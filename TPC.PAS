{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal)
  @description: Clone du compilateur en ligne de commande Turbo Pascal 7.0 (TPC)
  @license: MIT
}

Program TPC;

{ Clone de TPC.EXE de Turbo Pascal 7.0 (mode reel, cible DOS 8086).
  Base sur le clone du compilateur Turbo Pascal 6.0 (TURBOPASCAL6-0/TPC.PAS)
  avec les evolutions propres a la version 7.0 :
   - unites au format TPUQ (signature 'TPUQ', en-tete de 96 octets, taille
     de la section symboles a l'offset $1E), voir DOC/TPU_FORMAT.txt;
     une unite TPU9 (6.0) ou plus ancienne provoque l'erreur 70;
   - type predefini PChar (^Char) et syntaxe etendue $X+ : constante chaine
     affectable a un PChar, tableau de Char base 0 compatible PChar,
     indexation P[i], arithmetique P+n, P-n, P-Q, comparaisons, Inc/Dec,
     Write/WriteLn d'un PChar, constantes typees PChar;
   - procedures standard Break et Continue dans FOR, WHILE et REPEAT
     (erreur 109 hors d'une boucle);
   - instruction CASE (etiquettes, intervalles, ELSE);
   - fonctions High, Low et Assigned; procedures Include et Exclude;
   - type OpenString et commutateurs $P (chaines ouvertes), $Q (controle de
     debordement, erreur d'execution 215) et $T (pointeurs types pour @);
   - mots reserves INHERITED, LIBRARY et EXPORTS;
   - valeurs par defaut des commutateurs identiques a TPC 7.0 :
     A+ B- D+ E+ F- G- I+ L+ N- O- P- Q- R- S+ T- V+ X+;
   - messages du compilateur en francais, numeros d'erreurs de la table de
     Turbo Pascal 7.0, affichage FICHIER(ligne) et resume
     "n lignes, s secondes, c octets de code, d octets de donnees";
   - unites standard CRT, DOS, STRINGS et PRINTER integrees (sources Pascal
     embarques, compiles a la demande quand aucune TPU n'est trouvee);
   - disposition memoire de TP: code en CS, constantes et chaines en DS,
     variables globales non initialisees apres les constantes (hors de
     l'EXE, remises a zero au demarrage), temporaires des expressions
     chaine dans la frame de la procedure, pile separee;
   - erreurs d'execution "Erreur d'execution NNN a SSSS:OOOO." (numero sur
     trois chiffres comme TP), codes 100..106 des fichiers comme TP;
   - tableaux de caracteres compatibles chaine dans les expressions
     (concatenation, Copy, Length, Write, ReadLn, tableau := constante),
     pliage des constantes chaine juxtaposees, Type(Variable) := valeur,
     TRec(Pointer(P)^), constantes typees pointeur = @Variable, constante
     chaine pour un parametre "array of Char" ouvert, System.Ident, ^M^J;
   - typage Word/Integer de TP (Word shl n reste Word, Word op Integer
     donne un Longint, comparaison Word/Integer en 32 bits);
   - assembleur integre: expressions constantes (+ - * / NOT AND OR SHL SHR,
     LOW/HIGH, 5Ch*4, TRUE/FALSE), @Result, Var.Word[n], OFFSET d'une
     variable locale, d'une procedure ou d'un Type.Champ, saut vers une
     etiquette Pascal.
  La conformite a ete verifiee en compilant les 525 sources du projet CORAIL
  et en comparant les executables a ceux de Borland sous DOSBox, voir
  DOC/CORAIL_TPC_TESTS.txt et TESTS/CORAIL_TPC/.
  Contrainte du projet: tout dans TPC.PAS, aucun fichier d'inclusion,
  aucune unite auxiliaire; Uses DOS uniquement.
  Hote valide: Free Pascal 3.2, mode TP, strings courts uniquement.
  Cible: DOS MZ multi-segments, instructions 8086, CS/DS local et pile separee.
  Imports OMF86 Use16 via $L/$LINK; routines EXTERNAL Pascal far.
  Restrictions explicites: ABI Borland partielle (ordinaux 8/16 bits),
  objets, types proceduraux, resultats structures et ABI reelle Borland.
  Real48 logiciel, expressions mixtes, fonctions math et I/O locales.
  N+/E+: emulation locale des instructions 8087, precision interne 48 bits.
  Directives/includes, controles R/S/B/Q, assembleur 8086/286 et 8087 materiel.
  Types locaux: Longint, tableaux, records fixes/variants, sets, pointeurs,
  PChar, File/Text; parametres structures, chaines locales et runtime
  standard DOS partiel. Dictionnaire par unite/portee; types nommes
  ordinaux/chaine, constantes calculees et typees, frames locales et liens
  statiques pour procedures.
  /B recompile les sources et produit des fichiers TPU; /M ne recompile que
  les unites dont le source est plus recent que la TPU.
  Unites de code: conteneur TPUQ marque profil TPC1, ABI locale near,
  incompatible ABI Borland. TURBO.TPL: index TPUQ concatene, lecture directe
  par tranche, import des constantes et routines Borland.
  La compatibilite avec le linker Borland n'a pas ete validee.
  Les fonctionnalites manquantes ont un diagnostic propre sans faux numero TP.
  Extensions locales non documentees dans l'aide: --inspect-tpu=fichier,
  --inspect-tpl=fichier, --quiet, --help. }
{$A-}
{$IFDEF FPC}
{$MODE TP}
{$H-}
{$ENDIF}
{$R-}{$Q-}

Uses Dos;

Const
 MaxSource = 262144;
 MaxImage = 65520;
 MaxSymbols = 4096;
 MaxFixups = 32768;
 MaxDefines = 128;
 MaxUnits = 64;
 MaxLibraryUnits = 256;
 tkEOF=0;
 tkIdent=1;
 tkConstant=2;
 tkPlus=3;
 tkMinus=4;
 tkTimes=5;
 tkSlash=6;
 tkEqual=7;
 tkNE=8;
 tkGreater=9;
 tkLess=10;
 tkGE=11;
 tkLE=12;
 tkLP=13;
 tkRP=14;
 tkLB=15;
 tkRB=16;
 tkDot=17;
 tkComma=18;
 tkColon=19;
 tkSemi=20;
 tkCaret=21;
 tkAssign=22;
 tkRange=23;
 tkAt=24;
 tkAnd=28;
 tkArray=29;
 tkBegin=30;
 tkExports=43;
 tkInherited=75;
 tkCase=31;
 tkConst=32;
 tkConstructor=33;
 tkDestructor=34;
 tkDiv=35;
 tkDo=36;
 tkDownto=37;
 tkElse=38;
 tkEnd=39;
 tkAsm=40;
 tkFile=41;
 tkFor=42;
 tkFunction=44;
 tkGoto=45;
 tkIf=46;
 tkImplementation=47;
 tkIn=48;
 tkInline=49;
 tkInterface=50;
 tkLibrary=51;
 tkLabel=52;
 tkMod=53;
 tkNil=54;
 tkNot=55;
 tkObject=56;
 tkOf=57;
 tkOr=58;
 tkPacked=59;
 tkProcedure=60;
 tkProgram=61;
 tkRecord=62;
 tkRepeat=63;
 tkSet=64;
 tkShl=65;
 tkShr=66;
 tkString=67;
 tkThen=68;
 tkType=69;
 tkTo=70;
 tkUnit=71;
 tkUntil=72;
 tkUses=73;
 tkVar=74;
 tkWhile=76;
 tkWith=77;
 tkXor=78;
 ttVoid=0;
 ttArray=1;
 ttRecord=2;
 ttObject=3;
 ttFile=4;
 ttText=5;
 ttProc=6;
 ttSet=7;
 ttPointer=8;
 ttString=9;
 tt8087=10;
 ttReal=11;
 ttInteger=12;
 ttBoolean=13;
 ttChar=14;
 ttEnum=15;
 skVar=1;
 skConst=2;
 skProc=3;
 skForeign=4;
 skType=5;
 skLabel=6;
 MaxTypes=512;
 MaxScopes=1024;
 MaxTemps=32;                 { temporaires chaine/reel simultanes par instruction }
 MaxNativeParams = 16;
 MaxNativeRefs = 4096;
 MaxObjects = 64;
 MaxObjSegments = 256;
 MaxObjNames = 512;
 MaxObjGroups = 128;
 MaxLinkedImage = 524288;
 MaxFields = 512;
 TPUHeaderSize = 96;   { en-tete TPUQ de Turbo Pascal 7.0 }
 TPUVersion = 'Q';     { octet de version: 'Q' = 7.0 mode reel }
 MaxDebugEntries = 8192;
 MaxLoopJumps = 1024;  { sauts Break/Continue en attente }

Type
 TShortString = String[255];
  { Packed + Word: jamais de pointeurs natifs 32/64 bits dans une TPU. }
 { En-tete TPUQ (Turbo Pascal 7.0): 96 octets ($60). Par rapport a TPU9,
   un mot (Browser, offset $1C) precede EndTrace, qui est donc la taille de
   la section symboles a l'offset $1E, voir DOC/TPU_FORMAT.txt. }
 TUnitHeader = Packed Record
  Signature: Array[0..3] Of Char;
  Next, Link, Name, Interf, ProcMap, CodeMap, ConstMap, DataMap: Word;
  EndMaps, Units, Sources, Trace, Browser, EndTrace: Word;
  CodeSize, ConstSize, CodeFixupSize, DataFixupSize, DataSize: Word;
  DebugHash, Flags, CodeStart, CodeLength, OverlayLength: Word;
  TpuName, CodeSeg, ConstSeg, CodeFixupSeg, ConstFixupSeg: Word;
  Reserved: Array[0..16] Of Word;
 End;
 TTypeDescriptor = Packed Record
  Typ, Modifier: Byte;
  SizeOfType, Next: Word;
 End;
 TSymbolPrefix = Packed Record
  Prev: Word;
  Typ, NameLength: Byte;
 End;
 TFarAddress = Packed Record
  Offs, Segm: Word
 End;
 TTPUFixup = Packed Record
  UnitRef, Map, Target, Offs: Word
 End;
 TSegMap = Packed Record
  Addr, Len, FixupLength, Owner: Word
 End;
 TProcMap = Packed Record
  Stub, Flags, CodeMap, EntryPoint: Word
 End;
 TSymbol = Record
  Name: String[63];
  Kind, Typ, Width: Byte;
  Capacity: Byte;
  Addr: Word;
  Owner: Byte;
  Exported, HasBody: Boolean;
  ForwardJump: Word;
  Value: Longint;
  StrValue: TShortString;
  Native: Boolean;
  NativeMap: Word;
  NativeConst: Boolean;
  ParamCount: Byte;
  ParamTypes, ParamWidths, ParamFlags: Array[1..MaxNativeParams] Of Byte;
  SignedByte: Boolean;
  ParamSigned: Array[1..MaxNativeParams] Of Boolean;
  Scope, HashNext, TypeId: Word;
  Local: Boolean;
  ByReference, ResultVariable, FarRoutine, ForwardDeclared: Boolean;
  LegacyCall: Boolean;
  AssemblerBody: Boolean;
  InlineBody: Boolean;       { Procedure X; Inline(...) }
  DebugVisible: Boolean;
  DebugLine, DebugColumn: Word;
  DebugFile: TShortString;
  RoutineSymbol, ResultSymbol, ParamBytes: Word;
  ResultBuffer: Word;
  WithOffset: Word;          { champ d'un WITH: deplacement apres le pointeur }
  IsAbsolute: Boolean;       { ABSOLUTE seg:ofs }
  AbsoluteSeg: Word;
  ParamTypeIds: Array[1..MaxNativeParams] Of Word;
  ParamNames: Array[1..MaxNativeParams] Of String[63];
 End;
 TTypeInfo = Packed Record
  Typ, Width, Capacity: Byte;
  Signed: Boolean;
  Base: Word;
  LowBound, HighBound: Longint;
  IdentityUnit, IdentityName: String[63];
 End;
 { Temporaires d'expression (resultats de concatenation, Copy, Concat,
   formatage de reels): dans la frame de la procedure (reutilises d'une
   instruction a l'autre comme TP) ou, pour le programme principal, dans un
   petit pool statique reutilise. }
 TTempPool = Record
  Addr, Size: Array[1..MaxTemps] Of Word;
  Count, Used: Byte;
 End;
 TScopeInfo = Record
  Parent, ProcSymbol, LocalSize: Word;
  LinkOffset: Word;
  Owner: Byte;
  Pseudo: Boolean;           { portee d'un WITH: pas de frame propre }
  Temps: TTempPool;
 End;
 TTypeExtra = Record
  Size, ElementType, IndexType, FirstField, FieldCount: Word;
  ForwardName: String[63];
 End;
 TRecordField = Packed Record
  Name: String[63];
  TypeId, Offset, Next: Word;
 End;
 TConstValue = Record
  TypeId: Word;
  Value: Longint;
  RealValue: Double;
  Text: TShortString;
 End;
 TAddressFixup = Record
  Position, DataOffset: Word
 End;
 TRelativeFixup = Record
  Position, Target: Word
 End;
 TCondition = Record
  ParentActive, Test, SeenElse: Boolean
 End;
 TUnitSet = Set Of 0..MaxUnits;
 TBuildUnit = Record
  Name: String[63];
  State: Byte;
 { 1 = compilation en cours; 2 = compilee }
  InterfaceReady, HasInit: Boolean;
  InitAddress: Word;
  FromSource, Embedded: Boolean;
  Path: TShortString;
  Dependencies: TUnitSet;
  NativeDependencies: TUnitSet;
  DependencyChecks: Array[1..MaxUnits] Of Word;
  Checksum: Word;
  CodeBase, DataBase: Word;
  LibraryEntry: Word;
 End;
 TLibraryEntry = Record
  Name: String[63];
  Offset, Size: Longint;
  Header: TUnitHeader;
 End;
 TBinaryBuffer = Array[0..262143] Of Byte;
 PBinaryBuffer = ^TBinaryBuffer;
 TNativeRef = Record
  Position, Map, Target: Word;
  U, Kind: Byte
 End;
 TMZRelocation = Packed Record
  Offs, Segm: Word
 End;
 TLinkedImage = Array[0..MaxLinkedImage-1] Of Byte;
 PLinkedImage = ^TLinkedImage;
 TObjectFile = Record
  Path: TShortString;
  Owner: Byte;
  Bytes: PBinaryBuffer;
  Length: Longint;
 End;
 TObjectSegment = Record
  Name, ClassName: String[63];
  Combine, Alignment: Byte;
  Root: Word;
  Length, Contribution, Base: Longint;
  Bytes: PBinaryBuffer;
 End;
 TObjectGroup = Record
  Name: String[63];
  Members: Array[1..MaxObjSegments] Of Word;
  Count: Word;
  Base: Longint;
 End;
 TObjectPublic = Record
  Name: String[63];
  Segment, GroupIndex, Offset: Word;
 End;
 TObjectFixup = Record
  Segment, Offset, FrameIndex, TargetIndex, Displacement: Word;
  Location, FrameMethod, TargetMethod: Byte;
  Relative: Boolean;
 End;
 TObjectCall = Record
  Name: String[63];
  Position: Word;
 End;
 TSourceBuffer = Array[1..MaxSource] Of Char;
 TDebugEntry = Record
  Kind,U: Byte;
  Address,Line,Column,Size: Word;
  FileName,Name: TShortString;
 End;
 TAsmOperand = Record
  Kind, Reg, RM, Segment: Byte;
  Width, Sym: Word;
  Displacement: Longint;
  Direct, OffsetValue, SegmentValue, CodeValue: Boolean;
  Name: String[63];
 End;
 PSourceBuffer = ^TSourceBuffer;
 PParserState = ^TParserState;
 TParserState = Record
  Buffer: PSourceBuffer;
  SourceName: TShortString;
  SourceSize, SourcePos: Longint;
  Line, Column, TokenLine, TokenColumn: Word;
  Token: Byte;
  TokenText: TShortString;
  TokenValue: Longint;
  TokenReal: Double; TokenIsReal: Boolean;
  TokenIsString, Active, InProcedure, InInterface: Boolean;
  CondDepth, CurrentUnit: Byte;
  Imports: TUnitSet;
  ImportOrder: Array[1..MaxUnits] Of Byte;
  ImportCount: Byte;
  Conditions: Array[1..32] Of TCondition;
  Defines: Array[1..MaxDefines] Of String[63];
  DefineCount, StackSize, MinHeap, MaxHeap: Word;
  OptionBits: Longint;
  CurrentScope: Word;
 End;

Var
 Source: Array[1..MaxSource] Of Char;
 IncludeStack: Array[1..16] Of PParserState;
 IncludeDepth: Byte;
 IncludeDirs: TShortString;
 InAssembler: Boolean;
 DebugEntries: Array[1..MaxDebugEntries] Of TDebugEntry;
 DebugCount: Word;
 DebugCaptured: TUnitSet;
 MapMode: Byte;
 DebugRequested, DebugInExe: Boolean;
 LookupRequested: Boolean;
 LookupAddress: Longint;
 UnitFeatures: Array[0..MaxUnits] Of Byte;
 FPUStartup, BssPatch: Word;
 RealReady,EmulatorReady: Boolean;
 RealCodeBase,RealCodeEnd,RealDataBase,RealDataEnd: Word;
 EmulatorCodeBase,EmulatorCodeEnd,EmulatorDataBase,EmulatorDataEnd: Word;
const RealSource: array[1..279] of string[255] = (
 '{$R-,S-,B-,N-,O-,D-,L-,Q-}',
 'type RBytes=array[0..5] of Byte;',
 '     Mant=array[0..2] of Word;',
 '     Float=record m:Mant; e:Integer; neg:Boolean end;',
 'procedure RInt(n:Longint; var r:RBytes); forward;',
 'procedure RCalc(op:Integer; var a,b,r:RBytes); forward;',
 'function RCmp(var a,b:RBytes):Integer; forward;',
 'function RTrunc(var a:RBytes; rounded:Boolean):Longint; forward;',
 'procedure RFormat(var a:RBytes; digits,width:Integer; var s:string); forward;',
 'procedure RParse(var s:string; var a:RBytes; var code:Integer); forward;',
 'procedure Zero(var a:Float); forward;',
 'function Empty(var a:Float):Boolean; forward;',
 'procedure Left(var a:Mant); forward;',
 'procedure Right(var a:Mant); forward;',
 'procedure Normalize(var a:Float); forward;',
 'procedure IntegerFloat(n:Longint; var a:Float); forward;',
 'procedure Unpack(var r:RBytes; var a:Float); forward;',
 'procedure Pack(a:Float; var r:RBytes); forward;',
 'procedure Add(a,b:Float; var r:Float); forward;',
 'procedure Multiply(a,b:Float; var r:Float); forward;',
 'procedure Divide(a,b:Float; var r:Float); forward;',
 'function Compare(a,b:Float):Integer; forward;',
 'function IntValue(a:Float; mode:Integer):Longint; forward;',
 'procedure MathOp(op:Integer; a:Float; var r:Float); forward;',
 '',
 'procedure Zero(var a:Float);',
 'begin FillChar(a,SizeOf(a),0); a.e:=-30000 end;',
 'function Empty(var a:Float):Boolean;',
 'begin Empty:=(a.m[0]=0) and (a.m[1]=0) and (a.m[2]=0) end;',
 'procedure Left(var a:Mant);',
 'var i:Integer; c,t:Word;',
 'begin c:=0; for i:=0 to 2 do begin t:=a[i] shr 15; a[i]:=(a[i] shl 1) or c; c:=t end end;',
 'procedure Right(var a:Mant);',
 'var i:Integer; c,t:Word;',
 'begin c:=0; for i:=2 downto 0 do begin t:=a[i] shl 15; a[i]:=(a[i] shr 1) or c; c:=t end end;',
 'function Mag(var a,b:Mant):Integer;',
 'var i,c:Integer;',
 'begin c:=0; i:=2; while (i>=0) and (c=0) do begin',
 ' if a[i]<b[i] then c:=-1 else if a[i]>b[i] then c:=1; Dec(i) end; Mag:=c end;',
 'procedure Sub(var a,b:Mant);',
 'var i:Integer; t:Longint; borrow:Word;',
 'begin borrow:=0; for i:=0 to 2 do begin t:=Longint(a[i])-b[i]-borrow;',
 ' if t<0 then borrow:=1 else borrow:=0; a[i]:=Word(t) end end;',
 'procedure Normalize(var a:Float);',
 'begin if Empty(a) then Zero(a) else',
 ' while a.m[2]<32768 do begin Left(a.m); Dec(a.e) end end;',
 'procedure Unpack(var r:RBytes; var a:Float);',
 'begin Zero(a); if r[0]<>0 then begin',
 ' a.e:=Integer(r[0])-129; a.neg:=(r[5] and 128)<>0;',
 ' a.m[0]:=Word(r[1]) shl 8; a.m[1]:=Word(r[2]) or (Word(r[3]) shl 8);',
 ' a.m[2]:=Word(r[4]) or (Word(r[5] or 128) shl 8) end end;',
 'procedure Pack(a:Float; var r:RBytes);',
 'var i:Integer; t:Longint; carry:Word;',
 'begin',
 ' FillChar(r,6,0); Normalize(a);',
 ' if not Empty(a) then begin',
 '  if ((a.m[0] and 255)>128) or (((a.m[0] and 255)=128) and ((a.m[0] and 256)<>0)) then begin',
 '   carry:=256; for i:=0 to 2 do begin t:=Longint(a.m[i])+carry;',
 '    a.m[i]:=Word(t); carry:=Word(t shr 16) end;',
 '   if carry<>0 then begin a.m[2]:=32768; Inc(a.e) end',
 '  end;',
 '  if a.e>126 then RunError(205);',
 '  if a.e>=-128 then begin r[0]:=a.e+129; r[1]:=a.m[0] shr 8;',
 '   r[2]:=a.m[1]; r[3]:=a.m[1] shr 8; r[4]:=a.m[2]; r[5]:=(a.m[2] shr 8) and 127;',
 '   if a.neg then r[5]:=r[5] or 128 end',
 ' end',
 'end;',
 'procedure IntegerFloat(n:Longint; var a:Float);',
 'begin Zero(a); if n<>0 then begin a.neg:=n<0;',
 ' if a.neg then n:=-n; a.m[0]:=Word(n); a.m[1]:=Word(n shr 16); a.e:=47; Normalize(a) end end;',
 'procedure Add(a,b:Float; var r:Float);',
 'var t:Float; i,d:Integer; n:Longint; carry:Word;',
 'begin',
 ' if Empty(a) then r:=b else if Empty(b) then r:=a else begin',
 '  if a.e<b.e then begin t:=a; a:=b; b:=t end;',
 '  d:=a.e-b.e; if d>55 then Zero(b) else for i:=1 to d do Right(b.m);',
 '  if a.neg=b.neg then begin carry:=0;',
 '   for i:=0 to 2 do begin n:=Longint(a.m[i])+b.m[i]+carry;',
 '    a.m[i]:=Word(n); carry:=Word(n shr 16) end;',
 '   if carry<>0 then begin Right(a.m); a.m[2]:=a.m[2] or 32768; Inc(a.e) end;',
 '   r:=a',
 '  end else begin',
 '   if Mag(a.m,b.m)<0 then begin t:=a; a:=b; b:=t end;',
 '   Sub(a.m,b.m); r:=a; Normalize(r)',
 '  end',
 ' end',
 'end;',
 'procedure Multiply(a,b:Float; var r:Float);',
 'var p:array[0..5] of Word; i,j,k:Integer; n:Longint; carry:Word;',
 'begin',
 ' Zero(r); if not Empty(a) and not Empty(b) then begin',
 '  FillChar(p,SizeOf(p),0);',
 '  for i:=0 to 2 do begin carry:=0;',
 '   for j:=0 to 2 do begin k:=i+j;',
 '    n:=Longint(a.m[i])*Longint(b.m[j]);',
 '    n:=n+Longint(p[k])+carry; p[k]:=Word(n); carry:=Word(n shr 16)',
 '   end; p[i+3]:=carry',
 '  end;',
 '  for i:=1 to 47 do begin carry:=0;',
 '   for j:=5 downto 0 do begin k:=p[j] and 1; p[j]:=(p[j] shr 1) or carry; carry:=Word(k) shl 15 end',
 '  end;',
 '  r.m[0]:=p[0]; r.m[1]:=p[1]; r.m[2]:=p[2]; r.e:=a.e+b.e; r.neg:=a.neg<>b.neg;',
 '  if p[3]<>0 then begin Right(r.m); r.m[2]:=r.m[2] or 32768; Inc(r.e) end;',
 '  Normalize(r)',
 ' end',
 'end;',
 'procedure Divide(a,b:Float; var r:Float);',
 'var i:Integer; overflow:Boolean;',
 'begin',
 ' if Empty(b) then RunError(200); Zero(r);',
 ' if not Empty(a) then begin',
 '  r.e:=a.e-b.e; r.neg:=a.neg<>b.neg;',
 '  overflow:=False; for i:=0 to 47 do begin',
 '   Left(r.m);',
 '   if overflow or (Mag(a.m,b.m)>=0) then begin Sub(a.m,b.m); r.m[0]:=r.m[0] or 1 end;',
 '   if i<>47 then begin',
 '    overflow:=(a.m[2] and 32768)<>0; Left(a.m)',
 '   end',
 '  end;',
 '  Normalize(r)',
 ' end',
 'end;',
 'function Compare(a,b:Float):Integer;',
 'var c:Integer;',
 'begin',
 ' if Empty(a) and Empty(b) then c:=0 else if a.neg<>b.neg then begin',
 '  if a.neg then c:=-1 else c:=1',
 ' end else begin',
 '  c:=0; if a.e<b.e then c:=-1 else if a.e>b.e then c:=1 else c:=Mag(a.m,b.m);',
 '  if a.neg then c:=-c',
 ' end; Compare:=c',
 'end;',
 'function IntValue(a:Float; mode:Integer):Longint;',
 'var n:Longint; i:Integer; lost,half,below:Boolean;',
 'begin',
 ' n:=0; lost:=False; half:=False; below:=False;',
 ' if not Empty(a) then begin',
 '  if a.e>31 then RunError(207);',
 '  if a.e<-1 then begin lost:=True; a.m[0]:=0; a.m[1]:=0; a.m[2]:=0 end',
 '  else for i:=1 to 47-a.e do begin',
 '   below:=below or half; half:=(a.m[0] and 1)<>0; lost:=lost or half; Right(a.m)',
 '  end;',
 '  n:=Longint(a.m[0]) or (Longint(a.m[1]) shl 16);',
 '  if ((mode=0) and half and (below or ((n and 1)<>0))) or',
 '     ((mode=1) and a.neg and lost) or ((mode=2) and not a.neg and lost) then Inc(n);',
 '  if (n<0) and not (a.neg and (n=-2147483647-1)) then RunError(207);',
 '  if a.neg then n:=-n',
 ' end; IntValue:=n',
 'end;',
 'procedure DecimalFloat(text:string; var a:Float);',
 'var r:RBytes; code:Integer;',
 'begin RParse(text,r,code); if code<>0 then RunError(207); Unpack(r,a) end;',
 'procedure MathOp(op:Integer; a:Float; var r:Float);',
 'var b,c,t,sum,term,x,one,two:Float; i:Integer; n:Longint; neg:Boolean;',
 'begin',
 ' IntegerFloat(1,one); IntegerFloat(2,two); r:=a;',
 ' if op=10 then begin',
 '  if a.neg then RunError(207);',
 '  if not Empty(a) then begin r.e:=a.e div 2; r.m:=one.m; r.neg:=False;',
 '   for i:=1 to 32 do begin Divide(a,r,t); Add(r,t,r); Dec(r.e) end',
 '  end',
 ' end else if (op=11) or (op=12) then begin',
 '  { Reduce to [-pi,pi], then use an alternating Taylor series. }',
 '  DecimalFloat(''3.141592653589793'',b);',
 '  t:=b; Inc(t.e); Divide(a,t,c); n:=IntValue(c,3); IntegerFloat(n,c); Multiply(c,t,c); c.neg:=not c.neg; Add(a,c,x);',
 '  c:=b; c.neg:=True; if Compare(x,b)>0 then begin t.neg:=True; Add(x,t,x) end;',
 '  if Compare(x,c)<0 then begin t.neg:=False; Add(x,t,x) end;',
 '  Multiply(x,x,t); t.neg:=True;',
 '  if op=11 then begin sum:=x; term:=x; n:=2 end else begin sum:=one; term:=one; n:=1 end;',
 '  for i:=1 to 20 do begin Multiply(term,t,term); IntegerFloat(n*(n+1),c); Divide(term,c,term); Add(sum,term,sum); Inc(n,2) end; r:=sum',
 ' end else if op=14 then begin',
 '  if a.neg or Empty(a) then RunError(207); n:=a.e; a.e:=0;',
 '  c:=one; c.neg:=True; Add(a,c,b); Add(a,one,c); Divide(b,c,x); Multiply(x,x,t);',
 '  sum:=x; term:=x;',
 '  for i:=1 to 40 do begin Multiply(term,t,term); IntegerFloat(2*i+1,c); Divide(term,c,b); Add(sum,b,sum) end;',
 '  Inc(sum.e); DecimalFloat(''0.6931471805599453'',b);',
 '  IntegerFloat(n,c); Multiply(b,c,b); Add(sum,b,r)',
 ' end else if op=15 then begin',
 '  DecimalFloat(''0.6931471805599453'',b);',
 '  Divide(a,b,c); n:=IntValue(c,0); if (n>127) or (n<-150) then begin if n>127 then RunError(205); Zero(r) end',
 '  else begin IntegerFloat(n,c); Multiply(b,c,c); c.neg:=not c.neg; Add(a,c,x);',
 '   sum:=one; term:=one; for i:=1 to 24 do begin Multiply(term,x,term); IntegerFloat(i,c); Divide(term,c,term); Add(sum,term,sum) end;',
 '   r:=sum; Inc(r.e,n)',
 '  end',
 ' end else if op=13 then begin',
 '  neg:=a.neg; a.neg:=False; n:=0;',
 '  if Compare(a,one)>0 then begin Divide(one,a,a); n:=1 end;',
 '  { Half-angle reduction makes the series converge rapidly at x=1. }',
 '  Multiply(a,a,b); Add(b,one,b); MathOp(10,b,c); Add(c,one,c); Divide(a,c,x);',
 '  Multiply(x,x,t); t.neg:=True; sum:=x; term:=x;',
 '  for i:=1 to 32 do begin Multiply(term,t,term); IntegerFloat(2*i+1,c); Divide(term,c,b); Add(sum,b,sum) end;',
 '  Inc(sum.e); r:=sum;',
 '  if n=1 then begin DecimalFloat(''1.5707963267948966'',b); r.neg:=True; Add(b,r,r) end;',
 '  r.neg:=neg',
 ' end',
 'end;',
 'procedure RInt(n:Longint; var r:RBytes);',
 'var a:Float;',
 'begin IntegerFloat(n,a); Pack(a,r) end;',
 'procedure RCalc(op:Integer; var a,b,r:RBytes);',
 'var x,y,z:Float; i,bits:Integer;',
 'begin',
 ' Unpack(a,x); Unpack(b,y); z:=x;',
 ' if op=1 then Add(x,y,z) else if op=2 then begin y.neg:=not y.neg; Add(x,y,z) end',
 ' else if op=3 then Multiply(x,y,z) else if op=4 then Divide(x,y,z)',
 ' else if op=5 then begin if not Empty(z) then z.neg:=not z.neg end',
 ' else if op=6 then z.neg:=False else if op=7 then Multiply(x,x,z)',
 ' else if (op=8) or (op=9) then begin',
 '  if z.e<0 then Zero(z) else if z.e<47 then begin bits:=47-z.e;',
 '   for i:=1 to bits do Right(z.m); for i:=1 to bits do Left(z.m); Normalize(z)',
 '  end;',
 '  if op=9 then begin z.neg:=not z.neg; Add(x,z,z) end',
 ' end',
 ' else MathOp(op,x,z);',
 ' Pack(z,r)',
 'end;',
 'function RCmp(var a,b:RBytes):Integer;',
 'var x,y:Float;',
 'begin Unpack(a,x); Unpack(b,y); RCmp:=Compare(x,y) end;',
 'function RTrunc(var a:RBytes; rounded:Boolean):Longint;',
 'var x:Float; mode:Integer;',
 'begin Unpack(a,x); mode:=3; if rounded then mode:=0; RTrunc:=IntValue(x,mode) end;',
 'procedure RFormat(var a:RBytes; digits,width:Integer; var s:string);',
 'var x,ten,one,t:Float; i,e,d,n:Integer; negative:Boolean; text,tail:string;',
 'procedure Append(c:Char);',
 'var length:Integer;',
 'begin length:=Ord(s[0]); if length<255 then begin s[length+1]:=c; s[0]:=Chr(length+1) end end;',
 'begin',
 ' Unpack(a,x); negative:=x.neg; x.neg:=False; IntegerFloat(10,ten); IntegerFloat(1,one); e:=0;',
 ' if not Empty(x) then begin',
 '  while Compare(x,ten)>=0 do begin Divide(x,ten,x); Inc(e) end;',
 '  while Compare(x,one)<0 do begin Multiply(x,ten,x); Dec(e) end',
 ' end;',
 ' text[0]:=Chr(14); for i:=1 to 14 do begin d:=IntValue(x,3); text[i]:=Chr(48+d);',
 '  IntegerFloat(d,t); t.neg:=True; Add(x,t,x); Multiply(x,ten,x) end;',
 ' s[0]:=Chr(0);',
 ' if digits<0 then begin Append(text[1]); Append(''.''); for i:=2 to 12 do Append(text[i]); Append(''E'');',
 '  if e>=0 then Append(''+'') else begin Append(''-''); e:=-e end;',
 '  Str(e:2,tail); if tail[1]='' '' then tail[1]:=''0''; for i:=1 to Length(tail) do Append(tail[i])',
 ' end else begin',
 '  if digits>18 then digits:=18;',
 '  { Round the requested fixed decimal position, with carry into exponent. }',
 '  d:=e+1+digits;',
 '  if (d>=0) and (d<14) and (text[d+1]>=''5'') then begin',
 '   i:=d; while (i>0) and (text[i]=''9'') do begin text[i]:=''0''; Dec(i) end;',
 '   if i>0 then text[i]:=Chr(Ord(text[i])+1) else begin Move(text[1],text[2],14); text[1]:=''1''; text[0]:=Chr(15); Inc(e) end',
 '  end;',
 '  if e<0 then Append(''0'') else for i:=0 to e do begin if i<Length(text) then Append(text[i+1]) else Append(''0'') end;',
 '  if digits>0 then begin Append(''.''); for i:=1 to digits do begin d:=e+1+i;',
 '   if (d>0) and (d<=Length(text)) then Append(text[d]) else Append(''0'') end end',
 ' end;',
 ' if negative then begin n:=Length(s); Move(s[1],s[2],n); s[1]:=''-''; s[0]:=Chr(n+1) end;',
 ' if width>255 then width:=255; n:=Length(s);',
 ' if n<width then begin d:=width-n; Move(s[1],s[d+1],n); FillChar(s[1],d,32); s[0]:=Chr(width) end',
 'end;',
 'procedure RParse(var s:string; var a:RBytes; var code:Integer);',
 'var x,ten,t:Float; i,power,exponent,sign,count:Integer; negative,dot:Boolean;',
 'begin',
 ' Zero(x); IntegerFloat(10,ten); i:=1; power:=0; exponent:=0; sign:=1; count:=0; dot:=False; negative:=False; code:=0;',
 ' while (i<=Length(s)) and (s[i]='' '') do Inc(i);',
 ' if (i<=Length(s)) and ((s[i]=''+'') or (s[i]=''-'')) then begin negative:=s[i]=''-''; Inc(i) end;',
 ' while (i<=Length(s)) and (((s[i]>=''0'') and (s[i]<=''9'')) or (s[i]=''.'')) do begin',
 '  if s[i]=''.'' then begin if dot then begin code:=i; Exit end; dot:=True end',
 '  else begin Multiply(x,ten,x); IntegerFloat(Ord(s[i])-48,t); Add(x,t,x); Inc(count); if dot then Dec(power) end; Inc(i)',
 ' end;',
 ' if count=0 then begin code:=i; Exit end;',
 ' if (i<=Length(s)) and ((s[i]=''e'') or (s[i]=''E'')) then begin Inc(i);',
 '  if (i<=Length(s)) and ((s[i]=''+'') or (s[i]=''-'')) then begin if s[i]=''-'' then sign:=-1; Inc(i) end;',
 '  count:=0; while (i<=Length(s)) and (s[i]>=''0'') and (s[i]<=''9'') do begin',
 '   if exponent>1000 then begin code:=i; Exit end; exponent:=exponent*10+Ord(s[i])-48; Inc(i); Inc(count) end;',
 '  if count=0 then begin code:=i; Exit end',
 ' end;',
 ' if i<=Length(s) then begin code:=i; Exit end;',
 ' power:=power+sign*exponent;',
 ' if (power>300) or (power<-300) then begin code:=1; Exit end;',
 ' while power>0 do begin Multiply(x,ten,x); Dec(power) end;',
 ' while power<0 do begin Divide(x,ten,x); Inc(power) end;',
 ' x.neg:=negative; if x.e>126 then begin code:=1; Exit end; Pack(x,a)',
 'end;');
const EmulatorSource: array[1..174] of string[255] = (
 '{$R-,S-,B-,N-,O-,D-,L-}',
 'procedure REmu(op,width,index:Integer; var mem); forward;',
 'type Raw=array[0..9] of Byte; PRaw=^Raw;',
 'const control:Word=895;',
 'var st:array[0..7] of Float; used:array[0..7] of Boolean; top:Integer; status:Word;',
 'procedure LoadRaw(p:PRaw; width:Integer; integerMode:Boolean; var a:Float);',
 'var r:Raw; i,j,bits,e:Integer; negative:Boolean;',
 'begin',
 ' FillChar(r,SizeOf(r),0); for i:=0 to width-1 do r[i]:=p^[i]; Zero(a);',
 ' if integerMode then begin',
 '  negative:=(r[width-1] and 128)<>0;',
 '  if negative then begin j:=1; for i:=0 to width-1 do begin e:=255-r[i]+j; r[i]:=e; j:=e shr 8 end end;',
 '  a.e:=47; if width=8 then a.e:=63;',
 '  for i:=width*8-1 downto 0 do begin Left(a.m); if ((r[i div 8] shr (i mod 8)) and 1)<>0 then a.m[0]:=a.m[0] or 1 end;',
 '  if width=8 then begin a.m[0]:=Word(r[2]) or (Word(r[3]) shl 8); a.m[1]:=Word(r[4]) or (Word(r[5]) shl 8); a.m[2]:=Word(r[6]) or (Word(r[7]) shl 8) end;',
 '  a.neg:=negative; Normalize(a)',
 ' end else begin',
 '  if width=4 then begin bits:=23; e:=((Word(r[3]) and 127) shl 1) or (r[2] shr 7); j:=127; negative:=(r[3] and 128)<>0; r[2]:=r[2] and 127 end',
 '  else if width=8 then begin bits:=52; e:=((Word(r[7]) and 127) shl 4) or (r[6] shr 4); j:=1023; negative:=(r[7] and 128)<>0; r[6]:=r[6] and 15 end',
 '  else begin bits:=63; e:=Word(r[8]) or ((Word(r[9]) and 127) shl 8); j:=16383; negative:=(r[9] and 128)<>0 end;',
 '  if ((width=4) and (e=255)) or ((width=8) and (e=2047)) or ((width=10) and (e=32767)) then RunError(207);',
 '  if width<>10 then begin if e<>0 then r[bits div 8]:=r[bits div 8] or (1 shl (bits mod 8)) end;',
 '  a.e:=e-j; if e=0 then Inc(a.e);',
 '  for i:=bits downto bits-47 do begin Left(a.m); if (i>=0) and (((r[i div 8] shr (i mod 8)) and 1)<>0) then a.m[0]:=a.m[0] or 1 end;',
 '  a.neg:=negative; Normalize(a)',
 ' end',
 'end;',
 'procedure StoreRaw(a:Float; p:PRaw; width:Integer; integerMode:Boolean);',
 'var r:Raw; i,j,bits,e,mode:Integer; negative,half,below:Boolean; carry:Longint;',
 'begin',
 ' FillChar(r,SizeOf(r),0);',
 ' if integerMode then begin',
 '  mode:=(control shr 10) and 3; negative:=a.neg;',
 '  if width<8 then begin',
 '   e:=width*8-1; if a.e>e then RunError(207);',
 '  end;',
 '  if a.e>63 then RunError(207); half:=False; below:=False;',
 '  for i:=0 to 47 do begin j:=a.e-i;',
 '   if (a.m[2] and 32768)<>0 then begin',
 '    if (j>=0) and (j<width*8) then r[j div 8]:=r[j div 8] or (1 shl (j mod 8))',
 '    else if j=-1 then half:=True else if j<-1 then below:=True else RunError(207)',
 '   end; Left(a.m)',
 '  end;',
 '  if ((mode=0) and half and (below or ((r[0] and 1)<>0))) or',
 '     ((mode=1) and negative and (half or below)) or ((mode=2) and not negative and (half or below)) then begin',
 '   j:=1; for i:=0 to width-1 do begin e:=r[i]+j; r[i]:=e; j:=e shr 8 end;',
 '   if j<>0 then RunError(207)',
 '  end;',
 '  if (r[width-1] and 128)<>0 then begin',
 '   if not negative or (r[width-1]<>128) then RunError(207);',
 '   for i:=0 to width-2 do if r[i]<>0 then RunError(207)',
 '  end;',
 '  if negative then begin j:=1; for i:=0 to width-1 do begin e:=255-r[i]+j; r[i]:=e; j:=e shr 8 end end',
 ' end else if not Empty(a) then begin',
 '  if width=4 then begin',
 '   mode:=(control shr 10) and 3; half:=(a.m[1] and 128)<>0; below:=(a.m[0]<>0) or ((a.m[1] and 127)<>0);',
 '   if ((mode=0) and half and (below or ((a.m[1] and 256)<>0))) or',
 '      ((mode=1) and a.neg and (half or below)) or ((mode=2) and not a.neg and (half or below)) then begin',
 '    carry:=Longint(a.m[1])+256; a.m[1]:=Word(carry); carry:=Longint(a.m[2])+(carry shr 16); a.m[2]:=Word(carry);',
 '    if carry>65535 then begin a.m[1]:=0; a.m[2]:=32768; Inc(a.e) end',
 '   end',
 '  end;',
 '  if width=4 then begin bits:=23; e:=a.e+127 end else if width=8 then begin bits:=52; e:=a.e+1023 end else begin bits:=63; e:=a.e+16383 end;',
 '  if (e<=0) or ((width=4) and (e>=255)) or ((width=8) and (e>=2047)) or (e>=32767) then RunError(205);',
 '  for i:=0 to 47 do begin j:=bits-i;',
 '   if (j>=0) and ((a.m[2] and 32768)<>0) and ((i<>0) or (width=10)) then r[j div 8]:=r[j div 8] or (1 shl (j mod 8)); Left(a.m)',
 '  end;',
 '  if width=4 then begin r[2]:=r[2] or ((e and 1) shl 7); r[3]:=e shr 1; if a.neg then r[3]:=r[3] or 128 end',
 '  else if width=8 then begin r[6]:=r[6] or ((e and 15) shl 4); r[7]:=e shr 4; if a.neg then r[7]:=r[7] or 128 end',
 '  else begin r[8]:=e; r[9]:=e shr 8; if a.neg then r[9]:=r[9] or 128 end',
 ' end;',
 ' for i:=0 to width-1 do p^[i]:=r[i]',
 'end;',
 'procedure Rotate(rightward:Boolean);',
 'var i:Integer; a:Float; valid:Boolean;',
 'begin',
 ' if rightward then begin a:=st[7]; valid:=used[7]; for i:=7 downto 1 do begin st[i]:=st[i-1]; used[i]:=used[i-1] end;',
 '  st[0]:=a; used[0]:=valid; top:=(top-1) and 7',
 ' end else begin a:=st[0]; valid:=used[0]; for i:=0 to 6 do begin st[i]:=st[i+1]; used[i]:=used[i+1] end;',
 '  st[7]:=a; used[7]:=valid; top:=(top+1) and 7',
 ' end',
 'end;',
 'procedure Push(a:Float);',
 'begin if used[7] then RunError(207); Rotate(True); st[0]:=a; used[0]:=True end;',
 'procedure Pop;',
 'begin if not used[0] then RunError(207); used[0]:=False; Rotate(False) end;',
 'procedure SetCompare(a,b:Float);',
 'var c:Integer;',
 'begin status:=status and 47871; c:=Compare(a,b); if c=0 then status:=status or 16384 else if c<0 then status:=status or 256 end;',
 'procedure RoundFloat(var a:Float);',
 'var b:Float; bits,i,odd,mode:Integer; half,below,negative:Boolean;',
 'begin',
 ' if Empty(a) or (a.e>=47) then Exit; mode:=(control shr 10) and 3; negative:=a.neg;',
 ' bits:=47-a.e; half:=False; below:=False;',
 ' odd:=0;',
 ' if bits>48 then begin below:=True; Zero(a) end else begin',
 '  for i:=1 to bits do begin below:=below or half; half:=(a.m[0] and 1)<>0; Right(a.m) end;',
 '  odd:=a.m[0] and 1;',
 '  for i:=1 to bits do Left(a.m); Normalize(a)',
 ' end;',
 ' if ((mode=0) and half and (below or (odd<>0))) or ((mode=1) and negative and (half or below)) or',
 '    ((mode=2) and not negative and (half or below)) then begin IntegerFloat(1,b); b.neg:=negative; Add(a,b,a) end',
 'end;',
 'procedure REmu(op,width,index:Integer; var mem);',
 'var p:PRaw; a,b,c:Float; r:RBytes; text:string; err,i,group,target,n:Integer; integerMode,reverse,popping:Boolean;',
 'begin',
 ' p:=Addr(mem);',
 ' if op=0 then begin FillChar(used,SizeOf(used),0); top:=0; control:=895; status:=0; Exit end;',
 ' if op=1 then begin status:=0; Exit end;',
 ' if op=2 then Exit;',
 ' if op=16 then begin control:=Word(p^[0]) or (Word(p^[1]) shl 8); Exit end;',
 ' if op=17 then begin p^[0]:=control; p^[1]:=control shr 8; Exit end;',
 ' if op=18 then begin n:=(status and 51199) or (top shl 11); p^[0]:=n; p^[1]:=n shr 8; Exit end;',
 ' if (op=27) or (op=28) then begin Rotate(op=27); Exit end;',
 ' if op=3 then begin',
 '  text:=''0''; if index=0 then text:=''1'' else if index=2 then text:=''3.141592653589793''',
 '  else if index=3 then text:=''3.321928094887362'' else if index=4 then text:=''1.442695040888963''',
 '  else if index=5 then text:=''0.3010299956639812'' else if index=6 then text:=''0.6931471805599453'';',
 '  RParse(text,r,err); Unpack(r,a); Push(a); Exit',
 ' end;',
 ' if (op=5) or (op=8) then begin LoadRaw(p,width,op=8,a); Push(a); Exit end;',
 ' if not used[0] then RunError(207);',
 ' if (op=6) or (op=7) or (op=9) or (op=10) then begin StoreRaw(st[0],p,width,op>=9); if (op=7) or (op=10) then Pop; Exit end;',
 ' if (op>=11) and (op<=14) then begin',
 '  if (index<0) or (index>7) then RunError(207);',
 '  if ((op=11) or (op=14)) and not used[index] then RunError(207);',
 '  if op=11 then Push(st[index]) else if op=14 then begin a:=st[0]; st[0]:=st[index]; st[index]:=a end',
 '  else begin st[index]:=st[0]; used[index]:=True; if op=13 then Pop end; Exit',
 ' end;',
 ' if op=4 then begin',
 '  a:=st[0];',
 '  if index=0 then MathOp(10,a,a) else if index=1 then a.neg:=False',
 '  else if index=2 then begin if not Empty(a) then a.neg:=not a.neg end',
 '  else if (index=3) or (index=4) then begin Zero(b); SetCompare(a,b); if index=4 then begin',
 '   status:=status and 47359; if Empty(a) then status:=status or 16384 else status:=status or 1024;',
 '   if a.neg then status:=status or 512 end; Exit end',
 '  else if index=5 then RoundFloat(a)',
 '  else if index=6 then begin text:=''0.6931471805599453''; RParse(text,r,err); Unpack(r,b); Multiply(a,b,a); MathOp(15,a,a); IntegerFloat(-1,b); Add(a,b,a) end;',
 '  st[0]:=a; Exit',
 ' end;',
 ' if op=15 then begin',
 '  group:=index and 7; target:=(index shr 3) and 7; popping:=(index and 256)<>0; reverse:=(index and 128)<>0;',
 '  a:=st[0];',
 '  if width=0 then begin if not used[target] then RunError(207); b:=st[target] end',
 '  else begin integerMode:=width>16; if integerMode then Dec(width,16); LoadRaw(p,width,integerMode,b) end;',
 '  if reverse then begin c:=a; a:=b; b:=c end;',
 '  if group=0 then Add(a,b,c) else if group=1 then Multiply(a,b,c)',
 '  else if (group=2) or (group=3) then begin SetCompare(a,b); if group=3 then Pop; Exit end',
 '  else if group=4 then begin b.neg:=not b.neg; Add(a,b,c) end',
 '  else if group=5 then begin a.neg:=not a.neg; Add(b,a,c) end',
 '  else if group=6 then Divide(a,b,c) else Divide(b,a,c);',
 '  if reverse then st[target]:=c else st[0]:=c; if popping then Pop; Exit',
 ' end;',
 ' if op=25 then begin a:=st[0]; MathOp(11,a,b); MathOp(12,a,c); Divide(b,c,st[0]); IntegerFloat(1,a); Push(a); Exit end;',
 ' if op=26 then begin',
 '  { Intel FXTRACT: ST(0)=significand, ST(1)=unbiased exponent. }',
 '  if Empty(st[0]) then RunError(207); n:=st[0].e; a:=st[0]; a.e:=0; IntegerFloat(n,st[0]); Push(a); Exit',
 ' end;',
 ' if not used[1] then RunError(207); a:=st[0]; b:=st[1];',
 ' if op=19 then begin SetCompare(a,b); Pop; Pop end',
 ' else if op=20 then begin n:=IntValue(b,3); Inc(st[0].e,n) end',
 ' else if op=21 then begin Divide(a,b,c); n:=IntValue(c,3); IntegerFloat(n,c); Multiply(c,b,c); c.neg:=not c.neg; Add(a,c,st[0]) end',
 ' else if (op=22) or (op=23) then begin',
 '  if op=23 then begin IntegerFloat(1,c); Add(a,c,a) end;',
 '  MathOp(14,a,a); text:=''0.6931471805599453''; RParse(text,r,err); Unpack(r,c); Divide(a,c,a); Multiply(a,b,st[1]); Pop',
 ' end else if op=24 then begin',
 '  if Empty(a) then begin',
 '   if Empty(b) then RunError(207); text:=''1.5707963267948966''; RParse(text,r,err); Unpack(r,c); c.neg:=b.neg',
 '  end else begin Divide(b,a,c); MathOp(13,c,c);',
 '   if a.neg then begin text:=''3.141592653589793''; RParse(text,r,err); Unpack(r,a); a.neg:=b.neg; Add(c,a,c) end',
 '  end; st[1]:=c; Pop',
 ' end',
 ' else RunError(207)',
 'end;');

{ === DEBUT UNITES INTEGREES === }
{ Sources Pascal des unites standard CRT, DOS, STRINGS et PRINTER, compiles
  a la demande par RequireUnit quand aucune TPU ni TURBO.TPL ne les fournit
  (equivalent du TURBO.TPL de Turbo Pascal 7.0). Regeneres par script a
  partir des fichiers .PAS correspondants; apostrophes doublees. }
const StringsSource: array[1..209] of string[255] = (
 'Unit Strings;',
 '{ Unite STRINGS de Turbo Pascal 7.0 : chaines a zero terminal (PChar). }',
 'Interface',
 'Function StrLen(Str: PChar): Word;',
 'Function StrEnd(Str: PChar): PChar;',
 'Function StrMove(Dest, Source: PChar; Count: Word): PChar;',
 'Function StrCopy(Dest, Source: PChar): PChar;',
 'Function StrECopy(Dest, Source: PChar): PChar;',
 'Function StrLCopy(Dest, Source: PChar; MaxLen: Word): PChar;',
 'Function StrPCopy(Dest: PChar; Source: String): PChar;',
 'Function StrCat(Dest, Source: PChar): PChar;',
 'Function StrLCat(Dest, Source: PChar; MaxLen: Word): PChar;',
 'Function StrComp(Str1, Str2: PChar): Integer;',
 'Function StrIComp(Str1, Str2: PChar): Integer;',
 'Function StrLComp(Str1, Str2: PChar; MaxLen: Word): Integer;',
 'Function StrLIComp(Str1, Str2: PChar; MaxLen: Word): Integer;',
 'Function StrScan(Str: PChar; Chr: Char): PChar;',
 'Function StrRScan(Str: PChar; Chr: Char): PChar;',
 'Function StrPos(Str1, Str2: PChar): PChar;',
 'Function StrUpper(Str: PChar): PChar;',
 'Function StrLower(Str: PChar): PChar;',
 'Function StrPas(Str: PChar): String;',
 'Function StrNew(Str: PChar): PChar;',
 'Procedure StrDispose(Str: PChar);',
 'Implementation',
 '',
 'Function StrLen(Str: PChar): Word;',
 'Var L: Word;',
 'Begin',
 ' L:=0;',
 ' If Str<>Nil Then While Str[L]<>#0 Do Inc(L);',
 ' StrLen:=L;',
 'End;',
 '',
 'Function StrEnd(Str: PChar): PChar;',
 'Begin',
 ' StrEnd:=Str+StrLen(Str);',
 'End;',
 '',
 'Function StrMove(Dest, Source: PChar; Count: Word): PChar;',
 'Var I: Word;',
 'Begin',
 ' If Count<>0 Then Begin',
 '  If Source<Dest Then Begin',
 '   For I:=Count-1 DownTo 0 Do Begin Dest[I]:=Source[I]; If I=0 Then Break End;',
 '  End Else For I:=0 To Count-1 Do Dest[I]:=Source[I];',
 ' End;',
 ' StrMove:=Dest;',
 'End;',
 '',
 'Function StrCopy(Dest, Source: PChar): PChar;',
 'Var I: Word;',
 'Begin',
 ' I:=0;',
 ' While Source[I]<>#0 Do Begin Dest[I]:=Source[I]; Inc(I) End;',
 ' Dest[I]:=#0;',
 ' StrCopy:=Dest;',
 'End;',
 '',
 'Function StrECopy(Dest, Source: PChar): PChar;',
 'Begin',
 ' StrCopy(Dest,Source);',
 ' StrECopy:=Dest+StrLen(Source);',
 'End;',
 '',
 'Function StrLCopy(Dest, Source: PChar; MaxLen: Word): PChar;',
 'Var I: Word;',
 'Begin',
 ' I:=0;',
 ' While (I<MaxLen) And (Source[I]<>#0) Do Begin Dest[I]:=Source[I]; Inc(I) End;',
 ' Dest[I]:=#0;',
 ' StrLCopy:=Dest;',
 'End;',
 '',
 'Function StrPCopy(Dest: PChar; Source: String): PChar;',
 'Var I: Integer;',
 'Begin',
 ' For I:=1 To Length(Source) Do Dest[I-1]:=Source[I];',
 ' Dest[Length(Source)]:=#0;',
 ' StrPCopy:=Dest;',
 'End;',
 '',
 'Function StrCat(Dest, Source: PChar): PChar;',
 'Begin',
 ' StrCopy(StrEnd(Dest),Source);',
 ' StrCat:=Dest;',
 'End;',
 '',
 'Function StrLCat(Dest, Source: PChar; MaxLen: Word): PChar;',
 'Var L: Word;',
 'Begin',
 ' L:=StrLen(Dest);',
 ' If L<MaxLen Then StrLCopy(Dest+L,Source,MaxLen-L);',
 ' StrLCat:=Dest;',
 'End;',
 '',
 'Function StrLComp(Str1, Str2: PChar; MaxLen: Word): Integer;',
 'Var I: Word; C1,C2: Char;',
 'Begin',
 ' StrLComp:=0; I:=0;',
 ' While I<MaxLen Do Begin',
 '  C1:=Str1[I]; C2:=Str2[I];',
 '  If C1<>C2 Then Begin StrLComp:=Ord(C1)-Ord(C2); Exit End;',
 '  If C1=#0 Then Exit;',
 '  Inc(I);',
 ' End;',
 'End;',
 '',
 'Function StrComp(Str1, Str2: PChar): Integer;',
 'Begin',
 ' StrComp:=StrLComp(Str1,Str2,65535);',
 'End;',
 '',
 'Function StrLIComp(Str1, Str2: PChar; MaxLen: Word): Integer;',
 'Var I: Word; C1,C2: Char;',
 'Begin',
 ' StrLIComp:=0; I:=0;',
 ' While I<MaxLen Do Begin',
 '  C1:=UpCase(Str1[I]); C2:=UpCase(Str2[I]);',
 '  If C1<>C2 Then Begin StrLIComp:=Ord(C1)-Ord(C2); Exit End;',
 '  If C1=#0 Then Exit;',
 '  Inc(I);',
 ' End;',
 'End;',
 '',
 'Function StrIComp(Str1, Str2: PChar): Integer;',
 'Begin',
 ' StrIComp:=StrLIComp(Str1,Str2,65535);',
 'End;',
 '',
 'Function StrScan(Str: PChar; Chr: Char): PChar;',
 'Var I: Word;',
 'Begin',
 ' StrScan:=Nil; I:=0;',
 ' Repeat',
 '  If Str[I]=Chr Then Begin StrScan:=Str+I; Exit End;',
 '  If Str[I]=#0 Then Exit;',
 '  Inc(I);',
 ' Until False;',
 'End;',
 '',
 'Function StrRScan(Str: PChar; Chr: Char): PChar;',
 'Var I: Word;',
 'Begin',
 ' StrRScan:=Nil; I:=0;',
 ' Repeat',
 '  If Str[I]=Chr Then StrRScan:=Str+I;',
 '  If Str[I]=#0 Then Exit;',
 '  Inc(I);',
 ' Until False;',
 'End;',
 '',
 'Function StrPos(Str1, Str2: PChar): PChar;',
 'Var I,L: Word;',
 'Begin',
 ' StrPos:=Nil; L:=StrLen(Str2);',
 ' If L=0 Then Begin StrPos:=Str1; Exit End;',
 ' I:=0;',
 ' While Str1[I]<>#0 Do Begin',
 '  If StrLComp(Str1+I,Str2,L)=0 Then Begin StrPos:=Str1+I; Exit End;',
 '  Inc(I);',
 ' End;',
 'End;',
 '',
 'Function StrUpper(Str: PChar): PChar;',
 'Var I: Word;',
 'Begin',
 ' I:=0;',
 ' While Str[I]<>#0 Do Begin Str[I]:=UpCase(Str[I]); Inc(I) End;',
 ' StrUpper:=Str;',
 'End;',
 '',
 'Function StrLower(Str: PChar): PChar;',
 'Var I: Word;',
 'Begin',
 ' I:=0;',
 ' While Str[I]<>#0 Do Begin',
 '  If Str[I] In [''A''..''Z''] Then Str[I]:=Chr(Ord(Str[I])+32);',
 '  Inc(I);',
 ' End;',
 ' StrLower:=Str;',
 'End;',
 '',
 'Function StrPas(Str: PChar): String;',
 'Var S: String; I: Word;',
 'Begin',
 ' S:=''''; I:=0;',
 ' If Str<>Nil Then',
 '  While (Str[I]<>#0) And (I<255) Do Begin S:=S+Str[I]; Inc(I) End;',
 ' StrPas:=S;',
 'End;',
 '',
 'Function StrNew(Str: PChar): PChar;',
 'Var L: Word; P: PChar;',
 'Begin',
 ' StrNew:=Nil;',
 ' If (Str=Nil) Or (Str[0]=#0) Then Exit;',
 ' L:=StrLen(Str)+1;',
 ' GetMem(P,L);',
 ' If P<>Nil Then StrMove(P,Str,L);',
 ' StrNew:=P;',
 'End;',
 '',
 'Procedure StrDispose(Str: PChar);',
 'Begin',
 ' If Str<>Nil Then FreeMem(Str,StrLen(Str)+1);',
 'End;',
 '',
 'End.');
const PrinterSource: array[1..10] of string[255] = (
 'Unit Printer;',
 '{ Unite PRINTER de Turbo Pascal 7.0 : fichier texte Lst sur l''imprimante. }',
 'Interface',
 'Var Lst: Text;',
 'Implementation',
 'Begin',
 ' Assign(Lst,''PRN'');',
 ' {$I-} Rewrite(Lst); {$I+}',
 ' If IOResult<>0 Then ;',
 'End.');
const DosSource: array[1..490] of string[255] = (
 'Unit Dos;',
 '{ Unite DOS de Turbo Pascal 7.0 : interruptions, date/heure, fichiers,',
 '  repertoires, environnement et execution de programmes. }',
 'Interface',
 'Const',
 ' fmClosed=$D7B0; fmInput=$D7B1; fmOutput=$D7B2; fmInOut=$D7B3;',
 ' ReadOnly=$01; Hidden=$02; SysFile=$04; VolumeID=$08; Directory=$10; Archive=$20; AnyFile=$3F;',
 ' FCarry=$0001; FParity=$0004; FAuxiliary=$0010; FZero=$0040; FSign=$0080; FOverflow=$0800;',
 'Type',
 ' ComStr=String[127];',
 ' PathStr=String[79];',
 ' DirStr=String[67];',
 ' NameStr=String[8];',
 ' ExtStr=String[4];',
 ' SearchRec=Record',
 '  Fill: Array[1..21] Of Byte;',
 '  Attr: Byte;',
 '  Time: Longint;',
 '  Size: Longint;',
 '  Name: String[12];',
 ' End;',
 ' DateTime=Record',
 '  Year,Month,Day,Hour,Min,Sec: Word;',
 ' End;',
 ' Registers=Record',
 '  Case Integer Of',
 '   0:(AX,BX,CX,DX,BP,SI,DI,DS,ES,Flags: Word);',
 '   1:(AL,AH,BL,BH,CL,CH,DL,DH: Byte);',
 ' End;',
 ' FileRec=Record',
 '  Handle: Word;',
 '  Flags: Word;',
 '  Mode: Word;',
 '  BufSize: Word;',
 '  Std: Word;',
 '  Private1: Word;',
 '  Signature: Word;',
 '  Private2: Word;',
 '  Name: Array[0..79] Of Char;',
 '  BufPtr: Pointer;',
 '  BufLen: Word;',
 '  BufPos: Word;',
 '  BufEnd: Word;',
 '  Count: Word;',
 ' End;',
 ' TextRec=FileRec;',
 'Var',
 ' DosError: Integer;',
 'Procedure Intr(IntNo: Byte; Var Regs: Registers);',
 'Procedure MsDos(Var Regs: Registers);',
 'Function DosVersion: Word;',
 'Procedure GetDate(Var Year,Month,Day,DayOfWeek: Word);',
 'Procedure SetDate(Year,Month,Day: Word);',
 'Procedure GetTime(Var Hour,Minute,Second,Sec100: Word);',
 'Procedure SetTime(Hour,Minute,Second,Sec100: Word);',
 'Procedure GetCBreak(Var Break: Boolean);',
 'Procedure SetCBreak(Break: Boolean);',
 'Procedure GetVerify(Var Verify: Boolean);',
 'Procedure SetVerify(Verify: Boolean);',
 'Function DiskFree(Drive: Byte): Longint;',
 'Function DiskSize(Drive: Byte): Longint;',
 'Procedure GetFAttr(Var F; Var Attr: Word);',
 'Procedure SetFAttr(Var F; Attr: Word);',
 'Procedure GetFTime(Var F; Var Time: Longint);',
 'Procedure SetFTime(Var F; Time: Longint);',
 'Procedure FindFirst(Path: PathStr; Attr: Word; Var F: SearchRec);',
 'Procedure FindNext(Var F: SearchRec);',
 'Procedure UnpackTime(P: Longint; Var T: DateTime);',
 'Procedure PackTime(Var T: DateTime; Var P: Longint);',
 'Procedure GetIntVec(IntNo: Byte; Var Vector: Pointer);',
 'Procedure SetIntVec(IntNo: Byte; Vector: Pointer);',
 'Procedure SwapVectors;',
 'Procedure Keep(ExitCode: Word);',
 'Procedure Exec(Path: PathStr; ComLine: ComStr);',
 'Function DosExitCode: Word;',
 'Function FSearch(Path: PathStr; DirList: String): PathStr;',
 'Function FExpand(Path: PathStr): PathStr;',
 'Procedure FSplit(Path: PathStr; Var Dir: DirStr; Var Name: NameStr; Var Ext: ExtStr);',
 'Function EnvCount: Integer;',
 'Function EnvStr(Index: Integer): String;',
 'Function GetEnv(EnvVar: String): String;',
 'Implementation',
 'Type',
 ' PByte=^Byte;',
 ' PWord=^Word;',
 'Var',
 ' R: Registers;',
 ' Stub: Array[0..127] Of Byte;    { code de la routine d''interruption, en DS }',
 ' StubLen: Byte;',
 ' StubInt: Integer;',
 ' StubPtr: Pointer;',
 ' ASCIIZ: Array[0..255] Of Char;',
 '',
 'Procedure StubByte(B: Byte); Begin Stub[StubLen]:=B; Inc(StubLen) End;',
 'Procedure StubWord(W: Word); Begin StubByte(Lo(W)); StubByte(Hi(W)) End;',
 'Procedure StubMem(Op1,Op2: Byte; Ofs: Word); Begin StubByte(Op1); StubByte(Op2); StubWord(Ofs) End;',
 '',
 'Procedure BuildStub(IntNo: Byte);',
 '{ Routine far, executee avec CS = segment de donnees: charge les registres',
 '  depuis R, sauve SS:SP, execute INT IntNo, restaure SS:SP et DS, puis',
 '  range les registres dans R. Independante de CS du programme. }',
 'Var RO,SaveSS,SaveSP: Word;',
 'Begin',
 ' StubLen:=0; RO:=Ofs(R); SaveSS:=Ofs(Stub)+120; SaveSP:=Ofs(Stub)+122;',
 ' StubByte($A1); StubWord(RO);           { mov ax,[R.AX] }',
 ' StubMem($8B,$1E,RO+2);                 { mov bx,[R.BX] }',
 ' StubMem($8B,$0E,RO+4);                 { mov cx,[R.CX] }',
 ' StubMem($8B,$16,RO+6);                 { mov dx,[R.DX] }',
 ' StubMem($8B,$2E,RO+8);                 { mov bp,[R.BP] }',
 ' StubMem($8B,$36,RO+10);                { mov si,[R.SI] }',
 ' StubMem($8B,$3E,RO+12);                { mov di,[R.DI] }',
 ' StubMem($8E,$06,RO+16);                { mov es,[R.ES] }',
 ' StubByte($2E); StubMem($8C,$16,SaveSS); { mov cs:[SaveSS],ss }',
 ' StubByte($2E); StubMem($89,$26,SaveSP); { mov cs:[SaveSP],sp }',
 ' StubMem($8E,$1E,RO+14);                { mov ds,[R.DS] }',
 ' StubByte($CD); StubByte(IntNo);        { int IntNo }',
 ' StubByte($FA);                         { cli }',
 ' StubByte($2E); StubMem($8E,$16,SaveSS); { mov ss,cs:[SaveSS] }',
 ' StubByte($2E); StubMem($8B,$26,SaveSP); { mov sp,cs:[SaveSP] }',
 ' StubByte($FB);                         { sti }',
 ' StubByte($1E); StubByte($9C); StubByte($50); { push ds; pushf; push ax }',
 ' StubByte($B8); StubWord(DSeg); StubByte($8E); StubByte($D8); { mov ax,DSeg; mov ds,ax }',
 ' StubByte($58);                         { pop ax }',
 ' StubByte($A3); StubWord(RO);           { mov [R.AX],ax }',
 ' StubMem($89,$1E,RO+2);                 { mov [R.BX],bx }',
 ' StubMem($89,$0E,RO+4);                 { mov [R.CX],cx }',
 ' StubMem($89,$16,RO+6);                 { mov [R.DX],dx }',
 ' StubMem($89,$2E,RO+8);                 { mov [R.BP],bp }',
 ' StubMem($89,$36,RO+10);                { mov [R.SI],si }',
 ' StubMem($89,$3E,RO+12);                { mov [R.DI],di }',
 ' StubMem($8C,$06,RO+16);                { mov [R.ES],es }',
 ' StubMem($8F,$06,RO+18);                { pop [R.Flags] }',
 ' StubMem($8F,$06,RO+14);                { pop [R.DS] }',
 ' StubByte($CB);                         { retf }',
 ' StubInt:=IntNo; StubPtr:=Ptr(DSeg,Ofs(Stub));',
 'End;',
 '',
 'Procedure CallInt(IntNo: Byte);',
 '{ Execute INT IntNo avec les registres de R, et recupere le resultat. }',
 'Begin',
 ' If StubInt<>IntNo Then BuildStub(IntNo);',
 ' asm',
 '  push bp',
 '  push si',
 '  push di',
 '  call far [StubPtr]',
 '  pop di',
 '  pop si',
 '  pop bp',
 ' end;',
 'End;',
 '',
 'Procedure Intr(IntNo: Byte; Var Regs: Registers);',
 'Begin',
 ' R:=Regs; CallInt(IntNo); Regs:=R;',
 'End;',
 '',
 'Procedure MsDos(Var Regs: Registers);',
 'Begin',
 ' Intr($21,Regs);',
 'End;',
 '',
 'Procedure DosCall;',
 '{ INT 21h avec R; DosError = AX si le carry est positionne. }',
 'Begin',
 ' CallInt($21);',
 ' If R.Flags And FCarry<>0 Then DosError:=R.AX Else DosError:=0;',
 'End;',
 '',
 'Function DosVersion: Word;',
 'Begin',
 ' R.AH:=$30; CallInt($21); DosVersion:=R.AX;',
 'End;',
 '',
 'Procedure GetDate(Var Year,Month,Day,DayOfWeek: Word);',
 'Begin',
 ' R.AH:=$2A; CallInt($21);',
 ' Year:=R.CX; Month:=R.DH; Day:=R.DL; DayOfWeek:=R.AL;',
 'End;',
 '',
 'Procedure SetDate(Year,Month,Day: Word);',
 'Begin',
 ' R.AH:=$2B; R.CX:=Year; R.DH:=Month; R.DL:=Day; CallInt($21);',
 'End;',
 '',
 'Procedure GetTime(Var Hour,Minute,Second,Sec100: Word);',
 'Begin',
 ' R.AH:=$2C; CallInt($21);',
 ' Hour:=R.CH; Minute:=R.CL; Second:=R.DH; Sec100:=R.DL;',
 'End;',
 '',
 'Procedure SetTime(Hour,Minute,Second,Sec100: Word);',
 'Begin',
 ' R.AH:=$2D; R.CH:=Hour; R.CL:=Minute; R.DH:=Second; R.DL:=Sec100; CallInt($21);',
 'End;',
 '',
 'Procedure GetCBreak(Var Break: Boolean);',
 'Begin',
 ' R.AX:=$3300; CallInt($21); Break:=R.DL<>0;',
 'End;',
 '',
 'Procedure SetCBreak(Break: Boolean);',
 'Begin',
 ' R.AX:=$3301; R.DL:=Ord(Break); CallInt($21);',
 'End;',
 '',
 'Procedure GetVerify(Var Verify: Boolean);',
 'Begin',
 ' R.AH:=$54; CallInt($21); Verify:=R.AL<>0;',
 'End;',
 '',
 'Procedure SetVerify(Verify: Boolean);',
 'Begin',
 ' R.AH:=$2E; R.AL:=Ord(Verify); R.DL:=0; CallInt($21);',
 'End;',
 '',
 'Function DiskFree(Drive: Byte): Longint;',
 'Begin',
 ' R.AH:=$36; R.DL:=Drive; CallInt($21);',
 ' If R.AX=$FFFF Then DiskFree:=-1',
 ' Else DiskFree:=Longint(R.AX)*R.CX*R.BX;',
 'End;',
 '',
 'Function DiskSize(Drive: Byte): Longint;',
 'Begin',
 ' R.AH:=$36; R.DL:=Drive; CallInt($21);',
 ' If R.AX=$FFFF Then DiskSize:=-1',
 ' Else DiskSize:=Longint(R.AX)*R.CX*R.DX;',
 'End;',
 '',
 'Procedure FileNameRegs(Var F);',
 '{ DS:DX = nom ASCIIZ du descripteur de fichier (offset 16). }',
 'Var P: PChar;',
 'Begin',
 ' P:=PChar(@F); P:=P+16;',
 ' R.DS:=Seg(P^); R.DX:=Ofs(P^);',
 'End;',
 '',
 'Procedure GetFAttr(Var F; Var Attr: Word);',
 'Begin',
 ' FileNameRegs(F); R.AX:=$4300; DosCall;',
 ' If DosError=0 Then Attr:=R.CX Else Attr:=0;',
 'End;',
 '',
 'Procedure SetFAttr(Var F; Attr: Word);',
 'Begin',
 ' FileNameRegs(F); R.AX:=$4301; R.CX:=Attr; DosCall;',
 'End;',
 '',
 'Procedure GetFTime(Var F; Var Time: Longint);',
 'Var P: PWord;',
 'Begin',
 ' P:=PWord(@F); R.BX:=P^; R.AX:=$5700; DosCall;',
 ' If DosError=0 Then Time:=Longint(R.DX)*65536+R.CX Else Time:=0;',
 'End;',
 '',
 'Procedure SetFTime(Var F; Time: Longint);',
 'Var P: PWord;',
 'Begin',
 ' P:=PWord(@F); R.BX:=P^; R.AX:=$5701; R.CX:=Word(Time); R.DX:=Word(Time Shr 16); DosCall;',
 'End;',
 '',
 'Procedure SetASCIIZ(S: String);',
 'Var I: Integer;',
 'Begin',
 ' For I:=1 To Length(S) Do ASCIIZ[I-1]:=S[I];',
 ' ASCIIZ[Length(S)]:=#0;',
 ' R.DS:=Seg(ASCIIZ); R.DX:=Ofs(ASCIIZ);',
 'End;',
 '',
 'Procedure FixSearchName(Var F: SearchRec);',
 '{ Le nom ASCIIZ du DTA devient une chaine Pascal. }',
 'Var P: PChar; L,I: Integer;',
 'Begin',
 ' P:=PChar(@F.Name); L:=0;',
 ' While (L<12) And (P[L]<>#0) Do Inc(L);',
 ' For I:=L DownTo 1 Do P[I]:=P[I-1];',
 ' P[0]:=Chr(L);',
 'End;',
 '',
 'Procedure FindFirst(Path: PathStr; Attr: Word; Var F: SearchRec);',
 'Begin',
 ' R.AH:=$1A; R.DS:=Seg(F); R.DX:=Ofs(F); CallInt($21);',
 ' SetASCIIZ(Path); R.AH:=$4E; R.CX:=Attr; DosCall;',
 ' If DosError=0 Then FixSearchName(F);',
 'End;',
 '',
 'Procedure FindNext(Var F: SearchRec);',
 'Begin',
 ' R.AH:=$1A; R.DS:=Seg(F); R.DX:=Ofs(F); CallInt($21);',
 ' R.AH:=$4F; DosCall;',
 ' If DosError=0 Then FixSearchName(F);',
 'End;',
 '',
 'Procedure UnpackTime(P: Longint; Var T: DateTime);',
 'Begin',
 ' T.Sec:=(P And 31)*2;',
 ' T.Min:=(P Shr 5) And 63;',
 ' T.Hour:=(P Shr 11) And 31;',
 ' T.Day:=(P Shr 16) And 31;',
 ' T.Month:=(P Shr 21) And 15;',
 ' T.Year:=((P Shr 25) And 127)+1980;',
 'End;',
 '',
 'Procedure PackTime(Var T: DateTime; Var P: Longint);',
 'Begin',
 ' P:=(Longint(T.Year-1980) Shl 25) Or (Longint(T.Month) Shl 21) Or (Longint(T.Day) Shl 16) Or',
 '    (Longint(T.Hour) Shl 11) Or (Longint(T.Min) Shl 5) Or (T.Sec Div 2);',
 'End;',
 '',
 'Procedure GetIntVec(IntNo: Byte; Var Vector: Pointer);',
 'Begin',
 ' R.AH:=$35; R.AL:=IntNo; CallInt($21);',
 ' Vector:=Ptr(R.ES,R.BX);',
 'End;',
 '',
 'Procedure SetIntVec(IntNo: Byte; Vector: Pointer);',
 'Begin',
 ' R.AH:=$25; R.AL:=IntNo; R.DS:=Seg(Vector^); R.DX:=Ofs(Vector^); CallInt($21);',
 'End;',
 '',
 'Procedure SwapVectors;',
 'Begin',
 'End;',
 '',
 'Procedure Keep(ExitCode: Word);',
 'Begin',
 ' R.AH:=$62; CallInt($21);',
 ' R.DX:=SSeg+4096-R.BX;',
 ' R.AH:=$31; R.AL:=ExitCode; CallInt($21);',
 'End;',
 '',
 'Procedure Exec(Path: PathStr; ComLine: ComStr);',
 'Var Block: Array[0..6] Of Word; Cmd: Array[0..129] Of Char; I: Integer; Psp,Need: Word;',
 'Begin',
 ' If Length(ComLine)>126 Then ComLine[0]:=#126;',
 ' Cmd[0]:=Chr(Length(ComLine));',
 ' For I:=1 To Length(ComLine) Do Cmd[I]:=ComLine[I];',
 ' Cmd[Length(ComLine)+1]:=#13;',
 ' { Liberer la memoire au-dela de la pile pour le programme fils. }',
 ' R.AH:=$62; CallInt($21); Psp:=R.BX;',
 ' Need:=SSeg-Psp+4097;',
 ' R.AH:=$4A; R.ES:=Psp; R.BX:=Need; CallInt($21);',
 ' If R.Flags And FCarry<>0 Then Begin',
 '  R.AH:=$4A; R.ES:=Psp; CallInt($21);',
 ' End;',
 ' Block[0]:=0; Block[1]:=Ofs(Cmd); Block[2]:=Seg(Cmd);',
 ' Block[3]:=$5C; Block[4]:=Psp; Block[5]:=$6C; Block[6]:=Psp;',
 ' SetASCIIZ(Path);',
 ' R.ES:=Seg(Block); R.BX:=Ofs(Block); R.AX:=$4B00;',
 ' DosCall;',
 'End;',
 '',
 'Function DosExitCode: Word;',
 'Begin',
 ' R.AH:=$4D; CallInt($21); DosExitCode:=R.AX;',
 'End;',
 '',
 'Function UpStr(S: String): String;',
 'Var I: Integer;',
 'Begin',
 ' For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);',
 ' UpStr:=S;',
 'End;',
 '',
 'Function FileExists(Name: String): Boolean;',
 'Begin',
 ' SetASCIIZ(Name); R.AX:=$4300; DosCall;',
 ' FileExists:=(DosError=0) And (R.CX And Directory=0);',
 'End;',
 '',
 'Function FSearch(Path: PathStr; DirList: String): PathStr;',
 'Var P: Integer; Dir,Try: String;',
 'Begin',
 ' FSearch:='''';',
 ' If Path='''' Then Exit;',
 ' If FileExists(Path) Then Begin FSearch:=Path; Exit End;',
 ' If (Pos('':'',Path)<>0) Or (Pos(''\'',Path)<>0) Then Exit;',
 ' While DirList<>'''' Do Begin',
 '  P:=Pos('';'',DirList);',
 '  If P=0 Then Begin Dir:=DirList; DirList:='''' End',
 '  Else Begin Dir:=Copy(DirList,1,P-1); Delete(DirList,1,P) End;',
 '  If Dir<>'''' Then Begin',
 '   If Not (Dir[Length(Dir)] In [''\'','':'']) Then Dir:=Dir+''\'';',
 '   Try:=Dir+Path;',
 '   If FileExists(Try) Then Begin FSearch:=Try; Exit End;',
 '  End;',
 ' End;',
 'End;',
 '',
 'Procedure FSplit(Path: PathStr; Var Dir: DirStr; Var Name: NameStr; Var Ext: ExtStr);',
 'Var I,DirEnd,ExtPos: Integer;',
 'Begin',
 ' DirEnd:=0; ExtPos:=0;',
 ' For I:=1 To Length(Path) Do',
 '  Case Path[I] Of',
 '   ''\'','':'':Begin DirEnd:=I; ExtPos:=0 End;',
 '   ''.'':ExtPos:=I;',
 '  End;',
 ' Dir:=Copy(Path,1,DirEnd);',
 ' If ExtPos=0 Then Begin Name:=Copy(Path,DirEnd+1,8); Ext:='''' End',
 ' Else Begin Name:=Copy(Path,DirEnd+1,ExtPos-DirEnd-1); Ext:=Copy(Path,ExtPos,4) End;',
 'End;',
 '',
 'Function FExpand(Path: PathStr): PathStr;',
 'Var Cur: String; Drive: Byte; I,P: Integer; Res: String;',
 'Begin',
 ' Path:=UpStr(Path);',
 ' If (Length(Path)>=2) And (Path[2]='':'') Then Begin',
 '  Drive:=Ord(Path[1])-64; Delete(Path,1,2);',
 ' End Else Begin',
 '  R.AH:=$19; CallInt($21); Drive:=R.AL+1;',
 ' End;',
 ' If (Path<>'''') And (Path[1]=''\'') Then Res:=Path',
 ' Else Begin',
 '  GetDir(Drive,Cur);',
 '  If Length(Cur)>=2 Then Delete(Cur,1,2);',
 '  If (Cur='''') Or (Cur[Length(Cur)]<>''\'') Then Cur:=Cur+''\'';',
 '  Res:=Cur+Path;',
 ' End;',
 ' { Resoudre . et .. }',
 ' Repeat',
 '  P:=Pos(''\.\'',Res);',
 '  If P=0 Then Break;',
 '  Delete(Res,P,2);',
 ' Until False;',
 ' Repeat',
 '  P:=Pos(''\..'',Res);',
 '  If P=0 Then Break;',
 '  I:=P-1;',
 '  While (I>0) And (Res[I]<>''\'') Do Dec(I);',
 '  If I=0 Then I:=1;',
 '  Delete(Res,I,P+2-I);',
 '  If Res='''' Then Res:=''\'';',
 ' Until False;',
 ' If (Length(Res)>=2) And (Res[Length(Res)]=''.'') And (Res[Length(Res)-1]=''\'') Then Delete(Res,Length(Res),1);',
 ' If Res='''' Then Res:=''\'';',
 ' FExpand:=Chr(Drive+64)+'':''+Res;',
 'End;',
 '',
 'Function EnvSeg: Word;',
 'Begin',
 ' EnvSeg:=MemW[PrefixSeg:$2C];',
 'End;',
 '',
 'Function EnvCount: Integer;',
 'Var E,O: Word; N: Integer;',
 'Begin',
 ' E:=EnvSeg; O:=0; N:=0;',
 ' While Mem[E:O]<>0 Do Begin',
 '  Inc(N);',
 '  While Mem[E:O]<>0 Do Inc(O);',
 '  Inc(O);',
 ' End;',
 ' EnvCount:=N;',
 'End;',
 '',
 'Function EnvStr(Index: Integer): String;',
 'Var E,O: Word; N: Integer; S: String;',
 'Begin',
 ' EnvStr:=''''; S:='''';',
 ' If Index<1 Then Exit;',
 ' E:=EnvSeg; O:=0; N:=0;',
 ' While Mem[E:O]<>0 Do Begin',
 '  Inc(N);',
 '  If N=Index Then Begin',
 '   While (Mem[E:O]<>0) And (Length(S)<255) Do Begin S:=S+Chr(Mem[E:O]); Inc(O) End;',
 '   EnvStr:=S; Exit;',
 '  End;',
 '  While Mem[E:O]<>0 Do Inc(O);',
 '  Inc(O);',
 ' End;',
 'End;',
 '',
 'Function GetEnv(EnvVar: String): String;',
 'Var I,N,P: Integer; S: String;',
 'Begin',
 ' GetEnv:=''''; EnvVar:=UpStr(EnvVar);',
 ' N:=EnvCount;',
 ' For I:=1 To N Do Begin',
 '  S:=EnvStr(I); P:=Pos(''='',S);',
 '  If (P<>0) And (UpStr(Copy(S,1,P-1))=EnvVar) Then Begin',
 '   GetEnv:=Copy(S,P+1,255); Exit;',
 '  End;',
 ' End;',
 'End;',
 '',
 'Begin',
 ' DosError:=0; StubInt:=-1;',
 'End.');
const CrtSource: array[1..259] of string[255] = (
 'Unit Crt;',
 '{ Unite CRT de Turbo Pascal 7.0 : ecran texte, clavier, son.',
 '  La sortie standard est redirigee vers la memoire video par CrtWrite,',
 '  appelee par le runtime pour tout Text ouvert sur le handle 1. }',
 'Interface',
 'Const',
 ' BW40=0; CO40=1; BW80=2; CO80=3; Mono=7; Font8x8=256; C40=CO40; C80=CO80;',
 ' Black=0; Blue=1; Green=2; Cyan=3; Red=4; Magenta=5; Brown=6; LightGray=7;',
 ' DarkGray=8; LightBlue=9; LightGreen=10; LightCyan=11; LightRed=12;',
 ' LightMagenta=13; Yellow=14; White=15; Blink=128;',
 'Var',
 ' CheckBreak, CheckEOF, CheckSnow, DirectVideo: Boolean;',
 ' LastMode: Word;',
 ' TextAttr: Byte;',
 ' WindMin, WindMax: Word;',
 'Procedure AssignCrt(Var F: Text);',
 'Function KeyPressed: Boolean;',
 'Function ReadKey: Char;',
 'Procedure TextMode(Mode: Integer);',
 'Procedure Window(X1,Y1,X2,Y2: Byte);',
 'Procedure GotoXY(X,Y: Byte);',
 'Function WhereX: Byte;',
 'Function WhereY: Byte;',
 'Procedure ClrScr;',
 'Procedure ClrEol;',
 'Procedure InsLine;',
 'Procedure DelLine;',
 'Procedure TextColor(Color: Byte);',
 'Procedure TextBackground(Color: Byte);',
 'Procedure LowVideo;',
 'Procedure HighVideo;',
 'Procedure NormVideo;',
 'Procedure Delay(MS: Word);',
 'Procedure Sound(Hz: Word);',
 'Procedure NoSound;',
 'Implementation',
 'Var',
 ' VideoSeg: Word;',
 ' Cols, Rows: Byte;',
 ' NormAttr: Byte;',
 ' PendingScan: Byte;',
 ' HavePending: Boolean;',
 '',
 'Function CurX: Byte; Begin CurX:=Mem[Seg0040:$50] End;',
 'Function CurY: Byte; Begin CurY:=Mem[Seg0040:$51] End;',
 '',
 'Procedure SyncCursor(X,Y: Byte);',
 'Var Pos: Word;',
 'Begin',
 ' MemW[Seg0040:$50]:=Y*256+X;',
 ' Pos:=Y*Cols+X;',
 ' Port[$3D4]:=14; Port[$3D5]:=Hi(Pos);',
 ' Port[$3D4]:=15; Port[$3D5]:=Lo(Pos);',
 'End;',
 '',
 'Procedure FillCells(X1,Y1,X2,Y2: Byte);',
 '{ Remplit une zone d''espaces avec l''attribut courant. }',
 'Var X,Y: Byte; V: Word;',
 'Begin',
 ' V:=TextAttr*256+32;',
 ' For Y:=Y1 To Y2 Do For X:=X1 To X2 Do MemW[VideoSeg:(Y*Cols+X)*2]:=V;',
 'End;',
 '',
 'Procedure CopyRow(Src,Dst: Byte; X1,X2: Byte);',
 'Var X: Byte;',
 'Begin',
 ' For X:=X1 To X2 Do MemW[VideoSeg:(Dst*Cols+X)*2]:=MemW[VideoSeg:(Src*Cols+X)*2];',
 'End;',
 '',
 'Procedure ScrollUp(Y1,Y2: Byte);',
 'Var Y: Byte;',
 'Begin',
 ' If Y1<Y2 Then For Y:=Y1 To Y2-1 Do CopyRow(Y+1,Y,Lo(WindMin),Lo(WindMax));',
 ' FillCells(Lo(WindMin),Y2,Lo(WindMax),Y2);',
 'End;',
 '',
 'Procedure ScrollDown(Y1,Y2: Byte);',
 'Var Y: Byte;',
 'Begin',
 ' If Y1<Y2 Then For Y:=Y2 DownTo Y1+1 Do CopyRow(Y-1,Y,Lo(WindMin),Lo(WindMax));',
 ' FillCells(Lo(WindMin),Y1,Lo(WindMax),Y1);',
 'End;',
 '',
 'Procedure CrtWrite(Sg,Ofs,Count: Word);',
 '{ Appelee par le runtime: ecrit Count octets de Sg:Ofs dans la fenetre. }',
 'Var I: Word; X,Y: Byte; C: Char;',
 'Begin',
 ' If Count=0 Then Exit;',
 ' X:=CurX; Y:=CurY;',
 ' If X<Lo(WindMin) Then X:=Lo(WindMin);',
 ' If Y<Hi(WindMin) Then Y:=Hi(WindMin);',
 ' For I:=0 To Count-1 Do Begin',
 '  C:=Chr(Mem[Sg:Ofs+I]);',
 '  Case C Of',
 '   #7:Begin Sound(1000); Delay(60); NoSound End;',
 '   #8:If X>Lo(WindMin) Then Dec(X);',
 '   #10:Inc(Y);',
 '   #13:X:=Lo(WindMin);',
 '  Else',
 '   Begin',
 '    MemW[VideoSeg:(Y*Cols+X)*2]:=TextAttr*256+Ord(C);',
 '    Inc(X);',
 '    If X>Lo(WindMax) Then Begin X:=Lo(WindMin); Inc(Y) End;',
 '   End;',
 '  End;',
 '  If Y>Hi(WindMax) Then Begin ScrollUp(Hi(WindMin),Hi(WindMax)); Y:=Hi(WindMax) End;',
 ' End;',
 ' SyncCursor(X,Y);',
 'End;',
 '',
 'Procedure AssignCrt(Var F: Text);',
 'Begin',
 ' Assign(F,'''');',
 'End;',
 '',
 'Function KeyPressed: Boolean;',
 'Var R: Byte;',
 'Begin',
 ' If HavePending Then Begin KeyPressed:=True; Exit End;',
 ' R:=0;',
 ' asm',
 '  mov ah,1',
 '  int 16h',
 '  jz @@no',
 '  mov R,1',
 ' @@no:',
 ' end;',
 ' KeyPressed:=R<>0;',
 'End;',
 '',
 'Function ReadKey: Char;',
 'Var K: Word;',
 'Begin',
 ' If HavePending Then Begin HavePending:=False; ReadKey:=Chr(PendingScan); Exit End;',
 ' asm',
 '  mov ah,0',
 '  int 16h',
 '  mov K,ax',
 ' end;',
 ' If (Lo(K)=0) Or ((Lo(K)=$E0) And (Hi(K)<>0)) Then Begin',
 '  HavePending:=True; PendingScan:=Hi(K); ReadKey:=#0;',
 ' End Else ReadKey:=Chr(Lo(K));',
 'End;',
 '',
 'Procedure SetVideoVars;',
 'Begin',
 ' Cols:=MemW[Seg0040:$4A]; If Cols=0 Then Cols:=80;',
 ' Rows:=Mem[Seg0040:$84]+1; If Rows<2 Then Rows:=25;',
 ' If Mem[Seg0040:$49]=7 Then VideoSeg:=SegB000 Else VideoSeg:=SegB800;',
 ' WindMin:=0; WindMax:=(Rows-1)*256+(Cols-1);',
 'End;',
 '',
 'Procedure TextMode(Mode: Integer);',
 'Var M: Byte;',
 'Begin',
 ' M:=Lo(Mode);',
 ' asm',
 '  mov al,M',
 '  mov ah,0',
 '  int 10h',
 ' end;',
 ' If Mode And Font8x8<>0 Then',
 '  asm',
 '   mov ax,1112h',
 '   mov bl,0',
 '   int 10h',
 '  end;',
 ' LastMode:=Mode; SetVideoVars; TextAttr:=LightGray; NormAttr:=LightGray;',
 'End;',
 '',
 'Procedure Window(X1,Y1,X2,Y2: Byte);',
 'Begin',
 ' If (X1<1) Or (Y1<1) Or (X2>Cols) Or (Y2>Rows) Or (X1>X2) Or (Y1>Y2) Then Exit;',
 ' WindMin:=(Y1-1)*256+(X1-1); WindMax:=(Y2-1)*256+(X2-1);',
 ' SyncCursor(X1-1,Y1-1);',
 'End;',
 '',
 'Procedure GotoXY(X,Y: Byte);',
 'Begin',
 ' If (X<1) Or (Y<1) Then Exit;',
 ' If (Lo(WindMin)+X-1>Lo(WindMax)) Or (Hi(WindMin)+Y-1>Hi(WindMax)) Then Exit;',
 ' SyncCursor(Lo(WindMin)+X-1,Hi(WindMin)+Y-1);',
 'End;',
 '',
 'Function WhereX: Byte; Begin WhereX:=CurX-Lo(WindMin)+1 End;',
 'Function WhereY: Byte; Begin WhereY:=CurY-Hi(WindMin)+1 End;',
 '',
 'Procedure ClrScr;',
 'Begin',
 ' FillCells(Lo(WindMin),Hi(WindMin),Lo(WindMax),Hi(WindMax));',
 ' SyncCursor(Lo(WindMin),Hi(WindMin));',
 'End;',
 '',
 'Procedure ClrEol;',
 'Begin',
 ' FillCells(CurX,CurY,Lo(WindMax),CurY);',
 'End;',
 '',
 'Procedure InsLine;',
 'Begin',
 ' ScrollDown(CurY,Hi(WindMax));',
 'End;',
 '',
 'Procedure DelLine;',
 'Begin',
 ' ScrollUp(CurY,Hi(WindMax));',
 'End;',
 '',
 'Procedure TextColor(Color: Byte);',
 'Begin',
 ' TextAttr:=(TextAttr And $70) Or (Color And $8F);',
 'End;',
 '',
 'Procedure TextBackground(Color: Byte);',
 'Begin',
 ' TextAttr:=(TextAttr And $8F) Or ((Color And 7) Shl 4);',
 'End;',
 '',
 'Procedure LowVideo; Begin TextAttr:=TextAttr And $F7 End;',
 'Procedure HighVideo; Begin TextAttr:=TextAttr Or 8 End;',
 'Procedure NormVideo; Begin TextAttr:=NormAttr End;',
 '',
 'Procedure Delay(MS: Word);',
 'Begin',
 ' asm',
 '  mov ax,MS',
 '  mov bx,1000',
 '  mul bx',
 '  mov cx,dx',
 '  mov dx,ax',
 '  mov ah,86h',
 '  int 15h',
 ' end;',
 'End;',
 '',
 'Procedure Sound(Hz: Word);',
 'Var D: Word;',
 'Begin',
 ' If Hz=0 Then Exit;',
 ' D:=Word(1193180 Div Hz);',
 ' Port[$43]:=$B6;',
 ' Port[$42]:=Lo(D); Port[$42]:=Hi(D);',
 ' Port[$61]:=Port[$61] Or 3;',
 'End;',
 '',
 'Procedure NoSound;',
 'Begin',
 ' Port[$61]:=Port[$61] And $FC;',
 'End;',
 '',
 'Begin',
 ' SetVideoVars;',
 ' LastMode:=Mem[Seg0040:$49];',
 ' NormAttr:=Mem[VideoSeg:(CurY*Cols+CurX)*2+1];',
 ' If NormAttr=0 Then NormAttr:=LightGray;',
 ' TextAttr:=NormAttr;',
 ' CheckBreak:=True; CheckEOF:=False; CheckSnow:=True; DirectVideo:=True;',
 ' HavePending:=False;',
 'End.');
{ === FIN UNITES INTEGREES === }

Var
 OverlayTable,OverlayFileName,OverlayResult,OverlayHandle,OverlayScratch: Word;
 OverlayBufferSize,OverlayBankCount: Word;
 OverlaySelected: TUnitSet;
 ObjectDirs: TShortString;
 Image, Data: Array[0..MaxImage-1] Of Byte;
 Symbols: Array[1..MaxSymbols] Of TSymbol;
 Types: Array[0..MaxTypes] Of TTypeInfo;
 TypeExtras: Array[0..MaxTypes] Of TTypeExtra;
 Fields: Array[1..MaxFields] Of TRecordField;
 FieldCount: Word;
 RuntimeStandard: Array[1..96] Of Word;
 StringScratch, StringScratch2, RandomSeed: Word;
 InputAhead, InputByte, InputError: Word;
 HeapHead, HeapLimit, HeapUsed: Word;
 HeapNeeded: Boolean;
 FileModeAddress, InputHandle, InputConsoleAhead, InputFilePointer: Word;
 OutputHandle, OutputByte: Word;
 Scopes: Array[0..MaxScopes] Of TScopeInfo;
 StaticTemps: TTempPool; StaticTempsUnit: Byte;
 TempLocal, LastTempLocal: Boolean; LastTempAddr: Word;
 Dictionary: Array[0..63] Of Word;
 TypeCount, ScopeCount, CurrentScope, ExprType: Word;
 NativeTypeOwners: Array[1..MaxTypes] Of Byte;
 NativeTypeOffsets: Array[1..MaxTypes] Of Word;
 ExprUnsigned: Boolean;
 ExprKnown: Boolean;
 ExprValue: Longint;
 Fixups: Array[1..MaxFixups] Of TAddressFixup;
 RelativeFixups: Array[1..MaxFixups] Of TRelativeFixup;
 RelativeCount: Word;
 CodeOwners, DataOwners: Array[0..MaxImage-1] Of Byte;
 Defines: Array[1..MaxDefines] Of String[63];
 Conditions: Array[1..32] Of TCondition;
 SourceSize, SourcePos: Longint;
 Line, Column, TokenLine, TokenColumn: Word;
 Token: Byte;
 TokenText: TShortString;
 TokenValue: Longint;
 TokenReal: Double; TokenIsReal: Boolean;
 TokenIsString, Active: Boolean;
 CodeSize, DataSize, SymbolCount, FixupCount, DefineCount: Word;
 BssTop: Longint;             { variables globales non initialisees: allouees a partir de 65536 vers le bas }
 CondDepth: Byte;
 SourceName, OutputDir, UnitDirs, InputName, InspectName: TShortString;
 TurboDirs, LibraryName, InspectLibraryName: TShortString;
 LibraryUnits: Array[1..MaxLibraryUnits] Of TLibraryEntry;
 LibraryCount: Word;
 StackSize, MinHeap, MaxHeap: Word;
 OptionBits: Longint;
 { bits: I=1 R=2 S=4 X=8 V=$10 F=$20 B=$40 N=$80 D=$100 L=$200 E=$400 O=$800
         A=$1000 G=$2000 P=$4000 Q=$8000 T=$10000 }
 BuildMode, MakeMode, Quiet, InProcedure: Boolean;
 EntryFixup, RuntimeString, RuntimeInteger, RuntimeChar, RuntimeRawChar, BufferedCharPatch, BufferedHaltPatch: Word;
 OutputFilePointer: Word;
 StandardInputAddress, StandardOutputAddress: Word;
 RuntimeBoolean, RuntimeCopy: Word;
 NumberBuffer, TrueText, FalseText: Word;
 Units: Array[1..MaxUnits] Of TBuildUnit;
 InitOrder: Array[1..MaxUnits] Of Byte;
 UnitCount, InitCount, CurrentUnit: Byte;
 Imports: TUnitSet;
 ImportOrder: Array[1..MaxUnits] Of Byte;
 ImportCount: Byte;
 InInterface: Boolean;
 MainSourceName: TShortString;
 InitialDefines: Array[1..MaxDefines] Of String[63];
 InitialDefineCount: Word;
 InitialOptions: Longint;
 UnitOutput: Boolean;
 NativeBuffers: Array[1..MaxUnits] Of PBinaryBuffer;
 NativeHeaders: Array[1..MaxUnits] Of TUnitHeader;
 NativeCodeBases, NativeConstBases, NativeVarBases: Array[1..MaxUnits] Of Word;
 NativeActive: Array[1..MaxUnits] Of Boolean;
 NativeData: Array[0..MaxImage-1] Of Byte;
 NativeDataSize: Word;
 NativeRefs: Array[1..MaxNativeRefs] Of TNativeRef;
 NativeRefCount: Word;
 Relocations: Array[1..MaxNativeRefs] Of TMZRelocation;
 RelocationKinds: Array[1..MaxNativeRefs] Of Byte;
 RelocationCount: Word;
 NativeNeeded: Boolean;
 RuntimeHalt, MainEntry: Word;
 RuntimeError, RuntimeErrorPatch, RuntimeErrorText: Word; { "Erreur d'execution N a S:O." }
 { Resultats de fonctions String: anneau de 8 tampons de 256 octets, pour
   que F(a)+F(b) ne partage pas le meme tampon statique. }
 StringRing, StringRingPos: Word;
 CrtHook: Word;            { adresse de CRTWRITE de l'unite Crt, 0 = sortie DOS }
 { Le code (CS) et les donnees (DS) sont deux segments distincts, comme dans
   Turbo Pascal: DataSegVar est un mot du segment de code qui recoit, par la
   table de relocalisation MZ (kind 3), le paragraphe du segment de donnees. }
 DataSegVar: Word;
 CondTail: Word; CondJcc: Byte; { fin de la derniere sequence booleenne de comparaison }
 PrefixSeg: Word;          { segment du PSP, variable PrefixSeg de System }
 LinkedDataBase: Longint;  { position des donnees dans l'image liee }
 RuntimeUnsigned: Word;
 NativeInitOrder: Array[1..MaxUnits] Of Byte;
 NativeInitCount: Byte;
 ObjectFiles: Array[1..MaxObjects] Of TObjectFile;
 ObjectCount: Word;
 ObjectSegments: Array[1..MaxObjSegments] Of TObjectSegment;
 ObjectSegmentCount: Word;
 ObjectGroups: Array[1..MaxObjGroups] Of TObjectGroup;
 ObjectGroupCount: Word;
 ObjectPublics: Array[1..MaxObjNames] Of TObjectPublic;
 ObjectPublicCount: Word;
 ObjectExternals: Array[1..MaxObjNames] Of String[63];
 ObjectExternalCount: Word;
 ObjectFixups: Array[1..MaxFixups] Of TObjectFixup;
 ObjectFixupCount: Word;
 ObjectCalls: Array[1..MaxSymbols] Of TObjectCall;
 ObjectCallCount: Word;
 LinkedImage: PLinkedImage;
 LinkedSize: Longint;
 TotalLines: Longint;      { lignes compilees, affichees dans le resume }
 { Syntaxe etendue $X+: une constante chaine encore "nue" (non combinee par
   un operateur) peut etre convertie en PChar; les compteurs ci-dessous
   permettent de retirer le code deja emis pour la chaine Pascal. }
 ExprLiteral: Boolean;
 ExprLiteralText: TShortString;
 CastTarget: Word;            { type impose a un dereferencement sans type dans TRec(Pointer(P)^) }
 LiteralMarkCode, LiteralMarkFixup, LiteralMarkRelative: Word;
 LiteralMarkNative, LiteralMarkReloc, LiteralMarkData: Word;
 { Constantes typees PChar du programme: mots de Data a relocaliser. }
 DataFixups: Array[1..4096] Of Word;
 DataFixupCount: Word;
 { Break/Continue (TP 7.0): chaque boucle FOR/WHILE/REPEAT ouvre un niveau;
   les sauts emis a ce niveau sont resolus a la sortie de la boucle. }
 LoopDepth: Byte;
 LoopJumpCount: Word;
 { GOTO vers une etiquette pas encore definie }
 LabelJumps: Array[1..512] Of Record Sym, Position: Word End;
 LabelJumpCount: Word;
 LoopJumps: Array[1..MaxLoopJumps] Of Record Depth: Byte; IsBreak: Boolean; Position: Word End;
 StartTime: Longint;       { heure de depart en centiemes de seconde }
Procedure ActivateNative(U: Byte);Forward;
 Procedure QueueObject(Name: TShortString);Forward;

Function Upper(S: TShortString): TShortString;
Var
 I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Upper:=S;
End;

Function HashIdent(S: TShortString): Byte;
Var
 I: Integer;
 H: Word;
Begin
 H:=0;
 For I:=1 To Length(S) Do H:=(H+Ord(UpCase(S[I]))-1) And 255;
 HashIdent:=(H*2) And 255;
End;

Function ErrorMessage(N: Word): TShortString;Begin
 { Table des messages de Turbo Pascal 7.0, traduite en francais. }
 Case N Of
  1:ErrorMessage:='Memoire insuffisante';
  2:ErrorMessage:='Identificateur attendu';
  3:ErrorMessage:='Identificateur inconnu';
  4:ErrorMessage:='Identificateur duplique';
  5:ErrorMessage:='Erreur de syntaxe';
  6:ErrorMessage:='Erreur dans la constante reelle';
  7:ErrorMessage:='Erreur dans la constante entiere';
  8:ErrorMessage:='La constante chaine depasse la ligne';
  9:ErrorMessage:='Trop de fichiers imbriques';
  10:ErrorMessage:='Fin de fichier inattendue';
  11:ErrorMessage:='Ligne trop longue';
  12:ErrorMessage:='Identificateur de type attendu';
  13:ErrorMessage:='Trop de fichiers ouverts';
  14:ErrorMessage:='Nom de fichier invalide';
  15:ErrorMessage:='Fichier introuvable';
  16:ErrorMessage:='Disque plein';
  17:ErrorMessage:='Directive de compilation invalide';
  18:ErrorMessage:='Trop de fichiers';
  19:ErrorMessage:='Type indefini dans la definition du pointeur';
  20:ErrorMessage:='Identificateur de variable attendu';
  21:ErrorMessage:='Erreur dans le type';
  22:ErrorMessage:='Structure trop grande';
  23:ErrorMessage:='Type de base de l''ensemble hors limites';
  24:ErrorMessage:='Les composants d''un fichier ne peuvent pas etre des fichiers ou des objets';
  25:ErrorMessage:='Longueur de chaine invalide';
  26:ErrorMessage:='Types incompatibles';
  27:ErrorMessage:='Type de base d''intervalle invalide';
  28:ErrorMessage:='Borne inferieure superieure a la borne superieure';
  29:ErrorMessage:='Type ordinal attendu';
  30:ErrorMessage:='Constante entiere attendue';
  31:ErrorMessage:='Constante attendue';
  32:ErrorMessage:='Constante entiere ou reelle attendue';
  33:ErrorMessage:='Identificateur de type pointeur attendu';
  34:ErrorMessage:='Type de resultat de fonction invalide';
  35:ErrorMessage:='Identificateur d''etiquette attendu';
  36:ErrorMessage:='BEGIN attendu';
  37:ErrorMessage:='END attendu';
  38:ErrorMessage:='Expression entiere attendue';
  39:ErrorMessage:='Expression ordinale attendue';
  40:ErrorMessage:='Expression booleenne attendue';
  41:ErrorMessage:='Les types des operandes ne correspondent pas a l''operateur';
  42:ErrorMessage:='Erreur dans l''expression';
  43:ErrorMessage:='Affectation illegale';
  44:ErrorMessage:='Identificateur de champ attendu';
  45:ErrorMessage:='Fichier objet trop grand';
  46:ErrorMessage:='EXTERNAL indefini';
  47:ErrorMessage:='Enregistrement de fichier objet invalide';
  48:ErrorMessage:='Segment de code trop grand';
  49:ErrorMessage:='Segment de donnees trop grand';
  50:ErrorMessage:='DO attendu';
  51:ErrorMessage:='Definition PUBLIC invalide';
  52:ErrorMessage:='Definition EXTRN invalide';
  53:ErrorMessage:='Trop de definitions EXTRN';
  54:ErrorMessage:='OF attendu';
  55:ErrorMessage:='INTERFACE attendu';
  56:ErrorMessage:='Reference relogeable invalide';
  57:ErrorMessage:='THEN attendu';
  58:ErrorMessage:='TO ou DOWNTO attendu';
  59:ErrorMessage:='FORWARD indefini';
  60:ErrorMessage:='Trop de procedures';
  61:ErrorMessage:='Transtypage invalide';
  62:ErrorMessage:='Division par zero';
  63:ErrorMessage:='Type de fichier invalide';
  64:ErrorMessage:='Impossible de lire ou d''ecrire des variables de ce type';
  65:ErrorMessage:='Variable pointeur attendue';
  66:ErrorMessage:='Variable chaine attendue';
  67:ErrorMessage:='Expression chaine attendue';
  68:ErrorMessage:='Reference circulaire d''unites';
  69:ErrorMessage:='Nom d''unite different';
  70:ErrorMessage:='Version d''unite differente';
  71:ErrorMessage:='Debordement de la pile interne';
  72:ErrorMessage:='Erreur de format du fichier d''unite';
  73:ErrorMessage:='IMPLEMENTATION attendu';
  74:ErrorMessage:='Les types de la constante et du CASE ne correspondent pas';
  75:ErrorMessage:='Variable record ou objet attendue';
  76:ErrorMessage:='Constante hors limites';
  77:ErrorMessage:='Variable fichier attendue';
  78:ErrorMessage:='Expression pointeur attendue';
  79:ErrorMessage:='Expression entiere ou reelle attendue';
  80:ErrorMessage:='Etiquette hors du bloc courant';
  81:ErrorMessage:='Etiquette deja definie';
  82:ErrorMessage:='Etiquette indefinie dans la partie instruction precedente';
  83:ErrorMessage:='Argument @ invalide';
  84:ErrorMessage:='UNIT attendu';
  85:ErrorMessage:='";" attendu';
  86:ErrorMessage:='":" attendu';
  87:ErrorMessage:='"," attendu';
  88:ErrorMessage:='"(" attendu';
  89:ErrorMessage:='")" attendu';
  90:ErrorMessage:='"=" attendu';
  91:ErrorMessage:='":=" attendu';
  92:ErrorMessage:='"[" ou "(." attendu';
  93:ErrorMessage:='"]" ou ".)" attendu';
  94:ErrorMessage:='"." attendu';
  95:ErrorMessage:='".." attendu';
  96:ErrorMessage:='Trop de variables';
  97:ErrorMessage:='Variable de controle FOR invalide';
  98:ErrorMessage:='Variable entiere attendue';
  99:ErrorMessage:='Les fichiers et les types proceduraux ne sont pas autorises ici';
  100:ErrorMessage:='Longueurs de chaines differentes';
  101:ErrorMessage:='Ordre des champs invalide';
  102:ErrorMessage:='Constante chaine attendue';
  103:ErrorMessage:='Variable entiere ou reelle attendue';
  104:ErrorMessage:='Variable ordinale attendue';
  105:ErrorMessage:='Erreur INLINE';
  106:ErrorMessage:='Expression caractere attendue';
  107:ErrorMessage:='Trop d''elements de relocalisation';
  108:ErrorMessage:='Debordement dans une operation arithmetique';
  109:ErrorMessage:='Aucune instruction FOR, WHILE ou REPEAT englobante';
  110:ErrorMessage:='Debordement de la table d''informations de debogage';
  112:ErrorMessage:='Constante CASE hors limites';
  113:ErrorMessage:='Erreur dans l''instruction';
  114:ErrorMessage:='Impossible d''appeler une procedure d''interruption';
  116:ErrorMessage:='Doit etre en mode 8087 pour compiler ceci';
  117:ErrorMessage:='Adresse cible introuvable';
  118:ErrorMessage:='Les fichiers d''inclusion ne sont pas autorises ici';
  119:ErrorMessage:='Aucune methode heritee n''est accessible ici';
  121:ErrorMessage:='Qualificateur invalide';
  122:ErrorMessage:='Reference de variable invalide';
  123:ErrorMessage:='Trop de symboles';
  124:ErrorMessage:='Partie instruction trop grande';
  126:ErrorMessage:='Les fichiers doivent etre des parametres VAR';
  127:ErrorMessage:='Trop de symboles conditionnels';
  128:ErrorMessage:='Directive conditionnelle mal placee';
  129:ErrorMessage:='Directive ENDIF manquante';
  130:ErrorMessage:='Erreur dans les definitions conditionnelles initiales';
  131:ErrorMessage:='L''en-tete ne correspond pas a la definition precedente';
  132:ErrorMessage:='Erreur disque critique';
  133:ErrorMessage:='Impossible d''evaluer cette expression';
  134:ErrorMessage:='Expression terminee incorrectement';
  135:ErrorMessage:='Specificateur de format invalide';
  136:ErrorMessage:='Reference indirecte invalide';
  137:ErrorMessage:='Les variables structurees ne sont pas autorisees ici';
  138:ErrorMessage:='Impossible d''evaluer sans l''unite System';
  139:ErrorMessage:='Impossible d''acceder a ce symbole';
  140:ErrorMessage:='Operation en virgule flottante invalide';
  141:ErrorMessage:='Impossible de compiler les overlays en memoire';
  142:ErrorMessage:='Variable procedure ou fonction attendue';
  143:ErrorMessage:='Reference de procedure ou de fonction invalide';
  144:ErrorMessage:='Impossible de mettre cette unite en overlay';
  145:ErrorMessage:='Trop de portees imbriquees';
  146:ErrorMessage:='Acces au fichier refuse';
  147:ErrorMessage:='Type objet attendu';
  148:ErrorMessage:='Les types objets locaux ne sont pas autorises';
  149:ErrorMessage:='VIRTUAL attendu';
  150:ErrorMessage:='Identificateur de methode attendu';
  151:ErrorMessage:='Les constructeurs virtuels ne sont pas autorises';
  152:ErrorMessage:='Identificateur de constructeur attendu';
  153:ErrorMessage:='Identificateur de destructeur attendu';
  154:ErrorMessage:='Fail n''est autorise que dans les constructeurs';
  155:ErrorMessage:='Combinaison invalide de code operation et d''operandes';
  156:ErrorMessage:='Reference memoire attendue';
  157:ErrorMessage:='Impossible d''ajouter ou de soustraire des symboles relogeables';
  158:ErrorMessage:='Combinaison de registres invalide';
  159:ErrorMessage:='Les instructions 286/287 ne sont pas activees';
  160:ErrorMessage:='Reference de symbole invalide';
  161:ErrorMessage:='Erreur de generation de code';
  162:ErrorMessage:='Adresse hors limites';
 Else ErrorMessage:='Erreur du compilateur';
End;
End;

Procedure Fail(N: Word; S: TShortString);Begin
 Write(SourceName,'(',TokenLine,',',TokenColumn,'): Erreur ',N,': ',ErrorMessage(N),'.');
 If S<>'' Then Write(' (',S,')');
 WriteLn;
 Halt(1);
End;

Procedure Unsupported(S: TShortString);Begin
 WriteLn(SourceName,'(',TokenLine,',',TokenColumn,
 '): TPC: fonctionnalite non implementee: ',S);
 Halt(2);
End;

Procedure CLIError(S: TShortString);Begin
 WriteLn('TPC: ',S);
 Halt(2);
End;

Function Peek: Char;Begin
 If SourcePos>SourceSize Then Peek:=#0 Else Peek:=Source[SourcePos];
End;

Function PeekNext: Char;Begin
 If SourcePos>=SourceSize Then PeekNext:=#0 Else PeekNext:=Source[SourcePos+1];
End;
Function NextNonBlank: Char;
{ Premier caractere non blanc apres le jeton courant (sans consommer). }
Var P: Longint;
Begin
 P:=SourcePos; While (P<=SourceSize) And (Source[P]<=' ') Do Inc(P);
 If P>SourceSize Then NextNonBlank:=#0 Else NextNonBlank:=Source[P];
End;

Procedure Advance;Begin
 If Peek=#10 Then Begin
  Inc(Line); Column:=1
 End
 Else Inc(Column);
 Inc(SourcePos);
End;

Procedure AppendChar(Var S: TShortString; C: Char);Begin
 If Length(S)=255 Then Unsupported('chaine ou lexeme > 255 octets');
 S:=S+C;
End;

Function IsDefined(S: TShortString): Boolean;
Var
 I: Word;
Begin
 S:=Upper(S);
 IsDefined:=False;
 For I:=1 To DefineCount Do If Defines[I]=S Then IsDefined:=True;
End;

Procedure Define(S: TShortString);Begin
 S:=Upper(S);
 If (S='') Or (Length(S)>63) Then Fail(2,'Identificateur de define attendu');
 If Not IsDefined(S) Then Begin
  If DefineCount=MaxDefines Then Unsupported('trop de defines');
  Inc(DefineCount); Defines[DefineCount]:=S;
 End;
End;

Procedure Undefine(S: TShortString);
Var
 I: Word;
Begin
 S:=Upper(S);
 For I:=1 To DefineCount Do If Defines[I]=S Then Defines[I]:='';
End;

Function Trim(S: TShortString): TShortString;Begin
 While (Length(S)>0) And (S[1]<=' ') Do Delete(S,1,1);
 While (Length(S)>0) And (S[Length(S)]<=' ') Do Delete(S,Length(S),1);
 Trim:=S;
End;

Function SwitchBit(C: Char): Longint;Begin
 Case UpCase(C) Of
 'I':SwitchBit:=$0001; 'R':SwitchBit:=$0002; 'S':SwitchBit:=$0004;
 'X':SwitchBit:=$0008; 'V':SwitchBit:=$0010; 'F':SwitchBit:=$0020;
 'B':SwitchBit:=$0040; 'N':SwitchBit:=$0080; 'D':SwitchBit:=$0100;
 'L':SwitchBit:=$0200; 'E':SwitchBit:=$0400; 'O':SwitchBit:=$0800;
 'A':SwitchBit:=$1000; 'G':SwitchBit:=$2000;
 'P':SwitchBit:=$4000; 'Q':SwitchBit:=$8000; 'T':SwitchBit:=$10000;
 { K, W, Y, Z: reconnus par TP 7.0, sans effet en mode reel. }
 'K':SwitchBit:=$20000; 'W':SwitchBit:=$40000; 'Y':SwitchBit:=$80000; 'Z':SwitchBit:=$100000;
 Else SwitchBit:=0;
End;
End;

Function ExtendedSyntax: Boolean;Begin
 ExtendedSyntax:=OptionBits And 8<>0;
End;

Procedure SetSwitch(S: TShortString);
Var
 B: Longint;
Begin
 If (Length(S)<>2) Or Not (S[2] In ['+','-']) Then    CLIError(
 'Option attendue sous la forme $X+ ou $X-');
 B:=SwitchBit(S[1]);
 If B=0 Then CLIError('Option inconnue: $'+S);
 If S[2]='+' Then Begin
  OptionBits:=OptionBits Or B;
  If UpCase(S[1]) In ['D','L'] Then DebugRequested:=True;
  If UpCase(S[1])='O' Then UnitFeatures[CurrentUnit]:=UnitFeatures[CurrentUnit] Or 4;
 End Else OptionBits:=OptionBits And Not B;
End;

Procedure MemoryDirective(S: TShortString);
Var
 A: Array[1..3] Of Longint;
 I, P, E: Integer;
 Part: TShortString;
Begin
 For I:=1 To 3 Do Begin
  P:=Pos(',',S);
  If P=0 Then Begin
   Part:=Trim(S); S:=''
  End
   Else
  Begin
   Part:=Trim(Copy(S,1,P-1)); Delete(S,1,P)
  End;
  Val(Part,A[I],E);
  If E<>0 Then Fail(17,'Directive $M incorrecte');
 End;
 If (S<>'') Or (A[1]<1024) Or (A[1]>65520) Or
 (A[2]<0) Or (A[2]>655360) Or (A[3]<A[2]) Or (A[3]>655360) Then    Fail(17,
 'Limites $M incorrectes');
 If A[2]<>0 Then Unsupported('$M minheap non nul');
 StackSize:=(A[1]+1) And $FFFE;
 MinHeap:=0; MaxHeap:=(A[3]+15) Div 16;
End;

Procedure SaveParser(Var P: PParserState); Forward;
Procedure OpenBinaryRead(Var F: File; Var E: Integer); Forward;
Function FileExists(S: TShortString): Boolean; Forward;
Function JoinPath(Dir, Name: TShortString): TShortString; Forward;

Function ReadWhole(Var F: File): Integer;
{ Lit SourceSize octets du fichier dans Source par blocs de 32 Ko. }
Var Done: Longint; Chunk,Count: Word; E: Integer;
Begin
 Done:=0; E:=0;
 While (Done<SourceSize) And (E=0) Do Begin
  If SourceSize-Done>32768 Then Chunk:=32768 Else Chunk:=SourceSize-Done;
  {$I-} BlockRead(F,Source[Done+1],Chunk,Count); E:=IOResult; {$I+}
  If (E=0) And (Count<>Chunk) Then E:=100;
  Inc(Done,Chunk);
 End;
 ReadWhole:=E;
End;

Procedure IncludeSource(Name: TShortString);
Var F: File; Count: Word; Err,Sep: Integer; Path,Search,Part: TShortString;
 D: DirStr; N: NameStr; E: ExtStr; K: Byte; Saved: PParserState;
Begin
 Name:=Trim(Name);
 If (Length(Name)>=2) And (Name[1] In ['''','"']) And (Name[Length(Name)]=Name[1]) Then Name:=Copy(Name,2,Length(Name)-2);
 If Name='' Then Fail(2,'Nom du fichier include attendu');
 FSplit(SourceName,D,N,E); Search:=D+';.;'+IncludeDirs; Path:='';
 Repeat
  Sep:=Pos(';',Search); If Sep=0 Then Begin Part:=Search; Search:='' End
  Else Begin Part:=Copy(Search,1,Sep-1); Delete(Search,1,Sep) End;
  Path:=JoinPath(Part,Name); If FileExists(Path) Then Break;
  Path:='';
 Until Search='';
 If Path='' Then Fail(15,'Include introuvable: '+Name);
 If Upper(FExpand(Path))=Upper(FExpand(SourceName)) Then Fail(68,'Include circulaire');
 For K:=1 To IncludeDepth Do If Upper(FExpand(Path))=Upper(FExpand(IncludeStack[K]^.SourceName)) Then Fail(68,'Include circulaire');
 If IncludeDepth=16 Then Fail(123,'Includes imbriques >16');
 Assign(F,Path); OpenBinaryRead(F,Err); If Err<>0 Then Fail(15,'Ouverture include impossible');
 If FileSize(F)>MaxSource Then Begin Close(F); Fail(49,'Include trop grand') End;
 SaveParser(Saved); Inc(IncludeDepth); IncludeStack[IncludeDepth]:=Saved;
 SourceSize:=FileSize(F);
 Err:=ReadWhole(F); Close(F);
 If Err<>0 Then Fail(15,'Lecture include impossible');
 SourceName:=Path; SourcePos:=1; Line:=1; Column:=1;
End;

Procedure ReportSource;
{ TPC 7.0 affiche FICHIER(ligne) pour chaque source compile et cumule les
  lignes pour le resume final. }
Var N: Longint;
Begin
 N:=Line;
 If (SourceSize>0) And (Source[SourceSize]=#10) And (N>1) Then Dec(N);
 Inc(TotalLines,N);
 If Not Quiet Then WriteLn(SourceName,'(',N,')');
End;

Procedure EndInclude;
Var P: PParserState;
Begin
 P:=IncludeStack[IncludeDepth];
 If CondDepth<>P^.CondDepth Then Fail(129,'Condition non terminee dans include');
 ReportSource;
 Move(P^.Buffer^,Source,P^.SourceSize); SourceName:=P^.SourceName;
 SourceSize:=P^.SourceSize; SourcePos:=P^.SourcePos; Line:=P^.Line; Column:=P^.Column;
 Dispose(P^.Buffer); Dispose(P); Dec(IncludeDepth);
End;

Procedure SelectOverlay(Name: TShortString);
Var U: Byte;
Begin
 If CurrentUnit<>0 Then Fail(17,'$O unite reserve au programme');
 Name:=Upper(Trim(Name));
 For U:=1 To UnitCount Do If Units[U].Name=Name Then Begin
  If UnitFeatures[U] And 4=0 Then Fail(17,'Unite non compilee avec $O+: '+Name);
  OverlaySelected:=OverlaySelected+[U]; Exit;
 End;
 Fail(3,'Unite overlay inconnue: '+Name);
End;

Procedure Directive(S: TShortString);
Var
 P: Integer;
 Cmd, Arg: TShortString;
 Test: Boolean;
Begin
 S:=Trim(S);
 P:=1;
 While (P<=Length(S)) And (S[P]>' ') Do Inc(P);
 Cmd:=Upper(Copy(S,1,P-1)); Arg:=Trim(Copy(S,P+1,255));
 If (Cmd='IFDEF') Or (Cmd='IFNDEF') Or (Cmd='IFOPT') Then Begin
  If CondDepth=32 Then Unsupported('imbrication conditionnelle > 32');
  If Cmd='IFOPT' Then Begin
   Arg:=Upper(Arg);
   If (Length(Arg)<>2) Or Not (Arg[2] In ['+','-']) Or (SwitchBit(Arg[1])=0) Then Fail(17,'$IFOPT invalide');
   Test:=(OptionBits And SwitchBit(Arg[1])<>0)=(Arg[2]='+');
  End Else Begin Test:=IsDefined(Arg); If Cmd='IFNDEF' Then Test:=Not Test End;
  Inc(CondDepth);
  Conditions[CondDepth].ParentActive:=Active;
  Conditions[CondDepth].Test:=Test;
  Conditions[CondDepth].SeenElse:=False;
  Active:=Active And Test;
 End Else If Cmd='ELSE' Then Begin
  If CondDepth=0 Then Fail(128,'$ELSE sans $IFDEF');
  If Conditions[CondDepth].SeenElse Then Fail(128,'$ELSE duplique');
  Conditions[CondDepth].SeenElse:=True;
  Active:=Conditions[CondDepth].ParentActive And Not Conditions[CondDepth].Test;
 End Else If Cmd='ENDIF' Then Begin
  If CondDepth=0 Then Fail(128,'$ENDIF sans $IFDEF');
  Active:=Conditions[CondDepth].ParentActive; Dec(CondDepth);
 End Else If Active Then Begin
  If Cmd='DEFINE' Then Define(Arg) Else
  If Cmd='UNDEF' Then Undefine(Arg) Else
  If (Cmd='I') Or (Cmd='INCLUDE') Then IncludeSource(Arg) Else
  If Cmd='O' Then SelectOverlay(Arg) Else
  If (Cmd='L') Or (Cmd='LINK') Then QueueObject(Arg) Else
  If (Pos(',',Cmd)<>0) And (Cmd[1]<>'M') Then Begin
   Repeat P:=Pos(',',S); If P=0 Then Begin SetSwitch(Upper(Trim(S))); Break End;
    SetSwitch(Upper(Trim(Copy(S,1,P-1)))); Delete(S,1,P);
   Until False;
  End Else If (Length(Cmd)=2) And (Cmd[2] In ['+','-']) Then SetSwitch(Cmd) Else
  If (Length(Cmd)>0) And (Cmd[1]='M') Then      MemoryDirective(Trim(Copy(S,2,255)))
                                      Else Unsupported('directive $'+S);
 End;
End;

Procedure SkipComment(Paren: Boolean);
Var
 S: TShortString;
 IsDirective, Closed: Boolean;
Begin
 Advance; If Paren Then Advance;
 IsDirective:=Peek='$'; If IsDirective Then Advance;
 S:=''; Closed:=False;
 While (Peek<>#0) And Not Closed Do Begin
  If (Not Paren And (Peek='}')) Or
  (Paren And (Peek='*') And (PeekNext=')')) Then Begin
   Advance; If Paren Then Advance; Closed:=True;
  End Else
  Begin
   If IsDirective Then AppendChar(S,Peek);
   Advance;
  End;
 End;
 If Not Closed Then Fail(10,'Fin de fichier dans un commentaire');
 If IsDirective Then Directive(S);
End;

Function Keyword(S: TShortString): Byte;
Const
 Names: Array[1..51] Of String[14] = (
 'AND','ARRAY','BEGIN','CASE','CONST','CONSTRUCTOR','DESTRUCTOR','DIV',
 'DO','DOWNTO','ELSE','END','ASM','EXPORTS','FILE','FOR','FUNCTION','GOTO','IF',
 'IMPLEMENTATION','IN','INHERITED','INLINE','INTERFACE','LABEL','LIBRARY','MOD','NIL','NOT',
 'OBJECT','OF','OR','PACKED','PROCEDURE','PROGRAM','RECORD','REPEAT',
 'SET','SHL','SHR','STRING','THEN','TYPE','TO','UNIT','UNTIL','USES',
 'VAR','WHILE','WITH','XOR');
 Values: Array[1..51] Of Byte = (
 28,29,30,31,32,33,34,35,36,37,38,39,40,43,41,42,44,45,46,47,48,75,49,
 50,52,51,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,
 72,73,74,76,77,78);
Var
 I: Integer;
Begin
 Keyword:=tkIdent;
 For I:=1 To 51 Do If S=Names[I] Then Keyword:=Values[I];
End;

Function ReadNumber: Longint;
Var
 Base, Digit: Integer;
 N: Int64;
 C: Char;
Begin
 Base:=10; N:=0;
 If Peek='$' Then Begin
  Base:=16; Advance
 End;
 If ((Base=10) And Not (Peek In ['0'..'9'])) Or
 ((Base=16) And Not (UpCase(Peek) In ['0'..'9','A'..'F'])) Then    Fail(7,
 'Nombre attendu');
 While True Do Begin
  C:=UpCase(Peek);
  If C In ['0'..'9'] Then Digit:=Ord(C)-Ord('0') Else
  If (Base=16) And (C In ['A'..'F']) Then Digit:=Ord(C)-Ord('A')+10
                                     Else Break;
  If Digit>=Base Then Break;
  { TP 7.0: une constante hexadecimale va jusqu'a $FFFFFFFF (Longint negatif). }
  If Base=16 Then Begin If N>($FFFFFFFF-Digit) Div 16 Then Fail(7,'Constante hors limites') End
  Else If N>(2147483647-Digit) Div Base Then Fail(7,'Constante hors limites');
  N:=N*Base+Digit; Advance;
 End;
 If N>2147483647 Then N:=N-4294967296;
 ReadNumber:=N;
End;

Function ReadAssemblyNumber: Longint;
Var S: TShortString; E: Integer; N: Longint;
Begin
 If Peek='$' Then Begin ReadAssemblyNumber:=ReadNumber; Exit End;
 S:=''; While UpCase(Peek) In ['0'..'9','A'..'F','H','O','Q','T'] Do Begin AppendChar(S,UpCase(Peek)); Advance End;
 If S[Length(S)]='H' Then S:='$'+Copy(S,1,Length(S)-1)
 Else If S[Length(S)]='B' Then S:='%'+Copy(S,1,Length(S)-1)
 Else If S[Length(S)] In ['O','Q'] Then S:='&'+Copy(S,1,Length(S)-1)
 Else If S[Length(S)] In ['D','T'] Then Delete(S,Length(S),1);
 Val(S,N,E); If E<>0 Then Fail(7,'Constante assembleur invalide'); ReadAssemblyNumber:=N;
End;

Procedure NextToken;
Var
 C: Char;
 N: Longint;
 Closed: Boolean;
Begin
 Repeat
 If (Peek=#0) And (IncludeDepth<>0) And (IncludeStack[IncludeDepth]^.CurrentUnit=CurrentUnit) Then Begin EndInclude; Continue End;
 While (Peek<>#0) And (Peek<=' ') Do Advance;
 If (Peek=#0) And (IncludeDepth<>0) And (IncludeStack[IncludeDepth]^.CurrentUnit=CurrentUnit) Then Begin EndInclude; Continue End;
 TokenLine:=Line; TokenColumn:=Column;
 If Peek='{' Then SkipComment(False) Else
 If (Peek='(') And (PeekNext='*') Then SkipComment(True) Else
 If Not Active And (Peek<>#0) Then Advance
                              Else Break;
 Until False;
 TokenText:=''; TokenValue:=0; TokenIsString:=False; TokenIsReal:=False; TokenReal:=0;
 TokenLine:=Line; TokenColumn:=Column; C:=Peek;
 If C=#0 Then Begin
  If CondDepth<>0 Then Fail(129,'$ENDIF manquant');
  Token:=tkEOF; Exit;
 End;
 If UpCase(C) In ['A'..'Z','_'] Then Begin
  While UpCase(Peek) In ['A'..'Z','0'..'9','_'] Do Begin
   AppendChar(TokenText,UpCase(Peek)); Advance;
  End;
  If Length(TokenText)>63 Then Unsupported('identificateur > 63 caracteres');
  { System.Ident: le qualificatif de l'unite System est implicite. }
  If (TokenText='SYSTEM') And (Peek='.') And (UpCase(PeekNext) In ['A'..'Z','_']) Then Begin
   Advance; TokenText:='';
   While UpCase(Peek) In ['A'..'Z','0'..'9','_'] Do Begin AppendChar(TokenText,UpCase(Peek)); Advance End;
  End;
  Token:=Keyword(TokenText); Exit;
 End;
 If C In ['0'..'9','$'] Then Begin
  Token:=tkConstant;
  If InAssembler Then TokenValue:=ReadAssemblyNumber
  Else If C='$' Then TokenValue:=ReadNumber
  Else Begin
   While Peek In ['0'..'9'] Do Begin AppendChar(TokenText,Peek); Advance End;
   If (Peek='.') And (PeekNext<>'.') Then Begin
    TokenIsReal:=True; AppendChar(TokenText,'.'); Advance;
    While Peek In ['0'..'9'] Do Begin AppendChar(TokenText,Peek); Advance End;
   End;
   If UpCase(Peek)='E' Then Begin
    TokenIsReal:=True; AppendChar(TokenText,'E'); Advance;
    If Peek In ['+','-'] Then Begin AppendChar(TokenText,Peek); Advance End;
    If Not (Peek In ['0'..'9']) Then Fail(7,'Exposant reel invalide');
    N:=0;
    While Peek In ['0'..'9'] Do Begin
     AppendChar(TokenText,Peek); If N<100000 Then N:=N*10+Ord(Peek)-48; Advance;
    End;
    If N>38 Then Fail(76,'Constante reelle hors limites (Real 6 octets)');
   End;
   If TokenIsReal Then Begin
    Val(TokenText,TokenReal,N); If N<>0 Then Fail(7,'Constante reelle invalide');
    If Abs(TokenReal)>1.701411834603E38 Then Fail(76,'Constante reelle hors limites (Real 6 octets)');
   End
   Else Begin Val(TokenText,TokenValue,N); If N<>0 Then Fail(7,'Constante hors limites') End;
  End;
  Exit;
 End;
 If C In ['''','#'] Then Begin
  Token:=tkConstant; TokenIsString:=True;
  Repeat
  If Peek='#' Then Begin
   Advance; N:=ReadNumber;
   If N>255 Then Fail(76,'Code caractere hors limites');
   AppendChar(TokenText,Chr(N));
  End Else
  Begin
   Advance; Closed:=False;
   While Not Closed Do Begin
    If Peek In [#0,#10,#13] Then Fail(8,'Chaine non terminee');
    If Peek='''' Then Begin
     Advance;
     If Peek='''' Then Begin
      AppendChar(TokenText,''''); Advance
     End
     Else Closed:=True;
    End Else
    Begin
     AppendChar(TokenText,Peek); Advance
    End;
   End;
  End;
  Until Not (Peek In ['''','#']);
  Exit;
 End;
 Advance;
 Case C Of
 '+':Token:=tkPlus; '-':Token:=tkMinus; '*':Token:=tkTimes;
 '/':Token:=tkSlash; '=':Token:=tkEqual; '(':Token:=tkLP;
 ')':Token:=tkRP; '[':Token:=tkLB; ']':Token:=tkRB;
 ',':Token:=tkComma; ';':Token:=tkSemi; '@':Token:=tkAt;
 '^':Begin
  { ^Z est une constante caractere (#26) sauf apres un designateur (P^) ou
    devant un identificateur de type (^String). }
  If (UpCase(Peek) In ['@','A'..'Z','[','\',']','_']) And
     Not (UpCase(PeekNext) In ['A'..'Z','0'..'9','_']) And
     Not (Token In [tkIdent,tkRP,tkRB,tkCaret]) Then Begin
   Token:=tkConstant; TokenIsString:=True; TokenText:=Chr(Ord(UpCase(Peek))-64); Advance;
   { ^M^J: caracteres de controle juxtaposes = une seule chaine }
   While (Peek='^') And (UpCase(PeekNext) In ['@','A'..'Z','[','\',']','_']) And
         ((SourcePos+2>SourceSize) Or Not (UpCase(Source[SourcePos+2]) In ['A'..'Z','0'..'9','_'])) Do Begin
    Advance; AppendChar(TokenText,Chr(Ord(UpCase(Peek))-64)); Advance;
   End;
  End Else Token:=tkCaret;
 End;
 ':':
 Begin
  Token:=tkColon; If Peek='=' Then Begin
   Advance; Token:=tkAssign
  End
 End;
 '.':
 Begin
  Token:=tkDot; If Peek='.' Then Begin
   Advance; Token:=tkRange
  End
 End;
 '<':
 Begin
  Token:=tkLess;
  If Peek='=' Then Begin
   Advance; Token:=tkLE
  End
  Else If Peek='>' Then Begin
   Advance; Token:=tkNE
  End;
 End;
 '>':
 Begin
  Token:=tkGreater; If Peek='=' Then Begin
   Advance; Token:=tkGE
  End
 End;
 Else Fail(5,'Caractere inattendu');
End;
End;

Procedure Need(T: Byte);
Var
 E: Word;
Begin
 If Token<>T Then Begin
  Case T Of
  tkIdent:E:=2; tkBegin:E:=36; tkEnd:E:=37; tkDo:E:=50;
  tkOf:E:=54; tkInterface:E:=55; tkThen:E:=57;
  tkImplementation:E:=73; tkUnit:E:=84;
  tkSemi:E:=85; tkColon:E:=86; tkComma:E:=87; tkLP:E:=88;
  tkRP:E:=89; tkEqual:E:=90; tkAssign:E:=91; tkLB:E:=92;
  tkRB:E:=93; tkDot:E:=94; tkRange:E:=95; tkNil:E:=5;
  Else E:=5;
 End;
 Fail(E,'');
End;
NextToken;
End;

Procedure Emit(B: Byte);Begin
 If CodeSize=MaxImage Then Fail(48,'Segment de code trop grand');
 CodeOwners[CodeSize]:=CurrentUnit;
 If CurrentUnit In [253,254] Then CodeOwners[CodeSize]:=0;
 Image[CodeSize]:=B; Inc(CodeSize);
End;

Procedure EmitWord(W: Word);Begin
 Emit(W And 255); Emit(W Shr 8)
End;

Procedure PatchWord(P, W: Word);Begin
 Image[P]:=W And 255; Image[P+1]:=W Shr 8
End;

Procedure Emit2(A,B: Byte);Begin
 Emit(A); Emit(B)
End;

Function Jump: Word;Begin
 Emit($E9); Jump:=CodeSize; EmitWord(0)
End;

Procedure PatchJump(P, Target: Word);
Var
 I: Word;
Begin
 PatchWord(P,Word(Longint(Target)-P-2));
 For I:=1 To RelativeCount Do If RelativeFixups[I].Position=P Then Begin
  RelativeFixups[I].Target:=Target; Exit;
 End;
 If RelativeCount=MaxFixups Then Unsupported('trop de references de code');
 Inc(RelativeCount); RelativeFixups[RelativeCount].Position:=P;
 RelativeFixups[RelativeCount].Target:=Target;
End;

Procedure JumpTo(Target: Word);
Var
 P: Word;
Begin
 P:=Jump; PatchJump(P,Target)
End;

Function TailConst(Var V: Word): Boolean;
{ Si le code se termine par "push ax; mov ax,imm16" (operande droit
  constant), retire ces 4 octets et rend la constante. }
Begin
 TailConst:=False;
 If (CodeSize>=4) And (Image[CodeSize-4]=$50) And (Image[CodeSize-3]=$B8) Then Begin
  V:=Image[CodeSize-2]+Word(Image[CodeSize-1])*256; CodeSize:=CodeSize-4; TailConst:=True;
 End;
End;

Function JumpZeroKeep: Word;Begin
 { AX doit rester le resultat booleen (0) a la cible: pas de raccourci. }
 Emit2($09,$C0); Emit2($75,$03); JumpZeroKeep:=Jump;
End;

Function JumpZero: Word;Begin
 If (CondTail=CodeSize) And (CodeSize>=7) Then Begin
  { La comparaison vient de produire "mov ax,1; jcc +2; xor ax,ax":
    sauter directement sur la condition inverse. }
  CodeSize:=CodeSize-7; Emit2(CondJcc,3); JumpZero:=Jump; Exit;
 End;
 Emit2($09,$C0);             { or ax,ax }
 Emit2($75,$03);             { jnz +3: 8086 n'a pas Jcc near }
 JumpZero:=Jump;
End;

Procedure CallTo(Target: Word);
Var
 P: Word;
Begin
 Emit($E8); P:=CodeSize; EmitWord(0); PatchJump(P,Target)
End;

Procedure LoadImmediate(W: Word);Begin
 Emit($B8); EmitWord(W)
End;

Procedure EmitLoadDS;Begin
 Emit($2E); Emit2($8E,$1E); EmitWord(DataSegVar); { mov ds,cs:[DataSegVar] }
End;

Procedure EmitLoadES;Begin
 Emit($2E); Emit2($8E,$06); EmitWord(DataSegVar); { mov es,cs:[DataSegVar] }
End;

Procedure DataAddress(Offs: Word);Begin
 If FixupCount=MaxFixups Then Unsupported('trop de references de donnees');
 Inc(FixupCount); Fixups[FixupCount].Position:=CodeSize;
 Fixups[FixupCount].DataOffset:=Offs; EmitWord(0);
End;

Function BssSize: Word;
Begin BssSize:=65536-BssTop End;

Function AllocBss(N: Word): Word;
{ Variable globale du programme (non initialisee). Les adresses provisoires
  sont dans [BssTop,65536) et sont ramenees apres les constantes par
  FinalDataAddress lors de l'edition des liens. }
Begin
 If Longint(DataSize)+BssSize+N>MaxImage Then Fail(49,'Segment de donnees trop grand');
 BssTop:=BssTop-N; AllocBss:=Word(BssTop);
End;

Function FinalDataAddress(A: Word): Word;
Begin
 If (BssTop<65536) And (A>=BssTop) Then FinalDataAddress:=DataSize+(A-BssTop)
 Else FinalDataAddress:=A;
End;

Function AllocData(N: Word): Word;
Var
 I: Word;
Begin
 If Longint(DataSize)+N+BssSize>MaxImage Then Fail(49,'Segment de donnees trop grand');
 If N<>0 Then
 For I:=DataSize To DataSize+N-1 Do Begin
  DataOwners[I]:=CurrentUnit; If CurrentUnit In [253,254] Then DataOwners[I]:=0;
 End;
 AllocData:=DataSize; Inc(DataSize,N);
End;

Function StoreString(S: TShortString): Word;
Var
 A: Word;
 I: Integer;
Begin
 A:=AllocData(Length(S)+1); Data[A]:=Ord(S[0]);
 For I:=1 To Length(S) Do Data[A+I]:=Ord(S[I]);
 StoreString:=A;
End;

Function FindAtScope(S: TShortString; Owner: Byte; Scope: Word): Word;
Var I: Word;
Begin
 I:=Dictionary[(HashIdent(S) And 126) Div 2];
 While I<>0 Do Begin
  If (Symbols[I].Name=S) And (Symbols[I].Owner=Owner) And
    (Symbols[I].Scope=Scope) Then Begin FindAtScope:=I; Exit End;
  I:=Symbols[I].HashNext;
 End;
 FindAtScope:=0;
End;

Function FindOwnSymbol(S: TShortString): Word;
Begin FindOwnSymbol:=FindAtScope(S,CurrentUnit,CurrentScope) End;

Function FindLexicalSymbol(S: TShortString): Word;
Var Scope,I: Word;
Begin
 Scope:=CurrentScope;
 Repeat
  I:=FindAtScope(S,CurrentUnit,Scope);
  If I<>0 Then Begin FindLexicalSymbol:=I; Exit End;
  If Scope=0 Then Break;
  Scope:=Scopes[Scope].Parent;
 Until False;
 FindLexicalSymbol:=0;
End;

Function FindSymbol(S: TShortString): Word;
Var
 I: Word;
 J: Integer; Scope: Word;
Begin
 Scope:=CurrentScope;
 Repeat
  I:=FindAtScope(S,CurrentUnit,Scope);
  If I<>0 Then Begin FindSymbol:=I; Exit End;
  If Scope=0 Then Break;
  Scope:=Scopes[Scope].Parent;
 Until False;
 FindSymbol:=0;
 For J:=ImportCount Downto 1 Do
 Begin
 If ((S='FILEMODE') Or (S='INPUT') Or (S='OUTPUT') Or (S='RANDSEED') Or (S='MAXINT') Or (S='REAL') Or
     (S='PI') Or (S='SEG0040') Or (S='SEGA000') Or (S='SEGB000') Or (S='SEGB800') Or
     (S='PREFIXSEG') Or (S='INOUTRES') Or (S='MAXLONGINT')) And (Units[ImportOrder[J]].Name='SYSTEM') Then Continue;
 I:=FindAtScope(S,ImportOrder[J],0);
 If (I<>0) And Symbols[I].Exported Then Begin
  FindSymbol:=I; Exit
 End;
 End;
 If CurrentUnit=253 Then Begin I:=FindAtScope(S,254,0); If I<>0 Then Begin FindSymbol:=I; Exit End End;
 FindSymbol:=FindAtScope(S,255,0);
End;

Procedure AddImport(U: Byte);
Var
 I, J: Byte;
Begin
  { Ne pas reconstruire une unite deja compilee; sa priorite de recherche
    depend de la clause uses courante et non de l'ordre de compilation. }
 For I:=1 To ImportCount Do If ImportOrder[I]=U Then Begin
  For J:=I To ImportCount-1 Do ImportOrder[J]:=ImportOrder[J+1];
  Dec(ImportCount); Break;
 End;
 Inc(ImportCount); ImportOrder[ImportCount]:=U;
 Imports:=Imports+[U];
 If (CurrentUnit<>0) And (Units[U].Name<>'SYSTEM')
 Then    Units[CurrentUnit].Dependencies:=Units[CurrentUnit].Dependencies+[U];
End;

Function FindBuildUnit(S: TShortString): Byte;
Var
 I: Byte;
Begin
 FindBuildUnit:=0;
 For I:=1 To UnitCount Do If Units[I].Name=S Then FindBuildUnit:=I;
End;
{ Le premier identificateur est deja consomme. Gere Unite.Symbole sans
  rendre accessibles les symboles prives ou les dependances transitives. }

Function ResolveSymbol(Name: TShortString): Word;
Var
 U: Byte;
 I: Word;
Begin
 If (Token=tkDot) And (FindBuildUnit(Name)=0) Then Begin
  I:=FindSymbol(Name);
  If I<>0 Then Begin ResolveSymbol:=I; Exit End;
 End;
 If Token<>tkDot Then Begin
  I:=FindSymbol(Name);
  If I=0 Then Fail(3,'Identificateur inconnu: '+Name);
  If Symbols[I].Kind=skForeign Then      Unsupported('symbole Borland '+
  Units[Symbols[I].Owner].Name+'.'+Name+
  ': signature hors du sous-ensemble ABI');
  ResolveSymbol:=I; Exit;
 End;
 U:=FindBuildUnit(Name);
 If (U=0) Or Not ((U In Imports) Or (U=CurrentUnit)) Then    Fail(3,'Unite inconnue: '+
 Name);
 NextToken;
 If Token<>tkIdent Then Fail(2,'Identificateur qualifie attendu');
 I:=0;
 For I:=1 To SymbolCount Do    If (Symbols[I].Owner=U) And (Symbols[I].Name=TokenText) And
 (Symbols[I].Scope=0) And (Symbols[I].Exported Or (U=CurrentUnit)) Then Begin
  If Symbols[I].Kind=skForeign Then        Unsupported('symbole Borland '+Name+'.'+
  TokenText+
  ': signature hors du sous-ensemble ABI');
  ResolveSymbol:=I; NextToken; Exit;
 End;
 Fail(3,'Identificateur inconnu: '+Name+'.'+TokenText);
End;

Function NewSymbol(S: TShortString): Word;
Var Bucket: Word;
Begin
 If FindOwnSymbol(S)<>0 Then Fail(4,'Identificateur duplique: '+S);
 If SymbolCount=MaxSymbols Then Fail(123,'Table des symboles pleine');
 Inc(SymbolCount); FillChar(Symbols[SymbolCount],SizeOf(TSymbol),0);
 Symbols[SymbolCount].Owner:=CurrentUnit;
 Symbols[SymbolCount].Scope:=CurrentScope;
 Symbols[SymbolCount].Exported:=InInterface And (CurrentScope=0);
 Bucket:=(HashIdent(S) And 126) Div 2;
 Symbols[SymbolCount].HashNext:=Dictionary[Bucket]; Dictionary[Bucket]:=SymbolCount;
 Symbols[SymbolCount].Name:=S; NewSymbol:=SymbolCount;
 Symbols[SymbolCount].DebugVisible:=(OptionBits And $200<>0) Or (MapMode>=2);
 Symbols[SymbolCount].DebugFile:=SourceName; Symbols[SymbolCount].DebugLine:=TokenLine; Symbols[SymbolCount].DebugColumn:=TokenColumn;
End;

Function NewType(Typ, Width, Capacity: Byte; Signed: Boolean;
                 LowBound, HighBound: Longint; Base: Word): Word;
Begin
 If TypeCount=MaxTypes Then Fail(123,'Table des types pleine');
 Inc(TypeCount); FillChar(Types[TypeCount],SizeOf(TTypeInfo),0);
 Types[TypeCount].Typ:=Typ; Types[TypeCount].Width:=Width;
 Types[TypeCount].Capacity:=Capacity; Types[TypeCount].Signed:=Signed;
 Types[TypeCount].LowBound:=LowBound; Types[TypeCount].HighBound:=HighBound;
 If Base=0 Then Base:=TypeCount;
 Types[TypeCount].Base:=Base; NewType:=TypeCount;
 FillChar(TypeExtras[TypeCount],SizeOf(TTypeExtra),0);
 TypeExtras[TypeCount].Size:=Width;
 If Typ=ttString Then TypeExtras[TypeCount].Size:=Word(Capacity)+1;
End;

Procedure InitTypes;
Begin
 TypeCount:=0; FieldCount:=0;
 FillChar(NativeTypeOwners,SizeOf(NativeTypeOwners),0);
 FillChar(NativeTypeOffsets,SizeOf(NativeTypeOffsets),0);
 TypeCount:=NewType(ttInteger,2,0,True,-32768,32767,0);
 TypeCount:=NewType(ttInteger,1,0,False,0,255,1);
 TypeCount:=NewType(ttInteger,2,0,False,0,65535,1);
 TypeCount:=NewType(ttInteger,1,0,True,-128,127,1);
 TypeCount:=NewType(ttBoolean,1,0,False,0,1,0);
 TypeCount:=NewType(ttChar,1,0,False,0,255,0);
 TypeCount:=NewType(ttString,0,255,False,0,255,0);
 TypeCount:=NewType(ttPointer,4,0,False,0,0,0);
 TypeCount:=NewType(ttInteger,4,0,True,-2147483647-1,2147483647,1);
 TypeCount:=NewType(ttText,0,0,False,0,0,0); TypeExtras[10].Size:=256;
 TypeCount:=NewType(ttReal,6,0,True,0,0,0);
 TypeCount:=NewType(ttPointer,4,0,False,0,0,0); TypeExtras[12].ElementType:=6; { PChar = ^Char }
 TypeCount:=NewType(ttBoolean,2,0,False,0,1,5); { WordBool }
 TypeCount:=NewType(ttBoolean,4,0,False,0,1,5); { LongBool }
End;

Function BuiltinType(S: TShortString): Word;
Begin
 BuiltinType:=0;
 If S='INTEGER' Then BuiltinType:=1 Else If S='BYTE' Then BuiltinType:=2
 Else If S='WORD' Then BuiltinType:=3 Else If S='SHORTINT' Then BuiltinType:=4
 Else If S='BOOLEAN' Then BuiltinType:=5 Else If S='CHAR' Then BuiltinType:=6
 Else If S='STRING' Then BuiltinType:=7;
 If S='POINTER' Then BuiltinType:=8;
 If S='LONGINT' Then BuiltinType:=9;
 If S='TEXT' Then BuiltinType:=10;
 If S='REAL' Then BuiltinType:=11;
 If S='PCHAR' Then BuiltinType:=12;
 If S='OPENSTRING' Then BuiltinType:=7; { $P: chaine ouverte = String[255] }
 If S='BYTEBOOL' Then BuiltinType:=5;
 If S='WORDBOOL' Then BuiltinType:=13;
 If S='LONGBOOL' Then BuiltinType:=14;
End;

Function PointerTo(T: Word): Word;
{ Type pointeur vers T, reutilise si un tel type existe deja. }
Var I: Word;
Begin
 For I:=1 To TypeCount Do
  If (Types[I].Typ=ttPointer) And (TypeExtras[I].ElementType=T) Then Begin PointerTo:=I; Exit End;
 I:=NewType(ttPointer,4,0,False,0,0,0); TypeExtras[I].ElementType:=T; PointerTo:=I;
End;

Procedure ApplyType(I, T: Word);
Begin
 Symbols[I].TypeId:=T; Symbols[I].Typ:=Types[T].Typ;
 Symbols[I].Width:=Types[T].Width; Symbols[I].Capacity:=Types[T].Capacity;
 Symbols[I].SignedByte:=Types[T].Signed And (Types[T].Width=1);
End;

Function StoreReal(V: Double): Word; Forward;

Procedure InstallStandardTypes;
Const Names: Array[1..14] Of String[8]=('INTEGER','BYTE','WORD','SHORTINT','BOOLEAN','CHAR','STRING','POINTER','LONGINT','TEXT','REAL','PCHAR','WORDBOOL','LONGBOOL');
Var T,I: Word;
Begin
 CurrentUnit:=255;
 For T:=1 To 14 Do Begin I:=NewSymbol(Names[T]); Symbols[I].Kind:=skType; ApplyType(I,T) End;
 CurrentUnit:=0; FileModeAddress:=AllocData(1); Data[FileModeAddress]:=2;
 CurrentUnit:=255; I:=NewSymbol('FILEMODE'); Symbols[I].Kind:=skVar; ApplyType(I,2); Symbols[I].Addr:=FileModeAddress;
 CurrentUnit:=0; StandardInputAddress:=AllocData(256); StandardOutputAddress:=AllocData(256);
 Data[StandardInputAddress+2]:=1; Data[StandardInputAddress+4]:=1;
 Data[StandardInputAddress+6]:=255; Data[StandardInputAddress+7]:=255;
 Data[StandardInputAddress+8]:=1; Data[StandardInputAddress+12]:=$46; Data[StandardInputAddress+13]:=$50;
 Move(Data[StandardInputAddress],Data[StandardOutputAddress],256);
 Data[StandardOutputAddress]:=1; Data[StandardOutputAddress+4]:=2;
 CurrentUnit:=255; I:=NewSymbol('INPUT'); Symbols[I].Kind:=skVar; ApplyType(I,10); Symbols[I].Addr:=StandardInputAddress;
 I:=NewSymbol('OUTPUT'); Symbols[I].Kind:=skVar; ApplyType(I,10); Symbols[I].Addr:=StandardOutputAddress;
 CurrentUnit:=0; RandomSeed:=AllocData(4);
 StringRing:=AllocData(2048); StringRingPos:=AllocData(2);
 CurrentUnit:=255; I:=NewSymbol('RANDSEED'); Symbols[I].Kind:=skVar; ApplyType(I,9); Symbols[I].Addr:=RandomSeed;
 I:=NewSymbol('MAXINT'); Symbols[I].Kind:=skConst; ApplyType(I,1); Symbols[I].Value:=32767;
 { TP 7.0: segments standard et constante Pi de l'unite System }
 I:=NewSymbol('SEG0040'); Symbols[I].Kind:=skConst; ApplyType(I,3); Symbols[I].Value:=$0040;
 I:=NewSymbol('SEGA000'); Symbols[I].Kind:=skConst; ApplyType(I,3); Symbols[I].Value:=$A000;
 I:=NewSymbol('SEGB000'); Symbols[I].Kind:=skConst; ApplyType(I,3); Symbols[I].Value:=$B000;
 I:=NewSymbol('SEGB800'); Symbols[I].Kind:=skConst; ApplyType(I,3); Symbols[I].Value:=$B800;
 CurrentUnit:=0; I:=StoreReal(Pi); CurrentUnit:=255;
 T:=NewSymbol('PI'); Symbols[T].Kind:=skConst; ApplyType(T,11); Symbols[T].Addr:=I;
 Symbols[T].StrValue[0]:=#6; Move(Data[I],Symbols[T].StrValue[1],6);
 CurrentUnit:=0; CrtHook:=AllocData(2); PrefixSeg:=AllocData(2);
 CurrentUnit:=255;
 I:=NewSymbol('PREFIXSEG'); Symbols[I].Kind:=skVar; ApplyType(I,3); Symbols[I].Addr:=PrefixSeg;
 I:=NewSymbol('INOUTRES'); Symbols[I].Kind:=skVar; ApplyType(I,1); Symbols[I].Addr:=InputError;
 I:=NewSymbol('MAXLONGINT'); Symbols[I].Kind:=skConst; ApplyType(I,9); Symbols[I].Value:=2147483647;
 CurrentUnit:=0;
End;

Function SymbolType(I: Word): Word;
Begin
 If Symbols[I].TypeId<>0 Then Begin SymbolType:=Symbols[I].TypeId; Exit End;
 Case Symbols[I].Typ Of
  ttBoolean:SymbolType:=5; ttChar:SymbolType:=6; ttString:SymbolType:=7;
  ttInteger:Begin
   If Symbols[I].Width=1 Then Begin
    If Symbols[I].SignedByte Then SymbolType:=4 Else SymbolType:=2;
   End Else SymbolType:=1;
  End;
 Else SymbolType:=0;
 End;
End;

Procedure DebugLineEntry;
Begin
 If OptionBits And $100=0 Then Exit;
 { D+ est actif par defaut: au-dela de la table, les lignes ne sont plus
   notees plutot que d'interrompre la compilation. }
 If DebugCount=MaxDebugEntries Then Exit;
 Inc(DebugCount); FillChar(DebugEntries[DebugCount],SizeOf(TDebugEntry),0);
 With DebugEntries[DebugCount] Do Begin
  U:=CurrentUnit; Address:=CodeSize; Line:=TokenLine; Column:=TokenColumn; FileName:=SourceName;
 End;
End;

Procedure CaptureDebugSymbols(Owner: Byte);
Var I,T: Word; Prefix: TShortString;
Begin
 If Owner In DebugCaptured Then Exit;
 DebugCaptured:=DebugCaptured+[Owner]; Prefix:=''; If Owner<>0 Then Prefix:=Units[Owner].Name+'.';
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=Owner) And Symbols[I].DebugVisible And
    (Symbols[I].Kind In [skVar,skProc]) And Not Symbols[I].Native Then Begin
  If DebugCount=MaxDebugEntries Then Fail(110,'Trop d''entrees de debug');
  Inc(DebugCount); FillChar(DebugEntries[DebugCount],SizeOf(TDebugEntry),0);
  With DebugEntries[DebugCount] Do Begin
   U:=Owner; Address:=Symbols[I].Addr;
   FileName:=Symbols[I].DebugFile; Line:=Symbols[I].DebugLine; Column:=Symbols[I].DebugColumn;
   Name:=Prefix+Symbols[I].Name;
   If Symbols[I].Kind=skProc Then Kind:=1 Else If Symbols[I].Local Then Begin
    Kind:=3; Name:=Prefix+Symbols[Scopes[Symbols[I].Scope].ProcSymbol].Name+'.'+Symbols[I].Name;
   End Else Kind:=2;
   T:=SymbolType(I); Size:=TypeExtras[T].Size; If Symbols[I].ByReference Then Size:=4;
  End;
 End;
End;

Function IsCharPointer(T: Word): Boolean;
{ PChar ou tout type ^Char: Turbo Pascal 7.0 les traite de la meme facon. }
Begin
 IsCharPointer:=(T<>0) And (Types[T].Typ=ttPointer) And (TypeExtras[T].ElementType=6);
End;

Function IsCharArray(T: Word): Boolean;
{ Tableau de Char a base zero, compatible PChar avec $X+. }
Begin
 IsCharArray:=(T<>0) And (Types[T].Typ=ttArray) And (TypeExtras[T].ElementType=6) And
  (Types[TypeExtras[T].IndexType].Typ=ttInteger) And (Types[TypeExtras[T].IndexType].LowBound=0);
End;
Function IsAnyCharArray(T: Word): Boolean;
{ Tableau (packed) de Char quelconque: compatible chaine dans les expressions. }
Begin
 IsAnyCharArray:=(T<>0) And (Types[T].Typ=ttArray) And (TypeExtras[T].ElementType=6);
End;

Function CompatibleTypes(A, B: Word): Boolean;
Begin
 CompatibleTypes:=(A=0) Or (B=0);
 If IsCharPointer(A) And IsCharPointer(B) Then Begin CompatibleTypes:=True; Exit End;
 If (A<>0) And (B<>0) And (Types[A].Typ=ttReal) And (Types[B].Typ=ttReal) Then Begin CompatibleTypes:=True; Exit End;
 If (A<>0) And (B<>0) Then
  CompatibleTypes:=(Types[A].Typ=Types[B].Typ) And (Types[A].Base=Types[B].Base);
 If (A<>0) And (B<>0) And (Types[A].Typ=ttPointer) And (Types[B].Typ=ttPointer) Then
  CompatibleTypes:=(TypeExtras[A].ElementType=0) Or (TypeExtras[B].ElementType=0) Or (Types[A].Base=Types[B].Base);
 If (A<>0) And (B<>0) And (Types[A].Typ=ttSet) And (Types[B].Typ=ttSet) Then
  CompatibleTypes:=(TypeExtras[A].ElementType=0) Or (TypeExtras[B].ElementType=0) Or
   CompatibleTypes(TypeExtras[A].ElementType,TypeExtras[B].ElementType);
 If (A<>0) And (B<>0) And (Types[A].Typ=ttText) And (Types[B].Typ=ttText) Then CompatibleTypes:=True;
 If (A<>0) And (B<>0) And (Types[A].Typ=ttFile) And (Types[B].Typ=ttFile) Then
  CompatibleTypes:=(TypeExtras[A].ElementType=0) Or (TypeExtras[B].ElementType=0) Or
   CompatibleTypes(TypeExtras[A].ElementType,TypeExtras[B].ElementType);
End;

Function RealScope(S: Word): Word;
{ Portee possedant une frame (saute les pseudo-portees des WITH). }
Begin
 While (S<>0) And Scopes[S].Pseudo Do S:=Scopes[S].Parent;
 RealScope:=S;
End;

Function TempAlloc(Size: Word): Word;
{ Reserve un temporaire de Size octets pour l'instruction courante. TempLocal
  indique s'il est dans la frame ([bp+adresse]) ou statique (DS:adresse). }
Var R,K,W: Word; P: ^TTempPool;
Begin
 R:=RealScope(CurrentScope);
 If R<>0 Then P:=@Scopes[R].Temps Else Begin
  If StaticTempsUnit<>CurrentUnit Then Begin
   FillChar(StaticTemps,SizeOf(StaticTemps),0); StaticTempsUnit:=CurrentUnit;
  End;
  P:=@StaticTemps;
 End;
 TempLocal:=R<>0;
 K:=P^.Used+1;
 While (K<=P^.Count) And (P^.Size[K]<>Size) Do Inc(K);
 If K>P^.Count Then Begin
  If P^.Count=MaxTemps Then Fail(49,'Expression trop complexe (temporaires)');
  Inc(P^.Count); K:=P^.Count; P^.Size[K]:=Size;
  If R<>0 Then Begin
   If Longint(Scopes[R].LocalSize)+Size>65520 Then Fail(49,'Variables locales trop grandes');
   Inc(Scopes[R].LocalSize,Size); P^.Addr[K]:=Word(-Longint(Scopes[R].LocalSize));
  End Else P^.Addr[K]:=AllocData(Size);
 End;
 Inc(P^.Used);
 If K<>P^.Used Then Begin
  W:=P^.Addr[K]; P^.Addr[K]:=P^.Addr[P^.Used]; P^.Addr[P^.Used]:=W;
  W:=P^.Size[K]; P^.Size[K]:=P^.Size[P^.Used]; P^.Size[P^.Used]:=W;
 End;
 TempAlloc:=P^.Addr[P^.Used];
End;

Procedure TempRelease;
{ Fin d'instruction: tous les temporaires redeviennent disponibles. }
Var R: Word;
Begin
 R:=RealScope(CurrentScope);
 If R<>0 Then Scopes[R].Temps.Used:=0 Else StaticTemps.Used:=0;
End;

Procedure TempPointerAX(A: Word; Local: Boolean);  { DX:AX := adresse du temporaire }
Begin
 If Local Then Begin Emit2($8D,$86); EmitWord(A); Emit2($8C,$D2) End
 Else Begin Emit($B8); DataAddress(A); Emit2($8C,$DA) End;
End;

Procedure TempPointerDI(A: Word; Local: Boolean);  { ES:DI := adresse du temporaire }
Begin
 If Local Then Begin Emit2($8D,$BE); EmitWord(A); Emit($16); Emit($07) End
 Else Begin Emit($BF); DataAddress(A); CallTo(RuntimeStandard[71]) End;
End;

Procedure TempClear(A: Word; Local: Boolean);      { octet de longueur := 0 }
Begin
 If Local Then Begin Emit2($C6,$86); EmitWord(A); Emit(0) End
 Else Begin Emit2($C6,$06); DataAddress(A); Emit(0) End;
End;

Procedure ScopeAddress(Scope: Word);
Var S: Word;
Begin
 Emit2($89,$EB); { bx=bp }
 S:=CurrentScope;
 While S<>Scope Do Begin
  If S=0 Then Unsupported('lien statique vers une portee non accessible');
  If Scopes[S].Pseudo Then Begin S:=Scopes[S].Parent; Continue End;
  Emit($36); Emit2($8B,$9F); EmitWord(Scopes[S].LinkOffset);
  S:=Scopes[S].Parent;
 End;
End;

Procedure AddSegmentRelocation(P: Word; Kind: Byte);Begin
 If RelocationCount=MaxNativeRefs Then Unsupported('trop de relocalisations MZ');
 Inc(RelocationCount); Relocations[RelocationCount].Offs:=P;
 Relocations[RelocationCount].Segm:=0; RelocationKinds[RelocationCount]:=Kind;
End;

Procedure EmitLocalCall(I: Word);
Begin
 If Symbols[I].Scope=0 Then Emit($55) { le lien statique d'une routine globale est inutilise }
 Else Begin ScopeAddress(Symbols[I].Scope); Emit($53) End;
 If Symbols[I].FarRoutine Then Emit($0E);
 CallTo(Symbols[I].Addr);
 If Symbols[I].LegacyCall Then Begin Emit2($83,$C4); Emit(2) End;
End;

Procedure ProcedureExit;
Var I,A: Word;
Begin
 I:=Scopes[CurrentScope].ProcSymbol;
 If (Symbols[I].ResultSymbol<>0) And Not Symbols[I].AssemblerBody Then Begin
  If Symbols[I].Typ=ttString Then Begin
   { Copier la variable resultat (frame locale) dans le prochain tampon de
     l'anneau; DX:AX = adresse du tampon. }
   Emit2($8B,$1E); DataAddress(StringRingPos);                 { mov bx,[pos] }
   Emit2($8D,$BF); DataAddress(StringRing);                    { lea di,[bx+anneau] }
   Emit2($81,$C3); EmitWord(256); Emit2($81,$E3); EmitWord(2047); { add bx,256; and bx,2047 }
   Emit2($89,$1E); DataAddress(StringRingPos);                 { mov [pos],bx }
   Emit($1E); Emit($07); Emit($57);                            { push ds; pop es; push di }
   Emit2($8D,$B6); EmitWord(Symbols[Symbols[I].ResultSymbol].Addr); { lea si,[bp+resultat] }
   Emit($1E); Emit($16); Emit($1F); Emit($B9); EmitWord(Word(Types[Symbols[I].TypeId].Capacity)+1);
   Emit2($F3,$A4); Emit($1F); Emit($58); Emit2($8C,$DA);       { rep movsb; pop ds; pop ax; mov dx,ds }
  End Else
  If Symbols[I].Typ=ttReal Then Begin
   A:=AllocData(6); Emit($1E); Emit($07); Emit($BF); DataAddress(A);
   Emit2($8D,$B6); EmitWord(Symbols[Symbols[I].ResultSymbol].Addr);
   Emit($1E); Emit($16); Emit($1F); Emit($B9); EmitWord(6); Emit2($F3,$A4); Emit($1F);
   Emit($B8); DataAddress(A); Emit2($8C,$DA);
  End Else Begin
  { AX/AL contient le resultat ordinal apres restauration de la frame. }
  Emit2($8B,$86); EmitWord(Symbols[Symbols[I].ResultSymbol].Addr);
  If Symbols[I].Width=4 Then Begin
   Emit2($8B,$96); EmitWord(Symbols[Symbols[I].ResultSymbol].Addr+2);
  End;
  If Symbols[I].Width=1 Then Begin
   If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
  End;
 End;
 End;
 If Symbols[I].AssemblerBody And (Symbols[I].Width=1) Then Begin
  If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
 End;
 Emit2($89,$EC); Emit($5D);
 If Symbols[I].FarRoutine Then Emit($CA) Else Emit($C2);
 EmitWord(Symbols[I].ParamBytes+2); { parametres + lien statique local }
End;

Procedure NativeReference(U, Kind: Byte; Map, Target: Word);Begin
 If NativeRefCount=MaxNativeRefs Then Unsupported('trop de references Borland');
 Inc(NativeRefCount); NativeRefs[NativeRefCount].Position:=CodeSize;
 NativeRefs[NativeRefCount].U:=U; NativeRefs[NativeRefCount].Kind:=Kind;
 NativeRefs[NativeRefCount].Map:=Map; NativeRefs[NativeRefCount].Target:=Target;
 EmitWord(0);
End;

Procedure NeedNative(U: Byte);Begin
 If CurrentUnit<>0 Then
  Units[CurrentUnit].NativeDependencies:=Units[CurrentUnit].NativeDependencies+[U];
 NativeNeeded:=True; ActivateNative(U);
End;

Procedure SetNativeDS;Begin
 Emit($BA); AddSegmentRelocation(CodeSize,1); EmitWord(0);
 Emit2($8E,$DA); { mov ds,dx; preserve AX }
End;

Procedure NativeVarAddress(I: Word);
Var
 K: Byte;
Begin
 K:=1; If Symbols[I].NativeConst Then K:=2;
 NativeReference(Symbols[I].Owner,K,Symbols[I].NativeMap,Symbols[I].Addr);
End;

Procedure ReferencePointer(I: Word);
Begin
 If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope);
  Emit($36); Emit2($C4,$BF); EmitWord(Symbols[I].Addr); { les di,ss:[bx+offset] }
 End Else Begin Emit2($C4,$3E); DataAddress(Symbols[I].Addr) End; { les di,[statique] }
 If Symbols[I].WithOffset<>0 Then Begin Emit2($81,$C7); EmitWord(Symbols[I].WithOffset) End;
End;

Function Designator(I: Word): Word; Forward;

Procedure PushVariableAddress(I: Word);
Var T: Word;
Begin
 T:=Designator(I); ExprType:=T; Emit($06); Emit($57);
End;

Procedure RangeBounds(LowBound,HighBound: Longint; SourceType: Word);
Var P,Q,Done: Word; Bad: Array[1..4] Of Word; K: Byte;
Begin
 If Types[SourceType].Width<>4 Then Begin
  If Types[SourceType].Signed Then Emit($99) Else Emit2($31,$D2);
 End;
 Emit2($81,$FA); EmitWord(Word(LowBound Shr 16)); Emit2($7D,3); Bad[1]:=Jump;
 Emit2($7E,3); P:=Jump;
 Emit($3D); EmitWord(Word(LowBound)); Emit2($73,3); Bad[2]:=Jump;
 PatchJump(P,CodeSize);
 Emit2($81,$FA); EmitWord(Word(HighBound Shr 16)); Emit2($7E,3); Bad[3]:=Jump;
 Emit2($7D,3); Q:=Jump;
 Emit($3D); EmitWord(Word(HighBound)); Emit2($76,3); Bad[4]:=Jump;
 PatchJump(Q,CodeSize); Done:=Jump;
 For K:=1 To 4 Do PatchJump(Bad[K],CodeSize);
 LoadImmediate(201); CallTo(RuntimeError); PatchJump(Done,CodeSize);
End;

Function SimpleScalar(I: Word): Boolean;
{ Variable scalaire accessible par un seul MOV (globale ou dans une frame). }
Var T: Word;
Begin
 SimpleScalar:=False;
 If (Symbols[I].Kind<>skVar) Or Symbols[I].ByReference Or Symbols[I].Native Or
    Symbols[I].IsAbsolute Or (Symbols[I].WithOffset<>0) Then Exit;
 T:=SymbolType(I); If T=0 Then Exit;
 If Not (Types[T].Typ In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer]) Then Exit;
 If Not (Types[T].Width In [1,2,4]) Then Exit;
 SimpleScalar:=True;
End;

Procedure EmitBP(Reg: Byte; D: Integer);
{ ModRM [BP+disp] (8 ou 16 bits) pour le registre Reg. }
Begin
 If (D>=-128) And (D<=127) Then Begin Emit($46 Or (Reg Shl 3)); Emit(Byte(D)) End
 Else Begin Emit($86 Or (Reg Shl 3)); EmitWord(Word(D)) End;
End;

Procedure LoadScalar(I: Word);
{ AX (DX:AX) := variable scalaire simple. }
Var T: Word; W: Byte;
Begin
 T:=SymbolType(I); W:=Types[T].Width;
 If Symbols[I].Local Then Begin
  If RealScope(Symbols[I].Scope)=RealScope(CurrentScope) Then Begin
   If W=1 Then Emit($8A) Else Emit($8B); EmitBP(0,SmallInt(Symbols[I].Addr));
   If W=4 Then Begin Emit($8B); EmitBP(2,SmallInt(Symbols[I].Addr)+2) End;
  End Else Begin
   ScopeAddress(Symbols[I].Scope); Emit($36);
   If W=1 Then Emit2($8A,$87) Else Emit2($8B,$87); EmitWord(Symbols[I].Addr);
   If W=4 Then Begin Emit($36); Emit2($8B,$97); EmitWord(Symbols[I].Addr+2) End;
  End;
 End Else Begin
  If W=1 Then Emit($A0) Else Emit($A1); DataAddress(Symbols[I].Addr);
  If W=4 Then Begin Emit2($8B,$16); DataAddress(Symbols[I].Addr+2) End;
 End;
 If W=1 Then Begin If Types[T].Signed Then Emit($98) Else Emit2($30,$E4) End;
End;

Procedure StoreScalar(I: Word);
{ variable scalaire simple := AX (DX:AX). }
Var T: Word; W: Byte;
Begin
 T:=SymbolType(I); W:=Types[T].Width;
 If Symbols[I].Local Then Begin
  If RealScope(Symbols[I].Scope)=RealScope(CurrentScope) Then Begin
   If W=1 Then Emit($88) Else Emit($89); EmitBP(0,SmallInt(Symbols[I].Addr));
   If W=4 Then Begin Emit($89); EmitBP(2,SmallInt(Symbols[I].Addr)+2) End;
  End Else Begin
   ScopeAddress(Symbols[I].Scope); Emit($36);
   If W=1 Then Emit2($88,$87) Else Emit2($89,$87); EmitWord(Symbols[I].Addr);
   If W=4 Then Begin Emit($36); Emit2($89,$97); EmitWord(Symbols[I].Addr+2) End;
  End;
 End Else Begin
  If W=1 Then Emit($A2) Else Emit($A3); DataAddress(Symbols[I].Addr);
  If W=4 Then Begin Emit2($89,$16); DataAddress(Symbols[I].Addr+2) End;
 End;
End;

Procedure BaseVariableAddress(I: Word);
Begin
 If Symbols[I].Kind<>skVar Then Fail(43,'Variable attendue');
 If Symbols[I].IsAbsolute Then Begin
  Emit($B8); EmitWord(Symbols[I].AbsoluteSeg); Emit2($8E,$C0); Emit($BF); EmitWord(Symbols[I].Addr);
 End Else If Symbols[I].ByReference Then Begin
  ReferencePointer(I);
 End Else If Symbols[I].Native Then Begin
  NeedNative(Symbols[I].Owner);
  Emit($BA); AddSegmentRelocation(CodeSize,1); EmitWord(0); Emit2($8E,$C2);
  Emit($BF); NativeVarAddress(I);
 End Else If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope); Emit2($81,$C3); EmitWord(Symbols[I].Addr);
  Emit2($89,$DF); Emit($16); Emit($07);
 End Else Begin
  Emit($1E); Emit($07); Emit($BF); DataAddress(Symbols[I].Addr);
 End;
End;

Procedure LoadSymbol(I: Word);Begin
 If Symbols[I].Kind=skType Then Fail(42,'Type utilise comme valeur');
 If Symbols[I].IsAbsolute Then Begin
  Emit($B8); EmitWord(Symbols[I].AbsoluteSeg); Emit2($8E,$C0); Emit($26);
  If Symbols[I].Width=1 Then Begin Emit($A0); EmitWord(Symbols[I].Addr); If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4) End
  Else Begin Emit($A1); EmitWord(Symbols[I].Addr) End;
 End Else If Symbols[I].ByReference Then Begin
  ReferencePointer(I); Emit($26);
  If Symbols[I].Width=1 Then Emit2($8A,$05) Else Emit2($8B,$05);
  If Symbols[I].Width=1 Then Begin
   If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
  End;
 End Else If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope); Emit($36);
  If Symbols[I].Width=1 Then Emit2($8A,$87) Else Emit2($8B,$87);
  EmitWord(Symbols[I].Addr);
  If Symbols[I].Width=1 Then Begin
   If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
  End;
 End Else If Symbols[I].Native And (Symbols[I].Kind=skVar) Then Begin
  NeedNative(Symbols[I].Owner); Emit($1E); SetNativeDS;
  If Symbols[I].Width=1 Then Emit($A0) Else Emit($A1);
  NativeVarAddress(I); Emit($1F);
  If Symbols[I].Width=1 Then Begin
   If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
  End;
 End Else If Symbols[I].Kind=skConst Then Begin
  If Symbols[I].Typ In [ttString,ttReal] Then Begin
   Emit($B8); DataAddress(Symbols[I].Addr); If Symbols[I].Typ=ttReal Then Emit2($8C,$DA)
  End
  Else Begin
   LoadImmediate(Word(Symbols[I].Value));
   If Symbols[I].Width=4 Then Begin Emit($BA); EmitWord(Word(Symbols[I].Value Shr 16)) End;
  End;
 End Else If Symbols[I].Typ=ttString Then Begin
  Emit($B8); DataAddress(Symbols[I].Addr);
 End Else If Symbols[I].Width=1 Then Begin
  Emit($A0); DataAddress(Symbols[I].Addr);
  If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
 End Else
 Begin
  Emit($A1); DataAddress(Symbols[I].Addr)
 End;
End;

Procedure SaveSymbol(I: Word);Begin
 If Symbols[I].IsAbsolute Then Begin
  Emit($B8); EmitWord(Symbols[I].AbsoluteSeg); Emit2($8E,$C0); Emit($26);
  If Symbols[I].Width=1 Then Emit($A2) Else Emit($A3); EmitWord(Symbols[I].Addr); Exit;
 End;
 If Symbols[I].ByReference Then Begin
  ReferencePointer(I); Emit($26);
  If Symbols[I].Width=1 Then Emit2($88,$05) Else Emit2($89,$05);
  Exit;
 End;
 If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope); Emit($36);
  If Symbols[I].Width=1 Then Emit2($88,$87) Else Emit2($89,$87);
  EmitWord(Symbols[I].Addr); Exit;
 End;
 If Symbols[I].Native Then Begin
  NeedNative(Symbols[I].Owner); Emit($1E); SetNativeDS;
  If Symbols[I].Width=1 Then Emit($A2) Else Emit($A3);
  NativeVarAddress(I); Emit($1F); Exit;
 End;
 If Symbols[I].Width=1 Then Emit($A2) Else Emit($A3);
 DataAddress(Symbols[I].Addr);
End;
Procedure EnsureRealRuntime; Forward;
Function RealSymbol(Name: TShortString): Word; Forward;
Procedure StackRoom(Needed: Word); Forward;
Procedure OverflowCheck(Unsigned: Boolean); Forward;
Procedure RealCall(Name: TShortString);
Begin StackRoom(4096); EmitLocalCall(RealSymbol(Name)) End;
Procedure RealPointer(A: Word);
Begin Emit($B8); DataAddress(A); Emit2($8C,$DA) End;
Function StoreReal(V: Double): Word;
Var A,E,I: Word; N: Longint; Negative: Boolean;
Begin
 If (Abs(V)>1.701411834603E38) Then Fail(76,'Constante Real hors limites');
 A:=AllocData(6); Negative:=V<0; V:=Abs(V); E:=129;
 If V<>0 Then Begin
  While V>=2 Do Begin V:=V/2; Inc(E) End;
  While (V<1) And (E>0) Do Begin V:=V*2; Dec(E) End;
  If E<>0 Then Begin
   Data[A]:=E; V:=(V-1)*128; Data[A+5]:=Trunc(V); V:=V-Trunc(V);
   For I:=4 Downto 1 Do Begin V:=V*256; Data[A+I]:=Trunc(V); V:=V-Trunc(V) End;
   If (V>0.5) Or ((V=0.5) And (Data[A+1] And 1<>0)) Then Begin
    I:=1; N:=1; While (I<=5) And (N<>0) Do Begin N:=Data[A+I]+N; Data[A+I]:=N And 255; N:=N Shr 8; Inc(I) End;
    If Data[A+5] And 128<>0 Then Begin
     If Data[A]=255 Then Fail(76,'Constante Real hors limites'); Data[A+5]:=0; Inc(Data[A]);
    End;
   End;
   If Negative Then Data[A+5]:=Data[A+5] Or 128;
  End;
 End; StoreReal:=A;
End;
Procedure ToReal(T: Word);
Var A: Word;
Begin
 If Types[T].Typ=ttReal Then Exit;
 If Types[T].Typ<>ttInteger Then Fail(26,'Expression numerique attendue');
 EnsureRealRuntime; A:=AllocData(6);
 If Types[T].Width<>4 Then Begin If Types[T].Signed Then Emit($99) Else Emit2($31,$D2) End;
 Emit($06); Emit($57); Emit($52); Emit($50); Emit($1E); Emit($BB); DataAddress(A); Emit($53); RealCall('RINT'); Emit($5F); Emit($07); RealPointer(A);
End;
Procedure PushReal;
Begin
 Emit2($8C,$C1); Emit2($8E,$C2); Emit2($89,$C3);
 Emit($26); Emit2($FF,$77); Emit(4); Emit($26); Emit2($FF,$77); Emit(2); Emit($26); Emit2($FF,$37); Emit2($8E,$C1);
End;
Procedure RealUnary(Op: Word);
Var A: Word;
Begin
 EnsureRealRuntime; A:=AllocData(6); Emit2($89,$C3); Emit2($89,$D1);
 Emit($06); LoadImmediate(Op); Emit($50); Emit($51); Emit($53); Emit($51); Emit($53);
 Emit($1E); Emit($B8); DataAddress(A); Emit($50); RealCall('RCALC'); Emit($07); RealPointer(A);
 ExprType:=11; ExprKnown:=False; ExprUnsigned:=False;
End;
Procedure RealBinary(L,R,Op: Word; Compare: Boolean);
Var A: Word;
Begin
 If Not (Types[L].Typ In [ttReal,ttInteger]) Then Fail(26,'Expression numerique attendue');
 EnsureRealRuntime; ToReal(R);
 If Types[L].Typ=ttReal Then Begin Emit2($89,$E3); Emit2($8C,$D1) End
 Else Begin
  Emit2($89,$C6); Emit2($89,$D7); Emit($58);
  If Types[L].Width=4 Then Emit($5A) Else If Types[L].Signed Then Emit($99) Else Emit2($31,$D2);
  Emit($57); Emit($56); ToReal(9); Emit($5E); Emit($5F);
  Emit2($89,$C3); Emit2($89,$D1); Emit2($89,$F0); Emit2($89,$FA);
 End;
 Emit($06);
 If Compare Then Begin Emit($51); Emit($53); Emit($52); Emit($50); RealCall('RCMP') End
 Else Begin
  A:=AllocData(6); Emit2($89,$C6); LoadImmediate(Op); Emit($50);
  Emit($51); Emit($53); Emit($52); Emit($56); Emit($1E); Emit($B8); DataAddress(A); Emit($50);
  RealCall('RCALC'); RealPointer(A);
 End;
 Emit($07);
 If Types[L].Typ=ttReal Then Begin Emit2($83,$C4); Emit(6) End;
 ExprType:=11; ExprKnown:=False; ExprUnsigned:=False;
End;
Procedure RealParseText;
Var A,C: Word;
Begin
 EnsureRealRuntime; A:=AllocData(6); C:=AllocData(2);
 Emit($06); Emit($52); Emit($50); Emit($1E); Emit($B8); DataAddress(A); Emit($50);
 Emit($1E); Emit($B8); DataAddress(C); Emit($50); RealCall('RPARSE'); Emit($07);
 Emit2($8B,$0E); DataAddress(C); RealPointer(A);
End;
Procedure RealText; Forward;
Function Expression: Byte;Forward;
Procedure Statement;Forward;
Procedure StatementList(Stop: Byte);Forward;
Function ConstExpression: TConstValue; Forward;
Function ConstFactor: TConstValue; Forward;
Procedure ConstInteger(V: TConstValue); Forward;
Function InlineBytes(Direct: Boolean): TShortString; Forward;
Procedure AllocateVariable(I: Word); Forward;
Procedure CheckLabels(Scope: Word); Forward;
Function NativeCall(I: Word): Byte;Forward;
Function UserCall(I: Word): Byte;Forward;
Function ReadType: Word; Forward;
 Procedure RequireOrdinal(T: Byte); Forward;
 Function StandardFunction(Name: TShortString): Word; Forward;
 Function StandardProcedure(Name: TShortString): Boolean; Forward;
Procedure NormalizeSet(T,A: Word); Forward;
Procedure TrimSet(T,A: Word); Forward;
 Function SizeArgument: Word; Forward;
 Function IsMemPort(Name: TShortString): Boolean; Forward;
 Function MemPortLoad(Name: TShortString): Word; Forward;
 Procedure MemPortIndex(Name: TShortString); Forward;
 Procedure StringFromChar; Forward;
 Procedure CharArrayToString(T: Word); Forward;
 Function VariableArgument: Word; Forward;
 Procedure LiteralToPChar; Forward;
 Procedure WriteZString; Forward;
 Procedure RequireInteger(T: Byte); Forward;
 Function SetConstructor: Word; Forward;
 Function SetBinary(LeftType,RightType: Word; Op: Byte): Word; Forward;
 Function StringBinary(LeftIsTemp: Boolean): Word; Forward;
 Procedure SetComparison(LeftType,RightType: Word; Op: Byte); Forward;

Function DesignatorTail(T: Word): Word;
{ Suite d'un designateur (^ . [ ]) a partir de ES:DI et du type T. }
Var F,IndexType,Element: Word; Name: TShortString;
Begin
 While Token In [tkLB,tkDot,tkCaret] Do Begin
  If Token=tkCaret Then Begin
   If Types[T].Typ<>ttPointer Then Fail(26,'Pointeur attendu');
   Emit($26); Emit2($C4,$3D); T:=TypeExtras[T].ElementType; NextToken;
  End Else If (Token=tkLB) And IsCharPointer(T) And ExtendedSyntax Then Begin
   { $X+: P[i] designe le caractere a l'offset P+i, sans controle de bornes. }
   NextToken; Emit($26); Emit2($C4,$3D);
   Emit($06); Emit($57); RequireInteger(Expression); Emit($5F); Emit($07);
   Emit2($01,$C7); T:=6; Need(tkRB);
  End Else If Token=tkDot Then Begin
   If Types[T].Typ<>ttRecord Then Fail(26,'Record attendu');
   NextToken; If Token<>tkIdent Then Fail(2,'Champ attendu'); Name:=TokenText;
   F:=TypeExtras[T].FirstField;
   While (F<>0) And (Fields[F].Name<>Name) Do F:=Fields[F].Next;
   If F=0 Then Fail(3,'Champ inconnu: '+Name);
   If Fields[F].Offset<>0 Then Begin Emit2($81,$C7); EmitWord(Fields[F].Offset) End;
   T:=Fields[F].TypeId; NextToken;
  End Else Begin
   NextToken;
   Repeat
    If Types[T].Typ=ttString Then Begin IndexType:=3; Element:=6 End
    Else If Types[T].Typ=ttArray Then Begin
     IndexType:=TypeExtras[T].IndexType; Element:=TypeExtras[T].ElementType;
    End Else Fail(26,'Tableau ou chaine attendu');
    Emit($06); Emit($57); RequireOrdinal(Expression);
    If Not CompatibleTypes(IndexType,ExprType) Then Fail(26,'Type de l''index');
    If ExprKnown And (Types[T].Typ=ttArray) And
       ((ExprValue<Types[IndexType].LowBound) Or (ExprValue>Types[IndexType].HighBound)) Then
     Fail(76,'Index constant hors limites');
    Emit($5F); Emit($07);
    If OptionBits And 2<>0 Then Begin
     If Types[T].Typ=ttString Then RangeBounds(0,Types[T].Capacity,ExprType)
     Else RangeBounds(Types[IndexType].LowBound,Types[IndexType].HighBound,ExprType);
    End;
    If (Types[T].Typ=ttArray) And (Types[IndexType].LowBound<>0) Then Begin
     Emit($2D); EmitWord(Word(Types[IndexType].LowBound));
    End;
    If TypeExtras[Element].Size<>1 Then Begin
     Emit($BB); EmitWord(TypeExtras[Element].Size); Emit2($F7,$E3);
    End;
    Emit2($01,$C7); T:=Element;
    If Token<>tkComma Then Break; NextToken;
   Until False;
   Need(tkRB);
  End;
 End;
 DesignatorTail:=T;
End;

Function Designator(I: Word): Word;
Begin
 BaseVariableAddress(I); Designator:=DesignatorTail(SymbolType(I));
End;

Procedure LoadDesignator(T: Word);
Begin
 If T=0 Then Fail(42,'Variable sans type utilisee comme valeur');
 If Types[T].Typ In [ttString,ttArray,ttRecord,ttSet,ttFile,ttText,ttReal] Then Begin
  Emit2($89,$F8); Emit2($8C,$C2);
 End Else Begin
  Emit($26);
  If Types[T].Width=1 Then Emit2($8A,$05) Else Emit2($8B,$05);
  If Types[T].Width=1 Then Begin
   If Types[T].Signed Then Emit($98) Else Emit2($30,$E4);
  End Else If Types[T].Width=4 Then Begin Emit($26); Emit2($8B,$55); Emit(2) End;
 End;
End;

Procedure StoreDesignator(T: Word);
Begin
 Emit($26);
 If Types[T].Width=1 Then Emit2($88,$05) Else Emit2($89,$05);
 If Types[T].Width=4 Then Begin Emit($26); Emit2($89,$55); Emit(2) End;
End;

Procedure RequireInteger(T: Byte);Begin
 If T<>ttInteger Then Fail(38,'Expression entiere attendue');
End;

Procedure RequireBoolean(T: Byte);Begin
 If T<>ttBoolean Then Fail(40,'Expression booleenne attendue');
End;
Procedure RequireOrdinal(T: Byte);Begin
 If Not (T In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(27,'Expression ordinale attendue');
End;

Function Factor: Byte;
Var
 T: Byte;
 I,CastType: Word;
 Name: TShortString;
 Bound: Longint;
 Lit: Boolean;
Begin
 T:=ttInteger; ExprType:=1; ExprKnown:=False; ExprLiteral:=False; Lit:=False;
 If Token=tkLB Then Begin
  ExprType:=SetConstructor; T:=ttSet;
 End Else If Token=tkNil Then Begin
  NextToken; Emit2($31,$C0); Emit2($31,$D2); T:=ttPointer; ExprType:=8;
 End Else If Token=tkAt Then Begin
  NextToken; If Token<>tkIdent Then Fail(83,'Variable attendue apres @');
  Name:=TokenText; NextToken; I:=ResolveSymbol(Name); CastType:=Designator(I);
  Emit2($89,$F8); Emit2($8C,$C2); T:=ttPointer; ExprType:=8;
  { $T+: @ produit un pointeur sur le type de la variable au lieu de Pointer. }
  If (OptionBits And $10000<>0) And (CastType<>0) Then ExprType:=PointerTo(CastType);
 End Else If Token=tkConstant Then Begin
  ExprKnown:=True; ExprValue:=TokenValue;
  If TokenIsReal Then Begin EnsureRealRuntime; RealPointer(StoreReal(TokenReal)); T:=ttReal; ExprType:=11; ExprKnown:=False End
  Else If TokenIsString Then Begin
   LiteralMarkCode:=CodeSize; LiteralMarkFixup:=FixupCount; LiteralMarkRelative:=RelativeCount;
   LiteralMarkNative:=NativeRefCount; LiteralMarkReloc:=RelocationCount; LiteralMarkData:=DataSize;
   ExprLiteral:=True; Lit:=True; ExprLiteralText:=TokenText;
   If Length(TokenText)=1 Then Begin
    T:=ttChar; ExprType:=6; ExprValue:=Ord(TokenText[1]); LoadImmediate(Ord(TokenText[1]))
   End
    Else
   Begin
    T:=ttString; ExprType:=7; Emit($B8); DataAddress(StoreString(TokenText)); Emit2($8C,$DA)
   End;
  End Else
  Begin
  If TokenValue>32767 Then ExprType:=3;
   LoadImmediate(Word(TokenValue));
   If (TokenValue>65535) Or (TokenValue<-32768) Then Begin ExprType:=9; Emit($BA); EmitWord(Word(TokenValue Shr 16)) End;
  End;
  NextToken;
 End Else If Token=tkLP Then Begin
  NextToken; T:=Expression; Need(tkRP);
  If (Token=tkCaret) And (T=ttPointer) Then Begin
   { (expression pointeur)^ : dereferencement direct, ES:DI = valeur du pointeur }
   Emit2($8E,$C2); Emit2($89,$C7); NextToken; ExprType:=TypeExtras[ExprType].ElementType;
   If (ExprType=0) And (CastTarget<>0) Then ExprType:=CastTarget;
   If ExprType<>0 Then ExprType:=DesignatorTail(ExprType);
   If (ExprType=0) And (CastTarget<>0) Then ExprType:=CastTarget;
   LoadDesignator(ExprType); T:=Types[ExprType].Typ; ExprKnown:=False;
  End;
 End
 Else If Token=tkNot Then Begin
  NextToken; T:=Factor;
  ExprKnown:=False; ExprLiteral:=False;
  If T=ttBoolean Then Begin
   Emit2($35,$01); Emit(0)
  End
   Else
  Begin
   RequireInteger(T); Emit2($F7,$D0)
   ; If Types[ExprType].Width=4 Then Emit2($F7,$D2)
  End;
 End Else If Token=tkIdent Then Begin
  Name:=TokenText; NextToken;
  I:=FindLexicalSymbol(Name);
  If (I=0) And (Token=tkLB) And IsMemPort(Name) Then Begin
   ExprType:=MemPortLoad(Name); T:=Types[ExprType].Typ; ExprKnown:=False;
   ExprUnsigned:=Not Types[ExprType].Signed; ExprLiteral:=False; Factor:=T; Exit;
  End;
  CastType:=0;
  If (I=0) And (Token<>tkDot) Then CastType:=BuiltinType(Name);
  If (I<>0) And (Symbols[I].Kind=skType) Then CastType:=Symbols[I].TypeId;
  If (I=0) And (Token<>tkDot) Then Begin
   CastType:=StandardFunction(Name);
   If CastType<>0 Then Begin
    ExprType:=CastType; T:=Types[CastType].Typ; ExprKnown:=False;
    ExprUnsigned:=(T=ttInteger) And Not Types[CastType].Signed;
    ExprLiteral:=False; Factor:=T; Exit;
   End;
   CastType:=BuiltinType(Name);
  End;
  If (Token=tkLP) And (CastType<>0) Then Begin
   NextToken;
   If Types[CastType].Typ In [ttRecord,ttArray,ttString,ttSet] Then Begin
    { Transtypage de variable structuree: TRec(Pointer(P)^), TTab(Rec) }
    I:=CastTarget; CastTarget:=CastType; T:=Expression; CastTarget:=I; Need(tkRP);
    If T<>Types[CastType].Typ Then Fail(61,'Transtypage structure invalide');
    ExprType:=CastType; ExprKnown:=False; ExprLiteral:=False;
   End Else Begin
   T:=Expression; Need(tkRP);
   If Types[CastType].Typ=ttReal Then Begin ToReal(ExprType); T:=ttReal; ExprType:=11 End
   Else Begin
   If Not (T In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer]) Or
      Not (Types[CastType].Typ In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer]) Then
    Fail(61,'Conversion ordinale invalide');
   If (Types[CastType].Width=4) And (Types[ExprType].Width<>4) Then Begin
    If ExprUnsigned Then Emit2($31,$D2) Else Emit($99);
   End;
   T:=Types[CastType].Typ; ExprType:=CastType;
  ExprKnown:=False;
   If Types[CastType].Width=1 Then Begin
    If Types[CastType].Signed Then Emit($98) Else Emit2($30,$E4);
   End;
   If (Token In [tkCaret,tkLB,tkDot]) And (T=ttPointer) Then Begin
    { TypePointeur(expression)^ ... : ES:DI = valeur du pointeur }
    Emit2($8E,$C2); Emit2($89,$C7);
    If Token=tkCaret Then Begin NextToken; ExprType:=TypeExtras[ExprType].ElementType End;
    If (ExprType=0) And (CastTarget<>0) Then ExprType:=CastTarget;
    If ExprType<>0 Then ExprType:=DesignatorTail(ExprType);
    If (ExprType=0) And (CastTarget<>0) Then ExprType:=CastTarget;
    LoadDesignator(ExprType); T:=Types[ExprType].Typ;
   End;
   End;
   End;
  End Else If (I=0) And (Token<>tkDot) And ((Name='HIGH') Or (Name='LOW')) Then Begin
   { TP 7.0: bornes d'un type ou d'une variable ordinale, tableau ou chaine. }
   Need(tkLP);
   If Token=tkIdent Then Begin
    I:=FindLexicalSymbol(TokenText);
    If (I<>0) And (Symbols[I].Kind=skVar) And (Types[SymbolType(I)].Typ=ttArray) And
       (TypeExtras[SymbolType(I)].FieldCount=$FFFF) Then Begin
     { tableau ouvert: High est le mot qui suit le pointeur dans la frame }
     NextToken; Need(tkRP);
     If Name='HIGH' Then Begin ScopeAddress(Symbols[I].Scope); Emit($36); Emit2($8B,$87); EmitWord(Symbols[I].Addr+4) End
     Else LoadImmediate(0);
     T:=ttInteger; ExprType:=1; ExprKnown:=False; ExprLiteral:=False; I:=0; Factor:=T; Exit;
    End;
   End;
   CastType:=SizeArgument; Need(tkRP);
   If Types[CastType].Typ=ttArray Then CastType:=TypeExtras[CastType].IndexType;
   If Types[CastType].Typ=ttString Then Begin
    If Name='HIGH' Then Bound:=Types[CastType].Capacity Else Bound:=0; CastType:=1;
   End Else Begin
    If Not (Types[CastType].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(29,'');
    If Name='HIGH' Then Bound:=Types[CastType].HighBound Else Bound:=Types[CastType].LowBound;
   End;
   LoadImmediate(Word(Bound));
   If Types[CastType].Width=4 Then Begin Emit($BA); EmitWord(Word(Bound Shr 16)) End;
   T:=Types[CastType].Typ; ExprType:=CastType; ExprKnown:=True; ExprValue:=Bound;
  End Else If (I=0) And (Token<>tkDot) And (Name='ASSIGNED') Then Begin
   Need(tkLP); T:=Expression; Need(tkRP);
   If T<>ttPointer Then Fail(78,'');
   Emit2($09,$D0); LoadImmediate(1); Emit2($75,2); Emit2($31,$C0);
   T:=ttBoolean; ExprType:=5; ExprKnown:=False;
  End Else If (I=0) And (Token<>tkDot) And (Name='SIZEOF') Then Begin
   Need(tkLP); CastType:=SizeArgument; Need(tkRP);
   LoadImmediate(TypeExtras[CastType].Size);
   T:=ttInteger; ExprType:=1;
  End Else If (I=0) And (Token<>tkDot) And ((Name='TRUE') Or (Name='FALSE')) Then Begin
  T:=ttBoolean; ExprType:=5; ExprKnown:=True;
  If Name='TRUE' Then Begin ExprValue:=1; LoadImmediate(1) End
  Else Begin ExprValue:=0; LoadImmediate(0) End;
  End Else If (I=0) And (Token<>tkDot) And ((Name='LENGTH') Or (Name='ORD') Or (Name='CHR') Or
  (Name='ABS') Or (Name='SQR') Or (Name='SUCC') Or (Name='PRED')) Then Begin
   Need(tkLP); T:=Expression; Need(tkRP);
   If Name='LENGTH' Then Begin
    If T=ttString Then Begin
     Emit($1E); Emit2($8E,$DA);
     Emit2($89,$C3); Emit2($8A,$07); Emit2($30,$E4)
     ; Emit($1F)
    End
    Else If T=ttChar Then LoadImmediate(1)
    Else If (T=ttArray) And IsAnyCharArray(ExprType) Then Begin
     CharArrayToString(ExprType); Emit($1E); Emit2($8E,$DA); Emit2($89,$C3); Emit2($8A,$07); Emit2($30,$E4); Emit($1F);
    End Else Fail(67,'Chaine attendue');
    T:=ttInteger; ExprType:=1;
   End Else If Name='ORD' Then Begin
    If Not (T In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(26,'Type ordinal attendu');
    T:=ttInteger;
    If Types[ExprType].Width=4 Then ExprType:=9 Else If ExprUnsigned Then ExprType:=3 Else ExprType:=1;
   End Else If Name='CHR' Then Begin
    RequireInteger(T); Emit2($30,$E4); T:=ttChar; ExprType:=6
   End
    Else
   Begin
    If (T=ttReal) And ((Name='ABS') Or (Name='SQR')) Then Begin
     If Name='ABS' Then RealUnary(6) Else RealUnary(7);
    End Else Begin
    If Not ((Name='SUCC') Or (Name='PRED')) Then RequireInteger(T)
    Else If Not (T In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(26,'Type ordinal attendu');
    If Name='ABS' Then Begin
     If Types[ExprType].Width=4 Then Begin
      Emit2($09,$D2); Emit2($79,7); Emit2($F7,$D8); Emit2($83,$D2); Emit(0); Emit2($F7,$DA);
     End Else If Not ExprUnsigned Then Begin Emit2($09,$C0); Emit2($79,$02); Emit2($F7,$D8) End;
    End;
    If Name='SQR' Then Begin
     If Types[ExprType].Width=4 Then Begin Emit2($89,$C3); Emit2($89,$D1); CallTo(RuntimeStandard[14]) End
     Else Emit2($F7,$E8);
    End;
    If Name='SUCC' Then Begin Emit($05); EmitWord(1); If Types[ExprType].Width=4 Then Begin Emit2($83,$D2); Emit(0) End End;
    If Name='PRED' Then Begin Emit($2D); EmitWord(1); If Types[ExprType].Width=4 Then Begin Emit2($83,$DA); Emit(0) End End;
    End;
   End;
    ExprKnown:=False;
  End Else
  Begin
   I:=ResolveSymbol(Name);
  If Symbols[I].ResultVariable And (Token=tkLP) Then I:=Symbols[I].RoutineSymbol;
   If Symbols[I].Kind=skProc Then Begin
   If Symbols[I].Typ=ttVoid Then Fail(42,'Procedure utilisee comme fonction');
   If Symbols[I].Native Then T:=NativeCall(I) Else T:=UserCall(I);
    ExprKnown:=False;
    ExprType:=SymbolType(I);
    If T=ttVoid Then Fail(42,'Fonction attendue');
   End Else
   Begin
    If (Symbols[I].Kind=skVar) And SimpleScalar(I) And Not (Token In [tkLB,tkDot,tkCaret]) Then Begin
     ExprType:=SymbolType(I); T:=Types[ExprType].Typ; LoadScalar(I);
    End Else If Symbols[I].Kind=skVar Then Begin
     ExprType:=Designator(I); T:=Types[ExprType].Typ; LoadDesignator(ExprType);
    End Else Begin
     T:=Symbols[I].Typ; ExprType:=SymbolType(I); LoadSymbol(I);
     If T=ttString Then Emit2($8C,$DA);
    End;
    ExprKnown:=(Symbols[I].Kind=skConst) And (T<>ttReal); ExprValue:=Symbols[I].Value;
   End;
  End;
 End Else If Token=tkEOF Then Fail(10,'Fin de fichier inattendue')
                         Else Unsupported('expression: '+TokenText);
 ExprUnsigned:=(ExprType<>0) And Not Types[ExprType].Signed And (T=ttInteger);
 { Seule une constante chaine directe reste "nue": un appel de fonction ou un
   designateur dont les arguments contenaient un litteral ne l'est pas. }
 ExprLiteral:=Lit;
 Factor:=T;
End;

Function Term: Byte;
Var
 T, R, Op: Byte; RightKnown,MixedWide: Boolean; RightValue: Longint;
 Skip,ShiftLoop,CV: Word; ConstOp: Boolean;
 ShortCircuit,WideLeft,WideRight,WideResult: Boolean;
 LeftType: Word; LeftUnsigned: Boolean;
 LeftKnown: Boolean; LeftValue: Longint; Check: Real;
Begin
 T:=Factor;
 While Token In [tkTimes,tkSlash,tkDiv,tkMod,tkAnd,tkShl,tkShr] Do Begin
  Op:=Token;
  If T=ttSet Then Begin
   LeftType:=ExprType; If Op<>tkTimes Then Fail(26,'Operation set invalide');
   Emit($52); Emit($50); NextToken; R:=Factor; ExprLiteral:=False;
   If R<>ttSet Then Fail(26,'Ensemble attendu');
   ExprType:=SetBinary(LeftType,ExprType,Op); ExprKnown:=False; ExprUnsigned:=False; Continue;
  End;

  ShortCircuit:=(Op=tkAnd) And (T=ttBoolean) And (OptionBits And $40=0);
  LeftType:=ExprType; LeftUnsigned:=ExprUnsigned;
  LeftKnown:=ExprKnown; LeftValue:=ExprValue;
  If ShortCircuit Then Skip:=JumpZeroKeep;
  WideLeft:=(T=ttInteger) And (Types[LeftType].Width=4);
  If T=ttReal Then PushReal Else Begin If WideLeft Then Emit($52); Emit($50) End;
  NextToken; R:=Factor; ExprLiteral:=False;
  RightKnown:=ExprKnown; RightValue:=ExprValue;
  { Word op Integer (signes differents, ni constante positive): Longint comme TP }
  If (T=ttInteger) And (R=ttInteger) And (LeftUnsigned<>ExprUnsigned) And Not (Op In [tkShl,tkShr]) And
     Not (LeftUnsigned And RightKnown And (RightValue>=0) And (RightValue<=65535)) And
     Not (ExprUnsigned And LeftKnown And (LeftValue>=0) And (LeftValue<=65535)) Then Begin
   If Not ((Types[LeftType].Width=4) Or (Types[ExprType].Width=4)) Then MixedWide:=True;
  End Else MixedWide:=False;
  If (T=ttReal) Or (R=ttReal) Or (Op=tkSlash) Then Begin
   If Not (Op In [tkTimes,tkSlash]) Then Fail(26,'Operation reelle invalide');
   If Op=tkTimes Then RealBinary(LeftType,ExprType,3,False) Else RealBinary(LeftType,ExprType,4,False);
   T:=ttReal; Continue;
  End;
  WideRight:=(R=ttInteger) And (Types[ExprType].Width=4); WideResult:=WideLeft Or WideRight Or MixedWide;
  If WideResult Then Begin
   If Not WideRight Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
   Emit2($89,$C3); Emit2($89,$D1); Emit($58);
   If WideLeft Then Emit($5A) Else If LeftUnsigned Then Emit2($31,$D2) Else Emit($99);
   RequireInteger(T); RequireInteger(R);
   Case Op Of
    tkTimes:CallTo(RuntimeStandard[14]);
    tkDiv,tkMod:Begin
     CallTo(RuntimeStandard[15]);
     If Op=tkMod Then Begin Emit2($89,$D8); Emit2($89,$CA) End;
    End;
    tkAnd:Begin Emit2($21,$D8); Emit2($21,$CA) End;
    tkShl,tkShr:Begin
     Emit2($89,$D9); Emit2($80,$E1); Emit(31); Emit2($09,$C9); Emit2($75,3); Skip:=Jump;
     ShiftLoop:=CodeSize;
     If Op=tkShl Then Begin Emit2($D1,$E0); Emit2($D1,$D2) End
     Else Begin Emit2($D1,$EA); Emit2($D1,$D8) End;
     Emit($E2); Emit(Byte(Longint(ShiftLoop)-CodeSize-1)); PatchJump(Skip,CodeSize);
    End;
   End;
  End Else Begin
  ConstOp:=(Op=tkAnd) And TailConst(CV);
  If Not ConstOp Then Begin Emit2($89,$C3); Emit($58) End;
  If Op=tkAnd Then Begin
   If (T<>R) Or Not (T In [ttInteger,ttBoolean]) Then Fail(26,'Types incompatibles');
   If ConstOp Then Begin Emit($25); EmitWord(CV) End Else Emit2($21,$D8);
  End Else
  Begin
   RequireInteger(T); RequireInteger(R);
   Case Op Of
   tkTimes:Begin Emit2($F7,$EB); OverflowCheck(LeftUnsigned And ExprUnsigned) End;
   tkDiv,tkMod:
   Begin
    Emit2($09,$DB); Emit2($75,6); LoadImmediate(200); CallTo(RuntimeError);
    If LeftUnsigned And (ExprUnsigned Or (RightKnown And (RightValue>0))) Then Begin Emit2($31,$D2); Emit2($F7,$F3) End
    Else Begin
     Emit($3D); EmitWord($8000); Emit2($75,12);
     Emit2($81,$FB); EmitWord($FFFF); Emit2($75,6); LoadImmediate(200); CallTo(RuntimeError);
     Emit($99); Emit2($F7,$FB);
    End;
    If Op=tkMod Then Emit2($89,$D0);
   End;
   tkShl,tkShr:
   Begin
    Emit2($89,$D9);
    If Op=tkShl Then Emit2($D3,$E0) Else Emit2($D3,$E8);
   End;
  End;
 End;
 End;
 If ShortCircuit Then PatchJump(Skip,CodeSize);
 ExprKnown:=LeftKnown And ExprKnown;
 If ExprKnown Then Begin
  Case Op Of
   tkTimes:Begin
    Check:=LeftValue; Check:=Check*ExprValue;
    If (Check<-2147483647.0-1) Or (Check>2147483647.0) Then Fail(76,'Debordement expression constante');
    ExprValue:=LeftValue*ExprValue;
   End;
   tkDiv,tkMod:Begin
    If (ExprValue=0) Or ((LeftValue=-2147483647-1) And (ExprValue=-1)) Then ExprKnown:=False
    Else If Op=tkDiv Then ExprValue:=LeftValue Div ExprValue Else ExprValue:=LeftValue Mod ExprValue;
   End;
   tkAnd:ExprValue:=LeftValue And ExprValue;
   tkShl,tkShr:Begin
    If (ExprValue<0) Or (ExprValue>31) Then ExprKnown:=False
    Else If Op=tkShl Then ExprValue:=LeftValue Shl ExprValue Else ExprValue:=LeftValue Shr ExprValue;
   End;
  End;
 End;
 If T=ttInteger Then Begin
  { Comme TP: Word shl n reste Word; un operande Word avec une constante positive reste Word. }
  If WideResult Then ExprType:=9
  Else If Op In [tkShl,tkShr] Then Begin If LeftUnsigned Then ExprType:=3 Else ExprType:=1 End
  Else If (LeftUnsigned And (ExprUnsigned Or (RightKnown And (RightValue>=0)))) Or
          (ExprUnsigned And LeftKnown And (LeftValue>=0)) Then ExprType:=3 Else ExprType:=1;
  ExprUnsigned:=ExprType=3;
 End Else ExprType:=LeftType;
End;
Term:=T;
End;

Function SimpleExpression: Byte;
Var
 T,R,Op,Sign: Byte;
 Skip,CV: Word; ConstOp: Boolean;
 ShortCircuit,WideLeft,WideRight,WideResult: Boolean;
 LeftType: Word; LeftUnsigned: Boolean;
 LeftKnown: Boolean; LeftValue: Longint; Check: Real;
 StrTemp,LeftArray,RightKnown,MixedWide: Boolean; RightT: Word; RightValue: Longint;
Begin
 Sign:=0; StrTemp:=False;
 If Token In [tkPlus,tkMinus] Then Begin
  Sign:=Token; NextToken
 End;
 T:=Term;
 If Sign<>0 Then ExprLiteral:=False;
 If (Sign<>0) And (T<>ttReal) Then RequireInteger(T);
 If (Sign=tkMinus) And (T=ttReal) Then RealUnary(5)
 Else If Sign=tkMinus Then Begin
  Emit2($F7,$D8);
  If Types[ExprType].Width=4 Then Begin Emit2($83,$D2); Emit(0); Emit2($F7,$DA) End
  Else ExprType:=1;
  ExprUnsigned:=False; ExprValue:=-ExprValue;
 End;
 While Token In [tkPlus,tkMinus,tkOr,tkXor] Do Begin
  Op:=Token;
  If (T=ttPointer) And IsCharPointer(ExprType) And (Op In [tkPlus,tkMinus]) And ExtendedSyntax Then Begin
   { $X+: P+n et P-n agissent sur l'offset seulement; P-Q donne un entier. }
   LeftType:=ExprType; Emit($52); Emit($50); NextToken; R:=Term; ExprLiteral:=False;
   If (R=ttArray) And IsCharArray(ExprType) Then Begin R:=ttPointer; ExprType:=12 End;
   If (R=ttPointer) And (Op=tkMinus) Then Begin
    If Not IsCharPointer(ExprType) Then Fail(26,'PChar attendu');
    Emit2($89,$C3); Emit($58); Emit($5A); Emit2($29,$D8);
    T:=ttInteger; ExprType:=1; ExprUnsigned:=False;
   End Else Begin
    RequireInteger(R);
    Emit2($89,$C3); Emit($58); Emit($5A);
    If Op=tkPlus Then Emit2($01,$D8) Else Emit2($29,$D8);
    T:=ttPointer; ExprType:=LeftType; ExprUnsigned:=False;
   End;
   ExprKnown:=False; Continue;
  End;
  If T=ttSet Then Begin
   LeftType:=ExprType; If Not (Op In [tkPlus,tkMinus]) Then Fail(26,'Operation set invalide');
   Emit($52); Emit($50); NextToken; R:=Term; ExprLiteral:=False;
   If R<>ttSet Then Fail(26,'Ensemble attendu');
   ExprType:=SetBinary(LeftType,ExprType,Op); ExprKnown:=False; ExprUnsigned:=False; Continue;
  End;
  LeftArray:=(T=ttArray) And IsAnyCharArray(ExprType) And (Op=tkPlus);
  If LeftArray Then Begin LeftType:=ExprType; T:=ttString; ExprLiteral:=False End;
  If (T In [ttString,ttChar]) And (Op=tkPlus) Then Begin
   NextToken;
   { Constantes juxtaposees ('a'+#13+'b'): pliage en une seule constante chaine. }
   If ExprLiteral And (Token=tkConstant) And TokenIsString And
      (Length(ExprLiteralText)+Length(TokenText)<=255) Then Begin
    CodeSize:=LiteralMarkCode; FixupCount:=LiteralMarkFixup; RelativeCount:=LiteralMarkRelative;
    NativeRefCount:=LiteralMarkNative; RelocationCount:=LiteralMarkReloc; DataSize:=LiteralMarkData;
    ExprLiteralText:=ExprLiteralText+TokenText; NextToken;
    T:=ttString; ExprType:=7; Emit($B8); DataAddress(StoreString(ExprLiteralText)); Emit2($8C,$DA);
    ExprKnown:=False; ExprUnsigned:=False; Continue;
   End;
   If T=ttChar Then StringFromChar;
   Emit($52); Emit($50); R:=Term; ExprLiteral:=False;
   If LeftArray And (R=ttInteger) And ExtendedSyntax And IsCharArray(LeftType) Then Begin
    { TableauChar + n: arithmetique PChar ($X+) }
    Emit2($89,$C3); Emit($58); Emit($5A); Emit2($01,$D8);
    T:=ttPointer; ExprType:=12; ExprUnsigned:=False; ExprKnown:=False; StrTemp:=False; Continue;
   End;
   If LeftArray Then Begin
    { convertir la gauche (empilee) en chaine temporaire }
    RightT:=ExprType;
    Emit($52); Emit($50); Emit2($89,$E3); Emit($36); Emit2($8B,$47); Emit(4); Emit($36); Emit2($8B,$57); Emit(6);
    CharArrayToString(LeftType);
    Emit2($89,$E3); Emit($36); Emit2($89,$47); Emit(4); Emit($36); Emit2($89,$57); Emit(6); Emit($58); Emit($5A);
    ExprType:=RightT;
   End;
   If (R=ttArray) And IsAnyCharArray(ExprType) Then Begin CharArrayToString(ExprType); R:=ttString End;
   If R=ttChar Then StringFromChar Else If R<>ttString Then Fail(67,'Chaine attendue');
   ExprType:=StringBinary(StrTemp); StrTemp:=True; T:=ttString; ExprKnown:=False; ExprUnsigned:=False; Continue;
  End;
  ShortCircuit:=(Op=tkOr) And (T=ttBoolean) And (OptionBits And $40=0);
  LeftType:=ExprType; LeftUnsigned:=ExprUnsigned;
  LeftKnown:=ExprKnown; LeftValue:=ExprValue;
  If ShortCircuit Then Begin
   Emit2($09,$C0); Emit2($74,$03); Skip:=Jump;
  End;
  WideLeft:=(T=ttInteger) And (Types[LeftType].Width=4);
  If T=ttReal Then PushReal Else Begin If WideLeft Then Emit($52); Emit($50) End;
  NextToken; R:=Term; ExprLiteral:=False;
  RightKnown:=ExprKnown; RightValue:=ExprValue;
  If (T=ttInteger) And (R=ttInteger) And (LeftUnsigned<>ExprUnsigned) And (Op In [tkPlus,tkMinus]) And
     Not (LeftUnsigned And RightKnown And (RightValue>=0) And (RightValue<=65535)) And
     Not (ExprUnsigned And LeftKnown And (LeftValue>=0) And (LeftValue<=65535)) Then Begin
   If Not ((Types[LeftType].Width=4) Or (Types[ExprType].Width=4)) Then MixedWide:=True;
  End Else MixedWide:=False;
  If (T=ttReal) Or (R=ttReal) Then Begin
   If Not (Op In [tkPlus,tkMinus]) Then Fail(26,'Operation reelle invalide');
   If Op=tkPlus Then RealBinary(LeftType,ExprType,1,False) Else RealBinary(LeftType,ExprType,2,False);
   T:=ttReal; Continue;
  End;
  WideRight:=(R=ttInteger) And (Types[ExprType].Width=4); WideResult:=WideLeft Or WideRight Or MixedWide;
  ConstOp:=False;
  If WideResult Then Begin
   If Not WideRight Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
   Emit2($89,$C3); Emit2($89,$D1); Emit($58);
   If WideLeft Then Emit($5A) Else If LeftUnsigned Then Emit2($31,$D2) Else Emit($99);
  End Else Begin
   ConstOp:=TailConst(CV);
   If Not ConstOp Then Begin Emit2($89,$C3); Emit($58) End;
  End;
  If Op In [tkOr,tkXor] Then Begin
   If (T<>R) Or Not (T In [ttInteger,ttBoolean]) Then Fail(26,'Types incompatibles');
   If ConstOp Then Begin If Op=tkOr Then Emit($0D) Else Emit($35); EmitWord(CV) End
   Else If Op=tkOr Then Begin Emit2($09,$D8); If WideResult Then Emit2($09,$CA) End
   Else Begin Emit2($31,$D8); If WideResult Then Emit2($31,$CA) End;
  End Else
  Begin
   RequireInteger(T); RequireInteger(R);
   If ConstOp Then Begin If Op=tkPlus Then Emit($05) Else Emit($2D); EmitWord(CV) End
   Else If Op=tkPlus Then Begin Emit2($01,$D8); If WideResult Then Emit2($11,$CA) End
   Else Begin Emit2($29,$D8); If WideResult Then Emit2($19,$CA) End;
   If Not WideResult Then OverflowCheck(LeftUnsigned And ExprUnsigned);
  End;
  If ShortCircuit Then PatchJump(Skip,CodeSize);
  ExprKnown:=LeftKnown And ExprKnown;
  If ExprKnown Then Begin
   Check:=LeftValue;
   If Op=tkPlus Then Check:=Check+ExprValue Else If Op=tkMinus Then Check:=Check-ExprValue;
   If (Check<-2147483647.0-1) Or (Check>2147483647.0) Then Fail(76,'Debordement expression constante');
   Case Op Of
    tkPlus:ExprValue:=LeftValue+ExprValue; tkMinus:ExprValue:=LeftValue-ExprValue;
    tkOr:ExprValue:=LeftValue Or ExprValue; tkXor:ExprValue:=LeftValue Xor ExprValue;
   End;
  End;
  If T=ttInteger Then Begin
   If WideResult Then ExprType:=9
   Else If (LeftUnsigned And (ExprUnsigned Or (RightKnown And (RightValue>=0)))) Or
           (ExprUnsigned And LeftKnown And (LeftValue>=0)) Then ExprType:=3 Else ExprType:=1;
   ExprUnsigned:=ExprType=3;
  End Else ExprType:=LeftType;
 End;
 SimpleExpression:=T;
End;

Function Expression: Byte;
Var T,R,Op,Jcc,HighJcc: Byte; LeftType: Word; LeftUnsigned,WideLeft,WideRight,Wide: Boolean;
 P,Q,H,CV: Word;
Begin
 T:=SimpleExpression;
 If Token=tkIn Then Begin
  LeftType:=ExprType;
  If Not (T In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(27,'Element IN non ordinal');
  { Longint: hors de tout ensemble si la partie haute n'est pas nulle. }
  If Types[LeftType].Width=4 Then Begin Emit2($09,$D2); Emit2($74,3); LoadImmediate($FFFF) End;
  Emit($50); NextToken; R:=SimpleExpression; ExprLiteral:=False;
  If R<>ttSet Then Fail(26,'Ensemble attendu apres IN');
  If (TypeExtras[ExprType].ElementType<>0) And Not CompatibleTypes(LeftType,TypeExtras[ExprType].ElementType) Then
   Fail(26,'Type de l''element IN');
  Emit2($89,$C7); Emit2($8E,$C2); Emit($58);
  Emit($2D); EmitWord(Types[ExprType].LowBound Div 8*8);
  Emit($3D); EmitWord(TypeExtras[ExprType].Size*8); Emit2($72,3); P:=Jump;
  Emit2($89,$C3); Emit2($89,$C1); Emit2($80,$E1); Emit(7);
  Emit($BA); EmitWord(1); Emit2($D3,$E2); Emit2($B1,3); Emit2($D3,$EB);
  Emit($26); Emit2($84,$11); LoadImmediate(1); Emit2($75,2); Emit2($31,$C0); Q:=Jump;
  PatchJump(P,CodeSize); Emit2($31,$C0); PatchJump(Q,CodeSize);
  ExprType:=5; ExprUnsigned:=False; ExprKnown:=False; Expression:=ttBoolean; Exit;
 End;
 If Token In [tkEqual,tkNE,tkGreater,tkLess,tkGE,tkLE] Then Begin
  { Deux caracteres se comparent comme des octets; un caractere face a une
    chaine est converti apres evaluation du membre droit. }
  LeftType:=ExprType; LeftUnsigned:=ExprUnsigned;
  WideLeft:=(T=ttPointer) Or ((T=ttInteger) And (Types[LeftType].Width=4));
  Op:=Token;
  If T=ttReal Then PushReal Else Begin If WideLeft Or (T In [ttString,ttSet,ttArray]) Then Emit($52); Emit($50) End;
  NextToken; R:=SimpleExpression; ExprLiteral:=False;
  If (T=ttChar) And (R=ttString) Then Begin
   Emit($58); StringFromChar; Emit($52); Emit($50); T:=ttString; LeftType:=7;
  End;
  If (T=ttString) And (R=ttChar) Then Begin StringFromChar; R:=ttString; ExprType:=7 End;
  If (T=ttArray) And (TypeExtras[LeftType].ElementType=6) And (R In [ttString,ttChar,ttArray]) Then Begin
   { Tableau de Char compare a une chaine (meme longueur) ou a un autre tableau. }
   If R=ttChar Then StringFromChar;
   Emit2($89,$C7); Emit2($8E,$C2);                               { es:di = droite }
   If R<>ttArray Then Begin Emit($26); Emit2($8A,$1D); Emit($47) End; { bl = longueur; di++ }
   Emit($5E); Emit($5A); Emit($1E); Emit2($8E,$DA);             { ds:si = gauche }
   Emit($B9); EmitWord(TypeExtras[LeftType].Size);
   If R<>ttArray Then Begin Emit2($80,$FB); Emit(TypeExtras[LeftType].Size); Emit2($75,2) End;
   Emit2($F3,$A6); Emit($1F);                                    { repe cmpsb; pop ds }
   Case Op Of tkGreater:Jcc:=$77; tkLess:Jcc:=$72; tkGE:Jcc:=$73; tkLE:Jcc:=$76; tkNE:Jcc:=$75 Else Jcc:=$74 End;
   LoadImmediate(1); Emit2(Jcc,$02); Emit2($31,$C0); CondTail:=CodeSize; CondJcc:=Jcc;
   ExprType:=5; ExprKnown:=False; ExprUnsigned:=False; Expression:=ttBoolean; Exit;
  End;
  If (T=ttReal) Or (R=ttReal) Then Begin
   RealBinary(LeftType,ExprType,0,True); Emit2($09,$C0);
   Jcc:=$74; Case Op Of tkNE:Jcc:=$75; tkLess:Jcc:=$7C; tkGreater:Jcc:=$7F; tkLE:Jcc:=$7E; tkGE:Jcc:=$7D End;
   LoadImmediate(1); Emit2(Jcc,2); Emit2($31,$C0);
   ExprType:=5; ExprKnown:=False; ExprUnsigned:=False; Expression:=ttBoolean; Exit;
  End;
  If T<>R Then Fail(26,'Comparaison de types incompatibles');
  If Not CompatibleTypes(LeftType,ExprType) Then Fail(26,'Identites de types incompatibles');
  Jcc:=$74;
  Case Op Of
   tkEqual:Jcc:=$74; tkNE:Jcc:=$75; tkGreater:Jcc:=$7F;
   tkLess:Jcc:=$7C; tkGE:Jcc:=$7D; tkLE:Jcc:=$7E;
  End;
  If T=ttSet Then Begin
   SetComparison(LeftType,ExprType,Op);
   ExprType:=5; ExprUnsigned:=False; ExprKnown:=False; Expression:=ttBoolean; Exit;
  End Else If T=ttString Then Begin
   Emit2($89,$C7); Emit2($8E,$C2); Emit($5E); Emit($5A);
   Emit($1E); Emit2($8E,$DA); CallTo(RuntimeStandard[13]); Emit($1F); Emit2($09,$C0);
  End Else If T=ttPointer Then Begin
   If Op In [tkEqual,tkNE] Then Begin
    Emit2($89,$C3); Emit($58); Emit($59); Emit2($31,$D8); Emit2($31,$D1); Emit2($09,$C8);
   End Else Begin
    { $X+: ordre de deux PChar, compare sur l'offset (non signe). }
    If Not (IsCharPointer(LeftType) And ExtendedSyntax) Then Fail(26,'Comparaison ordonnee de pointeurs');
    Emit2($89,$C3); Emit($58); Emit($59); Emit2($39,$D8);
    Case Op Of tkGreater:Jcc:=$77; tkLess:Jcc:=$72; tkGE:Jcc:=$73; tkLE:Jcc:=$76 End;
   End;
  End Else Begin
   WideRight:=(R=ttInteger) And (Types[ExprType].Width=4); Wide:=WideLeft Or WideRight;
   { Word compare a Integer (signes differents): comparaison 32 bits comme TP,
     sauf avec une constante positive ou la comparaison non signee suffit. }
   If (T=ttInteger) And (R=ttInteger) And (LeftUnsigned<>ExprUnsigned) And
      Not (LeftUnsigned And ExprKnown And (ExprValue>=0) And (ExprValue<=65535)) Then Wide:=True;
   If Wide Then Begin
    If Not WideRight Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
    Emit2($89,$C3); Emit2($89,$D1); Emit($58);
    If WideLeft Then Emit($5A) Else If LeftUnsigned Then Emit2($31,$D2) Else Emit($99);
    Emit2($39,$CA); Emit2($74,3); H:=Jump;
    Emit2($39,$D8);
    Case Op Of tkGreater:Jcc:=$77; tkLess:Jcc:=$72; tkGE:Jcc:=$73; tkLE:Jcc:=$76 End;
    Emit2(Jcc Xor 1,3); P:=Jump; Q:=Jump;
    PatchJump(H,CodeSize);
    HighJcc:=$74;
    Case Op Of tkEqual:HighJcc:=$74; tkNE:HighJcc:=$75;
     tkGreater,tkGE:HighJcc:=$7F; tkLess,tkLE:HighJcc:=$7C End;
    Emit2(HighJcc Xor 1,3); H:=Jump;
    PatchJump(Q,CodeSize); Emit2($31,$C0); Q:=Jump;
    PatchJump(P,CodeSize); PatchJump(H,CodeSize); LoadImmediate(1); PatchJump(Q,CodeSize);
    T:=ttBoolean; ExprType:=5; ExprUnsigned:=False; ExprKnown:=False; Expression:=T; Exit;
   End;
   If TailConst(CV) Then Begin Emit($3D); EmitWord(CV) End
   Else Begin Emit2($89,$C3); Emit($58); Emit2($39,$D8) End;
   If (T In [ttChar,ttBoolean,ttEnum]) Or (LeftUnsigned And (ExprUnsigned Or (ExprKnown And (ExprValue>=0)))) Then
    Case Op Of tkGreater:Jcc:=$77; tkLess:Jcc:=$72; tkGE:Jcc:=$73; tkLE:Jcc:=$76 End;
  End;
  LoadImmediate(1); Emit2(Jcc,$02); Emit2($31,$C0); CondTail:=CodeSize; CondJcc:=Jcc;
  T:=ttBoolean; ExprType:=5; ExprUnsigned:=False; ExprKnown:=False;
 End;
 Expression:=T;
End;

Procedure OverflowCheck(Unsigned: Boolean);
{ $Q+: apres une addition, soustraction ou multiplication 16 bits, les
  indicateurs OF (signe) ou CF (non signe) declenchent l'erreur 215. }
Var Bad,Done: Word;
Begin
 If OptionBits And $8000=0 Then Exit;
 If Unsigned Then Emit2($73,3) Else Emit2($71,3);
 Bad:=Jump; Done:=Jump;
 PatchJump(Bad,CodeSize); LoadImmediate(215); CallTo(RuntimeError); PatchJump(Done,CodeSize);
End;

Procedure StackRoom(Needed: Word);
Begin
 If OptionBits And 4=0 Then Exit;
 CallTo(RuntimeStandard[72]); EmitWord(Needed); { call StackCheck; dw besoin }
End;

Function NativeCall(I: Word): Byte;
Var
 J, V, A, ParamType: Word;
 T: Byte;
 Name: TShortString;
Begin
 NeedNative(Symbols[I].Owner);
 StackRoom(320);
 Emit($1E); Emit($06); Emit($55); { saves BELOW arguments, not between args and return }
 If Symbols[I].ParamCount<>0 Then Begin
  Need(tkLP);
  For J:=1 To Symbols[I].ParamCount Do Begin
   If J<>1 Then Need(tkComma);
  ParamType:=Symbols[I].ParamTypeIds[J];
   If Symbols[I].ParamFlags[J]=6 Then Begin
    If Token<>tkIdent Then Fail(20,'Parametre var attendu');
    Name:=TokenText; NextToken; V:=ResolveSymbol(Name);
    If Symbols[V].Kind<>skVar Then Fail(26,'Variable attendue');
    PushVariableAddress(V);
    If (Types[ExprType].Typ<>Symbols[I].ParamTypes[J]) Or
    (Types[ExprType].Width<>Symbols[I].ParamWidths[J]) Or
    ((Types[ExprType].Signed And (Types[ExprType].Width=1))<>Symbols[I].ParamSigned[J]) Then Fail(26,
    'Type du parametre var');
    If (Symbols[I].ParamTypes[J]=ttString) And
       ((Types[ExprType].Capacity<>Types[ParamType].Capacity) And (OptionBits And $10<>0) And
        (OptionBits And $4000=0)) Then
      Fail(100,'Longueur de chaine du parametre var');
   End Else
   Begin
    T:=Expression;
    If Symbols[I].ParamTypes[J]=ttString Then Begin
     If Not (T In [ttString,ttChar]) Then Fail(26,'Chaine pour parametre natif attendue');
     If T=ttChar Then Begin
      A:=AllocData(2); Emit($A2); DataAddress(A+1);
      Emit2($C6,$06); DataAddress(A); Emit(1); Emit($B8); DataAddress(A);
      Emit2($8C,$DA);
     End;
     Emit($52); Emit($50); { segment et adresse du shortstring source }
    End Else Begin
    If T<>Symbols[I].ParamTypes[J] Then Fail(26,'Type du parametre valeur');
    If Symbols[I].ParamWidths[J]=1 Then Begin
     If Symbols[I].ParamSigned[J] Then Emit($98) Else Emit2($30,$E4);
    End;
    Emit($50); { TP6 empile les scalaires courts dans un mot }
    End;
   End;
  End;
  Need(tkRP);
 End Else If Token=tkLP Then Begin
  NextToken; Need(tkRP)
 End;
 SetNativeDS; Emit2($8E,$C2); { es=ds }
 Emit($9A); NativeReference(Symbols[I].Owner,3,Symbols[I].NativeMap,0);
 AddSegmentRelocation(CodeSize,0); EmitWord(0);
 Emit($5D); Emit($07); Emit($1F); { callee a retire les parametres avec retf N }
 If Symbols[I].Width=1 Then Begin
  If Symbols[I].SignedByte Then Emit($98) Else Emit2($30,$E4);
 End;
 NativeCall:=Symbols[I].Typ;
End;

Function UserCall(I: Word): Byte;
Var J,V,T,N,A: Word; Kind: Byte; Name: TShortString;
Begin
 StackRoom(Symbols[I].ParamBytes+268);
 Emit($06); { preserve ES: indirect var accesses use LES }
 If Symbols[I].ParamCount<>0 Then Begin
  Need(tkLP);
  For J:=1 To Symbols[I].ParamCount Do Begin
   If J<>1 Then Need(tkComma);
   T:=Symbols[I].ParamTypeIds[J];
   If Symbols[I].ParamFlags[J]=7 Then Begin
    { Tableau ouvert: adresse du tableau puis High, reordonnes sur la pile. }
    If (Token=tkConstant) And TokenIsString And (TypeExtras[T].ElementType=6) Then Begin
     { constante chaine pour un "array of Char" ouvert (TP 7) }
     A:=StoreString(TokenText); N:=Length(TokenText); NextToken;
     Emit($1E); Emit($B8); DataAddress(A+1); Emit($50); LoadImmediate(N-1);
     Emit($5F); Emit($5B); Emit($50); Emit($53); Emit($57);
    End Else Begin
    If Token<>tkIdent Then Fail(20,'Variable pour parametre var attendue');
    Name:=TokenText; NextToken; V:=ResolveSymbol(Name);
    PushVariableAddress(V); A:=ExprType;
    If (Types[A].Typ<>ttArray) Or Not CompatibleTypes(TypeExtras[A].ElementType,TypeExtras[T].ElementType) Then
     Fail(26,'Tableau attendu');
    If TypeExtras[A].FieldCount=$FFFF Then Begin
     ScopeAddress(Symbols[V].Scope); Emit($36); Emit2($8B,$87); EmitWord(Symbols[V].Addr+4);
    End Else LoadImmediate(Word(Types[TypeExtras[A].IndexType].HighBound-Types[TypeExtras[A].IndexType].LowBound));
    Emit($5F); Emit($5B); Emit($50); Emit($53); Emit($57); { High, seg, ofs }
    End;
   End Else
   If Symbols[I].ParamFlags[J]=6 Then Begin
    If Token<>tkIdent Then Fail(20,'Variable pour parametre var attendue');
    If IsMemPort(TokenText) And (TokenText[1]='M') And (FindLexicalSymbol(TokenText)=0) Then Begin
     ExprType:=VariableArgument; Emit($06); Emit($57);
    End Else Begin
    Name:=TokenText; NextToken; V:=ResolveSymbol(Name);
    PushVariableAddress(V);
    End;
    { V- ou P+ (OpenString): une chaine de toute longueur declaree est acceptee. }
    If (T<>0) And (ExprType<>T) And
       Not ((Types[T].Typ In [ttFile,ttText]) And CompatibleTypes(T,ExprType)) And
       Not ((Types[T].Typ=ttString) And (Types[ExprType].Typ=ttString) And
            ((OptionBits And $10=0) Or (OptionBits And $4000<>0) Or
             (Types[T].Capacity=Types[ExprType].Capacity))) Then
     Fail(26,'Identite du parametre var');
   End Else Begin
    Kind:=Expression;
    If IsCharPointer(T) And ExtendedSyntax Then Begin
     If ExprLiteral Then Begin LiteralToPChar; Kind:=ttPointer End
     Else If (Kind=ttArray) And IsCharArray(ExprType) Then Begin Kind:=ttPointer; ExprType:=12 End;
    End;
    If (Types[T].Typ=ttString) And (Kind=ttChar) Then Begin StringFromChar; Kind:=ttString; ExprType:=7; ExprKnown:=False End;
    If (Types[T].Typ=ttReal) And (Kind=ttInteger) Then Begin ToReal(ExprType); ExprType:=11; Kind:=ttReal End;
    If (Kind<>Types[T].Typ) Or Not CompatibleTypes(T,ExprType) Then Fail(26,'Type du parametre valeur');
    If ExprKnown And (Types[T].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) And
       ((ExprValue<Types[T].LowBound) Or (ExprValue>Types[T].HighBound)) Then
      Fail(76,'Parametre constant hors limites');
    If (OptionBits And 2<>0) And (Types[T].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then
     RangeBounds(Types[T].LowBound,Types[T].HighBound,ExprType);
    If Types[T].Width=1 Then Begin
     If Types[T].Signed Then Emit($98) Else Emit2($30,$E4);
    End;
    If (Types[T].Width=4) And (Types[ExprType].Width<>4) Then Begin
     If ExprUnsigned Then Emit2($31,$D2) Else Emit($99);
    End;
    If Types[T].Typ=ttSet Then Begin
     A:=AllocData(32); NormalizeSet(ExprType,A); TrimSet(T,A);
     Emit($B8); DataAddress(A+Types[T].LowBound Div 8); Emit2($8C,$DA);
    End;
    If Types[T].Typ In [ttArray,ttRecord,ttSet,ttString,ttReal] Then Begin
     N:=(TypeExtras[T].Size+1) And $FFFE;
     If N<2 Then N:=2;
     { copie sur la pile par le runtime: call StringArg/BlockArg; dw N; dw capacite|taille }
     If Types[T].Typ=ttString Then Begin CallTo(RuntimeStandard[79]); EmitWord(N); EmitWord(Types[T].Capacity) End
     Else Begin CallTo(RuntimeStandard[80]); EmitWord(N); EmitWord(TypeExtras[T].Size) End;
    End Else Begin
     If Types[T].Width=4 Then Emit($52); Emit($50);
    End;
   End;
  End;
  Need(tkRP);
 End Else If Token=tkLP Then Begin NextToken; Need(tkRP) End;
 If Symbols[I].InlineBody Then For J:=1 To Length(Symbols[I].StrValue) Do Emit(Ord(Symbols[I].StrValue[J]))
 Else EmitLocalCall(I);
 Emit($07);
 UserCall:=Symbols[I].Typ;
 ExprType:=SymbolType(I); ExprKnown:=False;
 ExprUnsigned:=(Symbols[I].Typ=ttInteger) And (ExprType<>0) And Not Types[ExprType].Signed;
End;

Function SizeArgument: Word;
Var I,T,C,F,R,N,S: Word; Name: TShortString;
Begin
 I:=0; If Token=tkIdent Then I:=FindSymbol(TokenText);
 If (I<>0) And (Symbols[I].Kind=skVar) Then Begin
  C:=CodeSize; F:=FixupCount; R:=RelativeCount; N:=NativeRefCount; S:=RelocationCount;
  Name:=TokenText; NextToken; I:=ResolveSymbol(Name); T:=Designator(I);
  CodeSize:=C; FixupCount:=F; RelativeCount:=R; NativeRefCount:=N; RelocationCount:=S;
 End Else T:=ReadType;
 SizeArgument:=T;
End;

Function VariableArgument: Word;
Var I,J,T: Word; Name: TShortString;
Begin
 If Token<>tkIdent Then Fail(43,'Variable attendue');
 Name:=TokenText; NextToken; J:=FindLexicalSymbol(Name);
 If (J=0) And (Token=tkLB) And IsMemPort(Name) And (Name[1]='M') Then Begin
  MemPortIndex(Name);
  If Name='MEM' Then VariableArgument:=2 Else If Name='MEMW' Then VariableArgument:=3 Else VariableArgument:=9;
  Exit;
 End;
 T:=0;
 If (J<>0) And (Symbols[J].Kind=skType) Then T:=Symbols[J].TypeId Else If J=0 Then T:=BuiltinType(Name);
 If (T<>0) And (Token=tkLP) Then Begin
  { Transtypage d'une variable: Word(X) designe X vu comme un Word. }
  NextToken; I:=VariableArgument; Need(tkRP); VariableArgument:=T; Exit;
 End;
 I:=ResolveSymbol(Name); VariableArgument:=Designator(I);
End;

Procedure LiteralToPChar;
{ Remplace le code de chargement d'une constante chaine Pascal par l'adresse
  DX:AX d'une copie a zero terminal (syntaxe etendue $X+). }
Var Z: Word; K: Integer;
Begin
 CodeSize:=LiteralMarkCode; FixupCount:=LiteralMarkFixup; RelativeCount:=LiteralMarkRelative;
 NativeRefCount:=LiteralMarkNative; RelocationCount:=LiteralMarkReloc; DataSize:=LiteralMarkData;
 Z:=AllocData(Length(ExprLiteralText)+1);
 For K:=1 To Length(ExprLiteralText) Do Data[Z+K-1]:=Ord(ExprLiteralText[K]);
 Data[Z+Length(ExprLiteralText)]:=0;
 Emit($B8); DataAddress(Z); Emit2($8C,$DA);
 ExprType:=12; ExprKnown:=False; ExprUnsigned:=False; ExprLiteral:=False;
End;

Procedure WriteZString;
{ DX:AX = PChar; ecrit les caracteres jusqu'au zero terminal via RuntimeChar. }
Var LoopStart,Done: Word;
Begin
 Emit($1E); Emit2($8E,$DA); Emit2($89,$C6);        { push ds; mov ds,dx; mov si,ax }
 LoopStart:=CodeSize;
 Emit($AC); Emit2($08,$C0); Emit2($75,3); Done:=Jump; { lodsb; or al,al; jnz suite; jmp fin }
 Emit2($30,$E4); Emit($1E); Emit($56);                { xor ah,ah; push ds; push si }
 Emit2($8B,$DC); Emit($36); Emit2($8E,$5F); Emit(4);  { mov bx,sp; mov ds,ss:[bx+4] }
 CallTo(RuntimeChar);
 Emit($5E); Emit($1F); JumpTo(LoopStart);             { pop si; pop ds; jmp boucle }
 PatchJump(Done,CodeSize); Emit($1F);                 { pop ds }
End;

Procedure StringFromChar;
Var A: Word;
Begin
 A:=AllocData(2); Emit($A2); DataAddress(A+1);
 Emit2($C6,$06); DataAddress(A); Emit(1);
 Emit($B8); DataAddress(A); Emit2($8C,$DA);
End;

Procedure StringExpression;
Var T: Byte;
Begin
 T:=Expression;
 If (T=ttArray) And IsAnyCharArray(ExprType) Then Begin CharArrayToString(ExprType); T:=ttString End;
 If T=ttChar Then StringFromChar Else If T<>ttString Then Fail(67,'Chaine attendue');
End;

Function SetConstructor: Word;
Var T,A,FirstType: Word; Kind: Byte; First: Boolean;
Begin
 T:=NewType(ttSet,0,0,False,0,255,0); TypeExtras[T].Size:=32;
 TypeExtras[T].ElementType:=2; First:=True; A:=AllocData(32);
 Emit($06); Emit($57); Emit($1E); Emit($07); Emit($BF); DataAddress(A);
 Emit2($31,$C0); Emit($B9); EmitWord(32); Emit2($F3,$AA); Emit($5F); Emit($07);
 Need(tkLB);
 While Token<>tkRB Do Begin
  Kind:=Expression;
  If Not (Kind In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(27,'Element set non ordinal');
  FirstType:=ExprType;
  If First Then Begin
   If Kind<>ttInteger Then TypeExtras[T].ElementType:=FirstType;
   First:=False;
  End;
  If Not CompatibleTypes(TypeExtras[T].ElementType,FirstType) Then Fail(26,'Elements set incompatibles');
  If ExprKnown And ((ExprValue<0) Or (ExprValue>255)) Then Fail(76,'Element set hors 0..255');
  Emit($50);
  If Token=tkRange Then Begin
   NextToken; Kind:=Expression;
   If Not CompatibleTypes(FirstType,ExprType) Then Fail(26,'Bornes set incompatibles');
   If ExprKnown And ((ExprValue<0) Or (ExprValue>255)) Then Fail(76,'Borne set hors 0..255');
   Emit2($89,$C3); Emit($58);
  End Else Begin Emit($58); Emit2($89,$C3) End;
  Emit($1E); Emit($07); Emit($BF); DataAddress(A); CallTo(RuntimeStandard[7]);
  If Token<>tkComma Then Break; NextToken;
 End;
 Need(tkRB); If First Then TypeExtras[T].ElementType:=0;
 Emit($B8); DataAddress(A); Emit2($8C,$DA); ExprKnown:=False;
 SetConstructor:=T;
End;

Procedure TrimSet(T,A: Word); { masquer les bits hors bornes dans le bitmap CS:A }
Var First,Last: Byte;
Begin
 First:=Byte($FF Shl (Types[T].LowBound Mod 8)); Last:=$FF Shr (7-Types[T].HighBound Mod 8);
 If Types[T].LowBound Div 8=Types[T].HighBound Div 8 Then Begin
  Emit2($80,$26); DataAddress(A+Types[T].LowBound Div 8); Emit(First And Last);
 End Else Begin
  Emit2($80,$26); DataAddress(A+Types[T].LowBound Div 8); Emit(First);
  Emit2($80,$26); DataAddress(A+Types[T].HighBound Div 8); Emit(Last);
 End;
End;

Procedure NormalizeSet(T,A: Word); { source DX:AX, destination universelle CS:A }
Begin
 Emit($52); Emit($50); Emit($1E); Emit($07); Emit($BF); DataAddress(A);
 Emit2($31,$C0); Emit($B9); EmitWord(32); Emit2($F3,$AA);
 Emit($5E); Emit($5A); Emit($1E); Emit2($8E,$DA);
 Emit($BF); DataAddress(A+Types[T].LowBound Div 8);
 Emit($B9); EmitWord(TypeExtras[T].Size); Emit2($F3,$A4); Emit($1F);
 TrimSet(T,A);
End;

Function SetBinary(LeftType,RightType: Word; Op: Byte): Word;
Var A,B,T,LoopStart: Word;
Begin
 If Not CompatibleTypes(LeftType,RightType) Then Fail(26,'Operations set incompatibles');
 A:=AllocData(32); B:=AllocData(32); NormalizeSet(RightType,B);
 Emit($58); Emit($5A); NormalizeSet(LeftType,A);
 Emit($BE); DataAddress(B); Emit($BF); DataAddress(A); Emit($B9); EmitWord(32);
 LoopStart:=CodeSize; Emit($AC);
 If Op=tkMinus Then Emit2($F6,$D0);
 Emit($26);
 If Op=tkPlus Then Emit2($08,$05) Else Emit2($20,$05);
 Emit($47); Emit($E2); Emit(Byte(Longint(LoopStart)-CodeSize-1));
 T:=NewType(ttSet,0,0,False,0,255,0); TypeExtras[T].Size:=32;
 TypeExtras[T].ElementType:=TypeExtras[LeftType].ElementType;
 If TypeExtras[T].ElementType=0 Then TypeExtras[T].ElementType:=TypeExtras[RightType].ElementType;
 Emit($B8); DataAddress(A); Emit2($8C,$DA); SetBinary:=T;
End;

Procedure CharArrayToString(T: Word);
{ DX:AX = adresse d'un tableau de caracteres: le copie dans un temporaire
  chaine (longueur = taille du tableau; pour un tableau a base zero en $X+,
  la copie s'arrete au premier #0 comme pour un PChar). }
Var A,N: Word; L,Z: Boolean;
Begin
 N:=TypeExtras[T].Size; If N>255 Then N:=255;
 Z:=ExtendedSyntax And (Types[TypeExtras[T].IndexType].LowBound=0);
 A:=TempAlloc(256); L:=TempLocal;
 Emit($1E); Emit2($89,$C6); Emit2($8E,$DA); TempPointerDI(A,L);   { push ds; mov si,ax; mov ds,dx; ES:DI temp }
 Emit($B9); EmitWord(N); Emit2($89,$FB); Emit($47);                 { mov cx,N; mov bx,di; inc di }
 Emit($AC);                                                        { lodsb }
 If Z Then Begin Emit2($08,$C0); Emit2($74,3); Emit($AA); Emit2($E2,$F8) End   { or al,al; jz fin; stosb; loop }
 Else Begin Emit($AA); Emit2($E2,$FC) End;                         { stosb; loop }
 Emit2($89,$F8); Emit2($29,$D8); Emit($48); Emit($26); Emit2($88,$07); Emit($1F); { longueur := di-bx-1 }
 TempPointerAX(A,L); ExprType:=7; ExprKnown:=False; ExprLiteral:=False;
End;

Function StringBinary(LeftIsTemp: Boolean): Word;
{ Entree: pointeur gauche empile (DX puis AX), droite dans DX:AX. Si la gauche
  est deja le temporaire de la concatenation precedente, on y ajoute la droite
  sur place (A+B+C+... n'utilise qu'un seul temporaire). }
Var A: Word; L: Boolean;
Begin
 If LeftIsTemp Then Begin A:=LastTempAddr; L:=LastTempLocal End
 Else Begin
  A:=TempAlloc(256); L:=TempLocal;
  Emit($52); Emit($50);                                            { sauver droite }
  Emit2($89,$E3); Emit($36); Emit2($8B,$77); Emit(4); Emit($36); Emit2($8B,$57); Emit(6);
  Emit($1E); Emit2($8E,$DA); TempPointerDI(A,L);                    { DS:SI gauche, ES:DI temp }
  LoadImmediate(1); Emit($B9); EmitWord(255); Emit($BB); EmitWord(255); CallTo(RuntimeStandard[1]); Emit($1F);
  Emit($58); Emit($5A);                                            { droite -> DX:AX }
 End;
 Emit2($89,$C6); Emit($1E); Emit2($8E,$DA); TempPointerDI(A,L);     { ajouter DS:SI a ES:DI }
 Emit($BB); EmitWord(255); CallTo(RuntimeStandard[3]); Emit($1F);
 Emit2($83,$C4); Emit(4);                                          { depiler la gauche }
 TempPointerAX(A,L); LastTempAddr:=A; LastTempLocal:=L; StringBinary:=7;
End;

Procedure SetComparison(LeftType,RightType: Word; Op: Byte);
Var A,B,P,Q,LoopStart: Word;
Begin
 If Not (Op In [tkEqual,tkNE,tkLE,tkGE]) Then Fail(26,'Comparaison ordonnee set');
 A:=AllocData(32); B:=AllocData(32); NormalizeSet(RightType,B);
 Emit($58); Emit($5A); NormalizeSet(LeftType,A);
 Emit($BE); DataAddress(A); Emit($BF); DataAddress(B); Emit($B9); EmitWord(32);
 If Op In [tkEqual,tkNE] Then Begin
  Emit2($F3,$A6); LoadImmediate(1);
  If Op=tkEqual Then Emit2($74,2) Else Emit2($75,2); Emit2($31,$C0);
 End Else Begin
  If Op=tkGE Then Begin Emit($BE); DataAddress(B); Emit($BF); DataAddress(A) End;
  LoopStart:=CodeSize; Emit($26); Emit2($8A,$05); Emit2($F6,$D0); Emit2($22,$04);
  Emit2($09,$C0); Emit2($74,3); P:=Jump;
  Emit($46); Emit($47); Emit($E2); Emit(Byte(Longint(LoopStart)-CodeSize-1));
  LoadImmediate(1); Q:=Jump; PatchJump(P,CodeSize); Emit2($31,$C0); PatchJump(Q,CodeSize);
 End;
End;

Procedure RandomWord;
{ N empile; AX := Random(N) (generateur congruentiel 32 bits de TP). }
Var P,Q: Word;
Begin
  Emit($A1); DataAddress(RandomSeed); Emit2($8B,$16); DataAddress(RandomSeed+2);
  Emit($BB); EmitWord($660D); Emit($B9); EmitWord($19); CallTo(RuntimeStandard[14]);
  Emit($05); EmitWord($F35F); Emit2($81,$D2); EmitWord($3C6E);
  Emit($A3); DataAddress(RandomSeed); Emit2($89,$16); DataAddress(RandomSeed+2); Emit($5B);
  Emit2($09,$DB); Emit2($75,3); P:=Jump;
  Emit($50); Emit2($89,$D0); Emit2($31,$D2); Emit2($F7,$F3); Emit($58);
  Emit2($F7,$F3); Emit2($89,$D0); Q:=Jump;
  PatchJump(P,CodeSize); Emit2($31,$C0); PatchJump(Q,CodeSize);
End;

Function StandardFunction(Name: TShortString): Word;
Var T,A,P,Q: Word; ScopedInput,Lcl: Boolean;
Begin
 If (Name='SQRT') Or (Name='SIN') Or (Name='COS') Or (Name='ARCTAN') Or (Name='LN') Or (Name='EXP') Then Begin
  Need(tkLP); T:=Expression; Need(tkRP); ToReal(ExprType);
  A:=10; If Name='SIN' Then A:=11 Else If Name='COS' Then A:=12 Else If Name='ARCTAN' Then A:=13 Else If Name='LN' Then A:=14 Else If Name='EXP' Then A:=15;
  RealUnary(A); StandardFunction:=11; Exit;
 End;
 If (Name='TRUNC') Or (Name='ROUND') Or (Name='INT') Or (Name='FRAC') Then Begin
  Need(tkLP); T:=Expression; Need(tkRP); ToReal(ExprType);
  If (Name='INT') Or (Name='FRAC') Then Begin
   If Name='INT' Then RealUnary(8) Else RealUnary(9); StandardFunction:=11; Exit;
  End;
  Emit($06); Emit($52); Emit($50); LoadImmediate(Ord(Name='ROUND')); Emit($50); RealCall('RTRUNC'); Emit($07);
  StandardFunction:=9; Exit;
 End;

 StandardFunction:=0;
 If Name='PARAMCOUNT' Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  CallTo(RuntimeStandard[31]); StandardFunction:=3;
 End Else If Name='PARAMSTR' Then Begin
  Need(tkLP); RequireInteger(Expression); Need(tkRP);
  CallTo(RuntimeStandard[32]); StandardFunction:=7;
 End Else If (Name='FILEPOS') Or (Name='FILESIZE') Then Begin
  Need(tkLP); T:=VariableArgument; If Types[T].Typ<>ttFile Then Fail(26,'FilePos/Size exige File');
  Need(tkRP); If Name='FILEPOS' Then LoadImmediate(0) Else LoadImmediate(1);
  CallTo(RuntimeStandard[38]); Emit($52); Emit($50); Emit2($09,$C9); Emit2($75,3); P:=Jump;
  Emit2($89,$C8); CallTo(RuntimeStandard[24]); PatchJump(P,CodeSize);
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]); Emit($58); Emit($5A); StandardFunction:=9;
 End Else If (Name='EOF') Or (Name='EOLN') Or (Name='SEEKEOF') Or (Name='SEEKEOLN') Then Begin
  ScopedInput:=False;
  If Token=tkLP Then Begin
   NextToken;
   Begin
    T:=VariableArgument;
    If (Types[T].Typ=ttFile) And (Name='EOF') Then Begin
     Need(tkRP); CallTo(RuntimeStandard[45]);
     If OptionBits And 1<>0 Then Begin Emit($50); CallTo(RuntimeStandard[25]); Emit($58) End;
     StandardFunction:=5; Exit;
    End;
    If Types[T].Typ<>ttText Then Fail(26,'Eof/Eoln exige Text');
    Emit2($89,$F8); Emit2($8C,$C2);
    CallTo(RuntimeStandard[41]); Emit($52); Emit($50); ScopedInput:=True;
   End;
   Need(tkRP);
  End;
  If Not ScopedInput Then Begin
   Emit($B8); DataAddress(StandardInputAddress); Emit2($8C,$DA);
   CallTo(RuntimeStandard[41]); Emit($52); Emit($50); ScopedInput:=True;
  End;
  P:=CodeSize;
  CallTo(RuntimeStandard[18]);
  If (Name='SEEKEOF') Or (Name='SEEKEOLN') Then Begin
   Emit($3D); EmitWord(26); Emit2($75,3); Q:=Jump;
   If Name='SEEKEOF' Then Begin Emit($3D); EmitWord(32); Emit2($76,3); A:=Jump End
   Else Begin
    Emit($3D); EmitWord(32); Emit2($74,8); Emit($3D); EmitWord(9); Emit2($74,3); A:=Jump;
   End;
   CallTo(RuntimeStandard[19]); JumpTo(P); PatchJump(A,CodeSize); PatchJump(Q,CodeSize);
  End;
  If (Name='EOF') Or (Name='SEEKEOF') Then Begin
   Emit($3D); EmitWord(26); LoadImmediate(1); Emit2($74,2); Emit2($31,$C0);
  End Else Begin
   Emit($3D); EmitWord(13); Emit2($75,3); P:=Jump;
   Emit($3D); EmitWord(10); Emit2($75,3); Q:=Jump;
   Emit($3D); EmitWord(26); LoadImmediate(1); Emit2($74,2); Emit2($31,$C0); A:=Jump;
   PatchJump(P,CodeSize); PatchJump(Q,CodeSize); LoadImmediate(1); PatchJump(A,CodeSize);
  End;
  If ScopedInput Then Begin
   Emit2($89,$C3); Emit($58); Emit($5A); Emit($53);
   CallTo(RuntimeStandard[41]); Emit($58);
  End;
  If OptionBits And 1<>0 Then Begin Emit($50); CallTo(RuntimeStandard[25]); Emit($58) End;
  StandardFunction:=5;
 End Else If (Name='MAXAVAIL') Or (Name='MEMAVAIL') Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  HeapNeeded:=True;
  If Name='MEMAVAIL' Then CallTo(RuntimeStandard[46]) Else CallTo(RuntimeStandard[33]);
  StandardFunction:=9;
 End Else If Name='IORESULT' Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  CallTo(RuntimeStandard[23]); StandardFunction:=3;
 End Else If (Name='ODD') Or (Name='SWAP') Or (Name='LO') Or (Name='HI') Or (Name='UPCASE') Then Begin
  Need(tkLP); T:=Expression; Need(tkRP);
  If Name='UPCASE' Then Begin
   If T<>ttChar Then Fail(106,'Caractere attendu');
   Emit2($3C,Ord('a')); Emit2($72,6); Emit2($3C,Ord('z')); Emit2($77,2); Emit2($2C,32);
   StandardFunction:=6;
  End Else Begin
   RequireInteger(T);
   If Name='ODD' Then Begin Emit($25); EmitWord(1); StandardFunction:=5 End
   Else If Name='SWAP' Then Begin Emit2($86,$C4); StandardFunction:=3 End
   Else Begin
    If Name='HI' Then Emit2($88,$E0); Emit2($30,$E4); StandardFunction:=2;
   End;
  End;
 End Else If (Name='CSEG') Or (Name='DSEG') Or (Name='SSEG') Or
             (Name='CSSEG') Or (Name='DSSEG') Or (Name='SSSEG') Or (Name='SPTR') Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  If (Name='CSEG') Or (Name='CSSEG') Then Emit2($8C,$C8) Else If (Name='DSEG') Or (Name='DSSEG') Then Emit2($8C,$D8)
  Else If (Name='SSEG') Or (Name='SSSEG') Then Emit2($8C,$D0) Else Emit2($89,$E0);
  StandardFunction:=3;
 End Else If (Name='TEST8086') Or (Name='TEST8087') Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  If Name='TEST8086' Then Begin
   { 0 = 8086/88, 1 = 80286, 2 = 80386 ou plus (methode de Turbo Pascal). }
   Emit($54); Emit($58); Emit2($39,$E0); Emit2($74,3); P:=Jump;     { push sp; pop ax; cmp ax,sp; jne 8086 }
   Emit($9C); Emit($58); Emit($0D); EmitWord($7000); Emit($50); Emit($9D);
   Emit($9C); Emit($58); Emit($25); EmitWord($7000); Emit2($75,3); Q:=Jump; { 286 si bits 12-14 nuls }
   LoadImmediate(2); A:=Jump;
   PatchJump(Q,CodeSize); LoadImmediate(1); T:=Jump;
   PatchJump(P,CodeSize); LoadImmediate(0); PatchJump(A,CodeSize); PatchJump(T,CodeSize);
  End Else If OptionBits And $80=0 Then LoadImmediate(0) { comme TP: 0 en $N- }
  Else Begin
   { bit 1 du mot d'equipement BIOS: coprocesseur present (3 = 80387) }
   Emit($06); LoadImmediate($40); Emit2($8E,$C0); Emit($26); Emit($A1); EmitWord($10); Emit($07);
   Emit($25); EmitWord(2); Emit2($74,3); LoadImmediate(3);
  End;
  StandardFunction:=2;
 End Else If Name='PTR' Then Begin
  Need(tkLP); RequireInteger(Expression); Emit($50); Need(tkComma);
  RequireInteger(Expression); Emit($5A); Need(tkRP); StandardFunction:=8;
 End Else If (Name='ADDR') Or (Name='OFS') Or (Name='SEG') Then Begin
  Need(tkLP); T:=VariableArgument; Need(tkRP);
  If Name='SEG' Then Emit2($8C,$C0)
  Else Begin Emit2($89,$F8); If Name='ADDR' Then Emit2($8C,$C2) End;
  If Name='ADDR' Then StandardFunction:=8 Else StandardFunction:=3;
 End Else If Name='COPY' Then Begin
  Need(tkLP); StringExpression; Emit($52); Emit($50); Need(tkComma);
  RequireInteger(Expression); Emit($50); Need(tkComma); RequireInteger(Expression);
  Emit2($89,$C1); Emit($58); Emit($5E); Emit($5A); Need(tkRP);
  A:=TempAlloc(256); Emit($1E); Emit2($8E,$DA); TempPointerDI(A,TempLocal);
  Emit($BB); EmitWord(255); CallTo(RuntimeStandard[1]); Emit($1F);
  TempPointerAX(A,TempLocal); StandardFunction:=7;
 End Else If Name='POS' Then Begin
  Need(tkLP); StringExpression; Emit($52); Emit($50); Need(tkComma); StringExpression;
  Emit2($89,$C7); Emit2($8E,$C2); Emit($5E); Emit($5A); Need(tkRP);
  Emit($1E); Emit2($8E,$DA); CallTo(RuntimeStandard[2]); Emit($1F); StandardFunction:=1;
 End Else If Name='CONCAT' Then Begin
  A:=TempAlloc(256); Lcl:=TempLocal; TempClear(A,Lcl); Need(tkLP);
  Repeat
   StringExpression; Emit($1E); Emit2($8E,$DA); Emit2($89,$C6);
   TempPointerDI(A,Lcl); Emit($BB); EmitWord(255);
   CallTo(RuntimeStandard[3]); Emit($1F);
   If Token<>tkComma Then Break; NextToken;
  Until False;
  Need(tkRP); TempPointerAX(A,Lcl); StandardFunction:=7;
 End Else If Name='RANDOM' Then Begin
  { Etat deterministe initial; Randomize utilise le tick DOS. }
  If Token<>tkLP Then Begin
   { Random: reel de [0,1) = Random(32768)/32768.0 }
   LoadImmediate(32768); Emit($50); RandomWord; ToReal(3); PushReal;
   RealPointer(StoreReal(32768.0)); RealBinary(11,11,4,False); StandardFunction:=11; Exit;
  End;
  NextToken; RequireInteger(Expression); Need(tkRP); Emit($50); RandomWord; StandardFunction:=3;
 End;
End;

Procedure FileTransferResult(Op,Count: Word);
Var P,Q,R: Word;
Begin
 Emit2($09,$D2); Emit2($74,3); P:=Jump;
 Emit($3D); EmitWord(Count); Emit2($75,3); Q:=Jump;
 LoadImmediate(100+Op); CallTo(RuntimeStandard[24]); R:=Jump;
 PatchJump(P,CodeSize); Emit2($89,$D0); CallTo(RuntimeStandard[24]);
 PatchJump(Q,CodeSize); PatchJump(R,CodeSize);
 If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
End;

Procedure BinaryFileWrite(FileType,ValueType: Word);
Var Element,N,A: Word;
Begin
 Element:=TypeExtras[FileType].ElementType;
 If (Types[Element].Typ=ttString) And (Types[ValueType].Typ=ttChar) Then Begin StringFromChar; ValueType:=7 End;
 If (Types[Element].Typ=ttReal) And (Types[ValueType].Typ=ttInteger) Then Begin ToReal(ValueType); ValueType:=11 End;
 If Not CompatibleTypes(Element,ValueType) Then Fail(26,'Type de valeur du fichier');
 If ExprKnown And (Types[Element].Typ In [ttInteger,ttChar,ttEnum,ttBoolean]) And
    ((ExprValue<Types[Element].LowBound) Or (ExprValue>Types[Element].HighBound)) Then Fail(76,'Valeur fichier hors limites');
 N:=0;
 If (OptionBits And 2<>0) And (Types[Element].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then
  RangeBounds(Types[Element].LowBound,Types[Element].HighBound,ValueType);
 If Types[Element].Typ=ttSet Then Begin
  A:=AllocData(32); NormalizeSet(ValueType,A); TrimSet(Element,A);
  Emit($B8); DataAddress(A+Types[Element].LowBound Div 8); Emit2($8C,$DA);
 End;
 If Types[Element].Typ=ttString Then Begin
  A:=AllocData(TypeExtras[Element].Size); Emit2($89,$C6); Emit($1E); Emit2($8E,$DA);
  CallTo(RuntimeStandard[71]); Emit($BF); DataAddress(A); LoadImmediate(1);
  Emit($BB); EmitWord(Types[Element].Capacity); Emit2($89,$D9); CallTo(RuntimeStandard[1]); Emit($1F);
  Emit($B8); DataAddress(A); Emit2($8C,$DA);
 End;
 If Types[Element].Typ In [ttArray,ttRecord,ttString,ttSet,ttReal] Then Begin
  Emit($1E); Emit2($8E,$DA); Emit2($89,$C2);
 End Else Begin
  If Types[Element].Width=4 Then Begin
   If Types[ValueType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
   Emit($52); N:=4;
  End Else N:=2;
  Emit($50); Emit2($89,$E2); Emit($1E); Emit($16); Emit($1F);
 End;
 Emit2($89,$E3); Emit($36); Emit2($8B,$7F); Emit(N+2);
 Emit($36); Emit2($8B,$47); Emit(N+4); Emit2($8E,$C0);
 Emit($B9); EmitWord(1); LoadImmediate(1); CallTo(RuntimeStandard[36]); Emit($1F);
 If N<>0 Then Begin Emit2($83,$C4); Emit(N) End;
 FileTransferResult(1,1);
End;

Function StandardProcedure(Name: TShortString): Boolean;
Var T,A,P,Q,R,Done,Op,N: Word; HasResult,FirstInput: Boolean; BinaryType: Word;
Begin
 StandardProcedure:=True;
 If Name='SETTEXTBUF' Then Begin
  Need(tkLP); T:=VariableArgument;
  If Types[T].Typ<>ttText Then Fail(26,'SetTextBuf exige Text');
  Emit($06); Emit($57); Need(tkComma); A:=VariableArgument;
  Emit($06); Emit($57);
  If Token=tkComma Then Begin NextToken; RequireInteger(Expression) End
  Else Begin If A=0 Then Fail(26,'Taille du buffer requise'); LoadImmediate(TypeExtras[A].Size) End;
  Need(tkRP); Emit2($89,$C1); Emit($58); Emit($5A); Emit($5F); Emit($07);
  CallTo(RuntimeStandard[51]); If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If Name='RUNERROR' Then Begin
  LoadImmediate(0);
  If Token=tkLP Then Begin NextToken; RequireInteger(Expression); Need(tkRP) End;
  CallTo(RuntimeStandard[47]);
 End Else If Name='GETDIR' Then Begin
  Need(tkLP); RequireInteger(Expression); Emit($50); Need(tkComma);
  T:=VariableArgument; If Types[T].Typ<>ttString Then Fail(26,'GetDir exige une chaine variable');
  Need(tkRP); Emit($58); Emit($06); Emit($57); CallTo(RuntimeStandard[44]);
  Emit($5F); Emit($07); Emit2($89,$C6); Emit($1E); Emit2($8E,$DA);
  LoadImmediate(1); Emit($B9); EmitWord(255); Emit($BB); EmitWord(Types[T].Capacity);
  CallTo(RuntimeStandard[1]); Emit($1F);
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If (Name='MKDIR') Or (Name='RMDIR') Or (Name='CHDIR') Then Begin
  Need(tkLP); StringExpression; Need(tkRP);
  A:=AllocData(256); Emit($1E); Emit($06); Emit2($89,$C6); Emit2($8E,$DA);
  CallTo(RuntimeStandard[71]); Emit($BF); DataAddress(A); Emit2($31,$C9); Emit($AC);
  Emit2($88,$C1); Emit2($F3,$A4); Emit2($31,$C0); Emit($AA); Emit($07); Emit($1F);
  Emit($BA); DataAddress(A);
  If Name='MKDIR' Then Op:=$39 Else If Name='RMDIR' Then Op:=$3A Else Op:=$3B;
  Emit2($B4,Op); CallTo(RuntimeStandard[43]);
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If Name='RENAME' Then Begin
  Need(tkLP); T:=VariableArgument;
  If Not (Types[T].Typ In [ttFile,ttText]) Then Fail(26,'Variable fichier attendue');
  Emit($06); Emit($57); Need(tkComma); StringExpression; Need(tkRP);
  Emit2($89,$C6); Emit($1E); Emit2($8E,$DA); Emit($5B); { ancienne DS }
  Emit($5F); Emit($07); Emit($53); CallTo(RuntimeStandard[42]); Emit($1F);
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If Name='ASSIGN' Then Begin
  Need(tkLP); T:=VariableArgument;
  If Not (Types[T].Typ In [ttFile,ttText]) Then Fail(26,'Variable fichier attendue');
  Emit($06); Emit($57); Need(tkComma); StringExpression; Need(tkRP);
  Emit($5F); Emit($07); Emit2($89,$C6); Emit($1E); Emit2($8E,$DA);
  A:=TypeExtras[T].ElementType;
  If Types[T].Typ=ttText Then Begin A:=1; LoadImmediate(1) End
  Else Begin If A=0 Then A:=128 Else A:=TypeExtras[A].Size; LoadImmediate(0) End;
  Emit($BB); EmitWord(A); CallTo(RuntimeStandard[34]); Emit($1F);
 End Else If (Name='RESET') Or (Name='REWRITE') Or (Name='APPEND') Or (Name='CLOSE') Or
             (Name='ERASE') Or (Name='FLUSH') Or (Name='TRUNCATE') Then Begin
  Need(tkLP); T:=VariableArgument;
  If Not (Types[T].Typ In [ttFile,ttText]) Then Fail(26,'Variable fichier attendue');
  If ((Name='APPEND') Or (Name='FLUSH')) And (Types[T].Typ<>ttText) Then Fail(26,'Fichier Text attendu');
  If (Name='TRUNCATE') And (Types[T].Typ<>ttFile) Then Fail(26,'Truncate exige File');
  If Token=tkComma Then Begin
   If Not ((Name='RESET') Or (Name='REWRITE')) Or (Types[T].Typ<>ttFile) Or
      (TypeExtras[T].ElementType<>0) Then Fail(26,'Taille record reservee au File sans type');
   Emit($06); Emit($57); NextToken; RequireInteger(Expression);
   If ExprKnown And ((ExprValue<1) Or (ExprValue>65535)) Then Fail(76,'Taille record hors limites');
   Emit2($89,$C3); Emit($5F); Emit($07);
  End Else Begin Emit($BB); EmitWord(0) End;
  Need(tkRP); Op:=1;
  If Name='REWRITE' Then Op:=2 Else If Name='APPEND' Then Op:=3 Else If Name='CLOSE' Then Op:=4
  Else If Name='ERASE' Then Op:=5 Else If Name='FLUSH' Then Op:=6 Else If Name='TRUNCATE' Then Op:=7;
  LoadImmediate(Op); CallTo(RuntimeStandard[35]); If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If Name='SEEK' Then Begin
  Need(tkLP); T:=VariableArgument; If Types[T].Typ<>ttFile Then Fail(26,'Seek exige File');
  Emit($06); Emit($57); Need(tkComma); RequireInteger(Expression);
  If ExprKnown And (ExprValue<0) Then Fail(76,'Position Seek negative');
  If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
  Need(tkRP); Emit($5F); Emit($07); CallTo(RuntimeStandard[37]); If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If (Name='BLOCKREAD') Or (Name='BLOCKWRITE') Then Begin
  Need(tkLP); T:=VariableArgument; If Types[T].Typ<>ttFile Then Fail(26,'BlockRead/Write exige File');
  Emit($06); Emit($57); Need(tkComma); A:=VariableArgument; Emit($06); Emit($57);
  Need(tkComma); RequireInteger(Expression);
  If ExprKnown And ((ExprValue<0) Or (ExprValue>65535)) Then Fail(76,'Nombre records hors limites');
  Emit($50); HasResult:=Token=tkComma;
  If HasResult Then Begin
   NextToken; A:=VariableArgument;
   If (Types[A].Typ<>ttInteger) Or (Types[A].Width<>2) Then Fail(26,'Resultat transfert doit etre Word/Integer');
   Emit($06); Emit($57);
  End Else Begin Emit2($31,$D2); Emit($52); Emit($52) End;
  Need(tkRP); Emit($55); Emit2($89,$E5); Emit($1E);
  Emit2($8B,$46); Emit(10); Emit2($8E,$D8); Emit2($8B,$56); Emit(8);
  Emit2($8B,$46); Emit(14); Emit2($8E,$C0); Emit2($8B,$7E); Emit(12);
  Emit2($8B,$4E); Emit(6);
  Op:=0; If Name='BLOCKWRITE' Then Op:=1; LoadImmediate(Op); CallTo(RuntimeStandard[36]); Emit($1F);
  Emit($50); Emit2($09,$D2); Emit2($74,3); P:=Jump;
  If Not HasResult Then Begin
   Emit2($3B,$46); Emit(6); Emit2($75,3); Q:=Jump;
   LoadImmediate(100+Op); CallTo(RuntimeStandard[24]); R:=Jump;
   PatchJump(Q,CodeSize);
  End Else R:=Jump;
  Done:=Jump; PatchJump(P,CodeSize); Emit2($89,$D0); CallTo(RuntimeStandard[24]);
  PatchJump(R,CodeSize); PatchJump(Done,CodeSize); Emit($58);
  If HasResult Then Begin Emit2($C4,$7E); Emit(2); Emit($26); Emit2($89,$05) End;
  Emit2($89,$EC); Emit($5D); Emit2($83,$C4); Emit(14);
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If (Name='NEW') Or (Name='GETMEM') Or (Name='MARK') Then Begin
  HeapNeeded:=True; Need(tkLP); T:=VariableArgument;
  If Types[T].Typ<>ttPointer Then Fail(26,'Variable pointeur attendue');
  Emit($06); Emit($57);
  If Name='NEW' Then Begin
   A:=TypeExtras[T].ElementType; If A=0 Then Fail(26,'New exige un pointeur type');
   LoadImmediate(TypeExtras[A].Size); CallTo(RuntimeStandard[26]);
  End Else If Name='GETMEM' Then Begin
   Need(tkComma); RequireInteger(Expression);
   If ExprKnown And ((ExprValue<0) Or (ExprValue>65535)) Then Fail(76,'Taille GetMem hors limites');
   CallTo(RuntimeStandard[26]);
  End Else CallTo(RuntimeStandard[29]);
  Need(tkRP); Emit($5F); Emit($07); StoreDesignator(T);
 End Else If (Name='DISPOSE') Or (Name='FREEMEM') Or (Name='RELEASE') Then Begin
  HeapNeeded:=True; Need(tkLP); A:=Expression;
  If A<>ttPointer Then Fail(26,'Pointeur attendu');
  If Name='FREEMEM' Then Begin
   Emit($52); Emit($50); Need(tkComma); RequireInteger(Expression);
   Emit2($89,$C3); Emit($58); Emit($5A); Emit($BE); EmitWord(1);
  End Else Emit2($31,$F6);
  Need(tkRP);
  If Name='RELEASE' Then CallTo(RuntimeStandard[30]) Else CallTo(RuntimeStandard[27]);
 End Else If (Name='READ') Or (Name='READLN') Then Begin
  CallTo(RuntimeStandard[76]); { ReadBegin }
  FirstInput:=True; BinaryType:=0;
  If Token=tkLP Then Begin
   NextToken;
   If (Token=tkIdent) And (TokenText='INPUT') And (FindLexicalSymbol('INPUT')=0) Then Begin
    NextToken; FirstInput:=False; If Token=tkComma Then NextToken;
   End;
   While Token<>tkRP Do Begin
    T:=VariableArgument;
    If FirstInput And (Types[T].Typ In [ttFile,ttText]) Then Begin
     If Types[T].Typ=ttText Then Begin
      Emit2($89,$F8); Emit2($8C,$C2); CallTo(RuntimeStandard[41]);
      If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
     End Else Begin
      If (Name='READLN') Or (TypeExtras[T].ElementType=0) Then Fail(26,'Read exige File type, ReadLn exige Text');
      BinaryType:=T; Emit($06); Emit($57);
     End;
    End Else If BinaryType<>0 Then Begin
     A:=TypeExtras[BinaryType].ElementType;
     If Not CompatibleTypes(T,A) Or (TypeExtras[T].Size<>TypeExtras[A].Size) Then Fail(26,'Variable du fichier incompatible');
     Emit2($89,$F8); Emit2($8C,$C2); Emit($1E); Emit2($8E,$DA); Emit2($89,$C2);
     Emit2($89,$E3); Emit($36); Emit2($8B,$7F); Emit(2);
     Emit($36); Emit2($8B,$47); Emit(4); Emit2($8E,$C0);
     Emit($B9); EmitWord(1); LoadImmediate(0); CallTo(RuntimeStandard[36]); Emit($1F);
     FileTransferResult(0,1);
    End Else Begin
     Emit($06); Emit($57);
     Case Types[T].Typ Of
      ttReal:Begin
       CallTo(RuntimeStandard[20]); Emit2($8C,$DA); RealParseText;
       Emit($52); Emit($50);
       Emit2($09,$C9); Emit2($74,3); P:=Jump; Q:=Jump;
       PatchJump(P,CodeSize); LoadImmediate(106); CallTo(RuntimeStandard[24]);
       PatchJump(Q,CodeSize); Emit($58); Emit($5A);
      End;
      ttChar:CallTo(RuntimeStandard[19]);
      ttString:Begin Emit($BB); EmitWord(Types[T].Capacity); CallTo(RuntimeStandard[21]) End;
      ttArray:Begin
       { tableau de Char a base zero ($X+): chaine lue (DX:AX) copiee avec zero terminal }
       If Not (IsCharArray(T) And ExtendedSyntax) Then Fail(26,'Type non lisible');
       N:=TypeExtras[T].Size-1; If N>255 Then N:=255;
       Emit($BB); EmitWord(N); CallTo(RuntimeStandard[21]);
      End;
      ttInteger:Begin
       CallTo(RuntimeStandard[20]); Emit2($89,$C6); CallTo(RuntimeStandard[17]);
       Emit2($09,$C9); Emit2($74,3); P:=Jump; Q:=0; R:=0; A:=0;
       If Types[T].Width<>4 Then Begin
        If Types[T].Signed Then Begin Emit2($89,$C3); Emit2($B1,15); Emit2($D3,$FB) End
        Else Emit2($31,$DB);
        Emit2($39,$DA); Emit2($74,3); Q:=Jump;
        If Types[T].Width=1 Then Begin
         Emit($3D); EmitWord(Word(Types[T].LowBound));
         If Types[T].Signed Then Emit2($7D,3) Else Emit2($73,3); R:=Jump;
         Emit($3D); EmitWord(Word(Types[T].HighBound));
         If Types[T].Signed Then Emit2($7E,3) Else Emit2($76,3); A:=Jump;
        End;
       End;
       Done:=Jump; PatchJump(P,CodeSize); If Q<>0 Then PatchJump(Q,CodeSize);
       If R<>0 Then PatchJump(R,CodeSize); If A<>0 Then PatchJump(A,CodeSize);
       LoadImmediate(106); CallTo(RuntimeStandard[24]); Emit2($31,$C0); Emit2($31,$D2);
       PatchJump(Done,CodeSize);
      End;
     Else Fail(26,'Type non lisible');
     End;
     Emit($5F); Emit($07);
     If Types[T].Typ=ttReal Then Begin
      Emit($1E); Emit2($8E,$DA); Emit2($89,$C6); Emit($B9); EmitWord(6); Emit2($F3,$A4); Emit($1F);
     End Else If Types[T].Typ=ttString Then Begin
      Emit2($89,$C6); Emit2($31,$C9); Emit2($8A,$0C); Emit($41); Emit2($F3,$A4);
     End Else If Types[T].Typ=ttArray Then Begin
      Emit2($89,$C6); Emit2($31,$C9); Emit2($8A,$0C); Emit($46); Emit2($F3,$A4); Emit2($30,$C0); Emit($AA);
     End Else StoreDesignator(T);
     If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
    End;
    FirstInput:=False;
    If Token<>tkComma Then Break; NextToken;
   End;
   Need(tkRP);
  End Else If Name='READ' Then Fail(88,'Parametres Read manquants');
  If BinaryType<>0 Then Begin Emit2($83,$C4); Emit(4) End;
  If Name='READLN' Then CallTo(RuntimeStandard[78]) Else CallTo(RuntimeStandard[77]); { ReadLnEnd / ReadEnd }
  If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
 End Else If (Name='INC') Or (Name='DEC') Then Begin
  Need(tkLP);
  If Token=tkIdent Then T:=FindLexicalSymbol(TokenText) Else T:=0;
  If (T<>0) And SimpleScalar(T) And (OptionBits And $8002=0) And (Types[SymbolType(T)].Width<=2) And
     (Types[SymbolType(T)].Typ<>ttPointer) And
     (Not Symbols[T].Local Or (RealScope(Symbols[T].Scope)=RealScope(CurrentScope))) Then Begin
   { inc/dec/add/sub directement en memoire }
   NextToken; A:=Types[SymbolType(T)].Width; P:=0;
   If Token=tkComma Then Begin
    NextToken; RequireInteger(Expression);
    If (CodeSize>=3) And (Image[CodeSize-3]=$B8) Then Begin
     Q:=Image[CodeSize-2]+Word(Image[CodeSize-1])*256; CodeSize:=CodeSize-3; P:=2;
    End Else P:=1;
   End;
   Need(tkRP);
   If P=0 Then Begin
    If A=1 Then Emit($FE) Else Emit($FF);
    If Name='INC' Then Op:=0 Else Op:=1;
   End Else If P=2 Then Begin
    If A=1 Then Emit($80) Else If (Q<128) Or (Q>=65408) Then Emit($83) Else Emit($81);
    If Name='INC' Then Op:=0 Else Op:=5;
   End Else Begin
    If A=1 Then Begin If Name='INC' Then Emit($00) Else Emit($28) End
    Else Begin If Name='INC' Then Emit($01) Else Emit($29) End;
    Op:=0;
   End;
   If Symbols[T].Local Then EmitBP(Op,SmallInt(Symbols[T].Addr))
   Else Begin Emit($06 Or (Op Shl 3)); DataAddress(Symbols[T].Addr) End;
   If P=2 Then Begin
    If (A=1) Or (Q<128) Or (Q>=65408) Then Emit(Q And 255) Else EmitWord(Q);
   End;
   Exit;
  End;
  T:=VariableArgument;
  If Types[T].Typ=ttPointer Then Begin
   { Inc/Dec d'un pointeur modifie l'offset seulement. }
   Emit($06); Emit($57); LoadDesignator(T);
   If Token=tkComma Then Begin
    Emit($52); Emit($50); NextToken; RequireInteger(Expression);
    Emit2($89,$C3); Emit($58); Emit($5A);
    If Name='INC' Then Emit2($01,$D8) Else Emit2($29,$D8);
   End Else If Name='INC' Then Emit($40) Else Emit($48);
   Need(tkRP); Emit($5F); Emit($07); StoreDesignator(T);
   Exit;
  End;
  If Not (Types[T].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(104,'Variable ordinale attendue');
  Emit($06); Emit($57); LoadDesignator(T);
  If Token=tkComma Then Begin
   If Types[T].Width=4 Then Emit($52); Emit($50); NextToken; RequireInteger(Expression);
   If Types[T].Width=4 Then Begin
    If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
    Emit2($89,$D1);
   End;
   Emit2($89,$C3); Emit($58); If Types[T].Width=4 Then Emit($5A);
   If Name='INC' Then Begin Emit2($01,$D8); If Types[T].Width=4 Then Emit2($11,$CA) End
   Else Begin Emit2($29,$D8); If Types[T].Width=4 Then Emit2($19,$CA) End;
  End Else If Name='INC' Then Begin
   Emit($05); EmitWord(1); If Types[T].Width=4 Then Begin Emit2($83,$D2); Emit(0) End;
  End Else Begin
   Emit($2D); EmitWord(1); If Types[T].Width=4 Then Begin Emit2($83,$DA); Emit(0) End;
  End;
  Need(tkRP); Emit($5F); Emit($07);
  If (Types[T].Width=2) And (OptionBits And 2=0) Then OverflowCheck(Not Types[T].Signed);
  If OptionBits And 2<>0 Then Begin
   If Types[T].Width>=2 Then Begin
    If Types[T].Signed Then Emit2($71,3) Else Emit2($73,3); P:=Jump; Q:=Jump;
    PatchJump(P,CodeSize); LoadImmediate(201); CallTo(RuntimeError); PatchJump(Q,CodeSize);
   End;
   If Types[T].Width=1 Then A:=1 Else A:=T;
   RangeBounds(Types[T].LowBound,Types[T].HighBound,A);
  End;
  StoreDesignator(T);
 End Else If (Name='INCLUDE') Or (Name='EXCLUDE') Then Begin
  { TP 7.0: Include(S,X) / Exclude(S,X) sur le bitmap ES:DI de l'ensemble. }
  Need(tkLP); T:=VariableArgument;
  If Types[T].Typ<>ttSet Then Fail(26,'Variable ensemble attendue');
  Emit($06); Emit($57); Need(tkComma); Op:=Expression;
  If Not (Op In [ttInteger,ttChar,ttBoolean,ttEnum]) Or (Types[ExprType].Width=4) Then Fail(39,'');
  If (TypeExtras[T].ElementType<>0) And Not CompatibleTypes(ExprType,TypeExtras[T].ElementType) Then
   Fail(26,'Type de l''element');
  Need(tkRP); Emit($5F); Emit($07);
  Emit($2D); EmitWord(Types[T].LowBound Div 8*8);
  Emit($3D); EmitWord(TypeExtras[T].Size*8); Emit2($72,3); P:=Jump;
  Emit2($89,$C3); Emit2($89,$C1); Emit2($80,$E1); Emit(7);
  Emit($BA); EmitWord(1); Emit2($D3,$E2); Emit2($B1,3); Emit2($D3,$EB);
  If Name='INCLUDE' Then Begin Emit($26); Emit2($08,$11) End
  Else Begin Emit2($F6,$D2); Emit($26); Emit2($20,$11) End;
  PatchJump(P,CodeSize);
 End Else If Name='RANDOMIZE' Then Begin
  If Token=tkLP Then Begin NextToken; Need(tkRP) End;
  Emit2($B4,$2C); Emit2($CD,$21); Emit2($89,$D0); Emit($A3); DataAddress(RandomSeed);
  Emit2($89,$0E); DataAddress(RandomSeed+2);
 End Else If Name='STR' Then Begin
  Need(tkLP); T:=Expression;
  If T=ttReal Then Begin
   RealText; Emit($52); Emit($50); Need(tkComma); T:=VariableArgument;
   If Types[T].Typ<>ttString Then Fail(66,'Destination Str non string'); Need(tkRP);
   Emit($5E); Emit($5A); Emit($1E); Emit2($8E,$DA); Emit2($31,$C9); Emit2($8A,$0C);
   Emit($BB); EmitWord(Types[T].Capacity); Emit2($39,$D9); Emit2($76,2); Emit2($89,$D9);
   Emit($26); Emit2($88,$0D); Emit($47); Emit($46); Emit2($F3,$A4); Emit($1F);
  End Else Begin
  RequireInteger(T);
  If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
  Emit($52); Emit($50);
  If Token=tkColon Then Begin NextToken; RequireInteger(Expression) End Else LoadImmediate(0);
  Emit($50); Need(tkComma); T:=VariableArgument;
  If Types[T].Typ<>ttString Then Fail(66,'Destination Str non string'); Need(tkRP);
  Emit($59); Emit($58); Emit($5A); Emit($51); Emit($06); Emit($57); CallTo(RuntimeStandard[16]);
  Emit($5F); Emit($07); Emit($59); Emit2($89,$C6); Emit($BB); EmitWord(Types[T].Capacity);
  Emit2($09,$C9); Emit2($79,2); Emit2($31,$C9);
  Emit2($39,$D9); Emit2($76,2); Emit2($89,$D9);
  Emit2($31,$D2); Emit2($8A,$14); Emit2($39,$DA); Emit2($76,2); Emit2($89,$DA);
  Emit2($39,$D1); Emit2($73,2); Emit2($89,$D1); Emit2($89,$CB);
  Emit($26); Emit2($88,$1D); Emit($47); Emit2($29,$D1); LoadImmediate(32); Emit2($F3,$AA);
  Emit2($89,$D1); Emit($46); Emit2($F3,$A4);
  End;
 End Else If Name='VAL' Then Begin
  Need(tkLP); StringExpression; Emit($52); Emit($50); Need(tkComma);
  T:=VariableArgument; If Not (Types[T].Typ In [ttInteger,ttReal]) Then Fail(38,'Destination Val non numerique');
  Emit($06); Emit($57); Need(tkComma); A:=VariableArgument;
  If (Types[A].Typ<>ttInteger) Or (Types[A].Width<>2) Then Fail(26,'Code Val doit etre Integer ou Word');
  Emit($06); Emit($57); Need(tkRP); Emit($55); Emit2($89,$E5);
  If Types[T].Typ=ttReal Then Begin
   EnsureRealRuntime; Emit($06);
   Emit2($FF,$76); Emit(12); Emit2($FF,$76); Emit(10);
   Emit2($FF,$76); Emit(8); Emit2($FF,$76); Emit(6);
   Emit2($FF,$76); Emit(4); Emit2($FF,$76); Emit(2); RealCall('RPARSE'); Emit($07);
  End Else Begin
  Emit($1E);
  Emit2($8B,$46); Emit(12); Emit2($8E,$D8); Emit2($8B,$76); Emit(10);
  CallTo(RuntimeStandard[17]); Emit($1F);
  If Types[T].Width<>4 Then Begin
   If Types[T].Signed Then Begin
    Emit2($89,$C3); Emit($51); Emit2($B1,15); Emit2($D3,$FB); Emit($59);
   End Else Emit2($31,$DB);
   Emit2($39,$DA); Emit2($74,3); P:=Jump; Q:=0; R:=0;
   If Types[T].Width=1 Then Begin
    Emit($3D); EmitWord(Word(Types[T].LowBound));
    If Types[T].Signed Then Emit2($7D,3) Else Emit2($73,3); Q:=Jump;
    Emit($3D); EmitWord(Word(Types[T].HighBound));
    If Types[T].Signed Then Emit2($7E,3) Else Emit2($76,3); R:=Jump;
   End;
   Done:=Jump; PatchJump(P,CodeSize);
   If Q<>0 Then PatchJump(Q,CodeSize); If R<>0 Then PatchJump(R,CodeSize);
   Emit($B9); EmitWord(1); PatchJump(Done,CodeSize);
  End;
  Emit2($C4,$7E); Emit(2); Emit($26); Emit2($89,$0D);
  Emit2($C4,$7E); Emit(6); StoreDesignator(T);
  End;
  Emit2($89,$EC); Emit($5D); Emit2($83,$C4); Emit(12);
 End Else If Name='DELETE' Then Begin
  Need(tkLP); T:=VariableArgument;
  If Types[T].Typ<>ttString Then Fail(66,'Chaine variable attendue');
  Emit($06); Emit($57); Need(tkComma); RequireInteger(Expression); Emit($50);
  Need(tkComma); RequireInteger(Expression); Emit2($89,$C1);
  Emit($58); Emit($5F); Emit($07); Need(tkRP); CallTo(RuntimeStandard[4]);
 End Else If Name='INSERT' Then Begin
  Need(tkLP); StringExpression; Emit($52); Emit($50); Need(tkComma);
  T:=VariableArgument; If Types[T].Typ<>ttString Then Fail(66,'Chaine variable attendue');
  Emit($06); Emit($57); Need(tkComma); RequireInteger(Expression); Need(tkRP);
  Emit($5F); Emit($07); Emit($5E); Emit($5A);
  Emit($1E); Emit2($8E,$DA); Emit($BB); EmitWord(Types[T].Capacity);
  CallTo(RuntimeStandard[5]); Emit($1F);
 End Else If Name='FILLCHAR' Then Begin
  Need(tkLP); T:=VariableArgument; Emit($06); Emit($57);
  Need(tkComma); RequireInteger(Expression); Emit($50);
  Need(tkComma); RequireOrdinal(Expression); Need(tkRP);
  Emit($59); Emit($5F); Emit($07); Emit2($09,$C9); Emit2($79,2); Emit2($31,$C9); Emit2($F3,$AA);
 End Else If Name='MOVE' Then Begin
  Need(tkLP); T:=VariableArgument; Emit($06); Emit($57);
  Need(tkComma); T:=VariableArgument; Emit($06); Emit($57);
  Need(tkComma); RequireInteger(Expression); Need(tkRP);
  Emit2($89,$C1); Emit($5F); Emit($07); Emit($5E); Emit($5A);
  Emit($1E); Emit2($8E,$DA); CallTo(RuntimeStandard[12]); Emit($1F);
 End Else StandardProcedure:=False;
End;

Procedure AssignToDesignator(Dest: Word); Forward;
Procedure Assignment(I: Word);
Var
 T: Byte; Dest,SourceType,SourceBuffer: Word;
Begin
 If Symbols[I].Kind<>skVar Then Fail(43,'Variable attendue');
 If SimpleScalar(I) And (Token=tkAssign) Then Begin
  { Variable scalaire simple: expression puis MOV direct. }
  Dest:=SymbolType(I); NextToken; T:=Expression;
  If IsCharPointer(Dest) And ExtendedSyntax Then Begin
   If ExprLiteral Then Begin LiteralToPChar; T:=ttPointer End
   Else If (T=ttArray) And IsCharArray(ExprType) Then Begin T:=ttPointer; ExprType:=12 End;
  End;
  SourceType:=ExprType;
  If (OptionBits And 2<>0) And (Types[Dest].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then
   RangeBounds(Types[Dest].LowBound,Types[Dest].HighBound,SourceType);
  If Not CompatibleTypes(Dest,SourceType) Then Fail(26,'Identite du type');
  If ExprKnown And (Types[Dest].Typ<>ttPointer) Then
   If (ExprValue<Types[Dest].LowBound) Or (ExprValue>Types[Dest].HighBound) Then Fail(76,'Affectation constante hors limites');
  If (Types[Dest].Width=4) And (Types[SourceType].Width<>4) Then Begin
   If ExprUnsigned Then Emit2($31,$D2) Else Emit($99);
  End;
  StoreScalar(I); Exit;
 End;
 Dest:=Designator(I); AssignToDesignator(Dest);
End;

Procedure AssignToDesignator(Dest: Word);
{ ES:DI = adresse de la destination de type Dest; ":= expression" suit. }
Var
 T: Byte; SourceType,SourceBuffer,N: Word;
Begin
 Emit($06); Emit($57);
 If Dest=0 Then Fail(26,'Affectation a une variable sans type');
 If Types[Dest].Typ In [ttFile,ttText] Then Fail(26,'Un fichier ne peut pas etre affecte');
 Need(tkAssign); T:=Expression;
 If IsCharPointer(Dest) And ExtendedSyntax Then Begin
  If ExprLiteral Then Begin LiteralToPChar; T:=ttPointer End
  Else If (T=ttArray) And IsCharArray(ExprType) Then Begin T:=ttPointer; ExprType:=12 End;
 End;
 SourceType:=ExprType; Emit($5F); Emit($07);
 If (OptionBits And 2<>0) And (Types[Dest].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then
  RangeBounds(Types[Dest].LowBound,Types[Dest].HighBound,SourceType);
 If Types[Dest].Typ=ttString Then Begin
  If T=ttChar Then Begin
   Emit($26); Emit2($88,$45); Emit(1);
   Emit($26); Emit2($C6,$05); Emit(1);
  End Else If T=ttString Then Begin
   CallTo(RuntimeStandard[81]); EmitWord(Types[Dest].Capacity); { StringAssign ES:DI := DX:AX }
  End Else Fail(26,'Chaine attendue');
 End Else If Types[Dest].Typ=ttSet Then Begin
  If Not CompatibleTypes(Dest,SourceType) Then Fail(26,'Affectation set incompatible');
  Emit($06); Emit($57); SourceBuffer:=AllocData(32); NormalizeSet(SourceType,SourceBuffer);
  TrimSet(Dest,SourceBuffer);
  Emit($5F); Emit($07); Emit($BE); DataAddress(SourceBuffer+Types[Dest].LowBound Div 8);
  Emit($B9); EmitWord(TypeExtras[Dest].Size); Emit2($F3,$A4);
 End Else If Types[Dest].Typ=ttReal Then Begin
  ToReal(SourceType); Emit($1E); Emit2($8E,$DA); Emit2($89,$C6); Emit($B9); EmitWord(6); Emit2($F3,$A4); Emit($1F);
 End Else If (Types[Dest].Typ=ttArray) And (TypeExtras[Dest].ElementType=6) And (T In [ttString,ttChar]) Then Begin
  { tableau de Char := constante chaine de meme longueur (TP), ou plus courte
    avec zero terminal pour un tableau a base zero ($X+) }
  If Not ExprLiteral Then Fail(26,'Longueur de la chaine');
  N:=Length(ExprLiteralText);
  If (N<>TypeExtras[Dest].Size) And Not (IsCharArray(Dest) And ExtendedSyntax And (N<TypeExtras[Dest].Size)) Then
   Fail(26,'Longueur de la chaine');
  If T=ttChar Then Begin
   Emit($26); Emit2($88,$05);
   If N<TypeExtras[Dest].Size Then Begin Emit($26); Emit2($C6,$45); Emit(1); Emit(0) End;
  End Else Begin
   Emit($1E); Emit2($8E,$DA); Emit2($89,$C6); Emit($46);
   Emit($B9); EmitWord(N); Emit2($F3,$A4);
   If N<TypeExtras[Dest].Size Then Begin Emit2($30,$C0); Emit($AA) End;
   Emit($1F);
  End;
 End Else If Types[Dest].Typ In [ttArray,ttRecord] Then Begin
  If Not CompatibleTypes(Dest,SourceType) Then Fail(26,'Affectation structuree incompatible');
  Emit($1E); Emit2($8E,$DA); Emit2($89,$C6);
  Emit($B9); EmitWord(TypeExtras[Dest].Size); Emit2($F3,$A4); Emit($1F);
 End Else
 Begin
  If Not CompatibleTypes(Dest,SourceType) Then Fail(26,'Identite du type');
  If ExprKnown And (Types[Dest].Typ<>ttPointer) Then
   If (ExprValue<Types[Dest].LowBound) Or
       (ExprValue>Types[Dest].HighBound) Then Fail(76,'Affectation constante hors limites');
  If (Types[Dest].Width=4) And (Types[SourceType].Width<>4) Then Begin
   If ExprUnsigned Then Emit2($31,$D2) Else Emit($99);
  End;
  StoreDesignator(Dest);
 End;
End;


Procedure RealText;
Var A: Word; L: Boolean;
Begin
 EnsureRealRuntime; A:=TempAlloc(256); L:=TempLocal;
 Emit($06); Emit($52); Emit($50);
 If Token=tkColon Then Begin
  NextToken; RequireInteger(Expression); Emit($50);
  If Token=tkColon Then Begin NextToken; RequireInteger(Expression) End Else LoadImmediate($FFFF);
 End Else Begin LoadImmediate(0); Emit($50); LoadImmediate($FFFF) End;
 Emit($50);
 If L Then Begin Emit($16); Emit2($8D,$86); EmitWord(A) End
 Else Begin Emit($1E); Emit($B8); DataAddress(A) End;
 Emit($50);
 { Rearrange width/digits and the saved real pointer into Pascal arguments. }
 Emit($58); Emit($5A); Emit($59); Emit($5B); Emit($5E); Emit($5F);
 Emit($57); Emit($56); Emit($51); Emit($53); Emit($52); Emit($50);
 RealCall('RFORMAT'); Emit($07);
 TempPointerAX(A,L);
End;
Procedure WriteStatement(NewLine: Boolean);
Var T: Byte; P,Q,A,B,BinaryType,FileType: Word; First: Boolean;
Begin
 CallTo(RuntimeStandard[73]); { WriteBegin: selection de Output, contexte empile }
 BinaryType:=0; First:=True;
 If Token=tkLP Then Begin
  NextToken;
  If (Token=tkIdent) And (TokenText='OUTPUT') And (FindLexicalSymbol('OUTPUT')=0) Then Begin
   NextToken; If Token=tkComma Then NextToken;
  End;
  While Token<>tkRP Do Begin
   T:=Expression;
   If (T=ttReal) And (BinaryType=0) Then Begin RealText; T:=ttString; ExprType:=7 End;
   If First And (T In [ttFile,ttText]) Then Begin
    FileType:=ExprType; First:=False;
    If T=ttFile Then Begin
     If NewLine Or (TypeExtras[FileType].ElementType=0) Then Fail(26,'Write exige File type, WriteLn exige Text');
     BinaryType:=FileType; Emit($52); Emit($50);
    End Else Begin
     Emit2($89,$C7); Emit2($8E,$C2);
     CallTo(RuntimeStandard[49]);
     Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); Emit2($74,3); P:=Jump;
     Emit($26); Emit2($83,$7D); Emit(4); Emit(0); Emit2($75,3); Q:=Jump;
     Emit($26); Emit2($83,$7D); Emit(4); Emit(1); Emit2($75,3); A:=Jump;
     Emit($26); Emit2($8B,$05); CallTo(RuntimeStandard[40]); B:=Jump;
     PatchJump(P,CodeSize); LoadImmediate(105); P:=Jump; { non assigne: 105 comme TP }
     PatchJump(Q,CodeSize); LoadImmediate(103); Q:=Jump;
     PatchJump(A,CodeSize); LoadImmediate(105); PatchJump(P,CodeSize); PatchJump(Q,CodeSize);
     CallTo(RuntimeStandard[24]); PatchJump(B,CodeSize);
     If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
    End;
   End Else Begin
    First:=False;
    If BinaryType<>0 Then Begin
     If Token=tkColon Then Fail(26,'Format interdit dans File type');
     BinaryFileWrite(BinaryType,ExprType);
    End Else Begin
  If Token=tkColon Then Begin
   Case T Of
    ttInteger:Begin
     If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End;
     CallTo(RuntimeStandard[16]);
    End;
    ttChar:StringFromChar;
    ttBoolean:Begin
     A:=StoreString('TRUE'); B:=StoreString('FALSE'); P:=JumpZero;
     Emit($B8); DataAddress(A); Q:=Jump; PatchJump(P,CodeSize);
     Emit($B8); DataAddress(B); PatchJump(Q,CodeSize); Emit2($8C,$DA);
    End;
    ttString:;
   Else Unsupported('type non imprimable');
   End;
   Emit($52); Emit($50); NextToken; RequireInteger(Expression);
   If Token=tkColon Then Unsupported('precision de champ non reelle');
   Emit2($89,$C1); Emit($58); Emit($5A); Emit($1E); Emit2($8E,$DA); Emit2($89,$C6);
   Emit2($31,$DB); Emit2($8A,$1C); Emit2($89,$C8); Emit2($29,$D8);
   Emit2($7F,2); Emit2($31,$C0); Emit2($89,$C1); Emit2($09,$C9); Emit2($75,3); P:=Jump;
   Q:=CodeSize; LoadImmediate(32); CallTo(RuntimeChar); Emit($E2); Emit(Byte(Longint(Q)-CodeSize-1));
   PatchJump(P,CodeSize); Emit2($89,$F0); CallTo(RuntimeString); Emit($1F);
  End Else Begin
  Case T Of
  ttString:Begin Emit($1E); Emit2($8E,$DA); CallTo(RuntimeString); Emit($1F) End;
  ttChar:CallTo(RuntimeChar);
  ttPointer,ttArray:Begin
   If (T=ttArray) And (Types[ExprType].Typ=ttArray) And (TypeExtras[ExprType].ElementType=6) And
      Not IsCharArray(ExprType) Then Begin
    { Tableau de caracteres non base a zero: imprime comme une chaine de sa taille. }
    CharArrayToString(ExprType); Emit($1E); Emit2($8E,$DA); CallTo(RuntimeString); Emit($1F);
   End Else Begin
    If Not (((T=ttPointer) And IsCharPointer(ExprType)) Or ((T=ttArray) And IsCharArray(ExprType))) Or
       Not ExtendedSyntax Then Fail(64,'Type non imprimable');
    WriteZString;
   End;
  End;
  ttInteger:Begin
   If Types[ExprType].Width=4 Then Begin CallTo(RuntimeStandard[16]); CallTo(RuntimeString) End
   Else If ExprUnsigned Then CallTo(RuntimeUnsigned) Else CallTo(RuntimeInteger);
  End;
  ttBoolean:CallTo(RuntimeBoolean);
  Else Unsupported('type non imprimable');
 End;
 End;

    End;
   End;
   If Token<>tkComma Then Break; NextToken;
  End;
  Need(tkRP);
 End;
 If BinaryType<>0 Then Begin Emit2($83,$C4); Emit(4) End;
 If NewLine Then CallTo(RuntimeStandard[75]) Else CallTo(RuntimeStandard[74]); { WriteLnEnd / WriteEnd }
 If OptionBits And 1<>0 Then CallTo(RuntimeStandard[25]);
End;

Function AsmRegister(Name: TShortString; var O: TAsmOperand): Boolean;
Const Names: Array[0..19] Of String[2]=('AX','CX','DX','BX','SP','BP','SI','DI',
 'AL','CL','DL','BL','AH','CH','DH','BH','ES','CS','SS','DS');
Var K: Byte;
Begin
 AsmRegister:=True;
 For K:=0 To 19 Do If Name=Names[K] Then Begin
  If K<16 Then Begin O.Kind:=1; O.Reg:=K Mod 8; If K<8 Then O.Width:=2 Else O.Width:=1 End
  Else Begin O.Kind:=4; O.Reg:=K-16; O.Width:=2 End;
  Exit;
 End;
 AsmRegister:=False;
End;

Procedure AsmStatement;
Var Name: TShortString; A,B,C: TAsmOperand; W,K,Op,Group,InstructionLine,I,P: Word;
 LabelCount,RefCount: Word;
 Labels: Array[1..128] Of Record Name: String[63]; Address: Word; Defined: Boolean End;
 References: Array[1..256] Of Record Position,LabelIndex: Word End;
 SavedAssembler: Boolean;
Function LabelIndex(S: TShortString): Word;
Var J: Word;
Begin
 For J:=1 To LabelCount Do If Labels[J].Name=S Then Begin LabelIndex:=J; Exit End;
 If LabelCount=128 Then Fail(123,'Trop de labels assembleur');
 Inc(LabelCount); Labels[LabelCount].Name:=S; Labels[LabelCount].Defined:=False; LabelIndex:=LabelCount;
End;
Function ReadName: TShortString;
Var S: TShortString;
Begin
 S:=''; While Token=tkAt Do Begin S:=S+'@'; NextToken End;
 If (TokenText='') And (Token=tkConstant) And (S<>'') Then Str(TokenValue,TokenText); { @1, @@2 }
 If TokenText='' Then Fail(2,'Nom assembleur attendu');
 S:=S+TokenText; NextToken; ReadName:=S;
End;
Function AsmConstStart: Boolean;
{ L'operande commence-t-il une expression constante (immediat)? }
Var Id: Word;
Begin
 AsmConstStart:=True;
 If Token In [tkConstant,tkLP,tkNot,tkMinus,tkPlus] Then Exit;
 If (TokenText='LOW') Or (TokenText='HIGH') Or (TokenText='TRUE') Or (TokenText='FALSE') Then Exit;
 If (Token=tkIdent) And (Peek<>'.') And (Peek<>'[') Then Begin
  Id:=FindSymbol(TokenText);
  If (Id<>0) And (Symbols[Id].Kind=skConst) Then Exit;
 End;
 AsmConstStart:=False;
End;
Function AsmExpr(Level: Byte): Longint;
{ Expression constante assembleur: + - OR XOR / * DIV MOD AND SHL SHR / unaires - + NOT, LOW(), HIGH(), (). }
Var V,W: Longint; Op: Byte; Id: Word; Name: TShortString;
Begin
 V:=0;
 Case Level Of
  0:Begin
     V:=AsmExpr(1);
     While (Token In [tkPlus,tkMinus,tkOr,tkXor]) And (TokenLine=InstructionLine) Do Begin
      Op:=Token; NextToken; W:=AsmExpr(1);
      Case Op Of tkPlus:V:=V+W; tkMinus:V:=V-W; tkOr:V:=V Or W; Else V:=V Xor W End;
     End;
    End;
  1:Begin
     V:=AsmExpr(2);
     While (Token In [tkTimes,tkSlash,tkDiv,tkMod,tkAnd,tkShl,tkShr]) And (TokenLine=InstructionLine) Do Begin
      Op:=Token; NextToken; W:=AsmExpr(2);
      Case Op Of
       tkTimes:V:=V*W;
       tkSlash,tkDiv:Begin If W=0 Then Fail(62,''); V:=V Div W End;
       tkMod:Begin If W=0 Then Fail(62,''); V:=V Mod W End;
       tkAnd:V:=V And W; tkShl:V:=V Shl W; Else V:=V Shr W;
      End;
     End;
    End;
  Else Begin
   If Token=tkMinus Then Begin NextToken; V:=-AsmExpr(2) End
   Else If Token=tkPlus Then Begin NextToken; V:=AsmExpr(2) End
   Else If Token=tkNot Then Begin NextToken; V:=Not AsmExpr(2) End
   Else If Token=tkLP Then Begin NextToken; V:=AsmExpr(0); Need(tkRP) End
   Else If Token=tkConstant Then Begin
    If TokenIsString Then Begin
     If Length(TokenText)<>1 Then Fail(7,'Caractere immediat attendu'); V:=Ord(TokenText[1]);
    End Else V:=TokenValue;
    NextToken;
   End Else Begin
    Name:=ReadName;
    If (Name='LOW') Or (Name='HIGH') Then Begin
     Need(tkLP); W:=AsmExpr(0); Need(tkRP);
     If Name='LOW' Then V:=W And $FF Else V:=(W Shr 8) And $FF;
    End Else If Name='TRUE' Then V:=1 Else If Name='FALSE' Then V:=0
    Else Begin
     Id:=ResolveSymbol(Name);
     If Symbols[Id].Kind<>skConst Then Fail(5,'Constante assembleur attendue');
     V:=Symbols[Id].Value;
    End;
   End;
  End;
 End;
 AsmExpr:=V;
End;
Function Operand: TAsmOperand;
Var O,R: TAsmOperand; S: TShortString; Size,Mask,Id,T,F: Word; Sign: Integer; Bracket,ForceOffset,ForceSegment,Resolved,Again: Boolean;
Procedure Members(SymbolId: Word);
Var T,F: Word;
Begin
 T:=SymbolType(SymbolId);
 If (Token=tkDot) And Symbols[SymbolId].ByReference Then Unsupported('champ assembleur d''un parametre var: utiliser LES/LDS');
 While Token=tkDot Do Begin
  If Types[T].Typ<>ttRecord Then Break; { .Word / .Byte: suffixe de taille traite plus loin }
  NextToken; If Token<>tkIdent Then Fail(2,'Champ assembleur attendu');
  F:=TypeExtras[T].FirstField; While (F<>0) And (Fields[F].Name<>TokenText) Do F:=Fields[F].Next;
  If F=0 Then Fail(3,'Champ assembleur inconnu');
  Inc(O.Displacement,Fields[F].Offset); T:=Fields[F].TypeId; NextToken;
 End;
 If Size=0 Then Begin
  O.Width:=Types[T].Width;
  If Types[T].Typ=ttArray Then O.Width:=Types[TypeExtras[T].ElementType].Width;
  If Types[T].Typ=ttString Then O.Width:=1;
  If Symbols[SymbolId].ByReference Then O.Width:=4;
 End;
End;
Procedure Atom;
Begin
 If Token=tkConstant Then Begin
  If TokenIsString Then Begin If Length(TokenText)<>1 Then Fail(7,'Caractere immediat attendu'); O.Displacement:=O.Displacement+Sign*Ord(TokenText[1]) End
  Else O.Displacement:=O.Displacement+Sign*TokenValue;
  NextToken;
 End Else Begin
  S:=ReadName; FillChar(R,SizeOf(R),0);
  If AsmRegister(S,R) Then Begin
   If (R.Kind<>1) Or (R.Width<>2) Or Not (R.Reg In [3,5,6,7]) Or (Sign<0) Then Fail(5,'Registre d''adresse 8086 invalide');
   Case R.Reg Of 3:Id:=1; 5:Id:=2; 6:Id:=4; 7:Id:=8 End;
   If Mask And Id<>0 Then Fail(5,'Registre d''adresse duplique'); Mask:=Mask Or Id;
  End Else Begin
   Id:=ResolveSymbol(S);
   If Symbols[Id].Kind=skConst Then O.Displacement:=O.Displacement+Sign*Symbols[Id].Value
   Else Begin
    If (Symbols[Id].Kind<>skVar) Or (Sign<0) Or (O.Sym<>0) Then Fail(5,'Adresse assembleur invalide');
    If Symbols[Id].Native Then Unsupported('operande assembleur de donnees Borland');
    If Symbols[Id].Local Then Begin
     If Symbols[Id].Scope<>CurrentScope Then Unsupported('capture de variable assembleur imbriquee');
     Mask:=Mask Or 2; O.Displacement:=O.Displacement+SmallInt(Symbols[Id].Addr);
    End Else O.Sym:=Id;
    If Size=0 Then Begin O.Width:=Symbols[Id].Width; If Symbols[Id].ByReference Then O.Width:=4 End;
    Members(Id);
   End;
  End;
 End;
End;
Begin
 FillChar(O,SizeOf(O),0); Size:=0; Mask:=0; Sign:=1; ForceOffset:=False; ForceSegment:=False;
 If TokenText='OFFSET' Then Begin ForceOffset:=True; NextToken End
 Else If TokenText='SEG' Then Begin ForceSegment:=True; NextToken End;
 If TokenText='SHORT' Then NextToken Else If (TokenText='NEAR') Or (TokenText='FAR') Then NextToken;
 If TokenText='BYTE' Then Size:=1 Else If TokenText='WORD' Then Size:=2
 Else If TokenText='DWORD' Then Size:=4 Else If TokenText='QWORD' Then Size:=8 Else If TokenText='TBYTE' Then Size:=10;
 If Size<>0 Then Begin NextToken; If TokenText='PTR' Then NextToken End;
 O.Width:=Size;
 If (TokenText='ST') Then Begin
  NextToken; O.Kind:=6; O.Reg:=0;
  If Token=tkLP Then Begin NextToken; If (Token<>tkConstant) Or (TokenValue<0) Or (TokenValue>7) Then Fail(7,'ST index 0..7'); O.Reg:=TokenValue; NextToken; Need(tkRP) End;
  Operand:=O; Exit;
 End;
 If (Size=0) And Not ForceOffset And Not ForceSegment And AsmConstStart Then Begin
  O.Kind:=3; O.Displacement:=AsmExpr(0); Operand:=O; Exit;
 End;
 If Token=tkMinus Then Begin Sign:=-1; NextToken End Else If Token=tkPlus Then NextToken;
 If (Token<>tkLB) And (Token<>tkAt) And (TokenText<>'') Then Begin
  S:=TokenText; FillChar(R,SizeOf(R),0);
  If AsmRegister(S,R) Then Begin
   NextToken;
   If (R.Kind=4) And (Token=tkColon) Then Begin
    O.Segment:=R.Reg+1; NextToken;
   End Else Begin If Size<>0 Then Fail(5,'PTR sur registre'); Operand:=R; Exit End;
  End;
 End;
 Bracket:=Token=tkLB;
 If Bracket Then Begin NextToken; O.Kind:=2; Atom;
  While Token In [tkPlus,tkMinus] Do Begin If Token=tkMinus Then Sign:=-1 Else Sign:=1; NextToken; Atom End;
  Need(tkRB);
 End Else Begin
  S:=ReadName; Resolved:=False;
  If (Token=tkDot) And (FindBuildUnit(S)<>0) Then Begin Id:=ResolveSymbol(S); Resolved:=True End Else Id:=FindSymbol(S);
  If S='@RESULT' Then Begin
   { @Result: variable resultat de la fonction (TP 7) }
   Id:=Symbols[Scopes[RealScope(CurrentScope)].ProcSymbol].ResultSymbol;
   If (Id=0) Or Not Symbols[Id].Local Then Fail(5,'@Result indisponible ici');
   O.Kind:=2; Mask:=2; O.Displacement:=SmallInt(Symbols[Id].Addr);
   If Size=0 Then O.Width:=Symbols[Id].Width;
  End Else
  If Id=0 Then Begin O.Kind:=5; O.Name:=S End
  Else Begin
   If Not Resolved Then Id:=ResolveSymbol(S);
   If Symbols[Id].Kind=skConst Then Begin O.Kind:=3; O.Displacement:=Sign*Symbols[Id].Value End
   Else If Symbols[Id].Kind=skProc Then Begin O.Kind:=5; O.Sym:=Id; O.Name:=S End
   Else If Symbols[Id].Kind=skLabel Then Begin O.Kind:=5; O.Sym:=Id; O.Name:=S End
   Else If Symbols[Id].Kind=skVar Then Begin
    O.Kind:=2;
    If Symbols[Id].Native Then Unsupported('operande assembleur de donnees Borland');
    If Symbols[Id].Local Then Begin
     If Symbols[Id].Scope<>CurrentScope Then Unsupported('capture de variable assembleur imbriquee');
     Mask:=2; O.Displacement:=SmallInt(Symbols[Id].Addr);
    End Else O.Sym:=Id;
    If Size=0 Then Begin O.Width:=Symbols[Id].Width; If Symbols[Id].ByReference Then O.Width:=4 End;
    Members(Id);
   End Else If (Symbols[Id].Kind=skType) And (Token=tkDot) And ForceOffset Then Begin
    { OFFSET Type.Champ: deplacement constant du champ }
    T:=Symbols[Id].TypeId; O.Kind:=3; ForceOffset:=False;
    While Token=tkDot Do Begin
     If Types[T].Typ<>ttRecord Then Fail(26,'Champ assembleur hors record');
     NextToken; If Token<>tkIdent Then Fail(2,'Champ assembleur attendu');
     F:=TypeExtras[T].FirstField; While (F<>0) And (Fields[F].Name<>TokenText) Do F:=Fields[F].Next;
     If F=0 Then Fail(3,'Champ assembleur inconnu');
     Inc(O.Displacement,Fields[F].Offset); T:=Fields[F].TypeId; NextToken;
    End;
   End Else Fail(5,'Operande assembleur invalide');
  End;
  If Token In [tkPlus,tkMinus] Then Begin
   If Token=tkMinus Then Sign:=-1 Else Sign:=1; NextToken;
   If Token<>tkConstant Then Fail(7,'Deplacement constant attendu'); O.Displacement:=O.Displacement+Sign*TokenValue; NextToken;
  End;
 End;
 Repeat
  Again:=False;
  If (O.Kind=2) And (Token=tkLB) Then Begin
   NextToken; Sign:=1; Atom;
   While Token In [tkPlus,tkMinus] Do Begin If Token=tkMinus Then Sign:=-1 Else Sign:=1; NextToken; Atom End;
   Need(tkRB); Again:=True;
  End;
  If (O.Kind=2) And (Token=tkDot) And (Peek In ['B','b','W','w','D','d']) Then Begin
   { suffixe de taille: [BX].Word, [DI+2].Byte, Var.Word[2] }
   NextToken;
   If TokenText='BYTE' Then O.Width:=1 Else If TokenText='WORD' Then O.Width:=2
   Else If TokenText='DWORD' Then O.Width:=4 Else Fail(5,'Suffixe de taille invalide');
   NextToken; Again:=True;
  End;
 Until Not Again;
 If O.Kind=2 Then Begin
  Case Mask Of 0:Begin O.RM:=6; O.Direct:=True End; 1:O.RM:=7; 2:O.RM:=6;
   4:O.RM:=4; 8:O.RM:=5; 5:O.RM:=0; 9:O.RM:=1; 6:O.RM:=2; 10:O.RM:=3;
   Else Fail(5,'Combinaison d''adresse 8086 invalide');
  End;
 End;
 If ForceOffset Or ForceSegment Then Begin
  If (O.Kind=2) And O.Direct And (O.Sym<>0) Then Begin
   O.Kind:=3; O.Width:=2; O.OffsetValue:=ForceOffset; O.SegmentValue:=ForceSegment;
  End Else If ForceOffset And (O.Kind=2) And (O.Sym=0) And (Mask=2) Then Begin
   O.Kind:=3; O.Width:=2;  { OFFSET variable locale: deplacement BP constant (comme TP) }
  End Else If ForceOffset And (O.Kind=5) And (O.Sym<>0) Then Begin
   O.Kind:=3; O.Width:=2; O.CodeValue:=True;  { OFFSET procedure: adresse dans le code }
  End Else Unsupported('OFFSET/SEG sans variable globale');
 End;
 Operand:=O;
End;
Procedure Prefix(O: TAsmOperand);
Const Bytes: Array[1..4] Of Byte=($26,$2E,$36,$3E);
Begin If O.Segment<>0 Then Emit(Bytes[O.Segment]) End;
Procedure RM(RegField: Byte; O: TAsmOperand);
Var Mode: Byte;
Begin
 If O.Kind=1 Then Begin Emit($C0+RegField*8+O.Reg); Exit End;
 If O.Kind<>2 Then Fail(5,'Registre ou memoire attendu');
 If O.Direct Then Mode:=0
 Else If O.Sym<>0 Then Mode:=2
 Else If (O.Displacement=0) And (O.RM<>6) Then Mode:=0
 Else If (O.Displacement>=-128) And (O.Displacement<=127) Then Mode:=1 Else Mode:=2;
 Emit(Mode*64+RegField*8+O.RM);
 If O.Sym<>0 Then DataAddress(Word(Symbols[O.Sym].Addr+O.Displacement))
 Else If O.Direct Or (Mode=2) Then EmitWord(Word(O.Displacement))
 Else If Mode=1 Then Emit(Byte(O.Displacement));
End;
Procedure Immediate(O: TAsmOperand; Size: Word);
Begin
 If O.Kind<>3 Then Fail(5,'Operande immediat attendu');
 If O.SegmentValue Then Begin AddSegmentRelocation(CodeSize,0); EmitWord(0) End
 Else If O.CodeValue Then Begin
  If CurrentUnit<>0 Then Unsupported('OFFSET de procedure dans une unite');
  If Not Symbols[O.Sym].HasBody Then Fail(5,'Procedure non encore definie');
  EmitWord(Symbols[O.Sym].Addr);
 End
 Else If O.OffsetValue Then DataAddress(Word(Symbols[O.Sym].Addr+O.Displacement))
 Else If Size=1 Then Begin If (O.Displacement<-128) Or (O.Displacement>255) Then Fail(76,'Immediat byte hors limites'); Emit(Byte(O.Displacement)) End
 Else Begin If (O.Displacement<-32768) Or (O.Displacement>65535) Then Fail(76,'Immediat word hors limites'); EmitWord(Word(O.Displacement)) End;
End;
Procedure MatchWidth;
Begin
 If A.Width=0 Then A.Width:=B.Width; If B.Width=0 Then B.Width:=A.Width;
 If (A.Width<>B.Width) Or Not (A.Width In [1,2]) Then Fail(26,'Largeurs assembleur incompatibles'); W:=A.Width-1;
End;
Procedure RelativeTarget(O: TAsmOperand);
Begin
 If O.Kind<>5 Then Fail(5,'Label assembleur attendu');
 If (O.Sym<>0) And (Symbols[O.Sym].Kind=skLabel) Then Begin
  { etiquette Pascal: resolue par DefineLabel/CheckLabels comme un GOTO }
  If Symbols[O.Sym].HasBody Then Begin P:=CodeSize; EmitWord(0); PatchJump(P,Symbols[O.Sym].Addr) End
  Else Begin
   If LabelJumpCount=512 Then Fail(123,'Trop de sauts');
   Inc(LabelJumpCount); LabelJumps[LabelJumpCount].Sym:=O.Sym; LabelJumps[LabelJumpCount].Position:=CodeSize; EmitWord(0);
  End;
 End Else
 If O.Sym<>0 Then Begin If Symbols[O.Sym].Native Then Unsupported('saut assembleur vers Borland'); P:=CodeSize; EmitWord(0); PatchJump(P,Symbols[O.Sym].Addr) End
 Else Begin
  If RefCount=256 Then Fail(123,'Trop de references assembleur');
  Inc(RefCount); References[RefCount].Position:=CodeSize; References[RefCount].LabelIndex:=LabelIndex(O.Name); EmitWord(0);
 End;
End;
Function Condition(S: TShortString): Byte;
Begin
 Condition:=0;
 If S='JO' Then Condition:=$70 Else If S='JNO' Then Condition:=$71
 Else If (S='JB') Or (S='JC') Or (S='JNAE') Then Condition:=$72
 Else If (S='JAE') Or (S='JNC') Or (S='JNB') Then Condition:=$73
 Else If (S='JE') Or (S='JZ') Then Condition:=$74 Else If (S='JNE') Or (S='JNZ') Then Condition:=$75
 Else If (S='JBE') Or (S='JNA') Then Condition:=$76 Else If (S='JA') Or (S='JNBE') Then Condition:=$77
 Else If S='JS' Then Condition:=$78 Else If S='JNS' Then Condition:=$79
 Else If (S='JP') Or (S='JPE') Then Condition:=$7A Else If (S='JNP') Or (S='JPO') Then Condition:=$7B
 Else If (S='JL') Or (S='JNGE') Then Condition:=$7C Else If (S='JGE') Or (S='JNL') Then Condition:=$7D
 Else If (S='JLE') Or (S='JNG') Then Condition:=$7E Else If (S='JG') Or (S='JNLE') Then Condition:=$7F;
End;
Procedure Need286;
Begin If OptionBits And $2000=0 Then Unsupported('instruction 286 exige $G+'); UnitFeatures[CurrentUnit]:=UnitFeatures[CurrentUnit] Or 2 End;
Procedure EmulatedFPU;
Var Operation,Width,Index,G: Word; Memory: Boolean;
Begin
 EnsureRealRuntime; Operation:=2; Width:=0; Index:=0; Memory:=False;
 If (Name='FINIT') Or (Name='FNINIT') Then Operation:=0
 Else If (Name='FCLEX') Or (Name='FNCLEX') Then Operation:=1
 Else If Name='FNOP' Then Operation:=2
 Else If (Name='FLD1') Or (Name='FLDZ') Or (Name='FLDPI') Or (Name='FLDL2T') Or
  (Name='FLDL2E') Or (Name='FLDLG2') Or (Name='FLDLN2') Then Begin
  Operation:=3; If Name='FLDZ' Then Index:=1 Else If Name='FLDPI' Then Index:=2
  Else If Name='FLDL2T' Then Index:=3 Else If Name='FLDL2E' Then Index:=4 Else If Name='FLDLG2' Then Index:=5 Else If Name='FLDLN2' Then Index:=6;
 End Else If (Name='FSQRT') Or (Name='FABS') Or (Name='FCHS') Or (Name='FTST') Or
  (Name='FXAM') Or (Name='FRNDINT') Or (Name='F2XM1') Then Begin
  Operation:=4; If Name='FABS' Then Index:=1 Else If Name='FCHS' Then Index:=2 Else If Name='FTST' Then Index:=3
  Else If Name='FXAM' Then Index:=4 Else If Name='FRNDINT' Then Index:=5 Else If Name='F2XM1' Then Index:=6;
 End Else If Name='FCOMPP' Then Operation:=19 Else If Name='FSCALE' Then Operation:=20
 Else If Name='FPREM' Then Operation:=21 Else If Name='FYL2X' Then Operation:=22
 Else If Name='FYL2XP1' Then Operation:=23 Else If Name='FPATAN' Then Operation:=24
 Else If Name='FPTAN' Then Operation:=25 Else If Name='FXTRACT' Then Operation:=26
 Else If Name='FDECSTP' Then Operation:=27 Else If Name='FINCSTP' Then Operation:=28
 Else Begin
  If (Name='FADDP') Or (Name='FMULP') Or (Name='FSUBP') Or (Name='FSUBRP') Or (Name='FDIVP') Or (Name='FDIVRP') Then Begin
   FillChar(A,SizeOf(A),0); A.Kind:=6; A.Reg:=1;
   If (TokenLine=InstructionLine) And Not (Token In [tkEnd,tkSemi]) Then Begin
    A:=Operand; If Token=tkComma Then Begin NextToken; B:=Operand; If (B.Kind<>6) Or (B.Reg<>0) Then Fail(5,'ST(0) attendu') End;
   End;
   If A.Kind<>6 Then Fail(5,'Registre ST attendu'); G:=0;
   If Name='FMULP' Then G:=1 Else If Name='FSUBP' Then G:=4 Else If Name='FSUBRP' Then G:=5
   Else If Name='FDIVP' Then G:=6 Else If Name='FDIVRP' Then G:=7;
   Operation:=15; Index:=G+A.Reg*8+128+256;
  End Else Begin
   A:=Operand;
   If (Name='FLD') Or (Name='FST') Or (Name='FSTP') Or (Name='FILD') Or (Name='FIST') Or (Name='FISTP') Then Begin
    If Name='FLD' Then Operation:=5 Else If Name='FST' Then Operation:=6 Else If Name='FSTP' Then Operation:=7
    Else If Name='FILD' Then Operation:=8 Else If Name='FIST' Then Operation:=9 Else Operation:=10;
    If A.Kind=6 Then Begin
     If Operation=5 Then Operation:=11 Else If Operation=6 Then Operation:=12 Else If Operation=7 Then Operation:=13 Else Fail(5,'Memoire entiere attendue');
     Index:=A.Reg;
    End Else Begin
     Memory:=True; Width:=A.Width;
     If (Operation<=7) And Not (Width In [4,8,10]) Then Fail(26,'Taille reelle 8087');
     If (Operation>=8) And Not (Width In [2,4,8]) Then Fail(26,'Taille entiere 8087');
    End;
   End Else If Name='FXCH' Then Begin If A.Kind<>6 Then Fail(5,'Registre ST attendu'); Operation:=14; Index:=A.Reg End
   Else If (Name='FLDCW') Or (Name='FSTCW') Or (Name='FNSTCW') Or (Name='FSTSW') Or (Name='FNSTSW') Then Begin
    Operation:=17; If Name='FLDCW' Then Operation:=16 Else If (Name='FSTSW') Or (Name='FNSTSW') Then Operation:=18;
    Memory:=True; Width:=2;
   End Else Begin
    G:=0;
    If (Name='FMUL') Or (Name='FIMUL') Then G:=1 Else If (Name='FCOM') Or (Name='FICOM') Then G:=2
    Else If (Name='FCOMP') Or (Name='FICOMP') Then G:=3 Else If (Name='FSUB') Or (Name='FISUB') Then G:=4
    Else If (Name='FSUBR') Or (Name='FISUBR') Then G:=5 Else If (Name='FDIV') Or (Name='FIDIV') Then G:=6
    Else If (Name='FDIVR') Or (Name='FIDIVR') Then G:=7
    Else If (Name<>'FADD') And (Name<>'FIADD') Then Unsupported('instruction 8087 emulee: '+Name);
    Operation:=15; Index:=G;
    If A.Kind=6 Then Begin
     If Token=tkComma Then Begin NextToken; B:=Operand; If B.Kind<>6 Then Fail(5,'Registre ST attendu');
      If A.Reg=0 Then A.Reg:=B.Reg Else Begin If B.Reg<>0 Then Fail(5,'ST(0) attendu'); Index:=Index+128 End;
     End; Index:=Index+A.Reg*8;
    End Else Begin
     Memory:=True; Width:=A.Width;
     If Name[2]='I' Then Begin If Not (Width In [2,4]) Then Fail(26,'Taille entiere 8087'); Inc(Width,16) End
     Else If Not (Width In [4,8]) Then Fail(26,'Taille reelle 8087');
    End;
   End;
  End;
 End;
 If Memory And (A.Kind<>2) Then Fail(5,'Operande memoire attendu');
 { x87 instructions leave integer registers, segments and flags intact. }
 Emit($9C); Emit($50); Emit($51); Emit($52); Emit($53); Emit($56); Emit($57); Emit($55); Emit($1E); Emit($06);
 Emit($FC); { runtime string copies require DF=0; POPF restores caller DF }
 If Memory Then Begin
  Emit($8D); RM(0,A);
  G:=A.Segment; If G=0 Then Begin If Not A.Direct And (A.RM In [2,3,6]) Then G:=3 Else G:=4 End;
  Emit($8C); Case G Of 1:Emit($C2); 2:Emit($CA); 3:Emit($D2); 4:Emit($DA) End;
 End Else Begin Emit2($31,$C0); Emit2($8C,$DA) End;
 Emit2($89,$C6); LoadImmediate(Operation); Emit($50); LoadImmediate(Width); Emit($50); LoadImmediate(Index); Emit($50);
 Emit($52); Emit($56); RealCall('REMU');
 Emit($07); Emit($1F); Emit($5D); Emit($5F); Emit($5E); Emit($5B); Emit($5A); Emit($59); Emit($58); Emit($9D);
End;
Procedure FPU;
Begin
 If OptionBits And $80=0 Then Unsupported('instruction 8087 exige $N+');
 If OptionBits And $400<>0 Then Begin EmulatedFPU; Exit End;
 UnitFeatures[CurrentUnit]:=UnitFeatures[CurrentUnit] Or 1;
 If Name='FINIT' Then Begin Emit($9B); Emit2($DB,$E3) End
 Else If Name='FNOP' Then Emit2($D9,$D0)
 Else If Name='FNINIT' Then Emit2($DB,$E3)
 Else If Name='FCLEX' Then Begin Emit($9B); Emit2($DB,$E2) End
 Else If Name='FNCLEX' Then Emit2($DB,$E2)
 Else If Name='FLD1' Then Emit2($D9,$E8) Else If Name='FLDZ' Then Emit2($D9,$EE)
 Else If Name='FLDPI' Then Emit2($D9,$EB) Else If Name='FLDL2T' Then Emit2($D9,$E9)
 Else If Name='FLDL2E' Then Emit2($D9,$EA) Else If Name='FLDLG2' Then Emit2($D9,$EC)
 Else If Name='FLDLN2' Then Emit2($D9,$ED) Else If Name='FSQRT' Then Emit2($D9,$FA)
 Else If Name='FABS' Then Emit2($D9,$E1) Else If Name='FCHS' Then Emit2($D9,$E0)
 Else If Name='FTST' Then Emit2($D9,$E4) Else If Name='FXAM' Then Emit2($D9,$E5)
 Else If Name='F2XM1' Then Emit2($D9,$F0) Else If Name='FYL2X' Then Emit2($D9,$F1)
 Else If Name='FPTAN' Then Emit2($D9,$F2) Else If Name='FPATAN' Then Emit2($D9,$F3)
 Else If Name='FXTRACT' Then Emit2($D9,$F4) Else If Name='FPREM' Then Emit2($D9,$F8)
 Else If Name='FYL2XP1' Then Emit2($D9,$F9) Else If Name='FRNDINT' Then Emit2($D9,$FC)
 Else If Name='FSCALE' Then Emit2($D9,$FD) Else If Name='FDECSTP' Then Emit2($D9,$F6)
 Else If Name='FINCSTP' Then Emit2($D9,$F7) Else If Name='FCOMPP' Then Emit2($DE,$D9)
 Else If (Name='FADDP') Or (Name='FMULP') Or (Name='FSUBP') Or (Name='FSUBRP') Or (Name='FDIVP') Or (Name='FDIVRP') Then Begin
  A.Kind:=6; A.Reg:=1;
  If (TokenLine=InstructionLine) And Not (Token In [tkEnd,tkSemi]) Then Begin A:=Operand; If Token=tkComma Then Begin NextToken; B:=Operand; If (B.Kind<>6) Or (B.Reg<>0) Then Fail(5,'ST(0) attendu') End End;
  If A.Kind<>6 Then Fail(5,'Registre ST attendu'); Group:=0;
  If Name='FMULP' Then Group:=1 Else If Name='FSUBRP' Then Group:=4 Else If Name='FSUBP' Then Group:=5
  Else If Name='FDIVRP' Then Group:=6 Else If Name='FDIVP' Then Group:=7;
  Emit2($DE,$C0+Group*8+A.Reg);
 End Else Begin
  A:=Operand; Group:=0; Op:=0;
  If (Name='FLD') Or (Name='FST') Or (Name='FSTP') Then Begin
   If A.Kind=6 Then Begin
    If Name='FLD' Then Emit2($D9,$C0+A.Reg) Else If Name='FST' Then Emit2($DD,$D0+A.Reg) Else Emit2($DD,$D8+A.Reg); Exit;
   End;
   If Name='FST' Then Group:=2 Else If Name='FSTP' Then Group:=3;
   If A.Width=4 Then Op:=$D9 Else If A.Width=8 Then Op:=$DD
   Else If (A.Width=10) And (Name<>'FST') Then Begin Op:=$DB; If Name='FLD' Then Group:=5 Else Group:=7 End;
  End Else If (Name='FILD') Or (Name='FIST') Or (Name='FISTP') Then Begin
   If Name='FIST' Then Group:=2 Else If Name='FISTP' Then Group:=3;
   If A.Width=2 Then Op:=$DF Else If A.Width=4 Then Op:=$DB
   Else If (A.Width=8) And (Name<>'FIST') Then Begin Op:=$DF; If Name='FILD' Then Group:=5 Else Group:=7 End;
  End Else If Name='FXCH' Then Begin If A.Kind<>6 Then Fail(5,'Registre ST attendu'); Emit2($D9,$C8+A.Reg); Exit End
  Else If (Name='FLDCW') Or (Name='FSTCW') Or (Name='FNSTCW') Then Begin
   Op:=$D9; Group:=5; If Name<>'FLDCW' Then Begin Group:=7; If Name='FSTCW' Then Emit($9B) End; A.Width:=2;
  End Else If (Name='FSTSW') Or (Name='FNSTSW') Then Begin
   If A.Kind=1 Then Unsupported('FSTSW AX exige un 80287');
   Op:=$DD; Group:=7; If Name='FSTSW' Then Emit($9B); A.Width:=2;
  End Else Begin
   If (Name='FADD') Or (Name='FIADD') Then Group:=0 Else If (Name='FMUL') Or (Name='FIMUL') Then Group:=1
   Else If (Name='FCOM') Or (Name='FICOM') Then Group:=2 Else If (Name='FCOMP') Or (Name='FICOMP') Then Group:=3
   Else If (Name='FSUB') Or (Name='FISUB') Then Group:=4 Else If (Name='FSUBR') Or (Name='FISUBR') Then Group:=5
   Else If (Name='FDIV') Or (Name='FIDIV') Then Group:=6 Else If (Name='FDIVR') Or (Name='FIDIVR') Then Group:=7
   Else Unsupported('instruction 8087: '+Name);
   If A.Kind=6 Then Begin
    If Name[2]='I' Then Fail(5,'Operande memoire entier attendu');
    If Token=tkComma Then Begin
     NextToken; B:=Operand; If B.Kind<>6 Then Fail(5,'Operande ST attendu');
     If A.Reg=0 Then A.Reg:=B.Reg
     Else Begin
      If (B.Reg<>0) Or (Group In [2,3]) Then Fail(5,'ST(0) attendu');
      If Group>=4 Then Group:=Group Xor 1;
      Emit2($DC,$C0+Group*8+A.Reg); Exit;
     End;
    End;
    Emit2($D8,$C0+Group*8+A.Reg); Exit;
   End;
   If Name[2]='I' Then Begin If A.Width=2 Then Op:=$DE Else If A.Width=4 Then Op:=$DA End
   Else Begin If A.Width=4 Then Op:=$D8 Else If A.Width=8 Then Op:=$DC End;
  End;
  If (A.Kind<>2) Or (Op=0) Then Fail(26,'Operande memoire 8087 ou taille invalide'); Prefix(A); Emit(Op); RM(Group,A);
 End;
End;
Begin
 SavedAssembler:=InAssembler; InAssembler:=True; LabelCount:=0; RefCount:=0;
 NextToken;
 While Token<>tkEnd Do Begin
  If Token=tkEOF Then Fail(37,'END assembleur manquant'); If Token=tkSemi Then Begin NextToken; Continue End;
  DebugLineEntry; InstructionLine:=TokenLine; Name:=ReadName;
  { Le debut de l'instruction est l'adresse de debug, avant emission. }
  If Token=tkColon Then Begin K:=LabelIndex(Name); If Labels[K].Defined Then Fail(4,'Label assembleur duplique'); Labels[K].Defined:=True; Labels[K].Address:=CodeSize; NextToken; Continue End;
  FillChar(A,SizeOf(A),0); FillChar(B,SizeOf(B),0);
  If Name='NOP' Then Emit($90) Else If Name='CLD' Then Emit($FC) Else If Name='STD' Then Emit($FD)
  Else If Name='CLI' Then Emit($FA) Else If Name='STI' Then Emit($FB) Else If Name='CLC' Then Emit($F8)
  Else If Name='STC' Then Emit($F9) Else If Name='CMC' Then Emit($F5) Else If Name='CBW' Then Emit($98)
  Else If Name='CWD' Then Emit($99) Else If Name='LAHF' Then Emit($9F) Else If Name='SAHF' Then Emit($9E)
  Else If Name='PUSHF' Then Emit($9C) Else If Name='POPF' Then Emit($9D)
  Else If Name='WAIT' Then Begin If OptionBits And $400<>0 Then Emit($90) Else Emit($9B) End
  Else If Name='XLAT' Then Emit($D7) Else If Name='HLT' Then Emit($F4) Else If Name='INTO' Then Emit($CE)
  Else If Name='IRET' Then Emit($CF) Else If Name='INT3' Then Emit($CC)
  Else If Name='INT' Then Begin A:=Operand; Emit($CD); Immediate(A,1) End
  Else If Name='DAA' Then Emit($27) Else If Name='DAS' Then Emit($2F) Else If Name='AAA' Then Emit($37) Else If Name='AAS' Then Emit($3F)
  Else If Name='AAM' Then Emit2($D4,10) Else If Name='AAD' Then Emit2($D5,10)
  Else If Name='MOVSB' Then Emit($A4) Else If Name='MOVSW' Then Emit($A5)
  Else If Name='CMPSB' Then Emit($A6) Else If Name='CMPSW' Then Emit($A7)
  Else If Name='STOSB' Then Emit($AA) Else If Name='STOSW' Then Emit($AB)
  Else If Name='LODSB' Then Emit($AC) Else If Name='LODSW' Then Emit($AD)
  Else If Name='SCASB' Then Emit($AE) Else If Name='SCASW' Then Emit($AF)
  Else If (Name='REP') Or (Name='REPE') Or (Name='REPZ') Then Emit($F3)
  Else If (Name='REPNE') Or (Name='REPNZ') Then Emit($F2) Else If Name='LOCK' Then Emit($F0)
  Else If Name='PUSHA' Then Begin Need286; Emit($60) End Else If Name='POPA' Then Begin Need286; Emit($61) End
  Else If Name='LEAVE' Then Begin Need286; Emit($C9) End
  Else If Name='ENTER' Then Begin Need286; A:=Operand; Need(tkComma); B:=Operand; Emit($C8); Immediate(A,2); Immediate(B,1) End
  Else If Name='INSB' Then Begin Need286; Emit($6C) End Else If Name='INSW' Then Begin Need286; Emit($6D) End
  Else If Name='OUTSB' Then Begin Need286; Emit($6E) End Else If Name='OUTSW' Then Begin Need286; Emit($6F) End
  Else If (Name='DB') Or (Name='DW') Or (Name='DD') Then Begin
   Repeat
    If (Name='DB') And TokenIsString Then Begin For K:=1 To Length(TokenText) Do Emit(Ord(TokenText[K])); NextToken End
    Else Begin A:=Operand; If A.Kind<>3 Then Fail(7,'Donnee immediat attendue'); If Name='DB' Then Immediate(A,1) Else If Name='DW' Then Immediate(A,2) Else Begin EmitWord(Word(A.Displacement)); EmitWord(Word(A.Displacement Shr 16)) End End;
    If Token<>tkComma Then Break; NextToken;
   Until False;
  End Else If Name[1]='F' Then FPU
  Else If (Name='JMP') Or (Name='CALL') Or (Condition(Name)<>0) Or
   (Name='LOOP') Or (Name='LOOPE') Or (Name='LOOPZ') Or (Name='LOOPNE') Or (Name='LOOPNZ') Or (Name='JCXZ') Then Begin
   A:=Operand;
   If (Name='JMP') Or (Name='CALL') Then Begin
    If (Name='CALL') And (A.Sym<>0) And (A.Kind=5) Then Begin
     If Symbols[A.Sym].Native Then Begin
      If Symbols[A.Sym].ParamCount<>0 Then Unsupported('CALL assembleur Borland avec parametres'); W:=NativeCall(A.Sym);
     End Else EmitLocalCall(A.Sym);
    End
    Else If A.Kind In [1,2] Then Begin Group:=4; If Name='CALL' Then Group:=2; If A.Width=4 Then Inc(Group); Prefix(A); Emit($FF); RM(Group,A) End
    Else Begin If Name='CALL' Then Emit($E8) Else Emit($E9); RelativeTarget(A) End;
   End Else Begin
    Op:=Condition(Name);
    If Op<>0 Then Emit2(Op Xor 1,3)
    Else Begin Op:=$E2; If Name='JCXZ' Then Op:=$E3 Else If (Name='LOOPE') Or (Name='LOOPZ') Then Op:=$E1 Else If (Name='LOOPNE') Or (Name='LOOPNZ') Then Op:=$E0; Emit2(Op,2); Emit2($EB,3) End;
    Emit($E9); RelativeTarget(A);
   End;
  End Else If (Name='RET') Or (Name='RETF') Then Begin
   If (TokenLine=InstructionLine) And (Token=tkConstant) Then Begin A:=Operand; If Name='RET' Then Emit($C2) Else Emit($CA); Immediate(A,2) End
   Else If (Name='RET') And (CurrentScope<>0) Then ProcedureExit
   Else If Name='RET' Then Emit($C3) Else Emit($CB);
  End Else If Name='INT' Then Begin A:=Operand; Emit($CD); Immediate(A,1) End
  Else If (Name='PUSH') Or (Name='POP') Then Begin
   A:=Operand;
   If (A.Kind=1) And (A.Width=2) Then Begin Op:=$50; If Name='POP' Then Op:=$58; Emit(Op+A.Reg) End
   Else If A.Kind=4 Then Begin If (Name='POP') And (A.Reg=1) Then Fail(5,'POP CS invalide'); Op:=6; If Name='POP' Then Op:=7; Emit(Op+A.Reg*8) End
   Else If (A.Kind=3) And (Name='PUSH') Then Begin Need286; Emit($68); Immediate(A,2) End
   Else If A.Kind=2 Then Begin If (A.Width<>0) And (A.Width<>2) Then Fail(26,'Pile assembleur Word'); Prefix(A); If Name='PUSH' Then Begin Emit($FF); RM(6,A) End Else Begin Emit($8F); RM(0,A) End End
   Else Fail(5,'Operande PUSH/POP invalide');
  End Else If (Name='INC') Or (Name='DEC') Or (Name='NEG') Or (Name='NOT') Or
   (Name='MUL') Or (Name='IMUL') Or (Name='DIV') Or (Name='IDIV') Then Begin
   A:=Operand; If Not (A.Width In [1,2]) Then Fail(26,'Taille assembleur requise'); W:=A.Width-1; Prefix(A);
   If (Name='IMUL') And (Token=tkComma) Then Begin
    Need286; If (A.Kind<>1) Or (A.Width<>2) Then Fail(26,'IMUL destination Word attendue');
    NextToken; B:=Operand; Need(tkComma); C:=Operand;
    If Not (B.Kind In [1,2]) Or Not (B.Width In [0,2]) Then Fail(26,'IMUL source Word attendue');
    Prefix(B); Emit($69); RM(A.Reg,B); Immediate(C,2); Continue;
   End;
   If (Name='INC') Or (Name='DEC') Then Begin Group:=0; If Name='DEC' Then Group:=1; Emit($FE+W) End
   Else Begin Group:=2; If Name='NEG' Then Group:=3 Else If Name='MUL' Then Group:=4 Else If Name='IMUL' Then Group:=5 Else If Name='DIV' Then Group:=6 Else If Name='IDIV' Then Group:=7; Emit($F6+W) End; RM(Group,A);
  End Else Begin
   A:=Operand; Need(tkComma); B:=Operand;
   If (Name='IN') Or (Name='OUT') Then Begin
    If Name='OUT' Then Begin C:=A; A:=B; B:=C End;
    If (A.Kind<>1) Or (A.Reg<>0) Or Not (A.Width In [1,2]) Then Fail(5,'IN/OUT exige AL ou AX');
    W:=A.Width-1;
    If B.Kind=3 Then Begin Op:=$E4; If Name='OUT' Then Op:=$E6; Emit(Op+W); Immediate(B,1) End
    Else If (B.Kind=1) And (B.Reg=2) And (B.Width=2) Then Begin Op:=$EC; If Name='OUT' Then Op:=$EE; Emit(Op+W) End
    Else Fail(5,'IN/OUT exige DX ou un port byte');
   End Else If (Name='LEA') Or (Name='LES') Or (Name='LDS') Then Begin
    If (A.Kind<>1) Or (A.Width<>2) Or (B.Kind<>2) Then Fail(5,'Operande LEA/LES/LDS invalide'); Prefix(B);
    If Name='LEA' Then Emit($8D) Else If Name='LES' Then Emit($C4) Else Emit($C5); RM(A.Reg,B);
   End Else If Name='MOV' Then Begin
    If A.Kind=4 Then Begin If A.Reg=1 Then Fail(5,'MOV CS invalide'); If Not (B.Width In [0,2]) Then Fail(26,'Registre segment exige Word'); Prefix(B); Emit($8E); RM(A.Reg,B) End
    Else If B.Kind=4 Then Begin If Not (A.Width In [0,2]) Then Fail(26,'Registre segment exige Word'); Prefix(A); Emit($8C); RM(B.Reg,A) End
    Else If B.Kind=3 Then Begin If Not (A.Width In [1,2]) Then Fail(26,'Taille MOV byte/word requise'); W:=A.Width-1;
     If A.Kind=1 Then Emit($B0+W*8+A.Reg) Else Begin Prefix(A); Emit($C6+W); RM(0,A) End; Immediate(B,A.Width);
    End Else Begin MatchWidth; If A.Kind=1 Then Begin Prefix(B); Emit($8A+W); RM(A.Reg,B) End
     Else If B.Kind=1 Then Begin Prefix(A); Emit($88+W); RM(B.Reg,A) End Else Fail(5,'MOV memoire/memoire invalide') End;
   End Else If (Name='SHL') Or (Name='SAL') Or (Name='SHR') Or (Name='SAR') Or
    (Name='ROL') Or (Name='ROR') Or (Name='RCL') Or (Name='RCR') Then Begin
    If Not (A.Width In [1,2]) Then Fail(26,'Taille decalage requise'); W:=A.Width-1; Group:=4;
    If Name='SHR' Then Group:=5 Else If Name='SAR' Then Group:=7 Else If Name='ROL' Then Group:=0 Else If Name='ROR' Then Group:=1 Else If Name='RCL' Then Group:=2 Else If Name='RCR' Then Group:=3;
    Prefix(A); If (B.Kind=1) And (B.Width=1) And (B.Reg=1) Then Begin Emit($D2+W); RM(Group,A) End
    Else If (B.Kind=3) And (B.Displacement=1) Then Begin Emit($D0+W); RM(Group,A) End
    Else If B.Kind=3 Then Begin Need286; Emit($C0+W); RM(Group,A); Immediate(B,1) End Else Fail(5,'CL ou immediat attendu');
   End Else If Name='XCHG' Then Begin MatchWidth; If A.Kind=1 Then Begin C:=A; A:=B; B:=C End; If B.Kind<>1 Then Fail(5,'XCHG avec registre attendu'); Prefix(A); Emit($86+W); RM(B.Reg,A) End
   Else Begin
    Op:=0; Group:=0;
    If Name='ADD' Then Begin Op:=$00; Group:=0 End Else If Name='OR' Then Begin Op:=$08; Group:=1 End
    Else If Name='ADC' Then Begin Op:=$10; Group:=2 End Else If Name='SBB' Then Begin Op:=$18; Group:=3 End
    Else If Name='AND' Then Begin Op:=$20; Group:=4 End Else If Name='SUB' Then Begin Op:=$28; Group:=5 End
    Else If Name='XOR' Then Begin Op:=$30; Group:=6 End Else If Name='CMP' Then Begin Op:=$38; Group:=7 End
    Else If Name='TEST' Then Op:=$84 Else Unsupported('instruction assembleur: '+Name);
    If B.Kind=3 Then Begin If Not (A.Width In [1,2]) Then Fail(26,'Taille arithmetique requise'); W:=A.Width-1; Prefix(A);
     If Name='TEST' Then Begin Emit($F6+W); RM(0,A) End Else Begin Emit($80+W); RM(Group,A) End; Immediate(B,A.Width);
    End Else Begin MatchWidth;
     If Name='TEST' Then Begin If B.Kind<>1 Then Fail(5,'TEST avec registre attendu'); Prefix(A); Emit(Op+W); RM(B.Reg,A) End
     Else If A.Kind=1 Then Begin Prefix(B); Emit(Op+2+W); RM(A.Reg,B) End
     Else If B.Kind=1 Then Begin Prefix(A); Emit(Op+W); RM(B.Reg,A) End Else Fail(5,'Operation memoire/memoire invalide');
    End;
   End;
  End;
 End;
 For I:=1 To RefCount Do Begin K:=References[I].LabelIndex; If Not Labels[K].Defined Then Fail(3,'Label assembleur inconnu: '+Labels[K].Name); PatchJump(References[I].Position,Labels[K].Address) End;
 InAssembler:=SavedAssembler; Need(tkEnd);
End;

Procedure LoopEnter;Begin
 If LoopDepth=255 Then Fail(145,'Boucles trop imbriquees');
 Inc(LoopDepth);
End;

Procedure LoopLeave(BreakTarget,ContinueTarget: Word);
{ Resout les Break/Continue du niveau courant puis ferme la boucle. }
Begin
 While (LoopJumpCount>0) And (LoopJumps[LoopJumpCount].Depth=LoopDepth) Do Begin
  If LoopJumps[LoopJumpCount].IsBreak Then PatchJump(LoopJumps[LoopJumpCount].Position,BreakTarget)
  Else PatchJump(LoopJumps[LoopJumpCount].Position,ContinueTarget);
  Dec(LoopJumpCount);
 End;
 Dec(LoopDepth);
End;

Procedure LoopJump(IsBreak: Boolean);
{ Procedures standard Break et Continue. }
Begin
 If LoopDepth=0 Then Fail(109,'');
 If LoopJumpCount=MaxLoopJumps Then Fail(124,'Trop de Break/Continue');
 Inc(LoopJumpCount); LoopJumps[LoopJumpCount].Depth:=LoopDepth;
 LoopJumps[LoopJumpCount].IsBreak:=IsBreak; LoopJumps[LoopJumpCount].Position:=Jump;
End;

Procedure Load32(I: Word);
{ DX:AX := variable Longint locale ou globale (FOR Longint). }
Begin
 If Symbols[I].ByReference Or Symbols[I].Native Then Unsupported('variable FOR Longint indirecte');
 If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope);
  Emit($36); Emit2($8B,$87); EmitWord(Symbols[I].Addr);
  Emit($36); Emit2($8B,$97); EmitWord(Symbols[I].Addr+2);
 End Else Begin
  Emit($A1); DataAddress(Symbols[I].Addr); Emit2($8B,$16); DataAddress(Symbols[I].Addr+2);
 End;
End;

Procedure Store32(I: Word);
Begin
 If Symbols[I].Local Then Begin
  ScopeAddress(Symbols[I].Scope);
  Emit($36); Emit2($89,$87); EmitWord(Symbols[I].Addr);
  Emit($36); Emit2($89,$97); EmitWord(Symbols[I].Addr+2);
 End Else Begin
  Emit($A3); DataAddress(Symbols[I].Addr); Emit2($89,$16); DataAddress(Symbols[I].Addr+2);
 End;
End;

Procedure ForLongint(I: Word);
{ FOR sur une variable Longint: la borne (hi,lo) reste sur la pile. }
Var Start,P1,P2,P3,Q1,ContinueAt: Word; Direction,Ignored: Byte;
Procedure Extend;
Begin If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End End;
Begin
 Need(tkAssign); Ignored:=Expression; RequireInteger(Ignored); Extend; Store32(I);
 Direction:=Token;
 If Not (Direction In [tkTo,tkDownto]) Then Fail(58,'');
 NextToken; Ignored:=Expression; RequireInteger(Ignored); Extend;
 Emit($52); Emit($50); Need(tkDo);
 Start:=CodeSize; Load32(I); Emit2($89,$E3);                 { mov bx,sp }
 Emit($36); Emit2($3B,$57); Emit(2);                          { cmp dx,ss:[bx+2] }
 { Le motif "Jcc +3; JMP cible" saute vers la cible quand cc est faux. }
 If Direction=tkTo Then Begin
  Emit2($7D,3); P1:=Jump; Emit2($7E,3); P2:=Jump;             { dx<hi: corps; dx>hi: sortie }
  Emit($36); Emit2($3B,$07); Emit2($76,3); P3:=Jump;          { cmp ax,ss:[bx]; ax>lo: sortie }
 End Else Begin
  Emit2($7E,3); P1:=Jump; Emit2($7D,3); P2:=Jump;             { dx>hi: corps; dx<hi: sortie }
  Emit($36); Emit2($3B,$07); Emit2($73,3); P3:=Jump;          { cmp ax,ss:[bx]; ax<lo: sortie }
 End;
 PatchJump(P1,CodeSize); LoopEnter; Statement;
 ContinueAt:=CodeSize;
 { Egalite avec la borne testee AVANT l'increment (pas de debordement). }
 Load32(I); Emit2($89,$E3); Emit($36); Emit2($3B,$57); Emit(2); Emit2($75,8);
 Emit($36); Emit2($3B,$07); Emit2($75,3); Q1:=Jump;
 If Direction=tkTo Then Begin Emit($05); EmitWord(1); Emit2($83,$D2); Emit(0) End
 Else Begin Emit($2D); EmitWord(1); Emit2($83,$DA); Emit(0) End;
 Store32(I); JumpTo(Start);
 PatchJump(P2,CodeSize); PatchJump(P3,CodeSize); PatchJump(Q1,CodeSize);
 LoopLeave(CodeSize,ContinueAt);
 Emit2($83,$C4); Emit(4);
End;

Procedure CaseStatement;
{ CASE selecteur OF etiquettes, intervalles et partie ELSE (TP 7.0). Le
  selecteur reste dans AX (DX:AX pour Longint) pendant les comparaisons. }
Var SelType: Word; T: Byte; Wide, Signed: Boolean;
 EndJumps: Array[1..512] Of Word; EndCount: Word;
 BodyJumps: Array[1..64] Of Word; BodyCount, NextLabel, N1, N2, K: Word;
 V1, V2: TConstValue;
Procedure CheckLabel(V: TConstValue);
Begin
 If Not (Types[V.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Or
    Not CompatibleTypes(SelType,V.TypeId) Then Fail(74,'');
 If (V.Value<Types[SelType].LowBound) Or (V.Value>Types[SelType].HighBound) Then Fail(112,'');
End;
Procedure Jcc(SignedCode,UnsignedCode: Byte);
Begin If Signed Then Emit2(SignedCode,3) Else Emit2(UnsignedCode,3) End;
Begin
 NextToken; T:=Expression; RequireOrdinal(T); SelType:=ExprType;
 Wide:=Types[SelType].Width=4; Signed:=Types[SelType].Signed;
 If (T=ttInteger) And Not Wide Then Signed:=Not ExprUnsigned;
 Need(tkOf); EndCount:=0;
 While Not (Token In [tkEnd,tkElse]) Do Begin
  BodyCount:=0;
  Repeat
   V1:=ConstExpression; CheckLabel(V1);
   If BodyCount=64 Then Fail(124,'Trop d''etiquettes CASE');
   If Token=tkRange Then Begin
    NextToken; V2:=ConstExpression; CheckLabel(V2);
    If V1.Value>V2.Value Then Fail(28,'');
    If Wide Then Unsupported('intervalle CASE sur Longint');
    Emit($3D); EmitWord(Word(V1.Value)); Jcc($7D,$73); N1:=Jump;
    Emit($3D); EmitWord(Word(V2.Value)); Jcc($7E,$76); N2:=Jump;
    Inc(BodyCount); BodyJumps[BodyCount]:=Jump;
    PatchJump(N1,CodeSize); PatchJump(N2,CodeSize);
   End Else Begin
    Emit($3D); EmitWord(Word(V1.Value)); Emit2($74,3); N1:=Jump;
    If Wide Then Begin
     Emit2($81,$FA); EmitWord(Word(V1.Value Shr 16)); Emit2($74,3); N2:=Jump;
    End Else N2:=0;
    Inc(BodyCount); BodyJumps[BodyCount]:=Jump;
    PatchJump(N1,CodeSize); If N2<>0 Then PatchJump(N2,CodeSize);
   End;
   If Token<>tkComma Then Break; NextToken;
  Until False;
  Need(tkColon);
  NextLabel:=Jump;
  For K:=1 To BodyCount Do PatchJump(BodyJumps[K],CodeSize);
  Statement;
  If EndCount=512 Then Fail(124,'Trop de branches CASE');
  Inc(EndCount); EndJumps[EndCount]:=Jump;
  PatchJump(NextLabel,CodeSize);
  If Token=tkSemi Then NextToken Else If Not (Token In [tkEnd,tkElse]) Then Need(tkSemi);
 End;
 If Token=tkElse Then Begin NextToken; StatementList(tkEnd) End;
 Need(tkEnd);
 For K:=1 To EndCount Do PatchJump(EndJumps[K],CodeSize);
End;

Procedure StatementList(Stop: Byte);Begin
 While Token<>Stop Do Begin
  If Token=tkEOF Then Fail(10,'Fin de fichier inattendue');
  Statement;
  If Token=Stop Then Break;
  Need(tkSemi);
 End;
End;

Function InlineBytes(Direct: Boolean): TShortString;
{ Inline(octet/octet/...): "<" force un octet, ">" un mot; une variable
  globale designe son offset (uniquement en emission directe). }
Var S: TShortString; V: TConstValue; Size: Byte; I: Word; Name: TShortString;
Begin
 S:=''; Need(tkLP);
 Repeat
  Size:=0;
  If Token=tkLess Then Begin Size:=1; NextToken End Else If Token=tkGreater Then Begin Size:=2; NextToken End;
  I:=0; If Token=tkIdent Then I:=FindLexicalSymbol(TokenText);
  If (I<>0) And (Symbols[I].Kind=skVar) Then Begin
   If Not Direct Or Symbols[I].Local Or Symbols[I].ByReference Then Fail(105,'');
   Name:=TokenText; NextToken; V.Value:=0;
   If Token In [tkPlus,tkMinus] Then Begin Size:=Token; NextToken; V:=ConstFactor; ConstInteger(V); If Size=tkMinus Then V.Value:=-V.Value End;
   For I:=1 To Length(S) Do Emit(Ord(S[I])); S:='';
   DataAddress(Symbols[FindLexicalSymbol(Name)].Addr+V.Value);
  End Else Begin
   V:=ConstFactor; ConstInteger(V);
   If (Size=0) And ((V.Value<0) Or (V.Value>255)) Then Size:=2;
   If Length(S)>253 Then Fail(105,'');
   S:=S+Chr(Word(V.Value) And 255);
   If Size=2 Then S:=S+Chr(Word(V.Value) Shr 8);
  End;
  If Token<>tkSlash Then Break; NextToken;
 Until False;
 Need(tkRP); InlineBytes:=S;
End;

Procedure DefineLabel(I: Word);
Var K: Word;
Begin
 If Symbols[I].HasBody Then Fail(81,Symbols[I].Name);
 Symbols[I].HasBody:=True; Symbols[I].Addr:=CodeSize;
 For K:=1 To LabelJumpCount Do If LabelJumps[K].Sym=I Then Begin
  PatchJump(LabelJumps[K].Position,CodeSize); LabelJumps[K].Sym:=0;
 End;
End;

Procedure WithStatement;
{ WITH r DO: l'adresse du record est conservee dans un pointeur cache et
  chaque champ devient une variable par reference d'une pseudo-portee. }
Var I,T,P,F,W,Saved: Word; Name: TShortString;
Begin
 Saved:=CurrentScope; NextToken;
 Repeat
  If Token<>tkIdent Then Fail(2,'');
  Name:=TokenText; NextToken; I:=ResolveSymbol(Name); T:=Designator(I);
  If Types[T].Typ<>ttRecord Then Fail(75,'');
  If ScopeCount=MaxScopes Then Fail(145,'');
  Inc(ScopeCount); W:=ScopeCount; FillChar(Scopes[W],SizeOf(TScopeInfo),0);
  Scopes[W].Parent:=CurrentScope; Scopes[W].Owner:=CurrentUnit;
  Scopes[W].ProcSymbol:=Scopes[CurrentScope].ProcSymbol; Scopes[W].Pseudo:=True;
  CurrentScope:=W;
  P:=NewSymbol('$WITH'); Symbols[P].Kind:=skVar; ApplyType(P,8); AllocateVariable(P);
  Symbols[P].DebugVisible:=False;
  If Symbols[P].Local Then Begin
   ScopeAddress(W); Emit($36); Emit2($89,$BF); EmitWord(Symbols[P].Addr);
   Emit($36); Emit2($8C,$87); EmitWord(Symbols[P].Addr+2);
  End Else Begin
   Emit2($89,$3E); DataAddress(Symbols[P].Addr); Emit2($8C,$06); DataAddress(Symbols[P].Addr+2);
  End;
  F:=TypeExtras[T].FirstField;
  While F<>0 Do Begin
   I:=NewSymbol(Fields[F].Name); Symbols[I].Kind:=skVar; ApplyType(I,Fields[F].TypeId);
   Symbols[I].Local:=Symbols[P].Local; Symbols[I].ByReference:=True; Symbols[I].Addr:=Symbols[P].Addr;
   Symbols[I].WithOffset:=Fields[F].Offset; Symbols[I].DebugVisible:=False;
   F:=Fields[F].Next;
  End;
  If Token<>tkComma Then Break; NextToken;
 Until False;
 Need(tkDo); Statement;
 CurrentScope:=Saved;
End;

Function IsMemPort(Name: TShortString): Boolean;
Begin
 IsMemPort:=(Name='MEM') Or (Name='MEMW') Or (Name='MEML') Or (Name='PORT') Or (Name='PORTW');
End;

Procedure MemPortIndex(Name: TShortString);
{ Mem[seg:ofs] -> ES:DI; Port[n] -> DX. }
Begin
 Need(tkLB); RequireInteger(Expression);
 If Name[1]='M' Then Begin
  Emit($50); Need(tkColon); RequireInteger(Expression); Emit2($89,$C7); Emit($07);
 End Else Emit2($89,$C2);
 Need(tkRB);
End;

Function MemPortLoad(Name: TShortString): Word;
Begin
 MemPortIndex(Name);
 If Name='MEM' Then Begin Emit($26); Emit2($8A,$05); Emit2($30,$E4); MemPortLoad:=2 End
 Else If Name='MEMW' Then Begin Emit($26); Emit2($8B,$05); MemPortLoad:=3 End
 Else If Name='MEML' Then Begin Emit($26); Emit2($8B,$05); Emit($26); Emit2($8B,$55); Emit(2); MemPortLoad:=9 End
 Else If Name='PORT' Then Begin Emit($EC); Emit2($30,$E4); MemPortLoad:=2 End
 Else Begin Emit($ED); MemPortLoad:=3 End;
End;

Procedure MemPortStore(Name: TShortString);
Var T: Byte;
Begin
 MemPortIndex(Name);
 If Name[1]='M' Then Begin Emit($06); Emit($57) End Else Emit($52);
 Need(tkAssign); T:=Expression;
 If Not (T In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(26,'');
 If Name='MEML' Then Begin If Types[ExprType].Width<>4 Then Begin If ExprUnsigned Then Emit2($31,$D2) Else Emit($99) End End;
 If Name[1]='M' Then Begin Emit($5F); Emit($07) End Else Emit($5A);
 If Name='MEM' Then Begin Emit($26); Emit2($88,$05) End
 Else If Name='MEMW' Then Begin Emit($26); Emit2($89,$05) End
 Else If Name='MEML' Then Begin Emit($26); Emit2($89,$05); Emit($26); Emit2($89,$55); Emit(2) End
 Else If Name='PORT' Then Emit($EE) Else Emit($EF);
End;

Procedure StatementBody;
Var
 I, Start, P, Q, ContinueAt: Word;
 Direction, Ignored: Byte;
 Name, VarName: TShortString;
Begin
 DebugLineEntry;
 { Etiquettes: "1:" ou "Ident:" devant l'instruction. }
 While ((Token=tkConstant) And Not TokenIsString And Not TokenIsReal) Or
       ((Token=tkIdent) And (FindLexicalSymbol(TokenText)<>0) And (Symbols[FindLexicalSymbol(TokenText)].Kind=skLabel)) Do Begin
  I:=FindLexicalSymbol(TokenText);
  If (I=0) Or (Symbols[I].Kind<>skLabel) Then Fail(113,'');
  DefineLabel(I); NextToken; Need(tkColon); DebugLineEntry;
 End;
 Case Token Of
 tkAsm:AsmStatement;
 tkWith:WithStatement;
 tkGoto:
 Begin
  NextToken;
  If Not ((Token=tkIdent) Or ((Token=tkConstant) And Not TokenIsString And Not TokenIsReal)) Then Fail(35,'');
  I:=FindLexicalSymbol(TokenText);
  If (I=0) Or (Symbols[I].Kind<>skLabel) Then Fail(35,'');
  If Symbols[I].HasBody Then JumpTo(Symbols[I].Addr)
  Else Begin
   If LabelJumpCount=512 Then Fail(124,'Trop de GOTO');
   Inc(LabelJumpCount); LabelJumps[LabelJumpCount].Sym:=I; LabelJumps[LabelJumpCount].Position:=Jump;
  End;
  NextToken;
 End;
 tkBegin:
 Begin
  NextToken; StatementList(tkEnd); Need(tkEnd)
 End;
 tkIf:
 Begin
  NextToken; RequireBoolean(Expression); Need(tkThen); P:=JumpZero;
  Statement;
  If Token=tkElse Then Begin
   Q:=Jump; PatchJump(P,CodeSize); NextToken; Statement; PatchJump(Q,CodeSize);
  End Else PatchJump(P,CodeSize);
 End;
 tkCase:CaseStatement;
 tkInline:Begin NextToken; VarName:=InlineBytes(True); For P:=1 To Length(VarName) Do Emit(Ord(VarName[P])) End;
 tkWhile:
 Begin
  NextToken; Start:=CodeSize; RequireBoolean(Expression); Need(tkDo);
  P:=JumpZero; LoopEnter; Statement; JumpTo(Start); PatchJump(P,CodeSize);
  LoopLeave(CodeSize,Start);
 End;
 tkRepeat:
 Begin
  NextToken; Start:=CodeSize; LoopEnter; StatementList(tkUntil); Need(tkUntil);
  Q:=CodeSize; { Continue reprend a l'evaluation de la condition }
  RequireBoolean(Expression); P:=JumpZero; PatchJump(P,Start);
  LoopLeave(CodeSize,Q);
 End;
 tkFor:
 Begin
  NextToken;
  If Token<>tkIdent Then Fail(2,'Variable de boucle attendue');
  Name:=TokenText; NextToken; I:=ResolveSymbol(Name);
  If (Symbols[I].Kind<>skVar) Or Not (Symbols[I].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then
   Fail(97,'Variable de controle FOR non ordinale');
  If Symbols[I].Width=4 Then Begin ForLongint(I); Exit End;
  Need(tkAssign); Ignored:=Expression;
  If Not CompatibleTypes(SymbolType(I),ExprType) Then Fail(26,'Valeur initiale FOR');
  If OptionBits And 2<>0 Then RangeBounds(Types[SymbolType(I)].LowBound,Types[SymbolType(I)].HighBound,ExprType);
  SaveSymbol(I);
  Direction:=Token;
  If Not (Direction In [tkTo,tkDownto]) Then Fail(58,'TO ou DOWNTO attendu');
  NextToken; Ignored:=Expression;
  If Not CompatibleTypes(SymbolType(I),ExprType) Then Fail(26,'Borne FOR');
  If OptionBits And 2<>0 Then RangeBounds(Types[SymbolType(I)].LowBound,Types[SymbolType(I)].HighBound,ExprType);
  { Comme TP, la borne est tronquee a la taille de la variable de controle
    (For B:=1 To -1 avec B: Byte boucle jusqu'a 255 puis s'arrete). }
  If Symbols[I].Width=1 Then Emit2($30,$E4);
  Emit($50); Need(tkDo);
  Start:=CodeSize; LoadSymbol(I); Emit2($89,$E3); Emit($36); Emit2($3B,$07);
  If Types[SymbolType(I)].Signed Then Begin
   If Direction=tkTo Then Emit2($7E,$03) Else Emit2($7D,$03);
  End Else Begin
   If Direction=tkTo Then Emit2($76,$03) Else Emit2($73,$03);
  End;
  P:=Jump; LoopEnter; Statement;
      { Tester l'egalite AVANT inc/dec evite le debordement a +/-32768. }
  ContinueAt:=CodeSize;
  LoadSymbol(I); Emit2($89,$E3); Emit($36); Emit2($3B,$07); Emit2($75,$03); Q:=Jump;
  If Direction=tkTo Then Emit($40) Else Emit($48);
  SaveSymbol(I); JumpTo(Start); PatchJump(P,CodeSize); PatchJump(Q,CodeSize);
  { Break sort avant la liberation de la borne empilee, comme P et Q. }
  LoopLeave(CodeSize,ContinueAt);
  Emit2($83,$C4); Emit(2);
 End;
 tkIdent:
 Begin
  Name:=TokenText; NextToken;
  I:=FindLexicalSymbol(Name);
  If (Token=tkLP) And (((I<>0) And (Symbols[I].Kind=skType)) Or ((I=0) And (BuiltinType(Name)<>0))) Then Begin
   { Type(Variable) := expression : transtypage de variable en destination }
   If I<>0 Then P:=Symbols[I].TypeId Else P:=BuiltinType(Name);
   NextToken; Q:=VariableArgument; Need(tkRP); AssignToDesignator(P);
  End Else
  If (I=0) And (Token=tkLB) And IsMemPort(Name) Then MemPortStore(Name)
  Else If (I=0) And (Token<>tkDot) And StandardProcedure(Name) Then
  Else If (I=0) And (Token<>tkDot) And ((Name='WRITE') Or (Name='WRITELN')) Then WriteStatement(Name=
  'WRITELN')
  Else If (I=0) And (Token<>tkDot) And ((Name='BREAK') Or (Name='CONTINUE')) Then LoopJump(Name='BREAK')
  Else If (I=0) And (Token<>tkDot) And (Name='HALT') Then Begin
   If Token=tkLP Then Begin
    NextToken; RequireInteger(Expression); Need(tkRP)
   End
   Else LoadImmediate(0);
   CallTo(RuntimeHalt);
  End Else If (I=0) And (Token<>tkDot) And (Name='EXIT') Then Begin
   If Not InProcedure Then Begin LoadImmediate(0); CallTo(RuntimeHalt) End
   Else If RealScope(CurrentScope)<>0 Then ProcedureExit Else Emit($C3);
  End Else If (I=0) And (Token<>tkDot) And ((Name='INC') Or (Name='DEC')) Then Begin
   Need(tkLP);
   If Token<>tkIdent Then Fail(2,'Variable attendue');
   VarName:=TokenText; NextToken; I:=ResolveSymbol(VarName);
   If (Symbols[I].Kind<>skVar) Or (Symbols[I].Typ<>ttInteger) Then          Fail(38,
   'Variable entiere attendue');
   LoadSymbol(I);
   If Token=tkComma Then Begin
    Emit($50); NextToken; RequireInteger(Expression);
    Emit2($89,$C3); Emit($58);
    If Name='INC' Then Emit2($01,$D8) Else Emit2($29,$D8);
   End Else If Name='INC' Then Emit($40) Else Emit($48);
   Need(tkRP); SaveSymbol(I);
  End Else
  Begin
   I:=ResolveSymbol(Name);
   If Symbols[I].Kind=skProc Then Begin
    { $X+: le resultat (AX ou DX:AX) d'une fonction est simplement ignore. }
    If (Symbols[I].Typ<>ttVoid) And Not ExtendedSyntax Then Fail(91,'Resultat de fonction ignore sans $X+');
    If Symbols[I].Native Then Ignored:=NativeCall(I) Else Ignored:=UserCall(I);
   End Else Assignment(I);
  End;
 End;
 tkSemi,tkEnd,tkElse,tkUntil:; { instruction vide }
 tkEOF:Fail(10,'Fin de fichier inattendue');
 Else Unsupported('instruction: '+TokenText);
End;
End;

Procedure Statement;
Begin StatementBody; TempRelease End;

Function ConstText(V: TConstValue): TShortString;
Begin
 If Types[V.TypeId].Typ=ttChar Then ConstText:=Chr(V.Value)
 Else If Types[V.TypeId].Typ=ttString Then ConstText:=V.Text
 Else Begin Fail(26,'Constante chaine attendue'); ConstText:='' End;
End;

Procedure ConstInteger(V: TConstValue);
Begin If Types[V.TypeId].Typ<>ttInteger Then Fail(26,'Constante entiere attendue') End;
{ forward: ConstInteger }

Function ConstReal(V: TConstValue): Double;
Begin
 If Types[V.TypeId].Typ=ttReal Then ConstReal:=V.RealValue
 Else Begin ConstInteger(V); ConstReal:=V.Value End;
End;
Function RealHost(A: Word): Double;
Var V: Double; I,E: Integer;
Begin
 V:=Data[A+1]/256;
 For I:=2 To 4 Do V:=(V+Data[A+I])/256;
 V:=(V+(Data[A+5] And 127))/128+1; E:=Integer(Data[A])-129;
 If Data[A]=0 Then V:=0 Else Begin
  While E>0 Do Begin V:=V*2; Dec(E) End;
  While E<0 Do Begin V:=V/2; Inc(E) End;
  If Data[A+5] And 128<>0 Then V:=-V;
 End; RealHost:=V;
End;
Function ConstCastType(Name: TShortString): Word;
{ Identificateur de type ordinal utilisable en transtypage constant. }
Var J: Word;
Begin
 ConstCastType:=0; J:=FindLexicalSymbol(Name);
 If (J<>0) And (Symbols[J].Kind=skType) Then ConstCastType:=Symbols[J].TypeId
 Else If J=0 Then ConstCastType:=BuiltinType(Name);
End;

Function ConstFactor: TConstValue;
Var V: TConstValue; Name: TShortString; I, T: Word;
Begin
 FillChar(V,SizeOf(V),0); V.TypeId:=1;
 If Token=tkConstant Then Begin
  If TokenIsReal Then Begin V.TypeId:=11; V.RealValue:=TokenReal End
  Else If TokenIsString Then Begin
   If Length(TokenText)=1 Then Begin V.TypeId:=6; V.Value:=Ord(TokenText[1]) End
   Else Begin V.TypeId:=7; V.Text:=TokenText End;
  End Else Begin
   V.Value:=TokenValue;
   If (V.Value>32767) And (V.Value<=65535) Then V.TypeId:=3;
  End;
  NextToken;
 End Else If Token=tkLP Then Begin NextToken; V:=ConstExpression; Need(tkRP) End
 Else If Token=tkNot Then Begin
  NextToken; V:=ConstFactor;
  If Types[V.TypeId].Typ=ttBoolean Then V.Value:=1-V.Value
  Else Begin ConstInteger(V); V.Value:=Not V.Value; V.TypeId:=1 End;
 End Else If Token=tkIdent Then Begin
  Name:=TokenText; NextToken;
  If (FindLexicalSymbol(Name)=0) And (Token<>tkDot) And ((Name='TRUE') Or (Name='FALSE')) Then Begin
   V.TypeId:=5; If Name='TRUE' Then V.Value:=1;
  End Else If (FindLexicalSymbol(Name)=0) And (Token<>tkDot) And (Token=tkLP) And
   ((Name='ORD') Or (Name='CHR') Or (Name='LENGTH') Or (Name='ABS') Or
    (Name='SQR') Or (Name='SUCC') Or (Name='PRED') Or (Name='SIZEOF') Or
    (Name='HIGH') Or (Name='LOW')) Then Begin
   NextToken;
   If Name='SIZEOF' Then Begin
    T:=SizeArgument; V.Value:=TypeExtras[T].Size;
   End Else If (Name='HIGH') Or (Name='LOW') Then Begin
    T:=SizeArgument;
    If Types[T].Typ=ttArray Then T:=TypeExtras[T].IndexType;
    If Types[T].Typ=ttString Then Begin
     If Name='HIGH' Then V.Value:=Types[T].Capacity Else V.Value:=0; V.TypeId:=1;
    End Else Begin
     If Not (Types[T].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(29,'');
     If Name='HIGH' Then V.Value:=Types[T].HighBound Else V.Value:=Types[T].LowBound;
     V.TypeId:=T;
    End;
   End Else Begin
    V:=ConstExpression;
    If Name='ORD' Then Begin
     If Not (Types[V.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(26,'Constante ordinale attendue');
     V.TypeId:=1;
    End Else If Name='CHR' Then Begin
     ConstInteger(V); If (V.Value<0) Or (V.Value>255) Then Fail(76,'CHR hors limites'); V.TypeId:=6;
    End Else If Name='LENGTH' Then Begin V.Value:=Length(ConstText(V)); V.TypeId:=1 End
    Else If (Name='SUCC') Or (Name='PRED') Then Begin
     If Not (Types[V.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(26,'Constante ordinale attendue');
     If Name='SUCC' Then Inc(V.Value) Else Dec(V.Value);
     If (V.Value<Types[V.TypeId].LowBound) Or (V.Value>Types[V.TypeId].HighBound) Then
      Fail(76,'SUCC/PRED hors limites');
    End Else If Types[V.TypeId].Typ=ttReal Then Begin
     If Name='ABS' Then V.RealValue:=Abs(V.RealValue) Else V.RealValue:=V.RealValue*V.RealValue;
    End Else Begin
     ConstInteger(V);
     If (V.Value=-2147483647-1) Or ((Name='SQR') And (Abs(V.Value)>46340)) Then
      Fail(76,'Debordement constant');
     If Name='ABS' Then V.Value:=Abs(V.Value) Else V.Value:=V.Value*V.Value;
     V.TypeId:=1;
    End;
   End;
   Need(tkRP);
  End Else If (Token=tkLP) And (ConstCastType(Name)<>0) Then Begin
   { Transtypage ordinal: Byte(' '), Char(65), Word(-1)... }
   T:=ConstCastType(Name); NextToken; V:=ConstExpression; Need(tkRP);
   If Not (Types[V.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Or
      Not (Types[T].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(61,'');
   If Types[T].Width=1 Then V.Value:=V.Value And $FF Else If Types[T].Width=2 Then V.Value:=V.Value And $FFFF;
   If Types[T].Signed And (Types[T].Width=1) And (V.Value>127) Then Dec(V.Value,256);
   If Types[T].Signed And (Types[T].Width=2) And (V.Value>32767) Then Dec(V.Value,65536);
   V.TypeId:=T; V.Text:='';
  End Else Begin
   I:=ResolveSymbol(Name);
   If Symbols[I].Kind<>skConst Then Fail(31,'Constante attendue: '+Name);
   V.TypeId:=SymbolType(I); V.Value:=Symbols[I].Value; V.Text:=Symbols[I].StrValue;
   If Types[V.TypeId].Typ=ttReal Then V.RealValue:=RealHost(Symbols[I].Addr);
  End;
 End Else Begin Fail(31,'Expression constante attendue') End;
 ConstFactor:=V;
End;

Function ConstTerm: TConstValue;
Var V,R: TConstValue; Op: Byte; Check: Real;
Begin
 V:=ConstFactor;
 While Token In [tkTimes,tkDiv,tkMod,tkAnd,tkShl,tkShr,tkSlash] Do Begin
  Op:=Token; NextToken; R:=ConstFactor;
  If (Op=tkSlash) Or (Types[V.TypeId].Typ=ttReal) Or (Types[R.TypeId].Typ=ttReal) Then Begin
   If Not (Op In [tkTimes,tkSlash]) Then Fail(26,'Operation constante reelle');
   If Op=tkTimes Then V.RealValue:=ConstReal(V)*ConstReal(R)
   Else Begin If ConstReal(R)=0 Then Fail(62,'Division constante par zero'); V.RealValue:=ConstReal(V)/ConstReal(R) End;
   V.TypeId:=11; Continue;
  End;
  If (Op=tkAnd) And (Types[V.TypeId].Typ=ttBoolean) Then Begin
   If Types[R.TypeId].Typ<>ttBoolean Then Fail(26,'AND constant');
   V.Value:=V.Value And R.Value;
  End Else Begin
   ConstInteger(V); ConstInteger(R);
   Case Op Of
    tkTimes:Begin
     Check:=V.Value; Check:=Check*R.Value;
     If (Check<-2147483647.0-1) Or (Check>2147483647.0) Then Fail(76,'Debordement constant');
     V.Value:=V.Value*R.Value;
    End;
    tkDiv,tkMod:Begin
     If R.Value=0 Then Fail(62,'Division constante par zero');
     If (V.Value=-2147483647-1) And (R.Value=-1) Then Fail(76,'Debordement constant');
     If Op=tkDiv Then V.Value:=V.Value Div R.Value Else V.Value:=V.Value Mod R.Value;
    End;
    tkAnd:V.Value:=V.Value And R.Value;
    tkShl,tkShr:Begin
     If (R.Value<0) Or (R.Value>31) Then Fail(76,'Decalage constant hors limites');
     If Op=tkShl Then V.Value:=V.Value Shl R.Value Else V.Value:=V.Value Shr R.Value;
    End;
   End;
   V.TypeId:=1;
  End;
 End;
 ConstTerm:=V;
End;

Function ConstSimple: TConstValue;
Var V,R: TConstValue; Op, Sign: Byte; Check: Real; S: TShortString;
Begin
 Sign:=0;
 If Token In [tkPlus,tkMinus] Then Begin Sign:=Token; NextToken End;
 V:=ConstTerm;
 If (Sign<>0) And (Types[V.TypeId].Typ<>ttReal) Then ConstInteger(V);
 If (Sign=tkMinus) And (Types[V.TypeId].Typ=ttReal) Then V.RealValue:=-V.RealValue
 Else If Sign=tkMinus Then Begin
  If V.Value=-2147483647-1 Then Fail(76,'Debordement constant');
  V.Value:=-V.Value; V.TypeId:=1;
 End;
 While Token In [tkPlus,tkMinus,tkOr,tkXor] Do Begin
  Op:=Token; NextToken; R:=ConstTerm;
  If (Types[V.TypeId].Typ=ttReal) Or (Types[R.TypeId].Typ=ttReal) Then Begin
   If Not (Op In [tkPlus,tkMinus]) Then Fail(26,'Operation constante reelle');
   If Op=tkPlus Then V.RealValue:=ConstReal(V)+ConstReal(R) Else V.RealValue:=ConstReal(V)-ConstReal(R);
   V.TypeId:=11; Continue;
  End;
  If (Op=tkPlus) And (Types[V.TypeId].Typ In [ttString,ttChar]) Then Begin
   S:=ConstText(V);
   V.Text:=S+ConstText(R); V.TypeId:=7; { TP tronque silencieusement a 255 }
  End Else If (Op In [tkOr,tkXor]) And (Types[V.TypeId].Typ=ttBoolean) Then Begin
   If Types[R.TypeId].Typ<>ttBoolean Then Fail(26,'Operation booleenne constante');
   If Op=tkOr Then V.Value:=V.Value Or R.Value Else V.Value:=V.Value Xor R.Value;
  End Else Begin
   ConstInteger(V); ConstInteger(R); Check:=V.Value;
   Case Op Of
    tkPlus:Begin Check:=Check+R.Value End;
    tkMinus:Begin Check:=Check-R.Value End;
   End;
   If (Check<-2147483647.0-1) Or (Check>2147483647.0) Then Fail(76,'Debordement constant');
   Case Op Of
    tkPlus:V.Value:=V.Value+R.Value; tkMinus:V.Value:=V.Value-R.Value;
    tkOr:V.Value:=V.Value Or R.Value; tkXor:V.Value:=V.Value Xor R.Value;
   End;
   V.TypeId:=1;
  End;
 End;
 ConstSimple:=V;
End;

Function ConstExpression: TConstValue;
Var V,R: TConstValue; Op: Byte; C: Integer; S,T: TShortString; B: Boolean;
Begin
 V:=ConstSimple;
 If Token In [tkEqual,tkNE,tkLess,tkGreater,tkLE,tkGE] Then Begin
  Op:=Token; NextToken; R:=ConstSimple;
  If (Types[V.TypeId].Typ=ttReal) Or (Types[R.TypeId].Typ=ttReal) Then Begin
   C:=0; If ConstReal(V)<ConstReal(R) Then C:=-1 Else If ConstReal(V)>ConstReal(R) Then C:=1;
  End Else If Types[V.TypeId].Typ In [ttString,ttChar] Then Begin
   S:=ConstText(V); T:=ConstText(R); C:=0; If S<T Then C:=-1 Else If S>T Then C:=1;
  End Else Begin
   If Not CompatibleTypes(V.TypeId,R.TypeId) Then Fail(26,'Comparaison constante incompatible');
   C:=0; If V.Value<R.Value Then C:=-1 Else If V.Value>R.Value Then C:=1;
  End;
  B:=False;
  Case Op Of
   tkEqual:B:=C=0; tkNE:B:=C<>0; tkLess:B:=C<0;
   tkGreater:B:=C>0; tkLE:B:=C<=0; tkGE:B:=C>=0;
  End;
  V.TypeId:=5; V.Value:=Ord(B); V.Text:='';
 End;
 ConstExpression:=V;
End;

Function ContainsFile(T: Word): Boolean;
Var F: Word;
Begin
 ContainsFile:=True;
 If Types[T].Typ In [ttFile,ttText] Then Exit;
 If Types[T].Typ=ttArray Then Begin ContainsFile:=ContainsFile(TypeExtras[T].ElementType); Exit End;
 If Types[T].Typ=ttRecord Then Begin
  F:=TypeExtras[T].FirstField;
  While F<>0 Do Begin If ContainsFile(Fields[F].TypeId) Then Exit; F:=Fields[F].Next End;
 End;
 ContainsFile:=False;
End;

Function ReadType: Word;
Var T,I,E,K,Element,Dimensions: Word; First,Last: TConstValue; Name: TShortString; W: Byte;
 IndexTypes: Array[1..16] Of Word;
 Size: Longint;
  SavedPos: Longint; SavedLine, SavedColumn, SavedTokenLine, SavedTokenColumn: Word;
Procedure RecordField(FieldName: TShortString; FieldType: Word; var Offset: Longint);
Var Field: Word;
Begin
 Field:=TypeExtras[T].FirstField;
 While Field<>0 Do Begin
  If Fields[Field].Name=FieldName Then Fail(4,'Champ duplique');
  Field:=Fields[Field].Next;
 End;
 If FieldCount=MaxFields Then Fail(123,'Table des champs pleine');
 If Offset+TypeExtras[FieldType].Size>MaxImage Then Fail(49,'Record trop grand');
 Inc(FieldCount); Field:=FieldCount; Fields[Field].Name:=FieldName;
 Fields[Field].TypeId:=FieldType; Fields[Field].Offset:=Offset;
 Fields[Field].Next:=TypeExtras[T].FirstField; TypeExtras[T].FirstField:=Field;
 Inc(TypeExtras[T].FieldCount); Inc(Offset,TypeExtras[FieldType].Size);
End;
Procedure RecordFields(var Offset: Longint; StopToken: Byte);
Var Names: Array[1..32] Of TShortString; Count,J,Component,Tag,I: Word;
 BaseOffset,ArmOffset,MaxOffset: Longint; TagName: TShortString;
 LabelValue: TConstValue; Labels: Array[1..256] Of Longint; LabelCount: Word;
Begin
 While Token<>StopToken Do Begin
  If Token=tkCase Then Begin
   NextToken; TagName:='';
   If Token<>tkIdent Then Fail(2,'Type ou champ discriminant attendu');
   TagName:=TokenText; NextToken;
   If Token=tkColon Then Begin
    NextToken; Tag:=ReadType; RecordField(TagName,Tag,Offset);
   End Else Begin
    I:=FindLexicalSymbol(TagName); Tag:=BuiltinType(TagName);
    If I<>0 Then Begin If Symbols[I].Kind<>skType Then Fail(27,'Type discriminant attendu'); Tag:=Symbols[I].TypeId End;
    If Tag=0 Then Fail(3,TagName);
   End;
   If Not (Types[Tag].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(27,'Discriminant non ordinal');
   Need(tkOf); BaseOffset:=Offset; MaxOffset:=Offset; LabelCount:=0; FillChar(Labels,SizeOf(Labels),0);
   While Token<>StopToken Do Begin
    Repeat
     LabelValue:=ConstExpression;
     If Not (Types[LabelValue.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(26,'Label variant non ordinal');
     If Not CompatibleTypes(Tag,LabelValue.TypeId) Then Fail(26,'Type de label variant');
     If (LabelValue.Value<Types[Tag].LowBound) Or (LabelValue.Value>Types[Tag].HighBound) Then Fail(76,'Label variant hors limites');
     For J:=1 To LabelCount Do If Labels[J]=LabelValue.Value Then Fail(4,'Label variant duplique');
     If LabelCount=256 Then Fail(123,'Trop de labels variants');
     Inc(LabelCount); Labels[LabelCount]:=LabelValue.Value;
     If Token<>tkComma Then Break; NextToken;
    Until False;
    Need(tkColon); Need(tkLP); ArmOffset:=BaseOffset; RecordFields(ArmOffset,tkRP); Need(tkRP);
    If ArmOffset>MaxOffset Then MaxOffset:=ArmOffset;
    If Token=tkSemi Then NextToken Else If Token<>StopToken Then Need(tkSemi);
   End;
   Offset:=MaxOffset; Exit;
  End;
  Count:=0;
  Repeat
   If Token<>tkIdent Then Fail(2,'Nom de champ attendu');
   If Count=32 Then Fail(123,'Trop de champs dans une declaration');
   Inc(Count); Names[Count]:=TokenText; NextToken;
   If Token<>tkComma Then Break; NextToken;
  Until False;
  Need(tkColon); Component:=ReadType;
  For J:=1 To Count Do RecordField(Names[J],Component,Offset);
  If Token=tkSemi Then NextToken Else If Token<>StopToken Then Need(tkSemi);
 End;
End;
Begin
 If Token=tkPacked Then NextToken;
 If Token In [tkObject,tkProcedure,tkFunction] Then
  Unsupported('objet ou type procedural');
 If (Token=tkIdent) And ((TokenText='SINGLE') Or (TokenText='DOUBLE') Or (TokenText='EXTENDED') Or (TokenText='COMP')) Then
  Unsupported('type: '+TokenText);
 If Token=tkFile Then Begin
  NextToken; Element:=0;
  If Token=tkOf Then Begin
   NextToken; Element:=ReadType;
   If ContainsFile(Element) Or (TypeExtras[Element].Size=0) Then Fail(26,'Type de composant file invalide');
  End;
  T:=NewType(ttFile,0,0,False,0,0,0); TypeExtras[T].Size:=128; TypeExtras[T].ElementType:=Element;
 End Else If Token=tkSet Then Begin
  NextToken; Need(tkOf); Element:=ReadType;
  If Not (Types[Element].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Or
     (Types[Element].LowBound<0) Or (Types[Element].HighBound>255) Then
   Fail(23,'Type de base set hors 0..255');
  T:=NewType(ttSet,0,0,False,Types[Element].LowBound,Types[Element].HighBound,0);
  TypeExtras[T].ElementType:=Element;
  TypeExtras[T].Size:=Types[Element].HighBound Div 8-Types[Element].LowBound Div 8+1;
 End Else If Token=tkCaret Then Begin
  NextToken;
  If Token=tkString Then Begin
   NextToken; T:=NewType(ttPointer,4,0,False,0,0,0); TypeExtras[T].ElementType:=7;
   ReadType:=T; Exit;
  End;
  If Token<>tkIdent Then Fail(12,'Type pointe attendu');
  Name:=TokenText; I:=FindSymbol(Name); T:=NewType(ttPointer,4,0,False,0,0,0);
  If (I<>0) And (Symbols[I].Kind=skType) And (Symbols[I].TypeId<>0) Then Begin
   NextToken; I:=ResolveSymbol(Name); TypeExtras[T].ElementType:=Symbols[I].TypeId;
  End Else Begin TypeExtras[T].ForwardName:=Name; NextToken End;
 End Else If Token=tkArray Then Begin
  NextToken;
  If Token=tkOf Then Begin
   { Parametre tableau ouvert (TP 7.0): pointeur far + High sur la pile. }
   NextToken; Element:=ReadType;
   T:=NewType(ttArray,0,0,False,0,0,0);
   TypeExtras[T].Size:=6; TypeExtras[T].IndexType:=3; TypeExtras[T].ElementType:=Element;
   TypeExtras[T].FieldCount:=$FFFF;
   ReadType:=T; Exit;
  End;
  Need(tkLB); Dimensions:=0;
  Repeat
   If Dimensions=16 Then Fail(123,'Trop de dimensions');
   Inc(Dimensions); IndexTypes[Dimensions]:=ReadType;
   I:=IndexTypes[Dimensions];
   If Not (Types[I].Typ In [ttInteger,ttBoolean,ttChar,ttEnum]) Then Fail(27,'Index non ordinal');
   If Token<>tkComma Then Break; NextToken;
  Until False;
  Need(tkRB); Need(tkOf); Element:=ReadType;
  For K:=Dimensions Downto 1 Do Begin
   I:=IndexTypes[K];
   Size:=(Types[I].HighBound-Types[I].LowBound+1)*Longint(TypeExtras[Element].Size);
   If (Size<=0) Or (Size>65535) Then Fail(22,'Tableau trop grand');
   T:=NewType(ttArray,0,0,False,0,0,0);
   TypeExtras[T].Size:=Size; TypeExtras[T].IndexType:=I; TypeExtras[T].ElementType:=Element;
   Element:=T;
  End;
 End Else If Token=tkRecord Then Begin
  NextToken; T:=NewType(ttRecord,0,0,False,0,0,0); Size:=0;
  RecordFields(Size,tkEnd);
  Need(tkEnd); TypeExtras[T].Size:=Size;
 End Else If Token=tkString Then Begin
  NextToken; T:=7;
  If Token=tkLB Then Begin
   NextToken; First:=ConstExpression; ConstInteger(First);
   If (First.Value<1) Or (First.Value>255) Then Fail(25,'Longueur string');
   Need(tkRB); T:=NewType(ttString,0,First.Value,False,0,First.Value,7);
  End;
 End Else If Token=tkLP Then Begin
  NextToken; T:=NewType(ttEnum,1,0,False,0,0,0); E:=0;
  Repeat
   If Token<>tkIdent Then Fail(2,'Identificateur enumere attendu');
   I:=NewSymbol(TokenText); Symbols[I].Kind:=skConst; ApplyType(I,T); Symbols[I].Value:=E;
   Inc(E); NextToken;
   If Token<>tkComma Then Break;
   NextToken;
  Until False;
  Need(tkRP);
  If E>256 Then Unsupported('enumeration >256 valeurs');
  Types[T].HighBound:=E-1;
 End Else Begin
  T:=0;
  If Token=tkIdent Then Begin
   SavedPos:=SourcePos; SavedLine:=Line; SavedColumn:=Column;
   SavedTokenLine:=TokenLine; SavedTokenColumn:=TokenColumn;
   I:=FindSymbol(TokenText);
   If (I<>0) And (Symbols[I].Kind=skType) Then Begin
    Name:=TokenText; NextToken; I:=ResolveSymbol(Name); T:=Symbols[I].TypeId;
    If T=0 Then Fail(12,'Type en cours de definition');
   End Else If I=0 Then Begin
    T:=BuiltinType(TokenText); If T<>0 Then NextToken;
    If (T=0) And (FindBuildUnit(TokenText)=0) And
      (TokenText<>'TRUE') And (TokenText<>'FALSE') Then Fail(12,'Type inconnu: '+TokenText);
   End;
   If (T=0) And (Token=tkIdent) And (Peek<>#0) Then Begin
    { Une reference qualifiee peut designer un type ou une constante borne. }
    Name:=TokenText;
    If FindBuildUnit(Name)<>0 Then Begin
     NextToken; I:=ResolveSymbol(Name);
     If Symbols[I].Kind=skType Then T:=Symbols[I].TypeId
     Else If Symbols[I].Kind=skConst Then Begin
      SourcePos:=SavedPos; Line:=SavedLine; Column:=SavedColumn;
      TokenLine:=SavedTokenLine; TokenColumn:=SavedTokenColumn;
      Token:=tkIdent; TokenText:=Name; TokenIsString:=False; TokenValue:=0;
      T:=0;
     End Else Fail(12,'Type attendu');
    End;
   End;
  End;
  If T=0 Then First:=ConstExpression;
  If (T=0) Or (T=$FFFF) Then Begin
   If Not (Types[First.TypeId].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(27,'Borne non ordinale');
   Need(tkRange); Last:=ConstExpression;
   If Not CompatibleTypes(First.TypeId,Last.TypeId) Then Fail(26,'Types des bornes');
   If First.Value>Last.Value Then Fail(28,'Bornes inversees');
   If (First.Value<-32768) Or (Last.Value>65535) Then Unsupported('sous-intervalle >16 bits');
   W:=2;
   If (First.Value>=0) And (Last.Value<=255) Then W:=1;
   If (First.Value>=-128) And (Last.Value<=127) Then W:=1;
   T:=NewType(Types[First.TypeId].Typ,W,0,First.Value<0,First.Value,Last.Value,Types[First.TypeId].Base);
  End;
 End;
 ReadType:=T;
End;

Procedure TypeDeclarations;
Var I,T: Word;
Begin
 NextToken;
 While Token=tkIdent Do Begin
  I:=NewSymbol(TokenText); Symbols[I].Kind:=skType; NextToken; Need(tkEqual);
  T:=ReadType;
  If (Types[T].Typ In [ttEnum,ttArray,ttRecord,ttPointer]) And (Types[T].IdentityName='') Then Begin
   If CurrentUnit=0 Then Types[T].IdentityUnit:='$PROGRAM'
   Else If CurrentUnit=254 Then Types[T].IdentityUnit:='$REAL'
   Else If CurrentUnit=253 Then Types[T].IdentityUnit:='$8087'
   Else Types[T].IdentityUnit:=Units[CurrentUnit].Name;
   Types[T].IdentityName:=Symbols[I].Name;
   If CurrentScope<>0 Then Types[T].IdentityName:=Symbols[I].Name+'$LOCAL';
  End;
  ApplyType(I,T); Need(tkSemi);
 End;
 For T:=1 To TypeCount Do If TypeExtras[T].ForwardName<>'' Then Begin
  I:=FindSymbol(TypeExtras[T].ForwardName);
  If (I=0) Or (Symbols[I].Kind<>skType) Or (Symbols[I].TypeId=0) Then
   Fail(12,'Type pointe inconnu: '+TypeExtras[T].ForwardName);
  TypeExtras[T].ElementType:=Symbols[I].TypeId; TypeExtras[T].ForwardName:='';
 End;
End;

Procedure CheckConstType(T: Word; V: TConstValue);
Begin
 If Types[T].Typ=ttReal Then Begin
  If Not (Types[V.TypeId].Typ In [ttReal,ttInteger]) Then Fail(26,'Constante numerique attendue');
 End Else If Types[T].Typ=ttString Then Begin
  If Not (Types[V.TypeId].Typ In [ttChar,ttString]) Then Fail(26,'Chaine constante attendue');
  { TP 7.0 tronque silencieusement une constante plus longue que String[n]. }
 End Else Begin
  If Not CompatibleTypes(T,V.TypeId) Then Fail(26,'Type constant incompatible');
  If (V.Value<Types[T].LowBound) Or (V.Value>Types[T].HighBound) Then Fail(76,'Constante hors limites du type');
 End;
End;

Procedure AllocateVariable(I: Word);
Var N,R: Word;
Begin
 N:=TypeExtras[SymbolType(I)].Size; R:=RealScope(CurrentScope);
 If R<>0 Then Begin
  N:=(N+1) And $FFFE;
  If Longint(Scopes[R].LocalSize)+N>65520 Then Fail(49,'Variables locales trop grandes');
  Inc(Scopes[R].LocalSize,N); Symbols[I].Local:=True;
  Symbols[I].Addr:=Word(-Longint(Scopes[R].LocalSize));
 End Else If (CurrentUnit=0) And (N<>0) Then Symbols[I].Addr:=AllocBss(N)
 Else Symbols[I].Addr:=AllocData(N);
End;

Procedure StorePCharConst(A: Word; S: TShortString);
{ Pointeur statique vers une copie a zero terminal de S (programme seul). }
Var Z: Word; K: Integer;
Begin
 If CurrentUnit<>0 Then Unsupported('constante typee PChar dans une unite');
 If DataFixupCount=4096 Then Fail(107,'Trop de constantes PChar');
 Z:=AllocData(Length(S)+1);
 For K:=1 To Length(S) Do Data[Z+K-1]:=Ord(S[K]);
 Data[Z+Length(S)]:=0;
 Data[A]:=Z And 255; Data[A+1]:=Z Shr 8; Data[A+2]:=0; Data[A+3]:=0;
 Inc(DataFixupCount); DataFixups[DataFixupCount]:=A;
End;

Procedure ConstSetElements(T, A: Word; V: TConstValue);
{ Elements d'une constante ensemble, V = premier element deja lu;
  s'arrete sur "]" (non consomme). }
Var V2: TConstValue; X,Lo: Longint;
Begin
 Lo:=Types[T].LowBound Div 8*8;
 Repeat
  V2:=V;
  If Token=tkRange Then Begin NextToken; V2:=ConstExpression End;
  If (TypeExtras[T].ElementType<>0) And Not CompatibleTypes(TypeExtras[T].ElementType,V.TypeId) Then Fail(26,'');
  For X:=V.Value To V2.Value Do Begin
   If (X<Types[T].LowBound) Or (X>Types[T].HighBound) Then Fail(76,'Element hors de l''ensemble');
   Data[A+(X-Lo) Div 8]:=Data[A+(X-Lo) Div 8] Or (1 Shl ((X-Lo) Mod 8));
  End;
  If Token<>tkComma Then Break; NextToken; V:=ConstExpression;
 Until False;
End;

Procedure ConstInit(T, A: Word);
{ Initialisation d'une constante typee a l'adresse A de Data, selon T:
  (v1,v2,...) pour un tableau, (champ:v;...) pour un record, [..] pour un
  ensemble, et une valeur scalaire sinon. }
Var V,V2: TConstValue; S: TShortString; K: Integer; F,Element,Count,N: Word; Lo,Hi,X: Longint;
Begin
 Case Types[T].Typ Of
  ttArray:Begin
   Element:=TypeExtras[T].ElementType;
   Lo:=Types[TypeExtras[T].IndexType].LowBound; Hi:=Types[TypeExtras[T].IndexType].HighBound;
   If (Token=tkConstant) And TokenIsString And (Element=6) Then Begin
    { tableau de Char initialise par une chaine }
    V:=ConstExpression; S:=ConstText(V);
    If Length(S)>Hi-Lo+1 Then Fail(76,'Chaine trop longue pour le tableau');
    For K:=1 To Length(S) Do Data[A+K-1]:=Ord(S[K]);
    Exit;
   End;
   Need(tkLP);
   For X:=Lo To Hi Do Begin
    If X<>Lo Then Need(tkComma);
    ConstInit(Element,A+(X-Lo)*TypeExtras[Element].Size);
   End;
   Need(tkRP);
  End;
  ttRecord:Begin
   Need(tkLP);
   While Token<>tkRP Do Begin
    If Token<>tkIdent Then Fail(44,'');
    F:=TypeExtras[T].FirstField;
    While (F<>0) And (Fields[F].Name<>TokenText) Do F:=Fields[F].Next;
    If F=0 Then Fail(3,'Champ inconnu: '+TokenText);
    NextToken; Need(tkColon); ConstInit(Fields[F].TypeId,A+Fields[F].Offset);
    If Token=tkSemi Then NextToken Else If Token<>tkRP Then Need(tkSemi);
   End;
   Need(tkRP);
  End;
  ttSet:Begin
   Need(tkLB);
   If Token<>tkRB Then Begin V:=ConstExpression; ConstSetElements(T,A,V) End;
   Need(tkRB);
  End;
  ttString:Begin
   V:=ConstExpression; CheckConstType(T,V); S:=ConstText(V);
   If Length(S)>Types[T].Capacity Then S[0]:=Chr(Types[T].Capacity);
   Data[A]:=Length(S);
   For K:=1 To Length(S) Do Data[A+K]:=Ord(S[K]);
  End;
  ttReal:Begin
   V:=ConstExpression; CheckConstType(T,V); F:=StoreReal(ConstReal(V)); Move(Data[F],Data[A],6);
  End;
  ttPointer:Begin
   If Token=tkNil Then Begin NextToken; FillChar(Data[A],4,0) End
   Else If Token=tkAt Then Begin
    { @Variable globale: offset + segment de donnees (relocalise par la table MZ) }
    NextToken; If Token<>tkIdent Then Fail(2,'');
    Element:=ResolveSymbol(TokenText); NextToken;
    If (Symbols[Element].Kind<>skVar) Or Symbols[Element].Local Then Fail(20,'Variable globale attendue');
    N:=Symbols[Element].Addr;
    While Token In [tkDot,tkLB] Do Begin
     If Token=tkDot Then Begin
      NextToken; If Token<>tkIdent Then Fail(2,'');
      F:=TypeExtras[SymbolType(Element)].FirstField; While (F<>0) And (Fields[F].Name<>TokenText) Do F:=Fields[F].Next;
      If F=0 Then Fail(3,''); Inc(N,Fields[F].Offset); NextToken;
     End Else Fail(31,'Indice non constant dans une adresse');
    End;
    Data[A]:=N And 255; Data[A+1]:=N Shr 8; Data[A+2]:=0; Data[A+3]:=0;
    If DataFixupCount=4096 Then Unsupported('trop de constantes pointeur'); Inc(DataFixupCount); DataFixups[DataFixupCount]:=A;
   End Else Begin
    V:=ConstExpression;
    If IsCharPointer(T) And (Types[V.TypeId].Typ In [ttChar,ttString]) And ExtendedSyntax Then
     StorePCharConst(A,ConstText(V))
    Else Fail(26,'');
   End;
  End;
  ttInteger,ttChar,ttBoolean,ttEnum:Begin
   V:=ConstExpression; CheckConstType(T,V);
   Data[A]:=Word(V.Value) And 255;
   If Types[T].Width>=2 Then Data[A+1]:=Word(V.Value) Shr 8;
   If Types[T].Width=4 Then For K:=1 To 3 Do Data[A+K]:=(V.Value Shr (K*8)) And 255;
  End;
 Else Fail(26,'Type de constante typee non pris en charge');
 End;
End;

Procedure ConstDeclarations;
Var
 I,T,A: Word; V: TConstValue; S: TShortString; K: Integer; Typed: Boolean;
Begin
 NextToken;
 While Token=tkIdent Do Begin
  I:=NewSymbol(TokenText); NextToken;
  Typed:=Token=tkColon; T:=0;
  If Typed Then Begin NextToken; T:=ReadType End;
  If Typed Then Begin
   { Constante typee: variable statique initialisee (TP 6/7). }
   Need(tkEqual); ApplyType(I,T); Symbols[I].Kind:=skVar;
   A:=AllocData(TypeExtras[T].Size); Symbols[I].Addr:=A; ConstInit(T,A);
  End Else If (Token=tkEqual) And (NextNonBlank='[') Then Begin
   { Constante ensemble: variable statique d'un type set anonyme. }
   NextToken; NextToken; T:=0;
   If Token<>tkRB Then Begin
    V:=ConstExpression;
    A:=V.TypeId; If Types[A].Typ=ttInteger Then A:=2;
    If Not (Types[A].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Then Fail(26,'');
    T:=NewType(ttSet,0,0,False,Types[A].LowBound,Types[A].HighBound,0);
    TypeExtras[T].ElementType:=A;
    TypeExtras[T].Size:=Types[A].HighBound Div 8-Types[A].LowBound Div 8+1;
    ApplyType(I,T); Symbols[I].Kind:=skVar; A:=AllocData(TypeExtras[T].Size); Symbols[I].Addr:=A;
    ConstSetElements(T,A,V);
   End Else Begin
    T:=NewType(ttSet,0,0,False,0,255,0); TypeExtras[T].ElementType:=2; TypeExtras[T].Size:=32;
    ApplyType(I,T); Symbols[I].Kind:=skVar; Symbols[I].Addr:=AllocData(32);
   End;
   Need(tkRB);
  End Else Begin
   Need(tkEqual); V:=ConstExpression;
   Symbols[I].Kind:=skConst;
   T:=V.TypeId;
   If Types[T].Typ=ttInteger Then Begin
    If (V.Value<-32768) Or (V.Value>65535) Then T:=9
    Else If (V.Value>=0) And (V.Value>32767) And (V.Value<=65535) Then T:=3 Else T:=1;
   End;
   ApplyType(I,T); Symbols[I].Value:=V.Value; Symbols[I].StrValue:=V.Text;
   If Symbols[I].Typ=ttString Then Symbols[I].Addr:=StoreString(V.Text);
   If Symbols[I].Typ=ttReal Then Begin
    Symbols[I].Addr:=StoreReal(V.RealValue); Symbols[I].StrValue[0]:=#6; Move(Data[Symbols[I].Addr],Symbols[I].StrValue[1],6);
   End;
  End;
  Need(tkSemi);
 End;
End;

Procedure VarDeclarations;
Var
 First, Last, I,T,J: Word; Name: TShortString; V1,V2: TConstValue;
Begin
 NextToken;
 While Token=tkIdent Do Begin
  First:=SymbolCount+1;
  Repeat
  If Token<>tkIdent Then Fail(2,'Identificateur attendu');
  I:=NewSymbol(TokenText); Symbols[I].Kind:=skVar; NextToken;
  If Token<>tkComma Then Break;
  NextToken;
  Until False;
  Last:=SymbolCount; Need(tkColon); T:=ReadType;
  If (Token=tkIdent) And (TokenText='ABSOLUTE') Then Begin
   { ABSOLUTE variable: meme emplacement; ABSOLUTE seg:ofs: adresse fixe. }
   NextToken;
   If Token=tkIdent Then Begin
    Name:=TokenText; NextToken; J:=ResolveSymbol(Name);
    If Symbols[J].Kind<>skVar Then Fail(20,'');
    For I:=First To Last Do Begin
     ApplyType(I,T); Symbols[I].Addr:=Symbols[J].Addr; Symbols[I].Local:=Symbols[J].Local;
     Symbols[I].ByReference:=Symbols[J].ByReference; Symbols[I].Native:=Symbols[J].Native;
     Symbols[I].WithOffset:=Symbols[J].WithOffset; Symbols[I].IsAbsolute:=Symbols[J].IsAbsolute;
     Symbols[I].AbsoluteSeg:=Symbols[J].AbsoluteSeg; Symbols[I].Scope:=Symbols[J].Scope;
     Symbols[I].DebugVisible:=False;
    End;
   End Else Begin
    V1:=ConstExpression; ConstInteger(V1); Need(tkColon); V2:=ConstExpression; ConstInteger(V2);
    If (V1.Value<0) Or (V1.Value>65535) Or (V2.Value<0) Or (V2.Value>65535) Then Fail(76,'');
    For I:=First To Last Do Begin
     ApplyType(I,T); Symbols[I].IsAbsolute:=True; Symbols[I].AbsoluteSeg:=V1.Value;
     Symbols[I].Addr:=V2.Value; Symbols[I].DebugVisible:=False;
    End;
   End;
  End Else
  For I:=First To Last Do Begin
   ApplyType(I,T); AllocateVariable(I);
  End;
  Need(tkSemi);
 End;
End;

Procedure DeclarationPart; Forward;

Procedure ProcedureDeclaration;
Var
 I,Parent,FramePatch,StackCheckPatch,Skip,J,K,T,V,ParamOffset,Size,Link: Word;
 SavedProcedure,IsFunction,Existing,FullHeading,ByVar,IsForward,HasDistance,IsExternal,IsConst: Boolean;
 Sig: TSymbol; Name: TShortString;
 Names: Array[1..MaxNativeParams] Of String[63]; N: Byte;
Begin
 IsFunction:=Token=tkFunction; FillChar(Sig,SizeOf(Sig),0);
 Sig.Kind:=skProc; Sig.Typ:=ttVoid;
 NextToken;
 If Token<>tkIdent Then Fail(2,'Nom de procedure attendu');
 Name:=TokenText;
 I:=FindOwnSymbol(TokenText);
 Existing:=I<>0;
 If Existing Then Begin
  If (Symbols[I].Kind<>skProc) Or Symbols[I].HasBody Then      Fail(4,
  'Identificateur duplique: '+TokenText);
 End;
 NextToken;
 FullHeading:=Token=tkLP;
 If Token=tkLP Then Begin
  NextToken;
  While Token<>tkRP Do Begin
   ByVar:=Token=tkVar; If ByVar Then NextToken;
   { CONST: transmis comme un parametre valeur (copie non modifiee);
     CONST sans type est une reference comme VAR sans type. }
   IsConst:=Token=tkConst; If IsConst Then NextToken;
   N:=0;
   Repeat
    If Token<>tkIdent Then Fail(2,'Nom de parametre attendu');
    If N=MaxNativeParams Then Unsupported('plus de 16 parametres');
    Inc(N); Names[N]:=TokenText; NextToken;
    If Token<>tkComma Then Break;
    NextToken;
   Until False;
   If (ByVar Or IsConst) And (Token In [tkSemi,tkRP]) Then Begin T:=0; ByVar:=True End
   Else Begin Need(tkColon); T:=ReadType End;
   If Not (Types[T].Typ In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer,ttArray,ttRecord,ttString,ttSet,ttReal]) And
      Not (ByVar And ((T=0) Or (Types[T].Typ In [ttFile,ttText]))) Then
    Unsupported('type de parametre utilisateur');
   For J:=1 To N Do Begin
    If Sig.ParamCount=MaxNativeParams Then Unsupported('plus de 16 parametres');
    Inc(Sig.ParamCount); K:=Sig.ParamCount;
    For V:=1 To K-1 Do If Sig.ParamNames[V]=Names[J] Then Fail(4,'Parametre duplique');
    Sig.ParamNames[K]:=Names[J]; Sig.ParamTypeIds[K]:=T;
    Sig.ParamTypes[K]:=Types[T].Typ; Sig.ParamWidths[K]:=Types[T].Width;
    Sig.ParamSigned[K]:=Types[T].Signed And (Types[T].Width=1);
    If (Types[T].Typ=ttArray) And (TypeExtras[T].FieldCount=$FFFF) Then Begin Sig.ParamFlags[K]:=7; Inc(Sig.ParamBytes,6) End
    Else If ByVar Then Begin Sig.ParamFlags[K]:=6; Inc(Sig.ParamBytes,4) End
    Else Begin
     Sig.ParamFlags[K]:=2; Size:=(TypeExtras[T].Size+1) And $FFFE;
     If Size<2 Then Size:=2;
     If Longint(Sig.ParamBytes)+Size>32766 Then Fail(49,'Parametres trop grands');
     Inc(Sig.ParamBytes,Size);
    End;
   End;
   If Token<>tkSemi Then Break;
   NextToken;
  End;
  Need(tkRP);
 End;
 If IsFunction Then Begin
  If Token=tkColon Then Begin
   FullHeading:=True; NextToken; T:=ReadType;
   If Not (Types[T].Typ In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer,ttReal,ttString]) Then
    Fail(34,'Resultat de fonction non ordinal');
   Sig.TypeId:=T; Sig.Typ:=Types[T].Typ; Sig.Width:=Types[T].Width;
   Sig.SignedByte:=Types[T].Signed And (Types[T].Width=1);
  End Else If Not Existing Then Need(tkColon);
 End;
 Need(tkSemi);
 IsForward:=False; HasDistance:=False; IsExternal:=False;
 Sig.FarRoutine:=InInterface Or (OptionBits And $20<>0);
 If Token=tkInline Then Begin
  { Procedure X; Inline(...): les octets sont inseres a chaque appel. }
  NextToken; Sig.StrValue:=InlineBytes(False); Need(tkSemi); Sig.InlineBody:=True;
 End;
 While (Token=tkIdent) And ((TokenText='FORWARD') Or (TokenText='NEAR') Or (TokenText='FAR') Or (TokenText='EXTERNAL') Or (TokenText='ASSEMBLER')) Do Begin
  If TokenText='FORWARD' Then IsForward:=True
  Else If TokenText='EXTERNAL' Then IsExternal:=True
  Else If TokenText='ASSEMBLER' Then Sig.AssemblerBody:=True
  Else Begin
   If HasDistance Then Fail(5,'Directive de distance dupliquee');
   HasDistance:=True; Sig.FarRoutine:=TokenText='FAR';
  End;
  NextToken; Need(tkSemi);
 End;
 If IsExternal And IsForward Then Fail(5,'EXTERNAL et FORWARD incompatibles');
 If Existing Then Begin
  If IsFunction<>(Symbols[I].Typ<>ttVoid) Then Fail(131,'Procedure/fonction differente');
  If FullHeading Then Begin
   If (Sig.ParamCount<>Symbols[I].ParamCount) Or (Sig.TypeId<>Symbols[I].TypeId) Then
    Fail(131,'Signature de routine differente');
   For J:=1 To Sig.ParamCount Do
    If (Sig.ParamNames[J]<>Symbols[I].ParamNames[J]) Or
      (Sig.ParamTypeIds[J]<>Symbols[I].ParamTypeIds[J]) Or
      (Sig.ParamFlags[J]<>Symbols[I].ParamFlags[J]) Then Fail(131,'Signature de parametre differente');
  End;
  If HasDistance And (Sig.FarRoutine<>Symbols[I].FarRoutine) Then Fail(131,'Distance near/far differente');
  If InInterface Or IsForward Then Fail(4,'Declaration de routine dupliquee');
 End Else Begin
  I:=NewSymbol(Name);
  { Conserver l'entree du dictionnaire, remplir uniquement la signature. }
  Symbols[I].Kind:=skProc; Symbols[I].Typ:=Sig.Typ; Symbols[I].Width:=Sig.Width;
  Symbols[I].TypeId:=Sig.TypeId; Symbols[I].SignedByte:=Sig.SignedByte;
  Symbols[I].ParamCount:=Sig.ParamCount; Symbols[I].ParamBytes:=Sig.ParamBytes;
  Symbols[I].FarRoutine:=Sig.FarRoutine;
  Symbols[I].AssemblerBody:=Sig.AssemblerBody;
  Symbols[I].InlineBody:=Sig.InlineBody; Symbols[I].StrValue:=Sig.StrValue;
  For J:=1 To Sig.ParamCount Do Begin
   Symbols[I].ParamTypeIds[J]:=Sig.ParamTypeIds[J]; Symbols[I].ParamNames[J]:=Sig.ParamNames[J];
   Symbols[I].ParamTypes[J]:=Sig.ParamTypes[J]; Symbols[I].ParamWidths[J]:=Sig.ParamWidths[J];
   Symbols[I].ParamSigned[J]:=Sig.ParamSigned[J]; Symbols[I].ParamFlags[J]:=Sig.ParamFlags[J];
  End;
  Symbols[I].Addr:=CodeSize; Symbols[I].ForwardJump:=Jump;
 End;
 If Sig.AssemblerBody Then Symbols[I].AssemblerBody:=True;
 If Sig.InlineBody Then Begin Symbols[I].HasBody:=True; Symbols[I].InlineBody:=True; Symbols[I].StrValue:=Sig.StrValue; Exit End;
 If InInterface Or IsForward Then Begin Symbols[I].ForwardDeclared:=True; Exit End;
 PatchJump(Symbols[I].ForwardJump,CodeSize);
 Symbols[I].HasBody:=True;
 If IsExternal Then Begin
  If Symbols[I].Typ=ttReal Then Unsupported('resultat Real externe: ABI Borland non portee');
  If CurrentScope<>0 Then Unsupported('EXTERNAL imbrique');
  If ObjectCallCount=MaxSymbols Then Unsupported('trop de routines EXTERNAL');
  { Pont ABI locale (lien statique) vers ABI Pascal OBJ far sans lien.
    Copier les arguments afin que RETF n'enleve pas la frame du pont. }
  Emit($55); Emit2($89,$E5); Emit($1E); Emit($06);
  Emit($53); Emit($56); Emit($57);
  Link:=4; If Symbols[I].FarRoutine Then Link:=6;
  J:=Symbols[I].ParamBytes;
  While J<>0 Do Begin
   Emit2($FF,$B6); EmitWord(Link+J); Dec(J,2);
  End;
  Emit($9A); Inc(ObjectCallCount);
  ObjectCalls[ObjectCallCount].Name:=Name;
  ObjectCalls[ObjectCallCount].Position:=CodeSize;
  EmitWord(0); EmitWord(0);
  Emit($5F); Emit($5E); Emit($5B); Emit($07); Emit($1F); Emit($5D);
  If Symbols[I].FarRoutine Then Emit($CA) Else Emit($C2);
  EmitWord(Symbols[I].ParamBytes+2);
  Exit;
 End;
 Parent:=CurrentScope; SavedProcedure:=InProcedure;
 If ScopeCount=MaxScopes Then Unsupported('plus de 128 portees');
 Inc(ScopeCount); CurrentScope:=ScopeCount;
 Scopes[CurrentScope].Parent:=Parent; Scopes[CurrentScope].Owner:=CurrentUnit;
 Scopes[CurrentScope].ProcSymbol:=I; Scopes[CurrentScope].LocalSize:=0;
 FillChar(Scopes[CurrentScope].Temps,SizeOf(TTempPool),0);
 If Symbols[I].FarRoutine Then Link:=6 Else Link:=4;
 Scopes[CurrentScope].LinkOffset:=Link;
 ParamOffset:=Link+2+Symbols[I].ParamBytes;
 For J:=1 To Symbols[I].ParamCount Do Begin
  Size:=(TypeExtras[Symbols[I].ParamTypeIds[J]].Size+1) And $FFFE;
  If Size<2 Then Size:=2; If Symbols[I].ParamFlags[J]=6 Then Size:=4;
  If Symbols[I].ParamFlags[J]=7 Then Size:=6;
  Dec(ParamOffset,Size); V:=NewSymbol(Symbols[I].ParamNames[J]);
  Symbols[V].Kind:=skVar; ApplyType(V,Symbols[I].ParamTypeIds[J]);
  Symbols[V].Local:=True; Symbols[V].Addr:=ParamOffset;
  Symbols[V].ByReference:=Symbols[I].ParamFlags[J] In [6,7];
 End;
 If IsFunction Then Begin
  V:=NewSymbol(Name); Symbols[V].Kind:=skVar; ApplyType(V,Symbols[I].TypeId);
  AllocateVariable(V); Symbols[V].ResultVariable:=True; Symbols[V].RoutineSymbol:=I;
  Symbols[I].ResultSymbol:=V;
 End;
 InProcedure:=True;
 If Token=tkAsm Then Symbols[I].AssemblerBody:=True;
 Emit($55); Emit2($89,$E5); StackCheckPatch:=0;
 If OptionBits And 4<>0 Then Begin
  CallTo(RuntimeStandard[72]); StackCheckPatch:=CodeSize; EmitWord(0);
 End;
 Emit2($81,$EC); FramePatch:=CodeSize; EmitWord(0);
 Skip:=Jump; DeclarationPart; PatchJump(Skip,CodeSize);
 For J:=1 To SymbolCount Do If (Symbols[J].Owner=CurrentUnit) And
   (Symbols[J].Scope=CurrentScope) And (Symbols[J].Kind=skProc) And
   Not Symbols[J].HasBody Then Fail(59,Symbols[J].Name);
 If Token=tkAsm Then Symbols[I].AssemblerBody:=True;
 Statement; ProcedureExit; CheckLabels(CurrentScope);
 { La taille de la frame inclut les temporaires alloues par les WITH. }
 PatchWord(FramePatch,Scopes[CurrentScope].LocalSize);
 If StackCheckPatch<>0 Then PatchWord(StackCheckPatch,Scopes[CurrentScope].LocalSize+256);
 CurrentScope:=Parent; InProcedure:=SavedProcedure; Need(tkSemi);
End;

Procedure LabelDeclarations;
Var I: Word;
Begin
 NextToken;
 Repeat
  If Not ((Token=tkIdent) Or ((Token=tkConstant) And Not TokenIsString And Not TokenIsReal)) Then Fail(35,'');
  I:=NewSymbol(TokenText); Symbols[I].Kind:=skLabel; Symbols[I].DebugVisible:=False; NextToken;
  If Token<>tkComma Then Break; NextToken;
 Until False;
 Need(tkSemi);
End;

Procedure CheckLabels(Scope: Word);
{ Erreur 82 si un GOTO vise une etiquette jamais definie dans ce bloc. }
Var K: Word;
Begin
 For K:=1 To LabelJumpCount Do
  If (LabelJumps[K].Sym<>0) And (Symbols[LabelJumps[K].Sym].Scope=Scope) And
     (Symbols[LabelJumps[K].Sym].Owner=CurrentUnit) Then Fail(82,Symbols[LabelJumps[K].Sym].Name);
End;

Procedure DeclarationPart;Begin
 While Token In [tkConst,tkType,tkVar,tkProcedure,tkFunction,tkLabel] Do Case Token Of
 tkConst:ConstDeclarations; tkVar:VarDeclarations;
 tkType:TypeDeclarations; tkLabel:LabelDeclarations;
 tkProcedure,tkFunction:ProcedureDeclaration;
End;
If Token In [tkConstructor,tkDestructor,tkExports] Then    Unsupported(
'declaration: '+TokenText);
End;
Procedure LoadSource;Forward;
Procedure UsesClause;Forward;
Procedure ImportLibrarySystem;Forward;

Procedure SaveParser(Var P: PParserState);Begin
 New(P); New(P^.Buffer);
 Move(Source,P^.Buffer^,SourceSize);
 P^.SourceName:=SourceName; P^.SourceSize:=SourceSize; P^.SourcePos:=SourcePos;
 P^.Line:=Line; P^.Column:=Column;
 P^.TokenLine:=TokenLine; P^.TokenColumn:=TokenColumn;
 P^.Token:=Token; P^.TokenText:=TokenText; P^.TokenValue:=TokenValue;
 P^.TokenIsString:=TokenIsString; P^.TokenIsReal:=TokenIsReal; P^.TokenReal:=TokenReal; P^.Active:=Active;
 P^.InProcedure:=InProcedure; P^.InInterface:=InInterface;
 P^.CondDepth:=CondDepth; P^.CurrentUnit:=CurrentUnit; P^.Imports:=Imports;
 Move(ImportOrder,P^.ImportOrder,SizeOf(ImportOrder)); P^.ImportCount:=ImportCount;
 Move(Conditions,P^.Conditions,SizeOf(Conditions));
 Move(Defines,P^.Defines,SizeOf(Defines)); P^.DefineCount:=DefineCount;
 P^.OptionBits:=OptionBits; P^.StackSize:=StackSize;
 P^.CurrentScope:=CurrentScope;
 P^.MinHeap:=MinHeap; P^.MaxHeap:=MaxHeap;
End;

Procedure RestoreParser(P: PParserState);Begin
 Move(P^.Buffer^,Source,P^.SourceSize);
 SourceName:=P^.SourceName; SourceSize:=P^.SourceSize; SourcePos:=P^.SourcePos;
 Line:=P^.Line; Column:=P^.Column;
 TokenLine:=P^.TokenLine; TokenColumn:=P^.TokenColumn;
 Token:=P^.Token; TokenText:=P^.TokenText; TokenValue:=P^.TokenValue;
 TokenIsString:=P^.TokenIsString; TokenIsReal:=P^.TokenIsReal; TokenReal:=P^.TokenReal; Active:=P^.Active;
 InProcedure:=P^.InProcedure; InInterface:=P^.InInterface;
 CondDepth:=P^.CondDepth; CurrentUnit:=P^.CurrentUnit; Imports:=P^.Imports;
 Move(P^.ImportOrder,ImportOrder,SizeOf(ImportOrder)); ImportCount:=P^.ImportCount;
 Move(P^.Conditions,Conditions,SizeOf(Conditions));
 Move(P^.Defines,Defines,SizeOf(Defines)); DefineCount:=P^.DefineCount;
 OptionBits:=P^.OptionBits; StackSize:=P^.StackSize;
 CurrentScope:=P^.CurrentScope;
 MinHeap:=P^.MinHeap; MaxHeap:=P^.MaxHeap;
 Dispose(P^.Buffer); Dispose(P);
End;

Procedure CompileSourceUnit(U: Byte; Path: TShortString);
Var
 P: PParserState;
 I: Word;
Begin
 SaveParser(P);
 SourceName:=Path; CurrentUnit:=U; Imports:=[]; ImportCount:=0;
 CurrentScope:=0;
 Units[U].FromSource:=True; Units[U].Path:=Path;
 InInterface:=True; InProcedure:=False;
  { Les directives locales d'une unite ne fuient ni dans ses dependances
    ni dans le programme appelant. Les /D de la CLI restent disponibles. }
 Move(InitialDefines,Defines,SizeOf(Defines)); DefineCount:=InitialDefineCount;
 OptionBits:=InitialOptions;
 If OptionBits And $800<>0 Then UnitFeatures[U]:=UnitFeatures[U] Or 4;
 LoadSource;
 ImportLibrarySystem;
 NextToken; Need(tkUnit);
 If Token<>tkIdent Then Fail(2,'Nom d''unite attendu');
 If TokenText<>Units[U].Name Then Fail(69,Units[U].Name+' <> '+TokenText);
 NextToken; Need(tkSemi); Need(tkInterface);
 UsesClause; DeclarationPart;
 Units[U].InterfaceReady:=True;
 Units[U].Checksum:=0; { calcule apres compilation; sources /B prioritaires }
 Need(tkImplementation); InInterface:=False;
 UsesClause; DeclarationPart;
 For I:=1 To SymbolCount Do    If (Symbols[I].Owner=U) And (Symbols[I].Kind=skProc) And
 Not Symbols[I].HasBody Then Fail(59,Symbols[I].Name);
 If Token=tkBegin Then Begin
  Units[U].HasInit:=True; Units[U].InitAddress:=CodeSize;
    { EXIT dans le bloc d'initialisation revient a l'appelant. }
  InProcedure:=True; Statement; InProcedure:=False; Emit($C3);
 End Else Need(tkEnd);
 Need(tkDot);
 Units[U].State:=2;
 If Units[U].HasInit Then Begin
  Inc(InitCount); InitOrder[InitCount]:=U
 End;
 If Units[U].Name='CRT' Then
  For I:=1 To SymbolCount Do If (Symbols[I].Owner=U) And (Symbols[I].Scope=0) And
   (Symbols[I].Kind=skProc) And (Symbols[I].Name='CRTWRITE') Then Begin
   Data[CrtHook]:=Symbols[I].Addr And 255; Data[CrtHook+1]:=Symbols[I].Addr Shr 8;
  End;
 If Not Units[U].Embedded Then ReportSource;
 RestoreParser(P);
End;

Procedure OpenBinaryRead(Var F: File; Var E: Integer);
Var
 SavedMode: Byte;
Begin
 SavedMode:=FileMode; FileMode:=0;
  {$I-} Reset(F,1); E:=IOResult; {$I+}
 FileMode:=SavedMode;
End;

Function FileExists(S: TShortString): Boolean;
Var
 F: File;
 E: Integer;
Begin
 Assign(F,S); OpenBinaryRead(F,E);
 FileExists:=E=0;
 If E=0 Then Begin
 {$I-} Close(F); E:=IOResult; {$I+} 
 End;
End;

Function JoinPath(Dir, Name: TShortString): TShortString;Begin
 If (Dir<>'') And Not (Dir[Length(Dir)] In ['\','/']) Then Dir:=Dir+'\';
 If Length(Dir)+Length(Name)>255 Then CLIError('Chemin trop long');
 JoinPath:=Dir+Name;
End;

Function FileStamp(Path: TShortString): Longint;
{ Date/heure DOS compactee d'un fichier, -1 si inaccessible. }
Var F: File; E: Integer; T: Longint;
Begin
 FileStamp:=-1;
 Assign(F,Path); OpenBinaryRead(F,E);
 If E<>0 Then Exit;
 {$I-} GetFTime(F,T); E:=IOResult; Close(F); If IOResult<>0 Then E:=1; {$I+}
 If E=0 Then FileStamp:=T;
End;

Function FindUnitPath(Name, Extension: TShortString): TShortString;
Var
 D, MainDir: DirStr;
 N: NameStr;
 E: ExtStr;
 S, Part, Candidate: TShortString;
 P: Integer;
Begin
 FindUnitPath:='';
  { TP6 consulte le repertoire de sortie avant les repertoires d'unites
    pour les TPU, mais PAS pour choisir le source a reconstruire. }
 If (Extension='.TPU') And (OutputDir<>'') Then Begin
  Candidate:=JoinPath(OutputDir,Name+Extension);
  If FileExists(Candidate) Then Begin
   FindUnitPath:=Candidate; Exit
  End;
 End;
 FSplit(SourceName,D,N,E); FSplit(MainSourceName,MainDir,N,E);
 If Length(D)+Length(MainDir)+Length(UnitDirs)+Length(TurboDirs)+5>255 Then    CLIError(
 'Liste de recherche des unites trop longue');
 If Extension='.OBJ' Then S:=D+';'+MainDir+';.;'+ObjectDirs+';'+UnitDirs
 Else S:=D+';'+MainDir+';.;'+UnitDirs+';'+TurboDirs;
 Repeat
 P:=Pos(';',S);
 If P=0 Then Begin
  Part:=S; S:=''
 End
  Else
 Begin
  Part:=Copy(S,1,P-1); Delete(S,1,P)
 End;
 Candidate:=JoinPath(Part,Name+Extension);
 If FileExists(Candidate) Then Begin
  FindUnitPath:=Candidate; Exit
 End;
 Until S='';
End;

Function Align16(N: Longint): Longint;Begin
 Align16:=(N+15) And Not Longint(15)
End;

Procedure QueueObject(Name: TShortString);
Var D: DirStr; N: NameStr; E: ExtStr; Path: TShortString; I: Word;
 F: File; Error: Integer; Count: Longint;
Begin
 Name:=Trim(Name);
 If (Length(Name)>1) And (Name[1]='''') And (Name[Length(Name)]='''') Then
  Name:=Copy(Name,2,Length(Name)-2);
 If Name='' Then Fail(17,'Nom OBJ manquant');
 FSplit(Name,D,N,E); If E='' Then Name:=Name+'.OBJ';
 If D='' Then Path:=FindUnitPath(N,Copy(Name,Length(N)+1,255))
 Else Begin
  FSplit(SourceName,D,N,E); Path:=JoinPath(D,Name);
  If Not FileExists(Path) Then Path:=Name;
 End;
 If Path='' Then Fail(15,'OBJ introuvable: '+Name);
 Path:=FExpand(Path);
 For I:=1 To ObjectCount Do
  If (Upper(ObjectFiles[I].Path)=Upper(Path)) And
     (ObjectFiles[I].Owner=CurrentUnit) Then Exit;
 If ObjectCount=MaxObjects Then Unsupported('trop de fichiers OBJ');
 Inc(ObjectCount); ObjectFiles[ObjectCount].Path:=Path;
 ObjectFiles[ObjectCount].Owner:=CurrentUnit;
 Assign(F,Path); OpenBinaryRead(F,Error);
 If Error<>0 Then Fail(15,'OBJ introuvable: '+Path);
 ObjectFiles[ObjectCount].Length:=FileSize(F);
 If (ObjectFiles[ObjectCount].Length<4) Or
    (ObjectFiles[ObjectCount].Length>SizeOf(TBinaryBuffer)) Then Fail(72,'Taille OBJ invalide');
 New(ObjectFiles[ObjectCount].Bytes);
 {$I-} BlockRead(F,ObjectFiles[ObjectCount].Bytes^,ObjectFiles[ObjectCount].Length,Count);
 Error:=IOResult; Close(F); If IOResult<>0 Then Error:=1; {$I+}
 If (Error<>0) Or (Count<>ObjectFiles[ObjectCount].Length) Then Fail(72,'Lecture OBJ impossible');
End;

{ OMF86 Use16. Les index du fichier sont traduits en index globaux lors
  de la lecture; aucun pointeur hote ne figure dans les records disque. }
Procedure ReadObject(Path: TShortString; B: PBinaryBuffer; FileLength: Longint);
Var
 P, Last, RecordEnd, Q: Longint;
 RecType, Check, A, C, D, Loc, FD, FM, TM: Byte;
 SegMap: Array[1..MaxObjSegments] Of Word;
 GroupMap: Array[1..MaxObjGroups] Of Word;
 ExtMap: Array[1..MaxObjNames] Of Word;
 Names: Array[1..MaxObjNames] Of String[63];
 SegCount, GroupCount, ExtCount, NameCount: Word;
 S, G, X, Offs, L, I, TI, FI, Disp: Word;
 LastSegment, LastOffset: Word; LastLength: Longint;
 FrameMethods, TargetMethods: Array[0..3] Of Byte;
 FrameIndices, TargetIndices: Array[0..3] Of Word;
 FrameDefined, TargetDefined: Array[0..3] Of Boolean;
 Name: TShortString; Started, Ended, Relative: Boolean;

Function GetByte: Byte;
Begin
 If P>=Last Then Fail(72,'Record OBJ tronque: '+Path);
 GetByte:=B^[P]; Inc(P);
End;
Function GetWord: Word;
Var V: Word;
Begin V:=GetByte; GetWord:=V+Word(GetByte)*256 End;
Function GetIndex: Word;
Var V: Word;
Begin
 V:=GetByte;
 If V And $80<>0 Then V:=(V And $7F)*256+GetByte;
 GetIndex:=V;
End;
Function GetName: TShortString;
Var V,K: Word; T: TShortString;
Begin
 V:=GetByte; If V>63 Then Unsupported('nom OMF de plus de 63 caracteres');
 T:=''; For K:=1 To V Do T:=T+Chr(GetByte);
 If T='' Then Fail(72,'Nom OMF vide'); GetName:=Upper(T);
End;
Function SegmentIndex(V: Word): Word;
Begin
 If (V=0) Or (V>SegCount) Then Fail(72,'Index SEGDEF OBJ invalide');
 SegmentIndex:=SegMap[V];
End;
Function GroupIndex(V: Word): Word;
Begin
 If (V=0) Or (V>GroupCount) Then Fail(72,'Index GRPDEF OBJ invalide');
 GroupIndex:=GroupMap[V];
End;
Function NameIndex(V: Word): TShortString;
Begin
 If (V=0) Or (V>NameCount) Then Fail(72,'Index LNAMES OBJ invalide');
 NameIndex:=Names[V];
End;
Function MethodIndex(Method: Byte; V: Word): Word;
Begin
 Case Method Of
  0:MethodIndex:=SegmentIndex(V);
  1:MethodIndex:=GroupIndex(V);
  2:Begin
   If (V=0) Or (V>ExtCount) Then Fail(72,'Index EXTDEF OBJ invalide');
   MethodIndex:=ExtMap[V];
  End;
 Else Fail(72,'Methode de fixup OMF invalide'); MethodIndex:=0;
 End;
End;
Procedure IteratedBlock(Depth: Word);
Var RepeatCount, Blocks, K: Word; Start, Finish, Length: Longint;
Begin
 If Depth>16 Then Fail(72,'LIDATA trop imbrique');
 RepeatCount:=GetWord; Blocks:=GetWord; Start:=LastLength;
 If Blocks=0 Then Begin
  K:=GetByte;
  If Longint(LastOffset)+LastLength+K>ObjectSegments[LastSegment].Length Then
   Fail(72,'LIDATA hors segment');
  While K<>0 Do Begin
   ObjectSegments[LastSegment].Bytes^[LastOffset+LastLength]:=GetByte;
   Inc(LastLength); Dec(K);
  End;
 End Else For K:=1 To Blocks Do IteratedBlock(Depth+1);
 Finish:=LastLength; Length:=Finish-Start;
 If RepeatCount=0 Then LastLength:=Start
 Else Begin
  If Longint(LastOffset)+Start+Length*RepeatCount>ObjectSegments[LastSegment].Length Then
   Fail(72,'Expansion LIDATA hors segment');
  For K:=2 To RepeatCount Do Begin
   Move(ObjectSegments[LastSegment].Bytes^[LastOffset+Start],
        ObjectSegments[LastSegment].Bytes^[LastOffset+LastLength],Length);
   Inc(LastLength,Length);
  End;
 End;
End;
Begin
 SegCount:=0; GroupCount:=0; ExtCount:=0; NameCount:=0;
 LastSegment:=0; LastOffset:=0; LastLength:=0; P:=0; Started:=False; Ended:=False;
 FillChar(FrameDefined,SizeOf(FrameDefined),0);
 FillChar(TargetDefined,SizeOf(TargetDefined),0);
 While P<FileLength Do Begin
  If Ended Then Fail(72,'Texte apres MODEND OBJ');
  If P+3>FileLength Then Fail(72,'En-tete record OBJ tronque');
  RecType:=B^[P]; L:=B^[P+1]+Word(B^[P+2])*256;
  If (L=0) Or (P+3+L>FileLength) Then Fail(72,'Longueur record OBJ invalide');
  RecordEnd:=P+3+L; Last:=RecordEnd-1;
  Check:=0; For Q:=P To RecordEnd-1 Do Check:=Check+B^[Q];
  If (B^[Last]<>0) And (Check<>0) Then Fail(72,'Checksum OBJ invalide');
  Inc(P,3);
  If Not Started And (RecType<>$80) Then Fail(72,'THEADR OBJ attendu');
  If (RecType<>$9C) And (RecType<>$A0) And (RecType<>$A2) Then LastSegment:=0;
  Case RecType Of
   $80:Begin
    If Started Then Fail(72,'THEADR OBJ duplique');
    Name:=GetName; Started:=True;
   End;
   $88,$94: P:=Last; { commentaires et numeros de lignes }
   $96:While P<Last Do Begin
    If NameCount=MaxObjNames Then Unsupported('trop de LNAMES OBJ');
    Inc(NameCount);
    { Le nom overlay vide est autorise dans LNAMES. }
    If B^[P]=0 Then Begin Names[NameCount]:=''; Inc(P) End
    Else Names[NameCount]:=GetName;
   End;
   $98:Begin
    If (SegCount=MaxObjSegments) Or (ObjectSegmentCount=MaxObjSegments) Then
     Unsupported('trop de segments OBJ');
    A:=GetByte; C:=(A Shr 2) And 7; D:=A Shr 5;
    If (A And 1<>0) Or (D=0) Or (D>4) Or Not (C In [0,2,4,5,6,7]) Then
     Unsupported('SEGDEF absolu/Use32/alignement/combinaison');
    If C In [4,7] Then C:=2; { synonymes PUBLIC OMF86 }
    L:=GetWord;
    If (A And 2<>0) And (L<>0) Then Fail(72,'SEGDEF Big avec longueur non nulle');
    Inc(ObjectSegmentCount); S:=ObjectSegmentCount;
    FillChar(ObjectSegments[S],SizeOf(TObjectSegment),0);
    ObjectSegments[S].Length:=L;
    If A And 2<>0 Then ObjectSegments[S].Length:=65536;
    X:=GetIndex; ObjectSegments[S].Name:=NameIndex(X);
    X:=GetIndex; ObjectSegments[S].ClassName:=NameIndex(X);
    X:=GetIndex; Name:=NameIndex(X);
    If Name<>'' Then Unsupported('overlay OBJ');
    ObjectSegments[S].Combine:=C; ObjectSegments[S].Alignment:=D;
    ObjectSegments[S].Root:=S;
    New(ObjectSegments[S].Bytes); FillChar(ObjectSegments[S].Bytes^,SizeOf(TBinaryBuffer),0);
    Inc(SegCount); SegMap[SegCount]:=S;
   End;
   $9A:Begin
    X:=GetIndex; Name:=NameIndex(X); G:=0;
    For I:=1 To ObjectGroupCount Do If ObjectGroups[I].Name=Name Then G:=I;
    If G=0 Then Begin
     If ObjectGroupCount=MaxObjGroups Then Unsupported('trop de groupes OBJ');
     Inc(ObjectGroupCount); G:=ObjectGroupCount;
     FillChar(ObjectGroups[G],SizeOf(TObjectGroup),0); ObjectGroups[G].Name:=Name;
    End;
    If GroupCount=MaxObjGroups Then Unsupported('trop de GRPDEF OBJ');
    Inc(GroupCount); GroupMap[GroupCount]:=G;
    While P<Last Do Begin
     If GetByte<>$FF Then Unsupported('composant GRPDEF non segment');
     X:=GetIndex; S:=SegmentIndex(X);
     If ObjectGroups[G].Count=MaxObjSegments Then Unsupported('groupe OBJ trop grand');
     Inc(ObjectGroups[G].Count); ObjectGroups[G].Members[ObjectGroups[G].Count]:=S;
    End;
   End;
   $8C:While P<Last Do Begin
    Name:=GetName; X:=GetIndex;
    If (ExtCount=MaxObjNames) Or (ObjectExternalCount=MaxObjNames) Then
     Unsupported('trop de EXTDEF OBJ');
    Inc(ObjectExternalCount); ObjectExternals[ObjectExternalCount]:=Name;
    Inc(ExtCount); ExtMap[ExtCount]:=ObjectExternalCount;
   End;
   $90:Begin
    X:=GetIndex; G:=0; If X<>0 Then G:=GroupIndex(X);
    X:=GetIndex; S:=0; If X<>0 Then S:=SegmentIndex(X);
    If S=0 Then Unsupported('PUBDEF absolu');
    While P<Last Do Begin
     Name:=GetName; Offs:=GetWord; X:=GetIndex;
     If Offs>ObjectSegments[S].Length Then Fail(72,'PUBDEF hors segment');
     For I:=1 To ObjectPublicCount Do If ObjectPublics[I].Name=Name Then
      Fail(4,'PUBDEF OBJ duplique: '+Name);
     If ObjectPublicCount=MaxObjNames Then Unsupported('trop de PUBDEF OBJ');
     Inc(ObjectPublicCount);
     ObjectPublics[ObjectPublicCount].Name:=Name;
     ObjectPublics[ObjectPublicCount].Segment:=S;
     ObjectPublics[ObjectPublicCount].GroupIndex:=G;
     ObjectPublics[ObjectPublicCount].Offset:=Offs;
    End;
   End;
   $A0,$A2:Begin
    X:=GetIndex; LastSegment:=SegmentIndex(X); LastOffset:=GetWord;
    LastLength:=0;
    If LastOffset>ObjectSegments[LastSegment].Length Then Fail(72,'Donnees OBJ hors segment');
    If RecType=$A0 Then Begin
     If Longint(LastOffset)+Last-P>ObjectSegments[LastSegment].Length Then
      Fail(72,'LEDATA hors segment');
     LastLength:=Last-P;
     Move(B^[P],ObjectSegments[LastSegment].Bytes^[LastOffset],LastLength); P:=Last;
    End Else Begin
     While P<Last Do IteratedBlock(0);
     { FIXUPP sur LIDATA exige les offsets du flux encode; refuse clairement. }
     LastSegment:=0;
    End;
   End;
   $9C:While P<Last Do Begin
    A:=GetByte;
    If A And $80=0 Then Begin
     I:=A And 3; FM:=(A Shr 2) And 7;
     If A And $20<>0 Then Fail(72,'Bit reserve THREAD OBJ');
     FI:=0;
     If FM<3 Then Begin X:=GetIndex; FI:=MethodIndex(FM,X) End;
     If A And $40<>0 Then Begin
      If Not (FM In [0,1,2,4,5]) Then Unsupported('methode frame THREAD OBJ');
      FrameMethods[I]:=FM; FrameIndices[I]:=FI; FrameDefined[I]:=True;
     End Else Begin
      If FM>2 Then Unsupported('methode target THREAD OBJ');
      TargetMethods[I]:=FM; TargetIndices[I]:=FI; TargetDefined[I]:=True;
     End;
    End Else Begin
     If LastSegment=0 Then Fail(72,'FIXUPP sans LEDATA');
     Loc:=(A Shr 2) And 15; Relative:=A And $40=0;
     Offs:=Word(A And 3)*256+GetByte;
     If Not (Loc In [0,1,2,3,5]) Then Unsupported('location FIXUPP non 16 bits');
     L:=2; If Loc=0 Then L:=1 Else If Loc=3 Then L:=4;
     If Longint(Offs)+L>LastLength Then Fail(72,'FIXUPP hors LEDATA');
     If Relative And Not (Loc In [0,1,5]) Then Fail(72,'FIXUPP relatif de segment');
     FD:=GetByte; FM:=(FD Shr 4) And 7; FI:=0;
     If FD And $80<>0 Then Begin
      I:=FM And 3; If Not FrameDefined[I] Then Fail(72,'Thread frame OBJ indefini');
      FM:=FrameMethods[I]; FI:=FrameIndices[I];
     End Else If FM<3 Then Begin X:=GetIndex; FI:=MethodIndex(FM,X) End;
     If Not (FM In [0,1,2,4,5]) Then Unsupported('methode frame FIXUPP');
     TM:=FD And 3;
     If FD And 8<>0 Then Begin
      If Not TargetDefined[TM] Then Fail(72,'Thread target OBJ indefini');
      TI:=TargetIndices[TM]; TM:=TargetMethods[TM];
     End Else Begin
      If TM=3 Then Unsupported('target absolu FIXUPP');
      X:=GetIndex; TI:=MethodIndex(TM,X);
     End;
     Disp:=0; If FD And 4=0 Then Disp:=GetWord;
     If ObjectFixupCount=MaxFixups Then Unsupported('trop de FIXUPP OBJ');
     Inc(ObjectFixupCount);
     With ObjectFixups[ObjectFixupCount] Do Begin
      Segment:=LastSegment; Offset:=LastOffset+Offs; FrameIndex:=FI;
      TargetIndex:=TI; Displacement:=Disp; Location:=Loc;
      FrameMethod:=FM; TargetMethod:=TM;
     End;
     ObjectFixups[ObjectFixupCount].Relative:=Relative;
    End;
   End;
   $8A:Begin
    A:=GetByte; If A<>0 Then Unsupported('MODEND OBJ avec point d''entree');
    Ended:=True;
   End;
  Else Begin Str(RecType,Name); Unsupported('record OMF '+Name) End;
  End;
  If P<>Last Then Fail(72,'Taille record OBJ incoherente');
  P:=RecordEnd;
 End;
 If Not Ended Then Fail(72,'MODEND OBJ manquant');
End;

Function UnitFileSize(Var H: TUnitHeader): Longint;
Var Size: Longint;
Begin
 Size:=Align16(H.EndTrace)+Align16(H.CodeSize)+Align16(H.ConstSize)+
 Align16(H.CodeFixupSize)+Align16(H.DataFixupSize);
 If (H.Flags=$8000) And (H.Reserved[0]=$5054) And (H.Reserved[1]=$3143) And
    (H.Reserved[2]>=5) Then Begin
  If H.Reserved[9]>3 Then Fail(72,'Payload OBJ TPU trop grand');
  Size:=Size+H.Reserved[8]+Longint(H.Reserved[9])*65536;
  If Size>SizeOf(TBinaryBuffer) Then Fail(72,'TPU avec OBJ trop grande');
 End;
 UnitFileSize:=Size;
End;

Procedure ValidateUnitHeader(Name: TShortString; Limit: Longint; Var H: TUnitHeader);Begin
 If (H.Signature[0]<>'T') Or (H.Signature[1]<>'P') Or
 (H.Signature[2]<>'U') Then    Fail(72,
 'Signature TPU attendue: '+Name);
 { Une unite d'une autre version (TPU0, TPU5, TPU6, TPU9) n'est pas
   compatible: TPC 7.0 signale alors "Unit version mismatch". }
 If H.Signature[3]<>TPUVersion Then Fail(70,Name+' est au format TPU'+H.Signature[3]+
  ', TPU'+TPUVersion+' attendu');
 If (H.EndTrace<SizeOf(H)) Or (UnitFileSize(H)>Limit) Or
 (H.Name<SizeOf(H)) Or (H.Name>=H.EndTrace) Or
 (H.Interf<SizeOf(H)) Or (H.Interf>=H.EndTrace) Then    Fail(72,
 'En-tete TPU incoherent: '+Name);
End;

Procedure ReadUnitHeaderAt(Name: TShortString; Base, Limit: Longint; Var H: TUnitHeader);
Var
 F: File;
 Count: Word;
 E: Integer;
 Size: Longint;
Begin
 Assign(F,Name); OpenBinaryRead(F,E);
 If E<>0 Then Fail(15,'Fichier introuvable: '+Name);
  {$I-} Size:=FileSize(F); E:=IOResult; {$I+}
 If (E<>0) Or (Base<0) Or (Base>Size-SizeOf(H)) Then Begin
  Close(F); Fail(72,'En-tete TPU/TPL hors fichier: '+Name);
 End;
 If Limit=0 Then Limit:=Size-Base;
 If (Limit<SizeOf(H)) Or (Limit>Size-Base) Then Begin
  Close(F); Fail(72,'Taille TPU/TPL incoherente: '+Name);
 End;
  {$I-} Seek(F,Base); BlockRead(F,H,SizeOf(H),Count); E:=IOResult;
 Close(F); If IOResult<>0 Then E:=1; {$I+}
 If (E<>0) Or (Count<>SizeOf(H)) Then Fail(72,'Unite tronquee: '+Name);
 ValidateUnitHeader(Name,Limit,H);
End;

Procedure ReadTPUHeader(Name: TShortString; Var H: TUnitHeader);Begin
 ReadUnitHeaderAt(Name,0,0,H)
End;

Function FindLibraryUnit(Name: TShortString): Word;
Var
 I: Word;
Begin
 FindLibraryUnit:=0;
 For I:=1 To LibraryCount Do If LibraryUnits[I].Name=Name Then Begin
  FindLibraryUnit:=I; Exit;
 End;
End;

Procedure ReadLibrary(Name: TShortString);
Var
 F: File;
 H: TUnitHeader;
 Base, Size, Span: Longint;
 Prefix: TSymbolPrefix;
 S: TShortString;
 Count: Word;
 E, I: Integer;
Begin
 LibraryCount:=0; LibraryName:=Name;
 Assign(F,Name); OpenBinaryRead(F,E);
 If E<>0 Then Fail(15,'Bibliotheque introuvable: '+Name);
 Size:=FileSize(F);
 If Size=0 Then Begin
  Close(F); Fail(72,'Bibliotheque TPL vide: '+Name)
 End;
 Base:=0;
 While Base<Size Do Begin
  If Size-Base<SizeOf(H) Then Fail(72,'En-tete TPL tronque: '+Name);
    {$I-} Seek(F,Base); BlockRead(F,H,SizeOf(H),Count); E:=IOResult; {$I+}
  If (E<>0) Or (Count<>SizeOf(H)) Then Fail(72,'En-tete TPL illisible: '+Name);
  ValidateUnitHeader(Name,Size-Base,H); Span:=UnitFileSize(H);
  If (H.Interf>=H.ProcMap) Or (H.ProcMap>H.CodeMap) Or
  (H.CodeMap>H.ConstMap) Or (H.ConstMap>H.DataMap) Or
  (H.DataMap>H.EndMaps) Or (H.EndMaps>H.Units) Or
  (H.Units>H.Sources) Or (H.Sources>H.Trace) Or
  (H.Trace>H.EndTrace) Or (H.Name+Longint(SizeOf(Prefix))>H.ProcMap) Then      Fail(72,
  'Sections TPL incoherentes: '+Name);
    {$I-} Seek(F,Base+H.Name); BlockRead(F,Prefix,SizeOf(Prefix),Count); E:=IOResult; {$I+}
  If (E<>0) Or (Count<>SizeOf(Prefix)) Or (Prefix.Typ<>89) Or
  (Prefix.NameLength=0) Or (Prefix.NameLength>63) Or
  (H.Name+Longint(SizeOf(Prefix))+Prefix.NameLength+8>H.ProcMap) Then      Fail(72,
  'Nom d''unite TPL invalide: '+Name);
  S:=''; S[0]:=Chr(Prefix.NameLength);
    {$I-} BlockRead(F,S[1],Prefix.NameLength,Count); E:=IOResult; {$I+}
  If (E<>0) Or (Count<>Prefix.NameLength) Then Fail(72,'Nom TPL tronque');
  S:=Upper(S);
  For I:=1 To Length(S) Do      If Not (S[I] In ['A'..'Z','_','0'..'9']) Then Fail(72,
  'Identificateur TPL invalide');
  If S[1] In ['0'..'9'] Then Fail(72,'Identificateur TPL invalide');
  If FindLibraryUnit(S)<>0 Then Fail(72,'Unite TPL dupliquee: '+S);
  If LibraryCount=MaxLibraryUnits Then Unsupported('plus de 256 unites TPL');
  Inc(LibraryCount); LibraryUnits[LibraryCount].Name:=S;
  LibraryUnits[LibraryCount].Offset:=Base; LibraryUnits[LibraryCount].Size:=Span;
  LibraryUnits[LibraryCount].Header:=H;
  Inc(Base,Span);
 End;
  {$I-} Close(F); E:=IOResult; {$I+}
 If E<>0 Then Fail(72,'Erreur de lecture TPL');
End;

Procedure FindAndReadLibrary;
Var
 D: DirStr;
 N: NameStr;
 E: ExtStr;
 S, Part, Candidate: TShortString;
 P: Integer;
Begin
 LibraryCount:=0; LibraryName:='';
 FSplit(FExpand(ParamStr(0)),D,N,E);
 If Length(TurboDirs)+Length(D)+4>255 Then CLIError('Liste de recherche TPL trop longue');
 S:='.;'+TurboDirs+';'+D;
 Repeat
 P:=Pos(';',S);
 If P=0 Then Begin
  Part:=S; S:=''
 End
  Else
 Begin
  Part:=Copy(S,1,P-1); Delete(S,1,P)
 End;
 If Part<>'' Then Begin
  Candidate:=JoinPath(Part,'TURBO.TPL');
  If FileExists(Candidate) Then Begin
   ReadLibrary(Candidate); Exit
  End;
 End;
 Until S='';
End;
{ Profil TPUQ/TPC1: conteneur TPUQ et structures historiques, mais ABI locale
  near/CS=DS. Reserved[0..2] = 'TP','C1',1 et Flags=$8000 l'identifient.
  Ces fichiers ne sont PAS annonces compatibles avec le linker Borland.
  Les fixups code $4000 sont relatifs IP, $8000 absolus DS; Map=$FFFF
  designe une routine du runtime local. Aucun pointeur hote sur disque. }

Function LocalOffset(Target: Word; U: Byte; IsCode: Boolean): Word;
Var
 I, N: Word;
Begin
 N:=0;
 If Target<>0 Then
 For I:=0 To Target-1 Do Begin
  If IsCode Then Begin
   If CodeOwners[I]=U Then Inc(N)
  End
  Else If DataOwners[I]=U Then Inc(N);
 End;
 LocalOffset:=N;
End;

Function GlobalOffset(Offset: Word; U: Byte; IsCode: Boolean): Word;
Var
 I, N, Limit, Last: Word;
Begin
 If IsCode Then Limit:=CodeSize Else Limit:=DataSize;
 N:=0; Last:=0;
 If Limit<>0 Then
 For I:=0 To Limit-1 Do Begin
  If (IsCode And (CodeOwners[I]=U)) Or (Not IsCode And (DataOwners[I]=U)) Then Begin
   If N=Offset Then Begin
    GlobalOffset:=I; Exit
   End;
   Inc(N); Last:=I+1;
  End;
 End;
 If IsCode And (N<>0) And (N=Offset) Then Begin
  GlobalOffset:=Last; Exit
 End;
 Fail(72,'Offset hors section d''unite'); GlobalOffset:=0;
End;

Function InterfaceChecksumMode(U: Byte; WithTypes, WithCalls, WithStructures: Boolean): Word;
Var
 I, K, N, Temp, T, Root: Word;
 J: Integer;
 H: Word;
 Order: Array[1..MaxSymbols] Of Word;
 Seen: Array[1..MaxTypes] Of Boolean;

Procedure Mix(W: Word);Begin
 H:=((H Shl 1) Or (H Shr 15))+W
End;
Procedure MixStructure(T: Word; Depth: Word);
Var F,C,I,J,K,Root: Word; Ordered: Array[1..MaxFields] Of Word;
Begin
 If T=0 Then Begin Mix(0); Exit End;
 If (Depth>MaxTypes) Or Seen[T] Then Begin Mix($FFFF); Exit End;
 Seen[T]:=True;
 Mix(Types[T].Typ); Mix(TypeExtras[T].Size);
 Mix(Word(Types[T].LowBound)); Mix(Word(Types[T].LowBound Shr 16));
 Mix(Word(Types[T].HighBound)); Mix(Word(Types[T].HighBound Shr 16));
 Root:=Types[T].Base;
 For I:=1 To Length(Types[Root].IdentityUnit) Do Mix(Ord(Types[Root].IdentityUnit[I]));
 For I:=1 To Length(Types[Root].IdentityName) Do Mix(Ord(Types[Root].IdentityName[I]));
 If Types[T].Typ=ttArray Then MixStructure(TypeExtras[T].IndexType,Depth+1);
 If Types[T].Typ In [ttArray,ttSet,ttPointer] Then MixStructure(TypeExtras[T].ElementType,Depth+1);
 If Types[T].Typ=ttRecord Then Begin
  C:=0; F:=TypeExtras[T].FirstField;
  While F<>0 Do Begin Inc(C); Ordered[C]:=F; F:=Fields[F].Next End;
  For I:=2 To C Do Begin
   J:=I;
   While J>1 Do Begin
    F:=Ordered[J]; K:=Ordered[J-1];
    If (Fields[K].Offset<Fields[F].Offset) Or
       ((Fields[K].Offset=Fields[F].Offset) And (Fields[K].Name<Fields[F].Name)) Then Break;
    Ordered[J]:=K; Ordered[J-1]:=F; Dec(J);
   End;
  End;
  Mix(C);
  For I:=1 To C Do Begin
   F:=Ordered[I]; Mix(Fields[F].Offset);
   For J:=1 To Length(Fields[F].Name) Do Mix(Ord(Fields[F].Name[J]));
   MixStructure(Fields[F].TypeId,Depth+1);
  End;
 End;
End;
Procedure MixExtra(T: Word);
Begin
 If WithStructures And (Types[T].Typ In [ttArray,ttRecord,ttSet,ttPointer]) Then Begin
  FillChar(Seen,SizeOf(Seen),0); MixStructure(T,0);
 End;
End;
Begin
 H:=0; N:=0;
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=U) And Symbols[I].Exported Then Begin
  Inc(N); Order[N]:=I;
 End;
 For I:=2 To N Do Begin
  K:=I;
  While K>1 Do Begin
   If Symbols[Order[K-1]].Name<Symbols[Order[K]].Name Then Break;
   Temp:=Order[K-1]; Order[K-1]:=Order[K]; Order[K]:=Temp; Dec(K);
  End;
 End;
 For K:=1 To N Do Begin
  I:=Order[K];
  For J:=1 To Length(Symbols[I].Name) Do Mix(Ord(Symbols[I].Name[J]));
  Mix(Symbols[I].Kind); Mix(Symbols[I].Typ);
  If WithCalls And (Symbols[I].Kind=skProc) Then Begin
   Mix(Ord(Symbols[I].FarRoutine)); Mix(Symbols[I].ParamCount); Mix(Symbols[I].ParamBytes);
   For J:=1 To Symbols[I].ParamCount Do Begin
    Mix(Symbols[I].ParamFlags[J]); T:=Symbols[I].ParamTypeIds[J];
    MixExtra(T);
    Mix(Types[T].Typ); Mix(Types[T].Width); Mix(Types[T].Capacity); Mix(Ord(Types[T].Signed));
    Mix(Word(Types[T].LowBound)); Mix(Word(Types[T].LowBound Shr 16));
    Mix(Word(Types[T].HighBound)); Mix(Word(Types[T].HighBound Shr 16));
    Root:=Types[T].Base;
    For Temp:=1 To Length(Types[Root].IdentityUnit) Do Mix(Ord(Types[Root].IdentityUnit[Temp]));
    For Temp:=1 To Length(Types[Root].IdentityName) Do Mix(Ord(Types[Root].IdentityName[Temp]));
   End;
  End;
  T:=SymbolType(I);
  If WithTypes And (T<>0) Then Begin
   MixExtra(T);
   Mix(Types[T].Width); Mix(Types[T].Capacity); Mix(Ord(Types[T].Signed));
   Mix(Word(Types[T].LowBound)); Mix(Word(Types[T].LowBound Shr 16));
   Mix(Word(Types[T].HighBound)); Mix(Word(Types[T].HighBound Shr 16));
   Root:=Types[T].Base;
   For J:=1 To Length(Types[Root].IdentityUnit) Do Mix(Ord(Types[Root].IdentityUnit[J]));
   For J:=1 To Length(Types[Root].IdentityName) Do Mix(Ord(Types[Root].IdentityName[J]));
  End;
  If Symbols[I].Kind=skConst Then Begin
   Mix(0); Mix(0)
  End
   Else
  Begin
   Mix(Symbols[I].Width); Mix(Symbols[I].Capacity)
  End;
  If Symbols[I].Kind=skConst Then Begin
   Mix(Word(Symbols[I].Value));
    If WithTypes Then Mix(Word(Symbols[I].Value Shr 16));
   For J:=0 To Length(Symbols[I].StrValue) Do Mix(Ord(Symbols[I].StrValue[J]));
  End;
 End;
 If H=0 Then H:=$FFFF;
 InterfaceChecksumMode:=H;
End;

Function InterfaceChecksum(U: Byte): Word;
Begin InterfaceChecksum:=InterfaceChecksumMode(U,True,True,True) End;

Function SoftwareChecksum: Word; Forward;
Function RuntimeNumber(Target: Word): Word;
Var K: Word;
Begin
 If RealReady And (Target>=RealCodeBase) And (Target<RealCodeEnd) Then Begin RuntimeNumber:=1024+Target-RealCodeBase; Exit End;
 If EmulatorReady And (Target>=EmulatorCodeBase) And (Target<EmulatorCodeEnd) Then Begin RuntimeNumber:=$8000+Target-EmulatorCodeBase; Exit End;
 For K:=1 To 96 Do If (RuntimeStandard[K]<>0) And (Target=RuntimeStandard[K]) Then Begin
  RuntimeNumber:=512+K; Exit;
 End;
 If Target=RuntimeUnsigned Then RuntimeNumber:=221 Else
 If Target=RuntimeString Then RuntimeNumber:=216 Else
 If Target=RuntimeInteger Then RuntimeNumber:=220 Else
 If Target=RuntimeBoolean Then RuntimeNumber:=224 Else
 If Target=RuntimeChar Then RuntimeNumber:=228 Else
 If Target=RuntimeCopy Then RuntimeNumber:=48 Else
 If Target=RuntimeHalt Then RuntimeNumber:=12 Else
 If Target=RuntimeError Then RuntimeNumber:=13
  Else
 Begin
  Unsupported('reference de code hors unite'); RuntimeNumber:=0
 End;
End;

Function RuntimeAddress(N: Word): Word;
Var P: Word;
Begin
 If N>=1024 Then Begin
  EnsureRealRuntime;
  If N>=$8000 Then Begin
   P:=RealSymbol('REMU'); P:=N-$8000; If P>=EmulatorCodeEnd-EmulatorCodeBase Then Fail(72,'Offset runtime 8087 invalide'); RuntimeAddress:=EmulatorCodeBase+P;
  End Else Begin P:=N-1024; If P>=RealCodeEnd-RealCodeBase Then Fail(72,'Offset runtime Real invalide'); RuntimeAddress:=RealCodeBase+P End;
  Exit;
 End;
 If (N>512) And (N<=608) And (RuntimeStandard[N-512]<>0) Then Begin
  If (N=538) Or (N=539) Or (N=541) Or (N=542) Or (N=545) Or (N=558) Then HeapNeeded:=True;
  RuntimeAddress:=RuntimeStandard[N-512]; Exit;
 End;
 Case N Of
 216:RuntimeAddress:=RuntimeString; 220:RuntimeAddress:=RuntimeInteger;
 224:RuntimeAddress:=RuntimeBoolean; 228:RuntimeAddress:=RuntimeChar;
 48:RuntimeAddress:=RuntimeCopy;
 12:RuntimeAddress:=RuntimeHalt;
 13:RuntimeAddress:=RuntimeError;
    221:RuntimeAddress:=RuntimeUnsigned;
  Else
 Begin
  Unsupported('routine du runtime TPU'); RuntimeAddress:=0
 End;
End;
End;

Function RuntimeDataNumber(P: Word): Word;
Begin
 If RealReady And (P>=RealDataBase) And (P<RealDataEnd) Then Begin RuntimeDataNumber:=1024+P-RealDataBase; Exit End;
 If EmulatorReady And (P>=EmulatorDataBase) And (P<EmulatorDataEnd) Then Begin RuntimeDataNumber:=$8000+P-EmulatorDataBase; Exit End;
 If P=RandomSeed Then RuntimeDataNumber:=1
 Else If P=FileModeAddress Then RuntimeDataNumber:=2
 Else If P=StandardInputAddress Then RuntimeDataNumber:=3
 Else If P=StandardOutputAddress Then RuntimeDataNumber:=4
 Else If P=RandomSeed+2 Then RuntimeDataNumber:=5
 Else If P=OverlayResult Then RuntimeDataNumber:=6
 Else If P=StringRing Then RuntimeDataNumber:=7
 Else If P=StringRingPos Then RuntimeDataNumber:=8
 Else If P=CrtHook Then RuntimeDataNumber:=9
 Else If P=RuntimeErrorText Then RuntimeDataNumber:=10
 Else If P=PrefixSeg Then RuntimeDataNumber:=11
 Else If P=InputError Then RuntimeDataNumber:=12
 Else Begin Unsupported('donnee runtime TPU inconnue'); RuntimeDataNumber:=0 End;
End;

Function RuntimeDataAddress(N: Word): Word;
Var P: Word;
Begin
 If N>=1024 Then Begin
  EnsureRealRuntime;
  If N>=$8000 Then Begin P:=RealSymbol('REMU'); P:=N-$8000; If P>=EmulatorDataEnd-EmulatorDataBase Then Fail(72,'Donnee runtime 8087 invalide'); RuntimeDataAddress:=EmulatorDataBase+P End
  Else Begin P:=N-1024; If P>=RealDataEnd-RealDataBase Then Fail(72,'Donnee runtime Real invalide'); RuntimeDataAddress:=RealDataBase+P End;
  Exit;
 End;
 If N=1 Then RuntimeDataAddress:=RandomSeed
 Else If N=2 Then RuntimeDataAddress:=FileModeAddress
 Else If N=3 Then RuntimeDataAddress:=StandardInputAddress
 Else If N=4 Then RuntimeDataAddress:=StandardOutputAddress
 Else If N=5 Then RuntimeDataAddress:=RandomSeed+2
 Else If N=6 Then RuntimeDataAddress:=OverlayResult
 Else If N=7 Then RuntimeDataAddress:=StringRing
 Else If N=8 Then RuntimeDataAddress:=StringRingPos
 Else If N=9 Then RuntimeDataAddress:=CrtHook
 Else If N=10 Then RuntimeDataAddress:=RuntimeErrorText
 Else If N=11 Then RuntimeDataAddress:=PrefixSeg
 Else If N=12 Then RuntimeDataAddress:=InputError
 Else Begin Fail(72,'Donnee runtime TPU invalide'); RuntimeDataAddress:=0 End;
End;

Procedure WriteCompiledUnit(U: Byte);
Var
 B: PBinaryBuffer;
 H: TUnitHeader;
 F: File;
 Posn, I, A, TypAddr, Bucket, CheckPos, CodeLen, DataLen: Word;
 FixLen, InitEntry, PayloadCheck: Word;
 V, TargetOwner: Byte;
 Refs: Array[0..MaxUnits] Of Word;
 Stubs: Array[0..MaxUnits] Of Word;
 MapStubs: Array[1..MaxSymbols] Of Word;
 SymbolEntries: Array[1..MaxSymbols] Of Word;
 FilePos, CodeStart, DataStart, RelStart: Longint;
 Count: Longint;
 E: Integer;
 Path: TShortString;
 D: DirStr;
 N: NameStr;
 Ext: ExtStr;
 NativeConstants: Boolean;
 MetadataCount,J,FieldCursor: Word;
 LastDebugFile: TShortString;

Procedure PutByte(X: Byte);Begin
 If Posn>=MaxImage Then Fail(123,'Dictionnaire TPU trop grand');
 B^[Posn]:=X; Inc(Posn);
End;

Procedure PutWord(X: Word);Begin
 PutByte(X And 255); PutByte(X Shr 8)
End;

Procedure SetWord(P, X: Word);Begin
 B^[P]:=X And 255; B^[P+1]:=X Shr 8
End;

Function GetWord(P: Word): Word;Begin
 GetWord:=B^[P]+Word(B^[P+1])*256
End;

Procedure PutString(S: TShortString);
Var
 K: Integer;
Begin
 PutByte(Length(S));
 For K:=1 To Length(S) Do PutByte(Ord(S[K]))
End;

Function SymbolEntry(S: TShortString; Kind: Byte): Word;
Var
 P: Word;
Begin
 P:=Posn; Bucket:=H.Interf+2+(HashIdent(S) And 126);
 PutWord(GetWord(Bucket)); SetWord(Bucket,P);
 PutByte(Kind); PutString(S); SymbolEntry:=P;
End;

Procedure UnitEntry(V: Byte; S: TShortString; Check: Word);
Var
 Prev, P: Word;
Begin
 Prev:=Stubs[U];
 If V<>U Then Begin
  Prev:=H.Name;
  While GetWord(Prev+4+B^[Prev+3]+4)<>0 Do        Prev:=GetWord(Prev+4+B^[Prev+3]+4);
 End;
 A:=SymbolEntry(S,89); Stubs[V]:=A;
 PutWord(0); PutWord(Check); PutWord(0); PutWord(0);
 If V<>U Then Begin
  P:=Prev+4+B^[Prev+3]; SetWord(P+4,A)
 End;
End;

Procedure Reloc(Position, Target: Word; IsData: Boolean);
Var
 Flags, Number: Word;
Begin
 If IsData Then Begin
  TargetOwner:=DataOwners[Target]; Flags:=$8000;
  Number:=LocalOffset(Target,TargetOwner,False);
 End Else
 Begin
      { Un saut vers la fin du corps peut viser le premier octet suivant. }
  If Target<CodeSize Then TargetOwner:=CodeOwners[Target] Else TargetOwner:=U;
  Flags:=$4000;
  Number:=LocalOffset(Target,TargetOwner,True);
  If Image[Position-1]=$E9 Then Begin
   TargetOwner:=U; Number:=LocalOffset(Target,U,True);
  End;
 End;
 If (TargetOwner<>U) And (TargetOwner<>0) And
 Not (TargetOwner In Units[U].Dependencies) Then      Unsupported(
 'reference TPU vers une unite non declaree');
 SetWord(Posn,Flags Or Refs[TargetOwner]); Inc(Posn,2);
 If TargetOwner=0 Then Begin
  SetWord(Posn,$FFFF); Inc(Posn,2);
  If IsData Then SetWord(Posn,RuntimeDataNumber(Target)) Else SetWord(Posn,RuntimeNumber(Target)); Inc(Posn,2);
 End Else
 Begin
  SetWord(Posn,0); Inc(Posn,2); SetWord(Posn,Number); Inc(Posn,2);
 End;
 SetWord(Posn,LocalOffset(Position,U,True)); Inc(Posn,2);
End;
Begin
  { Cas natif sans code ni dependance utilisateur: les constantes utilisent
    directement les types SYSTEM historiques. La compatibilite du layout
    est testee; une validation avec le linker Borland reste necessaire. }
 CaptureDebugSymbols(U);
 MetadataCount:=0; For I:=1 To DebugCount Do If DebugEntries[I].U=U Then Inc(MetadataCount);
 NativeConstants:=(MetadataCount=0) And UnitOutput And (U=1) And
 Not Units[U].HasInit And (Units[U].Dependencies=[]);
 For I:=1 To ObjectCount Do If ObjectFiles[I].Owner=U Then NativeConstants:=False;
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=U) And
 ((Symbols[I].Kind<>skConst) Or (Symbols[I].Typ=ttReal)) Then NativeConstants:=False;
  For I:=1 To SymbolCount Do If (Symbols[I].Owner=U) And Symbols[I].Exported And
    (Symbols[I].Kind=skConst) And (Symbols[I].Typ<>ttString) And
    ((Symbols[I].Width=4) Or (Symbols[I].Value<-32768) Or (Symbols[I].Value>65535)) Then NativeConstants:=False;
 New(B); FillChar(B^,SizeOf(TBinaryBuffer),0); FillChar(H,SizeOf(H),0);
 FillChar(MapStubs,SizeOf(MapStubs),0); FillChar(Refs,SizeOf(Refs),0);
 FillChar(SymbolEntries,SizeOf(SymbolEntries),0);
 FillChar(Stubs,SizeOf(Stubs),0);
 H.Signature[0]:='T'; H.Signature[1]:='P'; H.Signature[2]:='U'; H.Signature[3]:=TPUVersion;
 H.Flags:=$8000; H.Reserved[0]:=$5054; H.Reserved[1]:=$3143; H.Reserved[2]:=6;
 If (MetadataCount<>0) Or (UnitFeatures[U]<>0) Then H.Reserved[2]:=7;
 If UnitFeatures[U] And 24<>0 Then Begin H.Reserved[2]:=8; H.OverlayLength:=SoftwareChecksum End;
 If H.Reserved[2]>=7 Then H.CodeLength:=UnitFeatures[U] And 31;
 Units[U].Checksum:=InterfaceChecksum(U);
 Posn:=TPUHeaderSize; H.Interf:=Posn; PutWord(126);
 For I:=1 To 64 Do PutWord(0);
 H.Name:=Posn;
 If NativeConstants Then UnitEntry(U,Units[U].Name,0)
                    Else UnitEntry(U,Units[U].Name,Units[U].Checksum);
 CheckPos:=H.Name+4+Length(Units[U].Name)+2;
 UnitEntry(0,'SYSTEM',0);
 For V:=1 To UnitCount Do If V In Units[U].Dependencies Then    UnitEntry(V,Units[V].Name,
 Units[V].Checksum);
  { Types locaux: la partie segment reference le symbole d'unite. }
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=U) And Symbols[I].Exported Then Begin
  TypAddr:=Posn; PutByte(Symbols[I].Typ);
  If Symbols[I].Typ=ttInteger Then Begin
   If Symbols[I].Width=1 Then PutByte(2) Else PutByte(5);
  End Else PutByte(0);
  If (Symbols[I].Typ=ttString) And (Symbols[I].Kind=skConst) Then PutWord(256) Else
  If Symbols[I].Typ=ttString Then PutWord(Word(Symbols[I].Capacity)+1) Else
  If Symbols[I].Kind=skConst Then Begin
   If Symbols[I].Typ=ttInteger Then PutWord(2) Else PutWord(1);
  End Else PutWord(TypeExtras[SymbolType(I)].Size);
  PutWord(0);
  If Symbols[I].Typ=ttInteger Then Begin
   If Symbols[I].Width=1 Then Begin
    PutWord(0); PutWord(0); PutWord(255); PutWord(0)
   End
    Else
   Begin
    PutWord($8000); PutWord($FFFF); PutWord($7FFF); PutWord(0)
   End;
   PutWord(TypAddr); PutWord(H.Name+4+Length(Units[U].Name));
  End;
  Case Symbols[I].Kind Of
  skType:Begin
   A:=SymbolEntry(Symbols[I].Name,81); PutWord(TypAddr);
   PutWord(H.Name+4+Length(Units[U].Name));
  End;
  skConst:
  Begin
   A:=SymbolEntry(Symbols[I].Name,80);
   If NativeConstants Then Begin
    Case Symbols[I].Typ Of
    ttInteger:PutWord($114); ttChar:PutWord($14C);
    ttBoolean:PutWord($130); ttString:PutWord($A0);
   End;
   PutWord(Stubs[0]+4+6);
  End Else
  Begin
   PutWord(TypAddr); PutWord(H.Name+4+Length(Units[U].Name));
  End;
  If Symbols[I].Typ In [ttString,ttReal] Then PutString(Symbols[I].StrValue)
   Else
  Begin
   PutWord(Word(Symbols[I].Value));
  PutWord(Word(Symbols[I].Value Shr 16));
  End;
 End;
 skVar:
 Begin
  A:=SymbolEntry(Symbols[I].Name,82); PutByte(0);
  PutWord(LocalOffset(Symbols[I].Addr,U,False)); PutWord(0);
  PutWord(TypAddr); PutWord(H.Name+4+Length(Units[U].Name));
 End;
 skProc:
 Begin
  A:=SymbolEntry(Symbols[I].Name,83); MapStubs[I]:=A+4+Length(Symbols[I].Name);
  PutByte(Ord(Symbols[I].FarRoutine)); PutByte(0); PutWord(0); PutWord(0); PutWord(0); PutWord(0);
  PutByte(ttProc); PutByte(0); PutWord(0); PutWord(0);
  PutWord(0); PutWord(0); PutWord(0);
 End;
End;
 SymbolEntries[I]:=A;
End;
If Not NativeConstants Then Begin
 H.Reserved[5]:=Posn; PutWord(TypeCount);
 For I:=1 To TypeCount Do Begin
  If Longint(Posn)+SizeOf(TTypeInfo)>MaxImage Then Fail(123,'Types TPU trop grands');
  Move(Types[I],B^[Posn],SizeOf(TTypeInfo)); Inc(Posn,SizeOf(TTypeInfo));
 End;
 For I:=1 To TypeCount Do Begin
  PutWord(TypeExtras[I].Size); PutWord(TypeExtras[I].ElementType);
  PutWord(TypeExtras[I].IndexType); PutWord(TypeExtras[I].FieldCount);
  FieldCursor:=TypeExtras[I].FirstField;
  While FieldCursor<>0 Do Begin
   PutString(Fields[FieldCursor].Name); PutWord(Fields[FieldCursor].TypeId);
   PutWord(Fields[FieldCursor].Offset); FieldCursor:=Fields[FieldCursor].Next;
  End;
 End;
 MetadataCount:=0;
 For I:=1 To SymbolCount Do If (SymbolEntries[I]<>0) And (SymbolType(I)<>0) Then Inc(MetadataCount);
 PutWord(MetadataCount);
 For I:=1 To SymbolCount Do If (SymbolEntries[I]<>0) And (SymbolType(I)<>0) Then Begin
  PutWord(SymbolEntries[I]); PutWord(SymbolType(I));
 End;
 MetadataCount:=0;
 For I:=1 To SymbolCount Do If (SymbolEntries[I]<>0) And (Symbols[I].Kind=skProc) Then Inc(MetadataCount);
 PutWord(MetadataCount);
 For I:=1 To SymbolCount Do If (SymbolEntries[I]<>0) And (Symbols[I].Kind=skProc) Then Begin
  PutWord(SymbolEntries[I]); PutWord(Symbols[I].ParamCount); PutWord(Symbols[I].ParamBytes);
  PutWord(Ord(Symbols[I].FarRoutine));
  For J:=1 To Symbols[I].ParamCount Do Begin
   PutWord(Symbols[I].ParamTypeIds[J]); PutWord(Symbols[I].ParamFlags[J]);
  End;
 End;
 H.Reserved[6]:=Posn;
 MetadataCount:=0;
 For V:=1 To UnitCount Do If V In Units[U].NativeDependencies Then Inc(MetadataCount);
 PutWord(MetadataCount);
 For V:=1 To UnitCount Do If V In Units[U].NativeDependencies Then Begin
  PutString(Units[V].Name); PutWord(Units[V].Checksum);
 End;
 MetadataCount:=0;
 For I:=1 To NativeRefCount Do If CodeOwners[NativeRefs[I].Position]=U Then Inc(MetadataCount);
 PutWord(MetadataCount);
 For I:=1 To NativeRefCount Do If CodeOwners[NativeRefs[I].Position]=U Then Begin
  PutWord(LocalOffset(NativeRefs[I].Position,U,True));
  PutString(Units[NativeRefs[I].U].Name); PutWord(Units[NativeRefs[I].U].Checksum);
  PutWord(NativeRefs[I].Kind); PutWord(NativeRefs[I].Map); PutWord(NativeRefs[I].Target);
 End;
 MetadataCount:=0;
 For I:=1 To RelocationCount Do If (Relocations[I].Segm=0) And
   (CodeOwners[Relocations[I].Offs]=U) Then Inc(MetadataCount);
 PutWord(MetadataCount);
 For I:=1 To RelocationCount Do If (Relocations[I].Segm=0) And
   (CodeOwners[Relocations[I].Offs]=U) Then Begin
  PutWord(LocalOffset(Relocations[I].Offs,U,True)); PutWord(RelocationKinds[I]);
 End;
 MetadataCount:=0;
 For I:=1 To ObjectCount Do If ObjectFiles[I].Owner=U Then Inc(MetadataCount);
 For I:=1 To ObjectCallCount Do If CodeOwners[ObjectCalls[I].Position]=U Then Inc(MetadataCount);
 If (MetadataCount<>0) Or (H.Reserved[2]>=6) Then Begin
  H.Reserved[7]:=Posn;
  MetadataCount:=0;
  For I:=1 To ObjectCallCount Do If CodeOwners[ObjectCalls[I].Position]=U Then Inc(MetadataCount);
  PutWord(MetadataCount);
  For I:=1 To ObjectCallCount Do If CodeOwners[ObjectCalls[I].Position]=U Then Begin
   PutWord(LocalOffset(ObjectCalls[I].Position,U,True)); PutString(ObjectCalls[I].Name);
  End;
 End;
 If H.Reserved[2]>=7 Then Begin
  H.DebugHash:=Posn; MetadataCount:=0;
  For I:=1 To DebugCount Do If DebugEntries[I].U=U Then Inc(MetadataCount);
  PutWord(MetadataCount); LastDebugFile:='';
  For I:=1 To DebugCount Do If DebugEntries[I].U=U Then With DebugEntries[I] Do Begin
   PutByte(Kind);
   If Kind In [0,1] Then PutWord(LocalOffset(Address,U,True))
   Else If Kind=2 Then PutWord(LocalOffset(Address,U,False)) Else PutWord(Address);
   PutWord(Line); PutWord(Column); PutWord(Size);
   { Un nom vide signifie "meme fichier que l'entree precedente". }
   If FileName=LastDebugFile Then PutString('') Else PutString(FileName);
   LastDebugFile:=FileName; PutString(Name);
  End;
 End;
End;
If Odd(Posn) Then PutByte(0);
If NativeConstants Then Begin
 PayloadCheck:=0; I:=H.Interf;
 While I+1<Posn Do Begin
  PayloadCheck:=((PayloadCheck Shl 1) Or (PayloadCheck Shr 15))+GetWord(I);
  Inc(I,2);
 End;
 If PayloadCheck=0 Then PayloadCheck:=$FFFF;
 SetWord(CheckPos,PayloadCheck); Units[U].Checksum:=PayloadCheck;
End;
H.ProcMap:=Posn;
InitEntry:=$FFFF;
If Units[U].HasInit Then InitEntry:=LocalOffset(Units[U].InitAddress,U,True);
PutWord(0); PutWord(0);
If NativeConstants Then Begin
 PutWord($FFFF); PutWord(0)
End
 Else
Begin
 PutWord(0); PutWord(InitEntry)
End;
For I:=1 To SymbolCount Do If MapStubs[I]<>0 Then Begin
 SetWord(MapStubs[I]+2,Posn-H.ProcMap);
 PutWord(MapStubs[I]); PutWord(0); PutWord(0);
 PutWord(LocalOffset(Symbols[I].Addr,U,True));
End;
CodeLen:=LocalOffset(CodeSize,U,True); DataLen:=LocalOffset(DataSize,U,False);
If NativeConstants Then Begin
 CodeLen:=0; DataLen:=0
End;
FixLen:=0;
For I:=1 To FixupCount Do If CodeOwners[Fixups[I].Position]=U Then Begin
 If FixLen>MaxImage-8 Then Unsupported('trop de fixups dans une unite');
 Inc(FixLen,8);
End;
For I:=1 To RelativeCount Do If CodeOwners[RelativeFixups[I].Position]=U Then Begin
 If FixLen>MaxImage-8 Then Unsupported('trop de fixups dans une unite');
 Inc(FixLen,8);
End;
If Longint(Posn)+FixLen+1024>MaxImage Then Unsupported(
'dictionnaire et fixups TPU trop grands');
H.CodeMap:=Posn;
If Not NativeConstants Then Begin
 PutWord(0); PutWord(CodeLen); PutWord(FixLen); PutWord(0)
End;
H.ConstMap:=Posn;
If Not NativeConstants Then Begin
 PutWord(0); PutWord(DataLen); PutWord(0); PutWord(0)
End;
H.DataMap:=Posn; H.EndMaps:=Posn; H.Units:=Posn;
Refs[U]:=0; PutWord(0); PutString(Units[U].Name);
Refs[0]:=Posn-H.Units; PutWord(0); PutString('SYSTEM');
For V:=1 To UnitCount Do If V In Units[U].Dependencies Then Begin
 Refs[V]:=Posn-H.Units; PutWord(0); PutString(Units[V].Name);
End;
H.Sources:=Posn; H.Trace:=Posn; H.Browser:=Posn; H.EndTrace:=Posn;
If H.Reserved[2]<7 Then H.DebugHash:=H.Interf;
H.CodeSize:=CodeLen; H.ConstSize:=DataLen; H.CodeFixupSize:=FixLen;
H.Reserved[3]:=CheckPos; { profil: emplacement du checksum d'interface }
If NativeConstants Then Begin
 H.Flags:=0; FillChar(H.Reserved,SizeOf(H.Reserved),0);
End;
CodeStart:=Align16(Posn); FilePos:=CodeStart;
For I:=0 To CodeSize-1 Do If CodeOwners[I]=U Then Begin
 B^[FilePos]:=Image[I]; Inc(FilePos)
End;
DataStart:=CodeStart+Align16(CodeLen); FilePos:=DataStart;
If Not NativeConstants Then
For I:=0 To DataSize-1 Do If DataOwners[I]=U Then Begin
 B^[FilePos]:=Data[I]; Inc(FilePos)
End;
RelStart:=DataStart+Align16(DataLen);
  { Les fixups sont apres les deux sections; reutiliser un curseur Word
    uniquement dans une zone temporaire puis copier vers le fichier. }
Posn:=H.EndTrace;
For I:=1 To FixupCount Do If CodeOwners[Fixups[I].Position]=U Then    Reloc(
Fixups[I].Position,Fixups[I].DataOffset,True);
For I:=1 To RelativeCount Do If CodeOwners[RelativeFixups[I].Position]=U Then    Reloc(
RelativeFixups[I].Position,RelativeFixups[I].Target,False);
Move(B^[H.EndTrace],B^[RelStart],FixLen);
  { Effacer seulement la zone entre dictionnaire et code: elle avait servi
    de temporaire et peut recouvrir le code. Celui-ci est reconstitue. }
FilePos:=CodeStart;
For I:=0 To CodeSize-1 Do If CodeOwners[I]=U Then Begin
 B^[FilePos]:=Image[I]; Inc(FilePos)
End;
FilePos:=DataStart;
If Not NativeConstants Then
For I:=0 To DataSize-1 Do If DataOwners[I]=U Then Begin
 B^[FilePos]:=Data[I]; Inc(FilePos)
End;
FilePos:=RelStart+Align16(FixLen);
If H.Reserved[2]>=5 Then Begin
 MetadataCount:=0;
 For I:=1 To ObjectCount Do If ObjectFiles[I].Owner=U Then Inc(MetadataCount);
 If FilePos+2>SizeOf(TBinaryBuffer) Then Unsupported('TPU avec OBJ trop grande');
 B^[FilePos]:=MetadataCount And 255; B^[FilePos+1]:=MetadataCount Shr 8; Inc(FilePos,2);
 For I:=1 To ObjectCount Do If ObjectFiles[I].Owner=U Then Begin
  If FilePos+5+Length(ObjectFiles[I].Path)+ObjectFiles[I].Length>SizeOf(TBinaryBuffer) Then
   Unsupported('TPU avec OBJ trop grande');
  For J:=0 To 3 Do B^[FilePos+J]:=(ObjectFiles[I].Length Shr (J*8)) And 255;
  Inc(FilePos,4); B^[FilePos]:=Length(ObjectFiles[I].Path); Inc(FilePos);
  Move(ObjectFiles[I].Path[1],B^[FilePos],Length(ObjectFiles[I].Path));
  Inc(FilePos,Length(ObjectFiles[I].Path));
  Move(ObjectFiles[I].Bytes^,B^[FilePos],ObjectFiles[I].Length);
  Inc(FilePos,ObjectFiles[I].Length);
 End;
 If Align16(FilePos)>SizeOf(TBinaryBuffer) Then Unsupported('TPU avec OBJ trop grande');
 FilePos:=Align16(FilePos);
 H.Reserved[8]:=Word(FilePos-RelStart-Align16(FixLen));
 H.Reserved[9]:=(FilePos-RelStart-Align16(FixLen)) Shr 16;
End;
PayloadCheck:=0;
For CodeStart:=TPUHeaderSize To FilePos-1 Do    PayloadCheck:=((PayloadCheck Shl 1) Or (
PayloadCheck Shr 15))+B^[CodeStart];
If Not NativeConstants Then H.Reserved[4]:=PayloadCheck;
Move(H,B^,SizeOf(H));
FSplit(Units[U].Path,D,N,Ext);
If OutputDir='' Then Path:=D+Units[U].Name+'.TPU'
                Else Path:=JoinPath(OutputDir,Units[U].Name+'.TPU');
Assign(F,Path); {$I-} Rewrite(F,1); E:=IOResult; {$I+}
If E<>0 Then Begin
 Dispose(B); Fail(16,'Creation TPU impossible: '+Path)
End;
FilePos:=UnitFileSize(H);
  {$I-} BlockWrite(F,B^,FilePos,Count); E:=IOResult; Close(F);
If IOResult<>0 Then E:=1;
If (E<>0) Or (Count<>FilePos) Then Begin
 Erase(F); E:=IOResult; E:=1
End;
  {$I+}
Dispose(B);
If E<>0 Then Fail(16,'Ecriture TPU impossible: '+Path);
End;

Procedure WriteUnits;
Var
 U, V: Byte;
Begin
  { Checksums connus avant l'ecriture pour les cycles d'implementation. }
 For U:=1 To UnitCount Do If Units[U].FromSource Then    Units[U].Checksum:=
 InterfaceChecksum(U);
 For U:=1 To UnitCount Do
 For V:=1 To UnitCount Do    If (Units[U].DependencyChecks[V]<>0) And
 (Units[U].DependencyChecks[V]<>Units[V].Checksum) Then      Fail(70,Units[U].Name+' / '+
 Units[V].Name);
 For U:=1 To UnitCount Do If Units[U].FromSource And Not Units[U].Embedded Then WriteCompiledUnit(U);
End;
Procedure LoadCompiledUnit(U: Byte; Path: TShortString);Forward;
Function DecodeNativeType(U: Byte; Offset: Word): Word; Forward;

Procedure InstallOverlayUnit(U: Byte);
Var SavedUnit: Byte; SavedScope,I,K: Word; SavedInterface: Boolean;
 Names: Array[1..6] Of String[12];
Begin
 SavedUnit:=CurrentUnit; SavedScope:=CurrentScope; SavedInterface:=InInterface;
 CurrentUnit:=U; CurrentScope:=0; InInterface:=True;
 I:=NewSymbol('OVRRESULT'); Symbols[I].Kind:=skVar; ApplyType(I,1); Symbols[I].Addr:=OverlayResult;
 I:=NewSymbol('OVROK'); Symbols[I].Kind:=skConst; ApplyType(I,1); Symbols[I].Value:=0;
 I:=NewSymbol('OVRERROR'); Symbols[I].Kind:=skConst; ApplyType(I,1); Symbols[I].Value:=-1;
 I:=NewSymbol('OVRNOMEMORY'); Symbols[I].Kind:=skConst; ApplyType(I,1); Symbols[I].Value:=-2;
 Names[1]:='OVRINIT'; Names[2]:='OVRDONE'; Names[3]:='OVRCLEARBUF'; Names[4]:='OVRGETBUF'; Names[5]:='OVRSETBUF'; Names[6]:='';
 For K:=1 To 5 Do Begin
  I:=NewSymbol(Names[K]); Symbols[I].Kind:=skProc; Symbols[I].Addr:=RuntimeStandard[57+K];
  Symbols[I].FarRoutine:=True; Symbols[I].HasBody:=True; Symbols[I].DebugVisible:=False;
  If K=1 Then Begin
   Symbols[I].ParamCount:=1; Symbols[I].ParamBytes:=256; Symbols[I].ParamTypeIds[1]:=7;
   Symbols[I].ParamTypes[1]:=ttString; Symbols[I].ParamFlags[1]:=2; Symbols[I].ParamNames[1]:='FILENAME';
  End Else If K=4 Then ApplyType(I,9)
  Else If K=5 Then Begin
   Symbols[I].ParamCount:=1; Symbols[I].ParamBytes:=4; Symbols[I].ParamTypeIds[1]:=9;
   Symbols[I].ParamTypes[1]:=ttInteger; Symbols[I].ParamWidths[1]:=4; Symbols[I].ParamFlags[1]:=2; Symbols[I].ParamNames[1]:='SIZE';
  End;
 End;
 Units[U].Checksum:=InterfaceChecksum(U); Units[U].State:=2; Units[U].InterfaceReady:=True;
 CurrentUnit:=SavedUnit; CurrentScope:=SavedScope; InInterface:=SavedInterface;
End;

Function SoftwareChecksum: Word;
Var H,I,J: Word;
Begin
 H:=$8087;
 For I:=1 To High(RealSource) Do Begin
  For J:=1 To Length(RealSource[I]) Do H:=((H Shl 1) Or (H Shr 15))+Ord(RealSource[I][J]);
  H:=((H Shl 1) Or (H Shr 15))+10;
 End;
 For I:=1 To High(EmulatorSource) Do Begin
  For J:=1 To Length(EmulatorSource[I]) Do H:=((H Shl 1) Or (H Shr 15))+Ord(EmulatorSource[I][J]);
  H:=((H Shl 1) Or (H Shr 15))+10;
 End;
 If H=0 Then H:=$FFFF; SoftwareChecksum:=H;
End;
Procedure CompileSoftwareRuntime(Emulator: Boolean);
Var P: PParserState; I,N: Word; S: TShortString;
Begin
 SaveParser(P); CurrentScope:=0; Imports:=[]; ImportCount:=0;
 InInterface:=False; InProcedure:=False; InAssembler:=False;
 OptionBits:=0; DefineCount:=0; CondDepth:=0; Active:=True;
 SourceSize:=0; SourcePos:=1; Line:=1; Column:=1;
 If Emulator Then Begin
  CurrentUnit:=253; SourceName:='<8087 interne>'; N:=High(EmulatorSource);
  EmulatorCodeBase:=CodeSize; EmulatorDataBase:=DataSize;
 End Else Begin
  CurrentUnit:=254; SourceName:='<Real interne>'; N:=High(RealSource);
  RealCodeBase:=CodeSize; RealDataBase:=DataSize;
 End;
 For I:=1 To N Do Begin
  If Emulator Then S:=EmulatorSource[I] Else S:=RealSource[I];
  Move(S[1],Source[SourceSize+1],Length(S)); Inc(SourceSize,Length(S));
  Inc(SourceSize); Source[SourceSize]:=#10;
 End;
 NextToken; DeclarationPart;
 If Token<>tkEOF Then Fail(10,'Declaration runtime interne incomplete');
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=CurrentUnit) And
  (Symbols[I].Kind=skProc) And Not Symbols[I].HasBody Then Fail(59,Symbols[I].Name);
 If Emulator Then Begin EmulatorCodeEnd:=CodeSize; EmulatorDataEnd:=DataSize; EmulatorReady:=True End
 Else Begin RealCodeEnd:=CodeSize; RealDataEnd:=DataSize; RealReady:=True End;
 RestoreParser(P);
End;
Function EmbeddedUnit(Name: TShortString): Boolean;
Begin
 EmbeddedUnit:=(Name='CRT') Or (Name='DOS') Or (Name='STRINGS') Or (Name='PRINTER');
End;

Procedure LoadEmbeddedSource(Name: TShortString);
{ Charge le source integre de l'unite Name dans le tampon Source. }
Var I,N: Word; S: TShortString;
Begin
 SourceSize:=0;
 If Name='CRT' Then N:=High(CrtSource) Else If Name='DOS' Then N:=High(DosSource)
 Else If Name='STRINGS' Then N:=High(StringsSource) Else N:=High(PrinterSource);
 For I:=1 To N Do Begin
  If Name='CRT' Then S:=CrtSource[I] Else If Name='DOS' Then S:=DosSource[I]
  Else If Name='STRINGS' Then S:=StringsSource[I] Else S:=PrinterSource[I];
  Move(S[1],Source[SourceSize+1],Length(S)); Inc(SourceSize,Length(S));
  Inc(SourceSize); Source[SourceSize]:=#10;
 End;
 SourcePos:=1; Line:=1; Column:=1; CondDepth:=0; Active:=True;
End;

Procedure RequireUnit(Name: TShortString; Var U: Byte);
Var
 Path, Compiled: TShortString;
 Entry: Word;
Begin
 U:=FindBuildUnit(Name);
 If U<>0 Then Begin
  If (U=CurrentUnit) Or ((Units[U].State=1) And Not Units[U].InterfaceReady)
  Then      Fail(68,Name);
  Exit;
 End;
 If UnitCount=MaxUnits Then Unsupported('plus de 64 unites');
 If Name='OVERLAY' Then Begin
  Inc(UnitCount); U:=UnitCount; FillChar(Units[U],SizeOf(TBuildUnit),0);
  Units[U].Name:=Name; Units[U].Path:='<runtime local>'; InstallOverlayUnit(U); Exit;
 End;
 Entry:=FindLibraryUnit(Name);
 Path:=''; If (Entry=0) And BuildMode Then Path:=FindUnitPath(Name,'.PAS');
 If (Entry=0) And MakeMode And Not BuildMode Then Begin
  { /M: le source est recompile si la TPU manque ou est plus ancienne. }
  Path:=FindUnitPath(Name,'.PAS');
  If Path<>'' Then Begin
   Compiled:=FindUnitPath(Name,'.TPU');
   If (Compiled<>'') And (FileStamp(Compiled)>=FileStamp(Path)) Then Path:='';
  End;
 End;
 Inc(UnitCount); U:=UnitCount; FillChar(Units[U],SizeOf(TBuildUnit),0);
 Units[U].Name:=Name; Units[U].State:=1;
 Units[U].LibraryEntry:=Entry;
 If Entry<>0 Then LoadCompiledUnit(U,LibraryName) Else
 If Path<>'' Then CompileSourceUnit(U,Path)
  Else
 Begin
  Path:=FindUnitPath(Name,'.TPU');
  If (Path='') And EmbeddedUnit(Name) Then Begin
   { Unite standard integree (CRT, DOS, STRINGS, PRINTER). }
   Units[U].Embedded:=True; CompileSourceUnit(U,'<'+Name+'>'); Exit;
  End;
  If Path='' Then Fail(15,'Fichier introuvable: '+Name+'.TPU');
  LoadCompiledUnit(U,Path);
 End;
End;
Procedure EnsureRealRuntime;
Var P,SavedType: Word; SavedKnown,SavedUnsigned,SavedAssembler: Boolean; SavedValue: Longint;
Begin
 SavedType:=ExprType; SavedKnown:=ExprKnown; SavedUnsigned:=ExprUnsigned; SavedValue:=ExprValue; SavedAssembler:=InAssembler;
 If Not RealReady Then Begin P:=Jump; CompileSoftwareRuntime(False); PatchJump(P,CodeSize) End;
 If (CurrentUnit>0) And (CurrentUnit<=MaxUnits) Then UnitFeatures[CurrentUnit]:=UnitFeatures[CurrentUnit] Or 8;
 ExprType:=SavedType; ExprKnown:=SavedKnown; ExprUnsigned:=SavedUnsigned; ExprValue:=SavedValue; InAssembler:=SavedAssembler;
End;
Function RealSymbol(Name: TShortString): Word;
Var I,P: Word; SavedAssembler: Boolean;
Begin
 EnsureRealRuntime;
 If Name='REMU' Then Begin
  If Not EmulatorReady Then Begin
   SavedAssembler:=InAssembler; P:=Jump; CompileSoftwareRuntime(True); PatchJump(P,CodeSize); InAssembler:=SavedAssembler;
  End;
  If (CurrentUnit>0) And (CurrentUnit<=MaxUnits) Then UnitFeatures[CurrentUnit]:=UnitFeatures[CurrentUnit] Or 16;
 End;
 For I:=1 To SymbolCount Do If ((Symbols[I].Owner=254) Or ((Name='REMU') And (Symbols[I].Owner=253))) And
  (Symbols[I].Scope=0) And (Symbols[I].Name=Name) Then Begin RealSymbol:=I; Exit End;
 Fail(3,'Runtime Real: '+Name); RealSymbol:=0;
End;

Procedure LoadCompiledUnit(U: Byte; Path: TShortString);
Var
 B: PBinaryBuffer;
 H: TUnitHeader;
 F: File;
 P: PParserState;
 Size, Base, Count, CodeStart, DataStart, RelStart, X: Longint;
 A, Stub, I, J, Bucket, Next, Steps, W, R, Map, Target: Word;
 ParamN, K, FieldN, FieldIndex, FieldType, FieldOffset: Word;
  MetaPos, MetaCount, DiskCount, TIndex, NewIndex: Word;
  DiskTypes: Array[1..MaxTypes] Of TTypeInfo;
  TypeMap: Array[1..MaxTypes] Of Word;
 MapSum, FixSum: Longint;
 V, Typ, Width, Capacity, Kind: Byte;
 IsLocal, ProjectForeign, TypeSupported, TypeSigned,DebugSymbolPresent: Boolean;
 LoadCompiledUnitLastFile: TShortString;
 Name: TShortString;
 RefOffsets, RefChecks: Array[0..MaxUnits+1] Of Word;
 RefUnits: Array[0..MaxUnits+1] Of Byte;
 RefCount: Integer;
 E: Integer;
 Value: Longint;
 DecodedTypeId: Word;

Procedure Bounds(P, N: Longint);Begin
 If (P<0) Or (N<0) Or (P>Size-N) Then Fail(72,'Reference TPU hors fichier');
End;

Procedure DictBounds(P, N: Longint);Begin
 Bounds(P,N);
 If (P<TPUHeaderSize) Or (P+N>H.ProcMap) Then Fail(72,'Reference hors dictionnaire TPU');
End;

Function ReadWord(P: Longint): Word;Begin
 Bounds(P,2); ReadWord:=B^[P]+Word(B^[P+1])*256
End;

Function ReadString(P: Longint): TShortString;
Var
 K: Integer;
 S: TShortString;
Begin
 Bounds(P,1); Bounds(P+1,B^[P]); S:='';
 For K:=1 To B^[P] Do S:=S+Chr(B^[P+K]);
 ReadString:=S;
End;

Function SymbolStub(P: Word): Word;Begin
 DictBounds(P,4); DictBounds(P,4+B^[P+3]);
 If (B^[P+3]=0) Or (B^[P+3]>63) Then Fail(72,'Nom de symbole TPU invalide');
 SymbolStub:=P+4+B^[P+3];
End;

Function CheckForUnit(S: TShortString): Word;
Var
 K, Addr, Limit: Word;
Begin
 CheckForUnit:=0;
 For K:=0 To ReadWord(H.Interf) Div 2 Do Begin
  Addr:=ReadWord(H.Interf+2+K*2); Limit:=0;
  While Addr<>0 Do Begin
   Inc(Limit); If Limit>MaxSymbols Then Fail(72,'Cycle dans le hash TPU');
   W:=SymbolStub(Addr);
   If (Upper(ReadString(Addr+3))=S) And (B^[Addr+2]=89) Then Begin
    DictBounds(W,8);
    CheckForUnit:=ReadWord(W+2); Exit;
   End;
   DictBounds(Addr,4); Addr:=ReadWord(Addr);
  End;
 End;
End;

Procedure DecodeType(P: Word);
Var
 T, S, Addr, StubAddr, Limit: Word;
 UnitName: TShortString;

Procedure Reject(S: TShortString);Begin
 If ProjectForeign Then TypeSupported:=False Else Unsupported(S);
End;
Begin
 TypeSupported:=True; TypeSigned:=False;
 DecodedTypeId:=0;
 DictBounds(P,4); T:=ReadWord(P); S:=ReadWord(P+2);
 Width:=0; Capacity:=0;
 If ProjectForeign Then Begin
  Addr:=H.Name; Limit:=0; UnitName:='';
  While Addr<>0 Do Begin
   Inc(Limit); If Limit>MaxUnits+2 Then Fail(72,'Cycle des stubs de types Borland');
   StubAddr:=SymbolStub(Addr); DictBounds(StubAddr,8);
   If S=StubAddr Then Begin UnitName:=Upper(ReadString(Addr+3)); Break End;
   Addr:=ReadWord(StubAddr+4);
  End;
  If UnitName='' Then Fail(72,'Proprietaire de type Borland invalide');
  If (UnitName='SYSTEM') And (FindBuildUnit('SYSTEM')=0) And
     (FindLibraryUnit('SYSTEM')=0) And (FindUnitPath('SYSTEM','.TPU')='') Then Begin
   { Import de constantes sans runtime: offsets standard verifies dans
     COMPILER.INC. Aucun code n'est lie par ce chemin de secours. }
   Case T Of
    $A0:DecodedTypeId:=7; $DE:DecodedTypeId:=2; $F0:DecodedTypeId:=1;
    $102:DecodedTypeId:=3; $130:DecodedTypeId:=5; $14C:DecodedTypeId:=6;
    $114:DecodedTypeId:=NewType(ttInteger,4,0,True,-2147483647-1,2147483647,1);
   Else Begin Reject('type SYSTEM sans descripteur disponible'); Exit End;
   End;
   Typ:=Types[DecodedTypeId].Typ; Width:=Types[DecodedTypeId].Width;
   Capacity:=Types[DecodedTypeId].Capacity; TypeSigned:=Types[DecodedTypeId].Signed;
   Exit;
  End;
  If UnitName=Units[U].Name Then V:=U Else RequireUnit(UnitName,V);
  DecodedTypeId:=DecodeNativeType(V,T);
  If DecodedTypeId=0 Then Begin Reject('descripteur de type Borland non pris en charge'); Exit End;
  Typ:=Types[DecodedTypeId].Typ; Width:=Types[DecodedTypeId].Width;
  Capacity:=Types[DecodedTypeId].Capacity; TypeSigned:=Types[DecodedTypeId].Signed;
  Exit;
 End;
 If S=SymbolStub(H.Name) Then Begin
  DictBounds(T,6); Typ:=B^[T]; W:=ReadWord(T+2);
  If IsLocal And (H.Reserved[2]>=6) And (Typ In [ttArray,ttRecord,ttSet,ttFile,ttText]) Then Begin
   Width:=0; Exit;
  End;
  TypeSigned:=(Typ=ttInteger) And (B^[T+1] And 1<>0);
  If (Typ<>ttString) And Not (IsLocal And (Typ=ttReal) And (W=6)) And (W>4) Then Begin
   Reject('taille de type TPU'); Exit
  End;
  Width:=W;
  If Typ=ttString Then Begin
   W:=ReadWord(T+2);
   If (W<2) Or (W>256) Then Fail(72,'Type string TPU invalide');
   Capacity:=W-1; Width:=0;
  End;
  If (Typ=ttInteger) And Not (Width In [1,2]) And Not ((Width=4) And IsLocal And (H.Reserved[2]>=6)) And
  Not ((Kind=80) And (Width=4) And Not IsLocal) Then Begin
   Reject('type entier TPU > 16 bits'); Exit
  End;
 End Else
 Begin
      { Les pointeurs disque originaux referencent un symbole d'unite,
        pas un segment hote. Types SYSTEM standards dans COMPILER.INC. }
  Addr:=H.Name; Limit:=0; UnitName:='';
  While Addr<>0 Do Begin
   Inc(Limit); If Limit>MaxUnits+2 Then Fail(72,'Cycle des stubs d''unites TPU');
   StubAddr:=SymbolStub(Addr); DictBounds(StubAddr,8);
   If S=StubAddr Then Begin
    UnitName:=Upper(ReadString(Addr+3)); Break
   End;
   Addr:=ReadWord(StubAddr+4);
  End;
  If UnitName='' Then Fail(72,'Segment du type TPU invalide');
  If UnitName<>'SYSTEM' Then Begin
   Reject('type d''une autre unite TPU'); Exit
  End;
  Case T Of
  $A0:
  Begin
   Typ:=ttString; Capacity:=255
  End;
  $DE:
  Begin
   Typ:=ttInteger; Width:=1
  End;
  $F0:
  Begin
   Typ:=ttInteger; Width:=2
  End;
  $102:
  Begin
   Typ:=ttInteger; Width:=2
  End;
  $114:
  Begin
   Typ:=ttInteger; Width:=4
  End;
  $130:
  Begin
   Typ:=ttBoolean; Width:=1
  End;
  $14C:
  Begin
   Typ:=ttChar; Width:=1
  End;
   Else
  Begin
   Reject('type SYSTEM non pris en charge dans la TPU'); Exit
  End;
 End;
End;
  If IsLocal And (H.Reserved[2]>=6) And (Typ In [ttPointer,ttArray,ttRecord,ttSet,ttFile,ttText,ttReal]) Then Exit;
  If Not (Typ In [ttString,ttInteger,ttBoolean,ttChar,ttEnum]) Then Begin
 Reject('type TPU non pris en charge'); Exit;
End;
If (Typ In [ttChar,ttBoolean]) And (Width<>1) Then Fail(72,'Taille ordinale TPU invalide')
;
End;
Begin
 Base:=0; Size:=0;
 If Units[U].LibraryEntry<>0 Then Begin
  Base:=LibraryUnits[Units[U].LibraryEntry].Offset;
  Size:=LibraryUnits[Units[U].LibraryEntry].Size;
 End;
 ReadUnitHeaderAt(Path,Base,Size,H);
 SaveParser(P); CurrentUnit:=U; SourceName:=Path;
  CurrentScope:=0;
 TokenLine:=1; TokenColumn:=1; InInterface:=True; Imports:=[]; ImportCount:=0;
 Units[U].Path:=Path;
 Assign(F,Path); OpenBinaryRead(F,E);
 If E<>0 Then Fail(15,Path);
 If Units[U].LibraryEntry=0 Then Size:=FileSize(F);
 If (Size<TPUHeaderSize) Or (Size>SizeOf(TBinaryBuffer)) Then Begin
  Close(F); Fail(72,'Taille TPU invalide')
 End;
 New(B);
  {$I-} Seek(F,Base); BlockRead(F,B^,Size,Count); E:=IOResult; Close(F);
 If IOResult<>0 Then E:=1; {$I+}
 If (E<>0) Or (Count<>Size) Then Fail(72,'Lecture TPU incomplete');
 If (H.Interf>=H.ProcMap) Or (H.ProcMap>H.CodeMap) Or
 (H.CodeMap>H.ConstMap) Or (H.ConstMap>H.DataMap) Or
 (H.DataMap>H.EndMaps) Or (H.EndMaps>H.Units) Or
 (H.Units>H.Sources) Or (H.Sources>H.EndTrace) Then    Fail(72,
 'Ordre des sections TPU invalide');
 A:=SymbolStub(H.Name); DictBounds(A,8);
 If B^[H.Name+2]<>89 Then Fail(72,'Symbole de nom TPU invalide');
 Name:=Upper(ReadString(H.Name+3));
 If Name<>Units[U].Name Then Fail(69,Name+' <> '+Units[U].Name);
 Units[U].Checksum:=ReadWord(A+2);
 IsLocal:=(H.Flags=$8000) And (H.Reserved[0]=$5054) And (H.Reserved[1]=$3143);
 ProjectForeign:=Not IsLocal;
  If IsLocal And Not (H.Reserved[2] In [1,2,3,4,5,6,7,8]) Then Fail(72,'Version du profil TPC1 inconnue');
 If IsLocal Then Begin
  W:=0;
  For X:=TPUHeaderSize To Size-1 Do W:=((W Shl 1) Or (W Shr 15))+B^[X];
  If W<>H.Reserved[4] Then Fail(72,'Integrite de la TPU TPC1 invalide');
 End;
 If IsLocal And (H.Reserved[2]=8) Then Begin
  If H.OverlayLength<>SoftwareChecksum Then Fail(70,'Runtime Real/8087 interne modifie: reconstruire la TPU');
  CurrentUnit:=0; { resident runtime precedes this unit's imported code }
  If H.CodeLength And 8<>0 Then EnsureRealRuntime;
  If H.CodeLength And 16<>0 Then W:=RealSymbol('REMU');
  CurrentUnit:=U;
 End;
 If Not IsLocal Then Begin
  If ((H.CodeMap-H.ProcMap) Mod 8<>0) Or
  ((H.ConstMap-H.CodeMap) Mod 8<>0) Or ((H.DataMap-H.ConstMap) Mod 8<>0) Or
  ((H.EndMaps-H.DataMap) Mod 8<>0) Then Fail(72,'Cartes natives TPU invalides');
  MapSum:=0; FixSum:=0; X:=H.CodeMap;
  While X<H.ConstMap Do Begin
    If ReadWord(X+4) Mod 8<>0 Then Fail(72,'Fixups code Borland non alignes');
   If Longint(MapSum)+ReadWord(X+2)>65535 Then Fail(72,'Code natif trop grand');
   Inc(MapSum,ReadWord(X+2)); Inc(FixSum,ReadWord(X+4)); Inc(X,8);
  End;
  If (MapSum<>H.CodeSize) Or (FixSum<>H.CodeFixupSize) Then Fail(72,
  'Tailles code natif incoherentes');
  MapSum:=0; FixSum:=0; X:=H.ConstMap;
  While X<H.DataMap Do Begin
    If ReadWord(X+4) Mod 8<>0 Then Fail(72,'Fixups constantes Borland non alignes');
   Inc(MapSum,ReadWord(X+2)); Inc(FixSum,ReadWord(X+4)); Inc(X,8);
  End;
  If (MapSum<>H.ConstSize) Or (FixSum<>H.DataFixupSize) Then Fail(72,
  'Tailles constantes natives incoherentes');
  MapSum:=0; X:=H.DataMap;
  While X<H.EndMaps Do Begin
   Inc(MapSum,ReadWord(X+2)); Inc(X,8)
  End;
  If MapSum<>H.DataSize Then Fail(72,'Taille donnees natives incoherente');
  NativeBuffers[U]:=B; NativeHeaders[U]:=H;
 End;
 CodeStart:=Align16(H.EndTrace); DataStart:=CodeStart+Align16(H.CodeSize);
 RelStart:=DataStart+Align16(H.ConstSize);
 Units[U].CodeBase:=CodeSize; Units[U].DataBase:=DataSize;
 If IsLocal Then Begin
  If (H.ConstMap-H.CodeMap<>8) Or (H.DataMap-H.ConstMap<>8) Or
  (H.EndMaps<>H.DataMap) Or (H.DataSize<>0) Or (H.DataFixupSize<>0) Or
  ((H.CodeMap-H.ProcMap) Mod 8<>0) Or (H.CodeMap-H.ProcMap<8) Or
  (H.CodeFixupSize Mod 8<>0) Then Fail(72,'Cartes du profil TPC1 invalides');
  If (ReadWord(H.CodeMap+2)<>H.CodeSize) Or
  (ReadWord(H.CodeMap+4)<>H.CodeFixupSize) Or
  (ReadWord(H.ConstMap+2)<>H.ConstSize) Then Fail(72,'Tailles cartes incoherentes');
  If H.CodeSize<>0 Then
  For I:=0 To H.CodeSize-1 Do Emit(B^[CodeStart+I]);
  A:=AllocData(H.ConstSize);
  If H.ConstSize<>0 Then Move(B^[DataStart],Data[A],H.ConstSize);
  W:=ReadWord(H.ProcMap+6);
  If W<>$FFFF Then Begin
   If W>=H.CodeSize Then Fail(72,'Initialisation TPU hors code');
   Units[U].HasInit:=True; Units[U].InitAddress:=Units[U].CodeBase+W;
  End;
 End;
 DictBounds(H.Interf,2); W:=ReadWord(H.Interf);
 If (W>510) Or Odd(W) Then Fail(72,'Hash TPU invalide');
 DictBounds(H.Interf,Word(W)+4);
 For Bucket:=0 To W Div 2 Do Begin
  A:=ReadWord(H.Interf+2+Bucket*2); Steps:=0;
  While A<>0 Do Begin
   Inc(Steps); If Steps>MaxSymbols Then Fail(72,'Cycle de symboles TPU');
   Stub:=SymbolStub(A); Next:=ReadWord(A); Kind:=B^[A+2];
   Name:=Upper(ReadString(A+3));
      If Kind In [80,81,82,83] Then Begin
    I:=NewSymbol(Name);
        If Kind=81 Then Begin
          Symbols[I].Kind:=skType; DecodeType(Stub);
          If Not TypeSupported Or ((Width>2) And Not IsLocal) Then Symbols[I].Kind:=skForeign
          Else Begin
            Symbols[I].Typ:=Typ; Symbols[I].Width:=Width; Symbols[I].Capacity:=Capacity;
            If ProjectForeign Then Begin
              ApplyType(I,DecodedTypeId);
            End;
          End;
        End Else If ProjectForeign And (Kind=83) Then Begin
     Symbols[I].Kind:=skForeign;
     DictBounds(Stub,22); ParamN:=ReadWord(Stub+20);
     Map:=ReadWord(Stub+2);
     If (Map Mod 8<>0) Or (Map+Longint(8)>H.CodeMap-H.ProcMap) Then            Fail(72,
     'Carte procedure native invalide');
     If (ParamN<=MaxNativeParams) And (B^[Stub] And $F6=0) And
     (B^[Stub] And 1<>0) And (ReadWord(H.ProcMap+Map+4)<>$FFFF) Then Begin
      DictBounds(Stub,22+5*ParamN);
      If (ReadWord(Stub+16)=0) And (ReadWord(Stub+18)=0) Then Begin
       TypeSupported:=True; TypeSigned:=False; Typ:=ttVoid; Width:=0;
      DecodedTypeId:=0;
      End Else DecodeType(Stub+16);
      If TypeSupported And (Typ<>ttString) And (Width<=2) Then Begin
       Symbols[I].Typ:=Typ; Symbols[I].Width:=Width;
       Symbols[I].SignedByte:=TypeSigned And (Width=1);
      Symbols[I].TypeId:=DecodedTypeId;
       Symbols[I].Kind:=skProc; Symbols[I].Native:=True;
       Symbols[I].NativeMap:=Map; Symbols[I].ParamCount:=ParamN;
       For K:=1 To ParamN Do Begin
        DecodeType(Stub+22+(K-1)*5);
        If Not TypeSupported Or (Width>2) Or
        Not (B^[Stub+26+(K-1)*5] In [2,6]) Then Symbols[I].Kind:=skForeign;
        Symbols[I].ParamTypes[K]:=Typ; Symbols[I].ParamWidths[K]:=Width;
        Symbols[I].ParamFlags[K]:=B^[Stub+26+(K-1)*5];
        Symbols[I].ParamSigned[K]:=TypeSigned And (Width=1);
        Symbols[I].ParamTypeIds[K]:=DecodedTypeId;
       End;
      End;
     End;
    End Else If ProjectForeign And (Kind=82) Then Begin
     Symbols[I].Kind:=skForeign; DictBounds(Stub,9); DecodeType(Stub+5);
     If TypeSupported And (Typ<>ttString) And (Width<=2) And (B^[Stub] In [0,1])
     Then Begin
      Map:=ReadWord(Stub+3); Target:=ReadWord(Stub+1);
      If B^[Stub]=1 Then J:=H.ConstMap Else J:=H.DataMap;
      If (Map Mod 8<>0) Or ((B^[Stub]=1) And (Longint(J)+Map+8>H.DataMap)) Or
      ((B^[Stub]=0) And (Longint(J)+Map+8>H.EndMaps)) Then Fail(72,
      'Carte variable native invalide');
      If Longint(Target)+Width>ReadWord(J+Map+2) Then Fail(72,
      'Variable native hors carte');
      Symbols[I].Kind:=skVar; Symbols[I].Native:=True;
      Symbols[I].Typ:=Typ; Symbols[I].Width:=Width;
      Symbols[I].SignedByte:=TypeSigned And (Width=1);
      Symbols[I].TypeId:=DecodedTypeId;
      Symbols[I].NativeMap:=Map; Symbols[I].NativeConst:=B^[Stub]=1;
      Symbols[I].Addr:=Target;
     End;
    End Else If Kind=83 Then Begin
     If Not IsLocal Then Unsupported('procedure TPU Borland');
     DictBounds(Stub,22);
     Map:=ReadWord(Stub+2);
     If (Map Mod 8<>0) Or (Map>=H.CodeMap-H.ProcMap) Then Fail(72,'ProcMap TPU invalide');
     Target:=ReadWord(H.ProcMap+Map+6);
     If Target>=H.CodeSize Then Fail(72,'Procedure TPU hors code');
     Symbols[I].Kind:=skProc; Symbols[I].HasBody:=True;
    Symbols[I].LegacyCall:=H.Reserved[2]<3;
     Symbols[I].Addr:=Units[U].CodeBase+Target;
    End Else
    Begin
     If Kind=80 Then Begin
      Symbols[I].Kind:=skConst; DecodeType(Stub);
      Symbols[I].TypeId:=DecodedTypeId;
      If Not TypeSupported Then Symbols[I].Kind:=skForeign Else
      If Typ In [ttString,ttReal] Then Begin
       DictBounds(Stub+4,1); DictBounds(Stub+4,1+B^[Stub+4]);
       Symbols[I].StrValue:=ReadString(Stub+4);
       If Typ=ttReal Then Begin
        If Length(Symbols[I].StrValue)<>6 Then Fail(72,'Constante Real TPU invalide');
        Symbols[I].Addr:=AllocData(6); Move(Symbols[I].StrValue[1],Data[Symbols[I].Addr],6);
       End Else Symbols[I].Addr:=StoreString(Symbols[I].StrValue);
      End Else
      Begin
       DictBounds(Stub+4,4); Value:=ReadWord(Stub+4);
              If IsLocal And (H.Reserved[2]>=2) Then Begin
                Move(B^[Stub+4],Value,4);
                If (H.Reserved[2]<6) And ((Value<-32768) Or (Value>65535)) Then Fail(72,'Constante locale hors 16 bits');
              End Else If Width=4 Then Begin
        Move(B^[Stub+4],Value,4);
                If (Value<-32768) Or (Value>65535) Then Begin
         If ProjectForeign Then Symbols[I].Kind:=skForeign
                           Else Unsupported('constante TPU Longint hors Integer');
        End;
        Width:=2;
        If Symbols[I].Kind<>skForeign Then Symbols[I].TypeId:=1;
       End Else If (Typ=ttInteger) And (Width=2) And (Value>32767) Then Dec(Value,65536);
       If (Typ=ttBoolean) And (Value>1) Then Fail(72,'Constante Boolean TPU invalide');
       If (Typ=ttChar) And (Value>255) Then Fail(72,'Constante Char TPU invalide');
              Symbols[I].Value:=Value;
              If (Typ=ttInteger) And (Value>32767) And (Value<=65535) Then Symbols[I].TypeId:=3;
      End;
     End Else
     Begin
      If Not IsLocal Then Unsupported('variable TPU Borland');
      DictBounds(Stub,9); Symbols[I].Kind:=skVar;
      DecodeType(Stub+5); Target:=ReadWord(Stub+1);
      If Typ=ttString Then J:=Word(Capacity)+1 Else J:=Width;
      If Longint(Target)+J>H.ConstSize Then Fail(72,'Variable TPU hors donnees');
      Symbols[I].Addr:=Units[U].DataBase+Target;
     End;
     Symbols[I].Typ:=Typ; Symbols[I].Width:=Width; Symbols[I].Capacity:=Capacity;
    End;
   End Else If Not (Kind In [89]) Then Begin
    If ProjectForeign Then Begin
     I:=NewSymbol(Name); Symbols[I].Kind:=skForeign
    End
    Else Unsupported('categorie de symbole TPU');
   End;
   A:=Next;
  End;
 End;
  If IsLocal And (H.Reserved[2]>=2) Then Begin
    MetaPos:=H.Reserved[5]; DictBounds(MetaPos,2); DiskCount:=ReadWord(MetaPos); Inc(MetaPos,2);
    If (DiskCount<7) Or (DiskCount>MaxTypes) Then Fail(72,'Table des types TPU invalide');
    If (H.Reserved[2]>=6) And (DiskCount<10) Then Fail(72,'Types standard TPU v6 manquants');
    DictBounds(MetaPos,Longint(DiskCount)*SizeOf(TTypeInfo));
    For K:=1 To DiskCount Do Begin
      Move(B^[MetaPos],DiskTypes[K],SizeOf(TTypeInfo)); Inc(MetaPos,SizeOf(TTypeInfo));
      If (DiskTypes[K].Base=0) Or (DiskTypes[K].Base>DiskCount) Or
        (DiskTypes[K].IdentityUnit[0]>Chr(63)) Or (DiskTypes[K].IdentityName[0]>Chr(63)) Or
        Not (DiskTypes[K].Typ In [ttInteger,ttBoolean,ttChar,ttString,ttEnum,ttPointer,ttArray,ttRecord,ttSet,ttFile,ttText,ttReal]) Or
        (DiskTypes[K].LowBound>DiskTypes[K].HighBound) Then Fail(72,'Descripteur de type TPU invalide');
      If DiskTypes[K].Typ=ttString Then Begin
        If (DiskTypes[K].Width<>0) Or (DiskTypes[K].Capacity=0) Then Fail(72,'Taille string de metadonnees TPU');
      End Else If DiskTypes[K].Typ In [ttArray,ttRecord,ttSet,ttFile,ttText] Then Begin
       If (H.Reserved[2]<6) Or (DiskTypes[K].Width<>0) Then Fail(72,'Type structure TPU invalide');
      End Else If DiskTypes[K].Typ=ttReal Then Begin
       If DiskTypes[K].Width<>6 Then Fail(72,'Taille Real TPU invalide');
      End Else If DiskTypes[K].Typ=ttPointer Then Begin
       If (H.Reserved[2]<6) Or (DiskTypes[K].Width<>4) Then Fail(72,'Type pointeur TPU invalide');
      End Else If Not (DiskTypes[K].Width In [1,2,4]) Or
        ((DiskTypes[K].Width=4) And (DiskTypes[K].Typ<>ttInteger)) Or
        ((DiskTypes[K].Width<>4) And ((DiskTypes[K].LowBound<-32768) Or (DiskTypes[K].HighBound>65535))) Then
          Fail(72,'Taille ou bornes ordinales de metadonnees TPU');
      If (K<=7) Or ((H.Reserved[2]>=6) And (K<=10)) Or ((K=11) And (DiskTypes[K].Typ=ttReal)) Then
        If (DiskTypes[K].Typ<>Types[K].Typ) Or (DiskTypes[K].Width<>Types[K].Width) Or
          (DiskTypes[K].Capacity<>Types[K].Capacity) Or (DiskTypes[K].Base<>Types[K].Base) Or
          (DiskTypes[K].LowBound<>Types[K].LowBound) Or (DiskTypes[K].HighBound<>Types[K].HighBound) Or
          (DiskTypes[K].Signed<>Types[K].Signed) Then Fail(72,'Types standard TPU incompatibles');
      If (K<=7) Or ((H.Reserved[2]>=6) And (K<=10)) Or ((K=11) And (DiskTypes[K].Typ=ttReal)) Then TypeMap[K]:=K
      Else Begin
        NewIndex:=0;
        If DiskTypes[K].Typ In [ttEnum,ttArray,ttRecord,ttPointer] Then
          For TIndex:=8 To TypeCount Do
            If (Types[TIndex].Typ=DiskTypes[K].Typ) And (Types[TIndex].Base=TIndex) And
              (Types[TIndex].IdentityUnit=DiskTypes[K].IdentityUnit) And
              (Types[TIndex].IdentityName=DiskTypes[K].IdentityName) And
              (Types[TIndex].IdentityName<>'') Then NewIndex:=TIndex;
        If NewIndex=0 Then Begin
          NewIndex:=NewType(DiskTypes[K].Typ,DiskTypes[K].Width,DiskTypes[K].Capacity,
            DiskTypes[K].Signed,DiskTypes[K].LowBound,DiskTypes[K].HighBound,0);
          Types[NewIndex].IdentityUnit:=DiskTypes[K].IdentityUnit;
          Types[NewIndex].IdentityName:=DiskTypes[K].IdentityName;
        End;
        TypeMap[K]:=NewIndex;
      End;
    End;
    For K:=1 To DiskCount Do Begin
      TIndex:=DiskTypes[K].Base;
      If (DiskTypes[TIndex].Base<>TIndex) Or (DiskTypes[TIndex].Typ<>DiskTypes[K].Typ) Then
        Fail(72,'Graphe des types TPU incoherent');
    End;
    For K:=8 To DiskCount Do Types[TypeMap[K]].Base:=TypeMap[DiskTypes[K].Base];
    If H.Reserved[2]>=6 Then Begin
     For K:=1 To DiskCount Do Begin
      NewIndex:=TypeMap[K]; DictBounds(MetaPos,8);
      TypeExtras[NewIndex].Size:=ReadWord(MetaPos);
      TIndex:=ReadWord(MetaPos+2); FieldType:=ReadWord(MetaPos+4); FieldN:=ReadWord(MetaPos+6);
      Inc(MetaPos,8);
      If (TIndex>DiskCount) Or (FieldType>DiskCount) Or (FieldN>MaxFields-FieldCount) Then
       Fail(72,'Liens de type structure TPU invalides');
      If TIndex<>0 Then TypeExtras[NewIndex].ElementType:=TypeMap[TIndex];
      If FieldType<>0 Then TypeExtras[NewIndex].IndexType:=TypeMap[FieldType];
      TypeExtras[NewIndex].FirstField:=0; TypeExtras[NewIndex].FieldCount:=FieldN;
      For FieldIndex:=1 To FieldN Do Begin
       DictBounds(MetaPos,1); Name:=ReadString(MetaPos);
       If (Length(Name)=0) Or (Length(Name)>63) Then Fail(72,'Nom de champ TPU invalide');
       DictBounds(MetaPos,Length(Name)+5); Inc(MetaPos,Length(Name)+1);
       FieldType:=ReadWord(MetaPos); FieldOffset:=ReadWord(MetaPos+2); Inc(MetaPos,4);
       If (FieldType=0) Or (FieldType>DiskCount) Or (FieldOffset>TypeExtras[NewIndex].Size) Then
        Fail(72,'Champ TPU hors type');
       Inc(FieldCount); Fields[FieldCount].Name:=Upper(Name);
       Fields[FieldCount].TypeId:=TypeMap[FieldType]; Fields[FieldCount].Offset:=FieldOffset;
       Fields[FieldCount].Next:=TypeExtras[NewIndex].FirstField;
       TypeExtras[NewIndex].FirstField:=FieldCount;
      End;
     End;
     For K:=1 To DiskCount Do Begin
      NewIndex:=TypeMap[K]; TIndex:=TypeExtras[NewIndex].ElementType;
      If Types[NewIndex].Typ=ttArray Then Begin
       FieldType:=TypeExtras[NewIndex].IndexType;
       If (TIndex=0) Or (FieldType=0) Then Fail(72,'Tableau TPU sans index/element');
       If Not (Types[FieldType].Typ In [ttInteger,ttChar,ttBoolean,ttEnum]) Or
          ((Types[FieldType].HighBound-Types[FieldType].LowBound+1)*Longint(TypeExtras[TIndex].Size)<>
            TypeExtras[NewIndex].Size) Then Fail(72,'Taille tableau TPU incoherente');
      End Else If Types[NewIndex].Typ=ttRecord Then Begin
       FieldType:=TypeExtras[NewIndex].FirstField;
       While FieldType<>0 Do Begin
        If Longint(Fields[FieldType].Offset)+TypeExtras[Fields[FieldType].TypeId].Size>TypeExtras[NewIndex].Size Then
         Fail(72,'Champ TPU hors record'); FieldType:=Fields[FieldType].Next;
       End;
      End Else If Types[NewIndex].Typ=ttPointer Then Begin
       If TypeExtras[NewIndex].Size<>4 Then Fail(72,'Taille pointeur TPU invalide');
      End;
     End;
    End;
    DictBounds(MetaPos,2); MetaCount:=ReadWord(MetaPos); Inc(MetaPos,2);
    If MetaCount>MaxSymbols Then Fail(72,'Trop de metadonnees de symboles');
    DictBounds(MetaPos,Longint(MetaCount)*4);
    For K:=1 To MetaCount Do Begin
      A:=ReadWord(MetaPos); TIndex:=ReadWord(MetaPos+2); Inc(MetaPos,4);
      W:=SymbolStub(A);
      If (TIndex=0) Or (TIndex>DiskCount) Then Fail(72,'Identite de type TPU invalide');
      Name:=Upper(ReadString(A+3)); I:=FindOwnSymbol(Name);
      If I=0 Then Fail(72,'Metadonnees de symbole TPU inconnues');
      ApplyType(I,TypeMap[TIndex]);
    End;
    If H.Reserved[2]>=3 Then Begin
     DictBounds(MetaPos,2); MetaCount:=ReadWord(MetaPos); Inc(MetaPos,2);
     If MetaCount>MaxSymbols Then Fail(72,'Trop de signatures TPU');
     For K:=1 To MetaCount Do Begin
      DictBounds(MetaPos,8); A:=ReadWord(MetaPos); W:=SymbolStub(A);
      Name:=Upper(ReadString(A+3)); I:=FindOwnSymbol(Name);
      If (I=0) Or (Symbols[I].Kind<>skProc) Then Fail(72,'Signature TPU hors procedure');
      ParamN:=ReadWord(MetaPos+2);
      If ParamN>MaxNativeParams Then Fail(72,'Signature TPU trop longue');
      Symbols[I].ParamCount:=ParamN; Symbols[I].ParamBytes:=ReadWord(MetaPos+4);
      If ReadWord(MetaPos+6)>1 Then Fail(72,'Distance de routine TPU invalide');
      Symbols[I].FarRoutine:=ReadWord(MetaPos+6)=1; Inc(MetaPos,8);
      DictBounds(MetaPos,Longint(ParamN)*4); MapSum:=0;
      For J:=1 To ParamN Do Begin
       TIndex:=ReadWord(MetaPos); W:=ReadWord(MetaPos+2); Inc(MetaPos,4);
       If (TIndex>DiskCount) Or Not (W In [2,6,7]) Or
          ((TIndex=0) And ((W<>6) Or (H.Reserved[2]<6))) Then Fail(72,'Parametre TPU invalide');
       If TIndex<>0 Then TIndex:=TypeMap[TIndex];
       If Not (Types[TIndex].Typ In [ttInteger,ttBoolean,ttChar,ttEnum,ttPointer,ttArray,ttRecord,ttString,ttSet,ttFile,ttText,ttReal]) Or
          ((Types[TIndex].Typ In [ttFile,ttText]) And (W<>6)) Then
         If TIndex<>0 Then Fail(72,'Type parametre TPU');
       Symbols[I].ParamTypeIds[J]:=TIndex; Symbols[I].ParamFlags[J]:=W;
       Symbols[I].ParamTypes[J]:=Types[TIndex].Typ; Symbols[I].ParamWidths[J]:=Types[TIndex].Width;
       If W=6 Then Inc(MapSum,4) Else If W=7 Then Inc(MapSum,6)
       Else Begin
        FieldOffset:=(TypeExtras[TIndex].Size+1) And $FFFE; If FieldOffset<2 Then FieldOffset:=2;
        Inc(MapSum,FieldOffset);
       End;
      End;
      If MapSum<>Symbols[I].ParamBytes Then Fail(72,'Taille parametres TPU incoherente');
     End;
    End;
  End;
  If IsLocal And (H.Reserved[2]>=7) Then Begin
   MetaPos:=H.DebugHash; If MetaPos<TPUHeaderSize Then Fail(72,'Offset debug TPU invalide');
   DictBounds(MetaPos,2); MetaCount:=ReadWord(MetaPos); Inc(MetaPos,2);
   If MetaCount>MaxDebugEntries-DebugCount Then Fail(72,'Trop d''entrees debug TPU');
   DebugSymbolPresent:=False; LoadCompiledUnitLastFile:='';
   For K:=1 To MetaCount Do Begin
    DictBounds(MetaPos,10); W:=B^[MetaPos]; Inc(MetaPos);
    If W>3 Then Fail(72,'Kind debug TPU invalide');
    If W<>0 Then DebugSymbolPresent:=True;
    A:=ReadWord(MetaPos); Inc(MetaPos,2);
    If (W In [0,1]) And (A>=H.CodeSize) Then Fail(72,'Adresse code debug TPU invalide');
    If (W=2) And (Longint(A)+ReadWord(MetaPos+4)>Longint(H.ConstSize)+H.DataSize) Then Fail(72,'Adresse data debug TPU invalide');
    Inc(DebugCount); DebugEntries[DebugCount].U:=U;
    With DebugEntries[DebugCount] Do Begin
     Kind:=W;
     If W In [0,1] Then Address:=GlobalOffset(A,DebugEntries[DebugCount].U,True)
     Else If W=2 Then Address:=GlobalOffset(A,DebugEntries[DebugCount].U,False) Else Address:=A;
     Line:=ReadWord(MetaPos); Column:=ReadWord(MetaPos+2); Size:=ReadWord(MetaPos+4); Inc(MetaPos,6);
     DictBounds(MetaPos,1); DictBounds(MetaPos,1+B^[MetaPos]); FileName:=ReadString(MetaPos); Inc(MetaPos,1+Length(FileName));
     If FileName='' Then FileName:=LoadCompiledUnitLastFile Else LoadCompiledUnitLastFile:=FileName;
     DictBounds(MetaPos,1); DictBounds(MetaPos,1+B^[MetaPos]); Name:=ReadString(MetaPos); Inc(MetaPos,1+Length(Name));
    End;
   End;
   If DebugSymbolPresent Then DebugCaptured:=DebugCaptured+[U]; If MetaCount<>0 Then DebugRequested:=True;
   If ((H.Reserved[2]=7) And (H.CodeLength And Not 7<>0)) Or
      (H.CodeLength And Not 31<>0) Then Fail(72,'Features TPU invalides');
   UnitFeatures[U]:=H.CodeLength;
  End;
  Units[U].InterfaceReady:=True;
  If IsLocal And (InterfaceChecksumMode(U,H.Reserved[2]>=2,H.Reserved[2]>=3,H.Reserved[2]>=6)<>Units[U].Checksum) Then Begin
    { L'ordre des buckets differe de l'ordre des declarations: le checksum
      est verifie par la representation canonique triee ci-dessous. }
  Fail(72,'Checksum d''interface TPU invalide');
 End;
 RefCount:=0; X:=H.Units;
 While X<H.Sources Do Begin
  If RefCount>MaxUnits+1 Then Fail(72,'Trop de references TPU');
  Bounds(X,3); Name:=Upper(ReadString(X+2));
  If (Length(Name)=0) Or (Length(Name)>63) Or (X+3+Length(Name)>H.Sources) Then      Fail(
  72,'Liste de dependances TPU invalide');
  RefOffsets[RefCount]:=X-H.Units;
  RefChecks[RefCount]:=CheckForUnit(Name);
  If Name=Units[U].Name Then RefUnits[RefCount]:=U Else
  If Name='SYSTEM' Then RefUnits[RefCount]:=0
   Else
  Begin
   RequireUnit(Name,V); RefUnits[RefCount]:=V;
   Units[U].Dependencies:=Units[U].Dependencies+[V];
   Units[U].DependencyChecks[V]:=RefChecks[RefCount];
   If Not Units[V].FromSource And (RefChecks[RefCount]<>0) And
   (RefChecks[RefCount]<>Units[V].Checksum) Then Fail(70,Name);
  End;
  Inc(RefCount); Inc(X,3+Length(Name));
 End;
 If IsLocal Then Begin
  For I:=1 To H.CodeFixupSize Div 8 Do Begin
   X:=RelStart+(Longint(I)-1)*8; Bounds(X,8);
   R:=ReadWord(X); Map:=ReadWord(X+2); Target:=ReadWord(X+4); A:=ReadWord(X+6);
   If Longint(A)+2>H.CodeSize Then Fail(72,'Fixup TPU hors code');
   J:=0;
   While (J<RefCount) And (RefOffsets[J]<>(R And $0FFF)) Do Inc(J);
   If J=RefCount Then Fail(72,'Reference d''unite TPU invalide');
   V:=RefUnits[J]; A:=A+Units[U].CodeBase;
   If R And $F000=$8000 Then Begin
    If (V=0) And (Map=$FFFF) And (H.Reserved[2]>=6) Then Target:=RuntimeDataAddress(Target)
    Else Begin
     If (V=0) Or (Map<>0) Then Fail(72,'Fixup de donnees TPU invalide');
     Target:=GlobalOffset(Target,V,False);
    End;
    If (Target>=DataSize) Or (DataOwners[Target]<>V) Then Fail(72,
    'Cible de donnees TPU invalide');
    If FixupCount=MaxFixups Then Unsupported('trop de fixups TPU');
    Inc(FixupCount); Fixups[FixupCount].Position:=A;
    Fixups[FixupCount].DataOffset:=Target; PatchWord(A,0);
   End Else If R And $F000=$4000 Then Begin
    If (V=0) And (Map=$FFFF) Then Target:=RuntimeAddress(Target)
     Else
    Begin
     If (V=0) Or (Map<>0) Then Fail(72,'Fixup de code TPU invalide');
     Target:=GlobalOffset(Target,V,True);
     If Target>CodeSize Then Fail(72,'Cible de code TPU invalide');
    End;
    PatchJump(A,Target);
   End Else Fail(72,'Nature de fixup TPU inconnue');
  End;
 End;
 If IsLocal And (H.Reserved[2]>=4) Then Begin
  X:=H.Reserved[6]; DictBounds(X,2); MetaCount:=ReadWord(X); Inc(X,2);
  If MetaCount>MaxUnits Then Fail(72,'Trop de dependances natives TPU');
  For K:=1 To MetaCount Do Begin
   DictBounds(X,1); Name:=Upper(ReadString(X));
   If (Length(Name)=0) Or (Length(Name)>63) Then Fail(72,'Nom de dependance native TPU invalide');
   DictBounds(X,Length(Name)+3); Inc(X,Length(Name)+1); W:=ReadWord(X); Inc(X,2);
   RequireUnit(Name,V);
   If NativeBuffers[V]=Nil Then Fail(72,'Dependance native TPU non Borland');
   If W<>Units[V].Checksum Then Fail(70,Name);
   Units[U].NativeDependencies:=Units[U].NativeDependencies+[V];
   NativeNeeded:=True; ActivateNative(V);
  End;
  DictBounds(X,2); MetaCount:=ReadWord(X); Inc(X,2);
  If MetaCount>MaxNativeRefs-NativeRefCount Then Fail(72,'Trop de references natives TPU');
  For K:=1 To MetaCount Do Begin
   DictBounds(X,3); A:=ReadWord(X); Inc(X,2); Name:=Upper(ReadString(X));
   If (Length(Name)=0) Or (Length(Name)>63) Then Fail(72,'Nom de cible native TPU invalide');
   DictBounds(X,Length(Name)+9); Inc(X,Length(Name)+1);
   W:=ReadWord(X); R:=ReadWord(X+2); Map:=ReadWord(X+4); Target:=ReadWord(X+6); Inc(X,8);
   If (Longint(A)+2>H.CodeSize) Or Not (R In [1,2,3]) Then Fail(72,'Reference native TPU invalide');
   RequireUnit(Name,V);
   If (NativeBuffers[V]=Nil) Or Not (V In Units[U].NativeDependencies) Then
    Fail(72,'Cible native TPU non declaree');
   If W<>Units[V].Checksum Then Fail(70,Name);
   Inc(NativeRefCount); NativeRefs[NativeRefCount].Position:=Units[U].CodeBase+A;
   NativeRefs[NativeRefCount].U:=V; NativeRefs[NativeRefCount].Kind:=R;
   NativeRefs[NativeRefCount].Map:=Map; NativeRefs[NativeRefCount].Target:=Target;
   PatchWord(Units[U].CodeBase+A,0);
  End;
  DictBounds(X,2); MetaCount:=ReadWord(X); Inc(X,2);
  If MetaCount>MaxNativeRefs-RelocationCount Then Fail(72,'Trop de relocalisations natives TPU');
  DictBounds(X,Longint(MetaCount)*4);
  For K:=1 To MetaCount Do Begin
   A:=ReadWord(X); W:=ReadWord(X+2); Inc(X,4);
   If (Longint(A)+2>H.CodeSize) Or (W>3) Then Fail(72,'Relocalisation native TPU invalide');
   AddSegmentRelocation(Units[U].CodeBase+A,W); PatchWord(Units[U].CodeBase+A,0);
  End;
 End;
 If IsLocal And (H.Reserved[2]>=5) Then Begin
  X:=H.Reserved[7]; DictBounds(X,2); MetaCount:=ReadWord(X); Inc(X,2);
  If MetaCount>MaxSymbols-ObjectCallCount Then Fail(72,'Trop de references OBJ TPU');
  For K:=1 To MetaCount Do Begin
   DictBounds(X,3); A:=ReadWord(X); Inc(X,2); Name:=ReadString(X);
   If (Length(Name)=0) Or (Length(Name)>63) Or (Longint(A)+4>H.CodeSize) Then
    Fail(72,'Reference OBJ TPU invalide');
   DictBounds(X,Length(Name)+1); Inc(X,Length(Name)+1);
   Inc(ObjectCallCount); ObjectCalls[ObjectCallCount].Name:=Upper(Name);
   ObjectCalls[ObjectCallCount].Position:=Units[U].CodeBase+A;
  End;
  X:=Align16(H.EndTrace)+Align16(H.CodeSize)+Align16(H.ConstSize)+Align16(H.CodeFixupSize);
  Bounds(X,2); MetaCount:=ReadWord(X); Inc(X,2);
  If MetaCount>MaxObjects-ObjectCount Then Fail(72,'Trop de fichiers OBJ TPU');
  For K:=1 To MetaCount Do Begin
   Bounds(X,5); Value:=ReadWord(X)+Longint(ReadWord(X+2))*65536; Inc(X,4);
   If (Value<4) Or (Value>SizeOf(TBinaryBuffer)) Then Fail(72,'Taille OBJ TPU invalide');
   Name:=ReadString(X); Bounds(X,Length(Name)+1); Inc(X,Length(Name)+1);
   Bounds(X,Value); Inc(ObjectCount); ObjectFiles[ObjectCount].Owner:=U;
   ObjectFiles[ObjectCount].Path:=Name; ObjectFiles[ObjectCount].Length:=Value;
   New(ObjectFiles[ObjectCount].Bytes);
   Move(B^[X],ObjectFiles[ObjectCount].Bytes^,Value); Inc(X,Value);
  End;
  If (Align16(X)<>Size) Or (UnitFileSize(H)<>Size) Then Fail(72,'Payload OBJ TPU incoherent');
 End;
 Units[U].State:=2;
 If Units[U].HasInit Then Begin
  Inc(InitCount); InitOrder[InitCount]:=U
 End;
 If IsLocal Then Dispose(B);
 RestoreParser(P);
End;

Procedure ImportLibrarySystem;
Var
 U: Byte;
Begin
 If FindLibraryUnit('SYSTEM')=0 Then Exit;
 If (CurrentUnit<>0) And (Units[CurrentUnit].Name='SYSTEM') Then Exit;
 RequireUnit('SYSTEM',U); AddImport(U);
End;

Function NativeWord(U: Byte; P: Longint): Word;Begin
 If (NativeBuffers[U]=Nil) Or (P<0) Or (P+2>UnitFileSize(NativeHeaders[U])) Then    Fail(
 72,'Reference native hors unite');
 NativeWord:=NativeBuffers[U]^[P]+Word(NativeBuffers[U]^[P+1])*256;
End;

Function DecodeNativeType(U: Byte; Offset: Word): Word;
Var B: PBinaryBuffer; H: TUnitHeader; T,I,BaseId: Word; Typ,Width,Capacity,Modifier: Byte;
  L,R: Longint; Signed: Boolean; S: TShortString;
Begin
 DecodeNativeType:=0;
 If NativeBuffers[U]=Nil Then Unsupported('type provenant d''une unite non native');
 H:=NativeHeaders[U]; B:=NativeBuffers[U];
 If (Offset<TPUHeaderSize) Or (Longint(Offset)+6>H.ProcMap) Then Fail(72,'Descripteur Borland hors dictionnaire');
 For I:=8 To TypeCount Do
  If (NativeTypeOwners[I]=U) And (NativeTypeOffsets[I]=Offset) Then Begin DecodeNativeType:=I; Exit End;
 Typ:=B^[Offset]; Modifier:=B^[Offset+1]; T:=NativeWord(U,Offset+2);
 Signed:=(Modifier And 1)<>0; Capacity:=0;
 If Typ=ttString Then Begin
  If (T<2) Or (T>256) Then Fail(72,'Taille string Borland invalide');
  If T=256 Then Begin DecodeNativeType:=7; Exit End;
  Width:=0; Capacity:=T-1; L:=0; R:=Capacity; BaseId:=7;
 End Else If Typ In [ttInteger,ttBoolean,ttChar,ttEnum] Then Begin
  If Not (T In [1,2,4]) Then Fail(72,'Taille ordinale Borland invalide');
  If (Typ<>ttInteger) And (T>2) Then Fail(72,'Taille ordinale Borland non entiere');
  If Longint(Offset)+18>H.ProcMap Then Fail(72,'Bornes ordinales Borland tronquees');
  Width:=T; Move(B^[Offset+6],L,4); Move(B^[Offset+10],R,4);
  If L>R Then Fail(72,'Bornes ordinales Borland inversees');
  If (T=1) And ((L<-128) Or (R>255)) Then Fail(72,'Bornes Borland hors octet');
  If (T=2) And ((L<-32768) Or (R>65535)) Then Fail(72,'Bornes Borland hors mot');
  Case Typ Of
   ttBoolean:Begin
    If (T<>1) Or (L<0) Or (R>1) Then Fail(72,'Descripteur Boolean Borland invalide');
    If (L=0) And (R=1) Then Begin DecodeNativeType:=5; Exit End;
    BaseId:=5;
   End;
   ttChar:Begin
  If (T<>1) Or (L<0) Or (R>255) Then Fail(72,'Descripteur Char Borland invalide');
  If (L=0) And (R=255) Then Begin DecodeNativeType:=6; Exit End;
  BaseId:=6;
   End;
   ttInteger:Begin
  BaseId:=1;
  If (T=1) And (L=0) And (R=255) And Not Signed Then Begin DecodeNativeType:=2; Exit End;
  If (T=1) And (L=-128) And (R=127) And Signed Then Begin DecodeNativeType:=4; Exit End;
  If (T=2) And (L=-32768) And (R=32767) And Signed Then Begin DecodeNativeType:=1; Exit End;
  If (T=2) And (L=0) And (R=65535) And Not Signed Then Begin DecodeNativeType:=3; Exit End;
   End;
   ttEnum:BaseId:=0;
  End;
 End Else Exit; { structure valide mais backend pas encore disponible }
 I:=NewType(Typ,Width,Capacity,Signed,L,R,BaseId);
 NativeTypeOwners[I]:=U; NativeTypeOffsets[I]:=Offset;
 If Typ=ttEnum Then Begin
  Types[I].IdentityUnit:=Units[U].Name; Str(Offset,S); Types[I].IdentityName:='$TPU'+S;
 End;
 DecodeNativeType:=I;
End;

Procedure ActivateNative(U: Byte);
Var
 H: TUnitHeader;
 P: Word;
 S: TShortString;
 I: Integer;
 V: Byte;
Begin
 If NativeActive[U] Then Exit;
 If NativeBuffers[U]=Nil Then Unsupported('dependance native non Borland: '+Units[U].Name)
 ;
 H:=NativeHeaders[U];
 If Units[U].Name='OVERLAY' Then Unsupported('gestion des overlays Borland');
 If H.Flags And 1<>0 Then Unsupported('ABI native 8087');
 NativeActive[U]:=True; P:=H.Units;
 While P<H.Sources Do Begin
  S:='';
  For I:=1 To NativeBuffers[U]^[P+2] Do S:=S+Chr(NativeBuffers[U]^[P+2+I]);
  S:=Upper(S);
  If S<>Units[U].Name Then Begin
   V:=FindBuildUnit(S);
   If V=0 Then RequireUnit(S,V);
   ActivateNative(V);
  End;
  Inc(P,3+Length(S));
 End;
 Inc(NativeInitCount); NativeInitOrder[NativeInitCount]:=U;
End;

Function NativeMapAddress(U, Category: Byte; Map: Word): Word;
Var
 H: TUnitHeader;
 First, Last, P: Word;
 A: Longint;
Begin
 H:=NativeHeaders[U];
 Case Category Of
 0:
 Begin
  First:=H.CodeMap; Last:=H.ConstMap; A:=NativeCodeBases[U]
 End;
 1:
 Begin
  First:=H.DataMap; Last:=H.EndMaps; A:=NativeVarBases[U]
 End;
 2:
 Begin
  First:=H.ConstMap; Last:=H.DataMap; A:=NativeConstBases[U]
 End;
  Else
 Begin
  Fail(72,'Categorie de carte native'); First:=0; Last:=0; A:=0
 End;
End;
If (Map Mod 8<>0) Or (Longint(First)+Map+8>Last) Then Fail(72,
'Index carte native hors unite');
P:=First;
While P<First+Map Do Begin
 Inc(A,NativeWord(U,P+2)); Inc(P,8)
End;
If A>65535 Then Fail(49,'Adresse native trop grande');
NativeMapAddress:=A;
End;

Function NativeProcAddress(U: Byte; Map: Word): Word;
Var
 H: TUnitHeader;
 P, CodeMap, Entry: Word;
Begin
 H:=NativeHeaders[U];
 If (Map Mod 8<>0) Or (Longint(H.ProcMap)+Map+8>H.CodeMap) Then Fail(72,
 'Index procedure native');
 P:=H.ProcMap+Map; CodeMap:=NativeWord(U,P+4); Entry:=NativeWord(U,P+6);
 If CodeMap=$FFFF Then Fail(59,'Procedure native non resolue');
 If Entry>=NativeWord(U,H.CodeMap+CodeMap+2) Then Fail(72,
 'Entree procedure native hors segment');
 NativeProcAddress:=NativeMapAddress(U,0,CodeMap)+Entry;
End;

Procedure NativeDataRelocation(P: Word; Kind: Byte);Begin
 If RelocationCount=MaxNativeRefs Then Unsupported('trop de relocalisations MZ');
 Inc(RelocationCount); Relocations[RelocationCount].Offs:=P;
 Relocations[RelocationCount].Segm:=$FFFF; RelocationKinds[RelocationCount]:=Kind;
End;

Function NativeMapLength(U, Category: Byte; Map: Word): Word;
Var P: Word;
Begin
 P:=NativeMapAddress(U,Category,Map);
 Case Category Of
  0:P:=NativeHeaders[U].CodeMap;
  1:P:=NativeHeaders[U].DataMap;
  2:P:=NativeHeaders[U].ConstMap;
 End;
 NativeMapLength:=NativeWord(U,Longint(P)+Map+2);
End;

Procedure LinkNative;
Var
 U, Sys: Byte;
 I, P, Offset, Value: Word;
 H: TUnitHeader;
 X, CodeStart, ConstStart: Longint;

Function RefUnit(U: Byte; Ref: Word): Byte;
Var
 P: Longint;
 S: TShortString;
 K: Integer;
 V: Byte;
Begin
 P:=NativeHeaders[U].Units; S:='';
    { Ref est un offset dans la liste, pas un numero ordinal. }
 While P<NativeHeaders[U].Sources Do Begin
  If P=NativeHeaders[U].Units+Ref Then Begin
   For K:=1 To NativeBuffers[U]^[P+2] Do S:=S+Chr(NativeBuffers[U]^[P+2+K]);
   V:=FindBuildUnit(Upper(S));
   If V=0 Then Fail(72,'Dependance native non resolue');
   RefUnit:=V;
   Exit;
  End;
  Inc(P,3+NativeBuffers[U]^[P+2]);
 End;
 Fail(72,'Offset reference d''unite native invalide'); RefUnit:=0;
End;

Procedure WriteAt(P: Word; W: Word; InConst: Boolean);Begin
 If InConst Then Begin
  If Longint(P)+2>NativeDataSize Then Fail(72,'Fixup natif hors donnees');
  NativeData[P]:=W And 255; NativeData[P+1]:=W Shr 8;
 End Else
 Begin
  If Longint(P)+2>CodeSize Then Fail(72,'Fixup natif hors code');
  PatchWord(P,W);
 End;
End;

Procedure ResolveMaps(U: Byte; InConst: Boolean);
Var
 H: TUnitHeader;
 M, EndMap, Raw, FixRaw, Posn, Source, L, FS, N: Word;
 R, TM, T, At, W, SG: Word;
 Q: Longint;
 V: Byte;
Begin
 H:=NativeHeaders[U]; Raw:=0; FixRaw:=0;
 If InConst Then Begin
  M:=H.ConstMap; EndMap:=H.DataMap;
  Q:=Align16(H.EndTrace)+Align16(H.CodeSize)+Align16(H.ConstSize)+Align16(H.CodeFixupSize)
  ;
 End Else
 Begin
  M:=H.CodeMap; EndMap:=H.ConstMap;
  Q:=Align16(H.EndTrace)+Align16(H.CodeSize)+Align16(H.ConstSize);
 End;
 While M<EndMap Do Begin
  L:=NativeWord(U,M+2); FS:=NativeWord(U,M+4);
  If FS Mod 8<>0 Then Fail(72,'Taille fixups natifs invalide');
  If InConst Then Source:=NativeConstBases[U]+Raw Else Source:=NativeCodeBases[U]+Raw;
  For N:=1 To FS Div 8 Do Begin
   Posn:=FixRaw+(N-1)*8;
   R:=NativeWord(U,Q+Posn); TM:=NativeWord(U,Q+Posn+2);
   T:=NativeWord(U,Q+Posn+4); At:=NativeWord(U,Q+Posn+6);
   W:=2; If R And $3000=$3000 Then W:=4;
   If Longint(At)+W>L Then Fail(72,'Position de fixup hors carte native');
   V:=RefUnit(U,R And $FFF); SG:=0;
   If R And $8000<>0 Then Begin
    SG:=1;
    If R And $4000<>0 Then Begin
     If (R And $1000<>0) And (T>=NativeMapLength(V,2,TM)) Then Fail(72,'Cible constante hors carte native');
     W:=NativeMapAddress(V,2,TM)+T;
    End Else Begin
     If (R And $1000<>0) And (T>=NativeMapLength(V,1,TM)) Then Fail(72,'Cible donnee hors carte native');
     W:=NativeMapAddress(V,1,TM)+T;
    End;
    End Else If R And $4000<>0 Then Begin
    If (R And $1000<>0) And (T>NativeMapLength(V,0,TM)) Then Fail(72,'Cible code hors carte native');
    W:=NativeMapAddress(V,0,TM)+T;
    End Else W:=NativeProcAddress(V,TM)+T;
    At:=At+Source;
    If R And $1000<>0 Then Begin
     WriteAt(At,W,InConst); Inc(At,2);
    End Else If R And $2000=0 Then Begin
     WriteAt(At,Word(Longint(W)-At-2),InConst);
   End;
   If R And $2000<>0 Then Begin
    WriteAt(At,0,InConst);
    If InConst Then NativeDataRelocation(At,SG) Else AddSegmentRelocation(At,SG);
   End;
  End;
  Inc(Raw,L); Inc(FixRaw,FS); Inc(M,8);
 End;
End;

Procedure FarCallTo(Address: Word);Begin
 Emit($9A); EmitWord(Address); AddSegmentRelocation(CodeSize,0); EmitWord(0)
End;
Begin
 If Not NativeNeeded Then Exit;
 NativeDataSize:=2; FillChar(NativeData,SizeOf(NativeData),0);
 For U:=1 To UnitCount Do If NativeActive[U] Then Begin
  H:=NativeHeaders[U]; NativeCodeBases[U]:=CodeSize;
  CodeStart:=Align16(H.EndTrace);
  If H.CodeSize<>0 Then
  For X:=0 To H.CodeSize-1 Do Emit(NativeBuffers[U]^[CodeStart+X]);
  NativeConstBases[U]:=NativeDataSize;
  If Longint(NativeDataSize)+H.ConstSize>MaxImage Then Fail(49,
  'Constantes natives trop grandes');
  ConstStart:=CodeStart+Align16(H.CodeSize);
  If H.ConstSize<>0 Then Move(NativeBuffers[U]^[ConstStart],NativeData[NativeDataSize],
  H.ConstSize);
  Inc(NativeDataSize,H.ConstSize);
 End;
 For U:=1 To UnitCount Do If NativeActive[U] Then Begin
  NativeVarBases[U]:=NativeDataSize;
  If Longint(NativeDataSize)+NativeHeaders[U].DataSize>MaxImage Then Fail(49,
  'Donnees natives trop grandes');
  Inc(NativeDataSize,NativeHeaders[U].DataSize);
 End;
 For U:=1 To UnitCount Do If NativeActive[U] Then Begin
  ResolveMaps(U,False); ResolveMaps(U,True)
 End;
 For I:=1 To NativeRefCount Do Begin
  U:=NativeRefs[I].U;
  If Not NativeActive[U] Then Fail(72,'Cible native non activee');
  If NativeRefs[I].Kind=3 Then Value:=NativeProcAddress(U,NativeRefs[I].Map)+
  NativeRefs[I].Target
  Else Begin
   If NativeRefs[I].Target>=NativeMapLength(U,NativeRefs[I].Kind,NativeRefs[I].Map) Then
    Fail(72,'Reference native hors carte de donnees');
   Value:=NativeMapAddress(U,NativeRefs[I].Kind,NativeRefs[I].Map)+NativeRefs[I].Target;
  End;
  PatchWord(NativeRefs[I].Position,Value);
 End;
 Sys:=FindBuildUnit('SYSTEM');
 P:=CodeSize; PatchJump(EntryFixup,P);
 Emit($1E); Emit($06); Emit($55);
 SetNativeDS; Emit2($8E,$C2);
 If (Sys<>0) And NativeActive[Sys] Then Begin
    { ES=PSP a l'entree de _InitTurbo; CS principal est le segment de charge. }
  Emit2($8E,$06); DataAddress(PrefixSeg);
  FarCallTo(NativeProcAddress(Sys,8));
 End;
 For I:=1 To NativeInitCount Do Begin
  U:=NativeInitOrder[I];
  If U<>Sys Then      If NativeWord(U,NativeHeaders[U].ProcMap+4)<>$FFFF Then FarCallTo(
  NativeProcAddress(U,0));
 End;
 Emit($5D); Emit($07); Emit($1F); JumpTo(MainEntry);
 If (Sys<>0) And NativeActive[Sys] Then Begin
    { _HaltTurbo restitue les vecteurs installees par _InitTurbo. }
  Offset:=RuntimeHalt;
  Image[Offset]:=$E8; PatchWord(Offset+1,Word(Longint(RuntimeStandard[56])-Offset-3)); Inc(Offset,3);
  Image[Offset]:=$BA; PatchWord(Offset+1,0); AddSegmentRelocation(Offset+1,1);
  Image[Offset+3]:=$8E; Image[Offset+4]:=$DA; Image[Offset+5]:=$9A;
  PatchWord(Offset+6,NativeProcAddress(Sys,24)); PatchWord(Offset+8,0);
  AddSegmentRelocation(Offset+8,0);
 End;
End;

Procedure UsesClause;
Var
 Name: TShortString;
 U: Byte;
Begin
 If Token<>tkUses Then Exit;
 NextToken;
 Repeat
 If Token<>tkIdent Then Fail(2,'Nom d''unite attendu');
 Name:=TokenText; NextToken;
 If (Name<>'SYSTEM') Or (FindLibraryUnit('SYSTEM')<>0) Then Begin
  RequireUnit(Name,U);
  AddImport(U);
  If (NativeBuffers[U]<>Nil) And (Name<>'SYSTEM') Then        If (
  NativeHeaders[U].CodeMap-NativeHeaders[U].ProcMap>=8) And
  (NativeWord(U,NativeHeaders[U].ProcMap+4)<>$FFFF) Then Begin
          If CurrentUnit<>0 Then
           Units[CurrentUnit].NativeDependencies:=Units[CurrentUnit].NativeDependencies+[U];
   NativeNeeded:=True; ActivateNative(U);
  End;
 End;
 If Token<>tkComma Then Break;
 NextToken;
 Until False;
 Need(tkSemi);
End;

Procedure EmitTextRuntime;
Var P,Q,R,S,Done,LoopStart,ErrorClosed,ErrorMode: Word;
Begin
 RuntimeStandard[54]:=CodeSize; { buffer console initialise a la premiere utilisation }
 Emit($26); Emit2($83,$7D); Emit(100); Emit(0); Emit2($74,1); Emit($C3);
 Emit($50); Emit2($89,$F8); Emit($05); EmitWord(128); Emit($26); Emit2($89,$45); Emit(96);
 Emit2($8C,$C0); Emit($26); Emit2($89,$45); Emit(98);
 Emit($26); Emit2($C7,$45); Emit(100); EmitWord(1); Emit($58); Emit($C3);
 RuntimeStandard[49]:=CodeSize; { selection du Text de sortie DX:AX, nil=console }
 Emit2($87,$06); DataAddress(OutputFilePointer);
 Emit2($87,$16); DataAddress(OutputFilePointer+2); Emit($C3);

 RuntimeStandard[53]:=CodeSize; { remettre les compteurs Text a zero }
 Emit($26); Emit2($83,$7D); Emit(8); Emit(1); Emit2($74,1); Emit($C3);
 Emit($26); Emit2($C7,$45); Emit(102); EmitWord(0);
 Emit($26); Emit2($C7,$45); Emit(104); EmitWord(0);
 Emit($26); Emit2($C7,$45); Emit(106); EmitWord(0); Emit($C3);

 RuntimeStandard[51]:=CodeSize; { SetTextBuf ES:DI, DX:AX buffer, CX taille }
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); Emit2($74,3); P:=Jump;
 Emit2($09,$C9); Emit2($75,3); Q:=Jump;
 Emit($26); Emit2($89,$45); Emit(96); Emit($26); Emit2($89,$55); Emit(98);
 Emit($26); Emit2($89,$4D); Emit(100); CallTo(RuntimeStandard[53]);
 Emit($26); Emit2($C7,$45); Emit(6); EmitWord($FFFF); Emit($C3);
 PatchJump(P,CodeSize); LoadImmediate(102); P:=Jump;
 PatchJump(Q,CodeSize); LoadImmediate(106); PatchJump(P,CodeSize);
 Emit($A3); DataAddress(InputError); Emit($C3);

 RuntimeStandard[52]:=CodeSize; { Flush buffer ES:DI, rend AX=erreur }
 Emit($1E); Emit($53); Emit($51); Emit($52);
 Emit($26); Emit2($83,$7D); Emit(8); Emit(1); Emit2($74,3); P:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(2); Emit2($74,3); Q:=Jump;
 Emit($26); Emit2($8B,$4D); Emit(106); Emit2($09,$C9); Emit2($75,3); R:=Jump;
 Emit($26); Emit2($8B,$55); Emit(96); Emit($26); Emit2($8B,$45); Emit(98); Emit2($8E,$D8);
 { Unite Crt: la sortie standard (handle 1) passe par CrtWrite(Seg,Ofs,Count). }
 Emit($1E); EmitLoadDS;                                     { push ds(tampon); ds=donnees }
 Emit2($83,$3E); DataAddress(CrtHook); Emit(0); Emit2($75,3); ErrorClosed:=Jump;
 Emit($26); Emit2($83,$3D); Emit(1); Emit2($74,3); ErrorMode:=Jump;
 Emit($06); Emit($57); Emit($51);                            { push es,di,cx }
 Emit2($89,$E3); Emit($36); Emit2($FF,$77); Emit(6);         { push ss:[bx+6] = segment du tampon }
 Emit($52); Emit($51); Emit($53); Emit2($FF,$16); DataAddress(CrtHook); { push dx,cx,lien; call [hook] }
 Emit($59); Emit($5F); Emit($07); Emit($1F);                 { pop cx,di,es,ds }
 Emit2($89,$C8); Emit($F8); LoopStart:=Jump;                 { ax=cx; clc }
 PatchJump(ErrorClosed,CodeSize); PatchJump(ErrorMode,CodeSize); Emit($1F);
 Emit($26); Emit2($8B,$1D); Emit2($B4,$40); Emit2($CD,$21);
 PatchJump(LoopStart,CodeSize); Emit2($73,3); S:=Jump;
 Emit2($39,$C8); Emit2($74,3); Done:=Jump;
 Emit($26); Emit2($C7,$45); Emit(106); EmitWord(0);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(R,CodeSize); Emit2($31,$C0); P:=Jump;
 PatchJump(Done,CodeSize); LoadImmediate(101);
 PatchJump(P,CodeSize); PatchJump(S,CodeSize);
 Emit($5A); Emit($59); Emit($5B); Emit($1F); Emit($C3);

 RuntimeStandard[50]:=CodeSize; { RuntimeChar, buffer du Text actif }
 Emit($1E); EmitLoadDS; Emit2($83,$3E); DataAddress(InputError); Emit(0); Emit($1F); Emit2($74,1); Emit($C3);
 Emit($55); Emit2($89,$E5); Emit($50); Emit($06); Emit($57); Emit($1E);
 Emit($53); Emit($51); Emit($52); Emit($56);
 EmitLoadDS; Emit2($C4,$3E); DataAddress(OutputFilePointer);
 Emit2($8C,$C2); Emit2($89,$FB); Emit2($09,$D3); Emit2($75,3); P:=Jump;
 CallTo(RuntimeStandard[54]);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); Emit2($75,3); ErrorClosed:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(2); Emit2($74,3); ErrorMode:=Jump;
 Emit($26); Emit2($8B,$5D); Emit(106); Emit($26); Emit2($3B,$5D); Emit(100);
 Emit2($73,3); Q:=Jump; CallTo(RuntimeStandard[52]); Emit2($09,$C0); Emit2($74,3); R:=Jump;
 PatchJump(Q,CodeSize); Emit($26); Emit2($8B,$75); Emit(106);
 Emit($26); Emit2($8B,$5D); Emit(96); Emit($26); Emit2($8B,$55); Emit(98);
 Emit($06); Emit($57); Emit2($8E,$C2); Emit2($89,$DF); Emit2($01,$F7);
 Emit2($8B,$46); Emit($FE); Emit($26); Emit2($88,$05); Emit($5F); Emit($07);
 Emit($26); Emit2($FF,$45); Emit(106);
 Emit($26); Emit2($8B,$5D); Emit(106); Emit($26); Emit2($3B,$5D); Emit(100);
 Emit2($73,3); Q:=Jump; CallTo(RuntimeStandard[52]); S:=Jump;
 PatchJump(Q,CodeSize); Emit2($31,$C0); Q:=Jump;
 PatchJump(ErrorClosed,CodeSize); LoadImmediate(103); ErrorClosed:=Jump;
 PatchJump(ErrorMode,CodeSize); LoadImmediate(105);
 PatchJump(R,CodeSize); PatchJump(S,CodeSize); PatchJump(Q,CodeSize); PatchJump(ErrorClosed,CodeSize);
 Emit2($09,$C0); Emit2($75,3); Q:=Jump; Emit($A3); DataAddress(InputError);
 PatchJump(Q,CodeSize); Done:=Jump;
 PatchJump(P,CodeSize); Emit2($8B,$46); Emit($FE); CallTo(RuntimeRawChar);
 PatchJump(Done,CodeSize); Emit($5E); Emit($5A); Emit($59); Emit($5B); Emit($1F); Emit($5F); Emit($07); Emit($58); Emit($5D); Emit($C3);

 RuntimeStandard[48]:=CodeSize; { prochain octet du Text actif, 26=EOF }
 Emit($06); Emit($57); Emit($1E); Emit($53); Emit($51); Emit($52); Emit($56);
 EmitLoadDS; Emit2($C4,$3E); DataAddress(InputFilePointer);
 Emit2($8C,$C2); Emit2($89,$FB); Emit2($09,$D3); Emit2($75,3); P:=Jump;
 CallTo(RuntimeStandard[54]);
 Emit($26); Emit2($8B,$5D); Emit(102); Emit($26); Emit2($3B,$5D); Emit(104);
 Emit2($73,3); Q:=Jump;
 Emit($26); Emit2($8B,$4D); Emit(100); Emit($26); Emit2($8B,$55); Emit(96);
 Emit($26); Emit2($8B,$45); Emit(98); Emit2($8E,$D8); Emit($26); Emit2($8B,$1D);
 Emit2($B4,$3F); Emit2($CD,$21); Emit2($73,3); R:=Jump;
 Emit2($09,$C0); Emit2($75,3); S:=Jump;
 Emit($26); Emit2($89,$45); Emit(104); Emit($26); Emit2($C7,$45); Emit(102); EmitWord(0);
 PatchJump(Q,CodeSize); Emit($26); Emit2($8B,$75); Emit(96); Emit($26); Emit2($03,$75); Emit(102);
 Emit($26); Emit2($8B,$45); Emit(98); Emit2($8E,$D8); Emit($AC); Emit2($30,$E4);
 Emit($26); Emit2($FF,$45); Emit(102); Done:=Jump;
 PatchJump(P,CodeSize); Emit2($8B,$1E); DataAddress(InputHandle); Emit($B9); EmitWord(1);
 Emit($BA); DataAddress(InputByte); Emit2($B4,$3F); Emit2($CD,$21); Emit2($73,3); P:=Jump;
 Emit2($09,$C0); Emit2($75,3); Q:=Jump;
 Emit($A0); DataAddress(InputByte); Emit2($30,$E4); LoopStart:=Jump;
 PatchJump(R,CodeSize); PatchJump(P,CodeSize); EmitLoadDS; Emit($A3); DataAddress(InputError);
 PatchJump(S,CodeSize); PatchJump(Q,CodeSize); LoadImmediate(26);
 PatchJump(Done,CodeSize); PatchJump(LoopStart,CodeSize);
 Emit($5E); Emit($5A); Emit($59); Emit($5B); Emit($1F); Emit($5F); Emit($07); Emit($C3);
 RuntimeStandard[56]:=CodeSize; { finaliser le Text Output local }
 Emit($50); Emit($06); Emit($57); Emit($1E); EmitLoadDS; Emit($1E); Emit($07);
 Emit($BF); DataAddress(StandardOutputAddress); CallTo(RuntimeStandard[52]);
 Emit($1F); Emit($5F); Emit($07); Emit($58); Emit($C3);
 RuntimeStandard[55]:=CodeSize; CallTo(RuntimeStandard[56]); Emit2($B4,$4C); Emit2($CD,$21);
End;

Procedure EmitFileRuntime;
Var P,Q,R,S,Done,I,FinishCount,ErrorCount,NameBuffer: Word;
 Dispatch: Array[1..7] Of Word;
 Finish,ErrorAddresses,ErrorCodes: Array[1..32] Of Word;
Procedure FinishIO;
Begin Inc(FinishCount); Finish[FinishCount]:=Jump End;
Procedure FailIf(CC: Byte; Code: Word);
Begin
 Emit2(CC Xor 1,3); Inc(ErrorCount);
 ErrorAddresses[ErrorCount]:=Jump; ErrorCodes[ErrorCount]:=Code;
End;
Procedure FileName;
Begin Emit($06); Emit($1F); Emit2($89,$FA); Emit2($83,$C2); Emit(16) End;
Procedure OpenResult(Mode: Word);
Begin
 Emit2($89,$05); Emit2($C7,$45); Emit(4); EmitWord(Mode);
 Emit2($C7,$45); Emit(6); EmitWord($FFFF); CallTo(RuntimeStandard[53]); Emit2($31,$C0); FinishIO;
End;
Begin
 { Layout local File/Text: handle, record size, mode, lookahead, text flag,
   reserved, signature, reserved, ASCIIZ name[80]. Pas d'ABI FileRec Borland. }
 RuntimeStandard[34]:=CodeSize; { Assign: DS:SI nom, ES:DI descripteur, BX recordsize, AX textflag }
 Emit($26); Emit2($C7,$05); EmitWord($FFFF);
 Emit($26); Emit2($89,$5D); Emit(2); Emit($26); Emit2($C7,$45); Emit(4); EmitWord(0);
 Emit($26); Emit2($C7,$45); Emit(6); EmitWord($FFFF); Emit($26); Emit2($89,$45); Emit(8);
 Emit($26); Emit2($C7,$45); Emit(12); EmitWord($5046);
 Emit2($09,$C0); Emit2($75,3); P:=Jump;
 Emit2($89,$F8); Emit($05); EmitWord(128);
 Emit($26); Emit2($89,$45); Emit(96); Emit2($8C,$C0); Emit($26); Emit2($89,$45); Emit(98);
 Emit($26); Emit2($C7,$45); Emit(100); EmitWord(128); CallTo(RuntimeStandard[53]);
 PatchJump(P,CodeSize);
 Emit2($31,$C9); Emit2($8A,$0C); Emit($46); Emit2($83,$F9); Emit(79); Emit2($76,3);
 Emit($B9); EmitWord(79); Emit2($83,$C7); Emit(16); Emit2($F3,$A4);
 Emit($26); Emit2($C6,$05); Emit(0); Emit($C3);


 RuntimeStandard[35]:=CodeSize;
 FinishCount:=0; ErrorCount:=0;
 Emit($55); Emit2($89,$E5); Emit($1E); Emit($06); Emit($57); Emit($53); Emit($50);
 { Fichier non assigne: 102 pour Reset/Rewrite/Append/Erase, 103 sinon (comme TP) }
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); Emit2($74,19);
 Emit($3D); EmitWord(3); FailIf($76,102); Emit($3D); EmitWord(5); FailIf($74,102);
 Inc(ErrorCount); ErrorAddresses[ErrorCount]:=Jump; ErrorCodes[ErrorCount]:=103;
 For I:=1 To 7 Do Begin Emit($3D); EmitWord(I); Emit2($75,3); Dispatch[I]:=Jump End;
 LoadImmediate(1); FinishIO;

 PatchJump(Dispatch[1],CodeSize); { Reset }
 Emit2($09,$DB); Emit2($74,4); Emit($26); Emit2($89,$5D); Emit(2);
 Emit($A0); DataAddress(FileModeAddress);
 Emit($26); Emit2($83,$7D); Emit(8); Emit(1); Emit2($75,2); Emit2($B0,0);
 Emit2($31,$C9); Emit2($88,$C1); Emit2($83,$E1); Emit(3); Emit($51); FileName;
 Emit2($80,$7D); Emit(16); Emit(0); Emit2($75,5); Emit2($31,$C0); P:=Jump;
 Emit2($B4,$3D); Emit2($CD,$21); FailIf($72,0); PatchJump(P,CodeSize);
 Emit2($89,$05); Emit2($8B,$4E); Emit($F4); Emit($41); Emit2($89,$4D); Emit(4);
 Emit2($C7,$45); Emit(6); EmitWord($FFFF); CallTo(RuntimeStandard[53]); Emit2($31,$C0); FinishIO;

 PatchJump(Dispatch[2],CodeSize); { Rewrite }
 Emit2($09,$DB); Emit2($74,4); Emit($26); Emit2($89,$5D); Emit(2); FileName;
 Emit2($80,$7D); Emit(16); Emit(0); Emit2($75,6); LoadImmediate(1); P:=Jump;
 Emit2($31,$C9); LoadImmediate($3C00); Emit2($CD,$21); FailIf($72,0);
 PatchJump(P,CodeSize); OpenResult(2);

 PatchJump(Dispatch[3],CodeSize); { Append }
 FileName; Emit2($80,$7D); Emit(16); Emit(0); Emit2($75,6); LoadImmediate(1); P:=Jump;
 LoadImmediate($3D01); Emit2($CD,$21); FailIf($72,0); Emit2($89,$05);
 Emit2($89,$C3); Emit2($31,$C9); Emit2($31,$D2); LoadImmediate($4202); Emit2($CD,$21);
 Emit2($73,3); Q:=Jump; Emit2($8B,$05); PatchJump(P,CodeSize); OpenResult(2);
 PatchJump(Q,CodeSize); Emit($50); Emit2($B4,$3E); Emit2($CD,$21); Emit($58); FinishIO;

 PatchJump(Dispatch[4],CodeSize); { Close }
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 CallTo(RuntimeStandard[52]); Emit2($09,$C0); FailIf($75,0);
 Emit($26); Emit2($8B,$1D); Emit2($83,$FB); Emit(3); Emit2($73,3); P:=Jump;
 Emit2($B4,$3E); Emit2($CD,$21); FailIf($72,0); PatchJump(P,CodeSize);
 Emit($26); Emit2($C7,$45); Emit(4); EmitWord(0); Emit2($31,$C0); FinishIO;

 PatchJump(Dispatch[5],CodeSize); { Erase }
 FileName; Emit2($B4,$41); Emit2($CD,$21); FailIf($72,0); Emit2($31,$C0); FinishIO;

 PatchJump(Dispatch[6],CodeSize); { Flush }
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(2); FailIf($75,105);
 CallTo(RuntimeStandard[52]); Emit2($09,$C0); FailIf($75,0);
 Emit2($B4,$0D); Emit2($CD,$21); Emit2($31,$C0); FinishIO;

 PatchJump(Dispatch[7],CodeSize); { Truncate }
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 Emit($26); Emit2($8B,$1D); Emit2($31,$C9); Emit2($31,$D2);
 Emit2($B4,$40); Emit2($CD,$21); FailIf($72,0); Emit2($31,$C0); FinishIO;

 For I:=1 To ErrorCount Do Begin
  PatchJump(ErrorAddresses[I],CodeSize);
  If ErrorCodes[I]<>0 Then LoadImmediate(ErrorCodes[I]); FinishIO;
 End;
 For I:=1 To FinishCount Do PatchJump(Finish[I],CodeSize);
 Emit2($8B,$4E); Emit($FE); Emit2($8E,$D9); Emit($A3); DataAddress(InputError);
 Emit2($8B,$4E); Emit($FC); Emit2($8E,$C1); Emit2($8B,$7E); Emit($FA);
 Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[36]:=CodeSize; { BlockRead/Write: DS:DX buffer, ES:DI file, CX count, AX=0/1 }
 FinishCount:=0; ErrorCount:=0;
 Emit($55); Emit2($89,$E5); Emit2($83,$EC); Emit(12);
 Emit2($89,$46); Emit($FE); Emit2($89,$4E); Emit($FC); Emit2($89,$56); Emit($FA);
 Emit2($89,$7E); Emit($F6); Emit2($8C,$46); Emit($F4);
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); FailIf($75,103);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 Emit2($09,$C0); Emit2($75,13);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(2); FailIf($74,104); P:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(1); FailIf($74,105); PatchJump(P,CodeSize);
 Emit($26); Emit2($8B,$5D); Emit(2); Emit2($09,$DB); FailIf($74,106); Emit2($89,$5E); Emit($F8);
 Emit2($09,$C9); Emit2($75,3); Q:=Jump;
 Emit2($89,$C8); Emit2($F7,$E3); { Count*RecSize, poids faible seulement comme TP }
 Emit2($89,$C1); Emit2($8B,$56); Emit($FA); Emit($26); Emit2($8B,$1D);
 Emit2($83,$7E); Emit($FE); Emit(0); Emit2($75,5); Emit2($B4,$3F); P:=Jump;
 Emit2($B4,$40); PatchJump(P,CodeSize); Emit2($CD,$21); FailIf($72,0);
 Emit2($31,$D2); Emit2($8B,$5E); Emit($F8); Emit2($F7,$F3);
 Emit2($31,$D2); FinishIO;
 PatchJump(Q,CodeSize); Emit2($31,$C0); Emit2($31,$D2); FinishIO;
 For I:=1 To ErrorCount Do Begin
  PatchJump(ErrorAddresses[I],CodeSize);
  If ErrorCodes[I]=$FFFF Then Begin LoadImmediate(100); Emit2($03,$46); Emit($FE) End
  Else If ErrorCodes[I]<>0 Then LoadImmediate(ErrorCodes[I]);
  Emit2($89,$C2); Emit2($31,$C0); FinishIO;
 End;
 For I:=1 To FinishCount Do PatchJump(Finish[I],CodeSize);
 Emit2($8B,$7E); Emit($F6); Emit2($8B,$5E); Emit($F4); Emit2($8E,$C3);
 Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[37]:=CodeSize; { Seek, position en records DX:AX }
 FinishCount:=0; ErrorCount:=0;
 Emit($55); Emit2($89,$E5); Emit($06); Emit($57);
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); FailIf($75,103);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 Emit($26); Emit2($8B,$5D); Emit(2); Emit2($31,$C9); CallTo(RuntimeStandard[14]);
 Emit2($89,$D1); Emit2($89,$C2); Emit($26); Emit2($8B,$1D);
 LoadImmediate($4200); Emit2($CD,$21); FailIf($72,0);
 Emit($26); Emit2($C7,$45); Emit(6); EmitWord($FFFF); Emit2($31,$C0); FinishIO;
 For I:=1 To ErrorCount Do Begin
  PatchJump(ErrorAddresses[I],CodeSize); If ErrorCodes[I]<>0 Then LoadImmediate(ErrorCodes[I]); FinishIO;
 End;
 For I:=1 To FinishCount Do PatchJump(Finish[I],CodeSize);
 Emit($A3); DataAddress(InputError); Emit($5F); Emit($07); Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[38]:=CodeSize; { FilePos/Size, resultat DX:AX, erreur CX }
 FinishCount:=0; ErrorCount:=0;
 Emit($55); Emit2($89,$E5); Emit2($83,$EC); Emit(24);
 Emit2($89,$46); Emit($FE); Emit2($89,$7E); Emit($E8); Emit2($8C,$46); Emit($EA);
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); FailIf($75,103);
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); FailIf($74,103);
 Emit($26); Emit2($8B,$5D); Emit(2); Emit2($09,$DB); FailIf($74,106);
 Emit2($89,$5E); Emit($FC); Emit($26); Emit2($8B,$1D);
 Emit2($31,$C9); Emit2($31,$D2); LoadImmediate($4201); Emit2($CD,$21); FailIf($72,0);
 Emit2($83,$7E); Emit($FE); Emit(0); Emit2($75,3); P:=Jump;
 Emit2($89,$46); Emit($F4); Emit2($89,$56); Emit($F2);
 Emit2($31,$C9); Emit2($31,$D2); LoadImmediate($4202); Emit2($CD,$21); FailIf($72,0);
 Emit2($89,$46); Emit($F0); Emit2($89,$56); Emit($EE);
 Emit2($8B,$4E); Emit($F2); Emit2($8B,$56); Emit($F4); LoadImmediate($4200); Emit2($CD,$21); FailIf($72,0);
 Emit2($8B,$46); Emit($F0); Emit2($8B,$56); Emit($EE);
 PatchJump(P,CodeSize); Emit2($8B,$5E); Emit($FC); Emit2($31,$C9); CallTo(RuntimeStandard[15]);
 Emit2($31,$C9); FinishIO;
 For I:=1 To ErrorCount Do Begin
  PatchJump(ErrorAddresses[I],CodeSize); If ErrorCodes[I]<>0 Then LoadImmediate(ErrorCodes[I]);
  Emit2($89,$C1); Emit2($31,$C0); Emit2($31,$D2); FinishIO;
 End;
 For I:=1 To FinishCount Do PatchJump(Finish[I],CodeSize);
 Emit2($8B,$7E); Emit($E8); Emit2($8B,$5E); Emit($EA); Emit2($8E,$C3);
 Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[40]:=CodeSize; { selection scoped du handle de sortie }
 Emit2($87,$06); DataAddress(OutputHandle); Emit($C3);

 RuntimeStandard[42]:=CodeSize; { Rename ES:DI ferme, nouveau shortstring DS:SI }
 NameBuffer:=AllocData(80);
 Emit($55); Emit2($89,$E5); Emit($06); Emit($57); Emit($1E); Emit($56);
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); Emit2($74,3); P:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); Emit2($74,3); Q:=Jump;
 EmitLoadES; Emit($BF); DataAddress(NameBuffer);
 Emit2($31,$C9); Emit($AC); Emit2($88,$C1); Emit2($83,$F9); Emit(79); Emit2($76,3); R:=Jump;
 Emit2($F3,$A4); Emit2($31,$C0); Emit($AA);
 Emit2($8B,$56); Emit($FC); Emit2($83,$C2); Emit(16);
 Emit2($8B,$46); Emit($FE); Emit2($8E,$D8);
 Emit($BF); DataAddress(NameBuffer); Emit2($B4,$56); Emit2($CD,$21); Emit2($73,3); S:=Jump;
 EmitLoadDS; Emit2($8B,$46); Emit($FE); Emit2($8E,$C0);
 Emit2($8B,$7E); Emit($FC); Emit2($83,$C7); Emit(16);
 Emit($BE); DataAddress(NameBuffer); Emit($B9); EmitWord(80); Emit2($F3,$A4);
 Emit2($31,$C0); Done:=Jump;
 PatchJump(P,CodeSize); LoadImmediate(102); P:=Jump;
 PatchJump(Q,CodeSize); LoadImmediate(102); Q:=Jump;
 PatchJump(R,CodeSize); LoadImmediate(3);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(S,CodeSize); PatchJump(Done,CodeSize);
 EmitLoadDS; CallTo(RuntimeStandard[24]);
 Emit($5E); Emit($1F); Emit($5F); Emit($07); Emit($5D); Emit($C3);

 RuntimeStandard[43]:=CodeSize; { DOS directory operation AH, DS:DX ASCIIZ }
 Emit2($CD,$21); Emit2($73,3); P:=Jump; Emit($C3);
 PatchJump(P,CodeSize); CallTo(RuntimeStandard[24]); Emit($C3);

 RuntimeStandard[44]:=CodeSize; { GetDir AX drive -> shortstring DX:AX }
 Emit($06); Emit($57); Emit($56); Emit($53); Emit($51);
 Emit2($C6,$06); DataAddress(StringScratch2); Emit(0);
 Emit($3D); EmitWord(26); Emit2($76,3); P:=Jump;
 Emit2($89,$C3); Emit2($09,$C0); Emit2($75,7);
 Emit2($B4,$19); Emit2($CD,$21); Emit2($30,$E4); Emit($40);
 Emit2($04,64); Emit($A2); DataAddress(StringScratch2+1);
 Emit2($C6,$06); DataAddress(StringScratch2+2); Emit(Ord(':'));
 Emit2($C6,$06); DataAddress(StringScratch2+3); Emit(Ord('\'));
 Emit2($89,$DA); Emit($BE); DataAddress(NameBuffer); Emit2($B4,$47); Emit2($CD,$21);
 Emit2($73,3); Q:=Jump;
 EmitLoadES; Emit($BF); DataAddress(StringScratch2+4); Emit($BE); DataAddress(NameBuffer);
 Emit($B9); EmitWord(3);
 R:=CodeSize; Emit($AC); Emit2($08,$C0); Emit2($75,3); S:=Jump;
 Emit($AA); Emit($41); JumpTo(R);
 PatchJump(S,CodeSize); Emit2($88,$0E); DataAddress(StringScratch2); Done:=Jump;
 PatchJump(P,CodeSize); LoadImmediate(15); PatchJump(Q,CodeSize); CallTo(RuntimeStandard[24]);
 PatchJump(Done,CodeSize); Emit($59); Emit($5B); Emit($5E); Emit($5F); Emit($07);
 Emit($B8); DataAddress(StringScratch2); Emit2($8C,$DA); Emit($C3);

 RuntimeStandard[45]:=CodeSize; { Eof(File): compare position et nombre de records }
 LoadImmediate(0); CallTo(RuntimeStandard[38]); Emit2($09,$C9); Emit2($74,3); P:=Jump;
 Emit($52); Emit($50); LoadImmediate(1); CallTo(RuntimeStandard[38]);
 Emit2($89,$D6); Emit($5B); Emit($5A); Emit2($09,$C9); Emit2($74,3); Q:=Jump;
 Emit2($39,$F2); Emit2($73,3); R:=Jump;
 Emit2($74,3); S:=Jump;
 Emit2($39,$C3); Emit2($73,3); Done:=Jump;
 PatchJump(S,CodeSize); LoadImmediate(1); Emit($C3);
 PatchJump(R,CodeSize); PatchJump(Done,CodeSize); LoadImmediate(0); Emit($C3);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); Emit2($89,$C8);
 CallTo(RuntimeStandard[24]); LoadImmediate(1); Emit($C3);

 RuntimeStandard[41]:=CodeSize; { input DX:AX, nil=stdin; rend l'ancien descripteur }
 Emit($55); Emit2($89,$E5); Emit($06); Emit($57); Emit($56); Emit($53); Emit($50); Emit($52);
 Emit2($8B,$36); DataAddress(InputFilePointer); Emit2($8B,$1E); DataAddress(InputFilePointer+2);
 Emit($56); Emit($53); Emit2($89,$D8); Emit2($09,$F0); Emit2($75,3); P:=Jump;
 Emit2($8E,$C3); Emit2($89,$F7); Emit($A1); DataAddress(InputAhead);
 Emit($26); Emit2($89,$45); Emit(6); Q:=Jump;
 PatchJump(P,CodeSize); Emit($A1); DataAddress(InputAhead); Emit($A3); DataAddress(InputConsoleAhead);
 PatchJump(Q,CodeSize); Emit2($8B,$46); Emit($F6); Emit2($8B,$56); Emit($F4);
 Emit($A3); DataAddress(InputFilePointer); Emit2($89,$16); DataAddress(InputFilePointer+2);
 Emit2($09,$D0); Emit2($75,3); P:=Jump;
 Emit2($8B,$46); Emit($F6); Emit2($89,$C7); Emit2($8E,$C2);
 Emit($26); Emit2($81,$7D); Emit(12); EmitWord($5046); Emit2($74,3); Q:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(0); Emit2($75,3); R:=Jump;
 Emit($26); Emit2($83,$7D); Emit(4); Emit(2); Emit2($75,3); S:=Jump;
 Emit($26); Emit2($8B,$05); Emit($A3); DataAddress(InputHandle);
 Emit($26); Emit2($8B,$45); Emit(6); Emit($A3); DataAddress(InputAhead); Done:=Jump;
 PatchJump(P,CodeSize); Emit($A1); DataAddress(InputConsoleAhead); Emit($A3); DataAddress(InputAhead);
 Emit2($C7,$06); DataAddress(InputHandle); EmitWord(0); P:=Jump;
 PatchJump(Q,CodeSize); LoadImmediate(104); Q:=Jump; { non assigne: 104 comme TP }
 PatchJump(R,CodeSize); LoadImmediate(103); R:=Jump;
 PatchJump(S,CodeSize); LoadImmediate(104); PatchJump(Q,CodeSize); PatchJump(R,CodeSize);
 CallTo(RuntimeStandard[24]); Emit2($C7,$06); DataAddress(InputAhead); EmitWord(26);
 PatchJump(P,CodeSize); PatchJump(Done,CodeSize);
 Emit2($8B,$46); Emit($F2); Emit2($8B,$56); Emit($F0);
 Emit2($8B,$5E); Emit($F8); Emit2($8B,$76); Emit($FA);
 Emit2($8B,$7E); Emit($FC); Emit2($8B,$4E); Emit($FE); Emit2($8E,$C1);
 Emit2($89,$EC); Emit($5D); Emit($C3);
End;

Procedure EmitOverlayRuntime;
Var P,Q,R,S,K,Done,LoopStart: Word; Bad: Array[1..24] Of Word; BadCount: Byte;
Procedure FailIf(CC: Byte);
Begin Emit2(CC Xor 1,3); Inc(BadCount); Bad[BadCount]:=Jump End;
Procedure SetResult(Value: Word);
Begin Emit2($C7,$06); DataAddress(OverlayResult); EmitWord(Value) End;
Procedure SetHandle(Value: Word);
Begin Emit2($C7,$06); DataAddress(OverlayHandle); EmitWord(Value) End;
Begin
 OverlayTable:=AllocData((MaxUnits+1)*16); OverlayFileName:=AllocData(256);
 OverlayResult:=AllocData(2); OverlayHandle:=AllocData(2); Data[OverlayHandle]:=255; Data[OverlayHandle+1]:=255;
 OverlayScratch:=AllocData(12); OverlayBufferSize:=AllocData(2); OverlayBankCount:=AllocData(2);

 RuntimeStandard[63]:=CodeSize; { invalider les regions chargees }
 Emit($51); Emit($56); Emit($BE); DataAddress(OverlayTable); Emit($B9); EmitWord(MaxUnits+1);
 LoopStart:=CodeSize; Emit2($C7,$04); EmitWord(0); Emit2($83,$C6); Emit(16);
 Emit($E2); Emit(Byte(Longint(LoopStart)-CodeSize-1)); Emit($5E); Emit($59); Emit($C3);

 RuntimeStandard[64]:=CodeSize; { ouvrir/valider le fichier OVR, AX=0 succes }
 BadCount:=0; Emit($53); Emit($51); Emit($52); CallTo(RuntimeStandard[63]);
 Emit2($8B,$1E); DataAddress(OverlayHandle); Emit2($81,$FB); EmitWord($FFFF); Emit2($75,3); P:=Jump;
 Emit2($B4,$3E); Emit2($CD,$21); PatchJump(P,CodeSize); SetHandle($FFFF);
 Emit($BA); DataAddress(OverlayFileName); LoadImmediate($3D00); Emit2($CD,$21); FailIf($72);
 Emit($A3); DataAddress(OverlayHandle); Emit2($89,$C3); Emit($B9); EmitWord(12); Emit($BA); DataAddress(OverlayScratch);
 Emit2($B4,$3F); Emit2($CD,$21); FailIf($72); Emit($3D); EmitWord(12); FailIf($75);
 Emit2($81,$3E); DataAddress(OverlayScratch); EmitWord($5054); FailIf($75);
 Emit2($81,$3E); DataAddress(OverlayScratch+2); EmitWord($4F43); FailIf($75);
 Emit2($81,$3E); DataAddress(OverlayScratch+4); EmitWord($5256); FailIf($75);
 Emit2($81,$3E); DataAddress(OverlayScratch+6); EmitWord($2131); FailIf($75);
 Emit2($81,$3E); DataAddress(OverlayScratch+8); EmitWord(1); FailIf($75);
 Emit($A1); DataAddress(OverlayBankCount); Emit2($3B,$06); DataAddress(OverlayScratch+10); FailIf($75);
 SetResult(0); Emit2($31,$C0); Done:=Jump;
 For K:=1 To BadCount Do PatchJump(Bad[K],CodeSize);
 Emit2($8B,$1E); DataAddress(OverlayHandle); Emit2($81,$FB); EmitWord($FFFF); Emit2($75,3); P:=Jump;
 Emit2($B4,$3E); Emit2($CD,$21); PatchJump(P,CodeSize); SetHandle($FFFF); SetResult($FFFF); LoadImmediate(1);
 PatchJump(Done,CodeSize); Emit($5A); Emit($59); Emit($5B); Emit($C3);

 RuntimeStandard[65]:=CodeSize; { lire exactement CX octets DS:DX et checksum [BP-14] }
 Emit($50); Emit($53); Emit($56); Emit2($8B,$1E); DataAddress(OverlayHandle);
 Emit2($B4,$3F); Emit2($CD,$21); Emit2($73,3); P:=Jump;
 Emit2($39,$C8); Emit2($74,3); Q:=Jump;
 Emit2($8B,$5E); Emit($F2); Emit2($89,$D6);
 LoopStart:=CodeSize; Emit2($D1,$C3); Emit2($8A,$04); Emit2($30,$E4); Emit2($01,$C3); Emit($46);
 Emit($E2); Emit(Byte(Longint(LoopStart)-CodeSize-1)); Emit2($89,$5E); Emit($F2);
 Emit($5E); Emit($5B); Emit($58); Emit($C3);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); SetResult($FFFF); LoadImmediate(209); CallTo(RuntimeError);

 RuntimeStandard[57]:=CodeSize; { charger la region AX; preserve registres et flags }
 BadCount:=0; Emit($9C); Emit($55); Emit2($89,$E5); Emit2($83,$EC); Emit(14);
 Emit2($89,$46); Emit($FE); Emit($50); Emit($53); Emit($51); Emit($52); Emit($56); Emit($57); Emit($1E); Emit($06);
 EmitLoadDS; Emit2($B1,4); Emit2($D3,$E0); Emit($05); DataAddress(OverlayTable); Emit2($89,$C6); Emit2($89,$76); Emit($FC);
 Emit2($83,$3C); Emit(1); Emit2($75,3); Done:=Jump;
 Emit2($83,$7C); Emit(6); Emit(1); FailIf($75);
 Emit2($83,$3E); DataAddress(OverlayHandle); Emit($FF); Emit2($74,3); P:=Jump;
 CallTo(RuntimeStandard[64]); Emit2($09,$C0); Emit2($74,3); Q:=Jump;
 S:=Jump; PatchJump(Q,CodeSize); LoadImmediate(208); CallTo(RuntimeError); PatchJump(S,CodeSize);
 PatchJump(P,CodeSize); Emit2($8B,$76); Emit($FC);
 Emit2($8B,$54); Emit(2); Emit2($8B,$4C); Emit(4); Emit2($8B,$1E); DataAddress(OverlayHandle);
 LoadImmediate($4200); Emit2($CD,$21); FailIf($72);
 Emit2($C7,$46); Emit($F2); EmitWord(0); Emit($B9); EmitWord(2); Emit($BA); DataAddress(OverlayScratch);
 CallTo(RuntimeStandard[65]); Emit($A1); DataAddress(OverlayScratch); Emit2($8B,$76); Emit($FC);
 Emit2($3B,$44); Emit(14); FailIf($75); Emit2($89,$46); Emit($FA);
 LoopStart:=CodeSize; Emit2($83,$7E); Emit($FA); Emit(0); Emit2($75,3); R:=Jump;
 Emit($B9); EmitWord(6); Emit($BA); DataAddress(OverlayScratch); CallTo(RuntimeStandard[65]);
 Emit2($8B,$16); DataAddress(OverlayScratch); Emit2($89,$56); Emit($F6);
 Emit2($8B,$0E); DataAddress(OverlayScratch+2); Emit2($09,$C9); FailIf($74); Emit2($89,$4E); Emit($F4);
 Emit2($8B,$76); Emit($FC); Emit2($3B,$54); Emit(8); FailIf($72);
 Emit2($89,$D0); Emit2($01,$C8); FailIf($72); Emit2($3B,$44); Emit(10); FailIf($77);
 Emit($A1); DataAddress(OverlayScratch+4); Emit2($89,$46); Emit($F8);
 CallTo(RuntimeStandard[65]);
 P:=CodeSize; Emit2($83,$7E); Emit($F8); Emit(0); Emit2($75,3); Q:=Jump;
 Emit($B9); EmitWord(2); Emit($BA); DataAddress(OverlayScratch); CallTo(RuntimeStandard[65]);
 Emit($A1); DataAddress(OverlayScratch); Emit2($89,$C3); Emit2($83,$C0); Emit(2); FailIf($72);
 Emit2($3B,$46); Emit($F4); FailIf($77); Emit2($03,$5E); Emit($F6);
 Emit2($8C,$D8); Emit2($01,$07); Emit2($FF,$4E); Emit($F8); JumpTo(P);
 PatchJump(Q,CodeSize); Emit2($FF,$4E); Emit($FA); JumpTo(LoopStart);
 PatchJump(R,CodeSize); Emit2($8B,$76); Emit($FC); Emit2($8B,$46); Emit($F2);
 Emit2($3B,$44); Emit(12); FailIf($75); Emit2($C7,$04); EmitWord(1); SetResult(0);
 PatchJump(Done,CodeSize); Emit($07); Emit($1F); Emit($5F); Emit($5E); Emit($5A); Emit($59); Emit($5B); Emit($58);
 Emit2($89,$EC); Emit($5D); Emit($9D); Emit($C3);
 For K:=1 To BadCount Do PatchJump(Bad[K],CodeSize);
 SetResult($FFFF); LoadImmediate(209); CallTo(RuntimeError);

 RuntimeStandard[58]:=CodeSize; { OvrInit(String), ABI Pascal far locale }
 Emit($55); Emit2($89,$E5); Emit($1E); Emit($06); Emit($56); Emit($57); Emit($51);
 Emit($16); Emit($1F); EmitLoadES; Emit2($8D,$76); Emit(8); Emit2($31,$C9); Emit($AC); Emit2($88,$C1);
 Emit($BF); DataAddress(OverlayFileName); Emit2($F3,$A4); Emit2($31,$C0); Emit($AA);
 EmitLoadDS; CallTo(RuntimeStandard[64]); Emit($59); Emit($5F); Emit($5E); Emit($07); Emit($1F); Emit($5D);
 Emit($CA); EmitWord(258);
 RuntimeStandard[59]:=CodeSize; { OvrDone }
 Emit($53); Emit2($8B,$1E); DataAddress(OverlayHandle); Emit2($81,$FB); EmitWord($FFFF); Emit2($75,3); P:=Jump;
 Emit2($B4,$3E); Emit2($CD,$21); PatchJump(P,CodeSize); SetHandle($FFFF); CallTo(RuntimeStandard[63]); SetResult(0);
 Emit($5B); Emit($CA); EmitWord(2);
 RuntimeStandard[60]:=CodeSize; CallTo(RuntimeStandard[63]); SetResult(0); Emit($CA); EmitWord(2);
 RuntimeStandard[61]:=CodeSize; Emit($A1); DataAddress(OverlayBufferSize); Emit2($31,$D2); Emit($CA); EmitWord(2);
 RuntimeStandard[62]:=CodeSize; { OvrSetBuf: regions fixes; autre taille -> ovrNoMemory }
 Emit($55); Emit2($89,$E5); Emit2($83,$7E); Emit(10); Emit(0); Emit2($74,3); P:=Jump;
 Emit2($8B,$46); Emit(8); Emit2($3B,$06); DataAddress(OverlayBufferSize); Emit2($74,3); Q:=Jump;
 SetResult(0); Done:=Jump; PatchJump(P,CodeSize); PatchJump(Q,CodeSize); SetResult($FFFE);
 PatchJump(Done,CodeSize); Emit($5D); Emit($CA); EmitWord(6);
End;

Procedure EmitStandardRuntime;
Var P,Q,R,S,LoopStart,K,ErrorCount,ParamEndCount: Word;
 Errors: Array[1..16] Of Word;
 ParamEnds: Array[1..8] Of Word;
Procedure ParamEnd;
Begin Inc(ParamEndCount); ParamEnds[ParamEndCount]:=Jump End;
Procedure BadIf(CC: Byte);
Begin
 Emit2(CC Xor 1,3); Inc(ErrorCount); Errors[ErrorCount]:=Jump;
End;
Begin
 FillChar(RuntimeStandard,SizeOf(RuntimeStandard),0);
 StringScratch:=AllocData(256); StringScratch2:=AllocData(256);
 InputAhead:=AllocData(2); Data[InputAhead]:=255; Data[InputAhead+1]:=255;
 InputByte:=AllocData(1); InputHandle:=AllocData(2);
 InputConsoleAhead:=AllocData(2); Data[InputConsoleAhead]:=255; Data[InputConsoleAhead+1]:=255;
 InputFilePointer:=AllocData(4);
 HeapHead:=AllocData(2); HeapLimit:=AllocData(2); HeapUsed:=AllocData(2);
 EmitTextRuntime;
 RuntimeStandard[31]:=CodeSize; { ParamCount: PSP command tail, espaces et tabs }
 Emit($06); Emit($56); Emit($53); Emit($51); Emit($52);
 Emit2($B4,$51); Emit2($CD,$21); Emit2($8E,$C3); Emit($BE); EmitWord($81);
 Emit2($31,$C9); Emit($26); Emit2($8A,$0E); EmitWord($80); Emit2($31,$D2);
 LoopStart:=CodeSize; Emit2($09,$C9); Emit2($75,3); P:=Jump;
 Emit($26); Emit2($8A,$04); Emit($46); Emit($49);
 Emit2($3C,32); Emit2($75,3); JumpTo(LoopStart);
 Emit2($3C,9); Emit2($75,3); JumpTo(LoopStart); Emit($42);
 K:=CodeSize; Emit2($09,$C9); Emit2($75,3); Q:=Jump;
 Emit($26); Emit2($8A,$04); Emit2($3C,32); Emit2($75,3); JumpTo(LoopStart);
 Emit2($3C,9); Emit2($75,3); JumpTo(LoopStart);
 Emit($46); Emit($49); JumpTo(K);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); Emit2($89,$D0);
 Emit($5A); Emit($59); Emit($5B); Emit($5E); Emit($07); Emit($C3);

 RuntimeStandard[32]:=CodeSize; { ParamStr AX -> shortstring DX:AX }
 ParamEndCount:=0;
 Emit($06); Emit($55); Emit($57); Emit($56); Emit($53); Emit($51);
 Emit2($89,$C5); Emit2($C6,$06); DataAddress(StringScratch2); Emit(0);
 Emit2($B4,$51); Emit2($CD,$21); Emit2($8E,$C3);
 Emit2($09,$ED); Emit2($75,3); P:=Jump;
 Emit($BE); EmitWord($81); Emit2($31,$C9); Emit($26); Emit2($8A,$0E); EmitWord($80);
 LoopStart:=CodeSize; Emit2($09,$C9); Emit2($75,3); ParamEnd;
 Emit($26); Emit2($8A,$04); Emit($46); Emit($49);
 Emit2($3C,32); Emit2($75,3); JumpTo(LoopStart);
 Emit2($3C,9); Emit2($75,3); JumpTo(LoopStart);
 Emit($4E); Emit($41); Emit($4D); Emit2($75,3); R:=Jump;
 K:=CodeSize; Emit2($09,$C9); Emit2($75,3); ParamEnd;
 Emit($26); Emit2($8A,$04); Emit2($3C,32); Emit2($75,3); JumpTo(LoopStart);
 Emit2($3C,9); Emit2($75,3); JumpTo(LoopStart);
 Emit($46); Emit($49); JumpTo(K);
 PatchJump(P,CodeSize);
 Emit2($B4,$30); Emit2($CD,$21); Emit2($3C,3); Emit2($73,3); ParamEnd;
 Emit($26); Emit2($8B,$1E); EmitWord($2C); Emit2($09,$DB); Emit2($75,3); ParamEnd;
 Emit2($8E,$C3); Emit2($31,$F6); Emit($B9); EmitWord($7FFF);
 K:=CodeSize; Emit($26); Emit2($8A,$04); Emit($46); Emit2($08,$C0); Emit2($74,3); Q:=Jump;
 Emit($26); Emit2($80,$3C); Emit(0); Emit2($75,3); S:=Jump;
 PatchJump(Q,CodeSize); Emit($E2); Emit(Byte(Longint(K)-CodeSize-1)); ParamEnd;
 PatchJump(S,CodeSize); Emit2($83,$C6); Emit(3); Emit($B9); EmitWord(255);
 Emit2($31,$D2); Q:=Jump;
 PatchJump(R,CodeSize); Emit($BA); EmitWord(1); PatchJump(Q,CodeSize);
 Emit($BF); DataAddress(StringScratch2+1); Emit2($31,$DB);
 K:=CodeSize; Emit2($09,$C9); Emit2($75,3); R:=Jump;
 Emit($26); Emit2($8A,$04); Emit2($08,$C0); Emit2($75,3); S:=Jump;
 Emit2($09,$D2); Emit2($74,3); Q:=Jump;
 P:=Jump; PatchJump(Q,CodeSize);
 Emit2($3C,32); Emit2($75,3); Q:=Jump;
 Emit2($3C,9); Emit2($75,3); LoopStart:=Jump;
 PatchJump(P,CodeSize);
 Emit2($88,$05); Emit($47); Emit($46); Emit($43); Emit($49); JumpTo(K);
 PatchJump(R,CodeSize); PatchJump(S,CodeSize); PatchJump(Q,CodeSize); PatchJump(LoopStart,CodeSize);
 Emit2($88,$1E); DataAddress(StringScratch2);
 For K:=1 To ParamEndCount Do PatchJump(ParamEnds[K],CodeSize);
 Emit($59); Emit($5B); Emit($5E); Emit($5F); Emit($5D); Emit($07);
 Emit($B8); DataAddress(StringScratch2); Emit2($8C,$DA); Emit($C3);
 RuntimeStandard[6]:=CodeSize; { set element: ES:DI bitmap universel, AX ordinal }
 Emit($50); Emit($53); Emit($51); Emit($52); Emit($57);
 Emit($3D); EmitWord(255); Emit2($76,3); P:=Jump;
 Emit2($89,$C3); Emit2($89,$C1); Emit2($80,$E1); Emit(7);
 Emit($BA); EmitWord(1); Emit2($D3,$E2); Emit2($B1,3); Emit2($D3,$EB); Emit2($01,$DF);
 Emit($26); Emit2($08,$15);
 Emit($5F); Emit($5A); Emit($59); Emit($5B); Emit($58); Emit($C3);
 PatchJump(P,CodeSize); LoadImmediate(201); CallTo(RuntimeError);
 RuntimeStandard[7]:=CodeSize; { set range AX..BX }
 Emit($56); Emit2($39,$D8); Emit2($76,3); P:=Jump;
 Emit2($89,$DE); Emit2($29,$C6); Emit($46); LoopStart:=CodeSize;
 CallTo(RuntimeStandard[6]); Emit($40); Emit($4E); Emit2($74,3); JumpTo(LoopStart);
 PatchJump(P,CodeSize); Emit($5E); Emit($C3);
 RuntimeStandard[1]:=CodeSize; { Copy: DS:SI, ES:DI, AX=index, CX=count, BX=capacite }
 Emit2($09,$C9); Emit2($7F,3); P:=Jump;
 Emit2($3D,1); Emit(0); Emit2($7D,3); Q:=Jump;
 Emit2($31,$D2); Emit2($8A,$14); Emit($48); Emit2($39,$D0); Emit2($72,3); R:=Jump;
 Emit2($29,$C2); Emit2($39,$D1); Emit2($76,2); Emit2($89,$D1);
 Emit2($39,$D9); Emit2($76,2); Emit2($89,$D9);
 Emit($26); Emit2($88,$0D); Emit($47); Emit($46); Emit2($01,$C6); Emit2($F3,$A4); Emit($C3);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(R,CodeSize);
 Emit($26); Emit2($C6,$05); Emit(0); Emit($C3);

 RuntimeStandard[2]:=CodeSize; { Pos: DS:SI needle, ES:DI haystack }
 Emit($55); Emit2($31,$C9); Emit2($8A,$0C); Emit2($31,$DB); Emit($26); Emit2($8A,$1D);
 Emit2($09,$C9); Emit2($75,3); P:=Jump;
 Emit2($39,$D9); Emit2($76,3); Q:=Jump;
 Emit2($29,$CB); Emit($43); Emit($46); Emit($47); Emit($BA); EmitWord(1);
 LoopStart:=CodeSize; Emit($51); Emit($56); Emit($57); Emit2($F3,$A6);
 Emit($5F); Emit($5E); Emit($59); Emit2($75,3); R:=Jump;
 Emit($47); Emit($42); Emit($4B); Emit2($74,3); JumpTo(LoopStart);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); Emit2($31,$C0); S:=Jump;
 PatchJump(R,CodeSize); Emit2($89,$D0); PatchJump(S,CodeSize); Emit($5D); Emit($C3);

 RuntimeStandard[3]:=CodeSize; { Concat: append DS:SI to ES:DI, BX=capacity }
 Emit2($31,$C0); Emit($26); Emit2($8A,$05); Emit2($31,$C9); Emit2($8A,$0C); Emit($46);
 Emit2($89,$DA); Emit2($29,$C2); Emit2($39,$D1); Emit2($76,2); Emit2($89,$D1);
 Emit($26); Emit2($00,$0D); Emit($47); Emit2($01,$C7); Emit2($F3,$A4); Emit($C3);

 RuntimeStandard[4]:=CodeSize; { Delete: ES:DI, AX=index, CX=count }
 Emit2($09,$C9); Emit2($7F,3); P:=Jump;
 Emit($3D); EmitWord(1); Emit2($7D,3); Q:=Jump;
 Emit2($31,$DB); Emit($26); Emit2($8A,$1D); Emit($48); Emit2($39,$D8); Emit2($72,3); R:=Jump;
 Emit2($29,$C3); Emit2($39,$D9); Emit2($76,2); Emit2($89,$D9);
 Emit($26); Emit2($28,$0D); Emit2($29,$CB); Emit($57);
 Emit2($89,$FE); Emit($46); Emit2($01,$C6); Emit2($89,$F2); Emit2($01,$CE); Emit2($89,$D7);
 Emit($1E); Emit($06); Emit($1F); Emit2($89,$D9); Emit2($F3,$A4); Emit($1F); Emit($5F);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(R,CodeSize); Emit($C3);

 RuntimeStandard[5]:=CodeSize; { Insert, copie intermediaire: alias source/destination autorise }
 Emit($55); Emit2($89,$E5); Emit($1E); Emit($56); Emit($06); Emit($57); Emit($50); Emit($53);
 Emit($3D); EmitWord(1); Emit2($7D,3); LoadImmediate(1);
 Emit2($31,$D2); Emit($26); Emit2($8A,$15); Emit($42);
 Emit2($39,$D0); Emit2($76,2); Emit2($89,$D0); Emit2($89,$46); Emit($F6);
 Emit2($89,$C1); Emit($49); LoadImmediate(1);
 Emit2($8B,$76); Emit($F8); Emit($06); Emit($1F); EmitLoadES;
 Emit($BF); DataAddress(StringScratch); Emit2($8B,$5E); Emit($F4); CallTo(RuntimeStandard[1]);
 Emit2($8B,$46); Emit($FE); Emit2($8E,$D8); Emit2($8B,$76); Emit($FC);
 Emit($BF); DataAddress(StringScratch); Emit2($8B,$5E); Emit($F4); CallTo(RuntimeStandard[3]);
 Emit2($8B,$46); Emit($FA); Emit2($8E,$D8); Emit2($8B,$76); Emit($F8);
 Emit($BF); DataAddress(StringScratch2); Emit2($8B,$46); Emit($F6);
 Emit($B9); EmitWord(255); Emit2($8B,$5E); Emit($F4); CallTo(RuntimeStandard[1]);
 EmitLoadDS; Emit($BE); DataAddress(StringScratch2); Emit($BF); DataAddress(StringScratch);
 Emit2($8B,$5E); Emit($F4); CallTo(RuntimeStandard[3]);
 Emit2($8B,$46); Emit($FA); Emit2($8E,$C0); Emit2($8B,$7E); Emit($F8);
 Emit($BE); DataAddress(StringScratch); LoadImmediate(1); Emit($B9); EmitWord(255);
 Emit2($8B,$5E); Emit($F4); CallTo(RuntimeStandard[1]);
 Emit2($8B,$46); Emit($FE); Emit2($8E,$D8); Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[12]:=CodeSize; { Move: DS:SI to ES:DI, CX bytes }
 Emit2($09,$C9); Emit2($7F,3); P:=Jump;
 Emit2($8C,$D8); Emit2($8C,$C2); Emit2($39,$D0); Emit2($74,3); Q:=Jump;
 Emit2($39,$F7); Emit2($77,3); R:=Jump;
 Emit2($89,$F0); Emit2($01,$C8); Emit2($39,$C7); Emit2($72,3); S:=Jump;
 Emit2($01,$CE); Emit($4E); Emit2($01,$CF); Emit($4F); Emit($FD); Emit2($F3,$A4); Emit($FC); Emit($C3);
 PatchJump(Q,CodeSize); PatchJump(R,CodeSize); PatchJump(S,CodeSize); Emit($FC); Emit2($F3,$A4);
 PatchJump(P,CodeSize); Emit($FC); Emit($C3);

 RuntimeStandard[13]:=CodeSize; { comparaison lexicographique de shortstrings }
 Emit2($31,$C0); Emit2($8A,$04); Emit2($31,$DB); Emit($26); Emit2($8A,$1D);
 Emit2($89,$C1); Emit2($39,$D9); Emit2($76,2); Emit2($89,$D9);
 Emit($46); Emit($47); Emit2($09,$C9); Emit2($75,3); P:=Jump;
 Emit2($F3,$A6); Emit2($74,3); Q:=Jump;
 PatchJump(P,CodeSize); Emit2($39,$D8);
 PatchJump(Q,CodeSize); Emit2($75,3); R:=Jump;
 Emit2($72,3); S:=Jump; LoadImmediate($FFFF); Emit($C3);
 PatchJump(S,CodeSize); LoadImmediate(1); Emit($C3);
 PatchJump(R,CodeSize); Emit2($31,$C0); Emit($C3);

 RuntimeStandard[14]:=CodeSize; { multiplication DX:AX * CX:BX, modulo 2^32 }
 Emit($56); Emit($57); Emit2($89,$C6); Emit2($89,$D7); Emit2($F7,$E3); Emit($52); Emit($50);
 Emit2($89,$F8); Emit2($F7,$E3); Emit2($89,$C7); Emit2($89,$F0); Emit2($F7,$E1);
 Emit2($01,$C7); Emit($58); Emit($5A); Emit2($01,$FA); Emit($5F); Emit($5E); Emit($C3);

 RuntimeStandard[15]:=CodeSize; { division signee 32 bits; quotient DX:AX, reste CX:BX }
 Emit($55); Emit2($89,$DE); Emit2($09,$CE); Emit2($75,3); P:=Jump;
 Emit2($31,$F6); Emit2($09,$D2); Emit2($79,10);
 Emit2($F7,$D8); Emit2($83,$D2); Emit(0); Emit2($F7,$DA); Emit($BE); EmitWord(3);
 Emit2($09,$C9); Emit2($79,10);
 Emit2($F7,$DB); Emit2($83,$D1); Emit(0); Emit2($F7,$D9); Emit2($83,$F6); Emit(1);
 Emit($56); Emit2($31,$F6); Emit2($31,$FF); Emit($BD); EmitWord(32);
 LoopStart:=CodeSize;
 Emit2($D1,$E0); Emit2($D1,$D2); Emit2($D1,$D6); Emit2($D1,$D7);
 Emit2($39,$CF); Emit2($76,3); Q:=Jump;
 Emit2($73,3); R:=Jump;
 Emit2($39,$DE); Emit2($73,3); S:=Jump;
 PatchJump(Q,CodeSize); Emit2($29,$DE); Emit2($19,$CF); Emit2($83,$C8); Emit(1);
 PatchJump(R,CodeSize); PatchJump(S,CodeSize); Emit($4D); Emit2($74,3); JumpTo(LoopStart);
 Emit2($89,$F3); Emit2($89,$F9); Emit($5D);
 Emit2($F7,$C5); EmitWord(1); Emit2($74,7); Emit2($F7,$D8); Emit2($83,$D2); Emit(0); Emit2($F7,$DA);
 Emit2($F7,$C5); EmitWord(2); Emit2($74,7); Emit2($F7,$DB); Emit2($83,$D1); Emit(0); Emit2($F7,$D9);
 Emit($5D); Emit($C3);
 PatchJump(P,CodeSize); LoadImmediate(200); CallTo(RuntimeError);

 RuntimeStandard[16]:=CodeSize; { decimal signed DX:AX -> shortstring dans StringScratch2 }
 Emit($55); Emit($57); Emit($56); Emit2($31,$ED); Emit2($09,$D2); Emit2($79,10);
 Emit2($F7,$D8); Emit2($83,$D2); Emit(0); Emit2($F7,$DA); Emit($BD); EmitWord($8000);
 Emit($BF); DataAddress(StringScratch2+12); Emit($BB); EmitWord(10);
 LoopStart:=CodeSize; Emit2($89,$C1); Emit2($89,$D0); Emit2($31,$D2); Emit2($F7,$F3);
 Emit2($89,$C6); Emit2($89,$C8); Emit2($F7,$F3); Emit2($80,$C2); Emit(Ord('0'));
 Emit($4F); Emit2($88,$15); Emit2($89,$F2); Emit($45); Emit2($89,$D1); Emit2($09,$C1);
 Emit2($74,3); JumpTo(LoopStart);
 Emit2($F7,$C5); EmitWord($8000); Emit2($74,9);
 Emit($4F); Emit2($C6,$05); Emit(Ord('-')); Emit($45); Emit2($81,$E5); EmitWord($7FFF);
 Emit2($89,$FE); Emit2($89,$E9); Emit($BF); DataAddress(StringScratch2);
 Emit2($88,$0D); Emit($47); Emit($06); Emit($1E); Emit($07); Emit2($F3,$A4); Emit($07);
 Emit($5E); Emit($5F); Emit($5D); Emit($B8); DataAddress(StringScratch2); Emit2($8C,$DA); Emit($C3);

 RuntimeStandard[17]:=CodeSize; { Val: DS:SI -> DX:AX, CX=position erreur }
 ErrorCount:=0;
 Emit($55); Emit2($89,$E5); Emit2($83,$EC); Emit(8);
 Emit2($C7,$46); Emit($FE); EmitWord(0); { signe }
 Emit2($C7,$46); Emit($FC); EmitWord(10); { base }
 Emit2($C7,$46); Emit($FA); EmitWord(1); { position }
 Emit2($31,$C9); Emit2($8A,$0C); Emit($46); Emit2($89,$4E); Emit($F8);
 Emit2($09,$C9); BadIf($74);
 Emit2($8A,$04); Emit2($3C,Ord('-')); Emit2($75,5);
 Emit2($C7,$46); Emit($FE); EmitWord(1);
 Emit2($3C,Ord('-')); Emit2($74,4); Emit2($3C,Ord('+')); Emit2($75,12);
 Emit($46); Emit2($FF,$46); Emit($FA); Emit2($FF,$4E); Emit($F8);
 Emit2($75,3); P:=Jump; Inc(ErrorCount); Errors[ErrorCount]:=P;
 Emit2($80,$3C); Emit(Ord('$')); Emit2($75,17);
 Emit2($C7,$46); Emit($FC); EmitWord(16); Emit($46);
 Emit2($FF,$46); Emit($FA); Emit2($FF,$4E); Emit($F8); BadIf($74);
 Emit2($31,$C0); Emit2($31,$D2);
 LoopStart:=CodeSize; Emit2($31,$DB); Emit2($8A,$1C);
 Emit2($83,$FB); Emit(Ord('0')); BadIf($72);
 Emit2($83,$FB); Emit(Ord('9')); Emit2($77,3); P:=Jump;
 Emit2($83,$7E); Emit($FC); Emit(16); BadIf($75);
 Emit2($80,$E3); Emit($DF); Emit2($83,$FB); Emit(Ord('A')); BadIf($72);
 Emit2($83,$FB); Emit(Ord('F')); BadIf($77);
 Emit2($83,$EB); Emit(55); Q:=Jump;
 PatchJump(P,CodeSize); Emit2($83,$EB); Emit(48); PatchJump(Q,CodeSize);
 Emit2($89,$DF); Emit($56); Emit($57); Emit2($89,$C6); Emit2($89,$D7);
 Emit2($8B,$5E); Emit($FC); Emit2($F7,$E3); Emit2($89,$D1); Emit($50);
 Emit2($89,$F8); Emit2($F7,$E3); Emit2($09,$D2); Emit2($74,3); P:=Jump;
 Emit2($01,$C8); Emit2($73,3); Q:=Jump;
 Emit2($89,$C2); Emit($58); Emit($5F); Emit($5E); Emit2($01,$F8); Emit2($83,$D2); Emit(0); BadIf($72);
 Emit($46); Emit2($FF,$46); Emit($FA); Emit2($FF,$4E); Emit($F8); Emit2($74,3); JumpTo(LoopStart);
 Emit2($83,$7E); Emit($FC); Emit(16); Emit2($75,3); R:=Jump;
 Emit2($81,$FA); EmitWord($8000); Emit2($73,3); S:=Jump;
 Emit2($74,3); K:=Jump;
 Emit2($09,$C0); BadIf($75); Emit2($83,$7E); Emit($FE); Emit(0); BadIf($74);
 PatchJump(S,CodeSize); PatchJump(R,CodeSize);
 Emit2($83,$7E); Emit($FE); Emit(0); Emit2($74,7);
 Emit2($F7,$D8); Emit2($83,$D2); Emit(0); Emit2($F7,$DA);
 Emit2($31,$C9); R:=Jump;
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); Emit2($83,$C4); Emit(6); S:=Jump;
 For P:=1 To ErrorCount Do PatchJump(Errors[P],CodeSize);
 PatchJump(K,CodeSize); PatchJump(S,CodeSize);
 Emit2($8B,$4E); Emit($FA); Emit2($31,$C0); Emit2($31,$D2);
 PatchJump(R,CodeSize); Emit2($89,$EC); Emit($5D); Emit($C3);

 RuntimeStandard[18]:=CodeSize; { peek stdin, ^Z represente EOF }
 Emit($53); Emit($51); Emit($52); Emit($56); Emit($57); Emit($06);
 Emit($A1); DataAddress(InputAhead); Emit($3D); EmitWord($FFFF); Emit2($74,3); P:=Jump;
 CallTo(RuntimeStandard[48]);
 Emit($A3); DataAddress(InputAhead);
 PatchJump(P,CodeSize); Emit($07); Emit($5F); Emit($5E); Emit($5A); Emit($59); Emit($5B); Emit($C3);
 RuntimeStandard[19]:=CodeSize; { consume stdin }
 CallTo(RuntimeStandard[18]); Emit($3D); EmitWord(26); Emit2($74,6);
 Emit2($C7,$06); DataAddress(InputAhead); EmitWord($FFFF); Emit($C3);

 RuntimeStandard[20]:=CodeSize; { token entier, sans consommer le separateur final }
 Emit($56); Emit($53); Emit($BE); DataAddress(StringScratch+1); Emit2($31,$DB);
 LoopStart:=CodeSize; CallTo(RuntimeStandard[18]); Emit($3D); EmitWord(26); Emit2($75,3); P:=Jump;
 Emit($3D); EmitWord(32); Emit2($76,3); Q:=Jump;
 CallTo(RuntimeStandard[19]); JumpTo(LoopStart);
 PatchJump(Q,CodeSize); Q:=CodeSize;
 CallTo(RuntimeStandard[18]); Emit($3D); EmitWord(32); Emit2($77,3); R:=Jump;
 CallTo(RuntimeStandard[19]); Emit2($81,$FB); EmitWord(255); Emit2($72,3); S:=Jump;
 Emit2($88,$04); Emit($46); Emit($43); PatchJump(S,CodeSize); JumpTo(Q);
 PatchJump(P,CodeSize); PatchJump(R,CodeSize);
 Emit2($88,$1E); DataAddress(StringScratch); Emit($5B); Emit($5E);
 Emit($B8); DataAddress(StringScratch); Emit2($8C,$DA); Emit($C3);

 RuntimeStandard[21]:=CodeSize; { Read string: ne depasse pas la capacite BX }
 Emit($56); Emit($57); Emit($BE); DataAddress(StringScratch+1); Emit2($31,$FF);
 LoopStart:=CodeSize; Emit2($39,$DF); Emit2($72,3); P:=Jump;
 CallTo(RuntimeStandard[18]); Emit($3D); EmitWord(26); Emit2($75,3); Q:=Jump;
 Emit($3D); EmitWord(13); Emit2($75,3); R:=Jump;
 Emit($3D); EmitWord(10); Emit2($75,3); S:=Jump;
 CallTo(RuntimeStandard[19]); Emit2($88,$04); Emit($46); Emit($47); JumpTo(LoopStart);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(R,CodeSize); PatchJump(S,CodeSize);
 Emit2($89,$F8); Emit($A2); DataAddress(StringScratch); Emit($5F); Emit($5E);
 Emit($B8); DataAddress(StringScratch); Emit2($8C,$DA); Emit($C3);

 RuntimeStandard[22]:=CodeSize; { ReadLn consomme CR/LF ou LF }
 LoopStart:=CodeSize; CallTo(RuntimeStandard[18]); Emit($3D); EmitWord(26); Emit2($75,3); P:=Jump;
 Emit($3D); EmitWord(10); Emit2($75,3); Q:=Jump;
 Emit($3D); EmitWord(13); Emit2($75,3); R:=Jump;
 CallTo(RuntimeStandard[19]); JumpTo(LoopStart);
 PatchJump(R,CodeSize); CallTo(RuntimeStandard[19]); CallTo(RuntimeStandard[18]);
 Emit($3D); EmitWord(10); Emit2($74,3); S:=Jump;
 PatchJump(Q,CodeSize); CallTo(RuntimeStandard[19]);
 PatchJump(P,CodeSize); PatchJump(S,CodeSize); Emit($C3);

 RuntimeStandard[23]:=CodeSize; { IOResult, lecture et remise a zero }
 Emit($A1); DataAddress(InputError); Emit2($C7,$06); DataAddress(InputError); EmitWord(0); Emit($C3);
 RuntimeStandard[24]:=CodeSize; { memoriser une erreur I/O }
 Emit2($83,$3E); DataAddress(InputError); Emit(0); Emit2($75,3);
 Emit($A3); DataAddress(InputError); Emit($C3);
 RuntimeStandard[25]:=CodeSize; { controle $I+ }
 Emit($A1); DataAddress(InputError); Emit2($09,$C0); Emit2($74,3); JumpTo(RuntimeError); Emit($C3);

 RuntimeStandard[26]:=CodeSize; { GetMem: DOS blocs, header prive 16 octets }
 Emit($55); Emit2($89,$E5); Emit($06); Emit($50);
 Emit2($89,$C3); Emit2($B1,4); Emit2($D3,$EB); Emit($25); EmitWord(15);
 Emit2($74,1); Emit($43); Emit($43); Emit($53);
 Emit($A1); DataAddress(HeapLimit); Emit2($2B,$06); DataAddress(HeapUsed);
 Emit2($39,$C3); Emit2($76,3); P:=Jump;
 Emit2($B4,$48); Emit2($CD,$21); Emit2($73,3); Q:=Jump;
 Emit2($8E,$C0); Emit2($31,$FF); Emit($8B); Emit($16); DataAddress(HeapHead);
 Emit($26); Emit2($89,$15); Emit($26); Emit2($C7,$45); Emit(2); EmitWord(0);
 Emit2($8B,$5E); Emit($FC); Emit($26); Emit2($89,$5D); Emit(4);
 Emit($26); Emit2($C7,$45); Emit(6); EmitWord($5450);
 Emit2($8B,$5E); Emit($FA); Emit($26); Emit2($89,$5D); Emit(8);
 Emit2($01,$1E); DataAddress(HeapUsed);
 Emit2($09,$D2); Emit2($74,6); Emit2($8E,$C2);
 Emit($26); Emit2($A3,2); Emit(0);
 Emit($A3); DataAddress(HeapHead); Emit2($89,$C2); Emit($42); Emit2($31,$C0);
 Emit2($8B,$4E); Emit($FE); Emit2($8E,$C1); Emit2($89,$EC); Emit($5D); Emit($C3);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); LoadImmediate(203); CallTo(RuntimeError);

 RuntimeStandard[27]:=CodeSize; { Dispose/FreeMem, verifie le header et retire de la liste }
 ErrorCount:=0; Emit($06); Emit2($09,$C0); BadIf($75); Emit2($09,$D2); BadIf($74);
 Emit($4A); Emit2($8E,$C2); Emit($26); Emit2($81,$3E); EmitWord(6); EmitWord($5450); BadIf($75);
 Emit2($09,$F6); Emit2($74,10);
 Emit($26); Emit2($3B,$1E); EmitWord(4); BadIf($75);
 Emit($26); Emit2($8B,$3E); EmitWord(8); Emit2($29,$3E); DataAddress(HeapUsed);
 Emit($26); Emit2($8B,$1E); EmitWord(0); Emit($26); Emit2($8B,$0E); EmitWord(2);
 Emit($26); Emit2($C7,$06); EmitWord(6); EmitWord(0);
 Emit2($09,$DB); Emit2($74,7); Emit2($8E,$C3); Emit($26); Emit2($89,$0E); EmitWord(2);
 Emit2($09,$C9); Emit2($74,7); Emit2($8E,$C1); Emit($26); Emit2($89,$1E); EmitWord(0);
 Emit2($3B,$16); DataAddress(HeapHead); Emit2($75,4); Emit2($89,$1E); DataAddress(HeapHead);
 Emit2($8E,$C2); Emit2($B4,$49); Emit2($CD,$21); BadIf($72); Emit($07); Emit($C3);
 For K:=1 To ErrorCount Do PatchJump(Errors[K],CodeSize);
 LoadImmediate(204); CallTo(RuntimeError);

 RuntimeStandard[29]:=CodeSize; { Mark, token prive de la liste d'allocations }
 Emit($8B); Emit($16); DataAddress(HeapHead); Emit2($31,$C0); Emit($C3);
 RuntimeStandard[30]:=CodeSize; { Release jusqu'au token Mark }
 Emit($55); Emit2($89,$D5); LoopStart:=CodeSize;
 Emit($8B); Emit($16); DataAddress(HeapHead); Emit2($39,$EA); Emit2($75,3); P:=Jump;
 Emit2($09,$D2); Emit2($75,3); Q:=Jump;
 Emit($42); Emit2($31,$C0); Emit2($31,$F6); CallTo(RuntimeStandard[27]); JumpTo(LoopStart);
 PatchJump(P,CodeSize); Emit($5D); Emit($C3);
 PatchJump(Q,CodeSize); LoadImmediate(204); CallTo(RuntimeError);

 RuntimeStandard[33]:=CodeSize; { MaxAvail: plus grand bloc DOS, limite quota et Word }
 Emit($06); Emit($BB); EmitWord($FFFF); Emit2($B4,$48); Emit2($CD,$21);
 Emit($A1); DataAddress(HeapLimit); Emit2($2B,$06); DataAddress(HeapUsed);
 Emit2($39,$C3); Emit2($76,2); Emit2($89,$C3);
 Emit2($09,$DB); Emit2($75,3); P:=Jump; Emit($4B);
 Emit2($81,$FB); EmitWord(4096); Emit2($72,3); R:=Jump;
 Emit2($89,$D8); Emit2($31,$D2); Emit2($B1,4); Emit2($D3,$E0); Q:=Jump;
 PatchJump(R,CodeSize); LoadImmediate($FFFF); Emit2($31,$D2); R:=Jump;
 PatchJump(P,CodeSize); Emit2($31,$C0); Emit2($31,$D2);
 PatchJump(Q,CodeSize); PatchJump(R,CodeSize); Emit($07); Emit($C3);
 RuntimeStandard[46]:=CodeSize; { MemAvail: somme des blocs DOS, sans conserver les sondes }
 Emit($06); Emit($55); Emit($57); Emit($56); Emit($53); Emit($51);
 Emit2($31,$F6); Emit2($31,$FF);
 Emit2($8B,$0E); DataAddress(HeapLimit); Emit2($2B,$0E); DataAddress(HeapUsed);
 LoopStart:=CodeSize; Emit2($09,$C9); Emit2($75,3); P:=Jump;
 Emit($BB); EmitWord($FFFF); Emit2($B4,$48); Emit2($CD,$21);
 Emit2($09,$DB); Emit2($75,3); Q:=Jump;
 Emit2($39,$CB); Emit2($76,2); Emit2($89,$CB);
 Emit2($B4,$48); Emit2($CD,$21); Emit2($73,3); R:=Jump;
 Emit2($8E,$C0); Emit($26); Emit2($89,$36); EmitWord(0); Emit2($89,$C6);
 Emit2($01,$DF); Emit($4F); Emit2($29,$D9); JumpTo(LoopStart);
 PatchJump(P,CodeSize); PatchJump(Q,CodeSize); PatchJump(R,CodeSize);
 LoopStart:=CodeSize; Emit2($09,$F6); Emit2($75,3); P:=Jump;
 Emit2($8E,$C6); Emit($26); Emit2($8B,$36); EmitWord(0); Emit2($B4,$49); Emit2($CD,$21); JumpTo(LoopStart);
 PatchJump(P,CodeSize); Emit2($89,$F8); Emit2($89,$FA); Emit2($B1,12); Emit2($D3,$EA);
 Emit2($B1,4); Emit2($D3,$E0);
 Emit($59); Emit($5B); Emit($5E); Emit($5F); Emit($5D); Emit($07); Emit($C3);

 RuntimeStandard[47]:=CodeSize; { RunError(N): message et terminaison }
 JumpTo(RuntimeError);
 EmitFileRuntime;
 EmitOverlayRuntime;
End;

Procedure EmitRuntimeError;
{ Erreur d'execution: AX = code, [SP] = adresse de retour de l'appelant.
  Comme TP 7.0 ("Runtime error N at S:O."), le message est ecrit apres avoir
  vide le tampon de sortie, puis le programme se termine avec le code N.
  Le segment affiche est relatif au debut du programme (toujours 0000 ici). }
Const Msg = 'Erreur d''execution 000 a 0000:0000.'#13#10;
Var K,L1,L2: Word;
Begin
 RuntimeErrorText:=AllocData(Length(Msg));
 For K:=1 To Length(Msg) Do Data[RuntimeErrorText+K-1]:=Ord(Msg[K]);
 PatchJump(RuntimeErrorPatch,CodeSize);
 Emit($5B); EmitLoadDS; Emit($50); Emit($53);             { pop bx; ds=donnees; push ax; push bx }
 CallTo(RuntimeStandard[56]);                               { vider Output }
 Emit($5B); Emit($58); Emit($50);                           { pop bx; pop ax; push ax }
 Emit($BF); DataAddress(RuntimeErrorText+21); Emit($B9); EmitWord(3);
 L1:=CodeSize;
 Emit2($31,$D2); Emit($BE); EmitWord(10); Emit2($F7,$F6);  { xor dx,dx; mov si,10; div si }
 Emit2($80,$C2); Emit(Ord('0')); Emit2($88,$15); Emit($4F); { add dl,'0'; mov [di],dl; dec di }
 Emit($E2); Emit(Byte(Longint(L1)-CodeSize-1));
 Emit($BF); DataAddress(RuntimeErrorText+33); Emit($B9); EmitWord(4);
 L2:=CodeSize;
 Emit2($88,$D8); Emit2($24,$0F); Emit2($04,Ord('0'));       { mov al,bl; and al,15; add al,'0' }
 Emit2($3C,Ord('9')); Emit2($76,2); Emit2($04,7);           { cmp al,'9'; jbe +2; add al,7 }
 Emit2($88,$05); Emit($4F);                                 { mov [di],al; dec di }
 For K:=1 To 4 Do Emit2($D1,$EB);                           { shr bx,1 }
 Emit($E2); Emit(Byte(Longint(L2)-CodeSize-1));
 { Comme TP, le numero est affiche sur trois chiffres ("Runtime error 002 at ...") }
 Emit2($B4,$40); Emit($BB); EmitWord(1); Emit($B9); EmitWord(Length(Msg));
 Emit($BA); DataAddress(RuntimeErrorText); Emit2($CD,$21);
 Emit($58); Emit2($B4,$4C); Emit2($CD,$21);                 { pop ax; exit(al) }
End;

Procedure EmitRuntime;
Var LoadDSAddr,LoadESAddr,StackCheckAddr: Word;
 P, Q, LoopStart: Word;
Begin
 InputError:=AllocData(2); OutputHandle:=AllocData(2); Data[OutputHandle]:=1;
 OutputFilePointer:=AllocData(4);
 OutputByte:=AllocData(1);
 NumberBuffer:=AllocData(6);
 TrueText:=StoreString('TRUE'); FalseText:=StoreString('FALSE');
 RuntimeChar:=CodeSize;
 BufferedCharPatch:=Jump; RuntimeRawChar:=CodeSize;
 Emit($1E); EmitLoadDS; Emit2($83,$3E); DataAddress(InputError); Emit(0); Emit($1F); Emit2($74,1); Emit($C3);
 Emit($1E); EmitLoadDS; Emit2($83,$3E); DataAddress(OutputHandle); Emit(1); Emit($1F); Emit2($75,7);
 Emit2($89,$C2); Emit2($B4,$02); Emit2($CD,$21); Emit($C3);
 Emit($53); Emit($51); Emit($52); Emit($1E); EmitLoadDS;
 Emit($A2); DataAddress(OutputByte); Emit2($8B,$1E); DataAddress(OutputHandle);
 Emit($B9); EmitWord(1); Emit($BA); DataAddress(OutputByte); Emit2($B4,$40); Emit2($CD,$21);
 Emit2($73,3); P:=Jump; Emit($1F); Emit($5A); Emit($59); Emit($5B); Emit($C3);
 PatchJump(P,CodeSize); Emit($A3); DataAddress(InputError);
 Emit($1F); Emit($5A); Emit($59); Emit($5B); Emit($C3);
 RuntimeString:=CodeSize;
 Emit2($89,$C6); Emit2($31,$C9); Emit2($8A,$0C); Emit($46);
 Emit2($09,$C9); Emit2($75,$03); P:=Jump;
 LoopStart:=CodeSize;
 Emit($AC); CallTo(RuntimeChar); Emit($E2);
 Emit(Byte(Longint(LoopStart)-CodeSize-1));
 PatchJump(P,CodeSize); Emit($C3);
 RuntimeInteger:=CodeSize;
 Emit2($09,$C0); Emit2($79,$0A); Emit($50);
 LoadImmediate(Ord('-')); CallTo(RuntimeChar); Emit($58); Emit2($F7,$D8);
 RuntimeUnsigned:=CodeSize;
 Emit($BF); DataAddress(NumberBuffer+6); Emit($BB); EmitWord(10);
 Emit2($31,$C9); LoopStart:=CodeSize;
 Emit2($31,$D2); Emit2($F7,$F3); Emit2($80,$C2); Emit(Ord('0'));
 Emit($4F); Emit2($88,$15); Emit($41); Emit2($09,$C0); Emit2($75,0);
 Image[CodeSize-1]:=Byte(Longint(LoopStart)-CodeSize);
 Emit2($89,$FE); LoopStart:=CodeSize; Emit($AC); CallTo(RuntimeChar);
 Emit($E2); Emit(Byte(Longint(LoopStart)-CodeSize-1)); Emit($C3);
 RuntimeBoolean:=CodeSize;
 Emit2($09,$C0); Emit2($74,$06);
 Emit($B8); DataAddress(TrueText); Q:=Jump;
 Emit($B8); DataAddress(FalseText); PatchJump(Q,CodeSize);
 JumpTo(RuntimeString);
 RuntimeCopy:=CodeSize;      { DS:SI source, ES:DI dest, CX capacite }
 Emit($06); Emit($1E); Emit($07); { ES=DS, restaurer l'ES de l'appelant }
 Emit2($31,$C0); Emit($AC); Emit2($39,$C8); Emit2($76,$02);
 Emit2($89,$C8); Emit($AA); Emit2($89,$C1); Emit2($F3,$A4); Emit($07); Emit($C3);
 RuntimeHalt:=CodeSize; BufferedHaltPatch:=Jump;
 RuntimeError:=CodeSize; RuntimeErrorPatch:=Jump;
 LoadDSAddr:=CodeSize; EmitLoadDS; Emit($C3); { DS := donnees }
 LoadESAddr:=CodeSize; EmitLoadES; Emit($C3); { ES := donnees }
 { StackCheck: "call StackCheck; dw N": erreur 202 si SP < N }
 StackCheckAddr:=CodeSize;
 Emit($5B); Emit($2E); Emit2($8B,$07); Emit2($83,$C3); Emit(2); Emit($53); { pop bx; mov ax,cs:[bx]; add bx,2; push bx }
 Emit2($39,$C4); Emit2($73,3); P:=Jump; Emit($C3);                      { cmp sp,ax; jae ok; jmp err; ok: ret }
 PatchJump(P,CodeSize); LoadImmediate(202); JumpTo(RuntimeError);
 For P:=1 To 17 Do Emit($90);
 EmitStandardRuntime;
 { EmitStandardRuntime remet la table a zero: inscrire ces entrees apres. }
 RuntimeStandard[70]:=LoadDSAddr; RuntimeStandard[71]:=LoadESAddr; RuntimeStandard[72]:=StackCheckAddr;
 { WriteBegin [73]: laisse 3 mots de contexte sur la pile de l'appelant }
 RuntimeStandard[73]:=CodeSize; Emit($5B);
 Emit($B8); DataAddress(StandardOutputAddress); Emit2($8C,$DA); CallTo(RuntimeStandard[49]); Emit($52); Emit($50);
 Emit($A1); DataAddress(StandardOutputAddress); CallTo(RuntimeStandard[40]); Emit($50);
 Emit($53); Emit($C3);
 { WriteEnd [74] / WriteLnEnd [75]: CR LF puis restauration du contexte }
 RuntimeStandard[75]:=CodeSize; Emit($5B);
 LoadImmediate(13); CallTo(RuntimeChar); LoadImmediate(10); CallTo(RuntimeChar); Emit($53);
 RuntimeStandard[74]:=CodeSize; Emit($5B);
 Emit($58); CallTo(RuntimeStandard[40]); Emit($58); Emit($5A); CallTo(RuntimeStandard[49]);
 Emit($53); Emit($C3);
 { ReadBegin [76], ReadEnd [77], ReadLnEnd [78] }
 RuntimeStandard[76]:=CodeSize; Emit($5B);
 Emit($B8); DataAddress(StandardInputAddress); Emit2($8C,$DA); CallTo(RuntimeStandard[41]); Emit($52); Emit($50);
 Emit($53); Emit($C3);
 RuntimeStandard[78]:=CodeSize; Emit($5B); CallTo(RuntimeStandard[22]); Emit($53);
 RuntimeStandard[77]:=CodeSize; Emit($5B);
 Emit($58); Emit($5A); CallTo(RuntimeStandard[41]); Emit($53); Emit($C3);
 { StringArg [79] / BlockArg [80]: copie DX:AX dans N octets reserves sur la pile;
   mots apres l'appel: N puis capacite (chaine) ou taille (bloc). }
 RuntimeStandard[79]:=CodeSize; Emit($5B); Emit2($89,$C6);            { pop bx; mov si,ax }
 Emit($2E); Emit2($8B,$07); Emit2($29,$C4); Emit2($89,$E7);          { mov ax,cs:[bx]; sub sp,ax; mov di,sp }
 Emit($2E); Emit2($8B,$4F); Emit(2); Emit2($83,$C3); Emit(4); Emit($53); { mov cx,cs:[bx+2]; add bx,4; push bx }
 Emit($1E); Emit($06); Emit($16); Emit($07); Emit2($8E,$DA);         { push ds; push es; es=ss; ds=dx }
 Emit2($31,$C0); Emit($AC); Emit2($39,$C8); Emit2($76,$02); Emit2($89,$C8); Emit($AA); Emit2($89,$C1);
 Emit2($F3,$A4); Emit($07); Emit($1F); Emit($C3);
 { StringAssign [81]: ES:DI := chaine DX:AX tronquee a la capacite (mot apres l'appel) }
 RuntimeStandard[81]:=CodeSize; Emit($5B); Emit($2E); Emit2($8B,$0F); Emit2($83,$C3); Emit(2); Emit($53);
 Emit($1E); Emit2($8E,$DA); Emit2($89,$C6);
 Emit2($31,$C0); Emit($AC); Emit2($39,$C8); Emit2($76,$02); Emit2($89,$C8); Emit($AA); Emit2($89,$C1);
 Emit2($F3,$A4); Emit($1F); Emit($C3);
 RuntimeStandard[80]:=CodeSize; Emit($5B); Emit2($89,$C6);
 Emit($2E); Emit2($8B,$07); Emit2($29,$C4); Emit2($89,$E7);
 Emit($2E); Emit2($8B,$4F); Emit(2); Emit2($83,$C3); Emit(4); Emit($53);
 Emit($1E); Emit($06); Emit($16); Emit($07); Emit2($8E,$DA);
 Emit2($F3,$A4); Emit($07); Emit($1F); Emit($C3);
 PatchJump(BufferedCharPatch,RuntimeStandard[50]);
 PatchJump(BufferedHaltPatch,RuntimeStandard[55]);
 EmitRuntimeError;
End;

Procedure CompileProgram;
Var
 I: Word;
Begin
 CodeSize:=0; DataSize:=0; BssTop:=65536; SymbolCount:=0; FixupCount:=0;
 DebugCount:=0; DebugCaptured:=[]; RealReady:=False; EmulatorReady:=False;
 RealCodeBase:=0; RealCodeEnd:=0; RealDataBase:=0; RealDataEnd:=0;
 EmulatorCodeBase:=0; EmulatorCodeEnd:=0; EmulatorDataBase:=0; EmulatorDataEnd:=0;
 FillChar(UnitFeatures,SizeOf(UnitFeatures),0);
 OverlaySelected:=[];
 InitTypes; ScopeCount:=0; CurrentScope:=0; FillChar(Dictionary,SizeOf(Dictionary),0);
 FillChar(Scopes,SizeOf(Scopes),0);
 RelativeCount:=0; UnitOutput:=False;
 NativeNeeded:=False; NativeRefCount:=0; RelocationCount:=0; NativeInitCount:=0;
 HeapNeeded:=False;
 ObjectCount:=0; ObjectCallCount:=0; ObjectSegmentCount:=0;
 ObjectGroupCount:=0; ObjectPublicCount:=0; ObjectExternalCount:=0; ObjectFixupCount:=0;
 DataFixupCount:=0; ExprLiteral:=False; LoopDepth:=0; LoopJumpCount:=0; LabelJumpCount:=0;
 UnitCount:=0; InitCount:=0; CurrentUnit:=0; Imports:=[]; ImportCount:=0;
 InInterface:=False;
  InstallStandardTypes;
 { DS := segment de donnees (relocalise), PrefixSeg := ES (PSP), ES := DS }
 Emit($B8); AddSegmentRelocation(CodeSize,3); EmitWord(0); Emit2($8E,$D8);
 Emit2($8C,$06); DataAddress(PrefixSeg); Emit2($8E,$C0); Emit($FC);
 { Mise a zero de la fin du segment de donnees non stockee dans l'EXE
   (mov di,N; mov cx,M; xor ax,ax; rep stosb), valeurs fixees par WriteExecutable. }
 BssPatch:=CodeSize; Emit($BF); EmitWord(0); Emit($B9); EmitWord(0); Emit2($31,$C0); Emit2($F3,$AA);
 FPUStartup:=CodeSize; Emit($90); Emit($90); Emit($90);
 EntryFixup:=Jump;
 DataSegVar:=CodeSize; AddSegmentRelocation(CodeSize,3); EmitWord(0);
 EmitRuntime;
 { InOutRes partage l'emplacement de l'erreur d'E/S du runtime. }
 For I:=1 To SymbolCount Do If (Symbols[I].Owner=255) And (Symbols[I].Name='INOUTRES') Then Symbols[I].Addr:=InputError;
 NextToken;
 If Token=tkUnit Then Begin
  NextToken;
  If Token<>tkIdent Then Fail(2,'Nom d''unite attendu');
  UnitCount:=1; FillChar(Units[1],SizeOf(TBuildUnit),0);
  Units[1].Name:=TokenText; Units[1].State:=1;
  CompileSourceUnit(1,MainSourceName); UnitOutput:=True; Exit;
 End;
 If Token=tkProgram Then Begin
  NextToken; Need(tkIdent);
  If Token=tkLP Then Begin
   NextToken; Need(tkIdent);
   While Token=tkComma Do Begin
    NextToken; Need(tkIdent)
   End;
   Need(tkRP);
  End;
  Need(tkSemi);
 End;
 ImportLibrarySystem;
 UsesClause;
 DeclarationPart;
  For I:=1 To SymbolCount Do If (Symbols[I].Owner=0) And (Symbols[I].Scope=0) And
    (Symbols[I].Kind=skProc) And Not Symbols[I].HasBody Then Fail(59,Symbols[I].Name);
 MainEntry:=CodeSize;
 PatchJump(EntryFixup,CodeSize);
 For I:=1 To InitCount Do CallTo(Units[InitOrder[I]].InitAddress);
 Need(tkBegin); StatementList(tkEnd); Need(tkEnd);
 If Token<>tkDot Then Need(tkDot);
 { Comme TP, tout ce qui suit "END." est ignore. }
 LoadImmediate(0); CallTo(RuntimeHalt); CheckLabels(0);
 ReportSource;
End;

Procedure LoadSource;
Var
 F: File;
 N: Word;
 E: Integer;
Begin
 If (SourceName<>'') And (SourceName[1]='<') Then Begin
  LoadEmbeddedSource(Copy(SourceName,2,Length(SourceName)-2)); Exit;
 End;
 Assign(F,SourceName); OpenBinaryRead(F,E);
 If E<>0 Then Fail(15,'Fichier introuvable: '+SourceName);
 SourceSize:=FileSize(F);
 If SourceSize>MaxSource Then Begin
  Close(F); Fail(48,'source > 256 Ko')
 End;
 E:=ReadWhole(F); {$I-} Close(F); If IOResult<>0 Then E:=1; {$I+}
 If E<>0 Then Fail(15,'Lecture du source impossible');
 SourcePos:=1; Line:=1; Column:=1; CondDepth:=0; Active:=True;
End;

Procedure LinkedWord(P: Longint; W: Word);
Begin
 If (P<0) Or (P+2>LinkedSize) Then Fail(72,'Fixup hors image liee');
 LinkedImage^[P]:=W And 255; LinkedImage^[P+1]:=W Shr 8;
End;

Procedure LinkedRelocation(P: Longint);
Var I: Word;
Begin
 If (P<0) Or (P+2>LinkedSize) Then Fail(72,'Relocalisation hors image liee');
 For I:=1 To RelocationCount Do
  If Longint(Relocations[I].Segm)*16+Relocations[I].Offs=P Then
   Fail(72,'Relocalisation MZ dupliquee');
 If RelocationCount=MaxNativeRefs Then Unsupported('trop de relocalisations MZ');
 Inc(RelocationCount); Relocations[RelocationCount].Segm:=P Div 16;
 Relocations[RelocationCount].Offs:=P Mod 16;
End;

Procedure LoadObjects;
Var I,J: Word; Q: Longint; Duplicate: Boolean;
Begin
 For I:=1 To ObjectCount Do Begin
  Duplicate:=False;
  For J:=1 To I-1 Do If ObjectFiles[J].Length=ObjectFiles[I].Length Then Begin
   Q:=0;
   While (Q<ObjectFiles[I].Length) And
     (ObjectFiles[J].Bytes^[Q]=ObjectFiles[I].Bytes^[Q]) Do Inc(Q);
   If Q=ObjectFiles[I].Length Then Duplicate:=True;
  End;
  If Not Duplicate Then ReadObject(ObjectFiles[I].Path,ObjectFiles[I].Bytes,ObjectFiles[I].Length);
 End;
End;

Procedure LinkObjects;
Var
 I,J,R,G,Pub: Word; P,T,Frame,Value,Addend,Width,Limit: Longint;
 SegmentGroups: Array[1..MaxObjSegments] Of Word;
 Placed: Array[1..MaxObjSegments] Of Boolean;
 ExternalPublics: Array[1..MaxObjNames] Of Word;
 F: TObjectFixup;

Function Aligned(N: Longint; Alignment: Byte): Longint;
Var A: Longint;
Begin
 A:=1;
 Case Alignment Of 2:A:=2; 3:A:=16; 4:A:=256 End;
 Aligned:=(N+A-1) And Not (A-1);
End;
Function FindPublic(Name: TShortString): Word;
Var K: Word;
Begin
 FindPublic:=0;
 For K:=1 To ObjectPublicCount Do If ObjectPublics[K].Name=Name Then Begin
  FindPublic:=K; Exit;
 End;
 Fail(59,'Symbole OBJ non resolu: '+Name);
End;
Function PublicAddress(K: Word): Longint;
Begin
 PublicAddress:=ObjectSegments[ObjectPublics[K].Segment].Base+ObjectPublics[K].Offset;
End;
Function PublicFrame(K: Word): Longint;
Var G,S: Word;
Begin
 G:=ObjectPublics[K].GroupIndex; S:=ObjectPublics[K].Segment;
 If G<>0 Then PublicFrame:=ObjectGroups[G].Base
 Else PublicFrame:=ObjectSegments[ObjectSegments[S].Root].Base And Not Longint(15);
End;
Function TargetAddress(Method: Byte; Index: Word): Longint;
Begin
 Case Method Of
  0:TargetAddress:=ObjectSegments[Index].Base;
  1:TargetAddress:=ObjectGroups[Index].Base;
  2:TargetAddress:=PublicAddress(ExternalPublics[Index]);
 Else Fail(72,'Methode target OBJ invalide'); TargetAddress:=0;
 End;
End;
Function TargetFrame(Method: Byte; Index: Word): Longint;
Begin
 Case Method Of
  0:TargetFrame:=ObjectSegments[ObjectSegments[Index].Root].Base And Not Longint(15);
  1:TargetFrame:=ObjectGroups[Index].Base;
  2:TargetFrame:=PublicFrame(ExternalPublics[Index]);
 Else Fail(72,'Methode frame OBJ invalide'); TargetFrame:=0;
 End;
End;
Procedure PlaceSegment(S: Word);
Begin
 If Placed[S] Then Exit;
 LinkedSize:=Aligned(LinkedSize,ObjectSegments[S].Alignment);
 { Hors groupe, donner une base en paragraphes. Dans un groupe, respecter
   l'alignement declare sans introduire de trous supplementaires. }
 If SegmentGroups[S]=0 Then LinkedSize:=Align16(LinkedSize);
 ObjectSegments[S].Base:=LinkedSize;
 Inc(LinkedSize,ObjectSegments[S].Length);
 If LinkedSize>MaxLinkedImage Then Fail(49,'Image MZ multi-segments trop grande');
 Placed[S]:=True;
End;
Begin
 FillChar(SegmentGroups,SizeOf(SegmentGroups),0);
 FillChar(Placed,SizeOf(Placed),0);
 { PUBLIC/STACK concatene les contributions de meme nom et classe.
   COMMON les superpose. PRIVATE conserve une identite propre. }
 For I:=1 To ObjectSegmentCount Do Begin
  R:=I;
  If ObjectSegments[I].Combine<>0 Then
   For J:=1 To I-1 Do
    If (ObjectSegments[J].Root=J) And
       (ObjectSegments[J].Combine<>0) And
       (ObjectSegments[J].Name=ObjectSegments[I].Name) And
       (ObjectSegments[J].ClassName=ObjectSegments[I].ClassName) Then Begin
     If ObjectSegments[J].Combine<>ObjectSegments[I].Combine Then
      Fail(72,'Combinaisons SEGDEF incompatibles');
     R:=J; Break;
    End;
  ObjectSegments[I].Root:=R;
  If R<>I Then Begin
   If ObjectSegments[I].Combine=6 Then Begin
    If ObjectSegments[I].Length>ObjectSegments[R].Length Then
     ObjectSegments[R].Length:=ObjectSegments[I].Length;
   End Else Begin
    ObjectSegments[I].Contribution:=Aligned(ObjectSegments[R].Length,ObjectSegments[I].Alignment);
    ObjectSegments[R].Length:=ObjectSegments[I].Contribution+ObjectSegments[I].Length;
   End;
   If ObjectSegments[I].Alignment>ObjectSegments[R].Alignment Then
    ObjectSegments[R].Alignment:=ObjectSegments[I].Alignment;
  End;
  If ObjectSegments[R].Length>65536 Then Fail(48,'Segment OBJ combine > 64 Ko');
 End;
 For G:=1 To ObjectGroupCount Do
  For J:=1 To ObjectGroups[G].Count Do Begin
   R:=ObjectSegments[ObjectGroups[G].Members[J]].Root;
   If (SegmentGroups[R]<>0) And (SegmentGroups[R]<>G) Then
    Fail(72,'Segment OBJ dans plusieurs groupes');
   SegmentGroups[R]:=G;
  End;
 For G:=1 To ObjectGroupCount Do Begin
  LinkedSize:=Align16(LinkedSize); ObjectGroups[G].Base:=LinkedSize;
  For J:=1 To ObjectGroups[G].Count Do PlaceSegment(ObjectSegments[ObjectGroups[G].Members[J]].Root);
  If LinkedSize-ObjectGroups[G].Base>65536 Then Fail(49,'Groupe OBJ > 64 Ko');
 End;
 For I:=1 To ObjectSegmentCount Do If ObjectSegments[I].Root=I Then PlaceSegment(I);
 For I:=1 To ObjectSegmentCount Do Begin
  R:=ObjectSegments[I].Root;
  If R<>I Then ObjectSegments[I].Base:=ObjectSegments[R].Base+ObjectSegments[I].Contribution;
  { La longueur de la racine inclut des contributions suivantes, mais son
    tampon ne contient que sa propre contribution. La copie suivante des
    autres contributions remplit ces zones initialement nulles. }
  Move(ObjectSegments[I].Bytes^,LinkedImage^[ObjectSegments[I].Base],ObjectSegments[I].Length);
 End;
 For I:=1 To ObjectPublicCount Do Begin
  G:=ObjectPublics[I].GroupIndex;
  If (G<>0) And (SegmentGroups[ObjectSegments[ObjectPublics[I].Segment].Root]<>G) Then
   Fail(72,'PUBDEF hors GRPDEF');
 End;
 For I:=1 To ObjectExternalCount Do ExternalPublics[I]:=FindPublic(ObjectExternals[I]);
 For I:=1 To ObjectCallCount Do Begin
  Pub:=FindPublic(ObjectCalls[I].Name); P:=ObjectCalls[I].Position;
  Frame:=PublicFrame(Pub); T:=PublicAddress(Pub)-Frame;
  If (T<0) Or (T>65535) Then Fail(48,'Entree OBJ hors segment');
  LinkedWord(P,T); LinkedWord(P+2,Frame Div 16); LinkedRelocation(P+2);
 End;
 For I:=1 To ObjectFixupCount Do Begin
  F:=ObjectFixups[I]; P:=ObjectSegments[F.Segment].Base+F.Offset;
  T:=TargetAddress(F.TargetMethod,F.TargetIndex)+F.Displacement;
  Case F.FrameMethod Of
   0,1,2:Frame:=TargetFrame(F.FrameMethod,F.FrameIndex);
   4:Frame:=TargetFrame(0,F.Segment);
   5:Frame:=TargetFrame(F.TargetMethod,F.TargetIndex);
  Else Fail(72,'Frame OBJ invalide');
  End;
  Width:=2; If F.Location=0 Then Width:=1;
  Addend:=LinkedImage^[P];
  If Width=2 Then Addend:=Addend+Longint(LinkedImage^[P+1])*256;
  If F.Relative Then Begin
   { Une reference near doit rester dans le meme espace CS de 64 Ko. }
   Limit:=TargetFrame(0,F.Segment);
   If (T<Limit) Or (T>=Limit+65536) Then Fail(48,'FIXUPP near inter-segments');
   If Width=1 Then Begin If Addend>=128 Then Dec(Addend,256) End
   Else If Addend>=32768 Then Dec(Addend,65536);
   Value:=T-P-Width+Addend;
   If (Width=1) And ((Value<-128) Or (Value>127)) Then Fail(48,'FIXUPP relatif byte hors portee');
  End Else Value:=T-Frame+Addend;
  If F.Location<>2 Then Begin
   If Not F.Relative And ((Value<0) Or (Value>65535)) Then Fail(49,'Offset FIXUPP hors frame');
   If Width=1 Then LinkedImage^[P]:=Byte(Value) Else LinkedWord(P,Word(Value));
  End;
  If F.Location In [2,3] Then Begin
   If F.Location=3 Then Inc(P,2);
   Addend:=LinkedImage^[P]+Longint(LinkedImage^[P+1])*256;
   Value:=Frame Div 16+Addend;
   If Value>65535 Then Fail(49,'Segment FIXUPP trop grand');
   LinkedWord(P,Value); LinkedRelocation(P);
  End;
 End;
 For I:=1 To ObjectSegmentCount Do Dispose(ObjectSegments[I].Bytes);
 For I:=1 To ObjectCount Do Dispose(ObjectFiles[I].Bytes);
End;

Procedure PrepareOverlays;
Var I,J,OldRefs,Target,ThunkCount,MinAddr,MaxAddr,Chunks,Total,Row: Word; U: Byte;
 Thunks: Array[1..MaxSymbols] Of Record Target,Address: Word End;
 D: DirStr; N: NameStr; E: ExtStr; Name: TShortString; Inside: Boolean;
Procedure SetDataWord(P,V: Word);
Begin Data[P]:=V And 255; Data[P+1]:=V Shr 8 End;
Function ThunkFor(Address: Word; Owner: Byte): Word;
Var K,Position: Word;
Begin
 For K:=1 To ThunkCount Do If Thunks[K].Target=Address Then Begin ThunkFor:=Thunks[K].Address; Exit End;
 If ThunkCount=MaxSymbols Then Fail(123,'Trop de ponts overlay');
 Position:=CodeSize; Emit($50); LoadImmediate(Owner); CallTo(RuntimeStandard[57]); Emit($58); JumpTo(Address);
 Inc(ThunkCount); Thunks[ThunkCount].Target:=Address; Thunks[ThunkCount].Address:=Position; ThunkFor:=Position;
End;
Begin
 If OverlaySelected=[] Then Exit;
 FSplit(MainSourceName,D,N,E); Name:=N+'.OVR';
 For I:=1 To Length(Name) Do Data[OverlayFileName+I-1]:=Ord(Name[I]);
 Data[OverlayFileName+Length(Name)]:=0;
 Total:=0; J:=0;
 For U:=1 To UnitCount Do If U In OverlaySelected Then Begin
  Inc(J); MinAddr:=CodeSize; MaxAddr:=0; Chunks:=0; Inside:=False;
  For I:=0 To CodeSize-1 Do Begin
   If CodeOwners[I]=U Then Begin
    If Not Inside Then Inc(Chunks); Inside:=True;
    If I<MinAddr Then MinAddr:=I; MaxAddr:=I+1; Inc(Total);
   End Else Inside:=False;
  End;
  If MaxAddr=0 Then MinAddr:=0;
  Row:=OverlayTable+Word(U)*16;
  SetDataWord(Row+6,1); SetDataWord(Row+8,MinAddr); SetDataWord(Row+10,MaxAddr); SetDataWord(Row+14,Chunks);
 End;
 SetDataWord(OverlayBufferSize,Total); SetDataWord(OverlayBankCount,J);
 ThunkCount:=0; OldRefs:=RelativeCount;
 For I:=1 To OldRefs Do Begin
  Target:=RelativeFixups[I].Target;
  If Target<CodeSize Then Begin
   U:=CodeOwners[Target];
   If (U In OverlaySelected) And (CodeOwners[RelativeFixups[I].Position]<>U) Then
    PatchJump(RelativeFixups[I].Position,ThunkFor(Target,U));
  End;
 End;
End;

Procedure WriteOverlayFile(ExePath: TShortString);
Var B: PBinaryBuffer; F: File; Path: TShortString; Position,Start,At,Last,RelocAt,ChunkStart: Longint;
 I,J,Row,Chunks,RelocCount,Checksum,Written: Word; U: Byte; Error: Integer;
Procedure PutByte(Value: Byte);
Begin If Position>=SizeOf(TBinaryBuffer) Then Fail(49,'Fichier OVR trop grand'); B^[Position]:=Value; Inc(Position) End;
Procedure PutWord(Value: Word);
Begin PutByte(Value And 255); PutByte(Value Shr 8) End;
Procedure SetRuntimeWord(P,Value: Word);
Begin
 Data[P]:=Value And 255; Data[P+1]:=Value Shr 8;
 LinkedImage^[LinkedDataBase+P]:=Value And 255; LinkedImage^[LinkedDataBase+P+1]:=Value Shr 8;
End;
Begin
 If OverlaySelected=[] Then Exit;
 New(B); Position:=0; Path:=Copy(ExePath,1,Length(ExePath)-4)+'.OVR';
 PutWord($5054); PutWord($4F43); PutWord($5256); PutWord($2131); PutWord(1);
 PutWord(Data[OverlayBankCount]+Word(Data[OverlayBankCount+1])*256);
 For U:=1 To UnitCount Do If U In OverlaySelected Then Begin
  Row:=OverlayTable+Word(U)*16; Start:=Position;
  SetRuntimeWord(Row+2,Word(Start)); SetRuntimeWord(Row+4,Word(Start Shr 16));
  Chunks:=Data[Row+14]+Word(Data[Row+15])*256; PutWord(Chunks); At:=0;
  While At<CodeSize Do Begin
   If CodeOwners[At]<>U Then Begin Inc(At); Continue End;
   Last:=At+1; While (Last<CodeSize) And (CodeOwners[Last]=U) Do Inc(Last);
   RelocCount:=0;
   For I:=1 To RelocationCount Do Begin
    RelocAt:=Longint(Relocations[I].Segm)*16+Relocations[I].Offs;
    If (RelocAt>=At) And (RelocAt<Last) Then Begin
     If RelocAt+2>Last Then Fail(72,'Relocalisation overlay hors region'); Inc(RelocCount);
    End;
   End;
   ChunkStart:=At; PutWord(At); PutWord(Last-At); PutWord(RelocCount);
   While At<Last Do Begin PutByte(LinkedImage^[At]); Inc(At) End;
   For I:=1 To RelocationCount Do Begin
    RelocAt:=Longint(Relocations[I].Segm)*16+Relocations[I].Offs;
    If (RelocAt>=ChunkStart) And (RelocAt<Last) Then PutWord(RelocAt-ChunkStart);
   End;
  End;
  Checksum:=0;
  For At:=Start To Position-1 Do Checksum:=((Checksum Shl 1) Or (Checksum Shr 15))+B^[At];
  SetRuntimeWord(Row+12,Checksum);
 End;
 Assign(F,Path); {$I-} Rewrite(F,1); Error:=IOResult;
 If Error=0 Then Begin
  At:=0;
  While At<Position Do Begin
   J:=32768; If Position-At<J Then J:=Position-At;
   BlockWrite(F,B^[At],J,Written); If (IOResult<>0) Or (Written<>J) Then Begin Error:=1; Break End;
   Inc(At,J);
  End;
  Close(F); If IOResult<>0 Then Error:=1;
 End;
 {$I+} Dispose(B); If Error<>0 Then Fail(16,'Ecriture OVR impossible');
 For At:=0 To CodeSize-1 Do If CodeOwners[At] In OverlaySelected Then LinkedImage^[At]:=0;
End;

Function Hex4(Value: Word): String;
Const Digits: String[16]='0123456789ABCDEF';
Var S: String[4]; K: Byte;
Begin S:='0000'; For K:=4 Downto 1 Do Begin S[K]:=Digits[(Value And 15)+1]; Value:=Value Shr 4 End; Hex4:=S End;

Procedure WriteDebugArtifacts(ExePath: TShortString; ResidentSize: Longint; StackSegment,NativeSegment: Word);
Var MapFile: Text; F: File; B: PBinaryBuffer; P,I,Count,Addr,Bytes: Word; E: Integer;
 U: Byte; MapPath: TShortString;
Procedure PutByte(V: Byte);
Begin If P=MaxImage Then Fail(123,'Debug >60000 octets'); B^[P]:=V; Inc(P) End;
Procedure PutWord(V: Word);
Begin PutByte(V And 255); PutByte(V Shr 8) End;
Procedure PutString(S: TShortString);
Var J: Word;
Begin PutByte(Length(S)); For J:=1 To Length(S) Do PutByte(Ord(S[J])) End;
Begin
 CaptureDebugSymbols(0); For U:=1 To UnitCount Do CaptureDebugSymbols(U);
 If LookupRequested Then Begin
  I:=0;
  For Count:=1 To DebugCount Do If (DebugEntries[Count].Kind=0) And
     (DebugEntries[Count].Address<=LookupAddress) Then
    If (I=0) Or (DebugEntries[Count].Address>=DebugEntries[I].Address) Then I:=Count;
  If (I=0) Or (LookupAddress>=CodeSize) Then WriteLn('TPC: aucune ligne source pour /F ',Hex4(LookupAddress Div 16),':',Hex4(LookupAddress Mod 16))
  Else With DebugEntries[I] Do WriteLn('TPC: /F -> ',FileName,'(',Line,',',Column,')');
 End;
 MapPath:=Copy(ExePath,1,Length(ExePath)-4)+'.MAP';
 If MapMode<>0 Then Begin
  Assign(MapFile,MapPath); {$I-} Rewrite(MapFile); E:=IOResult; {$I+}
  If E<>0 Then Fail(16,'Creation MAP impossible');
  {$I-}
  WriteLn(MapFile,'TPC local map 7; addresses relative to MZ load segment');
  WriteLn(MapFile,'Start       Length       Name                 Class');
  WriteLn(MapFile,'0000:0000  ',CodeSize:10,'  TPC_CODE             CODE');
  WriteLn(MapFile,Hex4(Align16(CodeSize) Div 16),':0000  ',DataSize+BssSize:10,'  TPC_DATA             DATA');
  If NativeNeeded Then WriteLn(MapFile,Hex4(NativeSegment),':0000  ',NativeDataSize:10,'  BORLAND_DATA         DATA');
  For I:=1 To ObjectSegmentCount Do If ObjectSegments[I].Root=I Then
   WriteLn(MapFile,Hex4(ObjectSegments[I].Base Div 16),':',Hex4(ObjectSegments[I].Base Mod 16),'  ',ObjectSegments[I].Length:10,'  ',ObjectSegments[I].Name,'  ',ObjectSegments[I].ClassName);
  WriteLn(MapFile,Hex4(StackSegment),':0000  ',StackSize:10,'  TPC_STACK            STACK');
  If MapMode>=2 Then Begin
   WriteLn(MapFile); WriteLn(MapFile,'Address    Publics');
   For I:=1 To DebugCount Do If DebugEntries[I].Kind In [1,2] Then Begin
    Addr:=DebugEntries[I].Address;
    If DebugEntries[I].Kind=2 Then WriteLn(MapFile,Hex4(Align16(CodeSize) Div 16),':',Hex4(FinalDataAddress(Addr)),'  ',DebugEntries[I].Name)
    Else WriteLn(MapFile,'0000:',Hex4(Addr),'  ',DebugEntries[I].Name);
   End;
  End;
  If MapMode=3 Then Begin
   WriteLn(MapFile); WriteLn(MapFile,'Address    Line:Column  Source');
   For I:=1 To DebugCount Do If DebugEntries[I].Kind=0 Then With DebugEntries[I] Do
    WriteLn(MapFile,'0000:',Hex4(Address),'  ',Line,':',Column,'  ',FileName);
   WriteLn(MapFile); WriteLn(MapFile,'Frame offset  Size  Locals');
   For I:=1 To DebugCount Do If DebugEntries[I].Kind=3 Then With DebugEntries[I] Do
    WriteLn(MapFile,SmallInt(Address):12,'  ',Size:4,'  ',Name);
  End;
  E:=IOResult; Close(MapFile); If IOResult<>0 Then E:=1; {$I+}
  If E<>0 Then Fail(16,'Ecriture MAP impossible');
 End;
 If Not DebugInExe Then Exit;
 New(B); P:=0;
 PutString('TPCDBG7'); { huit octets: 7 suivi de TPCDBG7 }
 PutWord(7); PutWord(DebugCount); PutWord(Word(ResidentSize)); PutWord(Word(ResidentSize Shr 16));
 For I:=1 To DebugCount Do With DebugEntries[I] Do Begin
  PutByte(Kind); PutByte(U); Addr:=Address;
  PutWord(Addr); PutWord(Line); PutWord(Column); PutWord(Size); PutString(FileName); PutString(Name);
 End;
 Bytes:=P; E:=0;
 If DebugInExe Then Begin
  Assign(F,ExePath); {$I-} Reset(F,1); E:=IOResult;
  If E=0 Then Begin Seek(F,FileSize(F)); BlockWrite(F,B^,Bytes,Count); If IOResult<>0 Then E:=1; If Count<>Bytes Then E:=1; Close(F); If IOResult<>0 Then E:=1 End;
  {$I+} If E<>0 Then Fail(16,'Debug EXE impossible');
 End;
 Dispose(B);
End;

Procedure WriteExecutable;
Var
 H: Array[0..15] Of Word;
 F: File;
 Size, FullSize, AllocParas, HeaderBytes, Location, Written, Chunk: Longint;
 I, Base, StackSeg, Pad, N, DataParas, StoredData, TotalData: Word;
 E: Integer;
 Path: TShortString;
 NativeSegment: Word;
 Padding: Array[0..15] Of Byte;
 D: DirStr;
 Name: NameStr;
 Ext: ExtStr;
Begin
 Base:=CodeSize;
 For I:=0 To UnitCount Do If UnitFeatures[I] And 1<>0 Then Begin
  Image[FPUStartup]:=$9B; Image[FPUStartup+1]:=$DB; Image[FPUStartup+2]:=$E3;
 End;
 If HeapNeeded And NativeNeeded Then Unsupported('heap DOS local avec runtime Borland actif');
 Data[HeapLimit]:=MaxHeap And 255; Data[HeapLimit+1]:=MaxHeap Shr 8;
 If CodeSize>65520 Then Fail(48,'Segment de code > 65520 octets');
 If Longint(DataSize)+BssSize>65520 Then Fail(49,'Segment de donnees > 65520 octets');
 TotalData:=DataSize+BssSize;
 { Pointeurs constants vers des variables globales: adresse finale. }
 For I:=1 To DataFixupCount Do Begin
  N:=Data[DataFixups[I]]+Word(Data[DataFixups[I]+1])*256; N:=FinalDataAddress(N);
  Data[DataFixups[I]]:=N And 255; Data[DataFixups[I]+1]:=N Shr 8;
 End;
 { Le code est en CS:0000 et les donnees dans leur propre segment, place au
   paragraphe suivant la fin du code (comme TP: CS puis DS puis pile). }
 LinkedDataBase:=Align16(CodeSize); DataParas:=LinkedDataBase Div 16;
 { Comme TP, seules les donnees initialisees sont stockees dans l'EXE: la
   fin nulle du segment de donnees est reservee par e_minalloc et remise a
   zero par le code de demarrage. }
 StoredData:=DataSize;
 If Not NativeNeeded And (ObjectCount=0) Then Begin
  While (StoredData>0) And (Data[StoredData-1]=0) Do Dec(StoredData);
  For I:=1 To DataFixupCount Do
   If Longint(DataFixups[I])+4>StoredData Then StoredData:=DataFixups[I]+4;
  If Odd(StoredData) Then Inc(StoredData);
  If StoredData>DataSize Then StoredData:=DataSize;
 End;
 PatchWord(BssPatch+1,StoredData); PatchWord(BssPatch+4,TotalData-StoredData);
 FullSize:=LinkedDataBase+TotalData;
 Size:=LinkedDataBase+StoredData;
 New(LinkedImage); FillChar(LinkedImage^,SizeOf(TLinkedImage),0);
 For I:=1 To FixupCount Do    PatchWord(Fixups[I].Position,FinalDataAddress(Fixups[I].DataOffset));
 For I:=1 To DataFixupCount Do Begin
  { Constante typee PChar: le segment est relocalise par la table MZ. }
  If RelocationCount=MaxNativeRefs Then Unsupported('trop de relocalisations MZ');
  Inc(RelocationCount); Relocations[RelocationCount].Segm:=DataParas;
  Relocations[RelocationCount].Offs:=DataFixups[I]+2; RelocationKinds[RelocationCount]:=2;
 End;
 Move(Image,LinkedImage^,CodeSize);
 If StoredData<>0 Then Move(Data,LinkedImage^[LinkedDataBase],StoredData);
 NativeSegment:=0;
 If NativeNeeded Then Begin
  NativeSegment:=Align16(Size) Div 16;
  Size:=Longint(NativeSegment)*16+NativeDataSize;
  Move(NativeData,LinkedImage^[Longint(NativeSegment)*16],NativeDataSize);
 End;
 LinkedSize:=Size;
 For I:=1 To RelocationCount Do Begin
  If Relocations[I].Segm=$FFFF Then Relocations[I].Segm:=NativeSegment;
  Location:=Longint(Relocations[I].Segm)*16+Relocations[I].Offs;
  If Location+2>Size Then Fail(72,'Relocalisation MZ hors image');
  Case RelocationKinds[I] Of
   1:LinkedWord(Location,NativeSegment);
   2,3:LinkedWord(Location,DataParas);
  Else LinkedWord(Location,0);
  End;
 End;
 LinkedSize:=Size; LinkObjects; Size:=LinkedSize;
 If FullSize<Size Then FullSize:=Size;
 StackSeg:=(FullSize+15) Div 16;
 Pad:=StackSeg*16-Size;
  { Pile non stockee dans le fichier: e_minalloc la reserve a la charge. }
 AllocParas:=(Longint(StackSize)+Pad+15) Div 16;
 FillChar(H,SizeOf(H),0);
 HeaderBytes:=Align16(32+Longint(RelocationCount)*4);
 H[0]:=$5A4D; H[1]:=(Size+HeaderBytes) Mod 512; H[2]:=(Size+HeaderBytes+511) Div 512;
 H[3]:=RelocationCount; H[4]:=HeaderBytes Div 16; H[5]:=AllocParas+MinHeap;
 If AllocParas+MaxHeap>65535 Then H[6]:=$FFFF
                             Else H[6]:=AllocParas+MaxHeap;
 If HeapNeeded Then H[6]:=H[5]; { laisser DOS reserver les blocs demandes par GetMem }
 H[7]:=StackSeg;
 H[8]:=StackSize; H[12]:=32;
 FSplit(SourceName,D,Name,Ext);
 If OutputDir='' Then Path:=D+Name+'.EXE' Else Path:=JoinPath(OutputDir,Name+'.EXE');
 If Upper(Path)=Upper(SourceName) Then CLIError('Sortie identique au source');
 WriteOverlayFile(Path);
 Assign(F,Path); {$I-} Rewrite(F,1); E:=IOResult; {$I+}
 If E<>0 Then Fail(16,'Creation impossible: '+Path);
  {$I-}
 BlockWrite(F,H,32,N); E:=IOResult; If N<>32 Then E:=1;
 If (E=0) And (RelocationCount<>0) Then Begin
  BlockWrite(F,Relocations,RelocationCount*4,N); E:=IOResult;
  If N<>RelocationCount*4 Then E:=1;
 End;
 Pad:=HeaderBytes-32-RelocationCount*4; FillChar(Padding,SizeOf(Padding),0);
 If (E=0) And (Pad<>0) Then Begin
  BlockWrite(F,Padding,Pad,N); E:=IOResult; If N<>Pad Then E:=1
 End;
 Written:=0;
 While (E=0) And (Written<Size) Do Begin
  Chunk:=Size-Written; If Chunk>32768 Then Chunk:=32768;
  BlockWrite(F,LinkedImage^[Written],Chunk,N); E:=IOResult;
  If N<>Chunk Then E:=1; Inc(Written,Chunk);
 End;
 Close(F); If IOResult<>0 Then E:=1;
 If E<>0 Then Begin
  Erase(F); If IOResult<>0 Then E:=1
 End;
  {$I+}
 If E<>0 Then Fail(16,'Ecriture impossible: '+Path);
 WriteDebugArtifacts(Path,Size+HeaderBytes,StackSeg,NativeSegment);
 Dispose(LinkedImage);
End;

Procedure InspectTPU;
Var
 H: TUnitHeader;
Begin
 ReadTPUHeader(InspectName,H);
 WriteLn('TPU',H.Signature[3],': en-tete=',SizeOf(H),' octets; fin dictionnaire=',H.EndTrace);
 WriteLn('Code=',H.CodeSize,' constantes=',H.ConstSize,' donnees=',H.DataSize);
 WriteLn('Fixups code=',H.CodeFixupSize,' constantes=',H.DataFixupSize);
 If (H.Flags=$8000) And (H.Reserved[0]=$5054) And (H.Reserved[1]=$3143) Then    WriteLn(
 'Profil TPC1: ABI locale near/CS=DS, non compatible Borland.')
 Else WriteLn('TPUQ Borland: appels far et donnees ordinales; ABI partielle.');
End;

Procedure InspectLibrary;
Var
 I: Word;
 H: TUnitHeader;
Begin
 ReadLibrary(InspectLibraryName);
 WriteLn('TPL: ',LibraryName,'; unites=',LibraryCount);
 For I:=1 To LibraryCount Do Begin
  H:=LibraryUnits[I].Header;
  Write(LibraryUnits[I].Name,' offset=',LibraryUnits[I].Offset,
  ' taille=',LibraryUnits[I].Size,' code=',H.CodeSize,' constantes=',H.ConstSize);
  If (H.Flags=$8000) And (H.Reserved[0]=$5054) And (H.Reserved[1]=$3143) Then      Write(
  ' profil=TPC1')
  Else If (H.CodeSize<>0) Or (H.ConstSize<>0) Or (H.DataSize<>0) Then      Write(
  ' Borland: ABI ordinale/far')
  Else Write(' TPUQ sans code');
  WriteLn;
 End;
End;

Procedure Banner;Begin
 WriteLn('Turbo Pascal  Version 7.0');
End;

Procedure Help;Begin
 { Ecran d'aide de TPC.EXE 7.0 traduit en francais, meme disposition. }
 WriteLn('Syntaxe: TPC [options] fichier [options]');
 WriteLn('  -B = Compiler toutes les unites        -L = Tampon de liaison sur disque');
 WriteLn('  -D<syms> = Definir des conditionnels   -M = Compiler les unites modifiees');
 WriteLn('  -E<chemin> = Repertoires EXE/TPU       -O<chemin> = Repertoires des objets');
 WriteLn('  -F<seg>:<ofs> = Trouver l''erreur       -Q = Compilation silencieuse');
 WriteLn('  -GD = Fichier map detaille             -T<chemin> = Repertoire TPL/CFG');
 WriteLn('  -GP = Fichier map avec publics         -U<chemin> = Repertoires des unites');
 WriteLn('  -GS = Fichier map avec segments        -V = Infos de debogage dans l''EXE');
 WriteLn('  -I<chemin> = Repertoires d''inclusion   -$<dir> = Directive du compilateur');
 WriteLn('Commutateurs du compilateur: -$<lettre><etat> (defauts indiques ci-dessous)');
 WriteLn('  A+ Alignement sur mot    I+ Controle erreurs E/S  R- Controle des bornes');
 WriteLn('  B- Eval. bool. complete  L+ Symboles debug locaux S+ Controle de pile');
 WriteLn('  D+ Infos de debogage     N- Instructions 80x87    T- Pointeurs types');
 WriteLn('  E+ Emulation 80x87       O- Overlays autorises    V+ Var-strings strictes');
 WriteLn('  F- Appels FAR forces     P- Parametres OpenString X+ Syntaxe etendue');
 WriteLn('  G- Instructions 80286    Q- Controle debordement');
 WriteLn('Tailles memoire: -$M<pile>,<tasmin>,<tasmax>  (defaut: 16384,0,655360)');
End;

Procedure ProcessArgument(S: TShortString);
Var Arg,Part: TShortString; P,ErrorCode: Integer; C: Char; AddressPart: Longint;
Begin
  If (S='--help') Or (S='/?') Or (S='-?') Or (S='-h') Or (S='/h') Then Begin
   Help; Halt(0)
  End
  Else If S='--quiet' Then Quiet:=True Else
  If Copy(S,1,14)='--inspect-tpu=' Then InspectName:=Copy(S,15,255) Else
  If Copy(S,1,14)='--inspect-tpl=' Then InspectLibraryName:=Copy(S,15,255) Else
  If (Length(S)>0) And (S[1] In ['/','-']) Then Begin
   If Length(S)<2 Then CLIError('Option vide');
   C:=UpCase(S[2]); Arg:=Copy(S,3,255);
   Case C Of
   '$':
   Begin
    If (Length(Arg)>0) And (UpCase(Arg[1])='M') Then            MemoryDirective(Copy(Arg,
    2,255))
    Else SetSwitch(Upper(Arg));
   End;
   'E':
   Begin
    If Arg='' Then CLIError('Repertoire /E manquant'); OutputDir:=Arg
   End;
   'U':
   Begin
    If Arg='' Then CLIError('Repertoire /U manquant'); UnitDirs:=Arg
   End;
   'T':
   Begin
    If Arg='' Then CLIError('Repertoire /T manquant'); TurboDirs:=Arg
   End;
   'Q':
   Begin
    If Arg<>'' Then CLIError('Option /Q incorrecte'); Quiet:=True
   End;
   'D':
   Begin
    Repeat
    P:=Pos(';',Arg);
    If P=0 Then Begin
     Part:=Arg; Arg:=''
    End
     Else
    Begin
     Part:=Copy(Arg,1,P-1); Delete(Arg,1,P)
    End;
    Define(Part);
    Until Arg='';
   End;
   'B':
   Begin
    If Arg<>'' Then CLIError('Option /B incorrecte'); BuildMode:=True
   End;
   'M':
   Begin
    If Arg<>'' Then CLIError('Option /M incorrecte'); MakeMode:=True
   End;
   'I':Begin If Arg='' Then CLIError('Repertoire /I manquant'); IncludeDirs:=Arg End;
   'G':Begin
    Arg:=Upper(Arg); If Arg='S' Then MapMode:=1 Else If Arg='P' Then MapMode:=2
    Else If Arg='D' Then Begin MapMode:=3; SetSwitch('D+'); SetSwitch('L+') End
    Else CLIError('Option /G attendue: /GS /GP /GD');
   End;
   'V':Begin
    If Not ((Arg='') Or (Arg='+') Or (Arg='-')) Then CLIError('Option /V incorrecte');
    DebugInExe:=Arg<>'-'; If DebugInExe Then Begin SetSwitch('D+'); SetSwitch('L+') End;
   End;
   'F':Begin
    P:=Pos(':',Arg); If P=0 Then CLIError('/F exige segment:offset hexadecimal');
    Val('$'+Copy(Arg,1,P-1),LookupAddress,ErrorCode); If (ErrorCode<>0) Or (LookupAddress<0) Or (LookupAddress>65535) Then CLIError('Segment /F invalide');
    LookupAddress:=LookupAddress*16;
    Val('$'+Copy(Arg,P+1,255),AddressPart,ErrorCode); If (ErrorCode<>0) Or (AddressPart<0) Or (AddressPart>65535) Then CLIError('Offset /F invalide');
    LookupAddress:=LookupAddress+AddressPart; LookupRequested:=True; SetSwitch('D+');
   End;
   'O':Begin If Arg='' Then CLIError('Repertoire /O manquant'); ObjectDirs:=Arg End;
   'L':Begin
    { Tampon de liaison sur disque: l'image est deja construite en memoire
      hote, l'option est acceptee sans effet comme sur un PC bien dote. }
    If Arg<>'' Then CLIError('Option /L incorrecte');
   End;
   Else CLIError('Option inconnue: '+S);
  End;
 End Else
 Begin
  If InputName<>'' Then CLIError('Un seul fichier source attendu'); InputName:=S;
 End;
End;

Procedure ParseArguments;
Var I,J,Sep,Err: Integer; Config: Text; S,WordText,Path,Search,Part: TShortString;
 D: DirStr; N: NameStr; E: ExtStr; Quoted: Boolean;
Begin
 If ParamCount=0 Then Begin Help; Halt(0) End;
 Search:='.;';
 For I:=1 To ParamCount Do Begin
  S:=ParamStr(I);
  If (Length(S)>2) And (S[1] In ['/','-']) And (UpCase(S[2])='T') Then Search:=Search+Copy(S,3,255)+';';
 End;
 FSplit(ParamStr(0),D,N,E); Search:=Search+D; Path:='';
 Repeat
  Sep:=Pos(';',Search);
  If Sep=0 Then Begin Part:=Search; Search:='' End
  Else Begin Part:=Copy(Search,1,Sep-1); Delete(Search,1,Sep) End;
  Path:=JoinPath(Part,'TPC.CFG'); If FileExists(Path) Then Break; Path:='';
 Until Search='';
 If Path<>'' Then Begin
  Assign(Config,Path); {$I-} Reset(Config); Err:=IOResult; {$I+}
  If Err<>0 Then CLIError('Lecture TPC.CFG impossible');
  While Not Eof(Config) Do Begin
   ReadLn(Config,S); S:=Trim(S);
   If (S<>'') And (S[1]<>'#') Then Begin
    J:=1;
    While J<=Length(S) Do Begin
     While (J<=Length(S)) And (S[J]<=' ') Do Inc(J);
     WordText:=''; Quoted:=False;
     While J<=Length(S) Do Begin
      If S[J]='"' Then Quoted:=Not Quoted
      Else If (S[J]<=' ') And Not Quoted Then Break
      Else AppendChar(WordText,S[J]);
      Inc(J);
     End;
     If Quoted Then CLIError('Guillemet TPC.CFG non termine');
     If WordText<>'' Then Begin
      If Not (WordText[1] In ['/','-']) Then CLIError('TPC.CFG contient un nom de source');
      ProcessArgument(WordText);
     End;
    End;
   End;
  End;
  Close(Config);
 End;
 For I:=1 To ParamCount Do ProcessArgument(ParamStr(I));
End;

Procedure CheckLayout;
Var
 Actual: Word;
Begin
 Actual:=SizeOf(TUnitHeader);
 If Actual<>TPUHeaderSize Then CLIError('Disposition en-tete TPU incompatible');
 Actual:=SizeOf(TTypeDescriptor);
 If Actual<>6 Then CLIError('Disposition descripteur incompatible');
 Actual:=SizeOf(TSymbolPrefix);
 If Actual<>4 Then CLIError('Disposition symbole incompatible');
 Actual:=SizeOf(TTPUFixup);
 If Actual<>8 Then CLIError('Disposition fixup incompatible');
 Actual:=SizeOf(TShortString);
 If Actual<>256 Then CLIError('Disposition shortstring incompatible');
End;

Var
 D: DirStr;
 N: NameStr;
 E: ExtStr;

Function ClockHundredths: Longint;
Var H,M,S,C: Word;
Begin
 GetTime(H,M,S,C);
 ClockHundredths:=((Longint(H)*60+M)*60+S)*100+C;
End;

Procedure Summary(CodeBytes,DataBytes: Longint);
{ Ligne de resume de TPC 7.0: "n lines, s seconds, c bytes code, d bytes data." }
Var Elapsed: Longint;
Begin
 Elapsed:=ClockHundredths-StartTime;
 If Elapsed<0 Then Inc(Elapsed,Longint(24)*60*60*100);
 WriteLn(TotalLines,' lignes, ',Elapsed Div 100,'.',(Elapsed Mod 100) Div 10,' secondes, ',
  CodeBytes,' octets de code, ',DataBytes,' octets de donnees.');
End;

BEGIN
  { Structures fixes du format TPU, verifier avant toute lecture binaire. }
 CheckLayout;
 StartTime:=ClockHundredths; TotalLines:=0;
 StackSize:=16384; MinHeap:=0; MaxHeap:=$FFFF;
 OptionBits:=$171D; { defauts TPC 7.0: A+ D+ E+ I+ L+ S+ V+ X+; B F G N O P Q R T desactives }
 TokenLine:=1; TokenColumn:=1;
 Define('VER70'); Define('MSDOS'); Define('CPU86');
 Banner;
 ParseArguments;
 If InspectName<>'' Then Begin
  SourceName:=InspectName; InspectTPU; Halt(0)
 End;
 If InspectLibraryName<>'' Then Begin
  SourceName:=InspectLibraryName; InspectLibrary; Halt(0)
 End;
 If InputName='' Then CLIError('Fichier source manquant');
 SourceName:=InputName; FSplit(SourceName,D,N,E);
 If E='' Then SourceName:=SourceName+'.PAS';
 MainSourceName:=SourceName;
 FindAndReadLibrary;
 Move(Defines,InitialDefines,SizeOf(Defines)); InitialDefineCount:=DefineCount;
 InitialOptions:=OptionBits;
 LoadSource; CompileProgram; LoadObjects; WriteUnits;
 If Not UnitOutput Then Begin
  LinkNative; PrepareOverlays; WriteExecutable
 End;
 Summary(CodeSize,DataSize+BssSize);
END.
