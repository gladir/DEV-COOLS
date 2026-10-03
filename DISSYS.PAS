{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Desassembleur specialise pour les noyaux et pilotes DOS
                (MSDOS.SYS, IO.SYS, et tout DEVICE= comme HIMEM.SYS,
                EMM386.EXE, SMARTDRV.EXE, ANSI.SYS, etc.) - moteur de
                desassemblage RECURSIF (suit reellement CALL/JMP/Jcc au lieu
                d'un simple balayage lineaire), reconnaissance automatique
                des structures DOS (Device Header, Strategy, Interrupt,
                Request Header, DPB, SFT, MCB, drapeau InDOS) et annotation
                des fonctions INT 20h/21h/25h/26h/27h/2Fh/13h/10h connues.
  @license: MIT
}

Program DISSYS;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$A-}
{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GENERALES
  ============================================================ }
Const
 DISSYS_VERSION = '1.0';
 DISSYS_DATE    = '2026-10-03';

 { ---- Formats de fichier reconnus (/FMT) ---- }
 FMT_AUTO = 0;
 FMT_SYS  = 1;   { pilote DOS .SYS brut, En-tete Device a l'offset 0 }
 FMT_COM  = 2;   { .COM brut, charge conceptuellement a l'offset 100h }
 FMT_EXE  = 3;   { .EXE MZ reloge (noyau ou pilote au format EXE renomme) }
 FMT_RAW  = 4;   { image brute sans aucune hypothese (ex: noyau IO.SYS/MSDOS.SYS) }

 { ---- Syntaxes assembleur de sortie (/ASM) ---- }
 SYN_MASM = 0;
 SYN_TASM = 1;
 SYN_NASM = 2;

 { ---- Niveaux de processeur cible (/CPU) ---- }
 CPU_8086 = 0;
 CPU_186  = 1;
 CPU_286  = 2;
 CPU_386  = 3;
 CPU_486  = 4;
 CPU_AUTO = 5;

 { ---- Types d'operandes pour la table des opcodes ---- }
 OT_NONE  = 0;  OT_REG8  = 1;  OT_REG16 = 2;  OT_REG32 = 3;
 OT_SEG   = 4;  OT_CREG  = 5;  OT_DREG  = 6;  OT_TREG  = 7;
 OT_RM8   = 8;  OT_RM16  = 9;  OT_RM32  = 10; OT_MEM   = 11;
 OT_IMM8  = 12; OT_IMM16 = 13; OT_IMM32 = 14; OT_IMM8S = 15;
 OT_REL8  = 16; OT_REL16 = 17;
 OT_FARPTR= 18; OT_MOFFS8= 19; OT_MOFFS16=20;
 OT_AL    = 21; OT_AX    = 22; OT_CL    = 23; OT_DX    = 24; OT_ONE = 25;
 OT_CS    = 26; OT_DS    = 27; OT_ES    = 28; OT_SS    = 29;
 OT_FS    = 30; OT_GS    = 31;
 OT_SREGF = 32; { champ reg du ModRM interprete comme registre de segment }
 OT_REGOP = 33; { registre 16/32 bits code dans les 3 bits de poids faible de l'opcode }
 OT_REGOP8= 34; { BOGUE REEL CORRIGE (2026-10-03, trouve en reutilisant DISSYS
                   pour l'enquete HIMEM/MS-DOS 6.22 : "B4 F2" affiche a tort
                   "MOV SP,F2h" au lieu de "MOV AH,F2h" - OT_REGOP utilisait
                   TOUJOURS la table 16/32 bits, meme pour B0h-B7h (MOV r8,
                   imm8), la SEULE plage ou le registre code dans l'opcode
                   est un registre 8 BITS. Type dedie, utilise uniquement
                   pour B0h-B7h. }

 { ---- Marqueurs de groupes a dispatch special (champ reg du ModRM) ---- }
 GRP_NONE = 0;
 GRP_1    = 1;  { 80/81/82/83 : ADD/OR/ADC/SBB/AND/SUB/XOR/CMP }
 GRP_2    = 2;  { C0/C1/D0/D1/D2/D3 : ROL/ROR/RCL/RCR/SHL/SHR/SAL/SAR }
 GRP_3    = 3;  { F6/F7 : TEST/NOT/NEG/MUL/IMUL/DIV/IDIV }
 GRP_4    = 4;  { FE : INC/DEC r/m8 }
 GRP_5    = 5;  { FF : INC/DEC/CALL/CALLF/JMP/JMPF/PUSH r/m16 }
 GRP_6    = 6;  { 0F 00 : SLDT/STR/LLDT/LTR/VERR/VERW }
 GRP_7    = 7;  { 0F 01 : SGDT/SIDT/LGDT/LIDT/SMSW/LMSW }
 GRP_8    = 8;  { 0F BA : BT/BTS/BTR/BTC r/m16,imm8 }
 GRP_8F   = 9;  { 8F : POP r/m16 (seul /0 est defini) }
 GRP_C6   = 10; { C6 : MOV r/m8,imm8 (seul /0 est defini) }
 GRP_C7   = 11; { C7 : MOV r/m16,imm16 (seul /0 est defini) }

 { ---- Indicateurs par octet (carte code/donnees) ---- }
 BF_UNKNOWN = 0;  { jamais visite }
 BF_CODE    = 1;  { premier octet d'une instruction reellement decodee }
 BF_CODEPART= 2;  { octet interne (ModRM/disp/imm) d'une instruction }
 BF_DATA    = 3;  { donnee (table, pointeur, etc.) }
 BF_STRING  = 4;  { chaine de caracteres ASCII imprimable }
 BF_HEADER  = 5;  { en-tete reconnu (Device Header) }

 { ---- Categories de symboles ---- }
 SYM_SUB    = 0;  { sub_XXXX : cible de CALL }
 SYM_LOC    = 1;  { loc_XXXX : cible de JMP/Jcc }
 SYM_DATA   = 2;  { data_XXXX : reference memoire }
 SYM_DEVHDR = 3;  { DeviceHeader_XXXX }
 SYM_STRAT  = 4;  { Strategy_XXXX }
 SYM_INTR   = 5;  { Interrupt_XXXX }
 SYM_ENTRY  = 6;  { Entry_XXXX : point d'entree principal impose }
 SYM_USER   = 7;  { nom fourni explicitement par l'utilisateur }

 { ---- Limites internes ---- }
 MAX_IMAGE_SIZE  = 2 * 1024 * 1024;  { 2 Mo - largement suffisant pour un noyau/pilote DOS }
 MAX_SYMBOLS     = 16384;
 MAX_WORKQUEUE   = 16384;
 MAX_XREFS       = 32768;

 { ---- Blocs de segments multiples (2026-10-03, enquete HIMEM/MS-DOS 6.22) :
   DISSYS ne gerait jusqu'ici qu'un seul "bloc" (l'image primaire /O). Un
   noyau DOS reel dispatche constamment via CALL/JMP FAR et des tables de
   pointeurs FAR entre PLUSIEURS segments charges independamment (ex :
   plusieurs dumps memoire pris en direct dans l'emulateur, un par segment
   implique). /SEG:xxxx=fichier.bin (repetable) charge un bloc SUPPLEMENTAIRE
   en plus du bloc 0 (le fichier /O) ; le moteur recursif suit alors les
   CALL/JMP FAR directs qui tombent sur un segment charge, EXACTEMENT comme
   un vrai CPU le ferait, au lieu de s'arreter net comme avant ("segment
   different : cible non resoluble dans cette image"). }
 MAX_SEGBLOCKS   = 64;
 MAX_SEG_SIZE    = 65536;  { un bloc supplementaire est toujours un segment reel complet }
 MAX_FARPROBES   = 256;    { voir /FARPTR }

{ ============================================================
  TYPES
  ============================================================ }
Type
 TString = String;

 TByteArr = Array[0..(MAX_IMAGE_SIZE-1)] Of Byte;
 PByteArr = ^TByteArr;

 TFlagArr = Array[0..(MAX_IMAGE_SIZE-1)] Of Byte;
 PFlagArr = ^TFlagArr;

 { Entree de la table des opcodes (une par octet d'opcode primaire 00h-FFh
   et une seconde table identique pour l'echappement 2 octets 0Fh xx). }
 TOpEntry = Record
  Mnemonic : String[11];
  Op1      : Byte;    { OT_xxx }
  Op2      : Byte;    { OT_xxx, OT_NONE si un seul operande }
  Op3      : Byte;    { OT_xxx, OT_NONE si pas de 3e operande (ex: IMUL r,r/m,imm) }
  HasModRM : Boolean;
  Group    : Byte;     { GRP_xxx, GRP_NONE si l'opcode seul suffit }
  MinCPU   : Byte;      { CPU_xxx : niveau minimal pour que cet opcode existe }
 End;

 { Symbole connu (auto-genere ou reconnu) }
 TSymbolRec = Record
  Blk  : Integer;      { indice du bloc de segment (voir TSegBlock) }
  Addr : LongInt;    { adresse (deja ORG-relative, c-a-d valeur affichee) }
  Kind : Byte;        { SYM_xxx }
  Name : TString;
 End;

 { Reference croisee : qui appelle/saute vers qui - FromBlk/ToBlk different
   pour un CALL/JMP FAR direct resolu vers un AUTRE bloc charge (voir /SEG). }
 TXRefRec = Record
  FromBlk  : Integer;
  FromAddr : LongInt;
  ToBlk    : Integer;
  ToAddr   : LongInt;
  IsCall   : Boolean;
 End;

 { Un bloc de segment charge : le fichier /O original (bloc 0) ou un bloc
   supplementaire charge via /SEG:xxxx=fichier.bin. Chaque bloc a sa PROPRE
   image/carte d'octets/ORG/segment - c'est ce qui permet au moteur recursif
   de "traverser" plusieurs dumps memoire distincts comme un vrai CPU le
   ferait via CALL/JMP FAR. }
 TSegBlock = Record
  RealSeg   : Word;       { segment DOS reel represente par ce bloc }
  BlkOrg    : LongInt;    { ORG de ce bloc (0 pour un bloc supplementaire) }
  BlkHasSeg : Boolean;    { afficher "SEG:OFS" pour ce bloc }
  FileName  : TString;
  Image     : PByteArr;
  ByteFlags : PFlagArr;
  ImageSize : LongInt;
  Loaded    : Boolean;
 End;

 { Element de la file d'attente du moteur recursif : desormais un couple
   (bloc, adresse) plutot qu'une simple adresse - necessaire des qu'un CALL/
   JMP FAR direct peut faire basculer le travail vers un AUTRE bloc charge. }
 TWorkItem = Record
  Blk  : Integer;
  Addr : LongInt;
 End;

 { En-tete de pilote DOS (Device Header), 18 octets au minimum }
 TDeviceHeader = Record
  NextOfs      : Word;
  NextSeg      : Word;
  Attributes   : Word;
  StrategyOfs  : Word;
  InterruptOfs : Word;
  Name         : Array[0..7] Of Byte;
 End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
 { --- Image chargee en memoire --- }
 Image      : PByteArr;
 ImageSize  : LongInt;
 ByteFlags  : PFlagArr;

 { --- Parametres de ligne de commande --- }
 InputFileName  : TString;
 OutputFileName : TString;
 MapFileName    : TString;
 OptFormat      : Byte;
 OptCPU         : Byte;
 OptAsmSyntax   : Byte;
 OptOrg         : LongInt;       { adresse d'origine affichee pour l'octet 0 de l'image }
 OptHasOrg      : Boolean;
 OptBase        : LongInt;       { adresse de chargement supposee (informative) }
 OptHasBase     : Boolean;
 OptEntry       : LongInt;       { point d'entree force, -1 si absent }
 OptHasEntry    : Boolean;
 OptSeg         : Word;          { segment de chargement affiche (prefixe SEG: optionnel) }
 OptHasSeg      : Boolean;
 OptDosVerMajor : Byte;
 OptDosVerMinor : Byte;

 OptRecursive   : Boolean;      { /R : suivre CALL/JMP/Jcc (moteur recursif) }
 OptLinear      : Boolean;      { /L : desassembler lineairement tout l'intervalle }
 OptData        : Boolean;      { /DATA : tenter de distinguer code/donnees }
 OptStrings     : Boolean;      { /STRINGS : detecter les chaines ASCII }
 OptIntAnnot    : Boolean;      { /INT : annoter les INT connus }
 OptApiAnnot    : Boolean;      { /API : decoder AH/AL des fonctions DOS/BIOS }
 OptDrv         : Boolean;      { /DRV : analyser les structures de pilote }
 OptHdr         : Boolean;      { /HDR : afficher/analyser les en-tetes }
 OptReloc       : Boolean;      { /RELOC : informations de relogement (EXE) }
 OptSymbols     : Boolean;      { /SYMBOLS : noms symboliques automatiques }
 OptComments    : Boolean;      { /COMMENTS : commentaires explicatifs }
 OptBytes       : Boolean;      { /BYTES : octets machine en prefixe }
 OptAddr        : Boolean;      { /ADDR : adresses en prefixe }
 OptXref        : Boolean;      { /XREF : references croisees }
 OptQuiet       : Boolean;      { /Q }
 OptVerbose     : Boolean;      { /V }

 { --- Profils d'analyse DOS --- }
 OptModeSys     : Boolean;      { /SYS }
 OptModeDriver  : Boolean;      { /DRIVER }
 OptModeKernel  : Boolean;      { /KERNEL }
 OptXms         : Boolean;      { /XMS }
 OptEms         : Boolean;      { /EMS }
 OptBios        : Boolean;      { /BIOS }
 OptDosApi      : Boolean;      { /DOSAPI }
 OptDpb         : Boolean;      { /DPB }
 OptSft         : Boolean;      { /SFT }
 OptMcb         : Boolean;      { /MCB }
 OptIndos       : Boolean;      { /INDOS }

 { --- Tables d'opcodes --- }
 OpTable   : Array[0..255] Of TOpEntry;
 Op0FTable : Array[0..255] Of TOpEntry;

 { --- Tables de symboles/xref --- }
 Symbols    : Array[0..MAX_SYMBOLS-1] Of TSymbolRec;
 SymbolCnt  : LongInt;
 XRefs      : Array[0..MAX_XREFS-1] Of TXRefRec;
 XRefCnt    : LongInt;

 { --- File d'attente de travail (moteur recursif) --- }
 WorkQueue    : Array[0..MAX_WORKQUEUE-1] Of TWorkItem;
 WorkQueueCnt : LongInt;

 { --- Device Header reconnu (toujours relatif au bloc 0, le fichier /O -
   un bloc supplementaire /SEG:xxxx=fichier.bin est un dump memoire brut,
   jamais un .SYS avec son propre en-tete) --- }
 HasDeviceHeader : Boolean;
 DevHeader       : TDeviceHeader;

 { --- Blocs de segments (voir TSegBlock / /SEG:xxxx=fichier.bin) --- }
 SegBlocks   : Array[0..MAX_SEGBLOCKS-1] Of TSegBlock;
 SegBlockCnt : Integer;
 CurBlk      : Integer;   { bloc actuellement "actif" : Image/ByteFlags/
                             ImageSize/OptOrg/OptSeg lui correspondent }

 { --- Blocs supplementaires EN ATTENTE (/SEG:xxxx=fichier.bin), collectes
   pendant ParseArgs mais charges plus tard dans le programme principal,
   APRES que le bloc 0 (fichier /O) ait pris sa place via RegisterBlock0. }
 PendingSegVal  : Array[0..MAX_SEGBLOCKS-1] Of Word;
 PendingSegFile : Array[0..MAX_SEGBLOCKS-1] Of TString;
 PendingSegCnt  : Integer;

 { --- Sondes de pointeur FAR manuelles (/FARPTR:[xxxx:]yyyy) : l'utilisateur
   indique un endroit ou une table/variable contient un pointeur FAR
   (mot offset puis mot segment, convention x86 standard) a lire et a
   suivre si son segment correspond a un bloc charge - utile pour atteindre
   du code appele uniquement via une table de sauts qu'aucune analyse de
   flux statique ne peut decouvrir seule. }
 FarProbeSeg : Array[0..MAX_FARPROBES-1] Of Word;
 FarProbeOfs : Array[0..MAX_FARPROBES-1] Of Word;
 FarProbeHasSeg : Array[0..MAX_FARPROBES-1] Of Boolean;
 FarProbeCnt : Integer;

 { --- Fichiers de sortie --- }
 OutF : Text;
 MapF : Text;
 OptUseMap : Boolean;

{ ============================================================
  UTILITAIRES DE BASE : FORMATAGE HEXADECIMAL
  ============================================================ }

Function HexDigit(N: Byte): Char;
Begin
 If N < 10 Then HexDigit := Chr(Ord('0') + N)
 Else HexDigit := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): TString;
Begin
 HexByte := HexDigit(B Shr 4) + HexDigit(B And $0F) + 'h';
End;

Function HexWord(W: Word): TString;
Begin
 HexWord := HexDigit((W Shr 12) And $0F) + HexDigit((W Shr 8) And $0F) +
            HexDigit((W Shr 4) And $0F) + HexDigit(W And $0F) + 'h';
End;

Function HexLong(L: LongInt): TString;
Var S: TString; V: LongWord; I: Integer;
Begin
 V := LongWord(L);
 S := '';
 For I := 7 Downto 0 Do
  S := S + HexDigit((V Shr (I*4)) And $0F);
 HexLong := S + 'h';
End;

{ Formate une adresse d'affichage (deja ORG-relative) selon que le BLOC
  concerne a un segment d'affichage connu (/SEG) ou non. Parametre explicite
  (plutot que les globales OptSeg/OptHasSeg "actives") car un listing multi-
  bloc doit pouvoir formater une adresse d'un bloc SANS basculer le bloc
  actif (ex : la section XREF finale, qui melange des adresses de plusieurs
  blocs sur les memes lignes). }
Function FmtAddr(Blk: Integer; Addr: LongInt): TString;
Begin
 If (Blk >= 0) And (Blk < SegBlockCnt) And SegBlocks[Blk].BlkHasSeg Then
  FmtAddr := HexWord(SegBlocks[Blk].RealSeg) + ':' + HexWord(Word(Addr))
 Else
  FmtAddr := HexWord(Word(Addr));
End;

Function LTrimStr(S: TString): TString;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 LTrimStr := S;
End;

Function UpStr(S: TString): TString;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

{ Pad : complete une chaine a droite avec des espaces jusqu'a la largeur N
  (utilitaire local, FPC -Mtp n'offre pas de fonction standard equivalente
  sous ce mode). }
Function Pad(S: TString; N: Integer): TString;
Begin
 While Length(S) < N Do S := S + ' ';
 Pad := S;
End;

{ Convertit une chaine hexadecimale (avec ou sans suffixe 'h'/'H' ou prefixe
  '0x'/'$') en LongInt - accepte aussi un nombre decimal pur si aucun
  caractere A-F n'est present, pour rester tolerant sur la ligne de commande. }
Function HexStrToLong(S: TString): LongInt;
Var I: Integer; V: LongInt; C: Char; Neg: Boolean;
Begin
 V := 0;
 Neg := False;
 S := UpStr(S);
 If (Length(S) > 0) And (S[1] = '-') Then Begin Neg := True; Delete(S,1,1); End;
 If (Length(S) >= 2) And (S[1] = '0') And (S[2] = 'X') Then Delete(S, 1, 2);
 If (Length(S) >= 1) And (S[1] = '$') Then Delete(S, 1, 1);
 If (Length(S) >= 1) And (S[Length(S)] = 'H') Then Delete(S, Length(S), 1);
 For I := 1 To Length(S) Do Begin
  C := S[I];
  If (C >= '0') And (C <= '9') Then V := V*16 + (Ord(C)-Ord('0'))
  Else If (C >= 'A') And (C <= 'F') Then V := V*16 + (Ord(C)-Ord('A')+10);
 End;
 If Neg Then V := -V;
 HexStrToLong := V;
End;

{ ChangeFileExt : remplace (ou ajoute) l'extension d'un nom de fichier. }
Function ChangeFileExt(FileName, NewExt: TString): TString;
Var I: Integer; Base: TString;
Begin
 Base := FileName;
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   Base := Copy(FileName, 1, I - 1);
   Break;
  End;
  If (FileName[I] = '\') Or (FileName[I] = '/') Then Break;
 End;
 ChangeFileExt := Base + NewExt;
End;

Function DecStrToLong(S: TString): LongInt;
Var I: Integer; V: LongInt;
Begin
 V := 0;
 For I := 1 To Length(S) Do
  If (S[I] >= '0') And (S[I] <= '9') Then V := V*10 + (Ord(S[I])-Ord('0'));
 DecStrToLong := V;
End;

{ Decoupe une version DOS "6.22"/"6,22"/"6" en partie majeure/mineure
  (chiffres DECIMAUX, pas hexadecimaux) - le separateur peut etre '.' ou
  ',', la partie mineure vaut 0 si absente. }
Procedure ParseDosVersion(S: TString; Var Major, Minor: Byte);
Var P: Integer; MajS, MinS: TString;
Begin
 P := Pos('.', S);
 If P = 0 Then P := Pos(',', S);
 If P > 0 Then Begin
  MajS := Copy(S, 1, P-1);
  MinS := Copy(S, P+1, Length(S)-P);
 End Else Begin
  MajS := S;
  MinS := '0';
 End;
 Major := Byte(DecStrToLong(MajS));
 Minor := Byte(DecStrToLong(MinS));
End;

{ ============================================================
  TABLES DE NOMS DE REGISTRES
  ============================================================ }
Const
 Reg8Names : Array[0..7] Of String[2] = ('AL','CL','DL','BL','AH','CH','DH','BH');
 Reg16Names: Array[0..7] Of String[2] = ('AX','CX','DX','BX','SP','BP','SI','DI');
 Reg32Names: Array[0..7] Of String[3] = ('EAX','ECX','EDX','EBX','ESP','EBP','ESI','EDI');
 SegNames  : Array[0..7] Of String[2] = ('ES','CS','SS','DS','FS','GS','??','??');
 CRegNames : Array[0..7] Of String[3] = ('CR0','CR1','CR2','CR3','CR4','CR5','CR6','CR7');
 DRegNames : Array[0..7] Of String[3] = ('DR0','DR1','DR2','DR3','DR4','DR5','DR6','DR7');
 TRegNames : Array[0..7] Of String[3] = ('TR0','TR1','TR2','TR3','TR4','TR5','TR6','TR7');
 CondNames : Array[0..15] Of String[4] =
  ('O','NO','B','NB','Z','NZ','BE','A','S','NS','P','NP','L','GE','LE','G');
 { 16 effectifs d'adressage 16 bits, ordre canonique Intel }
 RM16Base  : Array[0..7] Of String[7] =
  ('BX+SI','BX+DI','BP+SI','BP+DI','SI','DI','BP','BX');

{ ============================================================
  TABLE DES FONCTIONS DOS/BIOS CONNUES (POUR /API ET /INT)
  ============================================================ }
Type
 TApiEntry = Record
  IntNum : Byte;
  AhVal  : Integer;   { -1 = s'applique quel que soit AH }
  AlVal  : Integer;   { -1 = s'applique quel que soit AL, seulement teste si AhVal<>-1 }
  Descr  : TString;
  MinDos : Word;       { version DOS minimale (Major*100+Minor), 0 si toujours }
 End;

Const
 API_COUNT = 142;
 ApiTable: Array[0..API_COUNT-1] Of TApiEntry = (
  { ---- INT 20h/21h/25h/26h/27h : fonctions DOS classiques ---- }
  (IntNum:$20; AhVal:-1; AlVal:-1; Descr:'Terminer le programme (ancienne forme)'; MinDos:0),
  (IntNum:$21; AhVal:$00; AlVal:-1; Descr:'Terminer le programme'; MinDos:0),
  (IntNum:$21; AhVal:$01; AlVal:-1; Descr:'Lire un caractere clavier avec echo'; MinDos:0),
  (IntNum:$21; AhVal:$02; AlVal:-1; Descr:'Afficher un caractere'; MinDos:0),
  (IntNum:$21; AhVal:$06; AlVal:-1; Descr:'E/S console directe'; MinDos:0),
  (IntNum:$21; AhVal:$07; AlVal:-1; Descr:'Lire caractere sans echo, sans Ctrl-C'; MinDos:0),
  (IntNum:$21; AhVal:$08; AlVal:-1; Descr:'Lire caractere sans echo'; MinDos:0),
  (IntNum:$21; AhVal:$09; AlVal:-1; Descr:'Afficher une chaine terminee par $'; MinDos:0),
  (IntNum:$21; AhVal:$0A; AlVal:-1; Descr:'Saisir une chaine au clavier'; MinDos:0),
  (IntNum:$21; AhVal:$0B; AlVal:-1; Descr:'Verifier l etat du clavier'; MinDos:0),
  (IntNum:$21; AhVal:$0C; AlVal:-1; Descr:'Vider le tampon clavier puis appeler une fonction'; MinDos:0),
  (IntNum:$21; AhVal:$0D; AlVal:-1; Descr:'Reinitialiser les disques (flush buffers)'; MinDos:0),
  (IntNum:$21; AhVal:$0E; AlVal:-1; Descr:'Selectionner le lecteur par defaut'; MinDos:0),
  (IntNum:$21; AhVal:$0F; AlVal:-1; Descr:'Ouvrir un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$10; AlVal:-1; Descr:'Fermer un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$11; AlVal:-1; Descr:'Chercher premier fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$12; AlVal:-1; Descr:'Chercher fichier suivant (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$13; AlVal:-1; Descr:'Supprimer un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$14; AlVal:-1; Descr:'Lecture sequentielle (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$15; AlVal:-1; Descr:'Ecriture sequentielle (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$16; AlVal:-1; Descr:'Creer un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$17; AlVal:-1; Descr:'Renommer un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$19; AlVal:-1; Descr:'Obtenir le lecteur par defaut'; MinDos:0),
  (IntNum:$21; AhVal:$1A; AlVal:-1; Descr:'Positionner le DTA (Disk Transfer Area)'; MinDos:0),
  (IntNum:$21; AhVal:$21; AlVal:-1; Descr:'Lecture aleatoire (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$22; AlVal:-1; Descr:'Ecriture aleatoire (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$23; AlVal:-1; Descr:'Obtenir la taille d un fichier (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$24; AlVal:-1; Descr:'Positionner l enregistrement relatif (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$25; AlVal:-1; Descr:'Definir un vecteur d interruption'; MinDos:0),
  (IntNum:$21; AhVal:$26; AlVal:-1; Descr:'Creer un nouveau PSP'; MinDos:0),
  (IntNum:$21; AhVal:$27; AlVal:-1; Descr:'Lecture aleatoire par blocs (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$28; AlVal:-1; Descr:'Ecriture aleatoire par blocs (FCB)'; MinDos:0),
  (IntNum:$21; AhVal:$29; AlVal:-1; Descr:'Analyser un nom de fichier vers FCB'; MinDos:0),
  (IntNum:$21; AhVal:$2A; AlVal:-1; Descr:'Obtenir la date systeme'; MinDos:0),
  (IntNum:$21; AhVal:$2B; AlVal:-1; Descr:'Definir la date systeme'; MinDos:0),
  (IntNum:$21; AhVal:$2C; AlVal:-1; Descr:'Obtenir l heure systeme'; MinDos:0),
  (IntNum:$21; AhVal:$2D; AlVal:-1; Descr:'Definir l heure systeme'; MinDos:0),
  (IntNum:$21; AhVal:$2E; AlVal:-1; Descr:'Activer/desactiver la verification disque'; MinDos:0),
  (IntNum:$21; AhVal:$2F; AlVal:-1; Descr:'Obtenir l adresse du DTA courant'; MinDos:0),
  (IntNum:$21; AhVal:$30; AlVal:-1; Descr:'Obtenir le numero de version DOS'; MinDos:0),
  (IntNum:$21; AhVal:$31; AlVal:-1; Descr:'Terminer et rester resident (TSR)'; MinDos:0),
  (IntNum:$21; AhVal:$32; AlVal:-1; Descr:'Obtenir l adresse du DPB (Drive Parameter Block)'; MinDos:0),
  (IntNum:$21; AhVal:$33; AlVal:$00; Descr:'Obtenir l etat de Ctrl-Break'; MinDos:0),
  (IntNum:$21; AhVal:$33; AlVal:$01; Descr:'Definir l etat de Ctrl-Break'; MinDos:0),
  (IntNum:$21; AhVal:$33; AlVal:$05; Descr:'Obtenir la version DOS reelle (boot)'; MinDos:500),
  (IntNum:$21; AhVal:$33; AlVal:$06; Descr:'Obtenir la version DOS reelle (complete)'; MinDos:500),
  (IntNum:$21; AhVal:$34; AlVal:-1; Descr:'Obtenir l adresse du drapeau InDOS (retour ES:BX)'; MinDos:0),
  (IntNum:$21; AhVal:$35; AlVal:-1; Descr:'Obtenir un vecteur d interruption'; MinDos:0),
  (IntNum:$21; AhVal:$36; AlVal:-1; Descr:'Obtenir l espace disque libre'; MinDos:0),
  (IntNum:$21; AhVal:$37; AlVal:-1; Descr:'Obtenir/definir le caractere switch (SWITCHAR)'; MinDos:0),
  (IntNum:$21; AhVal:$38; AlVal:-1; Descr:'Obtenir/definir les informations de pays'; MinDos:0),
  (IntNum:$21; AhVal:$39; AlVal:-1; Descr:'Creer un repertoire'; MinDos:0),
  (IntNum:$21; AhVal:$3A; AlVal:-1; Descr:'Supprimer un repertoire'; MinDos:0),
  (IntNum:$21; AhVal:$3B; AlVal:-1; Descr:'Changer de repertoire courant'; MinDos:0),
  (IntNum:$21; AhVal:$3C; AlVal:-1; Descr:'Creer un fichier (handle)'; MinDos:0),
  (IntNum:$21; AhVal:$3D; AlVal:-1; Descr:'Ouvrir un fichier (handle)'; MinDos:0),
  (IntNum:$21; AhVal:$3E; AlVal:-1; Descr:'Fermer un fichier (handle)'; MinDos:0),
  (IntNum:$21; AhVal:$3F; AlVal:-1; Descr:'Lire un fichier/peripherique (handle)'; MinDos:0),
  (IntNum:$21; AhVal:$40; AlVal:-1; Descr:'Ecrire dans un fichier/peripherique (handle)'; MinDos:0),
  (IntNum:$21; AhVal:$41; AlVal:-1; Descr:'Supprimer un fichier'; MinDos:0),
  (IntNum:$21; AhVal:$42; AlVal:-1; Descr:'Deplacer le pointeur de fichier (seek)'; MinDos:0),
  (IntNum:$21; AhVal:$43; AlVal:-1; Descr:'Obtenir/definir les attributs de fichier'; MinDos:0),
  (IntNum:$21; AhVal:$44; AlVal:-1; Descr:'IOCTL (controle de peripherique)'; MinDos:0),
  (IntNum:$21; AhVal:$45; AlVal:-1; Descr:'Dupliquer un handle de fichier'; MinDos:0),
  (IntNum:$21; AhVal:$46; AlVal:-1; Descr:'Forcer la duplication d un handle'; MinDos:0),
  (IntNum:$21; AhVal:$47; AlVal:-1; Descr:'Obtenir le repertoire courant'; MinDos:0),
  (IntNum:$21; AhVal:$48; AlVal:-1; Descr:'Allouer un bloc memoire (MCB)'; MinDos:0),
  (IntNum:$21; AhVal:$49; AlVal:-1; Descr:'Liberer un bloc memoire (MCB)'; MinDos:0),
  (IntNum:$21; AhVal:$4A; AlVal:-1; Descr:'Redimensionner un bloc memoire (MCB)'; MinDos:0),
  (IntNum:$21; AhVal:$4B; AlVal:-1; Descr:'Charger/executer un programme (EXEC)'; MinDos:0),
  (IntNum:$21; AhVal:$4C; AlVal:-1; Descr:'Terminer avec code de retour'; MinDos:0),
  (IntNum:$21; AhVal:$4D; AlVal:-1; Descr:'Obtenir le code de retour du processus enfant'; MinDos:0),
  (IntNum:$21; AhVal:$4E; AlVal:-1; Descr:'Chercher le premier fichier correspondant'; MinDos:0),
  (IntNum:$21; AhVal:$4F; AlVal:-1; Descr:'Chercher le fichier suivant correspondant'; MinDos:0),
  (IntNum:$21; AhVal:$50; AlVal:-1; Descr:'Definir le PSP courant (non documente)'; MinDos:0),
  (IntNum:$21; AhVal:$51; AlVal:-1; Descr:'Obtenir le PSP courant (non documente)'; MinDos:0),
  (IntNum:$21; AhVal:$52; AlVal:-1; Descr:'Obtenir le pointeur SYSVARS/liste des listes (retour ES:BX)'; MinDos:0),
  (IntNum:$21; AhVal:$53; AlVal:-1; Descr:'Traduire BPB en DPB (non documente)'; MinDos:0),
  (IntNum:$21; AhVal:$54; AlVal:-1; Descr:'Obtenir le drapeau de verification disque'; MinDos:0),
  (IntNum:$21; AhVal:$56; AlVal:-1; Descr:'Renommer un fichier'; MinDos:0),
  (IntNum:$21; AhVal:$57; AlVal:-1; Descr:'Obtenir/definir la date/heure d un fichier'; MinDos:0),
  (IntNum:$21; AhVal:$58; AlVal:-1; Descr:'Obtenir/definir la strategie d allocation memoire'; MinDos:300),
  (IntNum:$21; AhVal:$59; AlVal:-1; Descr:'Obtenir des informations d erreur etendues'; MinDos:300),
  (IntNum:$21; AhVal:$5A; AlVal:-1; Descr:'Creer un fichier temporaire'; MinDos:300),
  (IntNum:$21; AhVal:$5B; AlVal:-1; Descr:'Creer un nouveau fichier'; MinDos:300),
  (IntNum:$21; AhVal:$5C; AlVal:-1; Descr:'Verrouiller/deverrouiller une region de fichier'; MinDos:300),
  (IntNum:$21; AhVal:$5D; AlVal:-1; Descr:'Fonctions reseau diverses (non documente)'; MinDos:300),
  (IntNum:$21; AhVal:$5E; AlVal:-1; Descr:'Fonctions reseau (nom machine, impression)'; MinDos:300),
  (IntNum:$21; AhVal:$5F; AlVal:-1; Descr:'Fonctions reseau (redirections)'; MinDos:300),
  (IntNum:$21; AhVal:$60; AlVal:-1; Descr:'Qualifier un nom de fichier (non documente)'; MinDos:300),
  (IntNum:$21; AhVal:$62; AlVal:-1; Descr:'Obtenir l adresse du PSP courant'; MinDos:300),
  (IntNum:$21; AhVal:$63; AlVal:-1; Descr:'Obtenir la table DBCS (jeux de caracteres)'; MinDos:214),
  (IntNum:$21; AhVal:$64; AlVal:-1; Descr:'Verrou de partage de pilote (non documente)'; MinDos:330),
  (IntNum:$21; AhVal:$65; AlVal:-1; Descr:'Obtenir des informations etendues de pays'; MinDos:300),
  (IntNum:$21; AhVal:$66; AlVal:-1; Descr:'Obtenir/definir la page de code globale'; MinDos:300),
  (IntNum:$21; AhVal:$67; AlVal:-1; Descr:'Definir le nombre maximal de handles'; MinDos:300),
  (IntNum:$21; AhVal:$68; AlVal:-1; Descr:'Vider les tampons de fichier (commit)'; MinDos:300),
  (IntNum:$21; AhVal:$6C; AlVal:-1; Descr:'Extension d ouverture/creation de fichier'; MinDos:400),
  (IntNum:$21; AhVal:$71; AlVal:-1; Descr:'Fonctions de noms longs Windows 95'; MinDos:700),
  (IntNum:$25; AhVal:-1; AlVal:-1; Descr:'Lecture absolue de secteurs disque'; MinDos:0),
  (IntNum:$26; AhVal:-1; AlVal:-1; Descr:'Ecriture absolue de secteurs disque'; MinDos:0),
  (IntNum:$27; AhVal:-1; AlVal:-1; Descr:'Terminer et rester resident (ancienne forme)'; MinDos:0),
  { ---- INT 2Fh : multiplex DOS/TSR ---- }
  (IntNum:$2F; AhVal:$11; AlVal:-1; Descr:'Multiplex "services internes DOS" (non documente)'; MinDos:0),
  (IntNum:$2F; AhVal:$12; AlVal:-1; Descr:'Multiplex "services internes DOS" (SYSINIT/COMMAND)'; MinDos:0),
  (IntNum:$2F; AhVal:$15; AlVal:-1; Descr:'Multiplex MSCDEX (CD-ROM)'; MinDos:0),
  (IntNum:$2F; AhVal:$16; AlVal:-1; Descr:'Multiplex Windows (WINOLDAP/broadcast)'; MinDos:0),
  (IntNum:$2F; AhVal:$1A; AlVal:-1; Descr:'Multiplex ANSI.SYS'; MinDos:0),
  (IntNum:$2F; AhVal:$43; AlVal:$00; Descr:'XMS - verification d installation (retour AL=80h)'; MinDos:0),
  (IntNum:$2F; AhVal:$43; AlVal:$10; Descr:'XMS - obtenir le point d entree (retour ES:BX)'; MinDos:0),
  (IntNum:$2F; AhVal:$46; AlVal:-1; Descr:'Multiplex EMS (Expanded Memory)'; MinDos:0),
  (IntNum:$2F; AhVal:$48; AlVal:-1; Descr:'Multiplex DOSKEY'; MinDos:0),
  (IntNum:$2F; AhVal:$4A; AlVal:-1; Descr:'Multiplex ASSIGN/APPEND'; MinDos:0),
  (IntNum:$2F; AhVal:$B7; AlVal:-1; Descr:'Multiplex APPEND'; MinDos:0),
  (IntNum:$2F; AhVal:$AD; AlVal:-1; Descr:'Multiplex NLSFUNC (support national)'; MinDos:0),
  (IntNum:$2F; AhVal:$06; AlVal:-1; Descr:'Multiplex ASSIGN (table de redirection de lecteurs)'; MinDos:0),
  (IntNum:$2F; AhVal:$10; AlVal:-1; Descr:'Multiplex SHARE'; MinDos:0),
  { ---- INT 13h : BIOS disque ---- }
  (IntNum:$13; AhVal:$00; AlVal:-1; Descr:'BIOS disque - reinitialiser le controleur'; MinDos:0),
  (IntNum:$13; AhVal:$01; AlVal:-1; Descr:'BIOS disque - obtenir l etat du dernier appel'; MinDos:0),
  (IntNum:$13; AhVal:$02; AlVal:-1; Descr:'BIOS disque - lire des secteurs (CHS)'; MinDos:0),
  (IntNum:$13; AhVal:$03; AlVal:-1; Descr:'BIOS disque - ecrire des secteurs (CHS)'; MinDos:0),
  (IntNum:$13; AhVal:$04; AlVal:-1; Descr:'BIOS disque - verifier des secteurs'; MinDos:0),
  (IntNum:$13; AhVal:$05; AlVal:-1; Descr:'BIOS disque - formater une piste'; MinDos:0),
  (IntNum:$13; AhVal:$08; AlVal:-1; Descr:'BIOS disque - obtenir les parametres du lecteur'; MinDos:0),
  (IntNum:$13; AhVal:$0C; AlVal:-1; Descr:'BIOS disque - positionner tete (seek)'; MinDos:0),
  (IntNum:$13; AhVal:$15; AlVal:-1; Descr:'BIOS disque - obtenir le type de disque'; MinDos:0),
  (IntNum:$13; AhVal:$41; AlVal:-1; Descr:'BIOS disque - verifier les extensions LBA (IBM/MS INT13)'; MinDos:0),
  (IntNum:$13; AhVal:$42; AlVal:-1; Descr:'BIOS disque - lecture etendue (LBA)'; MinDos:0),
  (IntNum:$13; AhVal:$43; AlVal:-1; Descr:'BIOS disque - ecriture etendue (LBA)'; MinDos:0),
  (IntNum:$13; AhVal:$48; AlVal:-1; Descr:'BIOS disque - obtenir les parametres etendus'; MinDos:0),
  { ---- INT 10h : BIOS video ---- }
  (IntNum:$10; AhVal:$00; AlVal:-1; Descr:'BIOS video - definir le mode video'; MinDos:0),
  (IntNum:$10; AhVal:$01; AlVal:-1; Descr:'BIOS video - definir la forme du curseur'; MinDos:0),
  (IntNum:$10; AhVal:$02; AlVal:-1; Descr:'BIOS video - positionner le curseur'; MinDos:0),
  (IntNum:$10; AhVal:$06; AlVal:-1; Descr:'BIOS video - faire defiler vers le haut'; MinDos:0),
  (IntNum:$10; AhVal:$0E; AlVal:-1; Descr:'BIOS video - ecrire un caractere en mode teletype'; MinDos:0),
  (IntNum:$10; AhVal:$0F; AlVal:-1; Descr:'BIOS video - obtenir le mode video courant'; MinDos:0),
  { ---- INT 15h : BIOS systeme (A20/memoire etendue) ---- }
  (IntNum:$15; AhVal:$87; AlVal:-1; Descr:'BIOS systeme - deplacer un bloc de memoire etendue'; MinDos:0),
  (IntNum:$15; AhVal:$88; AlVal:-1; Descr:'BIOS systeme - obtenir la taille de memoire etendue'; MinDos:0),
  (IntNum:$15; AhVal:$89; AlVal:-1; Descr:'BIOS systeme - passer en mode protege'; MinDos:0),
  (IntNum:$15; AhVal:$C0; AlVal:-1; Descr:'BIOS systeme - obtenir les parametres de configuration'; MinDos:0),
  (IntNum:$15; AhVal:$E8; AlVal:$01; Descr:'BIOS systeme - obtenir la carte memoire (E801h)'; MinDos:0),
  (IntNum:$1A; AhVal:$00; AlVal:-1; Descr:'BIOS horloge - lire le compteur de tics'; MinDos:0),
  (IntNum:$1A; AhVal:$02; AlVal:-1; Descr:'BIOS horloge - lire l heure RTC'; MinDos:0)
 );

{ ============================================================
  CONSTRUCTION DES TABLES D'OPCODES (256 + 256)
  ============================================================ }

Procedure SetOp(Code: Byte; Mn: String; O1,O2,O3: Byte; Mdrm: Boolean; Grp,MinCpu: Byte);
Begin
 OpTable[Code].Mnemonic := Mn;
 OpTable[Code].Op1      := O1;
 OpTable[Code].Op2      := O2;
 OpTable[Code].Op3      := O3;
 OpTable[Code].HasModRM := Mdrm;
 OpTable[Code].Group    := Grp;
 OpTable[Code].MinCPU   := MinCpu;
End;

Procedure Set0F(Code: Byte; Mn: String; O1,O2,O3: Byte; Mdrm: Boolean; Grp,MinCpu: Byte);
Begin
 Op0FTable[Code].Mnemonic := Mn;
 Op0FTable[Code].Op1      := O1;
 Op0FTable[Code].Op2      := O2;
 Op0FTable[Code].Op3      := O3;
 Op0FTable[Code].HasModRM := Mdrm;
 Op0FTable[Code].Group    := Grp;
 Op0FTable[Code].MinCPU   := MinCpu;
End;

Procedure BuildOpcodeTables;
Var I: Integer; AluNames: Array[0..7] Of String[3];
Begin
 For I := 0 To 255 Do Begin
  SetOp(I, '???', OT_NONE, OT_NONE, OT_NONE, False, GRP_NONE, CPU_8086);
  Set0F(I, '???', OT_NONE, OT_NONE, OT_NONE, False, GRP_NONE, CPU_386);
 End;

 AluNames[0] := 'ADD'; AluNames[1] := 'OR';  AluNames[2] := 'ADC'; AluNames[3] := 'SBB';
 AluNames[4] := 'AND'; AluNames[5] := 'SUB'; AluNames[6] := 'XOR'; AluNames[7] := 'CMP';

 { ---- Groupes ALU 00h-3Dh : 6 opcodes par groupe (rm8,r8 / rm16,r16 /
   r8,rm8 / r16,rm16 / AL,imm8 / AX,imm16), puis PUSH/POP de segment et
   DAA/DAS/AAA/AAS intercales exactement comme le vrai jeu d'instructions. }
 For I := 0 To 7 Do Begin
  SetOp($00+I*8, AluNames[I], OT_RM8,  OT_REG8,  OT_NONE, True,  GRP_NONE, CPU_8086);
  SetOp($01+I*8, AluNames[I], OT_RM16, OT_REG16, OT_NONE, True,  GRP_NONE, CPU_8086);
  SetOp($02+I*8, AluNames[I], OT_REG8, OT_RM8,   OT_NONE, True,  GRP_NONE, CPU_8086);
  SetOp($03+I*8, AluNames[I], OT_REG16,OT_RM16,  OT_NONE, True,  GRP_NONE, CPU_8086);
  SetOp($04+I*8, AluNames[I], OT_AL,   OT_IMM8,  OT_NONE, False, GRP_NONE, CPU_8086);
  SetOp($05+I*8, AluNames[I], OT_AX,   OT_IMM16, OT_NONE, False, GRP_NONE, CPU_8086);
 End;
 SetOp($06,'PUSH',OT_ES,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($07,'POP', OT_ES,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($0E,'PUSH',OT_CS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($16,'PUSH',OT_SS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($17,'POP', OT_SS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($1E,'PUSH',OT_DS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($1F,'POP', OT_DS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($27,'DAA',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($2F,'DAS',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($37,'AAA',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($3F,'AAS',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);

 { ---- Prefixes de segment : traites specialement dans le decodeur, mais
   une entree existe ici pour /BYTES et la detection de longueur. }
 SetOp($26,'ES:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($2E,'CS:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($36,'SS:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($3E,'DS:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($64,'FS:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 SetOp($65,'GS:',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 SetOp($66,'OPSIZE',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 SetOp($67,'ADDRSIZE',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 SetOp($F0,'LOCK',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F2,'REPNE',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F3,'REP',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);

 { ---- 40h-5Fh : INC/DEC/PUSH/POP r16 (registre code dans l'opcode) ---- }
 For I := 0 To 7 Do Begin
  SetOp($40+I,'INC', OT_REGOP,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
  SetOp($48+I,'DEC', OT_REGOP,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
  SetOp($50+I,'PUSH',OT_REGOP,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
  SetOp($58+I,'POP', OT_REGOP,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 End;

 SetOp($60,'PUSHA',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($61,'POPA', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($62,'BOUND',OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_186);
 SetOp($63,'ARPL', OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_286);
 SetOp($68,'PUSH', OT_IMM16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($69,'IMUL', OT_REG16,OT_RM16,OT_IMM16,True,GRP_NONE,CPU_186);
 SetOp($6A,'PUSH', OT_IMM8S,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($6B,'IMUL', OT_REG16,OT_RM16,OT_IMM8S,True,GRP_NONE,CPU_186);
 SetOp($6C,'INSB', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($6D,'INSW', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($6E,'OUTSB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($6F,'OUTSW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);

 { ---- 70h-7Fh : Jcc rel8 ---- }
 For I := 0 To 15 Do
  SetOp($70+I,'J'+CondNames[I],OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);

 SetOp($80,'GRP1',OT_RM8, OT_IMM8, OT_NONE,True,GRP_1,CPU_8086);
 SetOp($81,'GRP1',OT_RM16,OT_IMM16,OT_NONE,True,GRP_1,CPU_8086);
 SetOp($82,'GRP1',OT_RM8, OT_IMM8, OT_NONE,True,GRP_1,CPU_8086);
 SetOp($83,'GRP1',OT_RM16,OT_IMM8S,OT_NONE,True,GRP_1,CPU_8086);
 SetOp($84,'TEST',OT_RM8,OT_REG8,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($85,'TEST',OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($86,'XCHG',OT_REG8,OT_RM8,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($87,'XCHG',OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($88,'MOV', OT_RM8,OT_REG8,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($89,'MOV', OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8A,'MOV', OT_REG8,OT_RM8,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8B,'MOV', OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8C,'MOV', OT_RM16,OT_SREGF,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8D,'LEA', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8E,'MOV', OT_SREGF,OT_RM16,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($8F,'POP', OT_RM16,OT_NONE,OT_NONE,True,GRP_8F,CPU_8086);
 SetOp($90,'NOP', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 For I := 1 To 7 Do
  SetOp($90+I,'XCHG',OT_AX,OT_REGOP,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($98,'CBW', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($99,'CWD', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9A,'CALL',OT_FARPTR,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9B,'WAIT',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9C,'PUSHF',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9D,'POPF', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9E,'SAHF', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($9F,'LAHF', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A0,'MOV',OT_AL,OT_MOFFS8, OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A1,'MOV',OT_AX,OT_MOFFS16,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A2,'MOV',OT_MOFFS8, OT_AL,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A3,'MOV',OT_MOFFS16,OT_AX,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A4,'MOVSB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A5,'MOVSW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A6,'CMPSB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A7,'CMPSW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A8,'TEST',OT_AL,OT_IMM8, OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($A9,'TEST',OT_AX,OT_IMM16,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AA,'STOSB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AB,'STOSW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AC,'LODSB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AD,'LODSW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AE,'SCASB',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($AF,'SCASW',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 For I := 0 To 7 Do Begin
  SetOp($B0+I,'MOV',OT_REGOP8,OT_IMM8, OT_NONE,False,GRP_NONE,CPU_8086);
  SetOp($B8+I,'MOV',OT_REGOP,OT_IMM16,OT_NONE,False,GRP_NONE,CPU_8086);
 End;
 SetOp($C0,'GRP2',OT_RM8, OT_IMM8,OT_NONE,True,GRP_2,CPU_186);
 SetOp($C1,'GRP2',OT_RM16,OT_IMM8,OT_NONE,True,GRP_2,CPU_186);
 SetOp($C2,'RETN',OT_IMM16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($C3,'RETN',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($C4,'LES', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($C5,'LDS', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_8086);
 SetOp($C6,'MOV', OT_RM8, OT_IMM8, OT_NONE,True,GRP_C6,CPU_8086);
 SetOp($C7,'MOV', OT_RM16,OT_IMM16,OT_NONE,True,GRP_C7,CPU_8086);
 SetOp($C8,'ENTER',OT_IMM16,OT_IMM8,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($C9,'LEAVE',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_186);
 SetOp($CA,'RETF', OT_IMM16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($CB,'RETF', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($CC,'INT',  OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086); { INT 3, traite a part }
 SetOp($CD,'INT',  OT_IMM8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($CE,'INTO', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($CF,'IRET', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($D0,'GRP2', OT_RM8, OT_ONE,OT_NONE,True,GRP_2,CPU_8086);
 SetOp($D1,'GRP2', OT_RM16,OT_ONE,OT_NONE,True,GRP_2,CPU_8086);
 SetOp($D2,'GRP2', OT_RM8, OT_CL, OT_NONE,True,GRP_2,CPU_8086);
 SetOp($D3,'GRP2', OT_RM16,OT_CL, OT_NONE,True,GRP_2,CPU_8086);
 SetOp($D4,'AAM',  OT_IMM8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($D5,'AAD',  OT_IMM8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($D6,'SALC', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($D7,'XLAT', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 For I := $D8 To $DF Do
  SetOp(I,'ESC',OT_RM8,OT_NONE,OT_NONE,True,GRP_NONE,CPU_8086); { x87, generique }
 SetOp($E0,'LOOPNE',OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E1,'LOOPE', OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E2,'LOOP',  OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E3,'JCXZ',  OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E4,'IN', OT_AL,OT_IMM8,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E5,'IN', OT_AX,OT_IMM8,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E6,'OUT',OT_IMM8,OT_AL,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E7,'OUT',OT_IMM8,OT_AX,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E8,'CALL',OT_REL16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($E9,'JMP', OT_REL16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($EA,'JMP', OT_FARPTR,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($EB,'JMP', OT_REL8,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($EC,'IN', OT_AL,OT_DX,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($ED,'IN', OT_AX,OT_DX,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($EE,'OUT',OT_DX,OT_AL,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($EF,'OUT',OT_DX,OT_AX,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F4,'HLT',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F5,'CMC',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F6,'GRP3',OT_RM8, OT_NONE,OT_NONE,True,GRP_3,CPU_8086);
 SetOp($F7,'GRP3',OT_RM16,OT_NONE,OT_NONE,True,GRP_3,CPU_8086);
 SetOp($F8,'CLC',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($F9,'STC',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($FA,'CLI',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($FB,'STI',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($FC,'CLD',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($FD,'STD',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_8086);
 SetOp($FE,'GRP4',OT_RM8, OT_NONE,OT_NONE,True,GRP_4,CPU_8086);
 SetOp($FF,'GRP5',OT_RM16,OT_NONE,OT_NONE,True,GRP_5,CPU_8086);

 { ============================================================
   TABLE D'ECHAPPEMENT 0Fh (286+/386+)
   ============================================================ }
 Set0F($00,'GRP6',OT_RM16,OT_NONE,OT_NONE,True,GRP_6,CPU_286);
 Set0F($01,'GRP7',OT_RM16,OT_NONE,OT_NONE,True,GRP_7,CPU_286);
 Set0F($02,'LAR', OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_286);
 Set0F($03,'LSL', OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_286);
 Set0F($06,'CLTS',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_286);
 Set0F($08,'INVD',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($09,'WBINVD',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($0B,'UD2', OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($20,'MOV', OT_REG32,OT_CREG,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($21,'MOV', OT_REG32,OT_DREG,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($22,'MOV', OT_CREG,OT_REG32,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($23,'MOV', OT_DREG,OT_REG32,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($24,'MOV', OT_REG32,OT_TREG,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($26,'MOV', OT_TREG,OT_REG32,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($30,'WRMSR',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($31,'RDTSC',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($32,'RDMSR',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($33,'RDPMC',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 For I := 0 To 15 Do Begin
  Set0F($80+I,'J'+CondNames[I],  OT_REL16,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
  Set0F($90+I,'SET'+CondNames[I],OT_RM8,  OT_NONE,OT_NONE,True, GRP_NONE,CPU_386);
 End;
 Set0F($A0,'PUSH',OT_FS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 Set0F($A1,'POP', OT_FS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 Set0F($A2,'CPUID',OT_NONE,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
 Set0F($A3,'BT',  OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($A4,'SHLD',OT_RM16,OT_REG16,OT_IMM8,True,GRP_NONE,CPU_386);
 Set0F($A5,'SHLD',OT_RM16,OT_REG16,OT_CL,  True,GRP_NONE,CPU_386);
 Set0F($A8,'PUSH',OT_GS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 Set0F($A9,'POP', OT_GS,OT_NONE,OT_NONE,False,GRP_NONE,CPU_386);
 Set0F($AB,'BTS', OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($AC,'SHRD',OT_RM16,OT_REG16,OT_IMM8,True,GRP_NONE,CPU_386);
 Set0F($AD,'SHRD',OT_RM16,OT_REG16,OT_CL,  True,GRP_NONE,CPU_386);
 Set0F($AF,'IMUL',OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B0,'CMPXCHG',OT_RM8, OT_REG8, OT_NONE,True,GRP_NONE,CPU_486);
 Set0F($B1,'CMPXCHG',OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_486);
 Set0F($B2,'LSS', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B3,'BTR', OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B4,'LFS', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B5,'LGS', OT_REG16,OT_MEM,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B6,'MOVZX',OT_REG16,OT_RM8, OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($B7,'MOVZX',OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($BA,'GRP8',OT_RM16,OT_IMM8,OT_NONE,True,GRP_8,CPU_386);
 Set0F($BB,'BTC', OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($BC,'BSF', OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($BD,'BSR', OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($BE,'MOVSX',OT_REG16,OT_RM8, OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($BF,'MOVSX',OT_REG16,OT_RM16,OT_NONE,True,GRP_NONE,CPU_386);
 Set0F($C0,'XADD',OT_RM8, OT_REG8, OT_NONE,True,GRP_NONE,CPU_486);
 Set0F($C1,'XADD',OT_RM16,OT_REG16,OT_NONE,True,GRP_NONE,CPU_486);
 For I := 0 To 7 Do
  Set0F($C8+I,'BSWAP',OT_REGOP,OT_NONE,OT_NONE,False,GRP_NONE,CPU_486);
End;

{ ============================================================
  LECTURE DE L'IMAGE EN MEMOIRE
  ============================================================ }

Function LoadImageFile(FName: TString): Boolean;
Var F: File; BytesRead: LongInt; Sz: LongInt;
Begin
 LoadImageFile := False;
 {$I-}
 Assign(F, FName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir ', FName);
  Exit;
 End;
 Sz := FileSize(F);
 If Sz > MAX_IMAGE_SIZE Then Sz := MAX_IMAGE_SIZE;
 GetMem(Image, MAX_IMAGE_SIZE);
 GetMem(ByteFlags, MAX_IMAGE_SIZE);
 FillChar(ByteFlags^, MAX_IMAGE_SIZE, BF_UNKNOWN);
 {$I-}
 BlockRead(F, Image^, Sz, BytesRead);
 {$I+}
 Close(F);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur de lecture : ', FName);
  Exit;
 End;
 ImageSize := BytesRead;
 LoadImageFile := True;
End;

{ ============================================================
  ACCES AUX OCTETS DE L'IMAGE (coordonnees = decalage fichier, 0 base)
  ============================================================ }

Function InBounds(Ofs: LongInt): Boolean;
Begin
 InBounds := (Ofs >= 0) And (Ofs < ImageSize);
End;

Function GetByte(Ofs: LongInt): Byte;
Begin
 If InBounds(Ofs) Then GetByte := Image^[Ofs]
 Else GetByte := 0;
End;

Function GetWordAt(Ofs: LongInt): Word;
Begin
 GetWordAt := Word(GetByte(Ofs)) Or (Word(GetByte(Ofs+1)) Shl 8);
End;

Function GetLongAt(Ofs: LongInt): LongInt;
Begin
 GetLongAt := LongInt(GetWordAt(Ofs)) Or (LongInt(GetWordAt(Ofs+2)) Shl 16);
End;

{ Conversion entre adresse AFFICHEE (ORG-relative) et decalage fichier. }
Function AddrToOfs(Addr: LongInt): LongInt;
Begin
 AddrToOfs := Addr - OptOrg;
End;

Function OfsToAddr(Ofs: LongInt): LongInt;
Begin
 OfsToAddr := Ofs + OptOrg;
End;

{ ============================================================
  BLOCS DE SEGMENTS MULTIPLES (voir TSegBlock / /SEG:xxxx=fichier.bin)
  ============================================================ }

{ Rend le bloc 0 (le fichier /O, deja charge dans Image/ByteFlags/ImageSize
  par LoadImageFile et eventuellement ajuste par SetupFormatAndEntries -
  decoupe d'en-tete MZ, ORG par defaut selon le format, etc.) visible dans
  SegBlocks, pour que le moteur recursif puisse y revenir apres avoir
  bascule sur un autre bloc. A appeler UNE SEULE FOIS, juste apres
  SetupFormatAndEntries. }
Procedure RegisterBlock0;
Begin
 SegBlocks[0].RealSeg   := OptSeg;
 SegBlocks[0].BlkOrg    := OptOrg;
 SegBlocks[0].BlkHasSeg := OptHasSeg;
 SegBlocks[0].FileName  := InputFileName;
 SegBlocks[0].Image     := Image;
 SegBlocks[0].ByteFlags := ByteFlags;
 SegBlocks[0].ImageSize := ImageSize;
 SegBlocks[0].Loaded    := True;
 SegBlockCnt := 1;
 CurBlk := 0;
End;

{ Charge un bloc SUPPLEMENTAIRE (/SEG:xxxx=fichier.bin) : toujours un dump
  de segment reel complet (ORG=0, segment affiche = RealSeg fourni), avec sa
  PROPRE image/carte d'octets independantes du bloc 0. }
Function LoadExtraSegBlock(RealSeg: Word; FName: TString): Boolean;
Var F: File; BytesRead: LongInt; Sz: LongInt; Idx: Integer;
Begin
 LoadExtraSegBlock := False;
 If SegBlockCnt >= MAX_SEGBLOCKS Then Begin
  WriteLn('Avertissement : limite de ', MAX_SEGBLOCKS, ' blocs de segments atteinte, ', FName, ' ignore.');
  Exit;
 End;
 {$I-}
 Assign(F, FName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir ', FName, ' (/SEG:', HexWord(RealSeg), '=...)');
  Exit;
 End;
 Sz := FileSize(F);
 If Sz > MAX_SEG_SIZE Then Sz := MAX_SEG_SIZE;
 Idx := SegBlockCnt;
 GetMem(SegBlocks[Idx].Image, MAX_SEG_SIZE);
 GetMem(SegBlocks[Idx].ByteFlags, MAX_SEG_SIZE);
 FillChar(SegBlocks[Idx].ByteFlags^, MAX_SEG_SIZE, BF_UNKNOWN);
 {$I-}
 BlockRead(F, SegBlocks[Idx].Image^, Sz, BytesRead);
 {$I+}
 Close(F);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur de lecture : ', FName);
  Exit;
 End;
 SegBlocks[Idx].RealSeg   := RealSeg;
 SegBlocks[Idx].BlkOrg    := 0;
 SegBlocks[Idx].BlkHasSeg := True;
 SegBlocks[Idx].FileName  := FName;
 SegBlocks[Idx].ImageSize := BytesRead;
 SegBlocks[Idx].Loaded    := True;
 Inc(SegBlockCnt);
 LoadExtraSegBlock := True;
End;

{ Cherche un bloc CHARGE dont le segment DOS reel correspond - c'est ce qui
  permet a un CALL/JMP FAR direct (ou une sonde /FARPTR) de "traverser" vers
  un autre bloc deja charge. -1 si aucun bloc ne correspond (segment non
  charge - le moteur ne peut pas suivre plus loin, comme avant /SEG). }
Function FindBlockBySeg(Seg: Word): Integer;
Var I: Integer;
Begin
 FindBlockBySeg := -1;
 For I := 0 To SegBlockCnt-1 Do
  If SegBlocks[I].Loaded And (SegBlocks[I].RealSeg = Seg) Then Begin
   FindBlockBySeg := I;
   Exit;
  End;
End;

{ Rend un bloc "actif" : toutes les fonctions existantes (GetByte/InBounds/
  AddrToOfs/OfsToAddr/DecodeModRM/DecodeOne/...) continuent a lire les
  globales Image/ByteFlags/ImageSize/OptOrg/OptSeg/OptHasSeg SANS AUCUN
  changement - c'est ce qui evite de devoir reecrire tout le decodeur pour
  le rendre "multi-bloc" : on bascule simplement CE SUR QUOI il travaille. }
Procedure SwitchBlock(B: Integer);
Begin
 If (B < 0) Or (B >= SegBlockCnt) Then Exit;
 CurBlk    := B;
 Image     := SegBlocks[B].Image;
 ByteFlags := SegBlocks[B].ByteFlags;
 ImageSize := SegBlocks[B].ImageSize;
 OptOrg    := SegBlocks[B].BlkOrg;
 OptSeg    := SegBlocks[B].RealSeg;
 OptHasSeg := SegBlocks[B].BlkHasSeg;
End;

{ IMPORTANT : si Blk est le bloc ACTUELLEMENT ACTIF (CurBlk), on consulte les
  globales "en cours" (ImageSize/OptOrg) plutot que SegBlocks[Blk] - c'est ce
  qui permet a SetupFormatAndEntries (bloc 0, AVANT que RegisterBlock0 n'ait
  pu etre appele puisqu'il doit capturer l'etat FINAL apres ajustements
  ORG/ImageSize specifiques au format) d'utiliser QueuePush(0,...)/
  AddSymbol(0,...) exactement comme avant - sans ce garde-fou, SegBlocks[0]
  ne serait pas encore rempli a ce moment precis et toute verification de
  bornes echouerait silencieusement (bogue reel trouve et corrige en testant
  cette fonctionnalite : "Instructions decodees : 0" alors qu'un point
  d'entree pourtant valide venait d'etre mis en file). }
Function InBoundsBlk(Blk: Integer; Ofs: LongInt): Boolean;
Begin
 If Blk = CurBlk Then Begin
  InBoundsBlk := InBounds(Ofs);
  Exit;
 End;
 InBoundsBlk := (Blk >= 0) And (Blk < SegBlockCnt) And
                (Ofs >= 0) And (Ofs < SegBlocks[Blk].ImageSize);
End;

Function AddrToOfsBlk(Blk: Integer; Addr: LongInt): LongInt;
Begin
 If Blk = CurBlk Then Begin
  AddrToOfsBlk := AddrToOfs(Addr);
  Exit;
 End;
 If (Blk < 0) Or (Blk >= SegBlockCnt) Then AddrToOfsBlk := Addr
 Else AddrToOfsBlk := Addr - SegBlocks[Blk].BlkOrg;
End;

Function OfsToAddrBlk(Blk: Integer; Ofs: LongInt): LongInt;
Begin
 If Blk = CurBlk Then Begin
  OfsToAddrBlk := OfsToAddr(Ofs);
  Exit;
 End;
 If (Blk < 0) Or (Blk >= SegBlockCnt) Then OfsToAddrBlk := Ofs
 Else OfsToAddrBlk := Ofs + SegBlocks[Blk].BlkOrg;
End;

{ Lecture d'un octet dans un bloc donne SANS le rendre actif - utilise par
  les passes qui parcourent Decoded[] apres coup (ex: ScanMcbPatterns), ou
  chaque entree peut appartenir a un bloc different de celui actuellement
  actif. }
Function GetByteBlk(Blk: Integer; Ofs: LongInt): Byte;
Begin
 If Blk = CurBlk Then Begin
  GetByteBlk := GetByte(Ofs);
  Exit;
 End;
 If InBoundsBlk(Blk, Ofs) Then GetByteBlk := SegBlocks[Blk].Image^[Ofs]
 Else GetByteBlk := 0;
End;

Function GetWordAtBlk(Blk: Integer; Ofs: LongInt): Word;
Begin
 GetWordAtBlk := Word(GetByteBlk(Blk, Ofs)) Or (Word(GetByteBlk(Blk, Ofs+1)) Shl 8);
End;

{ ============================================================
  TABLE DE SYMBOLES
  ============================================================ }

Function FindSymbol(Blk: Integer; Addr: LongInt): LongInt;
Var I: LongInt;
Begin
 FindSymbol := -1;
 For I := 0 To SymbolCnt-1 Do
  If (Symbols[I].Blk = Blk) And (Symbols[I].Addr = Addr) Then Begin
   FindSymbol := I;
   Exit;
  End;
End;

Procedure AddSymbol(Blk: Integer; Addr: LongInt; Kind: Byte; Nm: TString);
Var Idx: LongInt;
Begin
 Idx := FindSymbol(Blk, Addr);
 If Idx >= 0 Then Begin
  { Un symbole deja reconnu structurellement (Device Header/Strategy/...)
    a priorite sur un simple sub_/loc_ auto-genere. }
  If (Symbols[Idx].Kind in [SYM_SUB, SYM_LOC, SYM_DATA]) And
     (Kind In [SYM_DEVHDR, SYM_STRAT, SYM_INTR, SYM_ENTRY, SYM_USER]) Then Begin
   Symbols[Idx].Kind := Kind;
   Symbols[Idx].Name := Nm;
  End;
  Exit;
 End;
 If SymbolCnt >= MAX_SYMBOLS Then Exit;
 Symbols[SymbolCnt].Blk  := Blk;
 Symbols[SymbolCnt].Addr := Addr;
 Symbols[SymbolCnt].Kind := Kind;
 Symbols[SymbolCnt].Name := Nm;
 Inc(SymbolCnt);
End;

{ Qualifie le nom par le segment du bloc des qu'il y a PLUS D'UN bloc charge
  (/SEG:xxxx=fichier.bin) - sinon un "sub_94C8h" du bloc 9078h et un
  "sub_94C8h" d'un autre bloc charge au MEME decalage local seraient
  indiscernables dans un listing qui les melange tous. En mode mono-bloc
  (l'usage historique), le nom reste EXACTEMENT comme avant. }
Function AutoSymbolName(Blk: Integer; Addr: LongInt; Kind: Byte): TString;
Var Prefix, SegPfx: TString;
Begin
 Case Kind Of
  SYM_SUB:    Prefix := 'sub_';
  SYM_LOC:    Prefix := 'loc_';
  SYM_DATA:   Prefix := 'data_';
  SYM_DEVHDR: Prefix := 'DeviceHeader_';
  SYM_STRAT:  Prefix := 'Strategy_';
  SYM_INTR:   Prefix := 'Interrupt_';
  SYM_ENTRY:  Prefix := 'Entry_';
 Else
  Prefix := 'lbl_';
 End;
 SegPfx := '';
 If (SegBlockCnt > 1) And (Blk >= 0) And (Blk < SegBlockCnt) Then Begin
  SegPfx := HexWord(SegBlocks[Blk].RealSeg);
  Delete(SegPfx, Length(SegPfx), 1);  { retire le 'h' final de HexWord }
  SegPfx := SegPfx + '_';
 End;
 AutoSymbolName := Prefix + SegPfx + HexWord(Word(Addr));
End;

Function SymbolNameAt(Blk: Integer; Addr: LongInt): TString;
Var Idx: LongInt;
Begin
 Idx := FindSymbol(Blk, Addr);
 If Idx >= 0 Then SymbolNameAt := Symbols[Idx].Name
 Else SymbolNameAt := '';
End;

{ Renvoie un texte utilisable comme operande pour une adresse cible :
  le nom symbolique s'il existe et que /SYMBOLS est actif, sinon l'adresse
  hexadecimale brute. }
Function LabelOrAddr(Blk: Integer; Addr: LongInt): TString;
Var Nm: TString;
Begin
 If OptSymbols Then Begin
  Nm := SymbolNameAt(Blk, Addr);
  If Nm <> '' Then Begin
   LabelOrAddr := Nm;
   Exit;
  End;
 End;
 LabelOrAddr := HexWord(Word(Addr));
End;

Procedure AddXRef(FromBlk: Integer; FromA: LongInt; ToBlk: Integer; ToA: LongInt; IsCall: Boolean);
Begin
 If XRefCnt >= MAX_XREFS Then Exit;
 XRefs[XRefCnt].FromBlk  := FromBlk;
 XRefs[XRefCnt].FromAddr := FromA;
 XRefs[XRefCnt].ToBlk    := ToBlk;
 XRefs[XRefCnt].ToAddr   := ToA;
 XRefs[XRefCnt].IsCall   := IsCall;
 Inc(XRefCnt);
End;

{ ============================================================
  FILE D'ATTENTE DE TRAVAIL (MOTEUR RECURSIF)
  ============================================================ }

Procedure QueuePush(Blk: Integer; Addr: LongInt);
Begin
 If Not InBoundsBlk(Blk, AddrToOfsBlk(Blk, Addr)) Then Exit;
 If WorkQueueCnt >= MAX_WORKQUEUE Then Exit;
 WorkQueue[WorkQueueCnt].Blk  := Blk;
 WorkQueue[WorkQueueCnt].Addr := Addr;
 Inc(WorkQueueCnt);
End;

{ ============================================================
  DECODAGE DU MODRM (16 BITS - adressage reel x86, le seul pertinent
  pour du code de noyau/pilote DOS reel-mode)
  ============================================================ }

Type
 TDecodedOperand = Record
  Text    : TString;    { texte final de l'operande, pret a afficher }
  IsMem   : Boolean;
  MemAddr : LongInt;     { adresse memoire directe si IsMem et adressage direct, -1 sinon }
 End;

Var
 { Etat de decodage de l'instruction courante, repopule a chaque instruction }
 CurOfs      : LongInt;   { decalage de l'octet d'opcode (avant prefixes consommes) }
 CurPos      : LongInt;   { curseur de lecture courant }
 CurSeg      : TString;   { prefixe de segment textuel ('' si aucun) }
 CurHasSeg   : Boolean;
 CurRepPfx   : TString;   { 'LOCK '/'REP '/'REPNE '/'' }
 CurOpSize32 : Boolean;   { prefixe 66h present }
 ModRMByte   : Byte;
 ModRMMod    : Byte;
 ModRMReg    : Byte;
 ModRMRm     : Byte;

Function DecodeModRM: TDecodedOperand;
Var D: TDecodedOperand; Disp8: ShortInt; Disp16: Integer;
Begin
 ModRMByte := GetByte(CurPos);
 Inc(CurPos);
 ModRMMod := (ModRMByte Shr 6) And 3;
 ModRMReg := (ModRMByte Shr 3) And 7;
 ModRMRm  := ModRMByte And 7;
 D.IsMem := False;
 D.MemAddr := -1;
 If ModRMMod = 3 Then Begin
  D.Text := '#REG#';  { le mode registre direct est resolu par l'appelant
                          selon la taille d'operande demandee (8/16/32 bits) }
  DecodeModRM := D;
  Exit;
 End;
 D.IsMem := True;
 If (ModRMMod = 0) And (ModRMRm = 6) Then Begin
  { cas special : adresse directe 16 bits, pas de registre de base }
  Disp16 := Integer(GetWordAt(CurPos));
  CurPos := CurPos + 2;
  D.MemAddr := LongInt(Word(Disp16));
  D.Text := '[' + HexWord(Word(Disp16)) + ']';
  DecodeModRM := D;
  Exit;
 End;
 D.Text := '[' + RM16Base[ModRMRm];
 Case ModRMMod Of
  1: Begin
      Disp8 := ShortInt(GetByte(CurPos));
      Inc(CurPos);
      If Disp8 > 0 Then D.Text := D.Text + '+' + HexByte(Byte(Disp8))
      Else If Disp8 < 0 Then D.Text := D.Text + '-' + HexByte(Byte(-Disp8));
     End;
  2: Begin
      Disp16 := Integer(GetWordAt(CurPos));
      CurPos := CurPos + 2;
      If Disp16 > 0 Then D.Text := D.Text + '+' + HexWord(Word(Disp16))
      Else If Disp16 < 0 Then D.Text := D.Text + '-' + HexWord(Word(-Disp16));
     End;
 End;
 D.Text := D.Text + ']';
 DecodeModRM := D;
End;

{ Applique le prefixe de segment memorise (si present) juste avant le
  premier '[' d'un operande memoire deja construit. }
Function InjectSeg(S: TString): TString;
Var P: Integer;
Begin
 If Not CurHasSeg Then Begin
  InjectSeg := S;
  Exit;
 End;
 P := Pos('[', S);
 If P = 0 Then InjectSeg := S
 Else InjectSeg := Copy(S, 1, P-1) + CurSeg + Copy(S, P, Length(S)-P+1);
End;

{ ============================================================
  FORMATAGE D'UN OPERANDE SELON SON TYPE OT_xxx
  ============================================================ }

Function FmtOperand(OType: Byte; RegField: Byte; RmDecoded: TDecodedOperand;
 UseRm: Boolean; OpCodeForRegOp: Byte; ImmByte: Byte; ImmWord: Word;
 FarSeg: Word; FarOfs: Word): TString;
Var S: TString;
Begin
 S := '';
 Case OType Of
  OT_REG8:  S := Reg8Names[RegField];
  OT_REG16: If CurOpSize32 Then S := Reg32Names[RegField] Else S := Reg16Names[RegField];
  OT_REG32: S := Reg32Names[RegField];
  OT_SEG:   S := SegNames[RegField];
  OT_SREGF: S := SegNames[RegField And 3];
  OT_CREG:  S := CRegNames[RegField];
  OT_DREG:  S := DRegNames[RegField];
  OT_TREG:  S := TRegNames[RegField];
  OT_REGOP: If CurOpSize32 Then S := Reg32Names[OpCodeForRegOp And 7]
            Else S := Reg16Names[OpCodeForRegOp And 7];
  OT_REGOP8: S := Reg8Names[OpCodeForRegOp And 7];
  OT_RM8:   If UseRm Then Begin
             If RmDecoded.IsMem Then S := 'Byte Ptr ' + InjectSeg(RmDecoded.Text)
             Else S := Reg8Names[ModRMRm];
            End;
  OT_RM16:  If UseRm Then Begin
             If RmDecoded.IsMem Then Begin
              If CurOpSize32 Then S := 'DWord Ptr ' + InjectSeg(RmDecoded.Text)
              Else S := 'Word Ptr ' + InjectSeg(RmDecoded.Text);
             End Else Begin
              If CurOpSize32 Then S := Reg32Names[ModRMRm] Else S := Reg16Names[ModRMRm];
             End;
            End;
  OT_MEM:   If UseRm Then S := InjectSeg(RmDecoded.Text);
  OT_IMM8:  S := HexByte(ImmByte);
  OT_IMM8S: S := HexWord(ImmWord);  { deja etendu en signe par l'appelant }
  OT_IMM16: S := HexWord(ImmWord);
  { Les cibles de branchement direct ne sont PAS resolues ici : tous les
    symboles ne sont pas encore connus pendant le decodage (le moteur
    recursif peut rencontrer une reference AVANT la cible elle-meme). Un
    marqueur est emis et remplace par WriteOneInstruction une fois TOUS les
    symboles connus - evite les etiquettes "en avance" affichees en
    hexadecimal brut alors qu'un nom symbolique existe bel et bien plus
    loin dans le meme listing. }
  OT_REL8:  S := '@BT' + HexWord(ImmWord) + '@';
  OT_REL16: S := '@BT' + HexWord(ImmWord) + '@';
  { Marqueur FAR distinct ("@BTF...@") : un CALL/JMP FAR direct peut cibler
    un AUTRE bloc de segment charge (/SEG:xxxx=fichier.bin) - resolu plus
    tard par ResolveBranchMarkers, une fois tous les symboles connus,
    exactement comme @BT pour les branchements proches. }
  OT_FARPTR:S := '@BTF' + HexWord(FarSeg) + ':' + HexWord(FarOfs) + '@';
  OT_MOFFS8, OT_MOFFS16: S := InjectSeg('[' + HexWord(ImmWord) + ']');
  OT_AL: S := 'AL'; OT_AX: S := 'AX'; OT_CL: S := 'CL';
  OT_DX: S := 'DX'; OT_ONE: S := '1';
  OT_CS: S := 'CS'; OT_DS: S := 'DS'; OT_ES: S := 'ES'; OT_SS: S := 'SS';
  OT_FS: S := 'FS'; OT_GS: S := 'GS';
 End;
 FmtOperand := S;
End;

{ ============================================================
  ANNOTATION DES FONCTIONS DOS/BIOS CONNUES (/INT, /API)
  ============================================================ }

{ Cherche en arriere, a partir de l'octet d'opcode de l'INT lui-meme, la
  derniere valeur immediate chargee dans AH (ou AX) par une sequence
  "MOV AH,imm8" (B4 xx) ou "MOV AX,imm16" (B8 xx xx) sans instruction
  modifiant AH entre-temps - heuristique volontairement simple mais tres
  efficace sur du code reel (la convention d'appel DOS charge toujours
  AH/AX juste avant l'INT). }
Function FindAhBeforeInt(IntOfs: LongInt; Var Ah, Al: Integer): Boolean;
Var P: LongInt; Limit: LongInt; B: Byte;
Begin
 FindAhBeforeInt := False;
 Ah := -1; Al := -1;
 P := IntOfs - 1;
 Limit := IntOfs - 16;
 If Limit < 0 Then Limit := 0;
 While P >= Limit Do Begin
  B := GetByte(P);
  If B = $B4 Then Begin { MOV AH,imm8 }
   Ah := GetByte(P+1);
   FindAhBeforeInt := True;
   Exit;
  End;
  If B = $B8 Then Begin { MOV AX,imm16 }
   Ah := GetByte(P+2);
   Al := GetByte(P+1);
   FindAhBeforeInt := True;
   Exit;
  End;
  Dec(P);
 End;
End;

{ Vrai si AUCUN des commutateurs de categorie focalisee (/XMS /EMS /BIOS
  /DOSAPI /DPB /SFT /INDOS) n'est actif (dans ce cas /INT et /API montrent
  tout sans filtrage), OU si la categorie demandee correspond reellement a
  cette paire IntNum/AhVal - permet a chaque commutateur d'etre a la fois
  autonome et restrictif, comme demande ("tres flexible"). }
Function CategoryEnabled(IntNum: Byte; Ah: Integer): Boolean;
Var AnyCategory: Boolean;
Begin
 AnyCategory := OptXms Or OptEms Or OptBios Or OptDosApi Or OptDpb Or OptSft Or OptIndos;
 If Not AnyCategory Then Begin
  CategoryEnabled := True;
  Exit;
 End;
 CategoryEnabled := False;
 If OptXms And (IntNum = $2F) And (Ah = $43) Then CategoryEnabled := True;
 If OptEms And (IntNum = $2F) And (Ah = $46) Then CategoryEnabled := True;
 If OptBios And ((IntNum = $10) Or (IntNum = $13) Or (IntNum = $15) Or (IntNum = $1A)) Then
  CategoryEnabled := True;
 If OptDosApi And ((IntNum = $20) Or (IntNum = $21) Or (IntNum = $25) Or
    (IntNum = $26) Or (IntNum = $27) Or (IntNum = $2F)) Then CategoryEnabled := True;
 If OptDpb And (IntNum = $21) And (Ah = $32) Then CategoryEnabled := True;
 If OptSft And (IntNum = $21) And (Ah = $52) Then CategoryEnabled := True;
 If OptIndos And (IntNum = $21) And (Ah = $34) Then CategoryEnabled := True;
End;

Function DescribeInterrupt(IntNum: Byte; IntOfs: LongInt): TString;
Var I: Integer; Ah, Al: Integer; Best: TString; BestSpecific: Boolean;
Begin
 Best := ''; BestSpecific := False;
 If Not FindAhBeforeInt(IntOfs, Ah, Al) Then Ah := -1;
 If Not CategoryEnabled(IntNum, Ah) Then Begin
  DescribeInterrupt := '';
  Exit;
 End;
 For I := 0 To API_COUNT-1 Do
  If (ApiTable[I].IntNum = IntNum) And
     (ApiTable[I].MinDos <= (Word(OptDosVerMajor)*100 + OptDosVerMinor)) Then Begin
   If (ApiTable[I].AhVal = -1) Then Begin
    If Best = '' Then Best := ApiTable[I].Descr;
   End Else If (Ah = ApiTable[I].AhVal) Then Begin
    If (ApiTable[I].AlVal = -1) Then Begin
     If Not BestSpecific Then Begin
      Best := 'AH=' + HexByte(Byte(Ah)) + ' : ' + ApiTable[I].Descr;
      BestSpecific := True;
     End;
    End Else If (Al = ApiTable[I].AlVal) Then Begin
     Best := 'AH=' + HexByte(Byte(Ah)) + ' AL=' + HexByte(Byte(Al)) + ' : ' + ApiTable[I].Descr;
     BestSpecific := True;
    End;
   End;
  End;
 If (Best = '') And (Ah >= 0) Then
  Best := 'AH=' + HexByte(Byte(Ah)) + ' (fonction non repertoriee)';
 DescribeInterrupt := Best;
End;

{ ============================================================
  RECONNAISSANCE DE L'EN-TETE DE PILOTE DOS (DEVICE HEADER)
  ============================================================ }

{ Un Device Header plausible doit avoir : un champ Name majoritairement
  imprimable (ou le 1er octet < 26 pour un pilote bloc = nombre d'unites),
  et des decalages Strategy/Interrupt qui tombent dans les limites du
  fichier. Heuristique volontairement tolerante (de nombreux vrais pilotes
  laissent NextOfs/NextSeg a FFFFh avant chargement par DOS). }
Function DetectDeviceHeader: Boolean;
Var I: Integer; NameOk: Boolean; B: Byte; FirstByte: Byte;
Begin
 DetectDeviceHeader := False;
 If ImageSize < 18 Then Exit;
 { BOGUE REEL CORRIGE (2026-10-03, trouve en testant DISSYS sur le VRAI
   MSDOS.SYS extrait d'un VHD) : un noyau DOS brut (MSDOS.SYS/IO.SYS)
   commence TOUJOURS par un simple "JMP" (E9h near ou EBh short) vers son
   vrai code, suivi de donnees - ces octets etaient auparavant INTERPRETES
   A TORT comme un Device Header "pilote bloc" plausible (le controle de
   nom imprimable ne s'applique qu'aux pilotes CARACTERE, bit 15 des
   attributs, donc ne protegeait pas ce cas), produisant un faux positif
   qui faisait prendre le JMP initial pour une partie de l'en-tete et
   arretait le desassemblage recursif en 3 instructions a peine. Un VRAI
   Device Header ne commence jamais par un JMP/CALL deliberement encode -
   exclusion explicite de cette signature, la plus fiable disponible sans
   decoder le fichier au prealable. }
 FirstByte := GetByte(0);
 If (FirstByte = $E9) Or (FirstByte = $EB) Or (FirstByte = $E8) Then Exit;
 DevHeader.NextOfs      := GetWordAt(0);
 DevHeader.NextSeg      := GetWordAt(2);
 DevHeader.Attributes   := GetWordAt(4);
 DevHeader.StrategyOfs  := GetWordAt(6);
 DevHeader.InterruptOfs := GetWordAt(8);
 For I := 0 To 7 Do DevHeader.Name[I] := GetByte(10+I);
 If (DevHeader.StrategyOfs >= ImageSize) Or (DevHeader.InterruptOfs >= ImageSize) Then Exit;
 If (DevHeader.StrategyOfs = 0) And (DevHeader.InterruptOfs = 0) Then Exit;
 { Un vrai pilote n'a jamais Strategy et Interrupt a la MEME adresse. }
 If DevHeader.StrategyOfs = DevHeader.InterruptOfs Then Exit;
 { Pilote caractere (bit 15 de Attributes) : Name doit etre imprimable. }
 If (DevHeader.Attributes And $8000) <> 0 Then Begin
  NameOk := True;
  For I := 0 To 7 Do Begin
   B := DevHeader.Name[I];
   If (B < 32) Or (B > 126) Then NameOk := False;
  End;
  If Not NameOk Then Exit;
 End Else Begin
  { Pilote bloc (bit 15 = 0) : aucun champ texte a verifier, donc seul
    signal fiable restant = NextOfs/NextSeg plausibles (soit non encore
    chaine - $FFFF/$FFFF - soit un segment reel non nul ; un noyau brut
    qui n'est PAS un pilote a des "octets de NextOfs/NextSeg" qui sont en
    realite le DEBUT de son code/ses donnees, rarement a la fois nuls). }
  If (DevHeader.NextOfs = 0) And (DevHeader.NextSeg = 0) Then Exit;
 End;
 DetectDeviceHeader := True;
End;

{ ============================================================
  DECODAGE D'UNE SEULE INSTRUCTION A L'ADRESSE AFFICHEE "Addr"
  Renvoie le texte de l'instruction complete (mnemonique + operandes),
  la longueur en octets, et indique s'il s'agit d'un branchement/appel
  dont la cible a ete resolue (BranchTarget, IsCall, IsUncondJmp,
  IsIndirect, IsRet).
  ============================================================ }

Procedure DecodeOne(Addr: LongInt; Var OutText: TString; Var Length_: LongInt;
 Var IsBranch, IsCall_, IsUncond, IsIndirect, IsRetInstr: Boolean;
 Var BranchTarget: LongInt; Var BranchBlock: Integer;
 Var IntNumber: Integer; Var OpMinCPU: Byte);
Var Ofs: LongInt; OpByte, Op2Byte, Imm8: Byte; Imm16: Word;
 Entry: TOpEntry; Rm: TDecodedOperand; RmUsed: Boolean;
 S, O1S, O2S, O3S: TString;
 Rel8: ShortInt; RelTarget: LongInt;
 FarSeg, FarOfs: Word;
 GroupReg: Byte;
 Mn: TString;
 Is0F: Boolean;
Begin
 Ofs := AddrToOfs(Addr);
 CurOfs := Ofs;
 CurPos := Ofs;
 CurSeg := ''; CurHasSeg := False;
 CurRepPfx := '';
 CurOpSize32 := False;
 IsBranch := False; IsCall_ := False; IsUncond := False; IsIndirect := False;
 IsRetInstr := False; BranchTarget := 0; IntNumber := -1;
 BranchBlock := CurBlk;  { toujours le bloc courant sauf CALL/JMP FAR direct resolu vers un autre bloc }
 RmUsed := False;

 { ---- Consommer les prefixes (segment/REP/LOCK/66h/67h) ---- }
 OpByte := GetByte(CurPos);
 While (OpByte = $26) Or (OpByte = $2E) Or (OpByte = $36) Or (OpByte = $3E) Or
       (OpByte = $64) Or (OpByte = $65) Or (OpByte = $66) Or (OpByte = $67) Or
       (OpByte = $F0) Or (OpByte = $F2) Or (OpByte = $F3) Do Begin
  Case OpByte Of
   $26: Begin CurSeg := 'ES:'; CurHasSeg := True; End;
   $2E: Begin CurSeg := 'CS:'; CurHasSeg := True; End;
   $36: Begin CurSeg := 'SS:'; CurHasSeg := True; End;
   $3E: Begin CurSeg := 'DS:'; CurHasSeg := True; End;
   $64: Begin CurSeg := 'FS:'; CurHasSeg := True; End;
   $65: Begin CurSeg := 'GS:'; CurHasSeg := True; End;
   $66: CurOpSize32 := True;
   $F0: CurRepPfx := 'LOCK ';
   $F2: CurRepPfx := 'REPNE ';
   $F3: CurRepPfx := 'REP ';
  End;
  Inc(CurPos);
  OpByte := GetByte(CurPos);
 End;

 Is0F := (OpByte = $0F);
 If Is0F Then Begin
  Inc(CurPos);
  Op2Byte := GetByte(CurPos);
  Entry := Op0FTable[Op2Byte];
  Inc(CurPos);
 End Else Begin
  Entry := OpTable[OpByte];
  Inc(CurPos);
 End;

 Mn := Entry.Mnemonic;

 { ---- Cas particuliers non table-driven : INT 3, Jcc courts, groupes ---- }
 If (Not Is0F) And (OpByte = $CC) Then Begin
  OutText := CurRepPfx + 'INT 3';
  IntNumber := 3;
  Length_ := CurPos - Ofs;
  Exit;
 End;

 If Entry.HasModRM Then Begin
  Rm := DecodeModRM;
  RmUsed := True;
 End;

 GroupReg := ModRMReg;

 { ---- Dispatch des groupes a extension (champ reg du ModRM) ---- }
 If Entry.Group = GRP_1 Then Begin
  Case GroupReg Of
   0: Mn:='ADD'; 1: Mn:='OR'; 2: Mn:='ADC'; 3: Mn:='SBB';
   4: Mn:='AND'; 5: Mn:='SUB'; 6: Mn:='XOR'; 7: Mn:='CMP';
  End;
 End Else If Entry.Group = GRP_2 Then Begin
  Case GroupReg Of
   0: Mn:='ROL'; 1: Mn:='ROR'; 2: Mn:='RCL'; 3: Mn:='RCR';
   4: Mn:='SHL'; 5: Mn:='SHR'; 6: Mn:='SAL'; 7: Mn:='SAR';
  End;
 End Else If Entry.Group = GRP_3 Then Begin
  Case GroupReg Of
   0,1: Begin Mn:='TEST'; Entry.Op2 := OT_IMM8; If OpByte=$F7 Then Entry.Op2:=OT_IMM16; End;
   2: Begin Mn:='NOT';  Entry.Op2 := OT_NONE; End;
   3: Begin Mn:='NEG';  Entry.Op2 := OT_NONE; End;
   4: Begin Mn:='MUL';  Entry.Op2 := OT_NONE; End;
   5: Begin Mn:='IMUL'; Entry.Op2 := OT_NONE; End;
   6: Begin Mn:='DIV';  Entry.Op2 := OT_NONE; End;
   7: Begin Mn:='IDIV'; Entry.Op2 := OT_NONE; End;
  End;
 End Else If Entry.Group = GRP_4 Then Begin
  If GroupReg = 0 Then Mn := 'INC' Else If GroupReg = 1 Then Mn := 'DEC'
  Else Begin Mn := 'DB'; Entry.Op1 := OT_NONE; End;
 End Else If Entry.Group = GRP_5 Then Begin
  Case GroupReg Of
   0: Begin Mn:='INC';  Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; End;
   1: Begin Mn:='DEC';  Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; End;
   2: Begin Mn:='CALL'; Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; IsBranch:=True; IsCall_:=True; IsIndirect:=True; End;
   3: Begin Mn:='CALL'; Entry.Op1:=OT_MEM;  Entry.Op2:=OT_NONE; S:='Far Ptr '; IsBranch:=True; IsCall_:=True; IsIndirect:=True; End;
   4: Begin Mn:='JMP';  Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; IsBranch:=True; IsUncond:=True; IsIndirect:=True; End;
   5: Begin Mn:='JMP';  Entry.Op1:=OT_MEM;  Entry.Op2:=OT_NONE; S:='Far Ptr '; IsBranch:=True; IsUncond:=True; IsIndirect:=True; End;
   6: Begin Mn:='PUSH'; Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; End;
   7: Begin Mn:='DB';   Entry.Op1:=OT_NONE; Entry.Op2:=OT_NONE; End;
  End;
 End Else If Entry.Group = GRP_6 Then Begin
  Case GroupReg Of
   0: Mn:='SLDT'; 1: Mn:='STR'; 2: Mn:='LLDT'; 3: Mn:='LTR';
   4: Mn:='VERR'; 5: Mn:='VERW';
  Else Begin Mn:='DB'; Entry.Op1:=OT_NONE; End;
  End;
 End Else If Entry.Group = GRP_7 Then Begin
  Case GroupReg Of
   0: Mn:='SGDT'; 1: Mn:='SIDT'; 2: Mn:='LGDT'; 3: Mn:='LIDT';
   4: Begin Mn:='SMSW'; Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; End;
   6: Begin Mn:='LMSW'; Entry.Op1:=OT_RM16; Entry.Op2:=OT_NONE; End;
  Else Begin Mn:='DB'; Entry.Op1:=OT_NONE; End;
  End;
 End Else If Entry.Group = GRP_8 Then Begin
  Case GroupReg Of
   4: Mn:='BT'; 5: Mn:='BTS'; 6: Mn:='BTR'; 7: Mn:='BTC';
  Else Begin Mn:='DB'; Entry.Op1:=OT_NONE; Entry.Op2:=OT_NONE; End;
  End;
 End Else If Entry.Group = GRP_8F Then Begin
  If GroupReg <> 0 Then Begin Mn:='DB'; Entry.Op1:=OT_NONE; End;
 End Else If (Entry.Group = GRP_C6) Or (Entry.Group = GRP_C7) Then Begin
  If GroupReg <> 0 Then Begin Mn:='DB'; Entry.Op1:=OT_NONE; Entry.Op2:=OT_NONE; End;
 End;

 { ---- Lecture des immediats/deplacements apres le ModRM eventuel ---- }
 Imm8 := 0; Imm16 := 0; FarSeg := 0; FarOfs := 0;
 If (Entry.Op1 = OT_IMM8) Or (Entry.Op2 = OT_IMM8) Or (Entry.Op3 = OT_IMM8) Then Begin
  Imm8 := GetByte(CurPos); Inc(CurPos);
 End;
 If (Entry.Op1 = OT_IMM8S) Or (Entry.Op2 = OT_IMM8S) Or (Entry.Op3 = OT_IMM8S) Then Begin
  Imm16 := Word(Integer(ShortInt(GetByte(CurPos)))); Inc(CurPos);
 End;
 If (Entry.Op1 = OT_IMM16) Or (Entry.Op2 = OT_IMM16) Or (Entry.Op3 = OT_IMM16) Then Begin
  Imm16 := GetWordAt(CurPos); CurPos := CurPos + 2;
 End;
 If (Entry.Op1 = OT_MOFFS8) Or (Entry.Op1 = OT_MOFFS16) Or
    (Entry.Op2 = OT_MOFFS8) Or (Entry.Op2 = OT_MOFFS16) Then Begin
  Imm16 := GetWordAt(CurPos); CurPos := CurPos + 2;
 End;
 If (Entry.Op1 = OT_FARPTR) Then Begin
  FarOfs := GetWordAt(CurPos); CurPos := CurPos + 2;
  FarSeg := GetWordAt(CurPos); CurPos := CurPos + 2;
  IsBranch := True; IsUncond := True;
  If OpByte = $9A Then Begin IsCall_ := True; IsUncond := False; End;
  { BOGUE REEL "manquait" CORRIGE (2026-10-03, enquete HIMEM/MS-DOS 6.22) :
    un CALL/JMP FAR direct vers un AUTRE segment etait jusqu'ici TOUJOURS
    marque "non resoluble", meme si ce segment correspondait a un bloc
    charge via /SEG:xxxx=fichier.bin. On cherche maintenant ce bloc et, s'il
    existe, le moteur recursif peut realmente y poursuivre le decodage -
    exactement ce qu'un vrai CPU ferait en changeant simplement CS. }
  BranchBlock := FindBlockBySeg(FarSeg);
  If BranchBlock >= 0 Then
   BranchTarget := OfsToAddrBlk(BranchBlock, LongInt(FarOfs))
  Else
   BranchTarget := -1; { segment non charge : cible non resoluble, comme avant }
 End;
 If (Entry.Op1 = OT_REL8) Then Begin
  Rel8 := ShortInt(GetByte(CurPos)); Inc(CurPos);
  RelTarget := Addr + (CurPos - Ofs) + Rel8;
  Imm16 := Word(RelTarget);
  IsBranch := True;
  BranchTarget := RelTarget;
  If (OpByte = $EB) Then IsUncond := True;
 End;
 If (Entry.Op1 = OT_REL16) Then Begin
  If Is0F Then Begin
   { Jcc near (0F 80-8F) : deplacement sur 16 bits en mode reel }
   Imm16 := GetWordAt(CurPos); CurPos := CurPos + 2;
   RelTarget := Addr + (CurPos - Ofs) + Integer(Imm16);
  End Else Begin
   Imm16 := GetWordAt(CurPos); CurPos := CurPos + 2;
   RelTarget := Addr + (CurPos - Ofs) + Integer(Imm16);
  End;
  Imm16 := Word(RelTarget);
  IsBranch := True;
  BranchTarget := RelTarget;
  If (OpByte = $E9) Then IsUncond := True;
 End;

 { ---- Detection CALL near/far directs et RET/IRET ---- }
 If (Not Is0F) And (OpByte = $E8) Then IsCall_ := True;
 If (Not Is0F) And ((OpByte = $C3) Or (OpByte = $C2) Or (OpByte = $CA) Or
    (OpByte = $CB) Or (OpByte = $CF)) Then Begin
  { BOGUE REEL CORRIGE (2026-10-03, trouve en testant les blocs de segments
    multiples) : BranchTarget restait a sa valeur par defaut (0) pour
    RET/RETF/IRET, qui n'ont PAS de cible statique connue (elle vient de la
    pile a l'execution). Le moteur recursif (RunRecursiveEngine) ne teste
    que "BrTarget >= 0" pour decider d'ajouter un symbole/xref/mise en file -
    0 passait ce test, ce qui creait a tort un symbole/xref "RET -> debut du
    bloc" pour CHAQUE RET/RETF/IRET rencontre. Meme convention que pour un
    pointeur FAR non resoluble : -1 = "pas de cible". }
  IsRetInstr := True;
  IsBranch := True;
  IsUncond := True;
  BranchTarget := -1;
 End;
 If (Not Is0F) And (OpByte = $CD) Then IntNumber := Imm8;

 { ---- Construction du texte des operandes ---- }
 O1S := ''; O2S := ''; O3S := '';
 If Entry.Op1 <> OT_NONE Then
  O1S := FmtOperand(Entry.Op1, GroupReg, Rm, RmUsed, OpByte, Imm8, Imm16, FarSeg, FarOfs);
 If Entry.Op2 <> OT_NONE Then
  O2S := FmtOperand(Entry.Op2, GroupReg, Rm, RmUsed, OpByte, Imm8, Imm16, FarSeg, FarOfs);
 If Entry.Op3 <> OT_NONE Then
  O3S := FmtOperand(Entry.Op3, GroupReg, Rm, RmUsed, OpByte, Imm8, Imm16, FarSeg, FarOfs);

 { Les operandes "#REG#" (mode registre direct non resolu avant de
   connaitre le type final 8/16/32) sont deja geres par FmtOperand via
   OT_RM8/OT_RM16/OT_REG8/OT_REG16 - rien a faire ici. }

 S := CurRepPfx + Mn;
 If (Entry.Group = GRP_5) And (GroupReg In [3,5]) Then
  S := S + ' ' + 'Far Ptr ' + O1S
 Else If O1S <> '' Then S := S + ' ' + O1S;
 If O2S <> '' Then S := S + ',' + O2S;
 If O3S <> '' Then S := S + ',' + O3S;

 OutText := S;
 Length_ := CurPos - Ofs;
 If Length_ < 1 Then Length_ := 1;
 OpMinCPU := Entry.MinCPU;
End;

{ ============================================================
  MARQUAGE DES OCTETS COMME CODE (apres decodage reussi)
  ============================================================ }

Procedure MarkCodeRange(Ofs, Len: LongInt);
Var I: LongInt;
Begin
 If Not InBounds(Ofs) Then Exit;
 ByteFlags^[Ofs] := BF_CODE;
 For I := 1 To Len-1 Do
  If InBounds(Ofs+I) Then ByteFlags^[Ofs+I] := BF_CODEPART;
End;

{ ============================================================
  MOTEUR DE DESASSEMBLAGE RECURSIF
  Traite la file d'attente : pour chaque adresse, si elle n'a pas deja ete
  decodee comme code, decode l'instruction, l'enregistre, et met en file
  les cibles de branchement/appel directes decouvertes (symboles generes
  automatiquement). C'est la vraie difference avec un desassembleur
  lineaire classique : le flux de controle REEL du programme est suivi,
  y compris a travers des zones de donnees intercalees entre routines.
  ============================================================ }

Type
 TDecodedInstr = Record
  Blk  : Integer;
  Addr : LongInt;
  Text : TString;
  Len  : LongInt;
  Bytes: Array[0..15] Of Byte;
  IntNumber : Integer;
  IsCall, IsBranch : Boolean;
  MinCPU : Byte;
 End;

Const
 MAX_DECODED = 65536;
Var
 Decoded    : Array[0..MAX_DECODED-1] Of TDecodedInstr;
 DecodedCnt : LongInt;

{ Moteur recursif : desormais parcourt une file d'attente de couples
  (bloc,adresse) - voir TWorkItem. Chaque iteration bascule le bloc ACTIF
  sur celui de l'element traite (SwitchBlock), ce qui fait que TOUT le reste
  (GetByte/InBounds/AddrToOfs/DecodeOne/MarkCodeRange/ByteFlags^) continue a
  fonctionner EXACTEMENT comme avant, sans aucun changement - seul un
  CALL/JMP FAR direct (voir DecodeOne/OT_FARPTR) peut faire apparaitre un
  BranchBlock different du bloc courant, et c'est CE couple (BranchBlock,
  BrTarget) qui est mis en file, permettant au moteur de "traverser" vers
  l'autre bloc charge. }
Procedure RunRecursiveEngine;
Var Blk, BranchBlock: Integer; Addr, Ofs: LongInt; Text: TString; Len: LongInt; I: LongInt;
 IsBranch, IsCall_, IsUncond, IsIndirect, IsRetI: Boolean;
 BrTarget: LongInt; IntNum: Integer; MinCpuOut: Byte;
 Head: LongInt;
Begin
 Head := 0;
 While Head < WorkQueueCnt Do Begin
  Blk  := WorkQueue[Head].Blk;
  Addr := WorkQueue[Head].Addr;
  Inc(Head);
  If (Blk < 0) Or (Blk >= SegBlockCnt) Then Continue;
  SwitchBlock(Blk);
  Ofs := AddrToOfs(Addr);
  If Not InBounds(Ofs) Then Continue;
  If ByteFlags^[Ofs] = BF_CODE Then Continue;   { deja traite }
  If ByteFlags^[Ofs] = BF_CODEPART Then Continue; { tombe au milieu d'une instruction deja decodee - desalignement, on ignore ce depart }
  If ByteFlags^[Ofs] = BF_HEADER Then Continue; { Device Header (18 octets) : jamais du code, meme si une cible erronee y pointe }

  DecodeOne(Addr, Text, Len, IsBranch, IsCall_, IsUncond, IsIndirect, IsRetI, BrTarget, BranchBlock, IntNum, MinCpuOut);
  MarkCodeRange(Ofs, Len);

  If DecodedCnt < MAX_DECODED Then Begin
   Decoded[DecodedCnt].Blk  := Blk;
   Decoded[DecodedCnt].Addr := Addr;
   Decoded[DecodedCnt].Text := Text;
   Decoded[DecodedCnt].Len  := Len;
   For I := 0 To Len-1 Do
    If I <= 15 Then Decoded[DecodedCnt].Bytes[I] := GetByte(Ofs+I);
   Decoded[DecodedCnt].IntNumber := IntNum;
   Decoded[DecodedCnt].IsCall := IsCall_;
   Decoded[DecodedCnt].IsBranch := IsBranch;
   Decoded[DecodedCnt].MinCPU := MinCpuOut;
   Inc(DecodedCnt);
  End;

  If IsBranch And (Not IsIndirect) And (BranchBlock >= 0) And (BrTarget >= 0) And
     InBoundsBlk(BranchBlock, AddrToOfsBlk(BranchBlock, BrTarget)) Then Begin
   If IsCall_ Then Begin
    AddSymbol(BranchBlock, BrTarget, SYM_SUB, AutoSymbolName(BranchBlock, BrTarget, SYM_SUB));
    AddXRef(Blk, Addr, BranchBlock, BrTarget, True);
   End Else Begin
    AddSymbol(BranchBlock, BrTarget, SYM_LOC, AutoSymbolName(BranchBlock, BrTarget, SYM_LOC));
    AddXRef(Blk, Addr, BranchBlock, BrTarget, False);
   End;
   QueuePush(BranchBlock, BrTarget);
  End;

  { Une instruction qui ne se termine ni par un saut inconditionnel ni par
    un retour laisse le flot continuer normalement a l'instruction suivante -
    on la met donc aussi en file (c'est ce qui distingue un VRAI moteur
    recursif d'un simple "suivi d'etiquettes" : chaque instruction pousse
    elle-meme la suivante, permettant de s'arreter net des qu'on rencontre
    un JMP/RET/IRET inconditionnel plutot que de deborder dans des donnees). }
  If Not (IsUncond Or IsRetI) Then
   QueuePush(Blk, Addr + Len);
 End;
End;

{ ============================================================
  PASSE LINEAIRE (/L) : desassemble inconditionnellement tout l'intervalle,
  sans se soucier du flot de controle - utile pour auditer une zone ou le
  moteur recursif n'a rien trouve de rattache au graphe d'appel.
  ============================================================ }

Procedure RunLinearPass(Blk: Integer; StartAddr, EndAddr: LongInt);
Var Addr: LongInt; Ofs: LongInt; Text: TString; Len: LongInt; I: LongInt;
 IsBranch, IsCall_, IsUncond, IsIndirect, IsRetI: Boolean;
 BrTarget: LongInt; BranchBlock: Integer; IntNum: Integer; MinCpuOut: Byte;
Begin
 SwitchBlock(Blk);
 Addr := StartAddr;
 While Addr < EndAddr Do Begin
  Ofs := AddrToOfs(Addr);
  If Not InBounds(Ofs) Then Break;
  If ByteFlags^[Ofs] In [BF_CODE, BF_CODEPART, BF_HEADER] Then Begin
   Inc(Addr);
   Continue;
  End;
  DecodeOne(Addr, Text, Len, IsBranch, IsCall_, IsUncond, IsIndirect, IsRetI, BrTarget, BranchBlock, IntNum, MinCpuOut);
  MarkCodeRange(Ofs, Len);
  If DecodedCnt < MAX_DECODED Then Begin
   Decoded[DecodedCnt].Blk  := Blk;
   Decoded[DecodedCnt].Addr := Addr;
   Decoded[DecodedCnt].Text := Text;
   Decoded[DecodedCnt].Len  := Len;
   For I := 0 To Len-1 Do
    If I <= 15 Then Decoded[DecodedCnt].Bytes[I] := GetByte(Ofs+I);
   Decoded[DecodedCnt].IntNumber := IntNum;
   Decoded[DecodedCnt].IsCall := IsCall_;
   Decoded[DecodedCnt].MinCPU := MinCpuOut;
   Decoded[DecodedCnt].IsBranch := IsBranch;
   Inc(DecodedCnt);
  End;
  Addr := Addr + Len;
 End;
End;

{ ============================================================
  DETECTION DE CHAINES ASCII (/STRINGS) ET DE DONNEES (/DATA)
  DANS LES OCTETS RESTES NON MARQUES APRES LE DESASSEMBLAGE DE CODE
  ============================================================ }

Procedure RunDataDetection(Blk: Integer);
Var Ofs, RunStart: LongInt; RunLen: Integer; B: Byte;
Begin
 SwitchBlock(Blk);
 Ofs := 0;
 While Ofs < ImageSize Do Begin
  If ByteFlags^[Ofs] <> BF_UNKNOWN Then Begin
   Inc(Ofs);
   Continue;
  End;
  If OptStrings Then Begin
   RunStart := Ofs;
   RunLen := 0;
   While (Ofs < ImageSize) And (ByteFlags^[Ofs] = BF_UNKNOWN) Do Begin
    B := GetByte(Ofs);
    If (B >= 32) And (B <= 126) Then Begin
     Inc(RunLen);
     Inc(Ofs);
    End Else Break;
   End;
   If RunLen >= 4 Then Begin
    { chaine ASCII plausible : au moins 4 caracteres imprimables consecutifs }
    ByteFlags^[RunStart] := BF_STRING;
    AddSymbol(Blk, OfsToAddr(RunStart), SYM_DATA, AutoSymbolName(Blk, OfsToAddr(RunStart), SYM_DATA));
   End Else Begin
    Ofs := RunStart;
    If OptData Then ByteFlags^[Ofs] := BF_DATA;
    Inc(Ofs);
   End;
  End Else Begin
   If OptData Then ByteFlags^[Ofs] := BF_DATA;
   Inc(Ofs);
  End;
 End;
End;

{ ============================================================
  ANALYSE DES STRUCTURES DE PILOTE DOS (/DRV, /DPB, /SFT, /MCB, /INDOS)
  Ajoute des symboles/commentaires structurels de haut niveau. Ces passes
  ne modifient jamais le decodage d'instructions - elles enrichissent
  seulement la table de symboles et les commentaires emis a l'ecriture.
  ============================================================ }

Procedure AnnotateDeviceStructure;
Var StratAddr, IntrAddr: LongInt; NameStr: TString; I: Integer;
Begin
 { Toujours relatif au bloc 0 (le fichier /O) - voir HasDeviceHeader. }
 If Not HasDeviceHeader Then Exit;
 AddSymbol(0, OfsToAddr(0), SYM_DEVHDR, AutoSymbolName(0, OfsToAddr(0), SYM_DEVHDR));
 ByteFlags^[0] := BF_HEADER;
 For I := 1 To 17 Do If InBounds(I) Then ByteFlags^[I] := BF_HEADER;

 NameStr := '';
 If (DevHeader.Attributes And $8000) <> 0 Then Begin
  For I := 0 To 7 Do NameStr := NameStr + Chr(DevHeader.Name[I]);
 End;

 StratAddr := OfsToAddr(DevHeader.StrategyOfs);
 IntrAddr  := OfsToAddr(DevHeader.InterruptOfs);
 AddSymbol(0, StratAddr, SYM_STRAT, 'Strategy_' + HexWord(Word(StratAddr)));
 AddSymbol(0, IntrAddr,  SYM_INTR,  'Interrupt_' + HexWord(Word(IntrAddr)));
 QueuePush(0, StratAddr);
 QueuePush(0, IntrAddr);
End;

{ Recherche heuristique de comparaisons avec les octets signature 'M'(4Dh)
  ou 'Z'(5Ah) d'un en-tete de bloc memoire (MCB) - CMP AL,4Dh / CMP AL,5Ah
  ou CMP Byte Ptr [xxx],4Dh/5Ah - pure heuristique de motif, annoncee comme
  telle dans le commentaire emis (/MCB). }
Procedure ScanMcbPatterns;
Var I: LongInt; B0,B1: Byte; A: LongInt;
Begin
 If Not OptMcb Then Exit;
 For I := 0 To DecodedCnt-1 Do Begin
  { Decoded[I] peut appartenir a N'IMPORTE QUEL bloc charge - GetByteBlk lit
    directement dans le bloc concerne, sans toucher au bloc "actif". }
  A := AddrToOfsBlk(Decoded[I].Blk, Decoded[I].Addr);
  If (Decoded[I].Len >= 2) Then Begin
   B0 := GetByteBlk(Decoded[I].Blk, A); B1 := GetByteBlk(Decoded[I].Blk, A+1);
   If (B0 = $3C) And ((B1 = $4D) Or (B1 = $5A)) Then
    AddSymbol(Decoded[I].Blk, Decoded[I].Addr, SYM_LOC, SymbolNameAt(Decoded[I].Blk, Decoded[I].Addr));
  End;
 End;
End;

{ ============================================================
  ANALYSE DU FORMAT MZ (EXE) - EN-TETE MINIMAL
  ============================================================ }

Type
 TMZHdr = Record
  Sig, LastPage, PageCnt, RelocCnt, HdrParas, MinAlloc, MaxAlloc: Word;
  InitSS, InitSP, Checksum, InitIP, InitCS, RelocOfs, OverlayNum: Word;
 End;

Function ReadMZHdr(Var H: TMZHdr): Boolean;
Begin
 ReadMZHdr := False;
 If ImageSize < 28 Then Exit;
 H.Sig       := GetWordAt(0);
 If (H.Sig <> $5A4D) And (H.Sig <> $4D5A) Then Exit;
 H.LastPage  := GetWordAt(2);
 H.PageCnt   := GetWordAt(4);
 H.RelocCnt  := GetWordAt(6);
 H.HdrParas  := GetWordAt(8);
 H.MinAlloc  := GetWordAt(10);
 H.MaxAlloc  := GetWordAt(12);
 H.InitSS    := GetWordAt(14);
 H.InitSP    := GetWordAt(16);
 H.Checksum  := GetWordAt(18);
 H.InitIP    := GetWordAt(20);
 H.InitCS    := GetWordAt(22);
 H.RelocOfs  := GetWordAt(24);
 H.OverlayNum:= GetWordAt(26);
 ReadMZHdr := True;
End;

{ ============================================================
  SELECTION DU FORMAT ET DU/DES POINT(S) D'ENTREE
  ============================================================ }

Procedure SetupFormatAndEntries;
Var MZH: TMZHdr; HdrSizeBytes: LongInt;
Begin
 HasDeviceHeader := False;

 If OptFormat = FMT_AUTO Then Begin
  If ReadMZHdr(MZH) Then OptFormat := FMT_EXE
  Else If DetectDeviceHeader Then OptFormat := FMT_SYS
  Else OptFormat := FMT_RAW;
 End;

 Case OptFormat Of
  FMT_EXE: Begin
   If ReadMZHdr(MZH) Then Begin
    HdrSizeBytes := LongInt(MZH.HdrParas) * 16;
    { Reduit l'image a son "image de chargement" (apres l'en-tete MZ) en
      deplacant simplement l'origine : OptOrg reste tel que fourni par
      l'utilisateur, mais le DECALAGE FICHIER 0 doit desormais correspondre
      a HdrSizeBytes - on simule cela en avancant un pseudo-ORG interne. }
    If Not OptHasOrg Then OptOrg := 0;
    { On recadre l'image en copiant l'image de chargement au debut du
      tampon (le plus simple et le plus sur avec cette architecture a
      decalage fichier = decalage image). }
    Move(Image^[HdrSizeBytes], Image^[0], ImageSize - HdrSizeBytes);
    ImageSize := ImageSize - HdrSizeBytes;
    If Not OptHasEntry Then Begin
     OptEntry := OfsToAddr(LongInt(MZH.InitCS)*16 + LongInt(MZH.InitIP));
     OptHasEntry := True;
    End;
    If OptHdr And (Not OptQuiet) Then Begin
     WriteLn('En-tete MZ reconnu :');
     WriteLn('  Taille en-tete    : ', HdrSizeBytes, ' octets (', MZH.HdrParas, ' paragraphes)');
     WriteLn('  CS:IP initial     : ', HexWord(MZH.InitCS), ':', HexWord(MZH.InitIP));
     WriteLn('  SS:SP initial     : ', HexWord(MZH.InitSS), ':', HexWord(MZH.InitSP));
     WriteLn('  Relogements       : ', MZH.RelocCnt);
    End;
   End;
  End;
  FMT_SYS: Begin
   If Not OptHasOrg Then OptOrg := 0;
   HasDeviceHeader := DetectDeviceHeader;
   If HasDeviceHeader Then Begin
    AnnotateDeviceStructure;
    If OptHdr And (Not OptQuiet) Then Begin
     WriteLn('Device Header reconnu (pilote DOS) :');
     WriteLn('  Attributs         : ', HexWord(DevHeader.Attributes));
     WriteLn('  Strategy offset   : ', HexWord(DevHeader.StrategyOfs));
     WriteLn('  Interrupt offset  : ', HexWord(DevHeader.InterruptOfs));
    End;
   End;
  End;
  FMT_COM: Begin
   If Not OptHasOrg Then OptOrg := $100;
   If Not OptHasEntry Then Begin
    OptEntry := OfsToAddr(0);
    OptHasEntry := True;
   End;
  End;
  FMT_RAW: Begin
   If Not OptHasOrg Then OptOrg := 0;
   If Not OptHasEntry Then Begin
    OptEntry := OfsToAddr(0);
    OptHasEntry := True;
   End;
  End;
 End;

 { Toujours le bloc 0 (le fichier /O) - SetupFormatAndEntries s'execute
   AVANT que RegisterBlock0/SwitchBlock n'existent, donc "0" est explicite
   plutot que CurBlk (pas encore significatif a ce stade). }
 If OptHasEntry Then Begin
  AddSymbol(0, OptEntry, SYM_ENTRY, AutoSymbolName(0, OptEntry, SYM_ENTRY));
  QueuePush(0, OptEntry);
 End;
 If (Not HasDeviceHeader) And (OptFormat = FMT_SYS) Then Begin
  { Pas d'en-tete de pilote detecte malgre /FMT:SYS force (cas d'un VRAI
    noyau MSDOS.SYS/IO.SYS, qui demarre simplement par un JMP) - traite
    comme RAW a partir de l'offset 0 si aucun point d'entree n'a ete donne. }
  If Not OptHasEntry Then Begin
   OptEntry := OfsToAddr(0);
   OptHasEntry := True;
   AddSymbol(0, OptEntry, SYM_ENTRY, AutoSymbolName(0, OptEntry, SYM_ENTRY));
   QueuePush(0, OptEntry);
  End;
 End;
End;

{ ============================================================
  SYNTAXES DE SORTIE (/ASM:MASM|TASM|NASM)
  Les deux premieres sont quasi-identiques (syntaxe Intel classique) ; NASM
  utilise un style de litteraux et de crochets different - transformation
  legere appliquee au texte deja construit (suffisant pour un usage de
  relecture, sans pretendre a un reassemblage NASM bit-exact).
  ============================================================ }

Function ConvertToNasm(S: TString): TString;
Var R: TString; I: Integer; Tok: TString;
Begin
 { Convertit chaque "XXh" en "0xXX" et retire les mots-cles "Ptr"/"Far Ptr"
   (NASM utilise "byte [..]" / "word [..]" sans "Ptr"). }
 R := S;
 { Byte Ptr / Word Ptr / DWord Ptr -> minuscule sans "Ptr " }
 While Pos('Byte Ptr ', R) > 0 Do
  Delete(R, Pos('Byte Ptr ', R), Length('Byte Ptr ')-5);
 While Pos('Word Ptr ', R) > 0 Do
  Delete(R, Pos('Word Ptr ', R), Length('Word Ptr ')-5);
 While Pos('DWord Ptr ', R) > 0 Do
  Delete(R, Pos('DWord Ptr ', R), Length('DWord Ptr ')-6);
 While Pos('Far Ptr ', R) > 0 Do
  Delete(R, Pos('Far Ptr ', R), Length('Far Ptr '));
 { XXh -> 0xXX (parcours simple, convertit chaque occurrence finissant par 'h') }
 Tok := '';
 I := 1;
 While I <= Length(R) Do Begin
  If (R[I] In ['0'..'9','A'..'F']) Then Begin
   Tok := Tok + R[I];
   Inc(I);
   If (I <= Length(R)) And (R[I] = 'h') And (Tok <> '') Then Begin
    Delete(R, I-Length(Tok), Length(Tok)+1);
    Insert('0x'+Tok, R, I-Length(Tok));
    I := I - Length(Tok) + Length('0x'+Tok);
    Tok := '';
   End;
  End Else Begin
   Tok := '';
   Inc(I);
  End;
 End;
 ConvertToNasm := R;
End;

Function ApplySyntax(S: TString): TString;
Begin
 If OptAsmSyntax = SYN_NASM Then ApplySyntax := ConvertToNasm(S)
 Else ApplySyntax := S;
End;

{ ============================================================
  ECRITURE DE LA SORTIE
  ============================================================ }

Function CpuLevelName(C: Byte): TString;
Begin
 Case C Of
  CPU_8086: CpuLevelName := '8086';
  CPU_186:  CpuLevelName := '80186';
  CPU_286:  CpuLevelName := '80286';
  CPU_386:  CpuLevelName := '80386';
  CPU_486:  CpuLevelName := '80486';
 Else CpuLevelName := '?';
 End;
End;

Function BytesToHexStr(Var D: TDecodedInstr): TString;
Var I: Integer; S: TString;
Begin
 S := '';
 For I := 0 To D.Len-1 Do Begin
  If I > 15 Then Break;
  If S <> '' Then S := S + ' ';
  S := S + HexDigit(D.Bytes[I] Shr 4) + HexDigit(D.Bytes[I] And $0F);
 End;
 BytesToHexStr := S;
End;

Procedure WriteDeviceHeaderBlock;
Var S: TString; I: Integer;
Begin
 If (Not HasDeviceHeader) Or (Not OptHdr) Then Exit;
 WriteLn(OutF, '; ------------------------------------------------------------');
 WriteLn(OutF, '; Device Header DOS (en-tete de pilote, 18 octets)');
 WriteLn(OutF, '; ------------------------------------------------------------');
 WriteLn(OutF, FmtAddr(0, OfsToAddr(0)), '  DeviceHeader_', HexWord(Word(OfsToAddr(0))), ':');
 WriteLn(OutF, '    DD  ', HexWord(DevHeader.NextSeg), ':', HexWord(DevHeader.NextOfs),
   '          ; pointeur vers le pilote suivant (rempli par DOS au chargement)');
 WriteLn(OutF, '    DW  ', HexWord(DevHeader.Attributes),
   '                   ; attributs (bit15=caractere, bit11=IOCTL, bit13=sortie-jusqu-a-occupe)');
 WriteLn(OutF, '    DW  ', LabelOrAddr(0, OfsToAddr(DevHeader.StrategyOfs)),
   '                ; offset de la routine Strategy');
 WriteLn(OutF, '    DW  ', LabelOrAddr(0, OfsToAddr(DevHeader.InterruptOfs)),
   '                ; offset de la routine Interrupt (traitement des requetes)');
 S := '';
 If (DevHeader.Attributes And $8000) <> 0 Then Begin
  For I := 0 To 7 Do S := S + Chr(DevHeader.Name[I]);
  WriteLn(OutF, '    DB  "', S, '"             ; nom du pilote caractere (8 octets)');
 End Else
  WriteLn(OutF, '    DB  ', HexByte(DevHeader.Name[0]), ', 7 octets reserves     ; pilote bloc : nombre d''unites');
 WriteLn(OutF);
 WriteLn(OutF, '; Convention d''appel DOS (rappel) : DOS appelle Strategy avec ES:BX');
 WriteLn(OutF, '; pointant vers un Request Header (Length, Unit, Command, Status,');
 WriteLn(OutF, '; Reserved[8], puis champs specifiques a la commande), PUIS appelle');
 WriteLn(OutF, '; immediatement Interrupt (sans parametre - le pilote retrouve le');
 WriteLn(OutF, '; meme pointeur ES:BX que Strategy vient de recevoir/sauvegarder).');
 WriteLn(OutF);
End;

{ Remplace chaque marqueur "@BTxxxxh@" (branchement PROCHE, meme bloc) ou
  "@BTFssss:oooo@" (CALL/JMP FAR DIRECT, voir OT_FARPTR - "ssss"=segment,
  "oooo"=offset) par le nom symbolique s'il existe desormais (/SYMBOLS),
  sinon par l'adresse hexadecimale brute - appele une fois TOUS les
  symboles connus (de TOUS les blocs), donc toujours a jour meme pour une
  reference "en avance". Blk = bloc de L'INSTRUCTION QUI CONTIENT LE
  MARQUEUR (necessaire pour resoudre un "@BT" proche, qui reste toujours
  dans le MEME bloc que l'instruction qui branche). }
Function ResolveBranchMarkers(Blk: Integer; S: TString): TString;
Var P1, P2, PColon: Integer; Inner, SegS, OfsS: TString;
 Addr: LongInt; Resolved: TString; TargetBlk: Integer; Seg: Word;
Begin
 While Pos('@BT', S) > 0 Do Begin
  P1 := Pos('@BT', S);
  P2 := P1 + 3;
  While (P2 <= Length(S)) And (S[P2] <> '@') Do Inc(P2);
  Inner := Copy(S, P1+3, P2-(P1+3));
  If (Length(Inner) > 0) And (Inner[1] = 'F') Then Begin
   { "Fssss:oooo" - CALL/JMP FAR direct }
   Delete(Inner, 1, 1);
   PColon := Pos(':', Inner);
   SegS := Copy(Inner, 1, PColon-1);
   OfsS := Copy(Inner, PColon+1, Length(Inner)-PColon);
   Seg := Word(HexStrToLong(SegS));
   TargetBlk := FindBlockBySeg(Seg);
   If TargetBlk >= 0 Then
    Resolved := HexWord(Seg) + ':' + LabelOrAddr(TargetBlk, HexStrToLong(OfsS))
   Else
    Resolved := HexWord(Seg) + ':' + OfsS;  { segment non charge : hex brut, comme avant /SEG }
  End Else Begin
   { "xxxxh" - branchement proche, toujours dans le meme bloc Blk }
   Addr := HexStrToLong(Inner);
   Resolved := LabelOrAddr(Blk, Addr);
  End;
  S := Copy(S, 1, P1-1) + Resolved + Copy(S, P2+1, Length(S)-P2);
 End;
 ResolveBranchMarkers := S;
End;

Procedure WriteOneInstruction(Var D: TDecodedInstr);
Var Line, Nm, Cmt, ResolvedText: TString; Idx: LongInt;
Begin
 { Le bloc actif doit correspondre a CELUI de l'instruction : DescribeInterrupt
   (via AddrToOfs/GetByte) lit l'image du bloc concerne, pas forcement celui
   qui etait actif au moment ou le moteur recursif a fini son travail. }
 SwitchBlock(D.Blk);

 { ---- Etiquette eventuelle sur une ligne separee ---- }
 Idx := FindSymbol(D.Blk, D.Addr);
 If (Idx >= 0) And OptSymbols Then Begin
  Nm := Symbols[Idx].Name;
  WriteLn(OutF, Nm, ':');
 End;

 ResolvedText := ResolveBranchMarkers(D.Blk, D.Text);

 Line := '';
 If OptAddr Then Line := Line + FmtAddr(D.Blk, D.Addr) + '  ';
 If OptBytes Then Line := Line + Pad(BytesToHexStr(D), 24) + ' ';
 Line := Line + '    ' + ApplySyntax(ResolvedText);

 Cmt := '';
 If OptComments And (D.IntNumber >= 0) And (OptIntAnnot Or OptApiAnnot) Then
  Cmt := DescribeInterrupt(Byte(D.IntNumber), AddrToOfs(D.Addr));

 If (Cmt = '') And OptComments And (D.IntNumber >= 0) And (OptIntAnnot Or OptApiAnnot) Then
  Cmt := 'INT ' + HexByte(Byte(D.IntNumber));

 If (OptCPU <> CPU_AUTO) And (D.MinCPU > OptCPU) Then Begin
  If Cmt <> '' Then Cmt := Cmt + ' - ';
  Cmt := Cmt + 'ATTENTION : necessite un ' + CpuLevelName(D.MinCPU) +
         ' ou superieur (cible choisie : ' + CpuLevelName(OptCPU) + ')';
 End;

 If Cmt <> '' Then Line := Line + '   ; ' + Cmt;

 WriteLn(OutF, Line);
End;

{ Tri par (Blk,Addr) - pas seulement Addr - pour que chaque bloc forme une
  section CONTIGUE dans le listing final, meme si deux blocs differents
  contiennent un decalage local identique (parfaitement possible : chacun a
  son propre espace d'adressage 0..65535). }
Procedure SortDecodedByAddr;
Var I, J: LongInt; Tmp: TDecodedInstr; Swap: Boolean;
Begin
 { Tri a bulles simple : le nombre d'instructions decodees pour un noyau/
   pilote DOS reste de l'ordre de quelques dizaines de milliers au pire,
   largement gerable sans tri plus sophistique pour un outil hors-ligne. }
 For I := 0 To DecodedCnt-2 Do
  For J := 0 To DecodedCnt-2-I Do Begin
   Swap := (Decoded[J].Blk > Decoded[J+1].Blk) Or
           ((Decoded[J].Blk = Decoded[J+1].Blk) And (Decoded[J].Addr > Decoded[J+1].Addr));
   If Swap Then Begin
    Tmp := Decoded[J];
    Decoded[J] := Decoded[J+1];
    Decoded[J+1] := Tmp;
   End;
  End;
End;

Function FormatName: TString;
Begin
 Case OptFormat Of
  FMT_SYS: FormatName := 'SYS (pilote DOS)';
  FMT_COM: FormatName := 'COM';
  FMT_EXE: FormatName := 'EXE (MZ)';
  FMT_RAW: FormatName := 'RAW (image brute / noyau)';
 Else FormatName := 'AUTO';
 End;
End;

{ Affiche la ligne d'en-tete "SEG:OFS -> SEG:OFS CALL/JMP ..." d'une xref,
  en indiquant le segment des DEUX cotes meme s'ils sont identiques (plus
  clair qu'une xref multi-bloc melangeant silencieusement 2 espaces
  d'adressage locaux differents). }
Procedure WriteXRefLine(Var F: Text; Prefix: TString; I: LongInt);
Begin
 If XRefs[I].IsCall Then
  WriteLn(F, Prefix, FmtAddr(XRefs[I].FromBlk, XRefs[I].FromAddr), ' CALL -> ',
   FmtAddr(XRefs[I].ToBlk, XRefs[I].ToAddr), ' (', LabelOrAddr(XRefs[I].ToBlk, XRefs[I].ToAddr), ')')
 Else
  WriteLn(F, Prefix, FmtAddr(XRefs[I].FromBlk, XRefs[I].FromAddr), ' JMP/Jcc -> ',
   FmtAddr(XRefs[I].ToBlk, XRefs[I].ToAddr), ' (', LabelOrAddr(XRefs[I].ToBlk, XRefs[I].ToAddr), ')');
End;

Procedure WriteListing;
Var I: LongInt; Profiles: TString; B: Integer; AnyForBlk: Boolean;
Begin
 WriteLn(OutF, '; ============================================================');
 WriteLn(OutF, '; DISSYS v', DISSYS_VERSION, ' - Desassemblage de ', InputFileName);
 WriteLn(OutF, '; Format detecte/force : ', FormatName);
 WriteLn(OutF, '; Origine (ORG)        : ', HexWord(Word(OptOrg)));
 If OptHasBase Then
  WriteLn(OutF, '; Base de chargement   : ', HexLong(OptBase));
 If OptHasEntry Then
  WriteLn(OutF, '; Point d''entree       : ', FmtAddr(0, OptEntry));
 WriteLn(OutF, '; DOS cible            : ', OptDosVerMajor, '.', OptDosVerMinor);
 Profiles := '';
 If OptModeSys    Then Profiles := Profiles + '/SYS ';
 If OptModeDriver Then Profiles := Profiles + '/DRIVER ';
 If OptModeKernel Then Profiles := Profiles + '/KERNEL ';
 If Profiles <> '' Then WriteLn(OutF, '; Profil(s) d''analyse  : ', Profiles);
 If SegBlockCnt > 1 Then
  WriteLn(OutF, '; Blocs de segments    : ', SegBlockCnt, ' (voir /SEG ci-dessous)');
 WriteLn(OutF, '; Genere le ', DISSYS_DATE);
 WriteLn(OutF, '; ============================================================');
 WriteLn(OutF);

 WriteDeviceHeaderBlock;

 SortDecodedByAddr;

 { Un seul bloc (usage historique) : comportement EXACTEMENT identique a
   avant, sans aucun en-tete de section supplementaire. Plusieurs blocs :
   une section par bloc, dans l'ordre ou ils ont ete charges (bloc 0 =
   fichier /O en premier), chacune montrant son segment/fichier/nombre
   d'instructions - y compris les blocs charges mais JAMAIS atteints par
   aucun CALL/JMP FAR (0 instruction), signe utile que ce segment n'est
   peut-etre pas celui attendu ou n'est reellement appele que via un
   pointeur FAR en donnees (voir /FARPTR). }
 If SegBlockCnt <= 1 Then Begin
  For I := 0 To DecodedCnt-1 Do
   WriteOneInstruction(Decoded[I]);
 End Else Begin
  For B := 0 To SegBlockCnt-1 Do Begin
   WriteLn(OutF, '; ------------------------------------------------------------');
   If SegBlocks[B].BlkHasSeg Then
    WriteLn(OutF, '; Bloc ', B, ' - segment ', HexWord(SegBlocks[B].RealSeg),
     ' (', SegBlocks[B].FileName, '), ', SegBlocks[B].ImageSize, ' octets')
   Else
    WriteLn(OutF, '; Bloc ', B, ' - ', SegBlocks[B].FileName, ' (pas de segment /SEG), ',
     SegBlocks[B].ImageSize, ' octets');
   WriteLn(OutF, '; ------------------------------------------------------------');
   AnyForBlk := False;
   For I := 0 To DecodedCnt-1 Do
    If Decoded[I].Blk = B Then Begin
     WriteOneInstruction(Decoded[I]);
     AnyForBlk := True;
    End;
   If Not AnyForBlk Then
    WriteLn(OutF, '; (aucune instruction decodee - ce bloc n''a ete atteint par', ' aucun CALL/JMP FAR direct ni point d''entree)');
   WriteLn(OutF);
  End;
 End;

 If OptXref Then Begin
  WriteLn(OutF);
  WriteLn(OutF, '; ------------------------------------------------------------');
  WriteLn(OutF, '; References croisees (/XREF)');
  WriteLn(OutF, '; ------------------------------------------------------------');
  For I := 0 To XRefCnt-1 Do
   WriteXRefLine(OutF, '; ', I);
 End;
End;

Procedure WriteMapFile;
Var I: LongInt; KindStr: TString;
Begin
 If Not OptUseMap Then Exit;
 {$I-}
 Assign(MapF, MapFileName);
 Rewrite(MapF);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Avertissement : impossible de creer le fichier /MAP ', MapFileName);
  Exit;
 End;
 WriteLn(MapF, '; Carte des symboles - ', InputFileName);
 WriteLn(MapF, 'Adresse   Categorie      Nom');
 WriteLn(MapF, '--------  -------------  ------------------------------');
 For I := 0 To SymbolCnt-1 Do Begin
  Case Symbols[I].Kind Of
   SYM_SUB:    KindStr := 'sub';
   SYM_LOC:    KindStr := 'loc';
   SYM_DATA:   KindStr := 'data';
   SYM_DEVHDR: KindStr := 'DeviceHeader';
   SYM_STRAT:  KindStr := 'Strategy';
   SYM_INTR:   KindStr := 'Interrupt';
   SYM_ENTRY:  KindStr := 'Entry';
   SYM_USER:   KindStr := 'user';
  Else KindStr := '?';
  End;
  WriteLn(MapF, FmtAddr(Symbols[I].Blk, Symbols[I].Addr), '  ', Pad(KindStr,13), '  ', Symbols[I].Name);
 End;
 If OptXref Then Begin
  WriteLn(MapF);
  WriteLn(MapF, 'References croisees :');
  For I := 0 To XRefCnt-1 Do
   WriteXRefLine(MapF, '  ', I);
 End;
 Close(MapF);
End;

{ ============================================================
  LIGNE DE COMMANDE
  ============================================================ }

Procedure ShowHelp;
Begin
 WriteLn('DISSYS v', DISSYS_VERSION, ' - Cette commande permet de lancer le d'+#130+'sassembleur de ',
         'noyaux et pilotes DOS.');
 WriteLn('Cible MSDOS.SYS, IO.SYS, et tout pilote DEVICE= (.SYS ou .EXE resident :');
 WriteLn('HIMEM.SYS, EMM386.EXE, SMARTDRV.EXE, ANSI.SYS, un pilote CD-ROM, etc.).');
 WriteLn;
 WriteLn('Syntaxe : DISSYS fichier [options]');
 WriteLn;
 WriteLn('Options generales :');
 WriteLn('  /O:fichier       Fichier de sortie .ASM (defaut : meme nom, extension .ASM)');
 WriteLn('  /LIST:fichier    Alias de /O (listing de desassemblage)');
 WriteLn('  /MAP:fichier     Produit une carte des symboles + references croisees');
 WriteLn('  /CPU:niveau      8086 | 186 | 286 | 386 | 486 | AUTO (defaut AUTO)');
 WriteLn('  /ORG:adresse     Adresse d''origine du premier octet de l''image');
 WriteLn('  /BASE:adresse    Adresse de chargement supposee (informative)');
 WriteLn('  /ENTRY:adresse   Force un point d''entree supplementaire a analyser');
 WriteLn('  /SEG:segment     Prefixe SEG: affiche devant chaque adresse');
 WriteLn('  /FMT:format      SYS | COM | EXE | RAW | AUTO (defaut AUTO)');
 WriteLn('  /DOS:version     3.30 | 5.00 | 6.22 | ... (filtre les fonctions connues)');
 WriteLn('  /ASM:syntaxe     MASM | TASM | NASM (defaut MASM)');
 WriteLn;
 WriteLn('Blocs de segments multiples (suivre CALL/JMP FAR entre plusieurs dumps) :');
 WriteLn('  /SEG:xxxx=fichier.bin  Charge un bloc de SEGMENT SUPPLEMENTAIRE (repetable) -');
 WriteLn('                   un dump brut de 64 Ko representant le segment xxxx. Un');
 WriteLn('                   CALL/JMP FAR direct du fichier /O (ou d''un autre bloc)');
 WriteLn('                   dont le segment correspond est alors REELLEMENT SUIVI,');
 WriteLn('                   comme un vrai CPU le ferait en changeant CS - au lieu de');
 WriteLn('                   s''arreter net ("segment non resoluble dans cette image").');
 WriteLn('  /FARPTR:[xxxx:]yyyy    Sonde manuelle (repetable) : lit un pointeur FAR');
 WriteLn('                   (mot offset puis mot segment) a l''offset yyyy du bloc');
 WriteLn('                   xxxx (bloc 0 = fichier /O si omis) et le suit si son');
 WriteLn('                   segment correspond a un bloc charge - utile pour du code');
 WriteLn('                   atteint UNIQUEMENT via une table de sauts en donnees,');
 WriteLn('                   qu''aucune analyse de flux statique ne peut decouvrir seule.');
 WriteLn;
 WriteLn('Mode de parcours :');
 WriteLn('  /R               Desassemblage RECURSIF (suit CALL/JMP/Jcc) - defaut');
 WriteLn('  /L               Desassemblage LINEAIRE de tout l''intervalle en plus de /R');
 WriteLn;
 WriteLn('Analyse et annotation :');
 WriteLn('  /DATA            Marque les octets non-code restants comme donnees');
 WriteLn('  /STRINGS         Identifie les chaines ASCII imprimables');
 WriteLn('  /INT             Annote les instructions INT connues');
 WriteLn('  /API             Decode AH/AL des fonctions DOS/BIOS connues (implique /INT)');
 WriteLn('  /DRV             Analyse les structures de pilote (Device Header/Strategy/Interrupt)');
 WriteLn('  /HDR             Affiche/analyse les en-tetes reconnus');
 WriteLn('  /RELOC           Informations de relogement (fichiers EXE)');
 WriteLn('  /SYMBOLS         Genere des noms symboliques (sub_/loc_/data_/...)');
 WriteLn('  /COMMENTS        Ajoute les commentaires explicatifs (implique /SYMBOLS)');
 WriteLn('  /BYTES           Affiche les octets machine devant chaque instruction');
 WriteLn('  /ADDR            Affiche l''adresse devant chaque instruction');
 WriteLn('  /XREF            Genere les references croisees');
 WriteLn;
 WriteLn('Profils d''analyse DOS (activent plusieurs options a la fois) :');
 WriteLn('  /SYS             Analyse generale d''un fichier systeme DOS');
 WriteLn('  /DRIVER          Analyse complete d''un pilote de peripherique');
 WriteLn('  /KERNEL          Recherche les structures internes du noyau DOS');
 WriteLn('  /XMS             Recherche les structures/fonctions XMS (INT 2Fh/43xx)');
 WriteLn('  /EMS             Recherche les mecanismes EMS (INT 2Fh/46xx)');
 WriteLn('  /BIOS            Recherche les appels BIOS (INT 10h/13h/15h/1Ah)');
 WriteLn('  /DOSAPI          Decode INT 20h/21h/25h/26h/27h/2Fh');
 WriteLn('  /DPB             Signale les acces au Drive Parameter Block (INT 21h/32h)');
 WriteLn('  /SFT             Signale les acces a la System File Table (INT 21h/52h)');
 WriteLn('  /MCB             Signale les motifs de verification de signature MCB (''M''/''Z'')');
 WriteLn('  /INDOS           Signale les acces au drapeau InDOS (INT 21h/34h)');
 WriteLn;
 WriteLn('Divers :');
 WriteLn('  /Q               Mode silencieux (pas de resume sur la console)');
 WriteLn('  /V               Mode detaille (affiche la progression sur la console)');
 WriteLn('  /?               Affiche cette aide');
 WriteLn;
 WriteLn('Toutes les options /SWITCH:valeur acceptent aussi la forme "/SWITCH valeur"');
 WriteLn('(deux arguments separes) - la syntaxe est volontairement flexible.');
 Halt(0);
End;

Function ExtractSwitchValue(Arg: TString; Var SwName: TString; Var HasVal: Boolean): TString;
Var P: Integer;
Begin
 HasVal := False;
 P := Pos(':', Arg);
 If P > 0 Then Begin
  SwName := UpStr(Copy(Arg, 2, P-2));
  ExtractSwitchValue := Copy(Arg, P+1, Length(Arg)-P);
  HasVal := True;
 End Else Begin
  SwName := UpStr(Copy(Arg, 2, Length(Arg)-1));
  ExtractSwitchValue := '';
 End;
End;

{ IMPORTANT : les profils ci-dessous n'activent JAMAIS individuellement
  OptXms/OptEms/OptBios/OptDosApi/OptDpb/OptSft/OptIndos - ces commutateurs
  sont INTENTIONNELLEMENT restrictifs (voir CategoryEnabled : des qu'UN
  SEUL est actif, l'annotation se limite a SA categorie) pour un usage
  AUTONOME et cible ("/DPB seul" = ne montrer QUE les acces DPB). Un
  profil veut au contraire une couverture LARGE : il se contente donc de
  OptIntAnnot+OptApiAnnot (aucune categorie restrictive active => tout est
  annote, voir CategoryEnabled). Seul OptMcb est mis a part : c'est une
  passe heuristique additive separee (ScanMcbPatterns), pas un filtre de
  CategoryEnabled, donc sans effet secondaire a l'activer dans un profil. }
Procedure ApplyProfile(Profile: TString);
Begin
 Profile := UpStr(Profile);
 If Profile = 'SYS' Then Begin
  OptModeSys := True;
  OptHdr := True; OptDrv := True; OptIntAnnot := True; OptApiAnnot := True;
  OptSymbols := True; OptComments := True; OptXref := True; OptData := True;
  OptStrings := True; OptMcb := True;
 End Else If Profile = 'DRIVER' Then Begin
  OptModeDriver := True;
  OptHdr := True; OptDrv := True; OptIntAnnot := True; OptApiAnnot := True;
  OptSymbols := True; OptComments := True; OptXref := True; OptMcb := True;
 End Else If Profile = 'KERNEL' Then Begin
  OptModeKernel := True;
  OptSymbols := True; OptComments := True; OptXref := True;
  OptIntAnnot := True; OptApiAnnot := True; OptMcb := True;
  OptData := True; OptStrings := True;
 End;
End;

Procedure ParseArgs;
Var I, EqPos: Integer; Arg, SwName, SwVal: TString; HasVal: Boolean; GotFile: Boolean;
Begin
 InputFileName  := '';
 OutputFileName := '';
 MapFileName    := '';
 OptFormat      := FMT_AUTO;
 OptCPU         := CPU_AUTO;
 OptAsmSyntax   := SYN_MASM;
 OptOrg         := 0; OptHasOrg := False;
 OptBase        := 0; OptHasBase := False;
 OptEntry       := 0; OptHasEntry := False;
 OptSeg         := 0; OptHasSeg := False;
 OptDosVerMajor := 6; OptDosVerMinor := 22;

 OptRecursive := True;  { toujours actif - /R le rend simplement explicite }
 OptLinear    := False;
 OptData      := False;
 OptStrings   := False;
 OptIntAnnot  := False;
 OptApiAnnot  := False;
 OptDrv       := False;
 OptHdr       := False;
 OptReloc     := False;
 OptSymbols   := False;
 OptComments  := False;
 OptBytes     := False;
 OptAddr      := True;
 OptXref      := False;
 OptQuiet     := False;
 OptVerbose   := False;

 OptModeSys := False; OptModeDriver := False; OptModeKernel := False;
 OptXms := False; OptEms := False; OptBios := False; OptDosApi := False;
 OptDpb := False; OptSft := False; OptMcb := False; OptIndos := False;
 OptUseMap := False;

 PendingSegCnt := 0;
 FarProbeCnt := 0;

 GotFile := False;
 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If Arg = '' Then Begin Inc(I); Continue; End;

  If (Arg = '/?') Or (Arg = '-?') Or (UpStr(Arg) = '/H') Or
     (UpStr(Arg) = '--HELP') Or (UpStr(Arg) = '-H') Then
   ShowHelp
  Else If (Arg[1] = '/') Or (Arg[1] = '-') Then Begin
   SwVal := ExtractSwitchValue(Arg, SwName, HasVal);
   If (Not HasVal) And
      ((SwName = 'O') Or (SwName = 'LIST') Or (SwName = 'MAP') Or (SwName = 'CPU') Or
       (SwName = 'ORG') Or (SwName = 'BASE') Or (SwName = 'ENTRY') Or
       (SwName = 'SEG') Or (SwName = 'FMT') Or (SwName = 'DOS') Or (SwName = 'ASM') Or
       (SwName = 'FARPTR')) And
      (I < ParamCount) Then Begin
    Inc(I);
    SwVal := ParamStr(I);
    HasVal := True;
   End;

   If SwName = 'O' Then OutputFileName := SwVal
   Else If SwName = 'LIST' Then OutputFileName := SwVal
   Else If SwName = 'MAP' Then Begin MapFileName := SwVal; OptUseMap := True; End
   Else If SwName = 'CPU' Then Begin
    SwVal := UpStr(SwVal);
    If SwVal = '8086' Then OptCPU := CPU_8086
    Else If SwVal = '186' Then OptCPU := CPU_186
    Else If SwVal = '286' Then OptCPU := CPU_286
    Else If SwVal = '386' Then OptCPU := CPU_386
    Else If SwVal = '486' Then OptCPU := CPU_486
    Else OptCPU := CPU_AUTO;
   End
   Else If SwName = 'ORG' Then Begin OptOrg := HexStrToLong(SwVal); OptHasOrg := True; End
   Else If SwName = 'BASE' Then Begin OptBase := HexStrToLong(SwVal); OptHasBase := True; End
   Else If SwName = 'ENTRY' Then Begin OptEntry := HexStrToLong(SwVal); OptHasEntry := True; End
   Else If SwName = 'SEG' Then Begin
    { "/SEG:xxxx" (forme historique, un seul bloc) : fixe juste le segment
      d'affichage du fichier /O. "/SEG:xxxx=fichier.bin" (NOUVEAU, repetable) :
      charge un bloc de SEGMENT SUPPLEMENTAIRE - voir TSegBlock / l'enquete
      HIMEM/MS-DOS 6.22 qui a motive cette extension (suivre un CALL/JMP FAR
      a travers plusieurs dumps memoire distincts). }
    EqPos := Pos('=', SwVal);
    If EqPos > 0 Then Begin
     If PendingSegCnt < MAX_SEGBLOCKS Then Begin
      PendingSegVal[PendingSegCnt]  := Word(HexStrToLong(Copy(SwVal, 1, EqPos-1)));
      PendingSegFile[PendingSegCnt] := Copy(SwVal, EqPos+1, Length(SwVal)-EqPos);
      Inc(PendingSegCnt);
     End;
    End Else Begin
     OptSeg := Word(HexStrToLong(SwVal)); OptHasSeg := True;
    End;
   End
   Else If SwName = 'FARPTR' Then Begin
    { "/FARPTR:[xxxx:]yyyy" (repetable) : a l'offset yyyy du bloc xxxx (ou du
      bloc 0 si omis), lit un pointeur FAR (mot offset puis mot segment,
      convention x86 standard) et le suit s'il tombe sur un segment charge -
      utile pour atteindre du code qu'AUCUNE analyse de flux statique ne
      peut decouvrir seule (appele uniquement via une table de sauts en
      donnees, jamais par un CALL/JMP FAR direct). }
    If FarProbeCnt < MAX_FARPROBES Then Begin
     EqPos := Pos(':', SwVal);
     If EqPos > 0 Then Begin
      FarProbeSeg[FarProbeCnt]    := Word(HexStrToLong(Copy(SwVal, 1, EqPos-1)));
      FarProbeOfs[FarProbeCnt]    := Word(HexStrToLong(Copy(SwVal, EqPos+1, Length(SwVal)-EqPos)));
      FarProbeHasSeg[FarProbeCnt] := True;
     End Else Begin
      FarProbeOfs[FarProbeCnt]    := Word(HexStrToLong(SwVal));
      FarProbeHasSeg[FarProbeCnt] := False;
     End;
     Inc(FarProbeCnt);
    End;
   End
   Else If SwName = 'FMT' Then Begin
    SwVal := UpStr(SwVal);
    If SwVal = 'SYS' Then OptFormat := FMT_SYS
    Else If SwVal = 'COM' Then OptFormat := FMT_COM
    Else If SwVal = 'EXE' Then OptFormat := FMT_EXE
    Else If SwVal = 'RAW' Then OptFormat := FMT_RAW
    Else OptFormat := FMT_AUTO;
   End
   Else If SwName = 'DOS' Then Begin
    { Accepte "6.22", "6,22" ou simplement "6" - separateur ignore, le
      reste est la partie mineure (0 si absente). }
    ParseDosVersion(SwVal, OptDosVerMajor, OptDosVerMinor);
   End
   Else If SwName = 'ASM' Then Begin
    SwVal := UpStr(SwVal);
    If SwVal = 'TASM' Then OptAsmSyntax := SYN_TASM
    Else If SwVal = 'NASM' Then OptAsmSyntax := SYN_NASM
    Else OptAsmSyntax := SYN_MASM;
   End
   Else If SwName = 'R' Then OptRecursive := True
   Else If SwName = 'L' Then OptLinear := True
   Else If SwName = 'DATA' Then OptData := True
   Else If SwName = 'STRINGS' Then OptStrings := True
   Else If SwName = 'INT' Then OptIntAnnot := True
   Else If SwName = 'API' Then Begin OptApiAnnot := True; OptIntAnnot := True; End
   Else If SwName = 'DRV' Then Begin OptDrv := True; OptHdr := True; End
   Else If SwName = 'HDR' Then OptHdr := True
   Else If SwName = 'RELOC' Then OptReloc := True
   Else If SwName = 'SYMBOLS' Then OptSymbols := True
   Else If SwName = 'COMMENTS' Then Begin OptComments := True; OptSymbols := True; End
   Else If SwName = 'BYTES' Then OptBytes := True
   Else If SwName = 'ADDR' Then OptAddr := True
   Else If SwName = 'XREF' Then OptXref := True
   Else If SwName = 'Q' Then OptQuiet := True
   Else If SwName = 'V' Then OptVerbose := True
   Else If SwName = 'SYS' Then ApplyProfile('SYS')
   Else If SwName = 'DRIVER' Then ApplyProfile('DRIVER')
   Else If SwName = 'KERNEL' Then ApplyProfile('KERNEL')
   Else If SwName = 'XMS' Then Begin OptXms := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'EMS' Then Begin OptEms := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'BIOS' Then Begin OptBios := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'DOSAPI' Then Begin OptDosApi := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'DPB' Then Begin OptDpb := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'SFT' Then Begin OptSft := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else If SwName = 'MCB' Then Begin OptMcb := True; OptSymbols := True; OptComments := True; End
   Else If SwName = 'INDOS' Then Begin OptIndos := True; OptIntAnnot := True; OptApiAnnot := True; OptComments := True; OptSymbols := True; End
   Else Begin
    WriteLn('Option inconnue : ', Arg);
    Halt(1);
   End;
  End
  Else If Not GotFile Then Begin
   InputFileName := Arg;
   GotFile := True;
  End;
  Inc(I);
 End;

 If InputFileName = '' Then Begin
  WriteLn('Erreur : aucun fichier d''entree specifie.');
  WriteLn('Utilisez DISSYS /? pour l''aide.');
  Halt(1);
 End;
 If OutputFileName = '' Then
  OutputFileName := ChangeFileExt(InputFileName, '.ASM');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Var
 MainB: Integer; MainI: Integer;
 ProbeSrcBlk, ProbeDstBlk: Integer; ProbeFarOfs, ProbeFarSeg: Word; ProbeTargetAddr: LongInt;
BEGIN
 ParseArgs;

 If Not OptQuiet Then Begin
  WriteLn('DISSYS v', DISSYS_VERSION, ' - desassemblage de ', InputFileName);
 End;

 If OptVerbose Then WriteLn('[V] Construction des tables d''opcodes (8086-80486)...');
 BuildOpcodeTables;

 If Not LoadImageFile(InputFileName) Then Halt(1);
 If Not OptQuiet Then WriteLn('Image chargee : ', ImageSize, ' octets.');

 SymbolCnt := 0;
 XRefCnt := 0;
 WorkQueueCnt := 0;
 DecodedCnt := 0;
 SegBlockCnt := 0;

 If OptVerbose Then WriteLn('[V] Detection du format et des points d''entree...');
 SetupFormatAndEntries;
 If OptVerbose Then Begin
  WriteLn('[V] Format retenu     : ', FormatName);
  WriteLn('[V] Origine (ORG)     : ', HexWord(Word(OptOrg)));
  If OptHasEntry Then WriteLn('[V] Point d''entree    : ', FmtAddr(0, OptEntry));
  If HasDeviceHeader Then WriteLn('[V] Device Header reconnu - Strategy/Interrupt mis en file.');
 End;

 RegisterBlock0;

 { Blocs de segments SUPPLEMENTAIRES (/SEG:xxxx=fichier.bin) - charges
   maintenant que le bloc 0 a pris sa place (index 0 garanti). }
 For MainI := 0 To PendingSegCnt-1 Do Begin
  If LoadExtraSegBlock(PendingSegVal[MainI], PendingSegFile[MainI]) Then Begin
   If Not OptQuiet Then
    WriteLn('Bloc supplementaire charge : segment ', HexWord(PendingSegVal[MainI]),
     ' <- ', PendingSegFile[MainI], ' (', SegBlocks[SegBlockCnt-1].ImageSize, ' octets)');
  End;
 End;
 If (SegBlockCnt > 1) And OptVerbose Then
  WriteLn('[V] ', SegBlockCnt, ' blocs de segments charges au total.');

 { Sondes de pointeur FAR manuelles (/FARPTR:[xxxx:]yyyy) - lues et suivies
   AVANT le moteur recursif, pour que leurs cibles (si resolues) soient
   dans la file d'attente initiale exactement comme un point d'entree. }
 For MainI := 0 To FarProbeCnt-1 Do Begin
  If FarProbeHasSeg[MainI] Then ProbeSrcBlk := FindBlockBySeg(FarProbeSeg[MainI])
  Else ProbeSrcBlk := 0;
  If ProbeSrcBlk < 0 Then Begin
   If Not OptQuiet Then WriteLn('Avertissement /FARPTR : segment source ', HexWord(FarProbeSeg[MainI]), ' non charge, sonde ignoree.');
   Continue;
  End;
  ProbeFarOfs := GetWordAtBlk(ProbeSrcBlk, FarProbeOfs[MainI]);
  ProbeFarSeg := GetWordAtBlk(ProbeSrcBlk, LongInt(FarProbeOfs[MainI]) + 2);
  ProbeDstBlk := FindBlockBySeg(ProbeFarSeg);
  If ProbeDstBlk < 0 Then Begin
   If Not OptQuiet Then WriteLn('/FARPTR a ', FmtAddr(ProbeSrcBlk, OfsToAddrBlk(ProbeSrcBlk, FarProbeOfs[MainI])),
    ' pointe vers ', HexWord(ProbeFarSeg), ':', HexWord(ProbeFarOfs), ' - segment non charge, non suivi.');
   Continue;
  End;
  ProbeTargetAddr := OfsToAddrBlk(ProbeDstBlk, LongInt(ProbeFarOfs));
  AddSymbol(ProbeDstBlk, ProbeTargetAddr, SYM_ENTRY, AutoSymbolName(ProbeDstBlk, ProbeTargetAddr, SYM_ENTRY));
  QueuePush(ProbeDstBlk, ProbeTargetAddr);
  If Not OptQuiet Then WriteLn('/FARPTR a ', FmtAddr(ProbeSrcBlk, OfsToAddrBlk(ProbeSrcBlk, FarProbeOfs[MainI])),
   ' suivi vers ', FmtAddr(ProbeDstBlk, ProbeTargetAddr), '.');
 End;

 If OptVerbose Then WriteLn('[V] Moteur recursif (file d''attente initiale : ', WorkQueueCnt, ' adresse(s))...');
 RunRecursiveEngine;
 If OptVerbose Then WriteLn('[V] Moteur recursif termine : ', DecodedCnt, ' instruction(s) decodee(s).');

 If OptLinear Then Begin
  If OptVerbose Then WriteLn('[V] Passe lineaire (/L) sur le bloc 0...');
  RunLinearPass(0, OfsToAddrBlk(0, 0), OfsToAddrBlk(0, SegBlocks[0].ImageSize));
 End;

 If OptData Or OptStrings Then Begin
  If OptVerbose Then WriteLn('[V] Detection de donnees/chaines dans les octets restants (tous blocs)...');
  For MainB := 0 To SegBlockCnt-1 Do RunDataDetection(MainB);
 End;

 If OptMcb And OptVerbose Then WriteLn('[V] Recherche de motifs de signature MCB (''M''/''Z'')...');
 ScanMcbPatterns;

 If OptReloc And OptHdr And (Not OptQuiet) And (OptFormat = FMT_EXE) Then
  WriteLn('Remarque /RELOC : les cibles de CALL/JMP FAR vers un segment non charge',
          ' via /SEG:xxxx=fichier.bin ne sont pas resolues.');

 {$I-}
 Assign(OutF, OutputFileName);
 Rewrite(OutF);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de creer ', OutputFileName);
  Halt(1);
 End;

 WriteListing;
 Close(OutF);

 WriteMapFile;

 If Not OptQuiet Then Begin
  WriteLn('Instructions decodees : ', DecodedCnt);
  WriteLn('Symboles generes      : ', SymbolCnt);
  WriteLn('References croisees   : ', XRefCnt);
  WriteLn('Sortie ecrite dans    : ', OutputFileName);
  If OptUseMap Then WriteLn('Carte des symboles    : ', MapFileName);
 End;
END.
