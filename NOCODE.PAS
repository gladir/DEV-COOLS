{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Clone de Snowman (nocode) : desassembleur / decompilateur
                C/C++ pour executables x86 (ELF 32/64, PE32/PE32+, DOS MZ, COM)
  @license: MIT
}

Program NOCODE;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$A-}
{$I-}
{$R-}
{$Q-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
 NOCODE_VERSION = '1.0';

 MAXSEG    = 128;       { sections / segments charges en memoire }
 MAXSYM    = 65536;     { symboles }
 MAXINS    = 600000;    { instructions decodees (cache global) }
 HASHSIZE  = 1048576;   { table de hachage adresse -> instruction }
 MAXROOT   = 32768;     { points d'entree de fonctions }
 MAXFNINS  = 100000;    { instructions par fonction }
 MAXBLK    = 4096;      { blocs de base par fonction }
 MAXFILES  = 64;

 { Drapeaux de section }
 SF_EXEC  = 1;
 SF_WRITE = 2;
 SF_READ  = 4;
 SF_BSS   = 8;

 { Types de symbole }
 SK_NONE   = 0;
 SK_FUNC   = 1;
 SK_OBJECT = 2;
 SK_IMPORT = 3;
 SK_THUNK  = 4;
 SK_ENTRY  = 5;
 SK_EXPORT = 6;

 { Types d'operande }
 OK_NONE = 0;
 OK_REG  = 1;
 OK_IMM  = 2;
 OK_MEM  = 3;
 OK_REL  = 4;   { cible de branchement directe (adresse absolue dans Disp) }
 OK_FAR  = 5;   { pointeur lointain seg:off }

 { Classes de registre }
 RC_GPR = 0;
 RC_SEG = 1;
 RC_XMM = 2;
 RC_MMX = 3;
 RC_ST  = 4;
 RC_CR  = 5;
 RC_DR  = 6;

 { Types de flot de controle d'une instruction }
 FL_NORMAL = 0;
 FL_JMP    = 1;   { saut direct inconditionnel }
 FL_JCC    = 2;   { saut conditionnel }
 FL_CALL   = 3;   { appel direct }
 FL_RET    = 4;
 FL_IJMP   = 5;   { saut indirect }
 FL_ICALL  = 6;   { appel indirect }
 FL_HALT   = 7;   { hlt, ud2, int3 }

Type
 TByteArr = Array[0..$7FFFFFF0] of Byte;
 PByteArr = ^TByteArr;

 TSeg = Record
  Name:String[23];
  Addr:Int64;
  Size:LongInt;
  Flags:Byte;
  Data:PByteArr;
  Cov:PByteArr;
 End;

 TSym = Record
  Name:String[95];
  Addr:Int64;
  Size:LongInt;
  Kind:Byte;
 End;

 TOperand = Record
  Kind:Byte;
  Size:Byte;
  Cls:Byte;
  Reg:ShortInt;
  Hi:Boolean;
  Base:ShortInt;
  Index:ShortInt;
  Scale:Byte;
  Seg:ShortInt;
  ASize:Byte;
  Disp:Int64;
  Sel:Word;
 End;

 TInsn = Record
  Addr:Int64;
  Target:Int64;
  Len:Byte;
  Mn:String[11];
  N:Byte;
  Op:Array[0..3] of TOperand;
  Flow:Byte;
  CC:ShortInt;
  Rep:Byte;
  Lock:Boolean;
  OSize:Byte;
  Valid:Boolean;
 End;
 PInsn = ^TInsn;

 TInsArr = Array[0..0] of TInsn;
 PInsArr = ^TInsArr;

 TStr80 = String[80];

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
 { Options }
 OptHelp,OptVerbose:Boolean;
 OptSections,OptSymbols,OptInsns,OptCfg,OptIr,OptRegions,OptCxx:Boolean;
 FSections,FSymbols,FInsns,FCfg,FIr,FRegions,FCxx:String;
 OutOpened:Array[0..7] of Boolean;
 OptFrom,OptTo:Int64;
 HasFrom,HasTo:Boolean;
 Files:Array[0..MAXFILES-1] of String;
 NFiles:LongInt;

 { Fichier courant }
 FileBuf:PByteArr;
 FileLen:LongInt;
 CurFile:String;
 FmtName:String;
 CpuMode:Byte;           { 16, 32 ou 64 }
 EntryAddr:Int64;
 ImageBase:Int64;
 IsWin:Boolean;

 { Image memoire }
 NSeg:LongInt;
 Segs:Array[0..MAXSEG-1] of TSeg;
 LastSeg:LongInt;

 { Symboles }
 NSym:LongInt;
 Syms:Array[0..MAXSYM-1] of TSym;
 SymOrder:Array[0..MAXSYM-1] of LongInt;
 SymSorted:Boolean;

 OutF:Text;

{ ============================================================
  UTILITAIRES
  ============================================================ }
Function HexStr(V:Int64;Digits:Integer):String;
Const HexDigits:String[16]='0123456789abcdef';
Var I:Integer;S:String;N:Integer;
Begin
 S:='';
 For I:=15 downto 0 do Begin
  N:=Integer((V shr (I*4)) and $F);
  If(I<Digits)or(S<>'')or(N<>0)Then S:=S+HexDigits[N+1];
 End;
 If S=''Then S:='0';
 HexStr:=S;
End;

Function Hex0x(V:Int64):String;
Begin
 Hex0x:='0x'+HexStr(V,1);
End;

Function HexW(V:Int64):String;
Begin
 If CpuMode=64 Then HexW:=HexStr(V,8)
               Else If CpuMode=32 Then HexW:=HexStr(V,8)
                                  Else HexW:=HexStr(V,4);
End;

Function LStr(V:Int64):String;
Var S:String;
Begin
 Str(V,S);
 LStr:=S;
End;

Function UpStr(S:String):String;
Var I:Integer;
Begin
 For I:=1 to Length(S)do S[I]:=UpCase(S[I]);
 UpStr:=S;
End;

Function PadR(S:String;N:Integer):String;
Begin
 While Length(S)<N do S:=S+' ';
 PadR:=S;
End;

Function PadL(S:String;N:Integer):String;
Begin
 While Length(S)<N do S:=' '+S;
 PadL:=S;
End;

{ Convertit une chaine hexadecimale (0x..., $..., ...h, ou chiffres) }
Function ParseHex(S:String;Var V:Int64):Boolean;
Var I:Integer;D:Integer;C:Char;
Begin
 ParseHex:=False;V:=0;
 If S=''Then Exit;
 If(Length(S)>1)and(S[1]='0')and(UpCase(S[2])='X')Then Delete(S,1,2)
  Else If S[1]='$'Then Delete(S,1,1)
  Else If UpCase(S[Length(S)])='H'Then Delete(S,Length(S),1);
 If S=''Then Exit;
 For I:=1 to Length(S)do Begin
  C:=UpCase(S[I]);
  If(C>='0')and(C<='9')Then D:=Ord(C)-48
   Else If(C>='A')and(C<='F')Then D:=Ord(C)-55
   Else Exit;
  V:=(V shl 4)or D;
 End;
 ParseHex:=True;
End;

Function CName(S:String):String;
Var I:Integer;R:String;C:Char;
Begin
 R:='';
 For I:=1 to Length(S)do Begin
  C:=S[I];
  If((C>='A')and(C<='Z'))or((C>='a')and(C<='z'))or((C>='0')and(C<='9'))or(C='_')Then R:=R+C
   Else R:=R+'_';
 End;
 If R=''Then R:='_';
 If(R[1]>='0')and(R[1]<='9')Then R:='_'+R;
 CName:=R;
End;

Procedure Verbose(S:String);
Begin
 If OptVerbose Then WriteLn(StdErr,S);
End;

Procedure Warn(S:String);
Begin
 WriteLn(StdErr,'nocode: ',S);
End;

{ ============================================================
  LECTURE DU FICHIER
  ============================================================ }
Function FB(Ofs:Int64):Byte;
Begin
 If(Ofs<0)or(Ofs>=FileLen)Then FB:=0 Else FB:=FileBuf^[Ofs];
End;

Function FW(Ofs:Int64):LongInt;
Begin
 FW:=FB(Ofs)or(LongInt(FB(Ofs+1))shl 8);
End;

Function FD(Ofs:Int64):Int64;
Begin
 FD:=Int64(FB(Ofs))or(Int64(FB(Ofs+1))shl 8)or(Int64(FB(Ofs+2))shl 16)or(Int64(FB(Ofs+3))shl 24);
End;

Function FQ(Ofs:Int64):Int64;
Begin
 FQ:=FD(Ofs)or(FD(Ofs+4)shl 32);
End;

Function FStr(Ofs:Int64):String;
Var S:String;C:Byte;
Begin
 S:='';
 While(Length(S)<95)and(Ofs>=0)and(Ofs<FileLen)do Begin
  C:=FileBuf^[Ofs];
  If C=0 Then Break;
  S:=S+Chr(C);
  Inc(Ofs);
 End;
 FStr:=S;
End;

Function LoadFile(Const Name:String):Boolean;
Var F:File;Sz:LongInt;Got:LongInt;
Begin
 LoadFile:=False;
 FileBuf:=Nil;FileLen:=0;
 Assign(F,Name);Reset(F,1);
 If IOResult<>0 Then Begin
  Warn('impossible d''ouvrir '''+Name+'''');
  Exit;
 End;
 Sz:=FileSize(F);
 If Sz<=0 Then Begin
  Close(F);
  Warn('fichier vide : '+Name);
  Exit;
 End;
 GetMem(FileBuf,Sz+16);
 FillChar(FileBuf^,Sz+16,0);
 BlockRead(F,FileBuf^,Sz,Got);
 Close(F);
 FileLen:=Got;
 LoadFile:=True;
End;

Procedure FreeFile;
Begin
 If FileBuf<>Nil Then FreeMem(FileBuf,FileLen+16);
 FileBuf:=Nil;FileLen:=0;
End;

{ ============================================================
  IMAGE MEMOIRE
  ============================================================ }
Var
 SegBudget:Int64;

Function AddSeg(Const Name:String;Addr:Int64;Size:LongInt;Flags:Byte):LongInt;
Begin
 AddSeg:=-1;
 If NSeg>=MAXSEG Then Exit;
 If Size<0 Then Size:=0;
 If Size>$4000000 Then Size:=$4000000;
 If SegBudget+Size>$20000000 Then Begin
  Warn('image trop grande, section ignoree : '+Name);
  Exit;
 End;
 SegBudget:=SegBudget+Size;
 Segs[NSeg].Name:=Name;
 Segs[NSeg].Addr:=Addr;
 Segs[NSeg].Size:=Size;
 Segs[NSeg].Flags:=Flags;
 Segs[NSeg].Data:=Nil;
 Segs[NSeg].Cov:=Nil;
 If Size>0 Then Begin
  GetMem(Segs[NSeg].Data,Size+16);
  FillChar(Segs[NSeg].Data^,Size+16,0);
 End;
 AddSeg:=NSeg;
 Inc(NSeg);
End;

Procedure FreeImage;
Var I:LongInt;
Begin
 For I:=0 to NSeg-1 do
  Begin
  If Segs[I].Data<>Nil Then FreeMem(Segs[I].Data,Segs[I].Size+16);
  If Segs[I].Cov<>Nil Then FreeMem(Segs[I].Cov,Segs[I].Size+1);
  End;
 NSeg:=0;LastSeg:=0;SegBudget:=0;
End;

Function FindSeg(Addr:Int64):LongInt;
Var I:LongInt;
Begin
 If(LastSeg<NSeg)and(Addr>=Segs[LastSeg].Addr)and(Addr<Segs[LastSeg].Addr+Segs[LastSeg].Size)Then Begin
  FindSeg:=LastSeg;Exit;
 End;
 For I:=0 to NSeg-1 do
  If(Addr>=Segs[I].Addr)and(Addr<Segs[I].Addr+Segs[I].Size)Then Begin
   LastSeg:=I;FindSeg:=I;Exit;
  End;
 FindSeg:=-1;
End;

Function ReadB(Addr:Int64;Var B:Byte):Boolean;
Var S:LongInt;
Begin
 S:=FindSeg(Addr);
 If(S<0)or(Segs[S].Data=Nil)Then Begin B:=0;ReadB:=False;Exit;End;
 B:=Segs[S].Data^[Addr-Segs[S].Addr];
 ReadB:=True;
End;

Function IsExecAddr(Addr:Int64):Boolean;
Var S:LongInt;
Begin
 S:=FindSeg(Addr);
 IsExecAddr:=(S>=0)and((Segs[S].Flags and SF_EXEC)<>0);
End;

Function IsMapped(Addr:Int64):Boolean;
Begin
 IsMapped:=FindSeg(Addr)>=0;
End;

Function RdByte(Addr:Int64):Int64;
Var B:Byte;
Begin
 ReadB(Addr,B);RdByte:=B;
End;

Function RdWord(Addr:Int64):Int64;
Begin
 RdWord:=RdByte(Addr)or(RdByte(Addr+1)shl 8);
End;

Function RdDWord(Addr:Int64):Int64;
Begin
 RdDWord:=RdWord(Addr)or(RdWord(Addr+2)shl 16);
End;

Function RdQWord(Addr:Int64):Int64;
Begin
 RdQWord:=RdDWord(Addr)or(RdDWord(Addr+4)shl 32);
End;

Function RdPtr(Addr:Int64):Int64;
Begin
 If CpuMode=64 Then RdPtr:=RdQWord(Addr) Else RdPtr:=RdDWord(Addr);
End;

Function RdCStr(Addr:Int64):String;
Var S:String;B:Byte;
Begin
 S:='';
 While(Length(S)<95)and ReadB(Addr,B)do Begin
  If B=0 Then Break;
  S:=S+Chr(B);
  Inc(Addr);
 End;
 RdCStr:=S;
End;

Procedure PutSegBytes(S:LongInt;SegOfs:Int64;FileOfs:Int64;Count:Int64);
Var I:Int64;
Begin
 If S<0 Then Exit;
 For I:=0 to Count-1 do Begin
  If(SegOfs+I<0)or(SegOfs+I>=Segs[S].Size)Then Break;
  If(FileOfs+I<0)or(FileOfs+I>=FileLen)Then Break;
  Segs[S].Data^[SegOfs+I]:=FileBuf^[FileOfs+I];
 End;
End;

{ ============================================================
  TABLE DES SYMBOLES
  ============================================================ }
Procedure AddSym(Const Name:String;Addr:Int64;Size:LongInt;Kind:Byte);
Var I:LongInt;
Begin
 If Name=''Then Exit;
 If NSym>=MAXSYM Then Exit;
 { evite les doublons exacts }
 For I:=NSym-1 downto 0 do Begin
  If I<NSym-64 Then Break;
  If(Syms[I].Addr=Addr)and(Syms[I].Name=Name)Then Exit;
 End;
 Syms[NSym].Name:=Name;
 Syms[NSym].Addr:=Addr;
 Syms[NSym].Size:=Size;
 Syms[NSym].Kind:=Kind;
 Inc(NSym);
 SymSorted:=False;
End;

Procedure SortSyms(L,R:LongInt);
Var I,J,P,T:LongInt;
Begin
 While L<R do Begin
  I:=L;J:=R;P:=SymOrder[(L+R)div 2];
  Repeat
   While(Syms[SymOrder[I]].Addr<Syms[P].Addr)or
        ((Syms[SymOrder[I]].Addr=Syms[P].Addr)and(SymOrder[I]<P))do Inc(I);
   While(Syms[SymOrder[J]].Addr>Syms[P].Addr)or
        ((Syms[SymOrder[J]].Addr=Syms[P].Addr)and(SymOrder[J]>P))do Dec(J);
   If I<=J Then Begin
    T:=SymOrder[I];SymOrder[I]:=SymOrder[J];SymOrder[J]:=T;
    Inc(I);Dec(J);
   End;
  Until I>J;
  If J-L<R-I Then Begin
   SortSyms(L,J);L:=I;
  End
  Else Begin
   SortSyms(I,R);R:=J;
  End;
 End;
End;

Procedure PrepSyms;
Var I:LongInt;
Begin
 If SymSorted Then Exit;
 For I:=0 to NSym-1 do SymOrder[I]:=I;
 If NSym>1 Then SortSyms(0,NSym-1);
 SymSorted:=True;
End;

{ Retourne l'indice du meilleur symbole commencant exactement a Addr (-1 sinon) }
Function SymAt(Addr:Int64):LongInt;
Var Lo,Hi,Mid,Best,I:LongInt;
Begin
 PrepSyms;
 SymAt:=-1;
 Lo:=0;Hi:=NSym-1;
 While Lo<=Hi do Begin
  Mid:=(Lo+Hi)div 2;
  If Syms[SymOrder[Mid]].Addr<Addr Then Lo:=Mid+1 Else Hi:=Mid-1;
 End;
 Best:=-1;
 I:=Lo;
 While(I<NSym)and(Syms[SymOrder[I]].Addr=Addr)do Begin
  { preference : fonction/import/export avant objet/aucun }
  If Best<0 Then Best:=SymOrder[I]
  Else If(Syms[SymOrder[I]].Kind in[SK_FUNC,SK_THUNK,SK_IMPORT,SK_EXPORT])and
          not(Syms[Best].Kind in[SK_FUNC,SK_THUNK,SK_IMPORT,SK_EXPORT])Then Best:=SymOrder[I];
  Inc(I);
 End;
 SymAt:=Best;
End;

Function SymName(Addr:Int64):String;
Var I:LongInt;
Begin
 I:=SymAt(Addr);
 If I<0 Then SymName:='' Else SymName:=Syms[I].Name;
End;

{ ============================================================
  CHARGEUR ELF
  ============================================================ }
Var
 ElfIs64:Boolean;
 ElfType:LongInt;
 ElfMachine:LongInt;
 PltGot:Int64;                       { adresse de .got.plt }

 { Table des emplacements GOT/IAT -> nom d'import }
 NImp:LongInt;
 ImpSlot:Array[0..8191] of Int64;
 ImpName:Array[0..8191] of String[63];

Procedure AddImport(Slot:Int64;Const Name:String);
Begin
 If NImp>=8192 Then Exit;
 ImpSlot[NImp]:=Slot;ImpName[NImp]:=Name;
 Inc(NImp);
End;

Function ImportAt(Slot:Int64):String;
Var I:LongInt;
Begin
 ImportAt:='';
 For I:=0 to NImp-1 do
  If ImpSlot[I]=Slot Then Begin ImportAt:=ImpName[I];Exit;End;
End;

Function ElfPtr(Ofs:Int64):Int64;
Begin
 If ElfIs64 Then ElfPtr:=FQ(Ofs) Else ElfPtr:=FD(Ofs);
End;

Function LoadELF:Boolean;
Var
 ShOff,ShEnt,ShNum,ShStr,PhOff,PhEnt,PhNum:Int64;
 I,J,K,S,Idx:LongInt;
 ShBase,StrBase:Int64;
 SName:String;
 SType,SFlags,SAddr,SOffs,SSize,SLink,SInfo,SEnt:Int64;
 Fl:Byte;
 NextAddr:Int64;
 SecBase:Array[0..255] of Int64;
 SecSeg:Array[0..255] of LongInt;
 SymTab,StrTab,Cnt,SymSz:Int64;
 NameOfs,Val,Sz,Info,Shndx:Int64;
 Nm:String;
 Kind:Byte;
 RelOfs,RelCnt,RelEnt,RInfo,ROff,RAdd,RSym,RType:Int64;
 DynSymSh,DynStrOfs:Int64;
 SecIdx:LongInt;
 PType,PFlags,PVaddr,POff,PFile,PMem:Int64;
Begin
 LoadELF:=False;
 ElfIs64:=FB(4)=2;
 If FB(5)<>1 Then Begin Warn('ELF gros-boutiste non supporte');Exit;End;
 ElfType:=FW(16);
 ElfMachine:=FW(18);
 Case ElfMachine of
  3:CpuMode:=32;
  62:CpuMode:=64;
  Else Begin
   Warn('architecture ELF non supportee (e_machine='+LStr(ElfMachine)+')');
   Exit;
  End;
 End;
 If ElfIs64 and(CpuMode<>64)Then CpuMode:=64;
 If ElfIs64 Then Begin
  EntryAddr:=FQ(24);PhOff:=FQ(32);ShOff:=FQ(40);
  PhEnt:=FW(54);PhNum:=FW(56);ShEnt:=FW(58);ShNum:=FW(60);ShStr:=FW(62);
 End
 Else Begin
  EntryAddr:=FD(24);PhOff:=FD(28);ShOff:=FD(32);
  PhEnt:=FW(42);PhNum:=FW(44);ShEnt:=FW(46);ShNum:=FW(48);ShStr:=FW(50);
 End;
 FmtName:='ELF'+LStr(32*(1+Ord(ElfIs64)))+' ('+LStr(CpuMode)+' bits)';
 If ShNum>255 Then ShNum:=255;
 FillChar(SecBase,SizeOf(SecBase),0);
 For I:=0 to 255 do SecSeg[I]:=-1;
 PltGot:=0;
 NextAddr:=$1000;

 If(ShOff>0)and(ShNum>0)Then Begin
  { section des chaines de noms }
  StrBase:=0;
  If ShStr<ShNum Then Begin
   ShBase:=ShOff+ShStr*ShEnt;
   If ElfIs64 Then StrBase:=FQ(ShBase+24) Else StrBase:=FD(ShBase+16);
  End;
  For I:=0 to ShNum-1 do Begin
   ShBase:=ShOff+I*ShEnt;
   NameOfs:=FD(ShBase);
   SType:=FD(ShBase+4);
   If ElfIs64 Then Begin
    SFlags:=FQ(ShBase+8);SAddr:=FQ(ShBase+16);SOffs:=FQ(ShBase+24);SSize:=FQ(ShBase+32);
   End
   Else Begin
    SFlags:=FD(ShBase+8);SAddr:=FD(ShBase+12);SOffs:=FD(ShBase+16);SSize:=FD(ShBase+20);
   End;
   SName:=FStr(StrBase+NameOfs);
   If(SFlags and 2)=0 Then Continue;     { SHF_ALLOC }
   If SSize<=0 Then Continue;
   If SSize>$10000000 Then Continue;
   If ElfType=1 Then Begin               { fichier objet : adresses synthetiques }
    NextAddr:=(NextAddr+$FFF)and not Int64($FFF);
    SAddr:=NextAddr;
    NextAddr:=NextAddr+SSize;
   End;
   Fl:=SF_READ;
   If(SFlags and 4)<>0 Then Fl:=Fl or SF_EXEC;
   If(SFlags and 1)<>0 Then Fl:=Fl or SF_WRITE;
   If SType=8 Then Fl:=Fl or SF_BSS;
   S:=AddSeg(SName,SAddr,SSize,Fl);
   If S>=0 Then Begin
    SecBase[I]:=SAddr;SecSeg[I]:=S;
    If SType<>8 Then PutSegBytes(S,0,SOffs,SSize);
   End;
   If SName='.got.plt' Then PltGot:=SAddr;
  End;
 End
 Else If PhNum>0 Then Begin
  For I:=0 to PhNum-1 do Begin
   ShBase:=PhOff+I*PhEnt;
   PType:=FD(ShBase);
   If PType<>1 Then Continue;
   If ElfIs64 Then Begin
    PFlags:=FD(ShBase+4);POff:=FQ(ShBase+8);PVaddr:=FQ(ShBase+16);PFile:=FQ(ShBase+32);PMem:=FQ(ShBase+40);
   End
   Else Begin
    POff:=FD(ShBase+4);PVaddr:=FD(ShBase+8);PFile:=FD(ShBase+16);PMem:=FD(ShBase+20);PFlags:=FD(ShBase+24);
   End;
   Fl:=SF_READ;
   If(PFlags and 1)<>0 Then Fl:=Fl or SF_EXEC;
   If(PFlags and 2)<>0 Then Fl:=Fl or SF_WRITE;
   S:=AddSeg('LOAD'+LStr(I),PVaddr,PMem,Fl);
   If S>=0 Then PutSegBytes(S,0,POff,PFile);
  End;
 End;

 { symboles et relocations }
 If(ShOff>0)and(ShNum>0)Then Begin
  For I:=0 to ShNum-1 do Begin
   ShBase:=ShOff+I*ShEnt;
   SType:=FD(ShBase+4);
   If ElfIs64 Then Begin
    SOffs:=FQ(ShBase+24);SSize:=FQ(ShBase+32);SLink:=FD(ShBase+40);SInfo:=FD(ShBase+44);SEnt:=FQ(ShBase+56);
   End
   Else Begin
    SOffs:=FD(ShBase+16);SSize:=FD(ShBase+20);SLink:=FD(ShBase+24);SInfo:=FD(ShBase+28);SEnt:=FD(ShBase+36);
   End;
   If(SType=2)or(SType=11)Then Begin     { SYMTAB / DYNSYM }
    If SLink>=ShNum Then Continue;
    ShBase:=ShOff+SLink*ShEnt;
    If ElfIs64 Then StrTab:=FQ(ShBase+24) Else StrTab:=FD(ShBase+16);
    If ElfIs64 Then SymSz:=24 Else SymSz:=16;
    If SEnt>0 Then SymSz:=SEnt;
    Cnt:=SSize div SymSz;
    For J:=1 to Cnt-1 do Begin
     K:=SOffs+J*SymSz;
     NameOfs:=FD(K);
     If ElfIs64 Then Begin
      Info:=FB(K+4);Shndx:=FW(K+6);Val:=FQ(K+8);Sz:=FQ(K+16);
     End
     Else Begin
      Val:=FD(K+4);Sz:=FD(K+8);Info:=FB(K+12);Shndx:=FW(K+14);
     End;
     Nm:=FStr(StrTab+NameOfs);
     If Nm=''Then Continue;
     If(Length(Nm)>2)and(Nm[1]='.')and(Nm[2]='L')Then Continue;
     Case Info and $F of
      2:Kind:=SK_FUNC;
      1:Kind:=SK_OBJECT;
      Else Kind:=SK_NONE;
     End;
     If Shndx=0 Then Continue;           { non defini }
     If(Info and $F)in[3,4]Then Continue;  { SECTION, FILE }
     If Shndx>=$FF00 Then Begin
      If Shndx<>$FFF1 Then Continue;     { SHN_ABS accepte }
     End
     Else If(ElfType=1)and(Shndx<256)Then Begin
      If SecSeg[Shndx]<0 Then Continue;
      Val:=Val+SecBase[Shndx];
     End;
     If(Kind=SK_NONE)and(Shndx<256)and(SecSeg[Shndx]>=0)and((Segs[SecSeg[Shndx]].Flags and SF_EXEC)<>0)Then
      Kind:=SK_FUNC;
     AddSym(Nm,Val,Sz,Kind);
    End;
   End;
  End;
  { relocations : emplacements GOT (imports) ou application pour les fichiers objet }
  NextAddr:=$F0000000;
  For I:=0 to ShNum-1 do Begin
   ShBase:=ShOff+I*ShEnt;
   SType:=FD(ShBase+4);
   If(SType<>4)and(SType<>9)Then Continue;
   If ElfIs64 Then Begin
    SOffs:=FQ(ShBase+24);SSize:=FQ(ShBase+32);SLink:=FD(ShBase+40);SInfo:=FD(ShBase+44);
   End
   Else Begin
    SOffs:=FD(ShBase+16);SSize:=FD(ShBase+20);SLink:=FD(ShBase+24);SInfo:=FD(ShBase+28);
   End;
   If SLink>=ShNum Then Continue;
   { table de symboles associee }
   ShBase:=ShOff+SLink*ShEnt;
   If ElfIs64 Then Begin
    SymTab:=FQ(ShBase+24);K:=FD(ShBase+40);
   End
   Else Begin
    SymTab:=FD(ShBase+16);K:=FD(ShBase+24);
   End;
   If K>=ShNum Then Continue;
   ShBase:=ShOff+K*ShEnt;
   If ElfIs64 Then StrTab:=FQ(ShBase+24) Else StrTab:=FD(ShBase+16);
   If ElfIs64 Then SymSz:=24 Else SymSz:=16;
   If ElfIs64 Then Begin
    If SType=4 Then RelEnt:=24 Else RelEnt:=16;
   End
   Else Begin
    If SType=4 Then RelEnt:=12 Else RelEnt:=8;
   End;
   RelCnt:=SSize div RelEnt;
   For J:=0 to RelCnt-1 do Begin
    K:=SOffs+J*RelEnt;
    If ElfIs64 Then Begin
     ROff:=FQ(K);RInfo:=FQ(K+8);RSym:=RInfo shr 32;RType:=RInfo and $FFFFFFFF;
     If SType=4 Then RAdd:=FQ(K+16) Else RAdd:=0;
    End
    Else Begin
     ROff:=FD(K);RInfo:=FD(K+4);RSym:=RInfo shr 8;RType:=RInfo and $FF;
     If SType=4 Then RAdd:=LongInt(FD(K+8)) Else RAdd:=0;
    End;
    If RSym=0 Then Continue;
    { nom du symbole }
    ShBase:=SymTab+RSym*SymSz;
    Nm:=FStr(StrTab+FD(ShBase));
    If Nm=''Then Continue;
    If ElfIs64 Then Begin
     Shndx:=FW(ShBase+6);Val:=FQ(ShBase+8);
    End
    Else Begin
     Shndx:=FW(ShBase+14);Val:=FD(ShBase+4);
    End;
    If ElfType<>1 Then Begin
     { executable / bibliotheque partagee : emplacement GOT }
     If(RType=6)or(RType=7)or(RType=1)Then AddImport(ROff,Nm);
     Continue;
    End;
    { fichier objet : applique la relocation dans la section cible }
    If(SInfo>=256)or(SecSeg[SInfo]<0)Then Continue;
    If Shndx=0 Then Begin
     { symbole externe : adresse synthetique unique }
     Idx:=-1;
     For K:=0 to NSym-1 do
      If(Syms[K].Name=Nm)and(Syms[K].Kind=SK_IMPORT)Then Begin Idx:=K;Break;End;
     If Idx<0 Then Begin
      AddSym(Nm,NextAddr,0,SK_IMPORT);
      Val:=NextAddr;
      NextAddr:=NextAddr+16;
     End
     Else Val:=Syms[Idx].Addr;
    End
    Else If Shndx<256 Then Begin
     If SecSeg[Shndx]<0 Then Continue;
     Val:=Val+SecBase[Shndx];
    End;
    S:=SecSeg[SInfo];
    SecIdx:=SInfo;
    If ElfIs64 Then Begin
     Case RType of
      2,4:Val:=Val+RAdd-(SecBase[SecIdx]+ROff);           { PC32, PLT32 }
      1:Val:=Val+RAdd;                                     { 64 }
      10,11:Val:=Val+RAdd;                                 { 32, 32S }
      Else Continue;
     End;
     If RType=1 Then
      For K:=0 to 7 do Begin
       If ROff+K<Segs[S].Size Then Segs[S].Data^[ROff+K]:=(Val shr(8*K))and $FF;
      End
     Else
      For K:=0 to 3 do Begin
       If ROff+K<Segs[S].Size Then Segs[S].Data^[ROff+K]:=(Val shr(8*K))and $FF;
      End;
    End
    Else Begin
     RAdd:=LongInt(RdDWord(SecBase[SecIdx]+ROff));
     Case RType of
      2,4:Val:=Val+RAdd-(SecBase[SecIdx]+ROff);            { PC32, PLT32 }
      1:Val:=Val+RAdd;                                     { 32 }
      Else Continue;
     End;
     For K:=0 to 3 do Begin
      If ROff+K<Segs[S].Size Then Segs[S].Data^[ROff+K]:=(Val shr(8*K))and $FF;
     End;
    End;
   End;
  End;
 End;
 If ElfType=1 Then EntryAddr:=0;
 LoadELF:=True;
End;

{ ============================================================
  CHARGEUR PE
  ============================================================ }
Function LoadPE(PeOfs:Int64):Boolean;
Var
 Machine,NSec,OptSize:LongInt;
 OptOfs,SecOfs:Int64;
 Magic:LongInt;
 Is64:Boolean;
 EntryRva:Int64;
 NDir:LongInt;
 DirRva,DirSize:Array[0..15] of Int64;
 I,J,S:LongInt;
 SName:String;
 VSize,VAddr,RSize,ROff,Chr_:Int64;
 Fl:Byte;
 ExpOfs,NumFn,NumNm,AddrFn,AddrNm,AddrOrd,Ord_,Rva:Int64;
 ImpOfs,Thunk,OThunk,Slot,DllName,TSz:Int64;
 Nm,Dll:String;
Begin
 LoadPE:=False;
 Machine:=FW(PeOfs+4);
 NSec:=FW(PeOfs+6);
 OptSize:=FW(PeOfs+20);
 OptOfs:=PeOfs+24;
 Magic:=FW(OptOfs);
 Is64:=Magic=$20B;
 Case Machine of
  $14C:CpuMode:=32;
  $8664:CpuMode:=64;
  Else Begin
   Warn('architecture PE non supportee (machine=0x'+HexStr(Machine,4)+')');
   Exit;
  End;
 End;
 If(Magic<>$10B)and(Magic<>$20B)Then Begin Warn('en-tete optionnel PE invalide');Exit;End;
 EntryRva:=FD(OptOfs+16);
 If Is64 Then Begin
  ImageBase:=FQ(OptOfs+24);NDir:=FD(OptOfs+108);SecOfs:=OptOfs+112;
 End
 Else Begin
  ImageBase:=FD(OptOfs+28);NDir:=FD(OptOfs+92);SecOfs:=OptOfs+96;
 End;
 If NDir>16 Then NDir:=16;
 FillChar(DirRva,SizeOf(DirRva),0);FillChar(DirSize,SizeOf(DirSize),0);
 For I:=0 to NDir-1 do Begin
  DirRva[I]:=FD(SecOfs+I*8);DirSize[I]:=FD(SecOfs+I*8+4);
 End;
 FmtName:='PE'+LStr(32*(1+Ord(Is64)))+' ('+LStr(CpuMode)+' bits)';
 IsWin:=True;
 EntryAddr:=ImageBase+EntryRva;
 SecOfs:=OptOfs+OptSize;
 { en-tete comme premiere section en lecture seule }
 For I:=0 to NSec-1 do Begin
  J:=SecOfs+I*40;
  SName:='';
  For S:=0 to 7 do
   If FB(J+S)<>0 Then SName:=SName+Chr(FB(J+S));
  VSize:=FD(J+8);VAddr:=FD(J+12);RSize:=FD(J+16);ROff:=FD(J+20);Chr_:=FD(J+36);
  If VSize<RSize Then VSize:=RSize;
  If VSize<=0 Then Continue;
  Fl:=0;
  If(Chr_ and $20000000)<>0 Then Fl:=Fl or SF_EXEC;
  If(Chr_ and $40000000)<>0 Then Fl:=Fl or SF_READ;
  If(Chr_ and $80000000)<>0 Then Fl:=Fl or SF_WRITE;
  If(Chr_ and $80)<>0 Then Fl:=Fl or SF_BSS;
  If(Chr_ and $20)<>0 Then Fl:=Fl or SF_EXEC;
  S:=AddSeg(SName,ImageBase+VAddr,VSize,Fl);
  If S>=0 Then PutSegBytes(S,0,ROff,RSize);
 End;
 AddSym('entry',EntryAddr,0,SK_ENTRY);
 { exportations }
 If(NDir>0)and(DirRva[0]<>0)Then Begin
  ExpOfs:=ImageBase+DirRva[0];
  NumFn:=RdDWord(ExpOfs+20);NumNm:=RdDWord(ExpOfs+24);
  AddrFn:=ImageBase+RdDWord(ExpOfs+28);
  AddrNm:=ImageBase+RdDWord(ExpOfs+32);
  AddrOrd:=ImageBase+RdDWord(ExpOfs+36);
  If NumNm>8192 Then NumNm:=8192;
  For I:=0 to NumNm-1 do Begin
   Nm:=RdCStr(ImageBase+RdDWord(AddrNm+I*4));
   Ord_:=RdWord(AddrOrd+I*2);
   If Ord_<NumFn Then Begin
    Rva:=RdDWord(AddrFn+Ord_*4);
    If(Rva<>0)and((Rva<DirRva[0])or(Rva>=DirRva[0]+DirSize[0]))Then
     AddSym(Nm,ImageBase+Rva,0,SK_EXPORT);
   End;
  End;
 End;
 { importations }
 If(NDir>1)and(DirRva[1]<>0)Then Begin
  If Is64 Then TSz:=8 Else TSz:=4;
  ImpOfs:=ImageBase+DirRva[1];
  For I:=0 to 511 do Begin
   OThunk:=RdDWord(ImpOfs+I*20);
   DllName:=RdDWord(ImpOfs+I*20+12);
   Thunk:=RdDWord(ImpOfs+I*20+16);
   If(DllName=0)or(Thunk=0)Then Break;
   Dll:=RdCStr(ImageBase+DllName);
   If OThunk=0 Then OThunk:=Thunk;
   For J:=0 to 4095 do Begin
    If Is64 Then Rva:=RdQWord(ImageBase+OThunk+J*TSz) Else Rva:=RdDWord(ImageBase+OThunk+J*TSz);
    If Rva=0 Then Break;
    Slot:=ImageBase+Thunk+J*TSz;
    If Is64 Then Begin
     If(Rva shr 63)<>0 Then Nm:='ordinal_'+LStr(Rva and $FFFF)
      Else Nm:=RdCStr(ImageBase+(Rva and $7FFFFFFF)+2);
    End
    Else Begin
     If(Rva and $80000000)<>0 Then Nm:='ordinal_'+LStr(Rva and $FFFF)
      Else Nm:=RdCStr(ImageBase+Rva+2);
    End;
    AddImport(Slot,Nm);
    AddSym(Nm,Slot,TSz,SK_IMPORT);
   End;
  End;
 End;
 LoadPE:=True;
End;

{ ============================================================
  CHARGEUR DOS (MZ / COM)
  ============================================================ }
Function LoadMZ:Boolean;
Var
 CBlp,CP,Hdr,Total,CodeLen:Int64;
 S:LongInt;
 Cs,Ip:Int64;
Begin
 LoadMZ:=False;
 CBlp:=FW(2);CP:=FW(4);Hdr:=FW(8)*16;
 Total:=CP*512;
 If CBlp<>0 Then Total:=Total-512+CBlp;
 If(Total<=0)or(Total>FileLen)Then Total:=FileLen;
 CodeLen:=Total-Hdr;
 If CodeLen<=0 Then Begin Warn('executable MZ vide');Exit;End;
 CpuMode:=16;
 FmtName:='DOS MZ (16 bits)';
 ImageBase:=0;
 S:=AddSeg('.image',0,CodeLen+$100,SF_EXEC or SF_WRITE or SF_READ);
 If S<0 Then Exit;
 PutSegBytes(S,0,Hdr,CodeLen);
 Cs:=FW(22);Ip:=FW(20);
 EntryAddr:=Cs*16+Ip;
 AddSym('start',EntryAddr,0,SK_ENTRY);
 LoadMZ:=True;
End;

Function LoadCOM:Boolean;
Var S:LongInt;
Begin
 CpuMode:=16;
 FmtName:='DOS COM (16 bits)';
 ImageBase:=$100;
 S:=AddSeg('.image',$100,FileLen,SF_EXEC or SF_WRITE or SF_READ);
 If S<0 Then Begin LoadCOM:=False;Exit;End;
 PutSegBytes(S,0,0,FileLen);
 EntryAddr:=$100;
 AddSym('start',$100,0,SK_ENTRY);
 LoadCOM:=True;
End;

{ Detecte le format et charge l'image }
Function LoadImage:Boolean;
Var Lfa:Int64;Ext:String;
Begin
 LoadImage:=False;
 NSeg:=0;NSym:=0;NImp:=0;SymSorted:=False;LastSeg:=0;SegBudget:=0;
 ImageBase:=0;EntryAddr:=0;IsWin:=False;CpuMode:=32;
 If(FB(0)=$7F)and(FB(1)=Ord('E'))and(FB(2)=Ord('L'))and(FB(3)=Ord('F'))Then Begin
  LoadImage:=LoadELF;Exit;
 End;
 If(FB(0)=Ord('M'))and(FB(1)=Ord('Z'))Then Begin
  Lfa:=FD($3C);
  If(Lfa>0)and(Lfa+24<FileLen)and(FB(Lfa)=Ord('P'))and(FB(Lfa+1)=Ord('E'))Then Begin
   LoadImage:=LoadPE(Lfa);Exit;
  End;
  If(Lfa>0)and(Lfa+2<FileLen)and(FB(Lfa)=Ord('N'))and(FB(Lfa+1)=Ord('E'))Then Begin
   Warn('format NE (Windows 16 bits) non supporte');Exit;
  End;
  If(Lfa>0)and(Lfa+2<FileLen)and(FB(Lfa)=Ord('L'))and((FB(Lfa+1)=Ord('E'))or(FB(Lfa+1)=Ord('X')))Then Begin
   Warn('format LE/LX non supporte');Exit;
  End;
  LoadImage:=LoadMZ;Exit;
 End;
 Ext:=UpStr(CurFile);
 If(Length(Ext)>4)and(Copy(Ext,Length(Ext)-3,4)='.COM')Then Begin
  LoadImage:=LoadCOM;Exit;
 End;
 If(FB(0)=$CF)and(FB(1)=$FA)and(FB(2)=$ED)and(FB(3)=$FE)Then Warn('format Mach-O non supporte')
  Else If(FB(0)=$CE)and(FB(1)=$FA)and(FB(2)=$ED)and(FB(3)=$FE)Then Warn('format Mach-O non supporte')
  Else Warn('format de fichier non reconnu : '+CurFile);
End;

{ ============================================================
  DECODEUR x86 (16 / 32 / 64 bits)
  ============================================================ }
Const
 R64:Array[0..15] of String[4]=('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi',
                                'r8','r9','r10','r11','r12','r13','r14','r15');
 R32:Array[0..15] of String[5]=('eax','ecx','edx','ebx','esp','ebp','esi','edi',
                                'r8d','r9d','r10d','r11d','r12d','r13d','r14d','r15d');
 R16:Array[0..15] of String[5]=('ax','cx','dx','bx','sp','bp','si','di',
                                'r8w','r9w','r10w','r11w','r12w','r13w','r14w','r15w');
 R8:Array[0..15] of String[5]=('al','cl','dl','bl','spl','bpl','sil','dil',
                               'r8b','r9b','r10b','r11b','r12b','r13b','r14b','r15b');
 R8H:Array[0..3] of String[3]=('ah','ch','dh','bh');
 RSEG:Array[0..5] of String[2]=('es','cs','ss','ds','fs','gs');
 CCN:Array[0..15] of String[3]=('o','no','b','ae','e','ne','be','a','s','ns','p','np','l','ge','le','g');
 ARITH:Array[0..7] of String[3]=('add','or','adc','sbb','and','sub','xor','cmp');
 SHIFTN:Array[0..7] of String[3]=('rol','ror','rcl','rcr','shl','shr','shl','sar');
 GRP3N:Array[0..7] of String[4]=('test','test','not','neg','mul','imul','div','idiv');

Var
 DBuf:Array[0..15] of Byte;
 DLen,DPos:Integer;
 DFail:Boolean;
 DRex:Byte;
 DHasRex:Boolean;
 D66,D67,DF2,DF3,DLk:Boolean;
 DSeg:ShortInt;
 DOSz,DASz:Integer;
 DI:TInsn;
 MMod,MReg,MRm:Integer;
 MemFixup:Integer;     { indice de l'operande a corriger pour rip-relatif, -1 sinon }
 OpcPfx:Byte;
 VexMap,VexL,VexV:Integer;

Function NextB:Byte;
Begin
 If DPos>=DLen Then Begin DFail:=True;NextB:=0;Exit;End;
 NextB:=DBuf[DPos];
 Inc(DPos);
End;

Function NextS(Sz:Integer):Int64;      { lecture signee }
Var I:Integer;V:Int64;
Begin
 V:=0;
 For I:=0 to Sz-1 do V:=V or(Int64(NextB)shl(8*I));
 Case Sz of
  1:If V>=$80 Then V:=V-$100;
  2:If V>=$8000 Then V:=V-$10000;
  4:If V>=$80000000 Then V:=V-Int64($100000000);
 End;
 NextS:=V;
End;

Function NextU(Sz:Integer):Int64;
Var I:Integer;V:Int64;
Begin
 V:=0;
 For I:=0 to Sz-1 do V:=V or(Int64(NextB)shl(8*I));
 NextU:=V;
End;

Function RegName(Cls:Byte;Reg:Integer;Size:Integer;Hi:Boolean):String;
Begin
 RegName:='?';
 Case Cls of
  RC_GPR:Case Size of
   8:RegName:=R64[Reg and 15];
   4:RegName:=R32[Reg and 15];
   2:RegName:=R16[Reg and 15];
   Else If Hi Then RegName:=R8H[Reg and 3] Else RegName:=R8[Reg and 15];
  End;
  RC_SEG:If Reg<6 Then RegName:=RSEG[Reg] Else RegName:='seg'+LStr(Reg);
  RC_XMM:If Size=32 Then RegName:='ymm'+LStr(Reg) Else If Size=64 Then RegName:='zmm'+LStr(Reg) Else RegName:='xmm'+LStr(Reg);
  RC_MMX:RegName:='mm'+LStr(Reg and 7);
  RC_ST:RegName:='st('+LStr(Reg and 7)+')';
  RC_CR:RegName:='cr'+LStr(Reg);
  RC_DR:RegName:='dr'+LStr(Reg);
 End;
End;

Procedure ClrOp(Var O:TOperand);
Begin
 FillChar(O,SizeOf(O),0);
 O.Base:=-1;O.Index:=-1;O.Seg:=-1;O.Reg:=-1;
End;

Procedure SetReg(K:Integer;Cls:Byte;Idx,Size:Integer);
Begin
 ClrOp(DI.Op[K]);
 DI.Op[K].Kind:=OK_REG;DI.Op[K].Cls:=Cls;DI.Op[K].Size:=Size;
 If(Cls=RC_GPR)and(Size=1)and not DHasRex and(Idx>=4)and(Idx<8)Then Begin
  DI.Op[K].Reg:=Idx-4;DI.Op[K].Hi:=True;
 End
 Else DI.Op[K].Reg:=Idx;
 If DI.N<=K Then DI.N:=K+1;
End;

Procedure SetImm(K:Integer;V:Int64;Size:Integer);
Begin
 ClrOp(DI.Op[K]);
 DI.Op[K].Kind:=OK_IMM;DI.Op[K].Disp:=V;DI.Op[K].Size:=Size;
 If DI.N<=K Then DI.N:=K+1;
End;

Procedure SetRel(K:Integer;V:Int64);
Begin
 ClrOp(DI.Op[K]);
 DI.Op[K].Kind:=OK_REL;DI.Op[K].Disp:=V;DI.Op[K].Size:=DOSz;
 If DI.N<=K Then DI.N:=K+1;
End;

Procedure SetMn(Const S:String);
Begin
 DI.Mn:=S;
End;

{ Lit l'octet ModRM }
Procedure ReadModRM;
Var B:Integer;
Begin
 B:=NextB;
 MMod:=B shr 6;
 MReg:=((B shr 3)and 7)or((DRex and 4)shl 1);
 MRm:=B and 7;
End;

{ Construit l'operande r/m (registre ou memoire) }
Procedure DecodeRM(K:Integer;Cls:Byte;Size:Integer);
Var Sib,Sc,Ix,Bs:Integer;Rm:Integer;O:^TOperand;
Begin
 If MMod=3 Then Begin
  Rm:=MRm or((DRex and 1)shl 3);
  SetReg(K,Cls,Rm,Size);
  Exit;
 End;
 ClrOp(DI.Op[K]);
 O:=@DI.Op[K];
 O^.Kind:=OK_MEM;O^.Size:=Size;O^.ASize:=DASz;O^.Seg:=DSeg;
 If DI.N<=K Then DI.N:=K+1;
 If DASz=2 Then Begin
  Case MRm of
   0:Begin O^.Base:=3;O^.Index:=6;End;
   1:Begin O^.Base:=3;O^.Index:=7;End;
   2:Begin O^.Base:=5;O^.Index:=6;End;
   3:Begin O^.Base:=5;O^.Index:=7;End;
   4:O^.Base:=6;
   5:O^.Base:=7;
   6:O^.Base:=5;
   7:O^.Base:=3;
  End;
  O^.Scale:=1;
  If(MMod=0)and(MRm=6)Then Begin
   O^.Base:=-1;O^.Disp:=NextU(2);
  End
  Else If MMod=1 Then O^.Disp:=NextS(1)
  Else If MMod=2 Then O^.Disp:=NextS(2);
  Exit;
 End;
 Rm:=MRm;
 O^.Scale:=1;
 If Rm=4 Then Begin
  Sib:=NextB;
  Sc:=Sib shr 6;
  Ix:=((Sib shr 3)and 7)or((DRex and 2)shl 2);
  Bs:=Sib and 7;
  O^.Scale:=1 shl Sc;
  If Ix<>4 Then O^.Index:=Ix;
  If(Bs=5)and(MMod=0)Then Begin
   O^.Base:=-1;O^.Disp:=NextS(4);
  End
  Else Begin
   O^.Base:=Bs or((DRex and 1)shl 3);
   If MMod=1 Then O^.Disp:=NextS(1)
   Else If MMod=2 Then O^.Disp:=NextS(4);
  End;
  If O^.Index<0 Then O^.Scale:=1;
  Exit;
 End;
 If(Rm=5)and(MMod=0)Then Begin
  O^.Disp:=NextS(4);
  If CpuMode=64 Then Begin
   O^.Base:=16;MemFixup:=K;
  End;
  Exit;
 End;
 O^.Base:=Rm or((DRex and 1)shl 3);
 If MMod=1 Then O^.Disp:=NextS(1)
 Else If MMod=2 Then O^.Disp:=NextS(4);
End;

Procedure OpRM_Reg(Sz:Integer);       { E,G }
Begin
 DecodeRM(0,RC_GPR,Sz);SetReg(1,RC_GPR,MReg,Sz);
End;

Procedure OpReg_RM(Sz:Integer);       { G,E }
Begin
 DecodeRM(1,RC_GPR,Sz);SetReg(0,RC_GPR,MReg,Sz);
End;

Function ImmZ:Int64;                  { immediat de taille operande (max 4 octets) }
Begin
 If DOSz=2 Then ImmZ:=NextS(2) Else ImmZ:=NextS(4);
End;

Function StackSz:Integer;             { taille d'empilement }
Begin
 If CpuMode=64 Then Begin
  If D66 Then StackSz:=2 Else StackSz:=8;
 End
 Else StackSz:=DOSz;
End;

Function SzSuffix:String;
Begin
 Case DOSz of
  2:SzSuffix:='w';
  8:SzSuffix:='q';
  Else SzSuffix:='d';
 End;
End;

Procedure DecodeFPU(Opc:Integer);
Const
 MemN:Array[0..7,0..7] of String[8]=(
  ('fadd','fmul','fcom','fcomp','fsub','fsubr','fdiv','fdivr'),
  ('fld','','fst','fstp','fldenv','fldcw','fnstenv','fnstcw'),
  ('fiadd','fimul','ficom','ficomp','fisub','fisubr','fidiv','fidivr'),
  ('fild','fisttp','fist','fistp','','fld','','fstp'),
  ('fadd','fmul','fcom','fcomp','fsub','fsubr','fdiv','fdivr'),
  ('fld','fisttp','fst','fstp','frstor','','fnsave','fnstsw'),
  ('fiadd','fimul','ficom','ficomp','fisub','fisubr','fidiv','fidivr'),
  ('fild','fisttp','fist','fistp','fbld','fild','fbstp','fistp'));
 MemSz:Array[0..7,0..7] of Byte=(
  (4,4,4,4,4,4,4,4),
  (4,0,4,4,0,2,0,2),
  (4,4,4,4,4,4,4,4),
  (4,4,4,4,0,10,0,10),
  (8,8,8,8,8,8,8,8),
  (8,8,8,8,0,0,0,2),
  (2,2,2,2,2,2,2,2),
  (2,2,2,2,10,8,10,8));
Var Row,R,Sz:Integer;N:String[8];St:Integer;
Begin
 Row:=Opc-$D8;
 ReadModRM;
 R:=MReg and 7;
 If MMod<>3 Then Begin
  N:=MemN[Row,R];
  Sz:=MemSz[Row,R];
  If(N='')Then Begin DFail:=True;Exit;End;
  { instructions d'environnement : operande sans taille }
  SetMn(N);
  DecodeRM(0,RC_GPR,Sz);
  DI.N:=1;
  Exit;
 End;
 St:=MRm;
 DI.N:=0;
 Case Row of
  0:Begin
   Case R of
    0:SetMn('fadd');1:SetMn('fmul');2:SetMn('fcom');3:SetMn('fcomp');
    4:SetMn('fsub');5:SetMn('fsubr');6:SetMn('fdiv');7:SetMn('fdivr');
   End;
   If R in[2,3]Then SetReg(0,RC_ST,St,10)
   Else Begin SetReg(0,RC_ST,0,10);SetReg(1,RC_ST,St,10);End;
  End;
  1:Begin
   Case R of
    0:Begin SetMn('fld');SetReg(0,RC_ST,St,10);End;
    1:Begin SetMn('fxch');SetReg(0,RC_ST,St,10);End;
    2:Begin If St=0 Then SetMn('fnop') Else DFail:=True;End;
    4:Case St of
       0:SetMn('fchs');1:SetMn('fabs');4:SetMn('ftst');5:SetMn('fxam');
       Else DFail:=True;
      End;
    5:Case St of
       0:SetMn('fld1');1:SetMn('fldl2t');2:SetMn('fldl2e');3:SetMn('fldpi');
       4:SetMn('fldlg2');5:SetMn('fldln2');6:SetMn('fldz');
       Else DFail:=True;
      End;
    6:Case St of
       0:SetMn('f2xm1');1:SetMn('fyl2x');2:SetMn('fptan');3:SetMn('fpatan');
       4:SetMn('fxtract');5:SetMn('fprem1');6:SetMn('fdecstp');7:SetMn('fincstp');
      End;
    7:Case St of
       0:SetMn('fprem');1:SetMn('fyl2xp1');2:SetMn('fsqrt');3:SetMn('fsincos');
       4:SetMn('frndint');5:SetMn('fscale');6:SetMn('fsin');7:SetMn('fcos');
      End;
    Else DFail:=True;
   End;
  End;
  2:Begin
   Case R of
    0:SetMn('fcmovb');1:SetMn('fcmove');2:SetMn('fcmovbe');3:SetMn('fcmovu');
    5:Begin If St=1 Then SetMn('fucompp') Else DFail:=True;End;
    Else DFail:=True;
   End;
   If not DFail and(R<4)Then Begin SetReg(0,RC_ST,0,10);SetReg(1,RC_ST,St,10);End;
  End;
  3:Begin
   Case R of
    0:SetMn('fcmovnb');1:SetMn('fcmovne');2:SetMn('fcmovnbe');3:SetMn('fcmovnu');
    4:Case St of 2:SetMn('fnclex');3:SetMn('fninit');Else DFail:=True;End;
    5:SetMn('fucomi');6:SetMn('fcomi');
    Else DFail:=True;
   End;
   If not DFail and((R<4)or(R>=5))Then Begin SetReg(0,RC_ST,0,10);SetReg(1,RC_ST,St,10);End;
  End;
  4:Begin
   Case R of
    0:SetMn('fadd');1:SetMn('fmul');4:SetMn('fsubr');5:SetMn('fsub');6:SetMn('fdivr');7:SetMn('fdiv');
    Else DFail:=True;
   End;
   If not DFail Then Begin SetReg(0,RC_ST,St,10);SetReg(1,RC_ST,0,10);End;
  End;
  5:Begin
   Case R of
    0:SetMn('ffree');2:SetMn('fst');3:SetMn('fstp');4:SetMn('fucom');5:SetMn('fucomp');
    Else DFail:=True;
   End;
   If not DFail Then SetReg(0,RC_ST,St,10);
  End;
  6:Begin
   Case R of
    0:SetMn('faddp');1:SetMn('fmulp');4:SetMn('fsubrp');5:SetMn('fsubp');6:SetMn('fdivrp');7:SetMn('fdivp');
    3:Begin If St=1 Then SetMn('fcompp') Else DFail:=True;End;
    Else DFail:=True;
   End;
   If not DFail and(R<>3)Then Begin SetReg(0,RC_ST,St,10);SetReg(1,RC_ST,0,10);End;
  End;
  7:Begin
   Case R of
    4:Begin If St=0 Then Begin SetMn('fnstsw');SetReg(0,RC_GPR,0,2);End Else DFail:=True;End;
    5:Begin SetMn('fucomip');SetReg(0,RC_ST,0,10);SetReg(1,RC_ST,St,10);End;
    6:Begin SetMn('fcomip');SetReg(0,RC_ST,0,10);SetReg(1,RC_ST,St,10);End;
    Else DFail:=True;
   End;
  End;
 End;
End;

{ Registres SIMD : classe selon le prefixe 66 }
Function SimdCls:Byte;
Begin
 If D66 Then SimdCls:=RC_XMM Else SimdCls:=RC_MMX;
End;

Procedure SimdGE(Sz:Integer);          { G (simd), E (simd/mem) }
Var C:Byte;
Begin
 C:=SimdCls;
 DecodeRM(1,C,Sz);
 SetReg(0,C,MReg,Sz);
End;

Procedure XmmGE(Sz:Integer);
Begin
 DecodeRM(1,RC_XMM,Sz);
 SetReg(0,RC_XMM,MReg,Sz);
End;

Procedure XmmEG(Sz:Integer);
Begin
 DecodeRM(0,RC_XMM,Sz);
 SetReg(1,RC_XMM,MReg,Sz);
End;

Function PfxSuffix(Const A:Array of String):String;
Begin
 If DF3 Then PfxSuffix:=A[2]
 Else If DF2 Then PfxSuffix:=A[3]
 Else If D66 Then PfxSuffix:=A[1]
 Else PfxSuffix:=A[0];
End;

Procedure Decode0F;
Var Opc,Sz,K:Integer;B:Integer;S:String;C:Byte;Imm:Int64;
Begin
 If VexMap=2 Then Opc:=$38 Else If VexMap=3 Then Opc:=$3A Else Opc:=NextB;
 Case Opc of
  $00:Begin
   ReadModRM;
   Case MReg and 7 of
    0:SetMn('sldt');1:SetMn('str');2:SetMn('lldt');3:SetMn('ltr');4:SetMn('verr');5:SetMn('verw');
    Else DFail:=True;
   End;
   DecodeRM(0,RC_GPR,2);
  End;
  $01:Begin
   ReadModRM;
   If MMod=3 Then Begin
    B:=((MReg and 7)shl 3)or MRm;
    Case B of
     $01:SetMn('vmcall');
     $10:SetMn('xgetbv');
     $11:SetMn('xsetbv');
     $3F:SetMn('swapgs');
     $16:SetMn('xtest');
     $39:SetMn('rdtscp');
     $08:SetMn('monitor');
     $09:SetMn('mwait');
     Else DFail:=True;
    End;
   End
   Else Begin
    Case MReg and 7 of
     0:SetMn('sgdt');1:SetMn('sidt');2:SetMn('lgdt');3:SetMn('lidt');
     4:SetMn('smsw');6:SetMn('lmsw');7:SetMn('invlpg');
     Else DFail:=True;
    End;
    DecodeRM(0,RC_GPR,0);
   End;
  End;
  $02:Begin SetMn('lar');ReadModRM;OpReg_RM(DOSz);End;
  $03:Begin SetMn('lsl');ReadModRM;OpReg_RM(DOSz);End;
  $05:SetMn('syscall');
  $06:SetMn('clts');
  $07:SetMn('sysret');
  $08:SetMn('invd');
  $09:SetMn('wbinvd');
  $0B:Begin SetMn('ud2');DI.Flow:=FL_HALT;End;
  $0D:Begin SetMn('prefetchw');ReadModRM;DecodeRM(0,RC_GPR,1);End;
  $10,$11:Begin
   SetMn(PfxSuffix(['movups','movupd','movss','movsd']));
   ReadModRM;
   If DF3 Then Sz:=4 Else If DF2 Then Sz:=8 Else Sz:=16;
   If Opc=$10 Then XmmGE(Sz) Else XmmEG(Sz);
  End;
  $12,$13:Begin
   ReadModRM;
   If Opc=$12 Then Begin
    If DF2 Then SetMn('movddup')
    Else If DF3 Then SetMn('movsldup')
    Else If D66 Then SetMn('movlpd')
    Else If MMod=3 Then SetMn('movhlps') Else SetMn('movlps');
    XmmGE(8);
   End
   Else Begin
    If D66 Then SetMn('movlpd') Else SetMn('movlps');
    XmmEG(8);
   End;
  End;
  $14:Begin If D66 Then SetMn('unpcklpd') Else SetMn('unpcklps');ReadModRM;XmmGE(16);End;
  $15:Begin If D66 Then SetMn('unpckhpd') Else SetMn('unpckhps');ReadModRM;XmmGE(16);End;
  $16,$17:Begin
   ReadModRM;
   If Opc=$16 Then Begin
    If DF3 Then SetMn('movshdup')
    Else If D66 Then SetMn('movhpd')
    Else If MMod=3 Then SetMn('movlhps') Else SetMn('movhps');
    XmmGE(8);
   End
   Else Begin
    If D66 Then SetMn('movhpd') Else SetMn('movhps');
    XmmEG(8);
   End;
  End;
  $18:Begin
   ReadModRM;
   Case MReg and 7 of
    0:SetMn('prefetchnta');1:SetMn('prefetcht0');2:SetMn('prefetcht1');3:SetMn('prefetcht2');
    Else SetMn('nop');
   End;
   DecodeRM(0,RC_GPR,1);
  End;
  $19..$1D,$1F:Begin SetMn('nop');ReadModRM;DecodeRM(0,RC_GPR,DOSz);End;
  $1E:Begin
   ReadModRM;
   If DF3 and(MMod=3)and((MReg and 7)=7)and((MRm=2)or(MRm=3))Then Begin
    If MRm=2 Then SetMn('endbr64') Else SetMn('endbr32');
    DF3:=False;
   End
   Else Begin SetMn('nop');DecodeRM(0,RC_GPR,DOSz);End;
  End;
  $20,$22:Begin
   ReadModRM;SetMn('mov');
   If CpuMode=64 Then K:=8 Else K:=4;
   If Opc=$20 Then Begin
    SetReg(0,RC_GPR,MRm or((DRex and 1)shl 3),K);SetReg(1,RC_CR,MReg,K);
   End
   Else Begin
    SetReg(0,RC_CR,MReg,K);SetReg(1,RC_GPR,MRm or((DRex and 1)shl 3),K);
   End;
  End;
  $21,$23:Begin
   ReadModRM;SetMn('mov');
   If CpuMode=64 Then K:=8 Else K:=4;
   If Opc=$21 Then Begin
    SetReg(0,RC_GPR,MRm or((DRex and 1)shl 3),K);SetReg(1,RC_DR,MReg,K);
   End
   Else Begin
    SetReg(0,RC_DR,MReg,K);SetReg(1,RC_GPR,MRm or((DRex and 1)shl 3),K);
   End;
  End;
  $28:Begin If D66 Then SetMn('movapd') Else SetMn('movaps');ReadModRM;XmmGE(16);End;
  $29:Begin If D66 Then SetMn('movapd') Else SetMn('movaps');ReadModRM;XmmEG(16);End;
  $2A:Begin
   ReadModRM;
   If DF3 or DF2 Then Begin
    If DF3 Then SetMn('cvtsi2ss') Else SetMn('cvtsi2sd');
    If DOSz=8 Then K:=8 Else K:=4;
    DecodeRM(1,RC_GPR,K);SetReg(0,RC_XMM,MReg,16);
   End
   Else Begin
    If D66 Then SetMn('cvtpi2pd') Else SetMn('cvtpi2ps');
    DecodeRM(1,RC_MMX,8);SetReg(0,RC_XMM,MReg,16);
   End;
  End;
  $2B:Begin If D66 Then SetMn('movntpd') Else SetMn('movntps');ReadModRM;XmmEG(16);End;
  $2C,$2D:Begin
   ReadModRM;
   If DF3 or DF2 Then Begin
    If Opc=$2C Then S:='cvtt' Else S:='cvt';
    If DF3 Then S:=S+'ss2si' Else S:=S+'sd2si';
    SetMn(S);
    If DOSz=8 Then K:=8 Else K:=4;
    If DF3 Then DecodeRM(1,RC_XMM,4) Else DecodeRM(1,RC_XMM,8);
    SetReg(0,RC_GPR,MReg,K);
   End
   Else Begin
    If Opc=$2C Then S:='cvtt' Else S:='cvt';
    If D66 Then S:=S+'pd2pi' Else S:=S+'ps2pi';
    SetMn(S);
    DecodeRM(1,RC_XMM,16);SetReg(0,RC_MMX,MReg,8);
   End;
  End;
  $2E,$2F:Begin
   If Opc=$2E Then S:='ucomis' Else S:='comis';
   If D66 Then Begin SetMn(S+'d');K:=8;End Else Begin SetMn(S+'s');K:=4;End;
   ReadModRM;XmmGE(K);
  End;
  $30:SetMn('wrmsr');
  $31:SetMn('rdtsc');
  $32:SetMn('rdmsr');
  $33:SetMn('rdpmc');
  $34:SetMn('sysenter');
  $35:SetMn('sysexit');
  $38:Begin
   B:=NextB;
   ReadModRM;
   Case B of
    $00:S:='pshufb';$01:S:='phaddw';$02:S:='phaddd';$03:S:='phaddsw';$04:S:='pmaddubsw';
    $05:S:='phsubw';$06:S:='phsubd';$07:S:='phsubsw';$08:S:='psignb';$09:S:='psignw';
    $0A:S:='psignd';$0B:S:='pmulhrsw';$10:S:='pblendvb';$14:S:='blendvps';$15:S:='blendvpd';
    $17:S:='ptest';$1C:S:='pabsb';$1D:S:='pabsw';$1E:S:='pabsd';
    $20:S:='pmovsxbw';$21:S:='pmovsxbd';$22:S:='pmovsxbq';$23:S:='pmovsxwd';$24:S:='pmovsxwq';
    $25:S:='pmovsxdq';$28:S:='pmuldq';$29:S:='pcmpeqq';$2A:S:='movntdqa';$2B:S:='packusdw';
    $30:S:='pmovzxbw';$31:S:='pmovzxbd';$32:S:='pmovzxbq';$33:S:='pmovzxwd';$34:S:='pmovzxwq';
    $35:S:='pmovzxdq';$37:S:='pcmpgtq';$38:S:='pminsb';$39:S:='pminsd';$3A:S:='pminuw';
    $3B:S:='pminud';$3C:S:='pmaxsb';$3D:S:='pmaxsd';$3E:S:='pmaxuw';$3F:S:='pmaxud';$40:S:='pmulld';
    $DB:S:='aesimc';$DC:S:='aesenc';$DD:S:='aesenclast';$DE:S:='aesdec';$DF:S:='aesdeclast';
    $F0,$F1:S:='';
    Else If VexMap<>0 Then S:='vop38_'+HexStr(B,2) Else Begin DFail:=True;Exit;End;
   End;
   If(B=$F0)or(B=$F1)Then Begin
    If DF2 Then Begin
     SetMn('crc32');
     If B=$F0 Then Sz:=1 Else Sz:=DOSz;
     DecodeRM(1,RC_GPR,Sz);
     If DOSz=8 Then SetReg(0,RC_GPR,MReg,8) Else SetReg(0,RC_GPR,MReg,4);
    End
    Else Begin
     SetMn('movbe');
     If B=$F0 Then OpReg_RM(DOSz) Else OpRM_Reg(DOSz);
    End;
   End
   Else Begin
    SetMn(S);SimdGE(16);
   End;
  End;
  $3A:Begin
   B:=NextB;
   ReadModRM;
   Case B of
    $08:S:='roundps';$09:S:='roundpd';$0A:S:='roundss';$0B:S:='roundsd';$0C:S:='blendps';
    $0D:S:='blendpd';$0E:S:='pblendw';$0F:S:='palignr';$14:S:='pextrb';$15:S:='pextrw';
    $16:S:='pextrd';$17:S:='extractps';$20:S:='pinsrb';$21:S:='insertps';$22:S:='pinsrd';
    $40:S:='dpps';$41:S:='dppd';$42:S:='mpsadbw';$44:S:='pclmulqdq';$60:S:='pcmpestrm';
    $61:S:='pcmpestri';$62:S:='pcmpistrm';$63:S:='pcmpistri';$DF:S:='aeskeygenassist';
    Else If VexMap<>0 Then S:='vop3a_'+HexStr(B,2) Else Begin DFail:=True;Exit;End;
   End;
   SetMn(S);
   If(B>=$14)and(B<=$17)Then Begin
    DecodeRM(0,RC_GPR,4);SetReg(1,RC_XMM,MReg,16);
   End
   Else If(B=$20)or(B=$22)Then Begin
    DecodeRM(1,RC_GPR,4);SetReg(0,RC_XMM,MReg,16);
   End
   Else SimdGE(16);
   SetImm(2,NextU(1),1);
  End;
  $40..$4F:Begin
   SetMn('cmov'+CCN[Opc and 15]);DI.CC:=Opc and 15;
   ReadModRM;OpReg_RM(DOSz);
  End;
  $50:Begin
   If D66 Then SetMn('movmskpd') Else SetMn('movmskps');
   ReadModRM;DecodeRM(1,RC_XMM,16);SetReg(0,RC_GPR,MReg,4);
  End;
  $51..$53,$58,$59,$5C..$5F:Begin
   Case Opc of
    $51:S:='sqrt';$52:S:='rsqrt';$53:S:='rcp';$58:S:='add';$59:S:='mul';
    $5C:S:='sub';$5D:S:='min';$5E:S:='div';$5F:S:='max';
   End;
   SetMn(S+PfxSuffix(['ps','pd','ss','sd']));
   ReadModRM;
   If DF3 Then Sz:=4 Else If DF2 Then Sz:=8 Else Sz:=16;
   XmmGE(Sz);
  End;
  $54..$57:Begin
   Case Opc of $54:S:='and';$55:S:='andn';$56:S:='or';$57:S:='xor';End;
   If D66 Then SetMn(S+'pd') Else SetMn(S+'ps');
   ReadModRM;XmmGE(16);
  End;
  $5A:Begin
   SetMn(PfxSuffix(['cvtps2pd','cvtpd2ps','cvtss2sd','cvtsd2ss']));
   ReadModRM;
   If DF3 Then Sz:=4 Else If DF2 Then Sz:=8 Else Sz:=16;
   XmmGE(Sz);
  End;
  $5B:Begin
   SetMn(PfxSuffix(['cvtdq2ps','cvtps2dq','cvttps2dq','cvtdq2ps']));
   ReadModRM;XmmGE(16);
  End;
  $60..$6D:Begin
   Case Opc of
    $60:S:='punpcklbw';$61:S:='punpcklwd';$62:S:='punpckldq';$63:S:='packsswb';
    $64:S:='pcmpgtb';$65:S:='pcmpgtw';$66:S:='pcmpgtd';$67:S:='packuswb';
    $68:S:='punpckhbw';$69:S:='punpckhwd';$6A:S:='punpckhdq';$6B:S:='packssdw';
    $6C:S:='punpcklqdq';$6D:S:='punpckhqdq';
   End;
   SetMn(S);ReadModRM;SimdGE(16);
  End;
  $6E:Begin
   ReadModRM;
   If DOSz=8 Then Begin SetMn('movq');K:=8;End Else Begin SetMn('movd');K:=4;End;
   C:=SimdCls;
   DecodeRM(1,RC_GPR,K);SetReg(0,C,MReg,16);
  End;
  $6F:Begin
   ReadModRM;
   If DF3 Then SetMn('movdqu') Else If D66 Then SetMn('movdqa') Else SetMn('movq');
   SimdGE(16);
  End;
  $70:Begin
   SetMn(PfxSuffix(['pshufw','pshufd','pshufhw','pshuflw']));
   ReadModRM;
   If DF3 or DF2 or D66 Then XmmGE(16) Else SimdGE(8);
   SetImm(2,NextU(1),1);
  End;
  $71,$72,$73:Begin
   ReadModRM;
   B:=MReg and 7;
   S:='';
   Case Opc of
    $71:Case B of 2:S:='psrlw';4:S:='psraw';6:S:='psllw';End;
    $72:Case B of 2:S:='psrld';4:S:='psrad';6:S:='pslld';End;
    $73:Case B of 2:S:='psrlq';3:S:='psrldq';6:S:='psllq';7:S:='pslldq';End;
   End;
   If S=''Then Begin DFail:=True;Exit;End;
   SetMn(S);
   If D66 Then SetReg(0,RC_XMM,MRm or((DRex and 1)shl 3),16) Else SetReg(0,RC_MMX,MRm,8);
   SetImm(1,NextU(1),1);
  End;
  $74..$76:Begin
   Case Opc of $74:S:='pcmpeqb';$75:S:='pcmpeqw';$76:S:='pcmpeqd';End;
   SetMn(S);ReadModRM;SimdGE(16);
  End;
  $77:Begin
   If VexMap<>0 Then Begin If VexL=0 Then SetMn('vzeroupper') Else SetMn('vzeroall');End
   Else SetMn('emms');
  End;
  $7C:Begin If DF2 Then SetMn('haddps') Else SetMn('haddpd');ReadModRM;XmmGE(16);End;
  $7D:Begin If DF2 Then SetMn('hsubps') Else SetMn('hsubpd');ReadModRM;XmmGE(16);End;
  $7E:Begin
   ReadModRM;
   If DF3 Then Begin
    SetMn('movq');XmmGE(8);
   End
   Else Begin
    If DOSz=8 Then Begin SetMn('movq');K:=8;End Else Begin SetMn('movd');K:=4;End;
    C:=SimdCls;
    DecodeRM(0,RC_GPR,K);SetReg(1,C,MReg,16);
   End;
  End;
  $7F:Begin
   ReadModRM;
   If DF3 Then SetMn('movdqu') Else If D66 Then SetMn('movdqa') Else SetMn('movq');
   C:=SimdCls;
   DecodeRM(0,C,16);SetReg(1,C,MReg,16);
  End;
  $80..$8F:Begin
   SetMn('j'+CCN[Opc and 15]);DI.CC:=Opc and 15;DI.Flow:=FL_JCC;
   If DOSz=2 Then SetRel(0,NextS(2)) Else SetRel(0,NextS(4));
  End;
  $90..$9F:Begin
   SetMn('set'+CCN[Opc and 15]);DI.CC:=Opc and 15;
   ReadModRM;DecodeRM(0,RC_GPR,1);
  End;
  $A0:Begin SetMn('push');SetReg(0,RC_SEG,4,2);End;
  $A1:Begin SetMn('pop');SetReg(0,RC_SEG,4,2);End;
  $A2:SetMn('cpuid');
  $A3,$AB,$B3,$BB:Begin
   Case Opc of $A3:SetMn('bt');$AB:SetMn('bts');$B3:SetMn('btr');$BB:SetMn('btc');End;
   ReadModRM;OpRM_Reg(DOSz);
  End;
  $A4,$AC:Begin
   If Opc=$A4 Then SetMn('shld') Else SetMn('shrd');
   ReadModRM;OpRM_Reg(DOSz);SetImm(2,NextU(1),1);
  End;
  $A5,$AD:Begin
   If Opc=$A5 Then SetMn('shld') Else SetMn('shrd');
   ReadModRM;OpRM_Reg(DOSz);SetReg(2,RC_GPR,1,1);
  End;
  $A8:Begin SetMn('push');SetReg(0,RC_SEG,5,2);End;
  $A9:Begin SetMn('pop');SetReg(0,RC_SEG,5,2);End;
  $AA:SetMn('rsm');
  $AE:Begin
   ReadModRM;
   If MMod=3 Then Begin
    Case MReg and 7 of
     5:SetMn('lfence');6:SetMn('mfence');7:SetMn('sfence');
     Else DFail:=True;
    End;
   End
   Else Begin
    Case MReg and 7 of
     0:SetMn('fxsave');1:SetMn('fxrstor');2:SetMn('ldmxcsr');3:SetMn('stmxcsr');
     4:SetMn('xsave');5:SetMn('xrstor');6:SetMn('xsaveopt');7:SetMn('clflush');
    End;
    DecodeRM(0,RC_GPR,4);
   End;
  End;
  $AF:Begin SetMn('imul');ReadModRM;OpReg_RM(DOSz);End;
  $B0:Begin SetMn('cmpxchg');ReadModRM;OpRM_Reg(1);End;
  $B1:Begin SetMn('cmpxchg');ReadModRM;OpRM_Reg(DOSz);End;
  $B2:Begin SetMn('lss');ReadModRM;DecodeRM(1,RC_GPR,6);SetReg(0,RC_GPR,MReg,DOSz);End;
  $B4:Begin SetMn('lfs');ReadModRM;DecodeRM(1,RC_GPR,6);SetReg(0,RC_GPR,MReg,DOSz);End;
  $B5:Begin SetMn('lgs');ReadModRM;DecodeRM(1,RC_GPR,6);SetReg(0,RC_GPR,MReg,DOSz);End;
  $B6:Begin SetMn('movzx');ReadModRM;DecodeRM(1,RC_GPR,1);SetReg(0,RC_GPR,MReg,DOSz);End;
  $B7:Begin SetMn('movzx');ReadModRM;DecodeRM(1,RC_GPR,2);SetReg(0,RC_GPR,MReg,DOSz);End;
  $B8:Begin
   If DF3 Then Begin SetMn('popcnt');ReadModRM;OpReg_RM(DOSz);End Else DFail:=True;
  End;
  $B9:SetMn('ud1');
  $BA:Begin
   ReadModRM;
   Case MReg and 7 of
    4:SetMn('bt');5:SetMn('bts');6:SetMn('btr');7:SetMn('btc');
    Else Begin DFail:=True;Exit;End;
   End;
   DecodeRM(0,RC_GPR,DOSz);SetImm(1,NextU(1),1);
  End;
  $BC:Begin
   If DF3 Then SetMn('tzcnt') Else SetMn('bsf');
   ReadModRM;OpReg_RM(DOSz);
  End;
  $BD:Begin
   If DF3 Then SetMn('lzcnt') Else SetMn('bsr');
   ReadModRM;OpReg_RM(DOSz);
  End;
  $BE:Begin SetMn('movsx');ReadModRM;DecodeRM(1,RC_GPR,1);SetReg(0,RC_GPR,MReg,DOSz);End;
  $BF:Begin SetMn('movsx');ReadModRM;DecodeRM(1,RC_GPR,2);SetReg(0,RC_GPR,MReg,DOSz);End;
  $C0:Begin SetMn('xadd');ReadModRM;OpRM_Reg(1);End;
  $C1:Begin SetMn('xadd');ReadModRM;OpRM_Reg(DOSz);End;
  $C2:Begin
   SetMn(PfxSuffix(['cmpps','cmppd','cmpss','cmpsd']));
   ReadModRM;
   If DF3 Then Sz:=4 Else If DF2 Then Sz:=8 Else Sz:=16;
   XmmGE(Sz);SetImm(2,NextU(1),1);
  End;
  $C3:Begin SetMn('movnti');ReadModRM;OpRM_Reg(DOSz);End;
  $C4:Begin
   SetMn('pinsrw');ReadModRM;
   C:=SimdCls;DecodeRM(1,RC_GPR,4);SetReg(0,C,MReg,16);SetImm(2,NextU(1),1);
  End;
  $C5:Begin
   SetMn('pextrw');ReadModRM;
   C:=SimdCls;DecodeRM(1,C,16);SetReg(0,RC_GPR,MReg,4);SetImm(2,NextU(1),1);
  End;
  $C6:Begin
   If D66 Then SetMn('shufpd') Else SetMn('shufps');
   ReadModRM;XmmGE(16);SetImm(2,NextU(1),1);
  End;
  $C7:Begin
   ReadModRM;
   If MMod=3 Then Begin
    Case MReg and 7 of
     6:SetMn('rdrand');7:SetMn('rdseed');
     Else Begin DFail:=True;Exit;End;
    End;
    DecodeRM(0,RC_GPR,DOSz);
   End
   Else Begin
    If(MReg and 7)<>1 Then Begin DFail:=True;Exit;End;
    If DOSz=8 Then Begin SetMn('cmpxchg16b');DecodeRM(0,RC_GPR,16);End
     Else Begin SetMn('cmpxchg8b');DecodeRM(0,RC_GPR,8);End;
   End;
  End;
  $C8..$CF:Begin
   SetMn('bswap');
   K:=(Opc and 7)or((DRex and 1)shl 3);
   If DOSz=8 Then SetReg(0,RC_GPR,K,8) Else SetReg(0,RC_GPR,K,4);
  End;
  $D0:Begin If D66 Then SetMn('addsubpd') Else SetMn('addsubps');ReadModRM;XmmGE(16);End;
  $D6:Begin
   ReadModRM;
   If D66 Then Begin SetMn('movq');XmmEG(8);End
   Else If DF3 Then Begin SetMn('movq2dq');DecodeRM(1,RC_MMX,8);SetReg(0,RC_XMM,MReg,16);End
   Else If DF2 Then Begin SetMn('movdq2q');DecodeRM(1,RC_XMM,16);SetReg(0,RC_MMX,MReg,8);End
   Else DFail:=True;
  End;
  $D7:Begin
   SetMn('pmovmskb');ReadModRM;
   C:=SimdCls;DecodeRM(1,C,16);SetReg(0,RC_GPR,MReg,4);
  End;
  $E6:Begin
   SetMn(PfxSuffix(['cvtdq2pd','cvttpd2dq','cvtdq2pd','cvtpd2dq']));
   ReadModRM;XmmGE(16);
  End;
  $E7:Begin
   ReadModRM;
   If D66 Then SetMn('movntdq') Else SetMn('movntq');
   C:=SimdCls;DecodeRM(0,C,16);SetReg(1,C,MReg,16);
  End;
  $F7:Begin
   If D66 Then SetMn('maskmovdqu') Else SetMn('maskmovq');
   ReadModRM;SimdGE(16);
  End;
  $D1..$D5,$D8..$DF,$E0..$E5,$E8..$EF,$F1..$F6,$F8..$FE:Begin
   Case Opc of
    $D1:S:='psrlw';$D2:S:='psrld';$D3:S:='psrlq';$D4:S:='paddq';$D5:S:='pmullw';
    $D8:S:='psubusb';$D9:S:='psubusw';$DA:S:='pminub';$DB:S:='pand';$DC:S:='paddusb';
    $DD:S:='paddusw';$DE:S:='pmaxub';$DF:S:='pandn';$E0:S:='pavgb';$E1:S:='psraw';
    $E2:S:='psrad';$E3:S:='pavgw';$E4:S:='pmulhuw';$E5:S:='pmulhw';$E8:S:='psubsb';
    $E9:S:='psubsw';$EA:S:='pminsw';$EB:S:='por';$EC:S:='paddsb';$ED:S:='paddsw';
    $EE:S:='pmaxsw';$EF:S:='pxor';$F1:S:='psllw';$F2:S:='pslld';$F3:S:='psllq';
    $F4:S:='pmuludq';$F5:S:='pmaddwd';$F6:S:='psadbw';$F8:S:='psubb';$F9:S:='psubw';
    $FA:S:='psubd';$FB:S:='psubq';$FC:S:='paddb';$FD:S:='paddw';$FE:S:='paddd';
   End;
   SetMn(S);ReadModRM;SimdGE(16);
  End;
  $FF:Begin SetMn('ud0');ReadModRM;OpReg_RM(DOSz);End;
  Else DFail:=True;
 End;
End;


{ Prefixes VEX (C4/C5) : decodage via les tables 0F existantes }
Procedure DecodeVex(Opc:Integer);
Var B1,B2,R,X,Bb,W,Pp,K:Integer;
Begin
 If Opc=$C5 Then Begin
  B1:=NextB;
  R:=(B1 shr 7)xor 1;X:=0;Bb:=0;W:=0;
  VexV:=((B1 shr 3)and 15)xor 15;VexL:=(B1 shr 2)and 1;Pp:=B1 and 3;VexMap:=1;
 End
 Else Begin
  B1:=NextB;B2:=NextB;
  R:=((B1 shr 7)and 1)xor 1;X:=((B1 shr 6)and 1)xor 1;Bb:=((B1 shr 5)and 1)xor 1;
  VexMap:=B1 and 31;
  W:=(B2 shr 7)and 1;VexV:=((B2 shr 3)and 15)xor 15;VexL:=(B2 shr 2)and 1;Pp:=B2 and 3;
 End;
 If(VexMap<1)or(VexMap>3)Then Begin DFail:=True;Exit;End;
 DRex:=(W shl 3)or(R shl 2)or(X shl 1)or Bb;
 DHasRex:=True;
 D66:=Pp=1;DF3:=Pp=2;DF2:=Pp=3;
 If W=1 Then DOSz:=8 Else If D66 Then DOSz:=2 Else DOSz:=4;
 Decode0F;
 If DFail Then Exit;
 If(Copy(DI.Mn,1,1)<>'v')Then DI.Mn:='v'+DI.Mn;
 If(VexV<>0)and(DI.N>=2)and(DI.N<4)and(DI.Mn<>'vzeroupper')and(Copy(DI.Mn,1,4)<>'vmov')and
   (Copy(DI.Mn,1,4)<>'vcvt')and(Copy(DI.Mn,1,5)<>'vpshu')and(Copy(DI.Mn,1,5)<>'vptes')and
   (Copy(DI.Mn,1,6)<>'vucomi')and(Copy(DI.Mn,1,5)<>'vcomi')Then Begin
  For K:=DI.N downto 2 do DI.Op[K]:=DI.Op[K-1];
  SetReg(1,RC_XMM,VexV,16);
  DI.N:=DI.N+1;
 End;
 If VexL=1 Then
  For K:=0 to DI.N-1 do Begin
   If(DI.Op[K].Kind=OK_REG)and(DI.Op[K].Cls=RC_XMM)Then DI.Op[K].Size:=32;
   If(DI.Op[K].Kind=OK_MEM)and(DI.Op[K].Size=16)Then DI.Op[K].Size:=32;
  End;
 DI.Rep:=0;
End;

{ Prefixe EVEX (AVX-512) : decodage generique (longueur seulement) }
Procedure DecodeEvex;
Var P0,P1,P2,Opc,Map:Integer;
Begin
 P0:=NextB;P1:=NextB;P2:=NextB;
 Map:=P0 and 7;
 DRex:=0;DHasRex:=True;
 If((P0 shr 7)and 1)=0 Then DRex:=DRex or 4;
 If((P0 shr 6)and 1)=0 Then DRex:=DRex or 2;
 If((P0 shr 5)and 1)=0 Then DRex:=DRex or 1;
 Opc:=NextB;
 ReadModRM;
 SetMn('evex_'+HexStr(Map,1)+'_'+HexStr(Opc,2));
 DecodeRM(0,RC_XMM,64);
 SetReg(1,RC_XMM,MReg,64);
 If(Map=3)or((Map=1)and(Opc>=$70)and(Opc<=$73))or((Map=1)and(Opc in[$C2,$C4,$C5,$C6]))Then
  SetImm(2,NextU(1),1);
End;

Procedure DecodeMain(Opc:Integer);
Var K,Sz,B:Integer;S:String;Imm:Int64;
Begin
 Case Opc of
  $00..$3F:Begin
   If(Opc and 7)<6 Then Begin
    SetMn(ARITH[Opc shr 3]);
    Case Opc and 7 of
     0:Begin ReadModRM;OpRM_Reg(1);End;
     1:Begin ReadModRM;OpRM_Reg(DOSz);End;
     2:Begin ReadModRM;OpReg_RM(1);End;
     3:Begin ReadModRM;OpReg_RM(DOSz);End;
     4:Begin SetReg(0,RC_GPR,0,1);SetImm(1,NextS(1),1);End;
     5:Begin SetReg(0,RC_GPR,0,DOSz);SetImm(1,ImmZ,DOSz);End;
    End;
   End
   Else If CpuMode=64 Then DFail:=True
   Else Case Opc of
    $06:Begin SetMn('push');SetReg(0,RC_SEG,0,2);End;
    $07:Begin SetMn('pop');SetReg(0,RC_SEG,0,2);End;
    $0E:Begin SetMn('push');SetReg(0,RC_SEG,1,2);End;
    $16:Begin SetMn('push');SetReg(0,RC_SEG,2,2);End;
    $17:Begin SetMn('pop');SetReg(0,RC_SEG,2,2);End;
    $1E:Begin SetMn('push');SetReg(0,RC_SEG,3,2);End;
    $1F:Begin SetMn('pop');SetReg(0,RC_SEG,3,2);End;
    $27:SetMn('daa');
    $2F:SetMn('das');
    $37:SetMn('aaa');
    $3F:SetMn('aas');
    Else DFail:=True;
   End;
  End;
  $40..$47:Begin SetMn('inc');SetReg(0,RC_GPR,Opc and 7,DOSz);End;
  $48..$4F:Begin SetMn('dec');SetReg(0,RC_GPR,Opc and 7,DOSz);End;
  $50..$57:Begin SetMn('push');SetReg(0,RC_GPR,(Opc and 7)or((DRex and 1)shl 3),StackSz);End;
  $58..$5F:Begin SetMn('pop');SetReg(0,RC_GPR,(Opc and 7)or((DRex and 1)shl 3),StackSz);End;
  $60:Begin
   If CpuMode=64 Then DFail:=True Else If DOSz=2 Then SetMn('pusha') Else SetMn('pushad');
  End;
  $61:Begin
   If CpuMode=64 Then DFail:=True Else If DOSz=2 Then SetMn('popa') Else SetMn('popad');
  End;
  $62:Begin
   If(CpuMode=64)or((CpuMode=32)and(DPos<DLen)and((DBuf[DPos]shr 6)=3))Then DecodeEvex
   Else Begin SetMn('bound');ReadModRM;DecodeRM(1,RC_GPR,DOSz*2);SetReg(0,RC_GPR,MReg,DOSz);End;
  End;
  $63:Begin
   ReadModRM;
   If CpuMode=64 Then Begin
    SetMn('movsxd');DecodeRM(1,RC_GPR,4);SetReg(0,RC_GPR,MReg,DOSz);
   End
   Else Begin
    SetMn('arpl');OpRM_Reg(2);
   End;
  End;
  $68:Begin
   SetMn('push');Sz:=StackSz;
   If Sz=2 Then SetImm(0,NextS(2),2) Else SetImm(0,NextS(4),Sz);
  End;
  $69:Begin SetMn('imul');ReadModRM;OpReg_RM(DOSz);SetImm(2,ImmZ,DOSz);End;
  $6A:Begin SetMn('push');SetImm(0,NextS(1),StackSz);End;
  $6B:Begin SetMn('imul');ReadModRM;OpReg_RM(DOSz);SetImm(2,NextS(1),DOSz);End;
  $6C:SetMn('insb');
  $6D:SetMn('ins'+SzSuffix);
  $6E:SetMn('outsb');
  $6F:SetMn('outs'+SzSuffix);
  $70..$7F:Begin
   SetMn('j'+CCN[Opc and 15]);DI.CC:=Opc and 15;DI.Flow:=FL_JCC;
   SetRel(0,NextS(1));
  End;
  $80,$82:Begin
   If(Opc=$82)and(CpuMode=64)Then Begin DFail:=True;Exit;End;
   ReadModRM;SetMn(ARITH[MReg and 7]);DecodeRM(0,RC_GPR,1);SetImm(1,NextS(1),1);
  End;
  $81:Begin ReadModRM;SetMn(ARITH[MReg and 7]);DecodeRM(0,RC_GPR,DOSz);SetImm(1,ImmZ,DOSz);End;
  $83:Begin ReadModRM;SetMn(ARITH[MReg and 7]);DecodeRM(0,RC_GPR,DOSz);SetImm(1,NextS(1),DOSz);End;
  $84:Begin SetMn('test');ReadModRM;OpRM_Reg(1);End;
  $85:Begin SetMn('test');ReadModRM;OpRM_Reg(DOSz);End;
  $86:Begin SetMn('xchg');ReadModRM;OpRM_Reg(1);End;
  $87:Begin SetMn('xchg');ReadModRM;OpRM_Reg(DOSz);End;
  $88:Begin SetMn('mov');ReadModRM;OpRM_Reg(1);End;
  $89:Begin SetMn('mov');ReadModRM;OpRM_Reg(DOSz);End;
  $8A:Begin SetMn('mov');ReadModRM;OpReg_RM(1);End;
  $8B:Begin SetMn('mov');ReadModRM;OpReg_RM(DOSz);End;
  $8C:Begin
   SetMn('mov');ReadModRM;
   If MMod=3 Then DecodeRM(0,RC_GPR,DOSz) Else DecodeRM(0,RC_GPR,2);
   SetReg(1,RC_SEG,MReg and 7,2);
  End;
  $8D:Begin
   SetMn('lea');ReadModRM;
   If MMod=3 Then Begin DFail:=True;Exit;End;
   DecodeRM(1,RC_GPR,0);SetReg(0,RC_GPR,MReg,DOSz);
  End;
  $8E:Begin
   SetMn('mov');ReadModRM;
   DecodeRM(1,RC_GPR,2);SetReg(0,RC_SEG,MReg and 7,2);
  End;
  $8F:Begin
   ReadModRM;
   If(MReg and 7)<>0 Then Begin DFail:=True;Exit;End;
   SetMn('pop');DecodeRM(0,RC_GPR,StackSz);
  End;
  $90:Begin
   If(DRex and 1)<>0 Then Begin
    SetMn('xchg');SetReg(0,RC_GPR,8,DOSz);SetReg(1,RC_GPR,0,DOSz);
   End
   Else If DF3 Then Begin SetMn('pause');DF3:=False;End
   Else SetMn('nop');
  End;
  $91..$97:Begin
   SetMn('xchg');SetReg(0,RC_GPR,(Opc and 7)or((DRex and 1)shl 3),DOSz);SetReg(1,RC_GPR,0,DOSz);
  End;
  $98:Case DOSz of 2:SetMn('cbw');8:SetMn('cdqe');Else SetMn('cwde');End;
  $99:Case DOSz of 2:SetMn('cwd');8:SetMn('cqo');Else SetMn('cdq');End;
  $9A:Begin
   If CpuMode=64 Then DFail:=True
   Else Begin
    SetMn('call');DI.Flow:=FL_ICALL;
    ClrOp(DI.Op[0]);DI.Op[0].Kind:=OK_FAR;
    If DOSz=2 Then DI.Op[0].Disp:=NextU(2) Else DI.Op[0].Disp:=NextU(4);
    DI.Op[0].Sel:=NextU(2);DI.N:=1;
   End;
  End;
  $9B:SetMn('fwait');
  $9C:Begin
   If CpuMode=64 Then SetMn('pushfq') Else If DOSz=2 Then SetMn('pushf') Else SetMn('pushfd');
  End;
  $9D:Begin
   If CpuMode=64 Then SetMn('popfq') Else If DOSz=2 Then SetMn('popf') Else SetMn('popfd');
  End;
  $9E:SetMn('sahf');
  $9F:SetMn('lahf');
  $A0..$A3:Begin
   SetMn('mov');
   If Opc and 1=0 Then Sz:=1 Else Sz:=DOSz;
   ClrOp(DI.Op[1]);
   ClrOp(DI.Op[0]);
   If Opc<$A2 Then Begin
    SetReg(0,RC_GPR,0,Sz);
    DI.Op[1].Kind:=OK_MEM;DI.Op[1].Size:=Sz;DI.Op[1].ASize:=DASz;DI.Op[1].Seg:=DSeg;DI.Op[1].Scale:=1;
    DI.Op[1].Disp:=NextU(DASz);DI.N:=2;
   End
   Else Begin
    DI.Op[0].Kind:=OK_MEM;DI.Op[0].Size:=Sz;DI.Op[0].ASize:=DASz;DI.Op[0].Seg:=DSeg;DI.Op[0].Scale:=1;
    DI.Op[0].Disp:=NextU(DASz);DI.N:=1;
    SetReg(1,RC_GPR,0,Sz);
   End;
  End;
  $A4:SetMn('movsb');
  $A5:SetMn('movs'+SzSuffix);
  $A6:SetMn('cmpsb');
  $A7:SetMn('cmps'+SzSuffix);
  $A8:Begin SetMn('test');SetReg(0,RC_GPR,0,1);SetImm(1,NextS(1),1);End;
  $A9:Begin SetMn('test');SetReg(0,RC_GPR,0,DOSz);SetImm(1,ImmZ,DOSz);End;
  $AA:SetMn('stosb');
  $AB:SetMn('stos'+SzSuffix);
  $AC:SetMn('lodsb');
  $AD:SetMn('lods'+SzSuffix);
  $AE:SetMn('scasb');
  $AF:SetMn('scas'+SzSuffix);
  $B0..$B7:Begin
   SetMn('mov');SetReg(0,RC_GPR,(Opc and 7)or((DRex and 1)shl 3),1);SetImm(1,NextS(1),1);
  End;
  $B8..$BF:Begin
   SetMn('mov');SetReg(0,RC_GPR,(Opc and 7)or((DRex and 1)shl 3),DOSz);
   Case DOSz of
    2:SetImm(1,NextS(2),2);
    8:SetImm(1,NextU(8),8);
    Else SetImm(1,NextS(4),4);
   End;
  End;
  $C0,$C1:Begin
   ReadModRM;SetMn(SHIFTN[MReg and 7]);
   If Opc=$C0 Then DecodeRM(0,RC_GPR,1) Else DecodeRM(0,RC_GPR,DOSz);
   SetImm(1,NextU(1),1);
  End;
  $C2:Begin SetMn('ret');DI.Flow:=FL_RET;SetImm(0,NextU(2),2);End;
  $C3:Begin SetMn('ret');DI.Flow:=FL_RET;End;
  $C4,$C5:Begin
   If(CpuMode=64)or((CpuMode=32)and(DPos<DLen)and((DBuf[DPos]shr 6)=3))Then DecodeVex(Opc)
   Else Begin
    ReadModRM;
    If MMod=3 Then Begin DFail:=True;Exit;End;
    If Opc=$C4 Then SetMn('les') Else SetMn('lds');
    DecodeRM(1,RC_GPR,DOSz+2);SetReg(0,RC_GPR,MReg,DOSz);
   End;
  End;
  $C6:Begin
   ReadModRM;
   If(MMod=3)and(MReg and 7=7)and(MRm=0)Then Begin SetMn('xabort');SetImm(0,NextU(1),1);Exit;End;
   If(MReg and 7)<>0 Then Begin DFail:=True;Exit;End;
   SetMn('mov');DecodeRM(0,RC_GPR,1);SetImm(1,NextS(1),1);
  End;
  $C7:Begin
   ReadModRM;
   If(MMod=3)and(MReg and 7=7)and(MRm=0)Then Begin
    SetMn('xbegin');DI.Flow:=FL_NORMAL;
    If DOSz=2 Then SetRel(0,NextS(2)) Else SetRel(0,NextS(4));
    Exit;
   End;
   If(MReg and 7)<>0 Then Begin DFail:=True;Exit;End;
   SetMn('mov');DecodeRM(0,RC_GPR,DOSz);SetImm(1,ImmZ,DOSz);
  End;
  $C8:Begin SetMn('enter');SetImm(0,NextU(2),2);SetImm(1,NextU(1),1);End;
  $C9:SetMn('leave');
  $CA:Begin SetMn('retf');DI.Flow:=FL_RET;SetImm(0,NextU(2),2);End;
  $CB:Begin SetMn('retf');DI.Flow:=FL_RET;End;
  $CC:Begin SetMn('int3');DI.Flow:=FL_HALT;End;
  $CD:Begin SetMn('int');SetImm(0,NextU(1),1);End;
  $CE:Begin If CpuMode=64 Then DFail:=True Else SetMn('into');End;
  $CF:Begin
   DI.Flow:=FL_RET;
   Case DOSz of 2:SetMn('iret');8:SetMn('iretq');Else SetMn('iretd');End;
  End;
  $D0..$D3:Begin
   ReadModRM;SetMn(SHIFTN[MReg and 7]);
   If Opc and 1=0 Then DecodeRM(0,RC_GPR,1) Else DecodeRM(0,RC_GPR,DOSz);
   If Opc<$D2 Then SetImm(1,1,1) Else SetReg(1,RC_GPR,1,1);
  End;
  $D4:Begin If CpuMode=64 Then DFail:=True Else Begin SetMn('aam');SetImm(0,NextU(1),1);End;End;
  $D5:Begin If CpuMode=64 Then DFail:=True Else Begin SetMn('aad');SetImm(0,NextU(1),1);End;End;
  $D6:Begin If CpuMode=64 Then DFail:=True Else SetMn('salc');End;
  $D7:SetMn('xlat');
  $D8..$DF:DecodeFPU(Opc);
  $E0..$E3:Begin
   Case Opc of
    $E0:SetMn('loopne');$E1:SetMn('loope');$E2:SetMn('loop');
    $E3:Case DASz of 2:SetMn('jcxz');8:SetMn('jrcxz');Else SetMn('jecxz');End;
   End;
   DI.Flow:=FL_JCC;DI.CC:=-1;SetRel(0,NextS(1));
  End;
  $E4:Begin SetMn('in');SetReg(0,RC_GPR,0,1);SetImm(1,NextU(1),1);End;
  $E5:Begin
   SetMn('in');If DOSz=2 Then SetReg(0,RC_GPR,0,2) Else SetReg(0,RC_GPR,0,4);SetImm(1,NextU(1),1);
  End;
  $E6:Begin SetMn('out');SetImm(0,NextU(1),1);SetReg(1,RC_GPR,0,1);End;
  $E7:Begin
   SetMn('out');SetImm(0,NextU(1),1);If DOSz=2 Then SetReg(1,RC_GPR,0,2) Else SetReg(1,RC_GPR,0,4);
  End;
  $E8:Begin
   SetMn('call');DI.Flow:=FL_CALL;
   If DOSz=2 Then SetRel(0,NextS(2)) Else SetRel(0,NextS(4));
  End;
  $E9:Begin
   SetMn('jmp');DI.Flow:=FL_JMP;
   If DOSz=2 Then SetRel(0,NextS(2)) Else SetRel(0,NextS(4));
  End;
  $EA:Begin
   If CpuMode=64 Then DFail:=True
   Else Begin
    SetMn('jmp');DI.Flow:=FL_IJMP;
    ClrOp(DI.Op[0]);DI.Op[0].Kind:=OK_FAR;
    If DOSz=2 Then DI.Op[0].Disp:=NextU(2) Else DI.Op[0].Disp:=NextU(4);
    DI.Op[0].Sel:=NextU(2);DI.N:=1;
   End;
  End;
  $EB:Begin SetMn('jmp');DI.Flow:=FL_JMP;SetRel(0,NextS(1));End;
  $EC:Begin SetMn('in');SetReg(0,RC_GPR,0,1);SetReg(1,RC_GPR,2,2);End;
  $ED:Begin
   SetMn('in');If DOSz=2 Then SetReg(0,RC_GPR,0,2) Else SetReg(0,RC_GPR,0,4);SetReg(1,RC_GPR,2,2);
  End;
  $EE:Begin SetMn('out');SetReg(0,RC_GPR,2,2);SetReg(1,RC_GPR,0,1);End;
  $EF:Begin
   SetMn('out');SetReg(0,RC_GPR,2,2);If DOSz=2 Then SetReg(1,RC_GPR,0,2) Else SetReg(1,RC_GPR,0,4);
  End;
  $F1:SetMn('int1');
  $F4:Begin SetMn('hlt');DI.Flow:=FL_HALT;End;
  $F5:SetMn('cmc');
  $F6,$F7:Begin
   ReadModRM;
   If Opc=$F6 Then Sz:=1 Else Sz:=DOSz;
   SetMn(GRP3N[MReg and 7]);
   DecodeRM(0,RC_GPR,Sz);
   If(MReg and 7)<2 Then Begin
    If Sz=1 Then SetImm(1,NextS(1),1) Else SetImm(1,ImmZ,Sz);
   End;
  End;
  $F8:SetMn('clc');
  $F9:SetMn('stc');
  $FA:SetMn('cli');
  $FB:SetMn('sti');
  $FC:SetMn('cld');
  $FD:SetMn('std');
  $FE:Begin
   ReadModRM;
   Case MReg and 7 of
    0:SetMn('inc');1:SetMn('dec');
    Else Begin DFail:=True;Exit;End;
   End;
   DecodeRM(0,RC_GPR,1);
  End;
  $FF:Begin
   ReadModRM;
   Case MReg and 7 of
    0:Begin SetMn('inc');DecodeRM(0,RC_GPR,DOSz);End;
    1:Begin SetMn('dec');DecodeRM(0,RC_GPR,DOSz);End;
    2:Begin
     SetMn('call');DI.Flow:=FL_ICALL;
     If CpuMode=64 Then DecodeRM(0,RC_GPR,8) Else DecodeRM(0,RC_GPR,DOSz);
    End;
    3:Begin
     If MMod=3 Then Begin DFail:=True;Exit;End;
     SetMn('call');DI.Flow:=FL_ICALL;DecodeRM(0,RC_GPR,DOSz+2);
    End;
    4:Begin
     SetMn('jmp');DI.Flow:=FL_IJMP;
     If CpuMode=64 Then DecodeRM(0,RC_GPR,8) Else DecodeRM(0,RC_GPR,DOSz);
    End;
    5:Begin
     If MMod=3 Then Begin DFail:=True;Exit;End;
     SetMn('jmp');DI.Flow:=FL_IJMP;DecodeRM(0,RC_GPR,DOSz+2);
    End;
    6:Begin SetMn('push');DecodeRM(0,RC_GPR,StackSz);End;
    Else DFail:=True;
   End;
  End;
  Else DFail:=True;
 End;
End;

{ Decode une instruction a Addr.  Retourne False si octet invalide. }
Function Decode(Addr:Int64;Var Ins:TInsn):Boolean;
Var I,Opc,K:Integer;B:Byte;Fin:Boolean;Pf:Integer;
Begin
 DLen:=0;
 For I:=0 to 15 do Begin
  If ReadB(Addr+I,B)Then Begin DBuf[I]:=B;DLen:=I+1;End Else Break;
 End;
 DPos:=0;DFail:=False;DRex:=0;DHasRex:=False;
 D66:=False;D67:=False;DF2:=False;DF3:=False;DLk:=False;DSeg:=-1;MemFixup:=-1;
 FillChar(DI,SizeOf(DI),0);
 DI.Addr:=Addr;DI.CC:=-1;DI.Flow:=FL_NORMAL;
 For I:=0 to 3 do ClrOp(DI.Op[I]);
 VexMap:=0;VexL:=0;VexV:=0;
 Fin:=False;Opc:=0;Pf:=0;
 While not Fin and not DFail do Begin
  Opc:=NextB;
  Inc(Pf);
  If Pf>14 Then Begin DFail:=True;Break;End;
  Case Opc of
   $26:DSeg:=0;
   $2E:DSeg:=1;
   $36:DSeg:=2;
   $3E:DSeg:=3;
   $64:DSeg:=4;
   $65:DSeg:=5;
   $66:D66:=True;
   $67:D67:=True;
   $F0:DLk:=True;
   $F2:Begin DF2:=True;DF3:=False;End;
   $F3:Begin DF3:=True;DF2:=False;End;
   Else Fin:=True;
  End;
  If Fin and(CpuMode=64)and(Opc>=$40)and(Opc<=$4F)Then Begin
   DRex:=Opc;DHasRex:=True;
   Opc:=NextB;
  End;
 End;
 { tailles }
 Case CpuMode of
  16:Begin DOSz:=2;DASz:=2;End;
  32:Begin DOSz:=4;DASz:=4;End;
  Else Begin DOSz:=4;DASz:=8;End;
 End;
 If D66 Then Begin If CpuMode=16 Then DOSz:=4 Else DOSz:=2;End;
 If D67 Then Begin
  If CpuMode=16 Then DASz:=4 Else If CpuMode=32 Then DASz:=2 Else DASz:=4;
 End;
 If(CpuMode=64)and((DRex and 8)<>0)Then DOSz:=8;
 DI.OSize:=DOSz;
 If not DFail Then Begin
  If Opc=$0F Then Decode0F Else DecodeMain(Opc);
 End;
 { prefixes de repetition / verrou conserves pour l'affichage }
 If DF2 Then DI.Rep:=2 Else If DF3 Then DI.Rep:=1;
 DI.Lock:=DLk;
 If DFail or(DPos>DLen)Then Begin
  FillChar(Ins,SizeOf(Ins),0);
  Ins.Addr:=Addr;Ins.Len:=1;Ins.Mn:='db';Ins.N:=1;Ins.Valid:=False;Ins.CC:=-1;
  ClrOp(Ins.Op[0]);
  Ins.Op[0].Kind:=OK_IMM;Ins.Op[0].Size:=1;
  If DLen>0 Then Ins.Op[0].Disp:=DBuf[0];
  If DLen=0 Then Decode:=False Else Decode:=False;
  Exit;
 End;
 DI.Len:=DPos;
 DI.Valid:=True;
 { post-traitement : rip-relatif et cibles }
 If MemFixup>=0 Then DI.Op[MemFixup].Disp:=(DI.Op[MemFixup].Disp+Addr+DPos);
 For K:=0 to DI.N-1 do
  If DI.Op[K].Kind=OK_REL Then Begin
   DI.Op[K].Disp:=Addr+DPos+DI.Op[K].Disp;
   If CpuMode=32 Then DI.Op[K].Disp:=DI.Op[K].Disp and $FFFFFFFF;
   If CpuMode=16 Then DI.Op[K].Disp:=DI.Op[K].Disp and $FFFFF;
   DI.Target:=DI.Op[K].Disp;
  End;
 If CpuMode=16 Then
  For K:=0 to DI.N-1 do
   If DI.Op[K].Kind=OK_FAR Then Begin
    DI.Target:=(Int64(DI.Op[K].Sel)shl 4)+DI.Op[K].Disp;
    If DI.Mn='call' Then DI.Flow:=FL_CALL
    Else If DI.Mn='jmp' Then DI.Flow:=FL_JMP;
   End;
 If(DI.Flow=FL_NORMAL)and(DI.Mn='jmp')Then DI.Flow:=FL_IJMP;
 Ins:=DI;
 Decode:=True;
End;

{ ============================================================
  FORMATAGE (syntaxe Intel)
  ============================================================ }
Function SizePtr(Sz:Integer):String;
Begin
 Case Sz of
  1:SizePtr:='byte ptr ';
  2:SizePtr:='word ptr ';
  4:SizePtr:='dword ptr ';
  6:SizePtr:='fword ptr ';
  8:SizePtr:='qword ptr ';
  10:SizePtr:='tbyte ptr ';
  16:SizePtr:='xmmword ptr ';
  32:SizePtr:='ymmword ptr ';
  64:SizePtr:='zmmword ptr ';
  Else SizePtr:='';
 End;
End;

Function HexSigned(V:Int64):String;
Begin
 If V<0 Then HexSigned:='- '+Hex0x(-V) Else HexSigned:='+ '+Hex0x(V);
End;

Function FmtMem(Const O:TOperand;Const I:TInsn):String;
Var S:String;HasPart:Boolean;AS_:Integer;V:Int64;
Begin
 S:='';
 If O.Seg>=0 Then S:=RSEG[O.Seg]+':';
 S:=S+'[';
 HasPart:=False;
 AS_:=O.ASize;
 If O.Base=16 Then Begin
  S:=S+'rip';HasPart:=True;
  S:=S+' '+HexSigned(O.Disp-(I.Addr+I.Len));
  S:=S+']';
  FmtMem:=SizePtr(O.Size)+S;
  Exit;
 End;
 If O.Base>=0 Then Begin
  S:=S+RegName(RC_GPR,O.Base,AS_,False);HasPart:=True;
 End;
 If O.Index>=0 Then Begin
  If HasPart Then S:=S+' + ';
  S:=S+RegName(RC_GPR,O.Index,AS_,False);
  If O.Scale>1 Then S:=S+'*'+LStr(O.Scale);
  HasPart:=True;
 End;
 If(O.Disp<>0)or not HasPart Then Begin
  If HasPart Then Begin
   If O.Disp<0 Then S:=S+' - '+Hex0x(-O.Disp) Else S:=S+' + '+Hex0x(O.Disp);
  End
  Else Begin
   V:=O.Disp;
   If O.ASize=4 Then V:=V and $FFFFFFFF Else If O.ASize=2 Then V:=V and $FFFF;
   S:=S+Hex0x(V);
  End;
 End;
 S:=S+']';
 FmtMem:=SizePtr(O.Size)+S;
End;

Function FmtOp(Const I:TInsn;K:Integer):String;
Var O:TOperand;V:Int64;S:String;
Begin
 O:=I.Op[K];
 Case O.Kind of
  OK_REG:FmtOp:=RegName(O.Cls,O.Reg,O.Size,O.Hi);
  OK_IMM:Begin
   V:=O.Disp;
   Case O.Size of
    1:V:=V and $FF;
    2:V:=V and $FFFF;
    4:V:=V and $FFFFFFFF;
   End;
   FmtOp:=Hex0x(V);
  End;
  OK_MEM:FmtOp:=FmtMem(O,I);
  OK_REL:Begin
   S:=Hex0x(O.Disp);
   FmtOp:=S;
  End;
  OK_FAR:FmtOp:=Hex0x(O.Sel)+':'+Hex0x(O.Disp);
  Else FmtOp:='?';
 End;
End;

Function FmtInsn(Const I:TInsn):String;
Var S:String;K:Integer;
Begin
 S:='';
 If I.Lock Then S:='lock ';
 If I.Rep<>0 Then Begin
  If I.N=0 Then Begin
   If(Copy(I.Mn,1,4)='cmps')or(Copy(I.Mn,1,4)='scas')Then Begin
    If I.Rep=1 Then S:=S+'repe ' Else S:=S+'repne ';
   End
   Else If(Copy(I.Mn,1,4)='movs')or(Copy(I.Mn,1,4)='stos')or(Copy(I.Mn,1,4)='lods')or
          (Copy(I.Mn,1,3)='ins')or(Copy(I.Mn,1,4)='outs')Then Begin
    If I.Rep=1 Then S:=S+'rep ' Else S:=S+'repne ';
   End;
  End
  Else If(I.Flow=FL_RET)and(I.Rep=1)Then S:=S+'repz ';
 End;
 S:=S+I.Mn;
 For K:=0 to I.N-1 do Begin
  If K=0 Then S:=S+' ' Else S:=S+', ';
  S:=S+FmtOp(I,K);
 End;
 FmtInsn:=S;
End;

{ ============================================================
  CACHE D'INSTRUCTIONS ET DECOUVERTE DES FONCTIONS
  ============================================================ }
Const
 BK_FALL = 0;
 BK_JMP  = 1;
 BK_JCC  = 2;
 BK_RET  = 3;
 BK_IJMP = 4;
 BK_HALT = 5;
 BK_TAIL = 6;
 BK_SWITCH= 7;
 MAXSW    = 16384;
 MAXSWREC = 64;

Type
 THashArr = Array[0..HASHSIZE-1] of LongInt;
 TMarkArr = Array[0..MAXINS-1] of LongInt;
 TRootHashArr = Array[0..262143] of LongInt;
 TFnInsArr = Array[0..MAXFNINS-1] of LongInt;

Var
 Ins:PInsArr;
 NIns:LongInt;
 HashTab:^THashArr;
 Mark,LdrMark:^TMarkArr;
 FnStamp:LongInt;
 InsWarned:Boolean;

 { Points d'entree de fonctions }
 NRoot:LongInt;
 RootAddr:Array[0..MAXROOT-1] of Int64;
 RootHash:^TRootHashArr;
 RootsChanged:Boolean;

 { Fonction courante }
 FnEntry:Int64;
 FnIns:^TFnInsArr;
 NFnIns:LongInt;
 FnTrunc:Boolean;
 NB:LongInt;
 BStart,BEndA:Array[0..MAXBLK-1] of Int64;
 BI0,BN:Array[0..MAXBLK-1] of LongInt;
 BS0,BS1:Array[0..MAXBLK-1] of LongInt;
 BKind:Array[0..MAXBLK-1] of Byte;
 BTgt:Array[0..MAXBLK-1] of Int64;       { cible externe (appel terminal) }
 BExt0:Array[0..MAXBLK-1] of Boolean;    { la cible du saut est externe }

 { tables de saut (switch) }
 BSdS,BSdN:Array[0..MAXBLK-1] of LongInt;   { successeurs distincts }
 SdPool:Array[0..MAXSW-1] of LongInt;
 NSd:LongInt;
 BSwS,BSwN:Array[0..MAXBLK-1] of LongInt;   { entrees de la table }
 SwPool:Array[0..MAXSW-1] of LongInt;
 NSw:LongInt;
 NSwRec:LongInt;
 SwInsAddr,SwLoadAddr:Array[0..MAXSWREC-1] of Int64;
 SwIdxReg:Array[0..MAXSWREC-1] of ShortInt;
 SwIdxSz:Array[0..MAXSWREC-1] of Byte;
 SwCnt:Array[0..MAXSWREC-1] of LongInt;
 SwTab:Array[0..MAXSWREC-1,0..255] of Int64;
 Ring:Array[0..15] of LongInt;
 RingN:Integer;
 ThkSrc,ThkDst:Array[0..4095] of Int64;
 NThk:LongInt;

Procedure InitCache;
Begin
 If Ins=Nil Then Begin
  GetMem(Ins,Int64(MAXINS)*SizeOf(TInsn));
  GetMem(HashTab,HASHSIZE*4);
  GetMem(Mark,MAXINS*4);
  GetMem(LdrMark,MAXINS*4);
  GetMem(RootHash,262144*4);
  GetMem(FnIns,MAXFNINS*4);
 End;
 FillChar(HashTab^,HASHSIZE*4,$FF);
 FillChar(Mark^,MAXINS*4,0);
 FillChar(LdrMark^,MAXINS*4,0);
 FillChar(RootHash^,262144*4,$FF);
 NIns:=0;NRoot:=0;FnStamp:=0;InsWarned:=False;NThk:=0;
End;

Function HashSlot(A:Int64):LongInt;
Begin
 HashSlot:=LongInt((A xor(A shr 17)xor(A shr 31))and(HASHSIZE-1));
End;

{ Retourne l'indice de l'instruction decodee a l'adresse, ou -1 }
Function GetIns(Addr:Int64):LongInt;
Var H:LongInt;Tmp:TInsn;
Begin
 H:=HashSlot(Addr);
 While HashTab^[H]>=0 do Begin
  If Ins^[HashTab^[H]].Addr=Addr Then Begin GetIns:=HashTab^[H];Exit;End;
  H:=(H+1)and(HASHSIZE-1);
 End;
 If not IsMapped(Addr)Then Begin GetIns:=-1;Exit;End;
 If NIns>=MAXINS Then Begin
  If not InsWarned Then Warn('limite du nombre d''instructions atteinte');
  InsWarned:=True;
  GetIns:=-1;Exit;
 End;
 Decode(Addr,Tmp);
 Ins^[NIns]:=Tmp;
 HashTab^[H]:=NIns;
 GetIns:=NIns;
 Inc(NIns);
End;

Function InRange(A:Int64):Boolean;
Begin
 InRange:=True;
 If HasFrom and(A<OptFrom)Then InRange:=False;
 If HasTo and(A>=OptTo)Then InRange:=False;
End;

{ ---- roots ---- }
Function RootSlot(A:Int64):LongInt;
Begin
 RootSlot:=LongInt((A xor(A shr 16)xor(A shr 29))and 262143);
End;

Function IsRoot(A:Int64):Boolean;
Var H:LongInt;
Begin
 H:=RootSlot(A);
 IsRoot:=False;
 While RootHash^[H]>=0 do Begin
  If RootAddr[RootHash^[H]]=A Then Begin IsRoot:=True;Exit;End;
  H:=(H+1)and 262143;
 End;
End;

Function SymKindAt(A:Int64):Integer;
Var I:LongInt;
Begin
 I:=SymAt(A);
 If I<0 Then SymKindAt:=-1 Else SymKindAt:=Syms[I].Kind;
End;

{ une adresse qui est une procedure d'import (thunk) }
Function IsThunkAddr(A:Int64):Boolean;
Var K:Integer;
Begin
 K:=SymKindAt(A);
 IsThunkAddr:=(K=SK_THUNK)or(K=SK_IMPORT);
End;

{ Si l'instruction est un jmp indirect [mem] vers une entree d'import, retourne le nom }
Function ThunkImportName(Const I:TInsn):String;
Var Slot:Int64;
Begin
 ThunkImportName:='';
 If(I.Flow<>FL_IJMP)or(I.N<1)or(I.Op[0].Kind<>OK_MEM)Then Exit;
 If I.Op[0].Base=16 Then Slot:=I.Op[0].Disp
 Else If(I.Op[0].Base<0)and(I.Op[0].Index<0)Then Slot:=I.Op[0].Disp
 Else If(CpuMode=32)and(PltGot<>0)and(I.Op[0].Base=3)and(I.Op[0].Index<0)Then Slot:=PltGot+I.Op[0].Disp
 Else Exit;
 If CpuMode=32 Then Slot:=Slot and $FFFFFFFF;
 ThunkImportName:=ImportAt(Slot);
End;

Function AddRoot(A:Int64):Boolean;
Var H,Idx,Sg:LongInt;Nm:String;
Begin
 AddRoot:=False;
 If NRoot>=MAXROOT Then Exit;
 If not IsExecAddr(A)Then Exit;
 Sg:=FindSeg(A);
 If(Sg>=0)and(Copy(Segs[Sg].Name,1,4)='.plt')Then Exit;
 If IsRoot(A)Then Exit;
 If IsThunkAddr(A)Then Exit;
 If not InRange(A)Then Exit;
 Idx:=GetIns(A);
 If Idx<0 Then Exit;
 If not Ins^[Idx].Valid Then Exit;
 { petit thunk qui saute vers un import : n'est pas une fonction }
 Nm:=ThunkImportName(Ins^[Idx]);
 If Nm<>''Then Begin
  AddSym(Nm,A,Ins^[Idx].Len,SK_THUNK);
  Exit;
 End;
 H:=RootSlot(A);
 While RootHash^[H]>=0 do H:=(H+1)and 262143;
 RootHash^[H]:=NRoot;
 RootAddr[NRoot]:=A;
 Inc(NRoot);
 RootsChanged:=True;
 AddRoot:=True;
End;

Procedure SortRoots(L,R:LongInt);
Var I,J:LongInt;P,T:Int64;
Begin
 While L<R do Begin
  I:=L;J:=R;P:=RootAddr[(L+R)div 2];
  Repeat
   While RootAddr[I]<P do Inc(I);
   While RootAddr[J]>P do Dec(J);
   If I<=J Then Begin
    T:=RootAddr[I];RootAddr[I]:=RootAddr[J];RootAddr[J]:=T;
    Inc(I);Dec(J);
   End;
  Until I>J;
  If J-L<R-I Then Begin SortRoots(L,J);L:=I;End
  Else Begin SortRoots(I,R);R:=J;End;
 End;
End;

Procedure RebuildRootHash;
Var I,H:LongInt;
Begin
 FillChar(RootHash^,262144*4,$FF);
 For I:=0 to NRoot-1 do Begin
  H:=RootSlot(RootAddr[I]);
  While RootHash^[H]>=0 do H:=(H+1)and 262143;
  RootHash^[H]:=I;
 End;
End;

{ ---- fonctions qui ne retournent pas ---- }
Function IsNoReturnName(N:String):Boolean;
Begin
 IsNoReturnName:=False;
 If N=''Then Exit;
 If(N='exit')or(N='_exit')or(N='_Exit')or(N='abort')or(N='quick_exit')or
   (N='__stack_chk_fail')or(N='__assert_fail')or(N='__assert')or(N='longjmp')or
   (N='_longjmp')or(N='siglongjmp')or(N='__cxa_throw')or(N='__cxa_rethrow')or
   (N='ExitProcess')or(N='ExitThread')or(N='FatalExit')or(N='FatalAppExitA')or
   (N='_CxxThrowException')or(N='__chk_fail')or(N='__fortify_fail')or
   (N='__libc_fatal')or(N='pthread_exit')or(N='__cxa_bad_cast')or
   (N='__cxa_bad_typeid')or(N='__builtin_unreachable')or(N='terminate')or
   (N='_ZSt9terminatev')or(N='__stack_chk_fail_local')Then
  IsNoReturnName:=True;
End;

Function CallTargetName(Const I:TInsn):String;
Var Slot:Int64;
Begin
 CallTargetName:='';
 If I.Flow=FL_CALL Then CallTargetName:=SymName(I.Target)
 Else If(I.Flow=FL_ICALL)and(I.N>=1)and(I.Op[0].Kind=OK_MEM)Then Begin
  If I.Op[0].Base=16 Then Slot:=I.Op[0].Disp
  Else If(I.Op[0].Base<0)and(I.Op[0].Index<0)Then Slot:=I.Op[0].Disp
  Else Exit;
  If CpuMode=32 Then Slot:=Slot and $FFFFFFFF;
  CallTargetName:=ImportAt(Slot);
 End;
End;

Function IsNoRetCall(Const I:TInsn):Boolean;
Begin
 IsNoRetCall:=False;
 If(I.Flow=FL_CALL)or(I.Flow=FL_ICALL)Then IsNoRetCall:=IsNoReturnName(CallTargetName(I));
End;

{ ---- couverture du code ---- }
Procedure CoverAddr(A:Int64;L:Integer);
Var S:LongInt;I:Integer;
Begin
 S:=FindSeg(A);
 If(S<0)or(Segs[S].Cov=Nil)Then Exit;
 For I:=0 to L-1 do
  If(A-Segs[S].Addr+I<Segs[S].Size)Then Segs[S].Cov^[A-Segs[S].Addr+I]:=1;
End;

Function IsCovered(A:Int64):Boolean;
Var S:LongInt;
Begin
 S:=FindSeg(A);
 IsCovered:=(S>=0)and(Segs[S].Cov<>Nil)and(Segs[S].Cov^[A-Segs[S].Addr]<>0);
End;


{ ---- successeurs ---- }
Function NSucc(B:LongInt):LongInt;
Var N:LongInt;
Begin
 If BKind[B]=BK_SWITCH Then Begin NSucc:=BSdN[B];Exit;End;
 N:=0;
 If BS0[B]>=0 Then N:=1;
 If(BS1[B]>=0)and(BS1[B]<>BS0[B])Then Inc(N);
 NSucc:=N;
End;

Function SuccOf(B,K:LongInt):LongInt;
Begin
 SuccOf:=-1;
 If BKind[B]=BK_SWITCH Then Begin
  If K<BSdN[B]Then SuccOf:=SdPool[BSdS[B]+K];
  Exit;
 End;
 If BS0[B]>=0 Then Begin
  If K=0 Then SuccOf:=BS0[B]
  Else If(K=1)and(BS1[B]>=0)and(BS1[B]<>BS0[B])Then SuccOf:=BS1[B];
 End
 Else If(K=0)and(BS1[B]>=0)Then SuccOf:=BS1[B];
End;

{ ---- recherche d'une table de saut pour le saut indirect X ---- }
Function SwRecFor(InsAddr:Int64):LongInt;
Var I:LongInt;
Begin
 SwRecFor:=-1;
 For I:=0 to NSwRec-1 do
  If SwInsAddr[I]=InsAddr Then Begin SwRecFor:=I;Exit;End;
End;

Function SwRecLoad(LoadAddr:Int64):LongInt;
Var I:LongInt;
Begin
 SwRecLoad:=-1;
 For I:=0 to NSwRec-1 do
  If SwLoadAddr[I]=LoadAddr Then Begin SwRecLoad:=I;Exit;End;
End;

Function TryJumpTable(X:LongInt):Boolean;
Var
 P,Q:^TInsn;
 I,K,Cnt,BoundN,EntSz,IdxReg,IdxSz,RegR,RegB,RegX,Kadd:LongInt;
 Tbl,BaseV,E,T,LoadAddr:Int64;
 Rel,Found,FoundLoad,FoundLea,Bad:Boolean;
Begin
 TryJumpTable:=False;
 If NSwRec>=MAXSWREC Then Exit;
 P:=@Ins^[X];
 If P^.N<1 Then Exit;
 BoundN:=-1;
 For I:=RingN-1 downto 0 do Begin
  Q:=@Ins^[Ring[I]];
  If(Q^.Mn='cmp')and(Q^.N=2)and(Q^.Op[1].Kind=OK_IMM)and(Q^.Op[1].Disp>=0)and(Q^.Op[1].Disp<=255)Then Begin
   BoundN:=Q^.Op[1].Disp+1;Break;
  End;
 End;
 Rel:=False;Tbl:=0;BaseV:=0;EntSz:=0;IdxReg:=-1;IdxSz:=0;LoadAddr:=P^.Addr;Found:=False;
 If(P^.Op[0].Kind=OK_MEM)and(P^.Op[0].Base<0)and(P^.Op[0].Index>=0)and(P^.Op[0].Scale in[4,8])Then Begin
  Tbl:=P^.Op[0].Disp;
  If CpuMode=32 Then Tbl:=Tbl and $FFFFFFFF;
  EntSz:=P^.Op[0].Scale;IdxReg:=P^.Op[0].Index;IdxSz:=P^.Op[0].ASize;
  Found:=True;
 End
 Else If(P^.Op[0].Kind=OK_REG)and(P^.Op[0].Cls=RC_GPR)Then Begin
  RegR:=P^.Op[0].Reg;RegB:=-1;
  For I:=RingN-1 downto 0 do Begin
   Q:=@Ins^[Ring[I]];
   If(Q^.Mn='add')and(Q^.N=2)and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegR)and
     (Q^.Op[1].Kind=OK_REG)and(Q^.Op[1].Cls=RC_GPR)Then Begin RegB:=Q^.Op[1].Reg;Break;End;
  End;
  If RegB>=0 Then Begin
   FoundLoad:=False;
   For I:=RingN-1 downto 0 do Begin
    Q:=@Ins^[Ring[I]];
    If(Q^.N=2)and((Q^.Mn='mov')or(Q^.Mn='movsxd'))and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegR)and
      (Q^.Op[1].Kind=OK_MEM)and(Q^.Op[1].Index>=0)and(Q^.Op[1].Scale=4)and(Q^.Op[1].Base=RegB)Then Begin
     EntSz:=4;IdxReg:=Q^.Op[1].Index;IdxSz:=Q^.Op[1].ASize;LoadAddr:=Q^.Addr;Rel:=True;
     FoundLoad:=True;
     If CpuMode=64 Then Begin
      FoundLea:=False;
      K:=I-1;
      While K>=0 do Begin
       Q:=@Ins^[Ring[K]];
       If(Q^.Mn='lea')and(Q^.N=2)and(Q^.Op[0].Reg=RegB)and(Q^.Op[1].Kind=OK_MEM)and(Q^.Op[1].Base=16)Then Begin
        Tbl:=Q^.Op[1].Disp;BaseV:=Tbl;FoundLea:=True;Break;
       End;
       Dec(K);
      End;
      Found:=FoundLea;
     End
     Else Begin
      If PltGot<>0 Then Begin
       BaseV:=PltGot;Tbl:=(PltGot+Q^.Op[1].Disp)and $FFFFFFFF;Found:=True;
      End;
     End;
     Break;
    End;
   End;
  End;
  { variante : mov r,[idx*8+table] ; jmp r  (table absolue) }
  If not Found Then
   For I:=RingN-1 downto 0 do Begin
    Q:=@Ins^[Ring[I]];
    If(Q^.N=2)and(Q^.Mn='mov')and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegR)and(Q^.Op[1].Kind=OK_MEM)and
      (Q^.Op[1].Base<0)and(Q^.Op[1].Index>=0)and(Q^.Op[1].Scale in[4,8])Then Begin
     Tbl:=Q^.Op[1].Disp;
     If CpuMode=32 Then Tbl:=Tbl and $FFFFFFFF;
     EntSz:=Q^.Op[1].Scale;IdxReg:=Q^.Op[1].Index;IdxSz:=Q^.Op[1].ASize;LoadAddr:=Q^.Addr;Rel:=False;
     Found:=True;Break;
    End;
   End;
  { variante -O0 : shl r,2 ; add r,table ; mov r,[r] ; jmp r }
  If not Found Then
   For I:=RingN-1 downto 0 do Begin
    Q:=@Ins^[Ring[I]];
    If(Q^.N=2)and(Q^.Mn='mov')and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegR)and(Q^.Op[1].Kind=OK_MEM)and
      (Q^.Op[1].Index<0)and(Q^.Op[1].Base>=0)and(Q^.Op[1].Base<16)and(Q^.Op[1].Disp=0)Then Begin
     RegX:=Q^.Op[1].Base;
     Kadd:=-1;
     For K:=I-1 downto 0 do Begin
      Q:=@Ins^[Ring[K]];
      If(Q^.Mn='add')and(Q^.N=2)and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegX)and(Q^.Op[1].Kind=OK_IMM)Then Begin
       Tbl:=Q^.Op[1].Disp;
       If CpuMode=32 Then Tbl:=Tbl and $FFFFFFFF;
       Kadd:=K;Break;
      End;
     End;
     If Kadd>=0 Then
      For K:=Kadd-1 downto 0 do Begin
       Q:=@Ins^[Ring[K]];
       If(Q^.Mn='shl')and(Q^.N=2)and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegX)and(Q^.Op[1].Kind=OK_IMM)and
         ((Q^.Op[1].Disp=2)or(Q^.Op[1].Disp=3))Then Begin
        EntSz:=1 shl Q^.Op[1].Disp;IdxReg:=RegX;IdxSz:=Q^.Op[0].Size;LoadAddr:=Q^.Addr;Rel:=False;
        Found:=True;Break;
       End;
      End;
     Break;
    End;
   End;
  { variante : indice pre-multiplie par 4 (lea r,[x*4]) et table chargee par lea r,[rip+T] }
  If not Found and(CpuMode=64)and(RegB>=0)Then Begin
   For I:=RingN-1 downto 0 do Begin
    Q:=@Ins^[Ring[I]];
    If(Q^.N=2)and((Q^.Mn='mov')or(Q^.Mn='movsxd'))and(Q^.Op[0].Kind=OK_REG)and(Q^.Op[0].Reg=RegR)and
      (Q^.Op[1].Kind=OK_MEM)and(Q^.Op[1].Index>=0)and(Q^.Op[1].Base>=0)and(Q^.Op[1].Base<16)and(Q^.Op[1].Scale=1)Then Begin
     Found:=False;
     LoadAddr:=0;IdxReg:=-1;
     For K:=I-1 downto 0 do Begin
      Q:=@Ins^[Ring[K]];
      If(Q^.Mn='lea')and(Q^.N=2)and(Q^.Op[1].Kind=OK_MEM)and(Q^.Op[1].Base<0)and(Q^.Op[1].Index>=0)and
        (Q^.Op[1].Scale=4)and(Q^.Op[1].Disp=0)and((Q^.Op[0].Reg=Ins^[Ring[I]].Op[1].Base)or
        (Q^.Op[0].Reg=Ins^[Ring[I]].Op[1].Index))Then Begin
       IdxReg:=Q^.Op[1].Index;IdxSz:=Q^.Op[1].ASize;LoadAddr:=Q^.Addr;Break;
      End;
     End;
     If IdxReg>=0 Then Begin
      For K:=RingN-1 downto 0 do Begin
       Q:=@Ins^[Ring[K]];
       If(Q^.Mn='lea')and(Q^.N=2)and(Q^.Op[0].Reg=RegB)and(Q^.Op[1].Kind=OK_MEM)and(Q^.Op[1].Base=16)Then Begin
        Tbl:=Q^.Op[1].Disp;BaseV:=Tbl;EntSz:=4;Rel:=True;Found:=True;Break;
       End;
      End;
     End;
     Break;
    End;
   End;
  End;
 End;
 If not Found Then Exit;
 If not IsMapped(Tbl)Then Exit;
 If BoundN>0 Then Cnt:=BoundN Else Cnt:=256;
 Bad:=False;
 K:=0;
 While K<Cnt do Begin
  If EntSz=8 Then E:=RdQWord(Tbl+K*8)
  Else If Rel Then Begin
   E:=RdDWord(Tbl+K*4);
   If E>=$80000000 Then E:=E-Int64($100000000);
  End
  Else E:=RdDWord(Tbl+K*4);
  If Rel Then T:=BaseV+E Else T:=E;
  If CpuMode=32 Then T:=T and $FFFFFFFF;
  If(not IsExecAddr(T))or(GetIns(T)<0)Then Begin
   If BoundN>0 Then Bad:=True;
   Break;
  End;
  SwTab[NSwRec,K]:=T;
  Inc(K);
 End;
 If Bad or(K<2)Then Exit;
 SwInsAddr[NSwRec]:=P^.Addr;SwLoadAddr[NSwRec]:=LoadAddr;
 SwIdxReg[NSwRec]:=IdxReg;SwIdxSz[NSwRec]:=IdxSz;SwCnt[NSwRec]:=K;
 Inc(NSwRec);
 TryJumpTable:=True;
End;

{ ---- exploration d'une fonction ---- }
Function IsExternalTarget(T:Int64):Boolean;
Begin
 IsExternalTarget:=(T<>FnEntry)and(IsRoot(T)or IsThunkAddr(T)or not IsExecAddr(T));
End;

Procedure SortFnIns(L,R:LongInt);
Var I,J:LongInt;P:Int64;T:LongInt;
Begin
 While L<R do Begin
  I:=L;J:=R;P:=Ins^[FnIns^[(L+R)div 2]].Addr;
  Repeat
   While Ins^[FnIns^[I]].Addr<P do Inc(I);
   While Ins^[FnIns^[J]].Addr>P do Dec(J);
   If I<=J Then Begin
    T:=FnIns^[I];FnIns^[I]:=FnIns^[J];FnIns^[J]:=T;
    Inc(I);Dec(J);
   End;
  Until I>J;
  If J-L<R-I Then Begin SortFnIns(L,J);L:=I;End
  Else Begin SortFnIns(I,R);R:=J;End;
 End;
End;

Function FindBlock(A:Int64):LongInt;
Var Lo,Hi,Mid:LongInt;
Begin
 Lo:=0;Hi:=NB-1;
 While Lo<=Hi do Begin
  Mid:=(Lo+Hi)div 2;
  If BStart[Mid]=A Then Begin FindBlock:=Mid;Exit;End;
  If BStart[Mid]<A Then Lo:=Mid+1 Else Hi:=Mid-1;
 End;
 FindBlock:=-1;
End;

{ Index (dans FnIns) de la derniere instruction du bloc B }
Function BLast(B:LongInt):LongInt;
Begin
 BLast:=FnIns^[BI0[B]+BN[B]-1];
End;

Procedure MarkLeader(A:Int64);
Var X:LongInt;
Begin
 X:=GetIns(A);
 If X>=0 Then LdrMark^[X]:=FnStamp;
End;

Procedure ExploreFn(Entry:Int64;CollectRoots:Boolean);
Var
 Stack:Array[0..8191] of Int64;
 SP:LongInt;
 A,T,NA:Int64;
 X,I,K,Cur,Tj:LongInt;
 Stop:Boolean;
 P:^TInsn;
 NewBlk:Boolean;
 Last:^TInsn;
Begin
 Inc(FnStamp);
 FnEntry:=Entry;
 NFnIns:=0;NB:=0;FnTrunc:=False;NSwRec:=0;NSd:=0;NSw:=0;
 SP:=0;
 Stack[SP]:=Entry;Inc(SP);
 MarkLeader(Entry);
 While SP>0 do Begin
  Dec(SP);
  A:=Stack[SP];
  Stop:=False;
  RingN:=0;
  While not Stop do Begin
   X:=GetIns(A);
   If X<0 Then Break;
   If Mark^[X]=FnStamp Then Break;
   If NFnIns>=MAXFNINS Then Begin FnTrunc:=True;Break;End;
   Mark^[X]:=FnStamp;
   FnIns^[NFnIns]:=X;Inc(NFnIns);
   P:=@Ins^[X];
   If RingN>=16 Then Begin
    For K:=0 to 14 do Ring[K]:=Ring[K+1];
    RingN:=15;
   End;
   Ring[RingN]:=X;Inc(RingN);
   If not P^.Valid Then Break;
   NA:=A+P^.Len;
   Case P^.Flow of
    FL_NORMAL:A:=NA;
    FL_CALL:Begin
     If CollectRoots Then AddRoot(P^.Target);
     If IsNoReturnName(SymName(P^.Target))Then Break;
     A:=NA;
    End;
    FL_ICALL:Begin
     If IsNoRetCall(P^)Then Break;
     A:=NA;
    End;
    FL_JMP:Begin
     T:=P^.Target;
     If not IsExternalTarget(T)Then Begin
      MarkLeader(T);
      If SP<8190 Then Begin Stack[SP]:=T;Inc(SP);End;
     End
     Else If CollectRoots Then AddRoot(T);
     Break;
    End;
    FL_JCC:Begin
     T:=P^.Target;
     If not IsExternalTarget(T)Then Begin
      MarkLeader(T);
      If SP<8190 Then Begin Stack[SP]:=T;Inc(SP);End;
     End
     Else If CollectRoots Then AddRoot(T);
     MarkLeader(NA);
     A:=NA;
    End;
    FL_IJMP:Begin
     If TryJumpTable(X)Then Begin
      K:=SwRecFor(P^.Addr);
      For I:=0 to SwCnt[K]-1 do Begin
       MarkLeader(SwTab[K,I]);
       If SP<8190 Then Begin Stack[SP]:=SwTab[K,I];Inc(SP);End;
      End;
     End;
     Break;
    End;
    Else Break;      { ret, hlt }
   End;
  End;
 End;
 If NFnIns=0 Then Exit;
 SortFnIns(0,NFnIns-1);
 { decoupage en blocs }
 Cur:=-1;
 For I:=0 to NFnIns-1 do Begin
  X:=FnIns^[I];
  NewBlk:=(I=0)or(LdrMark^[X]=FnStamp);
  If not NewBlk Then Begin
   Last:=@Ins^[FnIns^[I-1]];
   If(Last^.Addr+Last^.Len<>Ins^[X].Addr)or(Last^.Flow in[FL_JMP,FL_RET,FL_IJMP,FL_HALT])or
     not Last^.Valid or IsNoRetCall(Last^)Then NewBlk:=True;
  End;
  If NewBlk Then Begin
   If NB>=MAXBLK Then Begin FnTrunc:=True;Break;End;
   Cur:=NB;Inc(NB);
   BStart[Cur]:=Ins^[X].Addr;BI0[Cur]:=I;BN[Cur]:=0;
  End;
  Inc(BN[Cur]);
  BEndA[Cur]:=Ins^[X].Addr+Ins^[X].Len;
 End;
 { successeurs }
 For I:=0 to NB-1 do Begin
  BS0[I]:=-1;BS1[I]:=-1;BTgt[I]:=0;BExt0[I]:=False;
  Last:=@Ins^[BLast(I)];
  NA:=Last^.Addr+Last^.Len;
  If not Last^.Valid Then Begin BKind[I]:=BK_HALT;Continue;End;
  Case Last^.Flow of
   FL_JMP:Begin
    T:=Last^.Target;K:=FindBlock(T);
    If K>=0 Then Begin BKind[I]:=BK_JMP;BS0[I]:=K;End
    Else Begin BKind[I]:=BK_TAIL;BTgt[I]:=T;End;
   End;
   FL_JCC:Begin
    BKind[I]:=BK_JCC;
    T:=Last^.Target;K:=FindBlock(T);
    BS0[I]:=K;
    If K<0 Then Begin BExt0[I]:=True;BTgt[I]:=T;End;
    BS1[I]:=FindBlock(NA);
   End;
   FL_RET:BKind[I]:=BK_RET;
   FL_IJMP:Begin
    BKind[I]:=BK_IJMP;
    K:=SwRecFor(Last^.Addr);
    If K>=0 Then Begin
     BKind[I]:=BK_SWITCH;
     BSwS[I]:=NSw;BSwN[I]:=SwCnt[K];BSdS[I]:=NSd;BSdN[I]:=0;
     For Tj:=0 to SwCnt[K]-1 do Begin
      Cur:=FindBlock(SwTab[K,Tj]);
      If NSw<MAXSW Then Begin SwPool[NSw]:=Cur;Inc(NSw);End;
      If Cur>=0 Then Begin
       Stop:=False;
       For X:=BSdS[I] to NSd-1 do If SdPool[X]=Cur Then Stop:=True;
       If not Stop and(NSd<MAXSW)Then Begin SdPool[NSd]:=Cur;Inc(NSd);Inc(BSdN[I]);End;
      End;
     End;
     If BSdN[I]=0 Then BKind[I]:=BK_IJMP;
    End;
   End;
   FL_HALT:BKind[I]:=BK_HALT;
   Else Begin
    If IsNoRetCall(Last^)Then BKind[I]:=BK_HALT
    Else Begin
     K:=FindBlock(NA);
     If K>=0 Then Begin BKind[I]:=BK_FALL;BS0[I]:=K;End
     Else BKind[I]:=BK_HALT;
    End;
   End;
  End;
 End;
 If CollectRoots Then
  For I:=0 to NFnIns-1 do CoverAddr(Ins^[FnIns^[I]].Addr,Ins^[FnIns^[I]].Len);
End;

{ appel d'un stub PLT dont le nom designe une fonction de l'image : renvoie cette fonction }
Function ThunkDest(A:Int64):Int64;
Var I:LongInt;
Begin
 ThunkDest:=A;
 For I:=0 to NThk-1 do
  If ThkSrc[I]=A Then Begin ThunkDest:=ThkDst[I];Exit;End;
End;

{ ---- PLT : nomme les stubs d'importation ---- }
Procedure DiscoverPlt;
Var
 S:LongInt;
 A,EndA,Slot:Int64;
 X:LongInt;
 P:^TInsn;
 Nm:String;
 PrevEndbr:Boolean;
Begin
 If not(CpuMode in[32,64])Then Exit;
 If NImp=0 Then Exit;
 For S:=0 to NSeg-1 do Begin
  If(Segs[S].Name<>'.plt')and(Segs[S].Name<>'.plt.sec')and(Segs[S].Name<>'.plt.got')Then Continue;
  A:=Segs[S].Addr;EndA:=A+Segs[S].Size;
  PrevEndbr:=False;
  While A<EndA do Begin
   X:=GetIns(A);
   If X<0 Then Break;
   P:=@Ins^[X];
   If not P^.Valid Then Begin Inc(A);Continue;End;
   If P^.Mn='endbr64' Then PrevEndbr:=True
   Else Begin
    Nm:=ThunkImportName(P^);
    If Nm<>''Then Begin
     If PrevEndbr Then AddSym(Nm,A-4,16,SK_THUNK) Else AddSym(Nm,A,P^.Len,SK_THUNK);
    End;
    PrevEndbr:=False;
   End;
   A:=A+P^.Len;
  End;
 End;

 { stubs dont le nom correspond a une fonction definie dans l'image (bibliotheque partagee) }
 NThk:=0;
 For S:=0 to NSym-1 do
  If(Syms[S].Kind=SK_THUNK)and(NThk<4096)Then
   For X:=0 to NSym-1 do
    If(Syms[X].Kind in[SK_FUNC,SK_EXPORT])and(Syms[X].Addr<>Syms[S].Addr)and(Syms[X].Name=Syms[S].Name)and
      IsExecAddr(Syms[X].Addr)Then Begin
     ThkSrc[NThk]:=Syms[S].Addr;ThkDst[NThk]:=Syms[X].Addr;Inc(NThk);Break;
    End;
End;


{ ---- decouverte globale ---- }
Procedure ScanEntryRefs;
Var X:LongInt;I:Integer;P:^TInsn;
Begin
 { fonction d'entree : adresses de code chargees dans des registres ou empilees }
 ExploreFn(EntryAddr,False);
 For X:=0 to NFnIns-1 do Begin
  P:=@Ins^[FnIns^[X]];
  For I:=0 to P^.N-1 do Begin
   If(P^.Op[I].Kind=OK_IMM)and(P^.Mn<>'int')and(P^.Op[I].Disp>$1000)and IsExecAddr(P^.Op[I].Disp)Then
    AddRoot(P^.Op[I].Disp)
   Else If(P^.Op[I].Kind=OK_MEM)and(P^.Mn='lea')and(P^.Op[I].Base=16)and IsExecAddr(P^.Op[I].Disp)Then
    AddRoot(P^.Op[I].Disp);
  End;
 End;
End;

Procedure ScanPrologues;
Var
 S:LongInt;
 A,EndA:Int64;
 B0,B1,B2,B3:Byte;
 Found:Boolean;
Begin
 For S:=0 to NSeg-1 do Begin
  If(Segs[S].Flags and SF_EXEC)=0 Then Continue;
  If Segs[S].Cov=Nil Then Continue;
  A:=Segs[S].Addr;EndA:=A+Segs[S].Size-4;
  While A<EndA do Begin
   If not IsCovered(A)Then Begin
    ReadB(A,B0);ReadB(A+1,B1);ReadB(A+2,B2);ReadB(A+3,B3);
    Found:=False;
    If CpuMode=64 Then Begin
     If(B0=$F3)and(B1=$0F)and(B2=$1E)and(B3=$FA)Then Found:=True;
     If(B0=$55)and(B1=$48)and(B2=$89)and(B3=$E5)Then Found:=True;
    End
    Else If CpuMode=32 Then Begin
     If(B0=$F3)and(B1=$0F)and(B2=$1E)and(B3=$FB)Then Found:=True;
     If(B0=$55)and(((B1=$89)and(B2=$E5))or((B1=$8B)and(B2=$EC)))Then Found:=True;
    End;
    If Found Then AddRoot(A);
   End;
   Inc(A);
  End;
 End;
End;

Procedure DiscoverFunctions;
Var I,Round:LongInt;Pass:Integer;
Begin
 Verbose('recherche des fonctions...');
 For I:=0 to NSeg-1 do
  If((Segs[I].Flags and SF_EXEC)<>0)and(Segs[I].Size>0)Then Begin
   GetMem(Segs[I].Cov,Segs[I].Size+1);
   FillChar(Segs[I].Cov^,Segs[I].Size+1,0);
  End;
 PrepSyms;
 For I:=0 to NSym-1 do
  If(Syms[I].Kind in[SK_FUNC,SK_EXPORT,SK_ENTRY])Then AddRoot(Syms[I].Addr);
 If EntryAddr<>0 Then Begin
  AddRoot(EntryAddr);
  ScanEntryRefs;
 End;
 For Pass:=0 to 1 do Begin
  Round:=0;
  Repeat
   RootsChanged:=False;
   I:=0;
   While I<NRoot do Begin
    ExploreFn(RootAddr[I],True);
    Inc(I);
   End;
   Inc(Round);
  Until not RootsChanged or(Round>=6);
  If Pass=0 Then ScanPrologues;
 End;
 SortRoots(0,NRoot-1);
 RebuildRootHash;
 Verbose(LStr(NRoot)+' fonction(s) trouvee(s)');
End;

{ ============================================================
  REPRESENTATION INTERMEDIAIRE (IR)
  ============================================================ }
Const
 MAXEXPR = 500000;
 MAXSTMT = 300000;
 MAXNAME = 2048;

 { Operateurs d'expression }
 EO_CONST=1;  EO_REG=2;   EO_VAR=3;   EO_MEM=4;   EO_ADD=5;   EO_SUB=6;
 EO_MUL=7;    EO_SDIV=8;  EO_UDIV=9;  EO_SMOD=10; EO_UMOD=11; EO_AND=12;
 EO_OR=13;    EO_XOR=14;  EO_SHL=15;  EO_SHR=16;  EO_SAR=17;  EO_NEG=18;
 EO_NOT=19;   EO_LNOT=20; EO_ZEXT=21; EO_SEXT=22; EO_TRUNC=23;
 EO_EQ=24;    EO_NE=25;   EO_SLT=26;  EO_SLE=27;  EO_SGT=28;  EO_SGE=29;
 EO_ULT=30;   EO_ULE=31;  EO_UGT=32;  EO_UGE=33;  EO_CC=34;   EO_TERN=35;
 EO_CALL=36;  EO_LIST=37; EO_INTR=38; EO_ROL=39;  EO_ROR=40;  EO_SLOT=41;
 EO_ADDRSLOT=42; EO_LAND=43; EO_LOR=44;

 { Statements }
 ST_NOP=0;    ST_ASSIGN=1; ST_STORE=2; ST_FLAGS=3; ST_PUSH=4;  ST_POP=5;
 ST_EXPR=6;   ST_ASM=7;
 ST_JMP=10;   ST_JCC=11;   ST_RET=12;  ST_IJMP=13; ST_HALT=14; ST_TAIL=15;

 { Types d'instructions pour les drapeaux }
 FK_CMP=1; FK_TEST=2; FK_ADD=3; FK_SUB=4; FK_LOGIC=5; FK_INC=6; FK_DEC=7;
 FK_NEG=8; FK_SHIFT=9; FK_FCMP=10; FK_OTHER=11; FK_BT=12;

 FLAGS_BIT = Int64(1) shl 32;

Type
 TExpr = Record
  Op:Byte;
  Sz:Byte;
  A,B,C:LongInt;
  V:Int64;
 End;
 TExprArr = Array[0..MAXEXPR-1] of TExpr;

 TStmt = Record
  Kind:Byte;
  FK:Byte;
  Sz:Byte;
  A,B:LongInt;
  Addr:Int64;
  Txt:LongInt;
 End;
 TStmtArr = Array[0..MAXSTMT-1] of TStmt;

Var
 Ex:^TExprArr;
 NEx:LongInt;
 St:^TStmtArr;
 NSt:LongInt;
 SB0,SBN:Array[0..MAXBLK-1] of LongInt;     { plage de statements par bloc }
 NameTab:Array[0..MAXNAME-1] of String[47];
 NName:LongInt;
 AsmTxt:Array[0..MAXNAME-1] of String[79];
 NAsm:LongInt;
 PtrSz:Integer;
 IgnoreMerge:Boolean;
 WideReg:Array[0..15] of Boolean;
 FnRetSz:Integer;

 { contexte de la fonction courante }
 CurBlk:LongInt;
 CurI:TInsn;
 TmpCount:LongInt;
 UsesFlagsRaw:Boolean;

Procedure InitIR;
Begin
 If Ex=Nil Then Begin
  GetMem(Ex,Int64(MAXEXPR)*SizeOf(TExpr));
  GetMem(St,Int64(MAXSTMT)*SizeOf(TStmt));
 End;
End;

Function NameIdx(Const S:String):LongInt;
Var I:LongInt;
Begin
 For I:=0 to NName-1 do
  If NameTab[I]=S Then Begin NameIdx:=I;Exit;End;
 If NName>=MAXNAME Then Begin NameIdx:=0;Exit;End;
 NameTab[NName]:=S;
 NameIdx:=NName;
 Inc(NName);
End;

Function NewEx(Op,Sz:Byte;A,B,C:LongInt;V:Int64):LongInt;
Begin
 If NEx>=MAXEXPR Then Begin
  { debordement : reutilise la derniere entree (sortie degradee) }
  NewEx:=MAXEXPR-1;Exit;
 End;
 Ex^[NEx].Op:=Op;Ex^[NEx].Sz:=Sz;Ex^[NEx].A:=A;Ex^[NEx].B:=B;Ex^[NEx].C:=C;Ex^[NEx].V:=V;
 NewEx:=NEx;
 Inc(NEx);
End;

Function SignExt(V:Int64;Sz:Integer):Int64;
Begin
 Case Sz of
  1:Begin V:=V and $FF;If V>=$80 Then V:=V-$100;End;
  2:Begin V:=V and $FFFF;If V>=$8000 Then V:=V-$10000;End;
  4:Begin V:=V and $FFFFFFFF;If V>=$80000000 Then V:=V-Int64($100000000);End;
 End;
 SignExt:=V;
End;

Function ZeroExt(V:Int64;Sz:Integer):Int64;
Begin
 Case Sz of
  1:V:=V and $FF;
  2:V:=V and $FFFF;
  4:V:=V and $FFFFFFFF;
 End;
 ZeroExt:=V;
End;

Function MkConst(V:Int64;Sz:Integer):LongInt;
Begin
 MkConst:=NewEx(EO_CONST,Sz,0,0,0,SignExt(V,Sz));
End;

Function MkRegRaw(R,Sz:Integer;Merge:Boolean):LongInt;
Begin
 MkRegRaw:=NewEx(EO_REG,Sz,R,Ord(Merge)*2,0,0);
End;

Function HomeSz:Integer;
Begin
 If CpuMode=16 Then HomeSz:=2 Else HomeSz:=4;
End;

{ taille du registre complet : 8 si le registre est aussi utilise sur 64 bits }
Function HomeOf(R:Integer):Integer;
Begin
 If(CpuMode=64)and(R<16)and(R>=0)and WideReg[R]Then HomeOf:=8 Else HomeOf:=HomeSz;
End;

Function MkVar(Const N:String;Sz:Integer):LongInt;
Begin
 MkVar:=NewEx(EO_VAR,Sz,NameIdx(N),0,0,0);
End;

Function MkMem(Addr:LongInt;Sz:Integer;Fp:Boolean):LongInt;
Begin
 MkMem:=NewEx(EO_MEM,Sz,Addr,Ord(Fp),0,0);
End;

Function IsConst(E:LongInt):Boolean;
Begin
 IsConst:=(E>=0)and(Ex^[E].Op=EO_CONST);
End;

Function SameExpr(A,B:LongInt):Boolean;
Begin
 SameExpr:=False;
 If A=B Then Begin SameExpr:=True;Exit;End;
 If(A<0)or(B<0)Then Exit;
 If(Ex^[A].Op<>Ex^[B].Op)or(Ex^[A].Sz<>Ex^[B].Sz)Then Exit;
 Case Ex^[A].Op of
  EO_CONST:SameExpr:=Ex^[A].V=Ex^[B].V;
  EO_REG:SameExpr:=(Ex^[A].A=Ex^[B].A)and(Ex^[A].B=Ex^[B].B);
  EO_VAR:SameExpr:=Ex^[A].A=Ex^[B].A;
  EO_MEM:SameExpr:=SameExpr(Ex^[A].A,Ex^[B].A);
  EO_SLOT,EO_ADDRSLOT:SameExpr:=Ex^[A].V=Ex^[B].V;
  EO_CC:SameExpr:=Ex^[A].A=Ex^[B].A;
  EO_ADD,EO_SUB,EO_MUL,EO_SDIV,EO_UDIV,EO_SMOD,EO_UMOD,EO_AND,EO_OR,EO_XOR,EO_SHL,EO_SHR,
  EO_SAR,EO_ROL,EO_ROR,EO_EQ,EO_NE,EO_SLT,EO_SLE,EO_SGT,EO_SGE,EO_ULT,EO_ULE,EO_UGT,EO_UGE:
   SameExpr:=SameExpr(Ex^[A].A,Ex^[B].A)and SameExpr(Ex^[A].B,Ex^[B].B);
  EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:SameExpr:=SameExpr(Ex^[A].A,Ex^[B].A);
  Else SameExpr:=False;
 End;
End;

Function MkBin(Op:Byte;A,B:LongInt;Sz:Integer):LongInt;
Var V:Int64;X:LongInt;
Begin
 If(Op in[EO_AND,EO_OR,EO_XOR,EO_MUL])and IsConst(A)and not IsConst(B)Then Begin X:=A;A:=B;B:=X;End;
 If(Op=EO_OR)and IsConst(B)and(Sz in[1,2,4,8])Then Begin
  If(Sz=8)and(Ex^[B].V=-1)Then Begin MkBin:=B;Exit;End;
  If(Sz<8)and((Ex^[B].V and(Int64(1)shl(8*Sz)-1))=(Int64(1)shl(8*Sz)-1))Then Begin MkBin:=MkConst(-1,Sz);Exit;End;
 End;
 If(Op=EO_AND)and IsConst(B)Then Begin
  If Ex^[B].V=0 Then Begin MkBin:=MkConst(0,Sz);Exit;End;
  If(Sz in[1,2,4])and((Ex^[B].V and(Int64(1)shl(8*Sz)-1))=(Int64(1)shl(8*Sz)-1))Then Begin MkBin:=A;Exit;End;
  If(Sz=8)and(Ex^[B].V=-1)Then Begin MkBin:=A;Exit;End;
 End;
 { simplifications simples }
 If(Op=EO_SUB)and IsConst(B)Then Begin
  Op:=EO_ADD;B:=MkConst(-Ex^[B].V,Sz);
 End;
 If IsConst(A)and IsConst(B)Then Begin
  V:=0;
  Case Op of
   EO_ADD:V:=Ex^[A].V+Ex^[B].V;
   EO_SUB:V:=Ex^[A].V-Ex^[B].V;
   EO_MUL:V:=Ex^[A].V*Ex^[B].V;
   EO_AND:V:=Ex^[A].V and Ex^[B].V;
   EO_OR:V:=Ex^[A].V or Ex^[B].V;
   EO_XOR:V:=Ex^[A].V xor Ex^[B].V;
   EO_SHL:V:=Ex^[A].V shl(Ex^[B].V and 63);
   Else Begin MkBin:=NewEx(Op,Sz,A,B,0,0);Exit;End;
  End;
  MkBin:=MkConst(V,Sz);Exit;
 End;
 If Op=EO_ADD Then Begin
  If IsConst(A)and not IsConst(B)Then Begin X:=A;A:=B;B:=X;End;
  If IsConst(B)and(Ex^[A].Op=EO_ADDRSLOT)Then Begin
   MkBin:=NewEx(EO_ADDRSLOT,Ex^[A].Sz,0,0,0,Ex^[A].V+Ex^[B].V);Exit;
  End;
  If IsConst(B)Then Begin
   If Ex^[B].V=0 Then Begin MkBin:=A;Exit;End;
   If(Ex^[A].Op=EO_ADD)and IsConst(Ex^[A].B)Then Begin
    MkBin:=MkBin(EO_ADD,Ex^[A].A,MkConst(Ex^[A].B*0+Ex^[Ex^[A].B].V+Ex^[B].V,Sz),Sz);Exit;
   End;
  End;
 End;
 If(Op in[EO_OR,EO_XOR,EO_SHL,EO_SHR,EO_SAR])and IsConst(B)and(Ex^[B].V=0)Then Begin MkBin:=A;Exit;End;
 If(Op=EO_MUL)and IsConst(B)and(Ex^[B].V=1)Then Begin MkBin:=A;Exit;End;
 If(Op=EO_XOR)and SameExpr(A,B)Then Begin MkBin:=MkConst(0,Sz);Exit;End;
 If(Op=EO_SUB)and SameExpr(A,B)Then Begin MkBin:=MkConst(0,Sz);Exit;End;
 MkBin:=NewEx(Op,Sz,A,B,0,0);
End;

Function ExSz(E:LongInt):Integer;
Begin
 ExSz:=0;
 If E<0 Then Exit;
 If Ex^[E].Op in[EO_EQ..EO_UGE,EO_CC,EO_LAND,EO_LOR,EO_LNOT]Then ExSz:=1
 Else ExSz:=Ex^[E].Sz;
End;

Function MkUn(Op:Byte;A:LongInt;Sz:Integer):LongInt;
Var Inner:LongInt;
Begin
 If(Op=EO_TRUNC)and(Ex^[A].Op in[EO_AND,EO_OR,EO_XOR])Then Begin
  MkUn:=MkBin(Ex^[A].Op,MkUn(EO_TRUNC,Ex^[A].A,Sz),MkUn(EO_TRUNC,Ex^[A].B,Sz),Sz);
  Exit;
 End;
 If(Op=EO_TRUNC)and IsConst(A)Then Begin MkUn:=MkConst(Ex^[A].V,Sz);Exit;End;
 If Op=EO_TRUNC Then Begin
  If ExSz(A)=Sz Then Begin MkUn:=A;Exit;End;
  If Ex^[A].Op=EO_TRUNC Then Begin MkUn:=MkUn(EO_TRUNC,Ex^[A].A,Sz);Exit;End;
  If Ex^[A].Op in[EO_ZEXT,EO_SEXT]Then Begin
   Inner:=Ex^[A].A;
   If ExSz(Inner)>=Sz Then Begin MkUn:=MkUn(EO_TRUNC,Inner,Sz);Exit;End;
  End;
 End;
 If(Op=EO_ZEXT)and(ExSz(A)>=Sz)and not IsConst(A)Then Begin MkUn:=A;Exit;End;
 If(Op=EO_SEXT)and(ExSz(A)>=Sz)and not IsConst(A)Then Begin MkUn:=A;Exit;End;
 If(Op=EO_ZEXT)and(Ex^[A].Op=EO_ZEXT)Then Begin MkUn:=NewEx(EO_ZEXT,Sz,Ex^[A].A,0,0,0);Exit;End;
 If(Op=EO_NEG)and IsConst(A)Then Begin MkUn:=MkConst(-Ex^[A].V,Sz);Exit;End;
 If(Op=EO_NOT)and IsConst(A)Then Begin MkUn:=MkConst(not Ex^[A].V,Sz);Exit;End;
 If(Op=EO_ZEXT)and IsConst(A)Then Begin MkUn:=MkConst(ZeroExt(Ex^[A].V,Ex^[A].Sz),Sz);Exit;End;
 If(Op=EO_SEXT)and IsConst(A)Then Begin MkUn:=MkConst(Ex^[A].V,Sz);Exit;End;
 MkUn:=NewEx(Op,Sz,A,0,0,0);
End;

{ lecture d'un registre : les registres partiels sont des vues du registre complet }
Function MkReg(R,Sz:Integer;Hi:Boolean):LongInt;
Var H:Integer;
Begin
 H:=HomeOf(R);
 If R>=16 Then Begin MkReg:=MkRegRaw(R,Sz,False);Exit;End;
 If Hi Then MkReg:=MkUn(EO_TRUNC,MkBin(EO_SHR,MkRegRaw(R,H,False),MkConst(8,1),H),1)
 Else If Sz<H Then MkReg:=MkUn(EO_TRUNC,MkRegRaw(R,H,False),Sz)
 Else MkReg:=MkRegRaw(R,Sz,False);
End;

Function MkCC(CC:Integer):LongInt;
Begin
 MkCC:=NewEx(EO_CC,1,CC,0,0,0);
End;

Function MkList(Item,Next:LongInt):LongInt;
Begin
 MkList:=NewEx(EO_LIST,0,Item,Next,0,0);
End;

Function MkIntr(Const N:String;Args:LongInt;Sz:Integer):LongInt;
Begin
 MkIntr:=NewEx(EO_INTR,Sz,NameIdx(N),Args,0,0);
End;

Function ListLen(L:LongInt):LongInt;
Var N:LongInt;
Begin
 N:=0;
 While L>=0 do Begin Inc(N);L:=Ex^[L].B;End;
 ListLen:=N;
End;

{ nombre de noeuds (plafonne a Lim) }
Function ExprNodes(E:LongInt;Lim:LongInt):LongInt;
Var N:LongInt;
Begin
 ExprNodes:=0;
 If(E<0)or(Lim<=0)Then Exit;
 N:=1;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_REG,EO_CC,EO_SLOT,EO_ADDRSLOT:;
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:N:=N+ExprNodes(Ex^[E].A,Lim-1);
  EO_TERN:N:=N+ExprNodes(Ex^[E].A,Lim-1)+ExprNodes(Ex^[E].B,Lim-1)+ExprNodes(Ex^[E].C,Lim-1);
  EO_INTR:N:=N+ExprNodes(Ex^[E].B,Lim-1);
  Else N:=N+ExprNodes(Ex^[E].A,Lim-1)+ExprNodes(Ex^[E].B,Lim-1);
 End;
 If N>Lim Then N:=Lim;
 ExprNodes:=N;
End;

{ ---------- analyse d'une expression ---------- }
Function ExprUses(E:LongInt):Int64;
Var M:Int64;
Begin
 ExprUses:=0;
 If E<0 Then Exit;
 M:=0;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_SLOT,EO_ADDRSLOT:M:=0;
  EO_REG:If not(IgnoreMerge and(Ex^[E].B=2))Then M:=Int64(1)shl Ex^[E].A;
  EO_CC:M:=FLAGS_BIT;
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:M:=ExprUses(Ex^[E].A);
  EO_TERN:M:=ExprUses(Ex^[E].A)or ExprUses(Ex^[E].B)or ExprUses(Ex^[E].C);
  EO_CALL:M:=ExprUses(Ex^[E].A)or ExprUses(Ex^[E].B);
  EO_LIST:M:=ExprUses(Ex^[E].A)or ExprUses(Ex^[E].B);
  EO_INTR:M:=ExprUses(Ex^[E].B);
  Else M:=ExprUses(Ex^[E].A)or ExprUses(Ex^[E].B);
 End;
 ExprUses:=M;
End;

Function ExprHasMem(E:LongInt):Boolean;
Begin
 ExprHasMem:=False;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_REG,EO_CC,EO_ADDRSLOT:Exit;
  EO_MEM,EO_SLOT:ExprHasMem:=True;
  EO_TERN:ExprHasMem:=ExprHasMem(Ex^[E].A)or ExprHasMem(Ex^[E].B)or ExprHasMem(Ex^[E].C);
  EO_CALL:ExprHasMem:=True;
  EO_INTR:ExprHasMem:=ExprHasMem(Ex^[E].B);
  EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:ExprHasMem:=ExprHasMem(Ex^[E].A);
  Else ExprHasMem:=ExprHasMem(Ex^[E].A)or ExprHasMem(Ex^[E].B);
 End;
End;

Function ExprHasCall(E:LongInt):Boolean;
Begin
 ExprHasCall:=False;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_REG,EO_CC,EO_ADDRSLOT,EO_SLOT:Exit;
  EO_CALL:ExprHasCall:=True;
  EO_TERN:ExprHasCall:=ExprHasCall(Ex^[E].A)or ExprHasCall(Ex^[E].B)or ExprHasCall(Ex^[E].C);
  EO_INTR:ExprHasCall:=ExprHasCall(Ex^[E].B);
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:ExprHasCall:=ExprHasCall(Ex^[E].A);
  Else ExprHasCall:=ExprHasCall(Ex^[E].A)or ExprHasCall(Ex^[E].B);
 End;
End;

Function ExprHasCC(E:LongInt):Boolean;
Begin
 ExprHasCC:=(ExprUses(E)and FLAGS_BIT)<>0;
End;

{ Nombre d'occurrences du registre canonique R dans E }
Function CountReg(E:LongInt;R:Integer):LongInt;
Begin
 CountReg:=0;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_CC,EO_ADDRSLOT,EO_SLOT:Exit;
  EO_REG:If Ex^[E].A=R Then CountReg:=1;
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:CountReg:=CountReg(Ex^[E].A,R);
  EO_TERN:CountReg:=CountReg(Ex^[E].A,R)+CountReg(Ex^[E].B,R)+CountReg(Ex^[E].C,R);
  EO_CALL,EO_LIST:CountReg:=CountReg(Ex^[E].A,R)+CountReg(Ex^[E].B,R);
  EO_INTR:CountReg:=CountReg(Ex^[E].B,R);
  Else CountReg:=CountReg(Ex^[E].A,R)+CountReg(Ex^[E].B,R);
 End;
End;

{ Taille du premier acces au registre canonique R dans E (0 si absent) }
Function RegSizeIn(E:LongInt;R:Integer):Integer;
Var X:Integer;
Begin
 RegSizeIn:=0;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_CONST,EO_VAR,EO_CC,EO_ADDRSLOT,EO_SLOT:Exit;
  EO_REG:If Ex^[E].A=R Then Begin
   If Ex^[E].B=1 Then RegSizeIn:=-1 Else RegSizeIn:=Ex^[E].Sz;
  End;
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:RegSizeIn:=RegSizeIn(Ex^[E].A,R);
  EO_TERN:Begin
   X:=RegSizeIn(Ex^[E].A,R);
   If X=0 Then X:=RegSizeIn(Ex^[E].B,R);
   If X=0 Then X:=RegSizeIn(Ex^[E].C,R);
   RegSizeIn:=X;
  End;
  EO_CALL,EO_LIST:Begin
   X:=RegSizeIn(Ex^[E].A,R);
   If X=0 Then X:=RegSizeIn(Ex^[E].B,R);
   RegSizeIn:=X;
  End;
  EO_INTR:RegSizeIn:=RegSizeIn(Ex^[E].B,R);
  Else Begin
   X:=RegSizeIn(Ex^[E].A,R);
   If X=0 Then X:=RegSizeIn(Ex^[E].B,R);
   RegSizeIn:=X;
  End;
 End;
End;

{ Remplace les lectures du registre canonique R (taille DefSz) par Repl }
Function SubstReg(E:LongInt;R,DefSz:Integer;Repl:LongInt):LongInt;
Var A,B,C,Rr:LongInt;T:TExpr;
Begin
 SubstReg:=E;
 If E<0 Then Exit;
 T:=Ex^[E];
 Case T.Op of
  EO_CONST,EO_VAR,EO_CC,EO_ADDRSLOT,EO_SLOT:Exit;
  EO_REG:Begin
   If(T.A=R)and(T.B<>1)Then Begin
    If T.Sz=DefSz Then SubstReg:=Repl
    Else If T.Sz<DefSz Then SubstReg:=MkUn(EO_TRUNC,Repl,T.Sz)
    Else If(DefSz=4)and(CpuMode=64)Then SubstReg:=MkUn(EO_ZEXT,Repl,T.Sz);
   End;
   Exit;
  End;
 End;
 A:=T.A;B:=T.B;C:=T.C;
 Case T.Op of
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:A:=SubstReg(T.A,R,DefSz,Repl);
  EO_TERN:Begin A:=SubstReg(T.A,R,DefSz,Repl);B:=SubstReg(T.B,R,DefSz,Repl);C:=SubstReg(T.C,R,DefSz,Repl);End;
  EO_INTR:B:=SubstReg(T.B,R,DefSz,Repl);
  Else Begin A:=SubstReg(T.A,R,DefSz,Repl);B:=SubstReg(T.B,R,DefSz,Repl);End;
 End;
 If(A=T.A)and(B=T.B)and(C=T.C)Then Exit;
 Case T.Op of
  EO_ADD,EO_MUL,EO_AND,EO_OR,EO_XOR,EO_SHL,EO_SHR,EO_SAR:Rr:=MkBin(T.Op,A,B,T.Sz);
  EO_TRUNC,EO_ZEXT,EO_SEXT,EO_NEG,EO_NOT:Rr:=MkUn(T.Op,A,T.Sz);
  Else Rr:=NewEx(T.Op,T.Sz,A,B,C,T.V);
 End;
 SubstReg:=Rr;
End;

{ ============================================================
  EMISSION DE STATEMENTS
  ============================================================ }
Procedure Emit(Kind:Byte;A,B:LongInt);
Begin
 If NSt>=MAXSTMT Then Exit;
 St^[NSt].Kind:=Kind;St^[NSt].FK:=0;St^[NSt].Sz:=0;
 St^[NSt].A:=A;St^[NSt].B:=B;St^[NSt].Txt:=-1;
 St^[NSt].Addr:=CurI.Addr;
 Inc(NSt);
End;

Procedure EmitFlags(FK:Byte;A,B:LongInt;Sz:Integer);
Begin
 If NSt>=MAXSTMT Then Exit;
 Emit(ST_FLAGS,A,B);
 St^[NSt-1].FK:=FK;St^[NSt-1].Sz:=Sz;
End;

Procedure EmitAsm;
Var K:Integer;M:Int64;
Begin
 If NAsm<MAXNAME Then Begin
  AsmTxt[NAsm]:=Copy(FmtInsn(CurI),1,79);
  { registres lus par l'instruction : -1 = tous }
  M:=0;
  If CurI.N=0 Then M:=-1
  Else
   For K:=0 to CurI.N-1 do Begin
    If(CurI.Op[K].Kind=OK_REG)and(CurI.Op[K].Cls=RC_GPR)and(CurI.Op[K].Reg>=0)Then M:=M or(Int64(1)shl CurI.Op[K].Reg);
    If(CurI.Op[K].Kind=OK_REG)and(CurI.Op[K].Cls=RC_XMM)Then M:=M or(Int64(1)shl(16+(CurI.Op[K].Reg and 15)));
    If CurI.Op[K].Kind=OK_MEM Then Begin
     If(CurI.Op[K].Base>=0)and(CurI.Op[K].Base<16)Then M:=M or(Int64(1)shl CurI.Op[K].Base);
     If(CurI.Op[K].Index>=0)and(CurI.Op[K].Index<16)Then M:=M or(Int64(1)shl CurI.Op[K].Index);
    End;
    If CurI.Op[K].Cls in[RC_ST,RC_MMX,RC_CR,RC_DR,RC_SEG]Then M:=-1;
   End;
  Emit(ST_ASM,-1,0);
  If M=-1 Then St^[NSt-1].B:=-1 Else St^[NSt-1].B:=LongInt(M and $7FFFFFFF);
  St^[NSt-1].Txt:=NAsm;
  Inc(NAsm);
 End
 Else Emit(ST_NOP,0,0);
End;

{ ecriture d'un registre partiel : fusion dans le registre complet }
Procedure GprWrite(R,Sz:Integer;Hi:Boolean;V:LongInt);
Var H:Integer;Mask:Int64;Old,Keep,New_:LongInt;
Begin
 H:=HomeOf(R);
 If(Sz=4)and not Hi Then Begin
  { ecriture 32 bits dans un registre 64 bits : extension par zero }
  Emit(ST_ASSIGN,MkRegRaw(R,H,False),MkUn(EO_ZEXT,V,H));
  Exit;
 End;
 If Hi Then Mask:=$FF00 Else If Sz=1 Then Mask:=$FF Else Mask:=$FFFF;
 Old:=MkRegRaw(R,H,True);
 Keep:=MkBin(EO_AND,Old,MkConst(not Mask,H),H);
 New_:=MkUn(EO_ZEXT,V,H);
 If Hi Then New_:=MkBin(EO_SHL,New_,MkConst(8,1),H);
 Emit(ST_ASSIGN,MkRegRaw(R,H,False),MkBin(EO_OR,Keep,New_,H));
End;

Procedure Asg(Dst,Src:LongInt);
Var X:LongInt;
Begin
 If Ex^[Dst].Op=EO_TRUNC Then Begin
  X:=Ex^[Dst].A;
  If(Ex^[X].Op=EO_REG)and(Ex^[X].B<>2)and(Ex^[X].A<16)and(Ex^[X].Sz>Ex^[Dst].Sz)Then Begin
   GprWrite(Ex^[X].A,Ex^[Dst].Sz,False,Src);Exit;
  End;
  If(Ex^[X].Op=EO_SHR)and(Ex^[Ex^[X].A].Op=EO_REG)and IsConst(Ex^[X].B)Then Begin
   GprWrite(Ex^[Ex^[X].A].A,1,True,Src);Exit;
  End;
 End;
 If(Ex^[Dst].Op=EO_REG)and SameExpr(Dst,Src)and not((CpuMode=64)and(Ex^[Dst].Sz=4))Then Begin
  Emit(ST_NOP,0,0);Exit;
 End;
 If Ex^[Dst].Op=EO_MEM Then Emit(ST_STORE,Dst,Src) Else Emit(ST_ASSIGN,Dst,Src);
End;

{ ---------- signatures des fonctions ---------- }
Var
 SigMask:Array[0..MAXROOT-1] of LongInt;
 SigFp,SigStk:Array[0..MAXROOT-1] of ShortInt;
 SigPop:Array[0..MAXROOT-1] of LongInt;
 SigOk:Array[0..MAXROOT-1] of Boolean;
 SigRet:Array[0..MAXROOT-1] of ShortInt;   { 0 void, 4 / 8 entier, 16 flottant }

Function RootIdx(A:Int64):LongInt;
Var H:LongInt;
Begin
 RootIdx:=-1;
 H:=RootSlot(A);
 While RootHash^[H]>=0 do Begin
  If RootAddr[RootHash^[H]]=A Then Begin RootIdx:=RootHash^[H];Exit;End;
  H:=(H+1)and 262143;
 End;
End;


{ ============================================================
  LEVEE DES INSTRUCTIONS
  ============================================================ }
{ taille des constantes qui representent des adresses }
Function AddrSz:Integer;
Begin
 If CpuMode=16 Then AddrSz:=4 Else AddrSz:=PtrSz;
End;

Function AddrExpr(Const O:TOperand):LongInt;
Var T,Ix:LongInt;AS_:Integer;
Begin
 AS_:=O.ASize;
 If AS_=0 Then AS_:=PtrSz;
 If O.Base=16 Then Begin
  AddrExpr:=MkConst(O.Disp,PtrSz);Exit;
 End;
 T:=-1;
 If O.Base>=0 Then T:=MkReg(O.Base,AS_,False);
 If O.Index>=0 Then Begin
  Ix:=MkReg(O.Index,AS_,False);
  If O.Scale>1 Then Ix:=MkBin(EO_MUL,Ix,MkConst(O.Scale,AS_),AS_);
  If T<0 Then T:=Ix Else T:=MkBin(EO_ADD,T,Ix,AS_);
 End;
 If(O.Disp<>0)or(T<0)Then Begin
  If T<0 Then Begin
   If AS_=4 Then T:=MkConst(O.Disp and $FFFFFFFF,AS_+4*Ord(CpuMode=64))
   Else If AS_=2 Then T:=MkConst(O.Disp and $FFFF,4)
   Else T:=MkConst(O.Disp,AS_);
  End
  Else T:=MkBin(EO_ADD,T,MkConst(O.Disp,AS_),AS_);
 End;
 If O.Seg>=4 Then T:=MkBin(EO_ADD,MkVar(RSEG[O.Seg]+'_base',PtrSz),T,PtrSz);
 AddrExpr:=T;
End;

Function IsFloatMn(Const Mn:String):Boolean;
Var L:Integer;S:String;
Begin
 L:=Length(Mn);
 IsFloatMn:=False;
 If L<3 Then Exit;
 S:=Copy(Mn,L-1,2);
 If(S='ss')or(S='sd')or(S='ps')or(S='pd')Then IsFloatMn:=True;
End;

Function OpExpr(K:Integer):LongInt;
Var O:TOperand;Sz:Integer;
Begin
 O:=CurI.Op[K];
 Case O.Kind of
  OK_REG:Begin
   If O.Cls=RC_GPR Then OpExpr:=MkReg(O.Reg,O.Size,O.Hi)
   Else If O.Cls=RC_XMM Then OpExpr:=MkReg(16+(O.Reg and 15),16,False)
   Else OpExpr:=MkVar(RegName(O.Cls,O.Reg,O.Size,False),O.Size);
  End;
  OK_IMM:Begin
   Sz:=O.Size;
   If Sz=0 Then Sz:=CurI.OSize;
   OpExpr:=MkConst(O.Disp,Sz);
  End;
  OK_MEM:Begin
   Sz:=O.Size;
   If Sz=0 Then Sz:=PtrSz;
   OpExpr:=MkMem(AddrExpr(O),Sz,IsFloatMn(CurI.Mn)and(CurI.N>=2));
  End;
  OK_REL:OpExpr:=MkConst(O.Disp,AddrSz);
  Else OpExpr:=MkConst(0,4);
 End;
End;

Function OpSize(K:Integer):Integer;
Var Sz:Integer;
Begin
 Sz:=CurI.Op[K].Size;
 If(Sz=0)or(CurI.Op[K].Kind=OK_IMM)Then Sz:=CurI.OSize;
 If Sz=0 Then Sz:=4;
 OpSize:=Sz;
End;

Function StackPtr:LongInt;
Begin
 StackPtr:=MkReg(4,PtrSz,False);
End;

Function RetReg:LongInt;
Begin
 RetReg:=MkReg(0,PtrSz,False);
End;

Function IsGprOp(K:Integer):Boolean;
Begin
 IsGprOp:=(CurI.Op[K].Kind=OK_REG)and(CurI.Op[K].Cls=RC_GPR);
End;

Function IsXmmOp(K:Integer):Boolean;
Begin
 IsXmmOp:=(CurI.Op[K].Kind=OK_REG)and(CurI.Op[K].Cls=RC_XMM);
End;

Procedure LiftArith(Op:Byte;FK:Byte;Const Mn:String);
Var D,S,R:LongInt;Sz:Integer;
Begin
 Sz:=OpSize(0);
 D:=OpExpr(0);S:=OpExpr(1);
 If(Op=EO_XOR)and SameExpr(D,S)and(CurI.Op[0].Kind=OK_REG)Then Begin
  Asg(D,MkConst(0,Sz));
  EmitFlags(FK_LOGIC,D,S,Sz);
  Exit;
 End;
 If(Mn='sub')and SameExpr(D,S)and(CurI.Op[0].Kind=OK_REG)Then Begin
  Asg(D,MkConst(0,Sz));
  EmitFlags(FK_LOGIC,D,S,Sz);
  Exit;
 End;
 R:=MkBin(Op,D,S,Sz);
 Asg(D,R);
 EmitFlags(FK,D,S,Sz);
End;

Procedure LiftIns;
Var
 Mn:String;
 D,S,T,R,Args,Tgt:LongInt;
 Sz,K:Integer;
 O0,O1:TOperand;
 Z:LongInt;
Begin
 Mn:=CurI.Mn;
 Sz:=0;
 If CurI.N>0 Then Sz:=OpSize(0);
 If Mn='mov' Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  If CurI.Op[0].Cls=RC_SEG Then Begin EmitAsm;Exit;End;
  If CurI.Op[1].Cls=RC_SEG Then Begin EmitAsm;Exit;End;
  If(CurI.Op[0].Cls=RC_CR)or(CurI.Op[0].Cls=RC_DR)or(CurI.Op[1].Cls=RC_CR)or(CurI.Op[1].Cls=RC_DR)Then Begin
   EmitAsm;Exit;
  End;
  Asg(D,S);
 End
 Else If(Mn='movzx')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Asg(D,MkUn(EO_ZEXT,S,Sz));
 End
 Else If(Mn='movsx')or(Mn='movsxd')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Asg(D,MkUn(EO_SEXT,S,Sz));
 End
 Else If Mn='lea' Then Begin
  D:=OpExpr(0);
  T:=AddrExpr(CurI.Op[1]);
  If Sz<>PtrSz Then T:=MkUn(EO_TRUNC,T,Sz);
  Asg(D,T);
 End
 Else If Mn='add' Then LiftArith(EO_ADD,FK_ADD,Mn)
 Else If Mn='sub' Then LiftArith(EO_SUB,FK_SUB,Mn)
 Else If Mn='and' Then LiftArith(EO_AND,FK_LOGIC,Mn)
 Else If Mn='or' Then LiftArith(EO_OR,FK_LOGIC,Mn)
 Else If Mn='xor' Then LiftArith(EO_XOR,FK_LOGIC,Mn)
 Else If(Mn='adc')or(Mn='sbb')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  If Mn='adc' Then R:=MkBin(EO_ADD,MkBin(EO_ADD,D,S,Sz),MkCC(2),Sz)
   Else R:=MkBin(EO_SUB,MkBin(EO_SUB,D,S,Sz),MkCC(2),Sz);
  Asg(D,R);
  EmitFlags(FK_OTHER,D,S,Sz);
 End
 Else If Mn='cmp' Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  EmitFlags(FK_CMP,D,S,Sz);
 End
 Else If Mn='test' Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  EmitFlags(FK_TEST,D,S,Sz);
 End
 Else If(Mn='inc')or(Mn='dec')Then Begin
  D:=OpExpr(0);
  If Mn='inc' Then R:=MkBin(EO_ADD,D,MkConst(1,Sz),Sz) Else R:=MkBin(EO_ADD,D,MkConst(-1,Sz),Sz);
  Asg(D,R);
  If Mn='inc' Then EmitFlags(FK_INC,D,-1,Sz) Else EmitFlags(FK_DEC,D,-1,Sz);
 End
 Else If Mn='neg' Then Begin
  D:=OpExpr(0);
  Asg(D,MkUn(EO_NEG,D,Sz));
  EmitFlags(FK_NEG,D,-1,Sz);
 End
 Else If Mn='not' Then Begin
  D:=OpExpr(0);
  Asg(D,MkUn(EO_NOT,D,Sz));
 End
 Else If(Mn='shl')or(Mn='shr')or(Mn='sar')or(Mn='rol')or(Mn='ror')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  If Mn='shl' Then K:=EO_SHL Else If Mn='shr' Then K:=EO_SHR Else If Mn='sar' Then K:=EO_SAR
   Else If Mn='rol' Then K:=EO_ROL Else K:=EO_ROR;
  Asg(D,MkBin(K,D,S,Sz));
  EmitFlags(FK_SHIFT,D,S,Sz);
 End
 Else If Mn='imul' Then Begin
  If CurI.N=1 Then Begin
   D:=MkReg(0,Sz,False);S:=OpExpr(0);
   If Sz<HomeSz Then Begin EmitAsm;Exit;End;
   T:=MkReg(2,Sz,False);
   Asg(T,MkIntr('mulhi'+LStr(Sz*8),MkList(D,MkList(S,-1)),Sz));
   Asg(D,MkBin(EO_MUL,D,S,Sz));
   EmitFlags(FK_OTHER,D,-1,Sz);
  End
  Else If CurI.N=2 Then Begin
   D:=OpExpr(0);S:=OpExpr(1);
   Asg(D,MkBin(EO_MUL,D,S,Sz));
   EmitFlags(FK_OTHER,D,-1,Sz);
  End
  Else Begin
   D:=OpExpr(0);S:=OpExpr(1);T:=OpExpr(2);
   Asg(D,MkBin(EO_MUL,S,T,Sz));
   EmitFlags(FK_OTHER,D,-1,Sz);
  End;
 End
 Else If Mn='mul' Then Begin
  If Sz<HomeSz Then Begin EmitAsm;Exit;End;
  D:=MkReg(0,Sz,False);S:=OpExpr(0);
  T:=MkReg(2,Sz,False);
  Asg(T,MkIntr('umulhi'+LStr(Sz*8),MkList(D,MkList(S,-1)),Sz));
  Asg(D,MkBin(EO_MUL,D,S,Sz));
  EmitFlags(FK_OTHER,D,-1,Sz);
 End
 Else If(Mn='idiv')or(Mn='div')Then Begin
  If Sz<HomeSz Then Begin EmitAsm;Exit;End;
  D:=MkReg(0,Sz,False);T:=MkReg(2,Sz,False);S:=OpExpr(0);
  { le diviseur ne doit pas dependre de edx/eax }
  If(ExprUses(S)and 5)<>0 Then Begin
   Inc(TmpCount);
   Z:=MkVar('t'+LStr(TmpCount),Sz);
   Emit(ST_ASSIGN,Z,S);
   S:=Z;
  End;
  If Mn='idiv' Then Begin
   Asg(T,MkBin(EO_SMOD,D,S,Sz));
   Asg(D,MkBin(EO_SDIV,D,S,Sz));
  End
  Else Begin
   Asg(T,MkBin(EO_UMOD,D,S,Sz));
   Asg(D,MkBin(EO_UDIV,D,S,Sz));
  End;
  EmitFlags(FK_OTHER,D,-1,Sz);
 End
 Else If(Mn='cdq')or(Mn='cqo')or(Mn='cwd')Then Begin
  Sz:=CurI.OSize;
  Asg(MkReg(2,Sz,False),MkBin(EO_SAR,MkReg(0,Sz,False),MkConst(Sz*8-1,1),Sz));
 End
 Else If(Mn='cwde')or(Mn='cdqe')Then Begin
  Sz:=CurI.OSize;
  Asg(MkReg(0,Sz,False),MkUn(EO_SEXT,MkReg(0,Sz div 2,False),Sz));
 End
 Else If Mn='cbw' Then
  Asg(MkReg(0,2,False),MkUn(EO_SEXT,MkReg(0,1,False),2))
 Else If Mn='xchg' Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Inc(TmpCount);
  T:=MkVar('t'+LStr(TmpCount),Sz);
  Emit(ST_ASSIGN,T,D);
  Asg(D,S);
  Asg(S,T);
 End
 Else If Mn='push' Then Begin
  S:=OpExpr(0);
  Emit(ST_PUSH,S,-1);
  St^[NSt-1].Sz:=CurI.Op[0].Size;
  If St^[NSt-1].Sz=0 Then St^[NSt-1].Sz:=PtrSz;
 End
 Else If Mn='pop' Then Begin
  D:=OpExpr(0);
  Emit(ST_POP,D,-1);
  St^[NSt-1].Sz:=CurI.Op[0].Size;
 End
 Else If Mn='leave' Then Begin
  Emit(ST_ASSIGN,StackPtr,MkReg(5,PtrSz,False));
  Emit(ST_POP,MkReg(5,PtrSz,False),-1);
  St^[NSt-1].Sz:=PtrSz;
 End
 Else If(Mn='cmovo')or(Copy(Mn,1,4)='cmov')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Asg(D,NewEx(EO_TERN,Sz,MkCC(CurI.CC),S,D,0));
 End
 Else If Copy(Mn,1,3)='set' Then Begin
  D:=OpExpr(0);
  Asg(D,MkCC(CurI.CC));
 End
 Else If Mn='call' Then Begin
  If CurI.Flow=FL_CALL Then Tgt:=MkConst(ThunkDest(CurI.Target),AddrSz)
  Else If CurI.Op[0].Kind=OK_FAR Then Begin EmitAsm;Exit;End
  Else Tgt:=OpExpr(0);
  Args:=NewEx(EO_CALL,PtrSz,Tgt,-1,0,0);
  K:=-1;
  If Ex^[Tgt].Op=EO_CONST Then Begin
   K:=RootIdx(Ex^[Tgt].V);
   If(K>=0)and not SigOk[K]Then K:=-1;
  End;
  If(K>=0)and(SigRet[K]=0)Then Emit(ST_EXPR,Args,-1)
  Else If(K>=0)and(SigRet[K]=4)Then Begin
   Ex^[Args].Sz:=4;
   Emit(ST_ASSIGN,MkRegRaw(0,HomeOf(0),False),Args);
  End
  Else If(K>=0)and(SigRet[K]=16)Then Asg(MkReg(16,16,False),Args)
  Else Emit(ST_ASSIGN,RetReg,Args);
 End
 Else If Mn='jmp' Then Begin
  If CurI.Flow=FL_IJMP Then Begin
   If CurI.Op[0].Kind=OK_FAR Then Emit(ST_IJMP,MkConst(CurI.Op[0].Disp,AddrSz),-1)
   Else Emit(ST_IJMP,OpExpr(0),-1);
  End
  Else Emit(ST_JMP,-1,-1);
 End
 Else If(CurI.Flow=FL_JCC)Then Begin
  If CurI.CC>=0 Then Emit(ST_JCC,MkCC(CurI.CC),-1)
  Else Begin
   { loop / jcxz }
   If Mn='jcxz' Then K:=2 Else If Mn='jrcxz' Then K:=8 Else If Mn='jecxz' Then K:=4 Else K:=PtrSz;
   D:=MkReg(1,K,False);
   If Copy(Mn,1,4)='loop' Then Begin
    Asg(D,MkBin(EO_ADD,D,MkConst(-1,K),K));
    T:=NewEx(EO_NE,1,D,MkConst(0,K),0,0);
    If Mn='loope' Then T:=NewEx(EO_LAND,1,T,MkCC(4),0,0)
    Else If Mn='loopne' Then T:=NewEx(EO_LAND,1,T,NewEx(EO_LNOT,1,MkCC(4),0,0,0),0,0);
   End
   Else T:=NewEx(EO_EQ,1,D,MkConst(0,K),0,0);
   Emit(ST_JCC,T,-1);
  End;
 End
 Else If(Mn='ret')or(Mn='retf')or(Mn='iret')or(Mn='iretd')or(Mn='iretq')Then Emit(ST_RET,-1,-1)
 Else If(Mn='hlt')or(Mn='ud2')or(Mn='int3')Then Emit(ST_HALT,-1,-1)
 Else If(Mn='nop')or(Mn='pause')or(Mn='endbr64')or(Mn='endbr32')or(Mn='fwait')or
        (Copy(Mn,1,8)='prefetch')or(Mn='lfence')or(Mn='mfence')or(Mn='sfence')Then
  Emit(ST_NOP,0,0)
 Else If(Mn='cld')or(Mn='std')or(Mn='clc')or(Mn='stc')or(Mn='cmc')Then Emit(ST_NOP,0,0)
 Else If Mn='bt' Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  EmitFlags(FK_BT,D,S,Sz);
 End
 Else If(Mn='bts')or(Mn='btr')or(Mn='btc')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  EmitFlags(FK_BT,D,S,Sz);
  Asg(D,MkIntr(Mn,MkList(D,MkList(S,-1)),Sz));
 End
 Else If(Mn='bsf')or(Mn='bsr')or(Mn='popcnt')or(Mn='tzcnt')or(Mn='lzcnt')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Asg(D,MkIntr(Mn,MkList(S,-1),Sz));
  EmitFlags(FK_OTHER,D,-1,Sz);
 End
 Else If Mn='bswap' Then Begin
  D:=OpExpr(0);
  Asg(D,MkIntr('bswap',MkList(D,-1),Sz));
 End
 Else If(Mn='shld')or(Mn='shrd')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);T:=OpExpr(2);
  Asg(D,MkIntr(Mn,MkList(D,MkList(S,MkList(T,-1))),Sz));
  EmitFlags(FK_SHIFT,D,T,Sz);
 End
 Else If(Mn='movs')or(Mn='stos')or(Copy(Mn,1,4)='movs')and(CurI.N=0)or(Copy(Mn,1,4)='stos')and(CurI.N=0)Then Begin
  If(CurI.Rep=1)and(Copy(Mn,1,4)='stos')Then Begin
   Sz:=1;
   If Mn='stosw' Then Sz:=2 Else If Mn='stosd' Then Sz:=4 Else If Mn='stosq' Then Sz:=8;
   Args:=MkList(MkReg(7,PtrSz,False),MkList(MkReg(0,Sz,False),MkList(
         MkBin(EO_MUL,MkReg(1,PtrSz,False),MkConst(Sz,PtrSz),PtrSz),-1)));
   Emit(ST_EXPR,MkIntr('memset',Args,PtrSz),-1);
  End
  Else If(CurI.Rep=1)and(Copy(Mn,1,4)='movs')Then Begin
   Sz:=1;
   If Mn='movsw' Then Sz:=2 Else If Mn='movsd' Then Sz:=4 Else If Mn='movsq' Then Sz:=8;
   Args:=MkList(MkReg(7,PtrSz,False),MkList(MkReg(6,PtrSz,False),MkList(
         MkBin(EO_MUL,MkReg(1,PtrSz,False),MkConst(Sz,PtrSz),PtrSz),-1)));
   Emit(ST_EXPR,MkIntr('memcpy',Args,PtrSz),-1);
  End
  Else EmitAsm;
 End
 Else If(Mn='syscall')Then Begin
  Args:=MkList(MkReg(0,8,False),MkList(MkReg(7,8,False),MkList(MkReg(6,8,False),
        MkList(MkReg(2,8,False),MkList(MkReg(10,8,False),MkList(MkReg(8,8,False),MkList(MkReg(9,8,False),-1)))))));
  Emit(ST_ASSIGN,MkReg(0,8,False),MkIntr('syscall',Args,8));
 End
 Else If(Mn='ucomiss')or(Mn='ucomisd')or(Mn='comiss')or(Mn='comisd')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  EmitFlags(FK_FCMP,D,S,CurI.Op[0].Size);
 End
 Else If(Copy(Mn,1,3)='mov')and(CurI.N=2)and((IsXmmOp(0)or IsXmmOp(1))or(Mn='movq')or(Mn='movd'))and
        (Copy(Mn,1,5)<>'movmsk')and(Mn<>'movhlps')and(Mn<>'movlhps')and(Mn<>'movddup')and
        (Mn<>'movq2dq')and(Mn<>'movdq2q')and(Mn<>'movnti')and(Mn<>'movntdq')and(Mn<>'movntps')and(Mn<>'movntpd')Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  Asg(D,S);
 End
 Else If((Mn='addss')or(Mn='addsd')or(Mn='addps')or(Mn='addpd'))and(CurI.N=2)Then Begin
  D:=OpExpr(0);Asg(D,MkBin(EO_ADD,D,OpExpr(1),Sz));
 End
 Else If((Mn='subss')or(Mn='subsd')or(Mn='subps')or(Mn='subpd'))and(CurI.N=2)Then Begin
  D:=OpExpr(0);Asg(D,MkBin(EO_SUB,D,OpExpr(1),Sz));
 End
 Else If((Mn='mulss')or(Mn='mulsd')or(Mn='mulps')or(Mn='mulpd'))and(CurI.N=2)Then Begin
  D:=OpExpr(0);Asg(D,MkBin(EO_MUL,D,OpExpr(1),Sz));
 End
 Else If((Mn='divss')or(Mn='divsd')or(Mn='divps')or(Mn='divpd'))and(CurI.N=2)Then Begin
  D:=OpExpr(0);Asg(D,MkBin(EO_SDIV,D,OpExpr(1),Sz));
 End
 Else If((Mn='xorps')or(Mn='xorpd')or(Mn='pxor'))and(CurI.N=2)and IsXmmOp(0)Then Begin
  D:=OpExpr(0);S:=OpExpr(1);
  If SameExpr(D,S)Then Asg(D,MkConst(0,Sz))
   Else Asg(D,MkIntr(Mn,MkList(D,MkList(S,-1)),Sz));
 End
 Else If(CurI.N>=2)and(IsXmmOp(0)or((CurI.Op[0].Kind=OK_REG)and(CurI.Op[0].Cls=RC_MMX))or
        ((CurI.Op[0].Kind=OK_REG)and(CurI.Op[0].Cls=RC_GPR)and(Copy(Mn,1,3)='cvt')))and
        (CurI.Flow=FL_NORMAL)and(CurI.Op[0].Cls<>RC_ST)Then Begin
  D:=OpExpr(0);
  Args:=-1;
  For K:=CurI.N-1 downto 1 do Args:=MkList(OpExpr(K),Args);
  If(Copy(Mn,1,3)<>'mov')and(Copy(Mn,1,3)<>'cvt')and(Copy(Mn,1,5)<>'pshuf')and
    (Copy(Mn,1,6)<>'pmovmsk')and(Copy(Mn,1,7)<>'pextrw')Then Args:=MkList(D,Args);
  Asg(D,MkIntr(Mn,Args,Sz));
 End
 Else EmitAsm;
End;

{ Convertit une instruction en statements (terminateur ajoute par l'appelant si necessaire) }
Procedure LiftOne(Const I:TInsn);
Begin
 CurI:=I;
 LiftIns;
End;

{ ============================================================
  ANALYSE DE LA FONCTION : IR, CONDITIONS, VIVACITE, PROPAGATION
  ============================================================ }
Var
 PredStart,PredCnt:Array[0..MAXBLK-1] of LongInt;
 PredPool:Array[0..MAXSW+2*MAXBLK] of LongInt;
 LiveIn,LiveOut:Array[0..MAXBLK-1] of Int64;
 VolMask:Int64;
 EntryBlk:LongInt;
 HasFrame:Boolean;
 FrameSlot:LongInt;
 ArgRegs:Array[0..5] of Integer;
 NArgRegs:Integer;
 SpIn:Array[0..MAXBLK-1] of LongInt;
 SpSet:Array[0..MAXBLK-1] of Boolean;
 FnTail:Boolean;

Procedure BuildPreds;
Var B,K,S,N:LongInt;
Begin
 FillChar(PredCnt,SizeOf(PredCnt),0);
 For B:=0 to NB-1 do
  For K:=0 to NSucc(B)-1 do Inc(PredCnt[SuccOf(B,K)]);
 N:=0;
 For B:=0 to NB-1 do Begin PredStart[B]:=N;N:=N+PredCnt[B];End;
 For B:=0 to NB-1 do PredCnt[B]:=0;
 For B:=0 to NB-1 do Begin
  For K:=0 to NSucc(B)-1 do Begin
   S:=SuccOf(B,K);
   PredPool[PredStart[S]+PredCnt[S]]:=B;
   Inc(PredCnt[S]);
  End;
 End;
End;

Procedure InitCtx;
Begin
 IgnoreMerge:=False;
 If CpuMode=64 Then PtrSz:=8 Else If CpuMode=32 Then PtrSz:=4 Else PtrSz:=2;
 NEx:=0;NSt:=0;NName:=0;NAsm:=0;TmpCount:=0;
 HasFrame:=False;FrameSlot:=0;
 If CpuMode=64 Then Begin
  If IsWin Then Begin
   VolMask:=$FFFF0000 or $0F07;       { rax rcx rdx r8-r11 + xmm }
   VolMask:=(Int64(1)shl 0)or(Int64(1)shl 1)or(Int64(1)shl 2)or(Int64(1)shl 8)or(Int64(1)shl 9)or
            (Int64(1)shl 10)or(Int64(1)shl 11)or(Int64($FFFF)shl 16)or FLAGS_BIT;
   ArgRegs[0]:=1;ArgRegs[1]:=2;ArgRegs[2]:=8;ArgRegs[3]:=9;NArgRegs:=4;
  End
  Else Begin
   VolMask:=(Int64(1)shl 0)or(Int64(1)shl 1)or(Int64(1)shl 2)or(Int64(1)shl 6)or(Int64(1)shl 7)or
            (Int64(1)shl 8)or(Int64(1)shl 9)or(Int64(1)shl 10)or(Int64(1)shl 11)or(Int64($FFFF)shl 16)or FLAGS_BIT;
   ArgRegs[0]:=7;ArgRegs[1]:=6;ArgRegs[2]:=2;ArgRegs[3]:=1;ArgRegs[4]:=8;ArgRegs[5]:=9;NArgRegs:=6;
  End;
 End
 Else Begin
  VolMask:=(Int64(1)shl 0)or(Int64(1)shl 1)or(Int64(1)shl 2)or(Int64($FFFF)shl 16)or FLAGS_BIT;
  If CpuMode=32 Then Begin ArgRegs[0]:=0;ArgRegs[1]:=2;ArgRegs[2]:=1;NArgRegs:=3;End
  Else NArgRegs:=0;
 End;
End;

{ ---------- proprietes des statements ---------- }
Function StmtHasCall(K:LongInt):Boolean;
Begin
 StmtHasCall:=False;
 Case St^[K].Kind of
  ST_ASSIGN,ST_STORE:StmtHasCall:=ExprHasCall(St^[K].B)or ExprHasCall(St^[K].A);
  ST_EXPR,ST_PUSH,ST_FLAGS,ST_JCC,ST_IJMP:StmtHasCall:=ExprHasCall(St^[K].A);
  ST_TAIL:StmtHasCall:=True;
 End;
End;

Function StmtDefMask(K:LongInt):Int64;
Var M:Int64;
Begin
 M:=0;
 Case St^[K].Kind of
  ST_ASSIGN:Begin
   If Ex^[St^[K].A].Op=EO_REG Then M:=Int64(1)shl Ex^[St^[K].A].A;
   If ExprHasCall(St^[K].B)Then M:=M or VolMask;
  End;
  ST_POP:If Ex^[St^[K].A].Op=EO_REG Then M:=Int64(1)shl Ex^[St^[K].A].A;
  ST_EXPR:If ExprHasCall(St^[K].A)Then M:=VolMask;
  ST_FLAGS:M:=FLAGS_BIT;
  ST_ASM:M:=$FFFF or FLAGS_BIT;
  ST_TAIL:M:=VolMask;
 End;
 StmtDefMask:=M;
End;

Function StmtWritesMem(K:LongInt):Boolean;
Begin
 StmtWritesMem:=False;
 Case St^[K].Kind of
  ST_STORE,ST_PUSH,ST_POP,ST_ASM,ST_TAIL:StmtWritesMem:=True;
  ST_ASSIGN,ST_EXPR:StmtWritesMem:=StmtHasCall(K);
 End;
End;

Function StmtReadsMem(K:LongInt):Boolean;
Begin
 StmtReadsMem:=False;
 Case St^[K].Kind of
  ST_ASSIGN:StmtReadsMem:=ExprHasMem(St^[K].B);
  ST_STORE:StmtReadsMem:=ExprHasMem(St^[K].A)or ExprHasMem(St^[K].B);
  ST_FLAGS:StmtReadsMem:=ExprHasMem(St^[K].A)or ExprHasMem(St^[K].B);
  ST_PUSH,ST_EXPR,ST_JCC,ST_IJMP,ST_TAIL,ST_POP:StmtReadsMem:=ExprHasMem(St^[K].A);
  ST_ASM:StmtReadsMem:=True;
 End;
End;

Function StmtReadCount(K,R:LongInt):LongInt;
Var N:LongInt;
Begin
 N:=0;
 Case St^[K].Kind of
  ST_ASSIGN:N:=CountReg(St^[K].B,R);
  ST_STORE,ST_FLAGS:N:=CountReg(St^[K].A,R)+CountReg(St^[K].B,R);
  ST_PUSH,ST_EXPR,ST_JCC,ST_IJMP,ST_TAIL:N:=CountReg(St^[K].A,R);
  ST_POP:If Ex^[St^[K].A].Op=EO_MEM Then N:=CountReg(St^[K].A,R);
  ST_RET:Begin
   If(St^[K].FK=2)and(R=16)Then N:=1
   Else If(St^[K].FK=1)and(R=0)Then N:=1;
  End;
  ST_ASM:N:=1;
 End;
 StmtReadCount:=N;
End;

Procedure StmtSubst(K,R,DefSz:LongInt;Repl:LongInt);
Begin
 Case St^[K].Kind of
  ST_ASSIGN:St^[K].B:=SubstReg(St^[K].B,R,DefSz,Repl);
  ST_STORE,ST_FLAGS:Begin
   St^[K].A:=SubstReg(St^[K].A,R,DefSz,Repl);
   St^[K].B:=SubstReg(St^[K].B,R,DefSz,Repl);
  End;
  ST_PUSH,ST_EXPR,ST_JCC,ST_IJMP,ST_TAIL:St^[K].A:=SubstReg(St^[K].A,R,DefSz,Repl);
  ST_POP:If Ex^[St^[K].A].Op=EO_MEM Then St^[K].A:=SubstReg(St^[K].A,R,DefSz,Repl);
 End;
End;

{ le statement tue-t-il completement le registre R ? }
Function StmtKills(K,R:LongInt):Boolean;
Var D:LongInt;FullSz:Integer;
Begin
 StmtKills:=False;
 If CpuMode=16 Then FullSz:=2 Else FullSz:=4;
 Case St^[K].Kind of
  ST_ASSIGN,ST_POP:Begin
   D:=St^[K].A;
   If(Ex^[D].Op=EO_REG)and(Ex^[D].A=R)and(Ex^[D].B=0)and((Ex^[D].Sz>=FullSz)or(R>=16))Then Begin
    StmtKills:=True;Exit;
   End;
   If(St^[K].Kind=ST_ASSIGN)and ExprHasCall(St^[K].B)and(((Int64(1)shl R)and VolMask)<>0)Then StmtKills:=True;
  End;
  ST_EXPR:If ExprHasCall(St^[K].A)and(((Int64(1)shl R)and VolMask)<>0)Then StmtKills:=True;
 End;
End;

{ ---------- resolution des conditions ---------- }
Function CondFromFlags(Const S:TStmt;CC:Integer):LongInt;
Var A,B,R,Z:LongInt;Sz:Integer;
 Function Rel(Op:Byte;X,Y:LongInt):LongInt;
 Begin
  Rel:=NewEx(Op,1,X,Y,0,0);
 End;
Begin
 CondFromFlags:=-1;
 Sz:=S.Sz;
 If Sz=0 Then Sz:=4;
 Z:=MkConst(0,Sz);
 A:=S.A;B:=S.B;
 Case S.FK of
  FK_CMP:Begin
   Case CC of
    4:CondFromFlags:=Rel(EO_EQ,A,B);
    5:CondFromFlags:=Rel(EO_NE,A,B);
    12:CondFromFlags:=Rel(EO_SLT,A,B);
    13:CondFromFlags:=Rel(EO_SGE,A,B);
    14:CondFromFlags:=Rel(EO_SLE,A,B);
    15:CondFromFlags:=Rel(EO_SGT,A,B);
    2:CondFromFlags:=Rel(EO_ULT,A,B);
    3:CondFromFlags:=Rel(EO_UGE,A,B);
    6:CondFromFlags:=Rel(EO_ULE,A,B);
    7:CondFromFlags:=Rel(EO_UGT,A,B);
    8:CondFromFlags:=Rel(EO_SLT,MkBin(EO_SUB,A,B,Sz),Z);
    9:CondFromFlags:=Rel(EO_SGE,MkBin(EO_SUB,A,B,Sz),Z);
   End;
  End;
  FK_TEST,FK_LOGIC:Begin
   If S.FK=FK_TEST Then Begin
    If SameExpr(A,B)Then R:=A Else R:=MkBin(EO_AND,A,B,Sz);
   End
   Else R:=A;
   Case CC of
    4,6:CondFromFlags:=Rel(EO_EQ,R,Z);
    5,7:CondFromFlags:=Rel(EO_NE,R,Z);
    8,12:CondFromFlags:=Rel(EO_SLT,R,Z);
    9,13:CondFromFlags:=Rel(EO_SGE,R,Z);
    14:CondFromFlags:=Rel(EO_SLE,R,Z);
    15:CondFromFlags:=Rel(EO_SGT,R,Z);
    2:CondFromFlags:=MkConst(0,1);
    3:CondFromFlags:=MkConst(1,1);
   End;
  End;
  FK_ADD,FK_SUB,FK_INC,FK_DEC,FK_NEG,FK_SHIFT:Begin
   R:=A;
   Case CC of
    4:CondFromFlags:=Rel(EO_EQ,R,Z);
    5:CondFromFlags:=Rel(EO_NE,R,Z);
    8,12:CondFromFlags:=Rel(EO_SLT,R,Z);
    9,13:CondFromFlags:=Rel(EO_SGE,R,Z);
    14:CondFromFlags:=Rel(EO_SLE,R,Z);
    15:CondFromFlags:=Rel(EO_SGT,R,Z);
    2:Begin
     If(S.FK=FK_ADD)and(B>=0)Then CondFromFlags:=Rel(EO_ULT,R,B)
     Else If(S.FK=FK_SUB)and(B>=0)Then CondFromFlags:=Rel(EO_ULT,MkBin(EO_ADD,R,B,Sz),B)
     Else If S.FK=FK_NEG Then CondFromFlags:=Rel(EO_NE,R,Z);
    End;
    3:Begin
     If(S.FK=FK_ADD)and(B>=0)Then CondFromFlags:=Rel(EO_UGE,R,B)
     Else If(S.FK=FK_SUB)and(B>=0)Then CondFromFlags:=Rel(EO_UGE,MkBin(EO_ADD,R,B,Sz),B)
     Else If S.FK=FK_NEG Then CondFromFlags:=Rel(EO_EQ,R,Z);
    End;
   End;
  End;
  FK_FCMP:Begin
   Case CC of
    4:CondFromFlags:=Rel(EO_EQ,A,B);
    5:CondFromFlags:=Rel(EO_NE,A,B);
    2:CondFromFlags:=Rel(EO_SLT,A,B);
    3:CondFromFlags:=Rel(EO_SGE,A,B);
    6:CondFromFlags:=Rel(EO_SLE,A,B);
    7:CondFromFlags:=Rel(EO_SGT,A,B);
   End;
  End;
  FK_BT:Begin
   R:=MkBin(EO_AND,MkBin(EO_SHR,A,B,Sz),MkConst(1,Sz),Sz);
   If CC=2 Then CondFromFlags:=Rel(EO_NE,R,Z)
   Else If CC=3 Then CondFromFlags:=Rel(EO_EQ,R,Z);
  End;
 End;
End;

Function ResolveCC(Blk,Pos:LongInt;CC:Integer):LongInt;
Var
 B,P,J,Depth,C:LongInt;
 DefAcc:Int64;
 StoreAcc,Stop:Boolean;
 Uses_:Int64;
 Mem:Boolean;
Begin
 B:=Blk;P:=Pos;DefAcc:=0;StoreAcc:=False;Depth:=0;
 While Depth<10 do Begin
  For J:=P-1 downto SB0[B] do Begin
   Case St^[J].Kind of
    ST_NOP:;
    ST_FLAGS:Begin
     C:=CondFromFlags(St^[J],CC);
     If C<0 Then Begin ResolveCC:=MkCC(CC);Exit;End;
     Uses_:=ExprUses(St^[J].A)or ExprUses(St^[J].B);
     Mem:=ExprHasMem(St^[J].A)or ExprHasMem(St^[J].B);
     If((Uses_ and DefAcc)<>0)or(Mem and StoreAcc)Then Begin ResolveCC:=MkCC(CC);Exit;End;
     ResolveCC:=C;Exit;
    End;
    ST_ASM:Begin ResolveCC:=MkCC(CC);Exit;End;
    Else Begin
     If StmtHasCall(J)Then Begin ResolveCC:=MkCC(CC);Exit;End;
     DefAcc:=DefAcc or StmtDefMask(J);
     If St^[J].Kind in[ST_STORE,ST_PUSH,ST_POP]Then StoreAcc:=True;
    End;
   End;
  End;
  If(PredCnt[B]=1)and(PredPool[PredStart[B]]<>B)Then Begin
   B:=PredPool[PredStart[B]];
   P:=SB0[B]+SBN[B]-1;
   Inc(Depth);
  End
  Else Break;
 End;
 ResolveCC:=MkCC(CC);
End;

{ ---------- levee de la fonction ---------- }
Function CallArgsFix(E:LongInt):LongInt;
Begin
 CallArgsFix:=E;
End;

Procedure FixTerm(B:LongInt);
Var Last:LongInt;Tg:LongInt;Nm:String;Slot:Int64;
Begin
 Last:=NSt-1;
 If NSt<=SB0[B]Then Last:=-1;
 Case BKind[B] of
  BK_FALL,BK_JMP:Begin
   If(Last<0)or(St^[Last].Kind<>ST_JMP)Then Emit(ST_JMP,-1,-1);
  End;
  BK_JCC:Begin
   If(Last<0)or(St^[Last].Kind<>ST_JCC)Then Emit(ST_JMP,-1,-1);
  End;
  BK_RET:Begin
   If(Last<0)or(St^[Last].Kind<>ST_RET)Then Emit(ST_RET,-1,-1);
  End;
  BK_SWITCH:Begin
   If(Last<0)or(St^[Last].Kind<>ST_IJMP)Then Emit(ST_HALT,-1,-1)
   Else Begin
    Tg:=SwRecFor(Ins^[BLast(B)].Addr);
    St^[Last].A:=MkVar('sw'+LStr(Tg),PtrSz);
   End;
  End;
  BK_IJMP:Begin
   If(Last<0)or(St^[Last].Kind<>ST_IJMP)Then Emit(ST_HALT,-1,-1)
   Else Begin
    { saut vers une fonction importee : appel terminal }
    Tg:=St^[Last].A;
    If(Tg>=0)and(Ex^[Tg].Op=EO_MEM)and(Ex^[Ex^[Tg].A].Op=EO_CONST)Then Begin
     Slot:=Ex^[Ex^[Tg].A].V;
     If CpuMode=32 Then Slot:=Slot and $FFFFFFFF;
     Nm:=ImportAt(Slot);
     If Nm<>''Then Begin
      St^[Last].Kind:=ST_TAIL;
      St^[Last].A:=NewEx(EO_CALL,PtrSz,Tg,-1,0,0);
     End;
    End;
   End;
  End;
  BK_TAIL:Begin
   If(Last>=0)and(St^[Last].Kind=ST_JMP)Then Begin
    St^[Last].Kind:=ST_TAIL;
    St^[Last].A:=NewEx(EO_CALL,PtrSz,MkConst(BTgt[B],AddrSz),-1,0,0);
   End
   Else Begin
    CurI.Addr:=BEndA[B];
    Emit(ST_TAIL,NewEx(EO_CALL,PtrSz,MkConst(BTgt[B],AddrSz),-1,0,0),-1);
   End;
  End;
  Else Begin
   If(Last<0)or(St^[Last].Kind<>ST_HALT)Then Emit(ST_HALT,-1,-1);
  End;
 End;
End;

{ registres utilises sur 64 bits dans la fonction : leur forme complete est rXX }
Procedure ScanWidths;
Var I,K,X:LongInt;P:^TInsn;
Begin
 FillChar(WideReg,SizeOf(WideReg),False);
 If CpuMode<>64 Then Exit;
 For I:=0 to NFnIns-1 do Begin
  P:=@Ins^[FnIns^[I]];
  If P^.Mn='nop' Then Continue;
  For K:=0 to P^.N-1 do Begin
   If(P^.Op[K].Kind=OK_REG)and(P^.Op[K].Cls=RC_GPR)and(P^.Op[K].Size=8)and(P^.Op[K].Reg>=0)and(P^.Op[K].Reg<16)Then
    WideReg[P^.Op[K].Reg]:=True;
   If P^.Op[K].Kind=OK_MEM Then Begin
    If(P^.Op[K].Base>=0)and(P^.Op[K].Base<16)Then WideReg[P^.Op[K].Base]:=True;
    If(P^.Op[K].Index>=0)and(P^.Op[K].Index<16)Then WideReg[P^.Op[K].Index]:=True;
   End;
  End;
  If P^.Mn='syscall' Then
   For X:=0 to 15 do If X in[0,1,2,6,7,8,9,10]Then WideReg[X]:=True;
  If(Copy(P^.Mn,1,4)='movs')or(Copy(P^.Mn,1,4)='stos')or(Copy(P^.Mn,1,4)='lods')or
    (Copy(P^.Mn,1,4)='scas')or(Copy(P^.Mn,1,4)='cmps')Then Begin
   WideReg[1]:=True;WideReg[6]:=True;WideReg[7]:=True;
  End;
 End;
End;

Procedure LiftFunction;
Var B,I,X,J,K:LongInt;Sz:Integer;
Begin
 For B:=0 to NB-1 do Begin
  SB0[B]:=NSt;
  For I:=BI0[B] to BI0[B]+BN[B]-1 do Begin
   X:=FnIns^[I];
   K:=SwRecLoad(Ins^[X].Addr);
   If K>=0 Then Begin
    CurI:=Ins^[X];
    Emit(ST_ASSIGN,MkVar('sw'+LStr(K),PtrSz),MkReg(SwIdxReg[K],SwIdxSz[K],False));
   End;
   LiftOne(Ins^[X]);
  End;
  CurI.Addr:=Ins^[BLast(B)].Addr;
  FixTerm(B);
  SBN[B]:=NSt-SB0[B];
 End;
 { taille du registre de retour d'un appel selon l'utilisation qui suit }
 If CpuMode=64 Then
  For B:=0 to NB-1 do
   For J:=SB0[B] to SB0[B]+SBN[B]-1 do
    If(St^[J].Kind=ST_ASSIGN)and(Ex^[St^[J].B].Op=EO_CALL)and(Ex^[St^[J].A].Op=EO_REG)and(Ex^[St^[J].A].A=0)Then Begin
     Sz:=0;
     For K:=J+1 to SB0[B]+SBN[B]-1 do Begin
      If St^[K].Kind=ST_NOP Then Continue;
      If StmtReadCount(K,0)>0 Then Begin
       Case St^[K].Kind of
        ST_ASSIGN:Sz:=RegSizeIn(St^[K].B,0);
        ST_STORE,ST_FLAGS:Begin
         Sz:=RegSizeIn(St^[K].A,0);
         If Sz=0 Then Sz:=RegSizeIn(St^[K].B,0);
        End;
        Else Sz:=RegSizeIn(St^[K].A,0);
       End;
       Break;
      End;
      If StmtKills(K,0)Then Break;
     End;
     If Sz=4 Then St^[J].A:=MkReg(0,4,False);
    End;
End;

{ ---------- prologue : pushes de registres masques ---------- }
Procedure MarkPrologue;
Var K,E:LongInt;
Begin
 E:=SB0[EntryBlk]+SBN[EntryBlk]-1;
 For K:=SB0[EntryBlk] to E do Begin
  Case St^[K].Kind of
   ST_NOP:;
   ST_PUSH:Begin
    If(Ex^[St^[K].A].Op=EO_REG)Then St^[K].FK:=1 Else Break;
   End;
   ST_ASSIGN:Begin
    If(Ex^[St^[K].A].Op=EO_REG)and(Ex^[St^[K].A].A in[4,5])Then
    Else Break;
   End;
   Else Break;
  End;
 End;
End;

{ ---------- nombre d'arguments des fonctions connues ---------- }
Const
 NAPITAB = 15;
 ApiTab:Array[0..NAPITAB-1] of String[255]=(
  ' puts=1 putchar=1 strlen=1 strcpy=2 strncpy=3 strcat=2 strncat=3 strcmp=2 strncmp=3 strchr=2 strrchr=2 strstr=2 strdup=1 memcpy=3 memmove=3 memset=3 memcmp=3 memchr=3 malloc=1 calloc=2 realloc=2 free=1 atoi=1 atol=1 strtol=3 strtoul=3',
  ' abs=1 exit=1 _exit=1 abort=0 fopen=2 fclose=1 fread=4 fwrite=4 fgets=3 fputs=2 fputc=2 fgetc=1 getc=1 putc=2 fflush=1 fseek=3 ftell=1 rewind=1 remove=1 rename=2 getenv=1 system=1 read=3 write=3 close=1 lseek=3 stat=2 fstat=2 access=2',
  ' unlink=1 mkdir=2 rmdir=1 chdir=1 getcwd=2 isatty=1 toupper=1 tolower=1 isalpha=1 isdigit=1 isspace=1 isalnum=1 isupper=1 islower=1 isprint=1 qsort=4 bsearch=5 time=1 sleep=1 usleep=1 signal=2 raise=1 setlocale=2 perror=1 strerror=1',
  ' __stack_chk_fail=0 __cxa_finalize=1 __libc_start_main=6 sqrt=0:1 sin=0:1 cos=0:1 tan=0:1 atan=0:1 exp=0:1 log=0:1 floor=0:1 ceil=0:1 fabs=0:1 pow=0:2 atan2=0:2 fmod=0:2 GetStdHandle=1 WriteFile=5 ReadFile=5 CloseHandle=1 CreateFileA=7',
  ' CreateFileW=7 ExitProcess=1 GetLastError=0 SetLastError=1 GetModuleHandleA=1 GetModuleHandleW=1 GetProcAddress=2 LoadLibraryA=1 LoadLibraryW=1 FreeLibrary=1 HeapAlloc=3 HeapFree=3 HeapCreate=3 GetProcessHeap=0 VirtualAlloc=4',
  ' VirtualFree=3 GetCommandLineA=0 GetCommandLineW=0 GetStartupInfoA=1 GetCurrentProcess=0 GetCurrentProcessId=0 GetCurrentThreadId=0 Sleep=1 TlsAlloc=0 TlsGetValue=1 TlsSetValue=2 TlsFree=1 CreateThread=6 ExitThread=1 GetTickCount=0',
  ' QueryPerformanceCounter=1 GetConsoleMode=2 SetConsoleMode=2 WriteConsoleA=5 WriteConsoleW=5 SetFilePointer=4 GetFileSize=2 DeleteFileA=1 GetFileAttributesA=1 GetModuleFileNameA=3 GetModuleFileNameW=3 MultiByteToWideChar=6',
  ' WideCharToMultiByte=8 lstrlenA=1 lstrcpyA=2 LocalAlloc=2 LocalFree=1 GlobalAlloc=2 GlobalFree=1 MessageBoxA=4 MessageBoxW=4 ReadProcessMemory=5 WaitForSingleObject=2 InitializeCriticalSection=1 EnterCriticalSection=1',
  ' LeaveCriticalSection=1 DeleteCriticalSection=1 GetSystemTime=1 GetLocalTime=1 GetVersion=0 GetOEMCP=0 GetACP=0 GetConsoleOutputCP=0 GetFileType=1 TerminateProcess=2 SuspendThread=1 FormatMessageW=7 FormatMessageA=7 poll=3 select=5',
  ' socket=3 connect=3 bind=3 listen=2 accept=3 send=4 recv=4 sendto=6 recvfrom=6 shutdown=2 getsockname=3 setsockopt=5 getsockopt=5 mmap=6 munmap=2 mprotect=3 pipe=1 dup=1 dup2=2 fork=0 execve=3 execv=2 waitpid=3 wait=1 kill=2 getpid=0',
  ' getppid=0 getuid=0 geteuid=0 getgid=0 sigaction=3 sigprocmask=3 sigemptyset=1 sigaddset=2 pthread_create=4 pthread_join=2 pthread_mutex_lock=1 pthread_mutex_unlock=1 pthread_mutex_init=2 pthread_self=0 strtod=2 atof=1 strcasecmp=2',
  ' strncasecmp=3 strspn=2 strcspn=2 strpbrk=2 strtok=2 strnlen=2 strcoll=2 wcslen=1 labs=1 rand=0 srand=1 setenv=3 putenv=1 unsetenv=1 opendir=1 readdir=1 closedir=1 lstat=2 chmod=2 chown=3 umask=1 gettimeofday=2 clock_gettime=2',
  ' nanosleep=2 localtime=1 gmtime=1 mktime=1 strftime=4 isxdigit=1 ispunct=1 iscntrl=1 isgraph=1 strlcpy=3 strlcat=3 getline=3 fileno=1 fdopen=2 freopen=3 setvbuf=4 ungetc=2 fscanf=0 readlink=3 symlink=2 link=2 truncate=2 ftruncate=2',
  ' fsync=1 getpagesize=0 sysconf=1 sched_yield=0 atexit=1 on_exit=2 __cxa_atexit=3 __errno_location=0 __ctype_b_loc=0 __ctype_tolower_loc=0 __ctype_toupper_loc=0 __assert_fail=4 __memcpy_chk=4 __strcpy_chk=3 __memset_chk=4',
  ' __fortify_fail=1 operator_delete=1');

{ nombre d'arguments entiers / flottants d'une fonction connue ; False si inconnue }
Function NameArgs(Const N:String;Var NI,NF:Integer):Boolean;
Var I,P,Q:Integer;S:String;
Begin
 NameArgs:=False;
 If N=''Then Exit;
 For I:=0 to NAPITAB-1 do Begin
  P:=Pos(' '+N+'=',ApiTab[I]);
  If P>0 Then Begin
   P:=P+Length(N)+2;
   NI:=0;NF:=0;
   S:='';
   While(P<=Length(ApiTab[I]))and(ApiTab[I][P]<>' ')do Begin S:=S+ApiTab[I][P];Inc(P);End;
   Q:=Pos(':',S);
   If Q>0 Then Begin
    NI:=Ord(S[1])-48;NF:=Ord(S[Q+1])-48;
   End
   Else Begin
    NI:=0;
    For Q:=1 to Length(S)do NI:=NI*10+Ord(S[Q])-48;
   End;
   NameArgs:=True;Exit;
  End;
 End;
End;

Function MaxSlotEnd(E:LongInt):LongInt;
Var A,B,C:LongInt;
Begin
 MaxSlotEnd:=0;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_SLOT:If Ex^[E].V>=PtrSz Then MaxSlotEnd:=Ex^[E].V+Ex^[E].Sz;
  EO_ADDRSLOT:If Ex^[E].V>=PtrSz Then MaxSlotEnd:=Ex^[E].V+PtrSz;
  EO_CONST,EO_VAR,EO_REG,EO_CC:;
  EO_MEM,EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:MaxSlotEnd:=MaxSlotEnd(Ex^[E].A);
  EO_INTR:MaxSlotEnd:=MaxSlotEnd(Ex^[E].B);
  Else Begin
   A:=MaxSlotEnd(Ex^[E].A);B:=MaxSlotEnd(Ex^[E].B);C:=0;
   If Ex^[E].Op=EO_TERN Then C:=MaxSlotEnd(Ex^[E].C);
   If B>A Then A:=B;
   If C>A Then A:=C;
   MaxSlotEnd:=A;
  End;
 End;
End;


{ pushes / pops symetriques de registres sauvegardes : masques }
Procedure HideSavedRegs;
Var K,R,B,J,NPush,NPop:LongInt;CS,PopM,PushM:Int64;
 PushIdx:Array[0..15] of LongInt;
 PopIdx:Array[0..15] of LongInt;
 Ok,FoundRet:Boolean;
Begin
 If CpuMode=64 Then Begin
  CS:=(Int64(1)shl 3)or(Int64(1)shl 5)or(Int64(1)shl 12)or(Int64(1)shl 13)or(Int64(1)shl 14)or(Int64(1)shl 15);
  If IsWin Then CS:=CS or(Int64(1)shl 6)or(Int64(1)shl 7);
 End
 Else CS:=(Int64(1)shl 3)or(Int64(1)shl 5)or(Int64(1)shl 6)or(Int64(1)shl 7);
 PopM:=0;PushM:=0;
 For K:=0 to NSt-1 do
  If(St^[K].Kind=ST_POP)and(Ex^[St^[K].A].Op=EO_REG)Then PopM:=PopM or(Int64(1)shl Ex^[St^[K].A].A);
 For K:=0 to NSt-1 do
  If(St^[K].Kind=ST_PUSH)and(Ex^[St^[K].A].Op=EO_REG)and(Ex^[St^[K].A].B=0)Then Begin
   R:=Ex^[St^[K].A].A;
   If(R<16)and(((Int64(1)shl R)and CS)<>0)and(((Int64(1)shl R)and PopM)<>0)Then Begin
    St^[K].FK:=1;PushM:=PushM or(Int64(1)shl R);
   End;
  End;
 For K:=0 to NSt-1 do
  If(St^[K].Kind=ST_POP)and(Ex^[St^[K].A].Op=EO_REG)Then
   If((Int64(1)shl Ex^[St^[K].A].A)and PushM)<>0 Then St^[K].FK:=1;
 { pushes d'alignement de la pile (push rcx ... pop rdx) en 64 bits }
 If CpuMode<>64 Then Exit;
 NPush:=0;
 For K:=SB0[EntryBlk] to SB0[EntryBlk]+SBN[EntryBlk]-1 do Begin
  If StmtHasCall(K)Then Break;
  If(St^[K].Kind=ST_PUSH)and(St^[K].FK=0)and(Ex^[St^[K].A].Op=EO_REG)and(NPush<16)Then Begin
   PushIdx[NPush]:=K;Inc(NPush);
  End;
 End;
 If NPush=0 Then Exit;
 FoundRet:=False;
 For B:=0 to NB-1 do
  If St^[SB0[B]+SBN[B]-1].Kind=ST_RET Then Begin
   NPop:=0;
   For J:=SB0[B]+SBN[B]-1 downto SB0[B] do
    If(St^[J].Kind=ST_POP)and(St^[J].FK=0)and(Ex^[St^[J].A].Op=EO_REG)and(NPop<16)Then Begin
     PopIdx[NPop]:=J;Inc(NPop);
    End;
   If NPop=NPush Then Begin
    For K:=0 to NPop-1 do St^[PopIdx[K]].FK:=1;
    FoundRet:=True;
   End;
  End;
 If FoundRet Then
  For K:=0 to NPush-1 do St^[PushIdx[K]].FK:=1;
End;

{ ---------- arguments des appels ---------- }
Function CallNode(K:LongInt):LongInt;
Begin
 CallNode:=-1;
 If St^[K].Kind=ST_ASSIGN Then Begin
  If(Ex^[St^[K].B].Op=EO_CALL)Then CallNode:=St^[K].B;
 End
 Else If St^[K].Kind=ST_TAIL Then CallNode:=St^[K].A
 Else If St^[K].Kind=ST_EXPR Then Begin
  If Ex^[St^[K].A].Op=EO_CALL Then CallNode:=St^[K].A;
 End;
End;

Procedure SetCallArgs(K,Args:LongInt;NInt:LongInt);
Var Old,N:LongInt;
Begin
 Old:=CallNode(K);
 N:=NewEx(EO_CALL,Ex^[Old].Sz,Ex^[Old].A,Args,NInt+1,0);
 If St^[K].Kind=ST_ASSIGN Then St^[K].B:=N
 Else St^[K].A:=N;
End;

{ renseignements sur le destinataire d'un appel }
Procedure CalleeInfo(CallN:LongInt;Var Known:Boolean;Var RegMask:LongInt;Var NStk,NFp,NInt:LongInt);
Var T,I,K:LongInt;Nm:String;Slot:Int64;NI,NF:Integer;
Begin
 Known:=False;RegMask:=0;NStk:=-1;NFp:=0;NInt:=-1;
 T:=Ex^[CallN].A;
 Nm:='';
 If Ex^[T].Op=EO_CONST Then Nm:=SymName(Ex^[T].V)
 Else If(Ex^[T].Op=EO_MEM)and(Ex^[Ex^[T].A].Op=EO_CONST)Then Begin
  Slot:=Ex^[Ex^[T].A].V;
  If CpuMode=32 Then Slot:=Slot and $FFFFFFFF;
  Nm:=ImportAt(Slot);
 End;
 If NameArgs(Nm,NI,NF)Then Begin
  Known:=True;NStk:=NI;NInt:=NI;NFp:=NF;
  Exit;
 End;
 If Ex^[T].Op=EO_CONST Then Begin
  I:=RootIdx(Ex^[T].V);
  If(I>=0)and SigOk[I]Then Begin
   Known:=True;RegMask:=SigMask[I];
   If SigPop[I]>=0 Then NStk:=SigPop[I]div PtrSz Else NStk:=SigStk[I];
   NFp:=SigFp[I];
   NInt:=0;
   For K:=0 to NArgRegs-1 do If(RegMask and(1 shl K))<>0 Then NInt:=K+1;
  End;
 End;
End;

{ indice d'un argument sortant si l'adresse est [esp+4*k] (avant normalisation de la pile) }
Function OutArgIndex(Addr:LongInt):LongInt;
Var A:LongInt;C:Int64;
Begin
 OutArgIndex:=-1;
 C:=0;
 If(Ex^[Addr].Op=EO_ADD)and(Ex^[Ex^[Addr].B].Op=EO_CONST)Then Begin
  C:=Ex^[Ex^[Addr].B].V;A:=Ex^[Addr].A;
 End
 Else A:=Addr;
 If(Ex^[A].Op=EO_REG)and(Ex^[A].A=4)and(Ex^[A].Sz=PtrSz)and(C>=0)and(C<128)and((C mod PtrSz)=0)Then
  OutArgIndex:=C div PtrSz;
End;

Procedure ArgGather32;
Var
 B,C,J,Q,T,Cnt,NArgs,First,Last,V,K,NOut:LongInt;
 OutIdx:Array[0..31] of LongInt;
 PushIdx:Array[0..31] of LongInt;
 Args,Tmp:LongInt;
 Conflict:Boolean;
 Src:LongInt;
 Known:Boolean;
 RegMask,NStk,NFp,NInt:LongInt;
Begin
 For B:=0 to NB-1 do Begin
  First:=SB0[B];Last:=SB0[B]+SBN[B]-1;
  For C:=First to Last do Begin
   If CallNode(C)<0 Then Continue;
   CalleeInfo(CallNode(C),Known,RegMask,NStk,NFp,NInt);
   { nettoyage de la pile apres l'appel : add esp,N }
   NArgs:=-1;
   For J:=C+1 to Last do Begin
    If St^[J].Kind=ST_NOP Then Continue;
    If StmtHasCall(J)Then Break;
    If(St^[J].Kind=ST_ASSIGN)and(Ex^[St^[J].A].Op=EO_REG)and(Ex^[St^[J].A].A=4)Then Begin
     Src:=St^[J].B;
     If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].A].Op=EO_REG)and(Ex^[Ex^[Src].A].A=4)and
       (Ex^[Ex^[Src].B].Op=EO_CONST)and(Ex^[Ex^[Src].B].V>0)Then
      NArgs:=Ex^[Ex^[Src].B].V div PtrSz;
     Break;
    End;
    If St^[J].Kind in[ST_PUSH,ST_POP]Then Break;
   End;
   If Known and(NStk>=0)Then NArgs:=NStk;
   { pushes precedents }
   Cnt:=0;
   J:=C-1;
   While(J>=First)and(Cnt<32)and((NArgs<0)or(Cnt<NArgs))do Begin
    Case St^[J].Kind of
     ST_NOP:;
     ST_PUSH:Begin
      If St^[J].FK=1 Then Break;
      PushIdx[Cnt]:=J;Inc(Cnt);
     End;
     ST_ASSIGN:Begin
      If StmtHasCall(J)and(St^[J].FK<>1)Then Break;
      If(Ex^[St^[J].A].Op=EO_REG)and(Ex^[St^[J].A].A=4)Then Break;
     End;
     ST_STORE,ST_FLAGS:If StmtHasCall(J)Then Break;
     Else Break;
    End;
    Dec(J);
   End;
   If(NArgs>=0)or Known Then St^[C].FK:=1;
   Args:=-1;
   For T:=Cnt-1 downto 0 do Begin
    Q:=PushIdx[T];
    V:=St^[Q].A;
    { conflit : valeur modifiee entre le push et l'appel ? }
    Conflict:=False;
    For J:=Q+1 to C-1 do Begin
     If St^[J].Kind=ST_NOP Then Continue;
     If(St^[J].Kind=ST_PUSH)Then Continue;
     If(StmtDefMask(J)and ExprUses(V))<>0 Then Conflict:=True;
     If ExprHasMem(V)and StmtWritesMem(J)Then Conflict:=True;
    End;
    If Conflict Then Begin
     Inc(TmpCount);
     Tmp:=MkVar('a'+LStr(TmpCount),PtrSz);
     St^[Q].Kind:=ST_ASSIGN;St^[Q].A:=Tmp;St^[Q].B:=V;St^[Q].FK:=0;
     V:=Tmp;
    End
    Else Begin
     St^[Q].Kind:=ST_NOP;
    End;
    Args:=MkList(V,Args);
   End;
   { arguments ecrits dans la zone de parametres sortants : mov [esp+k],v }
   If Cnt=0 Then Begin
    For K:=0 to 31 do OutIdx[K]:=-1;
    For J:=C-1 downto First do Begin
     If St^[J].Kind=ST_NOP Then Continue;
     If St^[J].Kind=ST_STORE Then Begin
      K:=OutArgIndex(Ex^[St^[J].A].A);
      If(K>=0)and(K<32)and(OutIdx[K]<0)Then OutIdx[K]:=J;
     End
     Else If St^[J].Kind=ST_ASSIGN Then Begin
      If StmtHasCall(J)and(St^[J].FK<>1)Then Break;
      If(Ex^[St^[J].A].Op=EO_REG)and(Ex^[St^[J].A].A=4)Then Break;
     End
     Else If St^[J].Kind<>ST_FLAGS Then Break;
    End;
    NOut:=0;
    While(NOut<32)and(OutIdx[NOut]>=0)do Inc(NOut);
    If Known and(NStk>=0)and(NOut>NStk)Then NOut:=NStk;
    For T:=NOut-1 downto 0 do Begin
     Q:=OutIdx[T];
     V:=St^[Q].B;
     Conflict:=False;
     For J:=Q+1 to C-1 do Begin
      If St^[J].Kind=ST_NOP Then Continue;
      If(StmtDefMask(J)and ExprUses(V))<>0 Then Conflict:=True;
      If ExprHasMem(V)and(St^[J].Kind<>ST_STORE)and StmtWritesMem(J)Then Conflict:=True;
     End;
     If Conflict Then Begin
      Inc(TmpCount);
      Tmp:=MkVar('a'+LStr(TmpCount),PtrSz);
      St^[Q].Kind:=ST_ASSIGN;St^[Q].A:=Tmp;St^[Q].B:=V;St^[Q].FK:=0;
      V:=Tmp;
     End
     Else St^[Q].Kind:=ST_NOP;
     Args:=MkList(V,Args);
    End;
    If NOut>0 Then Cnt:=NOut;
   End;
   { arguments passes dans des registres (eax, edx, ecx) }
   If Known Then
    For K:=NArgRegs-1 downto 0 do
     If(RegMask and(1 shl K))<>0 Then Args:=MkList(MkReg(ArgRegs[K],4,False),Args);
   If(Cnt>0)or(Args>=0)Then SetCallArgs(C,Args,-1);
  End;
 End;
End;

Procedure ArgGather64;
Var
 B,C,J,K,Hi,Fp:LongInt;
 First,Last:LongInt;
 DefSz:Array[0..5] of Integer;
 FpDef:Array[0..7] of Boolean;
 Args:LongInt;
 R:LongInt;
 D:LongInt;
 Known:Boolean;
 RegMask,NStk,NFp,NInt:LongInt;
Begin
 For B:=0 to NB-1 do Begin
  First:=SB0[B];Last:=SB0[B]+SBN[B]-1;
  For C:=First to Last do Begin
   If CallNode(C)<0 Then Continue;
   CalleeInfo(CallNode(C),Known,RegMask,NStk,NFp,NInt);
   FillChar(DefSz,SizeOf(DefSz),0);
   FillChar(FpDef,SizeOf(FpDef),False);
   For J:=C-1 downto First do Begin
    If St^[J].Kind=ST_NOP Then Continue;
    If(StmtHasCall(J))or(St^[J].Kind=ST_ASM)Then Break;
    If(St^[J].Kind=ST_ASSIGN)and(Ex^[St^[J].A].Op=EO_REG)Then Begin
     D:=St^[J].A;
     R:=Ex^[D].A;
     If R>=16 Then Begin
      If(R<24)Then FpDef[R-16]:=True;
     End
     Else For K:=0 to NArgRegs-1 do
      If(ArgRegs[K]=R)and(DefSz[K]=0)Then DefSz[K]:=Ex^[D].Sz;
    End;
   End;
   Hi:=-1;
   For K:=0 to NArgRegs-1 do If DefSz[K]>0 Then Hi:=K;
   Fp:=-1;
   For K:=7 downto 0 do If FpDef[K]Then Begin Fp:=K;Break;End;
   If Known Then Begin
    Hi:=NInt-1;Fp:=NFp-1;
    If Hi>=NArgRegs Then Hi:=NArgRegs-1;
   End;
   Args:=-1;
   For K:=Fp downto 0 do Args:=MkList(MkReg(16+K,16,False),Args);
   For K:=Hi downto 0 do Begin
    If DefSz[K]>0 Then Args:=MkList(MkReg(ArgRegs[K],DefSz[K],False),Args)
    Else Args:=MkList(MkReg(ArgRegs[K],8,False),Args);
   End;
   SetCallArgs(C,Args,Hi+1);
  End;
 End;
End;

{ ---------- normalisation des acces a la pile ---------- }
Function StackSlotOf(Addr:LongInt;Sp:LongInt;Var Slot:LongInt):Boolean;
Var A:LongInt;C:Int64;
Begin
 StackSlotOf:=False;
 C:=0;
 If(Ex^[Addr].Op=EO_ADD)and(Ex^[Ex^[Addr].B].Op=EO_CONST)Then Begin
  C:=Ex^[Ex^[Addr].B].V;A:=Ex^[Addr].A;
 End
 Else A:=Addr;
 If(Ex^[A].Op=EO_REG)and(Ex^[A].Sz=PtrSz)and(Ex^[A].B=0)Then Begin
  If Ex^[A].A=4 Then Begin Slot:=Sp+C;StackSlotOf:=True;End
  Else If(Ex^[A].A=5)and HasFrame Then Begin Slot:=FrameSlot+C;StackSlotOf:=True;End;
 End;
End;

Type
 TChain = Record
  Cst:Int64;
  BaseSet:Boolean;
  BaseSlot:LongInt;
  Rest:LongInt;
 End;

Function NormE(E:LongInt;Sp:LongInt):LongInt;forward;

Procedure Collect(E,Sp:LongInt;Var C:TChain);
Var X:LongInt;
Begin
 Case Ex^[E].Op of
  EO_ADD:Begin Collect(Ex^[E].A,Sp,C);Collect(Ex^[E].B,Sp,C);End;
  EO_CONST:C.Cst:=C.Cst+Ex^[E].V;
  EO_REG:Begin
   If(Ex^[E].B=0)and(Ex^[E].Sz=PtrSz)and not C.BaseSet and((Ex^[E].A=4)or((Ex^[E].A=5)and HasFrame))Then Begin
    C.BaseSet:=True;
    If Ex^[E].A=4 Then C.BaseSlot:=Sp Else C.BaseSlot:=FrameSlot;
   End
   Else Begin
    If C.Rest<0 Then C.Rest:=E Else C.Rest:=MkBin(EO_ADD,C.Rest,E,PtrSz);
   End;
  End;
  Else Begin
   X:=NormE(E,Sp);
   If C.Rest<0 Then C.Rest:=X Else C.Rest:=MkBin(EO_ADD,C.Rest,X,PtrSz);
  End;
 End;
End;

Function NormE(E:LongInt;Sp:LongInt):LongInt;
Var T:TExpr;A,B,C,Slot:LongInt;N:LongInt;Ch:TChain;
Begin
 NormE:=E;
 If E<0 Then Exit;
 T:=Ex^[E];
 Case T.Op of
  EO_CONST,EO_VAR,EO_REG,EO_CC,EO_SLOT,EO_ADDRSLOT:Exit;
  EO_MEM:Begin
   If StackSlotOf(T.A,Sp,Slot)Then Begin
    N:=NewEx(EO_SLOT,T.Sz,0,T.B,0,Slot);
    NormE:=N;Exit;
   End;
   A:=NormE(T.A,Sp);
   If A<>T.A Then NormE:=NewEx(EO_MEM,T.Sz,A,T.B,0,0);
   Exit;
  End;
  EO_ADD:Begin
   If StackSlotOf(E,Sp,Slot)Then Begin
    NormE:=NewEx(EO_ADDRSLOT,T.Sz,0,0,0,Slot);Exit;
   End;
   Ch.Cst:=0;Ch.BaseSet:=False;Ch.Rest:=-1;Ch.BaseSlot:=0;
   Collect(E,Sp,Ch);
   If Ch.BaseSet and(Ch.Rest>=0)Then Begin
    N:=NewEx(EO_ADDRSLOT,PtrSz,0,0,0,Ch.BaseSlot+Ch.Cst);
    NormE:=MkBin(EO_ADD,N,Ch.Rest,PtrSz);
    Exit;
   End;
  End;
 End;
 A:=T.A;B:=T.B;C:=T.C;
 Case T.Op of
  EO_NEG,EO_NOT,EO_LNOT,EO_ZEXT,EO_SEXT,EO_TRUNC:A:=NormE(T.A,Sp);
  EO_TERN:Begin A:=NormE(T.A,Sp);B:=NormE(T.B,Sp);C:=NormE(T.C,Sp);End;
  EO_INTR:B:=NormE(T.B,Sp);
  Else Begin A:=NormE(T.A,Sp);B:=NormE(T.B,Sp);End;
 End;
 If(A=T.A)and(B=T.B)and(C=T.C)Then Exit;
 NormE:=NewEx(T.Op,T.Sz,A,B,C,T.V);
End;

Procedure StackNorm;
Var
 Stack:Array[0..MAXBLK] of LongInt;
 SP,B,K,Sof,Src,Dst:LongInt;
 First,Last,S:LongInt;
 Sz:LongInt;
Begin
 FillChar(SpSet,SizeOf(SpSet),False);
 SP:=0;
 Stack[SP]:=EntryBlk;Inc(SP);
 SpIn[EntryBlk]:=0;SpSet[EntryBlk]:=True;
 While SP>0 do Begin
  Dec(SP);
  B:=Stack[SP];
  Sof:=SpIn[B];
  First:=SB0[B];Last:=SB0[B]+SBN[B]-1;
  For K:=First to Last do Begin
   Case St^[K].Kind of
    ST_NOP:;
    ST_PUSH:Begin
     St^[K].A:=NormE(St^[K].A,Sof);
     Sz:=St^[K].Sz;If Sz=0 Then Sz:=PtrSz;
     Sof:=Sof-Sz;
    End;
    ST_POP:Begin
     If Ex^[St^[K].A].Op=EO_MEM Then St^[K].A:=NormE(St^[K].A,Sof);
     Sz:=St^[K].Sz;If Sz=0 Then Sz:=PtrSz;
     Sof:=Sof+Sz;
    End;
    ST_ASSIGN:Begin
     Dst:=St^[K].A;Src:=St^[K].B;
     If(Ex^[Dst].Op=EO_REG)and(Ex^[Dst].A=4)and(Ex^[Dst].Sz=PtrSz)Then Begin
      { modification du pointeur de pile }
      If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].A].Op=EO_REG)and(Ex^[Ex^[Src].A].A=4)and(Ex^[Ex^[Src].B].Op=EO_CONST)Then
       Sof:=Sof+Ex^[Ex^[Src].B].V
      Else If(Ex^[Src].Op=EO_REG)and(Ex^[Src].A=5)and HasFrame Then Sof:=FrameSlot
      Else If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].A].Op=EO_REG)and(Ex^[Ex^[Src].A].A=5)and
             (Ex^[Ex^[Src].B].Op=EO_CONST)and HasFrame Then Sof:=FrameSlot+Ex^[Ex^[Src].B].V;
     End
     Else If(Ex^[Dst].Op=EO_REG)and(Ex^[Dst].A=5)and(Ex^[Dst].Sz=PtrSz)and(Ex^[Src].Op=EO_REG)and
             (Ex^[Src].A=4)and not HasFrame and(B=EntryBlk)Then Begin
      HasFrame:=True;FrameSlot:=Sof;
      St^[K].Kind:=ST_NOP;
     End
     Else Begin
      St^[K].B:=NormE(Src,Sof);
      If Ex^[Dst].Op=EO_MEM Then St^[K].A:=NormE(Dst,Sof);
     End;
    End;
    ST_STORE:Begin
     St^[K].A:=NormE(St^[K].A,Sof);St^[K].B:=NormE(St^[K].B,Sof);
    End;
    ST_FLAGS:Begin
     St^[K].A:=NormE(St^[K].A,Sof);St^[K].B:=NormE(St^[K].B,Sof);
    End;
    ST_EXPR,ST_JCC,ST_IJMP,ST_TAIL:St^[K].A:=NormE(St^[K].A,Sof);
   End;
  End;
  For K:=0 to NSucc(B)-1 do Begin
   S:=SuccOf(B,K);
   If not SpSet[S]Then Begin
    SpSet[S]:=True;SpIn[S]:=Sof;
    Stack[SP]:=S;Inc(SP);
   End;
  End;
 End;
End;

{ masque les modifications de esp / rsp }
Procedure NopStackRegs;
Var K,D:LongInt;
Begin
 For K:=0 to NSt-1 do
  If(St^[K].Kind=ST_ASSIGN)Then Begin
   D:=St^[K].A;
   If(Ex^[D].Op=EO_REG)and(Ex^[D].A=4)Then St^[K].Kind:=ST_NOP;
  End;
End;

{ ---------- vivacite ---------- }
Function Transfer(K:LongInt;Live:Int64):Int64;
Var D:LongInt;FullSz:Integer;
Begin
 If CpuMode=16 Then FullSz:=2 Else FullSz:=4;
 Case St^[K].Kind of
  ST_NOP:;
  ST_ASSIGN:Begin
   D:=St^[K].A;
   If Ex^[D].Op=EO_REG Then Begin
    If(Ex^[D].B=0)and((Ex^[D].Sz>=FullSz)or(Ex^[D].A>=16))Then Live:=Live and not(Int64(1)shl Ex^[D].A);
   End
   Else If Ex^[D].Op=EO_MEM Then Live:=Live or ExprUses(D);
   If ExprHasCall(St^[K].B)Then Live:=Live and not VolMask;
   Live:=Live or ExprUses(St^[K].B);
  End;
  ST_STORE:Live:=Live or ExprUses(St^[K].A)or ExprUses(St^[K].B);
  ST_FLAGS:Begin
   If(Live and FLAGS_BIT)<>0 Then
    Live:=(Live and not FLAGS_BIT)or ExprUses(St^[K].A)or ExprUses(St^[K].B);
  End;
  ST_PUSH:If St^[K].FK<>1 Then Live:=Live or ExprUses(St^[K].A);
  ST_POP:Begin
   D:=St^[K].A;
   If Ex^[D].Op=EO_REG Then Begin
    If(Ex^[D].B=0)and((Ex^[D].Sz>=FullSz)or(Ex^[D].A>=16))Then Live:=Live and not(Int64(1)shl Ex^[D].A);
   End
   Else Live:=Live or ExprUses(D);
  End;
  ST_EXPR:Begin
   If ExprHasCall(St^[K].A)Then Live:=Live and not VolMask;
   Live:=Live or ExprUses(St^[K].A);
  End;
  ST_ASM:Begin
   If St^[K].B=-1 Then Live:=Live or $FFFF or FLAGS_BIT
   Else Live:=Live or St^[K].B or FLAGS_BIT;
  End;
  ST_JCC,ST_IJMP:Live:=Live or ExprUses(St^[K].A);
  ST_TAIL:Begin
   Live:=Live and not VolMask;
   Live:=Live or ExprUses(St^[K].A);
  End;
  ST_RET:If St^[K].FK=2 Then Live:=Live or(Int64(1)shl 16) Else If St^[K].FK=1 Then Live:=Live or 1;
 End;
 Transfer:=Live;
End;

Procedure Liveness;
Var B,K,S:LongInt;Out_,L:Int64;Changed:Boolean;Iter:Integer;
Begin
 For B:=0 to NB-1 do Begin LiveIn[B]:=0;LiveOut[B]:=0;End;
 Iter:=0;
 Repeat
  Changed:=False;
  For B:=NB-1 downto 0 do Begin
   Out_:=0;
   For K:=0 to NSucc(B)-1 do Out_:=Out_ or LiveIn[SuccOf(B,K)];
   L:=Out_;
   For K:=SB0[B]+SBN[B]-1 downto SB0[B] do L:=Transfer(K,L);
   If(Out_<>LiveOut[B])or(L<>LiveIn[B])Then Begin
    LiveOut[B]:=Out_;LiveIn[B]:=L;Changed:=True;
   End;
  End;
  Inc(Iter);
 Until not Changed or(Iter>60);
End;

{ elimination du code mort ; retourne True si quelque chose a change }
Function DeadCode:Boolean;
Var B,K,D:LongInt;L:Int64;Chg,Dead:Boolean;
Begin
 Chg:=False;
 For B:=0 to NB-1 do Begin
  L:=LiveOut[B];
  For K:=SB0[B]+SBN[B]-1 downto SB0[B] do Begin
   Dead:=False;
   Case St^[K].Kind of
    ST_ASSIGN:Begin
     D:=St^[K].A;
     If(Ex^[D].Op=EO_REG)and(Ex^[D].A<>4)and((L and(Int64(1)shl Ex^[D].A))=0)Then Begin
      If ExprHasCall(St^[K].B)Then Begin
       If(Ex^[D].A=0)and((L and(Int64(1)shl 16))<>0)and(Ex^[St^[K].B].Op=EO_CALL)Then
        St^[K].A:=MkReg(16,16,False)
       Else Begin
        St^[K].Kind:=ST_EXPR;St^[K].A:=St^[K].B;St^[K].B:=-1;Chg:=True;
       End;
      End
      Else Dead:=True;
     End;
    End;
    ST_POP:Begin
     D:=St^[K].A;
     If(Ex^[D].Op=EO_REG)and((L and(Int64(1)shl Ex^[D].A))=0)Then Dead:=True;
    End;
    ST_FLAGS:If(L and FLAGS_BIT)=0 Then Dead:=True;
   End;
   If Dead Then Begin
    St^[K].Kind:=ST_NOP;Chg:=True;
   End
   Else L:=Transfer(K,L);
  End;
 End;
 DeadCode:=Chg;
End;

{ ---------- propagation locale d'expressions ---------- }
Function RegDeadAfter(B,From,R:LongInt):Boolean;
Var K:LongInt;
Begin
 RegDeadAfter:=False;
 For K:=From to SB0[B]+SBN[B]-1 do Begin
  If St^[K].Kind=ST_NOP Then Continue;
  If StmtReadCount(K,R)>0 Then Exit;
  If StmtKills(K,R)Then Begin RegDeadAfter:=True;Exit;End;
 End;
 RegDeadAfter:=(LiveOut[B]and(Int64(1)shl R))=0;
End;

Function UseSize(K,R:LongInt):Integer;
Var X:Integer;
Begin
 X:=0;
 Case St^[K].Kind of
  ST_ASSIGN:X:=RegSizeIn(St^[K].B,R);
  ST_STORE,ST_FLAGS:Begin
   X:=RegSizeIn(St^[K].A,R);
   If X=0 Then X:=RegSizeIn(St^[K].B,R);
  End;
  Else X:=RegSizeIn(St^[K].A,R);
 End;
 UseSize:=X;
End;

Function TryPropagate(B,I:LongInt):Boolean;
Var
 R,DSz,J,C,Last,USz:LongInt;
 E:LongInt;
 Uses_:Int64;
 HasMem,HasCall,HasCC,Dead:Boolean;
 D:LongInt;
Begin
 TryPropagate:=False;
 D:=St^[I].A;
 If(Ex^[D].Op<>EO_REG)or(Ex^[D].B<>0)Then Exit;
 R:=Ex^[D].A;DSz:=Ex^[D].Sz;
 If R=4 Then Exit;
 E:=St^[I].B;
 Uses_:=ExprUses(E);HasMem:=ExprHasMem(E);HasCall:=ExprHasCall(E);HasCC:=(Uses_ and FLAGS_BIT)<>0;
 If ExprNodes(E,25)>=25 Then Exit;
 Last:=SB0[B]+SBN[B]-1;
 For J:=I+1 to Last do Begin
  If St^[J].Kind=ST_NOP Then Continue;
  C:=StmtReadCount(J,R);
  If C>0 Then Begin
   If C<>1 Then Exit;
   If St^[J].Kind in[ST_RET,ST_ASM]Then Exit;
   If HasCC and(St^[J].Kind=ST_FLAGS)Then Exit;
   USz:=UseSize(J,R);
   If USz<=0 Then Exit;
   If not((USz=DSz)or(USz<DSz)or((DSz=4)and(CpuMode=64)))Then Exit;
   If(St^[J].Kind=ST_ASSIGN)and(Ex^[St^[J].A].Op=EO_REG)and(Ex^[St^[J].A].A=R)and(Ex^[St^[J].A].Sz<>USz)Then Exit;
   If StmtKills(J,R)Then Dead:=True Else Dead:=RegDeadAfter(B,J+1,R);
   If not Dead Then Exit;
   StmtSubst(J,R,DSz,E);
   St^[I].Kind:=ST_NOP;
   TryPropagate:=True;
   Exit;
  End;
  If(StmtDefMask(J)and(Int64(1)shl R))<>0 Then Exit;
  If(StmtDefMask(J)and Uses_)<>0 Then Exit;
  If HasMem and StmtWritesMem(J)Then Exit;
  If HasCall and(StmtReadsMem(J)or StmtWritesMem(J)or StmtHasCall(J))Then Exit;
  If HasCC and((St^[J].Kind=ST_FLAGS)or StmtHasCall(J))Then Exit;
 End;
End;

{ propagation des copies registre/constante vers plusieurs utilisations }
Function PropCopies:Boolean;
Var B,I,J,R,R2,Last,Sz,D,Src,OA,OB:LongInt;Chg,MemSrc:Boolean;Rd:Int64;
Begin
 Chg:=False;
 For B:=0 to NB-1 do Begin
  Last:=SB0[B]+SBN[B]-1;
  For I:=SB0[B] to Last do Begin
   If St^[I].Kind<>ST_ASSIGN Then Continue;
   D:=St^[I].A;Src:=St^[I].B;
   If(Ex^[D].Op<>EO_REG)or(Ex^[D].B<>0)Then Continue;
   R:=Ex^[D].A;Sz:=Ex^[D].Sz;
   If(R=4)or(R>=16)Then Continue;
   MemSrc:=False;
   If(Ex^[Src].Op=EO_CONST)or(Ex^[Src].Op=EO_ADDRSLOT)Then R2:=-1
   Else If(Ex^[Src].Op=EO_SLOT)and(Ex^[Src].Sz=Sz)Then Begin R2:=-1;MemSrc:=True;End
   Else If(Ex^[Src].Op=EO_REG)and(Ex^[Src].B=0)and(Ex^[Src].Sz=Sz)and(Ex^[Src].A<>R)and(Ex^[Src].A<16)Then
    R2:=Ex^[Src].A
   Else Continue;
   Rd:=Int64(1)shl R;
   For J:=I+1 to Last do Begin
    If St^[J].Kind=ST_NOP Then Continue;
    If St^[J].Kind=ST_ASM Then Break;
    If(St^[J].Kind<>ST_RET)and(StmtReadCount(J,R)>0)Then Begin
     OA:=St^[J].A;OB:=St^[J].B;
     StmtSubst(J,R,Sz,Src);
     If(OA<>St^[J].A)or(OB<>St^[J].B)Then Chg:=True;
    End;
    If(StmtDefMask(J)and Rd)<>0 Then Break;
    If(R2>=0)and((StmtDefMask(J)and(Int64(1)shl R2))<>0)Then Break;
    If MemSrc and StmtWritesMem(J)Then Break;
   End;
  End;
 End;
 PropCopies:=Chg;
End;

Function Propagate:Boolean;
Var B,I:LongInt;Chg:Boolean;
Begin
 Chg:=False;
 For B:=0 to NB-1 do
  For I:=SB0[B] to SB0[B]+SBN[B]-1 do
   If St^[I].Kind=ST_ASSIGN Then
    If TryPropagate(B,I)Then Chg:=True;
 Propagate:=Chg;
End;

Procedure Optimize;
Var Iter:Integer;Chg:Boolean;
Begin
 Iter:=0;
 Repeat
  Chg:=False;
  Liveness;
  If DeadCode Then Chg:=True;
  Liveness;
  If PropCopies Then Chg:=True;
  If Propagate Then Chg:=True;
  Inc(Iter);
 Until not Chg or(Iter>8);
 Liveness;
 DeadCode;
 Liveness;
End;

{ dernier registre de retour defini avant la position Pos du bloc B }
Var
 RdVis:Array[0..MAXBLK-1] of LongInt;
 RdStamp:LongInt;

Procedure RetDefScan(B,Pos:LongInt;Depth:Integer;Var Found:Integer;Var MaxSz:LongInt);
Var J,D,K,P,Src,CN,KI:LongInt;
Begin
 For J:=Pos-1 downto SB0[B] do Begin
  If St^[J].Kind=ST_NOP Then Continue;
  If St^[J].Kind in[ST_ASSIGN,ST_POP]Then Begin
   D:=St^[J].A;
   If(Ex^[D].Op=EO_REG)and((Ex^[D].A=0)or(Ex^[D].A=16))and(Ex^[D].B=0)Then Begin
    If Ex^[D].A=0 Then Begin
     Found:=Found or 1;
     K:=Ex^[D].Sz;
     If St^[J].Kind=ST_ASSIGN Then Begin
      Src:=St^[J].B;
      If Ex^[Src].Op=EO_CALL Then Begin
       K:=PtrSz;
       If Ex^[Src].Sz<K Then K:=Ex^[Src].Sz;
      End
      Else If(K=8)and(Ex^[Src].Op=EO_ZEXT)and(ExSz(Ex^[Src].A)<=4)Then K:=4
      Else If(K=8)and(Ex^[Src].Op=EO_CONST)and(Ex^[Src].V>=0)and(Ex^[Src].V<=$FFFFFFFF)Then K:=4;
     End;
     If K>MaxSz Then MaxSz:=K;
    End
    Else Found:=Found or 2;
    Exit;
   End;
  End
  Else If(St^[J].Kind=ST_EXPR)and ExprHasCall(St^[J].A)Then Begin
   CN:=St^[J].A;
   KI:=-1;
   If(Ex^[CN].Op=EO_CALL)and(Ex^[Ex^[CN].A].Op=EO_CONST)Then KI:=RootIdx(Ex^[Ex^[CN].A].V);
   If(KI>=0)and SigOk[KI]and(SigRet[KI]=0)Then Exit;
   Found:=Found or 1;
   If PtrSz>MaxSz Then MaxSz:=PtrSz;
   Exit;
  End;
 End;
 If Depth>=8 Then Exit;
 For K:=0 to PredCnt[B]-1 do Begin
  P:=PredPool[PredStart[B]+K];
  If RdVis[P]<>RdStamp Then Begin
   RdVis[P]:=RdStamp;
   RetDefScan(P,SB0[P]+SBN[P],Depth+1,Found,MaxSz);
  End;
 End;
End;

Function FindRetDef(B,Pos:LongInt;Var Canon,Sz:LongInt):Boolean;
Var Found:Integer;MaxSz:LongInt;
Begin
 Inc(RdStamp);
 RdVis[B]:=RdStamp;
 Found:=0;MaxSz:=0;
 RetDefScan(B,Pos,0,Found,MaxSz);
 FindRetDef:=Found<>0;
 If(Found and 1)<>0 Then Begin Canon:=0;Sz:=MaxSz;End
 Else If(Found and 2)<>0 Then Begin Canon:=16;Sz:=16;End;
End;

{ determine quel registre est lu par chaque ret }
Procedure AssignRetUse;
Var B,T,C,S:LongInt;
Begin
 For B:=0 to NB-1 do Begin
  T:=SB0[B]+SBN[B]-1;
  If St^[T].Kind=ST_RET Then Begin
   If FindRetDef(B,T,C,S)Then Begin
    If C=16 Then St^[T].FK:=2 Else St^[T].FK:=1;
   End
   Else St^[T].FK:=0;
  End;
 End;
End;

{ memorise la signature de la fonction courante }
Procedure RecordSig;
Var I,K,B,J,Mx,X:LongInt;Fnd:Integer;AnyDef,HasEnd:Boolean;
Begin
 I:=RootIdx(FnEntry);
 If I<0 Then Exit;
 SigMask[I]:=0;SigFp[I]:=0;SigStk[I]:=0;SigPop[I]:=-1;
 For K:=0 to NArgRegs-1 do
  If(LiveIn[EntryBlk]and(Int64(1)shl ArgRegs[K]))<>0 Then SigMask[I]:=SigMask[I]or(1 shl K);
 If CpuMode=64 Then
  For K:=0 to 7 do
   If(LiveIn[EntryBlk]and(Int64(1)shl(16+K)))<>0 Then SigFp[I]:=K+1;
 Mx:=0;
 If CpuMode<>64 Then
  For J:=0 to NSt-1 do
   If St^[J].Kind<>ST_NOP Then Begin
    X:=MaxSlotEnd(St^[J].A);
    If X>Mx Then Mx:=X;
    If St^[J].Kind in[ST_ASSIGN,ST_STORE,ST_FLAGS]Then Begin
     X:=MaxSlotEnd(St^[J].B);
     If X>Mx Then Mx:=X;
    End;
   End;
 If Mx>0 Then Begin
  X:=(Mx-PtrSz+PtrSz-1)div PtrSz;
  If X>100 Then X:=100;
  SigStk[I]:=X;
 End;
 For B:=0 to NB-1 do
  If BKind[B]=BK_RET Then Begin
   If((Ins^[BLast(B)].Mn='ret')or(Ins^[BLast(B)].Mn='retf'))and(Ins^[BLast(B)].N>=1)Then
    SigPop[I]:=Ins^[BLast(B)].Op[0].Disp;
   Break;
  End;
 { type de retour }
 SigRet[I]:=8;
 AnyDef:=False;HasEnd:=False;
 For J:=0 to NSt-1 do Begin
  Case St^[J].Kind of
   ST_ASSIGN,ST_POP:If(Ex^[St^[J].A].Op=EO_REG)and((Ex^[St^[J].A].A=0)or(Ex^[St^[J].A].A=16))Then AnyDef:=True;
   ST_ASM:AnyDef:=True;
   ST_TAIL,ST_IJMP:HasEnd:=True;
  End;
  If(St^[J].Kind in[ST_ASSIGN,ST_EXPR])and StmtHasCall(J)Then AnyDef:=True;
 End;
 If not HasEnd Then Begin
  If not AnyDef Then SigRet[I]:=0
  Else Begin
   Fnd:=0;Mx:=0;
   For B:=0 to NB-1 do
    If St^[SB0[B]+SBN[B]-1].Kind=ST_RET Then Begin
     Inc(RdStamp);RdVis[B]:=RdStamp;
     RetDefScan(B,SB0[B]+SBN[B]-1,0,Fnd,Mx);
    End;
   If(Fnd and 1)<>0 Then Begin
    If CpuMode<>64 Then SigRet[I]:=PtrSz
    Else If Mx>=8 Then SigRet[I]:=8 Else SigRet[I]:=4;
   End
   Else If(Fnd and 2)<>0 Then SigRet[I]:=16;
  End;
 End;
 SigOk[I]:=True;
End;

Procedure AnalyzeFunction;
Var K:LongInt;
Begin
 InitCtx;
 BuildPreds;
 EntryBlk:=FindBlock(FnEntry);
 If EntryBlk<0 Then EntryBlk:=0;
 ScanWidths;
 LiftFunction;
 MarkPrologue;
 AssignRetUse;
 HideSavedRegs;
 If CpuMode<>64 Then ArgGather32
 Else ArgGather64;
 StackNorm;
 NopStackRegs;
 Optimize;
 { les parametres sont calcules sans l'utilisation implicite des ret }
 For K:=0 to NSt-1 do
  If St^[K].Kind=ST_RET Then St^[K].FK:=0;
 IgnoreMerge:=True;
 Liveness;
 IgnoreMerge:=False;
 RecordSig;
End;

{ ============================================================
  ANALYSE STRUCTURELLE : DOMINATEURS, BOUCLES, REGIONS
  ============================================================ }
Const
 MAXREG = 40000;

 RG_BLOCK  = 1;
 RG_IF     = 2;
 RG_WHILE  = 3;
 RG_DOWHILE= 4;
 RG_LOOP   = 5;
 RG_GOTO   = 6;
 RG_BREAK  = 7;
 RG_CONT   = 8;
 RG_TAIL   = 9;
 RG_SWITCH = 10;
 RG_CASE   = 11;

Var
 GRev:Boolean;
 TermList:Array[0..MAXBLK] of LongInt;
 NTerm:LongInt;
 PoNum,PoOrder:Array[0..MAXBLK] of LongInt;
 NPo:LongInt;
 DomRes:Array[0..MAXBLK] of LongInt;
 IDomF,IPDom:Array[0..MAXBLK] of LongInt;
 RpoIdx:Array[0..MAXBLK] of LongInt;
 IsHdr:Array[0..MAXBLK] of Boolean;

 { regions }
 NReg:LongInt;
 RT:Array[0..MAXREG-1] of Byte;
 RB:Array[0..MAXREG-1] of LongInt;
 RC1,RC2,RNx:Array[0..MAXREG-1] of LongInt;
 RNeg:Array[0..MAXREG-1] of Boolean;
 RKind:Array[0..MAXREG-1] of Byte;      { pour WHILE : 1 si l'entete contient des statements }
 FnRoot:LongInt;
 Done,Labeled:Array[0..MAXBLK] of Boolean;
 InBody:Array[0..MAXBLK] of Boolean;
 StopSt:Array[0..4096] of LongInt;
 StopD:LongInt;
 LpHdr,LpFollow,DwLatch:Array[0..512] of LongInt;
 LpD:LongInt;
 FollowOut:LongInt;
 SwNest:LongInt;
 SwAtLoop:Array[0..512] of LongInt;

Function AugSucc(N,K:LongInt):LongInt;
Begin
 AugSucc:=-1;
 If N>=NB Then Exit;
 If K<NSucc(N)Then AugSucc:=SuccOf(N,K)
 Else If(NSucc(N)=0)and(K=0)Then AugSucc:=NB;
End;

Function AugPred(N,K:LongInt):LongInt;
Begin
 AugPred:=-1;
 If N<NB Then Begin
  If K<PredCnt[N]Then AugPred:=PredPool[PredStart[N]+K];
 End
 Else Begin
  If K<NTerm Then AugPred:=TermList[K];
 End;
End;

Function GSucc(N,K:LongInt):LongInt;
Begin
 If GRev Then GSucc:=AugPred(N,K) Else GSucc:=AugSucc(N,K);
End;

Function GPred(N,K:LongInt):LongInt;
Begin
 If GRev Then GPred:=AugSucc(N,K) Else GPred:=AugPred(N,K);
End;

Procedure ComputeDom(Root:LongInt);
Var
 Stack,NextK:Array[0..MAXBLK+1] of LongInt;
 Visited:Array[0..MAXBLK] of Boolean;
 SP,I,N,K,S,P,NewD,Idx:LongInt;
 Changed:Boolean;
 Function Intersect(A,B:LongInt):LongInt;
 Begin
  While A<>B do Begin
   While PoNum[A]<PoNum[B]do A:=DomRes[A];
   While PoNum[B]<PoNum[A]do B:=DomRes[B];
  End;
  Intersect:=A;
 End;
Begin
 For I:=0 to NB do Begin DomRes[I]:=-2;PoNum[I]:=-1;Visited[I]:=False;End;
 NPo:=0;SP:=0;
 Stack[0]:=Root;NextK[0]:=0;SP:=1;Visited[Root]:=True;
 While SP>0 do Begin
  N:=Stack[SP-1];
  S:=GSucc(N,NextK[SP-1]);
  If S<0 Then Begin
   PoNum[N]:=NPo;PoOrder[NPo]:=N;Inc(NPo);
   Dec(SP);
  End
  Else Begin
   Inc(NextK[SP-1]);
   If not Visited[S]Then Begin
    Visited[S]:=True;
    Stack[SP]:=S;NextK[SP]:=0;Inc(SP);
   End;
  End;
 End;
 DomRes[Root]:=Root;
 Repeat
  Changed:=False;
  For Idx:=NPo-1 downto 0 do Begin
   N:=PoOrder[Idx];
   If N=Root Then Continue;
   NewD:=-1;
   K:=0;
   Repeat
    P:=GPred(N,K);
    If P<0 Then Break;
    Inc(K);
    If(PoNum[P]>=0)and(DomRes[P]<>-2)Then Begin
     If NewD<0 Then NewD:=P Else NewD:=Intersect(P,NewD);
    End;
   Until False;
   If NewD<>DomRes[N]Then Begin DomRes[N]:=NewD;Changed:=True;End;
  End;
 Until not Changed;
End;

Function Dominates(A,B:LongInt):Boolean;
Var Guard:LongInt;
Begin
 Dominates:=False;
 Guard:=0;
 While(B>=0)and(Guard<=NB+1)do Begin
  If A=B Then Begin Dominates:=True;Exit;End;
  If(IDomF[B]=B)or(IDomF[B]<0)Then Exit;
  B:=IDomF[B];
  Inc(Guard);
 End;
End;

Procedure ComputeGraphInfo;
Var I,K,S:LongInt;
Begin
 NTerm:=0;
 For I:=0 to NB-1 do
  If AugSucc(I,0)=NB Then Begin TermList[NTerm]:=I;Inc(NTerm);End;
 GRev:=False;
 ComputeDom(EntryBlk);
 For I:=0 to NB do IDomF[I]:=DomRes[I];
 For I:=0 to NB do RpoIdx[I]:=NB+5;
 For I:=0 to NPo-1 do RpoIdx[PoOrder[I]]:=NPo-1-I;
 GRev:=True;
 ComputeDom(NB);
 For I:=0 to NB do IPDom[I]:=DomRes[I];
 GRev:=False;
 For I:=0 to NB-1 do IsHdr[I]:=False;
 For I:=0 to NB-1 do
  If IDomF[I]<>-2 Then Begin
   For K:=0 to NSucc(I)-1 do Begin
    S:=SuccOf(I,K);
    If(IDomF[S]<>-2)and Dominates(S,I)Then IsHdr[S]:=True;
   End;
  End;
End;

{ ---------- noeuds de region ---------- }
Function NewR(T:Byte;B:LongInt):LongInt;
Begin
 If NReg>=MAXREG Then Begin NewR:=MAXREG-1;Exit;End;
 RT[NReg]:=T;RB[NReg]:=B;RC1[NReg]:=-1;RC2[NReg]:=-1;RNx[NReg]:=-1;RNeg[NReg]:=False;RKind[NReg]:=0;
 NewR:=NReg;
 Inc(NReg);
End;

Function IPDomOf(B:LongInt):LongInt;
Begin
 IPDomOf:=-1;
 If(IPDom[B]>=0)and(IPDom[B]<NB)and(IPDom[B]<>B)Then IPDomOf:=IPDom[B];
End;

Function JumpLike(X,Stop:LongInt):Boolean;
Var I:LongInt;
Begin
 JumpLike:=False;
 If X<0 Then Exit;
 If X=Stop Then Exit;
 If LpD>0 Then Begin
  If X=LpHdr[LpD-1]Then Begin JumpLike:=True;Exit;End;
  If(LpFollow[LpD-1]>=0)and(X=LpFollow[LpD-1])Then Begin JumpLike:=True;Exit;End;
 End;
 If Done[X]Then Begin JumpLike:=True;Exit;End;
 For I:=0 to StopD-2 do
  If StopSt[I]=X Then Begin JumpLike:=True;Exit;End;
End;

Function BuildSeq(B0,Stop:LongInt;SkipLoop:Boolean):LongInt;forward;

{ nombre de statements significatifs d'un bloc }
Function BlockSize(B:LongInt):LongInt;
Var K,N:LongInt;
Begin
 N:=0;
 For K:=SB0[B] to SB0[B]+SBN[B]-1 do
  If not(St^[K].Kind in[ST_NOP,ST_FLAGS])Then Inc(N);
 BlockSize:=N;
End;

{ construit une boucle dont l'entete est H ; FollowOut = bloc suivant la boucle }
Function BuildLoop(H:LongInt):LongInt;
Var
 Stack:Array[0..MAXBLK] of LongInt;
 SP,I,U,P,S,K,N,Follow,Best,NLatch,Latch:LongInt;
 InS,ExS,T,F:LongInt;
 Shape:Integer;
Begin
 For I:=0 to NB-1 do InBody[I]:=False;
 InBody[H]:=True;
 NLatch:=0;Latch:=-1;
 SP:=0;
 For K:=0 to PredCnt[H]-1 do Begin
  P:=PredPool[PredStart[H]+K];
  If(IDomF[P]<>-2)and Dominates(H,P)Then Begin
   Inc(NLatch);Latch:=P;
   If not InBody[P]Then Begin InBody[P]:=True;Stack[SP]:=P;Inc(SP);End;
  End;
 End;
 While SP>0 do Begin
  Dec(SP);U:=Stack[SP];
  For K:=0 to PredCnt[U]-1 do Begin
   P:=PredPool[PredStart[U]+K];
   If not InBody[P]and(IDomF[P]<>-2)Then Begin InBody[P]:=True;Stack[SP]:=P;Inc(SP);End;
  End;
 End;
 { forme de la boucle }
 Shape:=3;
 Follow:=-1;InS:=-1;ExS:=-1;
 If(BKind[H]=BK_JCC)and not BExt0[H]and(BS0[H]<>BS1[H])and(BS0[H]>=0)and(BS1[H]>=0)and not((NLatch=1)and(Latch=H))Then Begin
  If InBody[BS0[H]]and not InBody[BS1[H]]Then Begin Shape:=1;InS:=BS0[H];ExS:=BS1[H];End
  Else If InBody[BS1[H]]and not InBody[BS0[H]]Then Begin Shape:=1;InS:=BS1[H];ExS:=BS0[H];End;
 End;
 If(Shape=3)and(NLatch=1)and(BKind[Latch]=BK_JCC)and not BExt0[Latch]and(BS0[Latch]<>BS1[Latch])and
   (BS0[Latch]>=0)and(BS1[Latch]>=0)Then Begin
  If(BS0[Latch]=H)and not InBody[BS1[Latch]]Then Begin Shape:=2;ExS:=BS1[Latch];End
  Else If(BS1[Latch]=H)and not InBody[BS0[Latch]]Then Begin Shape:=2;ExS:=BS0[Latch];End;
 End;
 If Shape=3 Then Begin
  Best:=-1;
  For U:=0 to NB-1 do
   If InBody[U]Then
    For K:=0 to NSucc(U)-1 do Begin
     S:=SuccOf(U,K);
     If not InBody[S]and(IDomF[S]<>-2)Then
      If(Best<0)or(RpoIdx[S]<RpoIdx[Best])Then Best:=S;
    End;
  Follow:=Best;
 End
 Else Follow:=ExS;
 FollowOut:=Follow;
 Inc(LpD);
 LpHdr[LpD-1]:=H;LpFollow[LpD-1]:=Follow;DwLatch[LpD-1]:=-1;SwAtLoop[LpD-1]:=SwNest;
 If Shape=1 Then Begin
  N:=NewR(RG_WHILE,H);
  Done[H]:=True;
  RNeg[N]:=(InS<>BS0[H]);          { condition vraie => reste dans la boucle si InS est la cible du saut }
  RC1[N]:=BuildSeq(InS,-1,False);
 End
 Else If Shape=2 Then Begin
  N:=NewR(RG_DOWHILE,Latch);
  DwLatch[LpD-1]:=Latch;
  RNeg[N]:=(BS0[Latch]<>H);
  RC1[N]:=BuildSeq(H,-1,True);
 End
 Else Begin
  N:=NewR(RG_LOOP,H);
  RC1[N]:=BuildSeq(H,-1,True);
 End;
 Dec(LpD);
 FollowOut:=Follow;
 BuildLoop:=N;
End;

Function BuildSeq(B0,Stop:LongInt;SkipLoop:Boolean):LongInt;
Var
 Head,Tail,B,T,F,M,N,I,Cur,Cs,Prev:LongInt;
 Skip:Boolean;
 FollowL:LongInt;

 Procedure Add(R:LongInt);
 Begin
  If R<0 Then Exit;
  If Head<0 Then Head:=R Else RNx[Tail]:=R;
  Tail:=R;
  While RNx[Tail]>=0 do Tail:=RNx[Tail];
 End;

 Function MkGoto(X:LongInt):LongInt;
 Begin
  Labeled[X]:=True;
  MkGoto:=NewR(RG_GOTO,X);
 End;

 { saut vers X : duplique les petits blocs de sortie plutot qu'un goto }
 Function MkJump(X:LongInt):LongInt;
 Var R:LongInt;
 Begin
  If(BKind[X]in[BK_RET,BK_HALT,BK_TAIL])and(BlockSize(X)<=3)Then Begin
   R:=NewR(RG_BLOCK,X);RKind[R]:=1;MkJump:=R;
  End
  Else MkJump:=MkGoto(X);
 End;

Begin
 If StopD<4090 Then Begin StopSt[StopD]:=Stop;Inc(StopD);End;
 Head:=-1;Tail:=-1;B:=B0;Skip:=SkipLoop;
 While True do Begin
  If B<0 Then Break;
  If B=Stop Then Break;
  { bloc d'arret d'une construction englobante }
  Cur:=-1;
  If not Skip Then
   For I:=0 to StopD-2 do
    If StopSt[I]=B Then Begin Cur:=I;Break;End;
  If Cur>=0 Then Begin Add(MkJump(B));Break;End;
  If(LpD>0)and not Skip Then Begin
   If B=LpHdr[LpD-1]Then Begin Add(NewR(RG_CONT,B));Break;End;
   If(LpFollow[LpD-1]>=0)and(B=LpFollow[LpD-1])Then Begin
    If SwNest>SwAtLoop[LpD-1]Then Add(MkGoto(B)) Else Add(NewR(RG_BREAK,B));
    Break;
   End;
   Cur:=-1;
   For I:=0 to LpD-2 do
    If(B=LpHdr[I])or((LpFollow[I]>=0)and(B=LpFollow[I]))Then Cur:=I;
   If Cur>=0 Then Begin Add(MkGoto(B));Break;End;
  End;
  If Done[B]and not Skip Then Begin Add(MkJump(B));Break;End;
  If not Skip and IsHdr[B]and(LpD<500)Then Begin
   N:=BuildLoop(B);
   FollowL:=FollowOut;
   Add(N);
   B:=FollowL;
   Continue;
  End;
  Skip:=False;
  Done[B]:=True;
  { dernier bloc d'une boucle do-while }
  If(LpD>0)and(B=DwLatch[LpD-1])Then Begin
   Add(NewR(RG_BLOCK,B));
   Break;
  End;
  Case BKind[B] of
   BK_FALL,BK_JMP:Begin
    Add(NewR(RG_BLOCK,B));
    B:=BS0[B];
   End;
   BK_JCC:Begin
    T:=BS0[B];F:=BS1[B];
    If BExt0[B]Then Begin
     N:=NewR(RG_IF,B);
     RC1[N]:=NewR(RG_TAIL,B);
     Add(N);
     B:=F;
    End
    Else If(T=F)or(F<0)Then Begin
     Add(NewR(RG_BLOCK,B));
     B:=T;
    End
    Else If JumpLike(T,Stop)Then Begin
     N:=NewR(RG_IF,B);
     RC1[N]:=BuildSeq(T,Stop,False);
     Add(N);
     B:=F;
    End
    Else If JumpLike(F,Stop)Then Begin
     N:=NewR(RG_IF,B);
     RNeg[N]:=True;
     RC1[N]:=BuildSeq(F,Stop,False);
     Add(N);
     B:=T;
    End
    Else Begin
     M:=IPDomOf(B);
     N:=NewR(RG_IF,B);
     If M=T Then Begin
      RNeg[N]:=True;
      RC1[N]:=BuildSeq(F,M,False);
     End
     Else If M=F Then
      RC1[N]:=BuildSeq(T,M,False)
     Else Begin
      RC1[N]:=BuildSeq(T,M,False);
      RC2[N]:=BuildSeq(F,M,False);
     End;
     Add(N);
     B:=M;
    End;
   End;
   BK_SWITCH:Begin
    N:=NewR(RG_SWITCH,B);
    M:=IPDomOf(B);
    Inc(SwNest);
    Prev:=-1;
    For I:=0 to BSdN[B]-1 do Begin
     T:=SdPool[BSdS[B]+I];
     Cs:=NewR(RG_CASE,T);
     RC1[Cs]:=BuildSeq(T,M,False);
     If Prev<0 Then RC1[N]:=Cs Else RNx[Prev]:=Cs;
     Prev:=Cs;
    End;
    Dec(SwNest);
    Add(N);
    B:=M;
   End;
   Else Begin
    Add(NewR(RG_BLOCK,B));
    Break;
   End;
  End;
 End;
 If StopD>0 Then Dec(StopD);
 BuildSeq:=Head;
End;

Procedure BuildRegions;
Var I:LongInt;
Begin
 ComputeGraphInfo;
 NReg:=0;StopD:=0;LpD:=0;SwNest:=0;
 For I:=0 to NB do Begin Done[I]:=False;Labeled[I]:=False;End;
 FnRoot:=BuildSeq(EntryBlk,-1,False);
End;

{ ============================================================
  SORTIES
  ============================================================ }
Const
 OUT_SEC=0; OUT_SYM=1; OUT_INS=2; OUT_CFG=3; OUT_IR=4; OUT_REG=5; OUT_CXX=6;

 PR_TERN=1; PR_LOR=2; PR_LAND=3; PR_BOR=4; PR_BXOR=5; PR_BAND=6; PR_EQ=7;
 PR_REL=8; PR_SHIFT=9; PR_ADD=10; PR_MUL=11; PR_UNARY=12; PR_POST=13;

Type
 TVar = Record
  Name:String[47];
  CType:String[15];
  Canon:LongInt;
  Sz:Byte;
 End;

Var
 EsDepth:LongInt;
 DeclSeen:Array[0..4095] of String[63];
 NDeclSeen:LongInt;
 PendName:Array[0..255] of String[63];
 PendLine:Array[0..255] of String[127];
 NPend:LongInt;
 Outs:Array[0..6] of Text;
 OutOn,OutStd:Array[0..6] of Boolean;
 Sink:Boolean;
 CtxBlk,CtxPos:LongInt;
 IrMode:Boolean;

 { variables et emplacements de pile utilises par la fonction }
 NVar:LongInt;
 VarTab:Array[0..255] of TVar;
 NSlot:LongInt;
 SlotOff:Array[0..255] of LongInt;
 SlotSz:Array[0..255] of Byte;
 SlotFp:Array[0..255] of Boolean;
 RetKind:Integer;                    { 0 void, 1 entier, 2 flottant }
 RetCanon:LongInt;
 RetSize:Integer;

Procedure W(Idx:Integer;Const S:AnsiString);
Begin
 If OutOn[Idx]Then Begin
  WriteLn(Outs[Idx],S);
  If OutStd[Idx]Then Flush(Outs[Idx]);
 End;
End;

Procedure PutLn(Ind:Integer;Const S:AnsiString);
Var P:AnsiString;I:Integer;
Begin
 If Sink Then Exit;
 P:='';
 For I:=1 to Ind do P:=P+'    ';
 WriteLn(Outs[OUT_CXX],P+S);
 If OutStd[OUT_CXX]Then Flush(Outs[OUT_CXX]);
End;

{ ---------- declarations externes ---------- }
Procedure NoteExtern(Const Name,Line:AnsiString);
Var I:LongInt;
Begin
 If not Sink Then Exit;
 If Length(Name)>62 Then Exit;
 For I:=0 to NDeclSeen-1 do If DeclSeen[I]=Name Then Exit;
 For I:=0 to NPend-1 do If PendName[I]=Name Then Exit;
 If NPend>=256 Then Exit;
 PendName[NPend]:=Name;PendLine[NPend]:=Line;
 Inc(NPend);
End;

Procedure FlushExterns;
Var I:LongInt;
Begin
 For I:=0 to NPend-1 do Begin
  PutLn(0,PendLine[I]);
  If NDeclSeen<4096 Then Begin DeclSeen[NDeclSeen]:=PendName[I];Inc(NDeclSeen);End;
 End;
 If NPend>0 Then PutLn(0,'');
 NPend:=0;
End;

{ ---------- noms ---------- }
Function FuncNameAt(A:Int64):AnsiString;
Var I:LongInt;
Begin
 I:=SymAt(A);
 If I>=0 Then FuncNameAt:=CName(Syms[I].Name)
 Else FuncNameAt:='fun_'+HexStr(A,1);
End;

Function IT(Sz:Integer):AnsiString;
Begin
 Case Sz of
  1:IT:='int8_t';
  2:IT:='int16_t';
  8:IT:='int64_t';
  Else IT:='int32_t';
 End;
End;

Function UT(Sz:Integer):AnsiString;
Begin
 Case Sz of
  1:UT:='uint8_t';
  2:UT:='uint16_t';
  8:UT:='uint64_t';
  Else UT:='uint32_t';
 End;
End;

Function FT(Sz:Integer):AnsiString;
Begin
 If Sz=4 Then FT:='float' Else FT:='double';
End;

Function ExprSize(E:LongInt):Integer;
Var X,Y:Integer;
Begin
 ExprSize:=4;
 If E<0 Then Exit;
 Case Ex^[E].Op of
  EO_ADDRSLOT:ExprSize:=PtrSz;
  EO_EQ..EO_UGE:Begin
   X:=ExprSize(Ex^[E].A);Y:=ExprSize(Ex^[E].B);
   If Y>X Then X:=Y;
   ExprSize:=X;
  End;
  EO_CC,EO_LAND,EO_LOR,EO_LNOT:ExprSize:=1;
  Else Begin
   If Ex^[E].Sz>0 Then ExprSize:=Ex^[E].Sz Else ExprSize:=4;
  End;
 End;
End;

Procedure NoteVar(Const N:AnsiString;Const T:AnsiString;Canon:LongInt;Sz:Integer);
Var I:LongInt;
Begin
 For I:=0 to NVar-1 do
  If VarTab[I].Name=N Then Exit;
 If NVar>=256 Then Exit;
 VarTab[NVar].Name:=N;VarTab[NVar].CType:=T;VarTab[NVar].Canon:=Canon;VarTab[NVar].Sz:=Sz;
 Inc(NVar);
End;

Function SlotName(Slot:LongInt):AnsiString;
Begin
 If Slot>=PtrSz Then Begin
  If CpuMode=64 Then SlotName:='stk_'+HexStr(Slot,1)
   Else SlotName:='a'+LStr(Slot div PtrSz);
 End
 Else If Slot<0 Then SlotName:='local_'+HexStr(-Slot,1)
 Else SlotName:='retaddr';
End;

Function SlotRef(Slot:LongInt;Sz:Integer;Fp:Boolean):AnsiString;
Var I:LongInt;T:AnsiString;
Begin
 For I:=0 to NSlot-1 do
  If SlotOff[I]=Slot Then Begin
   If SlotSz[I]=Sz Then SlotRef:=SlotName(Slot)
   Else Begin
    If Fp Then T:=FT(Sz) Else T:=IT(Sz);
    SlotRef:='*('+T+'*)&'+SlotName(Slot);
   End;
   Exit;
  End;
 If NSlot<256 Then Begin
  SlotOff[NSlot]:=Slot;SlotSz[NSlot]:=Sz;SlotFp[NSlot]:=Fp;Inc(NSlot);
 End;
 SlotRef:=SlotName(Slot);
End;

{ ---------- constantes ---------- }
Function EscStr(Const S:AnsiString):AnsiString;
Var I:Integer;R:AnsiString;
Begin
 R:='';
 For I:=1 to Length(S)do Begin
  Case S[I] of
   '"':R:=R+'\"';
   '\':R:=R+'\\';
   #10:R:=R+'\n';
   #13:R:=R+'\r';
   #9:R:=R+'\t';
   Else R:=R+S[I];
  End;
 End;
 EscStr:=R;
End;

Function StringAt(A:Int64;Var S:AnsiString):Boolean;
Var B:Byte;L:Integer;Sg:LongInt;
Begin
 StringAt:=False;S:='';
 Sg:=FindSeg(A);
 If(Sg<0)or((Segs[Sg].Flags and SF_EXEC)<>0)or((Segs[Sg].Flags and SF_BSS)<>0)Then Exit;
 L:=0;
 While L<70 do Begin
  If not ReadB(A+L,B)Then Exit;
  If B=0 Then Break;
  If not(((B>=32)and(B<127))or(B=10)or(B=9)or(B=13))Then Exit;
  S:=S+Chr(B);Inc(L);
 End;
 If L>=70 Then Begin
  { chaine trop longue : tronquee }
  S:=S+'...';StringAt:=True;Exit;
 End;
 If L=0 Then Exit;
 If(L<4)and((Segs[Sg].Flags and SF_WRITE)<>0)Then Exit;
 StringAt:=True;
End;

Function ConstStr(V:Int64;Sz:Integer):AnsiString;
Var I:LongInt;S:AnsiString;
Begin
 If(V>=$1000)and((Sz>=PtrSz)or((Sz=4)and(CpuMode=64)))and IsMapped(V)Then Begin
  I:=SymAt(V);
  If I>=0 Then Begin
   If Syms[I].Kind in[SK_FUNC,SK_THUNK,SK_IMPORT,SK_EXPORT,SK_ENTRY]Then Begin
    ConstStr:=CName(Syms[I].Name);
    If not IsRoot(V)Then NoteExtern(CName(Syms[I].Name),'extern int64_t '+CName(Syms[I].Name)+'();');
    Exit;
   End
   Else If Syms[I].Kind in[SK_OBJECT,SK_NONE]Then Begin
    ConstStr:='&'+CName(Syms[I].Name);
    NoteExtern(CName(Syms[I].Name),'extern char '+CName(Syms[I].Name)+';');
    Exit;
   End;
  End;
  If IsRoot(V)Then Begin ConstStr:='fun_'+HexStr(V,1);Exit;End;
  If StringAt(V,S)Then Begin ConstStr:='"'+EscStr(S)+'"';Exit;End;
 End;
 If V<0 Then Begin
  If V>=-65536 Then ConstStr:='-'+LStr(-V)
  Else If Sz=8 Then ConstStr:='0x'+HexStr(V,1)
  Else ConstStr:='0x'+HexStr(ZeroExt(V,Sz),1);
 End
 Else If V<=9 Then ConstStr:=LStr(V)
 Else ConstStr:='0x'+HexStr(V,1);
End;

{ ---------- expressions ---------- }
Function RawFlag(CC:Integer):AnsiString;
Begin
 NoteVar('cf','bool',-1,1);NoteVar('zf','bool',-1,1);NoteVar('sf','bool',-1,1);
 NoteVar('of','bool',-1,1);NoteVar('pf','bool',-1,1);
 Case CC of
  0:RawFlag:='of';1:RawFlag:='!of';2:RawFlag:='cf';3:RawFlag:='!cf';4:RawFlag:='zf';
  5:RawFlag:='!zf';6:RawFlag:='(cf || zf)';7:RawFlag:='(!cf && !zf)';8:RawFlag:='sf';
  9:RawFlag:='!sf';10:RawFlag:='pf';11:RawFlag:='!pf';12:RawFlag:='(sf != of)';
  13:RawFlag:='(sf == of)';14:RawFlag:='(zf || sf != of)';15:RawFlag:='(!zf && sf == of)';
  Else RawFlag:='flags';
 End;
End;

Function Par(Const S:AnsiString;Own,Ctx:Integer):AnsiString;
Begin
 If Own<Ctx Then Par:='('+S+')' Else Par:=S;
End;

Function ES(E:LongInt;Ctx:Integer):AnsiString;forward;

{ conversion en non signe : (uintN_t)x ; evite (uintN_t)(intN_t)x }
Function UCast(E:LongInt;Sz:Integer):AnsiString;
Begin
 If(Ex^[E].Op=EO_TRUNC)and(Ex^[E].Sz=Sz)Then UCast:='('+UT(Sz)+')'+ES(Ex^[E].A,PR_UNARY)
 Else UCast:='('+UT(Sz)+')'+ES(E,PR_UNARY);
End;

Function ArgsStr(L:LongInt):AnsiString;
Var S:AnsiString;
Begin
 S:='';
 While L>=0 do Begin
  If S<>''Then S:=S+', ';
  S:=S+ES(Ex^[L].A,0);
  L:=Ex^[L].B;
 End;
 ArgsStr:=S;
End;

{ arguments d'un appel ; les arguments flottants des fonctions printf sont replaces
  dans l'ordre de la chaine de format }
Function CallArgs(E:LongInt;Const Name:AnsiString):AnsiString;
Var
 Items:Array[0..31] of LongInt;
 Order:Array[0..31] of LongInt;
 N,NInt,FmtPos,I,P,NI,NF,NO,J:LongInt;
 L:LongInt;
 Fmt:AnsiString;
 Used:Array[0..31] of Boolean;
 C:Char;
 Res:AnsiString;
 Pk:Boolean;
Begin
 CallArgs:=ArgsStr(Ex^[E].B);
 If(Ex^[E].C<=0)or IsWin Then Exit;
 NInt:=Ex^[E].C-1;
 FmtPos:=-1;
 If(Name='printf')or(Name='vprintf')Then FmtPos:=0
 Else If(Name='fprintf')or(Name='sprintf')or(Name='dprintf')or(Name='__printf_chk')Then FmtPos:=1
 Else If(Name='snprintf')or(Name='__fprintf_chk')Then FmtPos:=2
 Else If Name='__sprintf_chk' Then FmtPos:=3
 Else If Name='__snprintf_chk' Then FmtPos:=4;
 If FmtPos<0 Then Exit;
 N:=0;L:=Ex^[E].B;
 While(L>=0)and(N<32)do Begin Items[N]:=Ex^[L].A;Inc(N);L:=Ex^[L].B;End;
 If NInt>N Then NInt:=N;
 If FmtPos>=NInt Then Exit;
 If Ex^[Items[FmtPos]].Op<>EO_CONST Then Exit;
 If not StringAt(Ex^[Items[FmtPos]].V,Fmt)Then Exit;
 FillChar(Used,SizeOf(Used),False);
 NO:=0;
 For I:=0 to FmtPos do Begin Order[NO]:=I;Used[I]:=True;Inc(NO);End;
 NI:=FmtPos+1;NF:=NInt;
 P:=1;
 While P<=Length(Fmt)do Begin
  If Fmt[P]<>'%' Then Begin Inc(P);Continue;End;
  Inc(P);
  If(P<=Length(Fmt))and(Fmt[P]='%')Then Begin Inc(P);Continue;End;
  While(P<=Length(Fmt))and(Fmt[P] in['-','+',' ','#','0'])do Inc(P);
  While(P<=Length(Fmt))and((Fmt[P] in['0'..'9'])or(Fmt[P]='*'))do Begin
   If(Fmt[P]='*')and(NI<NInt)Then Begin Order[NO]:=NI;Used[NI]:=True;Inc(NO);Inc(NI);End;
   Inc(P);
  End;
  If(P<=Length(Fmt))and(Fmt[P]='.')Then Begin
   Inc(P);
   While(P<=Length(Fmt))and((Fmt[P] in['0'..'9'])or(Fmt[P]='*'))do Begin
    If(Fmt[P]='*')and(NI<NInt)Then Begin Order[NO]:=NI;Used[NI]:=True;Inc(NO);Inc(NI);End;
    Inc(P);
   End;
  End;
  While(P<=Length(Fmt))and(Fmt[P] in['h','l','L','q','j','z','t'])do Inc(P);
  If P>Length(Fmt)Then Break;
  C:=Fmt[P];Inc(P);
  If C in['f','F','e','E','g','G','a','A']Then Begin
   If NF<N Then Begin Order[NO]:=NF;Used[NF]:=True;Inc(NO);Inc(NF);End;
  End
  Else If NI<NInt Then Begin Order[NO]:=NI;Used[NI]:=True;Inc(NO);Inc(NI);End;
 End;
 For I:=0 to N-1 do
  If not Used[I]Then Begin Order[NO]:=I;Inc(NO);End;
 Res:='';
 For I:=0 to NO-1 do Begin
  If I>0 Then Res:=Res+', ';
  Res:=Res+ES(Items[Order[I]],0);
 End;
 CallArgs:=Res;
End;

Function CallStr(E:LongInt):AnsiString;
Var T:LongInt;N:AnsiString;Slot:Int64;
Begin
 T:=Ex^[E].A;
 If Ex^[T].Op=EO_CONST Then Begin
  CallStr:=FuncNameAt(Ex^[T].V)+'('+CallArgs(E,FuncNameAt(Ex^[T].V))+')';
  If not IsRoot(Ex^[T].V)Then NoteExtern(FuncNameAt(Ex^[T].V),'extern int64_t '+FuncNameAt(Ex^[T].V)+'();');
 End
 Else Begin
  If(Ex^[T].Op=EO_MEM)and(Ex^[Ex^[T].A].Op=EO_CONST)Then Begin
   Slot:=Ex^[Ex^[T].A].V;
   If CpuMode=32 Then Slot:=Slot and $FFFFFFFF;
   N:=ImportAt(Slot);
   If N<>''Then Begin
    CallStr:=CName(N)+'('+CallArgs(E,CName(N))+')';
    NoteExtern(CName(N),'extern int64_t '+CName(N)+'();');
    Exit;
   End;
  End;
  CallStr:='((int64_t(*)())'+ES(T,PR_UNARY)+')('+ArgsStr(Ex^[E].B)+')';
 End;
End;

Function ES(E:LongInt;Ctx:Integer):AnsiString;
Var T:TExpr;A,B:AnsiString;R:LongInt;Fp:Boolean;S:AnsiString;Sg:LongInt;V:Int64;
 Function Bin(Const Op:AnsiString;Own:Integer;RightCtx:Integer):AnsiString;
 Begin
  Bin:=Par(ES(T.A,Own)+' '+Op+' '+ES(T.B,RightCtx),Own,Ctx);
 End;
 Function UBin(Const Op:AnsiString;Own:Integer):AnsiString;
 Var Z:Integer;
 Begin
  Z:=ExprSize(T.A);
  If ExprSize(T.B)>Z Then Z:=ExprSize(T.B);
  UBin:=Par(UCast(T.A,Z)+' '+Op+' '+UCast(T.B,Z),Own,Ctx);
 End;
Begin
 If E<0 Then Begin ES:='/*?*/';Exit;End;
 If EsDepth>400 Then Begin ES:='/*...*/';Exit;End;
 Inc(EsDepth);
 T:=Ex^[E];
 Case T.Op of
  EO_CONST:Begin
   S:=ConstStr(T.V,T.Sz);
   If(Length(S)>0)and(S[1]='&')and(Ctx>=PR_ADD)and(Ctx<=PR_UNARY)Then S:='(intptr_t)'+S;
   ES:=S;
  End;
  EO_REG:Begin
   If T.A>=16 Then Begin
    S:='xmm'+LStr(T.A-16);
    NoteVar(S,'double',T.A,16);
    ES:=S;
   End
   Else Begin
    S:=RegName(RC_GPR,T.A,T.Sz,T.B=1);
    NoteVar(S,IT(T.Sz),T.A,T.Sz);
    ES:=S;
   End;
  End;
  EO_VAR:Begin
   S:=NameTab[T.A];
   NoteVar(S,IT(T.Sz),-1,T.Sz);
   ES:=S;
  End;
  EO_SLOT:ES:=SlotRef(T.V,T.Sz,T.B<>0);
  EO_ADDRSLOT:Begin
   SlotRef(T.V,PtrSz,False);
   If(Ctx>=PR_ADD)and(Ctx<=PR_UNARY)Then ES:='(intptr_t)&'+SlotName(T.V)
   Else ES:=Par('&'+SlotName(T.V),PR_UNARY,Ctx);
  End;
  EO_MEM:Begin
   Fp:=T.B<>0;
   If Fp Then S:=FT(T.Sz) Else S:=IT(T.Sz);
   R:=T.A;
   If Ex^[R].Op=EO_CONST Then Begin
    Sg:=SymAt(Ex^[R].V);
    If(Sg>=0)and(Syms[Sg].Kind in[SK_OBJECT,SK_NONE,SK_IMPORT])and(Syms[Sg].Size=T.Sz)and not Fp Then Begin
     ES:=CName(Syms[Sg].Name);
     NoteExtern(CName(Syms[Sg].Name),'extern '+IT(T.Sz)+' '+CName(Syms[Sg].Name)+';');
     Dec(EsDepth);Exit;
    End;
    ES:=Par('*('+S+'*)'+ES(R,PR_POST),PR_UNARY,Ctx);
    If Sg>=0 Then Begin
     ES:=Par('*('+S+'*)&'+CName(Syms[Sg].Name),PR_UNARY,Ctx);
     NoteExtern(CName(Syms[Sg].Name),'extern char '+CName(Syms[Sg].Name)+';');
    End
     Else If IsMapped(Ex^[R].V)Then
      ES:=Par('*('+S+'*)0x'+HexStr(Ex^[R].V,1),PR_UNARY,Ctx);
   End
   Else Begin
    If Ex^[R].Op in[EO_ADDRSLOT,EO_REG,EO_VAR]Then ES:=Par('*('+S+'*)'+ES(R,PR_UNARY),PR_UNARY,Ctx)
    Else ES:=Par('*('+S+'*)'+ES(R,PR_POST),PR_UNARY,Ctx);
   End;
  End;
  EO_ADD:Begin
   If(Ex^[T.B].Op=EO_CONST)and(Ex^[T.B].V<0)Then
    ES:=Par(ES(T.A,PR_ADD)+' - '+ConstStr(-Ex^[T.B].V,T.Sz),PR_ADD,Ctx)
   Else ES:=Bin('+',PR_ADD,PR_ADD+1);
  End;
  EO_SUB:ES:=Bin('-',PR_ADD,PR_ADD+1);
  EO_MUL:ES:=Bin('*',PR_MUL,PR_MUL+1);
  EO_SDIV:ES:=Bin('/',PR_MUL,PR_MUL+1);
  EO_SMOD:ES:=Bin('%',PR_MUL,PR_MUL+1);
  EO_UDIV:ES:=Par(UCast(T.A,T.Sz)+' / '+UCast(T.B,T.Sz),PR_MUL,Ctx);
  EO_UMOD:ES:=Par(UCast(T.A,T.Sz)+' % '+UCast(T.B,T.Sz),PR_MUL,Ctx);
  EO_AND:ES:=Par(ES(T.A,PR_EQ)+' & '+ES(T.B,PR_EQ),PR_BAND,Ctx);
  EO_OR:ES:=Par(ES(T.A,PR_EQ)+' | '+ES(T.B,PR_EQ),PR_BOR,Ctx);
  EO_XOR:ES:=Par(ES(T.A,PR_EQ)+' ^ '+ES(T.B,PR_EQ),PR_BXOR,Ctx);
  EO_SHL:ES:=Bin('<<',PR_SHIFT,PR_SHIFT+1);
  EO_SAR:ES:=Bin('>>',PR_SHIFT,PR_SHIFT+1);
  EO_SHR:ES:=Par(UCast(T.A,T.Sz)+' >> '+ES(T.B,PR_SHIFT+1),PR_SHIFT,Ctx);
  EO_ROL:Begin
   ES:='__rol'+LStr(T.Sz*8)+'('+ES(T.A,0)+', '+ES(T.B,0)+')';
   NoteExtern('__rol'+LStr(T.Sz*8),'extern int64_t __rol'+LStr(T.Sz*8)+'();');
  End;
  EO_ROR:Begin
   ES:='__ror'+LStr(T.Sz*8)+'('+ES(T.A,0)+', '+ES(T.B,0)+')';
   NoteExtern('__ror'+LStr(T.Sz*8),'extern int64_t __ror'+LStr(T.Sz*8)+'();');
  End;
  EO_NEG:ES:=Par('-'+ES(T.A,PR_UNARY),PR_UNARY,Ctx);
  EO_NOT:ES:=Par('~'+ES(T.A,PR_UNARY),PR_UNARY,Ctx);
  EO_LNOT:ES:=Par('!'+ES(T.A,PR_UNARY),PR_UNARY,Ctx);
  EO_ZEXT:Begin
   If ExprSize(T.A)>=T.Sz Then ES:=ES(T.A,Ctx)
   Else ES:=Par(UCast(T.A,ExprSize(T.A)),PR_UNARY,Ctx);
  End;
  EO_SEXT,EO_TRUNC:ES:=Par('('+IT(T.Sz)+')'+ES(T.A,PR_UNARY),PR_UNARY,Ctx);
  EO_EQ:ES:=Bin('==',PR_EQ,PR_EQ+1);
  EO_NE:ES:=Bin('!=',PR_EQ,PR_EQ+1);
  EO_SLT:ES:=Bin('<',PR_REL,PR_REL+1);
  EO_SLE:ES:=Bin('<=',PR_REL,PR_REL+1);
  EO_SGT:ES:=Bin('>',PR_REL,PR_REL+1);
  EO_SGE:ES:=Bin('>=',PR_REL,PR_REL+1);
  EO_ULT:ES:=UBin('<',PR_REL);
  EO_ULE:ES:=UBin('<=',PR_REL);
  EO_UGT:ES:=UBin('>',PR_REL);
  EO_UGE:ES:=UBin('>=',PR_REL);
  EO_LAND:ES:=Bin('&&',PR_LAND,PR_LAND+1);
  EO_LOR:ES:=Bin('||',PR_LOR,PR_LOR+1);
  EO_CC:Begin
   R:=ResolveCC(CtxBlk,CtxPos,T.A);
   If Ex^[R].Op=EO_CC Then ES:=RawFlag(T.A)
   Else ES:=ES(R,Ctx);
  End;
  EO_TERN:ES:=Par(ES(T.A,PR_LOR)+' ? '+ES(T.B,PR_TERN+1)+' : '+ES(T.C,PR_TERN+1),PR_TERN,Ctx);
  EO_CALL:ES:=CallStr(E);
  EO_INTR:Begin
   S:=NameTab[T.A];
   If(T.B>=0)and(Ex^[T.B].B<0)Then Begin
    { conversions : ecrites comme des transtypages C }
    If S='cvtsi2sd' Then Begin ES:=Par('(double)'+ES(Ex^[T.B].A,PR_UNARY),PR_UNARY,Ctx);Dec(EsDepth);Exit;End;
    If S='cvtsi2ss' Then Begin ES:=Par('(float)'+ES(Ex^[T.B].A,PR_UNARY),PR_UNARY,Ctx);Dec(EsDepth);Exit;End;
    If(S='cvtss2sd')Then Begin ES:=Par('(double)'+ES(Ex^[T.B].A,PR_UNARY),PR_UNARY,Ctx);Dec(EsDepth);Exit;End;
    If(S='cvtsd2ss')Then Begin ES:=Par('(float)'+ES(Ex^[T.B].A,PR_UNARY),PR_UNARY,Ctx);Dec(EsDepth);Exit;End;
    If(S='cvttsd2si')or(S='cvttss2si')or(S='cvtsd2si')or(S='cvtss2si')Then Begin
     ES:=Par('('+IT(T.Sz)+')'+ES(Ex^[T.B].A,PR_UNARY),PR_UNARY,Ctx);Dec(EsDepth);Exit;
    End;
    If(S='sqrtsd')or(S='sqrtss')Then Begin
     NoteExtern('sqrt','extern double sqrt();');
     ES:='sqrt('+ES(Ex^[T.B].A,0)+')';Dec(EsDepth);Exit;
    End;
   End;
   ES:=S+'('+ArgsStr(T.B)+')';
   NoteExtern(S,'extern int64_t '+S+'();');
  End;
  Else ES:='/*?*/';
 End;
 Dec(EsDepth);
End;

Function NegE(E:LongInt):LongInt;
Var T:TExpr;Op:Byte;
Begin
 T:=Ex^[E];
 Op:=0;
 Case T.Op of
  EO_EQ:Op:=EO_NE;EO_NE:Op:=EO_EQ;EO_SLT:Op:=EO_SGE;EO_SGE:Op:=EO_SLT;
  EO_SLE:Op:=EO_SGT;EO_SGT:Op:=EO_SLE;EO_ULT:Op:=EO_UGE;EO_UGE:Op:=EO_ULT;
  EO_ULE:Op:=EO_UGT;EO_UGT:Op:=EO_ULE;
 End;
 If Op<>0 Then Begin NegE:=NewEx(Op,T.Sz,T.A,T.B,0,0);Exit;End;
 Case T.Op of
  EO_LNOT:NegE:=T.A;
  EO_CC:NegE:=MkCC(T.A xor 1);
  EO_LAND:NegE:=NewEx(EO_LOR,1,NegE(T.A),NegE(T.B),0,0);
  EO_LOR:NegE:=NewEx(EO_LAND,1,NegE(T.A),NegE(T.B),0,0);
  EO_CONST:NegE:=MkConst(Ord(T.V=0),1);
  Else NegE:=NewEx(EO_LNOT,1,E,0,0,0);
 End;
End;

{ ---------- statements ---------- }
Function LvalStr(E:LongInt):AnsiString;
Begin
 LvalStr:=ES(E,PR_UNARY);
End;

Function CompoundOp(Op:Byte):AnsiString;
Begin
 Case Op of
  EO_ADD:CompoundOp:='+=';
  EO_SUB:CompoundOp:='-=';
  EO_MUL:CompoundOp:='*=';
  EO_AND:CompoundOp:='&=';
  EO_OR:CompoundOp:='|=';
  EO_XOR:CompoundOp:='^=';
  EO_SHL:CompoundOp:='<<=';
  EO_SAR:CompoundOp:='>>=';
  Else CompoundOp:='';
 End;
End;

Function AssignStr(Dst,Src:LongInt):AnsiString;
Var L,Op:AnsiString;
Begin
 L:=LvalStr(Dst);
 If(Ex^[Src].Op in[EO_ADD,EO_SUB,EO_MUL,EO_AND,EO_OR,EO_XOR,EO_SHL,EO_SAR])and SameExpr(Ex^[Src].A,Dst)Then Begin
  If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].B].Op=EO_CONST)and(Ex^[Ex^[Src].B].V=1)Then Begin
   AssignStr:=L+'++;';Exit;
  End;
  If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].B].Op=EO_CONST)and(Ex^[Ex^[Src].B].V=-1)Then Begin
   AssignStr:=L+'--;';Exit;
  End;
  If(Ex^[Src].Op=EO_ADD)and(Ex^[Ex^[Src].B].Op=EO_CONST)and(Ex^[Ex^[Src].B].V<0)Then Begin
   AssignStr:=L+' -= '+ConstStr(-Ex^[Ex^[Src].B].V,Ex^[Src].Sz)+';';Exit;
  End;
  Op:=CompoundOp(Ex^[Src].Op);
  AssignStr:=L+' '+Op+' '+ES(Ex^[Src].B,0)+';';
  Exit;
 End;
 AssignStr:=L+' = '+ES(Src,0)+';';
End;

Function FlagsName(FK:Byte):AnsiString;
Begin
 Case FK of
  FK_CMP:FlagsName:='cmp';
  FK_TEST:FlagsName:='test';
  FK_ADD:FlagsName:='add';
  FK_SUB:FlagsName:='sub';
  FK_LOGIC:FlagsName:='logic';
  FK_INC:FlagsName:='inc';
  FK_DEC:FlagsName:='dec';
  FK_NEG:FlagsName:='neg';
  FK_SHIFT:FlagsName:='shift';
  FK_FCMP:FlagsName:='fcmp';
  FK_BT:FlagsName:='bt';
  Else FlagsName:='other';
 End;
End;

{ statement d'effet de bord imprimable en C ? }
Function Printable(K:LongInt):Boolean;
Begin
 Printable:=False;
 Case St^[K].Kind of
  ST_ASSIGN,ST_STORE,ST_EXPR,ST_ASM:Printable:=True;
  ST_PUSH,ST_POP:Printable:=St^[K].FK=0;
 End;
End;

Function StmtStr(K:LongInt;Ir:Boolean):AnsiString;
Var S:AnsiString;
Begin
 CtxPos:=K;
 Case St^[K].Kind of
  ST_ASSIGN,ST_STORE:Begin
   S:=AssignStr(St^[K].A,St^[K].B);
   If Ir Then Delete(S,Length(S),1);
   StmtStr:=S;
  End;
  ST_FLAGS:Begin
   S:='flags = '+FlagsName(St^[K].FK)+'('+ES(St^[K].A,0);
   If St^[K].B>=0 Then S:=S+', '+ES(St^[K].B,0);
   StmtStr:=S+')';
  End;
  ST_PUSH:Begin
   NoteExtern('push','extern void push();');
   S:='push('+ES(St^[K].A,0)+')';
   If not Ir Then S:=S+';';
   StmtStr:=S;
  End;
  ST_POP:Begin
   NoteExtern('pop','extern int64_t pop();');
   S:=LvalStr(St^[K].A)+' = pop()';
   If not Ir Then S:=S+';';
   StmtStr:=S;
  End;
  ST_EXPR:Begin
   S:=ES(St^[K].A,0);
   If not Ir Then S:=S+';';
   StmtStr:=S;
  End;
  ST_ASM:Begin
   If Ir Then StmtStr:='asm "'+AsmTxt[St^[K].Txt]+'"'
   Else StmtStr:='/* '+AsmTxt[St^[K].Txt]+' */';
  End;
  Else StmtStr:='';
 End;
End;

{ ---------- types de retour et declarations ---------- }
Procedure ComputeRetKind;
Var
 B,T:LongInt;
 Any1,Any2,HasRet,HasTail:Boolean;
 C,S,MaxSz:LongInt;
Begin
 RetKind:=0;RetCanon:=0;RetSize:=PtrSz;
 Any1:=False;Any2:=False;HasRet:=False;HasTail:=False;MaxSz:=0;
 For B:=0 to NB-1 do Begin
  T:=SB0[B]+SBN[B]-1;
  If St^[T].Kind=ST_TAIL Then HasTail:=True;
  If St^[T].Kind=ST_RET Then Begin
   HasRet:=True;
   If FindRetDef(B,T,C,S)Then Begin
    If C=0 Then Begin Any1:=True;If S>MaxSz Then MaxSz:=S;End
    Else Any2:=True;
   End;
  End;
 End;
 If Any1 or(HasTail and not HasRet)Then Begin
  RetKind:=1;RetCanon:=0;
  If MaxSz=0 Then MaxSz:=PtrSz;
  If CpuMode<>64 Then RetSize:=PtrSz
  Else If MaxSz>=8 Then RetSize:=8 Else RetSize:=4;
 End
 Else If Any2 Then Begin RetKind:=2;RetCanon:=16;RetSize:=16;End;
 { le type de retour suit la signature deja calculee (declarations anticipees) }
 B:=RootIdx(FnEntry);
 If(B>=0)and SigOk[B]Then Begin
  Case SigRet[B] of
   0:RetKind:=0;
   16:Begin RetKind:=2;RetCanon:=16;RetSize:=16;End;
   4:Begin RetKind:=1;RetCanon:=0;RetSize:=4;End;
   Else Begin RetKind:=1;RetCanon:=0;If CpuMode=64 Then RetSize:=8 Else RetSize:=PtrSz;End;
  End;
 End;
End;

{ type de retour d'apres la signature de la fonction racine I }
Function SigRetType(I:LongInt):AnsiString;
Begin
 Case SigRet[I] of
  0:SigRetType:='void';
  4:SigRetType:='int32_t';
  16:SigRetType:='double';
  Else If CpuMode=64 Then SigRetType:='int64_t' Else SigRetType:=IT(PtrSz);
 End;
End;

Function RetTypeStr:AnsiString;
Begin
 Case RetKind of
  1:RetTypeStr:=IT(RetSize);
  2:RetTypeStr:='double';
  Else RetTypeStr:='void';
 End;
End;

Function RetVarFor(C,S:LongInt):AnsiString;
Begin
 If C=16 Then Begin
  NoteVar('xmm0','double',16,16);
  RetVarFor:='xmm0';
 End
 Else Begin
  If CpuMode<>64 Then S:=PtrSz Else If S<4 Then S:=4;
  If(CpuMode=64)and WideReg[0]Then Begin
   NoteVar('rax','int64_t',0,8);
   If S=4 Then RetVarFor:='(int32_t)rax' Else RetVarFor:='rax';
  End
  Else Begin
   NoteVar(RegName(RC_GPR,0,S,False),IT(S),0,S);
   RetVarFor:=RegName(RC_GPR,0,S,False);
  End;
 End;
End;

Function RetVarStr:AnsiString;
Begin
 RetVarStr:=RetVarFor(RetCanon,RetSize);
End;

{ ---------- emission d'un bloc ---------- }
Procedure PrintLabel(B:LongInt;Ind:Integer);
Begin
 If Labeled[B]Then PutLn(Ind-1+Ord(Ind=0),'label_'+HexStr(BStart[B],1)+':');
End;

Function LastPrintable(B:LongInt):LongInt;
Var K:LongInt;
Begin
 LastPrintable:=-1;
 For K:=SB0[B]+SBN[B]-1 downto SB0[B] do
  If Printable(K)Then Begin LastPrintable:=K;Exit;End;
End;

Function TermOf(B:LongInt):LongInt;
Begin
 TermOf:=SB0[B]+SBN[B]-1;
End;

{ le dernier statement fusionne avec le return ? }
Function ReturnFold(B:LongInt):LongInt;
Var L,D:LongInt;
Begin
 ReturnFold:=-1;
 If St^[TermOf(B)].Kind<>ST_RET Then Exit;
 If RetKind=0 Then Exit;
 L:=LastPrintable(B);
 If L<0 Then Exit;
 If St^[L].Kind<>ST_ASSIGN Then Exit;
 D:=St^[L].A;
 If(Ex^[D].Op=EO_REG)and((Ex^[D].A=0)or(Ex^[D].A=16))and(Ex^[D].B=0)Then ReturnFold:=L;
End;

{ statement qui capture l'indice d'un switch }
Function SwitchAssign(B:LongInt):LongInt;
Var K:LongInt;
Begin
 SwitchAssign:=-1;
 If BKind[B]<>BK_SWITCH Then Exit;
 For K:=SB0[B] to SB0[B]+SBN[B]-1 do
  If(St^[K].Kind=ST_ASSIGN)and(Ex^[St^[K].A].Op=EO_VAR)Then
   If Copy(NameTab[Ex^[St^[K].A].A],1,2)='sw' Then SwitchAssign:=K;
End;

Function HasStmts(B:LongInt):Boolean;
Var K,F,W_:LongInt;
Begin
 HasStmts:=False;
 F:=ReturnFold(B);
 W_:=SwitchAssign(B);
 For K:=SB0[B] to SB0[B]+SBN[B]-1 do
  If Printable(K)and(K<>F)and(K<>W_)Then Begin HasStmts:=True;Exit;End;
 Case St^[TermOf(B)].Kind of
  ST_RET,ST_TAIL:HasStmts:=True;
  ST_IJMP:HasStmts:=BKind[B]<>BK_SWITCH;
 End;
End;

Procedure PrintBlock(B:LongInt;Ind:Integer;NoLabel:Boolean);
Var K,F,T,W_,C,S:LongInt;
Begin
 CtxBlk:=B;
 If Labeled[B]and not NoLabel Then Begin
  If HasStmts(B)Then PutLn(Ind-1,'label_'+HexStr(BStart[B],1)+':')
  Else PutLn(Ind-1,'label_'+HexStr(BStart[B],1)+':;');
 End;
 F:=ReturnFold(B);
 W_:=SwitchAssign(B);
 For K:=SB0[B] to SB0[B]+SBN[B]-1 do Begin
  If(K=F)or(K=W_)or not Printable(K)Then Continue;
  PutLn(Ind,StmtStr(K,False));
 End;
 T:=TermOf(B);
 CtxPos:=T;
 Case St^[T].Kind of
  ST_RET:Begin
   If F>=0 Then Begin
    CtxPos:=F;
    PutLn(Ind,'return '+ES(St^[F].B,0)+';');
   End
   Else If RetKind<>0 Then Begin
    If FindRetDef(B,T,C,S)Then PutLn(Ind,'return '+RetVarFor(C,S)+';')
    Else PutLn(Ind,'return '+RetVarStr+';');
   End
   Else PutLn(Ind,'return;');
  End;
  ST_TAIL:Begin
   If RetKind=0 Then Begin
    PutLn(Ind,ES(St^[T].A,0)+';');
    PutLn(Ind,'return;');
   End
   Else PutLn(Ind,'return '+ES(St^[T].A,0)+';');
  End;
  ST_IJMP:If BKind[B]<>BK_SWITCH Then PutLn(Ind,'goto *(void*)'+ES(St^[T].A,PR_UNARY)+';');
 End;
End;

Function CondStr(B:LongInt;Neg:Boolean):AnsiString;
Var T,C:LongInt;
Begin
 T:=TermOf(B);
 CtxBlk:=B;CtxPos:=T;
 C:=St^[T].A;
 If Neg Then C:=NegE(C);
 CondStr:=ES(C,0);
End;

Function TailCallStr(B:LongInt):AnsiString;
Begin
 TailCallStr:=FuncNameAt(BTgt[B])+'()';
End;

Procedure EmitList(R,Ind:Integer;InLoop:Boolean);forward;

Function ListEmpty(R:LongInt):Boolean;
Begin
 ListEmpty:=False;
 While R>=0 do Begin
  If RT[R]<>RG_BLOCK Then Exit;
  If HasStmts(RB[R])Then Exit;
  R:=RNx[R];
 End;
 ListEmpty:=True;
End;

Function EndsWithJump(R:LongInt):Boolean;
Var T:LongInt;
Begin
 EndsWithJump:=False;
 If R<0 Then Exit;
 While RNx[R]>=0 do R:=RNx[R];
 Case RT[R] of
  RG_GOTO,RG_BREAK,RG_CONT,RG_TAIL:EndsWithJump:=True;
  RG_BLOCK:Begin
   T:=TermOf(RB[R]);
   EndsWithJump:=St^[T].Kind in[ST_RET,ST_TAIL,ST_HALT,ST_IJMP];
  End;
 End;
End;

Procedure EmitRegion(R:LongInt;Ind:Integer;InLoop,IsLast:Boolean);
Var B,E,H,K:LongInt;S:AnsiString;Hdr:Boolean;
Begin
 B:=RB[R];
 Case RT[R] of
  RG_BLOCK:PrintBlock(B,Ind,RKind[R]=1);
  RG_GOTO:PutLn(Ind,'goto label_'+HexStr(BStart[B],1)+';');
  RG_BREAK:PutLn(Ind,'break;');
  RG_CONT:If not(InLoop and IsLast)Then PutLn(Ind,'continue;');
  RG_TAIL:Begin
   If RetKind=0 Then Begin PutLn(Ind,TailCallStr(B)+';');PutLn(Ind,'return;');End
   Else PutLn(Ind,'return '+TailCallStr(B)+';');
  End;
  RG_IF:Begin
   PrintBlock(B,Ind,False);
   S:=CondStr(B,RNeg[R]);
   If ListEmpty(RC1[R])and ListEmpty(RC2[R])Then Begin
    { rien a afficher }
   End
   Else If ListEmpty(RC1[R])and(RC2[R]>=0)Then Begin
    S:=CondStr(B,not RNeg[R]);
    PutLn(Ind,'if ('+S+') {');
    EmitList(RC2[R],Ind+1,InLoop and IsLast);
    PutLn(Ind,'}');
   End
   Else If(RC1[R]<0)and(RC2[R]>=0)Then Begin
    S:=CondStr(B,not RNeg[R]);
    PutLn(Ind,'if ('+S+') {');
    EmitList(RC2[R],Ind+1,InLoop and IsLast);
    PutLn(Ind,'}');
   End
   Else Begin
    PutLn(Ind,'if ('+S+') {');
    EmitList(RC1[R],Ind+1,InLoop and IsLast);
    If(RC2[R]>=0)and not ListEmpty(RC2[R])Then Begin
     PutLn(Ind,'} else {');
     EmitList(RC2[R],Ind+1,InLoop and IsLast);
    End;
    PutLn(Ind,'}');
   End;
  End;
  RG_WHILE:Begin
   Hdr:=HasStmts(B);
   If Hdr Then Begin
    PutLn(Ind,'for (;;) {');
    PrintBlock(B,Ind+1,False);
    PutLn(Ind+1,'if ('+CondStr(B,not RNeg[R])+') break;');
    EmitList(RC1[R],Ind+1,True);
    PutLn(Ind,'}');
   End
   Else Begin
    If Labeled[B]Then PutLn(Ind-1,'label_'+HexStr(BStart[B],1)+':');
    PutLn(Ind,'while ('+CondStr(B,RNeg[R])+') {');
    EmitList(RC1[R],Ind+1,True);
    PutLn(Ind,'}');
   End;
  End;
  RG_DOWHILE:Begin
   PutLn(Ind,'do {');
   EmitList(RC1[R],Ind+1,False);
   PutLn(Ind,'} while ('+CondStr(B,RNeg[R])+');');
  End;
  RG_LOOP:Begin
   PutLn(Ind,'for (;;) {');
   EmitList(RC1[R],Ind+1,True);
   PutLn(Ind,'}');
  End;
  RG_SWITCH:Begin
   PrintBlock(B,Ind,False);
   E:=SwitchAssign(B);
   If E>=0 Then Begin
    CtxBlk:=B;CtxPos:=E;
    S:=ES(St^[E].B,0);
   End
   Else S:='0';
   PutLn(Ind,'switch ('+S+') {');
   H:=RC1[R];
   While H>=0 do Begin
    For K:=0 to BSwN[B]-1 do
     If SwPool[BSwS[B]+K]=RB[H]Then PutLn(Ind+1,'case '+LStr(K)+':');
    EmitList(RC1[H],Ind+2,False);
    If not EndsWithJump(RC1[H])Then PutLn(Ind+2,'break;');
    H:=RNx[H];
   End;
   PutLn(Ind,'}');
  End;
 End;
End;

Procedure EmitList(R,Ind:Integer;InLoop:Boolean);
Begin
 While R>=0 do Begin
  EmitRegion(R,Ind,InLoop,RNx[R]<0);
  R:=RNx[R];
 End;
End;

{ ---------- fonction complete en C ---------- }
Procedure ResetDecls;
Begin
 NVar:=0;NSlot:=0;
End;

Procedure EmitFunctionC;
Var
 Pass,I,J,K,Hi,Best:LongInt;
 Sig,P,Nm,Ty:AnsiString;
 IsParam:Array[0..255] of Boolean;
 SlotIsParam:Array[0..255] of Boolean;
 Ord_:Array[0..255] of LongInt;
 Cnt,T,NDecl:LongInt;
 Fn:AnsiString;
 Found:Boolean;
Begin
 ComputeRetKind;
 ResetDecls;
 Fn:=FuncNameAt(FnEntry);
 { passe 1 : collecte des variables ; passe 2 : sortie reelle }
 For Pass:=1 to 2 do Begin
  Sink:=(Pass=1);
  If Pass=2 Then Begin
   { signature }
   FillChar(IsParam,SizeOf(IsParam),False);
   FillChar(SlotIsParam,SizeOf(SlotIsParam),False);
   Sig:='';
   If NArgRegs>0 Then Begin
    Hi:=-1;
    For K:=0 to NArgRegs-1 do
     If(LiveIn[EntryBlk]and(Int64(1)shl ArgRegs[K]))<>0 Then Hi:=K;
    For K:=0 to Hi do Begin
     If(CpuMode=32)and((LiveIn[EntryBlk]and(Int64(1)shl ArgRegs[K]))=0)Then Continue;
     Best:=-1;
     For I:=0 to NVar-1 do
      If VarTab[I].Canon=ArgRegs[K]Then
       If(Best<0)or(VarTab[I].Sz>VarTab[Best].Sz)Then Best:=I;
     If Sig<>''Then Sig:=Sig+', ';
     If Best>=0 Then Begin
      Sig:=Sig+VarTab[Best].CType+' '+VarTab[Best].Name;
      IsParam[Best]:=True;
     End
     Else If CpuMode=64 Then Sig:=Sig+'int64_t '+RegName(RC_GPR,ArgRegs[K],8,False)
     Else Sig:=Sig+'int32_t '+RegName(RC_GPR,ArgRegs[K],4,False);
    End;
   End;
   { arguments sur la pile }
   Cnt:=0;
   For I:=0 to NSlot-1 do
    If SlotOff[I]>=PtrSz Then Begin Ord_[Cnt]:=I;Inc(Cnt);End;
   For I:=0 to Cnt-2 do
    For J:=I+1 to Cnt-1 do
     If SlotOff[Ord_[J]]<SlotOff[Ord_[I]]Then Begin T:=Ord_[I];Ord_[I]:=Ord_[J];Ord_[J]:=T;End;
   For I:=0 to Cnt-1 do Begin
    If Sig<>''Then Sig:=Sig+', ';
    If SlotFp[Ord_[I]]Then Ty:=FT(SlotSz[Ord_[I]]) Else Ty:=IT(SlotSz[Ord_[I]]);
    Sig:=Sig+Ty+' '+SlotName(SlotOff[Ord_[I]]);
    SlotIsParam[Ord_[I]]:=True;
   End;
   If Sig=''Then Sig:='void';
   FlushExterns;
   PutLn(0,RetTypeStr+' '+Fn+'('+Sig+') {');
   NDecl:=0;
   { declarations locales }
   For I:=0 to NSlot-1 do
    If not SlotIsParam[I]Then Begin
     If SlotFp[I]Then Ty:=FT(SlotSz[I]) Else Ty:=IT(SlotSz[I]);
     If SlotOff[I]=0 Then Continue;
     PutLn(1,Ty+' '+SlotName(SlotOff[I])+';');
     Inc(NDecl);
    End;
   For I:=0 to NVar-1 do
    If not IsParam[I]Then Begin
     PutLn(1,VarTab[I].CType+' '+VarTab[I].Name+';');
     Inc(NDecl);
    End;
   If NDecl>0 Then PutLn(0,'');
  End;
  EmitList(FnRoot,1,False);
  If Pass=2 Then PutLn(0,'}');
 End;
 Sink:=False;
End;

{ ============================================================
  SORTIES DOT
  ============================================================ }
Function DotEsc(Const S:AnsiString):AnsiString;
Var I:Integer;R:AnsiString;
Begin
 R:='';
 For I:=1 to Length(S)do Begin
  Case S[I] of
   '"':R:=R+'\"';
   '\':R:=R+'\\';
   '<':R:=R+'\<';
   '>':R:=R+'\>';
   '{':R:=R+'\{';
   '}':R:=R+'\}';
   '|':R:=R+'\|';
   Else R:=R+S[I];
  End;
 End;
 DotEsc:=R;
End;

Function BlkId(B:LongInt):AnsiString;
Begin
 BlkId:='bb_'+HexStr(BStart[B],1);
End;

Function ExtId(A:Int64):AnsiString;
Begin
 ExtId:='ext_'+HexStr(A,1);
End;

Procedure DotCfgFunction;
Var B,I,X:LongInt;S:AnsiString;Fn:AnsiString;
Begin
 Fn:=FuncNameAt(FnEntry);
 W(OUT_CFG,'  subgraph cluster_'+HexStr(FnEntry,1)+' {');
 W(OUT_CFG,'    label="'+DotEsc(Fn)+'";');
 For B:=0 to NB-1 do Begin
  S:='';
  For I:=BI0[B] to BI0[B]+BN[B]-1 do Begin
   X:=FnIns^[I];
   S:=S+DotEsc(HexStr(Ins^[X].Addr,1)+': '+FmtInsn(Ins^[X]))+'\l';
  End;
  W(OUT_CFG,'    '+BlkId(B)+' [label="'+S+'"];');
 End;
 For B:=0 to NB-1 do Begin
  Case BKind[B] of
   BK_FALL,BK_JMP:If BS0[B]>=0 Then W(OUT_CFG,'    '+BlkId(B)+' -> '+BlkId(BS0[B])+';');
   BK_SWITCH:For X:=0 to NSucc(B)-1 do W(OUT_CFG,'    '+BlkId(B)+' -> '+BlkId(SuccOf(B,X))+' [label="case"];');
   BK_JCC:Begin
    If BS0[B]>=0 Then W(OUT_CFG,'    '+BlkId(B)+' -> '+BlkId(BS0[B])+' [label="true"];')
    Else Begin
     W(OUT_CFG,'    '+ExtId(BTgt[B])+' [label="'+DotEsc(FuncNameAt(BTgt[B]))+'", shape=ellipse];');
     W(OUT_CFG,'    '+BlkId(B)+' -> '+ExtId(BTgt[B])+' [label="true"];');
    End;
    If BS1[B]>=0 Then W(OUT_CFG,'    '+BlkId(B)+' -> '+BlkId(BS1[B])+' [label="false"];');
   End;
   BK_TAIL:Begin
    W(OUT_CFG,'    '+ExtId(BTgt[B])+' [label="'+DotEsc(FuncNameAt(BTgt[B]))+'", shape=ellipse];');
    W(OUT_CFG,'    '+BlkId(B)+' -> '+ExtId(BTgt[B])+' [style=dashed];');
   End;
  End;
 End;
 W(OUT_CFG,'  }');
End;

Procedure DotIrFunction;
Var B,K:LongInt;S,Fn,T:AnsiString;C:LongInt;
Begin
 Fn:=FuncNameAt(FnEntry);
 W(OUT_IR,'  subgraph cluster_'+HexStr(FnEntry,1)+' {');
 W(OUT_IR,'    label="'+DotEsc(Fn)+'";');
 NVar:=0;NSlot:=0;
 For B:=0 to NB-1 do Begin
  S:='';
  CtxBlk:=B;
  For K:=SB0[B] to SB0[B]+SBN[B]-1 do Begin
   CtxPos:=K;
   Case St^[K].Kind of
    ST_NOP:;
    ST_ASSIGN,ST_STORE,ST_FLAGS,ST_PUSH,ST_POP,ST_EXPR,ST_ASM:Begin
     If(St^[K].Kind in[ST_PUSH,ST_POP])and(St^[K].FK=1)Then Continue;
     S:=S+DotEsc(StmtStr(K,True))+'\l';
    End;
    ST_JMP:If BS0[B]>=0 Then S:=S+DotEsc('goto '+BlkId(BS0[B]))+'\l';
    ST_JCC:Begin
     CtxPos:=K;
     T:='if ('+ES(St^[K].A,0)+') goto ';
     If BS0[B]>=0 Then T:=T+BlkId(BS0[B]) Else T:=T+TailCallStr(B);
     If BS1[B]>=0 Then T:=T+' else goto '+BlkId(BS1[B]);
     S:=S+DotEsc(T)+'\l';
    End;
    ST_RET:S:=S+'return\l';
    ST_IJMP:If BKind[B]=BK_SWITCH Then S:=S+DotEsc('switch ('+ES(St^[K].A,0)+')')+'\l'
     Else S:=S+DotEsc('goto *'+ES(St^[K].A,PR_UNARY))+'\l';
    ST_HALT:S:=S+'halt\l';
    ST_TAIL:S:=S+DotEsc('return '+ES(St^[K].A,0))+'\l';
   End;
  End;
  W(OUT_IR,'    '+BlkId(B)+' [label="'+DotEsc(HexStr(BStart[B],1)+':')+'\l'+S+'"];');
 End;
 For B:=0 to NB-1 do Begin
  Case BKind[B] of
   BK_FALL,BK_JMP:If BS0[B]>=0 Then W(OUT_IR,'    '+BlkId(B)+' -> '+BlkId(BS0[B])+';');
   BK_SWITCH:For K:=0 to NSucc(B)-1 do W(OUT_IR,'    '+BlkId(B)+' -> '+BlkId(SuccOf(B,K))+' [label="case"];');
   BK_JCC:Begin
    If BS0[B]>=0 Then W(OUT_IR,'    '+BlkId(B)+' -> '+BlkId(BS0[B])+' [label="true"];');
    If BS1[B]>=0 Then W(OUT_IR,'    '+BlkId(B)+' -> '+BlkId(BS1[B])+' [label="false"];');
   End;
  End;
 End;
 W(OUT_IR,'  }');
End;

Function RegionLabel(R:LongInt):AnsiString;
Begin
 Case RT[R] of
  RG_BLOCK:RegionLabel:='block '+HexStr(BStart[RB[R]],1);
  RG_IF:Begin
   If RC2[R]>=0 Then RegionLabel:='if-else '+HexStr(BStart[RB[R]],1)
   Else RegionLabel:='if '+HexStr(BStart[RB[R]],1);
  End;
  RG_WHILE:RegionLabel:='while '+HexStr(BStart[RB[R]],1);
  RG_DOWHILE:RegionLabel:='do-while '+HexStr(BStart[RB[R]],1);
  RG_LOOP:RegionLabel:='loop '+HexStr(BStart[RB[R]],1);
  RG_GOTO:RegionLabel:='goto '+HexStr(BStart[RB[R]],1);
  RG_BREAK:RegionLabel:='break';
  RG_CONT:RegionLabel:='continue';
  RG_TAIL:RegionLabel:='tail-call '+HexStr(BTgt[RB[R]],1);
  RG_SWITCH:RegionLabel:='switch '+HexStr(BStart[RB[R]],1);
  RG_CASE:RegionLabel:='case -> '+HexStr(BStart[RB[R]],1);
  Else RegionLabel:='?';
 End;
End;

Procedure DotList(Parent:LongInt;Head:LongInt;Const Role:AnsiString);forward;

Function RId(R:LongInt):AnsiString;
Begin
 RId:='r'+HexStr(FnEntry,1)+'_'+LStr(R);
End;

Procedure DotList(Parent:LongInt;Head:LongInt;Const Role:AnsiString);
Var R,Prev:LongInt;Shp:AnsiString;
Begin
 Prev:=-1;
 R:=Head;
 While R>=0 do Begin
  If RT[R]in[RG_BLOCK,RG_GOTO,RG_BREAK,RG_CONT,RG_TAIL]Then Shp:='box' Else Shp:='ellipse';
  W(OUT_REG,'    '+RId(R)+' [label="'+DotEsc(RegionLabel(R))+'", shape='+Shp+'];');
  If Prev<0 Then Begin
   If Parent<0 Then Else W(OUT_REG,'    '+RId(Parent)+' -> '+RId(R)+' [label="'+Role+'"];');
  End
  Else W(OUT_REG,'    '+RId(Prev)+' -> '+RId(R)+' [style=dashed, label="next"];');
  Case RT[R] of
   RG_IF:Begin
    DotList(R,RC1[R],'then');
    If RC2[R]>=0 Then DotList(R,RC2[R],'else');
   End;
   RG_WHILE,RG_DOWHILE,RG_LOOP,RG_CASE:DotList(R,RC1[R],'body');
   RG_SWITCH:DotList(R,RC1[R],'case');
  End;
  Prev:=R;
  R:=RNx[R];
 End;
End;

Procedure DotRegionsFunction;
Var Fn:AnsiString;
Begin
 Fn:=FuncNameAt(FnEntry);
 W(OUT_REG,'  subgraph cluster_'+HexStr(FnEntry,1)+' {');
 W(OUT_REG,'    label="'+DotEsc(Fn)+'";');
 DotList(-1,FnRoot,'');
 W(OUT_REG,'  }');
End;

{ ============================================================
  SECTIONS, SYMBOLES, INSTRUCTIONS
  ============================================================ }
Procedure PrintSections;
Var I:LongInt;F:AnsiString;
Begin
 W(OUT_SEC,'# '+CurFile+' : '+FmtName);
 W(OUT_SEC,'# entry point: '+Hex0x(EntryAddr));
 W(OUT_SEC,PadR('name',24)+PadR('address',20)+PadR('size',12)+'flags');
 For I:=0 to NSeg-1 do Begin
  F:='';
  If(Segs[I].Flags and SF_READ)<>0 Then F:=F+'r' Else F:=F+'-';
  If(Segs[I].Flags and SF_WRITE)<>0 Then F:=F+'w' Else F:=F+'-';
  If(Segs[I].Flags and SF_EXEC)<>0 Then F:=F+'x' Else F:=F+'-';
  If(Segs[I].Flags and SF_EXEC)<>0 Then F:=F+' code'
  Else If(Segs[I].Flags and SF_BSS)<>0 Then F:=F+' bss'
  Else F:=F+' data';
  W(OUT_SEC,PadR(Segs[I].Name,24)+PadR('0x'+HexStr(Segs[I].Addr,8),20)+PadR('0x'+HexStr(Segs[I].Size,1),12)+F);
 End;
End;

Procedure PrintSymbols;
Var I:LongInt;K:AnsiString;
Begin
 PrepSyms;
 W(OUT_SYM,'# '+CurFile+' : '+FmtName);
 W(OUT_SYM,PadR('address',20)+PadR('size',10)+PadR('type',10)+'name');
 For I:=0 to NSym-1 do Begin
  With Syms[SymOrder[I]]do Begin
   Case Kind of
    SK_FUNC:K:='function';
    SK_OBJECT:K:='object';
    SK_IMPORT:K:='import';
    SK_THUNK:K:='thunk';
    SK_ENTRY:K:='entry';
    SK_EXPORT:K:='export';
    Else K:='notype';
   End;
   If InRange(Addr)Then
    W(OUT_SYM,PadR('0x'+HexStr(Addr,8),20)+PadR('0x'+HexStr(Size,1),10)+PadR(K,10)+Name);
  End;
 End;
End;

Procedure PrintInstructions;
Var
 S:LongInt;
 A,EndA:Int64;
 Ii:TInsn;
 Bytes,Nm:AnsiString;
 K:Integer;
 Cmt:AnsiString;
Begin
 For S:=0 to NSeg-1 do Begin
  If(Segs[S].Flags and SF_EXEC)=0 Then Continue;
  A:=Segs[S].Addr;EndA:=A+Segs[S].Size;
  If HasFrom and(A<OptFrom)Then A:=OptFrom;
  If HasTo and(EndA>OptTo)Then EndA:=OptTo;
  While A<EndA do Begin
   Decode(A,Ii);
   Nm:=SymName(A);
   If Nm<>''Then W(OUT_INS,Nm+':');
   Bytes:='';
   For K:=0 to Ii.Len-1 do Begin
    If K<10 Then Bytes:=Bytes+HexStr(RdByte(A+K),2)+' ';
   End;
   If Ii.Len>10 Then Bytes:=Bytes+'..';
   Cmt:='';
   For K:=0 to Ii.N-1 do Begin
    If Ii.Op[K].Kind=OK_REL Then Begin
     Nm:=SymName(Ii.Op[K].Disp);
     If Nm<>''Then Cmt:=' ; '+Nm;
    End
    Else If(Ii.Op[K].Kind=OK_MEM)and(Ii.Op[K].Base=16)Then Begin
     Nm:=SymName(Ii.Op[K].Disp);
     Cmt:=' ; '+Hex0x(Ii.Op[K].Disp);
     If Nm<>''Then Cmt:=Cmt+' <'+Nm+'>'
     Else Begin
      Nm:=ImportAt(Ii.Op[K].Disp);
      If Nm<>''Then Cmt:=Cmt+' <'+Nm+'>';
     End;
    End;
   End;
   W(OUT_INS,'0x'+HexStr(A,8)+': '+PadR(Bytes,31)+FmtInsn(Ii)+Cmt);
   A:=A+Ii.Len;
  End;
 End;
End;

{ ============================================================
  LIGNE DE COMMANDE
  ============================================================ }
Procedure Usage;
Begin
 WriteLn('NOCODE ',NOCODE_VERSION,' - desassembleur / decompilateur C/C++ (clone de Snowman)');
 WriteLn;
 WriteLn('Syntaxe : NOCODE [options] [--] fichier...');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  --help, -h                  Affiche cette aide.');
 WriteLn('  --verbose, -v               Affiche la progression sur la sortie d''erreur.');
 WriteLn('  --print-sections[=FILE]     Affiche les sections du fichier executable.');
 WriteLn('  --print-symbols[=FILE]      Extrait les symboles du programme.');
 WriteLn('  --print-instructions[=FILE] Extrait les instructions desassemblees.');
 WriteLn('  --print-cfg[=FILE]          Exporte le graphe de flot de controle (DOT).');
 WriteLn('  --print-ir[=FILE]           Exporte la representation intermediaire (DOT).');
 WriteLn('  --print-regions[=FILE]      Exporte les regions de l''analyse structurelle (DOT).');
 WriteLn('  --print-cxx[=FILE]          Produit le code C/C++ reconstruit.');
 WriteLn('  --from[=ADDR]               Adresse de debut du desassemblage (hexadecimal).');
 WriteLn('  --to[=ADDR]                 Adresse de fin du desassemblage (hexadecimal).');
 WriteLn('  --                          Separe les options des fichiers a traiter.');
 WriteLn;
 WriteLn('Sans option --print-*, --print-cxx est utilise.  Sans =FILE, la sortie');
 WriteLn('est la sortie standard.  Formats : ELF 32/64, PE32/PE32+, DOS MZ, COM (x86).');
End;

Function LooksNumeric(Const S:String):Boolean;
Var V:Int64;
Begin
 LooksNumeric:=False;
 If S=''Then Exit;
 If S[1]='-'Then Exit;
 If not ParseHex(S,V)Then Exit;
 { un nom de fichier existant a la priorite }
 LooksNumeric:=True;
End;

Function ParseArgs:Boolean;
Var
 I,P:Integer;
 A,Opt,Val:String;
 HasEq,OnlyFiles:Boolean;
 V:Int64;
 Fx:File;

 Function OptFile(Var On:Boolean;Var F:String):Boolean;
 Begin
  On:=True;
  If HasEq Then F:=Val;
  OptFile:=True;
 End;
Begin
 ParseArgs:=True;
 NFiles:=0;OnlyFiles:=False;
 I:=1;
 While I<=ParamCount do Begin
  A:=ParamStr(I);
  Inc(I);
  If OnlyFiles or(A='')or(A[1]<>'-')or(A='-')Then Begin
   If NFiles<MAXFILES Then Begin Files[NFiles]:=A;Inc(NFiles);End;
   Continue;
  End;
  If A='--'Then Begin OnlyFiles:=True;Continue;End;
  P:=Pos('=',A);
  HasEq:=P>0;
  If HasEq Then Begin Opt:=Copy(A,1,P-1);Val:=Copy(A,P+1,255);End
   Else Begin Opt:=A;Val:='';End;
  If(Opt='-h')or(Opt='--help')Then OptHelp:=True
  Else If(Opt='-v')or(Opt='--verbose')Then OptVerbose:=True
  Else If Opt='--print-sections' Then OptFile(OptSections,FSections)
  Else If Opt='--print-symbols' Then OptFile(OptSymbols,FSymbols)
  Else If Opt='--print-instructions' Then OptFile(OptInsns,FInsns)
  Else If Opt='--print-cfg' Then OptFile(OptCfg,FCfg)
  Else If Opt='--print-ir' Then OptFile(OptIr,FIr)
  Else If Opt='--print-regions' Then OptFile(OptRegions,FRegions)
  Else If Opt='--print-cxx' Then OptFile(OptCxx,FCxx)
  Else If(Opt='--from')or(Opt='--to')Then Begin
   If not HasEq and(I<=ParamCount)and LooksNumeric(ParamStr(I))Then Begin
    Assign(Fx,ParamStr(I));Reset(Fx,1);
    If IOResult<>0 Then Begin Val:=ParamStr(I);HasEq:=True;Inc(I);End
     Else Close(Fx);
   End;
   If not HasEq Then Begin
    WriteLn(StdErr,'nocode: l''option ',Opt,' requiert une adresse');
    ParseArgs:=False;
   End
   Else If not ParseHex(Val,V)Then Begin
    WriteLn(StdErr,'nocode: adresse invalide : ',Val);
    ParseArgs:=False;
   End
   Else If Opt='--from' Then Begin OptFrom:=V;HasFrom:=True;End
   Else Begin OptTo:=V;HasTo:=True;End;
  End
  Else Begin
   WriteLn(StdErr,'nocode: option inconnue : ',A);
   ParseArgs:=False;
  End;
 End;
End;

Procedure OpenOutput(Idx:Integer;Const FName:String);
Begin
 OutOn[Idx]:=False;
 Assign(Outs[Idx],FName);
 If(FName<>'')and OutOpened[Idx]Then Begin
  Append(Outs[Idx]);
  If IOResult<>0 Then Rewrite(Outs[Idx]);
 End
 Else Rewrite(Outs[Idx]);
 If IOResult<>0 Then Begin
  Warn('impossible de creer '''+FName+'''');
  Exit;
 End;
 OutOn[Idx]:=True;
 OutStd[Idx]:=(FName='');
 OutOpened[Idx]:=True;
End;

Procedure CloseOutput(Idx:Integer);
Begin
 If OutOn[Idx]Then Begin
  Close(Outs[Idx]);
  OutOn[Idx]:=False;
 End;
End;

Function ProcessFile(Const Name:String):Boolean;
Var
 I:LongInt;
 Any:Boolean;
 NeedFn:Boolean;
 NDone:LongInt;
Begin
 ProcessFile:=False;
 CurFile:=Name;
 Verbose('lecture de '+Name);
 If not LoadFile(Name)Then Exit;
 If not LoadImage Then Begin FreeFile;Exit;End;
 Verbose('format : '+FmtName+', point d''entree 0x'+HexStr(EntryAddr,1));
 InitCache;
 DiscoverPlt;
 NeedFn:=OptCfg or OptIr or OptRegions or OptCxx;
 If OptSections Then OpenOutput(OUT_SEC,FSections);
 If OptSymbols Then OpenOutput(OUT_SYM,FSymbols);
 If OptInsns Then OpenOutput(OUT_INS,FInsns);
 If OptCfg Then OpenOutput(OUT_CFG,FCfg);
 If OptIr Then OpenOutput(OUT_IR,FIr);
 If OptRegions Then OpenOutput(OUT_REG,FRegions);
 If OptCxx Then OpenOutput(OUT_CXX,FCxx);

 If NeedFn Then DiscoverFunctions;
 If OptSections Then Begin Verbose('sections...');PrintSections;End;
 If OptSymbols Then Begin Verbose('symboles...');PrintSymbols;End;
 If OptInsns Then Begin Verbose('instructions...');PrintInstructions;End;

 If NeedFn Then Begin
  If OptCfg Then Begin
   W(OUT_CFG,'digraph "'+DotEsc(Name)+'" {');
   W(OUT_CFG,'  node [shape=box, fontname="Courier"];');
  End;
  If OptIr Then Begin
   W(OUT_IR,'digraph "'+DotEsc(Name)+'" {');
   W(OUT_IR,'  node [shape=box, fontname="Courier"];');
  End;
  If OptRegions Then Begin
   W(OUT_REG,'digraph "'+DotEsc(Name)+'" {');
   W(OUT_REG,'  node [fontname="Courier"];');
  End;
  If OptCxx Then Begin
   W(OUT_CXX,'/* '+Name+' : '+FmtName+' - genere par NOCODE '+NOCODE_VERSION+' */');
   W(OUT_CXX,'#include <stdint.h>');
   W(OUT_CXX,'#include <stdbool.h>');
   W(OUT_CXX,'');
  End;
  NDeclSeen:=0;NPend:=0;
  If OptIr or OptRegions or OptCxx Then Begin
   Verbose('analyse des signatures...');
   FillChar(SigOk,SizeOf(SigOk),False);
   For I:=0 to NRoot-1 do Begin
    ExploreFn(RootAddr[I],False);
    If NB>0 Then AnalyzeFunction;
   End;
  End;
  If OptCxx and(NRoot>0)Then Begin
   For I:=0 to NRoot-1 do
    If SigOk[I]and InRange(RootAddr[I])Then W(OUT_CXX,SigRetType(I)+' '+FuncNameAt(RootAddr[I])+'();');
   W(OUT_CXX,'');
  End;
  NDone:=0;
  For I:=0 to NRoot-1 do Begin
   ExploreFn(RootAddr[I],False);
   If NB=0 Then Continue;
   Inc(NDone);
   If(NDone and 63)=0 Then Verbose('  '+LStr(NDone)+'/'+LStr(NRoot)+' fonctions');
   If OptCfg Then DotCfgFunction;
   If OptIr or OptRegions or OptCxx Then Begin
    AnalyzeFunction;
    BuildRegions;
    If OptIr Then DotIrFunction;
    If OptRegions Then DotRegionsFunction;
    If OptCxx Then Begin
     If FnTrunc Then W(OUT_CXX,'/* fonction tronquee (trop grande) */');
     EmitFunctionC;
     W(OUT_CXX,'');
    End;
   End;
  End;
  If NRoot=0 Then Warn('aucune fonction trouvee dans '+Name);
  If OptCfg Then W(OUT_CFG,'}');
  If OptIr Then W(OUT_IR,'}');
  If OptRegions Then W(OUT_REG,'}');
 End;
 For I:=0 to 6 do CloseOutput(I);
 FreeImage;
 FreeFile;
 ProcessFile:=True;
End;

Var
 MainI:Integer;
 AllOk:Boolean;
Begin
 OptHelp:=False;OptVerbose:=False;
 OptSections:=False;OptSymbols:=False;OptInsns:=False;OptCfg:=False;
 OptIr:=False;OptRegions:=False;OptCxx:=False;
 HasFrom:=False;HasTo:=False;OptFrom:=0;OptTo:=0;
 FSections:='';FSymbols:='';FInsns:='';FCfg:='';FIr:='';FRegions:='';FCxx:='';
 FillChar(OutOpened,SizeOf(OutOpened),False);
 FillChar(OutOn,SizeOf(OutOn),False);
 FillChar(OutStd,SizeOf(OutStd),False);
 Sink:=False;NSeg:=0;NSym:=0;NImp:=0;
 Ins:=Nil;Ex:=Nil;St:=Nil;FileBuf:=Nil;
 If ParamCount=0 Then Begin Usage;Halt(0);End;
 If not ParseArgs Then Begin WriteLn(StdErr,'Essayez ''nocode --help''.');Halt(2);End;
 If OptHelp Then Begin Usage;Halt(0);End;
 If NFiles=0 Then Begin
  WriteLn(StdErr,'nocode: aucun fichier a traiter');
  Halt(2);
 End;
 If not(OptSections or OptSymbols or OptInsns or OptCfg or OptIr or OptRegions or OptCxx)Then OptCxx:=True;
 InitIR;
 AllOk:=True;
 For MainI:=0 to NFiles-1 do
  If not ProcessFile(Files[MainI])Then AllOk:=False;
 If AllOk Then Halt(0) Else Halt(1);
End.
