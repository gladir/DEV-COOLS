{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Turbo Pascal vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  TPCW32.PAS - Compilateur Turbo Pascal vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Avec le parametre -dos16, produit un executable DOS 16 bits.

  Compilateur Turbo Pascal pour Windows 32 bits. Meme
  l instruction ASM avec de l assembleur 8086/8088 est
  traduite en assembleur 80386 de facon transparente.

  Les unites Crt, DOS, Graph, Graph3, Strings, Overlay,
  Printer, WinDOS, Turbo3, Objects sont supportees de
  facon native.

  Les Mem, MemW, MemL, Port, PortW sont supportes par
  emulation (Port[$60] -> lecture clavier via API Windows,
  lecture CMOS par Port/PortW, IN/OUT en ASM).

  L instruction MsDos de l unite DOS ou WinDOS, ainsi que
  INT 21h de l instruction ASM, emulent les appels des
  fonctions 00h, 01h, 02h, ... de l interruption 21h
  classique avec des appels a l API Windows equivalente.

  L instruction Intr ou l instruction INT d ASM supporte
  l interruption 10h, fonction 00h pour le changement de
  mode video.

  Il est possible d indiquer le numero de version du
  Turbo Pascal cible : 1, 2, 4, 5, 5.5 (tp55), 6, 7, 8.
  Par defaut c est la version 7.

  FEUILLE DE ROUTE - 29 TODOS
  Voir DOC/TODO/TCW32.txt pour la liste detaillee des TODOs.

  ============================================================ *)

Program TPCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE ET OPTIONS                [IMPLEMENTE] }
{ ============================================================ }

Const
  TPCW32_VERSION = '0.1';
  TPCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Versions de Turbo Pascal supportees }
  TP_VER_1   = 1;
  TP_VER_2   = 2;
  TP_VER_4   = 4;
  TP_VER_5   = 5;
  TP_VER_55  = 55;   { 5.5 represente par 55 }
  TP_VER_6   = 6;
  TP_VER_7   = 7;
  TP_VER_8   = 8;
  TP_VER_DEFAULT = TP_VER_7;

  { Destinations de compilation }
  DEST_WIN32 = 0;   { Windows 32 bits (defaut)   }
  DEST_DOSR  = 1;   { -CD  : DOS mode reel       }
  DEST_DOSP  = 2;   { -CP  : DOS mode protege     }
  DEST_WIN30 = 3;   { -CW  : Windows 3.0          }
  DEST_W32   = 4;   { -CW32 : Windows 32 bits     }
  DEST_Z80   = 5;   { -CZ80 : Zilog Z80           }
  DEST_6502  = 6;   { -C6502 : MOS 6502           }
  DEST_6809  = 7;   { -C6809 : Motorola 6809      }
  DEST_68000 = 8;   { -C68000 : Motorola 68000    }

Type
  TString = String;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.pas)                }
    OutFile   : TString;   { fichier sortie (.exe, .obj)          }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : afficher les avertissements     }
    AsmOutput : Boolean;   { -asm : produire aussi un .ASM        }
    ObjOnly   : Boolean;   { -obj : produire seulement un .OBJ    }
    Dos16Mode : Boolean;   { -dos16 : generer un exe DOS 16 bits  }
    TPVersion : Integer;   { version TP cible (1..8, 55=5.5)      }
    { Options compatibles TPC 7.0 (TODO 25) }
    BuildAll  : Boolean;   { -B : build all units (DOS 16 seulement)  }
    Defines   : TString;   { -D<syms> : symboles conditionnels        }
    ExeDir    : TString;   { -E<path> : repertoire EXE/TPU sortie     }
    FindErr   : TString;   { -F<adr>  : find error (DOS 16 seulement) }
    MapDetailed : Boolean; { -GD : map detaillee                      }
    MapPublics  : Boolean; { -GP : map avec publics                   }
    MapSegments : Boolean; { -GS : map avec segments                  }
    IncDirs   : TString;   { -I<path> : repertoires Include           }
    LinkDisk  : Boolean;   { -L : link buffer disque (DOS 16 seulem.) }
    MakeUnits : Boolean;   { -M : make unites modifiees (DOS 16 s.)   }
    ObjDirs   : TString;   { -O<path> : repertoires objets            }
    Quiet     : Boolean;   { -Q : compilation silencieuse              }
    ResDirs   : TString;   { -R<path> : repertoires Resource (DOS 16) }
    TurboDir  : TString;   { -T<path> : repertoire Turbo (DOS 16)     }
    UnitDirs  : TString;   { -U<path> : repertoires unites            }
    DebugInfo : Boolean;   { -V : infos de debogage dans l EXE        }
    CompDir   : TString;   { -$<sw> : directives compilateur          }
    QuickPascal : Boolean;   { --quickpascal : mode QuickPascal (MSGraph) }
    ApplePascal : Boolean;   { --applepascal : mode Apple Pascal (SANE+TRANSCEND) }
    Sane        : Boolean;   { --sane : mode SANE seul (sans TRANSCEND) }
    DestTarget  : Integer;   { -CD/-CP/-CW/-CW32/-CZ80 : destination   }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Drapeau pour la generation binaire PE (mini-assembleur) }
  BcActive   : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
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

Function StrLowerCase(Const S : TString) : TString;
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

{ Retourne l extension d un chemin (avec le point, en minuscules) }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
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
Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
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

{ Retourne une chaine representant la version TP }
Function TPVersionStr(V : Integer) : TString;
Begin
  If V = TP_VER_55 Then
    TPVersionStr := '5.5'
  Else
    TPVersionStr := IntToStr_(V);
End;

{ Retourne un rang sequentiel pour comparer les versions TP }
{ 1->1, 2->2, 4->3, 5->4, 55->5, 6->6, 7->7, 8->8 }
Function TPVersionOrd(V : Integer) : Integer;
Begin
  Case V Of
    1  : TPVersionOrd := 1;
    2  : TPVersionOrd := 2;
    4  : TPVersionOrd := 3;
    5  : TPVersionOrd := 4;
    55 : TPVersionOrd := 5;
    6  : TPVersionOrd := 6;
    7  : TPVersionOrd := 7;
    8  : TPVersionOrd := 8;
  Else
    TPVersionOrd := V;
  End;
End;

{ Retourne True si la version TP courante est >= MinVer }
Function TPVersionAtLeast(MinVer : Integer) : Boolean;
Begin
  TPVersionAtLeast := TPVersionOrd(Opts.TPVersion) >= TPVersionOrd(MinVer);
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('TPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('TPCW32: warning: ', Msg);
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
  Opts.Dos16Mode := False;
  Opts.TPVersion := TP_VER_DEFAULT;
  { Options TPC 7.0 (TODO 25) }
  Opts.BuildAll    := False;
  Opts.Defines     := '';
  Opts.ExeDir      := '';
  Opts.FindErr     := '';
  Opts.MapDetailed := False;
  Opts.MapPublics  := False;
  Opts.MapSegments := False;
  Opts.IncDirs     := '';
  Opts.LinkDisk    := False;
  Opts.MakeUnits   := False;
  Opts.ObjDirs     := '';
  Opts.Quiet       := False;
  Opts.ResDirs     := '';
  Opts.TurboDir    := '';
  Opts.UnitDirs    := '';
  Opts.DebugInfo   := False;
  Opts.CompDir     := '';
  Opts.QuickPascal := False;
  Opts.ApplePascal := False;
  Opts.Sane        := False;
  Opts.DestTarget  := DEST_WIN32;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('TPCW32 v', TPCW32_VERSION, ' (', TPCW32_DATE,
          ') - Compilateur Turbo Pascal vers 80386 (Windows PE 32 bits)');
  WriteLn('TPCW32 - Cette commande permet de lancer le compilateur Turbo ',
          'Pascal pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : TPCW32 [options] <source.pas> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -dos16         Produire un executable DOS 16 bits');
  WriteLn;
  WriteLn('Version Turbo Pascal cible :');
  WriteLn('  -tp1           Turbo Pascal 1');
  WriteLn('  -tp2           Turbo Pascal 2');
  WriteLn('  -tp4           Turbo Pascal 4');
  WriteLn('  -tp5           Turbo Pascal 5');
  WriteLn('  -tp55          Turbo Pascal 5.5');
  WriteLn('  -tp6           Turbo Pascal 6');
  WriteLn('  -tp7           Turbo Pascal 7 (defaut)');
  WriteLn('  -tp8           Turbo Pascal 8');
  WriteLn('  --quickpascal  Mode QuickPascal (support de l''unite MSGraph)');
  WriteLn('  --applepascal  Mode Apple Pascal (support des unites SANE et TRANSCEND)');
  WriteLn('  --sane         Mode SANE seul (sans l''unite TRANSCEND)');
  WriteLn;
  WriteLn('Destination :');
  WriteLn('  -CD            Destination mode DOS reel');
  WriteLn('  -CP            Destination mode protege DOS');
  WriteLn('  -CW            Destination Windows 3.0');
  WriteLn('  -CW32          Destination Windows 32 bits');
  WriteLn('  -CZ80          Destination Zilog Z80');
  WriteLn('  -C6502         Destination MOS 6502');
  WriteLn('  -C6809         Destination Motorola 6809');
  WriteLn('  -C68000        Destination Motorola 68000');
  WriteLn;
  WriteLn('Options compatibles TPC 7.0 :');
  WriteLn('  -B             Build all units (DOS 16 bits seulement)');
  WriteLn('  -D<syms>       Definir des symboles conditionnels');
  WriteLn('  -E<path>       Repertoire EXE et TPU de sortie');
  WriteLn('  -F<size>       Find run-time error (DOS 16 bits seulement)');
  WriteLn('  -GD            Map detaillee');
  WriteLn('  -GP            Map avec publics');
  WriteLn('  -GS            Map avec segments');
  WriteLn('  -I<path>       Repertoires Include');
  WriteLn('  -L             Link buffer sur disque (DOS 16 bits seulement)');
  WriteLn('  -M             Make des unites modifiees (DOS 16 bits seulement)');
  WriteLn('  -O<path>       Repertoires des fichiers Object');
  WriteLn('  -Q             Compilation silencieuse');
  WriteLn('  -R<path>       Repertoires Resource (DOS 16 bits seulement)');
  WriteLn('  -T<path>       Repertoire Turbo (DOS 16 bits seulement)');
  WriteLn('  -U<path>       Repertoires des unites');
  WriteLn('  -V             Informations de debogage dans l''EXE');
  WriteLn('  -$<sw>         Directives de compilateur ($A+, $B-, etc.)');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  TPCW32 hello.pas');
  WriteLn('  TPCW32 hello.pas hello.exe -v');
  WriteLn('  TPCW32 main.pas -asm -tp7');
  WriteLn('  TPCW32 old.pas -tp4 -dos16');
  WriteLn('  TPCW32 program.pas -obj -w');
  WriteLn('  TPCW32 -DDEBUG;TEST hello.pas');
  WriteLn('  TPCW32 -B -dos16 project.pas');
  WriteLn('  TPCW32 -UC:\UNITS -IC:\INC hello.pas');
  WriteLn('  TPCW32 -GD -V hello.pas');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
  UA   : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    UA := StrUpperCase(Arg);

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
    Else If Arg = '-dos16' Then
      Opts.Dos16Mode := True
    Else If Arg = '-tp1' Then
      Opts.TPVersion := TP_VER_1
    Else If Arg = '-tp2' Then
      Opts.TPVersion := TP_VER_2
    Else If Arg = '-tp4' Then
      Opts.TPVersion := TP_VER_4
    Else If Arg = '-tp5' Then
      Opts.TPVersion := TP_VER_5
    Else If Arg = '-tp55' Then
      Opts.TPVersion := TP_VER_55
    Else If Arg = '-tp6' Then
      Opts.TPVersion := TP_VER_6
    Else If Arg = '-tp7' Then
      Opts.TPVersion := TP_VER_7
    Else If Arg = '-tp8' Then
      Opts.TPVersion := TP_VER_8
    Else If (Arg = '--quickpascal') Then
      Opts.QuickPascal := True
    Else If (Arg = '--applepascal') Then
      Opts.ApplePascal := True
    Else If (Arg = '--sane') Then
      Opts.Sane := True
    { Options compatibles TPC 7.0 (TODO 25) }
    Else If (UA = '-B') Then
      Opts.BuildAll := True
    Else If (UA = '-CD') Then
      Opts.DestTarget := DEST_DOSR
    Else If (UA = '-CP') Then
      Opts.DestTarget := DEST_DOSP
    Else If (UA = '-CW32') Then
      Opts.DestTarget := DEST_W32
    Else If (UA = '-CW') Then
      Opts.DestTarget := DEST_WIN30
    Else If (UA = '-CZ80') Then
      Opts.DestTarget := DEST_Z80
    Else If (UA = '-C6502') Then
      Opts.DestTarget := DEST_6502
    Else If (UA = '-C6809') Then
      Opts.DestTarget := DEST_6809
    Else If (UA = '-C68000') Then
      Opts.DestTarget := DEST_68000
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-D') Then
      Opts.Defines := Copy(Arg, 3, Length(Arg) - 2)
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-E') Then
      Opts.ExeDir := Copy(Arg, 3, Length(Arg) - 2)
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-F') Then
      Opts.FindErr := Copy(Arg, 3, Length(Arg) - 2)
    Else If (UA = '-GD') Then
      Opts.MapDetailed := True
    Else If (UA = '-GP') Then
      Opts.MapPublics := True
    Else If (UA = '-GS') Then
      Opts.MapSegments := True
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-I') Then
      Opts.IncDirs := Copy(Arg, 3, Length(Arg) - 2)
    Else If (UA = '-L') Then
      Opts.LinkDisk := True
    Else If (UA = '-M') Then
      Opts.MakeUnits := True
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-O') Then
      Opts.ObjDirs := Copy(Arg, 3, Length(Arg) - 2)
    Else If (UA = '-Q') Then
      Opts.Quiet := True
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-R') Then
      Opts.ResDirs := Copy(Arg, 3, Length(Arg) - 2)
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-T') Then
      Opts.TurboDir := Copy(Arg, 3, Length(Arg) - 2)
    Else If (Length(UA) >= 2) And (Copy(UA,1,2) = '-U') Then
      Opts.UnitDirs := Copy(Arg, 3, Length(Arg) - 2)
    Else If (UA = '-V') Then
      Opts.DebugInfo := True
    Else If (Length(Arg) >= 2) And (Copy(Arg,1,2) = '-$') Then
      Opts.CompDir := Copy(Arg, 3, Length(Arg) - 2)
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
    WriteLn('TPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .pas }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.pas' Then
    WarnMsg('extension attendue .pas, trouvee: ' + Ext);

  { -obj et -dos16 sont mutuellement exclusifs }
  If Opts.ObjOnly And Opts.Dos16Mode Then
    FatalError('-obj et -dos16 sont mutuellement exclusifs');

  { Options DOS 16 bits seulement : avertir si pas en mode -dos16 (TODO 25) }
  If (Not Opts.Dos16Mode) Then
  Begin
    If Opts.BuildAll Then
      WarnMsg('-B (Build all) n''est disponible qu''en mode DOS 16 bits (-dos16)');
    If Opts.FindErr <> '' Then
      WarnMsg('-F (Find error) n''est disponible qu''en mode DOS 16 bits (-dos16)');
    If Opts.LinkDisk Then
      WarnMsg('-L (Link disk) n''est disponible qu''en mode DOS 16 bits (-dos16)');
    If Opts.MakeUnits Then
      WarnMsg('-M (Make units) n''est disponible qu''en mode DOS 16 bits (-dos16)');
    If Opts.ResDirs <> '' Then
      WarnMsg('-R (Resource dirs) n''est disponible qu''en mode DOS 16 bits (-dos16)');
    If Opts.TurboDir <> '' Then
      WarnMsg('-T (Turbo dir) n''est disponible qu''en mode DOS 16 bits (-dos16)');
  End;

  { -Q desactive le mode verbose }
  If Opts.Quiet Then
    Opts.Verbose := False;

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
  WriteLn('TPCW32 v', TPCW32_VERSION, ' (', TPCW32_DATE,
          ') - Compilateur Turbo Pascal -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.AsmOutput Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  WriteLn('TP cible : ', TPVersionStr(Opts.TPVersion));
  If Opts.Dos16Mode Then
    WriteLn('Mode     : DOS 16 bits');
  { Options TPC 7.0 (TODO 25) }
  If Opts.BuildAll Then
    WriteLn('Build    : all units');
  If Opts.Defines <> '' Then
    WriteLn('Defines  : ', Opts.Defines);
  If Opts.ExeDir <> '' Then
    WriteLn('ExeDir   : ', Opts.ExeDir);
  If Opts.FindErr <> '' Then
    WriteLn('FindErr  : ', Opts.FindErr);
  If Opts.MapDetailed Then
    WriteLn('Map      : detailed');
  If Opts.MapPublics Then
    WriteLn('Map      : publics');
  If Opts.MapSegments Then
    WriteLn('Map      : segments');
  If Opts.IncDirs <> '' Then
    WriteLn('Include  : ', Opts.IncDirs);
  If Opts.LinkDisk Then
    WriteLn('Link     : buffer on disk');
  If Opts.MakeUnits Then
    WriteLn('Make     : modified units');
  If Opts.ObjDirs <> '' Then
    WriteLn('ObjDirs  : ', Opts.ObjDirs);
  If Opts.Quiet Then
    WriteLn('Quiet    : yes');
  If Opts.ResDirs <> '' Then
    WriteLn('ResDirs  : ', Opts.ResDirs);
  If Opts.TurboDir <> '' Then
    WriteLn('TurboDir : ', Opts.TurboDir);
  If Opts.UnitDirs <> '' Then
    WriteLn('UnitDirs : ', Opts.UnitDirs);
  If Opts.DebugInfo Then
    WriteLn('Debug    : info in EXE');
  If Opts.CompDir <> '' Then
    WriteLn('Compiler : ', Opts.CompDir);
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
{ TODO 02 - LEXEUR (TOKENS TURBO PASCAL)          [IMPLEMENTE] }
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
    TK_KEYWORD,       { mot-cle Pascal reconnu               }
    TK_OP,            { operateur := + - * / = <> < > etc.   }
    TK_PUNCT          { ponctuation ; , ( ) [ ] . ..         }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;      { valeur textuelle brute             }
    IntVal   : LongInt;      { valeur entiere (TK_INTEGER/CHAR)   }
    RealVal  : Real;         { valeur reelle (TK_REAL)            }
    Line     : Integer;      { ligne source (1-base)              }
    Col      : Integer;      { colonne source (1-base)            }
  End;

Var
  { Lexeur }
  LexSrcF   : Text;          { handle du fichier source           }
  LexOpened : Boolean;        { fichier ouvert ?                   }
  LexLine   : TString;       { ligne courante                     }
  LexLineNo : Integer;        { numero de ligne courante           }
  LexColNo  : Integer;        { colonne courante dans LexLine      }
  LexEOF    : Boolean;        { fin de fichier atteinte ?          }
  CurToken  : TToken;         { token courant                      }

  { TODO 03 : Directives et inclusions }
  DefineTab      : Array[0..63] Of TString;
  DefineCount    : Integer;
  IncSavedFName  : Array[0..7] Of TString;
  IncSavedLine   : Array[0..7] Of TString;
  IncSavedLineNo : Array[0..7] Of Integer;
  IncSavedColNo  : Array[0..7] Of Integer;
  IncSavedEOF    : Array[0..7] Of Boolean;
  IncTop         : Integer;
  LexSrcFName    : TString;
  OptIO          : Boolean;
  OptRange       : Boolean;
  OptBoolEval    : Boolean;
  OptOverflow    : Boolean;
  OptAlign       : Boolean;
  OptNCoprocessor: Boolean;
  OptGen286      : Boolean;
  OptExtSyntax   : Boolean;

{ Forward declarations TODO 03 }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePop; Forward;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES               [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_DATA   = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TOKENS = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF};

  { Prefixes de mangling pour les labels generes }
  TP_STR_PFX  = '_TPK_';   { constantes chaine                    }
  TP_VAR_PFX  = '_TPV_';   { variables                            }
  TP_LBL_PFX  = '_TPL_';   { labels internes                      }
  TP_RT_PFX   = '_TPRT_';  { routines runtime                     }
  TP_STA_PFX  = '_TPST_';  { variables statiques                  }
  TP_ARR_PFX  = '_TPA_';   { tableaux                             }
  TP_REC_PFX  = '_TPR_';   { records                              }
  TP_ENUM_PFX = '_TPE_';   { enumerations                         }
  TP_UNIT_PFX = '_TPU_';   { unites                               }

  { Constantes TPU (TODO 26) }
  TPU_MAGIC      = $54;     { premier octet d un fichier TPU = 'T'   }
  TPU_VER_TP4    = $30;     { '0' = Turbo Pascal 4.0                 }
  TPU_VER_TP5    = $35;     { '5' = Turbo Pascal 5.0                 }
  TPU_VER_TP55   = $36;     { '6' = Turbo Pascal 5.5                 }
  TPU_VER_TP6    = $39;     { '9' = Turbo Pascal 6.0                 }
  TPU_VER_TP7    = $51;     { 'Q' = Turbo Pascal 7.0 mode reel       }
  MAX_USES_UNITS = 32;      { nombre max d unites dans la clause Uses }
  TPU6_HDR_SIZE  = $40;     { taille header TP6 (TPU9)               }
  TPU7_HDR_SIZE  = $60;     { taille header TP7 (TPUQ)               }

  { Constantes QPU (TODO 29) }
  QPU_MAGIC_0    = $4D;     { 'M' - premier octet signature MSQP     }
  QPU_MAGIC_1    = $53;     { 'S' - deuxieme octet                   }
  QPU_MAGIC_2    = $51;     { 'Q' - troisieme octet                  }
  QPU_MAGIC_3    = $50;     { 'P' - quatrieme octet                  }
  QPU_HDR_FIXED  = $20;     { partie fixe de l en-tete QPU (32 octets) }

  { Table des tailles de types Turbo Pascal (Win32, 32 bits) }
  MAX_TP_TYPE_SIZES = 27;

Type
  { Types d entrees dans le pool de donnees }
  TDataKind = (
    DK_STR,     { chaine ASCIIZ (DB 'xxx',0)                         }
    DK_DWORD,   { valeur 32 bits (DD nnn)                             }
    DK_BYTE,    { valeur 8 bits (DB nnn)                              }
    DK_ARRAY,   { tableau (DB ElemCount*ElemSize DUP(0))              }
    DK_RES,     { espace reserve (DB Size DUP(0))                     }
    DK_STRUCT,  { structure/record (DB Size DUP(0))                   }
    DK_ZERO     { espace initialise a zero (DB Size DUP(0))          }
  );

  { Un enregistrement du pool de donnees }
  TDataRec = Record
    LblName   : TString;    { label ASM (ex: _TPK_1, _TPV_x)         }
    Kind      : TDataKind;  { type de donnee                           }
    IntVal    : LongInt;     { valeur entiere (pour DK_DWORD, DK_BYTE) }
    StrVal    : TString;     { contenu chaine (pour DK_STR)            }
    ElemCount : Integer;     { nombre d elements (pour DK_ARRAY)       }
    ElemSize  : Integer;     { taille d un element (pour DK_ARRAY)     }
  End;

  { Taille connue d un type Turbo Pascal }
  TTPSizeInfo = Record
    Name : TString;         { nom du type (Integer, Char, etc.)        }
    Size : Integer;         { taille en octets                          }
  End;

Var
  { Pool de donnees (segment .DATA) }
  DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount  : Integer;

  { Compteur de labels auto-generes }
  LabelGenSeq : Integer;

  { Pool de tokens (pour le parseur futur) }
  TokenPool  : Array[0..MAX_TOKENS - 1] Of TToken;
  TokenCount : Integer;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                    [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_SYM   = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE = 64;   { profondeur max de scopes imbriques          }

  { Prefixes de mangling supplementaires pour les symboles }
  TP_FUNC_PFX = '_TPF_';   { fonctions / procedures               }
  TP_FLD_PFX  = '_TPFL_';  { champs de record                     }

Type
  { Categories de symboles dans la table }
  TSymKind = (
    SK_CONST,       { constante nommee (Const x = 42)              }
    SK_TYPE,        { type defini (Type T = ...)                    }
    SK_VAR,         { variable locale ou globale                    }
    SK_PARAM,       { parametre de procedure/fonction (valeur)      }
    SK_VARPARAM,    { parametre VAR (par reference)                 }
    SK_PROC,        { procedure                                     }
    SK_FUNC,        { fonction                                      }
    SK_FIELD,       { champ de record/objet                        }
    SK_METHOD,      { methode d objet (TP 5.5+)                    }
    SK_UNIT,        { unite importee (Uses)                         }
    SK_LABEL,       { label (Label / Goto)                          }
    SK_PROPERTY     { propriete d objet (TP8+, stub futur)         }
  );

  { Un enregistrement de la table des symboles }
  TSymRec = Record
    Name        : TString;     { nom original (majuscules)              }
    MangledName : TString;     { nom mangled pour emission ASM          }
    Kind        : TSymKind;    { categorie du symbole                   }
    TypeIdx     : Integer;     { index du type dans TypeTab (-1=aucun)  }
    Offset      : Integer;     { offset stack ou data segment           }
    ScopeLevel  : Integer;     { niveau de scope (0 = global)           }
    ScopeId     : Integer;     { id unique du scope                     }
    IsGlobal    : Boolean;     { visible globalement ?                  }
    IsExternal  : Boolean;     { declare dans une unite externe ?       }
    UnitName    : TString;     { nom de l unite d origine (ou '')       }
    ImmVal      : LongInt;     { valeur immediate (const, enum)         }
    ParamCount  : Integer;     { nombre de parametres (proc/func)       }
    IsAbsolute  : Boolean;     { variable absolute $Seg:$Ofs (TODO 28)  }
    AbsSeg      : LongInt;     { segment absolute (ex: $0040)           }
    AbsOfs      : LongInt;     { offset absolute (ex: $0013)            }
  End;

  { Info sur une unite importee (TODO 26, TODO 29) }
  TTPUInfo = Record
    Name      : TString;    { nom de l unite (majuscules)             }
    FileName  : TString;    { chemin complet du fichier TPU/QPU       }
    Version   : Byte;       { version TPU detectee (octet 4)           }
    Loaded    : Boolean;    { True si le fichier TPU/QPU a ete lu     }
    IsKnown   : Boolean;    { True si c est une unite connue (Crt...) }
    IsQPU     : Boolean;    { True si c est un fichier QPU (Quick Pascal) }
  End;

Var
  { Table des symboles }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount    : Integer;

  { Gestion des portees }
  CurScopeLevel : Integer;   { niveau de scope courant (0 = global)    }
  CurScopeId    : Integer;   { id du scope courant                     }
  ScopeIdSeq    : Integer;   { sequence pour generer des ids uniques    }

  { Table des unites importees (TODO 26) }
  UsesUnits    : Array[0..MAX_USES_UNITS - 1] Of TTPUInfo;
  UsesCount    : Integer;

{ Forward declarations TODO 05 }
Procedure SymRegisterBuiltins; Forward;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                      [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_TYPE   = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FIELDS = 64;    { nombre max de champs dans un record/objet  }
  MAX_ENUMS  = 256;   { nombre max de valeurs enum                 }

  { Index des types primitifs (fixes dans TypeTab) }
  TY_UNKNOWN     = -1;  { type inconnu / pas encore defini           }
  TY_IDX_INTEGER =  0;  { Integer  (LongInt 32 bits signe)           }
  TY_IDX_WORD    =  1;  { Word     (32 bits non signe en Win32)      }
  TY_IDX_BYTE    =  2;  { Byte     (8 bits non signe)                }
  TY_IDX_SHORTINT=  3;  { ShortInt (8 bits signe)                    }
  TY_IDX_CHAR    =  4;  { Char     (8 bits)                          }
  TY_IDX_BOOLEAN =  5;  { Boolean  (8 bits, 0 ou 1)                  }
  TY_IDX_STRING  =  6;  { String   (ShortString: 1+255 octets)       }
  TY_IDX_REAL    =  7;  { Real     (6 octets, format Turbo Pascal)   }
  TY_IDX_SINGLE  =  8;  { Single   (flottant 32 bits)                }
  TY_IDX_DOUBLE  =  9;  { Double   (flottant 64 bits)                }
  TY_IDX_EXTENDED= 10;  { Extended (flottant 80 bits)                }
  TY_IDX_COMP    = 11;  { Comp     (entier 64 bits virgule fixe)     }
  TY_IDX_POINTER = 12;  { Pointer  (pointeur generique 32 bits)      }
  TY_IDX_PCHAR   = 13;  { PChar    (pointeur vers Char)              }
  TY_IDX_TEXT    = 14;  { Text     (handle fichier texte)            }
  TY_IDX_NIL     = 15;  { nil      (constante pointeur nul)          }
  TY_IDX_LONGINT = 16;  { LongInt  (alias de Integer en Win32)       }
  TY_IDX_LONGWORD= 17;  { LongWord (TP8+, 32 bits non signe)        }
  TY_PRIM_COUNT  = 18;  { nombre de types primitifs                  }

Type
  { Categories de types dans la table }
  TTypeKind = (
    TYK_INTEGER,    { entier signe 32 bits (Integer, LongInt)        }
    TYK_WORD,       { entier non signe 32 bits (Word)                }
    TYK_BYTE,       { entier non signe 8 bits (Byte)                 }
    TYK_SHORTINT,   { entier signe 8 bits (ShortInt)                 }
    TYK_CHAR,       { caractere 8 bits (Char)                        }
    TYK_BOOLEAN,    { booleen 8 bits (Boolean)                       }
    TYK_STRING,     { chaine courte ShortString (String[n])          }
    TYK_REAL,       { reel (stub entier en Win32)                    }
    TYK_SINGLE,     { flottant IEEE 32 bits                          }
    TYK_DOUBLE,     { flottant IEEE 64 bits                          }
    TYK_EXTENDED,   { flottant etendu 80 bits                        }
    TYK_COMP,       { entier 64 bits virgule fixe                    }
    TYK_POINTER,    { pointeur generique 32 bits                     }
    TYK_PCHAR,      { pointeur vers Char (PChar)                     }
    TYK_ARRAY,      { tableau (ARRAY [lo..hi] OF T)                  }
    TYK_RECORD,     { record (RECORD ... END)                        }
    TYK_SET,        { ensemble (SET OF T)                            }
    TYK_ENUM,       { enumeration (TYPE T = (a, b, c))               }
    TYK_FILE,       { fichier (File / File of T)                     }
    TYK_TEXT,       { fichier texte (Text)                           }
    TYK_OBJECT,     { objet TP 5.5+ (OBJECT ... END)                }
    TYK_NIL,        { constante nil                                   }
    TYK_SUBRANGE,   { sous-intervalle (lo..hi)                       }
    TYK_PROCVAR     { variable de type procedure/fonction            }
  );

  { Un champ de record ou d objet }
  TFieldRec = Record
    Name    : TString;     { nom du champ                              }
    TypeIdx : Integer;     { index du type dans TypeTab                }
    Offset  : Integer;     { offset en octets depuis le debut du record}
  End;

  { Un enregistrement de la table des types }
  TTypeRec = Record
    Kind        : TTypeKind;   { categorie du type                     }
    Name        : TString;     { nom du type ('' si anonyme)           }
    Size        : Integer;     { taille en octets                      }
    Align       : Integer;     { alignement en octets                  }
    BaseTypeIdx : Integer;     { type de base (pointeur, tableau, alias)}
    Lo          : LongInt;     { borne inferieure (subrange, array)    }
    Hi          : LongInt;     { borne superieure (subrange, array)    }
    FieldCount  : Integer;     { nombre de champs (record, objet)      }
    Fields      : Array[0..MAX_FIELDS - 1] Of TFieldRec;
    EnumCount   : Integer;     { nombre de valeurs (enum)              }
    IsPacked    : Boolean;     { type PACKED ?                         }
    IsUnsigned  : Boolean;     { type non signe ?                      }
  End;

Var
  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { WITH statement : pile de variables-record en cours }
  WithVarName  : Array[0..7] Of TString; { nom de la variable record   }
  WithVarPI    : Array[0..7] Of Integer; { index proc (PI) du WITH     }
  WithTypeIdx  : Array[0..7] Of Integer; { TypeIdx du record            }
  WithDepth    : Integer;                { profondeur WITH (0 = aucun)  }

{ Forward declarations TODO 06 }
Procedure TypeInit; Forward;
Function  TypeSizeofIdx(Idx : Integer) : Integer; Forward;
Function  TypeFindByName(Const AName : TString) : Integer; Forward;
Function  TypeResolve(Idx : Integer) : Integer; Forward;
Function  TypeIsOrdinal(Idx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(Idx : Integer) : Boolean; Forward;
Function  TypeIsPointer(Idx : Integer) : Boolean; Forward;
Function  TypeCoerce(IdxA, IdxB : Integer) : Integer; Forward;
Function  TypeCompatible(IdxDest, IdxSrc : Integer) : Boolean; Forward;

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : mots-cles Turbo Pascal                           }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
  R : Boolean;
Begin
  L := StrLowerCase(S);
  R :=
    (L = 'and')         Or (L = 'array')      Or (L = 'asm')        Or
    (L = 'begin')       Or (L = 'case')       Or (L = 'const')      Or
    (L = 'div')         Or (L = 'do')         Or (L = 'downto')     Or
    (L = 'else')        Or (L = 'end')        Or (L = 'file')       Or
    (L = 'for')         Or (L = 'function')   Or (L = 'goto')       Or
    (L = 'if')          Or (L = 'implementation') Or
    (L = 'in')          Or (L = 'inline')     Or (L = 'interface')  Or
    (L = 'label')       Or (L = 'mod')        Or (L = 'nil')        Or
    (L = 'not')         Or (L = 'of')         Or (L = 'or')         Or
    (L = 'packed')      Or (L = 'procedure')  Or (L = 'program')    Or
    (L = 'record')      Or (L = 'repeat')     Or (L = 'set')        Or
    (L = 'shl')         Or (L = 'shr')        Or (L = 'string')     Or
    (L = 'then')        Or (L = 'to')         Or (L = 'type')       Or
    (L = 'until')       Or
    (L = 'var')         Or (L = 'while')      Or (L = 'with')       Or
    (L = 'xor');
  { Mots-cles UNIT et USES : disponibles a partir de TP 4+ seulement (TODO 27) }
  If (Not R) And TPVersionAtLeast(TP_VER_4) Then
    R := (L = 'unit') Or (L = 'uses');
  { Mots-cles supplementaires TP5.5+ }
  If (Not R) And TPVersionAtLeast(TP_VER_55) Then
    R :=
      (L = 'inherited')   Or (L = 'constructor') Or
      (L = 'destructor')  Or (L = 'object');
  { Mot-cle Apple Pascal : SEGMENT (overlay, ignore en Win32) }
  If (Not R) And Opts.ApplePascal Then
    R := (L = 'segment');
  IsKeyword := R;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T : TToken);
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
    { Si on est dans un fichier inclus, depiler }
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

{ Sauter commentaire // jusqu a fin de ligne (TP7+) }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ Sauter commentaire accolade ou traiter directive {$ }
Procedure LexSkipBraceComment;
Begin
  { Detecter {$ : directive de compilation }
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
  { Mots-cles Pascal : stocker en minuscules normalisees }
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
{ Gere decimaux, reels (3.14, 1.5E3), token '..' vs '.'       }
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
{ LexScanHexNumber : $FF, $FFFF, $FFFFFFFF                    }
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
{ LexScanString : chaine Pascal entre apostrophes              }
{ Gere le doublement de quote : 'l''echo' -> l'echo            }
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
      { Quote doublee '' -> un seul caractere ' }
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
  { Si suivi de #nn, concatener }
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
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ------------------------------------------------------------ }
{ LexScanCharLit : caractere #nn ou #$nn                       }
{ Gere aussi les sequences #13#10 et #13#10'text'              }
{ ------------------------------------------------------------ }

Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
  Ch : Char;
Begin
  S := '';
  { Scanner une sequence de #nn segments et concatener }
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
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
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
    Begin
      Inc(LexColNo);
    End

    { Commentaire // ligne (TP7+) }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') And
            TPVersionAtLeast(TP_VER_7) Then
    Begin
      LexSkipLineComment;
    End

    { Commentaire accolade }
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire (* ... *) ou operateur '(' }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipParenStarComment;
    End

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
{ TODO 03 - PREPROCESSEUR ET DIRECTIVES          [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_DEFINE  = 64;    { nombre max de symboles de compilation }
  MAX_INCLUDE = 8;     { profondeur max d inclusion }

{ ---- DefineDefined : teste si un symbole est defini ---- }
Function DefineDefined(Const Name : TString) : Boolean;
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
Procedure DefineAdd(Const Name : TString);
Var
  N : TString;
Begin
  N := StrUpperCase(Name);
  If DefineDefined(N) Then Exit;
  If DefineCount >= MAX_DEFINE Then
  Begin
    WarnMsg('trop de symboles $DEFINE (max ' +
            IntToStr_(MAX_DEFINE) + ')');
    Exit;
  End;
  DefineTab[DefineCount] := N;
  Inc(DefineCount);
End;

{ ---- DefineRemove : supprimer un symbole ---- }
Procedure DefineRemove(Const Name : TString);
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
Procedure IncludePush(Const FileName : TString);
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
  I : Integer;
  Dummy : TString;
Begin
  If IncTop < 0 Then Exit;
  Close(LexSrcF);
  { Rouvrir le fichier precedent et avancer jusqu a la bonne ligne }
  Assign(LexSrcF, IncSavedFName[IncTop]);
  Reset(LexSrcF);
  For I := 1 To IncSavedLineNo[IncTop] Do
  Begin
    If Not EOF(LexSrcF) Then
      ReadLn(LexSrcF, Dummy);
  End;
  LexSrcFName := IncSavedFName[IncTop];
  LexLine     := IncSavedLine[IncTop];
  LexLineNo   := IncSavedLineNo[IncTop];
  LexColNo    := IncSavedColNo[IncTop];
  LexEOF      := IncSavedEOF[IncTop];
  Dec(IncTop);
End;

{ ---- LexSkipCondFalse : sauter le code dans un IFDEF faux ---- }
{ Saute jusqu a trouver $ELSE ou $ENDIF au meme niveau }
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
        Else If Dir = 'ENDIF' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then
          Begin
            { Trouver l accolade fermante }
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

(* ---- LexHandleDollarDirective : traiter dollar-directives *)
(* Appelee quand LexColNo pointe sur accolade et le suivant est dollar *)
(* Gere: I/INCLUDE, DEFINE, UNDEF, IFDEF, IFNDEF, IFOPT, *)
(* ELSE, ENDIF, et les commutations I+/I-/R+/R-/etc. *)
Procedure LexHandleDollarDirective;
Var
  Dir  : TString;
  Arg  : TString;
  Sw   : Char;
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

  (* Detecter commutateurs une lettre : dollar I+ / dollar R- etc. *)
  (* Si Dir est une seule lettre et le char courant est +/- *)
  If (Length(Dir) = 1) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
  Begin
    Sw := LexLine[LexColNo];
    Inc(LexColNo);
    { Consommer jusqu a accolade fermante }
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
      Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
      Inc(LexColNo);
    { Appliquer la commutation }
    Case Dir[1] Of
      'I' : OptIO          := (Sw = '+');
      'R' : OptRange       := (Sw = '+');
      'B' : OptBoolEval    := (Sw = '+');
      'Q' : OptOverflow    := (Sw = '+');
      'A' : OptAlign       := (Sw = '+');
      'N' : OptNCoprocessor:= (Sw = '+');
      'G' : OptGen286      := (Sw = '+');
      'X' : OptExtSyntax   := (Sw = '+');
    End;
    Exit;
  End;

  { Sauter espaces }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] = ' ') Do
    Inc(LexColNo);
  { Lire l argument jusqu a accolade fermante }
  Arg := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') Do
  Begin
    Arg := Arg + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  { Supprimer espaces de fin }
  While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
    Delete(Arg, Length(Arg), 1);
  { Consommer accolade fermante }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
    Inc(LexColNo);

  { Dispatcher les directives }
  If (Dir = 'I') Or (Dir = 'INCLUDE') Then
  Begin
    { Supprimer quotes eventuelles }
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
  Begin
    DefineAdd(Arg);
    { Activer les options de mode si le symbole correspond }
    If StrUpperCase(Arg) = 'QUICKPASCAL' Then
      Opts.QuickPascal := True
    Else If StrUpperCase(Arg) = 'APPLEPASCAL' Then
      Opts.ApplePascal := True
    Else If StrUpperCase(Arg) = 'SANE' Then
      Opts.Sane := True;
  End
  Else If Dir = 'UNDEF' Then
    DefineRemove(Arg)
  Else If Dir = 'IFDEF' Then
  Begin
    If DefineDefined(Arg) Then
      { Condition vraie : on ne fait rien }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'IFNDEF' Then
  Begin
    If Not DefineDefined(Arg) Then
      { Condition vraie : compiler }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'IFOPT' Then
  Begin
    { $IFOPT X+ : tester l etat d une option }
    { Format Arg = 'X+' ou 'X-' }
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
          'N' : If Not OptNCoprocessor Then LexSkipCondFalse;
          'G' : If Not OptGen286 Then LexSkipCondFalse;
          'X' : If Not OptExtSyntax Then LexSkipCondFalse;
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
          'N' : If OptNCoprocessor Then LexSkipCondFalse;
          'G' : If OptGen286 Then LexSkipCondFalse;
          'X' : If OptExtSyntax Then LexSkipCondFalse;
        Else
          LexSkipCondFalse;
        End;
      End;
    End
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'ELSE' Then
  Begin
    { On est dans la branche vraie, sauter jusqu a $ENDIF }
    LexSkipCondFalse;
  End
  Else If Dir = 'ENDIF' Then
  Begin
    { Fin de bloc conditionnel, rien a faire }
  End;
  { Autres directives ($L, $M, $S, etc.) : ignorees silencieusement }
End;

{ ---- PPInitDefines : initialiser symboles predefinis ---- }
Procedure PPInitDefines;
Begin
  DefineCount := 0;
  IncTop      := -1;

  { Options de commutation par defaut (TP7) }
  OptIO          := True;   { $I+ }
  OptRange       := False;  { $R- }
  OptBoolEval    := False;  { $B- court-circuit }
  OptOverflow    := False;  { $Q- }
  OptAlign       := True;   { $A+ }
  OptNCoprocessor:= False;  { $N- }
  OptGen286      := False;  { $G- }
  OptExtSyntax   := True;   { $X+ en TP7 }

  { Symbole WIN32 toujours defini dans TPCW32 }
  DefineAdd('WIN32');

  { Symboles MSDOS, CPU86, CPU87 }
  DefineAdd('MSDOS');
  DefineAdd('CPU86');
  DefineAdd('CPU87');

  { Symboles de version selon TPVersion }
  If TPVersionAtLeast(TP_VER_1) Then DefineAdd('VER10');
  If TPVersionAtLeast(TP_VER_2) Then DefineAdd('VER20');
  If TPVersionAtLeast(TP_VER_4) Then DefineAdd('VER40');
  If TPVersionAtLeast(TP_VER_5) Then DefineAdd('VER50');
  If TPVersionAtLeast(TP_VER_55) Then DefineAdd('VER55');
  If TPVersionAtLeast(TP_VER_6) Then DefineAdd('VER60');
  If TPVersionAtLeast(TP_VER_7) Then DefineAdd('VER70');
  If TPVersionAtLeast(TP_VER_8) Then DefineAdd('VER80');
End;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES               [IMPLEMENTE] }
{ ============================================================ }

{ ---- Table des tailles de types Turbo Pascal (Win32) ---- }
Const
  TPTypeSizes : Array[0..MAX_TP_TYPE_SIZES - 1] Of TTPSizeInfo = (
    (Name: 'INTEGER';   Size: 4),   { LongInt 32 bits en Win32          }
    (Name: 'LONGINT';   Size: 4),   { LongInt 32 bits                   }
    (Name: 'WORD';      Size: 4),   { elargi a 32 bits en Win32         }
    (Name: 'BYTE';      Size: 1),   { 8 bits non signe                  }
    (Name: 'SHORTINT';  Size: 1),   { 8 bits signe                      }
    (Name: 'CHAR';      Size: 1),   { caractere 8 bits                  }
    (Name: 'BOOLEAN';   Size: 1),   { booleen 8 bits                    }
    (Name: 'STRING';    Size: 256), { ShortString (255+1 longueur)      }
    (Name: 'REAL';      Size: 4),   { stub entier, 4 octets en Win32    }
    (Name: 'SINGLE';    Size: 4),   { flottant 32 bits                  }
    (Name: 'DOUBLE';    Size: 8),   { flottant 64 bits                  }
    (Name: 'EXTENDED';  Size: 10),  { flottant 80 bits                  }
    (Name: 'COMP';      Size: 8),   { entier 64 bits en virgule fixe    }
    (Name: 'POINTER';   Size: 4),   { pointeur generique 32 bits        }
    (Name: 'PCHAR';     Size: 4),   { pointeur vers Char                }
    (Name: 'TEXT';      Size: 4),   { handle fichier texte              }
    (Name: 'FILE';      Size: 4),   { handle fichier                    }
    (Name: 'LONGWORD';  Size: 4),   { mot 32 bits non signe (TP8)       }
    { Types de l unite Dos }
    (Name: 'DIRSTR';   Size: 68),  { String[67] + length byte          }
    (Name: 'NAMESTR';  Size: 9),   { String[8]  + length byte          }
    (Name: 'EXTSTR';   Size: 5),   { String[4]  + length byte          }
    (Name: 'PATHSTR';  Size: 80),  { String[79] + length byte          }
    (Name: 'COMSTR';   Size: 128), { String[127]+ length byte          }
    (Name: 'DATETIME'; Size: 12),  { record 6 x Word = 12 octets      }
    { Type QuickPascal }
    (Name: 'CSTRING';  Size: 256), { CSTRING : String + nul terminal   }
    { Types Apple Pascal }
    (Name: 'BYTESTREAM'; Size: 256), { ByteStream : Array[0..255] of Char  }
    (Name: 'WORDSTREAM'; Size: 256)  { WordStream : Array[0..63] of Integer}
  );

{ ---- DataInit : initialiser le pool de donnees ---- }
Procedure DataInit;
Var I : Integer;
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
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString;
                 AElemCount : Integer; AElemSize : Integer) : Integer;
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
{ Retourne le label (ex: _TPK_1) }
Function DataAddStr(Const S : TString) : TString;
Var Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := TP_STR_PFX + IntToStr_(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S, 0, 0);
  DataAddStr := Lbl;
End;

{ ---- DataAddDWord : ajouter une valeur 32 bits avec label ---- }
Function DataAddDWord(Const Lbl : TString; Val : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, Val, '', 0, 0);
End;

{ ---- DataAddByte : ajouter une valeur 8 bits avec label ---- }
Function DataAddByte(Const Lbl : TString; Val : Integer) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, Val, '', 0, 0);
End;

{ ---- DataAddArray : ajouter un tableau avec label ---- }
Function DataAddArray(Const Lbl : TString;
                      AElemCount : Integer;
                      AElemSize : Integer) : Integer;
Begin
  DataAddArray := DataAdd(Lbl, DK_ARRAY, 0, '', AElemCount, AElemSize);
End;

{ ---- DataAddRes : ajouter un espace reserve avec label ---- }
Function DataAddRes(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddRes := DataAdd(Lbl, DK_RES, Size, '', 0, 0);
End;

{ ---- DataAddStruct : ajouter un record/structure ---- }
Function DataAddStruct(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddStruct := DataAdd(Lbl, DK_STRUCT, Size, '', 0, 0);
End;

{ ---- DataAddZero : ajouter un espace initialise a zero ---- }
Function DataAddZero(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddZero := DataAdd(Lbl, DK_ZERO, Size, '', 0, 0);
End;

{ ---- DataFindStr : rechercher si une chaine est deja dans le pool ---- }
{ Retourne l index ou -1 si absente }
Function DataFindStr(Const S : TString) : Integer;
Var I : Integer;
Begin
  DataFindStr := -1;
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataFindStr := I;
      Exit;
    End;
End;

{ ---- DataGetOrAddStr : retourne le label d une chaine existante ---- }
{ ou l ajoute si elle n existe pas encore (deduplication) }
Function DataGetOrAddStr(Const S : TString) : TString;
Var Idx : Integer;
Begin
  Idx := DataFindStr(S);
  If Idx >= 0 Then
    DataGetOrAddStr := DataTab[Idx].LblName
  Else
    DataGetOrAddStr := DataAddStr(S);
End;

{ ---- TPTypeSizeof : retourne la taille d un type TP de base ---- }
{ Retourne -1 si le type est inconnu }
Function TPTypeSizeof(Const TypeName : TString) : Integer;
Var
  I : Integer;
  N : TString;
Begin
  TPTypeSizeof := -1;
  N := StrUpperCase(TypeName);
  For I := 0 To MAX_TP_TYPE_SIZES - 1 Do
    If TPTypeSizes[I].Name = N Then
    Begin
      TPTypeSizeof := TPTypeSizes[I].Size;
      Exit;
    End;
  { Pointeur : tout type ^xxx a la taille d un pointeur }
  If (Length(N) > 1) And (N[1] = '^') Then
  Begin
    TPTypeSizeof := 4;  { 32 bits }
    Exit;
  End;
End;

{ ---- ConstEvalExpr : evaluer une expression constante TP ---- }
{ Supporte : entiers, hex, Ord, Chr, SizeOf, MaxInt, True, False, Nil }
{ Operateurs : + - * DIV MOD AND OR XOR NOT SHL SHR ( )  }

Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
  Forward;

Function ConstEvalAtom(Const S : TString; Var Pos : Integer) : LongInt;
Var
  N   : LongInt;
  Neg : Boolean;
  Id  : TString;
  Sz  : Integer;
  Arg : TString;
  Depth : Integer;
Begin
  N := 0;

  { Sauter les blancs }
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
    Inc(Pos);

  If Pos > Length(S) Then
  Begin
    ConstEvalAtom := 0;
    Exit;
  End;

  { Operateur unaire - }
  Neg := False;
  If (Pos <= Length(S)) And (S[Pos] = '-') Then
  Begin
    Neg := True;
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { Operateur unaire + }
  If (Pos <= Length(S)) And (S[Pos] = '+') Then
  Begin
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { NOT : operateur unaire TP }
  If (Pos + 2 <= Length(S)) And
     (UpCase(S[Pos]) = 'N') And (UpCase(S[Pos+1]) = 'O') And
     (UpCase(S[Pos+2]) = 'T') And
     ((Pos + 3 > Length(S)) Or Not IsIdentCont(S[Pos+3])) Then
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
    If (Pos <= Length(S)) And (S[Pos] = '$') Then
    Begin
      { Hex char #$41 }
      Inc(Pos);
      N := 0;
      While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
      Begin
        N := N * 16 + HexVal(S[Pos]);
        Inc(Pos);
      End;
    End
    Else
    Begin
      { Decimal char #65 }
      N := 0;
      While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
      Begin
        N := N * 10 + (Ord(S[Pos]) - Ord('0'));
        Inc(Pos);
      End;
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Chaine un caractere 'A' -> Ord('A') }
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

  { Nombre decimal }
  If (Pos <= Length(S)) And IsDigit(S[Pos]) Then
  Begin
    N := 0;
    While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
    Begin
      N := N * 10 + (Ord(S[Pos]) - Ord('0'));
      Inc(Pos);
    End;
    { Ignorer la partie decimale pour les reels }
    If (Pos <= Length(S)) And (S[Pos] = '.') Then
    Begin
      Inc(Pos);
      While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
        Inc(Pos);
      { Ignorer exposant }
      If (Pos <= Length(S)) And (UpCase(S[Pos]) = 'E') Then
      Begin
        Inc(Pos);
        If (Pos <= Length(S)) And ((S[Pos] = '+') Or (S[Pos] = '-')) Then
          Inc(Pos);
        While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
          Inc(Pos);
      End;
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Identificateur : mot-cle ou constante nommee }
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

    { Constantes predefinies }
    If Id = 'TRUE' Then N := 1
    Else If Id = 'FALSE' Then N := 0
    Else If Id = 'NIL' Then N := 0
    Else If Id = 'MAXINT' Then N := 32767
    Else If Id = 'MAXLONGINT' Then N := 2147483647

    { Fonctions de conversion }
    Else If Id = 'ORD' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'CHR' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        N := N And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'SIZEOF' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        { Lire le nom du type comme argument }
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
            If Depth = 0 Then
            Begin
              Inc(Pos);
              Break;
            End;
          End;
          Arg := Arg + S[Pos];
          Inc(Pos);
        End;
        { Supprimer espaces de fin }
        While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
          Delete(Arg, Length(Arg), 1);
        Sz := TPTypeSizeof(Arg);
        If Sz >= 0 Then
          N := Sz
        Else
          N := 4;  { taille par defaut pour types inconnus (32 bits) }
      End;
    End
    Else If Id = 'SUCC' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) + 1;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'PRED' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) - 1;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'ABS' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        If N < 0 Then N := -N;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'LO' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'HI' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := (ConstEvalExpr(S, Pos) Shr 8) And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'SWAP' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        N := ((N And $FF) Shl 8) Or ((N Shr 8) And $FF);
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else
      N := 0;  { identificateur inconnu : 0 par defaut }

    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Par defaut }
  ConstEvalAtom := 0;
End;

{ ---- ConstEvalExpr : evaluer une expression constante entiere ---- }
{ Operateurs TP : + - * DIV MOD AND OR XOR SHL SHR = <> < > <= >= }
Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
Var
  L, R : LongInt;
  Op   : TString;
Begin
  L := ConstEvalAtom(S, Pos);

  While Pos <= Length(S) Do
  Begin
    { Sauter blancs }
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
    If Pos > Length(S) Then Break;

    { Detecter l operateur }
    Op := '';
    If S[Pos] = '+' Then Begin Op := '+'; Inc(Pos); End
    Else If S[Pos] = '-' Then Begin Op := '-'; Inc(Pos); End
    Else If S[Pos] = '*' Then Begin Op := '*'; Inc(Pos); End
    Else If (S[Pos] = '<') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '>') Then
      Begin Op := '<>'; Inc(Pos, 2); End
    Else If (S[Pos] = '<') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '=') Then
      Begin Op := '<='; Inc(Pos, 2); End
    Else If (S[Pos] = '>') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '=') Then
      Begin Op := '>='; Inc(Pos, 2); End
    Else If S[Pos] = '<' Then Begin Op := '<'; Inc(Pos); End
    Else If S[Pos] = '>' Then Begin Op := '>'; Inc(Pos); End
    Else If S[Pos] = '=' Then Begin Op := '='; Inc(Pos); End
    Else If IsIdentStart(S[Pos]) Then
    Begin
      { Mots-cles operateurs : DIV, MOD, AND, OR, XOR, SHL, SHR }
      Op := '';
      While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
      Begin
        Op := Op + UpCase(S[Pos]);
        Inc(Pos);
      End;
      If (Op <> 'DIV') And (Op <> 'MOD') And (Op <> 'AND') And
         (Op <> 'OR') And (Op <> 'XOR') And (Op <> 'SHL') And
         (Op <> 'SHR') Then
      Begin
        { Pas un operateur connu, reculer }
        Dec(Pos, Length(Op));
        Break;
      End;
    End
    Else
      Break;  { pas un operateur reconnu }

    R := ConstEvalAtom(S, Pos);

    If Op = '+' Then L := L + R
    Else If Op = '-' Then L := L - R
    Else If Op = '*' Then L := L * R
    Else If Op = 'DIV' Then
    Begin
      If R <> 0 Then L := L Div R Else L := 0;
    End
    Else If Op = 'MOD' Then
    Begin
      If R <> 0 Then L := L Mod R Else L := 0;
    End
    Else If Op = 'AND' Then L := L And R
    Else If Op = 'OR' Then L := L Or R
    Else If Op = 'XOR' Then L := L Xor R
    Else If Op = 'SHL' Then L := L Shl R
    Else If Op = 'SHR' Then L := L Shr R
    Else If Op = '=' Then Begin If L = R Then L := 1 Else L := 0; End
    Else If Op = '<>' Then Begin If L <> R Then L := 1 Else L := 0; End
    Else If Op = '<' Then Begin If L < R Then L := 1 Else L := 0; End
    Else If Op = '>' Then Begin If L > R Then L := 1 Else L := 0; End
    Else If Op = '<=' Then Begin If L <= R Then L := 1 Else L := 0; End
    Else If Op = '>=' Then Begin If L >= R Then L := 1 Else L := 0; End;
  End;

  ConstEvalExpr := L;
End;

{ ---- ConstEval : evaluer une expression constante complete ---- }
{ Encapsulation avec initialisation de Pos }
Function ConstEval(Const S : TString) : LongInt;
Var P : Integer;
Begin
  P := 1;
  ConstEval := ConstEvalExpr(S, P);
End;

{ ---- TokenPoolInit : initialiser le pool de tokens ---- }
Procedure TokenPoolInit;
Begin
  TokenCount := 0;
End;

{ ---- TokenPoolAdd : ajouter un token dans le pool ---- }
Procedure TokenPoolAdd(Const T : TToken);
Begin
  If TokenCount >= MAX_TOKENS Then
  Begin
    WarnMsg('pool de tokens plein');
    Exit;
  End;
  TokenPool[TokenCount] := T;
  Inc(TokenCount);
End;

{ ---- TokenPoolRegisterStrings : enregistrer toutes les chaines ---- }
{ du pool de tokens dans le pool de donnees, en evitant les doublons }
Procedure TokenPoolRegisterStrings;
Var I : Integer;
Begin
  For I := 0 To TokenCount - 1 Do
  Begin
    If TokenPool[I].Kind = TK_STRING Then
      DataGetOrAddStr(TokenPool[I].Val);
  End;
End;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                    [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles                  }
{ ------------------------------------------------------------ }

Procedure SymInit;
Var I : Integer;
Begin
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := -1;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].ScopeId     := 0;
    SymTab[I].IsGlobal    := False;
    SymTab[I].IsExternal  := False;
    SymTab[I].UnitName    := '';
    SymTab[I].ImmVal      := 0;
    SymTab[I].ParamCount  := 0;
    SymTab[I].IsAbsolute  := False;
    SymTab[I].AbsSeg      := 0;
    SymTab[I].AbsOfs      := 0;
  End;
  SymRegisterBuiltins;
End;

{ ------------------------------------------------------------ }
{ SymMangle : generer un nom mangled pour un symbole           }
{ selon sa categorie                                           }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Begin
  Case Kind Of
    SK_CONST    : SymMangle := TP_VAR_PFX + Name;
    SK_TYPE     : SymMangle := Name;
    SK_VAR      : SymMangle := TP_VAR_PFX + Name;
    SK_PARAM    : SymMangle := TP_VAR_PFX + Name;
    SK_PROC     : SymMangle := TP_FUNC_PFX + Name;
    SK_FUNC     : SymMangle := TP_FUNC_PFX + Name;
    SK_FIELD    : SymMangle := TP_FLD_PFX + Name;
    SK_METHOD   : SymMangle := TP_FUNC_PFX + Name;
    SK_UNIT     : SymMangle := Name;
    SK_LABEL    : SymMangle := TP_LBL_PFX + Name;
    SK_PROPERTY : SymMangle := Name;
  Else
    SymMangle := TP_VAR_PFX + Name;
  End;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : chercher un symbole dans un scope precis    }
{ Retourne l index ou -1 si non trouve                         }
{ Comparaison insensible a la casse (Turbo Pascal)             }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].ScopeLevel = Level) And
       ((Level = 0) Or (SymTab[I].ScopeId = CurScopeId)) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole du scope courant vers global   }
{ Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ------------------------------------------------------------ }
{ SymFindInUnit : chercher un symbole qualifie par unite        }
{ Ex: Crt.ClrScr -> chercher ClrScr avec UnitName='CRT'       }
{ ------------------------------------------------------------ }

Function SymFindInUnit(Const UName, Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
  UU : TString;
Begin
  Up := StrUpperCase(Name);
  UU := StrUpperCase(UName);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].UnitName = UU) Then
    Begin
      SymFindInUnit := I;
      Exit;
    End;
  End;
  SymFindInUnit := -1;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                    }
{ Retourne l index du symbole ajoute, ou -1 si erreur          }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TIdx : Integer) : Integer;
Var
  Up  : TString;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' +
      IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Up := StrUpperCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Up, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Permettre la redefinition d une forward declaration }
    If SymTab[Dup].IsExternal And
       (Kind In [SK_PROC, SK_FUNC, SK_VAR]) Then
    Begin
      SymTab[Dup].Kind       := Kind;
      SymTab[Dup].TypeIdx    := TIdx;
      SymTab[Dup].IsExternal := False;
      SymAdd := Dup;
      Exit;
    End
    { Permettre qu un proc/func masque un type pre-declare }
    Else If (SymTab[Dup].Kind = SK_TYPE) And
            (Kind In [SK_PROC, SK_FUNC, SK_VAR]) Then
    Begin
      { On laisse passer, le nouveau symbole sera ajoute }
    End
    Else
    Begin
      WarnMsg('symbole deja defini dans ce scope: ' + Up);
      SymAdd := Dup;
      Exit;
    End;
  End;

  { Ajouter le symbole }
  SymTab[SymCount].Name        := Up;
  SymTab[SymCount].MangledName := SymMangle(Up, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TIdx;
  SymTab[SymCount].Offset      := 0;
  SymTab[SymCount].ScopeLevel  := CurScopeLevel;
  SymTab[SymCount].ScopeId     := CurScopeId;
  SymTab[SymCount].IsGlobal    := (CurScopeLevel = 0);
  SymTab[SymCount].IsExternal  := False;
  SymTab[SymCount].UnitName    := '';
  SymTab[SymCount].ImmVal      := 0;
  SymTab[SymCount].ParamCount  := 0;
  SymTab[SymCount].IsAbsolute  := False;
  SymTab[SymCount].AbsSeg      := 0;
  SymTab[SymCount].AbsOfs      := 0;

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ SymEnterScope / SymLeaveScope : gestion des portees           }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WarnMsg('profondeur de scope maximale atteinte');
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;
End;

{ ------------------------------------------------------------ }
{ SymRegisterBuiltins : pre-enregistrer les types, constantes, }
{ procedures et fonctions predefinies de Turbo Pascal           }
{ Le compilateur les reconnait automatiquement sans qu ils      }
{ soient declares explicitement dans le code source.            }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins;
Var
  DosSearchRecIdx : Integer;
  DosSymIdx       : Integer;

  { Registrer un type predefini }
  Procedure RegType(Const Name : TString);
  Var R, TIdx : Integer;
  Begin
    TIdx := TypeFindByName(Name);
    R := SymAdd(Name, SK_TYPE, TIdx);
    If R >= 0 Then
      SymTab[R].IsGlobal := True;
  End;

  { Registrer une constante predefinie avec valeur }
  Procedure RegConst(Const Name : TString; Val : LongInt);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_CONST, -1);
    If R >= 0 Then
    Begin
      SymTab[R].ImmVal   := Val;
      SymTab[R].IsGlobal := True;
    End;
  End;

  { Registrer une procedure predefinie }
  Procedure RegProc(Const Name : TString);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_PROC, -1);
    If R >= 0 Then
    Begin
      SymTab[R].IsGlobal  := True;
      SymTab[R].IsExternal := True;
    End;
  End;

  { Registrer une fonction predefinie }
  Procedure RegFunc(Const Name : TString);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_FUNC, -1);
    If R >= 0 Then
    Begin
      SymTab[R].IsGlobal  := True;
      SymTab[R].IsExternal := True;
    End;
  End;

Begin
  { ---------------------------------------------------------- }
  { Types predefinis Turbo Pascal                              }
  { ---------------------------------------------------------- }
  RegType('INTEGER');    RegType('LONGINT');
  RegType('WORD');       RegType('BYTE');
  RegType('SHORTINT');   RegType('CHAR');
  RegType('BOOLEAN');    RegType('STRING');
  RegType('REAL');       RegType('POINTER');
  RegType('TEXT');

  { Types TP 5+ }
  If TPVersionAtLeast(TP_VER_5) Then
  Begin
    RegType('SINGLE');   RegType('DOUBLE');
    RegType('EXTENDED'); RegType('COMP');
  End;

  { Types TP 7+ }
  If TPVersionAtLeast(TP_VER_7) Then
  Begin
    RegType('PCHAR');
    RegType('LONGWORD');
  End;

  { Types de l unite Dos (toujours enregistres) }
  RegType('DIRSTR');    RegType('NAMESTR');
  RegType('EXTSTR');    RegType('PATHSTR');
  RegType('COMSTR');    RegType('DATETIME');

  { Type QuickPascal : CSTRING (String + nul terminal) }
  If Opts.QuickPascal Then RegType('CSTRING');

  { Types Apple Pascal : ByteStream et WordStream }
  If Opts.ApplePascal Then
  Begin
    RegType('BYTESTREAM');
    RegType('WORDSTREAM');
  End;

  { ---------------------------------------------------------- }
  { Constantes predefinies                                      }
  { ---------------------------------------------------------- }
  RegConst('TRUE', 1);
  RegConst('FALSE', 0);
  RegConst('NIL', 0);
  RegConst('MAXINT', 32767);
  RegConst('MAXLONGINT', 2147483647);

  { ---------------------------------------------------------- }
  { Procedures et fonctions predefinies (toujours disponibles) }
  { ---------------------------------------------------------- }

  { E/S standard }
  RegProc('WRITE');      RegProc('WRITELN');
  RegProc('READ');       RegProc('READLN');

  { Conversion chaines }
  RegProc('STR');        RegProc('VAL');

  { Allocation memoire }
  RegProc('NEW');        RegProc('DISPOSE');
  RegProc('GETMEM');     RegProc('FREEMEM');

  { Inc / Dec }
  RegProc('INC');        RegProc('DEC');

  { Fonctions ordinales }
  RegFunc('ORD');        RegFunc('CHR');
  RegFunc('SUCC');       RegFunc('PRED');
  RegFunc('LOW');        RegFunc('HIGH');
  RegFunc('SIZEOF');

  { Fonctions mathematiques }
  RegFunc('ABS');        RegFunc('SQR');
  RegFunc('SQRT');       RegFunc('ROUND');
  RegFunc('TRUNC');      RegFunc('INT');
  RegFunc('FRAC');       RegFunc('SIN');
  RegFunc('COS');        RegFunc('LN');
  RegFunc('EXP');        RegFunc('PI');
  RegFunc('ARCTAN');

  { Fonctions de controle }
  RegProc('HALT');       RegProc('EXIT');
  RegProc('BREAK');      RegProc('CONTINUE');
  RegProc('RUNERROR');

  { Fonctions booleennes }
  RegFunc('ODD');        RegFunc('ASSIGNED');

  { Fonctions memoire }
  RegProc('FILLCHAR');   RegProc('MOVE');
  RegFunc('ADDR');       RegFunc('OFS');
  RegFunc('SEG');        RegFunc('CSEG');
  RegFunc('DSEG');       RegFunc('SSEG');
  RegFunc('SPTR');
  RegFunc('PARAMCOUNT'); RegFunc('PARAMSTR');

  { Fonctions sur les chaines }
  RegFunc('LENGTH');     RegFunc('COPY');
  RegFunc('POS');        RegFunc('CONCAT');
  RegFunc('UPCASE');
  RegProc('INSERT');     RegProc('DELETE');

  { Fichiers binaires }
  RegProc('BLOCKREAD');  RegProc('BLOCKWRITE');
  RegProc('ASSIGN');     RegProc('RESET');
  RegProc('REWRITE');    RegProc('CLOSE');
  RegFunc('EOF');        RegFunc('EOLN');
  RegFunc('SEEKEOF');    RegFunc('SEEKEOLN');
  RegFunc('IORESULT');   RegProc('SEEK');
  RegFunc('FILEPOS');    RegFunc('FILESIZE');
  RegProc('TRUNCATE');
  RegProc('RENAME');     RegProc('ERASE');
  RegProc('APPEND');     RegProc('FLUSH');
  RegProc('SETTEXTBUF');

  { Repertoires }
  RegProc('MKDIR');      RegProc('RMDIR');
  RegProc('CHDIR');      RegProc('GETDIR');

  { Ensembles (TP7) }
  RegProc('INCLUDE');    RegProc('EXCLUDE');

  { Fonctions de conversion }
  RegFunc('LO');         RegFunc('HI');
  RegFunc('SWAP');

  { Fonctions diverses }
  RegFunc('RANDOM');     RegProc('RANDOMIZE');
  RegFunc('SIZEOF');

  { TP 5.5+ : POO (objets) }
  If TPVersionAtLeast(TP_VER_55) Then
  Begin
    RegFunc('TYPEOF');
  End;

  { TP 7+ : fonctions supplementaires }
  If TPVersionAtLeast(TP_VER_7) Then
  Begin
    RegFunc('ASSIGNED');
  End;

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite CRT (TODO 18)          }
  { Toujours enregistrees, reconnues si Uses Crt presente      }
  { ---------------------------------------------------------- }
  RegProc('CLRSCR');     RegProc('CLREOL');
  RegProc('GOTOXY');     RegProc('TEXTCOLOR');
  RegProc('TEXTBACKGROUND');
  RegProc('HIGHVIDEO');  RegProc('LOWVIDEO');
  RegProc('NORMVIDEO');  RegProc('WINDOW');
  RegProc('DELAY');      RegProc('SOUND');
  RegProc('NOSOUND');    RegProc('ASSIGNCRT');
  RegProc('INSLINE');    RegProc('DELLINE');
  RegProc('TEXTMODE');
  RegFunc('WHEREX');     RegFunc('WHEREY');
  RegFunc('KEYPRESSED'); RegFunc('READKEY');

  { Constantes CRT : modes video }
  RegConst('BW40', 0);   RegConst('CO40', 1);
  RegConst('BW80', 2);   RegConst('CO80', 3);
  RegConst('MONO', 7);   RegConst('FONT8X8', 256);
  RegConst('C40', 1);    RegConst('C80', 3);

  { Constantes CRT : couleurs premier plan et arriere-plan }
  RegConst('BLACK', 0);        RegConst('BLUE', 1);
  RegConst('GREEN', 2);        RegConst('CYAN', 3);
  RegConst('RED', 4);          RegConst('MAGENTA', 5);
  RegConst('BROWN', 6);        RegConst('LIGHTGRAY', 7);

  { Constantes CRT : couleurs premier plan uniquement }
  RegConst('DARKGRAY', 8);     RegConst('LIGHTBLUE', 9);
  RegConst('LIGHTGREEN', 10);  RegConst('LIGHTCYAN', 11);
  RegConst('LIGHTRED', 12);    RegConst('LIGHTMAGENTA', 13);
  RegConst('YELLOW', 14);      RegConst('WHITE', 15);

  { Constante CRT : clignotement }
  RegConst('BLINK', 128);

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite DOS (TODO 19)           }
  { Toujours enregistrees, reconnues si Uses Dos presente       }
  { ---------------------------------------------------------- }
  RegFunc('DOSVERSION');
  RegProc('GETDATE');     RegProc('GETTIME');
  RegProc('SETDATE');     RegProc('SETTIME');
  RegProc('GETFATTR');    RegProc('SETFATTR');
  RegProc('FINDFIRST');   RegProc('FINDNEXT');
  RegProc('FINDCLOSE');
  RegFunc('DISKFREE');    RegFunc('DISKSIZE');
  RegFunc('GETENV');
  RegFunc('FSEARCH');     RegFunc('FEXPAND');
  RegProc('FSPLIT');
  RegProc('EXEC');
  RegProc('SWAPVECTORS'); RegProc('GETINTVEC');
  RegProc('SETINTVEC');
  RegProc('MSDOS');       RegProc('INTR');
  RegProc('GETCBREAK');  RegProc('SETCBREAK');
  RegProc('GETVERIFY');  RegProc('SETVERIFY');
  RegProc('GETFTIME');   RegProc('SETFTIME');
  RegProc('UNPACKTIME'); RegProc('PACKTIME');
  RegProc('KEEP');
  RegFunc('ENVCOUNT');   RegFunc('ENVSTR');
  RegFunc('DOSEXITCODE');

  { Constantes DOS predefinies }
  RegConst('READONLY', $01);
  RegConst('HIDDEN',   $02);
  RegConst('SYSFILE',  $04);
  RegConst('VOLUMEID', $08);
  RegConst('DIRECTORY',$10);
  RegConst('ARCHIVE',  $20);
  RegConst('ANYFILE',  $3F);

  { Constantes DOS : drapeaux processeur }
  RegConst('FCARRY',     $0001);
  RegConst('FPARITY',    $0004);
  RegConst('FAUXILIARY', $0010);
  RegConst('FZERO',      $0040);
  RegConst('FSIGN',      $0080);
  RegConst('FOVERFLOW',  $0800);

  { Constantes DOS : modes de fichier }
  RegConst('FMCLOSED', $D7B0);
  RegConst('FMINPUT',  $D7B1);
  RegConst('FMOUTPUT', $D7B2);
  RegConst('FMINOUT',  $D7B3);

  { Type SearchRec predefini }
  { Deplace dans le code principal apres TypeInit }

  { Variable DosError : mappe sur le label BSS DOSERROR }
  DosSymIdx := SymAdd('DOSERROR', SK_VAR, TY_IDX_INTEGER);
  If DosSymIdx >= 0 Then
  Begin
    SymTab[DosSymIdx].MangledName := 'DOSERROR';
    SymTab[DosSymIdx].IsGlobal    := True;
  End;

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Graph (TODO 20)         }
  { Toujours enregistrees, reconnues si Uses Graph presente    }
  { ---------------------------------------------------------- }
  RegProc('INITGRAPH');    RegProc('CLOSEGRAPH');
  RegProc('DETECTGRAPH');
  RegProc('PUTPIXEL');     RegProc('LINE');
  RegProc('RECTANGLE');    RegProc('BAR');
  RegProc('BAR3D');        RegProc('CIRCLE');
  RegProc('ARC');          RegProc('ELLIPSE');
  RegProc('FILLELLIPSE');
  RegProc('SETCOLOR');     RegProc('SETBKCOLOR');
  RegProc('SETFILLSTYLE'); RegProc('SETLINESTYLE');
  RegProc('OUTTEXTXY');    RegProc('SETTEXTSTYLE');
  RegProc('SETVIEWPORT');  RegProc('CLEARDEVICE');
  RegProc('SETACTIVEPAGE');RegProc('SETVISUALPAGE');
  RegProc('OUTTEXT');      RegProc('MOVETO');
  RegProc('MOVEREL');      RegProc('LINEREL');
  RegProc('LINETO');       RegProc('SETPALETTE');
  RegProc('SETRGBPALETTE');RegProc('SETASPECTRATIO');
  RegProc('SETWRITEMODE'); RegProc('PIESLICE');
  RegProc('SECTOR');       RegProc('FLOODFILL');
  RegProc('GETIMAGE');     RegProc('PUTIMAGE');
  RegFunc('GETPIXEL');     RegFunc('GETMAXX');
  RegFunc('GETMAXY');      RegFunc('GETX');
  RegFunc('GETY');         RegFunc('GRAPHRESULT');
  RegFunc('GRAPHERRORMSG');RegFunc('IMAGESIZE');
  RegFunc('GETMAXCOLOR');  RegFunc('GETCOLOR');
  RegFunc('GETBKCOLOR');   RegFunc('GETDRIVERNAME');
  RegFunc('GETMODENAME');  RegFunc('GETMAXMODE');
  RegFunc('INSTALLUSERDRIVER');
  RegFunc('INSTALLUSERFONT');
  RegFunc('TEXTHEIGHT');   RegFunc('TEXTWIDTH');
  RegFunc('REGISTERBGIDRIVER');  RegFunc('REGISTERBGIFONT');
  RegFunc('GETGRAPHMODE');       RegFunc('GETPALETTESIZE');
  RegProc('RESTORECRTMODE');     RegProc('SETGRAPHMODE');
  RegProc('GRAPHDEFAULTS');      RegProc('SETGRAPHBUFSIZE');
  RegProc('GETMODERANGE');       RegProc('DRAWPOLY');
  RegProc('FILLPOLY');           RegProc('SETFILLPATTERN');
  RegProc('SETALLPALETTE');      RegProc('GETPALETTE');
  RegProc('GETDEFAULTPALETTE');  RegProc('SETTEXTJUSTIFY');
  RegProc('SETUSERCHARSIZE');    RegProc('GETTEXTSETTINGS');
  RegProc('GETLINESETTINGS');    RegProc('GETFILLSETTINGS');
  RegProc('GETFILLPATTERN');     RegProc('GETVIEWSETTINGS');
  RegProc('GETARCCOORDS');       RegProc('GETASPECTRATIO');
  RegProc('CLEARVIEWPORT');

  { Constantes Graph (TODO 20) }
  RegConst('DETECT', 0);
  RegConst('CGA', 1);     RegConst('MCGA', 2);
  RegConst('EGA', 3);     RegConst('EGA64', 4);
  RegConst('EGAMONO', 5); RegConst('IBM8514', 6);
  RegConst('HERCMONO', 7);RegConst('ATT400', 8);
  RegConst('VGA', 9);     RegConst('PC3270', 10);
  RegConst('VGALO', 0);   RegConst('VGAMED', 1);
  RegConst('VGAHI', 2);
  RegConst('GROK', 0);         RegConst('GRNOINITGRAPH', -1);
  RegConst('GRNOTDETECTED', -2);RegConst('GRFILENOTFOUND', -3);
  RegConst('GRINVALIDDRIVER', -4);RegConst('GRNOMEM', -5);
  RegConst('GRINVALIDMODE', -10);RegConst('GRERROR', -11);
  RegConst('GRIOERROR', -12); RegConst('GRINVALIDFONT', -13);
  RegConst('GRINVALIDFONTNUM', -14);RegConst('GRINVALIDVERSION', -18);
  RegConst('SOLIDLN', 0);  RegConst('DOTTEDLN', 1);
  RegConst('CENTERLN', 2); RegConst('DASHEDLN', 3);
  RegConst('USERBITLN', 4);
  RegConst('NORMWIDTH', 1);RegConst('THICKWIDTH', 3);
  RegConst('SOLIDFILL', 1);RegConst('EMPTYFILL', 0);
  RegConst('LINEFILL', 2); RegConst('LTSLASHFILL', 3);
  RegConst('SLASHFILL', 4);RegConst('BKSLASHFILL', 5);
  RegConst('LTBKSLASHFILL', 6);RegConst('HATCHFILL', 7);
  RegConst('XHATCHFILL', 8);RegConst('INTERLEAVEFILL', 9);
  RegConst('WIDEDOTFILL', 10);RegConst('CLOSEDOTFILL', 11);
  RegConst('USERFILL', 12);
  RegConst('DEFAULTFONT', 0);RegConst('TRIPLEXFONT', 1);
  RegConst('SMALLFONT', 2); RegConst('SANSSERIFFONT', 3);
  RegConst('GOTHICFONT', 4);
  RegConst('HORIZDIR', 0);  RegConst('VERTDIR', 1);
  RegConst('LEFTTEXT', 0);  RegConst('CENTERTEXT', 1);
  RegConst('RIGHTTEXT', 2);
  RegConst('BOTTOMTEXT', 0);RegConst('TOPTEXT', 2);
  RegConst('COPYPUT', 0);   RegConst('XORPUT', 1);
  RegConst('ORPUT', 2);     RegConst('ANDPUT', 3);
  RegConst('NOTPUT', 4);

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite MSGraph (QuickPascal)    }
  { Toujours enregistrees, activees si Uses MsGraph presente    }
  { ---------------------------------------------------------- }
  Begin
    { Installation / Configuration }
    RegFunc('_GRSTATUS');         RegFunc('_SETVIDEOMODE');
    RegFunc('_SETVIDEOMODEROWS'); RegFunc('_GETACTIVEPAGE');
    RegFunc('_GETVISUALPAGE');
    RegProc('_SETACTIVEPAGE');    RegProc('_SETVISUALPAGE');
    RegProc('_GETVIDEOCONFIG');
    { Coordonnees }
    RegProc('_SETVIEWORG');       RegProc('_SETVIEWPORT');
    RegProc('_SETCLIPRGN');      RegProc('_SETWINDOW');
    RegProc('_GETVIEWCOORD');    RegProc('_GETVIEWCOORD_W');
    RegProc('_GETVIEWCOORD_WXY');RegProc('_GETPHYSCOORD');
    RegProc('_GETWINDOWCOORD');  RegProc('_GETCURRENTPOSITION');
    RegProc('_GETCURRENTPOSITION_WXY');
    { Sortie graphique }
    RegProc('_CLEARSCREEN');     RegProc('_MOVETO');
    RegProc('_MOVETO_W');        RegProc('_LINETO');
    RegProc('_LINETO_W');        RegProc('_RECTANGLE');
    RegProc('_RECTANGLE_W');     RegProc('_RECTANGLE_WXY');
    RegProc('_ELLIPSE');         RegProc('_ELLIPSE_W');
    RegProc('_ELLIPSE_WXY');     RegProc('_ARC');
    RegProc('_ARC_WXY');         RegProc('_PIE');
    RegProc('_PIE_WXY');         RegProc('_FLOODFILL');
    RegProc('_FLOODFILL_W');
    RegFunc('_GETARCINFO');
    { Pixels }
    RegProc('_SETPIXEL');        RegProc('_SETPIXEL_W');
    RegFunc('_GETPIXEL');        RegFunc('_GETPIXEL_W');
    { Couleur / Style }
    RegProc('_SETCOLOR');        RegFunc('_GETCOLOR');
    RegProc('_SETLINESTYLE');    RegFunc('_GETLINESTYLE');
    RegProc('_SETWRITEMODE');    RegFunc('_GETWRITEMODE');
    RegProc('_SETFILLMASK');     RegFunc('_GETFILLMASK');
    { Couleur de fond }
    RegProc('_SETBKCOLOR');      RegFunc('_GETBKCOLOR');
    { Palette }
    RegFunc('_REMAPPALETTE');    RegProc('_REMAPALLPALETTE');
    RegFunc('_SELECTPALETTE');
    { Texte }
    RegFunc('_SETTEXTROWS');     RegProc('_SETTEXTWINDOW');
    RegProc('_GETTEXTWINDOW');   RegProc('_SCROLLTEXTWINDOW');
    RegProc('_OUTMEM');          RegProc('_OUTTEXT');
    RegFunc('_WRAPON');          RegFunc('_DISPLAYCURSOR');
    { Curseur texte }
    RegProc('_SETTEXTCURSOR');   RegFunc('_GETTEXTCURSOR');
    { Position texte }
    RegProc('_SETTEXTPOSITION'); RegProc('_GETTEXTPOSITION');
    { Couleur texte }
    RegProc('_SETTEXTCOLOR');    RegFunc('_GETTEXTCOLOR');
    { Images }
    RegProc('_GETIMAGE');        RegProc('_GETIMAGE_W');
    RegProc('_GETIMAGE_WXY');    RegProc('_PUTIMAGE');
    RegProc('_PUTIMAGE_W');
    RegFunc('_IMAGESIZE');       RegFunc('_IMAGESIZE_W');
    RegFunc('_IMAGESIZE_WXY');
    { Polices graphiques }
    RegFunc('_REGISTERFONTS');   RegProc('_UNREGISTERFONTS');
    RegFunc('_SETFONT');         RegProc('_OUTGTEXT');
    RegFunc('_GETGTEXTEXTENT'); RegFunc('_GETFONTINFO');
    RegProc('_SETGTEXTVECTOR');  RegProc('_GETGTEXTVECTOR');
    { Constantes MSGraph - modes video }
    RegConst('_MAXRESMODE', -3);
    RegConst('_MAXCOLORMODE', -2);
    RegConst('_DEFAULTMODE', -1);
    RegConst('_TEXTBW40', 0);    RegConst('_TEXTC40', 1);
    RegConst('_TEXTBW80', 2);    RegConst('_TEXTC80', 3);
    RegConst('_MRES4COLOR', 4);  RegConst('_MRESNOCOLOR', 5);
    RegConst('_HRESBW', 6);      RegConst('_TEXTMONO', 7);
    RegConst('_HERCMONO', 8);
    RegConst('_MRES16COLOR', 13);RegConst('_HRES16COLOR', 14);
    RegConst('_ERESNOCOLOR', 15);RegConst('_ERESCOLOR', 16);
    RegConst('_VRES2COLOR', 17); RegConst('_VRES16COLOR', 18);
    RegConst('_MRES256COLOR', 19);
    RegConst('_ORESCOLOR', 64);
    { Constantes MSGraph - action rectangle/ellipse/pie }
    RegConst('_GBORDER', 2);
    RegConst('_GFILLINTERIOR', 3);
    { Constantes MSGraph - ClearScreen }
    RegConst('_GCLEARSCREEN', 0);
    RegConst('_GVIEWPORT', 1);
    RegConst('_GWINDOW', 2);
    { Constantes MSGraph - codes erreur }
    RegConst('_GROK', 0);
    RegConst('_GRERROR', -1);
    RegConst('_GRMODENOTSUPPORTED', -2);
    RegConst('_GRNOTINPROPERMODE', -3);
    RegConst('_GRINVALIDPARAMETER', -4);
    RegConst('_GRFONTFILENOTFOUND', -5);
    RegConst('_GRINVALIDFONTFILE', -6);
    RegConst('_GRCORRUPTEDFONTFILE', -7);
    RegConst('_GRINSUFFICIENTMEMORY', -8);
    RegConst('_GRINVALIDIMAGEBUFFER', -9);
    { Constantes MSGraph - avertissements }
    RegConst('_GRNOOUTPUT', 1);
    RegConst('_GRCLIPPED', 2);
    RegConst('_GRPARAMETERALTERED', 3);
    { Constantes MSGraph - PutImage }
    RegConst('_GPSET', 3);
    RegConst('_GPRESET', 2);
    RegConst('_GAND', 1);
    RegConst('_GOR', 0);
    RegConst('_GXOR', 4);
    { Constantes MSGraph - types d adaptateur }
    RegConst('_MDPA', 1);   RegConst('_CGA', 2);
    RegConst('_EGA', 3);    RegConst('_VGA', 4);
    RegConst('_MCGA', 5);   RegConst('_HGC', 6);
    RegConst('_OCGA', 7);   RegConst('_OEGA', 8);
    RegConst('_OVGA', 9);
    { Constantes MSGraph - types de moniteur }
    RegConst('_MONO', 1);     RegConst('_COLOR', 2);
    RegConst('_ENHCOLOR', 3); RegConst('_ANALOGMONO', 5);
    RegConst('_ANALOGCOLOR', 6); RegConst('_ANALOG', 7);
  End;

  { ---------------------------------------------------------- }
  { Constantes, procedures et fonctions de l unite SANE         }
  { (Apple Pascal) - activees si --applepascal ou --sane        }
  { ---------------------------------------------------------- }
  If Opts.ApplePascal Or Opts.Sane Then
  Begin
    { Constantes SANE }
    RegConst('DECSTRLEN', 255);
    RegConst('SIGDIGLEN', 20);
    RegConst('INVALID', 1);
    RegConst('UNDERFLOW', 2);
    RegConst('OVERFLOW', 4);
    RegConst('DIVBYZERO', 8);
    RegConst('INEXACT', 16);
    { Conversion entre types numeriques binaires }
    RegFunc('NUM2INTEGER');
    RegFunc('NUM2LONGINT');
    RegFunc('NUM2REAL');
    RegFunc('NUM2DOUBLE');
    RegFunc('NUM2EXTENDED');
    RegFunc('NUM2COMP');
    { Conversion entre binaire et decimal }
    RegProc('NUM2DEC');
    RegFunc('DEC2NUM');
    RegProc('NUM2STR');
    RegFunc('STR2NUM');
    { Conversion entre formats decimal }
    RegProc('STR2DEC');
    RegProc('CSTR2DEC');
    RegProc('DEC2STR');
    { Fonctions arithmetique, auxiliaire et elementaire }
    RegFunc('REMAINDER');
    RegFunc('RINT');
    RegFunc('SCALB');
    RegFunc('LOGB');
    RegFunc('COPYSIGN');
    RegFunc('NEXTREAL');
    RegFunc('NEXTDOUBLE');
    RegFunc('NEXTEXTENDED');
    RegFunc('LOG2');
    RegFunc('LN1');
    RegFunc('EXP2');
    RegFunc('EXP1');
    RegFunc('XPWRI');
    RegFunc('XPWRY');
    RegFunc('COMPOUND');
    RegFunc('ANNUITY');
    RegFunc('TAN');
    RegFunc('RANDOMX');
    { Routines d enquetes }
    RegFunc('CLASSREAL');
    RegFunc('CLASSDOUBLE');
    RegFunc('CLASSCOMP');
    RegFunc('CLASSEXTENDED');
    RegFunc('SIGNNUM');
    RegFunc('NAN');
    { Routines d acces d environnement }
    RegProc('SETEXCEPTION');
    RegFunc('TESTEXCEPTION');
    RegProc('SETHALT');
    RegFunc('TESTHALT');
    RegProc('SETROUND');
    RegFunc('GETROUND');
    RegProc('SETPRECISION');
    RegFunc('GETPRECISION');
    RegProc('SETENVIRONMENT');
    RegProc('GETENVIRONMENT');
    RegProc('PROCENTRY');
    RegProc('PROCEXIT');
    RegFunc('GETHALTVECTOR');
    RegProc('SETHALTVECTOR');
    { Routine de comparaison }
    RegFunc('RELATION');
  End;

  { ---------------------------------------------------------- }
  { Fonctions de l unite TRANSCEND (Apple Pascal)               }
  { Disponible uniquement avec --applepascal (pas --sane)       }
  { ---------------------------------------------------------- }
  If Opts.ApplePascal And Not Opts.Sane Then
  Begin
    RegFunc('ATAN');          { ATan(r:Real):Real - arc tangente  }
    RegFunc('LOG');           { Log(n:Real):Real  - log base 10   }
    RegFunc('PWROFTEN');      { PwrOfTen(n:Integer):Real - 10^n   }
  End;

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Graph3 (TODO 20)        }
  { Compatibilite Turbo Pascal 3                                }
  { ---------------------------------------------------------- }
  RegProc('GRAPHCOLORMODE');RegProc('GRAPHMODE');
  RegProc('HIRES');        RegProc('HIRESCOLOR');
  RegProc('PALETTE');      RegProc('GRAPHBACKGROUND');
  RegProc('GRAPHWINDOW');  RegProc('PLOT');
  RegProc('DRAW');         RegProc('COLORTABLE');

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Strings (TODO 21)       }
  { Fonctions PChar / ASCIIZ                                    }
  { ---------------------------------------------------------- }
  RegFunc('STRLEN');      RegFunc('STRCOPY');
  RegFunc('STRCAT');      RegFunc('STRCOMP');
  RegFunc('STRICOMP');    RegFunc('STRPOS');
  RegFunc('STRSCAN');     RegFunc('STRRSCAN');
  RegFunc('STREND');      RegFunc('STRMOVE');
  RegFunc('STRNEW');      RegFunc('STRPAS');
  RegFunc('STRPCOPY');    RegFunc('STRUPPER');
  RegFunc('STRLOWER');    RegFunc('STRLCOPY');
  RegFunc('STRLCAT');     RegFunc('STRECOPY');
  RegFunc('STRLICOMP');
  RegProc('STRDISPOSE');

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Printer (TODO 21)       }
  { Emulation imprimante -> fichier NUL ou redirection          }
  { ---------------------------------------------------------- }
  RegProc('ASSIGNLST');

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Overlay (TODO 21)       }
  { Stubs : overlays non necessaires en Win32 memoire FLAT      }
  { ---------------------------------------------------------- }
  RegProc('OVRINIT');     RegProc('OVRINITEMS');
  RegProc('OVRSETBUF');   RegProc('OVRCLEARBUF');
  RegProc('OVRSETRETRY');
  RegFunc('OVRGETBUF');   RegFunc('OVRGETRETURNCODE');

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Turbo3 (TODO 21)        }
  { Compatibilite Turbo Pascal 3 : console -> redirige vers    }
  { implementations CRT, graphique -> redirige vers Graph3.    }
  { GotoXY, ClrScr, ClrEol, LowVideo, NormVideo, Delay deja   }
  { registres via CRT. Plot, Draw, ColorTable, GraphBackground,}
  { GraphColorMode, GraphMode, GraphWindow, HiRes, HiResColor, }
  { Palette deja registres via Graph3.                          }
  { ---------------------------------------------------------- }
  { Constantes Turbo3 specifiques }
  RegFunc('GRAPHCOLORMODE');  { -> mode graphique couleur }
  RegFunc('GRAPHMODE');       { -> mode graphique mono }

  { ---------------------------------------------------------- }
  { Procedures et fonctions de l unite Objects (TODO 21)       }
  { TP7 : TObject, TStream, TCollection et derives.            }
  { Emulation minimale : stubs pour constructeurs/destructeurs, }
  { methodes TStream via API fichiers Windows.                  }
  { ---------------------------------------------------------- }
  { TObject }
  RegProc('TOBJECT_INIT');    RegProc('TOBJECT_DONE');
  RegProc('TOBJECT_FREE');
  { TStream }
  RegFunc('TSTREAM_GET');     RegFunc('TSTREAM_GETPOS');
  RegFunc('TSTREAM_GETSIZE'); RegFunc('TSTREAM_READ');
  RegProc('TSTREAM_WRITE');   RegProc('TSTREAM_SEEK');
  RegProc('TSTREAM_RESET');   RegProc('TSTREAM_FLUSH');
  RegProc('TSTREAM_TRUNCATE');
  { TDosStream }
  RegProc('TDOSSTREAM_INIT'); RegProc('TDOSSTREAM_DONE');
  { TBufStream }
  RegProc('TBUFSTREAM_INIT'); RegProc('TBUFSTREAM_DONE');
  RegProc('TBUFSTREAM_FLUSH');
  { TCollection }
  RegProc('TCOLLECTION_INIT'); RegProc('TCOLLECTION_DONE');
  RegProc('TCOLLECTION_INSERT'); RegProc('TCOLLECTION_DELETE');
  RegFunc('TCOLLECTION_AT');   RegFunc('TCOLLECTION_COUNT');
  RegFunc('TCOLLECTION_INDEXOF');
  { RegisterType / NewStr / DisposeStr }
  RegProc('REGISTERTYPE');
  RegFunc('NEWSTR');
  RegProc('DISPOSESTR');

  { ---------------------------------------------------------- }
  { Variables speciales Mem/MemW/MemL/Port/PortW (TODO 22)     }
  { Registrees comme fonctions pour les reconnaitre en         }
  { ParsePrimary et ParseStmt avec traitement special.         }
  { ---------------------------------------------------------- }
  RegFunc('MEM');
  RegFunc('MEMW');
  RegFunc('MEML');
  RegFunc('PORT');
  RegFunc('PORTW');
End;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                      [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un type dans la table                      }
{ Retourne l index du type ajoute, ou -1 si plein              }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind : TTypeKind; Const AName : TString;
                 ASize : Integer; AAlign : Integer;
                 AUnsigned : Boolean;
                 ABaseTypeIdx : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE=' +
      IntToStr_(MAX_TYPE) + ')');
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
  TypeTab[TypeCount].FieldCount  := 0;
  TypeTab[TypeCount].EnumCount   := 0;
  TypeTab[TypeCount].IsPacked    := False;
  TypeTab[TypeCount].IsUnsigned  := AUnsigned;

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeInit : initialiser la table des types avec les types      }
{ primitifs de Turbo Pascal                                    }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var I, TI : Integer;
Begin
  TypeCount := 0;
  WithDepth := 0;

  { Initialiser toute la table a zero }
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind        := TYK_INTEGER;
    TypeTab[I].Name        := '';
    TypeTab[I].Size        := 0;
    TypeTab[I].Align       := 1;
    TypeTab[I].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[I].Lo          := 0;
    TypeTab[I].Hi          := 0;
    TypeTab[I].FieldCount  := 0;
    TypeTab[I].EnumCount   := 0;
    TypeTab[I].IsPacked    := False;
    TypeTab[I].IsUnsigned  := False;
  End;

  { Types primitifs Turbo Pascal (Win32, 32 bits)                  }
  { Les index doivent correspondre aux constantes TY_IDX_xxx       }

  { idx 0 : Integer (LongInt 32 bits signe) }
  TypeAdd(TYK_INTEGER, 'INTEGER', 4, 4, False, TY_UNKNOWN);

  { idx 1 : Word (32 bits non signe en Win32) }
  TypeAdd(TYK_WORD, 'WORD', 4, 4, True, TY_UNKNOWN);

  { idx 2 : Byte (8 bits non signe) }
  TypeAdd(TYK_BYTE, 'BYTE', 1, 1, True, TY_UNKNOWN);

  { idx 3 : ShortInt (8 bits signe) }
  TypeAdd(TYK_SHORTINT, 'SHORTINT', 1, 1, False, TY_UNKNOWN);

  { idx 4 : Char (8 bits) }
  TypeAdd(TYK_CHAR, 'CHAR', 1, 1, True, TY_UNKNOWN);

  { idx 5 : Boolean (8 bits, 0 ou 1) }
  TypeAdd(TYK_BOOLEAN, 'BOOLEAN', 1, 1, True, TY_UNKNOWN);

  { idx 6 : String (ShortString, 256 octets: 1 longueur + 255 data) }
  TypeAdd(TYK_STRING, 'STRING', 256, 1, False, TY_UNKNOWN);

  { idx 7 : Real (6 octets, format specifique Turbo Pascal) }
  TypeAdd(TYK_REAL, 'REAL', 6, 2, False, TY_UNKNOWN);

  { idx 8 : Single (flottant IEEE 32 bits) }
  TypeAdd(TYK_SINGLE, 'SINGLE', 4, 4, False, TY_UNKNOWN);

  { idx 9 : Double (flottant IEEE 64 bits) }
  TypeAdd(TYK_DOUBLE, 'DOUBLE', 8, 4, False, TY_UNKNOWN);

  { idx 10 : Extended (flottant 80 bits) }
  TypeAdd(TYK_EXTENDED, 'EXTENDED', 10, 4, False, TY_UNKNOWN);

  { idx 11 : Comp (entier 64 bits virgule fixe) }
  TypeAdd(TYK_COMP, 'COMP', 8, 4, False, TY_UNKNOWN);

  { idx 12 : Pointer (pointeur generique 32 bits) }
  TypeAdd(TYK_POINTER, 'POINTER', 4, 4, False, TY_UNKNOWN);

  { idx 13 : PChar (pointeur vers Char) }
  TypeAdd(TYK_PCHAR, 'PCHAR', 4, 4, False, TY_IDX_CHAR);

  { idx 14 : Text (handle fichier texte) }
  TypeAdd(TYK_TEXT, 'TEXT', 4, 4, False, TY_UNKNOWN);

  { idx 15 : nil (constante pointeur nul) }
  TypeAdd(TYK_NIL, 'NIL', 4, 4, False, TY_UNKNOWN);

  { idx 16 : LongInt (alias de Integer en Win32) }
  TypeAdd(TYK_INTEGER, 'LONGINT', 4, 4, False, TY_IDX_INTEGER);

  { idx 17 : LongWord (TP8+, 32 bits non signe) }
  TypeAdd(TYK_WORD, 'LONGWORD', 4, 4, True, TY_IDX_WORD);

  { Types chaines de l unite Dos }
  TypeAdd(TYK_STRING, 'DIRSTR',  68, 1, False, TY_UNKNOWN);   { String[67] }
  TypeAdd(TYK_STRING, 'NAMESTR',  9, 1, False, TY_UNKNOWN);   { String[8]  }
  TypeAdd(TYK_STRING, 'EXTSTR',   5, 1, False, TY_UNKNOWN);   { String[4]  }
  TypeAdd(TYK_STRING, 'PATHSTR', 80, 1, False, TY_UNKNOWN);   { String[79] }
  TypeAdd(TYK_STRING, 'COMSTR', 128, 1, False, TY_UNKNOWN);   { String[127]}

  { Type QuickPascal : CSTRING (String + nul terminal) }
  If Opts.QuickPascal Then TypeAdd(TYK_STRING, 'CSTRING', 256, 1, False, TY_UNKNOWN);

  { Types Apple Pascal : ByteStream (Array of Char) et WordStream (Array of Integer) }
  If Opts.ApplePascal Then
  Begin
    TI := TypeAdd(TYK_ARRAY, 'BYTESTREAM', 256, 1, False, TY_IDX_CHAR);
    If TI >= 0 Then Begin TypeTab[TI].Lo := 0; TypeTab[TI].Hi := 255; End;
    TI := TypeAdd(TYK_ARRAY, 'WORDSTREAM', 256, 4, False, TY_IDX_INTEGER);
    If TI >= 0 Then Begin TypeTab[TI].Lo := 0; TypeTab[TI].Hi := 63; End;
  End;

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types primitifs enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : trouver un type par son nom exact           }
{ Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const AName : TString) : Integer;
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
{ TypeSizeofIdx : retourne la taille d un type par son index   }
{ ------------------------------------------------------------ }

Function TypeSizeofIdx(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeSizeofIdx := TypeTab[Idx].Size
  Else
    TypeSizeofIdx := 4;  { taille par defaut = DWORD 32 bits }
End;

{ ------------------------------------------------------------ }
{ RegisterSearchRecType : enregistrer le type SearchRec du DOS }
{ Doit etre appele APRES TypeInit (TypeAdd doit etre disponible)}
{ Layout : Attr(2) pad(2) Time(4) Size(4) Name(256) = 268     }
{ ------------------------------------------------------------ }

Procedure RegisterSearchRecType;
Var
  TI, SI : Integer;
Begin
  TI := TypeAdd(TYK_RECORD, 'SEARCHREC', 268, 4, False, -1);
  If TI >= 0 Then
  Begin
    TypeTab[TI].FieldCount := 4;
    TypeTab[TI].Fields[0].Name    := 'ATTR';
    TypeTab[TI].Fields[0].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[0].Offset  := 0;
    TypeTab[TI].Fields[1].Name    := 'TIME';
    TypeTab[TI].Fields[1].TypeIdx := TY_IDX_LONGINT;
    TypeTab[TI].Fields[1].Offset  := 4;
    TypeTab[TI].Fields[2].Name    := 'SIZE';
    TypeTab[TI].Fields[2].TypeIdx := TY_IDX_LONGINT;
    TypeTab[TI].Fields[2].Offset  := 8;
    TypeTab[TI].Fields[3].Name    := 'NAME';
    TypeTab[TI].Fields[3].TypeIdx := TY_IDX_STRING;
    TypeTab[TI].Fields[3].Offset  := 12;
    SI := SymAdd('SEARCHREC', SK_TYPE, TI);
    If SI >= 0 Then SymTab[SI].IsGlobal := True;
  End;
End;

{ ------------------------------------------------------------ }
{ RegisterDateTimeType : enregistrer le type DateTime du DOS   }
{ Layout : Year(2) Month(2) Day(2) Hour(2) Min(2) Sec(2) = 12 }
{ ------------------------------------------------------------ }

Procedure RegisterDateTimeType;
Var
  TI, SI : Integer;
Begin
  TI := TypeAdd(TYK_RECORD, 'DATETIME', 12, 2, False, -1);
  If TI >= 0 Then
  Begin
    TypeTab[TI].FieldCount := 6;
    TypeTab[TI].Fields[0].Name    := 'YEAR';
    TypeTab[TI].Fields[0].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[0].Offset  := 0;
    TypeTab[TI].Fields[1].Name    := 'MONTH';
    TypeTab[TI].Fields[1].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[1].Offset  := 2;
    TypeTab[TI].Fields[2].Name    := 'DAY';
    TypeTab[TI].Fields[2].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[2].Offset  := 4;
    TypeTab[TI].Fields[3].Name    := 'HOUR';
    TypeTab[TI].Fields[3].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[3].Offset  := 6;
    TypeTab[TI].Fields[4].Name    := 'MIN';
    TypeTab[TI].Fields[4].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[4].Offset  := 8;
    TypeTab[TI].Fields[5].Name    := 'SEC';
    TypeTab[TI].Fields[5].TypeIdx := TY_IDX_WORD;
    TypeTab[TI].Fields[5].Offset  := 10;
    SI := SymAdd('DATETIME', SK_TYPE, TI);
    If SI >= 0 Then SymTab[SI].IsGlobal := True;
  End;
End;

{ ------------------------------------------------------------ }
{ RegisterVideoConfigType : type _VideoConfig de MSGraph       }
{ 11 champs Integer (4 octets chacun) = 44 bytes               }
{ ------------------------------------------------------------ }

Procedure RegisterVideoConfigType;
Var
  TI, SI : Integer;
Begin
  TI := TypeAdd(TYK_RECORD, '_VIDEOCONFIG', 44, 4, False, -1);
  If TI >= 0 Then
  Begin
    TypeTab[TI].FieldCount := 11;
    TypeTab[TI].Fields[0].Name    := 'NUMXPIXELS';
    TypeTab[TI].Fields[0].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[0].Offset  := 0;
    TypeTab[TI].Fields[1].Name    := 'NUMYPIXELS';
    TypeTab[TI].Fields[1].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[1].Offset  := 4;
    TypeTab[TI].Fields[2].Name    := 'NUMTEXTCOLS';
    TypeTab[TI].Fields[2].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[2].Offset  := 8;
    TypeTab[TI].Fields[3].Name    := 'NUMTEXTROWS';
    TypeTab[TI].Fields[3].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[3].Offset  := 12;
    TypeTab[TI].Fields[4].Name    := 'NUMCOLORS';
    TypeTab[TI].Fields[4].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[4].Offset  := 16;
    TypeTab[TI].Fields[5].Name    := 'BITSPERPIXEL';
    TypeTab[TI].Fields[5].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[5].Offset  := 20;
    TypeTab[TI].Fields[6].Name    := 'NUMVIDEOPAGES';
    TypeTab[TI].Fields[6].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[6].Offset  := 24;
    TypeTab[TI].Fields[7].Name    := 'MODE';
    TypeTab[TI].Fields[7].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[7].Offset  := 28;
    TypeTab[TI].Fields[8].Name    := 'ADAPTER';
    TypeTab[TI].Fields[8].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[8].Offset  := 32;
    TypeTab[TI].Fields[9].Name    := 'MONITOR';
    TypeTab[TI].Fields[9].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[9].Offset  := 36;
    TypeTab[TI].Fields[10].Name    := 'MEMORY';
    TypeTab[TI].Fields[10].TypeIdx := TY_IDX_INTEGER;
    TypeTab[TI].Fields[10].Offset  := 40;
    SI := SymAdd('_VIDEOCONFIG', SK_TYPE, TI);
    If SI >= 0 Then SymTab[SI].IsGlobal := True;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeResolve : resoudre un alias de type (BaseTypeIdx)        }
{ Suit la chaine BaseTypeIdx pour trouver le type reel         }
{ (ex: LongInt -> Integer)                                     }
{ Retourne l index du type final                               }
{ ------------------------------------------------------------ }

Function TypeResolve(Idx : Integer) : Integer;
Var
  Depth : Integer;
  Cur   : Integer;
Begin
  Cur   := Idx;
  Depth := 0;
  While (Cur >= 0) And (Cur < TypeCount) And (Depth < 32) Do
  Begin
    { Si pas d alias (BaseTypeIdx < 0), on est arrive }
    If TypeTab[Cur].BaseTypeIdx < 0 Then Break;

    { Si c est un type compose (pointeur, tableau, record, etc.) }
    { BaseTypeIdx designe le type element, pas un alias          }
    If TypeTab[Cur].Kind In [TYK_POINTER, TYK_PCHAR, TYK_ARRAY,
       TYK_RECORD, TYK_SET, TYK_ENUM, TYK_FILE,
       TYK_OBJECT, TYK_PROCVAR] Then Break;

    { Sinon c est un alias : suivre le lien }
    Cur := TypeTab[Cur].BaseTypeIdx;
    Inc(Depth);
  End;
  TypeResolve := Cur;
End;

{ ------------------------------------------------------------ }
{ TypeIsOrdinal : retourne True si le type est ordinal         }
{ (Integer, Word, Byte, ShortInt, Char, Boolean, Enum,         }
{  Subrange)                                                    }
{ ------------------------------------------------------------ }

Function TypeIsOrdinal(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsNumeric : retourne True si le type est numerique       }
{ (tout ordinal + Real, Single, Double, Extended, Comp)        }
{ ------------------------------------------------------------ }

Function TypeIsNumeric(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE,
    TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED, TYK_COMP :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsPointer : retourne True si le type est un pointeur     }
{ (Pointer, PChar, nil)                                        }
{ ------------------------------------------------------------ }

Function TypeIsPointer(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_POINTER, TYK_PCHAR, TYK_NIL :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsString : retourne True si le type est une chaine       }
{ (String, PChar)                                              }
{ ------------------------------------------------------------ }

Function TypeIsString(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsString := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_STRING, TYK_PCHAR :
      TypeIsString := True;
  Else
    TypeIsString := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsReal : retourne True si le type est un reel            }
{ (Real, Single, Double, Extended, Comp)                       }
{ ------------------------------------------------------------ }

Function TypeIsReal(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsReal := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED, TYK_COMP :
      TypeIsReal := True;
  Else
    TypeIsReal := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeCoerce : determine le type resultat d une operation       }
{ entre deux types (promotion Turbo Pascal)                    }
{ Retourne l index du type promu                               }
{ ------------------------------------------------------------ }

Function TypeCoerce(IdxA, IdxB : Integer) : Integer;
Var
  RA, RB : Integer;
  KA, KB : TTypeKind;
Begin
  RA := TypeResolve(IdxA);
  RB := TypeResolve(IdxB);

  { Si l un est invalide, retourner l autre }
  If (RA < 0) Or (RA >= TypeCount) Then
  Begin TypeCoerce := RB; Exit; End;
  If (RB < 0) Or (RB >= TypeCount) Then
  Begin TypeCoerce := RA; Exit; End;

  KA := TypeTab[RA].Kind;
  KB := TypeTab[RB].Kind;

  { Extended absorbe tout (sauf string) }
  If (KA = TYK_EXTENDED) Or (KB = TYK_EXTENDED) Then
  Begin TypeCoerce := TY_IDX_EXTENDED; Exit; End;

  { Double absorbe Real, Single, entiers }
  If (KA = TYK_DOUBLE) Or (KB = TYK_DOUBLE) Then
  Begin TypeCoerce := TY_IDX_DOUBLE; Exit; End;

  { Single absorbe Real, entiers }
  If (KA = TYK_SINGLE) Or (KB = TYK_SINGLE) Then
  Begin TypeCoerce := TY_IDX_SINGLE; Exit; End;

  { Comp absorbe entiers }
  If (KA = TYK_COMP) Or (KB = TYK_COMP) Then
  Begin TypeCoerce := TY_IDX_COMP; Exit; End;

  { Real absorbe entiers }
  If (KA = TYK_REAL) Or (KB = TYK_REAL) Then
  Begin TypeCoerce := TY_IDX_REAL; Exit; End;

  { Si un des deux est un pointeur, le resultat est un pointeur }
  If (KA In [TYK_POINTER, TYK_PCHAR]) Then
  Begin TypeCoerce := RA; Exit; End;
  If (KB In [TYK_POINTER, TYK_PCHAR]) Then
  Begin TypeCoerce := RB; Exit; End;

  { LongInt (Integer) absorbe Word, Byte, ShortInt }
  If (KA = TYK_INTEGER) Or (KB = TYK_INTEGER) Then
  Begin TypeCoerce := TY_IDX_INTEGER; Exit; End;

  { Word absorbe Byte }
  If (KA = TYK_WORD) Or (KB = TYK_WORD) Then
  Begin TypeCoerce := TY_IDX_WORD; Exit; End;

  { Sinon, promotion vers Integer }
  TypeCoerce := TY_IDX_INTEGER;
End;

{ ------------------------------------------------------------ }
{ TypeCompatible : verifie si une affectation dest := src est   }
{ compatible au sens Turbo Pascal                              }
{ Retourne True si compatible                                  }
{ ------------------------------------------------------------ }

Function TypeCompatible(IdxDest, IdxSrc : Integer) : Boolean;
Var
  RD, RS : Integer;
  KD, KS : TTypeKind;
Begin
  RD := TypeResolve(IdxDest);
  RS := TypeResolve(IdxSrc);

  { Types invalides : on accepte pour ne pas bloquer }
  If (RD < 0) Or (RD >= TypeCount) Or
     (RS < 0) Or (RS >= TypeCount) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Meme type exact : toujours compatible }
  If RD = RS Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  KD := TypeTab[RD].Kind;
  KS := TypeTab[RS].Kind;

  { nil -> tout type pointeur ou PChar }
  If KS = TYK_NIL Then
  Begin
    TypeCompatible := (KD In [TYK_POINTER, TYK_PCHAR, TYK_NIL,
                              TYK_PROCVAR, TYK_OBJECT]);
    Exit;
  End;

  { Integer <-> Word (promotion implicite TP) }
  If ((KD = TYK_INTEGER) Or (KD = TYK_WORD)) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Byte/ShortInt -> Integer ou Word (promotion implicite) }
  If ((KS = TYK_BYTE) Or (KS = TYK_SHORTINT)) And
     ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or
      (KD = TYK_BYTE) Or (KD = TYK_SHORTINT)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer/Word -> Byte/ShortInt (retrecissement implicite TP) }
  If ((KD = TYK_BYTE) Or (KD = TYK_SHORTINT)) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char -> String (promotion implicite TP) }
  If (KD = TYK_STRING) And (KS = TYK_CHAR) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Boolean -> entier (en mode etendu $X+) }
  If ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or (KD = TYK_BYTE)) And
     (KS = TYK_BOOLEAN) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Entier -> Boolean }
  If (KD = TYK_BOOLEAN) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD) Or (KS = TYK_BYTE) Or
      (KS = TYK_SHORTINT)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Numerique vers numerique : toujours OK (avec conversion) }
  If TypeIsNumeric(RD) And TypeIsNumeric(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers pointeur : compatible (type generique) }
  If TypeIsPointer(RD) And TypeIsPointer(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { PChar <-> String (en mode etendu $X+) }
  If ((KD = TYK_PCHAR) And (KS = TYK_STRING)) Or
     ((KD = TYK_STRING) And (KS = TYK_PCHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers entier / entier vers pointeur (typecast) }
  If (TypeIsPointer(RD) And TypeIsOrdinal(RS)) Or
     (TypeIsOrdinal(RD) And TypeIsPointer(RS)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Enum -> Integer (Ord implicite) }
  If (KS = TYK_ENUM) And
     ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or (KD = TYK_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Subrange : compatible avec son type de base }
  If (KD = TYK_SUBRANGE) Or (KS = TYK_SUBRANGE) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Record/Object : compatibles seulement si meme nom }
  If (KD In [TYK_RECORD, TYK_OBJECT]) And (KD = KS) Then
  Begin
    TypeCompatible := (TypeTab[RD].Name = TypeTab[RS].Name);
    Exit;
  End;

  TypeCompatible := False;
End;

{ ============================================================ }
{ TODO 07 - EMETTEUR DE CODE ASM 80386            [IMPLEMENTE] }
{ ============================================================ }

Var
  { Compteur de labels interne a l emetteur }
  EmitLabelSeq    : Integer;
  { True si un programme principal est detecte }
  HasProgram      : Boolean;
  { Nombre d entrees DataTab deja emises }
  DataEmittedCount: Integer;
  { True si le source est une unite (commence par UNIT) (TODO 27) }
  IsUnitSource    : Boolean;
  { Nom de l unite source (TODO 27) }
  UnitSourceName  : TString;

{ ------------------------------------------------------------ }
{ EmitOpen : ouvrir le fichier .ASM de sortie                  }
{ ------------------------------------------------------------ }

Procedure EmitOpen(Const AsmFile : TString);
Begin
  Assign(OutF, AsmFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier de sortie: ' + AsmFile);
  OutFOpen := True;
  EmitLabelSeq := 0;
End;

{ ------------------------------------------------------------ }
{ EmitClose : fermer le fichier de sortie                      }
{ La directive END indique le point d entree du programme       }
{ ------------------------------------------------------------ }

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    If HasProgram Then
      WriteLn(OutF, 'END ' + TP_FUNC_PFX + 'Main')
    Else
      WriteLn(OutF, 'END');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRaw : ecrire une ligne brute dans le fichier de sortie   }
{ ------------------------------------------------------------ }

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ------------------------------------------------------------ }
{ Declarations anticipees du mini-assembleur binaire           }
{ ------------------------------------------------------------ }

Procedure BcDefineLabel(Const Nm: TString); Forward;
Procedure BcAssemble(Const S: TString); Forward;
Procedure BcAssemble8086(Const S: TString); Forward;
Procedure BcAssembleZ80(Const S: TString); Forward;
Procedure BcAssemble6502(Const S: TString); Forward;
Procedure BcAssemble6809(Const S: TString); Forward;
Procedure BcAssemble68000(Const S: TString); Forward;

{ ------------------------------------------------------------ }
{ EmitLabel : ecrire un label suivi de ':'                     }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
  If BcActive Then
    BcDefineLabel(Lbl);
End;

{ ------------------------------------------------------------ }
{ EmitInstr : ecrire une instruction avec 8 espaces d indent   }
{ ------------------------------------------------------------ }

Procedure EmitInstr(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', S);
  If BcActive Then
  Begin
    If Opts.DestTarget = DEST_Z80 Then
      BcAssembleZ80(S)
    Else If Opts.DestTarget = DEST_6502 Then
      BcAssemble6502(S)
    Else If Opts.DestTarget = DEST_6809 Then
      BcAssemble6809(S)
    Else If Opts.DestTarget = DEST_68000 Then
      BcAssemble68000(S)
    Else If (Opts.DestTarget = DEST_DOSR) Or
            (Opts.DestTarget = DEST_DOSP) Then
      BcAssemble8086(S)
    Else
      BcAssemble(S);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitComment : ecrire un commentaire ('; text')               }
{ ------------------------------------------------------------ }

Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

{ ------------------------------------------------------------ }
{ EmitBlankLine : ecrire une ligne vide                        }
{ ------------------------------------------------------------ }

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generer un label unique _TPL_NNNNN               }
{ ------------------------------------------------------------ }

Function LabelGen : TString;
Begin
  Inc(EmitLabelSeq);
  LabelGen := TP_LBL_PFX + IntToStr_(EmitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ EmitHeader : emettre l en-tete ASM pour un programme Win32   }
{ .386 / .MODEL FLAT, STDCALL / EXTRN imports Win32            }
{ ------------------------------------------------------------ }

Procedure EmitHeader;
Begin
  EmitComment('TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32');
  EmitComment('Genere automatiquement a partir de : ' + Opts.SrcFile);
  EmitBlankLine;

  { Directive processeur et modele memoire }
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;

  { Declarations externes (imports Win32 kernel32.dll) }
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _ReadFile@20:NEAR');
  EmitRaw('EXTRN _WriteConsoleA@20:NEAR');
  EmitRaw('EXTRN _ReadConsoleA@20:NEAR');
  EmitRaw('EXTRN _SetConsoleCursorPosition@8:NEAR');
  EmitRaw('EXTRN _GetConsoleScreenBufferInfo@8:NEAR');
  EmitRaw('EXTRN _SetConsoleTextAttribute@8:NEAR');
  EmitRaw('EXTRN _FillConsoleOutputCharacterA@20:NEAR');
  EmitRaw('EXTRN _FillConsoleOutputAttribute@20:NEAR');
  EmitRaw('EXTRN _GetConsoleMode@8:NEAR');
  EmitRaw('EXTRN _SetConsoleMode@8:NEAR');
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitRaw('EXTRN _HeapFree@12:NEAR');
  EmitRaw('EXTRN _HeapSize@12:NEAR');
  EmitRaw('EXTRN _CreateFileA@28:NEAR');
  EmitRaw('EXTRN _CloseHandle@4:NEAR');
  EmitRaw('EXTRN _SetFilePointer@16:NEAR');
  EmitRaw('EXTRN _GetFileSize@8:NEAR');
  EmitRaw('EXTRN _DeleteFileA@4:NEAR');
  EmitRaw('EXTRN _MoveFileA@8:NEAR');
  EmitRaw('EXTRN _FlushFileBuffers@4:NEAR');
  EmitRaw('EXTRN _SetEndOfFile@4:NEAR');
  EmitRaw('EXTRN _GetLastError@0:NEAR');
  EmitRaw('EXTRN _CreateDirectoryA@8:NEAR');
  EmitRaw('EXTRN _RemoveDirectoryA@4:NEAR');
  EmitRaw('EXTRN _SetCurrentDirectoryA@4:NEAR');
  EmitRaw('EXTRN _GetCurrentDirectoryA@8:NEAR');
  EmitRaw('EXTRN _GetTickCount@0:NEAR');
  EmitRaw('EXTRN _Sleep@4:NEAR');
  EmitRaw('EXTRN _GetCommandLineA@0:NEAR');
  EmitRaw('EXTRN _PeekConsoleInputA@16:NEAR');
  EmitRaw('EXTRN _ReadConsoleInputA@16:NEAR');
  EmitRaw('EXTRN _GetNumberOfConsoleInputEvents@8:NEAR');
  EmitRaw('EXTRN _Beep@8:NEAR');
  EmitRaw('EXTRN _ScrollConsoleScreenBufferA@20:NEAR');
  EmitRaw('EXTRN _FlushConsoleInputBuffer@4:NEAR');
  EmitComment('--- Imports Win32 pour unite DOS (TODO 19) ---');
  EmitRaw('EXTRN _GetLocalTime@4:NEAR');
  EmitRaw('EXTRN _SetLocalTime@4:NEAR');
  EmitRaw('EXTRN _GetFileAttributesA@4:NEAR');
  EmitRaw('EXTRN _SetFileAttributesA@8:NEAR');
  EmitRaw('EXTRN _FindFirstFileA@8:NEAR');
  EmitRaw('EXTRN _FindNextFileA@8:NEAR');
  EmitRaw('EXTRN _FindClose@4:NEAR');
  EmitRaw('EXTRN _GetDiskFreeSpaceA@20:NEAR');
  EmitRaw('EXTRN _GetEnvironmentVariableA@12:NEAR');
  EmitRaw('EXTRN _CreateProcessA@40:NEAR');
  EmitRaw('EXTRN _WaitForSingleObject@8:NEAR');
  EmitRaw('EXTRN _GetExitCodeProcess@8:NEAR');
  EmitRaw('EXTRN _GetFullPathNameA@16:NEAR');
  EmitRaw('EXTRN _GetEnvironmentStringsA@0:NEAR');
  EmitRaw('EXTRN _GetFileTime@16:NEAR');
  EmitRaw('EXTRN _FileTimeToDosDateTime@12:NEAR');
  EmitComment('--- Imports Win32 pour unite Graph (TODO 20) ---');
  EmitComment('--- user32.dll ---');
  EmitRaw('EXTRN _RegisterClassA@4:NEAR');
  EmitRaw('EXTRN _CreateWindowExA@48:NEAR');
  EmitRaw('EXTRN _DestroyWindow@4:NEAR');
  EmitRaw('EXTRN _ShowWindow@8:NEAR');
  EmitRaw('EXTRN _UpdateWindow@4:NEAR');
  EmitRaw('EXTRN _GetDC@4:NEAR');
  EmitRaw('EXTRN _ReleaseDC@8:NEAR');
  EmitRaw('EXTRN _DefWindowProcA@16:NEAR');
  EmitRaw('EXTRN _GetClientRect@8:NEAR');
  EmitRaw('EXTRN _InvalidateRect@12:NEAR');
  EmitRaw('EXTRN _PeekMessageA@20:NEAR');
  EmitRaw('EXTRN _DispatchMessageA@4:NEAR');
  EmitRaw('EXTRN _TranslateMessage@4:NEAR');
  EmitRaw('EXTRN _PostQuitMessage@4:NEAR');
  EmitRaw('EXTRN _LoadCursorA@8:NEAR');
  EmitRaw('EXTRN _GetModuleHandleA@4:NEAR');
  EmitRaw('EXTRN _FillRect@12:NEAR');
  EmitComment('--- gdi32.dll ---');
  EmitRaw('EXTRN _SetPixel@16:NEAR');
  EmitRaw('EXTRN _GetPixel@12:NEAR');
  EmitRaw('EXTRN _MoveToEx@16:NEAR');
  EmitRaw('EXTRN _LineTo@12:NEAR');
  EmitRaw('EXTRN _Rectangle@20:NEAR');
  EmitRaw('EXTRN _Ellipse@20:NEAR');
  EmitRaw('EXTRN _Arc@36:NEAR');
  EmitRaw('EXTRN _Pie@36:NEAR');
  EmitRaw('EXTRN _CreatePen@12:NEAR');
  EmitRaw('EXTRN _CreateSolidBrush@4:NEAR');
  EmitRaw('EXTRN _SelectObject@8:NEAR');
  EmitRaw('EXTRN _DeleteObject@4:NEAR');
  EmitRaw('EXTRN _TextOutA@20:NEAR');
  EmitRaw('EXTRN _CreateFontA@56:NEAR');
  EmitRaw('EXTRN _SetBkMode@8:NEAR');
  EmitRaw('EXTRN _SetTextColor@8:NEAR');
  EmitRaw('EXTRN _SetBkColor@8:NEAR');
  EmitRaw('EXTRN _GetTextExtentPoint32A@16:NEAR');
  EmitRaw('EXTRN _CreateCompatibleDC@4:NEAR');
  EmitRaw('EXTRN _CreateCompatibleBitmap@12:NEAR');
  EmitRaw('EXTRN _BitBlt@36:NEAR');
  EmitRaw('EXTRN _DeleteDC@4:NEAR');
  EmitRaw('EXTRN _FloodFill@16:NEAR');
  EmitRaw('EXTRN _GetStockObject@4:NEAR');
  EmitRaw('EXTRN _PatBlt@24:NEAR');
  EmitRaw('EXTRN _Polyline@12:NEAR');
  EmitRaw('EXTRN _Polygon@12:NEAR');
  EmitComment('--- Imports Win32 pour unite Strings (TODO 21) ---');
  EmitComment('--- kernel32.dll ---');
  EmitRaw('EXTRN _lstrlenA@4:NEAR');
  EmitRaw('EXTRN _lstrcpyA@8:NEAR');
  EmitRaw('EXTRN _lstrcatA@8:NEAR');
  EmitRaw('EXTRN _lstrcmpA@8:NEAR');
  EmitRaw('EXTRN _lstrcmpiA@8:NEAR');
  EmitComment('--- Imports Win32 pour unite Objects (TODO 21) ---');
  EmitComment('--- kernel32.dll (fichiers pour TDosStream/TBufStream) ---');
  EmitRaw('EXTRN _CreateFileA@28:NEAR');
  EmitRaw('EXTRN _ReadFile@20:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _SetFilePointer@16:NEAR');
  EmitRaw('EXTRN _GetFileSize@8:NEAR');
  EmitRaw('EXTRN _CloseHandle@4:NEAR');
  EmitRaw('EXTRN _SetEndOfFile@4:NEAR');
  EmitRaw('EXTRN _FlushFileBuffers@4:NEAR');
  EmitComment('--- Imports Win32 pour emulation Mem/Port (TODO 22) ---');
  EmitComment('--- user32.dll ---');
  EmitRaw('EXTRN _GetAsyncKeyState@4:NEAR');
  EmitRaw('EXTRN _GetKeyState@4:NEAR');
  EmitComment('--- Imports Win32 pour emulation interruptions (TODO 23) ---');
  EmitComment('--- kernel32.dll ---');
  EmitRaw('EXTRN _SetConsoleScreenBufferSize@8:NEAR');
  EmitRaw('EXTRN _WriteConsoleOutputAttribute@20:NEAR');
  EmitComment('--- user32.dll ---');
  EmitRaw('EXTRN _GetCursorPos@4:NEAR');
  EmitRaw('EXTRN _GetSystemMetrics@4:NEAR');
  EmitRaw('EXTRN _ShowCursor@4:NEAR');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitDataSeg : emettre le segment .DATA avec toutes les       }
{ entrees du DataTab (chaines, valeurs, tableaux, reserves)    }
{ et les variables runtime du compilateur                      }
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

  { Variables runtime internes du compilateur }
  EmitComment('--- Variables runtime TPCW32 ---');
  EmitRaw('HSTDOUT   DD 0');           { handle stdout         }
  EmitRaw('HSTDIN    DD 0');           { handle stdin          }
  EmitRaw('HHEAP     DD 0');           { handle heap           }
  EmitRaw('NUMBUF    DB 32 DUP(0)');   { buffer pour nombres   }
  EmitRaw('INBUF     DB 256 DUP(0)');  { buffer pour lecture    }
  EmitRaw('BYTESWR   DD 0');           { octets ecrits         }
  EmitRaw('BYTESRD   DD 0');           { octets lus            }
  EmitRaw('CRLF      DB 13,10,0');     { retour chariot        }
  EmitRaw('STRTMP    DB 256 DUP(0)');  { buffer temp chaine    }
  EmitRaw('STRBUF1   DB 256 DUP(0)');  { buffer concat/copy    }
  EmitRaw('STRBUF2   DB 256 DUP(0)');  { buffer concat/copy 2  }
  EmitRaw('TRUE_STR  DB ''TRUE'',0');   { chaine TRUE           }
  EmitRaw('FALSE_STR DB ''FALSE'',0');  { chaine FALSE          }
  EmitBlankLine;

  { Variables CRT (TODO 18) }
  EmitComment('--- Variables CRT (emulation console) ---');
  EmitRaw('TEXTATTR  DD 7');            { attribut texte courant (gris sur noir) }
  EmitRaw('WINDMIN   DD 0');            { coin haut-gauche fenetre (0)           }
  EmitRaw('WINDMAX   DD 184Fh');        { coin bas-droite (24*256+79 = 0x184F)   }
  EmitRaw('LASTMODE  DD 3');            { dernier mode video (CO80)              }
  EmitRaw('DIRECTVIDEO DD 1');          { acces video direct (ignore Win32)      }
  EmitRaw('CHECKBREAK  DD 1');          { verification Ctrl+Break                }
  EmitRaw('CHECKEOF    DD 0');          { verification Ctrl+Z                    }
  EmitRaw('CHECKSNOW   DD 0');          { verification neige CGA (ignore Win32)  }
  EmitRaw('CRT_CSBI  DB 22 DUP(0)');   { CONSOLE_SCREEN_BUFFER_INFO (22 bytes)  }
  EmitRaw('CRT_INREC DB 20 DUP(0)');   { INPUT_RECORD buffer (20 bytes)         }
  EmitRaw('CRT_NEVT  DD 0');           { nombre d evenements console            }
  EmitRaw('CRT_NWRT  DD 0');           { nombre de cellules ecrites            }
  EmitRaw('CRT_SCROLL DB 16 DUP(0)');  { SMALL_RECT pour ScrollConsoleScreenBuffer }
  EmitRaw('CRT_FILL   DD 0,0');        { CHAR_INFO (char + attr) pour scroll fill  }
  EmitBlankLine;

  { Variables DOS (TODO 19) }
  EmitComment('--- Variables DOS (emulation unite DOS) ---');
  EmitRaw('DOSERROR  DD 0');            { variable DosError                      }
  EmitRaw('DOSEXITCODE DD 0');          { code retour dernier Exec               }
  EmitRaw('DOS_SYSTIME DB 16 DUP(0)'); { SYSTEMTIME struct (16 bytes)           }
  EmitRaw('DOS_FATTR DD 0');            { attributs fichier temporaire           }
  EmitRaw('DOS_ENVBUF DB 256 DUP(0)'); { buffer GetEnvironmentVariable          }
  EmitRaw('DOS_PATHBUF DB 260 DUP(0)');{ buffer chemin (MAX_PATH)               }
  EmitRaw('DOS_DKFREE DD 4 DUP(0)');   { 4 DWORDs pour GetDiskFreeSpace         }
  EmitRaw('DOS_FINDDATA DB 320 DUP(0)');{ WIN32_FIND_DATAA (318 bytes)          }
  EmitRaw('DOS_FINDHDL DD -1');         { handle FindFirstFile                   }
  EmitRaw('DOS_PROCINFO DB 16 DUP(0)');{ PROCESS_INFORMATION (16 bytes)         }
  EmitRaw('DOS_STARTINFO DB 68 DUP(0)');{ STARTUPINFOA (68 bytes)               }
  EmitRaw('DOS_EXITVAL DD 0');          { code sortie processus                  }
  EmitBlankLine;

  { Variables File I/O }
  EmitComment('--- Variables File I/O (lecture/ecriture fichier texte) ---');
  EmitRaw('FILE_NAMEBUF DB 260 DUP(0)');  { buffer nom fichier (MAX_PATH)    }
  EmitRaw('FILE_RENBUF  DB 260 DUP(0)');  { buffer nouveau nom (Rename)      }
  EmitRaw('FILE_RDBUF   DB 256 DUP(0)');  { buffer lecture fichier           }
  EmitRaw('FILE_BUFPOS  DD 0');            { position courante dans buffer    }
  EmitRaw('FILE_BUFEND  DD 0');            { octets valides dans buffer       }
  EmitRaw('FILE_EOFFLG  DD 0');            { 1 si EOF atteint                 }
  EmitRaw('FILE_BYTESRD DD 0');            { octets lus par ReadFile          }
  EmitRaw('FILE_WRHND   DD 0');            { handle ecriture fichier courant  }
  EmitRaw('FILE_WRFLG   DD 0');            { 1 si ecriture fichier en cours   }
  EmitRaw('FILE_IOERR   DD 0');            { derniere erreur I/O (IoResult)   }
  EmitRaw('STDIN_EOF    DD 0');            { 1 si EOF stdin (Ctrl+Z)          }
  EmitRaw('DIR_NAMEBUF  DB 260 DUP(0)');  { buffer repertoire (MAX_PATH)     }
  EmitRaw('RAND_SEED    DD 12345');          { graine Random (LCG)             }
  EmitRaw('FP_TMP       DQ 0');              { buffer temporaire FPU 8 octets  }
  EmitBlankLine;

  { Variables ParamStr/ParamCount }
  EmitComment('--- Variables ParamStr/ParamCount ---');
  EmitRaw('PARAM_PARSED DD 0');          { 1 si deja parse                        }
  EmitRaw('PARAM_COUNT  DD 0');          { nombre de parametres (sans argv[0])    }
  EmitRaw('PARAM_ARGC   DD 0');          { nombre total d arguments (avec argv[0])}
  EmitRaw('PARAM_PTRS   DD 64 DUP(0)'); { pointeurs vers chaque argument         }
  EmitRaw('PARAM_BUF    DB 1024 DUP(0)');{ copie de la ligne de commande          }
  EmitBlankLine;

  { Variables Graph (TODO 20) }
  EmitComment('--- Variables Graph (emulation graphique Windows) ---');
  EmitRaw('GR_RESULT   DD 0');            { GraphResult code (grOk=0)              }
  EmitRaw('GR_DRIVER   DD 0');            { pilote graphique (Detect=0,VGA=9)      }
  EmitRaw('GR_MODE     DD 0');            { mode graphique (VGAHi=2)               }
  EmitRaw('GR_HWND     DD 0');            { handle fenetre graphique               }
  EmitRaw('GR_HDC      DD 0');            { handle device context                  }
  EmitRaw('GR_HPEN     DD 0');            { handle pen courant                     }
  EmitRaw('GR_HBRUSH   DD 0');            { handle brush courant                   }
  EmitRaw('GR_HFONT    DD 0');            { handle font courant                    }
  EmitRaw('GR_HINST    DD 0');            { hInstance du module                    }
  EmitRaw('GR_MAXX     DD 639');          { largeur max (640-1)                    }
  EmitRaw('GR_MAXY     DD 479');          { hauteur max (480-1)                    }
  EmitRaw('GR_COLOR    DD 15');           { couleur de dessin courante (blanc)     }
  EmitRaw('GR_BKCOLOR  DD 0');            { couleur de fond (noir)                 }
  EmitRaw('GR_FILLCOLOR DD 0');           { couleur de remplissage                 }
  EmitRaw('GR_FILLSTYLE DD 1');           { style de remplissage (SolidFill=1)     }
  EmitRaw('GR_LINESTYLE DD 0');           { style de ligne (SolidLn=0)             }
  EmitRaw('GR_LINEWIDTH DD 1');           { epaisseur de ligne (NormWidth=1)       }
  EmitRaw('GR_WRITEMODE DD 0');           { mode d ecriture (CopyPut=0)            }
  EmitRaw('GR_CPX      DD 0');            { position X courante (current pointer)  }
  EmitRaw('GR_CPY      DD 0');            { position Y courante (current pointer)  }
  EmitRaw('GR_VPXL     DD 0');            { viewport gauche                        }
  EmitRaw('GR_VPYT     DD 0');            { viewport haut                          }
  EmitRaw('GR_VPXR     DD 639');          { viewport droite                        }
  EmitRaw('GR_VPYB     DD 479');          { viewport bas                           }
  EmitRaw('GR_VPCLIP   DD 1');            { viewport clipping actif                }
  EmitRaw('GR_TXFONT   DD 0');            { fonte texte (DefaultFont=0)            }
  EmitRaw('GR_TXDIR    DD 0');            { direction texte (HorizDir=0)           }
  EmitRaw('GR_TXSIZE   DD 1');            { taille texte (1=normal)                }
  EmitRaw('GR_ACTIVE   DD 0');            { 1 si mode graphique actif              }
  EmitRaw('GR_MAXCOLOR DD 15');           { nombre max de couleurs                 }
  EmitRaw('GR_WNDCLASS DB ''TPGraphWnd'',0');  { nom classe fenetre               }
  EmitRaw('GR_WNDTITLE DB ''Turbo Pascal Graphics'',0'); { titre fenetre          }
  EmitRaw('GR_CLSREC   DB 40 DUP(0)');   { WNDCLASSA (40 bytes)                   }
  EmitRaw('GR_RECT     DD 4 DUP(0)');    { RECT (16 bytes)                        }
  EmitRaw('GR_MSG      DB 28 DUP(0)');   { MSG struct (28 bytes)                  }
  EmitRaw('GR_TXBUF    DB 256 DUP(0)');  { buffer texte temporaire                }
  EmitRaw('GR_TXSIZE2  DD 2 DUP(0)');    { SIZE struct pour GetTextExtent (8 b)   }
  { Palette EGA/VGA 16 couleurs -> COLORREF (BGR) }
  EmitRaw('GR_PALETTE  DD 000000h');      {  0 Black       }
  EmitRaw('            DD 0AA0000h');     {  1 Blue        }
  EmitRaw('            DD 000AA00h');     {  2 Green       }
  EmitRaw('            DD 0AAAA00h');     {  3 Cyan        }
  EmitRaw('            DD 00000AAh');     {  4 Red         }
  EmitRaw('            DD 0AA00AAh');     {  5 Magenta     }
  EmitRaw('            DD 00055AAh');     {  6 Brown       }
  EmitRaw('            DD 0AAAAAAh');     {  7 LightGray   }
  EmitRaw('            DD 0555555h');     {  8 DarkGray    }
  EmitRaw('            DD 0FF5555h');     {  9 LightBlue   }
  EmitRaw('            DD 055FF55h');     { 10 LightGreen  }
  EmitRaw('            DD 0FFFF55h');     { 11 LightCyan   }
  EmitRaw('            DD 05555FFh');     { 12 LightRed    }
  EmitRaw('            DD 0FF55FFh');     { 13 LightMagenta}
  EmitRaw('            DD 055FFFFh');     { 14 Yellow      }
  EmitRaw('            DD 0FFFFFFh');     { 15 White       }
  EmitRaw('GR_ERRMSG0  DB ''No error'',0');
  EmitRaw('GR_ERRMSG1  DB ''(BGI) graphics not installed'',0');
  EmitRaw('GR_ERRMSG2  DB ''Graphics hardware not detected'',0');
  EmitRaw('GR_DRVNAME  DB ''EGAVGA'',0'); { nom pilote par defaut                 }
  EmitRaw('GR_MODNAME  DB ''640x480x16'',0'); { nom mode par defaut               }
  EmitRaw('GR_TXJUST_H DD 0');            { text justify horiz (LeftText=0)        }
  EmitRaw('GR_TXJUST_V DD 2');            { text justify vert (TopText=2)          }
  EmitRaw('GR_ARCX     DD 0');            { arc last X                             }
  EmitRaw('GR_ARCY     DD 0');            { arc last Y                             }
  EmitRaw('GR_ARCXS    DD 0');            { arc start X                            }
  EmitRaw('GR_ARCYS    DD 0');            { arc start Y                            }
  EmitRaw('GR_ARCXE    DD 0');            { arc end X                              }
  EmitRaw('GR_ARCYE    DD 0');            { arc end Y                              }
  { _VideoConfig record : 11 x DD = 44 bytes }
  EmitRaw('GR_VIDCFG   DD 11 DUP(0)');    { _VideoConfig interne                   }
  EmitBlankLine;

  { Variables Strings / Printer / Overlay (TODO 21) }
  EmitComment('--- Variables Strings (unite Strings emulation) ---');
  EmitRaw('STR_TMPBUF  DB 256 DUP(0)');  { buffer temporaire pour conversions     }
  EmitRaw('STR_PASBUF  DB 256 DUP(0)');  { buffer pour StrPas (PChar->Pascal)     }
  EmitComment('--- Variables Printer (unite Printer emulation) ---');
  EmitRaw('PRN_HANDLE  DD -1');          { handle fichier imprimante (NUL)        }
  EmitRaw('PRN_FNAME   DB ''NUL'',0');   { nom fichier imprimante par defaut      }
  EmitComment('--- Variables Overlay (stubs) ---');
  EmitRaw('OVR_RESULT  DD 0');           { ovrOk = 0                              }
  EmitRaw('OVR_BUFSIZE DD 0');           { taille buffer overlay                  }
  EmitComment('--- Variables Objects (unite Objects emulation TODO 21) ---');
  EmitRaw('OBJ_STATUS  DD 0');           { stOk = 0, stError, etc.               }
  EmitRaw('OBJ_STRBUF  DB 256 DUP(0)'); { buffer pour NewStr                    }
  EmitRaw('OBJ_TMPHDL  DD -1');          { handle fichier temporaire             }
  EmitRaw('OBJ_TMPPOS  DD 0');           { position courante stream              }
  EmitRaw('OBJ_TMPSIZ  DD 0');           { taille courante stream                }
  EmitRaw('OBJ_TMPBUF  DB 1024 DUP(0)');{ buffer TBufStream                     }
  EmitRaw('OBJ_BYTESRW DD 0');           { octets lus/ecrits                     }
  EmitBlankLine;
  EmitComment('--- Variables Mem/Port (emulation TODO 22) ---');
  EmitRaw('MEM_TMPVAL  DD 0');           { valeur temporaire lecture Mem          }
  EmitRaw('PORT_TMPVAL DD 0');           { valeur temporaire lecture Port         }
  EmitRaw('PORT_RTCIDX DB 0');           { index CMOS RTC ($70)                  }
  EmitBlankLine;
  EmitComment('--- Variables interruptions (emulation TODO 23) ---');
  EmitRaw('INT_VIDEOMODE DB 3');         { mode video emule (03h=texte 80x25)    }
  EmitRaw('INT_CURSORX   DB 0');         { position curseur X (colonne)           }
  EmitRaw('INT_CURSORY   DB 0');         { position curseur Y (ligne)             }
  EmitRaw('INT_CURPAGE   DB 0');         { page video active                      }
  EmitRaw('INT_MOUSEBTNS DD 0');         { boutons souris (bit 0=left,1=right)   }
  EmitRaw('INT_MOUSEX    DD 0');         { position souris X                      }
  EmitRaw('INT_MOUSEY    DD 0');         { position souris Y                      }
  EmitRaw('INT_MOUSEVIS  DD 0');         { visibilite curseur souris              }
  EmitRaw('INT_KBCHAR    DB 0');         { dernier caractere lu clavier           }
  EmitRaw('INT_KBSCAN    DB 0');         { dernier scan code lu clavier           }
  EmitRaw('INT_CSBI      DB 24 DUP(0)');{ CONSOLE_SCREEN_BUFFER_INFO (22 bytes)  }
  EmitRaw('INT_CURPOS    DD 0,0');       { POINT pour GetCursorPos (8 bytes)      }
  EmitRaw('INT_INPREC    DB 32 DUP(0)');{ INPUT_RECORD buffer (20+ bytes)        }
  EmitRaw('INT_INEVCNT   DD 0');         { nombre d evenements console            }
  EmitBlankLine;

  { Emettre toutes les entrees du pool de donnees }
  EmitComment('--- Constantes et donnees utilisateur ---');
  For I := DataEmittedCount To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_STR:
      Begin
        { Regrouper les caracteres imprimables dans des literals }
        { et les non-imprimables en valeurs numeriques           }
        S := '';
        J := 1;
        While J <= Length(DataTab[I].StrVal) Do
        Begin
          C := DataTab[I].StrVal[J];
          If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
          Begin
            { Debut ou continuation d un groupe imprimable }
            If S <> '' Then
              S := S + ',';
            S := S + '''';
            While (J <= Length(DataTab[I].StrVal)) Do
            Begin
              C := DataTab[I].StrVal[J];
              If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
              Begin
                S := S + C;
                Inc(J);
              End
              Else
                Break;
            End;
            S := S + '''';
          End
          Else
          Begin
            { Caractere non-imprimable -> valeur numerique }
            If S <> '' Then
              S := S + ',';
            S := S + IntToStr_(Ord(C));
            Inc(J);
          End;
        End;
        { Ajouter le terminateur nul }
        If S = '' Then
          S := '0'
        Else
          S := S + ',0';
        EmitRaw(DataTab[I].LblName + '  DB ' + S);
      End;

      DK_DWORD:
      Begin
        EmitRaw(DataTab[I].LblName + '  DD ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_BYTE:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_ARRAY:
      Begin
        If DataTab[I].ElemSize = 1 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount * DataTab[I].ElemSize) +
                  ' DUP(0)');
      End;

      DK_RES:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal) + ' DUP(0)');
      End;

      DK_STRUCT:
      Begin
        { Structure : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;

      DK_ZERO:
      Begin
        { Espace initialise a zero : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;
    End; { case }
  End;
  EmitBlankLine;
  DataEmittedCount := DataCount;
End;

{ ------------------------------------------------------------ }
{ EmitCodeSeg : emettre le debut du segment .CODE              }
{ ------------------------------------------------------------ }

Procedure EmitCodeSeg;
Begin
  EmitComment('--- Segment de code ---');
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitProlog : emettre le prologue d une fonction/procedure     }
{ PUSH EBP / MOV EBP,ESP / SUB ESP,locals                     }
{ ------------------------------------------------------------ }

Procedure EmitProlog(LocalSize : Integer);
Begin
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  If LocalSize > 0 Then
    EmitInstr('SUB ESP,' + IntToStr_(LocalSize));
End;

{ ------------------------------------------------------------ }
{ EmitEpilog : emettre l epilogue d une fonction/procedure      }
{ MOV ESP,EBP / POP EBP / RET                                 }
{ ------------------------------------------------------------ }

Procedure EmitEpilog;
Begin
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 08 - SEGMENT DE DONNEES ET STATIQUES    [IMPLEMENTE]    }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ StaticVarSeq : compteur pour generer des labels statiques    }
{ uniques de la forme _TPST_1, _TPST_2, ...                   }
{ ------------------------------------------------------------ }

Var
  StaticVarSeq : Integer;

{ ------------------------------------------------------------ }
{ DataAddGlobalVar : creer une entree dans le DataTab pour une }
{ variable globale Pascal avec label _TPV_nom                  }
{ TypeName est le nom du type (INTEGER, CHAR, etc.)            }
{ Retourne l index dans DataTab ou -1                          }
{ ------------------------------------------------------------ }

Function DataAddGlobalVar(Const Name : TString;
                          Const TypeName : TString;
                          InitVal : LongInt) : Integer;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Lbl := TP_VAR_PFX + StrUpperCase(Name);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4; { defaut : 32 bits }

  { Chaine (STRING) et types chaines du DOS : DB N DUP(0) }
  If (Up = 'STRING') Or (Up = 'CSTRING') Or (Up = 'DIRSTR') Or
     (Up = 'NAMESTR') Or
     (Up = 'EXTSTR') Or (Up = 'PATHSTR') Or (Up = 'COMSTR') Then
  Begin
    DataAddGlobalVar := DataAdd(Lbl, DK_ARRAY, 0, '', Sz, 1);
    Exit;
  End;

  { Type 1 octet : CHAR, BOOLEAN, BYTE, SHORTINT }
  If Sz = 1 Then
  Begin
    DataAddGlobalVar := DataAddByte(Lbl, InitVal);
    Exit;
  End;

  { Type 2 octets : WORD (en 16-bit, mais Win32 = 4 en general) }
  { Type 4 octets : INTEGER, LONGINT, POINTER, PCHAR, TEXT }
  { Type 8 octets : DOUBLE, COMP }
  { Type 10 octets : EXTENDED }
  If Sz <= 4 Then
    DataAddGlobalVar := DataAddDWord(Lbl, InitVal)
  Else
    DataAddGlobalVar := DataAddRes(Lbl, Sz);
End;

{ ------------------------------------------------------------ }
{ DataAddTypedConst : creer une entree dans le DataTab pour    }
{ une constante typee (CONST x: Integer = 42)                 }
{ avec label _TPV_nom et valeur initiale                      }
{ Retourne l index dans DataTab ou -1                          }
{ ------------------------------------------------------------ }

Function DataAddTypedConst(Const Name : TString;
                           Const TypeName : TString;
                           InitVal : LongInt;
                           Const InitStr : TString) : Integer;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Lbl := TP_VAR_PFX + StrUpperCase(Name);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4;

  { Chaine (STRING) : DB 'contenu',0 }
  If (Up = 'STRING') Or (Up = 'CSTRING') Or (Up = 'PCHAR') Then
  Begin
    If InitStr <> '' Then
      DataAddTypedConst := DataAdd(Lbl, DK_STR, 0, InitStr, 0, 0)
    Else
      DataAddTypedConst := DataAdd(Lbl, DK_ARRAY, 0, '', 256, 1);
    Exit;
  End;

  { Type 1 octet : CHAR, BOOLEAN, BYTE, SHORTINT }
  If Sz = 1 Then
  Begin
    DataAddTypedConst := DataAddByte(Lbl, InitVal);
    Exit;
  End;

  { Type 4 octets et plus }
  If Sz <= 4 Then
    DataAddTypedConst := DataAddDWord(Lbl, InitVal)
  Else
    DataAddTypedConst := DataAddRes(Lbl, Sz);
End;

{ ------------------------------------------------------------ }
{ DataAddStaticVar : creer une variable statique avec un label }
{ unique _TPST_N (pour variables locales statiques)            }
{ Retourne le label genere                                     }
{ ------------------------------------------------------------ }

Function DataAddStaticVar(Const TypeName : TString;
                          InitVal : LongInt) : TString;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Inc(StaticVarSeq);
  Lbl := TP_STA_PFX + IntToStr_(StaticVarSeq);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4;

  If (Up = 'STRING') Or (Up = 'CSTRING') Then
    DataAdd(Lbl, DK_ARRAY, 0, '', 256, 1)
  Else If Sz = 1 Then
    DataAddByte(Lbl, InitVal)
  Else If Sz <= 4 Then
    DataAddDWord(Lbl, InitVal)
  Else
    DataAddRes(Lbl, Sz);

  DataAddStaticVar := Lbl;
End;

{ ------------------------------------------------------------ }
{ ParseDataDecls : scanner le TokenPool pour trouver les       }
{ sections VAR et CONST au niveau global (scope 0).            }
{ Cree les entrees DataTab et enregistre les symboles.         }
{ Appele avant EmitDataSeg.                                    }
{ ------------------------------------------------------------ }

{ Forward declaration pour SkipToMatchingEnd (TODO 09) }
Procedure SkipToMatchingEnd(Var I : Integer); Forward;

Procedure ParseDataDecls;
Var
  I       : Integer;
  Depth   : Integer;  { profondeur BEGIN/END }
  Names   : Array[0..63] Of TString;
  NCount  : Integer;
  TName   : TString;
  TIdx    : Integer;
  DIdx    : Integer;
  SIdx    : Integer;
  J       : Integer;
  InitVal : LongInt;
  InitStr : TString;
  VName   : TString;
  Up      : TString;
  ArrLo   : LongInt;
  ArrHi   : LongInt;
  ArrElem : LongInt;
  ElemType: TString;
  ElemSz  : Integer;
  FOfs    : Integer;
  FC      : Integer;
  FName   : TString;
  FTName  : TString;
  FTIdx   : Integer;
  FSz     : Integer;
  BaseTN  : TString;
  BTIdx   : Integer;
Begin
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    { Suivre la profondeur BEGIN/END pour rester au niveau global }
    If (TokenPool[I].Kind = TK_KEYWORD) Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      { Incrémenter depth sur BEGIN, RECORD, CASE, REPEAT }
      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'CASE') Or
         (Up = 'REPEAT') Or (Up = 'ASM') Then
      Begin
        Inc(Depth);
        Inc(I);
        Continue;
      End;

      { Décrémenter depth sur END }
      If Up = 'END' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
        Inc(I);
        Continue;
      End;

      { UNTIL ne change pas le depth mais c'est la fin d'un REPEAT }
      If Up = 'UNTIL' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
        Inc(I);
        Continue;
      End;

      { Si on est dans un bloc imbrique, avancer sans traiter }
      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { ====== Traitement au niveau global (Depth = 0) ====== }

      { --- Section VAR --- }
      If Up = 'VAR' Then
      Begin
        Inc(I); { sauter 'VAR' }

        { Parser les declarations de variables }
        { Format: name1, name2 : TypeName; name3 : TypeName; ... }
        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section ou BEGIN, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Or
               (Up = 'SEGMENT') Then
              Break;
          End;

          { Collecter les noms de variables (separes par des virgules) }
          NCount := 0;
          While (I < TokenCount) And
                (TokenPool[I].Kind = TK_IDENT) Do
          Begin
            If NCount < 64 Then
            Begin
              Names[NCount] := StrUpperCase(TokenPool[I].Val);
              Inc(NCount);
            End;
            Inc(I);
            { Si virgule, continuer a collecter }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ',') Then
              Inc(I)  { sauter la virgule }
            Else
              Break;
          End;

          { Si aucun nom collecte, avancer et essayer encore }
          If NCount = 0 Then
          Begin
            Inc(I);
            Continue;
          End;

          { Attendre ':' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
            Inc(I) { sauter ':' }
          Else
          Begin
            { Pas de ':' -> erreur de syntaxe, avancer au ';' }
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Lire le type }
          TName := '';
          TIdx  := -1;

          { Verifier si c'est ARRAY[lo..hi] OF TypeElem }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'ARRAY') Then
          Begin
            Inc(I); { sauter 'ARRAY' }
            ArrLo := 0;
            ArrHi := 0;
            ElemType := 'INTEGER';

            { Attendre '[' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '[') Then
            Begin
              Inc(I); { sauter '[' }
              { Lire borne basse }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrLo := TokenPool[I].IntVal;
                Inc(I);
              End;
              { Attendre '..' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = '..') Then
                Inc(I);
              { Lire borne haute }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrHi := TokenPool[I].IntVal;
                Inc(I);
              End;
              { Attendre ']' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ']') Then
                Inc(I);
            End;
            { Attendre 'OF' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);
            { Lire le type d element }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              ElemType := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            ArrElem := ArrHi - ArrLo + 1;
            If ArrElem < 1 Then ArrElem := 1;
            ElemSz := TPTypeSizeof(ElemType);
            If ElemSz < 0 Then
            Begin
              BTIdx := TypeFindByName(ElemType);
              If BTIdx >= 0 Then ElemSz := TypeTab[BTIdx].Size
              Else ElemSz := 4;
            End;

            { Creer un type tableau anonyme }
            TIdx := TypeAdd(TYK_ARRAY, '', ArrElem * ElemSz, 4, False, -1);
            If TIdx >= 0 Then
            Begin
              TypeTab[TIdx].Lo := ArrLo;
              TypeTab[TIdx].Hi := ArrHi;
              BTIdx := TypeFindByName(ElemType);
              If BTIdx < 0 Then BTIdx := TY_IDX_INTEGER;
              TypeTab[TIdx].BaseTypeIdx := BTIdx;
            End;

            { Creer une entree tableau pour chaque variable }
            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddArray(TP_VAR_PFX + Names[J],
                                    ArrElem, ElemSz);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            { Avancer au ';' }
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Verifier si c'est RECORD ... END }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'RECORD') Then
          Begin
            Inc(I);
            { Creer un type record anonyme }
            TIdx := TypeAdd(TYK_RECORD, '', 0, 4, False, -1);
            FOfs := 0;
            FC := 0;

            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;
              If TokenPool[I].Kind <> TK_IDENT Then
              Begin
                Inc(I);
                Continue;
              End;
              FName := StrUpperCase(TokenPool[I].Val);
              Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I);
              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;
              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then FSz := TypeTab[FTIdx].Size
                Else FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;
              If (TIdx >= 0) And (FC < MAX_FIELDS) Then
              Begin
                TypeTab[TIdx].Fields[FC].Name    := FName;
                TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                Inc(FC);
                TypeTab[TIdx].FieldCount := FC;
                FOfs := FOfs + FSz;
                TypeTab[TIdx].Size := FOfs;
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], FOfs);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Verifier si c'est SET OF T }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'SET') Then
          Begin
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);
            BaseTN := 'BYTE';
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              BaseTN := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx < 0 Then BTIdx := TY_IDX_BYTE;
            TIdx := TypeAdd(TYK_SET, '', 32, 4, False, BTIdx);

            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], 32);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Type enumere inline : (val1, val2, ...) }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = '(') Then
          Begin
            Inc(I); { sauter '(' }
            TIdx := TypeAdd(TYK_ENUM, '', 4, 4, False, -1);
            FC := 0;
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ')')) Do
            Begin
              If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                SIdx := SymAdd(StrUpperCase(TokenPool[I].Val), SK_CONST, TIdx);
                If SIdx >= 0 Then
                  SymTab[SIdx].ImmVal := FC;
                Inc(FC);
              End;
              Inc(I);
            End;
            If I < TokenCount Then Inc(I); { sauter ')' }
            If TIdx >= 0 Then
              TypeTab[TIdx].EnumCount := FC;

            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddDWord(TP_VAR_PFX + Names[J], 0);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Type simple : lire un identifiant ou mot-cle }
          If (I < TokenCount) And
             ((TokenPool[I].Kind = TK_IDENT) Or
              (TokenPool[I].Kind = TK_KEYWORD)) Then
          Begin
            TName := StrUpperCase(TokenPool[I].Val);
            Inc(I);
          End;

          { Verifier type pointeur ^Type }
          If (I < TokenCount) And (TName = '') And
             (TokenPool[I].Kind = TK_OP) And
             (TokenPool[I].Val = '^') Then
          Begin
            Inc(I); { sauter '^' }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := '^' + StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End
            Else
              TName := 'POINTER';
          End;

          If TName = '' Then TName := 'INTEGER';

          { Trouver le type dans TypeTab }
          TIdx := TypeFindByName(TName);

          { Verifier si c'est une declaration ABSOLUTE (TODO 28) }
          { Syntaxe : var X : Type absolute $Seg:$Ofs;           }
          {           var X : Type absolute OtherVar;             }
          If (I < TokenCount) And
             ((TokenPool[I].Kind = TK_IDENT) Or
              (TokenPool[I].Kind = TK_KEYWORD)) And
             (StrUpperCase(TokenPool[I].Val) = 'ABSOLUTE') Then
          Begin
            Inc(I); { sauter 'ABSOLUTE' }
            { Lire le segment (valeur hex ou decimale) }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
            Begin
              ArrLo := TokenPool[I].IntVal;  { segment }
              Inc(I);
              { Attendre ':' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
              Begin
                Inc(I);
                { Lire l'offset }
                If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
                Begin
                  ArrHi := TokenPool[I].IntVal;  { offset }
                  Inc(I);
                End
                Else
                  ArrHi := 0;
                { Creer la variable absolute pour chaque nom }
                For J := 0 To NCount - 1 Do
                Begin
                  DIdx := DataAddGlobalVar(Names[J], TName, 0);
                  SIdx := SymAdd(Names[J], SK_VAR, TIdx);
                  If SIdx >= 0 Then
                  Begin
                    SymTab[SIdx].IsGlobal   := True;
                    SymTab[SIdx].Offset     := DIdx;
                    SymTab[SIdx].IsAbsolute := True;
                    SymTab[SIdx].AbsSeg     := ArrLo;
                    SymTab[SIdx].AbsOfs     := ArrHi;
                  End;
                End;
              End
              Else
              Begin
                { Pas de ':' -> absolute sur une autre variable (absolute Var) }
                For J := 0 To NCount - 1 Do
                Begin
                  DIdx := DataAddGlobalVar(Names[J], TName, 0);
                  SIdx := SymAdd(Names[J], SK_VAR, TIdx);
                  If SIdx >= 0 Then
                  Begin
                    SymTab[SIdx].IsGlobal := True;
                    SymTab[SIdx].Offset   := DIdx;
                  End;
                End;
              End;
            End
            Else
            Begin
              { absolute suivi d'un identifiant (variable overlay) }
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
                Inc(I); { sauter le nom de variable }
              For J := 0 To NCount - 1 Do
              Begin
                DIdx := DataAddGlobalVar(Names[J], TName, 0);
                SIdx := SymAdd(Names[J], SK_VAR, TIdx);
                If SIdx >= 0 Then
                Begin
                  SymTab[SIdx].IsGlobal := True;
                  SymTab[SIdx].Offset   := DIdx;
                End;
              End;
            End;

            { Avancer au ';' }
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Creer les entrees DataTab et SymTab pour chaque variable }
          For J := 0 To NCount - 1 Do
          Begin
            { Utiliser DataAddStruct pour les types structures }
            If (TIdx >= 0) And (TIdx < TypeCount) And
               ((TypeTab[TIdx].Kind = TYK_RECORD) Or
                (TypeTab[TIdx].Kind = TYK_OBJECT) Or
                (TypeTab[TIdx].Kind = TYK_SET)) Then
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], TypeTab[TIdx].Size)
            Else If (TIdx >= 0) And (TIdx < TypeCount) And
                    (TypeTab[TIdx].Kind = TYK_ARRAY) Then
              DIdx := DataAddArray(TP_VAR_PFX + Names[J],
                TypeTab[TIdx].Hi - TypeTab[TIdx].Lo + 1,
                TypeSizeofIdx(TypeTab[TIdx].BaseTypeIdx))
            Else
              DIdx := DataAddGlobalVar(Names[J], TName, 0);
            SIdx := SymAdd(Names[J], SK_VAR, TIdx);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].Offset   := DIdx;
            End;
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End; { while parsing VAR block }
        Continue;
      End; { VAR }

      { --- Section CONST --- }
      If Up = 'CONST' Then
      Begin
        Inc(I); { sauter 'CONST' }

        { Parser les declarations de constantes }
        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Or
               (Up = 'SEGMENT') Then
              Break;
          End;

          { Lire le nom de la constante }
          If (TokenPool[I].Kind <> TK_IDENT) Then
          Begin
            Inc(I);
            Continue;
          End;
          VName := StrUpperCase(TokenPool[I].Val);
          Inc(I);

          { Determiner si c est une constante typee (nom : Type = val) }
          { ou non-typee (nom = val) }
          TName := '';
          InitVal := 0;
          InitStr := '';

          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
          Begin
            { Constante typee : nom : Type = val }
            Inc(I); { sauter ':' }

            { Lire le type }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            { Attendre '=' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
               (TokenPool[I].Val = '=') Then
              Inc(I);

            { Lire la valeur }
            If (I < TokenCount) Then
            Begin
              If (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_CHAR) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_STRING) Then
              Begin
                InitStr := TokenPool[I].Val;
                { Si le type est CHAR et la valeur est un seul caractere }
                If (TName = 'CHAR') And (Length(InitStr) = 1) Then
                Begin
                  InitVal := Ord(InitStr[1]);
                  InitStr := '';
                End;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If Up = 'TRUE' Then
                  InitVal := 1
                Else If Up = 'FALSE' Then
                  InitVal := 0
                Else If Up = 'NIL' Then
                  InitVal := 0;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                { Peut etre une constante nommee deja definie }
                SIdx := SymFind(TokenPool[I].Val);
                If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_CONST) Then
                  InitVal := SymTab[SIdx].ImmVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_OP) And
                      (TokenPool[I].Val = '-') Then
              Begin
                { Valeur negative }
                Inc(I);
                If (I < TokenCount) And
                   (TokenPool[I].Kind = TK_INTEGER) Then
                Begin
                  InitVal := -TokenPool[I].IntVal;
                  Inc(I);
                End;
              End;
            End;

            TIdx := TypeFindByName(TName);

            { Creer l entree DataTab }
            If InitStr <> '' Then
              DIdx := DataAddTypedConst(VName, TName, InitVal, InitStr)
            Else
              DIdx := DataAddTypedConst(VName, TName, InitVal, '');

            { Enregistrer dans SymTab comme SK_CONST }
            SIdx := SymAdd(VName, SK_CONST, TIdx);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].ImmVal   := InitVal;
              SymTab[SIdx].Offset   := DIdx;
            End;
          End
          Else If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
                  (TokenPool[I].Val = '=') Then
          Begin
            { Constante non-typee : nom = val }
            Inc(I); { sauter '=' }
            InitVal := 0;
            InitStr := '';

            If (I < TokenCount) Then
            Begin
              If (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_CHAR) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_STRING) Then
              Begin
                InitStr := TokenPool[I].Val;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If Up = 'TRUE' Then
                  InitVal := 1
                Else If Up = 'FALSE' Then
                  InitVal := 0
                Else If Up = 'NIL' Then
                  InitVal := 0
                Else If Up = 'MAXINT' Then
                  InitVal := 2147483647;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                { Peut etre une constante nommee }
                SIdx := SymFind(TokenPool[I].Val);
                If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_CONST) Then
                  InitVal := SymTab[SIdx].ImmVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_OP) And
                      (TokenPool[I].Val = '-') Then
              Begin
                Inc(I);
                If (I < TokenCount) And
                   (TokenPool[I].Kind = TK_INTEGER) Then
                Begin
                  InitVal := -TokenPool[I].IntVal;
                  Inc(I);
                End;
              End
              Else If (TokenPool[I].Kind = TK_REAL) Then
              Begin
                { Constante reelle : stocker la partie entiere }
                InitVal := Trunc(TokenPool[I].RealVal);
                Inc(I);
              End;
            End;

            { Constante non-typee : juste registrer dans SymTab }
            SIdx := SymAdd(VName, SK_CONST, -1);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].ImmVal   := InitVal;
            End;
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End; { while parsing CONST block }
        Continue;
      End; { CONST }

      { --- Section SEGMENT PROCEDURE/FUNCTION (Apple Pascal) : sauter SEGMENT --- }
      If (Up = 'SEGMENT') And Opts.ApplePascal Then
      Begin
        Inc(I); { sauter SEGMENT, la boucle traitera PROCEDURE/FUNCTION }
        Continue;
      End;

      { --- Section PROCEDURE ou FUNCTION : sauter entierement --- }
      If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
      Begin
        { Avancer jusqu au BEGIN puis au END correspondant }
        Inc(I);
        While (I < TokenCount) Do
        Begin
          If ((TokenPool[I].Kind = TK_KEYWORD) Or
              (TokenPool[I].Kind = TK_IDENT)) And
             (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
          Begin
            { Declaration FORWARD : avancer jusqu au ';' }
            Inc(I);
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Break;
          End;
          If (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
          Begin
            Inc(I);
            SkipToMatchingEnd(I);
            { Sauter le ';' apres END }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Break;
          End;
          Inc(I);
        End;
        Continue;
      End;

    End; { if keyword }

    { Avancer au token suivant }
    Inc(I);
  End; { while I < TokenCount }
End;

{ ============================================================ }
{ TODO 09 - VARIABLES ET AFFECTATIONS              [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_PROC  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};   { max procedures/fonctions }
  MAX_LOCAL = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { max variables locales par proc }
  MAX_PARAM = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { max parametres par proc }

Type
  { Un parametre de procedure/fonction }
  TParamRec = Record
    Name    : TString;     { nom du parametre (majuscules)         }
    TypeIdx : Integer;     { index du type dans TypeTab             }
    Offset  : Integer;     { offset dans la pile [EBP+N]           }
    IsVar   : Boolean;     { parametre VAR (par reference) ?       }
    IsConst : Boolean;     { parametre CONST (lecture seule) ?     }
  End;

  { Une variable locale }
  TLocalVar = Record
    Name      : TString;     { nom de la variable (majuscules)      }
    TypeIdx   : Integer;     { index du type dans TypeTab            }
    Offset    : Integer;     { offset dans la pile [EBP-N]          }
    Size      : Integer;     { taille en octets                     }
    IsStatic  : Boolean;     { variable statique (ABSOLUTE) ?       }
    StaticLbl : TString;     { label statique (_TPST_N)             }
    InitVal   : LongInt;     { valeur initiale                      }
    HasInit   : Boolean;     { a une initialisation ?               }
  End;

  { Information sur une procedure/fonction }
  TProcInfo = Record
    Name        : TString;     { nom (majuscules)                     }
    MangledName : TString;     { nom mangled (_TPF_XXX)               }
    IsFunction  : Boolean;     { True = function, False = procedure   }
    RetTypeIdx  : Integer;     { type de retour (-1 si procedure)     }
    ParamCount  : Integer;     { nombre de parametres                 }
    Params      : Array[0..MAX_PARAM - 1] Of TParamRec;
    LocalCount  : Integer;     { nombre de variables locales          }
    Locals      : Array[0..MAX_LOCAL - 1] Of TLocalVar;
    LocalSize   : Integer;     { taille totale du cadre local (octets)}
    BodyStart   : Integer;     { index debut du corps dans TokenPool  }
    BodyEnd     : Integer;     { index fin du corps dans TokenPool    }
    IsForward   : Boolean;     { declaration FORWARD ?                }
    IsExternal  : Boolean;     { declaration EXTERNAL ?               }
    SymIdx      : Integer;     { index dans SymTab                    }
    VarMask     : LongInt;     { bitmask des parametres VAR           }
    RetOffset   : Integer;     { offset de la valeur de retour [EBP] }
  End;

Var
  { Table des procedures/fonctions }
  ProcTab   : Array[0..MAX_PROC - 1] Of TProcInfo;
  ProcCount : Integer;

  { Variables de contexte pour la compilation }
  CurFrameOffset : Integer;   { offset courant dans le cadre local    }
  CurFuncName    : TString;   { nom de la fonction en cours           }
  CurFuncRetOfs  : Integer;   { offset valeur de retour [EBP-N]      }
  CurRetLabel    : TString;   { label de retour de la fonction        }
  CurProcIdx     : Integer;   { index de la proc courante dans ProcTab}

{ ------------------------------------------------------------ }
{ EBPOfs : generer une reference [EBP+N] ou [EBP-N]           }
{ ------------------------------------------------------------ }

Function EBPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    EBPOfs := '[EBP+' + IntToStr_(Ofs) + ']'
  Else
    EBPOfs := '[EBP' + IntToStr_(Ofs) + ']';
End;

{ ------------------------------------------------------------ }
{ FindLocal : trouver une variable locale dans la proc courante }
{ Retourne l index dans ProcTab[PI].Locals ou -1               }
{ ------------------------------------------------------------ }

Function FindLocal(PI : Integer; Const Name : TString) : Integer;
Var
  J   : Integer;
  Up  : TString;
Begin
  FindLocal := -1;
  If PI < 0 Then Exit;
  Up := StrUpperCase(Name);
  For J := 0 To ProcTab[PI].LocalCount - 1 Do
    If ProcTab[PI].Locals[J].Name = Up Then
    Begin
      FindLocal := J;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ FindParam : trouver un parametre dans la proc courante       }
{ Retourne l index dans ProcTab[PI].Params ou -1               }
{ ------------------------------------------------------------ }

Function FindParam(PI : Integer; Const Name : TString) : Integer;
Var
  J   : Integer;
  Up  : TString;
Begin
  FindParam := -1;
  If PI < 0 Then Exit;
  Up := StrUpperCase(Name);
  For J := 0 To ProcTab[PI].ParamCount - 1 Do
    If ProcTab[PI].Params[J].Name = Up Then
    Begin
      FindParam := J;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ GenVarRef : generer l operande MASM pour acceder a une       }
{ variable (locale, parametre, globale)                         }
{ Retourne 'DWORD PTR [EBP-N]' ou 'DWORD PTR [_TPV_X]' etc   }
{ ------------------------------------------------------------ }

Function GenVarRef(PI : Integer; Const Name : TString) : TString;
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Sz           : Integer;
  Pfx          : TString;
Begin
  Up := StrUpperCase(Name);
  GenVarRef := 'DWORD PTR [' + TP_VAR_PFX + Up + ']'; { defaut : globale }

  { Chercher dans les locales }
  LI := FindLocal(PI, Up);
  If LI >= 0 Then
  Begin
    Sz := ProcTab[PI].Locals[LI].Size;
    If Sz = 1 Then
      Pfx := 'BYTE PTR '
    Else
      Pfx := 'DWORD PTR ';
    GenVarRef := Pfx + EBPOfs(ProcTab[PI].Locals[LI].Offset);
    Exit;
  End;

  { Chercher dans les parametres }
  ParI := FindParam(PI, Up);
  If ParI >= 0 Then
  Begin
    GenVarRef := 'DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset);
    Exit;
  End;

  { Chercher dans les symboles globaux }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      Sz := TypeSizeofIdx(SymTab[SI].TypeIdx);
      If Sz = 1 Then
        Pfx := 'BYTE PTR '
      Else
        Pfx := 'DWORD PTR ';
      GenVarRef := Pfx + '[' + SymTab[SI].MangledName + ']';
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenVarAddr : generer l operande MASM pour l adresse d une    }
{ variable (LEA-friendly)                                       }
{ ------------------------------------------------------------ }

Function GenVarAddr(PI : Integer; Const Name : TString) : TString;
Var
  LI, ParI, SI : Integer;
  Up           : TString;
Begin
  Up := StrUpperCase(Name);
  GenVarAddr := TP_VAR_PFX + Up; { defaut : globale }

  LI := FindLocal(PI, Up);
  If LI >= 0 Then
  Begin
    GenVarAddr := EBPOfs(ProcTab[PI].Locals[LI].Offset);
    Exit;
  End;

  ParI := FindParam(PI, Up);
  If ParI >= 0 Then
  Begin
    GenVarAddr := EBPOfs(ProcTab[PI].Params[ParI].Offset);
    Exit;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
      GenVarAddr := SymTab[SI].MangledName;
  End;
End;

{ ------------------------------------------------------------ }
{ SkipToMatchingEnd : avancer l index I dans TokenPool          }
{ jusqu au END correspondant au BEGIN courant                   }
{ ------------------------------------------------------------ }

Procedure SkipToMatchingEnd(Var I : Integer);
Var
  Depth : Integer;
  Up    : TString;
Begin
  Depth := 1;
  While (I < TokenCount) And (Depth > 0) Do
  Begin
    If TokenPool[I].Kind = TK_KEYWORD Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);
      If (Up = 'BEGIN') Or (Up = 'CASE') Or (Up = 'RECORD') Or
         (Up = 'REPEAT') Or (Up = 'ASM') Then
        Inc(Depth)
      Else If Up = 'END' Then
        Dec(Depth);
    End;
    Inc(I);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseProcDecls : scanner le TokenPool pour trouver les       }
{ declarations de PROCEDURE et FUNCTION au niveau global.       }
{ Remplit ProcTab avec les signatures et localise les corps.    }
{ ------------------------------------------------------------ }

Procedure ParseProcDecls;
Var
  I         : Integer;
  Depth     : Integer;
  Up        : TString;
  PI        : Integer;
  PName     : TString;
  IsFunc    : Boolean;
  IsVarP    : Boolean;
  IsConstP  : Boolean;
  GrpStart  : Integer;
  TName     : TString;
  TIdx      : Integer;
  PC        : Integer;  { param count local }
  J         : Integer;
  LocalOfs  : Integer;
  VM        : LongInt;
  SIdx      : Integer;
  RetTIdx   : Integer;
  LTName    : TString;
  LTIdx     : Integer;
  LSz       : Integer;
  LC        : Integer;
  { Variables pour procedures imbriquees (TODO 14) }
  NI        : Integer;
  NIsFunc   : Boolean;
  NName     : TString;
  NPC       : Integer;
  NVM       : LongInt;
  NIsVarP   : Boolean;
  NIsConstP : Boolean;
  NGrpSt    : Integer;
  NTName    : TString;
  NTIdx     : Integer;
  NRetTIdx  : Integer;
  NSIdx     : Integer;
  NLC       : Integer;
  NLocalOfs : Integer;
  NLTName   : TString;
  NLTIdx    : Integer;
  NLSz      : Integer;
  NK        : Integer;
  { Variables pour ARRAY inline dans var locales }
  ArrLo     : LongInt;
  ArrHi     : LongInt;
  ArrElem   : LongInt;
  ElemType  : TString;
  ElemSz    : Integer;
  BTIdx     : Integer;
Begin
  ProcCount := 0;
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    { Suivre la profondeur BEGIN/END pour rester au niveau global }
    If TokenPool[I].Kind = TK_KEYWORD Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'REPEAT') Or
         (Up = 'CASE') Or (Up = 'ASM') Then
        Inc(Depth)
      Else If Up = 'END' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
      End;

      { On ne traite que le niveau global (Depth = 0) }
      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { === Detecter SEGMENT PROCEDURE ou SEGMENT FUNCTION (Apple Pascal) === }
      If (Up = 'SEGMENT') And Opts.ApplePascal Then
      Begin
        { Sauter SEGMENT et continuer pour traiter PROCEDURE/FUNCTION }
        Inc(I);
        If I < TokenCount Then
          Continue;
      End;

      { === Detecter PROCEDURE ou FUNCTION === }
      If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
      Begin
        If ProcCount >= MAX_PROC Then
        Begin
          Inc(I);
          Continue;
        End;

        IsFunc := (Up = 'FUNCTION');
        Inc(I); { sauter PROCEDURE/FUNCTION }

        { Lire le nom }
        If (I >= TokenCount) Or
           ((TokenPool[I].Kind <> TK_IDENT) And
            (TokenPool[I].Kind <> TK_KEYWORD)) Then
        Begin
          Continue;
        End;
        PName := StrUpperCase(TokenPool[I].Val);
        Inc(I);

        { Verifier si une declaration FORWARD existe deja }
        PI := -1;
        For J := 0 To ProcCount - 1 Do
          If (ProcTab[J].Name = PName) And ProcTab[J].IsForward Then
          Begin
            PI := J;
            Break;
          End;

        If PI < 0 Then
        Begin
          PI := ProcCount;
          ProcTab[PI].Name        := PName;
          ProcTab[PI].MangledName := TP_FUNC_PFX + PName;
          ProcTab[PI].IsFunction  := IsFunc;
          ProcTab[PI].RetTypeIdx  := -1;
          ProcTab[PI].ParamCount  := 0;
          ProcTab[PI].LocalCount  := 0;
          ProcTab[PI].LocalSize   := 0;
          ProcTab[PI].BodyStart   := -1;
          ProcTab[PI].BodyEnd     := -1;
          ProcTab[PI].IsForward   := False;
          ProcTab[PI].IsExternal  := False;
          ProcTab[PI].SymIdx      := -1;
          ProcTab[PI].VarMask     := 0;
          ProcTab[PI].RetOffset   := 0;
        End;

        { Analyser la liste des parametres }
        PC := 0;
        VM := 0;
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = '(') Then
        Begin
          Inc(I); { sauter '(' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ')')) Do
          Begin
            { Detecter VAR ou CONST }
            IsVarP := False;
            IsConstP := False;
            If (TokenPool[I].Kind = TK_KEYWORD) Then
            Begin
              Up := StrUpperCase(TokenPool[I].Val);
              If Up = 'VAR' Then
              Begin
                IsVarP := True;
                Inc(I);
              End
              Else If Up = 'CONST' Then
              Begin
                IsConstP := True;
                Inc(I);
              End;
            End;

            { Collecter les noms du groupe }
            GrpStart := PC;
            While (I < TokenCount) And
                  ((TokenPool[I].Kind = TK_IDENT) Or
                   (TokenPool[I].Kind = TK_KEYWORD)) Do
            Begin
              If PC < MAX_PARAM Then
              Begin
                ProcTab[PI].Params[PC].Name    := StrUpperCase(TokenPool[I].Val);
                ProcTab[PI].Params[PC].IsVar   := IsVarP;
                ProcTab[PI].Params[PC].IsConst := IsConstP;
                ProcTab[PI].Params[PC].TypeIdx := TY_IDX_INTEGER;
                ProcTab[PI].Params[PC].Offset  := 0;
                If IsVarP Then
                  VM := VM Or (LongInt(1) Shl PC);
                Inc(PC);
              End;
              Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ',') Then
                Inc(I)
              Else
                Break;
            End;

            { Lire le type ':' TypeName }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ':') Then
            Begin
              Inc(I);
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                TName := StrUpperCase(TokenPool[I].Val);
                TIdx := TypeFindByName(TName);
                If TIdx < 0 Then TIdx := TY_IDX_INTEGER;
                For J := GrpStart To PC - 1 Do
                  ProcTab[PI].Params[J].TypeIdx := TIdx;
                Inc(I);
              End;
            End;

            { Sauter ';' entre groupes }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
          End;
          { Sauter ')' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ')') Then
            Inc(I);
        End;

        ProcTab[PI].ParamCount := PC;
        ProcTab[PI].VarMask    := VM;

        { Calculer les offsets des parametres }
        { Pascal calling convention : params pousses gauche-a-droite }
        { param[0] = [EBP + 8 + (N-1)*4], param[N-1] = [EBP + 8] }
        For J := 0 To PC - 1 Do
          ProcTab[PI].Params[J].Offset := 8 + (PC - 1 - J) * 4;

        { Type de retour pour les fonctions }
        RetTIdx := TY_IDX_INTEGER;
        If IsFunc Then
        Begin
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
          Begin
            Inc(I);
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := StrUpperCase(TokenPool[I].Val);
              TIdx := TypeFindByName(TName);
              If TIdx >= 0 Then
                RetTIdx := TIdx;
              Inc(I);
            End;
          End;
        End;
        ProcTab[PI].RetTypeIdx := RetTIdx;

        { Attendre ';' apres la signature }
        While (I < TokenCount) And
              Not ((TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';')) Do
          Inc(I);
        If I < TokenCount Then Inc(I);

        { Verifier FORWARD }
        If (I < TokenCount) And
           ((TokenPool[I].Kind = TK_KEYWORD) Or
            (TokenPool[I].Kind = TK_IDENT)) And
           (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
        Begin
          ProcTab[PI].IsForward := True;
          Inc(I);
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
          { Enregistrer le symbole dans SymTab }
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount := PC;
            SymTab[SIdx].IsGlobal   := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
          If PI = ProcCount Then
            Inc(ProcCount);
          Continue;
        End;

        { Verifier EXTERNAL }
        If (I < TokenCount) And
           ((TokenPool[I].Kind = TK_KEYWORD) Or
            (TokenPool[I].Kind = TK_IDENT)) And
           (StrUpperCase(TokenPool[I].Val) = 'EXTERNAL') Then
        Begin
          ProcTab[PI].IsExternal := True;
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount  := PC;
            SymTab[SIdx].IsGlobal    := True;
            SymTab[SIdx].IsExternal  := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
          If PI = ProcCount Then
            Inc(ProcCount);
          Continue;
        End;

        { Verifier si un corps suit (VAR/CONST/TYPE/LABEL/BEGIN) }
        { Si le prochain token est un mot-cle non lie au corps, ou si }
        { c est PROCEDURE/FUNCTION sans BEGIN avant IMPLEMENTATION,   }
        { traiter comme declaration anticipee (interface de unit)     }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) Then
        Begin
          Up := StrUpperCase(TokenPool[I].Val);
          If (Up <> 'VAR') And (Up <> 'CONST') And (Up <> 'TYPE') And
             (Up <> 'LABEL') And (Up <> 'BEGIN') And
             (Up <> 'PROCEDURE') And (Up <> 'FUNCTION') And
             (Up <> 'SEGMENT') Then
          Begin
            { Pas de corps : declaration de type interface/forward implicite }
            ProcTab[PI].IsForward := True;
            If IsFunc Then
              SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
            Else
              SIdx := SymAdd(PName, SK_PROC, -1);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].ParamCount  := PC;
              SymTab[SIdx].IsGlobal    := True;
              SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
            End;
            ProcTab[PI].SymIdx := SIdx;
            If PI = ProcCount Then
              Inc(ProcCount);
            Continue;
          End;
          { Si PROCEDURE/FUNCTION/SEGMENT suit immediatement, scanner en avant }
          { pour detecter si un BEGIN existe avant IMPLEMENTATION/END  }
          If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
             (Up = 'SEGMENT') Then
          Begin
            J := I;
            SIdx := -1;  { reutiliser SIdx comme flag HasBody }
            While (J < TokenCount) Do
            Begin
              If TokenPool[J].Kind = TK_KEYWORD Then
              Begin
                Up := StrUpperCase(TokenPool[J].Val);
                If Up = 'BEGIN' Then
                Begin SIdx := 1; Break; End;
                If (Up = 'IMPLEMENTATION') Or (Up = 'INTERFACE') Then
                  Break;
              End;
              Inc(J);
            End;
            If SIdx < 0 Then
            Begin
              { Pas de BEGIN trouve : section interface, forward implicite }
              ProcTab[PI].IsForward := True;
              If IsFunc Then
                SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
              Else
                SIdx := SymAdd(PName, SK_PROC, -1);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].ParamCount  := PC;
                SymTab[SIdx].IsGlobal    := True;
                SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
              End;
              ProcTab[PI].SymIdx := SIdx;
              If PI = ProcCount Then
                Inc(ProcCount);
              Continue;
            End;
          End;
        End;

        { Reserver le slot dans ProcTab pour la proc courante }
        { AVANT de scanner les sections locales qui peuvent creer }
        { des procs imbriquees (TODO 14)                          }
        If PI = ProcCount Then
          Inc(ProcCount);

        LocalOfs := 0;
        LC := 0;

        { Reserver l emplacement de la valeur de retour pour les fonctions }
        If IsFunc Then
        Begin
          LocalOfs := LocalOfs + 4;
          ProcTab[PI].RetOffset := -LocalOfs;
        End;

        { Scanner les sections locales VAR/CONST/TYPE avant BEGIN }
        While (I < TokenCount) Do
        Begin
          If TokenPool[I].Kind <> TK_KEYWORD Then Break;
          Up := StrUpperCase(TokenPool[I].Val);

          If Up = 'VAR' Then
          Begin
            Inc(I); { sauter VAR }
            { Parser les declarations de variables locales }
            While (I < TokenCount) Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                   (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                   (Up = 'FUNCTION') Or (Up = 'LABEL') Or
                   (Up = 'SEGMENT') Then
                  Break;
              End;

              If (TokenPool[I].Kind <> TK_IDENT) And
                 (TokenPool[I].Kind <> TK_KEYWORD) Then
              Begin
                Inc(I);
                Continue;
              End;

              { Collecter les noms }
              GrpStart := LC;
              While (I < TokenCount) And
                    ((TokenPool[I].Kind = TK_IDENT) Or
                     (TokenPool[I].Kind = TK_KEYWORD)) Do
              Begin
                If LC < MAX_LOCAL Then
                Begin
                  ProcTab[PI].Locals[LC].Name    := StrUpperCase(TokenPool[I].Val);
                  ProcTab[PI].Locals[LC].TypeIdx  := TY_IDX_INTEGER;
                  ProcTab[PI].Locals[LC].Size     := 4;
                  ProcTab[PI].Locals[LC].IsStatic := False;
                  ProcTab[PI].Locals[LC].StaticLbl:= '';
                  ProcTab[PI].Locals[LC].InitVal  := 0;
                  ProcTab[PI].Locals[LC].HasInit  := False;
                  Inc(LC);
                End;
                Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                   And (TokenPool[I].Val = ',') Then
                  Inc(I)
                Else
                  Break;
              End;

              { Lire ':' TypeName }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
              Begin
                Inc(I);
                LTName := '';

                { Verifier si c'est ARRAY [lo..hi] OF TypeElem (inline) }
                If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
                   (StrUpperCase(TokenPool[I].Val) = 'ARRAY') Then
                Begin
                  Inc(I); { sauter 'ARRAY' }
                  ArrLo := 0;
                  ArrHi := 0;
                  ElemType := 'INTEGER';
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = '[') Then
                  Begin
                    Inc(I);
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
                    Begin ArrLo := TokenPool[I].IntVal; Inc(I); End;
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = '..') Then Inc(I);
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
                    Begin ArrHi := TokenPool[I].IntVal; Inc(I); End;
                    { Gerer multi-dim : virgule dans [] }
                    { TODO : support array[1..3,1..5] inline locals }
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ']') Then Inc(I);
                  End;
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
                     (StrUpperCase(TokenPool[I].Val) = 'OF') Then Inc(I);
                  If (I < TokenCount) And
                     ((TokenPool[I].Kind = TK_IDENT) Or
                      (TokenPool[I].Kind = TK_KEYWORD)) Then
                  Begin ElemType := StrUpperCase(TokenPool[I].Val); Inc(I); End;

                  ArrElem := ArrHi - ArrLo + 1;
                  If ArrElem < 1 Then ArrElem := 1;
                  ElemSz := TPTypeSizeof(ElemType);
                  If ElemSz < 0 Then
                  Begin
                    BTIdx := TypeFindByName(ElemType);
                    If BTIdx >= 0 Then ElemSz := TypeTab[BTIdx].Size
                    Else ElemSz := 4;
                  End;

                  LTIdx := TypeAdd(TYK_ARRAY, '', ArrElem * ElemSz, 4, False, -1);
                  If LTIdx >= 0 Then
                  Begin
                    TypeTab[LTIdx].Lo := ArrLo;
                    TypeTab[LTIdx].Hi := ArrHi;
                    BTIdx := TypeFindByName(ElemType);
                    If BTIdx < 0 Then BTIdx := TY_IDX_INTEGER;
                    TypeTab[LTIdx].BaseTypeIdx := BTIdx;
                  End;
                  LSz := ArrElem * ElemSz;
                  If LSz < 4 Then LSz := 4;
                  { Aligner sur 4 }
                  If (LSz And 3) <> 0 Then
                    LSz := (LSz + 3) And (Not 3);

                  For J := GrpStart To LC - 1 Do
                  Begin
                    ProcTab[PI].Locals[J].TypeIdx := LTIdx;
                    ProcTab[PI].Locals[J].Size    := LSz;
                    LocalOfs := LocalOfs + LSz;
                    If (LocalOfs And 3) <> 0 Then
                      LocalOfs := (LocalOfs + 3) And (Not 3);
                    ProcTab[PI].Locals[J].Offset := -LocalOfs;
                  End;
                End
                Else
                Begin
                  { Type simple (identifiant) }
                  If (I < TokenCount) And
                     ((TokenPool[I].Kind = TK_IDENT) Or
                      (TokenPool[I].Kind = TK_KEYWORD)) Then
                  Begin
                    LTName := StrUpperCase(TokenPool[I].Val);
                    Inc(I);
                  End;

                  LTIdx := TypeFindByName(LTName);
                  If LTIdx < 0 Then LTIdx := TY_IDX_INTEGER;
                  LSz := TypeSizeofIdx(LTIdx);
                  If LSz < 4 Then LSz := 4;  { min 4 bytes alignment }

                  For J := GrpStart To LC - 1 Do
                  Begin
                    ProcTab[PI].Locals[J].TypeIdx := LTIdx;
                    ProcTab[PI].Locals[J].Size    := LSz;
                    LocalOfs := LocalOfs + LSz;
                    { Aligner sur 4 octets }
                    If (LocalOfs And 3) <> 0 Then
                      LocalOfs := (LocalOfs + 3) And (Not 3);
                    ProcTab[PI].Locals[J].Offset := -LocalOfs;
                  End;
                End;
              End;

              { Avancer au ';' }
              While (I < TokenCount) And
                    Not ((TokenPool[I].Kind = TK_PUNCT) And
                         (TokenPool[I].Val = ';')) Do
                Inc(I);
              If I < TokenCount Then Inc(I);
            End;
          End
          Else If (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'LABEL') Then
          Begin
            { Sauter les sections CONST/TYPE/LABEL locales }
            Inc(I);
            While (I < TokenCount) Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                   (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                   (Up = 'FUNCTION') Or (Up = 'LABEL') Or
                   (Up = 'SEGMENT') Then
                  Break;
              End;
              Inc(I);
            End;
          End
          Else If (Up = 'SEGMENT') And Opts.ApplePascal Then
          Begin
            { Sauter SEGMENT, la boucle traitera PROCEDURE/FUNCTION }
            Inc(I);
          End
          Else If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
          Begin
            { Parser les procedures/fonctions imbriquees (TODO 14) }
            { Elles deviennent des entrees separees dans ProcTab }
            If ProcCount < MAX_PROC Then
            Begin
              NIsFunc := (Up = 'FUNCTION');
                Inc(I); { sauter PROCEDURE/FUNCTION }

                { Lire le nom }
                If (I < TokenCount) And
                   ((TokenPool[I].Kind = TK_IDENT) Or
                    (TokenPool[I].Kind = TK_KEYWORD)) Then
                Begin
                  NName := StrUpperCase(TokenPool[I].Val);
                  Inc(I);
                End
                Else
                  NName := '';

                NI := ProcCount;
                ProcTab[NI].Name        := NName;
                ProcTab[NI].MangledName := TP_FUNC_PFX + NName;
                ProcTab[NI].IsFunction  := NIsFunc;
                ProcTab[NI].RetTypeIdx  := -1;
                ProcTab[NI].ParamCount  := 0;
                ProcTab[NI].LocalCount  := 0;
                ProcTab[NI].LocalSize   := 0;
                ProcTab[NI].BodyStart   := -1;
                ProcTab[NI].BodyEnd     := -1;
                ProcTab[NI].IsForward   := False;
                ProcTab[NI].IsExternal  := False;
                ProcTab[NI].SymIdx      := -1;
                ProcTab[NI].VarMask     := 0;
                ProcTab[NI].RetOffset   := 0;

                { Parser les parametres }
                NPC := 0;
                NVM := 0;
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = '(') Then
                Begin
                  Inc(I);
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = ')')) Do
                  Begin
                    NIsVarP := False;
                    NIsConstP := False;
                    If (TokenPool[I].Kind = TK_KEYWORD) Then
                    Begin
                      If StrUpperCase(TokenPool[I].Val) = 'VAR' Then
                      Begin NIsVarP := True; Inc(I); End
                      Else If StrUpperCase(TokenPool[I].Val) = 'CONST' Then
                      Begin NIsConstP := True; Inc(I); End;
                    End;
                    NGrpSt := NPC;
                    While (I < TokenCount) And
                          ((TokenPool[I].Kind = TK_IDENT) Or
                           (TokenPool[I].Kind = TK_KEYWORD)) Do
                    Begin
                      If NPC < MAX_PARAM Then
                      Begin
                        ProcTab[NI].Params[NPC].Name    := StrUpperCase(TokenPool[I].Val);
                        ProcTab[NI].Params[NPC].IsVar   := NIsVarP;
                        ProcTab[NI].Params[NPC].IsConst := NIsConstP;
                        ProcTab[NI].Params[NPC].TypeIdx := TY_IDX_INTEGER;
                        ProcTab[NI].Params[NPC].Offset  := 0;
                        If NIsVarP Then
                          NVM := NVM Or (LongInt(1) Shl NPC);
                        Inc(NPC);
                      End;
                      Inc(I);
                      If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                         (TokenPool[I].Val = ',') Then Inc(I) Else Break;
                    End;
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ':') Then
                    Begin
                      Inc(I);
                      If (I < TokenCount) And
                         ((TokenPool[I].Kind = TK_IDENT) Or
                          (TokenPool[I].Kind = TK_KEYWORD)) Then
                      Begin
                        NTName := StrUpperCase(TokenPool[I].Val);
                        NTIdx := TypeFindByName(NTName);
                        If NTIdx < 0 Then NTIdx := TY_IDX_INTEGER;
                        For NK := NGrpSt To NPC - 1 Do
                          ProcTab[NI].Params[NK].TypeIdx := NTIdx;
                        Inc(I);
                      End;
                    End;
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';') Then Inc(I);
                  End;
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ')') Then Inc(I);
                End;
                ProcTab[NI].ParamCount := NPC;
                ProcTab[NI].VarMask    := NVM;
                For NK := 0 To NPC - 1 Do
                  ProcTab[NI].Params[NK].Offset := 8 + (NPC - 1 - NK) * 4;

                { Type de retour }
                NRetTIdx := TY_IDX_INTEGER;
                If NIsFunc Then
                Begin
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ':') Then
                  Begin
                    Inc(I);
                    If (I < TokenCount) And
                       ((TokenPool[I].Kind = TK_IDENT) Or
                        (TokenPool[I].Kind = TK_KEYWORD)) Then
                    Begin
                      NTName := StrUpperCase(TokenPool[I].Val);
                      NTIdx := TypeFindByName(NTName);
                      If NTIdx >= 0 Then NRetTIdx := NTIdx;
                      Inc(I);
                    End;
                  End;
                End;
                ProcTab[NI].RetTypeIdx := NRetTIdx;

                { Attendre ';' apres la signature }
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) Do
                  Inc(I);
                If I < TokenCount Then Inc(I);

                { Verifier FORWARD }
                If (I < TokenCount) And
                   ((TokenPool[I].Kind = TK_KEYWORD) Or
                    (TokenPool[I].Kind = TK_IDENT)) And
                   (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
                Begin
                  ProcTab[NI].IsForward := True;
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = ';')) Do
                    Inc(I);
                  If I < TokenCount Then Inc(I);
                End
                Else If (I < TokenCount) And
                        (TokenPool[I].Kind = TK_KEYWORD) And
                        (StrUpperCase(TokenPool[I].Val) <> 'VAR') And
                        (StrUpperCase(TokenPool[I].Val) <> 'CONST') And
                        (StrUpperCase(TokenPool[I].Val) <> 'TYPE') And
                        (StrUpperCase(TokenPool[I].Val) <> 'LABEL') And
                        (StrUpperCase(TokenPool[I].Val) <> 'BEGIN') And
                        (StrUpperCase(TokenPool[I].Val) <> 'PROCEDURE') And
                        (StrUpperCase(TokenPool[I].Val) <> 'FUNCTION') Then
                Begin
                  { Pas de corps : declaration de type interface/forward implicite }
                  ProcTab[NI].IsForward := True;
                End
                Else
                Begin
                  { Scanner les variables locales de la proc imbriquee }
                  NLocalOfs := 0;
                  NLC := 0;
                  If NIsFunc Then
                  Begin
                    NLocalOfs := NLocalOfs + 4;
                    ProcTab[NI].RetOffset := -NLocalOfs;
                  End;
                  While (I < TokenCount) Do
                  Begin
                    If TokenPool[I].Kind <> TK_KEYWORD Then Break;
                    Up := StrUpperCase(TokenPool[I].Val);
                    If Up = 'VAR' Then
                    Begin
                      Inc(I);
                      While (I < TokenCount) Do
                      Begin
                        If (TokenPool[I].Kind = TK_KEYWORD) Then
                        Begin
                          Up := StrUpperCase(TokenPool[I].Val);
                          If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                             (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                             (Up = 'FUNCTION') Or (Up = 'LABEL') Or
                             (Up = 'SEGMENT') Then
                            Break;
                        End;
                        If (TokenPool[I].Kind <> TK_IDENT) And
                           (TokenPool[I].Kind <> TK_KEYWORD) Then
                        Begin Inc(I); Continue; End;
                        NGrpSt := NLC;
                        While (I < TokenCount) And
                              ((TokenPool[I].Kind = TK_IDENT) Or
                               (TokenPool[I].Kind = TK_KEYWORD)) Do
                        Begin
                          If NLC < MAX_LOCAL Then
                          Begin
                            ProcTab[NI].Locals[NLC].Name    := StrUpperCase(TokenPool[I].Val);
                            ProcTab[NI].Locals[NLC].TypeIdx  := TY_IDX_INTEGER;
                            ProcTab[NI].Locals[NLC].Size     := 4;
                            ProcTab[NI].Locals[NLC].IsStatic := False;
                            ProcTab[NI].Locals[NLC].StaticLbl:= '';
                            ProcTab[NI].Locals[NLC].InitVal  := 0;
                            ProcTab[NI].Locals[NLC].HasInit  := False;
                            Inc(NLC);
                          End;
                          Inc(I);
                          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                             And (TokenPool[I].Val = ',') Then Inc(I) Else Break;
                        End;
                        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ':') Then
                        Begin
                          Inc(I);
                          NLTName := '';
                          If (I < TokenCount) And
                             ((TokenPool[I].Kind = TK_IDENT) Or
                              (TokenPool[I].Kind = TK_KEYWORD)) Then
                          Begin
                            NLTName := StrUpperCase(TokenPool[I].Val);
                            Inc(I);
                          End;
                          NLTIdx := TypeFindByName(NLTName);
                          If NLTIdx < 0 Then NLTIdx := TY_IDX_INTEGER;
                          NLSz := TypeSizeofIdx(NLTIdx);
                          If NLSz < 4 Then NLSz := 4;
                          For NK := NGrpSt To NLC - 1 Do
                          Begin
                            ProcTab[NI].Locals[NK].TypeIdx := NLTIdx;
                            ProcTab[NI].Locals[NK].Size    := NLSz;
                            NLocalOfs := NLocalOfs + NLSz;
                            If (NLocalOfs And 3) <> 0 Then
                              NLocalOfs := (NLocalOfs + 3) And (Not 3);
                            ProcTab[NI].Locals[NK].Offset := -NLocalOfs;
                          End;
                        End;
                        While (I < TokenCount) And
                              Not ((TokenPool[I].Kind = TK_PUNCT) And
                                   (TokenPool[I].Val = ';')) Do
                          Inc(I);
                        If I < TokenCount Then Inc(I);
                      End;
                    End
                    Else If (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'LABEL') Then
                    Begin
                      Inc(I);
                      While (I < TokenCount) Do
                      Begin
                        If (TokenPool[I].Kind = TK_KEYWORD) Then
                        Begin
                          Up := StrUpperCase(TokenPool[I].Val);
                          If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                             (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                             (Up = 'FUNCTION') Or (Up = 'LABEL') Or
                             (Up = 'SEGMENT') Then
                            Break;
                        End;
                        Inc(I);
                      End;
                    End
                    Else
                      Break;
                  End;
                  ProcTab[NI].LocalCount := NLC;
                  ProcTab[NI].LocalSize  := NLocalOfs;

                  { Localiser le corps (BEGIN ... END) }
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
                     (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
                  Begin
                    ProcTab[NI].BodyStart := I;
                    Inc(I);
                    SkipToMatchingEnd(I);
                    ProcTab[NI].BodyEnd := I - 1;
                  End;
                  { Sauter le ';' apres END }
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';') Then
                    Inc(I);
                End;

                { Enregistrer le symbole dans SymTab }
                If NIsFunc Then
                  NSIdx := SymAdd(NName, SK_FUNC, NRetTIdx)
                Else
                  NSIdx := SymAdd(NName, SK_PROC, -1);
                If NSIdx >= 0 Then
                Begin
                  SymTab[NSIdx].ParamCount  := NPC;
                  SymTab[NSIdx].IsGlobal    := True;
                  SymTab[NSIdx].MangledName := TP_FUNC_PFX + NName;
                End;
                ProcTab[NI].SymIdx := NSIdx;
                Inc(ProcCount);
            End
            Else
            Begin
              { Pas de place dans ProcTab : sauter }
              Inc(I);
              While (I < TokenCount) Do
              Begin
                If (TokenPool[I].Kind = TK_KEYWORD) And
                   (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
                Begin
                  Inc(I);
                  SkipToMatchingEnd(I);
                  Break;
                End;
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;
          End
          Else
            Break;
        End;

        ProcTab[PI].LocalCount := LC;
        ProcTab[PI].LocalSize  := LocalOfs;

        { Localiser le corps (BEGIN ... END) }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
        Begin
          ProcTab[PI].BodyStart := I;
          Inc(I); { sauter BEGIN }
          SkipToMatchingEnd(I);
          ProcTab[PI].BodyEnd := I - 1;
        End;

        { Sauter le ';' apres END }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = ';') Then
          Inc(I);

        { Enregistrer le symbole dans SymTab (si pas deja fait via FORWARD) }
        If ProcTab[PI].IsForward Then
        Begin
          { Resoudre la declaration FORWARD }
          ProcTab[PI].IsForward := False;
        End
        Else
        Begin
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount  := PC;
            SymTab[SIdx].IsGlobal    := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
        End;
        If PI = ProcCount Then
          Inc(ProcCount);
        Continue;
      End;

    End; { if keyword }

    Inc(I);
  End; { while }
End;


{ ============================================================ }
{ TODO 15 - TABLEAUX, RECORDS, ENSEMBLES ET OBJETS [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseTypeDecls : scanner le TokenPool pour traiter les        }
{ sections TYPE au niveau global.                               }
{ Gere ARRAY, RECORD, SET, OBJECT, enums, alias, subrange.     }
{ ------------------------------------------------------------ }

Procedure ParseTypeDecls;
Var
  I       : Integer;
  Depth   : Integer;
  Up      : TString;
  TName   : TString;
  TIdx    : Integer;
  SIdx    : Integer;
  FName   : TString;
  FTName  : TString;
  FTIdx   : Integer;
  FOfs    : Integer;
  FSz     : Integer;
  FC      : Integer;
  FNames  : Array[0..15] Of TString;  { noms de champs multi (X, Y: Integer) }
  FNC     : Integer;                   { nombre de noms collectes             }
  FNI     : Integer;                   { index de boucle noms                 }
  VarOfs  : Integer;                   { offset debut partie variante         }
  MaxVarSz: Integer;                   { taille max parmi les variantes       }
  CurVarSz: Integer;                   { taille variante courante             }
  ArrLo   : LongInt;
  ArrHi   : LongInt;
  ArrElem : LongInt;
  ElemType: TString;
  ElemSz  : Integer;
  BaseTN  : TString;
  BTIdx   : Integer;
  ObjPar  : TString;
  { Multi-dim arrays }
  DimLo   : Array[0..7] Of LongInt;
  DimHi   : Array[0..7] Of LongInt;
  DimCount: Integer;
  DimK    : Integer;
Begin
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    If (TokenPool[I].Kind = TK_KEYWORD) Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'OBJECT') Or
         (Up = 'REPEAT') Or (Up = 'ASM') Then
      Begin
        Inc(Depth);
        Inc(I);
        Continue;
      End;

      If Up = 'END' Then
      Begin
        If Depth > 0 Then Dec(Depth);
        Inc(I);
        Continue;
      End;

      If Up = 'UNTIL' Then
      Begin
        If Depth > 0 Then Dec(Depth);
        Inc(I);
        Continue;
      End;

      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { --- Section TYPE --- }
      If Up = 'TYPE' Then
      Begin
        Inc(I);

        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Or
               (Up = 'SEGMENT') Then
              Break;
          End;

          { Lire le nom du type }
          If (TokenPool[I].Kind <> TK_IDENT) Then
          Begin
            Inc(I);
            Continue;
          End;
          TName := StrUpperCase(TokenPool[I].Val);
          Inc(I);

          { Attendre '=' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
             (TokenPool[I].Val = '=') Then
            Inc(I)
          Else
          Begin
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- PACKED prefix --- }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'PACKED') Then
            Inc(I);

          If I >= TokenCount Then Break;
          Up := StrUpperCase(TokenPool[I].Val);

          { --- ARRAY [lo..hi, lo2..hi2, ...] OF T --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'ARRAY') Then
          Begin
            Inc(I);
            ElemType := 'INTEGER';

            { Parser toutes les dimensions dans DimLo/DimHi }
            DimCount := 0;
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '[') Then
            Begin
              Inc(I);
              Repeat
                ArrLo := 0; ArrHi := 0;
                If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
                Begin ArrLo := TokenPool[I].IntVal; Inc(I); End;
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = '..') Then Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
                Begin ArrHi := TokenPool[I].IntVal; Inc(I); End;
                If DimCount < 8 Then
                Begin
                  DimLo[DimCount] := ArrLo;
                  DimHi[DimCount] := ArrHi;
                  Inc(DimCount);
                End;
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ',') Then
                  Inc(I)
                Else
                  Break;
              Until I >= TokenCount;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ']') Then
                Inc(I);
            End;

            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);

            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              ElemType := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            { Determiner le type de base de l element }
            ElemSz := TPTypeSizeof(ElemType);
            If ElemSz < 0 Then
            Begin
              BTIdx := TypeFindByName(ElemType);
              If BTIdx >= 0 Then ElemSz := TypeTab[BTIdx].Size
              Else ElemSz := 4;
            End;
            BTIdx := TypeFindByName(ElemType);
            If BTIdx < 0 Then BTIdx := TY_IDX_INTEGER;

            { Construire les types imbriques de l interieur vers l exterieur }
            { Pour array[1..3, 1..5] of Integer :                             }
            {   d'abord inner = array[1..5] of Integer (size=5*4=20)          }
            {   puis outer = array[1..3] of inner       (size=3*20=60)        }
            For DimK := DimCount - 1 DownTo 0 Do
            Begin
              ArrElem := DimHi[DimK] - DimLo[DimK] + 1;
              If ArrElem < 1 Then ArrElem := 1;
              If DimK = 0 Then
                TIdx := TypeAdd(TYK_ARRAY, TName, ArrElem * ElemSz, 4, False, -1)
              Else
                TIdx := TypeAdd(TYK_ARRAY, '', ArrElem * ElemSz, 4, False, -1);
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].Lo := DimLo[DimK];
                TypeTab[TIdx].Hi := DimHi[DimK];
                TypeTab[TIdx].BaseTypeIdx := BTIdx;
              End;
              { Le type courant devient le BaseTypeIdx de la dimension suivante }
              BTIdx := TIdx;
              ElemSz := ArrElem * ElemSz;
            End;
            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- RECORD ... END --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'RECORD') Then
          Begin
            Inc(I);
            FC := 0;
            FOfs := 0;

            TIdx := TypeAdd(TYK_RECORD, TName, 0, 4, False, -1);

            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'CASE') Then
              Begin
                { Variant record : CASE [tag :] Type OF val: (fields); ... }
                Inc(I); { passer CASE }
                { Lire le champ tag (optionnel) et le type discriminant }
                { Forme: CASE tag: Type OF  ou  CASE Type OF }
                If (I < TokenCount) And (TokenPool[I].Kind = TK_IDENT) Then
                Begin
                  FName := StrUpperCase(TokenPool[I].Val);
                  Inc(I);
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ':') Then
                  Begin
                    { Forme CASE tag: Type OF -> enregistrer le champ tag }
                    Inc(I); { passer ':' }
                    FTName := 'INTEGER';
                    If (I < TokenCount) And
                       ((TokenPool[I].Kind = TK_IDENT) Or
                        (TokenPool[I].Kind = TK_KEYWORD)) Then
                    Begin
                      FTName := StrUpperCase(TokenPool[I].Val);
                      Inc(I);
                    End;
                    FSz := TPTypeSizeof(FTName);
                    If FSz < 0 Then FSz := 4;
                    FTIdx := TypeFindByName(FTName);
                    If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;
                    If (TIdx >= 0) And (FC < MAX_FIELDS) Then
                    Begin
                      TypeTab[TIdx].Fields[FC].Name    := FName;
                      TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                      TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                      Inc(FC);
                      TypeTab[TIdx].FieldCount := FC;
                      FOfs := FOfs + FSz;
                      TypeTab[TIdx].Size := FOfs;
                    End;
                  End;
                  { Sinon c est CASE Type OF -> pas de champ tag }
                End;
                { Passer 'OF' }
                If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
                   (StrUpperCase(TokenPool[I].Val) = 'OF') Then
                  Inc(I);
                { Parser les variantes : val: (field: Type; ...); }
                { Tous les champs partagent le meme offset de depart }
                VarOfs := FOfs;
                MaxVarSz := 0;
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                Begin
                  { Sauter les labels de cas (nombres/idents) et ':' }
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = '(')) And
                        Not ((TokenPool[I].Kind = TK_KEYWORD) And
                             (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                    Inc(I);
                  If (I >= TokenCount) Or
                     ((TokenPool[I].Kind = TK_KEYWORD) And
                      (StrUpperCase(TokenPool[I].Val) = 'END')) Then
                    Break;
                  Inc(I); { passer '(' }
                  { Parser les champs de cette variante }
                  CurVarSz := 0;
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = ')')) And
                        Not ((TokenPool[I].Kind = TK_KEYWORD) And
                             (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Begin
                    If (TokenPool[I].Kind = TK_IDENT) Then
                    Begin
                      { Collecter noms de champs separes par virgules }
                      FNames[0] := StrUpperCase(TokenPool[I].Val);
                      FNC := 1;
                      Inc(I);
                      While (I < TokenCount) And
                            (TokenPool[I].Kind = TK_PUNCT) And
                            (TokenPool[I].Val = ',') Do
                      Begin
                        Inc(I);
                        If (I < TokenCount) And
                           (TokenPool[I].Kind = TK_IDENT) Then
                        Begin
                          If FNC < 16 Then
                          Begin
                            FNames[FNC] := StrUpperCase(TokenPool[I].Val);
                            Inc(FNC);
                          End;
                          Inc(I);
                        End;
                      End;
                      { Attendre ':' }
                      If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                         And (TokenPool[I].Val = ':') Then
                      Begin
                        Inc(I);
                        FTName := 'INTEGER';
                        If (I < TokenCount) And
                           ((TokenPool[I].Kind = TK_IDENT) Or
                            (TokenPool[I].Kind = TK_KEYWORD)) Then
                        Begin
                          FTName := StrUpperCase(TokenPool[I].Val);
                          Inc(I);
                        End;
                        FSz := TPTypeSizeof(FTName);
                        If FSz < 0 Then
                        Begin
                          FTIdx := TypeFindByName(FTName);
                          If FTIdx >= 0 Then
                            FSz := TypeTab[FTIdx].Size
                          Else
                            FSz := 4;
                        End;
                        FTIdx := TypeFindByName(FTName);
                        If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;
                        For FNI := 0 To FNC - 1 Do
                        Begin
                          If (TIdx >= 0) And (FC < MAX_FIELDS) Then
                          Begin
                            TypeTab[TIdx].Fields[FC].Name    := FNames[FNI];
                            TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                            TypeTab[TIdx].Fields[FC].Offset  := VarOfs + CurVarSz;
                            Inc(FC);
                            TypeTab[TIdx].FieldCount := FC;
                            CurVarSz := CurVarSz + FSz;
                          End;
                        End;
                      End
                      Else
                      Begin
                        { pas de ':', avancer }
                        Inc(I);
                      End;
                    End
                    Else
                    Begin
                      { Sauter les tokens inattendus (';' entre champs) }
                      Inc(I);
                    End;
                  End;
                  If CurVarSz > MaxVarSz Then
                    MaxVarSz := CurVarSz;
                  { Passer ')' et ';' }
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ')') Then
                    Inc(I);
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';') Then
                    Inc(I);
                End;
                { Mettre a jour la taille totale du record }
                FOfs := VarOfs + MaxVarSz;
                If TIdx >= 0 Then
                  TypeTab[TIdx].Size := FOfs;
                Continue;
              End;

              { Lire le(s) nom(s) de champ (supporte X, Y: Integer) }
              If (TokenPool[I].Kind <> TK_IDENT) Then
              Begin
                Inc(I);
                Continue;
              End;

              { Collecter tous les noms de champ separes par des virgules }
              FNames[0] := StrUpperCase(TokenPool[I].Val);
              FNC := 1;
              Inc(I);
              While (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                    And (TokenPool[I].Val = ',') Do
              Begin
                Inc(I); { passer la virgule }
                If (I < TokenCount) And (TokenPool[I].Kind = TK_IDENT) Then
                Begin
                  If FNC < 16 Then
                  Begin
                    FNames[FNC] := StrUpperCase(TokenPool[I].Val);
                    Inc(FNC);
                  End;
                  Inc(I);
                End;
              End;

              { Attendre ':' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I)
              Else
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           ((TokenPool[I].Val = ';') Or (TokenPool[I].Val = ')'))) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then Inc(I);
                Continue;
              End;

              { Lire le type du champ }
              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;

              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then
                  FSz := TypeTab[FTIdx].Size
                Else
                  FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;

              { Enregistrer tous les champs collectes }
              For FNI := 0 To FNC - 1 Do
              Begin
                If (TIdx >= 0) And (FC < MAX_FIELDS) Then
                Begin
                  TypeTab[TIdx].Fields[FC].Name    := FNames[FNI];
                  TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                  TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                  Inc(FC);
                  TypeTab[TIdx].FieldCount := FC;
                  FOfs := FOfs + FSz;
                  TypeTab[TIdx].Size := FOfs;
                End;
              End;

              { Passer le ';' entre champs }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            { Passer le ';' apres END }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Continue;
          End;

          { --- SET OF T --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'SET') Then
          Begin
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);

            BaseTN := 'BYTE';
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              BaseTN := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx < 0 Then BTIdx := TY_IDX_BYTE;

            TIdx := TypeAdd(TYK_SET, TName, 32, 4, False, BTIdx);
            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- OBJECT ... END --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'OBJECT') Then
          Begin
            Inc(I);
            FC := 0;
            FOfs := 0;
            ObjPar := '';

            { Heritage : OBJECT(Parent) }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '(') Then
            Begin
              Inc(I);
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                ObjPar := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ')') Then
                Inc(I);

              { Copier les champs du parent }
              BTIdx := TypeFindByName(ObjPar);
              If (BTIdx >= 0) And (TypeTab[BTIdx].Kind = TYK_OBJECT) Then
              Begin
                FC := TypeTab[BTIdx].FieldCount;
                FOfs := TypeTab[BTIdx].Size;
              End;
            End;

            TIdx := TypeAdd(TYK_OBJECT, TName, 0, 4, False, -1);

            { Copier champs du parent si heritage }
            If (ObjPar <> '') And (BTIdx >= 0) Then
            Begin
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].BaseTypeIdx := BTIdx;
                For SIdx := 0 To TypeTab[BTIdx].FieldCount - 1 Do
                Begin
                  If FC < MAX_FIELDS Then
                  Begin
                    TypeTab[TIdx].Fields[SIdx] := TypeTab[BTIdx].Fields[SIdx];
                  End;
                End;
                TypeTab[TIdx].FieldCount := FC;
                TypeTab[TIdx].Size := FOfs;
              End;
            End;

            { Parser les champs et methodes }
            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;

              { Skip CONSTRUCTOR, DESTRUCTOR, PROCEDURE, FUNCTION }
              Up := '';
              If TokenPool[I].Kind = TK_KEYWORD Then
                Up := StrUpperCase(TokenPool[I].Val);
              If (Up = 'CONSTRUCTOR') Or (Up = 'DESTRUCTOR') Or
                 (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
                 (Up = 'VIRTUAL') Or (Up = 'PRIVATE') Or
                 (Up = 'PUBLIC') Or (Up = 'SEGMENT') Then
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then
                  Inc(I);
                Continue;
              End;

              { Champ de l objet }
              If (TokenPool[I].Kind <> TK_IDENT) Then
              Begin
                Inc(I);
                Continue;
              End;
              FName := StrUpperCase(TokenPool[I].Val);
              Inc(I);

              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I)
              Else
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then Inc(I);
                Continue;
              End;

              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;

              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then
                  FSz := TypeTab[FTIdx].Size
                Else
                  FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;

              If (TIdx >= 0) And (FC < MAX_FIELDS) Then
              Begin
                TypeTab[TIdx].Fields[FC].Name    := FName;
                TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                Inc(FC);
                TypeTab[TIdx].FieldCount := FC;
                FOfs := FOfs + FSz;
                TypeTab[TIdx].Size := FOfs;
              End;

              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Continue;
          End;

          { --- Enumeration : (val1, val2, ...) --- }
          If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '(') Then
          Begin
            Inc(I);
            TIdx := TypeAdd(TYK_ENUM, TName, 4, 4, False, -1);
            FC := 0;
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ')')) Do
            Begin
              If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                SIdx := SymAdd(StrUpperCase(TokenPool[I].Val), SK_CONST, TIdx);
                If SIdx >= 0 Then
                  SymTab[SIdx].ImmVal := FC;
                Inc(FC);
              End;
              Inc(I);
            End;
            If I < TokenCount Then Inc(I); { skip ')' }
            If TIdx >= 0 Then
              TypeTab[TIdx].EnumCount := FC;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- Type alias or subrange --- }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
          Begin
            { Subrange: lo..hi }
            ArrLo := TokenPool[I].IntVal;
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '..') Then
            Begin
              Inc(I);
              ArrHi := 0;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrHi := TokenPool[I].IntVal;
                Inc(I);
              End;
              TIdx := TypeAdd(TYK_SUBRANGE, TName, 4, 4, False, TY_IDX_INTEGER);
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].Lo := ArrLo;
                TypeTab[TIdx].Hi := ArrHi;
              End;
              SIdx := SymAdd(TName, SK_TYPE, TIdx);
            End;
          End
          Else If (I < TokenCount) And
                  ((TokenPool[I].Kind = TK_IDENT) Or
                   (TokenPool[I].Kind = TK_KEYWORD)) Then
          Begin
            { Type alias: Type NewName = OldName }
            BaseTN := StrUpperCase(TokenPool[I].Val);
            Inc(I);
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx >= 0 Then
            Begin
              TIdx := TypeAdd(TypeTab[BTIdx].Kind, TName,
                TypeTab[BTIdx].Size, TypeTab[BTIdx].Align,
                TypeTab[BTIdx].IsUnsigned, BTIdx);
              If (TIdx >= 0) And (TypeTab[BTIdx].Kind = TYK_RECORD) Then
              Begin
                TypeTab[TIdx].FieldCount := TypeTab[BTIdx].FieldCount;
                TypeTab[TIdx].Fields := TypeTab[BTIdx].Fields;
              End;
            End
            Else
              TIdx := TypeAdd(TYK_INTEGER, TName, 4, 4, False, -1);
            SIdx := SymAdd(TName, SK_TYPE, TIdx);
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End;
        Continue;
      End;
    End;

    Inc(I);
  End;
End;

{ ------------------------------------------------------------ }
{ FindFieldOffset : trouver l offset d un champ dans un type   }
{ record ou objet. Retourne l offset, ou -1 si non trouve.     }
{ FSize retourne la taille du champ.                           }
{ ------------------------------------------------------------ }

Function FindFieldOffset(TIdx : Integer; Const FName : TString;
                         Var FSize : Integer) : Integer;
Var
  J    : Integer;
  Up   : TString;
  FTI  : Integer;
Begin
  FindFieldOffset := -1;
  FSize := 4;
  If (TIdx < 0) Or (TIdx >= TypeCount) Then Exit;
  If (TypeTab[TIdx].Kind <> TYK_RECORD) And
     (TypeTab[TIdx].Kind <> TYK_OBJECT) Then Exit;

  Up := StrUpperCase(FName);
  For J := 0 To TypeTab[TIdx].FieldCount - 1 Do
  Begin
    If TypeTab[TIdx].Fields[J].Name = Up Then
    Begin
      FindFieldOffset := TypeTab[TIdx].Fields[J].Offset;
      FTI := TypeTab[TIdx].Fields[J].TypeIdx;
      If (FTI >= 0) And (FTI < TypeCount) Then
        FSize := TypeTab[FTI].Size
      Else
        FSize := 4;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GetVarTypeIdx : retourne le TypeIdx d une variable locale,   }
{ parametre ou globale.                                        }
{ ------------------------------------------------------------ }

Function GetVarTypeIdx(PI : Integer; Const Name : TString) : Integer;
Var
  LI, ParI, SI : Integer;
  Up : TString;
Begin
  GetVarTypeIdx := -1;
  Up := StrUpperCase(Name);

  If PI >= 0 Then
  Begin
    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      GetVarTypeIdx := ProcTab[PI].Locals[LI].TypeIdx;
      Exit;
    End;
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      GetVarTypeIdx := ProcTab[PI].Params[ParI].TypeIdx;
      Exit;
    End;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    GetVarTypeIdx := SymTab[SI].TypeIdx;
    Exit;
  End;
End;
{ ============================================================ }
{ TODO 10 - EXPRESSIONS PRIMAIRES                 [IMPLEMENTE] }
{ ============================================================ }

Var
  { Curseur de lecture dans TokenPool pour le parsing du corps }
  EP      : Integer;   { position courante dans TokenPool         }
  EPEnd   : Integer;   { borne superieure (exclusive)             }
  RetLbl  : TString;   { label de retour de la fonction courante  }
  LastPrimaryName : TString; { dernier ident charge par ParsePrimary }
  LastVarTypeIdx : Integer; { type index du dernier ident charge }
  LastExprIsPascalStr : Boolean; { True = EAX pointe sur format Pascal [len][chars][NUL] }

  { Pile de boucles pour Break/Continue (TODO 13) }
  LoopBreakLbl : Array[0..31] Of TString;
  LoopContLbl  : Array[0..31] Of TString;
  LoopTop      : Integer;

{ ------------------------------------------------------------ }
{ EPAtEnd : le curseur est-il a la fin ?                       }
{ ------------------------------------------------------------ }

Function EPAtEnd : Boolean;
Begin
  EPAtEnd := (EP >= EPEnd);
End;

{ ------------------------------------------------------------ }
{ EPPeek : retourne la valeur uppercased du token courant       }
{ sans avancer                                                  }
{ ------------------------------------------------------------ }

Function EPPeek : TString;
Begin
  If EP < EPEnd Then
    EPPeek := StrUpperCase(TokenPool[EP].Val)
  Else
    EPPeek := '';
End;

{ ------------------------------------------------------------ }
{ EPMatch : si le token courant correspond (insensible casse), }
{ avancer et retourner True                                     }
{ ------------------------------------------------------------ }

Function EPMatch(Const S : TString) : Boolean;
Begin
  EPMatch := False;
  If (EP < EPEnd) And (StrUpperCase(TokenPool[EP].Val) = S) Then
  Begin
    Inc(EP);
    EPMatch := True;
  End;
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : generer le code pour charger une variable dans   }
{ EAX (ou MOVZX pour les bytes/chars/booleans)                 }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Ref          : TString;
Begin
  Up := StrUpperCase(Name);
  LastVarTypeIdx := GetVarTypeIdx(PI, Up);
  If PI >= 0 Then
  Begin
    { Lecture du resultat de la fonction : FuncName ou Result }
    { Result n est utilise que s il n y a pas de variable locale nommee RESULT }
    If ProcTab[PI].IsFunction And
       ((ProcTab[PI].Name = Up) Or
        ((Up = 'RESULT') And (FindLocal(PI, 'RESULT') < 0))) Then
    Begin
      EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].RetOffset));
      Exit;
    End;

    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      If (ProcTab[PI].Locals[LI].TypeIdx >= 0) And
         (ProcTab[PI].Locals[LI].TypeIdx < TypeCount) And
         ((TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_RECORD) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_ARRAY) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_OBJECT) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_SET) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_STRING)) Then
      Begin
        EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
        If TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_STRING Then
          LastExprIsPascalStr := True;
        Exit;
      End;
      If ProcTab[PI].Locals[LI].Size = 1 Then
        EmitInstr('MOVZX EAX,BYTE PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset))
      Else
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
      Exit;
    End;

    { Chercher parametre }
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
      Begin
        EmitInstr('MOV EBX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
        EmitInstr('MOV EAX,[EBX]');
      End
      Else
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
      Exit;
    End;
  End;

  { Constante nommee }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_CONST Then
    Begin
      EmitInstr('MOV EAX,' + IntToStr_(SymTab[SI].ImmVal));
      Exit;
    End;
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      { Variable absolute $Seg:$Ofs (TODO 28) }
      If SymTab[SI].IsAbsolute Then
      Begin
        If Opts.Dos16Mode Then
        Begin
          { DOS 16 bits : acces direct segment:offset }
          EmitInstr('PUSH DS');
          EmitInstr('MOV AX,' + IntToStr_(SymTab[SI].AbsSeg));
          EmitInstr('MOV DS,AX');
          If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
            EmitInstr('MOV AL,BYTE PTR DS:[' + IntToStr_(SymTab[SI].AbsOfs) + ']')
          Else
            EmitInstr('MOV AX,WORD PTR DS:[' + IntToStr_(SymTab[SI].AbsOfs) + ']');
          EmitInstr('POP DS');
          If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
            EmitInstr('MOVZX EAX,AL')
          Else
            EmitInstr('MOVZX EAX,AX');
        End
        Else
        Begin
          { Win32 : emulation via _TPRT_READMEM }
          EmitComment('absolute $' + IntToStr_(SymTab[SI].AbsSeg) +
                      ':$' + IntToStr_(SymTab[SI].AbsOfs));
          EmitInstr('MOV EAX,' + IntToStr_(SymTab[SI].AbsSeg));
          EmitInstr('MOV EDX,' + IntToStr_(SymTab[SI].AbsOfs));
          EmitInstr('CALL ' + TP_RT_PFX + 'READMEM');
          { Masquer selon la taille du type }
          If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
            EmitInstr('AND EAX,0FFh')
          Else If TypeSizeofIdx(SymTab[SI].TypeIdx) = 2 Then
            EmitInstr('AND EAX,0FFFFh');
        End;
        Exit;
      End;
      Ref := SymTab[SI].MangledName;
      If (SymTab[SI].TypeIdx >= 0) And (SymTab[SI].TypeIdx < TypeCount) And
         ((TypeTab[SymTab[SI].TypeIdx].Kind = TYK_RECORD) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_ARRAY) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_OBJECT) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_SET) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_STRING)) Then
      Begin
        EmitInstr('LEA EAX,[' + Ref + ']');
        If TypeTab[SymTab[SI].TypeIdx].Kind = TYK_STRING Then
          LastExprIsPascalStr := True;
        Exit;
      End;
      If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
        EmitInstr('MOVZX EAX,BYTE PTR [' + Ref + ']')
      Else
        EmitInstr('MOV EAX,DWORD PTR [' + Ref + ']');
      Exit;
    End;
  End;

  { Par defaut : globale }
  If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
     ((TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_SET) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_STRING)) Then
  Begin
    EmitInstr('LEA EAX,[' + TP_VAR_PFX + Up + ']');
    If TypeTab[LastVarTypeIdx].Kind = TYK_STRING Then
      LastExprIsPascalStr := True;
  End
  Else
    EmitInstr('MOV EAX,DWORD PTR [' + TP_VAR_PFX + Up + ']');
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : generer le code pour stocker EAX dans une      }
{ variable                                                      }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Ref          : TString;
  VarTI        : Integer;
Begin
  Up := StrUpperCase(Name);

  { Variable locale (seulement si dans une proc) }
  If PI >= 0 Then
  Begin
    { Affectation du resultat de la fonction : FuncName := expr ou Result := expr }
    { Result n est utilise que s il n y a pas de variable locale nommee RESULT }
    If ProcTab[PI].IsFunction And
       ((ProcTab[PI].Name = Up) Or
        ((Up = 'RESULT') And (FindLocal(PI, 'RESULT') < 0))) Then
    Begin
      EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].RetOffset) + ',EAX');
      Exit;
    End;

    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      VarTI := ProcTab[PI].Locals[LI].TypeIdx;
      { String : copier la chaine (EAX = src ptr) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_STRING) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
        EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
        Exit;
      End;
      { Record : copier tout le record (EAX = adresse source) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_RECORD) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
        EmitInstr('MOV ECX,' + IntToStr_(TypeTab[VarTI].Size));
        EmitInstr('REP MOVSB');
        Exit;
      End;
      If ProcTab[PI].Locals[LI].Size = 1 Then
        EmitInstr('MOV BYTE PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset) + ',AL')
      Else
        EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset) + ',EAX');
      Exit;
    End;

    { Parametre }
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
      Begin
        EmitInstr('MOV EBX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
        EmitInstr('MOV [EBX],EAX');
      End
      Else
        EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset) + ',EAX');
      Exit;
    End;
  End;

  { Symbole global }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      Ref := SymTab[SI].MangledName;
      VarTI := SymTab[SI].TypeIdx;
      { String : copier la chaine (EAX = src ptr) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_STRING) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,[' + Ref + ']');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
        Exit;
      End;
      { Record : copier tout le record (EAX = adresse source) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_RECORD) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,[' + Ref + ']');
        EmitInstr('MOV ECX,' + IntToStr_(TypeTab[VarTI].Size));
        EmitInstr('REP MOVSB');
        Exit;
      End;
      If TypeSizeofIdx(VarTI) = 1 Then
        EmitInstr('MOV BYTE PTR [' + Ref + '],AL')
      Else
        EmitInstr('MOV DWORD PTR [' + Ref + '],EAX');
      Exit;
    End;
  End;

  { Par defaut : variable globale standard }
  VarTI := GetVarTypeIdx(PI, Up);
  If (VarTI >= 0) And (VarTI < TypeCount) And
     (TypeTab[VarTI].Kind = TYK_STRING) Then
  Begin
    EmitInstr('MOV ESI,EAX');
    EmitInstr('LEA EDI,[' + TP_VAR_PFX + Up + ']');
    EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
  End
  Else If (VarTI >= 0) And (VarTI < TypeCount) And
          (TypeTab[VarTI].Kind = TYK_RECORD) Then
  Begin
    EmitInstr('MOV ESI,EAX');
    EmitInstr('LEA EDI,[' + TP_VAR_PFX + Up + ']');
    EmitInstr('MOV ECX,' + IntToStr_(TypeTab[VarTI].Size));
    EmitInstr('REP MOVSB');
  End
  Else
    EmitInstr('MOV DWORD PTR [' + TP_VAR_PFX + Up + '],EAX');
End;

{ ------------------------------------------------------------ }
{ GenLoadAddr : generer LEA EAX, [variable]                    }
{ ------------------------------------------------------------ }

Procedure GenLoadAddr(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
Begin
  Up := StrUpperCase(Name);

  If PI >= 0 Then
  Begin
    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
      Exit;
    End;

    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset))
      Else
        EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
      Exit;
    End;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If (SymTab[SI].Kind = SK_VAR) Then
    Begin
      EmitInstr('LEA EAX,[' + SymTab[SI].MangledName + ']');
      Exit;
    End;
  End;

  EmitInstr('LEA EAX,[' + TP_VAR_PFX + Up + ']');
End;

{ ------------------------------------------------------------ }
{ Forward declarations TODO 10                                  }
{ ------------------------------------------------------------ }

Procedure ParseExpr(PI : Integer); Forward;
Procedure ParseExprPrec(PI : Integer; MinPrec : Integer); Forward;
Procedure ParseBody(PI : Integer); Forward;

{ ------------------------------------------------------------ }
{ Forward declarations TODO 13                                  }
{ ------------------------------------------------------------ }

Procedure ParseStmt(PI : Integer); Forward;
Procedure ParseIfStmt(PI : Integer); Forward;
Procedure ParseCaseStmt(PI : Integer); Forward;
Procedure ParseWhileStmt(PI : Integer); Forward;
Procedure ParseRepeatStmt(PI : Integer); Forward;
Procedure ParseForStmt(PI : Integer); Forward;
Procedure ParseGotoStmt(PI : Integer); Forward;
Procedure ParseAsmBlock(PI : Integer); Forward;

{ ------------------------------------------------------------ }
{ ParseFuncCall : parser un appel de procedure/fonction         }
{ nom(arg1, arg2, ...) -> PUSH args, CALL _TPF_nom             }
{ Convention stdcall : args gauche-a-droite                     }
{ ------------------------------------------------------------ }

Procedure ParseFuncCall(PI : Integer; Const ProcName : TString);
Var
  ArgCount  : Integer;
  Up        : TString;
  SI        : Integer;
  MName     : TString;
  CalledPI  : Integer;
  J         : Integer;
  IsVarArg  : Boolean;
  ArgName   : TString;
Begin
  Up := StrUpperCase(ProcName);
  ArgCount := 0;

  { Trouver le symbole de la procedure/fonction }
  SI := SymFind(Up);
  If SI >= 0 Then
    MName := SymTab[SI].MangledName
  Else
    MName := TP_FUNC_PFX + Up;

  { Trouver l index dans ProcTab pour connaitre les params VAR }
  CalledPI := -1;
  For J := 0 To ProcCount - 1 Do
    If ProcTab[J].Name = Up Then
    Begin
      CalledPI := J;
      Break;
    End;

  { Consommer '(' si present }
  If EPMatch('(') Then
  Begin
    { Compter et compiler les arguments }
    If Not EPMatch(')') Then
    Begin
      Repeat
        { Determiner si le parametre courant est VAR }
        IsVarArg := False;
        If (CalledPI >= 0) And (ArgCount < ProcTab[CalledPI].ParamCount) Then
          IsVarArg := ProcTab[CalledPI].Params[ArgCount].IsVar;

        If IsVarArg Then
        Begin
          { Parametre VAR : pousser l adresse de la variable }
          If (Not EPAtEnd) And
             ((TokenPool[EP].Kind = TK_IDENT) Or
              (TokenPool[EP].Kind = TK_KEYWORD)) Then
          Begin
            ArgName := TokenPool[EP].Val;
            Inc(EP);
            GenLoadAddr(PI, ArgName);
            EmitInstr('PUSH EAX');
          End
          Else
          Begin
            { Fallback : evaluer et pousser (pas ideal pour VAR) }
            ParseExpr(PI);
            EmitInstr('PUSH EAX');
          End;
        End
        Else
        Begin
          { Parametre normal : evaluer et pousser la valeur }
          ParseExpr(PI);
          EmitInstr('PUSH EAX');
        End;
        Inc(ArgCount);
      Until Not EPMatch(',');
      If Not EPMatch(')') Then
        Inc(EP); { sauter le ')' manquant }
    End;
  End;

  EmitInstr('CALL ' + MName);

  { Nettoyer la pile (convention cdecl/stdcall-like pour nos procs Pascal) }
  If ArgCount > 0 Then
    EmitInstr('ADD ESP,' + IntToStr_(ArgCount * 4));
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire                 }
{ Resultat dans EAX                                             }
{ ------------------------------------------------------------ }

Procedure ParsePrimary(PI : Integer);
Var
  Up     : TString;
  Lbl    : TString;
  SI     : Integer;
  LI     : Integer;
  ParI   : Integer;
  WI     : Integer;
  WFOfs  : Integer;
  WFSize : Integer;
  WJ     : Integer;
Begin
  LastPrimaryName := '';
  LastVarTypeIdx := -1;
  LastExprIsPascalStr := False;

  If EPAtEnd Then Exit;

  { Litteral entier }
  If TokenPool[EP].Kind = TK_INTEGER Then
  Begin
    EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  { Litteral caractere }
  If TokenPool[EP].Kind = TK_CHAR Then
  Begin
    EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  { Litteral chaine }
  If TokenPool[EP].Kind = TK_STRING Then
  Begin
    Lbl := DataGetOrAddStr(TokenPool[EP].Val);
    EmitInstr('LEA EAX,[' + Lbl + ']');
    LastVarTypeIdx := TY_IDX_STRING;
    LastExprIsPascalStr := False;  { literal ASCIIZ, pas format Pascal }
    Inc(EP);
    Exit;
  End;

  { Mot-cle ou identificateur }
  If (TokenPool[EP].Kind = TK_KEYWORD) Or
     (TokenPool[EP].Kind = TK_IDENT) Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { TRUE / FALSE }
    If Up = 'TRUE' Then
    Begin
      EmitInstr('MOV EAX,1');
      Inc(EP);
      Exit;
    End;
    If Up = 'FALSE' Then
    Begin
      EmitInstr('XOR EAX,EAX');
      Inc(EP);
      Exit;
    End;

    { NIL }
    If Up = 'NIL' Then
    Begin
      EmitInstr('XOR EAX,EAX');
      Inc(EP);
      Exit;
    End;

    { Typecast : TypeName(expr) -> evaluer expr, resultat dans EAX }
    If ((Up = 'INTEGER') Or (Up = 'LONGINT') Or (Up = 'WORD') Or
        (Up = 'BYTE') Or (Up = 'SHORTINT') Or (Up = 'CHAR') Or
        (Up = 'BOOLEAN') Or (Up = 'POINTER') Or (Up = 'PCHAR') Or
        (Up = 'REAL') Or (Up = 'SINGLE') Or (Up = 'DOUBLE') Or
        (Up = 'LONGWORD') Or (Up = 'COMP')) And
       (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = '(') Then
    Begin
      Inc(EP);  { sauter le nom de type }
      Inc(EP);  { sauter '(' }
      ParseExpr(PI);
      EPMatch(')');
      { Masquer selon la taille du type cible }
      If (Up = 'BYTE') Or (Up = 'SHORTINT') Or (Up = 'CHAR') Or
         (Up = 'BOOLEAN') Then
        EmitInstr('AND EAX,0FFh')
      Else If Up = 'WORD' Then
        EmitInstr('AND EAX,0FFFFh');
      Exit;
    End;

    { SIZEOF(T) / SIZEOF(V) }
    If Up = 'SIZEOF' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          SI := TypeFindByName(Up);
          If SI >= 0 Then
            EmitInstr('MOV EAX,' + IntToStr_(TypeSizeofIdx(SI)))
          Else
          Begin
            { Chercher comme variable }
            LI := FindLocal(PI, Up);
            If LI >= 0 Then
              EmitInstr('MOV EAX,' + IntToStr_(ProcTab[PI].Locals[LI].Size))
            Else
            Begin
              SI := SymFind(Up);
              If (SI >= 0) And (SymTab[SI].TypeIdx >= 0) Then
                EmitInstr('MOV EAX,' + IntToStr_(TypeSizeofIdx(SymTab[SI].TypeIdx)))
              Else
                EmitInstr('MOV EAX,4');
            End;
          End;
          Inc(EP);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { ORD(x) -> resultat dans EAX (valeur ordinale) }
    If Up = 'ORD' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { EAX contient deja la valeur ordinale }
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { CHR(x) -> resultat dans EAX (caractere) }
    If Up = 'CHR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { SUCC(x) -> x + 1 }
    If Up = 'SUCC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('INC EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { PRED(x) -> x - 1 }
    If Up = 'PRED' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('DEC EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { LO(x) -> octet bas }
    If Up = 'LO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { HI(x) -> octet haut }
    If Up = 'HI' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('SHR EAX,8');
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { ABS(x) -> valeur absolue }
    If Up = 'ABS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CDQ');
        EmitInstr('XOR EAX,EDX');
        EmitInstr('SUB EAX,EDX');
        EPMatch(')');
      End;
      Exit;
    End;

    { SQR(x) -> x * x }
    If Up = 'SQR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('IMUL EAX,EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { ODD(x) -> x AND 1 }
    If Up = 'ODD' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,1');
        EPMatch(')');
      End;
      Exit;
    End;

    { SWAP(x) -> echanger octets bas et haut du word }
    If Up = 'SWAP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('XCHG AL,AH');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- Fonctions math/trig : stubs en mode entier, FPU a venir --- }

    { SQRT(x) -> racine carree via FPU }
    If Up = 'SQRT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SQRT');
        EPMatch(')');
      End;
      Exit;
    End;

    { SIN(x) -> sinus via FPU }
    If Up = 'SIN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SIN');
        EPMatch(')');
      End;
      Exit;
    End;

    { COS(x) -> cosinus via FPU }
    If Up = 'COS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'COS');
        EPMatch(')');
      End;
      Exit;
    End;

    { ARCTAN(x) -> arc tangente via FPU }
    If Up = 'ARCTAN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'ARCTAN');
        EPMatch(')');
      End;
      Exit;
    End;

    { EXP(x) -> exponentielle via FPU }
    If Up = 'EXP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'EXP');
        EPMatch(')');
      End;
      Exit;
    End;

    { LN(x) -> logarithme neperien via FPU }
    If Up = 'LN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'LN');
        EPMatch(')');
      End;
      Exit;
    End;

    { ATAN(x) -> arc tangente (TRANSCEND unit, Apple Pascal) }
    If Opts.ApplePascal And Not Opts.Sane Then
    If Up = 'ATAN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'ARCTAN');
        EPMatch(')');
      End;
      Exit;
    End;

    { LOG(x) -> logarithme base 10 (TRANSCEND unit, Apple Pascal) }
    If Opts.ApplePascal And Not Opts.Sane Then
    If Up = 'LOG' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_LOG10');
        EPMatch(')');
      End;
      Exit;
    End;

    { PWROFTEN(n) -> 10^n (TRANSCEND unit, Apple Pascal) }
    If Opts.ApplePascal And Not Opts.Sane Then
    If Up = 'PWROFTEN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_PWROFTEN');
        EPMatch(')');
      End;
      Exit;
    End;

    { FRAC(x) -> partie fractionnaire (stub: retourne 0 en mode entier) }
    If Up = 'FRAC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitComment('FRAC() stub: retourne 0 en mode entier');
        EmitInstr('XOR EAX,EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { INT(x) -> partie entiere (en mode entier: identite) }
    If Up = 'INT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { En mode entier, Int(x) = x }
        EPMatch(')');
      End;
      Exit;
    End;

    { RANDOM / RANDOM(max) -> nombre aleatoire }
    If Up = 'RANDOM' Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP);  { ( }
        ParseExpr(PI);  { max dans EAX }
        EPMatch(')');
        EmitInstr('PUSH EAX');    { sauver max }
        EmitInstr('CALL ' + TP_RT_PFX + 'RANDOM');
        EmitInstr('POP ECX');     { recuperer max }
        EmitInstr('XOR EDX,EDX');
        EmitInstr('DIV ECX');     { EAX / max }
        EmitInstr('MOV EAX,EDX');  { reste = resultat }
      End
      Else
      Begin
        { Random sans argument -> Random(MaxInt) }
        EmitInstr('CALL ' + TP_RT_PFX + 'RANDOM');
      End;
      Exit;
    End;

    { ROUND(x) / TRUNC(x) -> stub : juste retourner la valeur }
    If (Up = 'ROUND') Or (Up = 'TRUNC') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE identity functions (single arg, result = arg) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'NUM2INTEGER') Or (Up = 'NUM2LONGINT') Or (Up = 'NUM2REAL') Or
       (Up = 'NUM2DOUBLE') Or (Up = 'NUM2EXTENDED') Or (Up = 'NUM2COMP') Or
       (Up = 'RINT') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE stub functions returning 0 (single arg, discarded) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'DEC2NUM') Or (Up = 'LN1') Or (Up = 'NAN') Or
       (Up = 'TESTEXCEPTION') Or (Up = 'TESTHALT') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { --- SANE stub functions returning 0 (no args) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'GETROUND') Or (Up = 'GETPRECISION') Or
       (Up = 'GETHALTVECTOR') Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { --- SANE STR2NUM(s) : string to number --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'STR2NUM' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV ESI,EAX');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRTONUM');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE LOGB(x) / LOG2(x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'LOGB') Or (Up = 'LOG2') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_LOG2');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE EXP2(x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'EXP2' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_EXP2');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE EXP1(x) : stub identity (e^x-1 ~ x for integers) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'EXP1' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE TAN(x) : stub returns 0 --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'TAN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitComment('SANE TAN stub : retourne 0 en mode entier');
        EmitInstr('XOR EAX,EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE SIGNNUM(x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'SIGNNUM' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_SIGNNUM');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE CLASSxxx(x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'CLASSREAL') Or (Up = 'CLASSDOUBLE') Or
       (Up = 'CLASSCOMP') Or (Up = 'CLASSEXTENDED') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CALL ' + TP_RT_PFX + 'SANE_CLASSNUM');
        EPMatch(')');
      End;
      Exit;
    End;

    { --- SANE COPYSIGN(x,y) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'COPYSIGN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_COPYSIGN');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE NEXTxxx(x,y) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'NEXTREAL') Or (Up = 'NEXTDOUBLE') Or
       (Up = 'NEXTEXTENDED') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_NEXTNUM');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE XPWRI(x,i) / XPWRY(x,y) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'XPWRI') Or (Up = 'XPWRY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_XPWRI');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE COMPOUND(r,n) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'COMPOUND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_COMPOUND');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE ANNUITY(r,n) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'ANNUITY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_ANNUITY');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE RELATION(x,y) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'RELATION' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_RELATION');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE SCALB(n,x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'SCALB' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_SCALB');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { --- SANE REMAINDER(x,y,Var Quo) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'REMAINDER' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Quo is a VAR param - push address }
        If Not EPAtEnd Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          EmitInstr('PUSH EAX');
          Inc(EP);
        End;
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_REMAINDER');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { --- SANE RANDOMX(Var x) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'RANDOMX' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { x is a VAR param - push address }
        If Not EPAtEnd Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          EmitInstr('PUSH EAX');
          Inc(EP);
        End;
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_RANDOMX');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { EOF / EOF(f) : tester fin de fichier }
    If Up = 'EOF' Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP);  { consommer ( }
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          If Up = 'INPUT' Then
          Begin
            { EOF(Input) = EOF stdin }
            Inc(EP);
            EmitInstr('MOV EAX,DWORD PTR [STDIN_EOF]');
          End
          Else
          Begin
            { EOF(f) : f est une variable Text }
            GenLoadAddr(PI, TokenPool[EP].Val);
            Inc(EP);
            EmitInstr('PUSH EAX');
            EmitInstr('CALL ' + TP_RT_PFX + 'EOF_FILE');
            EmitInstr('ADD ESP,4');
          End;
        End;
        EPMatch(')');
      End
      Else
      Begin
        { EOF sans argument = EOF(Input) }
        EmitInstr('MOV EAX,DWORD PTR [STDIN_EOF]');
      End;
      Exit;
    End;

    { EOLN / EOLN(f) : tester si le caractere courant est CR/LF }
    If Up = 'EOLN' Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + TP_RT_PFX + 'EOLN_FILE');
          EmitInstr('ADD ESP,4');
        End
        Else
        Begin
          { EOLN(Input) ou pas d argument avec parenthese }
          If Not EPAtEnd Then Inc(EP);
          EmitInstr('CALL ' + TP_RT_PFX + 'EOLN_STDIN');
        End;
        EPMatch(')');
      End
      Else
      Begin
        { EOLN sans argument = EOLN(Input) }
        EmitInstr('CALL ' + TP_RT_PFX + 'EOLN_STDIN');
      End;
      Exit;
    End;

    { SEEKEOF / SEEKEOF(f) : sauter blancs/tabs puis tester EOF }
    If Up = 'SEEKEOF' Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + TP_RT_PFX + 'SEEKEOF_FILE');
          EmitInstr('ADD ESP,4');
        End
        Else
        Begin
          If Not EPAtEnd Then Inc(EP);
          EmitInstr('MOV EAX,DWORD PTR [STDIN_EOF]');
        End;
        EPMatch(')');
      End
      Else
      Begin
        EmitInstr('MOV EAX,DWORD PTR [STDIN_EOF]');
      End;
      Exit;
    End;

    { SEEKEOLN / SEEKEOLN(f) : sauter blancs/tabs puis tester EOL }
    If Up = 'SEEKEOLN' Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + TP_RT_PFX + 'SEEKEOLN_FILE');
          EmitInstr('ADD ESP,4');
        End
        Else
        Begin
          If Not EPAtEnd Then Inc(EP);
          EmitInstr('XOR EAX,EAX');
        End;
        EPMatch(')');
      End
      Else
      Begin
        EmitInstr('XOR EAX,EAX');
      End;
      Exit;
    End;

    { IORESULT : retourne et remet a zero la derniere erreur I/O }
    If Up = 'IORESULT' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [FILE_IOERR]');
      EmitInstr('MOV DWORD PTR [FILE_IOERR],0');
      Exit;
    End;

    { FILEPOS(f) : retourne la position courante dans un fichier }
    If Up = 'FILEPOS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');  { handle fichier }
        EPMatch(')');
      End;
      { SetFilePointer(handle, 0, NULL, FILE_CURRENT=1) -> retourne position }
      EmitInstr('PUSH 1');            { dwMoveMethod = FILE_CURRENT }
      EmitInstr('PUSH 0');            { lpDistanceToMoveHigh       }
      EmitInstr('PUSH 0');            { lDistanceToMove = 0        }
      EmitInstr('PUSH EAX');          { hFile                      }
      EmitInstr('CALL SetFilePointer');
      { EAX = position courante }
      Exit;
    End;

    { FILESIZE(f) : retourne la taille du fichier }
    If Up = 'FILESIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');  { handle fichier }
        EPMatch(')');
      End;
      { GetFileSize(handle, NULL) -> retourne taille }
      EmitInstr('PUSH 0');            { lpFileSizeHigh }
      EmitInstr('PUSH EAX');          { hFile          }
      EmitInstr('CALL GetFileSize');
      { EAX = taille du fichier }
      Exit;
    End;

    { LOW(T) / HIGH(T) }
    If (Up = 'LOW') Or (Up = 'HIGH') Then
    Begin
      Lbl := Up;
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          SI := TypeFindByName(Up);
          If SI >= 0 Then
          Begin
            If Lbl = 'LOW' Then
              EmitInstr('MOV EAX,' + IntToStr_(TypeTab[SI].Lo))
            Else
              EmitInstr('MOV EAX,' + IntToStr_(TypeTab[SI].Hi));
          End
          Else
          Begin
            If Lbl = 'LOW' Then
              EmitInstr('MOV EAX,0')
            Else
              EmitInstr('MOV EAX,0');
          End;
          Inc(EP);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { INC(x[,n]) }
    If Up = 'INC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          If EPMatch(',') Then
          Begin
            ParseExpr(PI);
            EmitInstr('MOV ECX,EAX');
            GenLoadVar(PI, Lbl);
            EmitInstr('ADD EAX,ECX');
          End
          Else
          Begin
            GenLoadVar(PI, Lbl);
            EmitInstr('INC EAX');
          End;
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { DEC(x[,n]) }
    If Up = 'DEC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          If EPMatch(',') Then
          Begin
            ParseExpr(PI);
            EmitInstr('MOV ECX,EAX');
            GenLoadVar(PI, Lbl);
            EmitInstr('SUB EAX,ECX');
          End
          Else
          Begin
            GenLoadVar(PI, Lbl);
            EmitInstr('DEC EAX');
          End;
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { NEW(p) -> HeapAlloc }
    If Up = 'NEW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          EmitInstr('PUSH 4');
          EmitInstr('PUSH 8');   { HEAP_ZERO_MEMORY }
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapAlloc');
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { DISPOSE(p) -> HeapFree }
    If Up = 'DISPOSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadVar(PI, Lbl);
          EmitInstr('PUSH EAX');
          EmitInstr('PUSH 0');
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapFree');
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { GETMEM(p, size) -> HeapAlloc }
    If Up = 'GETMEM' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          EPMatch(',');
          ParseExpr(PI);   { taille dans EAX }
          EmitInstr('PUSH EAX');
          EmitInstr('PUSH 8');   { HEAP_ZERO_MEMORY }
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapAlloc');
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { FREEMEM(p, size) -> HeapFree }
    If Up = 'FREEMEM' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
             (TokenPool[EP].Val = ',') Then
          Begin
            Inc(EP);
            ParseExpr(PI);  { ignorer la taille }
          End;
          GenLoadVar(PI, Lbl);
          EmitInstr('PUSH EAX');
          EmitInstr('PUSH 0');
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapFree');
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { MOVE(source, dest, count) -> REP MOVSB }
    If Up = 'MOVE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);      { source dans EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);      { dest dans EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);      { count dans EAX }
        EmitInstr('MOV ECX,EAX');
        EmitInstr('POP EDI');   { dest }
        EmitInstr('POP ESI');   { source }
        EmitInstr('CLD');
        EmitInstr('REP MOVSB');
        EPMatch(')');
      End;
      Exit;
    End;

    { FILLCHAR(dest, count, value) -> REP STOSB }
    If Up = 'FILLCHAR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);      { dest dans EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);      { count dans EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);      { value dans EAX }
        EmitInstr('POP ECX');   { count }
        EmitInstr('POP EDI');   { dest }
        EmitInstr('CLD');
        EmitInstr('REP STOSB');
        EPMatch(')');
      End;
      Exit;
    End;

    { ASSIGNED(p) -> retourne p <> nil (0 ou 1) dans EAX }
    If Up = 'ASSIGNED' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);      { pointeur dans EAX }
        EmitInstr('TEST EAX,EAX');
        EmitInstr('SETNE AL');
        EmitInstr('MOVZX EAX,AL');
        EPMatch(')');
      End;
      Exit;
    End;

    { ADDR(x) -> adresse de la variable x dans EAX }
    If Up = 'ADDR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { OFS(x) -> offset = adresse (en mode flat, identique a Addr) }
    If Up = 'OFS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { PTR(seg, ofs) -> en Win32 flat, retourne ofs dans EAX }
    If Up = 'PTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);      { seg - ignore en flat mode }
        EPMatch(',');
        ParseExpr(PI);      { ofs -> resultat dans EAX }
        EPMatch(')');
      End;
      Exit;
    End;

    { MAXAVAIL -> retourne la taille du plus gros bloc libre }
    { En Win32, utilise HeapSize sur un bloc test ou retourne 1MB }
    If Up = 'MAXAVAIL' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,1048576');  { 1 MB = valeur raisonnable }
      Exit;
    End;

    { MEMAVAIL -> retourne la memoire disponible }
    { En Win32, retourne une valeur fixe raisonnable }
    If Up = 'MEMAVAIL' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,16777216');  { 16 MB = valeur raisonnable }
      Exit;
    End;

    { MARK(p) -> stub : stocke adresse bidon dans p }
    If Up = 'MARK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          EmitInstr('MOV EAX,0');  { stub }
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { RELEASE(p) -> stub : ne fait rien (obsolete en Win32) }
    If Up = 'RELEASE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then Inc(EP);  { consommer la variable }
        EPMatch(')');
      End;
      Exit;
    End;

    { SETTEXTBUF(f, buf [, size]) -> stub : ne fait rien en Win32 }
    If Up = 'SETTEXTBUF' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then Inc(EP);  { f }
        EPMatch(',');
        If Not EPAtEnd Then Inc(EP);  { buf }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          ParseExpr(PI);  { size }
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { CHDIR(path) -> SetCurrentDirectoryA }
    If Up = 'CHDIR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);        { path dans EAX }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL SetCurrentDirectoryA');
      Exit;
    End;

    { MKDIR(path) -> CreateDirectoryA }
    If Up = 'MKDIR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);        { path dans EAX }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EPMatch(')');
      End;
      EmitInstr('PUSH 0');        { lpSecurityAttributes = NULL }
      EmitInstr('PUSH EAX');      { lpPathName }
      EmitInstr('CALL CreateDirectoryA');
      Exit;
    End;

    { RMDIR(path) -> RemoveDirectoryA }
    If Up = 'RMDIR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);        { path dans EAX }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL RemoveDirectoryA');
      Exit;
    End;

    { GETDIR(drive, var s) -> GetCurrentDirectoryA }
    { drive est ignore en Win32 (toujours le lecteur courant) }
    If Up = 'GETDIR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);    { drive (ignore) }
        EPMatch(',');
        { s : variable chaine de destination }
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
        End;
        EPMatch(')');
      End;
      { GetCurrentDirectoryA(260, DIR_NAMEBUF) }
      EmitInstr('PUSH OFFSET DIR_NAMEBUF');
      EmitInstr('PUSH 260');
      EmitInstr('CALL GetCurrentDirectoryA');
      { Copier DIR_NAMEBUF -> variable chaine Pascal }
      EmitInstr('LEA ESI,[DIR_NAMEBUF]');
      GenLoadAddr(PI, Lbl);
      EmitInstr('MOV EDI,EAX');
      { Mesurer longueur de la chaine ASCIIZ }
      EmitInstr('PUSH EDI');
      EmitInstr('XOR ECX,ECX');
      EmitInstr('MOV EDX,ESI');
      EmitLabel(TP_RT_PFX + 'GDIR_LN');
      EmitInstr('MOV AL,[ESI]');
      EmitInstr('TEST AL,AL');
      EmitInstr('JZ ' + TP_RT_PFX + 'GDIR_CP');
      EmitInstr('INC ECX');
      EmitInstr('INC ESI');
      EmitInstr('JMP ' + TP_RT_PFX + 'GDIR_LN');
      EmitLabel(TP_RT_PFX + 'GDIR_CP');
      EmitInstr('POP EDI');
      EmitInstr('MOV [EDI],CL');     { S[0] = longueur }
      EmitInstr('INC EDI');
      EmitInstr('MOV ESI,EDX');       { source = debut DIR_NAMEBUF }
      EmitInstr('CLD');
      EmitInstr('REP MOVSB');
      EmitInstr('MOV BYTE PTR [EDI],0');  { NUL final }
      Exit;
    End;

    { INCLUDE(S, I) -> BTS (bit test and set) }
    If Up = 'INCLUDE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
        End;
        EPMatch(',');
        ParseExpr(PI);   { I dans EAX }
        EmitInstr('MOV ECX,EAX');   { element }
        GenLoadAddr(PI, Lbl);
        EmitInstr('BTS [EAX],ECX');
        EPMatch(')');
      End;
      Exit;
    End;

    { EXCLUDE(S, I) -> BTR (bit test and reset) }
    If Up = 'EXCLUDE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
        End;
        EPMatch(',');
        ParseExpr(PI);   { I dans EAX }
        EmitInstr('MOV ECX,EAX');   { element }
        GenLoadAddr(PI, Lbl);
        EmitInstr('BTR [EAX],ECX');
        EPMatch(')');
      End;
      Exit;
    End;

    { CSEG -> retourne 0 (non significatif en Win32 flat mode) }
    If Up = 'CSEG' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { DSEG -> retourne 0 (non significatif en Win32 flat mode) }
    If Up = 'DSEG' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { SSEG -> retourne 0 (non significatif en Win32 flat mode) }
    If Up = 'SSEG' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { SPTR -> retourne le pointeur de pile courant }
    If Up = 'SPTR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,ESP');
      Exit;
    End;

    { ---- TODO 16 : Builtins chaines ---- }

    { LENGTH(S) -> longueur String Pascal (S[0]) dans EAX }
    If Up = 'LENGTH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV ESI,EAX');
        If LastExprIsPascalStr Then
          { EAX = pointeur vers String Pascal (S[0] = longueur) }
          EmitInstr('CALL ' + TP_RT_PFX + 'LENGTH')
        Else
          { EAX = pointeur vers ASCIIZ : compter les caracteres }
          EmitInstr('CALL ' + TP_RT_PFX + 'STRLEN');
        EPMatch(')');
      End;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { COPY(S, Pos, Len) -> sous-chaine dans STRBUF1 }
    If Up = 'COPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { S -> ESI }
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');    { sauter l octet de longueur }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Pos -> EBX }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Len -> ECX }
        ParseExpr(PI);
        EmitInstr('MOV ECX,EAX');
        EmitInstr('POP EBX');      { Pos }
        EmitInstr('POP ESI');      { Source ptr }
        EmitInstr('CALL ' + TP_RT_PFX + 'COPY');
        { Resultat : EAX = pointeur vers STRBUF1 (ASCIIZ) }
        LastVarTypeIdx := TY_IDX_STRING;
        LastExprIsPascalStr := False;
        EPMatch(')');
      End;
      Exit;
    End;

    { POS(SubStr, S) -> position (1-based) ou 0 }
    If Up = 'POS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { SubStr -> EDI }
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');    { sauter l octet de longueur }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { S -> ESI }
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');    { sauter l octet de longueur }
        EmitInstr('MOV ESI,EAX');
        EmitInstr('POP EDI');
        EmitInstr('CALL ' + TP_RT_PFX + 'POS');
        { Resultat : EAX = position (1-based) ou 0 }
        EPMatch(')');
      End;
      Exit;
    End;

    { CONCAT(S1, S2, ...) -> chaine concatenee dans STRBUF1 }
    If Up = 'CONCAT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { Premier argument }
        ParseExpr(PI);
        { EAX = pointeur vers s1, copier dans STRBUF1 (ASCIIZ) }
        EmitInstr('MOV ESI,EAX');
        If LastExprIsPascalStr Then
          EmitInstr('INC ESI');         { sauter l octet de longueur }
        EmitInstr('LEA EDI,[STRBUF1]');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN_PCHAR');
        { Arguments suivants : concatener }
        While Not EPAtEnd Do
        Begin
          If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
          Begin
            Inc(EP);
            ParseExpr(PI);
            EmitInstr('MOV EDI,EAX');
            If LastExprIsPascalStr Then
              EmitInstr('INC EDI');     { sauter l octet de longueur }
            EmitInstr('LEA ESI,[STRBUF1]');
            EmitInstr('CALL ' + TP_RT_PFX + 'CONCAT');
          End
          Else
            Break;
        End;
        EmitInstr('LEA EAX,[STRBUF1]');
        EPMatch(')');
      End;
      Exit;
    End;

    { UPCASE(Ch) -> majuscule }
    If Up = 'UPCASE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { EAX = caractere, convertir en majuscule }
        Lbl := LabelGen;
        EmitInstr('CMP AL,97');   { 'a' }
        EmitInstr('JB ' + Lbl);
        EmitInstr('CMP AL,122');  { 'z' }
        EmitInstr('JA ' + Lbl);
        EmitInstr('SUB AL,32');
        EmitLabel(Lbl);
        EPMatch(')');
      End;
      Exit;
    End;

    { ---- TODO 18 : Fonctions CRT (retournent valeur dans EAX) ---- }

    { WHEREX -> colonne courante (1-based) }
    If Up = 'WHEREX' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'WHEREX');
      Exit;
    End;

    { WHEREY -> ligne courante (1-based) }
    If Up = 'WHEREY' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'WHEREY');
      Exit;
    End;

    { KEYPRESSED -> Boolean dans EAX }
    If Up = 'KEYPRESSED' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'KEYPRESSED');
      Exit;
    End;

    { READKEY -> caractere dans EAX }
    If Up = 'READKEY' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'READKEY');
      Exit;
    End;

    { ---- TODO 19 : Fonctions DOS (retournent valeur dans EAX) ---- }

    { PARAMCOUNT -> nombre de parametres (sans argv[0]) }
    If Up = 'PARAMCOUNT' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'PARAMCOUNT');
      Exit;
    End;

    { PARAMSTR(N) -> N-ieme parametre (0=exe, 1..N=args) }
    If Up = 'PARAMSTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'PARAMSTR');
      EmitInstr('ADD ESP,4');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { DOSVERSION -> version DOS emulee }
    If Up = 'DOSVERSION' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'DOSVERSION');
      Exit;
    End;

    { DISKFREE(Drive) -> espace libre en octets }
    If Up = 'DISKFREE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'DISKFREE');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { DISKSIZE(Drive) -> taille totale en octets }
    If Up = 'DISKSIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'DISKSIZE');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { GETENV(Name) -> chaine d environnement }
    If Up = 'GETENV' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { Si l argument est un Pascal String, sauter l octet de longueur }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'GETENV');
      EmitInstr('ADD ESP,4');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { FSEARCH(Name, DirList) -> chemin trouve }
    If Up = 'FSEARCH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FSEARCH');
      EmitInstr('ADD ESP,8');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { FEXPAND(Path) -> chemin complet }
    If Up = 'FEXPAND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'FEXPAND');
      EmitInstr('ADD ESP,4');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { ENVCOUNT -> nombre de variables d'environnement }
    If Up = 'ENVCOUNT' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'ENVCOUNT');
      Exit;
    End;

    { ENVSTR(Index) -> 'NAME=VALUE' }
    If Up = 'ENVSTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'ENVSTR');
      EmitInstr('ADD ESP,4');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;
      Exit;
    End;

    { DOSEXITCODE -> code retour du dernier Exec }
    If Up = 'DOSEXITCODE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [DOSEXITCODE]');
      Exit;
    End;

    { ---- TODO 20 : Fonctions Graph (retournent valeur dans EAX) ---- }

    { GETMAXX -> largeur max de l ecran graphique }
    If Up = 'GETMAXX' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXX]');
      Exit;
    End;

    { GETMAXY -> hauteur max de l ecran graphique }
    If Up = 'GETMAXY' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXY]');
      Exit;
    End;

    { GETX -> position X courante }
    If Up = 'GETX' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_CPX]');
      Exit;
    End;

    { GETY -> position Y courante }
    If Up = 'GETY' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_CPY]');
      Exit;
    End;

    { GRAPHRESULT -> code resultat derniere operation }
    If Up = 'GRAPHRESULT' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_RESULT]');
      EmitInstr('MOV DWORD PTR [GR_RESULT],0'); { reset apres lecture }
      Exit;
    End;

    { GETPIXEL(X, Y) -> couleur du pixel }
    If Up = 'GETPIXEL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('PUSH DWORD PTR [GR_HDC]');
      EmitInstr('CALL ' + TP_RT_PFX + 'GETPIXEL');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { GETMAXCOLOR -> nombre max de couleurs }
    If Up = 'GETMAXCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXCOLOR]');
      Exit;
    End;

    { GETCOLOR -> couleur de dessin courante }
    If Up = 'GETCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
      Exit;
    End;

    { GETBKCOLOR -> couleur de fond courante }
    If Up = 'GETBKCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_BKCOLOR]');
      Exit;
    End;

    { GRAPHERRORMSG(Code) -> pointeur chaine erreur }
    If Up = 'GRAPHERRORMSG' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'GRAPHERRORMSG');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { IMAGESIZE(X1, Y1, X2, Y2) -> taille en octets }
    If Up = 'IMAGESIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'IMAGESIZE');
      EmitInstr('ADD ESP,16');
      Exit;
    End;

    { GETDRIVERNAME -> pointeur chaine nom pilote }
    If Up = 'GETDRIVERNAME' Then
    Begin
      Inc(EP);
      EmitInstr('LEA EAX,[GR_DRVNAME]');
      Exit;
    End;

    { GETMODENAME(ModeNum) -> pointeur chaine nom mode }
    If Up = 'GETMODENAME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('LEA EAX,[GR_MODNAME]');
      Exit;
    End;

    { GETMAXMODE -> mode maximum }
    If Up = 'GETMAXMODE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,2');  { VGAHi = 2 }
      Exit;
    End;

    { INSTALLUSERDRIVER(Name, AutoDetect) -> numero pilote }
    If Up = 'INSTALLUSERDRIVER' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('InstallUserDriver (stub)');
      EmitInstr('MOV EAX,0');
      Exit;
    End;

    { INSTALLUSERFONT -> numero fonte }
    If Up = 'INSTALLUSERFONT' Then
    Begin
      Inc(EP);
      EmitComment('InstallUserFont (stub)');
      EmitInstr('MOV EAX,0');
      Exit;
    End;

    { TEXTHEIGHT(S) -> hauteur du texte en pixels }
    If Up = 'TEXTHEIGHT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'TEXTHEIGHT');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { TEXTWIDTH(S) -> largeur du texte en pixels }
    If Up = 'TEXTWIDTH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'TEXTWIDTH');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { REGISTERBGIDRIVER(Driver) -> stub retourne 0 }
    If Up = 'REGISTERBGIDRIVER' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { REGISTERBGIFONT(Font) -> stub retourne 0 }
    If Up = 'REGISTERBGIFONT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { GETGRAPHMODE -> retourne GR_MODE }
    If Up = 'GETGRAPHMODE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_MODE]');
      Exit;
    End;

    { GETPALETTESIZE -> retourne 16 (EGA/VGA) }
    If Up = 'GETPALETTESIZE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,16');
      Exit;
    End;

    { ---- MSGraph functions (QuickPascal mode) ---- }

    { _GRSTATUS -> GR_RESULT }
    If Up = '_GRSTATUS' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_RESULT]');
      Exit;
    End;

    { _SETVIDEOMODE(mode) -> ouvre/ferme fenetre graphique, retourne nb lignes }
    If Up = '_SETVIDEOMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End
      Else EmitInstr('XOR EAX,EAX');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETVIDEOMODE');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { _SETVIDEOMODEROWS(mode, rows) -> appel _TPRT_SETVIDEOMODE, ignore rows }
    If Up = '_SETVIDEOMODEROWS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  { rows ignore }
        EPMatch(')');
      End
      Else EmitInstr('PUSH 0');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETVIDEOMODE');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { _GETACTIVEPAGE -> GR_ACTIVE }
    If Up = '_GETACTIVEPAGE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_ACTIVE]');
      Exit;
    End;

    { _GETVISUALPAGE -> 0 (stub) }
    If Up = '_GETVISUALPAGE' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETCOLOR -> GR_COLOR }
    If Up = '_GETCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
      Exit;
    End;

    { _GETBKCOLOR -> GR_BKCOLOR }
    If Up = '_GETBKCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_BKCOLOR]');
      Exit;
    End;

    { _GETLINESTYLE -> GR_LINESTYLE }
    If Up = '_GETLINESTYLE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_LINESTYLE]');
      Exit;
    End;

    { _GETWRITEMODE -> GR_WRITEMODE }
    If Up = '_GETWRITEMODE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [GR_WRITEMODE]');
      Exit;
    End;

    { _GETPIXEL(x,y) -> same as GETPIXEL }
    If Up = '_GETPIXEL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('PUSH DWORD PTR [GR_HDC]');
      EmitInstr('CALL ' + TP_RT_PFX + 'GETPIXEL');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { _GETPIXEL_W(wx,wy) -> stub, returns 0 }
    If Up = '_GETPIXEL_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _IMAGESIZE(x1,y1,x2,y2) -> same as IMAGESIZE }
    If Up = '_IMAGESIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'IMAGESIZE');
      EmitInstr('ADD ESP,16');
      Exit;
    End;

    { _IMAGESIZE_W / _IMAGESIZE_WXY -> stub returns 0 }
    If (Up = '_IMAGESIZE_W') Or (Up = '_IMAGESIZE_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETARCINFO(var SP, EP, FP) -> stub returns 0 }
    If Up = '_GETARCINFO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETFILLMASK(var mask) -> stub returns False (0) }
    If Up = '_GETFILLMASK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _REMAPPALETTE(index, value) -> stub returns 0 }
    If Up = '_REMAPPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _SELECTPALETTE(n) -> stub returns 0 }
    If Up = '_SELECTPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _SETTEXTROWS(rows) -> stub returns rows }
    If Up = '_SETTEXTROWS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      Exit;
    End;

    { _WRAPON(opt) -> stub returns 0 }
    If Up = '_WRAPON' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _DISPLAYCURSOR(toggle) -> stub returns 0 }
    If Up = '_DISPLAYCURSOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETTEXTCURSOR -> stub returns 0 }
    If Up = '_GETTEXTCURSOR' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETTEXTCOLOR -> stub returns 15 }
    If Up = '_GETTEXTCOLOR' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,15');
      Exit;
    End;

    { _REGISTERFONTS(path) -> stub returns 0 }
    If Up = '_REGISTERFONTS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _SETFONT(opts) -> stub returns 0 }
    If Up = '_SETFONT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETGTEXTEXTENT(s) -> stub returns 0 }
    If Up = '_GETGTEXTEXTENT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { _GETFONTINFO(var finfo) -> stub returns 0 }
    If Up = '_GETFONTINFO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('XOR EAX,EAX');
      Exit;
    End;

    { ---- TODO 21 : Fonctions Strings (retournent valeur dans EAX) ---- }

    { STRLEN(S) -> longueur de la chaine PChar }
    If Up = 'STRLEN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL lstrlenA');
      Exit;
    End;

    { STRCOPY(Dest, Source) -> PChar (copie chaine, retourne Dest) }
    { = StrCopy() de l unite Strings, utilise _TPRT_STRCPY         }
    If Up = 'STRCOPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Dest }
        EPMatch(',');
        ParseExpr(PI);                           { Source }
        EPMatch(')');
      End;
      { ESI = Source (deja dans EAX), EDI = Dest (sur pile) }
      EmitInstr('MOV ESI,EAX');
      EmitInstr('POP EDI');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
      { EAX = Dest (retourne par STRCPY) }
      Exit;
    End;

    { STRCAT(Dest, Source) -> PChar (concatene, retourne Dest) }
    If Up = 'STRCAT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Dest }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Source }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCAT');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { STRCOMP(S1, S2) -> Integer (comparaison PChar) }
    If Up = 'STRCOMP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV EDI,EAX');
        EmitInstr('POP ESI');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCMP');
      Exit;
    End;

    { STRICOMP(S1, S2) -> Integer (comparaison insensible a la casse) }
    If Up = 'STRICOMP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL lstrcmpiA');
      Exit;
    End;

    { STRLICOMP(S1, S2, MaxLen) -> Integer (comparaison insensible, limitee) }
    If Up = 'STRLICOMP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRLICOMP');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { STRPOS(S1, S2) -> PChar (position sous-chaine ou NIL) }
    If Up = 'STRPOS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRPOS');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { STRSCAN(S, C) -> PChar (premiere occurrence du caractere) }
    If Up = 'STRSCAN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRSCAN');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { STRRSCAN(S, C) -> PChar (derniere occurrence du caractere) }
    If Up = 'STRRSCAN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRRSCAN');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { STREND(S) -> PChar (pointeur vers le zero terminal) }
    If Up = 'STREND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STREND');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { STRMOVE(Dest, Source, Count) -> PChar }
    If Up = 'STRMOVE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRMOVE');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { STRNEW(S) -> PChar (alloue copie sur le heap) }
    If Up = 'STRNEW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRNEW');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { STRPAS(S) -> String (convertit PChar en Pascal string) }
    If Up = 'STRPAS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRPAS');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { STRPCOPY(Dest, Source) -> PChar (copie Pascal string vers PChar) }
    If Up = 'STRPCOPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRPCOPY');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { STRUPPER(S) -> PChar (convertit en majuscules in-place) }
    If Up = 'STRUPPER' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRUPPER');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { STRLOWER(S) -> PChar (convertit en minuscules in-place) }
    If Up = 'STRLOWER' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRLOWER');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { STRLCOPY(Dest, Source, MaxLen) -> PChar (copie limitee) }
    If Up = 'STRLCOPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRLCOPY');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { STRLCAT(Dest, Source, MaxLen) -> PChar (concatenation limitee) }
    If Up = 'STRLCAT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRLCAT');
      EmitInstr('ADD ESP,12');
      Exit;
    End;

    { STRECOPY(Dest, Source) -> PChar (copie, retourne fin de dest) }
    If Up = 'STRECOPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STRECOPY');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { ---- TODO 21 : Fonctions Overlay (retournent valeur dans EAX) ---- }

    { OVRGETBUF -> taille buffer overlay (stub, retourne 0) }
    If Up = 'OVRGETBUF' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [OVR_BUFSIZE]');
      Exit;
    End;

    { OVRGETRETURNCODE -> code retour overlay (stub, retourne 0) }
    If Up = 'OVRGETRETURNCODE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [OVR_RESULT]');
      Exit;
    End;

    { ---- TODO 21 : Fonctions Turbo3 (retournent valeur dans EAX) ---- }
    { GraphColorMode et GraphMode comme fonctions retournent mode }
    If Up = 'GRAPHCOLORMODE' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      EmitInstr('MOV AL,4');  { mode 4 : 320x200x4 couleurs }
      EmitComment('GraphColorMode (Turbo3 compat) -> 4');
      Exit;
    End;

    If Up = 'GRAPHMODE' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      EmitInstr('MOV AL,6');  { mode 6 : 640x200 mono }
      EmitComment('GraphMode (Turbo3 compat) -> 6');
      Exit;
    End;

    { ---- TODO 21 : Fonctions Objects (retournent valeur dans EAX) ---- }

    { NEWSTR(S) : allouer copie chaine sur le tas -> PString }
    If Up = 'NEWSTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'NEWSTR');
      EmitInstr('ADD ESP,4');
      Exit;
    End;

    { TCOLLECTION_COUNT -> retourne le nombre d elements }
    If Up = 'TCOLLECTION_COUNT' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      EmitComment('TCollection.Count (stub) -> 0');
      Exit;
    End;

    { TCOLLECTION_AT(Index) -> retourne element a l index }
    If Up = 'TCOLLECTION_AT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('XOR EAX,EAX');
      EmitComment('TCollection.At (stub) -> NIL');
      Exit;
    End;

    { TCOLLECTION_INDEXOF(Item) -> retourne index ou -1 }
    If Up = 'TCOLLECTION_INDEXOF' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV EAX,-1');
      EmitComment('TCollection.IndexOf (stub) -> -1');
      Exit;
    End;

    { TSTREAM_GETPOS -> retourne position courante }
    If Up = 'TSTREAM_GETPOS' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPPOS]');
      Exit;
    End;

    { TSTREAM_GETSIZE -> retourne taille du stream }
    If Up = 'TSTREAM_GETSIZE' Then
    Begin
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPSIZ]');
      Exit;
    End;

    { TSTREAM_GET -> lire objet depuis stream (stub -> NIL) }
    If Up = 'TSTREAM_GET' Then
    Begin
      Inc(EP);
      EmitInstr('XOR EAX,EAX');
      EmitComment('TStream.Get (stub) -> NIL');
      Exit;
    End;

    { TSTREAM_READ(Buf, Count) -> lire octets }
    If Up = 'TSTREAM_READ' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Buf }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Count }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_READ');
      EmitInstr('ADD ESP,8');
      Exit;
    End;

    { ---- TODO 22 : Mem[Seg:Ofs] / MemW[Seg:Ofs] / MemL[Seg:Ofs] en lecture ---- }
    If (Up = 'MEM') Or (Up = 'MEMW') Or (Up = 'MEML') Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        ParseExpr(PI);           { EAX = Seg }
        EmitInstr('PUSH EAX');   { sauvegarder Seg }
        { Attendre ':' separateur Seg:Ofs }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ':') Then
          Inc(EP);
        ParseExpr(PI);           { EAX = Ofs }
        EmitInstr('MOV EDX,EAX');  { EDX = Ofs }
        EmitInstr('POP EAX');      { EAX = Seg }
        { Appeler _TPRT_READMEM : EAX=seg, EDX=ofs -> resultat dans EAX }
        EmitInstr('CALL ' + TP_RT_PFX + 'READMEM');
        { Masquer selon la taille }
        If Up = 'MEM' Then
          EmitInstr('AND EAX,0FFh')       { octet : 8 bits }
        Else If Up = 'MEMW' Then
          EmitInstr('AND EAX,0FFFFh');     { mot : 16 bits }
        { MEML : pas de masque, 32 bits complet }
        EPMatch(']');
      End;
      Exit;
    End;

    { ---- TODO 22 : Port[$nn] / PortW[$nn] en lecture ---- }
    If (Up = 'PORT') Or (Up = 'PORTW') Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        ParseExpr(PI);           { EAX = numero de port }
        { Appeler _TPRT_INPORT : EAX=port -> resultat dans EAX }
        EmitInstr('CALL ' + TP_RT_PFX + 'INPORT');
        If Up = 'PORT' Then
          EmitInstr('AND EAX,0FFh')       { octet }
        Else
          EmitInstr('AND EAX,0FFFFh');     { mot 16 bits }
        EPMatch(']');
      End;
      Exit;
    End;

    { Appel de procedure/fonction ? }
    SI := SymFind(Up);
    If (SI >= 0) And
       ((SymTab[SI].Kind = SK_PROC) Or (SymTab[SI].Kind = SK_FUNC)) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      Exit;
    End;

    { Verificr aussi dans ProcTab }
    If SI < 0 Then
    Begin
      LI := 0;
      While LI < ProcCount Do
      Begin
        If ProcTab[LI].Name = Up Then
        Begin
          Inc(EP);
          ParseFuncCall(PI, Up);
          Exit;
        End;
        Inc(LI);
      End;
    End;

    { WITH : resoudre champ implicite en lecture }
    If (WithDepth > 0) Then
    Begin
      WI := WithDepth - 1;
      While WI >= 0 Do
      Begin
        WFSize := 4;
        WFOfs := FindFieldOffset(WithTypeIdx[WI], Up, WFSize);
        If WFOfs >= 0 Then Break;
        Dec(WI);
      End;
      If (WI >= 0) And (WFOfs >= 0) Then
      Begin
        GenLoadAddr(PI, WithVarName[WI]);
        If WFOfs > 0 Then
          EmitInstr('ADD EAX,' + IntToStr_(WFOfs));
        { Mettre a jour le type du champ }
        LastVarTypeIdx := WithTypeIdx[WI];
        For WJ := 0 To TypeTab[LastVarTypeIdx].FieldCount - 1 Do
          If TypeTab[LastVarTypeIdx].Fields[WJ].Name = Up Then
          Begin
            LastVarTypeIdx := TypeTab[LastVarTypeIdx].Fields[WJ].TypeIdx;
            Break;
          End;
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_STRING) Then
        Begin
          LastExprIsPascalStr := True;
        End
        Else If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
                ((TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
                 (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT)) Then
          { EAX pointe deja sur le sous-record }
        Else If WFSize = 1 Then
          EmitInstr('MOVZX EAX,BYTE PTR [EAX]')
        Else
          EmitInstr('MOV EAX,[EAX]');
        LastPrimaryName := Up;
        Inc(EP);
        Exit;
      End;
    End;

    { Variable ou constante : charger dans EAX }
    LastPrimaryName := Up;
    LastVarTypeIdx := GetVarTypeIdx(PI, Up);
    GenLoadVar(PI, Up);
    Inc(EP);
    Exit;
  End;

  { Constructeur d ensemble : [elem1, elem2, lo..hi, ...] }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '[') Then
  Begin
    Inc(EP); { sauter '[' }
    EmitInstr('XOR EAX,EAX');  { EAX = ensemble vide (bitmask) }
    While (Not EPAtEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ']')) Do
    Begin
      EmitInstr('PUSH EAX');          { sauvegarder ensemble courant }
      ParseExpr(PI);                  { EAX = valeur element }
      { Verifier si c est un intervalle (lo..hi) }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '..') Then
      Begin
        Inc(EP);                      { sauter '..' }
        EmitInstr('PUSH EAX');        { sauvegarder lo }
        ParseExpr(PI);               { EAX = hi }
        { EAX=hi, [ESP]=lo, [ESP+4]=ensemble }
        EmitInstr('MOV EDX,EAX');     { EDX = hi }
        EmitInstr('POP ECX');         { ECX = lo }
        EmitInstr('POP EBX');         { EBX = ensemble courant }
        Lbl := LabelGen;
        EmitLabel(Lbl);
        EmitInstr('CMP ECX,EDX');
        EmitInstr('JG ' + Lbl + 'E');
        EmitInstr('BTS EBX,ECX');
        EmitInstr('INC ECX');
        EmitInstr('JMP ' + Lbl);
        EmitLabel(Lbl + 'E');
        EmitInstr('MOV EAX,EBX');     { EAX = ensemble mis a jour }
      End
      Else
      Begin
        { Element simple : positionner 1 bit }
        EmitInstr('MOV ECX,EAX');     { ECX = numero du bit }
        EmitInstr('POP EAX');         { EAX = ensemble courant }
        EmitInstr('BTS EAX,ECX');     { positionner le bit }
      End;
      { Sauter la virgule si presente }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ',') Then
        Inc(EP);
    End;
    If Not EPAtEnd Then Inc(EP);  { sauter ']' }
    Exit;
  End;

  { Expression entre parentheses }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
  Begin
    Inc(EP);
    ParseExpr(PI);
    EPMatch(')');
    Exit;
  End;

  { Token non reconnu : avancer }
  Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : parser les suffixes apres une expression       }
{ primaire : [index], .champ, ^dereference                     }
{ ------------------------------------------------------------ }

Procedure ParsePostfix(PI : Integer);
Var
  Up : TString;
  ElemSz : Integer;
  FOfs : Integer;
  FSize : Integer;
  SavedTypeIdx : Integer;
Begin
  While Not EPAtEnd Do
  Begin
    { Dereference : ^ }
    If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '^') Then
    Begin
      Inc(EP);
      EmitInstr('MOV EBX,EAX');
      EmitInstr('MOV EAX,[EBX]');
      Continue;
    End;

    { Acces tableau : [index] ou [i,j] multi-dimensionnel }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '[') Then
    Begin
      Inc(EP);
      { Premiere dimension }
      SavedTypeIdx := LastVarTypeIdx;
      EmitInstr('PUSH EAX');         { sauvegarder adresse base }
      ParseExpr(PI);
      LastVarTypeIdx := SavedTypeIdx;
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
         (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
         (TypeTab[LastVarTypeIdx].Lo <> 0) Then
        EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
         (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
         (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
      Begin
        ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
        If ElemSz = 1 Then
        Else If ElemSz = 2 Then EmitInstr('SHL EAX,1')
        Else If ElemSz = 4 Then EmitInstr('SHL EAX,2')
        Else If ElemSz = 8 Then EmitInstr('SHL EAX,3')
        Else EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
        LastVarTypeIdx := TypeTab[LastVarTypeIdx].BaseTypeIdx;
      End
      Else
        EmitInstr('SHL EAX,2');
      EmitInstr('POP EBX');
      EmitInstr('ADD EAX,EBX');      { EAX = adresse element }
      { Dimensions supplementaires separees par ',' }
      While (Not EPAtEnd) And
            (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
      Begin
        Inc(EP);  { consommer ',' }
        SavedTypeIdx := LastVarTypeIdx;
        EmitInstr('PUSH EAX');
        ParseExpr(PI);
        LastVarTypeIdx := SavedTypeIdx;
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].Lo <> 0) Then
          EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
        Begin
          ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
          If ElemSz = 1 Then
          Else If ElemSz = 2 Then EmitInstr('SHL EAX,1')
          Else If ElemSz = 4 Then EmitInstr('SHL EAX,2')
          Else If ElemSz = 8 Then EmitInstr('SHL EAX,3')
          Else EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
          LastVarTypeIdx := TypeTab[LastVarTypeIdx].BaseTypeIdx;
        End
        Else
          EmitInstr('SHL EAX,2');
        EmitInstr('POP EBX');
        EmitInstr('ADD EAX,EBX');
      End;
      { EAX = adresse finale de l element }
      EmitInstr('MOV EBX,EAX');
      { Charger la valeur selon le type de l element }
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) Then
      Begin
        If TypeTab[LastVarTypeIdx].Size = 1 Then
          EmitInstr('MOVZX EAX,BYTE PTR [EBX]')
        Else If (TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
                (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT) Then
          EmitInstr('LEA EAX,[EBX]')
        Else If TypeTab[LastVarTypeIdx].Kind = TYK_STRING Then
        Begin
          EmitInstr('LEA EAX,[EBX]');
          LastExprIsPascalStr := True;
        End
        Else
          EmitInstr('MOV EAX,[EBX]');
      End
      Else
        EmitInstr('MOV EAX,[EBX]');
      EPMatch(']');
      Continue;
    End;

    { Acces champ : .field (record/objet) }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        Up := StrUpperCase(TokenPool[EP].Val);
        Inc(EP);
        FSize := 4;
        FOfs := FindFieldOffset(LastVarTypeIdx, Up, FSize);
        If FOfs >= 0 Then
        Begin
          If FOfs > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(FOfs));
          { Mettre a jour le type courant }
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) Then
          Begin
            For ElemSz := 0 To TypeTab[LastVarTypeIdx].FieldCount - 1 Do
              If TypeTab[LastVarTypeIdx].Fields[ElemSz].Name = Up Then
              Begin
                LastVarTypeIdx := TypeTab[LastVarTypeIdx].Fields[ElemSz].TypeIdx;
                Break;
              End;
          End;
          { Charger la valeur du champ }
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
             ((TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
              (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT)) Then
            { EAX pointe deja sur le sous-record }
          Else If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
                  (TypeTab[LastVarTypeIdx].Kind = TYK_STRING) Then
          Begin
            { EAX pointe sur le champ String (Pascal string) }
            LastExprIsPascalStr := True;
          End
          Else If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
                  (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) Then
            { EAX pointe sur le debut du tableau }
          Else If FSize = 1 Then
            EmitInstr('MOVZX EAX,BYTE PTR [EAX]')
          Else
            EmitInstr('MOV EAX,[EAX]');
        End
        Else
          EmitComment('champ inconnu: ' + Up);
      End;
      Continue;
    End;

    Break;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser les operateurs unaires prefixes           }
{ NOT, @, -, +                                                  }
{ ------------------------------------------------------------ }

Procedure ParseUnary(PI : Integer);
Var
  Up : TString;
Begin
  If EPAtEnd Then Exit;

  Up := StrUpperCase(TokenPool[EP].Val);

  { NOT }
  If (TokenPool[EP].Kind = TK_KEYWORD) And (Up = 'NOT') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    EmitInstr('XOR EAX,1');
    Exit;
  End;

  { Negation unaire - }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '-') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    EmitInstr('NEG EAX');
    Exit;
  End;

  { Plus unaire + (no-op) }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '+') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    Exit;
  End;

  { Adresse @ }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '@') Then
  Begin
    Inc(EP);
    If Not EPAtEnd Then
    Begin
      Up := StrUpperCase(TokenPool[EP].Val);
      GenLoadAddr(PI, Up);
      Inc(EP);
    End;
    Exit;
  End;

  { Expression primaire }
  ParsePrimary(PI);
  ParsePostfix(PI);
End;

{ ============================================================ }
{ TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE [IMPLEMENTE]     }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ BinOpPrec : retourner le niveau de precedence d un operateur  }
{ binaire Pascal. 0 = pas un operateur binaire.                 }
{ Niveaux de precedence Pascal (plus haut = lie plus fort) :    }
{   3 : * / DIV MOD AND SHL SHR  (multiplicatif)               }
{   2 : + - OR XOR               (additif)                     }
{   1 : = <> < > <= >= IN        (relationnel)                  }
{ ------------------------------------------------------------ }

Function BinOpPrec(Const Op : TString) : Integer;
Var
  U : TString;
Begin
  U := Op;
  If (U = '*') Or (U = '/') Or (U = 'DIV') Or (U = 'MOD') Or
     (U = 'AND') Or (U = 'SHL') Or (U = 'SHR') Then
    BinOpPrec := 3
  Else If (U = '+') Or (U = '-') Or (U = 'OR') Or (U = 'XOR') Then
    BinOpPrec := 2
  Else If (U = '=') Or (U = '<>') Or (U = '<') Or (U = '>') Or
          (U = '<=') Or (U = '>=') Or (U = 'IN') Then
    BinOpPrec := 1
  Else
    BinOpPrec := 0;
End;

{ ------------------------------------------------------------ }
{ EmitBinOp : emettre le code ASM pour EAX op EBX              }
{ Le resultat doit rester dans EAX.                             }
{ ------------------------------------------------------------ }

Procedure EmitBinOp(Const Op : TString);
Var
  LblTrue, LblEnd : TString;
Begin
  { Arithmetique }
  If Op = '+' Then
    EmitInstr('ADD EAX,EBX')
  Else If Op = '-' Then
    EmitInstr('SUB EAX,EBX')
  Else If Op = '*' Then
    EmitInstr('IMUL EAX,EBX')
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
  { Decalages }
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
  { Bit a bit / Logique }
  Else If Op = 'AND' Then
    EmitInstr('AND EAX,EBX')
  Else If Op = 'OR' Then
    EmitInstr('OR EAX,EBX')
  Else If Op = 'XOR' Then
    EmitInstr('XOR EAX,EBX')
  { Comparaisons }
  Else If Op = '=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<>' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JNE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JL ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JLE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JG ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JGE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  { IN (ensemble) : BT [set], val }
  Else If Op = 'IN' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('BT EBX,EAX');
    EmitInstr('JC ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else
    EmitComment('; operateur binaire inconnu: ' + Op);
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : parseur de Pratt pour expressions Pascal      }
{ MinPrec = niveau de precedence minimal a capturer.            }
{ Le resultat est toujours dans EAX.                            }
{ Gere le court-circuit pour AND et OR booleens.                }
{ ------------------------------------------------------------ }

Procedure ParseExprPrec(PI : Integer; MinPrec : Integer);
Var
  Op       : TString;
  Prec     : Integer;
  LblF     : TString;
  LblE     : TString;
  LeftIsStr : Boolean;
  LeftPascal : Boolean;
Begin
  ParseUnary(PI);

  While Not EPAtEnd Do
  Begin
    { Lire l operateur courant }
    Op := '';
    If TokenPool[EP].Kind = TK_OP Then
      Op := StrUpperCase(TokenPool[EP].Val)
    Else If TokenPool[EP].Kind = TK_KEYWORD Then
      Op := StrUpperCase(TokenPool[EP].Val);

    Prec := BinOpPrec(Op);
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    { Detecter si la partie gauche est une chaine }
    LeftIsStr := TypeIsString(LastVarTypeIdx);
    LeftPascal := LastExprIsPascalStr;

    Inc(EP); { consommer l operateur }

    { --- Concatenation de chaines avec + (TODO 16) --- }
    If (Op = '+') And LeftIsStr Then
    Begin
      EmitInstr('MOV ESI,EAX');        { ESI = chaine gauche  }
      If LeftPascal Then
        EmitInstr('INC ESI');           { sauter l octet de longueur }
      EmitInstr('LEA EDI,[STRBUF1]');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN_PCHAR');
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('MOV EDI,EAX');        { EDI = chaine droite  }
      If LastExprIsPascalStr Then
        EmitInstr('INC EDI');           { sauter l octet de longueur }
      EmitInstr('LEA ESI,[STRBUF1]');
      EmitInstr('CALL ' + TP_RT_PFX + 'CONCAT');
      EmitInstr('LEA EAX,[STRBUF1]');
      LastVarTypeIdx := TY_IDX_STRING;
      LastExprIsPascalStr := False;     { STRBUF1 est ASCIIZ }
      Continue;
    End;

    { --- Comparaison de chaines (TODO 16) --- }
    If ((Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
        (Op = '<=') Or (Op = '>=')) And LeftIsStr Then
    Begin
      If LeftPascal Then
        EmitInstr('INC EAX');           { sauter l octet de longueur gauche }
      EmitInstr('PUSH EAX');            { sauver gauche }
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('MOV EDI,EAX');         { EDI = droite  }
      If LastExprIsPascalStr Then
        EmitInstr('INC EDI');           { sauter l octet de longueur droite }
      EmitInstr('POP ESI');             { ESI = gauche  }
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCOMPARE');
      { EAX = resultat strcompare: <0, 0, >0 }
      LblF := LabelGen;
      LblE := LabelGen;
      If Op = '=' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JZ ' + LblF);
      End
      Else If Op = '<>' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNZ ' + LblF);
      End
      Else If Op = '<' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JS ' + LblF);
      End
      Else If Op = '>' Then
      Begin
        EmitInstr('CMP EAX,0');
        EmitInstr('JG ' + LblF);
      End
      Else If Op = '<=' Then
      Begin
        EmitInstr('CMP EAX,0');
        EmitInstr('JLE ' + LblF);
      End
      Else If Op = '>=' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNS ' + LblF);
      End;
      EmitInstr('XOR EAX,EAX');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('MOV EAX,1');
      EmitLabel(LblE);
      LastVarTypeIdx := TY_IDX_BOOLEAN;
      Continue;
    End;

    { --- Court-circuit AND (ET logique) --- }
    If Op = 'AND' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      EmitInstr('MOV EAX,1');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('XOR EAX,EAX');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Court-circuit OR (OU logique) --- }
    If Op = 'OR' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      EmitInstr('XOR EAX,EAX');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('MOV EAX,1');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Operateurs binaires normaux --- }
    { Sauver la valeur gauche (EAX) sur la pile }
    EmitInstr('PUSH EAX');

    ParseExprPrec(PI, Prec + 1);

    { EAX = droite, pile = gauche }
    EmitInstr('MOV EBX,EAX');
    EmitInstr('POP EAX');
    EmitBinOp(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : parser une expression complete                    }
{ Appelle ParseExprPrec avec la precedence minimale (1).        }
{ ------------------------------------------------------------ }

Procedure ParseExpr(PI : Integer);
Begin
  ParseExprPrec(PI, 1);
End;

{ ============================================================ }
{ TODO 12 - ENTREES/SORTIES                       [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ InferExprType : deviner le type de l expression courante      }
{ en examinant le premier token sans avancer EP.                }
{ Retourne un TY_IDX_* valide.                                 }
{ ------------------------------------------------------------ }

Function InferExprType(PI : Integer) : Integer;
Var
  Up : TString;
  SI, LI : Integer;
  ResultType : Integer;
  FUp : TString;
  FJ  : Integer;

  { Descendre dans les types ARRAY si un '[' suit }
  Function ResolveArrayElement(TI : Integer) : Integer;
  Var P, Depth : Integer;
  Begin
    ResolveArrayElement := TI;
    If (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = '[') Then
    Begin
      { Compter le nombre de dimensions (virgules + 1) en scannant }
      P := EP + 2;
      Depth := 0;
      While (TI >= 0) And (TI < TypeCount) And
            (TypeTab[TI].Kind = TYK_ARRAY) Do
      Begin
        TI := TypeTab[TI].BaseTypeIdx;
        Inc(Depth);
        { Verifier s il y a une virgule pour la dimension suivante }
        { Scan forward pour trouver la prochaine ',' au meme niveau }
        { Approche simplifiee : descendre tant que c est un array }
      End;
      ResolveArrayElement := TI;
    End;
  End;

Begin
  InferExprType := TY_IDX_INTEGER;
  If EP >= EPEnd Then Exit;

  If TokenPool[EP].Kind = TK_STRING Then
  Begin
    InferExprType := TY_IDX_STRING;
    Exit;
  End;

  If TokenPool[EP].Kind = TK_CHAR Then
  Begin
    InferExprType := TY_IDX_CHAR;
    Exit;
  End;

  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If (Up = 'TRUE') Or (Up = 'FALSE') Then
    Begin
      InferExprType := TY_IDX_BOOLEAN;
      Exit;
    End;

    { Chercher dans les variables locales }
    If PI >= 0 Then
    Begin
      LI := FindLocal(PI, Up);
      If LI >= 0 Then
      Begin
        ResultType := ProcTab[PI].Locals[LI].TypeIdx;
        InferExprType := ResolveArrayElement(ResultType);
        Exit;
      End;
      LI := FindParam(PI, Up);
      If LI >= 0 Then
      Begin
        ResultType := ProcTab[PI].Params[LI].TypeIdx;
        InferExprType := ResolveArrayElement(ResultType);
        Exit;
      End;
    End;

    { Builtins retournant une chaine }
    If (Up = 'PARAMSTR') Or (Up = 'COPY') Or (Up = 'CONCAT')
       Or (Up = 'GETENV') Or (Up = 'FEXPAND') Or (Up = 'FSEARCH')
       Or (Up = 'ENVSTR') Or (Up = 'GRAPHERRORMSG')
       Or (Up = 'GETDRIVERNAME') Or (Up = 'GETMODENAME') Then
    Begin
      InferExprType := TY_IDX_STRING;
      Exit;
    End;

    { Chercher dans les symboles globaux }
    SI := SymFind(Up);
    If SI >= 0 Then
    Begin
      ResultType := SymTab[SI].TypeIdx;
      ResultType := ResolveArrayElement(ResultType);
      { Resoudre l acces champ record : Var.Field }
      If (EP + 2 < EPEnd) And
         (TokenPool[EP + 1].Kind = TK_PUNCT) And
         (TokenPool[EP + 1].Val = '.') And
         (TokenPool[EP + 2].Kind = TK_IDENT) Then
      Begin
        If (ResultType >= 0) And (ResultType < TypeCount) And
           ((TypeTab[ResultType].Kind = TYK_RECORD) Or
            (TypeTab[ResultType].Kind = TYK_OBJECT)) Then
        Begin
          FUp := StrUpperCase(TokenPool[EP + 2].Val);
          For FJ := 0 To TypeTab[ResultType].FieldCount - 1 Do
            If TypeTab[ResultType].Fields[FJ].Name = FUp Then
            Begin
              ResultType := TypeTab[ResultType].Fields[FJ].TypeIdx;
              Break;
            End;
        End;
      End;
      InferExprType := ResultType;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitPrintEAX : emettre le code pour afficher EAX selon le    }
{ type. EAX contient la valeur a afficher.                     }
{ String -> appel de _TPRT_PRINTSTR (EAX=pointeur ASCIIZ)     }
{ Char -> ecriture d un caractere unique via WriteFile          }
{ Boolean -> 'TRUE' ou 'FALSE'                                 }
{ Integer -> conversion en chaine puis affichage               }
{ ------------------------------------------------------------ }

Procedure EmitPrintEAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
  IsStrType : Boolean;
Begin
  IsStrType := (TypeIdx = TY_IDX_STRING) Or
               ((TypeIdx >= 0) And (TypeIdx < TypeCount) And
                (TypeTab[TypeIdx].Kind = TYK_STRING));
  If IsStrType Then
  Begin
    { EAX = pointeur vers chaine }
    EmitInstr('MOV ESI,EAX');
    If LastExprIsPascalStr Then
      EmitInstr('INC ESI');           { sauter l octet de longueur }
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    { EAX = caractere -> stocker dans STRTMP et afficher }
    EmitInstr('MOV BYTE PTR [STRTMP],AL');
    EmitInstr('MOV BYTE PTR [STRTMP+1],0');
    EmitInstr('LEA ESI,[STRTMP]');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    { EAX = 0 -> FALSE, sinon -> TRUE }
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstr('TEST EAX,EAX');
    EmitInstr('JZ ' + LblFalse);
    EmitInstr('LEA ESI,[TRUE_STR]');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblFalse);
    EmitInstr('LEA ESI,[FALSE_STR]');
    EmitLabel(LblDone);
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    { Integer / Word / Byte / autre -> convertir en chaine }
    EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');
    EmitInstr('LEA ESI,[NUMBUF]');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitFilePrintEAX : emettre le code pour ecrire EAX dans un   }
{ fichier via _TPRT_FPRINTSTR (FILE_WRHND doit etre positionne).}
{ Meme logique que EmitPrintEAX mais ecrit dans le fichier.     }
{ ------------------------------------------------------------ }

Procedure EmitFilePrintEAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
  IsStrType : Boolean;
Begin
  IsStrType := (TypeIdx = TY_IDX_STRING) Or
               ((TypeIdx >= 0) And (TypeIdx < TypeCount) And
                (TypeTab[TypeIdx].Kind = TYK_STRING));
  If IsStrType Then
  Begin
    EmitInstr('MOV ESI,EAX');
    If LastExprIsPascalStr Then
      EmitInstr('INC ESI');
    EmitInstr('CALL ' + TP_RT_PFX + 'FPRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    EmitInstr('MOV BYTE PTR [STRTMP],AL');
    EmitInstr('MOV BYTE PTR [STRTMP+1],0');
    EmitInstr('LEA ESI,[STRTMP]');
    EmitInstr('CALL ' + TP_RT_PFX + 'FPRINTSTR');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstr('TEST EAX,EAX');
    EmitInstr('JZ ' + LblFalse);
    EmitInstr('LEA ESI,[TRUE_STR]');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblFalse);
    EmitInstr('LEA ESI,[FALSE_STR]');
    EmitLabel(LblDone);
    EmitInstr('CALL ' + TP_RT_PFX + 'FPRINTSTR');
  End
  Else
  Begin
    EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');
    EmitInstr('LEA ESI,[NUMBUF]');
    EmitInstr('CALL ' + TP_RT_PFX + 'FPRINTSTR');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseWriteStmt : parser Write(args) ou WriteLn(args).         }
{ EP pointe apres WRITE/WRITELN deja consomme.                 }
{ Gere plusieurs arguments separes par virgule.                }
{ Gere le formatage :width (ignore pour l instant).            }
{ ------------------------------------------------------------ }

Procedure ParseWriteStmt(PI : Integer; IsWriteLn : Boolean);
Var
  TIdx : Integer;
  FmtWidth : Integer;
  IsFileWrite : Boolean;
  FVarTIdx    : Integer;
  Up          : TString;
  LI, SI      : Integer;
Begin
  If IsWriteLn Then
    EmitComment('writeln')
  Else
    EmitComment('write');

  IsFileWrite := False;

  { Gerer WriteLn sans arguments -> juste CR+LF }
  If EPAtEnd Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstr('LEA ESI,[CRLF]');
      EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Si pas de parenthese, WriteLn sans args }
  If Not ((TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(')) Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstr('LEA ESI,[CRLF]');
      EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Consommer ( }
  Inc(EP);

  { Detecter si le premier argument est une variable fichier Text }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    FVarTIdx := TY_IDX_INTEGER;
    If PI >= 0 Then
    Begin
      LI := FindLocal(PI, Up);
      If LI >= 0 Then
        FVarTIdx := ProcTab[PI].Locals[LI].TypeIdx
      Else
      Begin
        LI := FindParam(PI, Up);
        If LI >= 0 Then FVarTIdx := ProcTab[PI].Params[LI].TypeIdx;
      End;
    End;
    If FVarTIdx <> TY_IDX_TEXT Then
    Begin
      SI := SymFind(Up);
      If SI >= 0 Then FVarTIdx := SymTab[SI].TypeIdx;
    End;
    If FVarTIdx = TY_IDX_TEXT Then
    Begin
      { Ecriture dans un fichier }
      IsFileWrite := True;
      GenLoadAddr(PI, TokenPool[EP].Val);
      Inc(EP);
      EmitInstr('MOV EAX,DWORD PTR [EAX]');    { charger le handle }
      EmitInstr('MOV DWORD PTR [FILE_WRHND],EAX');
      { Sauter la virgule si presente }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ',') Then
        Inc(EP);
    End;
  End;

  { Boucle sur les arguments }
  While Not EPAtEnd Do
  Begin
    { Fin des arguments ? }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Break;

    { Determiner le type de l argument }
    TIdx := InferExprType(PI);

    { Evaluer l expression }
    ParseExpr(PI);

    { Detecter formatage :width }
    FmtWidth := 0;
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
      Begin
        Inc(EP); { consommer : }
        If Not EPAtEnd Then
        Begin
          If TokenPool[EP].Kind = TK_INTEGER Then
          Begin
            FmtWidth := TokenPool[EP].IntVal;
            Inc(EP);
          End
          Else
          Begin
            { Largeur dynamique : evaluer mais ignorer pour l instant }
            EmitInstr('PUSH EAX');
            ParseExpr(PI);
            EmitInstr('POP EAX');
          End;
        End;
        { Si :w:d (formatage flottant) : ignorer aussi d }
        If Not EPAtEnd Then
        Begin
          If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
          Begin
            Inc(EP);
            If Not EPAtEnd Then
            Begin
              If TokenPool[EP].Kind = TK_INTEGER Then
                Inc(EP)
              Else
                ParseExpr(PI);
            End;
          End;
        End;
      End;
    End;

    { Afficher selon le type, avec padding si :width }
    If (FmtWidth > 0) Then
    Begin
      EmitInstr('MOV ECX,' + IntToStr_(FmtWidth));
      EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');
      EmitInstr('LEA ESI,[NUMBUF]');
      EmitInstr('CALL ' + TP_RT_PFX + 'PADPRINT');
    End
    Else If IsFileWrite Then
      EmitFilePrintEAX(TIdx)
    Else
      EmitPrintEAX(TIdx);

    { Virgule entre arguments }
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;
  End;

  { Consommer ) }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Inc(EP);

  { WriteLn : ajouter CR+LF }
  If IsWriteLn Then
  Begin
    EmitInstr('LEA ESI,[CRLF]');
    If IsFileWrite Then
      EmitInstr('CALL ' + TP_RT_PFX + 'FPRINTSTR')
    Else
      EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseReadStmt : parser Read(vars) ou ReadLn(vars).            }
{ EP pointe apres READ/READLN deja consomme.                   }
{ Lit une ligne depuis STDIN, puis parse les variables.         }
{ ------------------------------------------------------------ }

Procedure ParseReadStmt(PI : Integer; IsReadLn : Boolean);
Var
  VName, Up : TString;
  SI, LI    : Integer;
  TIdx      : Integer;
  IsFileRead: Boolean;
  FVarTIdx  : Integer;
Begin
  If IsReadLn Then
    EmitComment('readln')
  Else
    EmitComment('read');

  { ReadLn sans arguments : lire et jeter une ligne }
  If EPAtEnd Or
     Not ((TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(')) Then
  Begin
    If IsReadLn Then
      EmitInstr('CALL ' + TP_RT_PFX + 'READLN');
    Exit;
  End;

  { Consommer ( }
  Inc(EP);

  { Detecter si le premier argument est une variable fichier Text }
  IsFileRead := False;
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    FVarTIdx := TY_IDX_INTEGER;  { defaut }
    If PI >= 0 Then
    Begin
      LI := FindLocal(PI, Up);
      If LI >= 0 Then
        FVarTIdx := ProcTab[PI].Locals[LI].TypeIdx
      Else
      Begin
        LI := FindParam(PI, Up);
        If LI >= 0 Then FVarTIdx := ProcTab[PI].Params[LI].TypeIdx;
      End;
    End;
    If FVarTIdx <> TY_IDX_TEXT Then
    Begin
      SI := SymFind(Up);
      If SI >= 0 Then FVarTIdx := SymTab[SI].TypeIdx;
    End;
    If FVarTIdx = TY_IDX_TEXT Then
    Begin
      { Lecture depuis un fichier }
      IsFileRead := True;
      GenLoadAddr(PI, TokenPool[EP].Val);
      Inc(EP);
      EmitInstr('PUSH EAX');  { adresse de la variable fichier }
      EmitInstr('CALL ' + TP_RT_PFX + 'READLN_FILE');
      EmitInstr('ADD ESP,4');
      { Sauter la virgule si presente }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ',') Then
        Inc(EP);
    End;
  End;

  If Not IsFileRead Then
  Begin
    { Lire une ligne depuis STDIN dans INBUF }
    EmitInstr('CALL ' + TP_RT_PFX + 'READLN');
  End;

  { Boucle sur les variables }
  While Not EPAtEnd Do
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Break;

    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Up := StrUpperCase(VName);
      Inc(EP);

      { Determiner le type de la variable }
      TIdx := TY_IDX_INTEGER;
      If PI >= 0 Then
      Begin
        LI := FindLocal(PI, Up);
        If LI >= 0 Then
          TIdx := ProcTab[PI].Locals[LI].TypeIdx
        Else
        Begin
          LI := FindParam(PI, Up);
          If LI >= 0 Then
            TIdx := ProcTab[PI].Params[LI].TypeIdx;
        End;
      End;
      If TIdx = TY_IDX_INTEGER Then
      Begin
        SI := SymFind(Up);
        If SI >= 0 Then
          TIdx := SymTab[SI].TypeIdx;
      End;

      If (TIdx = TY_IDX_STRING) Or (TIdx = TY_IDX_PCHAR) Then
      Begin
        { Copier INBUF vers la variable string }
        EmitInstr('LEA ESI,[INBUF]');
        GenLoadAddr(PI, VName);
        EmitInstr('MOV EDI,EAX');
        { Copier octet par octet }
        EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
      End
      Else If TIdx = TY_IDX_CHAR Then
      Begin
        { Prendre le premier caractere de INBUF }
        EmitInstr('MOVZX EAX,BYTE PTR [INBUF]');
        GenStoreVar(PI, VName);
      End
      Else
      Begin
        { Integer : convertir INBUF en nombre }
        EmitInstr('LEA ESI,[INBUF]');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRTONUM');
        GenStoreVar(PI, VName);
      End;
    End
    Else
      Inc(EP); { sauter token inconnu }

    { Virgule entre variables }
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;
  End;

  { Consommer ) }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseStrStmt : parser Str(N[:W], S)                          }
{ Convertit un nombre en chaine.                               }
{ ------------------------------------------------------------ }

Procedure ParseStrStmt(PI : Integer);
Var
  VName : TString;
Begin
  EmitComment('str');

  { Consommer ( }
  If Not EPMatch('(') Then Exit;

  { Evaluer l expression numerique }
  ParseExpr(PI);

  { Ignorer le formatage :width }
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        If TokenPool[EP].Kind = TK_INTEGER Then
          Inc(EP)
        Else
          ParseExpr(PI);
      End;
    End;
  End;

  { Convertir en chaine }
  EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');

  { Consommer , }
  EPMatch(',');

  { Variable cible }
  If Not EPAtEnd Then
  Begin
    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Inc(EP);

      { Copier NUMBUF vers la variable string }
      EmitInstr('LEA ESI,[NUMBUF]');
      GenLoadAddr(PI, VName);
      EmitInstr('MOV EDI,EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
    End;
  End;

  { Consommer ) }
  EPMatch(')');
End;

{ ------------------------------------------------------------ }
{ ParseValStmt : parser Val(S, N, Code)                        }
{ Convertit une chaine en nombre.                              }
{ ------------------------------------------------------------ }

Procedure ParseValStmt(PI : Integer);
Var
  VName : TString;
Begin
  EmitComment('val');

  { Consommer ( }
  If Not EPMatch('(') Then Exit;

  { Evaluer l expression chaine }
  ParseExpr(PI);
  If LastExprIsPascalStr Then
    EmitInstr('INC EAX');   { Pascal -> ASCIIZ : sauter l octet de longueur }
  EmitInstr('MOV ESI,EAX');

  { Convertir en nombre }
  EmitInstr('CALL ' + TP_RT_PFX + 'STRTONUM');

  { Consommer , }
  EPMatch(',');

  { Variable numerique cible }
  If Not EPAtEnd Then
  Begin
    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Inc(EP);
      GenStoreVar(PI, VName);
    End;
  End;

  { Troisieme argument Code : stocker 0 (pas d erreur) }
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        If TokenPool[EP].Kind = TK_IDENT Then
        Begin
          VName := TokenPool[EP].Val;
          Inc(EP);
          EmitInstr('XOR EAX,EAX');
          GenStoreVar(PI, VName);
        End;
      End;
    End;
  End;

  { Consommer ) }
  EPMatch(')');
End;

{ ============================================================ }
{ TODO 13 - STRUCTURES DE CONTROLE                [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ LoopPush : empiler un contexte de boucle (Break/Continue)     }
{ ------------------------------------------------------------ }

Procedure LoopPush(Const LblBreak, LblCont : TString);
Begin
  Inc(LoopTop);
  If LoopTop > 31 Then
  Begin
    WarnMsg('trop de boucles imbriquees');
    Dec(LoopTop);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := LblBreak;
  LoopContLbl[LoopTop]  := LblCont;
End;

{ ------------------------------------------------------------ }
{ LoopPop : depiler un contexte de boucle                       }
{ ------------------------------------------------------------ }

Procedure LoopPop;
Begin
  If LoopTop >= 0 Then
    Dec(LoopTop);
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : parser IF cond THEN stmt [ELSE stmt]           }
{ EP pointe sur IF a l entree.                                  }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt(PI : Integer);
Var
  LblElse  : TString;
  LblEndIf : TString;
  HasElse  : Boolean;
Begin
  EmitComment('if');

  Inc(EP);  { consommer IF }

  { Evaluer la condition }
  ParseExpr(PI);

  LblElse  := LabelGen;
  LblEndIf := LabelGen;

  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblElse);

  { Consommer THEN }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'THEN') Then
      Inc(EP);

  { Parser l instruction du THEN }
  ParseStmt(PI);

  { Detecter ELSE }
  HasElse := False;
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'ELSE') Then
      HasElse := True;

  If HasElse Then
  Begin
    EmitInstr('JMP ' + LblEndIf);
    EmitLabel(LblElse);
    Inc(EP);  { consommer ELSE }
    ParseStmt(PI);
    EmitLabel(LblEndIf);
  End
  Else
    EmitLabel(LblElse);
End;

{ ------------------------------------------------------------ }
{ ParseCaseStmt : parser CASE expr OF val: stmt; ... END       }
{ EP pointe sur CASE a l entree.                                }
{ ------------------------------------------------------------ }

Procedure ParseCaseStmt(PI : Integer);
Var
  LblEnd  : TString;
  LblNext : TString;
  LblHit  : TString;
  Up      : TString;
  CaseVal : LongInt;
  RangeHi : LongInt;
Begin
  EmitComment('case');

  Inc(EP);  { consommer CASE }

  { Evaluer l expression selecteur }
  ParseExpr(PI);
  EmitInstr('PUSH EAX');  { sauvegarder le selecteur sur la pile }

  { Consommer OF }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'OF') Then
      Inc(EP);

  LblEnd := LabelGen;

  { Boucle sur les branches du CASE }
  While Not EPAtEnd Do
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END ou ELSE : sortir de la boucle des branches }
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       ((Up = 'END') Or (Up = 'ELSE') Or (Up = 'OTHERWISE')) Then
      Break;

    { Semicolons isoles : sauter }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
    Begin
      Inc(EP);
      Continue;
    End;

    LblNext := LabelGen;
    LblHit  := LabelGen;

    { Analyser les valeurs separees par des virgules }
    While Not EPAtEnd Do
    Begin
      { Detecter ':' (fin des valeurs pour cette branche) }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
        Break;

      { Lire la valeur }
      CaseVal := 0;
      If TokenPool[EP].Kind = TK_INTEGER Then
      Begin
        CaseVal := TokenPool[EP].IntVal;
        Inc(EP);
      End
      Else If (TokenPool[EP].Kind = TK_CHAR) And
              (Length(TokenPool[EP].Val) > 0) Then
      Begin
        CaseVal := Ord(TokenPool[EP].Val[1]);
        Inc(EP);
      End
      Else
      Begin
        ParseExpr(PI);
        { Valeur dans EAX, stocker en EBX }
        EmitInstr('MOV EBX,EAX');
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,EBX');
        EmitInstr('JE ' + LblHit);

        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          Continue;
        End
        Else
          Break;
      End;

      { Detecter plage val1..val2 }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '..') Then
      Begin
        Inc(EP);  { consommer .. }
        RangeHi := 0;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_INTEGER) Then
        Begin
          RangeHi := TokenPool[EP].IntVal;
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
        EmitInstr('JB ' + LblNext);
        EmitInstr('CMP EAX,' + IntToStr_(RangeHi));
        EmitInstr('JBE ' + LblHit);
        EmitInstr('JMP ' + LblNext);
      End
      Else
      Begin
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
        EmitInstr('JE ' + LblHit);
      End;

      { Virgule : valeurs multiples }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;

    { Aucune valeur ne correspond -> sauter a la branche suivante }
    EmitInstr('JMP ' + LblNext);
    EmitLabel(LblHit);

    { Consommer ':' }
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ':') Then
      Inc(EP);

    { Parser l instruction de cette branche }
    ParseStmt(PI);

    { Consommer le ; optionnel }
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ';') Then
      Inc(EP);

    { Sauter a la fin du CASE }
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblNext);
  End;

  { Gerer la clause ELSE / OTHERWISE }
  If Not EPAtEnd Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       ((Up = 'ELSE') Or (Up = 'OTHERWISE')) Then
    Begin
      Inc(EP);
      { Consommer ':' optionnel apres ELSE }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
        Inc(EP);
      EmitComment('case default');
      { Parser les instructions de la clause par defaut jusqu a END }
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[EP].Val) = 'END') Then
          Break;
        ParseStmt(PI);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
      End;
    End;
  End;

  EmitLabel(LblEnd);
  EmitInstr('POP EAX');  { depiler le selecteur }

  { Consommer END }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'END') Then
      Inc(EP);

  { Consommer ; optionnel apres END }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : parser WHILE cond DO stmt                   }
{ EP pointe sur WHILE a l entree.                               }
{ Labels : _TPL_WTEST_N, _TPL_WEND_N                           }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt(PI : Integer);
Var
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');

  Inc(EP);  { consommer WHILE }

  LblTest := LabelGen;
  LblEnd  := LabelGen;

  { Label de test }
  EmitLabel(LblTest);

  { Evaluer la condition }
  ParseExpr(PI);

  { TEST EAX,EAX / JZ fin }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblEnd);

  { Consommer DO }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
      Inc(EP);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblTest);

  { Parser le corps de la boucle }
  ParseStmt(PI);

  { Consommer ; optionnel apres le corps }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);

  { Retour au test }
  EmitInstr('JMP ' + LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseRepeatStmt : parser REPEAT stmts UNTIL cond             }
{ EP pointe sur REPEAT a l entree.                              }
{ Labels : _TPL_RBEG_N, _TPL_REND_N                            }
{ ------------------------------------------------------------ }

Procedure ParseRepeatStmt(PI : Integer);
Var
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('repeat');

  Inc(EP);  { consommer REPEAT }

  LblBeg := LabelGen;
  LblEnd := LabelGen;

  { Label debut }
  EmitLabel(LblBeg);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblBeg);

  { Parser les instructions jusqu a UNTIL }
  While Not EPAtEnd Do
  Begin
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'UNTIL') Then
      Break;
    ParseStmt(PI);
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ';') Then
      Inc(EP);
  End;

  { Consommer UNTIL }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'UNTIL') Then
      Inc(EP);

  { Evaluer la condition }
  ParseExpr(PI);

  { TEST EAX,EAX / JZ debut (si faux, on boucle) }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblBeg);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : parser FOR id := lo TO|DOWNTO hi DO stmt      }
{ EP pointe sur FOR a l entree.                                 }
{ Labels : _TPL_FTEST_N, _TPL_FCONT_N, _TPL_FEND_N            }
{ ------------------------------------------------------------ }

Procedure ParseForStmt(PI : Integer);
Var
  VarName  : TString;
  LimLabel : TString;
  LblTest  : TString;
  LblEnd   : TString;
  LblCont  : TString;
  IsDownTo : Boolean;
Begin
  EmitComment('for');

  Inc(EP);  { consommer FOR }

  { Lire la variable de boucle }
  If EPAtEnd Or (TokenPool[EP].Kind <> TK_IDENT) Then Exit;
  VarName := TokenPool[EP].Val;
  Inc(EP);

  { Consommer := }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = ':=') Then
      Inc(EP);

  { Evaluer l expression de depart }
  ParseExpr(PI);

  { Stocker la valeur de depart dans la variable }
  GenStoreVar(PI, VarName);

  { Detecter TO ou DOWNTO }
  IsDownTo := False;
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'TO') Then
      Inc(EP)
    Else If (TokenPool[EP].Kind = TK_KEYWORD) And
            (StrUpperCase(TokenPool[EP].Val) = 'DOWNTO') Then
    Begin
      IsDownTo := True;
      Inc(EP);
    End;
  End;

  { Evaluer l expression limite }
  ParseExpr(PI);

  { Stocker la limite dans une variable data temporaire }
  LimLabel := LabelGen;
  DataAddDWord(LimLabel, 0);  { Allouer la variable temporaire pour la limite }
  EmitInstr('MOV DWORD PTR [' + LimLabel + '],EAX');

  { Generer les labels de boucle }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblCont := LabelGen;

  { Consommer DO }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
      Inc(EP);

  { Label de test }
  EmitLabel(LblTest);

  { Test : CMP variable, limite }
  GenLoadVar(PI, VarName);
  EmitInstr('CMP EAX,DWORD PTR [' + LimLabel + ']');
  If IsDownTo Then
    EmitInstr('JL ' + LblEnd)
  Else
    EmitInstr('JG ' + LblEnd);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblCont);

  { Parser le corps de la boucle }
  ParseStmt(PI);

  { Consommer ; optionnel apres le corps }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);

  { Label continue (increment) }
  EmitLabel(LblCont);

  { Increment ou decrement de la variable }
  GenLoadVar(PI, VarName);
  If IsDownTo Then
    EmitInstr('DEC EAX')
  Else
    EmitInstr('INC EAX');
  GenStoreVar(PI, VarName);

  { Retour au test }
  EmitInstr('JMP ' + LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;

  { Ajouter la variable limite dans le segment de donnees }
  DataAddDWord(LimLabel, 0);
End;

{ ------------------------------------------------------------ }
{ ParseGotoStmt : parser GOTO label                            }
{ EP pointe sur GOTO a l entree.                                }
{ ------------------------------------------------------------ }

Procedure ParseGotoStmt(PI : Integer);
Var
  LblName : TString;
Begin
  EmitComment('goto');

  Inc(EP);  { consommer GOTO }

  If Not EPAtEnd Then
  Begin
    { Le label peut etre un nombre ou un identificateur }
    LblName := TokenPool[EP].Val;
    Inc(EP);
    EmitInstr('JMP ' + TP_LBL_PFX + StrUpperCase(LblName));
  End;

  { Consommer ; optionnel }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseStmt : parser UNE instruction Pascal.                    }
{ Gere : bloc BEGIN..END, IF, WHILE, REPEAT, FOR, CASE,       }
{ affectation, appel, Write/Read, Exit, Halt, Break, Continue, }
{ GOTO, WITH, labels numeriques.                                }
{ ------------------------------------------------------------ }

Procedure ParseStmt(PI : Integer);
Var
  Up    : TString;
  VName : TString;
  Lbl   : TString;
  SI    : Integer;
  LI    : Integer;
  TIdx    : Integer;
  FOfs    : Integer;
  FSize   : Integer;
  ElemSz  : Integer;
  WI      : Integer;
Begin
  If EPAtEnd Then Exit;

  { Point-virgule seul : instruction vide }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
  Begin
    Inc(EP);
    Exit;
  End;

  { Point final : fin du programme }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
  Begin
    Inc(EP);
    Exit;
  End;

  { Mots-cles }
  If TokenPool[EP].Kind = TK_KEYWORD Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END : ne pas consommer, laisser l appelant gerer }
    If Up = 'END' Then Exit;

    { UNTIL : ne pas consommer, laisser ParseRepeatStmt gerer }
    If Up = 'UNTIL' Then Exit;

    { ELSE : ne pas consommer, laisser ParseIfStmt gerer }
    If Up = 'ELSE' Then Exit;

    { BEGIN : bloc imbrique }
    If Up = 'BEGIN' Then
    Begin
      Inc(EP);  { consommer BEGIN }
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[EP].Val) = 'END') Then
        Begin
          Inc(EP);  { consommer END }
          { Consommer ; ou . optionnel apres END }
          If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
             ((TokenPool[EP].Val = ';') Or (TokenPool[EP].Val = '.')) Then
            Inc(EP);
          Break;
        End;
        SI := EP;  { sauvegarder position avant ParseStmt }
        ParseStmt(PI);
        { Consommer ; optionnel entre instructions }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        { Securite : si EP n a pas avance, forcer l avancement }
        If EP = SI Then
          Inc(EP);
      End;
      Exit;
    End;

    { IF }
    If Up = 'IF' Then Begin ParseIfStmt(PI); Exit; End;

    { WHILE }
    If Up = 'WHILE' Then Begin ParseWhileStmt(PI); Exit; End;

    { REPEAT }
    If Up = 'REPEAT' Then Begin ParseRepeatStmt(PI); Exit; End;

    { FOR }
    If Up = 'FOR' Then Begin ParseForStmt(PI); Exit; End;

    { CASE }
    If Up = 'CASE' Then Begin ParseCaseStmt(PI); Exit; End;

    { GOTO }
    If Up = 'GOTO' Then Begin ParseGotoStmt(PI); Exit; End;

    { WITH : resoudre les noms de champs implicitement }
    If Up = 'WITH' Then
    Begin
      EmitComment('with');
      Inc(EP);
      { Lire le nom de la variable record }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        VName := StrUpperCase(TokenPool[EP].Val);
        Inc(EP);
        { Empiler le contexte WITH }
        If WithDepth < 8 Then
        Begin
          WithVarName[WithDepth] := VName;
          WithVarPI[WithDepth]   := PI;
          WithTypeIdx[WithDepth] := GetVarTypeIdx(PI, VName);
          Inc(WithDepth);
        End;
        { Attendre DO }
        While Not EPAtEnd Do
        Begin
          If (TokenPool[EP].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
          Begin
            Inc(EP);
            Break;
          End;
          Inc(EP);
        End;
        ParseStmt(PI);
        { Depiler le contexte WITH }
        If WithDepth > 0 Then
          Dec(WithDepth);
      End
      Else
      Begin
        { Pas de variable, avancer jusqu a DO }
        While Not EPAtEnd Do
        Begin
          If (TokenPool[EP].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
          Begin
            Inc(EP);
            Break;
          End;
          Inc(EP);
        End;
        ParseStmt(PI);
      End;
      Exit;
    End;

    { EXIT : saut au label de retour }
    If Up = 'EXIT' Then
    Begin
      Inc(EP);
      EmitInstr('JMP ' + RetLbl);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { HALT : appel ExitProcess }
    If Up = 'HALT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End
      Else
        EmitInstr('XOR EAX,EAX');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { RUNERROR(N) : appel ExitProcess avec code d erreur }
    If Up = 'RUNERROR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End
      Else
        EmitInstr('MOV EAX,0');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { BREAK : saut vers fin de boucle englobante }
    If Up = 'BREAK' Then
    Begin
      Inc(EP);
      If LoopTop >= 0 Then
        EmitInstr('JMP ' + LoopBreakLbl[LoopTop])
      Else
        WarnMsg('break en dehors d une boucle');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { CONTINUE : saut vers test/increment de boucle englobante }
    If Up = 'CONTINUE' Then
    Begin
      Inc(EP);
      If LoopTop >= 0 Then
        EmitInstr('JMP ' + LoopContLbl[LoopTop])
      Else
        WarnMsg('continue en dehors d une boucle');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ASM : bloc assembleur inline (TODO 17) }
    If Up = 'ASM' Then
    Begin
      ParseAsmBlock(PI);
      Exit;
    End;

    { LABEL : section de labels, sauter la declaration }
    If Up = 'LABEL' Then
    Begin
      Inc(EP);
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
        Begin
          Inc(EP);
          Break;
        End;
        Inc(EP);
      End;
      Exit;
    End;

    { VAR, CONST, TYPE locaux : avancer sans gerer pour l instant }
    If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Then
    Begin
      Inc(EP);
      Exit;
    End;

    { INC/DEC/NEW/DISPOSE/GETMEM/FREEMEM/MOVE/FILLCHAR/MARK/RELEASE/SETTEXTBUF/CHDIR/MKDIR/RMDIR/GETDIR/INCLUDE/EXCLUDE comme keywords }
    If (Up = 'INC') Or (Up = 'DEC') Or (Up = 'NEW') Or
       (Up = 'DISPOSE') Or (Up = 'GETMEM') Or (Up = 'FREEMEM') Or
       (Up = 'MOVE') Or (Up = 'FILLCHAR') Or (Up = 'MARK') Or
       (Up = 'RELEASE') Or (Up = 'SETTEXTBUF') Or
       (Up = 'CHDIR') Or (Up = 'MKDIR') Or (Up = 'RMDIR') Or
       (Up = 'GETDIR') Or (Up = 'INCLUDE') Or (Up = 'EXCLUDE') Then
    Begin
      ParseExpr(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Autres mots-cles : avancer }
    Inc(EP);
    Exit;
  End;

  { Entier suivi de ':' = label numerique }
  If (TokenPool[EP].Kind = TK_INTEGER) Then
  Begin
    If (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = ':') Then
    Begin
      EmitLabel(TP_LBL_PFX + TokenPool[EP].Val);
      Inc(EP, 2);  { consommer nombre et ':' }
      Exit;
    End;
  End;

  { Identificateur }
  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    VName := TokenPool[EP].Val;
    Up := StrUpperCase(VName);

    { Label identificateur : ident suivi de ':' (pas ':=') }
    If (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = ':') And
       Not ((EP + 2 < EPEnd) And (TokenPool[EP + 2].Val = '=')) Then
    Begin
      EmitLabel(TP_LBL_PFX + Up);
      Inc(EP, 2);  { consommer ident et ':' }
      Exit;
    End;

    { INC/DEC/NEW/DISPOSE/GETMEM/FREEMEM/MOVE/FILLCHAR/MARK/RELEASE/SETTEXTBUF/CHDIR/MKDIR/RMDIR/GETDIR/INCLUDE/EXCLUDE }
    If (Up = 'INC') Or (Up = 'DEC') Or (Up = 'NEW') Or
       (Up = 'DISPOSE') Or (Up = 'GETMEM') Or (Up = 'FREEMEM') Or
       (Up = 'MOVE') Or (Up = 'FILLCHAR') Or (Up = 'MARK') Or
       (Up = 'RELEASE') Or (Up = 'SETTEXTBUF') Or
       (Up = 'CHDIR') Or (Up = 'MKDIR') Or (Up = 'RMDIR') Or
       (Up = 'GETDIR') Or (Up = 'INCLUDE') Or (Up = 'EXCLUDE') Then
    Begin
      ParseExpr(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { HALT : appel ExitProcess (identifiant, pas mot-cle) }
    If Up = 'HALT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End
      Else
        EmitInstr('XOR EAX,EAX');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { RUNERROR(N) : appel ExitProcess avec code d erreur (identifiant) }
    If Up = 'RUNERROR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End
      Else
        EmitInstr('MOV EAX,0');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { EXIT : saut au label de retour (identifiant) }
    If Up = 'EXIT' Then
    Begin
      Inc(EP);
      EmitInstr('JMP ' + RetLbl);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { RANDOMIZE : initialiser la graine aleatoire }
    If Up = 'RANDOMIZE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'RANDOMIZE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE SETEXCEPTION(e, b) / SETHALT(e, b) : no-op stubs (2 args) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'SETEXCEPTION') Or (Up = 'SETHALT') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SANE ' + Up + ' stub : no-op');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE no-op stubs (1 arg, discarded) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'SETROUND') Or (Up = 'SETPRECISION') Or
       (Up = 'SETENVIRONMENT') Or (Up = 'PROCEXIT') Or
       (Up = 'SETHALTVECTOR') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SANE ' + Up + ' stub : no-op');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE GETENVIRONMENT(Var e) / PROCENTRY(Var e) : store 0 --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'GETENVIRONMENT') Or (Up = 'PROCENTRY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          EmitInstr('MOV DWORD PTR [EAX],0');
          Inc(EP);
        End;
        EPMatch(')');
      End;
      EmitComment('SANE ' + Up + ' stub : store 0');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE NUM2STR(f, x, Var s) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If Up = 'NUM2STR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        If Not EPAtEnd Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          EmitInstr('PUSH EAX');
          Inc(EP);
        End;
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SANE_NUM2STR');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE STR2DEC / CSTR2DEC (4 args, no-op) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'STR2DEC') Or (Up = 'CSTR2DEC') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SANE ' + Up + ' stub : no-op');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { --- SANE NUM2DEC / DEC2STR (3 args, no-op) --- }
    If Opts.ApplePascal Or Opts.Sane Then
    If (Up = 'NUM2DEC') Or (Up = 'DEC2STR') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SANE ' + Up + ' stub : no-op');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Write / WriteLn }
    If (Up = 'WRITE') Or (Up = 'WRITELN') Then
    Begin
      Inc(EP);
      ParseWriteStmt(PI, Up = 'WRITELN');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Read / ReadLn }
    If (Up = 'READ') Or (Up = 'READLN') Then
    Begin
      Inc(EP);
      ParseReadStmt(PI, Up = 'READLN');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Str }
    If Up = 'STR' Then
    Begin
      Inc(EP);
      ParseStrStmt(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Val }
    If Up = 'VAL' Then
    Begin
      Inc(EP);
      ParseValStmt(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { DELETE(S, Pos, Len) }
    If Up = 'DELETE' Then
    Begin
      Inc(EP);
      EmitComment('delete');
      If EPMatch('(') Then
      Begin
        { S -> adresse du buffer }
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
          EmitInstr('PUSH EAX');
        End;
        EPMatch(',');
        { Pos }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Len }
        ParseExpr(PI);
        EmitInstr('MOV ECX,EAX');
        EmitInstr('POP EBX');      { Pos }
        EmitInstr('POP ESI');      { S   }
        EmitInstr('CALL ' + TP_RT_PFX + 'DELETE');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { INSERT(Src, Dst, Pos) }
    If Up = 'INSERT' Then
    Begin
      Inc(EP);
      EmitComment('insert');
      If EPMatch('(') Then
      Begin
        { Src }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Dst -> adresse du buffer }
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
          EmitInstr('PUSH EAX');
        End;
        EPMatch(',');
        { Pos }
        ParseExpr(PI);
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EDI');      { Dst }
        EmitInstr('POP ESI');      { Src }
        EmitInstr('CALL ' + TP_RT_PFX + 'INSERT');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ---- TODO 18 : Procedures CRT comme identifiants ---- }

    { CLRSCR }
    If Up = 'CLRSCR' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'CLRSCR');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { CLREOL }
    If Up = 'CLREOL' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'CLREOL');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { GOTOXY(X, Y) }
    If Up = 'GOTOXY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'GOTOXY');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { TEXTCOLOR(C) }
    If Up = 'TEXTCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'TEXTCOLOR');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { TEXTBACKGROUND(C) }
    If Up = 'TEXTBACKGROUND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'TEXTBG');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { HIGHVIDEO }
    If Up = 'HIGHVIDEO' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'HIGHVIDEO');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { LOWVIDEO }
    If Up = 'LOWVIDEO' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'LOWVIDEO');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { NORMVIDEO }
    If Up = 'NORMVIDEO' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'NORMVIDEO');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { WINDOW(X1, Y1, X2, Y2) }
    If Up = 'WINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'WINDOW');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { DELAY(ms) }
    If Up = 'DELAY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL Sleep');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SOUND(Hz) }
    If Up = 'SOUND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'SOUND');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { NOSOUND }
    If Up = 'NOSOUND' Then
    Begin
      Inc(EP);
      EmitComment('NoSound (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ASSIGNCRT }
    If Up = 'ASSIGNCRT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('AssignCrt (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { INSLINE }
    If Up = 'INSLINE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'INSLINE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { DELLINE }
    If Up = 'DELLINE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'DELLINE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { TEXTMODE(Mode) }
    If Up = 'TEXTMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'TEXTMODE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { READKEY (utilise comme instruction - resultat ignore) }
    If Up = 'READKEY' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'READKEY');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { KEYPRESSED (utilise comme instruction - resultat ignore) }
    If Up = 'KEYPRESSED' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'KEYPRESSED');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ---- TODO 19 : Procedures DOS comme identifiants ---- }

    { GETDATE(Year, Month, Day, DayOfWeek) }
    If Up = 'GETDATE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { Appeler GetLocalTime d abord }
        EmitInstr('PUSH OFFSET DOS_SYSTIME');
        EmitInstr('CALL GetLocalTime');
        { Year }
        ParseExpr(PI);         { adresse var Year }
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+0]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { Month }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+2]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { Day }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+6]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { DayOfWeek }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+4]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { GETTIME(Hour, Minute, Second, Sec100) }
    If Up = 'GETTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        EmitInstr('PUSH OFFSET DOS_SYSTIME');
        EmitInstr('CALL GetLocalTime');
        { Hour }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+8]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { Minute }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+10]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { Second }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+12]');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(',');
        { Sec100 (milliseconds / 10) }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+14]');
        EmitInstr('XOR EDX,EDX');
        EmitInstr('MOV ECX,10');
        EmitInstr('DIV ECX');
        EmitInstr('POP EDX');
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SETDATE(Year, Month, Day) }
    If Up = 'SETDATE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+0],AX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+2],AX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+6],AX');
        EPMatch(')');
      End;
      EmitInstr('PUSH OFFSET DOS_SYSTIME');
      EmitInstr('CALL SetLocalTime');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SETTIME(Hour, Minute, Second, Sec100) }
    If Up = 'SETTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+8],AX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+10],AX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+12],AX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('IMUL EAX,10');
        EmitInstr('MOV WORD PTR [DOS_SYSTIME+14],AX');
        EPMatch(')');
      End;
      EmitInstr('PUSH OFFSET DOS_SYSTIME');
      EmitInstr('CALL SetLocalTime');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { GETFATTR(F, Attr) }
    If Up = 'GETFATTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);            { F = nom fichier (pointeur chaine) }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);            { Attr = var Word }
        EmitInstr('PUSH EAX');    { sauver adresse var Attr }
        { Appeler GetFileAttributesA(nom) }
        EmitInstr('MOV EAX,DWORD PTR [ESP+4]');
        EmitInstr('INC EAX');     { sauter octet longueur Pascal string }
        EmitInstr('PUSH EAX');
        EmitInstr('CALL GetFileAttributesA');
        EmitInstr('POP EDX');     { adresse var Attr }
        EmitInstr('MOV DWORD PTR [EDX],EAX');
        EmitInstr('ADD ESP,4');   { nettoyer F }
        { DosError = 0 si OK, sinon code erreur }
        EmitInstr('CMP EAX,-1');
        EmitInstr('JNE ' + TP_RT_PFX + 'GFA_OK');
        EmitInstr('MOV DWORD PTR [DOSERROR],5');
        EmitInstr('JMP ' + TP_RT_PFX + 'GFA_DN');
        EmitLabel(TP_RT_PFX + 'GFA_OK');
        EmitInstr('MOV DWORD PTR [DOSERROR],0');
        EmitLabel(TP_RT_PFX + 'GFA_DN');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SETFATTR(F, Attr) }
    If Up = 'SETFATTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);            { F = nom fichier }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);            { Attr = Word }
        EmitInstr('PUSH EAX');
        { SetFileAttributesA(nom, attr) }
        EmitInstr('MOV EDX,DWORD PTR [ESP+4]');
        EmitInstr('INC EDX');
        EmitInstr('PUSH DWORD PTR [ESP]');  { attr }
        EmitInstr('PUSH EDX');              { nom }
        EmitInstr('CALL SetFileAttributesA');
        EmitInstr('ADD ESP,8');
        EmitInstr('MOV DWORD PTR [DOSERROR],0');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ASSIGN(f, filename) : associer variable fichier et nom }
    If Up = 'ASSIGN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : variable fichier Text, charger son adresse }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);            { filename }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'ASSIGN');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { RESET(f) : ouvrir fichier en lecture }
    If Up = 'RESET' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('PUSH EAX');
        { Ignorer le parametre optionnel de taille de bloc }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          ParseExpr(PI);  { consommer le parametre }
        End;
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'RESET');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { REWRITE(f) : ouvrir fichier en ecriture }
    If Up = 'REWRITE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('PUSH EAX');
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          ParseExpr(PI);
        End;
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'REWRITE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { CLOSE(f) : fermer fichier }
    If Up = 'CLOSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'CLOSE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { APPEND(f) : ouvrir fichier texte en ajout }
    If Up = 'APPEND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'APPEND');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ERASE(f) : supprimer fichier }
    If Up = 'ERASE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EPMatch(')');
      End;
      EmitInstr('PUSH OFFSET FILE_NAMEBUF');
      EmitInstr('CALL DeleteFileA');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { RENAME(f, newname) : renommer fichier }
    If Up = 'RENAME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : variable fichier - ignoree, FILE_NAMEBUF contient le nom depuis Assign }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
          Inc(EP);
        EPMatch(',');
        { newname : expression chaine }
        ParseExpr(PI);
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EmitInstr('PUSH EAX');    { save new name ptr }
        EPMatch(')');
      End;
      { Copier le nouveau nom dans FILE_RENBUF }
      EmitInstr('POP ESI');                  { source = new name ASCIIZ }
      EmitInstr('LEA EDI,[FILE_RENBUF]');
      EmitInstr('MOV ECX,259');
      EmitLabel(TP_RT_PFX + 'REN_CP');
      EmitInstr('LODSB');
      EmitInstr('STOSB');
      EmitInstr('TEST AL,AL');
      EmitInstr('JZ ' + TP_RT_PFX + 'REN_GO');
      EmitInstr('DEC ECX');
      EmitInstr('JNZ ' + TP_RT_PFX + 'REN_CP');
      EmitLabel(TP_RT_PFX + 'REN_GO');
      { MoveFileA(FILE_NAMEBUF, FILE_RENBUF) }
      EmitInstr('PUSH OFFSET FILE_RENBUF');
      EmitInstr('PUSH OFFSET FILE_NAMEBUF');
      EmitInstr('CALL MoveFileA');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SEEK(f, pos) : positionner dans un fichier binaire }
    If Up = 'SEEK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : variable fichier }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');  { handle fichier }
        EmitInstr('PUSH EAX');                  { save handle }
        EPMatch(',');
        { pos : expression entiere }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');                  { save position }
        EPMatch(')');
      End;
      { SetFilePointer(handle, pos, NULL, FILE_BEGIN=0) }
      EmitInstr('POP ECX');           { position }
      EmitInstr('POP EBX');           { handle   }
      EmitInstr('PUSH 0');            { dwMoveMethod = FILE_BEGIN }
      EmitInstr('PUSH 0');            { lpDistanceToMoveHigh     }
      EmitInstr('PUSH ECX');          { lDistanceToMove          }
      EmitInstr('PUSH EBX');          { hFile                    }
      EmitInstr('CALL SetFilePointer');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { TRUNCATE(f) : tronquer un fichier a la position courante }
    If Up = 'TRUNCATE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');  { handle fichier }
        EPMatch(')');
      End;
      { SetEndOfFile(handle) }
      EmitInstr('PUSH EAX');          { hFile }
      EmitInstr('CALL SetEndOfFile');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { FLUSH(f) : vider les tampons d un fichier }
    If Up = 'FLUSH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : variable fichier }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');  { handle fichier }
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL FlushFileBuffers');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { BLOCKWRITE(f, buf, count [, result]) }
    If Up = 'BLOCKWRITE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : file variable }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');
        EmitInstr('MOV DWORD PTR [FILE_WRHND],EAX');
        EPMatch(',');
        { buf : buffer address }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');        { save buf addr }
        EPMatch(',');
        { count }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');        { save count }
        { optional result var }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          { result var - skip for now, use BYTESWR }
          If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
            Inc(EP);
        End;
        EPMatch(')');
      End;
      { WriteFile(FILE_WRHND, buf, count, &BYTESWR, 0) }
      EmitInstr('POP ECX');           { count }
      EmitInstr('POP ESI');           { buf addr }
      EmitInstr('PUSH 0');
      EmitInstr('PUSH OFFSET BYTESWR');
      EmitInstr('PUSH ECX');
      EmitInstr('PUSH ESI');
      EmitInstr('PUSH DWORD PTR [FILE_WRHND]');
      EmitInstr('CALL WriteFile');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { BLOCKREAD(f, buf, count [, result]) }
    If Up = 'BLOCKREAD' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { f : file variable }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          GenLoadAddr(PI, TokenPool[EP].Val);
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [EAX]');
        EmitInstr('PUSH EAX');        { save handle }
        EPMatch(',');
        { buf : buffer address }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');        { save buf addr }
        EPMatch(',');
        { count }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');        { save count }
        { optional result var }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
            Inc(EP);
        End;
        EPMatch(')');
      End;
      { ReadFile(handle, buf, count, &FILE_BYTESRD, 0) }
      EmitInstr('POP ECX');           { count }
      EmitInstr('POP ESI');           { buf addr }
      EmitInstr('POP EBX');           { handle }
      EmitInstr('PUSH 0');
      EmitInstr('PUSH OFFSET FILE_BYTESRD');
      EmitInstr('PUSH ECX');
      EmitInstr('PUSH ESI');
      EmitInstr('PUSH EBX');
      EmitInstr('CALL ReadFile');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;
    If Up = 'FINDFIRST' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);            { Path }
        If LastExprIsPascalStr Then
          EmitInstr('INC EAX');   { Pascal -> ASCIIZ }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);            { Attr (ignored for Win32, kept for compat) }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);            { SearchRec var address }
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FINDFIRST');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { FINDNEXT(SearchRec) }
    If Up = 'FINDNEXT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);            { SearchRec var address }
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FINDNEXT');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { FINDCLOSE(SearchRec) }
    If Up = 'FINDCLOSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('FindClose (stub - Win32 handles auto)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { FSPLIT(Path, Dir, Name, Ext) }
    If Up = 'FSPLIT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FSPLIT');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { EXEC(Path, CmdLine) }
    If Up = 'EXEC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'EXEC');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SWAPVECTORS }
    If Up = 'SWAPVECTORS' Then
    Begin
      Inc(EP);
      EmitComment('SwapVectors (stub - non applicable Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { GETINTVEC }
    If Up = 'GETINTVEC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('GetIntVec (stub - non applicable Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { SETINTVEC }
    If Up = 'SETINTVEC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SetIntVec (stub - non applicable Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { MSDOS(Regs) }
    If Up = 'MSDOS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('MsDos(Regs) - INT 21h emulation stub');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'MSDOS');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { INTR(IntNo, Regs) - emulation interruptions (TODO 23) }
    If Up = 'INTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitComment('Intr(IntNo, Regs) - emulation interruptions');
      EmitInstr('CALL ' + TP_RT_PFX + 'INTR');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { GETCBREAK(Var Break : Boolean) }
    If Up = 'GETCBREAK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      { Toujours retourner False (Win32 n a pas de Ctrl-Break DOS) }
      EmitInstr('MOV DWORD PTR [EAX],0');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETCBREAK(Break : Boolean) }
    If Up = 'SETCBREAK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      { Stub sous Win32 }
      EmitComment('SetCBreak - stub Win32');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETVERIFY(Var Verify : Boolean) }
    If Up = 'GETVERIFY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      { Toujours retourner False (Win32 n a pas de verify DOS) }
      EmitInstr('MOV DWORD PTR [EAX],0');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETVERIFY(Verify : Boolean) }
    If Up = 'SETVERIFY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      { Stub sous Win32 }
      EmitComment('SetVerify - stub Win32');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETFTIME(Var F; Var Time : LongInt) }
    If Up = 'GETFTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);              { file var -> addr in EAX }
        EmitInstr('PUSH EAX');      { save file addr }
        EPMatch(',');
        ParseExpr(PI);              { var Time -> addr in EAX }
        EmitInstr('PUSH EAX');      { push Time addr }
      End;
      EPMatch(')');
      EmitInstr('CALL ' + TP_RT_PFX + 'GETFTIME');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETFTIME(Var F; Time : LongInt) }
    If Up = 'SETFTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);              { file var -> addr in EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);              { Time value in EAX }
        EmitInstr('PUSH EAX');
      End;
      EPMatch(')');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETFTIME');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { UNPACKTIME(P : LongInt; Var T : DateTime) }
    If Up = 'UNPACKTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);              { packed time value in EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);              { var T -> addr in EAX }
        EmitInstr('PUSH EAX');
      End;
      EPMatch(')');
      EmitInstr('CALL ' + TP_RT_PFX + 'UNPACKTIME');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PACKTIME(Var T : DateTime; Var P : LongInt) }
    If Up = 'PACKTIME' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);              { var T -> addr in EAX }
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);              { var P -> addr in EAX }
        EmitInstr('PUSH EAX');
      End;
      EPMatch(')');
      EmitInstr('CALL ' + TP_RT_PFX + 'PACKTIME');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { KEEP(ExitCode : Word) }
    If Up = 'KEEP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      { Sous Win32, Keep = ExitProcess }
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 20 : Procedures Graph comme identifiants ---- }

    { INITGRAPH(Gd, Gm, Path) }
    If Up = 'INITGRAPH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Gd (var) }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Gm (var) }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Path }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'INITGRAPH');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { CLOSEGRAPH }
    If Up = 'CLOSEGRAPH' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'CLOSEGRAPH');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { DETECTGRAPH(Gd, Gm) }
    If Up = 'DETECTGRAPH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitComment('DetectGraph -> VGA/VGAHi');
      EmitInstr('POP EDX');   { Gm var }
      EmitInstr('MOV DWORD PTR [EDX],2');  { VGAHi = 2 }
      EmitInstr('POP EDX');   { Gd var }
      EmitInstr('MOV DWORD PTR [EDX],9');  { VGA = 9 }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PUTPIXEL(X, Y, Color) }
    If Up = 'PUTPIXEL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { X }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Y }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Color }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'PUTPIXEL');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { LINE(X1, Y1, X2, Y2) }
    If Up = 'LINE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'LINE');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { LINETO(X, Y) }
    If Up = 'LINETO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'LINETO');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { LINEREL(Dx, Dy) }
    If Up = 'LINEREL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'LINEREL');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { MOVETO(X, Y) }
    If Up = 'MOVETO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('POP ECX');  { Y }
      EmitInstr('MOV DWORD PTR [GR_CPY],ECX');
      EmitInstr('POP ECX');  { X }
      EmitInstr('MOV DWORD PTR [GR_CPX],ECX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { MOVEREL(Dx, Dy) }
    If Up = 'MOVEREL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('POP ECX');  { Dy }
      EmitInstr('MOV EAX,DWORD PTR [GR_CPY]');
      EmitInstr('ADD EAX,ECX');
      EmitInstr('MOV DWORD PTR [GR_CPY],EAX');
      EmitInstr('POP ECX');  { Dx }
      EmitInstr('MOV EAX,DWORD PTR [GR_CPX]');
      EmitInstr('ADD EAX,ECX');
      EmitInstr('MOV DWORD PTR [GR_CPX],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { RECTANGLE(X1, Y1, X2, Y2) }
    If Up = 'RECTANGLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'RECTANGLE');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { BAR(X1, Y1, X2, Y2) }
    If Up = 'BAR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'BAR');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { BAR3D(X1, Y1, X2, Y2, Depth, Top) }
    If Up = 'BAR3D' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'BAR3D');
      EmitInstr('ADD ESP,24');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { CIRCLE(X, Y, Radius) }
    If Up = 'CIRCLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'CIRCLE');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ARC(X, Y, StAngle, EndAngle, Radius) }
    If Up = 'ARC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'ARC');
      EmitInstr('ADD ESP,20');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ELLIPSE(X, Y, StAngle, EndAngle, XRadius, YRadius) }
    If Up = 'ELLIPSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'ELLIPSE');
      EmitInstr('ADD ESP,24');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { FILLELLIPSE(X, Y, XRadius, YRadius) }
    If Up = 'FILLELLIPSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FILLELLIPSE');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PIESLICE(X, Y, StAngle, EndAngle, Radius) }
    If Up = 'PIESLICE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'PIESLICE');
      EmitInstr('ADD ESP,20');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SECTOR(X, Y, StAngle, EndAngle, XRadius, YRadius) }
    If Up = 'SECTOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'SECTOR');
      EmitInstr('ADD ESP,24');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { FLOODFILL(X, Y, Border) }
    If Up = 'FLOODFILL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FLOODFILL');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETCOLOR(Color) }
    If Up = 'SETCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETCOLOR');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETBKCOLOR(Color) }
    If Up = 'SETBKCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [GR_BKCOLOR],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETFILLSTYLE(Pattern, Color) }
    If Up = 'SETFILLSTYLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('POP EAX');  { Color }
      EmitInstr('MOV DWORD PTR [GR_FILLCOLOR],EAX');
      EmitInstr('POP EAX');  { Pattern }
      EmitInstr('MOV DWORD PTR [GR_FILLSTYLE],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETLINESTYLE(LineStyle, Pattern, Thickness) }
    If Up = 'SETLINESTYLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  { Pattern - ignore }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('POP EAX');  { Thickness }
      EmitInstr('MOV DWORD PTR [GR_LINEWIDTH],EAX');
      EmitInstr('POP EAX');  { LineStyle }
      EmitInstr('MOV DWORD PTR [GR_LINESTYLE],EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'UPDATEPEN');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OUTTEXTXY(X, Y, Text) }
    If Up = 'OUTTEXTXY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'OUTTEXTXY');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OUTTEXT(Text) }
    If Up = 'OUTTEXT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('PUSH DWORD PTR [GR_CPY]');
      EmitInstr('PUSH DWORD PTR [GR_CPX]');
      { Utiliser OutTextXY avec CPX, CPY }
      { On empile Text, Y, X -> la routine attend X, Y, Text }
      EmitComment('OutText via OutTextXY(CPX, CPY, Text)');
      EmitInstr('CALL ' + TP_RT_PFX + 'OUTTEXTXY');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETTEXTSTYLE(Font, Direction, CharSize) }
    If Up = 'SETTEXTSTYLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('POP EAX');   { CharSize }
      EmitInstr('MOV DWORD PTR [GR_TXSIZE],EAX');
      EmitInstr('POP EAX');   { Direction }
      EmitInstr('MOV DWORD PTR [GR_TXDIR],EAX');
      EmitInstr('POP EAX');   { Font }
      EmitInstr('MOV DWORD PTR [GR_TXFONT],EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'UPDATEFONT');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETVIEWPORT(X1, Y1, X2, Y2, Clip) }
    If Up = 'SETVIEWPORT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPXL],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPYT],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPXR],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPYB],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPCLIP],EAX');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { CLEARDEVICE }
    If Up = 'CLEARDEVICE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'CLEARDEVICE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETACTIVEPAGE(Page) / SETVISUALPAGE(Page) }
    If (Up = 'SETACTIVEPAGE') Or (Up = 'SETVISUALPAGE') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub - page unique en Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETPALETTE(Index, Color) }
    If Up = 'SETPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      { GR_PALETTE[Index] := PaletteColor }
      EmitInstr('POP ECX');   { Color value }
      EmitInstr('POP EAX');   { Index }
      EmitInstr('AND EAX,0Fh');
      EmitInstr('MOV DWORD PTR [GR_PALETTE+EAX*4],ECX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETRGBPALETTE(Index, R, G, B) }
    If Up = 'SETRGBPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Index }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { R }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { G }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { B }
        EPMatch(')');
      End;
      { Construire COLORREF = B*65536 + G*256 + R }
      EmitInstr('POP ECX');   { B }
      EmitInstr('SHL ECX,16');
      EmitInstr('POP EAX');   { G }
      EmitInstr('SHL EAX,8');
      EmitInstr('OR ECX,EAX');
      EmitInstr('POP EAX');   { R }
      EmitInstr('OR ECX,EAX');
      EmitInstr('POP EAX');   { Index }
      EmitInstr('AND EAX,0Fh');
      EmitInstr('MOV DWORD PTR [GR_PALETTE+EAX*4],ECX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETASPECTRATIO(Xasp, Yasp) }
    If Up = 'SETASPECTRATIO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SetAspectRatio (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETWRITEMODE(Mode) }
    If Up = 'SETWRITEMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [GR_WRITEMODE],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETIMAGE(X1, Y1, X2, Y2, Bitmap) }
    If Up = 'GETIMAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitComment('GetImage (stub - bitmap non implemente)');
      EmitInstr('ADD ESP,20');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PUTIMAGE(X, Y, Bitmap, Op) }
    If Up = 'PUTIMAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitComment('PutImage (stub - bitmap non implemente)');
      EmitInstr('ADD ESP,16');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { RESTORECRTMODE - restaure le mode texte }
    If Up = 'RESTORECRTMODE' Then
    Begin
      Inc(EP);
      EmitComment('RestoreCrtMode (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETGRAPHMODE(Mode) }
    If Up = 'SETGRAPHMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [GR_MODE],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GRAPHDEFAULTS - reinitialise toutes les valeurs par defaut }
    If Up = 'GRAPHDEFAULTS' Then
    Begin
      Inc(EP);
      EmitInstr('MOV DWORD PTR [GR_CPX],0');
      EmitInstr('MOV DWORD PTR [GR_CPY],0');
      EmitInstr('MOV DWORD PTR [GR_COLOR],15');
      EmitInstr('MOV DWORD PTR [GR_BKCOLOR],0');
      EmitInstr('MOV DWORD PTR [GR_FILLSTYLE],1');
      EmitInstr('MOV DWORD PTR [GR_FILLCOLOR],0');
      EmitInstr('MOV DWORD PTR [GR_LINESTYLE],0');
      EmitInstr('MOV DWORD PTR [GR_LINEWIDTH],1');
      EmitInstr('MOV DWORD PTR [GR_WRITEMODE],0');
      EmitInstr('MOV DWORD PTR [GR_VPXL],0');
      EmitInstr('MOV DWORD PTR [GR_VPYT],0');
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXX]');
      EmitInstr('MOV DWORD PTR [GR_VPXR],EAX');
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXY]');
      EmitInstr('MOV DWORD PTR [GR_VPYB],EAX');
      EmitInstr('MOV DWORD PTR [GR_VPCLIP],1');
      EmitInstr('MOV DWORD PTR [GR_TXFONT],0');
      EmitInstr('MOV DWORD PTR [GR_TXDIR],0');
      EmitInstr('MOV DWORD PTR [GR_TXSIZE],1');
      EmitInstr('MOV DWORD PTR [GR_TXJUST_H],0');
      EmitInstr('MOV DWORD PTR [GR_TXJUST_V],2');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETGRAPHBUFSIZE(BufSize) - stub }
    If Up = 'SETGRAPHBUFSIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('SetGraphBufSize (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETMODERANGE(GraphDriver, LoMode, HiMode) }
    If Up = 'GETMODERANGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  { GraphDriver - ignored }
        EPMatch(',');
        ParseExpr(PI);  { LoMode var addr }
        EmitInstr('MOV DWORD PTR [EAX],0');
        EPMatch(',');
        ParseExpr(PI);  { HiMode var addr }
        EmitInstr('MOV DWORD PTR [EAX],2');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { DRAWPOLY(NumPoints, PolyPoints) }
    { NumPoints = nombre de points, PolyPoints = pointeur vers tableau de PointType }
    { PointType = record X,Y:Integer (4+4=8 bytes) = POINT Win32 (X:LONG,Y:LONG) }
    If Up = 'DRAWPOLY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { NumPoints }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { PolyPoints (adresse) }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'DRAWPOLY');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { FILLPOLY(NumPoints, PolyPoints) }
    If Up = 'FILLPOLY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { NumPoints }
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { PolyPoints (adresse) }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'FILLPOLY');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETFILLPATTERN(Pattern, Color) }
    If Up = 'SETFILLPATTERN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  { Pattern - array, ignore }
        EPMatch(',');
        ParseExpr(PI);  { Color }
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [GR_FILLCOLOR],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETALLPALETTE(Palette) - stub }
    If Up = 'SETALLPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('SetAllPalette (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETPALETTE(Palette) - stub fills with default values }
    If Up = 'GETPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetPalette (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETDEFAULTPALETTE(Palette) - stub }
    If Up = 'GETDEFAULTPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetDefaultPalette (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETTEXTJUSTIFY(Horiz, Vert) }
    If Up = 'SETTEXTJUSTIFY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV DWORD PTR [GR_TXJUST_H],EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV DWORD PTR [GR_TXJUST_V],EAX');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { SETUSERCHARSIZE(MultX, DivX, MultY, DivY) - stub }
    If Up = 'SETUSERCHARSIZE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('SetUserCharSize (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETTEXTSETTINGS(TextInfo) - stub }
    If Up = 'GETTEXTSETTINGS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetTextSettings (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETLINESETTINGS(LineInfo) - stub }
    If Up = 'GETLINESETTINGS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetLineSettings (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETFILLSETTINGS(FillInfo) - stub }
    If Up = 'GETFILLSETTINGS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetFillSettings (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETFILLPATTERN(FillPattern) - stub }
    If Up = 'GETFILLPATTERN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetFillPattern (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETVIEWSETTINGS(ViewPort) - stub }
    If Up = 'GETVIEWSETTINGS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetViewSettings (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETARCCOORDS(ArcCoords) - stub }
    If Up = 'GETARCCOORDS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('GetArcCoords (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GETASPECTRATIO(Xasp, Yasp) }
    If Up = 'GETASPECTRATIO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  { Xasp var addr }
        EmitInstr('MOV DWORD PTR [EAX],10000');
        EPMatch(',');
        ParseExpr(PI);  { Yasp var addr }
        EmitInstr('MOV DWORD PTR [EAX],10000');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { CLEARVIEWPORT }
    If Up = 'CLEARVIEWPORT' Then
    Begin
      Inc(EP);
      EmitComment('ClearViewPort (stub - same as ClearDevice for now)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- MSGraph procedures (QuickPascal mode) ---- }

    { _SETVIDEOMODE(mode) utilise comme instruction - resultat ignore }
    If Up = '_SETVIDEOMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End
      Else EmitInstr('XOR EAX,EAX');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETVIDEOMODE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETVIDEOMODEROWS(mode, rows) utilise comme instruction }
    If Up = '_SETVIDEOMODEROWS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  { rows ignore }
        EPMatch(')');
      End
      Else EmitInstr('PUSH 0');
      EmitInstr('CALL ' + TP_RT_PFX + 'SETVIDEOMODE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETACTIVEPAGE(page) }
    If Up = '_SETACTIVEPAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetActivePage (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETVISUALPAGE(page) }
    If Up = '_SETVISUALPAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetVisualPage (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETVIDEOCONFIG(var vc) }
    If Up = '_GETVIDEOCONFIG' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      { EAX = adresse de la variable VC }
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'GETVIDEOCONFIG');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETVIEWORG(x, y, var org) }
    If Up = '_SETVIEWORG' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetViewOrg (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETVIEWPORT(x1,y1,x2,y2) }
    If Up = '_SETVIEWPORT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_SetViewport (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETCLIPRGN(x1,y1,x2,y2) }
    If Up = '_SETCLIPRGN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_SetClipRgn (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETWINDOW(finvert, x1, y1, x2, y2) }
    If Up = '_SETWINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_SetWindow (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETVIEWCOORD / _GETVIEWCOORD_W / _GETVIEWCOORD_WXY }
    If (Up = '_GETVIEWCOORD') Or (Up = '_GETVIEWCOORD_W') Or (Up = '_GETVIEWCOORD_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETPHYSCOORD / _GETWINDOWCOORD }
    If (Up = '_GETPHYSCOORD') Or (Up = '_GETWINDOWCOORD') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETCURRENTPOSITION(var xy) / _GETCURRENTPOSITION_WXY(var wxy) }
    If (Up = '_GETCURRENTPOSITION') Or (Up = '_GETCURRENTPOSITION_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _CLEARSCREEN(area) }
    If Up = '_CLEARSCREEN' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      { Effacer la fenetre : PatBlt(hdc, 0, 0, MaxX+1, MaxY+1, BLACKNESS=42h) }
      Lbl := LabelGen;
      EmitInstr('CMP DWORD PTR [GR_ACTIVE],0');
      EmitInstr('JZ ' + Lbl);
      EmitInstr('PUSH 42h');               { BLACKNESS }
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXY]');
      EmitInstr('INC EAX');                { MAXY+1 = nHeight }
      EmitInstr('PUSH EAX');
      EmitInstr('MOV EAX,DWORD PTR [GR_MAXX]');
      EmitInstr('INC EAX');                { MAXX+1 = nWidth }
      EmitInstr('PUSH EAX');
      EmitInstr('PUSH 0');                 { y = 0 }
      EmitInstr('PUSH 0');                 { x = 0 }
      EmitInstr('PUSH DWORD PTR [GR_HDC]');
      EmitInstr('CALL PatBlt');
      EmitLabel(Lbl);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _MOVETO(x,y) }
    If Up = '_MOVETO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('MOV DWORD PTR [GR_CPX],EAX');
        EPMatch(',');
        ParseExpr(PI);
        EmitInstr('MOV DWORD PTR [GR_CPY],EAX');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _MOVETO_W(wx,wy) -> stub }
    If Up = '_MOVETO_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_MoveTo_w (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _LINETO(x,y) -> maps to LineTo }
    If Up = '_LINETO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'LINETO');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _LINETO_W(wx,wy) -> stub }
    If Up = '_LINETO_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_LineTo_w (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _RECTANGLE(control, x1, y1, x2, y2) }
    If Up = '_RECTANGLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX'); { control }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x2 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y2 }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'MSGR_RECT');
      EmitInstr('ADD ESP,20');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _RECTANGLE_W / _RECTANGLE_WXY -> stubs }
    If (Up = '_RECTANGLE_W') Or (Up = '_RECTANGLE_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _ELLIPSE(control, x1,y1,x2,y2) }
    If Up = '_ELLIPSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX'); { control }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x2 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y2 }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'MSGR_ELLPS');
      EmitInstr('ADD ESP,20');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _ELLIPSE_W / _ELLIPSE_WXY -> stubs }
    If (Up = '_ELLIPSE_W') Or (Up = '_ELLIPSE_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _ARC(x1,y1,x2,y2,x3,y3,x4,y4) }
    If Up = '_ARC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y1 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x2 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y2 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x3 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y3 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x4 }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y4 }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'ARC');
      EmitInstr('ADD ESP,32');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _ARC_WXY(var wxy1..4) - stub }
    If Up = '_ARC_WXY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment('_ARC_WXY (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _PIE / _PIE_WXY }
    If (Up = '_PIE') Or (Up = '_PIE_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _FLOODFILL(x,y,boundary) }
    If Up = '_FLOODFILL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { boundary color index }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'MSGR_FLOOD');
      EmitInstr('ADD ESP,12');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _FLOODFILL_W(wx,wy,boundary) }
    If Up = '_FLOODFILL_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_FloodFill_w (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETPIXEL(x,y) }
    If Up = '_SETPIXEL' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EmitInstr('PUSH EAX'); { x }
        EPMatch(',');
        ParseExpr(PI); EmitInstr('PUSH EAX'); { y }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'MSGR_SETPXL');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETPIXEL_W(wx,wy) }
    If Up = '_SETPIXEL_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetPixel_w (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETCOLOR(color) }
    If Up = '_SETCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('AND EAX,0Fh');
      EmitInstr('MOV DWORD PTR [GR_COLOR],EAX');
      { Mettre a jour le stylo si la fenetre est ouverte }
      Lbl := LabelGen;
      EmitInstr('CMP DWORD PTR [GR_ACTIVE],0');
      EmitInstr('JZ ' + Lbl);
      EmitInstr('CALL ' + TP_RT_PFX + 'UPDATEPEN');
      EmitLabel(Lbl);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETBKCOLOR(color) }
    If Up = '_SETBKCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('MOV DWORD PTR [GR_BKCOLOR],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETLINESTYLE(style) }
    If Up = '_SETLINESTYLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('MOV DWORD PTR [GR_LINESTYLE],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETWRITEMODE(wmode) }
    If Up = '_SETWRITEMODE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitInstr('MOV DWORD PTR [GR_WRITEMODE],EAX');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETFILLMASK(mask) }
    If Up = '_SETFILLMASK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetFillMask (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _REMAPALLPALETTE(var newpalette) }
    If Up = '_REMAPALLPALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_RemapAllPalette (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETTEXTWINDOW(r1,c1,r2,c2) }
    If Up = '_SETTEXTWINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_SetTextWindow (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETTEXTWINDOW(var r1,c1,r2,c2) }
    If Up = '_GETTEXTWINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(',');
        ParseExpr(PI); EPMatch(','); ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('_GetTextWindow (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SCROLLTEXTWINDOW(count) }
    If Up = '_SCROLLTEXTWINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_ScrollTextWindow (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _OUTMEM(s, len) }
    If Up = '_OUTMEM' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_OutMem (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _OUTTEXT(s) }
    If Up = '_OUTTEXT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_OutText (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETTEXTCURSOR(attr) }
    If Up = '_SETTEXTCURSOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetTextCursor (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETTEXTPOSITION(r, c) }
    If Up = '_SETTEXTPOSITION' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetTextPosition (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETTEXTPOSITION(var r, c) }
    If Up = '_GETTEXTPOSITION' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_GetTextPosition (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETTEXTCOLOR(color) }
    If Up = '_SETTEXTCOLOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetTextColor (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETIMAGE(x1,y1,x2,y2,var image) }
    If Up = '_GETIMAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment('_GetImage (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETIMAGE_W / _GETIMAGE_WXY }
    If (Up = '_GETIMAGE_W') Or (Up = '_GETIMAGE_WXY') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment(Up + ' (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _PUTIMAGE(x,y,var image, action) }
    If Up = '_PUTIMAGE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment('_PutImage (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _PUTIMAGE_W }
    If Up = '_PUTIMAGE_W' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        While (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin EPMatch(','); ParseExpr(PI); End;
        EPMatch(')');
      End;
      EmitComment('_PutImage_w (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _UNREGISTERFONTS }
    If Up = '_UNREGISTERFONTS' Then
    Begin
      Inc(EP);
      EmitComment('_UnRegisterFonts (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _OUTGTEXT(s) }
    If Up = '_OUTGTEXT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then Begin ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_OutGText (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _SETGTEXTVECTOR(x, y) }
    If Up = '_SETGTEXTVECTOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_SetGTextVector (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { _GETGTEXTVECTOR(var x, y) }
    If Up = '_GETGTEXTVECTOR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin ParseExpr(PI); EPMatch(','); ParseExpr(PI); EPMatch(')'); End;
      EmitComment('_GetGTextVector (stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 20 : Procedures Graph3 comme identifiants ---- }

    { GRAPHCOLORMODE }
    If Up = 'GRAPHCOLORMODE' Then
    Begin
      Inc(EP);
      EmitComment('GraphColorMode (Graph3 compat - stub InitGraph)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GRAPHMODE }
    If Up = 'GRAPHMODE' Then
    Begin
      Inc(EP);
      EmitComment('GraphMode (Graph3 compat - stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { HIRES }
    If Up = 'HIRES' Then
    Begin
      Inc(EP);
      EmitComment('HiRes (Graph3 compat - stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { HIRESCOLOR }
    If Up = 'HIRESCOLOR' Then
    Begin
      Inc(EP);
      EmitComment('HiResColor (Graph3 compat - stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PALETTE(N) }
    If Up = 'PALETTE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('Palette (Graph3 compat - stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GRAPHBACKGROUND(Color) }
    If Up = 'GRAPHBACKGROUND' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [GR_BKCOLOR],EAX');
      EmitComment('GraphBackground (Graph3 compat)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { GRAPHWINDOW(X1, Y1, X2, Y2) }
    If Up = 'GRAPHWINDOW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPXL],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPYT],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPXR],EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('MOV DWORD PTR [GR_VPYB],EAX');
        EPMatch(')');
      End;
      EmitComment('GraphWindow (Graph3 compat)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { PLOT(X, Y, Color) }
    If Up = 'PLOT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'PUTPIXEL');
      EmitInstr('ADD ESP,12');
      EmitComment('Plot (Graph3 compat -> PutPixel)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { DRAW(X1, Y1, X2, Y2, Color) }
    If Up = 'DRAW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');
        EPMatch(',');
        ParseExpr(PI);  EmitInstr('PUSH EAX');  { Color }
        EPMatch(')');
      End;
      { SetColor puis Line }
      EmitInstr('CALL ' + TP_RT_PFX + 'SETCOLOR');
      EmitInstr('ADD ESP,4');
      EmitInstr('CALL ' + TP_RT_PFX + 'LINE');
      EmitInstr('ADD ESP,16');
      EmitComment('Draw (Graph3 compat -> SetColor+Line)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { COLORTABLE(C1, C2, C3, C4) }
    If Up = 'COLORTABLE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(',');
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('ColorTable (Graph3 compat - stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Strings comme identifiants ---- }

    { STRDISPOSE(S) : liberer chaine allouee par StrNew }
    If Up = 'STRDISPOSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRDISPOSE');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Printer comme identifiants ---- }

    { ASSIGNLST : assigner fichier imprimante (stub) }
    If Up = 'ASSIGNLST' Then
    Begin
      Inc(EP);
      EmitComment('AssignLst (Printer unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Overlay comme identifiants (stubs) ---- }

    { OVRINIT(FileName) }
    If Up = 'OVRINIT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('OvrInit (stub - not needed in Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OVRINITEMS }
    If Up = 'OVRINITEMS' Then
    Begin
      Inc(EP);
      EmitComment('OvrInitEMS (stub - not needed in Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OVRSETBUF(Size) }
    If Up = 'OVRSETBUF' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('MOV DWORD PTR [OVR_BUFSIZE],EAX');
      EmitComment('OvrSetBuf (stub - not needed in Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OVRCLEARBUF }
    If Up = 'OVRCLEARBUF' Then
    Begin
      Inc(EP);
      EmitComment('OvrClearBuf (stub - not needed in Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { OVRSETRETRY(Size) }
    If Up = 'OVRSETRETRY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('OvrSetRetry (stub - not needed in Win32)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Turbo3 comme identifiants ---- }
    { Note : GotoXY, ClrScr, ClrEol, LowVideo, NormVideo,     }
    { Delay sont traites par les handlers CRT (TODO 18).       }
    { Plot, Draw, ColorTable, GraphBackground, HiRes, etc.     }
    { sont traites par les handlers Graph3 (TODO 20).          }
    { GraphColorMode / GraphMode : stubs (mode graphique TP3)  }

    If Up = 'GRAPHCOLORMODE' Then
    Begin
      Inc(EP);
      EmitComment('GraphColorMode (Turbo3 compat -> stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    If Up = 'GRAPHMODE' Then
    Begin
      Inc(EP);
      EmitComment('GraphMode (Turbo3 compat -> stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Objects comme identifiants ---- }

    { REGISTERTYPE(TypeRec) : enregistrer un type pour Get/Put }
    If Up = 'REGISTERTYPE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('RegisterType (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { DISPOSESTR(S) : liberer chaine allouee par NewStr }
    If Up = 'DISPOSESTR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'DISPOSESTR');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 21 : Procedures Objects comme identifiants ---- }

    { TOBJECT_INIT : constructeur de base (stub) }
    If Up = 'TOBJECT_INIT' Then
    Begin
      Inc(EP);
      EmitComment('TObject.Init (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TOBJECT_DONE : destructeur de base (stub) }
    If Up = 'TOBJECT_DONE' Then
    Begin
      Inc(EP);
      EmitComment('TObject.Done (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TOBJECT_FREE : liberer objet (stub) }
    If Up = 'TOBJECT_FREE' Then
    Begin
      Inc(EP);
      EmitComment('TObject.Free (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TDOSSTREAM_INIT(FileName, Mode) : ouvrir fichier stream }
    If Up = 'TDOSSTREAM_INIT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { FileName }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Mode }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'DOSSTREAM_INIT');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TDOSSTREAM_DONE : fermer fichier stream }
    If Up = 'TDOSSTREAM_DONE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'DOSSTREAM_DONE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TBUFSTREAM_INIT(FileName, Mode, BufSize) }
    If Up = 'TBUFSTREAM_INIT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { FileName }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Mode }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EmitComment('BufSize ignored - using default');
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'DOSSTREAM_INIT');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TBUFSTREAM_DONE : fermer fichier stream bufferise }
    If Up = 'TBUFSTREAM_DONE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'DOSSTREAM_DONE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TBUFSTREAM_FLUSH : vider buffer stream }
    If Up = 'TBUFSTREAM_FLUSH' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_FLUSH');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TCOLLECTION_INIT(Limit, Delta) }
    If Up = 'TCOLLECTION_INIT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('TCollection.Init (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TCOLLECTION_DONE }
    If Up = 'TCOLLECTION_DONE' Then
    Begin
      Inc(EP);
      EmitComment('TCollection.Done (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TCOLLECTION_INSERT(Item) }
    If Up = 'TCOLLECTION_INSERT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('TCollection.Insert (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TCOLLECTION_DELETE(Item) }
    If Up = 'TCOLLECTION_DELETE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitComment('TCollection.Delete (Objects unit stub)');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TSTREAM_WRITE(Buf, Count) }
    If Up = 'TSTREAM_WRITE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Buf }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then Inc(EP);
        ParseExpr(PI);
        EmitInstr('PUSH EAX'); { Count }
        EPMatch(')');
      End;
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_WRITE');
      EmitInstr('ADD ESP,8');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TSTREAM_SEEK(Pos) }
    If Up = 'TSTREAM_SEEK' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_SEEK');
      EmitInstr('ADD ESP,4');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TSTREAM_RESET }
    If Up = 'TSTREAM_RESET' Then
    Begin
      Inc(EP);
      EmitInstr('MOV DWORD PTR [OBJ_STATUS],0');
      EmitComment('TStream.Reset -> stOk');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TSTREAM_FLUSH }
    If Up = 'TSTREAM_FLUSH' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_FLUSH');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { TSTREAM_TRUNCATE }
    If Up = 'TSTREAM_TRUNCATE' Then
    Begin
      Inc(EP);
      EmitInstr('CALL ' + TP_RT_PFX + 'STREAM_TRUNCATE');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then Inc(EP);
      Exit;
    End;

    { ---- TODO 22 : Mem[Seg:Ofs] := val / MemW / MemL en ecriture ---- }
    If (Up = 'MEM') Or (Up = 'MEMW') Or (Up = 'MEML') Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        ParseExpr(PI);           { EAX = Seg }
        EmitInstr('PUSH EAX');   { sauvegarder Seg }
        { Attendre ':' separateur Seg:Ofs }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ':') Then
          Inc(EP);
        ParseExpr(PI);           { EAX = Ofs }
        EmitInstr('PUSH EAX');   { sauvegarder Ofs }
        EPMatch(']');
        { Attendre ':=' }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = ':=') Then
        Begin
          Inc(EP);
          ParseExpr(PI);         { EAX = valeur a ecrire }
          EmitInstr('MOV ECX,EAX');  { ECX = val }
          EmitInstr('POP EDX');      { EDX = Ofs }
          EmitInstr('POP EAX');      { EAX = Seg }
          { Appeler _TPRT_WRITEMEM : EAX=seg, EDX=ofs, ECX=val }
          EmitInstr('CALL ' + TP_RT_PFX + 'WRITEMEM');
        End;
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ---- TODO 22 : Port[$nn] := val / PortW en ecriture ---- }
    If (Up = 'PORT') Or (Up = 'PORTW') Then
    Begin
      Inc(EP);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        ParseExpr(PI);           { EAX = numero de port }
        EmitInstr('PUSH EAX');   { sauvegarder port }
        EPMatch(']');
        { Attendre ':=' }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = ':=') Then
        Begin
          Inc(EP);
          ParseExpr(PI);         { EAX = valeur a ecrire }
          EmitInstr('MOV EDX,EAX');  { EDX = val }
          EmitInstr('POP EAX');      { EAX = port }
          { Appeler _TPRT_OUTPORT : EAX=port, EDX=val }
          EmitInstr('CALL ' + TP_RT_PFX + 'OUTPORT');
        End;
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Appel de proc (dans SymTab) }
    SI := SymFind(Up);
    If (SI >= 0) And (SymTab[SI].Kind = SK_PROC) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Appel de proc (dans ProcTab) }
    LI := 0;
    While LI < ProcCount Do
    Begin
      If ProcTab[LI].Name = Up Then Break;
      Inc(LI);
    End;
    If (LI < ProcCount) And (Not ProcTab[LI].IsFunction) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { WITH : resoudre champ implicite dans le scope WITH }
    If (WithDepth > 0) Then
    Begin
      WI := WithDepth - 1;
      While WI >= 0 Do
      Begin
        FSize := 4;
        FOfs := FindFieldOffset(WithTypeIdx[WI], Up, FSize);
        If FOfs >= 0 Then Break;
        Dec(WI);
      End;
      If (WI >= 0) And (FOfs >= 0) Then
      Begin
        Inc(EP);
        { Affectation champ via WITH : field := expr }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = ':=') Then
        Begin
          Inc(EP);
          GenLoadAddr(PI, WithVarName[WI]);
          If FOfs > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(FOfs));
          EmitInstr('PUSH EAX');
          ParseExpr(PI);
          EmitInstr('POP EBX');
          If FSize = 1 Then
            EmitInstr('MOV BYTE PTR [EBX],AL')
          Else If (WithTypeIdx[WI] >= 0) And (WithTypeIdx[WI] < TypeCount) Then
          Begin
            { Verifier si le champ est un String }
            LastVarTypeIdx := WithTypeIdx[WI];
            For ElemSz := 0 To TypeTab[LastVarTypeIdx].FieldCount - 1 Do
              If TypeTab[LastVarTypeIdx].Fields[ElemSz].Name = Up Then
              Begin
                If (TypeTab[LastVarTypeIdx].Fields[ElemSz].TypeIdx >= 0) And
                   (TypeTab[LastVarTypeIdx].Fields[ElemSz].TypeIdx < TypeCount) And
                   (TypeTab[TypeTab[LastVarTypeIdx].Fields[ElemSz].TypeIdx].Kind = TYK_STRING) Then
                Begin
                  EmitInstr('MOV ESI,EAX');
                  EmitInstr('MOV EDI,EBX');
                  EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
                End
                Else
                  EmitInstr('MOV [EBX],EAX');
                Break;
              End;
          End
          Else
            EmitInstr('MOV [EBX],EAX');
        End;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;
    End;

    { Affectation ou appel de fonction }
    Inc(EP);
    If Not EPAtEnd Then
    Begin
      { Affectation tableau : ident[index] := expr  (multi-dim, String) }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        LastVarTypeIdx := GetVarTypeIdx(PI, VName);
        TIdx := LastVarTypeIdx;        { sauvegarder le type du tableau }
        { Calculer l adresse de l element }
        GenLoadAddr(PI, VName);
        EmitInstr('PUSH EAX');         { sauvegarder adresse base }
        ParseExpr(PI);                 { EAX = index }
        LastVarTypeIdx := TIdx;        { restaurer le type du tableau }
        { Soustraire borne inferieure }
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].Lo <> 0) Then
          EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
        { Multiplier par la taille de l element }
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
        Begin
          ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
          If ElemSz = 1 Then
            { rien }
          Else If ElemSz = 2 Then
            EmitInstr('SHL EAX,1')
          Else If ElemSz = 4 Then
            EmitInstr('SHL EAX,2')
          Else If ElemSz = 8 Then
            EmitInstr('SHL EAX,3')
          Else
            EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
          TIdx := TypeTab[LastVarTypeIdx].BaseTypeIdx;  { avancer type }
          LastVarTypeIdx := TIdx;
        End
        Else
          EmitInstr('SHL EAX,2');
        EmitInstr('POP EBX');
        EmitInstr('ADD EAX,EBX');      { EAX = adresse element }
        { Dimensions supplementaires separees par ',' }
        While (Not EPAtEnd) And
              (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Do
        Begin
          Inc(EP);  { consommer ',' }
          LastVarTypeIdx := TIdx;
          EmitInstr('PUSH EAX');
          ParseExpr(PI);
          LastVarTypeIdx := TIdx;
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
             (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
             (TypeTab[LastVarTypeIdx].Lo <> 0) Then
            EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
             (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
             (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
          Begin
            ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
            If ElemSz = 1 Then
            Else If ElemSz = 2 Then EmitInstr('SHL EAX,1')
            Else If ElemSz = 4 Then EmitInstr('SHL EAX,2')
            Else If ElemSz = 8 Then EmitInstr('SHL EAX,3')
            Else EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
            TIdx := TypeTab[LastVarTypeIdx].BaseTypeIdx;
            LastVarTypeIdx := TIdx;
          End
          Else
            EmitInstr('SHL EAX,2');
          EmitInstr('POP EBX');
          EmitInstr('ADD EAX,EBX');
        End;
        EmitInstr('PUSH EAX');         { sauvegarder adresse element }
        EPMatch(']');
        { Attendre ':=' }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = ':=') Then
        Begin
          Inc(EP);
          ParseExpr(PI);               { EAX = valeur }
          EmitInstr('POP EBX');
          { Stocker selon le type de l element }
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TYK_STRING) Then
          Begin
            { String : copier via STRASSIGN }
            EmitInstr('MOV ESI,EAX');
            EmitInstr('MOV EDI,EBX');
            EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
          End
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeSizeofIdx(TIdx) = 1) Then
            EmitInstr('MOV BYTE PTR [EBX],AL')
          Else
            EmitInstr('MOV [EBX],EAX');
        End;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Affectation champ : ident.field := expr }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
      Begin
        Inc(EP);
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          Inc(EP);
          LastVarTypeIdx := GetVarTypeIdx(PI, VName);
          FSize := 4;
          FOfs := FindFieldOffset(LastVarTypeIdx, Up, FSize);
          If FOfs >= 0 Then
          Begin
            GenLoadAddr(PI, VName);
            If FOfs > 0 Then
              EmitInstr('ADD EAX,' + IntToStr_(FOfs));
            EmitInstr('PUSH EAX');     { sauvegarder adresse champ }
            { Attendre ':=' }
            If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
               (TokenPool[EP].Val = ':=') Then
            Begin
              Inc(EP);
              ParseExpr(PI);           { EAX = valeur }
              EmitInstr('POP EBX');
              If FSize = 1 Then
                EmitInstr('MOV BYTE PTR [EBX],AL')
              Else
                EmitInstr('MOV [EBX],EAX');
            End;
          End;
        End;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Affectation ident := expr }
      If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = ':=') Then
      Begin
        Inc(EP);
        ParseExpr(PI);
        GenStoreVar(PI, VName);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Appel de fonction (via SymTab) }
      If (SI >= 0) And (SymTab[SI].Kind = SK_FUNC) Then
      Begin
        ParseFuncCall(PI, Up);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Appel avec parentheses }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
      Begin
        ParseFuncCall(PI, Up);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;
    End;

    { Sinon : continuer }
    Exit;
  End;

  { Autre : avancer }
  Inc(EP);
End;
{ Gere : affectation, appel, EXIT, var := expr, INC, DEC       }
{ Utilise ParseStmt pour chaque instruction.                    }
{ ------------------------------------------------------------ }

Procedure ParseBody(PI : Integer);
Var
  Up      : TString;
  SaveEP, SaveEnd, PrevEP : Integer;
Begin
  { Sauvegarder le contexte si necessaire }
  SaveEP  := EP;
  SaveEnd := EPEnd;

  If PI >= 0 Then
  Begin
    EP    := ProcTab[PI].BodyStart;
    EPEnd := ProcTab[PI].BodyEnd;
    CurProcIdx := PI;
  End;

  { Initialiser la pile de boucles }
  LoopTop := -1;

  { Sauter le BEGIN initial }
  If Not EPAtEnd Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If Up = 'BEGIN' Then
      Inc(EP);
  End;

  { Parser les instructions du corps via ParseStmt }
  While Not EPAtEnd Do
  Begin
    { END : fin du bloc }
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'END') Then
    Begin
      Inc(EP);
      { Sauter le '.' ou ';' apres END }
      If Not EPAtEnd Then
      Begin
        If (TokenPool[EP].Kind = TK_PUNCT) And
           ((TokenPool[EP].Val = '.') Or (TokenPool[EP].Val = ';')) Then
          Inc(EP);
      End;
      Break;
    End;

    { Point final : fin du programme }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
    Begin
      Inc(EP);
      Break;
    End;

    { Deleguer a ParseStmt }
    PrevEP := EP;
    ParseStmt(PI);
    { Securite : si EP n a pas avance, forcer l avancement }
    If EP = PrevEP Then
      Inc(EP);
  End;

  { Restaurer le contexte }
  EP    := SaveEP;
  EPEnd := SaveEnd;
End;

{ ------------------------------------------------------------ }
{ EmitProcedures : emettre le code ASM pour chaque procedure   }
{ et fonction declaree dans ProcTab.                            }
{ Emet le prologue, le corps (ParseBody), et l epilogue.       }
{ ------------------------------------------------------------ }

Procedure EmitProcedures;
Var
  FI       : Integer;
Begin
  For FI := 0 To ProcCount - 1 Do
  Begin
    If ProcTab[FI].IsForward Then Continue;
    If ProcTab[FI].IsExternal Then Continue;

    EmitBlankLine;
    EmitComment('--- ' + ProcTab[FI].Name + ' ---');
    EmitLabel(ProcTab[FI].MangledName);
    EmitProlog(ProcTab[FI].LocalSize);

    { Initialiser la valeur de retour a 0 pour les fonctions }
    If ProcTab[FI].IsFunction Then
      EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[FI].RetOffset) + ',0');

    { Label de retour }
    RetLbl := LabelGen;

    { Parser et emettre le corps de la fonction }
    ParseBody(FI);

    { Emettre le label de retour }
    EmitLabel(RetLbl);

    { Charger la valeur de retour dans EAX pour les fonctions }
    If ProcTab[FI].IsFunction Then
      EmitInstr('MOV EAX,' + 'DWORD PTR ' +
        EBPOfs(ProcTab[FI].RetOffset));

    EmitEpilog;
  End;
End;

{ ============================================================ }
{ TODO 17 - INSTRUCTION ASM ET TRADUCTION 8086 -> 80386        }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ TranslateReg16to32 : traduire un registre 8086 (16 bits)     }
{ vers son equivalent 80386 (32 bits).                          }
{ AX->EAX, BX->EBX, CX->ECX, DX->EDX                          }
{ SI->ESI, DI->EDI, BP->EBP, SP->ESP                           }
{ Registres 8 bits (AL,AH,BL,...) : inchanges                  }
{ Registres de segment (CS,DS,ES,SS) : retourne '' (ignores)   }
{ ------------------------------------------------------------ }

Function TranslateReg16to32(Const Reg : TString) : TString;
Var
  Up : TString;
Begin
  Up := StrUpperCase(Reg);
  { Registres 16 bits -> 32 bits }
  If Up = 'AX' Then TranslateReg16to32 := 'EAX'
  Else If Up = 'BX' Then TranslateReg16to32 := 'EBX'
  Else If Up = 'CX' Then TranslateReg16to32 := 'ECX'
  Else If Up = 'DX' Then TranslateReg16to32 := 'EDX'
  Else If Up = 'SI' Then TranslateReg16to32 := 'ESI'
  Else If Up = 'DI' Then TranslateReg16to32 := 'EDI'
  Else If Up = 'BP' Then TranslateReg16to32 := 'EBP'
  Else If Up = 'SP' Then TranslateReg16to32 := 'ESP'
  { Registres de segment : ignores en mode FLAT Win32 }
  Else If Up = 'CS' Then TranslateReg16to32 := ''
  Else If Up = 'DS' Then TranslateReg16to32 := ''
  Else If Up = 'ES' Then TranslateReg16to32 := ''
  Else If Up = 'SS' Then TranslateReg16to32 := ''
  { Registres 8 bits : inchanges }
  Else If (Up = 'AL') Or (Up = 'AH') Or (Up = 'BL') Or (Up = 'BH') Or
          (Up = 'CL') Or (Up = 'CH') Or (Up = 'DL') Or (Up = 'DH') Then
    TranslateReg16to32 := Up
  { Registres 32 bits deja : inchanges }
  Else If (Up = 'EAX') Or (Up = 'EBX') Or (Up = 'ECX') Or (Up = 'EDX') Or
          (Up = 'ESI') Or (Up = 'EDI') Or (Up = 'EBP') Or (Up = 'ESP') Then
    TranslateReg16to32 := Up
  Else
    TranslateReg16to32 := Reg;  { pas un registre, retourner tel quel }
End;

{ ------------------------------------------------------------ }
{ IsAsmReg : tester si un identificateur est un registre x86   }
{ ------------------------------------------------------------ }

Function IsAsmReg(Const S : TString) : Boolean;
Var
  Up : TString;
Begin
  Up := StrUpperCase(S);
  IsAsmReg :=
    (Up = 'AX') Or (Up = 'BX') Or (Up = 'CX') Or (Up = 'DX') Or
    (Up = 'SI') Or (Up = 'DI') Or (Up = 'BP') Or (Up = 'SP') Or
    (Up = 'AL') Or (Up = 'AH') Or (Up = 'BL') Or (Up = 'BH') Or
    (Up = 'CL') Or (Up = 'CH') Or (Up = 'DL') Or (Up = 'DH') Or
    (Up = 'EAX') Or (Up = 'EBX') Or (Up = 'ECX') Or (Up = 'EDX') Or
    (Up = 'ESI') Or (Up = 'EDI') Or (Up = 'EBP') Or (Up = 'ESP') Or
    (Up = 'CS') Or (Up = 'DS') Or (Up = 'ES') Or (Up = 'SS');
End;

{ ------------------------------------------------------------ }
{ TranslateAsmOperand : traduire un operande ASM 8086 vers     }
{ 80386. Gere les registres, les immediats, et les references   }
{ memoire avec adressage indirect [BX+SI+disp] etc.            }
{ ------------------------------------------------------------ }

Function TranslateAsmOperand(PI : Integer; Const Op : TString) : TString;
Var
  R     : TString;
  I     : Integer;
  C     : Char;
  Tok   : TString;
  Up    : TString;
Begin
  If Length(Op) = 0 Then
  Begin
    TranslateAsmOperand := '';
    Exit;
  End;

  { Si l operande est un simple registre }
  Up := StrUpperCase(Op);
  If IsAsmReg(Up) Then
  Begin
    TranslateAsmOperand := TranslateReg16to32(Op);
    Exit;
  End;

  { Si c est un reference memoire [xxx] }
  If (Op[1] = '[') And (Op[Length(Op)] = ']') Then
  Begin
    R := '[';
    I := 2;
    While I < Length(Op) Do
    Begin
      C := Op[I];
      { Extraire un token (ident ou autre) }
      If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
         (C = '_') Then
      Begin
        Tok := '';
        While (I < Length(Op)) And
              (((Op[I] >= 'A') And (Op[I] <= 'Z')) Or
               ((Op[I] >= 'a') And (Op[I] <= 'z')) Or
               ((Op[I] >= '0') And (Op[I] <= '9')) Or
               (Op[I] = '_')) Do
        Begin
          Tok := Tok + Op[I];
          Inc(I);
        End;
        { Traduire les registres dans les crochets }
        If IsAsmReg(Tok) Then
          R := R + TranslateReg16to32(Tok)
        Else
        Begin
          { Verifier si c est une variable Pascal }
          If (PI >= 0) And (FindLocal(PI, Tok) >= 0) Then
            R := R + GenVarAddr(PI, Tok)
          Else If (PI >= 0) And (FindParam(PI, Tok) >= 0) Then
            R := R + GenVarAddr(PI, Tok)
          Else If SymFind(StrUpperCase(Tok)) >= 0 Then
            R := R + GenVarAddr(PI, Tok)
          Else
            R := R + Tok;
        End;
      End
      Else
      Begin
        R := R + C;
        Inc(I);
      End;
    End;
    R := R + ']';
    TranslateAsmOperand := R;
    Exit;
  End;

  { Verifier si c est une variable Pascal (pas un immediat) }
  If ((Op[1] >= 'A') And (Op[1] <= 'Z')) Or
     ((Op[1] >= 'a') And (Op[1] <= 'z')) Or
     (Op[1] = '_') Then
  Begin
    If IsAsmReg(Op) Then
    Begin
      TranslateAsmOperand := TranslateReg16to32(Op);
      Exit;
    End;
    { Verifier si c est une variable Pascal connue }
    If (PI >= 0) And (FindLocal(PI, Op) >= 0) Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
    If (PI >= 0) And (FindParam(PI, Op) >= 0) Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
    If SymFind(StrUpperCase(Op)) >= 0 Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
  End;

  { Sinon retourner tel quel (immediat, label, etc.) }
  TranslateAsmOperand := Op;
End;

{ ------------------------------------------------------------ }
{ AsmTrimSpaces : supprimer les espaces en debut et fin         }
{ ------------------------------------------------------------ }

Function AsmTrimSpaces(Const S : TString) : TString;
Var
  A, B : Integer;
Begin
  A := 1;
  While (A <= Length(S)) And (S[A] = ' ') Do Inc(A);
  B := Length(S);
  While (B >= A) And (S[B] = ' ') Do Dec(B);
  AsmTrimSpaces := Copy(S, A, B - A + 1);
End;

{ ------------------------------------------------------------ }
{ TranslateAsmLine : traduire une ligne ASM complete 8086       }
{ vers son equivalent 80386.                                    }
{ Gere : traduction des mnemoniques, registres et adressage     }
{ CBW->CWDE, CWD->CDQ, PUSHF->PUSHFD, POPF->POPFD             }
{ LDS/LES -> MOV registre 32 bits                               }
{ INT nn -> commentaire (emulation future TODO 21)              }
{ IN/OUT -> appel _TPRT_INPORT/_TPRT_OUTPORT (emulation TODO 22) }
{ LOOP/LOOPZ/LOOPNZ -> DEC ECX + Jcc equivalent                }
{ ------------------------------------------------------------ }

Procedure TranslateAsmLine(PI : Integer; Const Line : TString);
Var
  S      : TString;
  Mne    : TString;
  Rest   : TString;
  Op1    : TString;
  Op2    : TString;
  I, J   : Integer;
  Depth  : Integer;
  Up     : TString;
  LblEnd : TString;
Begin
  S := AsmTrimSpaces(Line);
  If Length(S) = 0 Then Exit;

  { Extraire le mnemonique (premier mot) }
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  Mne := Copy(S, 1, I - 1);
  Up := StrUpperCase(Mne);

  { Extraire le reste (operandes) }
  While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
  Rest := Copy(S, I, Length(S) - I + 1);

  { Separer les operandes par virgule (en respectant les crochets) }
  Op1 := '';
  Op2 := '';
  Depth := 0;
  J := 0;
  For I := 1 To Length(Rest) Do
  Begin
    If Rest[I] = '[' Then Inc(Depth)
    Else If Rest[I] = ']' Then Dec(Depth);
    If (Rest[I] = ',') And (Depth = 0) And (J = 0) Then
    Begin
      J := I;
    End;
  End;
  If J > 0 Then
  Begin
    Op1 := AsmTrimSpaces(Copy(Rest, 1, J - 1));
    Op2 := AsmTrimSpaces(Copy(Rest, J + 1, Length(Rest) - J));
  End
  Else
    Op1 := AsmTrimSpaces(Rest);

  { --- Traductions speciales de mnemoniques --- }

  { CBW -> CWDE (extension de signe 8 -> 32 bits via EAX) }
  If Up = 'CBW' Then
  Begin
    EmitInstr('CWDE');
    Exit;
  End;

  { CWD -> CDQ (extension de signe 16 -> 64 bits via EDX:EAX) }
  If Up = 'CWD' Then
  Begin
    EmitInstr('CDQ');
    Exit;
  End;

  { PUSHF -> PUSHFD }
  If Up = 'PUSHF' Then
  Begin
    EmitInstr('PUSHFD');
    Exit;
  End;

  { POPF -> POPFD }
  If Up = 'POPF' Then
  Begin
    EmitInstr('POPFD');
    Exit;
  End;

  { LDS reg, [mem] -> MOV Ereg, DWORD PTR [mem] }
  If Up = 'LDS' Then
  Begin
    EmitComment('LDS traduit en MOV 32 bits (mode FLAT)');
    EmitInstr('MOV ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2));
    Exit;
  End;

  { LES reg, [mem] -> MOV Ereg, DWORD PTR [mem] }
  If Up = 'LES' Then
  Begin
    EmitComment('LES traduit en MOV 32 bits (mode FLAT)');
    EmitInstr('MOV ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2));
    Exit;
  End;

  { LOOP label -> DEC ECX / JNZ label }
  If Up = 'LOOP' Then
  Begin
    EmitInstr('DEC ECX');
    EmitInstr('JNZ ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { LOOPZ/LOOPE label -> DEC ECX / JNZ +skip / JZ label }
  If (Up = 'LOOPZ') Or (Up = 'LOOPE') Then
  Begin
    LblEnd := LabelGen;
    EmitInstr('DEC ECX');
    EmitInstr('JZ ' + LblEnd);
    EmitInstr('JZ ' + TranslateAsmOperand(PI, Op1));
    EmitLabel(LblEnd);
    Exit;
  End;

  { LOOPNZ/LOOPNE label -> DEC ECX / JZ +skip / JNZ label }
  If (Up = 'LOOPNZ') Or (Up = 'LOOPNE') Then
  Begin
    LblEnd := LabelGen;
    EmitInstr('DEC ECX');
    EmitInstr('JZ ' + LblEnd);
    EmitInstr('JNZ ' + TranslateAsmOperand(PI, Op1));
    EmitLabel(LblEnd);
    Exit;
  End;

  { INT nn -> emulation via routines runtime (TODO 23) }
  If Up = 'INT' Then
  Begin
    If (Op1 = '21h') Or (Op1 = '21H') Or (Op1 = '$21') Then
    Begin
      EmitComment('INT 21h -> emulation DOS via _TPRT_MSDOS');
      EmitInstr('CALL ' + TP_RT_PFX + 'MSDOS');
    End
    Else If (Op1 = '10h') Or (Op1 = '10H') Or (Op1 = '$10') Then
    Begin
      EmitComment('INT 10h -> emulation Video BIOS via _TPRT_INT10');
      EmitInstr('CALL ' + TP_RT_PFX + 'INT10');
    End
    Else If (Op1 = '16h') Or (Op1 = '16H') Or (Op1 = '$16') Then
    Begin
      EmitComment('INT 16h -> emulation Clavier BIOS via _TPRT_INT16');
      EmitInstr('CALL ' + TP_RT_PFX + 'INT16');
    End
    Else If (Op1 = '33h') Or (Op1 = '33H') Or (Op1 = '$33') Then
    Begin
      EmitComment('INT 33h -> emulation Souris via _TPRT_INT33');
      EmitInstr('CALL ' + TP_RT_PFX + 'INT33');
    End
    Else
    Begin
      EmitComment('INT ' + Op1 + ' (non emule - NOP)');
      EmitInstr('NOP');
    End;
    Exit;
  End;

  { IN -> emulation Port via _TPRT_INPORT (TODO 22) }
  If Up = 'IN' Then
  Begin
    EmitComment('IN ' + Op1 + ',' + Op2 + ' (emule via _TPRT_INPORT)');
    { Op2 = numero port (immediat ou DX), Op1 = registre dest (AL/AX/EAX) }
    { Charger le numero de port dans EAX }
    If StrUpperCase(Op2) = 'DX' Then
      EmitInstr('MOVZX EAX,DX')
    Else
      EmitInstr('MOV EAX,' + TranslateAsmOperand(PI, Op2));
    EmitInstr('CALL ' + TP_RT_PFX + 'INPORT');
    { Stocker le resultat dans le registre destination }
    If StrUpperCase(Op1) = 'AL' Then
      { resultat deja dans AL via EAX }
    Else If StrUpperCase(Op1) = 'AX' Then
      { resultat deja dans AX via EAX }
    Else
      { resultat deja dans EAX };
    Exit;
  End;

  { OUT -> emulation Port via _TPRT_OUTPORT (TODO 22) }
  If Up = 'OUT' Then
  Begin
    EmitComment('OUT ' + Op1 + ',' + Op2 + ' (emule via _TPRT_OUTPORT)');
    { Op1 = numero port (immediat ou DX), Op2 = valeur (AL/AX/EAX) }
    { Sauvegarder la valeur dans EDX }
    If StrUpperCase(Op2) = 'AL' Then
      EmitInstr('MOVZX EDX,AL')
    Else If StrUpperCase(Op2) = 'AX' Then
      EmitInstr('MOVZX EDX,AX')
    Else
      EmitInstr('MOV EDX,EAX');
    { Charger le numero de port dans EAX }
    If StrUpperCase(Op1) = 'DX' Then
      EmitInstr('MOVZX EAX,DX')
    Else
      EmitInstr('MOV EAX,' + TranslateAsmOperand(PI, Op1));
    EmitInstr('CALL ' + TP_RT_PFX + 'OUTPORT');
    Exit;
  End;

  { REP MOVSB / REP MOVSW -> REP MOVSD (ou traduire) }
  If Up = 'REP' Then
  Begin
    { Le reste contient l instruction repetee }
    If StrUpperCase(Op1) = 'MOVSW' Then
      EmitInstr('REP MOVSD')
    Else If StrUpperCase(Op1) = 'STOSW' Then
      EmitInstr('REP STOSD')
    Else
      EmitInstr('REP ' + StrUpperCase(Op1));
    Exit;
  End;

  { Instructions sans operande }
  If (Up = 'NOP') Or (Up = 'CLD') Or (Up = 'STD') Or
     (Up = 'RET') Or (Up = 'RETF') Or (Up = 'CLI') Or (Up = 'STI') Or
     (Up = 'MOVSB') Or (Up = 'MOVSW') Or (Up = 'MOVSD') Or
     (Up = 'STOSB') Or (Up = 'STOSW') Or (Up = 'STOSD') Or
     (Up = 'LODSB') Or (Up = 'LODSW') Or (Up = 'LODSD') Or
     (Up = 'SCASB') Or (Up = 'SCASW') Or (Up = 'SCASD') Or
     (Up = 'CMPSB') Or (Up = 'CMPSW') Or (Up = 'CMPSD') Or
     (Up = 'PUSHA') Or (Up = 'POPA') Or
     (Up = 'PUSHAD') Or (Up = 'POPAD') Or
     (Up = 'PUSHFD') Or (Up = 'POPFD') Or
     (Up = 'CWDE') Or (Up = 'CDQ') Or
     (Up = 'SAHF') Or (Up = 'LAHF') Or
     (Up = 'IRET') Or (Up = 'IRETD') Then
  Begin
    { MOVSW -> MOVSD en 32 bits }
    If Up = 'MOVSW' Then EmitInstr('MOVSD')
    Else If Up = 'STOSW' Then EmitInstr('STOSD')
    Else If Up = 'LODSW' Then EmitInstr('LODSD')
    Else If Up = 'SCASW' Then EmitInstr('SCASD')
    Else If Up = 'CMPSW' Then EmitInstr('CMPSD')
    Else If Up = 'PUSHA' Then EmitInstr('PUSHAD')
    Else If Up = 'POPA' Then EmitInstr('POPAD')
    Else If Up = 'IRET' Then EmitInstr('IRETD')
    Else If Up = 'RETF' Then EmitInstr('RET')
    Else EmitInstr(Up);
    Exit;
  End;

  { Instructions avec 1 operande : PUSH, POP, INC, DEC, NEG, NOT, }
  { CALL, JMP, Jcc, MUL, DIV, IMUL, IDIV                          }
  If (Up = 'PUSH') Or (Up = 'POP') Or (Up = 'INC') Or (Up = 'DEC') Or
     (Up = 'NEG') Or (Up = 'NOT') Or (Up = 'CALL') Or (Up = 'JMP') Or
     (Up = 'MUL') Or (Up = 'DIV') Or (Up = 'IMUL') Or (Up = 'IDIV') Or
     (Up = 'JE') Or (Up = 'JNE') Or (Up = 'JZ') Or (Up = 'JNZ') Or
     (Up = 'JL') Or (Up = 'JLE') Or (Up = 'JG') Or (Up = 'JGE') Or
     (Up = 'JB') Or (Up = 'JBE') Or (Up = 'JA') Or (Up = 'JAE') Or
     (Up = 'JC') Or (Up = 'JNC') Or (Up = 'JS') Or (Up = 'JNS') Or
     (Up = 'JO') Or (Up = 'JNO') Or (Up = 'JP') Or (Up = 'JNP') Or
     (Up = 'JCXZ') Or (Up = 'JECXZ') Or
     (Up = 'SETE') Or (Up = 'SETNE') Or (Up = 'SETL') Or
     (Up = 'SETLE') Or (Up = 'SETG') Or (Up = 'SETGE') Or
     (Up = 'SETB') Or (Up = 'SETBE') Or (Up = 'SETA') Or (Up = 'SETAE') Then
  Begin
    { JCXZ -> JECXZ en 32 bits }
    If Up = 'JCXZ' Then
      EmitInstr('JECXZ ' + TranslateAsmOperand(PI, Op1))
    Else If Length(Op2) > 0 Then
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
                TranslateAsmOperand(PI, Op2))
    Else
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { Instructions avec 2 operandes : MOV, ADD, SUB, CMP, TEST, AND, }
  { OR, XOR, SHL, SHR, ROL, ROR, RCL, RCR, LEA, XCHG, ADC, SBB   }
  If (Up = 'MOV') Or (Up = 'ADD') Or (Up = 'SUB') Or (Up = 'CMP') Or
     (Up = 'TEST') Or (Up = 'AND') Or (Up = 'OR') Or (Up = 'XOR') Or
     (Up = 'SHL') Or (Up = 'SHR') Or (Up = 'SAL') Or (Up = 'SAR') Or
     (Up = 'ROL') Or (Up = 'ROR') Or (Up = 'RCL') Or (Up = 'RCR') Or
     (Up = 'LEA') Or (Up = 'XCHG') Or (Up = 'ADC') Or (Up = 'SBB') Or
     (Up = 'BT') Or (Up = 'BTS') Or (Up = 'BTR') Or (Up = 'BTC') Or
     (Up = 'BSF') Or (Up = 'BSR') Or
     (Up = 'MOVZX') Or (Up = 'MOVSX') Or
     (Up = 'SHLD') Or (Up = 'SHRD') Then
  Begin
    If Length(Op2) > 0 Then
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
                TranslateAsmOperand(PI, Op2))
    Else
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { Si on arrive ici, emettre tel quel (instruction non reconnue) }
  If Length(Op2) > 0 Then
    EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2))
  Else If Length(Op1) > 0 Then
    EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1))
  Else
    EmitInstr(Up);
End;

{ ------------------------------------------------------------ }
{ ParseAsmBlock : parser un bloc ASM...END et traduire chaque   }
{ ligne d assembleur 8086 en assembleur 80386 Win32.            }
{ Syntaxe Turbo Pascal : ASM instruction; instruction; ... END  }
{ Dans le TokenPool, chaque token est un mot ; on reconstruit   }
{ les lignes d assembleur et on les traduit.                    }
{ ------------------------------------------------------------ }

Procedure ParseAsmBlock(PI : Integer);
Var
  AsmLine : TString;
  Up      : TString;
  T       : TString;
Begin
  EmitComment('--- Debut bloc ASM (TODO 17) ---');

  { Consommer le mot-cle ASM }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (StrUpperCase(TokenPool[EP].Val) = 'ASM') Then
    Inc(EP);

  { Traiter les tokens jusqu au END correspondant }
  While Not EPAtEnd Do
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END termine le bloc ASM }
    If (TokenPool[EP].Kind = TK_KEYWORD) And (Up = 'END') Then
    Begin
      Inc(EP);
      { Consommer ; ou . optionnel apres END }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         ((TokenPool[EP].Val = ';') Or (TokenPool[EP].Val = '.')) Then
        Inc(EP);
      Break;
    End;

    { Point-virgule seul : separateur d instructions, ignorer }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
    Begin
      Inc(EP);
      Continue;
    End;

    { Construire une ligne ASM a partir des tokens }
    { Une instruction ASM va jusqu au prochain ; ou END }
    AsmLine := '';
    While Not EPAtEnd Do
    Begin
      { Arreter au ; ou END }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
        Break;
      If (TokenPool[EP].Kind = TK_KEYWORD) And
         (StrUpperCase(TokenPool[EP].Val) = 'END') Then
        Break;

      { Verifier si le token suivant est ':' (c est un label ASM) }
      T := TokenPool[EP].Val;
      Inc(EP);

      { Si le prochain token est ':', c est un label }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
      Begin
        { Emettre le label }
        EmitLabel(T);
        Inc(EP); { consommer ':' }
        Continue;
      End;

      { Ajouter au tampon de la ligne }
      If Length(AsmLine) > 0 Then
        AsmLine := AsmLine + ' ';
      AsmLine := AsmLine + T;
    End;

    { Traduire et emettre la ligne ASM }
    AsmLine := AsmTrimSpaces(AsmLine);
    If Length(AsmLine) > 0 Then
      TranslateAsmLine(PI, AsmLine);
  End;

  EmitComment('--- Fin bloc ASM ---');
End;

{ ------------------------------------------------------------ }
{ EmitMainBlock : emettre le bloc principal du programme        }
{ (le BEGIN..END. final)                                        }
{ ------------------------------------------------------------ }

Procedure EmitMainBlock;
Var
  I    : Integer;
  Up   : TString;
  Depth: Integer;
Begin
  { Chercher le dernier BEGIN au niveau global = bloc principal }
  I := TokenCount - 1;
  While I >= 0 Do
  Begin
    If (TokenPool[I].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[I].Val) = 'END') Then
    Begin
      { Remonter pour trouver le BEGIN correspondant }
      Depth := 1;
      Dec(I);
      While (I >= 0) And (Depth > 0) Do
      Begin
        If TokenPool[I].Kind = TK_KEYWORD Then
        Begin
          Up := StrUpperCase(TokenPool[I].Val);
          If Up = 'END' Then
            Inc(Depth)
          Else If (Up = 'BEGIN') Or (Up = 'CASE') Or (Up = 'RECORD') Or
                  (Up = 'ASM') Then
            Dec(Depth);
        End;
        If Depth > 0 Then Dec(I);
      End;
      If Depth = 0 Then Break;
    End;
    Dec(I);
  End;

  { Si on a trouve le bloc principal, emettre _TPF_Main }
  If (I >= 0) And (TokenPool[I].Kind = TK_KEYWORD) And
     (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
  Begin
    HasProgram := True;
    EmitBlankLine;
    EmitComment('--- Programme principal ---');
    EmitLabel(TP_FUNC_PFX + 'Main');

    If (Opts.DestTarget = DEST_DOSR) Or (Opts.DestTarget = DEST_DOSP) Then
    Begin
      { Mode DOS 16 bits : initialiser DS et ES }
      EmitComment('Initialiser DS et ES pour DOS 16 bits');
      EmitInstr('MOV AX,0');   { placeholder, fixup segment data }
      EmitInstr('MOV DS,AX');
      EmitInstr('MOV ES,AX');
    End
    Else
    Begin
      EmitProlog(0);

      { Initialiser les handles Win32 }
      EmitComment('Obtenir STDOUT');
      EmitInstr('PUSH -11');
      EmitInstr('CALL GetStdHandle');
      EmitInstr('MOV [HSTDOUT],EAX');
      EmitComment('Obtenir STDIN');
      EmitInstr('PUSH -10');
      EmitInstr('CALL GetStdHandle');
      EmitInstr('MOV [HSTDIN],EAX');
      EmitComment('Obtenir le tas du processus');
      EmitInstr('CALL GetProcessHeap');
      EmitInstr('MOV [HHEAP],EAX');
    End;

    { Parser et emettre le corps du programme }
    RetLbl := LabelGen;
    EP := I;      { I pointe sur le BEGIN }
    EPEnd := TokenCount;
    CurProcIdx := -1;
    ParseBody(-1);
    EmitLabel(RetLbl);

    If (Opts.DestTarget = DEST_DOSR) Or (Opts.DestTarget = DEST_DOSP) Then
    Begin
      { Sortie DOS via INT 21h }
      EmitInstr('MOV AX,4C00H');
      EmitInstr('INT 21H');
    End
    Else
    Begin
      { Sortie propre Win32 }
      EmitInstr('PUSH 0');
      EmitInstr('CALL ExitProcess');
      EmitEpilog;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRuntime : emettre les routines runtime internes du        }
{ compilateur dans le segment .CODE.                           }
{ _TPRT_PRINTSTR : afficher chaine ASCIIZ (ESI = pointeur)    }
{ _TPRT_NUMTOSTR : convertir EAX en chaine NUMBUF             }
{ _TPRT_STRTONUM : convertir chaine ASCIIZ (ESI) en EAX       }
{ _TPRT_READLN   : lire une ligne de STDIN dans INBUF         }
{ _TPRT_STRASSIGN: affecter String Pascal (ASCIIZ -> Pascal) }
{ _TPRT_STRASSIGN_PCHAR: copier ASCIIZ brut (ESI -> EDI)      }
{ _TPRT_STRCPY   : StrCopy PChar ASCIIZ (Dest,Src) -> Dest    }
{ _TPRT_LENGTH   : longueur String Pascal S[0] -> EAX         }
{ _TPRT_STRLEN   : longueur ASCIIZ PChar (ESI) -> EAX         }
{ _TPRT_CONCAT   : concatener EDI apres ESI      (TODO 16)   }
{ _TPRT_STRCOMPARE: comparer String Pascal ESI/EDI -> EAX     }
{ _TPRT_STRCMP    : StrComp PChar ASCIIZ ESI/EDI -> EAX       }
{ _TPRT_COPY     : sous-chaine -> STRBUF1        (TODO 16)   }
{ _TPRT_POS      : position sous-chaine -> EAX   (TODO 16)   }
{ _TPRT_DELETE    : supprimer in-place            (TODO 16)   }
{ _TPRT_INSERT    : inserer via STRBUF2           (TODO 16)   }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeDOS;
{ Runtime DOS 16 bits utilisant INT 21h au lieu des API Win32. }
{ Les registres sont en 16 bits : SI au lieu de ESI, AX de EAX, etc. }
Begin
  EmitBlankLine;
  EmitComment('=== Routines runtime TPCW32 - DOS 16 bits ===');

  { ------ _TPRT_PRINTSTR : afficher chaine ASCIIZ (SI = ptr) ----- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSH AX');
  EmitInstr('PUSH DX');
  EmitInstr('PUSH SI');
  EmitLabel(TP_RT_PFX + 'PSTR_L');
  EmitInstr('LODSB');                    { AL = [DS:SI], SI++ }
  EmitInstr('CMP AL,0');
  EmitInstr('JE ' + TP_RT_PFX + 'PSTR_D');
  EmitInstr('MOV DL,AL');
  EmitInstr('MOV AH,2');               { DOS: afficher caractere }
  EmitInstr('INT 21H');
  EmitInstr('JMP ' + TP_RT_PFX + 'PSTR_L');
  EmitLabel(TP_RT_PFX + 'PSTR_D');
  EmitInstr('POP SI');
  EmitInstr('POP DX');
  EmitInstr('POP AX');
  EmitInstr('RET');

  { ------ _TPRT_NUMTOSTR : AX -> NUMBUF (ASCIIZ decimal) -------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSH AX');
  EmitInstr('PUSH BX');
  EmitInstr('PUSH CX');
  EmitInstr('PUSH DX');
  EmitInstr('PUSH DI');
  EmitInstr('LEA DI,[NUMBUF]');
  EmitInstr('XOR CX,CX');              { compteur de chiffres }
  EmitInstr('CMP AX,0');
  EmitInstr('JGE ' + TP_RT_PFX + 'NTS_POS');
  { Nombre negatif }
  EmitInstr('MOV BYTE PTR [NUMBUF],45'); { '-' utiliser label direct }
  EmitInstr('INC DI');
  EmitInstr('NEG AX');
  EmitLabel(TP_RT_PFX + 'NTS_POS');
  EmitInstr('MOV BX,10');
  EmitLabel(TP_RT_PFX + 'NTS_DIV');
  EmitInstr('XOR DX,DX');
  EmitInstr('DIV BX');                  { AX=quotient, DX=reste }
  EmitInstr('ADD DL,48');               { '0' }
  EmitInstr('PUSH DX');
  EmitInstr('INC CX');
  EmitInstr('CMP AX,0');
  EmitInstr('JNE ' + TP_RT_PFX + 'NTS_DIV');
  EmitLabel(TP_RT_PFX + 'NTS_POP');
  EmitInstr('POP AX');
  EmitInstr('STOSB');                   { [DI] = AL, DI++ }
  EmitInstr('DEC CX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'NTS_POP');
  EmitInstr('MOV AL,0');
  EmitInstr('STOSB');                   { terminateur NUL }
  EmitInstr('POP DI');
  EmitInstr('POP DX');
  EmitInstr('POP CX');
  EmitInstr('POP BX');
  EmitInstr('POP AX');
  EmitInstr('RET');

  { ------ _TPRT_READLN : lire ligne STDIN -> INBUF (ASCIIZ) ----- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'READLN');
  EmitInstr('PUSH AX');
  EmitInstr('PUSH DI');
  EmitInstr('LEA DI,[INBUF]');
  EmitLabel(TP_RT_PFX + 'RL_LP');
  EmitInstr('MOV AH,1');               { DOS: lire caractere avec echo }
  EmitInstr('INT 21H');
  EmitInstr('CMP AL,13');              { CR ? }
  EmitInstr('JE ' + TP_RT_PFX + 'RL_DN');
  EmitInstr('CMP AL,10');              { LF ? }
  EmitInstr('JE ' + TP_RT_PFX + 'RL_DN');
  EmitInstr('STOSB');                  { [DI] = AL, DI++ }
  EmitInstr('JMP ' + TP_RT_PFX + 'RL_LP');
  EmitLabel(TP_RT_PFX + 'RL_DN');
  EmitInstr('MOV AL,0');
  EmitInstr('STOSB');                  { terminateur NUL }
  EmitInstr('POP DI');
  EmitInstr('POP AX');
  EmitInstr('RET');

  { ------ _TPRT_STRTONUM : SI -> AX (conversion decimale) ------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRTONUM');
  EmitInstr('PUSH BX');
  EmitInstr('PUSH CX');
  EmitInstr('PUSH DX');
  EmitInstr('XOR AX,AX');
  EmitInstr('XOR CX,CX');              { flag signe }
  EmitInstr('CMP BYTE PTR [INBUF],45'); { '-' }
  EmitInstr('JNE ' + TP_RT_PFX + 'STN_LP');
  EmitInstr('INC SI');
  EmitInstr('INC CX');
  EmitLabel(TP_RT_PFX + 'STN_LP');
  EmitInstr('LODSB');
  EmitInstr('CMP AL,48');              { '0' }
  EmitInstr('JB ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP AL,57');              { '9' }
  EmitInstr('JA ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('SUB AL,48');
  EmitInstr('MOV BX,AX');             { sauver chiffre }
  EmitInstr('POP DX');                 { temp: recup AX partiel }
  EmitInstr('PUSH DX');
  { Simplification: multiplication par 10 via shifts+adds }
  { AX = result * 10 + digit, on utilise une approche simple }
  { Pour l instant, ignorer silencieusement les grands nombres }
  EmitInstr('JMP ' + TP_RT_PFX + 'STN_LP');
  EmitLabel(TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP CX,0');
  EmitInstr('JE ' + TP_RT_PFX + 'STN_RT');
  EmitInstr('NEG AX');
  EmitLabel(TP_RT_PFX + 'STN_RT');
  EmitInstr('POP DX');
  EmitInstr('POP CX');
  EmitInstr('POP BX');
  EmitInstr('RET');

  { ------ _TPRT_STRASSIGN : ASCIIZ -> Pascal String (stub) ------ }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRASSIGN');
  EmitInstr('RET');

  { ------ _TPRT_STRASSIGN_PCHAR : copie ASCIIZ (stub) ----------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRASSIGN_PCHAR');
  EmitInstr('RET');

  { ------ Stubs pour les autres routines runtime ------------------ }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PADPRINT');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'STRCPY');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'LENGTH');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'STRLEN');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'CONCAT');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'STRCOMPARE');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'STRCMP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'COPY');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'POS');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'DELETE');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'INSERT');
  EmitInstr('RET');
End;

Procedure EmitRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Routines runtime TPCW32 ===');

  { ------ _TPRT_PRINTSTR : afficher chaine ASCIIZ ---------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ                }
  { Utilise : WriteFile(HSTDOUT, ESI, len, &BYTESWR, 0)       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSHAD');
  { Calculer la longueur de la chaine }
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'PSTR_L');
  EmitInstr('CMP BYTE PTR [ESI+ECX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PSTR_G');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'PSTR_L');
  EmitLabel(TP_RT_PFX + 'PSTR_G');
  { ECX = longueur, ESI = debut de la chaine }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'PSTR_D');
  { Appeler WriteFile(HSTDOUT, ESI, ECX, &BYTESWR, 0) }
  EmitInstr('PUSH 0');                     { lpOverlapped         }
  EmitInstr('PUSH OFFSET BYTESWR');        { lpNumberOfBytesWritten }
  EmitInstr('PUSH ECX');                   { nNumberOfBytesToWrite }
  EmitInstr('PUSH ESI');                   { lpBuffer             }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');   { hFile                }
  EmitInstr('CALL WriteFile');
  EmitLabel(TP_RT_PFX + 'PSTR_D');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_PADPRINT : afficher avec padding ------------ }
  { Entree : ESI = pointeur vers chaine ASCIIZ                }
  {          ECX = largeur souhaitee (field width)             }
  { Affiche (width - strlen) espaces, puis la chaine          }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PADPRINT');
  EmitInstr('PUSHAD');
  { Compter la longueur de la chaine }
  EmitInstr('XOR EDX,EDX');            { EDX = strlen }
  EmitInstr('MOV EBX,ESI');            { sauver pointeur chaine }
  EmitLabel(TP_RT_PFX + 'PAD_C');
  EmitInstr('CMP BYTE PTR [ESI+EDX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PAD_P');
  EmitInstr('INC EDX');
  EmitInstr('JMP ' + TP_RT_PFX + 'PAD_C');
  EmitLabel(TP_RT_PFX + 'PAD_P');
  { EDX = strlen, ECX = width }
  EmitInstr('SUB ECX,EDX');            { ECX = nombre d espaces }
  EmitInstr('JLE ' + TP_RT_PFX + 'PAD_S');
  { Afficher ECX espaces }
  EmitLabel(TP_RT_PFX + 'PAD_L');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV BYTE PTR [STRTMP],32'); { espace }
  EmitInstr('MOV BYTE PTR [STRTMP+1],0');
  EmitInstr('LEA ESI,[STRTMP]');
  EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  EmitInstr('POP EBX');
  EmitInstr('POP ECX');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'PAD_L');
  EmitLabel(TP_RT_PFX + 'PAD_S');
  { Afficher la chaine originale }
  EmitInstr('MOV ESI,EBX');
  EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_NUMTOSTR : EAX -> NUMBUF (ASCIIZ) ---------- }
  { Entree : EAX = entier signe 32 bits                       }
  { Sortie : NUMBUF contient la representation decimale        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[NUMBUF]');
  EmitInstr('XOR ECX,ECX');        { compteur de chiffres }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JGE ' + TP_RT_PFX + 'NTS_POS');
  { Nombre negatif : stocker '-' et inverser }
  EmitInstr('MOV BYTE PTR [EDI],45'); { '-' }
  EmitInstr('INC EDI');
  EmitInstr('NEG EAX');
  EmitLabel(TP_RT_PFX + 'NTS_POS');
  EmitInstr('MOV EBX,10');
  EmitLabel(TP_RT_PFX + 'NTS_DIV');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');            { EAX=quotient, EDX=reste }
  EmitInstr('ADD DL,48');          { '0' }
  EmitInstr('PUSH EDX');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'NTS_DIV');
  EmitLabel(TP_RT_PFX + 'NTS_POP');
  EmitInstr('POP EAX');
  EmitInstr('MOV [EDI],AL');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'NTS_POP');
  EmitInstr('MOV BYTE PTR [EDI],0'); { terminateur NUL }
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRTONUM : ESI -> EAX (entier) ------------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ decimale        }
  { Sortie : EAX = valeur entiere                              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRTONUM');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('XOR ECX,ECX');        { flag signe }
  EmitInstr('CMP BYTE PTR [ESI],45'); { '-' }
  EmitInstr('JNE ' + TP_RT_PFX + 'STN_LP');
  EmitInstr('INC ESI');
  EmitInstr('INC ECX');
  EmitLabel(TP_RT_PFX + 'STN_LP');
  EmitInstr('MOVZX EDX,BYTE PTR [ESI]');
  EmitInstr('TEST DL,DL');
  EmitInstr('JZ ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP DL,48'); { '0' }
  EmitInstr('JB ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP DL,57'); { '9' }
  EmitInstr('JA ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('SUB DL,48');
  EmitInstr('IMUL EAX,EAX,10');
  EmitInstr('ADD EAX,EDX');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'STN_LP');
  EmitLabel(TP_RT_PFX + 'STN_DN');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'STN_RT');
  EmitInstr('NEG EAX');
  EmitLabel(TP_RT_PFX + 'STN_RT');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_READLN : lire une ligne de STDIN ----------- }
  { Sortie : INBUF contient la ligne lue, terminee par NUL    }
  { BYTESRD = nombre d octets lus                              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'READLN');
  EmitInstr('PUSHAD');
  { ReadFile(HSTDIN, INBUF, 255, &BYTESRD, 0) }
  EmitInstr('PUSH 0');                     { lpOverlapped         }
  EmitInstr('PUSH OFFSET BYTESRD');        { lpNumberOfBytesRead  }
  EmitInstr('PUSH 255');                   { nNumberOfBytesToRead  }
  EmitInstr('PUSH OFFSET INBUF');          { lpBuffer             }
  EmitInstr('PUSH DWORD PTR [HSTDIN]');    { hFile                }
  EmitInstr('CALL ReadFile');
  { Verifier EOF stdin (0 octets lus ou Ctrl+Z) }
  EmitInstr('MOV ECX,DWORD PTR [BYTESRD]');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'RL_OK');
  EmitInstr('MOV DWORD PTR [STDIN_EOF],1');
  EmitInstr('JMP ' + TP_RT_PFX + 'RL_DN');
  EmitLabel(TP_RT_PFX + 'RL_OK');
  { Retirer CR/LF de fin et terminer par NUL }
  EmitLabel(TP_RT_PFX + 'RL_TR');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'RL_DN');
  EmitInstr('DEC ECX');
  EmitInstr('LEA EDI,[INBUF]');
  EmitInstr('ADD EDI,ECX');
  EmitInstr('CMP BYTE PTR [EDI],13');
  EmitInstr('JE ' + TP_RT_PFX + 'RL_TR');
  EmitInstr('CMP BYTE PTR [EDI],10');
  EmitInstr('JE ' + TP_RT_PFX + 'RL_TR');
  EmitInstr('INC ECX');
  EmitLabel(TP_RT_PFX + 'RL_DN');
  EmitInstr('LEA EDI,[INBUF]');
  EmitInstr('ADD EDI,ECX');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRASSIGN : affecter String Pascal ---------- }
  { Entree : ESI = source ASCIIZ, EDI = destination String      }
  { Convertit ASCIIZ en format Pascal : EDI[0]=len, EDI[1..]=chars, +NUL }
  { Utilise pour l affectation String := expr                   }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRASSIGN');
  EmitInstr('PUSHAD');
  { D abord, compter la longueur de la source ASCIIZ }
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV EBX,ESI');           { sauver debut source }
  EmitLabel(TP_RT_PFX + 'SASG_C');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'SASG_D');
  EmitInstr('INC ECX');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'SASG_C');
  EmitLabel(TP_RT_PFX + 'SASG_D');
  { ECX = longueur, tronquer a 255 max }
  EmitInstr('CMP ECX,255');
  EmitInstr('JLE ' + TP_RT_PFX + 'SASG_OK');
  EmitInstr('MOV ECX,255');
  EmitLabel(TP_RT_PFX + 'SASG_OK');
  { Stocker longueur dans EDI[0] }
  EmitInstr('MOV BYTE PTR [EDI],CL');
  EmitInstr('INC EDI');               { avancer apres l octet de longueur }
  { Copier ECX caracteres de EBX vers EDI }
  EmitInstr('MOV ESI,EBX');           { restaurer source }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SASG_N');
  EmitLabel(TP_RT_PFX + 'SASG_L');
  EmitInstr('MOVSB');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SASG_L');
  EmitLabel(TP_RT_PFX + 'SASG_N');
  { Ajouter NUL terminal pour compatibilite }
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRASSIGN_PCHAR : copier ASCIIZ brut -------- }
  { Entree : ESI = source ASCIIZ, EDI = destination ASCIIZ     }
  { Copie simple byte par byte (pour buffers internes)         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRASSIGN_PCHAR');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'SPCA_L');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SPCA_L');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_STRCPY : StrCopy PChar ASCIIZ --------------- }
  { Entree : ESI = source ASCIIZ, EDI = destination ASCIIZ     }
  { Correspond a StrCopy(Dest, Source) de l unite Strings       }
  { Retourne : EAX = EDI (pointeur destination)                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCPY');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'SCPY_L');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SCPY_L');
  EmitInstr('POP EAX');           { EAX = Dest original }
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ============================================================ }
  { TODO 16 - ROUTINES RUNTIME CHAINES           [IMPLEMENTE]    }
  { ============================================================ }

  { ------ _TPRT_LENGTH : longueur String Pascal (S[0]) ------ }
  { Entree : ESI = pointeur vers String Pascal (S[0]=longueur) }
  { Sortie : EAX = longueur (valeur de S[0])                   }
  { Correspond a la fonction Length() de Turbo Pascal           }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LENGTH');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('RET');

  { ------ _TPRT_STRLEN : longueur PChar ASCIIZ -------------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ (PChar)         }
  { Sortie : EAX = longueur (nombre de caracteres avant NUL)   }
  { Correspond a la fonction StrLen() de l unite Strings        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLEN');
  EmitInstr('PUSH ESI');
  EmitInstr('XOR EAX,EAX');
  EmitLabel(TP_RT_PFX + 'SLN_L');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'SLN_D');
  EmitInstr('INC EAX');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'SLN_L');
  EmitLabel(TP_RT_PFX + 'SLN_D');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_CONCAT : concatener ESI + EDI -> ESI -------- }
  { Entree : ESI = destination (ASCIIZ, deja remplie)           }
  {          EDI = source a ajouter (ASCIIZ)                    }
  { Resultat : ESI est etendu avec EDI a la fin                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CONCAT');
  EmitInstr('PUSHAD');
  { Trouver la fin de ESI }
  EmitLabel(TP_RT_PFX + 'CAT_F');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CAT_C');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'CAT_F');
  EmitLabel(TP_RT_PFX + 'CAT_C');
  { Copier EDI a la fin }
  EmitLabel(TP_RT_PFX + 'CAT_L');
  EmitInstr('MOV AL,BYTE PTR [EDI]');
  EmitInstr('MOV BYTE PTR [ESI],AL');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'CAT_D');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'CAT_L');
  EmitLabel(TP_RT_PFX + 'CAT_D');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRCOMPARE : comparer String Pascal ESI/EDI -- }
  { Entree : ESI = chaine 1, EDI = chaine 2 (ASCIIZ)          }
  { Sortie : EAX = <0 si s1<s2, 0 si s1=s2, >0 si s1>s2      }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCOMPARE');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'SCMP_L');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('MOVZX ECX,BYTE PTR [EDI]');
  EmitInstr('SUB EAX,ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SCMP_D');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SCMP_D');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'SCMP_L');
  EmitLabel(TP_RT_PFX + 'SCMP_D');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_STRCMP : StrComp PChar ASCIIZ ESI/EDI -------- }
  { Entree : ESI = PChar 1, EDI = PChar 2 (ASCIIZ)            }
  { Sortie : EAX = <0 si s1<s2, 0 si s1=s2, >0 si s1>s2      }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCMP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'PCMP_L');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('MOVZX ECX,BYTE PTR [EDI]');
  EmitInstr('SUB EAX,ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'PCMP_D');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'PCMP_D');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PCMP_L');
  EmitLabel(TP_RT_PFX + 'PCMP_D');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_COPY : Copy(S, Pos, Len) -------------------- }
  { Entree : ESI = source ASCIIZ, EBX = position (1-based),    }
  {          ECX = longueur a copier                            }
  { Sortie : EAX = pointeur vers STRBUF1 (resultat ASCIIZ)    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'COPY');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[STRBUF1]');
  { Avancer ESI de (Pos-1) caracteres }
  EmitInstr('DEC EBX');
  EmitInstr('TEST EBX,EBX');
  EmitInstr('JLE ' + TP_RT_PFX + 'CPY_C');
  EmitLabel(TP_RT_PFX + 'CPY_S');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CPY_E');
  EmitInstr('INC ESI');
  EmitInstr('DEC EBX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'CPY_S');
  EmitLabel(TP_RT_PFX + 'CPY_C');
  { Copier ECX caracteres }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JLE ' + TP_RT_PFX + 'CPY_E');
  EmitLabel(TP_RT_PFX + 'CPY_L');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CPY_E');
  EmitInstr('MOVSB');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'CPY_L');
  EmitLabel(TP_RT_PFX + 'CPY_E');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('POPAD');
  EmitInstr('LEA EAX,[STRBUF1]');
  EmitInstr('RET');

  { ------ _TPRT_POS : Pos(SubStr, S) -> EAX ----------------- }
  { Entree : EDI = sous-chaine (ASCIIZ), ESI = chaine (ASCIIZ) }
  { Sortie : EAX = position 1-based, ou 0 si non trouve        }
  { Note : utilise MOVZX+CMP reg32 car BcAssemble ne supporte  }
  {        pas CMP reg8,[mem] (silencieusement ignore)          }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'POS');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EBX,ESI');        { EBX = debut original de S }
  { ESI = position courante dans S (boucle externe)            }
  { EDI = debut du pattern (inchange)                          }
  EmitLabel(TP_RT_PFX + 'POS_O');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'POS_N'); { fin de S = pas trouve }
  { Essayer de matcher le pattern a la position ESI }
  EmitInstr('MOV EAX,ESI');        { EAX = curseur interne S }
  EmitInstr('MOV ECX,EDI');        { ECX = curseur interne pattern }
  EmitLabel(TP_RT_PFX + 'POS_M');
  EmitInstr('MOVZX EDX,BYTE PTR [ECX]');  { char pattern -> EDX }
  EmitInstr('TEST EDX,EDX');
  EmitInstr('JZ ' + TP_RT_PFX + 'POS_F'); { fin du pattern = trouve }
  EmitInstr('PUSH ECX');           { sauvegarder curseur pattern }
  EmitInstr('MOVZX ECX,BYTE PTR [EAX]');  { char S -> ECX }
  EmitInstr('CMP EDX,ECX');        { comparer reg32,reg32 (supporte) }
  EmitInstr('POP ECX');            { restaurer curseur (flags preserves) }
  EmitInstr('JNE ' + TP_RT_PFX + 'POS_X'); { mismatch }
  EmitInstr('INC EAX');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_M');
  EmitLabel(TP_RT_PFX + 'POS_F');
  { Trouve ! Position = ESI - EBX + 1 }
  EmitInstr('MOV EAX,ESI');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('INC EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_D');
  EmitLabel(TP_RT_PFX + 'POS_X');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_O');
  EmitLabel(TP_RT_PFX + 'POS_N');
  EmitInstr('XOR EAX,EAX');        { pas trouve }
  EmitLabel(TP_RT_PFX + 'POS_D');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_DELETE : Delete(S, Pos, Len) in-place -------- }
  { Entree : ESI = pointeur buffer ASCIIZ                       }
  {          EBX = position (1-based), ECX = nombre a supprimer }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DELETE');
  EmitInstr('PUSHAD');
  EmitInstr('DEC EBX');
  { EDI = debut zone a supprimer, ESI = debut zone apres }
  EmitInstr('MOV EDI,ESI');
  EmitInstr('ADD EDI,EBX');
  EmitInstr('ADD ESI,EBX');
  EmitInstr('ADD ESI,ECX');
  EmitLabel(TP_RT_PFX + 'DEL_L');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'DEL_L');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_INSERT : Insert(Src, Dst, Pos) -------------- }
  { Entree : ESI = source ASCIIZ a inserer                     }
  {          EDI = destination buffer ASCIIZ                     }
  {          EBX = position d insertion (1-based)               }
  { Utilise STRBUF2 comme buffer temporaire                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INSERT');
  EmitInstr('PUSHAD');
  EmitInstr('DEC EBX');
  { Copier destination dans STRBUF2 }
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,EDI');
  EmitInstr('LEA EDI,[STRBUF2]');
  EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN_PCHAR');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  { EDI = debut du buffer destination }
  { Copier les EBX premiers caracteres de STRBUF2 dans EDI }
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EBX');
  EmitInstr('LEA ESI,[STRBUF2]');
  EmitInstr('MOV ECX,EBX');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'INS_P2');
  EmitLabel(TP_RT_PFX + 'INS_P1');
  EmitInstr('MOVSB');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'INS_P1');
  EmitLabel(TP_RT_PFX + 'INS_P2');
  { Copier la source (ESI original) dans EDI }
  EmitInstr('POP EBX');
  EmitInstr('POP ESI');
  EmitLabel(TP_RT_PFX + 'INS_S1');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'INS_S2');
  EmitInstr('MOVSB');
  EmitInstr('JMP ' + TP_RT_PFX + 'INS_S1');
  EmitLabel(TP_RT_PFX + 'INS_S2');
  { Copier le reste de STRBUF2 a partir de la position EBX }
  EmitInstr('LEA ESI,[STRBUF2]');
  EmitInstr('ADD ESI,EBX');
  EmitLabel(TP_RT_PFX + 'INS_R1');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'INS_R1');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ============================================================ }
  { TODO 18 - ROUTINES RUNTIME CRT               [IMPLEMENTE]    }
  { ============================================================ }

  { ------ _TPRT_CLRSCR : effacer l ecran console --------------- }
  { Utilise FillConsoleOutputCharacterA pour remplir de ' '        }
  { puis SetConsoleCursorPosition pour positionner en (0,0)        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CLRSCR');
  EmitInstr('PUSHAD');
  { Obtenir les informations du buffer console }
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  { Calculer la taille totale : colonnes * lignes }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+0]');  { dwSize.X (colonnes) }
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+2]');  { dwSize.Y (lignes)   }
  EmitInstr('IMUL EAX,ECX');                       { EAX = total cells   }
  { FillConsoleOutputCharacterA(hOut, ' ', count, 0, &written) }
  EmitInstr('PUSH OFFSET CRT_NWRT');
  EmitInstr('PUSH 0');                             { dwWriteCoord = (0,0) }
  EmitInstr('PUSH EAX');                           { nLength              }
  EmitInstr('PUSH 32');                            { cCharacter = ' '     }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL FillConsoleOutputCharacterA');
  { FillConsoleOutputAttribute(hOut, attr, count, 0, &written) }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+0]');
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+2]');
  EmitInstr('IMUL EAX,ECX');
  EmitInstr('PUSH OFFSET CRT_NWRT');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [TEXTATTR]');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL FillConsoleOutputAttribute');
  { SetConsoleCursorPosition(hOut, (0,0)) }
  EmitInstr('PUSH 0');                             { COORD (0,0) packed   }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleCursorPosition');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_CLREOL : effacer de curseur a fin de ligne ----- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CLREOL');
  EmitInstr('PUSHAD');
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  { Nombre de cellules a effacer = colonnes - cursor.X }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+0]');   { dwSize.X           }
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+4]');   { dwCursorPosition.X }
  EmitInstr('SUB EAX,ECX');
  { Coordonnee du curseur actuel (packed COORD) }
  EmitInstr('MOVZX EDX,WORD PTR [CRT_CSBI+6]');   { dwCursorPosition.Y }
  EmitInstr('SHL EDX,16');
  EmitInstr('OR EDX,ECX');                          { EDX = packed COORD }
  EmitInstr('PUSH OFFSET CRT_NWRT');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH 32');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL FillConsoleOutputCharacterA');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_GOTOXY : positionner curseur ------------------- }
  { Parametres sur pile : [ESP+4] = X (1-based), [ESP+8] = Y       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GOTOXY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH EDX');
  { X = [EBP+8] (1-based -> 0-based), Y = [EBP+12] }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');         { X }
  EmitInstr('DEC EAX');                             { 0-based }
  EmitInstr('AND EAX,0FFFFh');
  EmitInstr('MOV EDX,DWORD PTR [EBP+12]');        { Y }
  EmitInstr('DEC EDX');                             { 0-based }
  EmitInstr('SHL EDX,16');
  EmitInstr('OR EAX,EDX');                          { packed COORD }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleCursorPosition');
  EmitInstr('POP EDX');
  EmitInstr('POP EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_WHEREX : colonne courante -> EAX --------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'WHEREX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+4]');   { dwCursorPosition.X }
  EmitInstr('INC EAX');                             { 1-based }
  EmitInstr('POP ECX');
  EmitInstr('RET');

  { ------ _TPRT_WHEREY : ligne courante -> EAX ----------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'WHEREY');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+6]');   { dwCursorPosition.Y }
  EmitInstr('INC EAX');                             { 1-based }
  EmitInstr('POP ECX');
  EmitInstr('RET');

  { ------ _TPRT_TEXTCOLOR : couleur texte ---------------------- }
  { Parametre sur pile : [ESP+4] = couleur (0..15)                 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'TEXTCOLOR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EAX');
  { TEXTATTR = (TEXTATTR AND F0h) OR (color AND 0Fh) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EDX,DWORD PTR [TEXTATTR]');
  EmitInstr('AND EDX,0F0h');
  EmitInstr('OR EAX,EDX');
  EmitInstr('MOV DWORD PTR [TEXTATTR],EAX');
  { SetConsoleTextAttribute(hOut, attr) }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  EmitInstr('POP EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_TEXTBG : couleur de fond ----------------------- }
  { Parametre sur pile : [ESP+4] = couleur (0..7)                  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'TEXTBG');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EAX');
  { TEXTATTR = (TEXTATTR AND 0Fh) OR ((color AND 07h) SHL 4) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('AND EAX,07h');
  EmitInstr('SHL EAX,4');
  EmitInstr('MOV EDX,DWORD PTR [TEXTATTR]');
  EmitInstr('AND EDX,0Fh');
  EmitInstr('OR EAX,EDX');
  EmitInstr('MOV DWORD PTR [TEXTATTR],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  EmitInstr('POP EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_HIGHVIDEO : attribut haute intensite ------------ }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'HIGHVIDEO');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,DWORD PTR [TEXTATTR]');
  EmitInstr('OR EAX,08h');                         { bit intensite }
  EmitInstr('MOV DWORD PTR [TEXTATTR],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  EmitInstr('POP EAX');
  EmitInstr('RET');

  { ------ _TPRT_LOWVIDEO : attribut basse intensite ------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LOWVIDEO');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,DWORD PTR [TEXTATTR]');
  EmitInstr('AND EAX,0F7h');                       { enlever bit intensite }
  EmitInstr('MOV DWORD PTR [TEXTATTR],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  EmitInstr('POP EAX');
  EmitInstr('RET');

  { ------ _TPRT_NORMVIDEO : attribut normal --------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'NORMVIDEO');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,7');                          { gris sur noir }
  EmitInstr('MOV DWORD PTR [TEXTATTR],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  EmitInstr('POP EAX');
  EmitInstr('RET');

  { ------ _TPRT_WINDOW : definir zone de texte ------------------ }
  { Params : [ESP+4]=X1, [ESP+8]=Y1, [ESP+12]=X2, [ESP+16]=Y2    }
  { Stocke dans WINDMIN/WINDMAX                                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'WINDOW');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH EDX');
  { WINDMIN = (Y1-1)*256 + (X1-1) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');        { Y1 }
  EmitInstr('DEC EAX');
  EmitInstr('SHL EAX,8');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');         { X1 }
  EmitInstr('DEC EDX');
  EmitInstr('OR EAX,EDX');
  EmitInstr('MOV DWORD PTR [WINDMIN],EAX');
  { WINDMAX = (Y2-1)*256 + (X2-1) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+20]');        { Y2 }
  EmitInstr('DEC EAX');
  EmitInstr('SHL EAX,8');
  EmitInstr('MOV EDX,DWORD PTR [EBP+16]');        { X2 }
  EmitInstr('DEC EDX');
  EmitInstr('OR EAX,EDX');
  EmitInstr('MOV DWORD PTR [WINDMAX],EAX');
  EmitInstr('POP EDX');
  EmitInstr('POP EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_KEYPRESSED : touche disponible -> EAX ---------- }
  { Retourne 1 (True) si une touche est disponible, 0 sinon       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'KEYPRESSED');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  { GetNumberOfConsoleInputEvents(hStdin, &count) }
  EmitInstr('PUSH OFFSET CRT_NEVT');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL GetNumberOfConsoleInputEvents');
  EmitInstr('MOV EAX,DWORD PTR [CRT_NEVT]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'KP_NO');
  { PeekConsoleInputA(hStdin, &rec, 1, &count) }
  EmitInstr('PUSH OFFSET CRT_NEVT');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET CRT_INREC');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL PeekConsoleInputA');
  { Verifier si c est un evenement clavier (EventType == 1) }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_INREC]');
  EmitInstr('CMP EAX,1');
  EmitInstr('JNE ' + TP_RT_PFX + 'KP_FL');
  { Verifier bKeyDown (offset 4 dans INPUT_RECORD) }
  EmitInstr('MOV EAX,DWORD PTR [CRT_INREC+4]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'KP_FL');
  EmitInstr('MOV EAX,1');
  EmitInstr('JMP ' + TP_RT_PFX + 'KP_DN');
  EmitLabel(TP_RT_PFX + 'KP_FL');
  { Pas un key event ou key up - flush et retourner 0 }
  EmitInstr('PUSH OFFSET CRT_NEVT');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET CRT_INREC');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL ReadConsoleInputA');
  EmitLabel(TP_RT_PFX + 'KP_NO');
  EmitInstr('XOR EAX,EAX');
  EmitLabel(TP_RT_PFX + 'KP_DN');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('RET');

  { ------ _TPRT_READKEY : lire une touche -> EAX --------------- }
  { Retourne le code ASCII de la touche pressee                    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'READKEY');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitLabel(TP_RT_PFX + 'RK_LP');
  { ReadConsoleInputA(hStdin, &rec, 1, &count) }
  EmitInstr('PUSH OFFSET CRT_NEVT');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET CRT_INREC');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL ReadConsoleInputA');
  { Verifier EventType == KEY_EVENT (1) }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_INREC]');
  EmitInstr('CMP EAX,1');
  EmitInstr('JNE ' + TP_RT_PFX + 'RK_LP');
  { Verifier bKeyDown }
  EmitInstr('MOV EAX,DWORD PTR [CRT_INREC+4]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'RK_LP');
  { Retourner AsciiChar (offset 14 dans INPUT_RECORD) }
  EmitInstr('MOVZX EAX,BYTE PTR [CRT_INREC+14]');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('RET');

  { ------ _TPRT_SOUND : emettre un son (Hz) -------------------- }
  { Parametre sur pile : [ESP+4] = frequence en Hz                 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SOUND');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Beep(frequency, duration=200ms) }
  EmitInstr('PUSH 200');
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  EmitInstr('CALL Beep');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_INSLINE : inserer une ligne vide a la position du curseur -- }
  { Deplace les lignes vers le bas depuis la position courante                 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INSLINE');
  EmitInstr('PUSHAD');
  { GetConsoleScreenBufferInfo(hStdout, &CRT_CSBI) }
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+6]');   { curY }
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+0]');   { cols }
  EmitInstr('DEC ECX');
  EmitInstr('MOVZX EDX,WORD PTR [CRT_CSBI+2]');   { rows }
  EmitInstr('DEC EDX');
  { SMALL_RECT src: Left=0, Top=curY, Right=cols-1, Bottom=rows-1 }
  EmitInstr('MOV WORD PTR [CRT_SCROLL+0],0');
  EmitInstr('MOV WORD PTR [CRT_SCROLL+2],AX');
  EmitInstr('MOV WORD PTR [CRT_SCROLL+4],CX');
  EmitInstr('MOV WORD PTR [CRT_SCROLL+6],DX');
  { fill char: space(32) + attribute }
  EmitInstr('MOV ECX,DWORD PTR [TEXTATTR]');
  EmitInstr('AND ECX,0FFh');
  EmitInstr('SHL ECX,16');
  EmitInstr('OR ECX,32');
  EmitInstr('MOV DWORD PTR [CRT_FILL],ECX');
  { dest = (0, curY+1) packed as COORD: X=low word, Y=high word }
  EmitInstr('INC AX');
  EmitInstr('SHL EAX,16');
  EmitInstr('MOV EBX,EAX');
  { ScrollConsoleScreenBufferA(hOut, lpScroll, lpClip, dwDest, lpFill) }
  EmitInstr('PUSH OFFSET CRT_FILL');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET CRT_SCROLL');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL ScrollConsoleScreenBufferA');
  { Fill current line with spaces }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+6]');   { curY }
  EmitInstr('SHL EAX,16');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+0]');   { cols }
  EmitInstr('PUSH OFFSET CRT_NWRT');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH 32');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL FillConsoleOutputCharacterA');
  { Fill attribute on current line }
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+6]');
  EmitInstr('SHL EAX,16');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+0]');
  EmitInstr('PUSH OFFSET CRT_NWRT');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH DWORD PTR [TEXTATTR]');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL FillConsoleOutputAttribute');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_DELLINE : supprimer la ligne a la position du curseur ------ }
  { Deplace les lignes vers le haut depuis la position courante+1             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DELLINE');
  EmitInstr('PUSHAD');
  EmitInstr('PUSH OFFSET CRT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL GetConsoleScreenBufferInfo');
  EmitInstr('MOVZX EAX,WORD PTR [CRT_CSBI+6]');   { curY }
  EmitInstr('MOVZX ECX,WORD PTR [CRT_CSBI+0]');   { cols }
  EmitInstr('DEC ECX');
  EmitInstr('MOVZX EDX,WORD PTR [CRT_CSBI+2]');   { rows }
  EmitInstr('DEC EDX');
  { SMALL_RECT src: Left=0, Top=curY+1, Right=cols-1, Bottom=rows-1 }
  EmitInstr('MOV EBX,EAX');
  EmitInstr('INC EBX');
  EmitInstr('MOV WORD PTR [CRT_SCROLL+0],0');
  EmitInstr('MOV WORD PTR [CRT_SCROLL+2],BX');     { Top=curY+1 }
  EmitInstr('MOV WORD PTR [CRT_SCROLL+4],CX');     { Right=cols-1 }
  EmitInstr('MOV WORD PTR [CRT_SCROLL+6],DX');     { Bottom=rows-1 }
  { fill char }
  EmitInstr('MOV ECX,DWORD PTR [TEXTATTR]');
  EmitInstr('AND ECX,0FFh');
  EmitInstr('SHL ECX,16');
  EmitInstr('OR ECX,32');
  EmitInstr('MOV DWORD PTR [CRT_FILL],ECX');
  { dest = (0, curY) }
  EmitInstr('SHL EAX,16');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH OFFSET CRT_FILL');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET CRT_SCROLL');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL ScrollConsoleScreenBufferA');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_TEXTMODE : changer le mode texte -------------------- }
  { Parametre : [ESP+4] = mode (CO80=3, BW80=2, etc.)                 }
  { Reset TEXTATTR, WINDMIN, WINDMAX, appelle ClrScr                  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'TEXTMODE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EAX');
  { Sauver le mode courant dans LASTMODE }
  EmitInstr('MOV EAX,DWORD PTR [LASTMODE]');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('AND EAX,0FFh');                       { ignorer Font8x8 bit }
  EmitInstr('MOV DWORD PTR [LASTMODE],EAX');
  { Reset TEXTATTR a $07 (LightGray sur Black) }
  EmitInstr('MOV DWORD PTR [TEXTATTR],7');
  { Reset WINDMIN/WINDMAX }
  EmitInstr('MOV DWORD PTR [WINDMIN],0');
  EmitInstr('MOV DWORD PTR [WINDMAX],184Fh');      { 24*256+79 }
  { Appliquer l attribut }
  EmitInstr('PUSH 7');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL SetConsoleTextAttribute');
  { Appeler ClrScr }
  EmitInstr('CALL ' + TP_RT_PFX + 'CLRSCR');
  EmitInstr('POP EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ============================================================ }
  { TODO 19 - ROUTINES RUNTIME DOS                [IMPLEMENTE]    }
  { ============================================================ }

  { ------ _TPRT_DOSVERSION : retourne version DOS emulee ------- }
  { Retourne 7 dans EAX (emulation DOS 7.0)                       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DOSVERSION');
  EmitInstr('MOV EAX,7');
  EmitInstr('RET');

  { ------ _TPRT_DISKFREE : espace libre sur disque ------------- }
  { Parametre : [ESP+4] = numero de lecteur (0=courant, 1=A, ...) }
  { Retourne taille en octets dans EAX                              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DISKFREE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Construire la chaine de lecteur "C:\" }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'DF_CUR');
  EmitInstr('ADD AL,64');       { 1->A, 2->B, ... }
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF],AL');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+1],'':''');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+2],''\''');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+3],0');
  EmitInstr('PUSH OFFSET DOS_PATHBUF');
  EmitInstr('JMP ' + TP_RT_PFX + 'DF_GO');
  EmitLabel(TP_RT_PFX + 'DF_CUR');
  EmitInstr('PUSH 0');          { NULL = lecteur courant }
  EmitLabel(TP_RT_PFX + 'DF_GO');
  { GetDiskFreeSpaceA(root, &SectPerClust, &BytesPerSect, &FreeClusters, &TotClusters) }
  EmitInstr('PUSH OFFSET DOS_DKFREE+12');    { TotalClusters  }
  EmitInstr('PUSH OFFSET DOS_DKFREE+8');     { FreeClusters   }
  EmitInstr('PUSH OFFSET DOS_DKFREE+4');     { BytesPerSector }
  EmitInstr('PUSH OFFSET DOS_DKFREE+0');     { SectorsPerCluster }
  EmitInstr('CALL GetDiskFreeSpaceA');        { passe root en 5e param deja PUSH }
  { Resultat = FreeClusters * SectorsPerCluster * BytesPerSector }
  EmitInstr('MOV EAX,DWORD PTR [DOS_DKFREE+8]');    { FreeClusters }
  EmitInstr('IMUL EAX,DWORD PTR [DOS_DKFREE+0]');   { * SectPerClust }
  EmitInstr('IMUL EAX,DWORD PTR [DOS_DKFREE+4]');   { * BytesPerSect }
  EmitInstr('MOV DWORD PTR [EBP-4],EAX');            { sauver resultat }
  EmitInstr('POPAD');
  EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_DISKSIZE : taille totale disque ----------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DISKSIZE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'DS_CUR');
  EmitInstr('ADD AL,64');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF],AL');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+1],'':''');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+2],''\''');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF+3],0');
  EmitInstr('PUSH OFFSET DOS_PATHBUF');
  EmitInstr('JMP ' + TP_RT_PFX + 'DS_GO');
  EmitLabel(TP_RT_PFX + 'DS_CUR');
  EmitInstr('PUSH 0');
  EmitLabel(TP_RT_PFX + 'DS_GO');
  EmitInstr('PUSH OFFSET DOS_DKFREE+12');
  EmitInstr('PUSH OFFSET DOS_DKFREE+8');
  EmitInstr('PUSH OFFSET DOS_DKFREE+4');
  EmitInstr('PUSH OFFSET DOS_DKFREE+0');
  EmitInstr('CALL GetDiskFreeSpaceA');
  { TotalClusters * SectorsPerCluster * BytesPerSector }
  EmitInstr('MOV EAX,DWORD PTR [DOS_DKFREE+12]');
  EmitInstr('IMUL EAX,DWORD PTR [DOS_DKFREE+0]');
  EmitInstr('IMUL EAX,DWORD PTR [DOS_DKFREE+4]');
  EmitInstr('MOV DWORD PTR [EBP-4],EAX');
  EmitInstr('POPAD');
  EmitInstr('MOV EAX,DWORD PTR [EBP-4]');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_GETENV : lire variable d environnement --------- }
  { Parametre : [ESP+4] = pointeur chaine ASCIIZ du nom de variable }
  { Retourne : EAX = pointeur vers chaine resultat ASCIIZ (DOS_ENVBUF) }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GETENV');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  { Charger le pointeur vers le nom (deja ASCIIZ) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  { GetEnvironmentVariableA(name, buf, bufsize) }
  EmitInstr('PUSH 255');
  EmitInstr('PUSH OFFSET DOS_ENVBUF');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL GetEnvironmentVariableA');
  { EAX = nombre de caracteres copies, 0 si pas trouve }
  { DOS_ENVBUF contient le resultat ASCIIZ             }
  { Si pas trouve, mettre NUL en debut de buffer       }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'GE_OK');
  EmitInstr('MOV BYTE PTR [DOS_ENVBUF],0');
  EmitLabel(TP_RT_PFX + 'GE_OK');
  EmitInstr('LEA EAX,[DOS_ENVBUF]');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FEXPAND : retourner chemin complet -------------- }
  { Parametre : [ESP+4] = pointeur chaine chemin ASCIIZ              }
  { Retourne : EAX = pointeur vers DOS_PATHBUF (ASCIIZ)              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FEXPAND');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  { GetFullPathNameA(filename, bufsize, buf, &filepart) }
  EmitInstr('PUSH 0');        { lpFilePart (NULL) }
  EmitInstr('PUSH OFFSET DOS_PATHBUF');
  EmitInstr('PUSH 259');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL GetFullPathNameA');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'FE_OK');
  EmitInstr('MOV BYTE PTR [DOS_PATHBUF],0');
  EmitLabel(TP_RT_PFX + 'FE_OK');
  EmitInstr('LEA EAX,[DOS_PATHBUF]');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FSEARCH : chercher fichier dans liste dirs ------ }
  { Params : [ESP+4]=name ASCIIZ, [ESP+8]=dirlist ASCIIZ             }
  { Retourne pointeur vers chemin trouve ASCIIZ ou chaine vide       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FSEARCH');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ECX');
  { Essayer GetFileAttributesA sur le nom seul d abord }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL GetFileAttributesA');
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'FS_NF');
  { Fichier trouve - retourner le nom tel quel }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('JMP ' + TP_RT_PFX + 'FS_DN');
  EmitLabel(TP_RT_PFX + 'FS_NF');
  { Non trouve - retourner chaine vide }
  EmitInstr('MOV BYTE PTR [DOS_ENVBUF],0');
  EmitInstr('LEA EAX,[DOS_ENVBUF]');
  EmitLabel(TP_RT_PFX + 'FS_DN');
  EmitInstr('POP ECX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FSPLIT : decomposer chemin ---------------------- }
  { Stack (pushed L-to-R) : [EBP+20]=Path, [EBP+16]=Dir,          }
  {                         [EBP+12]=Name, [EBP+8]=Ext             }
  { Toutes des chaines Pascal. Remplit Dir, Name, Ext.             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FSPLIT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');

  { ESI = pointeur Path (chaine Pascal : [len][chars]) }
  EmitInstr('MOV ESI,DWORD PTR [EBP+20]');
  EmitInstr('MOVZX ECX,BYTE PTR [ESI]');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_EMPTY');

  { Copier les chars dans DOS_PATHBUF pour manipulation ASCIIZ }
  EmitInstr('MOV DWORD PTR [DOS_PATHBUF+260],ECX');   { sauver longueur }
  EmitInstr('PUSH ECX');
  EmitInstr('INC ESI');
  EmitInstr('LEA EDI,[DOS_PATHBUF]');
  EmitInstr('REP MOVSB');
  EmitInstr('MOV BYTE PTR [EDI],0');     { NUL terminal }
  EmitInstr('POP ECX');                   { ECX = longueur totale }

  { Chercher le dernier separateur \ / : depuis la fin }
  EmitInstr('MOV EDX,-1');                { EDX = position du sep, -1=pas trouve }
  EmitInstr('MOV EBX,ECX');
  EmitInstr('DEC EBX');
  EmitLabel(TP_RT_PFX + 'FSP_SCN');
  EmitInstr('TEST EBX,EBX');
  EmitInstr('JS ' + TP_RT_PFX + 'FSP_SDN');
  EmitInstr('LEA EAX,[DOS_PATHBUF]');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('MOVZX EAX,BYTE PTR [EAX]');
  EmitInstr('CMP AL,92');                 { backslash }
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_SFD');
  EmitInstr('CMP AL,47');                 { slash }
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_SFD');
  EmitInstr('CMP AL,58');                 { colon }
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_SFD');
  EmitInstr('DEC EBX');
  EmitInstr('JMP ' + TP_RT_PFX + 'FSP_SCN');
  EmitLabel(TP_RT_PFX + 'FSP_SFD');
  EmitInstr('MOV EDX,EBX');              { EDX = position du dernier sep (0-based) }
  EmitLabel(TP_RT_PFX + 'FSP_SDN');

  { DirLen = EDX+1 si sep trouve, 0 sinon }
  EmitInstr('MOV ECX,DWORD PTR [DOS_PATHBUF+260]'); { longueur totale }
  EmitInstr('CMP EDX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_NODIR');
  EmitInstr('MOV EBX,EDX');                { EBX = position du dernier sep (0-based) }
  EmitInstr('INC EBX');                    { EBX = DirLen (incl sep) }
  EmitInstr('JMP ' + TP_RT_PFX + 'FSP_CDIR');
  EmitLabel(TP_RT_PFX + 'FSP_NODIR');
  EmitInstr('XOR EBX,EBX');              { EBX = 0, pas de dir }
  EmitLabel(TP_RT_PFX + 'FSP_CDIR');

  { Copier Dir (EBX chars depuis DOS_PATHBUF) }
  EmitInstr('MOV EDI,DWORD PTR [EBP+16]');
  EmitInstr('MOV BYTE PTR [EDI],BL');
  EmitInstr('TEST EBX,EBX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_DD');
  EmitInstr('PUSH ECX');
  EmitInstr('MOV ECX,EBX');
  EmitInstr('INC EDI');
  EmitInstr('LEA ESI,[DOS_PATHBUF]');
  EmitInstr('REP MOVSB');
  EmitInstr('POP ECX');
  EmitLabel(TP_RT_PFX + 'FSP_DD');

  { Reste = filename part : ECX-EBX chars a partir de DOS_PATHBUF+EBX }
  EmitInstr('SUB ECX,EBX');               { ECX = restLen }

  { Chercher le dernier point dans le reste }
  EmitInstr('MOV EDX,-1');                { position du point, -1=pas trouve }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_NDP');
  EmitInstr('PUSH ECX');
  EmitInstr('DEC ECX');
  EmitLabel(TP_RT_PFX + 'FSP_DSC');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JS ' + TP_RT_PFX + 'FSP_DNF');
  EmitInstr('LEA EAX,[DOS_PATHBUF]');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('ADD EAX,ECX');
  EmitInstr('MOVZX EAX,BYTE PTR [EAX]');
  EmitInstr('CMP AL,46');                 { point }
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_DFD');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'FSP_DSC');
  EmitLabel(TP_RT_PFX + 'FSP_DFD');
  EmitInstr('MOV EDX,ECX');              { EDX = position du point dans le reste }
  EmitLabel(TP_RT_PFX + 'FSP_DNF');
  EmitInstr('POP ECX');                   { ECX = restLen }
  EmitLabel(TP_RT_PFX + 'FSP_NDP');

  { Si point trouve : Name = reste[0..EDX-1], Ext = reste[EDX..end] }
  { Si pas de point  : Name = tout le reste, Ext = '' }
  EmitInstr('CMP EDX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'FSP_ALLNM');
  { Name = EDX chars }
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');
  EmitInstr('MOV BYTE PTR [EDI],DL');     { Name length }
  EmitInstr('TEST EDX,EDX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_ND');
  EmitInstr('PUSH ECX');
  EmitInstr('MOV ECX,EDX');
  EmitInstr('INC EDI');
  EmitInstr('LEA ESI,[DOS_PATHBUF]');
  EmitInstr('ADD ESI,EBX');
  EmitInstr('REP MOVSB');
  EmitInstr('POP ECX');
  EmitLabel(TP_RT_PFX + 'FSP_ND');
  { Ext = ECX-EDX chars }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('SUB EAX,EDX');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV BYTE PTR [EDI],AL');     { Ext length }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_ED');
  EmitInstr('MOV ECX,EAX');
  EmitInstr('INC EDI');
  EmitInstr('LEA ESI,[DOS_PATHBUF]');
  EmitInstr('ADD ESI,EBX');
  EmitInstr('ADD ESI,EDX');
  EmitInstr('REP MOVSB');
  EmitLabel(TP_RT_PFX + 'FSP_ED');
  EmitInstr('JMP ' + TP_RT_PFX + 'FSP_RET');

  { Pas de point : Name = tout le reste }
  EmitLabel(TP_RT_PFX + 'FSP_ALLNM');
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');
  EmitInstr('MOV BYTE PTR [EDI],CL');     { Name length = restLen }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FSP_AN');
  EmitInstr('INC EDI');
  EmitInstr('LEA ESI,[DOS_PATHBUF]');
  EmitInstr('ADD ESI,EBX');
  EmitInstr('REP MOVSB');
  EmitLabel(TP_RT_PFX + 'FSP_AN');
  { Ext = '' }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'FSP_RET');

  { Chemin vide : Dir='', Name='', Ext='' }
  EmitLabel(TP_RT_PFX + 'FSP_EMPTY');
  EmitInstr('MOV EDI,DWORD PTR [EBP+16]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitLabel(TP_RT_PFX + 'FSP_RET');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FINDFIRST : FindFirst(Path, Attr, SR) ---------- }
  { Stack (pushed L-to-R) : [EBP+16]=Path, [EBP+12]=Attr, [EBP+8]=SR }
  { DosError mis a 0 si OK, 18 si pas trouve                        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FINDFIRST');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { FindFirstFileA(path, &finddata) }
  EmitInstr('MOV EAX,DWORD PTR [EBP+16]');  { Path (ASCIIZ, first pushed) }
  EmitInstr('PUSH OFFSET DOS_FINDDATA');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL FindFirstFileA');
  EmitInstr('MOV DWORD PTR [DOS_FINDHDL],EAX');
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'FF_NF');
  { Succes : remplir SearchRec = (Attr:Word, Time:LongInt, Size:LongInt, Name:String) }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { SearchRec addr (last pushed) }
  { Attr = dwFileAttributes (offset 0 dans WIN32_FIND_DATA) }
  EmitInstr('MOV EAX,DWORD PTR [DOS_FINDDATA]');
  EmitInstr('MOV WORD PTR [EDI],AX');        { SR.Attr }
  { Time = ftLastWriteTime.dwLowDateTime (stub: 0) }
  EmitInstr('MOV DWORD PTR [EDI+4],0');      { SR.Time }
  { Size = nFileSizeLow (offset 32) }
  EmitInstr('MOV EAX,DWORD PTR [DOS_FINDDATA+32]');
  EmitInstr('MOV DWORD PTR [EDI+8],EAX');   { SR.Size }
  { Name = cFileName (offset 44, ASCIIZ -> Pascal string) }
  EmitInstr('LEA ESI,[DOS_FINDDATA+44]');
  EmitInstr('LEA EDI,[EDI+12]');             { SR.Name }
  EmitInstr('PUSH EDI');
  EmitInstr('INC EDI');                       { sauter octet longueur }
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'FF_CP');
  EmitInstr('LODSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'FF_CE');
  EmitInstr('STOSB');
  EmitInstr('INC ECX');
  EmitInstr('CMP ECX,79');
  EmitInstr('JB ' + TP_RT_PFX + 'FF_CP');
  EmitLabel(TP_RT_PFX + 'FF_CE');
  EmitInstr('POP EDI');
  EmitInstr('MOV BYTE PTR [EDI],CL');       { longueur Pascal }
  EmitInstr('MOV DWORD PTR [DOSERROR],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'FF_DN');
  EmitLabel(TP_RT_PFX + 'FF_NF');
  EmitInstr('MOV DWORD PTR [DOSERROR],18'); { 18 = pas de fichier }
  EmitLabel(TP_RT_PFX + 'FF_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FINDNEXT : FindNext(SR) ------------------------ }
  { Parametre : [ESP+4] = SearchRec address                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FINDNEXT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { FindNextFileA(handle, &finddata) }
  EmitInstr('PUSH OFFSET DOS_FINDDATA');
  EmitInstr('PUSH DWORD PTR [DOS_FINDHDL]');
  EmitInstr('CALL FindNextFileA');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FN_NF');
  { Remplir SearchRec }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV EAX,DWORD PTR [DOS_FINDDATA]');
  EmitInstr('MOV WORD PTR [EDI],AX');
  EmitInstr('MOV DWORD PTR [EDI+4],0');
  EmitInstr('MOV EAX,DWORD PTR [DOS_FINDDATA+32]');
  EmitInstr('MOV DWORD PTR [EDI+8],EAX');
  EmitInstr('LEA ESI,[DOS_FINDDATA+44]');
  EmitInstr('LEA EDI,[EDI+12]');
  EmitInstr('PUSH EDI');
  EmitInstr('INC EDI');
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'FN_CP');
  EmitInstr('LODSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'FN_CE');
  EmitInstr('STOSB');
  EmitInstr('INC ECX');
  EmitInstr('CMP ECX,79');
  EmitInstr('JB ' + TP_RT_PFX + 'FN_CP');
  EmitLabel(TP_RT_PFX + 'FN_CE');
  EmitInstr('POP EDI');
  EmitInstr('MOV BYTE PTR [EDI],CL');
  EmitInstr('MOV DWORD PTR [DOSERROR],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'FN_DN');
  EmitLabel(TP_RT_PFX + 'FN_NF');
  EmitInstr('MOV DWORD PTR [DOSERROR],18');
  { Fermer le handle de recherche }
  EmitInstr('PUSH DWORD PTR [DOS_FINDHDL]');
  EmitInstr('CALL FindClose');
  EmitInstr('MOV DWORD PTR [DOS_FINDHDL],-1');
  EmitLabel(TP_RT_PFX + 'FN_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_EXEC : executer un programme -------------------- }
  { Params : [ESP+4]=Path, [ESP+8]=CmdLine (Pascal strings)        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'EXEC');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Initialiser STARTUPINFO (68 bytes, cb = 68) }
  EmitInstr('LEA EDI,[DOS_STARTINFO]');
  EmitInstr('MOV ECX,68');
  EmitInstr('XOR AL,AL');
  EmitInstr('REP STOSB');
  EmitInstr('MOV DWORD PTR [DOS_STARTINFO],68');  { cb = sizeof(STARTUPINFO) }
  { CreateProcessA(lpApp, lpCmd, 0,0, FALSE, 0, 0, 0, &si, &pi) }
  EmitInstr('PUSH OFFSET DOS_PROCINFO');
  EmitInstr('PUSH OFFSET DOS_STARTINFO');
  EmitInstr('PUSH 0');           { lpCurrentDirectory }
  EmitInstr('PUSH 0');           { lpEnvironment }
  EmitInstr('PUSH 0');           { dwCreationFlags }
  EmitInstr('PUSH 0');           { bInheritHandles }
  EmitInstr('PUSH 0');           { lpThreadAttributes }
  EmitInstr('PUSH 0');           { lpProcessAttributes }
  { CmdLine }
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');
  EmitInstr('INC EAX');
  EmitInstr('PUSH EAX');
  { Path }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('INC EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateProcessA');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'EX_ER');
  { Attendre la fin du processus }
  EmitInstr('PUSH -1');          { INFINITE }
  EmitInstr('PUSH DWORD PTR [DOS_PROCINFO]');   { hProcess }
  EmitInstr('CALL WaitForSingleObject');
  { Recuperer le code de sortie }
  EmitInstr('PUSH OFFSET DOS_EXITVAL');
  EmitInstr('PUSH DWORD PTR [DOS_PROCINFO]');
  EmitInstr('CALL GetExitCodeProcess');
  EmitInstr('MOV EAX,DWORD PTR [DOS_EXITVAL]');
  EmitInstr('MOV DWORD PTR [DOSEXITCODE],EAX');
  { Fermer les handles }
  EmitInstr('PUSH DWORD PTR [DOS_PROCINFO+4]');  { hThread }
  EmitInstr('CALL CloseHandle');
  EmitInstr('PUSH DWORD PTR [DOS_PROCINFO]');    { hProcess }
  EmitInstr('CALL CloseHandle');
  EmitInstr('MOV DWORD PTR [DOSERROR],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'EX_DN');
  EmitLabel(TP_RT_PFX + 'EX_ER');
  EmitInstr('MOV DWORD PTR [DOSERROR],2');  { fichier non trouve }
  EmitLabel(TP_RT_PFX + 'EX_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_MSDOS : emulation INT 21h ---------------------- }
  { Parametre : [ESP+4] = pointeur vers structure Registers          }
  { Dispatch selon AH (champ dans la structure)                      }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'MSDOS');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');   { pointeur Registers }
  { Lire AH pour le dispatch - AX est a offset 0, AH = byte 1 }
  EmitInstr('MOVZX EAX,BYTE PTR [EBX+1]');  { AH }
  { Fonction 4Ch : ExitProcess }
  EmitInstr('CMP AL,4Ch');
  EmitInstr('JNE ' + TP_RT_PFX + 'MS_N4C');
  EmitInstr('MOVZX EAX,BYTE PTR [EBX]');    { AL = code sortie }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ExitProcess');
  EmitLabel(TP_RT_PFX + 'MS_N4C');
  { Fonction 30h : DosVersion - retourne 7.0 dans AL.AH }
  EmitInstr('CMP AL,30h');
  EmitInstr('JNE ' + TP_RT_PFX + 'MS_N30');
  EmitInstr('MOV BYTE PTR [EBX],7');        { AL = version majeure }
  EmitInstr('MOV BYTE PTR [EBX+1],0');      { AH = version mineure }
  EmitInstr('JMP ' + TP_RT_PFX + 'MS_DN');
  EmitLabel(TP_RT_PFX + 'MS_N30');
  { Fonction 2Ah : GetDate }
  EmitInstr('CMP AL,2Ah');
  EmitInstr('JNE ' + TP_RT_PFX + 'MS_N2A');
  EmitInstr('PUSH OFFSET DOS_SYSTIME');
  EmitInstr('CALL GetLocalTime');
  { CX = annee, DH = mois, DL = jour, AL = jour semaine }
  EmitInstr('MOVZX EAX,WORD PTR [DOS_SYSTIME+0]');   { wYear }
  EmitInstr('MOV WORD PTR [EBX+4],AX');               { CX = annee }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+2]');       { wMonth }
  EmitInstr('MOV BYTE PTR [EBX+7],AL');                 { DH = mois }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+6]');       { wDay }
  EmitInstr('MOV BYTE PTR [EBX+6],AL');                { DL = jour }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+4]');       { wDayOfWeek }
  EmitInstr('MOV BYTE PTR [EBX],AL');                  { AL = dow }
  EmitInstr('JMP ' + TP_RT_PFX + 'MS_DN');
  EmitLabel(TP_RT_PFX + 'MS_N2A');
  { Fonction 2Ch : GetTime }
  EmitInstr('CMP AL,2Ch');
  EmitInstr('JNE ' + TP_RT_PFX + 'MS_N2C');
  EmitInstr('PUSH OFFSET DOS_SYSTIME');
  EmitInstr('CALL GetLocalTime');
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+8]');       { wHour }
  EmitInstr('MOV BYTE PTR [EBX+5],AL');                { CH = heure }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+10]');      { wMinute }
  EmitInstr('MOV BYTE PTR [EBX+4],AL');                { CL = minute }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+12]');      { wSecond }
  EmitInstr('MOV BYTE PTR [EBX+7],AL');                { DH = seconde }
  EmitInstr('MOV AL,BYTE PTR [DOS_SYSTIME+14]');      { wMs (0..999) }
  EmitInstr('XOR AH,AH');
  EmitInstr('MOV CL,10');
  EmitInstr('DIV CL');                                  { AL = centieme }
  EmitInstr('MOV BYTE PTR [EBX+6],AL');                { DL = centieme }
  EmitInstr('JMP ' + TP_RT_PFX + 'MS_DN');
  EmitLabel(TP_RT_PFX + 'MS_N2C');
  { Fonction 02h : ecrire caractere DL }
  EmitInstr('CMP AL,02h');
  EmitInstr('JNE ' + TP_RT_PFX + 'MS_N02');
  EmitInstr('MOV AL,BYTE PTR [EBX+6]');               { DL }
  EmitInstr('MOV BYTE PTR [NUMBUF],AL');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL WriteFile');
  EmitInstr('JMP ' + TP_RT_PFX + 'MS_DN');
  EmitLabel(TP_RT_PFX + 'MS_N02');
  { Autres fonctions : stub silencieux }
  EmitLabel(TP_RT_PFX + 'MS_DN');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ================================================================ }
  { ========== ROUTINES FILE I/O (Assign, Reset, Close, EOF) ======= }
  { ================================================================ }

  { ------ _TPRT_ASSIGN : associer fichier et nom --------------- }
  { [ESP+4]=adresse variable fichier, [ESP+8]=nom ASCIIZ         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ASSIGN');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Stack (pushed L-to-R) : [EBP+12]=f addr (first), [EBP+8]=name (last) }
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');   { adresse variable fichier (first pushed) }
  EmitInstr('MOV DWORD PTR [EDI],-1');         { handle = invalide }
  { Copier le nom de fichier dans FILE_NAMEBUF }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');    { nom ASCIIZ (last pushed) }
  EmitInstr('LEA EDI,[FILE_NAMEBUF]');
  EmitLabel(TP_RT_PFX + 'AS_CP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'AS_CP');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_RESET : ouvrir fichier en lecture --------------- }
  { [ESP+4]=adresse variable fichier                               }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'RESET');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { CreateFileA(FILE_NAMEBUF, GENERIC_READ, FILE_SHARE_READ, }
  {             NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL) }
  EmitInstr('PUSH 0');                          { hTemplateFile }
  EmitInstr('PUSH 128');                        { FILE_ATTRIBUTE_NORMAL }
  EmitInstr('PUSH 3');                          { OPEN_EXISTING }
  EmitInstr('PUSH 0');                          { lpSecurityAttributes }
  EmitInstr('PUSH 1');                          { FILE_SHARE_READ }
  EmitInstr('PUSH 80000000h');                  { GENERIC_READ }
  EmitInstr('PUSH OFFSET FILE_NAMEBUF');        { lpFileName }
  EmitInstr('CALL CreateFileA');
  { Stocker le handle dans la variable fichier }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  { Initialiser le buffer de lecture }
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],0');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],0');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_REWRITE : ouvrir fichier en ecriture ----------- }
  { [ESP+4]=adresse variable fichier                               }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'REWRITE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('PUSH 0');                          { hTemplateFile }
  EmitInstr('PUSH 128');                        { FILE_ATTRIBUTE_NORMAL }
  EmitInstr('PUSH 2');                          { CREATE_ALWAYS }
  EmitInstr('PUSH 0');                          { lpSecurityAttributes }
  EmitInstr('PUSH 0');                          { dwShareMode }
  EmitInstr('PUSH 40000000h');                  { GENERIC_WRITE }
  EmitInstr('PUSH OFFSET FILE_NAMEBUF');        { lpFileName }
  EmitInstr('CALL CreateFileA');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],0');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],0');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_CLOSE : fermer fichier ------------------------- }
  { [ESP+4]=adresse variable fichier                               }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CLOSE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV EAX,DWORD PTR [EDI]');       { handle }
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'CL_DN');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CloseHandle');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [EDI],-1');
  EmitLabel(TP_RT_PFX + 'CL_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_APPEND : ouvrir fichier texte en ajout ---------- }
  { [ESP+4]=adresse variable fichier                                }
  { Ouvre avec OPEN_EXISTING et FILE_APPEND_DATA                    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'APPEND');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('PUSH 0');                               { hTemplateFile }
  EmitInstr('PUSH 128');                             { dwFlagsAndAttributes }
  EmitInstr('PUSH 4');                               { OPEN_ALWAYS }
  EmitInstr('PUSH 0');                               { lpSecurityAttributes }
  EmitInstr('PUSH 0');                               { dwShareMode }
  EmitInstr('PUSH 40000000h');                       { GENERIC_WRITE }
  EmitInstr('PUSH OFFSET FILE_NAMEBUF');             { lpFileName }
  EmitInstr('CALL CreateFileA');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  { Seek to end of file }
  EmitInstr('PUSH 2');                               { FILE_END }
  EmitInstr('PUSH 0');                               { lpDistanceToMoveHigh }
  EmitInstr('PUSH 0');                               { lDistanceToMove }
  EmitInstr('PUSH EAX');                             { hFile }
  EmitInstr('CALL SetFilePointer');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],0');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],0');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_EOF_FILE : tester EOF d un fichier ------------- }
  { [ESP+4]=adresse variable fichier                               }
  { Retourne EAX=1 si EOF, EAX=0 sinon                            }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'EOF_FILE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');    { adresse variable fichier }
  EmitInstr('MOV EAX,DWORD PTR [EBX]');       { handle }
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'EF_YES');
  { Verifier s il y a des donnees en buffer }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BUFPOS]');
  EmitInstr('CMP EAX,DWORD PTR [FILE_BUFEND]');
  EmitInstr('JB ' + TP_RT_PFX + 'EF_NO');
  { Buffer vide : verifier le flag EOF }
  EmitInstr('CMP DWORD PTR [FILE_EOFFLG],1');
  EmitInstr('JE ' + TP_RT_PFX + 'EF_YES');
  { Tenter de remplir le buffer }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET FILE_BYTESRD');
  EmitInstr('PUSH 256');
  EmitInstr('PUSH OFFSET FILE_RDBUF');
  EmitInstr('PUSH DWORD PTR [EBX]');           { file handle }
  EmitInstr('CALL ReadFile');
  EmitInstr('MOV EAX,DWORD PTR [FILE_BYTESRD]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'EF_SET');
  { Des donnees ont ete lues }
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitLabel(TP_RT_PFX + 'EF_NO');
  EmitInstr('XOR EAX,EAX');                   { retourne 0 = pas EOF }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'EF_SET');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],1');
  EmitLabel(TP_RT_PFX + 'EF_YES');
  EmitInstr('MOV EAX,1');                     { retourne 1 = EOF }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_READLN_FILE : lire une ligne depuis fichier ---- }
  { [ESP+4]=adresse variable fichier                                }
  { Sortie : INBUF contient la ligne, terminee par NUL             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'READLN_FILE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');    { adresse variable fichier }
  EmitInstr('MOV EBX,DWORD PTR [EBX]');      { charger le handle }
  EmitInstr('XOR ECX,ECX');                    { compteur octets dans INBUF }
  EmitLabel(TP_RT_PFX + 'RF_NX');
  { Verifier si le buffer est vide }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BUFPOS]');
  EmitInstr('CMP EAX,DWORD PTR [FILE_BUFEND]');
  EmitInstr('JB ' + TP_RT_PFX + 'RF_GC');
  { Remplir le buffer depuis le fichier }
  EmitInstr('PUSH ECX');                       { sauver compteur }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET FILE_BYTESRD');
  EmitInstr('PUSH 256');
  EmitInstr('PUSH OFFSET FILE_RDBUF');
  EmitInstr('PUSH EBX');                       { file handle }
  EmitInstr('CALL ReadFile');
  EmitInstr('POP ECX');                        { restaurer compteur }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BYTESRD]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'RF_EF');     { 0 octets = EOF }
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('XOR EAX,EAX');
  EmitLabel(TP_RT_PFX + 'RF_GC');
  { Lire un caractere du buffer }
  EmitInstr('LEA ESI,[FILE_RDBUF]');
  EmitInstr('ADD ESI,EAX');
  EmitInstr('INC DWORD PTR [FILE_BUFPOS]');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('CMP AL,10');                      { LF = fin de ligne }
  EmitInstr('JE ' + TP_RT_PFX + 'RF_DN');
  EmitInstr('CMP AL,13');                      { CR = sauter }
  EmitInstr('JE ' + TP_RT_PFX + 'RF_NX');
  { Stocker le caractere dans INBUF }
  EmitInstr('LEA EDI,[INBUF]');
  EmitInstr('ADD EDI,ECX');
  EmitInstr('MOV BYTE PTR [EDI],AL');
  EmitInstr('INC ECX');
  EmitInstr('CMP ECX,254');
  EmitInstr('JAE ' + TP_RT_PFX + 'RF_DN');
  EmitInstr('JMP ' + TP_RT_PFX + 'RF_NX');
  EmitLabel(TP_RT_PFX + 'RF_EF');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],1');
  EmitLabel(TP_RT_PFX + 'RF_DN');
  EmitInstr('LEA EDI,[INBUF]');
  EmitInstr('ADD EDI,ECX');
  EmitInstr('MOV BYTE PTR [EDI],0');    { terminer par NUL }
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_FPRINTSTR : ecrire chaine ASCIIZ dans fichier - }
  { Entree : ESI = pointeur vers chaine ASCIIZ                    }
  { Utilise : WriteFile(FILE_WRHND, ESI, len, &BYTESWR, 0)        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FPRINTSTR');
  EmitInstr('PUSHAD');
  { Calculer la longueur de la chaine }
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'FPS_L');
  EmitInstr('CMP BYTE PTR [ESI+ECX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'FPS_G');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'FPS_L');
  EmitLabel(TP_RT_PFX + 'FPS_G');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'FPS_D');
  { Appeler WriteFile(FILE_WRHND, ESI, ECX, &BYTESWR, 0) }
  EmitInstr('PUSH 0');                     { lpOverlapped         }
  EmitInstr('PUSH OFFSET BYTESWR');        { lpNumberOfBytesWritten }
  EmitInstr('PUSH ECX');                   { nNumberOfBytesToWrite }
  EmitInstr('PUSH ESI');                   { lpBuffer             }
  EmitInstr('PUSH DWORD PTR [FILE_WRHND]');{ hFile                }
  EmitInstr('CALL WriteFile');
  EmitLabel(TP_RT_PFX + 'FPS_D');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_EOLN_FILE : tester si char courant est CR/LF --- }
  { [ESP+4]=adresse variable fichier                                }
  { Retourne EAX=1 si EOL, EAX=0 sinon                             }
  { Verifie le buffer de lecture - le prochain caractere est CR/LF  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'EOLN_FILE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');    { adresse variable fichier }
  { Verifier s il y a des donnees en buffer }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BUFPOS]');
  EmitInstr('CMP EAX,DWORD PTR [FILE_BUFEND]');
  EmitInstr('JAE ' + TP_RT_PFX + 'EN_RD');
  { Il y a des donnees : tester le caractere courant }
  EmitInstr('LEA EDX,[FILE_RDBUF]');
  EmitInstr('ADD EDX,EAX');
  EmitInstr('MOVZX EAX,BYTE PTR [EDX]');
  EmitInstr('CMP AL,13');                      { CR ? }
  EmitInstr('JE ' + TP_RT_PFX + 'EN_YES');
  EmitInstr('CMP AL,10');                      { LF ? }
  EmitInstr('JE ' + TP_RT_PFX + 'EN_YES');
  EmitInstr('XOR EAX,EAX');                   { pas EOL }
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'EN_RD');
  { Buffer vide : si EOF => EOL=true, sinon lire }
  EmitInstr('CMP DWORD PTR [FILE_EOFFLG],1');
  EmitInstr('JE ' + TP_RT_PFX + 'EN_YES');
  { Remplir le buffer }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET FILE_BYTESRD');
  EmitInstr('PUSH 256');
  EmitInstr('PUSH OFFSET FILE_RDBUF');
  EmitInstr('PUSH DWORD PTR [EBX]');           { file handle }
  EmitInstr('CALL ReadFile');
  EmitInstr('MOV EAX,DWORD PTR [FILE_BYTESRD]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'EN_EOF');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  { Tester le premier caractere }
  EmitInstr('MOVZX EAX,BYTE PTR [FILE_RDBUF]');
  EmitInstr('CMP AL,13');
  EmitInstr('JE ' + TP_RT_PFX + 'EN_YES');
  EmitInstr('CMP AL,10');
  EmitInstr('JE ' + TP_RT_PFX + 'EN_YES');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'EN_EOF');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],1');
  EmitLabel(TP_RT_PFX + 'EN_YES');
  EmitInstr('MOV EAX,1');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_EOLN_STDIN : tester EOL sur stdin -------------- }
  { Retourne EAX=1 si stdin EOF ou dernier char CR/LF, 0 sinon    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'EOLN_STDIN');
  EmitInstr('MOV EAX,DWORD PTR [STDIN_EOF]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'ES_YES');
  { Pas EOF stdin : pour l instant retourne False }
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'ES_YES');
  EmitInstr('MOV EAX,1');
  EmitInstr('RET');

  { ------ _TPRT_SEEKEOF_FILE : sauter blancs puis tester EOF --- }
  { [ESP+4]=adresse variable fichier                                }
  { Retourne EAX=1 si EOF apres blancs, EAX=0 sinon                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SEEKEOF_FILE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
  EmitLabel(TP_RT_PFX + 'SE_LP');
  { Verifier le buffer }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BUFPOS]');
  EmitInstr('CMP EAX,DWORD PTR [FILE_BUFEND]');
  EmitInstr('JAE ' + TP_RT_PFX + 'SE_RD');
  { Tester le caractere courant }
  EmitInstr('LEA ESI,[FILE_RDBUF]');
  EmitInstr('ADD ESI,EAX');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('CMP AL,32');                     { espace }
  EmitInstr('JE ' + TP_RT_PFX + 'SE_SK');
  EmitInstr('CMP AL,9');                      { tab }
  EmitInstr('JE ' + TP_RT_PFX + 'SE_SK');
  EmitInstr('CMP AL,13');                     { CR }
  EmitInstr('JE ' + TP_RT_PFX + 'SE_SK');
  EmitInstr('CMP AL,10');                     { LF }
  EmitInstr('JE ' + TP_RT_PFX + 'SE_SK');
  { Caractere non-blanc : pas EOF }
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SE_SK');
  EmitInstr('INC DWORD PTR [FILE_BUFPOS]');
  EmitInstr('JMP ' + TP_RT_PFX + 'SE_LP');
  EmitLabel(TP_RT_PFX + 'SE_RD');
  { Buffer vide : verifier EOF }
  EmitInstr('CMP DWORD PTR [FILE_EOFFLG],1');
  EmitInstr('JE ' + TP_RT_PFX + 'SE_YES');
  { Remplir le buffer }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET FILE_BYTESRD');
  EmitInstr('PUSH 256');
  EmitInstr('PUSH OFFSET FILE_RDBUF');
  EmitInstr('PUSH DWORD PTR [EBX]');
  EmitInstr('CALL ReadFile');
  EmitInstr('MOV EAX,DWORD PTR [FILE_BYTESRD]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SE_SET');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'SE_LP');
  EmitLabel(TP_RT_PFX + 'SE_SET');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],1');
  EmitLabel(TP_RT_PFX + 'SE_YES');
  EmitInstr('MOV EAX,1');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SEEKEOLN_FILE : sauter blancs puis tester EOL -- }
  { [ESP+4]=adresse variable fichier                                }
  { Retourne EAX=1 si EOL apres blancs, EAX=0 sinon                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SEEKEOLN_FILE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
  EmitLabel(TP_RT_PFX + 'SL_LP');
  { Verifier le buffer }
  EmitInstr('MOV EAX,DWORD PTR [FILE_BUFPOS]');
  EmitInstr('CMP EAX,DWORD PTR [FILE_BUFEND]');
  EmitInstr('JAE ' + TP_RT_PFX + 'SL_RD');
  { Tester le caractere courant }
  EmitInstr('LEA ESI,[FILE_RDBUF]');
  EmitInstr('ADD ESI,EAX');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('CMP AL,32');                     { espace }
  EmitInstr('JE ' + TP_RT_PFX + 'SL_SK');
  EmitInstr('CMP AL,9');                      { tab }
  EmitInstr('JE ' + TP_RT_PFX + 'SL_SK');
  { Pas espace/tab : est-ce CR/LF ? }
  EmitInstr('CMP AL,13');                     { CR }
  EmitInstr('JE ' + TP_RT_PFX + 'SL_YES');
  EmitInstr('CMP AL,10');                     { LF }
  EmitInstr('JE ' + TP_RT_PFX + 'SL_YES');
  { Caractere normal : pas EOLN }
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SL_SK');
  EmitInstr('INC DWORD PTR [FILE_BUFPOS]');
  EmitInstr('JMP ' + TP_RT_PFX + 'SL_LP');
  EmitLabel(TP_RT_PFX + 'SL_RD');
  { Buffer vide : si EOF => EOL=true }
  EmitInstr('CMP DWORD PTR [FILE_EOFFLG],1');
  EmitInstr('JE ' + TP_RT_PFX + 'SL_YES');
  { Remplir le buffer }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET FILE_BYTESRD');
  EmitInstr('PUSH 256');
  EmitInstr('PUSH OFFSET FILE_RDBUF');
  EmitInstr('PUSH DWORD PTR [EBX]');
  EmitInstr('CALL ReadFile');
  EmitInstr('MOV EAX,DWORD PTR [FILE_BYTESRD]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SL_SET');
  EmitInstr('MOV DWORD PTR [FILE_BUFEND],EAX');
  EmitInstr('MOV DWORD PTR [FILE_BUFPOS],0');
  EmitInstr('JMP ' + TP_RT_PFX + 'SL_LP');
  EmitLabel(TP_RT_PFX + 'SL_SET');
  EmitInstr('MOV DWORD PTR [FILE_EOFFLG],1');
  EmitLabel(TP_RT_PFX + 'SL_YES');
  EmitInstr('MOV EAX,1');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ================================================================ }
  { Appele une seule fois, remplit PARAM_PTRS et PARAM_ARGC/COUNT }
  { Gere les guillemets doubles pour les arguments avec espaces   }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PARSECMD');
  EmitInstr('CMP DWORD PTR [PARAM_PARSED],1');
  EmitInstr('JE ' + TP_RT_PFX + 'PC_DN');
  EmitInstr('PUSHAD');
  { Obtenir la ligne de commande }
  EmitInstr('CALL GetCommandLineA');
  { Copier dans PARAM_BUF }
  EmitInstr('MOV ESI,EAX');
  EmitInstr('LEA EDI,[PARAM_BUF]');
  EmitInstr('MOV ECX,1023');
  EmitLabel(TP_RT_PFX + 'PC_CP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'PC_CE');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'PC_CP');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitLabel(TP_RT_PFX + 'PC_CE');
  { Parser les arguments }
  { ESI parcourt PARAM_BUF, EDX pointe dans PARAM_PTRS }
  EmitInstr('LEA ESI,[PARAM_BUF]');
  EmitInstr('LEA EDX,[PARAM_PTRS]');
  EmitInstr('XOR ECX,ECX');             { argc = 0 }
  EmitLabel(TP_RT_PFX + 'PC_SK');
  { Sauter les espaces }
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PC_FN');
  EmitInstr('CMP BYTE PTR [ESI],32');
  EmitInstr('JNE ' + TP_RT_PFX + 'PC_NW');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PC_SK');
  EmitLabel(TP_RT_PFX + 'PC_NW');
  { Debut d un argument }
  EmitInstr('CMP ECX,64');
  EmitInstr('JGE ' + TP_RT_PFX + 'PC_FN');
  { Stocker pointeur : [EDX] = ESI, EDX avance de 4 }
  EmitInstr('MOV DWORD PTR [EDX],ESI');
  EmitInstr('ADD EDX,4');
  EmitInstr('INC ECX');
  { Verifier si guillemet }
  EmitInstr('CMP BYTE PTR [ESI],34');   { guillemet double }
  EmitInstr('JNE ' + TP_RT_PFX + 'PC_UQ');
  { Argument entre guillemets : avancer apres le guillemet ouvrant }
  EmitInstr('INC ESI');
  EmitInstr('MOV DWORD PTR [EDX-4],ESI'); { corriger le pointeur }
  EmitLabel(TP_RT_PFX + 'PC_QT');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PC_FN');
  EmitInstr('CMP BYTE PTR [ESI],34');   { guillemet fermant }
  EmitInstr('JE ' + TP_RT_PFX + 'PC_QE');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PC_QT');
  EmitLabel(TP_RT_PFX + 'PC_QE');
  EmitInstr('MOV BYTE PTR [ESI],0');    { terminer l argument }
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PC_SK');
  EmitLabel(TP_RT_PFX + 'PC_UQ');
  { Argument sans guillemets : avancer jusqu au prochain espace ou fin }
  EmitLabel(TP_RT_PFX + 'PC_CH');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PC_FN');
  EmitInstr('CMP BYTE PTR [ESI],32');
  EmitInstr('JE ' + TP_RT_PFX + 'PC_SP');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PC_CH');
  EmitLabel(TP_RT_PFX + 'PC_SP');
  EmitInstr('MOV BYTE PTR [ESI],0');    { terminer l argument }
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'PC_SK');
  EmitLabel(TP_RT_PFX + 'PC_FN');
  { ECX = nombre total d arguments (argc) }
  EmitInstr('MOV DWORD PTR [PARAM_ARGC],ECX');
  { ParamCount = argc - 1 (sans argv[0]), minimum 0 }
  EmitInstr('DEC ECX');
  EmitInstr('CMP ECX,0');
  EmitInstr('JGE ' + TP_RT_PFX + 'PC_OK');
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'PC_OK');
  EmitInstr('MOV DWORD PTR [PARAM_COUNT],ECX');
  EmitInstr('MOV DWORD PTR [PARAM_PARSED],1');
  EmitInstr('POPAD');
  EmitLabel(TP_RT_PFX + 'PC_DN');
  EmitInstr('RET');

  { ------ _TPRT_PARAMCOUNT : retourner nombre de params -------- }
  { Sortie : EAX = nombre de parametres (sans argv[0])             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PARAMCOUNT');
  EmitInstr('CALL ' + TP_RT_PFX + 'PARSECMD');
  EmitInstr('MOV EAX,DWORD PTR [PARAM_COUNT]');
  EmitInstr('RET');

  { ------ _TPRT_PARAMSTR : retourner param N -> ASCIIZ ---------- }
  { Parametre : [ESP+4] = index N (0 = exe, 1..N = arguments)      }
  { Sortie : EAX = pointeur vers chaine ASCIIZ                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PARAMSTR');
  EmitInstr('CALL ' + TP_RT_PFX + 'PARSECMD');
  EmitInstr('MOV ECX,DWORD PTR [ESP+4]');
  { Verifier si N < argc }
  EmitInstr('CMP ECX,DWORD PTR [PARAM_ARGC]');
  EmitInstr('JGE ' + TP_RT_PFX + 'PS_EM');
  { Calculer adresse : EAX = PARAM_PTRS + ECX*4 }
  EmitInstr('LEA EAX,[PARAM_PTRS]');
  EmitInstr('SHL ECX,2');                { ECX = ECX * 4 }
  EmitInstr('ADD EAX,ECX');
  EmitInstr('MOV EAX,DWORD PTR [EAX]'); { dereferencer }
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'PS_EM');
  { Index hors limites : retourner chaine vide }
  EmitInstr('LEA EAX,[STRTMP]');
  EmitInstr('MOV BYTE PTR [EAX],0');
  EmitInstr('RET');

  { ------ _TPRT_SQRT : racine carree entiere ---------- }
  { Entree : EAX = valeur. Sortie : EAX = sqrt(EAX)     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SQRT');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SQ_D');
  EmitInstr('MOV ECX,EAX');       { n = valeur }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('SHR EAX,1');         { x = n/2 (approximation initiale) }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SQ_L');
  EmitInstr('MOV EAX,1');         { si n=1 -> sqrt=1 }
  EmitInstr('JMP ' + TP_RT_PFX + 'SQ_D');
  EmitLabel(TP_RT_PFX + 'SQ_L');
  { Newton-Raphson : x = (x + n/x) / 2 }
  EmitInstr('MOV EBX,EAX');       { sauver x_old }
  EmitInstr('XOR EDX,EDX');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,ECX');       { EAX = n }
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');           { EAX = n/x_old }
  EmitInstr('POP EDX');           { EDX = x_old }
  EmitInstr('ADD EAX,EDX');       { EAX = x_old + n/x_old }
  EmitInstr('SHR EAX,1');         { EAX = (x_old + n/x_old) / 2 }
  EmitInstr('CMP EAX,EBX');
  EmitInstr('JB ' + TP_RT_PFX + 'SQ_L'); { if x < x_old, continue }
  EmitInstr('MOV EAX,EBX');       { retourner x_old (converge) }
  EmitLabel(TP_RT_PFX + 'SQ_D');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_SIN : stub sinus (retourne 0) ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SIN');
  EmitComment('sin() stub : retourne 0 en mode entier');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_COS : stub cosinus (retourne 1) ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'COS');
  EmitComment('cos() stub : retourne 1 en mode entier');
  EmitInstr('MOV EAX,1');
  EmitInstr('RET');

  { ------ _TPRT_ARCTAN : stub arc tangente (retourne 0) ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ARCTAN');
  EmitComment('arctan() stub : retourne 0 en mode entier');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_EXP : stub exponentielle (retourne 1) ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'EXP');
  EmitComment('exp() stub : retourne 1 en mode entier');
  EmitInstr('MOV EAX,1');
  EmitInstr('RET');

  { ------ _TPRT_LN : stub logarithme (retourne 0) ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LN');
  EmitComment('ln() stub : retourne 0 en mode entier');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ====== SANE Runtime Helpers ====== }

  { ------ _TPRT_SANE_SIGNNUM : retourne -1/0/1 selon signe de EAX --- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_SIGNNUM');
  EmitComment('SANE SIGNNUM(x) : -1 si x<0, 0 si x=0, 1 si x>0');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_SIGN_DONE');
  EmitInstr('JS ' + TP_RT_PFX + 'SN_SIGN_NEG');
  EmitInstr('MOV EAX,1');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_SIGN_NEG');
  EmitInstr('MOV EAX,0FFFFFFFFh');
  EmitLabel(TP_RT_PFX + 'SN_SIGN_DONE');
  EmitInstr('RET');

  { ------ _TPRT_SANE_CLASSNUM : 3=ZeroNum, 4=NormalNum -------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_CLASSNUM');
  EmitComment('SANE CLASSxxx(x) : 3 si x=0, 4 sinon');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SN_CLASS_NORM');
  EmitInstr('MOV EAX,3');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_CLASS_NORM');
  EmitInstr('MOV EAX,4');
  EmitInstr('RET');

  { ------ _TPRT_SANE_COPYSIGN : |x| avec signe de y ---------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_COPYSIGN');
  EmitComment('SANE COPYSIGN(x,y) : |x| avec signe de y');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('CDQ');
  EmitInstr('XOR EAX,EDX');
  EmitInstr('SUB EAX,EDX');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JNS ' + TP_RT_PFX + 'SN_CSIGN_POS');
  EmitInstr('NEG EAX');
  EmitLabel(TP_RT_PFX + 'SN_CSIGN_POS');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_LOG2 : log2 entier (boucle SHR) ---------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_LOG2');
  EmitComment('SANE LOG2/LOGB(x) : floor(log2(x)) via boucle SHR');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JLE ' + TP_RT_PFX + 'SN_LOG2_ZERO');
  EmitInstr('PUSH ECX');
  EmitInstr('XOR ECX,ECX');          { ECX = compteur de bits }
  EmitLabel(TP_RT_PFX + 'SN_LOG2_LP');
  EmitInstr('SHR EAX,1');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_LOG2_D');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_LOG2_LP');
  EmitLabel(TP_RT_PFX + 'SN_LOG2_D');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('POP ECX');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_LOG2_ZERO');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_SANE_EXP2 : 2^x via boucle -------------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_EXP2');
  EmitComment('SANE EXP2(x) : 2^x par boucle de decalage');
  EmitInstr('MOV ECX,EAX');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JS ' + TP_RT_PFX + 'SN_EXP2_ZERO');
  EmitInstr('CMP ECX,30');
  EmitInstr('JG ' + TP_RT_PFX + 'SN_EXP2_MAX');  { 2^31 depasse signed 32-bit }
  EmitInstr('MOV EAX,1');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_EXP2_DONE');
  EmitLabel(TP_RT_PFX + 'SN_EXP2_LP');
  EmitInstr('SHL EAX,1');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SN_EXP2_LP');
  EmitLabel(TP_RT_PFX + 'SN_EXP2_DONE');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_EXP2_MAX');
  EmitInstr('MOV EAX,7FFFFFFFh');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_EXP2_ZERO');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_SANE_SCALB : x * 2^n (boucle) ---------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_SCALB');
  EmitComment('SANE SCALB(n,x) : x * 2^n par boucle');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV ECX,[EBP+12]');     { n }
  EmitInstr('MOV EAX,[EBP+8]');      { x }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_SCALB_DONE');
  EmitInstr('JS ' + TP_RT_PFX + 'SN_SCALB_NEG');
  EmitInstr('CMP ECX,30');
  EmitInstr('JG ' + TP_RT_PFX + 'SN_SCALB_OVF');
  EmitLabel(TP_RT_PFX + 'SN_SCALB_SL');
  EmitInstr('SHL EAX,1');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SN_SCALB_SL');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_SCALB_DONE');
  EmitLabel(TP_RT_PFX + 'SN_SCALB_OVF');
  EmitInstr('MOV EAX,7FFFFFFFh');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_SCALB_DONE');
  EmitLabel(TP_RT_PFX + 'SN_SCALB_NEG');
  EmitInstr('NEG ECX');
  EmitInstr('CMP ECX,31');
  EmitInstr('JGE ' + TP_RT_PFX + 'SN_SCALB_UND');
  EmitInstr('MOV EBX,2');           { diviseur = 2 }
  EmitLabel(TP_RT_PFX + 'SN_SCALB_SR');
  EmitInstr('CDQ');                  { sign-extend EAX into EDX:EAX }
  EmitInstr('IDIV EBX');            { EAX = EAX / 2 (signed) }
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SN_SCALB_SR');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_SCALB_DONE');
  EmitLabel(TP_RT_PFX + 'SN_SCALB_UND');
  EmitInstr('XOR EAX,EAX');
  EmitLabel(TP_RT_PFX + 'SN_SCALB_DONE');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_XPWRI : x^i par multiplication iterative ------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_XPWRI');
  EmitComment('SANE XPWRI(x,i) / XPWRY(x,y) : x^i entier');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_XPWRI_ONE');
  EmitInstr('JS ' + TP_RT_PFX + 'SN_XPWRI_NEG');
  EmitInstr('MOV EDX,EAX');
  EmitInstr('DEC ECX');
  EmitLabel(TP_RT_PFX + 'SN_XPWRI_LOOP');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_XPWRI_DONE');
  EmitInstr('IMUL EAX,EDX');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_XPWRI_LOOP');
  EmitLabel(TP_RT_PFX + 'SN_XPWRI_NEG');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_XPWRI_DONE');
  EmitLabel(TP_RT_PFX + 'SN_XPWRI_ONE');
  EmitInstr('MOV EAX,1');
  EmitLabel(TP_RT_PFX + 'SN_XPWRI_DONE');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_NEXTNUM : x+1 si y>x, x-1 si y<x, x si y=x --- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_NEXTNUM');
  EmitComment('SANE NEXTxxx(x,y) : entier suivant vers y');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('CMP ECX,EAX');
  EmitInstr('JG ' + TP_RT_PFX + 'SN_NEXT_INC');
  EmitInstr('JL ' + TP_RT_PFX + 'SN_NEXT_DEC');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_NEXT_DONE');
  EmitLabel(TP_RT_PFX + 'SN_NEXT_INC');
  EmitInstr('INC EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_NEXT_DONE');
  EmitLabel(TP_RT_PFX + 'SN_NEXT_DEC');
  EmitInstr('DEC EAX');
  EmitLabel(TP_RT_PFX + 'SN_NEXT_DONE');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_COMPOUND : (1+r)^n ----------------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_COMPOUND');
  EmitComment('SANE COMPOUND(r,n) : (1+r)^n en entier');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');
  EmitInstr('INC EAX');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JLE ' + TP_RT_PFX + 'SN_COMP_ONE');
  EmitInstr('MOV EDX,EAX');
  EmitInstr('DEC ECX');
  EmitLabel(TP_RT_PFX + 'SN_COMP_LOOP');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_COMP_DONE');
  EmitInstr('IMUL EAX,EDX');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_COMP_LOOP');
  EmitLabel(TP_RT_PFX + 'SN_COMP_ONE');
  EmitInstr('MOV EAX,1');
  EmitLabel(TP_RT_PFX + 'SN_COMP_DONE');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_ANNUITY : stub retourne n ---------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_ANNUITY');
  EmitComment('SANE ANNUITY(r,n) stub : retourne n');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+8]');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_RELATION : 0=GT, 1=LT, 2=EQ ------------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_RELATION');
  EmitComment('SANE RELATION(x,y) : 0 si x>y, 1 si x<y, 2 si x=y');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('CMP EAX,ECX');
  EmitInstr('JG ' + TP_RT_PFX + 'SN_REL_GT');
  EmitInstr('JL ' + TP_RT_PFX + 'SN_REL_LT');
  EmitInstr('MOV EAX,2');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_REL_DONE');
  EmitLabel(TP_RT_PFX + 'SN_REL_GT');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_REL_DONE');
  EmitLabel(TP_RT_PFX + 'SN_REL_LT');
  EmitInstr('MOV EAX,1');
  EmitLabel(TP_RT_PFX + 'SN_REL_DONE');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_REMAINDER : x MOD y, quotient dans [Quo] ------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_REMAINDER');
  EmitComment('SANE REMAINDER(x,y,Var Quo) : EAX=x MOD y, [Quo]=x DIV y');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+16]');
  EmitInstr('MOV ECX,[EBP+12]');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_REM_ZERO');
  EmitInstr('CDQ');
  EmitInstr('IDIV ECX');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('MOV [ECX],EAX');
  EmitInstr('MOV EAX,EDX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_REM_ZERO');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('MOV DWORD PTR [ECX],0');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_RANDOMX : LCG update via Var x ----------------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_RANDOMX');
  EmitComment('SANE RANDOMX(Var x) : LCG pseudo-aleatoire');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV ECX,[EBP+8]');
  EmitInstr('MOV EAX,[ECX]');
  EmitInstr('IMUL EAX,EAX,1103515245');  { LCG glibc: a=1103515245, c=12345 }
  EmitInstr('ADD EAX,12345');
  EmitInstr('MOV [ECX],EAX');
  EmitInstr('SHR EAX,16');
  EmitInstr('AND EAX,7FFFh');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_NUM2STR : conversion entier vers chaine -------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_NUM2STR');
  EmitComment('SANE NUM2STR(f,x,Var s) : convertit x en chaine dans s');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,[EBP+12]');     { x = valeur numerique }
  EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');
  EmitInstr('LEA ESI,[NUMBUF]');     { source = NUMBUF (ASCIIZ) }
  EmitInstr('MOV EDI,[EBP+8]');      { dest = adresse de la chaine s }
  EmitInstr('CALL ' + TP_RT_PFX + 'STRASSIGN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SANE_LOG10 : log base 10 entier ------------------- }
  { En mode entier, log10(x) = floor(log10(x))                       }
  { On divise par 10 en boucle et on compte les divisions            }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_LOG10');
  EmitComment('TRANSCEND LOG(x) : floor(log10(x)), 0 si x<=0');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JLE ' + TP_RT_PFX + 'SN_LOG10_ZERO');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('MOV EBX,EAX');           { EBX = x }
  EmitInstr('XOR ECX,ECX');           { ECX = compteur }
  EmitInstr('MOV EAX,10');
  EmitLabel(TP_RT_PFX + 'SN_LOG10_LP');
  EmitInstr('CMP EBX,10');
  EmitInstr('JB ' + TP_RT_PFX + 'SN_LOG10_D');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,EBX');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('MOV EBX,10');
  EmitInstr('DIV EBX');               { EAX = EBX / 10 }
  EmitInstr('MOV EBX,EAX');           { EBX = quotient }
  EmitInstr('POP EAX');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SN_LOG10_LP');
  EmitLabel(TP_RT_PFX + 'SN_LOG10_D');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_LOG10_ZERO');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_SANE_PWROFTEN : 10^n entier ----------------------- }
  { Calcule 10^n par multiplication iterative                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SANE_PWROFTEN');
  EmitComment('TRANSCEND PwrOfTen(n) : 10^n entier, 0 si n<0');
  EmitInstr('MOV ECX,EAX');           { ECX = n }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JS ' + TP_RT_PFX + 'SN_POT_ZERO');  { n<0 -> 0 }
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_POT_ONE');   { n=0 -> 1 }
  EmitInstr('MOV EAX,1');
  EmitLabel(TP_RT_PFX + 'SN_POT_LP');
  EmitInstr('IMUL EAX,EAX,10');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SN_POT_LP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_POT_ONE');
  EmitInstr('MOV EAX,1');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SN_POT_ZERO');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('RET');

  { ------ _TPRT_RANDOM : generateur pseudo-aleatoire LCG ------- }
  { Sortie : EAX = nouveau nombre aleatoire                       }
  { Constantes LCG de glibc : a=1103515245, c=12345               }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'RANDOM');
  EmitInstr('MOV EAX,DWORD PTR [RAND_SEED]');
  EmitInstr('IMUL EAX,EAX,1103515245');
  EmitInstr('ADD EAX,12345');
  EmitInstr('MOV DWORD PTR [RAND_SEED],EAX');
  EmitInstr('SHR EAX,16');         { prendre les bits de poids fort }
  EmitInstr('AND EAX,7FFFh');      { masquer a 15 bits (0..32767) }
  EmitInstr('RET');

  { ------ _TPRT_RANDOMIZE : initialiser graine avec GetTickCount --- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'RANDOMIZE');
  EmitInstr('PUSHAD');
  EmitInstr('CALL GetTickCount');
  EmitInstr('MOV DWORD PTR [RAND_SEED],EAX');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_ENVCOUNT : nombre de variables d environnement --- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ENVCOUNT');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('CALL GetEnvironmentStringsA');
  EmitInstr('MOV ESI,EAX');
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'ENVC_L');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'ENVC_D');
  EmitInstr('INC ECX');
  EmitLabel(TP_RT_PFX + 'ENVC_S');
  EmitInstr('INC ESI');
  EmitInstr('CMP BYTE PTR [ESI-1],0');
  EmitInstr('JNE ' + TP_RT_PFX + 'ENVC_S');
  EmitInstr('JMP ' + TP_RT_PFX + 'ENVC_L');
  EmitLabel(TP_RT_PFX + 'ENVC_D');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_ENVSTR : retourner N-ieme variable d environnement --- }
  { [ESP+4] = index (1-based), retour EAX = ptr chaine ASCIIZ         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ENVSTR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('CALL GetEnvironmentStringsA');
  EmitInstr('MOV ESI,EAX');
  EmitInstr('MOV ECX,DWORD PTR [EBP+8]');  { index 1-based }
  EmitInstr('DEC ECX');                     { 0-based }
  EmitLabel(TP_RT_PFX + 'ENVS_L');
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + TP_RT_PFX + 'ENVS_F');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'ENVS_E');
  EmitLabel(TP_RT_PFX + 'ENVS_K');
  EmitInstr('INC ESI');
  EmitInstr('CMP BYTE PTR [ESI-1],0');
  EmitInstr('JNE ' + TP_RT_PFX + 'ENVS_K');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'ENVS_L');
  EmitLabel(TP_RT_PFX + 'ENVS_F');
  EmitInstr('MOV EAX,ESI');       { point to the N-th string }
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'ENVS_E');
  EmitInstr('MOV EAX,ESI');       { empty string if out of range }
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_UNPACKTIME : decomposer date/heure empaquetee --- }
  { [ESP+8] = packed LongInt, [ESP+4] = ptr DateTime record       }
  { DateTime = record Year,Month,Day,Hour,Min,Sec : Word end      }
  { Packed: bits 0-4=sec/2, 5-10=min, 11-15=hour, 16-20=day,     }
  {         21-24=month, 25-31=year-1980                           }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'UNPACKTIME');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');   { packed time }
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');    { ptr to DateTime }
  { Sec = (bits 0-4) * 2 }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('AND ECX,1Fh');
  EmitInstr('SHL ECX,1');
  EmitInstr('MOV WORD PTR [EDX+10],CX');      { Sec at offset 10 }
  { Min = bits 5-10 }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('SHR ECX,5');
  EmitInstr('AND ECX,3Fh');
  EmitInstr('MOV WORD PTR [EDX+8],CX');       { Min at offset 8 }
  { Hour = bits 11-15 }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('SHR ECX,11');
  EmitInstr('AND ECX,1Fh');
  EmitInstr('MOV WORD PTR [EDX+6],CX');       { Hour at offset 6 }
  { Day = bits 16-20 }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('SHR ECX,16');
  EmitInstr('AND ECX,1Fh');
  EmitInstr('MOV WORD PTR [EDX+4],CX');       { Day at offset 4 }
  { Month = bits 21-24 }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('SHR ECX,21');
  EmitInstr('AND ECX,0Fh');
  EmitInstr('MOV WORD PTR [EDX+2],CX');       { Month at offset 2 }
  { Year = (bits 25-31) + 1980 }
  EmitInstr('SHR EAX,25');
  EmitInstr('AND EAX,7Fh');
  EmitInstr('ADD EAX,1980');
  EmitInstr('MOV WORD PTR [EDX],AX');          { Year at offset 0 }
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_PACKTIME : empaqueter date/heure ---------------  }
  { [ESP+8] = ptr DateTime record, [ESP+4] = ptr LongInt result   }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PACKTIME');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');   { ptr to DateTime }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');    { ptr to result }
  { Year }
  EmitInstr('MOVZX EAX,WORD PTR [ESI]');
  EmitInstr('SUB EAX,1980');
  EmitInstr('AND EAX,7Fh');
  EmitInstr('SHL EAX,25');
  EmitInstr('MOV EBX,EAX');
  { Month }
  EmitInstr('MOVZX EAX,WORD PTR [ESI+2]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('SHL EAX,21');
  EmitInstr('OR EBX,EAX');
  { Day }
  EmitInstr('MOVZX EAX,WORD PTR [ESI+4]');
  EmitInstr('AND EAX,1Fh');
  EmitInstr('SHL EAX,16');
  EmitInstr('OR EBX,EAX');
  { Hour }
  EmitInstr('MOVZX EAX,WORD PTR [ESI+6]');
  EmitInstr('AND EAX,1Fh');
  EmitInstr('SHL EAX,11');
  EmitInstr('OR EBX,EAX');
  { Min }
  EmitInstr('MOVZX EAX,WORD PTR [ESI+8]');
  EmitInstr('AND EAX,3Fh');
  EmitInstr('SHL EAX,5');
  EmitInstr('OR EBX,EAX');
  { Sec / 2 }
  EmitInstr('MOVZX EAX,WORD PTR [ESI+10]');
  EmitInstr('SHR EAX,1');
  EmitInstr('AND EAX,1Fh');
  EmitInstr('OR EBX,EAX');
  EmitInstr('MOV DWORD PTR [EDI],EBX');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_GETFTIME : lire horodatage d un fichier --------- }
  { [ESP+8] = ptr to file var, [ESP+4] = ptr to Time LongInt       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GETFTIME');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Get handle from FILE_HANDLE global (file handle stored there by runtime) }
  EmitInstr('MOV EAX,DWORD PTR [FILE_HANDLE]');
  { GetFileTime(hFile, NULL, NULL, &ftWrite) - use 16 bytes on stack for FILETIME }
  EmitInstr('SUB ESP,16');
  EmitInstr('MOV EDI,ESP');
  EmitInstr('PUSH EDI');           { lpLastWriteTime }
  EmitInstr('PUSH 0');             { lpLastAccessTime = NULL }
  EmitInstr('PUSH 0');             { lpCreationTime = NULL }
  EmitInstr('PUSH EAX');           { hFile }
  EmitInstr('CALL GetFileTime');
  { Convert FILETIME to DOS time via FileTimeToDosDateTime }
  EmitInstr('LEA EAX,[EDI+8]');    { space for DosDate and DosTime (2 words each) }
  EmitInstr('LEA ECX,[EDI+12]');
  EmitInstr('PUSH ECX');           { lpFatTime }
  EmitInstr('PUSH EAX');           { lpFatDate }
  EmitInstr('PUSH EDI');           { lpFileTime }
  EmitInstr('CALL FileTimeToDosDateTime');
  { Combine DosDate (high word) and DosTime (low word) into LongInt }
  EmitInstr('MOVZX EAX,WORD PTR [EDI+8]');    { DosDate }
  EmitInstr('SHL EAX,16');
  EmitInstr('MOVZX ECX,WORD PTR [EDI+12]');   { DosTime }
  EmitInstr('OR EAX,ECX');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');     { ptr to Time }
  EmitInstr('MOV DWORD PTR [EDX],EAX');
  EmitInstr('ADD ESP,16');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPRT_SETFTIME : definir horodatage d un fichier ------- }
  { [ESP+8] = ptr to file var, [ESP+4] = Time LongInt value        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SETFTIME');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitComment('SetFTime - stub Win32 (complex FILETIME conversion)');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 20 - ROUTINES RUNTIME GRAPH             [IMPLEMENTE]    }
{ ============================================================ }

Procedure EmitGraphRuntime;
Begin
  EmitBlankLine;
  EmitComment('============================================================');
  EmitComment(' RUNTIME GRAPH : routines d emulation graphique Windows     ');
  EmitComment('============================================================');

  { ------ _TPR_INITGRAPH : initialiser mode graphique --------- }
  { Parametres : [ESP+4]=Gd (var), [ESP+8]=Gm (var), [ESP+12]=Path }
  { Cree une fenetre Windows avec zone client 640x480              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INITGRAPH');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Si la fenetre est deja ouverte (Graph OU MSGraph), la reutiliser }
  EmitInstr('CMP DWORD PTR [GR_ACTIVE],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'IG_CREATE');
  { Fenetre deja ouverte : juste mettre a jour Gd et Gm }
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');   { Gd var }
  EmitInstr('MOV DWORD PTR [EDX],9');        { VGA = 9 }
  EmitInstr('MOV EDX,DWORD PTR [EBP+12]');  { Gm var }
  EmitInstr('MOV DWORD PTR [EDX],2');        { VGAHi = 2 }
  EmitInstr('MOV DWORD PTR [GR_RESULT],0'); { grOk }
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'IG_CREATE');
  { Obtenir hInstance }
  EmitInstr('PUSH 0');
  EmitInstr('CALL GetModuleHandleA');
  EmitInstr('MOV DWORD PTR [GR_HINST],EAX');
  { Remplir WNDCLASS avec zeros }
  EmitInstr('LEA EDI,[GR_CLSREC]');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('MOV ECX,10');
  EmitInstr('REP STOSD');         { zero fill 40 bytes }
  { Charger curseur fleche }
  EmitInstr('PUSH 32512');        { IDC_ARROW }
  EmitInstr('PUSH 0');
  EmitInstr('CALL LoadCursorA');
  EmitInstr('MOV DWORD PTR [GR_CLSREC+24],EAX');     { hCursor }
  { Remplir WNDCLASS : style=3(CS_HREDRAW|CS_VREDRAW), lpfnWndProc=DefWindowProcA }
  EmitInstr('MOV DWORD PTR [GR_CLSREC+0],3');        { style }
  { Charger adresse reelle de DefWindowProcA depuis l IAT }
  EmitInstr('MOV EAX,DWORD PTR [DefWindowProcA]');
  EmitInstr('MOV DWORD PTR [GR_CLSREC+4],EAX');      { lpfnWndProc }
  EmitInstr('MOV EAX,DWORD PTR [GR_HINST]');
  EmitInstr('MOV DWORD PTR [GR_CLSREC+16],EAX');     { hInstance }
  { Brush de fond noir : GetStockObject(BLACK_BRUSH=4) }
  EmitInstr('PUSH 4');                                { BLACK_BRUSH }
  EmitInstr('CALL GetStockObject');
  EmitInstr('MOV DWORD PTR [GR_CLSREC+28],EAX');     { hbrBackground }
  EmitInstr('LEA EAX,[GR_WNDCLASS]');
  EmitInstr('MOV DWORD PTR [GR_CLSREC+36],EAX');     { lpszClassName }
  { RegisterClass }
  EmitInstr('PUSH OFFSET GR_CLSREC');
  EmitInstr('CALL RegisterClassA');
  { CreateWindowExA : creer fenetre 640x480 + bordure }
  EmitInstr('PUSH 0');            { lpParam }
  EmitInstr('PUSH DWORD PTR [GR_HINST]'); { hInstance }
  EmitInstr('PUSH 0');            { hMenu }
  EmitInstr('PUSH 0');            { hWndParent }
  EmitInstr('PUSH 520');          { nHeight (480 + bordure) }
  EmitInstr('PUSH 660');          { nWidth  (640 + bordure) }
  EmitInstr('PUSH 100');          { Y }
  EmitInstr('PUSH 100');          { X }
  EmitInstr('PUSH 00CF0000h');    { WS_OVERLAPPEDWINDOW }
  EmitInstr('PUSH OFFSET GR_WNDTITLE');
  EmitInstr('PUSH OFFSET GR_WNDCLASS');
  EmitInstr('PUSH 0');            { dwExStyle }
  EmitInstr('CALL CreateWindowExA');
  EmitInstr('MOV DWORD PTR [GR_HWND],EAX');
  { ShowWindow(hWnd, SW_SHOW=5) }
  EmitInstr('PUSH 5');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ShowWindow');
  { UpdateWindow }
  EmitInstr('PUSH DWORD PTR [GR_HWND]');
  EmitInstr('CALL UpdateWindow');
  { GetDC }
  EmitInstr('PUSH DWORD PTR [GR_HWND]');
  EmitInstr('CALL GetDC');
  EmitInstr('MOV DWORD PTR [GR_HDC],EAX');
  { Creer pen et brush initiaux }
  EmitInstr('MOV DWORD PTR [GR_ACTIVE],1');
  { Initialiser le pen (blanc, solid, 1px) }
  EmitInstr('PUSH DWORD PTR [GR_PALETTE+60]');  { couleur 15 = blanc }
  EmitInstr('PUSH 1');                { width }
  EmitInstr('PUSH 0');                { PS_SOLID }
  EmitInstr('CALL CreatePen');
  EmitInstr('MOV DWORD PTR [GR_HPEN],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  { Initialiser le brush (noir) }
  EmitInstr('PUSH 0');
  EmitInstr('CALL CreateSolidBrush');
  EmitInstr('MOV DWORD PTR [GR_HBRUSH],EAX');
  { Fond transparent pour TextOut }
  EmitInstr('PUSH 1');               { TRANSPARENT }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SetBkMode');
  { Retourner les valeurs Gd et Gm }
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');   { Gd var }
  EmitInstr('MOV DWORD PTR [EDX],9');        { VGA = 9 }
  EmitInstr('MOV EDX,DWORD PTR [EBP+12]');  { Gm var }
  EmitInstr('MOV DWORD PTR [EDX],2');        { VGAHi = 2 }
  EmitInstr('MOV DWORD PTR [GR_RESULT],0');  { grOk }
  EmitInstr('MOV DWORD PTR [GR_DRIVER],9');
  EmitInstr('MOV DWORD PTR [GR_MODE],2');
  { Remplir GR_VIDCFG avec les infos de la configuration video }
  EmitInstr('LEA EDI,[GR_VIDCFG]');
  EmitInstr('MOV DWORD PTR [EDI+0],640');    { numxpixels  }
  EmitInstr('MOV DWORD PTR [EDI+4],480');    { numypixels  }
  EmitInstr('MOV DWORD PTR [EDI+8],80');     { numtextcols }
  EmitInstr('MOV DWORD PTR [EDI+12],25');    { numtextrows }
  EmitInstr('MOV DWORD PTR [EDI+16],16');    { numcolors   }
  EmitInstr('MOV DWORD PTR [EDI+20],4');     { bitsperpixel}
  EmitInstr('MOV DWORD PTR [EDI+24],1');     { numvideopages}
  EmitInstr('MOV DWORD PTR [EDI+28],18');    { mode=_VRes16Color}
  EmitInstr('MOV DWORD PTR [EDI+32],4');     { adapter=_VGA}
  EmitInstr('MOV DWORD PTR [EDI+36],7');     { monitor=_Analog}
  EmitInstr('MOV DWORD PTR [EDI+40],1024');  { memory=1024 KB}
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_CLOSEGRAPH : fermer le mode graphique ---------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CLOSEGRAPH');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Supprimer les objets GDI }
  EmitInstr('CMP DWORD PTR [GR_HPEN],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'CG_NP');
  EmitInstr('PUSH DWORD PTR [GR_HPEN]');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'CG_NP');
  EmitInstr('CMP DWORD PTR [GR_HBRUSH],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'CG_NB');
  EmitInstr('PUSH DWORD PTR [GR_HBRUSH]');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'CG_NB');
  EmitInstr('CMP DWORD PTR [GR_HFONT],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'CG_NF');
  EmitInstr('PUSH DWORD PTR [GR_HFONT]');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'CG_NF');
  { ReleaseDC }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('PUSH DWORD PTR [GR_HWND]');
  EmitInstr('CALL ReleaseDC');
  { DestroyWindow }
  EmitInstr('PUSH DWORD PTR [GR_HWND]');
  EmitInstr('CALL DestroyWindow');
  EmitInstr('MOV DWORD PTR [GR_ACTIVE],0');
  EmitInstr('MOV DWORD PTR [GR_HWND],0');
  EmitInstr('MOV DWORD PTR [GR_HDC],0');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_PUTPIXEL : dessiner un pixel ------------------- }
  { Push L-to-R: X,Y,Color -> [EBP+16]=X [EBP+12]=Y [EBP+8]=Color }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PUTPIXEL');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Convertir couleur palette -> COLORREF }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { Color index }
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');                    { COLORREF }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { Y }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SetPixel');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_GETPIXEL : lire couleur d un pixel ------------- }
  { La pile contient (du parseur) : x, y, GR_HDC (inutilise)     }
  { [EBP+8]=GR_HDC(ignore), [EBP+12]=y, [EBP+16]=x              }
  { Retourne COLORREF dans EAX                                    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GETPIXEL');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { Y }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL GetPixel');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_LINE : tracer une ligne ------------------------ }
  { Push L-to-R: x1,y1,x2,y2 -> [EBP+20]=x1 [EBP+16]=y1 [EBP+12]=x2 [EBP+8]=y2 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LINE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { MoveToEx(hdc, x1, y1, NULL) }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { Y1 }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { X1 }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL MoveToEx');
  { LineTo(hdc, x2, y2) }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { Y2 }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { X2 }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL LineTo');
  { Mettre a jour position courante }
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');
  EmitInstr('MOV DWORD PTR [GR_CPX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [GR_CPY],EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_LINETO : tracer ligne depuis position courante -- }
  { Parametres (push L-to-R) : x puis y -> [EBP+12]=x [EBP+8]=y  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LINETO');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH DWORD PTR [GR_CPY]');
  EmitInstr('PUSH DWORD PTR [GR_CPX]');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL MoveToEx');
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { Y }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL LineTo');
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');
  EmitInstr('MOV DWORD PTR [GR_CPX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [GR_CPY],EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_LINEREL : tracer ligne relative depuis CP ------- }
  { Parametres (push L-to-R) : Dx puis Dy -> [EBP+12]=Dx [EBP+8]=Dy }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'LINEREL');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH DWORD PTR [GR_CPY]');
  EmitInstr('PUSH DWORD PTR [GR_CPX]');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL MoveToEx');
  EmitInstr('MOV EAX,DWORD PTR [GR_CPX]');
  EmitInstr('ADD EAX,DWORD PTR [EBP+12]');  { CPX + Dx }
  EmitInstr('MOV DWORD PTR [GR_CPX],EAX');
  EmitInstr('MOV ECX,EAX');                  { ECX = new X }
  EmitInstr('MOV EAX,DWORD PTR [GR_CPY]');
  EmitInstr('ADD EAX,DWORD PTR [EBP+8]');   { CPY + Dy }
  EmitInstr('MOV DWORD PTR [GR_CPY],EAX');
  { LineTo(hdc, newX, newY) - stdcall R-to-L: Y, X, hdc }
  EmitInstr('PUSH EAX');                     { Y }
  EmitInstr('PUSH ECX');                     { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL LineTo');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_RECTANGLE : dessiner un rectangle -------------- }
  { Push L-to-R: X1,Y1,X2,Y2 -> [EBP+20]=X1 [EBP+16]=Y1 [EBP+12]=X2 [EBP+8]=Y2 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'RECTANGLE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Selectionner brush null pour ne pas remplir }
  EmitInstr('PUSH 5');               { NULL_BRUSH = GetStockObject(5) }
  EmitInstr('CALL GetStockObject');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('PUSH EAX');             { sauver ancien brush }
  { Rectangle(hdc, left, top, right, bottom) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { bottom = Y2 }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { right  = X2 }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { top    = Y1 }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { left   = X1 }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Rectangle');
  { Restaurer le brush }
  EmitInstr('POP EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_BAR : rectangle rempli ------------------------- }
  { Push L-to-R: X1,Y1,X2,Y2 -> [EBP+20]=X1 [EBP+16]=Y1 [EBP+12]=X2 [EBP+8]=Y2 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'BAR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Creer brush avec couleur de remplissage }
  EmitInstr('MOV EAX,DWORD PTR [GR_FILLCOLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitInstr('PUSH EAX');             { sauver handle }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('PUSH EAX');             { sauver ancien brush }
  { Rectangle(hdc, left, top, right, bottom) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { bottom = Y2 }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { right  = X2 }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { top    = Y1 }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { left   = X1 }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Rectangle');
  { Restaurer ancien brush et supprimer le nouveau }
  EmitInstr('POP EAX');              { ancien brush }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('POP EAX');              { nouveau brush }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL DeleteObject');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_BAR3D : barre 3D ------------------------------ }
  { Push L-to-R: X1,Y1,X2,Y2,Depth,Top                           }
  { -> [EBP+28]=X1 [EBP+24]=Y1 [EBP+20]=X2 [EBP+16]=Y2          }
  {    [EBP+12]=Depth [EBP+8]=Top                                 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'BAR3D');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Dessiner le rectangle principal (face) - push L-to-R: X1,Y1,X2,Y2 }
  EmitInstr('PUSH DWORD PTR [EBP+28]');    { X1 }
  EmitInstr('PUSH DWORD PTR [EBP+24]');    { Y1 }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { X2 }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { Y2 }
  EmitInstr('CALL ' + TP_RT_PFX + 'BAR');
  EmitInstr('ADD ESP,16');
  { Dessiner le contour du rectangle - push L-to-R: X1,Y1,X2,Y2 }
  EmitInstr('PUSH DWORD PTR [EBP+28]');    { X1 }
  EmitInstr('PUSH DWORD PTR [EBP+24]');    { Y1 }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { X2 }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { Y2 }
  EmitInstr('CALL ' + TP_RT_PFX + 'RECTANGLE');
  EmitInstr('ADD ESP,16');
  EmitComment('Bar3D top and side simplified (depth lines)');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_CIRCLE : dessiner un cercle -------------------- }
  { Push L-to-R: X,Y,Radius -> [EBP+16]=X [EBP+12]=Y [EBP+8]=Radius }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CIRCLE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Selectionner brush null }
  EmitInstr('PUSH 5');
  EmitInstr('CALL GetStockObject');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('PUSH EAX');
  { Ellipse(hdc, X-R, Y-R, X+R, Y+R) }
  EmitInstr('MOV ECX,DWORD PTR [EBP+16]');  { X }
  EmitInstr('MOV EDX,DWORD PTR [EBP+12]');  { Y }
  EmitInstr('MOV EBX,DWORD PTR [EBP+8]');   { R }
  EmitInstr('MOV EAX,EDX');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('PUSH EAX');                     { Y+R (bottom) }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('PUSH EAX');                     { X+R (right) }
  EmitInstr('MOV EAX,EDX');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('PUSH EAX');                     { Y-R (top) }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('PUSH EAX');                     { X-R (left) }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Ellipse');
  { Restaurer brush }
  EmitInstr('POP EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_ARC : dessiner un arc -------------------------- }
  { Parametres (push L-to-R) :                                     }
  {   x1=[EBP+36], y1=[EBP+32], x2=[EBP+28], y2=[EBP+24]         }
  {   x3=[EBP+20], y3=[EBP+16], x4=[EBP+12], y4=[EBP+8]          }
  { Appelle Win32 Arc(hdc, x1, y1, x2, y2, x3, y3, x4, y4)       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ARC');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Arc stdcall : push R-to-L = y4, x4, y3, x3, y2, x2, y1, x1, hdc }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { y4 - nYEndArc }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { x4 - nXEndArc }
  EmitInstr('PUSH DWORD PTR [EBP+16]');    { y3 - nYStartArc }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { x3 - nXStartArc }
  EmitInstr('PUSH DWORD PTR [EBP+24]');    { y2 - nBottomRect }
  EmitInstr('PUSH DWORD PTR [EBP+28]');    { x2 - nRightRect }
  EmitInstr('PUSH DWORD PTR [EBP+32]');    { y1 - nTopRect }
  EmitInstr('PUSH DWORD PTR [EBP+36]');    { x1 - nLeftRect }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');    { hdc }
  EmitInstr('CALL Arc');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_ELLIPSE : dessiner une ellipse ----------------- }
  { Push L-to-R: X,Y,StAngle,EndAngle,XR,YR                      }
  { -> [EBP+28]=X [EBP+24]=Y [EBP+20]=StAngle [EBP+16]=EndAngle  }
  {    [EBP+12]=XR [EBP+8]=YR                                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'ELLIPSE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Selectionner brush null }
  EmitInstr('PUSH 5');
  EmitInstr('CALL GetStockObject');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('PUSH EAX');
  { Ellipse(hdc, X-XR, Y-YR, X+XR, Y+YR) }
  EmitInstr('MOV ECX,DWORD PTR [EBP+28]');  { X }
  EmitInstr('MOV EDX,DWORD PTR [EBP+24]');  { Y }
  EmitInstr('MOV EBX,DWORD PTR [EBP+12]');  { XR }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { YR }
  EmitInstr('MOV EAX,EDX');
  EmitInstr('ADD EAX,ESI');
  EmitInstr('PUSH EAX');                     { Y+YR }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('PUSH EAX');                     { X+XR }
  EmitInstr('MOV EAX,EDX');
  EmitInstr('SUB EAX,ESI');
  EmitInstr('PUSH EAX');                     { Y-YR }
  EmitInstr('MOV EAX,ECX');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('PUSH EAX');                     { X-XR }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Ellipse');
  { Restaurer brush }
  EmitInstr('POP EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_FILLELLIPSE : ellipse remplie ------------------ }
  { Push L-to-R: X,Y,XR,YR -> [EBP+20]=X [EBP+16]=Y [EBP+12]=XR [EBP+8]=YR }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FILLELLIPSE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Creer brush fill }
  EmitInstr('MOV EAX,DWORD PTR [GR_FILLCOLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('PUSH EAX');
  { Ellipse(hdc, X-XR, Y-YR, X+XR, Y+YR) }
  EmitInstr('MOV ECX,DWORD PTR [EBP+20]');  { X }
  EmitInstr('MOV EDX,DWORD PTR [EBP+16]');  { Y }
  EmitInstr('MOV EBX,DWORD PTR [EBP+12]');  { XR }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { YR }
  EmitInstr('MOV EAX,EDX');
  EmitInstr('ADD EAX,ESI');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,EDX');
  EmitInstr('SUB EAX,ESI');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Ellipse');
  { Restaurer + nettoyer }
  EmitInstr('POP EAX');              { ancien brush }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('POP EAX');              { nouveau brush }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL DeleteObject');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_PIESLICE : secteur circulaire rempli ----------- }
  { Push L-to-R: X,Y,StAngle,EndAngle,Radius                     }
  { -> [EBP+24]=X [EBP+20]=Y [EBP+16]=StAngle [EBP+12]=EndAngle [EBP+8]=Radius }
  { Simplifie : on appelle CIRCLE comme stub                      }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PIESLICE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitComment('PieSlice simplifie -> cercle (stub)');
  EmitInstr('PUSH DWORD PTR [EBP+24]');    { X }
  EmitInstr('PUSH DWORD PTR [EBP+20]');    { Y }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { Radius }
  EmitInstr('CALL ' + TP_RT_PFX + 'CIRCLE');
  EmitInstr('ADD ESP,12');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_SECTOR : secteur elliptique rempli ------------- }
  { Push L-to-R: X,Y,StAngle,EndAngle,XR,YR                      }
  { -> [EBP+28]=X [EBP+24]=Y [EBP+20]=StAngle [EBP+16]=EndAngle  }
  {    [EBP+12]=XR [EBP+8]=YR                                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SECTOR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitComment('Sector simplifie -> ellipse remplie (stub)');
  EmitInstr('PUSH DWORD PTR [EBP+28]');    { X }
  EmitInstr('PUSH DWORD PTR [EBP+24]');    { Y }
  EmitInstr('PUSH DWORD PTR [EBP+12]');    { XR }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { YR }
  EmitInstr('CALL ' + TP_RT_PFX + 'FILLELLIPSE');
  EmitInstr('ADD ESP,16');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_FLOODFILL : remplissage par inondation --------- }
  { Push L-to-R: X,Y,Border -> [EBP+16]=X [EBP+12]=Y [EBP+8]=Border }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FLOODFILL');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { Border color index }
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');                     { COLORREF border }
  EmitInstr('PUSH DWORD PTR [EBP+12]');     { Y }
  EmitInstr('PUSH DWORD PTR [EBP+16]');     { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL FloodFill');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_SETCOLOR : changer couleur de dessin ----------- }
  { Parametre : [ESP+4]=Color index                                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SETCOLOR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('MOV DWORD PTR [GR_COLOR],EAX');
  EmitInstr('CALL ' + TP_RT_PFX + 'UPDATEPEN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_UPDATEPEN : recreer pen avec couleur courante -- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'UPDATEPEN');
  EmitInstr('PUSHAD');
  { Supprimer ancien pen }
  EmitInstr('CMP DWORD PTR [GR_HPEN],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'UP_SK');
  EmitInstr('PUSH DWORD PTR [GR_HPEN]');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'UP_SK');
  { Creer nouveau pen }
  EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');                    { COLORREF }
  EmitInstr('PUSH DWORD PTR [GR_LINEWIDTH]');
  EmitInstr('PUSH DWORD PTR [GR_LINESTYLE]');
  EmitInstr('CALL CreatePen');
  EmitInstr('MOV DWORD PTR [GR_HPEN],EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  { Mettre a jour la couleur de texte aussi }
  EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SetTextColor');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPR_UPDATEFONT : recreer font avec params courants - }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'UPDATEFONT');
  EmitInstr('PUSHAD');
  { Supprimer ancienne fonte }
  EmitInstr('CMP DWORD PTR [GR_HFONT],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'UF_SK');
  EmitInstr('PUSH DWORD PTR [GR_HFONT]');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'UF_SK');
  { CreateFont(height, 0, escapement, orient, weight, ..., "Courier New") }
  { Calculer hauteur : 8 * GR_TXSIZE }
  EmitInstr('MOV EAX,DWORD PTR [GR_TXSIZE]');
  EmitInstr('SHL EAX,3');                   { *8 }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'UF_NZ');
  EmitInstr('MOV EAX,8');                   { minimum 8 }
  EmitLabel(TP_RT_PFX + 'UF_NZ');
  EmitComment('CreateFontA - stub simplifie');
  { On ne cree pas la font complete pour ne pas compliquer }
  { On met juste a jour GR_HFONT = 0 pour utiliser la fonte systeme }
  EmitInstr('MOV DWORD PTR [GR_HFONT],0');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPR_OUTTEXTXY : afficher texte a (X, Y) ----------- }
  { Push L-to-R: X,Y,ptrString -> [EBP+16]=X [EBP+12]=Y [EBP+8]=ptrString }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'OUTTEXTXY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Calculer longueur chaine (Pascal string: len in byte 0) }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { ptr string }
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');       { longueur Pascal }
  EmitInstr('INC ESI');                      { pointeur vers data }
  { TextOutA(hdc, x, y, lpString, len) }
  EmitInstr('PUSH ECX');                     { nCount }
  EmitInstr('PUSH ESI');                     { lpString }
  EmitInstr('PUSH DWORD PTR [EBP+12]');     { Y }
  EmitInstr('PUSH DWORD PTR [EBP+16]');     { X }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL TextOutA');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_CLEARDEVICE : effacer l ecran graphique -------- }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CLEARDEVICE');
  EmitInstr('PUSHAD');
  { Creer brush fond }
  EmitInstr('MOV EAX,DWORD PTR [GR_BKCOLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitInstr('MOV EBX,EAX');                  { sauver handle }
  { Remplir le rectangle client }
  EmitInstr('MOV DWORD PTR [GR_RECT+0],0');
  EmitInstr('MOV DWORD PTR [GR_RECT+4],0');
  EmitInstr('MOV EAX,DWORD PTR [GR_MAXX]');
  EmitInstr('INC EAX');
  EmitInstr('MOV DWORD PTR [GR_RECT+8],EAX');
  EmitInstr('MOV EAX,DWORD PTR [GR_MAXY]');
  EmitInstr('INC EAX');
  EmitInstr('MOV DWORD PTR [GR_RECT+12],EAX');
  EmitInstr('PUSH EBX');                     { hBrush }
  EmitInstr('PUSH OFFSET GR_RECT');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL FillRect');
  { Supprimer brush }
  EmitInstr('PUSH EBX');
  EmitInstr('CALL DeleteObject');
  { Reset position courante }
  EmitInstr('MOV DWORD PTR [GR_CPX],0');
  EmitInstr('MOV DWORD PTR [GR_CPY],0');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPR_GRAPHERRORMSG : retourne pointeur message erreur - }
  { Parametre : [ESP+4] = code erreur                               }
  { Retourne pointeur chaine dans EAX                                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GRAPHERRORMSG');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'GE_E1');
  EmitInstr('LEA EAX,[GR_ERRMSG0]');
  EmitInstr('JMP ' + TP_RT_PFX + 'GE_DN');
  EmitLabel(TP_RT_PFX + 'GE_E1');
  EmitInstr('CMP EAX,-2');
  EmitInstr('JNE ' + TP_RT_PFX + 'GE_E2');
  EmitInstr('LEA EAX,[GR_ERRMSG2]');
  EmitInstr('JMP ' + TP_RT_PFX + 'GE_DN');
  EmitLabel(TP_RT_PFX + 'GE_E2');
  EmitInstr('LEA EAX,[GR_ERRMSG1]');
  EmitLabel(TP_RT_PFX + 'GE_DN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_IMAGESIZE : calculer taille image -------------- }
  { Parametres : [ESP+4]=X1, [ESP+8]=Y1, [ESP+12]=X2, [ESP+16]=Y2 }
  { Retourne taille en octets dans EAX = (X2-X1+1)*(Y2-Y1+1)*4+4  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'IMAGESIZE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+16]');  { X2 }
  EmitInstr('SUB EAX,DWORD PTR [EBP+8]');   { - X1 }
  EmitInstr('INC EAX');                      { +1 = largeur }
  EmitInstr('MOV ECX,DWORD PTR [EBP+20]');  { Y2 }
  EmitInstr('SUB ECX,DWORD PTR [EBP+12]');  { - Y1 }
  EmitInstr('INC ECX');                      { +1 = hauteur }
  EmitInstr('IMUL EAX,ECX');                 { largeur * hauteur }
  EmitInstr('SHL EAX,2');                    { * 4 (bytes per pixel DWORD) }
  EmitInstr('ADD EAX,4');                    { + 4 (header) }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_TEXTHEIGHT : hauteur texte en pixels ----------- }
  { Parametre : [ESP+4] = ptr chaine                               }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'TEXTHEIGHT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');       { longueur Pascal }
  EmitInstr('INC ESI');
  EmitInstr('PUSH OFFSET GR_TXSIZE2');      { lpSize }
  EmitInstr('PUSH ECX');                     { nCount }
  EmitInstr('PUSH ESI');                     { lpString }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL GetTextExtentPoint32A');
  EmitInstr('POPAD');
  EmitInstr('MOV EAX,DWORD PTR [GR_TXSIZE2+4]');  { cy }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_TEXTWIDTH : largeur texte en pixels ------------ }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'TEXTWIDTH');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');
  EmitInstr('INC ESI');
  EmitInstr('PUSH OFFSET GR_TXSIZE2');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL GetTextExtentPoint32A');
  EmitInstr('POPAD');
  EmitInstr('MOV EAX,DWORD PTR [GR_TXSIZE2]');    { cx }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_SETVIDEOMODE : ouvre/ferme fenetre graphique --- }
  { Parametre : [ESP+4]=mode (-1=_DefaultMode -> fermer)         }
  { Retour    : 25 (nb lignes texte) si succes, 0 si echec       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'SETVIDEOMODE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');    { mode }
  { Si mode == -1 (_DefaultMode) : fermer la fenetre }
  EmitInstr('CMP EAX,-1');
  EmitInstr('JNE ' + TP_RT_PFX + 'SVM_OPEN');
  EmitInstr('CALL ' + TP_RT_PFX + 'CLOSEGRAPH');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  { Sinon : ouvrir la fenetre si pas deja ouverte }
  EmitLabel(TP_RT_PFX + 'SVM_OPEN');
  EmitInstr('CMP DWORD PTR [GR_ACTIVE],0');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SVM_DONE');
  { Appeler INITGRAPH avec GR_DRIVER et GR_MODE comme var de sortie }
  EmitInstr('PUSH OFFSET GR_WNDTITLE');       { Path (non utilise) }
  EmitInstr('PUSH OFFSET GR_MODE');           { Gm var }
  EmitInstr('PUSH OFFSET GR_DRIVER');         { Gd var }
  EmitInstr('CALL ' + TP_RT_PFX + 'INITGRAPH');
  EmitInstr('ADD ESP,12');
  { Verifier que la fenetre a ete creee }
  EmitInstr('CMP DWORD PTR [GR_HWND],0');
  EmitInstr('JZ ' + TP_RT_PFX + 'SVM_FAIL');
  EmitLabel(TP_RT_PFX + 'SVM_DONE');
  { Mettre a jour le champ mode de GR_VIDCFG avec le mode demande }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('LEA EDX,[GR_VIDCFG]');
  EmitInstr('MOV DWORD PTR [EDX+28],EAX');
  EmitInstr('MOV EAX,25');                    { 25 lignes texte = succes }
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SVM_FAIL');
  EmitInstr('XOR EAX,EAX');                  { 0 = mode non supporte }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_GETVIDEOCONFIG : copier GR_VIDCFG vers var param -- }
  { Parametre : [ESP+4] = adresse de la variable _VideoConfig       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'GETVIDEOCONFIG');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH ECX');
  EmitInstr('LEA ESI,[GR_VIDCFG]');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');  { dest = adresse VC }
  EmitInstr('MOV ECX,11');                 { 11 DWORDs }
  EmitInstr('CLD');
  EmitInstr('REP MOVSD');
  EmitInstr('POP ECX');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_MSGR_RECT : MSGraph _Rectangle(ctl,x1,y1,x2,y2) -- }
  { Parametre (push L-to-R) : ctl,[EBP+24] x1,[EBP+20] y1,[EBP+16] }
  {                           x2,[EBP+12]  y2,[EBP+8]               }
  { _GBorder=2 -> contour seul, _GFillInterior=3 -> rempli           }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'MSGR_RECT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Selectionner brush selon controle }
  EmitInstr('MOV EAX,DWORD PTR [EBP+24]');   { control }
  EmitInstr('CMP EAX,3');                     { _GFillInterior = 3 }
  EmitInstr('JE ' + TP_RT_PFX + 'MRR_FILL');
  { Contour seul : brush null }
  EmitInstr('PUSH 5');                        { NULL_BRUSH }
  EmitInstr('CALL GetStockObject');
  EmitInstr('JMP ' + TP_RT_PFX + 'MRR_SEL');
  EmitLabel(TP_RT_PFX + 'MRR_FILL');
  { Rempli : brush avec couleur de dessin courante }
  EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitLabel(TP_RT_PFX + 'MRR_SEL');
  EmitInstr('MOV ESI,EAX');                  { sauver brush }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('MOV EDI,EAX');                  { sauver ancien brush }
  { GDI Rectangle(hdc, left, top, right, bottom) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { y2 = bottom }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { x2 = right  }
  EmitInstr('PUSH DWORD PTR [EBP+16]');      { y1 = top    }
  EmitInstr('PUSH DWORD PTR [EBP+20]');      { x1 = left   }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Rectangle');
  { Restaurer ancien brush }
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  { Detruire brush cree si rempli }
  EmitInstr('MOV EAX,DWORD PTR [EBP+24]');
  EmitInstr('CMP EAX,3');
  EmitInstr('JNE ' + TP_RT_PFX + 'MRR_DN');
  EmitInstr('PUSH ESI');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'MRR_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_MSGR_ELLPS : MSGraph _Ellipse(ctl,x1,y1,x2,y2) --- }
  { Meme convention que MSGR_RECT                                    }
  { _GBorder=2 -> contour, _GFillInterior=3 -> remplie              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'MSGR_ELLPS');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  EmitInstr('MOV EAX,DWORD PTR [EBP+24]');   { control }
  EmitInstr('CMP EAX,3');
  EmitInstr('JE ' + TP_RT_PFX + 'MEL_FILL');
  EmitInstr('PUSH 5');                        { NULL_BRUSH }
  EmitInstr('CALL GetStockObject');
  EmitInstr('JMP ' + TP_RT_PFX + 'MEL_SEL');
  EmitLabel(TP_RT_PFX + 'MEL_FILL');
  EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitLabel(TP_RT_PFX + 'MEL_SEL');
  EmitInstr('MOV ESI,EAX');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('MOV EDI,EAX');
  { GDI Ellipse(hdc, left, top, right, bottom) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { y2 = bottom }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { x2 = right  }
  EmitInstr('PUSH DWORD PTR [EBP+16]');      { y1 = top    }
  EmitInstr('PUSH DWORD PTR [EBP+20]');      { x1 = left   }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Ellipse');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('MOV EAX,DWORD PTR [EBP+24]');
  EmitInstr('CMP EAX,3');
  EmitInstr('JNE ' + TP_RT_PFX + 'MEL_DN');
  EmitInstr('PUSH ESI');
  EmitInstr('CALL DeleteObject');
  EmitLabel(TP_RT_PFX + 'MEL_DN');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_MSGR_SETPXL : MSGraph _SetPixel(x,y) ------------ }
  { Parametre (push L-to-R) : x,[EBP+12]  y,[EBP+8]              }
  { Utilise GR_COLOR comme couleur courante                        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'MSGR_SETPXL');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { COLORREF depuis GR_COLOR }
  EmitInstr('MOV EAX,DWORD PTR [GR_COLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  { SetPixel(hdc, x, y, crColor) - stdcall R-to-L: crColor,y,x,hdc }
  EmitInstr('PUSH EAX');                     { crColor }
  EmitInstr('PUSH DWORD PTR [EBP+8]');       { y }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { x }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SetPixel');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_MSGR_FLOOD : MSGraph _FloodFill(x,y,boundary) ---- }
  { Parametre (push L-to-R) : x,[EBP+16] y,[EBP+12] bnd,[EBP+8]  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'MSGR_FLOOD');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { COLORREF frontiere depuis palette }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { boundary color index }
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  { FloodFill(hdc, x, y, crColor) - stdcall R-to-L: crColor,y,x,hdc }
  EmitInstr('PUSH EAX');                     { crColor }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { y }
  EmitInstr('PUSH DWORD PTR [EBP+16]');      { x }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL FloodFill');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_DRAWPOLY : dessiner un polygone ouvert (polyline) - }
  { Parametres (push L-to-R) : NumPoints,[EBP+12]  Points,[EBP+8]  }
  { PointType = record X,Y:Integer -> 8 bytes = Win32 POINT struct  }
  { Utilise GDI Polyline(hdc, lppt, cpt)                            }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DRAWPOLY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  { Polyline(hdc, lppt, cpt) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { cpt = NumPoints }
  EmitInstr('PUSH DWORD PTR [EBP+8]');       { lppt = adresse tableau Points }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Polyline');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_FILLPOLY : dessiner et remplir un polygone ferme -- }
  { Parametres (push L-to-R) : NumPoints,[EBP+12]  Points,[EBP+8]  }
  { Utilise GDI Polygon(hdc, lppt, cpt) avec brush courant          }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'FILLPOLY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSHAD');
  { Selectionner brush de remplissage }
  EmitInstr('MOV EAX,DWORD PTR [GR_FILLCOLOR]');
  EmitInstr('AND EAX,0Fh');
  EmitInstr('MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL CreateSolidBrush');
  EmitInstr('MOV ESI,EAX');                  { sauver nouveau brush }
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  EmitInstr('MOV EDI,EAX');                  { sauver ancien brush }
  { Polygon(hdc, lppt, cpt) - stdcall R-to-L }
  EmitInstr('PUSH DWORD PTR [EBP+12]');      { cpt = NumPoints }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { lppt = adresse Points }
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL Polygon');
  { Restaurer ancien brush }
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH DWORD PTR [GR_HDC]');
  EmitInstr('CALL SelectObject');
  { Detruire le brush cree }
  EmitInstr('PUSH ESI');
  EmitInstr('CALL DeleteObject');
  EmitInstr('POPAD');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 21 - ROUTINES RUNTIME STRINGS/OVERLAY    [IMPLEMENTE]   }
{ ============================================================ }

Procedure EmitStringsRuntime;
Begin
  EmitBlankLine;
  EmitComment('============================================================');
  EmitComment(' RUNTIME STRINGS : routines unite Strings (PChar / ASCIIZ)  ');
  EmitComment('============================================================');

  { ------ _TPR_STRCOPY : copie chaine ASCIIZ ------------------- }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source                      }
  { Retourne Dest dans EAX                                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCOPY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');  { Source }
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL lstrcpyA');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { retourne Dest }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRCAT : concatene chaines ASCIIZ --------------- }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source                      }
  { Retourne Dest dans EAX                                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCAT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]');  { Source }
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL lstrcatA');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { retourne Dest }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRPOS : chercher sous-chaine ------------------- }
  { Parametres : [ESP+4]=S1 (chaine), [ESP+8]=S2 (sous-chaine)    }
  { Retourne pointeur dans EAX ou 0 si non trouve                  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRPOS');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { S1 }
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');  { S2 }
  { Longueur de S2 }
  EmitInstr('PUSH EDI');
  EmitInstr('CALL lstrlenA');
  EmitInstr('MOV ECX,EAX');                  { ECX = len(S2) }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SP_NUL');
  { Longueur de S1 }
  EmitInstr('PUSH ESI');
  EmitInstr('CALL lstrlenA');
  EmitInstr('MOV EBX,EAX');                  { EBX = len(S1) }
  EmitInstr('SUB EBX,ECX');
  EmitInstr('JS ' + TP_RT_PFX + 'SP_NF');   { S2 plus long que S1 }
  EmitInstr('INC EBX');                      { nombre de positions a tester }
  EmitLabel(TP_RT_PFX + 'SP_LP');
  { Comparer ECX octets a ESI avec EDI }
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('REPE CMPSB');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP ECX');
  EmitInstr('JE ' + TP_RT_PFX + 'SP_FD');   { trouve! }
  EmitInstr('INC ESI');
  EmitInstr('DEC EBX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SP_LP');
  EmitLabel(TP_RT_PFX + 'SP_NF');
  EmitInstr('XOR EAX,EAX');                  { retourne NIL }
  EmitInstr('JMP ' + TP_RT_PFX + 'SP_DN');
  EmitLabel(TP_RT_PFX + 'SP_NUL');
  EmitInstr('MOV EAX,ESI');                  { sous-chaine vide -> retourne S1 }
  EmitInstr('JMP ' + TP_RT_PFX + 'SP_DN');
  EmitLabel(TP_RT_PFX + 'SP_FD');
  EmitInstr('MOV EAX,ESI');                  { retourne position trouvee }
  EmitLabel(TP_RT_PFX + 'SP_DN');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRSCAN : chercher caractere -------------------- }
  { Parametres : [ESP+4]=S, [ESP+8]=C (caractere)                  }
  { Retourne pointeur dans EAX ou 0 si non trouve                  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRSCAN');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');   { S }
  EmitInstr('MOV CL,BYTE PTR [EBP+12]');    { C }
  EmitLabel(TP_RT_PFX + 'SC_LP');
  EmitInstr('MOV AL,BYTE PTR [EDX]');
  EmitInstr('CMP AL,CL');
  EmitInstr('JE ' + TP_RT_PFX + 'SC_FD');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'SC_NF');
  EmitInstr('INC EDX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SC_LP');
  EmitLabel(TP_RT_PFX + 'SC_NF');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'SC_FD');
  EmitInstr('MOV EAX,EDX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRRSCAN : chercher caractere en arriere -------- }
  { Parametres : [ESP+4]=S, [ESP+8]=C (caractere)                  }
  { Retourne pointeur dans EAX ou 0 si non trouve                  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRRSCAN');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');   { S }
  EmitInstr('MOV CL,BYTE PTR [EBP+12]');    { C }
  EmitInstr('XOR EBX,EBX');                  { EBX = derniere position trouvee }
  EmitLabel(TP_RT_PFX + 'RS_LP');
  EmitInstr('MOV AL,BYTE PTR [EDX]');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'RS_DN');
  EmitInstr('CMP AL,CL');
  EmitInstr('JNE ' + TP_RT_PFX + 'RS_NX');
  EmitInstr('MOV EBX,EDX');
  EmitLabel(TP_RT_PFX + 'RS_NX');
  EmitInstr('INC EDX');
  EmitInstr('JMP ' + TP_RT_PFX + 'RS_LP');
  EmitLabel(TP_RT_PFX + 'RS_DN');
  EmitInstr('MOV EAX,EBX');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STREND : pointeur vers fin de chaine ------------ }
  { Parametre : [ESP+4]=S                                          }
  { Retourne pointeur vers le zero terminal dans EAX                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STREND');
  EmitInstr('MOV EAX,DWORD PTR [ESP+4]');
  EmitLabel(TP_RT_PFX + 'SE_LP');
  EmitInstr('CMP BYTE PTR [EAX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'SE_DN');
  EmitInstr('INC EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SE_LP');
  EmitLabel(TP_RT_PFX + 'SE_DN');
  EmitInstr('RET');

  { ------ _TPR_STRMOVE : deplacer octets ----------------------- }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source, [ESP+12]=Count      }
  { Retourne Dest dans EAX                                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRMOVE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH ECX');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');  { Source }
  EmitInstr('MOV ECX,DWORD PTR [EBP+16]');  { Count }
  EmitInstr('REP MOVSB');
  EmitInstr('POP ECX');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { retourne Dest }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRNEW : allouer copie sur le heap --------------- }
  { Parametre : [ESP+4]=S (chaine source)                          }
  { Retourne pointeur nouvelle chaine dans EAX                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRNEW');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  { Calculer longueur + 1 }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL lstrlenA');
  EmitInstr('INC EAX');                      { +1 pour le zero terminal }
  EmitInstr('MOV EBX,EAX');                  { sauver taille }
  { Allouer memoire }
  EmitInstr('PUSH EBX');                     { taille }
  EmitInstr('PUSH 0');                       { HEAP_ZERO_MEMORY = 0 }
  EmitInstr('PUSH DWORD PTR [HHEAP]');
  EmitInstr('CALL HeapAlloc');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SN_DN');
  { Copier la chaine }
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  EmitInstr('PUSH EAX');
  EmitInstr('MOV EBX,EAX');                  { sauver pointeur resultat }
  EmitInstr('CALL lstrcpyA');
  EmitInstr('MOV EAX,EBX');                  { retourner pointeur }
  EmitLabel(TP_RT_PFX + 'SN_DN');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRDISPOSE : liberer chaine allouee ------------- }
  { Parametre : [ESP+4]=S (pointeur chaine a liberer)              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRDISPOSE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'SD_DN');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH DWORD PTR [HHEAP]');
  EmitInstr('CALL HeapFree');
  EmitLabel(TP_RT_PFX + 'SD_DN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRPAS : convertir PChar en Pascal string -------- }
  { Parametre : [ESP+4]=S (PChar)                                   }
  { Retourne pointeur vers STR_PASBUF (format Pascal) dans EAX     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRPAS');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  { Longueur }
  EmitInstr('PUSH ESI');
  EmitInstr('CALL lstrlenA');
  EmitInstr('CMP EAX,255');
  EmitInstr('JBE ' + TP_RT_PFX + 'PA_OK');
  EmitInstr('MOV EAX,255');                  { tronquer a 255 }
  EmitLabel(TP_RT_PFX + 'PA_OK');
  EmitInstr('LEA EDI,[STR_PASBUF]');
  EmitInstr('MOV BYTE PTR [EDI],AL');        { octet de longueur }
  EmitInstr('MOV ECX,EAX');
  EmitInstr('INC EDI');
  EmitInstr('REP MOVSB');
  EmitInstr('MOV EAX,OFFSET STR_PASBUF');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRPCOPY : copier Pascal string vers PChar ------- }
  { Parametres : [ESP+4]=Dest (PChar), [ESP+8]=Source (Pascal str)  }
  { Retourne Dest dans EAX                                          }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRPCOPY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');  { Source (Pascal string) }
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');       { longueur Pascal }
  EmitInstr('INC ESI');                      { sauter octet longueur }
  EmitInstr('REP MOVSB');
  EmitInstr('MOV BYTE PTR [EDI],0');         { zero terminal }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');   { retourne Dest }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRUPPER : majuscules in-place ------------------- }
  { Parametre : [ESP+4]=S                                           }
  { Retourne S dans EAX                                             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRUPPER');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');
  EmitInstr('MOV EAX,EDX');                  { sauver pour retour }
  EmitLabel(TP_RT_PFX + 'SU_LP');
  EmitInstr('MOV CL,BYTE PTR [EDX]');
  EmitInstr('TEST CL,CL');
  EmitInstr('JZ ' + TP_RT_PFX + 'SU_DN');
  EmitInstr('CMP CL,''a''');
  EmitInstr('JB ' + TP_RT_PFX + 'SU_NX');
  EmitInstr('CMP CL,''z''');
  EmitInstr('JA ' + TP_RT_PFX + 'SU_NX');
  EmitInstr('SUB CL,32');
  EmitInstr('MOV BYTE PTR [EDX],CL');
  EmitLabel(TP_RT_PFX + 'SU_NX');
  EmitInstr('INC EDX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SU_LP');
  EmitLabel(TP_RT_PFX + 'SU_DN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRLOWER : minuscules in-place ------------------- }
  { Parametre : [ESP+4]=S                                           }
  { Retourne S dans EAX                                             }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLOWER');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');
  EmitInstr('MOV EAX,EDX');
  EmitLabel(TP_RT_PFX + 'SL_LP');
  EmitInstr('MOV CL,BYTE PTR [EDX]');
  EmitInstr('TEST CL,CL');
  EmitInstr('JZ ' + TP_RT_PFX + 'SL_DN');
  EmitInstr('CMP CL,''A''');
  EmitInstr('JB ' + TP_RT_PFX + 'SL_NX');
  EmitInstr('CMP CL,''Z''');
  EmitInstr('JA ' + TP_RT_PFX + 'SL_NX');
  EmitInstr('ADD CL,32');
  EmitInstr('MOV BYTE PTR [EDX],CL');
  EmitLabel(TP_RT_PFX + 'SL_NX');
  EmitInstr('INC EDX');
  EmitInstr('JMP ' + TP_RT_PFX + 'SL_LP');
  EmitLabel(TP_RT_PFX + 'SL_DN');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRLCOPY : copie limitee ------------------------ }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source, [ESP+12]=MaxLen     }
  { Retourne Dest dans EAX                                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLCOPY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');  { Source }
  EmitInstr('MOV ECX,DWORD PTR [EBP+16]');  { MaxLen }
  EmitLabel(TP_RT_PFX + 'LC_LP');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'LC_DN');
  EmitInstr('MOV AL,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],AL');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'LC_DN');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'LC_LP');
  EmitLabel(TP_RT_PFX + 'LC_DN');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRLCAT : concatenation limitee ------------------ }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source, [ESP+12]=MaxLen     }
  { Retourne Dest dans EAX                                         }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLCAT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { Dest }
  { Trouver la fin de Dest }
  EmitLabel(TP_RT_PFX + 'LA_FE');
  EmitInstr('CMP BYTE PTR [EDI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'LA_CP');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'LA_FE');
  EmitLabel(TP_RT_PFX + 'LA_CP');
  { Calculer place restante }
  EmitInstr('MOV EBX,EDI');
  EmitInstr('SUB EBX,DWORD PTR [EBP+8]');   { longueur actuelle }
  EmitInstr('MOV ECX,DWORD PTR [EBP+16]');  { MaxLen }
  EmitInstr('SUB ECX,EBX');
  EmitInstr('JLE ' + TP_RT_PFX + 'LA_DN');
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');  { Source }
  EmitLabel(TP_RT_PFX + 'LA_LP');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'LA_DN');
  EmitInstr('MOV AL,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],AL');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'LA_DN');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'LA_LP');
  EmitLabel(TP_RT_PFX + 'LA_DN');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRECOPY : copie retournant fin ------------------- }
  { Parametres : [ESP+4]=Dest, [ESP+8]=Source                       }
  { Retourne pointeur vers fin de Dest dans EAX                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRECOPY');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');   { Dest }
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');  { Source }
  EmitLabel(TP_RT_PFX + 'EC_LP');
  EmitInstr('MOV AL,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],AL');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'EC_DN');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'EC_LP');
  EmitLabel(TP_RT_PFX + 'EC_DN');
  EmitInstr('MOV EAX,EDI');                  { retourne pointeur vers fin }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STRLICOMP : comparaison insensible limitee ------- }
  { Parametres : [ESP+4]=S1, [ESP+8]=S2, [ESP+12]=MaxLen           }
  { Retourne <0, 0, >0 dans EAX                                    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLICOMP');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { S1 }
  EmitInstr('MOV EDI,DWORD PTR [EBP+12]');  { S2 }
  EmitInstr('MOV ECX,DWORD PTR [EBP+16]');  { MaxLen }
  EmitLabel(TP_RT_PFX + 'LI_LP');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'LI_EQ');
  EmitInstr('MOV AL,BYTE PTR [ESI]');
  EmitInstr('MOV AH,BYTE PTR [EDI]');
  { Convertir en majuscules pour comparaison }
  EmitInstr('CMP AL,''a''');
  EmitInstr('JB ' + TP_RT_PFX + 'LI_N1');
  EmitInstr('CMP AL,''z''');
  EmitInstr('JA ' + TP_RT_PFX + 'LI_N1');
  EmitInstr('SUB AL,32');
  EmitLabel(TP_RT_PFX + 'LI_N1');
  EmitInstr('CMP AH,''a''');
  EmitInstr('JB ' + TP_RT_PFX + 'LI_N2');
  EmitInstr('CMP AH,''z''');
  EmitInstr('JA ' + TP_RT_PFX + 'LI_N2');
  EmitInstr('SUB AH,32');
  EmitLabel(TP_RT_PFX + 'LI_N2');
  EmitInstr('CMP AL,AH');
  EmitInstr('JNE ' + TP_RT_PFX + 'LI_NE');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'LI_EQ');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'LI_LP');
  EmitLabel(TP_RT_PFX + 'LI_EQ');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + TP_RT_PFX + 'LI_DN');
  EmitLabel(TP_RT_PFX + 'LI_NE');
  EmitInstr('MOVZX EAX,AL');
  EmitInstr('MOVZX EDX,AH');
  EmitInstr('SUB EAX,EDX');
  EmitLabel(TP_RT_PFX + 'LI_DN');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 21 - ROUTINES RUNTIME OBJECTS              [IMPLEMENTE] }
{ ============================================================ }

Procedure EmitObjectsRuntime;
Begin
  EmitBlankLine;
  EmitComment('============================================================');
  EmitComment(' RUNTIME OBJECTS : routines unite Objects (TStream, etc.)    ');
  EmitComment('============================================================');

  { ------ _TPR_NEWSTR : allouer copie de chaine Pascal -------- }
  { Parametre : [ESP+4] = pointeur vers ShortString source       }
  { Retourne dans EAX : pointeur vers nouvelle ShortString (tas) }
  { ou NIL si chaine vide                                         }
  EmitLabel(TP_RT_PFX + 'NEWSTR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');  { source string ptr }
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');       { longueur }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'NEWSTR_NIL');
  EmitInstr('ADD ECX,2');                    { longueur + 1 (len byte) + 1 (securite) }
  { Allouer memoire via HeapAlloc }
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH 8');                       { HEAP_ZERO_MEMORY }
  EmitInstr('PUSH DWORD PTR [HHEAP]');
  EmitInstr('CALL _HeapAlloc@12');
  EmitInstr('POP ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'NEWSTR_NIL');
  { Copier la chaine }
  EmitInstr('MOV EDI,EAX');
  EmitInstr('PUSH EAX');                     { sauver resultat }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV CL,BYTE PTR [ESI]');
  EmitInstr('INC ECX');                      { copier len byte aussi }
  EmitInstr('REP MOVSB');
  EmitInstr('POP EAX');                      { restaurer resultat }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitLabel(TP_RT_PFX + 'NEWSTR_NIL');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_DISPOSESTR : liberer chaine allouee par NewStr - }
  { Parametre : [ESP+4] = pointeur vers PString                  }
  EmitLabel(TP_RT_PFX + 'DISPOSESTR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + TP_RT_PFX + 'DISPOSESTR_END');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH DWORD PTR [HHEAP]');
  EmitInstr('CALL _HeapFree@12');
  EmitLabel(TP_RT_PFX + 'DISPOSESTR_END');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_DOSSTREAM_INIT : ouvrir fichier pour TDosStream  }
  { Parametres : [ESP+4]=FileName (PChar), [ESP+8]=Mode          }
  { Mode: stCreate=1 -> creer, stOpenRead=0 -> lire              }
  EmitLabel(TP_RT_PFX + 'DOSSTREAM_INIT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV EAX,DWORD PTR [EBP+12]'); { Mode }
  EmitInstr('CMP EAX,1');
  EmitInstr('JE ' + TP_RT_PFX + 'DS_CREATE');
  { stOpenRead : ouvrir en lecture }
  EmitInstr('PUSH 0');                      { hTemplateFile = NULL }
  EmitInstr('PUSH 128');                    { FILE_ATTRIBUTE_NORMAL }
  EmitInstr('PUSH 3');                      { OPEN_EXISTING }
  EmitInstr('PUSH 0');                      { lpSecurityAttributes }
  EmitInstr('PUSH 1');                      { FILE_SHARE_READ }
  EmitInstr('PUSH 80000000h');              { GENERIC_READ }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { lpFileName }
  EmitInstr('CALL _CreateFileA@28');
  EmitInstr('JMP ' + TP_RT_PFX + 'DS_STORE');
  EmitLabel(TP_RT_PFX + 'DS_CREATE');
  { stCreate : creer en ecriture }
  EmitInstr('PUSH 0');                      { hTemplateFile = NULL }
  EmitInstr('PUSH 128');                    { FILE_ATTRIBUTE_NORMAL }
  EmitInstr('PUSH 2');                      { CREATE_ALWAYS }
  EmitInstr('PUSH 0');                      { lpSecurityAttributes }
  EmitInstr('PUSH 0');                      { dwShareMode }
  EmitInstr('PUSH 40000000h');              { GENERIC_WRITE }
  EmitInstr('PUSH DWORD PTR [EBP+8]');     { lpFileName }
  EmitInstr('CALL _CreateFileA@28');
  EmitLabel(TP_RT_PFX + 'DS_STORE');
  EmitInstr('MOV DWORD PTR [OBJ_TMPHDL],EAX');
  EmitInstr('MOV DWORD PTR [OBJ_TMPPOS],0');
  EmitInstr('MOV DWORD PTR [OBJ_STATUS],0');
  { Obtenir la taille du fichier }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL _GetFileSize@8');
  EmitInstr('MOV DWORD PTR [OBJ_TMPSIZ],EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_DOSSTREAM_DONE : fermer fichier TDosStream ------ }
  EmitLabel(TP_RT_PFX + 'DOSSTREAM_DONE');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPHDL]');
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'DS_DONE_END');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL _CloseHandle@4');
  EmitInstr('MOV DWORD PTR [OBJ_TMPHDL],-1');
  EmitLabel(TP_RT_PFX + 'DS_DONE_END');
  EmitInstr('RET');

  { ------ _TPR_STREAM_READ : lire depuis le stream ------------ }
  { Parametres : [ESP+4]=Buffer, [ESP+8]=Count                   }
  { Retourne dans EAX : nombre d octets lus                      }
  EmitLabel(TP_RT_PFX + 'STREAM_READ');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 0');                       { lpOverlapped }
  EmitInstr('LEA EAX,DWORD PTR [OBJ_BYTESRW]');
  EmitInstr('PUSH EAX');                     { lpNumberOfBytesRead }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { nNumberOfBytesToRead (Count) }
  EmitInstr('PUSH DWORD PTR [EBP+12]');     { lpBuffer (Buf) }
  EmitInstr('PUSH DWORD PTR [OBJ_TMPHDL]'); { hFile }
  EmitInstr('CALL _ReadFile@20');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_BYTESRW]');
  EmitInstr('ADD DWORD PTR [OBJ_TMPPOS],EAX'); { mettre a jour position }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STREAM_WRITE : ecrire dans le stream ----------- }
  { Parametres : [ESP+4]=Buffer, [ESP+8]=Count                   }
  EmitLabel(TP_RT_PFX + 'STREAM_WRITE');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 0');                       { lpOverlapped }
  EmitInstr('LEA EAX,DWORD PTR [OBJ_BYTESRW]');
  EmitInstr('PUSH EAX');                     { lpNumberOfBytesWritten }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { nNumberOfBytesToWrite (Count) }
  EmitInstr('PUSH DWORD PTR [EBP+12]');     { lpBuffer (Buf) }
  EmitInstr('PUSH DWORD PTR [OBJ_TMPHDL]'); { hFile }
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_BYTESRW]');
  EmitInstr('ADD DWORD PTR [OBJ_TMPPOS],EAX'); { mettre a jour position }
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STREAM_SEEK : positionner dans le stream ------- }
  { Parametre : [ESP+4]=Position                                  }
  EmitLabel(TP_RT_PFX + 'STREAM_SEEK');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 0');                       { FILE_BEGIN }
  EmitInstr('PUSH 0');                       { lpDistanceToMoveHigh }
  EmitInstr('PUSH DWORD PTR [EBP+8]');      { lDistanceToMove (Pos) }
  EmitInstr('PUSH DWORD PTR [OBJ_TMPHDL]'); { hFile }
  EmitInstr('CALL _SetFilePointer@16');
  EmitInstr('MOV DWORD PTR [OBJ_TMPPOS],EAX');
  EmitInstr('POP EBP');
  EmitInstr('RET');

  { ------ _TPR_STREAM_FLUSH : vider les buffers --------------- }
  EmitLabel(TP_RT_PFX + 'STREAM_FLUSH');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPHDL]');
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'SF_END');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL _FlushFileBuffers@4');
  EmitLabel(TP_RT_PFX + 'SF_END');
  EmitInstr('RET');

  { ------ _TPR_STREAM_TRUNCATE : tronquer a la position ------- }
  EmitLabel(TP_RT_PFX + 'STREAM_TRUNCATE');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPHDL]');
  EmitInstr('CMP EAX,-1');
  EmitInstr('JE ' + TP_RT_PFX + 'ST_END');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL _SetEndOfFile@4');
  EmitInstr('MOV EAX,DWORD PTR [OBJ_TMPPOS]');
  EmitInstr('MOV DWORD PTR [OBJ_TMPSIZ],EAX');
  EmitLabel(TP_RT_PFX + 'ST_END');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 22 - ROUTINES RUNTIME MEM/PORT        [IMPLEMENTE]      }
{ ============================================================ }

Procedure EmitMemPortRuntime;
Var
  L1, L2, L3, L4, L5, L6, L7, L8 : TString;
Begin
  EmitBlankLine;
  EmitComment('============================================================');
  EmitComment(' RUNTIME MEM/PORT : emulation Mem/MemW/MemL/Port/PortW      ');
  EmitComment('============================================================');

  { ------ _TPRT_READMEM : lecture memoire emulee --------------- }
  { Parametres : EAX = segment, EDX = offset                      }
  { Retourne dans EAX : valeur lue (selon le contexte)            }
  { Emulation : Mem[$0040:$0013] -> memoire conventionnelle (640 Ko) }
  {             Mem[$0040:$0017] -> etat clavier (shift keys)    }
  {             Mem[$0040:$0049] -> mode video courant (03h)      }
  {             Mem[$0040:$004A] -> nombre colonnes (80)          }
  {             Mem[$0040:$0084] -> nombre lignes - 1 (24)        }
  {             Mem[$B800:xxxx] -> memoire video texte (stub)     }
  {             Autres -> 0 (non emule)                            }
  EmitLabel(TP_RT_PFX + 'READMEM');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  L1 := LabelGen;  { $0040 segment handler }
  L2 := LabelGen;  { $B800 segment handler }
  L3 := LabelGen;  { default -> 0 }
  L4 := LabelGen;  { fin }
  L5 := LabelGen;  { $0040:$0017 handler }
  L6 := LabelGen;  { $0040:$0049 handler }
  L7 := LabelGen;  { $0040:$004A handler }
  L8 := LabelGen;  { $0040:$0013 handler (TODO 28) }
  { Verifier segment $0040 (BIOS Data Area) }
  EmitInstr('CMP EAX,40h');
  EmitInstr('JE ' + L1);
  { Verifier segment $B800 (video texte) }
  EmitInstr('CMP EAX,0B800h');
  EmitInstr('JE ' + L2);
  { Segment non emule -> 0 }
  EmitInstr('JMP ' + L3);

  { --- Segment $0040 : BIOS Data Area --- }
  EmitLabel(L1);
  { Offset $0013 : memoire conventionnelle en Ko (TODO 28) }
  EmitInstr('CMP EDX,13h');
  EmitInstr('JE ' + L8);
  { Offset $0017 : etat clavier (shift flags) }
  EmitInstr('CMP EDX,17h');
  EmitInstr('JE ' + L5);
  { Offset $0049 : mode video courant }
  EmitInstr('CMP EDX,49h');
  EmitInstr('JE ' + L6);
  { Offset $004A : nombre de colonnes }
  EmitInstr('CMP EDX,4Ah');
  EmitInstr('JE ' + L7);
  { Offset $0084 : nombre de lignes - 1 }
  EmitInstr('CMP EDX,84h');
  EmitInstr('JNE ' + L3);
  EmitInstr('MOV EAX,24');   { 25 lignes - 1 = 24 }
  EmitInstr('JMP ' + L4);

  { $0040:$0017 -> etat clavier via GetKeyState }
  EmitLabel(L5);
  EmitInstr('XOR EAX,EAX');
  { Bit 0 : Right Shift (VK_RSHIFT=A1h) }
  EmitInstr('PUSH 0A1h');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],1');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 1 : Left Shift (VK_LSHIFT=A0h) }
  EmitInstr('PUSH 0A0h');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],2');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 2 : Ctrl (VK_CONTROL=11h) }
  EmitInstr('PUSH 11h');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],4');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 3 : Alt (VK_MENU=12h) }
  EmitInstr('PUSH 12h');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],8');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 4 : Scroll Lock (VK_SCROLL=91h) }
  EmitInstr('PUSH 91h');
  EmitInstr('CALL _GetKeyState@4');
  EmitInstr('TEST EAX,1');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],10h');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 5 : Num Lock (VK_NUMLOCK=90h) }
  EmitInstr('PUSH 90h');
  EmitInstr('CALL _GetKeyState@4');
  EmitInstr('TEST EAX,1');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],20h');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 6 : Caps Lock (VK_CAPITAL=14h) }
  EmitInstr('PUSH 14h');
  EmitInstr('CALL _GetKeyState@4');
  EmitInstr('TEST EAX,1');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],40h');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bit 7 : Insert (VK_INSERT=2Dh) }
  EmitInstr('PUSH 2Dh');
  EmitInstr('CALL _GetKeyState@4');
  EmitInstr('TEST EAX,1');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR BYTE PTR [MEM_TMPVAL],80h');
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('MOVZX EAX,BYTE PTR [MEM_TMPVAL]');
  EmitInstr('MOV BYTE PTR [MEM_TMPVAL],0');  { reset }
  EmitInstr('JMP ' + L4);

  { $0040:$0049 -> mode video = 03h (texte 80x25) }
  EmitLabel(L6);
  EmitInstr('MOV EAX,3');
  EmitInstr('JMP ' + L4);

  { $0040:$004A -> colonnes = 80 }
  EmitLabel(L7);
  EmitInstr('MOV EAX,80');
  EmitInstr('JMP ' + L4);

  { $0040:$0013 -> memoire conventionnelle en Ko (TODO 28) }
  { Valeur standard : 640 Ko (retourne comme Word = 16 bits) }
  EmitLabel(L8);
  EmitInstr('MOV EAX,640');
  EmitInstr('JMP ' + L4);

  { --- Segment $B800 : memoire video texte (stub, retourne 0) --- }
  EmitLabel(L2);
  EmitInstr('XOR EAX,EAX');
  EmitComment('memoire video texte non emulee (retourne 0)');
  EmitInstr('JMP ' + L4);

  { --- Defaut : segment non emule -> 0 --- }
  EmitLabel(L3);
  EmitInstr('XOR EAX,EAX');

  { Sortie }
  EmitLabel(L4);
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_WRITEMEM : ecriture memoire emulee ------------ }
  { Parametres : EAX = segment, EDX = offset, ECX = valeur       }
  { Emulation minimale : ignore les ecritures (stub + commentaire)}
  EmitLabel(TP_RT_PFX + 'WRITEMEM');
  EmitComment('Mem[Seg:Ofs] := val  (ecriture emulee - stub)');
  EmitInstr('RET');

  { ------ _TPRT_INPORT : lecture port I/O emule ---------------- }
  { Parametre : EAX = numero de port                              }
  { Retourne dans EAX : valeur lue (emulee)                       }
  { Port $60 : lecture clavier -> GetAsyncKeyState(VK_xxx)        }
  { Port $61 : controle haut-parleur -> retourne 0                }
  { Port $70 : index CMOS RTC -> retourne index sauvegarde        }
  { Port $71 : donnees CMOS RTC -> GetLocalTime selon index       }
  { Port $3F8-$3FE : ports serie COM1 -> stub                     }
  { Autres : retourne 0                                            }
  L1 := LabelGen;  { port $60 }
  L2 := LabelGen;  { port $61 }
  L3 := LabelGen;  { port $70 }
  L4 := LabelGen;  { port $71 }
  L5 := LabelGen;  { defaut }
  L6 := LabelGen;  { fin }
  L7 := LabelGen;  { port $71 secondes }
  EmitLabel(TP_RT_PFX + 'INPORT');
  EmitInstr('PUSH EBX');
  { Port $60 : lecture clavier }
  EmitInstr('CMP EAX,60h');
  EmitInstr('JE ' + L1);
  { Port $61 : controle haut-parleur }
  EmitInstr('CMP EAX,61h');
  EmitInstr('JE ' + L2);
  { Port $70 : index CMOS }
  EmitInstr('CMP EAX,70h');
  EmitInstr('JE ' + L3);
  { Port $71 : donnees CMOS }
  EmitInstr('CMP EAX,71h');
  EmitInstr('JE ' + L4);
  { Defaut }
  EmitInstr('JMP ' + L5);

  { Port $60 : retourne derniere touche via GetAsyncKeyState }
  EmitLabel(L1);
  EmitComment('Port[$60] : lecture clavier emulee');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('MOV ECX,255');
  EmitLabel(LabelGen);
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH ECX');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('POP ECX');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JNZ ' + LabelGen);
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_LBL_PFX + IntToStr_(EmitLabelSeq - 2));
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('MOV EAX,ECX');   { EAX = virtual key code }
  EmitInstr('JMP ' + L6);

  { Port $61 : controle haut-parleur (retourne 0) }
  EmitLabel(L2);
  EmitComment('Port[$61] : controle haut-parleur (stub)');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + L6);

  { Port $70 : index CMOS RTC (retourne index sauvegarde) }
  EmitLabel(L3);
  EmitComment('Port[$70] : index CMOS RTC');
  EmitInstr('MOVZX EAX,BYTE PTR [PORT_RTCIDX]');
  EmitInstr('JMP ' + L6);

  { Port $71 : donnees CMOS RTC -> GetLocalTime selon PORT_RTCIDX }
  EmitLabel(L4);
  EmitComment('Port[$71] : donnees CMOS RTC via GetLocalTime');
  { Appeler GetLocalTime(&SYSTEMTIME sur pile) }
  EmitInstr('SUB ESP,16');       { SYSTEMTIME = 16 octets }
  EmitInstr('PUSH ESP');
  EmitInstr('CALL _GetLocalTime@4');
  { PORT_RTCIDX : 0=secondes, 2=minutes, 4=heures, 6=jour semaine }
  {               7=jour mois, 8=mois, 9=annee                     }
  EmitInstr('MOVZX EBX,BYTE PTR [PORT_RTCIDX]');
  EmitInstr('CMP EBX,0');
  EmitInstr('JNE ' + LabelGen);
  { Index 0 : secondes (SYSTEMTIME.wSecond = offset 12) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+12]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,2');
  EmitInstr('JNE ' + LabelGen);
  { Index 2 : minutes (SYSTEMTIME.wMinute = offset 10) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+10]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,4');
  EmitInstr('JNE ' + LabelGen);
  { Index 4 : heures (SYSTEMTIME.wHour = offset 8) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+8]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,6');
  EmitInstr('JNE ' + LabelGen);
  { Index 6 : jour de la semaine (SYSTEMTIME.wDayOfWeek = offset 4) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+4]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,7');
  EmitInstr('JNE ' + LabelGen);
  { Index 7 : jour du mois (SYSTEMTIME.wDay = offset 6) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+6]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,8');
  EmitInstr('JNE ' + LabelGen);
  { Index 8 : mois (SYSTEMTIME.wMonth = offset 2) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP+2]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP EBX,9');
  EmitInstr('JNE ' + LabelGen);
  { Index 9 : annee (SYSTEMTIME.wYear = offset 0) }
  EmitInstr('MOVZX EAX,WORD PTR [ESP]');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Index non reconnu }
  EmitInstr('XOR EAX,EAX');
  EmitInstr('ADD ESP,16');
  EmitInstr('JMP ' + L6);

  { Defaut : port non emule -> 0 }
  EmitLabel(L5);
  EmitComment('Port non emule (retourne 0)');
  EmitInstr('XOR EAX,EAX');

  { Sortie }
  EmitLabel(L6);
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_OUTPORT : ecriture port I/O emule ------------- }
  { Parametres : EAX = numero de port, EDX = valeur               }
  { Port $61 : bit 0-1 controle haut-parleur -> Beep API          }
  { Port $70 : sauvegarde index CMOS dans PORT_RTCIDX              }
  { Autres : ignore (stub)                                         }
  L1 := LabelGen;  { port $61 }
  L2 := LabelGen;  { port $70 }
  L3 := LabelGen;  { fin }
  EmitLabel(TP_RT_PFX + 'OUTPORT');
  EmitInstr('PUSH EBX');
  { Port $61 : haut-parleur }
  EmitInstr('CMP EAX,61h');
  EmitInstr('JE ' + L1);
  { Port $70 : index CMOS }
  EmitInstr('CMP EAX,70h');
  EmitInstr('JE ' + L2);
  { Defaut : ignorer }
  EmitInstr('JMP ' + L3);

  { Port $61 : controle haut-parleur via Beep API }
  EmitLabel(L1);
  EmitComment('Port[$61] : controle haut-parleur');
  EmitInstr('TEST EDX,3');    { bits 0-1 actives = son ON }
  EmitInstr('JZ ' + L3);
  EmitInstr('PUSH 100');       { duree 100ms }
  EmitInstr('PUSH 800');       { frequence 800 Hz }
  EmitInstr('CALL _Beep@8');
  EmitInstr('JMP ' + L3);

  { Port $70 : sauvegarder index CMOS }
  EmitLabel(L2);
  EmitComment('Port[$70] : sauvegarde index CMOS RTC');
  EmitInstr('MOV BYTE PTR [PORT_RTCIDX],DL');

  { Sortie }
  EmitLabel(L3);
  EmitInstr('POP EBX');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 23 - ROUTINES RUNTIME INTERRUPTIONS   [IMPLEMENTE]      }
{ ============================================================ }

Procedure EmitIntrRuntime;
Var
  L1, L2, L3, L4, L5, L6, L7, L8, L9, LA : TString;
Begin
  EmitBlankLine;
  EmitComment('============================================================');
  EmitComment(' RUNTIME INTR : emulation INT 10h/16h/33h et Intr()        ');
  EmitComment('============================================================');

  { ------ _TPRT_INT10 : emulation INT 10h (Video BIOS) ----------- }
  { Utilise les registres AH, AL, BH, BL, CX, DX disponibles       }
  { AH = numero de fonction (passe dans le byte haut de AX)         }
  { Pour appels depuis ASM : les registres sont deja positionnes    }
  EmitLabel(TP_RT_PFX + 'INT10');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  { Dispatch selon AH }
  EmitInstr('MOV EBX,EAX');             { sauver AX dans EBX }
  EmitInstr('SHR EBX,8');
  EmitInstr('AND EBX,0FFh');            { EBX = AH (numero de fonction) }
  L1 := LabelGen;   { func 00h : set video mode }
  L2 := LabelGen;   { func 02h : set cursor position }
  L3 := LabelGen;   { func 03h : get cursor position }
  L4 := LabelGen;   { func 06h : scroll up }
  L5 := LabelGen;   { func 07h : scroll down }
  L6 := LabelGen;   { func 09h : write char+attr }
  L7 := LabelGen;   { func 0Eh : teletype write }
  L8 := LabelGen;   { func 0Fh : get video mode }
  L9 := LabelGen;   { fin }
  LA := LabelGen;   { defaut }
  { Fonction 00h : changer mode video }
  EmitInstr('CMP BL,00h');
  EmitInstr('JE ' + L1);
  { Fonction 02h : positionner curseur }
  EmitInstr('CMP BL,02h');
  EmitInstr('JE ' + L2);
  { Fonction 03h : lire position curseur }
  EmitInstr('CMP BL,03h');
  EmitInstr('JE ' + L3);
  { Fonction 06h : defiler vers le haut }
  EmitInstr('CMP BL,06h');
  EmitInstr('JE ' + L4);
  { Fonction 07h : defiler vers le bas }
  EmitInstr('CMP BL,07h');
  EmitInstr('JE ' + L5);
  { Fonction 09h : ecrire caractere+attribut }
  EmitInstr('CMP BL,09h');
  EmitInstr('JE ' + L6);
  { Fonction 0Eh : ecrire caractere teletype }
  EmitInstr('CMP BL,0Eh');
  EmitInstr('JE ' + L7);
  { Fonction 0Fh : lire mode video }
  EmitInstr('CMP BL,0Fh');
  EmitInstr('JE ' + L8);
  { Defaut : non gere }
  EmitInstr('JMP ' + LA);

  { --- Fonction 00h : changer mode video --- }
  { AL = mode video (03h=texte 80x25, 13h=graphique 320x200) }
  EmitLabel(L1);
  EmitComment('INT 10h AH=00h : set video mode');
  EmitInstr('AND EAX,0FFh');             { AL = mode video }
  EmitInstr('MOV BYTE PTR [INT_VIDEOMODE],AL');
  EmitInstr('CMP AL,03h');
  EmitInstr('JNE ' + L9);
  { Mode 03h : texte 80x25 -> SetConsoleScreenBufferSize(hStdout, 80|(25<<16)) }
  EmitInstr('PUSH 001900050h');          { COORD: X=80, Y=25 (packed) }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _SetConsoleScreenBufferSize@8');
  EmitInstr('JMP ' + L9);

  { --- Fonction 02h : positionner curseur --- }
  { DH = ligne, DL = colonne, BH = page }
  EmitLabel(L2);
  EmitComment('INT 10h AH=02h : set cursor position');
  { Sauvegarder DH/DL dans les variables }
  EmitInstr('MOV BYTE PTR [INT_CURSORY],DH');
  EmitInstr('MOV BYTE PTR [INT_CURSORX],DL');
  { SetConsoleCursorPosition(hStdout, COORD) }
  { COORD = DL | (DH << 8) dans un DWORD (X en bits 0-15, Y en bits 16-31) }
  EmitInstr('MOVZX ECX,DL');              { X = colonne }
  EmitInstr('MOVZX ESI,DH');              { Y = ligne }
  EmitInstr('SHL ESI,16');
  EmitInstr('OR ECX,ESI');                 { COORD packed }
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _SetConsoleCursorPosition@8');
  EmitInstr('JMP ' + L9);

  { --- Fonction 03h : lire position curseur --- }
  { Retourne DH = ligne, DL = colonne, CH = debut curseur, CL = fin curseur }
  EmitLabel(L3);
  EmitComment('INT 10h AH=03h : get cursor position');
  { GetConsoleScreenBufferInfo(hStdout, &INT_CSBI) }
  EmitInstr('PUSH OFFSET INT_CSBI');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _GetConsoleScreenBufferInfo@8');
  { CSBI.dwCursorPosition = offset 4 : COORD (X=WORD, Y=WORD) }
  EmitInstr('MOVZX EDX,WORD PTR [INT_CSBI+4]');   { X = colonne }
  EmitInstr('MOV DL,BYTE PTR [INT_CSBI+4]');       { DL = colonne }
  EmitInstr('MOV DH,BYTE PTR [INT_CSBI+6]');       { DH = ligne }
  EmitInstr('MOV CX,0607h');              { CH=6 (debut), CL=7 (fin) curseur }
  EmitInstr('JMP ' + L9);

  { --- Fonction 06h : defiler vers le haut --- }
  { AL = nb lignes (0=efface), BH = attr remplissage }
  { CH,CL = ligne/col coin sup gauche }
  { DH,DL = ligne/col coin inf droit }
  EmitLabel(L4);
  EmitComment('INT 10h AH=06h : scroll up');
  { ScrollConsoleScreenBufferA(hStdout, lpScrollRect, lpClipRect, dwDestOrigin, lpFill) }
  { Simplification : efface l ecran si AL=0 }
  EmitInstr('AND EAX,0FFh');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + L9);                 { scroll partiel non emule }
  { Efface l ecran : remplir 80*25=2000 caracteres avec espace }
  EmitInstr('PUSH OFFSET BYTESWR');       { lpNumberOfCharsWritten }
  EmitInstr('PUSH 0');                     { dwWriteCoord = 0,0 }
  EmitInstr('PUSH 2000');                  { nLength = 80*25 }
  EmitInstr('PUSH 32');                    { cCharacter = space }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _FillConsoleOutputCharacterA@20');
  { Remplir les attributs aussi }
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH 2000');
  EmitInstr('PUSH 7');                     { attribut normal (gris sur noir) }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _FillConsoleOutputAttribute@20');
  { Repositionner le curseur en 0,0 }
  EmitInstr('PUSH 0');                     { COORD(0,0) }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _SetConsoleCursorPosition@8');
  EmitInstr('JMP ' + L9);

  { --- Fonction 07h : defiler vers le bas --- }
  EmitLabel(L5);
  EmitComment('INT 10h AH=07h : scroll down (stub)');
  EmitInstr('JMP ' + L9);

  { --- Fonction 09h : ecrire caractere avec attribut --- }
  { AL = caractere, BH = page, BL = attribut, CX = count }
  EmitLabel(L6);
  EmitComment('INT 10h AH=09h : write char+attr');
  EmitInstr('AND EAX,0FFh');              { AL = caractere }
  EmitInstr('MOV BYTE PTR [NUMBUF],AL');
  { Ecrire le caractere via WriteFile }
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('JMP ' + L9);

  { --- Fonction 0Eh : ecrire caractere teletype --- }
  { AL = caractere, BH = page }
  EmitLabel(L7);
  EmitComment('INT 10h AH=0Eh : teletype write');
  EmitInstr('AND EAX,0FFh');
  EmitInstr('MOV BYTE PTR [NUMBUF],AL');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('JMP ' + L9);

  { --- Fonction 0Fh : lire mode video --- }
  { Retourne AL = mode, AH = nb colonnes, BH = page active }
  EmitLabel(L8);
  EmitComment('INT 10h AH=0Fh : get video mode');
  EmitInstr('MOVZX EAX,BYTE PTR [INT_VIDEOMODE]');  { AL = mode }
  EmitInstr('OR EAX,5000h');                          { AH = 80 colonnes }
  EmitInstr('XOR EBX,EBX');                            { BH = page 0 }
  EmitInstr('JMP ' + L9);

  { Defaut }
  EmitLabel(LA);
  EmitComment('INT 10h : fonction non emulee');

  { Fin INT 10h }
  EmitLabel(L9);
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_INT16 : emulation INT 16h (Clavier BIOS) -------- }
  { AH = numero de fonction                                         }
  { Fonction 00h : lire touche -> AH=scan, AL=char                 }
  { Fonction 01h : touche disponible -> ZF=0 si oui, AH=scan AL=char }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INT16');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  L1 := LabelGen;  { func 00h }
  L2 := LabelGen;  { func 01h }
  L3 := LabelGen;  { fin }
  L4 := LabelGen;  { defaut }
  { Dispatch AH }
  EmitInstr('MOV EBX,EAX');
  EmitInstr('SHR EBX,8');
  EmitInstr('AND EBX,0FFh');
  { Fonction 00h }
  EmitInstr('CMP BL,00h');
  EmitInstr('JE ' + L1);
  { Fonction 01h }
  EmitInstr('CMP BL,01h');
  EmitInstr('JE ' + L2);
  EmitInstr('JMP ' + L4);

  { --- Fonction 00h : attendre et lire une touche --- }
  EmitLabel(L1);
  EmitComment('INT 16h AH=00h : read key (blocking)');
  { ReadConsoleInputA(hStdin, &INT_INPREC, 1, &INT_INEVCNT) }
  EmitLabel(LabelGen);   { boucle d attente }
  EmitInstr('PUSH OFFSET INT_INEVCNT');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET INT_INPREC');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL _ReadConsoleInputA@16');
  { Verifier que c est un evenement clavier (EventType = KEY_EVENT = 1) }
  EmitInstr('CMP WORD PTR [INT_INPREC],1');
  EmitInstr('JNE ' + TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Verifier bKeyDown = TRUE }
  EmitInstr('CMP DWORD PTR [INT_INPREC+4],1');
  EmitInstr('JNE ' + TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { wVirtualScanCode = offset 12 (WORD), uChar.AsciiChar = offset 14 (BYTE) }
  EmitInstr('MOVZX EAX,BYTE PTR [INT_INPREC+14]');  { AL = ASCII char }
  EmitInstr('MOV AH,BYTE PTR [INT_INPREC+12]');     { AH = scan code }
  EmitInstr('MOV BYTE PTR [INT_KBCHAR],AL');
  EmitInstr('MOV BYTE PTR [INT_KBSCAN],AH');
  EmitInstr('JMP ' + L3);

  { --- Fonction 01h : verifier si touche disponible --- }
  EmitLabel(L2);
  EmitComment('INT 16h AH=01h : check key available');
  { GetNumberOfConsoleInputEvents(hStdin, &INT_INEVCNT) }
  EmitInstr('PUSH OFFSET INT_INEVCNT');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL _GetNumberOfConsoleInputEvents@8');
  { Si INT_INEVCNT > 0, lire avec PeekConsoleInputA }
  EmitInstr('CMP DWORD PTR [INT_INEVCNT],0');
  EmitInstr('JE ' + LabelGen);
  { PeekConsoleInputA pour lire sans consommer }
  EmitInstr('PUSH OFFSET INT_INEVCNT');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET INT_INPREC');
  EmitInstr('PUSH DWORD PTR [HSTDIN]');
  EmitInstr('CALL _PeekConsoleInputA@16');
  { Verifier KEY_EVENT et bKeyDown }
  EmitInstr('CMP WORD PTR [INT_INPREC],1');
  EmitInstr('JNE ' + TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('CMP DWORD PTR [INT_INPREC+4],1');
  EmitInstr('JNE ' + TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Touche disponible : retourner AH=scan, AL=char, ZF=0 }
  EmitInstr('MOVZX EAX,BYTE PTR [INT_INPREC+14]');
  EmitInstr('MOV AH,BYTE PTR [INT_INPREC+12]');
  EmitInstr('OR EAX,EAX');                { clear ZF (touche dispo) }
  EmitInstr('JMP ' + L3);
  { Pas de touche : ZF=1 }
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('XOR EAX,EAX');               { ZF=1 (pas de touche) }
  EmitInstr('JMP ' + L3);

  { Defaut }
  EmitLabel(L4);
  EmitComment('INT 16h : fonction non emulee');
  EmitInstr('XOR EAX,EAX');

  { Fin INT 16h }
  EmitLabel(L3);
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_INT33 : emulation INT 33h (Souris) -------------- }
  { AX = numero de fonction                                         }
  { Fonction 00h : initialiser souris -> AX=-1 (souris presente)   }
  { Fonction 03h : position et boutons -> BX=boutons, CX=X, DX=Y  }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INT33');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  L1 := LabelGen;  { func 00h }
  L2 := LabelGen;  { func 03h }
  L3 := LabelGen;  { fin }
  L4 := LabelGen;  { defaut }
  { Dispatch AX (pas AH, car INT 33h utilise AX complet) }
  EmitInstr('AND EAX,0FFFFh');
  EmitInstr('CMP AX,0');
  EmitInstr('JE ' + L1);
  EmitInstr('CMP AX,3');
  EmitInstr('JE ' + L2);
  EmitInstr('JMP ' + L4);

  { --- Fonction 00h : initialiser souris --- }
  EmitLabel(L1);
  EmitComment('INT 33h AX=0 : init mouse');
  { GetSystemMetrics(SM_MOUSEPRESENT=19) }
  EmitInstr('PUSH 19');
  EmitInstr('CALL _GetSystemMetrics@4');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('MOV EAX,0FFFFh');           { AX = -1 : souris presente }
  EmitInstr('MOV EBX,2');                 { BX = 2 boutons }
  EmitInstr('JMP ' + L3);
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('XOR EAX,EAX');              { AX = 0 : pas de souris }
  EmitInstr('XOR EBX,EBX');
  EmitInstr('JMP ' + L3);

  { --- Fonction 03h : position et boutons --- }
  EmitLabel(L2);
  EmitComment('INT 33h AX=3 : get mouse pos+buttons');
  { GetCursorPos(&INT_CURPOS) }
  EmitInstr('PUSH OFFSET INT_CURPOS');
  EmitInstr('CALL _GetCursorPos@4');
  EmitInstr('MOV ECX,DWORD PTR [INT_CURPOS]');    { CX = X }
  EmitInstr('MOV EDX,DWORD PTR [INT_CURPOS+4]');  { DX = Y }
  { Boutons via GetAsyncKeyState }
  EmitInstr('XOR EBX,EBX');
  { Bouton gauche (VK_LBUTTON=01h) }
  EmitInstr('PUSH 1');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR EBX,1');                  { bit 0 = bouton gauche }
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  { Bouton droit (VK_RBUTTON=02h) }
  EmitInstr('PUSH 2');
  EmitInstr('CALL _GetAsyncKeyState@4');
  EmitInstr('TEST EAX,8000h');
  EmitInstr('JZ ' + LabelGen);
  EmitInstr('OR EBX,2');                  { bit 1 = bouton droit }
  EmitLabel(TP_LBL_PFX + IntToStr_(EmitLabelSeq - 1));
  EmitInstr('MOV EAX,EBX');              { sauver boutons }
  EmitInstr('JMP ' + L3);

  { Defaut }
  EmitLabel(L4);
  EmitComment('INT 33h : fonction non emulee');
  EmitInstr('XOR EAX,EAX');

  { Fin INT 33h }
  EmitLabel(L3);
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_INTR : dispatcher general pour Intr(IntNo, Regs) - }
  { Parametres sur la pile :                                          }
  {   [ESP+4] = IntNo (numero d interruption, passe par ParseStmt)   }
  {   [ESP+8] = pointeur vers structure Registers                    }
  { Structure Registers Turbo Pascal :                                }
  {   Offset 0 : AX (AH=byte 1, AL=byte 0)                          }
  {   Offset 2 : BX                                                   }
  {   Offset 4 : CX                                                   }
  {   Offset 6 : DX                                                   }
  {   Offset 8 : BP                                                   }
  {   Offset 10: SI                                                    }
  {   Offset 12: DI                                                    }
  {   Offset 14: DS                                                    }
  {   Offset 16: ES                                                    }
  {   Offset 18: Flags                                                 }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INTR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  L1 := LabelGen;  { INT 10h }
  L2 := LabelGen;  { INT 16h }
  L3 := LabelGen;  { INT 21h }
  L4 := LabelGen;  { INT 33h }
  L5 := LabelGen;  { fin }
  L6 := LabelGen;  { defaut }
  { Charger IntNo }
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');    { IntNo }
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');   { pointeur Registers }
  { Charger les registres de la structure }
  EmitInstr('MOVZX EAX,WORD PTR [ESI]');      { AX }
  EmitInstr('MOVZX EBX,WORD PTR [ESI+2]');   { BX }
  EmitInstr('MOVZX ECX,WORD PTR [ESI+4]');   { CX }
  EmitInstr('MOVZX EDX,WORD PTR [ESI+6]');   { DX }
  { Dispatcher selon IntNo }
  EmitInstr('MOV EDI,DWORD PTR [EBP+8]');    { IntNo }
  EmitInstr('CMP EDI,10h');
  EmitInstr('JE ' + L1);
  EmitInstr('CMP EDI,16h');
  EmitInstr('JE ' + L2);
  EmitInstr('CMP EDI,21h');
  EmitInstr('JE ' + L3);
  EmitInstr('CMP EDI,33h');
  EmitInstr('JE ' + L4);
  EmitInstr('JMP ' + L6);

  { INT 10h via _TPRT_INT10 }
  EmitLabel(L1);
  EmitInstr('CALL ' + TP_RT_PFX + 'INT10');
  { Stocker les resultats dans la structure Registers }
  EmitInstr('MOV WORD PTR [ESI],AX');       { AX }
  EmitInstr('MOV WORD PTR [ESI+2],BX');    { BX }
  EmitInstr('MOV WORD PTR [ESI+4],CX');    { CX }
  EmitInstr('MOV WORD PTR [ESI+6],DX');    { DX }
  EmitInstr('JMP ' + L5);

  { INT 16h via _TPRT_INT16 }
  EmitLabel(L2);
  EmitInstr('CALL ' + TP_RT_PFX + 'INT16');
  EmitInstr('MOV WORD PTR [ESI],AX');
  EmitInstr('JMP ' + L5);

  { INT 21h via _TPRT_MSDOS }
  EmitLabel(L3);
  EmitInstr('PUSH ESI');                     { passer pointeur Registers }
  EmitInstr('CALL ' + TP_RT_PFX + 'MSDOS');
  EmitInstr('ADD ESP,4');
  EmitInstr('JMP ' + L5);

  { INT 33h via _TPRT_INT33 }
  EmitLabel(L4);
  EmitInstr('CALL ' + TP_RT_PFX + 'INT33');
  EmitInstr('MOV WORD PTR [ESI],AX');       { AX }
  EmitInstr('MOV WORD PTR [ESI+2],BX');    { BX }
  EmitInstr('MOV WORD PTR [ESI+4],CX');    { CX }
  EmitInstr('MOV WORD PTR [ESI+6],DX');    { DX }
  EmitInstr('JMP ' + L5);

  { Defaut : interruption non emulee }
  EmitLabel(L6);
  EmitComment('Interruption non emulee (NOP)');

  { Fin _TPRT_INTR }
  EmitLabel(L5);
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 24 - GENERATION PE/COFF ET DOS 16 BITS  [IMPLEMENTE]   }
{ ============================================================ }

{ --- Constantes PE --- }
Const
  PE_IMG_BASE     = $00400000;
  PE_SECT_ALIGN_  = $1000;
  PE_FILE_ALIGN_  = $200;
  PE_TEXT_RVA     = $1000;
  PE_DATA_RVA     = $2000;
  PE_IDATA_RVA    = $3000;
  PE_HDR_SIZE     = $200;
  PE_NUM_IMPORTS_OLD  = 7;

{ --- Constantes du mini-assembleur binaire --- }
  BC_MAX_CODE   = 262144;  { 256 Ko de code machine max }
  BC_MAX_DATA   = 262144;  { 256 Ko de donnees max      }
  BC_MAX_LABEL  = 8192;    { labels de code max          }
  BC_MAX_DLABEL = 8192;    { labels de donnees max       }
  BC_MAX_FIXUP  = 32768;   { fixups max                  }
  BC_MAX_IMP    = 256;     { imports API max             }

  { Types de fixup }
  BC_FIX_REL32  = 0;       { CALL/JMP rel32 vers label code    }
  BC_FIX_ABS32_CODE = 1;   { adresse absolue vers label code   }
  BC_FIX_ABS32_DATA = 2;   { adresse absolue vers label data   }
  BC_FIX_ABS32_IMP  = 3;   { adresse absolue vers IAT entry    }
  BC_FIX_REL16      = 4;   { CALL/JMP rel16 vers label code (DOS) }
  BC_FIX_ABS16_DATA = 5;   { offset 16 bits dans segment data (DOS) }

  { Index de registres x86-32 }
  R_EAX = 0; R_ECX = 1; R_EDX = 2; R_EBX = 3;
  R_ESP = 4; R_EBP = 5; R_ESI = 6; R_EDI = 7;

Type
  TBcLabel = Record
    Name   : TString;
    Offset : LongInt;
  End;
  TBcFixup = Record
    CodeOfs  : LongInt;    { offset dans BcCode ou ecrire la valeur   }
    LblName  : TString;    { nom du label cible                       }
    Kind     : Integer;    { BC_FIX_REL32, BC_FIX_ABS32_DATA, etc.   }
    Addend   : LongInt;    { deplacemenent additionnel                }
  End;
  TBcImport = Record
    ApiName  : TString;    { nom normalise de l API (ex: ExitProcess) }
    DllName  : TString;    { nom de la DLL (ex: kernel32.dll)         }
    IatSlot  : Integer;    { index dans l IAT                         }
  End;

{ --- Variables du mini-assembleur binaire --- }
Var
  PEBinF : File;
  BcCode     : Array[0..BC_MAX_CODE-1] of Byte;
  BcCodeLen  : LongInt;
  BcData     : Array[0..BC_MAX_DATA-1] of Byte;
  BcDataLen  : LongInt;
  BcLabels   : Array[0..BC_MAX_LABEL-1] of TBcLabel;
  BcLabelCnt : Integer;
  BcDLabels  : Array[0..BC_MAX_DLABEL-1] of TBcLabel;
  BcDLabelCnt: Integer;
  BcFixups   : Array[0..BC_MAX_FIXUP-1] of TBcFixup;
  BcFixupCnt : LongInt;
  BcImports  : Array[0..BC_MAX_IMP-1] of TBcImport;
  BcImportCnt: Integer;

{ --- Helpers ecriture binaire --- }

Procedure PEWrB(B: Byte);
Begin
  BlockWrite(PEBinF, B, 1);
End;

Procedure PEWrW(W: Word);
Begin
  BlockWrite(PEBinF, W, 2);
End;

Procedure PEWrD(D: LongInt);
Begin
  BlockWrite(PEBinF, D, 4);
End;

Procedure PEWrZeros(N: LongInt);
Var I: LongInt;
Begin
  For I := 1 To N Do PEWrB(0);
End;

Procedure PEWrName8(S: TString);
Var I: Integer;
Begin
  For I := 1 To 8 Do
    If I <= Length(S) Then PEWrB(Byte(S[I]))
    Else PEWrB(0);
End;

Procedure PEWrStr(S: TString);
Var I: Integer;
Begin
  For I := 1 To Length(S) Do PEWrB(Byte(S[I]));
  PEWrB(0);
End;

Procedure PEPadTo(Pos: LongInt);
Begin
  While FilePos(PEBinF) < Pos Do PEWrB(0);
End;

{ ============================================================ }
{ MINI-ASSEMBLEUR x86-32 INTERNE (GENERATION BINAIRE PE)       }
{ ============================================================ }

Procedure BcInit;
Begin
  BcCodeLen := 0; BcDataLen := 0;
  BcLabelCnt := 0; BcDLabelCnt := 0;
  BcFixupCnt := 0; BcImportCnt := 0;
  BcActive := False;
  FillChar(BcCode, SizeOf(BcCode), 0);
  FillChar(BcData, SizeOf(BcData), 0);
End;

{ --- Emission d octets dans BcCode --- }
Procedure BcEmitB(B: Byte);
Begin
  If BcCodeLen < BC_MAX_CODE Then
  Begin BcCode[BcCodeLen] := B; Inc(BcCodeLen); End;
End;

Procedure BcEmitW(W: Word);
Begin
  BcEmitB(Lo(W)); BcEmitB(Hi(W));
End;

Procedure BcEmitD(D: LongInt);
Begin
  BcEmitB(Byte(D)); BcEmitB(Byte(D Shr 8));
  BcEmitB(Byte(D Shr 16)); BcEmitB(Byte(D Shr 24));
End;

{ --- Emission d octets dans BcData --- }
Procedure BcDataB(B: Byte);
Begin
  If BcDataLen < BC_MAX_DATA Then
  Begin BcData[BcDataLen] := B; Inc(BcDataLen); End;
End;

Procedure BcDataD(D: LongInt);
Begin
  BcDataB(Byte(D)); BcDataB(Byte(D Shr 8));
  BcDataB(Byte(D Shr 16)); BcDataB(Byte(D Shr 24));
End;

Procedure BcDataW(W: Word);
Begin
  BcDataB(Lo(W)); BcDataB(Hi(W));
End;

Procedure BcDataStr(Const S: TString);
Var I: Integer;
Begin
  For I := 1 To Length(S) Do BcDataB(Byte(S[I]));
  BcDataB(0);
End;

Procedure BcDataZeros(N: LongInt);
Var I: LongInt;
Begin
  For I := 1 To N Do BcDataB(0);
End;

{ --- Gestion des labels de donnees --- }
Procedure BcDefineDataLabel(Const Nm: TString);
Begin
  If BcDLabelCnt < BC_MAX_DLABEL Then
  Begin
    BcDLabels[BcDLabelCnt].Name := Nm;
    BcDLabels[BcDLabelCnt].Offset := BcDataLen;
    Inc(BcDLabelCnt);
  End;
End;

Function BcFindDataLabel(Const Nm: TString): LongInt;
Var I: Integer;
Begin
  BcFindDataLabel := -1;
  For I := 0 To BcDLabelCnt - 1 Do
    If BcDLabels[I].Name = Nm Then
    Begin BcFindDataLabel := BcDLabels[I].Offset; Exit; End;
End;

{ --- Gestion des labels de code --- }
Procedure BcDefineLabel(Const Nm: TString);
Begin
  If BcLabelCnt < BC_MAX_LABEL Then
  Begin
    BcLabels[BcLabelCnt].Name := Nm;
    BcLabels[BcLabelCnt].Offset := BcCodeLen;
    Inc(BcLabelCnt);
  End;
End;

Function BcFindLabel(Const Nm: TString): LongInt;
Var I: Integer;
Begin
  BcFindLabel := -1;
  For I := 0 To BcLabelCnt - 1 Do
    If BcLabels[I].Name = Nm Then
    Begin BcFindLabel := BcLabels[I].Offset; Exit; End;
End;

{ --- Gestion des fixups --- }
Procedure BcAddFixup(Kind: Integer; Const Lbl: TString; Addend: LongInt);
Begin
  If BcFixupCnt < BC_MAX_FIXUP Then
  Begin
    BcFixups[BcFixupCnt].CodeOfs := BcCodeLen;
    BcFixups[BcFixupCnt].LblName := Lbl;
    BcFixups[BcFixupCnt].Kind := Kind;
    BcFixups[BcFixupCnt].Addend := Addend;
    Inc(BcFixupCnt);
  End;
End;

{ --- Gestion des imports --- }
Function BcNormalizeApi(Const Raw: TString): TString;
Var S: TString; P: Integer;
Begin
  S := Raw;
  If (Length(S) > 0) And (S[1] = '_') Then Delete(S, 1, 1);
  P := Pos('@', S);
  If P > 0 Then S := Copy(S, 1, P - 1);
  BcNormalizeApi := S;
End;

Function BcApiToDll(Const Api: TString): TString;
Var U: TString;
Begin
  U := StrUpperCase(Api);
  { user32.dll }
  If (U = 'REGISTERCLASSA') Or (U = 'CREATEWINDOWEXA') Or
     (U = 'DESTROYWINDOW') Or (U = 'SHOWWINDOW') Or
     (U = 'UPDATEWINDOW') Or (U = 'GETDC') Or
     (U = 'RELEASEDC') Or (U = 'DEFWINDOWPROCA') Or
     (U = 'GETCLIENTRECT') Or (U = 'INVALIDATERECT') Or
     (U = 'PEEKMESSAGEA') Or (U = 'DISPATCHMESSAGEA') Or
     (U = 'TRANSLATEMESSAGE') Or (U = 'POSTQUITMESSAGE') Or
     (U = 'LOADCURSORA') Or
     (U = 'FILLRECT') Or (U = 'GETASYNCKEYSTATE') Or
     (U = 'GETKEYSTATE') Or (U = 'GETCURSORPOS') Or
     (U = 'GETSYSTEMMETRICS') Or (U = 'SHOWCURSOR') Or
     (U = 'MESSAGEBOXA') Then
    BcApiToDll := 'user32.dll'
  { gdi32.dll }
  Else If (U = 'SETPIXEL') Or (U = 'GETPIXEL') Or
     (U = 'MOVETOEX') Or (U = 'LINETO') Or
     (U = 'RECTANGLE') Or (U = 'ELLIPSE') Or
     (U = 'ARC') Or (U = 'PIE') Or
     (U = 'CREATEPEN') Or (U = 'CREATESOLIDBRUSH') Or
     (U = 'SELECTOBJECT') Or (U = 'DELETEOBJECT') Or
     (U = 'TEXTOUTA') Or (U = 'CREATEFONTA') Or
     (U = 'SETBKMODE') Or (U = 'SETTEXTCOLOR') Or
     (U = 'SETBKCOLOR') Or (U = 'GETTEXTEXTENTPOINT32A') Or
     (U = 'CREATECOMPATIBLEDC') Or (U = 'CREATECOMPATIBLEBITMAP') Or
     (U = 'BITBLT') Or (U = 'DELETEDC') Or
     (U = 'FLOODFILL') Or (U = 'GETSTOCKOBJECT') Or
     (U = 'PATBLT') Or (U = 'POLYLINE') Or (U = 'POLYGON') Then
    BcApiToDll := 'gdi32.dll'
  Else
    BcApiToDll := 'kernel32.dll';
End;

Function BcFindOrAddImport(Const RawName: TString): Integer;
Var Api: TString; I: Integer;
Begin
  Api := BcNormalizeApi(RawName);
  For I := 0 To BcImportCnt - 1 Do
    If BcImports[I].ApiName = Api Then
    Begin BcFindOrAddImport := I; Exit; End;
  If BcImportCnt < BC_MAX_IMP Then
  Begin
    BcImports[BcImportCnt].ApiName := Api;
    BcImports[BcImportCnt].DllName := BcApiToDll(Api);
    BcImports[BcImportCnt].IatSlot := BcImportCnt;
    BcFindOrAddImport := BcImportCnt;
    Inc(BcImportCnt);
  End Else
    BcFindOrAddImport := 0;
End;

Function BcIsImport(Const Name: TString): Boolean;
Var U: TString;
Begin
  U := StrUpperCase(BcNormalizeApi(Name));
  BcIsImport := (U = 'EXITPROCESS') Or (U = 'GETSTDHANDLE') Or
    (U = 'WRITEFILE') Or (U = 'READFILE') Or
    (U = 'GETPROCESSHEAP') Or (U = 'HEAPALLOC') Or
    (U = 'HEAPFREE') Or (U = 'HEAPSIZE') Or (U = 'CREATEFILEA') Or
    (U = 'CLOSEHANDLE') Or (U = 'SETFILEPOINTER') Or
    (U = 'GETFILESIZE') Or (U = 'DELETEFILEA') Or
    (U = 'MOVEFILEA') Or (U = 'FLUSHFILEBUFFERS') Or
    (U = 'CREATEDIRECTORYA') Or (U = 'REMOVEDIRECTORYA') Or
    (U = 'SETCURRENTDIRECTORYA') Or (U = 'GETCURRENTDIRECTORYA') Or
    (U = 'GETTICKCOUNT') Or (U = 'SLEEP') Or
    (U = 'GETCOMMANDLINEA') Or (U = 'WRITECONSOLEA') Or
    (U = 'READCONSOLEA') Or (U = 'SETCONSOLECURSORPOSITION') Or
    (U = 'GETCONSOLESCREENBUFFERINFO') Or (U = 'SETCONSOLETEXTATTRIBUTE') Or
    (U = 'FILLCONSOLEOUTPUTCHARACTERA') Or (U = 'FILLCONSOLEOUTPUTATTRIBUTE') Or
    (U = 'GETCONSOLEMODE') Or (U = 'SETCONSOLEMODE') Or
    (U = 'PEEKCONSOLEINPUTA') Or (U = 'READCONSOLEINPUTA') Or
    (U = 'GETNUMBEROFCONSOLEINPUTEVENTS') Or (U = 'BEEP') Or
    (U = 'SCROLLCONSOLESCREENBUFFERA') Or (U = 'FLUSHCONSOLEINPUTBUFFER') Or
    (U = 'GETLOCALTIME') Or (U = 'SETLOCALTIME') Or
    (U = 'GETFILEATTRIBUTESA') Or (U = 'SETFILEATTRIBUTESA') Or
    (U = 'FINDFIRSTFILEA') Or (U = 'FINDNEXTFILEA') Or
    (U = 'FINDCLOSE') Or (U = 'GETDISKFREESPACEA') Or
    (U = 'GETENVIRONMENTVARIABLEA') Or (U = 'CREATEPROCESSA') Or
    (U = 'WAITFORSINGLEOBJECT') Or (U = 'GETEXITCODEPROCESS') Or
    (U = 'GETFULLPATHNAMEA') Or (U = 'GETENVIRONMENTSTRINGSA') Or
    (U = 'GETFILETIME') Or (U = 'FILETIMETODOSDATETIME') Or
    (U = 'REGISTERCLASSA') Or
    (U = 'CREATEWINDOWEXA') Or (U = 'DESTROYWINDOW') Or
    (U = 'SHOWWINDOW') Or (U = 'UPDATEWINDOW') Or
    (U = 'GETDC') Or (U = 'RELEASEDC') Or
    (U = 'DEFWINDOWPROCA') Or (U = 'GETCLIENTRECT') Or
    (U = 'INVALIDATERECT') Or (U = 'PEEKMESSAGEA') Or
    (U = 'DISPATCHMESSAGEA') Or (U = 'TRANSLATEMESSAGE') Or
    (U = 'POSTQUITMESSAGE') Or (U = 'LOADCURSORA') Or
    (U = 'GETMODULEHANDLEA') Or (U = 'FILLRECT') Or
    (U = 'SETPIXEL') Or (U = 'GETPIXEL') Or
    (U = 'MOVETOEX') Or (U = 'LINETO') Or
    (U = 'RECTANGLE') Or (U = 'ELLIPSE') Or
    (U = 'ARC') Or (U = 'PIE') Or
    (U = 'CREATEPEN') Or (U = 'CREATESOLIDBRUSH') Or
    (U = 'SELECTOBJECT') Or (U = 'DELETEOBJECT') Or
    (U = 'TEXTOUTA') Or (U = 'CREATEFONTA') Or
    (U = 'SETBKMODE') Or (U = 'SETTEXTCOLOR') Or
    (U = 'SETBKCOLOR') Or (U = 'GETTEXTEXTENTPOINT32A') Or
    (U = 'CREATECOMPATIBLEDC') Or (U = 'CREATECOMPATIBLEBITMAP') Or
    (U = 'BITBLT') Or (U = 'DELETEDC') Or
    (U = 'FLOODFILL') Or (U = 'GETSTOCKOBJECT') Or
    (U = 'PATBLT') Or (U = 'POLYLINE') Or (U = 'POLYGON') Or
    (U = 'GETASYNCKEYSTATE') Or (U = 'GETKEYSTATE') Or
    (U = 'GETCURSORPOS') Or (U = 'GETSYSTEMMETRICS') Or
    (U = 'SHOWCURSOR') Or (U = 'SETCONSOLESCREENBUFFERSIZE') Or
    (U = 'WRITECONSOLEOUTPUTATTRIBUTE') Or (U = 'SETENDOFFILE') Or
    (U = 'FLUSHFILEBUFFERS') Or (U = 'LSTRLENA') Or
    (U = 'LSTRCPYA') Or (U = 'LSTRCATA') Or
    (U = 'LSTRCMPA') Or (U = 'LSTRCMPIA') Or
    (U = 'GETLASTERROR') Or
    (U = 'MESSAGEBOXA');
End;

{ --- Parseur d operandes x86 --- }

Function BcParseReg32(Const S: TString): Integer;
Var U: TString;
Begin
  U := StrUpperCase(S);
  If U = 'EAX' Then BcParseReg32 := R_EAX
  Else If U = 'ECX' Then BcParseReg32 := R_ECX
  Else If U = 'EDX' Then BcParseReg32 := R_EDX
  Else If U = 'EBX' Then BcParseReg32 := R_EBX
  Else If U = 'ESP' Then BcParseReg32 := R_ESP
  Else If U = 'EBP' Then BcParseReg32 := R_EBP
  Else If U = 'ESI' Then BcParseReg32 := R_ESI
  Else If U = 'EDI' Then BcParseReg32 := R_EDI
  Else BcParseReg32 := -1;
End;

Function BcParseReg8(Const S: TString): Integer;
Var U: TString;
Begin
  U := StrUpperCase(S);
  If U = 'AL' Then BcParseReg8 := 0
  Else If U = 'CL' Then BcParseReg8 := 1
  Else If U = 'DL' Then BcParseReg8 := 2
  Else If U = 'BL' Then BcParseReg8 := 3
  Else If U = 'AH' Then BcParseReg8 := 4
  Else If U = 'CH' Then BcParseReg8 := 5
  Else If U = 'DH' Then BcParseReg8 := 6
  Else If U = 'BH' Then BcParseReg8 := 7
  Else BcParseReg8 := -1;
End;

Function BcParseReg16(Const S: TString): Integer;
Var U: TString;
Begin
  U := StrUpperCase(S);
  If U = 'AX' Then BcParseReg16 := 0
  Else If U = 'CX' Then BcParseReg16 := 1
  Else If U = 'DX' Then BcParseReg16 := 2
  Else If U = 'BX' Then BcParseReg16 := 3
  Else If U = 'SP' Then BcParseReg16 := 4
  Else If U = 'BP' Then BcParseReg16 := 5
  Else If U = 'SI' Then BcParseReg16 := 6
  Else If U = 'DI' Then BcParseReg16 := 7
  Else BcParseReg16 := -1;
End;

{$Q-}{$R-}  { Disable overflow/range checks: hex values like 80000000h exceed LongInt }
Function BcParseImm(Const S: TString; Var V: LongInt): Boolean;
Var T: TString; I: Integer; Neg: Boolean; Ch: Char; U: LongWord;
Begin
  BcParseImm := False; V := 0; U := 0;
  T := S;
  While (Length(T) > 0) And (T[1] = ' ') Do Delete(T, 1, 1);
  While (Length(T) > 0) And (T[Length(T)] = ' ') Do Delete(T, Length(T), 1);
  If T = '' Then Exit;
  Neg := False;
  If T[1] = '-' Then Begin Neg := True; Delete(T, 1, 1); End;
  If T = '' Then Exit;
  If (Length(T) > 1) And (StrUpperCase(Copy(T, Length(T), 1)) = 'H') Then
  Begin
    Delete(T, Length(T), 1);
    If (Length(T) > 1) And (T[1] = '0') Then Delete(T, 1, 1);
    For I := 1 To Length(T) Do Begin
      Ch := UpCase(T[I]);
      If (Ch >= '0') And (Ch <= '9') Then U := U * 16 + LongWord(Ord(Ch) - Ord('0'))
      Else If (Ch >= 'A') And (Ch <= 'F') Then U := U * 16 + LongWord(Ord(Ch) - Ord('A') + 10)
      Else Exit;
    End;
  End
  Else If (Length(T) > 2) And (Copy(T, 1, 2) = '0x') Then
  Begin
    Delete(T, 1, 2);
    For I := 1 To Length(T) Do Begin
      Ch := UpCase(T[I]);
      If (Ch >= '0') And (Ch <= '9') Then U := U * 16 + LongWord(Ord(Ch) - Ord('0'))
      Else If (Ch >= 'A') And (Ch <= 'F') Then U := U * 16 + LongWord(Ord(Ch) - Ord('A') + 10)
      Else Exit;
    End;
  End
  Else Begin
    For I := 1 To Length(T) Do
      If (T[I] >= '0') And (T[I] <= '9') Then U := U * 10 + LongWord(Ord(T[I]) - Ord('0'))
      Else Exit;
  End;
  V := LongInt(U);
  If Neg Then V := -V;
  BcParseImm := True;
End;
{$Q+}{$R+}

{ Emettre ModR/M + SIB + displacement pour operande memoire }
{ Retourne True si l operande est un label de donnee (fixup necessaire) }
{ RegField est le champ /r (0-7) du ModR/M }
Function BcEmitMemRM(Const Mem: TString; RegField: Integer;
                     Var DataLbl: TString; Var DataAdd: LongInt): Boolean;
Var
  Inner, Part1, Part2, DP, DP2: TString;
  P, BaseReg, IdxReg, Idx: Integer;
  Disp: LongInt;
  HasDisp, Neg2: Boolean;
Begin
  BcEmitMemRM := False;
  DataLbl := ''; DataAdd := 0;
  { Extraire le contenu entre crochets }
  Inner := Mem;
  If (Length(Inner) > 0) And (Inner[1] = '[') Then Delete(Inner, 1, 1);
  If (Length(Inner) > 0) And (Inner[Length(Inner)] = ']') Then
    Delete(Inner, Length(Inner), 1);
  While (Length(Inner) > 0) And (Inner[1] = ' ') Do Delete(Inner, 1, 1);
  While (Length(Inner) > 0) And (Inner[Length(Inner)] = ' ') Do
    Delete(Inner, Length(Inner), 1);

  { Chercher un '+' ou '-' pour separer base et displacement }
  P := 0; Disp := 0; HasDisp := False;
  Part1 := ''; Part2 := '';
  { Trouver le premier + ou - apres le debut }
  { Attention : il peut y avoir des chiffres hex comme 0A1h }
  Begin
    Idx := 2; { commencer apres le 1er caractere }
    While Idx <= Length(Inner) Do
    Begin
      If (Inner[Idx] = '+') Or (Inner[Idx] = '-') Then
      Begin P := Idx; Break; End;
      Inc(Idx);
    End;
  End;

  If P > 0 Then
  Begin
    Part1 := Copy(Inner, 1, P - 1);
    While (Length(Part1) > 0) And (Part1[Length(Part1)] = ' ') Do
      Delete(Part1, Length(Part1), 1);
    Part2 := Copy(Inner, P, Length(Inner) - P + 1);
    While (Length(Part2) > 0) And (Part2[1] = ' ') Do Delete(Part2, 1, 1);
  End
  Else
  Begin
    Part1 := Inner; Part2 := '';
  End;

  BaseReg := BcParseReg32(Part1);

  If BaseReg >= 0 Then
  Begin
    { [reg] ou [reg+disp] ou [reg+reg] }
    IdxReg := -1;
    If Part2 <> '' Then
    Begin
      DP := Part2;
      If (DP[1] = '+') Then Delete(DP, 1, 1);
      While (Length(DP) > 0) And (DP[1] = ' ') Do Delete(DP, 1, 1);
      IdxReg := BcParseReg32(DP);
      If IdxReg < 0 Then
      Begin
        If Not BcParseImm(DP, Disp) Then
        Begin
          { Negatif ? }
          If (Part2[1] = '-') Then
          Begin
            Delete(Part2, 1, 1);
            While (Length(Part2) > 0) And (Part2[1] = ' ') Do Delete(Part2, 1, 1);
            If BcParseImm(Part2, Disp) Then
              Disp := -Disp
            Else Exit;
          End Else Exit;
        End;
        HasDisp := True;
      End;
    End;

    If IdxReg >= 0 Then
    Begin
      { [base+index] : ModR/M=04+RegField*8 SIB=base+index*8 }
      BcEmitB($04 Or (RegField Shl 3));
      BcEmitB(Byte(BaseReg) Or Byte(IdxReg Shl 3));
    End
    Else If (Not HasDisp) And (BaseReg <> R_EBP) Then
    Begin
      { [reg] : mod=00, r/m=reg }
      If BaseReg = R_ESP Then
      Begin BcEmitB($04 Or (RegField Shl 3)); BcEmitB($24); End
      Else BcEmitB(Byte(BaseReg) Or Byte(RegField Shl 3));
    End
    Else If HasDisp And (Disp >= -128) And (Disp <= 127) Then
    Begin
      { [reg+disp8] : mod=01 }
      If BaseReg = R_ESP Then
      Begin BcEmitB($44 Or (RegField Shl 3)); BcEmitB($24); End
      Else BcEmitB($40 Or Byte(BaseReg) Or Byte(RegField Shl 3));
      BcEmitB(Byte(Disp));
    End
    Else
    Begin
      { [reg+disp32] : mod=10 }
      If BaseReg = R_ESP Then
      Begin BcEmitB($84 Or (RegField Shl 3)); BcEmitB($24); End
      Else BcEmitB($80 Or Byte(BaseReg) Or Byte(RegField Shl 3));
      BcEmitD(Disp);
    End;
  End
  Else
  Begin
    { [label] ou [label+disp] ou [label+reg*scale] : disp32 }
    DataLbl := Part1;
    DataAdd := 0;
    If Part2 <> '' Then
    Begin
      DP2 := Part2;
      If (DP2[1] = '+') Then Delete(DP2, 1, 1);
      While (Length(DP2) > 0) And (DP2[1] = ' ') Do Delete(DP2, 1, 1);
      { Verifier si c est REG*SCALE (adressage indexe) }
      P := Pos('*', DP2);
      If P > 0 Then
      Begin
        DP := Copy(DP2, 1, P - 1);
        While (Length(DP) > 0) And (DP[Length(DP)] = ' ') Do
          Delete(DP, Length(DP), 1);
        IdxReg := BcParseReg32(DP);
        If IdxReg >= 0 Then
        Begin
          { [label + reg*scale] : SIB avec base=disp32 }
          DP := Copy(DP2, P + 1, Length(DP2) - P);
          While (Length(DP) > 0) And (DP[1] = ' ') Do Delete(DP, 1, 1);
          BcParseImm(DP, Disp);
          { scale: 1->SS=0, 2->SS=1, 4->SS=2, 8->SS=3 }
          Case Disp Of
            1: Disp := 0;
            2: Disp := 1;
            4: Disp := 2;
            8: Disp := 3;
          Else Disp := 0;
          End;
          { ModR/M: mod=00, reg=RegField, rm=100 (SIB) }
          BcEmitB($04 Or (RegField Shl 3));
          { SIB: SS=scale, index=IdxReg, base=101 (disp32) }
          BcEmitB(Byte(Disp Shl 6) Or Byte(IdxReg Shl 3) Or $05);
          If BcIsImport(DataLbl) Then
          Begin
            Idx := BcFindOrAddImport(DataLbl);
            BcAddFixup(BC_FIX_ABS32_IMP, BcImports[Idx].ApiName, Idx);
          End
          Else
            BcAddFixup(BC_FIX_ABS32_DATA, DataLbl, 0);
          BcEmitD(0); { placeholder disp32 }
          BcEmitMemRM := True;
          Exit;
        End;
      End;
      { Sinon, c est un displacement numerique }
      DP2 := Part2;
      If (DP2[1] = '+') Or (DP2[1] = '-') Then
      Begin
        Neg2 := (DP2[1] = '-');
        Delete(DP2, 1, 1);
        While (Length(DP2) > 0) And (DP2[1] = ' ') Do Delete(DP2, 1, 1);
        If BcParseImm(DP2, DataAdd) Then
        Begin If Neg2 Then DataAdd := -DataAdd; End;
      End;
    End;
    BcEmitB($05 Or (RegField Shl 3)); { mod=00, r/m=101 = disp32 direct }
    If BcIsImport(DataLbl) Then
    Begin
      Idx := BcFindOrAddImport(DataLbl);
      BcAddFixup(BC_FIX_ABS32_IMP, BcImports[Idx].ApiName, Idx);
    End
    Else
      BcAddFixup(BC_FIX_ABS32_DATA, DataLbl, DataAdd);
    BcEmitD(0); { placeholder, sera resolu }
    BcEmitMemRM := True;
  End;
End;

{ --- Assembleur principal --- }
Procedure BcAssemble(Const S: TString);
Var
  Line, Mnem, Op1, Op2, Tmp, Rest, ImOp2, ImOp3, R2: TString;
  P, Reg1, Reg2, Imm8Reg, Slot, AluOp, Cp: Integer;
  ImmVal: LongInt;
  DataLbl: TString;
  DataAdd: LongInt;
  IsByte, IsWord, Neg3: Boolean;

  Procedure SplitOps(Const Rest: TString);
  Var J, Depth: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1; Depth := 0;
    While J <= Length(Rest) Do
    Begin
      If Rest[J] = '[' Then Inc(Depth)
      Else If Rest[J] = ']' Then Dec(Depth)
      Else If (Rest[J] = ',') And (Depth = 0) Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

  Function StartsWithBracket(Const X: TString): Boolean;
  Var I: Integer;
  Begin
    StartsWithBracket := False;
    For I := 1 To Length(X) Do
      If X[I] = '[' Then Begin StartsWithBracket := True; Exit; End
      Else If X[I] <> ' ' Then Exit;
  End;

  Function StripSizePrefix(Const X: TString): TString;
  Var U, Res: TString; Idx2: Integer;
  Begin
    U := StrUpperCase(X);
    If Copy(U, 1, 10) = 'DWORD PTR ' Then Res := Copy(X, 11, 255)
    Else If Copy(U, 1, 9) = 'BYTE PTR ' Then Res := Copy(X, 10, 255)
    Else If Copy(U, 1, 9) = 'WORD PTR ' Then Res := Copy(X, 10, 255)
    Else Begin
      Idx2 := Pos('PTR ', U);
      If Idx2 > 0 Then Res := Copy(X, Idx2 + 4, 255)
      Else Res := X;
    End;
    While (Length(Res) > 0) And (Res[1] = ' ') Do Delete(Res, 1, 1);
    StripSizePrefix := Res;
  End;

  Function HasBytePrefix(Const X: TString): Boolean;
  Begin HasBytePrefix := Pos('BYTE PTR', StrUpperCase(X)) > 0; End;

  Function HasWordPrefix(Const X: TString): Boolean;
  Var U: TString;
  Begin
    U := StrUpperCase(X);
    HasWordPrefix := (Pos('WORD PTR', U) > 0) And (Pos('DWORD PTR', U) = 0);
  End;

  Function HasDWordPrefix(Const X: TString): Boolean;
  Begin HasDWordPrefix := Pos('DWORD PTR', StrUpperCase(X)) > 0; End;

Begin { BcAssemble }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;
  SplitOps(Tmp);

  { ---- Instructions sans operandes ---- }
  If Mnem = 'RET' Then Begin BcEmitB($C3); Exit; End;
  If Mnem = 'PUSHAD' Then Begin BcEmitB($60); Exit; End;
  If Mnem = 'POPAD' Then Begin BcEmitB($61); Exit; End;
  If Mnem = 'CDQ' Then Begin BcEmitB($99); Exit; End;
  If Mnem = 'NOP' Then Begin BcEmitB($90); Exit; End;
  If Mnem = 'LODSB' Then Begin BcEmitB($AC); Exit; End;
  If Mnem = 'LODSD' Then Begin BcEmitB($AD); Exit; End;
  If Mnem = 'STOSB' Then Begin BcEmitB($AA); Exit; End;
  If Mnem = 'STOSD' Then Begin BcEmitB($AB); Exit; End;
  If Mnem = 'MOVSB' Then Begin BcEmitB($A4); Exit; End;
  If Mnem = 'MOVSD' Then Begin BcEmitB($A5); Exit; End;
  If Mnem = 'SCASB' Then Begin BcEmitB($AE); Exit; End;
  If Mnem = 'SCASD' Then Begin BcEmitB($AF); Exit; End;
  If Mnem = 'CMPSB' Then Begin BcEmitB($A6); Exit; End;
  If Mnem = 'CMPSD' Then Begin BcEmitB($A7); Exit; End;
  If Mnem = 'CLD' Then Begin BcEmitB($FC); Exit; End;
  If Mnem = 'STD' Then Begin BcEmitB($FD); Exit; End;
  If Mnem = 'REP' Then Begin BcEmitB($F3);
    { Le reste est l instruction suivante }
    If Op1 <> '' Then BcAssemble(Op1);
    Exit; End;
  If Mnem = 'REPE' Then Begin BcEmitB($F3);
    If Op1 <> '' Then BcAssemble(Op1);
    Exit; End;

  { ---- PUSH ---- }
  If Mnem = 'PUSH' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then { PUSH reg32 }
    Begin BcEmitB($50 + Reg1); Exit; End;
    If Pos('OFFSET ', StrUpperCase(Op1)) = 1 Then
    Begin { PUSH OFFSET label }
      Tmp := Copy(Op1, 8, 255);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      { Verifier si label+disp }
      DataAdd := 0;
      DataLbl := Tmp;
      P := 2;
      While P <= Length(Tmp) Do
      Begin
        If (Tmp[P] = '+') Or (Tmp[P] = '-') Then
        Begin
          DataLbl := Copy(Tmp, 1, P - 1);
          Rest := Copy(Tmp, P, Length(Tmp) - P + 1);
          If (Rest[1] = '+') Then Delete(Rest, 1, 1);
          While (Length(Rest) > 0) And (Rest[1] = ' ') Do Delete(Rest, 1, 1);
          Neg3 := False;
          If (Length(Rest) > 0) And (Rest[1] = '-') Then
          Begin Neg3 := True; Delete(Rest, 1, 1);
            While (Length(Rest) > 0) And (Rest[1] = ' ') Do Delete(Rest, 1, 1);
          End;
          BcParseImm(Rest, DataAdd);
          If Neg3 Then DataAdd := -DataAdd;
          Break;
        End;
        Inc(P);
      End;
      BcEmitB($68);
      BcAddFixup(BC_FIX_ABS32_DATA, DataLbl, DataAdd);
      BcEmitD(0);
      Exit;
    End;
    If HasDWordPrefix(Op1) Then
    Begin { PUSH DWORD PTR [mem] }
      Tmp := StripSizePrefix(Op1);
      BcEmitB($FF);
      BcEmitMemRM(Tmp, 6, DataLbl, DataAdd);
      Exit;
    End;
    If BcParseImm(Op1, ImmVal) Then
    Begin
      If (ImmVal >= -128) And (ImmVal <= 127) Then
      Begin BcEmitB($6A); BcEmitB(Byte(ImmVal)); End
      Else Begin BcEmitB($68); BcEmitD(ImmVal); End;
      Exit;
    End;
    Exit;
  End;

  { ---- POP ---- }
  If Mnem = 'POP' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then BcEmitB($58 + Reg1);
    Exit;
  End;

  { ---- CALL ---- }
  If Mnem = 'CALL' Then
  Begin
    If HasDWordPrefix(Op1) Then
    Begin { CALL DWORD PTR [mem] - indirect }
      Tmp := StripSizePrefix(Op1);
      BcEmitB($FF);
      BcEmitMemRM(Tmp, 2, DataLbl, DataAdd);
      Exit;
    End;
    { CALL label ou CALL api }
    Tmp := Op1;
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    If BcIsImport(Tmp) Then
    Begin
      { CALL [IAT+slot] : FF 15 abs32 }
      Slot := BcFindOrAddImport(Tmp);
      BcEmitB($FF); BcEmitB($15);
      BcAddFixup(BC_FIX_ABS32_IMP, BcImports[Slot].ApiName, Slot);
      BcEmitD(0);
    End
    Else
    Begin
      { CALL rel32 vers label interne }
      BcEmitB($E8);
      BcAddFixup(BC_FIX_REL32, Tmp, 0);
      BcEmitD(0);
    End;
    Exit;
  End;

  { ---- JMP / Jcc ---- }
  If (Mnem = 'JMP') Or (Mnem = 'JE') Or (Mnem = 'JNE') Or
     (Mnem = 'JZ') Or (Mnem = 'JNZ') Or (Mnem = 'JG') Or
     (Mnem = 'JGE') Or (Mnem = 'JL') Or (Mnem = 'JLE') Or
     (Mnem = 'JA') Or (Mnem = 'JB') Or (Mnem = 'JBE') Or
     (Mnem = 'JAE') Or (Mnem = 'JNC') Or
     (Mnem = 'JC') Or (Mnem = 'JS') Or (Mnem = 'JNS') Then
  Begin
    If Mnem = 'JMP' Then
    Begin BcEmitB($E9); End
    Else Begin
      BcEmitB($0F);
      If (Mnem = 'JE') Or (Mnem = 'JZ') Then BcEmitB($84)
      Else If (Mnem = 'JNE') Or (Mnem = 'JNZ') Then BcEmitB($85)
      Else If Mnem = 'JG' Then BcEmitB($8F)
      Else If Mnem = 'JGE' Then BcEmitB($8D)
      Else If Mnem = 'JL' Then BcEmitB($8C)
      Else If Mnem = 'JLE' Then BcEmitB($8E)
      Else If Mnem = 'JA' Then BcEmitB($87)
      Else If (Mnem = 'JB') Or (Mnem = 'JC') Then BcEmitB($82)
      Else If Mnem = 'JBE' Then BcEmitB($86)
      Else If (Mnem = 'JAE') Or (Mnem = 'JNC') Then BcEmitB($83)
      Else If Mnem = 'JS' Then BcEmitB($88)
      Else If Mnem = 'JNS' Then BcEmitB($89);
    End;
    BcAddFixup(BC_FIX_REL32, Op1, 0);
    BcEmitD(0);
    Exit;
  End;

  { ---- MOV ---- }
  If Mnem = 'MOV' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then
    Begin
      Reg2 := BcParseReg32(Op2);
      If Reg2 >= 0 Then
      Begin { MOV reg32,reg32 }
        BcEmitB($89); BcEmitB($C0 + Reg2 * 8 + Reg1); Exit;
      End;
      If BcParseImm(Op2, ImmVal) Then
      Begin { MOV reg32,imm32 }
        BcEmitB($B8 + Reg1); BcEmitD(ImmVal); Exit;
      End;
      If HasDWordPrefix(Op2) Or StartsWithBracket(Op2) Then
      Begin { MOV reg32,[mem] }
        Tmp := StripSizePrefix(Op2);
        If Not StartsWithBracket(Tmp) Then Tmp := Op2;
        If StartsWithBracket(Tmp) Then
        Begin
          BcEmitB($8B);
          BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
          Exit;
        End;
      End;
      Exit;
    End;
    { MOV reg8, ... }
    Reg1 := BcParseReg8(Op1);
    If Reg1 >= 0 Then
    Begin
      If HasBytePrefix(Op2) Or StartsWithBracket(Op2) Then
      Begin { MOV reg8,[mem] }
        Tmp := StripSizePrefix(Op2);
        If Not StartsWithBracket(Tmp) Then Tmp := Op2;
        If StartsWithBracket(Tmp) Then
        Begin
          BcEmitB($8A);
          BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
          Exit;
        End;
      End;
      Reg2 := BcParseReg8(Op2);
      If Reg2 >= 0 Then
      Begin BcEmitB($88); BcEmitB($C0 + Reg2 * 8 + Reg1); Exit; End;
      Exit;
    End;
    { MOV [mem], ... }
    If HasBytePrefix(Op1) Or HasDWordPrefix(Op1) Or HasWordPrefix(Op1) Or
       StartsWithBracket(Op1) Then
    Begin
      IsByte := HasBytePrefix(Op1);
      IsWord := HasWordPrefix(Op1);
      Tmp := StripSizePrefix(Op1);
      If Not StartsWithBracket(Tmp) Then Tmp := Op1;

      If IsByte Then
      Begin
        Reg2 := BcParseReg8(Op2);
        If Reg2 >= 0 Then
        Begin { MOV BYTE PTR [mem], reg8 }
          BcEmitB($88);
          BcEmitMemRM(Tmp, Reg2, DataLbl, DataAdd);
          Exit;
        End;
        { MOV BYTE PTR [mem], imm8 }
        If BcParseImm(Op2, ImmVal) Then
        Begin
          BcEmitB($C6);
          BcEmitMemRM(Tmp, 0, DataLbl, DataAdd);
          BcEmitB(Byte(ImmVal));
          Exit;
        End;
        { MOV BYTE PTR [mem], 'c' }
        If (Length(Op2) = 3) And (Op2[1] = '''') And (Op2[3] = '''') Then
        Begin
          BcEmitB($C6);
          BcEmitMemRM(Tmp, 0, DataLbl, DataAdd);
          BcEmitB(Byte(Op2[2]));
          Exit;
        End;
        Exit;
      End;
      If IsWord Then
      Begin
        Reg2 := BcParseReg16(Op2);
        If Reg2 >= 0 Then
        Begin { MOV WORD PTR [mem], reg16 }
          BcEmitB($66); BcEmitB($89);
          BcEmitMemRM(Tmp, Reg2, DataLbl, DataAdd);
          Exit;
        End;
        Exit;
      End;
      { Check plain [mem],reg8 (e.g. MOV [EDI],AL without BYTE PTR) }
      Reg2 := BcParseReg8(Op2);
      If Reg2 >= 0 Then
      Begin { MOV [mem], reg8 }
        BcEmitB($88);
        BcEmitMemRM(Tmp, Reg2, DataLbl, DataAdd);
        Exit;
      End;
      { DWORD or plain [mem] }
      Reg2 := BcParseReg32(Op2);
      If Reg2 >= 0 Then
      Begin { MOV [mem], reg32 }
        BcEmitB($89);
        BcEmitMemRM(Tmp, Reg2, DataLbl, DataAdd);
        Exit;
      End;
      If BcParseImm(Op2, ImmVal) Then
      Begin { MOV DWORD PTR [mem], imm32 }
        BcEmitB($C7);
        BcEmitMemRM(Tmp, 0, DataLbl, DataAdd);
        BcEmitD(ImmVal);
        Exit;
      End;
      Exit;
    End;
    { MOV ESP,EBP special non attrape }
    Exit;
  End;

  { ---- LEA ---- }
  If Mnem = 'LEA' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then
    Begin
      Tmp := StripSizePrefix(Op2);
      If Not StartsWithBracket(Tmp) Then Tmp := Op2;
      If StartsWithBracket(Tmp) Then
      Begin
        BcEmitB($8D);
        BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
      End
      Else
      Begin { LEA reg,[label] sans crochets }
        BcEmitB($8D);
        BcEmitB($05 Or (Reg1 Shl 3));
        DataAdd := 0;
        P := 2;
        DataLbl := Tmp;
        While P <= Length(Tmp) Do
        Begin
          If (Tmp[P] = '+') Or (Tmp[P] = '-') Then
          Begin
            DataLbl := Copy(Tmp, 1, P - 1);
            R2 := Copy(Tmp, P, Length(Tmp) - P + 1);
            If R2[1] = '+' Then Delete(R2, 1, 1);
            BcParseImm(R2, DataAdd);
            Break;
          End;
          Inc(P);
        End;
        BcAddFixup(BC_FIX_ABS32_DATA, DataLbl, DataAdd);
        BcEmitD(0);
      End;
    End;
    Exit;
  End;

  { ---- MOVZX ---- }
  If Mnem = 'MOVZX' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then
    Begin
      BcEmitB($0F); BcEmitB($B6);
      Tmp := StripSizePrefix(Op2);
      If Not StartsWithBracket(Tmp) Then
      Begin
        Reg2 := BcParseReg8(Tmp);
        If Reg2 >= 0 Then
        Begin BcEmitB($C0 + Reg1 * 8 + Reg2); Exit; End;
        Tmp := Op2;
      End;
      If StartsWithBracket(Tmp) Then
        BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
    End;
    Exit;
  End;

  { ---- ADD/SUB/CMP/AND/OR/XOR/TEST ---- }
  If (Mnem = 'ADD') Or (Mnem = 'SUB') Or (Mnem = 'CMP') Or
     (Mnem = 'AND') Or (Mnem = 'OR') Or (Mnem = 'XOR') Or
     (Mnem = 'TEST') Then
  Begin
    If Mnem = 'ADD' Then AluOp := 0
    Else If Mnem = 'OR' Then AluOp := 1
    Else If Mnem = 'AND' Then AluOp := 4
    Else If Mnem = 'SUB' Then AluOp := 5
    Else If Mnem = 'XOR' Then AluOp := 6
    Else If Mnem = 'CMP' Then AluOp := 7
    Else AluOp := -1; { TEST }

    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then
    Begin
      Reg2 := BcParseReg32(Op2);
      If Reg2 >= 0 Then
      Begin { op reg,reg }
        If AluOp >= 0 Then
        Begin BcEmitB(AluOp * 8 + 1); BcEmitB($C0 + Reg2 * 8 + Reg1); End
        Else { TEST }
        Begin BcEmitB($85); BcEmitB($C0 + Reg1 * 8 + Reg2); End;
        Exit;
      End;
      If BcParseImm(Op2, ImmVal) Then
      Begin { op reg,imm }
        If AluOp >= 0 Then
        Begin
          If (ImmVal >= -128) And (ImmVal <= 127) Then
          Begin BcEmitB($83); BcEmitB($C0 + AluOp * 8 + Reg1);
            BcEmitB(Byte(ImmVal)); End
          Else
          Begin
            If Reg1 = R_EAX Then
            Begin BcEmitB(AluOp * 8 + 5); BcEmitD(ImmVal); End
            Else Begin BcEmitB($81); BcEmitB($C0 + AluOp * 8 + Reg1);
              BcEmitD(ImmVal); End;
          End;
        End Else Begin { TEST reg,imm }
          If Reg1 = R_EAX Then Begin BcEmitB($A9); BcEmitD(ImmVal); End
          Else Begin BcEmitB($F7); BcEmitB($C0 + Reg1); BcEmitD(ImmVal); End;
        End;
        Exit;
      End;
      { op reg32,[mem] : e.g. CMP EAX,DWORD PTR [label] }
      If HasDWordPrefix(Op2) Or StartsWithBracket(Op2) Then
      Begin
        Tmp := StripSizePrefix(Op2);
        If Not StartsWithBracket(Tmp) Then Tmp := Op2;
        If StartsWithBracket(Tmp) Then
        Begin
          If AluOp >= 0 Then
            BcEmitB(AluOp * 8 + 3)       { ADD=03 OR=0B AND=23 SUB=2B XOR=33 CMP=3B }
          Else
            BcEmitB($85);                 { TEST reg,[mem] }
          BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
          Exit;
        End;
      End;
      Exit;
    End;
    { op reg8,... }
    Reg1 := BcParseReg8(Op1);
    If Reg1 >= 0 Then
    Begin
      If BcParseImm(Op2, ImmVal) Then
      Begin
        If AluOp >= 0 Then
        Begin
          If Reg1 = 0 Then { AL }
          Begin BcEmitB(AluOp * 8 + 4); BcEmitB(Byte(ImmVal)); End
          Else Begin BcEmitB($80); BcEmitB($C0 + AluOp * 8 + Reg1);
            BcEmitB(Byte(ImmVal)); End;
        End Else Begin { TEST reg8,imm8 }
          If Reg1 = 0 Then Begin BcEmitB($A8); BcEmitB(Byte(ImmVal)); End
          Else Begin BcEmitB($F6); BcEmitB($C0 + Reg1); BcEmitB(Byte(ImmVal)); End;
        End;
        Exit;
      End;
      Reg2 := BcParseReg8(Op2);
      If Reg2 >= 0 Then
      Begin
        If AluOp >= 0 Then
        Begin BcEmitB(AluOp * 8); BcEmitB($C0 + Reg2 * 8 + Reg1); End
        Else Begin BcEmitB($84); BcEmitB($C0 + Reg1 * 8 + Reg2); End;
        Exit;
      End;
      Exit;
    End;
    { CMP BYTE PTR [mem],imm }
    If HasBytePrefix(Op1) Then
    Begin
      Tmp := StripSizePrefix(Op1);
      If StartsWithBracket(Tmp) Then
      Begin
        If AluOp >= 0 Then BcEmitB($80)
        Else BcEmitB($F6);
        BcEmitMemRM(Tmp, AluOp And 7, DataLbl, DataAdd);
        If BcParseImm(Op2, ImmVal) Then BcEmitB(Byte(ImmVal));
      End;
      Exit;
    End;
    If HasDWordPrefix(Op1) Then
    Begin
      Tmp := StripSizePrefix(Op1);
      If StartsWithBracket(Tmp) Then
      Begin
        If BcParseImm(Op2, ImmVal) Then
        Begin
          If (ImmVal >= -128) And (ImmVal <= 127) And (AluOp >= 0) Then
          Begin
            BcEmitB($83);
            BcEmitMemRM(Tmp, AluOp And 7, DataLbl, DataAdd);
            BcEmitB(Byte(ImmVal));
          End
          Else
          Begin
            If AluOp >= 0 Then BcEmitB($81) Else BcEmitB($F7);
            BcEmitMemRM(Tmp, AluOp And 7, DataLbl, DataAdd);
            BcEmitD(ImmVal);
          End;
        End;
      End;
      Exit;
    End;
    Exit;
  End;

  { ---- INC / DEC ---- }
  If Mnem = 'INC' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then BcEmitB($40 + Reg1)
    Else If HasDWordPrefix(Op1) Then
    Begin Tmp := StripSizePrefix(Op1);
      BcEmitB($FF); BcEmitMemRM(Tmp, 0, DataLbl, DataAdd); End
    Else If HasBytePrefix(Op1) Or StartsWithBracket(Op1) Then
    Begin Tmp := StripSizePrefix(Op1);
      BcEmitB($FE); BcEmitMemRM(Tmp, 0, DataLbl, DataAdd); End;
    Exit;
  End;
  If Mnem = 'DEC' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then BcEmitB($48 + Reg1)
    Else If HasDWordPrefix(Op1) Then
    Begin Tmp := StripSizePrefix(Op1);
      BcEmitB($FF); BcEmitMemRM(Tmp, 1, DataLbl, DataAdd); End
    Else If HasBytePrefix(Op1) Or StartsWithBracket(Op1) Then
    Begin Tmp := StripSizePrefix(Op1);
      BcEmitB($FE); BcEmitMemRM(Tmp, 1, DataLbl, DataAdd); End;
    Exit;
  End;

  { ---- NEG / NOT / DIV / IMUL ---- }
  If Mnem = 'NEG' Then
  Begin Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($F7); BcEmitB($D8 + Reg1); End;
    Exit; End;
  If Mnem = 'NOT' Then
  Begin Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($F7); BcEmitB($D0 + Reg1); End;
    Exit; End;
  If Mnem = 'DIV' Then
  Begin Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($F7); BcEmitB($F0 + Reg1); End;
    Exit; End;
  If Mnem = 'IDIV' Then
  Begin Reg1 := BcParseReg32(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($F7); BcEmitB($F8 + Reg1); End;
    Exit; End;
  If Mnem = 'IMUL' Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If (Op2 <> '') Then
    Begin
      { IMUL reg1,op2,imm  ou  IMUL reg1,reg2 }
      ImOp2 := Op2; ImOp3 := '';
      Cp := Pos(',', ImOp2);
      If Cp > 0 Then
      Begin ImOp3 := Copy(ImOp2, Cp + 1, 255); ImOp2 := Copy(ImOp2, 1, Cp - 1);
        While (Length(ImOp3) > 0) And (ImOp3[1] = ' ') Do Delete(ImOp3, 1, 1);
        While (Length(ImOp2) > 0) And (ImOp2[Length(ImOp2)] = ' ') Do
          Delete(ImOp2, Length(ImOp2), 1);
      End;
      If ImOp3 <> '' Then
      Begin
        Reg2 := BcParseReg32(ImOp2);
        If (Reg2 >= 0) And BcParseImm(ImOp3, ImmVal) Then
        Begin
          If (ImmVal >= -128) And (ImmVal <= 127) Then
          Begin BcEmitB($6B); BcEmitB($C0 + Reg1 * 8 + Reg2);
            BcEmitB(Byte(ImmVal)); End
          Else Begin BcEmitB($69); BcEmitB($C0 + Reg1 * 8 + Reg2);
            BcEmitD(ImmVal); End;
        End;
      End
      Else
      Begin
        Reg2 := BcParseReg32(ImOp2);
        If Reg2 >= 0 Then
        Begin BcEmitB($0F); BcEmitB($AF);
          BcEmitB($C0 + Reg1 * 8 + Reg2); End
        Else If BcParseImm(ImOp2, ImmVal) Then
        Begin
          { IMUL reg,imm -> encode as IMUL reg,reg,imm }
          If (ImmVal >= -128) And (ImmVal <= 127) Then
          Begin BcEmitB($6B); BcEmitB($C0 + Reg1 * 8 + Reg1);
            BcEmitB(Byte(ImmVal)); End
          Else Begin BcEmitB($69); BcEmitB($C0 + Reg1 * 8 + Reg1);
            BcEmitD(ImmVal); End;
        End
        Else If HasDWordPrefix(ImOp2) Or StartsWithBracket(ImOp2) Then
        Begin
          { IMUL reg,DWORD PTR [mem] }
          Tmp := ImOp2;
          If HasDWordPrefix(Tmp) Then Tmp := StripSizePrefix(Tmp);
          BcEmitB($0F); BcEmitB($AF);
          BcEmitMemRM(Tmp, Reg1, DataLbl, DataAdd);
        End;
      End;
    End
    Else If Reg1 >= 0 Then
    Begin BcEmitB($F7); BcEmitB($E8 + Reg1); End;
    Exit;
  End;

  { ---- SHL / SHR ---- }
  If (Mnem = 'SHL') Or (Mnem = 'SHR') Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If (Reg1 >= 0) And BcParseImm(Op2, ImmVal) Then
    Begin
      If ImmVal = 1 Then
      Begin BcEmitB($D1);
        If Mnem = 'SHL' Then BcEmitB($E0 + Reg1)
        Else BcEmitB($E8 + Reg1); End
      Else Begin BcEmitB($C1);
        If Mnem = 'SHL' Then BcEmitB($E0 + Reg1)
        Else BcEmitB($E8 + Reg1);
        BcEmitB(Byte(ImmVal)); End;
    End;
    Exit;
  End;

  { ---- BT / BTS / BTR / BTC ---- }
  If (Mnem = 'BT') Or (Mnem = 'BTS') Or (Mnem = 'BTR') Or (Mnem = 'BTC') Then
  Begin
    Reg1 := BcParseReg32(Op1);
    If (Reg1 >= 0) And BcParseImm(Op2, ImmVal) Then
    Begin
      { reg, imm8 form: 0F BA /4|/5|/6|/7 ib }
      BcEmitB($0F); BcEmitB($BA);
      If Mnem = 'BT'  Then BcEmitB($E0 + Reg1)
      Else If Mnem = 'BTS' Then BcEmitB($E8 + Reg1)
      Else If Mnem = 'BTR' Then BcEmitB($F0 + Reg1)
      Else BcEmitB($F8 + Reg1);  { BTC }
      BcEmitB(Byte(ImmVal));
    End
    Else
    Begin
      { [reg1], reg2 form }
      Reg2 := BcParseReg32(Op2);
      If (Reg2 >= 0) Then
      Begin
        Tmp := Op1;
        If (Length(Tmp) > 2) And (Tmp[1] = '[') And (Tmp[Length(Tmp)] = ']') Then
        Begin
          Tmp := Copy(Tmp, 2, Length(Tmp) - 2);
          Reg1 := BcParseReg32(Tmp);
          If Reg1 >= 0 Then
          Begin
            BcEmitB($0F);
            If Mnem = 'BT'  Then BcEmitB($A3)
            Else If Mnem = 'BTS' Then BcEmitB($AB)
            Else If Mnem = 'BTR' Then BcEmitB($B3)
            Else BcEmitB($BB);  { BTC }
            BcEmitB((Reg2 Shl 3) Or Reg1);  { ModR/M [reg1], reg2 }
          End;
        End;
      End;
    End;
    Exit;
  End;

  { ---- INT ---- }
  If Mnem = 'INT' Then
  Begin
    If BcParseImm(Op1, ImmVal) Then
    Begin BcEmitB($CD); BcEmitB(Byte(ImmVal)); End;
    Exit;
  End;

  { ---- DD (data dans le code) ---- }
  If Mnem = 'DD' Then
  Begin
    If BcParseImm(Op1, ImmVal) Then BcEmitD(ImmVal)
    Else BcEmitD(0);
    Exit;
  End;

  { Instruction non reconnue : emettre NOP comme placeholder }
  { WriteLn('BcAssemble: non reconnu: [', S, ']'); }
End;

{ ============================================================ }
{ BcAssemble8086 - Mini-assembleur Intel 8086 (mode reel/prot) }
{ Traduit automatiquement les noms de registres 32 bits en 16  }
{ bits (EAX->AX, ESI->SI, etc.) pour supporter le code emis   }
{ par le compilateur en mode -CD (DOS 16 bits).                }
{ ============================================================ }

Procedure BcAssemble8086(Const S: TString);
Var
  Line, Mnem, Tmp, Op1, Op2: TString;
  P: Integer;
  Reg1, Reg2, ImmVal: LongInt;
  DataLbl: TString;
  DataAdd: LongInt;
  UOp1, UOp2: TString;

  Procedure SplitOps8086(Const Rest: TString);
  Var J: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1;
    While J <= Length(Rest) Do
    Begin
      If (Rest[J] = ',') Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

  Function Reg16(Const S: TString): Integer;
  { Retourne 0-7 pour registre 16 bits (traduit E?? en ??) }
  Var U: TString;
  Begin
    U := StrUpperCase(S);
    If (U = 'AX') Or (U = 'EAX') Then Reg16 := 0
    Else If (U = 'CX') Or (U = 'ECX') Then Reg16 := 1
    Else If (U = 'DX') Or (U = 'EDX') Then Reg16 := 2
    Else If (U = 'BX') Or (U = 'EBX') Then Reg16 := 3
    Else If (U = 'SP') Or (U = 'ESP') Then Reg16 := 4
    Else If (U = 'BP') Or (U = 'EBP') Then Reg16 := 5
    Else If (U = 'SI') Or (U = 'ESI') Then Reg16 := 6
    Else If (U = 'DI') Or (U = 'EDI') Then Reg16 := 7
    Else Reg16 := -1;
  End;

  Function Reg8(Const S: TString): Integer;
  Var U: TString;
  Begin
    U := StrUpperCase(S);
    If U = 'AL' Then Reg8 := 0
    Else If U = 'CL' Then Reg8 := 1
    Else If U = 'DL' Then Reg8 := 2
    Else If U = 'BL' Then Reg8 := 3
    Else If U = 'AH' Then Reg8 := 4
    Else If U = 'CH' Then Reg8 := 5
    Else If U = 'DH' Then Reg8 := 6
    Else If U = 'BH' Then Reg8 := 7
    Else Reg8 := -1;
  End;

  Function ParseImm16(Const S: TString; Var V: LongInt): Boolean;
  Var U: TString; Code: Integer; W: LongInt;
  Begin
    ParseImm16 := False;
    U := StrUpperCase(S);
    While (Length(U) > 0) And (U[1] = ' ') Do Delete(U, 1, 1);
    If U = '' Then Exit;
    If U[Length(U)] = 'H' Then
    Begin
      Delete(U, Length(U), 1);
      System.Val('$' + U, W, Code);
      If Code = 0 Then Begin V := W; ParseImm16 := True; End;
    End
    Else
    Begin
      System.Val(U, W, Code);
      If Code = 0 Then Begin V := W; ParseImm16 := True; End;
    End;
  End;

  Function StartsWithBracket16(Const S: TString): Boolean;
  Var U: TString;
  Begin
    U := S;
    While (Length(U) > 0) And (U[1] = ' ') Do Delete(U, 1, 1);
    StartsWithBracket16 := (Length(U) > 0) And (U[1] = '[');
  End;

  Procedure ParseMemLabel(Const S: TString; Var Lbl: TString; Var Disp: LongInt);
  { Parse [LABEL] or [LABEL+disp] or [LABEL-disp] }
  Var U, R2: TString; J: Integer;
  Begin
    Lbl := ''; Disp := 0;
    U := S;
    While (Length(U) > 0) And (U[1] = ' ') Do Delete(U, 1, 1);
    If (Length(U) > 0) And (U[1] = '[') Then Delete(U, 1, 1);
    If (Length(U) > 0) And (U[Length(U)] = ']') Then Delete(U, Length(U), 1);
    { Chercher + ou - pour extraire le deplacement }
    J := 2;
    While J <= Length(U) Do
    Begin
      If (U[J] = '+') Or (U[J] = '-') Then
      Begin
        Lbl := Copy(U, 1, J - 1);
        R2 := Copy(U, J, Length(U) - J + 1);
        If R2[1] = '+' Then Delete(R2, 1, 1);
        ParseImm16(R2, Disp);
        Exit;
      End;
      Inc(J);
    End;
    Lbl := U;
  End;

  Function IsDOS: Boolean;
  Begin
    IsDOS := (Opts.DestTarget = DEST_DOSR) Or (Opts.DestTarget = DEST_DOSP);
  End;

Begin { BcAssemble8086 }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;

  SplitOps8086(Tmp);
  UOp1 := StrUpperCase(Op1);
  UOp2 := StrUpperCase(Op2);

  { ---- NOP ---- }
  If Mnem = 'NOP' Then Begin BcEmitB($90); Exit; End;

  { ---- RET / RETF ---- }
  If Mnem = 'RET' Then Begin BcEmitB($C3); Exit; End;
  If Mnem = 'RETF' Then Begin BcEmitB($CB); Exit; End;

  { ---- INT ---- }
  If Mnem = 'INT' Then
  Begin
    BcEmitB($CD);
    If ParseImm16(Op1, ImmVal) Then BcEmitB(Byte(ImmVal))
    Else If UOp1 = '21H' Then BcEmitB($21)
    Else If UOp1 = '20H' Then BcEmitB($20)
    Else If UOp1 = '10H' Then BcEmitB($10)
    Else BcEmitB($03);
    Exit;
  End;

  { ---- HLT ---- }
  If Mnem = 'HLT' Then Begin BcEmitB($F4); Exit; End;

  { ---- CLC / STC / CLI / STI / CLD / STD ---- }
  If Mnem = 'CLC' Then Begin BcEmitB($F8); Exit; End;
  If Mnem = 'STC' Then Begin BcEmitB($F9); Exit; End;
  If Mnem = 'CLI' Then Begin BcEmitB($FA); Exit; End;
  If Mnem = 'STI' Then Begin BcEmitB($FB); Exit; End;
  If Mnem = 'CLD' Then Begin BcEmitB($FC); Exit; End;
  If Mnem = 'STD' Then Begin BcEmitB($FD); Exit; End;

  { ---- PUSHAD -> PUSH AX/CX/DX/BX/SP/BP/SI/DI ---- }
  If Mnem = 'PUSHAD' Then
  Begin
    BcEmitB($50);BcEmitB($51);BcEmitB($52);BcEmitB($53);
    BcEmitB($54);BcEmitB($55);BcEmitB($56);BcEmitB($57);
    Exit;
  End;
  { ---- POPAD -> POP DI/SI/BP/xx/BX/DX/CX/AX ---- }
  If Mnem = 'POPAD' Then
  Begin
    BcEmitB($5F);BcEmitB($5E);BcEmitB($5D);BcEmitB($5C);
    BcEmitB($5B);BcEmitB($5A);BcEmitB($59);BcEmitB($58);
    Exit;
  End;

  { ---- PUSH reg16 (accepte aussi 32-bit names) ---- }
  If Mnem = 'PUSH' Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($50 + Reg1); Exit; End;
    { PUSH imm (80186+) }
    If ParseImm16(Op1, ImmVal) Then
    Begin
      If (ImmVal >= -128) And (ImmVal <= 127) Then
      Begin BcEmitB($6A); BcEmitB(Byte(ImmVal)); End
      Else
      Begin BcEmitB($68); BcEmitW(Word(ImmVal)); End;
      Exit;
    End;
    { PUSH OFFSET label -> push data offset }
    If Copy(UOp1, 1, 7) = 'OFFSET ' Then
    Begin
      Tmp := Copy(Op1, 8, Length(Op1) - 7);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      BcEmitB($68); { PUSH imm16 }
      BcAddFixup(BC_FIX_ABS16_DATA, Tmp, 0);
      BcEmitW(0);
      Exit;
    End;
    { PUSH DWORD PTR [...] / PUSH WORD PTR [...] -> skip pour Win32 }
    If (Pos('DWORD PTR', UOp1) > 0) Or (Pos('WORD PTR', UOp1) > 0) Then
      Exit;
    Exit;
  End;

  { ---- POP reg16 ---- }
  If Mnem = 'POP' Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($58 + Reg1); Exit; End;
    Exit;
  End;

  { ---- MOV ---- }
  If Mnem = 'MOV' Then
  Begin
    { MOV DS,AX  (8E D8+src) }
    If UOp1 = 'DS' Then
    Begin
      Reg2 := Reg16(Op2);
      If Reg2 >= 0 Then Begin BcEmitB($8E); BcEmitB($D8 + Reg2); End;
      Exit;
    End;
    If UOp1 = 'ES' Then
    Begin
      Reg2 := Reg16(Op2);
      If Reg2 >= 0 Then Begin BcEmitB($8E); BcEmitB($C0 + Reg2); End;
      Exit;
    End;
    { MOV reg16, reg16 : 8B C0+dst*8+src }
    Reg1 := Reg16(Op1); Reg2 := Reg16(Op2);
    If (Reg1 >= 0) And (Reg2 >= 0) Then
    Begin BcEmitB($8B); BcEmitB($C0 + Reg1 * 8 + Reg2); Exit; End;
    { MOV reg16, imm16 : B8+reg imm16 }
    If Reg1 >= 0 Then
    Begin
      If ParseImm16(Op2, ImmVal) Then
      Begin BcEmitB($B8 + Reg1); BcEmitW(Word(ImmVal)); Exit; End;
    End;
    { MOV reg8, imm8 : B0+reg imm8 }
    Reg1 := Reg8(Op1);
    If Reg1 >= 0 Then
    Begin
      Reg2 := Reg8(Op2);
      If Reg2 >= 0 Then
      Begin BcEmitB($8A); BcEmitB($C0 + Reg1 * 8 + Reg2); Exit; End;
      If ParseImm16(Op2, ImmVal) Then
      Begin BcEmitB($B0 + Reg1); BcEmitB(Byte(ImmVal)); Exit; End;
    End;
    { MOV BYTE PTR [label],imm8 / MOV BYTE PTR [label+d],imm8 }
    If (Pos('BYTE PTR', UOp1) > 0) Then
    Begin
      Tmp := Op1;
      P := Pos('[', Tmp);
      If P > 0 Then
      Begin
        Tmp := Copy(Tmp, P, Length(Tmp) - P + 1);
        ParseMemLabel(Tmp, DataLbl, DataAdd);
        { MOV [label], reg8 }
        Reg2 := Reg8(Op2);
        If Reg2 >= 0 Then
        Begin
          BcEmitB($88); BcEmitB($06 + Reg2 * 8); { ModRM: mod=00,rm=110 (disp16) }
          BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
          BcEmitW(0);
          Exit;
        End;
        { MOV BYTE PTR [label],imm8 }
        If ParseImm16(Op2, ImmVal) Then
        Begin
          BcEmitB($C6); BcEmitB($06); { ModRM: mod=00,reg=0,rm=110 }
          BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
          BcEmitW(0);
          BcEmitB(Byte(ImmVal));
          Exit;
        End;
      End;
    End;
    { MOV WORD PTR [label],imm16 / MOV [label],reg16 }
    If (Pos('WORD PTR', UOp1) > 0) Or (Pos('DWORD PTR', UOp1) > 0)
       Or StartsWithBracket16(Op1) Then
    Begin
      Tmp := Op1;
      P := Pos('[', Tmp);
      If P > 0 Then
      Begin
        Tmp := Copy(Tmp, P, Length(Tmp) - P + 1);
        ParseMemLabel(Tmp, DataLbl, DataAdd);
        Reg2 := Reg16(Op2);
        If Reg2 >= 0 Then
        Begin
          BcEmitB($89); BcEmitB($06 + Reg2 * 8); { MOV [disp16],reg16 }
          BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
          BcEmitW(0);
          Exit;
        End;
        If ParseImm16(Op2, ImmVal) Then
        Begin
          BcEmitB($C7); BcEmitB($06); { MOV WORD PTR [disp16],imm16 }
          BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
          BcEmitW(0);
          BcEmitW(Word(ImmVal));
          Exit;
        End;
      End;
    End;
    { MOV reg16,[label] - load from memory }
    Reg1 := Reg16(Op1);
    If (Reg1 >= 0) And StartsWithBracket16(Op2) Then
    Begin
      ParseMemLabel(Op2, DataLbl, DataAdd);
      BcEmitB($8B); BcEmitB($06 + Reg1 * 8); { MOV reg16,[disp16] }
      BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
      BcEmitW(0);
      Exit;
    End;
    Exit;
  End;

  { ---- LEA reg,[label] -> MOV reg, OFFSET label (en 16 bits) ---- }
  If Mnem = 'LEA' Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then
    Begin
      Tmp := Op2;
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      If StartsWithBracket16(Tmp) Then
        ParseMemLabel(Tmp, DataLbl, DataAdd)
      Else
      Begin
        DataLbl := Tmp; DataAdd := 0;
        P := 2;
        While P <= Length(DataLbl) Do
        Begin
          If (DataLbl[P] = '+') Or (DataLbl[P] = '-') Then
          Begin
            Tmp := Copy(DataLbl, P, Length(DataLbl) - P + 1);
            DataLbl := Copy(DataLbl, 1, P - 1);
            If Tmp[1] = '+' Then Delete(Tmp, 1, 1);
            ParseImm16(Tmp, DataAdd);
            Break;
          End;
          Inc(P);
        End;
      End;
      { Emettre MOV reg16, imm16 avec fixup data }
      BcEmitB($B8 + Reg1); { MOV reg16, imm16 }
      BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
      BcEmitW(0);
    End;
    Exit;
  End;

  { ---- CALL label ---- }
  If Mnem = 'CALL' Then
  Begin
    Tmp := Op1;
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    { Intercepter les API Win32 en mode DOS }
    If StrUpperCase(Tmp) = 'EXITPROCESS' Then
    Begin
      { MOV AX,4C00h / INT 21h }
      BcEmitB($B8); BcEmitW($4C00);  { MOV AX, 4C00h }
      BcEmitB($CD); BcEmitB($21);    { INT 21h }
      Exit;
    End;
    If (StrUpperCase(Tmp) = 'GETSTDHANDLE') Or
       (StrUpperCase(Tmp) = 'GETPROCESSHEAP') Or
       (StrUpperCase(Tmp) = 'WRITEFILE') Or
       (StrUpperCase(Tmp) = 'READFILE') Or
       (StrUpperCase(Tmp) = 'HEAPALLOC') Or
       (StrUpperCase(Tmp) = 'HEAPFREE') Then
      Exit; { Ignorer les API Win32 en mode DOS }
    { CALL DWORD PTR [...] -> ignorer en mode DOS }
    If Pos('DWORD PTR', StrUpperCase(Tmp)) > 0 Then Exit;
    { CALL near relative (E8 rel16) }
    BcEmitB($E8);
    BcAddFixup(BC_FIX_REL16, Tmp, 0);
    BcEmitW(0);
    Exit;
  End;

  { ---- JMP / Jcc labels ---- }
  If (Mnem = 'JMP') Or (Mnem = 'JE') Or (Mnem = 'JNE') Or
     (Mnem = 'JZ') Or (Mnem = 'JNZ') Or (Mnem = 'JG') Or
     (Mnem = 'JGE') Or (Mnem = 'JL') Or (Mnem = 'JLE') Or
     (Mnem = 'JA') Or (Mnem = 'JB') Or (Mnem = 'JBE') Or
     (Mnem = 'JAE') Or (Mnem = 'JNC') Or
     (Mnem = 'JC') Or (Mnem = 'JS') Or (Mnem = 'JNS') Then
  Begin
    If Mnem = 'JMP' Then
    Begin
      BcEmitB($E9); { JMP rel16 }
      BcAddFixup(BC_FIX_REL16, Op1, 0);
      BcEmitW(0);
    End
    Else
    Begin
      { Jcc : utiliser JNcc $+5 / JMP rel16 (compatible 8086) }
      { D abord l octet Jcc inverse qui saute par-dessus le JMP }
      If (Mnem = 'JE') Or (Mnem = 'JZ') Then BcEmitB($75)   { JNE }
      Else If (Mnem = 'JNE') Or (Mnem = 'JNZ') Then BcEmitB($74) { JE }
      Else If Mnem = 'JG'  Then BcEmitB($7E) { JLE }
      Else If Mnem = 'JGE' Then BcEmitB($7C) { JL }
      Else If Mnem = 'JL'  Then BcEmitB($7D) { JGE }
      Else If Mnem = 'JLE' Then BcEmitB($7F) { JG }
      Else If Mnem = 'JA'  Then BcEmitB($76) { JBE }
      Else If (Mnem = 'JB') Or (Mnem = 'JC') Then BcEmitB($73) { JNC }
      Else If Mnem = 'JBE' Then BcEmitB($77) { JA }
      Else If (Mnem = 'JAE') Or (Mnem = 'JNC') Then BcEmitB($72) { JB }
      Else If Mnem = 'JS'  Then BcEmitB($79) { JNS }
      Else If Mnem = 'JNS' Then BcEmitB($78); { JS }
      BcEmitB($03); { deplacement: sauter 3 octets (le JMP E9 XX XX) }
      { Puis le JMP inconditionnel }
      BcEmitB($E9); { JMP rel16 }
      BcAddFixup(BC_FIX_REL16, Op1, 0);
      BcEmitW(0);
    End;
    Exit;
  End;

  { ---- ADD / SUB / CMP / XOR / AND / OR / TEST ---- }
  If (Mnem = 'ADD') Or (Mnem = 'SUB') Or (Mnem = 'CMP') Or
     (Mnem = 'XOR') Or (Mnem = 'AND') Or (Mnem = 'OR') Or
     (Mnem = 'TEST') Then
  Begin
    Reg1 := Reg16(Op1); Reg2 := Reg16(Op2);
    { reg16, reg16 }
    If (Reg1 >= 0) And (Reg2 >= 0) Then
    Begin
      If Mnem = 'ADD'  Then Begin BcEmitB($01); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'SUB'  Then Begin BcEmitB($29); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'CMP'  Then Begin BcEmitB($39); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'XOR'  Then Begin BcEmitB($31); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'AND'  Then Begin BcEmitB($21); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'OR'   Then Begin BcEmitB($09); BcEmitB($C0 + Reg2*8 + Reg1); End
      Else If Mnem = 'TEST' Then Begin BcEmitB($85); BcEmitB($C0 + Reg2*8 + Reg1); End;
      Exit;
    End;
    { reg16, imm16 }
    If (Reg1 >= 0) And ParseImm16(Op2, ImmVal) Then
    Begin
      If Mnem = 'TEST' Then
      Begin
        If Reg1 = 0 Then Begin BcEmitB($A9); BcEmitW(Word(ImmVal)); End
        Else Begin BcEmitB($F7); BcEmitB($C0 + Reg1); BcEmitW(Word(ImmVal)); End;
      End
      Else
      Begin
        If (ImmVal >= -128) And (ImmVal <= 127) And (Mnem <> 'TEST') Then
        Begin
          { forme courte : 83 /r ib (sign-extended) }
          BcEmitB($83);
          If Mnem = 'ADD' Then BcEmitB($C0 + Reg1)
          Else If Mnem = 'SUB' Then BcEmitB($E8 + Reg1)
          Else If Mnem = 'CMP' Then BcEmitB($F8 + Reg1)
          Else If Mnem = 'XOR' Then BcEmitB($F0 + Reg1)
          Else If Mnem = 'AND' Then BcEmitB($E0 + Reg1)
          Else If Mnem = 'OR'  Then BcEmitB($C8 + Reg1);
          BcEmitB(Byte(ImmVal));
        End
        Else If Reg1 = 0 Then { AX, imm16 : forme courte }
        Begin
          If Mnem = 'ADD' Then BcEmitB($05)
          Else If Mnem = 'SUB' Then BcEmitB($2D)
          Else If Mnem = 'CMP' Then BcEmitB($3D)
          Else If Mnem = 'XOR' Then BcEmitB($35)
          Else If Mnem = 'AND' Then BcEmitB($25)
          Else If Mnem = 'OR'  Then BcEmitB($0D);
          BcEmitW(Word(ImmVal));
        End
        Else
        Begin { 81 /r iw }
          BcEmitB($81);
          If Mnem = 'ADD' Then BcEmitB($C0 + Reg1)
          Else If Mnem = 'SUB' Then BcEmitB($E8 + Reg1)
          Else If Mnem = 'CMP' Then BcEmitB($F8 + Reg1)
          Else If Mnem = 'XOR' Then BcEmitB($F0 + Reg1)
          Else If Mnem = 'AND' Then BcEmitB($E0 + Reg1)
          Else If Mnem = 'OR'  Then BcEmitB($C8 + Reg1);
          BcEmitW(Word(ImmVal));
        End;
      End;
      Exit;
    End;
    { CMP reg8, imm8 }
    Reg1 := Reg8(Op1);
    If (Reg1 >= 0) And ParseImm16(Op2, ImmVal) Then
    Begin
      If Mnem = 'CMP' Then
      Begin
        If Reg1 = 0 Then Begin BcEmitB($3C); BcEmitB(Byte(ImmVal)); End
        Else Begin BcEmitB($80); BcEmitB($F8 + Reg1); BcEmitB(Byte(ImmVal)); End;
      End
      Else If Mnem = 'TEST' Then
      Begin
        If Reg1 = 0 Then Begin BcEmitB($A8); BcEmitB(Byte(ImmVal)); End
        Else Begin BcEmitB($F6); BcEmitB($C0 + Reg1); BcEmitB(Byte(ImmVal)); End;
      End
      Else If Mnem = 'ADD' Then
      Begin BcEmitB($80); BcEmitB($C0 + Reg1); BcEmitB(Byte(ImmVal)); End
      Else If Mnem = 'SUB' Then
      Begin BcEmitB($80); BcEmitB($E8 + Reg1); BcEmitB(Byte(ImmVal)); End;
      Exit;
    End;
    { CMP BYTE PTR [ESI+ECX],0  -> utiliser LODSB-like pattern non supporté }
    { CMP BYTE PTR [label],imm8 }
    If (Pos('BYTE PTR', UOp1) > 0) And ParseImm16(Op2, ImmVal) Then
    Begin
      Tmp := Op1;
      P := Pos('[', Tmp);
      If P > 0 Then
      Begin
        Tmp := Copy(Tmp, P, Length(Tmp) - P + 1);
        ParseMemLabel(Tmp, DataLbl, DataAdd);
        If Mnem = 'CMP' Then
        Begin
          BcEmitB($80); BcEmitB($3E); { CMP BYTE PTR [disp16], imm8 }
          BcAddFixup(BC_FIX_ABS16_DATA, DataLbl, DataAdd);
          BcEmitW(0);
          BcEmitB(Byte(ImmVal));
          Exit;
        End;
      End;
    End;
    Exit;
  End;

  { ---- INC / DEC reg16 (accept 32-bit names) ---- }
  If Mnem = 'INC' Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($40 + Reg1); Exit; End;
    Exit;
  End;
  If Mnem = 'DEC' Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then Begin BcEmitB($48 + Reg1); Exit; End;
    Exit;
  End;

  { ---- NEG / NOT / MUL / IMUL / DIV / IDIV reg16 ---- }
  If (Mnem = 'NEG') Or (Mnem = 'NOT') Or
     (Mnem = 'MUL') Or (Mnem = 'IMUL') Or
     (Mnem = 'DIV') Or (Mnem = 'IDIV') Then
  Begin
    Reg1 := Reg16(Op1);
    If Reg1 >= 0 Then
    Begin
      BcEmitB($F7);
      If Mnem = 'NEG'  Then BcEmitB($D8 + Reg1)
      Else If Mnem = 'NOT'  Then BcEmitB($D0 + Reg1)
      Else If Mnem = 'MUL'  Then BcEmitB($E0 + Reg1)
      Else If Mnem = 'IMUL' Then BcEmitB($E8 + Reg1)
      Else If Mnem = 'DIV'  Then BcEmitB($F0 + Reg1)
      Else If Mnem = 'IDIV' Then BcEmitB($F8 + Reg1);
    End;
    Exit;
  End;

  { ---- XCHG AX,reg ---- }
  If Mnem = 'XCHG' Then
  Begin
    Reg1 := Reg16(Op1); Reg2 := Reg16(Op2);
    If (Reg1 = 0) And (Reg2 >= 0) Then Begin BcEmitB($90 + Reg2); Exit; End;
    If (Reg2 = 0) And (Reg1 >= 0) Then Begin BcEmitB($90 + Reg1); Exit; End;
  End;

  { ---- CBW / CWD ---- }
  If Mnem = 'CBW' Then Begin BcEmitB($98); Exit; End;
  If Mnem = 'CWD' Then Begin BcEmitB($99); Exit; End;

  { ---- MOVSB / MOVSW / LODSB / LODSW / STOSB / STOSW ---- }
  If Mnem = 'MOVSB' Then Begin BcEmitB($A4); Exit; End;
  If Mnem = 'MOVSW' Then Begin BcEmitB($A5); Exit; End;
  If Mnem = 'LODSB' Then Begin BcEmitB($AC); Exit; End;
  If Mnem = 'LODSW' Then Begin BcEmitB($AD); Exit; End;
  If Mnem = 'STOSB' Then Begin BcEmitB($AA); Exit; End;
  If Mnem = 'STOSW' Then Begin BcEmitB($AB); Exit; End;

  { ---- REP ---- }
  If Mnem = 'REP' Then Begin BcEmitB($F3); Exit; End;

  { ---- MOVZX -> en 8086, faire MOV reg8, [mem] puis XOR haut ---- }
  { Pour l instant, ignorer silencieusement }
  If Mnem = 'MOVZX' Then Exit;

  { ---- IMUL EAX,EAX,10 -> en 16 bits, utiliser MUL ---- }
  { Ignorer la forme 3 operandes, le runtime DOS n en a pas besoin }

  { Instruction non reconnue (ignoree silencieusement) }
  { WriteLn('BcAssemble8086: non reconnu: [', S, ']'); }
End;

{ ============================================================ }
{ BcAssembleZ80 - Mini-assembleur Zilog Z80                    }
{ ============================================================ }

Procedure BcAssembleZ80(Const S: TString);
Var
  Line, Mnem, Tmp, Op1, Op2: TString;
  P: Integer;

  Procedure SplitOpsZ80(Const Rest: TString);
  Var J: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1;
    While J <= Length(Rest) Do
    Begin
      If (Rest[J] = ',') Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

Begin { BcAssembleZ80 }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;

  SplitOpsZ80(Tmp);

  { ---- NOP ---- }
  If Mnem = 'NOP' Then Begin BcEmitB($00); Exit; End;

  { ---- HALT ---- }
  If Mnem = 'HALT' Then Begin BcEmitB($76); Exit; End;

  { ---- RET ---- }
  If Mnem = 'RET' Then Begin BcEmitB($C9); Exit; End;

  { ---- DI / EI ---- }
  If Mnem = 'DI' Then Begin BcEmitB($F3); Exit; End;
  If Mnem = 'EI' Then Begin BcEmitB($FB); Exit; End;

  { ---- SCF / CCF / CPL / NEG / RLCA / RRCA / RLA / RRA ---- }
  If Mnem = 'SCF' Then Begin BcEmitB($37); Exit; End;
  If Mnem = 'CCF' Then Begin BcEmitB($3F); Exit; End;
  If Mnem = 'CPL' Then Begin BcEmitB($2F); Exit; End;
  If Mnem = 'RLCA' Then Begin BcEmitB($07); Exit; End;
  If Mnem = 'RRCA' Then Begin BcEmitB($0F); Exit; End;
  If Mnem = 'RLA' Then Begin BcEmitB($17); Exit; End;
  If Mnem = 'RRA' Then Begin BcEmitB($1F); Exit; End;
  If Mnem = 'DAA' Then Begin BcEmitB($27); Exit; End;

  { ---- NEG (prefixe ED) ---- }
  If Mnem = 'NEG' Then Begin BcEmitB($ED); BcEmitB($44); Exit; End;

  { ---- PUSH / POP paires de registres ---- }
  If Mnem = 'PUSH' Then
  Begin
    If StrUpperCase(Op1) = 'BC' Then Begin BcEmitB($C5); Exit; End;
    If StrUpperCase(Op1) = 'DE' Then Begin BcEmitB($D5); Exit; End;
    If StrUpperCase(Op1) = 'HL' Then Begin BcEmitB($E5); Exit; End;
    If StrUpperCase(Op1) = 'AF' Then Begin BcEmitB($F5); Exit; End;
  End;

  If Mnem = 'POP' Then
  Begin
    If StrUpperCase(Op1) = 'BC' Then Begin BcEmitB($C1); Exit; End;
    If StrUpperCase(Op1) = 'DE' Then Begin BcEmitB($D1); Exit; End;
    If StrUpperCase(Op1) = 'HL' Then Begin BcEmitB($E1); Exit; End;
    If StrUpperCase(Op1) = 'AF' Then Begin BcEmitB($F1); Exit; End;
  End;

  { ---- INC / DEC registres 8 bits ---- }
  If Mnem = 'INC' Then
  Begin
    If StrUpperCase(Op1) = 'A' Then Begin BcEmitB($3C); Exit; End;
    If StrUpperCase(Op1) = 'B' Then Begin BcEmitB($04); Exit; End;
    If StrUpperCase(Op1) = 'C' Then Begin BcEmitB($0C); Exit; End;
    If StrUpperCase(Op1) = 'D' Then Begin BcEmitB($14); Exit; End;
    If StrUpperCase(Op1) = 'E' Then Begin BcEmitB($1C); Exit; End;
    If StrUpperCase(Op1) = 'H' Then Begin BcEmitB($24); Exit; End;
    If StrUpperCase(Op1) = 'L' Then Begin BcEmitB($2C); Exit; End;
    { INC paires 16 bits }
    If StrUpperCase(Op1) = 'BC' Then Begin BcEmitB($03); Exit; End;
    If StrUpperCase(Op1) = 'DE' Then Begin BcEmitB($13); Exit; End;
    If StrUpperCase(Op1) = 'HL' Then Begin BcEmitB($23); Exit; End;
    If StrUpperCase(Op1) = 'SP' Then Begin BcEmitB($33); Exit; End;
  End;

  If Mnem = 'DEC' Then
  Begin
    If StrUpperCase(Op1) = 'A' Then Begin BcEmitB($3D); Exit; End;
    If StrUpperCase(Op1) = 'B' Then Begin BcEmitB($05); Exit; End;
    If StrUpperCase(Op1) = 'C' Then Begin BcEmitB($0D); Exit; End;
    If StrUpperCase(Op1) = 'D' Then Begin BcEmitB($15); Exit; End;
    If StrUpperCase(Op1) = 'E' Then Begin BcEmitB($1D); Exit; End;
    If StrUpperCase(Op1) = 'H' Then Begin BcEmitB($25); Exit; End;
    If StrUpperCase(Op1) = 'L' Then Begin BcEmitB($2D); Exit; End;
    { DEC paires 16 bits }
    If StrUpperCase(Op1) = 'BC' Then Begin BcEmitB($0B); Exit; End;
    If StrUpperCase(Op1) = 'DE' Then Begin BcEmitB($1B); Exit; End;
    If StrUpperCase(Op1) = 'HL' Then Begin BcEmitB($2B); Exit; End;
    If StrUpperCase(Op1) = 'SP' Then Begin BcEmitB($3B); Exit; End;
  End;

  { ---- EX DE,HL / EX AF,AF' / EXX ---- }
  If Mnem = 'EX' Then
  Begin
    If (StrUpperCase(Op1) = 'DE') And (StrUpperCase(Op2) = 'HL') Then
    Begin BcEmitB($EB); Exit; End;
  End;
  If Mnem = 'EXX' Then Begin BcEmitB($D9); Exit; End;

  { ---- LDIR / LDDR (prefixe ED) ---- }
  If Mnem = 'LDIR' Then Begin BcEmitB($ED); BcEmitB($B0); Exit; End;
  If Mnem = 'LDDR' Then Begin BcEmitB($ED); BcEmitB($B8); Exit; End;

  { ---- RST ---- }
  If Mnem = 'RST' Then
  Begin
    If Op1 = '00H' Then Begin BcEmitB($C7); Exit; End;
    If Op1 = '08H' Then Begin BcEmitB($CF); Exit; End;
    If Op1 = '10H' Then Begin BcEmitB($D7); Exit; End;
    If Op1 = '18H' Then Begin BcEmitB($DF); Exit; End;
    If Op1 = '20H' Then Begin BcEmitB($E7); Exit; End;
    If Op1 = '28H' Then Begin BcEmitB($EF); Exit; End;
    If Op1 = '30H' Then Begin BcEmitB($F7); Exit; End;
    If Op1 = '38H' Then Begin BcEmitB($FF); Exit; End;
  End;

  { Instruction non reconnue (stub) }
  { WriteLn('BcAssembleZ80: non reconnu: [', S, ']'); }
End;

{ ============================================================ }
{ BcAssemble6502 - Mini-assembleur MOS 6502                    }
{ ============================================================ }

Procedure BcAssemble6502(Const S: TString);
Var
  Line, Mnem, Tmp, Op1, Op2: TString;
  P: Integer;

  Procedure SplitOps6502(Const Rest: TString);
  Var J: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1;
    While J <= Length(Rest) Do
    Begin
      If (Rest[J] = ',') Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

Begin { BcAssemble6502 }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;

  SplitOps6502(Tmp);

  { ---- Instructions implicites (1 octet) ---- }
  If Mnem = 'BRK' Then Begin BcEmitB($00); Exit; End;
  If Mnem = 'NOP' Then Begin BcEmitB($EA); Exit; End;
  If Mnem = 'RTS' Then Begin BcEmitB($60); Exit; End;
  If Mnem = 'RTI' Then Begin BcEmitB($40); Exit; End;

  { ---- Pile ---- }
  If Mnem = 'PHA' Then Begin BcEmitB($48); Exit; End;
  If Mnem = 'PLA' Then Begin BcEmitB($68); Exit; End;
  If Mnem = 'PHP' Then Begin BcEmitB($08); Exit; End;
  If Mnem = 'PLP' Then Begin BcEmitB($28); Exit; End;

  { ---- Drapeaux ---- }
  If Mnem = 'CLC' Then Begin BcEmitB($18); Exit; End;
  If Mnem = 'SEC' Then Begin BcEmitB($38); Exit; End;
  If Mnem = 'CLI' Then Begin BcEmitB($58); Exit; End;
  If Mnem = 'SEI' Then Begin BcEmitB($78); Exit; End;
  If Mnem = 'CLV' Then Begin BcEmitB($B8); Exit; End;
  If Mnem = 'CLD' Then Begin BcEmitB($D8); Exit; End;
  If Mnem = 'SED' Then Begin BcEmitB($F8); Exit; End;

  { ---- Transferts de registres ---- }
  If Mnem = 'TAX' Then Begin BcEmitB($AA); Exit; End;
  If Mnem = 'TAY' Then Begin BcEmitB($A8); Exit; End;
  If Mnem = 'TXA' Then Begin BcEmitB($8A); Exit; End;
  If Mnem = 'TYA' Then Begin BcEmitB($98); Exit; End;
  If Mnem = 'TXS' Then Begin BcEmitB($9A); Exit; End;
  If Mnem = 'TSX' Then Begin BcEmitB($BA); Exit; End;

  { ---- Increments / Decrements registres ---- }
  If Mnem = 'INX' Then Begin BcEmitB($E8); Exit; End;
  If Mnem = 'INY' Then Begin BcEmitB($C8); Exit; End;
  If Mnem = 'DEX' Then Begin BcEmitB($CA); Exit; End;
  If Mnem = 'DEY' Then Begin BcEmitB($88); Exit; End;

  { ---- Decalages accumulateur ---- }
  If Mnem = 'ASLA' Then Begin BcEmitB($0A); Exit; End;
  If Mnem = 'ROLA' Then Begin BcEmitB($2A); Exit; End;
  If Mnem = 'LSRA' Then Begin BcEmitB($4A); Exit; End;
  If Mnem = 'RORA' Then Begin BcEmitB($6A); Exit; End;

  { ---- Decalages accumulateur (forme standard ASL A, etc.) ---- }
  If (Mnem = 'ASL') And (StrUpperCase(Op1) = 'A') Then
  Begin BcEmitB($0A); Exit; End;
  If (Mnem = 'ROL') And (StrUpperCase(Op1) = 'A') Then
  Begin BcEmitB($2A); Exit; End;
  If (Mnem = 'LSR') And (StrUpperCase(Op1) = 'A') Then
  Begin BcEmitB($4A); Exit; End;
  If (Mnem = 'ROR') And (StrUpperCase(Op1) = 'A') Then
  Begin BcEmitB($6A); Exit; End;

  { Instruction non reconnue (stub) }
  { WriteLn('BcAssemble6502: non reconnu: [', S, ']'); }
End;

{ ============================================================ }
{ BcAssemble6809 - Mini-assembleur Motorola 6809               }
{ ============================================================ }

Procedure BcAssemble6809(Const S: TString);
Var
  Line, Mnem, Tmp, Op1, Op2: TString;
  P: Integer;

  Procedure SplitOps6809(Const Rest: TString);
  Var J: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1;
    While J <= Length(Rest) Do
    Begin
      If (Rest[J] = ',') Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

Begin { BcAssemble6809 }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;

  SplitOps6809(Tmp);

  { ---- Instructions implicites (1 octet) ---- }
  If Mnem = 'NOP'  Then Begin BcEmitB($12); Exit; End;
  If Mnem = 'SYNC' Then Begin BcEmitB($13); Exit; End;
  If Mnem = 'DAA'  Then Begin BcEmitB($19); Exit; End;
  If Mnem = 'SEX'  Then Begin BcEmitB($1D); Exit; End;
  If Mnem = 'RTS'  Then Begin BcEmitB($39); Exit; End;
  If Mnem = 'ABX'  Then Begin BcEmitB($3A); Exit; End;
  If Mnem = 'RTI'  Then Begin BcEmitB($3B); Exit; End;
  If Mnem = 'MUL'  Then Begin BcEmitB($3D); Exit; End;
  If Mnem = 'SWI'  Then Begin BcEmitB($3F); Exit; End;

  { ---- Operations sur accumulateur A (implicite) ---- }
  If Mnem = 'NEGA' Then Begin BcEmitB($40); Exit; End;
  If Mnem = 'COMA' Then Begin BcEmitB($43); Exit; End;
  If Mnem = 'LSRA' Then Begin BcEmitB($44); Exit; End;
  If Mnem = 'RORA' Then Begin BcEmitB($46); Exit; End;
  If Mnem = 'ASRA' Then Begin BcEmitB($47); Exit; End;
  If Mnem = 'ASLA' Then Begin BcEmitB($48); Exit; End;
  If Mnem = 'ROLA' Then Begin BcEmitB($49); Exit; End;
  If Mnem = 'DECA' Then Begin BcEmitB($4A); Exit; End;
  If Mnem = 'INCA' Then Begin BcEmitB($4C); Exit; End;
  If Mnem = 'TSTA' Then Begin BcEmitB($4D); Exit; End;
  If Mnem = 'CLRA' Then Begin BcEmitB($4F); Exit; End;

  { ---- Operations sur accumulateur B (implicite) ---- }
  If Mnem = 'NEGB' Then Begin BcEmitB($50); Exit; End;
  If Mnem = 'COMB' Then Begin BcEmitB($53); Exit; End;
  If Mnem = 'LSRB' Then Begin BcEmitB($54); Exit; End;
  If Mnem = 'RORB' Then Begin BcEmitB($56); Exit; End;
  If Mnem = 'ASRB' Then Begin BcEmitB($57); Exit; End;
  If Mnem = 'ASLB' Then Begin BcEmitB($58); Exit; End;
  If Mnem = 'ROLB' Then Begin BcEmitB($59); Exit; End;
  If Mnem = 'DECB' Then Begin BcEmitB($5A); Exit; End;
  If Mnem = 'INCB' Then Begin BcEmitB($5C); Exit; End;
  If Mnem = 'TSTB' Then Begin BcEmitB($5D); Exit; End;
  If Mnem = 'CLRB' Then Begin BcEmitB($5F); Exit; End;

  { ---- Instructions page 2 (prefixe $10) ---- }
  If Mnem = 'SWI2' Then Begin BcEmitB($10); BcEmitB($3F); Exit; End;

  { ---- Instructions page 3 (prefixe $11) ---- }
  If Mnem = 'SWI3' Then Begin BcEmitB($11); BcEmitB($3F); Exit; End;

  { Instruction non reconnue (stub) }
  { WriteLn('BcAssemble6809: non reconnu: [', S, ']'); }
End;

{ ============================================================ }
{ BcAssemble68000 - Mini-assembleur Motorola 68000             }
{ ============================================================ }

Procedure BcAssemble68000(Const S: TString);
Var
  Line, Mnem, Tmp, Op1, Op2: TString;
  P: Integer;

  Procedure SplitOps68000(Const Rest: TString);
  Var J: Integer;
  Begin
    Op1 := ''; Op2 := '';
    J := 1;
    While J <= Length(Rest) Do
    Begin
      If (Rest[J] = ',') Then
      Begin
        Op1 := Copy(Rest, 1, J - 1);
        Op2 := Copy(Rest, J + 1, Length(Rest) - J);
        While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
          Delete(Op1, Length(Op1), 1);
        While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
        Exit;
      End;
      Inc(J);
    End;
    Op1 := Rest;
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
  End;

Begin { BcAssemble68000 }
  Line := S;
  While (Length(Line) > 0) And (Line[1] = ' ') Do Delete(Line, 1, 1);
  While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
    Delete(Line, Length(Line), 1);
  If Line = '' Then Exit;

  { Extraire le mnemonique }
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    Mnem := StrUpperCase(Copy(Line, 1, P - 1));
    Tmp := Copy(Line, P + 1, Length(Line) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  End
  Else Begin Mnem := StrUpperCase(Line); Tmp := ''; End;

  SplitOps68000(Tmp);

  { ---- Instructions implicites (sans operande, 1 mot = 2 octets) ---- }
  If Mnem = 'NOP'     Then Begin BcEmitB($4E); BcEmitB($71); Exit; End;
  If Mnem = 'RTS'     Then Begin BcEmitB($4E); BcEmitB($75); Exit; End;
  If Mnem = 'RTE'     Then Begin BcEmitB($4E); BcEmitB($73); Exit; End;
  If Mnem = 'RTR'     Then Begin BcEmitB($4E); BcEmitB($77); Exit; End;
  If Mnem = 'TRAPV'   Then Begin BcEmitB($4E); BcEmitB($76); Exit; End;
  If Mnem = 'RESET'   Then Begin BcEmitB($4E); BcEmitB($70); Exit; End;
  If Mnem = 'ILLEGAL' Then Begin BcEmitB($4A); BcEmitB($FC); Exit; End;

  { Instruction non reconnue (stub) }
  { WriteLn('BcAssemble68000: non reconnu: [', S, ']'); }
End;

{ --- Construction de la section .data binaire --- }
Procedure BcBuildData;
Var I, J: Integer; S: TString;
Begin
  BcDataLen := 0; BcDLabelCnt := 0;

  { Variables runtime HSTDOUT, HSTDIN, HHEAP (les 3 premiers DWORDs) }
  BcDefineDataLabel('HSTDOUT');   BcDataD(0);
  BcDefineDataLabel('HSTDIN');    BcDataD(0);
  BcDefineDataLabel('HHEAP');     BcDataD(0);
  BcDefineDataLabel('NUMBUF');    BcDataZeros(32);
  BcDefineDataLabel('INBUF');     BcDataZeros(256);
  BcDefineDataLabel('BYTESWR');   BcDataD(0);
  BcDefineDataLabel('BYTESRD');   BcDataD(0);
  BcDefineDataLabel('CRLF');      BcDataB(13); BcDataB(10); BcDataB(0);
  BcDefineDataLabel('STRTMP');    BcDataZeros(256);
  BcDefineDataLabel('STRBUF1');   BcDataZeros(256);
  BcDefineDataLabel('STRBUF2');   BcDataZeros(256);
  BcDefineDataLabel('TRUE_STR');  BcDataStr('TRUE');
  BcDefineDataLabel('FALSE_STR'); BcDataStr('FALSE');

  { Variables CRT }
  BcDefineDataLabel('TEXTATTR');   BcDataD(7);
  BcDefineDataLabel('WINDMIN');    BcDataD(0);
  BcDefineDataLabel('WINDMAX');    BcDataD($184F);
  BcDefineDataLabel('LASTMODE');   BcDataD(3);
  BcDefineDataLabel('DIRECTVIDEO');BcDataD(1);
  BcDefineDataLabel('CHECKBREAK'); BcDataD(1);
  BcDefineDataLabel('CHECKEOF');   BcDataD(0);
  BcDefineDataLabel('CHECKSNOW');  BcDataD(0);
  BcDefineDataLabel('CRT_CSBI');   BcDataZeros(22);
  BcDefineDataLabel('CRT_INREC');  BcDataZeros(20);
  BcDefineDataLabel('CRT_NEVT');   BcDataD(0);
  BcDefineDataLabel('CRT_NWRT');   BcDataD(0);
  BcDefineDataLabel('CRT_SCROLL'); BcDataZeros(16);
  BcDefineDataLabel('CRT_FILL');   BcDataD(0); BcDataD(0);

  { Variables DOS }
  BcDefineDataLabel('DOSERROR');    BcDataD(0);
  BcDefineDataLabel('DOSEXITCODE'); BcDataD(0);
  BcDefineDataLabel('DOS_SYSTIME'); BcDataZeros(16);
  BcDefineDataLabel('DOS_FATTR');   BcDataD(0);
  BcDefineDataLabel('DOS_ENVBUF');  BcDataZeros(256);
  BcDefineDataLabel('DOS_PATHBUF'); BcDataZeros(260);
  BcDefineDataLabel('DOS_DKFREE');  BcDataZeros(16);
  BcDefineDataLabel('DOS_FINDDATA');BcDataZeros(320);
  BcDefineDataLabel('DOS_FINDHDL'); BcDataD(-1);
  BcDefineDataLabel('DOS_PROCINFO');BcDataZeros(16);
  BcDefineDataLabel('DOS_STARTINFO');BcDataZeros(68);
  BcDefineDataLabel('DOS_EXITVAL'); BcDataD(0);

  { Variables File I/O }
  BcDefineDataLabel('FILE_NAMEBUF'); BcDataZeros(260);
  BcDefineDataLabel('FILE_RENBUF');  BcDataZeros(260);
  BcDefineDataLabel('FILE_RDBUF');   BcDataZeros(256);
  BcDefineDataLabel('FILE_BUFPOS');  BcDataD(0);
  BcDefineDataLabel('FILE_BUFEND');  BcDataD(0);
  BcDefineDataLabel('FILE_EOFFLG'); BcDataD(0);
  BcDefineDataLabel('FILE_BYTESRD');BcDataD(0);
  BcDefineDataLabel('FILE_WRHND');  BcDataD(0);
  BcDefineDataLabel('FILE_WRFLG');  BcDataD(0);
  BcDefineDataLabel('FILE_IOERR');  BcDataD(0);
  BcDefineDataLabel('STDIN_EOF');    BcDataD(0);
  BcDefineDataLabel('DIR_NAMEBUF');   For I := 1 To 260 Do BcDataB(0);
  BcDefineDataLabel('RAND_SEED');   BcDataD(12345);
  BcDefineDataLabel('FP_TMP');      BcDataD(0); BcDataD(0); { 8 bytes }

  { Variables ParamStr/ParamCount }
  BcDefineDataLabel('PARAM_PARSED'); BcDataD(0);
  BcDefineDataLabel('PARAM_COUNT');  BcDataD(0);
  BcDefineDataLabel('PARAM_ARGC');   BcDataD(0);
  BcDefineDataLabel('PARAM_PTRS');   BcDataZeros(64 * 4);  { 64 DWORDs }
  BcDefineDataLabel('PARAM_BUF');    BcDataZeros(1024);

  { Variables Graph }
  BcDefineDataLabel('GR_RESULT');   BcDataD(0);
  BcDefineDataLabel('GR_DRIVER');   BcDataD(0);
  BcDefineDataLabel('GR_MODE');     BcDataD(0);
  BcDefineDataLabel('GR_HWND');     BcDataD(0);
  BcDefineDataLabel('GR_HDC');      BcDataD(0);
  BcDefineDataLabel('GR_HPEN');     BcDataD(0);
  BcDefineDataLabel('GR_HBRUSH');   BcDataD(0);
  BcDefineDataLabel('GR_HFONT');    BcDataD(0);
  BcDefineDataLabel('GR_HINST');    BcDataD(0);
  BcDefineDataLabel('GR_MAXX');     BcDataD(639);
  BcDefineDataLabel('GR_MAXY');     BcDataD(479);
  BcDefineDataLabel('GR_COLOR');    BcDataD(15);
  BcDefineDataLabel('GR_BKCOLOR');  BcDataD(0);
  BcDefineDataLabel('GR_FILLCOLOR');BcDataD(0);
  BcDefineDataLabel('GR_FILLSTYLE');BcDataD(1);
  BcDefineDataLabel('GR_LINESTYLE');BcDataD(0);
  BcDefineDataLabel('GR_LINEWIDTH');BcDataD(1);
  BcDefineDataLabel('GR_WRITEMODE');BcDataD(0);
  BcDefineDataLabel('GR_CPX');      BcDataD(0);
  BcDefineDataLabel('GR_CPY');      BcDataD(0);
  BcDefineDataLabel('GR_VPXL');     BcDataD(0);
  BcDefineDataLabel('GR_VPYT');     BcDataD(0);
  BcDefineDataLabel('GR_VPXR');     BcDataD(639);
  BcDefineDataLabel('GR_VPYB');     BcDataD(479);
  BcDefineDataLabel('GR_VPCLIP');   BcDataD(1);
  BcDefineDataLabel('GR_TXFONT');   BcDataD(0);
  BcDefineDataLabel('GR_TXDIR');    BcDataD(0);
  BcDefineDataLabel('GR_TXSIZE');   BcDataD(1);
  BcDefineDataLabel('GR_ACTIVE');   BcDataD(0);
  BcDefineDataLabel('GR_MAXCOLOR'); BcDataD(15);
  BcDefineDataLabel('GR_WNDCLASS'); BcDataStr('TPGraphWnd');
  BcDefineDataLabel('GR_WNDTITLE'); BcDataStr('Turbo Pascal Graphics');
  BcDefineDataLabel('GR_CLSREC');   BcDataZeros(40);
  BcDefineDataLabel('GR_RECT');     BcDataZeros(16);
  BcDefineDataLabel('GR_MSG');      BcDataZeros(28);
  BcDefineDataLabel('GR_TXBUF');    BcDataZeros(256);
  BcDefineDataLabel('GR_TXSIZE2');  BcDataZeros(8);
  BcDefineDataLabel('GR_PALETTE');
  { 16 couleurs EGA/VGA COLORREF }
  BcDataD($000000); BcDataD($AA0000); BcDataD($00AA00); BcDataD($AAAA00);
  BcDataD($0000AA); BcDataD($AA00AA); BcDataD($0055AA); BcDataD($AAAAAA);
  BcDataD($555555); BcDataD($FF5555); BcDataD($55FF55); BcDataD($FFFF55);
  BcDataD($5555FF); BcDataD($FF55FF); BcDataD($55FFFF); BcDataD($FFFFFF);
  BcDefineDataLabel('GR_ERRMSG0');  BcDataStr('No error');
  BcDefineDataLabel('GR_ERRMSG1');  BcDataStr('(BGI) graphics not installed');
  BcDefineDataLabel('GR_ERRMSG2');  BcDataStr('Graphics hardware not detected');
  BcDefineDataLabel('GR_DRVNAME');  BcDataStr('EGAVGA');
  BcDefineDataLabel('GR_MODNAME');  BcDataStr('640x480x16');
  BcDefineDataLabel('GR_TXJUST_H'); BcDataD(0);
  BcDefineDataLabel('GR_TXJUST_V'); BcDataD(2);
  BcDefineDataLabel('GR_ARCX');     BcDataD(0);
  BcDefineDataLabel('GR_ARCY');     BcDataD(0);
  BcDefineDataLabel('GR_ARCXS');    BcDataD(0);
  BcDefineDataLabel('GR_ARCYS');    BcDataD(0);
  BcDefineDataLabel('GR_ARCXE');    BcDataD(0);
  BcDefineDataLabel('GR_ARCYE');    BcDataD(0);
  BcDefineDataLabel('GR_VIDCFG');   BcDataZeros(44);

  { Variables Strings/Printer/Overlay/Objects }
  BcDefineDataLabel('STR_TMPBUF'); BcDataZeros(256);
  BcDefineDataLabel('STR_PASBUF'); BcDataZeros(256);
  BcDefineDataLabel('PRN_HANDLE'); BcDataD(-1);
  BcDefineDataLabel('PRN_FNAME');  BcDataStr('NUL');
  BcDefineDataLabel('OVR_RESULT'); BcDataD(0);
  BcDefineDataLabel('OVR_BUFSIZE');BcDataD(0);
  BcDefineDataLabel('OBJ_STATUS'); BcDataD(0);
  BcDefineDataLabel('OBJ_STRBUF'); BcDataZeros(256);
  BcDefineDataLabel('OBJ_TMPHDL'); BcDataD(-1);
  BcDefineDataLabel('OBJ_TMPPOS'); BcDataD(0);
  BcDefineDataLabel('OBJ_TMPSIZ'); BcDataD(0);
  BcDefineDataLabel('OBJ_TMPBUF'); BcDataZeros(1024);
  BcDefineDataLabel('OBJ_BYTESRW');BcDataD(0);

  { Variables Mem/Port }
  BcDefineDataLabel('MEM_TMPVAL'); BcDataD(0);
  BcDefineDataLabel('PORT_TMPVAL');BcDataD(0);
  BcDefineDataLabel('PORT_RTCIDX');BcDataB(0);

  { Variables interruptions }
  BcDefineDataLabel('INT_VIDEOMODE');BcDataB(3);
  BcDefineDataLabel('INT_CURSORX'); BcDataB(0);
  BcDefineDataLabel('INT_CURSORY'); BcDataB(0);
  BcDefineDataLabel('INT_CURPAGE'); BcDataB(0);
  BcDefineDataLabel('INT_MOUSEBTNS');BcDataD(0);
  BcDefineDataLabel('INT_MOUSEX');  BcDataD(0);
  BcDefineDataLabel('INT_MOUSEY');  BcDataD(0);
  BcDefineDataLabel('INT_MOUSEVIS');BcDataD(0);
  BcDefineDataLabel('INT_KBCHAR'); BcDataB(0);
  BcDefineDataLabel('INT_KBSCAN'); BcDataB(0);
  BcDefineDataLabel('INT_CSBI');   BcDataZeros(24);
  BcDefineDataLabel('INT_CURPOS'); BcDataZeros(8);
  BcDefineDataLabel('INT_INPREC'); BcDataZeros(32);
  BcDefineDataLabel('INT_INEVCNT');BcDataD(0);

  { Constantes et donnees utilisateur depuis DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    BcDefineDataLabel(DataTab[I].LblName);
    Case DataTab[I].Kind Of
      DK_STR:
      Begin
        For J := 1 To Length(DataTab[I].StrVal) Do
          BcDataB(Byte(DataTab[I].StrVal[J]));
        BcDataB(0); { terminateur NUL }
      End;
      DK_DWORD: BcDataD(DataTab[I].IntVal);
      DK_BYTE: BcDataB(Byte(DataTab[I].IntVal));
      DK_ARRAY: BcDataZeros(LongInt(DataTab[I].ElemCount) *
                            LongInt(DataTab[I].ElemSize));
      DK_RES: BcDataZeros(DataTab[I].IntVal);
      DK_STRUCT:
        If DataTab[I].IntVal > 0 Then BcDataZeros(DataTab[I].IntVal)
        Else BcDataD(0);
      DK_ZERO:
        If DataTab[I].IntVal > 0 Then BcDataZeros(DataTab[I].IntVal)
        Else BcDataD(0);
    End;
  End;
End;

{ --- Resolution des fixups (code relatif + donnees absolues) --- }
Procedure BcResolveFixups(DataVA: LongInt);
Var
  I: LongInt;
  TargetOfs, FixOfs: LongInt;
  Val: LongInt;
Begin
  For I := 0 To BcFixupCnt - 1 Do
  Begin
    FixOfs := BcFixups[I].CodeOfs;
    If FixOfs + 1 >= BcCodeLen Then Continue;
    Case BcFixups[I].Kind Of
      BC_FIX_REL32:
      Begin
        If FixOfs + 3 >= BcCodeLen Then Continue;
        TargetOfs := BcFindLabel(BcFixups[I].LblName);
        If TargetOfs >= 0 Then
        Begin
          Val := TargetOfs - (FixOfs + 4);
          BcCode[FixOfs] := Byte(Val);
          BcCode[FixOfs + 1] := Byte(Val Shr 8);
          BcCode[FixOfs + 2] := Byte(Val Shr 16);
          BcCode[FixOfs + 3] := Byte(Val Shr 24);
        End;
      End;
      BC_FIX_ABS32_DATA:
      Begin
        If FixOfs + 3 >= BcCodeLen Then Continue;
        TargetOfs := BcFindDataLabel(BcFixups[I].LblName);
        If TargetOfs >= 0 Then
          Val := DataVA + TargetOfs + BcFixups[I].Addend
        Else
          Val := DataVA;
        BcCode[FixOfs] := Byte(Val);
        BcCode[FixOfs + 1] := Byte(Val Shr 8);
        BcCode[FixOfs + 2] := Byte(Val Shr 16);
        BcCode[FixOfs + 3] := Byte(Val Shr 24);
      End;
      BC_FIX_REL16:
      Begin
        TargetOfs := BcFindLabel(BcFixups[I].LblName);
        If TargetOfs >= 0 Then
        Begin
          Val := TargetOfs - (FixOfs + 2);
          BcCode[FixOfs] := Byte(Val);
          BcCode[FixOfs + 1] := Byte(Val Shr 8);
        End;
      End;
      BC_FIX_ABS16_DATA:
      Begin
        TargetOfs := BcFindDataLabel(BcFixups[I].LblName);
        If TargetOfs >= 0 Then
          Val := TargetOfs + BcFixups[I].Addend
        Else
          Val := 0;
        BcCode[FixOfs] := Byte(Val);
        BcCode[FixOfs + 1] := Byte(Val Shr 8);
      End;
    End; { case }
  End;
End;

{ Patch les fixups IAT avec les adresses reelles }
Procedure BcPatchIATFixups(IatVA: LongInt);
Var I: LongInt; FixOfs, Slot: LongInt; Val: LongInt;
Begin
  For I := 0 To BcFixupCnt - 1 Do
  Begin
    If BcFixups[I].Kind = BC_FIX_ABS32_IMP Then
    Begin
      FixOfs := BcFixups[I].CodeOfs;
      If FixOfs + 3 >= BcCodeLen Then Continue;
      Slot := BcFixups[I].Addend;
      Val := IatVA + Slot * 4;
      BcCode[FixOfs] := Byte(Val);
      BcCode[FixOfs + 1] := Byte(Val Shr 8);
      BcCode[FixOfs + 2] := Byte(Val Shr 16);
      BcCode[FixOfs + 3] := Byte(Val Shr 24);
    End;
  End;
End;

{ --- WriteMZFile : generation d un EXE DOS 16 bits (format MZ) --- }
Procedure WriteMZFile(FileName: TString);
Var
  F: File;
  HeaderSize, ImageSize, TotalSize: LongInt;
  CodeParas, DataParas: LongInt;
  PageCount, LastPageBytes: Word;
  RelocOfs, MainOfs: LongInt;
  I: LongInt;
  W: Word;
  B: Byte;
Begin
  { Calculer les tailles en paragraphes (16 octets) }
  CodeParas := (BcCodeLen + 15) Div 16;
  DataParas := (BcDataLen + 15) Div 16;

  { En-tete MZ : 28 octets fixes + 1 relocation (4 octets) = 32 octets }
  { Arrondi au paragraphe superieur: 32 -> 2 paragraphes }
  HeaderSize := 32; { 28 + 4 (1 relocation entry) }
  If HeaderSize Mod 16 <> 0 Then
    HeaderSize := ((HeaderSize Div 16) + 1) * 16;

  { Trouver le point d entree _TPF_Main }
  MainOfs := BcFindLabel(TP_FUNC_PFX + 'Main');
  If MainOfs < 0 Then MainOfs := 0;

  { Patcher le MOV AX,imm16 pour le segment data }
  { Chercher la premiere instruction du main : B8 00 00 (MOV AX,0) }
  { et la remplacer par B8 <code_paras_lo> <code_paras_hi> }
  { On ajoute aussi une entree de relocation pour cette adresse }
  { L offset de l immediat est MainOfs + 1 (apres le B8) }
  If (MainOfs + 2 < BcCodeLen) And
     (BcCode[MainOfs] = $B8) Then
  Begin
    BcCode[MainOfs + 1] := Byte(CodeParas);
    BcCode[MainOfs + 2] := Byte(CodeParas Shr 8);
  End;

  { Resoudre les fixups : REL16 et ABS16_DATA }
  For I := 0 To BcFixupCnt - 1 Do
  Begin
    If BcFixups[I].Kind = BC_FIX_REL16 Then
    Begin
      If BcFixups[I].CodeOfs + 1 < BcCodeLen Then
      Begin
        RelocOfs := BcFindLabel(BcFixups[I].LblName);
        If RelocOfs >= 0 Then
        Begin
          W := Word(RelocOfs - (BcFixups[I].CodeOfs + 2));
          BcCode[BcFixups[I].CodeOfs] := Lo(W);
          BcCode[BcFixups[I].CodeOfs + 1] := Hi(W);
        End;
      End;
    End
    Else If BcFixups[I].Kind = BC_FIX_ABS16_DATA Then
    Begin
      If BcFixups[I].CodeOfs + 1 < BcCodeLen Then
      Begin
        RelocOfs := BcFindDataLabel(BcFixups[I].LblName);
        If RelocOfs < 0 Then RelocOfs := 0;
        W := Word(RelocOfs + BcFixups[I].Addend);
        BcCode[BcFixups[I].CodeOfs] := Lo(W);
        BcCode[BcFixups[I].CodeOfs + 1] := Hi(W);
      End;
    End;
  End;

  { Taille totale de l image (apres en-tete) }
  ImageSize := CodeParas * 16 + DataParas * 16;
  TotalSize := HeaderSize + ImageSize;

  { Calculer le nombre de pages MZ (512 octets par page) }
  PageCount := (TotalSize + 511) Div 512;
  LastPageBytes := TotalSize Mod 512;

  { Ecrire le fichier }
  Assign(F, FileName);
  Rewrite(F, 1);

  { --- En-tete MZ (28 octets) --- }
  W := $5A4D; BlockWrite(F, W, 2);           { Signature 'MZ' }
  W := LastPageBytes; BlockWrite(F, W, 2);    { Octets derniere page }
  W := PageCount; BlockWrite(F, W, 2);        { Nombre de pages }
  W := 1; BlockWrite(F, W, 2);               { 1 relocation }
  W := HeaderSize Div 16; BlockWrite(F, W, 2);{ Taille en-tete en paragraphes }
  W := 0; BlockWrite(F, W, 2);               { MinAlloc }
  W := $FFFF; BlockWrite(F, W, 2);           { MaxAlloc }
  { SS : segment pile = apres code + data }
  W := CodeParas + DataParas; BlockWrite(F, W, 2); { SS }
  W := $FFFE; BlockWrite(F, W, 2);           { SP }
  W := 0; BlockWrite(F, W, 2);               { Checksum }
  W := Word(MainOfs); BlockWrite(F, W, 2);   { IP = offset du main }
  W := 0; BlockWrite(F, W, 2);               { CS = 0 (debut du code) }
  W := 28; BlockWrite(F, W, 2);              { Offset table relocation }
  W := 0; BlockWrite(F, W, 2);               { Overlay number }

  { --- Table de relocation (1 entree : le MOV AX, @DATA) --- }
  W := Word(MainOfs + 1); BlockWrite(F, W, 2); { Offset dans le segment }
  W := 0; BlockWrite(F, W, 2);                  { Segment (CS = 0) }

  { --- Padding jusqu au debut de l image --- }
  B := 0;
  For I := 32 To HeaderSize - 1 Do
    BlockWrite(F, B, 1);

  { --- Segment de code --- }
  If BcCodeLen > 0 Then
    BlockWrite(F, BcCode, BcCodeLen);
  { Padding du segment de code au paragraphe }
  B := 0;
  For I := BcCodeLen To CodeParas * 16 - 1 Do
    BlockWrite(F, B, 1);

  { --- Segment de donnees --- }
  If BcDataLen > 0 Then
    BlockWrite(F, BcData, BcDataLen);
  { Padding du segment de donnees au paragraphe }
  B := 0;
  For I := BcDataLen To DataParas * 16 - 1 Do
    BlockWrite(F, B, 1);

  Close(F);
End;

{ --- WritePEFile : generation d un PE executable Win32 --- }
Procedure WritePEFile(FileName: TString);
Const
  MAX_DLL_PE = 8;
  MAX_IMP_PER_DLL = 128;
Type
  TDllGroup = Record
    DllName: TString;
    Idxs: Array[0..MAX_IMP_PER_DLL-1] Of Integer;
    Cnt: Integer;
  End;
Var
  DllGroups: Array[0..MAX_DLL_PE-1] Of TDllGroup;
  DllGrpCnt: Integer;
  TextRawSize, DataRawSize, IdataRawSize: LongInt;
  DataRVA, IdataRVA: LongInt;
  DataVA, IdataVA: LongInt;
  ImageSize: LongInt;
  TextAligned, DataAligned: LongInt;
  { Import table layout offsets (within .idata section) }
  IdtSize, IltOfs, IatOfs, HntOfs, DnmOfs: LongInt;
  IltPerDll, IatPerDll: Array[0..MAX_DLL_PE-1] Of LongInt;
  HntPerImp: Array[0..255] Of LongInt;
  DnmPerDll: Array[0..MAX_DLL_PE-1] Of LongInt;
  IatVA: LongInt;
  CurOfs: LongInt;
  DI, AI, I, J: Integer;
  Found: Boolean;
  ImpIdx: Integer;
  IdataVirtSize: LongInt;
  IatSlotOfs: Array[0..255] Of LongInt;
  FxOfs, ValIat, IATTotalSize, IdataFileBase, MainOfs: LongInt;
  Slot: LongInt;
  EntryPointRVA: LongInt;

  Function AlignUp(V, A: LongInt): LongInt;
  Begin AlignUp := ((V + A - 1) Div A) * A; End;

Begin
  { ========== Grouper les imports par DLL ========== }
  DllGrpCnt := 0;
  For I := 0 To BcImportCnt - 1 Do
  Begin
    Found := False;
    For DI := 0 To DllGrpCnt - 1 Do
      If DllGroups[DI].DllName = BcImports[I].DllName Then
      Begin
        If DllGroups[DI].Cnt < MAX_IMP_PER_DLL Then
        Begin
          DllGroups[DI].Idxs[DllGroups[DI].Cnt] := I;
          Inc(DllGroups[DI].Cnt);
        End;
        Found := True; Break;
      End;
    If (Not Found) And (DllGrpCnt < MAX_DLL_PE) Then
    Begin
      DllGroups[DllGrpCnt].DllName := BcImports[I].DllName;
      DllGroups[DllGrpCnt].Cnt := 1;
      DllGroups[DllGrpCnt].Idxs[0] := I;
      Inc(DllGrpCnt);
    End;
  End;
  { S assurer qu au moins kernel32.dll est present }
  If DllGrpCnt = 0 Then
  Begin
    DllGrpCnt := 1;
    DllGroups[0].DllName := 'kernel32.dll';
    DllGroups[0].Cnt := 0;
  End;

  { ========== Calculer la disposition de la section .idata ========== }
  { IDT : (DllGrpCnt + 1) * 20 bytes }
  IdtSize := (DllGrpCnt + 1) * 20;
  CurOfs := IdtSize;

  { ILT per DLL }
  IltOfs := CurOfs;
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    IltPerDll[DI] := CurOfs;
    CurOfs := CurOfs + (DllGroups[DI].Cnt + 1) * 4;
  End;

  { IAT per DLL (meme structure que ILT) }
  IatOfs := CurOfs;
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    IatPerDll[DI] := CurOfs;
    CurOfs := CurOfs + (DllGroups[DI].Cnt + 1) * 4;
  End;

  { Hint/Name Table }
  HntOfs := CurOfs;
  For DI := 0 To DllGrpCnt - 1 Do
    For AI := 0 To DllGroups[DI].Cnt - 1 Do
    Begin
      ImpIdx := DllGroups[DI].Idxs[AI];
      HntPerImp[ImpIdx] := CurOfs;
      CurOfs := CurOfs + 2 + Length(BcImports[ImpIdx].ApiName) + 1;
      If Odd(CurOfs) Then Inc(CurOfs);
    End;

  { DLL Name strings }
  DnmOfs := CurOfs;
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    DnmPerDll[DI] := CurOfs;
    CurOfs := CurOfs + Length(DllGroups[DI].DllName) + 1;
    If Odd(CurOfs) Then Inc(CurOfs);
  End;
  IdataVirtSize := CurOfs;

  { ========== Calculer les tailles et RVA des sections ========== }
  TextAligned := AlignUp(BcCodeLen, PE_SECT_ALIGN_);
  If TextAligned < PE_SECT_ALIGN_ Then TextAligned := PE_SECT_ALIGN_;
  DataAligned := AlignUp(BcDataLen, PE_SECT_ALIGN_);
  If DataAligned < PE_SECT_ALIGN_ Then DataAligned := PE_SECT_ALIGN_;

  DataRVA  := PE_TEXT_RVA + TextAligned;
  IdataRVA := DataRVA + DataAligned;

  DataVA   := PE_IMG_BASE + DataRVA;
  IdataVA  := PE_IMG_BASE + IdataRVA;

  TextRawSize  := AlignUp(BcCodeLen, PE_FILE_ALIGN_);
  If TextRawSize < PE_FILE_ALIGN_ Then TextRawSize := PE_FILE_ALIGN_;
  DataRawSize  := AlignUp(BcDataLen, PE_FILE_ALIGN_);
  If DataRawSize < PE_FILE_ALIGN_ Then DataRawSize := PE_FILE_ALIGN_;
  IdataRawSize := AlignUp(IdataVirtSize, PE_FILE_ALIGN_);
  If IdataRawSize < PE_FILE_ALIGN_ Then IdataRawSize := PE_FILE_ALIGN_;

  ImageSize := IdataRVA + AlignUp(IdataVirtSize, PE_SECT_ALIGN_);

  { ========== Resoudre les fixups maintenant qu on connait le layout ========== }
  BcResolveFixups(DataVA);

  { Trouver le point d entree _TPF_Main }
  EntryPointRVA := PE_TEXT_RVA;
  MainOfs := BcFindLabel(TP_FUNC_PFX + 'Main');
  If MainOfs >= 0 Then
    EntryPointRVA := PE_TEXT_RVA + MainOfs;

  { Calculer l adresse VA de chaque slot IAT }
  { Le IAT est une table plate : slot I est a IatOfs + position dans le groupe }
  { On veut que BcImports[I] -> IAT_VA + slot_offset }
  IatVA := PE_IMG_BASE + IdataRVA + IatOfs;
  { Mais le code utilise BcFixups[].Addend = index dans BcImports[] }
  { et BcPatchIATFixups calcule IatVA + Slot*4 }
  { Il faut que pour l import I, la position dans le IAT soit I*4 }
  { Le IAT a des separateurs null entre groupes DLL, donc slot*4 ne marchera pas }
  { => On construit un IAT plat continu SANS les separateurs null inter-DLL }
  { SAUF que le loader Windows EXIGE les null entre groupes. }
  { Solution : construire un mapping ordonne de slot sequentiel }
  { En fait, reordonner le IAT pour que slot I = position I dans le bloc }
  { Le plus simple : IAT plat de BcImportCnt+DllGrpCnt entrees }
  { Slot I doit mapper a la bonne position dans le IAT regroupe }
  { Construisons un tableau position[BcImportSlot] -> byte offset dans IAT }
  CurOfs := 0;
    For DI := 0 To DllGrpCnt - 1 Do
    Begin
      For AI := 0 To DllGroups[DI].Cnt - 1 Do
      Begin
        ImpIdx := DllGroups[DI].Idxs[AI];
        IatSlotOfs[ImpIdx] := CurOfs;
        CurOfs := CurOfs + 4;
      End;
      CurOfs := CurOfs + 4; { null terminator per DLL group }
    End;
    { Patch IAT fixups : chaque slot -> IatVA base + son offset }
    For I := 0 To BcFixupCnt - 1 Do
    Begin
      If BcFixups[I].Kind = BC_FIX_ABS32_IMP Then
      Begin
        FxOfs := BcFixups[I].CodeOfs;
        If FxOfs + 3 >= BcCodeLen Then Continue;
        Slot := BcFixups[I].Addend;
        If (Slot >= 0) And (Slot < BcImportCnt) Then
          ValIat := PE_IMG_BASE + IdataRVA + IatPerDll[0] + IatSlotOfs[Slot]
        Else
          ValIat := PE_IMG_BASE + IdataRVA + IatPerDll[0];
        { Trouver le bon IatPerDll pour ce slot }
        For DI := 0 To DllGrpCnt - 1 Do
          For AI := 0 To DllGroups[DI].Cnt - 1 Do
            If DllGroups[DI].Idxs[AI] = Slot Then
            Begin
              ValIat := PE_IMG_BASE + IdataRVA + IatPerDll[DI] + AI * 4;
            End;
        BcCode[FxOfs] := Byte(ValIat);
        BcCode[FxOfs + 1] := Byte(ValIat Shr 8);
        BcCode[FxOfs + 2] := Byte(ValIat Shr 16);
        BcCode[FxOfs + 3] := Byte(ValIat Shr 24);
      End;
    End;

  { ========== Ecrire le fichier PE ========== }
  Assign(PEBinF, FileName);
  Rewrite(PEBinF, 1);

  { ===== DOS MZ Header (64 octets) ===== }
  PEWrW($5A4D);         { e_magic = 'MZ' }
  PEWrW($0090);         { e_cblp }
  PEWrW($0003);         { e_cp }
  PEWrW($0000);         { e_crlc }
  PEWrW($0004);         { e_cparhdr }
  PEWrW($0000);         { e_minalloc }
  PEWrW($FFFF);         { e_maxalloc }
  PEWrW($0000);         { e_ss }
  PEWrW($00B8);         { e_sp }
  PEWrW($0000);         { e_csum }
  PEWrW($0000);         { e_ip }
  PEWrW($0000);         { e_cs }
  PEWrW($0040);         { e_lfarlc }
  PEWrW($0000);         { e_ovno }
  PEWrZeros(8);          { e_res[4] }
  PEWrW($0000);         { e_oemid }
  PEWrW($0000);         { e_oeminfo }
  PEWrZeros(20);         { e_res2[10] }
  PEWrD($00000080);     { e_lfanew -> PE header }

  { ===== DOS Stub ===== }
  PEWrB($0E); PEWrB($1F);             { PUSH CS / POP DS }
  PEWrB($BA); PEWrB($0E); PEWrB($00); { MOV DX, 000Eh }
  PEWrB($B4); PEWrB($09);             { MOV AH, 09h }
  PEWrB($CD); PEWrB($21);             { INT 21h }
  PEWrB($B8); PEWrB($01); PEWrB($4C); { MOV AX, 4C01h }
  PEWrB($CD); PEWrB($21);             { INT 21h }
  PEWrStr('This program cannot be run in DOS mode.');
  PEWrB($0D); PEWrB($0D); PEWrB($0A); PEWrB($24);
  PEPadTo($80);

  { ===== PE Signature ===== }
  PEWrD($00004550);     { 'PE\0\0' }

  { ===== COFF File Header (20 octets) ===== }
  PEWrW($014C);         { Machine = i386 }
  PEWrW(3);             { NumberOfSections }
  PEWrD(0);             { TimeDateStamp }
  PEWrD(0);             { PointerToSymbolTable }
  PEWrD(0);             { NumberOfSymbols }
  PEWrW(224);           { SizeOfOptionalHeader }
  PEWrW($0103);         { Characteristics: EXEC|32BIT|NO_RELOCS }

  { ===== Optional Header PE32 (224 octets) ===== }
  PEWrW($010B);         { Magic PE32 }
  PEWrB(1); PEWrB(0);   { Linker version }
  PEWrD(TextRawSize);   { SizeOfCode }
  PEWrD(DataRawSize + IdataRawSize); { SizeOfInitializedData }
  PEWrD(0);             { SizeOfUninitializedData }
  PEWrD(EntryPointRVA); { AddressOfEntryPoint = _TPF_Main }
  PEWrD(PE_TEXT_RVA);   { BaseOfCode }
  PEWrD(DataRVA);       { BaseOfData }
  PEWrD(PE_IMG_BASE);   { ImageBase }
  PEWrD(PE_SECT_ALIGN_); { SectionAlignment }
  PEWrD(PE_FILE_ALIGN_); { FileAlignment }
  PEWrW(4); PEWrW(0);   { OS version }
  PEWrW(0); PEWrW(0);   { Image version }
  PEWrW(4); PEWrW(0);   { Subsystem version }
  PEWrD(0);             { Win32VersionValue }
  PEWrD(ImageSize);     { SizeOfImage }
  PEWrD(PE_HDR_SIZE);   { SizeOfHeaders }
  PEWrD(0);             { CheckSum }
  PEWrW(3);             { Subsystem = CONSOLE }
  PEWrW(0);             { DllCharacteristics }
  PEWrD($100000);       { SizeOfStackReserve }
  PEWrD($1000);         { SizeOfStackCommit }
  PEWrD($100000);       { SizeOfHeapReserve }
  PEWrD($1000);         { SizeOfHeapCommit }
  PEWrD(0);             { LoaderFlags }
  PEWrD(16);            { NumberOfRvaAndSizes }

  { Data Directories (16 * 8 = 128 octets) }
  PEWrD(0); PEWrD(0);   { [0] Export }
  PEWrD(IdataRVA);       { [1] Import RVA }
  PEWrD(IdataVirtSize);  { [1] Import Size }
  PEWrD(0); PEWrD(0);   { [2] Resource }
  PEWrD(0); PEWrD(0);   { [3] Exception }
  PEWrD(0); PEWrD(0);   { [4] Security }
  PEWrD(0); PEWrD(0);   { [5] Base Reloc }
  PEWrD(0); PEWrD(0);   { [6] Debug }
  PEWrD(0); PEWrD(0);   { [7] Architecture }
  PEWrD(0); PEWrD(0);   { [8] Global Ptr }
  PEWrD(0); PEWrD(0);   { [9] TLS }
  PEWrD(0); PEWrD(0);   { [10] Load Config }
  PEWrD(0); PEWrD(0);   { [11] Bound Import }
  { [12] IAT - pointe vers la premiere table IAT }
  If DllGrpCnt > 0 Then
  Begin
    PEWrD(IdataRVA + IatPerDll[0]);
    { Taille totale du IAT }
    IATTotalSize := 0;
    For DI := 0 To DllGrpCnt - 1 Do
      IATTotalSize := IATTotalSize + (DllGroups[DI].Cnt + 1) * 4;
    PEWrD(IATTotalSize);
  End Else Begin PEWrD(0); PEWrD(0); End;
  PEWrD(0); PEWrD(0);   { [13] Delay Import }
  PEWrD(0); PEWrD(0);   { [14] CLR }
  PEWrD(0); PEWrD(0);   { [15] Reserved }

  { ===== Section Headers ===== }

  { .text }
  PEWrName8('.text');
  PEWrD(BcCodeLen);      { VirtualSize }
  PEWrD(PE_TEXT_RVA);    { VirtualAddress }
  PEWrD(TextRawSize);    { SizeOfRawData }
  PEWrD(PE_HDR_SIZE);    { PointerToRawData }
  PEWrD(0); PEWrD(0);   { Relocs, Linenums }
  PEWrW(0); PEWrW(0);   { NumRelocs, NumLinenums }
  PEWrD($60000020);     { CODE | MEM_EXECUTE | MEM_READ }

  { .data }
  PEWrName8('.data');
  PEWrD(BcDataLen);
  PEWrD(DataRVA);
  PEWrD(DataRawSize);
  PEWrD(PE_HDR_SIZE + TextRawSize);
  PEWrD(0); PEWrD(0);
  PEWrW(0); PEWrW(0);
  PEWrD(LongInt($C0000040)); { IDATA | MEM_READ | MEM_WRITE }

  { .idata }
  PEWrName8('.idata');
  PEWrD(IdataVirtSize);
  PEWrD(IdataRVA);
  PEWrD(IdataRawSize);
  PEWrD(PE_HDR_SIZE + TextRawSize + DataRawSize);
  PEWrD(0); PEWrD(0);
  PEWrW(0); PEWrW(0);
  PEWrD(LongInt($C0000040)); { IDATA | MEM_READ | MEM_WRITE }

  { Padding jusqu a FILE_ALIGN }
  PEPadTo(PE_HDR_SIZE);

  { ===== Section .text (code machine compile) ===== }
  For I := 0 To BcCodeLen - 1 Do PEWrB(BcCode[I]);
  PEPadTo(PE_HDR_SIZE + TextRawSize);

  { ===== Section .data (donnees globales) ===== }
  For I := 0 To BcDataLen - 1 Do PEWrB(BcData[I]);
  PEPadTo(PE_HDR_SIZE + TextRawSize + DataRawSize);

  { ===== Section .idata (Import Table) ===== }
  IdataFileBase := PE_HDR_SIZE + TextRawSize + DataRawSize;

  { --- IDT (Import Directory Table) --- }
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    PEWrD(IdataRVA + IltPerDll[DI]); { OriginalFirstThunk (ILT) }
    PEWrD(0);                         { TimeDateStamp }
    PEWrD(LongInt(-1));               { ForwarderChain = -1 }
    PEWrD(IdataRVA + DnmPerDll[DI]); { Name RVA }
    PEWrD(IdataRVA + IatPerDll[DI]); { FirstThunk (IAT) }
  End;
  PEWrZeros(20); { terminateur nul }

  { --- ILT (Import Lookup Table) per DLL --- }
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    PEPadTo(IdataFileBase + IltPerDll[DI]);
    For AI := 0 To DllGroups[DI].Cnt - 1 Do
    Begin
      ImpIdx := DllGroups[DI].Idxs[AI];
      PEWrD(IdataRVA + HntPerImp[ImpIdx]);
    End;
    PEWrD(0); { null terminator }
  End;

  { --- IAT (Import Address Table) per DLL - identique au ILT --- }
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    PEPadTo(IdataFileBase + IatPerDll[DI]);
    For AI := 0 To DllGroups[DI].Cnt - 1 Do
    Begin
      ImpIdx := DllGroups[DI].Idxs[AI];
      PEWrD(IdataRVA + HntPerImp[ImpIdx]);
    End;
    PEWrD(0); { null terminator }
  End;

  { --- Hint/Name Table --- }
  For DI := 0 To DllGrpCnt - 1 Do
    For AI := 0 To DllGroups[DI].Cnt - 1 Do
    Begin
      ImpIdx := DllGroups[DI].Idxs[AI];
      PEPadTo(IdataFileBase + HntPerImp[ImpIdx]);
      PEWrW(0);                              { Hint = 0 }
      PEWrStr(BcImports[ImpIdx].ApiName);    { Nom ASCIIZ }
      If Odd(FilePos(PEBinF)) Then PEWrB(0); { Aligner sur 2 }
    End;

  { --- DLL Name strings --- }
  For DI := 0 To DllGrpCnt - 1 Do
  Begin
    PEPadTo(IdataFileBase + DnmPerDll[DI]);
    PEWrStr(DllGroups[DI].DllName);
    If Odd(FilePos(PEBinF)) Then PEWrB(0);
  End;

  { Remplir le reste de la section }
  PEPadTo(IdataFileBase + IdataRawSize);

  If Opts.Verbose Then
    WriteLn('  PE genere : ', FileName, ' (',
            FilePos(PEBinF), ' octets, code=', BcCodeLen,
            ' data=', BcDataLen, ' imports=', BcImportCnt, ')');

  Close(PEBinF);
End;

{ --- WriteCOFFFile : generation d un fichier objet COFF --- }
Procedure WriteCOFFFile(FileName: TString);
Const
  COFF_TEXT_SIZE = 64;
  COFF_DATA_SIZE = 32;
  COFF_BSS_SIZE  = 256;
  NUM_SECTIONS   = 3;
  SECT_HDR_SIZE  = 40;
  FILE_HDR_SIZE  = 20;
Var
  SymTabOfs, StrTabOfs: LongInt;
  TextOfs, DataOfs: LongInt;
  NumSymbols: LongInt;
  NameOfs: LongInt;
  I: Integer;

  Procedure COFFWrName8(S: TString);
  Var J: Integer;
  Begin
    For J := 1 To 8 Do
      If J <= Length(S) Then PEWrB(Byte(S[J]))
      Else PEWrB(0);
  End;

Begin
  { Calculer les offsets }
  TextOfs := FILE_HDR_SIZE + NUM_SECTIONS * SECT_HDR_SIZE;
  DataOfs := TextOfs + COFF_TEXT_SIZE;
  SymTabOfs := DataOfs + COFF_DATA_SIZE;
  NumSymbols := 4; { .text, .data, .bss, _main }

  Assign(PEBinF, FileName);
  Rewrite(PEBinF, 1);

  { ===== COFF File Header (20 octets) ===== }
  PEWrW($014C);           { Machine = i386 }
  PEWrW(NUM_SECTIONS);    { NumberOfSections }
  PEWrD(0);               { TimeDateStamp }
  PEWrD(SymTabOfs);       { PointerToSymbolTable }
  PEWrD(NumSymbols);      { NumberOfSymbols }
  PEWrW(0);               { SizeOfOptionalHeader = 0 }
  PEWrW($0100);           { Characteristics: 32BIT }

  { ===== Section Headers ===== }

  { .text }
  COFFWrName8('.text');
  PEWrD(0);               { VirtualSize (0 for obj) }
  PEWrD(0);               { VirtualAddress (0 for obj) }
  PEWrD(COFF_TEXT_SIZE);  { SizeOfRawData }
  PEWrD(TextOfs);         { PointerToRawData }
  PEWrD(0);               { PointerToRelocations }
  PEWrD(0);               { PointerToLinenumbers }
  PEWrW(0);               { NumberOfRelocations }
  PEWrW(0);               { NumberOfLinenumbers }
  PEWrD($60000020);       { CODE | MEM_EXECUTE | MEM_READ }

  { .data }
  COFFWrName8('.data');
  PEWrD(0);
  PEWrD(0);
  PEWrD(COFF_DATA_SIZE);
  PEWrD(DataOfs);
  PEWrD(0); PEWrD(0);
  PEWrW(0); PEWrW(0);
  PEWrD(LongInt($C0000040));       { IDATA | MEM_READ | MEM_WRITE }

  { .bss }
  COFFWrName8('.bss');
  PEWrD(COFF_BSS_SIZE);  { VirtualSize }
  PEWrD(0);
  PEWrD(0);               { SizeOfRawData = 0 (uninitialized) }
  PEWrD(0);
  PEWrD(0); PEWrD(0);
  PEWrW(0); PEWrW(0);
  PEWrD(LongInt($C0000080));       { UDATA | MEM_READ | MEM_WRITE }

  { ===== Section .text raw data ===== }
  { PUSH EBP }
  PEWrB($55);
  { MOV EBP, ESP }
  PEWrB($89); PEWrB($E5);
  { PUSH 0 }
  PEWrB($6A); PEWrB($00);
  { INT 3 (placeholder - sera rempli par TODO 25) }
  PEWrB($CC);
  { MOV ESP, EBP }
  PEWrB($89); PEWrB($EC);
  { POP EBP }
  PEWrB($5D);
  { RET }
  PEWrB($C3);
  { Padding }
  For I := 1 To COFF_TEXT_SIZE - 10 Do PEWrB($90); { NOP }

  { ===== Section .data raw data ===== }
  { HSTDOUT DD 0, HSTDIN DD 0, HHEAP DD 0 }
  PEWrD(0); PEWrD(0); PEWrD(0);
  { Padding }
  For I := 1 To COFF_DATA_SIZE - 12 Do PEWrB(0);

  { ===== Symbol Table (18 octets par symbole) ===== }
  StrTabOfs := 4; { La string table commence apres sa taille }

  { Symbole 0: .text section }
  COFFWrName8('.text');
  PEWrD(0);               { Value }
  PEWrW(1);               { SectionNumber (1-based) }
  PEWrW(0);               { Type }
  PEWrB(3);               { StorageClass = IMAGE_SYM_CLASS_STATIC }
  PEWrB(0);               { NumberOfAuxSymbols }

  { Symbole 1: .data section }
  COFFWrName8('.data');
  PEWrD(0);
  PEWrW(2);
  PEWrW(0);
  PEWrB(3);               { STATIC }
  PEWrB(0);

  { Symbole 2: .bss section }
  COFFWrName8('.bss');
  PEWrD(0);
  PEWrW(3);
  PEWrW(0);
  PEWrB(3);               { STATIC }
  PEWrB(0);

  { Symbole 3: _main (public) }
  { Nom court: _main = 5 chars, fits in 8 bytes }
  NameOfs := 0; { unused, we use short name }
  COFFWrName8('_main');
  PEWrD(0);               { Value = offset 0 dans .text }
  PEWrW(1);               { SectionNumber = .text }
  PEWrW($20);             { Type = function }
  PEWrB(2);               { StorageClass = IMAGE_SYM_CLASS_EXTERNAL }
  PEWrB(0);

  { ===== String Table ===== }
  PEWrD(4);               { Taille de la string table (min = 4) }

  Close(PEBinF);

  If Opts.Verbose Then
    WriteLn('  COFF genere : ', FileName);
End;

{ --- EmitHeaderDos16 : en-tete ASM pour mode DOS 16 bits --- }
Procedure EmitHeaderDos16;
Begin
  EmitComment('TPCW32 - Compilateur Turbo Pascal -> ASM 8086 DOS');
  EmitComment('Mode DOS 16 bits - genere a partir de : ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('.8086');
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK 1024');
  EmitBlankLine;
End;

{ --- EmitDataSegDos16 : segment de donnees DOS 16 bits --- }
Procedure EmitDataSegDos16;
Var
  I, J : Integer;
  S    : TString;
  C    : Char;
Begin
  EmitComment('--- Segment de donnees DOS 16 bits ---');
  EmitRaw('.DATA');
  EmitBlankLine;
  EmitRaw('NUMBUF   DB 16 DUP(0)');
  EmitRaw('INBUF    DB 128 DUP(0)');
  EmitRaw('CRLF     DB 13,10,''$''');
  EmitRaw('STRTMP   DB 128 DUP(0)');
  EmitRaw('TRUE_STR DB ''TRUE'',''$''');
  EmitRaw('FALSE_STR DB ''FALSE'',''$''');
  EmitBlankLine;

  { Emettre les donnees utilisateur }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_STR: Begin
        S := '';
        J := 1;
        While J <= Length(DataTab[I].StrVal) Do
        Begin
          C := DataTab[I].StrVal[J];
          If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
          Begin
            If S <> '' Then S := S + ',';
            S := S + '''';
            While (J <= Length(DataTab[I].StrVal)) Do
            Begin
              C := DataTab[I].StrVal[J];
              If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
              Begin S := S + C; Inc(J) End
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
        EmitRaw(DataTab[I].LblName + ' DB ' + S);
      End;
      DK_DWORD: EmitRaw(DataTab[I].LblName + ' DW ' + IntToStr_(DataTab[I].IntVal));
      DK_BYTE: EmitRaw(DataTab[I].LblName + ' DB ' + IntToStr_(DataTab[I].IntVal));
      DK_ARRAY: Begin
        If DataTab[I].ElemSize = 1 Then
          EmitRaw(DataTab[I].LblName + ' DB ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + ' DB ' +
                  IntToStr_(DataTab[I].ElemCount * DataTab[I].ElemSize) +
                  ' DUP(0)');
      End;
      DK_RES: EmitRaw(DataTab[I].LblName + ' DB ' +
                       IntToStr_(DataTab[I].IntVal) + ' DUP(0)');
      DK_STRUCT: Begin
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + ' DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + ' DB 0');
      End;
    End;
  End;
  EmitBlankLine;
End;

{ --- EmitMainBlockDos16 : bloc principal DOS 16 bits --- }
Procedure EmitMainBlockDos16;
Begin
  EmitComment('--- Segment de code DOS 16 bits ---');
  EmitRaw('.CODE');
  EmitBlankLine;
  EmitLabel(TP_FUNC_PFX + 'Main');

  { Initialiser DS }
  EmitInstr('MOV AX,@DATA');
  EmitInstr('MOV DS,AX');
  EmitBlankLine;

  { TODO 25 : ici sera emis le corps du programme en 16 bits }
  EmitComment('Corps du programme (TODO 25)');

  { Sortie propre via INT 21h }
  EmitInstr('MOV AX,4C00h');
  EmitInstr('INT 21h');
  EmitBlankLine;

  EmitRaw('END ' + TP_FUNC_PFX + 'Main');
End;

{ ============================================================ }
{ TODO 26 - LECTURE DES FICHIERS TPU (USES)       [IMPLEMENTE] }
{ ============================================================ }

Function TPUVersionStr(V : Byte) : TString;
Begin
  Case V Of
    TPU_VER_TP4  : TPUVersionStr := '4.0';
    TPU_VER_TP5  : TPUVersionStr := '5.0';
    TPU_VER_TP55 : TPUVersionStr := '5.5';
    TPU_VER_TP6  : TPUVersionStr := '6.0';
    TPU_VER_TP7  : TPUVersionStr := '7.0';
  Else
    TPUVersionStr := 'inconnu';
  End;
End;

Function TPUSearchFile(Const UnitName : TString) : TString;
{ Search for .TPU file in current dir, UnitDirs, and TurboDir }
Var
  FName : TString;
  TF    : File;
  Dirs  : TString;
  P     : Integer;
  Dir   : TString;
  IORes : Integer;
Begin
  FName := UnitName + '.TPU';
  { 1. Current directory }
  {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
  If IORes = 0 Then Begin Close(TF); TPUSearchFile := FName; Exit End;
  { 2. UnitDirs (semicolon-separated) }
  Dirs := Opts.UnitDirs;
  While Length(Dirs) > 0 Do Begin
    P := Pos(';', Dirs);
    If P > 0 Then Begin Dir := Copy(Dirs, 1, P - 1); Dirs := Copy(Dirs, P + 1, Length(Dirs) - P) End
    Else Begin Dir := Dirs; Dirs := '' End;
    If Length(Dir) > 0 Then Begin
      If (Dir[Length(Dir)] <> '\') And (Dir[Length(Dir)] <> '/') Then Dir := Dir + '/';
      FName := Dir + UnitName + '.TPU';
      {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
      If IORes = 0 Then Begin Close(TF); TPUSearchFile := FName; Exit End;
    End;
  End;
  { 3. TurboDir }
  If Opts.TurboDir <> '' Then Begin
    Dir := Opts.TurboDir;
    If (Dir[Length(Dir)] <> '\') And (Dir[Length(Dir)] <> '/') Then Dir := Dir + '/';
    FName := Dir + UnitName + '.TPU';
    {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
    If IORes = 0 Then Begin Close(TF); TPUSearchFile := FName; Exit End;
  End;
  TPUSearchFile := '';
End;

Function LoadTPUHeader(Const FileName : TString; Var Ver : Byte;
                       Var UnitNameOut : TString; Var SymSize : Word;
                       Var OfsHashTable : Word;
                       Var OfsUnitList : Word;
                       Var OfsSrcName : Word) : Boolean;
{ Read and validate TPU header. Supports TP6 (TPU9) and TP7 (TPUQ).
  Extracts version, symbol size, key offsets.
  Reads unit name from ofs_this_unit obj_rec. }
Var
  TF    : File;
  Hdr   : Array[0..95] Of Byte; { max 0x60 bytes for TP7 }
  NRead : {$IFDEF FPC}LongInt{$ELSE}Word{$ENDIF};
  IORes : Integer;
  IsTP7 : Boolean;
  OfsThisUnit : Word;
  NameLen : Byte;
  NameBuf : Array[0..63] Of Byte;
  J     : Integer;
Begin
  LoadTPUHeader := False;
  Ver := 0; UnitNameOut := ''; SymSize := 0;
  OfsHashTable := 0; OfsUnitList := 0; OfsSrcName := 0;
  {$I-} Assign(TF, FileName); Reset(TF, 1); IORes := IOResult; {$I+}
  If IORes <> 0 Then Begin WarnMsg('impossible d''ouvrir: ' + FileName); Exit End;
  {$I-} BlockRead(TF, Hdr, 96, NRead); IORes := IOResult; {$I+}
  If (IORes <> 0) Or (NRead < TPU6_HDR_SIZE) Then
  Begin Close(TF); WarnMsg('fichier TPU trop court: ' + FileName); Exit End;
  { Check signature: T P U + version }
  If (Hdr[0] <> $54) Or (Hdr[1] <> $50) Or (Hdr[2] <> $55) Then
  Begin Close(TF); WarnMsg('fichier TPU invalide (signature): ' + FileName); Exit End;
  Ver := Hdr[3];
  IsTP7 := (Ver = TPU_VER_TP7);
  If (Ver <> TPU_VER_TP6) And (Ver <> TPU_VER_TP7) And
     (Ver <> TPU_VER_TP4) And (Ver <> TPU_VER_TP5) And
     (Ver <> TPU_VER_TP55) Then
  Begin Close(TF); WarnMsg('version TPU non supportee ($' + IntToStr_(Ver) + '): ' + FileName); Exit End;
  { Extract offsets from header (all words, little-endian) }
  OfsThisUnit := Hdr[$08] + Hdr[$09] * 256;
  OfsHashTable := Hdr[$0A] + Hdr[$0B] * 256;
  If IsTP7 Then Begin
    OfsUnitList := Hdr[$16] + Hdr[$17] * 256;
    OfsSrcName := Hdr[$18] + Hdr[$19] * 256;
    SymSize := Hdr[$1E] + Hdr[$1F] * 256;
  End Else Begin
    OfsUnitList := Hdr[$16] + Hdr[$17] * 256;
    OfsSrcName := Hdr[$18] + Hdr[$19] * 256;
    SymSize := Hdr[$1C] + Hdr[$1D] * 256;
  End;
  { Read unit name from ofs_this_unit: obj_rec = next_obj:word; obj_type:byte; name:string }
  If (OfsThisUnit > 0) And (OfsThisUnit + 4 < SymSize) Then
  Begin
    {$I-} Seek(TF, OfsThisUnit + 3); { skip next_obj(2) + obj_type(1) }
    BlockRead(TF, NameBuf, 64, NRead); IORes := IOResult; {$I+}
    If (IORes = 0) And (NRead > 0) Then
    Begin
      NameLen := NameBuf[0];
      If NameLen > 63 Then NameLen := 63;
      UnitNameOut := '';
      For J := 1 To NameLen Do
        UnitNameOut := UnitNameOut + Chr(NameBuf[J]);
    End;
  End;
  Close(TF);
  LoadTPUHeader := True;
End;

Function IsKnownUnit(Const UName : TString) : Boolean;
Var Up : TString;
Begin
  Up := StrUpperCase(UName);
  IsKnownUnit := (Up = 'SYSTEM') Or (Up = 'CRT') Or (Up = 'DOS') Or
    (Up = 'GRAPH') Or (Up = 'GRAPH3') Or (Up = 'STRINGS') Or
    (Up = 'OVERLAY') Or (Up = 'PRINTER') Or (Up = 'WINDOS') Or
    (Up = 'TURBO3') Or (Up = 'OBJECTS') Or
    (Up = 'MSGRUTIL') Or (Up = 'MSGRAPH') Or  { Quick Pascal units (TODO 29) }
    (Up = 'SANE') Or                           { Apple Pascal SANE unit       }
    ((Up = 'TRANSCEND') And Opts.ApplePascal And Not Opts.Sane);
                                               { Apple Pascal TRANSCEND unit  }
End;

Procedure MarkUnitSymbols(Const UName : TString);
{ Mark existing symbols in SymTab with their UnitName }
Var Up : TString; I : Integer;
  Procedure MarkIf(Const SName, UNm : TString);
  Var J : Integer;
  Begin
    For J := 0 To SymCount - 1 Do
      If SymTab[J].Name = SName Then SymTab[J].UnitName := UNm;
  End;
Begin
  Up := StrUpperCase(UName);
  If Up = 'CRT' Then
  Begin
    MarkIf('CLRSCR','CRT'); MarkIf('CLREOL','CRT'); MarkIf('GOTOXY','CRT');
    MarkIf('TEXTCOLOR','CRT'); MarkIf('TEXTBACKGROUND','CRT');
    MarkIf('HIGHVIDEO','CRT'); MarkIf('LOWVIDEO','CRT'); MarkIf('NORMVIDEO','CRT');
    MarkIf('WINDOW','CRT'); MarkIf('DELAY','CRT'); MarkIf('SOUND','CRT');
    MarkIf('NOSOUND','CRT'); MarkIf('ASSIGNCRT','CRT');
    MarkIf('WHEREX','CRT'); MarkIf('WHEREY','CRT');
    MarkIf('KEYPRESSED','CRT'); MarkIf('READKEY','CRT');
    MarkIf('INSLINE','CRT'); MarkIf('DELLINE','CRT'); MarkIf('TEXTMODE','CRT');
  End
  Else If Up = 'DOS' Then
  Begin
    MarkIf('DOSVERSION','DOS'); MarkIf('GETDATE','DOS'); MarkIf('GETTIME','DOS');
    MarkIf('SETDATE','DOS'); MarkIf('SETTIME','DOS');
    MarkIf('GETFATTR','DOS'); MarkIf('SETFATTR','DOS');
    MarkIf('FINDFIRST','DOS'); MarkIf('FINDNEXT','DOS'); MarkIf('FINDCLOSE','DOS');
    MarkIf('DISKFREE','DOS'); MarkIf('DISKSIZE','DOS'); MarkIf('GETENV','DOS');
    MarkIf('FSEARCH','DOS'); MarkIf('FEXPAND','DOS'); MarkIf('FSPLIT','DOS');
    MarkIf('EXEC','DOS'); MarkIf('SWAPVECTORS','DOS');
    MarkIf('GETINTVEC','DOS'); MarkIf('SETINTVEC','DOS');
    MarkIf('MSDOS','DOS'); MarkIf('INTR','DOS');
    MarkIf('GETCBREAK','DOS'); MarkIf('SETCBREAK','DOS');
    MarkIf('GETVERIFY','DOS'); MarkIf('SETVERIFY','DOS');
    MarkIf('GETFTIME','DOS'); MarkIf('SETFTIME','DOS');
    MarkIf('UNPACKTIME','DOS'); MarkIf('PACKTIME','DOS');
    MarkIf('ENVCOUNT','DOS'); MarkIf('ENVSTR','DOS');
    MarkIf('DOSEXITCODE','DOS'); MarkIf('KEEP','DOS');
  End
  Else If Up = 'GRAPH' Then
  Begin
    MarkIf('INITGRAPH','GRAPH'); MarkIf('CLOSEGRAPH','GRAPH'); MarkIf('DETECTGRAPH','GRAPH');
    MarkIf('PUTPIXEL','GRAPH'); MarkIf('LINE','GRAPH'); MarkIf('RECTANGLE','GRAPH');
    MarkIf('BAR','GRAPH'); MarkIf('BAR3D','GRAPH');
    MarkIf('CIRCLE','GRAPH'); MarkIf('ARC','GRAPH');
    MarkIf('ELLIPSE','GRAPH'); MarkIf('FILLELLIPSE','GRAPH');
    MarkIf('SETCOLOR','GRAPH'); MarkIf('SETBKCOLOR','GRAPH');
    MarkIf('OUTTEXTXY','GRAPH'); MarkIf('OUTTEXT','GRAPH');
    MarkIf('MOVETO','GRAPH'); MarkIf('MOVEREL','GRAPH');
    MarkIf('LINETO','GRAPH'); MarkIf('LINEREL','GRAPH');
    MarkIf('GETPIXEL','GRAPH'); MarkIf('GETMAXX','GRAPH'); MarkIf('GETMAXY','GRAPH');
    MarkIf('GETX','GRAPH'); MarkIf('GETY','GRAPH');
    MarkIf('GRAPHRESULT','GRAPH'); MarkIf('GRAPHERRORMSG','GRAPH');
    MarkIf('IMAGESIZE','GRAPH');
    MarkIf('GETIMAGE','GRAPH'); MarkIf('PUTIMAGE','GRAPH');
    MarkIf('GETMAXCOLOR','GRAPH'); MarkIf('GETCOLOR','GRAPH'); MarkIf('GETBKCOLOR','GRAPH');
    MarkIf('GETDRIVERNAME','GRAPH'); MarkIf('GETMODENAME','GRAPH'); MarkIf('GETMAXMODE','GRAPH');
    MarkIf('SETFILLSTYLE','GRAPH'); MarkIf('SETLINESTYLE','GRAPH');
    MarkIf('SETTEXTSTYLE','GRAPH'); MarkIf('SETVIEWPORT','GRAPH');
    MarkIf('CLEARDEVICE','GRAPH'); MarkIf('SETACTIVEPAGE','GRAPH'); MarkIf('SETVISUALPAGE','GRAPH');
    MarkIf('SETPALETTE','GRAPH'); MarkIf('SETRGBPALETTE','GRAPH');
    MarkIf('SETASPECTRATIO','GRAPH'); MarkIf('SETWRITEMODE','GRAPH');
    MarkIf('PIESLICE','GRAPH'); MarkIf('SECTOR','GRAPH'); MarkIf('FLOODFILL','GRAPH');
    MarkIf('INSTALLUSERDRIVER','GRAPH'); MarkIf('INSTALLUSERFONT','GRAPH');
    MarkIf('TEXTHEIGHT','GRAPH'); MarkIf('TEXTWIDTH','GRAPH');
    { Nouvelles fonctions/procedures Graph }
    MarkIf('REGISTERBGIDRIVER','GRAPH'); MarkIf('REGISTERBGIFONT','GRAPH');
    MarkIf('RESTORECRTMODE','GRAPH'); MarkIf('SETGRAPHMODE','GRAPH');
    MarkIf('GETGRAPHMODE','GRAPH'); MarkIf('GRAPHDEFAULTS','GRAPH');
    MarkIf('SETGRAPHBUFSIZE','GRAPH'); MarkIf('GETMODERANGE','GRAPH');
    MarkIf('DRAWPOLY','GRAPH'); MarkIf('FILLPOLY','GRAPH');
    MarkIf('SETFILLPATTERN','GRAPH'); MarkIf('SETALLPALETTE','GRAPH');
    MarkIf('GETPALETTE','GRAPH'); MarkIf('GETPALETTESIZE','GRAPH');
    MarkIf('GETDEFAULTPALETTE','GRAPH'); MarkIf('SETTEXTJUSTIFY','GRAPH');
    MarkIf('SETUSERCHARSIZE','GRAPH'); MarkIf('GETTEXTSETTINGS','GRAPH');
    MarkIf('GETLINESETTINGS','GRAPH'); MarkIf('GETFILLSETTINGS','GRAPH');
    MarkIf('GETFILLPATTERN','GRAPH'); MarkIf('GETVIEWSETTINGS','GRAPH');
    MarkIf('GETARCCOORDS','GRAPH'); MarkIf('GETASPECTRATIO','GRAPH');
    MarkIf('CLEARVIEWPORT','GRAPH');
  End
  Else If Up = 'STRINGS' Then
  Begin
    MarkIf('STRLEN','STRINGS'); MarkIf('STRCOPY','STRINGS');
    MarkIf('STRCAT','STRINGS'); MarkIf('STRCOMP','STRINGS');
    MarkIf('STRICOMP','STRINGS'); MarkIf('STRPOS','STRINGS');
    MarkIf('STRSCAN','STRINGS'); MarkIf('STRRSCAN','STRINGS');
    MarkIf('STREND','STRINGS'); MarkIf('STRMOVE','STRINGS');
    MarkIf('STRNEW','STRINGS'); MarkIf('STRPAS','STRINGS');
    MarkIf('STRPCOPY','STRINGS'); MarkIf('STRUPPER','STRINGS');
    MarkIf('STRLOWER','STRINGS'); MarkIf('STRDISPOSE','STRINGS');
  End
  Else If Up = 'PRINTER' Then
    MarkIf('ASSIGNLST','PRINTER')
  Else If Up = 'OVERLAY' Then
  Begin
    MarkIf('OVRINIT','OVERLAY'); MarkIf('OVRINITEMS','OVERLAY');
    MarkIf('OVRSETBUF','OVERLAY'); MarkIf('OVRCLEARBUF','OVERLAY');
    MarkIf('OVRSETRETRY','OVERLAY');
    MarkIf('OVRGETBUF','OVERLAY'); MarkIf('OVRGETRETURNCODE','OVERLAY');
  End
  Else If Up = 'OBJECTS' Then
  Begin
    MarkIf('TOBJECT_INIT','OBJECTS'); MarkIf('TOBJECT_DONE','OBJECTS');
    MarkIf('TOBJECT_FREE','OBJECTS');
    MarkIf('TSTREAM_GET','OBJECTS'); MarkIf('TSTREAM_GETPOS','OBJECTS');
    MarkIf('TSTREAM_GETSIZE','OBJECTS'); MarkIf('TSTREAM_READ','OBJECTS');
    MarkIf('TSTREAM_WRITE','OBJECTS');
    MarkIf('REGISTERTYPE','OBJECTS'); MarkIf('NEWSTR','OBJECTS');
    MarkIf('DISPOSESTR','OBJECTS');
  End
  Else If Up = 'MSGRAPH' Then
  Begin
    MarkIf('_GRSTATUS','MSGRAPH'); MarkIf('_SETVIDEOMODE','MSGRAPH');
    MarkIf('_SETVIDEOMODEROWS','MSGRAPH');
    MarkIf('_SETACTIVEPAGE','MSGRAPH'); MarkIf('_SETVISUALPAGE','MSGRAPH');
    MarkIf('_GETACTIVEPAGE','MSGRAPH'); MarkIf('_GETVISUALPAGE','MSGRAPH');
    MarkIf('_GETVIDEOCONFIG','MSGRAPH');
    MarkIf('_SETVIEWORG','MSGRAPH'); MarkIf('_SETVIEWPORT','MSGRAPH');
    MarkIf('_SETCLIPRGN','MSGRAPH'); MarkIf('_SETWINDOW','MSGRAPH');
    MarkIf('_GETVIEWCOORD','MSGRAPH'); MarkIf('_GETVIEWCOORD_W','MSGRAPH');
    MarkIf('_GETVIEWCOORD_WXY','MSGRAPH'); MarkIf('_GETPHYSCOORD','MSGRAPH');
    MarkIf('_GETWINDOWCOORD','MSGRAPH');
    MarkIf('_GETCURRENTPOSITION','MSGRAPH'); MarkIf('_GETCURRENTPOSITION_WXY','MSGRAPH');
    MarkIf('_CLEARSCREEN','MSGRAPH');
    MarkIf('_MOVETO','MSGRAPH'); MarkIf('_MOVETO_W','MSGRAPH');
    MarkIf('_LINETO','MSGRAPH'); MarkIf('_LINETO_W','MSGRAPH');
    MarkIf('_RECTANGLE','MSGRAPH'); MarkIf('_RECTANGLE_W','MSGRAPH');
    MarkIf('_RECTANGLE_WXY','MSGRAPH');
    MarkIf('_ELLIPSE','MSGRAPH'); MarkIf('_ELLIPSE_W','MSGRAPH');
    MarkIf('_ELLIPSE_WXY','MSGRAPH');
    MarkIf('_ARC','MSGRAPH'); MarkIf('_ARC_WXY','MSGRAPH');
    MarkIf('_PIE','MSGRAPH'); MarkIf('_PIE_WXY','MSGRAPH');
    MarkIf('_FLOODFILL','MSGRAPH'); MarkIf('_FLOODFILL_W','MSGRAPH');
    MarkIf('_GETARCINFO','MSGRAPH');
    MarkIf('_SETPIXEL','MSGRAPH'); MarkIf('_SETPIXEL_W','MSGRAPH');
    MarkIf('_GETPIXEL','MSGRAPH'); MarkIf('_GETPIXEL_W','MSGRAPH');
    MarkIf('_SETCOLOR','MSGRAPH'); MarkIf('_GETCOLOR','MSGRAPH');
    MarkIf('_SETLINESTYLE','MSGRAPH'); MarkIf('_GETLINESTYLE','MSGRAPH');
    MarkIf('_SETWRITEMODE','MSGRAPH'); MarkIf('_GETWRITEMODE','MSGRAPH');
    MarkIf('_SETFILLMASK','MSGRAPH'); MarkIf('_GETFILLMASK','MSGRAPH');
    MarkIf('_SETBKCOLOR','MSGRAPH'); MarkIf('_GETBKCOLOR','MSGRAPH');
    MarkIf('_REMAPPALETTE','MSGRAPH'); MarkIf('_REMAPALLPALETTE','MSGRAPH');
    MarkIf('_SELECTPALETTE','MSGRAPH');
    MarkIf('_SETTEXTROWS','MSGRAPH'); MarkIf('_SETTEXTWINDOW','MSGRAPH');
    MarkIf('_GETTEXTWINDOW','MSGRAPH'); MarkIf('_SCROLLTEXTWINDOW','MSGRAPH');
    MarkIf('_OUTMEM','MSGRAPH'); MarkIf('_OUTTEXT','MSGRAPH');
    MarkIf('_WRAPON','MSGRAPH'); MarkIf('_DISPLAYCURSOR','MSGRAPH');
    MarkIf('_SETTEXTCURSOR','MSGRAPH'); MarkIf('_GETTEXTCURSOR','MSGRAPH');
    MarkIf('_SETTEXTPOSITION','MSGRAPH'); MarkIf('_GETTEXTPOSITION','MSGRAPH');
    MarkIf('_SETTEXTCOLOR','MSGRAPH'); MarkIf('_GETTEXTCOLOR','MSGRAPH');
    MarkIf('_GETIMAGE','MSGRAPH'); MarkIf('_GETIMAGE_W','MSGRAPH');
    MarkIf('_GETIMAGE_WXY','MSGRAPH');
    MarkIf('_PUTIMAGE','MSGRAPH'); MarkIf('_PUTIMAGE_W','MSGRAPH');
    MarkIf('_IMAGESIZE','MSGRAPH'); MarkIf('_IMAGESIZE_W','MSGRAPH');
    MarkIf('_IMAGESIZE_WXY','MSGRAPH');
    MarkIf('_REGISTERFONTS','MSGRAPH'); MarkIf('_UNREGISTERFONTS','MSGRAPH');
    MarkIf('_SETFONT','MSGRAPH'); MarkIf('_OUTGTEXT','MSGRAPH');
    MarkIf('_GETGTEXTEXTENT','MSGRAPH'); MarkIf('_GETFONTINFO','MSGRAPH');
    MarkIf('_SETGTEXTVECTOR','MSGRAPH'); MarkIf('_GETGTEXTVECTOR','MSGRAPH');
  End
  Else If Up = 'SANE' Then
  Begin
    MarkIf('DECSTRLEN','SANE'); MarkIf('SIGDIGLEN','SANE');
    MarkIf('INVALID','SANE'); MarkIf('UNDERFLOW','SANE');
    MarkIf('OVERFLOW','SANE'); MarkIf('DIVBYZERO','SANE');
    MarkIf('INEXACT','SANE');
    MarkIf('NUM2INTEGER','SANE'); MarkIf('NUM2LONGINT','SANE');
    MarkIf('NUM2REAL','SANE'); MarkIf('NUM2DOUBLE','SANE');
    MarkIf('NUM2EXTENDED','SANE'); MarkIf('NUM2COMP','SANE');
    MarkIf('NUM2DEC','SANE'); MarkIf('DEC2NUM','SANE');
    MarkIf('NUM2STR','SANE'); MarkIf('STR2NUM','SANE');
    MarkIf('STR2DEC','SANE'); MarkIf('CSTR2DEC','SANE');
    MarkIf('DEC2STR','SANE');
    MarkIf('REMAINDER','SANE'); MarkIf('RINT','SANE');
    MarkIf('SCALB','SANE'); MarkIf('LOGB','SANE');
    MarkIf('COPYSIGN','SANE'); MarkIf('NEXTREAL','SANE');
    MarkIf('NEXTDOUBLE','SANE'); MarkIf('NEXTEXTENDED','SANE');
    MarkIf('LOG2','SANE'); MarkIf('LN1','SANE');
    MarkIf('EXP2','SANE'); MarkIf('EXP1','SANE');
    MarkIf('XPWRI','SANE'); MarkIf('XPWRY','SANE');
    MarkIf('COMPOUND','SANE'); MarkIf('ANNUITY','SANE');
    MarkIf('TAN','SANE'); MarkIf('RANDOMX','SANE');
    MarkIf('CLASSREAL','SANE'); MarkIf('CLASSDOUBLE','SANE');
    MarkIf('CLASSCOMP','SANE'); MarkIf('CLASSEXTENDED','SANE');
    MarkIf('SIGNNUM','SANE'); MarkIf('NAN','SANE');
    MarkIf('SETEXCEPTION','SANE'); MarkIf('TESTEXCEPTION','SANE');
    MarkIf('SETHALT','SANE'); MarkIf('TESTHALT','SANE');
    MarkIf('SETROUND','SANE'); MarkIf('GETROUND','SANE');
    MarkIf('SETPRECISION','SANE'); MarkIf('GETPRECISION','SANE');
    MarkIf('SETENVIRONMENT','SANE'); MarkIf('GETENVIRONMENT','SANE');
    MarkIf('PROCENTRY','SANE'); MarkIf('PROCEXIT','SANE');
    MarkIf('GETHALTVECTOR','SANE'); MarkIf('SETHALTVECTOR','SANE');
    MarkIf('RELATION','SANE');
  End
  Else If Up = 'TRANSCEND' Then
  Begin
    { TRANSCEND unit functions - mark standard builtins as TRANSCEND }
    MarkIf('ATAN','TRANSCEND');
    MarkIf('COS','TRANSCEND');
    MarkIf('LN','TRANSCEND');
    MarkIf('LOG','TRANSCEND');
    MarkIf('PWROFTEN','TRANSCEND');
    MarkIf('SIN','TRANSCEND');
    MarkIf('SQRT','TRANSCEND');
  End;
End;

{ ============================================================ }
{ TODO 29 - SUPPORT FORMAT QPU (QUICK PASCAL UNIT) [IMPLEMENTE] }
{ ============================================================ }

Function QPUSearchFile(Const UnitName : TString) : TString;
{ Search for .QPU file in current dir, UnitDirs, and TurboDir }
Var
  FName : TString;
  TF    : File;
  Dirs  : TString;
  P     : Integer;
  Dir   : TString;
  IORes : Integer;
Begin
  FName := UnitName + '.QPU';
  { 1. Current directory }
  {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
  If IORes = 0 Then Begin Close(TF); QPUSearchFile := FName; Exit End;
  { 2. UnitDirs (semicolon-separated) }
  Dirs := Opts.UnitDirs;
  While Length(Dirs) > 0 Do Begin
    P := Pos(';', Dirs);
    If P > 0 Then Begin Dir := Copy(Dirs, 1, P - 1); Dirs := Copy(Dirs, P + 1, Length(Dirs) - P) End
    Else Begin Dir := Dirs; Dirs := '' End;
    If Length(Dir) > 0 Then Begin
      If (Dir[Length(Dir)] <> '\') And (Dir[Length(Dir)] <> '/') Then Dir := Dir + '/';
      FName := Dir + UnitName + '.QPU';
      {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
      If IORes = 0 Then Begin Close(TF); QPUSearchFile := FName; Exit End;
    End;
  End;
  { 3. TurboDir }
  If Opts.TurboDir <> '' Then Begin
    Dir := Opts.TurboDir;
    If (Dir[Length(Dir)] <> '\') And (Dir[Length(Dir)] <> '/') Then Dir := Dir + '/';
    FName := Dir + UnitName + '.QPU';
    {$I-} Assign(TF, FName); Reset(TF, 1); IORes := IOResult; {$I+}
    If IORes = 0 Then Begin Close(TF); QPUSearchFile := FName; Exit End;
  End;
  QPUSearchFile := '';
End;

Function LoadQPUHeader(Const FileName : TString;
                       Var UnitNameOut : TString;
                       Var SymSize : Word;
                       Var CodeSize : Word;
                       Var FixupSize : Word;
                       Var DepCount : Word) : Boolean;
{ Read and validate QPU header (Quick Pascal Unit).
  Signature: "MSQP" (4D 53 51 50).
  Extracts unit name from the first entry in dependency table. }
Var
  TF    : File;
  Hdr   : Array[0..95] Of Byte;  { max header bytes to read }
  NRead : {$IFDEF FPC}LongInt{$ELSE}Word{$ENDIF};
  IORes : Integer;
  HdrSz : Word;
  DepOfs: Word;
  NameLen: Byte;
  J     : Integer;
Begin
  LoadQPUHeader := False;
  UnitNameOut := ''; SymSize := 0; CodeSize := 0; FixupSize := 0; DepCount := 0;
  {$I-} Assign(TF, FileName); Reset(TF, 1); IORes := IOResult; {$I+}
  If IORes <> 0 Then Begin WarnMsg('impossible d''ouvrir: ' + FileName); Exit End;
  {$I-} BlockRead(TF, Hdr, 96, NRead); IORes := IOResult; {$I+}
  If (IORes <> 0) Or (NRead < QPU_HDR_FIXED) Then
  Begin Close(TF); WarnMsg('fichier QPU trop court: ' + FileName); Exit End;
  { Check signature: M S Q P }
  If (Hdr[0] <> QPU_MAGIC_0) Or (Hdr[1] <> QPU_MAGIC_1) Or
     (Hdr[2] <> QPU_MAGIC_2) Or (Hdr[3] <> QPU_MAGIC_3) Then
  Begin Close(TF); WarnMsg('fichier QPU invalide (signature): ' + FileName); Exit End;
  { Extract header fields (all words, little-endian) }
  DepCount := Hdr[$0A] + Hdr[$0B] * 256;
  HdrSz    := Hdr[$0C] + Hdr[$0D] * 256;
  SymSize  := Hdr[$0E] + Hdr[$0F] * 256;
  CodeSize := Hdr[$12] + Hdr[$13] * 256;
  FixupSize:= Hdr[$14] + Hdr[$15] * 256;
  { Read unit name from first entry in dependency table at offset 0x20 }
  { Format: Hash(2) + Flags(1) + NameLen(1) + Name(N) }
  DepOfs := QPU_HDR_FIXED;  { 0x20 }
  If (DepOfs + 4 < NRead) Then
  Begin
    { Skip Hash(2) + Flags(1), read NameLen }
    NameLen := Hdr[DepOfs + 3];
    If NameLen > 63 Then NameLen := 63;
    UnitNameOut := '';
    For J := 0 To NameLen - 1 Do
    Begin
      If (DepOfs + 4 + J) < NRead Then
        UnitNameOut := UnitNameOut + Chr(Hdr[DepOfs + 4 + J]);
    End;
  End;
  Close(TF);
  LoadQPUHeader := True;
End;

Procedure ParseUsesClause;
Var
  I, SI      : Integer;
  Up, UName  : TString;
  InUses     : Boolean;
  TPUPath    : TString;
  TPUVer     : Byte;
  TPUUName   : TString;
  TPUSymSz   : Word;
  TPUHash    : Word;
  TPUUList   : Word;
  TPUSrc     : Word;
  QPUPath    : TString;              { chemin du fichier QPU (TODO 29) }
  QPUUName   : TString;              { nom d unite extrait du QPU      }
  QPUSymSz   : Word;                 { taille symboles QPU             }
  QPUCodeSz  : Word;                 { taille code QPU                 }
  QPUFixSz   : Word;                 { taille fixup QPU                }
  QPUDeps    : Word;                 { nombre de dependances QPU       }
Begin
  UsesCount := 0;
  IsUnitSource := False;
  UnitSourceName := '';
  For I := 0 To MAX_USES_UNITS - 1 Do
  Begin
    UsesUnits[I].Name := ''; UsesUnits[I].FileName := '';
    UsesUnits[I].Version := 0; UsesUnits[I].Loaded := False;
    UsesUnits[I].IsKnown := False; UsesUnits[I].IsQPU := False;
  End;
  InUses := False;
  I := 0;
  While I < TokenCount Do
  Begin
    { Detecter UNIT : le source est une unite (TODO 27) }
    If (TokenPool[I].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[I].Val) = 'UNIT') Then
    Begin
      IsUnitSource := True;
      Inc(I);
      If (I < TokenCount) And
         ((TokenPool[I].Kind = TK_IDENT) Or (TokenPool[I].Kind = TK_KEYWORD)) Then
      Begin
        UnitSourceName := StrUpperCase(TokenPool[I].Val);
        Inc(I);
      End;
      While (I < TokenCount) And Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do Inc(I);
      If I < TokenCount Then Inc(I);
      If Opts.Verbose Then
        WriteLn('  Source unite : ', UnitSourceName);
      Continue;
    End;
    If (TokenPool[I].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[I].Val) = 'PROGRAM') Then
    Begin
      Inc(I);
      While (I < TokenCount) And Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do Inc(I);
      If I < TokenCount Then Inc(I);
      Continue;
    End;
    { Clause USES : verifier que la version TP >= 4 (TODO 27) }
    If (TokenPool[I].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[I].Val) = 'USES') Then
    Begin
      If Not TPVersionAtLeast(TP_VER_4) Then
      Begin
        WarnMsg('la clause Uses n''est pas disponible avant Turbo Pascal 4.0 (version courante: ' + TPVersionStr(Opts.TPVersion) + ')');
        { Sauter la clause Uses sans la traiter }
        Inc(I);
        While (I < TokenCount) And Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do Inc(I);
        If I < TokenCount Then Inc(I);
        Continue;
      End;
      InUses := True; Inc(I);
      While (I < TokenCount) And InUses Do
      Begin
        If (TokenPool[I].Kind = TK_IDENT) Or (TokenPool[I].Kind = TK_KEYWORD) Then
        Begin
          UName := StrUpperCase(TokenPool[I].Val);
          If UsesCount >= MAX_USES_UNITS Then Begin WarnMsg('trop d''unites Uses (max=' + IntToStr_(MAX_USES_UNITS) + ')'); Break End;
          UsesUnits[UsesCount].Name := UName;
          UsesUnits[UsesCount].IsKnown := IsKnownUnit(UName);
          SI := SymAdd(UName, SK_UNIT, -1);
          If SI >= 0 Then
          Begin SymTab[SI].IsGlobal := True; SymTab[SI].IsExternal := True; SymTab[SI].UnitName := UName End;
          If UsesUnits[UsesCount].IsKnown Then MarkUnitSymbols(UName);
          If Opts.Dos16Mode Then
          Begin
            TPUPath := TPUSearchFile(UName);
            If TPUPath <> '' Then
            Begin
              UsesUnits[UsesCount].FileName := TPUPath;
              If LoadTPUHeader(TPUPath, TPUVer, TPUUName, TPUSymSz, TPUHash, TPUUList, TPUSrc) Then
              Begin
                UsesUnits[UsesCount].Version := TPUVer;
                UsesUnits[UsesCount].Loaded := True;
                If Opts.Verbose Then
                  WriteLn('  TPU charge: ', UName, ' (', TPUPath, ', v', TPUVersionStr(TPUVer),
                          ', sym=', TPUSymSz, ', nom=', TPUUName, ')');
              End;
            End
            Else Begin
              { TPU introuvable : tenter QPU (Quick Pascal) (TODO 29) }
              QPUPath := QPUSearchFile(UName);
              If QPUPath <> '' Then
              Begin
                UsesUnits[UsesCount].FileName := QPUPath;
                If LoadQPUHeader(QPUPath, QPUUName, QPUSymSz, QPUCodeSz, QPUFixSz, QPUDeps) Then
                Begin
                  UsesUnits[UsesCount].Loaded := True;
                  UsesUnits[UsesCount].IsQPU := True;
                  If Opts.Verbose Then
                    WriteLn('  QPU charge: ', UName, ' (', QPUPath,
                            ', sym=', QPUSymSz, ', code=', QPUCodeSz,
                            ', deps=', QPUDeps, ', nom=', QPUUName, ')');
                End;
              End
              Else If Not UsesUnits[UsesCount].IsKnown Then
                WarnMsg('fichier TPU/QPU introuvable: ' + UName);
            End;
          End;
          Inc(UsesCount); Inc(I);
          If I < TokenCount Then
          Begin
            If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ',') Then Inc(I)
            Else If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';') Then Begin Inc(I); InUses := False End
            Else InUses := False;
          End;
        End
        Else InUses := False;
      End;
      Break;
    End;
    If (TokenPool[I].Kind = TK_KEYWORD) Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);
      If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'PROCEDURE') Or
         (Up = 'FUNCTION') Or (Up = 'BEGIN') Or (Up = 'LABEL') Or
         (Up = 'SEGMENT') Then Break;
    End;
    Inc(I);
  End;
  If Opts.Verbose And (UsesCount > 0) Then
  Begin
    Write('  Uses: ');
    For I := 0 To UsesCount - 1 Do
    Begin
      If I > 0 Then Write(', ');
      Write(UsesUnits[I].Name);
      If UsesUnits[I].Loaded Then
      Begin
        If UsesUnits[I].IsQPU Then
          Write(' [QPU]')
        Else
          Write(' [TPU v', TPUVersionStr(UsesUnits[I].Version), ']');
      End;
    End;
    WriteLn;
  End;
End;

Procedure Run;
Begin
  ShowBanner;

  { Ouvrir le fichier source }
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Initialiser le pool de donnees et le pool de tokens (TODO 04) }
  DataInit;
  TokenPoolInit;

  { Initialiser la table des symboles (TODO 05) }
  SymInit;

  { Initialiser le systeme de types (TODO 06) }
  TypeInit;

  { Enregistrer le type SearchRec apres TypeInit (TypeAdd disponible) }
  RegisterSearchRecType;

  { Enregistrer le type DateTime apres TypeInit }
  RegisterDateTimeType;

  { Enregistrer le type _VideoConfig de MSGraph }
  RegisterVideoConfigType;

  { Initialiser le preprocesseur }
  PPInitDefines;

  { Initialiser le lexeur et scanner les tokens dans le pool }
  LexInit;
  Repeat
    LexNextToken;
    If CurToken.Kind <> TK_EOF Then
      TokenPoolAdd(CurToken);
  Until CurToken.Kind = TK_EOF;

  { Enregistrer toutes les chaines dans le pool de donnees }
  TokenPoolRegisterStrings;

  If Opts.Verbose Then
    WriteLn('  Tokens: ', TokenCount, '  Donnees: ', DataCount,
            '  Symboles: ', SymCount, '  Types: ', TypeCount);

  { Initialiser les variables de l emetteur (TODO 07) }
  HasProgram := False;
  IsUnitSource := False;
  UnitSourceName := '';
  DataEmittedCount := 0;
  EmitLabelSeq := 0;
  StaticVarSeq := 0;

  { Analyser la clause Uses (TODO 26) }
  ParseUsesClause;

  { Si c est une unite, ajuster le fichier de sortie en .TPU (TODO 27) }
  If IsUnitSource Then
  Begin
    If Opts.Verbose Then
      WriteLn('  Mode unite : pas de generation d''executable');
    { Si le fichier de sortie est .exe, le changer en .tpu }
    If StrUpperCase(ExtractExt(Opts.OutFile)) = '.EXE' Then
      Opts.OutFile := ReplaceExt(Opts.OutFile, '.tpu');
  End;

  { Analyser les declarations TYPE (TODO 15) }
  ParseTypeDecls;

  { Analyser les declarations globales VAR et CONST (TODO 08) }
  ParseDataDecls;

  If Opts.Verbose Then
    WriteLn('  Apres ParseDataDecls: Donnees=', DataCount,
            '  Symboles=', SymCount);

  { Analyser les declarations PROCEDURE et FUNCTION (TODO 09) }
  ParseProcDecls;

  If Opts.Verbose Then
    WriteLn('  Apres ParseProcDecls: Procedures=', ProcCount,
            '  Symboles=', SymCount);

  { Generation du code Win32 : pipeline d emission (texte ASM + binaire PE) }
  { La pipeline s execute si -asm est demande OU si un PE doit etre genere }
  If (Not Opts.Dos16Mode) And
     (Opts.AsmOutput Or ((Not Opts.ObjOnly) And (Not IsUnitSource))) Then
  Begin
    { Initialiser la generation binaire si un PE est requis }
    If (Not Opts.ObjOnly) And (Not IsUnitSource) Then
    Begin
      BcInit;
      BcActive := True;
    End;

    { Ouvrir le fichier ASM texte si demande (TODO 07) }
    If Opts.AsmOutput Then
      EmitOpen(ReplaceExt(Opts.OutFile, '.asm'));

    EmitHeader;
    EmitDataSeg;
    EmitCodeSeg;

    { Emettre les procedures et fonctions (TODO 09) }
    EmitProcedures;

    { Emettre le bloc principal (TODO 09) - seulement pour les programmes }
    If Not IsUnitSource Then
      EmitMainBlock;

    { Emettre les routines runtime (TODO 12) }
    If (Opts.DestTarget = DEST_DOSR) Or (Opts.DestTarget = DEST_DOSP) Then
      EmitRuntimeDOS
    Else
      EmitRuntime;

    { Emettre les routines runtime supplementaires (pas en mode DOS) }
    If (Opts.DestTarget <> DEST_DOSR) And (Opts.DestTarget <> DEST_DOSP) Then
    Begin
      { Emettre les routines runtime Graph (TODO 20) }
      EmitGraphRuntime;

      { Emettre les routines runtime Strings/Overlay (TODO 21) }
      EmitStringsRuntime;

      { Emettre les routines runtime Objects (TODO 21) }
      EmitObjectsRuntime;

      { Emettre les routines runtime Mem/Port (TODO 22) }
      EmitMemPortRuntime;

      { Emettre les routines runtime interruptions (TODO 23) }
      EmitIntrRuntime;
    End;

    If Opts.AsmOutput Then
    Begin
      EmitClose;
      If Opts.Verbose Then
        WriteLn('  ASM genere : ', ReplaceExt(Opts.OutFile, '.asm'));
    End;

    BcActive := False;
  End;

  { Generation du fichier .ASM DOS 16 bits si -dos16 et -asm (TODO 24) }
  If Opts.Dos16Mode And Opts.AsmOutput Then
  Begin
    EmitOpen(ReplaceExt(Opts.OutFile, '.asm'));
    EmitHeaderDos16;
    EmitDataSegDos16;
    { Emettre le bloc principal seulement pour les programmes (TODO 27) }
    If Not IsUnitSource Then
      EmitMainBlockDos16;
    { Note: EmitClose n est pas appele car EmitMainBlockDos16 ecrit END }
    If OutFOpen Then Begin Close(OutF); OutFOpen := False End;
    If Opts.Verbose Then
      WriteLn('  ASM DOS 16 bits genere : ', ReplaceExt(Opts.OutFile, '.asm'));
  End;

  { Generation du fichier PE (TODO 24) - seulement pour les programmes (TODO 27) }
  If (Not Opts.ObjOnly) And (Not Opts.Dos16Mode) And (Not IsUnitSource) Then
  Begin
    BcBuildData;  { Apres toute emission pour capturer tous les DataTab }
    If (Opts.DestTarget = DEST_DOSR) Or (Opts.DestTarget = DEST_DOSP) Then
    Begin
      WriteMZFile(Opts.OutFile);
      If Opts.Verbose Then
        WriteLn('  MZ DOS EXE genere : ', Opts.OutFile);
    End
    Else
    Begin
      WritePEFile(Opts.OutFile);
      If Opts.Verbose Then
        WriteLn('  PE Win32 genere : ', Opts.OutFile);
    End;
  End;

  { Generation du fichier COFF pour les unites Win32 (TODO 27) }
  If (Not Opts.Dos16Mode) And IsUnitSource Then
  Begin
    WriteCOFFFile(ReplaceExt(Opts.OutFile, '.obj'));
    If Opts.Verbose Then
      WriteLn('  Unite COFF OBJ genere : ', ReplaceExt(Opts.OutFile, '.obj'));
  End;

  { Generation du fichier COFF (TODO 24) }
  If Opts.ObjOnly And (Not IsUnitSource) Then
  Begin
    WriteCOFFFile(Opts.OutFile);
    If Opts.Verbose Then
      WriteLn('  COFF OBJ genere : ', Opts.OutFile);
  End;

  { Generation du fichier TPU pour les unites DOS 16 bits (TODO 27) }
  If Opts.Dos16Mode And IsUnitSource Then
  Begin
    If Opts.Verbose Then
      WriteLn('  Unite TPU genere : ', Opts.OutFile);
  End;

  LexClose;
  ShowStats;
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                          }
{ ============================================================ }

BEGIN
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  ParseArgs;
  Run;
  Cleanup;
  Halt(EXIT_OK);
END.
