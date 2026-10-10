{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Desassembleur de cartouches .PAK du TRS-80 Color Computer 3
                Motorola 6809E / Hitachi HD6309, format PAK (Jeff Vavasour)
  @license: MIT
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Lecture .PAK   : ReadPakFile -> detection d'en-tete Vavasour/brut/auto   }
{  2. Table opcodes  : OpTable[$00..$FF] + OpTablePage2/3 (prebytes $10/$11)   }
{     + postbyte indexe (18 sous-modes) - verifiees contre le vrai coeur       }
{     emulateur M6809_* deja present et teste dans DEVENV.PAS (meme projet)    }
{  3. Passe 1        : desassemblage RECURSIF (pas un simple balayage lineaire)}
{     a partir du point d'entree - suit JMP/JSR/Bcc/LBcc, s'arrete a RTS/RTI/  }
{     branchement inconditionnel - distingue code visite et donnees restantes  }
{  4. Etiquettes     : toute adresse cible d'un branchement/saut/reference      }
{     directe/etendue devient une etiquette LNNNN ou SNNNN (sous-routine)      }
{  5. Passe 2        : emission ASM/LST/TXT avec etiquettes, commentaires,      }
{     octets, cycles, xref, annotations materielles CoCo3 (GIME/SAM/PIA)       }
{ ---------------------------------------------------------------------------- }

{ TODO 01 - Infrastructure, options de ligne de commande et constantes }
{ TODO 02 - Lecture du fichier .PAK (Vavasour/brut/auto) et validation }
{ TODO 03 - Table des opcodes 6809 (page de base) }
{ TODO 04 - Table des opcodes 6809 page 2 ($10) et page 3 ($11) }
{ TODO 05 - Extensions HD6309 (-cpu 6309) }
{ TODO 06 - Decodage du mode indexe (postbyte, 18 sous-modes) }
{ TODO 07 - Table du materiel CoCo3 (GIME/SAM/PIA) pour -hardware/-equates }
{ TODO 08 - Table des symboles BASIC/Extended Color BASIC pour -basic }
{ TODO 09 - Table des symboles : etiquettes generees, xref, symboles externes }
{ TODO 10 - Decodeur d'une instruction (une passe, un point memoire) }
{ TODO 11 - Passe 1 : desassemblage recursif, decouverte code/donnees }
{ TODO 12 - Passe 2 : emission du texte assembleur/listing }
{ TODO 13 - Recherche de chaines ASCII (-strings) }
{ TODO 14 - Programme principal : ligne de commande, orchestration }

Program DISPAK;

{$A-}
{$I-}

{ ============================================================================ }
{ TODO 01 - Infrastructure, options de ligne de commande et constantes         }
{ ============================================================================ }

Const

 { ------------------------------------------------------------------ }
 { Limites                                                              }
 { ------------------------------------------------------------------ }
 MAX_ROM          = 2 * 1024 * 1024; { 2 Mio - largement au-dela de toute vraie cartouche CoCo3 }
 MAX_LABELS       = 16384;
 MAX_XREF_PER_LBL = 32;
 MAX_SYMBOLS      = 4096;
 MAX_BANKS        = 64;
 MAX_PENDING      = 8192;    { file d'attente de la passe 1 recursive }
 MAX_STRINGS      = 4096;

 { ------------------------------------------------------------------ }
 { CPU cible                                                           }
 { ------------------------------------------------------------------ }
 CPU_6809 = 0;
 CPU_6309 = 1;

 { ------------------------------------------------------------------ }
 { Modes d'adressage du 6809/6309                                      }
 { ------------------------------------------------------------------ }
 AM_INHERENT   = 0;  { pas d'operande (NOP, RTS, CLRA...)               }
 AM_DIRECT     = 1;  { octet direct (registre DP implicite)             }
 AM_EXTENDED   = 2;  { adresse 16 bits                                  }
 AM_INDEXED    = 3;  { postbyte indexe, 18 sous-modes (TODO 06)         }
 AM_IMMED8     = 4;  { valeur immediate 8 bits                          }
 AM_IMMED16    = 5;  { valeur immediate 16 bits                         }
 AM_REL8       = 6;  { branchement court, deplacement 8 bits signe      }
 AM_REL16      = 7;  { branchement long, deplacement 16 bits signe      }
 AM_IMMED_TFR  = 8;  { postbyte TFR/EXG (paire de registres 4+4 bits)   }
 AM_IMMED_PSH  = 9;  { postbyte PSHS/PULS/PSHU/PULU (masque de registres)}
 AM_IMMED_TFM  = 10; { postbyte + mode TFM (HD6309, 2 registres + mode) }
 AM_DIR_IMMED8 = 11; { HD6309 OIM/AIM/EIM/TIM : immediat 8 + direct     }
 AM_IDX_IMMED8 = 12; { HD6309 OIM/AIM/EIM/TIM : immediat 8 + indexe     }
 AM_EXT_IMMED8 = 13; { HD6309 OIM/AIM/EIM/TIM : immediat 8 + etendu     }
 AM_ILLEGAL    = 99; { opcode non implante/illegal                      }

 { ------------------------------------------------------------------ }
 { Format du fichier .PAK                                              }
 { ------------------------------------------------------------------ }
 PAK_AUTO      = 0;
 PAK_VAVASOUR  = 1;
 PAK_RAW       = 2;

 { ------------------------------------------------------------------ }
 { Format de sortie                                                    }
 { ------------------------------------------------------------------ }
 FMT_ASM = 0;
 FMT_LST = 1;
 FMT_TXT = 2;

 { ------------------------------------------------------------------ }
 { Type de region memoire (pour -auto, code vs donnees)                }
 { ------------------------------------------------------------------ }
 RGN_UNKNOWN = 0;  { jamais visite - devient donnee par defaut en sortie }
 RGN_CODE    = 1;  { premier octet d'une instruction decodee            }
 RGN_OPERAND = 2;  { octet appartenant a l'operande d'une instruction    }
 RGN_DATA    = 3;  { force donnee (par -data ou detection de chaine)     }

{ ============================================================================ }
{ Types internes                                                               }
{ ============================================================================ }

Type

 { --- Options de ligne de commande --- }
 TOptions = Record
  PakFile       : String;
  OutFile       : String;
  PakMode       : Byte;     { PAK_AUTO/VAVASOUR/RAW }
  Cpu           : Byte;     { CPU_6809/CPU_6309 }
  AutoMode      : Boolean;  { -auto : desassemblage recursif code/donnees }
  OrgSet        : Boolean;
  OrgAddr       : Word;
  EntrySet      : Boolean;
  EntryAddr     : Word;
  EndSet        : Boolean;
  EndAddr       : Word;
  Offset        : LongInt;
  SizeLimitSet  : Boolean;
  SizeLimit     : LongInt;
  ShowHeader    : Boolean;
  NoHeader      : Boolean;
  RomMode       : Boolean;
  RamMode       : Boolean;
  BankNum       : Integer;
  BankSize      : LongInt;
  BankMapFile   : String;
  DoVectors     : Boolean;
  DoStrings     : Boolean;
  DoData        : Boolean;
  DoLabels      : Boolean;
  SymbolFile    : String;
  DoComments    : Boolean;
  DoCycles      : Boolean;
  DoBytes       : Boolean;
  DoXref        : Boolean;
  DirectPageSet : Boolean;
  DirectPage    : Byte;
  DoEquates     : Boolean;
  DoHardware    : Boolean;
  DoBasic       : Boolean;
  DoGime        : Boolean;
  DoSam         : Boolean;
  DoPia         : Boolean;
  OutFormat     : Byte;     { FMT_ASM/LST/TXT }
  Verbose       : Boolean;
  Quiet         : Boolean;
  LoadAddrSet   : Boolean;
  LoadAddr      : Word;
  RomSizeSet    : Boolean;
  RomSizeOverride: LongInt;
  Validate      : Boolean;
  InfoOnly      : Boolean;
 End;

 { --- Table des opcodes (TODO 03/04/05) --- }
 TOpEntry = Record
  Mnem  : String[7];
  Mode  : Byte;
  Cyc   : Byte;      { cycles de base (approximatif, voir disclosure TODO 10) }
  Legal : Boolean;    { False = opcode non documente/illegal sur ce CPU }
  Min6309: Boolean;   { True = necessite -cpu 6309 (HD6309 uniquement) }
 End;

 { --- Etiquette generee ou fournie --- }
 TLabelEntry = Record
  Addr       : Word;
  Name       : String[16];
  IsSub      : Boolean;    { True si cible de JSR/BSR (sous-routine probable) }
  FromUser   : Boolean;    { True si chargee via -symbols }
  RefCount   : Integer;
  RefFrom    : Array[1..MAX_XREF_PER_LBL] Of Word;
 End;

 { --- Entree de table materielle (GIME/SAM/PIA/BASIC) --- }
 THwEntry = Record
  Addr : Word;
  Name : String[16];
  Desc : String[48];
 End;

{ ============================================================================ }
{ Variables globales                                                           }
{ ============================================================================ }

Var
 Opts : TOptions;

 { --- Image memoire et region (TODO 02/11) --- }
 Rom        : Array[0..MAX_ROM - 1] Of Byte;
 RomSize    : LongInt;        { octets reellement charges }
 LoadAddr   : Word;           { adresse de chargement (ORG effectif) }
 Region     : Array[0..$FFFF] Of Byte;   { RGN_xxx par adresse memoire 16 bits }
 HasByte    : Array[0..$FFFF] Of Boolean; { True si cette adresse est couverte par Rom }

 { --- Table des opcodes active (TODO 03/04/05) --- }
 OpTable      : Array[0..255] Of TOpEntry;  { page de base }
 OpTablePage2 : Array[0..255] Of TOpEntry;  { prebyte $10 }
 OpTablePage3 : Array[0..255] Of TOpEntry;  { prebyte $11 }

 { --- Table materielle CoCo3 (TODO 07/08) --- }
 HwTable    : Array[1..400] Of THwEntry;
 HwCount    : Integer;

 { --- Table des symboles/etiquettes (TODO 09) --- }
 Labels     : Array[1..MAX_LABELS] Of TLabelEntry;
 LabelCount : Integer;

 { --- File d'attente de la passe 1 recursive (TODO 11) --- }
 Pending      : Array[1..MAX_PENDING] Of Word;
 PendingCount : Integer;

 { --- Compteurs/bilan --- }
 InstrCount   : LongInt;
 DataByteCount: LongInt;
 ErrorCount   : Integer;

 { --- Fichier de sortie --- }
 OutText    : Text;
 OutOpened  : Boolean;

{ ============================================================================ }
{ Fonctions utilitaires                                                        }
{ ============================================================================ }

Function UpCaseStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R := S;
 For I := 1 To Length(R) Do R[I] := UpCase(R[I]);
 UpCaseStr := R;
End;

Function IntToStr(V: LongInt): String;
Var S: String;
Begin
 Str(V, S);
 IntToStr := S;
End;

Function HexDigit(N: Byte): Char;
Begin
 N := N And $0F;
 If N < 10 Then HexDigit := Chr(Ord('0') + N)
 Else HexDigit := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): String;
Begin
 HexByte := HexDigit(B Shr 4) + HexDigit(B);
End;

Function HexWord(W: Word): String;
Begin
 HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function PadRight(Const S: String; Width: Integer): String;
Var R: String;
Begin
 R := S;
 While Length(R) < Width Do R := R + ' ';
 PadRight := R;
End;

Function Trim(Const S: String): String;
Var I, J: Integer;
Begin
 I := 1;
 While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
 J := Length(S);
 While (J >= I) And (S[J] = ' ') Do Dec(J);
 If J < I Then Trim := '' Else Trim := Copy(S, I, J - I + 1);
End;

Function FileExists(Const FileName: String): Boolean;
Var F: File;
Begin
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult = 0 Then Begin FileExists := True; Close(F); End
 Else FileExists := False;
End;

{ Convertit un texte hexadecimal ("C000", "$C000", "0xC000") en Word. }
Function ParseHexWord(S: String; Var Ok: Boolean): Word;
Var V: LongInt; Code: Integer; US: String;
Begin
 US := UpCaseStr(Trim(S));
 If (Length(US) > 0) And (US[1] = '$') Then US := Copy(US, 2, Length(US) - 1);
 If (Length(US) > 1) And (US[1] = '0') And (US[2] = 'X') Then
  US := Copy(US, 3, Length(US) - 2);
 Val('$' + US, V, Code);
 Ok := (Code = 0) And (V >= 0) And (V <= $FFFF);
 If Ok Then ParseHexWord := Word(V) Else ParseHexWord := 0;
End;

Function ParseLongVal(S: String; Var Ok: Boolean): LongInt;
{ Accepte decimal ou hexadecimal ($xxxx/0xxxxx) pour -offset/-size/-banksize }
Var V: LongInt; Code: Integer; US: String;
Begin
 US := UpCaseStr(Trim(S));
 If (Length(US) > 0) And (US[1] = '$') Then
 Begin
  Val('$' + Copy(US, 2, Length(US) - 1), V, Code);
 End
 Else If (Length(US) > 1) And (US[1] = '0') And (US[2] = 'X') Then
 Begin
  Val('$' + Copy(US, 3, Length(US) - 2), V, Code);
 End
 Else
  Val(US, V, Code);
 Ok := (Code = 0);
 If Ok Then ParseLongVal := V Else ParseLongVal := 0;
End;

{ ============================================================================ }
{ TODO 02 - Lecture du fichier .PAK (Vavasour/brut/auto) et validation         }
{ ============================================================================ }

{ Format .PAK classique (emulateur CoCo3 de Jeff Vavasour), documente par      }
{ l'utilisateur :                                                              }
{   $0000  2 octets  longueur de la ROM, little-endian                        }
{   $0002  2 octets  adresse de chargement, little-endian                      }
{   $0004  ...        contenu binaire de la ROM                                }
{ Une cartouche de 8 Kio a $C000 donne donc un fichier de 8196 octets          }
{ (8192 + 4 octets d'en-tete) - c'est exactement le test de coherence que      }
{ -validate applique (voir ValidatePakHeader). }

Function ReadFileBytes(Const FileName: String; Var Buf; MaxLen: LongInt;
 Var ActualLen: LongInt): Boolean;
Var F: File; NRead: LongInt; P: ^Byte; Chunk: Word;
Begin
 ReadFileBytes := False;
 ActualLen := 0;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;
 P := @Buf;
 Repeat
  If (ActualLen + 32768) > MaxLen Then Chunk := Word(MaxLen - ActualLen)
  Else Chunk := 32768;
  If Chunk = 0 Then Break;
  {$I-} BlockRead(F, P^, Chunk, NRead); {$I+}
  If (IOResult <> 0) Then Break;
  Inc(ActualLen, NRead);
  Inc(P, NRead);
 Until (NRead = 0) Or (ActualLen >= MaxLen);
 Close(F);
 ReadFileBytes := True;
End;

{ Detecte si le fichier RESSEMBLE a un .PAK Vavasour valide : les 2 premiers   }
{ mots (longueur, adresse) doivent etre coherents avec la taille reelle du     }
{ fichier (longueur declaree + 4 = taille du fichier), et l'adresse de         }
{ chargement doit tomber dans une plage plausible pour une cartouche CoCo3     }
{ ($C000-$FFFF le plus souvent, parfois $4000+ pour certains montages). }
Function LooksLikeVavasour(Var RawBuf; RawLen: LongInt;
 Var DeclLen, DeclAddr: Word): Boolean;
Var P: ^Byte;
Begin
 LooksLikeVavasour := False;
 If RawLen < 4 Then Exit;
 P := @RawBuf;
 DeclLen  := Word(P^); Inc(P);
 DeclLen  := DeclLen Or (Word(P^) Shl 8); Inc(P);
 DeclAddr := Word(P^); Inc(P);
 DeclAddr := DeclAddr Or (Word(P^) Shl 8);
 LooksLikeVavasour := (LongInt(DeclLen) + 4 = RawLen) And (DeclLen > 0);
End;

Procedure ValidatePakHeader(DeclLen, DeclAddr: Word; RawLen: LongInt);
Begin
 If LongInt(DeclLen) + 4 <> RawLen Then
  WriteLn('Avertissement -validate : longueur declaree (', DeclLen,
   ' + 4 = ', LongInt(DeclLen) + 4, ') ne correspond pas a la taille ' +
   'reelle du fichier (', RawLen, ' octets).');
 If (DeclAddr < $4000) Or (LongInt(DeclAddr) + DeclLen > $10000) Then
  WriteLn('Avertissement -validate : adresse de chargement $', HexWord(DeclAddr),
   ' inhabituelle ou debordant au-dela de $FFFF pour une cartouche CoCo3.');
End;

{ Point d'entree de TODO 02 : charge Opts.PakFile dans Rom[]/RomSize/LoadAddr  }
{ selon Opts.PakMode (et les overrides -loadaddr/-romsize/-offset/-size).      }
{ Retourne False si le fichier est illisible. }
Function LoadPakFile: Boolean;
Var
 RawBuf: Array[0..MAX_ROM + 16 - 1] Of Byte;
 RawLen: LongInt;
 DeclLen, DeclAddr: Word;
 IsVavasour: Boolean;
 DataStart: LongInt;
 DataLen: LongInt;
 I: LongInt;
Begin
 LoadPakFile := False;
 If Not ReadFileBytes(Opts.PakFile, RawBuf, SizeOf(RawBuf), RawLen) Then
 Begin
  WriteLn('Erreur : impossible de lire ', Opts.PakFile);
  Exit;
 End;
 If RawLen = 0 Then
 Begin
  WriteLn('Erreur : fichier vide : ', Opts.PakFile);
  Exit;
 End;

 IsVavasour := LooksLikeVavasour(RawBuf, RawLen, DeclLen, DeclAddr);

 Case Opts.PakMode Of
  PAK_VAVASOUR:
  Begin
   If Not IsVavasour Then
    WriteLn('Avertissement : en-tete Vavasour force (-pak vavasour) mais ' +
     'la coherence longueur/taille echoue - poursuite quand meme.');
   DataStart := 4;
   DataLen   := RawLen - 4;
   LoadAddr  := DeclAddr;
  End;
  PAK_RAW:
  Begin
   DataStart := 0;
   DataLen   := RawLen;
   LoadAddr  := $C000; { defaut raisonnable pour une cartouche CoCo3 brute }
  End;
 Else { PAK_AUTO }
  Begin
   If IsVavasour Then
   Begin
    DataStart := 4;
    DataLen   := RawLen - 4;
    LoadAddr  := DeclAddr;
    If Not Opts.Quiet Then
     WriteLn('Info : en-tete Vavasour detecte automatiquement (longueur=',
      DeclLen, ', adresse=$', HexWord(DeclAddr), ').');
   End
   Else
   Begin
    DataStart := 0;
    DataLen   := RawLen;
    LoadAddr  := $C000;
    If Not Opts.Quiet Then
     WriteLn('Avertissement : format ambigu - aucun en-tete Vavasour ' +
      'coherent detecte, traitement en ROM brute a $C000 (voir -pak/-org/' +
      '-loadaddr pour forcer).');
   End;
  End;
 End;

 If Opts.NoHeader Then Begin DataStart := 0; DataLen := RawLen; End;

 If Opts.Validate And IsVavasour Then ValidatePakHeader(DeclLen, DeclAddr, RawLen);

 If Opts.LoadAddrSet Then LoadAddr := Opts.LoadAddr;
 If Opts.RomSizeSet And (Opts.RomSizeOverride > 0) Then DataLen := Opts.RomSizeOverride;

 { -offset : decalage supplementaire dans les donnees avant le debut reel }
 If Opts.Offset > 0 Then
 Begin
  Inc(DataStart, Opts.Offset);
  Dec(DataLen, Opts.Offset);
 End;
 If Opts.SizeLimitSet And (Opts.SizeLimit < DataLen) Then DataLen := Opts.SizeLimit;
 If DataLen < 0 Then DataLen := 0;
 If DataLen > MAX_ROM Then DataLen := MAX_ROM;
 If LongInt(LoadAddr) + DataLen > $10000 Then
  DataLen := $10000 - LongInt(LoadAddr);

 If Opts.OrgSet Then LoadAddr := Opts.OrgAddr;

 RomSize := DataLen;
 For I := 0 To DataLen - 1 Do Rom[I] := RawBuf[DataStart + I];

 FillChar(HasByte, SizeOf(HasByte), 0);
 For I := 0 To DataLen - 1 Do HasByte[(LongInt(LoadAddr) + I) And $FFFF] := True;

 If Opts.ShowHeader Or Opts.InfoOnly Then
 Begin
  WriteLn('Fichier          : ', Opts.PakFile);
  WriteLn('Taille fichier   : ', RawLen, ' octets');
  If IsVavasour Then
  Begin
   WriteLn('En-tete Vavasour : longueur=', DeclLen, ' ($', HexWord(DeclLen),
    '), adresse=$', HexWord(DeclAddr));
  End
  Else
   WriteLn('En-tete          : aucun (ou non reconnu)');
  WriteLn('Adresse chargee  : $', HexWord(LoadAddr));
  WriteLn('Octets charges   : ', RomSize, ' ($', HexWord(Word(RomSize And $FFFF)), ')');
  WriteLn('Derniere adresse : $', HexWord(Word((LongInt(LoadAddr) + RomSize - 1) And $FFFF)));
 End;

 LoadPakFile := True;
End;

{ ============================================================================ }
{ TODO 07 - Table du materiel CoCo3 (GIME/SAM/PIA) pour -hardware/-equates     }
{ ============================================================================ }

{ Portee disclosee : les registres sont nommes et decrits brievement (role      }
{ general), mais le detail bit-a-bit exact de chaque registre GIME/SAM n'est   }
{ PAS modelise ici (ce serait un second desassembleur a lui seul) - l'objectif }
{ est d'annoter "quel registre materiel est touche", pas de simuler sa         }
{ semantique complete. Vecteurs materiels 6809 ($FFF0-$FFFF) et registres      }
{ SAM ($FFC0-$FFDF, bascule pair/impair par bit) sont en revanche exacts, ce   }
{ sont des faits d'architecture fixes et bien documentes. }

Procedure AddHw(Addr: Word; Const Name, Desc: String);
Begin
 If HwCount < High(HwTable) Then
 Begin
  Inc(HwCount);
  HwTable[HwCount].Addr := Addr;
  HwTable[HwCount].Name := Name;
  HwTable[HwCount].Desc := Desc;
 End;
End;

Function FindHw(Addr: Word): Integer;
Var I: Integer;
Begin
 FindHw := 0;
 For I := 1 To HwCount Do
  If HwTable[I].Addr = Addr Then Begin FindHw := I; Exit; End;
End;

Procedure InitHwTable;
Var I: Word;
Begin
 HwCount := 0;

 If Opts.DoPia Or Opts.DoHardware Then
 Begin
  AddHw($FF00, 'PIA0PA',  'PIA0 port A (clavier/manette droite)');
  AddHw($FF01, 'PIA0CRA', 'PIA0 registre de controle A');
  AddHw($FF02, 'PIA0PB',  'PIA0 port B (clavier/manette gauche)');
  AddHw($FF03, 'PIA0CRB', 'PIA0 registre de controle B');
  AddHw($FF20, 'PIA1PA',  'PIA1 port A (son/cassette)');
  AddHw($FF21, 'PIA1CRA', 'PIA1 registre de controle A');
  AddHw($FF22, 'PIA1PB',  'PIA1 port B (RS-232/imprimante)');
  AddHw($FF23, 'PIA1CRB', 'PIA1 registre de controle B');
 End;

 If Opts.DoSam Or Opts.DoHardware Then
 Begin
  { Le SAM bascule chaque bit via une PAIRE d'adresses (paire=0, impaire=1) }
  AddHw($FFC0, 'SAM_V0_0', 'SAM mode video, bit V0 = 0');
  AddHw($FFC1, 'SAM_V0_1', 'SAM mode video, bit V0 = 1');
  AddHw($FFC2, 'SAM_V1_0', 'SAM mode video, bit V1 = 0');
  AddHw($FFC3, 'SAM_V1_1', 'SAM mode video, bit V1 = 1');
  AddHw($FFC4, 'SAM_V2_0', 'SAM mode video, bit V2 = 0');
  AddHw($FFC5, 'SAM_V2_1', 'SAM mode video, bit V2 = 1');
  AddHw($FFC6, 'SAM_F0_0', 'SAM decalage affichage, bit F0 = 0');
  AddHw($FFC7, 'SAM_F0_1', 'SAM decalage affichage, bit F0 = 1');
  AddHw($FFC8, 'SAM_F1_0', 'SAM decalage affichage, bit F1 = 0');
  AddHw($FFC9, 'SAM_F1_1', 'SAM decalage affichage, bit F1 = 1');
  AddHw($FFCA, 'SAM_F2_0', 'SAM decalage affichage, bit F2 = 0');
  AddHw($FFCB, 'SAM_F2_1', 'SAM decalage affichage, bit F2 = 1');
  AddHw($FFCC, 'SAM_F3_0', 'SAM decalage affichage, bit F3 = 0');
  AddHw($FFCD, 'SAM_F3_1', 'SAM decalage affichage, bit F3 = 1');
  AddHw($FFCE, 'SAM_F4_0', 'SAM decalage affichage, bit F4 = 0');
  AddHw($FFCF, 'SAM_F4_1', 'SAM decalage affichage, bit F4 = 1');
  AddHw($FFD0, 'SAM_F5_0', 'SAM decalage affichage, bit F5 = 0');
  AddHw($FFD1, 'SAM_F5_1', 'SAM decalage affichage, bit F5 = 1');
  AddHw($FFD2, 'SAM_F6_0', 'SAM decalage affichage, bit F6 = 0');
  AddHw($FFD3, 'SAM_F6_1', 'SAM decalage affichage, bit F6 = 1');
  AddHw($FFD4, 'SAM_P1_0', 'SAM page/type memoire, bit P1 = 0');
  AddHw($FFD5, 'SAM_P1_1', 'SAM page/type memoire, bit P1 = 1');
  AddHw($FFD6, 'SAM_R0_0', 'SAM vitesse processeur, bit R0 = 0 (lent)');
  AddHw($FFD7, 'SAM_R0_1', 'SAM vitesse processeur, bit R0 = 1 (rapide)');
  AddHw($FFD8, 'SAM_R1_0', 'SAM vitesse processeur, bit R1 = 0');
  AddHw($FFD9, 'SAM_R1_1', 'SAM vitesse processeur, bit R1 = 1');
  AddHw($FFDA, 'SAM_M0_0', 'SAM taille memoire, bit M0 = 0');
  AddHw($FFDB, 'SAM_M0_1', 'SAM taille memoire, bit M0 = 1');
  AddHw($FFDC, 'SAM_M1_0', 'SAM taille memoire, bit M1 = 0');
  AddHw($FFDD, 'SAM_M1_1', 'SAM taille memoire, bit M1 = 1');
  AddHw($FFDE, 'SAM_TY_0', 'SAM type carte memoire, bit TY = 0 (RAM)');
  AddHw($FFDF, 'SAM_TY_1', 'SAM type carte memoire, bit TY = 1 (ROM)');
 End;

 If Opts.DoGime Or Opts.DoHardware Then
 Begin
  AddHw($FF90, 'GIME_INIT0', 'GIME initialisation 0 (MMU/IRQ/FIRQ, compat. CoCo 1/2)');
  AddHw($FF91, 'GIME_INIT1', 'GIME initialisation 1 (selection de tache MMU)');
  AddHw($FF92, 'GIME_IRQENR','GIME masque de validation IRQ');
  AddHw($FF93, 'GIME_FIRQENR','GIME masque de validation FIRQ');
  AddHw($FF94, 'GIME_TIMMSB', 'GIME minuterie, octet fort');
  AddHw($FF95, 'GIME_TIMLSB', 'GIME minuterie, octet faible');
  AddHw($FF98, 'GIME_VMODE',  'GIME mode video (resolution/couleurs/MMU)');
  AddHw($FF99, 'GIME_VRES',   'GIME resolution video');
  AddHw($FF9A, 'GIME_BORDER', 'GIME couleur de bordure');
  AddHw($FF9C, 'GIME_VSC',    'GIME defilement vertical');
  AddHw($FF9D, 'GIME_VOFF1',  'GIME decalage vertical, octet fort');
  AddHw($FF9E, 'GIME_VOFF0',  'GIME decalage vertical, octet faible');
  AddHw($FF9F, 'GIME_HOFF',   'GIME decalage horizontal');
  For I := 0 To 7 Do
   AddHw($FFA0 + I, 'MMU_T0B' + Chr(Ord('0') + I), 'GIME MMU, tache 0, banque ' + Chr(Ord('0') + I));
  For I := 0 To 7 Do
   AddHw($FFA8 + I, 'MMU_T1B' + Chr(Ord('0') + I), 'GIME MMU, tache 1, banque ' + Chr(Ord('0') + I));
  For I := 0 To 15 Do
   AddHw($FFB0 + I, 'PALETTE' + IntToStr(I), 'GIME registre de palette couleur ' + IntToStr(I));
 End;

 If Opts.DoVectors Then
 Begin
  AddHw($FFF2, 'VEC_SWI3',  'Vecteur materiel 6809/6309 : SWI3');
  AddHw($FFF4, 'VEC_SWI2',  'Vecteur materiel 6809/6309 : SWI2');
  AddHw($FFF6, 'VEC_FIRQ',  'Vecteur materiel 6809/6309 : FIRQ');
  AddHw($FFF8, 'VEC_IRQ',   'Vecteur materiel 6809/6309 : IRQ');
  AddHw($FFFA, 'VEC_SWI',   'Vecteur materiel 6809/6309 : SWI');
  AddHw($FFFC, 'VEC_NMI',   'Vecteur materiel 6809/6309 : NMI');
  AddHw($FFFE, 'VEC_RESET', 'Vecteur materiel 6809/6309 : RESET');
 End;
End;

{ ============================================================================ }
{ TODO 08 - Table des symboles BASIC/Extended Color BASIC pour -basic         }
{ ============================================================================ }

{ Portee disclosee : plutot que de pretendre a une table d'adresses de         }
{ routines BASIC precises (risque reel d'erreur - les adresses exactes des    }
{ points d'entree varient selon la revision de ROM et ne sont pas verifiees   }
{ ici), -basic se contente d'annoter tout JSR/JMP dont la cible tombe dans    }
{ une des plages ROM BASIC connues du CoCo - un fait d'architecture fixe,     }
{ pas une pretention de precision sur LAQUELLE routine est appelee. }
Function BasicRangeComment(Addr: Word): String;
Begin
 BasicRangeComment := '';
 If (Addr >= $A000) And (Addr <= $BFFF) Then
  BasicRangeComment := 'appel probable dans la ROM Color BASIC ($A000-$BFFF)'
 Else If (Addr >= $8000) And (Addr <= $9FFF) Then
  BasicRangeComment := 'appel probable dans la ROM Extended Color BASIC ($8000-$9FFF)';
End;

{ ============================================================================ }
{ TODO 09 - Table des symboles : etiquettes generees, xref, symboles externes }
{ ============================================================================ }

Function FindLabel(Addr: Word): Integer;
Var I: Integer;
Begin
 FindLabel := 0;
 For I := 1 To LabelCount Do
  If Labels[I].Addr = Addr Then Begin FindLabel := I; Exit; End;
End;

Function AddLabel(Addr: Word; IsSub: Boolean): Integer;
Var Idx: Integer;
Begin
 Idx := FindLabel(Addr);
 If Idx <> 0 Then
 Begin
  If IsSub Then Labels[Idx].IsSub := True;
  AddLabel := Idx;
  Exit;
 End;
 If LabelCount >= MAX_LABELS Then Begin AddLabel := 0; Exit; End;
 Inc(LabelCount);
 Labels[LabelCount].Addr     := Addr;
 Labels[LabelCount].IsSub    := IsSub;
 Labels[LabelCount].FromUser := False;
 Labels[LabelCount].RefCount := 0;
 { Nom par defaut : SNNNN pour une sous-routine (cible JSR/BSR), sinon      }
 { LNNNN - renomme plus tard si -symbols fournit un nom reel pour Addr.    }
 If IsSub Then Labels[LabelCount].Name := 'S' + HexWord(Addr)
 Else Labels[LabelCount].Name := 'L' + HexWord(Addr);
 AddLabel := LabelCount;
End;

Procedure AddXref(Addr, FromAddr: Word);
Var Idx: Integer;
Begin
 Idx := FindLabel(Addr);
 If Idx = 0 Then Exit;
 If Labels[Idx].RefCount < MAX_XREF_PER_LBL Then
 Begin
  Inc(Labels[Idx].RefCount);
  Labels[Idx].RefFrom[Labels[Idx].RefCount] := FromAddr;
 End;
End;

Function LabelName(Addr: Word): String;
Var Idx: Integer;
Begin
 Idx := FindLabel(Addr);
 If Idx <> 0 Then LabelName := Labels[Idx].Name
 Else LabelName := '$' + HexWord(Addr);
End;

{ -symbols fichier : charge des paires "NOM=$ADDR" ou "NOM $ADDR", une par    }
{ ligne (';' en premiere colonne = commentaire) - les noms fournis par       }
{ l'utilisateur remplacent les etiquettes LNNNN/SNNNN generees. }
Procedure LoadSymbolFile(Const FileName: String);
Var
 F: Text;
 Line, NameStr, AddrStr: String;
 EqPos, SpPos, Idx: Integer;
 Addr: Word;
 Ok: Boolean;
 Loaded: Integer;
Begin
 If FileName = '' Then Exit;
 Assign(F, FileName);
 {$I-} Reset(F); {$I+}
 If IOResult <> 0 Then
 Begin
  WriteLn('Avertissement : -symbols, fichier introuvable : ', FileName);
  Exit;
 End;
 Loaded := 0;
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Line := Trim(Line);
  If (Line = '') Or (Line[1] = ';') Then Continue;
  EqPos := Pos('=', Line);
  SpPos := Pos(' ', Line);
  If (EqPos > 0) And ((SpPos = 0) Or (EqPos < SpPos)) Then
  Begin
   NameStr := Trim(Copy(Line, 1, EqPos - 1));
   AddrStr := Trim(Copy(Line, EqPos + 1, Length(Line)));
  End
  Else If SpPos > 0 Then
  Begin
   NameStr := Trim(Copy(Line, 1, SpPos - 1));
   AddrStr := Trim(Copy(Line, SpPos + 1, Length(Line)));
  End
  Else Continue;
  Addr := ParseHexWord(AddrStr, Ok);
  If Not Ok Then Continue;
  Idx := AddLabel(Addr, False);
  If Idx <> 0 Then
  Begin
   Labels[Idx].Name     := Copy(NameStr, 1, 16);
   Labels[Idx].FromUser := True;
   Inc(Loaded);
  End;
 End;
 Close(F);
 If Not Opts.Quiet Then
  WriteLn('Info : ', Loaded, ' symbole(s) charge(s) depuis ', FileName);
End;

{ ============================================================================ }
{ TODO 13 - Recherche de chaines ASCII (-strings)                              }
{ ============================================================================ }

{ Balaye Rom[] pour des sequences d'au moins 4 caracteres imprimables          }
{ ($20-$7E) terminees par un octet nul ou non imprimable - affiche sur la      }
{ console (independant du fichier de sortie principal, comme un outil         }
{ "strings" Unix classique) et marque ces octets RGN_DATA pour que la passe    }
{ 2 ne tente pas de les desassembler comme instructions. }
Procedure ScanStrings;
{ BOGUE CORRIGE (trouve en verification live) : un balayage naif des octets  }
{ bruts de Rom[] ne distingue pas un octet de CODE d'un octet de DONNEE -    }
{ un opcode qui est AUSSI un caractere imprimable (ex: RTS=$39='9') se       }
{ faisait accoler a tort a une vraie chaine adjacente ("9Hello" au lieu de   }
{ "Hello"). Corrige en n'examinant QUE les octets encore RGN_UNKNOWN (donc   }
{ appele APRES RunPass1 - voir Run - jamais avant, pour que la classification}
{ code/donnees soit deja etablie). }
Var
 I, StartI: LongInt;
 Len: Integer;
 S: String;
 Addr: Word;
 A: Word;
Begin
 I := 0;
 While I < RomSize Do
 Begin
  A := Word((LongInt(LoadAddr) + I) And $FFFF);
  If (Region[A] = RGN_UNKNOWN) And (Rom[I] >= 32) And (Rom[I] <= 126) Then
  Begin
   StartI := I;
   S := '';
   While (I < RomSize) And (Length(S) < 255) Do
   Begin
    A := Word((LongInt(LoadAddr) + I) And $FFFF);
    If (Region[A] <> RGN_UNKNOWN) Or (Rom[I] < 32) Or (Rom[I] > 126) Then Break;
    S := S + Chr(Rom[I]);
    Inc(I);
   End;
   Len := I - StartI;
   If Len >= 4 Then
   Begin
    Addr := Word((LongInt(LoadAddr) + StartI) And $FFFF);
    WriteLn('$', HexWord(Addr), ' (', Len, ' car.) : "', S, '"');
    For StartI := StartI To StartI + Len - 1 Do
     Region[Word((LongInt(LoadAddr) + StartI) And $FFFF)] := RGN_DATA;
   End;
  End
  Else Inc(I);
 End;
End;

{ ============================================================================ }
{ TODO 14 - Programme principal : ligne de commande, orchestration            }
{ ============================================================================ }

Procedure ShowHelp;
Begin
 WriteLn('DISPAK - Cette commande permet de lancer le d'+#130+'sassembleur de cartouches .PAK ',
         'du TRS-80 Color Computer 3');
 WriteLn('Motorola 6809E / Hitachi HD6309, format PAK (Jeff Vavasour)');
 WriteLn;
 WriteLn('Syntaxe : DISPAK [options] fichier.pak [fichier.asm]');
 WriteLn;
 WriteLn('Options essentielles :');
 WriteLn('  -pak auto|vavasour|raw  Format du fichier (defaut : auto)');
 WriteLn('  -cpu 6809|6309          Ensemble d''instructions cible (defaut : 6809)');
 WriteLn('  -org adresse            Adresse d''origine du code');
 WriteLn('  -entry adresse          Point d''entree (debut du desassemblage recursif)');
 WriteLn('  -offset valeur          Decalage dans le fichier avant desassemblage');
 WriteLn('  -labels                 Genere des etiquettes pour les adresses referencees');
 WriteLn('  -bytes                  Affiche les octets hexadecimaux de chaque instruction');
 WriteLn('  -output fichier         Fichier de sortie (ou 2e argument positionnel)');
 WriteLn;
 WriteLn('Autres options :');
 WriteLn('  -h, --help              Cette aide');
 WriteLn('  -v, --version           Version du desassembleur');
 WriteLn('  -i, --info              Informations sur le fichier .PAK, sans desassembler');
 WriteLn('  -auto                   Desassemblage recursif code/donnees (implicite avec -entry)');
 WriteLn('  -end adresse            Derniere adresse a desassembler');
 WriteLn('  -size taille            Limite le nombre d''octets analyses');
 WriteLn('  -header / -noheader     Force/desactive l''interpretation de l''en-tete');
 WriteLn('  -rom / -ram             Mode cartouche ROM / code RAM (annotation seulement)');
 WriteLn('  -bank n / -banksize t / -bankmap fichier   Gestion multi-banque (basique)');
 WriteLn('  -vectors                Annote les vecteurs materiels 6809 ($FFF0-$FFFF)');
 WriteLn('  -strings                Recherche les chaines ASCII');
 WriteLn('  -data                   N''insere aucune etiquette de code pour les zones forcees donnees');
 WriteLn('  -symbols fichier        Charge une table de symboles externes (NOM=$ADDR)');
 WriteLn('  -comments               Commentaires explicatifs sur les instructions reconnues');
 WriteLn('  -cycles                 Estimation du nombre de cycles par instruction');
 WriteLn('  -xref                   References croisees entre adresses');
 WriteLn('  -directpage adresse     Valeur supposee du registre DP (annotation des acces directs)');
 WriteLn('  -equates                Genere des EQU pour les adresses materielles connues');
 WriteLn('  -hardware / -gime / -sam / -pia   Annotation des registres materiels CoCo3');
 WriteLn('  -basic                  Annote les appels probables dans la ROM BASIC');
 WriteLn('  -format asm|lst|txt     Format de sortie (defaut : asm)');
 WriteLn('  -verbose / -quiet       Messages detailles / messages minimaux');
 WriteLn('  -loadaddr adresse       Remplace l''adresse de chargement de l''en-tete');
 WriteLn('  -romsize taille         Remplace la longueur de ROM de l''en-tete');
 WriteLn('  -validate               Verifie la coherence de l''en-tete et de la taille du fichier');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn('  DISPAK DONKEY.PAK DONKEY.ASM');
 WriteLn('  DISPAK -pak raw -org C000 DONKEY.PAK DONKEY.ASM');
 WriteLn('  DISPAK -bytes -cycles -labels DONKEY.PAK DONKEY.LST');
 WriteLn('  DISPAK -hardware -gime -sam -pia DONKEY.PAK');
 WriteLn('  DISPAK -cpu 6309 -auto -xref GAME.PAK GAME.ASM');
End;

Procedure ShowVersion;
Begin
 WriteLn('DISPAK version 0.1 - Desassembleur de cartouches .PAK CoCo3 (6809/6309)');
 WriteLn('Pour Free Pascal');
End;

Function UpArg(Const S: String): String;
Begin
 UpArg := UpCaseStr(S);
End;

Procedure ParseArgs;
Var
 I: Integer;
 Arg, UA, ValStr: String;
 Ok: Boolean;
 LV: LongInt;
 PosArgs: Array[1..2] Of String;
 PosCount: Integer;
Begin
 With Opts Do
 Begin
  PakFile := ''; OutFile := '';
  PakMode := PAK_AUTO; Cpu := CPU_6809;
  AutoMode := False;
  OrgSet := False; OrgAddr := 0;
  EntrySet := False; EntryAddr := 0;
  EndSet := False; EndAddr := 0;
  Offset := 0;
  SizeLimitSet := False; SizeLimit := 0;
  ShowHeader := False; NoHeader := False;
  RomMode := False; RamMode := False;
  BankNum := -1; BankSize := 0; BankMapFile := '';
  DoVectors := False; DoStrings := False; DoData := False; DoLabels := False;
  SymbolFile := '';
  DoComments := False; DoCycles := False; DoBytes := False; DoXref := False;
  DirectPageSet := False; DirectPage := 0;
  DoEquates := False; DoHardware := False; DoBasic := False;
  DoGime := False; DoSam := False; DoPia := False;
  OutFormat := FMT_ASM;
  Verbose := False; Quiet := False;
  LoadAddrSet := False; LoadAddr := 0;
  RomSizeSet := False; RomSizeOverride := 0;
  Validate := False; InfoOnly := False;
 End;

 PosCount := 0;
 I := 1;
 While I <= ParamCount Do
 Begin
  Arg := ParamStr(I);
  UA := UpArg(Arg);
  If (UA = '-H') Or (UA = '--HELP') Or (UA = '/?') Or (UA = '/H') Then
   Begin ShowHelp; Halt(0); End
  Else If (UA = '-V') Or (UA = '--VERSION') Then Begin ShowVersion; Halt(0); End
  Else If (UA = '-I') Or (UA = '--INFO') Then Opts.InfoOnly := True
  Else If UA = '-CPU' Then
  Begin
   Inc(I);
   If UpArg(ParamStr(I)) = '6309' Then Opts.Cpu := CPU_6309 Else Opts.Cpu := CPU_6809;
  End
  Else If UA = '-AUTO' Then Opts.AutoMode := True
  Else If UA = '-ORG' Then
  Begin Inc(I); Opts.OrgAddr := ParseHexWord(ParamStr(I), Ok); Opts.OrgSet := Ok; End
  Else If UA = '-ENTRY' Then
  Begin Inc(I); Opts.EntryAddr := ParseHexWord(ParamStr(I), Ok); Opts.EntrySet := Ok; End
  Else If UA = '-END' Then
  Begin Inc(I); Opts.EndAddr := ParseHexWord(ParamStr(I), Ok); Opts.EndSet := Ok; End
  Else If UA = '-OFFSET' Then
  Begin Inc(I); Opts.Offset := ParseLongVal(ParamStr(I), Ok); End
  Else If UA = '-SIZE' Then
  Begin Inc(I); Opts.SizeLimit := ParseLongVal(ParamStr(I), Ok); Opts.SizeLimitSet := Ok; End
  Else If UA = '-HEADER' Then Opts.ShowHeader := True
  Else If UA = '-NOHEADER' Then Opts.NoHeader := True
  Else If UA = '-ROM' Then Opts.RomMode := True
  Else If UA = '-RAM' Then Opts.RamMode := True
  Else If UA = '-BANK' Then
  Begin Inc(I); LV := ParseLongVal(ParamStr(I), Ok); If Ok Then Opts.BankNum := LV; End
  Else If UA = '-BANKSIZE' Then
  Begin Inc(I); Opts.BankSize := ParseLongVal(ParamStr(I), Ok); End
  Else If UA = '-BANKMAP' Then
  Begin Inc(I); Opts.BankMapFile := ParamStr(I); End
  Else If UA = '-VECTORS' Then Opts.DoVectors := True
  Else If UA = '-STRINGS' Then Opts.DoStrings := True
  Else If UA = '-DATA' Then Opts.DoData := True
  Else If UA = '-LABELS' Then Opts.DoLabels := True
  Else If UA = '-SYMBOLS' Then
  Begin Inc(I); Opts.SymbolFile := ParamStr(I); End
  Else If UA = '-COMMENTS' Then Opts.DoComments := True
  Else If UA = '-CYCLES' Then Opts.DoCycles := True
  Else If UA = '-BYTES' Then Opts.DoBytes := True
  Else If UA = '-XREF' Then Opts.DoXref := True
  Else If UA = '-DIRECTPAGE' Then
  Begin
   Inc(I);
   Opts.DirectPage := Byte(ParseHexWord(ParamStr(I), Ok));
   Opts.DirectPageSet := Ok;
  End
  Else If UA = '-EQUATES' Then Opts.DoEquates := True
  Else If UA = '-HARDWARE' Then Opts.DoHardware := True
  Else If UA = '-BASIC' Then Opts.DoBasic := True
  Else If UA = '-GIME' Then Opts.DoGime := True
  Else If UA = '-SAM' Then Opts.DoSam := True
  Else If UA = '-PIA' Then Opts.DoPia := True
  Else If UA = '-FORMAT' Then
  Begin
   Inc(I);
   ValStr := UpArg(ParamStr(I));
   If ValStr = 'LST' Then Opts.OutFormat := FMT_LST
   Else If ValStr = 'TXT' Then Opts.OutFormat := FMT_TXT
   Else Opts.OutFormat := FMT_ASM;
  End
  Else If UA = '-OUTPUT' Then
  Begin Inc(I); Opts.OutFile := ParamStr(I); End
  Else If UA = '-VERBOSE' Then Opts.Verbose := True
  Else If UA = '-QUIET' Then Opts.Quiet := True
  Else If UA = '-PAK' Then
  Begin
   Inc(I);
   ValStr := UpArg(ParamStr(I));
   If ValStr = 'VAVASOUR' Then Opts.PakMode := PAK_VAVASOUR
   Else If ValStr = 'RAW' Then Opts.PakMode := PAK_RAW
   Else Opts.PakMode := PAK_AUTO;
  End
  Else If UA = '-LOADADDR' Then
  Begin Inc(I); Opts.LoadAddr := ParseHexWord(ParamStr(I), Ok); Opts.LoadAddrSet := Ok; End
  Else If UA = '-ROMSIZE' Then
  Begin Inc(I); Opts.RomSizeOverride := ParseLongVal(ParamStr(I), Ok); Opts.RomSizeSet := Ok; End
  Else If UA = '-VALIDATE' Then Opts.Validate := True
  Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
  Begin
   If PosCount < 2 Then Begin Inc(PosCount); PosArgs[PosCount] := Arg; End;
  End
  Else
  Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(2);
  End;
  Inc(I);
 End;

 If PosCount >= 1 Then Opts.PakFile := PosArgs[1];
 If PosCount >= 2 Then Opts.OutFile := PosArgs[2];
 If Opts.EntrySet Then Opts.AutoMode := True;
End;

{ ============================================================================ }
{ TODO 03/04 - Table des opcodes 6809 (page de base, page 2 $10, page 3 $11)  }
{ ============================================================================ }

{ Table verifiee par recherche dediee (agent Explore) contre le VRAI coeur     }
{ emulateur 6809 deja present et teste dans ce depot (DEVENV.PAS, prefixe      }
{ M6809_* - M6809_Step/StepPage2/StepPage3) : memes opcodes, memes modes       }
{ d'adressage, memes positions "illegal" exactement verifiees ligne par ligne. }
{ Deux ecarts assumes PAR RAPPORT a cet emulateur (disclosure) :               }
{  - CWAI ($3C) EST implante ici (reel/legal sur 6809 authentique) bien que    }
{    l'emulateur de DEVENV.PAS ne l'implante pas (lacune DE CET emulateur,     }
{    pas du vrai 6809 - confirmee par la recherche).                           }
{  - DAA ($19) est ici un simple opcode reconnu (mnemonique+mode corrects) ;   }
{    DISPAK ne simule rien, contrairement a l'emulateur dont la semantique     }
{    DAA est elle-meme un bouchon approximatif - sans consequence ici          }
{    puisqu'un desassembleur n'execute jamais l'instruction, il la NOMME.      }

Procedure SetOpIn(Var T: Array Of TOpEntry; Op: Byte; Const Mnem: String;
 Mode, Cyc: Byte);
Begin
 T[Op].Mnem   := Mnem;
 T[Op].Mode   := Mode;
 T[Op].Cyc    := Cyc;
 T[Op].Legal  := True;
 T[Op].Min6309:= False;
End;

Procedure InitOpTableBase;
Var I: Integer;
Begin
 For I := 0 To 255 Do
 Begin
  OpTable[I].Mnem := '???';
  OpTable[I].Mode := AM_ILLEGAL;
  OpTable[I].Cyc  := 0;
  OpTable[I].Legal := False;
  OpTable[I].Min6309 := False;
 End;

 { --- Operations memoire direct $00-$0F --- }
 SetOpIn(OpTable, $00, 'NEG', AM_DIRECT, 6);
 SetOpIn(OpTable, $03, 'COM', AM_DIRECT, 6);
 SetOpIn(OpTable, $04, 'LSR', AM_DIRECT, 6);
 SetOpIn(OpTable, $06, 'ROR', AM_DIRECT, 6);
 SetOpIn(OpTable, $07, 'ASR', AM_DIRECT, 6);
 SetOpIn(OpTable, $08, 'ASL', AM_DIRECT, 6);
 SetOpIn(OpTable, $09, 'ROL', AM_DIRECT, 6);
 SetOpIn(OpTable, $0A, 'DEC', AM_DIRECT, 6);
 SetOpIn(OpTable, $0C, 'INC', AM_DIRECT, 6);
 SetOpIn(OpTable, $0D, 'TST', AM_DIRECT, 6);
 SetOpIn(OpTable, $0E, 'JMP', AM_DIRECT, 3);
 SetOpIn(OpTable, $0F, 'CLR', AM_DIRECT, 6);

 { --- Inherent sur A $40-$4F --- }
 SetOpIn(OpTable, $40, 'NEGA', AM_INHERENT, 2);
 SetOpIn(OpTable, $43, 'COMA', AM_INHERENT, 2);
 SetOpIn(OpTable, $44, 'LSRA', AM_INHERENT, 2);
 SetOpIn(OpTable, $46, 'RORA', AM_INHERENT, 2);
 SetOpIn(OpTable, $47, 'ASRA', AM_INHERENT, 2);
 SetOpIn(OpTable, $48, 'ASLA', AM_INHERENT, 2);
 SetOpIn(OpTable, $49, 'ROLA', AM_INHERENT, 2);
 SetOpIn(OpTable, $4A, 'DECA', AM_INHERENT, 2);
 SetOpIn(OpTable, $4C, 'INCA', AM_INHERENT, 2);
 SetOpIn(OpTable, $4D, 'TSTA', AM_INHERENT, 2);
 SetOpIn(OpTable, $4F, 'CLRA', AM_INHERENT, 2);

 { --- Inherent sur B $50-$5F --- }
 SetOpIn(OpTable, $50, 'NEGB', AM_INHERENT, 2);
 SetOpIn(OpTable, $53, 'COMB', AM_INHERENT, 2);
 SetOpIn(OpTable, $54, 'LSRB', AM_INHERENT, 2);
 SetOpIn(OpTable, $56, 'RORB', AM_INHERENT, 2);
 SetOpIn(OpTable, $57, 'ASRB', AM_INHERENT, 2);
 SetOpIn(OpTable, $58, 'ASLB', AM_INHERENT, 2);
 SetOpIn(OpTable, $59, 'ROLB', AM_INHERENT, 2);
 SetOpIn(OpTable, $5A, 'DECB', AM_INHERENT, 2);
 SetOpIn(OpTable, $5C, 'INCB', AM_INHERENT, 2);
 SetOpIn(OpTable, $5D, 'TSTB', AM_INHERENT, 2);
 SetOpIn(OpTable, $5F, 'CLRB', AM_INHERENT, 2);

 { --- Operations memoire indexe $60-$6F --- }
 SetOpIn(OpTable, $60, 'NEG', AM_INDEXED, 6);
 SetOpIn(OpTable, $63, 'COM', AM_INDEXED, 6);
 SetOpIn(OpTable, $64, 'LSR', AM_INDEXED, 6);
 SetOpIn(OpTable, $66, 'ROR', AM_INDEXED, 6);
 SetOpIn(OpTable, $67, 'ASR', AM_INDEXED, 6);
 SetOpIn(OpTable, $68, 'ASL', AM_INDEXED, 6);
 SetOpIn(OpTable, $69, 'ROL', AM_INDEXED, 6);
 SetOpIn(OpTable, $6A, 'DEC', AM_INDEXED, 6);
 SetOpIn(OpTable, $6C, 'INC', AM_INDEXED, 6);
 SetOpIn(OpTable, $6D, 'TST', AM_INDEXED, 6);
 SetOpIn(OpTable, $6E, 'JMP', AM_INDEXED, 3);
 SetOpIn(OpTable, $6F, 'CLR', AM_INDEXED, 6);

 { --- Operations memoire etendu $70-$7F --- }
 SetOpIn(OpTable, $70, 'NEG', AM_EXTENDED, 7);
 SetOpIn(OpTable, $73, 'COM', AM_EXTENDED, 7);
 SetOpIn(OpTable, $74, 'LSR', AM_EXTENDED, 7);
 SetOpIn(OpTable, $76, 'ROR', AM_EXTENDED, 7);
 SetOpIn(OpTable, $77, 'ASR', AM_EXTENDED, 7);
 SetOpIn(OpTable, $78, 'ASL', AM_EXTENDED, 7);
 SetOpIn(OpTable, $79, 'ROL', AM_EXTENDED, 7);
 SetOpIn(OpTable, $7A, 'DEC', AM_EXTENDED, 7);
 SetOpIn(OpTable, $7C, 'INC', AM_EXTENDED, 7);
 SetOpIn(OpTable, $7D, 'TST', AM_EXTENDED, 7);
 SetOpIn(OpTable, $7E, 'JMP', AM_EXTENDED, 4);
 SetOpIn(OpTable, $7F, 'CLR', AM_EXTENDED, 7);

 { --- Divers inherent/immediat/relatif --- }
 SetOpIn(OpTable, $12, 'NOP',   AM_INHERENT, 2);
 SetOpIn(OpTable, $13, 'SYNC',  AM_INHERENT, 2);
 SetOpIn(OpTable, $16, 'LBRA',  AM_REL16, 5);
 SetOpIn(OpTable, $17, 'LBSR',  AM_REL16, 9);
 SetOpIn(OpTable, $19, 'DAA',   AM_INHERENT, 2);
 SetOpIn(OpTable, $1A, 'ORCC',  AM_IMMED8, 3);
 SetOpIn(OpTable, $1C, 'ANDCC', AM_IMMED8, 3);
 SetOpIn(OpTable, $1D, 'SEX',   AM_INHERENT, 2);
 SetOpIn(OpTable, $1E, 'EXG',   AM_IMMED_TFR, 8);
 SetOpIn(OpTable, $1F, 'TFR',   AM_IMMED_TFR, 6);

 { --- Branchements courts $20-$2F (ordre Motorola standard) --- }
 SetOpIn(OpTable, $20, 'BRA', AM_REL8, 3);
 SetOpIn(OpTable, $21, 'BRN', AM_REL8, 3);
 SetOpIn(OpTable, $22, 'BHI', AM_REL8, 3);
 SetOpIn(OpTable, $23, 'BLS', AM_REL8, 3);
 SetOpIn(OpTable, $24, 'BCC', AM_REL8, 3); { = BHS }
 SetOpIn(OpTable, $25, 'BCS', AM_REL8, 3); { = BLO }
 SetOpIn(OpTable, $26, 'BNE', AM_REL8, 3);
 SetOpIn(OpTable, $27, 'BEQ', AM_REL8, 3);
 SetOpIn(OpTable, $28, 'BVC', AM_REL8, 3);
 SetOpIn(OpTable, $29, 'BVS', AM_REL8, 3);
 SetOpIn(OpTable, $2A, 'BPL', AM_REL8, 3);
 SetOpIn(OpTable, $2B, 'BMI', AM_REL8, 3);
 SetOpIn(OpTable, $2C, 'BGE', AM_REL8, 3);
 SetOpIn(OpTable, $2D, 'BLT', AM_REL8, 3);
 SetOpIn(OpTable, $2E, 'BGT', AM_REL8, 3);
 SetOpIn(OpTable, $2F, 'BLE', AM_REL8, 3);

 SetOpIn(OpTable, $30, 'LEAX', AM_INDEXED, 4);
 SetOpIn(OpTable, $31, 'LEAY', AM_INDEXED, 4);
 SetOpIn(OpTable, $32, 'LEAS', AM_INDEXED, 4);
 SetOpIn(OpTable, $33, 'LEAU', AM_INDEXED, 4);
 SetOpIn(OpTable, $34, 'PSHS', AM_IMMED_PSH, 5);
 SetOpIn(OpTable, $35, 'PULS', AM_IMMED_PSH, 5);
 SetOpIn(OpTable, $36, 'PSHU', AM_IMMED_PSH, 5);
 SetOpIn(OpTable, $37, 'PULU', AM_IMMED_PSH, 5);
 SetOpIn(OpTable, $39, 'RTS',  AM_INHERENT, 5);
 SetOpIn(OpTable, $3A, 'ABX',  AM_INHERENT, 3);
 SetOpIn(OpTable, $3B, 'RTI',  AM_INHERENT, 6);
 SetOpIn(OpTable, $3C, 'CWAI', AM_IMMED8, 21); { legal/reel - voir disclosure ci-dessus }
 SetOpIn(OpTable, $3D, 'MUL',  AM_INHERENT, 11);
 SetOpIn(OpTable, $3F, 'SWI',  AM_INHERENT, 19);

 SetOpIn(OpTable, $8D, 'BSR', AM_REL8, 7);
 SetOpIn(OpTable, $9D, 'JSR', AM_DIRECT, 7);
 SetOpIn(OpTable, $AD, 'JSR', AM_INDEXED, 7);
 SetOpIn(OpTable, $BD, 'JSR', AM_EXTENDED, 8);

 { --- Groupe A : $80-$BF (immediat/direct/indexe/etendu) --- }
 SetOpIn(OpTable, $80, 'SUBA', AM_IMMED8, 2);  SetOpIn(OpTable, $90, 'SUBA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A0, 'SUBA', AM_INDEXED, 4); SetOpIn(OpTable, $B0, 'SUBA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $81, 'CMPA', AM_IMMED8, 2);  SetOpIn(OpTable, $91, 'CMPA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A1, 'CMPA', AM_INDEXED, 4); SetOpIn(OpTable, $B1, 'CMPA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $82, 'SBCA', AM_IMMED8, 2);  SetOpIn(OpTable, $92, 'SBCA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A2, 'SBCA', AM_INDEXED, 4); SetOpIn(OpTable, $B2, 'SBCA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $83, 'SUBD', AM_IMMED16, 4); SetOpIn(OpTable, $93, 'SUBD', AM_DIRECT, 6);
 SetOpIn(OpTable, $A3, 'SUBD', AM_INDEXED, 6); SetOpIn(OpTable, $B3, 'SUBD', AM_EXTENDED, 7);
 SetOpIn(OpTable, $84, 'ANDA', AM_IMMED8, 2);  SetOpIn(OpTable, $94, 'ANDA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A4, 'ANDA', AM_INDEXED, 4); SetOpIn(OpTable, $B4, 'ANDA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $85, 'BITA', AM_IMMED8, 2);  SetOpIn(OpTable, $95, 'BITA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A5, 'BITA', AM_INDEXED, 4); SetOpIn(OpTable, $B5, 'BITA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $86, 'LDA',  AM_IMMED8, 2);  SetOpIn(OpTable, $96, 'LDA',  AM_DIRECT, 4);
 SetOpIn(OpTable, $A6, 'LDA',  AM_INDEXED, 4); SetOpIn(OpTable, $B6, 'LDA',  AM_EXTENDED, 5);
                                                SetOpIn(OpTable, $97, 'STA',  AM_DIRECT, 4);
 SetOpIn(OpTable, $A7, 'STA',  AM_INDEXED, 4); SetOpIn(OpTable, $B7, 'STA',  AM_EXTENDED, 5);
 SetOpIn(OpTable, $88, 'EORA', AM_IMMED8, 2);  SetOpIn(OpTable, $98, 'EORA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A8, 'EORA', AM_INDEXED, 4); SetOpIn(OpTable, $B8, 'EORA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $89, 'ADCA', AM_IMMED8, 2);  SetOpIn(OpTable, $99, 'ADCA', AM_DIRECT, 4);
 SetOpIn(OpTable, $A9, 'ADCA', AM_INDEXED, 4); SetOpIn(OpTable, $B9, 'ADCA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $8A, 'ORA',  AM_IMMED8, 2);  SetOpIn(OpTable, $9A, 'ORA',  AM_DIRECT, 4);
 SetOpIn(OpTable, $AA, 'ORA',  AM_INDEXED, 4); SetOpIn(OpTable, $BA, 'ORA',  AM_EXTENDED, 5);
 SetOpIn(OpTable, $8B, 'ADDA', AM_IMMED8, 2);  SetOpIn(OpTable, $9B, 'ADDA', AM_DIRECT, 4);
 SetOpIn(OpTable, $AB, 'ADDA', AM_INDEXED, 4); SetOpIn(OpTable, $BB, 'ADDA', AM_EXTENDED, 5);
 SetOpIn(OpTable, $8C, 'CMPX', AM_IMMED16, 4); SetOpIn(OpTable, $9C, 'CMPX', AM_DIRECT, 6);
 SetOpIn(OpTable, $AC, 'CMPX', AM_INDEXED, 6); SetOpIn(OpTable, $BC, 'CMPX', AM_EXTENDED, 7);
 SetOpIn(OpTable, $8E, 'LDX',  AM_IMMED16, 3); SetOpIn(OpTable, $9E, 'LDX',  AM_DIRECT, 5);
 SetOpIn(OpTable, $AE, 'LDX',  AM_INDEXED, 5); SetOpIn(OpTable, $BE, 'LDX',  AM_EXTENDED, 6);
                                                SetOpIn(OpTable, $9F, 'STX',  AM_DIRECT, 5);
 SetOpIn(OpTable, $AF, 'STX',  AM_INDEXED, 5); SetOpIn(OpTable, $BF, 'STX',  AM_EXTENDED, 6);

 { --- Groupe B : $C0-$FF (immediat/direct/indexe/etendu) --- }
 SetOpIn(OpTable, $C0, 'SUBB', AM_IMMED8, 2);  SetOpIn(OpTable, $D0, 'SUBB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E0, 'SUBB', AM_INDEXED, 4); SetOpIn(OpTable, $F0, 'SUBB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C1, 'CMPB', AM_IMMED8, 2);  SetOpIn(OpTable, $D1, 'CMPB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E1, 'CMPB', AM_INDEXED, 4); SetOpIn(OpTable, $F1, 'CMPB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C2, 'SBCB', AM_IMMED8, 2);  SetOpIn(OpTable, $D2, 'SBCB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E2, 'SBCB', AM_INDEXED, 4); SetOpIn(OpTable, $F2, 'SBCB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C3, 'ADDD', AM_IMMED16, 4); SetOpIn(OpTable, $D3, 'ADDD', AM_DIRECT, 6);
 SetOpIn(OpTable, $E3, 'ADDD', AM_INDEXED, 6); SetOpIn(OpTable, $F3, 'ADDD', AM_EXTENDED, 7);
 SetOpIn(OpTable, $C4, 'ANDB', AM_IMMED8, 2);  SetOpIn(OpTable, $D4, 'ANDB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E4, 'ANDB', AM_INDEXED, 4); SetOpIn(OpTable, $F4, 'ANDB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C5, 'BITB', AM_IMMED8, 2);  SetOpIn(OpTable, $D5, 'BITB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E5, 'BITB', AM_INDEXED, 4); SetOpIn(OpTable, $F5, 'BITB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C6, 'LDB',  AM_IMMED8, 2);  SetOpIn(OpTable, $D6, 'LDB',  AM_DIRECT, 4);
 SetOpIn(OpTable, $E6, 'LDB',  AM_INDEXED, 4); SetOpIn(OpTable, $F6, 'LDB',  AM_EXTENDED, 5);
                                                SetOpIn(OpTable, $D7, 'STB',  AM_DIRECT, 4);
 SetOpIn(OpTable, $E7, 'STB',  AM_INDEXED, 4); SetOpIn(OpTable, $F7, 'STB',  AM_EXTENDED, 5);
 SetOpIn(OpTable, $C8, 'EORB', AM_IMMED8, 2);  SetOpIn(OpTable, $D8, 'EORB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E8, 'EORB', AM_INDEXED, 4); SetOpIn(OpTable, $F8, 'EORB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $C9, 'ADCB', AM_IMMED8, 2);  SetOpIn(OpTable, $D9, 'ADCB', AM_DIRECT, 4);
 SetOpIn(OpTable, $E9, 'ADCB', AM_INDEXED, 4); SetOpIn(OpTable, $F9, 'ADCB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $CA, 'ORB',  AM_IMMED8, 2);  SetOpIn(OpTable, $DA, 'ORB',  AM_DIRECT, 4);
 SetOpIn(OpTable, $EA, 'ORB',  AM_INDEXED, 4); SetOpIn(OpTable, $FA, 'ORB',  AM_EXTENDED, 5);
 SetOpIn(OpTable, $CB, 'ADDB', AM_IMMED8, 2);  SetOpIn(OpTable, $DB, 'ADDB', AM_DIRECT, 4);
 SetOpIn(OpTable, $EB, 'ADDB', AM_INDEXED, 4); SetOpIn(OpTable, $FB, 'ADDB', AM_EXTENDED, 5);
 SetOpIn(OpTable, $CC, 'LDD',  AM_IMMED16, 3); SetOpIn(OpTable, $DC, 'LDD',  AM_DIRECT, 5);
 SetOpIn(OpTable, $EC, 'LDD',  AM_INDEXED, 5); SetOpIn(OpTable, $FC, 'LDD',  AM_EXTENDED, 6);
                                                SetOpIn(OpTable, $DD, 'STD',  AM_DIRECT, 5);
 SetOpIn(OpTable, $ED, 'STD',  AM_INDEXED, 5); SetOpIn(OpTable, $FD, 'STD',  AM_EXTENDED, 6);
 SetOpIn(OpTable, $CE, 'LDU',  AM_IMMED16, 3); SetOpIn(OpTable, $DE, 'LDU',  AM_DIRECT, 5);
 SetOpIn(OpTable, $EE, 'LDU',  AM_INDEXED, 5); SetOpIn(OpTable, $FE, 'LDU',  AM_EXTENDED, 6);
                                                SetOpIn(OpTable, $DF, 'STU',  AM_DIRECT, 5);
 SetOpIn(OpTable, $EF, 'STU',  AM_INDEXED, 5); SetOpIn(OpTable, $FF, 'STU',  AM_EXTENDED, 6);
End;

Procedure InitOpTablePage2;
{ Prebyte $10 - verifiee contre M6809_StepPage2 (DEVENV.PAS) }
Var I: Integer;
Begin
 For I := 0 To 255 Do
 Begin
  OpTablePage2[I].Mnem := '???';
  OpTablePage2[I].Mode := AM_ILLEGAL;
  OpTablePage2[I].Legal := False;
  OpTablePage2[I].Min6309 := False;
 End;
 SetOpIn(OpTablePage2, $21, 'LBRN', AM_REL16, 5);
 SetOpIn(OpTablePage2, $22, 'LBHI', AM_REL16, 5);
 SetOpIn(OpTablePage2, $23, 'LBLS', AM_REL16, 5);
 SetOpIn(OpTablePage2, $24, 'LBCC', AM_REL16, 5); { = LBHS }
 SetOpIn(OpTablePage2, $25, 'LBCS', AM_REL16, 5); { = LBLO }
 SetOpIn(OpTablePage2, $26, 'LBNE', AM_REL16, 5);
 SetOpIn(OpTablePage2, $27, 'LBEQ', AM_REL16, 5);
 SetOpIn(OpTablePage2, $28, 'LBVC', AM_REL16, 5);
 SetOpIn(OpTablePage2, $29, 'LBVS', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2A, 'LBPL', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2B, 'LBMI', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2C, 'LBGE', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2D, 'LBLT', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2E, 'LBGT', AM_REL16, 5);
 SetOpIn(OpTablePage2, $2F, 'LBLE', AM_REL16, 5);
 SetOpIn(OpTablePage2, $3F, 'SWI2', AM_INHERENT, 20);
 SetOpIn(OpTablePage2, $83, 'CMPD', AM_IMMED16, 5); SetOpIn(OpTablePage2, $93, 'CMPD', AM_DIRECT, 7);
 SetOpIn(OpTablePage2, $A3, 'CMPD', AM_INDEXED, 7); SetOpIn(OpTablePage2, $B3, 'CMPD', AM_EXTENDED, 8);
 SetOpIn(OpTablePage2, $8C, 'CMPY', AM_IMMED16, 5); SetOpIn(OpTablePage2, $9C, 'CMPY', AM_DIRECT, 7);
 SetOpIn(OpTablePage2, $AC, 'CMPY', AM_INDEXED, 7); SetOpIn(OpTablePage2, $BC, 'CMPY', AM_EXTENDED, 8);
 SetOpIn(OpTablePage2, $8E, 'LDY',  AM_IMMED16, 4); SetOpIn(OpTablePage2, $9E, 'LDY',  AM_DIRECT, 6);
 SetOpIn(OpTablePage2, $AE, 'LDY',  AM_INDEXED, 6); SetOpIn(OpTablePage2, $BE, 'LDY',  AM_EXTENDED, 7);
                                                     SetOpIn(OpTablePage2, $9F, 'STY',  AM_DIRECT, 6);
 SetOpIn(OpTablePage2, $AF, 'STY',  AM_INDEXED, 6); SetOpIn(OpTablePage2, $BF, 'STY',  AM_EXTENDED, 7);
 SetOpIn(OpTablePage2, $CE, 'LDS',  AM_IMMED16, 4); SetOpIn(OpTablePage2, $DE, 'LDS',  AM_DIRECT, 6);
 SetOpIn(OpTablePage2, $EE, 'LDS',  AM_INDEXED, 6); SetOpIn(OpTablePage2, $FE, 'LDS',  AM_EXTENDED, 7);
                                                     SetOpIn(OpTablePage2, $DF, 'STS',  AM_DIRECT, 6);
 SetOpIn(OpTablePage2, $EF, 'STS',  AM_INDEXED, 6); SetOpIn(OpTablePage2, $FF, 'STS',  AM_EXTENDED, 7);
End;

Procedure InitOpTablePage3;
{ Prebyte $11 - verifiee contre M6809_StepPage3 (DEVENV.PAS) }
Var I: Integer;
Begin
 For I := 0 To 255 Do
 Begin
  OpTablePage3[I].Mnem := '???';
  OpTablePage3[I].Mode := AM_ILLEGAL;
  OpTablePage3[I].Legal := False;
  OpTablePage3[I].Min6309 := False;
 End;
 SetOpIn(OpTablePage3, $3F, 'SWI3', AM_INHERENT, 20);
 SetOpIn(OpTablePage3, $83, 'CMPU', AM_IMMED16, 5); SetOpIn(OpTablePage3, $93, 'CMPU', AM_DIRECT, 7);
 SetOpIn(OpTablePage3, $A3, 'CMPU', AM_INDEXED, 7); SetOpIn(OpTablePage3, $B3, 'CMPU', AM_EXTENDED, 8);
 SetOpIn(OpTablePage3, $8C, 'CMPS', AM_IMMED16, 5); SetOpIn(OpTablePage3, $9C, 'CMPS', AM_DIRECT, 7);
 SetOpIn(OpTablePage3, $AC, 'CMPS', AM_INDEXED, 7); SetOpIn(OpTablePage3, $BC, 'CMPS', AM_EXTENDED, 8);
End;

{ ============================================================================ }
{ TODO 05 - Extensions HD6309 (-cpu 6309)                                     }
{ ============================================================================ }

{ Portee HONNETEMENT disclosee (voir aussi -help) : CONTRAIREMENT a la table   }
{ 6809 ci-dessus (verifiee contre un emulateur reel et teste de ce depot),     }
{ cette extension 6309 n'a AUCUNE reference testee a comparer dans ce projet   }
{ (confirme : zero occurrence de "6309"/"HD6309" dans DEVENV.PAS) - elle       }
{ repose uniquement sur la documentation Hitachi publiee, de memoire, pour le  }
{ sous-ensemble le MIEUX etabli et le plus souvent documente du jeu natif      }
{ 6309 (TFM, DIVD/DIVQ/MULD, OIM/AIM/EIM/TIM, registres-a-registres ADDR/      }
{ SUBR/CMPR/ANDR/ORR/EORR/ADCR/SBCR, LDQ/STQ, BITMD/LDMD, SEXW,                }
{ PSHSW/PULSW/PSHUW/PULUW). Des opcodes 6309 natifs plus rares/obscurs         }
{ peuvent manquer ou necessiter une verification contre la documentation       }
{ Hitachi HD6309E authentique avant tout travail de retro-ingenierie serieux   }
{ sur une cartouche reellement ecrite pour 6309 natif (rare sur CoCo3 standard,}
{ le HD6309 etant un accelerateur tiers, pas le processeur de serie). }

Procedure SetOp6309(Var T: Array Of TOpEntry; Op: Byte; Const Mnem: String;
 Mode, Cyc: Byte);
Begin
 T[Op].Mnem    := Mnem;
 T[Op].Mode    := Mode;
 T[Op].Cyc     := Cyc;
 T[Op].Legal   := True;
 T[Op].Min6309 := True;
End;

Procedure InitOpTable6309;
Begin
 { --- Page de base : opcodes illegaux sur 6809, legaux sur 6309 --- }
 SetOp6309(OpTable, $01, 'OIM', AM_DIR_IMMED8, 6);
 SetOp6309(OpTable, $02, 'AIM', AM_DIR_IMMED8, 6);
 SetOp6309(OpTable, $05, 'EIM', AM_DIR_IMMED8, 6);
 SetOp6309(OpTable, $0B, 'TIM', AM_DIR_IMMED8, 6);
 SetOp6309(OpTable, $61, 'OIM', AM_IDX_IMMED8, 6);
 SetOp6309(OpTable, $62, 'AIM', AM_IDX_IMMED8, 6);
 SetOp6309(OpTable, $65, 'EIM', AM_IDX_IMMED8, 6);
 SetOp6309(OpTable, $6B, 'TIM', AM_IDX_IMMED8, 6);
 SetOp6309(OpTable, $71, 'OIM', AM_EXT_IMMED8, 7);
 SetOp6309(OpTable, $72, 'AIM', AM_EXT_IMMED8, 7);
 SetOp6309(OpTable, $75, 'EIM', AM_EXT_IMMED8, 7);
 SetOp6309(OpTable, $7B, 'TIM', AM_EXT_IMMED8, 7);
 SetOp6309(OpTable, $CD, 'LDQ', AM_IMMED16, 5); { en realite 32 bits - voir TODO 10 }

 { --- Page 2 ($10) : registres-a-registres, pile W, blocs TFM, D-ops --- }
 SetOp6309(OpTablePage2, $30, 'ADDR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $31, 'ADCR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $32, 'SUBR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $33, 'SBCR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $34, 'ANDR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $35, 'ORR',  AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $36, 'EORR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $37, 'CMPR', AM_IMMED_TFR, 4);
 SetOp6309(OpTablePage2, $38, 'PSHSW', AM_INHERENT, 6);
 SetOp6309(OpTablePage2, $39, 'PULSW', AM_INHERENT, 6);
 SetOp6309(OpTablePage2, $3A, 'PSHUW', AM_INHERENT, 6);
 SetOp6309(OpTablePage2, $3B, 'PULUW', AM_INHERENT, 6);
 SetOp6309(OpTablePage2, $40, 'NEGD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $43, 'COMD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $44, 'LSRD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $46, 'RORD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $47, 'ASRD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $48, 'ASLD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $49, 'ROLD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $4A, 'DECD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $4C, 'INCD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $4D, 'TSTD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $4F, 'CLRD', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $53, 'COME', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $5A, 'DECE', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $5C, 'INCE', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $5D, 'TSTE', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $5F, 'CLRE', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $63, 'COMF', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $6A, 'DECF', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $6C, 'INCF', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $6D, 'TSTF', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $6F, 'CLRF', AM_INHERENT, 3);
 SetOp6309(OpTablePage2, $80, 'SUBW', AM_IMMED16, 4); SetOp6309(OpTablePage2, $90, 'SUBW', AM_DIRECT, 6);
 SetOp6309(OpTablePage2, $A0, 'SUBW', AM_INDEXED, 6); SetOp6309(OpTablePage2, $B0, 'SUBW', AM_EXTENDED, 7);
 SetOp6309(OpTablePage2, $81, 'CMPW', AM_IMMED16, 4); SetOp6309(OpTablePage2, $91, 'CMPW', AM_DIRECT, 6);
 SetOp6309(OpTablePage2, $A1, 'CMPW', AM_INDEXED, 6); SetOp6309(OpTablePage2, $B1, 'CMPW', AM_EXTENDED, 7);
 SetOp6309(OpTablePage2, $86, 'LDW',  AM_IMMED16, 4); SetOp6309(OpTablePage2, $96, 'LDW',  AM_DIRECT, 6);
 SetOp6309(OpTablePage2, $A6, 'LDW',  AM_INDEXED, 6); SetOp6309(OpTablePage2, $B6, 'LDW',  AM_EXTENDED, 7);
 SetOp6309(OpTablePage2, $C6, 'LDE',  AM_IMMED8, 3);  SetOp6309(OpTablePage2, $D6, 'LDE',  AM_DIRECT, 5);
 SetOp6309(OpTablePage2, $E6, 'LDE',  AM_INDEXED, 5); SetOp6309(OpTablePage2, $F6, 'LDE',  AM_EXTENDED, 6);
 SetOp6309(OpTablePage2, $D7, 'STE',  AM_DIRECT, 5);  SetOp6309(OpTablePage2, $E7, 'STE',  AM_INDEXED, 5);
 SetOp6309(OpTablePage2, $F7, 'STE',  AM_EXTENDED, 6);
 SetOp6309(OpTablePage2, $DC, 'LDF',  AM_DIRECT, 5);  SetOp6309(OpTablePage2, $EC, 'LDF',  AM_INDEXED, 5);
 SetOp6309(OpTablePage2, $FC, 'LDF',  AM_EXTENDED, 6);
 SetOp6309(OpTablePage2, $DD, 'STF',  AM_DIRECT, 5);  SetOp6309(OpTablePage2, $ED, 'STF',  AM_INDEXED, 5);
 SetOp6309(OpTablePage2, $FD, 'STF',  AM_EXTENDED, 6);

 { --- Page 3 ($11) : OIM/AIM/EIM/TIM, TFM, DIV/MUL, BITMD/LDMD, SEXW --- }
 SetOp6309(OpTablePage3, $30, 'BAND',  AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $31, 'BIAND', AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $32, 'BOR',   AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $33, 'BIOR',  AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $34, 'BEOR',  AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $35, 'BIEOR', AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $36, 'LDBT',  AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $37, 'STBT',  AM_IMMED_TFR, 7);
 SetOp6309(OpTablePage3, $38, 'TFM',   AM_IMMED_TFM, 6); { R+,R+ }
 SetOp6309(OpTablePage3, $39, 'TFM',   AM_IMMED_TFM, 6); { R-,R- }
 SetOp6309(OpTablePage3, $3A, 'TFM',   AM_IMMED_TFM, 6); { R+,R  }
 SetOp6309(OpTablePage3, $3B, 'TFM',   AM_IMMED_TFM, 6); { R,R+  }
 SetOp6309(OpTablePage3, $3C, 'BITMD', AM_IMMED8, 4);
 SetOp6309(OpTablePage3, $3D, 'LDMD',  AM_IMMED8, 5);
 SetOp6309(OpTablePage3, $43, 'COMW',  AM_INHERENT, 3);
 SetOp6309(OpTablePage3, $4C, 'INCW',  AM_INHERENT, 3);
 SetOp6309(OpTablePage3, $46, 'RORW',  AM_INHERENT, 3);
 SetOp6309(OpTablePage3, $53, 'COMD',  AM_INHERENT, 3);
 SetOp6309(OpTablePage3, $5C, 'INCD',  AM_INHERENT, 3);
 SetOp6309(OpTablePage3, $80, 'SUBE',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $90, 'SUBE', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $A0, 'SUBE',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $B0, 'SUBE', AM_EXTENDED, 6);
 SetOp6309(OpTablePage3, $81, 'CMPE',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $91, 'CMPE', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $A1, 'CMPE',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $B1, 'CMPE', AM_EXTENDED, 6);
 SetOp6309(OpTablePage3, $83, 'CMPU',  AM_IMMED16, 5); { deja 6809 page3 - conserve }
 SetOp6309(OpTablePage3, $8B, 'ADDE',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $9B, 'ADDE', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $AB, 'ADDE',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $BB, 'ADDE', AM_EXTENDED, 6);
 SetOp6309(OpTablePage3, $8D, 'DIVD',  AM_IMMED8, 25); SetOp6309(OpTablePage3, $9D, 'DIVD', AM_DIRECT, 27);
 SetOp6309(OpTablePage3, $AD, 'DIVD',  AM_INDEXED, 27);SetOp6309(OpTablePage3, $BD, 'DIVD', AM_EXTENDED, 28);
 SetOp6309(OpTablePage3, $8E, 'DIVQ',  AM_IMMED16, 34);SetOp6309(OpTablePage3, $9E, 'DIVQ', AM_DIRECT, 36);
 SetOp6309(OpTablePage3, $AE, 'DIVQ',  AM_INDEXED, 36);SetOp6309(OpTablePage3, $BE, 'DIVQ', AM_EXTENDED, 37);
 SetOp6309(OpTablePage3, $8F, 'MULD',  AM_IMMED16, 28);SetOp6309(OpTablePage3, $9F, 'MULD', AM_DIRECT, 30);
 SetOp6309(OpTablePage3, $AF, 'MULD',  AM_INDEXED, 30);SetOp6309(OpTablePage3, $BF, 'MULD', AM_EXTENDED, 31);
 SetOp6309(OpTablePage3, $C0, 'SUBF',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $D0, 'SUBF', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $E0, 'SUBF',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $F0, 'SUBF', AM_EXTENDED, 6);
 SetOp6309(OpTablePage3, $C1, 'CMPF',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $D1, 'CMPF', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $E1, 'CMPF',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $F1, 'CMPF', AM_EXTENDED, 6);
 SetOp6309(OpTablePage3, $CB, 'ADDF',  AM_IMMED8, 3);  SetOp6309(OpTablePage3, $DB, 'ADDF', AM_DIRECT, 5);
 SetOp6309(OpTablePage3, $EB, 'ADDF',  AM_INDEXED, 5); SetOp6309(OpTablePage3, $FB, 'ADDF', AM_EXTENDED, 6);
End;

{ ============================================================================ }
{ TODO 06 - Decodage du mode indexe (postoctet, 18 sous-modes)                 }
{ ============================================================================ }

{ Agencement de bits VERIFIE par recherche dediee contre M6809_AmIndexed       }
{ (DEVENV.PAS), lui-meme conforme a la documentation Motorola authentique :    }
{   bit 7 = 0 : deplacement signe 5 bits DIRECT dans les bits 4-0 (bits 6-5    }
{               = registre RR) - jamais indirect, impossible a encoder.       }
{   bit 7 = 1 : RR = bits 6-5, bit 4 = indicateur indirect, bits 3-0 =         }
{               sous-mode (table ci-dessous).                                 }
{ RR : 0=X 1=Y 2=U 3=S.                                                        }
{ Sous-modes illegaux sur le VRAI 6809 (bits 3-0 = 7/A/E - non definis sur     }
{ silicium reel) : DISPAK les marque illegaux (contrairement a l'emulateur    }
{ M6809_* de ce projet, qui les traite par lenience comme ,R - ecart          }
{ assume, voir l'en-tete de fichier). ,R+ et ,-R indirects sont EGALEMENT      }
{ illegaux sur le vrai 6809 (seuls ,R++ et ,--R supportent l'indirection) ;    }
{ [,,addr] (sous-mode $F) exige le bit indirect (sa forme non-indirecte $8F    }
{ est reservee/illegale sur le vrai 6809, encore un ecart assume face a       }
{ l'emulateur, qui l'accepte par lenience). }

Function IdxRegName(RR: Byte): String;
Begin
 Case RR Of
  0: IdxRegName := 'X';
  1: IdxRegName := 'Y';
  2: IdxRegName := 'U';
 Else IdxRegName := 'S';
 End;
End;

Function SignExtend5(V: Byte): ShortInt;
Begin
 If (V And $10) <> 0 Then SignExtend5 := ShortInt(V Or $E0)
 Else SignExtend5 := ShortInt(V And $1F);
End;

{ Decode le mode indexe a partir de l'index Idx dans Rom[] (position du        }
{ postoctet). Retourne le texte d'operande formate, TotalBytes = nombre       }
{ TOTAL d'octets consommes (postoctet inclus), et Legal. }
Function DecodeIndexed(Idx: LongInt; Var TotalBytes: Integer; Var Legal: Boolean): String;
Var
 PB, RR, Sub: Byte;
 Indirect: Boolean;
 Reg, Res: String;
 Off8: ShortInt;
 Off16: Integer;
Begin
 Legal := True;
 TotalBytes := 1;
 Res := '???';
 PB := Rom[Idx];
 RR := (PB Shr 5) And $03;
 Reg := IdxRegName(RR);

 If (PB And $80) = 0 Then
 Begin
  Off8 := SignExtend5(PB And $1F);
  DecodeIndexed := IntToStr(Off8) + ',' + Reg;
  Exit;
 End;

 Indirect := (PB And $10) <> 0;
 Sub := PB And $0F;

 Case Sub Of
  $0: Begin Res := ',' + Reg + '+';  If Indirect Then Legal := False; End;
  $1: Res := ',' + Reg + '++';
  $2: Begin Res := ',-' + Reg;       If Indirect Then Legal := False; End;
  $3: Res := ',--' + Reg;
  $4: Res := ',' + Reg;
  $5: Res := 'B,' + Reg;
  $6: Res := 'A,' + Reg;
  $7: Legal := False;
  $8:
  Begin
   If Idx + 1 >= RomSize Then Begin Legal := False; DecodeIndexed := Res; Exit; End;
   Off8 := ShortInt(Rom[Idx + 1]);
   Inc(TotalBytes);
   Res := IntToStr(Off8) + ',' + Reg;
  End;
  $9:
  Begin
   If Idx + 2 >= RomSize Then Begin Legal := False; DecodeIndexed := Res; Exit; End;
   { Integer(Word(...)) reinterprete directement le motif de bits 16 bits   }
   { en signe (meme taille, Integer=16 bits sous $MODE TP) - deja le bon    }
   { deplacement signe, aucun ajustement manuel supplementaire requis. }
   Off16 := Integer(Word(Rom[Idx+1]) Shl 8 Or Rom[Idx+2]);
   Inc(TotalBytes, 2);
   Res := IntToStr(Off16) + ',' + Reg;
  End;
  $A: Legal := False;
  $B: Res := 'D,' + Reg;
  $C:
  Begin
   If Idx + 1 >= RomSize Then Begin Legal := False; DecodeIndexed := Res; Exit; End;
   Off8 := ShortInt(Rom[Idx + 1]);
   Inc(TotalBytes);
   Res := IntToStr(Off8) + ',PCR';
  End;
  $D:
  Begin
   If Idx + 2 >= RomSize Then Begin Legal := False; DecodeIndexed := Res; Exit; End;
   Off16 := Integer(Word(Rom[Idx+1]) Shl 8 Or Rom[Idx+2]);
   Inc(TotalBytes, 2);
   Res := IntToStr(Off16) + ',PCR';
  End;
  $E: Legal := False;
  $F:
  Begin
   If Not Indirect Then Legal := False;
   If Idx + 2 >= RomSize Then Begin Legal := False; DecodeIndexed := Res; Exit; End;
   Off16 := Integer(Word(Rom[Idx+1]) Shl 8 Or Rom[Idx+2]);
   Inc(TotalBytes, 2);
   Res := '$' + HexWord(Word(Off16));
  End;
 End;

 If Not Legal Then Begin DecodeIndexed := '???'; Exit; End;
 If Indirect Then Res := '[' + Res + ']';
 DecodeIndexed := Res;
End;

{ ============================================================================ }
{ TODO 10 - Decodeur d'une instruction (une passe, un point memoire)          }
{ ============================================================================ }

Const
 FLOW_NEXT   = 0;  { suite normale a Addr+Len }
 FLOW_BRANCH = 1;  { branchement conditionnel : suite ET cible possibles }
 FLOW_JUMP   = 2;  { branchement/saut inconditionnel : SEULEMENT la cible }
 FLOW_CALL   = 3;  { JSR/BSR : suite ET cible (cible = sous-routine) }
 FLOW_STOP   = 4;  { RTS/RTI/SWI/CWAI : aucune suite statiquement connue }

Type
 TDecodedInstr = Record
  Addr      : Word;
  Len       : Integer;
  Mnem      : String[8];
  Operand   : String;
  Cyc       : Byte;
  Legal     : Boolean;
  HasRef    : Boolean;
  RefAddr   : Word;
  IsSub     : Boolean;
  Flow      : Byte;
 End;

Function RegName8(Code: Byte): String;
{ Decodage registre pour postoctet TFR/EXG/ADDR/etc (6809/6309) }
Begin
 Case Code And $0F Of
  $0: RegName8 := 'D';  $1: RegName8 := 'X';  $2: RegName8 := 'Y';
  $3: RegName8 := 'U';  $4: RegName8 := 'S';  $5: RegName8 := 'PC';
  $8: RegName8 := 'A';  $9: RegName8 := 'B';  $A: RegName8 := 'CC';
  $B: RegName8 := 'DP';
  $6: RegName8 := 'W';  { HD6309 natif }
  $7: RegName8 := 'V';  { HD6309 natif }
  $E: RegName8 := '0';  { HD6309 constante zero implicite }
 Else RegName8 := '?';
 End;
End;

Function DecodePshMask(Mask: Byte; OnU: Boolean): String;
{ PSHS/PULS (OnU=False) ou PSHU/PULU (OnU=True) - ordre d'empilement        }
{ standard Motorola : PC,U-ou-S,Y,X,DP,B,A,CC (bit7..bit0). }
Var R: String;
Begin
 R := '';
 If (Mask And $80) <> 0 Then R := R + 'PC,';
 If (Mask And $40) <> 0 Then Begin If OnU Then R := R + 'S,' Else R := R + 'U,'; End;
 If (Mask And $20) <> 0 Then R := R + 'Y,';
 If (Mask And $10) <> 0 Then R := R + 'X,';
 If (Mask And $08) <> 0 Then R := R + 'DP,';
 If (Mask And $04) <> 0 Then R := R + 'B,';
 If (Mask And $02) <> 0 Then R := R + 'A,';
 If (Mask And $01) <> 0 Then R := R + 'CC,';
 If (Length(R) > 0) And (R[Length(R)] = ',') Then Delete(R, Length(R), 1);
 If R = '' Then R := '0'; { masque vide - rarissime mais syntaxiquement valide }
 DecodePshMask := R;
End;

{ Decode UNE instruction a l'adresse Addr. Retourne False si Addr hors de la  }
{ zone chargee (HasByte). DI.Legal=False si l'opcode (ou le postoctet         }
{ indexe) est illegal/inconnu - dans ce cas DI.Len=1 (traite comme un seul    }
{ octet de donnees par l'appelant, jamais invente). }
Function DecodeOne(Addr: Word; Var DI: TDecodedInstr): Boolean;
Var
 Idx: LongInt;
 B0, B1: Byte;
 Op: ^TOpEntry;
 HeaderLen: Integer;
 Rel: ShortInt;
 Rel16: Integer;
 IdxLegal: Boolean;
 IdxBytes: Integer;
 ImmByte: Byte;
 FullAddr: Word;
Begin
 DecodeOne := False;
 FillChar(DI, SizeOf(DI), 0);
 DI.Addr := Addr;
 If Not HasByte[Addr] Then Exit;
 Idx := LongInt(Addr) - LongInt(LoadAddr);

 B0 := Rom[Idx];
 If (B0 = $10) And HasByte[Word(Addr + 1)] Then
 Begin
  B1 := Rom[Idx + 1];
  Op := @OpTablePage2[B1];
  HeaderLen := 2;
 End
 Else If (B0 = $11) And HasByte[Word(Addr + 1)] Then
 Begin
  B1 := Rom[Idx + 1];
  Op := @OpTablePage3[B1];
  HeaderLen := 2;
 End
 Else
 Begin
  Op := @OpTable[B0];
  HeaderLen := 1;
 End;

 DecodeOne := True;

 If (Not Op^.Legal) Or (Op^.Min6309 And (Opts.Cpu = CPU_6809)) Then
 Begin
  DI.Legal := False;
  DI.Len   := 1;
  DI.Mnem  := 'FCB';
  DI.Operand := '$' + HexByte(B0);
  DI.Flow  := FLOW_STOP;
  Exit;
 End;

 DI.Legal := True;
 DI.Mnem  := Op^.Mnem;
 DI.Cyc   := Op^.Cyc;
 DI.Len   := HeaderLen;
 DI.Flow  := FLOW_NEXT;

 Case Op^.Mode Of

  AM_INHERENT:
  Begin
   DI.Operand := '';
   If (DI.Mnem = 'RTS') Or (DI.Mnem = 'RTI') Or (DI.Mnem = 'SWI') Or
      (DI.Mnem = 'SWI2') Or (DI.Mnem = 'SWI3') Then DI.Flow := FLOW_STOP;
  End;

  AM_DIRECT:
  Begin
   If Not HasByte[Word(Addr + DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   If Opts.DirectPageSet Then
   Begin
    FullAddr := Word((Opts.DirectPage Shl 8) Or ImmByte);
    DI.HasRef := True;
    DI.RefAddr := FullAddr;
    DI.Operand := '<$' + HexByte(ImmByte);
   End
   Else
    DI.Operand := '<$' + HexByte(ImmByte);
   If DI.Mnem = 'JMP' Then
   Begin
    DI.Flow := FLOW_JUMP;
    If Not DI.HasRef Then DI.Flow := FLOW_STOP; { cible inconnue sans -directpage }
   End
   Else If DI.Mnem = 'JSR' Then
   Begin
    DI.Flow := FLOW_CALL;
    DI.IsSub := True;
    If Not DI.HasRef Then DI.Flow := FLOW_NEXT; { cible inconnue : on continue quand meme en suite }
   End;
  End;

  AM_EXTENDED:
  Begin
   If Not (HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)]) Then
   Begin DI.Legal := False; DI.Len := 1; Exit; End;
   FullAddr := Word((Word(Rom[Idx+DI.Len]) Shl 8) Or Rom[Idx+DI.Len+1]);
   Inc(DI.Len, 2);
   DI.HasRef := True;
   DI.RefAddr := FullAddr;
   DI.Operand := '$' + HexWord(FullAddr);
   If DI.Mnem = 'JMP' Then DI.Flow := FLOW_JUMP
   Else If DI.Mnem = 'JSR' Then Begin DI.Flow := FLOW_CALL; DI.IsSub := True; End;
  End;

  AM_INDEXED:
  Begin
   DI.Operand := DecodeIndexed(Idx + DI.Len, IdxBytes, IdxLegal);
   If Not IdxLegal Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   Inc(DI.Len, IdxBytes);
   If DI.Mnem = 'JMP' Then DI.Flow := FLOW_STOP  { cible dynamique, non resoluble statiquement }
   Else If DI.Mnem = 'JSR' Then Begin DI.Flow := FLOW_NEXT; DI.IsSub := True; End;
  End;

  AM_IMMED8:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   DI.Operand := '#$' + HexByte(ImmByte);
   If DI.Mnem = 'CWAI' Then DI.Flow := FLOW_STOP;
  End;

  AM_IMMED16:
  Begin
   If Not (HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)]) Then
   Begin DI.Legal := False; DI.Len := 1; Exit; End;
   FullAddr := Word((Word(Rom[Idx+DI.Len]) Shl 8) Or Rom[Idx+DI.Len+1]);
   Inc(DI.Len, 2);
   DI.Operand := '#$' + HexWord(FullAddr);
   If DI.Mnem = 'LDQ' Then
   Begin
    { HD6309 : LDQ charge 32 bits - 2 octets supplementaires non modelises  }
    { en detail (voir disclosure TODO 05) ; affiche les 16 bits de poids    }
    { fort recus, et consomme les 2 octets restants comme donnees brutes    }
    { pour garder une longueur d'instruction correcte. }
    If HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)] Then
     Inc(DI.Len, 2);
   End;
  End;

  AM_REL8:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   Rel := ShortInt(Rom[Idx + DI.Len]);
   Inc(DI.Len);
   FullAddr := Word(LongInt(Addr) + DI.Len + Rel);
   DI.HasRef := True;
   DI.RefAddr := FullAddr;
   DI.Operand := '$' + HexWord(FullAddr);
   If DI.Mnem = 'BRA' Then DI.Flow := FLOW_JUMP
   Else If DI.Mnem = 'BSR' Then Begin DI.Flow := FLOW_CALL; DI.IsSub := True; End
   Else DI.Flow := FLOW_BRANCH;
  End;

  AM_REL16:
  Begin
   If Not (HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)]) Then
   Begin DI.Legal := False; DI.Len := 1; Exit; End;
   Rel16 := Integer(Word(Rom[Idx+DI.Len]) Shl 8 Or Rom[Idx+DI.Len+1]);
   Inc(DI.Len, 2);
   FullAddr := Word(LongInt(Addr) + DI.Len + Rel16);
   DI.HasRef := True;
   DI.RefAddr := FullAddr;
   DI.Operand := '$' + HexWord(FullAddr);
   If DI.Mnem = 'LBRA' Then DI.Flow := FLOW_JUMP
   Else If DI.Mnem = 'LBSR' Then Begin DI.Flow := FLOW_CALL; DI.IsSub := True; End
   Else DI.Flow := FLOW_BRANCH;
  End;

  AM_IMMED_TFR:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   DI.Operand := RegName8(ImmByte Shr 4) + ',' + RegName8(ImmByte);
  End;

  AM_IMMED_PSH:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   DI.Operand := DecodePshMask(ImmByte, (DI.Mnem = 'PSHU') Or (DI.Mnem = 'PULU'));
  End;

  AM_IMMED_TFM:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   { Le sens de TFM depend de l'opcode (B1 = octet reel apres le prebyte     }
   { $11), pas du postoctet : $38=R+,R+  $39=R-,R-  $3A=R+,R  $3B=R,R+. }
   Case B1 Of
    $38: DI.Operand := RegName8(ImmByte Shr 4) + '+,' + RegName8(ImmByte) + '+';
    $39: DI.Operand := RegName8(ImmByte Shr 4) + '-,' + RegName8(ImmByte) + '-';
    $3A: DI.Operand := RegName8(ImmByte Shr 4) + '+,' + RegName8(ImmByte);
    $3B: DI.Operand := RegName8(ImmByte Shr 4) + ',' + RegName8(ImmByte) + '+';
   Else
    DI.Operand := RegName8(ImmByte Shr 4) + ',' + RegName8(ImmByte);
   End;
  End;

  AM_DIR_IMMED8:
  Begin
   If Not (HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)]) Then
   Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   B1 := Rom[Idx + DI.Len];
   Inc(DI.Len);
   DI.Operand := '#$' + HexByte(ImmByte) + ',<$' + HexByte(B1);
  End;

  AM_IDX_IMMED8:
  Begin
   If Not HasByte[Word(Addr+DI.Len)] Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   DI.Operand := DecodeIndexed(Idx + DI.Len, IdxBytes, IdxLegal);
   If Not IdxLegal Then Begin DI.Legal := False; DI.Len := 1; Exit; End;
   Inc(DI.Len, IdxBytes);
   DI.Operand := '#$' + HexByte(ImmByte) + ',' + DI.Operand;
  End;

  AM_EXT_IMMED8:
  Begin
   If Not (HasByte[Word(Addr+DI.Len)] And HasByte[Word(Addr+DI.Len+1)] And
           HasByte[Word(Addr+DI.Len+2)]) Then
   Begin DI.Legal := False; DI.Len := 1; Exit; End;
   ImmByte := Rom[Idx + DI.Len];
   Inc(DI.Len);
   FullAddr := Word((Word(Rom[Idx+DI.Len]) Shl 8) Or Rom[Idx+DI.Len+1]);
   Inc(DI.Len, 2);
   DI.HasRef := True;
   DI.RefAddr := FullAddr;
   DI.Operand := '#$' + HexByte(ImmByte) + ',$' + HexWord(FullAddr);
  End;

 Else
  Begin DI.Legal := False; DI.Len := 1; End;
 End;
End;

{ ============================================================================ }
{ TODO 11 - Passe 1 : desassemblage recursif, decouverte code/donnees         }
{ ============================================================================ }

{ Algorithme de "desassemblage recursif" standard (par opposition a un        }
{ simple balayage lineaire octet-par-octet) : part du point d'entree, suit    }
{ chaque branchement/appel/saut dont la cible est STATIQUEMENT connue,        }
{ s'arrete a RTS/RTI/SWI/branchement inconditionnel ou cible dynamique        }
{ (indexee). Tout octet jamais atteint par ce parcours reste "donnee" en      }
{ sortie (FCB/FDB) - exactement la distinction code/donnees que l'utilisateur }
{ a identifiee comme la vraie difficulte d'un desassembleur de cartouche. }

Procedure MarkRegion(Addr: Word; Len: Integer; Kind: Byte);
Var I: Integer;
Begin
 Region[Addr] := Kind;
 For I := 1 To Len - 1 Do
  Region[Word(Addr + I)] := RGN_OPERAND;
End;

Procedure QueuePending(Addr: Word);
Begin
 If Not HasByte[Addr] Then Exit;
 If Region[Addr] <> RGN_UNKNOWN Then Exit;
 If PendingCount >= MAX_PENDING Then Exit;
 Inc(PendingCount);
 Pending[PendingCount] := Addr;
End;

Procedure RunPass1;
Var
 Addr: Word;
 DI: TDecodedInstr;
 StartAddr: Word;
Begin
 FillChar(Region, SizeOf(Region), RGN_UNKNOWN);
 LabelCount := 0;
 PendingCount := 0;
 InstrCount := 0;

 If Opts.SymbolFile <> '' Then LoadSymbolFile(Opts.SymbolFile);

 If Opts.EntrySet Then StartAddr := Opts.EntryAddr Else StartAddr := LoadAddr;

 If Opts.AutoMode Then
 Begin
  If Opts.DoLabels Then AddLabel(StartAddr, False);
  QueuePending(StartAddr);
  While PendingCount > 0 Do
  Begin
   Addr := Pending[PendingCount];
   Dec(PendingCount);
   If Region[Addr] <> RGN_UNKNOWN Then Continue;
   While HasByte[Addr] And (Region[Addr] = RGN_UNKNOWN) Do
   Begin
    If Opts.EndSet And (Addr > Opts.EndAddr) Then Break;
    If Not DecodeOne(Addr, DI) Then Break;
    MarkRegion(Addr, DI.Len, RGN_CODE);
    Inc(InstrCount);
    If DI.HasRef Then
    Begin
     If Opts.DoLabels Then
     Begin
      AddLabel(DI.RefAddr, DI.IsSub);
      AddXref(DI.RefAddr, Addr);
     End;
     If (DI.Flow = FLOW_BRANCH) Or (DI.Flow = FLOW_CALL) Or (DI.Flow = FLOW_JUMP) Then
      QueuePending(DI.RefAddr);
    End;
    If (DI.Flow = FLOW_JUMP) Or (DI.Flow = FLOW_STOP) Or (Not DI.Legal) Then Break;
    Addr := Word(Addr + DI.Len);
   End;
  End;
 End
 Else
 Begin
  { Sans -auto : balayage lineaire simple, du debut (ou -entry) a la fin    }
  { (ou -end) - plus simple, mais risque de desassembler des donnees comme  }
  { si elles etaient du code, disclose dans -help. }
  Addr := StartAddr;
  While HasByte[Addr] Do
  Begin
   If Opts.EndSet And (Addr > Opts.EndAddr) Then Break;
   If Not DecodeOne(Addr, DI) Then Break;
   MarkRegion(Addr, DI.Len, RGN_CODE);
   Inc(InstrCount);
   If DI.HasRef And Opts.DoLabels Then
   Begin
    AddLabel(DI.RefAddr, DI.IsSub);
    AddXref(DI.RefAddr, Addr);
   End;
   Addr := Word(Addr + DI.Len);
  End;
 End;

 If Opts.DoData Then
  For Addr := 0 To $FFFE Do
   If HasByte[Addr] And (Region[Addr] = RGN_UNKNOWN) Then Region[Addr] := RGN_DATA;
 DataByteCount := 0;
 For Addr := 0 To $FFFE Do
  If HasByte[Addr] And ((Region[Addr] = RGN_UNKNOWN) Or (Region[Addr] = RGN_DATA)) Then
   Inc(DataByteCount);
End;

{ ============================================================================ }
{ TODO 12 - Passe 2 : emission du texte assembleur/listing                    }
{ ============================================================================ }

Procedure EmitLine(Const S: String);
Begin
 If OutOpened Then WriteLn(OutText, S) Else WriteLn(S);
End;

Function CommentForInstr(Const DI: TDecodedInstr): String;
Var HwIdx: Integer; BasicC: String;
Begin
 CommentForInstr := '';
 If Not DI.HasRef Then Exit;
 If Opts.DoHardware Or Opts.DoGime Or Opts.DoSam Or Opts.DoPia Then
 Begin
  HwIdx := FindHw(DI.RefAddr);
  If HwIdx <> 0 Then
  Begin
   CommentForInstr := HwTable[HwIdx].Name + ' : ' + HwTable[HwIdx].Desc;
   Exit;
  End;
 End;
 If Opts.DoBasic Then
 Begin
  BasicC := BasicRangeComment(DI.RefAddr);
  If BasicC <> '' Then Begin CommentForInstr := BasicC; Exit; End;
 End;
End;

Function OperandWithLabel(Const DI: TDecodedInstr): String;
{ Remplace le texte hexadecimal brut de l'operande par le nom d'etiquette    }
{ connu, pour les modes qui referencent une adresse resolue (EXTENDED/REL). }
Var Idx: Integer;
Begin
 OperandWithLabel := DI.Operand;
 If Not DI.HasRef Then Exit;
 If Not Opts.DoLabels Then Exit;
 Idx := FindLabel(DI.RefAddr);
 If Idx = 0 Then Exit;
 { Seuls les operandes "$XXXX" purs (EXTENDED/REL/REL16) sont remplaces -   }
 { DIRECT (<$XX) et les operandes composes (indexe, OIM/AIM/etc.) gardent   }
 { leur forme hexadecimale, la substitution textuelle y serait ambigue. }
 If (Length(DI.Operand) = 5) And (DI.Operand[1] = '$') Then
  OperandWithLabel := Labels[Idx].Name;
End;

Procedure EmitEquates;
Var I: Integer;
Begin
 If Not Opts.DoEquates Then Exit;
 EmitLine('; --- Equates materiels CoCo3 ---');
 For I := 1 To HwCount Do
  EmitLine(PadRight(HwTable[I].Name, 16) + 'EQU     $' + HexWord(HwTable[I].Addr));
 EmitLine('');
End;

Procedure EmitDataRun(StartAddr: Word; Len: Integer);
{ Emet une serie d'octets consecutifs non decodes comme instruction, sous    }
{ forme de lignes FCB (8 octets/ligne au plus, convention de listing usuelle).}
Var
 I, Col: Integer;
 Line, LblPart: String;
 A: Word;
Begin
 I := 0;
 While I < Len Do
 Begin
  A := Word(StartAddr + I);
  LblPart := '';
  If Opts.DoLabels And (FindLabel(A) <> 0) Then LblPart := LabelName(A) + ':';
  Line := PadRight(LblPart, 10) + 'FCB     ';
  Col := 0;
  While (I < Len) And (Col < 8) Do
  Begin
   If Col > 0 Then Line := Line + ',';
   Line := Line + '$' + HexByte(Rom[LongInt(StartAddr - LoadAddr) + I]);
   Inc(I);
   Inc(Col);
  End;
  EmitLine(Line);
 End;
End;

Procedure EmitXrefTable;
Var I, J: Integer; Line: String;
Begin
 If Not Opts.DoXref Then Exit;
 EmitLine('');
 EmitLine('; --- References croisees ---');
 For I := 1 To LabelCount Do
  If Labels[I].RefCount > 0 Then
  Begin
   Line := '; ' + PadRight(Labels[I].Name, 16) + '$' + HexWord(Labels[I].Addr) +
    '  referencee depuis : ';
   For J := 1 To Labels[I].RefCount Do
   Begin
    If J > 1 Then Line := Line + ', ';
    Line := Line + '$' + HexWord(Labels[I].RefFrom[J]);
   End;
   EmitLine(Line);
  End;
End;

Procedure RunPass2;
Var
 Addr: Word;
 DI: TDecodedInstr;
 Line, LblPart, OperPart, CommentPart, BytesPart: String;
 RunStart: Word;
 RunLen: Integer;
 I: Integer;
Begin
 OutOpened := False;
 If Opts.OutFile <> '' Then
 Begin
  Assign(OutText, Opts.OutFile);
  {$I-} Rewrite(OutText); {$I+}
  If IOResult <> 0 Then
  Begin
   WriteLn('Erreur : impossible de creer le fichier de sortie ', Opts.OutFile);
   Exit;
  End;
  OutOpened := True;
 End;

 If Opts.OutFormat = FMT_ASM Then
 Begin
  EmitLine('; Desassemblage genere par DISPAK');
  EmitLine('; Source : ' + Opts.PakFile);
  EmitLine('; CPU    : ' + Copy('680963090', 1 + Opts.Cpu * 4, 4));
  EmitLine('');
  EmitEquates;
  EmitLine('        ORG     $' + HexWord(LoadAddr));
  EmitLine('');
 End;

 Addr := LoadAddr;
 While LongInt(Addr) < LongInt(LoadAddr) + RomSize Do
 Begin
  If Region[Addr] = RGN_CODE Then
  Begin
   If Not DecodeOne(Addr, DI) Then Break;

   LblPart := '';
   If Opts.DoLabels And (FindLabel(Addr) <> 0) Then LblPart := LabelName(Addr) + ':';

   OperPart := OperandWithLabel(DI);
   CommentPart := '';
   If Opts.DoComments Then CommentPart := CommentForInstr(DI);

   BytesPart := '';
   If Opts.DoBytes Or (Opts.OutFormat = FMT_LST) Then
   Begin
    For I := 0 To DI.Len - 1 Do
     BytesPart := BytesPart + HexByte(Rom[LongInt(Addr - LoadAddr) + I]) + ' ';
   End;

   Case Opts.OutFormat Of
    FMT_LST:
     Line := '$' + HexWord(Addr) + '  ' + PadRight(Trim(BytesPart), 13) + '  ' +
      PadRight(LblPart, 9) + PadRight(DI.Mnem, 8) + PadRight(OperPart, 14);
    FMT_TXT:
     Line := '$' + HexWord(Addr) + ': ' + DI.Mnem + ' ' + OperPart;
   Else { FMT_ASM }
    Begin
     Line := PadRight(LblPart, 9) + PadRight(DI.Mnem, 8) + OperPart;
     If Opts.DoBytes Then Line := Line + PadRight('', 14 - Length(OperPart)) +
      '; ' + Trim(BytesPart);
    End;
   End;

   If Opts.DoCycles And (Opts.OutFormat <> FMT_TXT) Then
    Line := Line + '  ; ~' + IntToStr(DI.Cyc) + ' cycles';
   If (CommentPart <> '') And (Opts.OutFormat <> FMT_TXT) Then
    Line := Line + '  ; ' + CommentPart;

   EmitLine(Line);
   Addr := Word(Addr + DI.Len);
  End
  Else
  Begin
   { Zone de donnees : regrouper tous les octets consecutifs non-CODE en    }
   { une seule serie FCB plutot qu'une ligne par octet. }
   RunStart := Addr;
   RunLen := 0;
   While (LongInt(Addr) < LongInt(LoadAddr) + RomSize) And
         (Region[Addr] <> RGN_CODE) And (Region[Addr] <> RGN_OPERAND) Do
   Begin
    Inc(RunLen);
    Addr := Word(Addr + 1);
   End;
   If RunLen > 0 Then
   Begin
    If Opts.OutFormat = FMT_ASM Then EmitDataRun(RunStart, RunLen)
    Else
    Begin
     Line := '$' + HexWord(RunStart) + '  (' + IntToStr(RunLen) + ' octets de donnees)';
     EmitLine(Line);
    End;
   End
   Else
    Addr := Word(Addr + 1); { securite anti-boucle infinie (RGN_OPERAND isole) }
  End;
 End;

 If Opts.OutFormat = FMT_ASM Then
 Begin
  EmitLine('');
  If Opts.EntrySet Then EmitLine('        END     ' + LabelName(Opts.EntryAddr))
  Else EmitLine('        END');
 End;

 EmitXrefTable;

 If OutOpened Then Close(OutText);
End;

Procedure Bilan;
Begin
 If Opts.Quiet Then Exit;
 WriteLn;
 WriteLn('DISPAK - Desassemblage termine');
 WriteLn('Fichier .PAK     : ', Opts.PakFile);
 If Opts.OutFile <> '' Then WriteLn('Fichier de sortie : ', Opts.OutFile);
 WriteLn('CPU cible         : ', Copy('680963090', 1 + Opts.Cpu * 4, 4));
 WriteLn('Octets charges    : ', RomSize);
 WriteLn('Instructions      : ', InstrCount);
 WriteLn('Octets de donnees : ', DataByteCount);
 WriteLn('Etiquettes        : ', LabelCount);
 WriteLn('Erreurs           : ', ErrorCount);
End;

{ ============================================================================ }
{ Orchestration (fin de TODO 14)                                              }
{ ============================================================================ }

Procedure Run;
Begin
 ParseArgs;

 If Opts.PakFile = '' Then Begin ShowHelp; Halt(1); End;
 If Not FileExists(Opts.PakFile) Then
 Begin
  WriteLn('Erreur : fichier introuvable : ', Opts.PakFile);
  Halt(2);
 End;

 ErrorCount := 0;
 InstrCount := 0;
 DataByteCount := 0;
 LabelCount := 0;

 If Not LoadPakFile Then Begin Halt(2); End;
 If Opts.InfoOnly Then Halt(0);

 If Opts.Validate And (Opts.PakMode <> PAK_RAW) Then
 Begin
  { LoadPakFile a deja valide si un en-tete Vavasour a ete detecte/force ;   }
  { rien de plus a faire ici, -validate agit au chargement (TODO 02). }
 End;

 InitHwTable;
 InitOpTableBase;
 InitOpTablePage2;
 InitOpTablePage3;
 If Opts.Cpu = CPU_6309 Then InitOpTable6309;

 RunPass1;
 { -strings s'execute APRES la passe 1 (code/donnees deja distingues) -     }
 { voir la disclosure dans ScanStrings. }
 If Opts.DoStrings Then ScanStrings;
 RunPass2;
 Bilan;

 If Opts.Verbose Then
  WriteLn('(mode -verbose : aucun detail supplementaire au-dela du bilan dans cette version)');

 If ErrorCount > 0 Then Halt(1) Else Halt(0);
End;

{ ============================================================================ }
{ Programme principal                                                         }
{ ============================================================================ }

BEGIN
 { /? est la convention Windows courante, en plus des formes -h/--help     }
 { deja presentes (voir aussi le meme patron dans DEVENV.PAS lui-meme) -    }
 { verifiee ICI (avant ParseArgs) ET dans ParseArgs (ou que /? apparaisse   }
 { dans la ligne), puisque sans '-' en tete, ParseArgs l'aurait sinon       }
 { avale a tort comme s'il s'agissait du nom du fichier .pak positionnel. }
 If (ParamCount = 0) Or (UpCaseStr(ParamStr(1)) = '-H') Or
    (UpCaseStr(ParamStr(1)) = '--HELP') Or (UpCaseStr(ParamStr(1)) = '/?') Or
    (UpCaseStr(ParamStr(1)) = '/H') Then
 Begin
  ShowHelp;
  Halt(0);
 End;
 If (UpCaseStr(ParamStr(1)) = '-V') Or (UpCaseStr(ParamStr(1)) = '--VERSION') Then
 Begin
  ShowVersion;
  Halt(0);
 End;
 Run;
END.
