{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Clone de la commande python3 : compilateur Python vers
  bytecode (jeu d'instructions de CPython 3.8), machine virtuelle Python,
  options de ligne de commande de python3 et mode interactif (REPL).
  @license: MIT
}

(* ============================================================
  PYTHON3.PAS - Clone de la commande python3
  Free Pascal 3.2 (le source fixe lui-meme {$MODE OBJFPC} et les
  chaines longues : Turbo Pascal 7 ne peut pas contenir une machine
  virtuelle Python complete : segments de 64 Ko, pas d'Int64)

  Pipeline : source .py -> lexer (INDENT/DEDENT) -> parser (AST)
    -> table des symboles -> generateur de bytecode (opcodes de
    CPython 3.8, mots de 2 octets, EXTENDED_ARG, co_lnotab)
    -> machine virtuelle a pile (blocs SETUP_FINALLY, generateurs,
    fermetures, classes, metaclasses, exceptions chainees, ...).

  Usage : python3 [option] ... [-c cmd | -m mod | file | -] [arg] ...
  Voir  : python3 --help

  Compilation : fpc -Mtp PYTHON3.PAS -o./BINLINUX/PYTHON3
  ============================================================ *)

Program PYTHON3;

{$MODE OBJFPC}
{$H+}
{$INLINE ON}
{$POINTERMATH ON}
{$COPERATORS ON}
{$Q-}
{$R-}
{$I-}
{$S-}
{$WARN 5024 OFF}
{$WARN 5025 OFF}
{$WARN 5027 OFF}
{$WARN 4055 OFF}
{$WARN 4079 OFF}
{$WARN 4081 OFF}
{$WARN 5057 OFF}
{$WARN 5058 OFF}
{$WARN 6058 OFF}
{$WARN 3123 OFF}

Uses
 SysUtils, Classes, StrUtils, DateUtils, Math {$IFDEF UNIX}, BaseUnix, Unix, Termio{$ENDIF};

Const
 PY_MAJOR = 3;
 PY_MINOR = 8;
 PY_MICRO = 10;
 PY_VERSION = '3.8.10';
 PY_HEXVERSION = $03080AF0;
 PY_MAGIC = 3413;
 PY_BUILD = '(default, Oct 19 2026, 00:00:00)';
 PY_COMPILER = '[Free Pascal ' + {$I %FPCVERSION%} + ']';

 { Genres de valeurs }
 vkNull = 0;
 vkNone = 1;
 vkBool = 2;
 vkInt = 3;
 vkFloat = 4;
 vkObj = 5;
 vkDummy = 6;

 { Drapeaux de code (co_flags) }
 CO_OPTIMIZED = 1;
 CO_NEWLOCALS = 2;
 CO_VARARGS = 4;
 CO_VARKEYWORDS = 8;
 CO_NESTED = 16;
 CO_GENERATOR = 32;
 CO_NOFREE = 64;

 MAX_BLOCKS = 24;

Type
 PVal = ^TVal;
 TPyObj = Class;
 TPyType = Class;
 TPyDict = Class;
 TPyStr = Class;
 TPyTuple = Class;
 TPyList = Class;
 TPyCode = Class;
 TPyFunc = Class;
 TPyGen = Class;
 TFrame = Class;

 TVal = Record
  k: Byte;
  Case Byte Of
   0: (o: TPyObj);
   1: (i: Int64);
   2: (d: Double);
 End;
 TValArr = Array Of TVal;
 TStrArr = Array Of AnsiString;
 TNativeFn = Function(a: PVal; n: Integer; kw: TPyDict): TVal;
 TMag = Array Of Cardinal;
 TCpArr = Array Of Cardinal;

 { Objet de base du ramasse-miettes }
 TPyObj = Class
  cls: TPyType;
  idict: TPyDict;
  gcmark: Boolean;
  immortal: Boolean;
  Constructor Create(c: TPyType);
  Procedure MarkKids; Virtual;
 End;

 TPyStr = Class(TPyObj)
  s: AnsiString;
  h: Int64;
  hashed: Boolean;
  n: Integer;
  Constructor Make(Const t: AnsiString);
 End;

 TPyBytes = Class(TPyObj)
  s: AnsiString;
  Constructor Make(Const t: AnsiString);
 End;

 TPyBigInt = Class(TPyObj)
  neg: Boolean;
  mag: TMag;
  Constructor Make(ng: Boolean; Const m: TMag);
 End;

 TPyList = Class(TPyObj)
  items: Array Of TVal;
  cnt: Integer;
  Constructor Make;
  Procedure Add(Const v: TVal);
  Procedure Insert(ix: Integer; Const v: TVal);
  Procedure Delete(ix: Integer);
  Procedure Clear;
  Procedure MarkKids; Override;
 End;

 TPyTuple = Class(TPyObj)
  items: Array Of TVal;
  Constructor Make(n: Integer);
  Procedure MarkKids; Override;
 End;

 TDEntry = Record
  key, val: TVal;
  h: Int64;
 End;

 TPyDict = Class(TPyObj)
  ent: Array Of TDEntry;
  nent: Integer;
  used: Integer;
  idx: Array Of LongInt;
  mask: Integer;
  Constructor Make;
  Function FindIdx(Const key: TVal; h: Int64): Integer;
  Function FindS(Const s: AnsiString; h: Int64): Integer;
  Function GetItem(Const key: TVal; Var v: TVal): Boolean;
  Procedure SetItem(Const key, v: TVal);
  Function DelItem(Const key: TVal): Boolean;
  Function GetS(Const name: AnsiString; Var v: TVal): Boolean;
  Procedure SetS(Const name: AnsiString; Const v: TVal);
  Function HasS(Const name: AnsiString): Boolean;
  Function DelS(Const name: AnsiString): Boolean;
  Procedure Clear;
  Procedure Rebuild(newcap: Integer);
  Function Copy: TPyDict;
  Procedure MarkKids; Override;
 End;

 TSetEntry = Record
  key: TVal;
  h: Int64;
 End;

 TPySet = Class(TPyObj)
  tab: Array Of TSetEntry;
  fill, used, mask: Integer;
  frozen: Boolean;
  Constructor Make(fz: Boolean);
  Function Contains(Const key: TVal): Boolean;
  Function FindEntry(Const key: TVal; h: Int64): Integer;
  Procedure InsertClean(Const key: TVal; h: Int64);
  Function Add(Const key: TVal): Boolean;
  Function Discard(Const key: TVal): Boolean;
  Procedure Clear;
  Procedure Resize(minused: Integer);
  Procedure MarkKids; Override;
 End;

 TPySlice = Class(TPyObj)
  start, stop, step: TVal;
  Procedure MarkKids; Override;
 End;

 TPyRange = Class(TPyObj)
  start, stop, step: Int64;
  len: Int64;
 End;

 TPyCell = Class(TPyObj)
  v: TVal;
  Procedure MarkKids; Override;
 End;

 TPyBuiltin = Class(TPyObj)
  name: AnsiString;
  fn: TNativeFn;
  isMethod: Boolean;
  Procedure MarkKids; Override;
 End;

 TPyMethod = Class(TPyObj)
  fn: TVal;
  slf: TVal;
  Procedure MarkKids; Override;
 End;

 TPyModule = Class(TPyObj)
  name: AnsiString;
 End;

 TPyProperty = Class(TPyObj)
  fget, fset, fdel, doc: TVal;
  Procedure MarkKids; Override;
 End;

 TPyWrapper = Class(TPyObj)  { staticmethod / classmethod }
  fn: TVal;
  Procedure MarkKids; Override;
 End;

 TPySuper = Class(TPyObj)
  thisCls: TPyType;
  obj: TVal;
  objType: TPyType;
  Procedure MarkKids; Override;
 End;

 TPyCode = Class(TPyObj)
  argcount, posonly, kwonly, nlocals, stacksize, flags: Integer;
  co: Array Of Byte;
  consts: TValArr;
  names: Array Of AnsiString;
  nameObjs: Array Of TPyStr;
  varnames, freevars, cellvars: Array Of AnsiString;
  filename, name: AnsiString;
  firstline: Integer;
  lnotab: AnsiString;
  source: TStrArr;
  Procedure MarkKids; Override;
 End;

 TPyFunc = Class(TPyObj)
  code: TPyCode;
  globals: TPyDict;
  name, qualname: AnsiString;
  defaults: TPyTuple;
  kwdefaults: TPyDict;
  closure: Array Of TPyCell;
  doc: TVal;
  Procedure MarkKids; Override;
 End;

 TBlock = Record
  kind: Byte;
  handler: Integer;
  level: Integer;
 End;

 TFrame = Class
  code: TPyCode;
  func: TPyFunc;
  globals, locals, builtins: TPyDict;
  base: PVal;
  nfast: Integer;
  sp: PVal;
  ip: Integer;
  blocks: Array[0..MAX_BLOCKS - 1] Of TBlock;
  nb: Integer;
  back: TFrame;
  gen: TPyGen;
  mem: PVal;
  initInst: TVal;
  isEntry: Boolean;
  depth: Integer;
  lasti: Integer;
  throwExc: TPyObj;
  Procedure MarkAll;
 End;

 TPyIter = Class(TPyObj)
  Function Next(Var r: TVal): Boolean; Virtual; Abstract;
 End;

 TPyGen = Class(TPyIter)
  frame: TFrame;
  state: Integer;       { 0 initial, 1 suspendu, 2 en cours, 3 termine }
  retval: TVal;
  name: AnsiString;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
  Destructor Destroy; Override;
 End;

 TPyType = Class(TPyObj)
  name, qualname: AnsiString;
  bases: Array Of TPyType;
  mro: Array Of TPyType;
  native: Integer;       { genre natif alloue par __new__ }
  userdef: Boolean;
  newFn: TNativeFn;
  ctor: TNativeFn;
  Procedure MarkKids; Override;
 End;

 TPyFile = Class(TPyObj)
  fname, mode: AnsiString;
  data: AnsiString;
  pos: Integer;
  readable, writable, appendm, dirty, closed, binary: Boolean;
  std: Integer;          { 0 fichier, 1 stdin, 2 stdout, 3 stderr }
  Procedure MarkKids; Override;
 End;

 { Exception Pascal portant une exception Python }
 EPyError = Class(Exception)
  exc: TPyObj;
  Constructor Make(e: TPyObj);
 End;

Const
 { genres natifs de type }
 nkObject = 0;
 nkList = 1;
 nkDict = 2;
 nkSet = 3;
 nkStr = 4;
 nkTuple = 5;
 nkBytes = 6;
 nkFrozen = 7;
 nkException = 8;
 nkFile = 9;
 nkProperty = 10;
 nkWrapper = 11;
 nkInt = 12;
 nkFloat = 13;
 nkBool = 14;
 nkType = 15;
 nkNoNew = 16;

Var
 { objets du ramasse-miettes }
 GcObjs: Array Of TPyObj;
 GcCount: Integer;
 GcLive: Integer;
 GcEnabled: Boolean;
 GcInit: Boolean;
 GcStress: Boolean;
 GcStack: Array Of TPyObj;
 GcSP: Integer;
 GcRoots: Array Of TPyObj;
 GcNRoots: Integer;

 { types natifs }
 tyObject, tyType, tyInt, tyBool, tyFloat, tyStr, tyBytes, tyBytearray,
 tyList, tyTuple, tyDict, tySet, tyFrozenset, tyNone, tyFunction,
 tyBuiltin, tyMethod, tyModule, tyCode, tyCell, tyGenerator, tyRange,
 tySlice, tyProperty, tyStaticMethod, tyClassMethod, tySuper,
 tyEllipsis, tyNotImpl, tyFile, tyIter, tyDictView, tyFrame,
 tyTraceback: TPyType;

 { exceptions }
 exBaseException, exException, exSystemExit, exKeyboardInterrupt,
 exGeneratorExit, exStopIteration, exArithmeticError, exZeroDivision,
 exOverflow, exFloatingPoint, exAssertionError, exAttributeError,
 exBufferError, exEOFError, exImportError, exModuleNotFound,
 exLookupError, exIndexError, exKeyError, exMemoryError, exNameError,
 exUnboundLocal, exOSError, exFileNotFound, exFileExists,
 exIsADirectory, exNotADirectory, exPermissionError, exTimeoutError,
 exReferenceError, exRuntimeError, exNotImplementedError,
 exRecursionError, exSyntaxError, exIndentationError, exTabError,
 exSystemError, exTypeError, exValueError, exUnicodeError,
 exUnicodeDecodeError, exUnicodeEncodeError, exWarning,
 exUserWarning, exDeprecationWarning, exRuntimeWarning,
 exSyntaxWarning, exFutureWarning, exPendingDeprecationWarning,
 exImportWarning, exResourceWarning, exBytesWarning,
 exUnicodeWarning, exStopAsyncIteration, exBlockingIOError,
 exBrokenPipe, exConnectionError, exInterrupted, exChildProcess,
 exProcessLookup: TPyType;

 { constantes singletons }
 vNone, vTrue, vFalse, vNull, vEllipsis, vNotImpl: TVal;
 BuiltinsDict, ModulesDict, SysDict: TPyDict;
 InternTab: TPyDict;
 EmptyTuple: TPyTuple;

 { etat de la machine virtuelle }
 VStackBase, VTop, VLimit: PVal;
 CurFrame: TFrame;
 NestDepth: Integer;
 CallDepth: Integer;
 RecursionLimit: Integer;
 ExcInfo: TVal;           { exception en cours de traitement }
 PendingInterrupt: Boolean;

{ ------------------------------------------------------------
  Declarations anticipees
  ------------------------------------------------------------ }
Function HashVal(Const v: TVal): Int64; Forward;
Function ValEq(Const a, b: TVal): Boolean; Forward;
Function CallValue(Const fn: TVal; a: PVal; n: Integer;
 kw: TPyDict): TVal; Forward;
Function ReprVal(Const v: TVal): AnsiString; Forward;
Function StrVal(Const v: TVal): AnsiString; Forward;
Procedure RaiseExc(c: TPyType; Const msg: AnsiString); Forward;
Function TypeOf(Const v: TVal): TPyType; Forward;
Function GetAttr(Const o: TVal; Const name: AnsiString): TVal; Forward;
Function IsTrue(Const v: TVal): Boolean; Forward;
Function IsInstance(Const v: TVal; t: TPyType): Boolean; Forward;
Function TypeIsSub(c, base: TPyType): Boolean; Forward;
Function LookupType(t: TPyType; Const name: AnsiString;
 Var v: TVal): Boolean; Forward;
Function VStr(Const s: AnsiString): TVal; Forward;
Function VBytes(Const s: AnsiString): TVal; Forward;
Function NewList: TPyList; Forward;
Function NewTuple(n: Integer): TPyTuple; Forward;
Function InternStr(Const s: AnsiString): TPyStr; Forward;
Function IterOf(Const v: TVal): TVal; Forward;
Function IterNextVal(Const it: TVal; Var r: TVal): Boolean; Forward;
Procedure MarkVal(Const v: TVal); Forward;
Procedure MarkObj(o: TPyObj); Forward;
Function CmpLess(Const a, b: TVal): Boolean; Forward;
Function ValCompare(Const a, b: TVal; op: Integer): Boolean; Forward;
Function Call1(Const fn, a1: TVal): TVal; Forward;
Function Call2(Const fn, a1, a2: TVal): TVal; Forward;
Function Call0(Const fn: TVal): TVal; Forward;
Function ToInt64(Const v: TVal): Int64; Forward;
Function IntToStrVal(Const v: TVal): AnsiString; Forward;
Procedure PyRunTraceback(e: TPyObj); Forward;

{ ------------------------------------------------------------
  Constructeurs de valeurs
  ------------------------------------------------------------ }
Function VInt(i: Int64): TVal; Inline;
Begin
 Result.k := vkInt;
 Result.i := i;
End;

Function VFloat(d: Double): TVal; Inline;
Begin
 Result.k := vkFloat;
 Result.d := d;
End;

Function VBool(b: Boolean): TVal; Inline;
Begin
 Result.k := vkBool;
 If b Then Result.i := 1 Else Result.i := 0;
End;

Function VObj(o: TPyObj): TVal; Inline;
Begin
 If o = Nil Then Begin
  Result.k := vkNull;
  Result.i := 0;
 End
 Else Begin
  Result.k := vkObj;
  Result.o := o;
 End;
End;

Function IsObj(Const v: TVal): Boolean; Inline;
Begin
 Result := v.k = vkObj;
End;

{ ------------------------------------------------------------
  Ramasse-miettes : enregistrement des objets
  ------------------------------------------------------------ }
Procedure GcAddRoot(o: TPyObj);
Begin
 If GcNRoots >= Length(GcRoots) Then
  SetLength(GcRoots, GcNRoots * 2 + 64);
 GcRoots[GcNRoots] := o;
 Inc(GcNRoots);
End;

Constructor TPyObj.Create(c: TPyType);
Begin
 Inherited Create;
 cls := c;
 idict := Nil;
 gcmark := False;
 immortal := GcInit;
 If immortal Then GcAddRoot(Self)
 Else Begin
  If GcCount >= Length(GcObjs) Then
   SetLength(GcObjs, (GcCount + 1024) * 2);
  GcObjs[GcCount] := Self;
  Inc(GcCount);
 End;
End;

Procedure TPyObj.MarkKids;
Begin
 If cls <> Nil Then MarkObj(cls);
 If idict <> Nil Then MarkObj(idict);
End;

Constructor TPyStr.Make(Const t: AnsiString);
Begin
 Inherited Create(tyStr);
 s := t;
 hashed := False;
 n := -1;
End;

Constructor TPyBytes.Make(Const t: AnsiString);
Begin
 Inherited Create(tyBytes);
 s := t;
End;

Constructor TPyBigInt.Make(ng: Boolean; Const m: TMag);
Begin
 Inherited Create(tyInt);
 neg := ng;
 mag := m;
End;

Constructor TPyList.Make;
Begin
 Inherited Create(tyList);
 cnt := 0;
End;

Procedure TPyList.Add(Const v: TVal);
Begin
 If cnt >= Length(items) Then
  SetLength(items, cnt + (cnt Shr 1) + 4);
 items[cnt] := v;
 Inc(cnt);
End;

Procedure TPyList.Insert(ix: Integer; Const v: TVal);
Var
 j: Integer;
Begin
 If cnt >= Length(items) Then
  SetLength(items, cnt + (cnt Shr 1) + 4);
 If ix < 0 Then ix := 0;
 If ix > cnt Then ix := cnt;
 For j := cnt DownTo ix + 1 Do items[j] := items[j - 1];
 items[ix] := v;
 Inc(cnt);
End;

Procedure TPyList.Delete(ix: Integer);
Var
 j: Integer;
Begin
 For j := ix To cnt - 2 Do items[j] := items[j + 1];
 Dec(cnt);
 items[cnt].k := vkNull;
End;

Procedure TPyList.Clear;
Begin
 SetLength(items, 0);
 cnt := 0;
End;

Procedure TPyList.MarkKids;
Var
 j: Integer;
Begin
 Inherited MarkKids;
 For j := 0 To cnt - 1 Do MarkVal(items[j]);
End;

Constructor TPyTuple.Make(n: Integer);
Begin
 Inherited Create(tyTuple);
 SetLength(items, n);
 If n > 0 Then FillChar(items[0], n * SizeOf(TVal), 0);
End;

Procedure TPyTuple.MarkKids;
Var
 j: Integer;
Begin
 Inherited MarkKids;
 For j := 0 To High(items) Do MarkVal(items[j]);
End;

Procedure TPySlice.MarkKids;
Begin
 MarkVal(start);
 MarkVal(stop);
 MarkVal(step);
End;

Procedure TPyCell.MarkKids;
Begin
 MarkVal(v);
End;

Procedure TPyBuiltin.MarkKids;
Begin
 Inherited MarkKids;
End;

Procedure TPyMethod.MarkKids;
Begin
 MarkVal(fn);
 MarkVal(slf);
End;

Procedure TPyProperty.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(fget);
 MarkVal(fset);
 MarkVal(fdel);
 MarkVal(doc);
End;

Procedure TPyWrapper.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(fn);
End;

Procedure TPySuper.MarkKids;
Begin
 If thisCls <> Nil Then MarkObj(thisCls);
 MarkVal(obj);
 If objType <> Nil Then MarkObj(objType);
End;

Procedure TPyCode.MarkKids;
Var
 j: Integer;
Begin
 For j := 0 To High(consts) Do MarkVal(consts[j]);
 For j := 0 To High(nameObjs) Do
  If nameObjs[j] <> Nil Then MarkObj(nameObjs[j]);
End;

Procedure TPyFunc.MarkKids;
Var
 j: Integer;
Begin
 Inherited MarkKids;
 If code <> Nil Then MarkObj(code);
 If globals <> Nil Then MarkObj(globals);
 If defaults <> Nil Then MarkObj(defaults);
 If kwdefaults <> Nil Then MarkObj(kwdefaults);
 For j := 0 To High(closure) Do
  If closure[j] <> Nil Then MarkObj(closure[j]);
 MarkVal(doc);
End;

Procedure TPyType.MarkKids;
Var
 j: Integer;
Begin
 Inherited MarkKids;
 For j := 0 To High(bases) Do MarkObj(bases[j]);
 For j := 0 To High(mro) Do MarkObj(mro[j]);
End;

Procedure TPyFile.MarkKids;
Begin
 Inherited MarkKids;
End;

Constructor EPyError.Make(e: TPyObj);
Begin
 Inherited Create('PyError');
 exc := e;
End;

{ ------------------------------------------------------------
  Marquage (iteratif : pas de recursion Pascal profonde)
  ------------------------------------------------------------ }
Procedure MarkObj(o: TPyObj);
Begin
 If (o = Nil) Or o.gcmark Then Exit;
 o.gcmark := True;
 If GcSP >= Length(GcStack) Then
  SetLength(GcStack, (GcSP + 1024) * 2);
 GcStack[GcSP] := o;
 Inc(GcSP);
End;

Procedure MarkVal(Const v: TVal);
Begin
 If v.k = vkObj Then MarkObj(v.o);
End;

Procedure TFrame.MarkAll;
Var
 p: PVal;
Begin
 If code <> Nil Then MarkObj(code);
 If func <> Nil Then MarkObj(func);
 If globals <> Nil Then MarkObj(globals);
 If locals <> Nil Then MarkObj(locals);
 If builtins <> Nil Then MarkObj(builtins);
 MarkVal(initInst);
 If gen <> Nil Then MarkObj(gen);
 If base <> Nil Then Begin
  p := base;
  While p < sp Do Begin
   MarkVal(p^);
   Inc(p);
  End;
 End;
End;

Procedure TPyGen.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(retval);
 If frame <> Nil Then frame.MarkAll;
End;

Destructor TPyGen.Destroy;
Begin
 If frame <> Nil Then Begin
  If frame.mem <> Nil Then FreeMem(frame.mem);
  frame.Free;
 End;
 Inherited Destroy;
End;


{ ------------------------------------------------------------
  Utilitaires UTF-8
  ------------------------------------------------------------ }
Function Utf8Enc(cp: Cardinal): AnsiString;
Begin
 If cp < $80 Then Result := Chr(cp)
 Else If cp < $800 Then
  Result := Chr($C0 Or (cp Shr 6)) + Chr($80 Or (cp And $3F))
 Else If cp < $10000 Then
  Result := Chr($E0 Or (cp Shr 12)) + Chr($80 Or ((cp Shr 6) And $3F)) +
   Chr($80 Or (cp And $3F))
 Else
  Result := Chr($F0 Or ((cp Shr 18) And 7)) +
   Chr($80 Or ((cp Shr 12) And $3F)) + Chr($80 Or ((cp Shr 6) And $3F)) +
   Chr($80 Or (cp And $3F));
End;

{ Decode un point de code ; i = index base 1, avance i }
Function Utf8Dec(Const s: AnsiString; Var i: Integer): Cardinal;
Var
 c: Cardinal;
 n, j: Integer;
Begin
 c := Ord(s[i]);
 If c < $80 Then Begin
  Inc(i);
  Result := c;
  Exit;
 End;
 If (c >= $C2) And (c < $E0) Then n := 1
 Else If (c >= $E0) And (c < $F0) Then n := 2
 Else If (c >= $F0) And (c < $F5) Then n := 3
 Else n := -1;
 If (n < 0) Or (i + n > Length(s)) Then Begin
  Inc(i);
  Result := c;
  Exit;
 End;
 If n = 1 Then c := c And $1F
 Else If n = 2 Then c := c And $F
 Else c := c And 7;
 For j := 1 To n Do Begin
  If (Ord(s[i + j]) And $C0) <> $80 Then Begin
   Inc(i);
   Result := Ord(s[i - 1]);
   Exit;
  End;
  c := (c Shl 6) Or (Ord(s[i + j]) And $3F);
 End;
 Inc(i, n + 1);
 Result := c;
End;

Function Utf8Len(Const s: AnsiString): Integer;
Var
 i, n: Integer;
Begin
 n := 0;
 For i := 1 To Length(s) Do
  If (Ord(s[i]) And $C0) <> $80 Then Inc(n);
 Result := n;
End;

Function IsAsciiStr(Const s: AnsiString): Boolean;
Var
 i: Integer;
Begin
 Result := True;
 For i := 1 To Length(s) Do
  If Ord(s[i]) >= $80 Then Begin
   Result := False;
   Exit;
  End;
End;

Function StrToCps(Const s: AnsiString): TCpArr;
Var
 i, n: Integer;
Begin
 SetLength(Result, Length(s));
 i := 1;
 n := 0;
 While i <= Length(s) Do Begin
  Result[n] := Utf8Dec(s, i);
  Inc(n);
 End;
 SetLength(Result, n);
End;

Function CpsToStr(Const a: TCpArr; lo, hi: Integer): AnsiString;
Var
 i: Integer;
Begin
 Result := '';
 For i := lo To hi - 1 Do Result := Result + Utf8Enc(a[i]);
End;

Function PyStrLen(o: TPyStr): Integer;
Begin
 If o.n < 0 Then o.n := Utf8Len(o.s);
 Result := o.n;
End;

{ Sous-chaine en points de code [lo, hi[ }
Function CpSub(Const s: AnsiString; lo, hi: Integer): AnsiString;
Var
 i, k, b0, b1: Integer;
Begin
 If lo >= hi Then Begin
  Result := '';
  Exit;
 End;
 i := 1;
 k := 0;
 b0 := 1;
 b1 := Length(s) + 1;
 While i <= Length(s) Do Begin
  If k = lo Then b0 := i;
  If k = hi Then Begin
   b1 := i;
   Break;
  End;
  Utf8Dec(s, i);
  Inc(k);
 End;
 If k < hi Then b1 := Length(s) + 1;
 Result := Copy(s, b0, b1 - b0);
End;

Function ByteToCpIndex(Const s: AnsiString; b: Integer): Integer;
Var
 i, n: Integer;
Begin
 n := 0;
 For i := 1 To b - 1 Do
  If (Ord(s[i]) And $C0) <> $80 Then Inc(n);
 Result := n;
End;

Function CpToByteIndex(Const s: AnsiString; c: Integer): Integer;
Var
 i, k: Integer;
Begin
 i := 1;
 k := 0;
 While (i <= Length(s)) And (k < c) Do Begin
  Utf8Dec(s, i);
  Inc(k);
 End;
 Result := i;
End;

Function CpUpper(c: Cardinal): Cardinal;
Begin
 Result := c;
 If (c >= 97) And (c <= 122) Then Result := c - 32
 Else If c < 128 Then Result := c
 Else If ((c >= $E0) And (c <= $FE) And (c <> $F7)) Then Result := c - 32
 Else If c = $FF Then Result := $178
 Else If (c >= $3B1) And (c <= $3C9) And (c <> $3C2) Then Result := c - 32
 Else If c = $3C2 Then Result := $3A3
 Else If (c >= $430) And (c <= $44F) Then Result := c - 32
 Else If (c >= $450) And (c <= $45F) Then Result := c - 80
 Else If (c >= $100) And (c <= $17F) And ((c And 1) = 1) And
  (c <> $131) And (c <> $138) And (c <> $149) And (c <> $17F) And
  ((c < $139) Or (c > $148)) And ((c < $179) Or (c > $17E)) Then
  Result := c - 1
 Else If (c >= $139) And (c <= $148) And ((c And 1) = 0) Then
  Result := c - 1
 Else If (c >= $179) And (c <= $17E) And ((c And 1) = 0) Then
  Result := c - 1;
End;

Function CpLower(c: Cardinal): Cardinal;
Begin
 Result := c;
 If (c >= 65) And (c <= 90) Then Result := c + 32
 Else If c < 128 Then Result := c
 Else If (c >= $C0) And (c <= $DE) And (c <> $D7) Then Result := c + 32
 Else If c = $178 Then Result := $FF
 Else If (c >= $391) And (c <= $3A9) And (c <> $3A2) Then Result := c + 32
 Else If (c >= $410) And (c <= $42F) Then Result := c + 32
 Else If (c >= $400) And (c <= $40F) Then Result := c + 80
 Else If (c >= $100) And (c <= $137) And ((c And 1) = 0) And
  (c <> $130) Then Result := c + 1
 Else If (c >= $139) And (c <= $148) And ((c And 1) = 1) Then
  Result := c + 1
 Else If (c >= $14A) And (c <= $177) And ((c And 1) = 0) Then
  Result := c + 1
 Else If (c >= $179) And (c <= $17E) And ((c And 1) = 1) Then
  Result := c + 1;
End;

Function CpIsAlpha(c: Cardinal): Boolean;
Begin
 Result := ((c >= 65) And (c <= 90)) Or ((c >= 97) And (c <= 122)) Or
  ((c >= $C0) And (c <> $D7) And (c <> $F7) And (c < $2000)) Or
  ((c >= $3040) And (c < $A000)) Or ((c >= $AC00) And (c < $D7A4));
 If (c = $AA) Or (c = $B5) Or (c = $BA) Then Result := True;
End;

Function CpIsDigit(c: Cardinal): Boolean;
Begin
 Result := (c >= 48) And (c <= 57);
End;

Function CpIsSpace(c: Cardinal): Boolean;
Begin
 Result := ((c >= 9) And (c <= 13)) Or (c = 32) Or ((c >= $1C) And
  (c <= $1F)) Or (c = $85) Or (c = $A0) Or (c = $1680) Or
  ((c >= $2000) And (c <= $200A)) Or (c = $2028) Or (c = $2029) Or
  (c = $202F) Or (c = $205F) Or (c = $3000);
End;

Function CpIsUpper(c: Cardinal): Boolean;
Begin
 Result := (CpLower(c) <> c);
End;

Function CpIsLower(c: Cardinal): Boolean;
Begin
 Result := (CpUpper(c) <> c) Or (c = $DF);
End;

Function CpIsPrintable(c: Cardinal): Boolean;
Begin
 Result := (c >= 32) And (c <> 127) And ((c < $80) Or (c > $9F)) And
  (c <> $AD) And Not ((c >= $D800) And (c <= $DFFF)) And
  (Not CpIsSpace(c) Or (c = 32));
End;

Function Utf8Upper(Const s: AnsiString): AnsiString;
Var
 i: Integer;
 c: Cardinal;
Begin
 Result := '';
 If IsAsciiStr(s) Then Begin
  Result := s;
  For i := 1 To Length(Result) Do
   If (Result[i] >= 'a') And (Result[i] <= 'z') Then
    Result[i] := Chr(Ord(Result[i]) - 32);
  Exit;
 End;
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  If c = $DF Then Result := Result + 'SS'
  Else Result := Result + Utf8Enc(CpUpper(c));
 End;
End;

Function Utf8Lower(Const s: AnsiString): AnsiString;
Var
 i: Integer;
 c: Cardinal;
Begin
 Result := '';
 If IsAsciiStr(s) Then Begin
  Result := s;
  For i := 1 To Length(Result) Do
   If (Result[i] >= 'A') And (Result[i] <= 'Z') Then
    Result[i] := Chr(Ord(Result[i]) + 32);
  Exit;
 End;
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  Result := Result + Utf8Enc(CpLower(c));
 End;
End;

{ ------------------------------------------------------------
  Entiers de precision arbitraire (magnitude base 2^32)
  ------------------------------------------------------------ }
Procedure MagTrim(Var a: TMag);
Var
 n: Integer;
Begin
 n := Length(a);
 While (n > 0) And (a[n - 1] = 0) Do Dec(n);
 If n <> Length(a) Then SetLength(a, n);
End;

Function MagCmp(Const a, b: TMag): Integer;
Var
 i: Integer;
Begin
 If Length(a) <> Length(b) Then Begin
  If Length(a) < Length(b) Then Result := -1 Else Result := 1;
  Exit;
 End;
 For i := High(a) DownTo 0 Do
  If a[i] <> b[i] Then Begin
   If a[i] < b[i] Then Result := -1 Else Result := 1;
   Exit;
  End;
 Result := 0;
End;

Function MagFromQ(q: QWord): TMag;
Begin
 If q = 0 Then SetLength(Result, 0)
 Else If q <= $FFFFFFFF Then Begin
  SetLength(Result, 1);
  Result[0] := Cardinal(q);
 End
 Else Begin
  SetLength(Result, 2);
  Result[0] := Cardinal(q And $FFFFFFFF);
  Result[1] := Cardinal(q Shr 32);
 End;
End;

Function MagAdd(Const a, b: TMag): TMag;
Var
 i: Integer;
 c, x: QWord;
Begin
 If Length(a) < Length(b) Then Begin
  Result := MagAdd(b, a);
  Exit;
 End;
 SetLength(Result, Length(a) + 1);
 c := 0;
 For i := 0 To High(a) Do Begin
  x := QWord(a[i]) + c;
  If i < Length(b) Then x := x + b[i];
  Result[i] := Cardinal(x And $FFFFFFFF);
  c := x Shr 32;
 End;
 Result[Length(a)] := Cardinal(c);
 MagTrim(Result);
End;

{ a >= b requis }
Function MagSub(Const a, b: TMag): TMag;
Var
 i: Integer;
 t, bw: Int64;
Begin
 SetLength(Result, Length(a));
 bw := 0;
 For i := 0 To High(a) Do Begin
  t := Int64(a[i]) - bw;
  If i < Length(b) Then t := t - b[i];
  If t < 0 Then Begin
   t := t + $100000000;
   bw := 1;
  End
  Else bw := 0;
  Result[i] := Cardinal(t);
 End;
 MagTrim(Result);
End;

Function MagMul(Const a, b: TMag): TMag;
Var
 i, j: Integer;
 t, c: QWord;
Begin
 If (Length(a) = 0) Or (Length(b) = 0) Then Begin
  SetLength(Result, 0);
  Exit;
 End;
 SetLength(Result, Length(a) + Length(b));
 FillChar(Result[0], Length(Result) * 4, 0);
 For i := 0 To High(a) Do Begin
  c := 0;
  If a[i] <> 0 Then
   For j := 0 To High(b) Do Begin
    t := QWord(a[i]) * b[j] + Result[i + j] + c;
    Result[i + j] := Cardinal(t And $FFFFFFFF);
    c := t Shr 32;
   End;
  Result[i + Length(b)] := Cardinal(c);
 End;
 MagTrim(Result);
End;

Function MagMulSmall(Const a: TMag; m: Cardinal): TMag;
Var
 i: Integer;
 t, c: QWord;
Begin
 If (Length(a) = 0) Or (m = 0) Then Begin
  SetLength(Result, 0);
  Exit;
 End;
 SetLength(Result, Length(a) + 1);
 c := 0;
 For i := 0 To High(a) Do Begin
  t := QWord(a[i]) * m + c;
  Result[i] := Cardinal(t And $FFFFFFFF);
  c := t Shr 32;
 End;
 Result[Length(a)] := Cardinal(c);
 MagTrim(Result);
End;

Function MagAddSmall(Const a: TMag; m: Cardinal): TMag;
Var
 b: TMag;
Begin
 b := MagFromQ(m);
 Result := MagAdd(a, b);
End;

Procedure MagDivSmall(Const a: TMag; d: Cardinal; Var q: TMag;
 Var r: Cardinal);
Var
 i: Integer;
 cur: QWord;
Begin
 SetLength(q, Length(a));
 cur := 0;
 For i := High(a) DownTo 0 Do Begin
  cur := (cur Shl 32) Or a[i];
  q[i] := Cardinal(cur Div d);
  cur := cur Mod d;
 End;
 r := Cardinal(cur);
 MagTrim(q);
End;

Function MagBitLen(Const a: TMag): Integer;
Var
 t: Cardinal;
 n: Integer;
Begin
 If Length(a) = 0 Then Begin
  Result := 0;
  Exit;
 End;
 t := a[High(a)];
 n := 0;
 While t <> 0 Do Begin
  Inc(n);
  t := t Shr 1;
 End;
 Result := (Length(a) - 1) * 32 + n;
End;

Function MagShl(Const a: TMag; n: Integer): TMag;
Var
 w, b, i: Integer;
 c: QWord;
Begin
 If Length(a) = 0 Then Begin
  SetLength(Result, 0);
  Exit;
 End;
 w := n Div 32;
 b := n Mod 32;
 SetLength(Result, Length(a) + w + 1);
 FillChar(Result[0], Length(Result) * 4, 0);
 c := 0;
 For i := 0 To High(a) Do Begin
  c := c Or (QWord(a[i]) Shl b);
  Result[i + w] := Cardinal(c And $FFFFFFFF);
  c := c Shr 32;
 End;
 Result[Length(a) + w] := Cardinal(c);
 MagTrim(Result);
End;

Function MagShr(Const a: TMag; n: Integer): TMag;
Var
 w, b, i: Integer;
 x: QWord;
Begin
 w := n Div 32;
 b := n Mod 32;
 If w >= Length(a) Then Begin
  SetLength(Result, 0);
  Exit;
 End;
 SetLength(Result, Length(a) - w);
 For i := 0 To High(Result) Do Begin
  x := a[i + w];
  If i + w + 1 < Length(a) Then x := x Or (QWord(a[i + w + 1]) Shl 32);
  Result[i] := Cardinal((x Shr b) And $FFFFFFFF);
 End;
 MagTrim(Result);
End;

{ Division de Knuth (algorithme D) }
Procedure MagDivMod(Const a, b: TMag; Var q, r: TMag);
Var
 u, v: TMag;
 n, m, j, i, s: Integer;
 num, qhat, rhat, p: QWord;
 t, k: Int64;
 rem1: Cardinal;
 top: Cardinal;
Begin
 If Length(b) = 0 Then Begin
  SetLength(q, 0);
  SetLength(r, 0);
  Exit;
 End;
 If MagCmp(a, b) < 0 Then Begin
  SetLength(q, 0);
  r := Copy(a);
  Exit;
 End;
 If Length(b) = 1 Then Begin
  MagDivSmall(a, b[0], q, rem1);
  r := MagFromQ(rem1);
  Exit;
 End;
 n := Length(b);
 m := Length(a) - n;
 top := b[n - 1];
 s := 0;
 While (top And $80000000) = 0 Do Begin
  top := top Shl 1;
  Inc(s);
 End;
 v := MagShl(b, s);
 u := MagShl(a, s);
 While Length(u) < Length(a) + 1 Do Begin
  SetLength(u, Length(u) + 1);
  u[High(u)] := 0;
 End;
 While Length(v) < n Do Begin
  SetLength(v, Length(v) + 1);
  v[High(v)] := 0;
 End;
 SetLength(q, m + 1);
 For j := m DownTo 0 Do Begin
  num := (QWord(u[j + n]) Shl 32) Or u[j + n - 1];
  qhat := num Div v[n - 1];
  rhat := num Mod v[n - 1];
  While (qhat >= $100000000) Or
   (qhat * v[n - 2] > ((rhat Shl 32) Or u[j + n - 2])) Do Begin
   Dec(qhat);
   rhat := rhat + v[n - 1];
   If rhat >= $100000000 Then Break;
  End;
  k := 0;
  For i := 0 To n - 1 Do Begin
   p := qhat * v[i];
   t := Int64(u[i + j]) - k - Int64(p And $FFFFFFFF);
   u[i + j] := Cardinal(t And $FFFFFFFF);
   k := Int64(p Shr 32) - (t Shr 32);
  End;
  t := Int64(u[j + n]) - k;
  u[j + n] := Cardinal(t And $FFFFFFFF);
  q[j] := Cardinal(qhat);
  If t < 0 Then Begin
   q[j] := q[j] - 1;
   k := 0;
   For i := 0 To n - 1 Do Begin
    t := Int64(u[i + j]) + v[i] + k;
    u[i + j] := Cardinal(t And $FFFFFFFF);
    k := t Shr 32;
   End;
   u[j + n] := Cardinal((Int64(u[j + n]) + k) And $FFFFFFFF);
  End;
 End;
 MagTrim(q);
 SetLength(u, n);
 MagTrim(u);
 r := MagShr(u, s);
End;

Function MagPow10(n: Integer): TMag;
Var
 i: Integer;
Begin
 Result := MagFromQ(1);
 i := n;
 While i >= 9 Do Begin
  Result := MagMulSmall(Result, 1000000000);
  Dec(i, 9);
 End;
 While i > 0 Do Begin
  Result := MagMulSmall(Result, 10);
  Dec(i);
 End;
End;

Function MagToStr(Const a: TMag; radix: Integer): AnsiString;
Var
 q, cur: TMag;
 r: Cardinal;
 chunk, i, cl: Integer;
 digs, piece: AnsiString;
 big: Cardinal;
Begin
 If Length(a) = 0 Then Begin
  Result := '0';
  Exit;
 End;
 cur := Copy(a);
 digs := '';
 chunk := 0;
 big := 1;
 Case radix Of
  10: Begin chunk := 9; big := 1000000000; End;
  2: Begin chunk := 31; big := $80000000; End;
  8: Begin chunk := 10; big := 1073741824; End;
  16: Begin chunk := 7; big := $10000000; End;
 Else
  chunk := 1;
  big := radix;
 End;
 While Length(cur) > 0 Do Begin
  MagDivSmall(cur, big, q, r);
  cur := q;
  piece := '';
  cl := chunk;
  For i := 1 To cl Do Begin
   If (Length(cur) = 0) And (r = 0) Then Break;
   piece := piece + '0123456789abcdefghijklmnopqrstuvwxyz'[(r Mod
    Cardinal(radix)) + 1];
   r := r Div Cardinal(radix);
  End;
  digs := digs + piece;
 End;
 { digs est a l'envers }
 SetLength(Result, Length(digs));
 For i := 1 To Length(digs) Do Result[i] := digs[Length(digs) - i + 1];
End;

{ Fabrique un entier Python (petit ou grand) }
Function MakeInt(neg: Boolean; Var m: TMag): TVal;
Var
 q: QWord;
Begin
 MagTrim(m);
 If Length(m) = 0 Then Begin
  Result := VInt(0);
  Exit;
 End;
 If Length(m) <= 2 Then Begin
  q := m[0];
  If Length(m) = 2 Then q := q Or (QWord(m[1]) Shl 32);
  If Not neg And (q <= QWord(High(Int64))) Then Begin
   Result := VInt(Int64(q));
   Exit;
  End;
  If neg And (q <= QWord(1) Shl 63) Then Begin
   If q = QWord(1) Shl 63 Then Result := VInt(Low(Int64))
   Else Result := VInt(-Int64(q));
   Exit;
  End;
 End;
 Result := VObj(TPyBigInt.Make(neg, m));
End;

Function IsIntVal(Const v: TVal): Boolean; Inline;
Begin
 Result := (v.k = vkInt) Or (v.k = vkBool) Or
  ((v.k = vkObj) And (v.o Is TPyBigInt));
End;

Procedure IntToMag(Const v: TVal; Var neg: Boolean; Var m: TMag);
Var
 x: Int64;
Begin
 If v.k = vkObj Then Begin
  neg := TPyBigInt(v.o).neg;
  m := TPyBigInt(v.o).mag;
  Exit;
 End;
 x := v.i;
 neg := x < 0;
 If neg Then m := MagFromQ(QWord(-(x + 1)) + 1)
 Else m := MagFromQ(QWord(x));
End;

Function IntSign(Const v: TVal): Integer;
Begin
 If v.k = vkObj Then Begin
  If TPyBigInt(v.o).neg Then Result := -1 Else Result := 1;
 End
 Else If v.i < 0 Then Result := -1
 Else If v.i > 0 Then Result := 1
 Else Result := 0;
End;

Function IntCmp(Const a, b: TVal): Integer;
Var
 na, nb: Boolean;
 ma, mb: TMag;
Begin
 If (a.k <> vkObj) And (b.k <> vkObj) Then Begin
  If a.i < b.i Then Result := -1
  Else If a.i > b.i Then Result := 1
  Else Result := 0;
  Exit;
 End;
 IntToMag(a, na, ma);
 IntToMag(b, nb, mb);
 If Length(ma) = 0 Then na := False;
 If Length(mb) = 0 Then nb := False;
 If na <> nb Then Begin
  If na Then Result := -1 Else Result := 1;
  Exit;
 End;
 Result := MagCmp(ma, mb);
 If na Then Result := -Result;
End;

Function IntAdd(Const a, b: TVal): TVal;
Var
 r: Int64;
 na, nb: Boolean;
 ma, mb, m: TMag;
Begin
 If (a.k <> vkObj) And (b.k <> vkObj) Then Begin
  r := a.i + b.i;
  If ((a.i Xor r) And (b.i Xor r)) >= 0 Then Begin
   Result := VInt(r);
   Exit;
  End;
 End;
 IntToMag(a, na, ma);
 IntToMag(b, nb, mb);
 If na = nb Then Begin
  m := MagAdd(ma, mb);
  Result := MakeInt(na, m);
 End
 Else Begin
  If MagCmp(ma, mb) >= 0 Then Begin
   m := MagSub(ma, mb);
   Result := MakeInt(na, m);
  End
  Else Begin
   m := MagSub(mb, ma);
   Result := MakeInt(nb, m);
  End;
 End;
End;

Function IntNeg(Const a: TVal): TVal;
Var
 na: Boolean;
 ma: TMag;
Begin
 If (a.k <> vkObj) And (a.i <> Low(Int64)) Then Begin
  Result := VInt(-a.i);
  Exit;
 End;
 IntToMag(a, na, ma);
 Result := MakeInt(Not na, ma);
End;

Function IntSub(Const a, b: TVal): TVal;
Var
 r: Int64;
Begin
 If (a.k <> vkObj) And (b.k <> vkObj) Then Begin
  r := a.i - b.i;
  If ((a.i Xor b.i) And (a.i Xor r)) >= 0 Then Begin
   Result := VInt(r);
   Exit;
  End;
 End;
 Result := IntAdd(a, IntNeg(b));
End;

Function IntMul(Const a, b: TVal): TVal;
Var
 na, nb: Boolean;
 ma, mb, m: TMag;
 r: Int64;
Begin
 If (a.k <> vkObj) And (b.k <> vkObj) Then Begin
  If (a.i = 0) Or (b.i = 0) Then Begin
   Result := VInt(0);
   Exit;
  End;
  If (Abs(a.i) < $80000000) And (Abs(b.i) < $80000000) Then Begin
   Result := VInt(a.i * b.i);
   Exit;
  End;
  If (a.i <> -1) And (b.i <> -1) Then Begin
   r := a.i * b.i;
   If (r Div b.i = a.i) And (r Div a.i = b.i) Then Begin
    Result := VInt(r);
    Exit;
   End;
  End
  Else If a.i = -1 Then Begin
   If b.i <> Low(Int64) Then Begin
    Result := VInt(-b.i);
    Exit;
   End;
  End
  Else If a.i <> Low(Int64) Then Begin
   Result := VInt(-a.i);
   Exit;
  End;
 End;
 IntToMag(a, na, ma);
 IntToMag(b, nb, mb);
 m := MagMul(ma, mb);
 Result := MakeInt(na <> nb, m);
End;

{ Division plancher : q, r }
Procedure IntDivMod(Const a, b: TVal; Var q, r: TVal);
Var
 qq, rr: Int64;
 na, nb: Boolean;
 ma, mb, mq, mr: TMag;
 one: TMag;
Begin
 If IntSign(b) = 0 Then
  RaiseExc(exZeroDivision, 'integer division or modulo by zero');
 If (a.k <> vkObj) And (b.k <> vkObj) And Not
  ((a.i = Low(Int64)) And (b.i = -1)) Then Begin
  qq := a.i Div b.i;
  rr := a.i Mod b.i;
  If (rr <> 0) And ((rr < 0) <> (b.i < 0)) Then Begin
   Dec(qq);
   rr := rr + b.i;
  End;
  q := VInt(qq);
  r := VInt(rr);
  Exit;
 End;
 IntToMag(a, na, ma);
 IntToMag(b, nb, mb);
 MagDivMod(ma, mb, mq, mr);
 If na <> nb Then Begin
  If Length(mr) <> 0 Then Begin
   one := MagFromQ(1);
   mq := MagAdd(mq, one);
   mr := MagSub(mb, mr);
  End;
  q := MakeInt(True, mq);
 End
 Else q := MakeInt(False, mq);
 If nb Then Begin
  If Length(mr) = 0 Then r := VInt(0) Else r := MakeInt(True, mr);
 End
 Else r := MakeInt(False, mr);
End;

Function IntFloorDiv(Const a, b: TVal): TVal;
Var
 q, r: TVal;
Begin
 IntDivMod(a, b, q, r);
 Result := q;
End;

Function IntMod(Const a, b: TVal): TVal;
Var
 q, r: TVal;
Begin
 IntDivMod(a, b, q, r);
 Result := r;
End;

Function IntPow(Const a, e: TVal): TVal;
Var
 ex: Int64;
 base, res: TVal;
Begin
 If e.k = vkObj Then Begin
  If (a.k <> vkObj) And ((a.i = 0) Or (a.i = 1)) Then Begin
   Result := a;
   Exit;
  End;
  If (a.k <> vkObj) And (a.i = -1) Then Begin
   If (TPyBigInt(e.o).mag[0] And 1) = 1 Then Result := a
   Else Result := VInt(1);
   Exit;
  End;
  RaiseExc(exOverflow, 'exponent too large');
 End;
 ex := e.i;
 res := VInt(1);
 base := a;
 While ex > 0 Do Begin
  If (ex And 1) = 1 Then res := IntMul(res, base);
  ex := ex Shr 1;
  If ex > 0 Then base := IntMul(base, base);
 End;
 Result := res;
End;

Function IntPowMod(Const a, e, m: TVal): TVal;
Var
 ex, res, base, two, q, r, q2, t: TVal;
Begin
 res := VInt(1);
 IntDivMod(a, m, q, base);
 ex := e;
 two := VInt(2);
 While IntSign(ex) > 0 Do Begin
  IntDivMod(ex, two, q, r);
  If r.i = 1 Then Begin
   IntDivMod(IntMul(res, base), m, q2, t);
   res := t;
  End;
  ex := q;
  If IntSign(ex) > 0 Then Begin
   IntDivMod(IntMul(base, base), m, q2, t);
   base := t;
  End;
 End;
 IntDivMod(res, m, q, r);
 Result := r;
End;

{ complement a deux sur n limbes }
Procedure TwosComp(Const v: TVal; n: Integer; Var out: TMag);
Var
 neg: Boolean;
 m: TMag;
 i: Integer;
 c: QWord;
Begin
 IntToMag(v, neg, m);
 SetLength(out, n);
 For i := 0 To n - 1 Do
  If i < Length(m) Then out[i] := m[i] Else out[i] := 0;
 If neg And (Length(m) > 0) Then Begin
  c := 1;
  For i := 0 To n - 1 Do Begin
   c := c + (Not out[i] And $FFFFFFFF);
   out[i] := Cardinal(c And $FFFFFFFF);
   c := c Shr 32;
  End;
 End;
End;

Function FromTwos(Var t: TMag): TVal;
Var
 n, i: Integer;
 neg: Boolean;
 c: QWord;
Begin
 n := Length(t);
 neg := (t[n - 1] And $80000000) <> 0;
 If neg Then Begin
  c := 1;
  For i := 0 To n - 1 Do Begin
   c := c + (Not t[i] And $FFFFFFFF);
   t[i] := Cardinal(c And $FFFFFFFF);
   c := c Shr 32;
  End;
 End;
 Result := MakeInt(neg, t);
End;

Function IntBitOp(Const a, b: TVal; op: Char): TVal;
Var
 n, i: Integer;
 ta, tb, tr: TMag;
Begin
 If (a.k <> vkObj) And (b.k <> vkObj) Then Begin
  Case op Of
   '&': Result := VInt(a.i And b.i);
   '|': Result := VInt(a.i Or b.i);
  Else Result := VInt(a.i Xor b.i);
  End;
  Exit;
 End;
 n := 1;
 If a.k = vkObj Then n := Length(TPyBigInt(a.o).mag) + 1;
 If (b.k = vkObj) And (Length(TPyBigInt(b.o).mag) + 1 > n) Then
  n := Length(TPyBigInt(b.o).mag) + 1;
 If n < 3 Then n := 3;
 TwosComp(a, n, ta);
 TwosComp(b, n, tb);
 SetLength(tr, n);
 For i := 0 To n - 1 Do
  Case op Of
   '&': tr[i] := ta[i] And tb[i];
   '|': tr[i] := ta[i] Or tb[i];
  Else tr[i] := ta[i] Xor tb[i];
  End;
 Result := FromTwos(tr);
End;

Function IntInvert(Const a: TVal): TVal;
Begin
 Result := IntSub(IntNeg(a), VInt(1));
End;

Function IntShl(Const a: TVal; n: Int64): TVal;
Var
 na: Boolean;
 ma, m: TMag;
Begin
 If (a.k <> vkObj) And (n < 62) And (Abs(a.i) < (Int64(1) Shl (62 - n)))
  Then Begin
  Result := VInt(a.i Shl n);
  Exit;
 End;
 IntToMag(a, na, ma);
 m := MagShl(ma, n);
 Result := MakeInt(na, m);
End;

Function IntShr(Const a: TVal; n: Int64): TVal;
Var
 na: Boolean;
 ma, m, one: TMag;
 lost: Boolean;
 i: Integer;
Begin
 If a.k <> vkObj Then Begin
  If n >= 64 Then Begin
   If a.i < 0 Then Result := VInt(-1) Else Result := VInt(0);
  End
  Else Begin
   If a.i >= 0 Then Result := VInt(a.i Shr n)
   Else Result := VInt(Not ((Not a.i) Shr n));
  End;
  Exit;
 End;
 IntToMag(a, na, ma);
 m := MagShr(ma, n);
 If na Then Begin
  { arrondi vers -infini : si des bits ont ete perdus, ajouter 1 }
  lost := False;
  For i := 0 To Min(n Div 32, Length(ma)) - 1 Do
   If ma[i] <> 0 Then lost := True;
  If (n Mod 32 <> 0) And (n Div 32 < Length(ma)) Then
   If (ma[n Div 32] And ((Cardinal(1) Shl (n Mod 32)) - 1)) <> 0 Then
    lost := True;
  If lost Then Begin
   one := MagFromQ(1);
   m := MagAdd(m, one);
  End;
 End;
 Result := MakeInt(na, m);
End;

Function IntToStrRadix(Const v: TVal; radix: Integer): AnsiString;
Var
 neg: Boolean;
 m: TMag;
Begin
 If (v.k <> vkObj) And (radix = 10) Then Begin
  Result := IntToStr(v.i);
  Exit;
 End;
 IntToMag(v, neg, m);
 Result := MagToStr(m, radix);
 If neg And (Result <> '0') Then Result := '-' + Result;
End;

Function IntToStrVal(Const v: TVal): AnsiString;
Begin
 Result := IntToStrRadix(v, 10);
End;

{ Parse une chaine de chiffres (sans signe) ; ok=False si invalide }
Function ParseIntDigits(Const s: AnsiString; radix: Integer;
 Var ok: Boolean): TVal;
Var
 i, d: Integer;
 c: Char;
 m: TMag;
 x: Int64;
 small: Boolean;
Begin
 ok := False;
 If s = '' Then Begin
  Result := VInt(0);
  Exit;
 End;
 small := Length(s) <= 15;
 x := 0;
 SetLength(m, 0);
 For i := 1 To Length(s) Do Begin
  c := s[i];
  If (c >= '0') And (c <= '9') Then d := Ord(c) - 48
  Else If (c >= 'a') And (c <= 'z') Then d := Ord(c) - 87
  Else If (c >= 'A') And (c <= 'Z') Then d := Ord(c) - 55
  Else Exit;
  If d >= radix Then Exit;
  If small And (radix <= 16) Then x := x * radix + d
  Else Begin
   If small Then Begin
    small := False;
    m := MagFromQ(QWord(x));
   End;
   m := MagMulSmall(m, radix);
   m := MagAddSmall(m, d);
  End;
 End;
 ok := True;
 If small Then Result := VInt(x)
 Else Result := MakeInt(False, m);
End;

Function MagToDouble(Const m: TMag; neg: Boolean): Double;
Var
 bl, sh: Integer;
 t: TMag;
 q: QWord;
 sticky: Boolean;
 i: Integer;
Begin
 bl := MagBitLen(m);
 If bl = 0 Then Begin
  Result := 0;
  Exit;
 End;
 If bl <= 64 Then Begin
  q := m[0];
  If Length(m) > 1 Then q := q Or (QWord(m[1]) Shl 32);
  Result := q;
 End
 Else Begin
  sh := bl - 64;
  t := MagShr(m, sh);
  q := t[0];
  If Length(t) > 1 Then q := q Or (QWord(t[1]) Shl 32);
  sticky := False;
  For i := 0 To (sh Div 32) - 1 Do
   If m[i] <> 0 Then sticky := True;
  If (sh Mod 32) <> 0 Then
   If (m[sh Div 32] And ((Cardinal(1) Shl (sh Mod 32)) - 1)) <> 0 Then
    sticky := True;
  If sticky Then q := q Or 1;
  If bl > 1030 Then
   RaiseExc(exOverflow, 'int too large to convert to float');
  Result := q;
  Result := Ldexp(Result, sh);
  If IsInfinite(Result) Then
   RaiseExc(exOverflow, 'int too large to convert to float');
 End;
 If neg Then Result := -Result;
End;

Function IntToDouble(Const v: TVal): Double;
Var
 neg: Boolean;
 m: TMag;
Begin
 If v.k <> vkObj Then Begin
  Result := v.i;
  Exit;
 End;
 IntToMag(v, neg, m);
 Result := MagToDouble(m, neg);
End;

{ double entier (deja tronque) -> entier Python }
Function DoubleToInt(d: Double): TVal;
Var
 bits: QWord;
 e: Integer;
 mant: QWord;
 m: TMag;
 neg: Boolean;
Begin
 If IsNan(d) Then
  RaiseExc(exValueError, 'cannot convert float NaN to integer');
 If IsInfinite(d) Then
  RaiseExc(exOverflow, 'cannot convert float infinity to integer');
 If Abs(d) < 9.2e18 Then Begin
  Result := VInt(Trunc(d));
  Exit;
 End;
 neg := d < 0;
 bits := PQWord(@d)^;
 e := Integer((bits Shr 52) And $7FF) - 1075;
 mant := (bits And $FFFFFFFFFFFFF) Or (QWord(1) Shl 52);
 m := MagFromQ(mant);
 If e > 0 Then m := MagShl(m, e) Else m := MagShr(m, -e);
 Result := MakeInt(neg, m);
End;

Function IntHash(Const v: TVal): Int64;
Var
 neg: Boolean;
 m, q, r, mod61: TMag;
 x: Int64;
Begin
 If (v.k <> vkObj) And (v.i >= 0) And (v.i < (Int64(1) Shl 61) - 1) Then Begin
  Result := v.i;
  Exit;
 End;
 IntToMag(v, neg, m);
 mod61 := MagFromQ((QWord(1) Shl 61) - 1);
 MagDivMod(m, mod61, q, r);
 x := 0;
 If Length(r) > 0 Then x := r[0];
 If Length(r) > 1 Then x := x Or (Int64(r[1]) Shl 32);
 If neg Then x := -x;
 If x = -1 Then x := -2;
 Result := x;
End;

Function IntBitLength(Const v: TVal): Int64;
Var
 neg: Boolean;
 m: TMag;
Begin
 IntToMag(v, neg, m);
 Result := MagBitLen(m);
End;

{ ------------------------------------------------------------
  Flottants : conversions exactes et formatage
  ------------------------------------------------------------ }
Procedure DblDecompose(d: Double; Var m: QWord; Var e: Integer);
Var
 bits: QWord;
 ex: Integer;
Begin
 bits := PQWord(@d)^;
 ex := Integer((bits Shr 52) And $7FF);
 m := bits And $FFFFFFFFFFFFF;
 If ex = 0 Then e := -1074
 Else Begin
  m := m Or (QWord(1) Shl 52);
  e := ex - 1075;
 End;
End;

{ round-half-even(|d| * 10^s) en decimal }
Function DblDigits(d: Double; s: Integer): AnsiString;
Var
 m: QWord;
 e: Integer;
 num, den, q, r, r2: TMag;
 c: Integer;
Begin
 If d = 0 Then Begin
  Result := '0';
  Exit;
 End;
 DblDecompose(Abs(d), m, e);
 num := MagFromQ(m);
 den := MagFromQ(1);
 If e > 0 Then num := MagShl(num, e)
 Else If e < 0 Then den := MagShl(den, -e);
 If s > 0 Then num := MagMul(num, MagPow10(s))
 Else If s < 0 Then den := MagMul(den, MagPow10(-s));
 MagDivMod(num, den, q, r);
 r2 := MagShl(r, 1);
 c := MagCmp(r2, den);
 If (c > 0) Or ((c = 0) And (Length(q) > 0) And ((q[0] And 1) = 1)) Or
  ((c = 0) And (Length(q) = 0) And False) Then
  q := MagAdd(q, MagFromQ(1));
 Result := MagToStr(q, 10);
End;

{ p+1 chiffres significatifs et exposant decimal E }
Function SciDigits(d: Double; p: Integer; Var E: Integer): AnsiString;
Var
 t: AnsiString;
 guard: Integer;
Begin
 If d = 0 Then Begin
  Result := StringOfChar('0', p + 1);
  E := 0;
  Exit;
 End;
 E := Floor(Log10(Abs(d)));
 guard := 0;
 Repeat
  t := DblDigits(d, p - E);
  If Length(t) > p + 1 Then Inc(E)
  Else If Length(t) < p + 1 Then Dec(E)
  Else Break;
  Inc(guard);
 Until guard > 6;
 If Length(t) > p + 1 Then t := Copy(t, 1, p + 1);
 While Length(t) < p + 1 Do t := t + '0';
 Result := t;
End;

{ chaine decimale -> double, arrondi correct }
Function DigitsToDouble(Const digs: AnsiString; x10: Integer): Double;
Var
 m, num, den, q, r, t: TMag;
 k, bl, sh, i: Integer;
 sticky: Boolean;
 qq: QWord;
Begin
 Result := 0;
 If digs = '' Then Exit;
 m := MagFromQ(0);
 i := 1;
 While i <= Length(digs) Do Begin
  If i + 8 <= Length(digs) Then Begin
   m := MagMulSmall(m, 1000000000);
   m := MagAddSmall(m, StrToInt(Copy(digs, i, 9)));
   Inc(i, 9);
  End
  Else Begin
   m := MagMulSmall(m, 10);
   m := MagAddSmall(m, Ord(digs[i]) - 48);
   Inc(i);
  End;
 End;
 If Length(m) = 0 Then Exit;
 If x10 >= 0 Then Begin
  If x10 > 400 Then Begin
   Result := Infinity;
   Exit;
  End;
  m := MagMul(m, MagPow10(x10));
  If MagBitLen(m) > 1030 Then Begin
   Result := Infinity;
   Exit;
  End;
  Result := MagToDouble(m, False);
  Exit;
 End;
 If -x10 > 800 Then Begin
  Result := 0;
  Exit;
 End;
 den := MagPow10(-x10);
 k := 66 - (MagBitLen(m) - MagBitLen(den));
 If k < 0 Then k := 0;
 num := MagShl(m, k);
 MagDivMod(num, den, q, r);
 sticky := Length(r) > 0;
 bl := MagBitLen(q);
 sh := bl - 64;
 If sh > 0 Then Begin
  For i := 0 To (sh Div 32) - 1 Do
   If q[i] <> 0 Then sticky := True;
  If (sh Mod 32) <> 0 Then
   If (q[sh Div 32] And ((Cardinal(1) Shl (sh Mod 32)) - 1)) <> 0 Then
    sticky := True;
  t := MagShr(q, sh);
 End
 Else Begin
  sh := 0;
  t := q;
 End;
 qq := 0;
 If Length(t) > 0 Then qq := t[0];
 If Length(t) > 1 Then qq := qq Or (QWord(t[1]) Shl 32);
 If sticky Then qq := qq Or 1;
 Result := qq;
 Result := Ldexp(Result, sh - k);
End;

{ Analyse d'un litteral flottant (sans signe, sans soulignement) }
Function ParseFloatStr(Const s0: AnsiString; Var ok: Boolean): Double;
Var
 s, digs: AnsiString;
 i, x10, ex, esign, fr: Integer;
 neg: Boolean;
 seenDigit: Boolean;
Begin
 ok := False;
 Result := 0;
 s := Trim(s0);
 If s = '' Then Exit;
 i := 1;
 neg := False;
 If (s[i] = '+') Or (s[i] = '-') Then Begin
  neg := s[i] = '-';
  Inc(i);
 End;
 If LowerCase(Copy(s, i, 8)) = 'infinity' Then Begin
  If i + 7 = Length(s) Then Begin
   ok := True;
   If neg Then Result := -Infinity Else Result := Infinity;
  End;
  Exit;
 End;
 If LowerCase(Copy(s, i, 3)) = 'inf' Then Begin
  If i + 2 = Length(s) Then Begin
   ok := True;
   If neg Then Result := -Infinity Else Result := Infinity;
  End;
  Exit;
 End;
 If LowerCase(Copy(s, i, 3)) = 'nan' Then Begin
  If i + 2 = Length(s) Then Begin
   ok := True;
   Result := NaN;
  End;
  Exit;
 End;
 digs := '';
 fr := 0;
 seenDigit := False;
 While (i <= Length(s)) And (s[i] In ['0'..'9']) Do Begin
  digs := digs + s[i];
  seenDigit := True;
  Inc(i);
 End;
 If (i <= Length(s)) And (s[i] = '.') Then Begin
  Inc(i);
  While (i <= Length(s)) And (s[i] In ['0'..'9']) Do Begin
   digs := digs + s[i];
   Inc(fr);
   seenDigit := True;
   Inc(i);
  End;
 End;
 If Not seenDigit Then Exit;
 ex := 0;
 If (i <= Length(s)) And (s[i] In ['e', 'E']) Then Begin
  Inc(i);
  esign := 1;
  If (i <= Length(s)) And (s[i] In ['+', '-']) Then Begin
   If s[i] = '-' Then esign := -1;
   Inc(i);
  End;
  If (i > Length(s)) Or Not (s[i] In ['0'..'9']) Then Exit;
  While (i <= Length(s)) And (s[i] In ['0'..'9']) Do Begin
   If ex < 100000 Then ex := ex * 10 + Ord(s[i]) - 48;
   Inc(i);
  End;
  ex := ex * esign;
 End;
 If i <= Length(s) Then Exit;
 ok := True;
 { supprimer les zeros de tete }
 While (Length(digs) > 1) And (digs[1] = '0') Do Delete(digs, 1, 1);
 x10 := ex - fr;
 { supprimer les zeros de fin }
 While (Length(digs) > 1) And (digs[Length(digs)] = '0') Do Begin
  Delete(digs, Length(digs), 1);
  Inc(x10);
 End;
 If digs = '0' Then Result := 0
 Else Result := DigitsToDouble(digs, x10);
 If neg Then Result := -Result;
End;

Function FloatSignBit(d: Double): Boolean;
Begin
 Result := (PQWord(@d)^ Shr 63) = 1;
End;

Function ExpStr(E: Integer): AnsiString;
Begin
 If E < 0 Then Result := '-' Else Result := '+';
 If Abs(E) < 10 Then Result := Result + '0';
 Result := Result + IntToStr(Abs(E));
End;

Function FloatRepr(d: Double): AnsiString;
Var
 digs: AnsiString;
 E, p, n, i: Integer;
 ok: Boolean;
 back: Double;
 neg: Boolean;
Begin
 If IsNan(d) Then Begin
  Result := 'nan';
  Exit;
 End;
 If IsInfinite(d) Then Begin
  If d < 0 Then Result := '-inf' Else Result := 'inf';
  Exit;
 End;
 neg := FloatSignBit(d);
 If d = 0 Then Begin
  If neg Then Result := '-0.0' Else Result := '0.0';
  Exit;
 End;
 p := 14;
 Repeat
  digs := SciDigits(Abs(d), p, E);
  back := ParseFloatStr(Copy(digs, 1, 1) + '.' + Copy(digs, 2, 40) +
   'e' + IntToStr(E), ok);
  If back = Abs(d) Then Break;
  Inc(p);
 Until p >= 16;
 If p >= 16 Then digs := SciDigits(Abs(d), 16, E);
 n := Length(digs);
 While (n > 1) And (digs[n] = '0') Do Dec(n);
 digs := Copy(digs, 1, n);
 If (E >= -4) And (E < 16) Then Begin
  If E >= n - 1 Then
   Result := digs + StringOfChar('0', E - n + 1) + '.0'
  Else If E >= 0 Then
   Result := Copy(digs, 1, E + 1) + '.' + Copy(digs, E + 2, 40)
  Else
   Result := '0.' + StringOfChar('0', -E - 1) + digs;
 End
 Else Begin
  Result := Copy(digs, 1, 1);
  If n > 1 Then Result := Result + '.' + Copy(digs, 2, 40);
  Result := Result + 'e' + ExpStr(E);
 End;
 If neg Then Result := '-' + Result;
 i := 0;
 If i = 1 Then Result := '';
End;

{ 'f' : prec chiffres apres le point (valeur absolue, sans signe) }
Function FmtFixed(d: Double; prec: Integer): AnsiString;
Var
 t: AnsiString;
Begin
 t := DblDigits(d, prec);
 If prec = 0 Then Begin
  Result := t;
  Exit;
 End;
 While Length(t) <= prec Do t := '0' + t;
 Result := Copy(t, 1, Length(t) - prec) + '.' + Copy(t, Length(t) - prec +
  1, prec);
End;

Function FmtExp(d: Double; prec: Integer; upper, alt: Boolean): AnsiString;
Var
 digs: AnsiString;
 E: Integer;
Begin
 digs := SciDigits(Abs(d), prec, E);
 Result := Copy(digs, 1, 1);
 If (prec > 0) Or alt Then Result := Result + '.';
 Result := Result + Copy(digs, 2, prec);
 If upper Then Result := Result + 'E' Else Result := Result + 'e';
 Result := Result + ExpStr(E);
End;

Function FmtGeneral(d: Double; prec: Integer; upper, alt, pyDefault:
 Boolean): AnsiString;
Var
 digs: AnsiString;
 E, p: Integer;
 s: AnsiString;
Begin
 p := prec;
 If p = 0 Then p := 1;
 If d = 0 Then E := 0 Else SciDigits(Abs(d), p - 1, E);
 If (E >= -4) And (E < p) Then Begin
  s := FmtFixed(Abs(d), p - 1 - E);
  If Not alt And (Pos('.', s) > 0) Then Begin
   While s[Length(s)] = '0' Do Delete(s, Length(s), 1);
   If s[Length(s)] = '.' Then Delete(s, Length(s), 1);
  End;
  If pyDefault And (Pos('.', s) = 0) Then s := s + '.0';
  Result := s;
 End
 Else Begin
  s := FmtExp(Abs(d), p - 1, upper, alt);
  If Not alt Then Begin
   { retirer les zeros de la mantisse }
   digs := Copy(s, 1, Pos(Chr(Ord('e') - Ord(upper) * 32), s) - 1);
   If Pos('.', digs) > 0 Then Begin
    While digs[Length(digs)] = '0' Do Delete(digs, Length(digs), 1);
    If digs[Length(digs)] = '.' Then Delete(digs, Length(digs), 1);
   End;
   s := digs + Copy(s, Pos(Chr(Ord('e') - Ord(upper) * 32), s), 20);
  End;
  Result := s;
 End;
End;

{ ------------------------------------------------------------
  Mini-langage de format : [[fill]align][sign][#][0][width][,_][.prec][type]
  ------------------------------------------------------------ }
Type
 TFmtSpec = Record
  fill: AnsiString;
  align: Char;
  sign: Char;
  alt, zero: Boolean;
  width: Integer;
  grp: Char;
  prec: Integer;
  typ: Char;
 End;

Procedure ParseFmtSpec(Const spec: AnsiString; Var fs: TFmtSpec);
Var
 i, j, n: Integer;
 cps: TCpArr;
 c: Cardinal;
Begin
 fs.fill := ' ';
 fs.align := #0;
 fs.sign := '-';
 fs.alt := False;
 fs.zero := False;
 fs.width := 0;
 fs.grp := #0;
 fs.prec := -1;
 fs.typ := #0;
 cps := StrToCps(spec);
 n := Length(cps);
 i := 0;
 If n = 0 Then Exit;
 If (n >= 2) And (cps[1] < 128) And (Chr(cps[1]) In ['<', '>', '^', '=']) Then
  Begin
  fs.fill := Utf8Enc(cps[0]);
  fs.align := Chr(cps[1]);
  i := 2;
 End
 Else If (cps[0] < 128) And (Chr(cps[0]) In ['<', '>', '^', '=']) Then
  Begin
  fs.align := Chr(cps[0]);
  i := 1;
 End;
 If (i < n) And (cps[i] < 128) And (Chr(cps[i]) In ['+', '-', ' ']) Then Begin
  fs.sign := Chr(cps[i]);
  Inc(i);
 End;
 If (i < n) And (cps[i] = Ord('#')) Then Begin
  fs.alt := True;
  Inc(i);
 End;
 If (i < n) And (cps[i] = Ord('0')) Then Begin
  fs.zero := True;
  Inc(i);
 End;
 j := 0;
 While (i < n) And (cps[i] >= 48) And (cps[i] <= 57) Do Begin
  j := j * 10 + Integer(cps[i]) - 48;
  Inc(i);
 End;
 fs.width := j;
 If (i < n) And ((cps[i] = Ord(',')) Or (cps[i] = Ord('_'))) Then Begin
  fs.grp := Chr(cps[i]);
  Inc(i);
 End;
 If (i < n) And (cps[i] = Ord('.')) Then Begin
  Inc(i);
  j := 0;
  If (i >= n) Or (cps[i] < 48) Or (cps[i] > 57) Then
   RaiseExc(exValueError, 'Format specifier missing precision');
  While (i < n) And (cps[i] >= 48) And (cps[i] <= 57) Do Begin
   j := j * 10 + Integer(cps[i]) - 48;
   Inc(i);
  End;
  fs.prec := j;
 End;
 If i < n Then Begin
  c := cps[i];
  If c < 128 Then fs.typ := Chr(c)
  Else RaiseExc(exValueError, 'Invalid format specifier');
  Inc(i);
 End;
 If i < n Then RaiseExc(exValueError, 'Invalid format specifier');
End;

Function RepeatStr(Const s: AnsiString; n: Integer): AnsiString;
Var
 i: Integer;
Begin
 Result := '';
 For i := 1 To n Do Result := Result + s;
End;

Function PadStr(Const body: AnsiString; width: Integer;
 Const fill: AnsiString; align: Char): AnsiString;
Var
 n, padn, l: Integer;
Begin
 n := Utf8Len(body);
 If n >= width Then Begin
  Result := body;
  Exit;
 End;
 padn := width - n;
 Case align Of
  '<': l := 0;
  '^': l := padn Div 2;
 Else l := padn;
 End;
 Result := RepeatStr(fill, l) + body + RepeatStr(fill, padn - l);
End;

Function GroupDigits(Const digs: AnsiString; sep: Char; gsz: Integer):
 AnsiString;
Var
 i, c: Integer;
Begin
 Result := '';
 c := 0;
 For i := Length(digs) DownTo 1 Do Begin
  If (c > 0) And (c Mod gsz = 0) Then Result := sep + Result;
  Result := digs[i] + Result;
  Inc(c);
 End;
End;

{ assemble signe, prefixe, partie entiere, reste ; applique largeur }
Function AssembleNum(neg: Boolean; Const prefix, ipart, rest: AnsiString;
 Const fs: TFmtSpec; defAlign: Char): AnsiString;
Var
 sg, body, ip: AnsiString;
 al: Char;
 fillc: AnsiString;
 total, z: Integer;
Begin
 If neg Then sg := '-'
 Else If fs.sign = '+' Then sg := '+'
 Else If fs.sign = ' ' Then sg := ' '
 Else sg := '';
 ip := ipart;
 If fs.grp <> #0 Then Begin
  If (fs.typ In ['b', 'o', 'x', 'X']) Then ip := GroupDigits(ip, '_', 4)
  Else ip := GroupDigits(ip, fs.grp, 3);
 End;
 al := fs.align;
 fillc := fs.fill;
 If fs.zero And (al = #0) Then Begin
  al := '=';
  fillc := '0';
 End;
 If al = #0 Then al := defAlign;
 If al = '=' Then Begin
  total := Utf8Len(sg + prefix + ip + rest);
  z := fs.width - total;
  If z < 0 Then z := 0;
  Result := sg + prefix + RepeatStr(fillc, z) + ip + rest;
  Exit;
 End;
 body := sg + prefix + ip + rest;
 Result := PadStr(body, fs.width, fillc, al);
End;

Function FormatIntSpec(Const v: TVal; Const fs: TFmtSpec): AnsiString;
Var
 neg: Boolean;
 m: TMag;
 digs, prefix: AnsiString;
 t: Char;
Begin
 t := fs.typ;
 If t In ['e', 'E', 'f', 'F', 'g', 'G', '%'] Then Begin
  Result := '';
  Exit;
 End;
 IntToMag(v, neg, m);
 prefix := '';
 Case t Of
  'b': Begin digs := MagToStr(m, 2); If fs.alt Then prefix := '0b'; End;
  'o': Begin digs := MagToStr(m, 8); If fs.alt Then prefix := '0o'; End;
  'x': Begin digs := MagToStr(m, 16); If fs.alt Then prefix := '0x'; End;
  'X': Begin
        digs := UpperCase(MagToStr(m, 16));
        If fs.alt Then prefix := '0X';
       End;
  'c': Begin
        Result := PadStr(Utf8Enc(Cardinal(v.i)), fs.width, fs.fill,
         fs.align);
        Exit;
       End;
 Else digs := MagToStr(m, 10);
 End;
 Result := AssembleNum(neg And (Length(m) > 0), prefix, digs, '', fs, '>');
End;

Function FormatFloatSpec(d: Double; Const fs: TFmtSpec): AnsiString;
Var
 t: Char;
 neg: Boolean;
 body, ip, rest: AnsiString;
 p, k: Integer;
 up: Boolean;
Begin
 t := fs.typ;
 neg := FloatSignBit(d) And Not IsNan(d);
 up := t In ['E', 'F', 'G'];
 If IsNan(d) Or IsInfinite(d) Then Begin
  If IsNan(d) Then body := 'nan' Else body := 'inf';
  If up Then body := UpperCase(body);
  If t = '%' Then body := body + '%';
  Result := AssembleNum(neg, '', body, '', fs, '>');
  Exit;
 End;
 p := fs.prec;
 Case t Of
  'f', 'F': Begin
    If p < 0 Then p := 6;
    body := FmtFixed(d, p);
    If (p = 0) And fs.alt Then body := body + '.';
   End;
  'e', 'E': Begin
    If p < 0 Then p := 6;
    body := FmtExp(d, p, up, fs.alt);
   End;
  'g', 'G': Begin
    If p < 0 Then p := 6;
    body := FmtGeneral(d, p, up, fs.alt, False);
   End;
  '%': Begin
    If p < 0 Then p := 6;
    body := FmtFixed(d * 100, p) + '%';
   End;
 Else
  If p < 0 Then Begin
   body := FloatRepr(Abs(d));
  End
  Else body := FmtGeneral(d, p, False, fs.alt, True);
 End;
 { separer partie entiere / reste }
 k := 1;
 While (k <= Length(body)) And (body[k] In ['0'..'9']) Do Inc(k);
 ip := Copy(body, 1, k - 1);
 rest := Copy(body, k, Length(body));
 Result := AssembleNum(neg, '', ip, rest, fs, '>');
End;

Function FormatStrSpec(Const s: AnsiString; Const fs: TFmtSpec): AnsiString;
Var
 body: AnsiString;
 al: Char;
Begin
 If (fs.typ <> #0) And (fs.typ <> 's') Then
  RaiseExc(exValueError, 'Unknown format code ''' + fs.typ +
   ''' for object of type ''str''');
 If fs.sign <> '-' Then
  RaiseExc(exValueError, 'Sign not allowed in string format specifier');
 If fs.align = '=' Then
  RaiseExc(exValueError,
   '''='' alignment not allowed in string format specifier');
 body := s;
 If (fs.prec >= 0) And (Utf8Len(body) > fs.prec) Then
  body := CpSub(body, 0, fs.prec);
 al := fs.align;
 If al = #0 Then al := '<';
 Result := PadStr(body, fs.width, fs.fill, al);
End;

{ ------------------------------------------------------------
  repr des chaines
  ------------------------------------------------------------ }
Function StrReprEsc(Const s: AnsiString; asciiOnly: Boolean): AnsiString;
Var
 q: Char;
 i: Integer;
 c: Cardinal;
 r: AnsiString;
Begin
 q := '''';
 If (Pos('''', s) > 0) And (Pos('"', s) = 0) Then q := '"';
 r := q;
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  If (c = Ord(q)) Or (c = 92) Then r := r + '\' + Chr(c)
  Else If c = 10 Then r := r + '\n'
  Else If c = 13 Then r := r + '\r'
  Else If c = 9 Then r := r + '\t'
  Else If (c < 32) Or (c = 127) Then r := r + '\x' + LowerCase(IntToHex(c,
   2))
  Else If c < 127 Then r := r + Chr(c)
  Else If (c < 256) And (asciiOnly Or Not CpIsPrintable(c)) Then
   r := r + '\x' + LowerCase(IntToHex(c, 2))
  Else If asciiOnly Or Not CpIsPrintable(c) Then Begin
   If c < $10000 Then r := r + '\u' + LowerCase(IntToHex(c, 4))
   Else r := r + '\U' + LowerCase(IntToHex(c, 8));
  End
  Else r := r + Utf8Enc(c);
 End;
 Result := r + q;
End;

Function BytesReprEsc(Const s: AnsiString): AnsiString;
Var
 q: Char;
 i: Integer;
 c: Byte;
 r: AnsiString;
Begin
 q := '''';
 If (Pos('''', s) > 0) And (Pos('"', s) = 0) Then q := '"';
 r := 'b' + q;
 For i := 1 To Length(s) Do Begin
  c := Ord(s[i]);
  If (c = Ord(q)) Or (c = 92) Then r := r + '\' + Chr(c)
  Else If c = 10 Then r := r + '\n'
  Else If c = 13 Then r := r + '\r'
  Else If c = 9 Then r := r + '\t'
  Else If (c < 32) Or (c >= 127) Then r := r + '\x' + LowerCase(IntToHex(c,
   2))
  Else r := r + Chr(c);
 End;
 Result := r + q;
End;

{ ------------------------------------------------------------
  Analyse lexicale
  ------------------------------------------------------------ }
Const
 tkEOF = 0;
 tkNewline = 1;
 tkIndent = 2;
 tkDedent = 3;
 tkName = 4;
 tkNumber = 5;
 tkString = 6;
 tkOp = 7;

 tfBytes = 1;
 tfRaw = 2;
 tfFStr = 4;
 tfFloat = 1;
 tfImag = 2;

Type
 TToken = Record
  kind: Integer;
  s: AnsiString;
  line, col: Integer;
  flags: Integer;
  v: TVal;
 End;
 TTokArr = Array Of TToken;

 ESyntax = Class(Exception)
  kind: TPyType;
  msg: AnsiString;
  line, col: Integer;
  text: AnsiString;
  incomplete: Boolean;
 End;

Var
 SrcLines: TStrArr;
 SrcFile: AnsiString;

Procedure SetSourceLines(Const src: AnsiString);
Var
 i, st, n: Integer;
Begin
 SetLength(SrcLines, 0);
 n := 0;
 st := 1;
 For i := 1 To Length(src) + 1 Do
  If (i > Length(src)) Or (src[i] = #10) Then Begin
   If (i <= Length(src)) Or (i > st) Then Begin
    SetLength(SrcLines, n + 1);
    SrcLines[n] := Copy(src, st, i - st);
    Inc(n);
   End;
   st := i + 1;
  End;
End;

Procedure SynErr(Const msg: AnsiString; line, col: Integer;
 incomplete: Boolean = False; k: TPyType = Nil);
Var
 e: ESyntax;
Begin
 e := ESyntax.Create(msg);
 If k = Nil Then e.kind := exSyntaxError Else e.kind := k;
 e.msg := msg;
 e.line := line;
 e.col := col;
 e.incomplete := incomplete;
 If (line >= 1) And (line <= Length(SrcLines)) Then
  e.text := SrcLines[line - 1]
 Else e.text := '';
 Raise e;
End;

Function IsIdStart(c: Char): Boolean; Inline;
Begin
 Result := (c In ['a'..'z', 'A'..'Z', '_']) Or (Ord(c) >= 128);
End;

Function IsIdChar(c: Char): Boolean; Inline;
Begin
 Result := (c In ['a'..'z', 'A'..'Z', '_', '0'..'9']) Or (Ord(c) >= 128);
End;

Function NormalizeSource(Const s: AnsiString): AnsiString;
Var
 i, j: Integer;
Begin
 SetLength(Result, Length(s) + 1);
 j := 0;
 i := 1;
 If (Length(s) >= 3) And (s[1] = #$EF) And (s[2] = #$BB) And
  (s[3] = #$BF) Then i := 4;
 While i <= Length(s) Do Begin
  If s[i] = #13 Then Begin
   Inc(j);
   Result[j] := #10;
   If (i < Length(s)) And (s[i + 1] = #10) Then Inc(i);
  End
  Else Begin
   Inc(j);
   Result[j] := s[i];
  End;
  Inc(i);
 End;
 SetLength(Result, j);
 If (j > 0) And (Result[j] <> #10) Then Result := Result + #10;
End;

Procedure Tokenize(Const src: AnsiString; Var toks: TTokArr);
Var
 n, i, line, ls, depth, col, j, ntok, k, q: Integer;
 indents: Array Of Integer;
 ni: Integer;
 atStart: Boolean;
 c: Char;
 id, t: AnsiString;
 quote: Char;
 triple, bracketOpen: Boolean;
 flags: Integer;
 ok: Boolean;
 pending: Integer;
 lastKind: Integer;

 Procedure Emit(kind: Integer; Const s: AnsiString; ln, cl: Integer);
 Begin
  If ntok >= Length(toks) Then SetLength(toks, (ntok + 16) * 2);
  toks[ntok].kind := kind;
  toks[ntok].s := s;
  toks[ntok].line := ln;
  toks[ntok].col := cl;
  toks[ntok].flags := 0;
  toks[ntok].v := vNull;
  Inc(ntok);
 End;

 Procedure LexNumber;
 Var
  st, base: Integer;
  txt: AnsiString;
  isf, isim: Boolean;
  v: TVal;
  d: Double;
  okk: Boolean;
 Begin
  st := i;
  isf := False;
  isim := False;
  base := 10;
  If (src[i] = '0') And (i < n) And (src[i + 1] In ['x', 'X', 'o', 'O', 'b',
   'B']) Then Begin
   Case src[i + 1] Of
    'x', 'X': base := 16;
    'o', 'O': base := 8;
   Else base := 2;
   End;
   Inc(i, 2);
   txt := '';
   While (i <= n) And (src[i] In ['0'..'9', 'a'..'f', 'A'..'F', '_']) Do Begin
    If src[i] <> '_' Then txt := txt + src[i];
    Inc(i);
   End;
   v := ParseIntDigits(txt, base, okk);
   If Not okk Or (txt = '') Then
    SynErr('invalid syntax', line, st - ls - 1);
  End
  Else Begin
   txt := '';
   While (i <= n) And (src[i] In ['0'..'9', '_']) Do Begin
    If src[i] <> '_' Then txt := txt + src[i];
    Inc(i);
   End;
   If (i <= n) And (src[i] = '.') Then Begin
    isf := True;
    txt := txt + '.';
    Inc(i);
    While (i <= n) And (src[i] In ['0'..'9', '_']) Do Begin
     If src[i] <> '_' Then txt := txt + src[i];
     Inc(i);
    End;
   End;
   If (i <= n) And (src[i] In ['e', 'E']) And ((i < n) And ((src[i + 1] In
    ['0'..'9']) Or ((src[i + 1] In ['+', '-']) And (i + 1 < n) And
    (src[i + 2] In ['0'..'9'])))) Then Begin
    isf := True;
    txt := txt + 'e';
    Inc(i);
    If src[i] In ['+', '-'] Then Begin
     txt := txt + src[i];
     Inc(i);
    End;
    While (i <= n) And (src[i] In ['0'..'9', '_']) Do Begin
     If src[i] <> '_' Then txt := txt + src[i];
     Inc(i);
    End;
   End;
   If (i <= n) And (src[i] In ['j', 'J']) Then Begin
    isim := True;
    Inc(i);
   End;
   If isf Or isim Then Begin
    d := ParseFloatStr(txt, okk);
    If Not okk Then SynErr('invalid syntax', line, st - ls - 1);
    v := VFloat(d);
   End
   Else Begin
    If (Length(txt) > 1) And (txt[1] = '0') And (Trim(txt) <> StringOfChar(
     '0', Length(txt))) Then
     SynErr('leading zeros in decimal integer literals are not permitted' +
      '; use an 0o prefix for octal integers', line, st - ls - 1);
    v := ParseIntDigits(txt, 10, okk);
   End;
  End;
  If (i <= n) And IsIdChar(src[i]) Then
   SynErr('invalid syntax', line, st - ls - 1);
  Emit(tkNumber, Copy(src, st, i - st), line, st - ls - 1);
  toks[ntok - 1].v := v;
  If isf Then toks[ntok - 1].flags := tfFloat;
  If isim Then toks[ntok - 1].flags := tfImag;
 End;

 Procedure LexString(prefixLen: Integer; st: Integer; fl: Integer);
 Var
  qpos, startLine, cl: Integer;
  raw: AnsiString;
  closed: Boolean;
 Begin
  startLine := line;
  cl := st - ls - 1;
  qpos := st + prefixLen;
  quote := src[qpos];
  triple := (qpos + 2 <= n) And (src[qpos + 1] = quote) And
   (src[qpos + 2] = quote);
  If triple Then i := qpos + 3 Else i := qpos + 1;
  raw := '';
  closed := False;
  While i <= n Do Begin
   c := src[i];
   If c = '\' Then Begin
    If i < n Then Begin
     raw := raw + c + src[i + 1];
     If src[i + 1] = #10 Then Begin
      Inc(line);
      ls := i + 1;
     End;
     Inc(i, 2);
    End
    Else Begin
     raw := raw + c;
     Inc(i);
    End;
    Continue;
   End;
   If c = quote Then Begin
    If Not triple Then Begin
     closed := True;
     Inc(i);
     Break;
    End;
    If (i + 2 <= n) And (src[i + 1] = quote) And (src[i + 2] = quote) Then
     Begin
     closed := True;
     Inc(i, 3);
     Break;
    End;
   End;
   If c = #10 Then Begin
    If Not triple Then
     SynErr('EOL while scanning string literal', line, cl);
    Inc(line);
    ls := i + 1;
   End;
   raw := raw + c;
   Inc(i);
  End;
  If Not closed Then Begin
   If triple Then
    SynErr('EOF while scanning triple-quoted string literal', startLine,
     cl, True)
   Else SynErr('EOL while scanning string literal', startLine, cl);
  End;
  Emit(tkString, raw, startLine, cl);
  toks[ntok - 1].flags := fl;
 End;

 Procedure LexOp;
 Var
  op: AnsiString;
  m: Integer;
 Begin
  op := '';
  If i + 2 <= n Then Begin
   t := Copy(src, i, 3);
   If (t = '**=') Or (t = '//=') Or (t = '>>=') Or (t = '<<=') Or
    (t = '...') Then op := t;
  End;
  If (op = '') And (i + 1 <= n) Then Begin
   t := Copy(src, i, 2);
   If (t = '**') Or (t = '//') Or (t = '>>') Or (t = '<<') Or (t = '<=') Or
    (t = '>=') Or (t = '==') Or (t = '!=') Or (t = '+=') Or (t = '-=') Or
    (t = '*=') Or (t = '/=') Or (t = '%=') Or (t = '&=') Or (t = '|=') Or
    (t = '^=') Or (t = '@=') Or (t = '->') Or (t = ':=') Or (t = '<>')
    Then op := t;
  End;
  If op = '' Then Begin
   If src[i] In ['+', '-', '*', '/', '%', '@', '&', '|', '^', '~', '<', '>',
    '(', ')', '[', ']', '{', '}', ',', ':', '.', ';', '='] Then
    op := src[i]
   Else If src[i] = '!' Then
    SynErr('invalid syntax', line, i - ls - 1)
   Else If src[i] = '$' Then
    SynErr('invalid syntax', line, i - ls - 1)
   Else If src[i] = '?' Then
    SynErr('invalid syntax', line, i - ls - 1)
   Else
    SynErr('invalid character in identifier', line, i - ls - 1);
  End;
  m := Length(op);
  If (op = '(') Or (op = '[') Or (op = '{') Then Inc(depth)
  Else If (op = ')') Or (op = ']') Or (op = '}') Then Begin
   If depth > 0 Then Dec(depth)
   Else SynErr('invalid syntax', line, i - ls - 1);
  End;
  Emit(tkOp, op, line, i - ls - 1);
  Inc(i, m);
 End;

Begin
 n := Length(src);
 ntok := 0;
 SetLength(toks, 64);
 SetLength(indents, 32);
 ni := 1;
 indents[0] := 0;
 i := 1;
 line := 1;
 ls := 0;
 depth := 0;
 atStart := True;
 lastKind := tkNewline;
 bracketOpen := False;
 pending := 0;
 While i <= n Do Begin
  If atStart And (depth = 0) Then Begin
   col := 0;
   j := i;
   While (j <= n) And (src[j] In [' ', #9, #12]) Do Begin
    If src[j] = #9 Then col := (col Div 8 + 1) * 8
    Else If src[j] = #12 Then col := 0
    Else Inc(col);
    Inc(j);
   End;
   If (j > n) Then Begin
    i := j;
    Break;
   End;
   If src[j] = #10 Then Begin
    i := j + 1;
    Inc(line);
    ls := j;
    Continue;
   End;
   If src[j] = '#' Then Begin
    While (j <= n) And (src[j] <> #10) Do Inc(j);
    i := j + 1;
    Inc(line);
    ls := j;
    Continue;
   End;
   If (src[j] = '\') And (j < n) And (src[j + 1] = #10) Then Begin
    { ligne continuee au debut : traitee comme un espace }
    i := j + 2;
    Inc(line);
    ls := j + 1;
    Continue;
   End;
   i := j;
   If col > indents[ni - 1] Then Begin
    If ni >= Length(indents) Then SetLength(indents, ni * 2);
    indents[ni] := col;
    Inc(ni);
    Emit(tkIndent, '', line, 0);
   End
   Else Begin
    While col < indents[ni - 1] Do Begin
     Dec(ni);
     Emit(tkDedent, '', line, 0);
    End;
    If col <> indents[ni - 1] Then
     SynErr('unindent does not match any outer indentation level', line,
      col, False, exIndentationError);
   End;
   atStart := False;
  End;
  If i > n Then Break;
  c := src[i];
  Case c Of
   ' ', #9, #12: Inc(i);
   '#': Begin
     While (i <= n) And (src[i] <> #10) Do Inc(i);
    End;
   #10: Begin
     If depth > 0 Then Begin
      Inc(i);
      Inc(line);
      ls := i - 1;
     End
     Else Begin
      If ntok > 0 Then Emit(tkNewline, '', line, i - ls - 1);
      Inc(i);
      Inc(line);
      ls := i - 1;
      atStart := True;
     End;
    End;
   '\': Begin
     If (i < n) And (src[i + 1] = #10) Then Begin
      Inc(i, 2);
      Inc(line);
      ls := i - 1;
      If i > n Then
       SynErr('unexpected EOF while parsing', line, 0, True);
     End
     Else SynErr('unexpected character after line continuation character',
       line, i - ls - 1);
    End;
   '0'..'9': LexNumber;
   '.': Begin
     If (i < n) And (src[i + 1] In ['0'..'9']) Then LexNumber
     Else LexOp;
    End;
   '"', '''': LexString(0, i, 0);
  Else
   If IsIdStart(c) Then Begin
    j := i;
    While (j <= n) And IsIdChar(src[j]) Do Inc(j);
    id := Copy(src, i, j - i);
    flags := -1;
    If (j <= n) And (src[j] In ['"', '''']) And (Length(id) <= 2) Then Begin
     t := LowerCase(id);
     If t = 'r' Then flags := tfRaw
     Else If t = 'u' Then flags := 0
     Else If t = 'b' Then flags := tfBytes
     Else If t = 'f' Then flags := tfFStr
     Else If (t = 'br') Or (t = 'rb') Then flags := tfBytes Or tfRaw
     Else If (t = 'fr') Or (t = 'rf') Then flags := tfFStr Or tfRaw;
    End;
    If flags >= 0 Then Begin
     k := i;
     i := j;
     LexString(0, j, flags);
     toks[ntok - 1].col := k - ls - 1;
    End
    Else Begin
     Emit(tkName, id, line, i - ls - 1);
     i := j;
    End;
   End
   Else LexOp;
  End;
 End;
 If depth > 0 Then SynErr('unexpected EOF while parsing', line, 0, True);
 If (ntok > 0) And (toks[ntok - 1].kind <> tkNewline) And
  (toks[ntok - 1].kind <> tkDedent) And (toks[ntok - 1].kind <> tkIndent)
  Then Emit(tkNewline, '', line, 0);
 While ni > 1 Do Begin
  Dec(ni);
  Emit(tkDedent, '', line, 0);
 End;
 Emit(tkEOF, '', line, 0);
 SetLength(toks, ntok);
 q := lastKind + pending;
 If q = -5 Then bracketOpen := True;
End;

{ ------------------------------------------------------------
  Arbre syntaxique
  ------------------------------------------------------------ }
Const
 nName = 1; nNum = 2; nStr = 3; nJoined = 4; nFmt = 5; nBin = 6;
 nUnary = 7; nBool = 8; nCmp = 9; nCall = 10; nKw = 11; nStarred = 12;
 nAttr = 13; nSub = 14; nSlice = 15; nTuple = 16; nList = 17; nSet = 18;
 nDict = 19; nListComp = 20; nSetComp = 21; nGenExp = 22; nDictComp = 23;
 nCompFor = 24; nLambda = 25; nIfExp = 26; nYield = 27; nYieldFrom = 28;
 nAwait = 29; nNamed = 30; nConst = 31; nExtSlice = 32;
 nExprStmt = 40; nAssign = 41; nAugAssign = 42; nAnnAssign = 43;
 nReturn = 44; nDelete = 45; nPass = 46; nBreak = 47; nContinue = 48;
 nRaise = 49; nGlobal = 50; nNonlocal = 51; nImport = 52;
 nImportFrom = 53; nAssert = 54; nIf = 55; nWhile = 56; nFor = 57;
 nTry = 58; nWith = 59; nFuncDef = 60; nClassDef = 61; nHandler = 62;
 nWithItem = 63; nArgs = 64; nParam = 65; nAlias = 66; nModule = 67;
 nExprInter = 68;

Type
 TNode = Class;
 TNodes = Array Of TNode;
 TNode = Class
  k: Integer;
  line, col: Integer;
  s, s2: AnsiString;
  n: Integer;
  v: TVal;
  a, b, c, d: TNode;
  l1, l2, l3, l4: TNodes;
  sl: TStrArr;
  flag: Boolean;
  scope: TObject;
 End;

Function NewNode(k: Integer; line, col: Integer): TNode;
Begin
 Result := TNode.Create;
 Result.k := k;
 Result.line := line;
 Result.col := col;
 Result.v := vNull;
End;

Procedure AddNode(Var l: TNodes; nd: TNode);
Begin
 SetLength(l, Length(l) + 1);
 l[High(l)] := nd;
End;

{ ------------------------------------------------------------
  Analyseur syntaxique (descente recursive)
  ------------------------------------------------------------ }
Const
 Keywords: Array[0..34] Of String[10] = ('False', 'None', 'True', 'and',
  'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def',
  'del', 'elif', 'else', 'except', 'finally', 'for', 'from', 'global',
  'if', 'import', 'in', 'is', 'lambda', 'nonlocal', 'not', 'or', 'pass',
  'raise', 'return', 'try', 'while', 'with', 'yield');

Var
 PTok: TTokArr;
 PPos: Integer;
 PInFunc: Integer;

Function IsKeyword(Const s: AnsiString): Boolean;
Var
 i: Integer;
Begin
 Result := False;
 For i := 0 To High(Keywords) Do
  If Keywords[i] = s Then Begin
   Result := True;
   Exit;
  End;
End;

Procedure ErrAt(Const t: TToken; Const msg: AnsiString = 'invalid syntax');
Begin
 If t.kind = tkEOF Then
  SynErr('unexpected EOF while parsing', t.line, t.col, True)
 Else If t.kind = tkIndent Then
  SynErr('unexpected indent', t.line, t.col, False, exIndentationError)
 Else SynErr(msg, t.line, t.col);
End;

Function Cur: TToken; Inline;
Begin
 Result := PTok[PPos];
End;

Function PeekTok(k: Integer): TToken;
Begin
 If PPos + k < Length(PTok) Then Result := PTok[PPos + k]
 Else Result := PTok[High(PTok)];
End;

Function IsOp(Const s: AnsiString): Boolean; Inline;
Begin
 Result := (PTok[PPos].kind = tkOp) And (PTok[PPos].s = s);
End;

Function IsKw(Const s: AnsiString): Boolean; Inline;
Begin
 Result := (PTok[PPos].kind = tkName) And (PTok[PPos].s = s);
End;

Procedure Advance; Inline;
Begin
 If PPos < High(PTok) Then Inc(PPos);
End;

Function AcceptOp(Const s: AnsiString): Boolean;
Begin
 Result := IsOp(s);
 If Result Then Advance;
End;

Function AcceptKw(Const s: AnsiString): Boolean;
Begin
 Result := IsKw(s);
 If Result Then Advance;
End;

Procedure ExpectOp(Const s: AnsiString);
Begin
 If Not IsOp(s) Then ErrAt(Cur);
 Advance;
End;

Procedure ExpectKw(Const s: AnsiString);
Begin
 If Not IsKw(s) Then ErrAt(Cur);
 Advance;
End;

Function ExpectName: AnsiString;
Begin
 If (Cur.kind <> tkName) Or IsKeyword(Cur.s) Then ErrAt(Cur);
 Result := Cur.s;
 Advance;
End;

{ ---- decodage des litteraux de chaine ---- }
Function DecodeStrLit(Const raw: AnsiString; flags: Integer; line,
 col: Integer): AnsiString;
Var
 i, n, k, cnt: Integer;
 c: Char;
 r: AnsiString;
 cp: Cardinal;
 isB: Boolean;
Begin
 isB := (flags And tfBytes) <> 0;
 If (flags And tfRaw) <> 0 Then Begin
  If isB And Not IsAsciiStr(raw) Then
   SynErr('bytes can only contain ASCII literal characters.', line, col);
  Result := raw;
  Exit;
 End;
 If Pos('\', raw) = 0 Then Begin
  If isB And Not IsAsciiStr(raw) Then
   SynErr('bytes can only contain ASCII literal characters.', line, col);
  Result := raw;
  Exit;
 End;
 r := '';
 n := Length(raw);
 i := 1;
 While i <= n Do Begin
  c := raw[i];
  If c <> '\' Then Begin
   If isB And (Ord(c) >= 128) Then
    SynErr('bytes can only contain ASCII literal characters.', line, col);
   r := r + c;
   Inc(i);
   Continue;
  End;
  Inc(i);
  If i > n Then Begin
   r := r + '\';
   Break;
  End;
  c := raw[i];
  Inc(i);
  Case c Of
   #10: ;
   '\': r := r + '\';
   '''': r := r + '''';
   '"': r := r + '"';
   'a': r := r + #7;
   'b': r := r + #8;
   'f': r := r + #12;
   'n': r := r + #10;
   'r': r := r + #13;
   't': r := r + #9;
   'v': r := r + #11;
   '0'..'7': Begin
     cp := Ord(c) - 48;
     cnt := 1;
     While (i <= n) And (cnt < 3) And (raw[i] In ['0'..'7']) Do Begin
      cp := cp * 8 + Cardinal(Ord(raw[i]) - 48);
      Inc(i);
      Inc(cnt);
     End;
     If isB Then r := r + Chr(cp And 255) Else r := r + Utf8Enc(cp);
    End;
   'x': Begin
     k := 0;
     cp := 0;
     While (i <= n) And (k < 2) And (raw[i] In ['0'..'9', 'a'..'f', 'A'..'F'])
      Do Begin
      cp := cp * 16 + Cardinal(StrToInt('$' + raw[i]));
      Inc(i);
      Inc(k);
     End;
     If k < 2 Then
      SynErr('(unicode error) ''unicodeescape'' codec can''t decode bytes' +
       ' in position 0-1: truncated \xXX escape', line, col);
     If isB Then r := r + Chr(cp) Else r := r + Utf8Enc(cp);
    End;
   'u', 'U': Begin
     If isB Then r := r + '\' + c
     Else Begin
      If c = 'u' Then k := 4 Else k := 8;
      cp := 0;
      cnt := 0;
      While (i <= n) And (cnt < k) And (raw[i] In ['0'..'9', 'a'..'f',
       'A'..'F']) Do Begin
       cp := cp * 16 + Cardinal(StrToInt('$' + raw[i]));
       Inc(i);
       Inc(cnt);
      End;
      If cnt < k Then
       SynErr('(unicode error) ''unicodeescape'' codec can''t decode ' +
        'bytes in position 0-1: truncated \uXXXX escape', line, col);
      r := r + Utf8Enc(cp);
     End;
    End;
   'N': Begin
     If isB Then r := r + '\N'
     Else SynErr('(unicode error) ''unicodeescape'' codec can''t decode ' +
       'bytes: unknown Unicode character name', line, col);
    End;
  Else
   r := r + '\' + c;
  End;
 End;
 Result := r;
End;

{ ---- expressions ---- }
Function ParseTest: TNode; Forward;
Function ParseNamedTest: TNode; Forward;
Function ParseTestListStar(allowStar: Boolean): TNode; Forward;
Function ParseExpr: TNode; Forward;
Function ParseOr: TNode; Forward;
Function ParseStarExpr: TNode; Forward;
Function ParseYieldExpr: TNode; Forward;
Function ParseFStringParts(Const raw: AnsiString; flags, line,
 col: Integer): TNode; Forward;
Function ParseNamedTestNoCond: TNode; Forward;
Function ParseFactorExpr: TNode; Forward;

Procedure CheckTarget(nd: TNode; del: Boolean);
Var
 j: Integer;
Begin
 Case nd.k Of
  nName, nAttr, nSub: ;
  nTuple, nList: Begin
    For j := 0 To High(nd.l1) Do CheckTarget(nd.l1[j], del);
   End;
  nStarred: Begin
    If del Then SynErr('can''t delete starred', nd.line, nd.col);
    CheckTarget(nd.a, del);
   End;
  nConst, nNum, nStr, nJoined:
   If del Then SynErr('can''t delete literal', nd.line, nd.col)
   Else SynErr('can''t assign to literal', nd.line, nd.col);
  nCall: If del Then SynErr('can''t delete function call', nd.line, nd.col)
   Else SynErr('can''t assign to function call', nd.line, nd.col);
  nBin, nUnary, nBool: SynErr('can''t assign to operator', nd.line, nd.col);
  nCmp: SynErr('can''t assign to comparison', nd.line, nd.col);
  nLambda: SynErr('can''t assign to lambda', nd.line, nd.col);
  nIfExp: SynErr('can''t assign to conditional expression', nd.line,
    nd.col);
  nYield, nYieldFrom: SynErr('can''t assign to yield expression', nd.line,
    nd.col);
  nListComp, nSetComp, nGenExp, nDictComp:
   SynErr('can''t assign to comprehension', nd.line, nd.col);
  nDict: SynErr('can''t assign to literal', nd.line, nd.col);
  nSet: SynErr('can''t assign to literal', nd.line, nd.col);
 Else
  SynErr('can''t assign to expression', nd.line, nd.col);
 End;
End;

Function ParseParams(isLambda: Boolean): TNode;
Var
 args: TNode;
 prm: TNode;
 seenStar, seenDefault: Boolean;
 endTok: AnsiString;
 t: TToken;
Begin
 args := NewNode(nArgs, Cur.line, Cur.col);
 args.n := 0;
 seenStar := False;
 seenDefault := False;
 If isLambda Then endTok := ':' Else endTok := ')';
 While Not IsOp(endTok) Do Begin
  t := Cur;
  If IsOp('/') Then Begin
   If seenStar Or (args.n <> 0) Or (Length(args.l1) = 0) Then ErrAt(t);
   args.n := Length(args.l1);
   Advance;
  End
  Else If IsOp('**') Then Begin
   Advance;
   prm := NewNode(nParam, t.line, t.col);
   prm.s := ExpectName;
   If (Not isLambda) And AcceptOp(':') Then prm.b := ParseTest;
   args.d := prm;
   AcceptOp(',');
   If Not IsOp(endTok) Then ErrAt(Cur, 'invalid syntax');
   Break;
  End
  Else If IsOp('*') Then Begin
   If seenStar Then ErrAt(t);
   Advance;
   seenStar := True;
   If Not IsOp(',') Then Begin
    prm := NewNode(nParam, t.line, t.col);
    prm.s := ExpectName;
    If (Not isLambda) And AcceptOp(':') Then prm.b := ParseTest;
    args.c := prm;
   End
   Else Begin
    args.flag := True;
    If Not (PeekTok(1).kind = tkName) Then
     SynErr('named arguments must follow bare *', t.line, t.col);
   End;
  End
  Else Begin
   prm := NewNode(nParam, t.line, t.col);
   prm.s := ExpectName;
   If (Not isLambda) And AcceptOp(':') Then prm.b := ParseTest;
   If AcceptOp('=') Then Begin
    prm.a := ParseTest;
    If Not seenStar Then seenDefault := True;
   End
   Else If seenDefault And Not seenStar Then
    SynErr('non-default argument follows default argument', t.line, t.col);
   If seenStar Then AddNode(args.l2, prm) Else AddNode(args.l1, prm);
  End;
  If Not AcceptOp(',') Then Break;
 End;
 Result := args;
End;

Function ParseTargetList: TNode;
Var
 e, tup: TNode;
 t: TToken;
Begin
 t := Cur;
 e := ParseStarExpr;
 If Not IsOp(',') Then Begin
  Result := e;
  Exit;
 End;
 tup := NewNode(nTuple, t.line, t.col);
 AddNode(tup.l1, e);
 While AcceptOp(',') Do Begin
  If IsKw('in') Or IsOp('=') Then Break;
  AddNode(tup.l1, ParseStarExpr);
 End;
 Result := tup;
End;

Function ParseCompFor(): TNodes;
Var
 gens: TNodes;
 g: TNode;
 t: TToken;
Begin
 SetLength(gens, 0);
 While IsKw('for') Or IsKw('async') Do Begin
  t := Cur;
  If IsKw('async') Then
   SynErr('asynchronous comprehensions are not supported', t.line, t.col);
  Advance;
  g := NewNode(nCompFor, t.line, t.col);
  g.a := ParseTargetList;
  CheckTarget(g.a, False);
  ExpectKw('in');
  g.b := ParseOr;
  If IsKw('if') Then Begin
   { le test conditionnel du for ne doit pas avaler "if" }
  End;
  While IsKw('if') Do Begin
   Advance;
   AddNode(g.l1, ParseNamedTestNoCond);
  End;
  AddNode(gens, g);
 End;
 Result := gens;
End;

Function ParseNamedTestNoCond: TNode;
Var
 t: TToken;
 nd, v: TNode;
Begin
 t := Cur;
 If IsKw('lambda') Then Begin
  Result := ParseTest;
  Exit;
 End;
 nd := ParseOr;
 If IsOp(':=') Then Begin
  If nd.k <> nName Then SynErr('cannot use named assignment with ' +
   'expression', t.line, t.col);
  Advance;
  v := ParseTest;
  Result := NewNode(nNamed, t.line, t.col);
  Result.a := nd;
  Result.b := v;
  Exit;
 End;
 Result := nd;
End;

Function ParseCallArgs(fn: TNode; line, col: Integer): TNode;
Var
 call, kw, e: TNode;
 t: TToken;
 seenKw, seenStarStar: Boolean;
Begin
 call := NewNode(nCall, line, col);
 call.a := fn;
 seenKw := False;
 seenStarStar := False;
 While Not IsOp(')') Do Begin
  t := Cur;
  If IsOp('*') Then Begin
   Advance;
   e := NewNode(nStarred, t.line, t.col);
   e.a := ParseTest;
   If seenStarStar Then
    SynErr('iterable argument unpacking follows keyword argument unpacking',
     t.line, t.col);
   AddNode(call.l1, e);
  End
  Else If IsOp('**') Then Begin
   Advance;
   kw := NewNode(nKw, t.line, t.col);
   kw.s := '';
   kw.a := ParseTest;
   seenStarStar := True;
   AddNode(call.l1, kw);
  End
  Else If (t.kind = tkName) And (PeekTok(1).kind = tkOp) And
   (PeekTok(1).s = '=') And Not IsKeyword(t.s) Then Begin
   Advance;
   Advance;
   kw := NewNode(nKw, t.line, t.col);
   kw.s := t.s;
   kw.a := ParseTest;
   seenKw := True;
   AddNode(call.l1, kw);
  End
  Else Begin
   e := ParseNamedTest;
   If IsKw('for') Then Begin
    kw := NewNode(nGenExp, t.line, t.col);
    kw.a := e;
    kw.l1 := ParseCompFor;
    e := kw;
   End
   Else If seenStarStar Then
    SynErr('positional argument follows keyword argument unpacking',
     t.line, t.col)
   Else If seenKw Then
    SynErr('positional argument follows keyword argument', t.line, t.col);
   AddNode(call.l1, e);
  End;
  If Not AcceptOp(',') Then Break;
 End;
 ExpectOp(')');
 Result := call;
End;

Function ParseSubscriptItem: TNode;
Var
 t: TToken;
 sl, lo, hi, st: TNode;
Begin
 t := Cur;
 lo := Nil;
 If Not IsOp(':') Then Begin
  lo := ParseNamedTest;
  If Not IsOp(':') Then Begin
   Result := lo;
   Exit;
  End;
 End;
 Advance;
 hi := Nil;
 st := Nil;
 If Not (IsOp(':') Or IsOp(',') Or IsOp(']')) Then hi := ParseTest;
 If AcceptOp(':') Then
  If Not (IsOp(',') Or IsOp(']')) Then st := ParseTest;
 sl := NewNode(nSlice, t.line, t.col);
 sl.a := lo;
 sl.b := hi;
 sl.c := st;
 Result := sl;
End;

Function ParseTrailers(base: TNode): TNode;
Var
 nd, idx, tup: TNode;
 t: TToken;
Begin
 nd := base;
 While True Do Begin
  t := Cur;
  If IsOp('(') Then Begin
   Advance;
   nd := ParseCallArgs(nd, t.line, t.col);
  End
  Else If IsOp('[') Then Begin
   Advance;
   idx := ParseSubscriptItem;
   If IsOp(',') Then Begin
    tup := NewNode(nTuple, t.line, t.col);
    AddNode(tup.l1, idx);
    While AcceptOp(',') Do Begin
     If IsOp(']') Then Break;
     AddNode(tup.l1, ParseSubscriptItem);
    End;
    idx := tup;
   End;
   ExpectOp(']');
   tup := NewNode(nSub, t.line, t.col);
   tup.a := nd;
   tup.b := idx;
   nd := tup;
  End
  Else If IsOp('.') Then Begin
   Advance;
   tup := NewNode(nAttr, t.line, t.col);
   tup.a := nd;
   If (Cur.kind <> tkName) Or IsKeyword(Cur.s) Then ErrAt(Cur);
   tup.s := Cur.s;
   Advance;
   nd := tup;
  End
  Else Break;
 End;
 Result := nd;
End;

Function ParseAtom: TNode;
Var
 t: TToken;
 nd, e, d: TNode;
 isB, isF, anyStr: Boolean;
 s: AnsiString;
 parts: TNodes;
 fl: Integer;
 first: Boolean;
Begin
 t := Cur;
 Case t.kind Of
  tkNumber: Begin
    Advance;
    If t.flags = tfImag Then
     SynErr('complex numbers are not supported', t.line, t.col);
    nd := NewNode(nNum, t.line, t.col);
    nd.v := t.v;
    Result := nd;
    Exit;
   End;
  tkString: Begin
    isB := (t.flags And tfBytes) <> 0;
    isF := False;
    s := '';
    SetLength(parts, 0);
    anyStr := False;
    While Cur.kind = tkString Do Begin
     If ((Cur.flags And tfBytes) <> 0) <> isB Then
      SynErr('cannot mix bytes and nonbytes literals', Cur.line, Cur.col);
     fl := Cur.flags;
     If (fl And tfFStr) <> 0 Then Begin
      isF := True;
      If s <> '' Then Begin
       e := NewNode(nStr, t.line, t.col);
       e.s := s;
       AddNode(parts, e);
       s := '';
      End;
      e := ParseFStringParts(Cur.s, fl, Cur.line, Cur.col);
      For fl := 0 To High(e.l1) Do AddNode(parts, e.l1[fl]);
     End
     Else s := s + DecodeStrLit(Cur.s, fl, Cur.line, Cur.col);
     Advance;
    End;
    If isF Then Begin
     If s <> '' Then Begin
      e := NewNode(nStr, t.line, t.col);
      e.s := s;
      AddNode(parts, e);
     End;
     nd := NewNode(nJoined, t.line, t.col);
     nd.l1 := parts;
    End
    Else Begin
     nd := NewNode(nStr, t.line, t.col);
     nd.s := s;
     nd.flag := isB;
    End;
    Result := nd;
    Exit;
   End;
  tkName: Begin
    If t.s = 'None' Then Begin
     Advance;
     nd := NewNode(nConst, t.line, t.col);
     nd.v := vNone;
     Result := nd;
     Exit;
    End;
    If t.s = 'True' Then Begin
     Advance;
     nd := NewNode(nConst, t.line, t.col);
     nd.v := vTrue;
     Result := nd;
     Exit;
    End;
    If t.s = 'False' Then Begin
     Advance;
     nd := NewNode(nConst, t.line, t.col);
     nd.v := vFalse;
     Result := nd;
     Exit;
    End;
    If IsKeyword(t.s) Then ErrAt(t);
    Advance;
    nd := NewNode(nName, t.line, t.col);
    nd.s := t.s;
    Result := nd;
    Exit;
   End;
  tkOp: Begin
    If t.s = '...' Then Begin
     Advance;
     nd := NewNode(nConst, t.line, t.col);
     nd.v := vEllipsis;
     Result := nd;
     Exit;
    End;
    If t.s = '(' Then Begin
     Advance;
     If IsOp(')') Then Begin
      Advance;
      Result := NewNode(nTuple, t.line, t.col);
      Exit;
     End;
     If IsKw('yield') Then Begin
      e := ParseYieldExpr;
      ExpectOp(')');
      Result := e;
      Exit;
     End;
     If IsOp('*') Then e := ParseStarExpr Else e := ParseNamedTest;
     If IsKw('for') Then Begin
      nd := NewNode(nGenExp, t.line, t.col);
      nd.a := e;
      nd.l1 := ParseCompFor;
      ExpectOp(')');
      Result := nd;
      Exit;
     End;
     If IsOp(',') Then Begin
      nd := NewNode(nTuple, t.line, t.col);
      AddNode(nd.l1, e);
      While AcceptOp(',') Do Begin
       If IsOp(')') Then Break;
       If IsOp('*') Then AddNode(nd.l1, ParseStarExpr)
       Else AddNode(nd.l1, ParseNamedTest);
      End;
      ExpectOp(')');
      Result := nd;
      Exit;
     End;
     ExpectOp(')');
     If e.k = nStarred Then
      SynErr('can''t use starred expression here', e.line, e.col);
     { conserver un marqueur de parenthese pour les cibles }
     Result := e;
     Exit;
    End;
    If t.s = '[' Then Begin
     Advance;
     nd := NewNode(nList, t.line, t.col);
     If IsOp(']') Then Begin
      Advance;
      Result := nd;
      Exit;
     End;
     If IsOp('*') Then e := ParseStarExpr Else e := ParseNamedTest;
     If IsKw('for') Then Begin
      nd.k := nListComp;
      nd.a := e;
      nd.l1 := ParseCompFor;
      ExpectOp(']');
      Result := nd;
      Exit;
     End;
     AddNode(nd.l1, e);
     While AcceptOp(',') Do Begin
      If IsOp(']') Then Break;
      If IsOp('*') Then AddNode(nd.l1, ParseStarExpr)
      Else AddNode(nd.l1, ParseNamedTest);
     End;
     ExpectOp(']');
     Result := nd;
     Exit;
    End;
    If t.s = '{' Then Begin
     Advance;
     nd := NewNode(nDict, t.line, t.col);
     If IsOp('}') Then Begin
      Advance;
      Result := nd;
      Exit;
     End;
     first := True;
     While True Do Begin
      If IsOp('**') Then Begin
       Advance;
       If (Not first) And (nd.k = nSet) Then ErrAt(Cur);
       AddNode(nd.l1, Nil);
       AddNode(nd.l2, ParseOr);
      End
      Else Begin
       If IsOp('*') Then e := ParseStarExpr Else e := ParseNamedTest;
       If IsOp(':') And (e.k <> nStarred) Then Begin
        If (Not first) And (nd.k = nSet) Then ErrAt(Cur);
        Advance;
        d := ParseTest;
        If first And IsKw('for') Then Begin
         nd.k := nDictComp;
         nd.a := e;
         nd.b := d;
         nd.l1 := ParseCompFor;
         ExpectOp('}');
         Result := nd;
         Exit;
        End;
        AddNode(nd.l1, e);
        AddNode(nd.l2, d);
       End
       Else Begin
        If first Then nd.k := nSet
        Else If nd.k <> nSet Then ErrAt(Cur);
        If first And IsKw('for') Then Begin
         nd.k := nSetComp;
         nd.a := e;
         nd.l1 := ParseCompFor;
         ExpectOp('}');
         Result := nd;
         Exit;
        End;
        AddNode(nd.l1, e);
       End;
      End;
      first := False;
      If Not AcceptOp(',') Then Break;
      If IsOp('}') Then Break;
     End;
     ExpectOp('}');
     Result := nd;
     Exit;
    End;
    ErrAt(t);
   End;
 Else
  ErrAt(t);
 End;
 Result := Nil;
End;

Function ParsePower: TNode;
Var
 t: TToken;
 nd, r, b: TNode;
Begin
 t := Cur;
 If IsKw('await') Then Begin
  SynErr('async/await is not supported', t.line, t.col);
 End;
 nd := ParseTrailers(ParseAtom);
 If IsOp('**') Then Begin
  Advance;
  r := ParseFactorExpr;
  b := NewNode(nBin, t.line, t.col);
  b.s := '**';
  b.a := nd;
  b.b := r;
  Result := b;
 End
 Else Result := nd;
End;

Function ParseFactorExpr: TNode;
Var
 t: TToken;
 nd: TNode;
Begin
 t := Cur;
 If IsOp('-') Or IsOp('+') Or IsOp('~') Then Begin
  Advance;
  nd := NewNode(nUnary, t.line, t.col);
  nd.s := t.s;
  nd.a := ParseFactorExpr();
  { replier les constantes numeriques negatives }
  Result := nd;
 End
 Else Result := ParsePower;
End;

Function ParseBinLevel(level: Integer): TNode;
Var
 nd, r, b: TNode;
 t: TToken;
 found: Boolean;
Begin
 If level = 6 Then Begin
  Result := ParseFactorExpr;
  Exit;
 End;
 nd := ParseBinLevel(level + 1);
 While True Do Begin
  t := Cur;
  found := False;
  If t.kind = tkOp Then
   Case level Of
    0: found := t.s = '|';
    1: found := t.s = '^';
    2: found := t.s = '&';
    3: found := (t.s = '<<') Or (t.s = '>>');
    4: found := (t.s = '+') Or (t.s = '-');
    5: found := (t.s = '*') Or (t.s = '/') Or (t.s = '//') Or (t.s = '%')
        Or (t.s = '@');
   End;
  If Not found Then Break;
  Advance;
  r := ParseBinLevel(level + 1);
  b := NewNode(nBin, t.line, t.col);
  b.s := t.s;
  b.a := nd;
  b.b := r;
  nd := b;
 End;
 Result := nd;
End;

Function ParseExpr: TNode;
Begin
 Result := ParseBinLevel(0);
End;

Function ParseStarExpr: TNode;
Var
 t: TToken;
Begin
 t := Cur;
 If IsOp('*') Then Begin
  Advance;
  Result := NewNode(nStarred, t.line, t.col);
  Result.a := ParseExpr;
 End
 Else Result := ParseExpr;
End;

Function ParseCompOp(Var op: AnsiString): Boolean;
Var
 t: TToken;
Begin
 t := Cur;
 Result := True;
 If t.kind = tkOp Then Begin
  If (t.s = '<') Or (t.s = '>') Or (t.s = '==') Or (t.s = '>=') Or
   (t.s = '<=') Or (t.s = '!=') Then Begin
   op := t.s;
   Advance;
   Exit;
  End;
  If t.s = '<>' Then ErrAt(t);
 End
 Else If t.kind = tkName Then Begin
  If t.s = 'in' Then Begin
   op := 'in';
   Advance;
   Exit;
  End;
  If t.s = 'is' Then Begin
   Advance;
   If AcceptKw('not') Then op := 'is not' Else op := 'is';
   Exit;
  End;
  If (t.s = 'not') And (PeekTok(1).kind = tkName) And
   (PeekTok(1).s = 'in') Then Begin
   Advance;
   Advance;
   op := 'not in';
   Exit;
  End;
 End;
 Result := False;
End;

Function ParseComparison: TNode;
Var
 nd, c: TNode;
 op: AnsiString;
 t: TToken;
Begin
 t := Cur;
 nd := ParseExpr;
 If Not (((Cur.kind = tkOp) Or (Cur.kind = tkName))) Then Begin
  Result := nd;
  Exit;
 End;
 c := Nil;
 While ParseCompOp(op) Do Begin
  If c = Nil Then Begin
   c := NewNode(nCmp, t.line, t.col);
   c.a := nd;
  End;
  SetLength(c.sl, Length(c.sl) + 1);
  c.sl[High(c.sl)] := op;
  AddNode(c.l1, ParseExpr);
 End;
 If c <> Nil Then Result := c Else Result := nd;
End;

Function ParseNot: TNode;
Var
 t: TToken;
 nd: TNode;
Begin
 t := Cur;
 If IsKw('not') Then Begin
  Advance;
  nd := NewNode(nUnary, t.line, t.col);
  nd.s := 'not';
  nd.a := ParseNot();
  Result := nd;
 End
 Else Result := ParseComparison;
End;

Function ParseAnd: TNode;
Var
 nd, b: TNode;
 t: TToken;
Begin
 t := Cur;
 nd := ParseNot;
 If IsKw('and') Then Begin
  b := NewNode(nBool, t.line, t.col);
  b.s := 'and';
  AddNode(b.l1, nd);
  While AcceptKw('and') Do AddNode(b.l1, ParseNot);
  nd := b;
 End;
 Result := nd;
End;

Function ParseOr: TNode;
Var
 nd, b: TNode;
 t: TToken;
Begin
 t := Cur;
 nd := ParseAnd;
 If IsKw('or') Then Begin
  b := NewNode(nBool, t.line, t.col);
  b.s := 'or';
  AddNode(b.l1, nd);
  While AcceptKw('or') Do AddNode(b.l1, ParseAnd);
  nd := b;
 End;
 Result := nd;
End;

Function ParseLambda: TNode;
Var
 t: TToken;
 nd: TNode;
Begin
 t := Cur;
 Advance;
 nd := NewNode(nLambda, t.line, t.col);
 nd.b := ParseParams(True);
 ExpectOp(':');
 nd.a := ParseTest;
 Result := nd;
End;

Function ParseTest: TNode;
Var
 t: TToken;
 nd, c, e: TNode;
Begin
 t := Cur;
 If IsKw('lambda') Then Begin
  Result := ParseLambda;
  Exit;
 End;
 nd := ParseOr;
 If IsKw('if') Then Begin
  Advance;
  c := ParseOr;
  ExpectKw('else');
  e := ParseTest();
  Result := NewNode(nIfExp, t.line, t.col);
  Result.a := c;
  Result.b := nd;
  Result.c := e;
  Exit;
 End;
 Result := nd;
End;

Function ParseNamedTest: TNode;
Var
 t: TToken;
 nd, v: TNode;
Begin
 t := Cur;
 nd := ParseTest;
 If IsOp(':=') Then Begin
  If nd.k <> nName Then
   SynErr('cannot use named assignment with ' + 'expression', t.line, t.col);
  Advance;
  v := ParseTest;
  Result := NewNode(nNamed, t.line, t.col);
  Result.a := nd;
  Result.b := v;
  Exit;
 End;
 Result := nd;
End;

Function ParseYieldExpr: TNode;
Var
 t: TToken;
 nd: TNode;
Begin
 t := Cur;
 ExpectKw('yield');
 If AcceptKw('from') Then Begin
  nd := NewNode(nYieldFrom, t.line, t.col);
  nd.a := ParseTest;
  Result := nd;
  Exit;
 End;
 nd := NewNode(nYield, t.line, t.col);
 If Not (IsOp(')') Or IsOp(']') Or IsOp('}') Or IsOp('=') Or IsOp(';') Or
  (Cur.kind = tkNewline) Or (Cur.kind = tkEOF)) Then
  nd.a := ParseTestListStar(True);
 Result := nd;
End;

{ liste d'expressions : produit un tuple si virgule }
Function ParseTestListStar(allowStar: Boolean): TNode;
Var
 t: TToken;
 e, tup: TNode;
Begin
 t := Cur;
 If allowStar And IsOp('*') Then e := ParseStarExpr Else e := ParseNamedTest;
 If Not IsOp(',') Then Begin
  Result := e;
  Exit;
 End;
 tup := NewNode(nTuple, t.line, t.col);
 AddNode(tup.l1, e);
 While AcceptOp(',') Do Begin
  If (Cur.kind = tkNewline) Or (Cur.kind = tkEOF) Or IsOp('=') Or
   IsOp(')') Or IsOp(']') Or IsOp('}') Or IsOp(':') Or IsOp(';') Or
   (IsOp(':=')) Or ((Cur.kind = tkOp) And (Length(Cur.s) >= 2) And
   (Cur.s[Length(Cur.s)] = '=') And (Cur.s <> '==') And (Cur.s <> '!=')
   And (Cur.s <> '<=') And (Cur.s <> '>=')) Or IsKw('in') Then Break;
  If allowStar And IsOp('*') Then AddNode(tup.l1, ParseStarExpr)
  Else AddNode(tup.l1, ParseNamedTest);
 End;
 Result := tup;
End;

{ ---- f-strings ---- }
Function ParseExprFromText(Const txt: AnsiString; line, col: Integer): TNode;
Var
 saveTok: TTokArr;
 savePos: Integer;
 toks: TTokArr;
 nd: TNode;
 i: Integer;
Begin
 saveTok := PTok;
 savePos := PPos;
 Try
  If Trim(txt) = '' Then
   SynErr('f-string: empty expression not allowed', line, col);
  Tokenize('(' + txt + ')'#10, toks);
  PTok := toks;
  PPos := 0;
  If IsOp('(') Then Begin
   Advance;
   If IsKw('yield') Then nd := ParseYieldExpr
   Else nd := ParseTestListStar(True);
   If Not IsOp(')') Then
    SynErr('f-string: invalid syntax', line, col);
  End
  Else nd := Nil;
  For i := 0 To 0 Do ;
  Result := nd;
 Finally
  PTok := saveTok;
  PPos := savePos;
 End;
End;

Procedure SetLines(nd: TNode; line, col: Integer);
Var
 j: Integer;
Begin
 If nd = Nil Then Exit;
 nd.line := line;
 nd.col := col;
 SetLines(nd.a, line, col);
 SetLines(nd.b, line, col);
 SetLines(nd.c, line, col);
 SetLines(nd.d, line, col);
 For j := 0 To High(nd.l1) Do SetLines(nd.l1[j], line, col);
 For j := 0 To High(nd.l2) Do SetLines(nd.l2[j], line, col);
End;

Function ParseFStringParts(Const raw: AnsiString; flags, line,
 col: Integer): TNode;
Var
 res, e, fm: TNode;
 i, n, j, depth, st: Integer;
 lit, ex, spec: AnsiString;
 c, q: Char;
 isRaw: Boolean;
 conv: Integer;
 debug: Boolean;
 dbgText: AnsiString;

 Procedure FlushLit;
 Var
  nd: TNode;
 Begin
  If lit <> '' Then Begin
   nd := NewNode(nStr, line, col);
   If isRaw Then nd.s := lit
   Else nd.s := DecodeStrLit(lit, 0, line, col);
   AddNode(res.l1, nd);
   lit := '';
  End;
 End;

Begin
 isRaw := (flags And tfRaw) <> 0;
 res := NewNode(nJoined, line, col);
 n := Length(raw);
 i := 1;
 lit := '';
 While i <= n Do Begin
  c := raw[i];
  If c = '{' Then Begin
   If (i < n) And (raw[i + 1] = '{') Then Begin
    lit := lit + '{';
    Inc(i, 2);
    Continue;
   End;
   FlushLit;
   { chercher la fin de l'expression }
   j := i + 1;
   depth := 0;
   st := j;
   debug := False;
   conv := 0;
   spec := '';
   While j <= n Do Begin
    c := raw[j];
    If (c = '''') Or (c = '"') Then Begin
     q := c;
     If (j + 2 <= n) And (raw[j + 1] = q) And (raw[j + 2] = q) Then Begin
      Inc(j, 3);
      While (j + 2 <= n) And Not ((raw[j] = q) And (raw[j + 1] = q) And
       (raw[j + 2] = q)) Do Inc(j);
      Inc(j, 3);
     End
     Else Begin
      Inc(j);
      While (j <= n) And (raw[j] <> q) Do Begin
       If raw[j] = '\' Then Inc(j);
       Inc(j);
      End;
      Inc(j);
     End;
     Continue;
    End;
    If c In ['(', '[', '{'] Then Inc(depth)
    Else If c In [')', ']'] Then Dec(depth)
    Else If c = '}' Then Begin
     If depth = 0 Then Break;
     Dec(depth);
    End
    Else If (depth = 0) And (c = '!') And (j < n) And (raw[j + 1] <> '=')
     Then Break
    Else If (depth = 0) And (c = ':') Then Break
    Else If (depth = 0) And (c = '=') Then Begin
     If (j < n) And (raw[j + 1] = '=') Then Begin
      Inc(j, 2);
      Continue;
     End;
     If (j > st) And (raw[j - 1] In ['=', '!', '<', '>']) Then Begin
      Inc(j);
      Continue;
     End;
     { specificateur de debogage }
     Break;
    End;
    Inc(j);
   End;
   If j > n Then
    SynErr('f-string: expecting ''}''', line, col);
   ex := Copy(raw, st, j - st);
   dbgText := ex;
   If raw[j] = '=' Then Begin
    debug := True;
    Inc(j);
    dbgText := dbgText + '=';
    While (j <= n) And (raw[j] = ' ') Do Begin
     dbgText := dbgText + ' ';
     Inc(j);
    End;
   End;
   If (j <= n) And (raw[j] = '!') Then Begin
    Inc(j);
    If j > n Then SynErr('f-string: expecting ''}''', line, col);
    Case raw[j] Of
     's': conv := 1;
     'r': conv := 2;
     'a': conv := 3;
    Else
     SynErr('f-string: invalid conversion character: expected ''s'', ''r'''
      + ', or ''a''', line, col);
    End;
    Inc(j);
   End;
   spec := '';
   fm := Nil;
   If (j <= n) And (raw[j] = ':') Then Begin
    Inc(j);
    depth := 0;
    st := j;
    While j <= n Do Begin
     If raw[j] = '{' Then Inc(depth)
     Else If raw[j] = '}' Then Begin
      If depth = 0 Then Break;
      Dec(depth);
     End;
     Inc(j);
    End;
    spec := Copy(raw, st, j - st);
   End;
   If (j > n) Or (raw[j] <> '}') Then
    SynErr('f-string: expecting ''}''', line, col);
   If debug Then Begin
    lit := lit + dbgText;
    FlushLit;
    If (conv = 0) And (spec = '') Then conv := 2;
   End;
   e := ParseExprFromText(ex, line, col);
   SetLines(e, line, col);
   fm := NewNode(nFmt, line, col);
   fm.a := e;
   fm.n := conv;
   If spec <> '' Then
    fm.b := ParseFStringParts(spec, flags, line, col);
   AddNode(res.l1, fm);
   i := j + 1;
   Continue;
  End;
  If c = '}' Then Begin
   If (i < n) And (raw[i + 1] = '}') Then Begin
    lit := lit + '}';
    Inc(i, 2);
    Continue;
   End;
   SynErr('f-string: single ''}'' is not allowed', line, col);
  End;
  lit := lit + c;
  Inc(i);
 End;
 FlushLit;
 Result := res;
End;

{ ------------------------------------------------------------
  Instructions
  ------------------------------------------------------------ }
Procedure ParseStatement(Var body: TNodes); Forward;

Function ParseDotted: AnsiString;
Begin
 Result := ExpectName;
 While IsOp('.') Do Begin
  Advance;
  Result := Result + '.' + ExpectName;
 End;
End;

Function ParseSuite: TNodes;
Var
 body: TNodes;
 t: TToken;
Begin
 SetLength(body, 0);
 ExpectOp(':');
 If Cur.kind = tkNewline Then Begin
  Advance;
  If Cur.kind <> tkIndent Then Begin
   If Cur.kind = tkEOF Then
    SynErr('unexpected EOF while parsing', Cur.line, Cur.col, True)
   Else
    SynErr('expected an indented block', Cur.line, Cur.col, False,
     exIndentationError);
  End;
  Advance;
  While (Cur.kind <> tkDedent) And (Cur.kind <> tkEOF) Do
   ParseStatement(body);
  If Cur.kind = tkDedent Then Advance;
 End
 Else Begin
  t := Cur;
  ParseStatement(body);
  If t.kind = tkEOF Then ErrAt(t);
 End;
 Result := body;
End;

Function ParseAugOp(Var op: AnsiString): Boolean;
Const
 Aug: Array[0..12] Of String[4] = ('+=', '-=', '*=', '/=', '//=', '%=',
  '**=', '>>=', '<<=', '&=', '^=', '|=', '@=');
Var
 i: Integer;
Begin
 Result := False;
 If Cur.kind <> tkOp Then Exit;
 For i := 0 To High(Aug) Do
  If Cur.s = Aug[i] Then Begin
   op := Copy(Aug[i], 1, Length(Aug[i]) - 1);
   Advance;
   Result := True;
   Exit;
  End;
End;

Function ParseExprStmt: TNode;
Var
 t: TToken;
 e, v, nd, ann: TNode;
 op: AnsiString;
 targets: TNodes;
 j: Integer;
Begin
 t := Cur;
 If IsKw('yield') Then e := ParseYieldExpr
 Else e := ParseTestListStar(True);
 If IsOp('=') Then Begin
  SetLength(targets, 0);
  AddNode(targets, e);
  v := Nil;
  While AcceptOp('=') Do Begin
   If IsKw('yield') Then v := ParseYieldExpr
   Else v := ParseTestListStar(True);
   If IsOp('=') Then AddNode(targets, v);
  End;
  For j := 0 To High(targets) Do CheckTarget(targets[j], False);
  nd := NewNode(nAssign, t.line, t.col);
  nd.l1 := targets;
  nd.a := v;
  Result := nd;
  Exit;
 End;
 If ParseAugOp(op) Then Begin
  If Not (e.k In [nName, nAttr, nSub]) Then
   SynErr('illegal expression for augmented assignment', t.line, t.col);
  If IsKw('yield') Then v := ParseYieldExpr
  Else v := ParseTestListStar(False);
  nd := NewNode(nAugAssign, t.line, t.col);
  nd.a := e;
  nd.s := op;
  nd.b := v;
  Result := nd;
  Exit;
 End;
 If IsOp(':') And (e.k In [nName, nAttr, nSub]) Then Begin
  Advance;
  ann := ParseTest;
  nd := NewNode(nAnnAssign, t.line, t.col);
  nd.a := e;
  nd.b := ann;
  If AcceptOp('=') Then Begin
   If IsKw('yield') Then nd.c := ParseYieldExpr
   Else nd.c := ParseTestListStar(True);
  End;
  Result := nd;
  Exit;
 End;
 nd := NewNode(nExprStmt, t.line, t.col);
 nd.a := e;
 Result := nd;
End;

Function ParseImport: TNode;
Var
 nd, al: TNode;
 t: TToken;
 lvl: Integer;
 mod_: AnsiString;
Begin
 t := Cur;
 If IsKw('import') Then Begin
  Advance;
  nd := NewNode(nImport, t.line, t.col);
  Repeat
   al := NewNode(nAlias, Cur.line, Cur.col);
   al.s := ParseDotted;
   al.s2 := '';
   If AcceptKw('as') Then al.s2 := ExpectName;
   AddNode(nd.l1, al);
  Until Not AcceptOp(',');
  Result := nd;
  Exit;
 End;
 { from ... import ... }
 Advance;
 nd := NewNode(nImportFrom, t.line, t.col);
 lvl := 0;
 While IsOp('.') Or IsOp('...') Do Begin
  If IsOp('.') Then Inc(lvl) Else Inc(lvl, 3);
  Advance;
 End;
 mod_ := '';
 If Not IsKw('import') Then mod_ := ParseDotted
 Else If lvl = 0 Then ErrAt(Cur);
 nd.s := mod_;
 nd.n := lvl;
 ExpectKw('import');
 If IsOp('*') Then Begin
  Advance;
  al := NewNode(nAlias, t.line, t.col);
  al.s := '*';
  AddNode(nd.l1, al);
 End
 Else Begin
  If AcceptOp('(') Then Begin
   While True Do Begin
    al := NewNode(nAlias, Cur.line, Cur.col);
    al.s := ExpectName;
    al.s2 := '';
    If AcceptKw('as') Then al.s2 := ExpectName;
    AddNode(nd.l1, al);
    If Not AcceptOp(',') Then Break;
    If IsOp(')') Then Break;
   End;
   ExpectOp(')');
  End
  Else Begin
   Repeat
    al := NewNode(nAlias, Cur.line, Cur.col);
    al.s := ExpectName;
    al.s2 := '';
    If AcceptKw('as') Then al.s2 := ExpectName;
    AddNode(nd.l1, al);
   Until Not AcceptOp(',');
  End;
 End;
 Result := nd;
End;

Function ParseSmallStmt: TNode;
Var
 t: TToken;
 nd, e: TNode;
 j: Integer;
Begin
 t := Cur;
 If t.kind = tkName Then Begin
  If t.s = 'pass' Then Begin
   Advance;
   Result := NewNode(nPass, t.line, t.col);
   Exit;
  End;
  If t.s = 'break' Then Begin
   Advance;
   Result := NewNode(nBreak, t.line, t.col);
   Exit;
  End;
  If t.s = 'continue' Then Begin
   Advance;
   Result := NewNode(nContinue, t.line, t.col);
   Exit;
  End;
  If t.s = 'return' Then Begin
   Advance;
   nd := NewNode(nReturn, t.line, t.col);
   If Not ((Cur.kind = tkNewline) Or (Cur.kind = tkEOF) Or IsOp(';')) Then
    nd.a := ParseTestListStar(True);
   Result := nd;
   Exit;
  End;
  If t.s = 'raise' Then Begin
   Advance;
   nd := NewNode(nRaise, t.line, t.col);
   If Not ((Cur.kind = tkNewline) Or (Cur.kind = tkEOF) Or IsOp(';')) Then
    Begin
    nd.a := ParseTest;
    If AcceptKw('from') Then nd.b := ParseTest;
   End;
   Result := nd;
   Exit;
  End;
  If (t.s = 'global') Or (t.s = 'nonlocal') Then Begin
   Advance;
   If t.s = 'global' Then nd := NewNode(nGlobal, t.line, t.col)
   Else nd := NewNode(nNonlocal, t.line, t.col);
   Repeat
    SetLength(nd.sl, Length(nd.sl) + 1);
    nd.sl[High(nd.sl)] := ExpectName;
   Until Not AcceptOp(',');
   Result := nd;
   Exit;
  End;
  If (t.s = 'import') Or (t.s = 'from') Then Begin
   Result := ParseImport;
   Exit;
  End;
  If t.s = 'assert' Then Begin
   Advance;
   nd := NewNode(nAssert, t.line, t.col);
   nd.a := ParseTest;
   If AcceptOp(',') Then nd.b := ParseTest;
   Result := nd;
   Exit;
  End;
  If t.s = 'del' Then Begin
   Advance;
   nd := NewNode(nDelete, t.line, t.col);
   e := ParseTestListStar(False);
   If e.k = nTuple Then Begin
    For j := 0 To High(e.l1) Do Begin
     CheckTarget(e.l1[j], True);
     AddNode(nd.l1, e.l1[j]);
    End;
   End
   Else Begin
    CheckTarget(e, True);
    AddNode(nd.l1, e);
   End;
   Result := nd;
   Exit;
  End;
 End;
 Result := ParseExprStmt;
End;

Function ParseFuncDef(decos: TNodes): TNode;
Var
 t: TToken;
 nd: TNode;
Begin
 t := Cur;
 Advance;
 nd := NewNode(nFuncDef, t.line, t.col);
 nd.s := ExpectName;
 ExpectOp('(');
 nd.a := ParseParams(False);
 ExpectOp(')');
 If AcceptOp('->') Then nd.b := ParseTest;
 nd.l2 := decos;
 Inc(PInFunc);
 nd.l1 := ParseSuite;
 Dec(PInFunc);
 Result := nd;
End;

Function ParseClassDef(decos: TNodes): TNode;
Var
 t: TToken;
 nd, call: TNode;
Begin
 t := Cur;
 Advance;
 nd := NewNode(nClassDef, t.line, t.col);
 nd.s := ExpectName;
 If IsOp('(') Then Begin
  Advance;
  call := ParseCallArgs(Nil, t.line, t.col);
  nd.l1 := call.l1;
 End;
 nd.l3 := decos;
 nd.l2 := ParseSuite;
 Result := nd;
End;

Procedure ParseStatement(Var body: TNodes);
Var
 t: TToken;
 nd, h, it, cur_if, el: TNode;
 decos: TNodes;
 tgt: TNode;
Begin
 t := Cur;
 If t.kind = tkNewline Then Begin
  Advance;
  Exit;
 End;
 If t.kind = tkIndent Then ErrAt(t);
 If t.kind = tkName Then Begin
  If t.s = 'if' Then Begin
   Advance;
   nd := NewNode(nIf, t.line, t.col);
   nd.a := ParseNamedTest;
   nd.l1 := ParseSuite;
   cur_if := nd;
   While IsKw('elif') Do Begin
    el := NewNode(nIf, Cur.line, Cur.col);
    Advance;
    el.a := ParseNamedTest;
    el.l1 := ParseSuite;
    AddNode(cur_if.l2, el);
    cur_if := el;
   End;
   If AcceptKw('else') Then cur_if.l2 := ParseSuite;
   AddNode(body, nd);
   Exit;
  End;
  If t.s = 'while' Then Begin
   Advance;
   nd := NewNode(nWhile, t.line, t.col);
   nd.a := ParseNamedTest;
   nd.l1 := ParseSuite;
   If AcceptKw('else') Then nd.l2 := ParseSuite;
   AddNode(body, nd);
   Exit;
  End;
  If t.s = 'for' Then Begin
   Advance;
   nd := NewNode(nFor, t.line, t.col);
   tgt := ParseTargetList;
   CheckTarget(tgt, False);
   nd.a := tgt;
   ExpectKw('in');
   nd.b := ParseTestListStar(True);
   nd.l1 := ParseSuite;
   If AcceptKw('else') Then nd.l2 := ParseSuite;
   AddNode(body, nd);
   Exit;
  End;
  If t.s = 'try' Then Begin
   Advance;
   nd := NewNode(nTry, t.line, t.col);
   nd.l1 := ParseSuite;
   While IsKw('except') Do Begin
    h := NewNode(nHandler, Cur.line, Cur.col);
    Advance;
    If Not IsOp(':') Then Begin
     h.a := ParseTest;
     If AcceptKw('as') Then h.s := ExpectName
     Else If IsOp(',') Then
      SynErr('multiple exception types must be parenthesized', Cur.line,
       Cur.col);
    End;
    h.l1 := ParseSuite;
    AddNode(nd.l2, h);
   End;
   If AcceptKw('else') Then Begin
    If Length(nd.l2) = 0 Then ErrAt(PTok[PPos - 1]);
    nd.l3 := ParseSuite;
    nd.flag := True;
   End;
   If AcceptKw('finally') Then Begin
    nd.l4 := ParseSuite;
    nd.n := 1;
   End;
   If (Length(nd.l2) = 0) And (nd.n = 0) Then
    SynErr('invalid syntax', Cur.line, Cur.col, Cur.kind = tkEOF);
   AddNode(body, nd);
   Exit;
  End;
  If t.s = 'with' Then Begin
   Advance;
   nd := NewNode(nWith, t.line, t.col);
   Repeat
    it := NewNode(nWithItem, Cur.line, Cur.col);
    it.a := ParseTest;
    If AcceptKw('as') Then Begin
     it.b := ParseExpr;
     CheckTarget(it.b, False);
    End;
    AddNode(nd.l1, it);
   Until Not AcceptOp(',');
   nd.l2 := ParseSuite;
   AddNode(body, nd);
   Exit;
  End;
  If t.s = 'def' Then Begin
   SetLength(decos, 0);
   AddNode(body, ParseFuncDef(decos));
   Exit;
  End;
  If t.s = 'class' Then Begin
   SetLength(decos, 0);
   AddNode(body, ParseClassDef(decos));
   Exit;
  End;
  If t.s = 'async' Then
   SynErr('async/await is not supported', t.line, t.col);
 End;
 If IsOp('@') Then Begin
  SetLength(decos, 0);
  While IsOp('@') Do Begin
   Advance;
   AddNode(decos, ParseNamedTest);
   If Cur.kind <> tkNewline Then ErrAt(Cur);
   Advance;
  End;
  If IsKw('def') Then AddNode(body, ParseFuncDef(decos))
  Else If IsKw('class') Then AddNode(body, ParseClassDef(decos))
  Else ErrAt(Cur);
  Exit;
 End;
 { instructions simples separees par ; }
 AddNode(body, ParseSmallStmt);
 While IsOp(';') Do Begin
  Advance;
  If (Cur.kind = tkNewline) Or (Cur.kind = tkEOF) Then Break;
  AddNode(body, ParseSmallStmt);
 End;
 If Cur.kind = tkNewline Then Advance
 Else If Cur.kind <> tkEOF Then ErrAt(Cur);
End;

{ mode : 0 exec, 1 eval, 2 single (interactif) }
Function ParseSource(Const src0: AnsiString; mode: Integer): TNode;
Var
 src: AnsiString;
 root: TNode;
 body: TNodes;
Begin
 src := NormalizeSource(src0);
 SetSourceLines(src);
 Tokenize(src, PTok);
 PPos := 0;
 PInFunc := 0;
 root := NewNode(nModule, 1, 0);
 SetLength(body, 0);
 If mode = 1 Then Begin
  While Cur.kind = tkNewline Do Advance;
  root.a := ParseTestListStar(True);
  While Cur.kind = tkNewline Do Advance;
  If Cur.kind <> tkEOF Then ErrAt(Cur);
 End
 Else Begin
  While Cur.kind <> tkEOF Do ParseStatement(body);
 End;
 root.l1 := body;
 Result := root;
End;

{ ------------------------------------------------------------
  Jeu d'instructions (numeros d'opcodes de CPython 3.8)
  ------------------------------------------------------------ }
Const
 POP_TOP = 1; ROT_TWO = 2; ROT_THREE = 3; DUP_TOP = 4; DUP_TOP_TWO = 5;
 ROT_FOUR = 6; NOP = 9; UNARY_POSITIVE = 10; UNARY_NEGATIVE = 11;
 UNARY_NOT = 12; UNARY_INVERT = 15; BINARY_MATRIX_MULTIPLY = 16;
 INPLACE_MATRIX_MULTIPLY = 17; BINARY_POWER = 19; BINARY_MULTIPLY = 20;
 BINARY_MODULO = 22; BINARY_ADD = 23; BINARY_SUBTRACT = 24;
 BINARY_SUBSCR = 25; BINARY_FLOOR_DIVIDE = 26; BINARY_TRUE_DIVIDE = 27;
 INPLACE_FLOOR_DIVIDE = 28; INPLACE_TRUE_DIVIDE = 29; GET_AITER = 50;
 GET_ANEXT = 51; BEFORE_ASYNC_WITH = 52; BEGIN_FINALLY = 53;
 END_ASYNC_FOR = 54; INPLACE_ADD = 55; INPLACE_SUBTRACT = 56;
 INPLACE_MULTIPLY = 57; INPLACE_MODULO = 59; STORE_SUBSCR = 60;
 DELETE_SUBSCR = 61; BINARY_LSHIFT = 62; BINARY_RSHIFT = 63;
 BINARY_AND = 64; BINARY_XOR = 65; BINARY_OR = 66; INPLACE_POWER = 67;
 GET_ITER = 68; GET_YIELD_FROM_ITER = 69; PRINT_EXPR = 70;
 LOAD_BUILD_CLASS = 71; YIELD_FROM = 72; GET_AWAITABLE = 73;
 INPLACE_LSHIFT = 75; INPLACE_RSHIFT = 76; INPLACE_AND = 77;
 INPLACE_XOR = 78; INPLACE_OR = 79; WITH_CLEANUP_START = 81;
 WITH_CLEANUP_FINISH = 82; RETURN_VALUE = 83; IMPORT_STAR = 84;
 SETUP_ANNOTATIONS = 85; YIELD_VALUE = 86; POP_BLOCK = 87;
 END_FINALLY = 88; POP_EXCEPT = 89; STORE_NAME = 90; DELETE_NAME = 91;
 UNPACK_SEQUENCE = 92; FOR_ITER = 93; UNPACK_EX = 94; STORE_ATTR = 95;
 DELETE_ATTR = 96; STORE_GLOBAL = 97; DELETE_GLOBAL = 98;
 LOAD_CONST = 100; LOAD_NAME = 101; BUILD_TUPLE = 102; BUILD_LIST = 103;
 BUILD_SET = 104; BUILD_MAP = 105; LOAD_ATTR = 106; COMPARE_OP = 107;
 IMPORT_NAME = 108; IMPORT_FROM = 109; JUMP_FORWARD = 110;
 JUMP_IF_FALSE_OR_POP = 111; JUMP_IF_TRUE_OR_POP = 112;
 JUMP_ABSOLUTE = 113; POP_JUMP_IF_FALSE = 114; POP_JUMP_IF_TRUE = 115;
 LOAD_GLOBAL = 116; SETUP_FINALLY = 122; LOAD_FAST = 124;
 STORE_FAST = 125; DELETE_FAST = 126; RAISE_VARARGS = 130;
 CALL_FUNCTION = 131; MAKE_FUNCTION = 132; BUILD_SLICE = 133;
 LOAD_CLOSURE = 135; LOAD_DEREF = 136; STORE_DEREF = 137;
 DELETE_DEREF = 138; CALL_FUNCTION_KW = 141; CALL_FUNCTION_EX = 142;
 SETUP_WITH = 143; EXTENDED_ARG = 144; LIST_APPEND = 145;
 SET_ADD = 146; MAP_ADD = 147; LOAD_CLASSDEREF = 148;
 BUILD_LIST_UNPACK = 149; BUILD_MAP_UNPACK = 150;
 BUILD_MAP_UNPACK_WITH_CALL = 151; BUILD_TUPLE_UNPACK = 152;
 BUILD_SET_UNPACK = 153; SETUP_ASYNC_WITH = 154; FORMAT_VALUE = 155;
 BUILD_CONST_KEY_MAP = 156; BUILD_STRING = 157;
 BUILD_TUPLE_UNPACK_WITH_CALL = 158; LOAD_METHOD = 160;
 CALL_METHOD = 161; CALL_FINALLY = 162; POP_FINALLY = 163;
 HAVE_ARGUMENT = 90;

Var
 OpNames: Array[0..255] Of String[28];
 OptLevel: Integer;

Procedure InitOpNames;
Var
 i: Integer;
 Procedure N(op: Integer; Const s: String);
 Begin
  OpNames[op] := s;
 End;
Begin
 For i := 0 To 255 Do OpNames[i] := '<' + IntToStr(i) + '>';
 N(1, 'POP_TOP'); N(2, 'ROT_TWO'); N(3, 'ROT_THREE'); N(4, 'DUP_TOP');
 N(5, 'DUP_TOP_TWO'); N(6, 'ROT_FOUR'); N(9, 'NOP');
 N(10, 'UNARY_POSITIVE'); N(11, 'UNARY_NEGATIVE'); N(12, 'UNARY_NOT');
 N(15, 'UNARY_INVERT'); N(16, 'BINARY_MATRIX_MULTIPLY');
 N(17, 'INPLACE_MATRIX_MULTIPLY'); N(19, 'BINARY_POWER');
 N(20, 'BINARY_MULTIPLY'); N(22, 'BINARY_MODULO'); N(23, 'BINARY_ADD');
 N(24, 'BINARY_SUBTRACT'); N(25, 'BINARY_SUBSCR');
 N(26, 'BINARY_FLOOR_DIVIDE'); N(27, 'BINARY_TRUE_DIVIDE');
 N(28, 'INPLACE_FLOOR_DIVIDE'); N(29, 'INPLACE_TRUE_DIVIDE');
 N(50, 'GET_AITER'); N(51, 'GET_ANEXT'); N(52, 'BEFORE_ASYNC_WITH');
 N(53, 'BEGIN_FINALLY'); N(54, 'END_ASYNC_FOR'); N(55, 'INPLACE_ADD');
 N(56, 'INPLACE_SUBTRACT'); N(57, 'INPLACE_MULTIPLY');
 N(59, 'INPLACE_MODULO'); N(60, 'STORE_SUBSCR'); N(61, 'DELETE_SUBSCR');
 N(62, 'BINARY_LSHIFT'); N(63, 'BINARY_RSHIFT'); N(64, 'BINARY_AND');
 N(65, 'BINARY_XOR'); N(66, 'BINARY_OR'); N(67, 'INPLACE_POWER');
 N(68, 'GET_ITER'); N(69, 'GET_YIELD_FROM_ITER'); N(70, 'PRINT_EXPR');
 N(71, 'LOAD_BUILD_CLASS'); N(72, 'YIELD_FROM'); N(73, 'GET_AWAITABLE');
 N(75, 'INPLACE_LSHIFT'); N(76, 'INPLACE_RSHIFT'); N(77, 'INPLACE_AND');
 N(78, 'INPLACE_XOR'); N(79, 'INPLACE_OR'); N(81, 'WITH_CLEANUP_START');
 N(82, 'WITH_CLEANUP_FINISH'); N(83, 'RETURN_VALUE'); N(84, 'IMPORT_STAR');
 N(85, 'SETUP_ANNOTATIONS'); N(86, 'YIELD_VALUE'); N(87, 'POP_BLOCK');
 N(88, 'END_FINALLY'); N(89, 'POP_EXCEPT'); N(90, 'STORE_NAME');
 N(91, 'DELETE_NAME'); N(92, 'UNPACK_SEQUENCE'); N(93, 'FOR_ITER');
 N(94, 'UNPACK_EX'); N(95, 'STORE_ATTR'); N(96, 'DELETE_ATTR');
 N(97, 'STORE_GLOBAL'); N(98, 'DELETE_GLOBAL'); N(100, 'LOAD_CONST');
 N(101, 'LOAD_NAME'); N(102, 'BUILD_TUPLE'); N(103, 'BUILD_LIST');
 N(104, 'BUILD_SET'); N(105, 'BUILD_MAP'); N(106, 'LOAD_ATTR');
 N(107, 'COMPARE_OP'); N(108, 'IMPORT_NAME'); N(109, 'IMPORT_FROM');
 N(110, 'JUMP_FORWARD'); N(111, 'JUMP_IF_FALSE_OR_POP');
 N(112, 'JUMP_IF_TRUE_OR_POP'); N(113, 'JUMP_ABSOLUTE');
 N(114, 'POP_JUMP_IF_FALSE'); N(115, 'POP_JUMP_IF_TRUE');
 N(116, 'LOAD_GLOBAL'); N(122, 'SETUP_FINALLY'); N(124, 'LOAD_FAST');
 N(125, 'STORE_FAST'); N(126, 'DELETE_FAST'); N(130, 'RAISE_VARARGS');
 N(131, 'CALL_FUNCTION'); N(132, 'MAKE_FUNCTION'); N(133, 'BUILD_SLICE');
 N(135, 'LOAD_CLOSURE'); N(136, 'LOAD_DEREF'); N(137, 'STORE_DEREF');
 N(138, 'DELETE_DEREF'); N(141, 'CALL_FUNCTION_KW');
 N(142, 'CALL_FUNCTION_EX'); N(143, 'SETUP_WITH'); N(144, 'EXTENDED_ARG');
 N(145, 'LIST_APPEND'); N(146, 'SET_ADD'); N(147, 'MAP_ADD');
 N(148, 'LOAD_CLASSDEREF'); N(149, 'BUILD_LIST_UNPACK');
 N(150, 'BUILD_MAP_UNPACK'); N(151, 'BUILD_MAP_UNPACK_WITH_CALL');
 N(152, 'BUILD_TUPLE_UNPACK'); N(153, 'BUILD_SET_UNPACK');
 N(154, 'SETUP_ASYNC_WITH'); N(155, 'FORMAT_VALUE');
 N(156, 'BUILD_CONST_KEY_MAP'); N(157, 'BUILD_STRING');
 N(158, 'BUILD_TUPLE_UNPACK_WITH_CALL'); N(160, 'LOAD_METHOD');
 N(161, 'CALL_METHOD'); N(162, 'CALL_FINALLY'); N(163, 'POP_FINALLY');
End;

{ ------------------------------------------------------------
  Table des symboles
  ------------------------------------------------------------ }
Const
 symLocal = 1;
 symGlobal = 2;
 symNonlocal = 4;
 symParam = 8;
 symUsed = 16;
 symImport = 32;

 skNone = 0;
 skLocal = 1;
 skCell = 2;
 skFree = 3;
 skGlobalExp = 4;
 skGlobalImp = 5;

 scModule = 0;
 scFunction = 1;
 scClass = 2;
 scLambda = 3;
 scComp = 4;

Type
 TSym = Class
  flags: Integer;
  kind: Integer;
 End;

 TScope = Class
  kind: Integer;
  name: AnsiString;
  node: TNode;
  parent: TScope;
  syms: TStringList;
  order: TStrArr;
  children: Array Of TScope;
  isGen: Boolean;
  needsClassCell: Boolean;
  hasAnnot: Boolean;
  varnames, cellvars, freevars: TStrArr;
  nparams, nkwonly: Integer;
  hasVarArgs, hasKwArgs: Boolean;
  Function IsFunc: Boolean;
  Function Lookup(Const nm: AnsiString): TSym;
  Function Add(Const nm: AnsiString; fl: Integer): TSym;
 End;

Function TScope.IsFunc: Boolean;
Begin
 Result := kind In [scFunction, scLambda, scComp];
End;

Function TScope.Lookup(Const nm: AnsiString): TSym;
Var
 i: Integer;
Begin
 i := syms.IndexOf(nm);
 If i < 0 Then Result := Nil Else Result := TSym(syms.Objects[i]);
End;

Function TScope.Add(Const nm: AnsiString; fl: Integer): TSym;
Begin
 Result := Lookup(nm);
 If Result = Nil Then Begin
  Result := TSym.Create;
  Result.flags := 0;
  Result.kind := skNone;
  syms.AddObject(nm, Result);
  SetLength(order, Length(order) + 1);
  order[High(order)] := nm;
 End;
 Result.flags := Result.flags Or fl;
End;

Function NewScope(k: Integer; Const nm: AnsiString; nd: TNode;
 par: TScope): TScope;
Begin
 Result := TScope.Create;
 Result.kind := k;
 Result.name := nm;
 Result.node := nd;
 Result.parent := par;
 Result.syms := TStringList.Create;
 Result.syms.Sorted := True;
 Result.syms.Duplicates := dupIgnore;
 Result.syms.CaseSensitive := True;
 If par <> Nil Then Begin
  SetLength(par.children, Length(par.children) + 1);
  par.children[High(par.children)] := Result;
 End;
End;

Procedure SymExpr(sc: TScope; nd: TNode); Forward;
Procedure SymStmts(sc: TScope; Const l: TNodes); Forward;

Procedure SymStore(sc: TScope; nd: TNode);
Var
 j: Integer;
Begin
 If nd = Nil Then Exit;
 Case nd.k Of
  nName: Begin
    If (nd.s = '__debug__') Then
     SynErr('cannot assign to __debug__', nd.line, nd.col);
    sc.Add(nd.s, symLocal);
   End;
  nTuple, nList: For j := 0 To High(nd.l1) Do SymStore(sc, nd.l1[j]);
  nStarred: SymStore(sc, nd.a);
 Else
  SymExpr(sc, nd);
 End;
End;

Procedure SymParams(sc: TScope; args: TNode);
Var
 j: Integer;
Begin
 For j := 0 To High(args.l1) Do Begin
  sc.Add(args.l1[j].s, symParam Or symLocal);
  SetLength(sc.varnames, Length(sc.varnames) + 1);
  sc.varnames[High(sc.varnames)] := args.l1[j].s;
 End;
 sc.nparams := Length(args.l1);
 For j := 0 To High(args.l2) Do Begin
  sc.Add(args.l2[j].s, symParam Or symLocal);
  SetLength(sc.varnames, Length(sc.varnames) + 1);
  sc.varnames[High(sc.varnames)] := args.l2[j].s;
 End;
 sc.nkwonly := Length(args.l2);
 If args.c <> Nil Then Begin
  sc.Add(args.c.s, symParam Or symLocal);
  SetLength(sc.varnames, Length(sc.varnames) + 1);
  sc.varnames[High(sc.varnames)] := args.c.s;
  sc.hasVarArgs := True;
 End;
 If args.d <> Nil Then Begin
  sc.Add(args.d.s, symParam Or symLocal);
  SetLength(sc.varnames, Length(sc.varnames) + 1);
  sc.varnames[High(sc.varnames)] := args.d.s;
  sc.hasKwArgs := True;
 End;
End;

Procedure SymDefaults(sc: TScope; args: TNode);
Var
 j: Integer;
Begin
 For j := 0 To High(args.l1) Do SymExpr(sc, args.l1[j].a);
 For j := 0 To High(args.l2) Do SymExpr(sc, args.l2[j].a);
End;

Procedure SymComp(sc: TScope; nd: TNode);
Var
 cs: TScope;
 j, i: Integer;
 g: TNode;
Begin
 cs := NewScope(scComp, '<' + 'comp' + '>', nd, sc);
 nd.v := vNull;
 nd.s2 := '';
 { le premier iterable est evalue dans la portee englobante }
 SymExpr(sc, nd.l1[0].b);
 cs.Add('.0', symParam Or symLocal);
 SetLength(cs.varnames, 1);
 cs.varnames[0] := '.0';
 cs.nparams := 1;
 For j := 0 To High(nd.l1) Do Begin
  g := nd.l1[j];
  SymStore(cs, g.a);
  If j > 0 Then SymExpr(cs, g.b);
  For i := 0 To High(g.l1) Do SymExpr(cs, g.l1[i]);
 End;
 If nd.k = nDictComp Then Begin
  SymExpr(cs, nd.a);
  SymExpr(cs, nd.b);
 End
 Else SymExpr(cs, nd.a);
 If nd.k = nGenExp Then cs.isGen := True;
 nd.scope := cs;
End;

Function ScopeOf(nd: TNode): TScope;
Begin
 Result := TScope(nd.scope);
End;

Procedure SymExpr(sc: TScope; nd: TNode);
Var
 j: Integer;
 cs, t: TScope;
 sym: TSym;
Begin
 If nd = Nil Then Exit;
 Case nd.k Of
  nName: Begin
    sc.Add(nd.s, symUsed);
    If (nd.s = 'super') And sc.IsFunc Then sc.Add('__class__', symUsed);
   End;
  nConst, nNum, nStr: ;
  nLambda: Begin
    SymDefaults(sc, nd.b);
    cs := NewScope(scLambda, '<lambda>', nd, sc);
    SymParams(cs, nd.b);
    SymExpr(cs, nd.a);
    nd.scope := cs;
   End;
  nListComp, nSetComp, nGenExp, nDictComp: SymComp(sc, nd);
  nNamed: Begin
    SymExpr(sc, nd.b);
    t := sc;
    While t.kind = scComp Do t := t.parent;
    If sc.kind = scComp Then Begin
     { la cible est liee dans la portee englobante }
     cs := sc;
     While cs.kind = scComp Do Begin
      If t.IsFunc Then cs.Add(nd.a.s, symNonlocal)
      Else cs.Add(nd.a.s, symGlobal);
      cs := cs.parent;
     End;
     t.Add(nd.a.s, symLocal);
    End
    Else sc.Add(nd.a.s, symLocal);
   End;
  nYield, nYieldFrom: Begin
    If Not sc.IsFunc Then
     SynErr('''yield'' outside function', nd.line, nd.col);
    If sc.kind = scComp Then
     SynErr('''yield'' inside list comprehension', nd.line, nd.col);
    sc.isGen := True;
    SymExpr(sc, nd.a);
   End;
 Else
  SymExpr(sc, nd.a);
  SymExpr(sc, nd.b);
  SymExpr(sc, nd.c);
  SymExpr(sc, nd.d);
  For j := 0 To High(nd.l1) Do SymExpr(sc, nd.l1[j]);
  For j := 0 To High(nd.l2) Do SymExpr(sc, nd.l2[j]);
 End;
 sym := Nil;
End;

Function HasAnnotations(Const l: TNodes): Boolean;
Var
 j: Integer;
Begin
 Result := False;
 For j := 0 To High(l) Do Begin
  Case l[j].k Of
   nAnnAssign: Result := True;
   nIf, nWhile, nFor: Result := HasAnnotations(l[j].l1) Or
     HasAnnotations(l[j].l2);
   nTry: Result := HasAnnotations(l[j].l1) Or HasAnnotations(l[j].l3) Or
     HasAnnotations(l[j].l4);
   nWith: Result := HasAnnotations(l[j].l2);
  End;
  If Result Then Exit;
 End;
End;

Procedure SymStmts(sc: TScope; Const l: TNodes);
Var
 j, i: Integer;
 nd: TNode;
 cs: TScope;
 nm: AnsiString;
Begin
 For j := 0 To High(l) Do Begin
  nd := l[j];
  Case nd.k Of
   nExprStmt: SymExpr(sc, nd.a);
   nAssign: Begin
     SymExpr(sc, nd.a);
     For i := 0 To High(nd.l1) Do SymStore(sc, nd.l1[i]);
    End;
   nAugAssign: Begin
     SymExpr(sc, nd.b);
     If nd.a.k = nName Then Begin
      sc.Add(nd.a.s, symLocal Or symUsed);
     End
     Else SymExpr(sc, nd.a);
    End;
   nAnnAssign: Begin
     If nd.c <> Nil Then SymExpr(sc, nd.c);
     SymStore(sc, nd.a);
     If sc.kind <> scFunction Then SymExpr(sc, nd.b);
    End;
   nReturn: Begin
     If Not sc.IsFunc Then
      SynErr('''return'' outside function', nd.line, nd.col);
     SymExpr(sc, nd.a);
    End;
   nDelete: For i := 0 To High(nd.l1) Do SymStore(sc, nd.l1[i]);
   nPass, nBreak, nContinue: ;
   nRaise: Begin
     SymExpr(sc, nd.a);
     SymExpr(sc, nd.b);
    End;
   nGlobal: For i := 0 To High(nd.sl) Do Begin
     If Assigned(sc.Lookup(nd.sl[i])) And
      ((sc.Lookup(nd.sl[i]).flags And (symLocal Or symUsed)) <> 0) Then
      SynErr('name ''' + nd.sl[i] + ''' is used prior to global ' +
       'declaration', nd.line, nd.col);
     sc.Add(nd.sl[i], symGlobal);
    End;
   nNonlocal: For i := 0 To High(nd.sl) Do Begin
     If sc.kind = scModule Then
      SynErr('nonlocal declaration not allowed at module level', nd.line,
       nd.col);
     If Assigned(sc.Lookup(nd.sl[i])) And
      ((sc.Lookup(nd.sl[i]).flags And (symLocal Or symUsed)) <> 0) Then
      SynErr('name ''' + nd.sl[i] + ''' is used prior to nonlocal ' +
       'declaration', nd.line, nd.col);
     sc.Add(nd.sl[i], symNonlocal);
    End;
   nImport: For i := 0 To High(nd.l1) Do Begin
     If nd.l1[i].s2 <> '' Then nm := nd.l1[i].s2
     Else If Pos('.', nd.l1[i].s) > 0 Then
      nm := Copy(nd.l1[i].s, 1, Pos('.', nd.l1[i].s) - 1)
     Else nm := nd.l1[i].s;
     sc.Add(nm, symLocal Or symImport);
    End;
   nImportFrom: For i := 0 To High(nd.l1) Do Begin
     If nd.l1[i].s = '*' Then Begin
      If sc.kind <> scModule Then
       SynErr('import * only allowed at module level', nd.line, nd.col);
     End
     Else Begin
      If nd.l1[i].s2 <> '' Then nm := nd.l1[i].s2 Else nm := nd.l1[i].s;
      sc.Add(nm, symLocal Or symImport);
     End;
    End;
   nAssert: Begin
     SymExpr(sc, nd.a);
     SymExpr(sc, nd.b);
    End;
   nIf: Begin
     SymExpr(sc, nd.a);
     SymStmts(sc, nd.l1);
     SymStmts(sc, nd.l2);
    End;
   nWhile: Begin
     SymExpr(sc, nd.a);
     SymStmts(sc, nd.l1);
     SymStmts(sc, nd.l2);
    End;
   nFor: Begin
     SymExpr(sc, nd.b);
     SymStore(sc, nd.a);
     SymStmts(sc, nd.l1);
     SymStmts(sc, nd.l2);
    End;
   nTry: Begin
     SymStmts(sc, nd.l1);
     For i := 0 To High(nd.l2) Do Begin
      SymExpr(sc, nd.l2[i].a);
      If nd.l2[i].s <> '' Then sc.Add(nd.l2[i].s, symLocal);
      SymStmts(sc, nd.l2[i].l1);
     End;
     SymStmts(sc, nd.l3);
     SymStmts(sc, nd.l4);
    End;
   nWith: Begin
     For i := 0 To High(nd.l1) Do Begin
      SymExpr(sc, nd.l1[i].a);
      If nd.l1[i].b <> Nil Then SymStore(sc, nd.l1[i].b);
     End;
     SymStmts(sc, nd.l2);
    End;
   nFuncDef: Begin
     For i := 0 To High(nd.l2) Do SymExpr(sc, nd.l2[i]);
     SymDefaults(sc, nd.a);
     sc.Add(nd.s, symLocal);
     cs := NewScope(scFunction, nd.s, nd, sc);
     SymParams(cs, nd.a);
     SymStmts(cs, nd.l1);
     nd.scope := cs;
    End;
   nClassDef: Begin
     For i := 0 To High(nd.l3) Do SymExpr(sc, nd.l3[i]);
     For i := 0 To High(nd.l1) Do Begin
      If nd.l1[i].k = nKw Then SymExpr(sc, nd.l1[i].a)
      Else SymExpr(sc, nd.l1[i]);
     End;
     sc.Add(nd.s, symLocal);
     cs := NewScope(scClass, nd.s, nd, sc);
     cs.hasAnnot := HasAnnotations(nd.l2);
     SymStmts(cs, nd.l2);
     nd.scope := cs;
    End;
  End;
 End;
End;

{ ---- resolution ---- }
Type
 TNameSet = TStringList;

Function NewNameSet: TNameSet;
Begin
 Result := TStringList.Create;
 Result.Sorted := True;
 Result.Duplicates := dupIgnore;
End;

Procedure AnalyzeScope(sc: TScope; bound: TNameSet);
Var
 i, j: Integer;
 sym: TSym;
 nm: AnsiString;
 newBound, freeSet, localSet: TNameSet;
 child: TScope;
 ch: TSym;
Begin
 freeSet := NewNameSet;
 localSet := NewNameSet;
 For i := 0 To sc.syms.Count - 1 Do Begin
  nm := sc.syms[i];
  sym := TSym(sc.syms.Objects[i]);
  If (sym.flags And symGlobal) <> 0 Then sym.kind := skGlobalExp
  Else If (sym.flags And symNonlocal) <> 0 Then Begin
   If bound.IndexOf(nm) < 0 Then
    SynErr('no binding for nonlocal ''' + nm + ''' found', sc.node.line,
     sc.node.col);
   sym.kind := skFree;
   freeSet.Add(nm);
  End
  Else If (sym.flags And symLocal) <> 0 Then Begin
   sym.kind := skLocal;
   If sc.IsFunc Then localSet.Add(nm);
  End
  Else Begin
   If sc.kind = scModule Then sym.kind := skGlobalImp
   Else If bound.IndexOf(nm) >= 0 Then Begin
    sym.kind := skFree;
    freeSet.Add(nm);
   End
   Else sym.kind := skGlobalImp;
  End;
 End;
 { portee vue par les enfants }
 newBound := NewNameSet;
 newBound.AddStrings(bound);
 If sc.IsFunc Then newBound.AddStrings(localSet);
 If sc.kind = scClass Then newBound.Add('__class__');
 For i := 0 To High(sc.children) Do Begin
  child := sc.children[i];
  If child.kind = scClass Then Begin
   AnalyzeScope(child, newBound);
  End
  Else AnalyzeScope(child, newBound);
  { variables libres des enfants }
  For j := 0 To High(child.freevars) Do Begin
   nm := child.freevars[j];
   ch := sc.Lookup(nm);
   If sc.IsFunc And (localSet.IndexOf(nm) >= 0) Then Begin
    ch := sc.Lookup(nm);
    If ch <> Nil Then ch.kind := skCell;
   End
   Else If (sc.kind = scClass) And (nm = '__class__') Then
    sc.needsClassCell := True
   Else If bound.IndexOf(nm) >= 0 Then Begin
    { passer a travers }
    ch := sc.Add(nm, 0);
    If (ch.kind = skNone) Or (ch.kind = skGlobalImp) Then ch.kind := skFree;
    freeSet.Add(nm);
   End;
  End;
 End;
 { listes finales }
 SetLength(sc.freevars, 0);
 For i := 0 To freeSet.Count - 1 Do Begin
  SetLength(sc.freevars, Length(sc.freevars) + 1);
  sc.freevars[High(sc.freevars)] := freeSet[i];
 End;
 SetLength(sc.cellvars, 0);
 For i := 0 To sc.syms.Count - 1 Do Begin
  sym := TSym(sc.syms.Objects[i]);
  If sym.kind = skCell Then Begin
   SetLength(sc.cellvars, Length(sc.cellvars) + 1);
   sc.cellvars[High(sc.cellvars)] := sc.syms[i];
  End;
 End;
 If sc.needsClassCell Then Begin
  SetLength(sc.cellvars, Length(sc.cellvars) + 1);
  sc.cellvars[High(sc.cellvars)] := '__class__';
 End;
 { variables locales supplementaires dans l'ordre d'apparition }
 If sc.IsFunc Then
  For i := 0 To High(sc.order) Do Begin
   sym := sc.Lookup(sc.order[i]);
   If (sym.kind In [skLocal, skCell]) And ((sym.flags And symParam) = 0)
    And (sym.kind = skLocal) Then Begin
    SetLength(sc.varnames, Length(sc.varnames) + 1);
    sc.varnames[High(sc.varnames)] := sc.order[i];
   End;
  End;
 newBound.Free;
 freeSet.Free;
 localSet.Free;
End;

Function ScopeKindOf(sc: TScope; Const nm: AnsiString): Integer;
Var
 s: TSym;
Begin
 s := sc.Lookup(nm);
 If s = Nil Then Result := skGlobalImp Else Result := s.kind;
End;

Function IndexOfStr(Const a: TStrArr; Const s: AnsiString): Integer;
Var
 i: Integer;
Begin
 Result := -1;
 For i := 0 To High(a) Do
  If a[i] = s Then Begin
   Result := i;
   Exit;
  End;
End;

{ ------------------------------------------------------------
  Generateur de bytecode
  ------------------------------------------------------------ }
Const
 fbLoopWhile = 1;
 fbLoopFor = 2;
 fbExcept = 3;
 fbFinallyTry = 4;
 fbFinallyEnd = 5;
 fbWith = 6;
 fbHandler = 7;

Type
 TInstr = Record
  op: Byte;
  arg: Integer;
  line: Integer;
  lbl: Integer;
 End;

 TFBlock = Record
  kind: Integer;
  lbl1, lbl2: Integer;
 End;

 TGen = Class
  sc: TScope;
  ins: Array Of TInstr;
  nins: Integer;
  labels: Array Of Integer;
  nlabels: Integer;
  consts: TValArr;
  nconsts: Integer;
  names: TStrArr;
  fb: Array Of TFBlock;
  nfb: Integer;
  curLine: Integer;
  fname, name, qual: AnsiString;
  firstline: Integer;
  interactive: Boolean;
  clsName: AnsiString;
  parent: TGen;
  posonly: Integer;
 End;

Function IsRelJump(op: Integer): Boolean;
Begin
 Result := op In [FOR_ITER, JUMP_FORWARD, SETUP_FINALLY, SETUP_WITH,
  CALL_FINALLY, SETUP_ASYNC_WITH];
End;

Function IsAbsJump(op: Integer): Boolean;
Begin
 Result := op In [JUMP_ABSOLUTE, JUMP_IF_FALSE_OR_POP, JUMP_IF_TRUE_OR_POP,
  POP_JUMP_IF_FALSE, POP_JUMP_IF_TRUE];
End;

Function NewLabel(g: TGen): Integer;
Begin
 If g.nlabels >= Length(g.labels) Then
  SetLength(g.labels, (g.nlabels + 8) * 2);
 g.labels[g.nlabels] := -1;
 Result := g.nlabels;
 Inc(g.nlabels);
End;

Procedure SetLabel(g: TGen; l: Integer);
Begin
 g.labels[l] := g.nins;
End;

Procedure Emit(g: TGen; op: Integer; arg: Integer = 0);
Begin
 If g.nins >= Length(g.ins) Then SetLength(g.ins, (g.nins + 16) * 2);
 g.ins[g.nins].op := op;
 g.ins[g.nins].arg := arg;
 g.ins[g.nins].line := g.curLine;
 g.ins[g.nins].lbl := -1;
 Inc(g.nins);
End;

Procedure EmitJ(g: TGen; op: Integer; l: Integer);
Begin
 Emit(g, op, 0);
 g.ins[g.nins - 1].lbl := l;
End;

Procedure SetLine(g: TGen; nd: TNode);
Begin
 If (nd <> Nil) And (nd.line > 0) Then g.curLine := nd.line;
End;

Function AddConst(g: TGen; Const v: TVal): Integer;
Var
 i: Integer;
 c: TVal;
Begin
 For i := 0 To g.nconsts - 1 Do Begin
  c := g.consts[i];
  If c.k <> v.k Then Continue;
  Case v.k Of
   vkNone: Begin Result := i; Exit; End;
   vkBool, vkInt: If c.i = v.i Then Begin Result := i; Exit; End;
   vkFloat: If PQWord(@c.d)^ = PQWord(@v.d)^ Then Begin
      Result := i;
      Exit;
     End;
   vkObj: Begin
     If c.o = v.o Then Begin
      Result := i;
      Exit;
     End;
     If (c.o Is TPyStr) And (v.o Is TPyStr) And
      (TPyStr(c.o).s = TPyStr(v.o).s) Then Begin
      Result := i;
      Exit;
     End;
     If (c.o Is TPyBytes) And (v.o Is TPyBytes) And
      (TPyBytes(c.o).s = TPyBytes(v.o).s) Then Begin
      Result := i;
      Exit;
     End;
    End;
  End;
 End;
 If g.nconsts >= Length(g.consts) Then
  SetLength(g.consts, (g.nconsts + 8) * 2);
 g.consts[g.nconsts] := v;
 Result := g.nconsts;
 Inc(g.nconsts);
End;

Procedure EmitConst(g: TGen; Const v: TVal);
Begin
 Emit(g, LOAD_CONST, AddConst(g, v));
End;

Function AddName(g: TGen; Const s: AnsiString): Integer;
Var
 i: Integer;
Begin
 For i := 0 To High(g.names) Do
  If g.names[i] = s Then Begin
   Result := i;
   Exit;
  End;
 SetLength(g.names, Length(g.names) + 1);
 g.names[High(g.names)] := s;
 Result := High(g.names);
End;

Function Mangle(g: TGen; Const nm: AnsiString): AnsiString;
Var
 cn: AnsiString;
 k: Integer;
Begin
 Result := nm;
 If (g.clsName = '') Or (Length(nm) < 3) Then Exit;
 If (Copy(nm, 1, 2) <> '__') Or (Copy(nm, Length(nm) - 1, 2) = '__') Or
  (Pos('.', nm) > 0) Then Exit;
 cn := g.clsName;
 k := 1;
 While (k <= Length(cn)) And (cn[k] = '_') Do Inc(k);
 cn := Copy(cn, k, Length(cn));
 If cn = '' Then Exit;
 Result := '_' + cn + nm;
End;

Procedure PushFB(g: TGen; kind, l1, l2: Integer);
Begin
 If g.nfb >= Length(g.fb) Then SetLength(g.fb, (g.nfb + 4) * 2);
 g.fb[g.nfb].kind := kind;
 g.fb[g.nfb].lbl1 := l1;
 g.fb[g.nfb].lbl2 := l2;
 Inc(g.nfb);
End;

Procedure PopFB(g: TGen);
Begin
 Dec(g.nfb);
End;

Procedure CgExpr(g: TGen; nd: TNode); Forward;
Procedure CgStmts(g: TGen; Const l: TNodes); Forward;
Procedure CgStore(g: TGen; nd: TNode); Forward;
Procedure CgJumpIf(g: TGen; nd: TNode; lbl: Integer; sense: Boolean);
 Forward;
Function CgFunction(g: TGen; nd: TNode; sc: TScope; Const nm: AnsiString;
 Const qual: AnsiString): TPyCode; Forward;
Procedure CgComprehension(g: TGen; nd: TNode); Forward;

{ ---- noms ---- }
Procedure CgName(g: TGen; Const nm0: AnsiString; mode: Integer);
Var
 sym: TSym;
 kind, idx, op: Integer;
 nm: AnsiString;
Begin
 nm := nm0;
 If g.sc.kind = scClass Then nm := Mangle(g, nm0);
 sym := g.sc.Lookup(nm0);
 If sym = Nil Then kind := skGlobalImp Else kind := sym.kind;
 If (g.sc.kind = scModule) And (kind <> skGlobalExp) Then kind := skNone;
 If (g.sc.kind = scClass) And (kind In [skLocal, skGlobalImp]) Then
  kind := skNone;
 Case kind Of
  skLocal: Begin
    idx := IndexOfStr(g.sc.varnames, nm0);
    Case mode Of
     0: op := LOAD_FAST;
     1: op := STORE_FAST;
    Else op := DELETE_FAST;
    End;
    Emit(g, op, idx);
   End;
  skCell, skFree: Begin
    idx := IndexOfStr(g.sc.cellvars, nm0);
    If idx < 0 Then
     idx := Length(g.sc.cellvars) + IndexOfStr(g.sc.freevars, nm0);
    Case mode Of
     0: If g.sc.kind = scClass Then op := LOAD_CLASSDEREF
        Else op := LOAD_DEREF;
     1: op := STORE_DEREF;
    Else op := DELETE_DEREF;
    End;
    Emit(g, op, idx);
   End;
  skGlobalExp, skGlobalImp: Begin
    Case mode Of
     0: op := LOAD_GLOBAL;
     1: op := STORE_GLOBAL;
    Else op := DELETE_GLOBAL;
    End;
    Emit(g, op, AddName(g, nm));
   End;
 Else
  Case mode Of
   0: op := LOAD_NAME;
   1: op := STORE_NAME;
  Else op := DELETE_NAME;
  End;
  Emit(g, op, AddName(g, nm));
 End;
End;

{ ---- appels ---- }
Function IsStarArg(a: TNode): Boolean;
Begin
 Result := (a.k = nStarred) Or ((a.k = nKw) And (a.s = ''));
End;

Procedure CgCallTail(g: TGen; args: TNodes; pre: Integer);
{ pre : nombre de valeurs deja empilees apres la fonction }
Var
 j, npos, nkwn, nrun, nparts: Integer;
 hasStar, hasKw: Boolean;
 names: TPyTuple;
 kwNodes: TNodes;
 inRun: Boolean;
Begin
 hasStar := False;
 hasKw := False;
 For j := 0 To High(args) Do Begin
  If args[j].k = nStarred Then hasStar := True;
  If args[j].k = nKw Then Begin
   hasKw := True;
   If args[j].s = '' Then hasStar := True;
  End;
 End;
 If Not hasStar Then Begin
  npos := 0;
  nkwn := 0;
  For j := 0 To High(args) Do
   If args[j].k <> nKw Then Begin
    CgExpr(g, args[j]);
    Inc(npos);
   End;
  For j := 0 To High(args) Do
   If args[j].k = nKw Then Begin
    CgExpr(g, args[j].a);
    Inc(nkwn);
   End;
  If nkwn = 0 Then Emit(g, CALL_FUNCTION, npos + pre)
  Else Begin
   names := NewTuple(nkwn);
   nkwn := 0;
   For j := 0 To High(args) Do
    If args[j].k = nKw Then Begin
     names.items[nkwn] := VStr(args[j].s);
     Inc(nkwn);
    End;
   EmitConst(g, VObj(names));
   Emit(g, CALL_FUNCTION_KW, npos + nkwn + pre);
  End;
  Exit;
 End;
 { chemin etendu : tuple d'arguments positionnels }
 nparts := 0;
 nrun := pre;
 inRun := pre > 0;
 For j := 0 To High(args) Do Begin
  If args[j].k = nKw Then Continue;
  If args[j].k = nStarred Then Begin
   If inRun Then Begin
    Emit(g, BUILD_TUPLE, nrun);
    Inc(nparts);
    nrun := 0;
    inRun := False;
   End;
   CgExpr(g, args[j].a);
   Inc(nparts);
  End
  Else Begin
   CgExpr(g, args[j]);
   Inc(nrun);
   inRun := True;
  End;
 End;
 If inRun Then Begin
  Emit(g, BUILD_TUPLE, nrun);
  Inc(nparts);
 End;
 If (nparts = 1) And (pre = 0) And (Length(args) > 0) And
  (args[0].k = nStarred) Then
  { un seul *args : utilise directement }
 Else If nparts = 0 Then Emit(g, BUILD_TUPLE, 0)
 Else Emit(g, BUILD_TUPLE_UNPACK_WITH_CALL, nparts);
 If hasKw Then Begin
  { dictionnaire des mots-cles }
  nparts := 0;
  SetLength(kwNodes, 0);
  For j := 0 To High(args) Do Begin
   If args[j].k <> nKw Then Continue;
   If args[j].s = '' Then Begin
    If Length(kwNodes) > 0 Then Begin
     For npos := 0 To High(kwNodes) Do CgExpr(g, kwNodes[npos].a);
     names := NewTuple(Length(kwNodes));
     For npos := 0 To High(kwNodes) Do
      names.items[npos] := VStr(kwNodes[npos].s);
     EmitConst(g, VObj(names));
     Emit(g, BUILD_CONST_KEY_MAP, Length(kwNodes));
     Inc(nparts);
     SetLength(kwNodes, 0);
    End;
    CgExpr(g, args[j].a);
    Inc(nparts);
   End
   Else AddNode(kwNodes, args[j]);
  End;
  If Length(kwNodes) > 0 Then Begin
   For npos := 0 To High(kwNodes) Do CgExpr(g, kwNodes[npos].a);
   names := NewTuple(Length(kwNodes));
   For npos := 0 To High(kwNodes) Do
    names.items[npos] := VStr(kwNodes[npos].s);
   EmitConst(g, VObj(names));
   Emit(g, BUILD_CONST_KEY_MAP, Length(kwNodes));
   Inc(nparts);
  End;
  If nparts > 1 Then Emit(g, BUILD_MAP_UNPACK_WITH_CALL, nparts)
  Else If (nparts = 1) And (Length(args) > 0) Then Begin
   { un seul **kw : doit etre copie en dict par la VM }
  End;
  Emit(g, CALL_FUNCTION_EX, 1);
 End
 Else Emit(g, CALL_FUNCTION_EX, 0);
End;

Procedure CgCall(g: TGen; nd: TNode);
Var
 j: Integer;
 plain: Boolean;
Begin
 plain := True;
 For j := 0 To High(nd.l1) Do
  If nd.l1[j].k = nKw Then plain := False
  Else If nd.l1[j].k = nStarred Then plain := False;
 If plain And (nd.a.k = nAttr) And (Length(nd.l1) < 200) Then Begin
  CgExpr(g, nd.a.a);
  SetLine(g, nd.a);
  Emit(g, LOAD_METHOD, AddName(g, Mangle(g, nd.a.s)));
  For j := 0 To High(nd.l1) Do CgExpr(g, nd.l1[j]);
  g.curLine := nd.line;
  Emit(g, CALL_METHOD, Length(nd.l1));
  Exit;
 End;
 CgExpr(g, nd.a);
 CgCallTail(g, nd.l1, 0);
 g.curLine := nd.line;
End;

Procedure CgSequence(g: TGen; nd: TNode; build, buildUnpack: Integer);
Var
 j, nrun, nparts: Integer;
 hasStar: Boolean;
 inRun: Boolean;
Begin
 hasStar := False;
 For j := 0 To High(nd.l1) Do
  If nd.l1[j].k = nStarred Then hasStar := True;
 If Not hasStar Then Begin
  For j := 0 To High(nd.l1) Do CgExpr(g, nd.l1[j]);
  Emit(g, build, Length(nd.l1));
  Exit;
 End;
 nparts := 0;
 nrun := 0;
 inRun := False;
 For j := 0 To High(nd.l1) Do Begin
  If nd.l1[j].k = nStarred Then Begin
   If inRun Then Begin
    Emit(g, build, nrun);
    Inc(nparts);
    nrun := 0;
    inRun := False;
   End;
   CgExpr(g, nd.l1[j].a);
   Inc(nparts);
  End
  Else Begin
   CgExpr(g, nd.l1[j]);
   Inc(nrun);
   inRun := True;
  End;
 End;
 If inRun Then Begin
  Emit(g, build, nrun);
  Inc(nparts);
 End;
 Emit(g, buildUnpack, nparts);
End;

Function IsConstNode(nd: TNode; Var v: TVal): Boolean;
Var
 t: TPyTuple;
 j: Integer;
 x: TVal;
Begin
 Result := False;
 Case nd.k Of
  nNum, nConst: Begin
    v := nd.v;
    Result := True;
   End;
  nStr: Begin
    If nd.flag Then v := VBytes(nd.s) Else v := VStr(nd.s);
    Result := True;
   End;
  nUnary: If (nd.s = '-') And (nd.a.k = nNum) Then Begin
    If nd.a.v.k = vkFloat Then v := VFloat(-nd.a.v.d)
    Else v := IntNeg(nd.a.v);
    Result := True;
   End;
  nTuple: Begin
    If Length(nd.l1) = 0 Then Begin
     v := VObj(EmptyTuple);
     Result := True;
     Exit;
    End;
    For j := 0 To High(nd.l1) Do
     If Not IsConstNode(nd.l1[j], x) Then Exit;
    t := NewTuple(Length(nd.l1));
    For j := 0 To High(nd.l1) Do Begin
     IsConstNode(nd.l1[j], x);
     t.items[j] := x;
    End;
    v := VObj(t);
    Result := True;
   End;
 End;
End;

Procedure CgSlice(g: TGen; nd: TNode);
Begin
 If nd.a <> Nil Then CgExpr(g, nd.a) Else EmitConst(g, vNone);
 If nd.b <> Nil Then CgExpr(g, nd.b) Else EmitConst(g, vNone);
 If nd.c <> Nil Then Begin
  CgExpr(g, nd.c);
  Emit(g, BUILD_SLICE, 3);
 End
 Else Emit(g, BUILD_SLICE, 2);
End;

Function CmpOpCode(Const s: AnsiString): Integer;
Begin
 If s = '<' Then Result := 0
 Else If s = '<=' Then Result := 1
 Else If s = '==' Then Result := 2
 Else If s = '!=' Then Result := 3
 Else If s = '>' Then Result := 4
 Else If s = '>=' Then Result := 5
 Else If s = 'in' Then Result := 6
 Else If s = 'not in' Then Result := 7
 Else If s = 'is' Then Result := 8
 Else Result := 9;
End;

Function BinOpCode(Const s: AnsiString; inplace: Boolean): Integer;
Begin
 Result := 0;
 If s = '+' Then Result := BINARY_ADD
 Else If s = '-' Then Result := BINARY_SUBTRACT
 Else If s = '*' Then Result := BINARY_MULTIPLY
 Else If s = '/' Then Result := BINARY_TRUE_DIVIDE
 Else If s = '//' Then Result := BINARY_FLOOR_DIVIDE
 Else If s = '%' Then Result := BINARY_MODULO
 Else If s = '**' Then Result := BINARY_POWER
 Else If s = '<<' Then Result := BINARY_LSHIFT
 Else If s = '>>' Then Result := BINARY_RSHIFT
 Else If s = '&' Then Result := BINARY_AND
 Else If s = '|' Then Result := BINARY_OR
 Else If s = '^' Then Result := BINARY_XOR
 Else If s = '@' Then Result := BINARY_MATRIX_MULTIPLY;
 If inplace Then Begin
  Case Result Of
   BINARY_ADD: Result := INPLACE_ADD;
   BINARY_SUBTRACT: Result := INPLACE_SUBTRACT;
   BINARY_MULTIPLY: Result := INPLACE_MULTIPLY;
   BINARY_TRUE_DIVIDE: Result := INPLACE_TRUE_DIVIDE;
   BINARY_FLOOR_DIVIDE: Result := INPLACE_FLOOR_DIVIDE;
   BINARY_MODULO: Result := INPLACE_MODULO;
   BINARY_POWER: Result := INPLACE_POWER;
   BINARY_LSHIFT: Result := INPLACE_LSHIFT;
   BINARY_RSHIFT: Result := INPLACE_RSHIFT;
   BINARY_AND: Result := INPLACE_AND;
   BINARY_OR: Result := INPLACE_OR;
   BINARY_XOR: Result := INPLACE_XOR;
   BINARY_MATRIX_MULTIPLY: Result := INPLACE_MATRIX_MULTIPLY;
  End;
 End;
End;

Procedure CgClosureTuple(g: TGen; child: TScope; Var flags: Integer);
Var
 j, idx: Integer;
Begin
 If Length(child.freevars) = 0 Then Exit;
 For j := 0 To High(child.freevars) Do Begin
  idx := IndexOfStr(g.sc.cellvars, child.freevars[j]);
  If idx < 0 Then
   idx := Length(g.sc.cellvars) + IndexOfStr(g.sc.freevars,
    child.freevars[j]);
  Emit(g, LOAD_CLOSURE, idx);
 End;
 Emit(g, BUILD_TUPLE, Length(child.freevars));
 flags := flags Or 8;
End;

Function ChildQual(g: TGen; Const nm: AnsiString): AnsiString;
Begin
 If g.qual = '' Then Result := nm
 Else If g.sc.IsFunc Then Result := g.qual + '.<locals>.' + nm
 Else Result := g.qual + '.' + nm;
End;


{ ------------------------------------------------------------
  Assemblage : pile, adresses, lnotab
  ------------------------------------------------------------ }
Function PopCnt(x: Integer): Integer;
Begin
 Result := 0;
 While x <> 0 Do Begin
  Inc(Result, x And 1);
  x := x Shr 1;
 End;
End;

Function StackEffect(op, arg: Integer; jump: Boolean): Integer;
Begin
 Case op Of
  POP_TOP: Result := -1;
  ROT_TWO, ROT_THREE, ROT_FOUR, NOP: Result := 0;
  DUP_TOP: Result := 1;
  DUP_TOP_TWO: Result := 2;
  UNARY_POSITIVE, UNARY_NEGATIVE, UNARY_NOT, UNARY_INVERT: Result := 0;
  BINARY_MATRIX_MULTIPLY, INPLACE_MATRIX_MULTIPLY, BINARY_POWER,
  BINARY_MULTIPLY, BINARY_MODULO, BINARY_ADD, BINARY_SUBTRACT,
  BINARY_SUBSCR, BINARY_FLOOR_DIVIDE, BINARY_TRUE_DIVIDE,
  INPLACE_FLOOR_DIVIDE, INPLACE_TRUE_DIVIDE, INPLACE_ADD,
  INPLACE_SUBTRACT, INPLACE_MULTIPLY, INPLACE_MODULO, BINARY_LSHIFT,
  BINARY_RSHIFT, BINARY_AND, BINARY_XOR, BINARY_OR, INPLACE_POWER,
  INPLACE_LSHIFT, INPLACE_RSHIFT, INPLACE_AND, INPLACE_XOR,
  INPLACE_OR: Result := -1;
  GET_ITER, GET_YIELD_FROM_ITER: Result := 0;
  PRINT_EXPR: Result := -1;
  LOAD_BUILD_CLASS: Result := 1;
  YIELD_FROM: Result := -1;
  YIELD_VALUE: Result := 0;
  RETURN_VALUE: Result := -1;
  IMPORT_STAR: Result := -1;
  SETUP_ANNOTATIONS: Result := 0;
  STORE_SUBSCR: Result := -3;
  DELETE_SUBSCR: Result := -2;
  WITH_CLEANUP_START: Result := 1;
  WITH_CLEANUP_FINISH: Result := -1;
  POP_BLOCK: Result := 0;
  END_FINALLY: Result := -1;
  POP_EXCEPT: Result := -3;
  BEGIN_FINALLY: Result := 1;
  POP_FINALLY: Result := -1;
  STORE_NAME, STORE_GLOBAL, STORE_FAST, STORE_DEREF: Result := -1;
  DELETE_NAME, DELETE_GLOBAL, DELETE_FAST, DELETE_DEREF: Result := 0;
  UNPACK_SEQUENCE: Result := arg - 1;
  UNPACK_EX: Result := (arg And 255) + (arg Shr 8);
  FOR_ITER: If jump Then Result := -1 Else Result := 1;
  STORE_ATTR: Result := -2;
  DELETE_ATTR: Result := -1;
  LOAD_CONST, LOAD_NAME, LOAD_GLOBAL, LOAD_FAST, LOAD_CLOSURE,
  LOAD_DEREF, LOAD_CLASSDEREF: Result := 1;
  BUILD_TUPLE, BUILD_LIST, BUILD_SET, BUILD_STRING, BUILD_SLICE,
  BUILD_LIST_UNPACK, BUILD_MAP_UNPACK, BUILD_MAP_UNPACK_WITH_CALL,
  BUILD_TUPLE_UNPACK, BUILD_SET_UNPACK, BUILD_TUPLE_UNPACK_WITH_CALL:
   Result := 1 - arg;
  BUILD_MAP: Result := 1 - 2 * arg;
  BUILD_CONST_KEY_MAP: Result := -arg;
  LOAD_ATTR: Result := 0;
  COMPARE_OP: Result := -1;
  IMPORT_NAME: Result := -1;
  IMPORT_FROM: Result := 1;
  JUMP_FORWARD, JUMP_ABSOLUTE: Result := 0;
  JUMP_IF_FALSE_OR_POP, JUMP_IF_TRUE_OR_POP:
   If jump Then Result := 0 Else Result := -1;
  POP_JUMP_IF_FALSE, POP_JUMP_IF_TRUE: Result := -1;
  SETUP_FINALLY: If jump Then Result := 6 Else Result := 0;
  SETUP_WITH: If jump Then Result := 6 Else Result := 1;
  RAISE_VARARGS: Result := -arg;
  CALL_FUNCTION: Result := -arg;
  CALL_FUNCTION_KW: Result := -arg - 1;
  CALL_FUNCTION_EX: Result := -1 - (arg And 1);
  MAKE_FUNCTION: Result := -1 - PopCnt(arg And 15);
  LIST_APPEND, SET_ADD: Result := -1;
  MAP_ADD: Result := -2;
  FORMAT_VALUE: If (arg And 4) <> 0 Then Result := -1 Else Result := 0;
  LOAD_METHOD: Result := 1;
  CALL_METHOD: Result := -arg - 1;
  CALL_FINALLY: If jump Then Result := 1 Else Result := 0;
  EXTENDED_ARG: Result := 0;
 Else
  Result := 0;
 End;
End;

Function ArgSize(arg: Integer): Integer;
Begin
 If arg < 256 Then Result := 2
 Else If arg < 65536 Then Result := 4
 Else If arg < 16777216 Then Result := 6
 Else Result := 8;
End;

Function Assemble(g: TGen): TPyCode;
Var
 n, i, off, a, sz, nb, k, j: Integer;
 offs, sizes: Array Of Integer;
 changed: Boolean;
 co: Array Of Byte;
 lnotab: AnsiString;
 lastOff, lastLine, dOff, dLine: Integer;
 code: TPyCode;
 depth: Array Of Integer;
 work: Array Of Integer;
 wdepth: Array Of Integer;
 nw, cur, d, d1, dj, maxd, t, op: Integer;
 sc: TScope;
 fl: Integer;
Begin
 sc := g.sc;
 n := g.nins;
 SetLength(offs, n + 1);
 SetLength(sizes, n);
 For i := 0 To n - 1 Do sizes[i] := 2;
 Repeat
  changed := False;
  off := 0;
  For i := 0 To n - 1 Do Begin
   offs[i] := off;
   Inc(off, sizes[i]);
  End;
  offs[n] := off;
  For i := 0 To n - 1 Do Begin
   If g.ins[i].lbl >= 0 Then Begin
    t := g.labels[g.ins[i].lbl];
    If t < 0 Then t := n;
    If IsRelJump(g.ins[i].op) Then
     g.ins[i].arg := offs[t] - (offs[i] + sizes[i])
    Else g.ins[i].arg := offs[t];
   End;
   sz := ArgSize(g.ins[i].arg);
   If sz > sizes[i] Then Begin
    sizes[i] := sz;
    changed := True;
   End;
  End;
 Until Not changed;
 SetLength(co, offs[n]);
 For i := 0 To n - 1 Do Begin
  a := g.ins[i].arg;
  k := offs[i];
  nb := sizes[i] Div 2 - 1;
  For j := nb DownTo 1 Do Begin
   co[k] := EXTENDED_ARG;
   co[k + 1] := (a Shr (8 * j)) And 255;
   Inc(k, 2);
  End;
  co[k] := g.ins[i].op;
  co[k + 1] := a And 255;
 End;
 { co_lnotab }
 lnotab := '';
 lastOff := 0;
 lastLine := g.firstline;
 For i := 0 To n - 1 Do Begin
  If (g.ins[i].line > 0) And (g.ins[i].line <> lastLine) Then Begin
   dOff := offs[i] - lastOff;
   dLine := g.ins[i].line - lastLine;
   While dOff > 255 Do Begin
    lnotab := lnotab + #255 + #0;
    Dec(dOff, 255);
   End;
   While dLine > 127 Do Begin
    lnotab := lnotab + Chr(dOff) + #127;
    dOff := 0;
    Dec(dLine, 127);
   End;
   While dLine < -128 Do Begin
    lnotab := lnotab + Chr(dOff) + #128;
    dOff := 0;
    Inc(dLine, 128);
   End;
   lnotab := lnotab + Chr(dOff) + Chr(dLine And 255);
   lastOff := offs[i];
   lastLine := g.ins[i].line;
  End;
 End;
 { taille de pile }
 SetLength(depth, n + 1);
 For i := 0 To n Do depth[i] := -1;
 SetLength(work, 64);
 SetLength(wdepth, 64);
 nw := 0;
 maxd := 0;
 work[0] := 0;
 wdepth[0] := 0;
 nw := 1;
 While nw > 0 Do Begin
  Dec(nw);
  cur := work[nw];
  d := wdepth[nw];
  While cur < n Do Begin
   If depth[cur] >= d Then Break;
   depth[cur] := d;
   op := g.ins[cur].op;
   d1 := d + StackEffect(op, g.ins[cur].arg, False);
   If d > maxd Then maxd := d;
   If d1 > maxd Then maxd := d1;
   If g.ins[cur].lbl >= 0 Then Begin
    dj := d + StackEffect(op, g.ins[cur].arg, True);
    If dj > maxd Then maxd := dj;
    t := g.labels[g.ins[cur].lbl];
    If t < 0 Then t := n;
    If nw >= Length(work) Then Begin
     SetLength(work, nw * 2);
     SetLength(wdepth, nw * 2);
    End;
    work[nw] := t;
    wdepth[nw] := dj;
    Inc(nw);
   End;
   If op In [JUMP_ABSOLUTE, JUMP_FORWARD, RETURN_VALUE, RAISE_VARARGS]
    Then Break;
   d := d1;
   Inc(cur);
  End;
 End;
 code := TPyCode.Create(tyCode);
 code.co := co;
 code.stacksize := maxd + 2;
 SetLength(code.consts, g.nconsts);
 For i := 0 To g.nconsts - 1 Do code.consts[i] := g.consts[i];
 SetLength(code.names, Length(g.names));
 SetLength(code.nameObjs, Length(g.names));
 For i := 0 To High(g.names) Do Begin
  code.names[i] := g.names[i];
  code.nameObjs[i] := InternStr(g.names[i]);
 End;
 code.varnames := sc.varnames;
 code.cellvars := sc.cellvars;
 code.freevars := sc.freevars;
 code.nlocals := Length(sc.varnames);
 code.filename := g.fname;
 code.name := g.name;
 code.firstline := g.firstline;
 code.lnotab := lnotab;
 code.source := SrcLines;
 code.posonly := g.posonly;
 fl := 0;
 If sc.IsFunc Then Begin
  fl := CO_OPTIMIZED Or CO_NEWLOCALS;
  code.argcount := sc.nparams;
  code.kwonly := sc.nkwonly;
  If sc.hasVarArgs Then fl := fl Or CO_VARARGS;
  If sc.hasKwArgs Then fl := fl Or CO_VARKEYWORDS;
  If sc.isGen Then fl := fl Or CO_GENERATOR;
  If (sc.parent <> Nil) And (sc.parent.kind <> scModule) Then
   fl := fl Or CO_NESTED;
 End;
 If (Length(sc.freevars) = 0) And (Length(sc.cellvars) = 0) Then
  fl := fl Or CO_NOFREE;
 code.flags := fl;
 Result := code;
End;

{ ------------------------------------------------------------
  Expressions
  ------------------------------------------------------------ }
Procedure CgFuncDefaults(g: TGen; args: TNode; Var flags: Integer);
Var
 j, cnt: Integer;
 names: TPyTuple;
Begin
 cnt := 0;
 For j := 0 To High(args.l1) Do
  If args.l1[j].a <> Nil Then Inc(cnt);
 If cnt > 0 Then Begin
  For j := 0 To High(args.l1) Do
   If args.l1[j].a <> Nil Then CgExpr(g, args.l1[j].a);
  Emit(g, BUILD_TUPLE, cnt);
  flags := flags Or 1;
 End;
 cnt := 0;
 For j := 0 To High(args.l2) Do
  If args.l2[j].a <> Nil Then Inc(cnt);
 If cnt > 0 Then Begin
  names := NewTuple(cnt);
  cnt := 0;
  For j := 0 To High(args.l2) Do
   If args.l2[j].a <> Nil Then Begin
    CgExpr(g, args.l2[j].a);
    names.items[cnt] := VStr(args.l2[j].s);
    Inc(cnt);
   End;
  EmitConst(g, VObj(names));
  Emit(g, BUILD_CONST_KEY_MAP, cnt);
  flags := flags Or 2;
 End;
End;

Procedure CgMakeFunction(g: TGen; nd: TNode; args: TNode; Const nm: AnsiString);
Var
 flags: Integer;
 cs: TScope;
 code: TPyCode;
 qual: AnsiString;
Begin
 flags := 0;
 cs := ScopeOf(nd);
 CgFuncDefaults(g, args, flags);
 qual := ChildQual(g, nm);
 code := CgFunction(g, nd, cs, nm, qual);
 CgClosureTuple(g, cs, flags);
 EmitConst(g, VObj(code));
 EmitConst(g, VStr(qual));
 Emit(g, MAKE_FUNCTION, flags);
End;

Procedure CgComprehension(g: TGen; nd: TNode);
Var
 cs: TScope;
 c: TGen;
 code: TPyCode;
 flags: Integer;
 nm: AnsiString;

 Procedure Loops(idx: Integer);
 Var
  gen: TNode;
  ltop, lend, j: Integer;
 Begin
  gen := nd.l1[idx];
  ltop := NewLabel(c);
  lend := NewLabel(c);
  If idx = 0 Then Emit(c, LOAD_FAST, 0)
  Else Begin
   c.curLine := gen.line;
   CgExpr(c, gen.b);
   Emit(c, GET_ITER);
  End;
  SetLabel(c, ltop);
  EmitJ(c, FOR_ITER, lend);
  CgStore(c, gen.a);
  For j := 0 To High(gen.l1) Do CgJumpIf(c, gen.l1[j], ltop, False);
  If idx + 1 < Length(nd.l1) Then Loops(idx + 1)
  Else Begin
   Case nd.k Of
    nListComp: Begin
      CgExpr(c, nd.a);
      Emit(c, LIST_APPEND, idx + 2);
     End;
    nSetComp: Begin
      CgExpr(c, nd.a);
      Emit(c, SET_ADD, idx + 2);
     End;
    nDictComp: Begin
      CgExpr(c, nd.a);
      CgExpr(c, nd.b);
      Emit(c, MAP_ADD, idx + 2);
     End;
   Else
    CgExpr(c, nd.a);
    Emit(c, YIELD_VALUE);
    Emit(c, POP_TOP);
   End;
  End;
  EmitJ(c, JUMP_ABSOLUTE, ltop);
  SetLabel(c, lend);
 End;

Begin
 cs := ScopeOf(nd);
 Case nd.k Of
  nListComp: nm := '<listcomp>';
  nSetComp: nm := '<setcomp>';
  nDictComp: nm := '<dictcomp>';
 Else nm := '<genexpr>';
 End;
 c := TGen.Create;
 c.sc := cs;
 c.fname := g.fname;
 c.name := nm;
 c.qual := ChildQual(g, nm);
 c.firstline := nd.line;
 c.curLine := nd.line;
 c.clsName := g.clsName;
 c.parent := g;
 AddConst(c, vNone);
 Case nd.k Of
  nListComp: Emit(c, BUILD_LIST, 0);
  nSetComp: Emit(c, BUILD_SET, 0);
  nDictComp: Emit(c, BUILD_MAP, 0);
 End;
 Loops(0);
 If nd.k = nGenExp Then EmitConst(c, vNone);
 Emit(c, RETURN_VALUE);
 code := Assemble(c);
 flags := 0;
 CgClosureTuple(g, cs, flags);
 EmitConst(g, VObj(code));
 EmitConst(g, VStr(c.qual));
 Emit(g, MAKE_FUNCTION, flags);
 g.curLine := nd.line;
 CgExpr(g, nd.l1[0].b);
 Emit(g, GET_ITER);
 Emit(g, CALL_FUNCTION, 1);
End;

Procedure CgDict(g: TGen; nd: TNode);
Var
 j, nrun, nparts, n: Integer;
 hasStar, allConst: Boolean;
 v: TVal;
 keys: TPyTuple;

 Procedure FlushRun;
 Begin
  If nrun > 0 Then Begin
   Emit(g, BUILD_MAP, nrun);
   Inc(nparts);
   nrun := 0;
  End;
 End;

Begin
 n := Length(nd.l1);
 hasStar := False;
 allConst := n > 0;
 For j := 0 To n - 1 Do Begin
  If nd.l1[j] = Nil Then hasStar := True
  Else If Not IsConstNode(nd.l1[j], v) Then allConst := False;
 End;
 If Not hasStar Then Begin
  If allConst And (n > 1) And (n < 200) Then Begin
   keys := NewTuple(n);
   For j := 0 To n - 1 Do Begin
    CgExpr(g, nd.l2[j]);
    IsConstNode(nd.l1[j], v);
    keys.items[j] := v;
   End;
   EmitConst(g, VObj(keys));
   Emit(g, BUILD_CONST_KEY_MAP, n);
   Exit;
  End;
  For j := 0 To n - 1 Do Begin
   CgExpr(g, nd.l1[j]);
   CgExpr(g, nd.l2[j]);
  End;
  Emit(g, BUILD_MAP, n);
  Exit;
 End;
 nparts := 0;
 nrun := 0;
 For j := 0 To n - 1 Do Begin
  If nd.l1[j] = Nil Then Begin
   FlushRun;
   CgExpr(g, nd.l2[j]);
   Inc(nparts);
  End
  Else Begin
   CgExpr(g, nd.l1[j]);
   CgExpr(g, nd.l2[j]);
   Inc(nrun);
  End;
 End;
 FlushRun;
 Emit(g, BUILD_MAP_UNPACK, nparts);
End;

Procedure CgFString(g: TGen; nd: TNode);
Var
 j, n: Integer;
 p: TNode;
 fl: Integer;
Begin
 n := Length(nd.l1);
 If n = 0 Then Begin
  EmitConst(g, VStr(''));
  Exit;
 End;
 For j := 0 To n - 1 Do Begin
  p := nd.l1[j];
  If p.k = nStr Then EmitConst(g, VStr(p.s))
  Else Begin
   CgExpr(g, p.a);
   fl := p.n;
   If p.b <> Nil Then Begin
    CgFString(g, p.b);
    fl := fl Or 4;
   End;
   g.curLine := p.line;
   Emit(g, FORMAT_VALUE, fl);
  End;
 End;
 If n > 1 Then Emit(g, BUILD_STRING, n);
End;

Procedure CgExpr(g: TGen; nd: TNode);
Var
 v: TVal;
 j, lend, lcl, lelse: Integer;
 op: Integer;
Begin
 If nd.line > 0 Then g.curLine := nd.line;
 Case nd.k Of
  nNum, nConst, nStr: Begin
    IsConstNode(nd, v);
    EmitConst(g, v);
   End;
  nName: Begin
    If nd.s = '__debug__' Then EmitConst(g, VBool(OptLevel = 0))
    Else CgName(g, nd.s, 0);
   End;
  nBin: Begin
    CgExpr(g, nd.a);
    CgExpr(g, nd.b);
    g.curLine := nd.line;
    Emit(g, BinOpCode(nd.s, False));
   End;
  nUnary: Begin
    If (nd.s = '-') And IsConstNode(nd, v) Then EmitConst(g, v)
    Else Begin
     CgExpr(g, nd.a);
     g.curLine := nd.line;
     If nd.s = '-' Then Emit(g, UNARY_NEGATIVE)
     Else If nd.s = '+' Then Emit(g, UNARY_POSITIVE)
     Else If nd.s = '~' Then Emit(g, UNARY_INVERT)
     Else Emit(g, UNARY_NOT);
    End;
   End;
  nBool: Begin
    lend := NewLabel(g);
    If nd.s = 'and' Then op := JUMP_IF_FALSE_OR_POP
    Else op := JUMP_IF_TRUE_OR_POP;
    For j := 0 To High(nd.l1) Do Begin
     CgExpr(g, nd.l1[j]);
     If j < High(nd.l1) Then EmitJ(g, op, lend);
    End;
    SetLabel(g, lend);
   End;
  nCmp: Begin
    CgExpr(g, nd.a);
    If Length(nd.l1) = 1 Then Begin
     CgExpr(g, nd.l1[0]);
     g.curLine := nd.line;
     Emit(g, COMPARE_OP, CmpOpCode(nd.sl[0]));
    End
    Else Begin
     lcl := NewLabel(g);
     lend := NewLabel(g);
     For j := 0 To High(nd.l1) Do Begin
      CgExpr(g, nd.l1[j]);
      g.curLine := nd.line;
      If j < High(nd.l1) Then Begin
       Emit(g, DUP_TOP);
       Emit(g, ROT_THREE);
       Emit(g, COMPARE_OP, CmpOpCode(nd.sl[j]));
       EmitJ(g, JUMP_IF_FALSE_OR_POP, lcl);
      End
      Else Emit(g, COMPARE_OP, CmpOpCode(nd.sl[j]));
     End;
     EmitJ(g, JUMP_FORWARD, lend);
     SetLabel(g, lcl);
     Emit(g, ROT_TWO);
     Emit(g, POP_TOP);
     SetLabel(g, lend);
    End;
   End;
  nCall: CgCall(g, nd);
  nAttr: Begin
    CgExpr(g, nd.a);
    g.curLine := nd.line;
    Emit(g, LOAD_ATTR, AddName(g, Mangle(g, nd.s)));
   End;
  nSub: Begin
    CgExpr(g, nd.a);
    CgExpr(g, nd.b);
    g.curLine := nd.line;
    Emit(g, BINARY_SUBSCR);
   End;
  nSlice: CgSlice(g, nd);
  nTuple: Begin
    If IsConstNode(nd, v) Then EmitConst(g, v)
    Else CgSequence(g, nd, BUILD_TUPLE, BUILD_TUPLE_UNPACK);
   End;
  nList: CgSequence(g, nd, BUILD_LIST, BUILD_LIST_UNPACK);
  nSet: CgSequence(g, nd, BUILD_SET, BUILD_SET_UNPACK);
  nDict: CgDict(g, nd);
  nListComp, nSetComp, nDictComp, nGenExp: CgComprehension(g, nd);
  nLambda: CgMakeFunction(g, nd, nd.b, '<lambda>');
  nIfExp: Begin
    lelse := NewLabel(g);
    lend := NewLabel(g);
    CgJumpIf(g, nd.a, lelse, False);
    CgExpr(g, nd.b);
    EmitJ(g, JUMP_FORWARD, lend);
    SetLabel(g, lelse);
    CgExpr(g, nd.c);
    SetLabel(g, lend);
   End;
  nYield: Begin
    If nd.a <> Nil Then CgExpr(g, nd.a) Else EmitConst(g, vNone);
    g.curLine := nd.line;
    Emit(g, YIELD_VALUE);
   End;
  nYieldFrom: Begin
    CgExpr(g, nd.a);
    Emit(g, GET_YIELD_FROM_ITER);
    EmitConst(g, vNone);
    Emit(g, YIELD_FROM);
   End;
  nNamed: Begin
    CgExpr(g, nd.b);
    Emit(g, DUP_TOP);
    CgName(g, nd.a.s, 1);
   End;
  nJoined: CgFString(g, nd);
  nFmt: Begin
    CgExpr(g, nd.a);
    Emit(g, FORMAT_VALUE, nd.n);
   End;
  nStarred: SynErr('can''t use starred expression here', nd.line, nd.col);
 Else
  SynErr('invalid syntax', nd.line, nd.col);
 End;
End;

Procedure CgJumpIf(g: TGen; nd: TNode; lbl: Integer; sense: Boolean);
Var
 j, skip: Integer;
Begin
 If (nd.k = nUnary) And (nd.s = 'not') Then Begin
  CgJumpIf(g, nd.a, lbl, Not sense);
  Exit;
 End;
 If (nd.k = nBool) And ((nd.s = 'and') = Not sense) Then Begin
  { and avec jump-si-faux, ou or avec jump-si-vrai : chaque operande saute }
  For j := 0 To High(nd.l1) Do CgJumpIf(g, nd.l1[j], lbl, sense);
  Exit;
 End;
 If nd.k = nBool Then Begin
  skip := NewLabel(g);
  For j := 0 To High(nd.l1) - 1 Do CgJumpIf(g, nd.l1[j], skip, Not sense);
  CgJumpIf(g, nd.l1[High(nd.l1)], lbl, sense);
  SetLabel(g, skip);
  Exit;
 End;
 CgExpr(g, nd);
 If sense Then EmitJ(g, POP_JUMP_IF_TRUE, lbl)
 Else EmitJ(g, POP_JUMP_IF_FALSE, lbl);
End;

Procedure CgStore(g: TGen; nd: TNode);
Var
 j, nstar, before, after: Integer;
Begin
 Case nd.k Of
  nName: CgName(g, nd.s, 1);
  nAttr: Begin
    CgExpr(g, nd.a);
    g.curLine := nd.line;
    Emit(g, STORE_ATTR, AddName(g, Mangle(g, nd.s)));
   End;
  nSub: Begin
    CgExpr(g, nd.a);
    CgExpr(g, nd.b);
    g.curLine := nd.line;
    Emit(g, STORE_SUBSCR);
   End;
  nTuple, nList: Begin
    nstar := -1;
    For j := 0 To High(nd.l1) Do
     If nd.l1[j].k = nStarred Then Begin
      If nstar >= 0 Then
       SynErr('two starred expressions in assignment', nd.line, nd.col);
      nstar := j;
     End;
    If nstar < 0 Then Emit(g, UNPACK_SEQUENCE, Length(nd.l1))
    Else Begin
     before := nstar;
     after := Length(nd.l1) - nstar - 1;
     Emit(g, UNPACK_EX, before Or (after Shl 8));
    End;
    For j := 0 To High(nd.l1) Do Begin
     If nd.l1[j].k = nStarred Then CgStore(g, nd.l1[j].a)
     Else CgStore(g, nd.l1[j]);
    End;
   End;
 Else
  SynErr('can''t assign to expression', nd.line, nd.col);
 End;
End;

Procedure CgDelete(g: TGen; nd: TNode);
Var
 j: Integer;
Begin
 Case nd.k Of
  nName: CgName(g, nd.s, 2);
  nAttr: Begin
    CgExpr(g, nd.a);
    Emit(g, DELETE_ATTR, AddName(g, Mangle(g, nd.s)));
   End;
  nSub: Begin
    CgExpr(g, nd.a);
    CgExpr(g, nd.b);
    Emit(g, DELETE_SUBSCR);
   End;
  nTuple, nList: For j := 0 To High(nd.l1) Do CgDelete(g, nd.l1[j]);
 End;
End;

{ ------------------------------------------------------------
  Instructions
  ------------------------------------------------------------ }
Procedure UnwindFB(g: TGen; target: Integer; preserve: Boolean);
Var
 i: Integer;
Begin
 For i := g.nfb - 1 DownTo target Do
  Case g.fb[i].kind Of
   fbLoopFor: Begin
     If preserve Then Emit(g, ROT_TWO);
     Emit(g, POP_TOP);
    End;
   fbExcept: Emit(g, POP_BLOCK);
   fbFinallyTry: Begin
     Emit(g, POP_BLOCK);
     EmitJ(g, CALL_FINALLY, g.fb[i].lbl1);
    End;
   fbFinallyEnd: Begin
     If preserve Then Emit(g, POP_FINALLY, 1)
     Else Emit(g, POP_FINALLY, 0);
    End;
   fbWith: Begin
     Emit(g, POP_BLOCK);
     If preserve Then Emit(g, ROT_TWO);
     Emit(g, BEGIN_FINALLY);
     Emit(g, WITH_CLEANUP_START);
     Emit(g, WITH_CLEANUP_FINISH);
     Emit(g, POP_FINALLY, 0);
    End;
   fbHandler: Begin
     If preserve Then Emit(g, ROT_FOUR);
     Emit(g, POP_EXCEPT);
    End;
  End;
End;

Procedure CgStmt(g: TGen; nd: TNode); Forward;

Procedure CgBody(g: TGen; Const l: TNodes; skipDoc: Boolean);
Var
 j: Integer;
Begin
 For j := 0 To High(l) Do Begin
  If skipDoc And (j = 0) Then Continue;
  CgStmt(g, l[j]);
 End;
End;

Procedure CgTry(g: TGen; nd: TNode);
Var
 lfin, lhand, lelse, lend, lnext, lclean, j: Integer;
 h: TNode;

 Procedure ExceptPart;
 Var
  k: Integer;
 Begin
  lhand := NewLabel(g);
  lelse := NewLabel(g);
  lend := NewLabel(g);
  EmitJ(g, SETUP_FINALLY, lhand);
  PushFB(g, fbExcept, 0, 0);
  CgStmts(g, nd.l1);
  PopFB(g);
  Emit(g, POP_BLOCK);
  EmitJ(g, JUMP_FORWARD, lelse);
  SetLabel(g, lhand);
  For k := 0 To High(nd.l2) Do Begin
   h := nd.l2[k];
   g.curLine := h.line;
   lnext := NewLabel(g);
   If h.a <> Nil Then Begin
    Emit(g, DUP_TOP);
    CgExpr(g, h.a);
    Emit(g, COMPARE_OP, 10);
    EmitJ(g, POP_JUMP_IF_FALSE, lnext);
   End;
   Emit(g, POP_TOP);
   If h.s <> '' Then Begin
    CgName(g, h.s, 1);
    Emit(g, POP_TOP);
    lclean := NewLabel(g);
    EmitJ(g, SETUP_FINALLY, lclean);
    PushFB(g, fbHandler, 0, 0);
    PushFB(g, fbFinallyTry, lclean, 0);
    CgStmts(g, h.l1);
    PopFB(g);
    PopFB(g);
    Emit(g, POP_BLOCK);
    Emit(g, BEGIN_FINALLY);
    SetLabel(g, lclean);
    EmitConst(g, vNone);
    CgName(g, h.s, 1);
    CgName(g, h.s, 2);
    Emit(g, END_FINALLY);
   End
   Else Begin
    Emit(g, POP_TOP);
    Emit(g, POP_TOP);
    PushFB(g, fbHandler, 0, 0);
    CgStmts(g, h.l1);
    PopFB(g);
   End;
   Emit(g, POP_EXCEPT);
   EmitJ(g, JUMP_FORWARD, lend);
   SetLabel(g, lnext);
  End;
  Emit(g, END_FINALLY);
  SetLabel(g, lelse);
  CgStmts(g, nd.l3);
  SetLabel(g, lend);
 End;

Begin
 If nd.n = 1 Then Begin
  lfin := NewLabel(g);
  EmitJ(g, SETUP_FINALLY, lfin);
  PushFB(g, fbFinallyTry, lfin, 0);
  If Length(nd.l2) > 0 Then ExceptPart
  Else CgStmts(g, nd.l1);
  PopFB(g);
  Emit(g, POP_BLOCK);
  Emit(g, BEGIN_FINALLY);
  SetLabel(g, lfin);
  PushFB(g, fbFinallyEnd, 0, 0);
  CgStmts(g, nd.l4);
  PopFB(g);
  Emit(g, END_FINALLY);
 End
 Else ExceptPart;
 j := 0;
End;

Procedure CgWith(g: TGen; nd: TNode; idx: Integer);
Var
 it: TNode;
 lclean: Integer;
Begin
 it := nd.l1[idx];
 CgExpr(g, it.a);
 lclean := NewLabel(g);
 g.curLine := it.line;
 EmitJ(g, SETUP_WITH, lclean);
 If it.b <> Nil Then CgStore(g, it.b) Else Emit(g, POP_TOP);
 PushFB(g, fbWith, 0, 0);
 If idx + 1 < Length(nd.l1) Then CgWith(g, nd, idx + 1)
 Else CgStmts(g, nd.l2);
 PopFB(g);
 Emit(g, POP_BLOCK);
 Emit(g, BEGIN_FINALLY);
 SetLabel(g, lclean);
 Emit(g, WITH_CLEANUP_START);
 Emit(g, WITH_CLEANUP_FINISH);
 Emit(g, END_FINALLY);
End;

Function IsDocStmt(nd: TNode): Boolean;
Begin
 Result := (nd.k = nExprStmt) And (nd.a.k = nStr) And Not nd.a.flag;
End;

Procedure CgClassDef(g: TGen; nd: TNode);
Var
 cs: TScope;
 c: TGen;
 code: TPyCode;
 flags, j: Integer;
 qual: AnsiString;
 doc: Boolean;
Begin
 g.curLine := nd.line;
 cs := ScopeOf(nd);
 For j := 0 To High(nd.l3) Do CgExpr(g, nd.l3[j]);
 Emit(g, LOAD_BUILD_CLASS);
 qual := ChildQual(g, nd.s);
 c := TGen.Create;
 c.sc := cs;
 c.fname := g.fname;
 c.name := nd.s;
 c.qual := qual;
 c.firstline := nd.line;
 c.curLine := nd.line;
 c.clsName := nd.s;
 c.parent := g;
 AddConst(c, vNone);
 Emit(c, LOAD_NAME, AddName(c, '__name__'));
 Emit(c, STORE_NAME, AddName(c, '__module__'));
 EmitConst(c, VStr(qual));
 Emit(c, STORE_NAME, AddName(c, '__qualname__'));
 doc := (Length(nd.l2) > 0) And IsDocStmt(nd.l2[0]);
 If doc Then Begin
  EmitConst(c, VStr(nd.l2[0].a.s));
  Emit(c, STORE_NAME, AddName(c, '__doc__'));
 End;
 If cs.hasAnnot Then Emit(c, SETUP_ANNOTATIONS);
 CgBody(c, nd.l2, doc);
 If cs.needsClassCell Then Begin
  Emit(c, LOAD_CLOSURE, IndexOfStr(cs.cellvars, '__class__'));
  Emit(c, DUP_TOP);
  Emit(c, STORE_NAME, AddName(c, '__classcell__'));
 End
 Else EmitConst(c, vNone);
 Emit(c, RETURN_VALUE);
 code := Assemble(c);
 flags := 0;
 CgClosureTuple(g, cs, flags);
 EmitConst(g, VObj(code));
 EmitConst(g, VStr(nd.s));
 Emit(g, MAKE_FUNCTION, flags);
 EmitConst(g, VStr(nd.s));
 g.curLine := nd.line;
 CgCallTail(g, nd.l1, 2);
 For j := 0 To High(nd.l3) Do Emit(g, CALL_FUNCTION, 1);
 CgName(g, nd.s, 1);
End;

Procedure CgImport(g: TGen; nd: TNode);
Var
 j, p: Integer;
 al: TNode;
 nm, rest, part: AnsiString;
 names: TPyTuple;
Begin
 g.curLine := nd.line;
 If nd.k = nImport Then Begin
  For j := 0 To High(nd.l1) Do Begin
   al := nd.l1[j];
   EmitConst(g, VInt(0));
   EmitConst(g, vNone);
   Emit(g, IMPORT_NAME, AddName(g, al.s));
   If al.s2 <> '' Then Begin
    rest := al.s;
    p := Pos('.', rest);
    While p > 0 Do Begin
     rest := Copy(rest, p + 1, Length(rest));
     p := Pos('.', rest);
     If p > 0 Then part := Copy(rest, 1, p - 1) Else part := rest;
     Emit(g, LOAD_ATTR, AddName(g, part));
    End;
    CgName(g, al.s2, 1);
   End
   Else Begin
    p := Pos('.', al.s);
    If p > 0 Then nm := Copy(al.s, 1, p - 1) Else nm := al.s;
    CgName(g, nm, 1);
   End;
  End;
  Exit;
 End;
 EmitConst(g, VInt(nd.n));
 If nd.l1[0].s = '*' Then Begin
  EmitConst(g, vNone);
  Emit(g, IMPORT_NAME, AddName(g, nd.s));
  Emit(g, IMPORT_STAR);
  Exit;
 End;
 names := NewTuple(Length(nd.l1));
 For j := 0 To High(nd.l1) Do names.items[j] := VStr(nd.l1[j].s);
 EmitConst(g, VObj(names));
 Emit(g, IMPORT_NAME, AddName(g, nd.s));
 For j := 0 To High(nd.l1) Do Begin
  Emit(g, IMPORT_FROM, AddName(g, nd.l1[j].s));
  If nd.l1[j].s2 <> '' Then CgName(g, nd.l1[j].s2, 1)
  Else CgName(g, nd.l1[j].s, 1);
 End;
 Emit(g, POP_TOP);
End;

Procedure CgStmt(g: TGen; nd: TNode);
Var
 j, lelse, lend, ltop, i, op: Integer;
 decos: Integer;
 lp, found: Integer;
Begin
 If nd.line > 0 Then g.curLine := nd.line;
 Case nd.k Of
  nExprStmt: Begin
    CgExpr(g, nd.a);
    If g.interactive And (g.sc.kind = scModule) Then Emit(g, PRINT_EXPR)
    Else Emit(g, POP_TOP);
   End;
  nAssign: Begin
    CgExpr(g, nd.a);
    For j := 0 To High(nd.l1) Do Begin
     If j < High(nd.l1) Then Emit(g, DUP_TOP);
     CgStore(g, nd.l1[j]);
    End;
   End;
  nAugAssign: Begin
    op := BinOpCode(nd.s, True);
    Case nd.a.k Of
     nName: Begin
       CgName(g, nd.a.s, 0);
       CgExpr(g, nd.b);
       g.curLine := nd.line;
       Emit(g, op);
       CgName(g, nd.a.s, 1);
      End;
     nAttr: Begin
       CgExpr(g, nd.a.a);
       Emit(g, DUP_TOP);
       Emit(g, LOAD_ATTR, AddName(g, Mangle(g, nd.a.s)));
       CgExpr(g, nd.b);
       g.curLine := nd.line;
       Emit(g, op);
       Emit(g, ROT_TWO);
       Emit(g, STORE_ATTR, AddName(g, Mangle(g, nd.a.s)));
      End;
     nSub: Begin
       CgExpr(g, nd.a.a);
       CgExpr(g, nd.a.b);
       Emit(g, DUP_TOP_TWO);
       Emit(g, BINARY_SUBSCR);
       CgExpr(g, nd.b);
       g.curLine := nd.line;
       Emit(g, op);
       Emit(g, ROT_THREE);
       Emit(g, STORE_SUBSCR);
      End;
    End;
   End;
  nAnnAssign: Begin
    If nd.c <> Nil Then Begin
     CgExpr(g, nd.c);
     CgStore(g, nd.a);
    End;
    If g.sc.kind <> scFunction Then Begin
     CgExpr(g, nd.b);
     If nd.a.k = nName Then Begin
      CgName(g, '__annotations__', 0);
      EmitConst(g, VStr(Mangle(g, nd.a.s)));
      Emit(g, STORE_SUBSCR);
     End
     Else Emit(g, POP_TOP);
    End;
   End;
  nReturn: Begin
    If nd.a <> Nil Then CgExpr(g, nd.a) Else EmitConst(g, vNone);
    If g.nfb > 0 Then UnwindFB(g, 0, True);
    g.curLine := nd.line;
    Emit(g, RETURN_VALUE);
   End;
  nDelete: For j := 0 To High(nd.l1) Do CgDelete(g, nd.l1[j]);
  nPass: ;
  nBreak, nContinue: Begin
    found := -1;
    For i := g.nfb - 1 DownTo 0 Do
     If g.fb[i].kind In [fbLoopWhile, fbLoopFor] Then Begin
      found := i;
      Break;
     End;
    If found < 0 Then Begin
     If nd.k = nBreak Then
      SynErr('''break'' outside loop', nd.line, nd.col)
     Else SynErr('''continue'' not properly in loop', nd.line, nd.col);
    End;
    If nd.k = nBreak Then Begin
     UnwindFB(g, found, False);
     EmitJ(g, JUMP_ABSOLUTE, g.fb[found].lbl2);
    End
    Else Begin
     UnwindFB(g, found + 1, False);
     EmitJ(g, JUMP_ABSOLUTE, g.fb[found].lbl1);
    End;
   End;
  nRaise: Begin
    If nd.a = Nil Then Emit(g, RAISE_VARARGS, 0)
    Else Begin
     CgExpr(g, nd.a);
     If nd.b <> Nil Then Begin
      CgExpr(g, nd.b);
      g.curLine := nd.line;
      Emit(g, RAISE_VARARGS, 2);
     End
     Else Begin
      g.curLine := nd.line;
      Emit(g, RAISE_VARARGS, 1);
     End;
    End;
   End;
  nGlobal, nNonlocal: ;
  nImport, nImportFrom: CgImport(g, nd);
  nAssert: Begin
    If OptLevel = 0 Then Begin
     lend := NewLabel(g);
     CgJumpIf(g, nd.a, lend, True);
     CgName(g, 'AssertionError', 0);
     If nd.b <> Nil Then Begin
      CgExpr(g, nd.b);
      g.curLine := nd.line;
      Emit(g, CALL_FUNCTION, 1);
     End;
     g.curLine := nd.line;
     Emit(g, RAISE_VARARGS, 1);
     SetLabel(g, lend);
    End;
   End;
  nIf: Begin
    lelse := NewLabel(g);
    CgJumpIf(g, nd.a, lelse, False);
    CgStmts(g, nd.l1);
    If Length(nd.l2) > 0 Then Begin
     lend := NewLabel(g);
     EmitJ(g, JUMP_FORWARD, lend);
     SetLabel(g, lelse);
     CgStmts(g, nd.l2);
     SetLabel(g, lend);
    End
    Else SetLabel(g, lelse);
   End;
  nWhile: Begin
    ltop := NewLabel(g);
    lelse := NewLabel(g);
    lend := NewLabel(g);
    SetLabel(g, ltop);
    CgJumpIf(g, nd.a, lelse, False);
    PushFB(g, fbLoopWhile, ltop, lend);
    CgStmts(g, nd.l1);
    PopFB(g);
    g.curLine := nd.line;
    EmitJ(g, JUMP_ABSOLUTE, ltop);
    SetLabel(g, lelse);
    CgStmts(g, nd.l2);
    SetLabel(g, lend);
   End;
  nFor: Begin
    ltop := NewLabel(g);
    lelse := NewLabel(g);
    lend := NewLabel(g);
    CgExpr(g, nd.b);
    Emit(g, GET_ITER);
    SetLabel(g, ltop);
    g.curLine := nd.line;
    EmitJ(g, FOR_ITER, lelse);
    CgStore(g, nd.a);
    PushFB(g, fbLoopFor, ltop, lend);
    CgStmts(g, nd.l1);
    PopFB(g);
    EmitJ(g, JUMP_ABSOLUTE, ltop);
    SetLabel(g, lelse);
    CgStmts(g, nd.l2);
    SetLabel(g, lend);
   End;
  nTry: CgTry(g, nd);
  nWith: CgWith(g, nd, 0);
  nFuncDef: Begin
    For j := 0 To High(nd.l2) Do CgExpr(g, nd.l2[j]);
    CgMakeFunction(g, nd, nd.a, nd.s);
    g.curLine := nd.line;
    For j := 0 To High(nd.l2) Do Emit(g, CALL_FUNCTION, 1);
    CgName(g, nd.s, 1);
   End;
  nClassDef: CgClassDef(g, nd);
 End;
 decos := 0;
 lp := 0;
 If decos + lp = 99 Then Exit;
End;

Procedure CgStmts(g: TGen; Const l: TNodes);
Var
 j: Integer;
Begin
 For j := 0 To High(l) Do CgStmt(g, l[j]);
End;

Function CgFunction(g: TGen; nd: TNode; sc: TScope; Const nm: AnsiString;
 Const qual: AnsiString): TPyCode;
Var
 c: TGen;
 args: TNode;
 doc: Boolean;
Begin
 c := TGen.Create;
 c.sc := sc;
 c.fname := g.fname;
 c.name := nm;
 c.qual := qual;
 c.firstline := nd.line;
 c.curLine := nd.line;
 c.clsName := g.clsName;
 c.parent := g;
 If nd.k = nLambda Then args := nd.b Else args := nd.a;
 c.posonly := args.n;
 doc := (nd.k = nFuncDef) And (Length(nd.l1) > 0) And IsDocStmt(nd.l1[0]) And
  (OptLevel < 2);
 If doc Then AddConst(c, VStr(nd.l1[0].a.s))
 Else AddConst(c, vNone);
 If nd.k = nLambda Then Begin
  CgExpr(c, nd.a);
  Emit(c, RETURN_VALUE);
 End
 Else Begin
  CgBody(c, nd.l1, IsDocStmt(nd.l1[0]) And (Length(nd.l1) > 0));
  EmitConst(c, vNone);
  Emit(c, RETURN_VALUE);
 End;
 Result := Assemble(c);
End;

{ mode : 0 exec, 1 eval, 2 single }
Function CompileSource(Const src: AnsiString; Const fname: AnsiString;
 mode: Integer): TPyCode;
Var
 root: TNode;
 sc: TScope;
 bound: TNameSet;
 g: TGen;
 doc: Boolean;
Begin
 SrcFile := fname;
 root := ParseSource(src, mode);
 sc := NewScope(scModule, '<module>', root, Nil);
 If mode = 1 Then SymExpr(sc, root.a) Else SymStmts(sc, root.l1);
 sc.hasAnnot := HasAnnotations(root.l1);
 bound := NewNameSet;
 AnalyzeScope(sc, bound);
 g := TGen.Create;
 g.sc := sc;
 g.fname := fname;
 g.name := '<module>';
 g.qual := '';
 g.firstline := 1;
 g.curLine := 1;
 g.interactive := mode = 2;
 g.clsName := '';
 AddConst(g, vNone);
 If mode = 1 Then Begin
  CgExpr(g, root.a);
  Emit(g, RETURN_VALUE);
 End
 Else Begin
  doc := (Length(root.l1) > 0) And IsDocStmt(root.l1[0]) And
   (mode = 0) And (OptLevel < 2);
  If sc.hasAnnot Then Emit(g, SETUP_ANNOTATIONS);
  If doc Then Begin
   g.curLine := root.l1[0].line;
   EmitConst(g, VStr(root.l1[0].a.s));
   Emit(g, STORE_NAME, AddName(g, '__doc__'));
  End;
  CgBody(g, root.l1, doc);
  EmitConst(g, vNone);
  Emit(g, RETURN_VALUE);
 End;
 Result := Assemble(g);
End;

{ ------------------------------------------------------------
  Chaines internes, hachage
  ------------------------------------------------------------ }
Function HashBytes(Const s: AnsiString): Int64;
Var
 h: QWord;
 i: Integer;
Begin
 h := QWord($CBF29CE484222325);
 For i := 1 To Length(s) Do Begin
  h := h Xor Ord(s[i]);
  h := h * QWord($100000001B3);
 End;
 If Int64(h) = -1 Then h := 2;
 Result := Int64(h);
End;

Function StrHash(o: TPyStr): Int64; Inline;
Begin
 If Not o.hashed Then Begin
  o.h := HashBytes(o.s);
  o.hashed := True;
 End;
 Result := o.h;
End;

Function VStr(Const s: AnsiString): TVal;
Begin
 Result.k := vkObj;
 Result.o := TPyStr.Make(s);
End;

Function VBytes(Const s: AnsiString): TVal;
Begin
 Result.k := vkObj;
 Result.o := TPyBytes.Make(s);
End;

Function NewList: TPyList;
Begin
 Result := TPyList.Make;
End;

Function NewTuple(n: Integer): TPyTuple;
Begin
 Result := TPyTuple.Make(n);
End;

Function SameKey(Const a, b: TVal): Boolean; Inline;
Begin
 If a.k = b.k Then Begin
  If a.k = vkObj Then Begin
   If a.o = b.o Then Begin
    Result := True;
    Exit;
   End;
   If (a.o Is TPyStr) And (b.o Is TPyStr) Then Begin
    Result := TPyStr(a.o).s = TPyStr(b.o).s;
    Exit;
   End;
  End
  Else If a.k <> vkFloat Then Begin
   Result := a.i = b.i;
   Exit;
  End
  Else If PQWord(@a.d)^ = PQWord(@b.d)^ Then Begin
   Result := True;
   Exit;
  End;
 End;
 Result := ValEq(a, b);
End;

Function InternStr(Const s: AnsiString): TPyStr;
Var
 h: Int64;
 ix: Integer;
 v: TVal;
Begin
 h := HashBytes(s);
 ix := InternTab.FindS(s, h);
 If ix >= 0 Then Begin
  Result := TPyStr(InternTab.ent[ix].key.o);
  Exit;
 End;
 Result := TPyStr.Make(s);
 Result.h := h;
 Result.hashed := True;
 v := VObj(Result);
 InternTab.SetItem(v, vNone);
End;

{ ------------------------------------------------------------
  Dictionnaire ordonne
  ------------------------------------------------------------ }
Constructor TPyDict.Make;
Begin
 Inherited Create(tyDict);
 nent := 0;
 used := 0;
 mask := -1;
End;

Function TPyDict.FindIdx(Const key: TVal; h: Int64): Integer;
Var
 i: Integer;
 perturb: QWord;
 ix: LongInt;
Begin
 Result := -1;
 If mask < 0 Then Exit;
 i := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 Repeat
  ix := idx[i];
  If ix = -1 Then Exit;
  If ix >= 0 Then
   If ent[ix].h = h Then
    If SameKey(ent[ix].key, key) Then Begin
     Result := ix;
     Exit;
    End;
  perturb := perturb Shr 5;
  i := Integer((QWord(i) * 5 + perturb + 1) And QWord(mask));
 Until False;
End;

Function TPyDict.GetItem(Const key: TVal; Var v: TVal): Boolean;
Var
 ix: Integer;
Begin
 If mask < 0 Then Begin
  Result := False;
  Exit;
 End;
 ix := FindIdx(key, HashVal(key));
 Result := ix >= 0;
 If Result Then v := ent[ix].val;
End;

Procedure TPyDict.Rebuild(newcap: Integer);
Var
 ne: Array Of TDEntry;
 i, j, isz: Integer;
 p: Integer;
 perturb: QWord;
Begin
 If newcap < 8 Then newcap := 8;
 SetLength(ne, newcap);
 j := 0;
 For i := 0 To nent - 1 Do
  If ent[i].key.k <> vkNull Then Begin
   ne[j] := ent[i];
   Inc(j);
  End;
 ent := ne;
 nent := j;
 isz := 8;
 While isz < newcap * 2 Do isz := isz * 2;
 SetLength(idx, isz);
 For i := 0 To isz - 1 Do idx[i] := -1;
 mask := isz - 1;
 For i := 0 To nent - 1 Do Begin
  p := Integer(QWord(ent[i].h) And QWord(mask));
  perturb := QWord(ent[i].h);
  While idx[p] <> -1 Do Begin
   perturb := perturb Shr 5;
   p := Integer((QWord(p) * 5 + perturb + 1) And QWord(mask));
  End;
  idx[p] := i;
 End;
End;

Procedure TPyDict.SetItem(Const key, v: TVal);
Var
 h: Int64;
 ix, p: Integer;
 perturb: QWord;
Begin
 h := HashVal(key);
 If mask >= 0 Then Begin
  ix := FindIdx(key, h);
  If ix >= 0 Then Begin
   ent[ix].val := v;
   Exit;
  End;
 End;
 If (mask < 0) Or (nent >= Length(ent)) Then Begin
  If used * 2 > Length(ent) Then Rebuild(used * 2 + 8)
  Else Rebuild(Length(ent));
 End;
 p := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 While idx[p] >= 0 Do Begin
  perturb := perturb Shr 5;
  p := Integer((QWord(p) * 5 + perturb + 1) And QWord(mask));
 End;
 idx[p] := nent;
 ent[nent].key := key;
 ent[nent].val := v;
 ent[nent].h := h;
 Inc(nent);
 Inc(used);
End;

Function TPyDict.DelItem(Const key: TVal): Boolean;
Var
 h: Int64;
 ix, p: Integer;
 perturb: QWord;
Begin
 Result := False;
 If mask < 0 Then Exit;
 h := HashVal(key);
 ix := FindIdx(key, h);
 If ix < 0 Then Exit;
 p := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 While idx[p] <> ix Do Begin
  perturb := perturb Shr 5;
  p := Integer((QWord(p) * 5 + perturb + 1) And QWord(mask));
 End;
 idx[p] := -2;
 ent[ix].key.k := vkNull;
 ent[ix].val.k := vkNull;
 Dec(used);
 Result := True;
End;

Function TPyDict.GetS(Const name: AnsiString; Var v: TVal): Boolean;
Var
 ix: Integer;
Begin
 If mask < 0 Then Begin
  Result := False;
  Exit;
 End;
 ix := FindS(name, HashBytes(name));
 Result := ix >= 0;
 If Result Then v := ent[ix].val;
End;

Function TPyDict.FindS(Const s: AnsiString; h: Int64): Integer;
Var
 i: Integer;
 perturb: QWord;
 ix: LongInt;
Begin
 Result := -1;
 If mask < 0 Then Exit;
 i := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 Repeat
  ix := idx[i];
  If ix = -1 Then Exit;
  If ix >= 0 Then
   If ent[ix].h = h Then
    If (ent[ix].key.k = vkObj) And (ent[ix].key.o Is TPyStr) Then
     If TPyStr(ent[ix].key.o).s = s Then Begin
      Result := ix;
      Exit;
     End;
  perturb := perturb Shr 5;
  i := Integer((QWord(i) * 5 + perturb + 1) And QWord(mask));
 Until False;
End;

Procedure TPyDict.SetS(Const name: AnsiString; Const v: TVal);
Var
 ix: Integer;
 k: TVal;
Begin
 ix := FindS(name, HashBytes(name));
 If ix >= 0 Then Begin
  ent[ix].val := v;
  Exit;
 End;
 k := VObj(InternStr(name));
 SetItem(k, v);
End;

Function TPyDict.HasS(Const name: AnsiString): Boolean;
Begin
 Result := FindS(name, HashBytes(name)) >= 0;
End;

Function TPyDict.DelS(Const name: AnsiString): Boolean;
Var
 k: TVal;
Begin
 If FindS(name, HashBytes(name)) < 0 Then Begin
  Result := False;
  Exit;
 End;
 k := VObj(InternStr(name));
 Result := DelItem(k);
End;

Procedure TPyDict.Clear;
Begin
 SetLength(ent, 0);
 SetLength(idx, 0);
 nent := 0;
 used := 0;
 mask := -1;
End;

Function TPyDict.Copy: TPyDict;
Var
 i: Integer;
Begin
 Result := TPyDict.Make;
 For i := 0 To nent - 1 Do
  If ent[i].key.k <> vkNull Then Result.SetItem(ent[i].key, ent[i].val);
End;

Procedure TPyDict.MarkKids;
Var
 i: Integer;
Begin
 Inherited MarkKids;
 For i := 0 To nent - 1 Do
  If ent[i].key.k <> vkNull Then Begin
   MarkVal(ent[i].key);
   MarkVal(ent[i].val);
  End;
End;

{ ------------------------------------------------------------
  Ensemble (meme algorithme de sondage que CPython)
  ------------------------------------------------------------ }
Constructor TPySet.Make(fz: Boolean);
Begin
 If fz Then Inherited Create(tyFrozenset) Else Inherited Create(tySet);
 frozen := fz;
 fill := 0;
 used := 0;
 mask := 7;
 SetLength(tab, 8);
 FillChar(tab[0], 8 * SizeOf(TSetEntry), 0);
End;

Function TPySet.FindEntry(Const key: TVal; h: Int64): Integer;
Var
 i, j: Integer;
 perturb: QWord;
Begin
 i := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 Repeat
  If tab[i].key.k = vkNull Then Begin
   Result := -1;
   Exit;
  End;
  If (tab[i].h = h) And (tab[i].key.k <> vkDummy) Then
   If SameKey(tab[i].key, key) Then Begin
    Result := i;
    Exit;
   End;
  If i + 9 <= mask Then
   For j := 1 To 9 Do Begin
    If tab[i + j].key.k = vkNull Then Begin
     Result := -1;
     Exit;
    End;
    If (tab[i + j].h = h) And (tab[i + j].key.k <> vkDummy) Then
     If SameKey(tab[i + j].key, key) Then Begin
      Result := i + j;
      Exit;
     End;
   End;
  perturb := perturb Shr 5;
  i := Integer((QWord(i) * 5 + 1 + perturb) And QWord(mask));
 Until False;
End;

Function TPySet.Contains(Const key: TVal): Boolean;
Begin
 Result := FindEntry(key, HashVal(key)) >= 0;
End;

Procedure TPySet.InsertClean(Const key: TVal; h: Int64);
Var
 i, j: Integer;
 perturb: QWord;
Begin
 i := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 Repeat
  If tab[i].key.k = vkNull Then Begin
   tab[i].key := key;
   tab[i].h := h;
   Exit;
  End;
  If i + 9 <= mask Then
   For j := 1 To 9 Do
    If tab[i + j].key.k = vkNull Then Begin
     tab[i + j].key := key;
     tab[i + j].h := h;
     Exit;
    End;
  perturb := perturb Shr 5;
  i := Integer((QWord(i) * 5 + 1 + perturb) And QWord(mask));
 Until False;
End;

Procedure TPySet.Resize(minused: Integer);
Var
 old: Array Of TSetEntry;
 newsize, i: Integer;
Begin
 newsize := 8;
 While newsize <= minused Do newsize := newsize Shl 1;
 old := tab;
 SetLength(tab, newsize);
 FillChar(tab[0], newsize * SizeOf(TSetEntry), 0);
 mask := newsize - 1;
 For i := 0 To High(old) Do
  If (old[i].key.k <> vkNull) And (old[i].key.k <> vkDummy) Then
   InsertClean(old[i].key, old[i].h);
 fill := used;
End;

Function TPySet.Add(Const key: TVal): Boolean;
Var
 h: Int64;
 i, j, freeslot: Integer;
 perturb: QWord;

 Function Place(slot: Integer): Boolean;
 Begin
  tab[slot].key := key;
  tab[slot].h := h;
  Inc(used);
  Result := True;
 End;

Begin
 h := HashVal(key);
 i := Integer(QWord(h) And QWord(mask));
 perturb := QWord(h);
 freeslot := -1;
 Repeat
  If tab[i].key.k = vkNull Then Begin
   If freeslot >= 0 Then Begin
    Result := Place(freeslot);
    Exit;
   End;
   Inc(fill);
   Result := Place(i);
   If fill * 5 >= mask * 3 Then Begin
    If used > 50000 Then Resize(used * 2) Else Resize(used * 4);
   End;
   Exit;
  End;
  If tab[i].key.k = vkDummy Then Begin
   If freeslot < 0 Then freeslot := i;
  End
  Else If tab[i].h = h Then
   If SameKey(tab[i].key, key) Then Begin
    Result := False;
    Exit;
   End;
  If i + 9 <= mask Then
   For j := 1 To 9 Do Begin
    If tab[i + j].key.k = vkNull Then Begin
     If freeslot >= 0 Then Begin
      Result := Place(freeslot);
      Exit;
     End;
     Inc(fill);
     Result := Place(i + j);
     If fill * 5 >= mask * 3 Then Begin
      If used > 50000 Then Resize(used * 2) Else Resize(used * 4);
     End;
     Exit;
    End;
    If tab[i + j].key.k = vkDummy Then Begin
     If freeslot < 0 Then freeslot := i + j;
    End
    Else If tab[i + j].h = h Then
     If SameKey(tab[i + j].key, key) Then Begin
      Result := False;
      Exit;
     End;
   End;
  perturb := perturb Shr 5;
  i := Integer((QWord(i) * 5 + 1 + perturb) And QWord(mask));
 Until False;
End;

Function TPySet.Discard(Const key: TVal): Boolean;
Var
 ix: Integer;
Begin
 ix := FindEntry(key, HashVal(key));
 If ix < 0 Then Begin
  Result := False;
  Exit;
 End;
 tab[ix].key.k := vkDummy;
 tab[ix].h := -1;
 Dec(used);
 Result := True;
End;

Procedure TPySet.Clear;
Begin
 SetLength(tab, 8);
 FillChar(tab[0], 8 * SizeOf(TSetEntry), 0);
 mask := 7;
 fill := 0;
 used := 0;
End;

Procedure TPySet.MarkKids;
Var
 i: Integer;
Begin
 Inherited MarkKids;
 For i := 0 To High(tab) Do
  If (tab[i].key.k <> vkNull) And (tab[i].key.k <> vkDummy) Then
   MarkVal(tab[i].key);
End;

Function SetItems(s: TPySet): TValArr;
Var
 i, n: Integer;
Begin
 SetLength(Result, s.used);
 n := 0;
 For i := 0 To High(s.tab) Do
  If (s.tab[i].key.k <> vkNull) And (s.tab[i].key.k <> vkDummy) Then Begin
   Result[n] := s.tab[i].key;
   Inc(n);
  End;
End;

{ ------------------------------------------------------------
  Types : creation, MRO, recherche
  ------------------------------------------------------------ }
Function NewTypeRaw(Const nm: AnsiString): TPyType;
Begin
 Result := TPyType.Create(Nil);
 Result.name := nm;
 Result.qualname := nm;
 Result.idict := TPyDict.Make;
 Result.native := nkObject;
 Result.userdef := False;
End;

Procedure ComputeMro(t: TPyType);
Var
 seqs: Array Of Array Of TPyType;
 idxs: Array Of Integer;
 nseq, i, j, k, tot: Integer;
 res: Array Of TPyType;
 cand: TPyType;
 ok, found: Boolean;
 b: TPyType;
Begin
 If Length(t.bases) = 0 Then Begin
  SetLength(t.mro, 1);
  t.mro[0] := t;
  Exit;
 End;
 If Length(t.bases) = 1 Then Begin
  SetLength(t.mro, Length(t.bases[0].mro) + 1);
  t.mro[0] := t;
  For i := 0 To High(t.bases[0].mro) Do t.mro[i + 1] := t.bases[0].mro[i];
  Exit;
 End;
 nseq := Length(t.bases) + 1;
 SetLength(seqs, nseq);
 SetLength(idxs, nseq);
 tot := 0;
 For i := 0 To High(t.bases) Do Begin
  seqs[i] := t.bases[i].mro;
  Inc(tot, Length(seqs[i]));
 End;
 seqs[nseq - 1] := t.bases;
 SetLength(res, 0);
 SetLength(res, 1);
 res[0] := t;
 For i := 0 To nseq - 1 Do idxs[i] := 0;
 While True Do Begin
  cand := Nil;
  found := False;
  For i := 0 To nseq - 1 Do Begin
   If idxs[i] >= Length(seqs[i]) Then Continue;
   cand := seqs[i][idxs[i]];
   ok := True;
   For j := 0 To nseq - 1 Do
    For k := idxs[j] + 1 To High(seqs[j]) Do
     If seqs[j][k] = cand Then ok := False;
   If ok Then Begin
    found := True;
    Break;
   End;
  End;
  If Not found Then Begin
   ok := True;
   For i := 0 To nseq - 1 Do
    If idxs[i] < Length(seqs[i]) Then ok := False;
   If ok Then Break;
   RaiseExc(exTypeError, 'Cannot create a consistent method resolution ' +
    'order (MRO) for bases ' + t.bases[0].name);
  End;
  SetLength(res, Length(res) + 1);
  res[High(res)] := cand;
  For i := 0 To nseq - 1 Do
   If (idxs[i] < Length(seqs[i])) And (seqs[i][idxs[i]] = cand) Then
    Inc(idxs[i]);
 End;
 t.mro := res;
 b := Nil;
 If tot < 0 Then b := Nil;
End;

Function NewType(Const nm: AnsiString; base: TPyType; nat: Integer):
 TPyType;
Begin
 Result := NewTypeRaw(nm);
 Result.cls := tyType;
 If base <> Nil Then Begin
  SetLength(Result.bases, 1);
  Result.bases[0] := base;
  Result.native := base.native;
 End;
 If nat >= 0 Then Result.native := nat;
 ComputeMro(Result);
End;

Function TypeIsSub(c, base: TPyType): Boolean;
Var
 i: Integer;
Begin
 Result := True;
 If c = base Then Exit;
 For i := 0 To High(c.mro) Do
  If c.mro[i] = base Then Exit;
 Result := False;
End;

Function LookupType(t: TPyType; Const name: AnsiString;
 Var v: TVal): Boolean;
Var
 i: Integer;
 h: Int64;
 ix: Integer;
Begin
 h := HashBytes(name);
 For i := 0 To High(t.mro) Do
  If t.mro[i].idict <> Nil Then Begin
   ix := t.mro[i].idict.FindS(name, h);
   If ix >= 0 Then Begin
    v := t.mro[i].idict.ent[ix].val;
    Result := True;
    Exit;
   End;
  End;
 Result := False;
End;

Function LookupTypeO(t: TPyType; nm: TPyStr; Var v: TVal): Boolean;
Var
 i: Integer;
 ix: Integer;
 d: TPyDict;
 key: TVal;
Begin
 key := VObj(nm);
 For i := 0 To High(t.mro) Do Begin
  d := t.mro[i].idict;
  If (d <> Nil) And (d.mask >= 0) Then Begin
   ix := d.FindIdx(key, StrHash(nm));
   If ix >= 0 Then Begin
    v := d.ent[ix].val;
    Result := True;
    Exit;
   End;
  End;
 End;
 Result := False;
End;

Function TypeOf(Const v: TVal): TPyType;
Begin
 Case v.k Of
  vkNone: Result := tyNone;
  vkBool: Result := tyBool;
  vkInt: Result := tyInt;
  vkFloat: Result := tyFloat;
  vkObj: Result := v.o.cls;
 Else
  Result := tyObject;
 End;
End;

Function IsInstance(Const v: TVal; t: TPyType): Boolean;
Begin
 Result := TypeIsSub(TypeOf(v), t);
End;

Function IsObjOf(Const v: TVal; c: TClass): Boolean; Inline;
Begin
 Result := (v.k = vkObj) And (v.o Is c);
End;

Function IsStrVal(Const v: TVal): Boolean; Inline;
Begin
 Result := (v.k = vkObj) And (v.o Is TPyStr);
End;

Function IsExcClass(t: TPyType): Boolean;
Begin
 Result := TypeIsSub(t, exBaseException);
End;

{ ------------------------------------------------------------
  Exceptions : creation et levee
  ------------------------------------------------------------ }
Function MakeExcArgs(c: TPyType; Const args: Array Of TVal): TPyObj;
Var
 o: TPyObj;
 t: TPyTuple;
 i: Integer;
Begin
 o := TPyObj.Create(c);
 o.idict := TPyDict.Make;
 t := NewTuple(Length(args));
 For i := 0 To High(args) Do t.items[i] := args[i];
 o.idict.SetS('args', VObj(t));
 Result := o;
End;

Function MakeExc(c: TPyType; Const msg: AnsiString): TPyObj;
Begin
 Result := MakeExcArgs(c, [VStr(msg)]);
End;

Procedure RaiseExc(c: TPyType; Const msg: AnsiString);
Begin
 Raise EPyError.Make(MakeExc(c, msg));
End;

Procedure RaiseObj(o: TPyObj);
Begin
 Raise EPyError.Make(o);
End;

Procedure RaiseKeyError(Const key: TVal);
Begin
 Raise EPyError.Make(MakeExcArgs(exKeyError, [key]));
End;

Procedure RaiseStopIteration(Const v: TVal);
Begin
 Raise EPyError.Make(MakeExcArgs(exStopIteration, [v]));
End;

Function TypeName(Const v: TVal): AnsiString;
Begin
 Result := TypeOf(v).name;
End;

Procedure TypeErr(Const msg: AnsiString);
Begin
 RaiseExc(exTypeError, msg);
End;

Procedure ValueErr(Const msg: AnsiString);
Begin
 RaiseExc(exValueError, msg);
End;

{ ------------------------------------------------------------
  Definitions de fonctions natives
  ------------------------------------------------------------ }
Function NewBuiltin(Const nm: AnsiString; f: TNativeFn): TPyBuiltin;
Begin
 Result := TPyBuiltin.Create(tyBuiltin);
 Result.name := nm;
 Result.fn := f;
End;

Procedure DefMethod(t: TPyType; Const nm: AnsiString; f: TNativeFn);
Var
 b: TPyBuiltin;
Begin
 b := NewBuiltin(nm, f);
 b.isMethod := True;
 t.idict.SetS(nm, VObj(b));
End;

Procedure DefFunc(d: TPyDict; Const nm: AnsiString; f: TNativeFn);
Begin
 d.SetS(nm, VObj(NewBuiltin(nm, f)));
End;

Function NewWrapper(t: TPyType; Const fn: TVal): TPyWrapper;
Begin
 Result := TPyWrapper.Create(t);
 Result.fn := fn;
End;

Procedure DefClassMethod(t: TPyType; Const nm: AnsiString; f: TNativeFn);
Begin
 t.idict.SetS(nm, VObj(NewWrapper(tyClassMethod, VObj(NewBuiltin(nm, f)))));
End;

Procedure DefStaticMethod(t: TPyType; Const nm: AnsiString; f: TNativeFn);
Begin
 t.idict.SetS(nm, VObj(NewWrapper(tyStaticMethod, VObj(NewBuiltin(nm, f)))));
End;

{ ------------------------------------------------------------
  Acces aux arguments natifs
  ------------------------------------------------------------ }
Function KwGet(kw: TPyDict; Const nm: AnsiString; Var v: TVal): Boolean;
Begin
 If kw = Nil Then Result := False Else Result := kw.GetS(nm, v);
End;

Procedure NoKw(kw: TPyDict; Const fname: AnsiString);
Begin
 If (kw <> Nil) And (kw.used > 0) Then
  TypeErr(fname + '() takes no keyword arguments');
End;

Procedure NeedArgs(n, lo, hi: Integer; Const fname: AnsiString);
Begin
 If n < lo Then Begin
  If lo = hi Then
   TypeErr(fname + ' expected ' + IntToStr(lo) + ' argument' +
    Copy('s', 1, Ord(lo <> 1)) + ', got ' + IntToStr(n))
  Else
   TypeErr(fname + ' expected at least ' + IntToStr(lo) + ' argument' +
    Copy('s', 1, Ord(lo <> 1)) + ', got ' + IntToStr(n));
 End;
 If (hi >= 0) And (n > hi) Then Begin
  If lo = hi Then
   TypeErr(fname + ' expected ' + IntToStr(hi) + ' argument' +
    Copy('s', 1, Ord(hi <> 1)) + ', got ' + IntToStr(n))
  Else
   TypeErr(fname + ' expected at most ' + IntToStr(hi) + ' argument' +
    Copy('s', 1, Ord(hi <> 1)) + ', got ' + IntToStr(n));
 End;
End;

Function ToInt64(Const v: TVal): Int64;
Var
 t: TVal;
Begin
 Case v.k Of
  vkInt, vkBool: Result := v.i;
  vkObj: Begin
    If v.o Is TPyBigInt Then
     RaiseExc(exOverflow, 'Python int too large to convert to C long');
    TypeErr('''' + TypeName(v) + ''' object cannot be interpreted as an ' +
     'integer');
    Result := 0;
   End;
 Else
  TypeErr('''' + TypeName(v) + ''' object cannot be interpreted as an ' +
   'integer');
  Result := 0;
 End;
 t := vNone;
End;

Function StrOf(Const v: TVal): AnsiString;
Begin
 If (v.k = vkObj) And (v.o Is TPyStr) Then Result := TPyStr(v.o).s
 Else Begin
  TypeErr('expected str, got ''' + TypeName(v) + '''');
  Result := '';
 End;
End;

Function IsCallable(Const v: TVal): Boolean;
Var
 t: TVal;
Begin
 Result := False;
 If v.k <> vkObj Then Exit;
 If (v.o Is TPyFunc) Or (v.o Is TPyBuiltin) Or (v.o Is TPyMethod) Or
  (v.o Is TPyType) Then Begin
  Result := True;
  Exit;
 End;
 Result := LookupType(v.o.cls, '__call__', t);
End;

Function ListFromVals(Const a: TValArr): TPyList;
Var
 i: Integer;
Begin
 Result := NewList;
 SetLength(Result.items, Length(a));
 For i := 0 To High(a) Do Result.items[i] := a[i];
 Result.cnt := Length(a);
End;

Function TupleFromVals(Const a: TValArr): TPyTuple;
Var
 i: Integer;
Begin
 Result := NewTuple(Length(a));
 For i := 0 To High(a) Do Result.items[i] := a[i];
End;

Function Tup2(Const a, b: TVal): TVal;
Var
 t: TPyTuple;
Begin
 t := NewTuple(2);
 t.items[0] := a;
 t.items[1] := b;
 Result := VObj(t);
End;

{ ------------------------------------------------------------
  Hachage Python
  ------------------------------------------------------------ }
Function FloatHash(d: Double): Int64;
Const
 P = QWord($1FFFFFFFFFFFFFFF);
Var
 m: Double;
 mx: Extended;
 e, ee: Integer;
 x, y: QWord;
 neg: Boolean;
Begin
 If IsNan(d) Then Begin
  Result := 0;
  Exit;
 End;
 If IsInfinite(d) Then Begin
  If d > 0 Then Result := 314159 Else Result := -314159;
  Exit;
 End;
 If (Frac(d) = 0) And (Abs(d) < 9.0e18) Then Begin
  Result := IntHash(VInt(Trunc(d)));
  Exit;
 End;
 neg := d < 0;
 Frexp(Abs(d), mx, e);
 m := mx;
 x := 0;
 While m <> 0 Do Begin
  x := ((x Shl 28) And P) Or (x Shr (61 - 28));
  m := m * 268435456.0;
  e := e - 28;
  y := QWord(Trunc(m));
  m := m - y;
  x := x + y;
  If x >= P Then x := x - P;
 End;
 If e >= 0 Then ee := e Mod 61 Else ee := 61 - ((-e) Mod 61);
 x := ((x Shl ee) And P) Or (x Shr (61 - ee));
 If neg Then Result := -Int64(x) Else Result := Int64(x);
 If Result = -1 Then Result := -2;
End;

Function ROL64(x: QWord; r: Integer): QWord; Inline;
Begin
 Result := (x Shl r) Or (x Shr (64 - r));
End;

Function CallDunderHash(Const v: TVal): Int64;
Var
 hv: TVal;
 r: TVal;
 t: TPyType;
Begin
 t := TypeOf(v);
 If LookupType(t, '__hash__', hv) Then Begin
  If hv.k = vkNone Then Begin
   TypeErr('unhashable type: ''' + t.name + '''');
  End;
  If (hv.k = vkObj) And ((hv.o Is TPyFunc) Or (hv.o Is TPyMethod)) Then Begin
   r := Call1(hv, v);
   If Not IsIntVal(r) Then
    TypeErr('__hash__ method should return an integer');
   Result := IntHash(r);
   If Result = -1 Then Result := -2;
   Exit;
  End;
 End;
 Result := Int64(PtrUInt(v.o) Shr 4);
End;

Function HashVal(Const v: TVal): Int64;
Var
 t: TPyTuple;
 i: Integer;
 acc, lane: QWord;
 h: Int64;
 items: TValArr;
 s: TPySet;
Begin
 Case v.k Of
  vkNone: Result := 1546275796 Xor 9;
  vkBool, vkInt: Begin
    Result := v.i;
    If (Result < 0) Or (Result >= (Int64(1) Shl 61) - 1) Then
     Result := IntHash(v);
    If Result = -1 Then Result := -2;
   End;
  vkFloat: Result := FloatHash(v.d);
  vkObj: Begin
    If v.o Is TPyStr Then Result := StrHash(TPyStr(v.o))
    Else If v.o Is TPyTuple Then Begin
     t := TPyTuple(v.o);
     acc := QWord(2870177450012600261);
     For i := 0 To High(t.items) Do Begin
      lane := QWord(HashVal(t.items[i]));
      acc := acc + lane * QWord(14029467366897019727);
      acc := ROL64(acc, 31);
      acc := acc * QWord(11400714785074694791);
     End;
     acc := acc + (QWord(Length(t.items)) Xor (QWord(2870177450012600261) Xor
      QWord(3527539)));
     If acc = QWord(-1) Then acc := 1546275796;
     Result := Int64(acc);
    End
    Else If v.o Is TPyBigInt Then Result := IntHash(v)
    Else If v.o Is TPyBytes Then Result := HashBytes(TPyBytes(v.o).s) Xor 7
    Else If (v.o Is TPySet) And TPySet(v.o).frozen Then Begin
     s := TPySet(v.o);
     acc := 0;
     items := SetItems(s);
     For i := 0 To High(items) Do Begin
      h := HashVal(items[i]);
      lane := QWord(h);
      acc := acc Xor (((lane Xor QWord(89869747)) Xor (lane Shl 16)) *
       QWord(3644798167));
     End;
     acc := acc Xor ((QWord(s.used) + 1) * QWord(1927868237));
     acc := acc Xor ((acc Shr 11) Xor (acc Shr 25));
     acc := acc * QWord(69069) + QWord(907133923);
     If acc = QWord(-1) Then acc := 590923713;
     Result := Int64(acc);
    End
    Else If v.o Is TPyRange Then
     Result := TPyRange(v.o).start * 31 + TPyRange(v.o).stop * 7 +
      TPyRange(v.o).step
    Else Result := CallDunderHash(v);
   End;
 Else
  Result := 0;
 End;
End;

{ ------------------------------------------------------------
  Verite
  ------------------------------------------------------------ }
Function IsTrue(Const v: TVal): Boolean;
Var
 t: TVal;
 r: TVal;
Begin
 Case v.k Of
  vkNone: Result := False;
  vkBool, vkInt: Result := v.i <> 0;
  vkFloat: Result := v.d <> 0;
  vkObj: Begin
    If v.o Is TPyStr Then Result := Length(TPyStr(v.o).s) > 0
    Else If v.o Is TPyList Then Result := TPyList(v.o).cnt > 0
    Else If v.o Is TPyTuple Then Result := Length(TPyTuple(v.o).items) > 0
    Else If v.o Is TPyDict Then Result := TPyDict(v.o).used > 0
    Else If v.o Is TPySet Then Result := TPySet(v.o).used > 0
    Else If v.o Is TPyBigInt Then Result := True
    Else If v.o Is TPyBytes Then Result := Length(TPyBytes(v.o).s) > 0
    Else If v.o Is TPyRange Then Result := TPyRange(v.o).len > 0
    Else Begin
     If v.o.cls.userdef Or (v.o Is TPyObj) Then Begin
      If LookupType(v.o.cls, '__bool__', t) And (t.k = vkObj) And
       ((t.o Is TPyFunc) Or (t.o Is TPyBuiltin)) Then Begin
       r := Call1(t, v);
       If r.k <> vkBool Then
        TypeErr('__bool__ should return bool, returned ' + TypeName(r));
       Result := r.i <> 0;
       Exit;
      End;
      If LookupType(v.o.cls, '__len__', t) And (t.k = vkObj) And
       ((t.o Is TPyFunc) Or (t.o Is TPyBuiltin)) Then Begin
       r := Call1(t, v);
       Result := ToInt64(r) <> 0;
       Exit;
      End;
     End;
     Result := True;
    End;
   End;
 Else
  Result := False;
 End;
End;

{ ------------------------------------------------------------
  Nombres
  ------------------------------------------------------------ }
Function IsNumVal(Const v: TVal): Boolean; Inline;
Begin
 Result := (v.k = vkInt) Or (v.k = vkFloat) Or (v.k = vkBool) Or
  ((v.k = vkObj) And (v.o Is TPyBigInt));
End;

Function NumToDouble(Const v: TVal): Double;
Begin
 If v.k = vkFloat Then Result := v.d
 Else If (v.k = vkInt) Or (v.k = vkBool) Then Result := v.i
 Else Result := IntToDouble(v);
End;

{ -1, 0, 1 ou 2 (non ordonne) }
Function CmpNum(Const a, b: TVal): Integer;
Var
 da, db: Double;
 ia, ib: TVal;
Begin
 If IsIntVal(a) And IsIntVal(b) Then Begin
  Result := IntCmp(a, b);
  Exit;
 End;
 If (a.k = vkFloat) And (b.k = vkFloat) Then Begin
  da := a.d;
  db := b.d;
 End
 Else If a.k = vkFloat Then Begin
  da := a.d;
  If IsNan(da) Then Begin
   Result := 2;
   Exit;
  End;
  If IsInfinite(da) Then Begin
   If da > 0 Then Result := 1 Else Result := -1;
   Exit;
  End;
  ia := DoubleToInt(Int(da));
  Result := IntCmp(ia, b);
  If Result = 0 Then Begin
   If Frac(da) > 0 Then Result := 1
   Else If Frac(da) < 0 Then Result := -1;
  End;
  Exit;
 End
 Else Begin
  db := b.d;
  If IsNan(db) Then Begin
   Result := 2;
   Exit;
  End;
  If IsInfinite(db) Then Begin
   If db > 0 Then Result := -1 Else Result := 1;
   Exit;
  End;
  ib := DoubleToInt(Int(db));
  Result := IntCmp(a, ib);
  If Result = 0 Then Begin
   If Frac(db) > 0 Then Result := -1
   Else If Frac(db) < 0 Then Result := 1;
  End;
  Exit;
 End;
 If IsNan(da) Or IsNan(db) Then Result := 2
 Else If da < db Then Result := -1
 Else If da > db Then Result := 1
 Else Result := 0;
End;

Function CmpResult(c, op: Integer): Boolean;
Begin
 If c = 2 Then Begin
  Result := op = 3;
  Exit;
 End;
 Case op Of
  0: Result := c < 0;
  1: Result := c <= 0;
  2: Result := c = 0;
  3: Result := c <> 0;
  4: Result := c > 0;
 Else Result := c >= 0;
 End;
End;

Function OpSymbol(op: Integer): AnsiString;
Begin
 Case op Of
  0: Result := '<';
  1: Result := '<=';
  2: Result := '==';
  3: Result := '!=';
  4: Result := '>';
 Else Result := '>=';
 End;
End;

Function DunderCmpName(op: Integer): AnsiString;
Begin
 Case op Of
  0: Result := '__lt__';
  1: Result := '__le__';
  2: Result := '__eq__';
  3: Result := '__ne__';
  4: Result := '__gt__';
 Else Result := '__ge__';
 End;
End;

Function SwapOp(op: Integer): Integer;
Begin
 Case op Of
  0: Result := 4;
  1: Result := 5;
  4: Result := 0;
  5: Result := 1;
 Else Result := op;
 End;
End;

Function IsNotImpl(Const v: TVal): Boolean; Inline;
Begin
 Result := (v.k = vkObj) And (v.o = vNotImpl.o);
End;

Function CompareStrBytes(Const a, b: AnsiString): Integer;
Var
 n, i: Integer;
Begin
 n := Length(a);
 If Length(b) < n Then n := Length(b);
 For i := 1 To n Do
  If a[i] <> b[i] Then Begin
   If a[i] < b[i] Then Result := -1 Else Result := 1;
   Exit;
  End;
 If Length(a) < Length(b) Then Result := -1
 Else If Length(a) > Length(b) Then Result := 1
 Else Result := 0;
End;

Function ValCompare(Const a, b: TVal; op: Integer): Boolean;
Var
 la, lb: TPyList;
 ta, tb: TPyTuple;
 i, n: Integer;
 r, f: TVal;
 c: Integer;
 sa, sb: TPySet;
 da, db: TPyDict;
 items: TValArr;
 ix: Integer;
 ty: TPyType;
 tried: Boolean;
 av, bv: TValArr;

 Function SeqCmp(Const x, y: TValArr): Boolean;
 Var
  k, m: Integer;
 Begin
  m := Length(x);
  If Length(y) < m Then m := Length(y);
  For k := 0 To m - 1 Do Begin
   If (x[k].k = y[k].k) And (x[k].k = vkObj) And (x[k].o = y[k].o) Then
    Continue;
   If Not ValCompare(x[k], y[k], 2) Then Begin
    If op = 2 Then Result := False
    Else If op = 3 Then Result := True
    Else Result := ValCompare(x[k], y[k], op);
    Exit;
   End;
  End;
  If Length(x) = Length(y) Then Result := CmpResult(0, op)
  Else If Length(x) < Length(y) Then Result := CmpResult(-1, op)
  Else Result := CmpResult(1, op);
 End;

Begin
 { nombres }
 If IsNumVal(a) And IsNumVal(b) Then Begin
  If (a.k <> vkFloat) And (b.k <> vkFloat) And (a.k <> vkObj) And
   (b.k <> vkObj) Then Begin
   Case op Of
    0: Result := a.i < b.i;
    1: Result := a.i <= b.i;
    2: Result := a.i = b.i;
    3: Result := a.i <> b.i;
    4: Result := a.i > b.i;
   Else Result := a.i >= b.i;
   End;
   Exit;
  End;
  Result := CmpResult(CmpNum(a, b), op);
  Exit;
 End;
 If (a.k = vkNone) Or (b.k = vkNone) Then Begin
  If op = 2 Then Begin
   Result := a.k = b.k;
   Exit;
  End;
  If op = 3 Then Begin
   Result := a.k <> b.k;
   Exit;
  End;
 End;
 If (a.k = vkObj) And (b.k = vkObj) Then Begin
  If (a.o Is TPyStr) And (b.o Is TPyStr) Then Begin
   Case op Of
    2: Result := TPyStr(a.o).s = TPyStr(b.o).s;
    3: Result := TPyStr(a.o).s <> TPyStr(b.o).s;
   Else Result := CmpResult(CompareStrBytes(TPyStr(a.o).s,
     TPyStr(b.o).s), op);
   End;
   Exit;
  End;
  If (a.o Is TPyBytes) And (b.o Is TPyBytes) Then Begin
   Result := CmpResult(CompareStrBytes(TPyBytes(a.o).s, TPyBytes(b.o).s),
    op);
   Exit;
  End;
  If (a.o Is TPyList) And (b.o Is TPyList) And Not a.o.cls.userdef Then Begin
   la := TPyList(a.o);
   lb := TPyList(b.o);
   If (op = 2) And (la.cnt <> lb.cnt) Then Begin
    Result := False;
    Exit;
   End;
   If (op = 3) And (la.cnt <> lb.cnt) Then Begin
    Result := True;
    Exit;
   End;
   SetLength(av, la.cnt);
   SetLength(bv, lb.cnt);
   For i := 0 To la.cnt - 1 Do av[i] := la.items[i];
   For i := 0 To lb.cnt - 1 Do bv[i] := lb.items[i];
   Result := SeqCmp(av, bv);
   Exit;
  End;
  If (a.o Is TPyTuple) And (b.o Is TPyTuple) Then Begin
   ta := TPyTuple(a.o);
   tb := TPyTuple(b.o);
   If (op = 2) And (Length(ta.items) <> Length(tb.items)) Then Begin
    Result := False;
    Exit;
   End;
   If (op = 3) And (Length(ta.items) <> Length(tb.items)) Then Begin
    Result := True;
    Exit;
   End;
   Result := SeqCmp(ta.items, tb.items);
   Exit;
  End;
  If (a.o Is TPyDict) And (b.o Is TPyDict) And (op >= 2) And (op <= 3) And
   Not a.o.cls.userdef Then Begin
   da := TPyDict(a.o);
   db := TPyDict(b.o);
   Result := da.used = db.used;
   If Result Then
    For i := 0 To da.nent - 1 Do
     If da.ent[i].key.k <> vkNull Then Begin
      ix := db.FindIdx(da.ent[i].key, da.ent[i].h);
      If (ix < 0) Or Not ValCompare(da.ent[i].val, db.ent[ix].val, 2) Then
       Begin
       Result := False;
       Break;
      End;
     End;
   If op = 3 Then Result := Not Result;
   Exit;
  End;
  If (a.o Is TPySet) And (b.o Is TPySet) Then Begin
   sa := TPySet(a.o);
   sb := TPySet(b.o);
   items := SetItems(sa);
   Case op Of
    2, 3: Begin
      Result := sa.used = sb.used;
      If Result Then
       For i := 0 To High(items) Do
        If Not sb.Contains(items[i]) Then Begin
         Result := False;
         Break;
        End;
      If op = 3 Then Result := Not Result;
     End;
    1, 0: Begin
      Result := sa.used <= sb.used;
      If (op = 0) Then Result := sa.used < sb.used;
      If Result Then
       For i := 0 To High(items) Do
        If Not sb.Contains(items[i]) Then Begin
         Result := False;
         Break;
        End;
     End;
   Else
    items := SetItems(sb);
    Result := sb.used <= sa.used;
    If op = 4 Then Result := sb.used < sa.used;
    If Result Then
     For i := 0 To High(items) Do
      If Not sa.Contains(items[i]) Then Begin
       Result := False;
       Break;
      End;
   End;
   Exit;
  End;
  If (a.o Is TPyRange) And (b.o Is TPyRange) And (op = 2) Then Begin
   Result := (TPyRange(a.o).len = TPyRange(b.o).len) And
    ((TPyRange(a.o).len = 0) Or ((TPyRange(a.o).start = TPyRange(b.o).start)
    And ((TPyRange(a.o).len = 1) Or (TPyRange(a.o).step =
    TPyRange(b.o).step))));
   Exit;
  End;
  If (a.o = b.o) And (op = 2) And Not a.o.cls.userdef And
   Not (a.o Is TPyObj) Then Begin
   Result := True;
   Exit;
  End;
 End;
 { dunders utilisateur }
 tried := False;
 If a.k = vkObj Then Begin
  ty := a.o.cls;
  If (b.k = vkObj) And (b.o.cls <> ty) And TypeIsSub(b.o.cls, ty) And
   LookupType(b.o.cls, DunderCmpName(SwapOp(op)), f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call2(f, b, a);
   tried := True;
   If Not IsNotImpl(r) Then Begin
    Result := IsTrue(r);
    Exit;
   End;
  End;
 End;
 If a.k = vkObj Then Begin
  If LookupType(a.o.cls, DunderCmpName(op), f) And (f.k = vkObj) And
   ((f.o Is TPyFunc) Or (f.o Is TPyMethod)) Then Begin
   r := Call2(f, a, b);
   If Not IsNotImpl(r) Then Begin
    Result := IsTrue(r);
    Exit;
   End;
  End
  Else If (op = 3) And LookupType(a.o.cls, '__eq__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call2(f, a, b);
   If Not IsNotImpl(r) Then Begin
    Result := Not IsTrue(r);
    Exit;
   End;
  End;
 End;
 If (b.k = vkObj) And Not tried Then Begin
  If LookupType(b.o.cls, DunderCmpName(SwapOp(op)), f) And (f.k = vkObj) And
   ((f.o Is TPyFunc) Or (f.o Is TPyMethod)) Then Begin
   r := Call2(f, b, a);
   If Not IsNotImpl(r) Then Begin
    Result := IsTrue(r);
    Exit;
   End;
  End
  Else If (op = 3) And LookupType(b.o.cls, '__eq__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call2(f, b, a);
   If Not IsNotImpl(r) Then Begin
    Result := Not IsTrue(r);
    Exit;
   End;
  End;
 End;
 { defauts }
 If op = 2 Then Begin
  Result := (a.k = b.k) And (((a.k = vkObj) And (a.o = b.o)) Or
   ((a.k <> vkObj) And (a.i = b.i)));
  Exit;
 End;
 If op = 3 Then Begin
  Result := Not ((a.k = b.k) And (((a.k = vkObj) And (a.o = b.o)) Or
   ((a.k <> vkObj) And (a.i = b.i))));
  Exit;
 End;
 TypeErr('''' + OpSymbol(op) + ''' not supported between instances of ''' +
  TypeName(a) + ''' and ''' + TypeName(b) + '''');
 Result := False;
End;

Function ValEq(Const a, b: TVal): Boolean;
Begin
 If (a.k = vkObj) And (b.k = vkObj) And (a.o = b.o) And
  Not (a.o.cls.userdef) Then Begin
  Result := True;
  Exit;
 End;
 Result := ValCompare(a, b, 2);
End;

Function CmpLess(Const a, b: TVal): Boolean;
Begin
 If (a.k = vkInt) And (b.k = vkInt) Then Result := a.i < b.i
 Else If (a.k = vkFloat) And (b.k = vkFloat) Then Result := a.d < b.d
 Else Result := ValCompare(a, b, 0);
End;

{ ------------------------------------------------------------
  repr / str
  ------------------------------------------------------------ }
Var
 ReprStack: Array Of TPyObj;
 ReprDepth: Integer;

Function ReprBusy(o: TPyObj): Boolean;
Var
 i: Integer;
Begin
 Result := False;
 For i := 0 To ReprDepth - 1 Do
  If ReprStack[i] = o Then Result := True;
End;

Procedure ReprPush(o: TPyObj);
Begin
 If ReprDepth >= Length(ReprStack) Then SetLength(ReprStack, ReprDepth * 2 + 16);
 ReprStack[ReprDepth] := o;
 Inc(ReprDepth);
End;

Function HexAddr(o: TPyObj): AnsiString;
Begin
 Result := '0x' + LowerCase(IntToHex(Int64(PtrUInt(o)), 12));
End;

Function TypeModule(t: TPyType): AnsiString;
Var
 v: TVal;
Begin
 Result := '';
 If (t.idict <> Nil) And t.idict.GetS('__module__', v) And IsStrVal(v) Then
  Result := TPyStr(v.o).s;
End;

Function TypeFullName(t: TPyType): AnsiString;
Var
 m: AnsiString;
Begin
 m := TypeModule(t);
 If (m = '') Or (m = 'builtins') Then Result := t.qualname
 Else Result := m + '.' + t.qualname;
End;

Function CallStrMethod(Const v: TVal; Const nm: AnsiString; Var res: AnsiString):
 Boolean;
Var
 f, r: TVal;
Begin
 Result := False;
 If LookupType(v.o.cls, nm, f) And (f.k = vkObj) And
  ((f.o Is TPyFunc) Or (f.o Is TPyMethod)) Then Begin
  r := Call1(f, v);
  If Not IsStrVal(r) Then
   TypeErr(nm + ' returned non-string (type ' + TypeName(r) + ')');
  res := TPyStr(r.o).s;
  Result := True;
 End;
End;

Function ExcArgsStr(o: TPyObj): AnsiString;
Var
 a: TVal;
 t: TPyTuple;
Begin
 Result := '';
 If (o.idict <> Nil) And o.idict.GetS('args', a) And IsObjOf(a, TPyTuple) Then
  Begin
  t := TPyTuple(a.o);
  If Length(t.items) = 0 Then Result := ''
  Else If Length(t.items) = 1 Then Result := StrVal(t.items[0])
  Else Result := ReprVal(a);
 End;
End;

Function ReprBytesJoin(Const items: TValArr; Const op, cl: AnsiString;
 trailingComma: Boolean): AnsiString;
Var
 i: Integer;
Begin
 Result := op;
 For i := 0 To High(items) Do Begin
  If i > 0 Then Result := Result + ', ';
  Result := Result + ReprVal(items[i]);
 End;
 If trailingComma And (Length(items) = 1) Then Result := Result + ',';
 Result := Result + cl;
End;

Function ReprVal(Const v: TVal): AnsiString;
Var
 s: AnsiString;
 i: Integer;
 d: TPyDict;
 items: TValArr;
 o: TPyObj;
 r: TPyRange;
 sl: TPySlice;
 args: TVal;
 first: Boolean;
Begin
 Case v.k Of
  vkNone: Begin Result := 'None'; Exit; End;
  vkBool: Begin
    If v.i <> 0 Then Result := 'True' Else Result := 'False';
    Exit;
   End;
  vkInt: Begin Result := IntToStr(v.i); Exit; End;
  vkFloat: Begin Result := FloatRepr(v.d); Exit; End;
  vkNull: Begin Result := '<NULL>'; Exit; End;
 End;
 o := v.o;
 If o.cls.userdef Then
  If CallStrMethod(v, '__repr__', s) Then Begin
   Result := s;
   Exit;
  End;
 If o Is TPyStr Then Result := StrReprEsc(TPyStr(o).s, False)
 Else If o Is TPyBigInt Then Result := IntToStrVal(v)
 Else If o Is TPyBytes Then Result := BytesReprEsc(TPyBytes(o).s)
 Else If o Is TPyList Then Begin
  If ReprBusy(o) Then Result := '[...]'
  Else Begin
   ReprPush(o);
   Try
    SetLength(items, TPyList(o).cnt);
    For i := 0 To TPyList(o).cnt - 1 Do items[i] := TPyList(o).items[i];
    Result := ReprBytesJoin(items, '[', ']', False);
   Finally
    Dec(ReprDepth);
   End;
  End;
 End
 Else If o Is TPyTuple Then Begin
  If ReprBusy(o) Then Result := '(...)'
  Else Begin
   ReprPush(o);
   Try
    Result := ReprBytesJoin(TPyTuple(o).items, '(', ')', True);
   Finally
    Dec(ReprDepth);
   End;
  End;
 End
 Else If o Is TPyDict Then Begin
  If ReprBusy(o) Then Result := '{...}'
  Else Begin
   ReprPush(o);
   Try
    d := TPyDict(o);
    s := '{';
    first := True;
    For i := 0 To d.nent - 1 Do
     If d.ent[i].key.k <> vkNull Then Begin
      If Not first Then s := s + ', ';
      first := False;
      s := s + ReprVal(d.ent[i].key) + ': ' + ReprVal(d.ent[i].val);
     End;
    Result := s + '}';
   Finally
    Dec(ReprDepth);
   End;
  End;
 End
 Else If o Is TPySet Then Begin
  items := SetItems(TPySet(o));
  If ReprBusy(o) Then Result := '...'
  Else If Length(items) = 0 Then Begin
   If TPySet(o).frozen Then Result := 'frozenset()' Else Result := 'set()';
  End
  Else Begin
   ReprPush(o);
   Try
    If TPySet(o).frozen Then
     Result := 'frozenset(' + ReprBytesJoin(items, '{', '}', False) + ')'
    Else Result := ReprBytesJoin(items, '{', '}', False);
   Finally
    Dec(ReprDepth);
   End;
  End;
  If o.cls.userdef And (o.cls <> tySet) Then
   Result := o.cls.name + '(' + Result + ')';
 End
 Else If o Is TPyRange Then Begin
  r := TPyRange(o);
  If r.step = 1 Then
   Result := 'range(' + IntToStr(r.start) + ', ' + IntToStr(r.stop) + ')'
  Else Result := 'range(' + IntToStr(r.start) + ', ' + IntToStr(r.stop) +
    ', ' + IntToStr(r.step) + ')';
 End
 Else If o Is TPySlice Then Begin
  sl := TPySlice(o);
  Result := 'slice(' + ReprVal(sl.start) + ', ' + ReprVal(sl.stop) + ', ' +
   ReprVal(sl.step) + ')';
 End
 Else If o Is TPyFunc Then
  Result := '<function ' + TPyFunc(o).qualname + ' at ' + HexAddr(o) + '>'
 Else If o Is TPyBuiltin Then
  Result := '<built-in function ' + TPyBuiltin(o).name + '>'
 Else If o Is TPyMethod Then Begin
  If IsObjOf(TPyMethod(o).fn, TPyFunc) Then
   s := TPyFunc(TPyMethod(o).fn.o).qualname
  Else If IsObjOf(TPyMethod(o).fn, TPyBuiltin) Then
   s := TypeName(TPyMethod(o).slf) + '.' + TPyBuiltin(TPyMethod(o).fn.o).name
  Else s := '?';
  Result := '<bound method ' + s + ' of ' + ReprVal(TPyMethod(o).slf) + '>';
 End
 Else If o Is TPyType Then Begin
  If TPyType(o).userdef And (TypeModule(TPyType(o)) <> '') Then
   Result := '<class ''' + TypeFullName(TPyType(o)) + '''>'
  Else If (TypeModule(TPyType(o)) <> '') And
   (TypeModule(TPyType(o)) <> 'builtins') Then
   Result := '<class ''' + TypeFullName(TPyType(o)) + '''>'
  Else Result := '<class ''' + TPyType(o).qualname + '''>';
 End
 Else If o Is TPyModule Then
  Result := '<module ''' + TPyModule(o).name + '''>'
 Else If o Is TPyCode Then
  Result := '<code object ' + TPyCode(o).name + ' at ' + HexAddr(o) +
   ', file "' + TPyCode(o).filename + '", line ' +
   IntToStr(TPyCode(o).firstline) + '>'
 Else If o Is TPyGen Then
  Result := '<generator object ' + TPyGen(o).name + ' at ' + HexAddr(o) + '>'
 Else If o Is TPyCell Then
  Result := '<cell at ' + HexAddr(o) + '>'
 Else If o Is TPyFile Then Begin
  If TPyFile(o).std = 1 Then Result := '<_io.TextIOWrapper name=''<stdin>'' mode=''r'' encoding=''utf-8''>'
  Else If TPyFile(o).std = 2 Then Result := '<_io.TextIOWrapper name=''<stdout>'' mode=''w'' encoding=''utf-8''>'
  Else If TPyFile(o).std = 3 Then Result := '<_io.TextIOWrapper name=''<stderr>'' mode=''w'' encoding=''utf-8''>'
  Else Result := '<_io.TextIOWrapper name=' + StrReprEsc(TPyFile(o).fname,
    False) + ' mode=''' + TPyFile(o).mode + ''' encoding=''UTF-8''>';
 End
 Else If o = vNone.o Then Result := 'None'
 Else If o = vEllipsis.o Then Result := 'Ellipsis'
 Else If o = vNotImpl.o Then Result := 'NotImplemented'
 Else If TypeIsSub(o.cls, exBaseException) Then Begin
  args := vNone;
  s := '';
  If (o.idict <> Nil) And o.idict.GetS('args', args) And
   IsObjOf(args, TPyTuple) Then Begin
   If Length(TPyTuple(args.o).items) = 1 Then
    s := ReprVal(TPyTuple(args.o).items[0])
   Else
    For i := 0 To High(TPyTuple(args.o).items) Do Begin
     If i > 0 Then s := s + ', ';
     s := s + ReprVal(TPyTuple(args.o).items[i]);
    End;
  End;
  Result := o.cls.name + '(' + s + ')';
 End
 Else If o Is TPyProperty Then
  Result := '<property object at ' + HexAddr(o) + '>'
 Else If o Is TPyWrapper Then
  Result := '<' + o.cls.name + ' object at ' + HexAddr(o) + '>'
 Else If o Is TPyIter Then
  Result := '<' + o.cls.name + ' object at ' + HexAddr(o) + '>'
 Else Begin
  Result := '<' + TypeFullName(o.cls) + ' object at ' + HexAddr(o) + '>';
 End;
End;

Function StrVal(Const v: TVal): AnsiString;
Var
 s: AnsiString;
Begin
 Case v.k Of
  vkNone: Result := 'None';
  vkBool: If v.i <> 0 Then Result := 'True' Else Result := 'False';
  vkInt: Result := IntToStr(v.i);
  vkFloat: Result := FloatRepr(v.d);
  vkObj: Begin
    If v.o Is TPyStr Then Begin
     If Not v.o.cls.userdef Then Begin
      Result := TPyStr(v.o).s;
      Exit;
     End;
    End;
    If v.o.cls.userdef Then Begin
     If CallStrMethod(v, '__str__', s) Then Begin
      Result := s;
      Exit;
     End;
    End;
    If v.o Is TPyStr Then Result := TPyStr(v.o).s
    Else If TypeIsSub(v.o.cls, exBaseException) And (v.o Is TPyObj) Then
     Result := ExcArgsStr(v.o)
    Else Result := ReprVal(v);
   End;
 Else
  Result := '<NULL>';
 End;
End;

Function AsciiVal(Const v: TVal): AnsiString;
Var
 s: AnsiString;
 i: Integer;
 c: Cardinal;
Begin
 s := ReprVal(v);
 Result := '';
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  If c < 128 Then Result := Result + Chr(c)
  Else If c < 256 Then Result := Result + '\x' + LowerCase(IntToHex(c, 2))
  Else If c < $10000 Then Result := Result + '\u' + LowerCase(IntToHex(c, 4))
  Else Result := Result + '\U' + LowerCase(IntToHex(c, 8));
 End;
End;

Function FormatValue(Const v: TVal; Const spec: AnsiString): AnsiString;
Var
 fs: TFmtSpec;
 f, r: TVal;
 sv: TVal;
Begin
 If (v.k = vkObj) And v.o.cls.userdef Then Begin
  If LookupType(v.o.cls, '__format__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call2(f, v, VStr(spec));
   If Not IsStrVal(r) Then TypeErr('__format__ must return a str');
   Result := TPyStr(r.o).s;
   Exit;
  End;
 End;
 If spec = '' Then Begin
  Result := StrVal(v);
  Exit;
 End;
 ParseFmtSpec(spec, fs);
 If IsIntVal(v) And (v.k <> vkBool) Then Begin
  If fs.typ In ['e', 'E', 'f', 'F', 'g', 'G', '%'] Then
   Result := FormatFloatSpec(NumToDouble(v), fs)
  Else If fs.typ In [#0, 'd', 'b', 'o', 'x', 'X', 'c', 'n'] Then
   Result := FormatIntSpec(v, fs)
  Else ValueErr('Unknown format code ''' + fs.typ +
    ''' for object of type ''int''');
 End
 Else If v.k = vkBool Then Begin
  If fs.typ = #0 Then Result := FormatStrSpec(StrVal(v), fs)
  Else Result := FormatIntSpec(VInt(v.i), fs);
 End
 Else If v.k = vkFloat Then Begin
  If fs.typ In [#0, 'e', 'E', 'f', 'F', 'g', 'G', 'n', '%'] Then
   Result := FormatFloatSpec(v.d, fs)
  Else ValueErr('Unknown format code ''' + fs.typ +
    ''' for object of type ''float''');
 End
 Else If IsStrVal(v) Then Result := FormatStrSpec(TPyStr(v.o).s, fs)
 Else Begin
  If spec <> '' Then
   TypeErr('unsupported format string passed to ' + TypeName(v) +
    '.__format__');
  Result := StrVal(v);
 End;
 sv := vNone;
End;

{ ------------------------------------------------------------
  Itérateurs natifs
  ------------------------------------------------------------ }
Type
 TListIter = Class(TPyIter)
  src: TPyList;
  i: Integer;
  rev: Boolean;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TTupleIter = Class(TPyIter)
  src: TPyTuple;
  i: Integer;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TStrIter = Class(TPyIter)
  src: TPyStr;
  pos: Integer;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TBytesIter = Class(TPyIter)
  src: TPyBytes;
  pos: Integer;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TRangeIter = Class(TPyIter)
  cur, stop, step: Int64;
  Function Next(Var r: TVal): Boolean; Override;
 End;

 TDictIter = Class(TPyIter)
  src: TPyDict;
  pos: Integer;
  kind: Integer;       { 0 cles, 1 valeurs, 2 items }
  expect: Integer;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TSetIter = Class(TPyIter)
  src: TPySet;
  pos: Integer;
  expect: Integer;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TSeqIter = Class(TPyIter)
  src: TVal;
  i: Int64;
  getter: TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TCallIter = Class(TPyIter)
  fn, sentinel: TVal;
  done: Boolean;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TEnumIter = Class(TPyIter)
  it: TVal;
  n: TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TZipIter = Class(TPyIter)
  its: Array Of TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TMapIter = Class(TPyIter)
  fn: TVal;
  its: Array Of TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TFilterIter = Class(TPyIter)
  fn, it: TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TUserIter = Class(TPyIter)
  obj: TVal;
  nextFn: TVal;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

 TDictView = Class(TPyObj)
  src: TPyDict;
  kind: Integer;
  Procedure MarkKids; Override;
 End;

Function ValIter(Const v: TVal): TVal; Forward;

Function TListIter.Next(Var r: TVal): Boolean;
Begin
 If rev Then Begin
  If i < 0 Then Begin
   Result := False;
   Exit;
  End;
  If i >= src.cnt Then i := src.cnt - 1;
  If i < 0 Then Begin
   Result := False;
   Exit;
  End;
  r := src.items[i];
  Dec(i);
  Result := True;
  Exit;
 End;
 If i < src.cnt Then Begin
  r := src.items[i];
  Inc(i);
  Result := True;
 End
 Else Result := False;
End;

Procedure TListIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TTupleIter.Next(Var r: TVal): Boolean;
Begin
 If i < Length(src.items) Then Begin
  r := src.items[i];
  Inc(i);
  Result := True;
 End
 Else Result := False;
End;

Procedure TTupleIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TStrIter.Next(Var r: TVal): Boolean;
Var
 j: Integer;
 st: Integer;
Begin
 If pos > Length(src.s) Then Begin
  Result := False;
  Exit;
 End;
 st := pos;
 j := pos;
 Utf8Dec(src.s, j);
 r := VStr(Copy(src.s, st, j - st));
 pos := j;
 Result := True;
End;

Procedure TStrIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TBytesIter.Next(Var r: TVal): Boolean;
Begin
 If pos <= Length(src.s) Then Begin
  r := VInt(Ord(src.s[pos]));
  Inc(pos);
  Result := True;
 End
 Else Result := False;
End;

Procedure TBytesIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TRangeIter.Next(Var r: TVal): Boolean;
Begin
 If ((step > 0) And (cur < stop)) Or ((step < 0) And (cur > stop)) Then Begin
  r := VInt(cur);
  cur := cur + step;
  Result := True;
 End
 Else Result := False;
End;

Function TDictIter.Next(Var r: TVal): Boolean;
Begin
 If src.used <> expect Then
  RaiseExc(exRuntimeError, 'dictionary changed size during iteration');
 While pos < src.nent Do Begin
  If src.ent[pos].key.k <> vkNull Then Begin
   Case kind Of
    0: r := src.ent[pos].key;
    1: r := src.ent[pos].val;
   Else r := Tup2(src.ent[pos].key, src.ent[pos].val);
   End;
   Inc(pos);
   Result := True;
   Exit;
  End;
  Inc(pos);
 End;
 Result := False;
End;

Procedure TDictIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TSetIter.Next(Var r: TVal): Boolean;
Begin
 If src.used <> expect Then
  RaiseExc(exRuntimeError, 'Set changed size during iteration');
 While pos <= src.mask Do Begin
  If (src.tab[pos].key.k <> vkNull) And (src.tab[pos].key.k <> vkDummy) Then
   Begin
   r := src.tab[pos].key;
   Inc(pos);
   Result := True;
   Exit;
  End;
  Inc(pos);
 End;
 Result := False;
End;

Procedure TSetIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function TSeqIter.Next(Var r: TVal): Boolean;
Var
 a: TVal;
Begin
 a := VInt(i);
 Try
  r := Call2(getter, src, a);
 Except
  On E: EPyError Do Begin
   If IsInstance(VObj(E.exc), exIndexError) Or
    IsInstance(VObj(E.exc), exStopIteration) Then Begin
    Result := False;
    Exit;
   End;
   Raise;
  End;
 End;
 Inc(i);
 Result := True;
End;

Procedure TSeqIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(src);
 MarkVal(getter);
End;

Function TCallIter.Next(Var r: TVal): Boolean;
Var
 v: TVal;
Begin
 If done Then Begin
  Result := False;
  Exit;
 End;
 v := Call0(fn);
 If ValEq(v, sentinel) Then Begin
  done := True;
  Result := False;
  Exit;
 End;
 r := v;
 Result := True;
End;

Procedure TCallIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(fn);
 MarkVal(sentinel);
End;

Function TEnumIter.Next(Var r: TVal): Boolean;
Var
 v: TVal;
Begin
 If Not IterNextVal(it, v) Then Begin
  Result := False;
  Exit;
 End;
 r := Tup2(n, v);
 n := IntAdd(n, VInt(1));
 Result := True;
End;

Procedure TEnumIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(it);
 MarkVal(n);
End;

Function TZipIter.Next(Var r: TVal): Boolean;
Var
 t: TPyTuple;
 i: Integer;
 v: TVal;
Begin
 If Length(its) = 0 Then Begin
  Result := False;
  Exit;
 End;
 t := NewTuple(Length(its));
 For i := 0 To High(its) Do Begin
  If Not IterNextVal(its[i], v) Then Begin
   Result := False;
   Exit;
  End;
  t.items[i] := v;
 End;
 r := VObj(t);
 Result := True;
End;

Procedure TZipIter.MarkKids;
Var
 i: Integer;
Begin
 Inherited MarkKids;
 For i := 0 To High(its) Do MarkVal(its[i]);
End;

Function TMapIter.Next(Var r: TVal): Boolean;
Var
 args: Array Of TVal;
 i: Integer;
 v: TVal;
Begin
 SetLength(args, Length(its));
 For i := 0 To High(its) Do Begin
  If Not IterNextVal(its[i], v) Then Begin
   Result := False;
   Exit;
  End;
  args[i] := v;
 End;
 r := CallValue(fn, @args[0], Length(args), Nil);
 Result := True;
End;

Procedure TMapIter.MarkKids;
Var
 i: Integer;
Begin
 Inherited MarkKids;
 MarkVal(fn);
 For i := 0 To High(its) Do MarkVal(its[i]);
End;

Function TFilterIter.Next(Var r: TVal): Boolean;
Var
 v, t: TVal;
 ok: Boolean;
Begin
 While IterNextVal(it, v) Do Begin
  If fn.k = vkNone Then ok := IsTrue(v)
  Else Begin
   t := Call1(fn, v);
   ok := IsTrue(t);
  End;
  If ok Then Begin
   r := v;
   Result := True;
   Exit;
  End;
 End;
 Result := False;
End;

Procedure TFilterIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(fn);
 MarkVal(it);
End;

Function TUserIter.Next(Var r: TVal): Boolean;
Begin
 Try
  r := Call1(nextFn, obj);
  Result := True;
 Except
  On E: EPyError Do Begin
   If IsInstance(VObj(E.exc), exStopIteration) Then Result := False
   Else Raise;
  End;
 End;
End;

Procedure TUserIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkVal(obj);
 MarkVal(nextFn);
End;

Procedure TDictView.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(src);
End;

Function NewListIter(l: TPyList; rev: Boolean): TListIter;
Begin
 Result := TListIter.Create(tyIter);
 Result.src := l;
 Result.rev := rev;
 If rev Then Result.i := l.cnt - 1 Else Result.i := 0;
End;

{ ------------------------------------------------------------
  Protocole d'iteration
  ------------------------------------------------------------ }
Function IterOf(Const v: TVal): TVal;
Var
 f, r: TVal;
 o: TPyObj;
 it: TPyIter;
 ui: TUserIter;
 si: TSeqIter;
 ri: TRangeIter;
 di: TDictIter;
Begin
 If v.k <> vkObj Then Begin
  TypeErr('''' + TypeName(v) + ''' object is not iterable');
 End;
 o := v.o;
 If o Is TPyIter Then Begin
  Result := v;
  Exit;
 End;
 If o.cls.userdef Then Begin
  If LookupType(o.cls, '__iter__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call1(f, v);
   If (r.k <> vkObj) Then
    TypeErr('iter() returned non-iterator of type ''' + TypeName(r) + '''');
   If Not (r.o Is TPyIter) Then Begin
    If Not LookupType(r.o.cls, '__next__', f) Then
     TypeErr('iter() returned non-iterator of type ''' + TypeName(r) + '''');
    ui := TUserIter.Create(tyIter);
    ui.obj := r;
    ui.nextFn := f;
    Result := VObj(ui);
    Exit;
   End;
   Result := r;
   Exit;
  End;
 End;
 If o Is TPyList Then Result := VObj(NewListIter(TPyList(o), False))
 Else If o Is TPyTuple Then Begin
  it := TTupleIter.Create(tyIter);
  TTupleIter(it).src := TPyTuple(o);
  Result := VObj(it);
 End
 Else If o Is TPyStr Then Begin
  it := TStrIter.Create(tyIter);
  TStrIter(it).src := TPyStr(o);
  TStrIter(it).pos := 1;
  Result := VObj(it);
 End
 Else If o Is TPyDict Then Begin
  di := TDictIter.Create(tyIter);
  di.src := TPyDict(o);
  di.expect := di.src.used;
  Result := VObj(di);
 End
 Else If o Is TPySet Then Begin
  it := TSetIter.Create(tyIter);
  TSetIter(it).src := TPySet(o);
  TSetIter(it).expect := TPySet(o).used;
  Result := VObj(it);
 End
 Else If o Is TPyRange Then Begin
  ri := TRangeIter.Create(tyIter);
  ri.cur := TPyRange(o).start;
  ri.stop := TPyRange(o).stop;
  ri.step := TPyRange(o).step;
  Result := VObj(ri);
 End
 Else If o Is TPyBytes Then Begin
  it := TBytesIter.Create(tyIter);
  TBytesIter(it).src := TPyBytes(o);
  TBytesIter(it).pos := 1;
  Result := VObj(it);
 End
 Else If o Is TDictView Then Begin
  di := TDictIter.Create(tyIter);
  di.src := TDictView(o).src;
  di.kind := TDictView(o).kind;
  di.expect := di.src.used;
  Result := VObj(di);
 End
 Else If LookupType(o.cls, '__getitem__', f) Then Begin
  si := TSeqIter.Create(tyIter);
  si.src := v;
  si.getter := f;
  Result := VObj(si);
 End
 Else If o Is TPyFile Then Result := ValIter(v)
 Else TypeErr('''' + TypeName(v) + ''' object is not iterable');
End;

Function IterNextVal(Const it: TVal; Var r: TVal): Boolean;
Var
 f: TVal;
Begin
 If (it.k = vkObj) And (it.o Is TPyIter) Then Begin
  Result := TPyIter(it.o).Next(r);
  Exit;
 End;
 If (it.k = vkObj) And LookupType(it.o.cls, '__next__', f) Then Begin
  Try
   r := Call1(f, it);
   Result := True;
  Except
   On E: EPyError Do Begin
    If IsInstance(VObj(E.exc), exStopIteration) Then Result := False
    Else Raise;
   End;
  End;
  Exit;
 End;
 TypeErr('''' + TypeName(it) + ''' object is not an iterator');
 Result := False;
End;

{ Convertit un iterable en tableau de valeurs }
Function IterToArr(Const v: TVal): TValArr;
Var
 it, x: TVal;
 n: Integer;
 l: TPyList;
 i: Integer;
Begin
 If (v.k = vkObj) And (v.o Is TPyList) And Not v.o.cls.userdef Then Begin
  l := TPyList(v.o);
  SetLength(Result, l.cnt);
  For i := 0 To l.cnt - 1 Do Result[i] := l.items[i];
  Exit;
 End;
 If (v.k = vkObj) And (v.o Is TPyTuple) And Not v.o.cls.userdef Then Begin
  Result := Copy(TPyTuple(v.o).items);
  Exit;
 End;
 it := IterOf(v);
 SetLength(Result, 0);
 n := 0;
 While IterNextVal(it, x) Do Begin
  If n >= Length(Result) Then SetLength(Result, n * 2 + 8);
  Result[n] := x;
  Inc(n);
 End;
 SetLength(Result, n);
End;

Function ListFromIter(Const v: TVal): TPyList;
Var
 a: TValArr;
Begin
 a := IterToArr(v);
 Result := ListFromVals(a);
End;

{ ------------------------------------------------------------
  Indices, tranches
  ------------------------------------------------------------ }
Function IndexVal(Const v: TVal): Int64;
Var
 f, r: TVal;
Begin
 If (v.k = vkInt) Or (v.k = vkBool) Then Begin
  Result := v.i;
  Exit;
 End;
 If (v.k = vkObj) Then Begin
  If v.o Is TPyBigInt Then
   RaiseExc(exIndexError, 'cannot fit ''int'' into an index-sized integer');
  If LookupType(v.o.cls, '__index__', f) Then Begin
   r := Call1(f, v);
   If (r.k = vkInt) Or (r.k = vkBool) Then Begin
    Result := r.i;
    Exit;
   End;
  End;
 End;
 TypeErr('''' + TypeName(v) + ''' object cannot be interpreted as an integer');
 Result := 0;
End;

Function HasIndex(Const v: TVal): Boolean;
Var
 f: TVal;
Begin
 Result := (v.k = vkInt) Or (v.k = vkBool) Or
  ((v.k = vkObj) And ((v.o Is TPyBigInt) Or LookupType(v.o.cls,
  '__index__', f)));
End;

Procedure SliceIndices(sl: TPySlice; len: Int64; Var start, stop, step,
 count: Int64);
Var
 lo, hi: Int64;

 Function Bound(Const v: TVal; deflt, lo2, hi2: Int64): Int64;
 Var
  x: Int64;
 Begin
  If v.k = vkNone Then Begin
   Result := deflt;
   Exit;
  End;
  If (v.k = vkObj) And (v.o Is TPyBigInt) Then Begin
   If TPyBigInt(v.o).neg Then x := Low(Int64) Div 2
   Else x := High(Int64) Div 2;
  End
  Else x := IndexVal(v);
  If x < 0 Then Begin
   x := x + len;
   If x < lo2 Then x := lo2;
  End
  Else If x > hi2 Then x := hi2;
  Result := x;
 End;

Begin
 If sl.step.k = vkNone Then step := 1
 Else Begin
  step := IndexVal(sl.step);
  If step = 0 Then ValueErr('slice step cannot be zero');
 End;
 If step > 0 Then Begin
  lo := 0;
  hi := len;
  start := Bound(sl.start, 0, lo, hi);
  stop := Bound(sl.stop, len, lo, hi);
  If stop > start Then count := (stop - start - 1) Div step + 1
  Else count := 0;
 End
 Else Begin
  lo := -1;
  hi := len - 1;
  start := Bound(sl.start, len - 1, lo, hi);
  stop := Bound(sl.stop, -1, lo, hi);
  If start > stop Then count := (start - stop - 1) Div (-step) + 1
  Else count := 0;
 End;
End;

Function NewSlice(Const a, b, c: TVal): TVal;
Var
 s: TPySlice;
Begin
 s := TPySlice.Create(tySlice);
 s.start := a;
 s.stop := b;
 s.step := c;
 Result := VObj(s);
End;

Function StrSliceVal(Const s: AnsiString; sl: TPySlice): AnsiString;
Var
 start, stop, step, count, i: Int64;
 cps: TCpArr;
 n: Integer;
Begin
 If IsAsciiStr(s) Then Begin
  SliceIndices(sl, Length(s), start, stop, step, count);
  If step = 1 Then Begin
   Result := Copy(s, start + 1, count);
   Exit;
  End;
  SetLength(Result, count);
  For i := 0 To count - 1 Do Result[i + 1] := s[start + i * step + 1];
  Exit;
 End;
 cps := StrToCps(s);
 n := Length(cps);
 SliceIndices(sl, n, start, stop, step, count);
 Result := '';
 For i := 0 To count - 1 Do Result := Result + Utf8Enc(cps[start + i * step]);
End;

{ ------------------------------------------------------------
  Operations binaires
  ------------------------------------------------------------ }
Const
 bopAdd = 0; bopSub = 1; bopMul = 2; bopTrueDiv = 3; bopFloorDiv = 4;
 bopMod = 5; bopPow = 6; bopLShift = 7; bopRShift = 8; bopAnd = 9;
 bopOr = 10; bopXor = 11; bopMatMul = 12;
 BinNames: Array[0..12] Of String[16] = ('add', 'sub', 'mul', 'truediv',
  'floordiv', 'mod', 'pow', 'lshift', 'rshift', 'and', 'or', 'xor',
  'matmul');
 BinSyms: Array[0..12] Of String[4] = ('+', '-', '*', '/', '//', '%', '**',
  '<<', '>>', '&', '|', '^', '@');

Function Call3Args(Const fn, a, b, c: TVal): TVal; Forward;
Function PercentFormat(Const fmt: AnsiString; Const arg: TVal): AnsiString; Forward;
Function StrMulRepeat(Const s: AnsiString; n: Int64): AnsiString; Forward;

Function NumBinary(op: Integer; Const a, b: TVal; Var res: TVal): Boolean;
Var
 x, y, r: Double;
 q, m: TVal;
 shift: Int64;
Begin
 Result := False;
 If Not (IsNumVal(a) And IsNumVal(b)) Then Exit;
 Result := True;
 If IsIntVal(a) And IsIntVal(b) Then Begin
  Case op Of
   bopAdd: res := IntAdd(a, b);
   bopSub: res := IntSub(a, b);
   bopMul: res := IntMul(a, b);
   bopTrueDiv: Begin
     If IntSign(b) = 0 Then RaiseExc(exZeroDivision, 'division by zero');
     If (a.k <> vkObj) And (b.k <> vkObj) Then
      res := VFloat(a.i / b.i)
     Else Begin
      x := IntToDouble(a);
      y := IntToDouble(b);
      res := VFloat(x / y);
     End;
    End;
   bopFloorDiv: res := IntFloorDiv(a, b);
   bopMod: res := IntMod(a, b);
   bopPow: Begin
     If IntSign(b) < 0 Then Begin
      x := IntToDouble(a);
      y := IntToDouble(b);
      If x = 0 Then
       RaiseExc(exZeroDivision, '0.0 cannot be raised to a negative power');
      res := VFloat(Power(x, y));
     End
     Else res := IntPow(a, b);
    End;
   bopLShift: Begin
     If IntSign(b) < 0 Then ValueErr('negative shift count');
     If b.k = vkObj Then RaiseExc(exOverflow, 'too many digits in integer');
     If b.i > 100000000 Then RaiseExc(exMemoryError, '');
     res := IntShl(a, b.i);
    End;
   bopRShift: Begin
     If IntSign(b) < 0 Then ValueErr('negative shift count');
     If b.k = vkObj Then shift := High(Int64) Else shift := b.i;
     res := IntShr(a, shift);
    End;
   bopAnd, bopOr, bopXor: Begin
     res := IntBitOp(a, b, Chr(Ord('&') * Ord(op = bopAnd) +
      Ord('|') * Ord(op = bopOr) + Ord('^') * Ord(op = bopXor)));
     If (a.k = vkBool) And (b.k = vkBool) Then res := VBool(res.i <> 0);
    End;
  Else
   Result := False;
  End;
  Exit;
 End;
 x := NumToDouble(a);
 y := NumToDouble(b);
 Case op Of
  bopAdd: res := VFloat(x + y);
  bopSub: res := VFloat(x - y);
  bopMul: res := VFloat(x * y);
  bopTrueDiv: Begin
    If y = 0 Then RaiseExc(exZeroDivision, 'float division by zero');
    res := VFloat(x / y);
   End;
  bopFloorDiv: Begin
    If y = 0 Then RaiseExc(exZeroDivision, 'float divmod()');
    If IsInfinite(y) And Not IsInfinite(x) And Not IsNan(x) Then Begin
     If (x = 0) Or ((x < 0) = (y < 0)) Then res := VFloat(0)
     Else res := VFloat(-1);
    End
    Else Begin
     r := Floor(x / y);
     m := VFloat(x - Floor(x / y) * y);
     res := VFloat(r);
    End;
   End;
  bopMod: Begin
    If y = 0 Then RaiseExc(exZeroDivision, 'float modulo');
    If IsInfinite(y) And Not IsInfinite(x) And Not IsNan(x) Then Begin
     If (x = 0) Or ((x < 0) = (y < 0)) Then res := VFloat(x)
     Else res := VFloat(y);
    End
    Else Begin
     r := x - y * Floor(x / y);
     If (r <> 0) And ((r < 0) <> (y < 0)) Then r := r + y;
     r := FMod(x, y);
     If (r <> 0) And ((r < 0) <> (y < 0)) Then r := r + y;
     If r = 0 Then Begin
      If y < 0 Then r := -0.0 Else r := 0.0;
     End;
     res := VFloat(r);
    End;
   End;
  bopPow: Begin
    If (x = 0) And (y < 0) Then
     RaiseExc(exZeroDivision, '0.0 cannot be raised to a negative power');
    If (x < 0) And (Frac(y) <> 0) And Not IsInfinite(y) Then
     ValueErr('complex results are not supported');
    r := Power(x, y);
    If IsInfinite(r) And Not IsInfinite(x) And Not IsInfinite(y) Then
     RaiseExc(exOverflow, '(34, ''Numerical result out of range'')');
    res := VFloat(r);
   End;
 Else
  Result := False;
 End;
 q := vNone;
 m := vNone;
End;

Function UserBinary(op: Integer; Const a, b: TVal; inplace: Boolean;
 Var res: TVal): Boolean;
Var
 f, r: TVal;
 tb: TPyType;
 nm: AnsiString;
 triedR: Boolean;
Begin
 Result := False;
 triedR := False;
 If inplace And (a.k = vkObj) Then Begin
  nm := '__i' + BinNames[op] + '__';
  If LookupType(a.o.cls, nm, f) And (f.k = vkObj) And
   ((f.o Is TPyFunc) Or (f.o Is TPyMethod)) Then Begin
   r := Call2(f, a, b);
   If Not IsNotImpl(r) Then Begin
    res := r;
    Result := True;
    Exit;
   End;
  End;
 End;
 nm := '__r' + BinNames[op] + '__';
 If (b.k = vkObj) And (a.k = vkObj) And (b.o.cls <> a.o.cls) And
  TypeIsSub(b.o.cls, a.o.cls) And LookupType(b.o.cls, nm, f) And
  (f.k = vkObj) And (f.o Is TPyFunc) Then Begin
  r := Call2(f, b, a);
  triedR := True;
  If Not IsNotImpl(r) Then Begin
   res := r;
   Result := True;
   Exit;
  End;
 End;
 If a.k = vkObj Then Begin
  nm := '__' + BinNames[op] + '__';
  If LookupType(a.o.cls, nm, f) And (f.k = vkObj) And
   ((f.o Is TPyFunc) Or (f.o Is TPyMethod) Or (f.o Is TPyBuiltin)) Then Begin
   r := Call2(f, a, b);
   If Not IsNotImpl(r) Then Begin
    res := r;
    Result := True;
    Exit;
   End;
  End;
 End;
 If (b.k = vkObj) And Not triedR Then Begin
  nm := '__r' + BinNames[op] + '__';
  tb := b.o.cls;
  If LookupType(tb, nm, f) And (f.k = vkObj) And
   ((f.o Is TPyFunc) Or (f.o Is TPyMethod) Or (f.o Is TPyBuiltin)) Then Begin
   r := Call2(f, b, a);
   If Not IsNotImpl(r) Then Begin
    res := r;
    Result := True;
    Exit;
   End;
  End;
 End;
End;

Function SeqConcat(Const a, b: TVal; Var res: TVal): Boolean;
Var
 i, n: Integer;
 l: TPyList;
 t: TPyTuple;
Begin
 Result := True;
 If (a.o Is TPyStr) And (b.o Is TPyStr) Then
  res := VStr(TPyStr(a.o).s + TPyStr(b.o).s)
 Else If (a.o Is TPyList) And (b.o Is TPyList) Then Begin
  l := NewList;
  n := TPyList(a.o).cnt + TPyList(b.o).cnt;
  SetLength(l.items, n);
  For i := 0 To TPyList(a.o).cnt - 1 Do l.items[i] := TPyList(a.o).items[i];
  For i := 0 To TPyList(b.o).cnt - 1 Do
   l.items[TPyList(a.o).cnt + i] := TPyList(b.o).items[i];
  l.cnt := n;
  res := VObj(l);
 End
 Else If (a.o Is TPyTuple) And (b.o Is TPyTuple) Then Begin
  n := Length(TPyTuple(a.o).items);
  t := NewTuple(n + Length(TPyTuple(b.o).items));
  For i := 0 To n - 1 Do t.items[i] := TPyTuple(a.o).items[i];
  For i := 0 To High(TPyTuple(b.o).items) Do
   t.items[n + i] := TPyTuple(b.o).items[i];
  res := VObj(t);
 End
 Else If (a.o Is TPyBytes) And (b.o Is TPyBytes) Then
  res := VBytes(TPyBytes(a.o).s + TPyBytes(b.o).s)
 Else Result := False;
End;

Function StrMulRepeat(Const s: AnsiString; n: Int64): AnsiString;
Var
 i: Int64;
 p: PChar;
 L: Integer;
Begin
 If n <= 0 Then Begin
  Result := '';
  Exit;
 End;
 If Length(s) * n > 1000000000 Then RaiseExc(exMemoryError, '');
 L := Length(s);
 SetLength(Result, L * n);
 If L = 1 Then Begin
  FillChar(Result[1], n, s[1]);
  Exit;
 End;
 p := @Result[1];
 For i := 0 To n - 1 Do Begin
  Move(s[1], p^, L);
  Inc(p, L);
 End;
End;

Function SeqRepeat(Const a: TVal; n: Int64; Var res: TVal): Boolean;
Var
 i, j: Integer;
 l: TPyList;
 t: TPyTuple;
 k: Int64;
Begin
 Result := True;
 If n < 0 Then n := 0;
 If a.o Is TPyStr Then res := VStr(StrMulRepeat(TPyStr(a.o).s, n))
 Else If a.o Is TPyBytes Then res := VBytes(StrMulRepeat(TPyBytes(a.o).s, n))
 Else If a.o Is TPyList Then Begin
  l := NewList;
  k := TPyList(a.o).cnt * n;
  If k > 500000000 Then RaiseExc(exMemoryError, '');
  SetLength(l.items, k);
  For j := 0 To n - 1 Do
   For i := 0 To TPyList(a.o).cnt - 1 Do
    l.items[j * TPyList(a.o).cnt + i] := TPyList(a.o).items[i];
  l.cnt := k;
  res := VObj(l);
 End
 Else If a.o Is TPyTuple Then Begin
  k := Length(TPyTuple(a.o).items) * n;
  If k > 500000000 Then RaiseExc(exMemoryError, '');
  t := NewTuple(k);
  For j := 0 To n - 1 Do
   For i := 0 To High(TPyTuple(a.o).items) Do
    t.items[j * Length(TPyTuple(a.o).items) + i] := TPyTuple(a.o).items[i];
  res := VObj(t);
 End
 Else Result := False;
End;

Function SetBinary(op: Integer; sa, sb: TPySet): TVal;
Var
 r: TPySet;
 ia, ib: TValArr;
 i: Integer;
Begin
 r := TPySet.Make(sa.frozen);
 ia := SetItems(sa);
 ib := SetItems(sb);
 Case op Of
  bopOr: Begin
    For i := 0 To High(ia) Do r.Add(ia[i]);
    For i := 0 To High(ib) Do r.Add(ib[i]);
   End;
  bopAnd: For i := 0 To High(ia) Do
    If sb.Contains(ia[i]) Then r.Add(ia[i]);
  bopSub: For i := 0 To High(ia) Do
    If Not sb.Contains(ia[i]) Then r.Add(ia[i]);
  bopXor: Begin
    For i := 0 To High(ia) Do
     If Not sb.Contains(ia[i]) Then r.Add(ia[i]);
    For i := 0 To High(ib) Do
     If Not sa.Contains(ib[i]) Then r.Add(ib[i]);
   End;
 End;
 Result := VObj(r);
End;

Function BinaryOp(op: Integer; Const a, b: TVal): TVal;
Var
 r: TVal;
 d: TPyDict;
 i: Integer;
Begin
 If NumBinary(op, a, b, r) Then Begin
  Result := r;
  Exit;
 End;
 If (a.k = vkObj) And Not a.o.cls.userdef Then Begin
  Case op Of
   bopAdd: If (b.k = vkObj) And SeqConcat(a, b, r) Then Begin
     Result := r;
     Exit;
    End;
   bopMul: If IsIntVal(b) And (b.k <> vkObj) And SeqRepeat(a, b.i, r) Then
    Begin
     Result := r;
     Exit;
    End;
   bopMod: If a.o Is TPyStr Then Begin
     Result := VStr(PercentFormat(TPyStr(a.o).s, b));
     Exit;
    End;
   bopOr, bopAnd, bopSub, bopXor:
    If (a.o Is TPySet) And (b.k = vkObj) And (b.o Is TPySet) Then Begin
     Result := SetBinary(op, TPySet(a.o), TPySet(b.o));
     Exit;
    End
    Else If (op = bopOr) And (a.o Is TPyDict) And (b.k = vkObj) And
     (b.o Is TPyDict) Then Begin
     d := TPyDict(a.o).Copy;
     For i := 0 To TPyDict(b.o).nent - 1 Do
      If TPyDict(b.o).ent[i].key.k <> vkNull Then
       d.SetItem(TPyDict(b.o).ent[i].key, TPyDict(b.o).ent[i].val);
     Result := VObj(d);
     Exit;
    End;
  End;
 End;
 If (op = bopMul) And (b.k = vkObj) And Not b.o.cls.userdef And
  IsIntVal(a) And (a.k <> vkObj) Then
  If SeqRepeat(b, a.i, r) Then Begin
   Result := r;
   Exit;
  End;
 If UserBinary(op, a, b, False, r) Then Begin
  Result := r;
  Exit;
 End;
 If (a.k = vkObj) And (b.k = vkObj) And (a.o Is TPySet) And (b.o Is TPySet)
  And (op In [bopOr, bopAnd, bopSub, bopXor]) Then Begin
  Result := SetBinary(op, TPySet(a.o), TPySet(b.o));
  Exit;
 End;
 If (a.k = vkObj) And (a.o Is TDictView) And (b.k = vkObj) Then Begin
  { vues de dict comme ensembles }
  Result := VNone;
 End;
 TypeErr('unsupported operand type(s) for ' + BinSyms[op] + ': ''' +
  TypeName(a) + ''' and ''' + TypeName(b) + '''');
 Result := vNone;
End;

Function InplaceOp(op: Integer; Const a, b: TVal): TVal;
Var
 r: TVal;
 i: Integer;
 d: TPyDict;
Begin
 If a.k = vkObj Then Begin
  If Not a.o.cls.userdef Then Begin
   If (a.o Is TPyList) And (op = bopAdd) Then Begin
    If (b.k = vkObj) And (b.o Is TPyList) Then Begin
     For i := 0 To TPyList(b.o).cnt - 1 Do
      TPyList(a.o).Add(TPyList(b.o).items[i]);
    End
    Else Begin
     r := VObj(ListFromIter(b));
     For i := 0 To TPyList(r.o).cnt - 1 Do
      TPyList(a.o).Add(TPyList(r.o).items[i]);
    End;
    Result := a;
    Exit;
   End;
   If (a.o Is TPyList) And (op = bopMul) And IsIntVal(b) Then Begin
    r := BinaryOp(op, a, b);
    TPyList(a.o).Clear;
    For i := 0 To TPyList(r.o).cnt - 1 Do TPyList(a.o).Add(TPyList(r.o).items[i]);
    Result := a;
    Exit;
   End;
   If (a.o Is TPySet) And Not TPySet(a.o).frozen And (b.k = vkObj) And
    (b.o Is TPySet) And (op In [bopOr, bopAnd, bopSub, bopXor]) Then Begin
    r := SetBinary(op, TPySet(a.o), TPySet(b.o));
    TPySet(a.o).Clear;
    For i := 0 To High(TPySet(r.o).tab) Do
     If (TPySet(r.o).tab[i].key.k <> vkNull) And
      (TPySet(r.o).tab[i].key.k <> vkDummy) Then
      TPySet(a.o).Add(TPySet(r.o).tab[i].key);
    Result := a;
    Exit;
   End;
   If (a.o Is TPyDict) And (op = bopOr) Then Begin
    d := TPyDict(a.o);
    If (b.k = vkObj) And (b.o Is TPyDict) Then Begin
     For i := 0 To TPyDict(b.o).nent - 1 Do
      If TPyDict(b.o).ent[i].key.k <> vkNull Then
       d.SetItem(TPyDict(b.o).ent[i].key, TPyDict(b.o).ent[i].val);
     Result := a;
     Exit;
    End;
   End;
  End
  Else If UserBinary(op, a, b, True, r) Then Begin
   Result := r;
   Exit;
  End;
 End;
 Result := BinaryOp(op, a, b);
End;

Function UnaryNeg(Const a: TVal): TVal;
Var
 f, r: TVal;
Begin
 Case a.k Of
  vkInt, vkBool: Result := IntNeg(VInt(a.i));
  vkFloat: Result := VFloat(-a.d);
 Else
  If (a.k = vkObj) And (a.o Is TPyBigInt) Then Result := IntNeg(a)
  Else If (a.k = vkObj) And LookupType(a.o.cls, '__neg__', f) Then
   Result := Call1(f, a)
  Else Begin
   TypeErr('bad operand type for unary -: ''' + TypeName(a) + '''');
   Result := vNone;
  End;
 End;
 r := vNone;
End;

Function UnaryPos(Const a: TVal): TVal;
Var
 f: TVal;
Begin
 Case a.k Of
  vkInt: Result := a;
  vkBool: Result := VInt(a.i);
  vkFloat: Result := a;
 Else
  If (a.k = vkObj) And (a.o Is TPyBigInt) Then Result := a
  Else If (a.k = vkObj) And LookupType(a.o.cls, '__pos__', f) Then
   Result := Call1(f, a)
  Else Begin
   TypeErr('bad operand type for unary +: ''' + TypeName(a) + '''');
   Result := vNone;
  End;
 End;
End;

Function UnaryInvert(Const a: TVal): TVal;
Var
 f: TVal;
Begin
 If IsIntVal(a) Then Result := IntInvert(a)
 Else If (a.k = vkObj) And LookupType(a.o.cls, '__invert__', f) Then
  Result := Call1(f, a)
 Else Begin
  TypeErr('bad operand type for unary ~: ''' + TypeName(a) + '''');
  Result := vNone;
 End;
End;

{ ------------------------------------------------------------
  Appartenance
  ------------------------------------------------------------ }
Function ContainsOp(Const c, item: TVal): Boolean;
Var
 f, it, x, r: TVal;
 i: Integer;
 rg: TPyRange;
 d: Int64;
Begin
 If c.k <> vkObj Then Begin
  TypeErr('argument of type ''' + TypeName(c) + ''' is not iterable');
 End;
 If c.o.cls.userdef Then Begin
  If LookupType(c.o.cls, '__contains__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   r := Call2(f, c, item);
   Result := IsTrue(r);
   Exit;
  End;
 End;
 If c.o Is TPyStr Then Begin
  If Not IsStrVal(item) Then
   TypeErr('''in <string>'' requires string as left operand, not ' +
    TypeName(item));
  Result := Pos(TPyStr(item.o).s, TPyStr(c.o).s) > 0;
  If TPyStr(item.o).s = '' Then Result := True;
  Exit;
 End;
 If c.o Is TPyDict Then Begin
  Result := TPyDict(c.o).GetItem(item, x);
  Exit;
 End;
 If c.o Is TPySet Then Begin
  Result := TPySet(c.o).Contains(item);
  Exit;
 End;
 If c.o Is TPyList Then Begin
  For i := 0 To TPyList(c.o).cnt - 1 Do Begin
   x := TPyList(c.o).items[i];
   If (x.k = item.k) And (x.k = vkObj) And (x.o = item.o) Then Begin
    Result := True;
    Exit;
   End;
   If ValEq(x, item) Then Begin
    Result := True;
    Exit;
   End;
  End;
  Result := False;
  Exit;
 End;
 If c.o Is TPyTuple Then Begin
  For i := 0 To High(TPyTuple(c.o).items) Do Begin
   x := TPyTuple(c.o).items[i];
   If (x.k = item.k) And (x.k = vkObj) And (x.o = item.o) Then Begin
    Result := True;
    Exit;
   End;
   If ValEq(x, item) Then Begin
    Result := True;
    Exit;
   End;
  End;
  Result := False;
  Exit;
 End;
 If c.o Is TPyRange Then Begin
  rg := TPyRange(c.o);
  If Not IsIntVal(item) Or (item.k = vkObj) Then Begin
   If item.k = vkFloat Then Begin
    Result := False;
    If Frac(item.d) = 0 Then
     Result := ContainsOp(c, VInt(Trunc(item.d)));
   End
   Else Result := False;
   Exit;
  End;
  If rg.step > 0 Then Result := (item.i >= rg.start) And (item.i < rg.stop)
  Else Result := (item.i <= rg.start) And (item.i > rg.stop);
  If Result Then Begin
   d := item.i - rg.start;
   Result := (d Mod rg.step) = 0;
  End;
  Exit;
 End;
 If c.o Is TPyBytes Then Begin
  If IsIntVal(item) Then Result := Pos(Chr(item.i And 255),
    TPyBytes(c.o).s) > 0
  Else If (item.k = vkObj) And (item.o Is TPyBytes) Then
   Result := Pos(TPyBytes(item.o).s, TPyBytes(c.o).s) > 0
  Else Begin
   TypeErr('a bytes-like object is required, not ''' + TypeName(item) + '''');
   Result := False;
  End;
  Exit;
 End;
 If c.o Is TDictView Then Begin
  Case TDictView(c.o).kind Of
   0: Result := TDictView(c.o).src.GetItem(item, x);
  Else
   it := IterOf(c);
   Result := False;
   While IterNextVal(it, x) Do
    If ValEq(x, item) Then Begin
     Result := True;
     Break;
    End;
  End;
  Exit;
 End;
 it := IterOf(c);
 Result := False;
 While IterNextVal(it, x) Do
  If ValEq(x, item) Then Begin
   Result := True;
   Break;
  End;
End;

{ ------------------------------------------------------------
  Indexation
  ------------------------------------------------------------ }
Function GetItem(Const o, k: TVal): TVal;
Var
 f, r: TVal;
 i: Int64;
 l: TPyList;
 t: TPyTuple;
 nl: TPyList;
 nt: TPyTuple;
 start, stop, step, count, j: Int64;
 s: AnsiString;
 cps: TCpArr;
 rg: TPyRange;
 ix: Integer;
 d: TPyDict;
Begin
 If o.k <> vkObj Then Begin
  TypeErr('''' + TypeName(o) + ''' object is not subscriptable');
 End;
 If o.o.cls.userdef Then Begin
  If LookupType(o.o.cls, '__getitem__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   Result := Call2(f, o, k);
   Exit;
  End;
 End;
 If o.o Is TPyDict Then Begin
  d := TPyDict(o.o);
  If d.GetItem(k, r) Then Begin
   Result := r;
   Exit;
  End;
  If o.o.cls.userdef And LookupType(o.o.cls, '__missing__', f) Then Begin
   Result := Call2(f, o, k);
   Exit;
  End;
  RaiseKeyError(k);
 End;
 If o.o Is TPyList Then Begin
  l := TPyList(o.o);
  If (k.k = vkInt) Or (k.k = vkBool) Then Begin
   i := k.i;
   If i < 0 Then i := i + l.cnt;
   If (i < 0) Or (i >= l.cnt) Then
    RaiseExc(exIndexError, 'list index out of range');
   Result := l.items[i];
   Exit;
  End;
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), l.cnt, start, stop, step, count);
   nl := NewList;
   SetLength(nl.items, count);
   For j := 0 To count - 1 Do nl.items[j] := l.items[start + j * step];
   nl.cnt := count;
   Result := VObj(nl);
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + l.cnt;
  If (i < 0) Or (i >= l.cnt) Then
   RaiseExc(exIndexError, 'list index out of range');
  Result := l.items[i];
  Exit;
 End;
 If o.o Is TPyTuple Then Begin
  t := TPyTuple(o.o);
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), Length(t.items), start, stop, step, count);
   nt := NewTuple(count);
   For j := 0 To count - 1 Do nt.items[j] := t.items[start + j * step];
   Result := VObj(nt);
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + Length(t.items);
  If (i < 0) Or (i >= Length(t.items)) Then
   RaiseExc(exIndexError, 'tuple index out of range');
  Result := t.items[i];
  Exit;
 End;
 If o.o Is TPyStr Then Begin
  s := TPyStr(o.o).s;
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   Result := VStr(StrSliceVal(s, TPySlice(k.o)));
   Exit;
  End;
  i := IndexVal(k);
  If IsAsciiStr(s) Then Begin
   If i < 0 Then i := i + Length(s);
   If (i < 0) Or (i >= Length(s)) Then
    RaiseExc(exIndexError, 'string index out of range');
   Result := VStr(s[i + 1]);
   Exit;
  End;
  cps := StrToCps(s);
  If i < 0 Then i := i + Length(cps);
  If (i < 0) Or (i >= Length(cps)) Then
   RaiseExc(exIndexError, 'string index out of range');
  Result := VStr(Utf8Enc(cps[i]));
  Exit;
 End;
 If o.o Is TPyBytes Then Begin
  s := TPyBytes(o.o).s;
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), Length(s), start, stop, step, count);
   r := VBytes('');
   For j := 0 To count - 1 Do
    TPyBytes(r.o).s := TPyBytes(r.o).s + s[start + j * step + 1];
   Result := r;
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + Length(s);
  If (i < 0) Or (i >= Length(s)) Then
   RaiseExc(exIndexError, 'index out of range');
  Result := VInt(Ord(s[i + 1]));
  Exit;
 End;
 If o.o Is TPyRange Then Begin
  rg := TPyRange(o.o);
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), rg.len, start, stop, step, count);
   r := VObj(TPyRange.Create(tyRange));
   TPyRange(r.o).start := rg.start + start * rg.step;
   TPyRange(r.o).step := rg.step * step;
   TPyRange(r.o).len := count;
   TPyRange(r.o).stop := TPyRange(r.o).start + count * TPyRange(r.o).step;
   Result := r;
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + rg.len;
  If (i < 0) Or (i >= rg.len) Then
   RaiseExc(exIndexError, 'range object index out of range');
  Result := VInt(rg.start + i * rg.step);
  Exit;
 End;
 If o.o Is TPyType Then Begin
  If LookupType(TPyType(o.o), '__class_getitem__', f) Then Begin
   If (f.k = vkObj) And (f.o Is TPyWrapper) Then
    Result := Call2(TPyWrapper(f.o).fn, o, k)
   Else Result := Call2(f, o, k);
   Exit;
  End;
  Result := o;
  Exit;
 End;
 If LookupType(o.o.cls, '__getitem__', f) Then Begin
  Result := Call2(f, o, k);
  Exit;
 End;
 ix := 0;
 TypeErr('''' + TypeName(o) + ''' object is not subscriptable');
 Result := vNone;
End;

Procedure SetItem(Const o, k, v: TVal);
Var
 f: TVal;
 l: TPyList;
 i: Int64;
 start, stop, step, count, j: Int64;
 vals: TValArr;
 newItems: Array Of TVal;
 n, m: Integer;
Begin
 If o.k <> vkObj Then
  TypeErr('''' + TypeName(o) + ''' object does not support item assignment');
 If o.o.cls.userdef Then
  If LookupType(o.o.cls, '__setitem__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   Call3Args(f, o, k, v);
   Exit;
  End;
 If o.o Is TPyDict Then Begin
  TPyDict(o.o).SetItem(k, v);
  Exit;
 End;
 If o.o Is TPyList Then Begin
  l := TPyList(o.o);
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), l.cnt, start, stop, step, count);
   vals := IterToArr(v);
   If step = 1 Then Begin
    If stop < start Then stop := start;
    n := l.cnt - (stop - start) + Length(vals);
    SetLength(newItems, n);
    m := 0;
    For j := 0 To start - 1 Do Begin newItems[m] := l.items[j]; Inc(m); End;
    For j := 0 To High(vals) Do Begin newItems[m] := vals[j]; Inc(m); End;
    For j := stop To l.cnt - 1 Do Begin newItems[m] := l.items[j]; Inc(m); End;
    l.items := newItems;
    l.cnt := n;
   End
   Else Begin
    If Length(vals) <> count Then
     ValueErr('attempt to assign sequence of size ' + IntToStr(Length(vals))
      + ' to extended slice of size ' + IntToStr(count));
    For j := 0 To count - 1 Do l.items[start + j * step] := vals[j];
   End;
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + l.cnt;
  If (i < 0) Or (i >= l.cnt) Then
   RaiseExc(exIndexError, 'list assignment index out of range');
  l.items[i] := v;
  Exit;
 End;
 If LookupType(o.o.cls, '__setitem__', f) Then Begin
  Call3Args(f, o, k, v);
  Exit;
 End;
 TypeErr('''' + TypeName(o) + ''' object does not support item assignment');
End;

Procedure DelItem(Const o, k: TVal);
Var
 f: TVal;
 l: TPyList;
 i: Int64;
 start, stop, step, count, j: Int64;
 keep: Array Of Boolean;
 n: Integer;
 newItems: Array Of TVal;
Begin
 If o.k <> vkObj Then
  TypeErr('''' + TypeName(o) + ''' object doesn''t support item deletion');
 If o.o.cls.userdef Then
  If LookupType(o.o.cls, '__delitem__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   Call2(f, o, k);
   Exit;
  End;
 If o.o Is TPyDict Then Begin
  If Not TPyDict(o.o).DelItem(k) Then RaiseKeyError(k);
  Exit;
 End;
 If o.o Is TPyList Then Begin
  l := TPyList(o.o);
  If (k.k = vkObj) And (k.o Is TPySlice) Then Begin
   SliceIndices(TPySlice(k.o), l.cnt, start, stop, step, count);
   SetLength(keep, l.cnt);
   For j := 0 To l.cnt - 1 Do keep[j] := True;
   For j := 0 To count - 1 Do keep[start + j * step] := False;
   n := 0;
   SetLength(newItems, l.cnt);
   For j := 0 To l.cnt - 1 Do
    If keep[j] Then Begin
     newItems[n] := l.items[j];
     Inc(n);
    End;
   l.items := newItems;
   l.cnt := n;
   Exit;
  End;
  i := IndexVal(k);
  If i < 0 Then i := i + l.cnt;
  If (i < 0) Or (i >= l.cnt) Then
   RaiseExc(exIndexError, 'list assignment index out of range');
  l.Delete(i);
  Exit;
 End;
 If LookupType(o.o.cls, '__delitem__', f) Then Begin
  Call2(f, o, k);
  Exit;
 End;
 TypeErr('''' + TypeName(o) + ''' object doesn''t support item deletion');
End;

Function Call3Args(Const fn, a, b, c: TVal): TVal;
Var
 args: Array[0..2] Of TVal;
Begin
 args[0] := a;
 args[1] := b;
 args[2] := c;
 Result := CallValue(fn, @args[0], 3, Nil);
End;

Function Call0(Const fn: TVal): TVal;
Var
 args: Array[0..0] Of TVal;
Begin
 args[0] := vNone;
 Result := CallValue(fn, @args[0], 0, Nil);
End;

Function Call1(Const fn, a1: TVal): TVal;
Var
 args: Array[0..0] Of TVal;
Begin
 args[0] := a1;
 Result := CallValue(fn, @args[0], 1, Nil);
End;

Function Call2(Const fn, a1, a2: TVal): TVal;
Var
 args: Array[0..1] Of TVal;
Begin
 args[0] := a1;
 args[1] := a2;
 Result := CallValue(fn, @args[0], 2, Nil);
End;

{ ------------------------------------------------------------
  Frames
  ------------------------------------------------------------ }
Function CallValue3(Const fn, a, b, c: TVal): TVal; Forward;

Var
 FramePool: TFrame;
 LoopYielded: Boolean;
 GcThreshold: Integer;
 GcLastLive: Integer;
 NestLimit: Integer;

Function DictGetO(d: TPyDict; nm: TPyStr; Var v: TVal): Boolean; Inline;
Var
 key: TVal;
 ix: Integer;
Begin
 If d.mask < 0 Then Begin
  Result := False;
  Exit;
 End;
 key.k := vkObj;
 key.o := nm;
 ix := d.FindIdx(key, StrHash(nm));
 If ix >= 0 Then Begin
  v := d.ent[ix].val;
  Result := True;
 End
 Else Result := False;
End;

Procedure DictSetO(d: TPyDict; nm: TPyStr; Const v: TVal); Inline;
Var
 key: TVal;
Begin
 key.k := vkObj;
 key.o := nm;
 d.SetItem(key, v);
End;

Function NewFrame(code: TPyCode; fn: TPyFunc; g, l: TPyDict; heap: Boolean):
 TFrame;
Var
 f: TFrame;
 nfast, total: Integer;
Begin
 If FramePool <> Nil Then Begin
  f := FramePool;
  FramePool := f.back;
 End
 Else f := TFrame.Create;
 nfast := Length(code.varnames) + Length(code.cellvars) +
  Length(code.freevars);
 total := nfast + code.stacksize;
 f.code := code;
 f.func := fn;
 f.globals := g;
 f.locals := l;
 f.builtins := BuiltinsDict;
 f.nfast := nfast;
 f.ip := 0;
 f.lasti := 0;
 f.nb := 0;
 f.gen := Nil;
 f.initInst := vNull;
 f.isEntry := False;
 f.throwExc := Nil;
 f.mem := Nil;
 If heap Then Begin
  GetMem(f.mem, total * SizeOf(TVal) + 16);
  f.base := f.mem;
 End
 Else Begin
  If VTop + total + 8 > VLimit Then Begin
   f.back := FramePool;
   FramePool := f;
   RaiseExc(exRecursionError, 'maximum recursion depth exceeded');
  End;
  f.base := VTop;
  Inc(VTop, total);
 End;
 If nfast > 0 Then FillChar(f.base^, nfast * SizeOf(TVal), 0);
 f.sp := f.base + nfast;
 Result := f;
End;

Procedure ReleaseFrame(f: TFrame);
Begin
 If f.mem = Nil Then Begin
  VTop := f.base;
  f.back := FramePool;
  FramePool := f;
 End;
 f.code := Nil;
 f.func := Nil;
 f.locals := Nil;
 f.initInst := vNull;
End;

Function LineForFrame(f: TFrame): Integer;
Var
 co: TPyCode;
 addr, i, line: Integer;
Begin
 co := f.code;
 line := co.firstline;
 addr := 0;
 i := 1;
 While i < Length(co.lnotab) Do Begin
  addr := addr + Ord(co.lnotab[i]);
  If addr > f.lasti Then Break;
  If Ord(co.lnotab[i + 1]) >= 128 Then
   line := line + Ord(co.lnotab[i + 1]) - 256
  Else line := line + Ord(co.lnotab[i + 1]);
  Inc(i, 2);
 End;
 Result := line;
End;

{ ------------------------------------------------------------
  Attributs
  ------------------------------------------------------------ }
Function BindMethod(Const fn, slf: TVal): TVal;
Var
 m: TPyMethod;
Begin
 m := TPyMethod.Create(tyMethod);
 m.fn := fn;
 m.slf := slf;
 Result := VObj(m);
End;

Function NoneIfNull(Const v: TVal): TVal; Inline;
Begin
 If v.k = vkNull Then Result := vNone Else Result := v;
End;

Function TupleOfTypes(Const a: Array Of TPyType): TVal;
Var
 t: TPyTuple;
 i: Integer;
Begin
 t := NewTuple(Length(a));
 For i := 0 To High(a) Do t.items[i] := VObj(a[i]);
 Result := VObj(t);
End;

Function StrTupleVal(Const a: TStrArr): TVal;
Var
 t: TPyTuple;
 i: Integer;
Begin
 t := NewTuple(Length(a));
 For i := 0 To High(a) Do t.items[i] := VStr(a[i]);
 Result := VObj(t);
End;

Function BytesOfCode(co: TPyCode): AnsiString;
Var
 i: Integer;
Begin
 SetLength(Result, Length(co.co));
 For i := 0 To High(co.co) Do Result[i + 1] := Chr(co.co[i]);
End;

Function SpecialGetAttr(Const o: TVal; Const name: AnsiString;
 Var res: TVal): Boolean;
Var
 ob: TPyObj;
 i: Integer;
 t: TPyTuple;
 d: TPyDict;
 v: TVal;
Begin
 Result := True;
 If name = '__class__' Then Begin
  res := VObj(TypeOf(o));
  Exit;
 End;
 If o.k <> vkObj Then Begin
  If IsNumVal(o) Then Begin
   If name = 'real' Then Begin
    If o.k = vkFloat Then res := o
    Else If o.k = vkBool Then res := VInt(o.i) Else res := o;
    Exit;
   End;
   If name = 'imag' Then Begin
    If o.k = vkFloat Then res := VFloat(0) Else res := VInt(0);
    Exit;
   End;
   If (name = 'numerator') And (o.k <> vkFloat) Then Begin
    If o.k = vkBool Then res := VInt(o.i) Else res := o;
    Exit;
   End;
   If (name = 'denominator') And (o.k <> vkFloat) Then Begin
    res := VInt(1);
    Exit;
   End;
  End;
  Result := False;
  Exit;
 End;
 ob := o.o;
 If (name = '__dict__') Then Begin
  If ob Is TPyType Then Begin
   res := VObj(ob.idict.Copy);
   Exit;
  End;
  If ob.idict <> Nil Then Begin
   res := VObj(ob.idict);
   Exit;
  End;
  If (ob Is TPyObj) And (ob.cls.userdef) Then Begin
   ob.idict := TPyDict.Make;
   res := VObj(ob.idict);
   Exit;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyBigInt Then Begin
  If name = 'real' Then Begin res := o; Exit; End;
  If name = 'imag' Then Begin res := VInt(0); Exit; End;
  If name = 'numerator' Then Begin res := o; Exit; End;
  If name = 'denominator' Then Begin res := VInt(1); Exit; End;
 End;
 If ob Is TPyFunc Then Begin
  With TPyFunc(ob) Do Begin
   If name = '__name__' Then Begin res := VStr(TPyFunc(ob).name); Exit; End;
   If name = '__qualname__' Then Begin res := VStr(qualname); Exit; End;
   If name = '__doc__' Then Begin res := NoneIfNull(doc); Exit; End;
   If name = '__code__' Then Begin res := VObj(code); Exit; End;
   If name = '__globals__' Then Begin res := VObj(globals); Exit; End;
   If name = '__defaults__' Then Begin
    If defaults = Nil Then res := vNone Else res := VObj(defaults);
    Exit;
   End;
   If name = '__kwdefaults__' Then Begin
    If kwdefaults = Nil Then res := vNone Else res := VObj(kwdefaults);
    Exit;
   End;
   If name = '__closure__' Then Begin
    If Length(closure) = 0 Then res := vNone
    Else Begin
     t := NewTuple(Length(closure));
     For i := 0 To High(closure) Do t.items[i] := VObj(closure[i]);
     res := VObj(t);
    End;
    Exit;
   End;
   If name = '__module__' Then Begin
    If globals.GetS('__name__', v) Then res := v Else res := vNone;
    Exit;
   End;
   If name = '__annotations__' Then Begin
    If idict = Nil Then idict := TPyDict.Make;
    If Not idict.GetS('__annotations__', v) Then Begin
     v := VObj(TPyDict.Make);
     idict.SetS('__annotations__', v);
    End;
    res := v;
    Exit;
   End;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyCode Then Begin
  With TPyCode(ob) Do Begin
   If name = 'co_name' Then res := VStr(TPyCode(ob).name)
   Else If name = 'co_filename' Then res := VStr(filename)
   Else If name = 'co_firstlineno' Then res := VInt(firstline)
   Else If name = 'co_argcount' Then res := VInt(argcount)
   Else If name = 'co_posonlyargcount' Then res := VInt(posonly)
   Else If name = 'co_kwonlyargcount' Then res := VInt(kwonly)
   Else If name = 'co_nlocals' Then res := VInt(nlocals)
   Else If name = 'co_stacksize' Then res := VInt(stacksize)
   Else If name = 'co_flags' Then res := VInt(flags)
   Else If name = 'co_code' Then res := VBytes(BytesOfCode(TPyCode(ob)))
   Else If name = 'co_lnotab' Then res := VBytes(lnotab)
   Else If name = 'co_varnames' Then res := StrTupleVal(varnames)
   Else If name = 'co_freevars' Then res := StrTupleVal(freevars)
   Else If name = 'co_cellvars' Then res := StrTupleVal(cellvars)
   Else If name = 'co_names' Then res := StrTupleVal(names)
   Else If name = 'co_consts' Then Begin
    t := NewTuple(Length(consts));
    For i := 0 To High(consts) Do t.items[i] := consts[i];
    res := VObj(t);
   End
   Else Result := False;
  End;
  Exit;
 End;
 If ob Is TPyMethod Then Begin
  If name = '__self__' Then Begin res := TPyMethod(ob).slf; Exit; End;
  If name = '__func__' Then Begin res := TPyMethod(ob).fn; Exit; End;
  If (name = '__name__') Or (name = '__doc__') Or (name = '__qualname__') Or
   (name = '__module__') Then Begin
   res := GetAttr(TPyMethod(ob).fn, name);
   Exit;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyBuiltin Then Begin
  If (name = '__name__') Or (name = '__qualname__') Then Begin
   res := VStr(TPyBuiltin(ob).name);
   Exit;
  End;
  If name = '__doc__' Then Begin res := vNone; Exit; End;
  If name = '__self__' Then Begin res := vNone; Exit; End;
  If name = '__module__' Then Begin res := vNone; Exit; End;
  Result := False;
  Exit;
 End;
 If ob Is TPyType Then Begin
  With TPyType(ob) Do Begin
   If name = '__name__' Then Begin res := VStr(TPyType(ob).name); Exit; End;
   If name = '__qualname__' Then Begin res := VStr(qualname); Exit; End;
   If name = '__bases__' Then Begin res := TupleOfTypes(bases); Exit; End;
   If name = '__mro__' Then Begin res := TupleOfTypes(mro); Exit; End;
   If name = '__base__' Then Begin
    If Length(bases) > 0 Then res := VObj(bases[0]) Else res := vNone;
    Exit;
   End;
   If name = '__module__' Then Begin
    If idict.GetS('__module__', v) Then res := v
    Else res := VStr('builtins');
    Exit;
   End;
   If name = '__doc__' Then Begin
    If idict.GetS('__doc__', v) Then res := v Else res := vNone;
    Exit;
   End;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyModule Then Begin
  If name = '__name__' Then Begin
   If ob.idict.GetS('__name__', v) Then res := v
   Else res := VStr(TPyModule(ob).name);
   Exit;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyGen Then Begin
  If name = '__name__' Then Begin res := VStr(TPyGen(ob).name); Exit; End;
  If name = 'gi_running' Then Begin
   res := VBool(TPyGen(ob).state = 2);
   Exit;
  End;
  If name = 'gi_frame' Then Begin
   If TPyGen(ob).state = 3 Then res := vNone Else res := VObj(ob);
   Exit;
  End;
  Result := False;
  Exit;
 End;
 If ob Is TPyCell Then Begin
  If name = 'cell_contents' Then Begin
   If TPyCell(ob).v.k = vkNull Then RaiseExc(exValueError, 'Cell is empty');
   res := TPyCell(ob).v;
   Exit;
  End;
 End;
 If ob Is TPySlice Then Begin
  If name = 'start' Then Begin res := TPySlice(ob).start; Exit; End;
  If name = 'stop' Then Begin res := TPySlice(ob).stop; Exit; End;
  If name = 'step' Then Begin res := TPySlice(ob).step; Exit; End;
 End;
 If ob Is TPyRange Then Begin
  If name = 'start' Then Begin res := VInt(TPyRange(ob).start); Exit; End;
  If name = 'stop' Then Begin res := VInt(TPyRange(ob).stop); Exit; End;
  If name = 'step' Then Begin res := VInt(TPyRange(ob).step); Exit; End;
 End;
 If ob Is TPyProperty Then Begin
  If name = 'fget' Then Begin res := TPyProperty(ob).fget; Exit; End;
  If name = 'fset' Then Begin res := TPyProperty(ob).fset; Exit; End;
  If name = 'fdel' Then Begin res := TPyProperty(ob).fdel; Exit; End;
  If name = '__doc__' Then Begin res := TPyProperty(ob).doc; Exit; End;
 End;
 If ob Is TPyWrapper Then Begin
  If (name = '__func__') Or (name = '__wrapped__') Then Begin
   res := TPyWrapper(ob).fn;
   Exit;
  End;
 End;
 If ob Is TPyFile Then Begin
  With TPyFile(ob) Do Begin
   If name = 'closed' Then Begin res := VBool(closed); Exit; End;
   If name = 'name' Then Begin
    If std = 1 Then res := VStr('<stdin>')
    Else If std = 2 Then res := VStr('<stdout>')
    Else If std = 3 Then res := VStr('<stderr>')
    Else res := VStr(fname);
    Exit;
   End;
   If name = 'mode' Then Begin res := VStr(mode); Exit; End;
   If name = 'encoding' Then Begin res := VStr('utf-8'); Exit; End;
   If name = 'errors' Then Begin res := VStr('strict'); Exit; End;
   If name = 'newlines' Then Begin res := vNone; Exit; End;
  End;
 End;
 If TypeIsSub(ob.cls, exBaseException) Then Begin
  If name = '__traceback__' Then Begin
   If (ob.idict <> Nil) And ob.idict.GetS('__tb__', v) Then
    res := vNone
   Else res := vNone;
   Exit;
  End;
  If (name = '__cause__') Or (name = '__context__') Then Begin
   If (ob.idict <> Nil) And ob.idict.GetS(name, v) Then res := v
   Else res := vNone;
   Exit;
  End;
  If name = '__suppress_context__' Then Begin
   If (ob.idict <> Nil) And ob.idict.GetS(name, v) Then res := v
   Else res := vFalse;
   Exit;
  End;
 End;
 d := Nil;
 Result := False;
End;

Function SuperGetAttr(sp: TPySuper; Const name: AnsiString;
 Var res: TVal): Boolean;
Var
 i, start: Integer;
 v: TVal;
 isType: Boolean;
 ot: TPyType;
Begin
 Result := False;
 ot := sp.objType;
 If ot = Nil Then Exit;
 start := 0;
 For i := 0 To High(ot.mro) Do
  If ot.mro[i] = sp.thisCls Then Begin
   start := i + 1;
   Break;
  End;
 isType := (sp.obj.k = vkObj) And (sp.obj.o Is TPyType) And
  (sp.obj.o = ot);
 For i := start To High(ot.mro) Do Begin
  If (ot.mro[i].idict <> Nil) And ot.mro[i].idict.GetS(name, v) Then Begin
   If (v.k = vkObj) Then Begin
    If v.o Is TPyFunc Then Begin
     If isType Then res := v Else res := BindMethod(v, sp.obj);
    End
    Else If (v.o Is TPyBuiltin) And TPyBuiltin(v.o).isMethod Then Begin
     If isType Then res := v Else res := BindMethod(v, sp.obj);
    End
    Else If v.o Is TPyWrapper Then Begin
     If v.o.cls = tyClassMethod Then Begin
      If isType Then res := BindMethod(TPyWrapper(v.o).fn, sp.obj)
      Else res := BindMethod(TPyWrapper(v.o).fn, VObj(ot));
     End
     Else res := TPyWrapper(v.o).fn;
    End
    Else If v.o Is TPyProperty Then Begin
     res := Call1(TPyProperty(v.o).fget, sp.obj);
    End
    Else res := v;
   End
   Else res := v;
   Result := True;
   Exit;
  End;
 End;
End;

Function HasDescr(Const tv: TVal; Const nm: AnsiString; Var f: TVal): Boolean;
Begin
 Result := (tv.k = vkObj) And (tv.o.cls.userdef) And
  LookupType(tv.o.cls, nm, f);
End;

Function GetAttrOpt(Const o: TVal; nm: TPyStr; Var res: TVal): Boolean;
Var
 t: TPyType;
 tv, f: TVal;
 found: Boolean;
 name: AnsiString;
 d: TPyDict;
 ct: TPyType;
Begin
 name := nm.s;
 If (o.k = vkObj) And (o.o Is TPySuper) Then Begin
  If name = '__class__' Then Begin
   res := VObj(tySuper);
   Result := True;
   Exit;
  End;
  Result := SuperGetAttr(TPySuper(o.o), name, res);
  If Result Then Exit;
  If (TPySuper(o.o).objType <> Nil) Then Exit;
 End;
 If ((Length(name) > 2) And (name[1] = '_') And (name[2] = '_')) Or
  (o.k <> vkObj) Or (o.o.ClassType <> TPyObj) Then
  If SpecialGetAttr(o, name, res) Then Begin
   Result := True;
   Exit;
  End;
 t := TypeOf(o);
 found := LookupTypeO(t, nm, tv);
 If found And (tv.k = vkObj) Then Begin
  If tv.o Is TPyProperty Then Begin
   If o.k = vkObj Then Begin
    If o.o Is TPyType Then Begin
     { acces a la classe via la metaclasse }
    End;
   End;
   If TPyProperty(tv.o).fget.k = vkNone Then
    RaiseExc(exAttributeError, 'unreadable attribute');
   res := Call1(TPyProperty(tv.o).fget, o);
   Result := True;
   Exit;
  End;
  If HasDescr(tv, '__set__', f) Or HasDescr(tv, '__delete__', f) Then Begin
   If LookupType(tv.o.cls, '__get__', f) Then Begin
    res := CallValue3(f, tv, o, VObj(t));
    Result := True;
    Exit;
   End;
  End;
 End;
 If o.k = vkObj Then Begin
  If o.o Is TPyType Then Begin
   ct := TPyType(o.o);
   If LookupTypeO(ct, nm, tv) Then Begin
    If tv.k = vkObj Then Begin
     If tv.o Is TPyWrapper Then Begin
      If tv.o.cls = tyClassMethod Then
       res := BindMethod(TPyWrapper(tv.o).fn, o)
      Else res := TPyWrapper(tv.o).fn;
      Result := True;
      Exit;
     End;
     If HasDescr(tv, '__get__', f) And Not (tv.o Is TPyType) Then Begin
      res := CallValue3(f, tv, vNone, o);
      Result := True;
      Exit;
     End;
    End;
    res := tv;
    Result := True;
    Exit;
   End;
  End
  Else Begin
   d := o.o.idict;
   If d <> Nil Then
    If DictGetO(d, nm, res) Then Begin
     Result := True;
     Exit;
    End;
  End;
 End;
 If found Then Begin
  If tv.k = vkObj Then Begin
   If tv.o Is TPyFunc Then Begin
    res := BindMethod(tv, o);
    Result := True;
    Exit;
   End;
   If (tv.o Is TPyBuiltin) And TPyBuiltin(tv.o).isMethod Then Begin
    res := BindMethod(tv, o);
    Result := True;
    Exit;
   End;
   If tv.o Is TPyWrapper Then Begin
    If tv.o.cls = tyClassMethod Then Begin
     If (o.k = vkObj) And (o.o Is TPyType) Then
      res := BindMethod(TPyWrapper(tv.o).fn, o)
     Else res := BindMethod(TPyWrapper(tv.o).fn, VObj(t));
    End
    Else res := TPyWrapper(tv.o).fn;
    Result := True;
    Exit;
   End;
   If HasDescr(tv, '__get__', f) And Not (tv.o Is TPyType) Then Begin
    res := CallValue3(f, tv, o, VObj(t));
    Result := True;
    Exit;
   End;
  End;
  res := tv;
  Result := True;
  Exit;
 End;
 { metaclasse pour les classes }
 If (o.k = vkObj) And (o.o Is TPyType) Then Begin
  If LookupTypeO(o.o.cls, nm, tv) Then Begin
   If (tv.k = vkObj) And ((tv.o Is TPyFunc) Or
    ((tv.o Is TPyBuiltin) And TPyBuiltin(tv.o).isMethod)) Then
    res := BindMethod(tv, o)
   Else res := tv;
   Result := True;
   Exit;
  End;
 End;
 { __getattr__ }
 If (o.k = vkObj) And o.o.cls.userdef Then
  If LookupType(o.o.cls, '__getattr__', f) Then Begin
   res := Call2(f, o, VObj(nm));
   Result := True;
   Exit;
  End;
 Result := False;
End;

Procedure RaiseAttrError(Const o: TVal; Const name: AnsiString);
Var
 e: TPyObj;
Begin
 If (o.k = vkObj) And (o.o Is TPyModule) Then
  e := MakeExc(exAttributeError, 'module ''' + TPyModule(o.o).name +
   ''' has no attribute ''' + name + '''')
 Else If (o.k = vkObj) And (o.o Is TPyType) Then
  e := MakeExc(exAttributeError, 'type object ''' + TPyType(o.o).name +
   ''' has no attribute ''' + name + '''')
 Else
  e := MakeExc(exAttributeError, '''' + TypeName(o) +
   ''' object has no attribute ''' + name + '''');
 e.idict.SetS('name', VStr(name));
 e.idict.SetS('obj', o);
 Raise EPyError.Make(e);
End;

Function GetAttr(Const o: TVal; Const name: AnsiString): TVal;
Var
 nm: TPyStr;
Begin
 nm := InternStr(name);
 If Not GetAttrOpt(o, nm, Result) Then RaiseAttrError(o, name);
End;

Function GetAttrO(Const o: TVal; nm: TPyStr): TVal;
Begin
 If Not GetAttrOpt(o, nm, Result) Then RaiseAttrError(o, nm.s);
End;

Function HasAttr(Const o: TVal; Const name: AnsiString): Boolean;
Var
 r: TVal;
Begin
 Try
  Result := GetAttrOpt(o, InternStr(name), r);
 Except
  On E: EPyError Do Begin
   If IsInstance(VObj(E.exc), exAttributeError) Then Result := False
   Else Raise;
  End;
 End;
End;

Procedure SetAttrO(Const o: TVal; nm: TPyStr; Const v: TVal);
Var
 t: TPyType;
 tv, f: TVal;
 name: AnsiString;
Begin
 name := nm.s;
 If o.k <> vkObj Then Begin
  RaiseAttrError(o, name);
 End;
 t := o.o.cls;
 If t.userdef Then Begin
  If LookupType(t, '__setattr__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   Call3Args(f, o, VObj(nm), v);
   Exit;
  End;
 End;
 If LookupTypeO(t, nm, tv) And (tv.k = vkObj) Then Begin
  If tv.o Is TPyProperty Then Begin
   If TPyProperty(tv.o).fset.k = vkNone Then
    RaiseExc(exAttributeError, 'can''t set attribute');
   Call2(TPyProperty(tv.o).fset, o, v);
   Exit;
  End;
  If HasDescr(tv, '__set__', f) Then Begin
   Call3Args(f, tv, o, v);
   Exit;
  End;
 End;
 If o.o Is TPyFunc Then Begin
  If name = '__doc__' Then Begin TPyFunc(o.o).doc := v; Exit; End;
  If name = '__name__' Then Begin
   TPyFunc(o.o).name := StrOf(v);
   Exit;
  End;
  If name = '__qualname__' Then Begin
   TPyFunc(o.o).qualname := StrOf(v);
   Exit;
  End;
  If name = '__defaults__' Then Begin
   If v.k = vkNone Then TPyFunc(o.o).defaults := Nil
   Else TPyFunc(o.o).defaults := TPyTuple(v.o);
   Exit;
  End;
  If name = '__kwdefaults__' Then Begin
   If v.k = vkNone Then TPyFunc(o.o).kwdefaults := Nil
   Else TPyFunc(o.o).kwdefaults := TPyDict(v.o);
   Exit;
  End;
  If TPyFunc(o.o).idict = Nil Then TPyFunc(o.o).idict := TPyDict.Make;
 End;
 If TypeIsSub(t, exBaseException) And (name = '__traceback__') Then Exit;
 If o.o Is TPyType Then Begin
  If name = '__name__' Then Begin
   TPyType(o.o).name := StrOf(v);
   Exit;
  End;
  If name = '__qualname__' Then Begin
   TPyType(o.o).qualname := StrOf(v);
   Exit;
  End;
  If Not TPyType(o.o).userdef Then
   TypeErr('can''t set attributes of built-in/extension type ''' +
    TPyType(o.o).name + '''');
 End;
 If o.o Is TPyProperty Then Begin
  If name = '__doc__' Then Begin TPyProperty(o.o).doc := v; Exit; End;
 End;
 If o.o.idict = Nil Then Begin
  If o.o.cls.userdef Or (o.o Is TPyObj) And (o.o.ClassType = TPyObj) Then
   o.o.idict := TPyDict.Make
  Else RaiseAttrError(o, name);
 End;
 DictSetO(o.o.idict, nm, v);
End;

Procedure SetAttr(Const o: TVal; Const name: AnsiString; Const v: TVal);
Begin
 SetAttrO(o, InternStr(name), v);
End;

Procedure DelAttrO(Const o: TVal; nm: TPyStr);
Var
 t: TPyType;
 tv, f: TVal;
 key: TVal;
Begin
 If o.k <> vkObj Then RaiseAttrError(o, nm.s);
 t := o.o.cls;
 If t.userdef Then
  If LookupType(t, '__delattr__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   Call2(f, o, VObj(nm));
   Exit;
  End;
 If LookupTypeO(t, nm, tv) And (tv.k = vkObj) Then Begin
  If tv.o Is TPyProperty Then Begin
   If TPyProperty(tv.o).fdel.k = vkNone Then
    RaiseExc(exAttributeError, 'can''t delete attribute');
   Call1(TPyProperty(tv.o).fdel, o);
   Exit;
  End;
  If HasDescr(tv, '__delete__', f) Then Begin
   Call2(f, tv, o);
   Exit;
  End;
 End;
 key := VObj(nm);
 If (o.o.idict = Nil) Or Not o.o.idict.DelItem(key) Then
  RaiseAttrError(o, nm.s);
End;

{ ------------------------------------------------------------
  Liaison des arguments
  ------------------------------------------------------------ }
Function PluralS(n: Integer): AnsiString;
Begin
 If n = 1 Then Result := '' Else Result := 's';
End;

Function JoinNames(Const names: TStrArr): AnsiString;
Var
 i, n: Integer;
Begin
 n := Length(names);
 Result := '';
 For i := 0 To n - 1 Do Begin
  If i > 0 Then Begin
   If i = n - 1 Then Begin
    If n > 2 Then Result := Result + ', and ' Else Result := Result + ' and ';
   End
   Else Result := Result + ', ';
  End;
  Result := Result + '''' + names[i] + '''';
 End;
End;

Procedure SetupCells(fr: TFrame; fn: TPyFunc);
Var
 co: TPyCode;
 i, j, nl, nc: Integer;
 c: TPyCell;
 fast: PVal;
Begin
 co := fr.code;
 nl := Length(co.varnames);
 nc := Length(co.cellvars);
 fast := fr.base;
 For i := 0 To nc - 1 Do Begin
  c := TPyCell.Create(tyCell);
  c.v := vNull;
  { le parametre correspondant est copie dans la cellule }
  For j := 0 To nl - 1 Do
   If (j < co.argcount + co.kwonly + Ord((co.flags And CO_VARARGS) <> 0) +
    Ord((co.flags And CO_VARKEYWORDS) <> 0)) And
    (co.varnames[j] = co.cellvars[i]) Then Begin
    c.v := fast[j];
    Break;
   End;
  fast[nl + i] := VObj(c);
 End;
 If fn <> Nil Then
  For i := 0 To High(co.freevars) Do
   If i < Length(fn.closure) Then fast[nl + nc + i] := VObj(fn.closure[i]);
End;

{ Lie les arguments : positionnels a[0..npos-1], mots-cles kwv/kwNames ou kwd }
Procedure BindArgs(fn: TPyFunc; fr: TFrame; a: PVal; npos: Integer;
 kwv: PVal; kwNames: TPyTuple; kwd: TPyDict);
Var
 co: TPyCode;
 fast: PVal;
 ac, ko, i, j, nkw, m, ndef, idx: Integer;
 kwArgsDict: TPyDict;
 vaTuple: TPyTuple;
 slotVA, slotKW: Integer;
 name: AnsiString;
 v: TVal;
 missing: TStrArr;
 found: Boolean;
 nm: TPyStr;
 key: TVal;
 e: Integer;
 total: Integer;

 Procedure AddKw(Const k, val: TVal);
 Var
  kn: AnsiString;
  jj: Integer;
  ok2: Boolean;
 Begin
  If Not IsStrVal(k) Then TypeErr('keywords must be strings');
  kn := TPyStr(k.o).s;
  ok2 := False;
  For jj := co.posonly To ac + ko - 1 Do
   If co.varnames[jj] = kn Then Begin
    If fast[jj].k <> vkNull Then
     TypeErr(fn.name + '() got multiple values for argument ''' + kn + '''');
    fast[jj] := val;
    ok2 := True;
    Break;
   End;
  If Not ok2 Then Begin
   If kwArgsDict = Nil Then Begin
    For jj := 0 To co.posonly - 1 Do
     If co.varnames[jj] = kn Then
      TypeErr(fn.name + '() got some positional-only arguments passed ' +
       'as keyword arguments: ''' + kn + '''');
    TypeErr(fn.name + '() got an unexpected keyword argument ''' + kn +
     '''');
   End;
   kwArgsDict.SetItem(k, val);
  End;
 End;

Begin
 co := fn.code;
 fast := fr.base;
 ac := co.argcount;
 ko := co.kwonly;
 kwArgsDict := Nil;
 slotVA := ac + ko;
 If (co.flags And CO_VARARGS) <> 0 Then slotKW := slotVA + 1
 Else slotKW := slotVA;
 If (co.flags And CO_VARKEYWORDS) <> 0 Then Begin
  kwArgsDict := TPyDict.Make;
  fast[slotKW] := VObj(kwArgsDict);
 End;
 m := npos;
 If m > ac Then m := ac;
 For i := 0 To m - 1 Do fast[i] := a[i];
 If (co.flags And CO_VARARGS) <> 0 Then Begin
  If npos > ac Then Begin
   vaTuple := NewTuple(npos - ac);
   For i := ac To npos - 1 Do vaTuple.items[i - ac] := a[i];
  End
  Else vaTuple := EmptyTuple;
  fast[slotVA] := VObj(vaTuple);
 End
 Else If npos > ac Then Begin
  ndef := 0;
  If fn.defaults <> Nil Then ndef := Length(fn.defaults.items);
  If ndef > 0 Then
   TypeErr(fn.name + '() takes from ' + IntToStr(ac - ndef) + ' to ' +
    IntToStr(ac) + ' positional arguments but ' + IntToStr(npos) +
    ' ' + Copy('was were', 1 + 4 * Ord(npos <> 1), 3 + Ord(npos <> 1)) +
    ' given')
  Else
   TypeErr(fn.name + '() takes ' + IntToStr(ac) + ' positional argument' +
    PluralS(ac) + ' but ' + IntToStr(npos) + ' ' + Copy('was were', 1 + 4 *
    Ord(npos <> 1), 3 + Ord(npos <> 1)) + ' given');
 End;
 { mots-cles }
 If kwNames <> Nil Then Begin
  For i := 0 To High(kwNames.items) Do AddKw(kwNames.items[i], kwv[i]);
 End;
 If kwd <> Nil Then
  For i := 0 To kwd.nent - 1 Do
   If kwd.ent[i].key.k <> vkNull Then AddKw(kwd.ent[i].key, kwd.ent[i].val);
 { valeurs par defaut positionnelles }
 ndef := 0;
 If fn.defaults <> Nil Then ndef := Length(fn.defaults.items);
 SetLength(missing, 0);
 For i := m To ac - 1 Do
  If fast[i].k = vkNull Then Begin
   idx := i - (ac - ndef);
   If idx >= 0 Then fast[i] := fn.defaults.items[idx]
   Else Begin
    SetLength(missing, Length(missing) + 1);
    missing[High(missing)] := co.varnames[i];
   End;
  End;
 If Length(missing) > 0 Then
  TypeErr(fn.name + '() missing ' + IntToStr(Length(missing)) +
   ' required positional argument' + PluralS(Length(missing)) + ': ' +
   JoinNames(missing));
 { arguments mot-cle seulement }
 SetLength(missing, 0);
 For i := ac To ac + ko - 1 Do
  If fast[i].k = vkNull Then Begin
   found := False;
   If fn.kwdefaults <> Nil Then
    If fn.kwdefaults.GetS(co.varnames[i], v) Then Begin
     fast[i] := v;
     found := True;
    End;
   If Not found Then Begin
    SetLength(missing, Length(missing) + 1);
    missing[High(missing)] := co.varnames[i];
   End;
  End;
 If Length(missing) > 0 Then
  TypeErr(fn.name + '() missing ' + IntToStr(Length(missing)) +
   ' required keyword-only argument' + PluralS(Length(missing)) + ': ' +
   JoinNames(missing));
 total := 0;
 e := total;
 nm := Nil;
 key := vNone;
 j := 0;
 nkw := j;
 name := '';
End;

{ ------------------------------------------------------------
  Appels
  ------------------------------------------------------------ }
Function CallValue3(Const fn, a, b, c: TVal): TVal;
Begin
 Result := Call3Args(fn, a, b, c);
End;

Function MakeGenerator(fr: TFrame; fn: TPyFunc): TVal;
Var
 g: TPyGen;
Begin
 g := TPyGen.Create(tyGenerator);
 g.frame := fr;
 g.state := 0;
 g.retval := vNull;
 g.name := fn.name;
 fr.gen := g;
 Result := VObj(g);
End;

Function Run(entry: TFrame): TVal; Forward;

Function CallPyFunc(fn: TPyFunc; a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 fr: TFrame;
 gen: Boolean;
 code: TPyCode;
Begin
 code := fn.code;
 gen := (code.flags And CO_GENERATOR) <> 0;
 If CallDepth >= RecursionLimit Then
  RaiseExc(exRecursionError, 'maximum recursion depth exceeded');
 fr := NewFrame(code, fn, fn.globals, Nil, gen);
 Try
  BindArgs(fn, fr, a, n, Nil, Nil, kw);
  SetupCells(fr, fn);
 Except
  If gen Then Begin
   FreeMem(fr.mem);
   fr.mem := Nil;
   fr.Free;
  End
  Else ReleaseFrame(fr);
  Raise;
 End;
 If gen Then Begin
  Result := MakeGenerator(fr, fn);
  Exit;
 End;
 Result := Run(fr);
End;

Function CallType(t: TPyType; a: PVal; n: Integer; kw: TPyDict): TVal; Forward;

Function CallValue(Const fn: TVal; a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TPyObj;
 tmp: Array Of TVal;
 f: TVal;
 i: Integer;
Begin
 If fn.k <> vkObj Then Begin
  TypeErr('''' + TypeName(fn) + ''' object is not callable');
 End;
 o := fn.o;
 If o Is TPyFunc Then Begin
  Result := CallPyFunc(TPyFunc(o), a, n, kw);
  Exit;
 End;
 If o Is TPyBuiltin Then Begin
  Result := TPyBuiltin(o).fn(a, n, kw);
  Exit;
 End;
 If o Is TPyMethod Then Begin
  SetLength(tmp, n + 1);
  tmp[0] := TPyMethod(o).slf;
  For i := 0 To n - 1 Do tmp[i + 1] := a[i];
  Result := CallValue(TPyMethod(o).fn, @tmp[0], n + 1, kw);
  Exit;
 End;
 If o Is TPyType Then Begin
  Result := CallType(TPyType(o), a, n, kw);
  Exit;
 End;
 If LookupType(o.cls, '__call__', f) Then Begin
  SetLength(tmp, n + 1);
  tmp[0] := fn;
  For i := 0 To n - 1 Do tmp[i + 1] := a[i];
  Result := CallValue(f, @tmp[0], n + 1, kw);
  Exit;
 End;
 TypeErr('''' + TypeName(fn) + ''' object is not callable');
 Result := vNone;
End;

Function CallValueKw(Const fn: TVal; Const args: Array Of TVal; kw: TPyDict):
 TVal;
Var
 tmp: Array Of TVal;
 i: Integer;
Begin
 SetLength(tmp, Length(args) + 1);
 For i := 0 To High(args) Do tmp[i] := args[i];
 Result := CallValue(fn, @tmp[0], Length(args), kw);
End;

Function CallType(t: TPyType; a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f, nf, obj, r: TVal;
 tmp: Array Of TVal;
 i: Integer;
 meta: TPyType;
Begin
 meta := t.cls;
 If (meta <> tyType) And (meta <> Nil) Then
  If LookupType(meta, '__call__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   SetLength(tmp, n + 1);
   tmp[0] := VObj(t);
   For i := 0 To n - 1 Do tmp[i + 1] := a[i];
   Result := CallValue(f, @tmp[0], n + 1, kw);
   Exit;
  End;
 If (t = tyType) And (n = 1) And ((kw = Nil) Or (kw.used = 0)) Then Begin
  Result := VObj(TypeOf(a[0]));
  Exit;
 End;
 If Assigned(t.ctor) And Not t.userdef Then Begin
  Result := t.ctor(a, n, kw);
  Exit;
 End;
 If Not LookupType(t, '__new__', nf) Then
  TypeErr('cannot create ''' + t.name + ''' instances');
 SetLength(tmp, n + 1);
 tmp[0] := VObj(t);
 For i := 0 To n - 1 Do tmp[i + 1] := a[i];
 If (nf.k = vkObj) And (nf.o Is TPyWrapper) Then nf := TPyWrapper(nf.o).fn;
 obj := CallValue(nf, @tmp[0], n + 1, kw);
 If IsInstance(obj, t) Then Begin
  If LookupType(t, '__init__', f) Then Begin
   tmp[0] := obj;
   r := CallValue(f, @tmp[0], n + 1, kw);
   If r.k <> vkNone Then
    TypeErr('__init__() should return None, not ''' + TypeName(r) + '''');
  End;
 End;
 Result := obj;
End;

{ ------------------------------------------------------------
  Creation de classes
  ------------------------------------------------------------ }
Function NativeKindOf(bases: Array Of TPyType): Integer;
Var
 i: Integer;
 k: Integer;
Begin
 Result := nkObject;
 For i := 0 To High(bases) Do Begin
  k := bases[i].native;
  If k <> nkObject Then Begin
   If (Result <> nkObject) And (Result <> k) And Not
    ((Result = nkException) Or (k = nkException)) Then
    TypeErr('multiple bases have instance lay-out conflict');
   Result := k;
  End;
 End;
End;

Function TypeNew(meta: TPyType; Const nm: AnsiString; Const bases: Array Of
 TPyType; ns: TPyDict; kw: TPyDict): TPyType;
Var
 t: TPyType;
 i, j: Integer;
 v, cell, f: TVal;
 d: TPyDict;
 key: TVal;
Begin
 t := TPyType.Create(meta);
 t.name := nm;
 t.qualname := nm;
 t.userdef := True;
 d := ns.Copy;
 t.idict := d;
 If d.GetS('__qualname__', v) And IsStrVal(v) Then Begin
  t.qualname := TPyStr(v.o).s;
  d.DelS('__qualname__');
 End;
 If Length(bases) = 0 Then Begin
  SetLength(t.bases, 1);
  t.bases[0] := tyObject;
 End
 Else Begin
  SetLength(t.bases, Length(bases));
  For i := 0 To High(bases) Do t.bases[i] := bases[i];
 End;
 t.native := NativeKindOf(t.bases);
 ComputeMro(t);
 If Not d.HasS('__module__') Then Begin
  If (CurFrame <> Nil) And CurFrame.globals.GetS('__name__', v) Then
   d.SetS('__module__', v)
  Else d.SetS('__module__', VStr('__main__'));
 End;
 If d.HasS('__eq__') And Not d.HasS('__hash__') Then
  d.SetS('__hash__', vNone);
 If d.GetS('__classcell__', cell) Then Begin
  If (cell.k = vkObj) And (cell.o Is TPyCell) Then
   TPyCell(cell.o).v := VObj(t);
  d.DelS('__classcell__');
 End;
 { __set_name__ }
 For i := 0 To d.nent - 1 Do
  If (d.ent[i].key.k <> vkNull) And (d.ent[i].val.k = vkObj) And
   d.ent[i].val.o.cls.userdef Then
   If LookupType(d.ent[i].val.o.cls, '__set_name__', f) Then
    Call3Args(f, d.ent[i].val, VObj(t), d.ent[i].key);
 { __init_subclass__ }
 If Length(t.mro) > 1 Then Begin
  For i := 1 To High(t.mro) Do
   If (t.mro[i].idict <> Nil) And t.mro[i].idict.GetS('__init_subclass__', f)
    Then Begin
    If (f.k = vkObj) And (f.o Is TPyWrapper) Then
     f := BindMethod(TPyWrapper(f.o).fn, VObj(t));
    If (f.k = vkObj) And (f.o Is TPyMethod) Then
     CallValue(f, @key, 0, kw);
    Break;
   End;
 End;
 Result := t;
End;

Function BuildClass(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 func: TPyFunc;
 nm: AnsiString;
 bases: Array Of TPyType;
 nb, i: Integer;
 meta, winner, bm: TPyType;
 mv, nsv, clsv: TVal;
 ns: TPyDict;
 kw2: TPyDict;
 args: Array[0..2] Of TVal;
 fr: TFrame;
 r: TVal;
 prep: TVal;
 btuple: TPyTuple;
 j: Integer;
Begin
 If (n < 2) Or Not ((a[0].k = vkObj) And (a[0].o Is TPyFunc)) Then
  TypeErr('__build_class__: func must be a function');
 func := TPyFunc(a[0].o);
 nm := StrOf(a[1]);
 nb := n - 2;
 SetLength(bases, nb);
 btuple := NewTuple(nb);
 For i := 0 To nb - 1 Do Begin
  If Not ((a[i + 2].k = vkObj) And (a[i + 2].o Is TPyType)) Then
   TypeErr('bases must be types');
  bases[i] := TPyType(a[i + 2].o);
  btuple.items[i] := a[i + 2];
 End;
 meta := Nil;
 kw2 := Nil;
 If kw <> Nil Then Begin
  kw2 := kw.Copy;
  If kw2.GetS('metaclass', mv) Then Begin
   If (mv.k = vkObj) And (mv.o Is TPyType) Then meta := TPyType(mv.o);
   kw2.DelS('metaclass');
   If meta = Nil Then meta := tyType;
  End;
 End;
 If meta = Nil Then Begin
  If nb = 0 Then meta := tyType Else meta := bases[0].cls;
 End;
 winner := meta;
 For i := 0 To nb - 1 Do Begin
  bm := bases[i].cls;
  If TypeIsSub(bm, winner) Then winner := bm
  Else If Not TypeIsSub(winner, bm) Then
   TypeErr('metaclass conflict: the metaclass of a derived class must be ' +
    'a (non-strict) subclass of the metaclasses of all its bases');
 End;
 ns := Nil;
 If LookupType(winner, '__prepare__', prep) Then Begin
  If (prep.k = vkObj) And (prep.o Is TPyWrapper) Then
   prep := BindMethod(TPyWrapper(prep.o).fn, VObj(winner));
  args[0] := a[1];
  args[1] := VObj(btuple);
  r := CallValue(prep, @args[0], 2, kw2);
  If (r.k = vkObj) And (r.o Is TPyDict) Then ns := TPyDict(r.o);
 End;
 If ns = Nil Then ns := TPyDict.Make;
 { execution du corps de la classe }
 fr := NewFrame(func.code, func, func.globals, ns, False);
 Try
  SetupCells(fr, func);
 Except
  ReleaseFrame(fr);
  Raise;
 End;
 r := Run(fr);
 args[0] := a[1];
 args[1] := VObj(btuple);
 args[2] := VObj(ns);
 If winner = tyType Then
  clsv := VObj(TypeNew(tyType, nm, bases, ns, kw2))
 Else clsv := CallValue(VObj(winner), @args[0], 3, kw2);
 If (r.k = vkObj) And (r.o Is TPyCell) And (clsv.k = vkObj) Then
  TPyCell(r.o).v := clsv;
 j := 0;
 Result := clsv;
End;

{ ------------------------------------------------------------
  Generateurs
  ------------------------------------------------------------ }
Function GenResume(g: TPyGen; Const sendv: TVal; Var res: TVal): Boolean;
Var
 fr: TFrame;
 v: TVal;
Begin
 If g.state = 2 Then RaiseExc(exValueError, 'generator already executing');
 If g.state = 3 Then Begin
  Result := False;
  Exit;
 End;
 fr := g.frame;
 If (g.state = 0) And (sendv.k <> vkNone) Then
  TypeErr('can''t send non-None value to a just-started generator');
 If g.state = 1 Then Begin
  fr.sp^ := sendv;
  Inc(fr.sp);
 End;
 g.state := 2;
 Try
  v := Run(fr);
 Except
  g.state := 3;
  If fr.mem <> Nil Then Begin
   FreeMem(fr.mem);
   fr.mem := Nil;
   fr.base := Nil;
  End;
  Raise;
 End;
 If LoopYielded Then Begin
  g.state := 1;
  res := v;
  Result := True;
 End
 Else Begin
  g.state := 3;
  g.retval := v;
  If fr.mem <> Nil Then Begin
   FreeMem(fr.mem);
   fr.mem := Nil;
   fr.base := Nil;
  End;
  Result := False;
 End;
End;

Function TPyGen.Next(Var r: TVal): Boolean;
Begin
 Result := GenResume(Self, vNone, r);
End;

{ ------------------------------------------------------------
  Chaine d'exception : traceback
  ------------------------------------------------------------ }
Procedure AddTraceback(exc: TPyObj; f: TFrame);
Var
 tb: TVal;
 l: TPyList;
 ln: Integer;
 e: TPyTuple;
 src: AnsiString;
Begin
 If exc.idict = Nil Then exc.idict := TPyDict.Make;
 If Not exc.idict.GetS('__tb__', tb) Then Begin
  tb := VObj(NewList);
  exc.idict.SetS('__tb__', tb);
 End;
 l := TPyList(tb.o);
 ln := LineForFrame(f);
 src := '';
 If (ln >= 1) And (ln <= Length(f.code.source)) Then
  src := Trim(f.code.source[ln - 1]);
 e := NewTuple(4);
 e.items[0] := VStr(f.code.filename);
 e.items[1] := VInt(ln);
 e.items[2] := VStr(f.code.name);
 e.items[3] := VStr(src);
 l.Add(VObj(e));
End;

Procedure PushVal(f: TFrame; Const v: TVal); Inline;
Begin
 f.sp^ := v;
 Inc(f.sp);
End;

Procedure RestoreExcInfo(f: TFrame; level: Integer);
Var
 sb: PVal;
Begin
 sb := f.base + f.nfast;
 If sb[level + 1].k = vkNone Then ExcInfo := vNone
 Else ExcInfo := sb[level + 1];
End;

{ Gestion d'une exception levee : renvoie True si un gestionnaire est actif }
Function UnwindException(entry: TFrame; exc: TPyObj): Boolean;
Var
 f: TFrame;
 b: TBlock;
 sb: PVal;
 cur: TVal;
 first: Boolean;
Begin
 first := (exc.idict = Nil) Or Not exc.idict.HasS('__tb__');
 If first And (exc.idict <> Nil) Then Begin
  If (ExcInfo.k = vkObj) And (ExcInfo.o <> exc) And
   Not exc.idict.HasS('__context__') Then
   exc.idict.SetS('__context__', ExcInfo);
 End;
 While True Do Begin
  f := CurFrame;
  AddTraceback(exc, f);
  sb := f.base + f.nfast;
  While f.nb > 0 Do Begin
   b := f.blocks[f.nb - 1];
   Dec(f.nb);
   If b.kind = 2 Then Begin
    RestoreExcInfo(f, b.level);
   End
   Else Begin
    f.sp := sb + b.level;
    f.blocks[f.nb].kind := 2;
    f.blocks[f.nb].level := b.level;
    f.blocks[f.nb].handler := 0;
    Inc(f.nb);
    PushVal(f, vNone);
    If ExcInfo.k = vkObj Then Begin
     PushVal(f, ExcInfo);
     PushVal(f, VObj(ExcInfo.o.cls));
    End
    Else Begin
     PushVal(f, vNone);
     PushVal(f, vNone);
    End;
    ExcInfo := VObj(exc);
    PushVal(f, vNone);
    PushVal(f, VObj(exc));
    PushVal(f, VObj(exc.cls));
    f.ip := b.handler;
    Result := True;
    Exit;
   End;
  End;
  { pas de gestionnaire : depile le cadre }
  If f = entry Then Begin
   Result := False;
   Exit;
  End;
  CurFrame := f.back;
  Dec(CallDepth);
  ReleaseFrame(f);
 End;
 cur := vNone;
End;

Procedure GcCollect; Forward;

Function ExecLoop: TVal; Forward;

Function Run(entry: TFrame): TVal;
Var
 thrown: TPyObj;
 saveFrame: TFrame;
 savedInfo: TVal;
Begin
 If NestDepth >= NestLimit Then Begin
  If entry.mem = Nil Then ReleaseFrame(entry);
  RaiseExc(exRecursionError, 'maximum recursion depth exceeded');
 End;
 Inc(NestDepth);
 Inc(CallDepth);
 saveFrame := CurFrame;
 savedInfo := ExcInfo;
 entry.isEntry := True;
 entry.back := saveFrame;
 CurFrame := entry;
 LoopYielded := False;
 Try
  Try
   If entry.throwExc <> Nil Then Begin
    thrown := entry.throwExc;
    entry.throwExc := Nil;
    If Not UnwindException(entry, thrown) Then
     Raise EPyError.Make(thrown);
   End;
   While True Do Begin
    Try
     Result := ExecLoop;
     Break;
    Except
     On E: EPyError Do Begin
      If Not UnwindException(entry, E.exc) Then Raise;
     End;
     On E: EAccessViolation Do Begin
      If Not UnwindException(entry, MakeExc(exSystemError,
       'internal error (access violation)')) Then
       RaiseExc(exSystemError, 'internal error (access violation)');
     End;
     On E: EOutOfMemory Do Begin
      If Not UnwindException(entry, MakeExc(exMemoryError, '')) Then
       RaiseExc(exMemoryError, '');
     End;
     On E: EStackOverflow Do Begin
      If Not UnwindException(entry, MakeExc(exRecursionError,
       'maximum recursion depth exceeded')) Then
       RaiseExc(exRecursionError, 'maximum recursion depth exceeded');
     End;
    End;
   End;
  Except
   { l'exception quitte ce niveau : nettoyage du cadre d'entree }
   CurFrame := saveFrame;
   If entry.mem = Nil Then ReleaseFrame(entry);
   ExcInfo := savedInfo;
   Raise;
  End;
 Finally
  Dec(NestDepth);
  Dec(CallDepth);
 End;
 CurFrame := saveFrame;
 If entry.mem = Nil Then ReleaseFrame(entry);
 If Not LoopYielded Then ExcInfo := savedInfo;
End;

{ ------------------------------------------------------------
  Machine virtuelle : fonctions d'appui
  ------------------------------------------------------------ }
Function ImportName(Const name: AnsiString; globals: TPyDict;
 Const fromlist: TVal; level: Integer): TVal; Forward;
Function ImportFromName(Const m: TVal; Const name: AnsiString): TVal; Forward;
Procedure DisplayHook(Const v: TVal); Forward;
Procedure ImportStar(Const m: TVal; target: TPyDict); Forward;

Function ExcMatch(Const exctype, check: TVal): Boolean;
Var
 i: Integer;
Begin
 If (check.k = vkObj) And (check.o Is TPyTuple) Then Begin
  For i := 0 To High(TPyTuple(check.o).items) Do
   If ExcMatch(exctype, TPyTuple(check.o).items[i]) Then Begin
    Result := True;
    Exit;
   End;
  Result := False;
  Exit;
 End;
 If Not ((check.k = vkObj) And (check.o Is TPyType) And
  IsExcClass(TPyType(check.o))) Then
  TypeErr('catching classes that do not inherit from BaseException is ' +
   'not allowed');
 Result := TypeIsSub(TPyType(exctype.o), TPyType(check.o));
End;

Function NormalizeExc(Const v: TVal; isCause: Boolean): TVal;
Begin
 If (v.k = vkObj) And (v.o Is TPyType) Then Begin
  If Not IsExcClass(TPyType(v.o)) Then
   TypeErr('exceptions must derive from BaseException');
  Result := CallValue(v, Nil, 0, Nil);
  Exit;
 End;
 If (v.k = vkObj) And TypeIsSub(v.o.cls, exBaseException) Then Begin
  Result := v;
  Exit;
 End;
 If isCause Then TypeErr('exception causes must derive from BaseException')
 Else TypeErr('exceptions must derive from BaseException');
 Result := vNone;
End;

Procedure DoRaise(Const excv, causev: TVal; nargs: Integer);
Var
 e, c: TVal;
Begin
 If nargs = 0 Then Begin
  If ExcInfo.k <> vkObj Then
   RaiseExc(exRuntimeError, 'No active exception to reraise');
  Raise EPyError.Make(ExcInfo.o);
 End;
 e := NormalizeExc(excv, False);
 If nargs = 2 Then Begin
  If causev.k = vkNone Then c := vNone Else c := NormalizeExc(causev, True);
  If e.o.idict = Nil Then e.o.idict := TPyDict.Make;
  e.o.idict.SetS('__cause__', c);
  e.o.idict.SetS('__suppress_context__', vTrue);
 End;
 Raise EPyError.Make(e.o);
End;

Procedure UnpackSeq(Const seq: TVal; sp: PVal; cnt: Integer);
{ ecrit cnt valeurs a partir de sp en ordre inverse (premier element en haut) }
Var
 items: TValArr;
 i: Integer;
Begin
 If (seq.k = vkObj) And (seq.o Is TPyTuple) Then Begin
  If Length(TPyTuple(seq.o).items) <> cnt Then Begin
   If Length(TPyTuple(seq.o).items) < cnt Then
    ValueErr('not enough values to unpack (expected ' + IntToStr(cnt) +
     ', got ' + IntToStr(Length(TPyTuple(seq.o).items)) + ')')
   Else ValueErr('too many values to unpack (expected ' + IntToStr(cnt) +
     ')');
  End;
  For i := 0 To cnt - 1 Do sp[cnt - 1 - i] := TPyTuple(seq.o).items[i];
  Exit;
 End;
 If (seq.k = vkObj) And (seq.o Is TPyList) And Not seq.o.cls.userdef Then Begin
  If TPyList(seq.o).cnt <> cnt Then Begin
   If TPyList(seq.o).cnt < cnt Then
    ValueErr('not enough values to unpack (expected ' + IntToStr(cnt) +
     ', got ' + IntToStr(TPyList(seq.o).cnt) + ')')
   Else ValueErr('too many values to unpack (expected ' + IntToStr(cnt) +
     ')');
  End;
  For i := 0 To cnt - 1 Do sp[cnt - 1 - i] := TPyList(seq.o).items[i];
  Exit;
 End;
 items := IterToArr(seq);
 If Length(items) <> cnt Then Begin
  If Length(items) < cnt Then
   ValueErr('not enough values to unpack (expected ' + IntToStr(cnt) +
    ', got ' + IntToStr(Length(items)) + ')')
  Else ValueErr('too many values to unpack (expected ' + IntToStr(cnt) + ')');
 End;
 For i := 0 To cnt - 1 Do sp[cnt - 1 - i] := items[i];
End;

Procedure MergeMapping(d: TPyDict; Const m: TVal; strict: Boolean);
Var
 i: Integer;
 keys, it, k: TVal;
 mo: TPyDict;
Begin
 If (m.k = vkObj) And (m.o Is TPyDict) Then Begin
  mo := TPyDict(m.o);
  For i := 0 To mo.nent - 1 Do
   If mo.ent[i].key.k <> vkNull Then Begin
    If strict And Not IsStrVal(mo.ent[i].key) Then
     TypeErr('keywords must be strings');
    d.SetItem(mo.ent[i].key, mo.ent[i].val);
   End;
  Exit;
 End;
 If (m.k <> vkObj) Or Not HasAttr(m, 'keys') Then
  TypeErr('argument after ** must be a mapping, not ' + TypeName(m));
 keys := Call0(GetAttr(m, 'keys'));
 it := IterOf(keys);
 While IterNextVal(it, k) Do d.SetItem(k, GetItem(m, k));
End;

Function PushPyCall(fn: TPyFunc; a: PVal; npos: Integer; kwv: PVal;
 kwNames: TPyTuple; kwd: TPyDict; Var res: TVal): Boolean;
Var
 code: TPyCode;
 fr: TFrame;
 gen: Boolean;
 i: Integer;
Begin
 code := fn.code;
 If CallDepth >= RecursionLimit Then
  RaiseExc(exRecursionError, 'maximum recursion depth exceeded');
 gen := (code.flags And CO_GENERATOR) <> 0;
 fr := NewFrame(code, fn, fn.globals, Nil, gen);
 If (kwNames = Nil) And (kwd = Nil) And (npos = code.argcount) And
  ((code.flags And (CO_VARARGS Or CO_VARKEYWORDS)) = 0) And
  (code.kwonly = 0) Then Begin
  For i := 0 To npos - 1 Do fr.base[i] := a[i];
 End
 Else Begin
  Try
   BindArgs(fn, fr, a, npos, kwv, kwNames, kwd);
  Except
   If gen Then Begin
    FreeMem(fr.mem);
    fr.mem := Nil;
    fr.Free;
   End
   Else ReleaseFrame(fr);
   Raise;
  End;
 End;
 If (Length(code.cellvars) > 0) Or (Length(code.freevars) > 0) Then
  SetupCells(fr, fn);
 If gen Then Begin
  res := MakeGenerator(fr, fn);
  Result := False;
  Exit;
 End;
 fr.back := CurFrame;
 CurFrame := fr;
 Inc(CallDepth);
 Result := True;
End;

Function MakeFunctionObj(codeV, qualV: TVal; flags: Integer; sp: PVal): TPyFunc;
Var
 fn: TPyFunc;
 code: TPyCode;
 k: Integer;
 clos: TPyTuple;
 i: Integer;
Begin
 code := TPyCode(codeV.o);
 fn := TPyFunc.Create(tyFunction);
 fn.code := code;
 fn.globals := CurFrame.globals;
 fn.name := code.name;
 fn.qualname := StrOf(qualV);
 fn.doc := vNone;
 If (Length(code.consts) > 0) And IsStrVal(code.consts[0]) And
  ((code.flags And CO_OPTIMIZED) <> 0) Then fn.doc := code.consts[0];
 k := 0;
 If (flags And 8) <> 0 Then Begin
  clos := TPyTuple(sp[k].o);
  Inc(k);
  SetLength(fn.closure, Length(clos.items));
  For i := 0 To High(clos.items) Do fn.closure[i] := TPyCell(clos.items[i].o);
 End;
 If (flags And 4) <> 0 Then Inc(k);
 If (flags And 2) <> 0 Then Begin
  fn.kwdefaults := TPyDict(sp[k].o);
  Inc(k);
 End;
 If (flags And 1) <> 0 Then Begin
  fn.defaults := TPyTuple(sp[k].o);
  Inc(k);
 End;
 Result := fn;
End;

Function ConvertForFormat(Const v: TVal; conv: Integer): TVal;
Begin
 Case conv Of
  1: Result := VStr(StrVal(v));
  2: Result := VStr(ReprVal(v));
  3: Result := VStr(AsciiVal(v));
 Else Result := v;
 End;
End;

Procedure GcCollect;
Var
 i, j, live: Integer;
 f: TFrame;
 o: TPyObj;
Begin
 GcSP := 0;
 For i := 0 To GcNRoots - 1 Do MarkObj(GcRoots[i]);
 MarkVal(ExcInfo);
 f := CurFrame;
 While f <> Nil Do Begin
  f.MarkAll;
  f := f.back;
 End;
 While GcSP > 0 Do Begin
  Dec(GcSP);
  o := GcStack[GcSP];
  o.MarkKids;
 End;
 j := 0;
 For i := 0 To GcCount - 1 Do Begin
  o := GcObjs[i];
  If o.gcmark Then Begin
   o.gcmark := False;
   GcObjs[j] := o;
   Inc(j);
  End
  Else o.Free;
 End;
 For i := j To GcCount - 1 Do GcObjs[i] := Nil;
 GcCount := j;
 live := j;
 GcLastLive := live;
 For i := 0 To GcNRoots - 1 Do GcRoots[i].gcmark := False;
End;

Function GetItemFast(Const o, k: TVal): TVal; Inline;
Begin
 If (o.k = vkObj) And (k.k = vkInt) Then Begin
  If (o.o.ClassType = TPyList) And (Not o.o.cls.userdef) Then Begin
   If (k.i >= 0) And (k.i < TPyList(o.o).cnt) Then Begin
    Result := TPyList(o.o).items[k.i];
    Exit;
   End;
  End
  Else If (o.o.ClassType = TPyTuple) And (Not o.o.cls.userdef) Then Begin
   If (k.i >= 0) And (k.i < Length(TPyTuple(o.o).items)) Then Begin
    Result := TPyTuple(o.o).items[k.i];
    Exit;
   End;
  End;
 End;
 Result := GetItem(o, k);
End;

{ ------------------------------------------------------------
  Boucle d'interpretation
  ------------------------------------------------------------ }
Var
 BinIdx: Array[0..255] Of ShortInt;

Procedure InitBinIdx;
Var
 i: Integer;
Begin
 For i := 0 To 255 Do BinIdx[i] := -1;
 BinIdx[BINARY_MATRIX_MULTIPLY] := 12;
 BinIdx[BINARY_POWER] := 6;
 BinIdx[BINARY_MULTIPLY] := 2;
 BinIdx[BINARY_MODULO] := 5;
 BinIdx[BINARY_ADD] := 0;
 BinIdx[BINARY_SUBTRACT] := 1;
 BinIdx[BINARY_FLOOR_DIVIDE] := 4;
 BinIdx[BINARY_TRUE_DIVIDE] := 3;
 BinIdx[INPLACE_FLOOR_DIVIDE] := 4;
 BinIdx[INPLACE_TRUE_DIVIDE] := 3;
 BinIdx[INPLACE_ADD] := 0;
 BinIdx[INPLACE_SUBTRACT] := 1;
 BinIdx[INPLACE_MULTIPLY] := 2;
 BinIdx[INPLACE_MODULO] := 5;
 BinIdx[BINARY_LSHIFT] := 7;
 BinIdx[BINARY_RSHIFT] := 8;
 BinIdx[BINARY_AND] := 9;
 BinIdx[BINARY_XOR] := 11;
 BinIdx[BINARY_OR] := 10;
 BinIdx[INPLACE_POWER] := 6;
 BinIdx[INPLACE_LSHIFT] := 7;
 BinIdx[INPLACE_RSHIFT] := 8;
 BinIdx[INPLACE_AND] := 9;
 BinIdx[INPLACE_XOR] := 11;
 BinIdx[INPLACE_OR] := 10;
End;

Function ExecLoop: TVal;
Var
 f: TFrame;
 code: TPyCode;
 cp: PByte;
 ip, op, arg, ext: Integer;
 sp, fast, kst, stackBase: PVal;
 nameObjs: Array Of TPyStr;
 a, b, c, r: TVal;
 i, n, npos, nkw, bi, lvl: Integer;
 nm: TPyStr;
 d: TPyDict;
 lst: TPyList;
 tup: TPyTuple;
 st: TPySet;
 fnobj: TPyFunc;
 blk: TBlock;
 ok, pushed: Boolean;
 s: AnsiString;
 cell: TPyCell;
 t: TPyType;
 x, y: Int64;
 cmp: Integer;
 meth: TVal;
 kwd: TPyDict;
 items: TValArr;
 key: TVal;
 vv: TVal;
 ft: TFrame;
Begin
 While True Do Begin
  f := CurFrame;
  code := f.code;
  cp := @code.co[0];
  ip := f.ip;
  sp := f.sp;
  fast := f.base;
  stackBase := f.base + f.nfast;
  If Length(code.consts) > 0 Then kst := @code.consts[0] Else kst := Nil;
  nameObjs := code.nameObjs;
  While True Do Begin
   f.lasti := ip;
   op := cp[ip];
   arg := cp[ip + 1];
   Inc(ip, 2);
   If op = EXTENDED_ARG Then Begin
    ext := arg;
    While op = EXTENDED_ARG Do Begin
     op := cp[ip];
     arg := cp[ip + 1];
     Inc(ip, 2);
     If op = EXTENDED_ARG Then ext := (ext Shl 8) Or arg;
    End;
    arg := (ext Shl 8) Or arg;
   End;
   Case op Of
    NOP: ;
    POP_TOP: Dec(sp);
    ROT_TWO: Begin
      a := sp[-1];
      sp[-1] := sp[-2];
      sp[-2] := a;
     End;
    ROT_THREE: Begin
      a := sp[-1];
      sp[-1] := sp[-2];
      sp[-2] := sp[-3];
      sp[-3] := a;
     End;
    ROT_FOUR: Begin
      a := sp[-1];
      sp[-1] := sp[-2];
      sp[-2] := sp[-3];
      sp[-3] := sp[-4];
      sp[-4] := a;
     End;
    DUP_TOP: Begin
      sp[0] := sp[-1];
      Inc(sp);
     End;
    DUP_TOP_TWO: Begin
      sp[0] := sp[-2];
      sp[1] := sp[-1];
      Inc(sp, 2);
     End;
    UNARY_POSITIVE: sp[-1] := UnaryPos(sp[-1]);
    UNARY_NEGATIVE: Begin
      If sp[-1].k = vkInt Then Begin
       If sp[-1].i <> Low(Int64) Then sp[-1].i := -sp[-1].i
       Else sp[-1] := UnaryNeg(sp[-1]);
      End
      Else If sp[-1].k = vkFloat Then sp[-1].d := -sp[-1].d
      Else sp[-1] := UnaryNeg(sp[-1]);
     End;
    UNARY_NOT: Begin
      If sp[-1].k = vkBool Then sp[-1].i := 1 - sp[-1].i
      Else sp[-1] := VBool(Not IsTrue(sp[-1]));
     End;
    UNARY_INVERT: sp[-1] := UnaryInvert(sp[-1]);
    BINARY_ADD, INPLACE_ADD: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If (a.k = vkInt) And (b.k = vkInt) Then Begin
       x := a.i + b.i;
       If ((a.i Xor x) And (b.i Xor x)) >= 0 Then sp[-1] := VInt(x)
       Else sp[-1] := IntAdd(a, b);
      End
      Else If (a.k = vkFloat) And (b.k = vkFloat) Then
       sp[-1] := VFloat(a.d + b.d)
      Else If (a.k = vkObj) And (b.k = vkObj) And (a.o.ClassType = TPyStr)
       And (b.o.ClassType = TPyStr) And Not a.o.cls.userdef Then
       sp[-1] := VStr(TPyStr(a.o).s + TPyStr(b.o).s)
      Else If op = INPLACE_ADD Then sp[-1] := InplaceOp(bopAdd, a, b)
      Else sp[-1] := BinaryOp(bopAdd, a, b);
     End;
    BINARY_SUBTRACT, INPLACE_SUBTRACT: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If (a.k = vkInt) And (b.k = vkInt) Then Begin
       x := a.i - b.i;
       If ((a.i Xor b.i) And (a.i Xor x)) >= 0 Then sp[-1] := VInt(x)
       Else sp[-1] := IntSub(a, b);
      End
      Else If (a.k = vkFloat) And (b.k = vkFloat) Then
       sp[-1] := VFloat(a.d - b.d)
      Else If op = INPLACE_SUBTRACT Then sp[-1] := InplaceOp(bopSub, a, b)
      Else sp[-1] := BinaryOp(bopSub, a, b);
     End;
    BINARY_MULTIPLY, INPLACE_MULTIPLY: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If (a.k = vkInt) And (b.k = vkInt) Then sp[-1] := IntMul(a, b)
      Else If (a.k = vkFloat) And (b.k = vkFloat) Then
       sp[-1] := VFloat(a.d * b.d)
      Else If op = INPLACE_MULTIPLY Then sp[-1] := InplaceOp(bopMul, a, b)
      Else sp[-1] := BinaryOp(bopMul, a, b);
     End;
    BINARY_TRUE_DIVIDE, BINARY_FLOOR_DIVIDE, BINARY_MODULO, BINARY_POWER,
    BINARY_LSHIFT, BINARY_RSHIFT, BINARY_AND, BINARY_OR, BINARY_XOR,
    BINARY_MATRIX_MULTIPLY: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If (op = BINARY_MODULO) And (a.k = vkInt) And (b.k = vkInt) And
       (b.i > 0) And (a.i >= 0) Then sp[-1] := VInt(a.i Mod b.i)
      Else sp[-1] := BinaryOp(BinIdx[op], a, b);
     End;
    INPLACE_TRUE_DIVIDE, INPLACE_FLOOR_DIVIDE, INPLACE_MODULO,
    INPLACE_POWER, INPLACE_LSHIFT, INPLACE_RSHIFT, INPLACE_AND,
    INPLACE_XOR, INPLACE_OR, INPLACE_MATRIX_MULTIPLY: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If op = INPLACE_MATRIX_MULTIPLY Then bi := bopMatMul
      Else bi := BinIdx[op];
      sp[-1] := InplaceOp(bi, a, b);
     End;
    BINARY_SUBSCR: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      sp[-1] := GetItemFast(a, b);
     End;
    STORE_SUBSCR: Begin
      b := sp[-1];
      a := sp[-2];
      c := sp[-3];
      Dec(sp, 3);
      If (a.k = vkObj) And (b.k = vkInt) And (a.o.ClassType = TPyList) And
       Not a.o.cls.userdef And (b.i >= 0) And (b.i < TPyList(a.o).cnt) Then
       TPyList(a.o).items[b.i] := c
      Else SetItem(a, b, c);
     End;
    DELETE_SUBSCR: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp, 2);
      DelItem(a, b);
     End;
    GET_ITER: sp[-1] := IterOf(sp[-1]);
    GET_YIELD_FROM_ITER: Begin
      If Not ((sp[-1].k = vkObj) And (sp[-1].o Is TPyGen)) Then
       sp[-1] := IterOf(sp[-1]);
     End;
    PRINT_EXPR: Begin
      a := sp[-1];
      Dec(sp);
      f.sp := sp;
      DisplayHook(a);
     End;
    LOAD_BUILD_CLASS: Begin
      If Not BuiltinsDict.GetS('__build_class__', a) Then
       RaiseExc(exNameError, '__build_class__ not found');
      sp^ := a;
      Inc(sp);
     End;
    YIELD_VALUE: Begin
      a := sp[-1];
      Dec(sp);
      f.ip := ip;
      f.sp := sp;
      LoopYielded := True;
      Result := a;
      Exit;
     End;
    YIELD_FROM: Begin
      a := sp[-1];
      Dec(sp);
      b := sp[-1];
      f.sp := sp;
      If (b.k = vkObj) And (b.o Is TPyGen) Then
       pushed := GenResume(TPyGen(b.o), a, r)
      Else If a.k = vkNone Then pushed := IterNextVal(b, r)
      Else Begin
       r := Call1(GetAttr(b, 'send'), a);
       pushed := True;
      End;
      If pushed Then Begin
       f.ip := ip - 2;
       f.sp := sp;
       LoopYielded := True;
       Result := r;
       Exit;
      End;
      If (b.k = vkObj) And (b.o Is TPyGen) Then r := TPyGen(b.o).retval
      Else r := vNone;
      If r.k = vkNull Then r := vNone;
      sp[-1] := r;
     End;
    RETURN_VALUE: Begin
      a := sp[-1];
      Dec(sp);
      If f.initInst.k <> vkNull Then Begin
       If a.k <> vkNone Then
        TypeErr('__init__() should return None, not ''' + TypeName(a) + '''');
       a := f.initInst;
      End;
      If f.isEntry Then Begin
       LoopYielded := False;
       Result := a;
       Exit;
      End;
      ft := f;
      f := f.back;
      CurFrame := f;
      Dec(CallDepth);
      ReleaseFrame(ft);
      f.sp^ := a;
      Inc(f.sp);
      Break;
     End;
    IMPORT_STAR: Begin
      a := sp[-1];
      Dec(sp);
      If f.locals <> Nil Then ImportStar(a, f.locals)
      Else ImportStar(a, f.globals);
     End;
    SETUP_ANNOTATIONS: Begin
      If f.locals <> Nil Then d := f.locals Else d := f.globals;
      If Not d.HasS('__annotations__') Then
       d.SetS('__annotations__', VObj(TPyDict.Make));
     End;
    POP_BLOCK: Dec(f.nb);
    BEGIN_FINALLY: Begin
      sp^ := vNone;
      Inc(sp);
     End;
    CALL_FINALLY: Begin
      sp^ := VInt(ip);
      Inc(sp);
      Inc(ip, arg);
     End;
    END_FINALLY: Begin
      a := sp[-1];
      Dec(sp);
      If a.k = vkNone Then
      Else If a.k = vkInt Then ip := a.i
      Else Begin
       b := sp[-1];
       Dec(sp, 2);
       f.sp := sp;
       If (b.k = vkObj) Then Raise EPyError.Make(b.o);
       RaiseExc(exSystemError, 'bad END_FINALLY state');
      End;
     End;
    POP_EXCEPT: Begin
      Dec(f.nb);
      blk := f.blocks[f.nb];
      sp := stackBase + blk.level + 3;
      If sp[-2].k = vkNone Then ExcInfo := vNone Else ExcInfo := sp[-2];
      Dec(sp, 3);
     End;
    POP_FINALLY: Begin
      If arg <> 0 Then Begin
       a := sp[-1];
       Dec(sp);
      End;
      b := sp[-1];
      If (b.k = vkNone) Or (b.k = vkInt) Then Dec(sp)
      Else Begin
       Dec(sp, 3);
       Dec(f.nb);
       blk := f.blocks[f.nb];
       sp := stackBase + blk.level + 3;
       If sp[-2].k = vkNone Then ExcInfo := vNone Else ExcInfo := sp[-2];
       Dec(sp, 3);
      End;
      If arg <> 0 Then Begin
       sp^ := a;
       Inc(sp);
      End;
     End;
    SETUP_FINALLY: Begin
      f.blocks[f.nb].kind := 1;
      f.blocks[f.nb].handler := ip + arg;
      f.blocks[f.nb].level := sp - stackBase;
      Inc(f.nb);
     End;
    SETUP_WITH: Begin
      a := sp[-1];
      t := TypeOf(a);
      If Not LookupType(t, '__enter__', meth) Then
       RaiseExc(exAttributeError, '__enter__');
      If Not LookupType(t, '__exit__', c) Then
       RaiseExc(exAttributeError, '__exit__');
      sp[-1] := BindMethod(c, a);
      r := Call1(meth, a);
      f.blocks[f.nb].kind := 1;
      f.blocks[f.nb].handler := ip + arg;
      f.blocks[f.nb].level := sp - stackBase;
      Inc(f.nb);
      sp^ := r;
      Inc(sp);
     End;
    WITH_CLEANUP_START: Begin
      a := sp[-1];
      If a.k = vkNone Then Begin
       Dec(sp);
       meth := sp[-1];
       sp[-1] := vNone;
       f.sp := sp;
       r := Call3Args(meth, vNone, vNone, vNone);
       sp^ := vNone;
       sp[1] := r;
       Inc(sp, 2);
      End
      Else If a.k = vkInt Then Begin
       Dec(sp);
       meth := sp[-1];
       sp[-1] := a;
       f.sp := sp;
       r := Call3Args(meth, vNone, vNone, vNone);
       sp^ := vNone;
       sp[1] := r;
       Inc(sp, 2);
      End
      Else Begin
       { exception : type=sp[-1], val=sp[-2], tb=sp[-3] }
       meth := sp[-7];
       b := sp[-1];
       c := sp[-2];
       vv := sp[-3];
       sp[-7] := sp[-6];
       sp[-6] := sp[-5];
       sp[-5] := sp[-4];
       sp[-4] := vNull;
       Dec(f.blocks[f.nb - 1].level);
       f.sp := sp;
       r := Call3Args(meth, b, c, vv);
       sp^ := b;
       sp[1] := r;
       Inc(sp, 2);
      End;
     End;
    WITH_CLEANUP_FINISH: Begin
      r := sp[-1];
      a := sp[-2];
      Dec(sp, 2);
      If a.k <> vkNone Then Begin
       If IsTrue(r) Then Begin
        Dec(f.nb);
        blk := f.blocks[f.nb];
        sp := stackBase + blk.level + 3;
        If sp[-2].k = vkNone Then ExcInfo := vNone Else ExcInfo := sp[-2];
        Dec(sp, 3);
        sp^ := vNone;
        Inc(sp);
       End;
      End;
     End;
    STORE_NAME: Begin
      nm := nameObjs[arg];
      DictSetO(f.locals, nm, sp[-1]);
      Dec(sp);
     End;
    DELETE_NAME: Begin
      nm := nameObjs[arg];
      key := VObj(nm);
      If Not f.locals.DelItem(key) Then
       RaiseExc(exNameError, 'name ''' + nm.s + ''' is not defined');
     End;
    UNPACK_SEQUENCE: Begin
      a := sp[-1];
      Dec(sp);
      UnpackSeq(a, sp, arg);
      Inc(sp, arg);
     End;
    UNPACK_EX: Begin
      a := sp[-1];
      Dec(sp);
      items := IterToArr(a);
      n := arg And 255;
      i := arg Shr 8;
      If Length(items) < n + i Then
       ValueErr('not enough values to unpack (expected at least ' +
        IntToStr(n + i) + ', got ' + IntToStr(Length(items)) + ')');
      { empile : apres (premier au sommet) }
      For bi := 0 To i - 1 Do
       sp[bi] := items[Length(items) - 1 - bi];
      lst := NewList;
      For bi := n To Length(items) - i - 1 Do lst.Add(items[bi]);
      sp[i] := VObj(lst);
      For bi := 0 To n - 1 Do sp[i + 1 + (n - 1 - bi)] := items[bi];
      Inc(sp, n + i + 1);
     End;
    FOR_ITER: Begin
      a := sp[-1];
      If a.o.ClassType = TRangeIter Then Begin
       If ((TRangeIter(a.o).step > 0) And (TRangeIter(a.o).cur <
        TRangeIter(a.o).stop)) Or ((TRangeIter(a.o).step < 0) And
        (TRangeIter(a.o).cur > TRangeIter(a.o).stop)) Then Begin
        sp^ := VInt(TRangeIter(a.o).cur);
        Inc(TRangeIter(a.o).cur, TRangeIter(a.o).step);
        Inc(sp);
       End
       Else Begin
        Dec(sp);
        Inc(ip, arg);
       End;
      End
      Else Begin
       f.sp := sp;
       If IterNextVal(a, r) Then Begin
        sp^ := r;
        Inc(sp);
       End
       Else Begin
        Dec(sp);
        Inc(ip, arg);
       End;
      End;
     End;
    STORE_ATTR: Begin
      a := sp[-1];
      b := sp[-2];
      Dec(sp, 2);
      If (a.k = vkObj) And (a.o.ClassType = TPyObj) And (a.o.idict <> Nil)
       And Not a.o.cls.userdef Then SetAttrO(a, nameObjs[arg], b)
      Else SetAttrO(a, nameObjs[arg], b);
     End;
    DELETE_ATTR: Begin
      a := sp[-1];
      Dec(sp);
      DelAttrO(a, nameObjs[arg]);
     End;
    STORE_GLOBAL: Begin
      DictSetO(f.globals, nameObjs[arg], sp[-1]);
      Dec(sp);
     End;
    DELETE_GLOBAL: Begin
      key := VObj(nameObjs[arg]);
      If Not f.globals.DelItem(key) Then
       RaiseExc(exNameError, 'name ''' + nameObjs[arg].s +
        ''' is not defined');
     End;
    LOAD_CONST: Begin
      sp^ := kst[arg];
      Inc(sp);
     End;
    LOAD_NAME: Begin
      nm := nameObjs[arg];
      If DictGetO(f.locals, nm, r) Then
      Else If DictGetO(f.globals, nm, r) Then
      Else If DictGetO(f.builtins, nm, r) Then
      Else RaiseExc(exNameError, 'name ''' + nm.s + ''' is not defined');
      sp^ := r;
      Inc(sp);
     End;
    LOAD_GLOBAL: Begin
      nm := nameObjs[arg];
      If DictGetO(f.globals, nm, r) Then
      Else If DictGetO(f.builtins, nm, r) Then
      Else Begin
       { module sans __builtins__ : nom introuvable }
       RaiseExc(exNameError, 'name ''' + nm.s + ''' is not defined');
      End;
      sp^ := r;
      Inc(sp);
     End;
    LOAD_FAST: Begin
      r := fast[arg];
      If r.k = vkNull Then
       RaiseExc(exUnboundLocal, 'local variable ''' + code.varnames[arg] +
        ''' referenced before assignment');
      sp^ := r;
      Inc(sp);
     End;
    STORE_FAST: Begin
      fast[arg] := sp[-1];
      Dec(sp);
     End;
    DELETE_FAST: Begin
      If fast[arg].k = vkNull Then
       RaiseExc(exUnboundLocal, 'local variable ''' + code.varnames[arg] +
        ''' referenced before assignment');
      fast[arg].k := vkNull;
     End;
    LOAD_CLOSURE: Begin
      sp^ := fast[Length(code.varnames) + arg];
      Inc(sp);
     End;
    LOAD_DEREF, LOAD_CLASSDEREF: Begin
      cell := TPyCell(fast[Length(code.varnames) + arg].o);
      If op = LOAD_CLASSDEREF Then Begin
       { les classes cherchent d'abord dans leur espace de noms }
       n := arg - Length(code.cellvars);
       If n >= 0 Then s := code.freevars[n] Else s := code.cellvars[arg];
       nm := InternStr(s);
       If (f.locals <> Nil) And DictGetO(f.locals, nm, r) Then Begin
        sp^ := r;
        Inc(sp);
        Continue;
       End;
      End;
      r := cell.v;
      If r.k = vkNull Then Begin
       n := arg - Length(code.cellvars);
       If n >= 0 Then
        RaiseExc(exNameError, 'free variable ''' + code.freevars[n] +
         ''' referenced before assignment in enclosing scope')
       Else
        RaiseExc(exUnboundLocal, 'local variable ''' + code.cellvars[arg] +
         ''' referenced before assignment');
      End;
      sp^ := r;
      Inc(sp);
     End;
    STORE_DEREF: Begin
      TPyCell(fast[Length(code.varnames) + arg].o).v := sp[-1];
      Dec(sp);
     End;
    DELETE_DEREF: Begin
      cell := TPyCell(fast[Length(code.varnames) + arg].o);
      If cell.v.k = vkNull Then
       RaiseExc(exUnboundLocal, 'local variable referenced before ' +
        'assignment');
      cell.v.k := vkNull;
     End;
    BUILD_TUPLE: Begin
      tup := NewTuple(arg);
      For i := 0 To arg - 1 Do tup.items[i] := sp[i - arg];
      Dec(sp, arg);
      sp^ := VObj(tup);
      Inc(sp);
     End;
    BUILD_LIST: Begin
      lst := NewList;
      SetLength(lst.items, arg);
      For i := 0 To arg - 1 Do lst.items[i] := sp[i - arg];
      lst.cnt := arg;
      Dec(sp, arg);
      sp^ := VObj(lst);
      Inc(sp);
     End;
    BUILD_SET: Begin
      st := TPySet.Make(False);
      For i := 0 To arg - 1 Do st.Add(sp[i - arg]);
      Dec(sp, arg);
      sp^ := VObj(st);
      Inc(sp);
     End;
    BUILD_MAP: Begin
      d := TPyDict.Make;
      For i := 0 To arg - 1 Do d.SetItem(sp[2 * i - 2 * arg],
       sp[2 * i - 2 * arg + 1]);
      Dec(sp, 2 * arg);
      sp^ := VObj(d);
      Inc(sp);
     End;
    BUILD_CONST_KEY_MAP: Begin
      tup := TPyTuple(sp[-1].o);
      d := TPyDict.Make;
      For i := 0 To arg - 1 Do d.SetItem(tup.items[i], sp[i - 1 - arg]);
      Dec(sp, arg + 1);
      sp^ := VObj(d);
      Inc(sp);
     End;
    BUILD_STRING: Begin
      s := '';
      For i := 0 To arg - 1 Do s := s + TPyStr(sp[i - arg].o).s;
      Dec(sp, arg);
      sp^ := VStr(s);
      Inc(sp);
     End;
    BUILD_SLICE: Begin
      If arg = 3 Then Begin
       r := NewSlice(sp[-3], sp[-2], sp[-1]);
       Dec(sp, 3);
      End
      Else Begin
       r := NewSlice(sp[-2], sp[-1], vNone);
       Dec(sp, 2);
      End;
      sp^ := r;
      Inc(sp);
     End;
    BUILD_LIST_UNPACK, BUILD_TUPLE_UNPACK, BUILD_TUPLE_UNPACK_WITH_CALL,
    BUILD_SET_UNPACK: Begin
      lst := NewList;
      For i := 0 To arg - 1 Do Begin
       items := IterToArr(sp[i - arg]);
       For bi := 0 To High(items) Do lst.Add(items[bi]);
      End;
      Dec(sp, arg);
      If op = BUILD_LIST_UNPACK Then r := VObj(lst)
      Else If op = BUILD_SET_UNPACK Then Begin
       st := TPySet.Make(False);
       For i := 0 To lst.cnt - 1 Do st.Add(lst.items[i]);
       r := VObj(st);
      End
      Else Begin
       tup := NewTuple(lst.cnt);
       For i := 0 To lst.cnt - 1 Do tup.items[i] := lst.items[i];
       r := VObj(tup);
      End;
      sp^ := r;
      Inc(sp);
     End;
    BUILD_MAP_UNPACK, BUILD_MAP_UNPACK_WITH_CALL: Begin
      d := TPyDict.Make;
      For i := 0 To arg - 1 Do
       MergeMapping(d, sp[i - arg], op = BUILD_MAP_UNPACK_WITH_CALL);
      Dec(sp, arg);
      sp^ := VObj(d);
      Inc(sp);
     End;
    LOAD_ATTR: Begin
      a := sp[-1];
      nm := nameObjs[arg];
      If Not GetAttrOpt(a, nm, r) Then RaiseAttrError(a, nm.s);
      sp[-1] := r;
     End;
    LOAD_METHOD: Begin
      a := sp[-1];
      nm := nameObjs[arg];
      ok := False;
      If a.k = vkObj Then Begin
       If (Not (a.o Is TPyType)) And (Not (a.o Is TPySuper)) And
        (Not (a.o Is TPyModule)) And LookupTypeO(a.o.cls, nm, meth) And
        (meth.k = vkObj) And ((meth.o Is TPyFunc) Or
        ((meth.o Is TPyBuiltin) And TPyBuiltin(meth.o).isMethod)) Then Begin
        If (a.o.idict = Nil) Or Not DictGetO(a.o.idict, nm, r) Then ok := True;
       End;
      End
      Else If LookupTypeO(TypeOf(a), nm, meth) And (meth.k = vkObj) And
       ((meth.o Is TPyFunc) Or ((meth.o Is TPyBuiltin) And
       TPyBuiltin(meth.o).isMethod)) Then ok := True;
      If ok Then Begin
       sp[-1] := meth;
       sp^ := a;
       Inc(sp);
      End
      Else Begin
       If Not GetAttrOpt(a, nm, r) Then RaiseAttrError(a, nm.s);
       sp[-1] := vNull;
       sp^ := r;
       Inc(sp);
      End;
     End;
    COMPARE_OP: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      If (a.k = vkInt) And (b.k = vkInt) And (arg <= 5) Then Begin
       Case arg Of
        0: ok := a.i < b.i;
        1: ok := a.i <= b.i;
        2: ok := a.i = b.i;
        3: ok := a.i <> b.i;
        4: ok := a.i > b.i;
       Else ok := a.i >= b.i;
       End;
       sp[-1] := VBool(ok);
      End
      Else If (a.k = vkFloat) And (b.k = vkFloat) And (arg <= 5) Then Begin
       Case arg Of
        0: ok := a.d < b.d;
        1: ok := a.d <= b.d;
        2: ok := a.d = b.d;
        3: ok := a.d <> b.d;
        4: ok := a.d > b.d;
       Else ok := a.d >= b.d;
       End;
       sp[-1] := VBool(ok);
      End
      Else Begin
       f.sp := sp;
       Case arg Of
        0..5: sp[-1] := VBool(ValCompare(a, b, arg));
        6: sp[-1] := VBool(ContainsOp(b, a));
        7: sp[-1] := VBool(Not ContainsOp(b, a));
        8, 9: Begin
          If a.k <> b.k Then ok := False
          Else If a.k = vkObj Then ok := a.o = b.o
          Else If a.k = vkNone Then ok := True
          Else If a.k = vkFloat Then ok := PQWord(@a.d)^ = PQWord(@b.d)^
          Else ok := a.i = b.i;
          If arg = 9 Then ok := Not ok;
          sp[-1] := VBool(ok);
         End;
       Else
        sp[-1] := VBool(ExcMatch(a, b));
       End;
      End;
     End;
    IMPORT_NAME: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp);
      f.sp := sp;
      sp[-1] := ImportName(nameObjs[arg].s, f.globals, b, a.i);
     End;
    IMPORT_FROM: Begin
      a := sp[-1];
      f.sp := sp;
      r := ImportFromName(a, nameObjs[arg].s);
      sp^ := r;
      Inc(sp);
     End;
    JUMP_FORWARD: Inc(ip, arg);
    JUMP_ABSOLUTE: Begin
      ip := arg;
      If (GcCount - GcLastLive > GcThreshold) And (NestDepth = 1) And
       GcEnabled Then Begin
       f.sp := sp;
       GcCollect;
      End;
      If PendingInterrupt Then Begin
       PendingInterrupt := False;
       f.ip := ip;
       RaiseExc(exKeyboardInterrupt, '');
      End;
     End;
    JUMP_IF_FALSE_OR_POP: Begin
      If sp[-1].k = vkBool Then ok := sp[-1].i <> 0
      Else ok := IsTrue(sp[-1]);
      If Not ok Then ip := arg Else Dec(sp);
     End;
    JUMP_IF_TRUE_OR_POP: Begin
      If sp[-1].k = vkBool Then ok := sp[-1].i <> 0
      Else ok := IsTrue(sp[-1]);
      If ok Then ip := arg Else Dec(sp);
     End;
    POP_JUMP_IF_FALSE: Begin
      If sp[-1].k = vkBool Then ok := sp[-1].i <> 0
      Else ok := IsTrue(sp[-1]);
      Dec(sp);
      If Not ok Then ip := arg;
     End;
    POP_JUMP_IF_TRUE: Begin
      If sp[-1].k = vkBool Then ok := sp[-1].i <> 0
      Else ok := IsTrue(sp[-1]);
      Dec(sp);
      If ok Then ip := arg;
     End;
    RAISE_VARARGS: Begin
      Case arg Of
       0: Begin
         f.sp := sp;
         DoRaise(vNone, vNone, 0);
        End;
       1: Begin
         a := sp[-1];
         Dec(sp);
         f.sp := sp;
         DoRaise(a, vNone, 1);
        End;
      Else
       b := sp[-1];
       a := sp[-2];
       Dec(sp, 2);
       f.sp := sp;
       DoRaise(a, b, 2);
      End;
     End;
    CALL_FUNCTION: Begin
      If (GcCount - GcLastLive > GcThreshold) And (NestDepth = 1) And
       GcEnabled Then Begin
       f.sp := sp;
       GcCollect;
      End;
      a := sp[-arg - 1];
      If (a.k = vkObj) And (a.o.ClassType = TPyFunc) Then Begin
       f.ip := ip;
       fnobj := TPyFunc(a.o);
       f.sp := sp - arg - 1;
       If PushPyCall(fnobj, sp - arg, arg, Nil, Nil, Nil, r) Then Begin
        Break;
       End;
       sp := f.sp;
       sp^ := r;
       Inc(sp);
      End
      Else Begin
       f.sp := sp;
       r := CallValue(a, sp - arg, arg, Nil);
       Dec(sp, arg + 1);
       sp^ := r;
       Inc(sp);
      End;
     End;
    CALL_METHOD: Begin
      If (GcCount - GcLastLive > GcThreshold) And (NestDepth = 1) And
       GcEnabled Then Begin
       f.sp := sp;
       GcCollect;
      End;
      a := sp[-arg - 2];
      If a.k = vkNull Then Begin
       { (NULL, callable) }
       b := sp[-arg - 1];
       npos := arg;
       n := arg;
       i := 1;
      End
      Else Begin
       b := a;
       npos := arg + 1;
       n := arg + 1;
       i := 0;
      End;
      If (b.k = vkObj) And (b.o.ClassType = TPyFunc) Then Begin
       f.ip := ip;
       f.sp := sp - arg - 2;
       If PushPyCall(TPyFunc(b.o), sp - npos, npos, Nil, Nil, Nil, r) Then
        Break;
       sp := f.sp;
       sp^ := r;
       Inc(sp);
      End
      Else Begin
       f.sp := sp;
       r := CallValue(b, sp - npos, npos, Nil);
       Dec(sp, arg + 2);
       sp^ := r;
       Inc(sp);
      End;
      lvl := i;
     End;
    CALL_FUNCTION_KW: Begin
      tup := TPyTuple(sp[-1].o);
      nkw := Length(tup.items);
      npos := arg - nkw;
      a := sp[-arg - 2];
      If (a.k = vkObj) And (a.o.ClassType = TPyFunc) Then Begin
       f.ip := ip;
       f.sp := sp - arg - 2;
       If PushPyCall(TPyFunc(a.o), sp - 1 - arg, npos, sp - 1 - nkw, tup,
        Nil, r) Then Break;
       sp := f.sp;
       sp^ := r;
       Inc(sp);
      End
      Else Begin
       kwd := TPyDict.Make;
       For i := 0 To nkw - 1 Do kwd.SetItem(tup.items[i], sp[-1 - nkw + i]);
       f.sp := sp;
       r := CallValue(a, sp - 1 - arg, npos, kwd);
       Dec(sp, arg + 2);
       sp^ := r;
       Inc(sp);
      End;
     End;
    CALL_FUNCTION_EX: Begin
      kwd := Nil;
      If (arg And 1) <> 0 Then Begin
       c := sp[-1];
       Dec(sp);
       kwd := TPyDict.Make;
       MergeMapping(kwd, c, True);
      End;
      b := sp[-1];
      a := sp[-2];
      Dec(sp, 2);
      If Not ((b.k = vkObj) And (b.o Is TPyTuple)) Then Begin
       items := IterToArr(b);
       tup := TupleFromVals(items);
      End
      Else tup := TPyTuple(b.o);
      f.sp := sp;
      f.ip := ip;
      If (a.k = vkObj) And (a.o.ClassType = TPyFunc) Then Begin
       If Length(tup.items) > 0 Then n := Length(tup.items) Else n := 1;
       If PushPyCall(TPyFunc(a.o), @tup.items[0], Length(tup.items), Nil,
        Nil, kwd, r) Then Break;
       sp^ := r;
       Inc(sp);
      End
      Else Begin
       If Length(tup.items) = 0 Then r := CallValue(a, Nil, 0, kwd)
       Else r := CallValue(a, @tup.items[0], Length(tup.items), kwd);
       sp^ := r;
       Inc(sp);
      End;
     End;
    MAKE_FUNCTION: Begin
      a := sp[-1];
      b := sp[-2];
      n := PopCnt(arg And 15);
      fnobj := MakeFunctionObj(b, a, arg, sp - 2 - n);
      Dec(sp, 2 + n);
      sp^ := VObj(fnobj);
      Inc(sp);
     End;
    LIST_APPEND: Begin
      a := sp[-1];
      Dec(sp);
      TPyList(sp[-arg].o).Add(a);
     End;
    SET_ADD: Begin
      a := sp[-1];
      Dec(sp);
      TPySet(sp[-arg].o).Add(a);
     End;
    MAP_ADD: Begin
      b := sp[-1];
      a := sp[-2];
      Dec(sp, 2);
      TPyDict(sp[-arg].o).SetItem(a, b);
     End;
    FORMAT_VALUE: Begin
      s := '';
      If (arg And 4) <> 0 Then Begin
       b := sp[-1];
       Dec(sp);
       s := TPyStr(b.o).s;
      End;
      a := sp[-1];
      a := ConvertForFormat(a, arg And 3);
      If (a.k = vkObj) And (a.o.ClassType = TPyStr) And (s = '') Then
       sp[-1] := a
      Else sp[-1] := VStr(FormatValue(a, s));
     End;
   Else
    RaiseExc(exSystemError, 'unknown opcode ' + IntToStr(op));
   End;
  End;
 End;
End;

{ ------------------------------------------------------------
  Entrees / sorties de base
  ------------------------------------------------------------ }
Var
 OutBuf: AnsiString;
 OutLen: Integer;
 Unbuffered: Boolean;
 InBuf: AnsiString;
 InPos: Integer;
 InEOF: Boolean;
 StdinObj, StdoutObj, StderrObj: TPyFile;

Procedure RawWrite(h: THandle; Const s: AnsiString);
Var
 n, w: LongInt;
 p: PChar;
Begin
 If s = '' Then Exit;
 p := PChar(s);
 n := Length(s);
 While n > 0 Do Begin
  w := FileWrite(h, p^, n);
  If w <= 0 Then Exit;
  Inc(p, w);
  Dec(n, w);
 End;
End;

Procedure OutFlush;
Begin
 If OutLen > 0 Then Begin
  RawWrite(StdOutputHandle, Copy(OutBuf, 1, OutLen));
  OutLen := 0;
 End;
End;

Procedure OutWrite(Const s: AnsiString);
Var
 n: Integer;
Begin
 n := Length(s);
 If n = 0 Then Exit;
 If OutLen + n > Length(OutBuf) Then Begin
  OutFlush;
  If n > Length(OutBuf) Then Begin
   RawWrite(StdOutputHandle, s);
   Exit;
  End;
 End;
 Move(s[1], OutBuf[OutLen + 1], n);
 Inc(OutLen, n);
 If Unbuffered Then OutFlush;
End;

Procedure ErrWrite(Const s: AnsiString);
Begin
 OutFlush;
 RawWrite(StdErrorHandle, s);
End;

Procedure FillStdin;
Var
 tmp: AnsiString;
 n: LongInt;
Begin
 If InEOF Then Exit;
 SetLength(tmp, 65536);
 n := FileRead(StdInputHandle, tmp[1], 65536);
 If n <= 0 Then Begin
  InEOF := True;
  Exit;
 End;
 If InPos > 1 Then Begin
  Delete(InBuf, 1, InPos - 1);
  InPos := 1;
 End;
 InBuf := InBuf + Copy(tmp, 1, n);
End;

{ lit une ligne (avec le \n) ; False si fin de fichier sans donnees }
Function StdinReadLine(Var line: AnsiString): Boolean;
Var
 p: Integer;
Begin
 While True Do Begin
  p := PosEx(#10, InBuf, InPos);
  If p > 0 Then Begin
   line := Copy(InBuf, InPos, p - InPos + 1);
   InPos := p + 1;
   Result := True;
   Exit;
  End;
  If InEOF Then Begin
   If InPos <= Length(InBuf) Then Begin
    line := Copy(InBuf, InPos, Length(InBuf));
    InPos := Length(InBuf) + 1;
    Result := True;
   End
   Else Result := False;
   Exit;
  End;
  FillStdin;
 End;
 Result := False;
End;

Function StdinReadAll: AnsiString;
Begin
 While Not InEOF Do FillStdin;
 Result := Copy(InBuf, InPos, Length(InBuf));
 InPos := Length(InBuf) + 1;
End;

Function StdinReadN(n: Integer): AnsiString;
Begin
 While (Length(InBuf) - InPos + 1 < n) And Not InEOF Do FillStdin;
 Result := Copy(InBuf, InPos, n);
 Inc(InPos, Length(Result));
End;

{ ------------------------------------------------------------
  Initialisation des types
  ------------------------------------------------------------ }
Function MkType(Const nm: AnsiString; base: TPyType; nat: Integer): TPyType;
Begin
 Result := NewType(nm, base, nat);
 BuiltinsDict.SetS(nm, VObj(Result));
End;

Function MkExc(Const nm: AnsiString; base: TPyType): TPyType;
Begin
 Result := NewType(nm, base, nkException);
 Result.idict.SetS('__module__', VStr('builtins'));
 BuiltinsDict.SetS(nm, VObj(Result));
End;

Function ObjInit(a: PVal; n: Integer; kw: TPyDict): TVal; Forward;

Function ObjNew(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyType;
 o: TPyObj;
 f: TVal;
Begin
 If (n < 1) Or Not ((a[0].k = vkObj) And (a[0].o Is TPyType)) Then
  TypeErr('object.__new__(X): X is not a type object');
 t := TPyType(a[0].o);
 If (n > 1) Or ((kw <> Nil) And (kw.used > 0)) Then Begin
  If LookupType(t, '__init__', f) And (f.k = vkObj) And
   (f.o Is TPyBuiltin) And (TPyBuiltin(f.o).name = '__init__') And
   (Pointer(TPyBuiltin(f.o).fn) = Pointer(@ObjInit)) Then
   TypeErr(t.name + '() takes no arguments');
 End;
 If t.native <> nkObject Then
  TypeErr('object.__new__(' + t.name + ') is not safe, use ' +
   t.name + '.__new__()');
 o := TPyObj.Create(t);
 o.idict := TPyDict.Make;
 Result := VObj(o);
End;

Function ObjInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyType;
 f: TVal;
Begin
 Result := vNone;
 If (n > 1) Or ((kw <> Nil) And (kw.used > 0)) Then Begin
  t := TypeOf(a[0]);
  If LookupType(t, '__new__', f) And (f.k = vkObj) And (f.o Is TPyBuiltin)
   And (Pointer(TPyBuiltin(f.o).fn) = Pointer(@ObjNew)) Then
   TypeErr(t.name + '() takes no arguments');
 End;
End;

Function ObjRepr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr('<' + TypeFullName(TypeOf(a[0])) + ' object at ' +
  HexAddr(a[0].o) + '>');
End;

Function ObjStr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ReprVal(a[0]));
End;

Function ObjEq(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If (a[0].k = a[1].k) And (((a[0].k = vkObj) And (a[0].o = a[1].o)) Or
  ((a[0].k <> vkObj) And (a[0].i = a[1].i))) Then Result := vTrue
 Else Result := vNotImpl;
End;

Function ObjNe(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 r := ObjEq(a, n, kw);
 If IsNotImpl(r) Then Result := r Else Result := VBool(Not IsTrue(r));
End;

Function ObjHash(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If a[0].k = vkObj Then Result := VInt(Int64(PtrUInt(a[0].o) Shr 4))
 Else Result := VInt(HashVal(a[0]));
End;

Function ObjNotImpl2(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vNotImpl;
End;

Function ObjFormat(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If (n > 1) And (StrOf(a[1]) <> '') Then
  TypeErr('unsupported format string passed to ' + TypeName(a[0]) +
   '.__format__');
 Result := VStr(StrVal(a[0]));
End;

Function ObjSetAttr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TVal;
 nm: TPyStr;
Begin
 o := a[0];
 nm := InternStr(StrOf(a[1]));
 If (o.k = vkObj) And (o.o.idict = Nil) Then o.o.idict := TPyDict.Make;
 If o.k <> vkObj Then RaiseAttrError(o, nm.s);
 DictSetO(o.o.idict, nm, a[2]);
 Result := vNone;
End;

Function ObjDelAttr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 key: TVal;
Begin
 key := VObj(InternStr(StrOf(a[1])));
 If (a[0].k <> vkObj) Or (a[0].o.idict = Nil) Or
  Not a[0].o.idict.DelItem(key) Then RaiseAttrError(a[0], StrOf(a[1]));
 Result := vNone;
End;

Function ObjGetAttribute(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := GetAttr(a[0], StrOf(a[1]));
End;

Function ObjInitSubclass(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vNone;
End;

Function TypeNewNative(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 meta: TPyType;
 bases: Array Of TPyType;
 i: Integer;
 bt: TPyTuple;
Begin
 meta := TPyType(a[0].o);
 If n = 2 Then Begin
  Result := VObj(TypeOf(a[1]));
  Exit;
 End;
 If n <> 4 Then TypeErr('type() takes 1 or 3 arguments');
 If Not ((a[2].k = vkObj) And (a[2].o Is TPyTuple)) Then
  TypeErr('type.__new__() argument 2 must be tuple, not ' + TypeName(a[2]));
 If Not ((a[3].k = vkObj) And (a[3].o Is TPyDict)) Then
  TypeErr('type.__new__() argument 3 must be dict, not ' + TypeName(a[3]));
 bt := TPyTuple(a[2].o);
 SetLength(bases, Length(bt.items));
 For i := 0 To High(bt.items) Do Begin
  If Not ((bt.items[i].k = vkObj) And (bt.items[i].o Is TPyType)) Then
   TypeErr('bases must be types');
  bases[i] := TPyType(bt.items[i].o);
 End;
 Result := VObj(TypeNew(meta, StrOf(a[1]), bases, TPyDict(a[3].o), kw));
End;

Function TypeInitNative(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vNone;
End;

Function TypeMro(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i: Integer;
Begin
 l := NewList;
 For i := 0 To High(TPyType(a[0].o).mro) Do
  l.Add(VObj(TPyType(a[0].o).mro[i]));
 Result := VObj(l);
End;

Function TypeSubclasses(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i, j: Integer;
 o: TPyObj;
Begin
 l := NewList;
 For i := 0 To GcCount - 1 Do Begin
  o := GcObjs[i];
  If o Is TPyType Then
   For j := 0 To High(TPyType(o).bases) Do
    If TPyType(o).bases[j] = TPyType(a[0].o) Then l.Add(VObj(o));
 End;
 Result := VObj(l);
End;

Function TypeInstanceCheck(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(IsInstance(a[1], TPyType(a[0].o)));
End;

Function TypeSubclassCheck(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyType)) Then
  TypeErr('issubclass() arg 1 must be a class');
 Result := VBool(TypeIsSub(TPyType(a[1].o), TPyType(a[0].o)));
End;

Function TypeRepr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ReprVal(a[0]));
End;

{ ---- exceptions ---- }
Function ExcNew(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyType;
 o: TPyObj;
 tup: TPyTuple;
 i: Integer;
Begin
 t := TPyType(a[0].o);
 o := TPyObj.Create(t);
 o.idict := TPyDict.Make;
 tup := NewTuple(n - 1);
 For i := 1 To n - 1 Do tup.items[i - 1] := a[i];
 o.idict.SetS('args', VObj(tup));
 Result := VObj(o);
End;

Function ExcInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 tup: TPyTuple;
 i: Integer;
Begin
 tup := NewTuple(n - 1);
 For i := 1 To n - 1 Do tup.items[i - 1] := a[i];
 If a[0].o.idict = Nil Then a[0].o.idict := TPyDict.Make;
 a[0].o.idict.SetS('args', VObj(tup));
 If kw <> Nil Then
  For i := 0 To kw.nent - 1 Do
   If kw.ent[i].key.k <> vkNull Then
    a[0].o.idict.SetItem(kw.ent[i].key, kw.ent[i].val);
 Result := vNone;
End;

Function ExcStr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ExcArgsStr(a[0].o));
End;

Function ExcRepr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ReprVal(a[0]));
End;

Function ExcWithTb(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := a[0];
End;

Function StopIterInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 ExcInit(a, n, kw);
 If n > 1 Then a[0].o.idict.SetS('value', a[1])
 Else a[0].o.idict.SetS('value', vNone);
 Result := vNone;
End;

Function SysExitInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 ExcInit(a, n, kw);
 If n > 1 Then a[0].o.idict.SetS('code', a[1])
 Else a[0].o.idict.SetS('code', vNone);
 Result := vNone;
End;

Function OSErrInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 ExcInit(a, n, kw);
 a[0].o.idict.SetS('errno', vNone);
 a[0].o.idict.SetS('strerror', vNone);
 a[0].o.idict.SetS('filename', vNone);
 If n > 2 Then Begin
  a[0].o.idict.SetS('errno', a[1]);
  a[0].o.idict.SetS('strerror', a[2]);
  If n > 3 Then a[0].o.idict.SetS('filename', a[3]);
 End;
 Result := vNone;
End;

Function OSErrStr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 e, s, fn: TVal;
Begin
 If a[0].o.idict.GetS('errno', e) And (e.k <> vkNone) Then Begin
  a[0].o.idict.GetS('strerror', s);
  If a[0].o.idict.GetS('filename', fn) And (fn.k <> vkNone) Then
   Result := VStr('[Errno ' + StrVal(e) + '] ' + StrVal(s) + ': ' +
    ReprVal(fn))
  Else Result := VStr('[Errno ' + StrVal(e) + '] ' + StrVal(s));
 End
 Else Result := VStr(ExcArgsStr(a[0].o));
End;

Function KeyErrStr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TVal;
Begin
 If a[0].o.idict.GetS('args', t) And (Length(TPyTuple(t.o).items) = 1) Then
  Result := VStr(ReprVal(TPyTuple(t.o).items[0]))
 Else Result := VStr(ExcArgsStr(a[0].o));
End;

Function ImportErrInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 ExcInit(a, n, kw);
 a[0].o.idict.SetS('name', vNone);
 a[0].o.idict.SetS('path', vNone);
 If KwGet(kw, 'name', v) Then a[0].o.idict.SetS('name', v);
 If KwGet(kw, 'path', v) Then a[0].o.idict.SetS('path', v);
 a[0].o.idict.SetS('msg', vNone);
 If n > 1 Then a[0].o.idict.SetS('msg', a[1]);
 Result := vNone;
End;

Function SyntaxErrInit(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 info: TPyTuple;
Begin
 ExcInit(a, n, kw);
 a[0].o.idict.SetS('msg', vNone);
 a[0].o.idict.SetS('filename', vNone);
 a[0].o.idict.SetS('lineno', vNone);
 a[0].o.idict.SetS('offset', vNone);
 a[0].o.idict.SetS('text', vNone);
 If n > 1 Then a[0].o.idict.SetS('msg', a[1]);
 If (n > 2) And (a[2].k = vkObj) And (a[2].o Is TPyTuple) Then Begin
  info := TPyTuple(a[2].o);
  If Length(info.items) >= 4 Then Begin
   a[0].o.idict.SetS('filename', info.items[0]);
   a[0].o.idict.SetS('lineno', info.items[1]);
   a[0].o.idict.SetS('offset', info.items[2]);
   a[0].o.idict.SetS('text', info.items[3]);
  End;
 End;
 Result := vNone;
End;

Function SyntaxErrStr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 m, ln, fn: TVal;
 s: AnsiString;
Begin
 If a[0].o.idict.GetS('msg', m) And (m.k <> vkNone) Then s := StrVal(m)
 Else s := ExcArgsStr(a[0].o);
 If a[0].o.idict.GetS('lineno', ln) And (ln.k <> vkNone) Then Begin
  a[0].o.idict.GetS('filename', fn);
  If fn.k = vkNone Then s := s + ' (line ' + StrVal(ln) + ')'
  Else s := s + ' (' + StrVal(fn) + ', line ' + StrVal(ln) + ')';
 End;
 Result := VStr(s);
End;

{ ---- fonctions de base ---- }
Function EmptyKw: TPyDict;
Begin
 Result := Nil;
End;

Procedure InitTypes;
Begin
 tyObject := NewTypeRaw('object');
 tyType := NewTypeRaw('type');
 tyObject.cls := tyType;
 tyType.cls := tyType;
 SetLength(tyObject.mro, 1);
 tyObject.mro[0] := tyObject;
 SetLength(tyType.bases, 1);
 tyType.bases[0] := tyObject;
 ComputeMro(tyType);
 tyType.native := nkType;
 BuiltinsDict.SetS('object', VObj(tyObject));
 BuiltinsDict.SetS('type', VObj(tyType));
 tyInt := MkType('int', tyObject, nkInt);
 tyBool := MkType('bool', tyInt, nkBool);
 tyFloat := MkType('float', tyObject, nkFloat);
 tyStr := MkType('str', tyObject, nkStr);
 tyBytes := MkType('bytes', tyObject, nkBytes);
 tyBytearray := MkType('bytearray', tyObject, nkBytes);
 tyList := MkType('list', tyObject, nkList);
 tyTuple := MkType('tuple', tyObject, nkTuple);
 tyDict := MkType('dict', tyObject, nkDict);
 tySet := MkType('set', tyObject, nkSet);
 tyFrozenset := MkType('frozenset', tyObject, nkFrozen);
 tyRange := MkType('range', tyObject, nkNoNew);
 tySlice := MkType('slice', tyObject, nkNoNew);
 tyProperty := MkType('property', tyObject, nkProperty);
 tyStaticMethod := MkType('staticmethod', tyObject, nkWrapper);
 tyClassMethod := MkType('classmethod', tyObject, nkWrapper);
 tySuper := MkType('super', tyObject, nkNoNew);
 tyNone := NewType('NoneType', tyObject, nkNoNew);
 tyFunction := NewType('function', tyObject, nkNoNew);
 tyBuiltin := NewType('builtin_function_or_method', tyObject, nkNoNew);
 tyMethod := NewType('method', tyObject, nkNoNew);
 tyModule := NewType('module', tyObject, nkNoNew);
 tyCode := NewType('code', tyObject, nkNoNew);
 tyCell := NewType('cell', tyObject, nkNoNew);
 tyGenerator := NewType('generator', tyObject, nkNoNew);
 tyEllipsis := NewType('ellipsis', tyObject, nkNoNew);
 tyNotImpl := NewType('NotImplementedType', tyObject, nkNoNew);
 tyFile := NewType('TextIOWrapper', tyObject, nkFile);
 tyIter := NewType('iterator', tyObject, nkNoNew);
 tyDictView := NewType('dict_view', tyObject, nkNoNew);
 tyFrame := NewType('frame', tyObject, nkNoNew);
 tyTraceback := NewType('traceback', tyObject, nkNoNew);
 tyFile.idict.SetS('__module__', VStr('_io'));
 { exceptions }
 exBaseException := MkExc('BaseException', tyObject);
 exBaseException.native := nkException;
 exException := MkExc('Exception', exBaseException);
 exSystemExit := MkExc('SystemExit', exBaseException);
 exKeyboardInterrupt := MkExc('KeyboardInterrupt', exBaseException);
 exGeneratorExit := MkExc('GeneratorExit', exBaseException);
 exStopIteration := MkExc('StopIteration', exException);
 exStopAsyncIteration := MkExc('StopAsyncIteration', exException);
 exArithmeticError := MkExc('ArithmeticError', exException);
 exFloatingPoint := MkExc('FloatingPointError', exArithmeticError);
 exOverflow := MkExc('OverflowError', exArithmeticError);
 exZeroDivision := MkExc('ZeroDivisionError', exArithmeticError);
 exAssertionError := MkExc('AssertionError', exException);
 exAttributeError := MkExc('AttributeError', exException);
 exBufferError := MkExc('BufferError', exException);
 exEOFError := MkExc('EOFError', exException);
 exImportError := MkExc('ImportError', exException);
 exModuleNotFound := MkExc('ModuleNotFoundError', exImportError);
 exLookupError := MkExc('LookupError', exException);
 exIndexError := MkExc('IndexError', exLookupError);
 exKeyError := MkExc('KeyError', exLookupError);
 exMemoryError := MkExc('MemoryError', exException);
 exNameError := MkExc('NameError', exException);
 exUnboundLocal := MkExc('UnboundLocalError', exNameError);
 exOSError := MkExc('OSError', exException);
 BuiltinsDict.SetS('IOError', VObj(exOSError));
 BuiltinsDict.SetS('EnvironmentError', VObj(exOSError));
 exBlockingIOError := MkExc('BlockingIOError', exOSError);
 exChildProcess := MkExc('ChildProcessError', exOSError);
 exConnectionError := MkExc('ConnectionError', exOSError);
 exBrokenPipe := MkExc('BrokenPipeError', exConnectionError);
 MkExc('ConnectionAbortedError', exConnectionError);
 MkExc('ConnectionRefusedError', exConnectionError);
 MkExc('ConnectionResetError', exConnectionError);
 exFileExists := MkExc('FileExistsError', exOSError);
 exFileNotFound := MkExc('FileNotFoundError', exOSError);
 exInterrupted := MkExc('InterruptedError', exOSError);
 exIsADirectory := MkExc('IsADirectoryError', exOSError);
 exNotADirectory := MkExc('NotADirectoryError', exOSError);
 exPermissionError := MkExc('PermissionError', exOSError);
 exProcessLookup := MkExc('ProcessLookupError', exOSError);
 exTimeoutError := MkExc('TimeoutError', exOSError);
 exReferenceError := MkExc('ReferenceError', exException);
 exRuntimeError := MkExc('RuntimeError', exException);
 exNotImplementedError := MkExc('NotImplementedError', exRuntimeError);
 exRecursionError := MkExc('RecursionError', exRuntimeError);
 exSyntaxError := MkExc('SyntaxError', exException);
 exIndentationError := MkExc('IndentationError', exSyntaxError);
 exTabError := MkExc('TabError', exIndentationError);
 exSystemError := MkExc('SystemError', exException);
 exTypeError := MkExc('TypeError', exException);
 exValueError := MkExc('ValueError', exException);
 exUnicodeError := MkExc('UnicodeError', exValueError);
 exUnicodeDecodeError := MkExc('UnicodeDecodeError', exUnicodeError);
 exUnicodeEncodeError := MkExc('UnicodeEncodeError', exUnicodeError);
 MkExc('UnicodeTranslateError', exUnicodeError);
 exWarning := MkExc('Warning', exException);
 exUserWarning := MkExc('UserWarning', exWarning);
 exDeprecationWarning := MkExc('DeprecationWarning', exWarning);
 exPendingDeprecationWarning := MkExc('PendingDeprecationWarning', exWarning);
 exSyntaxWarning := MkExc('SyntaxWarning', exWarning);
 exRuntimeWarning := MkExc('RuntimeWarning', exWarning);
 exFutureWarning := MkExc('FutureWarning', exWarning);
 exImportWarning := MkExc('ImportWarning', exWarning);
 exUnicodeWarning := MkExc('UnicodeWarning', exWarning);
 exBytesWarning := MkExc('BytesWarning', exWarning);
 exResourceWarning := MkExc('ResourceWarning', exWarning);
 { methodes de object }
 tyObject.idict.SetS('__new__', VObj(NewBuiltin('__new__', @ObjNew)));
 DefMethod(tyObject, '__init__', @ObjInit);
 DefMethod(tyObject, '__repr__', @ObjRepr);
 DefMethod(tyObject, '__str__', @ObjStr);
 DefMethod(tyObject, '__eq__', @ObjEq);
 DefMethod(tyObject, '__ne__', @ObjNe);
 DefMethod(tyObject, '__hash__', @ObjHash);
 DefMethod(tyObject, '__lt__', @ObjNotImpl2);
 DefMethod(tyObject, '__le__', @ObjNotImpl2);
 DefMethod(tyObject, '__gt__', @ObjNotImpl2);
 DefMethod(tyObject, '__ge__', @ObjNotImpl2);
 DefMethod(tyObject, '__format__', @ObjFormat);
 DefMethod(tyObject, '__setattr__', @ObjSetAttr);
 DefMethod(tyObject, '__delattr__', @ObjDelAttr);
 DefMethod(tyObject, '__getattribute__', @ObjGetAttribute);
 DefClassMethod(tyObject, '__init_subclass__', @ObjInitSubclass);
 tyObject.idict.SetS('__module__', VStr('builtins'));
 { type }
 tyType.idict.SetS('__new__', VObj(NewBuiltin('__new__', @TypeNewNative)));
 DefMethod(tyType, '__init__', @TypeInitNative);
 DefMethod(tyType, 'mro', @TypeMro);
 DefMethod(tyType, '__subclasses__', @TypeSubclasses);
 DefMethod(tyType, '__instancecheck__', @TypeInstanceCheck);
 DefMethod(tyType, '__subclasscheck__', @TypeSubclassCheck);
 DefMethod(tyType, '__repr__', @TypeRepr);
 { exceptions }
 exBaseException.idict.SetS('__new__', VObj(NewBuiltin('__new__', @ExcNew)));
 DefMethod(exBaseException, '__init__', @ExcInit);
 DefMethod(exBaseException, '__str__', @ExcStr);
 DefMethod(exBaseException, '__repr__', @ExcRepr);
 DefMethod(exBaseException, 'with_traceback', @ExcWithTb);
 DefMethod(exStopIteration, '__init__', @StopIterInit);
 DefMethod(exSystemExit, '__init__', @SysExitInit);
 DefMethod(exOSError, '__init__', @OSErrInit);
 DefMethod(exOSError, '__str__', @OSErrStr);
 DefMethod(exKeyError, '__str__', @KeyErrStr);
 DefMethod(exImportError, '__init__', @ImportErrInit);
 DefMethod(exSyntaxError, '__init__', @SyntaxErrInit);
 DefMethod(exSyntaxError, '__str__', @SyntaxErrStr);
 { singletons }
 vNone.k := vkNone;
 vNone.i := 0;
 vTrue := VBool(True);
 vFalse := VBool(False);
 vNull.k := vkNull;
 vNull.i := 0;
 vEllipsis := VObj(TPyObj.Create(tyEllipsis));
 vNotImpl := VObj(TPyObj.Create(tyNotImpl));
 BuiltinsDict.SetS('Ellipsis', vEllipsis);
 BuiltinsDict.SetS('NotImplemented', vNotImpl);
 BuiltinsDict.SetS('None', vNone);
 BuiltinsDict.SetS('True', vTrue);
 BuiltinsDict.SetS('False', vFalse);
 BuiltinsDict.SetS('__debug__', VBool(OptLevel = 0));
 EmptyTuple := NewTuple(0);
 tyList.idict.SetS('__hash__', vNone);
 tyDict.idict.SetS('__hash__', vNone);
 tySet.idict.SetS('__hash__', vNone);
End;

{ ------------------------------------------------------------
  Affichage d'une exception non interceptee
  ------------------------------------------------------------ }
Function ExcTypeDisplay(c: TPyType): AnsiString;
Var
 m: AnsiString;
Begin
 m := TypeModule(c);
 If (m = '') Or (m = 'builtins') Or (m = '__main__') Then
  Result := c.qualname
 Else Result := m + '.' + c.qualname;
End;

Function ExcOneLine(e: TPyObj): AnsiString;
Var
 s: AnsiString;
Begin
 s := StrVal(VObj(e));
 If s = '' Then Result := ExcTypeDisplay(e.cls)
 Else Result := ExcTypeDisplay(e.cls) + ': ' + s;
End;

Function SyntaxErrDisplay(e: TPyObj): AnsiString;
Var
 fn, ln, off, txt, msg: TVal;
 s, t: AnsiString;
 col, i: Integer;
Begin
 s := '';
 e.idict.GetS('filename', fn);
 e.idict.GetS('lineno', ln);
 e.idict.GetS('offset', off);
 e.idict.GetS('text', txt);
 e.idict.GetS('msg', msg);
 If ln.k <> vkNone Then Begin
  If IsStrVal(fn) Then
   s := '  File "' + TPyStr(fn.o).s + '", line ' + StrVal(ln) + #10
  Else s := '  File "<string>", line ' + StrVal(ln) + #10;
  If IsStrVal(txt) And (TPyStr(txt.o).s <> '') Then Begin
   t := TPyStr(txt.o).s;
   col := 0;
   If off.k = vkInt Then col := off.i;
   i := 1;
   While (i <= Length(t)) And (t[i] In [' ', #9]) Do Inc(i);
   s := s + '    ' + Copy(t, i, Length(t)) + #10;
   If col > 0 Then Begin
    col := col - (i - 1);
    If col < 1 Then col := 1;
    s := s + '    ' + StringOfChar(' ', col - 1) + '^' + #10;
   End;
  End;
 End;
 If msg.k = vkNone Then s := s + ExcTypeDisplay(e.cls)
 Else s := s + ExcTypeDisplay(e.cls) + ': ' + StrVal(msg);
 Result := s;
End;

Function FormatException(e: TPyObj; depth: Integer): AnsiString;
Var
 s: AnsiString;
 tb, c, ctx, sup: TVal;
 l: TPyList;
 i: Integer;
 ent: TPyTuple;
Begin
 s := '';
 If depth < 12 Then Begin
  If e.idict <> Nil Then Begin
   If e.idict.GetS('__cause__', c) And (c.k = vkObj) Then
    s := FormatException(c.o, depth + 1) + #10 +
     'The above exception was the direct cause of the following ' +
     'exception:' + #10#10
   Else If e.idict.GetS('__context__', ctx) And (ctx.k = vkObj) And
    Not (e.idict.GetS('__suppress_context__', sup) And IsTrue(sup)) Then
    s := FormatException(ctx.o, depth + 1) + #10 +
     'During handling of the above exception, another exception occurred:'
     + #10#10;
  End;
 End;
 If (e.idict <> Nil) And e.idict.GetS('__tb__', tb) And (tb.k = vkObj) Then Begin
  l := TPyList(tb.o);
  If l.cnt > 0 Then s := s + 'Traceback (most recent call last):' + #10;
  For i := l.cnt - 1 DownTo 0 Do Begin
   ent := TPyTuple(l.items[i].o);
   s := s + '  File "' + StrVal(ent.items[0]) + '", line ' +
    StrVal(ent.items[1]) + ', in ' + StrVal(ent.items[2]) + #10;
   If StrVal(ent.items[3]) <> '' Then
    s := s + '    ' + StrVal(ent.items[3]) + #10;
  End;
 End;
 If TypeIsSub(e.cls, exSyntaxError) Then s := s + SyntaxErrDisplay(e) + #10
 Else s := s + ExcOneLine(e) + #10;
 Result := s;
End;

Procedure PyRunTraceback(e: TPyObj);
Begin
 ErrWrite(FormatException(e, 0));
End;

{ ------------------------------------------------------------
  Fonctions integrees (builtins)
  ------------------------------------------------------------ }
Procedure FileWriteStr(f: TPyFile; Const s: AnsiString); Forward;
Function CompileSafe(Const src, fname: AnsiString; mode: Integer): TPyCode;
 Forward;
Function ModuleGlobalsOfFrame: TPyDict; Forward;

Function ArgKw(a: PVal; n: Integer; kw: TPyDict; idx: Integer;
 Const nm: AnsiString; Var v: TVal): Boolean;
Begin
 If idx < n Then Begin
  v := a[idx];
  Result := True;
 End
 Else Result := KwGet(kw, nm, v);
End;

Procedure PyWriteTo(Const target: TVal; Const s: AnsiString);
Var
 v: TVal;
Begin
 v := target;
 If v.k = vkNone Then Begin
  If Not SysDict.GetS('stdout', v) Then Begin
   OutWrite(s);
   Exit;
  End;
 End;
 If v.k = vkNone Then
  RaiseExc(exRuntimeError, 'lost sys.stdout');
 If (v.k = vkObj) And (v.o Is TPyFile) And Not v.o.cls.userdef Then
  FileWriteStr(TPyFile(v.o), s)
 Else Call1(GetAttr(v, 'write'), VStr(s));
End;

Function BiPrint(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 sep, endS, s: AnsiString;
 v, fv: TVal;
 i: Integer;
 doFlush: Boolean;
Begin
 sep := ' ';
 endS := #10;
 fv := vNone;
 doFlush := False;
 If kw <> Nil Then Begin
  If KwGet(kw, 'sep', v) And (v.k <> vkNone) Then Begin
   If Not IsStrVal(v) Then TypeErr('sep must be None or a string, not ' +
    TypeName(v));
   sep := TPyStr(v.o).s;
  End;
  If KwGet(kw, 'end', v) And (v.k <> vkNone) Then Begin
   If Not IsStrVal(v) Then TypeErr('end must be None or a string, not ' +
    TypeName(v));
   endS := TPyStr(v.o).s;
  End;
  If KwGet(kw, 'file', v) Then fv := v;
  If KwGet(kw, 'flush', v) Then doFlush := IsTrue(v);
 End;
 If n = 1 Then s := StrVal(a[0])
 Else Begin
  s := '';
  For i := 0 To n - 1 Do Begin
   If i > 0 Then s := s + sep;
   s := s + StrVal(a[i]);
  End;
 End;
 PyWriteTo(fv, s + endS);
 If doFlush Then OutFlush;
 Result := vNone;
End;

Function LenOf(Const v: TVal): Int64;
Var
 f, r: TVal;
Begin
 If v.k = vkObj Then Begin
  If v.o.cls.userdef Then
   If LookupType(v.o.cls, '__len__', f) And (f.k = vkObj) And
    (f.o Is TPyFunc) Then Begin
    r := Call1(f, v);
    If Not IsIntVal(r) Then TypeErr('''' + TypeName(r) +
     ''' object cannot be interpreted as an integer');
    If IntSign(r) < 0 Then ValueErr('__len__() should return >= 0');
    Result := ToInt64(r);
    Exit;
   End;
  If v.o Is TPyStr Then Result := PyStrLen(TPyStr(v.o))
  Else If v.o Is TPyList Then Result := TPyList(v.o).cnt
  Else If v.o Is TPyTuple Then Result := Length(TPyTuple(v.o).items)
  Else If v.o Is TPyDict Then Result := TPyDict(v.o).used
  Else If v.o Is TPySet Then Result := TPySet(v.o).used
  Else If v.o Is TPyBytes Then Result := Length(TPyBytes(v.o).s)
  Else If v.o Is TPyRange Then Result := TPyRange(v.o).len
  Else If v.o Is TDictView Then Result := TDictView(v.o).src.used
  Else If LookupType(v.o.cls, '__len__', f) Then Begin
   r := Call1(f, v);
   Result := ToInt64(r);
  End
  Else Begin
   TypeErr('object of type ''' + TypeName(v) + ''' has no len()');
   Result := 0;
  End;
  Exit;
 End;
 TypeErr('object of type ''' + TypeName(v) + ''' has no len()');
 Result := 0;
End;

Function BiLen(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'len()');
 Result := VInt(LenOf(a[0]));
End;

Function BiAbs(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TVal;
Begin
 NeedArgs(n, 1, 1, 'abs()');
 Case a[0].k Of
  vkInt, vkBool: Begin
    If a[0].i < 0 Then Result := IntNeg(VInt(a[0].i)) Else Result := VInt(a[0].i);
   End;
  vkFloat: Result := VFloat(Abs(a[0].d));
 Else
  If (a[0].k = vkObj) And (a[0].o Is TPyBigInt) Then Begin
   If TPyBigInt(a[0].o).neg Then Result := IntNeg(a[0]) Else Result := a[0];
  End
  Else If (a[0].k = vkObj) And LookupType(a[0].o.cls, '__abs__', f) Then
   Result := Call1(f, a[0])
  Else Begin
   TypeErr('bad operand type for abs(): ''' + TypeName(a[0]) + '''');
   Result := vNone;
  End;
 End;
End;

Function BiAll(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 it, x: TVal;
Begin
 NeedArgs(n, 1, 1, 'all()');
 it := IterOf(a[0]);
 Result := vTrue;
 While IterNextVal(it, x) Do
  If Not IsTrue(x) Then Begin
   Result := vFalse;
   Exit;
  End;
End;

Function BiAny(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 it, x: TVal;
Begin
 NeedArgs(n, 1, 1, 'any()');
 it := IterOf(a[0]);
 Result := vFalse;
 While IterNextVal(it, x) Do
  If IsTrue(x) Then Begin
   Result := vTrue;
   Exit;
  End;
End;

Function BiChr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 c: Int64;
Begin
 NeedArgs(n, 1, 1, 'chr()');
 c := IndexVal(a[0]);
 If (c < 0) Or (c > $10FFFF) Then ValueErr('chr() arg not in range(0x110000)');
 Result := VStr(Utf8Enc(c));
End;

Function BiOrd(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
Begin
 NeedArgs(n, 1, 1, 'ord()');
 If IsStrVal(a[0]) Then Begin
  If PyStrLen(TPyStr(a[0].o)) <> 1 Then
   TypeErr('ord() expected a character, but string of length ' +
    IntToStr(PyStrLen(TPyStr(a[0].o))) + ' found');
  i := 1;
  Result := VInt(Utf8Dec(TPyStr(a[0].o).s, i));
 End
 Else If (a[0].k = vkObj) And (a[0].o Is TPyBytes) Then Begin
  If Length(TPyBytes(a[0].o).s) <> 1 Then
   TypeErr('ord() expected a character, but string of length ' +
    IntToStr(Length(TPyBytes(a[0].o).s)) + ' found');
  Result := VInt(Ord(TPyBytes(a[0].o).s[1]));
 End
 Else Begin
  TypeErr('ord() expected string of length 1, but ' + TypeName(a[0]) +
   ' found');
  Result := vNone;
 End;
End;

Function RadixStr(Const v: TVal; radix: Integer; Const prefix: AnsiString):
 AnsiString;
Var
 x: TVal;
Begin
 If Not HasIndex(v) Then
  TypeErr('''' + TypeName(v) + ''' object cannot be interpreted as an ' +
   'integer');
 If IsIntVal(v) Then x := v Else x := VInt(IndexVal(v));
 If IntSign(x) < 0 Then
  Result := '-' + prefix + IntToStrRadix(IntNeg(x), radix)
 Else Result := prefix + IntToStrRadix(x, radix);
End;

Function BiHex(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'hex()');
 Result := VStr(RadixStr(a[0], 16, '0x'));
End;

Function BiOct(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'oct()');
 Result := VStr(RadixStr(a[0], 8, '0o'));
End;

Function BiBin(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'bin()');
 Result := VStr(RadixStr(a[0], 2, '0b'));
End;

Function BiRepr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'repr()');
 Result := VStr(ReprVal(a[0]));
End;

Function BiAscii(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'ascii()');
 Result := VStr(AsciiVal(a[0]));
End;

Function BiCallable(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'callable()');
 Result := VBool(IsCallable(a[0]));
End;

Function BiId(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'id()');
 If a[0].k = vkObj Then Result := VInt(Int64(PtrUInt(a[0].o)))
 Else If a[0].k = vkNone Then Result := VInt(Int64(PtrUInt(vEllipsis.o)) + 16)
 Else Result := VInt(a[0].i * 32 + 1000000);
End;

Function BiHash(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'hash()');
 Result := VInt(HashVal(a[0]));
End;

Function BiDivmod(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 q, r: TVal;
 x, y, fq, fr2: Double;
 f: TVal;
Begin
 NeedArgs(n, 2, 2, 'divmod()');
 If IsIntVal(a[0]) And IsIntVal(a[1]) Then Begin
  IntDivMod(a[0], a[1], q, r);
  Result := Tup2(q, r);
  Exit;
 End;
 If IsNumVal(a[0]) And IsNumVal(a[1]) Then Begin
  x := NumToDouble(a[0]);
  y := NumToDouble(a[1]);
  If y = 0 Then RaiseExc(exZeroDivision, 'float divmod()');
  fr2 := x - y * Floor(x / y);
  fr2 := FMod(x, y);
  If (fr2 <> 0) And ((fr2 < 0) <> (y < 0)) Then fr2 := fr2 + y;
  fq := Floor((x - fr2) / y + 0.5);
  If fq = 0 Then fq := 0;
  Result := Tup2(VFloat(fq), VFloat(fr2));
  Exit;
 End;
 If (a[0].k = vkObj) And LookupType(a[0].o.cls, '__divmod__', f) Then Begin
  Result := Call2(f, a[0], a[1]);
  Exit;
 End;
 TypeErr('unsupported operand type(s) for divmod(): ''' + TypeName(a[0]) +
  ''' and ''' + TypeName(a[1]) + '''');
 Result := vNone;
End;

Function BiPow(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 3, 'pow()');
 If (n = 3) And (a[2].k <> vkNone) Then Begin
  If Not (IsIntVal(a[0]) And IsIntVal(a[1]) And IsIntVal(a[2])) Then
   TypeErr('pow() 3rd argument not allowed unless all arguments are ' +
    'integers');
  If IntSign(a[2]) = 0 Then ValueErr('pow() 3rd argument cannot be 0');
  If IntSign(a[1]) < 0 Then ValueErr('pow() 2nd argument cannot be negative' +
   ' when 3rd argument specified');
  Result := IntPowMod(a[0], a[1], a[2]);
  Exit;
 End;
 Result := BinaryOp(bopPow, a[0], a[1]);
End;

Function ParseIntStr(Const s0: AnsiString; base: Integer; Var ok: Boolean):
 TVal;
Var
 s, t: AnsiString;
 neg: Boolean;
 i: Integer;
 prev: Char;
Begin
 ok := False;
 Result := VInt(0);
 s := Trim(s0);
 If s = '' Then Exit;
 neg := False;
 i := 1;
 If (s[1] = '+') Or (s[1] = '-') Then Begin
  neg := s[1] = '-';
  i := 2;
 End;
 t := Copy(s, i, Length(s));
 If (Length(t) >= 2) And (t[1] = '0') Then Begin
  If (t[2] In ['x', 'X']) And ((base = 16) Or (base = 0)) Then Begin
   base := 16;
   t := Copy(t, 3, Length(t));
  End
  Else If (t[2] In ['o', 'O']) And ((base = 8) Or (base = 0)) Then Begin
   base := 8;
   t := Copy(t, 3, Length(t));
  End
  Else If (t[2] In ['b', 'B']) And ((base = 2) Or (base = 0)) Then Begin
   base := 2;
   t := Copy(t, 3, Length(t));
  End
  Else If base = 0 Then Begin
   { 0 initial en base 0 : seulement des zeros }
   If Trim(t) <> StringOfChar('0', Length(t)) Then Exit;
   base := 10;
  End;
 End;
 If base = 0 Then base := 10;
 { soulignements }
 If (t = '') Or (t[1] = '_') Or (t[Length(t)] = '_') Then Exit;
 prev := ' ';
 For i := 1 To Length(t) Do Begin
  If (t[i] = '_') And (prev = '_') Then Exit;
  prev := t[i];
 End;
 t := StringReplace(t, '_', '', [rfReplaceAll]);
 Result := ParseIntDigits(t, base, ok);
 If ok And neg Then Result := IntNeg(Result);
End;

Function ToIntVal(Const v: TVal): TVal;
Var
 f: TVal;
 r: TVal;
Begin
 If IsIntVal(v) Then Begin
  If v.k = vkBool Then Result := VInt(v.i) Else Result := v;
  Exit;
 End;
 If v.k = vkFloat Then Begin
  Result := DoubleToInt(Int(v.d));
  Exit;
 End;
 If v.k = vkObj Then Begin
  If v.o Is TPyStr Then Begin
   Result := vNone;
   Exit;
  End;
  If LookupType(v.o.cls, '__int__', f) Then Begin
   r := Call1(f, v);
   If IsIntVal(r) Then Begin
    Result := r;
    Exit;
   End;
   TypeErr('__int__ returned non-int (type ' + TypeName(r) + ')');
  End;
  If LookupType(v.o.cls, '__index__', f) Then Begin
   Result := Call1(f, v);
   Exit;
  End;
  If LookupType(v.o.cls, '__trunc__', f) Then Begin
   Result := Call1(f, v);
   Exit;
  End;
 End;
 TypeErr('int() argument must be a string, a bytes-like object or a ' +
  'number, not ''' + TypeName(v) + '''');
 Result := vNone;
End;

Function IntCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 base: Integer;
 ok: Boolean;
 v: TVal;
 s: AnsiString;
Begin
 If n = 0 Then Begin
  Result := VInt(0);
  Exit;
 End;
 base := 10;
 If (n > 1) Or KwGet(kw, 'base', v) Then Begin
  If n > 1 Then v := a[1];
  base := IndexVal(v);
  If (base <> 0) And ((base < 2) Or (base > 36)) Then
   ValueErr('int() base must be >= 2 and <= 36, or 0');
  If Not (IsStrVal(a[0]) Or ((a[0].k = vkObj) And (a[0].o Is TPyBytes))) Then
   TypeErr('int() can''t convert non-string with explicit base');
 End;
 If IsStrVal(a[0]) Or ((a[0].k = vkObj) And (a[0].o Is TPyBytes)) Then Begin
  If IsStrVal(a[0]) Then s := TPyStr(a[0].o).s Else s := TPyBytes(a[0].o).s;
  Result := ParseIntStr(s, base, ok);
  If Not ok Then
   ValueErr('invalid literal for int() with base ' + IntToStr(base) + ': ' +
    ReprVal(a[0]));
  Exit;
 End;
 Result := ToIntVal(a[0]);
End;

Function FloatFromStr(Const s0: AnsiString; Var ok: Boolean): Double;
Var
 s: AnsiString;
 i: Integer;
Begin
 s := Trim(s0);
 ok := False;
 Result := 0;
 If (s = '') Then Exit;
 If Pos('_', s) > 0 Then Begin
  For i := 1 To Length(s) Do
   If s[i] = '_' Then Begin
    If (i = 1) Or (i = Length(s)) Or Not (s[i - 1] In ['0'..'9']) Or
     Not (s[i + 1] In ['0'..'9']) Then Exit;
   End;
  s := StringReplace(s, '_', '', [rfReplaceAll]);
 End;
 Result := ParseFloatStr(s, ok);
End;

Function ToFloatVal(Const v: TVal): Double;
Var
 f, r: TVal;
 ok: Boolean;
Begin
 If v.k = vkFloat Then Begin
  Result := v.d;
  Exit;
 End;
 If IsIntVal(v) Then Begin
  Result := IntToDouble(v);
  Exit;
 End;
 If IsStrVal(v) Then Begin
  Result := FloatFromStr(TPyStr(v.o).s, ok);
  If Not ok Then ValueErr('could not convert string to float: ' + ReprVal(v));
  Exit;
 End;
 If (v.k = vkObj) And (v.o Is TPyBytes) Then Begin
  Result := FloatFromStr(TPyBytes(v.o).s, ok);
  If Not ok Then ValueErr('could not convert string to float: ' + ReprVal(v));
  Exit;
 End;
 If v.k = vkObj Then Begin
  If LookupType(v.o.cls, '__float__', f) Then Begin
   r := Call1(f, v);
   If r.k <> vkFloat Then TypeErr('__float__ returned non-float');
   Result := r.d;
   Exit;
  End;
  If LookupType(v.o.cls, '__index__', f) Then Begin
   r := Call1(f, v);
   Result := IntToDouble(r);
   Exit;
  End;
 End;
 TypeErr('float() argument must be a string or a number, not ''' +
  TypeName(v) + '''');
 Result := 0;
End;

Function FloatCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If n = 0 Then Result := VFloat(0)
 Else Result := VFloat(ToFloatVal(a[0]));
End;

Function StrCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 enc: AnsiString;
Begin
 If n = 0 Then Begin
  Result := VStr('');
  Exit;
 End;
 If (n > 1) Or (kw <> Nil) Then Begin
  If (a[0].k = vkObj) And (a[0].o Is TPyBytes) Then Begin
   enc := 'utf-8';
   Result := VStr(TPyBytes(a[0].o).s);
   Exit;
  End;
 End;
 If IsStrVal(a[0]) And Not a[0].o.cls.userdef Then Result := a[0]
 Else Result := VStr(StrVal(a[0]));
End;

Function BoolCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If n = 0 Then Result := vFalse
 Else Result := VBool(IsTrue(a[0]));
End;

Function BiIsInstance(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
 f, r: TVal;
 c: TVal;
 args: Array[0..1] Of TVal;
Begin
 NeedArgs(n, 2, 2, 'isinstance()');
 c := a[1];
 If (c.k = vkObj) And (c.o Is TPyTuple) Then Begin
  For i := 0 To High(TPyTuple(c.o).items) Do Begin
   args[0] := a[0];
   args[1] := TPyTuple(c.o).items[i];
   If BiIsInstance(@args[0], 2, Nil).i <> 0 Then Begin
    Result := vTrue;
    Exit;
   End;
  End;
  Result := vFalse;
  Exit;
 End;
 If Not ((c.k = vkObj) And (c.o Is TPyType)) Then
  TypeErr('isinstance() arg 2 must be a type or tuple of types');
 If (c.o.cls <> tyType) And c.o.cls.userdef And
  LookupType(c.o.cls, '__instancecheck__', f) And (f.k = vkObj) And
  (f.o Is TPyFunc) Then Begin
  r := Call2(f, c, a[0]);
  Result := VBool(IsTrue(r));
  Exit;
 End;
 Result := VBool(IsInstance(a[0], TPyType(c.o)));
End;

Function BiIsSubclass(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
 f, r: TVal;
 c: TVal;
 args: Array[0..1] Of TVal;
Begin
 NeedArgs(n, 2, 2, 'issubclass()');
 c := a[1];
 If Not ((a[0].k = vkObj) And (a[0].o Is TPyType)) Then
  TypeErr('issubclass() arg 1 must be a class');
 If (c.k = vkObj) And (c.o Is TPyTuple) Then Begin
  For i := 0 To High(TPyTuple(c.o).items) Do Begin
   args[0] := a[0];
   args[1] := TPyTuple(c.o).items[i];
   If BiIsSubclass(@args[0], 2, Nil).i <> 0 Then Begin
    Result := vTrue;
    Exit;
   End;
  End;
  Result := vFalse;
  Exit;
 End;
 If Not ((c.k = vkObj) And (c.o Is TPyType)) Then
  TypeErr('issubclass() arg 2 must be a class or tuple of classes');
 If (c.o.cls <> tyType) And c.o.cls.userdef And
  LookupType(c.o.cls, '__subclasscheck__', f) And (f.k = vkObj) And
  (f.o Is TPyFunc) Then Begin
  r := Call2(f, c, a[0]);
  Result := VBool(IsTrue(r));
  Exit;
 End;
 Result := VBool(TypeIsSub(TPyType(a[0].o), TPyType(c.o)));
End;

Function BiIter(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 ci: TCallIter;
Begin
 NeedArgs(n, 1, 2, 'iter()');
 If n = 2 Then Begin
  ci := TCallIter.Create(tyIter);
  ci.fn := a[0];
  ci.sentinel := a[1];
  Result := VObj(ci);
 End
 Else Result := IterOf(a[0]);
End;

Function BiNext(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 NeedArgs(n, 1, 2, 'next()');
 If IterNextVal(a[0], r) Then Result := r
 Else Begin
  If n > 1 Then Result := a[1]
  Else RaiseStopIteration(vNone);
 End;
End;

Function BiGetattr(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
 nm: TPyStr;
Begin
 NeedArgs(n, 2, 3, 'getattr()');
 If Not IsStrVal(a[1]) Then
  TypeErr('getattr(): attribute name must be string');
 nm := InternStr(TPyStr(a[1].o).s);
 If n = 3 Then Begin
  Try
   If GetAttrOpt(a[0], nm, r) Then Result := r Else Result := a[2];
  Except
   On E: EPyError Do Begin
    If IsInstance(VObj(E.exc), exAttributeError) Then Result := a[2]
    Else Raise;
   End;
  End;
 End
 Else Result := GetAttrO(a[0], nm);
End;

Function BiSetattr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 3, 3, 'setattr()');
 If Not IsStrVal(a[1]) Then
  TypeErr('setattr(): attribute name must be string');
 SetAttrO(a[0], InternStr(TPyStr(a[1].o).s), a[2]);
 Result := vNone;
End;

Function BiDelattr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'delattr()');
 If Not IsStrVal(a[1]) Then
  TypeErr('delattr(): attribute name must be string');
 DelAttrO(a[0], InternStr(TPyStr(a[1].o).s));
 Result := vNone;
End;

Function BiHasattr(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'hasattr()');
 If Not IsStrVal(a[1]) Then
  TypeErr('hasattr(): attribute name must be string');
 Result := VBool(HasAttr(a[0], TPyStr(a[1].o).s));
End;

Function BiGlobals(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(CurFrame.globals);
End;

Function FrameLocalsDict(f: TFrame): TPyDict;
Var
 d: TPyDict;
 i, nl: Integer;
Begin
 If f.locals <> Nil Then Begin
  Result := f.locals;
  Exit;
 End;
 d := TPyDict.Make;
 nl := Length(f.code.varnames);
 For i := 0 To nl - 1 Do
  If f.base[i].k <> vkNull Then d.SetS(f.code.varnames[i], f.base[i]);
 For i := 0 To High(f.code.cellvars) Do
  If (f.base[nl + i].k = vkObj) And (TPyCell(f.base[nl + i].o).v.k <> vkNull)
   Then d.SetS(f.code.cellvars[i], TPyCell(f.base[nl + i].o).v);
 For i := 0 To High(f.code.freevars) Do
  If (f.base[nl + Length(f.code.cellvars) + i].k = vkObj) And
   (TPyCell(f.base[nl + Length(f.code.cellvars) + i].o).v.k <> vkNull) Then
   d.SetS(f.code.freevars[i], TPyCell(f.base[nl + Length(f.code.cellvars) +
    i].o).v);
 Result := d;
End;

Function BiLocals(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(FrameLocalsDict(CurFrame));
End;

Function CollectNames(Const o: TVal): TPyList;
Var
 names: TPyDict;
 i, j: Integer;
 t: TPyType;
 res: TPyList;
 arr: TValArr;
Begin
 names := TPyDict.Make;
 If (o.k = vkObj) And (o.o Is TPyType) Then Begin
  t := TPyType(o.o);
  For i := 0 To High(t.mro) Do
   For j := 0 To t.mro[i].idict.nent - 1 Do
    If t.mro[i].idict.ent[j].key.k <> vkNull Then
     names.SetItem(t.mro[i].idict.ent[j].key, vNone);
 End
 Else If (o.k = vkObj) And (o.o Is TPyModule) Then Begin
  For j := 0 To o.o.idict.nent - 1 Do
   If o.o.idict.ent[j].key.k <> vkNull Then
    names.SetItem(o.o.idict.ent[j].key, vNone);
 End
 Else Begin
  If (o.k = vkObj) And (o.o.idict <> Nil) Then
   For j := 0 To o.o.idict.nent - 1 Do
    If o.o.idict.ent[j].key.k <> vkNull Then
     names.SetItem(o.o.idict.ent[j].key, vNone);
  t := TypeOf(o);
  For i := 0 To High(t.mro) Do
   For j := 0 To t.mro[i].idict.nent - 1 Do
    If t.mro[i].idict.ent[j].key.k <> vkNull Then
     names.SetItem(t.mro[i].idict.ent[j].key, vNone);
 End;
 res := NewList;
 SetLength(arr, 0);
 For j := 0 To names.nent - 1 Do
  If names.ent[j].key.k <> vkNull Then res.Add(names.ent[j].key);
 Result := res;
End;

Procedure SortVals(Var arr: TValArr; Const key: TVal; reverse: Boolean);
Forward;

Function BiDir(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 arr: TValArr;
 i: Integer;
 f: TVal;
Begin
 If n = 0 Then Begin
  l := NewList;
  With FrameLocalsDict(CurFrame) Do
   For i := 0 To nent - 1 Do
    If ent[i].key.k <> vkNull Then l.Add(ent[i].key);
 End
 Else Begin
  If (a[0].k = vkObj) And a[0].o.cls.userdef And
   LookupType(a[0].o.cls, '__dir__', f) And (f.k = vkObj) And
   (f.o Is TPyFunc) Then Begin
   l := ListFromIter(Call1(f, a[0]));
  End
  Else l := CollectNames(a[0]);
 End;
 SetLength(arr, l.cnt);
 For i := 0 To l.cnt - 1 Do arr[i] := l.items[i];
 SortVals(arr, vNone, False);
 For i := 0 To l.cnt - 1 Do l.items[i] := arr[i];
 Result := VObj(l);
End;

Function BiVars(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If n = 0 Then Begin
  Result := VObj(FrameLocalsDict(CurFrame));
  Exit;
 End;
 If (a[0].k = vkObj) And (a[0].o.idict <> Nil) And Not (a[0].o Is TPyType) Then
  Result := VObj(a[0].o.idict)
 Else If (a[0].k = vkObj) And (a[0].o Is TPyType) Then
  Result := VObj(a[0].o.idict.Copy)
 Else TypeErr('vars() argument must have __dict__ attribute');
End;

{ ---- tri ---- }
Type
 TKeyed = Record
  key, val: TVal;
 End;

Procedure SortVals(Var arr: TValArr; Const key: TVal; reverse: Boolean);
Var
 n, i: Integer;
 keys, tmpk: Array Of TVal;
 idx, tmpi: Array Of Integer;

 Procedure MSort(lo, hi: Integer);
 Var
  mid, p, q, k: Integer;
 Begin
  If hi - lo < 2 Then Exit;
  mid := (lo + hi) Div 2;
  MSort(lo, mid);
  MSort(mid, hi);
  p := lo;
  q := mid;
  k := lo;
  While (p < mid) And (q < hi) Do Begin
   If CmpLess(keys[idx[q]], keys[idx[p]]) Then Begin
    tmpi[k] := idx[q];
    Inc(q);
   End
   Else Begin
    tmpi[k] := idx[p];
    Inc(p);
   End;
   Inc(k);
  End;
  While p < mid Do Begin
   tmpi[k] := idx[p];
   Inc(p);
   Inc(k);
  End;
  While q < hi Do Begin
   tmpi[k] := idx[q];
   Inc(q);
   Inc(k);
  End;
  For k := lo To hi - 1 Do idx[k] := tmpi[k];
 End;

Var
 res: TValArr;
 j: Integer;
Begin
 n := Length(arr);
 If n < 2 Then Exit;
 SetLength(keys, n);
 SetLength(idx, n);
 SetLength(tmpi, n);
 For i := 0 To n - 1 Do Begin
  If key.k = vkNone Then keys[i] := arr[i] Else keys[i] := Call1(key, arr[i]);
  idx[i] := i;
 End;
 If reverse Then Begin
  { inverser, trier de facon stable, inverser : conserve la stabilite }
  For i := 0 To (n Div 2) - 1 Do Begin
   j := idx[i];
   idx[i] := idx[n - 1 - i];
   idx[n - 1 - i] := j;
  End;
 End;
 MSort(0, n);
 If reverse Then
  For i := 0 To (n Div 2) - 1 Do Begin
   j := idx[i];
   idx[i] := idx[n - 1 - i];
   idx[n - 1 - i] := j;
  End;
 SetLength(res, n);
 For i := 0 To n - 1 Do res[i] := arr[idx[i]];
 arr := res;
 tmpk := Nil;
End;

Function BiSorted(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 key, rev: TVal;
Begin
 If n < 1 Then TypeErr('sorted expected 1 argument, got 0');
 If n > 1 Then TypeErr('sorted expected 1 argument, got ' + IntToStr(n));
 arr := IterToArr(a[0]);
 key := vNone;
 rev := vFalse;
 KwGet(kw, 'key', key);
 KwGet(kw, 'reverse', rev);
 SortVals(arr, key, IsTrue(rev));
 Result := VObj(ListFromVals(arr));
End;

Function MinMax(a: PVal; n: Integer; kw: TPyDict; isMax: Boolean): TVal;
Var
 it, x, best, bk, k, key, deflt: TVal;
 first: Boolean;
 hasDef: Boolean;
 nm: AnsiString;
 i: Integer;
 arr: TValArr;
 op: Integer;
Begin
 If isMax Then nm := 'max' Else nm := 'min';
 If isMax Then op := 4 Else op := 0;
 key := vNone;
 hasDef := KwGet(kw, 'default', deflt);
 KwGet(kw, 'key', key);
 If n = 0 Then
  TypeErr(nm + ' expected 1 arguments, got 0');
 If n = 1 Then arr := IterToArr(a[0])
 Else Begin
  SetLength(arr, n);
  For i := 0 To n - 1 Do arr[i] := a[i];
 End;
 If Length(arr) = 0 Then Begin
  If hasDef Then Begin
   Result := deflt;
   Exit;
  End;
  ValueErr(nm + '() arg is an empty sequence');
 End;
 best := arr[0];
 If key.k = vkNone Then bk := best Else bk := Call1(key, best);
 For i := 1 To High(arr) Do Begin
  x := arr[i];
  If key.k = vkNone Then k := x Else k := Call1(key, x);
  If ValCompare(k, bk, op) Then Begin
   best := x;
   bk := k;
  End;
 End;
 first := False;
 it := vNone;
 Result := best;
End;

Function BiMin(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := MinMax(a, n, kw, False);
End;

Function BiMax(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := MinMax(a, n, kw, True);
End;

Function BiSum(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 it, x, acc: TVal;
 fsum: Double;
 allFloat: Boolean;
Begin
 NeedArgs(n, 1, 2, 'sum()');
 acc := VInt(0);
 If n > 1 Then acc := a[1]
 Else KwGet(kw, 'start', acc);
 If IsStrVal(acc) Then
  TypeErr('sum() can''t sum strings [use ''''.join(seq) instead]');
 it := IterOf(a[0]);
 While IterNextVal(it, x) Do Begin
  If (acc.k = vkInt) And (x.k = vkInt) Then Begin
   fsum := acc.i + x.i;
   If Abs(fsum) < 4.0e18 Then acc := VInt(acc.i + x.i)
   Else acc := IntAdd(acc, x);
  End
  Else If (acc.k = vkFloat) And (x.k = vkFloat) Then
   acc := VFloat(acc.d + x.d)
  Else acc := BinaryOp(bopAdd, acc, x);
 End;
 allFloat := False;
 Result := acc;
End;

Function BiReversed(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 f: TVal;
 arr: TValArr;
 i: Integer;
Begin
 NeedArgs(n, 1, 1, 'reversed()');
 If (a[0].k = vkObj) And (a[0].o Is TPyList) And Not a[0].o.cls.userdef Then Begin
  Result := VObj(NewListIter(TPyList(a[0].o), True));
  Exit;
 End;
 If (a[0].k = vkObj) And a[0].o.cls.userdef And
  LookupType(a[0].o.cls, '__reversed__', f) Then Begin
  Result := Call1(f, a[0]);
  Exit;
 End;
 If (a[0].k = vkObj) And ((a[0].o Is TPyTuple) Or (a[0].o Is TPyStr) Or
  (a[0].o Is TPyRange) Or (a[0].o Is TPyBytes) Or (a[0].o.cls.userdef)) Then
  Begin
  arr := IterToArr(a[0]);
  l := NewList;
  For i := High(arr) DownTo 0 Do l.Add(arr[i]);
  Result := VObj(NewListIter(l, False));
  Exit;
 End;
 TypeErr('''' + TypeName(a[0]) + ''' object is not reversible');
 Result := vNone;
End;

Function BiEnumerate(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 e: TEnumIter;
 st: TVal;
Begin
 NeedArgs(n, 1, 2, 'enumerate()');
 e := TEnumIter.Create(tyIter);
 e.it := IterOf(a[0]);
 e.n := VInt(0);
 If n > 1 Then e.n := a[1]
 Else If KwGet(kw, 'start', st) Then e.n := st;
 Result := VObj(e);
End;

Function BiZip(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 z: TZipIter;
 i: Integer;
Begin
 z := TZipIter.Create(tyIter);
 SetLength(z.its, n);
 For i := 0 To n - 1 Do z.its[i] := IterOf(a[i]);
 Result := VObj(z);
End;

Function BiMap(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 m: TMapIter;
 i: Integer;
Begin
 If n < 2 Then TypeErr('map() must have at least two arguments.');
 m := TMapIter.Create(tyIter);
 m.fn := a[0];
 SetLength(m.its, n - 1);
 For i := 1 To n - 1 Do m.its[i - 1] := IterOf(a[i]);
 Result := VObj(m);
End;

Function BiFilter(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 m: TFilterIter;
Begin
 NeedArgs(n, 2, 2, 'filter()');
 m := TFilterIter.Create(tyIter);
 m.fn := a[0];
 m.it := IterOf(a[1]);
 Result := VObj(m);
End;

Function BiRound(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, fl, diff: Double;
 nd: Int64;
 s: AnsiString;
 ok: Boolean;
 f: TVal;
 p10, q, r, two, half: TVal;
 ndv: TVal;
Begin
 NeedArgs(n, 1, 2, 'round()');
 ndv := vNone;
 If n > 1 Then ndv := a[1] Else KwGet(kw, 'ndigits', ndv);
 If (a[0].k = vkObj) And a[0].o.cls.userdef And
  LookupType(a[0].o.cls, '__round__', f) Then Begin
  If ndv.k = vkNone Then Result := Call1(f, a[0])
  Else Result := Call2(f, a[0], ndv);
  Exit;
 End;
 If IsIntVal(a[0]) Then Begin
  If ndv.k = vkNone Then Begin
   Result := a[0];
   If a[0].k = vkBool Then Result := VInt(a[0].i);
   Exit;
  End;
  nd := IndexVal(ndv);
  If nd >= 0 Then Begin
   Result := a[0];
   Exit;
  End;
  p10 := IntPow(VInt(10), VInt(-nd));
  IntDivMod(a[0], p10, q, r);
  two := VInt(2);
  half := IntFloorDiv(p10, two);
  If IntCmp(IntMul(r, two), p10) > 0 Then q := IntAdd(q, VInt(1))
  Else If IntCmp(IntMul(r, two), p10) = 0 Then Begin
   If IntSign(IntMod(q, two)) <> 0 Then q := IntAdd(q, VInt(1));
  End;
  Result := IntMul(q, p10);
  Exit;
 End;
 If a[0].k = vkFloat Then Begin
  x := a[0].d;
  If ndv.k = vkNone Then Begin
   If IsNan(x) Then ValueErr('cannot convert float NaN to integer');
   If IsInfinite(x) Then
    RaiseExc(exOverflow, 'cannot convert float infinity to integer');
   fl := Floor(x);
   diff := x - fl;
   If diff < 0.5 Then x := fl
   Else If diff > 0.5 Then x := fl + 1
   Else Begin
    If Frac(fl / 2) = 0 Then x := fl Else x := fl + 1;
   End;
   Result := DoubleToInt(x);
   Exit;
  End;
  nd := IndexVal(ndv);
  If IsNan(x) Or IsInfinite(x) Then Begin
   Result := a[0];
   Exit;
  End;
  If nd > 300 Then Begin
   Result := a[0];
   Exit;
  End;
  If nd >= 0 Then Begin
   s := FmtFixed(Abs(x), nd);
   x := ParseFloatStr(s, ok);
   If FloatSignBit(a[0].d) Then x := -x;
   Result := VFloat(x);
  End
  Else Begin
   If nd < -308 Then x := 0
   Else Begin
    p10 := IntPow(VInt(10), VInt(-nd));
    fl := IntToDouble(p10);
    diff := x / fl;
    s := FmtFixed(Abs(diff), 0);
    x := ParseFloatStr(s, ok) * fl;
    If FloatSignBit(a[0].d) Then x := -x;
   End;
   Result := VFloat(x);
  End;
  Exit;
 End;
 TypeErr('type ' + TypeName(a[0]) + ' doesn''t define __round__ method');
 Result := vNone;
End;

Function BiFormat(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 2, 'format()');
 If n > 1 Then Result := VStr(FormatValue(a[0], StrOf(a[1])))
 Else Result := VStr(FormatValue(a[0], ''));
End;

Function BiInput(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 line: AnsiString;
Begin
 NeedArgs(n, 0, 1, 'input()');
 If n = 1 Then Begin
  PyWriteTo(vNone, StrVal(a[0]));
 End;
 OutFlush;
 If Not StdinReadLine(line) Then RaiseExc(exEOFError, 'EOF when reading a line');
 If (line <> '') And (line[Length(line)] = #10) Then
  Delete(line, Length(line), 1);
 If (line <> '') And (line[Length(line)] = #13) Then
  Delete(line, Length(line), 1);
 Result := VStr(line);
End;

Function BiSlice(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 3, 'slice()');
 If n = 1 Then Result := NewSlice(vNone, a[0], vNone)
 Else If n = 2 Then Result := NewSlice(a[0], a[1], vNone)
 Else Result := NewSlice(a[0], a[1], a[2]);
End;

Function RangeCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyRange;
 st, sp, stp: Int64;
 q: Int64;
Begin
 NeedArgs(n, 1, 3, 'range');
 If n = 1 Then Begin
  st := 0;
  sp := IndexVal(a[0]);
  stp := 1;
 End
 Else Begin
  st := IndexVal(a[0]);
  sp := IndexVal(a[1]);
  If n = 3 Then stp := IndexVal(a[2]) Else stp := 1;
 End;
 If stp = 0 Then ValueErr('range() arg 3 must not be zero');
 r := TPyRange.Create(tyRange);
 r.start := st;
 r.stop := sp;
 r.step := stp;
 If stp > 0 Then Begin
  If sp > st Then r.len := (sp - st - 1) Div stp + 1 Else r.len := 0;
 End
 Else Begin
  If st > sp Then r.len := (st - sp - 1) Div (-stp) + 1 Else r.len := 0;
 End;
 q := 0;
 Result := VObj(r);
End;

Function BiObjectCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TPyObj;
Begin
 If (n > 0) Or ((kw <> Nil) And (kw.used > 0)) Then
  TypeErr('object() takes no arguments');
 o := TPyObj.Create(tyObject);
 o.idict := TPyDict.Make;
 Result := VObj(o);
End;

Function BiSuper(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 sp: TPySuper;
 f: TFrame;
 co: TPyCode;
 i, k: Integer;
 cell: TPyCell;
 obj: TVal;
 cls: TPyType;
Begin
 sp := TPySuper.Create(tySuper);
 If n = 0 Then Begin
  f := CurFrame;
  If f = Nil Then RaiseExc(exRuntimeError, 'super(): no current frame');
  co := f.code;
  If Length(co.varnames) + Length(co.cellvars) = 0 Then
   RaiseExc(exRuntimeError, 'super(): no arguments');
  k := IndexOfStr(co.freevars, '__class__');
  If k < 0 Then RaiseExc(exRuntimeError, 'super(): __class__ cell not found');
  cell := TPyCell(f.base[Length(co.varnames) + Length(co.cellvars) + k].o);
  If cell.v.k <> vkObj Then RaiseExc(exRuntimeError,
   'super(): empty __class__ cell');
  cls := TPyType(cell.v.o);
  If co.argcount = 0 Then
   RaiseExc(exRuntimeError, 'super(): no arguments');
  obj := f.base[0];
  If obj.k = vkNull Then Begin
   { parametre capture par une cellule }
   i := IndexOfStr(co.cellvars, co.varnames[0]);
   If i >= 0 Then obj := TPyCell(f.base[Length(co.varnames) + i].o).v;
  End;
  If obj.k = vkNull Then RaiseExc(exRuntimeError, 'super(): arg[0] deleted');
  sp.thisCls := cls;
  sp.obj := obj;
 End
 Else Begin
  NeedArgs(n, 1, 2, 'super()');
  If Not ((a[0].k = vkObj) And (a[0].o Is TPyType)) Then
   TypeErr('super() argument 1 must be type, not ' + TypeName(a[0]));
  sp.thisCls := TPyType(a[0].o);
  If n = 2 Then sp.obj := a[1] Else sp.obj := vNone;
 End;
 If sp.obj.k = vkNone Then sp.objType := Nil
 Else If (sp.obj.k = vkObj) And (sp.obj.o Is TPyType) And
  TypeIsSub(TPyType(sp.obj.o), sp.thisCls) Then
  sp.objType := TPyType(sp.obj.o)
 Else If IsInstance(sp.obj, sp.thisCls) Then sp.objType := TypeOf(sp.obj)
 Else TypeErr('super(type, obj): obj must be an instance or subtype of type');
 Result := VObj(sp);
End;

Function PropertyCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: TPyProperty;
 v: TVal;
Begin
 p := TPyProperty.Create(tyProperty);
 p.fget := vNone;
 p.fset := vNone;
 p.fdel := vNone;
 p.doc := vNone;
 If n > 0 Then p.fget := a[0] Else If KwGet(kw, 'fget', v) Then p.fget := v;
 If n > 1 Then p.fset := a[1] Else If KwGet(kw, 'fset', v) Then p.fset := v;
 If n > 2 Then p.fdel := a[2] Else If KwGet(kw, 'fdel', v) Then p.fdel := v;
 If n > 3 Then p.doc := a[3] Else If KwGet(kw, 'doc', v) Then p.doc := v;
 If (p.doc.k = vkNone) And (p.fget.k = vkObj) And (p.fget.o Is TPyFunc) Then
  p.doc := NoneIfNull(TPyFunc(p.fget.o).doc);
 Result := VObj(p);
End;

Function PropGetter(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p, np: TPyProperty;
Begin
 p := TPyProperty(a[0].o);
 np := TPyProperty.Create(tyProperty);
 np.fget := p.fget;
 np.fset := p.fset;
 np.fdel := p.fdel;
 np.doc := p.doc;
 Result := VObj(np);
End;

Function PropSetter(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := PropGetter(a, n, kw);
 TPyProperty(Result.o).fset := a[1];
End;

Function PropGetterSet(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := PropGetter(a, n, kw);
 TPyProperty(Result.o).fget := a[1];
End;

Function PropDeleter(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := PropGetter(a, n, kw);
 TPyProperty(Result.o).fdel := a[1];
End;

Function StaticMethodCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'staticmethod');
 Result := VObj(NewWrapper(tyStaticMethod, a[0]));
End;

Function ClassMethodCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 1, 1, 'classmethod');
 Result := VObj(NewWrapper(tyClassMethod, a[0]));
End;

Function BiExit(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If n > 0 Then
  Raise EPyError.Make(MakeExcArgs(exSystemExit, [a[0]]))
 Else Raise EPyError.Make(MakeExcArgs(exSystemExit, []));
 Result := vNone;
End;

Function BiHelp(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If n = 0 Then Begin
  OutWrite('Type help() for interactive help, or help(object) for help ' +
   'about object.' + #10);
 End
 Else OutWrite('Help on ' + ReprVal(a[0]) + #10);
 Result := vNone;
End;

Function BiBuildClass(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := BuildClass(a, n, kw);
End;

Function ExcFromSyntax(e: ESyntax; Const fname: AnsiString): TPyObj;
Var
 o: TPyObj;
 info: TPyTuple;
 col: Integer;
Begin
 o := MakeExcArgs(e.kind, []);
 info := NewTuple(4);
 info.items[0] := VStr(fname);
 info.items[1] := VInt(e.line);
 col := Utf8Len(Copy(e.text, 1, e.col)) + 1;
 info.items[2] := VInt(col);
 If e.text <> '' Then info.items[3] := VStr(e.text) Else info.items[3] := vNone;
 o.idict.SetS('args', Tup2(VStr(e.msg), VObj(info)));
 o.idict.SetS('msg', VStr(e.msg));
 o.idict.SetS('filename', VStr(fname));
 o.idict.SetS('lineno', VInt(e.line));
 o.idict.SetS('offset', VInt(col));
 o.idict.SetS('text', info.items[3]);
 Result := o;
End;

Function CompileSafe(Const src, fname: AnsiString; mode: Integer): TPyCode;
Begin
 Try
  Result := CompileSource(src, fname, mode);
  If (Length(fname) > 0) And (fname[1] = '<') Then Result.source := Nil;
 Except
  On E: ESyntax Do Raise EPyError.Make(ExcFromSyntax(E, fname));
 End;
End;

Function RunCodeObject(code: TPyCode; g, l: TPyDict): TVal;
Var
 fr: TFrame;
Begin
 fr := NewFrame(code, Nil, g, l, False);
 SetupCells(fr, Nil);
 Result := Run(fr);
End;

Function ModuleGlobalsOfFrame: TPyDict;
Begin
 If CurFrame <> Nil Then Result := CurFrame.globals Else Result := Nil;
End;

Function SourceOf(Const v: TVal): AnsiString;
Begin
 If IsStrVal(v) Then Result := TPyStr(v.o).s
 Else If (v.k = vkObj) And (v.o Is TPyBytes) Then Result := TPyBytes(v.o).s
 Else Begin
  TypeErr('exec() arg 1 must be a string, bytes or code object');
  Result := '';
 End;
End;

Function BiExec(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 code: TPyCode;
 g, l: TPyDict;
 gv, lv: TVal;
Begin
 NeedArgs(n, 1, 3, 'exec()');
 If n > 1 Then gv := a[1] Else gv := vNone;
 If n > 2 Then lv := a[2] Else lv := vNone;
 If gv.k = vkNone Then Begin
  g := CurFrame.globals;
  If lv.k = vkNone Then l := FrameLocalsDict(CurFrame) Else l := TPyDict(lv.o);
 End
 Else Begin
  If Not ((gv.k = vkObj) And (gv.o Is TPyDict)) Then
   TypeErr('exec() globals must be a dict, not ' + TypeName(gv));
  g := TPyDict(gv.o);
  If lv.k = vkNone Then l := g Else l := TPyDict(lv.o);
 End;
 If (a[0].k = vkObj) And (a[0].o Is TPyCode) Then code := TPyCode(a[0].o)
 Else code := CompileSafe(SourceOf(a[0]), '<string>', 0);
 If Not g.HasS('__builtins__') Then g.SetS('__builtins__', VObj(BuiltinsDict));
 RunCodeObject(code, g, l);
 Result := vNone;
End;

Function BiEval(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 code: TPyCode;
 g, l: TPyDict;
 gv, lv: TVal;
 s: AnsiString;
Begin
 NeedArgs(n, 1, 3, 'eval()');
 If n > 1 Then gv := a[1] Else gv := vNone;
 If n > 2 Then lv := a[2] Else lv := vNone;
 If gv.k = vkNone Then Begin
  g := CurFrame.globals;
  If lv.k = vkNone Then l := FrameLocalsDict(CurFrame) Else l := TPyDict(lv.o);
 End
 Else Begin
  If Not ((gv.k = vkObj) And (gv.o Is TPyDict)) Then
   TypeErr('globals must be a dict');
  g := TPyDict(gv.o);
  If lv.k = vkNone Then l := g Else l := TPyDict(lv.o);
 End;
 If (a[0].k = vkObj) And (a[0].o Is TPyCode) Then code := TPyCode(a[0].o)
 Else Begin
  s := Trim(SourceOf(a[0]));
  code := CompileSafe(s, '<string>', 1);
 End;
 If Not g.HasS('__builtins__') Then g.SetS('__builtins__', VObj(BuiltinsDict));
 Result := RunCodeObject(code, g, l);
End;

Function BiCompile(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 mode: AnsiString;
 m: Integer;
Begin
 NeedArgs(n, 3, 6, 'compile()');
 mode := StrOf(a[2]);
 If mode = 'exec' Then m := 0
 Else If mode = 'eval' Then m := 1
 Else If mode = 'single' Then m := 2
 Else Begin
  ValueErr('compile() mode must be ''exec'', ''eval'' or ''single''');
  m := 0;
 End;
 If (a[0].k = vkObj) And (a[0].o Is TPyCode) Then Begin
  Result := a[0];
  Exit;
 End;
 Result := VObj(CompileSafe(SourceOf(a[0]), StrOf(a[1]), m));
End;

Function BiBytesCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: AnsiString;
 arr: TValArr;
 i: Integer;
 enc: AnsiString;
Begin
 If n = 0 Then Begin
  Result := VBytes('');
  Exit;
 End;
 If IsStrVal(a[0]) Then Begin
  If (n < 2) And (kw = Nil) Then TypeErr('string argument without an encoding');
  enc := LowerCase(StrVal(a[1]));
  s := TPyStr(a[0].o).s;
  If (enc = 'latin-1') Or (enc = 'latin1') Or (enc = 'iso-8859-1') Or
   (enc = 'ascii') Then Begin
   arr := nil;
   s := '';
   i := 1;
   While i <= Length(TPyStr(a[0].o).s) Do
    s := s + Chr(Utf8Dec(TPyStr(a[0].o).s, i) And 255);
  End;
  Result := VBytes(s);
  Exit;
 End;
 If IsIntVal(a[0]) Then Begin
  Result := VBytes(StringOfChar(#0, a[0].i));
  Exit;
 End;
 If (a[0].k = vkObj) And (a[0].o Is TPyBytes) Then Begin
  Result := VBytes(TPyBytes(a[0].o).s);
  Exit;
 End;
 arr := IterToArr(a[0]);
 s := '';
 For i := 0 To High(arr) Do Begin
  If (IndexVal(arr[i]) < 0) Or (IndexVal(arr[i]) > 255) Then
   ValueErr('bytes must be in range(0, 256)');
  s := s + Chr(IndexVal(arr[i]));
 End;
 Result := VBytes(s);
End;

Procedure InitBuiltinFuncs;
Begin
 DefFunc(BuiltinsDict, 'print', @BiPrint);
 DefFunc(BuiltinsDict, 'len', @BiLen);
 DefFunc(BuiltinsDict, 'abs', @BiAbs);
 DefFunc(BuiltinsDict, 'all', @BiAll);
 DefFunc(BuiltinsDict, 'any', @BiAny);
 DefFunc(BuiltinsDict, 'chr', @BiChr);
 DefFunc(BuiltinsDict, 'ord', @BiOrd);
 DefFunc(BuiltinsDict, 'hex', @BiHex);
 DefFunc(BuiltinsDict, 'oct', @BiOct);
 DefFunc(BuiltinsDict, 'bin', @BiBin);
 DefFunc(BuiltinsDict, 'repr', @BiRepr);
 DefFunc(BuiltinsDict, 'ascii', @BiAscii);
 DefFunc(BuiltinsDict, 'callable', @BiCallable);
 DefFunc(BuiltinsDict, 'id', @BiId);
 DefFunc(BuiltinsDict, 'hash', @BiHash);
 DefFunc(BuiltinsDict, 'divmod', @BiDivmod);
 DefFunc(BuiltinsDict, 'pow', @BiPow);
 DefFunc(BuiltinsDict, 'isinstance', @BiIsInstance);
 DefFunc(BuiltinsDict, 'issubclass', @BiIsSubclass);
 DefFunc(BuiltinsDict, 'iter', @BiIter);
 DefFunc(BuiltinsDict, 'next', @BiNext);
 DefFunc(BuiltinsDict, 'getattr', @BiGetattr);
 DefFunc(BuiltinsDict, 'setattr', @BiSetattr);
 DefFunc(BuiltinsDict, 'delattr', @BiDelattr);
 DefFunc(BuiltinsDict, 'hasattr', @BiHasattr);
 DefFunc(BuiltinsDict, 'globals', @BiGlobals);
 DefFunc(BuiltinsDict, 'locals', @BiLocals);
 DefFunc(BuiltinsDict, 'dir', @BiDir);
 DefFunc(BuiltinsDict, 'vars', @BiVars);
 DefFunc(BuiltinsDict, 'sorted', @BiSorted);
 DefFunc(BuiltinsDict, 'min', @BiMin);
 DefFunc(BuiltinsDict, 'max', @BiMax);
 DefFunc(BuiltinsDict, 'sum', @BiSum);
 DefFunc(BuiltinsDict, 'reversed', @BiReversed);
 DefFunc(BuiltinsDict, 'enumerate', @BiEnumerate);
 DefFunc(BuiltinsDict, 'zip', @BiZip);
 DefFunc(BuiltinsDict, 'map', @BiMap);
 DefFunc(BuiltinsDict, 'filter', @BiFilter);
 DefFunc(BuiltinsDict, 'round', @BiRound);
 DefFunc(BuiltinsDict, 'format', @BiFormat);
 DefFunc(BuiltinsDict, 'input', @BiInput);
 DefFunc(BuiltinsDict, 'exit', @BiExit);
 DefFunc(BuiltinsDict, 'quit', @BiExit);
 DefFunc(BuiltinsDict, 'help', @BiHelp);
 DefFunc(BuiltinsDict, 'exec', @BiExec);
 DefFunc(BuiltinsDict, 'eval', @BiEval);
 DefFunc(BuiltinsDict, 'compile', @BiCompile);
 DefFunc(BuiltinsDict, '__build_class__', @BiBuildClass);
 tyInt.ctor := @IntCtor;
 tyFloat.ctor := @FloatCtor;
 tyStr.ctor := @StrCtor;
 tyBool.ctor := @BoolCtor;
 tyRange.ctor := @RangeCtor;
 tySlice.ctor := @BiSlice;
 tySuper.ctor := @BiSuper;
 tyProperty.ctor := @PropertyCtor;
 tyStaticMethod.ctor := @StaticMethodCtor;
 tyClassMethod.ctor := @ClassMethodCtor;
 tyBytes.ctor := @BiBytesCtor;
 tyBytearray.ctor := @BiBytesCtor;
 tyObject.ctor := Nil;
 DefMethod(tyProperty, 'getter', @PropGetterSet);
 DefMethod(tyProperty, 'setter', @PropSetter);
 DefMethod(tyProperty, 'deleter', @PropDeleter);
End;

{ ------------------------------------------------------------
  Formatage : operateur % et str.format
  ------------------------------------------------------------ }
Function PercentFormat(Const fmt: AnsiString; Const arg: TVal): AnsiString;
Var
 i, n, argi: Integer;
 items: TValArr;
 isMap: Boolean;
 mapObj: TVal;
 res, key, flags, body, prefix: AnsiString;
 c: Char;
 width, prec: Integer;
 v: TVal;
 fs: TFmtSpec;
 d: Double;
 neg: Boolean;
 dig: AnsiString;
 conv: Char;
 depth: Integer;
 cp: Integer;

 Function NextArg: TVal;
 Begin
  If argi >= Length(items) Then TypeErr('not enough arguments for format ' +
   'string');
  Result := items[argi];
  Inc(argi);
 End;

 Function PadIt(Const s: AnsiString): AnsiString;
 Var
  al: Char;
 Begin
  If Pos('-', flags) > 0 Then al := '<' Else al := '>';
  Result := PadStr(s, width, ' ', al);
 End;

Begin
 If (arg.k = vkObj) And (arg.o Is TPyTuple) Then Begin
  items := Copy(TPyTuple(arg.o).items);
  isMap := False;
 End
 Else Begin
  SetLength(items, 1);
  items[0] := arg;
  isMap := (arg.k = vkObj) And ((arg.o Is TPyDict) Or
   (arg.o.cls.userdef And LookupType(arg.o.cls, '__getitem__', v))) And
   Not (arg.o Is TPyStr);
 End;
 mapObj := arg;
 argi := 0;
 res := '';
 n := Length(fmt);
 i := 1;
 While i <= n Do Begin
  c := fmt[i];
  If c <> '%' Then Begin
   res := res + c;
   Inc(i);
   Continue;
  End;
  Inc(i);
  If i > n Then ValueErr('incomplete format');
  key := '';
  v := vNone;
  If fmt[i] = '(' Then Begin
   depth := 1;
   Inc(i);
   While (i <= n) And (depth > 0) Do Begin
    If fmt[i] = '(' Then Inc(depth)
    Else If fmt[i] = ')' Then Begin
     Dec(depth);
     If depth = 0 Then Break;
    End;
    key := key + fmt[i];
    Inc(i);
   End;
   Inc(i);
   If Not isMap Then TypeErr('format requires a mapping');
   v := GetItem(mapObj, VStr(key));
  End;
  flags := '';
  While (i <= n) And (fmt[i] In ['#', '0', '-', ' ', '+']) Do Begin
   flags := flags + fmt[i];
   Inc(i);
  End;
  width := 0;
  If (i <= n) And (fmt[i] = '*') Then Begin
   width := IndexVal(NextArg);
   If width < 0 Then Begin
    flags := flags + '-';
    width := -width;
   End;
   Inc(i);
  End
  Else
   While (i <= n) And (fmt[i] In ['0'..'9']) Do Begin
    width := width * 10 + Ord(fmt[i]) - 48;
    Inc(i);
   End;
  prec := -1;
  If (i <= n) And (fmt[i] = '.') Then Begin
   Inc(i);
   prec := 0;
   If (i <= n) And (fmt[i] = '*') Then Begin
    prec := IndexVal(NextArg);
    Inc(i);
   End
   Else
    While (i <= n) And (fmt[i] In ['0'..'9']) Do Begin
     prec := prec * 10 + Ord(fmt[i]) - 48;
     Inc(i);
    End;
  End;
  While (i <= n) And (fmt[i] In ['h', 'l', 'L']) Do Inc(i);
  If i > n Then ValueErr('incomplete format');
  conv := fmt[i];
  Inc(i);
  If conv = '%' Then Begin
   res := res + '%';
   Continue;
  End;
  If key = '' Then v := NextArg;
  fs.fill := ' ';
  fs.align := '>';
  If Pos('-', flags) > 0 Then fs.align := '<';
  fs.sign := '-';
  If Pos('+', flags) > 0 Then fs.sign := '+'
  Else If Pos(' ', flags) > 0 Then fs.sign := ' ';
  fs.alt := Pos('#', flags) > 0;
  fs.zero := (Pos('0', flags) > 0) And (Pos('-', flags) = 0);
  fs.width := width;
  fs.grp := #0;
  fs.prec := prec;
  fs.typ := #0;
  Case conv Of
   's', 'r', 'a': Begin
     If conv = 's' Then body := StrVal(v)
     Else If conv = 'r' Then body := ReprVal(v)
     Else body := AsciiVal(v);
     If (prec >= 0) And (Utf8Len(body) > prec) Then
      body := CpSub(body, 0, prec);
     res := res + PadIt(body);
    End;
   'd', 'i', 'u': Begin
     If Not IsNumVal(v) Then Begin
      If (v.k = vkObj) And HasIndex(v) Then v := VInt(IndexVal(v))
      Else TypeErr('%' + conv + ' format: a number is required, not ' +
       TypeName(v));
     End;
     If v.k = vkFloat Then Begin
      If IsNan(v.d) Or IsInfinite(v.d) Then
       ValueErr('cannot convert float NaN to integer');
      v := DoubleToInt(Int(v.d));
     End;
     If v.k = vkBool Then v := VInt(v.i);
     fs.typ := 'd';
     res := res + FormatIntSpec(v, fs);
    End;
   'o', 'x', 'X': Begin
     If Not IsNumVal(v) Then
      TypeErr('%' + conv + ' format: an integer is required, not ' +
       TypeName(v));
     If v.k = vkFloat Then v := DoubleToInt(Int(v.d));
     If v.k = vkBool Then v := VInt(v.i);
     fs.typ := conv;
     res := res + FormatIntSpec(v, fs);
    End;
   'e', 'E', 'f', 'F', 'g', 'G': Begin
     If Not IsNumVal(v) Then
      TypeErr('must be real number, not ' + TypeName(v));
     fs.typ := conv;
     res := res + FormatFloatSpec(NumToDouble(v), fs);
    End;
   'c': Begin
     If IsStrVal(v) Then Begin
      If PyStrLen(TPyStr(v.o)) <> 1 Then
       TypeErr('%c requires int or char');
      body := TPyStr(v.o).s;
     End
     Else If IsIntVal(v) Then Begin
      cp := IndexVal(v);
      If (cp < 0) Or (cp > $10FFFF) Then
       RaiseExc(exOverflow, '%c arg not in range(0x110000)');
      body := Utf8Enc(cp);
     End
     Else Begin
      TypeErr('%c requires int or char');
      body := '';
     End;
     res := res + PadIt(body);
    End;
  Else
   ValueErr('unsupported format character ''' + conv + ''' (0x' +
    LowerCase(IntToHex(Ord(conv), 2)) + ') at index ' + IntToStr(i - 2));
  End;
 End;
 If (Not isMap) And (argi < Length(items)) Then
  TypeErr('not all arguments converted during string formatting');
 prefix := '';
 dig := '';
 neg := False;
 d := 0;
 Result := res;
End;

{ str.format }
Function FormatString(Const fmt: AnsiString; a: PVal; n: Integer;
 kw: TPyDict; mapObj: TVal; useMap: Boolean; depth: Integer): AnsiString;
Var
 i, ln, j, lvl, auto: Integer;
 res, field, spec, nm, rest, attr: AnsiString;
 conv: Char;
 v, idx: TVal;
 c: Char;
 k: Integer;
 numeric: Boolean;
 num: Int64;
 p: Integer;
 tmp: TVal;
Begin
 If depth > 2 Then ValueErr('Max string recursion exceeded');
 res := '';
 ln := Length(fmt);
 i := 1;
 auto := 0;
 While i <= ln Do Begin
  c := fmt[i];
  If c = '{' Then Begin
   If (i < ln) And (fmt[i + 1] = '{') Then Begin
    res := res + '{';
    Inc(i, 2);
    Continue;
   End;
   lvl := 1;
   j := i + 1;
   While (j <= ln) And (lvl > 0) Do Begin
    If fmt[j] = '{' Then Inc(lvl)
    Else If fmt[j] = '}' Then Begin
     Dec(lvl);
     If lvl = 0 Then Break;
    End;
    Inc(j);
   End;
   If lvl > 0 Then ValueErr('expected ''}'' before end of string');
   field := Copy(fmt, i + 1, j - i - 1);
   i := j + 1;
   conv := #0;
   spec := '';
   { separer spec et conversion }
   k := 1;
   lvl := 0;
   While k <= Length(field) Do Begin
    If field[k] = '[' Then Inc(lvl)
    Else If field[k] = ']' Then Dec(lvl)
    Else If (lvl = 0) And ((field[k] = '!') Or (field[k] = ':')) Then Break;
    Inc(k);
   End;
   rest := Copy(field, k, Length(field));
   field := Copy(field, 1, k - 1);
   If (rest <> '') And (rest[1] = '!') Then Begin
    If Length(rest) < 2 Then ValueErr('end of string while looking for ' +
     'conversion specifier');
    conv := rest[2];
    rest := Copy(rest, 3, Length(rest));
    If (rest <> '') And (rest[1] <> ':') Then
     ValueErr('expected '':'' after conversion specifier');
   End;
   If (rest <> '') And (rest[1] = ':') Then spec := Copy(rest, 2, Length(rest));
   { nom du champ : premier element }
   k := 1;
   While (k <= Length(field)) And Not (field[k] In ['.', '[']) Do Inc(k);
   nm := Copy(field, 1, k - 1);
   rest := Copy(field, k, Length(field));
   numeric := (nm <> '') And (nm[1] In ['0'..'9']);
   If nm = '' Then Begin
    num := auto;
    Inc(auto);
    numeric := True;
   End
   Else If numeric Then num := StrToInt64(nm);
   If numeric Then Begin
    If useMap Then
     ValueErr('Format string contains positional fields');
    If num >= n Then
     RaiseExc(exIndexError, 'Replacement index ' + IntToStr(num) +
      ' out of range for positional args tuple');
    v := a[num];
   End
   Else Begin
    If useMap Then v := GetItem(mapObj, VStr(nm))
    Else Begin
     If (kw = Nil) Or Not kw.GetS(nm, v) Then RaiseKeyError(VStr(nm));
    End;
   End;
   { attributs et indices }
   While rest <> '' Do Begin
    If rest[1] = '.' Then Begin
     k := 2;
     While (k <= Length(rest)) And Not (rest[k] In ['.', '[']) Do Inc(k);
     attr := Copy(rest, 2, k - 2);
     v := GetAttr(v, attr);
     rest := Copy(rest, k, Length(rest));
    End
    Else Begin
     k := Pos(']', rest);
     If k = 0 Then ValueErr('Missing '']'' in format string');
     attr := Copy(rest, 2, k - 2);
     If (attr <> '') And (attr[1] In ['0'..'9']) Then idx := VInt(StrToInt64(
      attr))
     Else idx := VStr(attr);
     v := GetItem(v, idx);
     rest := Copy(rest, k + 1, Length(rest));
    End;
   End;
   Case conv Of
    'r': v := VStr(ReprVal(v));
    's': v := VStr(StrVal(v));
    'a': v := VStr(AsciiVal(v));
    #0: ;
   Else
    ValueErr('Unknown conversion specifier ' + conv);
   End;
   If Pos('{', spec) > 0 Then
    spec := FormatString(spec, a, n, kw, mapObj, useMap, depth + 1);
   res := res + FormatValue(v, spec);
   Continue;
  End;
  If c = '}' Then Begin
   If (i < ln) And (fmt[i + 1] = '}') Then Begin
    res := res + '}';
    Inc(i, 2);
    Continue;
   End;
   ValueErr('Single ''}'' encountered in format string');
  End;
  res := res + c;
  Inc(i);
 End;
 p := 0;
 tmp := vNone;
 Result := res;
End;

{ ------------------------------------------------------------
  Methodes de str
  ------------------------------------------------------------ }
Function SArg(a: PVal; i, n: Integer; Const fname: AnsiString): AnsiString;
Begin
 If i >= n Then TypeErr(fname + '() missing required argument');
 If Not IsStrVal(a[i]) Then
  TypeErr(fname + '() argument must be str, not ' + TypeName(a[i]));
 Result := TPyStr(a[i].o).s;
End;

Function SelfStr(a: PVal): AnsiString; Inline;
Begin
 Result := TPyStr(a[0].o).s;
End;

Function StrNewObj(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyType;
 o: TPyStr;
 s: AnsiString;
Begin
 t := TPyType(a[0].o);
 If n > 1 Then s := StrVal(a[1]) Else s := '';
 If (t = tyStr) Then Begin
  Result := VStr(s);
  Exit;
 End;
 o := TPyStr.Make(s);
 o.cls := t;
 o.idict := TPyDict.Make;
 Result := VObj(o);
End;

{ borne [lo,hi[ en octets a partir d'indices code points }
Procedure CpRange(Const s: AnsiString; a: PVal; n, iStart: Integer;
 Var bs, be: Integer);
Var
 ln, st, en: Int64;
 ascii: Boolean;
Begin
 ascii := IsAsciiStr(s);
 If ascii Then ln := Length(s) Else ln := Utf8Len(s);
 st := 0;
 en := ln;
 If (n > iStart) And (a[iStart].k <> vkNone) Then st := IndexVal(a[iStart]);
 If (n > iStart + 1) And (a[iStart + 1].k <> vkNone) Then
  en := IndexVal(a[iStart + 1]);
 If st < 0 Then Begin
  st := st + ln;
  If st < 0 Then st := 0;
 End;
 If en < 0 Then Begin
  en := en + ln;
  If en < 0 Then en := 0;
 End;
 If en > ln Then en := ln;
 If st > ln Then st := ln + 1;
 If ascii Then Begin
  bs := st + 1;
  be := en + 1;
 End
 Else Begin
  bs := CpToByteIndex(s, st);
  be := CpToByteIndex(s, en);
 End;
End;

Function PosRev(Const sub, s: AnsiString; bs, be: Integer): Integer;
Var
 i: Integer;
Begin
 Result := 0;
 For i := be - Length(sub) DownTo bs Do
  If Copy(s, i, Length(sub)) = sub Then Begin
   Result := i;
   Exit;
  End;
End;

Function StrFind(a: PVal; n: Integer; kw: TPyDict; rev: Boolean): Integer;
Var
 s, sub: AnsiString;
 bs, be, p: Integer;
Begin
 s := SelfStr(a);
 sub := SArg(a, 1, n, 'find');
 CpRange(s, a, n, 2, bs, be);
 If bs > Length(s) + 1 Then Begin
  Result := -1;
  Exit;
 End;
 If rev Then p := PosRev(sub, s, bs, be)
 Else Begin
  p := PosEx(sub, s, bs);
  If (p > 0) And (p + Length(sub) > be) Then p := 0;
  If sub = '' Then Begin
   If bs <= be Then p := bs Else p := 0;
  End;
 End;
 If p = 0 Then Result := -1
 Else If IsAsciiStr(s) Then Result := p - 1
 Else Result := ByteToCpIndex(s, p);
End;

Function StrFindM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(StrFind(a, n, kw, False));
End;

Function StrRFindM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(StrFind(a, n, kw, True));
End;

Function StrIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: Integer;
Begin
 r := StrFind(a, n, kw, False);
 If r < 0 Then ValueErr('substring not found');
 Result := VInt(r);
End;

Function StrRIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: Integer;
Begin
 r := StrFind(a, n, kw, True);
 If r < 0 Then ValueErr('substring not found');
 Result := VInt(r);
End;

Function StrCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, sub: AnsiString;
 bs, be, p, cnt: Integer;
Begin
 s := SelfStr(a);
 sub := SArg(a, 1, n, 'count');
 CpRange(s, a, n, 2, bs, be);
 cnt := 0;
 If sub = '' Then Begin
  Result := VInt(Utf8Len(Copy(s, bs, be - bs)) + 1);
  Exit;
 End;
 p := PosEx(sub, s, bs);
 While (p > 0) And (p + Length(sub) <= be) Do Begin
  Inc(cnt);
  p := PosEx(sub, s, p + Length(sub));
 End;
 Result := VInt(cnt);
End;

Function StrStartsEnds(a: PVal; n: Integer; ends: Boolean): TVal;
Var
 s, sub: AnsiString;
 bs, be, i: Integer;
 t: TPyTuple;

 Function Chk(Const sb: AnsiString): Boolean;
 Begin
  If ends Then
   Result := (be - bs >= Length(sb)) And (Copy(s, be - Length(sb), Length(sb))
    = sb)
  Else
   Result := (be - bs >= Length(sb)) And (Copy(s, bs, Length(sb)) = sb);
 End;

Begin
 s := SelfStr(a);
 If n < 2 Then TypeErr('startswith/endswith() takes at least 1 argument');
 CpRange(s, a, n, 2, bs, be);
 If bs > Length(s) + 1 Then Begin
  Result := vFalse;
  Exit;
 End;
 If (a[1].k = vkObj) And (a[1].o Is TPyTuple) Then Begin
  t := TPyTuple(a[1].o);
  For i := 0 To High(t.items) Do
   If Chk(StrOf(t.items[i])) Then Begin
    Result := vTrue;
    Exit;
   End;
  Result := vFalse;
  Exit;
 End;
 If Not IsStrVal(a[1]) Then
  TypeErr('startswith first arg must be str or a tuple of str, not ' +
   TypeName(a[1]));
 sub := TPyStr(a[1].o).s;
 Result := VBool(Chk(sub));
End;

Function StrStartsWithM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StrStartsEnds(a, n, False);
End;

Function StrEndsWithM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StrStartsEnds(a, n, True);
End;

Function StrUpperM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(Utf8Upper(SelfStr(a)));
End;

Function StrLowerM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(Utf8Lower(SelfStr(a)));
End;

Function StrCapitalizeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: AnsiString;
 i: Integer;
 c: Cardinal;
Begin
 s := SelfStr(a);
 If s = '' Then Begin
  Result := VStr('');
  Exit;
 End;
 i := 1;
 c := Utf8Dec(s, i);
 Result := VStr(Utf8Enc(CpUpper(c)) + Utf8Lower(Copy(s, i, Length(s))));
End;

Function StrSwapcaseM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 i: Integer;
 c: Cardinal;
Begin
 s := SelfStr(a);
 r := '';
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  If CpIsUpper(c) Then r := r + Utf8Enc(CpLower(c))
  Else If CpIsLower(c) Then r := r + Utf8Enc(CpUpper(c))
  Else r := r + Utf8Enc(c);
 End;
 Result := VStr(r);
End;

Function StrTitleM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 i: Integer;
 c: Cardinal;
 prevCased: Boolean;
Begin
 s := SelfStr(a);
 r := '';
 prevCased := False;
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  If CpIsUpper(c) Or CpIsLower(c) Then Begin
   If prevCased Then r := r + Utf8Enc(CpLower(c))
   Else r := r + Utf8Enc(CpUpper(c));
   prevCased := True;
  End
  Else Begin
   r := r + Utf8Enc(c);
   prevCased := False;
  End;
 End;
 Result := VStr(r);
End;

Function StripImpl(a: PVal; n: Integer; left, right: Boolean): TVal;
Var
 s, chars: AnsiString;
 cps, cc: TCpArr;
 lo, hi, i: Integer;
 hasChars: Boolean;

 Function InSet(c: Cardinal): Boolean;
 Var
  k: Integer;
 Begin
  If hasChars Then Begin
   Result := False;
   For k := 0 To High(cc) Do
    If cc[k] = c Then Result := True;
  End
  Else Result := CpIsSpace(c);
 End;

Begin
 s := SelfStr(a);
 hasChars := (n > 1) And (a[1].k <> vkNone);
 If hasChars Then Begin
  chars := StrOf(a[1]);
  cc := StrToCps(chars);
 End;
 If IsAsciiStr(s) And Not hasChars Then Begin
  lo := 1;
  hi := Length(s);
  If left Then
   While (lo <= hi) And (s[lo] In [' ', #9, #10, #11, #12, #13, #28..#31]) Do
    Inc(lo);
  If right Then
   While (hi >= lo) And (s[hi] In [' ', #9, #10, #11, #12, #13, #28..#31]) Do
    Dec(hi);
  Result := VStr(Copy(s, lo, hi - lo + 1));
  Exit;
 End;
 cps := StrToCps(s);
 lo := 0;
 hi := Length(cps);
 If left Then
  While (lo < hi) And InSet(cps[lo]) Do Inc(lo);
 If right Then
  While (hi > lo) And InSet(cps[hi - 1]) Do Dec(hi);
 i := 0;
 Result := VStr(CpsToStr(cps, lo, hi));
End;

Function StrStripM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StripImpl(a, n, True, True);
End;

Function StrLStripM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StripImpl(a, n, True, False);
End;

Function StrRStripM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StripImpl(a, n, False, True);
End;

Function SplitWhitespace(Const s: AnsiString; maxsplit: Int64; fromRight: Boolean):
 TPyList;
Var
 l: TPyList;
 cps: TCpArr;
 i, st, cnt, n: Integer;
 parts: Array Of AnsiString;
 np: Integer;
 hi: Integer;
Begin
 l := NewList;
 cps := StrToCps(s);
 n := Length(cps);
 If Not fromRight Then Begin
  i := 0;
  cnt := 0;
  While i < n Do Begin
   While (i < n) And CpIsSpace(cps[i]) Do Inc(i);
   If i >= n Then Break;
   If (maxsplit >= 0) And (cnt >= maxsplit) Then Begin
    hi := n;
    While (hi > i) And CpIsSpace(cps[hi - 1]) Do Dec(hi);
    l.Add(VStr(CpsToStr(cps, i, hi)));
    Break;
   End;
   st := i;
   While (i < n) And Not CpIsSpace(cps[i]) Do Inc(i);
   l.Add(VStr(CpsToStr(cps, st, i)));
   Inc(cnt);
  End;
 End
 Else Begin
  SetLength(parts, 0);
  i := n;
  cnt := 0;
  While i > 0 Do Begin
   While (i > 0) And CpIsSpace(cps[i - 1]) Do Dec(i);
   If i <= 0 Then Break;
   If (maxsplit >= 0) And (cnt >= maxsplit) Then Begin
    st := 0;
    While (st < i) And CpIsSpace(cps[st]) Do Inc(st);
    SetLength(parts, Length(parts) + 1);
    parts[High(parts)] := CpsToStr(cps, st, i);
    Break;
   End;
   hi := i;
   While (i > 0) And Not CpIsSpace(cps[i - 1]) Do Dec(i);
   SetLength(parts, Length(parts) + 1);
   parts[High(parts)] := CpsToStr(cps, i, hi);
   Inc(cnt);
  End;
  np := Length(parts);
  For i := np - 1 DownTo 0 Do l.Add(VStr(parts[i]));
 End;
 Result := l;
End;

Function SplitImpl(a: PVal; n: Integer; kw: TPyDict; fromRight: Boolean):
 TVal;
Var
 s, sep: AnsiString;
 maxsplit: Int64;
 v: TVal;
 l: TPyList;
 p, st, cnt, i: Integer;
 parts: Array Of AnsiString;
Begin
 s := SelfStr(a);
 maxsplit := -1;
 sep := '';
 If ArgKw(a, n, kw, 2, 'maxsplit', v) Then maxsplit := IndexVal(v);
 If ArgKw(a, n, kw, 1, 'sep', v) And (v.k <> vkNone) Then Begin
  If Not IsStrVal(v) Then
   TypeErr('must be str or None, not ' + TypeName(v));
  sep := TPyStr(v.o).s;
  If sep = '' Then ValueErr('empty separator');
  l := NewList;
  If Not fromRight Then Begin
   st := 1;
   cnt := 0;
   p := PosEx(sep, s, st);
   While (p > 0) And ((maxsplit < 0) Or (cnt < maxsplit)) Do Begin
    l.Add(VStr(Copy(s, st, p - st)));
    st := p + Length(sep);
    Inc(cnt);
    p := PosEx(sep, s, st);
   End;
   l.Add(VStr(Copy(s, st, Length(s) - st + 1)));
  End
  Else Begin
   SetLength(parts, 0);
   st := Length(s);
   cnt := 0;
   While (st >= Length(sep)) And ((maxsplit < 0) Or (cnt < maxsplit)) Do Begin
    p := PosRev(sep, s, 1, st + 1);
    If p = 0 Then Break;
    SetLength(parts, Length(parts) + 1);
    parts[High(parts)] := Copy(s, p + Length(sep), st - p - Length(sep) + 1);
    st := p - 1;
    Inc(cnt);
   End;
   l.Add(VStr(Copy(s, 1, st)));
   For i := High(parts) DownTo 0 Do l.Add(VStr(parts[i]));
  End;
  Result := VObj(l);
  Exit;
 End;
 Result := VObj(SplitWhitespace(s, maxsplit, fromRight));
End;

Function StrSplitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := SplitImpl(a, n, kw, False);
End;

Function StrRSplitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := SplitImpl(a, n, kw, True);
End;

Function StrJoinM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 sep, r: AnsiString;
 arr: TValArr;
 i, total: Integer;
Begin
 NeedArgs(n, 2, 2, 'join');
 sep := SelfStr(a);
 arr := IterToArr(a[1]);
 total := 0;
 For i := 0 To High(arr) Do Begin
  If Not IsStrVal(arr[i]) Then
   TypeErr('sequence item ' + IntToStr(i) + ': expected str instance, ' +
    TypeName(arr[i]) + ' found');
  Inc(total, Length(TPyStr(arr[i].o).s) + Length(sep));
 End;
 r := '';
 SetLength(r, 0);
 If Length(arr) = 1 Then Begin
  Result := arr[0];
  Exit;
 End;
 For i := 0 To High(arr) Do Begin
  If i > 0 Then r := r + sep;
  r := r + TPyStr(arr[i].o).s;
 End;
 Result := VStr(r);
End;

Function StrReplaceM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, o, nw, r: AnsiString;
 cnt, c, p, st: Integer;
 cps: TCpArr;
 i: Integer;
Begin
 NeedArgs(n, 3, 4, 'replace');
 s := SelfStr(a);
 o := SArg(a, 1, n, 'replace');
 nw := SArg(a, 2, n, 'replace');
 cnt := -1;
 If n > 3 Then cnt := IndexVal(a[3]);
 If o = '' Then Begin
  cps := StrToCps(s);
  r := '';
  c := 0;
  For i := 0 To High(cps) Do Begin
   If (cnt < 0) Or (c < cnt) Then Begin
    r := r + nw;
    Inc(c);
   End;
   r := r + Utf8Enc(cps[i]);
  End;
  If (cnt < 0) Or (c < cnt) Then r := r + nw;
  Result := VStr(r);
  Exit;
 End;
 r := '';
 st := 1;
 c := 0;
 p := PosEx(o, s, st);
 While (p > 0) And ((cnt < 0) Or (c < cnt)) Do Begin
  r := r + Copy(s, st, p - st) + nw;
  st := p + Length(o);
  Inc(c);
  p := PosEx(o, s, st);
 End;
 r := r + Copy(s, st, Length(s) - st + 1);
 Result := VStr(r);
End;

Function JustifyImpl(a: PVal; n: Integer; al: Char): TVal;
Var
 s, fillc: AnsiString;
 w, ln, padn, l: Integer;
Begin
 NeedArgs(n, 2, 3, 'justify');
 s := SelfStr(a);
 w := IndexVal(a[1]);
 fillc := ' ';
 If n > 2 Then Begin
  fillc := SArg(a, 2, n, 'justify');
  If Utf8Len(fillc) <> 1 Then
   TypeErr('The fill character must be exactly one character long');
 End;
 ln := Utf8Len(s);
 If w <= ln Then Begin
  Result := a[0];
  Exit;
 End;
 padn := w - ln;
 Case al Of
  '<': l := 0;
  '>': l := padn;
 Else
  l := padn Div 2 + (padn And w And 1);
 End;
 Result := VStr(RepeatStr(fillc, l) + s + RepeatStr(fillc, padn - l));
End;

Function StrLJustM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := JustifyImpl(a, n, '<');
End;

Function StrRJustM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := JustifyImpl(a, n, '>');
End;

Function StrCenterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := JustifyImpl(a, n, '^');
End;

Function StrZFillM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: AnsiString;
 w, ln: Integer;
 sg: AnsiString;
Begin
 NeedArgs(n, 2, 2, 'zfill');
 s := SelfStr(a);
 w := IndexVal(a[1]);
 ln := Utf8Len(s);
 If w <= ln Then Begin
  Result := a[0];
  Exit;
 End;
 sg := '';
 If (s <> '') And (s[1] In ['+', '-']) Then Begin
  sg := s[1];
  s := Copy(s, 2, Length(s));
 End;
 Result := VStr(sg + StringOfChar('0', w - ln) + s);
End;

Function StrFormatM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(FormatString(SelfStr(a), a + 1, n - 1, kw, vNone, False, 0));
End;

Function StrFormatMapM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(FormatString(SelfStr(a), Nil, 0, Nil, a[1], True, 0));
End;

Function StrPartitionImpl(a: PVal; n: Integer; rev: Boolean): TVal;
Var
 s, sep: AnsiString;
 p: Integer;
 t: TPyTuple;
Begin
 NeedArgs(n, 2, 2, 'partition');
 s := SelfStr(a);
 sep := SArg(a, 1, n, 'partition');
 If sep = '' Then ValueErr('empty separator');
 If rev Then p := PosRev(sep, s, 1, Length(s) + 1) Else p := Pos(sep, s);
 t := NewTuple(3);
 If p = 0 Then Begin
  If rev Then Begin
   t.items[0] := VStr('');
   t.items[1] := VStr('');
   t.items[2] := a[0];
  End
  Else Begin
   t.items[0] := a[0];
   t.items[1] := VStr('');
   t.items[2] := VStr('');
  End;
 End
 Else Begin
  t.items[0] := VStr(Copy(s, 1, p - 1));
  t.items[1] := VStr(sep);
  t.items[2] := VStr(Copy(s, p + Length(sep), Length(s)));
 End;
 Result := VObj(t);
End;

Function StrPartitionM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StrPartitionImpl(a, n, False);
End;

Function StrRPartitionM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := StrPartitionImpl(a, n, True);
End;

Function StrSplitLinesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: AnsiString;
 keep: Boolean;
 l: TPyList;
 i, st: Integer;
 v: TVal;
Begin
 s := SelfStr(a);
 keep := False;
 If ArgKw(a, n, kw, 1, 'keepends', v) Then keep := IsTrue(v);
 l := NewList;
 i := 1;
 st := 1;
 While i <= Length(s) Do Begin
  If s[i] In [#10, #13, #11, #12] Then Begin
   If (s[i] = #13) And (i < Length(s)) And (s[i + 1] = #10) Then Begin
    If keep Then l.Add(VStr(Copy(s, st, i + 2 - st)))
    Else l.Add(VStr(Copy(s, st, i - st)));
    Inc(i, 2);
   End
   Else Begin
    If keep Then l.Add(VStr(Copy(s, st, i + 1 - st)))
    Else l.Add(VStr(Copy(s, st, i - st)));
    Inc(i);
   End;
   st := i;
  End
  Else Inc(i);
 End;
 If st <= Length(s) Then l.Add(VStr(Copy(s, st, Length(s) - st + 1)));
 Result := VObj(l);
End;

Function StrIsImpl(a: PVal; kind: Integer): TVal;
Var
 s: AnsiString;
 cps: TCpArr;
 i: Integer;
 anyCased, prevCased, ok: Boolean;
 c: Cardinal;
Begin
 s := SelfStr(a);
 cps := StrToCps(s);
 If Length(cps) = 0 Then Begin
  Result := vFalse;
  If kind = 11 Then Result := vTrue;
  If kind = 12 Then Result := vTrue;
  If kind = 13 Then Result := vTrue;
  Exit;
 End;
 ok := True;
 anyCased := False;
 prevCased := False;
 For i := 0 To High(cps) Do Begin
  c := cps[i];
  Case kind Of
   1: If Not CpIsAlpha(c) Then ok := False;
   2: If Not CpIsDigit(c) Then ok := False;
   3: If Not (CpIsAlpha(c) Or CpIsDigit(c)) Then ok := False;
   4: If Not CpIsSpace(c) Then ok := False;
   5: Begin
     If CpIsLower(c) Then anyCased := True
     Else If CpIsUpper(c) Then ok := False;
    End;
   6: Begin
     If CpIsUpper(c) Then anyCased := True
     Else If CpIsLower(c) Then ok := False;
    End;
   7: Begin
     If CpIsUpper(c) Then Begin
      If prevCased Then ok := False;
      prevCased := True;
      anyCased := True;
     End
     Else If CpIsLower(c) Then Begin
      If Not prevCased Then ok := False;
      prevCased := True;
      anyCased := True;
     End
     Else prevCased := False;
    End;
   8: If c >= 128 Then ok := False;
   9: If Not (CpIsAlpha(c) Or CpIsDigit(c) Or (c = 95)) Then ok := False;
   10: If Not CpIsPrintable(c) Then ok := False;
  End;
 End;
 If kind In [5, 6, 7] Then ok := ok And anyCased;
 If kind = 9 Then Begin
  If CpIsDigit(cps[0]) Then ok := False;
 End;
 Result := VBool(ok);
End;

Function StrIsAlphaM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 1); End;
Function StrIsDigitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 2); End;
Function StrIsAlnumM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 3); End;
Function StrIsSpaceM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 4); End;
Function StrIsLowerM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 5); End;
Function StrIsUpperM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 6); End;
Function StrIsTitleM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 7); End;
Function StrIsAsciiM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(IsAsciiStr(SelfStr(a)));
End;
Function StrIsIdentM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 9); End;
Function StrIsPrintM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrIsImpl(a, 10); End;

Function StrExpandTabsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 ts, col, i: Integer;
 v: TVal;
Begin
 s := SelfStr(a);
 ts := 8;
 If ArgKw(a, n, kw, 1, 'tabsize', v) Then ts := IndexVal(v);
 r := '';
 col := 0;
 For i := 1 To Length(s) Do Begin
  If s[i] = #9 Then Begin
   If ts > 0 Then Begin
    r := r + StringOfChar(' ', ts - (col Mod ts));
    col := col + ts - (col Mod ts);
   End;
  End
  Else Begin
   r := r + s[i];
   If (s[i] = #10) Or (s[i] = #13) Then col := 0 Else Inc(col);
  End;
 End;
 Result := VStr(r);
End;

Function StrEncodeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, enc, r, errs: AnsiString;
 v: TVal;
 i: Integer;
 c: Cardinal;
Begin
 s := SelfStr(a);
 enc := 'utf-8';
 errs := 'strict';
 If ArgKw(a, n, kw, 1, 'encoding', v) Then enc := LowerCase(StrOf(v));
 If ArgKw(a, n, kw, 2, 'errors', v) Then errs := StrOf(v);
 enc := StringReplace(enc, '_', '-', [rfReplaceAll]);
 If (enc = 'utf-8') Or (enc = 'utf8') Then Begin
  Result := VBytes(s);
  Exit;
 End;
 If (enc = 'ascii') Or (enc = 'latin-1') Or (enc = 'latin1') Or
  (enc = 'iso-8859-1') Then Begin
  r := '';
  i := 1;
  While i <= Length(s) Do Begin
   c := Utf8Dec(s, i);
   If (c < 128) Or ((c < 256) And (enc <> 'ascii')) Then r := r + Chr(c)
   Else If errs = 'ignore' Then
   Else If errs = 'replace' Then r := r + '?'
   Else Begin
    Raise EPyError.Make(MakeExcArgs(exUnicodeEncodeError,
     [VStr(enc), VStr(Utf8Enc(c)), VInt(i - 1), VInt(i), VStr('ordinal ' +
     'not in range(' + IntToStr(128 + 128 * Ord(enc <> 'ascii')) + ')')]));
   End;
  End;
  Result := VBytes(r);
  Exit;
 End;
 RaiseExc(exLookupError, 'unknown encoding: ' + enc);
 Result := vNone;
End;

Function StrTranslateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 i: Integer;
 c: Cardinal;
 v: TVal;
Begin
 NeedArgs(n, 2, 2, 'translate');
 s := SelfStr(a);
 r := '';
 i := 1;
 While i <= Length(s) Do Begin
  c := Utf8Dec(s, i);
  Try
   v := GetItem(a[1], VInt(c));
   If v.k = vkNone Then
   Else If IsStrVal(v) Then r := r + TPyStr(v.o).s
   Else If IsIntVal(v) Then r := r + Utf8Enc(v.i)
   Else TypeErr('character mapping must return integer, None or str');
  Except
   On E: EPyError Do Begin
    If IsInstance(VObj(E.exc), exLookupError) Then r := r + Utf8Enc(c)
    Else Raise;
   End;
  End;
 End;
 Result := VStr(r);
End;

Function StrMakeTransM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
 x, y, z: AnsiString;
 cx, cy: TCpArr;
 i: Integer;
Begin
 NeedArgs(n, 1, 3, 'maketrans');
 d := TPyDict.Make;
 If n = 1 Then Begin
  If Not ((a[0].k = vkObj) And (a[0].o Is TPyDict)) Then
   TypeErr('if you give only one argument to maketrans it must be a dict');
  For i := 0 To TPyDict(a[0].o).nent - 1 Do
   If TPyDict(a[0].o).ent[i].key.k <> vkNull Then Begin
    If IsStrVal(TPyDict(a[0].o).ent[i].key) Then
     d.SetItem(VInt(StrToCps(TPyStr(TPyDict(a[0].o).ent[i].key.o).s)[0]),
      TPyDict(a[0].o).ent[i].val)
    Else d.SetItem(TPyDict(a[0].o).ent[i].key, TPyDict(a[0].o).ent[i].val);
   End;
 End
 Else Begin
  x := StrOf(a[0]);
  y := StrOf(a[1]);
  cx := StrToCps(x);
  cy := StrToCps(y);
  If Length(cx) <> Length(cy) Then
   ValueErr('the first two maketrans arguments must have equal length');
  For i := 0 To High(cx) Do d.SetItem(VInt(cx[i]), VInt(cy[i]));
  If n > 2 Then Begin
   z := StrOf(a[2]);
   cx := StrToCps(z);
   For i := 0 To High(cx) Do d.SetItem(VInt(cx[i]), vNone);
  End;
 End;
 Result := VObj(d);
End;

Function StrRemovePrefixM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, p: AnsiString;
Begin
 s := SelfStr(a);
 p := SArg(a, 1, n, 'removeprefix');
 If (p <> '') And (Copy(s, 1, Length(p)) = p) Then
  Result := VStr(Copy(s, Length(p) + 1, Length(s)))
 Else Result := a[0];
End;

Function StrRemoveSuffixM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, p: AnsiString;
Begin
 s := SelfStr(a);
 p := SArg(a, 1, n, 'removesuffix');
 If (p <> '') And (Length(s) >= Length(p)) And
  (Copy(s, Length(s) - Length(p) + 1, Length(p)) = p) Then
  Result := VStr(Copy(s, 1, Length(s) - Length(p)))
 Else Result := a[0];
End;

Function StrLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(PyStrLen(TPyStr(a[0].o)));
End;

Function StrContainsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(ContainsOp(a[0], a[1]));
End;

Function StrGetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := GetItem(a[0], a[1]);
End;

Function StrAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not IsStrVal(a[1]) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VStr(SelfStr(a) + TPyStr(a[1].o).s);
End;

Function StrMulM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := BinaryOp(bopMul, a[0], a[1]);
End;

Function StrModM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(PercentFormat(SelfStr(a), a[1]));
End;

Function StrCmpM(a: PVal; n: Integer; kw: TPyDict; op: Integer): TVal;
Begin
 If Not IsStrVal(a[1]) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], op));
End;

Function StrEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 2); End;
Function StrNeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 3); End;
Function StrLtM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 0); End;
Function StrLeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 1); End;
Function StrGtM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 4); End;
Function StrGeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := StrCmpM(a, n, kw, 5); End;

Function StrHashM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(StrHash(TPyStr(a[0].o)));
End;

Function StrReprM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(StrReprEsc(SelfStr(a), False));
End;

Function StrStrM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(SelfStr(a));
End;

Function StrIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := IterOf(a[0]);
End;

Function StrFormatDunder(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(FormatValue(a[0], StrOf(a[1])));
End;

Procedure InitStrMethods;
Begin
 tyStr.idict.SetS('__new__', VObj(NewBuiltin('__new__', @StrNewObj)));
 DefMethod(tyStr, 'find', @StrFindM);
 DefMethod(tyStr, 'rfind', @StrRFindM);
 DefMethod(tyStr, 'index', @StrIndexM);
 DefMethod(tyStr, 'rindex', @StrRIndexM);
 DefMethod(tyStr, 'count', @StrCountM);
 DefMethod(tyStr, 'startswith', @StrStartsWithM);
 DefMethod(tyStr, 'endswith', @StrEndsWithM);
 DefMethod(tyStr, 'upper', @StrUpperM);
 DefMethod(tyStr, 'lower', @StrLowerM);
 DefMethod(tyStr, 'casefold', @StrLowerM);
 DefMethod(tyStr, 'capitalize', @StrCapitalizeM);
 DefMethod(tyStr, 'swapcase', @StrSwapcaseM);
 DefMethod(tyStr, 'title', @StrTitleM);
 DefMethod(tyStr, 'strip', @StrStripM);
 DefMethod(tyStr, 'lstrip', @StrLStripM);
 DefMethod(tyStr, 'rstrip', @StrRStripM);
 DefMethod(tyStr, 'split', @StrSplitM);
 DefMethod(tyStr, 'rsplit', @StrRSplitM);
 DefMethod(tyStr, 'join', @StrJoinM);
 DefMethod(tyStr, 'replace', @StrReplaceM);
 DefMethod(tyStr, 'ljust', @StrLJustM);
 DefMethod(tyStr, 'rjust', @StrRJustM);
 DefMethod(tyStr, 'center', @StrCenterM);
 DefMethod(tyStr, 'zfill', @StrZFillM);
 DefMethod(tyStr, 'format', @StrFormatM);
 DefMethod(tyStr, 'format_map', @StrFormatMapM);
 DefMethod(tyStr, 'partition', @StrPartitionM);
 DefMethod(tyStr, 'rpartition', @StrRPartitionM);
 DefMethod(tyStr, 'splitlines', @StrSplitLinesM);
 DefMethod(tyStr, 'isalpha', @StrIsAlphaM);
 DefMethod(tyStr, 'isdigit', @StrIsDigitM);
 DefMethod(tyStr, 'isdecimal', @StrIsDigitM);
 DefMethod(tyStr, 'isnumeric', @StrIsDigitM);
 DefMethod(tyStr, 'isalnum', @StrIsAlnumM);
 DefMethod(tyStr, 'isspace', @StrIsSpaceM);
 DefMethod(tyStr, 'islower', @StrIsLowerM);
 DefMethod(tyStr, 'isupper', @StrIsUpperM);
 DefMethod(tyStr, 'istitle', @StrIsTitleM);
 DefMethod(tyStr, 'isascii', @StrIsAsciiM);
 DefMethod(tyStr, 'isidentifier', @StrIsIdentM);
 DefMethod(tyStr, 'isprintable', @StrIsPrintM);
 DefMethod(tyStr, 'expandtabs', @StrExpandTabsM);
 DefMethod(tyStr, 'encode', @StrEncodeM);
 DefMethod(tyStr, 'translate', @StrTranslateM);
 DefStaticMethod(tyStr, 'maketrans', @StrMakeTransM);
 DefMethod(tyStr, 'removeprefix', @StrRemovePrefixM);
 DefMethod(tyStr, 'removesuffix', @StrRemoveSuffixM);
 DefMethod(tyStr, '__len__', @StrLenM);
 DefMethod(tyStr, '__contains__', @StrContainsM);
 DefMethod(tyStr, '__getitem__', @StrGetItemM);
 DefMethod(tyStr, '__add__', @StrAddM);
 DefMethod(tyStr, '__mul__', @StrMulM);
 DefMethod(tyStr, '__rmul__', @StrMulM);
 DefMethod(tyStr, '__mod__', @StrModM);
 DefMethod(tyStr, '__eq__', @StrEqM);
 DefMethod(tyStr, '__ne__', @StrNeM);
 DefMethod(tyStr, '__lt__', @StrLtM);
 DefMethod(tyStr, '__le__', @StrLeM);
 DefMethod(tyStr, '__gt__', @StrGtM);
 DefMethod(tyStr, '__ge__', @StrGeM);
 DefMethod(tyStr, '__hash__', @StrHashM);
 DefMethod(tyStr, '__repr__', @StrReprM);
 DefMethod(tyStr, '__str__', @StrStrM);
 DefMethod(tyStr, '__iter__', @StrIterM);
 DefMethod(tyStr, '__format__', @StrFormatDunder);
End;

{ ------------------------------------------------------------
  list
  ------------------------------------------------------------ }
Function IntFromQ(q: QWord): TVal;
Var
 m: TMag;
Begin
 m := MagFromQ(q);
 Result := MakeInt(False, m);
End;

Function SelfList(a: PVal): TPyList; Inline;
Begin
 Result := TPyList(a[0].o);
End;

Procedure InitObjOf(o: TPyObj; t: TPyType);
Begin
 o.cls := t;
 If t.userdef Then o.idict := TPyDict.Make;
End;

Procedure ListFill(l: TPyList; a: PVal; n: Integer);
Var
 arr: TValArr;
 i: Integer;
Begin
 l.Clear;
 If n > 0 Then Begin
  arr := IterToArr(a[0]);
  SetLength(l.items, Length(arr));
  For i := 0 To High(arr) Do l.items[i] := arr[i];
  l.cnt := Length(arr);
 End;
End;

Function ListCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
Begin
 NeedArgs(n, 0, 1, 'list');
 l := NewList;
 ListFill(l, a, n);
 Result := VObj(l);
End;

Function ListNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
Begin
 l := NewList;
 InitObjOf(l, TPyType(a[0].o));
 Result := VObj(l);
End;

Function ListInitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 ListFill(SelfList(a), a + 1, n - 1);
 Result := vNone;
End;

Function ListAppendM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'append');
 SelfList(a).Add(a[1]);
 Result := vNone;
End;

Function ListExtendM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 i: Integer;
 l: TPyList;
Begin
 NeedArgs(n, 2, 2, 'extend');
 l := SelfList(a);
 arr := IterToArr(a[1]);
 For i := 0 To High(arr) Do l.Add(arr[i]);
 Result := vNone;
End;

Function ListInsertM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Int64;
 l: TPyList;
Begin
 NeedArgs(n, 3, 3, 'insert');
 l := SelfList(a);
 i := IndexVal(a[1]);
 If i < 0 Then Begin
  i := i + l.cnt;
  If i < 0 Then i := 0;
 End;
 If i > l.cnt Then i := l.cnt;
 l.Insert(i, a[2]);
 Result := vNone;
End;

Function ListRemoveM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i: Integer;
Begin
 NeedArgs(n, 2, 2, 'remove');
 l := SelfList(a);
 For i := 0 To l.cnt - 1 Do
  If ValEq(l.items[i], a[1]) Then Begin
   l.Delete(i);
   Result := vNone;
   Exit;
  End;
 ValueErr('list.remove(x): x not in list');
 Result := vNone;
End;

Function ListPopM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i: Int64;
Begin
 NeedArgs(n, 1, 2, 'pop');
 l := SelfList(a);
 If l.cnt = 0 Then RaiseExc(exIndexError, 'pop from empty list');
 If n > 1 Then i := IndexVal(a[1]) Else i := -1;
 If i < 0 Then i := i + l.cnt;
 If (i < 0) Or (i >= l.cnt) Then RaiseExc(exIndexError, 'pop index out of range');
 Result := l.items[i];
 l.Delete(i);
End;

Function ListClearM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfList(a).Clear;
 Result := vNone;
End;

Function ListIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i, st, en: Integer;
Begin
 NeedArgs(n, 2, 4, 'index');
 l := SelfList(a);
 st := 0;
 en := l.cnt;
 If n > 2 Then st := IndexVal(a[2]);
 If n > 3 Then en := IndexVal(a[3]);
 If st < 0 Then st := Max(0, st + l.cnt);
 If en < 0 Then en := Max(0, en + l.cnt);
 If en > l.cnt Then en := l.cnt;
 For i := st To en - 1 Do
  If ValEq(l.items[i], a[1]) Then Begin
   Result := VInt(i);
   Exit;
  End;
 ValueErr(ReprVal(a[1]) + ' is not in list');
 Result := vNone;
End;

Function ListCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i, c: Integer;
Begin
 NeedArgs(n, 2, 2, 'count');
 l := SelfList(a);
 c := 0;
 For i := 0 To l.cnt - 1 Do
  If ValEq(l.items[i], a[1]) Then Inc(c);
 Result := VInt(c);
End;

Function ListSortM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 arr: TValArr;
 key, rev: TVal;
 i: Integer;
Begin
 If n > 1 Then TypeErr('sort() takes no positional arguments');
 l := SelfList(a);
 key := vNone;
 rev := vFalse;
 KwGet(kw, 'key', key);
 KwGet(kw, 'reverse', rev);
 SetLength(arr, l.cnt);
 For i := 0 To l.cnt - 1 Do arr[i] := l.items[i];
 SortVals(arr, key, IsTrue(rev));
 For i := 0 To High(arr) Do l.items[i] := arr[i];
 Result := vNone;
End;

Function ListReverseM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 i: Integer;
 t: TVal;
Begin
 l := SelfList(a);
 For i := 0 To (l.cnt Div 2) - 1 Do Begin
  t := l.items[i];
  l.items[i] := l.items[l.cnt - 1 - i];
  l.items[l.cnt - 1 - i] := t;
 End;
 Result := vNone;
End;

Function ListCopyM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l, r: TPyList;
 i: Integer;
Begin
 l := SelfList(a);
 r := NewList;
 For i := 0 To l.cnt - 1 Do r.Add(l.items[i]);
 Result := VObj(r);
End;

Function ListLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(SelfList(a).cnt);
End;

Function ListGetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := GetItem(a[0], a[1]);
End;

Function ListSetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 tmp: TVal;
Begin
 tmp := a[0];
 { appel direct sans repasser par __setitem__ utilisateur }
 If a[0].o.cls.userdef Then Begin
  If (a[1].k = vkInt) Then Begin
   If (a[1].i >= -SelfList(a).cnt) And (a[1].i < SelfList(a).cnt) Then Begin
    If a[1].i < 0 Then SelfList(a).items[a[1].i + SelfList(a).cnt] := a[2]
    Else SelfList(a).items[a[1].i] := a[2];
    Result := vNone;
    Exit;
   End;
   RaiseExc(exIndexError, 'list assignment index out of range');
  End;
 End;
 SetItem(a[0], a[1], a[2]);
 Result := vNone;
End;

Function ListDelItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 DelItem(a[0], a[1]);
 Result := vNone;
End;

Function ListContainsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(ContainsOp(a[0], a[1]));
End;

Function ListIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(NewListIter(SelfList(a), False));
End;

Function ListReversedM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(NewListIter(SelfList(a), True));
End;

Function ListAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyList)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 If SeqConcat(a[0], a[1], r) Then Result := r Else Result := vNotImpl;
End;

Function ListMulM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 If Not IsIntVal(a[1]) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 If SeqRepeat(a[0], a[1].i, r) Then Result := r Else Result := vNotImpl;
End;

Function ListIAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 ListExtendM(a, n, kw);
 Result := a[0];
End;

Function ListEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyList)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], 2));
End;

Function ListLtM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyList)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], 0));
End;

Function ListReprM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ReprVal(a[0]));
End;

{ ------------------------------------------------------------
  tuple
  ------------------------------------------------------------ }
Function TupleCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
Begin
 NeedArgs(n, 0, 1, 'tuple');
 If n = 0 Then Begin
  Result := VObj(EmptyTuple);
  Exit;
 End;
 If (a[0].k = vkObj) And (a[0].o.ClassType = TPyTuple) And
  Not a[0].o.cls.userdef Then Begin
  Result := a[0];
  Exit;
 End;
 arr := IterToArr(a[0]);
 Result := VObj(TupleFromVals(arr));
End;

Function TupleNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 t: TPyTuple;
Begin
 If n > 1 Then arr := IterToArr(a[1]) Else SetLength(arr, 0);
 t := TupleFromVals(arr);
 InitObjOf(t, TPyType(a[0].o));
 Result := VObj(t);
End;

Function TupleCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyTuple;
 i, c: Integer;
Begin
 NeedArgs(n, 2, 2, 'count');
 t := TPyTuple(a[0].o);
 c := 0;
 For i := 0 To High(t.items) Do
  If ValEq(t.items[i], a[1]) Then Inc(c);
 Result := VInt(c);
End;

Function TupleIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyTuple;
 i: Integer;
Begin
 NeedArgs(n, 2, 4, 'index');
 t := TPyTuple(a[0].o);
 For i := 0 To High(t.items) Do
  If ValEq(t.items[i], a[1]) Then Begin
   Result := VInt(i);
   Exit;
  End;
 ValueErr('tuple.index(x): x not in tuple');
 Result := vNone;
End;

Function TupleLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(Length(TPyTuple(a[0].o).items));
End;

Function TupleHashM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(HashVal(a[0]));
End;

Function TupleEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyTuple)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], 2));
End;

Function TupleAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyTuple)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 SeqConcat(a[0], a[1], r);
 Result := r;
End;

{ ------------------------------------------------------------
  dict
  ------------------------------------------------------------ }
Function SelfDict(a: PVal): TPyDict; Inline;
Begin
 Result := TPyDict(a[0].o);
End;

Procedure DictUpdateFrom(d: TPyDict; Const src: TVal);
Var
 it, x, k, pair: TVal;
 arr: TValArr;
 idx, i: Integer;
 so: TPyDict;
Begin
 If (src.k = vkObj) And (src.o Is TPyDict) Then Begin
  so := TPyDict(src.o);
  For i := 0 To so.nent - 1 Do
   If so.ent[i].key.k <> vkNull Then d.SetItem(so.ent[i].key, so.ent[i].val);
  Exit;
 End;
 If (src.k = vkObj) And HasAttr(src, 'keys') Then Begin
  it := IterOf(Call0(GetAttr(src, 'keys')));
  While IterNextVal(it, k) Do d.SetItem(k, GetItem(src, k));
  Exit;
 End;
 it := IterOf(src);
 idx := 0;
 While IterNextVal(it, pair) Do Begin
  arr := IterToArr(pair);
  If Length(arr) <> 2 Then
   ValueErr('dictionary update sequence element #' + IntToStr(idx) +
    ' has length ' + IntToStr(Length(arr)) + '; 2 is required');
  d.SetItem(arr[0], arr[1]);
  Inc(idx);
 End;
 x := vNone;
End;

Procedure DictFill(d: TPyDict; a: PVal; n: Integer; kw: TPyDict);
Var
 i: Integer;
Begin
 If n > 1 Then TypeErr('dict expected at most 1 argument, got ' + IntToStr(n));
 If n = 1 Then DictUpdateFrom(d, a[0]);
 If kw <> Nil Then
  For i := 0 To kw.nent - 1 Do
   If kw.ent[i].key.k <> vkNull Then d.SetItem(kw.ent[i].key, kw.ent[i].val);
End;

Function DictCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
Begin
 d := TPyDict.Make;
 DictFill(d, a, n, kw);
 Result := VObj(d);
End;

Function DictNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
Begin
 d := TPyDict.Make;
 InitObjOf(d, TPyType(a[0].o));
 Result := VObj(d);
End;

Function DictInitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 DictFill(SelfDict(a), a + 1, n - 1, kw);
 Result := vNone;
End;

Function MakeView(d: TPyDict; kind: Integer): TVal;
Var
 v: TDictView;
Begin
 v := TDictView.Create(tyDictView);
 v.src := d;
 v.kind := kind;
 Result := VObj(v);
End;

Function DictKeysM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := MakeView(SelfDict(a), 0);
End;

Function DictValuesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := MakeView(SelfDict(a), 1);
End;

Function DictItemsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := MakeView(SelfDict(a), 2);
End;

Function DictGetM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 NeedArgs(n, 2, 3, 'get');
 If SelfDict(a).GetItem(a[1], v) Then Result := v
 Else If n > 2 Then Result := a[2]
 Else Result := vNone;
End;

Function DictSetDefaultM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 NeedArgs(n, 2, 3, 'setdefault');
 If SelfDict(a).GetItem(a[1], v) Then Result := v
 Else Begin
  If n > 2 Then v := a[2] Else v := vNone;
  SelfDict(a).SetItem(a[1], v);
  Result := v;
 End;
End;

Function DictPopM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 NeedArgs(n, 2, 3, 'pop');
 If SelfDict(a).GetItem(a[1], v) Then Begin
  SelfDict(a).DelItem(a[1]);
  Result := v;
 End
 Else If n > 2 Then Result := a[2]
 Else RaiseKeyError(a[1]);
End;

Function DictPopItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
 i: Integer;
 k, v: TVal;
Begin
 d := SelfDict(a);
 For i := d.nent - 1 DownTo 0 Do
  If d.ent[i].key.k <> vkNull Then Begin
   k := d.ent[i].key;
   v := d.ent[i].val;
   d.DelItem(k);
   Result := Tup2(k, v);
   Exit;
  End;
 RaiseExc(exKeyError, 'popitem(): dictionary is empty');
 Result := vNone;
End;

Function DictUpdateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
Begin
 If n > 2 Then TypeErr('update expected at most 1 arguments, got ' +
  IntToStr(n - 1));
 If n = 2 Then DictUpdateFrom(SelfDict(a), a[1]);
 If kw <> Nil Then
  For i := 0 To kw.nent - 1 Do
   If kw.ent[i].key.k <> vkNull Then
    SelfDict(a).SetItem(kw.ent[i].key, kw.ent[i].val);
 Result := vNone;
End;

Function DictClearM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfDict(a).Clear;
 Result := vNone;
End;

Function DictCopyM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
Begin
 d := SelfDict(a).Copy;
 If a[0].o.cls.userdef Then InitObjOf(d, a[0].o.cls);
 Result := VObj(d);
End;

Function DictFromKeysM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
 arr: TValArr;
 i: Integer;
 v: TVal;
Begin
 NeedArgs(n, 2, 3, 'fromkeys');
 d := TPyDict.Make;
 If n > 2 Then v := a[2] Else v := vNone;
 arr := IterToArr(a[1]);
 For i := 0 To High(arr) Do d.SetItem(arr[i], v);
 If (a[0].k = vkObj) And (a[0].o Is TPyType) And (a[0].o <> tyDict) Then
  InitObjOf(d, TPyType(a[0].o));
 Result := VObj(d);
End;

Function DictLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(SelfDict(a).used);
End;

Function DictGetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 If SelfDict(a).GetItem(a[1], v) Then Result := v
 Else Begin
  If a[0].o.cls.userdef And LookupType(a[0].o.cls, '__missing__', v) Then
   Result := Call2(v, a[0], a[1])
  Else RaiseKeyError(a[1]);
 End;
End;

Function DictSetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfDict(a).SetItem(a[1], a[2]);
 Result := vNone;
End;

Function DictDelItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not SelfDict(a).DelItem(a[1]) Then RaiseKeyError(a[1]);
 Result := vNone;
End;

Function DictContainsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: TVal;
Begin
 Result := VBool(SelfDict(a).GetItem(a[1], v));
End;

Function DictIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := IterOf(a[0]);
End;

Function DictEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyDict)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], 2));
End;

Function DictOrM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyDict)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := BinaryOp(bopOr, a[0], a[1]);
End;

Function DictIOrM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 DictUpdateFrom(SelfDict(a), a[1]);
 Result := a[0];
End;

{ vues de dictionnaire }
Function ViewLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(TDictView(a[0].o).src.used);
End;

Function ViewIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := IterOf(a[0]);
End;

Function ViewContainsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(ContainsOp(a[0], a[1]));
End;

Function ViewToSet(Const v: TVal): TVal;
Var
 s: TPySet;
 arr: TValArr;
 i: Integer;
Begin
 s := TPySet.Make(False);
 arr := IterToArr(v);
 For i := 0 To High(arr) Do s.Add(arr[i]);
 Result := VObj(s);
End;

Function ViewReprM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 nm: AnsiString;
Begin
 arr := IterToArr(a[0]);
 Case TDictView(a[0].o).kind Of
  0: nm := 'dict_keys';
  1: nm := 'dict_values';
 Else nm := 'dict_items';
 End;
 Result := VStr(nm + '(' + ReprBytesJoin(arr, '[', ']', False) + ')');
End;

Function ViewSetOp(a: PVal; op: Integer): TVal;
Begin
 Result := BinaryOp(op, ViewToSet(a[0]), ViewToSet(a[1]));
End;

Function ViewOrM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := ViewSetOp(a, bopOr); End;
Function ViewAndM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := ViewSetOp(a, bopAnd); End;
Function ViewSubM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := ViewSetOp(a, bopSub); End;
Function ViewXorM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := ViewSetOp(a, bopXor); End;

Function ViewEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If TDictView(a[0].o).kind = 1 Then Begin
  Result := VBool((a[1].k = vkObj) And (a[0].o = a[1].o));
  Exit;
 End;
 Result := VBool(ValCompare(ViewToSet(a[0]), ViewToSet(a[1]), 2));
End;

{ ------------------------------------------------------------
  set / frozenset
  ------------------------------------------------------------ }
Function SelfSet(a: PVal): TPySet; Inline;
Begin
 Result := TPySet(a[0].o);
End;

Procedure SetFill(s: TPySet; a: PVal; n: Integer);
Var
 arr: TValArr;
 i: Integer;
Begin
 If n > 0 Then Begin
  arr := IterToArr(a[0]);
  For i := 0 To High(arr) Do s.Add(arr[i]);
 End;
End;

Function SetCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: TPySet;
Begin
 NeedArgs(n, 0, 1, 'set');
 s := TPySet.Make(False);
 SetFill(s, a, n);
 Result := VObj(s);
End;

Function FrozensetCtor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: TPySet;
Begin
 NeedArgs(n, 0, 1, 'frozenset');
 s := TPySet.Make(True);
 SetFill(s, a, n);
 Result := VObj(s);
End;

Function SetNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: TPySet;
 t: TPyType;
Begin
 t := TPyType(a[0].o);
 s := TPySet.Make(t.native = nkFrozen);
 InitObjOf(s, t);
 If t.native = nkFrozen Then SetFill(s, a + 1, n - 1);
 Result := VObj(s);
End;

Function SetInitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not SelfSet(a).frozen Then Begin
  SelfSet(a).Clear;
  SetFill(SelfSet(a), a + 1, n - 1);
 End;
 Result := vNone;
End;

Function SetAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'add');
 SelfSet(a).Add(a[1]);
 Result := vNone;
End;

Function SetRemoveM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'remove');
 If Not SelfSet(a).Discard(a[1]) Then RaiseKeyError(a[1]);
 Result := vNone;
End;

Function SetDiscardM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 NeedArgs(n, 2, 2, 'discard');
 SelfSet(a).Discard(a[1]);
 Result := vNone;
End;

Function SetPopM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: TPySet;
 i: Integer;
Begin
 s := SelfSet(a);
 For i := 0 To High(s.tab) Do
  If (s.tab[i].key.k <> vkNull) And (s.tab[i].key.k <> vkDummy) Then Begin
   Result := s.tab[i].key;
   s.Discard(Result);
   Exit;
  End;
 RaiseExc(exKeyError, 'pop from an empty set');
 Result := vNone;
End;

Function SetClearM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfSet(a).Clear;
 Result := vNone;
End;

Function SetCopyM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: TPySet;
 arr: TValArr;
 i: Integer;
Begin
 s := SelfSet(a);
 r := TPySet.Make(s.frozen);
 arr := SetItems(s);
 For i := 0 To High(arr) Do r.Add(arr[i]);
 Result := VObj(r);
End;

Function ToSetArg(Const v: TVal; frozen: Boolean): TPySet;
Var
 arr: TValArr;
 i: Integer;
Begin
 If (v.k = vkObj) And (v.o Is TPySet) Then Begin
  Result := TPySet(v.o);
  Exit;
 End;
 Result := TPySet.Make(frozen);
 arr := IterToArr(v);
 For i := 0 To High(arr) Do Result.Add(arr[i]);
End;

Function SetOpM(a: PVal; n: Integer; op: Integer): TVal;
Var
 r: TVal;
 i: Integer;
 other: TPySet;
Begin
 r := SetCopyM(a, 1, Nil);
 If op = bopAnd Then Begin
  If n < 2 Then Begin
   Result := r;
   Exit;
  End;
 End;
 For i := 1 To n - 1 Do Begin
  other := ToSetArg(a[i], False);
  r := SetBinary(op, TPySet(r.o), other);
 End;
 If op = bopAnd Then Begin
  { intersection de plusieurs ensembles : deja cumulee }
 End;
 Result := r;
End;

Function SetUnionM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetOpM(a, n, bopOr); End;
Function SetIntersectionM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetOpM(a, n, bopAnd); End;
Function SetDifferenceM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetOpM(a, n, bopSub); End;
Function SetSymDiffM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetOpM(a, n, bopXor); End;

Procedure SetReplaceWith(dst: TPySet; Const r: TVal);
Var
 arr: TValArr;
 i: Integer;
Begin
 arr := SetItems(TPySet(r.o));
 dst.Clear;
 For i := 0 To High(arr) Do dst.Add(arr[i]);
End;

Function SetUpdateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i, j: Integer;
 arr: TValArr;
Begin
 For i := 1 To n - 1 Do Begin
  arr := IterToArr(a[i]);
  For j := 0 To High(arr) Do SelfSet(a).Add(arr[j]);
 End;
 Result := vNone;
End;

Function SetInterUpdateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SetReplaceWith(SelfSet(a), SetOpM(a, n, bopAnd));
 Result := vNone;
End;

Function SetDiffUpdateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SetReplaceWith(SelfSet(a), SetOpM(a, n, bopSub));
 Result := vNone;
End;

Function SetSymDiffUpdateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SetReplaceWith(SelfSet(a), SetOpM(a, n, bopXor));
 Result := vNone;
End;

Function SetIsSubsetM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TPySet;
 arr: TValArr;
 i: Integer;
Begin
 o := ToSetArg(a[1], False);
 arr := SetItems(SelfSet(a));
 For i := 0 To High(arr) Do
  If Not o.Contains(arr[i]) Then Begin
   Result := vFalse;
   Exit;
  End;
 Result := vTrue;
End;

Function SetIsSupersetM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TPySet;
 arr: TValArr;
 i: Integer;
Begin
 o := ToSetArg(a[1], False);
 arr := SetItems(o);
 For i := 0 To High(arr) Do
  If Not SelfSet(a).Contains(arr[i]) Then Begin
   Result := vFalse;
   Exit;
  End;
 Result := vTrue;
End;

Function SetIsDisjointM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 o: TPySet;
 arr: TValArr;
 i: Integer;
Begin
 o := ToSetArg(a[1], False);
 arr := SetItems(o);
 For i := 0 To High(arr) Do
  If SelfSet(a).Contains(arr[i]) Then Begin
   Result := vFalse;
   Exit;
  End;
 Result := vTrue;
End;

Function SetLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(SelfSet(a).used);
End;

Function SetContainsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(SelfSet(a).Contains(a[1]));
End;

Function SetIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := IterOf(a[0]);
End;

Function SetHashM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(HashVal(a[0]));
End;

Function SetBinM(a: PVal; op: Integer): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPySet)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := SetBinary(op, TPySet(a[0].o), TPySet(a[1].o));
End;

Function SetOrM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetBinM(a, bopOr); End;
Function SetAndM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetBinM(a, bopAnd); End;
Function SetSubM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetBinM(a, bopSub); End;
Function SetXorM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := SetBinM(a, bopXor); End;

Function SetEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPySet)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], 2));
End;

{ ------------------------------------------------------------
  int / float / bool
  ------------------------------------------------------------ }
Function IntBitLengthM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(IntBitLength(a[0]));
End;

Function IntBitCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 neg: Boolean;
 m: TMag;
 i, c: Integer;
 w: Cardinal;
Begin
 IntToMag(a[0], neg, m);
 c := 0;
 For i := 0 To High(m) Do Begin
  w := m[i];
  While w <> 0 Do Begin
   Inc(c, w And 1);
   w := w Shr 1;
  End;
 End;
 Result := VInt(c);
End;

Function IntToBytesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 ln: Int64;
 order: AnsiString;
 signed: Boolean;
 v, x: TVal;
 r: AnsiString;
 i: Integer;
 mask: TVal;
 neg: Boolean;
 m: TMag;
 b: Cardinal;
Begin
 ln := 1;
 order := 'big';
 signed := False;
 If ArgKw(a, n, kw, 1, 'length', v) Then ln := IndexVal(v);
 If ArgKw(a, n, kw, 2, 'byteorder', v) Then order := StrOf(v);
 If KwGet(kw, 'signed', v) Then signed := IsTrue(v);
 x := a[0];
 If (IntSign(x) < 0) Then Begin
  If Not signed Then RaiseExc(exOverflow, 'can''t convert negative int to ' +
   'unsigned');
  x := IntAdd(x, IntShl(VInt(1), ln * 8));
 End;
 If IntBitLength(x) > ln * 8 Then
  RaiseExc(exOverflow, 'int too big to convert');
 IntToMag(x, neg, m);
 r := '';
 For i := 0 To ln - 1 Do Begin
  If (i Div 4) < Length(m) Then b := (m[i Div 4] Shr (8 * (i Mod 4))) And 255
  Else b := 0;
  r := r + Chr(b);
 End;
 If order = 'big' Then Begin
  v := VBytes('');
  For i := Length(r) DownTo 1 Do TPyBytes(v.o).s := TPyBytes(v.o).s + r[i];
  Result := v;
 End
 Else Result := VBytes(r);
 mask := vNone;
End;

Function IntFromBytesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, order: AnsiString;
 signed: Boolean;
 v, r: TVal;
 i: Integer;
Begin
 order := 'big';
 signed := False;
 If (a[1].k = vkObj) And (a[1].o Is TPyBytes) Then s := TPyBytes(a[1].o).s
 Else s := TPyBytes(BiBytesCtor(@a[1], 1, Nil).o).s;
 If ArgKw(a, n, kw, 2, 'byteorder', v) Then order := StrOf(v);
 If KwGet(kw, 'signed', v) Then signed := IsTrue(v);
 r := VInt(0);
 If order = 'big' Then
  For i := 1 To Length(s) Do
   r := IntAdd(IntShl(r, 8), VInt(Ord(s[i])))
 Else
  For i := Length(s) DownTo 1 Do
   r := IntAdd(IntShl(r, 8), VInt(Ord(s[i])));
 If signed And (Length(s) > 0) And ((Ord(s[IfThen(order = 'big', 1,
  Length(s))]) And $80) <> 0) Then
  r := IntSub(r, IntShl(VInt(1), Length(s) * 8));
 Result := r;
End;

Function IntConjugateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If a[0].k = vkBool Then Result := VInt(a[0].i) Else Result := a[0];
End;

Function IntIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If a[0].k = vkBool Then Result := VInt(a[0].i) Else Result := a[0];
End;

Function IntFloatM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(IntToDouble(a[0]));
End;

Function IntAsRatioM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := Tup2(a[0], VInt(1));
End;

Function IntHashM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(HashVal(a[0]));
End;

Function IntReprM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ReprVal(a[0]));
End;

Function IntArith(a: PVal; op: Integer; swap: Boolean): TVal;
Var
 r: TVal;
Begin
 If Not IsNumVal(a[1]) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 If swap Then Result := BinaryOp(op, a[1], a[0])
 Else Result := BinaryOp(op, a[0], a[1]);
 r := vNone;
End;

Function NumAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopAdd, False); End;
Function NumRAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopAdd, True); End;
Function NumSubM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopSub, False); End;
Function NumRSubM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopSub, True); End;
Function NumMulM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopMul, False); End;
Function NumRMulM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopMul, True); End;
Function NumTrueDivM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopTrueDiv, False); End;
Function NumRTrueDivM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopTrueDiv, True); End;
Function NumFloorDivM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopFloorDiv, False); End;
Function NumModM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopMod, False); End;
Function NumPowM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := IntArith(a, bopPow, False); End;
Function NumNegM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := UnaryNeg(a[0]); End;
Function NumPosM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := UnaryPos(a[0]); End;
Function NumAbsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := BiAbs(a, 1, Nil); End;

Function NumCmpM(a: PVal; op: Integer): TVal;
Begin
 If Not IsNumVal(a[1]) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(ValCompare(a[0], a[1], op));
End;

Function NumEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 2); End;
Function NumNeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 3); End;
Function NumLtM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 0); End;
Function NumLeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 1); End;
Function NumGtM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 4); End;
Function NumGeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin Result := NumCmpM(a, 5); End;

Function NumBoolM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(IsTrue(a[0]));
End;

Function IntNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If TPyType(a[0].o) <> tyInt Then TypeErr('subclassing int is not supported');
 Result := IntCtor(a + 1, n - 1, kw);
End;

Function FloatNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If TPyType(a[0].o) <> tyFloat Then
  TypeErr('subclassing float is not supported');
 Result := FloatCtor(a + 1, n - 1, kw);
End;

Function FloatIsIntegerM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool((Not IsNan(a[0].d)) And (Not IsInfinite(a[0].d)) And
  (Frac(a[0].d) = 0));
End;

Function FloatAsRatioM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 m: QWord;
 e: Integer;
 num, den: TVal;
 g, t: TVal;
Begin
 If IsNan(a[0].d) Then ValueErr('cannot convert NaN to integer ratio');
 If IsInfinite(a[0].d) Then
  RaiseExc(exOverflow, 'cannot convert Infinity to integer ratio');
 DblDecompose(Abs(a[0].d), m, e);
 num := IntFromQ(m);
 den := VInt(1);
 If e > 0 Then num := IntShl(num, e) Else If e < 0 Then den := IntShl(den, -e);
 While (IntSign(num) <> 0) And (IntSign(IntBitOp(num, VInt(1), '&')) = 0) And
  (IntCmp(den, VInt(1)) > 0) Do Begin
  num := IntShr(num, 1);
  den := IntShr(den, 1);
 End;
 If IntSign(num) = 0 Then den := VInt(1);
 If FloatSignBit(a[0].d) Then num := IntNeg(num);
 g := num;
 t := den;
 Result := Tup2(num, den);
End;

Function FloatHexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(FloatRepr(a[0].d));
End;

Function FloatFloatM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := a[0];
End;

Function FloatIntM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := DoubleToInt(Int(a[0].d));
End;

Function BoolNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := BoolCtor(a + 1, n - 1, kw);
End;

{ ------------------------------------------------------------
  bytes
  ------------------------------------------------------------ }
Function BytesDecodeM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 enc, errs, s, r: AnsiString;
 v: TVal;
 i: Integer;
Begin
 enc := 'utf-8';
 errs := 'strict';
 If ArgKw(a, n, kw, 1, 'encoding', v) Then enc := LowerCase(StrOf(v));
 If ArgKw(a, n, kw, 2, 'errors', v) Then errs := StrOf(v);
 s := TPyBytes(a[0].o).s;
 enc := StringReplace(enc, '_', '-', [rfReplaceAll]);
 If (enc = 'latin-1') Or (enc = 'latin1') Or (enc = 'iso-8859-1') Then Begin
  r := '';
  For i := 1 To Length(s) Do r := r + Utf8Enc(Ord(s[i]));
  Result := VStr(r);
  Exit;
 End;
 If (enc = 'ascii') And Not IsAsciiStr(s) Then Begin
  If errs = 'strict' Then
   Raise EPyError.Make(MakeExcArgs(exUnicodeDecodeError, [VStr('ascii'),
    a[0], VInt(0), VInt(1), VStr('ordinal not in range(128)')]));
 End;
 If (enc = 'utf-8') Or (enc = 'utf8') Or (enc = 'ascii') Then Begin
  { validation UTF-8 }
  i := 1;
  r := '';
  While i <= Length(s) Do Begin
   If Ord(s[i]) < $80 Then Begin
    r := r + s[i];
    Inc(i);
   End
   Else Begin
    v := vNone;
    If ((Ord(s[i]) >= $C2) And (Ord(s[i]) < $E0) And (i + 1 <= Length(s)) And
     ((Ord(s[i + 1]) And $C0) = $80)) Or
     ((Ord(s[i]) >= $E0) And (Ord(s[i]) < $F0) And (i + 2 <= Length(s)) And
     ((Ord(s[i + 1]) And $C0) = $80) And ((Ord(s[i + 2]) And $C0) = $80)) Or
     ((Ord(s[i]) >= $F0) And (Ord(s[i]) < $F5) And (i + 3 <= Length(s)) And
     ((Ord(s[i + 1]) And $C0) = $80) And ((Ord(s[i + 2]) And $C0) = $80) And
     ((Ord(s[i + 3]) And $C0) = $80)) Then Begin
     If Ord(s[i]) < $E0 Then Begin
      r := r + Copy(s, i, 2);
      Inc(i, 2);
     End
     Else If Ord(s[i]) < $F0 Then Begin
      r := r + Copy(s, i, 3);
      Inc(i, 3);
     End
     Else Begin
      r := r + Copy(s, i, 4);
      Inc(i, 4);
     End;
    End
    Else Begin
     If errs = 'ignore' Then Inc(i)
     Else If errs = 'replace' Then Begin
      r := r + #$EF#$BF#$BD;
      Inc(i);
     End
     Else
      Raise EPyError.Make(MakeExcArgs(exUnicodeDecodeError, [VStr('utf-8'),
       a[0], VInt(i - 1), VInt(i), VStr('invalid start byte')]));
    End;
   End;
  End;
  Result := VStr(r);
  Exit;
 End;
 RaiseExc(exLookupError, 'unknown encoding: ' + enc);
 Result := vNone;
End;

Function BytesHexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 i: Integer;
Begin
 s := TPyBytes(a[0].o).s;
 r := '';
 For i := 1 To Length(s) Do r := r + LowerCase(IntToHex(Ord(s[i]), 2));
 Result := VStr(r);
End;

Function BytesFromHexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, r: AnsiString;
 i: Integer;
Begin
 s := StringReplace(StrOf(a[1]), ' ', '', [rfReplaceAll]);
 If Odd(Length(s)) Then ValueErr('non-hexadecimal number found in fromhex()');
 r := '';
 i := 1;
 While i < Length(s) Do Begin
  r := r + Chr(StrToInt('$' + Copy(s, i, 2)));
  Inc(i, 2);
 End;
 Result := VBytes(r);
End;

Function BytesLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(Length(TPyBytes(a[0].o).s));
End;

Function BytesGetItemM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := GetItem(a[0], a[1]);
End;

Function BytesIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := IterOf(a[0]);
End;

Function BytesJoinM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 i: Integer;
 r: AnsiString;
Begin
 arr := IterToArr(a[1]);
 r := '';
 For i := 0 To High(arr) Do Begin
  If i > 0 Then r := r + TPyBytes(a[0].o).s;
  If Not ((arr[i].k = vkObj) And (arr[i].o Is TPyBytes)) Then
   TypeErr('sequence item ' + IntToStr(i) + ': expected a bytes-like object, '
    + TypeName(arr[i]) + ' found');
  r := r + TPyBytes(arr[i].o).s;
 End;
 Result := VBytes(r);
End;

Function BytesFromStr(Const v: TVal): AnsiString;
Begin
 If (v.k = vkObj) And (v.o Is TPyBytes) Then Result := TPyBytes(v.o).s
 Else Begin
  TypeErr('a bytes-like object is required, not ''' + TypeName(v) + '''');
  Result := '';
 End;
End;

Function BytesStartsWithM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, p: AnsiString;
Begin
 s := TPyBytes(a[0].o).s;
 p := BytesFromStr(a[1]);
 Result := VBool(Copy(s, 1, Length(p)) = p);
End;

Function BytesEndsWithM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, p: AnsiString;
Begin
 s := TPyBytes(a[0].o).s;
 p := BytesFromStr(a[1]);
 Result := VBool((Length(s) >= Length(p)) And
  (Copy(s, Length(s) - Length(p) + 1, Length(p)) = p));
End;

Function BytesFindM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(Pos(BytesFromStr(a[1]), TPyBytes(a[0].o).s) - 1);
End;

Function BytesReplaceM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBytes(StringReplace(TPyBytes(a[0].o).s, BytesFromStr(a[1]),
  BytesFromStr(a[2]), [rfReplaceAll]));
End;

Function BytesUpperM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBytes(UpperCase(TPyBytes(a[0].o).s));
End;

Function BytesLowerM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBytes(LowerCase(TPyBytes(a[0].o).s));
End;

Function BytesStripM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBytes(Trim(TPyBytes(a[0].o).s));
End;

Function BytesSplitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 l: TPyList;
 s, sep: AnsiString;
 st, p: Integer;
Begin
 l := NewList;
 s := TPyBytes(a[0].o).s;
 If (n < 2) Or (a[1].k = vkNone) Then Begin
  st := 1;
  p := 1;
  While p <= Length(s) Do Begin
   While (p <= Length(s)) And (s[p] In [' ', #9, #10, #13, #11, #12]) Do Inc(p);
   If p > Length(s) Then Break;
   st := p;
   While (p <= Length(s)) And Not (s[p] In [' ', #9, #10, #13, #11, #12]) Do
    Inc(p);
   l.Add(VBytes(Copy(s, st, p - st)));
  End;
 End
 Else Begin
  sep := BytesFromStr(a[1]);
  st := 1;
  p := PosEx(sep, s, st);
  While p > 0 Do Begin
   l.Add(VBytes(Copy(s, st, p - st)));
   st := p + Length(sep);
   p := PosEx(sep, s, st);
  End;
  l.Add(VBytes(Copy(s, st, Length(s))));
 End;
 Result := VObj(l);
End;

Function BytesAddM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBytes(TPyBytes(a[0].o).s + BytesFromStr(a[1]));
End;

Function BytesEqM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not ((a[1].k = vkObj) And (a[1].o Is TPyBytes)) Then Begin
  Result := vNotImpl;
  Exit;
 End;
 Result := VBool(TPyBytes(a[0].o).s = TPyBytes(a[1].o).s);
End;

Function BytesHashM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(HashVal(a[0]));
End;

{ ------------------------------------------------------------
  Generateurs et iterateurs
  ------------------------------------------------------------ }
Function GenNextM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
 g: TPyGen;
Begin
 g := TPyGen(a[0].o);
 If GenResume(g, vNone, r) Then Result := r
 Else RaiseStopIteration(NoneIfNull(g.retval));
End;

Function GenSendM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
 g: TPyGen;
Begin
 NeedArgs(n, 2, 2, 'send');
 g := TPyGen(a[0].o);
 If GenResume(g, a[1], r) Then Result := r
 Else RaiseStopIteration(NoneIfNull(g.retval));
End;

Function GenThrowM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 g: TPyGen;
 e: TVal;
 r: TVal;
Begin
 NeedArgs(n, 2, 4, 'throw');
 g := TPyGen(a[0].o);
 If n > 2 Then e := CallValue(a[1], @a[2], 1, Nil)
 Else e := NormalizeExc(a[1], False);
 If (g.state = 0) Or (g.state = 3) Then Begin
  g.state := 3;
  Raise EPyError.Make(e.o);
 End;
 g.frame.throwExc := e.o;
 If GenResume(g, vNone, r) Then Result := r
 Else RaiseStopIteration(NoneIfNull(g.retval));
End;

Function GenCloseM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 g: TPyGen;
 r: TVal;
Begin
 g := TPyGen(a[0].o);
 Result := vNone;
 If g.state = 0 Then Begin
  g.state := 3;
  Exit;
 End;
 If g.state = 3 Then Exit;
 g.frame.throwExc := MakeExc(exGeneratorExit, '');
 Try
  If GenResume(g, vNone, r) Then
   RaiseExc(exRuntimeError, 'generator ignored GeneratorExit');
 Except
  On E: EPyError Do Begin
   If IsInstance(VObj(E.exc), exGeneratorExit) Or
    IsInstance(VObj(E.exc), exStopIteration) Then Exit;
   Raise;
  End;
 End;
End;

Function IterSelfM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := a[0];
End;

Function IterNextM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TVal;
Begin
 If IterNextVal(a[0], r) Then Result := r
 Else RaiseStopIteration(vNone);
End;

Function ListLenHintM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(0);
End;

{ ------------------------------------------------------------
  fonctions, methodes, modules, etc.
  ------------------------------------------------------------ }
Function FuncCallM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := CallValue(a[0], a + 1, n - 1, kw);
End;

Function MethodCallM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := CallValue(a[0], a + 1, n - 1, kw);
End;

Function NoneBoolM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vFalse;
End;

Function NoneReprM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr('None');
End;

Function RangeIndexM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyRange;
 x: Int64;
Begin
 r := TPyRange(a[0].o);
 If ContainsOp(a[0], a[1]) Then Begin
  x := (a[1].i - r.start) Div r.step;
  Result := VInt(x);
 End
 Else Begin
  ValueErr(ReprVal(a[1]) + ' is not in range');
  Result := vNone;
 End;
End;

Function RangeCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If ContainsOp(a[0], a[1]) Then Result := VInt(1) Else Result := VInt(0);
End;

Function RangeLenM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(TPyRange(a[0].o).len);
End;

Function RangeReversedM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyRange;
 it: TRangeIter;
Begin
 r := TPyRange(a[0].o);
 it := TRangeIter.Create(tyIter);
 it.cur := r.start + (r.len - 1) * r.step;
 it.step := -r.step;
 it.stop := r.start - r.step;
 Result := VObj(it);
End;

Function CellNewM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vNone;
End;

Procedure InitContainerMethods;
Begin
 { list }
 tyList.ctor := @ListCtor;
 tyList.idict.SetS('__new__', VObj(NewBuiltin('__new__', @ListNewM)));
 DefMethod(tyList, '__init__', @ListInitM);
 DefMethod(tyList, 'append', @ListAppendM);
 DefMethod(tyList, 'extend', @ListExtendM);
 DefMethod(tyList, 'insert', @ListInsertM);
 DefMethod(tyList, 'remove', @ListRemoveM);
 DefMethod(tyList, 'pop', @ListPopM);
 DefMethod(tyList, 'clear', @ListClearM);
 DefMethod(tyList, 'index', @ListIndexM);
 DefMethod(tyList, 'count', @ListCountM);
 DefMethod(tyList, 'sort', @ListSortM);
 DefMethod(tyList, 'reverse', @ListReverseM);
 DefMethod(tyList, 'copy', @ListCopyM);
 DefMethod(tyList, '__len__', @ListLenM);
 DefMethod(tyList, '__getitem__', @ListGetItemM);
 DefMethod(tyList, '__setitem__', @ListSetItemM);
 DefMethod(tyList, '__delitem__', @ListDelItemM);
 DefMethod(tyList, '__contains__', @ListContainsM);
 DefMethod(tyList, '__iter__', @ListIterM);
 DefMethod(tyList, '__reversed__', @ListReversedM);
 DefMethod(tyList, '__add__', @ListAddM);
 DefMethod(tyList, '__mul__', @ListMulM);
 DefMethod(tyList, '__rmul__', @ListMulM);
 DefMethod(tyList, '__iadd__', @ListIAddM);
 DefMethod(tyList, '__eq__', @ListEqM);
 DefMethod(tyList, '__lt__', @ListLtM);
 DefMethod(tyList, '__repr__', @ListReprM);
 { tuple }
 tyTuple.ctor := @TupleCtor;
 tyTuple.idict.SetS('__new__', VObj(NewBuiltin('__new__', @TupleNewM)));
 DefMethod(tyTuple, 'count', @TupleCountM);
 DefMethod(tyTuple, 'index', @TupleIndexM);
 DefMethod(tyTuple, '__len__', @TupleLenM);
 DefMethod(tyTuple, '__getitem__', @ListGetItemM);
 DefMethod(tyTuple, '__contains__', @ListContainsM);
 DefMethod(tyTuple, '__iter__', @StrIterM);
 DefMethod(tyTuple, '__hash__', @TupleHashM);
 DefMethod(tyTuple, '__eq__', @TupleEqM);
 DefMethod(tyTuple, '__add__', @TupleAddM);
 DefMethod(tyTuple, '__repr__', @ListReprM);
 { dict }
 tyDict.ctor := @DictCtor;
 tyDict.idict.SetS('__new__', VObj(NewBuiltin('__new__', @DictNewM)));
 DefMethod(tyDict, '__init__', @DictInitM);
 DefMethod(tyDict, 'keys', @DictKeysM);
 DefMethod(tyDict, 'values', @DictValuesM);
 DefMethod(tyDict, 'items', @DictItemsM);
 DefMethod(tyDict, 'get', @DictGetM);
 DefMethod(tyDict, 'setdefault', @DictSetDefaultM);
 DefMethod(tyDict, 'pop', @DictPopM);
 DefMethod(tyDict, 'popitem', @DictPopItemM);
 DefMethod(tyDict, 'update', @DictUpdateM);
 DefMethod(tyDict, 'clear', @DictClearM);
 DefMethod(tyDict, 'copy', @DictCopyM);
 DefClassMethod(tyDict, 'fromkeys', @DictFromKeysM);
 DefMethod(tyDict, '__len__', @DictLenM);
 DefMethod(tyDict, '__getitem__', @DictGetItemM);
 DefMethod(tyDict, '__setitem__', @DictSetItemM);
 DefMethod(tyDict, '__delitem__', @DictDelItemM);
 DefMethod(tyDict, '__contains__', @DictContainsM);
 DefMethod(tyDict, '__iter__', @DictIterM);
 DefMethod(tyDict, '__eq__', @DictEqM);
 DefMethod(tyDict, '__or__', @DictOrM);
 DefMethod(tyDict, '__ior__', @DictIOrM);
 DefMethod(tyDict, '__repr__', @ListReprM);
 DefMethod(tyDictView, '__len__', @ViewLenM);
 DefMethod(tyDictView, '__iter__', @ViewIterM);
 DefMethod(tyDictView, '__contains__', @ViewContainsM);
 DefMethod(tyDictView, '__repr__', @ViewReprM);
 DefMethod(tyDictView, '__or__', @ViewOrM);
 DefMethod(tyDictView, '__and__', @ViewAndM);
 DefMethod(tyDictView, '__sub__', @ViewSubM);
 DefMethod(tyDictView, '__xor__', @ViewXorM);
 DefMethod(tyDictView, '__eq__', @ViewEqM);
 { set / frozenset }
 tySet.ctor := @SetCtor;
 tyFrozenset.ctor := @FrozensetCtor;
 tySet.idict.SetS('__new__', VObj(NewBuiltin('__new__', @SetNewM)));
 tyFrozenset.idict.SetS('__new__', VObj(NewBuiltin('__new__', @SetNewM)));
 DefMethod(tySet, '__init__', @SetInitM);
 DefMethod(tySet, 'add', @SetAddM);
 DefMethod(tySet, 'remove', @SetRemoveM);
 DefMethod(tySet, 'discard', @SetDiscardM);
 DefMethod(tySet, 'pop', @SetPopM);
 DefMethod(tySet, 'clear', @SetClearM);
 DefMethod(tySet, 'update', @SetUpdateM);
 DefMethod(tySet, 'intersection_update', @SetInterUpdateM);
 DefMethod(tySet, 'difference_update', @SetDiffUpdateM);
 DefMethod(tySet, 'symmetric_difference_update', @SetSymDiffUpdateM);
 DefMethod(tySet, '__ior__', @SetUpdateM);
 DefMethod(tySet, '__hash__', @SetHashM);
 tySet.idict.SetS('__hash__', vNone);
 tyFrozenset.idict.SetS('__hash__', VObj(NewBuiltin('__hash__', @SetHashM)));
 DefMethod(tySet, 'copy', @SetCopyM);
 DefMethod(tyFrozenset, 'copy', @SetCopyM);
 DefMethod(tySet, 'union', @SetUnionM);
 DefMethod(tyFrozenset, 'union', @SetUnionM);
 DefMethod(tySet, 'intersection', @SetIntersectionM);
 DefMethod(tyFrozenset, 'intersection', @SetIntersectionM);
 DefMethod(tySet, 'difference', @SetDifferenceM);
 DefMethod(tyFrozenset, 'difference', @SetDifferenceM);
 DefMethod(tySet, 'symmetric_difference', @SetSymDiffM);
 DefMethod(tyFrozenset, 'symmetric_difference', @SetSymDiffM);
 DefMethod(tySet, 'issubset', @SetIsSubsetM);
 DefMethod(tyFrozenset, 'issubset', @SetIsSubsetM);
 DefMethod(tySet, 'issuperset', @SetIsSupersetM);
 DefMethod(tyFrozenset, 'issuperset', @SetIsSupersetM);
 DefMethod(tySet, 'isdisjoint', @SetIsDisjointM);
 DefMethod(tyFrozenset, 'isdisjoint', @SetIsDisjointM);
 DefMethod(tySet, '__len__', @SetLenM);
 DefMethod(tyFrozenset, '__len__', @SetLenM);
 DefMethod(tySet, '__contains__', @SetContainsM);
 DefMethod(tyFrozenset, '__contains__', @SetContainsM);
 DefMethod(tySet, '__iter__', @SetIterM);
 DefMethod(tyFrozenset, '__iter__', @SetIterM);
 DefMethod(tySet, '__or__', @SetOrM);
 DefMethod(tyFrozenset, '__or__', @SetOrM);
 DefMethod(tySet, '__and__', @SetAndM);
 DefMethod(tyFrozenset, '__and__', @SetAndM);
 DefMethod(tySet, '__sub__', @SetSubM);
 DefMethod(tyFrozenset, '__sub__', @SetSubM);
 DefMethod(tySet, '__xor__', @SetXorM);
 DefMethod(tyFrozenset, '__xor__', @SetXorM);
 DefMethod(tySet, '__eq__', @SetEqM);
 DefMethod(tyFrozenset, '__eq__', @SetEqM);
 { int / float / bool }
 tyInt.idict.SetS('__new__', VObj(NewBuiltin('__new__', @IntNewM)));
 tyFloat.idict.SetS('__new__', VObj(NewBuiltin('__new__', @FloatNewM)));
 tyBool.idict.SetS('__new__', VObj(NewBuiltin('__new__', @BoolNewM)));
 DefMethod(tyInt, 'bit_length', @IntBitLengthM);
 DefMethod(tyInt, 'bit_count', @IntBitCountM);
 DefMethod(tyInt, 'to_bytes', @IntToBytesM);
 DefClassMethod(tyInt, 'from_bytes', @IntFromBytesM);
 DefMethod(tyInt, 'conjugate', @IntConjugateM);
 DefMethod(tyInt, '__index__', @IntIndexM);
 DefMethod(tyInt, '__int__', @IntIndexM);
 DefMethod(tyInt, '__trunc__', @IntIndexM);
 DefMethod(tyInt, '__floor__', @IntIndexM);
 DefMethod(tyInt, '__ceil__', @IntIndexM);
 DefMethod(tyInt, '__float__', @IntFloatM);
 DefMethod(tyInt, 'as_integer_ratio', @IntAsRatioM);
 DefMethod(tyInt, '__hash__', @IntHashM);
 DefMethod(tyInt, '__repr__', @IntReprM);
 DefMethod(tyInt, '__str__', @IntReprM);
 DefMethod(tyFloat, 'is_integer', @FloatIsIntegerM);
 DefMethod(tyFloat, 'as_integer_ratio', @FloatAsRatioM);
 DefMethod(tyFloat, 'hex', @FloatHexM);
 DefMethod(tyFloat, '__float__', @FloatFloatM);
 DefMethod(tyFloat, '__int__', @FloatIntM);
 DefMethod(tyFloat, '__trunc__', @FloatIntM);
 DefMethod(tyFloat, 'conjugate', @FloatFloatM);
 DefMethod(tyFloat, '__hash__', @IntHashM);
 DefMethod(tyFloat, '__repr__', @IntReprM);
 DefMethod(tyFloat, '__str__', @IntReprM);
 DefMethod(tyInt, '__add__', @NumAddM);
 DefMethod(tyInt, '__radd__', @NumRAddM);
 DefMethod(tyInt, '__sub__', @NumSubM);
 DefMethod(tyInt, '__rsub__', @NumRSubM);
 DefMethod(tyInt, '__mul__', @NumMulM);
 DefMethod(tyInt, '__rmul__', @NumRMulM);
 DefMethod(tyInt, '__truediv__', @NumTrueDivM);
 DefMethod(tyInt, '__rtruediv__', @NumRTrueDivM);
 DefMethod(tyInt, '__floordiv__', @NumFloorDivM);
 DefMethod(tyInt, '__mod__', @NumModM);
 DefMethod(tyInt, '__pow__', @NumPowM);
 DefMethod(tyInt, '__neg__', @NumNegM);
 DefMethod(tyInt, '__pos__', @NumPosM);
 DefMethod(tyInt, '__abs__', @NumAbsM);
 DefMethod(tyInt, '__bool__', @NumBoolM);
 DefMethod(tyInt, '__eq__', @NumEqM);
 DefMethod(tyInt, '__ne__', @NumNeM);
 DefMethod(tyInt, '__lt__', @NumLtM);
 DefMethod(tyInt, '__le__', @NumLeM);
 DefMethod(tyInt, '__gt__', @NumGtM);
 DefMethod(tyInt, '__ge__', @NumGeM);
 DefMethod(tyFloat, '__add__', @NumAddM);
 DefMethod(tyFloat, '__radd__', @NumRAddM);
 DefMethod(tyFloat, '__sub__', @NumSubM);
 DefMethod(tyFloat, '__rsub__', @NumRSubM);
 DefMethod(tyFloat, '__mul__', @NumMulM);
 DefMethod(tyFloat, '__rmul__', @NumRMulM);
 DefMethod(tyFloat, '__truediv__', @NumTrueDivM);
 DefMethod(tyFloat, '__rtruediv__', @NumRTrueDivM);
 DefMethod(tyFloat, '__floordiv__', @NumFloorDivM);
 DefMethod(tyFloat, '__mod__', @NumModM);
 DefMethod(tyFloat, '__pow__', @NumPowM);
 DefMethod(tyFloat, '__neg__', @NumNegM);
 DefMethod(tyFloat, '__pos__', @NumPosM);
 DefMethod(tyFloat, '__abs__', @NumAbsM);
 DefMethod(tyFloat, '__bool__', @NumBoolM);
 DefMethod(tyFloat, '__eq__', @NumEqM);
 DefMethod(tyFloat, '__ne__', @NumNeM);
 DefMethod(tyFloat, '__lt__', @NumLtM);
 DefMethod(tyFloat, '__le__', @NumLeM);
 DefMethod(tyFloat, '__gt__', @NumGtM);
 DefMethod(tyFloat, '__ge__', @NumGeM);
 { bytes }
 DefMethod(tyBytes, 'decode', @BytesDecodeM);
 DefMethod(tyBytes, 'hex', @BytesHexM);
 DefStaticMethod(tyBytes, 'fromhex', @BytesFromHexM);
 DefMethod(tyBytes, '__len__', @BytesLenM);
 DefMethod(tyBytes, '__getitem__', @BytesGetItemM);
 DefMethod(tyBytes, '__iter__', @BytesIterM);
 DefMethod(tyBytes, 'join', @BytesJoinM);
 DefMethod(tyBytes, 'startswith', @BytesStartsWithM);
 DefMethod(tyBytes, 'endswith', @BytesEndsWithM);
 DefMethod(tyBytes, 'find', @BytesFindM);
 DefMethod(tyBytes, 'replace', @BytesReplaceM);
 DefMethod(tyBytes, 'upper', @BytesUpperM);
 DefMethod(tyBytes, 'lower', @BytesLowerM);
 DefMethod(tyBytes, 'strip', @BytesStripM);
 DefMethod(tyBytes, 'split', @BytesSplitM);
 DefMethod(tyBytes, '__add__', @BytesAddM);
 DefMethod(tyBytes, '__eq__', @BytesEqM);
 DefMethod(tyBytes, '__hash__', @BytesHashM);
 { generateurs et iterateurs }
 DefMethod(tyGenerator, '__next__', @GenNextM);
 DefMethod(tyGenerator, 'send', @GenSendM);
 DefMethod(tyGenerator, 'throw', @GenThrowM);
 DefMethod(tyGenerator, 'close', @GenCloseM);
 DefMethod(tyGenerator, '__iter__', @IterSelfM);
 DefMethod(tyIter, '__iter__', @IterSelfM);
 DefMethod(tyIter, '__next__', @IterNextM);
 DefMethod(tyIter, '__length_hint__', @ListLenHintM);
 DefMethod(tyRange, 'index', @RangeIndexM);
 DefMethod(tyRange, 'count', @RangeCountM);
 DefMethod(tyRange, '__len__', @RangeLenM);
 DefMethod(tyRange, '__reversed__', @RangeReversedM);
 DefMethod(tyRange, '__iter__', @StrIterM);
 DefMethod(tyRange, '__getitem__', @ListGetItemM);
 DefMethod(tyRange, '__contains__', @ListContainsM);
 DefMethod(tyNone, '__bool__', @NoneBoolM);
 DefMethod(tyNone, '__repr__', @NoneReprM);
End;

{ ------------------------------------------------------------
  Fichiers
  ------------------------------------------------------------ }
Var
 OpenFiles: Array Of TPyFile;
 NOpenFiles: Integer;

Procedure RaiseOSErr(cls: TPyType; errno: Integer; Const strerror, fname:
 AnsiString);
Var
 o: TPyObj;
 args: Array Of TVal;
Begin
 If fname <> '' Then Begin
  SetLength(args, 3);
  args[0] := VInt(errno);
  args[1] := VStr(strerror);
  args[2] := VStr(fname);
 End
 Else Begin
  SetLength(args, 2);
  args[0] := VInt(errno);
  args[1] := VStr(strerror);
 End;
 o := MakeExcArgs(cls, args);
 o.idict.SetS('errno', VInt(errno));
 o.idict.SetS('strerror', VStr(strerror));
 If fname <> '' Then o.idict.SetS('filename', VStr(fname))
 Else o.idict.SetS('filename', vNone);
 Raise EPyError.Make(o);
End;

Procedure RaiseNoEnt(Const fname: AnsiString);
Begin
 RaiseOSErr(exFileNotFound, 2, 'No such file or directory', fname);
End;

Function ReadWholeFile(Const fname: AnsiString; Var data: AnsiString): Boolean;
Var
 h: THandle;
 buf: AnsiString;
 n: LongInt;
Begin
 Result := False;
 h := FileOpen(fname, fmOpenRead Or fmShareDenyNone);
 If h = THandle(-1) Then Exit;
 data := '';
 SetLength(buf, 65536);
 Repeat
  n := FileRead(h, buf[1], 65536);
  If n > 0 Then data := data + Copy(buf, 1, n);
 Until n <= 0;
 FileClose(h);
 Result := True;
End;

Procedure FileFlushObj(f: TPyFile);
Var
 h: THandle;
Begin
 If (f.std <> 0) Or Not f.dirty Or f.closed Then Exit;
 h := FileCreate(f.fname);
 If h = THandle(-1) Then
  RaiseOSErr(exPermissionError, 13, 'Permission denied', f.fname);
 If Length(f.data) > 0 Then FileWrite(h, f.data[1], Length(f.data));
 FileClose(h);
 f.dirty := False;
End;

Procedure FileCloseObj(f: TPyFile);
Var
 i: Integer;
Begin
 If f.closed Then Exit;
 If f.std = 0 Then Begin
  FileFlushObj(f);
  For i := 0 To NOpenFiles - 1 Do
   If OpenFiles[i] = f Then Begin
    OpenFiles[i] := OpenFiles[NOpenFiles - 1];
    Dec(NOpenFiles);
    Break;
   End;
 End
 Else If f.std = 2 Then OutFlush;
 f.closed := True;
 f.data := '';
End;

Procedure FlushAllFiles;
Var
 i: Integer;
Begin
 For i := NOpenFiles - 1 DownTo 0 Do
  If i < NOpenFiles Then FileFlushObj(OpenFiles[i]);
 OutFlush;
End;

Procedure FileWriteStr(f: TPyFile; Const s: AnsiString);
Var
 n: Integer;
Begin
 If f.closed Then ValueErr('I/O operation on closed file.');
 Case f.std Of
  2: Begin OutWrite(s); Exit; End;
  3: Begin ErrWrite(s); Exit; End;
  1: RaiseOSErr(exOSError, 9, 'Bad file descriptor', '');
 End;
 If Not f.writable Then
  RaiseExc(TPyType(exOSError), 'not writable');
 If f.appendm Then f.pos := Length(f.data);
 n := Length(s);
 If f.pos >= Length(f.data) Then Begin
  f.data := f.data + s;
 End
 Else Begin
  If f.pos + n >= Length(f.data) Then
   f.data := Copy(f.data, 1, f.pos) + s
  Else
   f.data := Copy(f.data, 1, f.pos) + s + Copy(f.data, f.pos + n + 1,
    Length(f.data));
 End;
 Inc(f.pos, n);
 f.dirty := True;
End;

Function OpenFileObj(Const name, mode: AnsiString): TPyFile;
Var
 f: TPyFile;
 data: AnsiString;
 i: Integer;
 plus, ok: Boolean;
 m: Char;
Begin
 m := #0;
 plus := Pos('+', mode) > 0;
 For i := 1 To Length(mode) Do
  If mode[i] In ['r', 'w', 'a', 'x'] Then Begin
   If m <> #0 Then
    ValueErr('must have exactly one of create/read/write/append mode');
   m := mode[i];
  End
  Else If Not (mode[i] In ['b', 't', '+', 'U']) Then
   ValueErr('invalid mode: ''' + mode + '''');
 If m = #0 Then ValueErr('Must have exactly one of create/read/write/append ' +
  'mode and at most one plus');
 f := TPyFile.Create(tyFile);
 f.fname := name;
 f.mode := mode;
 f.binary := Pos('b', mode) > 0;
 f.readable := (m = 'r') Or plus;
 f.writable := (m <> 'r') Or plus;
 f.appendm := m = 'a';
 f.pos := 0;
 f.std := 0;
 f.closed := False;
 f.dirty := False;
 If DirectoryExists(name) Then
  RaiseOSErr(exIsADirectory, 21, 'Is a directory', name);
 Case m Of
  'r': Begin
    If Not FileExists(name) Then RaiseNoEnt(name);
    ok := ReadWholeFile(name, data);
    If Not ok Then
     RaiseOSErr(exPermissionError, 13, 'Permission denied', name);
    f.data := data;
   End;
  'a': Begin
    If FileExists(name) Then Begin
     ReadWholeFile(name, data);
     f.data := data;
    End;
    f.pos := Length(f.data);
    f.dirty := True;
   End;
  'x': Begin
    If FileExists(name) Then
     RaiseOSErr(exFileExists, 17, 'File exists', name);
    f.data := '';
    f.dirty := True;
   End;
 Else
  f.data := '';
  f.dirty := True;
 End;
 If m <> 'r' Then Begin
  { creation immediate pour detecter les erreurs }
  FileFlushObj(f);
  f.dirty := m <> 'a';
  If m = 'w' Then f.dirty := True;
 End;
 If (m = 'r') Or (Pos('r', mode) > 0) Then Begin
  If Not f.binary And (Pos(#13, f.data) > 0) Then Begin
   f.data := StringReplace(f.data, #13#10, #10, [rfReplaceAll]);
   f.data := StringReplace(f.data, #13, #10, [rfReplaceAll]);
  End;
 End;
 If f.writable Then Begin
  If NOpenFiles >= Length(OpenFiles) Then
   SetLength(OpenFiles, NOpenFiles * 2 + 8);
  OpenFiles[NOpenFiles] := f;
  Inc(NOpenFiles);
 End;
 Result := f;
End;

Function BiOpen(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 name, mode: AnsiString;
 v: TVal;
Begin
 NeedArgs(n, 1, 8, 'open()');
 If IsIntVal(a[0]) Then
  TypeErr('open() with file descriptors is not supported');
 If (a[0].k = vkObj) And (a[0].o Is TPyBytes) Then name := TPyBytes(a[0].o).s
 Else If IsStrVal(a[0]) Then name := TPyStr(a[0].o).s
 Else If HasAttr(a[0], '__fspath__') Then
  name := StrVal(Call0(GetAttr(a[0], '__fspath__')))
 Else Begin
  TypeErr('expected str, bytes or os.PathLike object, not ' +
   TypeName(a[0]));
  name := '';
 End;
 mode := 'r';
 If n > 1 Then mode := StrOf(a[1])
 Else If KwGet(kw, 'mode', v) Then mode := StrOf(v);
 Result := VObj(OpenFileObj(name, mode));
End;

Function SelfFile(a: PVal): TPyFile;
Begin
 If Not ((a[0].k = vkObj) And (a[0].o Is TPyFile)) Then
  TypeErr('descriptor requires a file object');
 Result := TPyFile(a[0].o);
 If Result.closed Then ValueErr('I/O operation on closed file.');
End;

Function FileOut(f: TPyFile; Const s: AnsiString): TVal;
Begin
 If f.binary Then Result := VBytes(s) Else Result := VStr(s);
End;

Function FileReadM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 sz: Int64;
 s: AnsiString;
 i, e: Integer;
Begin
 f := SelfFile(a);
 sz := -1;
 If (n > 1) And (a[1].k <> vkNone) Then sz := IndexVal(a[1]);
 If f.std = 1 Then Begin
  If sz < 0 Then s := StdinReadAll
  Else Begin
   OutFlush;
   If f.binary Then s := StdinReadN(sz)
   Else Begin
    s := '';
    For i := 1 To sz Do Begin
     e := Length(s);
     s := s + StdinReadN(1);
     If Length(s) = e Then Break;
     { completer un caractere UTF-8 }
     While (Length(s) > 0) And ((Ord(s[Length(s)]) And $C0) = $80) And False
      Do ;
    End;
   End;
  End;
  Result := FileOut(f, s);
  Exit;
 End;
 If Not f.readable Then
  RaiseOSErr(exOSError, 9, 'not readable', '');
 If sz < 0 Then Begin
  s := Copy(f.data, f.pos + 1, Length(f.data));
  f.pos := Length(f.data);
 End
 Else If f.binary Then Begin
  s := Copy(f.data, f.pos + 1, sz);
  Inc(f.pos, Length(s));
 End
 Else Begin
  { sz caracteres }
  i := f.pos + 1;
  e := 0;
  While (i <= Length(f.data)) And (e < sz) Do Begin
   Utf8Dec(f.data, i);
   Inc(e);
  End;
  s := Copy(f.data, f.pos + 1, i - f.pos - 1);
  f.pos := i - 1;
 End;
 Result := FileOut(f, s);
End;

Function FileReadLineImpl(f: TPyFile; Var line: AnsiString; limit: Int64):
 Boolean;
Var
 p: Integer;
Begin
 If f.std = 1 Then Begin
  OutFlush;
  Result := StdinReadLine(line);
  Exit;
 End;
 If Not f.readable Then RaiseOSErr(exOSError, 9, 'not readable', '');
 If f.pos >= Length(f.data) Then Begin
  Result := False;
  Exit;
 End;
 p := PosEx(#10, f.data, f.pos + 1);
 If p = 0 Then p := Length(f.data);
 line := Copy(f.data, f.pos + 1, p - f.pos);
 If (limit >= 0) And (Length(line) > limit) Then line := Copy(line, 1, limit);
 Inc(f.pos, Length(line));
 Result := True;
End;

Function FileReadLineM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 line: AnsiString;
 lim: Int64;
Begin
 f := SelfFile(a);
 lim := -1;
 If (n > 1) And (a[1].k <> vkNone) Then lim := IndexVal(a[1]);
 If FileReadLineImpl(f, line, lim) Then Result := FileOut(f, line)
 Else Result := FileOut(f, '');
End;

Function FileReadLinesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 line: AnsiString;
 l: TPyList;
Begin
 f := SelfFile(a);
 l := NewList;
 While FileReadLineImpl(f, line, -1) Do l.Add(FileOut(f, line));
 Result := VObj(l);
End;

Function FileWriteM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
Begin
 NeedArgs(n, 2, 2, 'write');
 f := SelfFile(a);
 If f.binary Then Begin
  If Not ((a[1].k = vkObj) And (a[1].o Is TPyBytes)) Then
   TypeErr('a bytes-like object is required, not ''' + TypeName(a[1]) + '''');
  FileWriteStr(f, TPyBytes(a[1].o).s);
  Result := VInt(Length(TPyBytes(a[1].o).s));
 End
 Else Begin
  If Not IsStrVal(a[1]) Then
   TypeErr('write() argument must be str, not ' + TypeName(a[1]));
  FileWriteStr(f, TPyStr(a[1].o).s);
  Result := VInt(PyStrLen(TPyStr(a[1].o)));
 End;
End;

Function FileWriteLinesM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 arr: TValArr;
 i: Integer;
 args: Array[0..1] Of TVal;
Begin
 f := SelfFile(a);
 arr := IterToArr(a[1]);
 For i := 0 To High(arr) Do Begin
  args[0] := a[0];
  args[1] := arr[i];
  FileWriteM(@args[0], 2, Nil);
 End;
 Result := vNone;
End;

Function FileCloseM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 FileCloseObj(TPyFile(a[0].o));
 Result := vNone;
End;

Function FileFlushM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
Begin
 f := SelfFile(a);
 If f.std = 2 Then OutFlush Else FileFlushObj(f);
 Result := vNone;
End;

Function FileSeekM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 off, wh, np: Int64;
Begin
 f := SelfFile(a);
 off := IndexVal(a[1]);
 wh := 0;
 If n > 2 Then wh := IndexVal(a[2]);
 Case wh Of
  0: np := off;
  1: np := f.pos + off;
 Else np := Length(f.data) + off;
 End;
 If np < 0 Then ValueErr('negative seek position ' + IntToStr(np));
 f.pos := np;
 Result := VInt(np);
End;

Function FileTellM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(SelfFile(a).pos);
End;

Function FileTruncateM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
 sz: Int64;
Begin
 f := SelfFile(a);
 If (n > 1) And (a[1].k <> vkNone) Then sz := IndexVal(a[1]) Else sz := f.pos;
 f.data := Copy(f.data, 1, sz);
 f.dirty := True;
 Result := VInt(sz);
End;

Function FileReadableM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(SelfFile(a).readable);
End;

Function FileWritableM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(SelfFile(a).writable);
End;

Function FileSeekableM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(TPyFile(a[0].o).std = 0);
End;

Function FileIsattyM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
Begin
 f := TPyFile(a[0].o);
 Result := vFalse;
 {$IFDEF UNIX}
 If f.std = 1 Then Result := VBool(IsATTY(0) = 1)
 Else If f.std = 2 Then Result := VBool(IsATTY(1) = 1)
 Else If f.std = 3 Then Result := VBool(IsATTY(2) = 1);
 {$ENDIF}
End;

Function FileFilenoM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Case TPyFile(a[0].o).std Of
  1: Result := VInt(0);
  2: Result := VInt(1);
  3: Result := VInt(2);
 Else Result := VInt(3);
 End;
End;

Function FileEnterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfFile(a);
 Result := a[0];
End;

Function FileExitM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 FileCloseObj(TPyFile(a[0].o));
 Result := vFalse;
End;

Type
 TFileIter = Class(TPyIter)
  f: TPyFile;
  Function Next(Var r: TVal): Boolean; Override;
  Procedure MarkKids; Override;
 End;

Function TFileIter.Next(Var r: TVal): Boolean;
Var
 line: AnsiString;
Begin
 If f.closed Then ValueErr('I/O operation on closed file.');
 If FileReadLineImpl(f, line, -1) Then Begin
  r := FileOut(f, line);
  Result := True;
 End
 Else Result := False;
End;

Procedure TFileIter.MarkKids;
Begin
 Inherited MarkKids;
 MarkObj(f);
End;

Function ValIter(Const v: TVal): TVal;
Var
 it: TFileIter;
Begin
 it := TFileIter.Create(tyIter);
 it.f := TPyFile(v.o);
 Result := VObj(it);
End;

Function FileIterM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 SelfFile(a);
 Result := ValIter(a[0]);
End;

Function FileNextM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 line: AnsiString;
Begin
 If FileReadLineImpl(SelfFile(a), line, -1) Then
  Result := FileOut(TPyFile(a[0].o), line)
 Else RaiseStopIteration(vNone);
End;

Procedure InitFileType;
Begin
 DefMethod(tyFile, 'read', @FileReadM);
 DefMethod(tyFile, 'readline', @FileReadLineM);
 DefMethod(tyFile, 'readlines', @FileReadLinesM);
 DefMethod(tyFile, 'write', @FileWriteM);
 DefMethod(tyFile, 'writelines', @FileWriteLinesM);
 DefMethod(tyFile, 'close', @FileCloseM);
 DefMethod(tyFile, 'flush', @FileFlushM);
 DefMethod(tyFile, 'seek', @FileSeekM);
 DefMethod(tyFile, 'tell', @FileTellM);
 DefMethod(tyFile, 'truncate', @FileTruncateM);
 DefMethod(tyFile, 'readable', @FileReadableM);
 DefMethod(tyFile, 'writable', @FileWritableM);
 DefMethod(tyFile, 'seekable', @FileSeekableM);
 DefMethod(tyFile, 'isatty', @FileIsattyM);
 DefMethod(tyFile, 'fileno', @FileFilenoM);
 DefMethod(tyFile, '__enter__', @FileEnterM);
 DefMethod(tyFile, '__exit__', @FileExitM);
 DefMethod(tyFile, '__iter__', @FileIterM);
 DefMethod(tyFile, '__next__', @FileNextM);
 DefFunc(BuiltinsDict, 'open', @BiOpen);
End;

Function NewStdFile(std: Integer; Const mode: AnsiString): TPyFile;
Begin
 Result := TPyFile.Create(tyFile);
 Result.std := std;
 Result.mode := mode;
 Result.readable := std = 1;
 Result.writable := std <> 1;
 Result.closed := False;
End;

{ ------------------------------------------------------------
  Modules : registre, importation
  ------------------------------------------------------------ }
Type
 TModInit = Procedure(m: TPyModule);
 TModSrc = Function: AnsiString;

Var
 NativeMods: TStringList;
 SrcMods: TStringList;
 VerboseImport: Boolean;
 NoSite: Boolean;
 NoUserSite: Boolean;
 SysPathList: TPyList;
 ProgName: AnsiString;
 ScriptDir: AnsiString;

Function NewModule(Const name: AnsiString): TPyModule;
Begin
 Result := TPyModule.Create(tyModule);
 Result.name := name;
 Result.idict := TPyDict.Make;
 Result.idict.SetS('__name__', VStr(name));
 Result.idict.SetS('__doc__', vNone);
 Result.idict.SetS('__package__', VStr(''));
 Result.idict.SetS('__loader__', vNone);
 Result.idict.SetS('__spec__', vNone);
End;

Procedure RegNative(Const name: AnsiString; p: TModInit);
Begin
 NativeMods.AddObject(name, TObject(Pointer(p)));
End;

Procedure RegSource(Const name: AnsiString; p: TModSrc);
Begin
 SrcMods.AddObject(name, TObject(Pointer(p)));
End;

Function FindModuleIn(Const name: AnsiString; Var m: TVal): Boolean;
Begin
 Result := ModulesDict.GetS(name, m);
End;

Procedure ExecModuleSource(m: TPyModule; Const src, fname: AnsiString);
Var
 code: TPyCode;
Begin
 code := CompileSafe(src, fname, 0);
 RunCodeObject(code, m.idict, m.idict);
End;

Function JoinPath(Const a, b: AnsiString): AnsiString;
Begin
 If a = '' Then Result := b
 Else If (a[Length(a)] = '/') Or (a[Length(a)] = '\') Then Result := a + b
 Else Result := a + '/' + b;
End;

Function ImportByName(Const name: AnsiString): TVal; Forward;

Function LoadModuleFile(Const fullname, path: AnsiString; isPkg: Boolean;
 Const pkgdir: AnsiString): TVal;
Var
 m: TPyModule;
 src: AnsiString;
 mv: TVal;
Begin
 If Not ReadWholeFile(path, src) Then
  RaiseExc(exImportError, 'cannot read ' + path);
 m := NewModule(fullname);
 m.idict.SetS('__file__', VStr(path));
 If isPkg Then Begin
  m.idict.SetS('__path__', VObj(ListFromVals([VStr(pkgdir)])));
  m.idict.SetS('__package__', VStr(fullname));
 End
 Else If Pos('.', fullname) > 0 Then
  m.idict.SetS('__package__', VStr(Copy(fullname, 1, LastDelimiter('.',
   fullname) - 1)))
 Else m.idict.SetS('__package__', VStr(''));
 mv := VObj(m);
 ModulesDict.SetS(fullname, mv);
 Try
  ExecModuleSource(m, src, path);
 Except
  ModulesDict.DelS(fullname);
  Raise;
 End;
 Result := mv;
End;

Function SearchPath(Const fullname: AnsiString; Const dirs: TValArr;
 Var found: TVal): Boolean;
Var
 i: Integer;
 base, leaf, p: AnsiString;
Begin
 Result := False;
 If Pos('.', fullname) > 0 Then leaf := Copy(fullname, LastDelimiter('.',
  fullname) + 1, Length(fullname))
 Else leaf := fullname;
 For i := 0 To High(dirs) Do Begin
  If Not IsStrVal(dirs[i]) Then Continue;
  base := TPyStr(dirs[i].o).s;
  If base = '' Then base := '.';
  p := JoinPath(JoinPath(base, leaf), '__init__.py');
  If FileExists(p) Then Begin
   found := LoadModuleFile(fullname, p, True, JoinPath(base, leaf));
   Result := True;
   Exit;
  End;
  p := JoinPath(base, leaf + '.py');
  If FileExists(p) Then Begin
   found := LoadModuleFile(fullname, p, False, '');
   Result := True;
   Exit;
  End;
 End;
End;

Function ImportByName(Const name: AnsiString): TVal;
Var
 m, parent, pathv: TVal;
 idx: Integer;
 pname, leaf: AnsiString;
 nm: TPyModule;
 src: AnsiString;
 dirs: TValArr;
 e: TPyObj;
Begin
 If FindModuleIn(name, m) Then Begin
  Result := m;
  Exit;
 End;
 If name = '' Then ValueErr('Empty module name');
 idx := LastDelimiter('.', name);
 parent := vNone;
 If idx > 0 Then Begin
  pname := Copy(name, 1, idx - 1);
  leaf := Copy(name, idx + 1, Length(name));
  parent := ImportByName(pname);
  If FindModuleIn(name, m) Then Begin
   Result := m;
   Exit;
  End;
  If Not GetAttrOpt(parent, InternStr('__path__'), pathv) Then Begin
   e := MakeExc(exModuleNotFound, 'No module named ''' + name + '''; ''' +
    pname + ''' is not a package');
   e.idict.SetS('name', VStr(name));
   Raise EPyError.Make(e);
  End;
  dirs := IterToArr(pathv);
 End
 Else Begin
  leaf := name;
  dirs := IterToArr(VObj(SysPathList));
 End;
 { modules natifs }
 idx := NativeMods.IndexOf(name);
 If idx >= 0 Then Begin
  nm := NewModule(name);
  nm.idict.SetS('__loader__', VStr('builtin'));
  m := VObj(nm);
  ModulesDict.SetS(name, m);
  Try
   TModInit(Pointer(NativeMods.Objects[idx]))(nm);
  Except
   ModulesDict.DelS(name);
   Raise;
  End;
  If parent.k = vkObj Then SetAttr(parent, leaf, m);
  Result := m;
  Exit;
 End;
 { modules en Python integres }
 idx := SrcMods.IndexOf(name);
 If idx >= 0 Then Begin
  src := TModSrc(Pointer(SrcMods.Objects[idx]))();
  nm := NewModule(name);
  nm.idict.SetS('__file__', VStr('<frozen ' + name + '>'));
  If (Pos('.', name) = 0) Then nm.idict.SetS('__package__', VStr(''))
  Else nm.idict.SetS('__package__', VStr(Copy(name, 1, LastDelimiter('.',
   name) - 1)));
  If Pos('#PACKAGE', Copy(src, 1, 12)) = 1 Then Begin
   nm.idict.SetS('__path__', VObj(ListFromVals([])));
   nm.idict.SetS('__package__', VStr(name));
  End;
  m := VObj(nm);
  ModulesDict.SetS(name, m);
  Try
   ExecModuleSource(nm, src, '<frozen ' + name + '>');
  Except
   ModulesDict.DelS(name);
   Raise;
  End;
  If parent.k = vkObj Then SetAttr(parent, leaf, m);
  Result := m;
  Exit;
 End;
 If SearchPath(name, dirs, m) Then Begin
  If parent.k = vkObj Then SetAttr(parent, leaf, m);
  Result := m;
  Exit;
 End;
 e := MakeExc(exModuleNotFound, 'No module named ''' + name + '''');
 e.idict.SetS('name', VStr(name));
 Raise EPyError.Make(e);
End;

Function ResolveRelative(Const name: AnsiString; globals: TPyDict;
 level: Integer): AnsiString;
Var
 pkg, mn: TVal;
 base: AnsiString;
 i, p: Integer;
Begin
 If globals = Nil Then
  RaiseExc(exImportError, 'attempted relative import with no known parent ' +
   'package');
 base := '';
 If globals.GetS('__package__', pkg) And IsStrVal(pkg) And
  (TPyStr(pkg.o).s <> '') Then base := TPyStr(pkg.o).s
 Else If globals.GetS('__name__', mn) And IsStrVal(mn) Then Begin
  If globals.HasS('__path__') Then base := TPyStr(mn.o).s
  Else Begin
   p := LastDelimiter('.', TPyStr(mn.o).s);
   If p > 0 Then base := Copy(TPyStr(mn.o).s, 1, p - 1);
  End;
 End;
 If base = '' Then
  RaiseExc(exImportError, 'attempted relative import with no known parent ' +
   'package');
 For i := 2 To level Do Begin
  p := LastDelimiter('.', base);
  If p = 0 Then
   RaiseExc(exImportError, 'attempted relative import beyond top-level ' +
    'package');
  base := Copy(base, 1, p - 1);
 End;
 If name = '' Then Result := base Else Result := base + '.' + name;
End;

Function ImportName(Const name: AnsiString; globals: TPyDict;
 Const fromlist: TVal; level: Integer): TVal;
Var
 full, top: AnsiString;
 m: TVal;
 p: Integer;
Begin
 If level > 0 Then full := ResolveRelative(name, globals, level)
 Else full := name;
 m := ImportByName(full);
 If (fromlist.k <> vkNone) And IsTrue(fromlist) Then Begin
  Result := m;
  Exit;
 End;
 If level > 0 Then Begin
  Result := m;
  Exit;
 End;
 p := Pos('.', full);
 If p > 0 Then Begin
  top := Copy(full, 1, p - 1);
  Result := ImportByName(top);
 End
 Else Result := m;
End;

Function ImportFromName(Const m: TVal; Const name: AnsiString): TVal;
Var
 r, pn: TVal;
 e: TPyObj;
 mname: AnsiString;
Begin
 If GetAttrOpt(m, InternStr(name), r) Then Begin
  Result := r;
  Exit;
 End;
 mname := '?';
 If GetAttrOpt(m, InternStr('__name__'), pn) And IsStrVal(pn) Then
  mname := TPyStr(pn.o).s;
 If HasAttr(m, '__path__') Then Begin
  Try
   Result := ImportByName(mname + '.' + name);
   Exit;
  Except
   On E1: EPyError Do Begin
    If Not IsInstance(VObj(E1.exc), exModuleNotFound) Then Raise;
   End;
  End;
 End;
 e := MakeExc(exImportError, 'cannot import name ''' + name + ''' from ''' +
  mname + ''' (unknown location)');
 e.idict.SetS('name', VStr(mname));
 Raise EPyError.Make(e);
End;

Procedure ImportStar(Const m: TVal; target: TPyDict);
Var
 allv, k, v: TVal;
 arr: TValArr;
 i: Integer;
 d: TPyDict;
Begin
 If GetAttrOpt(m, InternStr('__all__'), allv) Then Begin
  arr := IterToArr(allv);
  For i := 0 To High(arr) Do
   target.SetItem(arr[i], GetAttr(m, StrOf(arr[i])));
  Exit;
 End;
 d := m.o.idict;
 For i := 0 To d.nent - 1 Do
  If d.ent[i].key.k <> vkNull Then Begin
   k := d.ent[i].key;
   v := d.ent[i].val;
   If IsStrVal(k) And (Length(TPyStr(k.o).s) > 0) And
    (TPyStr(k.o).s[1] <> '_') Then target.SetItem(k, v);
  End;
End;

Function BiImport(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 lvl: Integer;
 g: TPyDict;
 fl: TVal;
Begin
 NeedArgs(n, 1, 5, '__import__()');
 lvl := 0;
 g := Nil;
 fl := vNone;
 If (n > 1) And (a[1].k = vkObj) And (a[1].o Is TPyDict) Then
  g := TPyDict(a[1].o);
 If n > 3 Then fl := a[3];
 If n > 4 Then lvl := IndexVal(a[4]);
 Result := ImportName(StrOf(a[0]), g, fl, lvl);
End;

Procedure DisplayHook(Const v: TVal);
Var
 hook: TVal;
Begin
 If SysDict.GetS('displayhook', hook) And (hook.k = vkObj) And
  Not (hook.o Is TPyBuiltin) Then Begin
  Call1(hook, v);
  Exit;
 End;
 If v.k = vkNone Then Exit;
 BuiltinsDict.SetS('_', vNone);
 PyWriteTo(vNone, ReprVal(v) + #10);
 BuiltinsDict.SetS('_', v);
End;

Function SysDisplayHook(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 DisplayHook(a[0]);
 Result := vNone;
End;

{ ------------------------------------------------------------
  Module sys
  ------------------------------------------------------------ }
Function SysGetRecLimit(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(RecursionLimit);
End;

Function SysSetRecLimit(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 v: Int64;
Begin
 v := IndexVal(a[0]);
 If v < 1 Then ValueErr('recursion limit must be greater or equal than 1');
 If v > 1000000 Then v := 1000000;
 RecursionLimit := v;
 Result := vNone;
End;

Function SysExcInfo(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyTuple;
Begin
 t := NewTuple(3);
 If ExcInfo.k = vkObj Then Begin
  t.items[0] := VObj(ExcInfo.o.cls);
  t.items[1] := ExcInfo;
  t.items[2] := vNone;
 End
 Else Begin
  t.items[0] := vNone;
  t.items[1] := vNone;
  t.items[2] := vNone;
 End;
 Result := VObj(t);
End;

Function SysGetSizeOf(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If a[0].k = vkObj Then Begin
  If a[0].o Is TPyStr Then Result := VInt(49 + Length(TPyStr(a[0].o).s))
  Else If a[0].o Is TPyList Then Result := VInt(64 + 8 * TPyList(a[0].o).cnt)
  Else If a[0].o Is TPyTuple Then
   Result := VInt(48 + 8 * Length(TPyTuple(a[0].o).items))
  Else If a[0].o Is TPyDict Then Result := VInt(232 + 24 * TPyDict(a[0].o).used)
  Else Result := VInt(56);
 End
 Else If a[0].k = vkFloat Then Result := VInt(24)
 Else Result := VInt(28);
End;

Function SysIntern(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(InternStr(StrOf(a[0])));
End;

Function SysNoop(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := vNone;
End;

Function SysExceptHook(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If (n > 1) And (a[1].k = vkObj) Then PyRunTraceback(a[1].o);
 Result := vNone;
End;

Function SysGetDefEnc(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr('utf-8');
End;

Function SysGetRefCount(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(2);
End;

Function SysGetFrame(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(CurFrame.func);
 If CurFrame.func = Nil Then Result := vNone;
End;

Procedure InitSysModule(m: TPyModule);
Var
 d: TPyDict;
 mv: TVal;
Begin
 d := m.idict;
 d.SetS('modules', VObj(ModulesDict));
 d.SetS('path', VObj(SysPathList));
 d.SetS('stdin', VObj(StdinObj));
 d.SetS('stdout', VObj(StdoutObj));
 d.SetS('stderr', VObj(StderrObj));
 d.SetS('__stdin__', VObj(StdinObj));
 d.SetS('__stdout__', VObj(StdoutObj));
 d.SetS('__stderr__', VObj(StderrObj));
 d.SetS('version', VStr(PY_VERSION + ' ' + PY_BUILD + ' ' + PY_COMPILER));
 d.SetS('hexversion', VInt(PY_HEXVERSION));
 d.SetS('api_version', VInt(1013));
 d.SetS('maxsize', VInt(High(Int64)));
 d.SetS('maxunicode', VInt($10FFFF));
 d.SetS('byteorder', VStr('little'));
 d.SetS('copyright', VStr('Copyright (c) 2026 Sylvain Maltais. Compatible ' +
  'avec Python ' + PY_VERSION));
 {$IFDEF UNIX}
 d.SetS('platform', VStr('linux'));
 {$ELSE}
 d.SetS('platform', VStr('win32'));
 {$ENDIF}
 d.SetS('prefix', VStr('/usr'));
 d.SetS('exec_prefix', VStr('/usr'));
 d.SetS('base_prefix', VStr('/usr'));
 d.SetS('base_exec_prefix', VStr('/usr'));
 d.SetS('dont_write_bytecode', vTrue);
 d.SetS('builtin_module_names', VObj(NewTuple(0)));
 d.SetS('warnoptions', VObj(NewList));
 d.SetS('_xoptions', VObj(TPyDict.Make));
 d.SetS('meta_path', VObj(NewList));
 d.SetS('path_hooks', VObj(NewList));
 d.SetS('path_importer_cache', VObj(TPyDict.Make));
 d.SetS('last_value', vNone);
 DefFunc(d, 'exit', @BiExit);
 DefFunc(d, 'getrecursionlimit', @SysGetRecLimit);
 DefFunc(d, 'setrecursionlimit', @SysSetRecLimit);
 DefFunc(d, 'exc_info', @SysExcInfo);
 DefFunc(d, 'getsizeof', @SysGetSizeOf);
 DefFunc(d, 'intern', @SysIntern);
 DefFunc(d, 'settrace', @SysNoop);
 DefFunc(d, 'setprofile', @SysNoop);
 DefFunc(d, 'gettrace', @SysNoop);
 DefFunc(d, 'getprofile', @SysNoop);
 DefFunc(d, 'displayhook', @SysDisplayHook);
 DefFunc(d, 'excepthook', @SysExceptHook);
 DefFunc(d, 'getdefaultencoding', @SysGetDefEnc);
 DefFunc(d, 'getfilesystemencoding', @SysGetDefEnc);
 DefFunc(d, 'getrefcount', @SysGetRefCount);
 DefFunc(d, '_getframe', @SysGetFrame);
 DefFunc(d, 'setswitchinterval', @SysNoop);
 If d.GetS('displayhook', mv) Then d.SetS('__displayhook__', mv);
End;

{ ------------------------------------------------------------
  Module math
  ------------------------------------------------------------ }
Function MathArg(a: PVal; i, n: Integer; Const fname: AnsiString): Double;
Begin
 If i >= n Then TypeErr(fname + '() takes exactly one argument (' +
  IntToStr(n) + ' given)');
 If IsNumVal(a[i]) Then Result := NumToDouble(a[i])
 Else Begin
  If (a[i].k = vkObj) And HasAttr(a[i], '__float__') Then
   Result := ToFloatVal(a[i])
  Else Begin
   TypeErr('must be real number, not ' + TypeName(a[i]));
   Result := 0;
  End;
 End;
End;

Procedure MathDomain;
Begin
 ValueErr('math domain error');
End;

Function CheckFloat(x: Double; Const orig: Double): TVal;
Begin
 If IsNan(x) And Not IsNan(orig) Then MathDomain;
 If IsInfinite(x) And Not IsInfinite(orig) Then
  RaiseExc(exOverflow, 'math range error');
 Result := VFloat(x);
End;

Function MSqrt(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'sqrt');
 If x < 0 Then MathDomain;
 Result := VFloat(Sqrt(x));
End;

Function MSin(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'sin');
 If IsInfinite(x) Then MathDomain;
 Result := VFloat(Sin(x));
End;

Function MCos(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'cos');
 If IsInfinite(x) Then MathDomain;
 Result := VFloat(Cos(x));
End;

Function MTan(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'tan');
 If IsInfinite(x) Then MathDomain;
 Result := VFloat(Tan(x));
End;

Function MAsin(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'asin');
 If (x < -1) Or (x > 1) Then MathDomain;
 Result := VFloat(ArcSin(x));
End;

Function MAcos(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'acos');
 If (x < -1) Or (x > 1) Then MathDomain;
 Result := VFloat(ArcCos(x));
End;

Function MAtan(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(ArcTan(MathArg(a, 0, n, 'atan')));
End;

Function MAtan2(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(ArcTan2(MathArg(a, 0, n, 'atan2'), MathArg(a, 1, n,
  'atan2')));
End;

Function MSinh(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'sinh');
 Result := CheckFloat(SinH(x), x);
End;

Function MCosh(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'cosh');
 Result := CheckFloat(CosH(x), x);
End;

Function MTanh(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(TanH(MathArg(a, 0, n, 'tanh')));
End;

Function MAsinh(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(ArcSinH(MathArg(a, 0, n, 'asinh')));
End;

Function MAcosh(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'acosh');
 If x < 1 Then MathDomain;
 Result := VFloat(ArcCosH(x));
End;

Function MAtanh(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'atanh');
 If (x <= -1) Or (x >= 1) Then MathDomain;
 Result := VFloat(ArcTanH(x));
End;

Function MExp(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'exp');
 Result := CheckFloat(Exp(x), x);
End;

Function MExpm1(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'expm1');
 If Abs(x) < 1e-5 Then Result := VFloat(x + x * x / 2 + x * x * x / 6)
 Else Result := CheckFloat(Exp(x) - 1, x);
End;

Function LogOf(Const v: TVal; Const fname: AnsiString): Double;
Var
 bl: Int64;
 sh: TVal;
 x: Double;
Begin
 If (v.k = vkObj) And (v.o Is TPyBigInt) And Not TPyBigInt(v.o).neg Then Begin
  bl := IntBitLength(v);
  If bl > 1000 Then Begin
   sh := IntShr(v, bl - 60);
   Result := Ln(IntToDouble(sh)) + (bl - 60) * Ln(2);
   Exit;
  End;
 End;
 x := NumToDouble(v);
 If x <= 0 Then MathDomain;
 Result := Ln(x);
End;

Function MLog(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r, b: Double;
Begin
 NeedArgs(n, 1, 2, 'log');
 If Not IsNumVal(a[0]) Then
  TypeErr('must be real number, not ' + TypeName(a[0]));
 r := LogOf(a[0], 'log');
 If n = 2 Then Begin
  b := LogOf(a[1], 'log');
  If b = 0 Then RaiseExc(exZeroDivision, 'float division by zero');
  r := r / b;
 End;
 Result := VFloat(r);
End;

Function MLog2(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 If Not IsNumVal(a[0]) Then
  TypeErr('must be real number, not ' + TypeName(a[0]));
 Result := VFloat(LogOf(a[0], 'log2') / Ln(2));
 If (a[0].k = vkInt) And (a[0].i > 0) And ((a[0].i And (a[0].i - 1)) = 0) Then
  Result := VFloat(IntBitLength(a[0]) - 1);
End;

Function MLog10(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: Double;
Begin
 If Not IsNumVal(a[0]) Then
  TypeErr('must be real number, not ' + TypeName(a[0]));
 r := LogOf(a[0], 'log10') / Ln(10);
 If (a[0].k = vkInt) And (a[0].i > 0) Then
  If Abs(r - Round(r)) < 1e-12 Then
   If IntPow(VInt(10), VInt(Round(r))).i = a[0].i Then r := Round(r);
 Result := VFloat(r);
End;

Function MLog1p(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'log1p');
 If x <= -1 Then MathDomain;
 If Abs(x) < 1e-5 Then Result := VFloat(x - x * x / 2 + x * x * x / 3)
 Else Result := VFloat(Ln(1 + x));
End;

Function MPow(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, y, r: Double;
Begin
 x := MathArg(a, 0, n, 'pow');
 y := MathArg(a, 1, n, 'pow');
 If (x = 0) And (y < 0) Then MathDomain;
 If (x < 0) And (Frac(y) <> 0) And Not IsInfinite(y) Then MathDomain;
 r := Power(x, y);
 If IsInfinite(r) And Not IsInfinite(x) And Not IsInfinite(y) Then
  RaiseExc(exOverflow, 'math range error');
 Result := VFloat(r);
End;

Function MFabs(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(Abs(MathArg(a, 0, n, 'fabs')));
End;

Function MFloor(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TVal;
Begin
 If IsIntVal(a[0]) Then Begin
  If a[0].k = vkBool Then Result := VInt(a[0].i) Else Result := a[0];
  Exit;
 End;
 If (a[0].k = vkObj) And LookupType(a[0].o.cls, '__floor__', f) Then Begin
  Result := Call1(f, a[0]);
  Exit;
 End;
 Result := DoubleToInt(Floor(MathArg(a, 0, n, 'floor')));
End;

Function MCeil(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TVal;
Begin
 If IsIntVal(a[0]) Then Begin
  If a[0].k = vkBool Then Result := VInt(a[0].i) Else Result := a[0];
  Exit;
 End;
 If (a[0].k = vkObj) And LookupType(a[0].o.cls, '__ceil__', f) Then Begin
  Result := Call1(f, a[0]);
  Exit;
 End;
 Result := DoubleToInt(Ceil(MathArg(a, 0, n, 'ceil')));
End;

Function MTrunc(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TVal;
Begin
 If IsIntVal(a[0]) Then Begin
  Result := a[0];
  If a[0].k = vkBool Then Result := VInt(a[0].i);
  Exit;
 End;
 If (a[0].k = vkObj) And LookupType(a[0].o.cls, '__trunc__', f) Then Begin
  Result := Call1(f, a[0]);
  Exit;
 End;
 Result := DoubleToInt(Int(MathArg(a, 0, n, 'trunc')));
End;

Function MFmod(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, y: Double;
Begin
 x := MathArg(a, 0, n, 'fmod');
 y := MathArg(a, 1, n, 'fmod');
 If (y = 0) Or IsInfinite(x) Then MathDomain;
 Result := VFloat(FMod(x, y));
End;

Function MModf(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, i: Double;
Begin
 x := MathArg(a, 0, n, 'modf');
 If IsInfinite(x) Then Begin
  Result := Tup2(VFloat(0), VFloat(x));
  Exit;
 End;
 i := Int(x);
 Result := Tup2(VFloat(x - i), VFloat(i));
End;

Function MFrexp(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
 m: Extended;
 e: Integer;
Begin
 x := MathArg(a, 0, n, 'frexp');
 If (x = 0) Or IsNan(x) Or IsInfinite(x) Then Begin
  Result := Tup2(VFloat(x), VInt(0));
  Exit;
 End;
 Frexp(x, m, e);
 Result := Tup2(VFloat(m), VInt(e));
End;

Function MLdexp(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
 r: Double;
Begin
 x := MathArg(a, 0, n, 'ldexp');
 r := Ldexp(x, IndexVal(a[1]));
 Result := CheckFloat(r, x);
End;

Function MHypot(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: Double;
 i: Integer;
 x: Double;
Begin
 s := 0;
 For i := 0 To n - 1 Do Begin
  x := MathArg(a, i, n, 'hypot');
  s := s + x * x;
 End;
 Result := VFloat(Sqrt(s));
End;

Function MDegrees(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(MathArg(a, 0, n, 'degrees') * 180.0 / Pi);
End;

Function MRadians(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(MathArg(a, 0, n, 'radians') * Pi / 180.0);
End;

Function MCopysign(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, y: Double;
Begin
 x := Abs(MathArg(a, 0, n, 'copysign'));
 y := MathArg(a, 1, n, 'copysign');
 If FloatSignBit(y) Then x := -x;
 Result := VFloat(x);
End;

Function MIsNan(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(IsNan(MathArg(a, 0, n, 'isnan')));
End;

Function MIsInf(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(IsInfinite(MathArg(a, 0, n, 'isinf')));
End;

Function MIsFinite(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'isfinite');
 Result := VBool(Not IsNan(x) And Not IsInfinite(x));
End;

Function MIsClose(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, y, rt, at, d: Double;
 v: TVal;
Begin
 x := MathArg(a, 0, n, 'isclose');
 y := MathArg(a, 1, n, 'isclose');
 rt := 1e-9;
 at := 0;
 If KwGet(kw, 'rel_tol', v) Then rt := NumToDouble(v);
 If KwGet(kw, 'abs_tol', v) Then at := NumToDouble(v);
 If x = y Then Begin
  Result := vTrue;
  Exit;
 End;
 If IsInfinite(x) Or IsInfinite(y) Then Begin
  Result := vFalse;
  Exit;
 End;
 d := Abs(y - x);
 Result := VBool((d <= Abs(rt * y)) Or (d <= Abs(rt * x)) Or (d <= at));
End;

Function IntGcd(Const a, b: TVal): TVal;
Var
 x, y, t: TVal;
Begin
 x := a;
 y := b;
 If IntSign(x) < 0 Then x := IntNeg(x);
 If IntSign(y) < 0 Then y := IntNeg(y);
 While IntSign(y) <> 0 Do Begin
  t := IntMod(x, y);
  x := y;
  y := t;
 End;
 Result := x;
End;

Function MGcd(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
 r: TVal;
Begin
 r := VInt(0);
 For i := 0 To n - 1 Do Begin
  If Not IsIntVal(a[i]) Then
   TypeErr('''' + TypeName(a[i]) + ''' object cannot be interpreted as an ' +
    'integer');
  r := IntGcd(r, a[i]);
 End;
 Result := r;
End;

Function MLcm(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
 r, g: TVal;
Begin
 r := VInt(1);
 For i := 0 To n - 1 Do Begin
  If IntSign(a[i]) = 0 Then Begin
   Result := VInt(0);
   Exit;
  End;
  g := IntGcd(r, a[i]);
  r := IntFloorDiv(IntMul(r, a[i]), g);
  If IntSign(r) < 0 Then r := IntNeg(r);
 End;
 Result := r;
End;

Function MFactorial(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i, k: Int64;
 r: TVal;
Begin
 If a[0].k = vkFloat Then
  TypeErr('''float'' object cannot be interpreted as an integer');
 k := IndexVal(a[0]);
 If k < 0 Then ValueErr('factorial() not defined for negative values');
 r := VInt(1);
 For i := 2 To k Do r := IntMul(r, VInt(i));
 Result := r;
End;

Function MComb(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 nn, k, i: Int64;
 r: TVal;
Begin
 nn := IndexVal(a[0]);
 k := IndexVal(a[1]);
 If (nn < 0) Or (k < 0) Then ValueErr('n must be a non-negative integer');
 If k > nn Then Begin
  Result := VInt(0);
  Exit;
 End;
 If k > nn - k Then k := nn - k;
 r := VInt(1);
 For i := 1 To k Do
  r := IntFloorDiv(IntMul(r, VInt(nn - k + i)), VInt(i));
 Result := r;
End;

Function MPerm(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 nn, k, i: Int64;
 r: TVal;
Begin
 nn := IndexVal(a[0]);
 If (n > 1) And (a[1].k <> vkNone) Then k := IndexVal(a[1]) Else k := nn;
 If (nn < 0) Or (k < 0) Then ValueErr('n must be a non-negative integer');
 If k > nn Then Begin
  Result := VInt(0);
  Exit;
 End;
 r := VInt(1);
 For i := 0 To k - 1 Do r := IntMul(r, VInt(nn - i));
 Result := r;
End;

Function MIsqrt(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, r, nr, t: TVal;
Begin
 x := a[0];
 If Not IsIntVal(x) Then
  TypeErr('''' + TypeName(x) + ''' object cannot be interpreted as an ' +
   'integer');
 If IntSign(x) < 0 Then ValueErr('isqrt() argument must be nonnegative');
 If IntSign(x) = 0 Then Begin
  Result := VInt(0);
  Exit;
 End;
 r := IntShl(VInt(1), (IntBitLength(x) + 1) Div 2);
 While True Do Begin
  t := IntFloorDiv(x, r);
  nr := IntShr(IntAdd(r, t), 1);
  If IntCmp(nr, r) >= 0 Then Break;
  r := nr;
 End;
 Result := r;
End;

Function MFsum(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 partials: Array Of Double;
 np, i, j: Integer;
 x, y, hi, lo, s: Double;
Begin
 arr := IterToArr(a[0]);
 SetLength(partials, 0);
 np := 0;
 For i := 0 To High(arr) Do Begin
  x := NumToDouble(arr[i]);
  j := 0;
  For np := 0 To High(partials) Do Begin
   y := partials[np];
   If Abs(x) < Abs(y) Then Begin
    s := x;
    x := y;
    y := s;
   End;
   hi := x + y;
   lo := y - (hi - x);
   If lo <> 0 Then Begin
    partials[j] := lo;
    Inc(j);
   End;
   x := hi;
  End;
  SetLength(partials, j + 1);
  partials[j] := x;
 End;
 s := 0;
 For i := High(partials) DownTo 0 Do s := s + partials[i];
 Result := VFloat(s);
End;

Function MProd(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 it, x, r, st: TVal;
Begin
 r := VInt(1);
 If KwGet(kw, 'start', st) Then r := st;
 it := IterOf(a[0]);
 While IterNextVal(it, x) Do r := BinaryOp(bopMul, r, x);
 Result := r;
End;

Function MGamma(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
 i: Integer;
 r: Double;
Begin
 x := MathArg(a, 0, n, 'gamma');
 If (Frac(x) = 0) And (x <= 0) Then MathDomain;
 If (Frac(x) = 0) And (x < 171) Then Begin
  r := 1;
  For i := 2 To Trunc(x) - 1 Do r := r * i;
  Result := VFloat(r);
  Exit;
 End;
 { Lanczos }
 Result := VFloat(Exp(Ln(Abs(2.5066282746310002 * (1.000000000190015 +
  76.18009172947146 / (x + 1) - 86.50532032941677 / (x + 2) +
  24.01409824083091 / (x + 3) - 1.231739572450155 / (x + 4) +
  0.001208650973866179 / (x + 5) - 0.000005395239384953 / (x + 6)) /
  x)) + (x + 0.5) * Ln(x + 5.5) - (x + 5.5)));
End;

Function MLgamma(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'lgamma');
 Result := VFloat(Ln(Abs(MGamma(a, n, kw).d)));
End;

Function MErf(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, t, y: Double;
Begin
 x := MathArg(a, 0, n, 'erf');
 t := 1 / (1 + 0.3275911 * Abs(x));
 y := 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
  0.284496736) * t + 0.254829592) * t * Exp(-x * x);
 If x < 0 Then y := -y;
 Result := VFloat(y);
End;

Function MErfc(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(1 - MErf(a, n, kw).d);
End;

Function MDist(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p, q: TValArr;
 i: Integer;
 s, d: Double;
Begin
 p := IterToArr(a[0]);
 q := IterToArr(a[1]);
 If Length(p) <> Length(q) Then
  ValueErr('both points must have the same number of dimensions');
 s := 0;
 For i := 0 To High(p) Do Begin
  d := NumToDouble(p[i]) - NumToDouble(q[i]);
  s := s + d * d;
 End;
 Result := VFloat(Sqrt(s));
End;

Function MRemainder(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x, y, r: Double;
Begin
 x := MathArg(a, 0, n, 'remainder');
 y := MathArg(a, 1, n, 'remainder');
 If y = 0 Then MathDomain;
 r := x - y * Round(x / y);
 Result := VFloat(r);
End;

Procedure InitMathModule(m: TPyModule);
Var
 d: TPyDict;
Begin
 d := m.idict;
 d.SetS('pi', VFloat(Pi));
 d.SetS('e', VFloat(Exp(1)));
 d.SetS('tau', VFloat(2 * Pi));
 d.SetS('inf', VFloat(Infinity));
 d.SetS('nan', VFloat(NaN));
 DefFunc(d, 'sqrt', @MSqrt);
 DefFunc(d, 'sin', @MSin);
 DefFunc(d, 'cos', @MCos);
 DefFunc(d, 'tan', @MTan);
 DefFunc(d, 'asin', @MAsin);
 DefFunc(d, 'acos', @MAcos);
 DefFunc(d, 'atan', @MAtan);
 DefFunc(d, 'atan2', @MAtan2);
 DefFunc(d, 'sinh', @MSinh);
 DefFunc(d, 'cosh', @MCosh);
 DefFunc(d, 'tanh', @MTanh);
 DefFunc(d, 'asinh', @MAsinh);
 DefFunc(d, 'acosh', @MAcosh);
 DefFunc(d, 'atanh', @MAtanh);
 DefFunc(d, 'exp', @MExp);
 DefFunc(d, 'expm1', @MExpm1);
 DefFunc(d, 'log', @MLog);
 DefFunc(d, 'log2', @MLog2);
 DefFunc(d, 'log10', @MLog10);
 DefFunc(d, 'log1p', @MLog1p);
 DefFunc(d, 'pow', @MPow);
 DefFunc(d, 'fabs', @MFabs);
 DefFunc(d, 'floor', @MFloor);
 DefFunc(d, 'ceil', @MCeil);
 DefFunc(d, 'trunc', @MTrunc);
 DefFunc(d, 'fmod', @MFmod);
 DefFunc(d, 'modf', @MModf);
 DefFunc(d, 'frexp', @MFrexp);
 DefFunc(d, 'ldexp', @MLdexp);
 DefFunc(d, 'hypot', @MHypot);
 DefFunc(d, 'degrees', @MDegrees);
 DefFunc(d, 'radians', @MRadians);
 DefFunc(d, 'copysign', @MCopysign);
 DefFunc(d, 'isnan', @MIsNan);
 DefFunc(d, 'isinf', @MIsInf);
 DefFunc(d, 'isfinite', @MIsFinite);
 DefFunc(d, 'isclose', @MIsClose);
 DefFunc(d, 'gcd', @MGcd);
 DefFunc(d, 'lcm', @MLcm);
 DefFunc(d, 'factorial', @MFactorial);
 DefFunc(d, 'comb', @MComb);
 DefFunc(d, 'perm', @MPerm);
 DefFunc(d, 'isqrt', @MIsqrt);
 DefFunc(d, 'fsum', @MFsum);
 DefFunc(d, 'prod', @MProd);
 DefFunc(d, 'gamma', @MGamma);
 DefFunc(d, 'lgamma', @MLgamma);
 DefFunc(d, 'erf', @MErf);
 DefFunc(d, 'erfc', @MErfc);
 DefFunc(d, 'dist', @MDist);
 DefFunc(d, 'remainder', @MRemainder);
End;

{ ------------------------------------------------------------
  Module time
  ------------------------------------------------------------ }
Function NowSeconds: Double;
{$IFDEF UNIX}
Var
 tv: TTimeVal;
{$ENDIF}
Begin
 {$IFDEF UNIX}
 fpgettimeofday(@tv, Nil);
 Result := tv.tv_sec + tv.tv_usec / 1000000.0;
 {$ELSE}
 Result := (Now - EncodeDate(1970, 1, 1)) * 86400.0;
 {$ENDIF}
End;

Function TimeTime(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(NowSeconds);
End;

Function TimeTimeNs(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(Round(NowSeconds * 1.0e9));
End;

Function TimeSleep(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 x: Double;
Begin
 x := MathArg(a, 0, n, 'sleep');
 If x < 0 Then ValueErr('sleep length must be non-negative');
 OutFlush;
 Sleep(Round(x * 1000));
 Result := vNone;
End;

Var
 StartTick: Double;

Function TimePerf(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(GetTickCount64 / 1000.0);
End;

Function TimePerfNs(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(GetTickCount64 * 1000000);
End;

Function TimeProcess(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VFloat(NowSeconds - StartTick);
End;

Function TimeStructArr(t: Double; local: Boolean): TVal;
Var
 dt: TDateTime;
 y, mo, d, h, mi, s, ms: Word;
 wd, yd: Integer;
 tp: TPyTuple;
Begin
 dt := EncodeDate(1970, 1, 1) + t / 86400.0;
 If local Then Begin
  {$IFDEF UNIX}
  dt := dt + (-GetLocalTimeOffset * 60) / 86400.0;
  {$ENDIF}
 End;
 DecodeDate(dt, y, mo, d);
 DecodeTime(dt, h, mi, s, ms);
 wd := DayOfWeek(dt) - 2;
 If wd < 0 Then wd := 6;
 yd := Trunc(dt) - Trunc(EncodeDate(y, 1, 1)) + 1;
 tp := NewTuple(9);
 tp.items[0] := VInt(y);
 tp.items[1] := VInt(mo);
 tp.items[2] := VInt(d);
 tp.items[3] := VInt(h);
 tp.items[4] := VInt(mi);
 tp.items[5] := VInt(s);
 tp.items[6] := VInt(wd);
 tp.items[7] := VInt(yd);
 tp.items[8] := VInt(0);
 Result := VObj(tp);
End;

Function TimeGmtime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: Double;
Begin
 If (n > 0) And (a[0].k <> vkNone) Then t := NumToDouble(a[0])
 Else t := NowSeconds;
 Result := TimeStructArr(Floor(t), False);
End;

Function TimeLocaltime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: Double;
Begin
 If (n > 0) And (a[0].k <> vkNone) Then t := NumToDouble(a[0])
 Else t := NowSeconds;
 Result := TimeStructArr(Floor(t), True);
End;

Function TimeMktime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 arr: TValArr;
 dt: TDateTime;
Begin
 arr := IterToArr(a[0]);
 dt := EncodeDate(arr[0].i, arr[1].i, arr[2].i) + EncodeTime(arr[3].i,
  arr[4].i, arr[5].i, 0);
 Result := VFloat((dt - EncodeDate(1970, 1, 1)) * 86400.0
  {$IFDEF UNIX} - (-GetLocalTimeOffset * 60) {$ENDIF});
End;

Function TimeStrftime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 fmt, r: AnsiString;
 arr: TValArr;
 i: Integer;
 y, mo, d, h, mi, s, wd, yd: Integer;
 c: Char;
Const
 Days: Array[0..6] Of String = ('Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday');
 Months: Array[1..12] Of String = ('January', 'February', 'March', 'April',
  'May', 'June', 'July', 'August', 'September', 'October', 'November',
  'December');
Begin
 fmt := StrOf(a[0]);
 If n > 1 Then arr := IterToArr(a[1])
 Else arr := IterToArr(TimeStructArr(Floor(NowSeconds), True));
 y := arr[0].i;
 mo := arr[1].i;
 d := arr[2].i;
 h := arr[3].i;
 mi := arr[4].i;
 s := arr[5].i;
 wd := arr[6].i;
 yd := arr[7].i;
 r := '';
 i := 1;
 While i <= Length(fmt) Do Begin
  If (fmt[i] = '%') And (i < Length(fmt)) Then Begin
   Inc(i);
   c := fmt[i];
   Case c Of
    'Y': r := r + IntToStr(y);
    'y': r := r + Format('%.2d', [y Mod 100]);
    'm': r := r + Format('%.2d', [mo]);
    'd': r := r + Format('%.2d', [d]);
    'H': r := r + Format('%.2d', [h]);
    'I': r := r + Format('%.2d', [((h + 11) Mod 12) + 1]);
    'M': r := r + Format('%.2d', [mi]);
    'S': r := r + Format('%.2d', [s]);
    'p': If h < 12 Then r := r + 'AM' Else r := r + 'PM';
    'A': r := r + Days[wd];
    'a': r := r + Copy(Days[wd], 1, 3);
    'B': r := r + Months[mo];
    'b': r := r + Copy(Months[mo], 1, 3);
    'j': r := r + Format('%.3d', [yd]);
    'w': r := r + IntToStr((wd + 1) Mod 7);
    'Z': r := r + 'UTC';
    'z': r := r + '+0000';
    'F': r := r + Format('%.4d-%.2d-%.2d', [y, mo, d]);
    'T': r := r + Format('%.2d:%.2d:%.2d', [h, mi, s]);
    'D': r := r + Format('%.2d/%.2d/%.2d', [mo, d, y Mod 100]);
    'c': r := r + Copy(Days[wd], 1, 3) + ' ' + Copy(Months[mo], 1, 3) + ' ' +
      Format('%2d %.2d:%.2d:%.2d %d', [d, h, mi, s, y]);
    'x': r := r + Format('%.2d/%.2d/%.2d', [mo, d, y Mod 100]);
    'X': r := r + Format('%.2d:%.2d:%.2d', [h, mi, s]);
    '%': r := r + '%';
    'n': r := r + #10;
    't': r := r + #9;
   Else r := r + '%' + c;
   End;
  End
  Else r := r + fmt[i];
  Inc(i);
 End;
 Result := VStr(r);
End;

Function TimeCtime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 args: Array[0..1] Of TVal;
Begin
 args[0] := VStr('%a %b %e %H:%M:%S %Y');
 If (n > 0) And (a[0].k <> vkNone) Then
  args[1] := TimeStructArr(Floor(NumToDouble(a[0])), True)
 Else args[1] := TimeStructArr(Floor(NowSeconds), True);
 Result := TimeStrftime(@args[0], 2, Nil);
End;

Procedure InitTimeModule(m: TPyModule);
Var
 d: TPyDict;
Begin
 d := m.idict;
 StartTick := NowSeconds;
 DefFunc(d, 'time', @TimeTime);
 DefFunc(d, 'time_ns', @TimeTimeNs);
 DefFunc(d, 'sleep', @TimeSleep);
 DefFunc(d, 'perf_counter', @TimePerf);
 DefFunc(d, 'perf_counter_ns', @TimePerfNs);
 DefFunc(d, 'monotonic', @TimePerf);
 DefFunc(d, 'monotonic_ns', @TimePerfNs);
 DefFunc(d, 'process_time', @TimeProcess);
 DefFunc(d, 'gmtime', @TimeGmtime);
 DefFunc(d, 'localtime', @TimeLocaltime);
 DefFunc(d, 'mktime', @TimeMktime);
 DefFunc(d, 'strftime', @TimeStrftime);
 DefFunc(d, 'ctime', @TimeCtime);
 d.SetS('timezone', VInt(0));
 d.SetS('altzone', VInt(0));
 d.SetS('daylight', VInt(0));
 d.SetS('tzname', Tup2(VStr('UTC'), VStr('UTC')));
End;

{ ------------------------------------------------------------
  Module posix (primitives du module os)
  ------------------------------------------------------------ }
Function PosixGetcwd(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(GetCurrentDir);
End;

Function PosixChdir(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 If Not DirectoryExists(p) Then Begin
  If FileExists(p) Then RaiseOSErr(exNotADirectory, 20, 'Not a directory', p)
  Else RaiseNoEnt(p);
 End;
 SetCurrentDir(p);
 Result := vNone;
End;

Function PosixListdir(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
 sr: TSearchRec;
 l: TPyList;
Begin
 If n > 0 Then p := StrOf(a[0]) Else p := '.';
 If Not DirectoryExists(p) Then Begin
  If FileExists(p) Then RaiseOSErr(exNotADirectory, 20, 'Not a directory', p)
  Else RaiseNoEnt(p);
 End;
 l := NewList;
 If FindFirst(JoinPath(p, '*'), faAnyFile, sr) = 0 Then Begin
  Repeat
   If (sr.Name <> '.') And (sr.Name <> '..') Then l.Add(VStr(sr.Name));
  Until FindNext(sr) <> 0;
  FindClose(sr);
 End;
 Result := VObj(l);
End;

Function PosixMkdir(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 If DirectoryExists(p) Or FileExists(p) Then
  RaiseOSErr(exFileExists, 17, 'File exists', p);
 If Not CreateDir(p) Then Begin
  If Not DirectoryExists(ExtractFileDir(ExpandFileName(p))) Then RaiseNoEnt(p)
  Else RaiseOSErr(exPermissionError, 13, 'Permission denied', p);
 End;
 Result := vNone;
End;

Function PosixRemove(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 If DirectoryExists(p) Then
  RaiseOSErr(exIsADirectory, 21, 'Is a directory', p);
 If Not FileExists(p) Then RaiseNoEnt(p);
 If Not DeleteFile(p) Then
  RaiseOSErr(exPermissionError, 13, 'Permission denied', p);
 Result := vNone;
End;

Function PosixRmdir(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 If Not DirectoryExists(p) Then RaiseNoEnt(p);
 If Not RemoveDir(p) Then
  RaiseOSErr(exOSError, 39, 'Directory not empty', p);
 Result := vNone;
End;

Function PosixRename(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s, d: AnsiString;
Begin
 s := StrOf(a[0]);
 d := StrOf(a[1]);
 If Not (FileExists(s) Or DirectoryExists(s)) Then RaiseNoEnt(s);
 If Not RenameFile(s, d) Then
  RaiseOSErr(exPermissionError, 13, 'Permission denied', s);
 Result := vNone;
End;

Function PosixExists(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 Result := VBool(FileExists(p) Or DirectoryExists(p));
End;

Function PosixIsFile(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
Begin
 p := StrOf(a[0]);
 Result := VBool(FileExists(p) And Not DirectoryExists(p));
End;

Function PosixIsDir(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(DirectoryExists(StrOf(a[0])));
End;

Function PosixGetSize(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
 sr: TSearchRec;
Begin
 p := StrOf(a[0]);
 If FindFirst(p, faAnyFile, sr) <> 0 Then RaiseNoEnt(p);
 Result := VInt(sr.Size);
 FindClose(sr);
End;

Function PosixGetMTime(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 p: AnsiString;
 age: LongInt;
Begin
 p := StrOf(a[0]);
 age := FileAge(p);
 If age = -1 Then RaiseNoEnt(p);
 Result := VFloat((FileDateToDateTime(age) - EncodeDate(1970, 1, 1)) *
  86400.0 - (-GetLocalTimeOffset * 60));
End;

Function PosixEnviron(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 d: TPyDict;
 i, p: Integer;
 s: AnsiString;
Begin
 d := TPyDict.Make;
 For i := 1 To GetEnvironmentVariableCount Do Begin
  s := GetEnvironmentString(i);
  p := Pos('=', s);
  If p > 1 Then d.SetItem(VStr(Copy(s, 1, p - 1)), VStr(Copy(s, p + 1,
   Length(s))));
 End;
 Result := VObj(d);
End;

Function PosixGetpid(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(GetProcessID);
End;

Function PosixSystem(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 rc: Integer;
Begin
 OutFlush;
 {$IFDEF UNIX}
 rc := fpSystem(StrOf(a[0]));
 If rc <> -1 Then rc := (rc And $FF00) Shr 8 * 256;
 Result := VInt(rc);
 {$ELSE}
 Result := VInt(0);
 {$ENDIF}
End;

Function PosixUrandom(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 s: AnsiString;
 i, k: Integer;
Begin
 k := IndexVal(a[0]);
 SetLength(s, k);
 For i := 1 To k Do s[i] := Chr(Random(256));
 Result := VBytes(s);
End;

{$IFDEF UNIX}
Function c_setenv(nm, v: PChar; ow: LongInt): LongInt; CDecl; External 'c' Name 'setenv';
{$ENDIF}

Function PosixSetenv(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 {$IFDEF UNIX}
 c_setenv(PChar(StrOf(a[0])), PChar(StrOf(a[1])), 1);
 {$ENDIF}
 Result := vNone;
End;

Function PosixCpuCount(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VInt(1);
End;

Function PosixAbspath(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VStr(ExpandFileName(StrOf(a[0])));
End;

Procedure InitPosixModule(m: TPyModule);
Var
 d: TPyDict;
Begin
 d := m.idict;
 DefFunc(d, 'getcwd', @PosixGetcwd);
 DefFunc(d, 'chdir', @PosixChdir);
 DefFunc(d, 'listdir', @PosixListdir);
 DefFunc(d, 'mkdir', @PosixMkdir);
 DefFunc(d, 'remove', @PosixRemove);
 DefFunc(d, 'rmdir', @PosixRmdir);
 DefFunc(d, 'rename', @PosixRename);
 DefFunc(d, 'exists', @PosixExists);
 DefFunc(d, 'isfile', @PosixIsFile);
 DefFunc(d, 'isdir', @PosixIsDir);
 DefFunc(d, 'getsize', @PosixGetSize);
 DefFunc(d, 'getmtime', @PosixGetMTime);
 DefFunc(d, 'environ', @PosixEnviron);
 DefFunc(d, 'getpid', @PosixGetpid);
 DefFunc(d, 'system', @PosixSystem);
 DefFunc(d, 'urandom', @PosixUrandom);
 DefFunc(d, 'putenv', @PosixSetenv);
 DefFunc(d, 'cpu_count', @PosixCpuCount);
 DefFunc(d, 'abspath', @PosixAbspath);
End;

{ ------------------------------------------------------------
  Module _random : Mersenne Twister MT19937 (comme CPython)
  ------------------------------------------------------------ }
Type
 TPyMT = Class(TPyObj)
  mt: Array[0..623] Of Cardinal;
  mti: Integer;
 End;

Procedure MTInitGen(r: TPyMT; s: Cardinal);
Var
 i: Integer;
Begin
 r.mt[0] := s;
 For i := 1 To 623 Do
  r.mt[i] := Cardinal((QWord(1812433253) * (r.mt[i - 1] Xor (r.mt[i - 1] Shr
   30)) + QWord(i)) And $FFFFFFFF);
 r.mti := 624;
End;

Procedure MTInitByArray(r: TPyMT; Const key: Array Of Cardinal);
Var
 i, j, k, klen: Integer;
Begin
 klen := Length(key);
 MTInitGen(r, 19650218);
 i := 1;
 j := 0;
 If 624 > klen Then k := 624 Else k := klen;
 While k > 0 Do Begin
  r.mt[i] := Cardinal(((QWord(r.mt[i]) Xor ((QWord(r.mt[i - 1]) Xor
   (r.mt[i - 1] Shr 30)) * QWord(1664525))) + key[j] + QWord(j)) And
   $FFFFFFFF);
  Inc(i);
  Inc(j);
  If i >= 624 Then Begin
   r.mt[0] := r.mt[623];
   i := 1;
  End;
  If j >= klen Then j := 0;
  Dec(k);
 End;
 k := 623;
 While k > 0 Do Begin
  r.mt[i] := Cardinal(((QWord(r.mt[i]) Xor ((QWord(r.mt[i - 1]) Xor
   (r.mt[i - 1] Shr 30)) * QWord(1566083941))) - QWord(i)) And $FFFFFFFF);
  Inc(i);
  If i >= 624 Then Begin
   r.mt[0] := r.mt[623];
   i := 1;
  End;
  Dec(k);
 End;
 r.mt[0] := $80000000;
 r.mti := 624;
End;

Function MTGenInt32(r: TPyMT): Cardinal;
Var
 y: Cardinal;
 kk: Integer;
Begin
 If r.mti >= 624 Then Begin
  For kk := 0 To 623 - 397 Do Begin
   y := (r.mt[kk] And $80000000) Or (r.mt[kk + 1] And $7FFFFFFF);
   r.mt[kk] := r.mt[kk + 397] Xor (y Shr 1) Xor ((y And 1) * $9908B0DF);
  End;
  For kk := 624 - 397 To 622 Do Begin
   y := (r.mt[kk] And $80000000) Or (r.mt[kk + 1] And $7FFFFFFF);
   r.mt[kk] := r.mt[kk + 397 - 624] Xor (y Shr 1) Xor ((y And 1) * $9908B0DF);
  End;
  y := (r.mt[623] And $80000000) Or (r.mt[0] And $7FFFFFFF);
  r.mt[623] := r.mt[396] Xor (y Shr 1) Xor ((y And 1) * $9908B0DF);
  r.mti := 0;
 End;
 y := r.mt[r.mti];
 Inc(r.mti);
 y := y Xor (y Shr 11);
 y := y Xor ((y Shl 7) And $9D2C5680);
 y := y Xor ((y Shl 15) And $EFC60000);
 y := y Xor (y Shr 18);
 Result := y;
End;

Function RndNew(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
Begin
 r := TPyMT.Create(tyObject);
 MTInitGen(r, Cardinal(Trunc(NowSeconds * 1000)) Xor Cardinal(GetProcessID));
 Result := VObj(r);
End;

Function RndSeed(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
 key: Array Of Cardinal;
 v: TVal;
 neg: Boolean;
 m: TMag;
 i: Integer;
 s: AnsiString;
Begin
 r := TPyMT(a[0].o);
 v := a[1];
 If v.k = vkNone Then Begin
  MTInitGen(r, Cardinal(Trunc(NowSeconds * 1000)));
  Result := vNone;
  Exit;
 End;
 If IsStrVal(v) Or ((v.k = vkObj) And (v.o Is TPyBytes)) Then Begin
  If IsStrVal(v) Then s := TPyStr(v.o).s Else s := TPyBytes(v.o).s;
  v := VInt(Abs(HashBytes(s)));
 End
 Else If v.k = vkFloat Then v := VInt(HashVal(v));
 IntToMag(v, neg, m);
 If Length(m) = 0 Then Begin
  SetLength(key, 1);
  key[0] := 0;
 End
 Else Begin
  SetLength(key, Length(m));
  For i := 0 To High(m) Do key[i] := m[i];
 End;
 MTInitByArray(r, key);
 Result := vNone;
End;

Function RndRandom(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
 x, y: Cardinal;
Begin
 r := TPyMT(a[0].o);
 x := MTGenInt32(r) Shr 5;
 y := MTGenInt32(r) Shr 6;
 Result := VFloat((x * 67108864.0 + y) * (1.0 / 9007199254740992.0));
End;

Function RndGetRandBits(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
 k, i, words: Integer;
 m: TMag;
 w: Cardinal;
Begin
 r := TPyMT(a[0].o);
 k := IndexVal(a[1]);
 If k < 0 Then ValueErr('number of bits must be non-negative');
 If k = 0 Then Begin
  Result := VInt(0);
  Exit;
 End;
 If k <= 32 Then Begin
  Result := VInt(MTGenInt32(r) Shr (32 - k));
  Exit;
 End;
 words := (k - 1) Div 32 + 1;
 SetLength(m, words);
 For i := 0 To words - 1 Do Begin
  w := MTGenInt32(r);
  If k < 32 Then w := w Shr (32 - k);
  m[i] := w;
  Dec(k, 32);
 End;
 Result := MakeInt(False, m);
End;

Function RndGetState(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
 t: TPyTuple;
 i: Integer;
Begin
 r := TPyMT(a[0].o);
 t := NewTuple(625);
 For i := 0 To 623 Do t.items[i] := VInt(r.mt[i]);
 t.items[624] := VInt(r.mti);
 Result := VObj(t);
End;

Function RndSetState(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 r: TPyMT;
 t: TPyTuple;
 i: Integer;
Begin
 r := TPyMT(a[0].o);
 t := TPyTuple(a[1].o);
 For i := 0 To 623 Do r.mt[i] := Cardinal(t.items[i].i);
 r.mti := t.items[624].i;
 Result := vNone;
End;

Procedure InitRandomModule(m: TPyModule);
Var
 d: TPyDict;
Begin
 d := m.idict;
 DefFunc(d, 'new', @RndNew);
 DefFunc(d, 'seed', @RndSeed);
 DefFunc(d, 'random', @RndRandom);
 DefFunc(d, 'getrandbits', @RndGetRandBits);
 DefFunc(d, 'getstate', @RndGetState);
 DefFunc(d, 'setstate', @RndSetState);
End;

{ ------------------------------------------------------------
  Modules gc, atexit, builtins
  ------------------------------------------------------------ }
Var
 AtExitList: TPyList;

Function GcCollectM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 GcLastLive := GcCount - GcThreshold - 1;
 Result := VInt(0);
End;

Function GcEnableM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 GcEnabled := True;
 Result := vNone;
End;

Function GcDisableM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 GcEnabled := False;
 Result := vNone;
End;

Function GcIsEnabledM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VBool(GcEnabled);
End;

Function GcGetCountM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(TupleFromVals([VInt(GcCount - GcLastLive), VInt(0), VInt(0)]));
End;

Function GcGetObjectsM(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := VObj(NewList);
End;

Procedure InitGcModule(m: TPyModule);
Var
 d: TPyDict;
Begin
 d := m.idict;
 DefFunc(d, 'collect', @GcCollectM);
 DefFunc(d, 'enable', @GcEnableM);
 DefFunc(d, 'disable', @GcDisableM);
 DefFunc(d, 'isenabled', @GcIsEnabledM);
 DefFunc(d, 'get_count', @GcGetCountM);
 DefFunc(d, 'get_objects', @GcGetObjectsM);
 DefFunc(d, 'set_threshold', @SysNoop);
 DefFunc(d, 'get_threshold', @GcGetCountM);
 d.SetS('garbage', VObj(NewList));
End;

Function AtExitRegister(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyTuple;
 i: Integer;
Begin
 If n < 1 Then TypeErr('register() takes at least 1 argument (0 given)');
 t := NewTuple(n);
 For i := 0 To n - 1 Do t.items[i] := a[i];
 AtExitList.Add(VObj(t));
 Result := a[0];
End;

Function AtExitUnregister(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 i: Integer;
Begin
 For i := AtExitList.cnt - 1 DownTo 0 Do
  If ValEq(TPyTuple(AtExitList.items[i].o).items[0], a[0]) Then
   AtExitList.Delete(i);
 Result := vNone;
End;

Function AtExitRunM(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 t: TPyTuple;
Begin
 While AtExitList.cnt > 0 Do Begin
  t := TPyTuple(AtExitList.items[AtExitList.cnt - 1].o);
  AtExitList.Delete(AtExitList.cnt - 1);
  Try
   CallValue(t.items[0], @t.items[1], Length(t.items) - 1, Nil);
  Except
   On E: EPyError Do Begin
    If IsInstance(VObj(E.exc), exSystemExit) Then Raise;
    ErrWrite('Error in atexit._run_exitfuncs:' + #10);
    PyRunTraceback(E.exc);
   End;
  End;
 End;
 Result := vNone;
End;

Procedure InitAtexitModule(m: TPyModule);
Begin
 DefFunc(m.idict, 'register', @AtExitRegister);
 DefFunc(m.idict, 'unregister', @AtExitUnregister);
 DefFunc(m.idict, '_run_exitfuncs', @AtExitRunM);
End;

Procedure InitBuiltinsModule(m: TPyModule);
Begin
 m.idict := BuiltinsDict;
 BuiltinsDict.SetS('__name__', VStr('builtins'));
End;

{ module _io / io minimal : StringIO natif pour la rapidite }
Function SioNew(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
Begin
 f := TPyFile.Create(tyFile);
 f.fname := '<StringIO>';
 f.mode := 'w+';
 f.readable := True;
 f.writable := True;
 f.std := 0;
 f.pos := 0;
 f.closed := False;
 f.dirty := False;
 If (n > 0) And IsStrVal(a[0]) Then f.data := TPyStr(a[0].o).s;
 Result := VObj(f);
End;

Function BioNew(a: PVal; n: Integer; kw: TPyDict): TVal;
Var
 f: TPyFile;
Begin
 f := TPyFile(SioNew(a, 0, kw).o);
 f.binary := True;
 f.fname := '<BytesIO>';
 If (n > 0) And (a[0].k = vkObj) And (a[0].o Is TPyBytes) Then
  f.data := TPyBytes(a[0].o).s;
 Result := VObj(f);
End;

Function SioGetValue(a: PVal; n: Integer; kw: TPyDict): TVal;
Begin
 Result := FileOut(TPyFile(a[0].o), TPyFile(a[0].o).data);
End;

Procedure InitIoModule(m: TPyModule);
Begin
 DefFunc(m.idict, '_stringio', @SioNew);
 DefFunc(m.idict, '_bytesio', @BioNew);
 DefFunc(m.idict, '_getvalue', @SioGetValue);
 m.idict.SetS('TextIOWrapper', VObj(tyFile));
 m.idict.SetS('open', BuiltinsDict.ent[BuiltinsDict.FindS('open', HashBytes(
  'open'))].val);
End;

{ ------------------------------------------------------------
  Initialisation, ligne de commande, mode interactif
  ------------------------------------------------------------ }
Procedure RegisterPrelude; Forward;

Type
 TOptions = Record
  optB, optBB, optBytecode, optD, optE, optH, optI, optIso, optQ, optS,
  optSS, optU, optX, optP, optV2: Boolean;
  optVerbose: Integer;
  optVersion: Integer;
  optOptimize: Integer;
  cmd: AnsiString;
  hasCmd: Boolean;
  modName: AnsiString;
  hasMod: Boolean;
  script: AnsiString;
  hasScript: Boolean;
  warn: TStrArr;
  xopts: TStrArr;
  args: TStrArr;
  helpEnv, helpX, helpAll: Boolean;
  checkHash: AnsiString;
 End;

Var
 Opts: TOptions;
 MainDict: TPyDict;
 InteractiveMode: Boolean;
 ExitCode: Integer;
 StdinIsTTY: Boolean;
 StdoutIsTTY: Boolean;
 SrcSiteFn: TModSrc;

Procedure SigIntHandler(sig: LongInt); CDecl;
Begin
 PendingInterrupt := True;
End;

Procedure InstallSignals;
{$IFDEF UNIX}
Var
 sa, old: SigActionRec;
{$ENDIF}
Begin
 {$IFDEF UNIX}
 FillChar(sa, SizeOf(sa), 0);
 sa.sa_handler := SigActionHandler(@SigIntHandler);
 sa.sa_flags := 0;
 fpSigAction(SIGINT, @sa, @old);
 FillChar(sa, SizeOf(sa), 0);
 sa.sa_handler := SigActionHandler(SIG_IGN);
 fpSigAction(SIGPIPE, @sa, @old);
 {$ENDIF}
End;

Function GetEnv(Const nm: AnsiString): AnsiString;
Begin
 Result := GetEnvironmentVariable(nm);
End;

Procedure InitRuntime;
Var
 stackSize: PtrUInt;
 m: TPyModule;
Begin
 GcInit := True;
 GcEnabled := True;
 GcThreshold := 300000;
 GcLastLive := 0;
 NestLimit := 180;
 RecursionLimit := 1000;
 SetLength(OutBuf, 65536);
 OutLen := 0;
 InPos := 1;
 stackSize := 16 * 1024 * 1024;
 VStackBase := Nil;
 While (VStackBase = Nil) And (stackSize >= 65536) Do Begin
  Try
   GetMem(VStackBase, stackSize * SizeOf(TVal));
  Except
   VStackBase := Nil;
   stackSize := stackSize Div 2;
  End;
 End;
 VTop := VStackBase;
 VLimit := VStackBase + stackSize;
 InitOpNames;
 InitBinIdx;
 vNone.k := vkNone;
 vNone.i := 0;
 NativeMods := TStringList.Create;
 NativeMods.Sorted := False;
 SrcMods := TStringList.Create;
 InternTab := TPyDict.Make;
 BuiltinsDict := TPyDict.Make;
 ModulesDict := TPyDict.Make;
 InitTypes;
 InitBuiltinFuncs;
 InitStrMethods;
 InitContainerMethods;
 InitFileType;
 DefFunc(BuiltinsDict, '__import__', @BiImport);
 StdinObj := NewStdFile(1, 'r');
 StdoutObj := NewStdFile(2, 'w');
 StderrObj := NewStdFile(3, 'w');
 AtExitList := NewList;
 SysPathList := NewList;
 RegNative('sys', @InitSysModule);
 RegNative('math', @InitMathModule);
 RegNative('time', @InitTimeModule);
 RegNative('posix', @InitPosixModule);
 RegNative('_random', @InitRandomModule);
 RegNative('gc', @InitGcModule);
 RegNative('atexit', @InitAtexitModule);
 RegNative('builtins', @InitBuiltinsModule);
 RegNative('_io', @InitIoModule);
 RegisterPrelude;
 m := NewModule('__main__');
 MainDict := m.idict;
 MainDict.SetS('__builtins__', VObj(BuiltinsDict));
 MainDict.SetS('__package__', vNone);
 ModulesDict.SetS('__main__', VObj(m));
 SysDict := TPyModule(ImportByName('sys').o).idict;
End;

Function ExitCodeOf(exc: TPyObj): Integer;
Var
 c: TVal;
Begin
 Result := 0;
 If (exc.idict <> Nil) And exc.idict.GetS('code', c) Then Begin
  If c.k = vkNone Then Result := 0
  Else If IsIntVal(c) And (c.k <> vkObj) Then Result := c.i And 255
  Else Begin
   ErrWrite(StrVal(c) + #10);
   Result := 1;
  End;
 End
 Else Result := 0;
End;

{ traite une exception non interceptee ; renvoie le code de sortie }
Function HandleUncaught(exc: TPyObj): Integer;
Var
 hook: TVal;
 args: Array[0..2] Of TVal;
Begin
 If IsInstance(VObj(exc), exSystemExit) Then Begin
  Result := ExitCodeOf(exc);
  Exit;
 End;
 If SysDict.GetS('excepthook', hook) And (hook.k = vkObj) And
  Not (hook.o Is TPyBuiltin) Then Begin
  Try
   args[0] := VObj(exc.cls);
   args[1] := VObj(exc);
   args[2] := vNone;
   CallValue(hook, @args[0], 3, Nil);
  Except
   On E: EPyError Do PyRunTraceback(E.exc);
  End;
 End
 Else PyRunTraceback(exc);
 If IsInstance(VObj(exc), exKeyboardInterrupt) Then Result := 130
 Else Result := 1;
End;

Procedure RunAtExit;
Var
 m: TVal;
Begin
 If ModulesDict.GetS('atexit', m) Then Begin
  Try
   AtExitRunM(Nil, 0, Nil);
  Except
   On E: EPyError Do Begin
    If IsInstance(VObj(E.exc), exSystemExit) Then ExitCode := ExitCodeOf(E.exc);
   End;
  End;
 End;
End;

Procedure FinishAndHalt(code: Integer);
Begin
 Try
  RunAtExit;
 Except
 End;
 Try
  FlushAllFiles;
 Except
 End;
 OutFlush;
 Halt(code);
End;

{ Execute une source dans __main__ ; renvoie le code de sortie }
Function RunSource(Const src, fname: AnsiString): Integer;
Var
 code: TPyCode;
Begin
 Result := 0;
 Try
  code := CompileSafe(src, fname, 0);
  RunCodeObject(code, MainDict, MainDict);
 Except
  On E: EPyError Do Result := HandleUncaught(E.exc);
 End;
End;

Procedure SetSysArgv(Const first: AnsiString);
Var
 l: TPyList;
 i: Integer;
Begin
 l := NewList;
 l.Add(VStr(first));
 For i := 0 To High(Opts.args) Do l.Add(VStr(Opts.args[i]));
 SysDict.SetS('argv', VObj(l));
 SysDict.SetS('orig_argv', VObj(l));
End;

{ ------------------------------------------------------------
  Mode interactif
  ------------------------------------------------------------ }
Function IsCompoundStart(Const src: AnsiString): Boolean;
Var
 p, q: Integer;
 w: AnsiString;
Begin
 Result := False;
 p := 1;
 While p <= Length(src) Do Begin
  { debut d'une ligne logique : ignorer les lignes vides et commentaires }
  While (p <= Length(src)) And (src[p] In [#10]) Do Inc(p);
  If p > Length(src) Then Exit;
  If src[p] = '#' Then Begin
   While (p <= Length(src)) And (src[p] <> #10) Do Inc(p);
   Continue;
  End;
  Break;
 End;
 If p > Length(src) Then Exit;
 If src[p] = '@' Then Begin
  Result := True;
  Exit;
 End;
 If Not IsIdStart(src[p]) Then Exit;
 q := p;
 While (q <= Length(src)) And IsIdChar(src[q]) Do Inc(q);
 w := Copy(src, p, q - p);
 Result := (w = 'if') Or (w = 'while') Or (w = 'for') Or (w = 'try') Or
  (w = 'with') Or (w = 'def') Or (w = 'class') Or (w = 'async');
End;

Function ReadPromptLine(Const prompt: AnsiString; Var line: AnsiString):
 Boolean;
Begin
 OutFlush;
 ErrWrite(prompt);
 PendingInterrupt := False;
 Result := StdinReadLine(line);
 If (Not Result) And PendingInterrupt Then Begin
  PendingInterrupt := False;
  line := #3;
  Result := True;
 End;
End;

Function GetPrompt(Const nm, deflt: AnsiString): AnsiString;
Var
 v: TVal;
Begin
 If SysDict.GetS(nm, v) Then Result := StrVal(v) Else Result := deflt;
End;

Procedure RunInteractive;
Var
 buf, line, p: AnsiString;
 code: TPyCode;
 more, ok: Boolean;
 eof: Boolean;
Begin
 SysDict.SetS('ps1', VStr('>>> '));
 SysDict.SetS('ps2', VStr('... '));
 If Not Opts.optQ Then Begin
  ErrWrite('Python ' + PY_VERSION + ' ' + PY_BUILD + ' ' + #10 +
   PY_COMPILER + ' on ' + Copy('linux', 1, 5 * Ord(True)) + #10 +
   'Type "help", "copyright", "credits" or "license" for more information.'
   + #10);
 End;
 { fichier de demarrage }
 If (Not Opts.optE) And (Not Opts.optIso) And (GetEnv('PYTHONSTARTUP') <> '')
  Then Begin
  If ReadWholeFile(GetEnv('PYTHONSTARTUP'), line) Then
   RunSource(line, GetEnv('PYTHONSTARTUP'));
 End;
 buf := '';
 eof := False;
 While Not eof Do Begin
  If buf = '' Then p := GetPrompt('ps1', '>>> ')
  Else p := GetPrompt('ps2', '... ');
  If Not ReadPromptLine(p, line) Then Begin
   If StdinIsTTY Then ErrWrite(#10);
   Break;
  End;
  If line = #3 Then Begin
   ErrWrite('KeyboardInterrupt' + #10);
   buf := '';
   Continue;
  End;
  buf := buf + line;
  If (line <> '') And (line[Length(line)] <> #10) Then buf := buf + #10;
  { instruction composee : il faut une ligne vide pour terminer }
  more := False;
  If IsCompoundStart(buf) Then Begin
   If Not ((Length(buf) >= 2) And (buf[Length(buf)] = #10) And
    (buf[Length(buf) - 1] = #10)) Then more := True;
  End;
  If Not more Then Begin
   ok := True;
   Try
    code := CompileSource(buf, '<stdin>', 2);
    code.source := Nil;
   Except
    On E: ESyntax Do Begin
     If E.incomplete Then Begin
      ok := False;
      more := True;
     End
     Else Begin
      PyRunTraceback(ExcFromSyntax(E, '<stdin>'));
      buf := '';
      ok := False;
     End;
    End;
   End;
   If ok Then Begin
    Try
     RunCodeObject(code, MainDict, MainDict);
    Except
     On E: EPyError Do Begin
      If IsInstance(VObj(E.exc), exSystemExit) Then Begin
       ExitCode := ExitCodeOf(E.exc);
       eof := True;
      End
      Else HandleUncaught(E.exc);
     End;
    End;
    buf := '';
   End;
  End;
 End;
End;

{ ------------------------------------------------------------
  Aide
  ------------------------------------------------------------ }
Procedure ShowUsage(toErr: Boolean);
Var
 s: AnsiString;
Begin
 s := 'usage: python3 [option] ... [-c cmd | -m mod | file | -] [arg] ...' +
  #10;
 If toErr Then ErrWrite(s) Else OutWrite(s);
End;

Procedure ShowHelp;
Begin
 OutWrite('usage: python3 [option] ... [-c cmd | -m mod | file | -] [arg] ' +
  '...' + #10 +
  'Options and arguments (and corresponding environment variables):' + #10 +
  '-b     : issue warnings about str(bytes_instance), str(bytearray_instance)'
  + #10 + '         and comparing bytes/bytearray with str. (-bb: issue ' +
  'errors)' + #10 +
  '-B     : don''t write .pyc files on import; also PYTHONDONTWRITEBYTECODE=x'
  + #10 +
  '-c cmd : program passed in as string (terminates option list)' + #10 +
  '-d     : turn on parser debugging output (for experts only, only works on'
  + #10 + '         debug builds); also PYTHONDEBUG=x' + #10 +
  '-E     : ignore PYTHON* environment variables (such as PYTHONPATH)' + #10 +
  '-h     : print this help message and exit (also --help)' + #10 +
  '-i     : inspect interactively after running script; forces a prompt even'
  + #10 + '         if stdin does not appear to be a terminal; also ' +
  'PYTHONINSPECT=x' + #10 +
  '-I     : isolate Python from the user''s environment (implies -E and -s)'
  + #10 +
  '-m mod : run library module as a script (terminates option list)' + #10 +
  '-O     : remove assert and __debug__-dependent statements; add .opt-1 ' +
  'before' + #10 + '         .pyc extension; also PYTHONOPTIMIZE=x' + #10 +
  '-OO    : do -O changes and also discard docstrings; add .opt-2 before' +
  #10 + '         .pyc extension' + #10 +
  '-q     : don''t print version and copyright messages on interactive ' +
  'startup' + #10 +
  '-s     : don''t add user site directory to sys.path; also PYTHONNOUSERSITE'
  + #10 +
  '-S     : don''t imply ''import site'' on initialization' + #10 +
  '-u     : force the stdout and stderr streams to be unbuffered;' + #10 +
  '         this option has no effect on stdin; also PYTHONUNBUFFERED=x' + #10
  + '-v     : verbose (trace import statements); also PYTHONVERBOSE=x' + #10 +
  '         can be supplied multiple times to increase verbosity' + #10 +
  '-V     : print the Python version number and exit (also --version)' + #10 +
  '         when given twice, print more information about the build' + #10 +
  '-W arg : warning control; arg is action:message:category:module:lineno' +
  #10 + '         also PYTHONWARNINGS=arg' + #10 +
  '-x     : skip first line of source, allowing use of non-Unix forms of ' +
  '#!cmd' + #10 + '-X opt : set implementation-specific option' + #10 +
  '--check-hash-based-pycs always|default|never:' + #10 +
  '    control how Python invalidates hash-based .pyc files' + #10 +
  'file   : program read from script file' + #10 +
  '-      : program read from stdin (default; interactive mode if a tty)' +
  #10 + 'arg ...: arguments passed to program in sys.argv[1:]' + #10#10 +
  'Other environment variables:' + #10 +
  'PYTHONSTARTUP: file executed on interactive startup (no default)' + #10 +
  'PYTHONPATH   : '':''-separated list of directories prefixed to the' + #10 +
  '               default module search path.  The result is sys.path.' + #10
  + 'PYTHONHOME   : alternate <prefix> directory (or <prefix>:' +
  '<exec_prefix>).' + #10 + '               The default module search path ' +
  'uses <prefix>/lib/pythonX.X.' + #10 +
  'PYTHONCASEOK : ignore case in ''import'' statements (Windows).' + #10 +
  'PYTHONIOENCODING: Encoding[:errors] used for stdin/stdout/stderr.' + #10 +
  'PYTHONFAULTHANDLER: dump the Python traceback on fatal errors.' + #10 +
  'PYTHONHASHSEED: if this variable is set to ''random'', a random value ' +
  'is used' + #10 + '   to seed the hashes of str, bytes and datetime ' +
  'objects.  It can also be' + #10 + '   set to an integer in the range ' +
  '[0,4294967295] to get hash values with a' + #10 +
  '   predictable seed.' + #10 +
  'PYTHONMALLOC: set the Python memory allocators and/or install debug ' +
  'hooks' + #10 + '   on Python memory allocators. Use PYTHONMALLOC=debug ' +
  'to install debug' + #10 + '   hooks.' + #10 +
  'PYTHONCOERCECLOCALE: if this variable is set to 0, it disables the ' +
  'locale' + #10 + '   coercion behavior. Use PYTHONCOERCECLOCALE=warn to ' +
  'request display of' + #10 + '   locale coercion and locale ' +
  'compatibility warnings on stderr.' + #10 +
  'PYTHONBREAKPOINT: if this variable is set to 0, it disables the default'
  + #10 + '   debugger. It can be set to the callable of your debugger of ' +
  'choice.' + #10 + 'PYTHONDEVMODE: enable the development mode.' + #10 +
  'PYTHONPYCACHEPREFIX: root directory for bytecode cache (pyc) files.' +
  #10);
End;

Procedure ShowHelpEnv;
Begin
 OutWrite('Environment variables that change the behavior of python3:' + #10 +
  'PYTHONSTARTUP: file executed on interactive startup (no default)' + #10 +
  'PYTHONPATH   : '':''-separated list of directories prefixed to the' + #10 +
  '               default module search path.  The result is sys.path.' + #10 +
  'PYTHONHOME   : alternate <prefix> directory' + #10 +
  'PYTHONOPTIMIZE: enable level 1 optimizations (-O); >=2 for -OO' + #10 +
  'PYTHONDONTWRITEBYTECODE: don''t write .pyc files (-B)' + #10 +
  'PYTHONINSPECT: inspect interactively after running a script (-i)' + #10 +
  'PYTHONUNBUFFERED: unbuffered stdout/stderr (-u)' + #10 +
  'PYTHONVERBOSE: trace imports (-v)' + #10 +
  'PYTHONWARNINGS: warning control (-W)' + #10 +
  'PYTHONNOUSERSITE: don''t add the user site directory (-s)' + #10 +
  'PYTHONDEBUG  : parser debugging output (-d)' + #10 +
  'PYTHONIOENCODING: Encoding[:errors] used for stdin/stdout/stderr' + #10 +
  'PYTHONHASHSEED: random or an integer in [0,4294967295]' + #10 +
  'PYTHONDEVMODE: enable the development mode' + #10);
End;

Procedure ShowHelpX;
Begin
 OutWrite('The following implementation-specific options are available:' + #10 +
  '-X dev: enable CPython''s "development mode", introducing additional ' +
  'runtime' + #10 + '         checks which are too expensive to be enabled ' +
  'by default.' + #10 +
  '-X faulthandler: enable faulthandler' + #10 +
  '-X importtime: show how long each import takes' + #10 +
  '-X showrefcount: output the total reference count and number of used' + #10 +
  '         memory blocks when the program finishes' + #10 +
  '-X tracemalloc: start tracing Python memory allocations' + #10 +
  '-X utf8: enable UTF-8 mode for operating system interfaces' + #10 +
  '-X pycache_prefix=PATH: write .pyc files to a parallel tree rooted at ' +
  'PATH' + #10);
End;

{ ------------------------------------------------------------
  Analyse de la ligne de commande
  ------------------------------------------------------------ }
Procedure AddStr(Var a: TStrArr; Const s: AnsiString);
Begin
 SetLength(a, Length(a) + 1);
 a[High(a)] := s;
End;

Procedure Fail(Const msg: AnsiString);
Begin
 ErrWrite(msg + #10);
 ShowUsage(True);
 ErrWrite('Try `python3 -h'' for more information.' + #10);
 Halt(2);
End;

Procedure ParseCmdLine;
Var
 i, n, k: Integer;
 a, rest: AnsiString;
 c: Char;
 stop: Boolean;

 Function NextArg(Const opt: AnsiString): AnsiString;
 Begin
  If i + 1 > n Then Begin
   ErrWrite('Argument expected for the ' + opt + ' option' + #10);
   ShowUsage(True);
   ErrWrite('Try `python3 -h'' for more information.' + #10);
   Halt(2);
  End;
  Inc(i);
  Result := ParamStr(i);
 End;

Begin
 FillChar(Opts, SizeOf(Opts), 0);
 n := ParamCount;
 i := 1;
 stop := False;
 While (i <= n) And Not stop Do Begin
  a := ParamStr(i);
  If (a = '') Or (a[1] <> '-') Or (a = '-') Then Break;
  If a = '--' Then Begin
   Inc(i);
   Break;
  End;
  If (Length(a) > 1) And (a[2] = '-') Then Begin
   If a = '--help' Then Opts.optH := True
   Else If a = '--version' Then Inc(Opts.optVersion)
   Else If a = '--help-env' Then Opts.helpEnv := True
   Else If a = '--help-xoptions' Then Opts.helpX := True
   Else If a = '--help-all' Then Opts.helpAll := True
   Else If a = '--check-hash-based-pycs' Then Opts.checkHash := NextArg(a)
   Else If Copy(a, 1, 24) = '--check-hash-based-pycs=' Then
    Opts.checkHash := Copy(a, 25, 20)
   Else Fail('Unknown option: ' + a);
   Inc(i);
   Continue;
  End;
  k := 2;
  While k <= Length(a) Do Begin
   c := a[k];
   Case c Of
    'b': Begin
      If Opts.optB Then Opts.optBB := True;
      Opts.optB := True;
     End;
    'B': Opts.optBytecode := True;
    'd': Opts.optD := True;
    'E': Opts.optE := True;
    'h', '?': Opts.optH := True;
    'i': Opts.optI := True;
    'I': Begin
      Opts.optIso := True;
      Opts.optE := True;
      Opts.optS := True;
     End;
    'O': Inc(Opts.optOptimize);
    'q': Opts.optQ := True;
    's': Opts.optS := True;
    'S': Opts.optSS := True;
    'u': Opts.optU := True;
    'v': Inc(Opts.optVerbose);
    'V': Inc(Opts.optVersion);
    'x': Opts.optX := True;
    'P': Opts.optP := True;
    'c', 'm', 'W', 'X': Begin
      rest := Copy(a, k + 1, Length(a));
      If rest = '' Then rest := NextArg('-' + c);
      Case c Of
       'c': Begin
         Opts.cmd := rest;
         Opts.hasCmd := True;
         stop := True;
        End;
       'm': Begin
         Opts.modName := rest;
         Opts.hasMod := True;
         stop := True;
        End;
       'W': AddStr(Opts.warn, rest);
       'X': AddStr(Opts.xopts, rest);
      End;
      k := Length(a);
     End;
   Else
    Fail('Unknown option: -' + c);
   End;
   Inc(k);
  End;
  Inc(i);
 End;
 { script ou arguments }
 If Not (Opts.hasCmd Or Opts.hasMod) And (i <= n) Then Begin
  Opts.script := ParamStr(i);
  Opts.hasScript := True;
  Inc(i);
 End;
 While i <= n Do Begin
  AddStr(Opts.args, ParamStr(i));
  Inc(i);
 End;
End;

Procedure ApplyEnvironment;
Var
 s: AnsiString;
Begin
 If Opts.optE Then Exit;
 If GetEnv('PYTHONINSPECT') <> '' Then Opts.optI := True;
 If GetEnv('PYTHONUNBUFFERED') <> '' Then Opts.optU := True;
 If GetEnv('PYTHONDONTWRITEBYTECODE') <> '' Then Opts.optBytecode := True;
 If GetEnv('PYTHONDEBUG') <> '' Then Opts.optD := True;
 If GetEnv('PYTHONNOUSERSITE') <> '' Then Opts.optS := True;
 s := GetEnv('PYTHONOPTIMIZE');
 If (s <> '') And (Opts.optOptimize = 0) Then
  Opts.optOptimize := StrToIntDef(s, 1);
 s := GetEnv('PYTHONVERBOSE');
 If (s <> '') And (Opts.optVerbose = 0) Then
  Opts.optVerbose := StrToIntDef(s, 1);
 s := GetEnv('PYTHONWARNINGS');
 If s <> '' Then AddStr(Opts.warn, s);
End;

Procedure SetupSysPath;
Var
 l: TPyList;
 s, p: AnsiString;
 i, k: Integer;
Begin
 l := SysPathList;
 l.Clear;
 { PYTHONPATH }
 If Not Opts.optE Then Begin
  s := GetEnv('PYTHONPATH');
  While s <> '' Do Begin
   k := Pos(':', s);
   If k = 0 Then Begin
    p := s;
    s := '';
   End
   Else Begin
    p := Copy(s, 1, k - 1);
    s := Copy(s, k + 1, Length(s));
   End;
   If p <> '' Then l.Add(VStr(p));
  End;
 End;
 l.Add(VStr('/usr/lib/python3.8'));
 l.Add(VStr('/usr/lib/python3.8/lib-dynload'));
 If Not Opts.optIso Then
  If Not Opts.optP Then Begin
   If Opts.hasScript And (Opts.script <> '-') Then
    l.Insert(0, VStr(ScriptDir))
   Else If Opts.hasMod Then l.Insert(0, VStr(GetCurrentDir))
   Else l.Insert(0, VStr(''));
  End;
 i := 0;
End;

Procedure SetupSysExtras;
Var
 d: TPyDict;
 l, w, x: TPyList;
 i, p: Integer;
 xd: TPyDict;
 fl: TPyTuple;
Begin
 d := SysDict;
 d.SetS('executable', VStr(ParamStr(0)));
 d.SetS('_base_executable', VStr(ParamStr(0)));
 d.SetS('dont_write_bytecode', VBool(True));
 w := TPyList(d.ent[d.FindS('warnoptions', HashBytes('warnoptions'))].val.o);
 For i := 0 To High(Opts.warn) Do w.Add(VStr(Opts.warn[i]));
 xd := TPyDict(d.ent[d.FindS('_xoptions', HashBytes('_xoptions'))].val.o);
 For i := 0 To High(Opts.xopts) Do Begin
  p := Pos('=', Opts.xopts[i]);
  If p > 0 Then xd.SetItem(VStr(Copy(Opts.xopts[i], 1, p - 1)),
   VStr(Copy(Opts.xopts[i], p + 1, Length(Opts.xopts[i]))))
  Else xd.SetItem(VStr(Opts.xopts[i]), vTrue);
 End;
 fl := NewTuple(15);
 fl.items[0] := VInt(Ord(Opts.optD));
 fl.items[1] := VInt(Ord(Opts.optI));
 fl.items[2] := VInt(Ord(InteractiveMode));
 fl.items[3] := VInt(Opts.optOptimize);
 fl.items[4] := VInt(Ord(Opts.optBytecode));
 fl.items[5] := VInt(Ord(Opts.optS));
 fl.items[6] := VInt(Ord(Opts.optSS));
 fl.items[7] := VInt(Ord(Opts.optE));
 fl.items[8] := VInt(Opts.optVerbose);
 fl.items[9] := VInt(Ord(Opts.optB) + Ord(Opts.optBB));
 fl.items[10] := VInt(Ord(Opts.optQ));
 fl.items[11] := VInt(1);
 fl.items[12] := VInt(Ord(Opts.optIso));
 fl.items[13] := VInt(0);
 fl.items[14] := VInt(0);
 d.SetS('_flags_tuple', VObj(fl));
 x := NewList;
 l := x;
End;

Function FindScriptFile(Const path: AnsiString; Var src: AnsiString;
 Var realName: AnsiString): Integer;
{ 0 ok, sinon code d'erreur }
Begin
 realName := path;
 If DirectoryExists(path) Then Begin
  If FileExists(JoinPath(path, '__main__.py')) Then Begin
   ReadWholeFile(JoinPath(path, '__main__.py'), src);
   ScriptDir := ExpandFileName(path);
   Result := 0;
   Exit;
  End;
  Result := 21;
  Exit;
 End;
 If Not FileExists(path) Then Begin
  Result := 2;
  Exit;
 End;
 If Not ReadWholeFile(path, src) Then Begin
  Result := 13;
  Exit;
 End;
 Result := 0;
End;

Function RunModuleAsMain(Const name: AnsiString): Integer;
Var
 m: TPyModule;
 src, fname: AnsiString;
 idx, i: Integer;
 dirs: TValArr;
 base, leaf, p: AnsiString;
 found: Boolean;
 code: TPyCode;
 d: TPyDict;
Begin
 Result := 0;
 src := '';
 found := False;
 leaf := name;
 idx := SrcMods.IndexOf(name);
 If idx >= 0 Then Begin
  src := TModSrc(Pointer(SrcMods.Objects[idx]))();
  fname := '<frozen ' + name + '>';
  found := True;
 End
 Else If SrcMods.IndexOf(name + '.__main__') >= 0 Then Begin
  src := TModSrc(Pointer(SrcMods.Objects[SrcMods.IndexOf(name +
   '.__main__')]))();
  fname := '<frozen ' + name + '.__main__>';
  found := True;
 End
 Else Begin
  dirs := IterToArr(VObj(SysPathList));
  For i := 0 To High(dirs) Do Begin
   base := StrOf(dirs[i]);
   If base = '' Then base := '.';
   p := base + '/' + StringReplace(name, '.', '/', [rfReplaceAll]);
   If FileExists(p + '.py') Then Begin
    ReadWholeFile(p + '.py', src);
    fname := p + '.py';
    found := True;
    Break;
   End;
   If FileExists(p + '/__main__.py') Then Begin
    ReadWholeFile(p + '/__main__.py', src);
    fname := p + '/__main__.py';
    found := True;
    Break;
   End;
  End;
 End;
 If Not found Then Begin
  ErrWrite(ParamStr(0) + ': No module named ' + name + #10);
  Result := 1;
  Exit;
 End;
 If Pos('.', name) > 0 Then Begin
  Try
   ImportByName(Copy(name, 1, LastDelimiter('.', name) - 1));
  Except
   On E: EPyError Do Begin
    Result := HandleUncaught(E.exc);
    Exit;
   End;
  End;
 End;
 SetSysArgv(fname);
 d := MainDict;
 d.SetS('__file__', VStr(fname));
 d.SetS('__name__', VStr('__main__'));
 d.SetS('__package__', VStr(Copy(name, 1, Max(0, LastDelimiter('.', name) -
  1))));
 m := nil;
 Result := RunSource(src, fname);
 code := Nil;
End;

Procedure MainProgram;
Var
 src, rn, fname: AnsiString;
 rc: Integer;
Begin
 ExitCode := 0;
 InteractiveMode := False;
 ParseCmdLine;
 If Opts.optH Or Opts.helpAll Then Begin
  ShowHelp;
  If Opts.helpAll Then Begin
   OutWrite(#10);
   ShowHelpEnv;
   OutWrite(#10);
   ShowHelpX;
  End;
  Halt(0);
 End;
 If Opts.helpEnv Then Begin
  ShowHelpEnv;
  Halt(0);
 End;
 If Opts.helpX Then Begin
  ShowHelpX;
  Halt(0);
 End;
 If Opts.optVersion >= 2 Then Begin
  OutWrite('Python ' + PY_VERSION + ' ' + PY_BUILD + #10 + PY_COMPILER + #10);
  OutFlush;
  Halt(0);
 End;
 If Opts.optVersion = 1 Then Begin
  OutWrite('Python ' + PY_VERSION + #10);
  OutFlush;
  Halt(0);
 End;
 ApplyEnvironment;
 OptLevel := Opts.optOptimize;
 Unbuffered := Opts.optU;
 VerboseImport := Opts.optVerbose > 0;
 NoSite := Opts.optSS;
 StdinIsTTY := False;
 StdoutIsTTY := False;
 {$IFDEF UNIX}
 StdinIsTTY := IsATTY(0) = 1;
 StdoutIsTTY := IsATTY(1) = 1;
 {$ENDIF}
 ScriptDir := GetCurrentDir;
 If Opts.hasScript And (Opts.script <> '-') Then Begin
  rc := FindScriptFile(Opts.script, src, rn);
  If rc <> 0 Then Begin
   Case rc Of
    2: ErrWrite('python3: can''t open file ''' + Opts.script +
        ''': [Errno 2] No such file or directory' + #10);
    13: ErrWrite('python3: can''t open file ''' + Opts.script +
         ''': [Errno 13] Permission denied' + #10);
    21: ErrWrite('python3: can''t find ''__main__'' module in ''' +
         Opts.script + '''' + #10);
   End;
   Halt(2);
  End;
  If Not DirectoryExists(Opts.script) Then
   ScriptDir := ExtractFileDir(ExpandFileName(Opts.script));
 End;
 InitRuntime;
 If Opts.optI Then InteractiveMode := True;
 SetupSysPath;
 SetupSysExtras;
 GcInit := False;
 ImportByName('site');
 If Opts.hasCmd Then Begin
  SetSysArgv('-c');
  MainDict.SetS('__name__', VStr('__main__'));
  ExitCode := RunSource(Opts.cmd, '<string>');
  If Opts.optI Then RunInteractive;
 End
 Else If Opts.hasMod Then Begin
  ExitCode := RunModuleAsMain(Opts.modName);
  If Opts.optI Then RunInteractive;
 End
 Else If Opts.hasScript And (Opts.script <> '-') Then Begin
  SetSysArgv(Opts.script);
  If Opts.optX Then Begin
   If Pos(#10, src) > 0 Then src := '#' + #10 + Copy(src, Pos(#10, src) + 1,
    Length(src))
   Else src := '';
  End;
  MainDict.SetS('__file__', VStr(Opts.script));
  fname := Opts.script;
  If DirectoryExists(Opts.script) Then fname := Opts.script + '/__main__.py';
  ExitCode := RunSource(src, fname);
  If Opts.optI Then RunInteractive;
 End
 Else Begin
  { stdin }
  If Opts.hasScript Then SetSysArgv('-') Else SetSysArgv('');
  If StdinIsTTY Or Opts.optI Then Begin
   InteractiveMode := True;
   RunInteractive;
  End
  Else Begin
   src := StdinReadAll;
   ExitCode := RunSource(src, '<stdin>');
  End;
 End;
 FinishAndHalt(ExitCode);
End;
Function Src_site: AnsiString;
Var
 s: AnsiString;
Begin
 s := '';
 s := s +
   'import sys'#10;
 s := s +
   'import builtins'#10;
 s := s + #10;
 s := s +
   'def _structseq(name, fields):'#10;
 s := s +
   '    n = len(fields)'#10;
 s := s + #10;
 s := s +
   '    class _S(tuple):'#10;
 s := s +
   '        _fields = tuple(fields)'#10;
 s := s + #10;
 s := s +
   '        def __new__(cls, seq):'#10;
 s := s +
   '            seq = tuple(seq)'#10;
 s := s +
   '            if len(seq) != n:'#10;
 s := s +
   '                raise TypeError(''%s() takes a %d-sequence (%' +
   'd-sequence given)'' % (name, n, len(seq)))'#10;
 s := s +
   '            return tuple.__new__(cls, seq)'#10;
 s := s + #10;
 s := s +
   '        def __repr__(self):'#10;
 s := s +
   '            return name + ''('' + '', ''.join([''%s=%r'' % (f, v) ' +
   'for f, v in zip(self._fields, self)]) + '')'''#10;
 s := s +
   '    for i, f in enumerate(fields):'#10;
 s := s +
   '        setattr(_S, f, property(lambda self, i=i: self[i]))'#10;
 s := s +
   '    _S.__name__ = name.split(''.'')[-1]'#10;
 s := s +
   '    return _S'#10;
 s := s + #10;
 s := s +
   'class _Namespace:'#10;
 s := s +
   '    def __init__(self, **kw):'#10;
 s := s +
   '        self.__dict__.update(kw)'#10;
 s := s + #10;
 s := s +
   '    def __repr__(self):'#10;
 s := s +
   '        return ''namespace('' + '', ''.join([''%s=%r'' % (k, v) fo' +
   'r k, v in self.__dict__.items()]) + '')'''#10;
 s := s + #10;
 s := s +
   'sys.version_info = _structseq(''sys.version_info'', [''major'', ' +
   '''minor'', ''micro'', ''releaselevel'', ''serial''])((3, 8, 10, ''fin' +
   'al'', 0))'#10;
 s := s +
   'sys.flags = _structseq(''sys.flags'', [''debug'', ''inspect'', ''in' +
   'teractive'', ''optimize'', ''dont_write_bytecode'', ''no_user_site' +
   ''', ''no_site'', ''ignore_environment'', ''verbose'', ''bytes_warnin' +
   'g'', ''quiet'', ''hash_randomization'', ''isolated'', ''dev_mode'', ''' +
   'utf8_mode''])(sys._flags_tuple)'#10;
 s := s +
   'sys.float_info = _structseq(''sys.float_info'', [''max'', ''max_e' +
   'xp'', ''max_10_exp'', ''min'', ''min_exp'', ''min_10_exp'', ''dig'', ''m' +
   'ant_dig'', ''epsilon'', ''radix'', ''rounds''])((1.7976931348623157' +
   'e+308, 1024, 308, 2.2250738585072014e-308, -1021, -307, 15, ' +
   '53, 2.220446049250313e-16, 2, 1))'#10;
 s := s +
   'sys.int_info = _structseq(''sys.int_info'', [''bits_per_digit'',' +
   ' ''sizeof_digit''])((30, 4))'#10;
 s := s +
   'sys.hash_info = _structseq(''sys.hash_info'', [''width'', ''modul' +
   'us'', ''inf'', ''nan'', ''imag''])((64, 2305843009213693951, 314159' +
   ', 0, 1000003))'#10;
 s := s +
   'sys.implementation = _Namespace(name=''cpython'', version=sys.' +
   'version_info, hexversion=sys.hexversion, cache_tag=None)'#10;
 s := s +
   'sys._structseq = _structseq'#10;
 s := s +
   'sys._Namespace = _Namespace'#10;
 s := s + #10;
 s := s +
   'class _Quitter:'#10;
 s := s +
   '    def __init__(self, name):'#10;
 s := s +
   '        self.name = name'#10;
 s := s + #10;
 s := s +
   '    def __repr__(self):'#10;
 s := s +
   '        return ''Use %s() or Ctrl-D (i.e. EOF) to exit'' % sel' +
   'f.name'#10;
 s := s + #10;
 s := s +
   '    def __call__(self, code=None):'#10;
 s := s +
   '        raise SystemExit(code)'#10;
 s := s + #10;
 s := s +
   'class _Printer:'#10;
 s := s +
   '    def __init__(self, name, data):'#10;
 s := s +
   '        self.__name = name'#10;
 s := s +
   '        self.__data = data'#10;
 s := s + #10;
 s := s +
   '    def __repr__(self):'#10;
 s := s +
   '        return self.__data'#10;
 s := s + #10;
 s := s +
   '    def __call__(self):'#10;
 s := s +
   '        print(self.__data)'#10;
 s := s + #10;
 s := s +
   'builtins.exit = _Quitter(''exit'')'#10;
 s := s +
   'builtins.quit = _Quitter(''quit'')'#10;
 s := s +
   'builtins.copyright = _Printer(''copyright'', ''Copyright (c) 20' +
   '26 Sylvain Maltais.\nAll Rights Reserved.'')'#10;
 s := s +
   'builtins.credits = _Printer(''credits'', ''    Thanks to CWI, C' +
   'NRI, BeOpen.com, Zope Corporation and a cast of thousands\n ' +
   '   for supporting Python development.  See www.python.org fo' +
   'r more information.'')'#10;
 s := s +
   'builtins.license = _Printer(''license'', ''Type license() to se' +
   'e the full license text'')'#10;
 s := s + #10;
 Result := s;
End;

Procedure RegisterPrelude;
Begin
  RegSource('site', @Src_site);
End;

Begin
 InstallSignals;
 MainProgram;
End.
