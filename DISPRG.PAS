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

  TODO 07 - ANALYSE DES DRAPEAUX (PH_PRGFLAGS) [IMPLEMENTE]
            PrgFlagsToStr, GetMemProtection, ShowPrgFlags, HasPrgFlag.
            PF_FASTLOAD, PF_TTRAMLOAD, PF_TTRAMMEM,
            protection memoire MiNT, PF_SHARED_TEXT.

  TODO 08 - TABLE DES OPCODES 68000 - TRANSFERT [IMPLEMENTE]
            AddOpcode, InitTransferOpcodes, InitOpcodeTable,
            FindOpcode, GetOpcodeMnemonic, OpcodeGroupToStr,
            ShowOpcodeTable, CountOpcodes, CountOpcodesByGroup.
            MOVE, MOVEA, MOVEQ, MOVEM, MOVEP, EXG, SWAP,
            LEA, PEA, LINK, UNLK.

  TODO 09 - TABLE DES OPCODES 68000 - ARITHMETIQUE/LOGIQUE [IMPLEMENTE]
            ADD, ADDA, ADDI, ADDQ, ADDX, SUB, SUBA, SUBI, SUBQ, SUBX,
            MULU, MULS, DIVU, DIVS, AND, ANDI, OR, ORI, EOR, EORI,
            NOT, NEG, NEGX, CMP, CMPA, CMPI, CMPM, CLR, EXT, TST, TAS.

  TODO 10 - TABLE DES OPCODES 68000 - DECALAGES/ROTATIONS [IMPLEMENTE]
            ASL, ASR, LSL, LSR, ROL, ROR, ROXL, ROXR.

  TODO 11 - TABLE DES OPCODES 68000 - BRANCHEMENTS/CONTROLE [IMPLEMENTE]
            BRA, BSR, Bcc, DBcc, Scc, JMP, JSR, RTS, RTE,
            RTR, NOP, STOP, RESET, ILLEGAL.

  TODO 12 - TABLE DES OPCODES 68000 - BITS ET DIVERS [IMPLEMENTE]
            BTST, BSET, BCLR, BCHG, TRAP, TRAPV, CHK,
            MOVE SR/CCR/USP, ANDI/ORI/EORI to SR/CCR.

  TODO 13 - DECODAGE DES MODES D'ADRESSAGE 68000 [IMPLEMENTE]
            Dn, An, (An), (An)+, -(An), d16(An), d8(An,Xn),
            xxx.W, xxx.L, d16(PC), d8(PC,Xn), #imm.

  TODO 14 - DECODAGE D'UNE INSTRUCTION COMPLETE [IMPLEMENTE]
            DecodeInstruction : lire le mot d instruction,
            extraire les champs, decoder les extensions.

  TODO 15 - PREMIERE PASSE : ANALYSE DU FLUX DE CONTROLE [IMPLEMENTE]
            FindLabelByAddr, AddLabel, AddXRef, IsReturn,
            IsUnconditionalJump, GetBranchTarget, IsCodeAddr,
            FirstPass, ShowFirstPassResults, CountXRefs,
            CountCallXRefs, CountBranchXRefs.

  TODO 16 - DETECTION DES SOUS-PROGRAMMES [IMPLEMENTE]
            IsLinkA6, IsUnlkA6, IsMovemPush, IsMovemPop, IsRtsAt,
            GetLinkDisp, RegMaskToStr, HasStdPrologue,
            HasStdEpilogue, DetectSubroutines, ShowSubroutines,
            CountSubroutines, IsSubroutine.

  TODO 17 - DETECTION DES APPELS SYSTEME TOS [IMPLEMENTE]
            IsTrapGemdos, IsTrapBios, IsTrapXbios, IsTrapGem,
            GetTrapFuncNum, GemdosFuncName, BiosFuncName,
            XbiosFuncName, GetTrapComment, DetectTrapCalls,
            ShowTrapCalls, CountTrapCalls, IsTrapCall.

  TODO 18 - DISCRIMINATION CODE/DONNEES DANS TEXT [IMPLEMENTE]
            AllocCodeMap, FreeCodeMap, GetCodeMapByte,
            MarkRegion, IsASCIIPrintable, DetectASCIIStringAt,
            IsJumpTableEntry, DetectJumpTableAt,
            MarkCodeRegions, ClassifyDataRegions,
            ClassifyTextRegions, ShowTextRegions,
            CountCodeBytes, CountDataBytes, CountASCIIRegions,
            CountJumpTables.

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

  { Masque et valeurs de protection memoire MiNT (bits 4-7) }
  PF_MEMPROTECT_MASK = $00F0;  { masque pour bits 4-7 }
  PF_MEMPRIVATE      = $0000;  { memoire privee (defaut) }
  PF_MEMGLOBAL       = $0010;  { memoire globale }
  PF_MEMSUPER        = $0020;  { memoire accessible en mode superviseur }
  PF_MEMREADABLE     = $0030;  { memoire lisible par tous }

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
  MAX_OPCODES    = 256;
  BUFFER_SIZE    = 65536;

  { Taille maximale de l'image en memoire (4 Mo) }
  MAX_IMAGE_SIZE = 4 * 1024 * 1024;

  { Codes de retour }
  EXIT_OK        = 0;
  EXIT_ERROR     = 1;
  EXIT_USAGE     = 2;

  { Classification code/donnees (TODO 18) }
  CM_UNKNOWN     = 0;   { non classe }
  CM_CODE        = 1;   { instruction 68000 }
  CM_DATA        = 2;   { donnee generique }
  CM_ASCII       = 3;   { chaine ASCII terminee par 0 }
  CM_JUMPTBL     = 4;   { table de saut (mots longs) }

  { Seuil minimum pour une chaine ASCII }
  MIN_ASCII_LEN  = 4;

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

  { Information d'une instruction decodee }
  TInstructionInfo = Record
    Offset    : LongInt;    { offset dans l'image memoire         }
    OpWord    : Word;       { mot d'instruction (16 bits)         }
    Mnemonic  : String[15]; { mnemonique avec suffixe de taille   }
    Operands  : TString;    { operandes formatees                 }
    TotalSize : Byte;       { taille totale en octets (2,4,6,...) }
    OpcIdx    : Integer;    { index dans OpcodeTable (0=inconnu)  }
    IsValid   : Boolean;    { instruction valide ?                }
  End;

  { Entree de la table des opcodes 68000 }
  TOpcodeEntry = Record
    Mask     : Word;      { masque de bits pour l'identification       }
    Value    : Word;      { valeur attendue apres application du masque }
    Mnemonic : String[10]; { mnemonique de l'instruction                }
    OpFormat : Byte;      { format des operandes (0=aucun, 1=Dn,       }
                          {   2=An, 3=EA, 4=imm, 5=reglist, etc.)      }
    BaseSize : Byte;      { taille de base en octets (2, 4 ou 6)       }
    Group    : Byte;      { groupe: 0=transfert, 1=arith, 2=shift,     }
                          {   3=branch, 4=bit, 5=divers                }
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

  { Table des opcodes 68000 }
  OpcodeTable : Array[1..MAX_OPCODES] Of TOpcodeEntry;
  OpcodeCount : Integer;

  { Instruction en cours de decodage }
  TmpInfo     : TInstructionInfo;

  { Variables pour le desassemblage }
  CurOfs      : LongInt;
  EndOfs      : LongInt;

  { Carte code/donnees de la section TEXT (TODO 18) }
  CodeMap     : Pointer;
  CodeMapSize : LongInt;

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
  TODO 07 - ANALYSE DES DRAPEAUX (PH_PRGFLAGS) [IMPLEMENTE]
  ============================================================ }

{ --- BoolToStr : convertir un Boolean en 'Oui'/'Non' --- }

Function BoolToStr(B: Boolean): String;
Begin
  If B Then
    BoolToStr := 'Oui'
  Else
    BoolToStr := 'Non';
End;

{ --- PrgFlagsToStr : decoder les bits de ph_prgflags en texte --- }

Function PrgFlagsToStr(Flags: LongInt): String;
Var
  S: String;
Begin
  S := '';
  If (Flags And PF_FASTLOAD) <> 0 Then Begin
    If Length(S) > 0 Then S := S + ', ';
    S := S + 'FASTLOAD';
  End;
  If (Flags And PF_TTRAMLOAD) <> 0 Then Begin
    If Length(S) > 0 Then S := S + ', ';
    S := S + 'TTRAMLOAD';
  End;
  If (Flags And PF_TTRAMMEM) <> 0 Then Begin
    If Length(S) > 0 Then S := S + ', ';
    S := S + 'TTRAMMEM';
  End;
  If (Flags And LongInt(PF_SHARED_TEXT)) <> 0 Then Begin
    If Length(S) > 0 Then S := S + ', ';
    S := S + 'SHARED_TEXT';
  End;
  If Length(S) = 0 Then
    S := '(aucun)';
  PrgFlagsToStr := S;
End;

{ --- GetMemProtection : extraire et decoder les bits 4-7 --- }
{     protection memoire MiNT/MultiTOS                        }

Function GetMemProtection(Flags: LongInt): String;
Var
  MemProt: LongInt;
Begin
  MemProt := Flags And PF_MEMPROTECT_MASK;
  Case MemProt Of
    PF_MEMPRIVATE  : GetMemProtection := 'privee (defaut)';
    PF_MEMGLOBAL   : GetMemProtection := 'globale';
    PF_MEMSUPER    : GetMemProtection := 'superviseur seulement';
    PF_MEMREADABLE : GetMemProtection := 'lisible par tous';
  Else
    GetMemProtection := 'inconnue ($' + HexByte(Byte(MemProt)) + ')';
  End;
End;

{ --- ShowPrgFlags : affichage detaille des drapeaux du programme --- }

Procedure ShowPrgFlags(Var H: TPrgHeader; Verbose: Boolean);
Var
  Flags: LongInt;
Begin
  If Not Verbose Then Exit;
  Flags := H.ph_prgflags;
  WriteLn;
  WriteLn('=== Drapeaux du programme (ph_prgflags = $',
          HexLong(Flags), ') ===');
  WriteLn('  Drapeaux actifs : ', PrgFlagsToStr(Flags));
  WriteLn('  Bit 0 FASTLOAD  : ',
    BoolToStr((Flags And PF_FASTLOAD) <> 0));
  WriteLn('  Bit 1 TTRAMLOAD : ',
    BoolToStr((Flags And PF_TTRAMLOAD) <> 0));
  WriteLn('  Bit 2 TTRAMMEM  : ',
    BoolToStr((Flags And PF_TTRAMMEM) <> 0));
  WriteLn('  Bits 4-7 memoire: ', GetMemProtection(Flags));
  WriteLn('  Bit 28 SHARED   : ',
    BoolToStr((Flags And LongInt(PF_SHARED_TEXT)) <> 0));
End;

{ --- HasPrgFlag : tester si un drapeau est actif --- }

Function HasPrgFlag(Var H: TPrgHeader; Flag: LongInt): Boolean;
Begin
  HasPrgFlag := (H.ph_prgflags And Flag) <> 0;
End;

{ ============================================================
  TODO 08 - TABLE DES OPCODES 68000 - TRANSFERT [IMPLEMENTE]
  ============================================================ }

{ Groupes d'opcodes }
Const
  GRP_TRANSFER = 0;   { transfert de donnees }
  GRP_ARITH    = 1;   { arithmetique/logique }
  GRP_SHIFT    = 2;   { decalages/rotations }
  GRP_BRANCH   = 3;   { branchements/controle }
  GRP_BIT      = 4;   { manipulation de bits }
  GRP_MISC     = 5;   { divers }

{ Formats d'operandes }
Const
  FMT_NONE     = 0;   { pas d'operande (NOP, RTS, etc.)       }
  FMT_EA_EA    = 1;   { MOVE ea,ea                            }
  FMT_EA_AN    = 2;   { MOVEA ea,An                           }
  FMT_IMM8_DN  = 3;   { MOVEQ #imm8,Dn                       }
  FMT_REGLIST  = 4;   { MOVEM reglist,ea / ea,reglist          }
  FMT_DN_AN    = 5;   { MOVEP Dn,d16(An) / d16(An),Dn         }
  FMT_DN_DN    = 6;   { EXG Dn,Dn / An,An / Dn,An             }
  FMT_DN       = 7;   { SWAP Dn                               }
  FMT_EA_AN2   = 8;   { LEA ea,An                             }
  FMT_EA       = 9;   { PEA ea / CLR ea / TST ea etc.         }
  FMT_AN_DISP  = 10;  { LINK An,#disp / UNLK An               }
  FMT_AN       = 11;  { UNLK An                               }
  FMT_EA_DN    = 12;  { ADD ea,Dn / SUB ea,Dn / AND ea,Dn etc. }
  FMT_DN_EA    = 13;  { ADD Dn,ea / SUB Dn,ea / AND Dn,ea etc. }
  FMT_EA_AN3   = 14;  { ADDA ea,An / SUBA ea,An / CMPA ea,An   }
  FMT_IMM_EA   = 15;  { ADDI #imm,ea / SUBI / ANDI / ORI etc.  }
  FMT_IMM3_EA  = 16;  { ADDQ #1-8,ea / SUBQ #1-8,ea            }
  FMT_DN_DN2   = 17;  { ADDX Dn,Dn / SUBX Dn,Dn / CMPM (An)+  }
  FMT_WORD_DN  = 18;  { MULU ea,Dn / MULS ea,Dn / DIVU / DIVS  }
  FMT_DN2      = 19;  { NOT Dn / NEG Dn / NEGX Dn / EXT Dn     }
  FMT_SH_REG   = 20;  { ASL/ASR/LSL/LSR/ROL/ROR Dn (reg count) }
  FMT_SH_IMM   = 21;  { ASL/ASR/LSL/LSR/ROL/ROR #imm3,Dn       }
  FMT_SH_MEM   = 22;  { ASL/ASR/LSL/LSR/ROL/ROR ea (1 bit)     }
  FMT_BRA      = 23;  { BRA/BSR/Bcc d8/d16                     }
  FMT_DBCC     = 24;  { DBcc Dn,d16                            }
  FMT_SCC      = 25;  { Scc ea                                 }
  FMT_EA2      = 26;  { JMP ea / JSR ea                        }
  FMT_IMM16    = 27;  { STOP #imm16                            }
  FMT_TRAP     = 28;  { TRAP #vector (0-15)                    }
  FMT_BIT_DN   = 29;  { BTST/BSET/BCLR/BCHG Dn,ea             }
  FMT_BIT_IMM  = 30;  { BTST/BSET/BCLR/BCHG #imm,ea           }
  FMT_SR       = 31;  { MOVE ea,SR / MOVE SR,ea                }
  FMT_CCR      = 32;  { MOVE ea,CCR / MOVE CCR,ea              }
  FMT_USP      = 33;  { MOVE USP,An / MOVE An,USP              }
  FMT_IMM_SR   = 34;  { ANDI/ORI/EORI #imm,SR                  }
  FMT_IMM_CCR  = 35;  { ANDI/ORI/EORI #imm,CCR                 }
  FMT_CHK      = 36;  { CHK ea,Dn                              }

{ --- AddOpcode : ajouter une entree dans la table --- }

Procedure AddOpcode(AMask, AValue: Word; AMnemonic: String;
                    AFormat, ABaseSize, AGroup: Byte);
Begin
  If OpcodeCount >= MAX_OPCODES Then
    FatalError('Table des opcodes pleine (max ' +
               IntToStr(MAX_OPCODES) + ')');
  Inc(OpcodeCount);
  OpcodeTable[OpcodeCount].Mask     := AMask;
  OpcodeTable[OpcodeCount].Value    := AValue;
  OpcodeTable[OpcodeCount].Mnemonic := AMnemonic;
  OpcodeTable[OpcodeCount].OpFormat := AFormat;
  OpcodeTable[OpcodeCount].BaseSize := ABaseSize;
  OpcodeTable[OpcodeCount].Group    := AGroup;
End;

{ --- InitTransferOpcodes : opcodes de transfert de donnees --- }

Procedure InitTransferOpcodes;
Begin
  { MOVE.B ea,ea : 0001 xxxx xxxx xxxx }
  AddOpcode($F000, $1000, 'MOVE.B', FMT_EA_EA, 2, GRP_TRANSFER);
  { MOVEA.W ea,An : 0011 xxx0 01xx xxxx }
  AddOpcode($F1C0, $3040, 'MOVEA.W', FMT_EA_AN, 2, GRP_TRANSFER);
  { MOVE.W ea,ea : 0011 xxxx xxxx xxxx }
  AddOpcode($F000, $3000, 'MOVE.W', FMT_EA_EA, 2, GRP_TRANSFER);
  { MOVEA.L ea,An : 0010 xxx0 01xx xxxx }
  AddOpcode($F1C0, $2040, 'MOVEA.L', FMT_EA_AN, 2, GRP_TRANSFER);
  { MOVE.L ea,ea : 0010 xxxx xxxx xxxx }
  AddOpcode($F000, $2000, 'MOVE.L', FMT_EA_EA, 2, GRP_TRANSFER);
  { MOVEQ #imm8,Dn : 0111 xxx0 xxxx xxxx }
  AddOpcode($F100, $7000, 'MOVEQ', FMT_IMM8_DN, 2, GRP_TRANSFER);
  { MOVEM.W reglist,ea : 0100 1000 10xx xxxx }
  AddOpcode($FFC0, $4880, 'MOVEM.W', FMT_REGLIST, 4, GRP_TRANSFER);
  { MOVEM.L reglist,ea : 0100 1000 11xx xxxx }
  AddOpcode($FFC0, $48C0, 'MOVEM.L', FMT_REGLIST, 4, GRP_TRANSFER);
  { MOVEM.W ea,reglist : 0100 1100 10xx xxxx }
  AddOpcode($FFC0, $4C80, 'MOVEM.W', FMT_REGLIST, 4, GRP_TRANSFER);
  { MOVEM.L ea,reglist : 0100 1100 11xx xxxx }
  AddOpcode($FFC0, $4CC0, 'MOVEM.L', FMT_REGLIST, 4, GRP_TRANSFER);
  { MOVEP.W Dn,d16(An) : 0000 xxx1 1000 1xxx }
  AddOpcode($F1F8, $0188, 'MOVEP.W', FMT_DN_AN, 4, GRP_TRANSFER);
  { MOVEP.L Dn,d16(An) : 0000 xxx1 1100 1xxx }
  AddOpcode($F1F8, $01C8, 'MOVEP.L', FMT_DN_AN, 4, GRP_TRANSFER);
  { MOVEP.W d16(An),Dn : 0000 xxx1 0000 1xxx }
  AddOpcode($F1F8, $0108, 'MOVEP.W', FMT_DN_AN, 4, GRP_TRANSFER);
  { MOVEP.L d16(An),Dn : 0000 xxx1 0100 1xxx }
  AddOpcode($F1F8, $0148, 'MOVEP.L', FMT_DN_AN, 4, GRP_TRANSFER);
  { EXG Dn,Dn : 1100 xxx1 0100 0xxx }
  AddOpcode($F1F8, $C140, 'EXG', FMT_DN_DN, 2, GRP_TRANSFER);
  { EXG An,An : 1100 xxx1 0100 1xxx }
  AddOpcode($F1F8, $C148, 'EXG', FMT_DN_DN, 2, GRP_TRANSFER);
  { EXG Dn,An : 1100 xxx1 1000 1xxx }
  AddOpcode($F1F8, $C188, 'EXG', FMT_DN_DN, 2, GRP_TRANSFER);
  { SWAP Dn : 0100 1000 0100 0xxx }
  { Note: SWAP ($FFF8/$4840) doit etre avant PEA ($FFC0/$4840) }
  { car ils partagent la meme valeur de base. La recherche      }
  { lineaire dans FindOpcode trouvera SWAP en premier pour les  }
  { registres Dn (bits 0-2), et PEA pour les autres modes.     }
  AddOpcode($FFF8, $4840, 'SWAP', FMT_DN, 2, GRP_TRANSFER);
  { LEA ea,An : 0100 xxx1 11xx xxxx }
  AddOpcode($F1C0, $41C0, 'LEA', FMT_EA_AN2, 2, GRP_TRANSFER);
  { PEA ea : 0100 1000 01xx xxxx }
  { Note: voir commentaire SWAP ci-dessus pour le chevauchement }
  AddOpcode($FFC0, $4840, 'PEA', FMT_EA, 2, GRP_TRANSFER);
  { LINK An,#d16 : 0100 1110 0101 0xxx }
  AddOpcode($FFF8, $4E50, 'LINK', FMT_AN_DISP, 4, GRP_TRANSFER);
  { UNLK An : 0100 1110 0101 1xxx }
  AddOpcode($FFF8, $4E58, 'UNLK', FMT_AN, 2, GRP_TRANSFER);
End;

{ ============================================================
  TODO 09 - TABLE DES OPCODES 68000 - ARITH/LOGIQUE [IMPLEMENTE]
  ============================================================ }

{ --- InitArithLogicOpcodes : opcodes arithmetiques et logiques --- }

Procedure InitArithLogicOpcodes;
Begin
  { === ADD / ADDA / ADDI / ADDQ / ADDX === }

  { ADDI.B #imm8,ea : 0000 0110 00xx xxxx }
  AddOpcode($FFC0, $0600, 'ADDI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { ADDI.W #imm16,ea : 0000 0110 01xx xxxx }
  AddOpcode($FFC0, $0640, 'ADDI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { ADDI.L #imm32,ea : 0000 0110 10xx xxxx }
  AddOpcode($FFC0, $0680, 'ADDI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { ADDQ.B #data3,ea : 0101 xxx0 00xx xxxx }
  AddOpcode($F1C0, $5000, 'ADDQ.B', FMT_IMM3_EA, 2, GRP_ARITH);
  { ADDQ.W #data3,ea : 0101 xxx0 01xx xxxx }
  AddOpcode($F1C0, $5040, 'ADDQ.W', FMT_IMM3_EA, 2, GRP_ARITH);
  { ADDQ.L #data3,ea : 0101 xxx0 10xx xxxx }
  AddOpcode($F1C0, $5080, 'ADDQ.L', FMT_IMM3_EA, 2, GRP_ARITH);
  { ADDX.B Dn,Dn : 1101 xxx1 0000 0xxx }
  AddOpcode($F1F8, $D100, 'ADDX.B', FMT_DN_DN2, 2, GRP_ARITH);
  { ADDX.W Dn,Dn : 1101 xxx1 0100 0xxx }
  AddOpcode($F1F8, $D140, 'ADDX.W', FMT_DN_DN2, 2, GRP_ARITH);
  { ADDX.L Dn,Dn : 1101 xxx1 1000 0xxx }
  AddOpcode($F1F8, $D180, 'ADDX.L', FMT_DN_DN2, 2, GRP_ARITH);
  { ADDA.W ea,An : 1101 xxx0 11xx xxxx }
  AddOpcode($F1C0, $D0C0, 'ADDA.W', FMT_EA_AN3, 2, GRP_ARITH);
  { ADDA.L ea,An : 1101 xxx1 11xx xxxx }
  AddOpcode($F1C0, $D1C0, 'ADDA.L', FMT_EA_AN3, 2, GRP_ARITH);
  { ADD.B ea,Dn : 1101 xxx0 00xx xxxx }
  AddOpcode($F1C0, $D000, 'ADD.B', FMT_EA_DN, 2, GRP_ARITH);
  { ADD.W ea,Dn : 1101 xxx0 01xx xxxx }
  AddOpcode($F1C0, $D040, 'ADD.W', FMT_EA_DN, 2, GRP_ARITH);
  { ADD.L ea,Dn : 1101 xxx0 10xx xxxx }
  AddOpcode($F1C0, $D080, 'ADD.L', FMT_EA_DN, 2, GRP_ARITH);
  { ADD.B Dn,ea : 1101 xxx1 00xx xxxx }
  AddOpcode($F1C0, $D100, 'ADD.B', FMT_DN_EA, 2, GRP_ARITH);
  { ADD.W Dn,ea : 1101 xxx1 01xx xxxx }
  AddOpcode($F1C0, $D140, 'ADD.W', FMT_DN_EA, 2, GRP_ARITH);
  { ADD.L Dn,ea : 1101 xxx1 10xx xxxx }
  AddOpcode($F1C0, $D180, 'ADD.L', FMT_DN_EA, 2, GRP_ARITH);

  { === SUB / SUBA / SUBI / SUBQ / SUBX === }

  { SUBI.B #imm8,ea : 0000 0100 00xx xxxx }
  AddOpcode($FFC0, $0400, 'SUBI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { SUBI.W #imm16,ea : 0000 0100 01xx xxxx }
  AddOpcode($FFC0, $0440, 'SUBI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { SUBI.L #imm32,ea : 0000 0100 10xx xxxx }
  AddOpcode($FFC0, $0480, 'SUBI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { SUBQ.B #data3,ea : 0101 xxx1 00xx xxxx }
  AddOpcode($F1C0, $5100, 'SUBQ.B', FMT_IMM3_EA, 2, GRP_ARITH);
  { SUBQ.W #data3,ea : 0101 xxx1 01xx xxxx }
  AddOpcode($F1C0, $5140, 'SUBQ.W', FMT_IMM3_EA, 2, GRP_ARITH);
  { SUBQ.L #data3,ea : 0101 xxx1 10xx xxxx }
  AddOpcode($F1C0, $5180, 'SUBQ.L', FMT_IMM3_EA, 2, GRP_ARITH);
  { SUBX.B Dn,Dn : 1001 xxx1 0000 0xxx }
  AddOpcode($F1F8, $9100, 'SUBX.B', FMT_DN_DN2, 2, GRP_ARITH);
  { SUBX.W Dn,Dn : 1001 xxx1 0100 0xxx }
  AddOpcode($F1F8, $9140, 'SUBX.W', FMT_DN_DN2, 2, GRP_ARITH);
  { SUBX.L Dn,Dn : 1001 xxx1 1000 0xxx }
  AddOpcode($F1F8, $9180, 'SUBX.L', FMT_DN_DN2, 2, GRP_ARITH);
  { SUBA.W ea,An : 1001 xxx0 11xx xxxx }
  AddOpcode($F1C0, $90C0, 'SUBA.W', FMT_EA_AN3, 2, GRP_ARITH);
  { SUBA.L ea,An : 1001 xxx1 11xx xxxx }
  AddOpcode($F1C0, $91C0, 'SUBA.L', FMT_EA_AN3, 2, GRP_ARITH);
  { SUB.B ea,Dn : 1001 xxx0 00xx xxxx }
  AddOpcode($F1C0, $9000, 'SUB.B', FMT_EA_DN, 2, GRP_ARITH);
  { SUB.W ea,Dn : 1001 xxx0 01xx xxxx }
  AddOpcode($F1C0, $9040, 'SUB.W', FMT_EA_DN, 2, GRP_ARITH);
  { SUB.L ea,Dn : 1001 xxx0 10xx xxxx }
  AddOpcode($F1C0, $9080, 'SUB.L', FMT_EA_DN, 2, GRP_ARITH);
  { SUB.B Dn,ea : 1001 xxx1 00xx xxxx }
  AddOpcode($F1C0, $9100, 'SUB.B', FMT_DN_EA, 2, GRP_ARITH);
  { SUB.W Dn,ea : 1001 xxx1 01xx xxxx }
  AddOpcode($F1C0, $9140, 'SUB.W', FMT_DN_EA, 2, GRP_ARITH);
  { SUB.L Dn,ea : 1001 xxx1 10xx xxxx }
  AddOpcode($F1C0, $9180, 'SUB.L', FMT_DN_EA, 2, GRP_ARITH);

  { === MULU / MULS / DIVU / DIVS === }

  { MULU.W ea,Dn : 1100 xxx0 11xx xxxx }
  AddOpcode($F1C0, $C0C0, 'MULU.W', FMT_WORD_DN, 2, GRP_ARITH);
  { MULS.W ea,Dn : 1100 xxx1 11xx xxxx }
  AddOpcode($F1C0, $C1C0, 'MULS.W', FMT_WORD_DN, 2, GRP_ARITH);
  { DIVU.W ea,Dn : 1000 xxx0 11xx xxxx }
  AddOpcode($F1C0, $80C0, 'DIVU.W', FMT_WORD_DN, 2, GRP_ARITH);
  { DIVS.W ea,Dn : 1000 xxx1 11xx xxxx }
  AddOpcode($F1C0, $81C0, 'DIVS.W', FMT_WORD_DN, 2, GRP_ARITH);

  { === AND / ANDI / OR / ORI / EOR / EORI === }

  { ANDI.B #imm8,ea : 0000 0010 00xx xxxx }
  AddOpcode($FFC0, $0200, 'ANDI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { ANDI.W #imm16,ea : 0000 0010 01xx xxxx }
  AddOpcode($FFC0, $0240, 'ANDI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { ANDI.L #imm32,ea : 0000 0010 10xx xxxx }
  AddOpcode($FFC0, $0280, 'ANDI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { AND.B ea,Dn : 1100 xxx0 00xx xxxx }
  AddOpcode($F1C0, $C000, 'AND.B', FMT_EA_DN, 2, GRP_ARITH);
  { AND.W ea,Dn : 1100 xxx0 01xx xxxx }
  AddOpcode($F1C0, $C040, 'AND.W', FMT_EA_DN, 2, GRP_ARITH);
  { AND.L ea,Dn : 1100 xxx0 10xx xxxx }
  AddOpcode($F1C0, $C080, 'AND.L', FMT_EA_DN, 2, GRP_ARITH);
  { AND.B Dn,ea : 1100 xxx1 00xx xxxx }
  AddOpcode($F1C0, $C100, 'AND.B', FMT_DN_EA, 2, GRP_ARITH);
  { AND.W Dn,ea : 1100 xxx1 01xx xxxx }
  AddOpcode($F1C0, $C140, 'AND.W', FMT_DN_EA, 2, GRP_ARITH);
  { AND.L Dn,ea : 1100 xxx1 10xx xxxx }
  AddOpcode($F1C0, $C180, 'AND.L', FMT_DN_EA, 2, GRP_ARITH);
  { ORI.B #imm8,ea : 0000 0000 00xx xxxx }
  AddOpcode($FFC0, $0000, 'ORI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { ORI.W #imm16,ea : 0000 0000 01xx xxxx }
  AddOpcode($FFC0, $0040, 'ORI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { ORI.L #imm32,ea : 0000 0000 10xx xxxx }
  AddOpcode($FFC0, $0080, 'ORI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { OR.B ea,Dn : 1000 xxx0 00xx xxxx }
  AddOpcode($F1C0, $8000, 'OR.B', FMT_EA_DN, 2, GRP_ARITH);
  { OR.W ea,Dn : 1000 xxx0 01xx xxxx }
  AddOpcode($F1C0, $8040, 'OR.W', FMT_EA_DN, 2, GRP_ARITH);
  { OR.L ea,Dn : 1000 xxx0 10xx xxxx }
  AddOpcode($F1C0, $8080, 'OR.L', FMT_EA_DN, 2, GRP_ARITH);
  { OR.B Dn,ea : 1000 xxx1 00xx xxxx }
  AddOpcode($F1C0, $8100, 'OR.B', FMT_DN_EA, 2, GRP_ARITH);
  { OR.W Dn,ea : 1000 xxx1 01xx xxxx }
  AddOpcode($F1C0, $8140, 'OR.W', FMT_DN_EA, 2, GRP_ARITH);
  { OR.L Dn,ea : 1000 xxx1 10xx xxxx }
  AddOpcode($F1C0, $8180, 'OR.L', FMT_DN_EA, 2, GRP_ARITH);
  { EORI.B #imm8,ea : 0000 1010 00xx xxxx }
  AddOpcode($FFC0, $0A00, 'EORI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { EORI.W #imm16,ea : 0000 1010 01xx xxxx }
  AddOpcode($FFC0, $0A40, 'EORI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { EORI.L #imm32,ea : 0000 1010 10xx xxxx }
  AddOpcode($FFC0, $0A80, 'EORI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { EOR.B Dn,ea : 1011 xxx1 00xx xxxx }
  AddOpcode($F1C0, $B100, 'EOR.B', FMT_DN_EA, 2, GRP_ARITH);
  { EOR.W Dn,ea : 1011 xxx1 01xx xxxx }
  AddOpcode($F1C0, $B140, 'EOR.W', FMT_DN_EA, 2, GRP_ARITH);
  { EOR.L Dn,ea : 1011 xxx1 10xx xxxx }
  AddOpcode($F1C0, $B180, 'EOR.L', FMT_DN_EA, 2, GRP_ARITH);

  { === NOT / NEG / NEGX === }

  { NOT.B ea : 0100 0110 00xx xxxx }
  AddOpcode($FFC0, $4600, 'NOT.B', FMT_EA, 2, GRP_ARITH);
  { NOT.W ea : 0100 0110 01xx xxxx }
  AddOpcode($FFC0, $4640, 'NOT.W', FMT_EA, 2, GRP_ARITH);
  { NOT.L ea : 0100 0110 10xx xxxx }
  AddOpcode($FFC0, $4680, 'NOT.L', FMT_EA, 2, GRP_ARITH);
  { NEG.B ea : 0100 0100 00xx xxxx }
  AddOpcode($FFC0, $4400, 'NEG.B', FMT_EA, 2, GRP_ARITH);
  { NEG.W ea : 0100 0100 01xx xxxx }
  AddOpcode($FFC0, $4440, 'NEG.W', FMT_EA, 2, GRP_ARITH);
  { NEG.L ea : 0100 0100 10xx xxxx }
  AddOpcode($FFC0, $4480, 'NEG.L', FMT_EA, 2, GRP_ARITH);
  { NEGX.B ea : 0100 0000 00xx xxxx }
  AddOpcode($FFC0, $4000, 'NEGX.B', FMT_EA, 2, GRP_ARITH);
  { NEGX.W ea : 0100 0000 01xx xxxx }
  AddOpcode($FFC0, $4040, 'NEGX.W', FMT_EA, 2, GRP_ARITH);
  { NEGX.L ea : 0100 0000 10xx xxxx }
  AddOpcode($FFC0, $4080, 'NEGX.L', FMT_EA, 2, GRP_ARITH);

  { === CMP / CMPA / CMPI / CMPM === }

  { CMPI.B #imm8,ea : 0000 1100 00xx xxxx }
  AddOpcode($FFC0, $0C00, 'CMPI.B', FMT_IMM_EA, 4, GRP_ARITH);
  { CMPI.W #imm16,ea : 0000 1100 01xx xxxx }
  AddOpcode($FFC0, $0C40, 'CMPI.W', FMT_IMM_EA, 4, GRP_ARITH);
  { CMPI.L #imm32,ea : 0000 1100 10xx xxxx }
  AddOpcode($FFC0, $0C80, 'CMPI.L', FMT_IMM_EA, 6, GRP_ARITH);
  { CMPM.B (An)+,(An)+ : 1011 xxx1 0000 1xxx }
  AddOpcode($F1F8, $B108, 'CMPM.B', FMT_DN_DN2, 2, GRP_ARITH);
  { CMPM.W (An)+,(An)+ : 1011 xxx1 0100 1xxx }
  AddOpcode($F1F8, $B148, 'CMPM.W', FMT_DN_DN2, 2, GRP_ARITH);
  { CMPM.L (An)+,(An)+ : 1011 xxx1 1000 1xxx }
  AddOpcode($F1F8, $B188, 'CMPM.L', FMT_DN_DN2, 2, GRP_ARITH);
  { CMPA.W ea,An : 1011 xxx0 11xx xxxx }
  AddOpcode($F1C0, $B0C0, 'CMPA.W', FMT_EA_AN3, 2, GRP_ARITH);
  { CMPA.L ea,An : 1011 xxx1 11xx xxxx }
  AddOpcode($F1C0, $B1C0, 'CMPA.L', FMT_EA_AN3, 2, GRP_ARITH);
  { CMP.B ea,Dn : 1011 xxx0 00xx xxxx }
  AddOpcode($F1C0, $B000, 'CMP.B', FMT_EA_DN, 2, GRP_ARITH);
  { CMP.W ea,Dn : 1011 xxx0 01xx xxxx }
  AddOpcode($F1C0, $B040, 'CMP.W', FMT_EA_DN, 2, GRP_ARITH);
  { CMP.L ea,Dn : 1011 xxx0 10xx xxxx }
  AddOpcode($F1C0, $B080, 'CMP.L', FMT_EA_DN, 2, GRP_ARITH);

  { === CLR / EXT / TST / TAS === }

  { CLR.B ea : 0100 0010 00xx xxxx }
  AddOpcode($FFC0, $4200, 'CLR.B', FMT_EA, 2, GRP_ARITH);
  { CLR.W ea : 0100 0010 01xx xxxx }
  AddOpcode($FFC0, $4240, 'CLR.W', FMT_EA, 2, GRP_ARITH);
  { CLR.L ea : 0100 0010 10xx xxxx }
  AddOpcode($FFC0, $4280, 'CLR.L', FMT_EA, 2, GRP_ARITH);
  { EXT.W Dn : 0100 1000 1000 0xxx }
  AddOpcode($FFF8, $4880, 'EXT.W', FMT_DN2, 2, GRP_ARITH);
  { EXT.L Dn : 0100 1000 1100 0xxx }
  AddOpcode($FFF8, $48C0, 'EXT.L', FMT_DN2, 2, GRP_ARITH);
  { TST.B ea : 0100 1010 00xx xxxx }
  AddOpcode($FFC0, $4A00, 'TST.B', FMT_EA, 2, GRP_ARITH);
  { TST.W ea : 0100 1010 01xx xxxx }
  AddOpcode($FFC0, $4A40, 'TST.W', FMT_EA, 2, GRP_ARITH);
  { TST.L ea : 0100 1010 10xx xxxx }
  AddOpcode($FFC0, $4A80, 'TST.L', FMT_EA, 2, GRP_ARITH);
  { TAS.B ea : 0100 1010 11xx xxxx }
  AddOpcode($FFC0, $4AC0, 'TAS.B', FMT_EA, 2, GRP_ARITH);
End;

{ ============================================================
  TODO 10 - TABLE DES OPCODES 68000 - DECALAGES/ROTATIONS [IMPLEMENTE]
  ============================================================ }

{ --- InitShiftRotateOpcodes : opcodes de decalage et rotation --- }

Procedure InitShiftRotateOpcodes;
Begin
  { === ASL - Arithmetic Shift Left === }

  { ASL.B Dn,Dn : 1110 xxx1 0010 0xxx }
  AddOpcode($F1F8, $E120, 'ASL.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ASL.W Dn,Dn : 1110 xxx1 0110 0xxx }
  AddOpcode($F1F8, $E160, 'ASL.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ASL.L Dn,Dn : 1110 xxx1 1010 0xxx }
  AddOpcode($F1F8, $E1A0, 'ASL.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ASL.B #imm3,Dn : 1110 xxx1 0000 0xxx }
  AddOpcode($F1F8, $E100, 'ASL.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASL.W #imm3,Dn : 1110 xxx1 0100 0xxx }
  AddOpcode($F1F8, $E140, 'ASL.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASL.L #imm3,Dn : 1110 xxx1 1000 0xxx }
  AddOpcode($F1F8, $E180, 'ASL.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASL.W ea : 1110 0001 11xx xxxx }
  AddOpcode($FFC0, $E1C0, 'ASL.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === ASR - Arithmetic Shift Right === }

  { ASR.B Dn,Dn : 1110 xxx0 0010 0xxx }
  AddOpcode($F1F8, $E020, 'ASR.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ASR.W Dn,Dn : 1110 xxx0 0110 0xxx }
  AddOpcode($F1F8, $E060, 'ASR.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ASR.L Dn,Dn : 1110 xxx0 1010 0xxx }
  AddOpcode($F1F8, $E0A0, 'ASR.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ASR.B #imm3,Dn : 1110 xxx0 0000 0xxx }
  AddOpcode($F1F8, $E000, 'ASR.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASR.W #imm3,Dn : 1110 xxx0 0100 0xxx }
  AddOpcode($F1F8, $E040, 'ASR.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASR.L #imm3,Dn : 1110 xxx0 1000 0xxx }
  AddOpcode($F1F8, $E080, 'ASR.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ASR.W ea : 1110 0000 11xx xxxx }
  AddOpcode($FFC0, $E0C0, 'ASR.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === LSL - Logical Shift Left === }

  { LSL.B Dn,Dn : 1110 xxx1 0010 1xxx }
  AddOpcode($F1F8, $E128, 'LSL.B', FMT_SH_REG, 2, GRP_SHIFT);
  { LSL.W Dn,Dn : 1110 xxx1 0110 1xxx }
  AddOpcode($F1F8, $E168, 'LSL.W', FMT_SH_REG, 2, GRP_SHIFT);
  { LSL.L Dn,Dn : 1110 xxx1 1010 1xxx }
  AddOpcode($F1F8, $E1A8, 'LSL.L', FMT_SH_REG, 2, GRP_SHIFT);
  { LSL.B #imm3,Dn : 1110 xxx1 0000 1xxx }
  AddOpcode($F1F8, $E108, 'LSL.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSL.W #imm3,Dn : 1110 xxx1 0100 1xxx }
  AddOpcode($F1F8, $E148, 'LSL.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSL.L #imm3,Dn : 1110 xxx1 1000 1xxx }
  AddOpcode($F1F8, $E188, 'LSL.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSL.W ea : 1110 0011 11xx xxxx }
  AddOpcode($FFC0, $E3C0, 'LSL.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === LSR - Logical Shift Right === }

  { LSR.B Dn,Dn : 1110 xxx0 0010 1xxx }
  AddOpcode($F1F8, $E028, 'LSR.B', FMT_SH_REG, 2, GRP_SHIFT);
  { LSR.W Dn,Dn : 1110 xxx0 0110 1xxx }
  AddOpcode($F1F8, $E068, 'LSR.W', FMT_SH_REG, 2, GRP_SHIFT);
  { LSR.L Dn,Dn : 1110 xxx0 1010 1xxx }
  AddOpcode($F1F8, $E0A8, 'LSR.L', FMT_SH_REG, 2, GRP_SHIFT);
  { LSR.B #imm3,Dn : 1110 xxx0 0000 1xxx }
  AddOpcode($F1F8, $E008, 'LSR.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSR.W #imm3,Dn : 1110 xxx0 0100 1xxx }
  AddOpcode($F1F8, $E048, 'LSR.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSR.L #imm3,Dn : 1110 xxx0 1000 1xxx }
  AddOpcode($F1F8, $E088, 'LSR.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { LSR.W ea : 1110 0010 11xx xxxx }
  AddOpcode($FFC0, $E2C0, 'LSR.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === ROL - Rotate Left === }

  { ROL.B Dn,Dn : 1110 xxx1 0011 1xxx }
  AddOpcode($F1F8, $E138, 'ROL.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ROL.W Dn,Dn : 1110 xxx1 0111 1xxx }
  AddOpcode($F1F8, $E178, 'ROL.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ROL.L Dn,Dn : 1110 xxx1 1011 1xxx }
  AddOpcode($F1F8, $E1B8, 'ROL.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ROL.B #imm3,Dn : 1110 xxx1 0001 1xxx }
  AddOpcode($F1F8, $E118, 'ROL.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROL.W #imm3,Dn : 1110 xxx1 0101 1xxx }
  AddOpcode($F1F8, $E158, 'ROL.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROL.L #imm3,Dn : 1110 xxx1 1001 1xxx }
  AddOpcode($F1F8, $E198, 'ROL.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROL.W ea : 1110 0111 11xx xxxx }
  AddOpcode($FFC0, $E7C0, 'ROL.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === ROR - Rotate Right === }

  { ROR.B Dn,Dn : 1110 xxx0 0011 1xxx }
  AddOpcode($F1F8, $E038, 'ROR.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ROR.W Dn,Dn : 1110 xxx0 0111 1xxx }
  AddOpcode($F1F8, $E078, 'ROR.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ROR.L Dn,Dn : 1110 xxx0 1011 1xxx }
  AddOpcode($F1F8, $E0B8, 'ROR.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ROR.B #imm3,Dn : 1110 xxx0 0001 1xxx }
  AddOpcode($F1F8, $E018, 'ROR.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROR.W #imm3,Dn : 1110 xxx0 0101 1xxx }
  AddOpcode($F1F8, $E058, 'ROR.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROR.L #imm3,Dn : 1110 xxx0 1001 1xxx }
  AddOpcode($F1F8, $E098, 'ROR.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROR.W ea : 1110 0110 11xx xxxx }
  AddOpcode($FFC0, $E6C0, 'ROR.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === ROXL - Rotate Left with Extend === }

  { ROXL.B Dn,Dn : 1110 xxx1 0011 0xxx }
  AddOpcode($F1F8, $E130, 'ROXL.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXL.W Dn,Dn : 1110 xxx1 0111 0xxx }
  AddOpcode($F1F8, $E170, 'ROXL.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXL.L Dn,Dn : 1110 xxx1 1011 0xxx }
  AddOpcode($F1F8, $E1B0, 'ROXL.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXL.B #imm3,Dn : 1110 xxx1 0001 0xxx }
  AddOpcode($F1F8, $E110, 'ROXL.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXL.W #imm3,Dn : 1110 xxx1 0101 0xxx }
  AddOpcode($F1F8, $E150, 'ROXL.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXL.L #imm3,Dn : 1110 xxx1 1001 0xxx }
  AddOpcode($F1F8, $E190, 'ROXL.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXL.W ea : 1110 0101 11xx xxxx }
  AddOpcode($FFC0, $E5C0, 'ROXL.W', FMT_SH_MEM, 2, GRP_SHIFT);

  { === ROXR - Rotate Right with Extend === }

  { ROXR.B Dn,Dn : 1110 xxx0 0011 0xxx }
  AddOpcode($F1F8, $E030, 'ROXR.B', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXR.W Dn,Dn : 1110 xxx0 0111 0xxx }
  AddOpcode($F1F8, $E070, 'ROXR.W', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXR.L Dn,Dn : 1110 xxx0 1011 0xxx }
  AddOpcode($F1F8, $E0B0, 'ROXR.L', FMT_SH_REG, 2, GRP_SHIFT);
  { ROXR.B #imm3,Dn : 1110 xxx0 0001 0xxx }
  AddOpcode($F1F8, $E010, 'ROXR.B', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXR.W #imm3,Dn : 1110 xxx0 0101 0xxx }
  AddOpcode($F1F8, $E050, 'ROXR.W', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXR.L #imm3,Dn : 1110 xxx0 1001 0xxx }
  AddOpcode($F1F8, $E090, 'ROXR.L', FMT_SH_IMM, 2, GRP_SHIFT);
  { ROXR.W ea : 1110 0100 11xx xxxx }
  AddOpcode($FFC0, $E4C0, 'ROXR.W', FMT_SH_MEM, 2, GRP_SHIFT);
End;

{ ============================================================
  TODO 11 - TABLE DES OPCODES 68000 - BRANCHEMENTS/CONTROLE [IMPLEMENTE]
  ============================================================ }

{ --- InitBranchControlOpcodes : opcodes de branchement et controle --- }

Procedure InitBranchControlOpcodes;
Begin
  { === Bcc - Branchements conditionnels === }
  { Bcc : 0110 cccc dddd dddd (cccc=condition, d=deplacement 8/16) }

  { BRA : 0110 0000 dddd dddd }
  AddOpcode($FF00, $6000, 'BRA', FMT_BRA, 2, GRP_BRANCH);
  { BSR : 0110 0001 dddd dddd }
  AddOpcode($FF00, $6100, 'BSR', FMT_BRA, 2, GRP_BRANCH);
  { BHI : 0110 0010 dddd dddd }
  AddOpcode($FF00, $6200, 'BHI', FMT_BRA, 2, GRP_BRANCH);
  { BLS : 0110 0011 dddd dddd }
  AddOpcode($FF00, $6300, 'BLS', FMT_BRA, 2, GRP_BRANCH);
  { BCC : 0110 0100 dddd dddd }
  AddOpcode($FF00, $6400, 'BCC', FMT_BRA, 2, GRP_BRANCH);
  { BCS : 0110 0101 dddd dddd }
  AddOpcode($FF00, $6500, 'BCS', FMT_BRA, 2, GRP_BRANCH);
  { BNE : 0110 0110 dddd dddd }
  AddOpcode($FF00, $6600, 'BNE', FMT_BRA, 2, GRP_BRANCH);
  { BEQ : 0110 0111 dddd dddd }
  AddOpcode($FF00, $6700, 'BEQ', FMT_BRA, 2, GRP_BRANCH);
  { BVC : 0110 1000 dddd dddd }
  AddOpcode($FF00, $6800, 'BVC', FMT_BRA, 2, GRP_BRANCH);
  { BVS : 0110 1001 dddd dddd }
  AddOpcode($FF00, $6900, 'BVS', FMT_BRA, 2, GRP_BRANCH);
  { BPL : 0110 1010 dddd dddd }
  AddOpcode($FF00, $6A00, 'BPL', FMT_BRA, 2, GRP_BRANCH);
  { BMI : 0110 1011 dddd dddd }
  AddOpcode($FF00, $6B00, 'BMI', FMT_BRA, 2, GRP_BRANCH);
  { BGE : 0110 1100 dddd dddd }
  AddOpcode($FF00, $6C00, 'BGE', FMT_BRA, 2, GRP_BRANCH);
  { BLT : 0110 1101 dddd dddd }
  AddOpcode($FF00, $6D00, 'BLT', FMT_BRA, 2, GRP_BRANCH);
  { BGT : 0110 1110 dddd dddd }
  AddOpcode($FF00, $6E00, 'BGT', FMT_BRA, 2, GRP_BRANCH);
  { BLE : 0110 1111 dddd dddd }
  AddOpcode($FF00, $6F00, 'BLE', FMT_BRA, 2, GRP_BRANCH);

  { === DBcc - Decrement and Branch === }
  { DBcc Dn,d16 : 0101 cccc 1100 1xxx }

  { DBT : 0101 0000 1100 1xxx }
  AddOpcode($FFF8, $50C8, 'DBT', FMT_DBCC, 4, GRP_BRANCH);
  { DBF/DBRA : 0101 0001 1100 1xxx }
  AddOpcode($FFF8, $51C8, 'DBF', FMT_DBCC, 4, GRP_BRANCH);
  { DBHI : 0101 0010 1100 1xxx }
  AddOpcode($FFF8, $52C8, 'DBHI', FMT_DBCC, 4, GRP_BRANCH);
  { DBLS : 0101 0011 1100 1xxx }
  AddOpcode($FFF8, $53C8, 'DBLS', FMT_DBCC, 4, GRP_BRANCH);
  { DBCC : 0101 0100 1100 1xxx }
  AddOpcode($FFF8, $54C8, 'DBCC', FMT_DBCC, 4, GRP_BRANCH);
  { DBCS : 0101 0101 1100 1xxx }
  AddOpcode($FFF8, $55C8, 'DBCS', FMT_DBCC, 4, GRP_BRANCH);
  { DBNE : 0101 0110 1100 1xxx }
  AddOpcode($FFF8, $56C8, 'DBNE', FMT_DBCC, 4, GRP_BRANCH);
  { DBEQ : 0101 0111 1100 1xxx }
  AddOpcode($FFF8, $57C8, 'DBEQ', FMT_DBCC, 4, GRP_BRANCH);
  { DBVC : 0101 1000 1100 1xxx }
  AddOpcode($FFF8, $58C8, 'DBVC', FMT_DBCC, 4, GRP_BRANCH);
  { DBVS : 0101 1001 1100 1xxx }
  AddOpcode($FFF8, $59C8, 'DBVS', FMT_DBCC, 4, GRP_BRANCH);
  { DBPL : 0101 1010 1100 1xxx }
  AddOpcode($FFF8, $5AC8, 'DBPL', FMT_DBCC, 4, GRP_BRANCH);
  { DBMI : 0101 1011 1100 1xxx }
  AddOpcode($FFF8, $5BC8, 'DBMI', FMT_DBCC, 4, GRP_BRANCH);
  { DBGE : 0101 1100 1100 1xxx }
  AddOpcode($FFF8, $5CC8, 'DBGE', FMT_DBCC, 4, GRP_BRANCH);
  { DBLT : 0101 1101 1100 1xxx }
  AddOpcode($FFF8, $5DC8, 'DBLT', FMT_DBCC, 4, GRP_BRANCH);
  { DBGT : 0101 1110 1100 1xxx }
  AddOpcode($FFF8, $5EC8, 'DBGT', FMT_DBCC, 4, GRP_BRANCH);
  { DBLE : 0101 1111 1100 1xxx }
  AddOpcode($FFF8, $5FC8, 'DBLE', FMT_DBCC, 4, GRP_BRANCH);

  { === Scc - Set According to Condition === }
  { Scc ea : 0101 cccc 11xx xxxx }

  { ST : 0101 0000 11xx xxxx }
  AddOpcode($FFC0, $50C0, 'ST', FMT_SCC, 2, GRP_BRANCH);
  { SF : 0101 0001 11xx xxxx }
  AddOpcode($FFC0, $51C0, 'SF', FMT_SCC, 2, GRP_BRANCH);
  { SHI : 0101 0010 11xx xxxx }
  AddOpcode($FFC0, $52C0, 'SHI', FMT_SCC, 2, GRP_BRANCH);
  { SLS : 0101 0011 11xx xxxx }
  AddOpcode($FFC0, $53C0, 'SLS', FMT_SCC, 2, GRP_BRANCH);
  { SCC : 0101 0100 11xx xxxx }
  AddOpcode($FFC0, $54C0, 'SCC', FMT_SCC, 2, GRP_BRANCH);
  { SCS : 0101 0101 11xx xxxx }
  AddOpcode($FFC0, $55C0, 'SCS', FMT_SCC, 2, GRP_BRANCH);
  { SNE : 0101 0110 11xx xxxx }
  AddOpcode($FFC0, $56C0, 'SNE', FMT_SCC, 2, GRP_BRANCH);
  { SEQ : 0101 0111 11xx xxxx }
  AddOpcode($FFC0, $57C0, 'SEQ', FMT_SCC, 2, GRP_BRANCH);
  { SVC : 0101 1000 11xx xxxx }
  AddOpcode($FFC0, $58C0, 'SVC', FMT_SCC, 2, GRP_BRANCH);
  { SVS : 0101 1001 11xx xxxx }
  AddOpcode($FFC0, $59C0, 'SVS', FMT_SCC, 2, GRP_BRANCH);
  { SPL : 0101 1010 11xx xxxx }
  AddOpcode($FFC0, $5AC0, 'SPL', FMT_SCC, 2, GRP_BRANCH);
  { SMI : 0101 1011 11xx xxxx }
  AddOpcode($FFC0, $5BC0, 'SMI', FMT_SCC, 2, GRP_BRANCH);
  { SGE : 0101 1100 11xx xxxx }
  AddOpcode($FFC0, $5CC0, 'SGE', FMT_SCC, 2, GRP_BRANCH);
  { SLT : 0101 1101 11xx xxxx }
  AddOpcode($FFC0, $5DC0, 'SLT', FMT_SCC, 2, GRP_BRANCH);
  { SGT : 0101 1110 11xx xxxx }
  AddOpcode($FFC0, $5EC0, 'SGT', FMT_SCC, 2, GRP_BRANCH);
  { SLE : 0101 1111 11xx xxxx }
  AddOpcode($FFC0, $5FC0, 'SLE', FMT_SCC, 2, GRP_BRANCH);

  { === JMP / JSR === }

  { JMP ea : 0100 1110 11xx xxxx }
  AddOpcode($FFC0, $4EC0, 'JMP', FMT_EA2, 2, GRP_BRANCH);
  { JSR ea : 0100 1110 10xx xxxx }
  AddOpcode($FFC0, $4E80, 'JSR', FMT_EA2, 2, GRP_BRANCH);

  { === RTS / RTE / RTR === }

  { RTS : 0100 1110 0111 0101 = $4E75 }
  AddOpcode($FFFF, $4E75, 'RTS', FMT_NONE, 2, GRP_BRANCH);
  { RTE : 0100 1110 0111 0011 = $4E73 }
  AddOpcode($FFFF, $4E73, 'RTE', FMT_NONE, 2, GRP_BRANCH);
  { RTR : 0100 1110 0111 0111 = $4E77 }
  AddOpcode($FFFF, $4E77, 'RTR', FMT_NONE, 2, GRP_BRANCH);

  { === NOP / STOP / RESET / ILLEGAL === }

  { NOP : 0100 1110 0111 0001 = $4E71 }
  AddOpcode($FFFF, $4E71, 'NOP', FMT_NONE, 2, GRP_BRANCH);
  { STOP #imm16 : 0100 1110 0111 0010 = $4E72 }
  AddOpcode($FFFF, $4E72, 'STOP', FMT_IMM16, 4, GRP_BRANCH);
  { RESET : 0100 1110 0111 0000 = $4E70 }
  AddOpcode($FFFF, $4E70, 'RESET', FMT_NONE, 2, GRP_BRANCH);
  { ILLEGAL : 0100 1010 1111 1100 = $4AFC }
  AddOpcode($FFFF, $4AFC, 'ILLEGAL', FMT_NONE, 2, GRP_BRANCH);

  { === TRAP === }

  { TRAP #vector : 0100 1110 0100 vvvv = $4E40-$4E4F }
  AddOpcode($FFF0, $4E40, 'TRAP', FMT_TRAP, 2, GRP_BRANCH);
  { TRAPV : 0100 1110 0111 0110 = $4E76 }
  AddOpcode($FFFF, $4E76, 'TRAPV', FMT_NONE, 2, GRP_BRANCH);
End;

{ ============================================================
  TODO 12 - TABLE DES OPCODES 68000 - BITS ET DIVERS [IMPLEMENTE]
  ============================================================ }

{ --- InitBitMiscOpcodes : opcodes de manipulation de bits et divers --- }

Procedure InitBitMiscOpcodes;
Begin
  { === BTST/BCHG/BCLR/BSET - Registre === }
  { BTST Dn,ea : 0000 xxx1 00xx xxxx }
  AddOpcode($F1C0, $0100, 'BTST', FMT_BIT_DN, 2, GRP_BIT);
  { BCHG Dn,ea : 0000 xxx1 01xx xxxx }
  AddOpcode($F1C0, $0140, 'BCHG', FMT_BIT_DN, 2, GRP_BIT);
  { BCLR Dn,ea : 0000 xxx1 10xx xxxx }
  AddOpcode($F1C0, $0180, 'BCLR', FMT_BIT_DN, 2, GRP_BIT);
  { BSET Dn,ea : 0000 xxx1 11xx xxxx }
  AddOpcode($F1C0, $01C0, 'BSET', FMT_BIT_DN, 2, GRP_BIT);

  { === BTST/BCHG/BCLR/BSET - Immediat === }
  { BTST #imm,ea : 0000 1000 00xx xxxx }
  AddOpcode($FFC0, $0800, 'BTST', FMT_BIT_IMM, 4, GRP_BIT);
  { BCHG #imm,ea : 0000 1000 01xx xxxx }
  AddOpcode($FFC0, $0840, 'BCHG', FMT_BIT_IMM, 4, GRP_BIT);
  { BCLR #imm,ea : 0000 1000 10xx xxxx }
  AddOpcode($FFC0, $0880, 'BCLR', FMT_BIT_IMM, 4, GRP_BIT);
  { BSET #imm,ea : 0000 1000 11xx xxxx }
  AddOpcode($FFC0, $08C0, 'BSET', FMT_BIT_IMM, 4, GRP_BIT);

  { === MOVE to/from SR === }
  { MOVE ea,SR : 0100 0110 11xx xxxx }
  AddOpcode($FFC0, $46C0, 'MOVE', FMT_SR, 2, GRP_MISC);
  { MOVE SR,ea : 0100 0000 11xx xxxx }
  AddOpcode($FFC0, $40C0, 'MOVE', FMT_SR, 2, GRP_MISC);

  { === MOVE to/from CCR === }
  { MOVE ea,CCR : 0100 0100 11xx xxxx }
  AddOpcode($FFC0, $44C0, 'MOVE', FMT_CCR, 2, GRP_MISC);
  { MOVE CCR,ea : 0100 0010 11xx xxxx (68010+) }
  AddOpcode($FFC0, $42C0, 'MOVE', FMT_CCR, 2, GRP_MISC);

  { === MOVE USP === }
  { MOVE USP,An : 0100 1110 0110 1xxx = $4E68-$4E6F }
  AddOpcode($FFF8, $4E68, 'MOVE', FMT_USP, 2, GRP_MISC);
  { MOVE An,USP : 0100 1110 0110 0xxx = $4E60-$4E67 }
  AddOpcode($FFF8, $4E60, 'MOVE', FMT_USP, 2, GRP_MISC);

  { === ANDI/ORI/EORI to CCR === }
  { ANDI #imm,CCR : 0000 0010 0011 1100 = $023C }
  AddOpcode($FFFF, $023C, 'ANDI', FMT_IMM_CCR, 4, GRP_MISC);
  { ORI #imm,CCR : 0000 0000 0011 1100 = $003C }
  AddOpcode($FFFF, $003C, 'ORI', FMT_IMM_CCR, 4, GRP_MISC);
  { EORI #imm,CCR : 0000 1010 0011 1100 = $0A3C }
  AddOpcode($FFFF, $0A3C, 'EORI', FMT_IMM_CCR, 4, GRP_MISC);

  { === ANDI/ORI/EORI to SR === }
  { ANDI #imm,SR : 0000 0010 0111 1100 = $027C }
  AddOpcode($FFFF, $027C, 'ANDI', FMT_IMM_SR, 4, GRP_MISC);
  { ORI #imm,SR : 0000 0000 0111 1100 = $007C }
  AddOpcode($FFFF, $007C, 'ORI', FMT_IMM_SR, 4, GRP_MISC);
  { EORI #imm,SR : 0000 1010 0111 1100 = $0A7C }
  AddOpcode($FFFF, $0A7C, 'EORI', FMT_IMM_SR, 4, GRP_MISC);

  { === CHK === }
  { CHK ea,Dn : 0100 xxx1 10xx xxxx }
  AddOpcode($F1C0, $4180, 'CHK', FMT_CHK, 2, GRP_MISC);
End;

{ --- InitOpcodeTable : initialiser la table des opcodes --- }

Procedure InitOpcodeTable;
Begin
  OpcodeCount := 0;
  InitTransferOpcodes;
  InitArithLogicOpcodes;
  InitShiftRotateOpcodes;
  InitBranchControlOpcodes;
  InitBitMiscOpcodes;
  { Les groupes suivants seront ajoutes par les TODOs 13+ }
End;

{ --- FindOpcode : chercher un opcode par son mot d'instruction --- }

Function FindOpcode(InstrWord: Word): Integer;
Var
  I: Integer;
Begin
  FindOpcode := 0;
  For I := 1 To OpcodeCount Do Begin
    If (InstrWord And OpcodeTable[I].Mask) = OpcodeTable[I].Value Then Begin
      FindOpcode := I;
      Exit;
    End;
  End;
End;

{ --- GetOpcodeMnemonic : retourner le mnemonique d'un opcode --- }

Function GetOpcodeMnemonic(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= OpcodeCount) Then
    GetOpcodeMnemonic := OpcodeTable[Index].Mnemonic
  Else
    GetOpcodeMnemonic := '???';
End;

{ --- OpcodeGroupToStr : nom du groupe d'opcodes --- }

Function OpcodeGroupToStr(G: Byte): String;
Begin
  Case G Of
    GRP_TRANSFER : OpcodeGroupToStr := 'Transfert';
    GRP_ARITH    : OpcodeGroupToStr := 'Arithmetique';
    GRP_SHIFT    : OpcodeGroupToStr := 'Decalages';
    GRP_BRANCH   : OpcodeGroupToStr := 'Branchements';
    GRP_BIT      : OpcodeGroupToStr := 'Bits';
    GRP_MISC     : OpcodeGroupToStr := 'Divers';
  Else
    OpcodeGroupToStr := 'Inconnu';
  End;
End;

{ --- ShowOpcodeTable : afficher la table des opcodes --- }

Procedure ShowOpcodeTable(Show: Boolean);
Var
  I: Integer;
Begin
  If Not Show Then Exit;
  WriteLn;
  WriteLn('=== Table des opcodes 68000 (', IntToStr(OpcodeCount),
          ' entrees) ===');
  WriteLn('  #    Masque  Valeur  Taille  Groupe        Mnemonique');
  WriteLn('  ---- ------- ------- ------- ------------- ----------');
  For I := 1 To OpcodeCount Do Begin
    Write('  ');
    If I < 10 Then Write(' ');
    If I < 100 Then Write(' ');
    Write(IntToStr(I), '  ');
    Write(' $', HexWord(OpcodeTable[I].Mask));
    Write('  $', HexWord(OpcodeTable[I].Value));
    Write('  ', IntToStr(OpcodeTable[I].BaseSize));
    If OpcodeTable[I].BaseSize < 10 Then Write(' ');
    Write('      ');
    Write(OpcodeGroupToStr(OpcodeTable[I].Group));
    { Remplir jusqu'a 14 caracteres }
    Write('':14 - Length(OpcodeGroupToStr(OpcodeTable[I].Group)));
    WriteLn(OpcodeTable[I].Mnemonic);
  End;
End;

{ --- CountOpcodes : retourner le nombre total d'opcodes --- }

Function CountOpcodes: Integer;
Begin
  CountOpcodes := OpcodeCount;
End;

{ --- CountOpcodesByGroup : compter les opcodes d'un groupe --- }

Function CountOpcodesByGroup(G: Byte): Integer;
Var
  I, C: Integer;
Begin
  C := 0;
  For I := 1 To OpcodeCount Do
    If OpcodeTable[I].Group = G Then
      Inc(C);
  CountOpcodesByGroup := C;
End;

{ ============================================================
  TODO 13 - DECODAGE DES MODES D'ADRESSAGE 68000 [IMPLEMENTE]
  ============================================================ }

{ Constantes des modes d'adressage 68000 }
Const
  AM_DN        = 0;   { Dn          - registre de donnees direct       }
  AM_AN        = 1;   { An          - registre d'adresses direct       }
  AM_AN_IND    = 2;   { (An)        - registre d'adresses indirect     }
  AM_AN_POST   = 3;   { (An)+       - post-increment                   }
  AM_AN_PRE    = 4;   { -(An)       - pre-decrement                    }
  AM_AN_DISP   = 5;   { d16(An)     - deplacement 16 bits              }
  AM_AN_IDX    = 6;   { d8(An,Xn)   - indexe avec deplacement 8 bits   }
  AM_ABS_W     = 7;   { xxx.W       - adresse absolue courte (16 bits) }
  AM_ABS_L     = 8;   { xxx.L       - adresse absolue longue (32 bits) }
  AM_PC_DISP   = 9;   { d16(PC)     - relatif au PC avec deplacement   }
  AM_PC_IDX    = 10;  { d8(PC,Xn)   - relatif au PC indexe             }
  AM_IMM       = 11;  { #imm        - immediat                         }

{ --- SizeToStr : suffixe de taille (.B, .W, .L) --- }

Function SizeToStr(Size: Byte): String;
Begin
  Case Size Of
    0: SizeToStr := '.B';
    1: SizeToStr := '.W';
    2: SizeToStr := '.L';
  Else
    SizeToStr := '';
  End;
End;

{ --- SizeInBytes : nombre d'octets pour une taille --- }

Function SizeInBytes(Size: Byte): Byte;
Begin
  Case Size Of
    0: SizeInBytes := 1;  { byte }
    1: SizeInBytes := 2;  { word }
    2: SizeInBytes := 4;  { long }
  Else
    SizeInBytes := 2;
  End;
End;

{ --- SignExtByte : extension de signe d'un octet vers un LongInt --- }

Function SignExtByte(B: Byte): LongInt;
Begin
  If B >= $80 Then
    SignExtByte := LongInt(B) - 256
  Else
    SignExtByte := LongInt(B);
End;

{ --- SignExtWord : extension de signe d'un Word vers un LongInt --- }

Function SignExtWord(W: Word): LongInt;
Begin
  If W >= $8000 Then
    SignExtWord := LongInt(W) - 65536
  Else
    SignExtWord := LongInt(W);
End;

{ --- GetAddrModeKind : retourner le type de mode d'adressage --- }
{     Mode = bits 3-5, Reg = bits 0-2 du mot d'instruction        }

Function GetAddrModeKind(Mode, Reg: Byte): Byte;
Begin
  Case Mode Of
    0: GetAddrModeKind := AM_DN;
    1: GetAddrModeKind := AM_AN;
    2: GetAddrModeKind := AM_AN_IND;
    3: GetAddrModeKind := AM_AN_POST;
    4: GetAddrModeKind := AM_AN_PRE;
    5: GetAddrModeKind := AM_AN_DISP;
    6: GetAddrModeKind := AM_AN_IDX;
    7: Case Reg Of
         0: GetAddrModeKind := AM_ABS_W;
         1: GetAddrModeKind := AM_ABS_L;
         2: GetAddrModeKind := AM_PC_DISP;
         3: GetAddrModeKind := AM_PC_IDX;
         4: GetAddrModeKind := AM_IMM;
       Else
         GetAddrModeKind := 255;  { invalide }
       End;
  Else
    GetAddrModeKind := 255;  { invalide }
  End;
End;

{ --- AddrModeToStr : nom du mode d'adressage --- }

Function AddrModeToStr(Kind: Byte): String;
Begin
  Case Kind Of
    AM_DN:       AddrModeToStr := 'Dn';
    AM_AN:       AddrModeToStr := 'An';
    AM_AN_IND:   AddrModeToStr := '(An)';
    AM_AN_POST:  AddrModeToStr := '(An)+';
    AM_AN_PRE:   AddrModeToStr := '-(An)';
    AM_AN_DISP:  AddrModeToStr := 'd16(An)';
    AM_AN_IDX:   AddrModeToStr := 'd8(An,Xn)';
    AM_ABS_W:    AddrModeToStr := 'xxx.W';
    AM_ABS_L:    AddrModeToStr := 'xxx.L';
    AM_PC_DISP:  AddrModeToStr := 'd16(PC)';
    AM_PC_IDX:   AddrModeToStr := 'd8(PC,Xn)';
    AM_IMM:      AddrModeToStr := '#imm';
  Else
    AddrModeToStr := '???';
  End;
End;

{ --- ExtensionSize : taille des mots d'extension pour un mode --- }
{     OpSize : 0=byte, 1=word, 2=long (utilise pour #imm)          }

Function ExtensionSize(Kind, OpSize: Byte): Byte;
Begin
  Case Kind Of
    AM_DN:       ExtensionSize := 0;
    AM_AN:       ExtensionSize := 0;
    AM_AN_IND:   ExtensionSize := 0;
    AM_AN_POST:  ExtensionSize := 0;
    AM_AN_PRE:   ExtensionSize := 0;
    AM_AN_DISP:  ExtensionSize := 2;  { 1 mot d'extension : deplacement 16 bits }
    AM_AN_IDX:   ExtensionSize := 2;  { 1 mot d'extension : brief extension word }
    AM_ABS_W:    ExtensionSize := 2;  { 1 mot d'extension : adresse 16 bits }
    AM_ABS_L:    ExtensionSize := 4;  { 2 mots d'extension : adresse 32 bits }
    AM_PC_DISP:  ExtensionSize := 2;  { 1 mot d'extension : deplacement 16 bits }
    AM_PC_IDX:   ExtensionSize := 2;  { 1 mot d'extension : brief extension word }
    AM_IMM:      Begin                { immediat : taille depend de OpSize }
                   If OpSize = 2 Then
                     ExtensionSize := 4  { long = 2 mots }
                   Else
                     ExtensionSize := 2; { byte ou word = 1 mot }
                 End;
  Else
    ExtensionSize := 0;
  End;
End;

{ --- IsValidEA : verifier si un mode d'adressage est valide --- }

Function IsValidEA(Mode, Reg: Byte): Boolean;
Begin
  If Mode <= 6 Then
    IsValidEA := True
  Else If Mode = 7 Then
    IsValidEA := (Reg <= 4)
  Else
    IsValidEA := False;
End;

{ --- DecodeEA : decoder un operande effectif 68000 en texte --- }
{     Mode = bits 3-5, Reg = bits 0-2                            }
{     Ofs  = offset dans ImageBuffer (apres le mot d'instruction)}
{     OpSize = 0=byte, 1=word, 2=long (pour #imm)               }
{     PC   = adresse courante (pour modes PC-relatifs)           }
{     ExtBytes = retourne le nombre d'octets d'extension lus     }

Function DecodeEA(Mode, Reg: Byte; Ofs: LongInt; OpSize: Byte;
                  PC: LongInt; Var ExtBytes: Byte): String;
Var
  Kind      : Byte;
  Disp16    : LongInt;
  Disp8     : ShortInt;
  ExtWord   : Word;
  Addr32    : LongInt;
  ImmVal    : LongInt;
  IdxReg    : Byte;
  IdxIsAddr : Boolean;
  IdxSize   : Boolean;  { False = word, True = long }
  TargetAddr: LongInt;
  S         : String;
Begin
  ExtBytes := 0;
  Kind := GetAddrModeKind(Mode, Reg);

  Case Kind Of
    AM_DN: Begin
      DecodeEA := 'D' + IntToStr(Reg);
    End;

    AM_AN: Begin
      DecodeEA := 'A' + IntToStr(Reg);
    End;

    AM_AN_IND: Begin
      DecodeEA := '(A' + IntToStr(Reg) + ')';
    End;

    AM_AN_POST: Begin
      DecodeEA := '(A' + IntToStr(Reg) + ')+';
    End;

    AM_AN_PRE: Begin
      DecodeEA := '-(A' + IntToStr(Reg) + ')';
    End;

    AM_AN_DISP: Begin
      { Lire le deplacement 16 bits signe }
      ExtWord := ReadBEWordMem(Ofs);
      Disp16 := SignExtWord(ExtWord);
      ExtBytes := 2;
      If Disp16 >= 0 Then
        DecodeEA := IntToStr(Disp16) + '(A' + IntToStr(Reg) + ')'
      Else
        DecodeEA := '-' + IntToStr(-Disp16) + '(A' + IntToStr(Reg) + ')';
    End;

    AM_AN_IDX: Begin
      { Lire le mot d'extension (brief extension word) }
      ExtWord := ReadBEWordMem(Ofs);
      ExtBytes := 2;
      { Bit 15 : 0=Dn, 1=An }
      IdxIsAddr := (ExtWord And $8000) <> 0;
      { Bits 14-12 : numero du registre index }
      IdxReg := (ExtWord Shr 12) And 7;
      { Bit 11 : 0=word, 1=long }
      IdxSize := (ExtWord And $0800) <> 0;
      { Bits 7-0 : deplacement 8 bits signe }
      Disp8 := ShortInt(ExtWord And $FF);
      S := '';
      If Disp8 <> 0 Then Begin
        If Disp8 > 0 Then
          S := IntToStr(Disp8)
        Else
          S := '-' + IntToStr(-Integer(Disp8));
      End;
      S := S + '(A' + IntToStr(Reg) + ',';
      If IdxIsAddr Then
        S := S + 'A'
      Else
        S := S + 'D';
      S := S + IntToStr(IdxReg);
      If IdxSize Then
        S := S + '.L)'
      Else
        S := S + '.W)';
      DecodeEA := S;
    End;

    AM_ABS_W: Begin
      { Adresse absolue courte (16 bits, extension de signe a 32 bits) }
      ExtWord := ReadBEWordMem(Ofs);
      ExtBytes := 2;
      TargetAddr := SignExtWord(ExtWord);
      DecodeEA := '$' + HexLong(TargetAddr) + '.W';
    End;

    AM_ABS_L: Begin
      { Adresse absolue longue (32 bits) }
      Addr32 := ReadBELongMem(Ofs);
      ExtBytes := 4;
      DecodeEA := '$' + HexLong(Addr32);
    End;

    AM_PC_DISP: Begin
      { Relatif au PC avec deplacement 16 bits }
      ExtWord := ReadBEWordMem(Ofs);
      Disp16 := SignExtWord(ExtWord);
      ExtBytes := 2;
      TargetAddr := PC + 2 + LongInt(Disp16);
      DecodeEA := '$' + HexLong(TargetAddr) + '(PC)';
    End;

    AM_PC_IDX: Begin
      { Relatif au PC indexe (brief extension word) }
      ExtWord := ReadBEWordMem(Ofs);
      ExtBytes := 2;
      IdxIsAddr := (ExtWord And $8000) <> 0;
      IdxReg := (ExtWord Shr 12) And 7;
      IdxSize := (ExtWord And $0800) <> 0;
      Disp8 := ShortInt(ExtWord And $FF);
      TargetAddr := PC + 2 + LongInt(Disp8);
      S := '$' + HexLong(TargetAddr) + '(PC,';
      If IdxIsAddr Then
        S := S + 'A'
      Else
        S := S + 'D';
      S := S + IntToStr(IdxReg);
      If IdxSize Then
        S := S + '.L)'
      Else
        S := S + '.W)';
      DecodeEA := S;
    End;

    AM_IMM: Begin
      { Immediat : taille depend de OpSize }
      If OpSize = 2 Then Begin
        { Long : 4 octets }
        ImmVal := ReadBELongMem(Ofs);
        ExtBytes := 4;
        DecodeEA := '#$' + HexLong(ImmVal);
      End Else If OpSize = 0 Then Begin
        { Byte : 2 octets (poids fort ignore) }
        ExtWord := ReadBEWordMem(Ofs);
        ExtBytes := 2;
        DecodeEA := '#$' + HexByte(Byte(ExtWord And $FF));
      End Else Begin
        { Word : 2 octets }
        ExtWord := ReadBEWordMem(Ofs);
        ExtBytes := 2;
        DecodeEA := '#$' + HexWord(ExtWord);
      End;
    End;

  Else
    DecodeEA := '???';
  End;
End;

{ --- DecodeRegList : decoder un masque de registres MOVEM --- }
{     Mask = mot de 16 bits, Direction: 0 = reg-to-mem, 1 = mem-to-reg }

Function DecodeRegList(Mask: Word; Direction: Byte): String;
Var
  S    : String;
  I    : Integer;
  First: Boolean;
  Bit  : Integer;
  RunStart, RunEnd: Integer;

  Procedure AppendReg(RegNum: Integer);
  Begin
    If Not First Then
      S := S + '/';
    If RegNum < 8 Then
      S := S + 'D' + IntToStr(RegNum)
    Else
      S := S + 'A' + IntToStr(RegNum - 8);
    First := False;
  End;

  Procedure AppendRange(StartReg, EndReg: Integer);
  Begin
    If Not First Then
      S := S + '/';
    If StartReg < 8 Then
      S := S + 'D' + IntToStr(StartReg)
    Else
      S := S + 'A' + IntToStr(StartReg - 8);
    S := S + '-';
    If EndReg < 8 Then
      S := S + 'D' + IntToStr(EndReg)
    Else
      S := S + 'A' + IntToStr(EndReg - 8);
    First := False;
  End;

Begin
  S := '';
  First := True;
  I := 0;
  While I <= 15 Do Begin
    { Pour reg-to-mem (predecrement), les bits sont inverses :
      bit 0 = A7, bit 15 = D0
      Pour mem-to-reg (normal), bit 0 = D0, bit 15 = A7 }
    If Direction = 0 Then
      Bit := 15 - I   { predecrement : bit inverse }
    Else
      Bit := I;        { normal }
    If (Mask And (1 Shl Bit)) <> 0 Then Begin
      RunStart := I;
      RunEnd := I;
      While (RunEnd < 15) Do Begin
        If Direction = 0 Then
          Bit := 15 - (RunEnd + 1)
        Else
          Bit := RunEnd + 1;
        If (Mask And (1 Shl Bit)) <> 0 Then
          Inc(RunEnd)
        Else
          Break;
      End;
      If RunEnd > RunStart Then
        AppendRange(RunStart, RunEnd)
      Else
        AppendReg(RunStart);
      I := RunEnd + 1;
    End Else
      Inc(I);
  End;
  If S = '' Then
    S := '#$' + HexWord(Mask);
  DecodeRegList := S;
End;

{ --- ShowAddrModes : afficher les modes d'adressage supportes (verbose) --- }

Procedure ShowAddrModes(Verbose: Boolean);
Begin
  If Not Verbose Then Exit;
  WriteLn;
  WriteLn('=== Modes d''adressage 68000 (12 modes) ===');
  WriteLn('  000 Dn          : registre de donnees direct');
  WriteLn('  001 An          : registre d''adresses direct');
  WriteLn('  010 (An)        : registre d''adresses indirect');
  WriteLn('  011 (An)+       : post-increment');
  WriteLn('  100 -(An)       : pre-decrement');
  WriteLn('  101 d16(An)     : deplacement 16 bits');
  WriteLn('  110 d8(An,Xn)   : indexe (deplacement 8 bits)');
  WriteLn('  111/000 xxx.W   : adresse absolue courte');
  WriteLn('  111/001 xxx.L   : adresse absolue longue');
  WriteLn('  111/010 d16(PC) : relatif au PC');
  WriteLn('  111/011 d8(PC,Xn) : relatif au PC indexe');
  WriteLn('  111/100 #imm    : immediat');
End;

{ --- CountAddrModes : retourner le nombre de modes supportes --- }

Function CountAddrModes: Integer;
Begin
  CountAddrModes := 12;  { AM_DN..AM_IMM }
End;

{ ============================================================
  TODO 14 - DECODAGE D'UNE INSTRUCTION COMPLETE [IMPLEMENTE]
  ============================================================ }

{ --- CondCodeToStr : convertir un code condition 68000 en chaine --- }

Function CondCodeToStr(CC: Byte): String;
Begin
  Case CC Of
    0:  CondCodeToStr := 'T';    { True (always)    }
    1:  CondCodeToStr := 'F';    { False (never)    }
    2:  CondCodeToStr := 'HI';   { HIgher           }
    3:  CondCodeToStr := 'LS';   { Lower or Same    }
    4:  CondCodeToStr := 'CC';   { Carry Clear      }
    5:  CondCodeToStr := 'CS';   { Carry Set        }
    6:  CondCodeToStr := 'NE';   { Not Equal        }
    7:  CondCodeToStr := 'EQ';   { EQual            }
    8:  CondCodeToStr := 'VC';   { oVerflow Clear   }
    9:  CondCodeToStr := 'VS';   { oVerflow Set     }
    10: CondCodeToStr := 'PL';   { PLus             }
    11: CondCodeToStr := 'MI';   { MInus            }
    12: CondCodeToStr := 'GE';   { Greater or Equal }
    13: CondCodeToStr := 'LT';   { Less Than        }
    14: CondCodeToStr := 'GT';   { Greater Than     }
    15: CondCodeToStr := 'LE';   { Less or Equal    }
  Else
    CondCodeToStr := '??';
  End;
End;

{ --- MnemonicSize : retourner le mnemonique avec le suffixe de taille --- }

Function MnemonicSize(Mnem: String; Size: Byte): String;
Begin
  MnemonicSize := Mnem + SizeToStr(Size);
End;

{ --- DecodeInstruction : decoder une instruction complete 68000 --- }
{     Ofs = offset dans ImageBuffer (relatif a TextOffset)          }
{     PC  = adresse logique de l'instruction (pour Bcc/PC-relatif)  }

Procedure DecodeInstruction(Ofs: LongInt; PC: LongInt;
                            Var Info: TInstructionInfo);
Var
  OpWord     : Word;
  Idx        : Integer;
  Fmt        : Byte;
  OpSize     : Byte;
  SrcMode    : Byte;
  SrcReg     : Byte;
  DstMode    : Byte;
  DstReg     : Byte;
  Reg9       : Byte;
  ExtB       : Byte;
  ExtB2      : Byte;
  TotalExt   : Byte;
  Disp8      : LongInt;
  Disp16     : LongInt;
  ImmW       : Word;
  ImmL       : LongInt;
  ImmVal     : LongInt;
  CC         : Byte;
  VecNum     : Byte;
  RegMask    : Word;
  Direction  : Byte;
  BitNum     : Byte;
  SrcStr     : String;
  DstStr     : String;
  Mnem       : String;
  TargetAddr : LongInt;
Begin
  Info.Offset    := Ofs;
  Info.Operands  := '';
  Info.TotalSize := 2;
  Info.OpcIdx    := 0;
  Info.IsValid   := False;
  Info.Mnemonic  := '';

  { Lire le mot d'instruction }
  If Ofs + 1 >= ImageSize Then Begin
    Info.Mnemonic := 'DC.W';
    Info.IsValid  := False;
    Exit;
  End;
  OpWord := ReadBEWordMem(Ofs);
  Info.OpWord := OpWord;

  { Chercher dans la table des opcodes }
  Idx := FindOpcode(OpWord);
  If Idx = 0 Then Begin
    Info.Mnemonic  := 'DC.W';
    Info.Operands  := '$' + HexWord(OpWord);
    Info.TotalSize := 2;
    Exit;
  End;

  Info.OpcIdx  := Idx;
  Info.IsValid := True;
  Fmt  := OpcodeTable[Idx].OpFormat;
  Mnem := OpcodeTable[Idx].Mnemonic;
  TotalExt := 0;

  { Extraire les champs courants du mot d'instruction }
  SrcMode := (OpWord Shr 3) And 7;
  SrcReg  := OpWord And 7;
  Reg9    := (OpWord Shr 9) And 7;

  Case Fmt Of

    { --- FMT_NONE : pas d'operande (NOP, RTS, RTE, RTR, RESET, ILLEGAL) --- }
    FMT_NONE: Begin
      Info.Mnemonic := Mnem;
    End;

    { --- FMT_EA_EA : MOVE ea,ea --- }
    FMT_EA_EA: Begin
      { Taille : bits 13-12 : 01=B, 11=W, 10=L }
      Case (OpWord Shr 12) And 3 Of
        1: OpSize := 0; { byte }
        3: OpSize := 1; { word }
        2: OpSize := 2; { long }
      Else
        OpSize := 1;
      End;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Source : mode=bits 5-3, reg=bits 2-0 }
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      { Destination : mode=bits 8-6, reg=bits 11-9 }
      DstMode := (OpWord Shr 6) And 7;
      DstReg  := Reg9;
      DstStr := DecodeEA(DstMode, DstReg, Ofs + 2 + TotalExt, OpSize,
                          PC, ExtB2);
      TotalExt := TotalExt + ExtB2;
      Info.Operands := SrcStr + ',' + DstStr;
    End;

    { --- FMT_EA_AN : MOVEA ea,An --- }
    FMT_EA_AN: Begin
      { Taille : bit 12 : 0=W, 1=L (dans le mot d'opcode) }
      If (OpWord And $1000) <> 0 Then
        OpSize := 1  { word }
      Else
        OpSize := 2; { long }
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',A' + IntToStr(Reg9);
    End;

    { --- FMT_IMM8_DN : MOVEQ #imm8,Dn --- }
    FMT_IMM8_DN: Begin
      Info.Mnemonic := Mnem;
      Disp8 := SignExtByte(Byte(OpWord And $FF));
      Info.Operands := '#' + IntToStr(Disp8) + ',D' + IntToStr(Reg9);
    End;

    { --- FMT_REGLIST : MOVEM reglist,ea / ea,reglist --- }
    FMT_REGLIST: Begin
      { Taille : bit 6 : 0=W, 1=L }
      If (OpWord And $0040) <> 0 Then
        OpSize := 2  { long }
      Else
        OpSize := 1; { word }
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Direction : bit 10 : 0 = reg-to-mem, 1 = mem-to-reg }
      Direction := (OpWord Shr 10) And 1;
      { Masque de registres = mot suivant }
      RegMask := ReadBEWordMem(Ofs + 2);
      TotalExt := 2;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 4, OpSize, PC, ExtB);
      TotalExt := TotalExt + ExtB;
      If Direction = 0 Then
        { reg-to-mem : reglist,ea }
        Info.Operands := DecodeRegList(RegMask, Direction) + ',' + SrcStr
      Else
        { mem-to-reg : ea,reglist }
        Info.Operands := SrcStr + ',' + DecodeRegList(RegMask, Direction);
    End;

    { --- FMT_DN_AN : MOVEP Dn,d16(An) / d16(An),Dn --- }
    FMT_DN_AN: Begin
      { Taille : bit 6 : 0=W, 1=L }
      If (OpWord And $0040) <> 0 Then
        OpSize := 2
      Else
        OpSize := 1;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
      TotalExt := 2;
      { Direction : bit 7 : 0 = mem-to-reg, 1 = reg-to-mem }
      If (OpWord And $0080) <> 0 Then Begin
        { reg-to-mem : Dn,d16(An) }
        If Disp16 >= 0 Then
          Info.Operands := 'D' + IntToStr(Reg9) + ',' +
                           IntToStr(Disp16) + '(A' + IntToStr(SrcReg) + ')'
        Else
          Info.Operands := 'D' + IntToStr(Reg9) + ',-' +
                           IntToStr(-Disp16) + '(A' + IntToStr(SrcReg) + ')';
      End Else Begin
        { mem-to-reg : d16(An),Dn }
        If Disp16 >= 0 Then
          Info.Operands := IntToStr(Disp16) + '(A' + IntToStr(SrcReg) +
                           ')' + ',D' + IntToStr(Reg9)
        Else
          Info.Operands := '-' + IntToStr(-Disp16) + '(A' +
                           IntToStr(SrcReg) + ')' + ',D' + IntToStr(Reg9);
      End;
    End;

    { --- FMT_DN_DN : EXG Dn,Dn / An,An / Dn,An --- }
    FMT_DN_DN: Begin
      Info.Mnemonic := Mnem;
      Case (OpWord Shr 3) And $1F Of
        $08: { Dn,Dn }
          Info.Operands := 'D' + IntToStr(Reg9) + ',D' + IntToStr(SrcReg);
        $09: { An,An }
          Info.Operands := 'A' + IntToStr(Reg9) + ',A' + IntToStr(SrcReg);
        $11: { Dn,An }
          Info.Operands := 'D' + IntToStr(Reg9) + ',A' + IntToStr(SrcReg);
      Else
        Info.Operands := '???';
      End;
    End;

    { --- FMT_DN : SWAP Dn --- }
    FMT_DN: Begin
      Info.Mnemonic := Mnem;
      Info.Operands := 'D' + IntToStr(SrcReg);
    End;

    { --- FMT_EA_AN2 : LEA ea,An --- }
    FMT_EA_AN2: Begin
      Info.Mnemonic := Mnem;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 2, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',A' + IntToStr(Reg9);
    End;

    { --- FMT_EA : PEA ea / CLR ea / TST ea / TAS ea --- }
    FMT_EA: Begin
      { Verifier si le mnemonique contient un suffixe de taille }
      OpSize := 1; { defaut word }
      If Pos('.B', Mnem) > 0 Then OpSize := 0
      Else If Pos('.L', Mnem) > 0 Then OpSize := 2
      Else If Pos('.W', Mnem) > 0 Then OpSize := 1;
      Info.Mnemonic := Mnem;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr;
    End;

    { --- FMT_AN_DISP : LINK An,#disp --- }
    FMT_AN_DISP: Begin
      Info.Mnemonic := Mnem;
      Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
      TotalExt := 2;
      Info.Operands := 'A' + IntToStr(SrcReg) + ',#' + IntToStr(Disp16);
    End;

    { --- FMT_AN : UNLK An --- }
    FMT_AN: Begin
      Info.Mnemonic := Mnem;
      Info.Operands := 'A' + IntToStr(SrcReg);
    End;

    { --- FMT_EA_DN : ADD ea,Dn / SUB ea,Dn / AND ea,Dn / OR ea,Dn --- }
    { ---             CMP ea,Dn                                        --- }
    FMT_EA_DN: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',D' + IntToStr(Reg9);
    End;

    { --- FMT_DN_EA : ADD Dn,ea / SUB Dn,ea / AND Dn,ea / OR Dn,ea --- }
    { ---             EOR Dn,ea                                       --- }
    FMT_DN_EA: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := 'D' + IntToStr(Reg9) + ',' + DstStr;
    End;

    { --- FMT_EA_AN3 : ADDA ea,An / SUBA ea,An / CMPA ea,An --- }
    FMT_EA_AN3: Begin
      { Taille : bit 8 : 0=W, 1=L }
      If (OpWord And $0100) <> 0 Then
        OpSize := 2
      Else
        OpSize := 1;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',A' + IntToStr(Reg9);
    End;

    { --- FMT_IMM_EA : ADDI #imm,ea / SUBI / ANDI / ORI / EORI / CMPI --- }
    FMT_IMM_EA: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Lire l'immediat }
      If OpSize = 2 Then Begin
        ImmL := ReadBELongMem(Ofs + 2);
        TotalExt := 4;
        SrcStr := '#$' + HexLong(ImmL);
      End Else If OpSize = 0 Then Begin
        ImmW := ReadBEWordMem(Ofs + 2);
        TotalExt := 2;
        SrcStr := '#$' + HexByte(Byte(ImmW And $FF));
      End Else Begin
        ImmW := ReadBEWordMem(Ofs + 2);
        TotalExt := 2;
        SrcStr := '#$' + HexWord(ImmW);
      End;
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2 + TotalExt, OpSize,
                          PC, ExtB);
      TotalExt := TotalExt + ExtB;
      Info.Operands := SrcStr + ',' + DstStr;
    End;

    { --- FMT_IMM3_EA : ADDQ #1-8,ea / SUBQ #1-8,ea --- }
    FMT_IMM3_EA: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Immediat 3 bits : bits 11-9, 0 signifie 8 }
      ImmVal := Reg9;
      If ImmVal = 0 Then ImmVal := 8;
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := '#' + IntToStr(ImmVal) + ',' + DstStr;
    End;

    { --- FMT_DN_DN2 : ADDX Dn,Dn / SUBX Dn,Dn / CMPM (An)+,(An)+ --- }
    FMT_DN_DN2: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Verifier si c'est CMPM (mode (An)+) ou ADDX/SUBX (Dn ou -(An)) }
      If Pos('CMPM', Mnem) > 0 Then
        Info.Operands := '(A' + IntToStr(SrcReg) + ')+,(A' +
                          IntToStr(Reg9) + ')+'
      Else If (OpWord And $0008) <> 0 Then
        { Mode -(An) }
        Info.Operands := '-(A' + IntToStr(SrcReg) + '),-(A' +
                          IntToStr(Reg9) + ')'
      Else
        Info.Operands := 'D' + IntToStr(SrcReg) + ',D' + IntToStr(Reg9);
    End;

    { --- FMT_WORD_DN : MULU ea,Dn / MULS ea,Dn / DIVU / DIVS --- }
    FMT_WORD_DN: Begin
      OpSize := 1;  { toujours word }
      Info.Mnemonic := Mnem;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',D' + IntToStr(Reg9);
    End;

    { --- FMT_DN2 : NOT / NEG / NEGX / EXT --- }
    FMT_DN2: Begin
      { Verifier si le mnemonique contient deja un suffixe }
      OpSize := 1;
      If Pos('.B', Mnem) > 0 Then OpSize := 0
      Else If Pos('.L', Mnem) > 0 Then OpSize := 2
      Else If Pos('.W', Mnem) > 0 Then OpSize := 1;
      Info.Mnemonic := Mnem;
      Info.Operands := 'D' + IntToStr(SrcReg);
    End;

    { --- FMT_SH_REG : ASL/ASR/LSL/LSR/ROL/ROR Dn,Dn (register count) --- }
    FMT_SH_REG: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      Info.Operands := 'D' + IntToStr(Reg9) + ',D' + IntToStr(SrcReg);
    End;

    { --- FMT_SH_IMM : ASL/ASR/LSL/LSR/ROL/ROR #imm3,Dn --- }
    FMT_SH_IMM: Begin
      { Taille : bits 7-6 : 00=B, 01=W, 10=L }
      OpSize := (OpWord Shr 6) And 3;
      Info.Mnemonic := MnemonicSize(Mnem, OpSize);
      { Immediat 3 bits : bits 11-9, 0 signifie 8 }
      ImmVal := Reg9;
      If ImmVal = 0 Then ImmVal := 8;
      Info.Operands := '#' + IntToStr(ImmVal) + ',D' + IntToStr(SrcReg);
    End;

    { --- FMT_SH_MEM : ASL/ASR/LSL/LSR/ROL/ROR ea (1 bit, word) --- }
    FMT_SH_MEM: Begin
      OpSize := 1;  { toujours word pour les decalages memoire }
      Info.Mnemonic := Mnem;
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := DstStr;
    End;

    { --- FMT_BRA : BRA/BSR/Bcc d8/d16 --- }
    FMT_BRA: Begin
      Disp8 := SignExtByte(Byte(OpWord And $FF));
      { Extraire le code condition (bits 11-8) }
      CC := (OpWord Shr 8) And $0F;
      If Disp8 = 0 Then Begin
        { Deplacement 16 bits dans le mot suivant }
        Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
        TotalExt := 2;
        TargetAddr := PC + 2 + Disp16;
      End Else Begin
        { Deplacement 8 bits dans le mot d'instruction }
        TargetAddr := PC + 2 + Disp8;
      End;
      { Construire le mnemonique avec le code condition }
      If CC = 0 Then
        Info.Mnemonic := 'BRA'
      Else If CC = 1 Then
        Info.Mnemonic := 'BSR'
      Else
        Info.Mnemonic := 'B' + CondCodeToStr(CC);
      If Disp8 = 0 Then
        Info.Mnemonic := Info.Mnemonic + '.W'
      Else
        Info.Mnemonic := Info.Mnemonic + '.S';
      Info.Operands := '$' + HexLong(TargetAddr);
    End;

    { --- FMT_DBCC : DBcc Dn,d16 --- }
    FMT_DBCC: Begin
      CC := (OpWord Shr 8) And $0F;
      Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
      TotalExt := 2;
      TargetAddr := PC + 2 + Disp16;
      If CC = 0 Then
        Info.Mnemonic := 'DBT'
      Else If CC = 1 Then
        Info.Mnemonic := 'DBRA'
      Else
        Info.Mnemonic := 'DB' + CondCodeToStr(CC);
      Info.Operands := 'D' + IntToStr(SrcReg) + ',$' +
                        HexLong(TargetAddr);
    End;

    { --- FMT_SCC : Scc ea --- }
    FMT_SCC: Begin
      CC := (OpWord Shr 8) And $0F;
      If CC = 0 Then
        Info.Mnemonic := 'ST'
      Else If CC = 1 Then
        Info.Mnemonic := 'SF'
      Else
        Info.Mnemonic := 'S' + CondCodeToStr(CC);
      OpSize := 0;  { byte }
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, OpSize, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := DstStr;
    End;

    { --- FMT_EA2 : JMP ea / JSR ea --- }
    FMT_EA2: Begin
      Info.Mnemonic := Mnem;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 2, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr;
    End;

    { --- FMT_IMM16 : STOP #imm16 --- }
    FMT_IMM16: Begin
      Info.Mnemonic := Mnem;
      ImmW := ReadBEWordMem(Ofs + 2);
      TotalExt := 2;
      Info.Operands := '#$' + HexWord(ImmW);
    End;

    { --- FMT_TRAP : TRAP #vector (0-15) --- }
    FMT_TRAP: Begin
      Info.Mnemonic := Mnem;
      VecNum := OpWord And $000F;
      Info.Operands := '#' + IntToStr(VecNum);
    End;

    { --- FMT_BIT_DN : BTST/BSET/BCLR/BCHG Dn,ea --- }
    FMT_BIT_DN: Begin
      Info.Mnemonic := Mnem;
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 0, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := 'D' + IntToStr(Reg9) + ',' + DstStr;
    End;

    { --- FMT_BIT_IMM : BTST/BSET/BCLR/BCHG #imm,ea --- }
    FMT_BIT_IMM: Begin
      Info.Mnemonic := Mnem;
      ImmW := ReadBEWordMem(Ofs + 2);
      BitNum := Byte(ImmW And $FF);
      TotalExt := 2;
      DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 4, 0, PC, ExtB);
      TotalExt := TotalExt + ExtB;
      Info.Operands := '#' + IntToStr(BitNum) + ',' + DstStr;
    End;

    { --- FMT_SR : MOVE ea,SR / MOVE SR,ea --- }
    FMT_SR: Begin
      Info.Mnemonic := Mnem;
      If (OpWord And $0400) <> 0 Then Begin
        { MOVE ea,SR }
        SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 1, PC, ExtB);
        TotalExt := ExtB;
        Info.Operands := SrcStr + ',SR';
      End Else Begin
        { MOVE SR,ea }
        DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 1, PC, ExtB);
        TotalExt := ExtB;
        Info.Operands := 'SR,' + DstStr;
      End;
    End;

    { --- FMT_CCR : MOVE ea,CCR / MOVE CCR,ea --- }
    FMT_CCR: Begin
      Info.Mnemonic := Mnem;
      If (OpWord And $0400) <> 0 Then Begin
        { MOVE ea,CCR }
        SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 1, PC, ExtB);
        TotalExt := ExtB;
        Info.Operands := SrcStr + ',CCR';
      End Else Begin
        { MOVE CCR,ea }
        DstStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 1, PC, ExtB);
        TotalExt := ExtB;
        Info.Operands := 'CCR,' + DstStr;
      End;
    End;

    { --- FMT_USP : MOVE USP,An / MOVE An,USP --- }
    FMT_USP: Begin
      Info.Mnemonic := Mnem;
      If (OpWord And $0008) <> 0 Then
        { MOVE USP,An }
        Info.Operands := 'USP,A' + IntToStr(SrcReg)
      Else
        { MOVE An,USP }
        Info.Operands := 'A' + IntToStr(SrcReg) + ',USP';
    End;

    { --- FMT_IMM_SR : ANDI/ORI/EORI #imm,SR --- }
    FMT_IMM_SR: Begin
      Info.Mnemonic := Mnem;
      ImmW := ReadBEWordMem(Ofs + 2);
      TotalExt := 2;
      Info.Operands := '#$' + HexWord(ImmW) + ',SR';
    End;

    { --- FMT_IMM_CCR : ANDI/ORI/EORI #imm,CCR --- }
    FMT_IMM_CCR: Begin
      Info.Mnemonic := Mnem;
      ImmW := ReadBEWordMem(Ofs + 2);
      TotalExt := 2;
      Info.Operands := '#$' + HexByte(Byte(ImmW And $FF)) + ',CCR';
    End;

    { --- FMT_CHK : CHK ea,Dn --- }
    FMT_CHK: Begin
      Info.Mnemonic := Mnem;
      SrcStr := DecodeEA(SrcMode, SrcReg, Ofs + 2, 1, PC, ExtB);
      TotalExt := ExtB;
      Info.Operands := SrcStr + ',D' + IntToStr(Reg9);
    End;

  Else
    { Format inconnu }
    Info.Mnemonic  := 'DC.W';
    Info.Operands  := '$' + HexWord(OpWord);
    Info.IsValid   := False;
  End;

  Info.TotalSize := 2 + TotalExt;
End;

{ --- FormatInstruction : formater une instruction pour l'affichage --- }

Function FormatInstruction(Var Info: TInstructionInfo): String;
Var
  S: String;
Begin
  S := '$' + HexLong(Info.Offset) + '  ';
  S := S + Info.Mnemonic;
  { Padding pour aligner les operandes }
  While Length(S) < 28 Do
    S := S + ' ';
  If Info.Operands <> '' Then
    S := S + Info.Operands;
  FormatInstruction := S;
End;

{ --- ShowInstruction : afficher une instruction decodee --- }

Procedure ShowInstruction(Var Info: TInstructionInfo; HexDump: Boolean);
Var
  S      : String;
  I      : Integer;
  HexStr : String;
Begin
  S := FormatInstruction(Info);
  If HexDump Then Begin
    { Ajouter les octets hexa en commentaire }
    HexStr := '';
    For I := 0 To Info.TotalSize - 1 Do Begin
      If I > 0 Then HexStr := HexStr + ' ';
      If Info.Offset + I < ImageSize Then
        HexStr := HexStr + HexByte(Byte(PChar(ImageBuffer)[Info.Offset + I]))
      Else
        HexStr := HexStr + '??';
    End;
    While Length(S) < 52 Do
      S := S + ' ';
    S := S + ' ; ' + HexStr;
  End;
  WriteLn(S);
End;

{ --- GetInstrSize : retourner la taille d'une instruction --- }

Function GetInstrSize(Var Info: TInstructionInfo): Byte;
Begin
  GetInstrSize := Info.TotalSize;
End;

{ --- IsControlFlow : est-ce une instruction de controle de flux ? --- }

Function IsControlFlow(Var Info: TInstructionInfo): Boolean;
Var
  M: String;
Begin
  IsControlFlow := False;
  If Not Info.IsValid Then Exit;
  M := Info.Mnemonic;
  If (Pos('BRA', M) = 1) Or (Pos('BSR', M) = 1) Or
     (Pos('B', M) = 1) Or (Pos('DB', M) = 1) Or
     (M = 'JMP') Or (M = 'JSR') Or
     (M = 'RTS') Or (M = 'RTE') Or (M = 'RTR') Then
    IsControlFlow := True;
End;

{ --- IsBranch : est-ce un branchement (pas un appel) ? --- }

Function IsBranch(Var Info: TInstructionInfo): Boolean;
Var
  M: String;
Begin
  IsBranch := False;
  If Not Info.IsValid Then Exit;
  M := Info.Mnemonic;
  If (Pos('BRA', M) = 1) Or (M = 'JMP') Or
     (Pos('DB', M) = 1) Then
    IsBranch := True
  Else If (Pos('B', M) = 1) And (Pos('BSR', M) <> 1) And
          (Pos('BTST', M) <> 1) And (Pos('BSET', M) <> 1) And
          (Pos('BCLR', M) <> 1) And (Pos('BCHG', M) <> 1) Then
    IsBranch := True;
End;

{ --- IsCall : est-ce un appel de sous-programme ? --- }

Function IsCall(Var Info: TInstructionInfo): Boolean;
Var
  M: String;
Begin
  IsCall := False;
  If Not Info.IsValid Then Exit;
  M := Info.Mnemonic;
  If (Pos('BSR', M) = 1) Or (M = 'JSR') Then
    IsCall := True;
End;

{ --- CountInstructions : compter les instructions dans la section TEXT --- }

Function CountInstructions(TextLen: LongInt): LongInt;
Var
  Ofs   : LongInt;
  Count : LongInt;
  Inf   : TInstructionInfo;
Begin
  Count := 0;
  Ofs := TextOffset;
  While Ofs < TextOffset + TextLen Do Begin
    DecodeInstruction(Ofs, Ofs - TextOffset, Inf);
    Inc(Count);
    If Inf.TotalSize < 2 Then
      Ofs := Ofs + 2
    Else
      Ofs := Ofs + Inf.TotalSize;
  End;
  CountInstructions := Count;
End;

{ ============================================================
  TODO 15 - PREMIERE PASSE : ANALYSE DU FLUX DE CONTROLE [IMPLEMENTE]
  ============================================================ }

{ --- FindLabelByAddr : chercher un label par adresse et section --- }
{     Retourne l'index (1..LabelCount) ou 0 si non trouve           }

Function FindLabelByAddr(Addr: LongInt; Sec: Byte): Integer;
Var
  I: Integer;
Begin
  FindLabelByAddr := 0;
  For I := 1 To LabelCount Do Begin
    If (Labels[I].Address = Addr) And (Labels[I].Section = Sec) Then Begin
      FindLabelByAddr := I;
      Exit;
    End;
  End;
End;

{ --- AddLabel : ajouter un label s'il n'existe pas deja --- }
{     Si le label existe, met a jour IsProc si necessaire    }

Procedure AddLabel(Addr: LongInt; AName: String;
                   AIsProc, AIsData: Boolean; Sec: Byte);
Var
  Idx: Integer;
Begin
  Idx := FindLabelByAddr(Addr, Sec);
  If Idx > 0 Then Begin
    { Le label existe deja, mettre a jour IsProc si necessaire }
    If AIsProc Then Labels[Idx].IsProc := True;
    { Mettre a jour le nom si c'est un sub_ et qu'on avait loc_ }
    If AIsProc And (Pos('loc_', Labels[Idx].Name) = 1) Then
      Labels[Idx].Name := AName;
    Exit;
  End;
  If LongInt(LabelCount) >= LongInt(MAX_LABELS) Then Exit;
  Inc(LabelCount);
  Labels[LabelCount].Address := Addr;
  Labels[LabelCount].Name    := AName;
  Labels[LabelCount].IsProc  := AIsProc;
  Labels[LabelCount].IsData  := AIsData;
  Labels[LabelCount].Section := Sec;
End;

{ --- AddXRef : ajouter une reference croisee --- }

Procedure AddXRef(FromAddr, ToAddr: LongInt; AIsCall: Boolean);
Begin
  If LongInt(XRefCount) >= LongInt(MAX_XREFS) Then Exit;
  Inc(XRefCount);
  XRefs[XRefCount].FromAddr := FromAddr;
  XRefs[XRefCount].ToAddr   := ToAddr;
  XRefs[XRefCount].IsCall   := AIsCall;
End;

{ --- IsReturn : est-ce une instruction de retour (RTS/RTE/RTR) ? --- }

Function IsReturn(Var Info: TInstructionInfo): Boolean;
Begin
  IsReturn := False;
  If Not Info.IsValid Then Exit;
  If (Info.Mnemonic = 'RTS') Or (Info.Mnemonic = 'RTE') Or
     (Info.Mnemonic = 'RTR') Then
    IsReturn := True;
End;

{ --- IsUnconditionalJump : est-ce un saut inconditionnel ? --- }
{     BRA ou JMP (interrompt le flux lineaire)                  }

Function IsUnconditionalJump(Var Info: TInstructionInfo): Boolean;
Begin
  IsUnconditionalJump := False;
  If Not Info.IsValid Then Exit;
  If (Pos('BRA', Info.Mnemonic) = 1) Or (Info.Mnemonic = 'JMP') Then
    IsUnconditionalJump := True;
End;

{ --- GetBranchTarget : extraire l'adresse cible d'un branchement --- }
{     Retourne l'adresse cible (PC logique), ou -1 si non             }
{     determinable statiquement (mode indirect registre, etc.)        }

Function GetBranchTarget(Ofs: LongInt; PC: LongInt;
                          Var Info: TInstructionInfo): LongInt;
Var
  OpW      : Word;
  Disp8    : LongInt;
  Disp16   : LongInt;
  Fmt      : Byte;
  SMode    : Byte;
  SReg     : Byte;
Begin
  GetBranchTarget := -1;
  If Not Info.IsValid Then Exit;
  If Info.OpcIdx = 0 Then Exit;
  OpW := Info.OpWord;
  Fmt := OpcodeTable[Info.OpcIdx].OpFormat;
  Case Fmt Of
    FMT_BRA: Begin
      { BRA/BSR/Bcc : deplacement 8 ou 16 bits relatif a PC+2 }
      Disp8 := SignExtByte(Byte(OpW And $FF));
      If Disp8 = 0 Then Begin
        { Deplacement 16 bits dans le mot suivant }
        Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
        GetBranchTarget := PC + 2 + Disp16;
      End Else
        GetBranchTarget := PC + 2 + Disp8;
    End;
    FMT_DBCC: Begin
      { DBcc Dn,d16 : deplacement 16 bits relatif a PC+2 }
      Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
      GetBranchTarget := PC + 2 + Disp16;
    End;
    FMT_EA2: Begin
      { JMP/JSR ea : seulement si mode adresse absolue ou PC-relatif }
      SMode := (OpW Shr 3) And 7;
      SReg  := OpW And 7;
      If (SMode = 7) And (SReg = 0) Then Begin
        { Adresse absolue courte 16 bits (sign-extended) }
        GetBranchTarget := SignExtWord(ReadBEWordMem(Ofs + 2));
      End
      Else If (SMode = 7) And (SReg = 1) Then Begin
        { Adresse absolue longue 32 bits }
        GetBranchTarget := ReadBELongMem(Ofs + 2);
      End
      Else If (SMode = 7) And (SReg = 2) Then Begin
        { PC-relatif d16(PC) }
        Disp16 := SignExtWord(ReadBEWordMem(Ofs + 2));
        GetBranchTarget := PC + 2 + Disp16;
      End;
      { Modes (An), d16(An), d8(An,Xn) : cible non determinable }
    End;
  End; { Case }
End;

{ --- IsCodeAddr : verifier si une adresse est dans la section TEXT --- }

Function IsCodeAddr(Addr: LongInt; TextLen: LongInt): Boolean;
Begin
  IsCodeAddr := (Addr >= 0) And (Addr < TextLen);
End;

{ --- FirstPass : premiere passe d'analyse du flux de controle --- }
{     Parcourt lineairement la section TEXT, collecte les cibles   }
{     de branchement (labels) et les references croisees.          }
{     Pour chaque BRA/Bcc/BSR/JMP/JSR, calcule l'adresse cible    }
{     et l'ajoute a la table des labels.                           }
{     Pour chaque RTS/RTE/RTR, marque la fin d'un bloc de code.    }

Procedure FirstPass(TextLen: LongInt);
Var
  Ofs      : LongInt;
  PC       : LongInt;
  Inf      : TInstructionInfo;
  Target   : LongInt;
  LblName  : String;
  IsCallI  : Boolean;
Begin
  If TextLen <= 0 Then Exit;
  { Ajouter le point d'entree comme premier label }
  AddLabel(0, 'start', True, False, 0);
  { Parcourir lineairement la section TEXT instruction par instruction }
  Ofs := TextOffset;
  While Ofs < TextOffset + TextLen Do Begin
    PC := Ofs - TextOffset;
    DecodeInstruction(Ofs, PC, Inf);
    { Verifier si c'est un branchement ou un appel }
    If Inf.IsValid And (IsBranch(Inf) Or IsCall(Inf)) Then Begin
      Target := GetBranchTarget(Ofs, PC, Inf);
      IsCallI := IsCall(Inf);
      If (Target >= 0) And IsCodeAddr(Target, TextLen) Then Begin
        { Generer le nom du label }
        If IsCallI Then
          LblName := 'sub_' + HexLong(Target)
        Else
          LblName := 'loc_' + HexLong(Target);
        { Ajouter le label cible }
        AddLabel(Target, LblName, IsCallI, False, 0);
        { Ajouter la reference croisee }
        AddXRef(PC, Target, IsCallI);
      End;
    End;
    { Avancer a l'instruction suivante }
    If Inf.TotalSize < 2 Then
      Ofs := Ofs + 2
    Else
      Ofs := Ofs + Inf.TotalSize;
  End;
End;

{ --- ShowFirstPassResults : afficher les resultats de la premiere passe --- }

Procedure ShowFirstPassResults(Verbose: Boolean);
Var
  I: Integer;
  CallCnt: LongInt;
  BranchCnt: LongInt;
  TextLblCnt: LongInt;
  ProcCnt: LongInt;
Begin
  If Not Verbose Then Exit;
  WriteLn;
  WriteLn('=== Premiere passe : analyse du flux de controle ===');
  WriteLn;
  { Compter les appels et branchements }
  CallCnt := 0;
  BranchCnt := 0;
  For I := 1 To XRefCount Do Begin
    If XRefs[I].IsCall Then
      Inc(CallCnt)
    Else
      Inc(BranchCnt);
  End;
  { Compter les labels TEXT et les sous-programmes }
  TextLblCnt := 0;
  ProcCnt := 0;
  For I := 1 To LabelCount Do Begin
    If Labels[I].Section = 0 Then Begin
      Inc(TextLblCnt);
      If Labels[I].IsProc Then
        Inc(ProcCnt);
    End;
  End;
  WriteLn('Labels TEXT         : ', IntToStr(TextLblCnt));
  WriteLn('Sous-programmes     : ', IntToStr(ProcCnt));
  WriteLn('Labels total        : ', IntToStr(LabelCount));
  WriteLn('References croisees : ', IntToStr(XRefCount));
  WriteLn('  Appels (BSR/JSR)  : ', IntToStr(CallCnt));
  WriteLn('  Branchements      : ', IntToStr(BranchCnt));
  { Afficher les labels de la section TEXT }
  If TextLblCnt > 0 Then Begin
    WriteLn;
    WriteLn('--- Labels de la section TEXT ---');
    WriteLn('  Adresse     Nom              Type');
    WriteLn('  ----------  ---------------  -----------');
    For I := 1 To LabelCount Do Begin
      If Labels[I].Section = 0 Then Begin
        Write('  $', HexLong(Labels[I].Address));
        Write('  ', Labels[I].Name);
        If Length(Labels[I].Name) < 15 Then
          Write('' : 15 - Length(Labels[I].Name));
        If Labels[I].IsProc Then
          WriteLn('  sous-programme')
        Else
          WriteLn('  cible de saut');
      End;
    End;
  End;
  { Afficher les references croisees }
  If XRefCount > 0 Then Begin
    WriteLn;
    WriteLn('--- References croisees ---');
    WriteLn('  Source      Type     Cible');
    WriteLn('  ----------  -------  ----------');
    For I := 1 To XRefCount Do Begin
      Write('  $', HexLong(XRefs[I].FromAddr));
      If XRefs[I].IsCall Then
        Write('  appel    ')
      Else
        Write('  saut     ');
      WriteLn('$', HexLong(XRefs[I].ToAddr));
    End;
  End;
End;

{ --- CountXRefs : compter les references croisees --- }

Function CountXRefs: LongInt;
Begin
  CountXRefs := XRefCount;
End;

{ --- CountCallXRefs : compter les appels (BSR/JSR) --- }

Function CountCallXRefs: LongInt;
Var
  I: Integer;
  Count: LongInt;
Begin
  Count := 0;
  For I := 1 To XRefCount Do
    If XRefs[I].IsCall Then Inc(Count);
  CountCallXRefs := Count;
End;

{ --- CountBranchXRefs : compter les branchements (BRA/Bcc/DBcc/JMP) --- }

Function CountBranchXRefs: LongInt;
Var
  I: Integer;
  Count: LongInt;
Begin
  Count := 0;
  For I := 1 To XRefCount Do
    If Not XRefs[I].IsCall Then Inc(Count);
  CountBranchXRefs := Count;
End;

{ ============================================================
  TODO 16 - DETECTION DES SOUS-PROGRAMMES [IMPLEMENTE]
  ============================================================ }

{ --- IsLinkA6 : est-ce une instruction LINK A6,#disp ? --- }
{     LINK A6 = $4E56 (opcode $4E50 | registre A6 = 6)      }

Function IsLinkA6(Ofs: LongInt): Boolean;
Begin
  IsLinkA6 := False;
  If Ofs + 3 >= ImageSize Then Exit;
  IsLinkA6 := (ReadBEWordMem(Ofs) = $4E56);
End;

{ --- IsUnlkA6 : est-ce une instruction UNLK A6 ? --- }
{     UNLK A6 = $4E5E (opcode $4E58 | registre A6 = 6) }

Function IsUnlkA6(Ofs: LongInt): Boolean;
Begin
  IsUnlkA6 := False;
  If Ofs + 1 >= ImageSize Then Exit;
  IsUnlkA6 := (ReadBEWordMem(Ofs) = $4E5E);
End;

{ --- IsMovemPush : est-ce MOVEM.L reglist,-(SP) ? --- }
{     MOVEM.L reglist,-(A7) = $48E7                     }

Function IsMovemPush(Ofs: LongInt): Boolean;
Begin
  IsMovemPush := False;
  If Ofs + 3 >= ImageSize Then Exit;
  IsMovemPush := (ReadBEWordMem(Ofs) = $48E7);
End;

{ --- IsMovemPop : est-ce MOVEM.L (SP)+,reglist ? --- }
{     MOVEM.L (A7)+,reglist = $4CDF                    }

Function IsMovemPop(Ofs: LongInt): Boolean;
Begin
  IsMovemPop := False;
  If Ofs + 3 >= ImageSize Then Exit;
  IsMovemPop := (ReadBEWordMem(Ofs) = $4CDF);
End;

{ --- IsRtsAt : est-ce une instruction RTS ($4E75) ? --- }

Function IsRtsAt(Ofs: LongInt): Boolean;
Begin
  IsRtsAt := False;
  If Ofs + 1 >= ImageSize Then Exit;
  IsRtsAt := (ReadBEWordMem(Ofs) = $4E75);
End;

{ --- GetLinkDisp : obtenir le deplacement LINK A6,#disp --- }

Function GetLinkDisp(Ofs: LongInt): LongInt;
Begin
  GetLinkDisp := SignExtWord(ReadBEWordMem(Ofs + 2));
End;

{ --- RegMaskToStr : convertir un masque de registres en texte --- }
{     Si Reversed=True (push -(SP)) : bit 15=D0, bit 0=A7        }
{     Si Reversed=False (pop (SP)+) : bit 0=D0, bit 15=A7        }

Function RegMaskToStr(Mask: Word; Reversed: Boolean): String;
Var
  S: String;
  Reg: Integer;
  BitPos: Integer;
Begin
  S := '';
  For Reg := 0 To 15 Do Begin
    If Reversed Then
      BitPos := 15 - Reg
    Else
      BitPos := Reg;
    If ((Mask Shr BitPos) And 1) <> 0 Then Begin
      If S <> '' Then S := S + '/';
      If Reg < 8 Then
        S := S + 'D' + Chr(Ord('0') + Reg)
      Else
        S := S + 'A' + Chr(Ord('0') + (Reg - 8));
    End;
  End;
  RegMaskToStr := S;
End;

{ --- HasStdPrologue : est-ce un prologue standard ? --- }
{     LINK A6,#-nn et/ou MOVEM.L reglist,-(SP)          }

Function HasStdPrologue(Addr: LongInt): Boolean;
Var
  Ofs: LongInt;
Begin
  Ofs := TextOffset + Addr;
  HasStdPrologue := IsLinkA6(Ofs) Or IsMovemPush(Ofs);
End;

{ --- HasStdEpilogue : a-t-il un epilogue standard ? --- }
{     Scanne depuis Addr jusqu'au premier RTS et verifie }
{     UNLK A6 et/ou MOVEM.L (SP)+,reglist avant le RTS  }

Function HasStdEpilogue(Addr: LongInt; TextLen: LongInt): Boolean;
Var
  Ofs: LongInt;
  Inf: TInstructionInfo;
  PC: LongInt;
  Limit: LongInt;
Begin
  HasStdEpilogue := False;
  Ofs := TextOffset + Addr;
  Limit := TextOffset + TextLen;
  If Ofs + 2048 < Limit Then
    Limit := Ofs + 2048;
  While Ofs < Limit Do Begin
    PC := Ofs - TextOffset;
    If IsRtsAt(Ofs) Then Begin
      { Verifier UNLK A6 juste avant RTS }
      If (Ofs >= TextOffset + 2) And IsUnlkA6(Ofs - 2) Then Begin
        HasStdEpilogue := True;
        Exit;
      End;
      { Verifier MOVEM.L (SP)+,reglist juste avant RTS }
      If (Ofs >= TextOffset + 4) And IsMovemPop(Ofs - 4) Then Begin
        HasStdEpilogue := True;
        Exit;
      End;
      Exit; { Premier RTS trouve, arreter }
    End;
    DecodeInstruction(Ofs, PC, Inf);
    If Inf.TotalSize < 2 Then
      Ofs := Ofs + 2
    Else
      Ofs := Ofs + Inf.TotalSize;
  End;
End;

{ --- DetectSubroutines : detecter les sous-programmes --- }
{     Parcourt les labels et identifie les sous-programmes }
{     par les cibles BSR/JSR et les prologues standards.   }
{     Les labels avec prologue mais sans IsProc sont        }
{     promus en sous-programmes (sub_XXXXXXXX).            }

Procedure DetectSubroutines(TextLen: LongInt);
Var
  I: Integer;
Begin
  SubCount := 0;
  For I := 1 To LabelCount Do Begin
    If (Labels[I].Section = 0) And Labels[I].IsProc Then Begin
      Inc(SubCount);
    End Else If (Labels[I].Section = 0) And (Not Labels[I].IsProc)
              And HasStdPrologue(Labels[I].Address) Then Begin
      { Ce label n'etait pas marque comme sous-programme mais a }
      { un prologue standard : le promouvoir en sous-programme  }
      Labels[I].IsProc := True;
      If Pos('loc_', Labels[I].Name) = 1 Then
        Labels[I].Name := 'sub_' + HexLong(Labels[I].Address);
      Inc(SubCount);
    End;
  End;
End;

{ --- ShowSubroutines : afficher les sous-programmes detectes --- }

Procedure ShowSubroutines(Verbose: Boolean);
Var
  I: Integer;
  Ofs: LongInt;
  Disp: LongInt;
  RegMask: Word;
  ProStr: String;
  EpiStr: String;
Begin
  If Not Verbose Then Exit;
  WriteLn;
  WriteLn('=== Detection des sous-programmes ===');
  WriteLn;
  WriteLn('Sous-programmes detectes : ', IntToStr(SubCount));
  If SubCount = 0 Then Exit;
  WriteLn;
  WriteLn('  Adresse     Nom              Prologue             Epilogue');
  WriteLn('  ----------  ---------------  -------------------  --------');
  For I := 1 To LabelCount Do Begin
    If (Labels[I].Section = 0) And Labels[I].IsProc Then Begin
      Ofs := TextOffset + Labels[I].Address;
      { Analyser le prologue }
      ProStr := '';
      If IsLinkA6(Ofs) Then Begin
        Disp := GetLinkDisp(Ofs);
        ProStr := 'LINK A6,#' + IntToStr(Disp);
        If IsMovemPush(Ofs + 4) Then Begin
          RegMask := ReadBEWordMem(Ofs + 6);
          ProStr := ProStr + '+MOVEM';
        End;
      End Else If IsMovemPush(Ofs) Then Begin
        RegMask := ReadBEWordMem(Ofs + 2);
        ProStr := 'MOVEM ' + RegMaskToStr(RegMask, True);
      End;
      If ProStr = '' Then
        ProStr := '(aucun)';
      { Analyser l'epilogue }
      If HasStdEpilogue(Labels[I].Address, Header.ph_tlen) Then
        EpiStr := 'oui'
      Else
        EpiStr := '(aucun)';
      { Afficher la ligne }
      Write('  $', HexLong(Labels[I].Address));
      Write('  ', Labels[I].Name);
      If Length(Labels[I].Name) < 15 Then
        Write('' : 15 - Length(Labels[I].Name));
      Write('  ', ProStr);
      If Length(ProStr) < 19 Then
        Write('' : 19 - Length(ProStr));
      WriteLn('  ', EpiStr);
    End;
  End;
End;

{ --- CountSubroutines : compter les sous-programmes --- }

Function CountSubroutines: LongInt;
Begin
  CountSubroutines := SubCount;
End;

{ --- IsSubroutine : verifier si une adresse est un sous-programme --- }

Function IsSubroutine(Addr: LongInt): Boolean;
Var
  Idx: Integer;
Begin
  IsSubroutine := False;
  Idx := FindLabelByAddr(Addr, 0);
  If Idx > 0 Then
    IsSubroutine := Labels[Idx].IsProc;
End;

{ ============================================================
  TODO 17 - DETECTION DES APPELS SYSTEME TOS [IMPLEMENTE]
  ============================================================ }

{ --- IsTrapGemdos : est-ce un TRAP #1 (GEMDOS) ? --- }
{     TRAP #1 = $4E41                                  }

Function IsTrapGemdos(Ofs: LongInt): Boolean;
Begin
  IsTrapGemdos := False;
  If Ofs + 1 < ImageSize Then
    If ReadBEWordMem(Ofs) = $4E41 Then
      IsTrapGemdos := True;
End;

{ --- IsTrapBios : est-ce un TRAP #13 (BIOS) ? --- }
{     TRAP #13 = $4E4D                               }

Function IsTrapBios(Ofs: LongInt): Boolean;
Begin
  IsTrapBios := False;
  If Ofs + 1 < ImageSize Then
    If ReadBEWordMem(Ofs) = $4E4D Then
      IsTrapBios := True;
End;

{ --- IsTrapXbios : est-ce un TRAP #14 (XBIOS) ? --- }
{     TRAP #14 = $4E4E                                 }

Function IsTrapXbios(Ofs: LongInt): Boolean;
Begin
  IsTrapXbios := False;
  If Ofs + 1 < ImageSize Then
    If ReadBEWordMem(Ofs) = $4E4E Then
      IsTrapXbios := True;
End;

{ --- IsTrapGem : est-ce un TRAP #2 (GEM AES/VDI) ? --- }
{     TRAP #2 = $4E42                                     }

Function IsTrapGem(Ofs: LongInt): Boolean;
Begin
  IsTrapGem := False;
  If Ofs + 1 < ImageSize Then
    If ReadBEWordMem(Ofs) = $4E42 Then
      IsTrapGem := True;
End;

{ --- GetTrapFuncNum : lire le numero de fonction empile --- }
{     Cherche un MOVE.W #nn,-(SP) juste avant le TRAP       }
{     MOVE.W #imm,-(SP) = $3F3C suivi du mot immediat       }

Function GetTrapFuncNum(TrapOfs: LongInt): Integer;
Var
  PrevOfs: LongInt;
  PrevW  : Word;
Begin
  GetTrapFuncNum := -1;
  PrevOfs := TrapOfs - 4;
  If PrevOfs >= TextOffset Then Begin
    PrevW := ReadBEWordMem(PrevOfs);
    If PrevW = $3F3C Then
      GetTrapFuncNum := ReadBEWordMem(PrevOfs + 2);
  End;
End;

{ --- GemdosFuncName : nom d'une fonction GEMDOS --- }

Function GemdosFuncName(FuncNum: Integer): String;
Begin
  Case FuncNum Of
    $00: GemdosFuncName := 'Pterm0';
    $01: GemdosFuncName := 'Cconin';
    $02: GemdosFuncName := 'Cconout';
    $03: GemdosFuncName := 'Cauxin';
    $04: GemdosFuncName := 'Cauxout';
    $05: GemdosFuncName := 'Cprnout';
    $06: GemdosFuncName := 'Crawio';
    $07: GemdosFuncName := 'Crawcin';
    $08: GemdosFuncName := 'Cnecin';
    $09: GemdosFuncName := 'Cconws';
    $0A: GemdosFuncName := 'Cconrs';
    $0B: GemdosFuncName := 'Cconis';
    $0E: GemdosFuncName := 'Dsetdrv';
    $10: GemdosFuncName := 'Cconos';
    $11: GemdosFuncName := 'Cprnos';
    $12: GemdosFuncName := 'Cauxis';
    $13: GemdosFuncName := 'Cauxos';
    $19: GemdosFuncName := 'Dgetdrv';
    $1A: GemdosFuncName := 'Fsetdta';
    $20: GemdosFuncName := 'Super';
    $2A: GemdosFuncName := 'Tgetdate';
    $2B: GemdosFuncName := 'Tsetdate';
    $2C: GemdosFuncName := 'Tgettime';
    $2D: GemdosFuncName := 'Tsettime';
    $2F: GemdosFuncName := 'Fgetdta';
    $30: GemdosFuncName := 'Sversion';
    $31: GemdosFuncName := 'Ptermres';
    $36: GemdosFuncName := 'Dfree';
    $39: GemdosFuncName := 'Dcreate';
    $3A: GemdosFuncName := 'Ddelete';
    $3B: GemdosFuncName := 'Dsetpath';
    $3C: GemdosFuncName := 'Fcreate';
    $3D: GemdosFuncName := 'Fopen';
    $3E: GemdosFuncName := 'Fclose';
    $3F: GemdosFuncName := 'Fread';
    $40: GemdosFuncName := 'Fwrite';
    $41: GemdosFuncName := 'Fdelete';
    $42: GemdosFuncName := 'Fseek';
    $43: GemdosFuncName := 'Fattrib';
    $44: GemdosFuncName := 'Mxalloc';
    $45: GemdosFuncName := 'Fdup';
    $46: GemdosFuncName := 'Fforce';
    $47: GemdosFuncName := 'Dgetpath';
    $48: GemdosFuncName := 'Malloc';
    $49: GemdosFuncName := 'Mfree';
    $4A: GemdosFuncName := 'Mshrink';
    $4B: GemdosFuncName := 'Pexec';
    $4C: GemdosFuncName := 'Pterm';
    $4E: GemdosFuncName := 'Fsfirst';
    $4F: GemdosFuncName := 'Fsnext';
    $56: GemdosFuncName := 'Frename';
    $57: GemdosFuncName := 'Fdatime';
  Else
    GemdosFuncName := 'GEMDOS_$' + HexWord(FuncNum);
  End;
End;

{ --- BiosFuncName : nom d'une fonction BIOS --- }

Function BiosFuncName(FuncNum: Integer): String;
Begin
  Case FuncNum Of
    $00: BiosFuncName := 'Getmpb';
    $01: BiosFuncName := 'Bconstat';
    $02: BiosFuncName := 'Bconin';
    $03: BiosFuncName := 'Bconout';
    $04: BiosFuncName := 'Rwabs';
    $05: BiosFuncName := 'Setexc';
    $06: BiosFuncName := 'Tickcal';
    $07: BiosFuncName := 'Getbpb';
    $08: BiosFuncName := 'Bcostat';
    $09: BiosFuncName := 'Mediach';
    $0A: BiosFuncName := 'Drvmap';
    $0B: BiosFuncName := 'Kbshift';
  Else
    BiosFuncName := 'BIOS_$' + HexWord(FuncNum);
  End;
End;

{ --- XbiosFuncName : nom d'une fonction XBIOS --- }

Function XbiosFuncName(FuncNum: Integer): String;
Begin
  Case FuncNum Of
    $00: XbiosFuncName := 'Initmous';
    $01: XbiosFuncName := 'Ssbrk';
    $02: XbiosFuncName := 'Physbase';
    $03: XbiosFuncName := 'Logbase';
    $04: XbiosFuncName := 'Getrez';
    $05: XbiosFuncName := 'Setscreen';
    $06: XbiosFuncName := 'Setpalette';
    $07: XbiosFuncName := 'Setcolor';
    $08: XbiosFuncName := 'Floprd';
    $09: XbiosFuncName := 'Flopwr';
    $0A: XbiosFuncName := 'Flopfmt';
    $0B: XbiosFuncName := 'Dbmsg';
    $0C: XbiosFuncName := 'Midiws';
    $0D: XbiosFuncName := 'Mfpint';
    $0E: XbiosFuncName := 'Iorec';
    $0F: XbiosFuncName := 'Rsconf';
    $10: XbiosFuncName := 'Keytbl';
    $11: XbiosFuncName := 'Random';
    $12: XbiosFuncName := 'Protobt';
    $13: XbiosFuncName := 'Flopver';
    $14: XbiosFuncName := 'Scrdmp';
    $15: XbiosFuncName := 'Cursconf';
    $16: XbiosFuncName := 'Settime';
    $17: XbiosFuncName := 'Gettime';
    $18: XbiosFuncName := 'Bioskeys';
    $19: XbiosFuncName := 'Ikbdws';
    $1A: XbiosFuncName := 'Jdisint';
    $1B: XbiosFuncName := 'Jenabint';
    $1C: XbiosFuncName := 'Giaccess';
    $1D: XbiosFuncName := 'Offgibit';
    $1E: XbiosFuncName := 'Ongibit';
    $1F: XbiosFuncName := 'Xbtimer';
    $20: XbiosFuncName := 'Dosound';
    $21: XbiosFuncName := 'Setprt';
    $22: XbiosFuncName := 'Kbdvbase';
    $23: XbiosFuncName := 'Kbrate';
    $24: XbiosFuncName := 'Prtblk';
    $25: XbiosFuncName := 'Vsync';
    $26: XbiosFuncName := 'Supexec';
    $27: XbiosFuncName := 'Puntaes';
  Else
    XbiosFuncName := 'XBIOS_$' + HexWord(FuncNum);
  End;
End;

{ --- GetTrapComment : generer un commentaire pour un TRAP --- }

Function GetTrapComment(Ofs: LongInt): String;
Var
  FuncNum: Integer;
  TrapW  : Word;
  VecNum : Integer;
Begin
  GetTrapComment := '';
  If Ofs + 1 >= ImageSize Then Exit;
  TrapW := ReadBEWordMem(Ofs);
  If (TrapW And $FFF0) <> $4E40 Then Exit;
  VecNum := TrapW And $000F;
  FuncNum := GetTrapFuncNum(Ofs);
  Case VecNum Of
    1: Begin { GEMDOS }
      If FuncNum >= 0 Then
        GetTrapComment := '; GEMDOS ' + GemdosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
      Else
        GetTrapComment := '; GEMDOS (fonction inconnue)';
    End;
    2: Begin { GEM AES/VDI }
      GetTrapComment := '; GEM AES/VDI';
    End;
    13: Begin { BIOS }
      If FuncNum >= 0 Then
        GetTrapComment := '; BIOS ' + BiosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
      Else
        GetTrapComment := '; BIOS (fonction inconnue)';
    End;
    14: Begin { XBIOS }
      If FuncNum >= 0 Then
        GetTrapComment := '; XBIOS ' + XbiosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
      Else
        GetTrapComment := '; XBIOS (fonction inconnue)';
    End;
  Else
    GetTrapComment := '; TRAP #' + IntToStr(VecNum);
  End;
End;

{ --- DetectTrapCalls : scanner TEXT pour les appels TRAP --- }

Procedure DetectTrapCalls(TextLen: LongInt);
Var
  Ofs : LongInt;
  W   : Word;
  Vec : Integer;
Begin
  TrapCount := 0;
  Ofs := TextOffset;
  While Ofs + 1 < TextOffset + TextLen Do Begin
    W := ReadBEWordMem(Ofs);
    If (W And $FFF0) = $4E40 Then Begin
      Vec := W And $000F;
      If (Vec = 1) Or (Vec = 2) Or (Vec = 13) Or (Vec = 14) Then
        TrapCount := TrapCount + 1;
    End;
    Ofs := Ofs + 2;
  End;
End;

{ --- ShowTrapCalls : afficher les appels systeme TOS detectes --- }

Procedure ShowTrapCalls(Verbose: Boolean);
Var
  Ofs     : LongInt;
  W       : Word;
  Vec     : Integer;
  FuncNum : Integer;
  FuncName: String;
  TrapType: String;
  Cnt     : LongInt;
Begin
  If Not Verbose Then Exit;
  If TrapCount = 0 Then Exit;
  WriteLn;
  WriteLn('=== Appels systeme TOS (', IntToStr(TrapCount), ' appels) ===');
  WriteLn;
  WriteLn('  Adresse    TRAP         Fonction');
  WriteLn('  --------   ----------   --------------------------------');
  Cnt := 0;
  Ofs := TextOffset;
  While Ofs + 1 < ImageSize Do Begin
    W := ReadBEWordMem(Ofs);
    If (W And $FFF0) = $4E40 Then Begin
      Vec := W And $000F;
      If (Vec = 1) Or (Vec = 2) Or (Vec = 13) Or (Vec = 14) Then Begin
        Cnt := Cnt + 1;
        FuncNum := GetTrapFuncNum(Ofs);
        Case Vec Of
          1: Begin
            TrapType := 'TRAP #1  ';
            If FuncNum >= 0 Then
              FuncName := 'GEMDOS ' + GemdosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
            Else
              FuncName := 'GEMDOS (inconnu)';
          End;
          2: Begin
            TrapType := 'TRAP #2  ';
            FuncName := 'GEM AES/VDI';
          End;
          13: Begin
            TrapType := 'TRAP #13 ';
            If FuncNum >= 0 Then
              FuncName := 'BIOS ' + BiosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
            Else
              FuncName := 'BIOS (inconnu)';
          End;
          14: Begin
            TrapType := 'TRAP #14 ';
            If FuncNum >= 0 Then
              FuncName := 'XBIOS ' + XbiosFuncName(FuncNum) +
                          ' ($' + HexWord(FuncNum) + ')'
            Else
              FuncName := 'XBIOS (inconnu)';
          End;
        Else
          TrapType := 'TRAP #' + IntToStr(Vec);
          FuncName := '';
        End;
        Write('  $', HexLong(Ofs - TextOffset));
        Write('   ', TrapType);
        WriteLn('   ', FuncName);
      End;
    End;
    Ofs := Ofs + 2;
  End;
End;

{ --- CountTrapCalls : nombre d'appels systeme detectes --- }

Function CountTrapCalls: LongInt;
Begin
  CountTrapCalls := TrapCount;
End;

{ --- IsTrapCall : verifier si une adresse est un appel systeme --- }

Function IsTrapCall(Ofs: LongInt): Boolean;
Var
  W  : Word;
  Vec: Integer;
Begin
  IsTrapCall := False;
  If Ofs + 1 >= ImageSize Then Exit;
  W := ReadBEWordMem(Ofs);
  If (W And $FFF0) = $4E40 Then Begin
    Vec := W And $000F;
    If (Vec = 1) Or (Vec = 2) Or (Vec = 13) Or (Vec = 14) Then
      IsTrapCall := True;
  End;
End;

{ ============================================================
  TODO 18 - DISCRIMINATION CODE/DONNEES DANS TEXT [IMPLEMENTE]
  ============================================================ }

{ --- AllocCodeMap : allouer la carte code/donnees --- }
{     Un octet par octet de la section TEXT             }

Procedure AllocCodeMap(TextLen: LongInt);
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  P: PByteArray;
  I: LongInt;
Begin
  If TextLen <= 0 Then Begin
    CodeMap := Nil;
    CodeMapSize := 0;
    Exit;
  End;
  CodeMapSize := TextLen;
  GetMem(CodeMap, CodeMapSize);
  If CodeMap = Nil Then
    FatalError('AllocCodeMap: memoire insuffisante');
  { Initialiser tout a CM_UNKNOWN }
  P := PByteArray(CodeMap);
  For I := 0 To CodeMapSize - 1 Do
    P^[I] := CM_UNKNOWN;
End;

{ --- FreeCodeMap : liberer la carte code/donnees --- }

Procedure FreeCodeMap;
Begin
  If CodeMap <> Nil Then Begin
    FreeMem(CodeMap, CodeMapSize);
    CodeMap := Nil;
    CodeMapSize := 0;
  End;
End;

{ --- GetCodeMapByte : lire la classification d'un octet --- }

Function GetCodeMapByte(TextOfs: LongInt): Byte;
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Begin
  GetCodeMapByte := CM_UNKNOWN;
  If CodeMap = Nil Then Exit;
  If (TextOfs < 0) Or (TextOfs >= CodeMapSize) Then Exit;
  GetCodeMapByte := PByteArray(CodeMap)^[TextOfs];
End;

{ --- MarkRegion : marquer une plage dans la carte --- }

Procedure MarkRegion(StartOfs, Len: LongInt; MarkType: Byte);
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  P: PByteArray;
  I: LongInt;
Begin
  If CodeMap = Nil Then Exit;
  P := PByteArray(CodeMap);
  For I := StartOfs To StartOfs + Len - 1 Do Begin
    If (I >= 0) And (I < CodeMapSize) Then
      P^[I] := MarkType;
  End;
End;

{ --- IsASCIIPrintable : est-ce un caractere ASCII imprimable ? --- }
{     Accepte 32..126 (espace a tilde) et les codes 9 (tab),       }
{     10 (LF), 13 (CR).                                             }

Function IsASCIIPrintable(B: Byte): Boolean;
Begin
  IsASCIIPrintable := ((B >= 32) And (B <= 126)) Or
                      (B = 9) Or (B = 10) Or (B = 13);
End;

{ --- DetectASCIIStringAt : detecter une chaine ASCII terminee par 0 --- }
{     TextOfs = offset dans la section TEXT (0-based)                     }
{     Retourne la longueur totale (incluant le 0 terminal) ou 0           }

Function DetectASCIIStringAt(TextOfs: LongInt): LongInt;
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  P   : PByteArray;
  Ofs : LongInt;
  Len : LongInt;
  B   : Byte;
Begin
  DetectASCIIStringAt := 0;
  If ImageBuffer = Nil Then Exit;
  If CodeMap = Nil Then Exit;
  P := PByteArray(ImageBuffer);
  Ofs := TextOffset + TextOfs;
  Len := 0;
  While (TextOfs + Len < CodeMapSize) And (Ofs + Len < ImageSize) Do Begin
    B := P^[Ofs + Len];
    If B = 0 Then Begin
      { Terminateur nul trouve }
      If Len >= MIN_ASCII_LEN Then Begin
        DetectASCIIStringAt := Len + 1;  { inclure le 0 terminal }
        Exit;
      End Else Begin
        DetectASCIIStringAt := 0;
        Exit;
      End;
    End;
    If Not IsASCIIPrintable(B) Then Begin
      DetectASCIIStringAt := 0;
      Exit;
    End;
    Inc(Len);
  End;
  { Fin de section sans 0 terminal : pas une chaine }
  DetectASCIIStringAt := 0;
End;

{ --- IsJumpTableEntry : verifier si un mot long pointe vers du code --- }
{     Addr = adresse logique (PC-relative) a verifier                    }

Function IsJumpTableEntry(Addr: LongInt; TextLen: LongInt): Boolean;
Var
  Idx: Integer;
Begin
  IsJumpTableEntry := False;
  If (Addr < 0) Or (Addr >= TextLen) Then Exit;
  { Verifier si l'adresse est un label connu ou tombe sur une limite paire }
  If (Addr And 1) <> 0 Then Exit;  { les instructions 68000 sont alignees }
  { Si c'est un label connu, c'est probablement une entree de table }
  Idx := FindLabelByAddr(Addr, 0);
  If Idx > 0 Then Begin
    IsJumpTableEntry := True;
    Exit;
  End;
  { Verifier si c'est dans la zone code de la carte }
  If GetCodeMapByte(Addr) = CM_CODE Then
    IsJumpTableEntry := True;
End;

{ --- DetectJumpTableAt : detecter une table de saut --- }
{     TextOfs = offset dans la section TEXT (0-based)     }
{     TextLen = taille de la section TEXT                  }
{     Retourne le nombre d'entrees (0 si pas une table)   }

Function DetectJumpTableAt(TextOfs: LongInt; TextLen: LongInt): LongInt;
Var
  Ofs    : LongInt;
  Count  : LongInt;
  Addr   : LongInt;
Begin
  DetectJumpTableAt := 0;
  If ImageBuffer = Nil Then Exit;
  { Verifier l'alignement }
  If (TextOfs And 1) <> 0 Then Exit;
  Ofs := TextOffset + TextOfs;
  Count := 0;
  While (TextOfs + Count * 4 + 3 < CodeMapSize) And
        (Ofs + Count * 4 + 3 < ImageSize) Do Begin
    Addr := ReadBELongMem(Ofs + Count * 4);
    If Not IsJumpTableEntry(Addr, TextLen) Then Break;
    Inc(Count);
  End;
  { Au moins 2 entrees pour considerer comme une table de saut }
  If Count >= 2 Then
    DetectJumpTableAt := Count;
End;

{ --- MarkCodeRegions : marquer les instructions comme code --- }
{     Parcourt lineairement la section TEXT en utilisant le      }
{     decodeur d'instructions et marque les octets code.         }
{     Suit le flux de controle : apres un RTS/BRA/JMP, les      }
{     octets suivants non cibles par un label sont non-code.     }

Procedure MarkCodeRegions(TextLen: LongInt);
Var
  Ofs      : LongInt;
  PC       : LongInt;
  Inf      : TInstructionInfo;
  ISize    : LongInt;
  InCode   : Boolean;
  Idx      : Integer;
Begin
  If TextLen <= 0 Then Exit;
  If CodeMap = Nil Then Exit;
  InCode := True;  { on commence au point d'entree = code }
  Ofs := TextOffset;
  While Ofs < TextOffset + TextLen Do Begin
    PC := Ofs - TextOffset;
    { Verifier si un label pointe ici (reprend le flux) }
    Idx := FindLabelByAddr(PC, 0);
    If Idx > 0 Then
      InCode := True;
    If InCode Then Begin
      { Decoder l'instruction }
      DecodeInstruction(Ofs, PC, Inf);
      If Inf.IsValid Then Begin
        ISize := Inf.TotalSize;
        If ISize < 2 Then ISize := 2;
        MarkRegion(PC, ISize, CM_CODE);
        { Verifier si le flux est interrompu }
        If IsReturn(Inf) Or IsUnconditionalJump(Inf) Then
          InCode := False;
        Ofs := Ofs + ISize;
      End Else Begin
        { Instruction invalide : quitter le mode code }
        InCode := False;
        Ofs := Ofs + 2;
      End;
    End Else Begin
      { Pas en mode code : avancer octet par octet }
      Ofs := Ofs + 2;
    End;
  End;
End;

{ --- ClassifyDataRegions : classifier les zones non-code --- }
{     Parcourt la carte et pour chaque zone non marquee code,  }
{     tente de detecter :                                       }
{     1) Chaines ASCII terminee par 0                           }
{     2) Tables de saut (listes de mots longs vers du code)    }
{     3) Sinon, marque comme donnees generiques                 }

Procedure ClassifyDataRegions(TextLen: LongInt);
Var
  PC     : LongInt;
  StrLen : LongInt;
  TblCnt : LongInt;
Begin
  If TextLen <= 0 Then Exit;
  If CodeMap = Nil Then Exit;
  PC := 0;
  While PC < TextLen Do Begin
    If GetCodeMapByte(PC) = CM_UNKNOWN Then Begin
      { Essayer de detecter une chaine ASCII }
      StrLen := DetectASCIIStringAt(PC);
      If StrLen > 0 Then Begin
        MarkRegion(PC, StrLen, CM_ASCII);
        PC := PC + StrLen;
        { Aligner sur un mot si necessaire }
        If (PC < TextLen) And ((PC And 1) <> 0) Then Begin
          If GetCodeMapByte(PC) = CM_UNKNOWN Then
            MarkRegion(PC, 1, CM_DATA);
          Inc(PC);
        End;
        Continue;
      End;
      { Essayer de detecter une table de saut }
      If (PC And 1) = 0 Then Begin
        TblCnt := DetectJumpTableAt(PC, TextLen);
        If TblCnt > 0 Then Begin
          MarkRegion(PC, TblCnt * 4, CM_JUMPTBL);
          PC := PC + TblCnt * 4;
          Continue;
        End;
      End;
      { Sinon marquer comme donnee generique }
      MarkRegion(PC, 1, CM_DATA);
      Inc(PC);
    End Else
      Inc(PC);
  End;
End;

{ --- ClassifyTextRegions : fonction principale de classification --- }
{     Alloue la carte, marque le code, classifie les donnees         }

Procedure ClassifyTextRegions(TextLen: LongInt);
Begin
  If TextLen <= 0 Then Exit;
  AllocCodeMap(TextLen);
  MarkCodeRegions(TextLen);
  ClassifyDataRegions(TextLen);
End;

{ --- ShowTextRegions : afficher les resultats de la classification --- }

Procedure ShowTextRegions(TextLen: LongInt; Verbose: Boolean);
Type
  TByteArray = Array[0..0] Of Byte;
  PByteArray = ^TByteArray;
Var
  PC         : LongInt;
  RegStart   : LongInt;
  RegType    : Byte;
  CurType    : Byte;
  CodeCnt    : LongInt;
  DataCnt    : LongInt;
  AsciiCnt   : LongInt;
  JmpTblCnt  : LongInt;
  RegionCnt  : LongInt;
  CodeBytes  : LongInt;
  DataBytes  : LongInt;
  AsciiBytes : LongInt;
  JmpBytes   : LongInt;
  TypeStr    : String;
  P          : PByteArray;
  MaxShow    : Integer;
  ShowLen    : LongInt;
  I          : LongInt;
Begin
  If Not Verbose Then Exit;
  If TextLen <= 0 Then Exit;
  If CodeMap = Nil Then Exit;

  WriteLn;
  WriteLn('=== Discrimination code/donnees dans TEXT ===');
  WriteLn;

  { Compter les statistiques }
  CodeBytes := 0;
  DataBytes := 0;
  AsciiBytes := 0;
  JmpBytes := 0;
  CodeCnt := 0;
  DataCnt := 0;
  AsciiCnt := 0;
  JmpTblCnt := 0;
  RegionCnt := 0;

  If TextLen > 0 Then Begin
    RegStart := 0;
    RegType := GetCodeMapByte(0);
    For PC := 0 To TextLen - 1 Do Begin
      CurType := GetCodeMapByte(PC);
      If CurType <> RegType Then Begin
        { Fin de region }
        Inc(RegionCnt);
        Case RegType Of
          CM_CODE:    Begin Inc(CodeCnt); CodeBytes := CodeBytes + (PC - RegStart); End;
          CM_DATA:    Begin Inc(DataCnt); DataBytes := DataBytes + (PC - RegStart); End;
          CM_ASCII:   Begin Inc(AsciiCnt); AsciiBytes := AsciiBytes + (PC - RegStart); End;
          CM_JUMPTBL: Begin Inc(JmpTblCnt); JmpBytes := JmpBytes + (PC - RegStart); End;
        Else
          DataBytes := DataBytes + (PC - RegStart);
        End;
        RegStart := PC;
        RegType := CurType;
      End;
    End;
    { Derniere region }
    Inc(RegionCnt);
    Case RegType Of
      CM_CODE:    Begin Inc(CodeCnt); CodeBytes := CodeBytes + (TextLen - RegStart); End;
      CM_DATA:    Begin Inc(DataCnt); DataBytes := DataBytes + (TextLen - RegStart); End;
      CM_ASCII:   Begin Inc(AsciiCnt); AsciiBytes := AsciiBytes + (TextLen - RegStart); End;
      CM_JUMPTBL: Begin Inc(JmpTblCnt); JmpBytes := JmpBytes + (TextLen - RegStart); End;
    Else
      DataBytes := DataBytes + (TextLen - RegStart);
    End;
  End;

  WriteLn('Taille section TEXT : ', IntToStr(TextLen), ' octets');
  WriteLn('Code                : ', IntToStr(CodeBytes), ' octets (',
          IntToStr(CodeCnt), ' regions)');
  WriteLn('Donnees generiques  : ', IntToStr(DataBytes), ' octets (',
          IntToStr(DataCnt), ' regions)');
  WriteLn('Chaines ASCII       : ', IntToStr(AsciiBytes), ' octets (',
          IntToStr(AsciiCnt), ' chaines)');
  WriteLn('Tables de saut      : ', IntToStr(JmpBytes), ' octets (',
          IntToStr(JmpTblCnt), ' tables)');
  WriteLn('Regions totales     : ', IntToStr(RegionCnt));

  { Afficher les regions non-code detectees }
  MaxShow := 50;  { limiter l'affichage }
  P := PByteArray(ImageBuffer);

  If (AsciiCnt > 0) Or (JmpTblCnt > 0) Or (DataCnt > 0) Then Begin
    WriteLn;
    WriteLn('--- Regions non-code ---');
    WriteLn('  Adresse     Type           Taille  Detail');
    WriteLn('  ----------  -------------  ------  ------');

    RegStart := 0;
    RegType := GetCodeMapByte(0);
    PC := 1;
    While (PC <= TextLen) And (MaxShow > 0) Do Begin
      If PC < TextLen Then
        CurType := GetCodeMapByte(PC)
      Else
        CurType := 255;  { forcer la fin de la derniere region }
      If CurType <> RegType Then Begin
        { Afficher si c'est non-code }
        If RegType <> CM_CODE Then Begin
          Dec(MaxShow);
          Case RegType Of
            CM_DATA:    TypeStr := 'donnees      ';
            CM_ASCII:   TypeStr := 'chaine ASCII ';
            CM_JUMPTBL: TypeStr := 'table saut   ';
          Else
            TypeStr := 'inconnu      ';
          End;
          ShowLen := PC - RegStart;
          Write('  $', HexLong(RegStart));
          Write('  ', TypeStr);
          Write('  ', IntToStr(ShowLen));
          If Length(IntToStr(ShowLen)) < 6 Then
            Write('' : 6 - Length(IntToStr(ShowLen)));
          { Detail selon le type }
          If (RegType = CM_ASCII) And (P <> Nil) Then Begin
            Write('  "');
            I := RegStart;
            While (I < PC) And (I < RegStart + 40) Do Begin
              If (TextOffset + I < ImageSize) And
                 (P^[TextOffset + I] >= 32) And
                 (P^[TextOffset + I] <= 126) Then
                Write(Chr(P^[TextOffset + I]))
              Else If P^[TextOffset + I] <> 0 Then
                Write('.');
              Inc(I);
            End;
            If PC - RegStart > 40 Then Write('...');
            Write('"');
          End Else If RegType = CM_JUMPTBL Then Begin
            Write('  ', IntToStr(ShowLen Div 4), ' entrees');
          End Else If (RegType = CM_DATA) And (ShowLen <= 8) And (P <> Nil) Then Begin
            Write('  ');
            For I := RegStart To PC - 1 Do Begin
              If TextOffset + I < ImageSize Then
                Write('$', HexByte(P^[TextOffset + I]))
              Else
                Write('$??');
              If I < PC - 1 Then Write(',');
            End;
          End;
          WriteLn;
        End;
        RegStart := PC;
        RegType := CurType;
      End;
      Inc(PC);
    End;
    If MaxShow <= 0 Then
      WriteLn('  ... (tronque)');
  End;
End;

{ --- CountCodeBytes : compter les octets de code --- }

Function CountCodeBytes(TextLen: LongInt): LongInt;
Var
  PC    : LongInt;
  Count : LongInt;
Begin
  Count := 0;
  For PC := 0 To TextLen - 1 Do
    If GetCodeMapByte(PC) = CM_CODE Then
      Inc(Count);
  CountCodeBytes := Count;
End;

{ --- CountDataBytes : compter les octets de donnees --- }
{     Inclut CM_DATA, CM_ASCII, CM_JUMPTBL et CM_UNKNOWN }

Function CountDataBytes(TextLen: LongInt): LongInt;
Var
  PC    : LongInt;
  Count : LongInt;
Begin
  Count := 0;
  For PC := 0 To TextLen - 1 Do
    If GetCodeMapByte(PC) <> CM_CODE Then
      Inc(Count);
  CountDataBytes := Count;
End;

{ --- CountASCIIRegions : compter les regions de chaines ASCII --- }

Function CountASCIIRegions(TextLen: LongInt): LongInt;
Var
  PC     : LongInt;
  Count  : LongInt;
  InStr  : Boolean;
Begin
  Count := 0;
  InStr := False;
  For PC := 0 To TextLen - 1 Do Begin
    If GetCodeMapByte(PC) = CM_ASCII Then Begin
      If Not InStr Then Begin
        Inc(Count);
        InStr := True;
      End;
    End Else
      InStr := False;
  End;
  CountASCIIRegions := Count;
End;

{ --- CountJumpTables : compter les tables de saut --- }

Function CountJumpTables(TextLen: LongInt): LongInt;
Var
  PC     : LongInt;
  Count  : LongInt;
  InTbl  : Boolean;
Begin
  Count := 0;
  InTbl := False;
  For PC := 0 To TextLen - 1 Do Begin
    If GetCodeMapByte(PC) = CM_JUMPTBL Then Begin
      If Not InTbl Then Begin
        Inc(Count);
        InTbl := True;
      End;
    End Else
      InTbl := False;
  End;
  CountJumpTables := Count;
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
  CodeMap     := Nil;
  CodeMapSize := 0;
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
  { TODO 13-25 : desassemblage, generation .S }
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
  { Analyser et afficher les drapeaux du programme }
  ShowPrgFlags(Header, Opts.Verbose);
  { Initialiser et afficher la table des opcodes 68000 }
  InitOpcodeTable;
  ShowOpcodeTable(Opts.Verbose);
  If Opts.Verbose Then
    WriteLn('Opcodes 68000   : ', IntToStr(OpcodeCount),
            ' (transfert: ', IntToStr(CountOpcodesByGroup(GRP_TRANSFER)),
            ', arith: ', IntToStr(CountOpcodesByGroup(GRP_ARITH)),
            ', shift: ', IntToStr(CountOpcodesByGroup(GRP_SHIFT)),
            ', branch: ', IntToStr(CountOpcodesByGroup(GRP_BRANCH)),
            ', bit: ', IntToStr(CountOpcodesByGroup(GRP_BIT)),
            ', misc: ', IntToStr(CountOpcodesByGroup(GRP_MISC)), ')');
  { Afficher les modes d'adressage }
  ShowAddrModes(Opts.Verbose);
  If Opts.Verbose Then
    WriteLn('Modes adressage : ', IntToStr(CountAddrModes));
  { Decoder et afficher les instructions de la section TEXT }
  If Opts.Verbose And (Header.ph_tlen > 0) Then Begin
    WriteLn;
    WriteLn('=== Desassemblage de la section TEXT (',
            IntToStr(Header.ph_tlen), ' octets) ===');
    WriteLn;
    CurOfs := TextOffset;
    EndOfs := TextOffset + Header.ph_tlen;
    While CurOfs < EndOfs Do Begin
      DecodeInstruction(CurOfs, CurOfs - TextOffset, TmpInfo);
      ShowInstruction(TmpInfo, Opts.HexDump);
      If TmpInfo.TotalSize < 2 Then
        CurOfs := CurOfs + 2
      Else
        CurOfs := CurOfs + TmpInfo.TotalSize;
    End;
    WriteLn;
    WriteLn('Instructions    : ', IntToStr(CountInstructions(Header.ph_tlen)));
  End;
  { Premiere passe : analyse du flux de controle }
  If Header.ph_tlen > 0 Then Begin
    FirstPass(Header.ph_tlen);
    ShowFirstPassResults(Opts.Verbose);
    If Opts.Verbose Then Begin
      WriteLn;
      WriteLn('Flux de controle : ',
              IntToStr(CountXRefs), ' refs (',
              IntToStr(CountCallXRefs), ' appels, ',
              IntToStr(CountBranchXRefs), ' branchements)');
    End;
  End;
  { Detection des sous-programmes et des points d'entree }
  If Header.ph_tlen > 0 Then Begin
    DetectSubroutines(Header.ph_tlen);
    ShowSubroutines(Opts.Verbose);
    If Opts.Verbose Then Begin
      WriteLn;
      WriteLn('Sous-programmes : ', IntToStr(CountSubroutines));
    End;
  End;
  { Detection des appels systeme TOS (TRAP) }
  If Header.ph_tlen > 0 Then Begin
    DetectTrapCalls(Header.ph_tlen);
    ShowTrapCalls(Opts.Verbose);
    If Opts.Verbose Then Begin
      WriteLn;
      WriteLn('Appels systeme  : ', IntToStr(CountTrapCalls));
    End;
  End;
  { Discrimination code/donnees dans la section TEXT }
  If Header.ph_tlen > 0 Then Begin
    ClassifyTextRegions(Header.ph_tlen);
    ShowTextRegions(Header.ph_tlen, Opts.Verbose);
    If Opts.Verbose Then Begin
      WriteLn;
      WriteLn('Code/Donnees    : ',
              IntToStr(CountCodeBytes(Header.ph_tlen)), ' octets code, ',
              IntToStr(CountDataBytes(Header.ph_tlen)), ' octets donnees (',
              IntToStr(CountASCIIRegions(Header.ph_tlen)), ' chaines, ',
              IntToStr(CountJumpTables(Header.ph_tlen)), ' tables saut)');
    End;
    FreeCodeMap;
  End;
  { Liberer la memoire }
  FreeSections;
  WriteLn;
  WriteLn('DISPRG v', DISPRG_VERSION,
          ' - TODOs 01-18 [IMPLEMENTE], TODOs 19-25 [A FAIRE]');
End.
