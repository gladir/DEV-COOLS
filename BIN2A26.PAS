{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2, Turbo Pascal 7)
  @description: BIN2A26.PAS - Convertisseur ROM Atari 2600 : .BIN -> .A26

}

{**************************************************************************
 * Convertit un fichier ROM brut (.BIN) au format .A26 utilise par les    *
 * emulateurs Atari 2600 (Stella, z26, etc.).                             *
 *                                                                        *
 * Le format .A26 est compose d'une en-tete de 16 octets suivie des       *
 * donnees brutes de la ROM :                                             *
 *                                                                        *
 *   Offset  Taille  Description                                          *
 *   ------  ------  -----------                                          *
 *     0       4     Signature : 'A26' + $1A (marqueur binaire)           *
 *     4       4     Taille de la ROM en octets (little-endian)           *
 *     8       1     Type de bancswitching detecte                        *
 *     9       1     Drapeaux (reserve, $00)                              *
 *    10       6     Reserve (zeros)                                      *
 *    16       N     Donnees brutes de la ROM (N = taille de la ROM)      *
 *                                                                        *
 * Types de bancswitching Atari 2600 :                                    *
 *   $00 = Aucun    (2Ko/4Ko)                                             *
 *   $01 = F8       (8Ko)                                                 *
 *   $02 = FA/CBS   (12Ko)                                                *
 *   $03 = F6       (16Ko)                                                *
 *   $04 = F4       (32Ko)                                                *
 *   $05 = EF/BF    (64Ko)                                                *
 *   $06 = DF/SB    (128Ko)                                               *
 *   $FF = Inconnu  (taille non standard)                                 *
 *                                                                        *
 * Compilation :                                                          *
 *   Free Pascal : fpc BIN2A26.PAS                                        *
 *   Turbo Pascal : tpc BIN2A26.PAS                                       *
 *                                                                        *
 * Usage : BIN2A26 <source.bin> [destination.a26]                         *
 *                                                                        *
 * Auteur  : Sylvain Maltais                                              *
 * Version : 1.0                                                          *
 **************************************************************************}

{$IFDEF FPC}
  {$MODE OBJFPC}
  {$H+}              { Strings longues }
{$ENDIF}

Program BIN2A26;

{---------------------------------------------------------------------------}
{ Constantes                                                                }
{---------------------------------------------------------------------------}

const
  VERSION = '1.0';

  { Taille fixe de l'en-tete A26 }
  TAILLE_ENTETE = 16;

  { Taille maximale du tampon de ROM (128 Ko) }
  TAILLE_ROM_MAX = 131072;
  TAILLE_BLOC_ROM = 16384;
  NB_BLOCS_ROM = 8;

  { Codes de bancswitching }
  BANC_AUCUN   = $00;   { 2Ko / 4Ko }
  BANC_F8      = $01;   { 8Ko  }
  BANC_FA      = $02;   { 12Ko - CBS }
  BANC_F6      = $03;   { 16Ko }
  BANC_F4      = $04;   { 32Ko }
  BANC_EF      = $05;   { 64Ko }
  BANC_DF      = $06;   { 128Ko / Superchip }
  BANC_INCONNU = $FF;   { Non reconnu }

  { Tailles de ROM Atari 2600 valides }
  NB_TAILLES           = 8;
  TAILLES_VALIDES      : array[1..NB_TAILLES] of LongInt = (
    2048, 4096, 8192, 12288, 16384, 32768, 65536, 131072
  );

{---------------------------------------------------------------------------}
{ Types                                                                     }
{---------------------------------------------------------------------------}

Type
  PByte = ^Byte;

  TROMBuffers = array[0..NB_BLOCS_ROM - 1] of PByte;
  TTailleBuffers = array[0..NB_BLOCS_ROM - 1] of Integer;

  { En-tete du format .A26 (16 octets) }
  TA26Header = packed record
   Signature  : array[0..3] of Byte;   { 'A', '2', '6', $1A }
   TailleROM  : {$IFDEF FPC}LongWord{$ELSE}LongInt{$ENDIF};              { Taille en octets, little-endian  }
   BancSwitch : Byte;                  { Type de bancswitching            }
   Flags      : Byte;                  { Drapeaux (reserve)               }
   Reserve    : array[0..5] of Byte;   { Rembourrage, initialise a zero   }
  End;

{---------------------------------------------------------------------------}
{ Fonctions utilitaires                                                     }
{---------------------------------------------------------------------------}

Function DetecterBancSwitch(Taille: LongInt):Byte;Begin
 If (Taille = 2048) Or (Taille = 4096) Then
  DetecterBancSwitch := BANC_AUCUN
 Else If Taille = 8192 Then
  DetecterBancSwitch := BANC_F8
 Else If Taille = 12288 Then
  DetecterBancSwitch := BANC_FA
 Else If Taille = 16384 Then
  DetecterBancSwitch := BANC_F6
 Else If Taille = 32768 Then
  DetecterBancSwitch := BANC_F4
 Else If Taille = 65536 Then
  DetecterBancSwitch := BANC_EF
 Else If Taille = 131072 Then
  DetecterBancSwitch := BANC_DF
 Else
  DetecterBancSwitch := BANC_INCONNU;
End;

Function NomBancSwitch(Code:Byte):String;Begin
 Case Code of
  BANC_AUCUN   : NomBancSwitch := 'Aucun (2Ko/4Ko standard)';
  BANC_F8      : NomBancSwitch := 'F8  (8Ko)';
  BANC_FA      : NomBancSwitch := 'FA  (12Ko - CBS)';
  BANC_F6      : NomBancSwitch := 'F6  (16Ko)';
  BANC_F4      : NomBancSwitch := 'F4  (32Ko)';
  BANC_EF      : NomBancSwitch := 'EF/BF  (64Ko)';
  BANC_DF      : NomBancSwitch := 'DF/Superchip  (128Ko)';
  BANC_INCONNU : NomBancSwitch := 'Inconnu (taille non standard)';
  Else NomBancSwitch := 'Non defini';
 End;
End;

Function TailleValide(Taille:LongInt):Boolean;
Var
  i:Integer;
Begin
 TailleValide := False;
 For i:=1 to NB_TAILLES do If TAILLES_VALIDES[i] = Taille Then Begin
  TailleValide := True;
  Exit;
 End;
End;

Function FileExists(Const NomFichier:String):Boolean;
Var
 FichierTest : file;
 CodeErreur  : Integer;
Begin
 Assign(FichierTest, NomFichier);
 {$I-}
 Reset(FichierTest, 1);
 CodeErreur := IOResult;
 {$I+}
 FileExists := CodeErreur = 0;
 If CodeErreur = 0 Then Close(FichierTest);
End;

Function ChangeFileExt(Const NomFichier, NouvelleExtension:String):String;
Var
 i           : Integer;
 DernierSep : Integer;
 DernierPoint : Integer;
Begin
 DernierSep := 0;
 DernierPoint := 0;
 For i := 1 To Length(NomFichier) Do Begin
  If (NomFichier[i] = '\\') Or (NomFichier[i] = '/') Then DernierSep := i;
  If NomFichier[i] = '.' Then DernierPoint := i;
 End;
 If DernierPoint > DernierSep Then
  ChangeFileExt := Copy(NomFichier, 1, DernierPoint - 1) + NouvelleExtension
 Else
  ChangeFileExt := NomFichier + NouvelleExtension;
End;

Procedure AfficheAide;Begin
 WriteLn('BIN2A26 : Cette commande permet de convertir la ROM Atari 2600 de ',
         'format de fichier avec l''extension ".BIN" vers ".A26".');
 WriteLn;
 WriteLn('Syntaxe: BIN2A26 <source.bin> [destination.a26]');
 WriteLn;
 WriteLn('  source.bin       ROM Atari 2600 en format binaire brut (.BIN)');
 WriteLn('  destination.a26  Fichier de sortie (optionnel)');
 WriteLn('                   Par defaut : meme nom avec extension .A26');
 WriteLn;
 WriteLn('Tailles de ROM Atari 2600 reconnues :');
 WriteLn('  2Ko  4Ko  8Ko  12Ko  16Ko  32Ko  64Ko  128Ko');
 WriteLn;
 WriteLn('Codes de sortie :');
 WriteLn('  0 = Succes');
 WriteLn('  1 = Parametres invalides');
 WriteLn('  2 = Fichier source introuvable');
 WriteLn('  3 = Impossible d''ouvrir le fichier source');
 WriteLn('  4 = Fichier source vide');
 WriteLn('  5 = Erreur de lecture');
 WriteLn('  6 = Impossible de creer le fichier de destination');
End;

{---------------------------------------------------------------------------}
{ Programme principal                                                       }
{---------------------------------------------------------------------------}

Var
 FichierSrc  : file;
 FichierDst  : file;
  DonneeROM   : TROMBuffers;
  TailleBloc  : TTailleBuffers;
 Entete      : TA26Header;
 TailleROM   : LongInt;
 NomSrc      : string;
 NomDst      : string;
 OctetsLus   : {$IFDEF FPC}SizeInt{$ELSE}Integer{$ENDIF};
 CodeBanc    : Byte;
 i           : Integer;
  NbBlocs     : Integer;
  IndexBloc   : Integer;
  OctetsBloc  : Integer;
  LectureComplete : Boolean;

Procedure LibererDonneeROM;
Var
  IndexLiberation : Integer;
Begin
 For IndexLiberation := 0 To NB_BLOCS_ROM - 1 Do
  If DonneeROM[IndexLiberation] <> Nil Then Begin
   FreeMem(DonneeROM[IndexLiberation], TailleBloc[IndexLiberation]);
   DonneeROM[IndexLiberation] := Nil;
   TailleBloc[IndexLiberation] := 0;
  End;
End;

BEGIN
  { --- Traitement des arguments de la ligne de commande --- }
 If ParamCount < 1 Then Begin
  WriteLn('Erreur : aucun fichier source specifie.');
  AfficheAide;
  Halt(1);
 End;
 NomSrc := ParamStr(1);
 If(NomSrc = '-h') or (NomSrc = '--help') or (NomSrc = '/?')Then Begin
  AfficheAide;
  Halt(0);
 End;
 If ParamCount >= 2 Then NomDst := ParamStr(2)
                    Else NomDst := ChangeFileExt(NomSrc, '.a26');
  { --- Ouverture et lecture du fichier source --- }
 If not FileExists(NomSrc) Then Begin
  WriteLn('Erreur : fichier source introuvable : ', NomSrc);
  Halt(2);
 End;
 Assign(FichierSrc, NomSrc);
 {$I-}
 Reset(FichierSrc, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir : ', NomSrc);
  Halt(3);
 End;
 TailleROM := {$IFDEF FPC}FileSize(FichierSrc){$ELSE}System.FileSize(FichierSrc){$ENDIF};
 If TailleROM = 0 Then Begin
  Close(FichierSrc);
  WriteLn('Erreur : le fichier source est vide.');
  Halt(4);
 End;
 If TailleROM > TAILLE_ROM_MAX Then Begin
  Close(FichierSrc);
  WriteLn('Erreur : le fichier source depasse 128 Ko.');
  Halt(4);
 End;
 CodeBanc := DetecterBancSwitch(TailleROM);
  { Affichage des informations detectees }
 WriteLn('Source         : ', NomSrc);
 WriteLn('Taille ROM     : ', TailleROM, ' octets (', TailleROM div 1024, ' Ko)');
 WriteLn('Bancswitching  : ', NomBancSwitch(CodeBanc));
 WriteLn('Destination    : ', NomDst);
 WriteLn;

 If not TailleValide(TailleROM) Then
  WriteLn('Attention : taille non standard pour une ROM Atari 2600 !');

  { Allocation dans le tas par blocs compatibles Turbo Pascal }
 FillChar(DonneeROM, SizeOf(DonneeROM), 0);
 FillChar(TailleBloc, SizeOf(TailleBloc), 0);
 NbBlocs := (TailleROM + TAILLE_BLOC_ROM - 1) Div TAILLE_BLOC_ROM;
 For IndexBloc := 0 To NbBlocs - 1 Do Begin
  OctetsBloc := TAILLE_BLOC_ROM;
  If IndexBloc = NbBlocs - 1 Then
   OctetsBloc := TailleROM - (IndexBloc * TAILLE_BLOC_ROM);
  GetMem(DonneeROM[IndexBloc], OctetsBloc);
  TailleBloc[IndexBloc] := OctetsBloc;
 End;

  { Lecture complete des donnees de la ROM }
 LectureComplete := True;
 OctetsLus := 0;
 For IndexBloc := 0 To NbBlocs - 1 Do Begin
  BlockRead(FichierSrc, DonneeROM[IndexBloc]^,
    TailleBloc[IndexBloc], OctetsLus);
  If OctetsLus <> TailleBloc[IndexBloc] Then Begin
   LectureComplete := False;
   Break;
  End;
 End;
 Close(FichierSrc);

 If not LectureComplete Then Begin
  WriteLn('Erreur : lecture incomplete.');
  LibererDonneeROM;
  Halt(5);
 End;

  { --- Construction de l'en-tete A26 (16 octets) --- }
 FillChar(Entete, SizeOf(Entete), 0);

  { Signature : 'A', '2', '6', $1A }
 Entete.Signature[0] := $41;  { 'A' }
 Entete.Signature[1] := $32;  { '2' }
 Entete.Signature[2] := $36;  { '6' }
 Entete.Signature[3] := $1A;  { Marqueur de debut de fichier binaire }

 Entete.TailleROM  := LongInt(TailleROM);
 Entete.BancSwitch := CodeBanc;
 Entete.Flags      := $00;
  { Reserve initialise a zero par FillChar }
  { --- Ecriture du fichier de destination --- }
 Assign(FichierDst, NomDst);
 {$I-}
 Rewrite(FichierDst, 1);
 {$I+}
 If IOResult <> 0 then Begin
  WriteLn('Erreur : impossible de creer : ', NomDst);
  Halt(6);
 End;

  { En-tete A26 (16 octets) }
 BlockWrite(FichierDst, Entete, TAILLE_ENTETE);
  { Donnees brutes de la ROM }
 For IndexBloc := 0 To NbBlocs - 1 Do
  BlockWrite(FichierDst, DonneeROM[IndexBloc]^, TailleBloc[IndexBloc]);

 Close(FichierDst);
 LibererDonneeROM;

  { --- Rapport final --- }
 WriteLn('Conversion reussie !');
 WriteLn;
 WriteLn('  En-tete A26  : ', TAILLE_ENTETE, ' octets');
 WriteLn('  Donnees ROM  : ', TailleROM, ' octets');
 WriteLn('  Total ecrit  : ', TAILLE_ENTETE + TailleROM, ' octets');
 WriteLn;
 WriteLn('"', NomDst, '" est pret pour utilisation.');
END.
