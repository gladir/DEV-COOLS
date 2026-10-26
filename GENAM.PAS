{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Clone de Devpac GenAm (HiSoft) pour Commodore Amiga.
                Assembleur Motorola 68000 a 68060, coprocesseurs flottants
                68881/68882 et MMU (68851, 68030, 68040),
                  produisant des fichiers
                au format AmigaOS Hunk : executable (par defaut) ou objet
                linkable (option -L ou OPT L+).
                Syntaxe : genam [options] source.s
  @license: MIT
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Source    : pile de sources (fichier, INCLUDE, macro, REPT)              }
{  2. Lexeur    : decoupage de ligne (etiquette, mnemonique, operandes)        }
{  3. Expressions : evaluation avec relocation (section) et externes (XREF)    }
{  4. Operandes : analyse des 14 modes 68000 + modes complets du 68020         }
{  5. Encodage  : instructions 68000-68040, FPU 68881/2, MMU, directives       }
{  6. Passes    : assemblage multi-passes jusqu'a stabilisation des tailles    }
{                 (branches .S/.W, optimisations O/O1/O2/A)                    }
{  7. Sortie    : HUNK_HEADER (executable) ou HUNK_UNIT/HUNK_EXT (objet),      }
{                 listing optionnel, table des symboles                        }
{                                                                              }
{  Directives OPT : A C C<n> D L M O O1 O2 P S T W X   (suffixe + ou -)       }
{  Seule l'unite DOS est utilisee.                                             }
{ ---------------------------------------------------------------------------- }

Program GENAM;

{$A-}
{$I-}
{$R-}
{$Q-}
{$H-}

Uses DOS;

Const
 GENAM_VERSION = '1.00';

 MAX_SYM     = 65536;
 HASH_SIZE   = 16384;
 MAX_SECT    = 64;
 MAX_MACRO   = 1024;
 MAX_SRC     = 40;
 MAX_COND    = 64;
 MAX_INCP    = 32;
 MAX_ERRORS  = 100;
 MAX_PASS    = 40;
 MAX_ARGS    = 36;
 MAX_LISTB   = 6;

 { Types de section }
 ST_CODE = 0;
 ST_DATA = 1;
 ST_BSS  = 2;

 { Memoire des hunks }
 MEM_ANY  = 0;
 MEM_CHIP = 1;
 MEM_FAST = 2;

 { Identifiants du format Hunk }
 HUNK_UNIT    = $3E7;
 HUNK_NAME    = $3E8;
 HUNK_CODE    = $3E9;
 HUNK_DATA    = $3EA;
 HUNK_BSS     = $3EB;
 HUNK_RELOC32 = $3EC;
 HUNK_EXT     = $3EF;
 HUNK_SYMBOL  = $3F0;
 HUNK_DEBUG   = $3F1;
 HUNK_END     = $3F2;
 HUNK_HEADER  = $3F3;

 EXT_DEF   = 1;
 EXT_ABS   = 2;
 EXT_REF32 = 129;
 EXT_REF16 = 131;

 { Genres de symboles }
 SK_NONE    = 0;
 SK_LABEL   = 1;
 SK_EQU     = 2;
 SK_SET     = 3;
 SK_EQUR    = 4;
 SK_REGLIST = 5;
 SK_XREF    = 6;

 { Genres de sources }
 SRC_FILE  = 0;
 SRC_MACRO = 1;
 SRC_REPT  = 2;

 { Processeurs }
 CPU_68000 = 0;
 CPU_68010 = 1;
 CPU_68020 = 2;
 CPU_68030 = 3;
 CPU_68040 = 4;
 CPU_68060 = 5;

 { Genres d'operandes }
 OK_NONE = 0;
 OK_DN   = 1;
 OK_AN   = 2;
 OK_IND  = 3;
 OK_POST = 4;
 OK_PRE  = 5;
 OK_DISP = 6;
 OK_IDX  = 7;
 OK_ABS  = 8;   { adresse absolue, taille non encore choisie }
 OK_ABSW = 9;
 OK_ABSL = 10;
 OK_PCD  = 11;
 OK_PCI  = 12;
 OK_IMM  = 13;
 OK_SR   = 14;
 OK_CCR  = 15;
 OK_USP  = 16;
 OK_LIST = 17;
 OK_CTRL = 18;
 OK_FULL = 19;  { 68020 : format d'extension complet (An/PC de base) }
 OK_FPREG = 20; { registre FPn }
 OK_FPLIST = 21; { liste de registres FP (FMOVEM) }
 OK_FPCR = 22;  { registres de controle FPCR/FPSR/FPIAR (masque) }
 OK_MMUREG = 23; { registre MMU (PMOVE) }
 OK_CACHE = 24; { specificateur de cache (CINV/CPUSH) }

 { Masques de modes autorises }
 M_DN   = $0001;
 M_AN   = $0002;
 M_IND  = $0004;
 M_POST = $0008;
 M_PRE  = $0010;
 M_DISP = $0020;
 M_IDX  = $0040;
 M_ABSW = $0080;
 M_ABSL = $0100;
 M_PCD  = $0200;
 M_PCI  = $0400;
 M_IMM  = $0800;

 M_MEMALT  = M_IND or M_POST or M_PRE or M_DISP or M_IDX or M_ABSW or M_ABSL;
 M_DATALT  = M_DN or M_MEMALT;
 M_ALT     = M_DATALT or M_AN;
 M_CONTROL = M_IND or M_DISP or M_IDX or M_ABSW or M_ABSL or M_PCD or M_PCI;
 M_DATA    = M_DN or M_IND or M_POST or M_PRE or M_DISP or M_IDX or M_ABSW or
             M_ABSL or M_PCD or M_PCI or M_IMM;
 M_ALL     = M_DATA or M_AN;

Type
 PByteArr = ^TByteArr;
 TByteArr = Array[0..0] of Byte;

 TVal = Record
  v:Longint;
  sect:Longint;      { -1 absolu, >=0 section, -2 externe }
  ext:Longint;       { index du symbole externe si sect=-2 }
  fwd:Boolean;       { depend d'un symbole defini plus loin }
  undef:Boolean;     { depend d'un symbole non defini }
 End;

 TReloc = Record
  off,tgt:Longint;
 End;
 PRelocArr = ^TRelocArr;
 TRelocArr = Array[0..0] of TReloc;

 TXRef = Record
  sym,off:Longint;
  typ:Byte;
 End;
 PXRefArr = ^TXRefArr;
 TXRefArr = Array[0..0] of TXRef;

 TLineEnt = Record
  off,line:Longint;
 End;
 PLineArr = ^TLineArr;
 TLineArr = Array[0..0] of TLineEnt;

 TSection = Record
  name:String[40];
  kind,mem:Byte;
  data:PByteArr;
  cap,size:Longint;
  rel:PRelocArr;
  nrel,caprel:Longint;
  xr:PXRefArr;
  nxr,capxr:Longint;
  ln:PLineArr;
  nln,capln:Longint;
 End;

 TSym = Record
  name:String[95];
  orig:String[95];
  v,sect:Longint;
  kind:Byte;
  defpass,refpass,refline,reffile:Longint;
  xdef,islocal:Boolean;
  next:Longint;
 End;

 PLine = ^TLine;
 TLine = Record
  next:PLine;
  s:String;
 End;

 TMacro = Record
  name:String[40];
  first,last:PLine;
  nlines:Longint;
  defpass:Longint;
 End;

 TSrc = Record
  kind:Byte;
  f:Text;
  isopen:Boolean;
  buf:Pointer;
  name:String[127];
  dir:String[127];
  fid:Longint;
  line:Longint;
  cur,first:PLine;
  count:Longint;
  narg,uniq,condBase:Longint;
  ext:String[8];
  macname:String[40];
  args:Array[0..MAX_ARGS] of String[200];
 End;

 TOpts = Record
  a,c,d,l,m,o,o1,o2,p,s,t,w,x:Boolean;
  cn:Longint;
 End;

 TOp = Record
  kind:Byte;
  reg:Longint;          { numero de registre : Dn/An ou base 0..7 }
  xreg:Longint;         { registre d'index 0..15 (An = 8..15), -1 = aucun }
  xlong:Boolean;
  xscale:Longint;       { 0..3 }
  val:TVal;             { deplacement, adresse absolue ou valeur immediate }
  absSize:Byte;         { taille forcee : 0 aucune, 2 .W, 4 .L }
  mask:Longint;         { liste de registres }
  { format complet 68020 }
  hasBd,hasOd:Boolean;
  bd,od:TVal;
  bdSize,odSize:Byte;   { 0 auto, 2 mot, 4 long }
  baseSup,idxSup:Boolean;
  memInd:Byte;          { 0 aucun, 1 pre, 2 post, 3 sans index }
  baseIsPC:Boolean;
  { champ de bits }
  hasBF:Boolean;
  bfOffReg,bfWidReg:Boolean;
  bfOff,bfWid:Longint;
  { paire Dn:Dn }
  hasPair:Boolean;
  pair:Longint;
  ctrl:Longint;
  { coprocesseur flottant }
  hasFloat:Boolean;
  fval:Extended;
  ftext:String[48];
  hasK,kIsReg:Boolean;
  kVal:Longint;
 End;

Var
 Language:Integer;

 { Options }
 opt,optDef:TOpts;
 cpu:Integer;
 fpuFlag,mmuFlag:Boolean;
 gSpecial:Integer;   { 1 : noms de registres MMU, 2 : noms de caches }
 cmdOutName,cmdListName,srcName:String;
 cmdList,cmdQuiet:Boolean;
 incPath:Array[1..MAX_INCP] of String;
 nIncPath:Longint;
 cmdDefs:Array[1..32] of String;
 cmdDefVal:Array[1..32] of Longint;
 nCmdDef:Longint;

 { Passes }
 pass:Longint;
 final:Boolean;
 symChanged,siteChanged:Boolean;
 errors,warnings:Longint;
 endSeen:Boolean;

 { Symboles }
 syms:Array[0..MAX_SYM-1] of TSym;
 nsym:Longint;
 hashTab:Array[0..HASH_SIZE-1] of Longint;
 lastGlobal:String[63];
 keyedC,caseInsSeen:Boolean;
 keyedCn:Longint;

 { Macros }
 macros:Array[0..MAX_MACRO-1] of TMacro;
 nmacro:Longint;
 uniqCount:Longint;

 { Sections }
 sec:Array[0..MAX_SECT-1] of TSection;
 nsec:Longint;
 cursec:Longint;
 inOffset:Boolean;
 offPC:Longint;
 orgMode:Boolean;
 orgAddr:Longint;
 rsCnt,foCnt:Longint;

 { Sites d'optimisation (tailles collantes) }
 sites:PByteArr;
 siteCap,sitePos:Longint;

 { Sources }
 src:Array[0..MAX_SRC] of TSrc;
 srcTop:Longint;
 curLineText:String;
 mainFileName:String;
 errThisLine:Boolean;
 fileNames:Array[0..127] of String[127];
 nFileNames:Longint;

 { Conditionnels }
 condCur,condTaken,condParent:Array[0..MAX_COND] of Boolean;
 condDepth:Longint;

 { Blocs en collecte (MACRO / REPT) }
 colKind:Integer;           { 0 aucun, 1 macro, 2 rept }
 colDepth:Longint;
 colFirst,colLast:PLine;
 colName:String[40];
 colCount:Longint;
 colLines:Longint;

 { Analyse de ligne / expressions }
 LP:String;
 LPOS:Longint;
 exprErr:Boolean;

 { Listing }
 listFile:Text;
 listOpen:Boolean;
 listOn:Boolean;
 listTitle,listSub:String;
 listPage,listLineNo,listPLen:Longint;
 lineStartPC,lineStartSec:Longint;
 lineHasCode:Boolean;
 lstLine,lstKind:Longint;

 { Sortie }
 outBuf:PByteArr;
 outCap,outLen:Longint;
 totalErrCount:Longint;

{ ------------------------------------------------------------------------ }
{ Utilitaires generaux                                                      }
{ ------------------------------------------------------------------------ }

Function Tr(Const fr,en:String):String;
Begin
 If Language=1 Then Tr:=en Else Tr:=fr;
End;

Function UpStr(Const s:String):String;
Var
 i:Longint;
 r:String;
Begin
 r:=s;
 For i:=1 to Length(r) do If r[i] in ['a'..'z'] Then r[i]:=Chr(Ord(r[i])-32);
 UpStr:=r;
End;

Function IsIdStart(c:Char):Boolean;
Begin
 IsIdStart:=c in ['A'..'Z','a'..'z','_','.'];
End;

Function IsIdChar(c:Char):Boolean;
Begin
 IsIdChar:=c in ['A'..'Z','a'..'z','0'..'9','_','$'];
End;

Function IsDigit(c:Char):Boolean;
Begin
 IsDigit:=c in ['0'..'9'];
End;

Function IsHexDigit(c:Char):Boolean;
Begin
 IsHexDigit:=c in ['0'..'9','A'..'F','a'..'f'];
End;

Function HexVal(c:Char):Longint;
Begin
 If c in ['0'..'9'] Then HexVal:=Ord(c)-48 Else
 If c in ['A'..'F'] Then HexVal:=Ord(c)-55 Else HexVal:=Ord(c)-87;
End;

Function HexStr(v:Longint;n:Integer):String;
Const
 Digits:String[16]='0123456789ABCDEF';
Var
 s:String;
 i:Integer;
Begin
 s:='';
 For i:=n-1 downto 0 do s:=s+Digits[((v shr (i*4)) and 15)+1];
 HexStr:=s;
End;

Function IntStr(v:Longint):String;
Var
 s:String;
Begin
 Str(v,s);
 IntStr:=s;
End;

Function Fmt(Const s:String;w:Integer):String;
Var
 r:String;
Begin
 r:=s;
 While Length(r)<w do r:=r+' ';
 Fmt:=r;
End;

Function RFmt(Const s:String;w:Integer):String;
Var
 r:String;
Begin
 r:=s;
 While Length(r)<w do r:=' '+r;
 RFmt:=r;
End;

Function BaseName(Const s:String):String;
Var
 i:Integer;
Begin
 i:=Length(s);
 While(i>0)and Not(s[i] in ['/','\',':'])do Dec(i);
 BaseName:=Copy(s,i+1,255);
End;

Function DirName(Const s:String):String;
Var
 i:Integer;
Begin
 i:=Length(s);
 While(i>0)and Not(s[i] in ['/','\',':'])do Dec(i);
 DirName:=Copy(s,1,i);
End;

Function StripExt(Const s:String):String;
Var
 i:Integer;
Begin
 i:=Length(s);
 While(i>0)and Not(s[i] in ['/','\',':','.'])do Dec(i);
 If(i>0)and(s[i]='.')Then StripExt:=Copy(s,1,i-1) Else StripExt:=s;
End;

Function FileExists(Const n:String):Boolean;
Var
 sr:SearchRec;
Begin
 FindFirst(n,AnyFile and Not Directory,sr);
 FileExists:=DosError=0;
 FindClose(sr);
End;

Function DirExists(Const n:String):Boolean;
Var
 sr:SearchRec;
 p:String;
Begin
 p:=n;
 While(Length(p)>1)and(p[Length(p)] in ['/','\'])do Dec(p[0]);
 FindFirst(p,Directory,sr);
 DirExists:=(DosError=0)and((sr.Attr and Directory)<>0);
 FindClose(sr);
End;

{ Recherche d'un nom de fichier sans tenir compte de la casse (les sources
  Amiga melangent souvent majuscules et minuscules). }
Function FindCI(Const dir,name:String):String;
Var
 sr:SearchRec;
 u:String;
Begin
 FindCI:='';
 If name='' Then Exit;
 u:=UpStr(name);
 If dir='' Then FindFirst('*',AnyFile,sr) Else FindFirst(dir+'*',AnyFile,sr);
 While DosError=0 do Begin
  If UpStr(sr.Name)=u Then Begin
   FindCI:=sr.Name;
   Break;
  End;
  FindNext(sr);
 End;
 FindClose(sr);
End;

{ Resout "a/b/c.i" a partir de base en ignorant la casse des composants }
Function ResolvePath(Const base,rel:String):String;
Var
 cur,part,r:String;
 i:Integer;
 found:String;
 isLast:Boolean;
Begin
 ResolvePath:='';
 r:=rel;
 For i:=1 to Length(r) do If r[i]='\' Then r[i]:='/';
 If FileExists(base+r)Then Begin ResolvePath:=base+r;Exit;End;
 cur:=base;
 While r<>'' do Begin
  i:=Pos('/',r);
  If i=0 Then Begin part:=r;r:='';isLast:=True;End
         Else Begin part:=Copy(r,1,i-1);r:=Copy(r,i+1,255);isLast:=(r='');End;
  If(part='')or(part='.')Then Continue;
  If part='..' Then Begin cur:=cur+'../';Continue;End;
  found:=FindCI(cur,part);
  If found='' Then Exit;
  If isLast Then Begin
   If FileExists(cur+found)Then ResolvePath:=cur+found;
   Exit;
  End;
  cur:=cur+found+'/';
 End;
End;

{ ------------------------------------------------------------------------ }
{ Messages d'erreur et d'avertissement                                      }
{ ------------------------------------------------------------------------ }

Procedure PrintWhere;
Var
 i:Longint;
 fname:String;
 fline:Longint;
 mname:String;
Begin
 fname:=mainFileName;
 fline:=0;
 mname:='';
 i:=srcTop;
 While i>=0 do Begin
  If src[i].kind=SRC_FILE Then Begin
   fname:=src[i].name;
   fline:=src[i].line;
   Break;
  End Else If mname='' Then mname:=src[i].macname;
  Dec(i);
 End;
 If fline=0 Then fline:=lstLine;
 Write(fname,'(',fline,')');
 If mname<>'' Then Write(' [',mname,']');
 Write(': ');
End;

Procedure Error(Const msg:String);
Begin
 If Not final Then Begin Inc(errors);Exit;End;
 If errThisLine Then Exit;
 errThisLine:=True;
 Inc(errors);
 PrintWhere;
 WriteLn(Tr('Erreur : ','Error: '),msg);
 If curLineText<>'' Then WriteLn('    ',Copy(curLineText,1,150));
 If errors>=MAX_ERRORS Then Begin
  WriteLn(Tr('Trop d''erreurs, arret de l''assemblage.',
    'Too many errors, assembly aborted.'));
  Halt(10);
 End;
End;

Procedure Warn(Const msg:String);
Begin
 If(Not final)or(Not opt.w)Then Exit;
 Inc(warnings);
 PrintWhere;
 WriteLn(Tr('Avertissement : ','Warning: '),msg);
End;

Procedure Fatal(Const msg:String);
Begin
 WriteLn(Tr('Erreur fatale : ','Fatal error: '),msg);
 Halt(20);
End;

{ ------------------------------------------------------------------------ }
{ Table des symboles                                                        }
{ ------------------------------------------------------------------------ }

Function HashOf(Const s:String):Longint;
Var
 i:Longint;
 h:Longint;
Begin
 h:=5381;
 For i:=1 to Length(s) do h:=((h shl 5)+h+Ord(s[i])) and $7FFFFFF;
 HashOf:=h and (HASH_SIZE-1);
End;

Function SymKey(Const name:String):String;
Var
 k:String;
Begin
 k:=name;
 If opt.cn>0 Then Begin
  { le suffixe d'une etiquette locale n'est pas tronque }
  If(Length(k)>opt.cn)and(Pos(#1,k)=0)Then k:=Copy(k,1,opt.cn);
 End;
 If Not opt.c Then k:=UpStr(k);
 SymKey:=k;
End;

Function FindSym(Const key:String):Longint;
Var
 i:Longint;
Begin
 i:=hashTab[HashOf(key)];
 While i>=0 do Begin
  If syms[i].name=key Then Begin FindSym:=i;Exit;End;
  i:=syms[i].next;
 End;
 FindSym:=-1;
End;

Function AddSym(Const key,origFull:String):Longint;
Var
 h:Longint;
Begin
 If nsym>=MAX_SYM Then Fatal(Tr('Table des symboles pleine',
   'Symbol table full'));
 h:=HashOf(key);
 FillChar(syms[nsym],SizeOf(TSym),0);
 syms[nsym].name:=key;
 syms[nsym].orig:=origFull;
 syms[nsym].kind:=SK_NONE;
 syms[nsym].sect:=-1;
 syms[nsym].next:=hashTab[h];
 syms[nsym].islocal:=Pos(#1,key)>0;
 hashTab[h]:=nsym;
 AddSym:=nsym;
 Inc(nsym);
End;

Function IsLocalName(Const s:String):Boolean;
Begin
 IsLocalName:=(s<>'')and((s[1]='.')or(s[Length(s)]='$'));
End;

{ Nom interne d'un symbole (les etiquettes locales sont rattachees a la
  derniere etiquette globale) }
Function MangleName(Const s:String):String;
Begin
 If IsLocalName(s)Then MangleName:=lastGlobal+#1+s Else MangleName:=s;
End;

Function SymDisplayName(Const s:String):String;
Var
 p:Integer;
Begin
 p:=Pos(#1,s);
 If p>0 Then SymDisplayName:=Copy(s,p+1,255) Else SymDisplayName:=s;
End;

{ Recalcule les cles de tous les symboles (changement de OPT C / C<n>) }
Procedure RekeySyms;
Var
 i,h:Longint;
Begin
 FillChar(hashTab,SizeOf(hashTab),$FF);
 For i:=0 to nsym-1 do Begin
  syms[i].name:=SymKey(syms[i].orig);
  h:=HashOf(syms[i].name);
  syms[i].next:=hashTab[h];
  hashTab[h]:=i;
 End;
 keyedC:=opt.c;
 keyedCn:=opt.cn;
End;

{ ------------------------------------------------------------------------ }
{ Sections et emission du code                                              }
{ ------------------------------------------------------------------------ }

Procedure MkAbs(Var r:TVal;v:Longint);
Begin
 r.v:=v;
 r.sect:=-1;
 r.ext:=0;
 r.fwd:=False;
 r.undef:=False;
End;

Function FindOrAddSection(Const name:String;kind,mem:Byte):Longint;
Var
 i:Longint;
Begin
 For i:=0 to nsec-1 do Begin
  If name<>'' Then Begin
   If UpStr(sec[i].name)=UpStr(name)Then Begin
    If sec[i].kind<>kind Then
     Error(Tr('Section deja definie avec un autre type : ',
       'Section already defined with another type: ')+name);
    FindOrAddSection:=i;
    Exit;
   End;
  End Else If(sec[i].name='')and(sec[i].kind=kind)and(sec[i].mem=mem)Then Begin
   FindOrAddSection:=i;
   Exit;
  End;
 End;
 If nsec>=MAX_SECT Then Fatal(Tr('Trop de sections','Too many sections'));
 FillChar(sec[nsec],SizeOf(TSection),0);
 sec[nsec].name:=name;
 sec[nsec].kind:=kind;
 sec[nsec].mem:=mem;
 FindOrAddSection:=nsec;
 Inc(nsec);
End;

Procedure EnsureSect;
Begin
 If(cursec<0)and Not inOffset Then cursec:=FindOrAddSection('',ST_CODE,MEM_ANY);
End;

Function PC:Longint;
Begin
 If inOffset Then PC:=offPC Else Begin
  EnsureSect;
  PC:=sec[cursec].size;
 End;
End;

Procedure CurLocVal(Var r:TVal);
Begin
 MkAbs(r,0);
 If inOffset Then r.v:=offPC Else Begin
  EnsureSect;
  r.v:=sec[cursec].size;
  r.sect:=cursec;
 End;
End;

Procedure GrowData(n:Longint);
Var
 nc:Longint;
Begin
 With sec[cursec] do Begin
  If size+n>cap Then Begin
   nc:=cap*2;
   If nc<4096 Then nc:=4096;
   While nc<size+n do nc:=nc*2;
   ReAllocMem(data,nc);
   cap:=nc;
  End;
 End;
End;

Procedure EmitB(b:Longint);
Begin
 If inOffset Then Begin
  Error(Tr('Donnees non permises dans une section OFFSET',
    'Data not allowed in an OFFSET section'));
  Inc(offPC);
  Exit;
 End;
 EnsureSect;
 With sec[cursec] do Begin
  If kind=ST_BSS Then Begin
   Error(Tr('Donnees non permises dans une section BSS',
     'Data not allowed in a BSS section'));
   Inc(size);
   Exit;
  End;
  GrowData(1);
  data^[size]:=b and $FF;
  Inc(size);
 End;
End;

Procedure EmitW(w:Longint);
Begin
 EmitB((w shr 8) and $FF);
 EmitB(w and $FF);
End;

Procedure EmitL(l:Longint);
Begin
 EmitW((l shr 16) and $FFFF);
 EmitW(l and $FFFF);
End;

{ Reserve n octets a zero (DS) }
Procedure Reserve(n:Longint);
Var
 i:Longint;
Begin
 If n<=0 Then Exit;
 If inOffset Then Begin Inc(offPC,n);Exit;End;
 EnsureSect;
 If sec[cursec].kind=ST_BSS Then Inc(sec[cursec].size,n)
  Else For i:=1 to n do EmitB(0);
End;

Procedure AlignEven;
Begin
 If(PC and 1)<>0 Then Reserve(1);
End;

Procedure PatchW(secIdx,off,w:Longint);
Begin
 If(secIdx<0)or(sec[secIdx].kind=ST_BSS)Then Exit;
 If off+1>=sec[secIdx].size Then Exit;
 sec[secIdx].data^[off]:=(w shr 8) and $FF;
 sec[secIdx].data^[off+1]:=w and $FF;
End;

Procedure AddReloc(off,tgt:Longint);
Var
 nc:Longint;
Begin
 With sec[cursec] do Begin
  If nrel>=caprel Then Begin
   nc:=caprel*2;
   If nc<256 Then nc:=256;
   ReAllocMem(rel,nc*SizeOf(TReloc));
   caprel:=nc;
  End;
  rel^[nrel].off:=off;
  rel^[nrel].tgt:=tgt;
  Inc(nrel);
 End;
End;

Procedure AddXRef(sym,off:Longint;typ:Byte);
Var
 nc:Longint;
Begin
 With sec[cursec] do Begin
  If nxr>=capxr Then Begin
   nc:=capxr*2;
   If nc<256 Then nc:=256;
   ReAllocMem(xr,nc*SizeOf(TXRef));
   capxr:=nc;
  End;
  xr^[nxr].sym:=sym;
  xr^[nxr].off:=off;
  xr^[nxr].typ:=typ;
  Inc(nxr);
 End;
End;

Procedure AddLineEnt(off,line:Longint);
Var
 nc:Longint;
Begin
 With sec[cursec] do Begin
  If nln>=capln Then Begin
   nc:=capln*2;
   If nc<256 Then nc:=256;
   ReAllocMem(ln,nc*SizeOf(TLineEnt));
   capln:=nc;
  End;
  ln^[nln].off:=off;
  ln^[nln].line:=line;
  Inc(nln);
 End;
End;

Function SectBase(s:Longint):Longint;
Begin
 If orgMode Then SectBase:=orgAddr Else SectBase:=0;
End;

{ Emet un long mot pouvant etre relogeable ou externe }
Procedure EmitLongVal(Const v:TVal);
Begin
 If inOffset Then Begin
  Error(Tr('Donnees non permises dans une section OFFSET',
    'Data not allowed in an OFFSET section'));
  Inc(offPC,4);
  Exit;
 End;
 EnsureSect;
 If v.sect=-2 Then Begin
  AddXRef(v.ext,sec[cursec].size,EXT_REF32);
  EmitL(v.v);
 End Else If v.sect>=0 Then Begin
  If opt.p Then
   Error(Tr('Adresse absolue interdite avec OPT P+',
           'Absolute address not allowed with OPT P+'));
  If orgMode Then EmitL(v.v+SectBase(v.sect)) Else Begin
   AddReloc(sec[cursec].size,v.sect);
   EmitL(v.v);
  End;
 End Else EmitL(v.v);
End;

{ ------------------------------------------------------------------------ }
{ Sites d'optimisation : decisions de taille qui ne peuvent que croitre     }
{ ------------------------------------------------------------------------ }

Function SiteLevel(need:Byte):Byte;
Var
 idx,nc:Longint;
Begin
 idx:=sitePos;
 Inc(sitePos);
 If idx>=siteCap Then Begin
  nc:=siteCap*2;
  If nc<1024 Then nc:=1024;
  ReAllocMem(sites,nc);
  FillChar(sites^[siteCap],nc-siteCap,0);
  siteCap:=nc;
 End;
 If need>sites^[idx]Then Begin
  sites^[idx]:=need;
  siteChanged:=True;
 End;
 SiteLevel:=sites^[idx];
End;

{ ------------------------------------------------------------------------ }
{ Definition et recherche de symboles                                       }
{ ------------------------------------------------------------------------ }

Function CurFileId:Longint;
Var
 i:Longint;
Begin
 CurFileId:=0;
 i:=srcTop;
 While i>=0 do Begin
  If src[i].kind=SRC_FILE Then Begin CurFileId:=src[i].fid;Exit;End;
  Dec(i);
 End;
End;

Function CurFileLine:Longint;
Var
 i:Longint;
Begin
 CurFileLine:=0;
 i:=srcTop;
 While i>=0 do Begin
  If src[i].kind=SRC_FILE Then Begin CurFileLine:=src[i].line;Exit;End;
  Dec(i);
 End;
End;

Procedure DefineSymbol(Const name:String;Const v:TVal;kind:Byte);
Var
 key:String;
 i:Longint;
Begin
 key:=SymKey(MangleName(name));
 i:=FindSym(key);
 If i<0 Then i:=AddSym(key,MangleName(name));
 If syms[i].kind=SK_XREF Then Begin
  Error(Tr('Symbole externe redefini localement : ',
    'External symbol redefined locally: ')+name);
  Exit;
 End;
 If(kind<>SK_SET)and(syms[i].defpass=pass)and(syms[i].kind<>SK_NONE)Then Begin
  Error(Tr('Symbole deja defini : ','Symbol already defined: ')+name);
  Exit;
 End;
 If(kind<>SK_SET)and((syms[i].defpass=0)or(syms[i].v<>v.v)
   or(syms[i].sect<>v.sect)or
    (syms[i].kind<>kind))Then symChanged:=True;
 syms[i].v:=v.v;
 syms[i].sect:=v.sect;
 syms[i].kind:=kind;
 syms[i].defpass:=pass;
End;

Procedure DefineLabel(Const name:String);
Var
 v:TVal;
Begin
 CurLocVal(v);
 DefineSymbol(name,v,SK_LABEL);
 If Not IsLocalName(name)Then lastGlobal:=name;
End;

Function LookupSymIdx(Const name:String):Longint;
Var
 key:String;
 i:Longint;
Begin
 key:=SymKey(MangleName(name));
 i:=FindSym(key);
 If i<0 Then i:=AddSym(key,MangleName(name));
 LookupSymIdx:=i;
End;

{ ------------------------------------------------------------------------ }
{ Analyse d'expressions                                                     }
{ ------------------------------------------------------------------------ }

Procedure SkipSp;
Begin
 While(LPOS<=Length(LP))and(LP[LPOS] in [' ',#9])do Inc(LPOS);
End;

Function PeekCh:Char;
Begin
 If LPOS<=Length(LP)Then PeekCh:=LP[LPOS] Else PeekCh:=#0;
End;

Function PeekCh2:Char;
Begin
 If LPOS+1<=Length(LP)Then PeekCh2:=LP[LPOS+1] Else PeekCh2:=#0;
End;

Procedure ExprError(Const msg:String);
Begin
 If Not exprErr Then Error(msg);
 exprErr:=True;
End;

Function CurNarg:Longint;
Var
 i:Longint;
Begin
 CurNarg:=0;
 i:=srcTop;
 While i>=0 do Begin
  If src[i].kind=SRC_MACRO Then Begin CurNarg:=src[i].narg;Exit;End;
  Dec(i);
 End;
End;

Procedure Expr(Var r:TVal);Forward;

Procedure NoteRef(i:Longint);
Begin
 If(syms[i].defpass<>pass)and(syms[i].refpass<>pass)Then Begin
  syms[i].refpass:=pass;
  syms[i].refline:=CurFileLine;
  syms[i].reffile:=CurFileId;
 End;
End;

Procedure PrimarySymbol(Var r:TVal);
Var
 st:Longint;
 name,up:String;
 i:Longint;
Begin
 st:=LPOS;
 Inc(LPOS);
 While(LPOS<=Length(LP))and IsIdChar(LP[LPOS])do Inc(LPOS);
 name:=Copy(LP,st,LPOS-st);
 up:=UpStr(name);
 MkAbs(r,0);
 If up='NARG' Then Begin r.v:=CurNarg;Exit;End;
 i:=LookupSymIdx(name);
 NoteRef(i);
 Case syms[i].kind of
  SK_XREF:Begin
   r.sect:=-2;
   r.ext:=i;
  End;
  SK_LABEL,SK_EQU,SK_SET:Begin
   r.v:=syms[i].v;
   r.sect:=syms[i].sect;
   If(syms[i].defpass<>pass)and(syms[i].kind<>SK_SET)Then r.fwd:=True;
  End;
  SK_EQUR,SK_REGLIST:
   ExprError(Tr('Registre utilise dans une expression : ',
     'Register used in an expression: ')+name);
  Else Begin
   r.undef:=True;
   r.fwd:=True;
  End;
 End;
End;

Procedure PrimaryNumber(Var r:TVal);
Var
 c:Char;
 v:Longint;
 n:Longint;
Begin
 MkAbs(r,0);
 c:=PeekCh;
 v:=0;
 n:=0;
 If c='$' Then Begin
  Inc(LPOS);
  While(LPOS<=Length(LP))and IsHexDigit(LP[LPOS])do Begin
   v:=(v shl 4) or HexVal(LP[LPOS]);
   Inc(LPOS);
   Inc(n);
  End;
  If n=0 Then ExprError(Tr('Nombre hexadecimal invalide',
    'Invalid hexadecimal number'));
 End Else If c='%' Then Begin
  Inc(LPOS);
  While(LPOS<=Length(LP))and(LP[LPOS] in ['0','1'])do Begin
   v:=(v shl 1) or (Ord(LP[LPOS])-48);
   Inc(LPOS);
   Inc(n);
  End;
  If n=0 Then ExprError(Tr('Nombre binaire invalide','Invalid binary number'));
 End Else If c='@' Then Begin
  Inc(LPOS);
  While(LPOS<=Length(LP))and(LP[LPOS] in ['0'..'7'])do Begin
   v:=(v shl 3) or (Ord(LP[LPOS])-48);
   Inc(LPOS);
   Inc(n);
  End;
  If n=0 Then ExprError(Tr('Nombre octal invalide','Invalid octal number'));
 End Else Begin
  If(c='0')and(PeekCh2 in ['x','X'])Then Begin
   Inc(LPOS,2);
   While(LPOS<=Length(LP))and IsHexDigit(LP[LPOS])do Begin
    v:=(v shl 4) or HexVal(LP[LPOS]);
    Inc(LPOS);
   End;
  End Else Begin
   While(LPOS<=Length(LP))and IsDigit(LP[LPOS])do Begin
    v:=v*10+(Ord(LP[LPOS])-48);
    Inc(LPOS);
   End;
   If(LPOS<=Length(LP))and IsIdChar(LP[LPOS])Then
    ExprError(Tr('Nombre decimal invalide','Invalid decimal number'));
  End;
 End;
 r.v:=v;
End;

Procedure PrimaryString(Var r:TVal);
Var
 q:Char;
 n:Longint;
 v:Longint;
 closed:Boolean;
Begin
 MkAbs(r,0);
 q:=LP[LPOS];
 Inc(LPOS);
 v:=0;
 n:=0;
 closed:=False;
 While LPOS<=Length(LP) do Begin
  If LP[LPOS]=q Then Begin
   If(LPOS<Length(LP))and(LP[LPOS+1]=q)Then Begin
    v:=(v shl 8) or Ord(q);
    Inc(n);
    Inc(LPOS,2);
   End Else Begin
    Inc(LPOS);
    closed:=True;
    Break;
   End;
  End Else Begin
   v:=(v shl 8) or Ord(LP[LPOS]);
   Inc(n);
   Inc(LPOS);
  End;
 End;
 If Not closed Then ExprError(Tr('Chaine non terminee','Unterminated string'));
 If n>4 Then Warn(Tr('Constante de plus de 4 caracteres tronquee',
   'Constant longer than 4 characters truncated'));
 r.v:=v;
End;

Procedure Primary(Var r:TVal);
Var
 c:Char;
 j:Longint;
 tok:String;
 allDig:Boolean;
Begin
 SkipSp;
 c:=PeekCh;
 MkAbs(r,0);
 If c='(' Then Begin
  Inc(LPOS);
  Expr(r);
  SkipSp;
  If PeekCh=')' Then Inc(LPOS) Else ExprError(Tr('Parenthese fermante attendue',
    'Closing parenthesis expected'));
 End Else If c in ['''','"'] Then PrimaryString(r)
 Else If c='*' Then Begin
  Inc(LPOS);
  CurLocVal(r);
 End Else If(c='$')and Not IsHexDigit(PeekCh2)Then Begin
  { '$' seul : compteur de position (compatibilite) }
  Inc(LPOS);
  CurLocVal(r);
 End Else If c in ['$','%','@'] Then PrimaryNumber(r)
 Else If IsDigit(c)Then Begin
  { etiquette locale du genre 1$ ? }
  j:=LPOS;
  While(j<=Length(LP))and IsIdChar(LP[j])do Inc(j);
  tok:=Copy(LP,LPOS,j-LPOS);
  allDig:=True;
  If(tok<>'')and(tok[Length(tok)]='$')Then Begin
   Dec(tok[0]);
   For j:=1 to Length(tok) do If Not IsDigit(tok[j])Then allDig:=False;
   If allDig Then PrimarySymbol(r) Else PrimaryNumber(r);
  End Else PrimaryNumber(r);
 End Else If IsIdStart(c)Then PrimarySymbol(r)
 Else Begin
  ExprError(Tr('Expression invalide','Invalid expression'));
  If LPOS<=Length(LP)Then Inc(LPOS);
 End;
End;

Procedure Unary(Var r:TVal);
Var
 c:Char;
Begin
 SkipSp;
 c:=PeekCh;
 If c='-' Then Begin
  Inc(LPOS);
  Unary(r);
  If r.sect<>-1 Then Begin
   If Not r.undef Then ExprError(Tr('Negation d''une valeur relogeable',
     'Negation of a relocatable value'));
  End;
  r.v:=-r.v;
 End Else If c='+' Then Begin
  Inc(LPOS);
  Unary(r);
 End Else If c='~' Then Begin
  Inc(LPOS);
  Unary(r);
  If(r.sect<>-1)and Not r.undef
    Then ExprError(Tr('Operation invalide sur une valeur relogeable',
    'Invalid operation on a relocatable value'));
  r.v:=Not r.v;
 End Else Primary(r);
End;

Procedure NeedAbs(Const a,b:TVal);
Begin
 If((a.sect<>-1)or(b.sect<>-1))and Not(a.undef or b.undef)Then
  ExprError(Tr('Operande relogeable invalide pour cet operateur',
    'Invalid relocatable operand for this operator'));
End;

Procedure MulExpr(Var r:TVal);
Var
 b:TVal;
 c:Char;
Begin
 Unary(r);
 While True do Begin
  SkipSp;
  c:=PeekCh;
  If c='*' Then Begin
   Inc(LPOS);
   Unary(b);
   NeedAbs(r,b);
   r.v:=r.v*b.v;
  End Else If(c='/')and(PeekCh2='/')Then Begin
   Inc(LPOS,2);
   Unary(b);
   NeedAbs(r,b);
   If b.v=0 Then Begin
    If Not(b.undef or b.fwd)Then ExprError(Tr('Division par zero',
      'Division by zero'));
   End Else r.v:=r.v mod b.v;
  End Else If c='\' Then Begin
   Inc(LPOS);
   Unary(b);
   NeedAbs(r,b);
   If b.v=0 Then Begin
    If Not(b.undef or b.fwd)Then ExprError(Tr('Division par zero',
      'Division by zero'));
   End Else r.v:=r.v mod b.v;
  End Else If c='/' Then Begin
   Inc(LPOS);
   Unary(b);
   NeedAbs(r,b);
   If b.v=0 Then Begin
    If Not(b.undef or b.fwd)Then ExprError(Tr('Division par zero',
      'Division by zero'));
   End Else r.v:=r.v div b.v;
  End Else Break;
  r.fwd:=r.fwd or b.fwd;
  r.undef:=r.undef or b.undef;
 End;
End;

Procedure AddExpr(Var r:TVal);
Var
 b:TVal;
 c:Char;
 sub:Boolean;
Begin
 MulExpr(r);
 While True do Begin
  SkipSp;
  c:=PeekCh;
  If Not(c in ['+','-'])Then Break;
  sub:=(c='-');
  Inc(LPOS);
  MulExpr(b);
  If sub Then Begin
   If b.sect=-1 Then Begin
    { r reste inchange }
   End Else If(r.sect=b.sect)and(r.sect>=0)Then r.sect:=-1
   Else If Not(r.undef or b.undef)Then
    ExprError(Tr('Soustraction relogeable invalide',
      'Invalid relocatable subtraction'));
   r.v:=r.v-b.v;
  End Else Begin
   If r.sect=-1 Then Begin
    r.sect:=b.sect;
    r.ext:=b.ext;
   End Else If b.sect<>-1 Then Begin
    If Not(r.undef or b.undef)Then
     ExprError(Tr('Addition de deux valeurs relogeables',
       'Addition of two relocatable values'));
   End;
   r.v:=r.v+b.v;
  End;
  r.fwd:=r.fwd or b.fwd;
  r.undef:=r.undef or b.undef;
 End;
End;

Procedure ShiftExpr(Var r:TVal);
Var
 b:TVal;
Begin
 AddExpr(r);
 While True do Begin
  SkipSp;
  If(PeekCh='<')and(PeekCh2='<')Then Begin
   Inc(LPOS,2);
   AddExpr(b);
   NeedAbs(r,b);
   If(b.v>=0)and(b.v<32)Then r.v:=r.v shl b.v Else r.v:=0;
  End Else If(PeekCh='>')and(PeekCh2='>')Then Begin
   Inc(LPOS,2);
   AddExpr(b);
   NeedAbs(r,b);
   If(b.v>=0)and(b.v<32)Then r.v:=Longint(Cardinal(r.v) shr b.v) Else r.v:=0;
  End Else Break;
  r.fwd:=r.fwd or b.fwd;
  r.undef:=r.undef or b.undef;
 End;
End;

Procedure AndExpr(Var r:TVal);
Var
 b:TVal;
Begin
 ShiftExpr(r);
 While True do Begin
  SkipSp;
  If PeekCh='&' Then Begin
   Inc(LPOS);
   If PeekCh='&' Then Inc(LPOS);
   ShiftExpr(b);
   NeedAbs(r,b);
   r.v:=r.v and b.v;
   r.fwd:=r.fwd or b.fwd;
   r.undef:=r.undef or b.undef;
  End Else Break;
 End;
End;

Procedure OrExpr(Var r:TVal);
Var
 b:TVal;
 c:Char;
Begin
 AndExpr(r);
 While True do Begin
  SkipSp;
  c:=PeekCh;
  If c in ['!','|','^','~'] Then Begin
   Inc(LPOS);
   If(c='|')and(PeekCh='|')Then Inc(LPOS);
   AndExpr(b);
   NeedAbs(r,b);
   If c in ['!','|'] Then r.v:=r.v or b.v Else r.v:=r.v xor b.v;
   r.fwd:=r.fwd or b.fwd;
   r.undef:=r.undef or b.undef;
  End Else Break;
 End;
End;

Procedure Expr(Var r:TVal);
Var
 b:TVal;
 op:Integer;
 res:Boolean;
Begin
 OrExpr(r);
 While True do Begin
  SkipSp;
  op:=0;
  If(PeekCh='<')and(PeekCh2='>')Then Begin op:=1;Inc(LPOS,2);End
  Else If(PeekCh='<')and(PeekCh2='=')Then Begin op:=5;Inc(LPOS,2);End
  Else If(PeekCh='>')and(PeekCh2='=')Then Begin op:=6;Inc(LPOS,2);End
  Else If(PeekCh='=')and(PeekCh2='=')Then Begin op:=2;Inc(LPOS,2);End
  Else If PeekCh='=' Then Begin op:=2;Inc(LPOS);End
  Else If(PeekCh='<')and(PeekCh2<>'<')Then Begin op:=3;Inc(LPOS);End
  Else If(PeekCh='>')and(PeekCh2<>'>')Then Begin op:=4;Inc(LPOS);End;
  If op=0 Then Break;
  OrExpr(b);
  If(r.sect<>b.sect)and Not(r.undef or b.undef)Then
   ExprError(Tr('Comparaison de valeurs relogeables incompatibles',
     'Comparison of incompatible relocatable values'));
  Case op of
   1:res:=r.v<>b.v;
   2:res:=r.v=b.v;
   3:res:=r.v<b.v;
   4:res:=r.v>b.v;
   5:res:=r.v<=b.v;
   Else res:=r.v>=b.v;
  End;
  r.fwd:=r.fwd or b.fwd;
  r.undef:=r.undef or b.undef;
  r.sect:=-1;
  r.ext:=0;
  If res Then r.v:=1 Else r.v:=0;
 End;
End;

{ Evalue une expression qui doit etre absolue }
Procedure ExprAbs(Var v:Longint);
Var
 r:TVal;
Begin
 exprErr:=False;
 Expr(r);
 If r.sect<>-1 Then Begin
  If Not r.undef Then ExprError(Tr('Expression absolue requise',
    'Absolute expression required'));
 End;
 v:=r.v;
End;

Procedure ExprAbsV(Var r:TVal);
Begin
 exprErr:=False;
 Expr(r);
 If r.sect<>-1 Then Begin
  If Not r.undef Then ExprError(Tr('Expression absolue requise',
    'Absolute expression required'));
  r.sect:=-1;
 End;
End;

{ Evalue une expression complete avec relocation autorisee }
Procedure ExprFull(Var r:TVal);
Begin
 exprErr:=False;
 Expr(r);
End;

{ ------------------------------------------------------------------------ }
{ Pile de sources : fichiers, INCLUDE, macros et REPT                       }
{ ------------------------------------------------------------------------ }

Var
 nCmdInc:Longint;

Function AddFileName(Const n:String):Longint;
Var
 i:Longint;
Begin
 For i:=0 to nFileNames-1 do If fileNames[i]=n Then
   Begin AddFileName:=i;Exit;End;
 If nFileNames<128 Then Begin
  fileNames[nFileNames]:=n;
  AddFileName:=nFileNames;
  Inc(nFileNames);
 End Else AddFileName:=0;
End;

Procedure FreeLines(p:PLine);
Var
 q:PLine;
Begin
 While p<>Nil do Begin
  q:=p^.next;
  Dispose(p);
  p:=q;
 End;
End;

Function PushFile(Const fname:String):Boolean;
Var
 t:Longint;
Begin
 PushFile:=False;
 If srcTop>=MAX_SRC-1 Then Begin
  Error(Tr('Imbrication de sources trop profonde','Source nesting too deep'));
  Exit;
 End;
 t:=srcTop+1;
 FillChar(src[t].args,SizeOf(src[t].args),0);
 src[t].kind:=SRC_FILE;
 src[t].name:=fname;
 src[t].dir:=DirName(fname);
 src[t].fid:=AddFileName(fname);
 src[t].line:=0;
 src[t].cur:=Nil;
 src[t].first:=Nil;
 src[t].macname:='';
 GetMem(src[t].buf,16384);
 Assign(src[t].f,fname);
 SetTextBuf(src[t].f,src[t].buf^,16384);
 Reset(src[t].f);
 If IOResult<>0 Then Begin
  FreeMem(src[t].buf,16384);
  Exit;
 End;
 src[t].isopen:=True;
 srcTop:=t;
 PushFile:=True;
End;

Procedure PopSrc;
Begin
 If srcTop<0 Then Exit;
 With src[srcTop] do Begin
  If kind=SRC_FILE Then Begin
   If isopen Then Close(f);
   isopen:=False;
   If buf<>Nil Then FreeMem(buf,16384);
   buf:=Nil;
  End Else If kind=SRC_REPT Then Begin
   FreeLines(first);
   first:=Nil;
  End Else If kind=SRC_MACRO Then Begin
   If condDepth>condBase Then condDepth:=condBase;
  End;
 End;
 Dec(srcTop);
End;

Function SubstMacro(Const line:String;t:Longint):String;
Var
 res:String;
 i,n,idx:Longint;
 d:Char;
 j:Longint;
 nm:String;
 k:Longint;
Begin
 res:='';
 i:=1;
 n:=Length(line);
 While i<=n do Begin
  If(line[i]='\')and(i<n)Then Begin
   d:=line[i+1];
   If d='@' Then Begin
    res:=res+'_'+IntStr(src[t].uniq);
    Inc(i,2);
   End Else If d='0' Then Begin
    res:=res+src[t].ext;
    Inc(i,2);
   End Else If d in ['1'..'9'] Then Begin
    res:=res+src[t].args[Ord(d)-48];
    Inc(i,2);
   End Else If(d in ['A'..'Z','a'..'z'])and(src[t].narg>=10)Then Begin
    idx:=10+(Ord(UpCase(d))-65);
    If idx<=MAX_ARGS Then res:=res+src[t].args[idx];
    Inc(i,2);
   End Else If d='<' Then Begin
    j:=i+2;
    While(j<=n)and(line[j]<>'>')do Inc(j);
    nm:=Copy(line,i+2,j-i-2);
    k:=LookupSymIdx(nm);
    res:=res+IntStr(syms[k].v);
    i:=j+1;
   End Else Begin
    res:=res+'\';
    Inc(i);
   End;
  End Else Begin
   res:=res+line[i];
   Inc(i);
  End;
 End;
 SubstMacro:=res;
End;

Function NextSrcLine(Var s:String):Boolean;
Var
 t:Longint;
 n:Integer;
Begin
 NextSrcLine:=False;
 While srcTop>=0 do Begin
  t:=srcTop;
  Case src[t].kind of
   SRC_FILE:Begin
    If Not Eof(src[t].f)Then Begin
     ReadLn(src[t].f,s);
     Inc(src[t].line);
     n:=Length(s);
     While(n>0)and(s[n]<' ')and(s[n]<>#9)do Begin Dec(n);Dec(s[0]);End;
     NextSrcLine:=True;
     Exit;
    End;
    PopSrc;
   End;
   SRC_MACRO:Begin
    If src[t].cur<>Nil Then Begin
     s:=SubstMacro(src[t].cur^.s,t);
     src[t].cur:=src[t].cur^.next;
     Inc(src[t].line);
     NextSrcLine:=True;
     Exit;
    End;
    PopSrc;
   End;
   Else Begin
    If src[t].cur<>Nil Then Begin
     s:=src[t].cur^.s;
     src[t].cur:=src[t].cur^.next;
     Inc(src[t].line);
     NextSrcLine:=True;
     Exit;
    End;
    Dec(src[t].count);
    If src[t].count>0 Then src[t].cur:=src[t].first Else PopSrc;
   End;
  End;
 End;
End;

{ Recherche d'un fichier INCLUDE }
Function FindIncludeFile(Const name:String):String;
Var
 nm,nm2,r:String;
 i,p:Longint;
Begin
 FindIncludeFile:='';
 nm:=name;
 For i:=1 to Length(nm) do If nm[i]='\' Then nm[i]:='/';
 nm2:=nm;
 p:=Pos(':',nm);
 If p>0 Then nm2:=Copy(nm,p+1,255);
 If(nm<>'')and(nm[1]='/')Then Begin
  If FileExists(nm)Then FindIncludeFile:=nm;
  Exit;
 End;
 If srcTop>=0 Then Begin
  i:=srcTop;
  While(i>0)and(src[i].kind<>SRC_FILE)do Dec(i);
  r:=ResolvePath(src[i].dir,nm);
  If r<>'' Then Begin FindIncludeFile:=r;Exit;End;
 End;
 r:=ResolvePath('',nm);
 If r<>'' Then Begin FindIncludeFile:=r;Exit;End;
 For i:=nIncPath downto 1 do Begin
  r:=ResolvePath(incPath[i],nm2);
  If r<>'' Then Begin FindIncludeFile:=r;Exit;End;
 End;
End;

{ ------------------------------------------------------------------------ }
{ Macros                                                                    }
{ ------------------------------------------------------------------------ }

Function FindMacro(Const up:String):Longint;
Var
 i:Longint;
Begin
 FindMacro:=-1;
 For i:=0 to nmacro-1 do
  If(macros[i].defpass=pass)and(macros[i].name=up)Then
    Begin FindMacro:=i;Exit;End;
End;

Procedure AppendLine(Var first,last:PLine;Const s:String);
Var
 p:PLine;
Begin
 New(p);
 p^.next:=Nil;
 p^.s:=s;
 If last=Nil Then first:=p Else last^.next:=p;
 last:=p;
End;

Procedure FinishMacro;
Var
 i:Longint;
Begin
 i:=-1;
 For i:=0 to nmacro-1 do If macros[i].name=colName Then Break;
 If(i<0)or(i>=nmacro)or(macros[i].name<>colName)Then Begin
  If nmacro>=MAX_MACRO Then Fatal(Tr('Trop de macros','Too many macros'));
  i:=nmacro;
  Inc(nmacro);
  macros[i].name:=colName;
  macros[i].first:=Nil;
  macros[i].defpass:=0;
 End;
 If macros[i].defpass=pass Then Begin
  Error(Tr('Macro deja definie : ','Macro already defined: ')+colName);
  FreeLines(colFirst);
 End Else Begin
  FreeLines(macros[i].first);
  macros[i].first:=colFirst;
  macros[i].last:=colLast;
  macros[i].nlines:=colLines;
  macros[i].defpass:=pass;
 End;
 colKind:=0;
 colFirst:=Nil;
 colLast:=Nil;
End;

{ Decoupe les arguments d'un appel de macro }
Procedure SplitMacroArgs(Const o:String;Var args:Array of String;Var n:Longint);
Var
 i,len,depth:Longint;
 cur:String;
 q:Char;
 c:Char;
 started:Boolean;
 d2:Longint;
Begin
 n:=0;
 len:=Length(o);
 i:=1;
 While(i<=len)and(o[i] in [' ',#9])do Inc(i);
 If(i>len)or(o[i]=';')Then Exit;
 cur:='';
 depth:=0;
 started:=False;
 While i<=len do Begin
  c:=o[i];
  If(c='<')and(cur='')and(Not started)Then Begin
   d2:=1;
   Inc(i);
   While(i<=len)and(d2>0)do Begin
    If o[i]='<' Then Inc(d2) Else If o[i]='>' Then Begin
     Dec(d2);
     If d2=0 Then Break;
    End;
    cur:=cur+o[i];
    Inc(i);
   End;
   Inc(i);
   started:=True;
   Continue;
  End;
  If c in ['''','"'] Then Begin
   q:=c;
   cur:=cur+c;
   Inc(i);
   While i<=len do Begin
    cur:=cur+o[i];
    If o[i]=q Then Begin Inc(i);Break;End;
    Inc(i);
   End;
   started:=True;
   Continue;
  End;
  If c='(' Then Inc(depth) Else If c=')' Then Dec(depth);
  If(c=',')and(depth<=0)Then Begin
   If n<=High(args)Then args[n]:=cur;
   Inc(n);
   cur:='';
   started:=False;
   Inc(i);
   While(i<=len)and(o[i] in [' ',#9])do Inc(i);
   Continue;
  End;
  If(depth<=0)and(c in [' ',#9,';'])Then Break;
  cur:=cur+c;
  started:=True;
  Inc(i);
 End;
 If n<=High(args)Then args[n]:=cur;
 Inc(n);
End;

Procedure InvokeMacro(m:Longint;Const ext,o:String);
Var
 t:Longint;
 a:Array[0..MAX_ARGS] of String;
 n,i:Longint;
Begin
 If srcTop>=MAX_SRC-1 Then Begin
  Error(Tr('Expansion de macros trop profonde','Macro expansion too deep'));
  Exit;
 End;
 For i:=0 to MAX_ARGS do a[i]:='';
 SplitMacroArgs(o,a,n);
 t:=srcTop+1;
 src[t].kind:=SRC_MACRO;
 src[t].isopen:=False;
 src[t].buf:=Nil;
 src[t].name:=macros[m].name;
 src[t].macname:=macros[m].name;
 src[t].first:=macros[m].first;
 src[t].cur:=macros[m].first;
 src[t].line:=0;
 src[t].count:=0;
 src[t].ext:=ext;
 src[t].condBase:=condDepth;
 If n>MAX_ARGS Then n:=MAX_ARGS;
 src[t].narg:=n;
 Inc(uniqCount);
 src[t].uniq:=uniqCount;
 For i:=1 to MAX_ARGS do src[t].args[i]:='';
 For i:=1 to n do src[t].args[i]:=Copy(a[i-1],1,200);
 srcTop:=t;
End;

{ ------------------------------------------------------------------------ }
{ Assemblage conditionnel                                                   }
{ ------------------------------------------------------------------------ }

Function CondActive:Boolean;
Begin
 CondActive:=(condDepth=0)or condCur[condDepth];
End;

Procedure PushCond(c:Boolean);
Var
 pa:Boolean;
Begin
 pa:=CondActive;
 If condDepth>=MAX_COND Then Begin
  Error(Tr('Conditions imbriquees trop profondes',
    'Conditional nesting too deep'));
  Exit;
 End;
 Inc(condDepth);
 condParent[condDepth]:=pa;
 If pa Then Begin
  condCur[condDepth]:=c;
  condTaken[condDepth]:=c;
 End Else Begin
  condCur[condDepth]:=False;
  condTaken[condDepth]:=True;
 End;
End;

Procedure ElseCond;
Begin
 If condDepth=0 Then Begin
  Error(Tr('ELSE sans IF correspondant','ELSE without matching IF'));
  Exit;
 End;
 condCur[condDepth]:=condParent[condDepth] and Not condTaken[condDepth];
 If condCur[condDepth]Then condTaken[condDepth]:=True;
End;

Procedure EndCond;
Begin
 If condDepth=0 Then Begin
  Error(Tr('ENDC sans IF correspondant','ENDC without matching IF'));
  Exit;
 End;
 Dec(condDepth);
End;

{ ------------------------------------------------------------------------ }
{ Decoupage d'une ligne source                                              }
{ ------------------------------------------------------------------------ }

Procedure SplitLine(Const s:String;Var lab,mn,ext:String;Var opStart:Longint);
Var
 i,n,j,k:Longint;
 tok:String;
 u:String;
Begin
 lab:='';
 mn:='';
 ext:='';
 n:=Length(s);
 opStart:=n+1;
 If n=0 Then Exit;
 If s[1] in ['*',';'] Then Exit;
 i:=1;
 If Not(s[1] in [' ',#9])Then Begin
  j:=1;
  If IsIdStart(s[1])or IsDigit(s[1])Then Begin
   Inc(j);
   While(j<=n)and IsIdChar(s[j])do Inc(j);
  End;
  lab:=Copy(s,1,j-1);
  i:=j;
  If(i<=n)and(s[i]=':')Then Begin
   Inc(i);
   If(i<=n)and(s[i]=':')Then Inc(i);
  End Else Begin
   { directive sans operande ecrite en colonne 1 }
   k:=i;
   While(k<=n)and(s[k] in [' ',#9])do Inc(k);
   If(k>n)or(s[k]=';')Then Begin
    u:=UpStr(lab);
    If(u='ENDM')or(u='ENDC')or(u='ENDIF')or(u='ELSE')or(u='ENDR')or(u='MEXIT')or
      (u='END')or(u='EVEN')or(u='RSRESET')or(u='NOLIST')Then Begin
     mn:=u;
     lab:='';
     Exit;
    End;
   End;
  End;
 End;
 While(i<=n)and(s[i] in [' ',#9])do Inc(i);
 If(i>n)or(s[i]=';')Then Exit;
 If s[i]='=' Then Begin
  mn:='=';
  Inc(i);
  If(i<=n)and(s[i]='=')Then Inc(i);
 End Else Begin
  j:=i;
  While(j<=n)and Not(s[j] in [' ',#9,';'])do Inc(j);
  tok:=Copy(s,i,j-i);
  i:=j;
  If(lab='')and(tok<>'')and(tok[Length(tok)]=':')Then Begin
   lab:=Copy(tok,1,Length(tok)-1);
   While(i<=n)and(s[i] in [' ',#9])do Inc(i);
   If(i>n)or(s[i]=';')Then Exit;
   j:=i;
   While(j<=n)and Not(s[j] in [' ',#9,';'])do Inc(j);
   tok:=Copy(s,i,j-i);
   i:=j;
  End;
  k:=Pos('.',tok);
  If(k>1)Then Begin
   mn:=Copy(tok,1,k-1);
   ext:=UpStr(Copy(tok,k+1,8));
  End Else mn:=tok;
 End;
 While(i<=n)and(s[i] in [' ',#9])do Inc(i);
 opStart:=i;
End;

{ ------------------------------------------------------------------------ }
{ Registres et analyse des operandes                                        }
{ ------------------------------------------------------------------------ }

Function PeekIdent:String;
Var
 j:Longint;
Begin
 PeekIdent:='';
 j:=LPOS;
 If(j<=Length(LP))and IsIdStart(LP[j])Then Begin
  Inc(j);
  While(j<=Length(LP))and IsIdChar(LP[j])do Inc(j);
  PeekIdent:=Copy(LP,LPOS,j-LPOS);
 End;
End;

{ Numero de registre : D0-D7 = 0..7, A0-A7 = 8..15 ; -1 si ce n'est pas un
  registre }
Function RegFromName(Const name:String):Longint;
Var
 u:String;
 i:Longint;
Begin
 RegFromName:=-1;
 u:=UpStr(name);
 If Length(u)=2 Then Begin
  If(u[1]='D')and(u[2] in ['0'..'7'])Then
    Begin RegFromName:=Ord(u[2])-48;Exit;End;
  If(u[1]='A')and(u[2] in ['0'..'7'])Then
    Begin RegFromName:=8+Ord(u[2])-48;Exit;End;
  If u='SP' Then Begin RegFromName:=15;Exit;End;
 End;
 i:=FindSym(SymKey(MangleName(name)));
 If(i>=0)and(syms[i].kind=SK_EQUR)Then RegFromName:=syms[i].v;
End;

Function CtrlRegCode(Const u:String):Longint;
Begin
 CtrlRegCode:=-1;
 If u='SFC' Then CtrlRegCode:=$000 Else
 If u='DFC' Then CtrlRegCode:=$001 Else
 If u='CACR' Then CtrlRegCode:=$002 Else
 If u='USP' Then CtrlRegCode:=$800 Else
 If u='VBR' Then CtrlRegCode:=$801 Else
 If u='CAAR' Then CtrlRegCode:=$802 Else
 If u='MSP' Then CtrlRegCode:=$803 Else
 If u='ISP' Then CtrlRegCode:=$804;
End;

{ Lit un registre simple a la position courante (avance si trouve) }
Function TryReg(Var r:Longint):Boolean;
Var
 id:String;
 n:Longint;
Begin
 TryReg:=False;
 id:=PeekIdent;
 If id='' Then Exit;
 n:=RegFromName(id);
 If n<0 Then Exit;
 r:=n;
 Inc(LPOS,Length(id));
 TryReg:=True;
End;

{ Liste de registres pour MOVEM : D0-D3/A0/A2-A4 }
Function ParseRegList(Var mask:Longint):Boolean;
Var
 r1,r2,i,lo,hi,k:Longint;
 id:String;
Begin
 ParseRegList:=False;
 mask:=0;
 While True do Begin
  SkipSp;
  id:=PeekIdent;
  k:=FindSym(SymKey(MangleName(id)));
  If(id<>'')and(k>=0)and(syms[k].kind=SK_REGLIST)Then Begin
   mask:=mask or syms[k].v;
   Inc(LPOS,Length(id));
  End Else Begin
   If Not TryReg(r1)Then Exit;
   r2:=r1;
   SkipSp;
   If PeekCh='-' Then Begin
    Inc(LPOS);
    SkipSp;
    If Not TryReg(r2)Then Exit;
   End;
   lo:=r1;
   hi:=r2;
   If lo>hi Then Begin i:=lo;lo:=hi;hi:=i;End;
   For i:=lo to hi do mask:=mask or (1 shl i);
  End;
  SkipSp;
  If PeekCh='/' Then Inc(LPOS) Else Break;
 End;
 ParseRegList:=True;
End;

Procedure InitOp(Var op:TOp);
Begin
 FillChar(op,SizeOf(op),0);
 op.xreg:=-1;
 MkAbs(op.val,0);
 MkAbs(op.bd,0);
 MkAbs(op.od,0);
End;

{ Suffixe .W ou .L apres une expression ou un registre d'index }
Function ParseSizeSuffix(Var sz:Byte):Boolean;
Begin
 ParseSizeSuffix:=False;
 If(PeekCh='.')and(UpCase(PeekCh2) in ['W','L'])Then Begin
  If(LPOS+2>Length(LP))or Not IsIdChar(LP[LPOS+2])Then Begin
   If UpCase(PeekCh2)='W' Then sz:=2 Else sz:=4;
   Inc(LPOS,2);
   ParseSizeSuffix:=True;
  End;
 End;
End;

{ Registre d'index : Xn[.W|.L][*echelle] }
Procedure ParseIndexSpec(Var op:TOp;r:Longint);
Var
 sz:Byte;
 v:Longint;
Begin
 op.xreg:=r;
 op.xlong:=False;
 op.xscale:=0;
 sz:=2;
 If ParseSizeSuffix(sz)Then op.xlong:=(sz=4);
 If PeekCh='*' Then Begin
  Inc(LPOS);
  ExprAbs(v);
  Case v of
   1:op.xscale:=0;
   2:op.xscale:=1;
   4:op.xscale:=2;
   8:op.xscale:=3;
   Else ExprError(Tr('Echelle d''index invalide','Invalid index scale'));
  End;
  If cpu<CPU_68020 Then ExprError(Tr('Echelle d''index requiert un 68020',
    'Index scale requires a 68020'));
 End;
End;

{ Trouve la parenthese fermante correspondant a celle en LPOS }
Function MatchParen(from:Longint):Longint;
Var
 d,i:Longint;
 q:Char;
Begin
 d:=0;
 i:=from;
 q:=#0;
 While i<=Length(LP) do Begin
  If q<>#0 Then Begin
   If LP[i]=q Then q:=#0;
  End Else If LP[i] in ['''','"'] Then q:=LP[i]
  Else If LP[i]='(' Then Inc(d)
  Else If LP[i]=')' Then Begin
   Dec(d);
   If d=0 Then Begin MatchParen:=i;Exit;End;
  End;
  Inc(i);
 End;
 MatchParen:=0;
End;

{ Le contenu des parentheses est-il un mode d'adressage (et non une
  expression) ? }
Function IsParenMode(p1,p2:Longint):Boolean;
Var
 i,d:Longint;
 inner,u:String;
 q:Char;
Begin
 IsParenMode:=False;
 inner:=Copy(LP,p1+1,p2-p1-1);
 d:=0;
 q:=#0;
 For i:=1 to Length(inner) do Begin
  If q<>#0 Then Begin
   If inner[i]=q Then q:=#0;
  End Else If inner[i] in ['''','"'] Then q:=inner[i]
  Else If inner[i]='(' Then Inc(d)
  Else If inner[i]=')' Then Dec(d)
  Else If(inner[i]=',')and(d=0)Then Begin IsParenMode:=True;Exit;End
  Else If(inner[i]='[')and(d=0)Then Begin IsParenMode:=True;Exit;End;
 End;
 While(inner<>'')and(inner[1]=' ')do inner:=Copy(inner,2,255);
 While(inner<>'')and(inner[Length(inner)]=' ')do Dec(inner[0]);
 u:=UpStr(inner);
 If(u='PC')or(u='ZPC')or(RegFromName(inner)>=8)Then IsParenMode:=True;
 If(Length(u)=3)and(u[1]='Z')and(u[2] in ['A','D'])Then IsParenMode:=True;
End;

{ Analyse du contenu d'un mode parenthese ou crochet 68020.
  LPOS est place juste apres '(' }
Procedure ParseParenItems(Var op:TOp;haveDisp:Boolean);
Var
 inBr,usedBr,baseSet,idxInBr:Boolean;
 id,u:String;
 r:Longint;
 sz:Byte;
 v:TVal;
 gotOd:Boolean;
Begin
 inBr:=False;
 usedBr:=False;
 baseSet:=False;
 idxInBr:=False;
 gotOd:=False;
 op.hasBd:=haveDisp;
 If haveDisp Then Begin op.bd:=op.val;op.bdSize:=0;End;
 While True do Begin
  SkipSp;
  If PeekCh='[' Then Begin
   Inc(LPOS);
   inBr:=True;
   usedBr:=True;
   Continue;
  End;
  id:=PeekIdent;
  u:=UpStr(id);
  If(u='PC')or(u='ZPC')Then Begin
   Inc(LPOS,Length(id));
   baseSet:=True;
   op.baseIsPC:=True;
   If u='ZPC' Then op.baseSup:=True;
  End Else If(Length(u)=3)and(u[1]='Z')and(u[2]='A')and(u[3] in ['0'..'7'])Then
    Begin
   Inc(LPOS,Length(id));
   If baseSet Then Begin
    op.idxSup:=True;
    ParseIndexSpec(op,8+Ord(u[3])-48);
    If inBr Then idxInBr:=True;
   End Else Begin
    baseSet:=True;
    op.baseSup:=True;
    op.reg:=Ord(u[3])-48;
   End;
  End Else If(Length(u)=3)and(u[1]='Z')and(u[2]='D')and(u[3] in ['0'..'7'])Then
    Begin
   Inc(LPOS,Length(id));
   op.idxSup:=True;
   op.xreg:=Ord(u[3])-48;
   ParseIndexSpec(op,op.xreg);
   If inBr Then idxInBr:=True;
  End Else If(id<>'')and(RegFromName(id)>=0)Then Begin
   r:=RegFromName(id);
   Inc(LPOS,Length(id));
   If(Not baseSet)and(r>=8)and(PeekCh<>'.')and(PeekCh<>'*')Then Begin
    baseSet:=True;
    op.reg:=r-8;
   End Else Begin
    ParseIndexSpec(op,r);
    If inBr Then idxInBr:=True;
   End;
  End Else Begin
   exprErr:=False;
   Expr(v);
   sz:=0;
   ParseSizeSuffix(sz);
   If(Not op.hasBd)and Not(usedBr and Not inBr)Then Begin
    op.bd:=v;
    op.hasBd:=True;
    op.bdSize:=sz;
   End Else Begin
    op.od:=v;
    op.hasOd:=True;
    op.odSize:=sz;
    gotOd:=True;
   End;
  End;
  SkipSp;
  If PeekCh=']' Then Begin
   Inc(LPOS);
   inBr:=False;
   SkipSp;
   If PeekCh=',' Then Inc(LPOS) Else If PeekCh=')' Then Begin
    Inc(LPOS);
    Break;
   End;
   Continue;
  End;
  If PeekCh=',' Then Begin Inc(LPOS);Continue;End;
  If PeekCh=')' Then Begin Inc(LPOS);Break;End;
  ExprError(Tr('Syntaxe de mode d''adressage invalide',
    'Invalid addressing mode syntax'));
  Break;
 End;
 If gotOd and Not usedBr Then ExprError(Tr('Deplacement externe sans crochets',
   'Outer displacement without brackets'));
 If usedBr Then Begin
  op.kind:=OK_FULL;
  If op.xreg<0 Then op.memInd:=3 Else If idxInBr Then op.memInd:=1
    Else op.memInd:=2;
  If cpu<CPU_68020 Then ExprError(Tr('Mode d''adressage 68020 non disponible',
    '68020 addressing mode not available'));
  Exit;
 End;
 If op.baseSup or(op.idxSup and baseSet)Then Begin
  op.kind:=OK_FULL;
  op.memInd:=0;
  If cpu<CPU_68020 Then ExprError(Tr('Mode d''adressage 68020 non disponible',
    '68020 addressing mode not available'));
  Exit;
 End;
 If Not baseSet Then Begin
  If op.xreg>=0 Then Begin
   op.kind:=OK_FULL;
   op.baseSup:=True;
   op.memInd:=0;
   If cpu<CPU_68020 Then ExprError(Tr('Mode d''adressage 68020 non disponible',
     '68020 addressing mode not available'));
  End Else ExprError(Tr('Registre de base manquant','Missing base register'));
  Exit;
 End;
 If op.baseIsPC Then Begin
  If op.xreg>=0 Then op.kind:=OK_PCI Else op.kind:=OK_PCD;
  If op.hasBd Then op.val:=op.bd Else MkAbs(op.val,0);
 End Else Begin
  If op.xreg>=0 Then op.kind:=OK_IDX Else If op.hasBd Then op.kind:=OK_DISP
    Else op.kind:=OK_IND;
  If op.hasBd Then op.val:=op.bd Else MkAbs(op.val,0);
  If(op.kind=OK_IND)and(PeekCh='+')Then Begin
   Inc(LPOS);
   op.kind:=OK_POST;
  End;
 End;
End;

Procedure ParseBitfield(Var op:TOp);
Var
 r:Longint;
 v:Longint;
Begin
 Inc(LPOS);
 SkipSp;
 If PeekCh='#' Then Inc(LPOS);
 op.hasBF:=True;
 If TryReg(r)Then Begin
  If r>7 Then ExprError(Tr('Registre de donnees attendu',
    'Data register expected'));
  op.bfOffReg:=True;
  op.bfOff:=r;
 End Else Begin
  ExprAbs(v);
  op.bfOff:=v;
 End;
 SkipSp;
 If PeekCh='}' Then Begin
  { facteur K du format decimal compacte (k ou Dn entre accolades) }
  Inc(LPOS);
  op.hasBF:=False;
  op.hasK:=True;
  op.kIsReg:=op.bfOffReg;
  op.kVal:=op.bfOff;
  Exit;
 End;
 If PeekCh=':' Then Inc(LPOS)
   Else ExprError(Tr('":" attendu dans le champ de bits',
   '":" expected in bit field'));
 SkipSp;
 If TryReg(r)Then Begin
  If r>7 Then ExprError(Tr('Registre de donnees attendu',
    'Data register expected'));
  op.bfWidReg:=True;
  op.bfWid:=r;
 End Else Begin
  ExprAbs(v);
  op.bfWid:=v;
 End;
 SkipSp;
 If PeekCh='}' Then Inc(LPOS) Else ExprError(Tr('"}" attendu','"}" expected'));
End;

{ Litteral flottant : [+-]chiffres[.chiffres][e[+-]chiffres] }
Function ScanFloat(Var e:Extended;Var txt:String):Boolean;
Var
 i,n,code:Longint;
 s:String;
 hasDig,hasDot,hasExp:Boolean;
Begin
 ScanFloat:=False;
 i:=LPOS;
 n:=Length(LP);
 s:='';
 hasDig:=False;
 hasDot:=False;
 hasExp:=False;
 If(i<=n)and(LP[i] in ['+','-'])Then Begin
  s:=LP[i];
  Inc(i);
 End;
 While(i<=n)and IsDigit(LP[i])do Begin
  s:=s+LP[i];
  Inc(i);
  hasDig:=True;
 End;
 If(i<n)and(LP[i]='.')and IsDigit(LP[i+1])Then Begin
  hasDot:=True;
  s:=s+'.';
  Inc(i);
  While(i<=n)and IsDigit(LP[i])do Begin
   s:=s+LP[i];
   Inc(i);
   hasDig:=True;
  End;
 End;
 If Not hasDig Then Exit;
 If(i<=n)and(LP[i] in ['e','E'])Then Begin
  If(i<n)and IsDigit(LP[i+1])Then Begin
   hasExp:=True;
   s:=s+'e';
   Inc(i);
  End Else If(i+1<n)and(LP[i+1] in ['+','-'])and IsDigit(LP[i+2])Then Begin
   hasExp:=True;
   s:=s+'e'+LP[i+1];
   Inc(i,2);
  End;
  If hasExp Then
   While(i<=n)and IsDigit(LP[i])do Begin
    s:=s+LP[i];
    Inc(i);
   End;
 End;
 If Not(hasDot or hasExp)Then Exit;
 Val(s,e,code);
 If code<>0 Then Exit;
 txt:=s;
 LPOS:=i;
 ScanFloat:=True;
End;

Function FPNum(Const u:String):Longint;
Begin
 FPNum:=-1;
 If(Length(u)=3)and(u[1]='F')and(u[2]='P')and(u[3] in ['0'..'7'])Then
  FPNum:=Ord(u[3])-48;
End;

Function FPCtrlBit(Const u:String):Longint;
Begin
 If u='FPCR' Then FPCtrlBit:=$1000 Else
 If u='FPSR' Then FPCtrlBit:=$0800 Else
 If u='FPIAR' Then FPCtrlBit:=$0400 Else FPCtrlBit:=0;
End;

Function MMURegCode(Const u:String):Longint;
Begin
 MMURegCode:=-1;
 If u='TC' Then MMURegCode:=$4000 Else
 If u='DRP' Then MMURegCode:=$4400 Else
 If u='SRP' Then MMURegCode:=$4800 Else
 If u='CRP' Then MMURegCode:=$4C00 Else
 If u='CAL' Then MMURegCode:=$5000 Else
 If u='VAL' Then MMURegCode:=$5400 Else
 If u='SCC' Then MMURegCode:=$5800 Else
 If u='AC' Then MMURegCode:=$5C00 Else
 If u='PSR' Then MMURegCode:=$6000 Else
 If u='PCSR' Then MMURegCode:=$6400 Else
 If u='TT0' Then MMURegCode:=$0800 Else
 If u='TT1' Then MMURegCode:=$0C00;
End;

Function CacheCode(Const u:String):Longint;
Begin
 CacheCode:=-1;
 If u='NC' Then CacheCode:=0 Else
 If u='DC' Then CacheCode:=1 Else
 If u='IC' Then CacheCode:=2 Else
 If u='BC' Then CacheCode:=3;
End;

{ Registres flottants et listes : FP0, FP0-FP3/FP5, FPCR/FPSR, FP1:FP2 }
Function ParseFPSpec(Var op:TOp):Boolean;
Var
 id,u:String;
 n,lo,hi,i,save,items,fpm,crm:Longint;
 isRange:Boolean;
Begin
 ParseFPSpec:=False;
 fpm:=0;
 crm:=0;
 items:=0;
 isRange:=False;
 n:=0;
 While True do Begin
  SkipSp;
  id:=PeekIdent;
  u:=UpStr(id);
  If FPNum(u)>=0 Then Begin
   n:=FPNum(u);
   lo:=n;
   hi:=n;
   Inc(LPOS,Length(id));
   If PeekCh='-' Then Begin
    save:=LPOS;
    Inc(LPOS);
    SkipSp;
    id:=PeekIdent;
    If FPNum(UpStr(id))>=0 Then Begin
     hi:=FPNum(UpStr(id));
     Inc(LPOS,Length(id));
     isRange:=True;
    End Else LPOS:=save;
   End;
   If lo>hi Then Begin i:=lo;lo:=hi;hi:=i;End;
   For i:=lo to hi do fpm:=fpm or (1 shl i);
  End Else If FPCtrlBit(u)<>0 Then Begin
   crm:=crm or FPCtrlBit(u);
   Inc(LPOS,Length(id));
  End Else Exit;
  Inc(items);
  If PeekCh='/' Then Inc(LPOS) Else Break;
 End;
 If(fpm<>0)and(crm<>0)Then Begin
  ExprError(Tr('Melange de registres FP et de controle',
    'Mixed FP and control registers'));
  Exit;
 End;
 If crm<>0 Then Begin
  op.kind:=OK_FPCR;
  op.mask:=crm;
 End Else If(items=1)and Not isRange Then Begin
  op.kind:=OK_FPREG;
  op.reg:=n;
  If PeekCh=':' Then Begin
   Inc(LPOS);
   SkipSp;
   id:=PeekIdent;
   If FPNum(UpStr(id))>=0 Then Begin
    op.hasPair:=True;
    op.pair:=FPNum(UpStr(id));
    Inc(LPOS,Length(id));
   End Else ExprError(Tr('Registre FP attendu apres ":"',
     'FP register expected after ":"'));
  End;
 End Else Begin
  op.kind:=OK_FPLIST;
  op.mask:=fpm;
 End;
 ParseFPSpec:=True;
End;

{ Analyse un operande. Retourne False s'il n'y a plus d'operande. }
Function ParseOperand(Var op:TOp):Boolean;
Var
 c:Char;
 id,u:String;
 r,r2,p2:Longint;
 k:Longint;
 save:Longint;
 mask:Longint;
 sz:Byte;
 v:TVal;
Begin
 InitOp(op);
 ParseOperand:=False;
 SkipSp;
 c:=PeekCh;
 If(c=#0)or(c=';')Then Exit;
 ParseOperand:=True;
 exprErr:=False;
 If c='#' Then Begin
  Inc(LPOS);
  If ScanFloat(op.fval,op.ftext)Then Begin
   op.hasFloat:=True;
   op.kind:=OK_IMM;
   Exit;
  End;
  Expr(op.val);
  op.kind:=OK_IMM;
  Exit;
 End;
 If c='(' Then Begin
  p2:=MatchParen(LPOS);
  If(p2>0)and IsParenMode(LPOS,p2)Then Begin
   Inc(LPOS);
   ParseParenItems(op,False);
   If PeekCh='{' Then ParseBitfield(op);
   Exit;
  End;
 End;
 If(c='-')and(PeekCh2='(')Then Begin
  save:=LPOS;
  Inc(LPOS,2);
  SkipSp;
  If TryReg(r)and(r>=8)Then Begin
   SkipSp;
   If PeekCh=')' Then Begin
    Inc(LPOS);
    op.kind:=OK_PRE;
    op.reg:=r-8;
    Exit;
   End;
  End;
  LPOS:=save;
 End;
 id:=PeekIdent;
 If id<>'' Then Begin
  u:=UpStr(id);
  If u='SR' Then Begin Inc(LPOS,2);op.kind:=OK_SR;Exit;End;
  If u='CCR' Then Begin Inc(LPOS,3);op.kind:=OK_CCR;Exit;End;
  If u='USP' Then Begin Inc(LPOS,3);op.kind:=OK_USP;op.ctrl:=$800;Exit;End;
  If(FPNum(u)>=0)or(FPCtrlBit(u)<>0)Then Begin
   save:=LPOS;
   If ParseFPSpec(op)Then Begin
    If PeekCh='{' Then ParseBitfield(op);
    Exit;
   End;
   LPOS:=save;
   InitOp(op);
  End;
  If gSpecial=1 Then Begin
   k:=MMURegCode(u);
   If k>=0 Then Begin
    Inc(LPOS,Length(id));
    op.kind:=OK_MMUREG;
    op.ctrl:=k;
    Exit;
   End;
  End;
  If gSpecial=2 Then Begin
   k:=CacheCode(u);
   If k>=0 Then Begin
    Inc(LPOS,Length(id));
    op.kind:=OK_CACHE;
    op.ctrl:=k;
    Exit;
   End;
  End;
  k:=CtrlRegCode(u);
  If k>=0 Then Begin
   Inc(LPOS,Length(id));
   op.kind:=OK_CTRL;
   op.ctrl:=k;
   Exit;
  End;
  r:=RegFromName(id);
  If r>=0 Then Begin
   save:=LPOS;
   Inc(LPOS,Length(id));
   SkipSp;
   If PeekCh in ['-','/'] Then Begin
    LPOS:=save;
    If ParseRegList(mask)Then Begin
     op.kind:=OK_LIST;
     op.mask:=mask;
     Exit;
    End;
    LPOS:=save;
    Inc(LPOS,Length(id));
   End;
   If r<8 Then op.kind:=OK_DN Else op.kind:=OK_AN;
   op.reg:=r and 7;
   op.val.v:=r;
   If PeekCh=':' Then Begin
    Inc(LPOS);
    SkipSp;
    If TryReg(r2)Then Begin
     op.hasPair:=True;
     op.pair:=r2;
    End Else ExprError(Tr('Registre attendu apres ":"',
      'Register expected after ":"'));
   End;
   If PeekCh='{' Then ParseBitfield(op);
   Exit;
  End;
  k:=FindSym(SymKey(MangleName(id)));
  If(k>=0)and(syms[k].kind=SK_REGLIST)Then Begin
   If ParseRegList(mask)Then Begin
    op.kind:=OK_LIST;
    op.mask:=mask;
    Exit;
   End;
  End;
 End;
 { expression : adresse absolue ou deplacement }
 Expr(v);
 op.val:=v;
 SkipSp;
 If PeekCh='(' Then Begin
  Inc(LPOS);
  ParseParenItems(op,True);
  If(op.kind=OK_IND)or(op.kind=OK_POST)Then Begin
   { d(An) deja gere : kind sera OK_DISP }
  End;
  If PeekCh='{' Then ParseBitfield(op);
  Exit;
 End;
 sz:=0;
 ParseSizeSuffix(sz);
 op.absSize:=sz;
 op.kind:=OK_ABS;
 If PeekCh='{' Then ParseBitfield(op);
End;

{ Analyse tous les operandes de la ligne }
Function ParseOperands(Var ops:Array of TOp):Longint;
Var
 n:Longint;
Begin
 n:=0;
 While n<=High(ops) do Begin
  If Not ParseOperand(ops[n])Then Break;
  Inc(n);
  SkipSp;
  If PeekCh=',' Then Inc(LPOS) Else Break;
 End;
 ParseOperands:=n;
End;

{ ------------------------------------------------------------------------ }
{ Resolution et encodage des modes d'adressage                             }
{ ------------------------------------------------------------------------ }

Function KnownAbs(Const v:TVal):Boolean;
Begin
 KnownAbs:=(v.sect=-1)and Not v.undef and Not v.fwd;
End;

Function KindMask(Const op:TOp):Longint;
Begin
 Case op.kind of
  OK_DN:KindMask:=M_DN;
  OK_AN:KindMask:=M_AN;
  OK_IND:KindMask:=M_IND;
  OK_POST:KindMask:=M_POST;
  OK_PRE:KindMask:=M_PRE;
  OK_DISP:KindMask:=M_DISP;
  OK_IDX:KindMask:=M_IDX;
  OK_FULL:If op.baseIsPC Then KindMask:=M_PCI Else KindMask:=M_IDX;
  OK_ABSW:KindMask:=M_ABSW;
  OK_ABSL:KindMask:=M_ABSL;
  OK_PCD:KindMask:=M_PCD;
  OK_PCI:KindMask:=M_PCI;
  OK_IMM:KindMask:=M_IMM;
  Else KindMask:=0;
 End;
End;

Function EABits(Const op:TOp):Longint;
Begin
 Case op.kind of
  OK_DN:EABits:=op.reg;
  OK_AN:EABits:=$08 or op.reg;
  OK_IND:EABits:=$10 or op.reg;
  OK_POST:EABits:=$18 or op.reg;
  OK_PRE:EABits:=$20 or op.reg;
  OK_DISP:EABits:=$28 or op.reg;
  OK_IDX:EABits:=$30 or op.reg;
  OK_FULL:If op.baseIsPC Then EABits:=$3B Else EABits:=$30 or op.reg;
  OK_ABSW:EABits:=$38;
  OK_ABSL:EABits:=$39;
  OK_PCD:EABits:=$3A;
  OK_PCI:EABits:=$3B;
  OK_IMM:EABits:=$3C;
  Else EABits:=0;
 End;
End;

{ Determine le mode final de l'operande (taille d'adresse absolue,
  optimisations) et retourne les 6 bits du champ EA, ou -1 en cas d'erreur }
Function ResolveEA(Var op:TOp;allowed:Longint):Longint;
Var
 need,lvl:Byte;
 dist:Longint;
 m:Longint;
Begin
 ResolveEA:=-1;
 If op.kind=OK_ABS Then Begin
  If op.absSize=2 Then op.kind:=OK_ABSW Else If op.absSize=4
    Then op.kind:=OK_ABSL
  Else Begin
   op.kind:=OK_ABSL;
   If opt.a and((allowed and M_PCD)<>0)Then Begin
    If op.val.undef Then need:=0
    Else If op.val.sect<>cursec Then need:=1
    Else Begin
     dist:=op.val.v-(PC+2);
     If(dist>32000)or(dist<-32000)Then need:=1 Else need:=0;
    End;
    lvl:=SiteLevel(need);
    If lvl=0 Then op.kind:=OK_PCD;
   End;
   If(op.kind=OK_ABSL)and opt.o and KnownAbs(op.val)and(op.val.v>=-32768)
     and(op.val.v<=32767)Then
    op.kind:=OK_ABSW;
  End;
 End;
 If(op.kind=OK_DISP)and opt.o2 and KnownAbs(op.val)and(op.val.v=0)
   Then op.kind:=OK_IND;
 If(op.kind=OK_DISP)and(cpu>=CPU_68020)and KnownAbs(op.val)and
   ((op.val.v<-32768)or(op.val.v>32767))Then Begin
  op.kind:=OK_FULL;
  op.hasBd:=True;
  op.bd:=op.val;
  op.bdSize:=0;
  op.memInd:=0;
 End;
 If(op.kind=OK_PCD)and(cpu>=CPU_68020)and(op.val.sect=-1)
   and Not op.val.undef and
   ((op.val.v<-32768)or(op.val.v>32767))Then Begin
  op.kind:=OK_FULL;
  op.baseIsPC:=True;
  op.hasBd:=True;
  op.bd:=op.val;
  op.bdSize:=0;
  op.memInd:=0;
 End;
 m:=KindMask(op);
 If(m and allowed)=0 Then Begin
  Error(Tr('Mode d''adressage invalide pour cette instruction',
    'Invalid addressing mode for this instruction'));
  Exit;
 End;
 If(op.kind=OK_FULL)and(cpu<CPU_68020)Then Begin
  Error(Tr('Mode d''adressage 68020 non disponible',
    '68020 addressing mode not available'));
  Exit;
 End;
 ResolveEA:=EABits(op);
End;

Procedure CheckRange(v,size:Longint);
Var
 bad:Boolean;
 msg:String;
Begin
 bad:=False;
 Case size of
  1:If(v<-128)or(v>255)Then Begin
   bad:=True;
   msg:=Tr('Valeur hors limites pour un octet','Value out of range for a byte');
  End;
  2:If(v<-32768)or(v>65535)Then Begin
   bad:=True;
   msg:=Tr('Valeur hors limites pour un mot','Value out of range for a word');
  End;
 End;
 If bad Then Begin
  If opt.t Then Error(msg) Else Warn(msg);
 End;
End;

Procedure NoReloc(Const v:TVal);
Begin
 If(v.sect<>-1)and Not v.undef Then
  Error(Tr('Valeur relogeable ou externe non permise ici',
    'Relocatable or external value not allowed here'));
End;

{ Deplacement relatif au compteur de position 'at' }
Function PCRelDisp(Const v:TVal;at:Longint;Var isExt:Boolean):Longint;
Begin
 isExt:=False;
 PCRelDisp:=0;
 If v.undef Then Exit;
 If v.sect=-2 Then Begin
  isExt:=True;
  PCRelDisp:=v.v;
 End Else If v.sect=cursec Then PCRelDisp:=v.v-at
 Else If v.sect=-1 Then PCRelDisp:=v.v
 Else Error(Tr('Reference relative a une autre section',
   'PC-relative reference to another section'));
End;

Procedure EmitDisp16(Const v:TVal);
Var
 d:Longint;
Begin
 NoReloc(v);
 d:=v.v;
 If(Not v.undef)and((d<-32768)or(d>32767))
   Then Error(Tr('Deplacement hors limites (16 bits)',
   'Displacement out of range (16 bits)'));
 EmitW(d and $FFFF);
End;

Procedure EmitImmValue(Const v:TVal;size:Longint);
Begin
 Case size of
  1:Begin
   NoReloc(v);
   CheckRange(v.v,1);
   EmitW(v.v and $FF);
  End;
  4:EmitLongVal(v);
  Else Begin
   NoReloc(v);
   CheckRange(v.v,2);
   EmitW(v.v and $FFFF);
  End;
 End;
End;

Function SizeOfBd(Const v:TVal;explicit:Byte):Longint;
Begin
 If explicit<>0 Then Begin SizeOfBd:=explicit;Exit;End;
 If KnownAbs(v)and(v.v>=-32768)and(v.v<=32767)Then SizeOfBd:=2 Else SizeOfBd:=4;
End;

{ Format d'extension complet du 68020 }
Procedure EmitFullExt(Var op:TOp);
Var
 w:Longint;
 bdv:TVal;
 bdn,odn:Longint;
 extpc:Longint;
Begin
 extpc:=PC;
 w:=$0100;
 If op.xreg>=0 Then Begin
  w:=w or (op.xreg shl 12) or (op.xscale shl 9);
  If op.xlong Then w:=w or $0800;
  If op.idxSup Then w:=w or $0040;
 End Else w:=w or $0040;
 If op.baseSup Then w:=w or $0080;
 bdv:=op.bd;
 If op.hasBd Then Begin
  If op.baseIsPC Then Begin
   If bdv.sect=cursec Then Begin bdv.v:=bdv.v-extpc;bdv.sect:=-1;End;
  End;
  bdn:=SizeOfBd(bdv,op.bdSize);
  If bdv.sect<>-1 Then bdn:=4;
 End Else bdn:=0;
 If bdn=0 Then w:=w or $0010 Else If bdn=2 Then w:=w or $0020 Else w:=w
   or $0030;
 If op.hasOd Then odn:=SizeOfBd(op.od,op.odSize) Else odn:=0;
 Case op.memInd of
  1:w:=w or 1;
  2:w:=w or 5;
  3:w:=w or $0040 or 1;
 End;
 If op.memInd<>0 Then Begin
  If odn=2 Then w:=w+1 Else If odn=4 Then w:=w+2;
 End;
 EmitW(w);
 If bdn=2 Then Begin
  NoReloc(bdv);
  EmitW(bdv.v and $FFFF);
 End Else If bdn=4 Then EmitLongVal(bdv);
 If odn=2 Then Begin NoReloc(op.od);EmitW(op.od.v and $FFFF);End
 Else If odn=4 Then EmitLongVal(op.od);
End;

{ ------------------------------------------------------------------------ }
{ Conversion des valeurs flottantes (Single, Double, Extended, Packed)     }
{ ------------------------------------------------------------------------ }

Type
 TByteBuf = Array[0..15] of Byte;

{ Format packed decimal (12 octets) a partir du texte du litteral }
Procedure PackedBytes(Const s0:String;Var b:TByteBuf);
Var
 s,ip,fp,ds:String;
 neg,eneg:Boolean;
 p,q,ex,code,pp,expn,k:Longint;
 d:Array[0..16] of Longint;
Begin
 FillChar(b,SizeOf(b),0);
 s:=s0;
 neg:=False;
 If(s<>'')and(s[1] in ['+','-'])Then Begin
  neg:=(s[1]='-');
  Delete(s,1,1);
 End;
 ex:=0;
 p:=Pos('e',s);
 If p>0 Then Begin
  Val(Copy(s,p+1,10),ex,code);
  s:=Copy(s,1,p-1);
 End;
 q:=Pos('.',s);
 If q>0 Then Begin
  ip:=Copy(s,1,q-1);
  fp:=Copy(s,q+1,255);
 End Else Begin
  ip:=s;
  fp:='';
 End;
 ds:=ip+fp;
 pp:=Length(ip);
 While(ds<>'')and(ds[1]='0')do Begin
  Delete(ds,1,1);
  Dec(pp);
 End;
 FillChar(d,SizeOf(d),0);
 expn:=0;
 If ds<>'' Then Begin
  expn:=pp+ex-1;
  For k:=0 to 16 do If k<Length(ds)Then d[k]:=Ord(ds[k+1])-48;
 End Else neg:=neg;
 eneg:=expn<0;
 If eneg Then expn:=-expn;
 If expn>999 Then Begin
  Error(Tr('Exposant hors limites pour le format packed',
    'Exponent out of range for packed format'));
  expn:=0;
 End;
 b[0]:=(expn div 100);
 If neg Then b[0]:=b[0] or $80;
 If eneg Then b[0]:=b[0] or $40;
 b[1]:=(((expn div 10)mod 10)shl 4)or(expn mod 10);
 b[3]:=d[0];
 For k:=0 to 7 do b[4+k]:=(d[1+2*k]shl 4)or d[2+2*k];
End;

Procedure ExtendedBytes(e:Extended;Var b:TByteBuf);
Var
 raw:Array[0..15] of Byte;
 dd:Double;
 i,e11,lo,hi,e15,mh,ml,szExt:Longint;
 neg:Boolean;
Begin
 FillChar(b,SizeOf(b),0);
 szExt:=SizeOf(Extended);
 If szExt=10 Then Begin
  FillChar(raw,SizeOf(raw),0);
  Move(e,raw,10);
  b[0]:=raw[9];
  b[1]:=raw[8];
  For i:=0 to 7 do b[4+i]:=raw[7-i];
 End Else Begin
  dd:=e;
  FillChar(raw,SizeOf(raw),0);
  Move(dd,raw,8);
  lo:=raw[0]or(raw[1]shl 8)or(raw[2]shl 16)or(raw[3]shl 24);
  hi:=raw[4]or(raw[5]shl 8)or(raw[6]shl 16)or(raw[7]shl 24);
  neg:=(hi<0);
  e11:=(hi shr 20)and $7FF;
  If neg Then e11:=((hi and $7FFFFFFF)shr 20);
  e15:=0;
  mh:=0;
  ml:=0;
  If e11=$7FF Then e15:=$7FFF Else If e11<>0 Then Begin
   e15:=e11-1023+16383;
   mh:=Longint($80000000)or((hi and $FFFFF)shl 11)
     or(Longint(Cardinal(lo)shr 21));
   ml:=Longint(Cardinal(lo)shl 11);
  End;
  If neg Then e15:=e15 or $8000;
  b[0]:=e15 shr 8;
  b[1]:=e15 and $FF;
  b[4]:=(mh shr 24)and $FF;
  b[5]:=(mh shr 16)and $FF;
  b[6]:=(mh shr 8)and $FF;
  b[7]:=mh and $FF;
  b[8]:=(ml shr 24)and $FF;
  b[9]:=(ml shr 16)and $FF;
  b[10]:=(ml shr 8)and $FF;
  b[11]:=ml and $FF;
 End;
End;

{ fmt : 8 = Single, 9 = Double, 10 = Extended, 11 = Packed }
Procedure FloatBytes(fmt:Longint;e:Extended;Const txt:String;Var b:TByteBuf;
                     Var n:Longint);
Var
 sg:Single;
 db:Double;
 raw:Array[0..15] of Byte;
 i:Longint;
Begin
 FillChar(b,SizeOf(b),0);
 n:=0;
 Case fmt of
  8:Begin
   n:=4;
   If(e>3.4028234e38)or(e<-3.4028234e38)Then Begin
    Error(Tr('Valeur hors limites pour un flottant simple',
      'Value out of range for single precision'));
    Exit;
   End;
   sg:=e;
   Move(sg,raw,4);
   For i:=0 to 3 do b[i]:=raw[3-i];
  End;
  9:Begin
   n:=8;
   If(e>1.7976931348623157e308)or(e<-1.7976931348623157e308)Then Begin
    Error(Tr('Valeur hors limites pour un flottant double',
      'Value out of range for double precision'));
    Exit;
   End;
   db:=e;
   Move(db,raw,8);
   For i:=0 to 7 do b[i]:=raw[7-i];
  End;
  10:Begin
   n:=12;
   ExtendedBytes(e,b);
  End;
  Else Begin
   n:=12;
   PackedBytes(txt,b);
  End;
 End;
End;

Procedure EmitFloatValue(fmt:Longint;e:Extended;Const txt:String);
Var
 b:TByteBuf;
 n,i:Longint;
Begin
 FloatBytes(fmt,e,txt,b,n);
 For i:=0 to n-1 do EmitB(b[i]);
End;

Procedure EmitFloatImm(Const op:TOp;fmt:Longint);
Var
 e:Extended;
 t:String;
Begin
 If op.hasFloat Then Begin
  e:=op.fval;
  t:=op.ftext;
 End Else Begin
  NoReloc(op.val);
  e:=op.val.v;
  t:=IntStr(op.val.v);
 End;
 EmitFloatValue(fmt,e,t);
End;

{ Mots d'extension d'un operande (apres le mot d'operation) }
Procedure EmitEAExt(Var op:TOp;size:Longint);
Var
 d,at:Longint;
 isExt:Boolean;
 w:Longint;
Begin
 Case op.kind of
  OK_DISP:EmitDisp16(op.val);
  OK_IDX,OK_PCI:Begin
   at:=PC;
   If op.kind=OK_PCI Then d:=PCRelDisp(op.val,at,isExt) Else Begin
    NoReloc(op.val);
    d:=op.val.v;
    isExt:=False;
   End;
   If(d<-128)or(d>127)Then Begin
    If(cpu>=CPU_68020)Then Begin
     op.hasBd:=True;
     op.bd:=op.val;
     op.memInd:=0;
     If op.kind=OK_PCI Then op.baseIsPC:=True;
     EmitFullExt(op);
     Exit;
    End;
    If Not op.val.undef Then Error(Tr('Deplacement hors limites (8 bits)',
      'Displacement out of range (8 bits)'));
    d:=0;
   End;
   If isExt Then Begin
    Error(Tr('Reference externe non permise ici',
      'External reference not allowed here'));
    d:=0;
   End;
   w:=(op.xreg shl 12)or(op.xscale shl 9)or(d and $FF);
   If op.xlong Then w:=w or $0800;
   If(op.xscale<>0)and(cpu<CPU_68020)
     Then Error(Tr('Echelle d''index requiert un 68020',
     'Index scale requires a 68020'));
   EmitW(w);
  End;
  OK_FULL:EmitFullExt(op);
  OK_ABSW:Begin
   NoReloc(op.val);
   If(Not op.val.undef)and((op.val.v<-32768)or(op.val.v>32767))Then
    Error(Tr('Adresse absolue courte hors limites',
      'Absolute short address out of range'));
   EmitW(op.val.v and $FFFF);
  End;
  OK_ABSL:EmitLongVal(op.val);
  OK_PCD:Begin
   at:=PC;
   d:=PCRelDisp(op.val,at,isExt);
   If isExt Then AddXRef(op.val.ext,at,EXT_REF16);
   If(Not op.val.undef)and((d<-32768)or(d>32767))
     Then Error(Tr('Deplacement hors limites (16 bits)',
     'Displacement out of range (16 bits)'));
   EmitW(d and $FFFF);
  End;
  OK_IMM:If size>=8 Then EmitFloatImm(op,size) Else EmitImmValue(op.val,size);
 End;
End;

{ ------------------------------------------------------------------------ }
{ Table des instructions                                                    }
{ ------------------------------------------------------------------------ }

Const
 C_NOOP=1;   C_BCC=2;    C_DBCC=3;   C_SCC=4;    C_TRAPCC=5; C_ADDSUB=6;
 C_LOGIC=7;  C_CMP=8;    C_ADDA=9;   C_IMMOP=10; C_QUICK=11; C_MOVE=12;
 C_MOVEA=13; C_MOVEQ=14; C_MOVEM=15; C_MOVEP=16; C_MOVEC=17; C_MOVES=18;
 C_UNARY=19; C_UNARYB=20; C_SHIFT=21; C_BIT=22;  C_MULDIV=23; C_DIVL=24;
 C_EXT=25;   C_SWAP=26;  C_LINK=27;  C_UNLK=28;  C_TRAP=29;  C_STOP=30;
 C_RTD=31;   C_BKPT=32;  C_CTRL1=33; C_LEA=34;   C_CHK=35;   C_EXG=36;
 C_BCDX=37;  C_BF=38;    C_CAS=39;   C_CMP2=40;  C_PACK=41;  C_CMPM=42;
 C_FPARITH=43; C_FMOVE=44; C_FMOVEM=45; C_FMOVECR=46; C_FSINCOS=47;
 C_FTST=48; C_FNOP=49; C_FSAVE=50; C_FRESTORE=51; C_FBCC=52; C_FDBCC=53;
 C_FSCC=54; C_FTRAPCC=55; C_PMOVE=56; C_PFLUSH=57; C_PLOAD=58; C_PTEST=59;
 C_PBCC=60; C_PDBCC=61; C_PSCC=62; C_PTRAPCC=63; C_PSAVE=64;
 C_PRESTORE=65; C_PVALID=66; C_CINV=67; C_MOVE16=68;

 NINSTR = 177;

Type
 TInstr = Record
  n:String[8];
  cls:Byte;
  op:Word;
  arg:Byte;
 End;

Const
 InstrTab:Array[1..NINSTR] of TInstr=(
  (n:'NOP';cls:C_NOOP;op:$4E71;arg:0),
  (n:'RESET';cls:C_NOOP;op:$4E70;arg:0),
  (n:'RTE';cls:C_NOOP;op:$4E73;arg:0),
  (n:'RTR';cls:C_NOOP;op:$4E77;arg:0),
  (n:'RTS';cls:C_NOOP;op:$4E75;arg:0),
  (n:'TRAPV';cls:C_NOOP;op:$4E76;arg:0),
  (n:'ILLEGAL';cls:C_NOOP;op:$4AFC;arg:0),
  (n:'ADD';cls:C_ADDSUB;op:$D000;arg:0),
  (n:'SUB';cls:C_ADDSUB;op:$9000;arg:1),
  (n:'AND';cls:C_LOGIC;op:$C000;arg:0),
  (n:'OR';cls:C_LOGIC;op:$8000;arg:1),
  (n:'EOR';cls:C_LOGIC;op:$B000;arg:2),
  (n:'CMP';cls:C_CMP;op:$B000;arg:0),
  (n:'ADDA';cls:C_ADDA;op:$D000;arg:0),
  (n:'SUBA';cls:C_ADDA;op:$9000;arg:1),
  (n:'CMPA';cls:C_ADDA;op:$B000;arg:2),
  (n:'ADDI';cls:C_IMMOP;op:$0600;arg:0),
  (n:'SUBI';cls:C_IMMOP;op:$0400;arg:0),
  (n:'CMPI';cls:C_IMMOP;op:$0C00;arg:0),
  (n:'ANDI';cls:C_IMMOP;op:$0200;arg:1),
  (n:'ORI';cls:C_IMMOP;op:$0000;arg:1),
  (n:'EORI';cls:C_IMMOP;op:$0A00;arg:1),
  (n:'ADDQ';cls:C_QUICK;op:$5000;arg:0),
  (n:'SUBQ';cls:C_QUICK;op:$5100;arg:0),
  (n:'MOVE';cls:C_MOVE;op:0;arg:0),
  (n:'MOVEA';cls:C_MOVEA;op:0;arg:0),
  (n:'MOVEQ';cls:C_MOVEQ;op:0;arg:0),
  (n:'MOVEM';cls:C_MOVEM;op:0;arg:0),
  (n:'MOVEP';cls:C_MOVEP;op:0;arg:0),
  (n:'MOVEC';cls:C_MOVEC;op:0;arg:0),
  (n:'MOVES';cls:C_MOVES;op:0;arg:0),
  (n:'CLR';cls:C_UNARY;op:$4200;arg:0),
  (n:'NEG';cls:C_UNARY;op:$4400;arg:0),
  (n:'NEGX';cls:C_UNARY;op:$4000;arg:0),
  (n:'NOT';cls:C_UNARY;op:$4600;arg:0),
  (n:'TST';cls:C_UNARY;op:$4A00;arg:1),
  (n:'NBCD';cls:C_UNARYB;op:$4800;arg:0),
  (n:'TAS';cls:C_UNARYB;op:$4AC0;arg:0),
  (n:'ASR';cls:C_SHIFT;op:0;arg:0),
  (n:'ASL';cls:C_SHIFT;op:0;arg:1),
  (n:'LSR';cls:C_SHIFT;op:1;arg:0),
  (n:'LSL';cls:C_SHIFT;op:1;arg:1),
  (n:'ROXR';cls:C_SHIFT;op:2;arg:0),
  (n:'ROXL';cls:C_SHIFT;op:2;arg:1),
  (n:'ROR';cls:C_SHIFT;op:3;arg:0),
  (n:'ROL';cls:C_SHIFT;op:3;arg:1),
  (n:'BTST';cls:C_BIT;op:0;arg:0),
  (n:'BCHG';cls:C_BIT;op:1;arg:0),
  (n:'BCLR';cls:C_BIT;op:2;arg:0),
  (n:'BSET';cls:C_BIT;op:3;arg:0),
  (n:'MULU';cls:C_MULDIV;op:$C0C0;arg:0),
  (n:'MULS';cls:C_MULDIV;op:$C1C0;arg:1),
  (n:'DIVU';cls:C_MULDIV;op:$80C0;arg:2),
  (n:'DIVS';cls:C_MULDIV;op:$81C0;arg:3),
  (n:'DIVUL';cls:C_DIVL;op:0;arg:0),
  (n:'DIVSL';cls:C_DIVL;op:0;arg:1),
  (n:'EXT';cls:C_EXT;op:0;arg:0),
  (n:'EXTB';cls:C_EXT;op:0;arg:1),
  (n:'SWAP';cls:C_SWAP;op:0;arg:0),
  (n:'LINK';cls:C_LINK;op:0;arg:0),
  (n:'UNLK';cls:C_UNLK;op:0;arg:0),
  (n:'TRAP';cls:C_TRAP;op:0;arg:0),
  (n:'STOP';cls:C_STOP;op:0;arg:0),
  (n:'RTD';cls:C_RTD;op:0;arg:0),
  (n:'BKPT';cls:C_BKPT;op:0;arg:0),
  (n:'JMP';cls:C_CTRL1;op:$4EC0;arg:0),
  (n:'JSR';cls:C_CTRL1;op:$4E80;arg:1),
  (n:'PEA';cls:C_CTRL1;op:$4840;arg:2),
  (n:'LEA';cls:C_LEA;op:0;arg:0),
  (n:'CHK';cls:C_CHK;op:0;arg:0),
  (n:'EXG';cls:C_EXG;op:0;arg:0),
  (n:'ABCD';cls:C_BCDX;op:$C100;arg:0),
  (n:'SBCD';cls:C_BCDX;op:$8100;arg:0),
  (n:'ADDX';cls:C_BCDX;op:$D100;arg:1),
  (n:'SUBX';cls:C_BCDX;op:$9100;arg:1),
  (n:'BFTST';cls:C_BF;op:$E8C0;arg:0),
  (n:'BFEXTU';cls:C_BF;op:$E9C0;arg:1),
  (n:'BFCHG';cls:C_BF;op:$EAC0;arg:3),
  (n:'BFEXTS';cls:C_BF;op:$EBC0;arg:1),
  (n:'BFCLR';cls:C_BF;op:$ECC0;arg:3),
  (n:'BFFFO';cls:C_BF;op:$EDC0;arg:1),
  (n:'BFSET';cls:C_BF;op:$EEC0;arg:3),
  (n:'BFINS';cls:C_BF;op:$EFC0;arg:2),
  (n:'CAS';cls:C_CAS;op:0;arg:0),
  (n:'CMP2';cls:C_CMP2;op:0;arg:0),
  (n:'CHK2';cls:C_CMP2;op:0;arg:1),
  (n:'PACK';cls:C_PACK;op:$8140;arg:0),
  (n:'UNPK';cls:C_PACK;op:$8180;arg:0),
  (n:'CMPM';cls:C_CMPM;op:0;arg:0),
  (n:'BRA';cls:C_BCC;op:0;arg:0),
  (n:'BSR';cls:C_BCC;op:0;arg:1),
  (n:'DBRA';cls:C_DBCC;op:0;arg:1),
  (n:'DBF';cls:C_DBCC;op:0;arg:1),
  (n:'DBT';cls:C_DBCC;op:0;arg:0),
  (n:'ST';cls:C_SCC;op:0;arg:0),
  (n:'SF';cls:C_SCC;op:0;arg:1),
  (n:'TRAPT';cls:C_TRAPCC;op:0;arg:0),
  (n:'TRAPF';cls:C_TRAPCC;op:0;arg:1),
  (n:'FINT';cls:C_FPARITH;op:$01;arg:1),
  (n:'FSINH';cls:C_FPARITH;op:$02;arg:1),
  (n:'FINTRZ';cls:C_FPARITH;op:$03;arg:1),
  (n:'FSQRT';cls:C_FPARITH;op:$04;arg:1),
  (n:'FLOGNP1';cls:C_FPARITH;op:$06;arg:1),
  (n:'FETOXM1';cls:C_FPARITH;op:$08;arg:1),
  (n:'FTANH';cls:C_FPARITH;op:$09;arg:1),
  (n:'FATAN';cls:C_FPARITH;op:$0A;arg:1),
  (n:'FASIN';cls:C_FPARITH;op:$0C;arg:1),
  (n:'FATANH';cls:C_FPARITH;op:$0D;arg:1),
  (n:'FSIN';cls:C_FPARITH;op:$0E;arg:1),
  (n:'FTAN';cls:C_FPARITH;op:$0F;arg:1),
  (n:'FETOX';cls:C_FPARITH;op:$10;arg:1),
  (n:'FTWOTOX';cls:C_FPARITH;op:$11;arg:1),
  (n:'FTENTOX';cls:C_FPARITH;op:$12;arg:1),
  (n:'FLOGN';cls:C_FPARITH;op:$14;arg:1),
  (n:'FLOG10';cls:C_FPARITH;op:$15;arg:1),
  (n:'FLOG2';cls:C_FPARITH;op:$16;arg:1),
  (n:'FABS';cls:C_FPARITH;op:$18;arg:1),
  (n:'FCOSH';cls:C_FPARITH;op:$19;arg:1),
  (n:'FNEG';cls:C_FPARITH;op:$1A;arg:1),
  (n:'FACOS';cls:C_FPARITH;op:$1C;arg:1),
  (n:'FCOS';cls:C_FPARITH;op:$1D;arg:1),
  (n:'FGETEXP';cls:C_FPARITH;op:$1E;arg:1),
  (n:'FGETMAN';cls:C_FPARITH;op:$1F;arg:1),
  (n:'FSSQRT';cls:C_FPARITH;op:$41;arg:1),
  (n:'FDSQRT';cls:C_FPARITH;op:$45;arg:1),
  (n:'FSABS';cls:C_FPARITH;op:$58;arg:1),
  (n:'FDABS';cls:C_FPARITH;op:$5C;arg:1),
  (n:'FSNEG';cls:C_FPARITH;op:$5A;arg:1),
  (n:'FDNEG';cls:C_FPARITH;op:$5E;arg:1),
  (n:'FDIV';cls:C_FPARITH;op:$20;arg:0),
  (n:'FMOD';cls:C_FPARITH;op:$21;arg:0),
  (n:'FADD';cls:C_FPARITH;op:$22;arg:0),
  (n:'FMUL';cls:C_FPARITH;op:$23;arg:0),
  (n:'FSGLDIV';cls:C_FPARITH;op:$24;arg:0),
  (n:'FREM';cls:C_FPARITH;op:$25;arg:0),
  (n:'FSCALE';cls:C_FPARITH;op:$26;arg:0),
  (n:'FSGLMUL';cls:C_FPARITH;op:$27;arg:0),
  (n:'FSUB';cls:C_FPARITH;op:$28;arg:0),
  (n:'FCMP';cls:C_FPARITH;op:$38;arg:0),
  (n:'FSDIV';cls:C_FPARITH;op:$60;arg:0),
  (n:'FDDIV';cls:C_FPARITH;op:$64;arg:0),
  (n:'FSADD';cls:C_FPARITH;op:$62;arg:0),
  (n:'FDADD';cls:C_FPARITH;op:$66;arg:0),
  (n:'FSMUL';cls:C_FPARITH;op:$63;arg:0),
  (n:'FDMUL';cls:C_FPARITH;op:$67;arg:0),
  (n:'FSSUB';cls:C_FPARITH;op:$68;arg:0),
  (n:'FDSUB';cls:C_FPARITH;op:$6C;arg:0),
  (n:'FMOVE';cls:C_FMOVE;op:$00;arg:0),
  (n:'FSMOVE';cls:C_FMOVE;op:$40;arg:0),
  (n:'FDMOVE';cls:C_FMOVE;op:$44;arg:0),
  (n:'FMOVEM';cls:C_FMOVEM;op:0;arg:0),
  (n:'FMOVECR';cls:C_FMOVECR;op:0;arg:0),
  (n:'FSINCOS';cls:C_FSINCOS;op:0;arg:0),
  (n:'FTST';cls:C_FTST;op:0;arg:0),
  (n:'FNOP';cls:C_FNOP;op:0;arg:0),
  (n:'FSAVE';cls:C_FSAVE;op:$F300;arg:0),
  (n:'FRESTORE';cls:C_FRESTORE;op:$F340;arg:0),
  (n:'PMOVE';cls:C_PMOVE;op:0;arg:0),
  (n:'PMOVEFD';cls:C_PMOVE;op:0;arg:1),
  (n:'PFLUSH';cls:C_PFLUSH;op:0;arg:0),
  (n:'PFLUSHA';cls:C_PFLUSH;op:0;arg:1),
  (n:'PFLUSHN';cls:C_PFLUSH;op:0;arg:2),
  (n:'PFLUSHAN';cls:C_PFLUSH;op:0;arg:3),
  (n:'PLOADR';cls:C_PLOAD;op:0;arg:1),
  (n:'PLOADW';cls:C_PLOAD;op:0;arg:0),
  (n:'PTESTR';cls:C_PTEST;op:0;arg:1),
  (n:'PTESTW';cls:C_PTEST;op:0;arg:0),
  (n:'PSAVE';cls:C_PSAVE;op:$F100;arg:0),
  (n:'PRESTORE';cls:C_PRESTORE;op:$F140;arg:0),
  (n:'PVALID';cls:C_PVALID;op:0;arg:0),
  (n:'CINVL';cls:C_CINV;op:$F408;arg:0),
  (n:'CINVP';cls:C_CINV;op:$F410;arg:0),
  (n:'CINVA';cls:C_CINV;op:$F418;arg:0),
  (n:'CPUSHL';cls:C_CINV;op:$F428;arg:1),
  (n:'CPUSHP';cls:C_CINV;op:$F430;arg:1),
  (n:'CPUSHA';cls:C_CINV;op:$F438;arg:1),
  (n:'MOVE16';cls:C_MOVE16;op:0;arg:0)
 );

 CCNames:Array[0..17] of String[2]=
  ('T','F','HI','LS','CC','CS','NE','EQ','VC','VS','PL','MI','GE','LT','GT',
    'LE','HS','LO');

{ Index de condition (0..15) pour un nom comme "NE", -1 si inconnu }
Function CCIndex(Const s:String):Longint;
Var
 i:Longint;
Begin
 CCIndex:=-1;
 For i:=0 to 17 do If CCNames[i]=s Then Begin
  If i>=16 Then CCIndex:=i-12 Else CCIndex:=i;
  Exit;
 End;
End;

Const
 FCCNames:Array[0..31] of String[5]=
  ('F','EQ','OGT','OGE','OLT','OLE','OGL','OR','UN','UEQ','UGT','UGE','ULT',
   'ULE','NE','T','SF','SEQ','GT','GE','LT','LE','GL','GLE','NGLE','NGL',
   'NLE','NLT','NGE','NGT','SNE','ST');
 PCCNames:Array[0..15] of String[3]=
  ('BS','BC','LS','LC','SS','SC','AS','AC','WS','WC','IS','IC','GS','GC',
   'CS','CC');

Function FCCIndex(Const s:String):Longint;
Var
 i:Longint;
Begin
 FCCIndex:=-1;
 For i:=0 to 31 do If FCCNames[i]=s Then Begin FCCIndex:=i;Exit;End;
End;

Function PCCIndex(Const s:String):Longint;
Var
 i:Longint;
Begin
 PCCIndex:=-1;
 For i:=0 to 15 do If PCCNames[i]=s Then Begin PCCIndex:=i;Exit;End;
End;

{ Recherche d'un mnemonique d'instruction. idx = index dans la table (0 pour
  les formes conditionnelles generees) ; cc = code de condition }
Function FindInstr(Const up:String;Var cls,idx,cc:Longint):Boolean;
Var
 i,c:Longint;
Begin
 FindInstr:=False;
 For i:=1 to NINSTR do Begin
  If InstrTab[i].n=up Then Begin
   cls:=InstrTab[i].cls;
   idx:=i;
   cc:=InstrTab[i].arg;
   FindInstr:=True;
   Exit;
  End;
 End;
 idx:=0;
 If Length(up)>=2 Then Begin
  If up[1]='B' Then Begin
   c:=CCIndex(Copy(up,2,3));
   If c>=2 Then Begin cls:=C_BCC;cc:=c;FindInstr:=True;Exit;End;
  End;
  If(Length(up)>=3)and(Copy(up,1,2)='DB')Then Begin
   c:=CCIndex(Copy(up,3,3));
   If c>=0 Then Begin cls:=C_DBCC;cc:=c;FindInstr:=True;Exit;End;
  End;
  If up[1]='S' Then Begin
   c:=CCIndex(Copy(up,2,3));
   If c>=0 Then Begin cls:=C_SCC;cc:=c;FindInstr:=True;Exit;End;
  End;
  If(Length(up)>=6)and(Copy(up,1,4)='TRAP')Then Begin
   c:=CCIndex(Copy(up,5,3));
   If c>=0 Then Begin cls:=C_TRAPCC;cc:=c;FindInstr:=True;Exit;End;
  End;
  { coprocesseur flottant : FBcc, FDBcc, FScc, FTRAPcc }
  If(up[1]='F')Then Begin
   If Copy(up,1,2)='FB' Then Begin
    c:=FCCIndex(Copy(up,3,5));
    If c>=0 Then Begin cls:=C_FBCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,3)='FDB' Then Begin
    c:=FCCIndex(Copy(up,4,5));
    If c>=0 Then Begin cls:=C_FDBCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,5)='FTRAP' Then Begin
    c:=FCCIndex(Copy(up,6,5));
    If c>=0 Then Begin cls:=C_FTRAPCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,2)='FS' Then Begin
    c:=FCCIndex(Copy(up,3,5));
    If c>=0 Then Begin cls:=C_FSCC;cc:=c;FindInstr:=True;Exit;End;
   End;
  End;
  { MMU : PBcc, PDBcc, PScc, PTRAPcc }
  If(up[1]='P')Then Begin
   If Copy(up,1,2)='PB' Then Begin
    c:=PCCIndex(Copy(up,3,3));
    If c>=0 Then Begin cls:=C_PBCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,3)='PDB' Then Begin
    c:=PCCIndex(Copy(up,4,3));
    If c>=0 Then Begin cls:=C_PDBCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,5)='PTRAP' Then Begin
    c:=PCCIndex(Copy(up,6,3));
    If c>=0 Then Begin cls:=C_PTRAPCC;cc:=c;FindInstr:=True;Exit;End;
   End;
   If Copy(up,1,2)='PS' Then Begin
    c:=PCCIndex(Copy(up,3,3));
    If c>=0 Then Begin cls:=C_PSCC;cc:=c;FindInstr:=True;Exit;End;
   End;
  End;
 End;
End;

{ ------------------------------------------------------------------------ }
{ Encodage des instructions                                                 }
{ ------------------------------------------------------------------------ }

Var
 gOps:Array[0..3] of TOp;
 gN:Longint;
 gSzRaw:Longint;   { 0 aucune, 1 B, 2 W, 4 L, 8 S, -1 invalide }

Function SzFromExt(Const e:String):Longint;
Begin
 If e='' Then SzFromExt:=0 Else
 If e='B' Then SzFromExt:=1 Else
 If e='W' Then SzFromExt:=2 Else
 If e='L' Then SzFromExt:=4 Else
 If e='S' Then SzFromExt:=8 Else
 If e='D' Then SzFromExt:=9 Else
 If e='X' Then SzFromExt:=10 Else
 If e='P' Then SzFromExt:=11 Else SzFromExt:=-1;
End;

{ Taille effective ; mask : bit 1 = B, bit 2 = W, bit 4 = L }
Function EffSz(dflt,mask:Longint):Longint;
Begin
 EffSz:=dflt;
 If gSzRaw=0 Then Exit;
 If(gSzRaw<0)or(gSzRaw=8)or((mask and gSzRaw)=0)Then Begin
  Error(Tr('Taille d''operande invalide pour cette instruction',
    'Invalid operand size for this instruction'));
  Exit;
 End;
 EffSz:=gSzRaw;
End;

Function SzCode(sz:Longint):Longint;
Begin
 Case sz of
  1:SzCode:=0;
  2:SzCode:=1;
  Else SzCode:=2;
 End;
End;

Function NeedOps(n:Longint):Boolean;
Begin
 NeedOps:=(gN=n);
 If gN<>n Then Error(Tr('Nombre d''operandes invalide',
   'Invalid number of operands'));
End;

Function FitsShort(d:Longint):Boolean;
Begin
 FitsShort:=(d>=-128)and(d<=127)and(d<>0);
End;

{ Deplacement d'une cible de branchement par rapport a base }
Function TargetDisp(Const t:TVal;base:Longint;Var isExt:Boolean):Longint;
Begin
 isExt:=False;
 TargetDisp:=0;
 If t.undef Then Exit;
 If t.sect=-2 Then Begin
  isExt:=True;
  TargetDisp:=t.v;
 End Else If t.sect=cursec Then TargetDisp:=t.v-base
 Else Error(Tr('Cible de branchement hors de la section courante',
   'Branch target outside current section'));
End;

Procedure DoBranch(cc:Longint);
Var
 t:TVal;
 pcop,base,d,need:Longint;
 sz:Longint;
 lvl:Byte;
 isExt,fits:Boolean;
 op:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 If gOps[0].kind<>OK_ABS Then Begin
  Error(Tr('Cible de branchement invalide','Invalid branch target'));
  Exit;
 End;
 t:=gOps[0].val;
 pcop:=PC;
 base:=pcop+2;
 op:=$6000 or (cc shl 8);
 sz:=gSzRaw;
 If sz=1 Then sz:=8;
 If(sz<0)or Not(sz in [0,2,4,8])Then Begin
  Error(Tr('Taille de branchement invalide','Invalid branch size'));
  Exit;
 End;
 d:=TargetDisp(t,base,isExt);
 If isExt Then Begin
  If(sz=8)Then Error(Tr('Branchement court vers un symbole externe impossible',
    'Short branch to external symbol impossible'));
  EmitW(op);
  AddXRef(t.ext,pcop+2,EXT_REF16);
  EmitW(d and $FFFF);
  Exit;
 End;
 fits:=FitsShort(d)or t.undef;
 If sz=4 Then Begin
  If cpu<CPU_68020 Then Begin
   Error(Tr('Branchement long requiert un 68020',
     'Long branch requires a 68020'));
   Exit;
  End;
  EmitW(op or $FF);
  EmitL(d);
  Exit;
 End;
 lvl:=1;
 If sz=8 Then Begin
  lvl:=0;
  If Not fits Then Begin
   Error(Tr('Branchement court hors limites','Short branch out of range'));
   fits:=True;
  End;
 End Else If opt.o1 Then Begin
  If fits Then need:=0 Else need:=1;
  lvl:=SiteLevel(need);
 End Else If(sz=0)and Not t.fwd and fits Then lvl:=0;
 If lvl=0 Then Begin
  If t.undef Then d:=1;
  EmitW(op or (d and $FF));
 End Else Begin
  If(Not t.undef)and((d<-32768)or(d>32767))Then Begin
   If cpu>=CPU_68020 Then Begin
    EmitW(op or $FF);
    EmitL(d);
    Exit;
   End;
   Error(Tr('Branchement hors limites','Branch out of range'));
  End;
  EmitW(op);
  EmitW(d and $FFFF);
 End;
End;

Procedure DoDbcc(cc:Longint);
Var
 pcop,d:Longint;
 isExt:Boolean;
 ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If gOps[0].kind<>OK_DN Then Begin
  Error(Tr('Registre de donnees attendu','Data register expected'));
  Exit;
 End;
 If gOps[1].kind<>OK_ABS Then Begin
  Error(Tr('Cible de branchement invalide','Invalid branch target'));
  Exit;
 End;
 pcop:=PC;
 d:=TargetDisp(gOps[1].val,pcop+2,isExt);
 EmitW($50C8 or (cc shl 8) or gOps[0].reg);
 If isExt Then AddXRef(gOps[1].val.ext,pcop+2,EXT_REF16)
 Else If(Not gOps[1].val.undef)and((d<-32768)or(d>32767))Then
  Error(Tr('Branchement hors limites','Branch out of range'));
 ea:=d;
 EmitW(ea and $FFFF);
End;

{ ADDA / SUBA / CMPA }
Procedure DoAdda(base,qbase:Longint);
Var
 sz,ea,opw:Longint;
Begin
 sz:=EffSz(2,6);
 If(qbase<>0)and opt.o and(gOps[0].kind=OK_IMM)and KnownAbs(gOps[0].val)and
   (gOps[0].val.v>=1)and(gOps[0].val.v<=8)Then Begin
  ea:=ResolveEA(gOps[1],M_AN);
  If ea<0 Then Exit;
  EmitW(qbase or ((gOps[0].val.v and 7)shl 9)or(SzCode(sz)shl 6)or ea);
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_ALL);
 If ea<0 Then Exit;
 opw:=base or (gOps[1].reg shl 9) or ea;
 If sz=4 Then opw:=opw or $01C0 Else opw:=opw or $00C0;
 EmitW(opw);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoQuickOp(qbase,sz:Longint);
Var
 ea:Longint;
 v:Longint;
Begin
 v:=gOps[0].val.v;
 If gOps[0].kind<>OK_IMM Then Begin
  Error(Tr('Operande immediat attendu','Immediate operand expected'));
  Exit;
 End;
 If(Not gOps[0].val.undef)and((v<1)or(v>8))Then Begin
  Error(Tr('ADDQ/SUBQ : valeur entre 1 et 8 requise',
    'ADDQ/SUBQ: value between 1 and 8 required'));
  Exit;
 End;
 If(sz=1)and(gOps[1].kind=OK_AN)Then Begin
  Error(Tr('Taille octet invalide avec un registre d''adresse',
    'Byte size invalid with an address register'));
  Exit;
 End;
 ea:=ResolveEA(gOps[1],M_ALT);
 If ea<0 Then Exit;
 EmitW(qbase or ((v and 7)shl 9)or(SzCode(sz)shl 6)or ea);
 EmitEAExt(gOps[1],sz);
End;

Procedure DoAddSub(idx:Longint);
Var
 sub,base,qbase,ibase,sz,ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sub:=InstrTab[idx].arg;
 base:=InstrTab[idx].op;
 qbase:=$5000+sub*$100;
 ibase:=$0600-sub*$200;
 sz:=EffSz(2,7);
 If gOps[1].kind=OK_AN Then Begin
  If sz=1 Then Begin
   Error(Tr('Taille octet invalide avec un registre d''adresse',
     'Byte size invalid with an address register'));
   Exit;
  End;
  DoAdda(base,qbase);
  Exit;
 End;
 If gOps[0].kind=OK_IMM Then Begin
  If opt.o and KnownAbs(gOps[0].val)and(gOps[0].val.v>=1)and(gOps[0].val.v<=8)
    Then Begin
   DoQuickOp(qbase,sz);
   Exit;
  End;
  ea:=ResolveEA(gOps[1],M_DATALT);
  If ea<0 Then Exit;
  EmitW(ibase or (SzCode(sz)shl 6)or ea);
  EmitImmValue(gOps[0].val,sz);
  EmitEAExt(gOps[1],sz);
  Exit;
 End;
 If gOps[1].kind=OK_DN Then Begin
  If(sz=1)and(gOps[0].kind=OK_AN)Then Begin
   Error(Tr('Taille octet invalide avec un registre d''adresse',
     'Byte size invalid with an address register'));
   Exit;
  End;
  ea:=ResolveEA(gOps[0],M_ALL);
  If ea<0 Then Exit;
  EmitW(base or (gOps[1].reg shl 9)or(SzCode(sz)shl 6)or ea);
  EmitEAExt(gOps[0],sz);
 End Else If gOps[0].kind=OK_DN Then Begin
  ea:=ResolveEA(gOps[1],M_MEMALT);
  If ea<0 Then Exit;
  EmitW(base or (gOps[0].reg shl 9)or((4+SzCode(sz))shl 6)or ea);
  EmitEAExt(gOps[1],sz);
 End Else Error(Tr('Combinaison d''operandes invalide',
   'Invalid operand combination'));
End;

Procedure DoImmToSrCcr(ibase:Longint);
Begin
 If gOps[1].kind=OK_CCR Then Begin
  EmitW(ibase or $3C);
  EmitImmValue(gOps[0].val,1);
 End Else Begin
  EmitW(ibase or $7C);
  EmitImmValue(gOps[0].val,2);
 End;
End;

Procedure DoLogic(idx:Longint);
Var
 which,base,ibase,sz,ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 which:=InstrTab[idx].arg;
 base:=InstrTab[idx].op;
 Case which of
  0:ibase:=$0200;
  1:ibase:=$0000;
  Else ibase:=$0A00;
 End;
 sz:=EffSz(2,7);
 If(gOps[0].kind=OK_IMM)and(gOps[1].kind in [OK_CCR,OK_SR])Then Begin
  DoImmToSrCcr(ibase);
  Exit;
 End;
 If gOps[0].kind=OK_IMM Then Begin
  ea:=ResolveEA(gOps[1],M_DATALT);
  If ea<0 Then Exit;
  EmitW(ibase or (SzCode(sz)shl 6)or ea);
  EmitImmValue(gOps[0].val,sz);
  EmitEAExt(gOps[1],sz);
  Exit;
 End;
 If which=2 Then Begin
  If gOps[0].kind<>OK_DN Then Begin
   Error(Tr('EOR requiert un registre de donnees source',
     'EOR requires a source data register'));
   Exit;
  End;
  ea:=ResolveEA(gOps[1],M_DATALT);
  If ea<0 Then Exit;
  EmitW(base or (gOps[0].reg shl 9)or((4+SzCode(sz))shl 6)or ea);
  EmitEAExt(gOps[1],sz);
  Exit;
 End;
 If gOps[1].kind=OK_DN Then Begin
  ea:=ResolveEA(gOps[0],M_DATA);
  If ea<0 Then Exit;
  EmitW(base or (gOps[1].reg shl 9)or(SzCode(sz)shl 6)or ea);
  EmitEAExt(gOps[0],sz);
 End Else If gOps[0].kind=OK_DN Then Begin
  ea:=ResolveEA(gOps[1],M_MEMALT);
  If ea<0 Then Exit;
  EmitW(base or (gOps[0].reg shl 9)or((4+SzCode(sz))shl 6)or ea);
  EmitEAExt(gOps[1],sz);
 End Else Error(Tr('Combinaison d''operandes invalide',
   'Invalid operand combination'));
End;

{ CMPI accepte aussi les modes relatifs au PC a partir du 68010 }
Function CmpiModes:Longint;
Begin
 If cpu>=CPU_68010 Then CmpiModes:=M_DATALT or M_PCD or M_PCI
   Else CmpiModes:=M_DATALT;
End;

Procedure DoCmp;
Var
 sz,ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,7);
 If gOps[1].kind=OK_AN Then Begin
  If sz=1 Then Begin
   Error(Tr('Taille octet invalide avec un registre d''adresse',
     'Byte size invalid with an address register'));
   Exit;
  End;
  DoAdda($B000,0);
  Exit;
 End;
 If gOps[0].kind=OK_IMM Then Begin
  If opt.o and KnownAbs(gOps[0].val)and(gOps[0].val.v=0)Then Begin
   ea:=ResolveEA(gOps[1],M_DATALT);
   If ea<0 Then Exit;
   EmitW($4A00 or (SzCode(sz)shl 6)or ea);
   EmitEAExt(gOps[1],sz);
   Exit;
  End;
  ea:=ResolveEA(gOps[1],CmpiModes);
  If ea<0 Then Exit;
  EmitW($0C00 or (SzCode(sz)shl 6)or ea);
  EmitImmValue(gOps[0].val,sz);
  EmitEAExt(gOps[1],sz);
  Exit;
 End;
 If(gOps[0].kind=OK_POST)and(gOps[1].kind=OK_POST)Then Begin
  EmitW($B108 or (gOps[1].reg shl 9)or(SzCode(sz)shl 6)or gOps[0].reg);
  Exit;
 End;
 If gOps[1].kind=OK_DN Then Begin
  If(sz=1)and(gOps[0].kind=OK_AN)Then Begin
   Error(Tr('Taille octet invalide avec un registre d''adresse',
     'Byte size invalid with an address register'));
   Exit;
  End;
  ea:=ResolveEA(gOps[0],M_ALL);
  If ea<0 Then Exit;
  EmitW($B000 or (gOps[1].reg shl 9)or(SzCode(sz)shl 6)or ea);
  EmitEAExt(gOps[0],sz);
 End Else Error(Tr('Combinaison d''operandes invalide',
   'Invalid operand combination'));
End;

Procedure DoImmOp(idx:Longint);
Var
 sz,ea,base:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,7);
 base:=InstrTab[idx].op;
 If gOps[0].kind<>OK_IMM Then Begin
  Error(Tr('Operande immediat attendu','Immediate operand expected'));
  Exit;
 End;
 If(InstrTab[idx].arg=1)and(gOps[1].kind in [OK_CCR,OK_SR])Then Begin
  DoImmToSrCcr(base);
  Exit;
 End;
 If base=$0C00 Then ea:=ResolveEA(gOps[1],CmpiModes) Else ea:=ResolveEA(gOps[1],
   M_DATALT);
 If ea<0 Then Exit;
 EmitW(base or (SzCode(sz)shl 6)or ea);
 EmitImmValue(gOps[0].val,sz);
 EmitEAExt(gOps[1],sz);
End;

Procedure DoMoveGeneral(sz:Longint);
Var
 eas,ead,db:Longint;
 sb:Longint;
Begin
 If(gOps[0].kind=OK_IMM)and opt.o and(sz=4)and(gOps[1].kind=OK_DN)and
   KnownAbs(gOps[0].val)and(gOps[0].val.v>=-128)and(gOps[0].val.v<=127)Then
     Begin
  EmitW($7000 or (gOps[1].reg shl 9)or(gOps[0].val.v and $FF));
  Exit;
 End;
 If(sz=1)and((gOps[0].kind=OK_AN)or(gOps[1].kind=OK_AN))Then Begin
  Error(Tr('Taille octet invalide avec un registre d''adresse',
    'Byte size invalid with an address register'));
  Exit;
 End;
 eas:=ResolveEA(gOps[0],M_ALL);
 If eas<0 Then Exit;
 If gOps[1].kind=OK_AN Then ead:=ResolveEA(gOps[1],
   M_AN) Else ead:=ResolveEA(gOps[1],M_DATALT);
 If ead<0 Then Exit;
 db:=((ead and 7)shl 9)or((ead shr 3)shl 6);
 Case sz of
  1:sb:=$1000;
  2:sb:=$3000;
  Else sb:=$2000;
 End;
 EmitW(sb or db or eas);
 EmitEAExt(gOps[0],sz);
 EmitEAExt(gOps[1],sz);
End;

Procedure DoMove;
Var
 sz,ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,7);
 If gOps[1].kind=OK_SR Then Begin
  ea:=ResolveEA(gOps[0],M_DATA);
  If ea<0 Then Exit;
  EmitW($46C0 or ea);
  EmitEAExt(gOps[0],2);
  Exit;
 End;
 If gOps[1].kind=OK_CCR Then Begin
  ea:=ResolveEA(gOps[0],M_DATA);
  If ea<0 Then Exit;
  EmitW($44C0 or ea);
  EmitEAExt(gOps[0],2);
  Exit;
 End;
 If gOps[0].kind=OK_SR Then Begin
  ea:=ResolveEA(gOps[1],M_DATALT);
  If ea<0 Then Exit;
  EmitW($40C0 or ea);
  EmitEAExt(gOps[1],2);
  Exit;
 End;
 If gOps[0].kind=OK_CCR Then Begin
  If cpu<CPU_68010 Then Begin
   Error(Tr('MOVE from CCR requiert un 68010 ou plus',
     'MOVE from CCR requires a 68010 or later'));
   Exit;
  End;
  ea:=ResolveEA(gOps[1],M_DATALT);
  If ea<0 Then Exit;
  EmitW($42C0 or ea);
  EmitEAExt(gOps[1],2);
  Exit;
 End;
 If(gOps[0].kind=OK_USP)and(gOps[1].kind=OK_AN)Then Begin
  EmitW($4E68 or gOps[1].reg);
  Exit;
 End;
 If(gOps[1].kind=OK_USP)and(gOps[0].kind=OK_AN)Then Begin
  EmitW($4E60 or gOps[0].reg);
  Exit;
 End;
 If(gOps[0].kind in [OK_USP,OK_CTRL,OK_LIST])or(gOps[1].kind in [OK_USP,OK_CTRL,
   OK_LIST])Then Begin
  Error(Tr('Operande invalide pour MOVE','Invalid operand for MOVE'));
  Exit;
 End;
 If(gOps[1].kind=OK_AN)and(sz=1)Then Begin
  Error(Tr('Taille octet invalide avec un registre d''adresse',
    'Byte size invalid with an address register'));
  Exit;
 End;
 DoMoveGeneral(sz);
End;

Procedure DoMovea;
Var
 sz:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,6);
 If gOps[1].kind<>OK_AN Then Begin
  Error(Tr('MOVEA requiert un registre d''adresse destination',
    'MOVEA requires a destination address register'));
  Exit;
 End;
 DoMoveGeneral(sz);
End;

Procedure DoMoveq;
Var
 v:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If(gOps[0].kind<>OK_IMM)or(gOps[1].kind<>OK_DN)Then Begin
  Error(Tr('MOVEQ #imm,Dn attendu','MOVEQ #imm,Dn expected'));
  Exit;
 End;
 NoReloc(gOps[0].val);
 v:=gOps[0].val.v;
 If(Not gOps[0].val.undef)and((v<-128)or(v>255))Then Begin
  Error(Tr('Valeur MOVEQ hors limites (-128..255)',
    'MOVEQ value out of range (-128..255)'));
  Exit;
 End;
 EmitW($7000 or (gOps[1].reg shl 9)or(v and $FF));
End;

Function MaskOfOp(Const op:TOp;Var mask:Longint):Boolean;
Begin
 MaskOfOp:=True;
 If op.kind=OK_LIST Then mask:=op.mask Else
 If op.kind=OK_DN Then mask:=1 shl op.reg Else
 If op.kind=OK_AN Then mask:=1 shl (8+op.reg) Else MaskOfOp:=False;
End;

Function ReverseMask(m:Longint):Longint;
Var
 i,r:Longint;
Begin
 r:=0;
 For i:=0 to 15 do If(m and (1 shl i))<>0 Then r:=r or (1 shl (15-i));
 ReverseMask:=r;
End;

Procedure DoMovem;
Var
 sz,ea,mask:Longint;
 toMem:Boolean;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,6);
 toMem:=gOps[0].kind in [OK_LIST,OK_DN,OK_AN];
 If toMem Then Begin
  If Not MaskOfOp(gOps[0],mask)Then Exit;
  ea:=ResolveEA(gOps[1],M_IND or M_PRE or M_DISP or M_IDX or M_ABSW or M_ABSL);
  If ea<0 Then Exit;
  If gOps[1].kind=OK_PRE Then mask:=ReverseMask(mask);
  EmitW($4880 or (Ord(sz=4)shl 6)or ea);
  EmitW(mask);
  EmitEAExt(gOps[1],sz);
 End Else Begin
  If Not MaskOfOp(gOps[1],mask)Then Begin
   Error(Tr('Liste de registres attendue','Register list expected'));
   Exit;
  End;
  ea:=ResolveEA(gOps[0],M_CONTROL or M_POST);
  If ea<0 Then Exit;
  EmitW($4C80 or (Ord(sz=4)shl 6)or ea);
  EmitW(mask);
  EmitEAExt(gOps[0],sz);
 End;
End;

Procedure DoMovep;
Var
 sz,opm,dn,an:Longint;
 mem:Integer;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,6);
 If gOps[0].kind=OK_DN Then mem:=1 Else mem:=0;
 If(gOps[mem].kind<>OK_DISP)and(gOps[mem].kind<>OK_IND)Then Begin
  Error(Tr('MOVEP requiert le mode d(An)','MOVEP requires the d(An) mode'));
  Exit;
 End;
 If gOps[1-mem].kind<>OK_DN Then Begin
  Error(Tr('MOVEP requiert un registre de donnees',
    'MOVEP requires a data register'));
  Exit;
 End;
 dn:=gOps[1-mem].reg;
 an:=gOps[mem].reg;
 If mem=0 Then opm:=$0108 Else opm:=$0188;
 If sz=4 Then opm:=opm or $40;
 EmitW(opm or (dn shl 9)or an);
 If gOps[mem].kind=OK_DISP Then EmitDisp16(gOps[mem].val) Else EmitW(0);
End;

Procedure DoMovec;
Var
 w:Longint;
 r,c:Integer;
Begin
 If Not NeedOps(2)Then Exit;
 If cpu<CPU_68010 Then Begin
  Error(Tr('MOVEC requiert un 68010 ou plus',
    'MOVEC requires a 68010 or later'));
  Exit;
 End;
 If gOps[0].kind in [OK_CTRL,OK_USP]Then Begin
  c:=0;r:=1;
  If Not(gOps[1].kind in [OK_DN,OK_AN])Then Begin
   Error(Tr('Registre general attendu','General register expected'));
   Exit;
  End;
  EmitW($4E7A);
 End Else Begin
  c:=1;r:=0;
  If(Not(gOps[1].kind in [OK_CTRL,OK_USP]))or Not(gOps[0].kind in [OK_DN,
    OK_AN])Then Begin
   Error(Tr('Operandes MOVEC invalides','Invalid MOVEC operands'));
   Exit;
  End;
  EmitW($4E7B);
 End;
 w:=gOps[r].reg;
 If gOps[r].kind=OK_AN Then w:=w+8;
 EmitW((w shl 12)or gOps[c].ctrl);
End;

Procedure DoMoves;
Var
 sz,ea,w,r,m:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If cpu<CPU_68010 Then Begin
  Error(Tr('MOVES requiert un 68010 ou plus',
    'MOVES requires a 68010 or later'));
  Exit;
 End;
 sz:=EffSz(2,7);
 If gOps[0].kind in [OK_DN,OK_AN]Then Begin
  r:=0;m:=1;
 End Else Begin
  r:=1;m:=0;
 End;
 ea:=ResolveEA(gOps[m],M_MEMALT);
 If ea<0 Then Exit;
 w:=gOps[r].reg;
 If gOps[r].kind=OK_AN Then w:=w+8;
 w:=w shl 12;
 If r=0 Then w:=w or $0800;
 EmitW($0E00 or (SzCode(sz)shl 6)or ea);
 EmitW(w);
 EmitEAExt(gOps[m],sz);
End;

Procedure DoUnary(idx:Longint);
Var
 sz,ea,allowed:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 sz:=EffSz(2,7);
 allowed:=M_DATALT;
 If(InstrTab[idx].arg=1)and(cpu>=CPU_68020)Then allowed:=M_ALL;
 ea:=ResolveEA(gOps[0],allowed);
 If ea<0 Then Exit;
 EmitW(InstrTab[idx].op or (SzCode(sz)shl 6)or ea);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoUnaryB(idx:Longint);
Var
 ea:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 EffSz(1,1);
 ea:=ResolveEA(gOps[0],M_DATALT);
 If ea<0 Then Exit;
 EmitW(InstrTab[idx].op or ea);
 EmitEAExt(gOps[0],1);
End;

Procedure DoShift(idx:Longint);
Var
 typ,dir,sz,ea,cnt,irb:Longint;
 memForm:Boolean;
Begin
 typ:=InstrTab[idx].op;
 dir:=InstrTab[idx].arg;
 sz:=EffSz(2,7);
 memForm:=False;
 If gN=1 Then Begin
  If gOps[0].kind=OK_DN Then Begin
   EmitW($E000 or (1 shl 9)or(dir shl 8)or(SzCode(sz)shl 6)or(typ shl 3)
     or gOps[0].reg);
   Exit;
  End;
  memForm:=True;
 End Else If gN=2 Then Begin
  If(gOps[0].kind=OK_IMM)and(gOps[1].kind<>OK_DN)and KnownAbs(gOps[0].val)
    and(gOps[0].val.v=1)Then Begin
   memForm:=True;
   gOps[0]:=gOps[1];
  End;
 End Else Begin
  Error(Tr('Nombre d''operandes invalide','Invalid number of operands'));
  Exit;
 End;
 If memForm Then Begin
  If(sz<>2)and(gSzRaw<>0)
    Then Error(Tr('Les decalages memoire sont de taille mot',
    'Memory shifts are word sized'));
  ea:=ResolveEA(gOps[0],M_MEMALT);
  If ea<0 Then Exit;
  EmitW($E0C0 or (typ shl 9)or(dir shl 8)or ea);
  EmitEAExt(gOps[0],2);
  Exit;
 End;
 If gOps[1].kind<>OK_DN Then Begin
  Error(Tr('Registre de donnees destination requis',
    'Destination data register required'));
  Exit;
 End;
 If gOps[0].kind=OK_DN Then Begin
  cnt:=gOps[0].reg;
  irb:=1;
 End Else If gOps[0].kind=OK_IMM Then Begin
  NoReloc(gOps[0].val);
  cnt:=gOps[0].val.v;
  If(Not gOps[0].val.undef)and((cnt<1)or(cnt>8))Then Begin
   Error(Tr('Compteur de decalage entre 1 et 8 requis',
     'Shift count between 1 and 8 required'));
   Exit;
  End;
  cnt:=cnt and 7;
  irb:=0;
 End Else Begin
  Error(Tr('Operande de decalage invalide','Invalid shift operand'));
  Exit;
 End;
 EmitW($E000 or (cnt shl 9)or(dir shl 8)or(SzCode(sz)shl 6)or(irb shl 5)
   or(typ shl 3)or gOps[1].reg);
End;

Procedure DoBit(idx:Longint);
Var
 typ,ea,allowed,v:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 typ:=InstrTab[idx].op;
 If(gSzRaw<>0)and(gSzRaw<>1)and(gSzRaw<>4)
   Then Error(Tr('Taille invalide pour une instruction de bit',
   'Invalid size for a bit instruction'));
 If gOps[0].kind=OK_DN Then Begin
  If typ=0 Then allowed:=M_DATA Else allowed:=M_DATALT;
  ea:=ResolveEA(gOps[1],allowed);
  If ea<0 Then Exit;
  EmitW($0100 or (gOps[0].reg shl 9)or(typ shl 6)or ea);
  EmitEAExt(gOps[1],1);
 End Else If gOps[0].kind=OK_IMM Then Begin
  If typ=0 Then allowed:=M_DATA and Not M_IMM Else allowed:=M_DATALT;
  ea:=ResolveEA(gOps[1],allowed);
  If ea<0 Then Exit;
  NoReloc(gOps[0].val);
  v:=gOps[0].val.v;
  If(Not gOps[0].val.undef)and((v<0)or(v>255))
    Then Error(Tr('Numero de bit hors limites','Bit number out of range'));
  EmitW($0800 or (typ shl 6)or ea);
  EmitW(v and $FF);
  EmitEAExt(gOps[1],1);
 End Else Error(Tr('Operande de bit invalide','Invalid bit operand'));
End;

Procedure DoMulDiv(idx:Longint);
Var
 ea,arg,signed,isdiv,w,first,second,is64:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 arg:=InstrTab[idx].arg;
 signed:=arg and 1;
 isdiv:=(arg shr 1)and 1;
 If gSzRaw=4 Then Begin
  If cpu<CPU_68020 Then Begin
   Error(Tr('Multiplication/division 32 bits requiert un 68020',
     '32-bit multiply/divide requires a 68020'));
   Exit;
  End;
  If gOps[1].kind<>OK_DN Then Begin
   Error(Tr('Registre de donnees destination requis',
     'Destination data register required'));
   Exit;
  End;
  ea:=ResolveEA(gOps[0],M_DATA);
  If ea<0 Then Exit;
  If gOps[1].hasPair Then Begin
   first:=gOps[1].reg;
   second:=gOps[1].pair and 7;
   is64:=1;
  End Else Begin
   first:=gOps[1].reg;
   second:=gOps[1].reg;
   is64:=0;
  End;
  If isdiv=0 Then Begin
   { MUL.L : Dl dans les bits 14-12, Dh dans les bits 2-0 }
   If is64=1 Then w:=(second shl 12)or(signed shl 11)or $0400 or first
             Else w:=(first shl 12)or(signed shl 11);
   EmitW($4C00 or ea);
  End Else Begin
   { DIV.L : Dq dans les bits 14-12, Dr dans les bits 2-0 }
   If is64=1 Then w:=(second shl 12)or(signed shl 11)or $0400 or first
             Else w:=(first shl 12)or(signed shl 11)or first;
   EmitW($4C40 or ea);
  End;
  EmitW(w);
  EmitEAExt(gOps[0],4);
  Exit;
 End;
 EffSz(2,2);
 If gOps[1].kind<>OK_DN Then Begin
  Error(Tr('Registre de donnees destination requis',
    'Destination data register required'));
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_DATA);
 If ea<0 Then Exit;
 EmitW(InstrTab[idx].op or (gOps[1].reg shl 9)or ea);
 EmitEAExt(gOps[0],2);
End;

Procedure DoDivl(idx:Longint);
Var
 ea,w,signed:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If cpu<CPU_68020 Then Begin
  Error(Tr('Division 32 bits requiert un 68020',
    '32-bit divide requires a 68020'));
  Exit;
 End;
 signed:=InstrTab[idx].arg;
 If(gOps[1].kind<>OK_DN)or Not gOps[1].hasPair Then Begin
  Error(Tr('Dr:Dq attendu comme destination','Dr:Dq expected as destination'));
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_DATA);
 If ea<0 Then Exit;
 w:=((gOps[1].pair and 7)shl 12)or(signed shl 11)or gOps[1].reg;
 EmitW($4C40 or ea);
 EmitW(w);
 EmitEAExt(gOps[0],4);
End;

Procedure DoExt(idx:Longint);
Var
 sz:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 If gOps[0].kind<>OK_DN Then Begin
  Error(Tr('Registre de donnees attendu','Data register expected'));
  Exit;
 End;
 If InstrTab[idx].arg=1 Then Begin
  If cpu<CPU_68020 Then Begin
   Error(Tr('EXTB requiert un 68020','EXTB requires a 68020'));
   Exit;
  End;
  EffSz(4,4);
  EmitW($49C0 or gOps[0].reg);
  Exit;
 End;
 sz:=EffSz(2,6);
 If sz=2 Then EmitW($4880 or gOps[0].reg) Else EmitW($48C0 or gOps[0].reg);
End;

Procedure DoImmOnly(opc,sz:Longint);
Begin
 EmitW(opc);
 EmitImmValue(gOps[0].val,sz);
End;

Procedure DoCtrl1(idx:Longint);
Var
 ea,need,d,pcop,cc,arg:Longint;
 lvl:Byte;
 t:TVal;
Begin
 If Not NeedOps(1)Then Exit;
 arg:=InstrTab[idx].arg;
 If opt.o1 and(arg<2)and(gOps[0].kind=OK_ABS)and(gOps[0].absSize=0)Then Begin
  t:=gOps[0].val;
  pcop:=PC;
  d:=0;
  If t.undef Then need:=0 Else If t.sect<>cursec Then need:=2
  Else Begin
   d:=t.v-(pcop+2);
   If FitsShort(d)Then need:=0 Else If(d>=-32768)and(d<=32767)Then need:=1
     Else need:=2;
  End;
  lvl:=SiteLevel(need);
  If lvl<2 Then Begin
   cc:=arg;
   If lvl=0 Then Begin
    If t.undef Then d:=1;
    EmitW($6000 or (cc shl 8)or(d and $FF));
   End Else Begin
    EmitW($6000 or (cc shl 8));
    EmitW(d and $FFFF);
   End;
   Exit;
  End;
 End;
 ea:=ResolveEA(gOps[0],M_CONTROL);
 If ea<0 Then Exit;
 EmitW(InstrTab[idx].op or ea);
 EmitEAExt(gOps[0],4);
End;

Procedure DoLea;
Var
 ea:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If gOps[1].kind<>OK_AN Then Begin
  Error(Tr('LEA requiert un registre d''adresse destination',
    'LEA requires a destination address register'));
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_CONTROL);
 If ea<0 Then Exit;
 EmitW($41C0 or (gOps[1].reg shl 9)or ea);
 EmitEAExt(gOps[0],4);
End;

Procedure DoChk;
Var
 ea,sz:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 sz:=EffSz(2,6);
 If(sz=4)and(cpu<CPU_68020)Then Begin
  Error(Tr('CHK.L requiert un 68020','CHK.L requires a 68020'));
  Exit;
 End;
 If gOps[1].kind<>OK_DN Then Begin
  Error(Tr('Registre de donnees destination requis',
    'Destination data register required'));
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_DATA);
 If ea<0 Then Exit;
 If sz=4 Then EmitW($4100 or (gOps[1].reg shl 9)or ea) Else EmitW($4180
   or (gOps[1].reg shl 9)or ea);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoExg;
Var
 a,b:Integer;
Begin
 If Not NeedOps(2)Then Exit;
 EffSz(4,4);
 a:=gOps[0].kind;
 b:=gOps[1].kind;
 If(a=OK_DN)and(b=OK_DN)Then EmitW($C140 or (gOps[0].reg shl 9)or gOps[1].reg)
 Else If(a=OK_AN)and(b=OK_AN)Then EmitW($C148 or (gOps[0].reg shl 9)
   or gOps[1].reg)
 Else If(a=OK_DN)and(b=OK_AN)Then EmitW($C188 or (gOps[0].reg shl 9)
   or gOps[1].reg)
 Else If(a=OK_AN)and(b=OK_DN)Then EmitW($C188 or (gOps[1].reg shl 9)
   or gOps[0].reg)
 Else Error(Tr('Operandes EXG invalides','Invalid EXG operands'));
End;

Procedure DoBcdx(idx:Longint);
Var
 sz,op:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 op:=InstrTab[idx].op;
 If InstrTab[idx].arg=0 Then Begin
  sz:=EffSz(1,1);
  op:=op or 0;
 End Else Begin
  sz:=EffSz(2,7);
  op:=op or (SzCode(sz)shl 6);
 End;
 If(gOps[0].kind=OK_DN)and(gOps[1].kind=OK_DN)Then
  EmitW(op or (gOps[1].reg shl 9)or gOps[0].reg)
 Else If(gOps[0].kind=OK_PRE)and(gOps[1].kind=OK_PRE)Then
  EmitW(op or $0008 or (gOps[1].reg shl 9)or gOps[0].reg)
 Else Error(Tr('Operandes invalides (Dy,Dx ou -(Ay),-(Ax) attendus)',
   'Invalid operands (Dy,Dx or -(Ay),-(Ax) expected)'));
End;

Function BfSpec(Const op:TOp):Longint;
Var
 w:Longint;
Begin
 w:=0;
 If op.bfOffReg Then w:=w or $0800 or ((op.bfOff and 7)shl 6)
  Else w:=w or ((op.bfOff and 31)shl 6);
 If op.bfWidReg Then w:=w or $0020 or (op.bfWid and 7)
  Else w:=w or (op.bfWid and 31);
 BfSpec:=w;
End;

Procedure DoBitfield(idx:Longint);
Var
 form,ea,m,dn,allowed:Longint;
Begin
 If cpu<CPU_68020 Then Begin
  Error(Tr('Instruction de champ de bits : 68020 requis',
    'Bit field instruction: 68020 required'));
  Exit;
 End;
 form:=InstrTab[idx].arg;
 Case form of
  0,3:Begin
   If Not NeedOps(1)Then Exit;
   m:=0;dn:=-1;
  End;
  1:Begin
   If Not NeedOps(2)Then Exit;
   m:=0;
   dn:=gOps[1].reg;
   If gOps[1].kind<>OK_DN Then Begin
    Error(Tr('Registre de donnees destination requis',
      'Destination data register required'));
    Exit;
   End;
  End;
  Else Begin
   If Not NeedOps(2)Then Exit;
   m:=1;
   dn:=gOps[0].reg;
   If gOps[0].kind<>OK_DN Then Begin
    Error(Tr('Registre de donnees source requis',
      'Source data register required'));
    Exit;
   End;
  End;
 End;
 If Not gOps[m].hasBF Then Begin
  Error(Tr('Champ de bits {offset:largeur} attendu',
    'Bit field {offset:width} expected'));
  Exit;
 End;
 If form in [0,1]Then allowed:=M_DN or M_CONTROL
  Else allowed:=M_DN or (M_CONTROL and Not (M_PCD or M_PCI));
 ea:=ResolveEA(gOps[m],allowed);
 If ea<0 Then Exit;
 EmitW(InstrTab[idx].op or ea);
 If dn>=0 Then EmitW(BfSpec(gOps[m])or (dn shl 12)) Else EmitW(BfSpec(gOps[m]));
 EmitEAExt(gOps[m],4);
End;

Procedure DoCas;
Var
 sz,ea:Longint;
Begin
 If Not NeedOps(3)Then Exit;
 If cpu<CPU_68020 Then Begin
  Error(Tr('CAS requiert un 68020','CAS requires a 68020'));
  Exit;
 End;
 sz:=EffSz(2,7);
 If(gOps[0].kind<>OK_DN)or(gOps[1].kind<>OK_DN)Then Begin
  Error(Tr('CAS Dc,Du,<ea> attendu','CAS Dc,Du,<ea> expected'));
  Exit;
 End;
 ea:=ResolveEA(gOps[2],M_MEMALT);
 If ea<0 Then Exit;
 EmitW($08C0 or ((SzCode(sz)+1)shl 9)or ea);
 EmitW((gOps[1].reg shl 6)or gOps[0].reg);
 EmitEAExt(gOps[2],sz);
End;

Procedure DoCmp2(idx:Longint);
Var
 sz,ea,w:Longint;
Begin
 If Not NeedOps(2)Then Exit;
 If cpu<CPU_68020 Then Begin
  Error(Tr('CMP2/CHK2 requiert un 68020','CMP2/CHK2 requires a 68020'));
  Exit;
 End;
 sz:=EffSz(2,7);
 If Not(gOps[1].kind in [OK_DN,OK_AN])Then Begin
  Error(Tr('Registre general attendu','General register expected'));
  Exit;
 End;
 ea:=ResolveEA(gOps[0],M_CONTROL);
 If ea<0 Then Exit;
 w:=gOps[1].reg;
 If gOps[1].kind=OK_AN Then w:=w+8;
 w:=w shl 12;
 If InstrTab[idx].arg=1 Then w:=w or $0800;
 EmitW($00C0 or (SzCode(sz)shl 9)or ea);
 EmitW(w);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoPack(idx:Longint);
Begin
 If Not NeedOps(3)Then Exit;
 If cpu<CPU_68020 Then Begin
  Error(Tr('PACK/UNPK requiert un 68020','PACK/UNPK requires a 68020'));
  Exit;
 End;
 If gOps[2].kind<>OK_IMM Then Begin
  Error(Tr('Ajustement immediat attendu','Immediate adjustment expected'));
  Exit;
 End;
 If(gOps[0].kind=OK_DN)and(gOps[1].kind=OK_DN)Then
  EmitW(InstrTab[idx].op or (gOps[1].reg shl 9)or gOps[0].reg)
 Else If(gOps[0].kind=OK_PRE)and(gOps[1].kind=OK_PRE)Then
  EmitW(InstrTab[idx].op or $0008 or (gOps[1].reg shl 9)or gOps[0].reg)
 Else Begin
  Error(Tr('Operandes invalides','Invalid operands'));
  Exit;
 End;
 EmitImmValue(gOps[2].val,2);
End;

{ ------------------------------------------------------------------------ }
{ Coprocesseur flottant 68881/68882                                        }
{ ------------------------------------------------------------------------ }

Function FpuOk:Boolean;
Begin
 FpuOk:=(cpu>=CPU_68020)or fpuFlag;
 If Not((cpu>=CPU_68020)or fpuFlag)Then
  Error(Tr('Instruction FPU : utilisez MC68881 ou MC68882',
           'FPU instruction: use MC68881 or MC68882'));
End;

Function MmuOk:Boolean;
Begin
 MmuOk:=(cpu>=CPU_68020)or mmuFlag;
 If Not((cpu>=CPU_68020)or mmuFlag)Then
  Error(Tr('Instruction MMU : utilisez MC68851 ou MC68030',
           'MMU instruction: use MC68851 or MC68030'));
End;

{ Code de format source/destination : L=0 S=1 X=2 P=3 W=4 D=5 B=6 ; -1
  invalide }
Function FpFmt(sz:Longint):Longint;
Begin
 Case sz of
  0,10:FpFmt:=2;
  4:FpFmt:=0;
  8:FpFmt:=1;
  11:FpFmt:=3;
  2:FpFmt:=4;
  9:FpFmt:=5;
  1:FpFmt:=6;
  Else Begin
   Error(Tr('Taille invalide pour une instruction FPU',
     'Invalid size for an FPU instruction'));
   FpFmt:=2;
  End;
 End;
End;

Function FpSz(sz:Longint):Longint;
Begin
 If sz=0 Then FpSz:=10 Else FpSz:=sz;
End;

Function FpSrcModes(fmt:Longint):Longint;
Begin
 Case fmt of
  0,1,4:FpSrcModes:=M_DATA or M_AN;
  6:FpSrcModes:=M_DATA;
  Else FpSrcModes:=M_DATA and Not M_DN;
 End;
End;

Function FpDstModes(fmt:Longint):Longint;
Begin
 If fmt in [0,1,4,6]Then FpDstModes:=M_DATALT Else FpDstModes:=M_MEMALT;
End;

Procedure DoFArith(idx:Longint);
Var
 opm,fmt,ea,sz,srcReg:Longint;
 mono:Boolean;
Begin
 If Not FpuOk Then Exit;
 opm:=InstrTab[idx].op;
 mono:=InstrTab[idx].arg=1;
 If(gN<1)or(gN>2)or((gN=1)and Not mono)Then Begin
  Error(Tr('Nombre d''operandes invalide','Invalid number of operands'));
  Exit;
 End;
 If gN=1 Then Begin
  If gOps[0].kind<>OK_FPREG Then Begin
   Error(Tr('Registre FP destination requis',
     'FP destination register required'));
   Exit;
  End;
  gOps[1]:=gOps[0];
 End;
 If gOps[1].kind<>OK_FPREG Then Begin
  Error(Tr('Registre FP destination requis',
    'FP destination register required'));
  Exit;
 End;
 If gOps[0].kind=OK_FPREG Then Begin
  If(gSzRaw<>0)and(gSzRaw<>10)
    Then Error(Tr('Taille X requise entre registres FP',
    'Size X required between FP registers'));
  srcReg:=gOps[0].reg;
  EmitW($F200);
  EmitW((srcReg shl 10)or(gOps[1].reg shl 7)or opm);
  Exit;
 End;
 sz:=FpSz(gSzRaw);
 fmt:=FpFmt(sz);
 ea:=ResolveEA(gOps[0],FpSrcModes(fmt));
 If ea<0 Then Exit;
 EmitW($F200 or ea);
 EmitW($4000 or (fmt shl 10)or(gOps[1].reg shl 7)or opm);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoFTst;
Var
 fmt,ea,sz:Longint;
Begin
 If Not FpuOk Then Exit;
 If Not NeedOps(1)Then Exit;
 If gOps[0].kind=OK_FPREG Then Begin
  EmitW($F200);
  EmitW((gOps[0].reg shl 10)or $3A);
  Exit;
 End;
 sz:=FpSz(gSzRaw);
 fmt:=FpFmt(sz);
 ea:=ResolveEA(gOps[0],FpSrcModes(fmt));
 If ea<0 Then Exit;
 EmitW($F200 or ea);
 EmitW($4000 or (fmt shl 10)or $3A);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoFSinCos;
Var
 fmt,ea,sz:Longint;
Begin
 If Not FpuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 If(gOps[1].kind<>OK_FPREG)or Not gOps[1].hasPair Then Begin
  Error(Tr('FSINCOS <ea>,FPc:FPs attendu','FSINCOS <ea>,FPc:FPs expected'));
  Exit;
 End;
 If gOps[0].kind=OK_FPREG Then Begin
  EmitW($F200);
  EmitW((gOps[0].reg shl 10)or(gOps[1].pair shl 7)or $30 or gOps[1].reg);
  Exit;
 End;
 sz:=FpSz(gSzRaw);
 fmt:=FpFmt(sz);
 ea:=ResolveEA(gOps[0],FpSrcModes(fmt));
 If ea<0 Then Exit;
 EmitW($F200 or ea);
 EmitW($4000 or (fmt shl 10)or(gOps[1].pair shl 7)or $30 or gOps[1].reg);
 EmitEAExt(gOps[0],sz);
End;

Procedure DoFMovecr;
Var
 v:Longint;
Begin
 If Not FpuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 If(gOps[0].kind<>OK_IMM)or(gOps[1].kind<>OK_FPREG)Then Begin
  Error(Tr('FMOVECR #offset,FPn attendu','FMOVECR #offset,FPn expected'));
  Exit;
 End;
 NoReloc(gOps[0].val);
 v:=gOps[0].val.v;
 If(Not gOps[0].val.undef)and((v<0)or(v>127))Then Begin
  Error(Tr('Offset FMOVECR hors limites (0..127)',
    'FMOVECR offset out of range (0..127)'));
  Exit;
 End;
 EmitW($F200);
 EmitW($5C00 or (gOps[1].reg shl 7)or(v and $7F));
End;

Function ReverseMask8(m:Longint):Longint;
Var
 i,r:Longint;
Begin
 r:=0;
 For i:=0 to 7 do If(m and (1 shl i))<>0 Then r:=r or (1 shl (7-i));
 ReverseMask8:=r;
End;

Procedure DoFMove(idx:Longint);
Var
 opm,fmt,ea,sz,k,regsel:Longint;
Begin
 If Not FpuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 opm:=InstrTab[idx].op;
 { registres de controle }
 If gOps[0].kind=OK_FPCR Then Begin
  ea:=ResolveEA(gOps[1],M_ALT);
  If ea<0 Then Exit;
  EmitW($F200 or ea);
  EmitW($A000 or gOps[0].mask);
  EmitEAExt(gOps[1],4);
  Exit;
 End;
 If gOps[1].kind=OK_FPCR Then Begin
  ea:=ResolveEA(gOps[0],M_ALL);
  If ea<0 Then Exit;
  EmitW($F200 or ea);
  EmitW($8000 or gOps[1].mask);
  EmitEAExt(gOps[0],4);
  Exit;
 End;
 If gOps[1].kind=OK_FPREG Then Begin
  If gOps[0].kind=OK_FPREG Then Begin
   If(gSzRaw<>0)and(gSzRaw<>10)
     Then Error(Tr('Taille X requise entre registres FP',
     'Size X required between FP registers'));
   EmitW($F200);
   EmitW((gOps[0].reg shl 10)or(gOps[1].reg shl 7)or opm);
   Exit;
  End;
  sz:=FpSz(gSzRaw);
  fmt:=FpFmt(sz);
  ea:=ResolveEA(gOps[0],FpSrcModes(fmt));
  If ea<0 Then Exit;
  EmitW($F200 or ea);
  EmitW($4000 or (fmt shl 10)or(gOps[1].reg shl 7)or opm);
  EmitEAExt(gOps[0],sz);
  Exit;
 End;
 If gOps[0].kind=OK_FPREG Then Begin
  sz:=FpSz(gSzRaw);
  fmt:=FpFmt(sz);
  ea:=ResolveEA(gOps[1],FpDstModes(fmt));
  If ea<0 Then Exit;
  k:=0;
  If gOps[1].hasK Then Begin
   If gOps[1].kIsReg Then Begin
    fmt:=7;
    k:=(gOps[1].kVal and 7)shl 4;
   End Else k:=gOps[1].kVal and $7F;
  End;
  regsel:=gOps[0].reg;
  EmitW($F200 or ea);
  EmitW($6000 or (fmt shl 10)or(regsel shl 7)or k);
  EmitEAExt(gOps[1],sz);
  Exit;
 End;
 Error(Tr('Operandes FMOVE invalides','Invalid FMOVE operands'));
End;

Procedure DoFMovem;
Var
 ea,mode,lst,m:Longint;
 toMem:Boolean;
Begin
 If Not FpuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 { registres de controle }
 If(gOps[0].kind=OK_FPCR)or(gOps[1].kind=OK_FPCR)Then Begin
  If gOps[0].kind=OK_FPCR Then Begin
   ea:=ResolveEA(gOps[1],M_ALT);
   If ea<0 Then Exit;
   EmitW($F200 or ea);
   EmitW($A000 or gOps[0].mask);
   EmitEAExt(gOps[1],4);
  End Else Begin
   ea:=ResolveEA(gOps[0],M_ALL);
   If ea<0 Then Exit;
   EmitW($F200 or ea);
   EmitW($8000 or gOps[1].mask);
   EmitEAExt(gOps[0],4);
  End;
  Exit;
 End;
 toMem:=gOps[0].kind in [OK_FPREG,OK_FPLIST];
 If(gOps[0].kind=OK_DN)Then toMem:=True;
 If toMem Then Begin
  If gOps[1].kind in [OK_FPREG,OK_FPLIST,OK_DN]Then Begin
   Error(Tr('Operandes FMOVEM invalides','Invalid FMOVEM operands'));
   Exit;
  End;
  ea:=ResolveEA(gOps[1],(M_CONTROL and Not (M_PCD or M_PCI))or M_PRE);
  If ea<0 Then Exit;
  If gOps[0].kind=OK_DN Then Begin
   lst:=gOps[0].reg shl 4;
   If gOps[1].kind=OK_PRE Then mode:=1 Else mode:=3;
  End Else Begin
   If gOps[0].kind=OK_FPREG Then m:=1 shl gOps[0].reg Else m:=gOps[0].mask;
   If gOps[1].kind=OK_PRE Then Begin
    mode:=0;
    lst:=m;
   End Else Begin
    mode:=2;
    lst:=ReverseMask8(m);
   End;
  End;
  EmitW($F200 or ea);
  EmitW($E000 or (mode shl 11)or lst);
  EmitEAExt(gOps[1],4);
 End Else Begin
  If Not(gOps[1].kind in [OK_FPREG,OK_FPLIST,OK_DN])Then Begin
   Error(Tr('Liste de registres FP attendue','FP register list expected'));
   Exit;
  End;
  ea:=ResolveEA(gOps[0],M_CONTROL or M_POST);
  If ea<0 Then Exit;
  If gOps[1].kind=OK_DN Then Begin
   lst:=gOps[1].reg shl 4;
   mode:=3;
  End Else Begin
   If gOps[1].kind=OK_FPREG Then m:=1 shl gOps[1].reg Else m:=gOps[1].mask;
   mode:=2;
   lst:=ReverseMask8(m);
  End;
  EmitW($F200 or ea);
  EmitW($C000 or (mode shl 11)or lst);
  EmitEAExt(gOps[0],4);
 End;
End;

{ Branchements conditionnels du coprocesseur : FBcc / PBcc }
Procedure DoCpBranch(base,cc:Longint);
Var
 pcop,d:Longint;
 isExt:Boolean;
Begin
 If Not NeedOps(1)Then Exit;
 If gOps[0].kind<>OK_ABS Then Begin
  Error(Tr('Cible de branchement invalide','Invalid branch target'));
  Exit;
 End;
 pcop:=PC;
 d:=TargetDisp(gOps[0].val,pcop+2,isExt);
 If gSzRaw=4 Then Begin
  EmitW(base or $40 or cc);
  If isExt Then AddXRef(gOps[0].val.ext,pcop+2,EXT_REF32);
  EmitL(d);
  Exit;
 End;
 If(gSzRaw<>0)and(gSzRaw<>2)Then Begin
  Error(Tr('Taille de branchement invalide','Invalid branch size'));
  Exit;
 End;
 If(Not gOps[0].val.undef)and Not isExt and((d<-32768)or(d>32767))Then
  Error(Tr('Branchement hors limites','Branch out of range'));
 EmitW(base or cc);
 If isExt Then AddXRef(gOps[0].val.ext,pcop+2,EXT_REF16);
 EmitW(d and $FFFF);
End;

Procedure DoCpDbcc(base,cc:Longint);
Var
 pcop,d:Longint;
 isExt:Boolean;
Begin
 If Not NeedOps(2)Then Exit;
 If(gOps[0].kind<>OK_DN)or(gOps[1].kind<>OK_ABS)Then Begin
  Error(Tr('Dn,etiquette attendus','Dn,label expected'));
  Exit;
 End;
 pcop:=PC;
 d:=TargetDisp(gOps[1].val,pcop+4,isExt);
 EmitW(base or $48 or gOps[0].reg);
 EmitW(cc);
 If isExt Then AddXRef(gOps[1].val.ext,pcop+4,EXT_REF16)
 Else If(Not gOps[1].val.undef)and((d<-32768)or(d>32767))Then
  Error(Tr('Branchement hors limites','Branch out of range'));
 EmitW(d and $FFFF);
End;

Procedure DoCpScc(base,cc:Longint);
Var
 ea:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 ea:=ResolveEA(gOps[0],M_DATALT);
 If ea<0 Then Exit;
 EmitW(base or $40 or ea);
 EmitW(cc);
 EmitEAExt(gOps[0],1);
End;

Procedure DoCpTrapcc(base,cc:Longint);
Var
 sz:Longint;
Begin
 If gN=0 Then Begin
  EmitW(base or $78 or 4);
  EmitW(cc);
  Exit;
 End;
 If(gN<>1)or(gOps[0].kind<>OK_IMM)Then Begin
  Error(Tr('Operande immediat attendu','Immediate operand expected'));
  Exit;
 End;
 sz:=EffSz(2,6);
 If sz=4 Then EmitW(base or $78 or 3) Else EmitW(base or $78 or 2);
 EmitW(cc);
 EmitImmValue(gOps[0].val,sz);
End;

Procedure DoCpSave(opc:Longint;restore:Boolean);
Var
 ea:Longint;
Begin
 If Not NeedOps(1)Then Exit;
 If restore Then ea:=ResolveEA(gOps[0],M_CONTROL or M_POST)
  Else ea:=ResolveEA(gOps[0],(M_CONTROL and Not (M_PCD or M_PCI))or M_PRE);
 If ea<0 Then Exit;
 EmitW(opc or ea);
 EmitEAExt(gOps[0],4);
End;

{ ------------------------------------------------------------------------ }
{ MMU : 68851 / 68030 et instructions 68040                                  }
{ ------------------------------------------------------------------------ }

{ Code de fonction : #n, Dn, SFC, DFC }
Function FcCode(Const op:TOp):Longint;
Begin
 FcCode:=0;
 Case op.kind of
  OK_IMM:Begin
   NoReloc(op.val);
   FcCode:=$10 or (op.val.v and 15);
  End;
  OK_DN:FcCode:=$08 or op.reg;
  OK_CTRL:If op.ctrl=0 Then FcCode:=0 Else If op.ctrl=1 Then FcCode:=1
   Else Error(Tr('Code de fonction invalide','Invalid function code'));
  Else Error(Tr('Code de fonction invalide','Invalid function code'));
 End;
End;

Procedure DoPmove(idx:Longint);
Var
 ea,fd:Longint;
Begin
 If Not MmuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 fd:=0;
 If InstrTab[idx].arg=1 Then fd:=$0100;
 If gOps[1].kind=OK_MMUREG Then Begin
  ea:=ResolveEA(gOps[0],M_ALL);
  If ea<0 Then Exit;
  EmitW($F000 or ea);
  EmitW(gOps[1].ctrl or fd);
  EmitEAExt(gOps[0],4);
 End Else If gOps[0].kind=OK_MMUREG Then Begin
  ea:=ResolveEA(gOps[1],M_ALT);
  If ea<0 Then Exit;
  EmitW($F000 or ea);
  EmitW(gOps[0].ctrl or $0200 or fd);
  EmitEAExt(gOps[1],4);
 End Else Error(Tr('Registre MMU attendu','MMU register expected'));
End;

Procedure DoPflush(idx:Longint);
Var
 which,ea,mask:Longint;
Begin
 which:=InstrTab[idx].arg;
 If cpu>=CPU_68040 Then Begin
  { 68040 : PFLUSH (An), PFLUSHN (An), PFLUSHA, PFLUSHAN }
  Case which of
   1:Begin
    If gN<>0 Then Warn(Tr('Operandes ignores','Operands ignored'));
    EmitW($F518);
   End;
   3:Begin
    If gN<>0 Then Warn(Tr('Operandes ignores','Operands ignored'));
    EmitW($F510);
   End;
   Else Begin
    If Not NeedOps(1)Then Exit;
    If gOps[0].kind<>OK_IND Then Begin
     Error(Tr('PFLUSH (An) attendu','PFLUSH (An) expected'));
     Exit;
    End;
    If which=2 Then EmitW($F500 or gOps[0].reg) Else EmitW($F508
      or gOps[0].reg);
   End;
  End;
  Exit;
 End;
 If Not MmuOk Then Exit;
 If which=1 Then Begin
  EmitW($F000);
  EmitW($2400);
  Exit;
 End;
 If(gN<2)or(gN>3)Then Begin
  Error(Tr('PFLUSH fc,#masque[,<ea>] attendu',
    'PFLUSH fc,#mask[,<ea>] expected'));
  Exit;
 End;
 If gOps[1].kind<>OK_IMM Then Begin
  Error(Tr('Masque immediat attendu','Immediate mask expected'));
  Exit;
 End;
 NoReloc(gOps[1].val);
 mask:=gOps[1].val.v and 15;
 If gN=2 Then Begin
  EmitW($F000);
  EmitW($3000 or (mask shl 5)or FcCode(gOps[0]));
 End Else Begin
  ea:=ResolveEA(gOps[2],M_CONTROL);
  If ea<0 Then Exit;
  EmitW($F000 or ea);
  EmitW($3800 or (mask shl 5)or FcCode(gOps[0]));
  EmitEAExt(gOps[2],4);
 End;
End;

Procedure DoPload(idx:Longint);
Var
 ea:Longint;
Begin
 If Not MmuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 ea:=ResolveEA(gOps[1],M_CONTROL);
 If ea<0 Then Exit;
 EmitW($F000 or ea);
 EmitW($2000 or (InstrTab[idx].arg shl 9)or FcCode(gOps[0]));
 EmitEAExt(gOps[1],4);
End;

Procedure DoPtest(idx:Longint);
Var
 ea,rw,lvl,a,r:Longint;
Begin
 rw:=InstrTab[idx].arg;
 If cpu>=CPU_68040 Then Begin
  If Not NeedOps(1)Then Exit;
  If gOps[0].kind<>OK_IND Then Begin
   Error(Tr('PTEST (An) attendu','PTEST (An) expected'));
   Exit;
  End;
  If rw=1 Then EmitW($F568 or gOps[0].reg) Else EmitW($F548 or gOps[0].reg);
  Exit;
 End;
 If Not MmuOk Then Exit;
 If(gN<3)or(gN>4)Then Begin
  Error(Tr('PTEST fc,<ea>,#niveau[,An] attendu',
    'PTEST fc,<ea>,#level[,An] expected'));
  Exit;
 End;
 If gOps[2].kind<>OK_IMM Then Begin
  Error(Tr('Niveau immediat attendu','Immediate level expected'));
  Exit;
 End;
 NoReloc(gOps[2].val);
 lvl:=gOps[2].val.v and 7;
 a:=0;
 r:=0;
 If gN=4 Then Begin
  If gOps[3].kind<>OK_AN Then Begin
   Error(Tr('Registre d''adresse attendu','Address register expected'));
   Exit;
  End;
  a:=1;
  r:=gOps[3].reg;
 End;
 ea:=ResolveEA(gOps[1],M_CONTROL);
 If ea<0 Then Exit;
 EmitW($F000 or ea);
 EmitW($8000 or (lvl shl 10)or(rw shl 9)or(a shl 8)or(r shl 5)
   or FcCode(gOps[0]));
 EmitEAExt(gOps[1],4);
End;

Procedure DoPvalid;
Var
 ea:Longint;
Begin
 If Not MmuOk Then Exit;
 If Not NeedOps(2)Then Exit;
 ea:=ResolveEA(gOps[1],M_CONTROL);
 If ea<0 Then Exit;
 EmitW($F000 or ea);
 If gOps[0].kind=OK_AN Then EmitW($2C00 or gOps[0].reg)
 Else If(gOps[0].kind=OK_MMUREG)and(gOps[0].ctrl=$5400)Then EmitW($2800)
 Else Begin
  Error(Tr('PVALID VAL ou An attendu','PVALID VAL or An expected'));
  Exit;
 End;
 EmitEAExt(gOps[1],4);
End;

Procedure DoCinv(idx:Longint);
Var
 opc:Longint;
Begin
 If cpu<CPU_68040 Then Begin
  Error(Tr('CINV/CPUSH requiert un 68040','CINV/CPUSH requires a 68040'));
  Exit;
 End;
 opc:=InstrTab[idx].op;
 If(opc and $18)=$18 Then Begin
  If Not NeedOps(1)Then Exit;
  If gOps[0].kind<>OK_CACHE Then Begin
   Error(Tr('Specificateur de cache attendu (NC, DC, IC, BC)',
     'Cache specifier expected (NC, DC, IC, BC)'));
   Exit;
  End;
  EmitW(opc or (gOps[0].ctrl shl 6));
 End Else Begin
  If Not NeedOps(2)Then Exit;
  If(gOps[0].kind<>OK_CACHE)or(gOps[1].kind<>OK_IND)Then Begin
   Error(Tr('CINV cache,(An) attendu','CINV cache,(An) expected'));
   Exit;
  End;
  EmitW(opc or (gOps[0].ctrl shl 6)or gOps[1].reg);
 End;
End;

Procedure DoMove16;
Var
 a,b:Integer;
Begin
 If cpu<CPU_68040 Then Begin
  Error(Tr('MOVE16 requiert un 68040','MOVE16 requires a 68040'));
  Exit;
 End;
 If Not NeedOps(2)Then Exit;
 a:=gOps[0].kind;
 b:=gOps[1].kind;
 If(a=OK_POST)and(b=OK_POST)Then Begin
  EmitW($F620 or gOps[0].reg);
  EmitW($8000 or (gOps[1].reg shl 12));
 End Else If(a=OK_POST)and(b=OK_ABS)Then Begin
  EmitW($F600 or gOps[0].reg);
  EmitLongVal(gOps[1].val);
 End Else If(a=OK_ABS)and(b=OK_POST)Then Begin
  EmitW($F608 or gOps[1].reg);
  EmitLongVal(gOps[0].val);
 End Else If(a=OK_IND)and(b=OK_ABS)Then Begin
  EmitW($F610 or gOps[0].reg);
  EmitLongVal(gOps[1].val);
 End Else If(a=OK_ABS)and(b=OK_IND)Then Begin
  EmitW($F618 or gOps[1].reg);
  EmitLongVal(gOps[0].val);
 End Else Error(Tr('Operandes MOVE16 invalides','Invalid MOVE16 operands'));
End;

Procedure DoInstruction(cls,idx,cc:Longint;Const ext:String);
Var
 sz,ea,v:Longint;
Begin
 gSzRaw:=SzFromExt(ext);
 gSpecial:=0;
 If(cls=C_PMOVE)or(cls=C_PVALID)Then gSpecial:=1;
 If cls=C_CINV Then gSpecial:=2;
 If cls=C_NOOP Then gN:=0 Else gN:=ParseOperands(gOps);
 gSpecial:=0;
 If exprErr Then Exit;
 Case cls of
  C_NOOP:Begin
   If gN<>0 Then Warn(Tr('Operandes ignores','Operands ignored'));
   EmitW(InstrTab[idx].op);
  End;
  C_BCC:DoBranch(cc);
  C_DBCC:DoDbcc(cc);
  C_SCC:Begin
   If Not NeedOps(1)Then Exit;
   EffSz(1,1);
   ea:=ResolveEA(gOps[0],M_DATALT);
   If ea<0 Then Exit;
   EmitW($50C0 or (cc shl 8)or ea);
   EmitEAExt(gOps[0],1);
  End;
  C_TRAPCC:Begin
   If cpu<CPU_68020 Then Begin
    Error(Tr('TRAPcc requiert un 68020','TRAPcc requires a 68020'));
    Exit;
   End;
   If gN=0 Then EmitW($50FC or (cc shl 8)) Else Begin
    If gOps[0].kind<>OK_IMM Then Begin
     Error(Tr('Operande immediat attendu','Immediate operand expected'));
     Exit;
    End;
    sz:=EffSz(2,6);
    If sz=4 Then EmitW($50FB or (cc shl 8)) Else EmitW($50FA or (cc shl 8));
    EmitImmValue(gOps[0].val,sz);
   End;
  End;
  C_ADDSUB:DoAddSub(idx);
  C_LOGIC:DoLogic(idx);
  C_CMP:DoCmp;
  C_ADDA:Begin
   If Not NeedOps(2)Then Exit;
   If gOps[1].kind<>OK_AN Then Begin
    Error(Tr('Registre d''adresse destination requis',
      'Destination address register required'));
    Exit;
   End;
   If InstrTab[idx].arg=2 Then DoAdda(InstrTab[idx].op,0)
    Else DoAdda(InstrTab[idx].op,$5000+InstrTab[idx].arg*$100);
  End;
  C_IMMOP:DoImmOp(idx);
  C_QUICK:Begin
   If Not NeedOps(2)Then Exit;
   sz:=EffSz(2,7);
   DoQuickOp(InstrTab[idx].op,sz);
  End;
  C_MOVE:DoMove;
  C_MOVEA:DoMovea;
  C_MOVEQ:DoMoveq;
  C_MOVEM:DoMovem;
  C_MOVEP:DoMovep;
  C_MOVEC:DoMovec;
  C_MOVES:DoMoves;
  C_UNARY:DoUnary(idx);
  C_UNARYB:DoUnaryB(idx);
  C_SHIFT:DoShift(idx);
  C_BIT:DoBit(idx);
  C_MULDIV:DoMulDiv(idx);
  C_DIVL:DoDivl(idx);
  C_EXT:DoExt(idx);
  C_SWAP:Begin
   If Not NeedOps(1)Then Exit;
   If gOps[0].kind<>OK_DN Then Begin
    Error(Tr('Registre de donnees attendu','Data register expected'));
    Exit;
   End;
   EmitW($4840 or gOps[0].reg);
  End;
  C_LINK:Begin
   If Not NeedOps(2)Then Exit;
   If(gOps[0].kind<>OK_AN)or(gOps[1].kind<>OK_IMM)Then Begin
    Error(Tr('LINK An,#deplacement attendu','LINK An,#displacement expected'));
    Exit;
   End;
   sz:=EffSz(2,6);
   If sz=4 Then Begin
    If cpu<CPU_68020 Then Begin
     Error(Tr('LINK.L requiert un 68020','LINK.L requires a 68020'));
     Exit;
    End;
    EmitW($4808 or gOps[0].reg);
    EmitLongVal(gOps[1].val);
   End Else Begin
    EmitW($4E50 or gOps[0].reg);
    EmitDisp16(gOps[1].val);
   End;
  End;
  C_UNLK:Begin
   If Not NeedOps(1)Then Exit;
   If gOps[0].kind<>OK_AN Then Begin
    Error(Tr('Registre d''adresse attendu','Address register expected'));
    Exit;
   End;
   EmitW($4E58 or gOps[0].reg);
  End;
  C_TRAP:Begin
   If Not NeedOps(1)Then Exit;
   If gOps[0].kind<>OK_IMM Then Begin
    Error(Tr('TRAP #n attendu','TRAP #n expected'));
    Exit;
   End;
   NoReloc(gOps[0].val);
   v:=gOps[0].val.v;
   If(Not gOps[0].val.undef)and((v<0)or(v>15))Then Begin
    Error(Tr('Vecteur TRAP hors limites (0..15)',
      'TRAP vector out of range (0..15)'));
    Exit;
   End;
   EmitW($4E40 or (v and 15));
  End;
  C_STOP:Begin
   If Not NeedOps(1)Then Exit;
   If gOps[0].kind<>OK_IMM Then Begin
    Error(Tr('STOP #n attendu','STOP #n expected'));
    Exit;
   End;
   DoImmOnly($4E72,2);
  End;
  C_RTD:Begin
   If Not NeedOps(1)Then Exit;
   If cpu<CPU_68010 Then Begin
    Error(Tr('RTD requiert un 68010 ou plus','RTD requires a 68010 or later'));
    Exit;
   End;
   If gOps[0].kind<>OK_IMM Then Begin
    Error(Tr('RTD #n attendu','RTD #n expected'));
    Exit;
   End;
   DoImmOnly($4E74,2);
  End;
  C_BKPT:Begin
   If Not NeedOps(1)Then Exit;
   If cpu<CPU_68010 Then Begin
    Error(Tr('BKPT requiert un 68010 ou plus',
      'BKPT requires a 68010 or later'));
    Exit;
   End;
   If gOps[0].kind<>OK_IMM Then Begin
    Error(Tr('BKPT #n attendu','BKPT #n expected'));
    Exit;
   End;
   NoReloc(gOps[0].val);
   v:=gOps[0].val.v;
   If(v<0)or(v>7)Then Begin
    Error(Tr('Numero BKPT hors limites (0..7)',
      'BKPT number out of range (0..7)'));
    Exit;
   End;
   EmitW($4848 or v);
  End;
  C_CTRL1:DoCtrl1(idx);
  C_LEA:DoLea;
  C_CHK:DoChk;
  C_EXG:DoExg;
  C_BCDX:DoBcdx(idx);
  C_BF:DoBitfield(idx);
  C_CAS:DoCas;
  C_CMP2:DoCmp2(idx);
  C_PACK:DoPack(idx);
  C_FPARITH:DoFArith(idx);
  C_FMOVE:DoFMove(idx);
  C_FMOVEM:DoFMovem;
  C_FMOVECR:DoFMovecr;
  C_FSINCOS:DoFSinCos;
  C_FTST:DoFTst;
  C_FNOP:Begin
   If FpuOk Then Begin
    EmitW($F280);
    EmitW(0);
   End;
  End;
  C_FSAVE:If FpuOk Then DoCpSave(InstrTab[idx].op,False);
  C_FRESTORE:If FpuOk Then DoCpSave(InstrTab[idx].op,True);
  C_FBCC:If FpuOk Then DoCpBranch($F280,cc);
  C_FDBCC:If FpuOk Then DoCpDbcc($F200,cc);
  C_FSCC:If FpuOk Then DoCpScc($F200,cc);
  C_FTRAPCC:If FpuOk Then DoCpTrapcc($F200,cc);
  C_PMOVE:DoPmove(idx);
  C_PFLUSH:DoPflush(idx);
  C_PLOAD:DoPload(idx);
  C_PTEST:DoPtest(idx);
  C_PBCC:If MmuOk Then DoCpBranch($F080,cc);
  C_PDBCC:If MmuOk Then DoCpDbcc($F000,cc);
  C_PSCC:If MmuOk Then DoCpScc($F000,cc);
  C_PTRAPCC:If MmuOk Then DoCpTrapcc($F000,cc);
  C_PSAVE:If MmuOk Then DoCpSave(InstrTab[idx].op,False);
  C_PRESTORE:If MmuOk Then DoCpSave(InstrTab[idx].op,True);
  C_PVALID:DoPvalid;
  C_CINV:DoCinv(idx);
  C_MOVE16:DoMove16;
  C_CMPM:Begin
   If Not NeedOps(2)Then Exit;
   sz:=EffSz(2,7);
   If(gOps[0].kind<>OK_POST)or(gOps[1].kind<>OK_POST)Then Begin
    Error(Tr('CMPM (Ay)+,(Ax)+ attendu','CMPM (Ay)+,(Ax)+ expected'));
    Exit;
   End;
   EmitW($B108 or (gOps[1].reg shl 9)or(SzCode(sz)shl 6)or gOps[0].reg);
  End;
 End;
End;

{ ------------------------------------------------------------------------ }
{ Listing                                                                   }
{ ------------------------------------------------------------------------ }

Procedure ListHeader;
Begin
 Inc(listPage);
 WriteLn(listFile,'GenAm ',GENAM_VERSION,'  ',listTitle,'  ',Tr('Page ',
   'Page '),listPage);
 If listSub<>'' Then WriteLn(listFile,listSub) Else WriteLn(listFile);
 WriteLn(listFile);
 listLineNo:=3;
End;

Procedure ListNewPage;
Begin
 If Not listOpen Then Exit;
 If listPage>0 Then Write(listFile,#12);
 ListHeader;
End;

Procedure ListRaw(Const s:String);
Begin
 If Not listOpen Then Exit;
 If(listPage=0)or(listLineNo>=listPLen)Then ListNewPage;
 WriteLn(listFile,s);
 Inc(listLineNo);
End;

Procedure ListLine(Const s:String);
Var
 n,i,k,addr:Longint;
 hx,txt:String;
 sameSec:Boolean;
 nb:Longint;
Begin
 If(Not listOpen)or(Not listOn)or(Not final)Then Exit;
 If(lstKind<>SRC_FILE)and(Not opt.m)Then Exit;
 nb:=0;
 sameSec:=(cursec=lineStartSec)and(cursec>=0)and Not inOffset;
 If sameSec Then Begin
  If sec[cursec].size>lineStartPC Then Begin
   nb:=sec[cursec].size-lineStartPC;
   If sec[cursec].kind=ST_BSS Then Begin
    nb:=-nb;
   End;
  End;
 End;
 addr:=lineStartPC;
 txt:=RFmt(IntStr(lstLine),5)+' ';
 If(nb<>0)or(lineHasCode)Then txt:=txt+HexStr(addr,
   8)+' ' Else txt:=txt+'         ';
 hx:='';
 If nb>0 Then Begin
  n:=nb;
  If n>MAX_LISTB Then n:=MAX_LISTB;
  For i:=0 to n-1 do hx:=hx+HexStr(sec[cursec].data^[lineStartPC+i],2);
 End;
 ListRaw(txt+Fmt(hx,MAX_LISTB*2)+'  '+s);
 If nb>MAX_LISTB Then Begin
  k:=MAX_LISTB;
  While k<nb do Begin
   hx:='';
   n:=nb-k;
   If n>MAX_LISTB Then n:=MAX_LISTB;
   For i:=0 to n-1 do hx:=hx+HexStr(sec[cursec].data^[lineStartPC+k+i],2);
   ListRaw('      '+HexStr(addr+k,8)+' '+hx);
   Inc(k,MAX_LISTB);
  End;
 End;
End;

{ ------------------------------------------------------------------------ }
{ Directives                                                                }
{ ------------------------------------------------------------------------ }

Const
 D_DC=1;  D_DS=2;  D_DCB=3;  D_EVEN=4;  D_CNOP=5;  D_ORG=6;  D_END=7;
 D_EQU=8; D_SET=9; D_EQUR=10; D_REG=11; D_RS=12; D_RSRESET=13; D_RSSET=14;
 D_FO=15; D_SECTION=16; D_CODE=17; D_DATA=18; D_BSS=19; D_OFFSET=20;
 D_XDEF=21; D_XREF=22; D_INCLUDE=23; D_INCDIR=24; D_INCBIN=25; D_MACRO=26;
 D_ENDM=27; D_MEXIT=28; D_REPT=29; D_ENDR=30; D_OPT=31; D_LIST=32;
 D_NOLIST=33; D_PAGE=34; D_TTL=35; D_SUBTTL=36; D_SPC=37; D_LLEN=38;
 D_PLEN=39; D_FAIL=40; D_PRINTT=41; D_PRINTV=42; D_MC=43; D_IDNT=44;
 D_OUTPUT=45; D_IGNORE=46; D_IF=47; D_ELSE=48; D_ENDC=49;
 D_IFD=50; D_IFND=51; D_IFC=52; D_IFNC=53; D_BLK=54;

 NDIRNAMES = 83;

 DirNames:Array[1..NDIRNAMES] of String[8]=(
  'DC','DS','DCB','EVEN','CNOP','ORG','END','EQU','=','SET','EQUR','REG',
  'RS','RSRESET','RSSET','SO','FO','SECTION','CODE','DATA','BSS','OFFSET',
  'XDEF','PUBLIC','XREF','EXTERN','INCLUDE','INCDIR','INCBIN','MACRO','ENDM',
  'MEXIT','REPT','ENDR','OPT','LIST','NOLIST','PAGE','TTL','SUBTTL','SPC',
  'LLEN','PLEN','FAIL','PRINTT','PRINTV','MC68000','MC68010','MC68020',
  'MC68030','MC68040','IDNT','OUTPUT','FORMAT','NEAR','LISTCHAR','MASK2',
  'NOPAGE','IFEQ','IFNE','IFGT','IFGE','IFLT','IFLE','IF','ELSE','ENDC',
  'ENDIF','IFD','IFND','IFC','IFNC','BLK','CODE_C','CODE_F','DATA_C','DATA_F',
  'BSS_C','BSS_F','MC68881','MC68882','MC68851','MC68060');

 DirIds:Array[1..NDIRNAMES] of Byte=(
  D_DC,D_DS,D_DCB,D_EVEN,D_CNOP,D_ORG,D_END,D_EQU,D_EQU,D_SET,D_EQUR,D_REG,
  D_RS,D_RSRESET,D_RSSET,D_RS,D_FO,D_SECTION,D_CODE,D_DATA,D_BSS,D_OFFSET,
  D_XDEF,D_XDEF,D_XREF,D_XREF,D_INCLUDE,D_INCDIR,D_INCBIN,D_MACRO,D_ENDM,
  D_MEXIT,D_REPT,D_ENDR,D_OPT,D_LIST,D_NOLIST,D_PAGE,D_TTL,D_SUBTTL,D_SPC,
  D_LLEN,D_PLEN,D_FAIL,D_PRINTT,D_PRINTV,D_MC,D_MC,D_MC,
  D_MC,D_MC,D_IDNT,D_OUTPUT,D_IGNORE,D_IGNORE,D_IGNORE,D_IGNORE,
  D_IGNORE,D_IF,D_IF,D_IF,D_IF,D_IF,D_IF,D_IF,D_ELSE,D_ENDC,
  D_ENDC,D_IFD,D_IFND,D_IFC,D_IFNC,D_BLK,D_CODE,D_CODE,D_DATA,D_DATA,
  D_BSS,D_BSS,D_MC,D_MC,D_MC,D_MC);

Var
 unitName:String;
 outNameDir:String;
 cpuDef:Integer;

Function FindDirective(Const up:String):Longint;
Var
 i:Longint;
Begin
 FindDirective:=0;
 For i:=1 to NDIRNAMES do If DirNames[i]=up Then Begin
  FindDirective:=i;
  Exit;
 End;
End;

{ Lit un argument texte : entre guillemets ou jusqu'a la virgule/espace }
Function ParseTextArg(Var s:String;stopComma:Boolean):Boolean;
Var
 q:Char;
Begin
 s:='';
 ParseTextArg:=False;
 SkipSp;
 If LPOS>Length(LP)Then Exit;
 If LP[LPOS] in ['''','"'] Then Begin
  q:=LP[LPOS];
  Inc(LPOS);
  While LPOS<=Length(LP) do Begin
   If LP[LPOS]=q Then Begin
    If(LPOS<Length(LP))and(LP[LPOS+1]=q)Then Begin
     s:=s+q;
     Inc(LPOS,2);
    End Else Begin
     Inc(LPOS);
     Break;
    End;
   End Else Begin
    s:=s+LP[LPOS];
    Inc(LPOS);
   End;
  End;
 End Else Begin
  While(LPOS<=Length(LP))and Not(LP[LPOS] in [' ',#9,
    ';'])and Not(stopComma and(LP[LPOS]=','))do Begin
   s:=s+LP[LPOS];
   Inc(LPOS);
  End;
 End;
 ParseTextArg:=True;
End;

Function SizeOfDirExt(Const e:String;dflt:Longint):Longint;
Begin
 If e='' Then SizeOfDirExt:=dflt Else
 If e='B' Then SizeOfDirExt:=1 Else
 If e='W' Then SizeOfDirExt:=2 Else
 If e='L' Then SizeOfDirExt:=4 Else
 If e='S' Then SizeOfDirExt:=8 Else
 If e='D' Then SizeOfDirExt:=9 Else
 If e='X' Then SizeOfDirExt:=10 Else
 If e='P' Then SizeOfDirExt:=11 Else Begin
  Error(Tr('Taille invalide pour cette directive',
    'Invalid size for this directive'));
  SizeOfDirExt:=dflt;
 End;
End;

{ Un element DC.B pouvant etre une chaine }
Function TryStringItem:Boolean;
Var
 save:Longint;
 q:Char;
 t:String;
 i:Longint;
Begin
 TryStringItem:=False;
 SkipSp;
 If Not(PeekCh in ['''','"'])Then Exit;
 save:=LPOS;
 q:=PeekCh;
 Inc(LPOS);
 t:='';
 While LPOS<=Length(LP) do Begin
  If LP[LPOS]=q Then Begin
   If(LPOS<Length(LP))and(LP[LPOS+1]=q)Then Begin
    t:=t+q;
    Inc(LPOS,2);
   End Else Break;
  End Else Begin
   t:=t+LP[LPOS];
   Inc(LPOS);
  End;
 End;
 If(LPOS>Length(LP))or(LP[LPOS]<>q)Then Begin
  LPOS:=save;
  Exit;
 End;
 Inc(LPOS);
 SkipSp;
 If(PeekCh=',')or(PeekCh=#0)or(PeekCh=';')or(LPOS>Length(LP))Then Begin
  For i:=1 to Length(t) do EmitB(Ord(t[i]));
  TryStringItem:=True;
 End Else LPOS:=save;
End;

{ Nombre d'octets d'un element de donnees (formats flottants inclus) }
Function DirByteSize(sz:Longint):Longint;
Begin
 Case sz of
  8:DirByteSize:=4;
  9:DirByteSize:=8;
  10,11:DirByteSize:=12;
  Else DirByteSize:=sz;
 End;
End;

{ Un nombre flottant ou une constante entiere pour DC.S/D/X/P }
Procedure ParseFloatItem(Var e:Extended;Var txt:String);
Var
 v:TVal;
Begin
 SkipSp;
 If Not ScanFloat(e,txt)Then Begin
  ExprFull(v);
  If(v.sect<>-1)and Not v.undef Then
   Error(Tr('Valeur relogeable non permise dans un flottant',
     'Relocatable value not allowed in a float'));
  e:=v.v;
  txt:=IntStr(v.v);
 End;
End;

Procedure DoDCFloat(sz:Longint);
Var
 e:Extended;
 t:String;
Begin
 While True do Begin
  ParseFloatItem(e,t);
  If exprErr Then Exit;
  EmitFloatValue(sz,e,t);
  SkipSp;
  If PeekCh=',' Then Inc(LPOS) Else Break;
 End;
End;

Procedure DoDC(Const ext:String);
Var
 sz:Longint;
 v:TVal;
Begin
 sz:=SizeOfDirExt(ext,2);
 If sz>=8 Then Begin
  DoDCFloat(sz);
  Exit;
 End;
 While True do Begin
  SkipSp;
  If(sz=1)and TryStringItem Then Begin
  End Else Begin
   ExprFull(v);
   If exprErr Then Exit;
   Case sz of
    1:Begin
     If(v.sect<>-1)and Not v.undef Then
      Error(Tr('Valeur relogeable non permise dans DC.B',
        'Relocatable value not allowed in DC.B'));
     CheckRange(v.v,1);
     EmitB(v.v and $FF);
    End;
    2:Begin
     If(v.sect<>-1)and Not v.undef Then
      Error(Tr('Valeur relogeable non permise dans DC.W',
        'Relocatable value not allowed in DC.W'));
     CheckRange(v.v,2);
     EmitW(v.v and $FFFF);
    End;
    Else EmitLongVal(v);
   End;
  End;
  SkipSp;
  If PeekCh=',' Then Inc(LPOS) Else Break;
 End;
End;

Procedure DoDS(Const ext:String);
Var
 sz,n:Longint;
 v:TVal;
Begin
 sz:=SizeOfDirExt(ext,2);
 ExprAbsV(v);
 If exprErr Then Exit;
 n:=v.v;
 If v.undef and final Then Error(Tr('DS requiert une valeur definie',
   'DS requires a defined value'));
 If n<0 Then Begin
  Error(Tr('Taille negative pour DS','Negative size for DS'));
  Exit;
 End;
 Reserve(n*DirByteSize(sz));
End;

Procedure DoDCB(Const ext:String);
Var
 sz,i:Longint;
 cnt,v:TVal;
 fe:Extended;
 ft:String;
Begin
 sz:=SizeOfDirExt(ext,2);
 ExprAbsV(cnt);
 SkipSp;
 fe:=0;
 ft:='0';
 If sz>=8 Then Begin
  If PeekCh=',' Then Begin
   Inc(LPOS);
   ParseFloatItem(fe,ft);
  End;
  If exprErr Then Exit;
  For i:=1 to cnt.v do EmitFloatValue(sz,fe,ft);
  Exit;
 End;
 If PeekCh=',' Then Begin
  Inc(LPOS);
  ExprFull(v);
 End Else MkAbs(v,0);
 If exprErr Then Exit;
 If cnt.v<0 Then Begin
  Error(Tr('Nombre negatif pour DCB','Negative count for DCB'));
  Exit;
 End;
 For i:=1 to cnt.v do Begin
  Case sz of
   1:EmitB(v.v and $FF);
   2:EmitW(v.v and $FFFF);
   Else EmitLongVal(v);
  End;
 End;
End;

Procedure DoCnop;
Var
 off,al,cur,pad,i:Longint;
Begin
 ExprAbs(off);
 SkipSp;
 If PeekCh=',' Then Inc(LPOS) Else Begin
  Error(Tr('CNOP offset,alignement attendu','CNOP offset,alignment expected'));
  Exit;
 End;
 ExprAbs(al);
 If al<=0 Then Begin
  Error(Tr('Alignement CNOP invalide','Invalid CNOP alignment'));
  Exit;
 End;
 cur:=PC;
 pad:=((off-cur) mod al + al) mod al;
 If(Not inOffset)and(cursec>=0)and(sec[cursec].kind=ST_CODE)Then Begin
  If(pad and 1)<>0 Then Begin EmitB(0);Dec(pad);End;
  For i:=1 to pad div 2 do EmitW($4E71);
 End Else Reserve(pad);
End;

Procedure DoOrg;
Var
 v:Longint;
Begin
 ExprAbs(v);
 If exprErr Then Exit;
 If opt.l Then Begin
  Error(Tr('ORG non permis en mode linkable',
    'ORG not allowed in linkable mode'));
  Exit;
 End;
 EnsureSect;
 If(nsec>1)or(sec[cursec].size<>0)Then Begin
  Error(Tr('ORG doit preceder tout code et toute section',
    'ORG must precede any code and section'));
  Exit;
 End;
 orgMode:=True;
 orgAddr:=v;
End;

Procedure DoSection(Const up,ext:String);
Var
 name,typ:String;
 kind,mem:Byte;
 i:Longint;
Begin
 name:='';
 kind:=ST_CODE;
 mem:=MEM_ANY;
 typ:='';
 If up='SECTION' Then Begin
  If Not ParseTextArg(name,True)Then Begin
   Error(Tr('Nom de section attendu','Section name expected'));
   Exit;
  End;
  SkipSp;
  If PeekCh=',' Then Begin
   Inc(LPOS);
   ParseTextArg(typ,True);
   typ:=UpStr(typ);
  End;
 End Else typ:=up;
 If Copy(typ,1,4)='CODE' Then Begin kind:=ST_CODE;typ:=Copy(typ,5,10);End Else
 If Copy(typ,1,4)='DATA' Then Begin kind:=ST_DATA;typ:=Copy(typ,5,10);End Else
 If Copy(typ,1,3)='BSS' Then Begin kind:=ST_BSS;typ:=Copy(typ,4,10);End Else
 If typ<>'' Then Begin
  Error(Tr('Type de section invalide : ','Invalid section type: ')+typ);
  Exit;
 End;
 If typ='_C' Then mem:=MEM_CHIP Else If typ='_F' Then mem:=MEM_FAST
 Else If typ<>'' Then Begin
  Error(Tr('Type de section invalide : ','Invalid section type: ')+typ);
  Exit;
 End;
 If orgMode Then Begin
  Error(Tr('Les sections ne sont pas permises avec ORG',
    'Sections are not allowed with ORG'));
  Exit;
 End;
 i:=FindOrAddSection(name,kind,mem);
 If(name<>'')and(sec[i].mem<>mem)and(mem<>MEM_ANY)Then sec[i].mem:=mem;
 cursec:=i;
 inOffset:=False;
End;

Procedure DoOffset;
Var
 v:Longint;
Begin
 SkipSp;
 v:=0;
 If(LPOS<=Length(LP))and(PeekCh<>';')Then ExprAbs(v);
 inOffset:=True;
 offPC:=v;
End;

Procedure DoXdef(isRef:Boolean);
Var
 id:String;
 i:Longint;
 sfx:Byte;
Begin
 While True do Begin
  SkipSp;
  id:=PeekIdent;
  If id='' Then Begin
   Error(Tr('Nom de symbole attendu','Symbol name expected'));
   Exit;
  End;
  Inc(LPOS,Length(id));
  i:=LookupSymIdx(id);
  If isRef Then Begin
   If(syms[i].defpass=pass)and(syms[i].kind in [SK_LABEL,SK_EQU,SK_SET])Then
    Error(Tr('Symbole deja defini localement : ',
      'Symbol already defined locally: ')+id)
   Else Begin
    syms[i].kind:=SK_XREF;
    syms[i].sect:=-2;
    syms[i].defpass:=pass;
   End;
  End Else syms[i].xdef:=True;
  ParseSizeSuffix(sfx);
  SkipSp;
  If PeekCh=',' Then Inc(LPOS) Else Break;
 End;
End;

Procedure DoInclude;
Var
 nm,full:String;
Begin
 If Not ParseTextArg(nm,False)Then Begin
  Error(Tr('Nom de fichier attendu','File name expected'));
  Exit;
 End;
 full:=FindIncludeFile(nm);
 If full='' Then Begin
  Error(Tr('Fichier INCLUDE introuvable : ','INCLUDE file not found: ')+nm);
  Exit;
 End;
 If Not PushFile(full)Then
  Error(Tr('Impossible d''ouvrir : ','Cannot open: ')+full);
End;

Procedure DoIncdir;
Var
 nm:String;
 i:Longint;
Begin
 If Not ParseTextArg(nm,False)Then Exit;
 For i:=1 to Length(nm) do If nm[i]='\' Then nm[i]:='/';
 If(nm<>'')and Not(nm[Length(nm)] in ['/',':'])Then nm:=nm+'/';
 If nIncPath<MAX_INCP Then Begin
  Inc(nIncPath);
  incPath[nIncPath]:=nm;
 End;
End;

Procedure DoIncbin;
Var
 nm,full:String;
 f:File;
 buf:Array[0..4095] of Byte;
 got,i:Longint;
Begin
 If Not ParseTextArg(nm,False)Then Begin
  Error(Tr('Nom de fichier attendu','File name expected'));
  Exit;
 End;
 full:=FindIncludeFile(nm);
 If full='' Then Begin
  Error(Tr('Fichier INCBIN introuvable : ','INCBIN file not found: ')+nm);
  Exit;
 End;
 Assign(f,full);
 Reset(f,1);
 If IOResult<>0 Then Begin
  Error(Tr('Impossible d''ouvrir : ','Cannot open: ')+full);
  Exit;
 End;
 While Not Eof(f) do Begin
  BlockRead(f,buf,SizeOf(buf),got);
  If got<=0 Then Break;
  For i:=0 to got-1 do EmitB(buf[i]);
 End;
 Close(f);
End;

Procedure StartMacro(Const lab:String);
Var
 nm:String;
Begin
 nm:=lab;
 If nm='' Then Begin
  SkipSp;
  nm:=PeekIdent;
 End;
 If nm='' Then Begin
  Error(Tr('Nom de macro attendu','Macro name expected'));
  Exit;
 End;
 colKind:=1;
 colName:=UpStr(nm);
 colDepth:=1;
 colFirst:=Nil;
 colLast:=Nil;
 colLines:=0;
End;

Procedure DoMexit;
Var
 found:Boolean;
 i:Longint;
Begin
 found:=False;
 For i:=srcTop downto 0 do If src[i].kind=SRC_MACRO Then
   Begin found:=True;Break;End;
 If Not found Then Begin
  Error(Tr('MEXIT en dehors d''une macro','MEXIT outside a macro'));
  Exit;
 End;
 While(srcTop>=0)and(src[srcTop].kind<>SRC_MACRO)do PopSrc;
 PopSrc;
End;

Procedure ApplyOptFlag2(Const nm:String;on:Boolean);
Var
 n:Longint;
Begin
 If nm='A' Then opt.a:=on Else
 If nm='C' Then opt.c:=on Else
 If nm='D' Then opt.d:=on Else
 If nm='L' Then opt.l:=on Else
 If nm='M' Then opt.m:=on Else
 If nm='O' Then Begin opt.o:=on;opt.o1:=on;opt.o2:=on;End Else
 If nm='O1' Then opt.o1:=on Else
 If nm='O2' Then opt.o2:=on Else
 If nm='P' Then opt.p:=on Else
 If nm='S' Then opt.s:=on Else
 If nm='T' Then opt.t:=on Else
 If nm='W' Then opt.w:=on Else
 If nm='X' Then opt.x:=on Else
 If(nm[1]='C')and(Length(nm)>1)Then Begin
  n:=0;
  Val(Copy(nm,2,5),n);
  If on Then opt.cn:=n Else opt.cn:=0;
 End Else Warn(Tr('Option OPT inconnue : ','Unknown OPT option: ')+nm);
End;

Procedure ApplyOptFlag(Const nm:String;on:Boolean);
Begin
 ApplyOptFlag2(nm,on);
 If(nm='C')and Not on Then caseInsSeen:=True;
 If(opt.c<>keyedC)or(opt.cn<>keyedCn)Then RekeySyms;
End;

Procedure DoOpt;
Var
 tok:String;
 on:Boolean;
Begin
 While True do Begin
  SkipSp;
  tok:='';
  While(LPOS<=Length(LP))and Not(LP[LPOS] in [',',' ',#9,';'])do Begin
   tok:=tok+UpCase(LP[LPOS]);
   Inc(LPOS);
  End;
  If tok='' Then Break;
  on:=True;
  If tok[Length(tok)]='+' Then Dec(tok[0]) Else If tok[Length(tok)]='-' Then
    Begin
   on:=False;
   Dec(tok[0]);
  End;
  If tok<>'' Then ApplyOptFlag(tok,on);
  SkipSp;
  If PeekCh=',' Then Inc(LPOS) Else Break;
 End;
End;

Procedure DoEqu(Const lab:String;kind:Byte);
Var
 v:TVal;
Begin
 If lab='' Then Begin
  Error(Tr('Etiquette requise','Label required'));
  Exit;
 End;
 ExprFull(v);
 If exprErr Then Exit;
 DefineSymbol(lab,v,kind);
End;

Procedure DoEqur(Const lab:String);
Var
 r:Longint;
 v:TVal;
Begin
 If lab='' Then Begin
  Error(Tr('Etiquette requise','Label required'));
  Exit;
 End;
 SkipSp;
 If Not TryReg(r)Then Begin
  Error(Tr('Registre attendu','Register expected'));
  Exit;
 End;
 MkAbs(v,r);
 DefineSymbol(lab,v,SK_EQUR);
End;

Procedure DoRegList(Const lab:String);
Var
 m:Longint;
 v:TVal;
Begin
 If lab='' Then Begin
  Error(Tr('Etiquette requise','Label required'));
  Exit;
 End;
 If Not ParseRegList(m)Then Begin
  Error(Tr('Liste de registres invalide','Invalid register list'));
  Exit;
 End;
 MkAbs(v,m);
 DefineSymbol(lab,v,SK_REGLIST);
End;

Procedure DoRs(Const lab,ext:String;isFo:Boolean);
Var
 sz,n:Longint;
 v:TVal;
Begin
 sz:=SizeOfDirExt(ext,2);
 ExprAbsV(v);
 If exprErr Then Exit;
 n:=v.v;
 If isFo Then Begin
  If(sz>1)and((foCnt and 1)<>0)Then Dec(foCnt);
  foCnt:=foCnt-n*sz;
  If lab<>'' Then Begin
   MkAbs(v,foCnt);
   DefineSymbol(lab,v,SK_EQU);
  End;
 End Else Begin
  If(sz>1)and((rsCnt and 1)<>0)Then Inc(rsCnt);
  If lab<>'' Then Begin
   MkAbs(v,rsCnt);
   DefineSymbol(lab,v,SK_EQU);
  End;
  rsCnt:=rsCnt+n*sz;
 End;
End;

Procedure DoIfValue(id:Longint;Const up:String);
Var
 v:Longint;
 r:Boolean;
Begin
 ExprAbs(v);
 If up='IFEQ' Then r:=(v=0) Else
 If up='IFNE' Then r:=(v<>0) Else
 If up='IFGT' Then r:=(v>0) Else
 If up='IFGE' Then r:=(v>=0) Else
 If up='IFLT' Then r:=(v<0) Else
 If up='IFLE' Then r:=(v<=0) Else r:=(v<>0);
 PushCond(r);
End;

Procedure DoIfDef(neg:Boolean);
Var
 id:String;
 i:Longint;
 r:Boolean;
Begin
 SkipSp;
 id:=PeekIdent;
 If id='' Then Begin
  Error(Tr('Nom de symbole attendu','Symbol name expected'));
  PushCond(False);
  Exit;
 End;
 i:=FindSym(SymKey(MangleName(id)));
 r:=(i>=0)and(syms[i].defpass=pass)and(syms[i].kind<>SK_NONE);
 If neg Then r:=Not r;
 PushCond(r);
End;

Procedure DoIfc(neg:Boolean);
Var
 a,b:String;
 r:Boolean;
Begin
 ParseTextArg(a,True);
 SkipSp;
 If PeekCh=',' Then Inc(LPOS);
 ParseTextArg(b,True);
 r:=(a=b);
 If neg Then r:=Not r;
 PushCond(r);
End;

Procedure DoPrintt;
Var
 s:String;
Begin
 ParseTextArg(s,False);
 If final Then WriteLn(s);
End;

Procedure DoPrintv;
Var
 v:Longint;
Begin
 ExprAbs(v);
 If final Then WriteLn(v);
End;

{ ------------------------------------------------------------------------ }
{ Traitement d'une ligne                                                    }
{ ------------------------------------------------------------------------ }

Procedure CollectLine(Const s:String);
Var
 lab,mn,ext,up:String;
 op:Longint;
Begin
 SplitLine(s,lab,mn,ext,op);
 up:=UpStr(mn);
 If colKind=1 Then Begin
  If up='MACRO' Then Inc(colDepth) Else
  If up='ENDM' Then Dec(colDepth);
  If colDepth=0 Then Begin
   FinishMacro;
   Exit;
  End;
 End Else Begin
  If up='REPT' Then Inc(colDepth) Else
  If up='ENDR' Then Dec(colDepth);
  If colDepth=0 Then Begin
   colKind:=0;
   If(colCount>0)and(colFirst<>Nil)Then Begin
    If srcTop>=MAX_SRC-1 Then Begin
     Error(Tr('Imbrication de sources trop profonde',
       'Source nesting too deep'));
     FreeLines(colFirst);
    End Else Begin
     Inc(srcTop);
     src[srcTop].kind:=SRC_REPT;
     src[srcTop].isopen:=False;
     src[srcTop].buf:=Nil;
     src[srcTop].name:='REPT';
     src[srcTop].macname:='REPT';
     src[srcTop].first:=colFirst;
     src[srcTop].cur:=colFirst;
     src[srcTop].count:=colCount;
     src[srcTop].line:=0;
     src[srcTop].narg:=0;
    End;
   End Else FreeLines(colFirst);
   colFirst:=Nil;
   colLast:=Nil;
   Exit;
  End;
 End;
 AppendLine(colFirst,colLast,s);
 Inc(colLines);
End;

Procedure DoDirective(id:Longint;Const up,ext:String);
Var
 sz:Longint;
Begin
 Case id of
  D_DC:DoDC(ext);
  D_DS:DoDS(ext);
  D_DCB:DoDCB(ext);
  D_BLK:DoDS(ext);
  D_EVEN:AlignEven;
  D_CNOP:DoCnop;
  D_ORG:DoOrg;
  D_END:endSeen:=True;
  D_XDEF:DoXdef(False);
  D_XREF:DoXdef(True);
  D_SECTION,D_CODE,D_DATA,D_BSS:DoSection(up,ext);
  D_OFFSET:DoOffset;
  D_INCLUDE:DoInclude;
  D_INCDIR:DoIncdir;
  D_INCBIN:DoIncbin;
  D_ENDM:Error(Tr('ENDM sans MACRO','ENDM without MACRO'));
  D_ENDR:Error(Tr('ENDR sans REPT','ENDR without REPT'));
  D_MEXIT:DoMexit;
  D_REPT:Begin
   ExprAbs(sz);
   If exprErr Then Exit;
   colKind:=2;
   colCount:=sz;
   colDepth:=1;
   colFirst:=Nil;
   colLast:=Nil;
   colLines:=0;
  End;
  D_OPT:DoOpt;
  D_LIST:listOn:=True;
  D_NOLIST:listOn:=False;
  D_PAGE:If final Then ListNewPage;
  D_TTL:ParseTextArg(listTitle,False);
  D_SUBTTL:ParseTextArg(listSub,False);
  D_SPC:Begin
   ExprAbs(sz);
   While(sz>0)and final and listOpen do Begin ListRaw('');Dec(sz);End;
  End;
  D_LLEN:ExprAbs(sz);
  D_PLEN:Begin
   ExprAbs(sz);
   If sz>10 Then listPLen:=sz;
  End;
  D_FAIL:Error('FAIL');
  D_PRINTT:DoPrintt;
  D_PRINTV:DoPrintv;
  D_MC:Begin
   If up='MC68000' Then cpu:=CPU_68000 Else
   If up='MC68010' Then cpu:=CPU_68010 Else
   If up='MC68020' Then cpu:=CPU_68020 Else
   If up='MC68030' Then Begin cpu:=CPU_68030;mmuFlag:=True;End Else
   If up='MC68040' Then Begin
    cpu:=CPU_68040;
    fpuFlag:=True;
    mmuFlag:=True;
   End Else
   If up='MC68060' Then Begin
    cpu:=CPU_68060;
    fpuFlag:=True;
    mmuFlag:=True;
   End Else
   If(up='MC68881')or(up='MC68882')Then fpuFlag:=True Else
   If up='MC68851' Then mmuFlag:=True;
  End;
  D_IDNT:Begin
   ParseTextArg(unitName,False);
  End;
  D_OUTPUT:Begin
   ParseTextArg(outNameDir,False);
  End;
  D_IGNORE:;
 End;
End;

Procedure ProcessLine(Const s:String);
Var
 lab,mn,ext,up:String;
 opStart:Longint;
 d:Longint;
 cls,idx,cc:Longint;
 m:Longint;
Begin
 curLineText:=s;
 errThisLine:=False;
 lineStartSec:=cursec;
 If inOffset Then lineStartPC:=offPC Else If cursec>=0
   Then lineStartPC:=sec[cursec].size Else lineStartPC:=0;
 lineHasCode:=False;
 lstLine:=CurFileLine;
 If srcTop>=0 Then lstKind:=src[srcTop].kind Else lstKind:=SRC_FILE;
 If colKind<>0 Then Begin
  CollectLine(s);
  ListLine(s);
  Exit;
 End;
 SplitLine(s,lab,mn,ext,opStart);
 up:=UpStr(mn);
 LP:=Copy(s,opStart,255);
 LPOS:=1;
 exprErr:=False;
 { directives conditionnelles }
 d:=0;
 If up<>'' Then d:=FindDirective(up);
 If d>0 Then d:=DirIds[d];
 If d in [D_IF,D_IFD,D_IFND,D_IFC,D_IFNC,D_ELSE,D_ENDC]Then Begin
  If Not CondActive Then Begin
   If d in [D_IF,D_IFD,D_IFND,D_IFC,D_IFNC]Then PushCond(False)
   Else If d=D_ELSE Then ElseCond Else EndCond;
  End Else Begin
   Case d of
    D_IF:DoIfValue(d,up);
    D_IFD:DoIfDef(False);
    D_IFND:DoIfDef(True);
    D_IFC:DoIfc(False);
    D_IFNC:DoIfc(True);
    D_ELSE:ElseCond;
    D_ENDC:EndCond;
   End;
  End;
  ListLine(s);
  Exit;
 End;
 If Not CondActive Then Begin
  ListLine(s);
  Exit;
 End;
 If(lab='')and(mn='')Then Begin
  ListLine(s);
  Exit;
 End;
 If mn='' Then Begin
  DefineLabel(lab);
  ListLine(s);
  Exit;
 End;
 { macro ? }
 m:=FindMacro(up);
 If m>=0 Then Begin
  If lab<>'' Then DefineLabel(lab);
  InvokeMacro(m,ext,Copy(s,opStart,255));
  ListLine(s);
  Exit;
 End;
 If d>0 Then Begin
  { directives }
  Case d of
   D_EQU:DoEqu(lab,SK_EQU);
   D_SET:DoEqu(lab,SK_SET);
   D_EQUR:DoEqur(lab);
   D_REG:DoRegList(lab);
   D_MACRO:StartMacro(lab);
   D_RS:DoRs(lab,ext,False);
   D_FO:DoRs(lab,ext,True);
   D_RSRESET:Begin rsCnt:=0;foCnt:=0;End;
   D_RSSET:Begin
    ExprAbs(m);
    rsCnt:=m;
   End;
   Else Begin
    If(d in [D_DC,D_DS,D_DCB,D_BLK])and((ext='W')or(ext='L')or(ext='')
      or(ext='S')or(ext='D')or(ext='X')or
    (ext='P'))Then Begin
     AlignEven;
    End;
    If(lab<>'')and(d<>D_OFFSET)and(d<>D_SECTION)and(d<>D_CODE)and(d<>D_DATA)
      and(d<>D_BSS)Then
     DefineLabel(lab);
    DoDirective(d,up,ext);
    If(lab<>'')and(d in [D_SECTION,D_CODE,D_DATA,D_BSS,
      D_OFFSET])Then DefineLabel(lab);
   End;
  End;
  If(d in [D_DC,D_DS,D_DCB])Then lineHasCode:=True;
  ListLine(s);
  Exit;
 End;
 { instruction }
 If FindInstr(up,cls,idx,cc)Then Begin
  AlignEven;
  If lab<>'' Then DefineLabel(lab);
  lineStartSec:=cursec;
  If inOffset Then lineStartPC:=offPC Else If cursec>=0
    Then lineStartPC:=sec[cursec].size;
  If inOffset Then Error(Tr('Instruction non permise dans une section OFFSET',
    'Instruction not allowed in an OFFSET section'))
   Else DoInstruction(cls,idx,cc,ext);
  lineHasCode:=True;
  If opt.d and(cursec>=0)and(CurFileId=0)and(sec[cursec].kind<>ST_BSS)and
    (sec[cursec].size>lineStartPC)Then Begin
   AddLineEnt(lineStartPC,CurFileLine);
  End;
  ListLine(s);
  Exit;
 End;
 If lab<>'' Then DefineLabel(lab);
 Error(Tr('Instruction, directive ou macro inconnue : ',
   'Unknown instruction, directive or macro: ')+mn);
 ListLine(s);
End;

{ ------------------------------------------------------------------------ }
{ Ecriture du fichier de sortie (format Hunk AmigaOS)                       }
{ ------------------------------------------------------------------------ }

Procedure OutGrow(n:Longint);
Var
 nc:Longint;
Begin
 If outLen+n>outCap Then Begin
  nc:=outCap*2;
  If nc<65536 Then nc:=65536;
  While nc<outLen+n do nc:=nc*2;
  ReAllocMem(outBuf,nc);
  outCap:=nc;
 End;
End;

Procedure PutB(b:Longint);
Begin
 OutGrow(1);
 outBuf^[outLen]:=b and $FF;
 Inc(outLen);
End;

Procedure PutL(l:Longint);
Begin
 PutB(l shr 24);
 PutB(l shr 16);
 PutB(l shr 8);
 PutB(l);
End;

Procedure PutPad(size:Longint);
Begin
 While(size and 3)<>0 do Begin
  PutB(0);
  Inc(size);
 End;
End;

Procedure PutStr(Const s:String);
Var
 i:Longint;
Begin
 For i:=1 to Length(s) do PutB(Ord(s[i]));
 PutPad(Length(s));
End;

Function NameLongs(Const s:String):Longint;
Begin
 NameLongs:=(Length(s)+3)div 4;
End;

Procedure PutName(Const s:String);
Begin
 PutL(NameLongs(s));
 PutStr(s);
End;

Procedure PutExtName(typ:Longint;Const s:String);
Begin
 PutL((typ shl 24)or NameLongs(s));
 PutStr(s);
End;

Function MemBits(m:Byte):Longint;
Begin
 Case m of
  MEM_CHIP:MemBits:=$40000000;
  MEM_FAST:MemBits:=Longint($80000000);
  Else MemBits:=0;
 End;
End;

Function ExportName(i:Longint):String;
Begin
 If syms[i].orig<>'' Then ExportName:=SymDisplayName(syms[i].orig)
   Else ExportName:=syms[i].name;
End;

Procedure PutSectionData(si:Longint);
Var
 i:Longint;
Begin
 With sec[si] do Begin
  If kind=ST_BSS Then Exit;
  For i:=0 to size-1 do PutB(data^[i]);
  PutPad(size);
 End;
End;

Procedure PutRelocs(si:Longint);
Var
 t,j,cnt:Longint;
Begin
 With sec[si] do Begin
  If nrel=0 Then Exit;
  PutL(HUNK_RELOC32);
  For t:=0 to nsec-1 do Begin
   cnt:=0;
   For j:=0 to nrel-1 do If rel^[j].tgt=t Then Inc(cnt);
   If cnt>0 Then Begin
    PutL(cnt);
    PutL(t);
    For j:=0 to nrel-1 do If rel^[j].tgt=t Then PutL(rel^[j].off);
   End;
  End;
  PutL(0);
 End;
End;

Procedure PutSymbols(si:Longint);
Var
 k,n:Longint;
Begin
 n:=0;
 For k:=0 to nsym-1 do
  If(syms[k].kind=SK_LABEL)and(syms[k].sect=si)and(syms[k].defpass=pass)
    and Not syms[k].islocal Then Inc(n);
 If n=0 Then Exit;
 PutL(HUNK_SYMBOL);
 For k:=0 to nsym-1 do
  If(syms[k].kind=SK_LABEL)and(syms[k].sect=si)and(syms[k].defpass=pass)
    and Not syms[k].islocal Then Begin
   PutName(ExportName(k));
   PutL(syms[k].v);
  End;
 PutL(0);
End;

Procedure PutDebug(si:Longint);
Var
 j:Longint;
 nm:String;
Begin
 With sec[si] do Begin
  If nln=0 Then Exit;
  nm:=BaseName(mainFileName);
  PutL(HUNK_DEBUG);
  PutL(3+NameLongs(nm)+2*nln);
  PutL(0);
  PutL($4C494E45);
  PutName(nm);
  For j:=0 to nln-1 do Begin
   PutL(ln^[j].line);
   PutL(ln^[j].off);
  End;
 End;
End;

Procedure PutExt(si:Longint);
Var
 k,j,m,cnt,hasAny:Longint;
 done:PByteArr;
 typ:Byte;
 isDef:Boolean;
Begin
 hasAny:=0;
 For k:=0 to nsym-1 do Begin
  If(syms[k].defpass=pass)and(syms[k].kind in [SK_LABEL,SK_EQU,
    SK_SET])Then Begin
   isDef:=syms[k].xdef or(opt.x and(syms[k].kind=SK_LABEL)
     and Not syms[k].islocal);
   If isDef and((syms[k].sect=si)or((syms[k].sect=-1)and(si=0)))
     Then Inc(hasAny);
  End;
 End;
 If sec[si].nxr>0 Then Inc(hasAny);
 If hasAny=0 Then Exit;
 PutL(HUNK_EXT);
 For k:=0 to nsym-1 do Begin
  If(syms[k].defpass=pass)and(syms[k].kind in [SK_LABEL,SK_EQU,
    SK_SET])Then Begin
   isDef:=syms[k].xdef or(opt.x and(syms[k].kind=SK_LABEL)
     and Not syms[k].islocal);
   If isDef Then Begin
    If syms[k].sect=si Then Begin
     PutExtName(EXT_DEF,ExportName(k));
     PutL(syms[k].v);
    End Else If(syms[k].sect=-1)and(si=0)Then Begin
     PutExtName(EXT_ABS,ExportName(k));
     PutL(syms[k].v);
    End;
   End;
  End;
 End;
 With sec[si] do Begin
  If nxr>0 Then Begin
   GetMem(done,nxr);
   FillChar(done^,nxr,0);
   For j:=0 to nxr-1 do Begin
    If done^[j]=0 Then Begin
     cnt:=0;
     typ:=xr^[j].typ;
     For m:=j to nxr-1 do
      If(done^[m]=0)and(xr^[m].sym=xr^[j].sym)and(xr^[m].typ=typ)Then Inc(cnt);
     PutExtName(typ,ExportName(xr^[j].sym));
     PutL(cnt);
     For m:=j to nxr-1 do
      If(done^[m]=0)and(xr^[m].sym=xr^[j].sym)and(xr^[m].typ=typ)Then Begin
       PutL(xr^[m].off);
       done^[m]:=1;
      End;
    End;
   End;
   FreeMem(done,nxr);
  End;
 End;
 PutL(0);
End;

Procedure BuildExecutable;
Var
 i:Longint;
Begin
 PutL(HUNK_HEADER);
 PutL(0);
 PutL(nsec);
 PutL(0);
 PutL(nsec-1);
 For i:=0 to nsec-1 do PutL(((sec[i].size+3)div 4)or MemBits(sec[i].mem));
 For i:=0 to nsec-1 do Begin
  Case sec[i].kind of
   ST_CODE:PutL(HUNK_CODE);
   ST_DATA:PutL(HUNK_DATA);
   Else PutL(HUNK_BSS);
  End;
  PutL((sec[i].size+3)div 4);
  PutSectionData(i);
  If sec[i].kind<>ST_BSS Then PutRelocs(i);
  If opt.d Then Begin
   PutSymbols(i);
   PutDebug(i);
  End;
  PutL(HUNK_END);
 End;
End;

Procedure BuildObject;
Var
 i:Longint;
 un:String;
Begin
 un:=unitName;
 If un='' Then un:=BaseName(StripExt(srcName));
 PutL(HUNK_UNIT);
 PutName(un);
 For i:=0 to nsec-1 do Begin
  If sec[i].name<>'' Then Begin
   PutL(HUNK_NAME);
   PutName(sec[i].name);
  End;
  Case sec[i].kind of
   ST_CODE:PutL(HUNK_CODE);
   ST_DATA:PutL(HUNK_DATA);
   Else PutL(HUNK_BSS);
  End;
  PutL(((sec[i].size+3)div 4)or MemBits(sec[i].mem));
  PutSectionData(i);
  If sec[i].kind<>ST_BSS Then PutRelocs(i);
  PutExt(i);
  If opt.d Then Begin
   PutSymbols(i);
   PutDebug(i);
  End;
  PutL(HUNK_END);
 End;
End;

Procedure BuildRaw;
Var
 i:Longint;
Begin
 If(nsec>0)and(sec[0].kind<>ST_BSS)Then
  For i:=0 to sec[0].size-1 do PutB(sec[0].data^[i]);
End;

{ ------------------------------------------------------------------------ }
{ Table des symboles dans le listing                                        }
{ ------------------------------------------------------------------------ }

Procedure PrintSymbolTable;
Var
 idx:Array[0..MAX_SYM-1] of Longint;
 n,i,j,t,gap:Longint;
 line:String;
Begin
 n:=0;
 For i:=0 to nsym-1 do
  If(syms[i].kind in [SK_LABEL,SK_EQU,SK_SET,SK_REGLIST,
    SK_XREF])and Not syms[i].islocal Then Begin
   idx[n]:=i;
   Inc(n);
  End;
 gap:=n div 2;
 While gap>0 do Begin
  For i:=gap to n-1 do Begin
   t:=idx[i];
   j:=i;
   While(j>=gap)and(UpStr(ExportName(idx[j-gap]))>UpStr(ExportName(t)))do Begin
    idx[j]:=idx[j-gap];
    Dec(j,gap);
   End;
   idx[j]:=t;
  End;
  gap:=gap div 2;
 End;
 If listOpen Then Begin
  ListRaw('');
  ListRaw(Tr('Table des symboles :','Symbol table:'));
 End Else Begin
  WriteLn;
  WriteLn(Tr('Table des symboles :','Symbol table:'));
 End;
 For i:=0 to n-1 do Begin
  j:=idx[i];
  line:=Fmt(ExportName(j),32)+' ';
  Case syms[j].kind of
   SK_XREF:line:=line+'XREF';
   SK_REGLIST:line:=line+'REG   '+HexStr(syms[j].v,4);
   Else Begin
    line:=line+'$'+HexStr(syms[j].v,8);
    If syms[j].sect>=0 Then Begin
     line:=line+'  '+Tr('section ','section ')+IntStr(syms[j].sect);
     If sec[syms[j].sect].name<>''
       Then line:=line+' ('+sec[syms[j].sect].name+')';
    End;
    If syms[j].xdef Then line:=line+'  XDEF';
   End;
  End;
  If listOpen Then ListRaw(line) Else WriteLn(line);
 End;
End;

{ ------------------------------------------------------------------------ }
{ Passes d'assemblage                                                       }
{ ------------------------------------------------------------------------ }

Procedure InitPass;
Var
 i:Longint;
 v:TVal;
Begin
 opt:=optDef;
 If caseInsSeen Then opt.c:=False;
 If(opt.c<>keyedC)or(opt.cn<>keyedCn)Then RekeySyms;
 cpu:=cpuDef;
 fpuFlag:=cpuDef>=CPU_68040;
 mmuFlag:=cpuDef>=CPU_68030;
 gSpecial:=0;
 lastGlobal:='';
 rsCnt:=0;
 foCnt:=0;
 condDepth:=0;
 colKind:=0;
 colFirst:=Nil;
 colLast:=Nil;
 srcTop:=-1;
 sitePos:=0;
 siteChanged:=False;
 symChanged:=False;
 errors:=0;
 warnings:=0;
 endSeen:=False;
 uniqCount:=0;
 nIncPath:=nCmdInc;
 cursec:=-1;
 inOffset:=False;
 offPC:=0;
 orgMode:=False;
 orgAddr:=0;
 listOn:=True;
 listTitle:='';
 listSub:='';
 curLineText:='';
 For i:=0 to nsec-1 do Begin
  sec[i].size:=0;
  sec[i].nrel:=0;
  sec[i].nxr:=0;
  sec[i].nln:=0;
 End;
 For i:=1 to nCmdDef do Begin
  MkAbs(v,cmdDefVal[i]);
  DefineSymbol(cmdDefs[i],v,SK_SET);
 End;
End;

Procedure CheckUndefined;
Var
 i:Longint;
Begin
 For i:=0 to nsym-1 do Begin
  If(syms[i].kind<>SK_XREF)and(syms[i].refpass=pass)and(syms[i].defpass<>pass)
    Then Begin
   Inc(errors);
   WriteLn(fileNames[syms[i].reffile],'(',syms[i].refline,'): ',Tr('Erreur : ',
     'Error: '),
           Tr('Symbole non defini : ','Undefined symbol: '),
             SymDisplayName(ExportName(i)));
  End Else If syms[i].xdef and(syms[i].defpass<>pass)Then Begin
   Inc(errors);
   WriteLn(Tr('Erreur : ','Error: '),Tr('Symbole XDEF non defini : ',
     'Undefined XDEF symbol: '),ExportName(i));
  End;
 End;
End;

Procedure RunPass(isFinal:Boolean);
Var
 line:String;
 i:Longint;
Begin
 Inc(pass);
 final:=isFinal;
 InitPass;
 If Not PushFile(srcName)Then Fatal(Tr('Fichier source introuvable : ',
   'Source file not found: ')+srcName);
 mainFileName:=srcName;
 While(Not endSeen)and NextSrcLine(line) do ProcessLine(line);
 curLineText:='';
 If colKind<>0 Then Begin
  If colKind=1 Then Error(Tr('MACRO sans ENDM','MACRO without ENDM'))
   Else Error(Tr('REPT sans ENDR','REPT without ENDR'));
  FreeLines(colFirst);
  colFirst:=Nil;
  colKind:=0;
 End;
 While srcTop>=0 do PopSrc;
 If condDepth>0 Then Error(Tr('IF sans ENDC correspondant',
   'IF without matching ENDC'));
 If isFinal Then Begin
  CheckUndefined;
  If Not opt.l Then
   For i:=0 to nsec-1 do If sec[i].nxr>0 Then Begin
    Inc(errors);
    WriteLn(Tr('Erreur : XREF en mode executable ; utilisez -L',
               'Error: XREF in executable mode; use -L'));
    Break;
   End;
 End;
End;

{ ------------------------------------------------------------------------ }
{ Ligne de commande                                                         }
{ ------------------------------------------------------------------------ }

Procedure ShowHelp;
Begin
 If Language=1 Then Begin
  WriteLn('GENAM : Devpac GenAm clone - 680x0, FPU, MMU Amiga assembler.');
  WriteLn;
  WriteLn('Syntax : GENAM [options] source[.s]         Help : GENAM /?');
  WriteLn;
  WriteLn('  -A          PC-relative optimisation of addresses (OPT A+)');
  WriteLn('  -C          case-insensitive labels (OPT C-)');
  WriteLn('  -D          debug information (OPT D+)');
  WriteLn('  -E<s>[=<n>] define symbol <s> with value <n> (default 1)');
  WriteLn('  -I<dir>     add an INCLUDE directory');
  WriteLn('  -L          linkable object code (OPT L+); default: executable');
  WriteLn('  -M          show macro expansions in the listing (OPT M+)');
  WriteLn('  -O          all optimisations (OPT O+); -O1 -O2');
  WriteLn('  -o<file>    output file name');
  WriteLn('  -P[file]    write a listing (to file, or to the screen)');
  WriteLn('  -S          symbol table at the end of the listing (OPT S+)');
  WriteLn('  -T          type/size checking of values (OPT T+)');
  WriteLn('  -W          disable warnings (OPT W-)');
  WriteLn('  -X          export all labels as XDEF (OPT X+)');
  WriteLn('  -680x0      target processor: 68000 (default) 68010 68020 68030');
  WriteLn('              68040 68060, e.g. -68020');
  WriteLn('  -Q          quiet mode (no banner)');
  WriteLn;
  WriteLn('OPT directives: A C C<n> D L M O O1 O2 P S T W X (suffix + or -)');
  WriteLn('Coprocessors: MC68881 / MC68882 (FPU), MC68851 (MMU);');
  WriteLn('68030/68040 MMU enabled with -68030 / -68040.');
 End Else Begin
  WriteLn('GENAM : Clone de Devpac GenAm - Assembleur 680x0, FPU, MMU Amiga.');
  WriteLn;
  WriteLn('Syntaxe : GENAM [options] source[.s]        Aide : GENAM /?');
  WriteLn;
  WriteLn('  -A          optimisation PC-relative des adresses (OPT A+)');
  WriteLn('  -C          etiquettes insensibles a la casse (OPT C-)');
  WriteLn('  -D          informations de debogage (OPT D+)');
  WriteLn('  -E<s>[=<n>] definit le symbole <s> avec la valeur <n> (defaut 1)');
  WriteLn('  -I<rep>     ajoute un repertoire pour INCLUDE');
  WriteLn('  -L          code objet linkable (OPT L+) ; defaut : executable');
  WriteLn('  -M          expansion des macros dans le listing (OPT M+)');
  WriteLn('  -O          toutes les optimisations (OPT O+) ; -O1 -O2');
  WriteLn('  -o<fichier> nom du fichier de sortie');
  WriteLn('  -P[fichier] genere un listing (dans un fichier, ou a l''ecran)');
  WriteLn('  -S          table des symboles en fin de listing (OPT S+)');
  WriteLn('  -T          verification du type/taille des valeurs (OPT T+)');
  WriteLn('  -W          desactive les avertissements (OPT W-)');
  WriteLn('  -X          exporte toutes les etiquettes en XDEF (OPT X+)');
  WriteLn('  -680x0      processeur cible : 68000 (defaut) 68010 68020 68030');
  WriteLn('              68040 68060, par exemple -68020');
  WriteLn('  -Q          mode silencieux (pas de banniere)');
  WriteLn;
  WriteLn('Directives OPT : A C C<n> D L M O O1 O2 P S T W X (suffixe + ou -)');
  WriteLn('Coprocesseurs : MC68881 / MC68882 (FPU) et MC68851 (MMU) ;');
  WriteLn('MMU 68030/68040 actives avec -68030 / -68040.');
 End;
End;

Procedure ParseCmdLine;
Var
 i,j,k:Longint;
 p,u,r:String;
 v:Longint;
Begin
 i:=0;
 While i<ParamCount do Begin
  Inc(i);
  p:=ParamStr(i);
  If(p='')Then Continue;
  If(p='/?')or(p='--help')or(p='-?')or(UpStr(p)='-H')Then Begin
   ShowHelp;
   Halt(0);
  End;
  If p[1]='-' Then Begin
   If(Length(p)=6)and(p[2]='6')and(p[3]='8')Then Begin
    If Copy(p,2,5)='68000' Then cpuDef:=CPU_68000 Else
    If Copy(p,2,5)='68010' Then cpuDef:=CPU_68010 Else
    If Copy(p,2,5)='68030' Then cpuDef:=CPU_68030 Else
    If Copy(p,2,5)='68040' Then cpuDef:=CPU_68040 Else
    If Copy(p,2,5)='68060' Then cpuDef:=CPU_68060 Else cpuDef:=CPU_68020;
    Continue;
   End;
   If Length(p)<2 Then Continue;
   r:=Copy(p,3,255);
   u:=UpStr(r);
   Case UpCase(p[2]) of
    'A':optDef.a:=True;
    'C':optDef.c:=False;
    'D':optDef.d:=True;
    'E':Begin
     If nCmdDef<32 Then Begin
      Inc(nCmdDef);
      j:=Pos('=',r);
      v:=1;
      If j>0 Then Begin
       Val(Copy(r,j+1,20),v,k);
       If k<>0 Then v:=1;
       r:=Copy(r,1,j-1);
      End;
      cmdDefs[nCmdDef]:=r;
      cmdDefVal[nCmdDef]:=v;
     End;
    End;
    'I':Begin
     If nCmdInc<MAX_INCP Then Begin
      For j:=1 to Length(r) do If r[j]='\' Then r[j]:='/';
      If(r<>'')and Not(r[Length(r)] in ['/',':'])Then r:=r+'/';
      Inc(nCmdInc);
      incPath[nCmdInc]:=r;
     End;
    End;
    'L':optDef.l:=True;
    'M':optDef.m:=True;
    'O':Begin
     If(p[2]='o')and(r='')and(i<ParamCount)Then Begin
      Inc(i);
      cmdOutName:=ParamStr(i);
     End Else
     If p[2]='o' Then cmdOutName:=r Else
     If u='' Then Begin optDef.o:=True;optDef.o1:=True;optDef.o2:=True;End Else
     If u='1' Then optDef.o1:=True Else
     If u='2' Then optDef.o2:=True Else cmdOutName:=r;
    End;
    'P':Begin
     cmdList:=True;
     cmdListName:=r;
    End;
    'S':optDef.s:=True;
    'T':optDef.t:=True;
    'W':optDef.w:=False;
    'X':optDef.x:=True;
    'Q':cmdQuiet:=True;
    Else Begin
     WriteLn(Tr('Option inconnue : ','Unknown option: ')+p);
     Halt(5);
    End;
   End;
  End Else If srcName='' Then srcName:=p
  Else Begin
   WriteLn(Tr('Parametre superflu : ','Extra parameter: ')+p);
   Halt(5);
  End;
 End;
End;

Function LocateSource(Const n:String):String;
Var
 r,d,f:String;
Begin
 LocateSource:='';
 If FileExists(n)Then Begin LocateSource:=n;Exit;End;
 d:=DirName(n);
 f:=BaseName(n);
 r:=FindCI(d,f);
 If r<>'' Then Begin LocateSource:=d+r;Exit;End;
 If Pos('.',f)=0 Then Begin
  If FileExists(n+'.s')Then Begin LocateSource:=n+'.s';Exit;End;
  r:=FindCI(d,f+'.s');
  If r<>'' Then Begin LocateSource:=d+r;Exit;End;
  r:=FindCI(d,f+'.asm');
  If r<>'' Then Begin LocateSource:=d+r;Exit;End;
 End;
End;

Procedure WriteOutput;
Var
 outName:String;
 f:File;
 i,total:Longint;
 kindName:String;
Begin
 outLen:=0;
 If orgMode Then BuildRaw Else If opt.l Then BuildObject Else BuildExecutable;
 outName:=cmdOutName;
 If outName='' Then outName:=outNameDir;
 If outName='' Then Begin
  If opt.l Then outName:=StripExt(srcName)+'.o'
   Else If orgMode Then outName:=StripExt(srcName)+'.bin'
   Else outName:=StripExt(srcName);
 End;
 Assign(f,outName);
 Rewrite(f,1);
 If IOResult<>0 Then Begin
  WriteLn(Tr('Impossible de creer le fichier : ',
    'Cannot create file: ')+outName);
  Halt(20);
 End;
 If outLen>0 Then BlockWrite(f,outBuf^,outLen);
 Close(f);
 If cmdQuiet Then Exit;
 total:=0;
 For i:=0 to nsec-1 do Begin
  Case sec[i].kind of
   ST_CODE:kindName:='CODE';
   ST_DATA:kindName:='DATA';
   Else kindName:='BSS ';
  End;
  If sec[i].mem=MEM_CHIP Then kindName:=kindName+'_C' Else
  If sec[i].mem=MEM_FAST Then kindName:=kindName+'_F';
  Write('  ',Tr('Hunk ','Hunk '),i,' : ',Fmt(kindName,7),
    RFmt(IntStr(sec[i].size),8),Tr(' octets','  bytes'));
  If sec[i].name<>'' Then Write('  "',sec[i].name,'"');
  WriteLn;
  Inc(total,sec[i].size);
 End;
 If orgMode Then WriteLn(Tr('  Origine : $','  Origin: $'),HexStr(orgAddr,8));
 WriteLn(Tr('Fichier genere : ','Output written: '),outName,' (',outLen,
   Tr(' octets)',' bytes)'));
End;

Procedure OpenListing;
Begin
 listOpen:=False;
 If Not cmdList Then Exit;
 If cmdListName='' Then Assign(listFile,'') Else Assign(listFile,cmdListName);
 Rewrite(listFile);
 If IOResult<>0 Then Begin
  WriteLn(Tr('Impossible de creer le listing : ',
    'Cannot create listing: ')+cmdListName);
  Halt(20);
 End;
 listOpen:=True;
 listPage:=0;
 listLineNo:=0;
 listPLen:=60;
End;

Procedure InitGlobals;
Var
 s:String;
Begin
 Language:=0;
 s:=GetEnv('LANGUAGE');
 If(s<>'')and(s[1]='"')Then s:=Copy(s,2,255);
 If UpStr(Copy(s,1,2))='EN' Then Language:=1;
 FillChar(optDef,SizeOf(optDef),0);
 optDef.c:=True;
 optDef.w:=True;
 cpuDef:=CPU_68000;
 cmdOutName:='';
 cmdListName:='';
 srcName:='';
 cmdList:=False;
 cmdQuiet:=False;
 nCmdInc:=0;
 nIncPath:=0;
 nCmdDef:=0;
 FillChar(hashTab,SizeOf(hashTab),$FF);
 keyedC:=True;
 keyedCn:=0;
 caseInsSeen:=False;
 nsym:=0;
 nmacro:=0;
 nsec:=0;
 nFileNames:=0;
 pass:=0;
 sites:=Nil;
 siteCap:=0;
 outBuf:=Nil;
 outCap:=0;
 outLen:=0;
 unitName:='';
 outNameDir:='';
 listOpen:=False;
 srcTop:=-1;
End;

Var
 stable:Boolean;
 relSrc:String;

BEGIN
 InitGlobals;
 ParseCmdLine;
 If srcName='' Then Begin
  ShowHelp;
  Halt(1);
 End;
 relSrc:=LocateSource(srcName);
 If relSrc='' Then Begin
  WriteLn(Tr('Fichier source introuvable : ',
    'Source file not found: ')+srcName);
  Halt(20);
 End;
 srcName:=relSrc;
 If Not cmdQuiet Then Begin
  WriteLn('GenAm ',GENAM_VERSION,' - ',
    Tr('clone de Devpac GenAm pour Amiga (DEV-COOLS)',
    'Devpac GenAm clone for the Amiga (DEV-COOLS)'));
  WriteLn(Tr('Assemblage de ','Assembling '),srcName);
 End;
 stable:=False;
 While Not stable do Begin
  RunPass(False);
  If(pass>=2)and Not symChanged and Not siteChanged Then stable:=True
  Else If pass>=MAX_PASS-1 Then Begin
   WriteLn(Tr('Avertissement : nombre maximal de passes atteint.',
              'Warning: maximum number of passes reached.'));
   stable:=True;
  End;
 End;
 OpenListing;
 RunPass(True);
 If opt.s Then PrintSymbolTable;
 If listOpen Then Close(listFile);
 totalErrCount:=errors;
 If totalErrCount=0 Then Begin
  WriteOutput;
 End;
 If Not cmdQuiet Then Begin
  If totalErrCount=0 Then WriteLn(Tr('Aucune erreur','No errors'))
   Else WriteLn(totalErrCount,Tr(' erreur(s)',' error(s)'));
  If warnings>0 Then WriteLn(warnings,Tr(' avertissement(s)',' warning(s)'));
  WriteLn(pass,Tr(' passe(s)',' pass(es)'));
 End;
 If totalErrCount<>0 Then Halt(10);
END.
