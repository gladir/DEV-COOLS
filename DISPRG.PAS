{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Desassembleur de fichiers .PRG (Atari ST, Motorola 68000)
                genere un fichier de sortie .S (assembleur 68000)
  @license: MIT
}

(* ============================================================
  DISPRG.PAS - Desassembleur de fichiers .PRG Atari ST
  Turbo Pascal / Free Pascal (-Mtp)

  Le format .PRG est le format executable natif de l Atari ST
  sous TOS (The Operating System). Il contient du code machine
  Motorola 68000 avec un en-tete de 28 octets, des sections
  TEXT (code), DATA (donnees initialisees), BSS (donnees non
  initialisees), une table des symboles DRI et une table de
  relocalisation.

  Usage :
    DISPRG fichier.prg [-o sortie.s] [-v] [-hex] [-sym] [-reloc] [-data]

  Options :
    -o nom     : specifier le nom du fichier de sortie .S
    -v         : mode verbeux (afficher details de l en-tete et des sections)
    -hex       : inclure les octets hexadecimaux en commentaire
    -sym       : afficher la table des symboles DRI
    -reloc     : afficher la table de relocalisation
    -data      : desassembler aussi la section DATA

  Voir DOC/PRG_FORMAT.txt pour la description complete du format .PRG.
  Voir DOC/ASM_68000.txt pour le jeu d instructions du Motorola 68000.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
            DISPRG_VERSION ('1.0') et DISPRG_DATE ('2026-04-02')
            Constantes : PRG_MAGIC ($601A), MAX_SYMBOLS (8192),
              MAX_RELOCS (65536), MAX_LABELS (65536), MAX_XREFS (65536),
              BUFFER_SIZE (65536), MAX_IMAGE_SIZE (4 Mo)
            Codes de retour : EXIT_OK = 0, EXIT_ERROR = 1, EXIT_USAGE = 2
            TOptions : SrcFile, OutFile, Verbose, HexDump, ShowSymbols,
              ShowRelocs, DisasmData
            Procedure FatalError(Msg: String)
            Procedure ShowVersion
            Procedure ShowHelp
            Procedure InitOptions(Var Opts: TOptions)
            Procedure ParseCommandLine(Var Opts: TOptions)
            Function UpCaseStr(S: String): String
            Function HexByte(B: Byte): String
            Function HexWord(W: Word): String
            Function HexLong(L: LongInt): String
            Function IntToStr(N: LongInt): String
            Function FileExists(FileName: String): Boolean
            Function ChangeFileExt(FileName, NewExt: String): String

  TODO 02 - LECTURE ET VALIDATION DE L'EN-TETE PRG [IMPLEMENTE]
            Lire les 28 octets de l en-tete : ph_branch ($601A),
            ph_tlen, ph_dlen, ph_blen, ph_slen, ph_res1,
            ph_prgflags, ph_absflag. Valider la signature $601A.
            Convertir les valeurs big-endian en little-endian.
            Afficher un resume de l en-tete si -v est active.

  TODO 03 - CONVERSION BIG-ENDIAN / LITTLE-ENDIAN [IMPLEMENTE]
            SwapWord, SwapLong, ReadBEWord, ReadBELong,
            ReadBEWordMem, ReadBELongMem.

  TODO 04 - CHARGEMENT DES SECTIONS EN MEMOIRE [A FAIRE]
            Charger TEXT, DATA et la table des symboles dans un
            tampon dynamique. Calculer les offsets de chaque section.

  TODO 05 - LECTURE DE LA TABLE DES SYMBOLES DRI [A FAIRE]
            Entrees de 14 octets : sym_name (8 car), sym_type (Word),
            sym_value (LongInt). Decoder les types ($0001 defini,
            $0004 global, $0040 TEXT, $0020 DATA, $0080 BSS, etc.).

  TODO 06 - LECTURE DE LA TABLE DE RELOCALISATION [A FAIRE]
            Premier mot long = offset, puis octets incrementaux.
            $00 = fin, $01 = +254, $02-$FD = relocaliser.

  TODO 07 - ANALYSE DES DRAPEAUX (PH_PRGFLAGS) [A FAIRE]
            PF_FASTLOAD, PF_TTRAMLOAD, PF_TTRAMMEM,
            protection memoire MiNT, PF_SHARED_TEXT.

  TODO 08 - TABLE DES OPCODES 68000 - TRANSFERT [A FAIRE]
            MOVE, MOVEA, MOVEQ, MOVEM, MOVEP, EXG, SWAP,
            LEA, PEA, LINK, UNLK.

  TODO 09 - TABLE DES OPCODES 68000 - ARITHMETIQUE/LOGIQUE [A FAIRE]
            ADD, SUB, MUL, DIV, AND, OR, EOR, NOT, NEG,
            CMP, CLR, EXT, TST, TAS.

  TODO 10 - TABLE DES OPCODES 68000 - DECALAGES/ROTATIONS [A FAIRE]
            ASL, ASR, LSL, LSR, ROL, ROR, ROXL, ROXR.

  TODO 11 - TABLE DES OPCODES 68000 - BRANCHEMENTS/CONTROLE [A FAIRE]
            BRA, BSR, Bcc, DBcc, Scc, JMP, JSR, RTS, RTE,
            RTR, NOP, STOP, RESET, ILLEGAL.

  TODO 12 - TABLE DES OPCODES 68000 - BITS ET DIVERS [A FAIRE]
            BTST, BSET, BCLR, BCHG, TRAP, TRAPV, CHK,
            MOVE SR/CCR/USP, ANDI/ORI/EORI to SR/CCR.

  TODO 13 - DECODAGE DES MODES D'ADRESSAGE 68000 [A FAIRE]
            Dn, An, (An), (An)+, -(An), d16(An), d8(An,Xn),
            xxx.W, xxx.L, d16(PC), d8(PC,Xn), #imm.

  TODO 14 - DECODAGE D'UNE INSTRUCTION COMPLETE [A FAIRE]
            DecodeInstruction : lire le mot d instruction,
            extraire les champs, decoder les extensions.

  TODO 15 - PREMIERE PASSE : ANALYSE DU FLUX DE CONTROLE [A FAIRE]
            Parcourir TEXT, collecter les cibles de branchement,
            construire le graphe de flux, marquer code/donnees.

  TODO 16 - DETECTION DES SOUS-PROGRAMMES [A FAIRE]
            Identifier les cibles de BSR/JSR, detecter LINK/UNLK,
            MOVEM, prologues et epilogues de fonctions.

  TODO 17 - DETECTION DES APPELS SYSTEME TOS [A FAIRE]
            TRAP #1 (GEMDOS), TRAP #13 (BIOS), TRAP #14 (XBIOS),
            TRAP #2 (GEM AES/VDI). Noms des fonctions TOS.

  TODO 18 - DISCRIMINATION CODE/DONNEES DANS TEXT [A FAIRE]
            Octets non atteints = donnees (DC.B/DC.W/DC.L).
            Detecter chaines ASCII, tables de saut, constantes.

  TODO 19 - DESASSEMBLAGE DE LA SECTION DATA [A FAIRE]
            Emettre DC.B/DC.W/DC.L, detecter les chaines,
            utiliser symboles DRI et relocalisations.

  TODO 20 - GENERATION FICHIER .S : EN-TETE ET DIRECTIVES [A FAIRE]
            En-tete, directives section TEXT/DATA/BSS,
            XDEF, XREF, format Devpac/vasm compatible.

  TODO 21 - GENERATION FICHIER .S : SECTION TEXT [A FAIRE]
            Code desassemble : label, mnemonique, suffixe taille,
            operandes. Labels de saut loc_XXXXXX.

  TODO 22 - GENERATION FICHIER .S : SECTIONS DATA ET BSS [A FAIRE]
            DC.B/DC.W/DC.L pour DATA, DS.B/DS.W/DS.L pour BSS.
            Labels dat_XXXXXX, bss_XXXXXX.

  TODO 23 - ETIQUETTES AUTOMATIQUES ET REFERENCES CROISEES [A FAIRE]
            sub_XXXXXX, loc_XXXXXX, dat_XXXXXX, dta_XXXXXX,
            bss_XXXXXX. Commentaires XREF.

  TODO 24 - COMMENTAIRES ET ANNOTATIONS [A FAIRE]
            Noms des fonctions GEMDOS/BIOS/XBIOS, prologues,
            epilogues, adresses hardware ($FF8240, $FFFC00, ...).

  TODO 25 - VERIFICATION FINALE ET RAPPORT [A FAIRE]
            Coherence du fichier .S, statistiques : instructions,
            sous-programmes, labels, symboles, relocalisations,
            appels systeme, taille du fichier .S.
            Code de retour : 0 = succes, 1 = erreur.

  ============================================================ *)

Program DISPRG;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$A-}
{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  DISPRG_VERSION = '1.0';
  DISPRG_DATE    = '2026-04-02';

  { Signature magique de l'en-tete PRG Atari ST }
  PRG_MAGIC      = $601A;

  { Taille de l'en-tete PRG en octets }
  PRG_HEADER_SIZE = 28;

  { Taille d'une entree de la table des symboles DRI }
  SYM_ENTRY_SIZE = 14;

  { Drapeaux du programme (ph_prgflags) }
  PF_FASTLOAD    = $0001;   { Effacer seulement BSS au chargement }
  PF_TTRAMLOAD   = $0002;   { Charger en TT-RAM }
  PF_TTRAMMEM    = $0004;   { Allouer en TT-RAM }
  PF_SHARED_TEXT = $10000000;  { Partager la section TEXT (MiNT) }

  { Types de symboles DRI }
  SYM_DEFINED    = $0001;
  SYM_EQUATE     = $0002;
  SYM_GLOBAL     = $0004;
  SYM_REGISTER   = $0008;
  SYM_EXTERNAL   = $0010;
  SYM_DATA_REF   = $0020;
  SYM_TEXT_REF   = $0040;
  SYM_BSS_REF    = $0080;

  { Limites des tableaux internes }
  MAX_SYMBOLS    = 8192;
  MAX_RELOCS     = 65536;
  MAX_LABELS     = 65536;
  MAX_XREFS      = 65536;
  BUFFER_SIZE    = 65536;

  { Taille maximale de l'image en memoire (4 Mo) }
  MAX_IMAGE_SIZE = 4 * 1024 * 1024;

  { Codes de retour }
  EXIT_OK        = 0;
  EXIT_ERROR     = 1;
  EXIT_USAGE     = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String;

  { En-tete du fichier .PRG Atari ST (28 octets, big-endian) }
  TPrgHeader = Record
    ph_branch   : Word;       { $601A = signature standard          }
    ph_tlen     : LongInt;    { taille de la section TEXT            }
    ph_dlen     : LongInt;    { taille de la section DATA            }
    ph_blen     : LongInt;    { taille de la section BSS             }
    ph_slen     : LongInt;    { taille de la table des symboles      }
    ph_res1     : LongInt;    { reserve (doit etre 0)                }
    ph_prgflags : LongInt;    { drapeaux du programme                }
    ph_absflag  : Word;       { 0 = relocalisable                   }
  End;

  { Entree de la table des symboles DRI (14 octets) }
  TPrgSymbol = Record
    sym_name  : Array[0..7] Of Char;  { nom (8 caracteres max)       }
    sym_type  : Word;                  { type du symbole              }
    sym_value : LongInt;               { valeur / adresse             }
  End;

  { Information de label/symbole }
  TLabelInfo = Record
    Address  : LongInt;   { adresse dans l'image }
    Name     : TString;   { nom du label }
    IsProc   : Boolean;   { est-ce un sous-programme ? }
    IsData   : Boolean;   { est-ce une donnee ? }
    Section  : Byte;      { 0=TEXT, 1=DATA, 2=BSS }
  End;

  { Reference croisee }
  TXRef = Record
    FromAddr : LongInt;   { adresse source }
    ToAddr   : LongInt;   { adresse cible }
    IsCall   : Boolean;   { BSR/JSR (True) ou BRA/Bcc/JMP (False) }
  End;

  { Options de ligne de commande }
  TOptions = Record
    SrcFile    : TString;   { fichier .PRG en entree }
    OutFile    : TString;   { fichier .S en sortie }
    Verbose    : Boolean;   { -v : mode verbeux }
    HexDump    : Boolean;   { -hex : octets hex en commentaire }
    ShowSymbols: Boolean;   { -sym : afficher la table des symboles }
    ShowRelocs : Boolean;   { -reloc : afficher les relocalisations }
    DisasmData : Boolean;   { -data : desassembler la section DATA }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts        : TOptions;
  Header      : TPrgHeader;
  InFile      : File;
  OutF        : Text;

  { Tampon dynamique pour l'image }
  ImageBuffer : Pointer;
  ImageSize   : LongInt;

  { Offsets des sections dans l'image }
  TextOffset  : LongInt;
  DataOffset  : LongInt;
  SymOffset   : LongInt;

  { Table des symboles DRI }
  Symbols     : Array[1..MAX_SYMBOLS] Of TPrgSymbol;
  SymbolCount : Integer;

  { Table des labels }
  Labels      : Array[1..MAX_LABELS] Of TLabelInfo;
  LabelCount  : Integer;

  { Table des references croisees }
  XRefs       : Array[1..MAX_XREFS] Of TXRef;
  XRefCount   : Integer;

  { Compteurs de statistiques }
  InstrCount  : LongInt;
  SubCount    : LongInt;
  TrapCount   : LongInt;

{ ============================================================
  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ --- Fonctions utilitaires --- }

Function UpCaseStr(S: String): String;
Var
  I: Integer;
Begin
  For I := 1 To Length(S) Do
    S[I] := UpCase(S[I]);
  UpCaseStr := S;
End;

Function HexNibble(N: Byte): Char;
Begin
  If N < 10 Then
    HexNibble := Chr(Ord('0') + N)
  Else
    HexNibble := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): String;
Begin
  HexByte := HexNibble(B Shr 4) + HexNibble(B And $0F);
End;

Function HexWord(W: Word): String;
Begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function HexLong(L: LongInt): String;
Begin
  HexLong := HexWord(Word(L Shr 16)) + HexWord(Word(L And $FFFF));
End;

Function IntToStr(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function FileExists(FileName: String): Boolean;
Var
  F: File;
  R: Integer;
Begin
  Assign(F, FileName);
  R := IOResult; { vider IOResult precedent }
  Reset(F, 1);
  R := IOResult;
  If R = 0 Then Begin
    Close(F);
    R := IOResult;
    FileExists := True;
  End Else
    FileExists := False;
End;

Function ChangeFileExt(FileName, NewExt: String): String;
Var
  I: Integer;
  Base: String;
Begin
  Base := FileName;
  For I := Length(FileName) DownTo 1 Do Begin
    If FileName[I] = '.' Then Begin
      Base := Copy(FileName, 1, I - 1);
      Break;
    End;
    If (FileName[I] = '\') Or (FileName[I] = '/') Then
      Break;
  End;
  ChangeFileExt := Base + NewExt;
End;

{ --- Gestion des erreurs --- }

Procedure FatalError(Msg: String);
Begin
  WriteLn('DISPRG: Erreur: ', Msg);
  Halt(EXIT_ERROR);
End;

{ --- Aide et version --- }

Procedure ShowVersion;
Begin
  WriteLn('DISPRG - Desassembleur de fichiers .PRG Atari ST');
  WriteLn('Version ', DISPRG_VERSION, ' (', DISPRG_DATE, ')');
  WriteLn('Motorola 68000 -> assembleur 68000 (.S)');
End;

Procedure ShowHelp;
Begin
  ShowVersion;
  WriteLn;
  WriteLn('Usage: DISPRG fichier.prg [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -o nom     Specifier le nom du fichier de sortie .S');
  WriteLn('  -v         Mode verbeux');
  WriteLn('  -hex       Inclure les octets hexadecimaux en commentaire');
  WriteLn('  -sym       Afficher la table des symboles DRI');
  WriteLn('  -reloc     Afficher la table de relocalisation');
  WriteLn('  -data      Desassembler aussi la section DATA');
  WriteLn('  -h         Afficher cette aide');
  WriteLn('  --help     Afficher cette aide');
  WriteLn;
  WriteLn('Formats supportes:');
  WriteLn('  .PRG  Programme executable Atari ST');
  WriteLn('  .TOS  Programme mode texte TOS');
  WriteLn('  .TTP  TOS Takes Parameters');
  WriteLn('  .APP  Application GEM');
  WriteLn('  .GTP  GEM Takes Parameters');
  WriteLn('  .ACC  Accessoire de bureau GEM');
  Halt(EXIT_OK);
End;

{ --- Initialisation des options --- }

Procedure InitOptions(Var Opts: TOptions);
Begin
  Opts.SrcFile     := '';
  Opts.OutFile     := '';
  Opts.Verbose     := False;
  Opts.HexDump     := False;
  Opts.ShowSymbols := False;
  Opts.ShowRelocs  := False;
  Opts.DisasmData  := False;
End;

{ --- Analyse de la ligne de commande --- }

Procedure ParseCommandLine(Var Opts: TOptions);
Var
  I: Integer;
  Arg: String;
  NextIsOut: Boolean;
Begin
  If ParamCount = 0 Then
    ShowHelp;
  NextIsOut := False;
  For I := 1 To ParamCount Do Begin
    Arg := ParamStr(I);
    If NextIsOut Then Begin
      Opts.OutFile := Arg;
      NextIsOut := False;
    End Else If (Arg = '-h') Or (Arg = '--help') Or (Arg = '-?') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '-V') Then
      Opts.Verbose := True
    Else If (Arg = '-hex') Or (Arg = '-HEX') Then
      Opts.HexDump := True
    Else If (Arg = '-sym') Or (Arg = '-SYM') Then
      Opts.ShowSymbols := True
    Else If (Arg = '-reloc') Or (Arg = '-RELOC') Then
      Opts.ShowRelocs := True
    Else If (Arg = '-data') Or (Arg = '-DATA') Then
      Opts.DisasmData := True
    Else If (Arg = '-o') Or (Arg = '-O') Then
      NextIsOut := True
    Else If Arg[1] = '-' Then
      FatalError('Option inconnue: ' + Arg)
    Else Begin
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
        FatalError('Fichier source deja specifie: ' + Arg);
    End;
  End;
  If NextIsOut Then
    FatalError('Option -o sans nom de fichier');
  If Opts.SrcFile = '' Then
    FatalError('Aucun fichier source specifie');
  If Not FileExists(Opts.SrcFile) Then
    FatalError('Fichier introuvable: ' + Opts.SrcFile);
  If Opts.OutFile = '' Then
    Opts.OutFile := ChangeFileExt(Opts.SrcFile, '.S');
End;

{ ============================================================
  TODO 02 - LECTURE ET VALIDATION DE L'EN-TETE PRG [IMPLEMENTE]
  ============================================================ }

{ --- Conversion big-endian vers little-endian (16 bits) --- }

Function BEToWord(B0, B1: Byte): Word;
Begin
  BEToWord := Word(B0) Shl 8 Or B1;
End;

{ --- Conversion big-endian vers little-endian (32 bits) --- }

Function BEToLong(B0, B1, B2, B3: Byte): LongInt;
Begin
  BEToLong := LongInt(B0) Shl 24 Or LongInt(B1) Shl 16 Or
              LongInt(B2) Shl 8 Or LongInt(B3);
End;

{ --- Lecture de l'en-tete PRG (28 octets, big-endian) --- }

Procedure ReadPrgHeader(Var F: File; Var H: TPrgHeader);
Var
  Buf: Array[0..27] Of Byte;
  BytesRead: Word;
Begin
  BlockRead(F, Buf, PRG_HEADER_SIZE, BytesRead);
  If BytesRead <> PRG_HEADER_SIZE Then
    FatalError('Fichier tronque: impossible de lire l''en-tete PRG (' +
               IntToStr(BytesRead) + '/' + IntToStr(PRG_HEADER_SIZE) +
               ' octets)');
  { Convertir les champs big-endian en little-endian }
  H.ph_branch   := BEToWord(Buf[0], Buf[1]);
  H.ph_tlen     := BEToLong(Buf[2], Buf[3], Buf[4], Buf[5]);
  H.ph_dlen     := BEToLong(Buf[6], Buf[7], Buf[8], Buf[9]);
  H.ph_blen     := BEToLong(Buf[10], Buf[11], Buf[12], Buf[13]);
  H.ph_slen     := BEToLong(Buf[14], Buf[15], Buf[16], Buf[17]);
  H.ph_res1     := BEToLong(Buf[18], Buf[19], Buf[20], Buf[21]);
  H.ph_prgflags := BEToLong(Buf[22], Buf[23], Buf[24], Buf[25]);
  H.ph_absflag  := BEToWord(Buf[26], Buf[27]);
End;

{ --- Validation de la signature magique $601A --- }

Procedure ValidatePrgHeader(Var H: TPrgHeader);
Begin
  If H.ph_branch <> PRG_MAGIC Then
    FatalError('Signature invalide: $' + HexWord(H.ph_branch) +
               ' (attendu $' + HexWord(PRG_MAGIC) + ')');
End;

{ --- Affichage de l'en-tete si mode verbeux --- }

Procedure ShowPrgHeader(Var H: TPrgHeader; Verbose: Boolean);
Var
  RelocStr: String;
  TotalSize: LongInt;
Begin
  If Not Verbose Then Exit;
  If H.ph_absflag = 0 Then
    RelocStr := 'relocalisable'
  Else
    RelocStr := 'absolu';
  TotalSize := H.ph_tlen + H.ph_dlen + H.ph_blen;
  WriteLn;
  WriteLn('=== En-tete PRG (', IntToStr(PRG_HEADER_SIZE), ' octets) ===');
  WriteLn('  ph_branch   : $', HexWord(H.ph_branch));
  WriteLn('  ph_tlen     : $', HexLong(H.ph_tlen),
          ' (', IntToStr(H.ph_tlen), ' octets = section TEXT)');
  WriteLn('  ph_dlen     : $', HexLong(H.ph_dlen),
          ' (', IntToStr(H.ph_dlen), ' octets = section DATA)');
  WriteLn('  ph_blen     : $', HexLong(H.ph_blen),
          ' (', IntToStr(H.ph_blen), ' octets = section BSS)');
  WriteLn('  ph_slen     : $', HexLong(H.ph_slen),
          ' (', IntToStr(H.ph_slen), ' octets = table symboles)');
  WriteLn('  ph_res1     : $', HexLong(H.ph_res1));
  WriteLn('  ph_prgflags : $', HexLong(H.ph_prgflags));
  WriteLn('  ph_absflag  : $', HexWord(H.ph_absflag),
          ' (', RelocStr, ')');
  WriteLn('  Taille programme : ', IntToStr(TotalSize),
          ' octets (TEXT+DATA+BSS)');
  If H.ph_slen > 0 Then
    WriteLn('  Nombre symboles  : ',
            IntToStr(H.ph_slen Div SYM_ENTRY_SIZE), ' entrees');
End;

{ ============================================================
  TODO 03 - CONVERSION BIG-ENDIAN / LITTLE-ENDIAN [IMPLEMENTE]
  ============================================================ }

{ --- SwapWord : permuter les 2 octets d'un Word --- }

Function SwapWord(W: Word): Word;
Begin
  SwapWord := (W Shr 8) Or ((W And $FF) Shl 8);
End;

{ --- SwapLong : permuter les 4 octets d'un LongInt --- }

Function SwapLong(L: LongInt): LongInt;
Var
  B0, B1, B2, B3: Byte;
Begin
  B0 := Byte(L And $FF);
  B1 := Byte((L Shr 8) And $FF);
  B2 := Byte((L Shr 16) And $FF);
  B3 := Byte((L Shr 24) And $FF);
  SwapLong := LongInt(B0) Shl 24 Or LongInt(B1) Shl 16 Or
              LongInt(B2) Shl 8 Or LongInt(B3);
End;

{ --- ReadBEWord : lire un Word big-endian depuis un fichier --- }

Function ReadBEWord(Var F: File): Word;
Var
  Buf: Array[0..1] Of Byte;
  BytesRead: Word;
Begin
  BlockRead(F, Buf, 2, BytesRead);
  If BytesRead <> 2 Then
    FatalError('Lecture fichier echouee: attendu 2 octets, lu ' +
               IntToStr(BytesRead));
  ReadBEWord := BEToWord(Buf[0], Buf[1]);
End;

{ --- ReadBELong : lire un LongInt big-endian depuis un fichier --- }

Function ReadBELong(Var F: File): LongInt;
Var
  Buf: Array[0..3] Of Byte;
  BytesRead: Word;
Begin
  BlockRead(F, Buf, 4, BytesRead);
  If BytesRead <> 4 Then
    FatalError('Lecture fichier echouee: attendu 4 octets, lu ' +
               IntToStr(BytesRead));
  ReadBELong := BEToLong(Buf[0], Buf[1], Buf[2], Buf[3]);
End;

{ --- ReadBEWordMem : lire un Word big-endian en memoire --- }
{     Ofs = offset dans ImageBuffer                         }

Function ReadBEWordMem(Ofs: LongInt): Word;
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  P: PByteArray;
Begin
  If ImageBuffer = Nil Then
    FatalError('ReadBEWordMem: tampon image non alloue');
  If (Ofs < 0) Or (Ofs + 1 >= ImageSize) Then
    FatalError('ReadBEWordMem: offset hors limites: $' + HexLong(Ofs));
  P := PByteArray(ImageBuffer);
  ReadBEWordMem := BEToWord(P^[Ofs], P^[Ofs + 1]);
End;

{ --- ReadBELongMem : lire un LongInt big-endian en memoire --- }
{     Ofs = offset dans ImageBuffer                             }

Function ReadBELongMem(Ofs: LongInt): LongInt;
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  P: PByteArray;
Begin
  If ImageBuffer = Nil Then
    FatalError('ReadBELongMem: tampon image non alloue');
  If (Ofs < 0) Or (Ofs + 3 >= ImageSize) Then
    FatalError('ReadBELongMem: offset hors limites: $' + HexLong(Ofs));
  P := PByteArray(ImageBuffer);
  ReadBELongMem := BEToLong(P^[Ofs], P^[Ofs + 1],
                             P^[Ofs + 2], P^[Ofs + 3]);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
  ShowVersion;
  WriteLn;
  InitOptions(Opts);
  ParseCommandLine(Opts);
  { Initialiser les compteurs }
  SymbolCount := 0;
  LabelCount  := 0;
  XRefCount   := 0;
  InstrCount  := 0;
  SubCount    := 0;
  TrapCount   := 0;
  ImageBuffer := Nil;
  ImageSize   := 0;
  TextOffset  := 0;
  DataOffset  := 0;
  SymOffset   := 0;
  WriteLn('Fichier source  : ', Opts.SrcFile);
  WriteLn('Fichier sortie  : ', Opts.OutFile);
  If Opts.Verbose Then Begin
    WriteLn('Mode verbeux    : Oui');
    If Opts.HexDump Then
      WriteLn('Dump hexa       : Oui');
    If Opts.ShowSymbols Then
      WriteLn('Table symboles  : Oui');
    If Opts.ShowRelocs Then
      WriteLn('Table reloc     : Oui');
    If Opts.DisasmData Then
      WriteLn('Desasm DATA     : Oui');
  End;
  { Ouvrir le fichier PRG }
  Assign(InFile, Opts.SrcFile);
  Reset(InFile, 1);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier: ' + Opts.SrcFile);
  { Lire et valider l'en-tete PRG }
  ReadPrgHeader(InFile, Header);
  ValidatePrgHeader(Header);
  ShowPrgHeader(Header, Opts.Verbose);
  { Fermer le fichier pour l'instant }
  Close(InFile);
  If IOResult <> 0 Then;  { ignorer erreur de fermeture }
  { TODO 04-25 : chargement, desassemblage, generation .S }
  WriteLn;
  WriteLn('DISPRG v', DISPRG_VERSION, ' - TODOs 01-03 [IMPLEMENTE], TODOs 04-25 [A FAIRE]');
End.
