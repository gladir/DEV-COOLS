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

  TODO 04 - CHARGEMENT DES SECTIONS EN MEMOIRE [IMPLEMENTE]
            LoadSections, FreeSections, ShowSections.
            Charger TEXT, DATA et la table des symboles dans un
            tampon dynamique. Calculer les offsets de chaque section.

  TODO 05 - LECTURE DE LA TABLE DES SYMBOLES DRI [IMPLEMENTE]
            ReadSymbolTable, SymTypeToStr, GetSymbolSection,
            ShowSymbolTable, FindSymbolByAddr, AddSymbolLabels.
            Entrees de 14 octets : sym_name (8 car), sym_type (Word),
            sym_value (LongInt). Decoder les types ($0001 defini,
            $0004 global, $0040 TEXT, $0020 DATA, $0080 BSS, etc.).

  TODO 06 - LECTURE DE LA TABLE DE RELOCALISATION [IMPLEMENTE]
            ReadRelocTable, ShowRelocTable, IsRelocatedAddr, CountRelocs.
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

  { Table des relocalisations (offsets dans TEXT+DATA) }
  Relocs      : Array[1..MAX_RELOCS] Of LongInt;
  RelocCount  : LongInt;

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
  TODO 04 - CHARGEMENT DES SECTIONS EN MEMOIRE [IMPLEMENTE]
  ============================================================ }

{ --- LoadSections : charger TEXT, DATA et symboles en memoire --- }
{     Le fichier doit etre ouvert et positionne apres l'en-tete   }

Procedure LoadSections(Var F: File; Var H: TPrgHeader);
Var
  TotalSize  : LongInt;
  BytesRead  : Word;
  Remaining  : LongInt;
  ChunkSize  : Word;
  P          : Pointer;
  Offset     : LongInt;
Begin
  { Calculer la taille totale a charger }
  TotalSize := H.ph_tlen + H.ph_dlen + H.ph_slen;
  If TotalSize <= 0 Then
    FatalError('Fichier PRG vide: aucune section a charger');
  If TotalSize > MAX_IMAGE_SIZE Then
    FatalError('Image trop grande: ' + IntToStr(TotalSize) +
               ' octets (max ' + IntToStr(MAX_IMAGE_SIZE) + ')');
  { Allouer le tampon dynamique }
  GetMem(ImageBuffer, TotalSize);
  If ImageBuffer = Nil Then
    FatalError('Memoire insuffisante pour ' + IntToStr(TotalSize) +
               ' octets');
  ImageSize := TotalSize;
  { Calculer les offsets des sections dans le tampon }
  TextOffset := 0;
  DataOffset := H.ph_tlen;
  SymOffset  := H.ph_tlen + H.ph_dlen;
  { Le fichier est deja positionne apres l'en-tete (offset $001C) }
  { Charger toute l'image par blocs de BUFFER_SIZE }
  Offset := 0;
  Remaining := TotalSize;
  While Remaining > 0 Do Begin
    If Remaining > LongInt(BUFFER_SIZE - 1) Then
      ChunkSize := BUFFER_SIZE - 1
    Else
      ChunkSize := Word(Remaining);
    { Calculer l'adresse de destination dans le tampon }
    P := Pointer(PtrUInt(ImageBuffer) + PtrUInt(Offset));
    BlockRead(F, P^, ChunkSize, BytesRead);
    If BytesRead <> ChunkSize Then
      FatalError('Lecture incomplete: attendu ' + IntToStr(ChunkSize) +
                 ' octets, lu ' + IntToStr(BytesRead) +
                 ' (offset $' + HexLong(Offset) + ')');
    Inc(Offset, BytesRead);
    Dec(Remaining, BytesRead);
  End;
End;

{ --- FreeSections : liberer la memoire du tampon image --- }

Procedure FreeSections;
Begin
  If ImageBuffer <> Nil Then Begin
    FreeMem(ImageBuffer, ImageSize);
    ImageBuffer := Nil;
    ImageSize   := 0;
    TextOffset  := 0;
    DataOffset  := 0;
    SymOffset   := 0;
  End;
End;

{ --- ShowSections : afficher les informations des sections chargees --- }

Procedure ShowSections(Var H: TPrgHeader; Verbose: Boolean);
Var
  TotalSize: LongInt;
Begin
  If Not Verbose Then Exit;
  TotalSize := H.ph_tlen + H.ph_dlen + H.ph_slen;
  WriteLn;
  WriteLn('=== Sections chargees en memoire ===');
  WriteLn('  Section TEXT    : offset $', HexLong(TextOffset),
          ', taille ', IntToStr(H.ph_tlen), ' octets');
  WriteLn('  Section DATA    : offset $', HexLong(DataOffset),
          ', taille ', IntToStr(H.ph_dlen), ' octets');
  If H.ph_slen > 0 Then
    WriteLn('  Table symboles  : offset $', HexLong(SymOffset),
            ', taille ', IntToStr(H.ph_slen), ' octets');
  WriteLn('  Taille tampon   : ', IntToStr(TotalSize), ' octets');
  WriteLn('  Section BSS     : ', IntToStr(H.ph_blen),
          ' octets (non chargee, non initialisee)');
End;

{ ============================================================
  TODO 05 - LECTURE DE LA TABLE DES SYMBOLES DRI [IMPLEMENTE]
  ============================================================ }

{ --- SymTypeToStr : decoder les bits de type d'un symbole DRI --- }

Function SymTypeToStr(T: Word): String;
Var
  S: String;
Begin
  S := '';
  If (T And SYM_DEFINED) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'DEF';
  End;
  If (T And SYM_EQUATE) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'EQU';
  End;
  If (T And SYM_GLOBAL) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'GLB';
  End;
  If (T And SYM_REGISTER) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'REG';
  End;
  If (T And SYM_EXTERNAL) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'EXT';
  End;
  If (T And SYM_DATA_REF) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'DATA';
  End;
  If (T And SYM_TEXT_REF) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'TEXT';
  End;
  If (T And SYM_BSS_REF) <> 0 Then Begin
    If S <> '' Then S := S + ',';
    S := S + 'BSS';
  End;
  If S = '' Then
    S := '???';
  SymTypeToStr := S;
End;

{ --- GetSymbolSection : determiner la section d'un symbole --- }
{     Retourne 0=TEXT, 1=DATA, 2=BSS, 3=inconnu                }

Function GetSymbolSection(T: Word): Byte;
Begin
  If (T And SYM_TEXT_REF) <> 0 Then
    GetSymbolSection := 0
  Else If (T And SYM_DATA_REF) <> 0 Then
    GetSymbolSection := 1
  Else If (T And SYM_BSS_REF) <> 0 Then
    GetSymbolSection := 2
  Else
    GetSymbolSection := 3;
End;

{ --- ReadSymbolTable : lire la table des symboles DRI --- }
{     depuis ImageBuffer a l'offset SymOffset                }

Procedure ReadSymbolTable(Var H: TPrgHeader);
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  NumEntries : LongInt;
  I, J       : LongInt;
  Ofs        : LongInt;
  P          : PByteArray;
  C          : Char;
Begin
  SymbolCount := 0;
  If H.ph_slen <= 0 Then Exit;
  If ImageBuffer = Nil Then
    FatalError('ReadSymbolTable: tampon image non alloue');
  NumEntries := H.ph_slen Div SYM_ENTRY_SIZE;
  If NumEntries > MAX_SYMBOLS Then Begin
    WriteLn('Avertissement: ', IntToStr(NumEntries),
            ' symboles trouves, seuls les ', IntToStr(MAX_SYMBOLS),
            ' premiers seront traites');
    NumEntries := MAX_SYMBOLS;
  End;
  P := PByteArray(ImageBuffer);
  For I := 1 To NumEntries Do Begin
    Ofs := SymOffset + (I - 1) * LongInt(SYM_ENTRY_SIZE);
    { Verifier les limites }
    If Ofs + SYM_ENTRY_SIZE > ImageSize Then Begin
      WriteLn('Avertissement: table symboles tronquee a l''entree ',
              IntToStr(I));
      Break;
    End;
    { Lire le nom (8 caracteres) }
    For J := 0 To 7 Do Begin
      C := Chr(P^[Ofs + J]);
      If (C < ' ') Or (C > '~') Then C := '_';
      Symbols[I].sym_name[J] := C;
    End;
    { Lire le type (Word big-endian) }
    Symbols[I].sym_type := BEToWord(P^[Ofs + 8], P^[Ofs + 9]);
    { Lire la valeur (LongInt big-endian) }
    Symbols[I].sym_value := BEToLong(P^[Ofs + 10], P^[Ofs + 11],
                                      P^[Ofs + 12], P^[Ofs + 13]);
    SymbolCount := I;
  End;
End;

{ --- GetSymbolName : extraire le nom d'un symbole (8 car, trim) --- }

Function GetSymbolName(Var Sym: TPrgSymbol): String;
Var
  S: String;
  I: Integer;
Begin
  S := '';
  For I := 0 To 7 Do Begin
    If Sym.sym_name[I] = #0 Then Break;
    If (Sym.sym_name[I] >= ' ') And (Sym.sym_name[I] <= '~') Then
      S := S + Sym.sym_name[I];
  End;
  { Retirer les espaces de fin }
  While (Length(S) > 0) And (S[Length(S)] = ' ') Do
    Delete(S, Length(S), 1);
  GetSymbolName := S;
End;

{ --- ShowSymbolTable : afficher la table des symboles DRI --- }

Procedure ShowSymbolTable(ShowSym: Boolean);
Var
  I       : Integer;
  SymName : String;
  SecStr  : String;
  Sec     : Byte;
Begin
  If Not ShowSym Then Exit;
  If SymbolCount = 0 Then Begin
    WriteLn;
    WriteLn('=== Table des symboles DRI ===');
    WriteLn('  (aucun symbole)');
    Exit;
  End;
  WriteLn;
  WriteLn('=== Table des symboles DRI (', IntToStr(SymbolCount),
          ' entrees) ===');
  WriteLn('  #     Nom        Type    Valeur     Section  Attributs');
  WriteLn('  ----  --------  ------  ----------  -------  ---------');
  For I := 1 To SymbolCount Do Begin
    SymName := GetSymbolName(Symbols[I]);
    Sec := GetSymbolSection(Symbols[I].sym_type);
    Case Sec Of
      0: SecStr := 'TEXT';
      1: SecStr := 'DATA';
      2: SecStr := 'BSS ';
    Else
      SecStr := '??? ';
    End;
    Write('  ');
    { Numero }
    If I < 10 Then Write(' ');
    If I < 100 Then Write(' ');
    If I < 1000 Then Write(' ');
    Write(IntToStr(I), '  ');
    { Nom (8 car) }
    Write(SymName);
    If Length(SymName) < 8 Then
      Write('' : 8 - Length(SymName));
    Write('  ');
    { Type hex }
    Write('$', HexWord(Symbols[I].sym_type), '  ');
    { Valeur }
    Write('$', HexLong(Symbols[I].sym_value), '  ');
    { Section }
    Write(SecStr, '     ');
    { Attributs }
    WriteLn(SymTypeToStr(Symbols[I].sym_type));
  End;
End;

{ --- FindSymbolByAddr : trouver un symbole par adresse et section --- }
{     Retourne l'index (1..SymbolCount) ou 0 si non trouve            }

Function FindSymbolByAddr(Addr: LongInt; Section: Byte): Integer;
Var
  I: Integer;
Begin
  FindSymbolByAddr := 0;
  For I := 1 To SymbolCount Do Begin
    If (Symbols[I].sym_value = Addr) And
       (GetSymbolSection(Symbols[I].sym_type) = Section) Then Begin
      FindSymbolByAddr := I;
      Exit;
    End;
  End;
End;

{ --- AddSymbolLabels : ajouter les symboles DRI comme labels --- }

Procedure AddSymbolLabels;
Var
  I       : Integer;
  Sec     : Byte;
  SymName : String;
Begin
  For I := 1 To SymbolCount Do Begin
    If LongInt(LabelCount) >= LongInt(MAX_LABELS) Then Begin
      WriteLn('Avertissement: limite de labels atteinte (',
              IntToStr(MAX_LABELS), ')');
      Exit;
    End;
    SymName := GetSymbolName(Symbols[I]);
    If SymName = '' Then Continue;
    { Ne pas ajouter les symboles externes ou registres }
    If (Symbols[I].sym_type And SYM_EXTERNAL) <> 0 Then Continue;
    If (Symbols[I].sym_type And SYM_REGISTER) <> 0 Then Continue;
    Sec := GetSymbolSection(Symbols[I].sym_type);
    If Sec > 2 Then Continue;  { section inconnue }
    Inc(LabelCount);
    Labels[LabelCount].Address := Symbols[I].sym_value;
    Labels[LabelCount].Name    := SymName;
    Labels[LabelCount].IsProc  := (Sec = 0);  { TEXT = sous-programme potentiel }
    Labels[LabelCount].IsData  := (Sec > 0);  { DATA ou BSS = donnee }
    Labels[LabelCount].Section := Sec;
  End;
End;

{ ============================================================
  TODO 06 - LECTURE DE LA TABLE DE RELOCALISATION [IMPLEMENTE]
  ============================================================ }

{ --- ReadRelocTable : lire la table de relocalisation --- }
{     depuis le fichier PRG (apres TEXT+DATA+symboles).     }
{     Le fichier doit etre ouvert et positionne apres les   }
{     sections (offset $001C + ph_tlen + ph_dlen + ph_slen).}
{     Si ph_absflag <> 0, le programme est absolu (pas de   }
{     table de relocalisation).                              }

Procedure ReadRelocTable(Var F: File; Var H: TPrgHeader);
Var
  FirstOffset : LongInt;
  CurOffset   : LongInt;
  Delta       : Byte;
  BytesRead   : Word;
  Buf         : Array[0..3] Of Byte;
Begin
  RelocCount := 0;
  { Si le programme est absolu, pas de table de relocalisation }
  If H.ph_absflag <> 0 Then Exit;
  { Lire le premier mot long (offset de la premiere relocalisation) }
  BlockRead(F, Buf, 4, BytesRead);
  If BytesRead < 4 Then Exit;  { pas de table de relocalisation }
  FirstOffset := BEToLong(Buf[0], Buf[1], Buf[2], Buf[3]);
  { Si le premier offset est 0, pas de relocalisation }
  If FirstOffset = 0 Then Exit;
  { Enregistrer la premiere relocalisation }
  CurOffset := FirstOffset;
  If RelocCount < MAX_RELOCS Then Begin
    Inc(RelocCount);
    Relocs[RelocCount] := CurOffset;
  End;
  { Lire la sequence d'octets incrementaux }
  Repeat
    BlockRead(F, Delta, 1, BytesRead);
    If BytesRead < 1 Then Break;  { fin de fichier }
    If Delta = 0 Then
      Break                       { $00 = fin de la table }
    Else If Delta = 1 Then
      Inc(CurOffset, 254)         { $01 = avancer de 254, pas de reloc }
    Else Begin
      Inc(CurOffset, LongInt(Delta));  { $02-$FD = avancer et relocaliser }
      If RelocCount < MAX_RELOCS Then Begin
        Inc(RelocCount);
        Relocs[RelocCount] := CurOffset;
      End;
    End;
  Until False;
End;

{ --- ShowRelocTable : afficher la table de relocalisation --- }

Procedure ShowRelocTable(ShowReloc: Boolean);
Var
  I      : LongInt;
  ColCnt : Integer;
Begin
  If Not ShowReloc Then Exit;
  WriteLn;
  If RelocCount = 0 Then Begin
    WriteLn('=== Table de relocalisation ===');
    WriteLn('  (aucune relocalisation)');
    Exit;
  End;
  WriteLn('=== Table de relocalisation (', IntToStr(RelocCount),
          ' entrees) ===');
  ColCnt := 0;
  For I := 1 To RelocCount Do Begin
    If ColCnt = 0 Then
      Write('  ');
    Write('$', HexLong(Relocs[I]));
    Inc(ColCnt);
    If ColCnt >= 8 Then Begin
      WriteLn;
      ColCnt := 0;
    End Else
      If I < RelocCount Then
        Write('  ');
  End;
  If ColCnt > 0 Then
    WriteLn;
End;

{ --- IsRelocatedAddr : verifier si une adresse est relocalisee --- }

Function IsRelocatedAddr(Addr: LongInt): Boolean;
Var
  I: LongInt;
Begin
  IsRelocatedAddr := False;
  For I := 1 To RelocCount Do Begin
    If Relocs[I] = Addr Then Begin
      IsRelocatedAddr := True;
      Exit;
    End;
  End;
End;

{ --- CountRelocs : retourner le nombre de relocalisations --- }

Function CountRelocs: LongInt;
Begin
  CountRelocs := RelocCount;
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
  RelocCount  := 0;
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
  { Charger les sections TEXT, DATA et symboles en memoire }
  LoadSections(InFile, Header);
  ShowSections(Header, Opts.Verbose);
  { Lire la table de relocalisation (si relocalisable) }
  ReadRelocTable(InFile, Header);
  { Fermer le fichier PRG }
  Close(InFile);
  If IOResult <> 0 Then;  { ignorer erreur de fermeture }
  { TODO 07-25 : drapeaux, desassemblage, generation .S }
  { Lire la table des symboles DRI }
  ReadSymbolTable(Header);
  ShowSymbolTable(Opts.ShowSymbols Or Opts.Verbose);
  AddSymbolLabels;
  If Opts.Verbose And (SymbolCount > 0) Then
    WriteLn('Labels ajoutes depuis symboles DRI: ', IntToStr(LabelCount));
  { Afficher la table de relocalisation }
  ShowRelocTable(Opts.ShowRelocs Or Opts.Verbose);
  If Opts.Verbose Then
    WriteLn('Relocalisations : ', IntToStr(RelocCount));
  { Liberer la memoire }
  FreeSections;
  WriteLn;
  WriteLn('DISPRG v', DISPRG_VERSION, ' - TODOs 01-06 [IMPLEMENTE], TODOs 07-25 [A FAIRE]');
End.
