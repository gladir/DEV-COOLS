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

  TODO 02 - LECTURE ET VALIDATION DE L'EN-TETE PRG [A FAIRE]
            Lire les 28 octets de l en-tete : ph_branch ($601A),
            ph_tlen, ph_dlen, ph_blen, ph_slen, ph_res1,
            ph_prgflags, ph_absflag. Valider la signature $601A.
            Convertir les valeurs big-endian en little-endian.
            Afficher un resume de l en-tete si -v est active.

  TODO 03 - CONVERSION BIG-ENDIAN / LITTLE-ENDIAN [A FAIRE]
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
  { TODO 02-25 : lecture en-tete, chargement, desassemblage, generation .S }
  WriteLn;
  WriteLn('DISPRG v', DISPRG_VERSION, ' - TODO 01 [IMPLEMENTE], TODOs 02-25 [A FAIRE]');
End.
