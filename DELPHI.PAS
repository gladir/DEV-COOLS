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

  TODO 16 - PROPRIETES (PROPERTY)                          [IMPLEMENTE]
         property Nom: Type read Getter write Setter;
         Lecture -> appel de la methode/du champ Getter
         Ecriture -> appel de la methode/du champ Setter
         Propriete indexee (property Items[i: Integer]: T ...)
         Propriete par defaut (default property, acces obj[i])
         Default, stored, nodefault : specificateurs -> stubs
           conserves pour compatibilite syntaxique seulement

  TODO 17 - INTERFACES ET COM DE BASE                     [IMPLEMENTE]
         interface IXxx ['{GUID}'] ... end
         class(TObject, IXxx, ...) : implementation d interface(s)
         Generation automatique de QueryInterface, _AddRef, _Release
         Table de thunks par interface implementee (voir TODO 08)
         Variables de type interface : comptage de references
           automatique (voir TODO 09)

  TODO 18 - GESTION DES EXCEPTIONS                         [IMPLEMENTE]
         Try..Except..Finally, Raise, Raise; (relance)
         Hierarchie Exception minimale : Exception, EXxx courantes
           (EDivByZero, EInvalidCast, EAccessViolation, ERangeError)
         Exception.Message, Exception.ClassName
         Implementation via Structured Exception Handling (SEH)
           Win32 natif ou, a defaut, table de gestionnaires geree
           par le runtime (_DPRT_) avec deroulement de pile explicite
         Liberation automatique des objets exception non geres ->
           message d erreur non traite + ExitProcess

  TODO 19 - TABLEAUX, RECORDS ET ENSEMBLES (STATIQUE/DYNAMIQUE) [IMPLEMENTE]
         Tableaux statiques : identiques a Turbo Pascal
         Tableaux dynamiques (Array of T) : SetLength, Length,
           High/Low, comptage de references et reallocation via
           _DPRT_ (GetMem/FreeMem/Move)
         Tableaux ouverts en parametre (array of T sans bornes)
         Records simples champ par champ ; support minimal des
           "advanced records" (methodes dans un record) en stub
         Set of T : union, intersection, difference, test IN

  TODO 20 - CHAINES DE CARACTERES (ANSISTRING/WIDESTRING)  [IMPLEMENTE]
         AnsiString : bloc precede d un en-tete cache (compteur de
           references, longueur), copy-on-write, liberation
           automatique quand le compteur atteint zero
         Fonctions : Length, Copy, Delete, Insert, Pos, Concat,
           UpperCase, LowerCase, Trim, CompareStr/CompareText
         Concatenation + et comparaison avec gestion du refcount
         Conversion ShortString <-> AnsiString <-> PChar
         WideString/UnicodeString : stub minimal (stockage UTF-16,
           conversions de base uniquement)

  TODO 21 - INSTRUCTION ASM (BLOC ASSEMBLEUR EN LIGNE)     [IMPLEMENTE]
         ParseAsmBlock : asm ... end
         Assembleur 80386 natif (pas de traduction 8086 necessaire,
           contrairement a TPCW32, car Delphi cible directement le
           32 bits) : MOV, ADD, SUB, CALL, PUSH, POP, Jcc, etc.
         Acces depuis le bloc asm aux variables Pascal, aux champs
           d instance (via Self) et aux parametres de la methode
           courante

  TODO 22 - UNITES RTL MINIMALES (SYSTEM, SYSUTILS, CLASSES) [IMPLEMENTE]
         System : New, Dispose, GetMem, FreeMem, ReallocMem, Move,
           FillChar, Inc, Dec, Ord, Chr, High, Low, SizeOf, Abs,
           Sqr, Sqrt, Round, Trunc, Assigned, FreeAndNil
         SysUtils minimal : voir TODO 12 (IntToStr, Format, etc.),
           Exception et descendantes (voir TODO 18)
         Classes minimal (stub optionnel) : TList, TStringList
           avec l ensemble minimal de methodes utilise par les
           exemples de SAMPLES\DELPHI

  TODO 23 - FICHIERS PROJET (.dpr) ET UNITES (.pas)        [IMPLEMENTE]
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

  TODO 24 - GENERATION PE/OBJ (EXE PAR DEFAUT, OBJ SUR DEMANDE) [IMPLEMENTE]
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

  TODO 25 - VALIDATION : SUPPORT COMPLET DE SAMPLES\DELPHI\* [IMPLEMENTE]
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
  SrcFile      : TString;   { fichier source (.pas ou .dpr)         }
  OutFile      : TString;   { fichier sortie (.exe ou .obj)         }
  OutFileGiven : Boolean;   { True si l utilisateur a fourni le nom }
                             { de sortie explicitement (2e argument }
                             { positionnel) - False si derive par     }
                             { defaut de SrcFile (TODO 25 : une Unit   }
                             { compilee seule doit alors deriver .obj   }
                             { et non .exe, aucun point d entree n etant}
                             { possible pour un .exe).                   }
  Verbose      : Boolean;   { -v : banniere et statistiques         }
  DebugMode    : Boolean;   { -d : affichage de chaque token        }
  Warnings     : Boolean;   { -w : afficher les avertissements      }
  AsmOutput    : Boolean;   { -asm : produire aussi un .ASM lisible }
  ObjOnly      : Boolean;   { -obj : produire seulement un .OBJ     }
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
 Opts.SrcFile      := '';
 Opts.OutFile      := '';
 Opts.OutFileGiven := False;
 Opts.Verbose      := False;
 Opts.DebugMode    := False;
 Opts.Warnings     := False;
 Opts.AsmOutput    := False;
 Opts.ObjOnly      := False;
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
   Begin
    Opts.OutFile      := Arg;
    Opts.OutFileGiven := True;
   End
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
 If StrUpperCase(ExtractExt(Opts.OutFile)) = '.OBJ' Then
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
 MAX_DP_TYPE_SIZES = 26;

Type
 { Types d entrees dans le pool de donnees }
 TDataKind = (
  DK_STR,     { chaine ASCIIZ (DB 'xxx',0)                         }
  DK_DWORD,   { valeur 32 bits (DD nnn)                            }
  DK_BYTE,    { valeur 8 bits (DB nnn)                             }
  DK_ARRAY,   { tableau (DB ElemCount*ElemSize DUP(0))             }
  DK_RES,     { espace reserve (DB Size DUP(0))                    }
  DK_STRUCT,  { structure/record/VMT (DB Size DUP(0))              }
  DK_ZERO,    { espace initialise a zero (DB Size DUP(0))          }
  DK_BYTES    { octets litteraux (DB v1,v2,...), TODO 19 : constante }
              { ensembliste (StrVal = liste decimale prete a emettre) }
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
  (Name: 'SHORTSTRING';   Size: 256), { 255 + octet de longueur        }
  (Name: 'WIDESTRING';    Size: 4),   { stub minimal (TODO 20) : simple}
  (Name: 'UNICODESTRING'; Size: 4)    { pointeur, pas de vraie gestion }
                                       { UTF-16 (stockage/refcompte/    }
                                       { conversions) au-dela du minimum}
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

{ EmitRaw (TODO 07, definie bien plus bas avec le reste de l emetteur   }
{ ASM) : declaration anticipee necessaire ici - DataAddSetConst (TODO    }
{ 24) doit pouvoir rouvrir .DATA/.CODE en ligne des ce stade precoce du   }
{ fichier (TODO 04/19).                                                    }
Procedure EmitRaw(Const S: TString); Forward;

{ ---- DataAddSetConst (TODO 19) : constante ensembliste litterale ---- }
{ (MAX_SET_BYTES octets), un label auto-genere par litteral - pas de   }
{ deduplication (contrairement a DataGetOrAddStr) : deux litteraux      }
{ textuellement identiques restent rares et la dedup demanderait de     }
{ comparer les MAX_SET_BYTES octets, pas juste une chaine.               }
Function DataAddSetConst(Const SV: TSetVal): TString;
Var Lbl, S : TString; I : Integer;
Begin
 Inc(LabelGenSeq);
 Lbl := DP_STR_PFX + 'SET_' + IntToStr_(LabelGenSeq);
 S := '';
 For I := 0 To MAX_SET_BYTES - 1 Do
 Begin
  If S <> '' Then S := S + ',';
  S := S + IntToStr_(SV[I]);
 End;
 DataAdd(Lbl, DK_BYTES, 0, S, 0, 0);
 { Meme bug/correctif que ParseForStmt (LimLbl, TODO 13/24) : un        }
 { litteral ensembliste ([1,2,3]) peut apparaitre a l interieur d un      }
 { corps ou du bloc principal, bien APRES qu EmitDataSeg (TODO 07) ait     }
 { deja ecrit .DATA une seule fois (TODO 23) - DataAdd seul ne suffit       }
 { donc pas ici, il faut re-ouvrir .DATA/.CODE en ligne pour que ce           }
 { litteral existe reellement dans le texte .asm assemble.                     }
 EmitRaw('.DATA');
 EmitRaw(Lbl + '  DB ' + S);
 EmitRaw('.CODE');
 DataAddSetConst := Lbl;
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
 MAX_PROP_POOL    = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};  { proprietes de
                      toutes les classes confondues (TODO 16)     }

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

 { Une propriete de classe (property, TODO 16), dans le pool partage  }
 { PropPool. Pur sucre syntaxique vers un champ ou une methode : pas   }
 { de representation memoire propre (donc pas d Offset, contrairement }
 { a TFieldRec).                                                       }
 TPropRec = Record
  Name         : TString;
  TypeIdx      : Integer;   { type lu/ecrit par la propriete          }
  IsIndexed    : Boolean;   { property Nom[Index: T2]: T ...           }
  IndexTypeIdx : Integer;   { type du parametre d index, -1 si aucun  }
  ReadName     : TString;   { champ ou methode getter, '' = aucun     }
  WriteName    : TString;   { champ ou methode setter, '' = aucun     }
  IsDefault    : Boolean;   { propriete tableau par defaut, acces obj[i]}
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
  PropFirst   : Integer;    { SK_CLASS : index de depart dans        }
                             { PropPool (TODO 16), -1 si aucune       }
  PropCount   : Integer;    { SK_CLASS : nombre de proprietes PROPRES}
                             { (non copiees des ancetres - contrairement}
                             { aux champs, une propriete n a pas de   }
                             { disposition memoire a repercuter ; la  }
                             { recherche remonte donc la chaine des    }
                             { ancetres a la demande, PropFindInClassChain)}
  GUID        : TString;    { SK_INTERFACE : GUID litteral declare   }
                             { (TODO 17), optionnel apres le nom de   }
                             { l interface ; '' si absent             }
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
 PropPool      : Array[0..MAX_PROP_POOL - 1] Of TPropRec;
 PropPoolCount : Integer;

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
 TObjectIdx, ExceptionIdx, ExcCreateSym, ExcMessageSym : Integer;
 TObjCreateSym : Integer;
 TListSymIdx, TListCreateSym : Integer;
 TStringListSymIdx, TSLCreateSym : Integer;

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
 RegType('WIDESTRING'); RegType('UNICODESTRING'); { stub minimal, TODO 20 }
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
 TObjCreateSym := RegMethod('TObject', 'CREATE');
 { Bug trouve en instanciant reellement une classe SANS Create propre     }
 { (TODO 25 : "TAnimal.Create" ou TAnimal n a jamais redefini Create doit  }
 { resoudre l HERITE TObject.Create via SymFindInClassChain) : RegMethod    }
 { seule ne marque PAS IsConstructor (voir Exception.Create ci-dessous,      }
 { qui le fait explicitement) - sans cette ligne, ParseClassMemberAccess       }
 { ne reconnaissait JAMAIS TObject.Create comme un constructeur et             }
 { avertissait "ni un constructeur ni une methode de classe" pour TOUTE          }
 { classe n ayant pas explicitement redeclare son propre Create.                  }
 If TObjCreateSym >= 0 Then
 Begin
  SymTab[TObjCreateSym].IsConstructor := True;
  SymTab[TObjCreateSym].ParamCount    := 0;
 End;
 RegMethod('TObject', 'DESTROY');
 RegMethod('TObject', 'FREE');
 RegMethod('TObject', 'CLASSNAME');
 RegMethod('TObject', 'CLASSTYPE');
 SymLeaveScope;

 { -------------------------------------------------------- }
 { Exception : classe de base des exceptions (try/except,     }
 { TODO 18). Redefinit sa PROPRE Create (arite 1, Msg: String)}
 { qui masque celle de TObject (arite 0) - SymFindInClassChain}
 { la trouve en premier, aucune resolution de surcharge par    }
 { arite n est necessaire ici (TODO 14), c est un simple        }
 { masquage par nom comme pour toute autre methode heritee.     }
 { Le champ cache FMessage et les corps reels de Create/Message }
 { sont ajoutes/emis plus tard (ClassSystemInit/EmitRuntimeLibrary)}
 { une fois la table des types disponible.                       }
 { -------------------------------------------------------- }
 ExceptionIdx := SymDeclareClass('EXCEPTION', SK_CLASS, TObjectIdx);
 SymEnterClassScope(ExceptionIdx);
 ExcMessageSym := RegMethod('Exception', 'MESSAGE');
 If ExcMessageSym >= 0 Then
  SymTab[ExcMessageSym].TypeIdx := TypeFindByName('STRING');
 ExcCreateSym := RegMethod('Exception', 'CREATE');
 If ExcCreateSym >= 0 Then
 Begin
  SymTab[ExcCreateSym].IsConstructor := True;
  SymTab[ExcCreateSym].ParamCount    := 1;
 End;
 SymLeaveScope;

 { -------------------------------------------------------- }
 { Hierarchie minimale d exceptions courantes (TODO 18) :      }
 { aucune n ajoute de champ/methode propre, elles n existent    }
 { que pour etre distinguees par leur NOM de classe (approximation}
 { statique de "on E: EDivByZero do", faute de vraie RTTI       }
 { d instance - meme simplification que is/as, TODO 15).         }
 { -------------------------------------------------------- }
 SymDeclareClass('EDIVBYZERO', SK_CLASS, ExceptionIdx);
 SymDeclareClass('EINVALIDCAST', SK_CLASS, ExceptionIdx);
 SymDeclareClass('EACCESSVIOLATION', SK_CLASS, ExceptionIdx);
 SymDeclareClass('ERANGEERROR', SK_CLASS, ExceptionIdx);

 { -------------------------------------------------------- }
 { IUnknown : racine de toute la hierarchie d interfaces      }
 { (TODO 17). QueryInterface/AddRef/Release restent abstraites}
 { ici (aucun symbole propre, VMTAddMethod avec -1) : c est    }
 { chaque CLASSE implementant une interface qui recoit ses     }
 { PROPRES methodes generees automatiquement (voir              }
 { ClassEnsureIUnknownMethods, TODO 17) - la VMT elle-meme est   }
 { initialisee dans ClassSystemInit, comme pour TObject.         }
 { -------------------------------------------------------- }
 SymDeclareClass('IUNKNOWN', SK_INTERFACE, -1);

 { -------------------------------------------------------- }
 { TList (TODO 22, Classes minimal - stub optionnel) : liste  }
 { dynamique de Pointer (pas de generiques dans ce compilateur}
 { - un seul type de liste "brute"). Redefinit sa PROPRE       }
 { Create (arite 0, comme TObject, mais avec un vrai corps qui }
 { initialise ses champs - voir ClassSystemInit/                }
 { EmitRuntimeLibrary) : les instances ne sont PAS mises a zero}
 { par l allocateur (HeapAlloc avec dwFlags=0, TODO 15/22),     }
 { donc une classe qui a des champs a initialiser DOIT avoir   }
 { sa propre Create, meme d arite identique a celle heritee.    }
 { -------------------------------------------------------- }
 TListSymIdx := SymDeclareClass('TLIST', SK_CLASS, TObjectIdx);
 SymEnterClassScope(TListSymIdx);
 TListCreateSym := RegMethod('TList', 'CREATE');
 If TListCreateSym >= 0 Then
 Begin
  SymTab[TListCreateSym].IsConstructor := True;
  SymTab[TListCreateSym].ParamCount    := 0;
 End;
 RegMethod('TList', 'ADD');
 RegMethod('TList', 'GET');
 RegMethod('TList', 'DELETE');
 RegMethod('TList', 'CLEAR');
 RegMethod('TList', 'COUNT');
 SymLeaveScope;

 { -------------------------------------------------------- }
 { TStringList (TODO 22) : meme principe que TList, mais       }
 { stockage d AnsiString (Add/Get/Delete passent par              }
 { _DPRT_STRASSIGN, TODO 20, pour le comptage de references de   }
 { chaque slot).                                                   }
 { -------------------------------------------------------- }
 TStringListSymIdx := SymDeclareClass('TSTRINGLIST', SK_CLASS, TObjectIdx);
 SymEnterClassScope(TStringListSymIdx);
 TSLCreateSym := RegMethod('TStringList', 'CREATE');
 If TSLCreateSym >= 0 Then
 Begin
  SymTab[TSLCreateSym].IsConstructor := True;
  SymTab[TSLCreateSym].ParamCount    := 0;
 End;
 RegMethod('TStringList', 'ADD');
 RegMethod('TStringList', 'GET');
 RegMethod('TStringList', 'DELETE');
 RegMethod('TStringList', 'CLEAR');
 RegMethod('TStringList', 'COUNT');
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
 RegProc('SETLENGTH');   { tableaux dynamiques, TODO 19 }
 RegProc('DELETE');   RegProc('INSERT');   { AnsiString, TODO 20 }
 RegProc('REALLOCMEM');   { TODO 22 }
 RegProc('MOVE');      RegProc('FILLCHAR');   { TODO 22 }

 RegFunc('ORD');      RegFunc('CHR');
 RegFunc('SUCC');     RegFunc('PRED');
 RegFunc('LOW');      RegFunc('HIGH');
 RegFunc('SIZEOF');   RegFunc('LENGTH');
 RegFunc('ABS');      RegFunc('ASSIGNED');
 RegFunc('COPY');     RegFunc('POS');   { AnsiString, TODO 20 }
 RegFunc('SQR');      RegFunc('SQRT');     { TODO 22 }
 RegFunc('ROUND');    RegFunc('TRUNC');    { TODO 22 }

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
 { Exception redefinit sa PROPRE Create (Msg: String, TODO 18) - elle }
 { masque donc celle de TObject, contrairement a avant le TODO 18 ou   }
 { Exception n avait pas de Create en direct.                           }
 SymAssert('Exception.Create present en direct (TODO 18, arite 1)',
  (SymFindInClass(ExcIdx, 'Create') >= 0) And
  (SymTab[SymFindInClass(ExcIdx, 'Create')].ParamCount = 1));

 { inherited Methode : EDivByZero (TODO 18, heritee d Exception) ne    }
 { redefinit pas Create - "inherited Create" doit donc le trouver via  }
 { Exception, pas via TObject (masque depuis le TODO 18).                }
 CreateIdx := SymFindInherited(SymFind('EDivByZero'), 'Create');
 SymAssert('inherited Create resolu via Exception', CreateIdx >= 0);
 SymAssert('inherited Create pointe le bon symbole',
  CreateIdx = SymFindInClass(ExcIdx, 'Create'));

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
 TypeTab[TypeCount].PropFirst   := -1;
 TypeTab[TypeCount].PropCount   := 0;
 TypeTab[TypeCount].GUID        := '';

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
 Else If (N = 'STRING') Or (N = 'ANSISTRING') Or (N = 'SHORTSTRING') Or
         (N = 'WIDESTRING') Or (N = 'UNICODESTRING') Then
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
 PropPoolCount    := 0;

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

Function TypeIsSet(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsSet := False; Exit; End;
 TypeIsSet := TypeTab[R].Kind = TYK_SET;
End;

Function TypeIsArray(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsArray := False; Exit; End;
 TypeIsArray := TypeTab[R].Kind = TYK_ARRAY;
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
{ FieldFindInClass : cherche un champ par nom dans le FieldPool  }
{ PROPRE a BaseTypeIdx (deja etendu aux champs herites par       }
{ FieldInitInherit, donc pas besoin de remonter la chaine ici,    }
{ contrairement aux methodes/proprietes). Retourne l index dans   }
{ FieldPool, ou -1.                                                }
{ ------------------------------------------------------------ }

Function FieldFindInClass(BaseTypeIdx: Integer; Const UpName: TString): Integer;
Var First, Cnt, I : Integer;
Begin
 FieldFindInClass := -1;
 If (BaseTypeIdx < 0) Or (BaseTypeIdx >= TypeCount) Then Exit;
 First := TypeTab[BaseTypeIdx].FieldFirst;
 Cnt   := TypeTab[BaseTypeIdx].FieldCount;
 If First < 0 Then Exit;
 For I := First To First + Cnt - 1 Do
  If FieldPool[I].Name = UpName Then
  Begin
   FieldFindInClass := I;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeAddProperty (TODO 16) : enregistre une propriete dans le   }
{ pool partage PropPool, comme TypeAddField pour les champs -     }
{ mais une propriete n a pas de representation memoire propre     }
{ (pur sucre syntaxique vers un champ ou une methode), donc pas    }
{ d Offset/Align a calculer ici. Contrairement aux champs, les     }
{ proprietes heritees ne sont PAS copiees dans le pool du          }
{ descendant : PropFindInClassChain remonte la chaine a la         }
{ demande (voir sa documentation).                                  }
{ ------------------------------------------------------------ }

Function TypeAddProperty(ClassTypeIdx: Integer; Const PName: TString;
 PTypeIdx: Integer; IsIndexed: Boolean; IndexTypeIdx: Integer;
 Const ReadName, WriteName: TString): Integer;
Begin
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Or
    (PropPoolCount >= MAX_PROP_POOL) Then
 Begin
  TypeAddProperty := -1;
  Exit;
 End;

 If TypeTab[ClassTypeIdx].PropCount = 0 Then
  TypeTab[ClassTypeIdx].PropFirst := PropPoolCount;

 PropPool[PropPoolCount].Name         := StrUpperCase(PName);
 PropPool[PropPoolCount].TypeIdx      := PTypeIdx;
 PropPool[PropPoolCount].IsIndexed    := IsIndexed;
 PropPool[PropPoolCount].IndexTypeIdx := IndexTypeIdx;
 PropPool[PropPoolCount].ReadName     := StrUpperCase(ReadName);
 PropPool[PropPoolCount].WriteName    := StrUpperCase(WriteName);
 PropPool[PropPoolCount].IsDefault    := False;
 TypeAddProperty := PropPoolCount;
 Inc(PropPoolCount);
 Inc(TypeTab[ClassTypeIdx].PropCount);
End;

{ ------------------------------------------------------------ }
{ PropFindInClassChain / PropFindDefault (TODO 16) : recherche   }
{ une propriete par nom (ou la propriete tableau par defaut) en   }
{ remontant la chaine des ancetres (BaseTypeIdx), comme           }
{ SymFindInClassChain pour les methodes non virtuelles - une       }
{ propriete heritee n a pas besoin d etre recopiee (aucun offset   }
{ memoire a repercuter, contrairement a un champ).                  }
{ ------------------------------------------------------------ }

Function PropFindInClassChain(ClassTypeIdx: Integer; Const UpName: TString): Integer;
Var T, First, Cnt, I : Integer;
Begin
 PropFindInClassChain := -1;
 T := ClassTypeIdx;
 While T >= 0 Do
 Begin
  First := TypeTab[T].PropFirst;
  Cnt   := TypeTab[T].PropCount;
  If First >= 0 Then
   For I := First To First + Cnt - 1 Do
    If PropPool[I].Name = UpName Then
    Begin
     PropFindInClassChain := I;
     Exit;
    End;
  T := TypeTab[T].BaseTypeIdx;
 End;
End;

Function PropFindDefault(ClassTypeIdx: Integer): Integer;
Var T, First, Cnt, I : Integer;
Begin
 PropFindDefault := -1;
 T := ClassTypeIdx;
 While T >= 0 Do
 Begin
  First := TypeTab[T].PropFirst;
  Cnt   := TypeTab[T].PropCount;
  If First >= 0 Then
   For I := First To First + Cnt - 1 Do
    If PropPool[I].IsDefault Then
    Begin
     PropFindDefault := I;
     Exit;
    End;
  T := TypeTab[T].BaseTypeIdx;
 End;
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

{ Implementee au TODO 17 (table des interfaces implementees, bien plus }
{ bas) mais utilisee ici : une classe implemente-t-elle une interface ?}
Function IfaceImplFind(ClassTypeIdx, InterfaceTypeIdx: Integer): Integer; Forward;

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

 { Interface descendante -> reference a un de ses ancetres (TODO 17),  }
 { meme principe que la chaine de classes ci-dessus (IUnknown en tete).}
 If (TypeTab[RF].Kind = TYK_INTERFACE) And (TypeTab[RT].Kind = TYK_INTERFACE) Then
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

 { Classe implementant l interface -> variable de ce type interface    }
 { (TODO 17). Compatible a la COMPILATION ; la conversion reelle de la }
 { reference objet vers un pointeur de table de thunks proprement dit  }
 { reste une approximation (copie directe du pointeur) tant que        }
 { l emission des tables de thunks n est pas faite (TODO 24), comme    }
 { pour les VMT de classe (VMTLabelFor).                                }
 If (TypeTab[RF].Kind = TYK_CLASS) And (TypeTab[RT].Kind = TYK_INTERFACE) Then
 Begin TypeIsAssignCompatible := IfaceImplFind(RF, RT) >= 0; Exit; End;

 { Tableaux (TODO 19) : compatibilite STRUCTURELLE (contrairement aux   }
 { records, qui restent nominaux comme en Delphi reel - deux records    }
 { distincts aux champs identiques ne sont jamais compatibles) - meme   }
 { element, memes bornes pour un tableau statique, meme caractere       }
 { dynamique/statique des deux cotes.                                    }
 If (TypeTab[RF].Kind = TYK_ARRAY) And (TypeTab[RT].Kind = TYK_ARRAY) Then
 Begin
  TypeIsAssignCompatible :=
   (TypeTab[RF].IsDynArray = TypeTab[RT].IsDynArray) And
   (TypeResolve(TypeTab[RF].BaseTypeIdx) = TypeResolve(TypeTab[RT].BaseTypeIdx)) And
   (TypeTab[RF].IsDynArray Or
    ((TypeTab[RF].Lo = TypeTab[RT].Lo) And (TypeTab[RF].Hi = TypeTab[RT].Hi)));
  Exit;
 End;

 { Ensembles (TODO 19) : tous compatibles entre eux, quel que soit le  }
 { type de base declare - contrairement aux tableaux, la REPRESENTATION}
 { memoire d un ensemble ne depend jamais du type de base (toujours un }
 { bloc de MAX_SET_BYTES octets) ; un litteral ensembliste (ParseSetLiteral)}
 { n a d ailleurs pas de moyen simple d inferer le "vrai" type de base  }
 { attendu par le contexte (pas d inference bidirectionnelle dans ce    }
 { compilateur a une passe) - accepter largement ici evite d exiger      }
 { cette inference pour un cas d usage courant (Var := [1, 2, 3]).       }
 If (TypeTab[RF].Kind = TYK_SET) And (TypeTab[RT].Kind = TYK_SET) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

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

 { Tableaux/ensembles (TODO 19) : un typecast explicite est plus       }
 { permissif qu une affectation - accepte tout autre tableau/ensemble.  }
 If (TypeTab[RF].Kind = TYK_ARRAY) And (TypeTab[RT].Kind = TYK_ARRAY) Then
 Begin TypeIsCastCompatible := True; Exit; End;
 If (TypeTab[RF].Kind = TYK_SET) And (TypeTab[RT].Kind = TYK_SET) Then
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
 SetScratchSeq : Integer;   { tampons ensemblistes rotatifs (TODO 19) }

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
 SetScratchSeq := 0;
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
 EmitRaw('EXTRN _HeapReAlloc@16:NEAR');   { tableaux dynamiques, TODO 19 }
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
     { En-tete cachee AnsiString (TODO 20), juste avant les octets : }
     { compteur de references -1 (constante litterale, jamais       }
     { liberee/incrementee/decrementee - _DPRT_STRASSIGN le           }
     { verifie), puis la longueur. Le label reste positionne EXACTEMENT}
     { sur le premier caractere (aucun changement au site d emploi,   }
     { LEA EAX,[Label], deja utilise partout depuis le TODO 10).       }
     EmitRaw('DD -1');
     EmitRaw('DD ' + IntToStr_(Length(DataTab[I].StrVal)));
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

    DK_BYTES:
     EmitRaw(DataTab[I].LblName + '  DB ' + DataTab[I].StrVal);
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
  ClassTypeIdx      : Integer;
  InterfaceTypeIdx  : Integer;
  GUID              : TString;
  ThunkFirst        : Integer;
  ThunkCount        : Integer;
  HiddenFieldOffset : Integer;  { champ cache (pointeur vers la table }
                                  { de thunks de cette interface), TODO 25 }
  VTblLabel         : TString;  { etiquette .DATA de la table de thunks }
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

 { Runtime (_DPRT_, TODO 20) pour Copy/Delete/Insert/Pos sur           }
 { AnsiString - declarees ici (avant ParseStrCopy et consorts, TODO10) }
 { plutot qu avec DPRT_STR_CONCAT (TODO11, plus bas) car utilisees      }
 { plus tot dans le fichier.                                             }
 DPRT_STR_COPY    = '_DPRT_STRCOPY';     { Copy(S,Index,Count): Pointer }
 DPRT_STR_DELETE  = '_DPRT_STRDELETE';   { Delete(VAR S; Index,Count)  }
 DPRT_STR_INSERT  = '_DPRT_STRINSERT';   { Insert(Src; VAR S; Index)   }
 DPRT_STR_POS     = '_DPRT_STRPOS';      { Pos(SubStr, S): Integer     }

 { Runtime (_DPRT_, TODO 18) : relance/propagation d exception, geree }
 { par une pile de gestionnaires (tableaux DPRT_EXCSTACK_*, EmitRuntimeData) }
 { plutot que par le SEH natif Win32 (aucune primitive SEH deja        }
 { importee, et la spec du TODO 18 autorise explicitement ce repli).  }
 DPRT_RAISE = '_DPRT_RAISE';   { Raise(ExceptionObj: Pointer), ne revient jamais }

 { Runtime (_DPRT_, TODO 19) : (re)dimensionnement d un tableau         }
 { dynamique. Entete cachee de 8 octets (compteur de references,        }
 { longueur) juste avant les donnees, comme une AnsiString classique -   }
 { sans le vrai comptage de references (simplification documentee,       }
 { comme pour EmitAssignPointer sur ces memes tableaux).                  }
 DPRT_DYNARR_SETLENGTH = '_DPRT_DYNARR_SETLENGTH';
 MAX_SET_SCRATCH = 4;   { tampons ensemblistes rotatifs (TODO 19) - au }
                          { plus 4 operations +/-/* imbriquees dans une }
                          { meme expression sans collision              }

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
 EmitInstr('ADD ESP,8');
End;

Procedure EmitAssignInterface(Const DestAddrOperand, SrcOperand: TString);
Begin
 EmitComment('Affectation d interface : comptage de references (TODO 17/18)');
 EmitInstr('PUSH ' + SrcOperand);
 EmitInstr('PUSH ' + DestAddrOperand);
 EmitInstr('CALL ' + DPRT_INTF_ASSIGN);
 EmitInstr('ADD ESP,8');
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
{ EmitClassToInterfaceCoerce (TODO 25) : quand le membre droit     }
{ d une affectation vers une variable d interface est une          }
{ expression de type CLASSE (assignation directe classe->          }
{ interface, ex. G := Impl ou Impl: TFrenchGreeter), EAX contient   }
{ pour l instant le pointeur d OBJET brut - mais une variable        }
{ d interface doit contenir l ADRESSE du champ cache stampe par      }
{ ParseClassMemberAccess (le pointeur vers la table de thunks de      }
{ CETTE interface, EmitInterfaceThunks), pas le pointeur d objet        }
{ lui-meme : dereferencer une fois cette adresse donne la table de       }
{ thunks, et chaque thunk retranche ce meme offset pour retrouver         }
{ l objet reel avant de sauter vers la vraie methode (meme                 }
{ disposition qu un objet COM/Delphi reel). Sans cette correction,           }
{ un appel via la variable d interface utilisait l offset VMT propre          }
{ a l INTERFACE applique a la VMT REELLE de la classe (qui commence            }
{ par Destroy, herite de TObject) et atterrissait silencieusement sur           }
{ la mauvaise methode - limitation documentee depuis le TODO 17,                }
{ corrigee ici. N agit que si le membre droit est REELLEMENT de type             }
{ classe (LastExprTypeIdx, convention TODO 09/10) - une affectation               }
{ interface->interface (le membre droit est deja de ce type) reste                }
{ une simple copie de pointeur, deja correcte. `nil` reste `nil`.                  }
{ Implementation plus bas (TODO 10, apres la declaration de la globale}
{ LastExprTypeIdx) - seule la signature est necessaire ici.            }
{ ------------------------------------------------------------ }

Procedure EmitClassToInterfaceCoerce(Const SrcOperand: TString;
 DestIfaceTypeIdxResolved: Integer); Forward;

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

 { Un tableau DYNAMIQUE (TODO 19) est une simple copie de pointeur     }
 { (comme une classe) : sa case ne contient que l adresse des donnees, }
 { pas les donnees elles-memes - contrairement a un tableau STATIQUE,   }
 { qui reste une copie de bloc comme un record/ensemble. Aucun          }
 { comptage de references reel ici (simplification documentee, comme   }
 { pour les interfaces avant le vrai refcount du TODO 17/AnsiString du  }
 { TODO 20) : juste le pointeur, tel quel.                                }
 If (TypeTab[R].Kind = TYK_ARRAY) And TypeTab[R].IsDynArray Then
 Begin
  EmitAssignPointer(DestOperand, SrcOperand);
  Exit;
 End;

 Case TypeTab[R].Kind Of
  TYK_STRING:
   EmitAssignString(DestOperand, SrcOperand);
  TYK_INTERFACE:
  Begin
   EmitClassToInterfaceCoerce(SrcOperand, R);
   EmitAssignInterface(DestOperand, SrcOperand);
  End;
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

 { InInterfaceSection (TODO 23) : True pendant l analyse de la        }
 { section INTERFACE d une Unit. Une signature Procedure/Function y   }
 { est une simple DECLARATION (pas de corps - il vient plus tard,     }
 { dans IMPLEMENTATION) : ParseProcOrFuncDecl la traite alors comme    }
 { un FORWARD implicite (memes symptome/IsExternal qu un vrai          }
 { 'forward;'), permettant a IMPLEMENTATION de redefinir proprement    }
 { le meme symbole avec un corps reel (SymAdd sait deja faire cela     }
 { pour un forward, TODO 14).                                          }
 InInterfaceSection : Boolean;

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
{ EmitClassToInterfaceCoerce (TODO 25) : implementation (voir la  }
{ signature/Forward plus haut, avant EmitAssign, pour l explication}
{ complete) - definie ici, apres LastExprTypeIdx, puisqu elle en    }
{ a besoin.                                                          }
{ ------------------------------------------------------------ }

Procedure EmitClassToInterfaceCoerce(Const SrcOperand: TString;
 DestIfaceTypeIdxResolved: Integer);
Var
 SrcClassTypeIdx, ImplIdx : Integer;
 LblSkip : TString;
Begin
 SrcClassTypeIdx := TypeResolve(LastExprTypeIdx);
 If (SrcClassTypeIdx < 0) Or (SrcClassTypeIdx >= TypeCount) Then Exit;
 If TypeTab[SrcClassTypeIdx].Kind <> TYK_CLASS Then Exit;
 If SrcOperand <> 'EAX' Then Exit;   { convention EAX uniquement, TODO 09 }

 ImplIdx := IfaceImplFind(SrcClassTypeIdx, DestIfaceTypeIdxResolved);
 If ImplIdx < 0 Then
 Begin
  WarnMsg('la classe n''implemente pas directement cette interface ' +
   '(affectation classe->interface)');
  Exit;
 End;

 LblSkip := LabelGen;
 EmitComment('classe -> interface (TODO 25) : EAX devient l adresse du ' +
  'champ cache de thunks, sauf si nil');
 EmitInstr('CMP EAX,0');
 EmitInstr('JE ' + LblSkip);
 EmitInstr('ADD EAX,' + IntToStr_(IfaceImplTab[ImplIdx].HiddenFieldOffset));
 EmitLabel(LblSkip);
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

 { Un tableau DYNAMIQUE (TODO 19) n est PAS un bloc pour la lecture :  }
 { sa case ne contient qu un pointeur vers les donnees (comme une      }
 { classe/chaine) - seul un tableau STATIQUE (taille fixe, donnees      }
 { inline) se comporte comme un record/ensemble ici.                     }
 RT      := TypeResolve(SymTab[SI].TypeIdx);
 IsBlock := (RT >= 0) And (RT < TypeCount) And
  ((TypeTab[RT].Kind In [TYK_RECORD, TYK_SET]) Or
   ((TypeTab[RT].Kind = TYK_ARRAY) And Not TypeTab[RT].IsDynArray));

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

{ EmitCompareZeroJcc (TODO 11, definie plus bas avec le reste du   }
{ codegen des comparaisons) est reutilisee par ParseAssigned        }
{ (TODO 22) : declaration anticipee necessaire, l ordre habituel     }
{ du fichier la place APRES les fonctions ParseXxx du TODO 10.        }
Procedure EmitCompareZeroJcc(Const Jcc: TString); Forward;

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
{ GenPropertyAccessorCall (TODO 16) : appelle le getter/setter    }
{ d une propriete (AccessorUpName, deja en MAJUSCULES) une fois     }
{ que l APPELANT a deja empile tous les arguments necessaires,       }
{ Self en DERNIER (meme convention que le bloc d appel de methode    }
{ generique ci-dessous). Choisit l appel virtuel (via la VMT, si     }
{ l accesseur y figure - EBX doit alors contenir Self) ou statique    }
{ selon VMTFindMethod, exactement comme pour un appel de methode      }
{ ordinaire. CleanupBytes = taille totale (en octets) des arguments   }
{ empiles, Self compris, a nettoyer apres l appel (ADD ESP).           }
{ ------------------------------------------------------------ }

Function GenPropertyAccessorCall(BaseTypeIdx: Integer;
 Const AccessorUpName: TString; CleanupBytes: Integer): Integer;
Var MethodSym, VMTOffset : Integer;
Begin
 GenPropertyAccessorCall := -1;
 VMTOffset := VMTFindMethod(BaseTypeIdx, AccessorUpName);
 MethodSym := VMTFindMethodSym(BaseTypeIdx, AccessorUpName);
 If MethodSym < 0 Then MethodSym := SymFindInClassChain(BaseTypeIdx, AccessorUpName);
 If MethodSym < 0 Then
 Begin
  WarnMsg('accesseur de propriete introuvable: ' + AccessorUpName);
  Exit;
 End;
 If VMTOffset >= 0 Then
 Begin
  EmitInstr('MOV EDX,DWORD PTR [EBX]');
  EmitInstr('CALL DWORD PTR [EDX+' + IntToStr_(VMTOffset) + ']');
 End
 Else
  EmitInstr('CALL ' + SymTab[MethodSym].MangledName);
 EmitInstr('ADD ESP,' + IntToStr_(CleanupBytes));
 GenPropertyAccessorCall := SymTab[MethodSym].TypeIdx;
End;

{ ------------------------------------------------------------ }
{ GenIndexedPropertyAssign (TODO 16) : Nom[Index] := expr ou      }
{ Nom.Prop[Index] := expr, une fois que l APPELANT a deja empile   }
{ (PUSH) la reference Self et que PP pointe sur le '[' de l index.  }
{ L index et la valeur du membre droit sont evalues dans leur ORDRE }
{ TEXTUEL naturel (index d abord, puis valeur), chacun temporairement}
{ sauvegarde sur la pile machine, puis re-empiles dans l ordre exige }
{ par la convention d appel (valeur, index, Self - Self en dernier,  }
{ TODO 09/14) juste avant l appel au setter.                          }
{ ------------------------------------------------------------ }

Procedure GenIndexedPropertyAssign(BaseTypeIdx, PropIdx: Integer;
 Const PropDisplayName: TString);
Begin
 PPAdvance;                    { [ }
 ParseExpr;                     { EAX = valeur d index }
 EmitInstr('PUSH EAX');          { index, sauvegarde temporaire }
 PPMatch(']');
 PPMatch(':=');
 ParseExpr;                       { EAX = valeur a ecrire }
 EmitInstr('POP EDX');            { EDX = index }
 EmitInstr('POP EBX');            { EBX = Self }
 If PropPool[PropIdx].WriteName = '' Then
  WarnMsg('propriete en lecture seule: ' + PropDisplayName)
 Else
 Begin
  EmitInstr('PUSH EAX');          { valeur }
  EmitInstr('PUSH EDX');          { index }
  EmitInstr('PUSH EBX');          { Self, en dernier (1er parametre) }
  GenPropertyAccessorCall(BaseTypeIdx, PropPool[PropIdx].WriteName, 12);
 End;
End;

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
 First, Cnt, I, MethodSym, ArgN, VMTOffset, PropIdx : Integer;
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

 { Pas un champ : propriete (TODO 16) ? Recherchee AVANT les          }
 { methodes, car le nom d une propriete ne coincide jamais avec celui  }
 { de son propre accesseur (FField ou GetField/SetField).              }
 PropIdx := PropFindInClassChain(BaseTypeIdx, Up);
 If PropIdx >= 0 Then
 Begin
  If PropPool[PropIdx].IsIndexed Then
  Begin
   If Not PPMatch('[') Then
   Begin
    WarnMsg('propriete indexee ' + FieldName + ' : index "[...]" attendu');
    ParseFieldAccess := PropPool[PropIdx].TypeIdx;
    Exit;
   End;
   EmitInstr('MOV EBX,EAX');           { Self }
   ParseExpr;                          { EAX = valeur d index }
   PPMatch(']');
   If PropPool[PropIdx].ReadName = '' Then
   Begin
    WarnMsg('propriete en ecriture seule: ' + FieldName);
    ParseFieldAccess := PropPool[PropIdx].TypeIdx;
    Exit;
   End;
   EmitInstr('PUSH EAX');              { index }
   EmitInstr('PUSH EBX');              { Self, en dernier }
   LastExprTypeIdx := GenPropertyAccessorCall(BaseTypeIdx,
    PropPool[PropIdx].ReadName, 8);
   ParseFieldAccess := LastExprTypeIdx;
   Exit;
  End;

  { propriete simple : deleguer au champ ou a la methode getter -    }
  { EAX contient deja la reference/adresse de base, exactement comme }
  { si le code source avait ecrit Base.<ReadName> directement.        }
  If PropPool[PropIdx].ReadName = '' Then
  Begin
   WarnMsg('propriete en ecriture seule: ' + FieldName);
   ParseFieldAccess := PropPool[PropIdx].TypeIdx;
   Exit;
  End;
  ParseFieldAccess := ParseFieldAccess(BaseTypeIdx, PropPool[PropIdx].ReadName);
  Exit;
 End;

 { Pas un champ ni une propriete : methode d instance. VMTFindMethod    }
 { (Sym) attend un index de TYPE (BaseTypeIdx), contrairement a         }
 { SymFindInClassChain qui attend aussi un index de TYPE mais remonte   }
 { la chaine des ancetres (contrairement a SymFindInClass, limite a      }
 { une seule classe) - ne pas melanger avec l espace d index des         }
 { SYMBOLES. Une methode presente dans la VMT (virtual/dynamic/override,}
 { TODO 15) est appelee INDIRECTEMENT via le pointeur de VMT stocke a    }
 { l offset 0 de l instance ; une methode ordinaire (jamais ajoutee a     }
 { la VMT, ex. TObject.Free) est appelee en dur, retrouvee en remontant   }
 { la hierarchie des classes.                                             }
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
 CurType, C, TargetIdx, RCurType, PropIdx : Integer;
 ElemTypeIdx, ElemSize : Integer;
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
  Else If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '[') Then
  Begin
   RCurType := TypeResolve(CurType);

   If (RCurType >= 0) And (RCurType < TypeCount) And
      (TypeTab[RCurType].Kind = TYK_ARRAY) Then
   Begin
    { Indexation de tableau (TODO 19) : EAX contient deja l adresse de }
    { la case 0, que le tableau soit STATIQUE (LEA emis par            }
    { GenLoadVar/ParseFieldAccess, TypeNeedsDestAddr) ou DYNAMIQUE (la  }
    { case ne contient QUE ce pointeur, charge PAR VALEUR) - le meme     }
    { calcul convient aux deux cas, Lo valant toujours 0 pour un         }
    { tableau dynamique (TypeAddArray ne le change jamais).               }
    PPAdvance;                    { [ }
    ElemTypeIdx := TypeTab[RCurType].BaseTypeIdx;
    ElemSize    := TypeSizeofIdx(ElemTypeIdx);
    EmitInstr('MOV EBX,EAX');      { EBX = adresse de la case 0 }
    ParseExpr;                      { EAX = valeur d index }
    If TypeTab[RCurType].Lo <> 0 Then
     EmitInstr('SUB EAX,' + IntToStr_(TypeTab[RCurType].Lo));
    If ElemSize <> 1 Then
     EmitInstr('IMUL EAX,' + IntToStr_(ElemSize));
    EmitInstr('ADD EBX,EAX');
    PPMatch(']');
    If TypeNeedsDestAddr(ElemTypeIdx) Then
    Begin
     EmitInstr('MOV EAX,EBX');
     LastExprIsAddr := True;
    End
    Else
    Begin
     If ElemSize = 1 Then
      EmitInstr('MOVZX EAX,BYTE PTR [EBX]')
     Else
      EmitInstr('MOV EAX,' + SizedPtr(ElemTypeIdx) + '[EBX]');
     LastExprIsAddr := False;
    End;
    CurType := ElemTypeIdx;
    LastExprTypeIdx := CurType;
    Continue;
   End;

   { Propriete tableau par defaut (TODO 16) : obj[Index], sans nommer  }
   { la propriete. N intervient que pour un type classe possedant une  }
   { propriete indexee marquee "default" (PropFindDefault).             }
   PropIdx  := -1;
   If (RCurType >= 0) And (RCurType < TypeCount) And
      (TypeTab[RCurType].Kind = TYK_CLASS) Then
    PropIdx := PropFindDefault(RCurType);

   If PropIdx < 0 Then Break;   { pas gere ici : laisser l appelant reagir }

   PPAdvance;                    { [ }
   EmitInstr('MOV EBX,EAX');      { Self }
   ParseExpr;                      { EAX = valeur d index }
   PPMatch(']');
   If PropPool[PropIdx].ReadName = '' Then
   Begin
    WarnMsg('propriete par defaut en ecriture seule');
    CurType := PropPool[PropIdx].TypeIdx;
   End
   Else
   Begin
    EmitInstr('PUSH EAX');        { index }
    EmitInstr('PUSH EBX');        { Self, en dernier }
    CurType := GenPropertyAccessorCall(RCurType, PropPool[PropIdx].ReadName, 8);
   End;
   LastExprTypeIdx := CurType;
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

{ ============================================================ }
{ TODO 22 - UNITES RTL MINIMALES (SYSTEM, SYSUTILS, CLASSES) [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseGetMem : GetMem(P, Size) - allocation brute de Size       }
{ octets via HeapAlloc (meme primitive que New, mais avec une     }
{ taille explicite plutot que deduite du type pointe). P doit     }
{ etre un identificateur simple (variable pointeur), comme New/   }
{ Dispose (simplification documentee, TODO 09).                    }
{ ------------------------------------------------------------ }

Function ParseGetMem: Integer;
Var IdentTok: TString;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;               { EAX := Size }
 PPMatch(')');

 EmitComment('GetMem(' + IdentTok + ',Size) : allocation via HeapAlloc');
 EmitInstr('PUSH EAX');            { dwBytes, empile en premier }
 EmitInstr('CALL GetProcessHeap'); { EAX := handle - Size reste protege sur la pile }
 EmitInstr('PUSH 0');              { dwFlags }
 EmitInstr('PUSH EAX');            { hHeap, en dernier }
 EmitInstr('CALL HeapAlloc');
 GenStoreVar(IdentTok, 'EAX');

 LastExprTypeIdx := -1;
 ParseGetMem := -1;
End;

{ ------------------------------------------------------------ }
{ ParseFreeMem : FreeMem(P) - libere via HeapFree le bloc pointe  }
{ par P (identique a Dispose : ce compilateur ne distingue pas    }
{ le typage du pointeur pour la liberation elle-meme).             }
{ ------------------------------------------------------------ }

Function ParseFreeMem: Integer;
Var IdentTok: TString;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 GenLoadVar(IdentTok);   { EAX := valeur du pointeur }
 EmitComment('FreeMem(' + IdentTok + ') : liberation via HeapFree');
 EmitInstr('MOV ESI,EAX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapFree');

 LastExprTypeIdx := -1;
 ParseFreeMem := -1;
End;

{ ------------------------------------------------------------ }
{ ParseReallocMem : ReallocMem(P, NewSize) - redimensionne le     }
{ bloc pointe par P via HeapReAlloc (meme primitive que           }
{ _DPRT_DYNARR_SETLENGTH, TODO 19, mais sans l entete cachee       }
{ refcount/longueur : P est un pointeur brut).                     }
{ ------------------------------------------------------------ }

Function ParseReallocMem: Integer;
Var IdentTok: TString;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;                        { EAX := NewSize }
 PPMatch(')');

 EmitComment('ReallocMem(' + IdentTok + ',NewSize) : via HeapReAlloc');
 EmitInstr('PUSH EAX');            { dwBytes, empile en premier }
 GenLoadVar(IdentTok);              { EAX := ancien pointeur }
 EmitInstr('PUSH EAX');            { lpMem }
 EmitInstr('CALL GetProcessHeap'); { EAX := handle }
 EmitInstr('PUSH 0');              { dwFlags }
 EmitInstr('PUSH EAX');            { hHeap, en dernier }
 EmitInstr('CALL HeapReAlloc');
 GenStoreVar(IdentTok, 'EAX');

 LastExprTypeIdx := -1;
 ParseReallocMem := -1;
End;

{ ------------------------------------------------------------ }
{ ParseMove : Move(Source, Dest, Count) - copie brute de Count    }
{ octets via REP MOVSB. Source/Dest doivent etre des               }
{ identificateurs simples (variables) : GenVarAddr calcule           }
{ l adresse de la variable ELLE-MEME (pas sa valeur dereferencee),    }
{ exactement la semantique des parametres non types de Move en       }
{ vrai Delphi. Simplification documentee : pas de Source^/Dest^      }
{ (dereference explicite), comme New/Dispose/GetMem/FreeMem.          }
{ ------------------------------------------------------------ }

Function ParseMove: Integer;
Var SrcName, DestName: TString;
Begin
 PPMatch('(');
 SrcName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 DestName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;                  { EAX := Count }
 PPMatch(')');

 EmitComment('Move(' + SrcName + ',' + DestName + ',Count)');
 EmitInstr('PUSH EAX');       { conserver Count }
 GenVarAddr(SrcName);         { EDX := adresse source }
 EmitInstr('MOV ESI,EDX');
 GenVarAddr(DestName);        { EDX := adresse destination }
 EmitInstr('MOV EDI,EDX');
 EmitInstr('POP ECX');
 EmitInstr('CLD');
 EmitInstr('REP MOVSB');

 LastExprTypeIdx := -1;
 ParseMove := -1;
End;

{ ------------------------------------------------------------ }
{ ParseFillChar : FillChar(X, Count, Value) - remplissage brut    }
{ de Count octets via REP STOSB. X doit etre un identificateur     }
{ simple (meme simplification que Move ci-dessus).                  }
{ ------------------------------------------------------------ }

Function ParseFillChar: Integer;
Var XName: TString;
Begin
 PPMatch('(');
 XName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;                 { EAX := Count }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 ParseExpr;                 { EAX := Value (AL utilise par STOSB) }
 PPMatch(')');

 EmitComment('FillChar(' + XName + ',Count,Value)');
 GenVarAddr(XName);          { EDX := adresse de X }
 EmitInstr('MOV EDI,EDX');
 EmitInstr('POP ECX');
 EmitInstr('CLD');
 EmitInstr('REP STOSB');

 LastExprTypeIdx := -1;
 ParseFillChar := -1;
End;

{ ------------------------------------------------------------ }
{ ParseOrd : Ord(X) - un Char/Boolean/enumeration/sous-intervalle }
{ partage deja la representation entiere de son type de base       }
{ (TODO 06) : aucun code n est necessaire au-dela de l evaluation   }
{ de l expression elle-meme, seul le type du resultat change.        }
{ ------------------------------------------------------------ }

Function ParseOrd: Integer;
Begin
 PPMatch('(');
 ParseExpr;      { EAX := valeur ordinale, deja une representation entiere }
 PPMatch(')');
 LastExprTypeIdx := TypeFindByName('Integer');
 ParseOrd := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseChr : Chr(X) - reinterprete un entier comme un Char        }
{ (masque au octet bas, comme le fait deja ConstEvalAtom pour la  }
{ version compile-time de Chr).                                    }
{ ------------------------------------------------------------ }

Function ParseChr: Integer;
Begin
 PPMatch('(');
 ParseExpr;       { EAX := valeur entiere }
 PPMatch(')');
 EmitInstr('AND EAX,0FFh');
 LastExprTypeIdx := TypeFindByName('Char');
 ParseChr := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseAbs / ParseSqr : intrinseques arithmetiques ENTIERS purs   }
{ (aucun FPU necessaire) - Abs par negation conditionnelle, Sqr   }
{ par IMUL EAX,EAX. Le type du resultat est conserve tel quel      }
{ (Integer typiquement).                                           }
{ ------------------------------------------------------------ }

Function ParseAbs: Integer;
Var LblPos: TString;
Begin
 PPMatch('(');
 ParseExpr;
 PPMatch(')');
 LblPos := LabelGen;
 EmitInstr('CMP EAX,0');
 EmitInstr('JGE ' + LblPos);
 EmitInstr('NEG EAX');
 EmitLabel(LblPos);
 ParseAbs := LastExprTypeIdx;
End;

Function ParseSqr: Integer;
Begin
 PPMatch('(');
 ParseExpr;
 PPMatch(')');
 EmitInstr('IMUL EAX,EAX');
 ParseSqr := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseFloatIntrinsicStub : Sqrt/Round/Trunc necessiteraient un   }
{ vrai codegen FPU (FLD/FSQRT/FISTP...), qui n existe nulle part   }
{ ailleurs dans ce fichier (l arithmetique flottante elle-meme     }
{ n est encore qu un avertissement, voir ParseExprPrec et le cas   }
{ TK_REAL de ParsePrimary) - meme simplification deja assumee la : }
{ la routine est reconnue et consomme correctement ses arguments,  }
{ mais n effectue pas encore le calcul reel (avertissement +        }
{ resultat 0). Un vrai support demandera d introduire une           }
{ convention FPU generale, hors de la portee raisonnable de ce       }
{ seul TODO.                                                        }
{ ------------------------------------------------------------ }

Function ParseFloatIntrinsicStub(Const Name: TString): Integer;
Begin
 PPMatch('(');
 ParseExpr;
 PPMatch(')');
 WarnMsg(Name + ' : arithmetique flottante non encore implementee (FPU)');
 EmitInstr('XOR EAX,EAX');
 LastExprTypeIdx := TypeFindByName('Integer');
 ParseFloatIntrinsicStub := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseAssigned : Assigned(X) - sucre syntaxique pour X <> nil.  }
{ nil est deja represente par l entier 0 (RegConst('NIL', 0)) :   }
{ reutilise directement EmitCompareZeroJcc (meme motif que les     }
{ comparaisons ordinaires, TODO 11).                                }
{ ------------------------------------------------------------ }

Function ParseAssigned: Integer;
Begin
 PPMatch('(');
 ParseExpr;          { EAX := reference/pointeur }
 PPMatch(')');
 EmitCompareZeroJcc('JNE');
 LastExprTypeIdx := TypeFindByName('Boolean');
 ParseAssigned := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseFreeAndNil : FreeAndNil(X) - equivalent a X.Free suivi de }
{ X := nil. Reutilise exactement la meme resolution de methode     }
{ (VMTFindMethod/VMTFindMethodSym/SymFindInClassChain) et la        }
{ meme sequence d appel (Self empile en dernier, ADD ESP apres)      }
{ que ParseFieldAccess pour un appel de methode ordinaire.           }
{ ------------------------------------------------------------ }

Function ParseFreeAndNil: Integer;
Var
 IdentTok : TString;
 VI, TI, VMTOffset, MethodSym : Integer;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 VI := SymFind(IdentTok);
 If VI < 0 Then
 Begin
  WarnMsg('FreeAndNil: variable inconnue: ' + IdentTok);
  ParseFreeAndNil := -1;
  Exit;
 End;
 TI := TypeResolve(SymTab[VI].TypeIdx);
 If Not TypeIsClass(TI) Then
 Begin
  WarnMsg('FreeAndNil attend une instance de classe: ' + IdentTok);
  ParseFreeAndNil := -1;
  Exit;
 End;

 GenLoadVar(IdentTok);        { EAX := instance }
 EmitComment('FreeAndNil(' + IdentTok + ')');
 VMTOffset := VMTFindMethod(TI, 'FREE');
 MethodSym := VMTFindMethodSym(TI, 'FREE');
 If MethodSym < 0 Then MethodSym := SymFindInClassChain(TI, 'FREE');

 If MethodSym >= 0 Then
 Begin
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH EBX');
  If VMTOffset >= 0 Then
  Begin
   EmitInstr('MOV EDX,DWORD PTR [EBX]');
   EmitInstr('CALL DWORD PTR [EDX+' + IntToStr_(VMTOffset) + ']');
  End
  Else
   EmitInstr('CALL ' + SymTab[MethodSym].MangledName);
  EmitInstr('ADD ESP,4');
 End
 Else
  WarnMsg('FreeAndNil: methode Free introuvable pour ' + IdentTok);

 GenStoreVar(IdentTok, '0');
 LastExprTypeIdx := -1;
 ParseFreeAndNil := -1;
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

{ Definie plus bas avec ParseTypeExpr (TODO 19) : lit une valeur      }
{ entiere CONSTANTE simple (litteral, ou nom de constante SK_CONST).    }
Function ParseConstIntLiteral: LongInt; Forward;

{ ------------------------------------------------------------ }
{ ParseSetLiteral (TODO 19) : [a, b..c, ...] ou [] (ensemble vide).}
{ Elements et bornes de plage sont des CONSTANTES simples          }
{ (ParseConstIntLiteral) - un constructeur d ensemble melangeant     }
{ des valeurs connues seulement a l execution est hors de portee     }
{ ici (simplification documentee : reutilise directement SetValInclude}
{ /SetValClear du TODO 04, jamais raccordes au vrai parseur avant     }
{ ce TODO). Le bloc de MAX_SET_BYTES octets qui en resulte est emis   }
{ en .DATA (DataAddSetConst) et son ADRESSE renvoyee, exactement       }
{ comme un litteral chaine (DataGetOrAddStr).                          }
{ ------------------------------------------------------------ }

Function ParseSetLiteral: Integer;
Var
 SV : TSetVal;
 Lo, Hi, I : LongInt;
 Lbl : TString;
Begin
 SetValClear(SV);
 PPAdvance;   { [ }
 If Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = ']')) Then
  Repeat
   Lo := ParseConstIntLiteral;
   Hi := Lo;
   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '..') Then
   Begin
    PPAdvance;
    Hi := ParseConstIntLiteral;
   End;
   For I := Lo To Hi Do SetValInclude(SV, I);
  Until Not PPMatch(',');
 PPMatch(']');

 Lbl := DataAddSetConst(SV);
 EmitInstr('LEA EAX,[' + Lbl + ']');
 LastExprIsAddr  := True;
 LastExprTypeIdx := TypeAddSet(TypeFindByName('Integer'));
 ParseSetLiteral := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ OrdinalTypeBounds (TODO 22) : bornes Lo/Hi d un type ORDINAL   }
{ designe par son NOM (et non par une variable) - sous-intervalle}
{ (Lo/Hi deja stockes par TypeAddSubrange), enumeration (bornes   }
{ deduites du premier/dernier EnumValPool) ou type ordinal        }
{ predefini (Byte/Char/Boolean/ShortInt/Word/SmallInt/Integer/    }
{ LongInt - bornes classiques Delphi, en dur faute de table de     }
{ bornes dediee pour ces types de base). Utilise par High/Low     }
{ (ParseArrayLenHigh/ParseArrayLow) quand l argument n est PAS     }
{ une variable mais un nom de type - ex: High(Byte), Low(TCouleur)}
{ ------------------------------------------------------------ }

Function OrdinalTypeBounds(TI: Integer; Var LoV, HiV: LongInt): Boolean;
Var Up: TString;
Begin
 OrdinalTypeBounds := False;
 If (TI < 0) Or (TI >= TypeCount) Then Exit;

 If TypeTab[TI].Kind = TYK_SUBRANGE Then
 Begin
  LoV := TypeTab[TI].Lo; HiV := TypeTab[TI].Hi;
  OrdinalTypeBounds := True;
  Exit;
 End;

 If (TypeTab[TI].Kind = TYK_ENUM) And (TypeTab[TI].EnumCount > 0) Then
 Begin
  LoV := EnumValPool[TypeTab[TI].EnumFirst].Value;
  HiV := EnumValPool[TypeTab[TI].EnumFirst + TypeTab[TI].EnumCount - 1].Value;
  OrdinalTypeBounds := True;
  Exit;
 End;

 Up := StrUpperCase(TypeTab[TI].Name);
 If (Up = 'BYTE') Or (Up = 'CHAR') Then
 Begin LoV := 0; HiV := 255; OrdinalTypeBounds := True; Exit; End;
 If Up = 'BOOLEAN' Then
 Begin LoV := 0; HiV := 1; OrdinalTypeBounds := True; Exit; End;
 If Up = 'SHORTINT' Then
 Begin LoV := -128; HiV := 127; OrdinalTypeBounds := True; Exit; End;
 If Up = 'WORD' Then
 Begin LoV := 0; HiV := 65535; OrdinalTypeBounds := True; Exit; End;
 If Up = 'SMALLINT' Then
 Begin LoV := -32768; HiV := 32767; OrdinalTypeBounds := True; Exit; End;
 If (Up = 'INTEGER') Or (Up = 'LONGINT') Then
 Begin LoV := -2147483647 - 1; HiV := 2147483647; OrdinalTypeBounds := True; Exit; End;
End;

{ ------------------------------------------------------------ }
{ ParseArrayLenHigh / ParseArrayLow (TODO 19, etendu TODO 22) :  }
{ Length(Arr), High(Arr), Low(Arr). Un tableau STATIQUE a des     }
{ bornes connues a la COMPILATION (Lo/Hi du type) : aucun code n }
{ est genere, juste une constante. Un tableau DYNAMIQUE stocke sa}
{ longueur dans l entete cachee juste avant les donnees            }
{ ([Pointeur-4], voir _DPRT_DYNARR_SETLENGTH) - High = Length-1,   }
{ Low = 0 toujours ; un pointeur nil (tableau jamais dimensionne)  }
{ vaut longueur 0. Depuis TODO 22, High/Low acceptent aussi un      }
{ NOM DE TYPE ordinal (sous-intervalle, enumeration, ou type        }
{ predefini) via OrdinalTypeBounds - Length reste reserve aux       }
{ tableaux/chaines (High/Low(TypeOrdinal) n a pas d equivalent      }
{ Length).                                                           }
{ ------------------------------------------------------------ }

Function ParseArrayLenHigh(WantHigh: Boolean): Integer;
Var
 IdentTok, LblZero, LblDone : TString;
 VI, TI : Integer;
 LoV, HiV : LongInt;
 IsVarSym : Boolean;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 VI := SymFind(IdentTok);
 { Un nom de TYPE (Byte, TCouleur...) est aussi enregistre comme      }
 { symbole (RegType, SK_TYPE) : IsVarSym distingue une VRAIE variable  }
 { (SK_VAR/SK_PARAM, chemin tableau/chaine) d un simple nom de type     }
 { (chemin bornes ordinales High/Low(TypeName), TODO 22) - VI >= 0 ne   }
 { suffit PAS a lui seul pour ce distinguo.                              }
 IsVarSym := (VI >= 0) And (SymTab[VI].Kind In [SK_VAR, SK_PARAM]);
 TI := -1;
 If IsVarSym Then TI := TypeResolve(SymTab[VI].TypeIdx)
 Else TI := TypeResolve(TypeFindByName(IdentTok));

 If IsVarSym And (TI >= 0) And (TypeTab[TI].Kind = TYK_ARRAY) And
    Not TypeTab[TI].IsDynArray Then
 Begin
  If WantHigh Then
   EmitInstr('MOV EAX,' + IntToStr_(TypeTab[TI].Hi))
  Else
   EmitInstr('MOV EAX,' + IntToStr_(TypeTab[TI].Hi - TypeTab[TI].Lo + 1));
 End
 Else If IsVarSym And (TI >= 0) And (TypeTab[TI].Kind = TYK_ARRAY) And
    TypeTab[TI].IsDynArray Then
 Begin
  GenLoadVar(IdentTok);   { EAX = pointeur de donnees (0 si jamais dimensionne) }
  EmitInstr('TEST EAX,EAX');
  LblZero := LabelGen;
  LblDone := LabelGen;
  EmitInstr('JZ ' + LblZero);
  EmitInstr('MOV EAX,DWORD PTR [EAX-4]');
  If WantHigh Then EmitInstr('DEC EAX');
  EmitInstr('JMP ' + LblDone);
  EmitLabel(LblZero);
  If WantHigh Then EmitInstr('MOV EAX,-1') Else EmitInstr('XOR EAX,EAX');
  EmitLabel(LblDone);
 End
 Else If (Not WantHigh) And IsVarSym And (TI >= 0) And
    (TypeTab[TI].Kind = TYK_STRING) Then
 Begin
  { Length(S) (TODO 20) : meme en-tete cachee qu un tableau dynamique  }
  { ([Pointeur-4]) - une AnsiString litterale (refcount -1) porte        }
  { aussi sa longueur au meme endroit (EmitDataSeg), donc ce chemin       }
  { fonctionne indifferemment pour une variable ou un litteral direct.    }
  GenLoadVar(IdentTok);
  EmitInstr('TEST EAX,EAX');
  LblZero := LabelGen;
  LblDone := LabelGen;
  EmitInstr('JZ ' + LblZero);
  EmitInstr('MOV EAX,DWORD PTR [EAX-4]');
  EmitInstr('JMP ' + LblDone);
  EmitLabel(LblZero);
  EmitInstr('XOR EAX,EAX');
  EmitLabel(LblDone);
 End
 Else If (Not IsVarSym) And OrdinalTypeBounds(TI, LoV, HiV) Then
 Begin
  { High(NomDeType)/Low(NomDeType) (TODO 22) : borne constante }
  If WantHigh Then
   EmitInstr('MOV EAX,' + IntToStr_(HiV))
  Else
   EmitInstr('MOV EAX,' + IntToStr_(LoV));
 End
 Else
 Begin
  WarnMsg('Length/High attendent un tableau, une chaine (Length), ' +
   'ou un type ordinal (High/Low): ' + IdentTok);
  EmitInstr('XOR EAX,EAX');
 End;

 LastExprTypeIdx := TypeFindByName('Integer');
 ParseArrayLenHigh := LastExprTypeIdx;
End;

Function ParseArrayLow: Integer;
Var
 IdentTok : TString;
 VI, TI : Integer;
 LoV, HiV : LongInt;
 IsVarSym : Boolean;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 VI := SymFind(IdentTok);
 IsVarSym := (VI >= 0) And (SymTab[VI].Kind In [SK_VAR, SK_PARAM]);
 TI := -1;
 If IsVarSym Then TI := TypeResolve(SymTab[VI].TypeIdx)
 Else TI := TypeResolve(TypeFindByName(IdentTok));

 If IsVarSym And (TI >= 0) And (TypeTab[TI].Kind = TYK_ARRAY) Then
  EmitInstr('MOV EAX,' + IntToStr_(TypeTab[TI].Lo))   { 0 pour un dynamique }
 Else If (Not IsVarSym) And OrdinalTypeBounds(TI, LoV, HiV) Then
  EmitInstr('MOV EAX,' + IntToStr_(LoV))
 Else
 Begin
  WarnMsg('Low attend un tableau ou un type ordinal: ' + IdentTok);
  EmitInstr('XOR EAX,EAX');
 End;

 LastExprTypeIdx := TypeFindByName('Integer');
 ParseArrayLow := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseSetLengthCall (TODO 19) : SetLength(Arr, NewLen) - seuls    }
{ les tableaux DYNAMIQUES sont concernes (un tableau statique a une }
{ taille fixee a la compilation). Appelle _DPRT_DYNARR_SETLENGTH   }
{ avec l ADRESSE de la variable (GenVarAddr, gere deja correctement }
{ le cas d un parametre VAR/CONST/OUT), NewLen et ElemSize.          }
{ ------------------------------------------------------------ }

Function ParseSetLengthCall: Integer;
Var
 ArrName : TString;
 SI, TI, ElemTypeIdx, ElemSize : Integer;
Begin
 PPMatch('(');
 ArrName := TokenPool[PP].Val;
 PPAdvance;

 SI := SymFind(ArrName);
 TI := -1;
 If SI >= 0 Then TI := TypeResolve(SymTab[SI].TypeIdx);

 If (TI < 0) Or (TypeTab[TI].Kind <> TYK_ARRAY) Or (Not TypeTab[TI].IsDynArray) Then
 Begin
  WarnMsg('SetLength attend un tableau dynamique: ' + ArrName);
  While (Not PPAtEnd) And
        (Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = ')'))) Do PPAdvance;
  PPMatch(')');
  ParseSetLengthCall := -1;
  Exit;
 End;

 ElemTypeIdx := TypeTab[TI].BaseTypeIdx;
 ElemSize    := TypeSizeofIdx(ElemTypeIdx);

 PPMatch(',');
 EmitInstr('PUSH ' + IntToStr_(ElemSize));   { ElemSize, dernier parametre }
 ParseExpr;                                    { EAX = NewLen }
 EmitInstr('PUSH EAX');
 GenVarAddr(ArrName);                          { emet le calcul, resultat EDX }
 EmitInstr('PUSH EDX');                        { adresse variable, en dernier }
 EmitInstr('CALL ' + DPRT_DYNARR_SETLENGTH);
 EmitInstr('ADD ESP,12');
 PPMatch(')');

 ParseSetLengthCall := -1;   { procedure : pas de valeur utile }
End;

{ ------------------------------------------------------------ }
{ ParseStrCopy / ParseStrDelete / ParseStrInsert / ParseStrPos    }
{ (TODO 20) : Copy/Delete/Insert/Pos sur AnsiString. Chaque         }
{ argument est evalue dans son ORDRE TEXTUEL naturel (respecte les   }
{ effets de bord eventuels), chacun sauvegarde temporairement sur la  }
{ pile machine, puis re-empile dans l ordre exige par la convention   }
{ d appel (dernier parametre declare empile en premier, Self/adresse  }
{ en dernier) - meme technique que GenIndexedPropertyAssign (TODO 16) }
{ et SetLength (TODO 19).                                              }
{ ------------------------------------------------------------ }

Function ParseStrCopy: Integer;
Begin
 PPMatch('(');
 ParseExpr;                   { EAX = S }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 ParseExpr;                    { EAX = Index }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 ParseExpr;                     { EAX = Count }
 EmitInstr('PUSH EAX');
 PPMatch(')');
 EmitInstr('POP EAX');           { Count }
 EmitInstr('POP EDX');           { Index }
 EmitInstr('POP EBX');           { S }
 EmitInstr('PUSH EAX');          { Count, empile en premier (EBP+16) }
 EmitInstr('PUSH EDX');          { Index (EBP+12) }
 EmitInstr('PUSH EBX');          { S, en dernier (EBP+8) }
 EmitInstr('CALL ' + DPRT_STR_COPY);
 EmitInstr('ADD ESP,12');
 LastExprIsAddr  := False;        { valeur (pointeur), pas une adresse-de-case }
 LastExprTypeIdx := TypeFindByName('String');
 ParseStrCopy := LastExprTypeIdx;
End;

Function ParseStrDelete: Integer;
Var SName: TString;
Begin
 PPMatch('(');
 SName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;                   { EAX = Index }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 ParseExpr;                    { EAX = Count }
 EmitInstr('PUSH EAX');
 PPMatch(')');
 EmitInstr('POP EAX');          { Count }
 EmitInstr('POP EDX');          { Index }
 EmitInstr('PUSH EAX');         { Count (EBP+16) }
 EmitInstr('PUSH EDX');         { Index (EBP+12) }
 GenVarAddr(SName);              { adresse de S -> EDX }
 EmitInstr('PUSH EDX');          { adresse de S, en dernier (EBP+8) }
 EmitInstr('CALL ' + DPRT_STR_DELETE);
 EmitInstr('ADD ESP,12');
 ParseStrDelete := -1;           { procedure : pas de valeur utile }
End;

Function ParseStrInsert: Integer;
Var SName: TString;
Begin
 PPMatch('(');
 ParseExpr;                    { EAX = Source }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 SName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(',');
 ParseExpr;                     { EAX = Index }
 EmitInstr('PUSH EAX');
 PPMatch(')');
 EmitInstr('POP EAX');           { Index }
 EmitInstr('POP EBX');           { Source }
 EmitInstr('PUSH EAX');          { Index (EBP+16) }
 GenVarAddr(SName);               { adresse de S -> EDX }
 EmitInstr('PUSH EDX');           { adresse de S (EBP+12) }
 EmitInstr('PUSH EBX');           { Source, en dernier (EBP+8) }
 EmitInstr('CALL ' + DPRT_STR_INSERT);
 EmitInstr('ADD ESP,12');
 ParseStrInsert := -1;            { procedure : pas de valeur utile }
End;

Function ParseStrPos: Integer;
Begin
 PPMatch('(');
 ParseExpr;                     { EAX = SubStr }
 EmitInstr('PUSH EAX');
 PPMatch(',');
 ParseExpr;                      { EAX = S }
 EmitInstr('PUSH EAX');
 PPMatch(')');
 EmitInstr('POP EAX');            { S }
 EmitInstr('POP EBX');            { SubStr }
 EmitInstr('PUSH EAX');           { S (EBP+12) }
 EmitInstr('PUSH EBX');           { SubStr, en dernier (EBP+8) }
 EmitInstr('CALL ' + DPRT_STR_POS);
 EmitInstr('ADD ESP,8');
 LastExprTypeIdx := TypeFindByName('Integer');
 ParseStrPos := LastExprTypeIdx;
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

 { Litteral ensembliste [a, b..c, ...] (TODO 19) - sans ambiguite avec }
 { l indexation de tableau/propriete (TODO 16/19, ParsePostfix), qui   }
 { n intervient qu APRES une expression deja evaluee, jamais en        }
 { position PRIMAIRE (debut d expression).                              }
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '[') Then
 Begin
  ParsePrimary := ParsePostfix(ParseSetLiteral);
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
  If Up = 'LENGTH' Then Begin ParsePrimary := ParseArrayLenHigh(False); Exit; End;
  If Up = 'HIGH' Then Begin ParsePrimary := ParseArrayLenHigh(True); Exit; End;
  If Up = 'LOW' Then Begin ParsePrimary := ParseArrayLow; Exit; End;
  If Up = 'SETLENGTH' Then Begin ParsePrimary := ParseSetLengthCall; Exit; End;
  If Up = 'COPY' Then Begin ParsePrimary := ParsePostfix(ParseStrCopy); Exit; End;
  If Up = 'DELETE' Then Begin ParsePrimary := ParseStrDelete; Exit; End;
  If Up = 'INSERT' Then Begin ParsePrimary := ParseStrInsert; Exit; End;
  If Up = 'POS' Then Begin ParsePrimary := ParsePostfix(ParseStrPos); Exit; End;
  If Up = 'GETMEM' Then Begin ParsePrimary := ParseGetMem; Exit; End;
  If Up = 'FREEMEM' Then Begin ParsePrimary := ParseFreeMem; Exit; End;
  If Up = 'REALLOCMEM' Then Begin ParsePrimary := ParseReallocMem; Exit; End;
  If Up = 'MOVE' Then Begin ParsePrimary := ParseMove; Exit; End;
  If Up = 'FILLCHAR' Then Begin ParsePrimary := ParseFillChar; Exit; End;
  If Up = 'ORD' Then Begin ParsePrimary := ParseOrd; Exit; End;
  If Up = 'CHR' Then Begin ParsePrimary := ParseChr; Exit; End;
  If Up = 'ABS' Then Begin ParsePrimary := ParseAbs; Exit; End;
  If Up = 'SQR' Then Begin ParsePrimary := ParseSqr; Exit; End;
  If Up = 'SQRT' Then Begin ParsePrimary := ParseFloatIntrinsicStub('Sqrt'); Exit; End;
  If Up = 'ROUND' Then Begin ParsePrimary := ParseFloatIntrinsicStub('Round'); Exit; End;
  If Up = 'TRUNC' Then Begin ParsePrimary := ParseFloatIntrinsicStub('Trunc'); Exit; End;
  If Up = 'ASSIGNED' Then Begin ParsePrimary := ParseAssigned; Exit; End;
  If Up = 'FREEANDNIL' Then Begin ParsePrimary := ParseFreeAndNil; Exit; End;

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
 { Runtime (_DPRT_, TODO 07/09) pour la concatenation d AnsiString -  }
 { corps reel fourni par TODO 20. La comparaison reutilise directement}
 { DPRT_COMPARESTR (deja implementee au TODO 12, meme signature       }
 { Compare(A,B): Integer <0/0/>0) plutot que de dupliquer la meme      }
 { boucle octet par octet sous un second nom.                          }
 DPRT_STR_CONCAT  = '_DPRT_STRCONCAT';   { Concat(A, B): Pointer      }

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
 ResultLbl : TString;
 DwI : Integer;
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
    EmitInstr('ADD ESP,8');
    LastExprTypeIdx := LeftType;
   End
   Else
   Begin
    EmitComment('Comparaison AnsiString : reutilise ' + DPRT_COMPARESTR +
     ' (TODO 12/20)');
    EmitInstr('PUSH EBX');
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + DPRT_COMPARESTR);
    EmitInstr('ADD ESP,8');
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

  { --- Ensembles (TODO 19) : union (+), difference (-), intersection }
  { (*). EAX/EBX contiennent deja des ADRESSES de bloc (GenLoadVar/     }
  { ParseFieldAccess font toujours LEA pour un TYK_SET) - combine       }
  { DWORD par DWORD (8 * 4 = MAX_SET_BYTES octets) dans un tampon        }
  { rotatif (DPRT_SETSCRATCH0..3, SetScratchSeq) puisque, contrairement }
  { aux scalaires, le resultat ne tient pas dans un registre EAX.        }
  If TypeIsSet(LeftType) And ((Op = '+') Or (Op = '-') Or (Op = '*')) Then
  Begin
   EmitInstr('PUSH EAX');            { adresse du set gauche }
   ParseExprPrec(Prec + 1);           { EAX = adresse du set droit }
   EmitInstr('MOV EBX,EAX');
   EmitInstr('POP EAX');              { EAX = gauche, EBX = droit }
   ResultLbl := 'DPRT_SETSCRATCH' + IntToStr_(SetScratchSeq Mod MAX_SET_SCRATCH);
   Inc(SetScratchSeq);
   For DwI := 0 To (MAX_SET_BYTES Div 4) - 1 Do
   Begin
    EmitInstr('MOV ECX,DWORD PTR [EAX+' + IntToStr_(DwI * 4) + ']');
    If Op = '+' Then
     EmitInstr('OR ECX,DWORD PTR [EBX+' + IntToStr_(DwI * 4) + ']')
    Else If Op = '*' Then
     EmitInstr('AND ECX,DWORD PTR [EBX+' + IntToStr_(DwI * 4) + ']')
    Else   { '-' : difference = gauche AND (NOT droit) }
    Begin
     EmitInstr('MOV EDX,DWORD PTR [EBX+' + IntToStr_(DwI * 4) + ']');
     EmitInstr('NOT EDX');
     EmitInstr('AND ECX,EDX');
    End;
    EmitInstr('MOV DWORD PTR [' + ResultLbl + '+' + IntToStr_(DwI * 4) + '],ECX');
   End;
   EmitInstr('LEA EAX,[' + ResultLbl + ']');
   LastExprIsAddr  := True;
   LastExprTypeIdx := LeftType;
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
Const
 MAX_TRY_DEPTH = 32;   { profondeur maximale de try imbriques a l  }
                        { execution (TODO 18) - pile geree par le    }
                        { runtime, independante de toute pile de      }
                        { portees COMPILE-TIME (contrairement a       }
                        { LoopBreakLbl/LoopContLbl, TODO 13)          }
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
 EmitComment('--- Pile de gestionnaires d exception (TODO 18) ---');
 EmitRaw('DPRT_EXCTOP         DD 0');   { 0 = aucun gestionnaire actif }
 EmitRaw('DPRT_EXCSTACK_ESP   DD ' + IntToStr_(MAX_TRY_DEPTH) + ' DUP(0)');
 EmitRaw('DPRT_EXCSTACK_EBP   DD ' + IntToStr_(MAX_TRY_DEPTH) + ' DUP(0)');
 EmitRaw('DPRT_EXCSTACK_HANDLER DD ' + IntToStr_(MAX_TRY_DEPTH) + ' DUP(0)');
 EmitRaw('DPRT_CUREXCEPTION   DD 0');   { objet de la derniere exception levee }
 EmitRaw('DPRT_UNHANDLEDMSG   DB ''Exception non geree: '',0');
 EmitComment('--- Tampons ensemblistes de travail (TODO 19) ---');
 EmitRaw('DPRT_SETSCRATCH0    DB ' + IntToStr_(MAX_SET_BYTES) + ' DUP(0)');
 EmitRaw('DPRT_SETSCRATCH1    DB ' + IntToStr_(MAX_SET_BYTES) + ' DUP(0)');
 EmitRaw('DPRT_SETSCRATCH2    DB ' + IntToStr_(MAX_SET_BYTES) + ' DUP(0)');
 EmitRaw('DPRT_SETSCRATCH3    DB ' + IntToStr_(MAX_SET_BYTES) + ' DUP(0)');
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
 ExcIdx, ExcCreateSym, ExcMessageSym, FMsgFieldIdx, FMsgOffset : Integer;
 TListIdx, TLCreateSym, TLAddSym, TLGetSym, TLDelSym, TLClearSym, TLCountSym : Integer;
 TLItemsOff, TLCountOff, TLCapOff : Integer;
 TSLIdx, TSLCreateSym, TSLAddSym, TSLGetSym, TSLDelSym, TSLClearSym, TSLCountSym : Integer;
 TSLItemsOff, TSLCountOff, TSLCapOff : Integer;
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

 EmitComment('--- _DPRT_INTFASSIGN(NewVal, VAR Dest) : comptage de');
 EmitComment('    references d interface (TODO 17). Relache l ancienne');
 EmitComment('    valeur (Release, offset IUnknown standard +8) si non');
 EmitComment('    nulle, retient la nouvelle (AddRef, +4) si non nulle,');
 EmitComment('    puis stocke. Correct pour un flux interface->interface');
 EmitComment('    (le pointeur pointe deja vers une vraie table de type');
 EmitComment('    IUnknown) ; une classe assignee directement a une');
 EmitComment('    variable d interface reste une approximation tant que');
 EmitComment('    la table de thunks n est pas emise (TODO 24).');
 EmitLabel(DPRT_INTF_ASSIGN);
 EmitProlog(0);
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');    { EAX = adresse de Dest }
 EmitInstr('MOV EBX,DWORD PTR [EAX]');       { EBX = ancienne valeur }
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_INTFASSIGN_SKIPREL');
 EmitInstr('MOV ECX,DWORD PTR [EBX]');       { ECX = table (thunks/VMT) }
 EmitInstr('PUSH EBX');
 EmitInstr('CALL DWORD PTR [ECX+8]');        { Release }
 EmitInstr('ADD ESP,4');
 EmitLabel('DPRT_INTFASSIGN_SKIPREL');
 EmitInstr('MOV EDX,DWORD PTR [EBP+12]');    { EDX = nouvelle valeur }
 EmitInstr('TEST EDX,EDX');
 EmitInstr('JZ DPRT_INTFASSIGN_SKIPADD');
 EmitInstr('MOV ECX,DWORD PTR [EDX]');
 EmitInstr('PUSH EDX');
 EmitInstr('CALL DWORD PTR [ECX+4]');        { AddRef }
 EmitInstr('ADD ESP,4');
 EmitLabel('DPRT_INTFASSIGN_SKIPADD');
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
 EmitInstr('MOV EDX,DWORD PTR [EBP+12]');
 EmitInstr('MOV DWORD PTR [EAX],EDX');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRASSIGN(NewVal, VAR Dest) (TODO 20) : comptage de     }
 { references AnsiString, meme principe que _DPRT_INTFASSIGN mais      }
 { avec un VRAI HeapFree du bloc (entete comprise, recul de 8 octets)   }
 { quand le compteur atteint zero. Un compteur NEGATIF (-1) marque       }
 { une constante litterale (DataAddSetConst/EmitDataSeg, TODO 20) :      }
 { jamais incremente/decremente/liberee.                                  }
 EmitComment('--- ' + DPRT_STR_ASSIGN +
  '(NewVal, VAR Dest) : comptage de references AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_ASSIGN);
 EmitProlog(0);
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');     { adresse de Dest }
 EmitInstr('MOV EBX,DWORD PTR [EAX]');        { ancienne valeur }
 EmitInstr('MOV EDX,DWORD PTR [EBP+12]');     { nouvelle valeur }
 EmitInstr('TEST EDX,EDX');
 EmitInstr('JZ DPRT_STRASSIGN_SKIPADD');
 EmitInstr('MOV ECX,DWORD PTR [EDX-8]');
 EmitInstr('CMP ECX,0');
 EmitInstr('JL DPRT_STRASSIGN_SKIPADD');
 EmitInstr('INC ECX');
 EmitInstr('MOV DWORD PTR [EDX-8],ECX');
 EmitLabel('DPRT_STRASSIGN_SKIPADD');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_STRASSIGN_SKIPREL');
 EmitInstr('MOV ECX,DWORD PTR [EBX-8]');
 EmitInstr('CMP ECX,0');
 EmitInstr('JL DPRT_STRASSIGN_SKIPREL');
 EmitInstr('DEC ECX');
 EmitInstr('MOV DWORD PTR [EBX-8],ECX');
 EmitInstr('CMP ECX,0');
 EmitInstr('JG DPRT_STRASSIGN_SKIPREL');
 EmitInstr('SUB EBX,8');                       { bloc reel (entete incluse) }
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH EBX');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapFree');
 EmitLabel('DPRT_STRASSIGN_SKIPREL');
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
 EmitInstr('MOV EDX,DWORD PTR [EBP+12]');
 EmitInstr('MOV DWORD PTR [EAX],EDX');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRCONCAT(A, B): Pointer (TODO 20) : alloue une NOUVELLE }
 { AnsiString (entete + LenA+LenB octets + terminateur nul), copie A     }
 { puis B, et renvoie l ADRESSE DES DONNEES (apres l entete). Compteur    }
 { de references initialise a ZERO (pas 1) : c est l affectation qui      }
 { suit habituellement (S3 := S1+S2, via _DPRT_STRASSIGN) qui en prend     }
 { possession en l incrementant a 1 - un resultat de concatenation JAMAIS  }
 { assigne (ex: WriteLn(S1+S2) seul) fuit la memoire (simplification        }
 { documentee : pas de gestion de temporaires, comme les tableaux            }
 { dynamiques du TODO 19).                                                    }
 EmitComment('--- ' + DPRT_STR_CONCAT +
  '(A, B): Pointer : concatenation AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_CONCAT);
 EmitProlog(16);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EBX,DWORD PTR [EBP+8]');       { A }
 EmitInstr('XOR EAX,EAX');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_SC_ADONE');
 EmitInstr('MOV EAX,DWORD PTR [EBX-4]');
 EmitLabel('DPRT_SC_ADONE');
 EmitInstr('MOV DWORD PTR [EBP-4],EAX');        { LenA }
 EmitInstr('MOV EBX,DWORD PTR [EBP+12]');       { B }
 EmitInstr('XOR EAX,EAX');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_SC_BDONE');
 EmitInstr('MOV EAX,DWORD PTR [EBX-4]');
 EmitLabel('DPRT_SC_BDONE');
 EmitInstr('MOV DWORD PTR [EBP-8],EAX');        { LenB }
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitInstr('ADD EAX,DWORD PTR [EBP-8]');
 EmitInstr('ADD EAX,9');                         { + entete (8) + terminateur nul (1) }
 EmitInstr('MOV DWORD PTR [EBP-16],EAX');        { taille totale a allouer }
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-16]');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV DWORD PTR [EAX],0');             { refcount = 0, voir ci-dessus }
 EmitInstr('MOV EDX,DWORD PTR [EBP-4]');
 EmitInstr('ADD EDX,DWORD PTR [EBP-8]');
 EmitInstr('MOV DWORD PTR [EAX+4],EDX');         { longueur }
 EmitInstr('ADD EAX,8');                          { EAX = debut des donnees resultat }
 EmitInstr('MOV DWORD PTR [EBP-12],EAX');
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-4]');
 EmitInstr('TEST ESI,ESI');
 EmitInstr('JZ DPRT_SC_SKIPA');
 EmitInstr('TEST ECX,ECX');
 EmitInstr('JZ DPRT_SC_SKIPA');
 EmitInstr('REP MOVSB');
 EmitLabel('DPRT_SC_SKIPA');
 EmitInstr('MOV ESI,DWORD PTR [EBP+12]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-8]');
 EmitInstr('TEST ESI,ESI');
 EmitInstr('JZ DPRT_SC_SKIPB');
 EmitInstr('TEST ECX,ECX');
 EmitInstr('JZ DPRT_SC_SKIPB');
 EmitInstr('REP MOVSB');
 EmitLabel('DPRT_SC_SKIPB');
 EmitInstr('MOV BYTE PTR [EDI],0');              { terminateur nul final }
 EmitInstr('MOV EAX,DWORD PTR [EBP-12]');        { resultat }
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRCOPY(S, Index, Count): Pointer (TODO 20) : Copy()     }
 { Delphi (1-based, bornes ecretees comme la vraie fonction). Alloue    }
 { une NOUVELLE AnsiString (refcount 0, meme convention que Concat).     }
 EmitComment('--- ' + DPRT_STR_COPY +
  '(S, Index, Count): Pointer : Copy() AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_COPY);
 EmitProlog(20);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EBX,DWORD PTR [EBP+8]');        { S }
 EmitInstr('XOR EAX,EAX');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_SCOPY_LEN0');
 EmitInstr('MOV EAX,DWORD PTR [EBX-4]');
 EmitLabel('DPRT_SCOPY_LEN0');
 EmitInstr('MOV DWORD PTR [EBP-4],EAX');         { Len }
 EmitInstr('MOV EAX,DWORD PTR [EBP+12]');        { Index }
 EmitInstr('DEC EAX');
 EmitInstr('CMP EAX,0');
 EmitInstr('JGE DPRT_SCOPY_IDXOK1');
 EmitInstr('XOR EAX,EAX');
 EmitLabel('DPRT_SCOPY_IDXOK1');
 EmitInstr('CMP EAX,DWORD PTR [EBP-4]');
 EmitInstr('JLE DPRT_SCOPY_IDXOK2');
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitLabel('DPRT_SCOPY_IDXOK2');
 EmitInstr('MOV DWORD PTR [EBP-8],EAX');         { Idx0 }
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitInstr('SUB EAX,DWORD PTR [EBP-8]');          { restant = Len-Idx0 }
 EmitInstr('MOV EDX,DWORD PTR [EBP+16]');         { Count demande }
 EmitInstr('CMP EDX,EAX');
 EmitInstr('JLE DPRT_SCOPY_CNTOK1');
 EmitInstr('MOV EDX,EAX');
 EmitLabel('DPRT_SCOPY_CNTOK1');
 EmitInstr('CMP EDX,0');
 EmitInstr('JGE DPRT_SCOPY_CNTOK2');
 EmitInstr('XOR EDX,EDX');
 EmitLabel('DPRT_SCOPY_CNTOK2');
 EmitInstr('MOV DWORD PTR [EBP-12],EDX');         { ActualCount }
 EmitInstr('MOV EAX,DWORD PTR [EBP-12]');
 EmitInstr('ADD EAX,9');
 EmitInstr('MOV DWORD PTR [EBP-20],EAX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-20]');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV DWORD PTR [EAX],0');
 EmitInstr('MOV EDX,DWORD PTR [EBP-12]');
 EmitInstr('MOV DWORD PTR [EAX+4],EDX');
 EmitInstr('ADD EAX,8');
 EmitInstr('MOV DWORD PTR [EBP-16],EAX');         { ResultDataPtr }
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('ADD ESI,DWORD PTR [EBP-8]');           { S + Idx0 }
 EmitInstr('MOV ECX,DWORD PTR [EBP-12]');
 EmitInstr('REP MOVSB');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('MOV EAX,DWORD PTR [EBP-16]');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRDELETE(VAR S; Index, Count) (TODO 20) : Delete()      }
 { Delphi. Construit une nouvelle chaine (prefixe + suffixe autour de   }
 { la portion retiree) puis la stocke dans S via _DPRT_STRASSIGN (qui   }
 { libere correctement l ancienne valeur) - jamais de mutation sur      }
 { place, pour ne jamais corrompre une autre variable partageant le      }
 { meme bloc (comptage de references).                                    }
 EmitComment('--- ' + DPRT_STR_DELETE +
  '(VAR S; Index, Count) : Delete() AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_DELETE);
 EmitProlog(24);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EBX,DWORD PTR [EBP+8]');          { adresse de S }
 EmitInstr('MOV EAX,DWORD PTR [EBX]');             { valeur actuelle de S }
 EmitInstr('XOR EDX,EDX');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_SD_LEN0');
 EmitInstr('MOV EDX,DWORD PTR [EAX-4]');
 EmitLabel('DPRT_SD_LEN0');
 EmitInstr('MOV DWORD PTR [EBP-4],EDX');           { Len }
 EmitInstr('MOV EAX,DWORD PTR [EBP+12]');          { Index }
 EmitInstr('DEC EAX');
 EmitInstr('CMP EAX,0');
 EmitInstr('JGE DPRT_SD_IDXOK1');
 EmitInstr('XOR EAX,EAX');
 EmitLabel('DPRT_SD_IDXOK1');
 EmitInstr('CMP EAX,DWORD PTR [EBP-4]');
 EmitInstr('JLE DPRT_SD_IDXOK2');
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitLabel('DPRT_SD_IDXOK2');
 EmitInstr('MOV DWORD PTR [EBP-8],EAX');            { Idx0 }
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitInstr('SUB EAX,DWORD PTR [EBP-8]');
 EmitInstr('MOV EDX,DWORD PTR [EBP+16]');            { Count }
 EmitInstr('CMP EDX,EAX');
 EmitInstr('JLE DPRT_SD_CNTOK1');
 EmitInstr('MOV EDX,EAX');
 EmitLabel('DPRT_SD_CNTOK1');
 EmitInstr('CMP EDX,0');
 EmitInstr('JGE DPRT_SD_CNTOK2');
 EmitInstr('XOR EDX,EDX');
 EmitLabel('DPRT_SD_CNTOK2');
 EmitInstr('MOV DWORD PTR [EBP-12],EDX');            { ActualCount }
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitInstr('SUB EAX,DWORD PTR [EBP-12]');
 EmitInstr('MOV DWORD PTR [EBP-16],EAX');            { NewLen }
 EmitInstr('ADD EAX,9');
 EmitInstr('MOV DWORD PTR [EBP-20],EAX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-20]');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV DWORD PTR [EAX],0');
 EmitInstr('MOV EDX,DWORD PTR [EBP-16]');
 EmitInstr('MOV DWORD PTR [EAX+4],EDX');
 EmitInstr('ADD EAX,8');
 EmitInstr('MOV DWORD PTR [EBP-24],EAX');             { NewDataPtr }
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ESI,DWORD PTR [EBX]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-8]');               { Idx0 }
 EmitInstr('REP MOVSB');                                { copie [0..Idx0) }
 EmitInstr('MOV EDI,DWORD PTR [EBP-24]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-8]');
 EmitInstr('MOV ESI,DWORD PTR [EBX]');
 EmitInstr('ADD ESI,DWORD PTR [EBP-8]');
 EmitInstr('ADD ESI,DWORD PTR [EBP-12]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-4]');
 EmitInstr('SUB ECX,DWORD PTR [EBP-8]');
 EmitInstr('SUB ECX,DWORD PTR [EBP-12]');
 EmitInstr('REP MOVSB');                                { copie [Idx0+ActualCount..Len) }
 EmitInstr('MOV EDI,DWORD PTR [EBP-24]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-16]');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('PUSH DWORD PTR [EBP-24]');
 EmitInstr('PUSH EBX');
 EmitInstr('CALL ' + DPRT_STR_ASSIGN);
 EmitInstr('ADD ESP,8');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRINSERT(Source; VAR S; Index) (TODO 20) : Insert()     }
 { Delphi - meme technique que Delete (nouvelle chaine, StrAssign).    }
 EmitComment('--- ' + DPRT_STR_INSERT +
  '(Source; VAR S; Index) : Insert() AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_INSERT);
 EmitProlog(24);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EBX,DWORD PTR [EBP+12]');           { adresse de S }
 EmitInstr('MOV EAX,DWORD PTR [EBX]');               { valeur actuelle de S }
 EmitInstr('XOR EDX,EDX');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_SI_SLEN0');
 EmitInstr('MOV EDX,DWORD PTR [EAX-4]');
 EmitLabel('DPRT_SI_SLEN0');
 EmitInstr('MOV DWORD PTR [EBP-4],EDX');              { LenS }
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');              { Source }
 EmitInstr('XOR EDX,EDX');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_SI_SRCLEN0');
 EmitInstr('MOV EDX,DWORD PTR [EAX-4]');
 EmitLabel('DPRT_SI_SRCLEN0');
 EmitInstr('MOV DWORD PTR [EBP-8],EDX');               { LenSrc }
 EmitInstr('MOV EAX,DWORD PTR [EBP+16]');              { Index }
 EmitInstr('DEC EAX');
 EmitInstr('CMP EAX,0');
 EmitInstr('JGE DPRT_SI_IDXOK1');
 EmitInstr('XOR EAX,EAX');
 EmitLabel('DPRT_SI_IDXOK1');
 EmitInstr('CMP EAX,DWORD PTR [EBP-4]');
 EmitInstr('JLE DPRT_SI_IDXOK2');
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitLabel('DPRT_SI_IDXOK2');
 EmitInstr('MOV DWORD PTR [EBP-12],EAX');               { Idx0 }
 EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
 EmitInstr('ADD EAX,DWORD PTR [EBP-8]');
 EmitInstr('MOV DWORD PTR [EBP-16],EAX');               { NewLen = LenS+LenSrc }
 EmitInstr('ADD EAX,9');
 EmitInstr('MOV DWORD PTR [EBP-20],EAX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-20]');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV DWORD PTR [EAX],0');
 EmitInstr('MOV EDX,DWORD PTR [EBP-16]');
 EmitInstr('MOV DWORD PTR [EAX+4],EDX');
 EmitInstr('ADD EAX,8');
 EmitInstr('MOV DWORD PTR [EBP-24],EAX');                { NewDataPtr }
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ESI,DWORD PTR [EBX]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-12]');                 { Idx0 }
 EmitInstr('REP MOVSB');                                   { copie S[0..Idx0) }
 EmitInstr('MOV EDI,DWORD PTR [EBP-24]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-12]');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');                    { Source }
 EmitInstr('MOV ECX,DWORD PTR [EBP-8]');                     { LenSrc }
 EmitInstr('REP MOVSB');                                      { copie Source entier }
 EmitInstr('MOV EDI,DWORD PTR [EBP-24]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-12]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-8]');
 EmitInstr('MOV ESI,DWORD PTR [EBX]');
 EmitInstr('ADD ESI,DWORD PTR [EBP-12]');
 EmitInstr('MOV ECX,DWORD PTR [EBP-4]');
 EmitInstr('SUB ECX,DWORD PTR [EBP-12]');
 EmitInstr('REP MOVSB');                                       { copie S[Idx0..LenS) }
 EmitInstr('MOV EDI,DWORD PTR [EBP-24]');
 EmitInstr('ADD EDI,DWORD PTR [EBP-16]');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('PUSH DWORD PTR [EBP-24]');
 EmitInstr('PUSH EBX');
 EmitInstr('CALL ' + DPRT_STR_ASSIGN);
 EmitInstr('ADD ESP,8');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 { --- _DPRT_STRPOS(SubStr, S): Integer (TODO 20) : Pos() Delphi -    }
 { recherche naive (sous-chaine dans une chaine), 1-based, 0 si         }
 { absente ou si SubStr est vide (comme la vraie fonction).             }
 EmitComment('--- ' + DPRT_STR_POS +
  '(SubStr, S): Integer : Pos() AnsiString (TODO 20) ---');
 EmitLabel(DPRT_STR_POS);
 EmitProlog(12);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EBX,DWORD PTR [EBP+8]');           { SubStr }
 EmitInstr('XOR EAX,EAX');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_SP_SUBLEN0');
 EmitInstr('MOV EAX,DWORD PTR [EBX-4]');
 EmitLabel('DPRT_SP_SUBLEN0');
 EmitInstr('MOV DWORD PTR [EBP-4],EAX');            { LenSub }
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_SP_NOTFOUND');
 EmitInstr('MOV EDX,DWORD PTR [EBP+12]');            { S }
 EmitInstr('XOR EAX,EAX');
 EmitInstr('TEST EDX,EDX');
 EmitInstr('JZ DPRT_SP_SLEN0');
 EmitInstr('MOV EAX,DWORD PTR [EDX-4]');
 EmitLabel('DPRT_SP_SLEN0');
 EmitInstr('MOV DWORD PTR [EBP-8],EAX');             { LenS }
 EmitInstr('MOV DWORD PTR [EBP-12],0');               { I = 0 }
 EmitLabel('DPRT_SP_OUTER');
 EmitInstr('MOV EAX,DWORD PTR [EBP-12]');
 EmitInstr('ADD EAX,DWORD PTR [EBP-4]');
 EmitInstr('CMP EAX,DWORD PTR [EBP-8]');
 EmitInstr('JG DPRT_SP_NOTFOUND');
 EmitInstr('MOV ESI,DWORD PTR [EBP+12]');
 EmitInstr('ADD ESI,DWORD PTR [EBP-12]');
 EmitInstr('MOV EDI,EBX');
 EmitInstr('MOV ECX,DWORD PTR [EBP-4]');
 EmitLabel('DPRT_SP_INNER');
 EmitInstr('MOV AL,BYTE PTR [ESI]');
 EmitInstr('CMP AL,BYTE PTR [EDI]');
 EmitInstr('JNE DPRT_SP_NEXT');
 EmitInstr('INC ESI');
 EmitInstr('INC EDI');
 EmitInstr('DEC ECX');
 EmitInstr('JNZ DPRT_SP_INNER');
 EmitInstr('MOV EAX,DWORD PTR [EBP-12]');
 EmitInstr('INC EAX');
 EmitInstr('JMP DPRT_SP_DONE');
 EmitLabel('DPRT_SP_NEXT');
 EmitInstr('MOV EAX,DWORD PTR [EBP-12]');
 EmitInstr('INC EAX');
 EmitInstr('MOV DWORD PTR [EBP-12],EAX');
 EmitInstr('JMP DPRT_SP_OUTER');
 EmitLabel('DPRT_SP_NOTFOUND');
 EmitInstr('XOR EAX,EAX');
 EmitLabel('DPRT_SP_DONE');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
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
   SymTab[CreateSym].IsExternal := False;
  End;

  If DestroySym >= 0 Then
  Begin
   EmitComment('--- TObject.Destroy (virtuelle) : corps vide par defaut ---');
   EmitLabel(SymTab[DestroySym].MangledName);
   EmitProlog(0);
   EmitEpilog;
   EmitBlankLine;
   SymTab[DestroySym].IsExternal := False;
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
   SymTab[FreeSym].IsExternal := False;
  End;
 End;

 { --- Exception : corps reels de Create(Msg)/Message (TODO 18). Le  }
 { champ cache FMessage a ete reserve par ClassSystemInit ; son        }
 { offset est retrouve ici dynamiquement (FieldFindInClass), comme     }
 { le reste de ce bloc retrouve les symboles via SymFindInClass. Note :}
 { FMsgFieldIdx/FMsgOffset restent valides plus bas (_DPRT_RAISE) meme }
 { si Exception est introuvable (-1 : le message ne sera pas affiche). }
 FMsgFieldIdx := -1;
 FMsgOffset   := 0;
 ExcIdx := SymFind('Exception');
 If ExcIdx >= 0 Then
 Begin
  ExcCreateSym  := SymFindInClass(ExcIdx, 'CREATE');
  ExcMessageSym := SymFindInClass(ExcIdx, 'MESSAGE');
  FMsgFieldIdx  := FieldFindInClass(SymTab[ExcIdx].TypeIdx, 'FMESSAGE');
  If FMsgFieldIdx >= 0 Then FMsgOffset := FieldPool[FMsgFieldIdx].Offset;

  If (ExcCreateSym >= 0) And (FMsgFieldIdx >= 0) Then
  Begin
   EmitComment('--- Exception.Create(Msg) : stocke Msg dans FMessage ---');
   EmitLabel(SymTab[ExcCreateSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');    { Self }
   EmitInstr('MOV EDX,DWORD PTR [EBP+12]');   { Msg (pointeur de chaine) }
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(FMsgOffset) + '],EDX');
   EmitEpilog;
   EmitBlankLine;
   SymTab[ExcCreateSym].IsExternal := False;
  End;

  If (ExcMessageSym >= 0) And (FMsgFieldIdx >= 0) Then
  Begin
   EmitComment('--- Exception.Message : renvoie FMessage ---');
   EmitLabel(SymTab[ExcMessageSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');    { Self }
   EmitInstr('MOV EAX,DWORD PTR [EAX+' + IntToStr_(FMsgOffset) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[ExcMessageSym].IsExternal := False;
  End;
 End;

 { --- _DPRT_RAISE(ExceptionObj) (TODO 18) : ne revient JAMAIS a son   }
 { appelant - soit elle saute directement dans le bloc except/finally }
 { le plus proche (pile de gestionnaires geree par le runtime,         }
 { DPRT_EXCSTACK_*, empilee/depilee par ParseTryStmt), en restaurant   }
 { ESP/EBP tels qu ils etaient a l entree du try correspondant (donc    }
 { independant de la profondeur d appel entre la levee et le try -     }
 { setjmp/longjmp classique), soit, si aucun gestionnaire n est actif,  }
 { affiche un message d erreur (prefixe + Message, si l objet est un    }
 { Exception ou descendant) puis libere l objet et termine le          }
 { processus (ExitProcess).                                             }
 FreeSym := SymFindInClass(SymFind('TObject'), 'FREE');
 EmitComment('--- ' + DPRT_RAISE +
  '(ExceptionObj) : relance/propagation d exception (TODO 18) ---');
 EmitLabel(DPRT_RAISE);
 EmitInstr('MOV DWORD PTR [DPRT_CUREXCEPTION],EAX');
 EmitInstr('MOV EAX,DWORD PTR [DPRT_EXCTOP]');
 EmitInstr('CMP EAX,0');
 EmitInstr('JLE DPRT_RAISE_UNHANDLED');
 EmitInstr('DEC EAX');
 EmitInstr('MOV DWORD PTR [DPRT_EXCTOP],EAX');
 EmitInstr('MOV EDX,DWORD PTR [DPRT_EXCSTACK_HANDLER+EAX*4]');
 EmitInstr('MOV ECX,DWORD PTR [DPRT_EXCSTACK_EBP+EAX*4]');
 EmitInstr('MOV EBX,DWORD PTR [DPRT_EXCSTACK_ESP+EAX*4]');
 EmitInstr('MOV EBP,ECX');
 EmitInstr('MOV ESP,EBX');
 EmitInstr('JMP EDX');
 EmitLabel('DPRT_RAISE_UNHANDLED');
 EmitInstr('PUSH OFFSET DPRT_UNHANDLEDMSG');
 EmitInstr('CALL ' + DPRT_WRITESTR);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EAX,DWORD PTR [DPRT_CUREXCEPTION]');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_RAISE_NOMSG');
 If FMsgFieldIdx >= 0 Then
 Begin
  EmitInstr('MOV EDX,DWORD PTR [EAX+' + IntToStr_(FMsgOffset) + ']');
  EmitInstr('PUSH EDX');
  EmitInstr('CALL ' + DPRT_WRITESTR);
  EmitInstr('ADD ESP,4');
 End;
 EmitLabel('DPRT_RAISE_NOMSG');
 EmitInstr('PUSH OFFSET DPRT_CRLF');
 EmitInstr('CALL ' + DPRT_WRITESTR);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EAX,DWORD PTR [DPRT_CUREXCEPTION]');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ DPRT_RAISE_EXIT');
 If FreeSym >= 0 Then
 Begin
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + SymTab[FreeSym].MangledName);
  EmitInstr('ADD ESP,4');
 End;
 EmitLabel('DPRT_RAISE_EXIT');
 EmitInstr('PUSH 1');
 EmitInstr('CALL ExitProcess');
 EmitBlankLine;

 { --- _DPRT_DYNARR_SETLENGTH(VAR ArrPtr; NewLen, ElemSize) (TODO 19) --- }
 { (Re)dimensionne un tableau dynamique. Entete cachee de 8 octets       }
 { (compteur de references, longueur) juste avant le pointeur de         }
 { donnees rendu a l appelant - meme principe qu une AnsiString          }
 { classique, sans le vrai comptage de references (simplification        }
 { documentee : un seul HeapAlloc/HeapReAlloc, jamais de copie sur       }
 { ecriture reelle).                                                       }
 EmitComment('--- ' + DPRT_DYNARR_SETLENGTH +
  '(VAR ArrPtr, NewLen, ElemSize) (TODO 19) ---');
 EmitLabel(DPRT_DYNARR_SETLENGTH);
 EmitProlog(4);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EAX,DWORD PTR [EBP+12]');    { NewLen }
 EmitInstr('IMUL EAX,DWORD PTR [EBP+16]');   { * ElemSize }
 EmitInstr('ADD EAX,8');                     { + entete (refcount+longueur) }
 EmitInstr('MOV DWORD PTR [EBP-4],EAX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');     { adresse de la variable }
 EmitInstr('MOV EBX,DWORD PTR [ESI]');       { ancien pointeur (0 si vide) }
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_DYNARR_SL_NEW');
 EmitInstr('SUB EBX,8');                     { bloc reel = donnees - entete }
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-4]');
 EmitInstr('PUSH EBX');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapReAlloc');
 EmitInstr('JMP DPRT_DYNARR_SL_STORE');
 EmitLabel('DPRT_DYNARR_SL_NEW');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH DWORD PTR [EBP-4]');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitLabel('DPRT_DYNARR_SL_STORE');
 EmitInstr('MOV DWORD PTR [EAX],1');         { refcount (simplification) }
 EmitInstr('MOV EBX,DWORD PTR [EBP+12]');    { NewLen }
 EmitInstr('MOV DWORD PTR [EAX+4],EBX');     { longueur }
 EmitInstr('ADD EAX,8');                     { EAX = pointeur de donnees }
 EmitInstr('MOV DWORD PTR [ESI],EAX');
 EmitInstr('POP EBX');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 { --- TList (TODO 22, Classes minimal) : liste dynamique de       }
 { Pointer. Stockage brut (HeapAlloc/HeapReAlloc, dwFlags=0 - pas   }
 { de mise a zero necessaire, les elements sont de simples pointeurs}
 { ecrits directement, jamais dereferences comme en-tete de bloc).   }
 { Champs caches FITEMS (Pointer)/FCOUNT/FCAPACITY (Integer) ajoutes }
 { par ClassSystemInit ; offsets retrouves ici dynamiquement, comme   }
 { FMessage/Exception ci-dessus.                                       }
 { Note : les champs FITEMS/FCOUNT/FCAPACITY ne sont ajoutes qu au    }
 { premier appel de ClassSystemInit - or EmitRuntimeLibrary peut       }
 { s executer AVANT (ex: EmitSelfTest, appele tot dans Run, produit    }
 { un squelette .asm avant tout ClassSystemInit). FieldFindInClass     }
 { renvoie -1 sans crasher dans ce cas (TypeTab[...].FieldFirst < 0),  }
 { mais indexer FieldPool avec -1 crasherait : le garde-fou             }
 { TypeTab[...].FieldFirst >= 0 evite d emettre ces corps (avec des      }
 { offsets bidons) tant que les champs ne sont pas encore poses -        }
 { la VRAIE compilation (Run), elle, a toujours appele ClassSystemInit  }
 { avant d atteindre EmitSkeletonProgram.                                 }
 TListIdx := SymFind('TList');
 If (TListIdx >= 0) And (TypeTab[SymTab[TListIdx].TypeIdx].FieldFirst >= 0) Then
 Begin
  TLCreateSym := SymFindInClass(TListIdx, 'CREATE');
  TLAddSym    := SymFindInClass(TListIdx, 'ADD');
  TLGetSym    := SymFindInClass(TListIdx, 'GET');
  TLDelSym    := SymFindInClass(TListIdx, 'DELETE');
  TLClearSym  := SymFindInClass(TListIdx, 'CLEAR');
  TLCountSym  := SymFindInClass(TListIdx, 'COUNT');
  TLItemsOff  := FieldPool[FieldFindInClass(SymTab[TListIdx].TypeIdx, 'FITEMS')].Offset;
  TLCountOff  := FieldPool[FieldFindInClass(SymTab[TListIdx].TypeIdx, 'FCOUNT')].Offset;
  TLCapOff    := FieldPool[FieldFindInClass(SymTab[TListIdx].TypeIdx, 'FCAPACITY')].Offset;

  If TLCreateSym >= 0 Then
  Begin
   EmitComment('--- TList.Create : initialise FItems/FCount/FCapacity ---');
   EmitLabel(SymTab[TLCreateSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { Self }
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TLItemsOff) + '],0');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TLCountOff) + '],0');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TLCapOff) + '],0');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLCreateSym].IsExternal := False;
  End;

  If TLAddSym >= 0 Then
  Begin
   EmitComment('--- TList.Add(Item): Integer - agrandit si necessaire ---');
   EmitLabel(SymTab[TLAddSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');    { Self }
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitInstr('CMP EAX,DWORD PTR [EBX+' + IntToStr_(TLCapOff) + ']');
   EmitInstr('JL DPRT_TLADD_NOGROW');
   EmitInstr('MOV ESI,DWORD PTR [EBX+' + IntToStr_(TLCapOff) + ']');
   EmitInstr('SHL ESI,1');
   EmitInstr('TEST ESI,ESI');
   EmitInstr('JNZ DPRT_TLADD_CAPOK');
   EmitInstr('MOV ESI,4');
   EmitLabel('DPRT_TLADD_CAPOK');
   EmitInstr('MOV EDI,ESI');
   EmitInstr('SHL EDI,2');                    { EDI = NewCap*4 octets }
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TLItemsOff) + ']');
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JZ DPRT_TLADD_ALLOCNEW');
   EmitInstr('CALL GetProcessHeap');
   EmitInstr('PUSH EDI');
   EmitInstr('PUSH DWORD PTR [EBX+' + IntToStr_(TLItemsOff) + ']');
   EmitInstr('PUSH 0');
   EmitInstr('PUSH EAX');
   EmitInstr('CALL HeapReAlloc');
   EmitInstr('JMP DPRT_TLADD_GROWDONE');
   EmitLabel('DPRT_TLADD_ALLOCNEW');
   EmitInstr('CALL GetProcessHeap');
   EmitInstr('PUSH EDI');
   EmitInstr('PUSH 0');
   EmitInstr('PUSH EAX');
   EmitInstr('CALL HeapAlloc');
   EmitLabel('DPRT_TLADD_GROWDONE');
   EmitInstr('MOV DWORD PTR [EBX+' + IntToStr_(TLItemsOff) + '],EAX');
   EmitInstr('MOV DWORD PTR [EBX+' + IntToStr_(TLCapOff) + '],ESI');
   EmitLabel('DPRT_TLADD_NOGROW');
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitInstr('MOV ECX,DWORD PTR [EBP+12]');    { Item }
   EmitInstr('MOV DWORD PTR [EAX+EDX*4],ECX');
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitInstr('INC DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLAddSym].IsExternal := False;
  End;

  If TLGetSym >= 0 Then
  Begin
   EmitComment('--- TList.Get(Index): Pointer ---');
   EmitLabel(SymTab[TLGetSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+' + IntToStr_(TLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBP+12]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+EDX*4]');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLGetSym].IsExternal := False;
  End;

  If TLDelSym >= 0 Then
  Begin
   EmitComment('--- TList.Delete(Index) - decale les elements suivants ---');
   EmitLabel(SymTab[TLDelSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EDI,DWORD PTR [EBX+' + IntToStr_(TLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBP+12]');    { Index }
   EmitInstr('MOV ECX,DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitInstr('SUB ECX,EDX');
   EmitInstr('DEC ECX');                        { nb elements a decaler }
   EmitInstr('CMP ECX,0');
   EmitInstr('JLE DPRT_TLDEL_SKIPSHIFT');
   EmitInstr('PUSH EDI');
   EmitInstr('LEA ESI,[EDI+EDX*4+4]');
   EmitInstr('LEA EDI,[EDI+EDX*4]');
   EmitInstr('CLD');
   EmitInstr('REP MOVSD');
   EmitInstr('POP EDI');
   EmitLabel('DPRT_TLDEL_SKIPSHIFT');
   EmitInstr('DEC DWORD PTR [EBX+' + IntToStr_(TLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLDelSym].IsExternal := False;
  End;

  If TLClearSym >= 0 Then
  Begin
   EmitComment('--- TList.Clear - remet le compteur a zero (garde le bloc) ---');
   EmitLabel(SymTab[TLClearSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TLCountOff) + '],0');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLClearSym].IsExternal := False;
  End;

  If TLCountSym >= 0 Then
  Begin
   EmitComment('--- TList.Count: Integer ---');
   EmitLabel(SymTab[TLCountSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+' + IntToStr_(TLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TLCountSym].IsExternal := False;
  End;
 End;

 { --- TStringList (TODO 22) : meme structure que TList, mais       }
 { elements AnsiString avec comptage de references reel              }
 { (_DPRT_STRASSIGN, TODO 20) sur chaque slot. Croissance avec        }
 { HEAP_ZERO_MEMORY (dwFlags=8, contrairement a TList) : un slot      }
 { fraichement alloue DOIT valoir nil avant sa premiere ecriture,      }
 { sans quoi _DPRT_STRASSIGN interpreterait un octet de bloc heap     }
 { non initialise comme un ancien pointeur de chaine a liberer.        }
 { Delete() libere explicitement le slot supprime (StrAssign(nil,..)) }
 { PUIS remet a nil l ancien DERNIER slot apres decalage : sans cela   }
 { ce slot garderait une copie brute (non comptee) du dernier pointeur}
 { de chaine, causant une double liberation le jour ou Add() l ecrase.}
 TSLIdx := SymFind('TStringList');
 If (TSLIdx >= 0) And (TypeTab[SymTab[TSLIdx].TypeIdx].FieldFirst >= 0) Then
 Begin
  TSLCreateSym := SymFindInClass(TSLIdx, 'CREATE');
  TSLAddSym    := SymFindInClass(TSLIdx, 'ADD');
  TSLGetSym    := SymFindInClass(TSLIdx, 'GET');
  TSLDelSym    := SymFindInClass(TSLIdx, 'DELETE');
  TSLClearSym  := SymFindInClass(TSLIdx, 'CLEAR');
  TSLCountSym  := SymFindInClass(TSLIdx, 'COUNT');
  TSLItemsOff  := FieldPool[FieldFindInClass(SymTab[TSLIdx].TypeIdx, 'FITEMS')].Offset;
  TSLCountOff  := FieldPool[FieldFindInClass(SymTab[TSLIdx].TypeIdx, 'FCOUNT')].Offset;
  TSLCapOff    := FieldPool[FieldFindInClass(SymTab[TSLIdx].TypeIdx, 'FCAPACITY')].Offset;

  If TSLCreateSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Create : initialise FItems/FCount/FCapacity ---');
   EmitLabel(SymTab[TSLCreateSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TSLItemsOff) + '],0');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TSLCountOff) + '],0');
   EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(TSLCapOff) + '],0');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLCreateSym].IsExternal := False;
  End;

  If TSLAddSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Add(S: String): Integer ---');
   EmitLabel(SymTab[TSLAddSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');    { Self }
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('CMP EAX,DWORD PTR [EBX+' + IntToStr_(TSLCapOff) + ']');
   EmitInstr('JL DPRT_TSLADD_NOGROW');
   EmitInstr('MOV ESI,DWORD PTR [EBX+' + IntToStr_(TSLCapOff) + ']');
   EmitInstr('SHL ESI,1');
   EmitInstr('TEST ESI,ESI');
   EmitInstr('JNZ DPRT_TSLADD_CAPOK');
   EmitInstr('MOV ESI,4');
   EmitLabel('DPRT_TSLADD_CAPOK');
   EmitInstr('MOV EDI,ESI');
   EmitInstr('SHL EDI,2');
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JZ DPRT_TSLADD_ALLOCNEW');
   EmitInstr('CALL GetProcessHeap');
   EmitInstr('PUSH EDI');
   EmitInstr('PUSH DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('PUSH 8');                        { HEAP_ZERO_MEMORY }
   EmitInstr('PUSH EAX');
   EmitInstr('CALL HeapReAlloc');
   EmitInstr('JMP DPRT_TSLADD_GROWDONE');
   EmitLabel('DPRT_TSLADD_ALLOCNEW');
   EmitInstr('CALL GetProcessHeap');
   EmitInstr('PUSH EDI');
   EmitInstr('PUSH 8');                        { HEAP_ZERO_MEMORY }
   EmitInstr('PUSH EAX');
   EmitInstr('CALL HeapAlloc');
   EmitLabel('DPRT_TSLADD_GROWDONE');
   EmitInstr('MOV DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + '],EAX');
   EmitInstr('MOV DWORD PTR [EBX+' + IntToStr_(TSLCapOff) + '],ESI');
   EmitLabel('DPRT_TSLADD_NOGROW');
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('LEA EDI,[EAX+EDX*4]');            { &slot[FCount] }
   { _DPRT_STRASSIGN utilise librement EAX/EBX/ECX/EDX (ce n est pas   }
   { une convention "registres appelant preserves" comme les API       }
   { Win32) : EBX (Self) doit donc etre sauvegarde explicitement        }
   { autour de l appel pour rester valide juste apres (FCount).         }
   EmitInstr('PUSH EBX');                       { sauver Self }
   EmitInstr('PUSH DWORD PTR [EBP+12]');        { S (NewVal), empile en premier }
   EmitInstr('PUSH EDI');                       { Dest addr, en dernier }
   EmitInstr('CALL ' + DPRT_STR_ASSIGN);
   EmitInstr('ADD ESP,8');
   EmitInstr('POP EBX');                        { restaurer Self }
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('INC DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLAddSym].IsExternal := False;
  End;

  If TSLGetSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Get(Index): String ---');
   EmitLabel(SymTab[TSLGetSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBP+12]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+EDX*4]');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLGetSym].IsExternal := False;
  End;

  If TSLDelSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Delete(Index) : libere puis decale ---');
   EmitLabel(SymTab[TSLDelSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EDI,DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('MOV EDX,DWORD PTR [EBP+12]');     { Index }
   EmitInstr('LEA EAX,[EDI+EDX*4]');
   EmitInstr('PUSH EBX');                        { sauver Self (voir Add ci-dessus) }
   EmitInstr('PUSH EDX');                        { sauver Index (aussi ecrase par l appel) }
   EmitInstr('PUSH 0');                          { NewVal = nil }
   EmitInstr('PUSH EAX');                        { Dest addr }
   EmitInstr('CALL ' + DPRT_STR_ASSIGN);
   EmitInstr('ADD ESP,8');
   EmitInstr('POP EDX');                         { restaurer Index }
   EmitInstr('POP EBX');                         { restaurer Self }
   EmitInstr('MOV EDI,DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('MOV ECX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('SUB ECX,EDX');
   EmitInstr('DEC ECX');
   EmitInstr('CMP ECX,0');
   EmitInstr('JLE DPRT_TSLDEL_SKIPSHIFT');
   EmitInstr('PUSH EDI');
   EmitInstr('LEA ESI,[EDI+EDX*4+4]');
   EmitInstr('LEA EDI,[EDI+EDX*4]');
   EmitInstr('CLD');
   EmitInstr('REP MOVSD');
   EmitInstr('POP EDI');
   EmitLabel('DPRT_TSLDEL_SKIPSHIFT');
   { effacer le dernier slot (desormais un doublon brut non compte  }
   { apres le decalage, ou le slot deja libere ci-dessus si aucun    }
   { decalage n a eu lieu - idempotent dans les deux cas) }
   EmitInstr('MOV EAX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('DEC EAX');
   EmitInstr('MOV DWORD PTR [EDI+EAX*4],0');
   EmitInstr('DEC DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLDelSym].IsExternal := False;
  End;

  If TSLClearSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Clear : libere chaque slot puis remet a zero ---');
   EmitLabel(SymTab[TSLClearSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
   EmitInstr('MOV ESI,DWORD PTR [EBX+' + IntToStr_(TSLItemsOff) + ']');
   EmitInstr('MOV ECX,0');
   EmitLabel('DPRT_TSLCLEAR_LOOP');
   EmitInstr('CMP ECX,DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + ']');
   EmitInstr('JGE DPRT_TSLCLEAR_DONE');
   EmitInstr('LEA EAX,[ESI+ECX*4]');
   EmitInstr('PUSH EBX');                        { sauver Self (voir Add ci-dessus) }
   EmitInstr('PUSH ECX');                        { sauver l indice de boucle }
   EmitInstr('PUSH 0');
   EmitInstr('PUSH EAX');
   EmitInstr('CALL ' + DPRT_STR_ASSIGN);
   EmitInstr('ADD ESP,8');
   EmitInstr('POP ECX');
   EmitInstr('POP EBX');                         { restaurer Self }
   EmitInstr('INC ECX');
   EmitInstr('JMP DPRT_TSLCLEAR_LOOP');
   EmitLabel('DPRT_TSLCLEAR_DONE');
   EmitInstr('MOV DWORD PTR [EBX+' + IntToStr_(TSLCountOff) + '],0');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLClearSym].IsExternal := False;
  End;

  If TSLCountSym >= 0 Then
  Begin
   EmitComment('--- TStringList.Count: Integer ---');
   EmitLabel(SymTab[TSLCountSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
   EmitInstr('MOV EAX,DWORD PTR [EAX+' + IntToStr_(TSLCountOff) + ']');
   EmitEpilog;
   EmitBlankLine;
   SymTab[TSLCountSym].IsExternal := False;
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

{ ------------------------------------------------------------ }
{ PPMatchingBracketThenAssign (TODO 16) : lecture seule (restaure }
{ toujours PP), utilisee pour distinguer une ECRITURE de          }
{ propriete indexee (Ident[Index] := ... ou Ident.Prop[Index] :=   }
{ ...) d un simple ACCES en lecture, SANS parser quoi que ce soit.  }
{ StartPP doit pointer sur le '[' ouvrant ; suit la meme technique  }
{ de comptage de profondeur que ParseCallArgs (TODO 10) pour       }
{ retrouver le ']' correspondant, puis verifie que le jeton qui     }
{ suit immediatement est bien ':='.                                 }
{ ------------------------------------------------------------ }

Function PPMatchingBracketThenAssign(StartPP: Integer): Boolean;
Var Save, Depth : Integer;
Begin
 PPMatchingBracketThenAssign := False;
 Save := PP;
 PP := StartPP;
 Depth := 0;
 While Not PPAtEnd Do
 Begin
  If (PPPeekVal = '(') Or (PPPeekVal = '[') Then
   Inc(Depth)
  Else If (PPPeekVal = ')') Or (PPPeekVal = ']') Then
  Begin
   Dec(Depth);
   If Depth = 0 Then
   Begin
    PPAdvance;   { la ']' fermante elle-meme }
    PPMatchingBracketThenAssign := (PPPeekKind = TK_OP) And (PPPeekVal = ':=');
    PP := Save;
    Exit;
   End;
  End;
  PPAdvance;
 End;
 PP := Save;
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
 { Bug trouve en assemblant reellement un vrai programme pour la        }
 { premiere fois (TODO 24) : EmitDataSeg (un seul passage, TODO 07) a     }
 { deja ecrit .DATA bien avant qu un FOR a l interieur d un corps ou du    }
 { bloc principal ne soit atteint (TODO 23, phases Declarations puis       }
 { Routines) - DataAdd seul, sans emission immediate, laissait donc         }
 { LimLbl reference (MOV/CMP) sans jamais etre reellement declare quelque    }
 { part dans le texte .asm. Corrige en re-ouvrant .DATA/.CODE en ligne,       }
 { exactement au point d usage (les directives simplifiees MASM/cet             }
 { assembleur maison acceptent .DATA/.CODE repetes n importe ou dans le           }
 { fichier).                                                                        }
 EmitRaw('.DATA');
 EmitRaw(LimLbl + '  DD 0');
 EmitRaw('.CODE');
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
{ ParseStmtSeq (TODO 18) : suite d instructions jusqu a l un des }
{ mots-cles delimiteurs (END/EXCEPT/FINALLY/UNTIL/ELSE, deja       }
{ reconnus par ParseStmt qui s arrete sans les consommer) - comme   }
{ la boucle interne de ParseCompoundStmt (TODO 13), mais sans le    }
{ BEGIN/END qui l encadre, pour les corps try/except/finally qui    }
{ n en ont pas.                                                       }
{ ------------------------------------------------------------ }

Procedure ParseStmtSeq;
Var SavePP: Integer; Up: TString;
Begin
 While Not PPAtEnd Do
 Begin
  If PPPeekKind = TK_KEYWORD Then
  Begin
   Up := StrUpperCase(PPPeekVal);
   If (Up = 'END') Or (Up = 'EXCEPT') Or (Up = 'FINALLY') Or
      (Up = 'UNTIL') Or (Up = 'ELSE') Then Exit;
  End;
  SavePP := PP;
  ParseStmt;
  SkipOptSemi;
  If PP = SavePP Then PPAdvance;   { filet de securite anti-boucle infinie }
 End;
End;

{ ------------------------------------------------------------ }
{ ParseRaiseStmt (TODO 18) : RAISE expr - leve une exception (via  }
{ _DPRT_RAISE, qui ne revient jamais) ; RAISE ; seul (sans          }
{ expression, uniquement utile a l interieur d un bloc except)       }
{ relance l exception courante (deja dans DPRT_CUREXCEPTION).        }
{ ------------------------------------------------------------ }

Procedure ParseRaiseStmt;
Begin
 PPAdvance;   { raise }
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then
 Begin
  EmitComment('raise; : relance de l exception courante');
  EmitInstr('MOV EAX,DWORD PTR [DPRT_CUREXCEPTION]');
 End
 Else
  ParseExpr;   { EAX = objet exception, typiquement Xxx.Create(...) }
 EmitInstr('CALL ' + DPRT_RAISE);
End;

{ ------------------------------------------------------------ }
{ ParseTryStmt (TODO 18) : TRY <corps> (EXCEPT [ON Ident: Classe   }
{ DO] <gestionnaire> | FINALLY <nettoyage>) END. Aucun SEH natif    }
{ Win32 n est utilise (rien a reutiliser - aucune primitive SEH ni  }
{ prefixe fs: n existe ailleurs dans le fichier) : la spec du       }
{ TODO 18 autorise explicitement le repli sur une pile de            }
{ gestionnaires geree par le runtime (DPRT_EXCSTACK_*, EmitRuntimeData}
{ /EmitRuntimeLibrary) - equivalent a un setjmp/longjmp classique :   }
{ TRY sauvegarde ESP/EBP courants et l adresse du gestionnaire dans   }
{ une case de la pile RUNTIME (profondeur geree dynamiquement, donc   }
{ correcte quel que soit le nombre d appels de procedures entre le    }
{ TRY et le RAISE qui le declenche - contrairement a LoopBreakLbl/    }
{ LoopContLbl, TODO 13, qui sont une pile COMPILE-TIME et ne             }
{ conviendraient pas ici). _DPRT_RAISE restaure ESP/EBP depuis cette   }
{ case puis saute directement dans le gestionnaire.                    }
{ EXCEPT et FINALLY sont mutuellement exclusifs dans un meme TRY       }
{ (comme en Delphi reel - les combiner exige d imbriquer deux TRY).    }
{ FINALLY doit s executer QUE l exception soit levee ou non ; son      }
{ code est donc compile DEUX FOIS (chemin normal, puis chemin           }
{ exception suivi d une relance) en rejouant les memes jetons (PP      }
{ restaure) - LabelGen garantit des etiquettes fraiches a chaque        }
{ compilation, donc aucune collision entre les deux copies.             }
{ ------------------------------------------------------------ }

Procedure ParseTryStmt;
Var
 LblHandler, LblEnd, ExcVarName, ExcTypeName : TString;
 ExcTypeIdx, SI, SavePP : Integer;
Begin
 PPAdvance;   { try }

 LblHandler := LabelGen;
 LblEnd     := LabelGen;

 EmitComment('try : empiler un cadre de gestionnaire d exception');
 EmitInstr('MOV EAX,DWORD PTR [DPRT_EXCTOP]');
 EmitInstr('MOV DWORD PTR [DPRT_EXCSTACK_ESP+EAX*4],ESP');
 EmitInstr('MOV DWORD PTR [DPRT_EXCSTACK_EBP+EAX*4],EBP');
 EmitInstr('MOV DWORD PTR [DPRT_EXCSTACK_HANDLER+EAX*4],OFFSET ' + LblHandler);
 EmitInstr('INC EAX');
 EmitInstr('MOV DWORD PTR [DPRT_EXCTOP],EAX');

 ParseStmtSeq;   { corps protege }

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'FINALLY') Then
 Begin
  PPAdvance;   { finally }

  EmitComment('finally (chemin normal) : depiler le cadre puis nettoyer');
  EmitInstr('DEC DWORD PTR [DPRT_EXCTOP]');
  SavePP := PP;
  ParseStmtSeq;
  EmitInstr('JMP ' + LblEnd);

  EmitComment('finally (chemin exception, cadre deja depile) : ' +
   'nettoyer puis relancer');
  EmitLabel(LblHandler);
  PP := SavePP;
  ParseStmtSeq;
  EmitInstr('MOV EAX,DWORD PTR [DPRT_CUREXCEPTION]');
  EmitInstr('CALL ' + DPRT_RAISE);

  EmitLabel(LblEnd);
  PPMatch('end');
  SkipOptSemi;
  Exit;
 End;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'EXCEPT') Then
 Begin
  PPAdvance;   { except }

  EmitComment('except (chemin normal) : depiler le cadre, sauter le ' +
   'gestionnaire');
  EmitInstr('DEC DWORD PTR [DPRT_EXCTOP]');
  EmitInstr('JMP ' + LblEnd);

  EmitLabel(LblHandler);
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'ON') Then
  Begin
   PPAdvance;   { on }
   ExcVarName := TokenPool[PP].Val;
   PPAdvance;   { E }
   PPMatch(':');
   ExcTypeName := TokenPool[PP].Val;
   PPAdvance;   { Classe }

   { Aucune verification dynamique du type (pas de vraie RTTI d       }
   { instance - meme simplification que is/as, TODO 15) : E est lie     }
   { inconditionnellement. ExcTypeIdx sert seulement a typer E pour     }
   { l acces a ses membres (Message, ClassName...).                      }
   ExcTypeIdx := TypeFindByName(ExcTypeName);
   If ExcTypeIdx < 0 Then
   Begin
    SI := SymFind(ExcTypeName);
    If SI >= 0 Then ExcTypeIdx := SymTab[SI].TypeIdx;
   End;
   If ExcTypeIdx < 0 Then ExcTypeIdx := TypeFindByName('Integer');

   If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'DO') Then
    PPAdvance;

   { E : alias direct vers la variable globale DPRT_CUREXCEPTION -      }
   { aucune copie locale necessaire (meme technique que les proprietes  }
   { en lecture directe sur un champ, TODO 16).                          }
   SI := SymAdd(ExcVarName, SK_VAR, ExcTypeIdx);
   If SI >= 0 Then
   Begin
    SymTab[SI].IsGlobal    := True;
    SymTab[SI].MangledName := 'DPRT_CUREXCEPTION';
   End;
  End;

  ParseStmtSeq;

  EmitLabel(LblEnd);
  PPMatch('end');
  SkipOptSemi;
  Exit;
 End;

 { ni FINALLY ni EXCEPT : bloc TRY vide de fait - depiler le cadre }
 { par securite avant de continuer.                                  }
 EmitInstr('DEC DWORD PTR [DPRT_EXCTOP]');
 PPMatch('end');
 SkipOptSemi;
End;

{ ============================================================ }
{ TODO 21 - INSTRUCTION ASM (BLOC ASSEMBLEUR EN LIGNE) [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ IsAsmReg : tester si un identificateur designe un registre     }
{ 80386. Aucune table de traduction 8086->386 n est necessaire   }
{ ici (contrairement a TPCW32) : Delphi cible directement le     }
{ 32 bits.                                                        }
{ ------------------------------------------------------------ }

Function IsAsmReg(Const S: TString): Boolean;
Var Up: TString;
Begin
 Up := StrUpperCase(S);
 IsAsmReg :=
  (Up = 'EAX') Or (Up = 'EBX') Or (Up = 'ECX') Or (Up = 'EDX') Or
  (Up = 'ESI') Or (Up = 'EDI') Or (Up = 'EBP') Or (Up = 'ESP') Or
  (Up = 'AX')  Or (Up = 'BX')  Or (Up = 'CX')  Or (Up = 'DX')  Or
  (Up = 'SI')  Or (Up = 'DI')  Or (Up = 'BP')  Or (Up = 'SP')  Or
  (Up = 'AL')  Or (Up = 'AH')  Or (Up = 'BL')  Or (Up = 'BH')  Or
  (Up = 'CL')  Or (Up = 'CH')  Or (Up = 'DL')  Or (Up = 'DH')  Or
  (Up = 'CS')  Or (Up = 'DS')  Or (Up = 'ES')  Or (Up = 'SS')  Or
  (Up = 'FS')  Or (Up = 'GS');
End;

{ ------------------------------------------------------------ }
{ AsmTrimSpaces : supprimer les espaces en debut et fin d une     }
{ chaine. Les operandes d un bloc asm sont reconstruits en        }
{ joignant les jetons par des espaces, y compris a l interieur    }
{ d une reference [...] - ce que MASM tolere sans probleme.       }
{ ------------------------------------------------------------ }

Function AsmTrimSpaces(Const S: TString): TString;
Var A, B: Integer;
Begin
 A := 1;
 While (A <= Length(S)) And (S[A] = ' ') Do Inc(A);
 B := Length(S);
 While (B >= A) And (S[B] = ' ') Do Dec(B);
 AsmTrimSpaces := Copy(S, A, B - A + 1);
End;

{ ------------------------------------------------------------ }
{ AsmVarBracketInner : interieur (sans crochets) de la reference  }
{ memoire d une variable/parametre/globale Pascal connue (via     }
{ GenVarBracket, TODO 09) - pour composer un operande adresse      }
{ manuel comme [EBX+MaVariable] a l interieur d un bloc asm.       }
{ Retourne Name inchange si inconnu (immediat, etiquette locale). }
{ ------------------------------------------------------------ }

Function AsmVarBracketInner(Const Name: TString): TString;
Var B: TString;
Begin
 B := GenVarBracket(Name);
 If Length(B) >= 2 Then
  AsmVarBracketInner := Copy(B, 2, Length(B) - 2)
 Else
  AsmVarBracketInner := Name;
End;

{ ------------------------------------------------------------ }
{ AsmFieldOperand : traduire un operande compose 'Base.Champ'     }
{ (Self.Champ, ou Variable-objet.Champ) en operande memoire       }
{ complet (via GenFieldRef, TODO 09/15). x86 n a pas d adressage  }
{ indirect double : le pointeur Base est d abord charge dans EDX  }
{ (registre de travail, meme convention que GenVarAddr) - une      }
{ ligne asm utilisant Self.Champ ou Objet.Champ ne doit donc pas   }
{ compter sur la valeur preexistante de EDX. Simplification         }
{ documentee : un seul niveau de champ est gere (pas de             }
{ Self.Champ1.Champ2), et l usage a l interieur d une reference    }
{ [...] n est pas gere (Self.Champ s utilise seul, sans crochets    }
{ englobants - GenFieldRef fournit deja les crochets necessaires). }
{ ------------------------------------------------------------ }

Function AsmFieldOperand(Const BaseName, FieldName: TString): TString;
Var
 SI, ClassTI : Integer;
 Base, Fld, Up : TString;
Begin
 Base := AsmTrimSpaces(BaseName);
 Fld  := AsmTrimSpaces(FieldName);
 AsmFieldOperand := Base + '.' + Fld;   { repli si non resolu }
 Up := StrUpperCase(Base);

 If Up = 'SELF' Then
 Begin
  If CurSelfTypeIdx < 0 Then
  Begin
   WarnMsg('Self utilise dans un bloc asm hors d une methode');
   Exit;
  End;
  EmitInstr('MOV EDX,' + GenVarRef('SELF'));
  AsmFieldOperand := GenFieldRef('EDX', CurSelfTypeIdx, Fld);
  Exit;
 End;

 SI := SymFind(Base);
 If SI < 0 Then Exit;
 If Not TypeIsClass(SymTab[SI].TypeIdx) Then Exit;
 ClassTI := TypeResolve(SymTab[SI].TypeIdx);

 EmitInstr('MOV EDX,' + GenVarRef(Base));
 AsmFieldOperand := GenFieldRef('EDX', ClassTI, Fld);
End;

{ ------------------------------------------------------------ }
{ TranslateAsmOperand : traduire un operande d instruction asm    }
{ (registre, reference memoire [...], champ Self./Objet., ou      }
{ variable/parametre/globale/routine Pascal simple) en operande   }
{ MASM final. Un immediat, une etiquette locale (@Nom) ou un mot- }
{ cle de taille (BYTE/WORD/DWORD/PTR/SHORT/NEAR...) traverse       }
{ inchange.                                                        }
{ ------------------------------------------------------------ }

Function TranslateAsmOperand(Const Op: TString): TString;
Var
 Up, R, Tok, Prefix, Bracket : TString;
 I, BPos, DotPos : Integer;
 C : Char;
Begin
 TranslateAsmOperand := Op;
 If Length(Op) = 0 Then Exit;

 Up := StrUpperCase(Op);
 If IsAsmReg(Up) Then Begin TranslateAsmOperand := Up; Exit; End;

 { reference memoire, avec eventuel prefixe de taille avant le '[' }
 BPos := Pos('[', Op);
 If (BPos > 0) And (Op[Length(Op)] = ']') Then
 Begin
  Prefix  := Copy(Op, 1, BPos - 1);
  Bracket := Copy(Op, BPos, Length(Op) - BPos + 1);

  R := '[';
  I := 2;
  While I <= Length(Bracket) Do
  Begin
   C := Bracket[I];
   If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
      (C = '_') Then
   Begin
    Tok := '';
    While (I <= Length(Bracket)) And
          (((Bracket[I] >= 'A') And (Bracket[I] <= 'Z')) Or
           ((Bracket[I] >= 'a') And (Bracket[I] <= 'z')) Or
           ((Bracket[I] >= '0') And (Bracket[I] <= '9')) Or
           (Bracket[I] = '_')) Do
    Begin
     Tok := Tok + Bracket[I];
     Inc(I);
    End;
    If IsAsmReg(Tok) Then
     R := R + StrUpperCase(Tok)
    Else If SymFind(Tok) >= 0 Then
     R := R + AsmVarBracketInner(Tok)
    Else
     R := R + Tok;
   End
   Else Begin R := R + C; Inc(I); End;
  End;

  TranslateAsmOperand := Prefix + R;
  Exit;
 End;

 { champ d instance : Self.Champ ou Objet.Champ (sans crochets) }
 DotPos := Pos('.', Op);
 If DotPos > 0 Then
 Begin
  TranslateAsmOperand :=
   AsmFieldOperand(Copy(Op, 1, DotPos - 1),
    Copy(Op, DotPos + 1, Length(Op) - DotPos));
  Exit;
 End;

 { identificateur simple : variable/parametre/globale/routine connue }
 If ((Op[1] >= 'A') And (Op[1] <= 'Z')) Or
    ((Op[1] >= 'a') And (Op[1] <= 'z')) Or (Op[1] = '_') Then
 Begin
  I := SymFind(Op);
  If I >= 0 Then
  Begin
   If SymTab[I].Kind In [SK_PROC, SK_FUNC, SK_METHOD] Then
    TranslateAsmOperand := SymTab[I].MangledName
   Else
    TranslateAsmOperand := GenVarRef(Op);
   Exit;
  End;
 End;

 { sinon : immediat, etiquette locale (@Nom), mot-cle de taille... }
 TranslateAsmOperand := Op;
End;

{ ------------------------------------------------------------ }
{ AsmTranslateOperandList : decouper une liste d operandes        }
{ separes par des virgules (profondeur 0, hors crochets) et       }
{ traduire chacun via TranslateAsmOperand.                         }
{ ------------------------------------------------------------ }

Function AsmTranslateOperandList(Const S: TString): TString;
Var
 R, Cur : TString;
 I, Depth : Integer;
 C : Char;
Begin
 R := ''; Cur := ''; Depth := 0;
 For I := 1 To Length(S) Do
 Begin
  C := S[I];
  If C = '[' Then Inc(Depth);
  If C = ']' Then Dec(Depth);
  If (C = ',') And (Depth = 0) Then
  Begin
   If Length(R) > 0 Then R := R + ',';
   R := R + TranslateAsmOperand(AsmTrimSpaces(Cur));
   Cur := '';
  End
  Else
   Cur := Cur + C;
 End;
 If Length(AsmTrimSpaces(Cur)) > 0 Then
 Begin
  If Length(R) > 0 Then R := R + ',';
  R := R + TranslateAsmOperand(AsmTrimSpaces(Cur));
 End;
 AsmTranslateOperandList := R;
End;

{ ------------------------------------------------------------ }
{ ParseAsmInstr : lire une instruction asm (jusqu au ';' ou au    }
{ END du bloc), la reconstruire en une ligne textuelle a partir   }
{ des jetons (chaque jeton separe par un espace - '@' colle a     }
{ l identificateur qui suit pour former une etiquette locale de   }
{ saut, ex: @Boucle), puis separer mnemonique et operandes et      }
{ emettre l instruction traduite.                                  }
{ ------------------------------------------------------------ }

Procedure ParseAsmInstr;
Var
 LineTxt, Mne, Rest : TString;
 I : Integer;
Begin
 LineTxt := '';
 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then Break;
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'END') Then Break;

  If Length(LineTxt) > 0 Then LineTxt := LineTxt + ' ';

  If (PPPeekKind = TK_OP) And (PPPeekVal = '@') And ((PP + 1) < TokenCount) And
     (TokenPool[PP + 1].Kind In [TK_IDENT, TK_KEYWORD]) Then
  Begin
   LineTxt := LineTxt + '@' + TokenPool[PP + 1].Val;
   PPAdvance; PPAdvance;
  End
  Else
  Begin
   LineTxt := LineTxt + TokenPool[PP].Val;
   PPAdvance;
  End;
 End;

 LineTxt := AsmTrimSpaces(LineTxt);
 If Length(LineTxt) = 0 Then Exit;

 I := 1;
 While (I <= Length(LineTxt)) And (LineTxt[I] <> ' ') Do Inc(I);
 Mne  := Copy(LineTxt, 1, I - 1);
 Rest := AsmTrimSpaces(Copy(LineTxt, I, Length(LineTxt) - I + 1));

 If Length(Rest) = 0 Then
  EmitInstr(StrUpperCase(Mne))
 Else
  EmitInstr(StrUpperCase(Mne) + ' ' + AsmTranslateOperandList(Rest));
End;

{ ------------------------------------------------------------ }
{ ParseAsmBlock : bloc ASM ... END. Accepte les etiquettes        }
{ locales (Nom: ou @Nom:) et traduit chaque instruction via        }
{ ParseAsmInstr. Assembleur 80386 natif : aucune table de          }
{ traduction de mnemoniques n est necessaire (contrairement a      }
{ TPCW32, qui traduit du 8086 vers le 386) - seuls les operandes    }
{ (variables/champs Pascal) sont reecrits.                          }
{ ------------------------------------------------------------ }

Procedure ParseAsmBlock;
Var LblName : TString;
Begin
 EmitComment('--- debut bloc asm (TODO 21) ---');
 PPAdvance;   { consommer ASM }

 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'END') Then
  Begin
   PPAdvance;
   Break;
  End;

  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then
  Begin
   PPAdvance;
   Continue;
  End;

  LblName := '';

  If (PPPeekKind = TK_OP) And (PPPeekVal = '@') And ((PP + 1) < TokenCount) And
     (TokenPool[PP + 1].Kind In [TK_IDENT, TK_KEYWORD]) And
     ((PP + 2) < TokenCount) And (TokenPool[PP + 2].Kind = TK_PUNCT) And
     (TokenPool[PP + 2].Val = ':') Then
  Begin
   LblName := '@' + TokenPool[PP + 1].Val;
   PPAdvance; PPAdvance; PPAdvance;
  End
  Else If (PPPeekKind In [TK_IDENT, TK_KEYWORD]) And ((PP + 1) < TokenCount) And
     (TokenPool[PP + 1].Kind = TK_PUNCT) And (TokenPool[PP + 1].Val = ':') Then
  Begin
   LblName := TokenPool[PP].Val;
   PPAdvance; PPAdvance;
  End;

  If Length(LblName) > 0 Then
  Begin
   EmitLabel(LblName);
   Continue;
  End;

  ParseAsmInstr;
 End;

 SkipOptSemi;
 EmitComment('--- fin bloc asm ---');
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
 SI, BaseTypeIdx, FI, First, Cnt, PropIdx : Integer;
 ElemTypeIdx, ElemSize : Integer;
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
  If Up = 'EXCEPT' Then Exit;    { TODO 18 : borne d un bloc try, jamais }
  If Up = 'FINALLY' Then Exit;   { consommee ici - voir ParseStmtSeq     }

  If Up = 'BEGIN' Then Begin ParseCompoundStmt; Exit; End;
  If Up = 'IF' Then Begin ParseIfStmt; Exit; End;
  If Up = 'WHILE' Then Begin ParseWhileStmt; Exit; End;
  If Up = 'REPEAT' Then Begin ParseRepeatStmt; Exit; End;
  If Up = 'FOR' Then Begin ParseForStmt; Exit; End;
  If Up = 'CASE' Then Begin ParseCaseStmt; Exit; End;
  If Up = 'TRY' Then Begin ParseTryStmt; Exit; End;
  If Up = 'RAISE' Then Begin ParseRaiseStmt; Exit; End;
  If Up = 'ASM' Then Begin ParseAsmBlock; Exit; End;

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

  { Ident[Index] := expr : indexation de tableau (TODO 19), ou repli   }
  { sur la propriete tableau par defaut (TODO 16) si Ident n est pas    }
  { un tableau - meme jeton declencheur, distingue par le type de Ident.}
  If (PP + 1 < TokenCount) And (TokenPool[PP + 1].Kind = TK_PUNCT) And
     (TokenPool[PP + 1].Val = '[') And PPMatchingBracketThenAssign(PP + 1) Then
  Begin
   SI := SymFind(Name);
   If SI < 0 Then
   Begin
    WarnMsg('identificateur inconnu: ' + Name);
    PPAdvance;
    ParseExpr;
    Exit;
   End;

   BaseTypeIdx := TypeResolve(SymTab[SI].TypeIdx);

   If (BaseTypeIdx >= 0) And (BaseTypeIdx < TypeCount) And
      (TypeTab[BaseTypeIdx].Kind = TYK_ARRAY) Then
   Begin
    { Ecriture indexee (TODO 19) : meme calcul d adresse que la        }
    { lecture (ParsePostfix) - EBX joue le role de "case 0", que le     }
    { tableau soit statique (adresse) ou dynamique (pointeur charge     }
    { par valeur, Lo toujours 0).                                        }
    PPAdvance;                   { ident }
    GenLoadVar(Name);
    EmitInstr('MOV EBX,EAX');
    PPAdvance;                    { [ }
    ElemTypeIdx := TypeTab[BaseTypeIdx].BaseTypeIdx;
    ElemSize    := TypeSizeofIdx(ElemTypeIdx);
    ParseExpr;                     { EAX = index }
    If TypeTab[BaseTypeIdx].Lo <> 0 Then
     EmitInstr('SUB EAX,' + IntToStr_(TypeTab[BaseTypeIdx].Lo));
    If ElemSize <> 1 Then
     EmitInstr('IMUL EAX,' + IntToStr_(ElemSize));
    EmitInstr('ADD EBX,EAX');
    PPMatch(']');
    PPMatch(':=');
    { EBX (adresse cible) doit survivre a l evaluation du RHS, qui peut  }
    { elle-meme utiliser EBX comme registre de travail pour un operateur }
    { binaire (ex. (I+1)*10, IMUL EAX,EBX) - sans cette sauvegarde,       }
    { l ecriture finale visait une adresse ecrasee par le dernier         }
    { operande du RHS au lieu de la case du tableau (bogue confirme par   }
    { execution reelle, TODO 25).                                          }
    EmitInstr('PUSH EBX');
    ParseExpr;                      { EAX = valeur a ecrire }
    EmitInstr('POP EBX');
    If TypeNeedsDestAddr(ElemTypeIdx) Then
     EmitAssign('EBX', 'EAX', ElemTypeIdx)
    Else
     EmitAssign(SizedPtr(ElemTypeIdx) + '[EBX]', 'EAX', ElemTypeIdx);
    Exit;
   End;

   PropIdx := -1;
   If (BaseTypeIdx >= 0) And (BaseTypeIdx < TypeCount) And
      (TypeTab[BaseTypeIdx].Kind = TYK_CLASS) Then
    PropIdx := PropFindDefault(BaseTypeIdx);

   If PropIdx < 0 Then
   Begin
    WarnMsg('propriete tableau par defaut introuvable pour: ' + Name);
    PPAdvance;
    While Not ((PPPeekKind = TK_OP) And (PPPeekVal = ':=')) Do PPAdvance;
    PPAdvance;
    ParseExpr;
    Exit;
   End;

   PPAdvance;                   { ident }
   GenLoadVar(Name);             { EAX = reference de l objet }
   EmitInstr('PUSH EAX');         { Self, sauvegarde temporaire }
   GenIndexedPropertyAssign(BaseTypeIdx, PropIdx, Name);
   Exit;
  End;

  { Propriete indexee nommee (TODO 16) : Ident.Prop[Index] := expr }
  If (PP + 1 < TokenCount) And (TokenPool[PP + 1].Kind = TK_PUNCT) And
     (TokenPool[PP + 1].Val = '.') And (PP + 3 < TokenCount) And
     (TokenPool[PP + 3].Kind = TK_PUNCT) And (TokenPool[PP + 3].Val = '[') And
     PPMatchingBracketThenAssign(PP + 3) Then
  Begin
   SI := SymFind(Name);
   If SI < 0 Then
   Begin
    WarnMsg('identificateur inconnu: ' + Name);
    PPAdvance; PPAdvance; PPAdvance;
    ParseExpr;
    Exit;
   End;

   BaseTypeIdx := TypeResolve(SymTab[SI].TypeIdx);
   PPAdvance;                   { ident }
   GenLoadVar(Name);             { EAX = reference de l objet }
   EmitInstr('PUSH EAX');         { Self, sauvegarde temporaire }
   PPAdvance;                     { . }
   FieldName := StrUpperCase(TokenPool[PP].Val);
   PPAdvance;                     { Prop }

   PropIdx := -1;
   If (BaseTypeIdx >= 0) And (BaseTypeIdx < TypeCount) Then
    PropIdx := PropFindInClassChain(BaseTypeIdx, FieldName);

   If PropIdx < 0 Then
   Begin
    WarnMsg('propriete indexee inconnue: ' + FieldName);
    EmitInstr('ADD ESP,4');       { Self empile plus haut, non consomme }
    While Not ((PPPeekKind = TK_OP) And (PPPeekVal = ':=')) Do PPAdvance;
    PPAdvance;
    ParseExpr;
    Exit;
   End;

   GenIndexedPropertyAssign(BaseTypeIdx, PropIdx, FieldName);
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
       { EBX (Self) doit survivre a l evaluation du RHS, qui peut elle-  }
       { meme utiliser EBX comme registre de travail pour un operateur   }
       { binaire (meme bogue que l indexation de tableau, TODO 25).       }
       EmitInstr('PUSH EBX');
       ParseExpr;   { EAX = valeur du membre droit }
       EmitInstr('POP EBX');
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

   { Pas un champ : propriete simple (non indexee, TODO 16) ? Le       }
   { setter peut lui-meme etre un champ (property X: T read FX         }
   { write FX) - repasse alors par exactement le meme code d ecriture   }
   { de champ que ci-dessus (offset/TypeNeedsDestAddr), ou une methode  }
   { (Procedure SetX(Value: T), appelee avec Self en dernier argument,  }
   { meme convention que tout appel de methode).                        }
   If Not Found And (BaseTypeIdx >= 0) And (BaseTypeIdx < TypeCount) Then
   Begin
    PropIdx := PropFindInClassChain(BaseTypeIdx, FieldName);
    If (PropIdx >= 0) And Not PropPool[PropIdx].IsIndexed Then
    Begin
     Found := True;
     If PropPool[PropIdx].WriteName = '' Then
     Begin
      WarnMsg('propriete en lecture seule: ' + FieldName);
      ParseExpr;
     End
     Else
     Begin
      FI := FieldFindInClass(BaseTypeIdx, PropPool[PropIdx].WriteName);
      If FI >= 0 Then
      Begin
       EmitInstr('PUSH EBX');   { Self doit survivre au RHS, voir ci-dessus }
       ParseExpr;   { EAX = valeur du membre droit }
       EmitInstr('POP EBX');
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
      End
      Else
      Begin
       EmitInstr('PUSH EBX');          { Self doit survivre au RHS, voir ci-dessus }
       ParseExpr;                    { EAX = valeur du membre droit }
       EmitInstr('POP EBX');
       EmitInstr('PUSH EAX');          { valeur }
       EmitInstr('PUSH EBX');          { Self, en dernier }
       GenPropertyAccessorCall(BaseTypeIdx, PropPool[PropIdx].WriteName, 8);
      End;
     End;
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
 HasExcPush, HasExcPop, HasReRaise : Boolean;

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

 { --- Try..Finally : geree par une pile de gestionnaires runtime,    }
 { TODO 18 - le contenu des DEUX blocs (protege et nettoyage) est      }
 { desormais reellement compile (plus un stub qui ignore tout).        }
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
 StmtAssert('try..finally consomme tout le bloc jusqu au END correspondant',
  PPAtEnd);

 HasWriteStr := False;
 HasExcPush := False; HasExcPop := False; HasReRaise := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_WRITESTR, Line) > 0 Then HasWriteStr := True;
  If Pos('MOV DWORD PTR [DPRT_EXCTOP],EAX', Line) > 0 Then HasExcPush := True;
  If Pos('DEC DWORD PTR [DPRT_EXCTOP]', Line) > 0 Then HasExcPop := True;
  If Pos('CALL ' + DPRT_RAISE, Line) > 0 Then HasReRaise := True;
 End;
 Close(F); Erase(F);
 StmtAssert('try..finally compile bien le contenu des deux blocs',
  HasWriteStr);
 StmtAssert('try empile un cadre de gestionnaire (DPRT_EXCTOP)',
  HasExcPush);
 StmtAssert('finally (chemin normal) depile le cadre', HasExcPop);
 StmtAssert('finally relance apres nettoyage (chemin exception)',
  HasReRaise);

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
{ mutuellement. ParseTypeExpr (TODO 19, definie bien plus bas avec     }
{ ParseTypeDecl) analyse le type d une variable locale, y compris      }
{ array/record/set inline.                                              }
Procedure ParseProcOrFuncDecl; Forward;
Function ParseTypeExpr: Integer; Forward;

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
   TIdx := ParseTypeExpr;   { nom simple, ou array/record/set inline (TODO 19) }

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

 { Une signature rencontree dans la section INTERFACE d une Unit       }
 { (TODO 23) n a jamais de corps ici (il vient plus tard, dans          }
 { IMPLEMENTATION) : traitee comme un FORWARD implicite, exactement      }
 { comme IsForwardOnly ci-dessous.                                        }
 If IsForwardOnly Or InInterfaceSection Then
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
 IUnkIdx, IUnkTypeIdx : Integer;
 I, SubIdx, SubTypeIdx : Integer;
 ExcSubNames : Array[0..3] Of TString;
 TListIdx2, TListTypeIdx, TSLIdx2, TSLTypeIdx : Integer;
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
   { FMessage (TODO 18) : champ cache derriere Exception.Message/     }
   { Create(Msg), corps reels ecrits directement dans                 }
   { EmitRuntimeLibrary (comme TObject.Create/Destroy/Free, TODO 15). }
   TypeAddField(ExcTypeIdx, 'FMESSAGE', TypeFindByName('String'));
  End;

  { Hierarchie minimale d exceptions (TODO 18) : memes champs/VMT que }
  { Exception (aucun ajout propre), simplement idempotent comme       }
  { ci-dessus.                                                          }
  ExcSubNames[0] := 'EDivByZero';
  ExcSubNames[1] := 'EInvalidCast';
  ExcSubNames[2] := 'EAccessViolation';
  ExcSubNames[3] := 'ERangeError';
  For I := 0 To 3 Do
  Begin
   SubIdx := SymFind(ExcSubNames[I]);
   If SubIdx >= 0 Then
   Begin
    SubTypeIdx := SymTab[SubIdx].TypeIdx;
    If TypeTab[SubTypeIdx].FieldFirst < 0 Then
    Begin
     FieldInitInherit(SubTypeIdx);
     VMTInit(SubTypeIdx);
    End;
   End;
  End;
 End;

 { IUnknown (TODO 17) : racine des interfaces, meme traitement que    }
 { TObject ci-dessus mais sans FieldInitInherit (une interface n a     }
 { pas de disposition memoire propre, seulement une VMT de signatures).}
 IUnkIdx := SymFind('IUnknown');
 If IUnkIdx >= 0 Then
 Begin
  IUnkTypeIdx := SymTab[IUnkIdx].TypeIdx;
  If TypeTab[IUnkTypeIdx].VMTFirst < 0 Then
  Begin
   VMTInit(IUnkTypeIdx);
   VMTAddMethod(IUnkTypeIdx, 'QUERYINTERFACE', -1);
   VMTAddMethod(IUnkTypeIdx, 'ADDREF', -1);
   VMTAddMethod(IUnkTypeIdx, 'RELEASE', -1);
  End;
 End;

 { TList/TStringList (TODO 22, Classes minimal) : memes 3 champs      }
 { caches (stockage brut, compteur, capacite) - Create/Add/Get/        }
 { Delete/Clear/Count ont leurs corps reels ecrits directement dans     }
 { EmitRuntimeLibrary, comme TObject/Exception ci-dessus.                }
 TListIdx2 := SymFind('TList');
 If TListIdx2 >= 0 Then
 Begin
  TListTypeIdx := SymTab[TListIdx2].TypeIdx;
  If TypeTab[TListTypeIdx].FieldFirst < 0 Then
  Begin
   FieldInitInherit(TListTypeIdx);
   VMTInit(TListTypeIdx);
   TypeAddField(TListTypeIdx, 'FITEMS', TypeFindByName('Pointer'));
   TypeAddField(TListTypeIdx, 'FCOUNT', TypeFindByName('Integer'));
   TypeAddField(TListTypeIdx, 'FCAPACITY', TypeFindByName('Integer'));
  End;
 End;

 TSLIdx2 := SymFind('TStringList');
 If TSLIdx2 >= 0 Then
 Begin
  TSLTypeIdx := SymTab[TSLIdx2].TypeIdx;
  If TypeTab[TSLTypeIdx].FieldFirst < 0 Then
  Begin
   FieldInitInherit(TSLTypeIdx);
   VMTInit(TSLTypeIdx);
   TypeAddField(TSLTypeIdx, 'FITEMS', TypeFindByName('Pointer'));
   TypeAddField(TSLTypeIdx, 'FCOUNT', TypeFindByName('Integer'));
   TypeAddField(TSLTypeIdx, 'FCAPACITY', TypeFindByName('Integer'));
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
{ EmitClassVMTs (TODO 25) : ecrire la vraie table VMT de chaque    }
{ classe (DD <nom mangled>,<nom mangled>,... - un pointeur de        }
{ methode par emplacement, dans l ordre des offsets deja fixes par     }
{ VMTInit/VMTAddMethod) - l emission promise depuis le TODO 07/08/24     }
{ mais jamais ecrite (VMTLabelFor ne faisait que NOMMER le label de       }
{ facon deterministe). Appelee APRES ParseTopLevelRoutines (pas depuis     }
{ EmitDataSeg elle-meme, deja fermee a ce stade du fichier) : IsExternal    }
{ ne distingue fiablement "abstraite/externe, jamais de corps" de            }
{ "corps pas encore analyse" qu une fois TOUS les corps hors-ligne              }
{ analyses (ParseMethodBodyDecl remet IsExternal a False au moment ou            }
{ elle fournit le corps reel, TODO 14/15) - une methode encore IsExternal          }
{ a CE stade est donc reellement abstraite/externe, et recoit un pointeur           }
{ NUL (comme le ferait un vrai Delphi pour une methode abstraite jamais              }
{ appelee) plutot qu une etiquette qui n existera jamais dans le texte .asm            }
{ (l assembleur echouerait sinon avec 'etiquette introuvable'). Reutilise                }
{ le meme "reouvrir .DATA/.CODE en ligne" que DataAddSetConst/ParseForStmt                }
{ (TODO 13/19/24), puisque .DATA/.CODE sont deja fermes ici.                                }
{ ------------------------------------------------------------ }

Procedure EmitClassVMTs;
Var
 I, J, MSym : Integer;
 S : TString;
Begin
 EmitRaw('.DATA');
 EmitComment('--- Tables VMT (TODO 25) ---');
 For I := 0 To TypeCount - 1 Do
  If (TypeTab[I].Kind = TYK_CLASS) And (TypeTab[I].VMTFirst >= 0) And
     (TypeTab[I].VMTCount > 0) Then
  Begin
   S := '';
   For J := TypeTab[I].VMTFirst To
    TypeTab[I].VMTFirst + TypeTab[I].VMTCount - 1 Do
   Begin
    If S <> '' Then S := S + ',';
    MSym := VMTEntryPool[J].MethodSymIdx;
    If (MSym >= 0) And (Not SymTab[MSym].IsExternal) Then
     S := S + SymTab[MSym].MangledName
    Else
     S := S + '0';
   End;
   EmitRaw(VMTLabelFor(I) + '  DD ' + S);
  End;
 EmitRaw('.CODE');
End;

{ ------------------------------------------------------------ }
{ VMTMethodSymAtOffset : retrouver le symbole de methode place    }
{ par VMTAddMethod a un offset VMT donne, pour une classe. Utilise }
{ par EmitInterfaceThunks (TODO 25) pour retrouver le nom mangled  }
{ reel derriere l offset deja calcule par ClassImplementInterface  }
{ (TODO 17, ClassVMTOffset).                                        }
{ ------------------------------------------------------------ }

Function VMTMethodSymAtOffset(ClassTypeIdx, TargetOffset: Integer): Integer;
Var J : Integer;
Begin
 VMTMethodSymAtOffset := -1;
 If TypeTab[ClassTypeIdx].VMTFirst < 0 Then Exit;
 For J := TypeTab[ClassTypeIdx].VMTFirst To
  TypeTab[ClassTypeIdx].VMTFirst + TypeTab[ClassTypeIdx].VMTCount - 1 Do
  If VMTEntryPool[J].Offset = TargetOffset Then
  Begin
   VMTMethodSymAtOffset := VMTEntryPool[J].MethodSymIdx;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitInterfaceThunks (TODO 25) : pour chaque implementation      }
{ classe/interface (IfaceImplTab, TODO 17), ecrit la vraie table   }
{ de thunks - le morceau explicitement differe depuis le TODO 17    }
{ ("l emission reelle de la table de thunks elle-meme (donnees +     }
{ code des trampolines) reste differee au TODO 24"), qui n avait       }
{ finalement pas ete fait non plus en TODO 24. Sans cette table,         }
{ un appel de methode via une variable d interface (G.Methode, ou G       }
{ est typee IGreeter) utilisait l offset VMT propre a l INTERFACE          }
{ (QueryInterface=0/AddRef=4/Release=8/Methode=12) applique a la            }
{ VMT REELLE de la classe (qui commence par Destroy, herite de               }
{ TObject, decalant tout de 4) - atterrissant silencieusement sur             }
{ la MAUVAISE methode (ex: Release au lieu de Methode). Chaque                 }
{ thunk retranche l offset du champ cache (ClassImplementInterface)             }
{ de "Self" (qui, vu par le thunk, est l ADRESSE de ce champ cache -             }
{ voir EmitAssign/TYK_INTERFACE) pour retrouver l adresse reelle de              }
{ l objet, puis saute (JMP, pas CALL : appel terminal, aucun retour              }
{ a corriger) vers la vraie methode - Self est TOUJOURS le dernier              }
{ argument empile par l appelant (TODO 09/14), donc systematiquement            }
{ a [ESP+4] a l entree d une fonction quel que soit son nombre de               }
{ parametres reels : le thunk n a besoin d aucun prolog/epilog.                 }
{ ------------------------------------------------------------ }

Procedure EmitInterfaceThunks;
Var
 I, K, MSym : Integer;
 ThunkLbl, VTblBody, Entry : TString;
Begin
 If IfaceImplCount = 0 Then Exit;
 EmitComment('--- Tables de thunks d interface (TODO 25) ---');
 For I := 0 To IfaceImplCount - 1 Do
 Begin
  If Length(IfaceImplTab[I].VTblLabel) = 0 Then Continue;

  EmitRaw('.CODE');
  VTblBody := '';
  For K := 0 To IfaceImplTab[I].ThunkCount - 1 Do
  Begin
   MSym := VMTMethodSymAtOffset(IfaceImplTab[I].ClassTypeIdx,
    ThunkPool[IfaceImplTab[I].ThunkFirst + K].VMTOffset);
   If (MSym >= 0) And (Not SymTab[MSym].IsExternal) Then
   Begin
    ThunkLbl := IfaceImplTab[I].VTblLabel + '_T' + IntToStr_(K);
    EmitLabel(ThunkLbl);
    EmitInstr('SUB DWORD PTR [ESP+4],' +
     IntToStr_(IfaceImplTab[I].HiddenFieldOffset));
    EmitInstr('JMP ' + SymTab[MSym].MangledName);
    Entry := ThunkLbl;
   End
   Else
    Entry := '0';
   If VTblBody <> '' Then VTblBody := VTblBody + ',';
   VTblBody := VTblBody + Entry;
  End;

  EmitRaw('.DATA');
  If VTblBody <> '' Then
   EmitRaw(IfaceImplTab[I].VTblLabel + '  DD ' + VTblBody);
 End;
 EmitRaw('.CODE');
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
 TIdx := ParseTypeExpr;   { nom simple, ou array/record/set inline (TODO 19) }

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
{ ParsePropertyDecl (TODO 16) : PROPERTY Nom [ '[' Idx: T2 ']' ]  }
{ ':' Type [READ Getter] [WRITE Setter] <specificateurs ignores :  }
{ INDEX n, DEFAULT v, STORED b, NODEFAULT, IMPLEMENTS I - stubs    }
{ syntaxiques uniquement, aucun effet semantique> ';' suivi,        }
{ uniquement pour une propriete INDEXEE, d un specificateur         }
{ separe 'DEFAULT ;' qui en fait la propriete tableau par defaut    }
{ de la classe (acces obj[i] sans nommer la propriete elle-meme,    }
{ PropFindDefault). READ/WRITE peuvent nommer indifferemment un     }
{ champ ou une methode : c est ParseFieldAccess/ParseStmt (acces/   }
{ affectation) qui font la difference au moment de l USAGE, pas ici.}
{ ------------------------------------------------------------ }

Procedure ParsePropertyDecl(ClassTypeIdx: Integer);
Var
 PName, Up, TName, ReadName, WriteName : TString;
 PTypeIdx, IndexTypeIdx, PropIdx : Integer;
 IsIndexed : Boolean;
Begin
 PPAdvance;   { property }
 PName := TokenPool[PP].Val;
 PPAdvance;

 IsIndexed    := False;
 IndexTypeIdx := -1;
 If PPMatch('[') Then
 Begin
  IsIndexed := True;
  PPAdvance;   { nom du parametre d index (non conserve, TODO 16) }
  If PPMatch(':') Then
  Begin
   TName := TokenPool[PP].Val;
   PPAdvance;
   IndexTypeIdx := TypeFindByName(TName);
  End;
  PPMatch(']');
 End;

 PTypeIdx := TypeFindByName('Integer');
 If PPMatch(':') Then
 Begin
  TName := TokenPool[PP].Val;
  PPAdvance;
  PTypeIdx := TypeFindByName(TName);
  If PTypeIdx < 0 Then PTypeIdx := TypeFindByName('Integer');
 End;

 ReadName  := '';
 WriteName := '';
 While (Not PPAtEnd) And
       (Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = ';'))) Do
 Begin
  Up := StrUpperCase(PPPeekVal);
  If (Up = 'READ') And (PPPeekKind = TK_IDENT) Then
  Begin
   PPAdvance;
   ReadName := TokenPool[PP].Val;
   PPAdvance;
  End
  Else If (Up = 'WRITE') And (PPPeekKind = TK_IDENT) Then
  Begin
   PPAdvance;
   WriteName := TokenPool[PP].Val;
   PPAdvance;
  End
  Else
   PPAdvance;   { index Nb, default V, stored B, nodefault, implements I : }
                 { specificateurs reconnus mais sans effet (TODO 16)        }
 End;
 SkipOptSemi;

 PropIdx := TypeAddProperty(ClassTypeIdx, PName, PTypeIdx, IsIndexed,
  IndexTypeIdx, ReadName, WriteName);

 { propriete tableau par defaut : property ...[...]... ; default ;  }
 { (specificateur SEPARE, propre aux proprietes indexees - permet    }
 { l acces obj[i] sans nommer la propriete, TODO 16).                }
 If IsIndexed And (PPPeekKind = TK_IDENT) And
    (StrUpperCase(PPPeekVal) = 'DEFAULT') Then
 Begin
  PPAdvance;
  SkipOptSemi;
  If PropIdx >= 0 Then PropPool[PropIdx].IsDefault := True;
 End;
End;

{ ------------------------------------------------------------ }
{ ClassEnsureIUnknownMethods (TODO 17) : ajoute une seule fois,   }
{ pour une classe (ou l un de ses ancetres) implementant au moins  }
{ une interface, le champ cache FRefCount (compteur de references)}
{ et les trois methodes IUnknown (QueryInterface/AddRef/Release), }
{ avec de vrais corps ASM ecrits directement ici (comme            }
{ TObject.Create/Destroy/Free, EmitRuntimeLibrary) plutot que via  }
{ ParseMethodBodyDecl, puisque le code source Delphi ne fournit     }
{ jamais leur corps lui-meme. Idempotent : verifie via              }
{ SymFindInClassChain (et non SymFindInClass) pour que la version    }
{ heritee d une classe ancetre soit reutilisee telle quelle, sans   }
{ dupliquer ni le champ ni les methodes chez le descendant.          }
{ ------------------------------------------------------------ }

Procedure ClassEnsureIUnknownMethods(ClassSymIdx, ClassTypeIdx: Integer);
Var
 FRCFieldIdx, FRCOffset, IntIdx : Integer;
 QISym, ARSym, RelSym, FreeSym : Integer;
 ClassNameUp, DoneLbl : TString;
Begin
 If SymFindInClassChain(ClassTypeIdx, 'QUERYINTERFACE') >= 0 Then Exit;

 IntIdx      := TypeFindByName('Integer');
 FRCFieldIdx := TypeAddField(ClassTypeIdx, 'FREFCOUNT', IntIdx);
 FRCOffset   := FieldPool[FRCFieldIdx].Offset;
 ClassNameUp := StrUpperCase(SymTab[ClassSymIdx].Name);

 SymEnterClassScope(ClassSymIdx);
 QISym  := SymAddForce('QueryInterface', SK_METHOD, IntIdx);
 ARSym  := SymAddForce('AddRef', SK_METHOD, IntIdx);
 RelSym := SymAddForce('Release', SK_METHOD, IntIdx);
 SymTab[QISym].IsExternal  := False;
 SymTab[ARSym].IsExternal  := False;
 SymTab[RelSym].IsExternal := False;
 SymTab[QISym].MangledName  := DP_FUNC_PFX + ClassNameUp + '_QUERYINTERFACE';
 SymTab[ARSym].MangledName  := DP_FUNC_PFX + ClassNameUp + '_ADDREF';
 SymTab[RelSym].MangledName := DP_FUNC_PFX + ClassNameUp + '_RELEASE';
 SymLeaveScope;

 VMTAddMethod(ClassTypeIdx, 'QUERYINTERFACE', QISym);
 VMTAddMethod(ClassTypeIdx, 'ADDREF', ARSym);
 VMTAddMethod(ClassTypeIdx, 'RELEASE', RelSym);

 FreeSym := SymFindInClass(SymFind('TObject'), 'FREE');

 EmitComment('--- ' + SymTab[ClassSymIdx].Name +
  ' : methodes IUnknown generees automatiquement (TODO 17) ---');

 EmitLabel(SymTab[QISym].MangledName);
 EmitProlog(0);
 EmitComment('Approximation (TODO 17) : pas de verification de GUID');
 EmitComment('reelle (RTTI d instance non implementee) - echoue toujours.');
 EmitInstr('MOV EAX,-2147467262');   { E_NOINTERFACE }
 EmitEpilog;
 EmitBlankLine;

 EmitLabel(SymTab[ARSym].MangledName);
 EmitProlog(0);
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
 EmitInstr('MOV EDX,DWORD PTR [EAX+' + IntToStr_(FRCOffset) + ']');
 EmitInstr('INC EDX');
 EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(FRCOffset) + '],EDX');
 EmitInstr('MOV EAX,EDX');
 EmitEpilog;
 EmitBlankLine;

 DoneLbl := SymTab[RelSym].MangledName + '_DONE';
 EmitLabel(SymTab[RelSym].MangledName);
 EmitProlog(0);
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
 EmitInstr('MOV EDX,DWORD PTR [EAX+' + IntToStr_(FRCOffset) + ']');
 EmitInstr('DEC EDX');
 EmitInstr('MOV DWORD PTR [EAX+' + IntToStr_(FRCOffset) + '],EDX');
 EmitInstr('CMP EDX,0');
 EmitInstr('JG ' + DoneLbl);
 EmitInstr('PUSH DWORD PTR [EBP+8]');
 If FreeSym >= 0 Then
  EmitInstr('CALL ' + SymTab[FreeSym].MangledName)
 Else
  WarnMsg('TObject.Free introuvable (ne devrait jamais arriver)');
 EmitInstr('ADD ESP,4');
 EmitLabel(DoneLbl);
 EmitInstr('MOV EAX,EDX');
 EmitEpilog;
 EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ ClassImplementInterface (TODO 17) : enregistre que ClassTypeIdx }
{ implemente l interface nommee IfaceName (resolue via SymFind).   }
{ Genere d abord FRefCount/QueryInterface/AddRef/Release si         }
{ necessaire (ClassEnsureIUnknownMethods), puis pour chaque methode }
{ de l interface (VMT de IfaceTypeIdx, deja etendue par VMTInit avec}
{ les 3 methodes IUnknown heritees) retrouve l offset VMT reel de   }
{ la classe qui l implemente - la rendant virtuelle au passage       }
{ (VMTAddMethod) si elle ne l etait pas deja, puisqu une methode      }
{ satisfaisant une interface doit etre atteignable par decalage       }
{ constant comme n importe quelle autre methode virtuelle - et         }
{ enregistre le thunk correspondant (IfaceImplAddThunk, TODO 08).      }
{ L emission reelle de la table de thunks elle-meme (donnees + code   }
{ des trampolines) reste differee au TODO 24, comme la VMT de classe.  }
{ ------------------------------------------------------------ }

Procedure ClassImplementInterface(ClassSymIdx, ClassTypeIdx: Integer;
 Const IfaceName: TString);
Var
 IfaceSymIdx, IfaceTypeIdx, ImplIdx : Integer;
 I, ClassVMTOffset, MethodSymIdx : Integer;
 HiddenFieldIdx, PtrTypeIdx : Integer;
Begin
 IfaceSymIdx := SymFind(IfaceName);
 If (IfaceSymIdx < 0) Or (SymTab[IfaceSymIdx].Kind <> SK_INTERFACE) Then
 Begin
  WarnMsg('interface inconnue: ' + IfaceName);
  Exit;
 End;
 IfaceTypeIdx := SymTab[IfaceSymIdx].TypeIdx;

 ClassEnsureIUnknownMethods(ClassSymIdx, ClassTypeIdx);

 ImplIdx := IfaceImplAdd(ClassTypeIdx, IfaceTypeIdx, TypeTab[IfaceTypeIdx].GUID);

 { Champ cache (TODO 25) : contient l adresse de la table de thunks de  }
 { cette interface pour cette classe - une valeur CONSTANTE, la meme     }
 { pour toute instance, stampee au site d appel de Create (comme le      }
 { pointeur de VMT lui-meme, ParseClassMemberAccess). L ADRESSE de ce     }
 { champ (et non le pointeur d objet lui-meme) est ce qu une variable      }
 { d interface recoit lors d une affectation classe->interface           }
 { (EmitAssign) : la dereferencer une fois donne la table de thunks, et    }
 { chaque thunk retranche cet offset avant de sauter vers la vraie         }
 { methode pour retrouver le pointeur d objet reel - meme technique que    }
 { la disposition d objet COM/Delphi reelle, evitant ainsi l offset VMT     }
 { errone (numerotation de l interface applique a la VMT de la classe)      }
 { qui restait une approximation documentee depuis le TODO 17.               }
 PtrTypeIdx := TypeFindByName('POINTER');
 HiddenFieldIdx := TypeAddField(ClassTypeIdx,
  '_DPI_' + StrUpperCase(SymTab[ClassSymIdx].Name) + '_' + StrUpperCase(IfaceName),
  PtrTypeIdx);
 If (ImplIdx >= 0) And (HiddenFieldIdx >= 0) Then
 Begin
  IfaceImplTab[ImplIdx].HiddenFieldOffset := FieldPool[HiddenFieldIdx].Offset;
  IfaceImplTab[ImplIdx].VTblLabel := DP_CLS_PFX +
   StrUpperCase(SymTab[ClassSymIdx].Name) + '_' + StrUpperCase(IfaceName) + '_VTBL';
 End;

 If TypeTab[IfaceTypeIdx].VMTFirst >= 0 Then
  For I := TypeTab[IfaceTypeIdx].VMTFirst To
   TypeTab[IfaceTypeIdx].VMTFirst + TypeTab[IfaceTypeIdx].VMTCount - 1 Do
  Begin
   ClassVMTOffset := VMTFindMethod(ClassTypeIdx, VMTEntryPool[I].MethodName);
   If ClassVMTOffset < 0 Then
   Begin
    MethodSymIdx := SymFindInClassChain(ClassTypeIdx, VMTEntryPool[I].MethodName);
    If MethodSymIdx >= 0 Then
     ClassVMTOffset := VMTAddMethod(ClassTypeIdx, VMTEntryPool[I].MethodName,
      MethodSymIdx)
    Else
    Begin
     WarnMsg('la classe ' + SymTab[ClassSymIdx].Name +
      ' n''implemente pas ' + VMTEntryPool[I].MethodName +
      ' (interface ' + IfaceName + ')');
     Continue;
    End;
   End;
   If ImplIdx >= 0 Then
    IfaceImplAddThunk(ImplIdx, VMTEntryPool[I].MethodName, ClassVMTOffset);
  End;
End;

Const
 MAX_IFACE_PER_CLASS = 8;   { interfaces implementees par une meme     }
                             { classe dans une seule liste d ancetres  }
                             { class(Parent, I1, I2, ...), TODO 17     }

{ ------------------------------------------------------------ }
{ ParseClassDecl : CLASS[(Parent[, IInterface...])] [SEALED]      }
{ [ABSTRACT] <sections de visibilite/champs/methodes/proprietes>  }
{ END - le nom de la classe (ClassName) a deja ete lu par          }
{ l appelant (ParseTypeDecl). Sans ancetre explicite, herite de     }
{ TObject (comme en Delphi reel). Les sections de visibilite        }
{ (private/protected/public/published/automated) sont reconnues    }
{ mais pas appliquees/implementees - une seule "unite" existe pour  }
{ l instant (TODO 23). Retourne le TypeIdx de la nouvelle classe.    }
{ Les interfaces supplementaires de la liste d ancetres (TODO 17)   }
{ sont implementees APRES le corps entier de la classe (voir         }
{ ClassImplementInterface), afin que les methodes qui les             }
{ satisfont puissent etre declarees n importe ou dans ce corps.       }
{ ------------------------------------------------------------ }

Function ParseClassDecl(Const ClassName: TString): Integer;
Var
 ParentName, Up : TString;
 ParentSymIdx, ClassSymIdx, ClassTypeIdx, Found : Integer;
 IfaceNames : Array[0..MAX_IFACE_PER_CLASS - 1] Of TString;
 IfaceCount, II : Integer;
Begin
 PPAdvance;   { class }

 IfaceCount := 0;
 ParentSymIdx := SymFind('TObject');
 If PPMatch('(') Then
 Begin
  ParentName := TokenPool[PP].Val;
  PPAdvance;
  Found := SymFind(ParentName);
  If Found >= 0 Then ParentSymIdx := Found
  Else WarnMsg('classe ancetre inconnue: ' + ParentName);
  { interfaces supplementaires (TODO 17) : chaque identificateur     }
  { suivant apres la premiere virgule est resolu et implemente une   }
  { fois le corps de la classe entierement analyse (voir plus bas),  }
  { pour que ses propres methodes (potentiellement declarees plus   }
  { loin dans ce meme corps) soient deja visibles.                    }
  While PPMatch(',') Do
  Begin
   If IfaceCount < MAX_IFACE_PER_CLASS Then
   Begin
    IfaceNames[IfaceCount] := TokenPool[PP].Val;
    Inc(IfaceCount);
   End;
   PPAdvance;
  End;
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
    ParsePropertyDecl(ClassTypeIdx);
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

 For II := 0 To IfaceCount - 1 Do
  ClassImplementInterface(ClassSymIdx, ClassTypeIdx, IfaceNames[II]);

 ParseClassDecl := ClassTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseInterfaceMethodDecl (TODO 17) : PROCEDURE|FUNCTION Nom     }
{ (params)[: Type]; a l interieur d un corps d interface. Proche   }
{ de ParseClassMethodDecl (meme analyse de signature) mais bien     }
{ plus simple : ni constructeur/destructeur/methode de classe, ni   }
{ directives virtual/override (une methode d interface est          }
{ TOUJOURS implicitement abstraite - donc TOUJOURS ajoutee a la      }
{ VMT de l interface, sans condition). Contrairement aux proprietes  }
{ ou methodes de classe qui comptent seulement l arite, une methode  }
{ d interface recoit un VRAI symbole SK_METHOD (IsExternal=True a    }
{ jamais, aucun corps ne sera jamais fourni) : c est ce symbole,      }
{ retrouve via VMTFindMethodSym, qui donne son type de retour a tout }
{ appel a travers une variable de type interface (ParseFieldAccess). }
{ ------------------------------------------------------------ }

Procedure ParseInterfaceMethodDecl(IfaceSymIdx, IfaceTypeIdx: Integer);
Var
 Name, TName : TString;
 IsFunc : Boolean;
 MethodSymIdx, RetTypeIdx, PTypeIdx, GI, ParamCountLocal : Integer;
Begin
 IsFunc := StrUpperCase(PPPeekVal) = 'FUNCTION';
 PPAdvance;   { procedure|function }
 Name := TokenPool[PP].Val;
 PPAdvance;

 SymEnterClassScope(IfaceSymIdx);
 MethodSymIdx := SymAddForce(Name, SK_METHOD, -1);
 If MethodSymIdx >= 0 Then
 Begin
  SymTab[MethodSymIdx].IsExternal  := True;   { abstraite : jamais de corps }
  SymTab[MethodSymIdx].MangledName :=
   DP_FUNC_PFX + SymTab[IfaceSymIdx].Name + '_' + StrUpperCase(Name);
 End;
 SymLeaveScope;

 ParamCountLocal := 0;
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   Repeat
    If PPPeekKind = TK_KEYWORD Then
    Begin
     If (StrUpperCase(PPPeekVal) = 'VAR') Or
        (StrUpperCase(PPPeekVal) = 'CONST') Or
        (StrUpperCase(PPPeekVal) = 'OUT') Then PPAdvance;
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

    If PPMatch('=') Then ParseExpr;   { defaut : analyse et jete }

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

 If MethodSymIdx >= 0 Then
 Begin
  SymTab[MethodSymIdx].TypeIdx    := RetTypeIdx;
  SymTab[MethodSymIdx].ParamCount := ParamCountLocal;
 End;

 PPMatch(';');

 If MethodSymIdx >= 0 Then VMTAddMethod(IfaceTypeIdx, Name, MethodSymIdx);
End;

{ ------------------------------------------------------------ }
{ ParseInterfaceDecl : INTERFACE[(Parent)] ['GUID'] <methodes>    }
{ END - le nom de l interface (IfaceName) a deja ete lu par         }
{ l appelant (ParseTypeDecl). Sans ancetre explicite, herite de     }
{ IUnknown (comme en Delphi reel), qui apporte deja QueryInterface/ }
{ AddRef/Release aux offsets VMT 0/4/8 (ClassSystemInit) - toute     }
{ methode declaree ici s ajoute donc APRES ces trois-la. Retourne    }
{ le TypeIdx de la nouvelle interface.                                }
{ ------------------------------------------------------------ }

Function ParseInterfaceDecl(Const IfaceName: TString): Integer;
Var
 ParentName, Up, GUIDStr : TString;
 ParentSymIdx, IfaceSymIdx, IfaceTypeIdx, Found : Integer;
Begin
 PPAdvance;   { interface }

 ParentSymIdx := SymFind('IUnknown');
 If PPMatch('(') Then
 Begin
  ParentName := TokenPool[PP].Val;
  PPAdvance;
  Found := SymFind(ParentName);
  If Found >= 0 Then ParentSymIdx := Found
  Else WarnMsg('interface ancetre inconnue: ' + ParentName);
  PPMatch(')');
 End;

 { GUID optionnel, entre crochets droits (syntaxe Delphi reelle) -    }
 { accepte aussi la chaine seule, sans crochets, par souplesse.        }
 GUIDStr := '';
 If PPMatch('[') Then
 Begin
  If PPPeekKind = TK_STRING Then
  Begin
   GUIDStr := TokenPool[PP].Val;
   PPAdvance;
  End;
  PPMatch(']');
 End
 Else If PPPeekKind = TK_STRING Then
 Begin
  GUIDStr := TokenPool[PP].Val;
  PPAdvance;
 End;

 IfaceSymIdx  := SymDeclareClass(IfaceName, SK_INTERFACE, ParentSymIdx);
 IfaceTypeIdx := SymTab[IfaceSymIdx].TypeIdx;
 VMTInit(IfaceTypeIdx);
 TypeTab[IfaceTypeIdx].GUID := GUIDStr;

 While Not PPAtEnd Do
 Begin
  If PPPeekKind = TK_KEYWORD Then
  Begin
   Up := StrUpperCase(PPPeekVal);
   If Up = 'END' Then Break;
   If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
   Begin
    ParseInterfaceMethodDecl(IfaceSymIdx, IfaceTypeIdx);
    Continue;
   End;
   PPAdvance;
   Continue;
  End;
  Break;   { filet de securite anti-boucle infinie }
 End;

 PPMatch('end');
 SkipOptSemi;

 ParseInterfaceDecl := IfaceTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseTypeExpr (TODO 19) : analyse une expression de type -      }
{ ARRAY [Lo..Hi | rien = dynamique] OF T, RECORD ... END,           }
{ SET OF T, ou (repli) un simple nom de type deja connu. Recursif   }
{ (l element d un tableau/ensemble, ou le type d un champ de         }
{ record, peut lui-meme etre n importe laquelle de ces formes).      }
{ Utilise a la fois par ParseTypeDecl (TYPE X = ...) et par toute    }
{ position ou un type est attendu inline (Var, champ de classe,      }
{ champ de record) - le type resultant reste ANONYME (Name='') sauf  }
{ si l appelant le nomme explicitement apres coup (ParseTypeDecl).   }
{ Deja forward-declaree plus haut (avant ParseDeclSection, TODO 14). }
{ ------------------------------------------------------------ }

{ ------------------------------------------------------------ }
{ ParseConstIntLiteral (TODO 19) : lit une valeur entiere CONSTANTE }
{ simple - litteral entier/caractere, nom de constante deja         }
{ declaree (SK_CONST), ou l un precede de '-' unaire. Ni ConstEvalExpr}
{ (TODO 04, base sur une chaine source, pas des jetons) ni ParseExpr }
{ (TODO 11, qui EMET du code ASM) ne conviennent ici : les bornes    }
{ d un tableau statique et les elements d un litteral ensembliste     }
{ sont des METADONNEES DE TYPE evaluees a la compilation, pas des     }
{ valeurs a calculer a l execution.                                    }
{ ------------------------------------------------------------ }

Function ParseConstIntLiteral: LongInt;
Var Neg: Boolean; SI: Integer; V: LongInt;
Begin
 Neg := False;
 If (PPPeekKind = TK_OP) And (PPPeekVal = '-') Then
 Begin
  Neg := True;
  PPAdvance;
 End;

 If (PPPeekKind = TK_INTEGER) Or (PPPeekKind = TK_CHAR) Then
 Begin
  V := TokenPool[PP].IntVal;
  PPAdvance;
 End
 Else If PPPeekKind = TK_IDENT Then
 Begin
  SI := SymFind(TokenPool[PP].Val);
  If (SI >= 0) And (SymTab[SI].Kind = SK_CONST) Then
   V := SymTab[SI].ImmVal
  Else
  Begin
   WarnMsg('constante entiere attendue: ' + TokenPool[PP].Val);
   V := 0;
  End;
  PPAdvance;
 End
 Else
 Begin
  WarnMsg('constante entiere attendue');
  V := 0;
  PPAdvance;
 End;

 { Note (piege Pascal) : relire ParseConstIntLiteral ici (hors ":=")   }
 { RAPPELLERAIT la fonction au lieu de lire la valeur deja assignee -   }
 { d ou le passage par la variable locale V tout du long.               }
 If Neg Then V := -V;
 ParseConstIntLiteral := V;
End;

{ ------------------------------------------------------------ }
{ SkipRecordMethodStub (TODO 19) : "advanced record" - une methode  }
{ (function/procedure) a l interieur d un corps de RECORD est        }
{ reconnue syntaxiquement (signature, puis corps BEGIN..END eventuel,}
{ via SkipToMatchingEnd) mais totalement ignoree - stub honnete,      }
{ exactement comme le spec du TODO 19 le demande explicitement        }
{ ("support minimal ... en stub").                                     }
{ ------------------------------------------------------------ }

Procedure SkipRecordMethodStub;
Var Depth: Integer;
Begin
 WarnMsg('methode de record (advanced record) reconnue mais non geree ' +
  '(stub, TODO 19) : ignoree');
 PPAdvance;   { function|procedure }
 Depth := 0;
 While (Not PPAtEnd) And
       (Not ((Depth = 0) And (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';'))) Do
 Begin
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '(') Then Inc(Depth);
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ')') Then Dec(Depth);
  PPAdvance;
 End;
 SkipOptSemi;
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'BEGIN') Then
 Begin
  PPAdvance;
  SkipToMatchingEnd;
  SkipOptSemi;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseRecordBody (TODO 19) : suite de groupes Nom[,Nom...]: Type ;}
{ jusqu a END (non consomme, laisse a l appelant) - TypeAddField    }
{ (TODO 06/09/15/16) fonctionne deja tel quel pour un TYK_RECORD,   }
{ sans aucune modification (confirme par recherche prealable).      }
{ ------------------------------------------------------------ }

Procedure ParseRecordBody(RecTypeIdx: Integer);
Var
 Names : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 NCount, I, TIdx : Integer;
 Up : TString;
Begin
 While Not PPAtEnd Do
 Begin
  If PPPeekKind = TK_KEYWORD Then
  Begin
   Up := StrUpperCase(PPPeekVal);
   If Up = 'END' Then Break;
   If (Up = 'FUNCTION') Or (Up = 'PROCEDURE') Then
   Begin
    SkipRecordMethodStub;
    Continue;
   End;
   WarnMsg('construction de record non geree (ex: variant/case, ' +
    'TODO 19+) : ignoree');
   Break;
  End;

  If PPPeekKind <> TK_IDENT Then Break;   { filet de securite }

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
  TIdx := ParseTypeExpr;

  For I := 0 To NCount - 1 Do TypeAddField(RecTypeIdx, Names[I], TIdx);
  SkipOptSemi;
 End;
End;

Function ParseTypeExpr: Integer;
Var
 Up, TName, ValName : TString;
 Lo, Hi, ElemIdx, RecIdx, R : Integer;
 IsDyn : Boolean;
 EnumIdx, EVIdx, SI : Integer;
Begin
 { Enumeration : TYPE T = (Val1, Val2, ...) - infrastructure TypeAddEnum/ }
 { TypeAddEnumValue deja existante (TODO 06) mais jamais reliee a un      }
 { vrai parseur avant ce TODO (aucun TODO precedent, y compris le 19,    }
 { n en avait la charge explicite). Chaque valeur est aussi enregistree   }
 { comme une CONSTANTE ordinaire (SK_CONST) dans la portee courante -     }
 { c est ainsi que Delphi les rend utilisables en expression (X := Red). }
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '(') Then
 Begin
  PPAdvance;   { ( }
  EnumIdx := TypeAddEnum('');
  Repeat
   ValName := TokenPool[PP].Val;
   PPAdvance;
   EVIdx := TypeAddEnumValue(EnumIdx, ValName, False, 0);
   If EVIdx >= 0 Then
   Begin
    SI := SymAdd(ValName, SK_CONST, EnumIdx);
    If SI >= 0 Then SymTab[SI].ImmVal := EnumValPool[EVIdx].Value;
   End;
  Until Not PPMatch(',');
  PPMatch(')');
  ParseTypeExpr := EnumIdx;
  Exit;
 End;

 If PPPeekKind = TK_KEYWORD Then
 Begin
  Up := StrUpperCase(PPPeekVal);

  If Up = 'ARRAY' Then
  Begin
   PPAdvance;   { array }
   Lo := 0; Hi := -1; IsDyn := True;
   If PPMatch('[') Then
   Begin
    IsDyn := False;
    Lo := ParseConstIntLiteral;
    PPMatch('..');
    Hi := ParseConstIntLiteral;
    PPMatch(']');
   End;
   If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'OF') Then
    PPAdvance;
   ElemIdx := ParseTypeExpr;
   ParseTypeExpr := TypeAddArray(ElemIdx, Lo, Hi, IsDyn);
   Exit;
  End;

  If Up = 'RECORD' Then
  Begin
   PPAdvance;   { record }
   RecIdx := TypeAddRecord('');
   ParseRecordBody(RecIdx);
   PPMatch('end');
   ParseTypeExpr := RecIdx;
   Exit;
  End;

  If Up = 'SET' Then
  Begin
   PPAdvance;   { set }
   If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'OF') Then
    PPAdvance;
   ElemIdx := ParseTypeExpr;
   ParseTypeExpr := TypeAddSet(ElemIdx);
   Exit;
  End;
 End;

 { repli : nom de type simple deja connu (alias, TODO 06). Passe par }
 { une variable locale : relire le NOM de la fonction dans une         }
 { expression (hors ":=") RAPPELLE la fonction (recursion), ne lit PAS}
 { la valeur deja assignee - piege Pascal classique.                    }
 TName := TokenPool[PP].Val;
 PPAdvance;
 R := TypeFindByName(TName);
 If R < 0 Then R := TypeFindByName('Integer');
 ParseTypeExpr := R;
End;

{ ------------------------------------------------------------ }
{ ParseTypeDecl : TYPE Nom = ... ; point d entree de plus haut    }
{ niveau. Classes et interfaces sont gerees (TODO 15/17) ; tableaux,}
{ records et ensembles (TODO 19) passent par ParseTypeExpr, qui     }
{ construit un type ANONYME - etiquete ici du nom declare (sauf     }
{ pour un simple ALIAS vers un type deja nomme : ne jamais ecraser   }
{ le nom d un type EXISTANT, ce qui corromprait TypeFindByName pour  }
{ tout le monde).                                                     }
{ ------------------------------------------------------------ }

{ ParseOneTypeDecl : Nom = ... ; SANS consommer le mot-cle TYPE lui-  }
{ meme (contrairement a ParseTypeDecl ci-dessous, qui reste inchange   }
{ pour les self-tests existants) - permet a ParseGlobalDeclSection      }
{ (TODO 23) de boucler sur PLUSIEURS declarations partageant un seul     }
{ mot-cle TYPE (Type A = ...; B = ...; C = ...;), le style Delphi le     }
{ plus courant, qu un unique appel a ParseTypeDecl ne peut pas gerer      }
{ (il consommerait TYPE une seconde fois au lieu de lire B).               }
Procedure ParseOneTypeDecl;
Var Name: TString; TIdx: Integer;
Begin
 Name := TokenPool[PP].Val;
 PPAdvance;
 PPMatch('=');

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'CLASS') Then
 Begin
  ParseClassDecl(Name);
  Exit;
 End;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'INTERFACE') Then
 Begin
  ParseInterfaceDecl(Name);
  Exit;
 End;

 TIdx := ParseTypeExpr;
 If (TIdx >= 0) And (TIdx < TypeCount) And (TypeTab[TIdx].Name = '') Then
  TypeTab[TIdx].Name := StrUpperCase(Name);
 SkipOptSemi;
End;

Procedure ParseTypeDecl;
Begin
 PPAdvance;   { type }
 ParseOneTypeDecl;
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
 MethodSymIdx, ClassTypeIdx, ArgN, II : Integer;
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

  { Champs caches de thunks d interface (TODO 25) : une valeur       }
  { CONSTANTE par interface implementee directement par cette classe, }
  { stampee ici comme le pointeur de VMT ci-dessus (memes raisons -     }
  { aucune init specifique n existe dans TObject.Create/le constructeur }
  { herite, qui ignorent tout des interfaces implementees par un          }
  { descendant).                                                            }
  For II := 0 To IfaceImplCount - 1 Do
   If (IfaceImplTab[II].ClassTypeIdx = ClassTypeIdx) And
      (Length(IfaceImplTab[II].VTblLabel) > 0) Then
    EmitInstr('MOV DWORD PTR [EBX+' +
     IntToStr_(IfaceImplTab[II].HiddenFieldOffset) + '],OFFSET ' +
     IfaceImplTab[II].VTblLabel);

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
{ PropAssert / PropSelfTest (TODO 16) : verifient les proprietes  }
{ simples (champ ou methode getter/setter), indexees, et par       }
{ defaut (acces obj[i]), en lecture et en ecriture, avec une        }
{ classe synthetique TPointPT et des suites de tokens               }
{ construites directement dans TokenPool, comme les self-tests des  }
{ TODO precedents.                                                    }
{ ------------------------------------------------------------ }

Procedure PropAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('PropSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PropSelfTest;
Const
 TmpFile = 'DPPROPSELFTEST.$$$';
Var
 PointSymIdx, PointTypeIdx : Integer;
 GetYSym, SetYSym, GetItemSym, SetItemSym : Integer;
 F : Text;
 Line : TString;
 HasReadX, HasWriteX, HasCallGetY, HasCallSetY, HasAddEsp8Y : Boolean;
 HasCallGetItem, HasCallSetItem, HasAddEsp8Item, HasAddEsp12Item : Boolean;
 HasCallGetItemDef, HasCallSetItemDef : Boolean;

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

 { --- TPointPT = class                                              }
 {      FX: Integer;                                                  }
 {      function GetY: Integer;  procedure SetY(Value: Integer);       }
 {      function GetItem(Index: Integer): Integer;                     }
 {      procedure SetItem(Index: Integer; Value: Integer);              }
 {      property X: Integer read FX write FX;                          }
 {      property Y: Integer read GetY write SetY;                      }
 {      property Items[Index: Integer]: Integer                        }
 {       read GetItem write SetItem; default;                          }
 {      end;                                                            }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TPointPT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_IDENT, 'FX', 0); Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'function', 0); Tok(TK_IDENT, 'GetY', 0);
 Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'procedure', 0); Tok(TK_IDENT, 'SetY', 0);
 Tok(TK_PUNCT, '(', 0); Tok(TK_IDENT, 'Value', 0); Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ')', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'function', 0); Tok(TK_IDENT, 'GetItem', 0);
 Tok(TK_PUNCT, '(', 0); Tok(TK_IDENT, 'Index', 0); Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ')', 0); Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'procedure', 0); Tok(TK_IDENT, 'SetItem', 0);
 Tok(TK_PUNCT, '(', 0); Tok(TK_IDENT, 'Index', 0); Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ';', 0); Tok(TK_IDENT, 'Value', 0);
 Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'property', 0); Tok(TK_IDENT, 'X', 0);
 Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_IDENT, 'read', 0); Tok(TK_IDENT, 'FX', 0);
 Tok(TK_IDENT, 'write', 0); Tok(TK_IDENT, 'FX', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'property', 0); Tok(TK_IDENT, 'Y', 0);
 Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_IDENT, 'read', 0); Tok(TK_IDENT, 'GetY', 0);
 Tok(TK_IDENT, 'write', 0); Tok(TK_IDENT, 'SetY', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'property', 0); Tok(TK_IDENT, 'Items', 0);
 Tok(TK_PUNCT, '[', 0); Tok(TK_IDENT, 'Index', 0); Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0); Tok(TK_PUNCT, ']', 0);
 Tok(TK_PUNCT, ':', 0); Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_IDENT, 'read', 0); Tok(TK_IDENT, 'GetItem', 0);
 Tok(TK_IDENT, 'write', 0); Tok(TK_IDENT, 'SetItem', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'default', 0); Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0); Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 PropAssert('declaration TPointPT consomme tous les tokens', PPAtEnd);

 PointSymIdx  := SymFind('TPointPT');
 PropAssert('TPointPT enregistree comme classe', PointSymIdx >= 0);
 PointTypeIdx := SymTab[PointSymIdx].TypeIdx;

 PropAssert('propriete X trouvee', PropFindInClassChain(PointTypeIdx, 'X') >= 0);
 PropAssert('propriete Y trouvee', PropFindInClassChain(PointTypeIdx, 'Y') >= 0);
 PropAssert('propriete Items trouvee',
  PropFindInClassChain(PointTypeIdx, 'ITEMS') >= 0);
 PropAssert('Items est bien indexee',
  PropPool[PropFindInClassChain(PointTypeIdx, 'ITEMS')].IsIndexed);
 PropAssert('Items est la propriete tableau par defaut',
  PropFindDefault(PointTypeIdx) = PropFindInClassChain(PointTypeIdx, 'ITEMS'));

 GetYSym    := SymFindInClass(PointSymIdx, 'GETY');
 SetYSym    := SymFindInClass(PointSymIdx, 'SETY');
 GetItemSym := SymFindInClass(PointSymIdx, 'GETITEM');
 SetItemSym := SymFindInClass(PointSymIdx, 'SETITEM');
 PropAssert('GetY/SetY/GetItem/SetItem enregistrees',
  (GetYSym >= 0) And (SetYSym >= 0) And (GetItemSym >= 0) And (SetItemSym >= 0));

 GlobalVarDeclare('PROPCTPOINT', PointTypeIdx, 0);

 { --- Lecture simple, appuyee sur un champ : PropCTPoint.X --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'X', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.X consomme tous les tokens', PPAtEnd);
 HasReadX := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 PropAssert('fichier de test (lecture X) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('[EAX+4]', Line) > 0 Then HasReadX := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.X lit directement le champ FX (offset 4)', HasReadX);

 { --- Ecriture simple, appuyee sur un champ : PropCTPoint.X := 42; --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'X', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.X := 42 consomme tous les tokens', PPAtEnd);
 HasWriteX := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('[EBX+4]', Line) > 0 Then HasWriteX := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.X := 42 ecrit directement le champ FX (offset 4)',
  HasWriteX);

 { --- Lecture via getter : PropCTPoint.Y --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Y', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.Y consomme tous les tokens', PPAtEnd);
 HasCallGetY := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[GetYSym].MangledName, Line) > 0 Then HasCallGetY := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.Y appelle le getter GetY', HasCallGetY);

 { --- Ecriture via setter : PropCTPoint.Y := 42; --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Y', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.Y := 42 consomme tous les tokens', PPAtEnd);
 HasCallSetY := False; HasAddEsp8Y := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[SetYSym].MangledName, Line) > 0 Then HasCallSetY := True;
  If Pos('ADD ESP,8', Line) > 0 Then HasAddEsp8Y := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.Y := 42 appelle le setter SetY', HasCallSetY);
 PropAssert('PropCTPoint.Y := 42 nettoie valeur+Self (8 octets)', HasAddEsp8Y);

 { --- Lecture indexee nommee : PropCTPoint.Items[3] --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Items', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.Items[3] consomme tous les tokens', PPAtEnd);
 HasCallGetItem := False; HasAddEsp8Item := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[GetItemSym].MangledName, Line) > 0 Then
   HasCallGetItem := True;
  If Pos('ADD ESP,8', Line) > 0 Then HasAddEsp8Item := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.Items[3] appelle le getter GetItem', HasCallGetItem);
 PropAssert('PropCTPoint.Items[3] nettoie index+Self (8 octets)', HasAddEsp8Item);

 { --- Ecriture indexee nommee : PropCTPoint.Items[3] := 42; --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Items', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint.Items[3] := 42 consomme tous les tokens', PPAtEnd);
 HasCallSetItem := False; HasAddEsp12Item := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[SetItemSym].MangledName, Line) > 0 Then
   HasCallSetItem := True;
  If Pos('ADD ESP,12', Line) > 0 Then HasAddEsp12Item := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint.Items[3] := 42 appelle le setter SetItem',
  HasCallSetItem);
 PropAssert('PropCTPoint.Items[3] := 42 nettoie index+valeur+Self (12 octets)',
  HasAddEsp12Item);

 { --- Lecture par defaut, sans nommer la propriete : PropCTPoint[3] --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint[3] consomme tous les tokens', PPAtEnd);
 HasCallGetItemDef := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[GetItemSym].MangledName, Line) > 0 Then
   HasCallGetItemDef := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint[3] (propriete par defaut) appelle GetItem',
  HasCallGetItemDef);

 { --- Ecriture par defaut, sans nommer la propriete : PropCTPoint[3] := 42; --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'PropCTPoint', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPPROPSELFTEST_END');
 PropAssert('PropCTPoint[3] := 42 consomme tous les tokens', PPAtEnd);
 HasCallSetItemDef := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[SetItemSym].MangledName, Line) > 0 Then
   HasCallSetItemDef := True;
 End;
 Close(F); Erase(F);
 PropAssert('PropCTPoint[3] := 42 (propriete par defaut) appelle SetItem',
  HasCallSetItemDef);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ IfaceAssert / InterfaceSelfTest (TODO 17) : verifient           }
{ l interface (VMT heritee de IUnknown + GUID), une classe         }
{ l implementant (FRefCount, QueryInterface/AddRef/Release         }
{ generees, thunk enregistre, methode promue virtuelle) et le      }
{ comptage de references automatique a l affectation entre          }
{ variables d interface, avec une interface et une classe            }
{ synthetiques (IParlantIT/TChienIT) et des suites de tokens         }
{ construites directement dans TokenPool, comme les self-tests des  }
{ TODO precedents.                                                    }
{ ------------------------------------------------------------ }

Procedure IfaceAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('InterfaceSelfTest: ' + Label_ + ' a echoue');
End;

Procedure InterfaceSelfTest;
Const
 TmpFile = 'DPIFACESELFTEST.$$$';
Var
 IfaceSymIdx, IfaceTypeIdx : Integer;
 ChienSymIdx, ChienTypeIdx : Integer;
 FRCFieldIdx, ImplIdx, ThunkI, ParlerVMTOffset : Integer;
 AddRefSym, ReleaseSym, FreeSym : Integer;
 HasThunkParler : Boolean;
 F : Text;
 Line : TString;
 HasAddRefLabel, HasIncEdx, HasReleaseLabel, HasDecEdx, HasCallFree : Boolean;
 HasIntfAssignCall : Boolean;

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

 { --- IParlantIT = interface, GUID entre crochets, function Parler --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'IParlantIT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'interface', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_STRING, '{00000000-0000-0000-0000-000000000042}', 0);
 Tok(TK_PUNCT, ']', 0);
 Tok(TK_KEYWORD, 'function', 0);
 Tok(TK_IDENT, 'Parler', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 IfaceAssert('declaration IParlantIT consomme tous les tokens', PPAtEnd);

 IfaceSymIdx := SymFind('IParlantIT');
 IfaceAssert('IParlantIT enregistree comme interface',
  (IfaceSymIdx >= 0) And (SymTab[IfaceSymIdx].Kind = SK_INTERFACE));
 IfaceTypeIdx := SymTab[IfaceSymIdx].TypeIdx;

 IfaceAssert('GUID de IParlantIT conserve',
  TypeTab[IfaceTypeIdx].GUID = '{00000000-0000-0000-0000-000000000042}');
 IfaceAssert('QueryInterface heritee de IUnknown a l offset 0',
  VMTFindMethod(IfaceTypeIdx, 'QUERYINTERFACE') = 0);
 IfaceAssert('AddRef heritee de IUnknown a l offset 4',
  VMTFindMethod(IfaceTypeIdx, 'ADDREF') = 4);
 IfaceAssert('Release heritee de IUnknown a l offset 8',
  VMTFindMethod(IfaceTypeIdx, 'RELEASE') = 8);
 IfaceAssert('Parler declaree apres les 3 methodes IUnknown, a l offset 12',
  VMTFindMethod(IfaceTypeIdx, 'PARLER') = 12);

 { --- TChienIT = class(TObject, IParlantIT)                          }
 {      function Parler: Integer;                                      }
 {      end;                                                            }
 { Parler n est PAS declaree virtual : ClassImplementInterface doit    }
 { la promouvoir elle-meme pour qu elle soit atteignable par decalage  }
 { fixe (thunk). Genere du code (QueryInterface/AddRef/Release) : le    }
 { fichier de sortie doit donc etre ouvert pour cette declaration.       }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TChienIT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'TObject', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'IParlantIT', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_KEYWORD, 'function', 0);
 Tok(TK_IDENT, 'Parler', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseTypeDecl;
 EmitClose('DPIFACESELFTEST_END');
 IfaceAssert('declaration TChienIT consomme tous les tokens', PPAtEnd);

 ChienSymIdx := SymFind('TChienIT');
 IfaceAssert('TChienIT enregistree comme classe', ChienSymIdx >= 0);
 ChienTypeIdx := SymTab[ChienSymIdx].TypeIdx;

 IfaceAssert('QueryInterface/AddRef/Release generees automatiquement',
  SymFindInClassChain(ChienTypeIdx, 'QUERYINTERFACE') >= 0);

 FRCFieldIdx := FieldFindInClass(ChienTypeIdx, 'FREFCOUNT');
 IfaceAssert('le champ cache FRefCount existe', FRCFieldIdx >= 0);
 IfaceAssert('FRefCount est a l offset 4 (0 = pointeur de VMT)',
  FieldPool[FRCFieldIdx].Offset = 4);

 IfaceAssert('TChienIT compatible en affectation avec IParlantIT '+
  '(TypeIsAssignCompatible)', TypeIsAssignCompatible(ChienTypeIdx, IfaceTypeIdx));

 ImplIdx := IfaceImplFind(ChienTypeIdx, IfaceTypeIdx);
 IfaceAssert('TChienIT.implemente(IParlantIT) enregistre', ImplIdx >= 0);
 IfaceAssert('le GUID de l interface est recopie dans l implementation',
  IfaceImplTab[ImplIdx].GUID = '{00000000-0000-0000-0000-000000000042}');

 ParlerVMTOffset := VMTFindMethod(ChienTypeIdx, 'PARLER');
 IfaceAssert('Parler a ete promue virtuelle par ClassImplementInterface',
  ParlerVMTOffset >= 0);

 HasThunkParler := False;
 For ThunkI := IfaceImplTab[ImplIdx].ThunkFirst To
  IfaceImplTab[ImplIdx].ThunkFirst + IfaceImplTab[ImplIdx].ThunkCount - 1 Do
  If (ThunkPool[ThunkI].MethodName = 'PARLER') And
     (ThunkPool[ThunkI].VMTOffset = ParlerVMTOffset) Then
   HasThunkParler := True;
 IfaceAssert('un thunk PARLER -> offset VMT reel de TChienIT est enregistre',
  HasThunkParler);

 { --- Corps ASM generes automatiquement pour AddRef/Release --- }
 AddRefSym  := SymFindInClassChain(ChienTypeIdx, 'ADDREF');
 ReleaseSym := SymFindInClassChain(ChienTypeIdx, 'RELEASE');
 FreeSym    := SymFindInClass(SymFind('TObject'), 'FREE');
 HasAddRefLabel := False; HasIncEdx := False;
 HasReleaseLabel := False; HasDecEdx := False; HasCallFree := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 IfaceAssert('fichier de test (declaration TChienIT) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Line = SymTab[AddRefSym].MangledName + ':' Then HasAddRefLabel := True;
  If Pos('INC EDX', Line) > 0 Then HasIncEdx := True;
  If Line = SymTab[ReleaseSym].MangledName + ':' Then HasReleaseLabel := True;
  If Pos('DEC EDX', Line) > 0 Then HasDecEdx := True;
  If Pos('CALL ' + SymTab[FreeSym].MangledName, Line) > 0 Then HasCallFree := True;
 End;
 Close(F); Erase(F);
 IfaceAssert('le corps de AddRef est emis', HasAddRefLabel);
 IfaceAssert('AddRef incremente le compteur de references', HasIncEdx);
 IfaceAssert('le corps de Release est emis', HasReleaseLabel);
 IfaceAssert('Release decremente le compteur de references', HasDecEdx);
 IfaceAssert('Release appelle TObject.Free a zero reference', HasCallFree);

 { --- Comptage de references automatique : IntfA := IntfB; --- }
 GlobalVarDeclare('INTFAIT', IfaceTypeIdx, 0);
 GlobalVarDeclare('INTFBIT', IfaceTypeIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'IntfAIT', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_IDENT, 'IntfBIT', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPIFACESELFTEST_END');
 IfaceAssert('IntfAIT := IntfBIT consomme tous les tokens', PPAtEnd);
 HasIntfAssignCall := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_INTF_ASSIGN, Line) > 0 Then HasIntfAssignCall := True;
 End;
 Close(F); Erase(F);
 IfaceAssert('l affectation entre variables d interface passe par '+
  DPRT_INTF_ASSIGN + ' (comptage de references)', HasIntfAssignCall);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ ExcAssert / ExceptionSelfTest (TODO 18) : verifient la           }
{ hierarchie d exceptions (Message/Create heritees en chaine,      }
{ masquant TObject.Create), la construction d une exception          }
{ (EDivByZero.Create), RAISE (avec expression et relance nue),        }
{ et TRY..EXCEPT..ON E: Classe DO (empilement/depilement du cadre,    }
{ liaison de E a DPRT_CUREXCEPTION), avec des suites de tokens        }
{ construites directement dans TokenPool, comme les self-tests des    }
{ TODO precedents.                                                      }
{ ------------------------------------------------------------ }

Procedure ExcAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('ExceptionSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ExceptionSelfTest;
Const
 TmpFile = 'DPEXCSELFTEST.$$$';
Var
 ExcIdx, DivZeroIdx, ExcCreateSym, ExcMessageSym : Integer;
 FMsgFieldIdx : Integer;
 F : Text;
 Line : TString;
 HasHeapAlloc, HasCallExcCreate, HasCallRaise : Boolean;
 HasExcPush, HasExcPop, HasCallMessage, HasLoadCurExc : Boolean;
 HasBareReraise : Boolean;

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

 ExcIdx     := SymFind('Exception');
 DivZeroIdx := SymFind('EDivByZero');
 ExcAssert('Exception enregistree', ExcIdx >= 0);
 ExcAssert('EDivByZero enregistree et herite d Exception',
  (DivZeroIdx >= 0) And (SymTab[DivZeroIdx].ParentClassIdx = ExcIdx));

 ExcCreateSym  := SymFindInClass(ExcIdx, 'CREATE');
 ExcMessageSym := SymFindInClass(ExcIdx, 'MESSAGE');
 ExcAssert('Exception.Create propre (arite 1) masque TObject.Create',
  (ExcCreateSym >= 0) And (SymTab[ExcCreateSym].ParamCount = 1));
 ExcAssert('Exception.Message enregistree', ExcMessageSym >= 0);

 FMsgFieldIdx := FieldFindInClass(SymTab[ExcIdx].TypeIdx, 'FMESSAGE');
 ExcAssert('FMessage (champ cache) existe sur Exception', FMsgFieldIdx >= 0);
 { FieldInitInherit RECOPIE les champs dans le pool du descendant (un   }
 { index DIFFERENT, TODO 09/15) : c est l OFFSET qui doit rester stable,}
 { pas l index dans FieldPool.                                            }
 ExcAssert('EDivByZero herite FMessage au meme offset',
  FieldPool[FieldFindInClass(SymTab[DivZeroIdx].TypeIdx, 'FMESSAGE')].Offset =
   FieldPool[FMsgFieldIdx].Offset);

 { --- EDivByZero.Create('oops') : construction via Exception.Create --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'EDivByZero', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Create', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'oops', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPEXCSELFTEST_END');
 ExcAssert('EDivByZero.Create(...) consomme tous les tokens', PPAtEnd);
 HasHeapAlloc := False; HasCallExcCreate := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 ExcAssert('fichier de test (Create) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL HeapAlloc', Line) > 0 Then HasHeapAlloc := True;
  If Pos('CALL ' + SymTab[ExcCreateSym].MangledName, Line) > 0 Then
   HasCallExcCreate := True;
 End;
 Close(F); Erase(F);
 ExcAssert('EDivByZero.Create alloue l instance (HeapAlloc)', HasHeapAlloc);
 ExcAssert('EDivByZero.Create appelle le corps herite d Exception.Create',
  HasCallExcCreate);

 { --- raise EDivByZero.Create('oops'); --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'raise', 0);
 Tok(TK_IDENT, 'EDivByZero', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Create', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'oops', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPEXCSELFTEST_END');
 ExcAssert('raise EDivByZero.Create(...) consomme tous les tokens', PPAtEnd);
 HasCallRaise := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_RAISE, Line) > 0 Then HasCallRaise := True;
 End;
 Close(F); Erase(F);
 ExcAssert('raise <expr> appelle ' + DPRT_RAISE, HasCallRaise);

 { --- raise; (relance nue, hors contexte - valide quand meme        }
 { syntaxiquement : aucune verification compile-time du contexte,    }
 { seul DPRT_EXCTOP en decide a l execution) --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'raise', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPEXCSELFTEST_END');
 HasBareReraise := False; HasCallRaise := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('[DPRT_CUREXCEPTION]', Line) > 0 Then HasBareReraise := True;
  If Pos('CALL ' + DPRT_RAISE, Line) > 0 Then HasCallRaise := True;
 End;
 Close(F); Erase(F);
 ExcAssert('raise; recharge DPRT_CUREXCEPTION', HasBareReraise);
 ExcAssert('raise; appelle ' + DPRT_RAISE, HasCallRaise);

 { --- try WriteLn('a') except on E: Exception do WriteLn(E.Message) end --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'try', 0);
 Tok(TK_IDENT, 'WriteLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'a', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'except', 0);
 Tok(TK_KEYWORD, 'on', 0);
 Tok(TK_IDENT, 'E', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Exception', 0);
 Tok(TK_KEYWORD, 'do', 0);
 Tok(TK_IDENT, 'WriteLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'E', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Message', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPEXCSELFTEST_END');
 ExcAssert('try..except..on E: Exception do consomme tous les tokens',
  PPAtEnd);

 HasExcPush := False; HasExcPop := False;
 HasCallMessage := False; HasLoadCurExc := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV DWORD PTR [DPRT_EXCTOP],EAX', Line) > 0 Then HasExcPush := True;
  If Pos('DEC DWORD PTR [DPRT_EXCTOP]', Line) > 0 Then HasExcPop := True;
  If Pos('CALL ' + SymTab[ExcMessageSym].MangledName, Line) > 0 Then
   HasCallMessage := True;
  If Pos('[DPRT_CUREXCEPTION]', Line) > 0 Then HasLoadCurExc := True;
 End;
 Close(F); Erase(F);
 ExcAssert('try empile un cadre de gestionnaire', HasExcPush);
 ExcAssert('except (chemin normal) depile le cadre', HasExcPop);
 ExcAssert('E.Message appelle Exception.Message (heritee)', HasCallMessage);
 ExcAssert('E est lie a DPRT_CUREXCEPTION', HasLoadCurExc);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ CompAssert / CompoundSelfTest (TODO 19) : verifient les          }
{ tableaux statiques (indexation en lecture/ecriture, bornes non     }
{ nulles), les tableaux dynamiques (SetLength, indexation, longueur   }
{ via l entete cachee), les records (declaration via ParseTypeDecl,   }
{ acces aux champs), et les ensembles (litteral, union/intersection/  }
{ difference), avec des suites de tokens construites directement       }
{ dans TokenPool, comme les self-tests des TODO precedents.             }
{ ------------------------------------------------------------ }

Procedure CompAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('CompoundSelfTest: ' + Label_ + ' a echoue');
End;

Procedure CompoundSelfTest;
Const
 TmpFile = 'DPCOMPSELFTEST.$$$';
Var
 IntIdx, StaticArrIdx, DynArrIdx, RecIdx : Integer;
 F : Text;
 Line : TString;
 HasSub1, HasImul4, HasLoadEbx, HasStoreEbx : Boolean;
 HasSetLenCall, HasPushElemSize4, HasHeaderRead : Boolean;
 HasSetLitLea, HasOr, HasAnd, HasAndNot : Boolean;

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

 IntIdx := TypeFindByName('Integer');

 { --- Tableau statique : array[1..5] of Integer --- }
 StaticArrIdx := TypeAddArray(IntIdx, 1, 5, False);
 CompAssert('tableau statique : element Integer',
  TypeTab[StaticArrIdx].BaseTypeIdx = IntIdx);
 CompAssert('tableau statique : bornes 1..5',
  (TypeTab[StaticArrIdx].Lo = 1) And (TypeTab[StaticArrIdx].Hi = 5));
 CompAssert('tableau statique : taille = 5 * SizeOf(Integer)',
  TypeTab[StaticArrIdx].Size = 20);
 GlobalVarDeclare('ARR5PT19', StaticArrIdx, 0);

 { --- Lecture indexee : Arr5PT19[3] --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Arr5PT19', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('Arr5PT19[3] consomme tous les tokens', PPAtEnd);
 HasSub1 := False; HasImul4 := False; HasLoadEbx := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 CompAssert('fichier de test (lecture) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('SUB EAX,1', Line) > 0 Then HasSub1 := True;
  If Pos('IMUL EAX,4', Line) > 0 Then HasImul4 := True;
  If Pos('MOV EAX,DWORD PTR [EBX]', Line) > 0 Then HasLoadEbx := True;
 End;
 Close(F); Erase(F);
 CompAssert('Arr5PT19[3] soustrait la borne inferieure (SUB EAX,1)', HasSub1);
 CompAssert('Arr5PT19[3] multiplie par SizeOf(Integer) (IMUL EAX,4)',
  HasImul4);
 CompAssert('Arr5PT19[3] charge la valeur depuis [EBX]', HasLoadEbx);

 { --- Ecriture indexee : Arr5PT19[3] := 42; --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Arr5PT19', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('Arr5PT19[3] := 42 consomme tous les tokens', PPAtEnd);
 HasStoreEbx := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV DWORD PTR [EBX],EAX', Line) > 0 Then HasStoreEbx := True;
 End;
 Close(F); Erase(F);
 CompAssert('Arr5PT19[3] := 42 ecrit a l adresse calculee ([EBX])',
  HasStoreEbx);

 { --- Tableau dynamique : array of Integer --- }
 DynArrIdx := TypeAddArray(IntIdx, 0, -1, True);
 CompAssert('tableau dynamique : IsDynArray', TypeTab[DynArrIdx].IsDynArray);
 CompAssert('tableau dynamique : taille = 4 (pointeur)',
  TypeTab[DynArrIdx].Size = 4);
 GlobalVarDeclare('DARRPT19', DynArrIdx, 0);

 { --- SetLength(DArrPT19, 10) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'SetLength', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'DArrPT19', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '10', 10);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('SetLength(DArrPT19, 10) consomme tous les tokens', PPAtEnd);
 HasSetLenCall := False; HasPushElemSize4 := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_DYNARR_SETLENGTH, Line) > 0 Then HasSetLenCall := True;
  If Pos('PUSH 4', Line) > 0 Then HasPushElemSize4 := True;
 End;
 Close(F); Erase(F);
 CompAssert('SetLength appelle ' + DPRT_DYNARR_SETLENGTH, HasSetLenCall);
 CompAssert('SetLength passe ElemSize=4 (SizeOf Integer)', HasPushElemSize4);

 { --- Length(DArrPT19) : lecture de l entete cachee [Pointeur-4] --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Length', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'DArrPT19', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('Length(DArrPT19) consomme tous les tokens', PPAtEnd);
 HasHeaderRead := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,DWORD PTR [EAX-4]', Line) > 0 Then HasHeaderRead := True;
 End;
 Close(F); Erase(F);
 CompAssert('Length(DArrPT19) lit la longueur dans l entete cachee',
  HasHeaderRead);

 { --- Record : type TPointPT19 = record X, Y: Integer; end; --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TPointPT19', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'record', 0);
 Tok(TK_IDENT, 'X', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'Y', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 CompAssert('declaration TPointPT19 consomme tous les tokens', PPAtEnd);

 RecIdx := TypeFindByName('TPointPT19');
 CompAssert('TPointPT19 enregistre comme record',
  (RecIdx >= 0) And (TypeTab[RecIdx].Kind = TYK_RECORD));
 CompAssert('TPointPT19 a 2 champs (X, Y)', TypeTab[RecIdx].FieldCount = 2);
 CompAssert('X a l offset 0, Y a l offset 4',
  (FieldPool[TypeTab[RecIdx].FieldFirst].Offset = 0) And
  (FieldPool[TypeTab[RecIdx].FieldFirst + 1].Offset = 4));

 GlobalVarDeclare('PTPT19', RecIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'PtPT19', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Y', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('PtPT19.Y consomme tous les tokens', PPAtEnd);
 HasLoadEbx := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('[EAX+4]', Line) > 0 Then HasLoadEbx := True;
 End;
 Close(F); Erase(F);
 CompAssert('PtPT19.Y lit le champ Y a l offset 4', HasLoadEbx);

 { --- Ensembles : litteral [1, 3, 5..7] --- }
 TokenPoolInit;
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '5', 5);
 Tok(TK_PUNCT, '..', 0);
 Tok(TK_INTEGER, '7', 7);
 Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('[1, 3, 5..7] consomme tous les tokens', PPAtEnd);
 HasSetLitLea := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If (Pos('LEA EAX,[', Line) > 0) And (Pos('_DPK_SET_', Line) > 0) Then
   HasSetLitLea := True;
 End;
 Close(F); Erase(F);
 CompAssert('[1, 3, 5..7] emet l adresse d une constante ensembliste',
  HasSetLitLea);

 { --- Union : [1,2] + [3,4] --- }
 TokenPoolInit;
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '1', 1); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2); Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, '+', 0);
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '3', 3); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '4', 4); Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('[1,2] + [3,4] consomme tous les tokens', PPAtEnd);
 HasOr := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('OR ECX,DWORD PTR', Line) > 0 Then HasOr := True;
 End;
 Close(F); Erase(F);
 CompAssert('[1,2] + [3,4] (union) combine par OR', HasOr);

 { --- Intersection : [1,2] * [2,3] --- }
 TokenPoolInit;
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '1', 1); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2); Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, '*', 0);
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '2', 2); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '3', 3); Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('[1,2] * [2,3] consomme tous les tokens', PPAtEnd);
 HasAnd := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('AND ECX,DWORD PTR', Line) > 0 Then HasAnd := True;
 End;
 Close(F); Erase(F);
 CompAssert('[1,2] * [2,3] (intersection) combine par AND', HasAnd);

 { --- Difference : [1,2] - [2,3] --- }
 TokenPoolInit;
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '1', 1); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2); Tok(TK_PUNCT, ']', 0);
 Tok(TK_OP, '-', 0);
 Tok(TK_PUNCT, '[', 0); Tok(TK_INTEGER, '2', 2); Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '3', 3); Tok(TK_PUNCT, ']', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPCOMPSELFTEST_END');
 CompAssert('[1,2] - [2,3] consomme tous les tokens', PPAtEnd);
 HasAndNot := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('NOT EDX', Line) > 0 Then HasAndNot := True;
 End;
 Close(F); Erase(F);
 CompAssert('[1,2] - [2,3] (difference) inverse puis combine par AND',
  HasAndNot);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ StrAssert / StrSelfTest (TODO 20) : verifient l en-tete cachee   }
{ AnsiString sur un litteral (refcount -1 + longueur), le comptage   }
{ de references reel a l affectation (_DPRT_STRASSIGN), la             }
{ concatenation et la comparaison (nettoyage de pile inclus - bug       }
{ corrige au passage), Length() sur une chaine, Copy/Delete/Insert/Pos,}
{ et l enregistrement minimal de WideString/UnicodeString, avec des     }
{ suites de tokens construites directement dans TokenPool, comme les    }
{ self-tests des TODO precedents.                                        }
{ ------------------------------------------------------------ }

Procedure StrAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('StrSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StrSelfTest;
Const
 TmpFile = 'DPSTRSELFTEST.$$$';
Var
 StrIdx, WideIdx, UnicodeIdx : Integer;
 F : Text;
 Line, PrevLine : TString;
 HasHeader, HasStrAssignCall : Boolean;
 HasConcatCall, HasConcatCleanup : Boolean;
 HasCompareCall, HasCompareCleanup, HasJE : Boolean;
 HasLenRead, HasCopyCall, HasCopyCleanup : Boolean;
 HasDeleteCall, HasDeleteCleanup : Boolean;
 HasInsertCall, HasInsertCleanup, HasPosCall, HasPosCleanup : Boolean;

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

 StrIdx := TypeFindByName('String');
 GlobalVarDeclare('SAPT20', StrIdx, 0);
 GlobalVarDeclare('SBPT20', StrIdx, 0);

 { --- Litteral 'hello' : en-tete cachee (refcount -1, longueur 5) --- }
 TokenPoolInit;
 Tok(TK_STRING, 'hello', 0);
 ParserInit;
 ParsePrimary;
 EmitSkeletonProgram(TmpFile);
 HasHeader := False; PrevLine := '';
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 StrAssert('squelette .asm relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If (Pos('DD -1', PrevLine) > 0) And (Pos('DD 5', Line) > 0) Then
   HasHeader := True;
  PrevLine := Line;
 End;
 Close(F); Erase(F);
 StrAssert('litteral chaine : en-tete refcount -1 puis longueur 5',
  HasHeader);

 { --- SAPT20 := SBPT20; : comptage de references reel --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_IDENT, 'SBPT20', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('SAPT20 := SBPT20 consomme tous les tokens', PPAtEnd);
 HasStrAssignCall := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_ASSIGN, Line) > 0 Then HasStrAssignCall := True;
 End;
 Close(F); Erase(F);
 StrAssert('SAPT20 := SBPT20 appelle ' + DPRT_STR_ASSIGN, HasStrAssignCall);

 { --- SAPT20 + SBPT20 : concatenation --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_OP, '+', 0);
 Tok(TK_IDENT, 'SBPT20', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('SAPT20 + SBPT20 consomme tous les tokens', PPAtEnd);
 HasConcatCall := False; HasConcatCleanup := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_CONCAT, Line) > 0 Then HasConcatCall := True;
  If Pos('ADD ESP,8', Line) > 0 Then HasConcatCleanup := True;
 End;
 Close(F); Erase(F);
 StrAssert('SAPT20 + SBPT20 appelle ' + DPRT_STR_CONCAT, HasConcatCall);
 StrAssert('SAPT20 + SBPT20 nettoie la pile (ADD ESP,8)', HasConcatCleanup);

 { --- SAPT20 = SBPT20 : comparaison (reutilise DPRT_COMPARESTR) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_IDENT, 'SBPT20', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('SAPT20 = SBPT20 consomme tous les tokens', PPAtEnd);
 HasCompareCall := False; HasCompareCleanup := False; HasJE := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_COMPARESTR, Line) > 0 Then HasCompareCall := True;
  If Pos('ADD ESP,8', Line) > 0 Then HasCompareCleanup := True;
  If Pos('JE ', Line) > 0 Then HasJE := True;
 End;
 Close(F); Erase(F);
 StrAssert('SAPT20 = SBPT20 reutilise ' + DPRT_COMPARESTR, HasCompareCall);
 StrAssert('SAPT20 = SBPT20 nettoie la pile (ADD ESP,8)', HasCompareCleanup);
 StrAssert('SAPT20 = SBPT20 traduit le resultat via JE', HasJE);

 { --- Length(SAPT20) : lecture de l en-tete cachee --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Length', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('Length(SAPT20) consomme tous les tokens', PPAtEnd);
 HasLenRead := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,DWORD PTR [EAX-4]', Line) > 0 Then HasLenRead := True;
 End;
 Close(F); Erase(F);
 StrAssert('Length(SAPT20) lit la longueur dans l en-tete cachee',
  HasLenRead);

 { --- Copy(SAPT20, 2, 3) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Copy', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('Copy(SAPT20, 2, 3) consomme tous les tokens', PPAtEnd);
 HasCopyCall := False; HasCopyCleanup := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_COPY, Line) > 0 Then HasCopyCall := True;
  If Pos('ADD ESP,12', Line) > 0 Then HasCopyCleanup := True;
 End;
 Close(F); Erase(F);
 StrAssert('Copy(SAPT20, 2, 3) appelle ' + DPRT_STR_COPY, HasCopyCall);
 StrAssert('Copy(SAPT20, 2, 3) nettoie la pile (ADD ESP,12)', HasCopyCleanup);

 { --- Delete(SAPT20, 2, 3) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Delete', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('Delete(SAPT20, 2, 3) consomme tous les tokens', PPAtEnd);
 HasDeleteCall := False; HasDeleteCleanup := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_DELETE, Line) > 0 Then HasDeleteCall := True;
  If Pos('ADD ESP,12', Line) > 0 Then HasDeleteCleanup := True;
 End;
 Close(F); Erase(F);
 StrAssert('Delete(SAPT20, 2, 3) appelle ' + DPRT_STR_DELETE, HasDeleteCall);
 StrAssert('Delete(SAPT20, 2, 3) nettoie la pile (ADD ESP,12)',
  HasDeleteCleanup);

 { --- Insert('x', SAPT20, 2) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Insert', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'x', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('Insert(''x'', SAPT20, 2) consomme tous les tokens', PPAtEnd);
 HasInsertCall := False; HasInsertCleanup := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_INSERT, Line) > 0 Then HasInsertCall := True;
  If Pos('ADD ESP,12', Line) > 0 Then HasInsertCleanup := True;
 End;
 Close(F); Erase(F);
 StrAssert('Insert(''x'', SAPT20, 2) appelle ' + DPRT_STR_INSERT,
  HasInsertCall);
 StrAssert('Insert(''x'', SAPT20, 2) nettoie la pile (ADD ESP,12)',
  HasInsertCleanup);

 { --- Pos('l', SAPT20) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Pos', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'l', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'SAPT20', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPSTRSELFTEST_END');
 StrAssert('Pos(''l'', SAPT20) consomme tous les tokens', PPAtEnd);
 HasPosCall := False; HasPosCleanup := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_STR_POS, Line) > 0 Then HasPosCall := True;
  If Pos('ADD ESP,8', Line) > 0 Then HasPosCleanup := True;
 End;
 Close(F); Erase(F);
 StrAssert('Pos(''l'', SAPT20) appelle ' + DPRT_STR_POS, HasPosCall);
 StrAssert('Pos(''l'', SAPT20) nettoie la pile (ADD ESP,8)', HasPosCleanup);

 { --- WideString/UnicodeString : stub minimal enregistre --- }
 WideIdx    := TypeFindByName('WIDESTRING');
 UnicodeIdx := TypeFindByName('UNICODESTRING');
 StrAssert('WideString enregistre comme chaine',
  (WideIdx >= 0) And (TypeTab[WideIdx].Kind = TYK_STRING));
 StrAssert('UnicodeString enregistre comme chaine',
  (UnicodeIdx >= 0) And (TypeTab[UnicodeIdx].Kind = TYK_STRING));

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ AsmSelfTest (TODO 21) : verifie ParseAsmBlock sur des suites   }
{ de jetons construites directement dans TokenPool, comme les    }
{ self-tests des TODO precedents - mnemonique + registre +        }
{ immediat, substitution d une variable locale, d une variable    }
{ globale a l interieur d une reference [...], acces a un champ   }
{ d instance via Self.Champ (chargement prealable dans EDX), et   }
{ etiquette locale @Nom: avec un saut vers elle.                   }
{ ------------------------------------------------------------ }

Procedure AsmAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('AsmSelfTest: ' + Label_ + ' a echoue');
End;

Procedure AsmSelfTest;
Const
 TmpFile = 'DPASMSELFTEST.$$$';
Var
 IntIdx, AsmClsSymIdx, AsmClsIdx : Integer;
 F : Text;
 Line : TString;
 HasBasic, HasLocal, HasGlobal, HasSelfLoad, HasSelfField : Boolean;
 HasLabel, HasDec, HasJmp : Boolean;

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

 IntIdx := TypeFindByName('Integer');

 { --- asm MOV EAX,1; end : mnemonique + registre + immediat --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'asm', 0);
 Tok(TK_IDENT, 'MOV', 0);
 Tok(TK_IDENT, 'EAX', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPASMSELFTEST_END');
 AsmAssert('asm MOV EAX,1 end consomme tous les tokens', PPAtEnd);
 HasBasic := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,1', Line) > 0 Then HasBasic := True;
 End;
 Close(F); Erase(F);
 AsmAssert('bloc asm de base traduit MOV EAX,1', HasBasic);

 { --- variable locale : asm MOV EAX,MyLocal; end --- }
 SymEnterScope;
  LocalAdd('MYLOCALASM', IntIdx);
  TokenPoolInit;
  Tok(TK_KEYWORD, 'asm', 0);
  Tok(TK_IDENT, 'MOV', 0);
  Tok(TK_IDENT, 'EAX', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_IDENT, 'MyLocalAsm', 0);
  Tok(TK_PUNCT, ';', 0);
  Tok(TK_KEYWORD, 'end', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPASMSELFTEST_END');
  AsmAssert('asm avec variable locale consomme tous les tokens', PPAtEnd);
 SymLeaveScope;
 HasLocal := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,DWORD PTR [EBP-4]', Line) > 0 Then HasLocal := True;
 End;
 Close(F); Erase(F);
 AsmAssert('variable locale traduite en [EBP-4]', HasLocal);

 { --- variable globale a l interieur de [...] : asm MOV EAX,[EBX+MyGlobal]; end --- }
 GlobalVarDeclare('MYGLOBALASM', IntIdx, 0);
 TokenPoolInit;
 Tok(TK_KEYWORD, 'asm', 0);
 Tok(TK_IDENT, 'MOV', 0);
 Tok(TK_IDENT, 'EAX', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_PUNCT, '[', 0);
 Tok(TK_IDENT, 'EBX', 0);
 Tok(TK_OP, '+', 0);
 Tok(TK_IDENT, 'MyGlobalAsm', 0);
 Tok(TK_PUNCT, ']', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPASMSELFTEST_END');
 AsmAssert('asm avec variable globale en bracket consomme tous les tokens',
  PPAtEnd);
 HasGlobal := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  { les espaces autour des jetons a l interieur de [...] sont tolerees }
  { par MASM (voir TranslateAsmOperand) : on ne verifie donc pas       }
  { l adjacence stricte 'EBX+', seulement la presence des deux         }
  { composantes et de l operateur.                                     }
  If (Pos('EBX', Line) > 0) And (Pos('+', Line) > 0) And
     (Pos(DP_VAR_PFX, Line) > 0) Then
   HasGlobal := True;
 End;
 Close(F); Erase(F);
 AsmAssert('variable globale substituee dans [EBX+...]', HasGlobal);

 { --- Self.FValue : champ d instance --- }
 FrameInit;
 SymEnterScope;
  AsmClsSymIdx := SymDeclareClass('TASMSELFTESTCLS', SK_CLASS, -1);
  AsmClsIdx    := SymTab[AsmClsSymIdx].TypeIdx;
  FieldInitInherit(AsmClsIdx);
  TypeAddField(AsmClsIdx, 'FVALUE', IntIdx);
  VMTInit(AsmClsIdx);
  ParamAdd('SELF', AsmClsIdx, PK_VALUE);

  TokenPoolInit;
  Tok(TK_KEYWORD, 'asm', 0);
  Tok(TK_IDENT, 'MOV', 0);
  Tok(TK_IDENT, 'EAX', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_IDENT, 'Self', 0);
  Tok(TK_PUNCT, '.', 0);
  Tok(TK_IDENT, 'FValue', 0);
  Tok(TK_PUNCT, ';', 0);
  Tok(TK_KEYWORD, 'end', 0);
  ParserInit;
  CurSelfTypeIdx := AsmClsIdx;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPASMSELFTEST_END');
  AsmAssert('asm avec Self.Champ consomme tous les tokens', PPAtEnd);
  CurSelfTypeIdx := -1;
 SymLeaveScope;
 HasSelfLoad := False; HasSelfField := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EDX,DWORD PTR [EBP+8]', Line) > 0 Then HasSelfLoad := True;
  If Pos('MOV EAX,DWORD PTR [EDX+4]', Line) > 0 Then HasSelfField := True;
 End;
 Close(F); Erase(F);
 AsmAssert('Self charge dans EDX avant l acces au champ', HasSelfLoad);
 AsmAssert('Self.FValue traduit en [EDX+4]', HasSelfField);

 { --- etiquette locale @Boucle: et saut JNZ @Boucle --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'asm', 0);
 Tok(TK_OP, '@', 0);
 Tok(TK_IDENT, 'Boucle', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'DEC', 0);
 Tok(TK_IDENT, 'ECX', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'JNZ', 0);
 Tok(TK_OP, '@', 0);
 Tok(TK_IDENT, 'Boucle', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPASMSELFTEST_END');
 AsmAssert('asm avec etiquette locale consomme tous les tokens', PPAtEnd);
 HasLabel := False; HasDec := False; HasJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('@Boucle:', Line) > 0 Then HasLabel := True;
  If Pos('DEC ECX', Line) > 0 Then HasDec := True;
  If Pos('JNZ @Boucle', Line) > 0 Then HasJmp := True;
 End;
 Close(F); Erase(F);
 AsmAssert('etiquette locale @Boucle: emise', HasLabel);
 AsmAssert('DEC ECX emis inchange', HasDec);
 AsmAssert('JNZ @Boucle emis inchange', HasJmp);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ Rtl22SelfTest (TODO 22) : verifie les intrinseques System      }
{ (GetMem/FreeMem/ReallocMem/Move/FillChar/Sqr/Abs/Assigned/      }
{ FreeAndNil/High-Low sur un type ordinal) et les corps reels      }
{ de TList/TStringList emis par EmitRuntimeLibrary, avec des        }
{ suites de tokens construites directement dans TokenPool, comme    }
{ les self-tests des TODO precedents.                                 }
{ ------------------------------------------------------------ }

Procedure Rtl22Assert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('Rtl22SelfTest: ' + Label_ + ' a echoue');
End;

Procedure Rtl22SelfTest;
Const
 TmpFile = 'DPRTL22SELFTEST.$$$';
Var
 IntIdx, PtrIdx : Integer;
 TListIdx, TSLIdx : Integer;
 TLCreateSym, TLAddSym, TLDelSym : Integer;
 TSLCreateSym, TSLAddSym, TSLDelSym, TSLClearSym : Integer;
 F : Text;
 Line : TString;
 HasGetMemAlloc, HasFreeMemFree, HasReallocCall : Boolean;
 HasMoveRep, HasFillRep : Boolean;
 HasSqrMul, HasAbsNeg, HasAssignedCmp : Boolean;
 HasFreeAndNilCall, HasFreeAndNilNil : Boolean;
 HasHighByte, HasLowByte : Boolean;
 HasTLCreateLbl, HasTLAddLbl, HasTLHeapAlloc, HasTLHeapRealloc, HasTLDelShift : Boolean;
 StrAssignCount : Integer;

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

 IntIdx := TypeFindByName('Integer');
 PtrIdx := TypeFindByName('Pointer');

 SymEnterScope;
  LocalAdd('PPTR22', PtrIdx);

  { --- GetMem(P, 10) --- }
  TokenPoolInit;
  Tok(TK_IDENT, 'GetMem', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'PPtr22', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_INTEGER, '10', 10);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPRTL22_END');
  Rtl22Assert('GetMem consomme tous les tokens', PPAtEnd);
  HasGetMemAlloc := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('CALL HeapAlloc', Line) > 0 Then HasGetMemAlloc := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('GetMem appelle HeapAlloc', HasGetMemAlloc);

  { --- FreeMem(P) --- }
  TokenPoolInit;
  Tok(TK_IDENT, 'FreeMem', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'PPtr22', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPRTL22_END');
  Rtl22Assert('FreeMem consomme tous les tokens', PPAtEnd);
  HasFreeMemFree := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('CALL HeapFree', Line) > 0 Then HasFreeMemFree := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('FreeMem appelle HeapFree', HasFreeMemFree);

  { --- ReallocMem(P, 20) --- }
  TokenPoolInit;
  Tok(TK_IDENT, 'ReallocMem', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'PPtr22', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_INTEGER, '20', 20);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPRTL22_END');
  Rtl22Assert('ReallocMem consomme tous les tokens', PPAtEnd);
  HasReallocCall := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('CALL HeapReAlloc', Line) > 0 Then HasReallocCall := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('ReallocMem appelle HeapReAlloc', HasReallocCall);

  { --- Move(Src, Dest, 5) / FillChar(Src, 5, 0) --- }
  LocalAdd('SRC22', IntIdx);
  LocalAdd('DST22', IntIdx);
  TokenPoolInit;
  Tok(TK_IDENT, 'Move', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Src22', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_IDENT, 'Dst22', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_INTEGER, '5', 5);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPRTL22_END');
  Rtl22Assert('Move consomme tous les tokens', PPAtEnd);
  HasMoveRep := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('REP MOVSB', Line) > 0 Then HasMoveRep := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('Move emet REP MOVSB', HasMoveRep);

  TokenPoolInit;
  Tok(TK_IDENT, 'FillChar', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Src22', 0);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_INTEGER, '5', 5);
  Tok(TK_PUNCT, ',', 0);
  Tok(TK_INTEGER, '0', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParseStmt;
  EmitClose('DPRTL22_END');
  Rtl22Assert('FillChar consomme tous les tokens', PPAtEnd);
  HasFillRep := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('REP STOSB', Line) > 0 Then HasFillRep := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('FillChar emet REP STOSB', HasFillRep);

  { --- Sqr(Src22) / Abs(Src22) / Assigned(Src22) --- }
  TokenPoolInit;
  Tok(TK_IDENT, 'Sqr', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Src22', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParsePrimary;
  EmitClose('DPRTL22_END');
  Rtl22Assert('Sqr consomme tous les tokens', PPAtEnd);
  HasSqrMul := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('IMUL EAX,EAX', Line) > 0 Then HasSqrMul := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('Sqr emet IMUL EAX,EAX', HasSqrMul);

  TokenPoolInit;
  Tok(TK_IDENT, 'Abs', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Src22', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParsePrimary;
  EmitClose('DPRTL22_END');
  Rtl22Assert('Abs consomme tous les tokens', PPAtEnd);
  HasAbsNeg := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('NEG EAX', Line) > 0 Then HasAbsNeg := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('Abs emet NEG EAX', HasAbsNeg);

  TokenPoolInit;
  Tok(TK_IDENT, 'Assigned', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Src22', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParsePrimary;
  EmitClose('DPRTL22_END');
  Rtl22Assert('Assigned consomme tous les tokens', PPAtEnd);
  HasAssignedCmp := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('JNE ', Line) > 0 Then HasAssignedCmp := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('Assigned utilise JNE (EmitCompareZeroJcc)', HasAssignedCmp);
 SymLeaveScope;

 { --- High(Byte) / Low(Byte) : bornes d un type ordinal predefini --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'High', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'Byte', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTL22_END');
 Rtl22Assert('High(Byte) consomme tous les tokens', PPAtEnd);
 HasHighByte := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,255', Line) > 0 Then HasHighByte := True;
 End;
 Close(F); Erase(F);
 Rtl22Assert('High(Byte) = 255', HasHighByte);

 TokenPoolInit;
 Tok(TK_IDENT, 'Low', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'Byte', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTL22_END');
 Rtl22Assert('Low(Byte) consomme tous les tokens', PPAtEnd);
 HasLowByte := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,0', Line) > 0 Then HasLowByte := True;
 End;
 Close(F); Erase(F);
 Rtl22Assert('Low(Byte) = 0', HasLowByte);

 { --- FreeAndNil(Obj) : X.Free suivi de X := nil --- }
 SymEnterScope;
  LocalAdd('OBJ22', SymTab[SymFind('TObject')].TypeIdx);
  TokenPoolInit;
  Tok(TK_IDENT, 'FreeAndNil', 0);
  Tok(TK_PUNCT, '(', 0);
  Tok(TK_IDENT, 'Obj22', 0);
  Tok(TK_PUNCT, ')', 0);
  ParserInit;
  EmitOpen(TmpFile);
  ParsePrimary;
  EmitClose('DPRTL22_END');
  Rtl22Assert('FreeAndNil consomme tous les tokens', PPAtEnd);
  HasFreeAndNilCall := False; HasFreeAndNilNil := False;
  {$I-} Assign(F, TmpFile); Reset(F); {$I+}
  While Not Eof(F) Do
  Begin
   ReadLn(F, Line);
   If Pos('CALL ', Line) > 0 Then HasFreeAndNilCall := True;
   If Pos('MOV EAX,0', Line) > 0 Then HasFreeAndNilNil := True;
  End;
  Close(F); Erase(F);
  Rtl22Assert('FreeAndNil appelle une methode (Free)', HasFreeAndNilCall);
  Rtl22Assert('FreeAndNil affecte nil (0) a la variable', HasFreeAndNilNil);
 SymLeaveScope;

 { --- TList/TStringList : corps reels emis par EmitRuntimeLibrary --- }
 EmitSkeletonProgram(TmpFile);
 TListIdx := SymFind('TList');
 TSLIdx   := SymFind('TStringList');
 Rtl22Assert('TList enregistre', TListIdx >= 0);
 Rtl22Assert('TStringList enregistre', TSLIdx >= 0);
 TLCreateSym  := SymFindInClass(TListIdx, 'CREATE');
 TLAddSym     := SymFindInClass(TListIdx, 'ADD');
 TLDelSym     := SymFindInClass(TListIdx, 'DELETE');
 TSLCreateSym := SymFindInClass(TSLIdx, 'CREATE');
 TSLAddSym    := SymFindInClass(TSLIdx, 'ADD');
 TSLDelSym    := SymFindInClass(TSLIdx, 'DELETE');
 TSLClearSym  := SymFindInClass(TSLIdx, 'CLEAR');

 HasTLCreateLbl := False; HasTLAddLbl := False;
 HasTLHeapAlloc := False; HasTLHeapRealloc := False; HasTLDelShift := False;
 StrAssignCount := 0;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If (TLCreateSym >= 0) And (Line = SymTab[TLCreateSym].MangledName + ':') Then
   HasTLCreateLbl := True;
  If (TLAddSym >= 0) And (Line = SymTab[TLAddSym].MangledName + ':') Then
   HasTLAddLbl := True;
  If Pos('CALL HeapAlloc', Line) > 0 Then HasTLHeapAlloc := True;
  If Pos('CALL HeapReAlloc', Line) > 0 Then HasTLHeapRealloc := True;
  If Pos('REP MOVSD', Line) > 0 Then HasTLDelShift := True;
  If Pos('CALL ' + DPRT_STR_ASSIGN, Line) > 0 Then Inc(StrAssignCount);
 End;
 Close(F); Erase(F);
 Rtl22Assert('TList.Create emis (' + SymTab[TLCreateSym].MangledName + ')',
  HasTLCreateLbl);
 Rtl22Assert('TList.Add emis (' + SymTab[TLAddSym].MangledName + ')', HasTLAddLbl);
 Rtl22Assert('TList utilise HeapAlloc (premiere allocation)', HasTLHeapAlloc);
 Rtl22Assert('TList utilise HeapReAlloc (croissance)', HasTLHeapRealloc);
 Rtl22Assert('TList.Delete decale via REP MOVSD', HasTLDelShift);
 Rtl22Assert('TStringList appelle ' + DPRT_STR_ASSIGN + ' (Add/Delete/Clear)',
  StrAssignCount >= 3);
 Rtl22Assert('TStringList.Create/Add/Delete/Clear enregistres',
  (TSLCreateSym >= 0) And (TSLAddSym >= 0) And (TSLDelSym >= 0) And
  (TSLClearSym >= 0));

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ============================================================ }
{ TODO 23 - FICHIERS PROJET (.dpr) ET UNITES (.pas) [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseConstDecl : CONST Nom = ValeurEntiere; [Nom2 = ...;]*     }
{ Reutilise ParseConstIntLiteral (TODO 19, litteral entier/char   }
{ ou nom de constante deja definie, avec signe optionnel) plutot  }
{ que ParseExpr (qui emettrait du code) ou ConstEvalExpr (qui      }
{ travaille sur du TEXTE de directive, pas sur le TokenPool) -      }
{ simplification documentee : pas de constantes chaine/flottantes  }
{ ni d expression arithmetique generale (a+b, a*b...) pour l       }
{ instant, seulement litteral/constante-nommee avec signe.          }
{ ------------------------------------------------------------ }

Procedure ParseConstDecl;
Var
 Name, Up : TString;
 V    : LongInt;
 SI   : Integer;
Begin
 PPAdvance;   { const }
 While PPPeekKind = TK_IDENT Do
 Begin
  Name := TokenPool[PP].Val;
  PPAdvance;
  PPMatch('=');
  V := ParseConstIntLiteral;
  SI := SymAdd(Name, SK_CONST, TypeFindByName('Integer'));
  If SI >= 0 Then SymTab[SI].ImmVal := V;

  { Filet de securite : une valeur non geree par ParseConstIntLiteral   }
  { (chaine, flottant, concatenation 'A'#13#10'B'...) peut laisser des   }
  { jetons non consommes avant le ';' - les ignorer plutot que de         }
  { desynchroniser tout le reste du fichier (Const/Type/Var suivants,      }
  { puis Procedure/Function, puis Begin...End.). ParseConstIntLiteral a     }
  { deja emis un avertissement dans ce cas ; ce filet ne fait que limiter   }
  { les degats a CETTE seule constante (valeur 0), pas au fichier entier.    }
  While Not PPAtEnd Do
  Begin
   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then Break;
   If PPPeekKind = TK_KEYWORD Then
   Begin
    Up := StrUpperCase(PPPeekVal);
    If (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'VAR') Or (Up = 'BEGIN') Or
       (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then Break;
   End;
   PPAdvance;
  End;
  SkipOptSemi;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseGlobalDeclSection : sections Const/Type/Var au niveau      }
{ PRINCIPAL d un Program/Unit (pas a l interieur d une procedure/  }
{ fonction - voir ParseDeclSection, TODO 09/14, pour les sections   }
{ LOCALES, qui restent inchangees). Var y utilise GlobalVarDeclare  }
{ (TODO 09 : reserve l espace en .DATA ET la table des symboles)    }
{ plutot que LocalAdd (qui suppose un cadre de pile EBP-relatif,     }
{ inexistant au niveau principal). Const/Type sont ici reellement    }
{ geres (ParseConstDecl ci-dessus / ParseTypeDecl, TODO 15/17/19),    }
{ contrairement au stub avertissement+saut de ParseDeclSection.       }
{                                                                      }
{ SIMPLIFICATION DOCUMENTEE (TODO 23) : toutes les sections            }
{ Const/Type/Var d une meme zone de declarations (avant Begin, ou      }
{ avant le premier Procedure/Function/methode hors-ligne) doivent      }
{ preceder TEXTUELLEMENT cette premiere routine - Pascal autorise en   }
{ toute generalite un entrelacement arbitraire (var, procedure, var,   }
{ procedure, ...), mais ce compilateur emet le code de chaque          }
{ procedure/fonction IMMEDIATEMENT au moment de son analyse (pas de    }
{ registre differe ni de second passage, TODO 22) alors que .DATA      }
{ (EmitDataSeg) doit etre emis EN BLOC, une seule fois, une fois        }
{ TOUTES les globales connues - cette regle evite d avoir a re-ouvrir   }
{ .DATA apres avoir deja commence a emettre du code. Cette boucle       }
{ s arrete donc des qu elle rencontre Procedure/Function/Constructor/   }
{ Destructor/Begin, laissant l appelant driver (ParseProgramOrLibrary/  }
{ ParseUnitFile) continuer a partir de la.                               }
{ ------------------------------------------------------------ }

Procedure ParseGlobalDeclSection;
Var
 Up    : TString;
 Names : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 NCount, I, TIdx : Integer;
Begin
 While PPPeekKind = TK_KEYWORD Do
 Begin
  Up := StrUpperCase(PPPeekVal);

  If Up = 'CONST' Then Begin ParseConstDecl; Continue; End;

  If Up = 'TYPE' Then
  Begin
   { Un seul mot-cle TYPE couvre generalement PLUSIEURS declarations   }
   { (Type A = ...; B = ...; C = ...;) - le style Delphi le plus        }
   { courant. ParseOneTypeDecl (contrairement a ParseTypeDecl) ne         }
   { consomme pas TYPE elle-meme : boucler ici tant qu un identificateur   }
   { suit (chaque declaration commence par Nom '=').                       }
   PPAdvance;   { type }
   While PPPeekKind = TK_IDENT Do ParseOneTypeDecl;
   Continue;
  End;

  If Up = 'VAR' Then
  Begin
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
    TIdx := ParseTypeExpr;

    For I := 0 To NCount - 1 Do GlobalVarDeclare(Names[I], TIdx, 0);
    SkipOptSemi;
   End;
   Continue;
  End;

  { Dans une section INTERFACE (TODO 23), une signature Procedure/     }
  { Function n a pas de corps : ParseProcOrFuncDecl la traite comme    }
  { un forward implicite (InInterfaceSection) et revient aussitot,      }
  { sans rien emettre - donc sans danger vis-a-vis de l ordre           }
  { EmitDataSeg/EmitCodeSeg. Ailleurs (Program ou section                }
  { IMPLEMENTATION), une Procedure/Function a un VRAI corps qui doit     }
  { attendre que .DATA/.CODE soient deja emis (ParseTopLevelRoutines,     }
  { appelee par l appelant APRES cette section) : on s arrete donc ici.   }
  If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
  Begin
   If InInterfaceSection Then Begin ParseProcOrFuncDecl; Continue; End;
   Break;
  End;

  Break;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseUsesClause : USES Nom1 [IN 'Fichier1.pas'] [, Nom2 ...] ;  }
{ Analyse et valide la syntaxe (y compris la forme 'IN' propre     }
{ aux .dpr). SIMPLIFICATION DOCUMENTEE (TODO 23) : la compilation   }
{ multi-fichiers reelle (lecture/compilation de chaque Unit.pas     }
{ referencee, puis liaison) attend le veritable emetteur OBJ         }
{ (TODO 24, explicitement reserve a cet effet par la feuille de       }
{ route elle-meme) - les unites systeme (System/SysUtils/Classes)     }
{ sont de toute facon deja disponibles globalement comme des           }
{ symboles integres (TODO 12/18/19/20/22), sans fichier .pas reel a     }
{ charger.                                                                }
{ ------------------------------------------------------------ }

Procedure ParseUsesClause;
Begin
 PPAdvance;   { uses }
 Repeat
  PPAdvance;   { nom d unite }
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'IN') Then
  Begin
   PPAdvance;   { in }
   PPAdvance;   { 'Fichier.pas' }
  End;
 Until Not PPMatch(',');
 SkipOptSemi;
End;

{ ------------------------------------------------------------ }
{ ParseTopLevelRoutines : boucle sur les declarations Procedure/  }
{ Function/Constructor/Destructor de plus haut niveau - routines   }
{ ordinaires (ParseProcOrFuncDecl, TODO 14) ou corps hors-ligne     }
{ d une methode deja declaree dans un corps de classe               }
{ (ParseMethodBodyDecl, TODO 15 : motif Classe.Methode, reconnu      }
{ par la presence d un '.' au troisieme jeton). Reutilisee par le     }
{ Program/Library principal et par la section Implementation d une   }
{ Unit.                                                                 }
{ ------------------------------------------------------------ }

Procedure ParseTopLevelRoutines;
Var Up: TString;
Begin
 While PPPeekKind = TK_KEYWORD Do
 Begin
  Up := StrUpperCase(PPPeekVal);
  If (Up <> 'PROCEDURE') And (Up <> 'FUNCTION') And
     (Up <> 'CONSTRUCTOR') And (Up <> 'DESTRUCTOR') Then
   Break;

  If ((PP + 2) < TokenCount) And (TokenPool[PP + 2].Kind = TK_PUNCT) And
     (TokenPool[PP + 2].Val = '.') Then
   ParseMethodBodyDecl
  Else
   ParseProcOrFuncDecl;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseProgramOrLibraryFile : PROGRAM|LIBRARY Nom; [uses ...;]     }
{ <Const/Type/Var...> <Procedure/Function/methode...> Begin ...     }
{ End. Pilote le tout premier compile REEL d un fichier source de     }
{ ce compilateur (TODO 23) : jusqu ici, ParseStmt/ParseDeclSection/    }
{ ParseProcOrFuncDecl/ParseClassDecl (TODO 10-22) n etaient exerces     }
{ que par leurs propres self-tests, sur des suites de jetons             }
{ synthetiques - aucun point d entree de plus haut niveau ne les          }
{ enchainait sur un VRAI fichier .pas/.dpr lexe en entier.                  }
{ Library (bibliotheque dynamique) est reconnue et suit exactement le      }
{ meme chemin qu un Program ici - un point d entree/export DLL reel         }
{ specifique attend la generation PE/OBJ (TODO 24, qui possede aussi le     }
{ vrai .OBJ des Unit ci-dessous).                                            }
{ ------------------------------------------------------------ }

Procedure ParseProgramOrLibraryFile(IsLibrary: Boolean; Const AsmFilePath: TString);
Var ProgName: TString;
Begin
 PPAdvance;   { program|library }
 ProgName := TokenPool[PP].Val;
 PPAdvance;
 SkipOptSemi;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'USES') Then
  ParseUsesClause;

 { Depuis le TODO 24, la generation de code (texte .asm intermediaire,   }
 { toujours produit maintenant - plus seulement sous -asm) est           }
 { INCONDITIONNELLE : c est l assembleur maison (AsmAssembleFile, plus     }
 { bas) qui relit ensuite ce texte pour ecrire un vrai .exe/.obj. -asm      }
 { ne controle plus que la CONSERVATION de ce fichier intermediaire         }
 { (sinon efface par Run une fois l assemblage termine).                      }
 EmitOpen(AsmFilePath);
 EmitHeader;
 If IsLibrary Then
  EmitComment('Bibliotheque (LIBRARY) ' + ProgName +
   ' : export/entree DLL reels -> TODO 24')
 Else
  EmitComment('Programme ' + ProgName);

 ParseGlobalDeclSection;

 EmitDataSeg;
 EmitCodeSeg;
 EmitRuntimeLibrary;

 ParseTopLevelRoutines;

 EmitClassVMTs;   { maintenant que tous les corps hors-ligne sont connus (TODO 25) }
 EmitInterfaceThunks;   { idem, tables de thunks d interface (TODO 25) }
 EmitUserExterns;   { maintenant que tout 'external' est connu }

 EmitLabel(DP_FUNC_PFX + 'MAIN');
 EmitProlog(0);
 EmitInstr('CALL ' + DPRT_INIT);

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'BEGIN') Then
  ParseCompoundStmt
 Else
  WarnMsg('bloc principal begin...end. attendu');
 If Not PPMatch('.') Then
  WarnMsg('"." attendu apres le end du bloc principal de ' + ProgName);
 If Not PPAtEnd Then
  WarnMsg('jetons superflus apres la fin du programme ' + ProgName);

 EmitInstr('PUSH 0');
 EmitInstr('CALL ExitProcess');
 EmitEpilog;
 EmitClose(DP_FUNC_PFX + 'MAIN');
End;

{ ------------------------------------------------------------ }
{ ParseUnitFile : UNIT Nom; INTERFACE [uses ...;] <declarations>  }
{ IMPLEMENTATION [uses ...;] <declarations + routines> [           }
{ INITIALIZATION <instructions>] [FINALIZATION <instructions>]      }
{ END. Les declarations des DEUX sections sont enregistrees dans     }
{ la MEME table des symboles globale que pour un Program (ce           }
{ compilateur n a pas encore de frontiere de module/namespace          }
{ separee) mais, depuis le TODO 25, une Unite compilee seule PRODUIT     }
{ desormais un vrai .OBJ (COFF) : le meme pipeline que                    }
{ ParseProgramOrLibraryFile (EmitDataSeg/EmitCodeSeg/EmitRuntimeLibrary,    }
{ ParseTopLevelRoutines, EmitClassVMTs, EmitInterfaceThunks,                 }
{ EmitUserExterns) est rejoue ici, MAIS sans bloc principal                  }
{ begin...end/ExitProcess (une Unite n en a pas) - chaque routine             }
{ declaree dans INTERFACE devient un symbole COFF PUBLIC reel dans le          }
{ .OBJ produit (WriteCOFFObj marque deja TOUTE etiquette PUBLIC par             }
{ simplification, TODO 24), adressable par un editeur de liens externe.          }
{ Initialization/Finalization sont emises comme de VRAIES routines               }
{ etiquetees (_DPF_<NOM>_INIT/_FINI) plutot que seulement validees puis           }
{ jetees - mais RIEN ne les appelle automatiquement : aucun vrai pilote            }
{ multi-fichiers (chainage reel des sections Initialization de toutes les          }
{ unites d un programme, comme le ferait un vrai linker Delphi) n existe            }
{ dans ce compilateur - limitation documentee, restant hors de portee du            }
{ TODO 25 (qui ne demandait que la VALIDATION des exemples existants,                }
{ pas la liaison multi-fichiers elle-meme, deja explicitement differee au             }
{ TODO 23/24).                                                                          }
{ ------------------------------------------------------------ }

Procedure ParseUnitFile(Const AsmFilePath: TString);
Var UnitName: TString;
Begin
 PPAdvance;   { unit }
 UnitName := TokenPool[PP].Val;
 PPAdvance;
 SkipOptSemi;

 EmitOpen(AsmFilePath);
 EmitHeader;
 EmitComment('Unite ' + UnitName);

 If Not PPMatch('interface') Then
  WarnMsg('interface attendu dans l unite ' + UnitName);
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'USES') Then
  ParseUsesClause;
 InInterfaceSection := True;
 ParseGlobalDeclSection;
 InInterfaceSection := False;

 EmitDataSeg;
 EmitCodeSeg;
 EmitRuntimeLibrary;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'IMPLEMENTATION') Then
 Begin
  PPAdvance;
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'USES') Then
   ParseUsesClause;
  ParseGlobalDeclSection;
  ParseTopLevelRoutines;
 End
 Else
  WarnMsg('implementation attendu dans l unite ' + UnitName);

 EmitClassVMTs;
 EmitInterfaceThunks;
 EmitUserExterns;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'INITIALIZATION') Then
 Begin
  PPAdvance;
  EmitComment('Initialization de ' + UnitName + ' (jamais appelee ' +
   'automatiquement - aucun pilote multi-fichiers, TODO 25)');
  EmitLabel(DP_FUNC_PFX + StrUpperCase(UnitName) + '_INIT');
  EmitProlog(0);
  ParseStmtSeq;
  EmitEpilog;
  EmitBlankLine;
 End;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'FINALIZATION') Then
 Begin
  PPAdvance;
  EmitComment('Finalization de ' + UnitName + ' (jamais appelee ' +
   'automatiquement - aucun pilote multi-fichiers, TODO 25)');
  EmitLabel(DP_FUNC_PFX + StrUpperCase(UnitName) + '_FINI');
  EmitProlog(0);
  ParseStmtSeq;
  EmitEpilog;
  EmitBlankLine;
 End;

 If Not PPMatch('end') Then
  WarnMsg('end attendu en fin de l unite ' + UnitName);
 If Not PPMatch('.') Then
  WarnMsg('"." attendu apres end en fin de l unite ' + UnitName);
 If Not PPAtEnd Then
  WarnMsg('jetons superflus apres la fin de l unite ' + UnitName);

 EmitClose('');
End;

{ Declarations anticipees (TODO 24) : l assembleur/emetteur PE/COFF     }
{ est defini plus bas dans le fichier (apres CompileSourceFile, qui       }
{ pilote la compilation reelle TODO 23) mais est appele DEPUIS              }
{ CompileSourceFile - ordre habituel du fichier (TODO le plus recent en      }
{ dernier), donc Forward ici, comme ParseProcOrFuncDecl/ParseTypeExpr        }
{ (TODO 14/19) plus haut.                                                       }
Procedure AsmAssembleFile(Const AsmPath: TString); Forward;
Procedure AsmResolveRel32Fixups; Forward;
Procedure WritePEExe(Const OutPath: TString); Forward;
Procedure WriteCOFFObj(Const OutPath: TString); Forward;

{ ------------------------------------------------------------ }
{ CompileSourceFile : detecte Program vs Unit vs Library (premier }
{ mot-cle reel du fichier lexe) et pilote le compilateur en         }
{ consequence - point d entree unique du TODO 23. Un fichier .dfm     }
{ (formulaire VCL) est hors perimetre (pas de VCL graphique dans       }
{ ce projet) : detecte par extension et simplement ignore, avec un      }
{ avertissement, sans tenter de le lexer/parser (sa syntaxe binaire      }
{ ou texte proprietaire n a rien a voir avec du Pascal).                  }
{ ------------------------------------------------------------ }

{ ------------------------------------------------------------ }
{ AdjustOutFileForUnitIfNeeded (TODO 25) : une Unite compilee     }
{ seule ne peut jamais devenir un .exe (pas de point d entree),   }
{ seulement un .obj - si l utilisateur n a pas explicitement       }
{ choisi le nom de sortie ni -obj, deriver .obj des maintenant.      }
{ Appelee depuis Run (avant ShowBanner, pour que la banniere         }
{ affiche deja la bonne extension/le bon mode) ET depuis               }
{ CompileSourceFile (ou l appel est idempotent si deja fait) - PP        }
{ doit deja pointer sur le premier jeton reel (ParserInit+lexage).         }
{ ------------------------------------------------------------ }

Procedure AdjustOutFileForUnitIfNeeded;
Begin
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'UNIT') And
    (Not Opts.OutFileGiven) And (Not Opts.ObjOnly) Then
  Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj');
End;

Procedure CompileSourceFile;
Var
 Ext, Up, AsmFilePath : TString;
 IsProgramOrLibrary, IsUnit, DidEmit : Boolean;
 TmpAsmF : Text;
Begin
 Ext := ExtractExt(Opts.SrcFile);
 If Ext = '.DFM' Then
 Begin
  WarnMsg('fichier .dfm (formulaire VCL) hors perimetre : ignore');
  Exit;
 End;

 If PPAtEnd Then
 Begin
  WarnMsg('fichier source vide');
  Exit;
 End;

 If PPPeekKind <> TK_KEYWORD Then
 Begin
  WarnMsg('Program, Unit ou Library attendu en tete de fichier');
  Exit;
 End;

 Up := StrUpperCase(PPPeekVal);
 IsUnit := (Up = 'UNIT');

 { Idempotent si deja fait par Run avant ShowBanner (TODO 25) - une     }
 { Unite n a pas de point d entree, donc jamais de .exe direct.           }
 AdjustOutFileForUnitIfNeeded;

 { Depuis le TODO 24, le texte .asm est TOUJOURS produit (l assembleur   }
 { maison en a besoin, meme si -asm n a pas ete demande) : ecrit dans le  }
 { fichier REEL si -asm, sinon dans un fichier temporaire efface a la      }
 { fin de cette procedure.                                                   }
 If Opts.AsmOutput Then
  AsmFilePath := ReplaceExt(Opts.OutFile, '.asm')
 Else
  AsmFilePath := 'DPASMTMP.$$$';

 IsProgramOrLibrary := False;
 If Up = 'PROGRAM' Then
 Begin
  ParseProgramOrLibraryFile(False, AsmFilePath);
  IsProgramOrLibrary := True;
 End
 Else If Up = 'LIBRARY' Then
 Begin
  ParseProgramOrLibraryFile(True, AsmFilePath);
  IsProgramOrLibrary := True;
 End
 Else If IsUnit Then
  ParseUnitFile(AsmFilePath)
 Else
  WarnMsg('Program, Unit ou Library attendu en tete de fichier (trouve: ' +
   PPPeekVal + ')');

 { TODO 24/25 : assembler le texte .asm qui vient d etre produit et      }
 { ecrire un vrai binaire. Program/Library : .OBJ (COFF) si -obj, sinon    }
 { .EXE (PE) par defaut. Unit : TOUJOURS .OBJ (COFF), quel que soit -obj    }
 { (aucun point d entree possible pour un .exe) - chaque routine declaree    }
 { dans son INTERFACE devient un symbole COFF PUBLIC reel (WriteCOFFObj      }
 { marque deja toute etiquette PUBLIC par simplification, TODO 24),           }
 { adressable par un editeur de liens externe.                                  }
 DidEmit := IsProgramOrLibrary Or IsUnit;
 If DidEmit And (ErrorCount = 0) Then
 Begin
  AsmAssembleFile(AsmFilePath);
  { La resolution des fixups REL32 differe entre les deux modes (TODO 24) :}
  { -obj (WriteCOFFObj) fait SA PROPRE resolution "locale seulement"        }
  { (AsmResolveLocalRel32Fixups, pas de vignette IAT - un CALL vers un        }
  { import reste une relocation COFF pour l editeur de liens) ; le mode       }
  { EXE (WritePEExe) a besoin de la resolution COMPLETE (vignettes IAT)        }
  { AVANT de calculer la disposition PE, donc appelee ici.                       }
  If IsUnit Or Opts.ObjOnly Then
   WriteCOFFObj(Opts.OutFile)
  Else
  Begin
   AsmResolveRel32Fixups;
   WritePEExe(Opts.OutFile);
  End;
 End;

 { Depuis le TODO 25, une Unite appelle elle aussi EmitOpen (comme un   }
 { Program/Library) : le fichier .asm temporaire existe donc bien pour    }
 { les trois cas et doit etre efface de la meme facon si -asm n a pas      }
 { ete demande.                                                              }
 If DidEmit And (Not Opts.AsmOutput) Then
 Begin
  Assign(TmpAsmF, AsmFilePath);
  {$I-} Erase(TmpAsmF); {$I+}
 End;
End;

{ ------------------------------------------------------------ }
{ Prog23SelfTest (TODO 23) : verifie ParseConstDecl, la section   }
{ globale Const/Type/Var de ParseGlobalDeclSection, ParseUsesClause}
{ (formes simple et 'in'), puis un compile REEL de bout en bout    }
{ (ParseProgramOrLibraryFile et ParseUnitFile) sur des suites de    }
{ jetons construites directement dans TokenPool, comme les self-     }
{ tests des TODO precedents - y compris un test de non-regression    }
{ pour le piege trouve pendant le developpement : une signature       }
{ Procedure/Function dans la section INTERFACE d une Unit (sans        }
{ corps ni 'forward' explicite) desynchronisait silencieusement le      }
{ parseur avant la correction (InInterfaceSection).                       }
{ ------------------------------------------------------------ }

Procedure Prog23Assert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('Prog23SelfTest: ' + Label_ + ' a echoue');
End;

Procedure Prog23SelfTest;
Const
 TmpFile = 'DPPROG23SELFTEST.$$$';
Var
 SI, GTypeIdx, RecTypeIdx : Integer;
 F : Text;
 Line : TString;
 SavedAsmOutput : Boolean;
 SavedOutFile : TString;
 HasGVarStore, HasMainCall : Boolean;

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
 InInterfaceSection := False;

 { --- ParseConstDecl : Const MyConst23 = 42; --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'const', 0);
 Tok(TK_IDENT, 'MyConst23', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_INTEGER, '42', 42);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseConstDecl;
 Prog23Assert('Const consomme tous les tokens', PPAtEnd);
 SI := SymFind('MyConst23');
 Prog23Assert('MyConst23 enregistree', SI >= 0);
 Prog23Assert('MyConst23 = 42', SymTab[SI].ImmVal = 42);

 { --- ParseGlobalDeclSection : Type/Const/Var combines --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TRec23', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'record', 0);
 Tok(TK_IDENT, 'F', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'var', 0);
 Tok(TK_IDENT, 'GVar23', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseGlobalDeclSection;
 Prog23Assert('section Type/Var globale consomme tous les tokens', PPAtEnd);
 RecTypeIdx := TypeFindByName('TRec23');
 Prog23Assert('TRec23 enregistre comme record', RecTypeIdx >= 0);
 GTypeIdx := SymFind('GVar23');
 Prog23Assert('GVar23 enregistree', GTypeIdx >= 0);
 Prog23Assert('GVar23 est globale (GlobalVarDeclare, pas LocalAdd)',
  (GTypeIdx >= 0) And SymTab[GTypeIdx].IsGlobal);

 { --- ParseUsesClause : forme simple et forme 'in' --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'uses', 0);
 Tok(TK_IDENT, 'SysUtils', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'Classes', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseUsesClause;
 Prog23Assert('uses SysUtils, Classes consomme tous les tokens', PPAtEnd);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'uses', 0);
 Tok(TK_IDENT, 'Unit1', 0);
 Tok(TK_KEYWORD, 'in', 0);
 Tok(TK_STRING, 'Unit1.pas', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseUsesClause;
 Prog23Assert('uses Unit1 in ''Unit1.pas'' consomme tous les tokens', PPAtEnd);

 { --- Compile reel de bout en bout : Program avec Const/Var/Procedure --- }
 { Program Prog23T; Const K23=5; Var V23: Integer; Procedure Proc23;      }
 { Begin V23 := K23; End; Begin Proc23; End.                               }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'program', 0);
 Tok(TK_IDENT, 'Prog23T', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'const', 0);
 Tok(TK_IDENT, 'K23', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_INTEGER, '5', 5);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'var', 0);
 Tok(TK_IDENT, 'V23', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Proc23', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_IDENT, 'V23', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_IDENT, 'K23', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_IDENT, 'Proc23', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, '.', 0);
 ParserInit;

 SavedAsmOutput := Opts.AsmOutput;
 SavedOutFile   := Opts.OutFile;
 Opts.AsmOutput := True;
 Opts.OutFile   := TmpFile;
 ParseProgramOrLibraryFile(False, ReplaceExt(TmpFile, '.asm'));
 Opts.AsmOutput := SavedAsmOutput;
 Opts.OutFile   := SavedOutFile;

 Prog23Assert('Program Prog23T consomme tous les tokens', PPAtEnd);
 HasGVarStore := False; HasMainCall := False;
 {$I-} Assign(F, ReplaceExt(TmpFile, '.asm')); Reset(F); {$I+}
 Prog23Assert('Program Prog23T produit un .asm relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV DWORD PTR [_DPV_V23],EAX', Line) > 0 Then HasGVarStore := True;
  If Pos('CALL _DPF_PROC23', Line) > 0 Then HasMainCall := True;
 End;
 Close(F); Erase(F);
 Prog23Assert('K23 (const=5) affecte a la globale V23', HasGVarStore);
 Prog23Assert('le bloc principal appelle Proc23', HasMainCall);

 { --- Unit avec signature Interface puis corps Implementation : le }
 { piege corrige (InInterfaceSection) - Function DoubleIt declaree   }
 { SANS corps ni 'forward' en Interface, REDEFINIE avec un corps en   }
 { Implementation.                                                     }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'unit', 0);
 Tok(TK_IDENT, 'Unit23T', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'interface', 0);
 Tok(TK_KEYWORD, 'function', 0);
 Tok(TK_IDENT, 'DoubleIt23', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'X', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'implementation', 0);
 Tok(TK_KEYWORD, 'function', 0);
 Tok(TK_IDENT, 'DoubleIt23', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'X', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_IDENT, 'Result', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_IDENT, 'X', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, '.', 0);
 ParserInit;
 ParseUnitFile(ReplaceExt(TmpFile, '.asm'));
 Prog23Assert(
  'Unit23T (signature Interface + corps Implementation) consomme ' +
  'tous les tokens (regression InInterfaceSection)', PPAtEnd);
 SI := SymFind('DoubleIt23');
 Prog23Assert('DoubleIt23 enregistree', SI >= 0);
 Prog23Assert('DoubleIt23 a recu un corps reel (plus IsExternal)',
  (SI >= 0) And Not SymTab[SI].IsExternal);
 {$I-} Assign(F, ReplaceExt(TmpFile, '.asm')); Erase(F); {$I+}

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
 InInterfaceSection := False;
End;

{ ============================================================ }
{ TODO 24 - GENERATION PE/OBJ (EXE PAR DEFAUT, OBJ SUR DEMANDE) }
{ [IMPLEMENTE]                                                   }
{ ============================================================ }
{ NOTE : les forward-declarations AsmAssembleFile/AsmResolveRel32Fixups/}
{ WritePEExe/WriteCOFFObj (juste avant CompileSourceFile, TODO 23-24)    }
{ rendent ces noms deja utilisables ici par Todo24SelfTest, place AVANT  }
{ leur vraie definition plus bas (meme motif que ParseProcOrFuncDecl/     }
{ ParseTypeExpr, TODO 14/19).                                              }

Procedure Todo24Assert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('Todo24SelfTest: ' + Label_ + ' a echoue');
End;

{ ------------------------------------------------------------ }
{ Todo24SelfTest : compile un Program minimal de bout en bout    }
{ (comme Prog23SelfTest, TODO 23) puis va PLUS LOIN - assemble      }
{ reellement le texte .asm produit et verifie la SIGNATURE BINAIRE   }
{ du fichier obtenu (MZ/PE pour l EXE, Machine i386 pour l OBJ) :      }
{ le premier self-test de ce fichier qui verifie des OCTETS reels,     }
{ pas seulement des motifs dans du texte .asm - necessaire car c est    }
{ exactement ce que TODO 24 ajoute (un assembleur+emetteur PE/COFF       }
{ maison, TODO 23 ne produisait que du texte .asm jamais reassemble).     }
{ ------------------------------------------------------------ }

Procedure Todo24SelfTest;
Const
 TmpFile = 'DPTODO24SELFTEST.$$$';
Var
 SavedOutFile : TString;
 SavedObjOnly : Boolean;
 F : File Of Byte;
 B1, B2, B3, B4 : Byte;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

 Procedure BuildMinimalProgram;
 Begin
  TokenPoolInit;
  Tok(TK_KEYWORD, 'program', 0);
  Tok(TK_IDENT, 'P24T', 0);
  Tok(TK_PUNCT, ';', 0);
  Tok(TK_KEYWORD, 'begin', 0);
  Tok(TK_KEYWORD, 'end', 0);
  Tok(TK_PUNCT, '.', 0);
  ParserInit;
 End;

Begin
 SymInit; ClassSystemInit; DataInit; DataInit2; FrameInit; StmtInit;
 UserExternInit; InInterfaceSection := False;

 SavedOutFile := Opts.OutFile;
 SavedObjOnly := Opts.ObjOnly;

 { --- Mode EXE : Program P24T; Begin End. -> vrai .exe PE --- }
 BuildMinimalProgram;
 Opts.OutFile := TmpFile;
 Opts.ObjOnly := False;
 ParseProgramOrLibraryFile(False, ReplaceExt(TmpFile, '.asm'));
 Todo24Assert('Program P24T (EXE) consomme tous les tokens', PPAtEnd);
 AsmAssembleFile(ReplaceExt(TmpFile, '.asm'));
 AsmResolveRel32Fixups;
 WritePEExe(ReplaceExt(TmpFile, '.exe'));

 {$I-} Assign(F, ReplaceExt(TmpFile, '.exe')); Reset(F); {$I+}
 Todo24Assert('WritePEExe produit un fichier relisible', IOResult = 0);
 Read(F, B1); Read(F, B2);
 Todo24Assert('signature MZ ($4D,$5A) en tete du .exe',
  (B1 = $4D) And (B2 = $5A));
 Seek(F, 64);
 Read(F, B1); Read(F, B2); Read(F, B3); Read(F, B4);
 Todo24Assert('signature PE\0\0 a e_lfanew=64',
  (B1 = Ord('P')) And (B2 = Ord('E')) And (B3 = 0) And (B4 = 0));
 Close(F);
 {$I-} Erase(F); {$I+}
 {$I-} Assign(F, ReplaceExt(TmpFile, '.asm')); Erase(F); {$I+}

 { --- Mode OBJ : meme programme, verifie la signature COFF --- }
 SymInit; ClassSystemInit; DataInit; DataInit2; FrameInit; StmtInit;
 UserExternInit; InInterfaceSection := False;
 BuildMinimalProgram;
 ParseProgramOrLibraryFile(False, ReplaceExt(TmpFile, '.asm'));
 Todo24Assert('Program P24T (OBJ) consomme tous les tokens', PPAtEnd);
 AsmAssembleFile(ReplaceExt(TmpFile, '.asm'));
 WriteCOFFObj(ReplaceExt(TmpFile, '.obj'));

 {$I-} Assign(F, ReplaceExt(TmpFile, '.obj')); Reset(F); {$I+}
 Todo24Assert('WriteCOFFObj produit un fichier relisible', IOResult = 0);
 Read(F, B1); Read(F, B2);
 Todo24Assert('Machine=i386 ($014C, petit-boutiste) en tete du .obj',
  (B1 = $4C) And (B2 = $01));
 Close(F);
 {$I-} Erase(F); {$I+}
 {$I-} Assign(F, ReplaceExt(TmpFile, '.asm')); Erase(F); {$I+}

 Opts.OutFile := SavedOutFile;
 Opts.ObjOnly := SavedObjOnly;

 SymInit; ClassSystemInit; DataInit; DataInit2; FrameInit; StmtInit;
 UserExternInit; InInterfaceSection := False;
End;
{ Un assembleur 80386 maison (pas MASM/ML.EXE externe) relit le    }
{ texte .ASM deja produit par EmitOpen/EmitInstr/... (TODO 07) et    }
{ produit directement un fichier binaire reel : PE (.exe, mode        }
{ par defaut) ou COFF (.obj, -obj). Porte du meme esprit que            }
{ l assembleur de ML.PAS (projet frere, deja verifie fonctionnel        }
{ sur de vrais .exe) mais REECRIT ICI, plus etroit : uniquement le        }
{ repertoire d instructions/directives que CE compilateur emet          }
{ reellement (enumere par relecture de tous les EmitInstr du fichier),   }
{ pas un clone general de MASM. Une instruction ASM utilisateur            }
{ (bloc asm en ligne, TODO 21) hors de ce repertoire produit une            }
{ erreur fatale claire plutot que des octets faux.                          }
{ ------------------------------------------------------------ }

Const
 ASMSEC_TEXT  = 0;
 ASMSEC_DATA  = 1;
 ASMSEC_IDATA = 2;
 ASMSEC_COUNT = 3;

 MAX_ASM_BYTES   = {$IFDEF FPC}1048576{$ELSE}65536{$ENDIF};
 MAX_ASM_LABELS  = 4096;
 MAX_ASM_FIXUPS  = 16384;
 MAX_ASM_EXTERNS = 256;
 MAX_ASM_THUNKS  = 256;

 { Table d alias : nom "nu" (tel qu ecrit par les sites d appel du     }
 { generateur de code, ex. 'CALL ExitProcess') -> nom decore reel de   }
 { l import (tel que declare par EmitHeader, ex. '_ExitProcess@4').     }
 { Simplification deliberee (TODO 24) : plutot que de retoucher les       }
 { dizaines de sites d emission CALL/JMP existants pour leur faire        }
 { ecrire le nom decore, l assembleur resout lui-meme cet alias -          }
 { seul endroit du fichier qui a besoin de connaitre cette correspondance.}
 ASM_API_ALIAS_COUNT = 9;
 AsmApiAliasBare : Array[0..ASM_API_ALIAS_COUNT - 1] Of TString = (
  'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
  'GetProcessHeap', 'HeapAlloc', 'HeapFree', 'HeapReAlloc', 'CloseHandle');
 AsmApiAliasReal : Array[0..ASM_API_ALIAS_COUNT - 1] Of TString = (
  '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20', '_ReadFile@20',
  '_GetProcessHeap@0', '_HeapAlloc@12', '_HeapFree@12', '_HeapReAlloc@16',
  '_CloseHandle@4');

Type
 TAsmFixKind = (AFX_REL32, AFX_ABS32);

 TAsmLabel = Record
  Name    : TString;
  Sec     : Integer;   { ASMSEC_xxx }
  Ofs     : LongInt;   { position dans le tampon de cette section }
 End;

 TAsmFixup = Record
  Sec        : Integer;    { section CONTENANT le champ a corriger }
  Pos        : LongInt;    { position de ce champ (32 bits) dans cette section }
  Kind       : TAsmFixKind;
  TargetName : TString;    { nom du symbole (local, extern ou alias API) vise }
  Addend     : LongInt;    { deplacement supplementaire (Label+N) }
 End;

Var
 AsmBuf      : Array[ASMSEC_TEXT..ASMSEC_IDATA] Of Array[0..MAX_ASM_BYTES - 1] Of Byte;
 AsmLen      : Array[ASMSEC_TEXT..ASMSEC_IDATA] Of LongInt;
 AsmCurSec   : Integer;

 AsmLabels     : Array[0..MAX_ASM_LABELS - 1] Of TAsmLabel;
 AsmLabelCount : Integer;

 AsmFixups     : Array[0..MAX_ASM_FIXUPS - 1] Of TAsmFixup;
 AsmFixupCount : Integer;

 AsmExterns     : Array[0..MAX_ASM_EXTERNS - 1] Of TString;
 AsmExternCount : Integer;

 { Vignettes IAT (TODO 24) : un CALL/JMP vers un symbole EXTERN ne peut }
 { pas etre un rel32 direct (l adresse reelle de la DLL est inconnue     }
 { avant le chargement) - il saute plutot vers une petite vignette        }
 { locale ('JMP DWORD PTR [case IAT]', 6 octets, meme technique que        }
 { ML.PAS/tout compilateur Win32 reel) placee dans .text, UNE fois par      }
 { symbole extern reellement appele. AsmThunkOfs[I] = position (dans        }
 { AsmBuf[ASMSEC_TEXT]) de la vignette du I-eme extern d AsmExterns.          }
 AsmThunkOfs      : Array[0..MAX_ASM_EXTERNS - 1] Of LongInt;
 AsmThunkExists   : Array[0..MAX_ASM_EXTERNS - 1] Of Boolean;

{ ------------------------------------------------------------ }
{ AsmInit : reinitialiser tout l etat de l assembleur (TODO 24), }
{ avant l assemblage d un nouveau fichier .asm.                   }
{ ------------------------------------------------------------ }

Procedure AsmInit;
Var I: Integer;
Begin
 AsmLen[ASMSEC_TEXT]  := 0;
 AsmLen[ASMSEC_DATA]  := 0;
 AsmLen[ASMSEC_IDATA] := 0;
 AsmCurSec       := ASMSEC_TEXT;
 AsmLabelCount   := 0;
 AsmFixupCount   := 0;
 AsmExternCount  := 0;
 For I := 0 To MAX_ASM_EXTERNS - 1 Do AsmThunkExists[I] := False;
End;

{ ------------------------------------------------------------ }
{ AsmEmitByte/Word/DWord : ecrire des octets bruts dans la        }
{ section COURANTE (AsmCurSec), a la position AsmLen[AsmCurSec],  }
{ en little-endian (convention x86 native).                        }
{ ------------------------------------------------------------ }

Procedure AsmEmitByte(B: Integer);
Begin
 If AsmLen[AsmCurSec] >= MAX_ASM_BYTES Then
 Begin
  FatalError('assembleur : section pleine (MAX_ASM_BYTES=' +
   IntToStr_(MAX_ASM_BYTES) + ')');
  Exit;
 End;
 AsmBuf[AsmCurSec][AsmLen[AsmCurSec]] := B And $FF;
 Inc(AsmLen[AsmCurSec]);
End;

Procedure AsmEmitWord(W: Integer);
Begin
 AsmEmitByte(W And $FF);
 AsmEmitByte((W Shr 8) And $FF);
End;

Procedure AsmEmitDWord(D: LongInt);
Begin
 AsmEmitByte(D And $FF);
 AsmEmitByte((D Shr 8) And $FF);
 AsmEmitByte((D Shr 16) And $FF);
 AsmEmitByte((D Shr 24) And $FF);
End;

{ ------------------------------------------------------------ }
{ AsmAddFixup : enregistrer une correction differee (adresse pas  }
{ encore connue - label en avant, ou symbole extern) a l emplacement}
{ des 4 derniers octets ecrits dans SecOfFixup (deja reserves via   }
{ AsmEmitDWord(0) par l appelant). Resolue par AsmResolveFixups     }
{ une fois tout le fichier assemble (donc tous les labels connus).  }
{ ------------------------------------------------------------ }

Procedure AsmAddFixup(SecOfFixup: Integer; Kind: TAsmFixKind;
 Const TargetName: TString; Addend: LongInt);
Begin
 If AsmFixupCount >= MAX_ASM_FIXUPS Then
 Begin
  FatalError('assembleur : table des corrections pleine (MAX_ASM_FIXUPS=' +
   IntToStr_(MAX_ASM_FIXUPS) + ')');
  Exit;
 End;
 AsmFixups[AsmFixupCount].Sec        := SecOfFixup;
 AsmFixups[AsmFixupCount].Pos        := AsmLen[SecOfFixup] - 4;
 AsmFixups[AsmFixupCount].Kind       := Kind;
 AsmFixups[AsmFixupCount].TargetName := TargetName;
 AsmFixups[AsmFixupCount].Addend     := Addend;
 Inc(AsmFixupCount);
End;

{ ------------------------------------------------------------ }
{ AsmDefineLabel : enregistrer Name a la position COURANTE de la  }
{ section COURANTE (etiquette ASM, EmitLabel/DataTab[I].LblName). }
{ ------------------------------------------------------------ }

Procedure AsmDefineLabel(Const Name: TString);
Begin
 If AsmLabelCount >= MAX_ASM_LABELS Then
 Begin
  FatalError('assembleur : table des etiquettes pleine (MAX_ASM_LABELS=' +
   IntToStr_(MAX_ASM_LABELS) + ')');
  Exit;
 End;
 AsmLabels[AsmLabelCount].Name := StrUpperCase(Name);
 AsmLabels[AsmLabelCount].Sec  := AsmCurSec;
 AsmLabels[AsmLabelCount].Ofs  := AsmLen[AsmCurSec];
 Inc(AsmLabelCount);
End;

Function AsmFindLabel(Const Name: TString): Integer;
Var I: Integer; Up: TString;
Begin
 AsmFindLabel := -1;
 Up := StrUpperCase(Name);
 For I := 0 To AsmLabelCount - 1 Do
  If AsmLabels[I].Name = Up Then
  Begin
   AsmFindLabel := I;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ AsmExternIndex : trouver (ou enregistrer) un symbole EXTRN par  }
{ son nom REEL decore (deja resolu par AsmResolveApiAlias). Une    }
{ 'EXTRN Nom:NEAR' explicite (Win32 de base ou 'external' utilisateur,}
{ TODO 22) l enregistre d avance ; un appel jamais precede d une       }
{ ligne EXTRN correspondante est une erreur (symbole non declare).      }
{ ------------------------------------------------------------ }

Function AsmExternIndex(Const Name: TString): Integer;
Var I: Integer; Up: TString;
Begin
 Up := StrUpperCase(Name);
 For I := 0 To AsmExternCount - 1 Do
  If AsmExterns[I] = Up Then
  Begin
   AsmExternIndex := I;
   Exit;
  End;
 AsmExternIndex := -1;
End;

Procedure AsmDeclareExtern(Const Name: TString);
Begin
 If AsmExternIndex(Name) >= 0 Then Exit;   { deja declare }
 If AsmExternCount >= MAX_ASM_EXTERNS Then
 Begin
  FatalError('assembleur : table des imports externes pleine ' +
   '(MAX_ASM_EXTERNS=' + IntToStr_(MAX_ASM_EXTERNS) + ')');
  Exit;
 End;
 AsmExterns[AsmExternCount] := StrUpperCase(Name);
 Inc(AsmExternCount);
End;

{ ------------------------------------------------------------ }
{ AsmResolveApiAlias : traduire un nom "nu" (CALL ExitProcess) en }
{ son nom EXTRN decore reel (_ExitProcess@4) s il figure dans la  }
{ table d alias ci-dessus ; sinon renvoie Name inchange (etiquette}
{ locale ou symbole deja decore).                                  }
{ ------------------------------------------------------------ }

Function AsmResolveApiAlias(Const Name: TString): TString;
Var I: Integer; Up: TString;
Begin
 Up := StrUpperCase(Name);
 For I := 0 To ASM_API_ALIAS_COUNT - 1 Do
  If StrUpperCase(AsmApiAliasBare[I]) = Up Then
  Begin
   AsmResolveApiAlias := AsmApiAliasReal[I];
   Exit;
  End;
 AsmResolveApiAlias := Name;
End;

{ ------------------------------------------------------------ }
{ AsmExportNameFor : nom REEL EXPORTE par la DLL pour un symbole  }
{ decore (ex: '_ExitProcess@4' -> 'ExitProcess') - c est CE nom     }
{ (sans decoration stdcall) que le CHARGEUR Windows cherche dans     }
{ la table d export de kernel32.dll (Hint/Name, WritePEExe) : la      }
{ decoration _Nom@N n existe qu au niveau du symbole EXTRN/OBJ, elle   }
{ n a jamais ete un nom REELLEMENT exporte par la DLL. L oublier ici    }
{ (ecrire le nom decore dans la table d import) produit un .exe qui      }
{ semble valide mais que Windows refuse de charger                        }
{ (STATUS_ENTRYPOINT_NOT_FOUND, 0xC0000139) - bug trouve et corrige         }
{ en testant reellement l executable produit (TODO 24).                       }
{ Repli (aucun alias trouve, import 'external' utilisateur, TODO 22) :         }
{ le nom decore est utilise tel quel - un utilisateur import de DLL tierce      }
{ doit alors fournir NAME 'NomReel' pour un nom different (deja gere par         }
{ ParseProcOrFuncDecl, ExportName), mais ce nom-la n atteint pas encore           }
{ l assembleur (seul le nom mangled traverse l EXTRN texte, TODO 24 -              }
{ limitation documentee, identique a celle du choix "tout KERNEL32.DLL").          }
{ ------------------------------------------------------------ }

Function AsmExportNameFor(Const DecoratedName: TString): TString;
Var I: Integer; Up: TString;
Begin
 Up := StrUpperCase(DecoratedName);
 For I := 0 To ASM_API_ALIAS_COUNT - 1 Do
  If StrUpperCase(AsmApiAliasReal[I]) = Up Then
  Begin
   AsmExportNameFor := AsmApiAliasBare[I];
   Exit;
  End;
 AsmExportNameFor := DecoratedName;
End;

{ ------------------------------------------------------------ }
{ AsmTrimSpaces / AsmIsNumberLiteral / AsmParseNumber : petits    }
{ utilitaires texte reutilises par l assembleur (AsmTrimSpaces     }
{ existe deja depuis le TODO 21 - reutilisee telle quelle ici).     }
{ AsmParseNumber gere le decimal (signe optionnel) et l hexadecimal }
{ style MASM (suffixe 'h', toujours precede d un chiffre par         }
{ construction - EmitInstr n emet jamais 'FFh' mais '0FFh').          }
{ ------------------------------------------------------------ }

Function AsmIsNumberLiteral(Const S: TString): Boolean;
Var T: TString;
Begin
 T := S;
 If (Length(T) > 0) And (T[1] = '-') Then T := Copy(T, 2, Length(T) - 1);
 AsmIsNumberLiteral := (Length(T) > 0) And (T[1] >= '0') And (T[1] <= '9');
End;

{ Desactive localement la verification de depassement/plage (portee     }
{ limitee a cette seule fonction, reactivee juste apres) : un litteral    }
{ hexadecimal 32 bits comme 0FFFFFFFFh (4294967295, ex. _DPRT_STRLEN,      }
{ TODO 12/20) depasse volontairement l intervalle signe d un LongInt        }
{ pendant l accumulation chiffre par chiffre POSITIVE (avant l eventuelle    }
{ negation) - le bouclage (wraparound) est ici le comportement VOULU (on      }
{ veut juste le motif de bits sur 32 bits), pas une erreur, mais les          }
{ directives de depassement/plage (actives par defaut dans les options         }
{ de projet standard de l EDI Free Pascal, contrairement aux compilations       }
{ en ligne de commande utilisees pendant le developpement) transformaient        }
{ ce bouclage intentionnel en "Runtime error 215" a l execution.                  }
{$Q-}{$R-}
Function AsmParseNumber(Const S: TString): LongInt;
Var
 T     : TString;
 Neg   : Boolean;
 IsHex : Boolean;
 V     : LongInt;
 I     : Integer;
 C     : Char;
Begin
 T := S;
 Neg := False;
 If (Length(T) > 0) And (T[1] = '-') Then
 Begin
  Neg := True;
  T := Copy(T, 2, Length(T) - 1);
 End;

 IsHex := (Length(T) > 0) And
  ((T[Length(T)] = 'h') Or (T[Length(T)] = 'H'));
 If IsHex Then T := Copy(T, 1, Length(T) - 1);

 V := 0;
 For I := 1 To Length(T) Do
 Begin
  C := T[I];
  If IsHex Then
  Begin
   If (C >= '0') And (C <= '9') Then V := V * 16 + (Ord(C) - Ord('0'))
   Else If (C >= 'A') And (C <= 'F') Then V := V * 16 + (Ord(C) - Ord('A') + 10)
   Else If (C >= 'a') And (C <= 'f') Then V := V * 16 + (Ord(C) - Ord('a') + 10);
  End
  Else
  Begin
   If (C >= '0') And (C <= '9') Then V := V * 10 + (Ord(C) - Ord('0'));
  End;
 End;

 If Neg Then V := -V;
 AsmParseNumber := V;
End;
{$Q+}{$R+}

{ ------------------------------------------------------------ }
{ Registres : numerotation ModRM/SIB standard 80386.             }
{ 32 bits : EAX=0 ECX=1 EDX=2 EBX=3 ESP=4 EBP=5 ESI=6 EDI=7.      }
{ 8 bits  : AL=0  CL=1  DL=2  BL=3  AH=4  CH=5  DH=6  BH=7.       }
{ ------------------------------------------------------------ }

Function AsmReg32(Const Name: TString): Integer;
Var Up: TString;
Begin
 Up := StrUpperCase(Name);
 If Up = 'EAX' Then AsmReg32 := 0
 Else If Up = 'ECX' Then AsmReg32 := 1
 Else If Up = 'EDX' Then AsmReg32 := 2
 Else If Up = 'EBX' Then AsmReg32 := 3
 Else If Up = 'ESP' Then AsmReg32 := 4
 Else If Up = 'EBP' Then AsmReg32 := 5
 Else If Up = 'ESI' Then AsmReg32 := 6
 Else If Up = 'EDI' Then AsmReg32 := 7
 Else AsmReg32 := -1;
End;

Function AsmReg8(Const Name: TString): Integer;
Var Up: TString;
Begin
 Up := StrUpperCase(Name);
 If Up = 'AL' Then AsmReg8 := 0
 Else If Up = 'CL' Then AsmReg8 := 1
 Else If Up = 'DL' Then AsmReg8 := 2
 Else If Up = 'BL' Then AsmReg8 := 3
 Else If Up = 'AH' Then AsmReg8 := 4
 Else If Up = 'CH' Then AsmReg8 := 5
 Else If Up = 'DH' Then AsmReg8 := 6
 Else If Up = 'BH' Then AsmReg8 := 7
 Else AsmReg8 := -1;
End;

{ ------------------------------------------------------------ }
{ TAsmOperand : operande d instruction decode (registre,         }
{ immediat, reference memoire [...], ou "immediat a corriger"     }
{ - OFFSET Nom, ou une cible CALL/JMP/Jcc nommee).                 }
{ ------------------------------------------------------------ }

Type
 TAsmOpKind = (AOK_REG, AOK_IMM, AOK_MEM, AOK_LABELIMM);

 TAsmOperand = Record
  Kind      : TAsmOpKind;
  RegNum    : Integer;
  RegSize   : Integer;
  ImmVal    : LongInt;
  HasBase   : Boolean;
  BaseReg   : Integer;
  HasIndex  : Boolean;
  IndexReg  : Integer;
  Scale     : Integer;
  Disp      : LongInt;
  DispLabel : TString;
  MemSize   : Integer;
  LabelName : TString;
 End;

{ ------------------------------------------------------------ }
{ AsmParseMemInner : contenu ENTRE crochets d une reference        }
{ memoire ('EBP-4', 'EAX', 'ESI+ECX*4', 'EDI+EDX*4+4',              }
{ 'DPRT_EXCSTACK_EBP+EAX*4', 'DPRT_HSTDOUT'...). Decoupe en          }
{ termes signes separes par '+'/'-' au niveau superieur (aucun        }
{ identificateur/etiquette de ce compilateur ne contient l un de       }
{ ces deux caracteres) : chaque terme est soit un registre (base,       }
{ premiere occurrence), soit 'Registre*Echelle' (index), soit un         }
{ entier (deplacement, accumule avec son signe), soit un nom              }
{ (etiquette, base ABSENTE - jamais combinee avec une base registre        }
{ dans le code emis par ce compilateur, seulement avec un index).          }
{ ------------------------------------------------------------ }

Procedure AsmParseMemInner(Const Inner: TString; Var HasBase: Boolean;
 Var BaseReg: Integer; Var HasIndex: Boolean; Var IndexReg, Scale: Integer;
 Var Disp: LongInt; Var DispLabel: TString);
Var
 I, TermStart, StarPos, RN : Integer;
 Sign : Integer;
 Term, RegPart, ScalePart : TString;
Begin
 HasBase := False; BaseReg := 0;
 HasIndex := False; IndexReg := 0; Scale := 1;
 Disp := 0; DispLabel := '';

 Sign := 1;
 TermStart := 1;
 I := 1;
 While I <= Length(Inner) + 1 Do
 Begin
  If (I > Length(Inner)) Or (Inner[I] = '+') Or (Inner[I] = '-') Then
  Begin
   Term := Copy(Inner, TermStart, I - TermStart);
   If Length(Term) > 0 Then
   Begin
    StarPos := Pos('*', Term);
    If StarPos > 0 Then
    Begin
     RegPart   := Copy(Term, 1, StarPos - 1);
     ScalePart := Copy(Term, StarPos + 1, Length(Term) - StarPos);
     HasIndex  := True;
     IndexReg  := AsmReg32(RegPart);
     Scale     := AsmParseNumber(ScalePart);
    End
    Else If AsmIsNumberLiteral(Term) Then
     Disp := Disp + Sign * AsmParseNumber(Term)
    Else
    Begin
     RN := AsmReg32(Term);
     If RN >= 0 Then
     Begin
      HasBase := True;
      BaseReg := RN;
     End
     Else
      DispLabel := Term;
    End;
   End;
   If I <= Length(Inner) Then
   Begin
    If Inner[I] = '+' Then Sign := 1 Else Sign := -1;
   End;
   TermStart := I + 1;
  End;
  Inc(I);
 End;
End;

{ ------------------------------------------------------------ }
{ AsmParseOperand : decoder un operande textuel complet (avec      }
{ eventuel prefixe de taille BYTE/WORD/DWORD PTR).                  }
{ ------------------------------------------------------------ }

Procedure AsmParseOperand(Const RawOp: TString; Var Op: TAsmOperand);
Var
 S   : TString;
 Up  : TString;
 Inner : TString;
 SizePfx : Integer;
Begin
 S := AsmTrimSpaces(RawOp);
 Op.Kind := AOK_IMM; Op.ImmVal := 0; Op.MemSize := 0;
 Op.HasBase := False; Op.HasIndex := False; Op.Scale := 1; Op.Disp := 0;
 Op.DispLabel := ''; Op.LabelName := ''; Op.RegNum := 0; Op.RegSize := 4;
 Op.BaseReg := 0; Op.IndexReg := 0;

 SizePfx := 0;
 Up := StrUpperCase(S);
 If Pos('DWORD PTR ', Up) = 1 Then
 Begin SizePfx := 4; S := AsmTrimSpaces(Copy(S, 11, Length(S) - 10)); End
 Else If Pos('WORD PTR ', Up) = 1 Then
 Begin SizePfx := 2; S := AsmTrimSpaces(Copy(S, 10, Length(S) - 9)); End
 Else If Pos('BYTE PTR ', Up) = 1 Then
 Begin SizePfx := 1; S := AsmTrimSpaces(Copy(S, 10, Length(S) - 9)); End;

 If (Length(S) > 0) And (S[1] = '[') Then
 Begin
  Inner := Copy(S, 2, Length(S) - 2);
  Op.Kind := AOK_MEM;
  Op.MemSize := SizePfx;
  AsmParseMemInner(Inner, Op.HasBase, Op.BaseReg, Op.HasIndex, Op.IndexReg,
   Op.Scale, Op.Disp, Op.DispLabel);
  Exit;
 End;

 Up := StrUpperCase(S);
 If Pos('OFFSET ', Up) = 1 Then
 Begin
  Op.Kind := AOK_LABELIMM;
  Op.LabelName := AsmTrimSpaces(Copy(S, 8, Length(S) - 7));
  Exit;
 End;

 If AsmIsNumberLiteral(S) Then
 Begin
  Op.Kind := AOK_IMM;
  Op.ImmVal := AsmParseNumber(S);
  Exit;
 End;

 If AsmReg32(S) >= 0 Then
 Begin
  Op.Kind := AOK_REG;
  Op.RegNum := AsmReg32(S);
  Op.RegSize := 4;
  Exit;
 End;

 If AsmReg8(S) >= 0 Then
 Begin
  Op.Kind := AOK_REG;
  Op.RegNum := AsmReg8(S);
  Op.RegSize := 1;
  Exit;
 End;

 { Filet de securite (TODO 24) : un operande vide (ou reduit a un        }
 { simple mot-cle de taille sans rien derriere, ex. 'DWORD PTR' seul       }
 { sans '[...]') signale presque toujours un BUG EN AMONT dans le           }
 { generateur de code (ex: GenVarRef/GenVarBracket qui renvoie '' pour       }
 { un symbole mal resolu - trouve en testant reellement lextest3.pas,          }
 { TODO 24 : une variable nommee comme un builtin, 'Write', produisait          }
 { 'MOV DWORD PTR ,EAX'). Sans ce garde-fou, le repli silencieux vers            }
 { AOK_LABELIMM avec un nom vide finissait par ecrire a l adresse ABSOLUE          }
 { 0 (Mem.DispLabel vide + Mem.Disp=0 par defaut dans AsmEmitRM) - une              }
 { corruption memoire SILENCIEUSE (plantage a l execution, bien plus dur             }
 { a diagnostiquer que cette erreur claire, immediate, au moment de                   }
 { l assemblage).                                                                       }
 If (Length(S) = 0) Or (Up = 'DWORD') Or (Up = 'WORD') Or (Up = 'BYTE') Or
    (Up = 'PTR') Then
 Begin
  FatalError('assembleur : operande vide ou malforme (''' + RawOp +
   ''') - bug probable en amont dans le generateur de code');
  Exit;
 End;

 Op.Kind := AOK_LABELIMM;
 Op.LabelName := S;
End;

{ ------------------------------------------------------------ }
{ AsmSplitOperands : separer jusqu a 2 operandes par une virgule  }
{ de PROFONDEUR 0 (hors crochets) - au plus 2 operandes dans tout  }
{ le repertoire emis par ce compilateur.                            }
{ ------------------------------------------------------------ }

Procedure AsmSplitOperands(Const S: TString; Var Op1, Op2: TString;
 Var OpCount: Integer);
Var
 I, Depth : Integer;
 C   : Char;
 Cur : TString;
Begin
 Op1 := ''; Op2 := ''; OpCount := 0;
 Cur := ''; Depth := 0;
 For I := 1 To Length(S) Do
 Begin
  C := S[I];
  If C = '[' Then Inc(Depth);
  If C = ']' Then Dec(Depth);
  If (C = ',') And (Depth = 0) Then
  Begin
   If OpCount = 0 Then Op1 := AsmTrimSpaces(Cur) Else Op2 := AsmTrimSpaces(Cur);
   Inc(OpCount);
   Cur := '';
  End
  Else
   Cur := Cur + C;
 End;
 If Length(AsmTrimSpaces(Cur)) > 0 Then
 Begin
  If OpCount = 0 Then Op1 := AsmTrimSpaces(Cur) Else Op2 := AsmTrimSpaces(Cur);
  Inc(OpCount);
 End;
End;

{ ------------------------------------------------------------ }
{ AsmEmitRM : emettre ModRM(+SIB)(+disp32) pour RegField (champ   }
{ Reg du ModRM - un vrai registre, ou l extension d opcode /digit  }
{ des groupes ALU/unaires) et l operande Mem (registre ou memoire).}
{ Simplification documentee (TODO 24) : toujours disp32 des qu une }
{ base registre existe (jamais Mod=00, qui a un sens special pour   }
{ EBP/SIB-base=101 - ce choix uniforme evite ce piege d encodage     }
{ sans avoir a traiter EBP a part) - cout : quelques octets de plus   }
{ par acces memoire, aucun impact sur la correction.                   }
{ ------------------------------------------------------------ }

Procedure AsmEmitRM(RegField: Integer; Const Mem: TAsmOperand);
Var ModRM, SIB, ScaleBits: Integer;
Begin
 If Mem.Kind = AOK_REG Then
 Begin
  ModRM := ($C0) Or (RegField Shl 3) Or Mem.RegNum;
  AsmEmitByte(ModRM);
  Exit;
 End;

 If Mem.HasIndex Or (Mem.HasBase And (Mem.BaseReg = 4)) Then
 Begin
  Case Mem.Scale Of
   1: ScaleBits := 0;
   2: ScaleBits := 1;
   4: ScaleBits := 2;
   8: ScaleBits := 3;
   Else ScaleBits := 2;
  End;

  If Mem.HasBase Then
  Begin
   ModRM := ($80) Or (RegField Shl 3) Or 4;
   AsmEmitByte(ModRM);
   If Mem.HasIndex Then
    SIB := (ScaleBits Shl 6) Or (Mem.IndexReg Shl 3) Or Mem.BaseReg
   Else
    SIB := (0 Shl 6) Or (4 Shl 3) Or Mem.BaseReg;
   AsmEmitByte(SIB);
   AsmEmitDWord(Mem.Disp);
  End
  Else
  Begin
   ModRM := (0 Shl 6) Or (RegField Shl 3) Or 4;
   AsmEmitByte(ModRM);
   SIB := (ScaleBits Shl 6) Or (Mem.IndexReg Shl 3) Or 5;
   AsmEmitByte(SIB);
   If Length(Mem.DispLabel) > 0 Then
   Begin
    AsmEmitDWord(0);
    AsmAddFixup(AsmCurSec, AFX_ABS32, Mem.DispLabel, Mem.Disp);
   End
   Else
    AsmEmitDWord(Mem.Disp);
  End;
  Exit;
 End;

 If Mem.HasBase Then
 Begin
  ModRM := ($80) Or (RegField Shl 3) Or Mem.BaseReg;
  AsmEmitByte(ModRM);
  AsmEmitDWord(Mem.Disp);
  Exit;
 End;

 ModRM := (0 Shl 6) Or (RegField Shl 3) Or 5;
 AsmEmitByte(ModRM);
 If Length(Mem.DispLabel) > 0 Then
 Begin
  AsmEmitDWord(0);
  AsmAddFixup(AsmCurSec, AFX_ABS32, Mem.DispLabel, Mem.Disp);
 End
 Else
  AsmEmitDWord(Mem.Disp);
End;

{ ------------------------------------------------------------ }
{ Encodeurs d instructions (TODO 24) - un par famille d opcode,  }
{ couvrant exactement le repertoire enumere par relecture de       }
{ tous les EmitInstr de ce fichier (aucune ambition MASM generale).}
{ ------------------------------------------------------------ }

Procedure AsmEncodeAlu(GroupDigit: Integer; Const Op1Text, Op2Text: TString);
Var
 Op1, Op2 : TAsmOperand;
 Size : Integer;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);

 If Op1.Kind = AOK_REG Then Size := Op1.RegSize
 Else If (Op1.Kind = AOK_MEM) And (Op1.MemSize > 0) Then Size := Op1.MemSize
 Else Size := 4;

 If Op2.Kind = AOK_IMM Then
 Begin
  If Size = 1 Then
  Begin
   AsmEmitByte($80);
   AsmEmitRM(GroupDigit, Op1);
   AsmEmitByte(Op2.ImmVal And $FF);
  End
  Else
  Begin
   AsmEmitByte($81);
   AsmEmitRM(GroupDigit, Op1);
   AsmEmitDWord(Op2.ImmVal);
  End;
  Exit;
 End;

 If Op1.Kind = AOK_REG Then
 Begin
  If Size = 1 Then AsmEmitByte($02 + (GroupDigit Shl 3))
  Else AsmEmitByte($03 + (GroupDigit Shl 3));
  AsmEmitRM(Op1.RegNum, Op2);
 End
 Else
 Begin
  If Size = 1 Then AsmEmitByte($00 + (GroupDigit Shl 3))
  Else AsmEmitByte($01 + (GroupDigit Shl 3));
  AsmEmitRM(Op2.RegNum, Op1);
 End;
End;

Procedure AsmEncodeMov(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand; Size: Integer;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);

 If Op1.Kind = AOK_REG Then Size := Op1.RegSize
 Else If (Op1.Kind = AOK_MEM) And (Op1.MemSize > 0) Then Size := Op1.MemSize
 Else Size := 4;

 If (Op2.Kind = AOK_IMM) Or (Op2.Kind = AOK_LABELIMM) Then
 Begin
  If Size = 1 Then
  Begin
   AsmEmitByte($C6);
   AsmEmitRM(0, Op1);
   If Op2.Kind = AOK_IMM Then AsmEmitByte(Op2.ImmVal And $FF)
   Else Begin AsmEmitByte(0); AsmAddFixup(AsmCurSec, AFX_ABS32, Op2.LabelName, 0); End;
  End
  Else
  Begin
   AsmEmitByte($C7);
   AsmEmitRM(0, Op1);
   If Op2.Kind = AOK_IMM Then AsmEmitDWord(Op2.ImmVal)
   Else Begin AsmEmitDWord(0); AsmAddFixup(AsmCurSec, AFX_ABS32, Op2.LabelName, 0); End;
  End;
  Exit;
 End;

 If Op1.Kind = AOK_REG Then
 Begin
  If Size = 1 Then AsmEmitByte($8A) Else AsmEmitByte($8B);
  AsmEmitRM(Op1.RegNum, Op2);
 End
 Else
 Begin
  If Size = 1 Then AsmEmitByte($88) Else AsmEmitByte($89);
  AsmEmitRM(Op2.RegNum, Op1);
 End;
End;

Procedure AsmEncodeMovzx(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);
 AsmEmitByte($0F);
 AsmEmitByte($B6);
 AsmEmitRM(Op1.RegNum, Op2);
End;

Procedure AsmEncodeLea(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);
 AsmEmitByte($8D);
 AsmEmitRM(Op1.RegNum, Op2);
End;

Procedure AsmEncodePush(Const Op1Text: TString);
Var Op1: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 If Op1.Kind = AOK_REG Then
  AsmEmitByte($50 + Op1.RegNum)
 Else If Op1.Kind = AOK_IMM Then
 Begin
  AsmEmitByte($68);
  AsmEmitDWord(Op1.ImmVal);
 End
 Else If Op1.Kind = AOK_LABELIMM Then
 Begin
  AsmEmitByte($68);
  AsmEmitDWord(0);
  AsmAddFixup(AsmCurSec, AFX_ABS32, Op1.LabelName, 0);
 End
 Else
 Begin
  AsmEmitByte($FF);
  AsmEmitRM(6, Op1);
 End;
End;

Procedure AsmEncodePop(Const Op1Text: TString);
Var Op1: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 If Op1.Kind = AOK_REG Then
  AsmEmitByte($58 + Op1.RegNum)
 Else
 Begin
  AsmEmitByte($8F);
  AsmEmitRM(0, Op1);
 End;
End;

Procedure AsmEncodeIncDec(IsInc: Boolean; Const Op1Text: TString);
Var Op1: TAsmOperand; Size, Digit: Integer;
Begin
 AsmParseOperand(Op1Text, Op1);
 If Op1.Kind = AOK_REG Then Size := Op1.RegSize
 Else If Op1.MemSize > 0 Then Size := Op1.MemSize Else Size := 4;

 If IsInc Then Digit := 0 Else Digit := 1;

 If (Op1.Kind = AOK_REG) And (Size = 4) Then
 Begin
  If IsInc Then AsmEmitByte($40 + Op1.RegNum) Else AsmEmitByte($48 + Op1.RegNum);
  Exit;
 End;

 If Size = 1 Then AsmEmitByte($FE) Else AsmEmitByte($FF);
 AsmEmitRM(Digit, Op1);
End;

Procedure AsmEncodeNegNot(IsNeg: Boolean; Const Op1Text: TString);
Var Op1: TAsmOperand; Digit: Integer;
Begin
 AsmParseOperand(Op1Text, Op1);
 If IsNeg Then Digit := 3 Else Digit := 2;
 AsmEmitByte($F7);
 AsmEmitRM(Digit, Op1);
End;

Procedure AsmEncodeImul(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);

 { IMUL r32,imm32 (ex. IMUL EAX,4) ou la forme a 3 operandes reg,reg,imm}
 { dont AsmSplitOperands ne garde que le 1er et le dernier operande     }
 { (IMUL EAX,EAX,10 -> Op1=EAX,Op2=10) - les deux emissions de ce        }
 { compilateur (ParsePostfix/EmitInstr, TODO 19/20) ont toujours          }
 { r/m32 = Op1 lui-meme (destination = multiplicande) : encode via        }
 { 0x69 /r id (IMUL r32,r/m32,imm32) avec r/m32 = Op1.                      }
 If Op2.Kind = AOK_IMM Then
 Begin
  AsmEmitByte($69);
  AsmEmitRM(Op1.RegNum, Op1);
  AsmEmitDWord(Op2.ImmVal);
  Exit;
 End;

 AsmEmitByte($0F);
 AsmEmitByte($AF);
 AsmEmitRM(Op1.RegNum, Op2);
End;

Procedure AsmEncodeDivIdiv(IsIdiv: Boolean; Const Op1Text: TString);
Var Op1: TAsmOperand; Digit: Integer;
Begin
 AsmParseOperand(Op1Text, Op1);
 If IsIdiv Then Digit := 7 Else Digit := 6;
 AsmEmitByte($F7);
 AsmEmitRM(Digit, Op1);
End;

Procedure AsmEncodeTest(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);
 If Op2.Kind = AOK_IMM Then
 Begin
  AsmEmitByte($F7);
  AsmEmitRM(0, Op1);
  AsmEmitDWord(Op2.ImmVal);
  Exit;
 End;
 AsmEmitByte($85);
 AsmEmitRM(Op2.RegNum, Op1);
End;

Procedure AsmEncodeBt(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);
 AsmEmitByte($0F);
 AsmEmitByte($A3);
 AsmEmitRM(Op2.RegNum, Op1);
End;

Procedure AsmEncodeShift(Digit: Integer; Const Op1Text, Op2Text: TString);
Var Op1, Op2: TAsmOperand;
Begin
 AsmParseOperand(Op1Text, Op1);
 AsmParseOperand(Op2Text, Op2);
 AsmEmitByte($C1);
 AsmEmitRM(Digit, Op1);
 AsmEmitByte(Op2.ImmVal And $FF);
End;

Procedure AsmEncodeCall(Const Op1Text: TString);
Var Op1: TAsmOperand; ResolvedName: TString;
Begin
 AsmParseOperand(Op1Text, Op1);
 If (Op1.Kind = AOK_MEM) Or (Op1.Kind = AOK_REG) Then
 Begin
  AsmEmitByte($FF);
  AsmEmitRM(2, Op1);
  Exit;
 End;
 ResolvedName := AsmResolveApiAlias(Op1.LabelName);
 AsmEmitByte($E8);
 AsmEmitDWord(0);
 AsmAddFixup(AsmCurSec, AFX_REL32, ResolvedName, 0);
End;

Procedure AsmEncodeJmp(Const Op1Text: TString);
Var Op1: TAsmOperand; ResolvedName: TString;
Begin
 AsmParseOperand(Op1Text, Op1);
 If (Op1.Kind = AOK_MEM) Or (Op1.Kind = AOK_REG) Then
 Begin
  AsmEmitByte($FF);
  AsmEmitRM(4, Op1);
  Exit;
 End;
 ResolvedName := AsmResolveApiAlias(Op1.LabelName);
 AsmEmitByte($E9);
 AsmEmitDWord(0);
 AsmAddFixup(AsmCurSec, AFX_REL32, ResolvedName, 0);
End;

Procedure AsmEncodeJcc(Const Mnemonic, Op1Text: TString);
Var Op1: TAsmOperand; Cond: Integer; Up: TString;
Begin
 AsmParseOperand(Op1Text, Op1);
 Up := StrUpperCase(Mnemonic);
 If (Up = 'JE') Or (Up = 'JZ') Then Cond := $84
 Else If (Up = 'JNE') Or (Up = 'JNZ') Then Cond := $85
 Else If Up = 'JG' Then Cond := $8F
 Else If Up = 'JGE' Then Cond := $8D
 Else If Up = 'JL' Then Cond := $8C
 Else If Up = 'JLE' Then Cond := $8E
 Else If Up = 'JC' Then Cond := $82
 Else Cond := $85;

 AsmEmitByte($0F);
 AsmEmitByte(Cond);
 AsmEmitDWord(0);
 AsmAddFixup(AsmCurSec, AFX_REL32, Op1.LabelName, 0);
End;

Procedure AsmEncodeRepOp(Const FullLine: TString);
Var Up: TString;
Begin
 Up := StrUpperCase(FullLine);
 If Up = 'REP MOVSB' Then Begin AsmEmitByte($F3); AsmEmitByte($A4); End
 Else If Up = 'REP MOVSD' Then Begin AsmEmitByte($F3); AsmEmitByte($A5); End
 Else If Up = 'REP STOSB' Then Begin AsmEmitByte($F3); AsmEmitByte($AA); End
 Else If Up = 'REPNE SCASB' Then Begin AsmEmitByte($F2); AsmEmitByte($AE); End
 Else FatalError('assembleur : forme REP non geree: ' + FullLine);
End;

{ ------------------------------------------------------------ }
{ AsmAssembleInstrLine : dispatcher mnemonique -> encodeur.       }
{ ------------------------------------------------------------ }

Procedure AsmAssembleInstrLine(Const RawLine: TString);
Var
 Line, Mnemonic, Rest, Op1, Op2, Up : TString;
 I, OpCount : Integer;
Begin
 Line := AsmTrimSpaces(RawLine);
 If Length(Line) = 0 Then Exit;

 Up := StrUpperCase(Line);
 If (Pos('REP MOVSB', Up) = 1) Or (Pos('REP MOVSD', Up) = 1) Or
    (Pos('REP STOSB', Up) = 1) Or (Pos('REPNE SCASB', Up) = 1) Then
 Begin
  AsmEncodeRepOp(Line);
  Exit;
 End;

 I := 1;
 While (I <= Length(Line)) And (Line[I] <> ' ') Do Inc(I);
 Mnemonic := Copy(Line, 1, I - 1);
 Rest := AsmTrimSpaces(Copy(Line, I, Length(Line) - I + 1));
 AsmSplitOperands(Rest, Op1, Op2, OpCount);

 Up := StrUpperCase(Mnemonic);

 If Up = 'MOV' Then Begin AsmEncodeMov(Op1, Op2); Exit; End;
 If Up = 'MOVZX' Then Begin AsmEncodeMovzx(Op1, Op2); Exit; End;
 If Up = 'LEA' Then Begin AsmEncodeLea(Op1, Op2); Exit; End;
 If Up = 'ADD' Then Begin AsmEncodeAlu(0, Op1, Op2); Exit; End;
 If Up = 'OR' Then Begin AsmEncodeAlu(1, Op1, Op2); Exit; End;
 If Up = 'AND' Then Begin AsmEncodeAlu(4, Op1, Op2); Exit; End;
 If Up = 'SUB' Then Begin AsmEncodeAlu(5, Op1, Op2); Exit; End;
 If Up = 'XOR' Then Begin AsmEncodeAlu(6, Op1, Op2); Exit; End;
 If Up = 'CMP' Then Begin AsmEncodeAlu(7, Op1, Op2); Exit; End;
 If Up = 'PUSH' Then Begin AsmEncodePush(Op1); Exit; End;
 If Up = 'POP' Then Begin AsmEncodePop(Op1); Exit; End;
 If Up = 'INC' Then Begin AsmEncodeIncDec(True, Op1); Exit; End;
 If Up = 'DEC' Then Begin AsmEncodeIncDec(False, Op1); Exit; End;
 If Up = 'NEG' Then Begin AsmEncodeNegNot(True, Op1); Exit; End;
 If Up = 'NOT' Then Begin AsmEncodeNegNot(False, Op1); Exit; End;
 If Up = 'IMUL' Then Begin AsmEncodeImul(Op1, Op2); Exit; End;
 If Up = 'DIV' Then Begin AsmEncodeDivIdiv(False, Op1); Exit; End;
 If Up = 'IDIV' Then Begin AsmEncodeDivIdiv(True, Op1); Exit; End;
 If Up = 'TEST' Then Begin AsmEncodeTest(Op1, Op2); Exit; End;
 If Up = 'BT' Then Begin AsmEncodeBt(Op1, Op2); Exit; End;
 If Up = 'SHL' Then Begin AsmEncodeShift(4, Op1, Op2); Exit; End;
 If Up = 'SHR' Then Begin AsmEncodeShift(5, Op1, Op2); Exit; End;
 If Up = 'CALL' Then Begin AsmEncodeCall(Op1); Exit; End;
 If Up = 'JMP' Then Begin AsmEncodeJmp(Op1); Exit; End;
 If (Up = 'JE') Or (Up = 'JZ') Or (Up = 'JNE') Or (Up = 'JNZ') Or
    (Up = 'JG') Or (Up = 'JGE') Or (Up = 'JL') Or (Up = 'JLE') Or
    (Up = 'JC') Then
 Begin AsmEncodeJcc(Up, Op1); Exit; End;
 If Up = 'CDQ' Then Begin AsmEmitByte($99); Exit; End;
 If Up = 'CLD' Then Begin AsmEmitByte($FC); Exit; End;
 If Up = 'RET' Then Begin AsmEmitByte($C3); Exit; End;

 FatalError('assembleur : mnemonique non geree: ' + Mnemonic);
End;

{ ------------------------------------------------------------ }
{ AsmEmitDataItem / AsmAssembleDataLine : declarations DB/DD du   }
{ segment .DATA (litteraux 'texte', entiers, N DUP(valeur)).       }
{ ------------------------------------------------------------ }

Procedure AsmEmitDataItem(Const ItemRaw: TString; ByteWidth: Integer);
Var
 Item, NStr, ValStr : TString;
 I, DupPos : Integer;
 N, V : LongInt;
Begin
 Item := AsmTrimSpaces(ItemRaw);
 If Length(Item) = 0 Then Exit;

 If Item[1] = '''' Then
 Begin
  For I := 2 To Length(Item) - 1 Do AsmEmitByte(Ord(Item[I]));
  Exit;
 End;

 DupPos := Pos('DUP', StrUpperCase(Item));
 If DupPos > 0 Then
 Begin
  NStr := AsmTrimSpaces(Copy(Item, 1, DupPos - 1));
  N := AsmParseNumber(NStr);
  ValStr := Copy(Item, DupPos + 4, Length(Item) - DupPos - 4);
  If (Length(ValStr) > 0) And (ValStr[Length(ValStr)] = ')') Then
   ValStr := Copy(ValStr, 1, Length(ValStr) - 1);
  V := AsmParseNumber(AsmTrimSpaces(ValStr));
  For I := 1 To N Do
   If ByteWidth = 1 Then AsmEmitByte(V) Else AsmEmitDWord(V);
  Exit;
 End;

 { Filet de securite (TODO 25) : un item DD/DB non numerique et non     }
 { 'texte'/DUP est une REFERENCE A UNE ETIQUETTE (ex: 'DD _DPF_TDOG_SPEAK'}
 { dans une table VMT, EmitClassVMTs) - AsmParseNumber, elle, renvoie      }
 { silencieusement 0 pour tout texte non numerique, ce qui aurait produit  }
 { un pointeur NUL sans le moindre avertissement (bug trouve en concevant   }
 { EmitClassVMTs : une table VMT est justement une LISTE d etiquettes,       }
 { jamais des nombres). Seul DD (4 octets) peut porter une adresse ;         }
 { DB (1 octet) ne le peut pas - une reference d etiquette y est une           }
 { erreur reelle, signalee clairement plutot que tronquee en silence.          }
 If Not AsmIsNumberLiteral(Item) Then
 Begin
  If ByteWidth <> 4 Then
  Begin
   FatalError('assembleur : reference d etiquette (''' + Item +
    ''') invalide dans une declaration DB (1 octet, adresse impossible)');
   Exit;
  End;
  AsmEmitDWord(0);
  AsmAddFixup(AsmCurSec, AFX_ABS32, Item, 0);
  Exit;
 End;

 V := AsmParseNumber(Item);
 If ByteWidth = 1 Then AsmEmitByte(V) Else AsmEmitDWord(V);
End;

Procedure AsmAssembleDataLine(Const RawLine: TString);
Var
 Line, LabelName, Rest, Up : TString;
 I, J, ByteWidth : Integer;
 InQuote : Boolean;
 Cur : TString;
 C : Char;
Begin
 Line := AsmTrimSpaces(RawLine);
 If Length(Line) = 0 Then Exit;

 I := 1;
 While (I <= Length(Line)) And
       (((Line[I] >= 'A') And (Line[I] <= 'Z')) Or
        ((Line[I] >= 'a') And (Line[I] <= 'z')) Or
        ((Line[I] >= '0') And (Line[I] <= '9')) Or (Line[I] = '_')) Do
  Inc(I);

 LabelName := Copy(Line, 1, I - 1);
 Rest := AsmTrimSpaces(Copy(Line, I, Length(Line) - I + 1));
 Up := StrUpperCase(Rest);

 If (Length(LabelName) > 0) And
    ((Pos('DB ', Up) = 1) Or (Pos('DD ', Up) = 1)) Then
  AsmDefineLabel(LabelName)
 Else
 Begin
  Rest := Line;
  LabelName := '';
 End;

 Up := StrUpperCase(Rest);
 If Pos('DD ', Up) = 1 Then
 Begin
  ByteWidth := 4;
  Rest := AsmTrimSpaces(Copy(Rest, 3, Length(Rest) - 2));
 End
 Else If Pos('DB ', Up) = 1 Then
 Begin
  ByteWidth := 1;
  Rest := AsmTrimSpaces(Copy(Rest, 3, Length(Rest) - 2));
 End
 Else
 Begin
  FatalError('assembleur : declaration de donnees non geree: ' + Line);
  Exit;
 End;

 Cur := ''; InQuote := False;
 For J := 1 To Length(Rest) Do
 Begin
  C := Rest[J];
  If C = '''' Then InQuote := Not InQuote;
  If (C = ',') And (Not InQuote) Then
  Begin
   AsmEmitDataItem(Cur, ByteWidth);
   Cur := '';
  End
  Else
   Cur := Cur + C;
 End;
 If Length(AsmTrimSpaces(Cur)) > 0 Then AsmEmitDataItem(Cur, ByteWidth);
End;

{ ------------------------------------------------------------ }
{ AsmAssembleFile : relire le fichier .asm deja ecrit            }
{ (EmitOpen/EmitInstr/..., TODO 07) et assembler chaque ligne      }
{ vers AsmBuf. Capture aussi l etiquette de point d entree depuis  }
{ la ligne finale 'END <Nom>' (EmitClose).                          }
{ ------------------------------------------------------------ }

Var AsmEntryLabelName : TString;

Procedure AsmAssembleFile(Const AsmPath: TString);
Var
 F : Text;
 Line, Trimmed, Up : TString;
 ColonPos : Integer;
Begin
 AsmInit;
 AsmEntryLabelName := '';

 {$I-} Assign(F, AsmPath); Reset(F); {$I+}
 If IOResult <> 0 Then
 Begin
  FatalError('assembleur : impossible de relire le fichier .asm: ' + AsmPath);
  Exit;
 End;

 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Trimmed := AsmTrimSpaces(Line);
  If Length(Trimmed) = 0 Then Continue;
  If Trimmed[1] = ';' Then Continue;

  Up := StrUpperCase(Trimmed);

  If (Up = '.386') Or (Pos('.MODEL', Up) = 1) Then Continue;
  If Up = '.DATA' Then Begin AsmCurSec := ASMSEC_DATA; Continue; End;
  If Up = '.CODE' Then Begin AsmCurSec := ASMSEC_TEXT; Continue; End;

  If Pos('EXTRN ', Up) = 1 Then
  Begin
   ColonPos := Pos(':', Trimmed);
   If ColonPos > 0 Then
    AsmDeclareExtern(AsmTrimSpaces(Copy(Trimmed, 7, ColonPos - 7)))
   Else
    AsmDeclareExtern(AsmTrimSpaces(Copy(Trimmed, 7, Length(Trimmed) - 6)));
   Continue;
  End;

  If (Up = 'END') Or (Pos('END ', Up) = 1) Then
  Begin
   If Length(Trimmed) > 4 Then
    AsmEntryLabelName := AsmTrimSpaces(Copy(Trimmed, 5, Length(Trimmed) - 4));
   Break;
  End;

  If Trimmed[Length(Trimmed)] = ':' Then
  Begin
   AsmDefineLabel(Copy(Trimmed, 1, Length(Trimmed) - 1));
   Continue;
  End;

  If AsmCurSec = ASMSEC_DATA Then
   AsmAssembleDataLine(Trimmed)
  Else
   AsmAssembleInstrLine(Trimmed);
 End;

 Close(F);
End;

{ ------------------------------------------------------------ }
{ AsmCreateThunk : vignette IAT (TODO 24) - un CALL/JMP vers un   }
{ symbole EXTERN ne peut pas etre un rel32 direct (l adresse        }
{ reelle de la DLL est inconnue avant le chargement) : il saute       }
{ vers une petite vignette locale ('JMP DWORD PTR [case IAT]', 6        }
{ octets), UNE fois par symbole extern reellement appele. L adresse      }
{ de la case IAT elle-meme n est connue qu une fois la disposition        }
{ PE calculee (WritePEExe) - d ou le fixup ABS32 special '@IAT:Nom'.       }
{ ------------------------------------------------------------ }

Procedure AsmCreateThunk(ExternIdx: Integer);
Var SavedSec: Integer;
Begin
 If AsmThunkExists[ExternIdx] Then Exit;
 SavedSec := AsmCurSec;
 AsmCurSec := ASMSEC_TEXT;
 AsmThunkOfs[ExternIdx] := AsmLen[ASMSEC_TEXT];
 AsmThunkExists[ExternIdx] := True;
 AsmEmitByte($FF);
 AsmEmitByte($25);
 AsmEmitDWord(0);
 AsmAddFixup(ASMSEC_TEXT, AFX_ABS32, '@IAT:' + AsmExterns[ExternIdx], 0);
 AsmCurSec := SavedSec;
End;

{ ------------------------------------------------------------ }
{ AsmResolveRel32Fixups : corriger tous les fixups REL32 (toujours}
{ intra-.text : etiquette locale, ou vignette IAT nouvellement       }
{ creee) et retirer ces entrees de AsmFixups - seuls les fixups        }
{ ABS32 (adresse absolue, connue seulement une fois la disposition      }
{ PE/COFF calculee) restent apres cet appel. La boucle relit             }
{ AsmFixupCount a CHAQUE iteration (While, pas For) car                   }
{ AsmCreateThunk peut ajouter de NOUVEAUX fixups ABS32 en fin de           }
{ table pendant le parcours.                                                }
{ ------------------------------------------------------------ }

Procedure AsmResolveRel32Fixups;
Var
 I, LI, EI : Integer;
 TargetOfs : LongInt;
 KeepList : Array[0..MAX_ASM_FIXUPS - 1] Of TAsmFixup;
 KeepCount : Integer;
Begin
 KeepCount := 0;
 I := 0;
 While I < AsmFixupCount Do
 Begin
  If AsmFixups[I].Kind = AFX_REL32 Then
  Begin
   LI := AsmFindLabel(AsmFixups[I].TargetName);
   If LI >= 0 Then
    TargetOfs := AsmLabels[LI].Ofs
   Else
   Begin
    EI := AsmExternIndex(AsmFixups[I].TargetName);
    If EI < 0 Then
    Begin
     FatalError('assembleur : symbole introuvable (CALL/JMP): ' +
      AsmFixups[I].TargetName);
     Exit;
    End;
    AsmCreateThunk(EI);
    TargetOfs := AsmThunkOfs[EI];
   End;
   TargetOfs := TargetOfs - (AsmFixups[I].Pos + 4);
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos]     := TargetOfs And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 1] := (TargetOfs Shr 8) And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 2] := (TargetOfs Shr 16) And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 3] := (TargetOfs Shr 24) And $FF;
  End
  Else
  Begin
   KeepList[KeepCount] := AsmFixups[I];
   Inc(KeepCount);
  End;
  Inc(I);
 End;

 For I := 0 To KeepCount - 1 Do AsmFixups[I] := KeepList[I];
 AsmFixupCount := KeepCount;
End;

Function AsmAlignUp(V, Align: LongInt): LongInt;
Begin
 If V Mod Align = 0 Then AsmAlignUp := V
 Else AsmAlignUp := ((V Div Align) + 1) * Align;
End;

Function AsmSectionRva(Sec: Integer; TRva, DRva, IRva: LongInt): LongInt;
Begin
 Case Sec Of
  ASMSEC_TEXT  : AsmSectionRva := TRva;
  ASMSEC_DATA  : AsmSectionRva := DRva;
  ASMSEC_IDATA : AsmSectionRva := IRva;
  Else AsmSectionRva := 0;
 End;
End;

{ ------------------------------------------------------------ }
{ PEOutF / PEWriteXxx : primitives d ecriture binaire brute (petit}
{ boutiste, convention x86 native) vers le fichier .exe/.obj final.}
{ ------------------------------------------------------------ }

Var PEOutF : File;

Procedure PEWriteByte(B: Integer);
Var Bt: Byte;
Begin
 Bt := B And $FF;
 BlockWrite(PEOutF, Bt, 1);
End;

Procedure PEWriteWord(W: Integer);
Begin
 PEWriteByte(W And $FF);
 PEWriteByte((W Shr 8) And $FF);
End;

Procedure PEWriteDWord(D: LongInt);
Begin
 PEWriteByte(D And $FF);
 PEWriteByte((D Shr 8) And $FF);
 PEWriteByte((D Shr 16) And $FF);
 PEWriteByte((D Shr 24) And $FF);
End;

Procedure PEWriteZeros(N: LongInt);
Var I: LongInt;
Begin
 For I := 1 To N Do PEWriteByte(0);
End;

Procedure PEWriteStr(Const S: TString);
Var I: Integer;
Begin
 For I := 1 To Length(S) Do PEWriteByte(Ord(S[I]));
End;

{ PEWriteAnsiStr : comme PEWriteStr, mais pour un AnsiString (non    }
{ borne a 255 caracteres, contrairement a TString = String sous la    }
{ directive de chaines courtes active pour tout ce fichier, TODO 01) - }
{ necessaire pour la table des chaines de WriteCOFFObj (StrTab), qui     }
{ concatene le nom de CHAQUE etiquette/symbole du fichier (bien au-dela   }
{ de 255 caracteres des qu un programme reel est compile, vu le nombre     }
{ de routines RTL) : passer un AnsiString a PEWriteStr le convertirait       }
{ d abord en TString (ShortString), tronquant silencieusement - bug          }
{ confirme (TODO 25, table des symboles/chaines corrompue au-dela de          }
{ 255 caracteres cumules, decouvert en relisant un .obj produit avec un        }
{ vrai objdump).                                                                 }
Procedure PEWriteAnsiStr(Const S: AnsiString);
Var I: Integer;
Begin
 For I := 1 To Length(S) Do PEWriteByte(Ord(S[I]));
End;

Procedure PEWriteSectionBytes(Sec: Integer; Count: LongInt);
Var I: LongInt;
Begin
 For I := 0 To Count - 1 Do PEWriteByte(AsmBuf[Sec][I]);
End;

{ ------------------------------------------------------------ }
{ WritePEExe (TODO 24) : ecrire un fichier PE (.exe) complet a     }
{ partir de AsmBuf/AsmLabels/AsmFixups/AsmExterns deja assembles   }
{ (AsmAssembleFile + AsmResolveRel32Fixups deja executes par        }
{ l appelant). Structure/constantes reprises de ML.PAS (projet       }
{ frere, deja verifie sur de vrais .exe qui s executent) : base        }
{ image $400000, alignement section $1000, alignement fichier         }
{ $200, en-tete optionnel PE32 224 octets, disposition en DEUX          }
{ etapes (mesurer, puis ecrire). Simplification documentee (TODO 24) :   }
{ TOUS les imports externes sont supposes venir de KERNEL32.DLL (les      }
{ imports utilisateur d autres DLL, 'external', TODO 14/22, n ont pas       }
{ encore leur nom de DLL propage jusqu ici - seulement en commentaire        }
{ non analyse) - correct pour tout ce que ce compilateur importe            }
{ reellement aujourd hui (les 9 imports de base, EmitHeader).                 }
{ ------------------------------------------------------------ }

Procedure WritePEExe(Const OutPath: TString);
Const
 IMAGE_BASE = $400000;
 SEC_ALIGN  = $1000;
 FILE_ALIGN = $200;
 KERNEL32_NAME = 'KERNEL32.DLL';
Var
 NImp, I, LI, FixI : Integer;
 HintNameOfs : Array[0..MAX_ASM_EXTERNS - 1] Of LongInt;
 IltOfs, IatOfs, DllNameOfs, HintNameTotal : LongInt;
 IdataExtra : LongInt;
 TextSize, DataSize, IdataSize : LongInt;
 TextRva, DataRva, IdataRva : LongInt;
 TextFileOfs, DataFileOfs, IdataFileOfs : LongInt;
 TextRawSize, DataRawSize, IdataRawSize : LongInt;
 HdrSize, HdrSizeAligned : LongInt;
 EntryRva, EntryLI : Integer;
 ImportDirRva, IltRva, IatRva, DllNameRva : LongInt;
 ImageSize : LongInt;
 Name : TString;
 V : LongInt;
 HnLen : Integer;
Begin
 { --- 1. mesurer le bloc d import (a l interieur de .idata) --- }
 NImp := AsmExternCount;
 IltOfs := 40;                        { table des import : 1 descripteur + 1 nul }
 IatOfs := IltOfs + (NImp + 1) * 4;
 HintNameTotal := 0;
 For I := 0 To NImp - 1 Do
 Begin
  HintNameOfs[I] := IatOfs + (NImp + 1) * 4 + HintNameTotal;
  HnLen := 2 + Length(AsmExportNameFor(AsmExterns[I])) + 1;
  If HnLen Mod 2 <> 0 Then Inc(HnLen);
  HintNameTotal := HintNameTotal + HnLen;
 End;
 DllNameOfs := IatOfs + (NImp + 1) * 4 + HintNameTotal;
 IdataExtra := DllNameOfs + Length(KERNEL32_NAME) + 1;
 If IdataExtra Mod 2 <> 0 Then Inc(IdataExtra);

 { --- 2. tailles finales des sections (toujours 3, jamais vides   }
 { en pratique : donnees/code runtime toujours presents) --- }
 TextSize  := AsmLen[ASMSEC_TEXT];
 DataSize  := AsmLen[ASMSEC_DATA];
 IdataSize := AsmLen[ASMSEC_IDATA] + IdataExtra;

 { --- 3. disposition RVA/fichier (deux passes, comme ML.PAS) --- }
 HdrSize := 64 + 4 + 20 + 224 + 3 * 40;
 HdrSizeAligned := AsmAlignUp(HdrSize, FILE_ALIGN);

 TextRva     := SEC_ALIGN;
 TextFileOfs := HdrSizeAligned;
 TextRawSize := AsmAlignUp(TextSize, FILE_ALIGN);

 DataRva     := TextRva + AsmAlignUp(TextSize, SEC_ALIGN);
 DataFileOfs := TextFileOfs + TextRawSize;
 DataRawSize := AsmAlignUp(DataSize, FILE_ALIGN);

 IdataRva     := DataRva + AsmAlignUp(DataSize, SEC_ALIGN);
 IdataFileOfs := DataFileOfs + DataRawSize;
 IdataRawSize := AsmAlignUp(IdataSize, FILE_ALIGN);

 ImageSize := AsmAlignUp(IdataRva + IdataSize, SEC_ALIGN);

 ImportDirRva := IdataRva + AsmLen[ASMSEC_IDATA];
 IltRva       := IdataRva + AsmLen[ASMSEC_IDATA] + IltOfs;
 IatRva       := IdataRva + AsmLen[ASMSEC_IDATA] + IatOfs;
 DllNameRva   := IdataRva + AsmLen[ASMSEC_IDATA] + DllNameOfs;

 { --- 4. corriger les fixups ABS32 (adresses absolues) : soit une }
 { etiquette locale (.text/.data/.idata + son offset), soit une      }
 { vignette IAT ('@IAT:Nom' - la case IAT de cet import).              }
 For FixI := 0 To AsmFixupCount - 1 Do
 Begin
  Name := AsmFixups[FixI].TargetName;
  If Pos('@IAT:', Name) = 1 Then
  Begin
   LI := AsmExternIndex(Copy(Name, 6, Length(Name) - 5));
   If LI < 0 Then
   Begin
    FatalError('assembleur : import introuvable pour la vignette IAT: ' + Name);
    Exit;
   End;
   V := IMAGE_BASE + IatRva + LI * 4;
  End
  Else
  Begin
   LI := AsmFindLabel(Name);
   If LI < 0 Then
   Begin
    FatalError('assembleur : etiquette introuvable: ' + Name);
    Exit;
   End;
   V := IMAGE_BASE +
    AsmSectionRva(AsmLabels[LI].Sec, TextRva, DataRva, IdataRva) +
    AsmLabels[LI].Ofs + AsmFixups[FixI].Addend;
  End;
  AsmBuf[AsmFixups[FixI].Sec][AsmFixups[FixI].Pos]     := V And $FF;
  AsmBuf[AsmFixups[FixI].Sec][AsmFixups[FixI].Pos + 1] := (V Shr 8) And $FF;
  AsmBuf[AsmFixups[FixI].Sec][AsmFixups[FixI].Pos + 2] := (V Shr 16) And $FF;
  AsmBuf[AsmFixups[FixI].Sec][AsmFixups[FixI].Pos + 3] := (V Shr 24) And $FF;
 End;

 { --- 5. point d entree --- }
 EntryLI := AsmFindLabel(AsmEntryLabelName);
 If EntryLI >= 0 Then
  EntryRva := AsmSectionRva(AsmLabels[EntryLI].Sec, TextRva, DataRva, IdataRva) +
   AsmLabels[EntryLI].Ofs
 Else
  EntryRva := TextRva;

 { --- 6. ecrire le fichier --- }
 {$I-} Assign(PEOutF, OutPath); Rewrite(PEOutF, 1); {$I+}
 If IOResult <> 0 Then
 Begin
  FatalError('impossible de creer le fichier de sortie: ' + OutPath);
  Exit;
 End;

 { en-tete MZ minimal (64 octets : seuls e_magic et e_lfanew comptent) }
 PEWriteWord($5A4D);           { 'MZ' }
 PEWriteZeros(58);
 PEWriteDWord(64);             { e_lfanew : l en-tete PE suit immediatement }

 PEWriteDWord($00004550);      { "PE\0\0" }

 { IMAGE_FILE_HEADER (20 octets) }
 PEWriteWord($014C);           { Machine = i386 }
 PEWriteWord(3);               { NumberOfSections }
 PEWriteDWord(0);              { TimeDateStamp }
 PEWriteDWord(0);              { PointerToSymbolTable }
 PEWriteDWord(0);              { NumberOfSymbols }
 PEWriteWord(224);             { SizeOfOptionalHeader }
 PEWriteWord($010F);           { Characteristics }

 { IMAGE_OPTIONAL_HEADER32 (224 octets) }
 PEWriteWord($10B);            { Magic = PE32 }
 PEWriteByte(1); PEWriteByte(0);   { MajorLinkerVersion, Minor }
 PEWriteDWord(AsmAlignUp(TextSize, FILE_ALIGN));    { SizeOfCode }
 PEWriteDWord(AsmAlignUp(DataSize, FILE_ALIGN) +
  AsmAlignUp(IdataSize, FILE_ALIGN));                 { SizeOfInitializedData }
 PEWriteDWord(0);              { SizeOfUninitializedData }
 PEWriteDWord(EntryRva);       { AddressOfEntryPoint }
 PEWriteDWord(TextRva);        { BaseOfCode }
 PEWriteDWord(DataRva);        { BaseOfData }
 PEWriteDWord(IMAGE_BASE);     { ImageBase }
 PEWriteDWord(SEC_ALIGN);      { SectionAlignment }
 PEWriteDWord(FILE_ALIGN);     { FileAlignment }
 PEWriteWord(4); PEWriteWord(0);   { OS version }
 PEWriteWord(0); PEWriteWord(0);   { Image version }
 PEWriteWord(4); PEWriteWord(0);   { Subsystem version }
 PEWriteDWord(0);              { Win32VersionValue }
 PEWriteDWord(ImageSize);      { SizeOfImage }
 PEWriteDWord(HdrSizeAligned); { SizeOfHeaders }
 PEWriteDWord(0);              { CheckSum }
 PEWriteWord(3);               { Subsystem = CUI (console) }
 PEWriteWord(0);               { DllCharacteristics }
 PEWriteDWord($100000);        { SizeOfStackReserve }
 PEWriteDWord($1000);          { SizeOfStackCommit }
 PEWriteDWord($100000);        { SizeOfHeapReserve }
 PEWriteDWord($1000);          { SizeOfHeapCommit }
 PEWriteDWord(0);              { LoaderFlags }
 PEWriteDWord(16);             { NumberOfRvaAndSizes }
 PEWriteDWord(0); PEWriteDWord(0);              { [0] Export }
 PEWriteDWord(ImportDirRva); PEWriteDWord(40);  { [1] Import }
 PEWriteDWord(0); PEWriteDWord(0);              { [2] Resource }
 PEWriteDWord(0); PEWriteDWord(0);              { [3] Exception }
 PEWriteDWord(0); PEWriteDWord(0);              { [4] Security }
 PEWriteDWord(0); PEWriteDWord(0);              { [5] BaseReloc }
 PEWriteDWord(0); PEWriteDWord(0);              { [6] Debug }
 PEWriteDWord(0); PEWriteDWord(0);              { [7] Architecture }
 PEWriteDWord(0); PEWriteDWord(0);              { [8] GlobalPtr }
 PEWriteDWord(0); PEWriteDWord(0);              { [9] TLS }
 PEWriteDWord(0); PEWriteDWord(0);              { [10] LoadConfig }
 PEWriteDWord(0); PEWriteDWord(0);              { [11] BoundImport }
 PEWriteDWord(IatRva); PEWriteDWord((NImp + 1) * 4);  { [12] IAT }
 PEWriteDWord(0); PEWriteDWord(0);              { [13] DelayImport }
 PEWriteDWord(0); PEWriteDWord(0);              { [14] COM descriptor }
 PEWriteDWord(0); PEWriteDWord(0);              { [15] reserve }

 { table des sections (3 en-tetes de 40 octets) }
 PEWriteStr('.text'); PEWriteZeros(8 - Length('.text'));
 PEWriteDWord(TextSize); PEWriteDWord(TextRva);
 PEWriteDWord(TextRawSize); PEWriteDWord(TextFileOfs);
 PEWriteDWord(0); PEWriteDWord(0); PEWriteWord(0); PEWriteWord(0);
 PEWriteDWord($60000020);      { CODE | EXECUTE | READ }

 PEWriteStr('.data'); PEWriteZeros(8 - Length('.data'));
 PEWriteDWord(DataSize); PEWriteDWord(DataRva);
 PEWriteDWord(DataRawSize); PEWriteDWord(DataFileOfs);
 PEWriteDWord(0); PEWriteDWord(0); PEWriteWord(0); PEWriteWord(0);
 PEWriteDWord(-1073741760);    { $C0000040 = INITIALIZED_DATA|READ|WRITE, }
                                { ecrit en decimal signe (le bit de poids }
                                { fort deborde un LongInt signe litteral) }

 PEWriteStr('.idata'); PEWriteZeros(8 - Length('.idata'));
 PEWriteDWord(IdataSize); PEWriteDWord(IdataRva);
 PEWriteDWord(IdataRawSize); PEWriteDWord(IdataFileOfs);
 PEWriteDWord(0); PEWriteDWord(0); PEWriteWord(0); PEWriteWord(0);
 PEWriteDWord(-1073741760);    { $C0000040 = INITIALIZED_DATA|READ|WRITE, }
                                { ecrit en decimal signe (le bit de poids }
                                { fort deborde un LongInt signe litteral) }

 PEWriteZeros(HdrSizeAligned - HdrSize);

 { --- .text --- }
 PEWriteSectionBytes(ASMSEC_TEXT, TextSize);
 PEWriteZeros(TextRawSize - TextSize);

 { --- .data --- }
 PEWriteSectionBytes(ASMSEC_DATA, DataSize);
 PEWriteZeros(DataRawSize - DataSize);

 { --- .idata : donnees utilisateur puis table d import --- }
 PEWriteSectionBytes(ASMSEC_IDATA, AsmLen[ASMSEC_IDATA]);

 { Import Directory Table : 1 descripteur KERNEL32.DLL + 1 nul }
 PEWriteDWord(IltRva);         { OriginalFirstThunk }
 PEWriteDWord(0);              { TimeDateStamp }
 PEWriteDWord(0);              { ForwarderChain }
 PEWriteDWord(DllNameRva);     { Name }
 PEWriteDWord(IatRva);         { FirstThunk }
 PEWriteZeros(20);             { descripteur nul terminal }

 { Import Lookup Table (ILT) : une RVA Hint/Name par import + nul }
 For I := 0 To NImp - 1 Do
  PEWriteDWord(IdataRva + AsmLen[ASMSEC_IDATA] + HintNameOfs[I]);
 PEWriteDWord(0);

 { Import Address Table (IAT) : identique a l ILT au depart (le    }
 { chargeur la remplace par les vraies adresses au demarrage) }
 For I := 0 To NImp - 1 Do
  PEWriteDWord(IdataRva + AsmLen[ASMSEC_IDATA] + HintNameOfs[I]);
 PEWriteDWord(0);

 { entrees Hint/Name : le nom REEL exporte par la DLL (AsmExportNameFor,   }
 { pas le nom mangled/decore '_Nom@N' - le chargeur Windows cherche ce      }
 { nom textuellement dans la table d export de kernel32.dll, TODO 24).       }
 For I := 0 To NImp - 1 Do
 Begin
  PEWriteWord(0);              { Hint }
  PEWriteStr(AsmExportNameFor(AsmExterns[I]));
  PEWriteByte(0);
  HnLen := 2 + Length(AsmExportNameFor(AsmExterns[I])) + 1;
  If HnLen Mod 2 <> 0 Then PEWriteByte(0);
 End;

 { nom de la DLL }
 PEWriteStr(KERNEL32_NAME);
 PEWriteByte(0);
 If (DllNameOfs + Length(KERNEL32_NAME) + 1) <> IdataExtra Then
  PEWriteZeros(IdataExtra - (DllNameOfs + Length(KERNEL32_NAME) + 1));

 PEWriteZeros(IdataRawSize - IdataSize);

 Close(PEOutF);
End;

{ ------------------------------------------------------------ }
{ AsmResolveLocalRel32Fixups (TODO 24, mode -obj) : comme          }
{ AsmResolveRel32Fixups, mais SANS creer de vignette IAT pour un    }
{ REL32 vers un symbole EXTERN - en mode OBJ, un CALL/JMP vers un     }
{ import reste une vraie relocation COFF (REL32), resolue par           }
{ l EDITEUR DE LIENS lors de la liaison finale avec kernel32.lib          }
{ (ou toute autre unite .OBJ). Seules les references INTRA-fichier         }
{ (etiquette locale) sont resolues ici en offset relatif final -           }
{ elles restent valables telles quelles quel que soit l endroit ou          }
{ l editeur de liens placera la section (l ecart entre deux positions        }
{ de la MEME section ne change pas).                                          }
{ ------------------------------------------------------------ }

Procedure AsmResolveLocalRel32Fixups;
Var
 I, LI : Integer;
 TargetOfs : LongInt;
 KeepList : Array[0..MAX_ASM_FIXUPS - 1] Of TAsmFixup;
 KeepCount : Integer;
Begin
 KeepCount := 0;
 For I := 0 To AsmFixupCount - 1 Do
 Begin
  LI := -1;
  If AsmFixups[I].Kind = AFX_REL32 Then LI := AsmFindLabel(AsmFixups[I].TargetName);
  If (AsmFixups[I].Kind = AFX_REL32) And (LI >= 0) Then
  Begin
   TargetOfs := AsmLabels[LI].Ofs - (AsmFixups[I].Pos + 4);
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos]     := TargetOfs And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 1] := (TargetOfs Shr 8) And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 2] := (TargetOfs Shr 16) And $FF;
   AsmBuf[AsmFixups[I].Sec][AsmFixups[I].Pos + 3] := (TargetOfs Shr 24) And $FF;
  End
  Else
  Begin
   KeepList[KeepCount] := AsmFixups[I];
   Inc(KeepCount);
  End;
 End;
 For I := 0 To KeepCount - 1 Do AsmFixups[I] := KeepList[I];
 AsmFixupCount := KeepCount;
End;

{ ------------------------------------------------------------ }
{ WriteCOFFObj (TODO 24, -obj) : ecrire un fichier COFF (.obj)     }
{ minimal mais reel - IMAGE_FILE_HEADER, sections .text/.data        }
{ (donnees brutes, sans alignement fichier - un .OBJ n a pas besoin   }
{ d etre aligne au secteur comme un .EXE), relocations DIR32/REL32     }
{ (une par fixup restant apres AsmResolveLocalRel32Fixups - toute       }
{ reference intra-fichier deja resolue en dur), table des symboles       }
{ (une entree par section + par etiquette [PUBLIC par simplification,    }
{ TODO 24 : aucun suivi PUBLIC/STATIC explicite] + par import EXTERN),     }
{ table des chaines (tous les noms de symboles y passent, y compris        }
{ courts - simplification valide vis-a-vis du format COFF, qui l autorise). }
{ ------------------------------------------------------------ }

Procedure WriteCOFFObj(Const OutPath: TString);
Const
 COFF_REL_DIR32 = $0006;
 COFF_REL_REL32 = $0014;
 COFF_SYMCLASS_EXTERNAL = 2;
 COFF_SYMCLASS_STATIC   = 3;
Var
 I, FixI, RelocCount : Integer;
 TextRelocCount, DataRelocCount : Integer;
 SecHdrOfs, TextDataOfs, DataDataOfs : LongInt;
 TextRelocOfs, DataRelocOfs, SymTabOfs : LongInt;
 SymIndexOfSection : Array[0..1] Of Integer;   { 0=.text, 1=.data }
 SymIndexOfLabel   : Array[0..MAX_ASM_LABELS - 1] Of Integer;
 SymIndexOfExtern  : Array[0..MAX_ASM_EXTERNS - 1] Of Integer;
 NextSymIdx : Integer;
 StrTab : AnsiString;   { concatenation des noms, chacun termine par }
                         { #0 - AnsiString (pas TString/ShortString,  }
                         { limite a 255 caracteres) : depasse tres      }
                         { largement 255 caracteres cumules des qu un    }
                         { programme reel est compile (TODO 25).          }
 Name : TString;
 TargetSymIdx, LI, EI : Integer;
 RelocType : Integer;
 SecOf : Integer;

 Function StrTabAdd(Const Nm: TString): LongInt;
 Begin
  StrTabAdd := Length(StrTab) + 4;   { +4 : le prefixe de longueur COFF }
  StrTab := StrTab + Nm + #0;
 End;

Begin
 AsmResolveLocalRel32Fixups;

 { --- table des symboles : .text, .data, chaque etiquette, chaque   }
 { import extern (dans cet ordre, pour calculer les index a l avance) }
 NextSymIdx := 0;
 SymIndexOfSection[0] := NextSymIdx; Inc(NextSymIdx);   { .text }
 SymIndexOfSection[1] := NextSymIdx; Inc(NextSymIdx);   { .data }
 For I := 0 To AsmLabelCount - 1 Do
 Begin
  SymIndexOfLabel[I] := NextSymIdx;
  Inc(NextSymIdx);
 End;
 For I := 0 To AsmExternCount - 1 Do
 Begin
  SymIndexOfExtern[I] := NextSymIdx;
  Inc(NextSymIdx);
 End;

 { --- compter les relocations par section --- }
 TextRelocCount := 0; DataRelocCount := 0;
 For FixI := 0 To AsmFixupCount - 1 Do
 Begin
  If AsmFixups[FixI].Sec = ASMSEC_TEXT Then Inc(TextRelocCount)
  Else If AsmFixups[FixI].Sec = ASMSEC_DATA Then Inc(DataRelocCount);
 End;

 { --- disposition fichier : en-tete + 2 sections + donnees brutes + }
 { relocations + table des symboles + table des chaines --- }
 SecHdrOfs    := 20;
 TextDataOfs  := SecHdrOfs + 2 * 40;
 DataDataOfs  := TextDataOfs + AsmLen[ASMSEC_TEXT];
 TextRelocOfs := DataDataOfs + AsmLen[ASMSEC_DATA];
 DataRelocOfs := TextRelocOfs + TextRelocCount * 10;
 SymTabOfs    := DataRelocOfs + DataRelocCount * 10;

 StrTab := '';

 {$I-} Assign(PEOutF, OutPath); Rewrite(PEOutF, 1); {$I+}
 If IOResult <> 0 Then
 Begin
  FatalError('impossible de creer le fichier de sortie: ' + OutPath);
  Exit;
 End;

 { IMAGE_FILE_HEADER }
 PEWriteWord($014C);                { Machine = i386 }
 PEWriteWord(2);                    { NumberOfSections }
 PEWriteDWord(0);                   { TimeDateStamp }
 PEWriteDWord(SymTabOfs);           { PointerToSymbolTable }
 PEWriteDWord(NextSymIdx);          { NumberOfSymbols }
 PEWriteWord(0);                    { SizeOfOptionalHeader (aucun pour un .OBJ) }
 PEWriteWord(0);                    { Characteristics }

 { en-tete de section .text }
 PEWriteStr('.text'); PEWriteZeros(8 - Length('.text'));
 PEWriteDWord(0);                   { VirtualSize (non utilise pour un .OBJ) }
 PEWriteDWord(0);                   { VirtualAddress }
 PEWriteDWord(AsmLen[ASMSEC_TEXT]); { SizeOfRawData }
 PEWriteDWord(TextDataOfs);         { PointerToRawData }
 PEWriteDWord(TextRelocOfs);        { PointerToRelocations }
 PEWriteDWord(0);                   { PointerToLinenumbers }
 PEWriteWord(TextRelocCount);       { NumberOfRelocations }
 PEWriteWord(0);                    { NumberOfLinenumbers }
 PEWriteDWord($60000020);           { CODE | EXECUTE | READ }

 { en-tete de section .data }
 PEWriteStr('.data'); PEWriteZeros(8 - Length('.data'));
 PEWriteDWord(0);
 PEWriteDWord(0);
 PEWriteDWord(AsmLen[ASMSEC_DATA]);
 PEWriteDWord(DataDataOfs);
 PEWriteDWord(DataRelocOfs);
 PEWriteDWord(0);
 PEWriteWord(DataRelocCount);
 PEWriteWord(0);
 PEWriteDWord(-1073741760);         { $C0000040 = INITIALIZED_DATA|READ|WRITE }

 { donnees brutes }
 PEWriteSectionBytes(ASMSEC_TEXT, AsmLen[ASMSEC_TEXT]);
 PEWriteSectionBytes(ASMSEC_DATA, AsmLen[ASMSEC_DATA]);

 { relocations .text puis .data }
 For SecOf := ASMSEC_TEXT To ASMSEC_DATA Do
  For FixI := 0 To AsmFixupCount - 1 Do
   If AsmFixups[FixI].Sec = SecOf Then
   Begin
    Name := AsmFixups[FixI].TargetName;
    LI := AsmFindLabel(Name);
    If LI >= 0 Then
     TargetSymIdx := SymIndexOfLabel[LI]
    Else
    Begin
     EI := AsmExternIndex(Name);
     If EI >= 0 Then
      TargetSymIdx := SymIndexOfExtern[EI]
     Else
     Begin
      FatalError('assembleur (.obj) : symbole introuvable: ' + Name);
      Exit;
     End;
    End;
    If AsmFixups[FixI].Kind = AFX_REL32 Then RelocType := COFF_REL_REL32
    Else RelocType := COFF_REL_DIR32;
    PEWriteDWord(AsmFixups[FixI].Pos);
    PEWriteDWord(TargetSymIdx);
    PEWriteWord(RelocType);
   End;

 { table des symboles (18 octets chacun) : .text, .data, etiquettes, }
 { imports externes - toutes les entrees utilisent la table des        }
 { chaines pour le nom (simplification valide, TODO 24 : le format        }
 { COFF autorise cette forme meme pour un nom court de 8 caracteres        }
 { ou moins, qui pourrait sinon tenir en ligne).                             }
 PEWriteDWord(0); PEWriteDWord(StrTabAdd('.text'));
 PEWriteDWord(0); PEWriteWord(1); PEWriteWord(0);   { section 1, Type=0 (usuel) }
 PEWriteByte(COFF_SYMCLASS_STATIC); PEWriteByte(0);

 PEWriteDWord(0); PEWriteDWord(StrTabAdd('.data'));
 PEWriteDWord(0); PEWriteWord(2); PEWriteWord(0);
 PEWriteByte(COFF_SYMCLASS_STATIC); PEWriteByte(0);

 For I := 0 To AsmLabelCount - 1 Do
 Begin
  PEWriteDWord(0); PEWriteDWord(StrTabAdd(AsmLabels[I].Name));
  PEWriteDWord(AsmLabels[I].Ofs);
  If AsmLabels[I].Sec = ASMSEC_TEXT Then PEWriteWord(1) Else PEWriteWord(2);
  PEWriteWord(0);
  PEWriteByte(COFF_SYMCLASS_EXTERNAL);   { PUBLIC par simplification, TODO 24 }
  PEWriteByte(0);
 End;

 For I := 0 To AsmExternCount - 1 Do
 Begin
  PEWriteDWord(0); PEWriteDWord(StrTabAdd(AsmExterns[I]));
  PEWriteDWord(0); PEWriteWord(0);       { section 0 = symbole non defini ici }
  PEWriteWord(0);
  PEWriteByte(COFF_SYMCLASS_EXTERNAL);
  PEWriteByte(0);
 End;

 { table des chaines : prefixe de longueur (elle-meme comprise) puis }
 { les noms concatenes, chacun termine par un octet nul.               }
 PEWriteDWord(Length(StrTab) + 4);
 PEWriteAnsiStr(StrTab);

 Close(PEOutF);
End;

{ ------------------------------------------------------------ }
{ Run - point d entree de la compilation                       }
{ Fait passer le lexeur sur tout le fichier source, puis pilote   }
{ la compilation reelle via CompileSourceFile (TODO 23 :          }
{ detection Program/Unit/Library, section(s) de declarations,     }
{ routines, bloc principal) et genere un .ASM assemblable si      }
{ -asm est demande.                                                }
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
 PropSelfTest;
 InterfaceSelfTest;
 ExceptionSelfTest;
 CompoundSelfTest;
 StrSelfTest;
 AsmSelfTest;
 Rtl22SelfTest;
 Prog23SelfTest;
 Todo24SelfTest;

 {$I-}
 Assign(LexSrcF, Opts.SrcFile);
 Reset(LexSrcF);
 {$I+}
 If IOResult <> 0 Then
  FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
 LexOpened   := True;
 LexSrcFName := Opts.SrcFile;

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

 { PP pointe deja sur le premier jeton reel (ParserInit ci-dessus) :   }
 { ajuster Opts.OutFile AVANT ShowBanner (TODO 25) pour qu elle          }
 { affiche deja la bonne extension/le bon mode pour une Unite (qui n a    }
 { pas de point d entree, donc jamais de .exe direct) - CompileSourceFile }
 { refait le meme test plus loin, sans effet (idempotent).                  }
 AdjustOutFileForUnitIfNeeded;
 ShowBanner;

 { TODO 23 : compilation reelle du fichier source (detection Program/ }
 { Unit/Library, declarations, routines, bloc principal) - remplace   }
 { l ancien squelette fixe (EmitSkeletonProgram, conserve pour les     }
 { self-tests qui l utilisent encore tel quel).                        }
 CompileSourceFile;

 If Opts.Verbose Then
 Begin
  WriteLn('AppType  : ', AppType);
  WriteLn('Tokens   : ', TokenCount, '   Donnees (chaines) : ', DataCount);
  WriteLn('Symboles predefinis enregistres : ', SymCount);
  WriteLn('Types predefinis enregistres    : ', TypeCount);
 End;

 {WriteLn('DELPHI: TODO 01 (infrastructure et options) implemente.');
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
 WriteLn('DELPHI: TODO 16 (proprietes) implemente.');
 WriteLn('DELPHI: TODO 17 (interfaces et COM de base) implemente.');
 WriteLn('DELPHI: TODO 18 (gestion des exceptions) implemente.');
 WriteLn('DELPHI: TODO 19 (tableaux, records et ensembles) implemente.');
 WriteLn('DELPHI: TODO 20 (chaines de caracteres) implemente.');
 WriteLn('DELPHI: TODO 21 (instruction asm, bloc assembleur en ligne) ',
         'implemente.');
 WriteLn('DELPHI: TODO 22 (unites RTL minimales System/SysUtils/Classes) ',
         'implemente.');
 WriteLn('DELPHI: TODO 23 (fichiers projet .dpr et unites .pas) ',
         'implemente.');
 WriteLn('DELPHI: TODO 24 (generation PE/OBJ, EXE par defaut, ',
         'OBJ sur demande) implemente.');
 WriteLn('DELPHI: TODO 25 (validation : support complet de ',
         'SAMPLES/DELPHI) implemente.');}
 ShowStats;
 Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

BEGIN
 ParseArgs;
 Run;
 Halt(EXIT_OK);
END.

