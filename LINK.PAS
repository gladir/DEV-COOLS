{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program LINK;

{$A-}

Uses DOS;

Const
 MAX_SEGMENTS=128;      { Nombre maximal de segments suivis pendant l'edition de liens }
 MAX_SYMBOLS=1024;      { Nombre maximal de symboles (publics + externes) }
 MAX_RELOCATIONS=2048;  { Nombre maximal d'entrees de relocation en memoire }
 MAX_GROUPS=128;        { Nombre maximal de groupes OMF (GRPDEF) }
 MAX_LNAMES=2048;       { Nombre maximal de noms logiques LNAMES }
 MAX_LINENUMS=4096;     { Nombre maximal d'entrees de debug LINNUM }
 MAX_COMMENTS=2048;     { Nombre maximal d'enregistrements COMENT OMF }
 MAX_ALIASES=1024;      { Nombre maximal de definitions ALIAS }

Type
 { En-tete DOS MZ du fichier executable genere }
 TExeHeader=Record
  Signature:Word;          { Signature DOS 'MZ' }
  LastPageBytes:Word;      { Nombre d'octets utilises dans la derniere page }
  PageCount:Word;          { Nombre total de pages de 512 octets dans l'EXE }
  RelocCount:Word;         { Nombre d'entrees de relocation }
  HeaderSize:Word;         { Taille de l'en-tete en paragraphes (16 octets) }
  MinAlloc:Word;           { Memoire minimale supplementaire demandee }
  MaxAlloc:Word;           { Memoire maximale supplementaire demandee }
  InitSS:Word;             { Valeur initiale de SS (relative au debut de chargement) }
  InitSP:Word;             { Valeur initiale de SP }
  Checksum:Word;           { Somme de controle (souvent 0 si non utilisee) }
  InitIP:Word;             { Valeur initiale de IP }
  InitCS:Word;             { Valeur initiale de CS (relative au debut de chargement) }
  RelocOffset:Word;        { Offset dans l'en-tete de la table de relocation }
  OverlayNumber:Word;      { Numero d'overlay (0 pour programme principal) }
 End;

   { Description d'un segment logique dans l'image liee }
 TSegment=Record
  Name:String[16];         { Nom logique du segment }
  Address:LongInt;         { Adresse/offset de base du segment dans l'image liee }
  Size:Word;               { Taille du segment en octets }
  Class:String[8];         { Classe du segment (CODE, DATA, etc.) }
 End;

   { Description d'un symbole resolu ou externe }
 TSymbol=Record
  Name:String[32];         { Nom du symbole }
  Segment:Word;            { Index du segment de definition (0 si externe) }
  Offset:Word;             { Offset du symbole dans son segment }
  IsExternal:Boolean;      { True si symbole externe non defini dans ce module }
 End;

   { Entree de relocation pour corriger une adresse a l'execution }
 TRelocation=Record
  Offset:Word;             { Offset MZ de la valeur a relocaliser }
  Segment:Word;            { Segment MZ (paragraphe) de la valeur a relocaliser }
  Target:Word;             { Reserve pour informations de cible/fixup }
 End;

 PSegment=^TSegment;
 PSymbol=^TSymbol;

 { Listes chainees des structures principales }
 PSegmentItem=^TSegmentItem;
 TSegmentItem=Record
  Value:TSegment;
  Next:PSegmentItem;
 End;

 PSymbolItem=^TSymbolItem;
 TSymbolItem=Record
  Value:TSymbol;
  Next:PSymbolItem;
 End;

 PRelocationItem=^TRelocationItem;
 TRelocationItem=Record
  Value:TRelocation;
  Next:PRelocationItem;
 End;

 PGroupMemberItem=^TGroupMemberItem;
 TGroupMemberItem=Record
  SegIndex:Word;
  Next:PGroupMemberItem;
 End;

 PGroupItem=^TGroupItem;
 TGroupItem=Record
  NameIndex:Word;
  Is32Bit:Boolean;
  MemberHead,MemberTail:PGroupMemberItem;
  MemberCount:Integer;
  Next:PGroupItem;
 End;

 PLNameItem=^TLNameItem;
 TLNameItem=Record
  Value:String[64];
  Next:PLNameItem;
 End;

 PLineInfoItem=^TLineInfoItem;
 TLineInfoItem=Record
  GroupIndex:Word;
  SegIndex:Word;
  LineNo:LongInt;
  CodeOffset:LongInt;
  Is32Bit:Boolean;
  Next:PLineInfoItem;
 End;

 PCommentItem=^TCommentItem;
 TCommentItem=Record
  Flags:Byte;
  ClassCode:Byte;
  Text:String[80];
  Next:PCommentItem;
 End;

 { Liste chainee des corrections OFFSET }
 POffsetPatchItem=^TOffsetPatchItem;
 TOffsetPatchItem=Record
  Pos:LongInt;
  Delta:Integer;
  Next:POffsetPatchItem;
 End;

 PBackPatchItem=^TBackPatchItem;
 TBackPatchItem=Record
  SegIndex:Word;
  LocType:Byte;
  PatchOffset:LongInt;
  PatchValue:LongInt;
  Is32Bit:Boolean;
  Next:PBackPatchItem;
 End;

 PAliasItem=^TAliasItem;
 TAliasItem=Record
  AliasName:String[64];
  SubstituteName:String[64];
  Next:PAliasItem;
 End;

 TObjRecBuffer=Array[0..8191] of Byte;

Var
 ObjFile,ExeFile,MapFile:File;
 ExeHeader:TExeHeader;
 SegmentHead,SegmentTail:PSegmentItem;
 SymbolHead,SymbolTail:PSymbolItem;
 RelocationHead,RelocationTail:PRelocationItem;
 GroupHead,GroupTail:PGroupItem;
 LNameHead,LNameTail:PLNameItem;
 LineInfoHead,LineInfoTail:PLineInfoItem;
 CommentHead,CommentTail:PCommentItem;
 OffsetPatchHead,OffsetPatchTail:POffsetPatchItem;
 BackPatchHead,BackPatchTail:PBackPatchItem;
 AliasHead,AliasTail:PAliasItem;
 SegmentCount,SymbolCount,RelocationCount:Integer;
 GroupCount:Integer;
 LNameCount,LineInfoCount:Integer;
 CommentCount:Integer;
 OffsetPatchCount:Integer;
 BackPatchCount:Integer;
 AliasCount:Integer;
 HasEntryPoint:Boolean;
 EntrySegIndex:Word;
 EntryOffset:LongInt;
 StackSize:Word;
 ObjModuleName:String[64];
 ObjFileName,ExeFileName,MapFileName:String;  { Ajout des variables }
 i:Integer;
 Param:string;
 Buffer:Array[0..1023] of Byte;  { Ajout du tampon manquant }

Procedure InitOffsetPatchList;
Begin
 OffsetPatchHead:=Nil;
 OffsetPatchTail:=Nil;
 OffsetPatchCount:=0;
End;

Procedure AddOffsetPatch(Const Pos:LongInt; Const Delta:Integer);
Var item:POffsetPatchItem;
Begin
 If OffsetPatchCount>=MAX_RELOCATIONS Then Begin
  WriteLn('Erreur : Trop de patchs OFFSET');
  Halt(15);
 End;
 New(item);
 item^.Pos:=Pos;
 item^.Delta:=Delta;
 item^.Next:=Nil;
 If OffsetPatchHead=Nil Then OffsetPatchHead:=item
                        Else OffsetPatchTail^.Next:=item;
 OffsetPatchTail:=item;
 Inc(OffsetPatchCount);
End;

Procedure AddBackPatch(Const SegIdx:Word; Const LocTyp:Byte;
                       Const OfsVal,PatchVal:LongInt; Is32Rec:Boolean);
Var item:PBackPatchItem;
Begin
 If BackPatchCount>=MAX_RELOCATIONS Then Begin
  WriteLn('Erreur : Trop d''entrees BAKPAT');
  Halt(18);
 End;
 New(item);
 item^.SegIndex:=SegIdx;
 item^.LocType:=LocTyp;
 item^.PatchOffset:=OfsVal;
 item^.PatchValue:=PatchVal;
 item^.Is32Bit:=Is32Rec;
 item^.Next:=Nil;
 If BackPatchHead=Nil Then BackPatchHead:=item
                     Else BackPatchTail^.Next:=item;
 BackPatchTail:=item;
 Inc(BackPatchCount);
End;

Procedure AddAlias(Const AliasNm,SubNm:String);
Var
 item,scan:PAliasItem;
Begin
 scan:=AliasHead;
 While scan<>Nil do Begin
  If scan^.AliasName=Copy(AliasNm,1,64) Then Begin
   scan^.SubstituteName:=Copy(SubNm,1,64);
   Exit;
  End;
  scan:=scan^.Next;
 End;

 If AliasCount>=MAX_ALIASES Then Begin
  WriteLn('Erreur : Trop de definitions ALIAS');
  Halt(19);
 End;

 New(item);
 item^.AliasName:=Copy(AliasNm,1,64);
 item^.SubstituteName:=Copy(SubNm,1,64);
 item^.Next:=Nil;
 If AliasHead=Nil Then AliasHead:=item
                  Else AliasTail^.Next:=item;
 AliasTail:=item;
 Inc(AliasCount);
End;

Function ResolveAliasName(Const Nm:String):String;
Var
 curName:String[64];
 aliasItem:PAliasItem;
 loopCount:Integer;
 changed:Boolean;
Begin
 curName:=Copy(Nm,1,64);
 For loopCount:=1 to 16 do Begin
  changed:=False;
  aliasItem:=AliasHead;
  While aliasItem<>Nil do Begin
   If aliasItem^.AliasName=curName Then Begin
    If aliasItem^.SubstituteName='' Then Begin
     ResolveAliasName:=curName;
     Exit;
    End;
    curName:=aliasItem^.SubstituteName;
    changed:=True;
    Break;
   End;
   aliasItem:=aliasItem^.Next;
  End;
  If Not changed Then Break;
 End;
 ResolveAliasName:=curName;
End;

Procedure FreeOffsetPatchList;
Var item,nextItem:POffsetPatchItem;
Begin
 item:=OffsetPatchHead;
 While item<>Nil do Begin
  nextItem:=item^.Next;
  Dispose(item);
  item:=nextItem;
 End;
 OffsetPatchHead:=Nil;
 OffsetPatchTail:=Nil;
 OffsetPatchCount:=0;
End;

Procedure InitMainLists;
Begin
 SegmentHead:=Nil;
 SegmentTail:=Nil;
 SymbolHead:=Nil;
 SymbolTail:=Nil;
 RelocationHead:=Nil;
 RelocationTail:=Nil;
 GroupHead:=Nil;
 GroupTail:=Nil;
 LNameHead:=Nil;
 LNameTail:=Nil;
 LineInfoHead:=Nil;
 LineInfoTail:=Nil;
 CommentHead:=Nil;
 CommentTail:=Nil;
 BackPatchHead:=Nil;
 BackPatchTail:=Nil;
 AliasHead:=Nil;
 AliasTail:=Nil;
 SegmentCount:=0;
 SymbolCount:=0;
 RelocationCount:=0;
 GroupCount:=0;
 LNameCount:=0;
 LineInfoCount:=0;
 CommentCount:=0;
 BackPatchCount:=0;
 AliasCount:=0;
End;

Procedure FreeMainLists;
Var
 segItem,nextSeg:PSegmentItem;
 symItem,nextSym:PSymbolItem;
 relItem,nextRel:PRelocationItem;
 grpItem,nextGrp:PGroupItem;
 memItem,nextMem:PGroupMemberItem;
 nameItem,nextName:PLNameItem;
 lineItem,nextLine:PLineInfoItem;
 comItem,nextCom:PCommentItem;
 bakItem,nextBak:PBackPatchItem;
 aliasItem,nextAlias:PAliasItem;
Begin
 segItem:=SegmentHead;
 While segItem<>Nil do Begin
  nextSeg:=segItem^.Next;
  Dispose(segItem);
  segItem:=nextSeg;
 End;
 symItem:=SymbolHead;
 While symItem<>Nil do Begin
  nextSym:=symItem^.Next;
  Dispose(symItem);
  symItem:=nextSym;
 End;
 relItem:=RelocationHead;
 While relItem<>Nil do Begin
  nextRel:=relItem^.Next;
  Dispose(relItem);
  relItem:=nextRel;
 End;

 grpItem:=GroupHead;
 While grpItem<>Nil do Begin
  memItem:=grpItem^.MemberHead;
  While memItem<>Nil do Begin
   nextMem:=memItem^.Next;
   Dispose(memItem);
   memItem:=nextMem;
  End;
  nextGrp:=grpItem^.Next;
  Dispose(grpItem);
  grpItem:=nextGrp;
 End;

 nameItem:=LNameHead;
 While nameItem<>Nil do Begin
  nextName:=nameItem^.Next;
  Dispose(nameItem);
  nameItem:=nextName;
 End;

 lineItem:=LineInfoHead;
 While lineItem<>Nil do Begin
  nextLine:=lineItem^.Next;
  Dispose(lineItem);
  lineItem:=nextLine;
 End;

 comItem:=CommentHead;
 While comItem<>Nil do Begin
  nextCom:=comItem^.Next;
  Dispose(comItem);
  comItem:=nextCom;
 End;

 bakItem:=BackPatchHead;
 While bakItem<>Nil do Begin
  nextBak:=bakItem^.Next;
  Dispose(bakItem);
  bakItem:=nextBak;
 End;

 aliasItem:=AliasHead;
 While aliasItem<>Nil do Begin
  nextAlias:=aliasItem^.Next;
  Dispose(aliasItem);
  aliasItem:=nextAlias;
 End;
 InitMainLists;
End;

Function AddSegment(Const Seg:TSegment):Integer;
Var item:PSegmentItem;
Begin
 If SegmentCount>=MAX_SEGMENTS Then Begin
  WriteLn('Erreur : Trop de segments dans le fichier objet');
  Halt(11);
 End;
 New(item);
 item^.Value:=Seg;
 item^.Next:=Nil;
 If SegmentHead=Nil Then SegmentHead:=item
                    Else SegmentTail^.Next:=item;
 SegmentTail:=item;
 Inc(SegmentCount);
 AddSegment:=SegmentCount;
End;

Procedure AddSymbol(Const Sym:TSymbol);
Var item:PSymbolItem;
Begin
 New(item);
 item^.Value:=Sym;
 item^.Next:=Nil;
 If SymbolHead=Nil Then SymbolHead:=item
                   Else SymbolTail^.Next:=item;
 SymbolTail:=item;
 Inc(SymbolCount);
End;

Function AddGroup(Const NameIdx:Word; Is32Rec:Boolean):PGroupItem;
Var item:PGroupItem;
Begin
 If GroupCount>=MAX_GROUPS Then Begin
  WriteLn('Erreur : Trop de groupes OMF');
  Halt(16);
 End;
 New(item);
 item^.NameIndex:=NameIdx;
 item^.Is32Bit:=Is32Rec;
 item^.MemberHead:=Nil;
 item^.MemberTail:=Nil;
 item^.MemberCount:=0;
 item^.Next:=Nil;
 If GroupHead=Nil Then GroupHead:=item
                   Else GroupTail^.Next:=item;
 GroupTail:=item;
 Inc(GroupCount);
 AddGroup:=item;
End;

Procedure AddGroupMember(GroupItem:PGroupItem; SegIdx:Word);
Var mem:PGroupMemberItem;
Begin
 If GroupItem=Nil Then Exit;
 New(mem);
 mem^.SegIndex:=SegIdx;
 mem^.Next:=Nil;
 If GroupItem^.MemberHead=Nil Then GroupItem^.MemberHead:=mem
                            Else GroupItem^.MemberTail^.Next:=mem;
 GroupItem^.MemberTail:=mem;
 Inc(GroupItem^.MemberCount);
End;

Procedure AddLName(Const Nm:String);
Var item:PLNameItem;
Begin
 If LNameCount>=MAX_LNAMES Then Begin
  WriteLn('Erreur : Trop de noms LNAMES');
  Halt(17);
 End;
 New(item);
 item^.Value:=Copy(Nm,1,64);
 item^.Next:=Nil;
 If LNameHead=Nil Then LNameHead:=item
                   Else LNameTail^.Next:=item;
 LNameTail:=item;
 Inc(LNameCount);
End;

Function GetLName(Index:Word):String;
Var
 item:PLNameItem;
 n:Word;
Begin
 GetLName:='';
 If (Index=0)Or(Index>LNameCount) Then Exit;
 item:=LNameHead;
 n:=1;
 While(item<>Nil)And(n<Index)do Begin
  item:=item^.Next;
  Inc(n);
 End;
 If item<>Nil Then GetLName:=item^.Value;
End;

Procedure AddLineInfo(Const GrpIdx,SegIdx:Word; Const LineNum,CodeOfs:LongInt; Is32Rec:Boolean);
Var item:PLineInfoItem;
Begin
 If LineInfoCount>=MAX_LINENUMS Then Exit;
 New(item);
 item^.GroupIndex:=GrpIdx;
 item^.SegIndex:=SegIdx;
 item^.LineNo:=LineNum;
 item^.CodeOffset:=CodeOfs;
 item^.Is32Bit:=Is32Rec;
 item^.Next:=Nil;
 If LineInfoHead=Nil Then LineInfoHead:=item
                      Else LineInfoTail^.Next:=item;
 LineInfoTail:=item;
 Inc(LineInfoCount);
End;

Procedure AddComment(Const Flags,ClassCode:Byte; Const Txt:String);
Var item:PCommentItem;
Begin
 If CommentCount>=MAX_COMMENTS Then Exit;
 New(item);
 item^.Flags:=Flags;
 item^.ClassCode:=ClassCode;
 item^.Text:=Copy(Txt,1,80);
 item^.Next:=Nil;
 If CommentHead=Nil Then CommentHead:=item
                    Else CommentTail^.Next:=item;
 CommentTail:=item;
 Inc(CommentCount);
End;

Function GetSegmentPtr(Index:Integer):PSegment;
Var
 item:PSegmentItem;
 n:Integer;
Begin
 GetSegmentPtr:=Nil;
 If (Index<=0)Or(Index>SegmentCount) Then Exit;
 item:=SegmentHead;
 n:=1;
 While(item<>Nil)And(n<Index)do Begin
  item:=item^.Next;
  Inc(n);
 End;
 If item<>Nil Then GetSegmentPtr:=@item^.Value;
End;

Procedure AddRelocationEntry(Const OffsetVal,SegmentVal,TargetVal:Word);
Var
 item:PRelocationItem;
 rel:TRelocation;
Begin
 If RelocationCount>=MAX_RELOCATIONS Then Begin
  WriteLn('Erreur : Trop de relocations');
  Halt(14);
 End;
 rel.Offset:=OffsetVal;
 rel.Segment:=SegmentVal;
 rel.Target:=TargetVal;
 New(item);
 item^.Value:=rel;
 item^.Next:=Nil;
 If RelocationHead=Nil Then RelocationHead:=item
                       Else RelocationTail^.Next:=item;
 RelocationTail:=item;
 Inc(RelocationCount);
End;

Function SkipIterBlock16(Var RecBuf:TObjRecBuffer; Var Pos:Integer; Limit:Integer; Var Generated:LongInt):Boolean;
Var
 RepeatCount,BlockCount:Word;
 DataCount:Byte;
 i:Integer;
 SubLen,AddLen:LongInt;
Begin
 Generated:=0;
 SkipIterBlock16:=False;
 If Pos+3>=Limit Then Exit;

 RepeatCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);
 BlockCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);

 If BlockCount=0 Then Begin
  If Pos>=Limit Then Exit;
  DataCount:=RecBuf[Pos];
  Inc(Pos);
  If Pos+DataCount>Limit Then Exit;
  Inc(Pos,DataCount);
  Generated:=LongInt(RepeatCount)*LongInt(DataCount);
  SkipIterBlock16:=True;
  Exit;
 End;

 For i:=1 to BlockCount do Begin
  If Not SkipIterBlock16(RecBuf,Pos,Limit,SubLen) Then Exit;
  AddLen:=LongInt(RepeatCount)*SubLen;
  If Generated>High(LongInt)-AddLen Then Generated:=High(LongInt)
                                 Else Inc(Generated,AddLen);
 End;

 SkipIterBlock16:=True;
End;

Procedure EmitRawSpanToExe(Var ExeF:File; Var RecBuf:TObjRecBuffer;
                           StartPos,Count:Integer; DestBase:LongInt;
                           Var Produced:LongInt; MaxBytes:LongInt);
Var
 Writable:LongInt;
 WriteCount:Word;
Begin
 If Count<=0 Then Exit;
 Writable:=0;
 If Produced<MaxBytes Then Begin
  Writable:=MaxBytes-Produced;
  If Writable>Count Then Writable:=Count;
 End;
 If Writable>0 Then Begin
  WriteCount:=Writable;
  Seek(ExeF,DestBase+Produced);
  BlockWrite(ExeF,RecBuf[StartPos],WriteCount);
 End;
 If Produced>High(LongInt)-Count Then Produced:=High(LongInt)
                                Else Inc(Produced,Count);
End;

Function EmitIterBlock16(Var ExeF:File; Var RecBuf:TObjRecBuffer;
                         Var Pos:Integer; Limit:Integer;
                         DestBase:LongInt; Var Produced:LongInt;
                         MaxBytes:LongInt):Boolean;
Var
 RepeatCount,BlockCount:Word;
 DataCount:Byte;
 i,r:Integer;
 TempPos,SubEnd:Integer;
 DummyLen:LongInt;
 DataStart:Integer;
Begin
 EmitIterBlock16:=False;
 If Pos+3>=Limit Then Exit;

 RepeatCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);
 BlockCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);

 If BlockCount=0 Then Begin
  If Pos>=Limit Then Exit;
  DataCount:=RecBuf[Pos];
  Inc(Pos);
  If Pos+DataCount>Limit Then Exit;
  DataStart:=Pos;
  Inc(Pos,DataCount);

  For r:=1 to RepeatCount do
   EmitRawSpanToExe(ExeF,RecBuf,DataStart,DataCount,DestBase,Produced,MaxBytes);

  EmitIterBlock16:=True;
  Exit;
 End;

 TempPos:=Pos;
 For i:=1 to BlockCount do
  If Not SkipIterBlock16(RecBuf,TempPos,Limit,DummyLen) Then Exit;
 SubEnd:=TempPos;

 For r:=1 to RepeatCount do Begin
  TempPos:=Pos;
  For i:=1 to BlockCount do
   If Not EmitIterBlock16(ExeF,RecBuf,TempPos,SubEnd,DestBase,Produced,MaxBytes) Then Exit;
 End;

 Pos:=SubEnd;
 EmitIterBlock16:=True;
End;

Function SkipIterBlockEx(Var RecBuf:TObjRecBuffer; Var Pos:Integer; Limit:Integer;
                        Use32Repeat:Boolean; Var Generated:LongInt):Boolean;
Var
 RepeatCount,AddLen:LongInt;
 BlockCount:Word;
 DataCount:Byte;
 i:Integer;
 SubLen:LongInt;
Begin
 Generated:=0;
 SkipIterBlockEx:=False;

 If Use32Repeat Then Begin
  If Pos+5>=Limit Then Exit;
  RepeatCount:=LongInt(RecBuf[Pos])
           + LongInt(RecBuf[Pos+1]) * 256
           + LongInt(RecBuf[Pos+2]) * 65536
           + LongInt(RecBuf[Pos+3]) * 16777216;
  Inc(Pos,4);
 End Else Begin
  If Pos+3>=Limit Then Exit;
  RepeatCount:=RecBuf[Pos]+LongInt(RecBuf[Pos+1])*256;
  Inc(Pos,2);
 End;

 BlockCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);

 If BlockCount=0 Then Begin
  If Pos>=Limit Then Exit;
  DataCount:=RecBuf[Pos];
  Inc(Pos);
  If Pos+DataCount>Limit Then Exit;
  Inc(Pos,DataCount);
  Generated:=RepeatCount*LongInt(DataCount);
  SkipIterBlockEx:=True;
  Exit;
 End;

 For i:=1 to BlockCount do Begin
  If Not SkipIterBlockEx(RecBuf,Pos,Limit,Use32Repeat,SubLen) Then Exit;
  AddLen:=RepeatCount*SubLen;
  If Generated>High(LongInt)-AddLen Then Generated:=High(LongInt)
                                 Else Inc(Generated,AddLen);
 End;

 SkipIterBlockEx:=True;
End;

Function EmitIterBlockEx(Var ExeF:File; Var RecBuf:TObjRecBuffer;
                         Var Pos:Integer; Limit:Integer;
                         DestBase:LongInt; Var Produced:LongInt;
                         MaxBytes:LongInt; Use32Repeat:Boolean):Boolean;
Var
 RepeatCount:LongInt;
 BlockCount:Word;
 DataCount:Byte;
 i,r:LongInt;
 TempPos,SubEnd:Integer;
 DummyLen:LongInt;
 DataStart:Integer;
Begin
 EmitIterBlockEx:=False;

 If Use32Repeat Then Begin
  If Pos+5>=Limit Then Exit;
  RepeatCount:=LongInt(RecBuf[Pos])
           + LongInt(RecBuf[Pos+1]) * 256
           + LongInt(RecBuf[Pos+2]) * 65536
           + LongInt(RecBuf[Pos+3]) * 16777216;
  Inc(Pos,4);
 End Else Begin
  If Pos+3>=Limit Then Exit;
  RepeatCount:=RecBuf[Pos]+LongInt(RecBuf[Pos+1])*256;
  Inc(Pos,2);
 End;

 BlockCount:=RecBuf[Pos]+Word(RecBuf[Pos+1])*256;
 Inc(Pos,2);

 If BlockCount=0 Then Begin
  If Pos>=Limit Then Exit;
  DataCount:=RecBuf[Pos];
  Inc(Pos);
  If Pos+DataCount>Limit Then Exit;
  DataStart:=Pos;
  Inc(Pos,DataCount);

  For r:=1 to RepeatCount do
   EmitRawSpanToExe(ExeF,RecBuf,DataStart,DataCount,DestBase,Produced,MaxBytes);

  EmitIterBlockEx:=True;
  Exit;
 End;

 TempPos:=Pos;
 For i:=1 to BlockCount do
  If Not SkipIterBlockEx(RecBuf,TempPos,Limit,Use32Repeat,DummyLen) Then Exit;
 SubEnd:=TempPos;

 For r:=1 to RepeatCount do Begin
  TempPos:=Pos;
  For i:=1 to BlockCount do
   If Not EmitIterBlockEx(ExeF,RecBuf,TempPos,SubEnd,DestBase,Produced,MaxBytes,Use32Repeat) Then Exit;
 End;

 Pos:=SubEnd;
 EmitIterBlockEx:=True;
End;

Function ReadObjFile(Const FileName:String):Boolean;
Var
 RecType:Byte;
 RecLen:Word;
 Buffer:TObjRecBuffer;
 i:Integer;
 SegIndex:Word;
 SegOffset:Word;
 DataLen:Word;
 EndPos:LongInt;
 IdxSize:Integer;
 ModuleEnded:Boolean;
 NameLen:Byte;
 j:Integer;
 LastDataSeg:Word;
 LastDataOfs:Word;
 HasDataContext:Boolean;
 FixPos,FixLimit:Integer;
 Locat,FixDat,FixByte:Byte;
 LocOfs:Word;
 LocKind:Byte;
 LocIsSelfRel:Boolean;
 FrameMethod,TargetMethod:Byte;
 RelocLinearPos,RelocDataPos:LongInt;
 SegSize32:LongInt;
 SymRec:TSymbol;
 SegRec:TSegment;
 SegPtr,PrevSegPtr:PSegment;
 SymItem:PSymbolItem;
 GroupPtr:PGroupItem;
 GroupPos,GroupLimit:Integer;
 ExtPos,ExtLimit:Integer;
 GroupNameIdx,GroupMemberIdx:Word;
 GroupItemType:Byte;
 NamePos,NameLimit:Integer;
 PubPos,PubLimit:Integer;
 LinePos,LineLimit:Integer;
 BaseGroupIdx,BaseSegIdx:Word;
 PubTypeIdx:Word;
 SegNameIdx,SegClassIdx,SegOverlayIdx:Word;
 CommentFlags,CommentClass:Byte;
 ModType,EndDat:Byte;
 EntryFrameIdx,EntryTargetIdx:Word;
 ParsedName:String[64];
 ParsedClass:String[64];
 CommentText:String[80];
 ParsedNameLen:Byte;
 CommentTextLen:Byte;
 PubOfs:LongInt;
 EntryDisp:LongInt;
 LineNum,LineOfs:LongInt;
 IterLen,BlockLen:LongInt;
 LegacyPubParsed:Integer;
 DataOfs32:LongInt;
 TmpPos:Integer;
 ParseOK:Boolean;
 IterPos:Integer;
 k:Integer;
 BakLocType:Byte;
 BakPatchOfs:LongInt;
 BakPatchVal:LongInt;
 LSymFlags:Byte;
 LSymName:String[64];
 LSymContinue:Boolean;
 LSymSeg:Word;
 LSymBaseOfs:LongInt;
 LastLSymName:String[64];
 LastLSymSeg:Word;
 LastLSymBaseOfs:LongInt;
 HasLastLSym:Boolean;
 ComDataType:Byte;
 ComdatFlags:Byte;
 ComdatAttr:Byte;
 ComdatAllocType:Byte;
 ComdatEnumOfs:LongInt;

 Function ReadOmfIndex(Var Pos:Integer; Limit:Integer; Var Idx:Word):Boolean;
 Var b:Byte;
 Begin
  ReadOmfIndex:=False;
  If Pos>=Limit Then Exit;
  b:=Buffer[Pos];
  Inc(Pos);
  If (b And $80)<>0 Then Begin
   If Pos>=Limit Then Exit;
   Idx:=((Word(b And $7F) Shl 8) Or Buffer[Pos]);
   Inc(Pos);
  End Else Idx:=b;
  ReadOmfIndex:=True;
 End;

 Function FindSymbolByName(Const Nm:String; Var SegIdx:Word; Var OfsVal:LongInt):Boolean;
 Var
  symItem:PSymbolItem;
  lookupName:String[64];
 Begin
  FindSymbolByName:=False;
  SegIdx:=0;
  OfsVal:=0;
  lookupName:=ResolveAliasName(Nm);
  symItem:=SymbolHead;
  While symItem<>Nil do Begin
   If (Not symItem^.Value.IsExternal)
      And((symItem^.Value.Name=Nm)Or(symItem^.Value.Name=lookupName)) Then Begin
    SegIdx:=symItem^.Value.Segment;
    OfsVal:=symItem^.Value.Offset;
    FindSymbolByName:=True;
    Exit;
   End;
   symItem:=symItem^.Next;
  End;
 End;

 Function SkipComdefNumber(Var Pos:Integer; Limit:Integer):Boolean;
 Var b:Byte;
 Begin
  SkipComdefNumber:=False;
  If Pos>=Limit Then Exit;
  b:=Buffer[Pos];
  Inc(Pos);
  Case b of
   $81:Begin
    If Pos+1>=Limit Then Exit;
    Inc(Pos,2);
   End;
   $84:Begin
    If Pos+2>=Limit Then Exit;
    Inc(Pos,3);
   End;
   $88:Begin
    If Pos+3>=Limit Then Exit;
    Inc(Pos,4);
   End;
  Else
   If b>$80 Then Exit;
  End;
  SkipComdefNumber:=True;
 End;

Begin
 ReadObjFile:=False;
 FreeMainLists;
 InitMainLists;
 FreeOffsetPatchList;
 InitOffsetPatchList;
 ModuleEnded:=False;
 LastDataSeg:=0;
 LastDataOfs:=0;
 HasDataContext:=False;
 HasLastLSym:=False;
 LastLSymName:='';
 LastLSymSeg:=0;
 LastLSymBaseOfs:=0;
 HasEntryPoint:=False;
 EntrySegIndex:=0;
 EntryOffset:=0;
 {$I-}Assign(ObjFile,FileName);
 Reset(ObjFile, 1);{$I+}
 If IOResult<>0 Then Exit;
 While(Not Eof(ObjFile))and(Not ModuleEnded)do Begin
  BlockRead(ObjFile,RecType,1);
  If Eof(ObjFile) Then Break;
    If RecType<$80 Then RecType:=RecType Or $80;
  BlockRead(ObjFile,RecLen,2);
  If RecLen>SizeOf(Buffer)Then Begin
   WriteLn('Erreur : RecLen sup�rieur � la taille du tampon');
   Halt(10);
  End;
  BlockRead(ObjFile,Buffer,RecLen);
  Case RecType of
    $00..$7F:Begin
     { Codes bas : normalement convertis en forme haute ci-dessus }
    End;
    $80, $82:Begin
      ObjModuleName:='';
      If RecLen>=2 Then Begin
       NameLen:=Buffer[0];
       If NameLen>(RecLen-2) Then NameLen:=RecLen-2;
       If NameLen>64 Then NameLen:=64;
       For j:=1 to NameLen do ObjModuleName:=ObjModuleName+Chr(Buffer[j]);
      End;
    End;
    $84, $86:Begin
      { PEDATA/PIDATA (anciens) : support de compatibilite }
      GroupPos:=0;
      GroupLimit:=RecLen-1; { sans checksum }
      If GroupLimit<=0 Then Continue;

      SegIndex:=Buffer[GroupPos];
      Inc(GroupPos);
      If (SegIndex And $80)<>0 Then Begin
       If GroupPos>=GroupLimit Then Continue;
       SegIndex:=((SegIndex And $7F) Shl 8) Or Buffer[GroupPos];
       Inc(GroupPos);
      End;

      If GroupPos+1>=GroupLimit Then Continue;
      SegOffset:=Buffer[GroupPos]+Word(Buffer[GroupPos+1])*256;
      Inc(GroupPos,2);

      If RecType=$84 Then Begin
       IterLen:=GroupLimit-GroupPos;
      End Else Begin
       IterPos:=GroupPos;
       IterLen:=0;
       While IterPos<GroupLimit do Begin
        BlockLen:=0;
        If Not SkipIterBlock16(Buffer,IterPos,GroupLimit,BlockLen) Then Break;
        If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
                      Else Inc(IterLen,BlockLen);
       End;
      End;

      If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
       SegPtr:=GetSegmentPtr(SegIndex);
       If SegPtr<>Nil Then Begin
        EndPos:=LongInt(SegOffset)+IterLen;
        If EndPos>$FFFF Then EndPos:=$FFFF;
        If EndPos>SegPtr^.Size Then SegPtr^.Size:=EndPos;
        LastDataSeg:=SegIndex;
        LastDataOfs:=SegOffset;
        HasDataContext:=True;
       End;
      End;
    End;
    $88:Begin
     { COMENT : commentaires/directives du compilateur/assembleur }
      GroupLimit:=RecLen-1; { sans checksum }
      If GroupLimit<2 Then Continue;
      CommentFlags:=Buffer[0];
      CommentClass:=Buffer[1];
      CommentTextLen:=GroupLimit-2;
      If CommentTextLen>80 Then CommentTextLen:=80;
      CommentText:='';
      For k:=1 to CommentTextLen do
       CommentText:=CommentText+Chr(Buffer[1+k]);
      AddComment(CommentFlags,CommentClass,CommentText);
    End;
    $8A, $8B:Begin
     { MODEND/MODEND32 : fin de module }
         GroupPos:=0;
         GroupLimit:=RecLen-1; { sans checksum }
         If GroupLimit>0 Then Begin
          ModType:=Buffer[GroupPos];
          Inc(GroupPos);

          { Bit 6 du MODTYP : adresse de depart presente }
          If ((ModType And $40)<>0)And(GroupPos<GroupLimit) Then Begin
           EndDat:=Buffer[GroupPos];
           Inc(GroupPos);

           EntryFrameIdx:=0;
           EntryTargetIdx:=0;
           EntryDisp:=0;

           { Frame datum explicite si F=0 (bit 7) et methode 0..2 }
           FrameMethod:=(EndDat Shr 4) And $07;
           If ((EndDat And $80)=0)And(FrameMethod<=2) Then
      If Not ReadOmfIndex(GroupPos,GroupLimit,EntryFrameIdx) Then GroupPos:=GroupLimit;

           { Target datum explicite si T=0 (bit 3) et methode 0..2 }
           TargetMethod:=EndDat And $03;
           If ((EndDat And $08)=0)And(TargetMethod<=2) Then
      If Not ReadOmfIndex(GroupPos,GroupLimit,EntryTargetIdx) Then GroupPos:=GroupLimit;

           { P=0 => displacement present }
           If (EndDat And $04)=0 Then Begin
      If RecType=$8B Then Begin
       If GroupPos+3<GroupLimit Then Begin
        EntryDisp:=LongInt(Buffer[GroupPos])
          + LongInt(Buffer[GroupPos+1]) * 256
          + LongInt(Buffer[GroupPos+2]) * 65536
          + LongInt(Buffer[GroupPos+3]) * 16777216;
        Inc(GroupPos,4);
       End;
      End Else Begin
       If GroupPos+1<GroupLimit Then Begin
        EntryDisp:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
        Inc(GroupPos,2);
       End;
      End;
           End;

                 { Cas supporte pour MZ: cible segment (SEGDEF index) }
                 If (TargetMethod=0)And(EntryTargetIdx>0) Then Begin
      HasEntryPoint:=True;
      EntrySegIndex:=EntryTargetIdx;
      EntryOffset:=EntryDisp;
           End;
          End;

                { Compatibilite pratique: certains OBJ codent MODEND avec 2 index sur 16 bits }
                If (Not HasEntryPoint)And((ModType And $01)<>0) Then Begin
                 If (RecType=$8A)And(GroupLimit>=7) Then Begin
            EntryFrameIdx:=Word(Buffer[1]) * 256 + Buffer[2];
            EntryTargetIdx:=Word(Buffer[3]) * 256 + Buffer[4];
            EntryDisp:=Buffer[5] + LongInt(Buffer[6]) * 256;
            If EntryTargetIdx=0 Then EntryTargetIdx:=EntryFrameIdx;
            If EntryTargetIdx>0 Then Begin
             HasEntryPoint:=True;
             EntrySegIndex:=EntryTargetIdx;
             EntryOffset:=EntryDisp;
            End;
                 End Else If (RecType=$8B)And(GroupLimit>=9) Then Begin
            EntryFrameIdx:=Word(Buffer[1]) * 256 + Buffer[2];
            EntryTargetIdx:=Word(Buffer[3]) * 256 + Buffer[4];
            EntryDisp:=LongInt(Buffer[5])
              + LongInt(Buffer[6]) * 256
              + LongInt(Buffer[7]) * 65536
              + LongInt(Buffer[8]) * 16777216;
            If EntryTargetIdx=0 Then EntryTargetIdx:=EntryFrameIdx;
            If EntryTargetIdx>0 Then Begin
             HasEntryPoint:=True;
             EntrySegIndex:=EntryTargetIdx;
             EntryOffset:=EntryDisp;
            End;
                 End;
                End;
         End;
     ModuleEnded:=True;
    End;
    $8C, $8D, $B4, $B5, $CC, $CD:Begin { EXTDEF/LEXTDEF/CEXTDEF(compat) : references externes }
     ExtPos:=0;
     ExtLimit:=RecLen-1; { sans checksum }
     If ExtLimit<=0 Then Continue;

     While ExtPos<ExtLimit do Begin
      ParsedNameLen:=Buffer[ExtPos];
      Inc(ExtPos);
      If (ParsedNameLen=0)Or(ExtPos>ExtLimit) Then Break;
      If ExtPos+ParsedNameLen>ExtLimit Then ParsedNameLen:=ExtLimit-ExtPos;

      ParsedName:='';
      For k:=1 to ParsedNameLen do Begin
       ParsedName:=ParsedName+Chr(Buffer[ExtPos]);
       Inc(ExtPos);
      End;

      If Not ReadOmfIndex(ExtPos,ExtLimit,PubTypeIdx) Then Break;

      If SymbolCount>=MAX_SYMBOLS Then Begin
       WriteLn('Erreur : Trop de symboles externes');
       Halt(13);
      End;

      SymRec.Name:=Copy(ParsedName,1,32);
      SymRec.Segment:=0;
      SymRec.Offset:=0;
      SymRec.IsExternal:=True;
      AddSymbol(SymRec);
     End;
    End;
    $8E, $8F:Begin
     { TYPDEF / ancien PUBDEF(32) : tentative de decode PUBDEF, sinon ignore }
     PubPos:=0;
     PubLimit:=RecLen-1; { sans checksum }
     LegacyPubParsed:=0;
     If PubLimit<=0 Then Continue;

     If ReadOmfIndex(PubPos,PubLimit,BaseGroupIdx)
        And ReadOmfIndex(PubPos,PubLimit,BaseSegIdx) Then Begin

      { Garde-fou: index segment aberrant => probablement TYPDEF }
      If BaseSegIdx>MAX_SEGMENTS Then PubPos:=PubLimit;

      { Cas special OMF : BaseSeg=0 => frame explicite }
      If BaseSegIdx=0 Then Begin
       If RecType=$8F Then Begin
        If PubPos+3<PubLimit Then Inc(PubPos,4)
                            Else PubPos:=PubLimit;
       End Else Begin
        If PubPos+1<PubLimit Then Inc(PubPos,2)
                            Else PubPos:=PubLimit;
       End;
      End;

      While PubPos<PubLimit do Begin
       ParsedNameLen:=Buffer[PubPos];
       Inc(PubPos);
       If (ParsedNameLen=0)Or(PubPos>PubLimit) Then Break;
       If PubPos+ParsedNameLen>PubLimit Then ParsedNameLen:=PubLimit-PubPos;

       ParsedName:='';
       For k:=1 to ParsedNameLen do Begin
        ParsedName:=ParsedName+Chr(Buffer[PubPos]);
        Inc(PubPos);
       End;
       If ParsedName='' Then Break;

       If RecType=$8F Then Begin
        If PubPos+3>=PubLimit Then Break;
        PubOfs:=LongInt(Buffer[PubPos])
              + LongInt(Buffer[PubPos+1]) * 256
              + LongInt(Buffer[PubPos+2]) * 65536
              + LongInt(Buffer[PubPos+3]) * 16777216;
        Inc(PubPos,4);
       End Else Begin
        If PubPos+1>=PubLimit Then Break;
        PubOfs:=Buffer[PubPos]+LongInt(Buffer[PubPos+1])*256;
        Inc(PubPos,2);
       End;

       If Not ReadOmfIndex(PubPos,PubLimit,PubTypeIdx) Then Break;

       If SymbolCount>=MAX_SYMBOLS Then Begin
        WriteLn('Erreur : Trop de symboles publics');
        Halt(12);
       End;

       SymRec.Name:=Copy(ParsedName,1,32);
       SymRec.Segment:=BaseSegIdx;
       If PubOfs<0 Then SymRec.Offset:=0
       Else If PubOfs>$FFFF Then SymRec.Offset:=$FFFF
       Else SymRec.Offset:=PubOfs;
       SymRec.IsExternal:=False;
       AddSymbol(SymRec);
       Inc(LegacyPubParsed);
      End;
     End;

     { Si aucun symbole extrait, on considere le record comme TYPDEF et on l'ignore }
    End;
    $90, $91:Begin
     { PUBDEF/PUBDEF32 : definition publique }
     PubPos:=0;
     PubLimit:=RecLen-1; { sans checksum }
     If PubLimit<=0 Then Continue;
     If Not ReadOmfIndex(PubPos,PubLimit,BaseGroupIdx) Then Continue;
     If Not ReadOmfIndex(PubPos,PubLimit,BaseSegIdx) Then Continue;

     { Cas special OMF : BaseSeg=0 => frame explicite }
     If BaseSegIdx=0 Then Begin
      If RecType=$91 Then Begin
       If PubPos+3<PubLimit Then Inc(PubPos,4)
                           Else Continue;
      End Else Begin
       If PubPos+1<PubLimit Then Inc(PubPos,2)
                           Else Continue;
      End;
     End;

     While PubPos<PubLimit do Begin
      ParsedNameLen:=Buffer[PubPos];
      Inc(PubPos);
      If (ParsedNameLen=0)Or(PubPos>PubLimit) Then Break;
      If PubPos+ParsedNameLen>PubLimit Then ParsedNameLen:=PubLimit-PubPos;

      ParsedName:='';
      For k:=1 to ParsedNameLen do Begin
       ParsedName:=ParsedName+Chr(Buffer[PubPos]);
       Inc(PubPos);
      End;

      If RecType=$91 Then Begin
       If PubPos+3>=PubLimit Then Break;
       PubOfs:=LongInt(Buffer[PubPos])
             + LongInt(Buffer[PubPos+1]) * 256
             + LongInt(Buffer[PubPos+2]) * 65536
             + LongInt(Buffer[PubPos+3]) * 16777216;
       Inc(PubPos,4);
      End Else Begin
       If PubPos+1>=PubLimit Then Break;
       PubOfs:=Buffer[PubPos]+LongInt(Buffer[PubPos+1])*256;
       Inc(PubPos,2);
      End;

      If Not ReadOmfIndex(PubPos,PubLimit,PubTypeIdx) Then Break;

      If SymbolCount>=MAX_SYMBOLS Then Begin
       WriteLn('Erreur : Trop de symboles publics');
       Halt(12);
      End;

      SymRec.Name:=Copy(ParsedName,1,32);
      SymRec.Segment:=BaseSegIdx;
      If PubOfs<0 Then SymRec.Offset:=0
      Else If PubOfs>$FFFF Then SymRec.Offset:=$FFFF
      Else SymRec.Offset:=PubOfs;
      SymRec.IsExternal:=False;
      AddSymbol(SymRec);
     End;
    End;
    $92, $93, $B6, $B7:Begin
     { LPUBDEF/LPUBDEF32 : definition publique locale }
     PubPos:=0;
     PubLimit:=RecLen-1; { sans checksum }
     If PubLimit<=0 Then Continue;
     If Not ReadOmfIndex(PubPos,PubLimit,BaseGroupIdx) Then Continue;
     If Not ReadOmfIndex(PubPos,PubLimit,BaseSegIdx) Then Continue;

     { Cas special OMF : BaseSeg=0 => frame explicite }
     If BaseSegIdx=0 Then Begin
      If (RecType=$93)Or(RecType=$B7) Then Begin
       If PubPos+3<PubLimit Then Inc(PubPos,4)
                           Else Continue;
      End Else Begin
       If PubPos+1<PubLimit Then Inc(PubPos,2)
                           Else Continue;
      End;
     End;

     While PubPos<PubLimit do Begin
      ParsedNameLen:=Buffer[PubPos];
      Inc(PubPos);
      If PubPos>PubLimit Then Break;
      If PubPos+ParsedNameLen>PubLimit Then ParsedNameLen:=PubLimit-PubPos;

      ParsedName:='';
      For k:=1 to ParsedNameLen do Begin
       ParsedName:=ParsedName+Chr(Buffer[PubPos]);
       Inc(PubPos);
      End;

      If (RecType=$93)Or(RecType=$B7) Then Begin
       If PubPos+3>=PubLimit Then Break;
       PubOfs:=LongInt(Buffer[PubPos])
             + LongInt(Buffer[PubPos+1]) * 256
             + LongInt(Buffer[PubPos+2]) * 65536
             + LongInt(Buffer[PubPos+3]) * 16777216;
       Inc(PubPos,4);
      End Else Begin
       If PubPos+1>=PubLimit Then Break;
       PubOfs:=Buffer[PubPos]+LongInt(Buffer[PubPos+1])*256;
       Inc(PubPos,2);
      End;

      If Not ReadOmfIndex(PubPos,PubLimit,PubTypeIdx) Then Break;

      If SymbolCount>=MAX_SYMBOLS Then Begin
       WriteLn('Erreur : Trop de symboles publics locaux');
       Halt(12);
      End;

      SymRec.Name:=Copy(ParsedName,1,32);
      SymRec.Segment:=BaseSegIdx;
      If PubOfs<0 Then SymRec.Offset:=0
      Else If PubOfs>$FFFF Then SymRec.Offset:=$FFFF
      Else SymRec.Offset:=PubOfs;
      SymRec.IsExternal:=False;
      AddSymbol(SymRec);
     End;
    End;
    $94, $95:Begin
     { LINNUM/LINNUM32 : information de lignes source }
     LinePos:=0;
     LineLimit:=RecLen-1; { sans checksum }
     If LineLimit<=0 Then Continue;
     If Not ReadOmfIndex(LinePos,LineLimit,BaseGroupIdx) Then Continue;
     If Not ReadOmfIndex(LinePos,LineLimit,BaseSegIdx) Then Continue;

     While LinePos<LineLimit do Begin
      If LinePos+1>=LineLimit Then Break;
      LineNum:=Buffer[LinePos]+LongInt(Buffer[LinePos+1])*256;
      Inc(LinePos,2);

      If RecType=$95 Then Begin
       If LinePos+3>=LineLimit Then Break;
       LineOfs:=LongInt(Buffer[LinePos])
              + LongInt(Buffer[LinePos+1]) * 256
              + LongInt(Buffer[LinePos+2]) * 65536
              + LongInt(Buffer[LinePos+3]) * 16777216;
       Inc(LinePos,4);
      End Else Begin
       If LinePos+1>=LineLimit Then Break;
       LineOfs:=Buffer[LinePos]+LongInt(Buffer[LinePos+1])*256;
       Inc(LinePos,2);
      End;

      AddLineInfo(BaseGroupIdx,BaseSegIdx,LineNum,LineOfs,RecType=$95);
     End;
    End;
    $96, $97, $CA, $CB:Begin
     { LNAMES/LLNAMES : table de noms logiques (segments/classes/overlays) }
     NamePos:=0;
     NameLimit:=RecLen-1; { sans checksum }
     While NamePos<NameLimit do Begin
      ParsedNameLen:=Buffer[NamePos];
      Inc(NamePos);
      If NamePos>NameLimit Then Break;
      If NamePos+ParsedNameLen>NameLimit Then ParsedNameLen:=NameLimit-NamePos;

      ParsedName:='';
      For k:=1 to ParsedNameLen do Begin
       ParsedName:=ParsedName+Chr(Buffer[NamePos]);
       Inc(NamePos);
      End;
      AddLName(ParsedName);
     End;
    End;
    $99:Begin
     { SEGDEF32 : definition de segment avec taille 32 bits }
      SegRec.Name:='';
      SegRec.Class:='CODE';
      SegSize32:=0;
      If RecLen>=6 Then
       SegSize32:=LongInt(Buffer[1])
                 + LongInt(Buffer[2]) * 256
                 + LongInt(Buffer[3]) * 65536
                 + LongInt(Buffer[4]) * 16777216;
      If SegSize32>$FFFF Then SegRec.Size:=$FFFF
                          Else SegRec.Size:=SegSize32;
      SegRec.Address:=0;

      { tentative de resolution des index de noms via LNAMES }
      GroupPos:=0;
      GroupLimit:=RecLen-1;
      If GroupLimit>0 Then Begin
       Inc(GroupPos);      { ACBP }
       Inc(GroupPos,4);    { longueur 32 bits }
       If ReadOmfIndex(GroupPos,GroupLimit,SegNameIdx) Then Begin
        If ReadOmfIndex(GroupPos,GroupLimit,SegClassIdx) Then Begin
         ReadOmfIndex(GroupPos,GroupLimit,SegOverlayIdx);
         ParsedName:=GetLName(SegNameIdx);
         ParsedClass:=GetLName(SegClassIdx);
         If ParsedName<>'' Then SegRec.Name:=Copy(ParsedName,1,16);
         If ParsedClass<>'' Then SegRec.Class:=Copy(ParsedClass,1,8);
        End;
       End;
      End;

      AddSegment(SegRec);
    End;
    $9A, $9B:Begin
      { GRPDEF / GRPDEF32 : definition de groupes de segments }
      GroupPos:=0;
      GroupLimit:=RecLen-1;  { sans checksum OMF }
      If GroupLimit<=0 Then Continue;
      If Not ReadOmfIndex(GroupPos,GroupLimit,GroupNameIdx) Then Continue;

      GroupPtr:=AddGroup(GroupNameIdx, RecType=$9B);

      While GroupPos<GroupLimit do Begin
       GroupItemType:=Buffer[GroupPos];
       Inc(GroupPos);
       Case GroupItemType of
        $FF:Begin { composant segment }
         If Not ReadOmfIndex(GroupPos,GroupLimit,GroupMemberIdx) Then Break;
         AddGroupMember(GroupPtr,GroupMemberIdx);
        End;
        $FE, $FD:Begin
         { composant externe/groupe : consommer l'index, non resolu ici }
         If Not ReadOmfIndex(GroupPos,GroupLimit,GroupMemberIdx) Then Break;
        End;
       Else
        { Tolerance format : tentative index direct }
        Dec(GroupPos);
        If Not ReadOmfIndex(GroupPos,GroupLimit,GroupMemberIdx) Then Break;
        AddGroupMember(GroupPtr,GroupMemberIdx);
       End;
      End;
    End;
    $9C, $9D:Begin
      { FIXUPP / FIXUPP32 : extraction des relocations chargeur MZ }
      If (Not HasDataContext)Or(LastDataSeg=0)Or(LastDataSeg>SegmentCount) Then Continue;
      If RecLen<2 Then Continue;

      { Le dernier octet est le checksum OMF }
      FixPos:=0;
      FixLimit:=RecLen-1;

      While FixPos<FixLimit do Begin
       FixByte:=Buffer[FixPos];
       Inc(FixPos);

       If (FixByte And $80)=0 Then Begin
        { THREAD subrecord : on ne decode pas l'etat interne ici }
        { Le byte de thread est consomme, on poursuit le balayage }
        Continue;
       End;

       { FIXUP subrecord }
       Locat:=FixByte;
       If FixPos>=FixLimit Then Break;
       LocOfs:=(Word(Locat And $03) Shl 8) Or Buffer[FixPos];
       Inc(FixPos);
       LocKind:=(Locat Shr 2) And $0F;
      LocIsSelfRel:=(Locat And $40)<>0;

       If FixPos>=FixLimit Then Break;
       FixDat:=Buffer[FixPos];
       Inc(FixPos);

       { Frame datum explicite }
       If (FixDat And $80)<>0 Then Begin
        FrameMethod:=(FixDat Shr 4) And $07;
        If FrameMethod<=2 Then Begin
         If FixPos>=FixLimit Then Break;
         FixByte:=Buffer[FixPos];
         Inc(FixPos);
         If (FixByte And $80)<>0 Then If FixPos<FixLimit Then Inc(FixPos) Else Break;
        End;
       End;

       { Target datum explicite }
       If (FixDat And $08)<>0 Then Begin
        TargetMethod:=FixDat And $03;
        If TargetMethod<=2 Then Begin
         If FixPos>=FixLimit Then Break;
         FixByte:=Buffer[FixPos];
         Inc(FixPos);
         If (FixByte And $80)<>0 Then If FixPos<FixLimit Then Inc(FixPos) Else Break;
        End;
       End;

       { Displacement cible si P=0 (bit 2 du FIXDAT) }
      If (FixDat And $04)<>0 Then Begin
        If RecType=$9D Then Begin
         If FixPos+3<FixLimit Then Inc(FixPos,4)
              Else FixPos:=FixLimit;
        End Else Begin
         If FixPos+1<FixLimit Then Inc(FixPos,2)
              Else FixPos:=FixLimit;
        End;
       End;

       { On ne genere des relocations MZ que pour BASE (2) et POINTER (3) }
       Case LocKind of
       1:RelocDataPos:=LongInt(LastDataOfs)+LongInt(LocOfs);           { OFFSET 16 }
        2: RelocDataPos:=LongInt(LastDataOfs)+LongInt(LocOfs);
        3: RelocDataPos:=LongInt(LastDataOfs)+LongInt(LocOfs)+2;
       Else
        RelocDataPos:=-1;
       End;

       If RelocDataPos>=0 Then Begin
        SegPtr:=GetSegmentPtr(LastDataSeg);
        If SegPtr=Nil Then Continue;
        RelocLinearPos:=SegPtr^.Address+RelocDataPos;

       { OFFSET segment-relatif : correction a l'edition de liens }
       If (LocKind=1)And(Not LocIsSelfRel) Then Begin
        If (RelocLinearPos>=0)And(RelocLinearPos<=1048575) Then Begin
         AddOffsetPatch(RelocLinearPos, SegPtr^.Address);
        End;
       End;

        If (RelocLinearPos>=0)And(RelocLinearPos<=1048575) Then Begin
         If LocKind In [2,3] Then
          AddRelocationEntry(RelocLinearPos Mod 16, RelocLinearPos Div 16, 0);
        End;
       End;
      End;
    End;
    $9E, $9F:Begin
     { Records OMF historiques/reserves }
     { Le payload est deja lu dans Buffer : on l'ignore volontairement }
    End;
    $B0, $B8:Begin
     { COMDEF/LCOMDEF : communaux, traites comme symboles externes }
     ExtPos:=0;
     ExtLimit:=RecLen-1; { sans checksum }
     If ExtLimit<=0 Then Continue;

     While ExtPos<ExtLimit do Begin
      ParsedNameLen:=Buffer[ExtPos];
      Inc(ExtPos);
      If (ParsedNameLen=0)Or(ExtPos>ExtLimit) Then Break;
      If ExtPos+ParsedNameLen>ExtLimit Then ParsedNameLen:=ExtLimit-ExtPos;

      ParsedName:='';
      For k:=1 to ParsedNameLen do Begin
       ParsedName:=ParsedName+Chr(Buffer[ExtPos]);
       Inc(ExtPos);
      End;

      If Not ReadOmfIndex(ExtPos,ExtLimit,PubTypeIdx) Then Break;
      If ExtPos>=ExtLimit Then Break;

      ComDataType:=Buffer[ExtPos];
      Inc(ExtPos);
      Case ComDataType of
       $61:Begin
      If Not SkipComdefNumber(ExtPos,ExtLimit) Then Break;
      If Not SkipComdefNumber(ExtPos,ExtLimit) Then Break;
       End;
       $62:Begin
      If Not SkipComdefNumber(ExtPos,ExtLimit) Then Break;
       End;
      Else
       Break;
      End;

      If SymbolCount>=MAX_SYMBOLS Then Begin
       WriteLn('Erreur : Trop de symboles externes');
       Halt(13);
      End;

      SymRec.Name:=Copy(ParsedName,1,32);
      SymRec.Segment:=0;
      SymRec.Offset:=0;
      SymRec.IsExternal:=True;
      AddSymbol(SymRec);
     End;
    End;
   $98:Begin { SEGDEF : D�finition de segment OMF }
      SegRec.Name:='';
      SegRec.Class:='CODE';
      If RecLen>=4 Then Move(Buffer[1], SegRec.Size, 2)
            Else SegRec.Size:=0;
      SegRec.Address:=0;

      { tentative de resolution des index de noms via LNAMES }
      GroupPos:=0;
      GroupLimit:=RecLen-1;
      If GroupLimit>0 Then Begin
       Inc(GroupPos);      { ACBP }
       Inc(GroupPos,2);    { longueur 16 bits }
       If ReadOmfIndex(GroupPos,GroupLimit,SegNameIdx) Then Begin
        If ReadOmfIndex(GroupPos,GroupLimit,SegClassIdx) Then Begin
         ReadOmfIndex(GroupPos,GroupLimit,SegOverlayIdx);
         ParsedName:=GetLName(SegNameIdx);
         ParsedClass:=GetLName(SegClassIdx);
         If ParsedName<>'' Then SegRec.Name:=Copy(ParsedName,1,16);
         If ParsedClass<>'' Then SegRec.Class:=Copy(ParsedClass,1,8);
        End;
       End;
      End;

      AddSegment(SegRec);
   End;
   $A0:Begin { LEDATA : Donn�es de segment }
    If RecLen>=5 Then Begin
     IdxSize:=1;
     SegIndex:=Buffer[0];
     If (SegIndex And $80)<>0 Then Begin
      If RecLen<6 Then Continue;
      SegIndex:=((SegIndex And $7F) Shl 8) Or Buffer[1];
      IdxSize:=2;
     End;
     Move(Buffer[IdxSize],SegOffset,2);
     DataLen:=RecLen-IdxSize-2-1; { -index -offset -checksum }
     If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
      SegPtr:=GetSegmentPtr(SegIndex);
      If SegPtr<>Nil Then Begin
       EndPos:=LongInt(SegOffset)+LongInt(DataLen);
       If EndPos>$FFFF Then EndPos:=$FFFF;
       If EndPos>SegPtr^.Size Then SegPtr^.Size:=EndPos;
       LastDataSeg:=SegIndex;
       LastDataOfs:=SegOffset;
       HasDataContext:=True;
      End;
     End;
    End;
   End;
      $A1:Begin
       { LEDATA/LIDATA 32-bit : support pragmatique (brut ou itere) }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       SegIndex:=Buffer[GroupPos];
       Inc(GroupPos);
       If (SegIndex And $80)<>0 Then Begin
        If GroupPos>=GroupLimit Then Continue;
        SegIndex:=((SegIndex And $7F) Shl 8) Or Buffer[GroupPos];
        Inc(GroupPos);
       End;

       If GroupPos+3>=GroupLimit Then Continue;
       DataOfs32:=LongInt(Buffer[GroupPos])
         + LongInt(Buffer[GroupPos+1]) * 256
         + LongInt(Buffer[GroupPos+2]) * 65536
         + LongInt(Buffer[GroupPos+3]) * 16777216;
       Inc(GroupPos,4);

       IterLen:=0;
       TmpPos:=GroupPos;
       ParseOK:=True;
       While TmpPos<GroupLimit do Begin
        BlockLen:=0;
        If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,True,BlockLen) Then Begin
         ParseOK:=False;
         Break;
        End;
        If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
            Else Inc(IterLen,BlockLen);
       End;

      If Not(ParseOK And (TmpPos=GroupLimit)) Then Begin
        IterLen:=0;
        TmpPos:=GroupPos;
        ParseOK:=True;
        While TmpPos<GroupLimit do Begin
         BlockLen:=0;
         If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,False,BlockLen) Then Begin
          ParseOK:=False;
          Break;
         End;
         If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
             Else Inc(IterLen,BlockLen);
        End;
        If Not(ParseOK And (TmpPos=GroupLimit)) Then IterLen:=GroupLimit-GroupPos;
       End;

       If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
        SegPtr:=GetSegmentPtr(SegIndex);
        If SegPtr<>Nil Then Begin
         EndPos:=DataOfs32+IterLen;
         If (DataOfs32<0)Or(EndPos<0)Or(EndPos>$FFFF) Then EndPos:=$FFFF;
         If EndPos>SegPtr^.Size Then SegPtr^.Size:=EndPos;
         LastDataSeg:=SegIndex;
         If DataOfs32<0 Then LastDataOfs:=0
         Else If DataOfs32>$FFFF Then LastDataOfs:=$FFFF
         Else LastDataOfs:=DataOfs32;
         HasDataContext:=True;
        End;
       End;
      End;
      $A2, $A3:Begin
             { LIDATA / LIDATA32 : donnees iterees }
             GroupPos:=0;
             GroupLimit:=RecLen-1; { sans checksum }
             If GroupLimit<=0 Then Continue;

             SegIndex:=Buffer[GroupPos];
             Inc(GroupPos);
             If (SegIndex And $80)<>0 Then Begin
        If GroupPos>=GroupLimit Then Continue;
        SegIndex:=((SegIndex And $7F) Shl 8) Or Buffer[GroupPos];
        Inc(GroupPos);
             End;

             If RecType=$A3 Then Begin
        If GroupPos+3>=GroupLimit Then Continue;
        DataOfs32:=LongInt(Buffer[GroupPos])
          + LongInt(Buffer[GroupPos+1]) * 256
          + LongInt(Buffer[GroupPos+2]) * 65536
          + LongInt(Buffer[GroupPos+3]) * 16777216;
        Inc(GroupPos,4);
             End Else Begin
        If GroupPos+1>=GroupLimit Then Continue;
        DataOfs32:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
        Inc(GroupPos,2);
             End;

             IterLen:=0;
             If RecType=$A3 Then Begin
        TmpPos:=GroupPos;
        ParseOK:=True;
        While TmpPos<GroupLimit do Begin
         BlockLen:=0;
         If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,True,BlockLen) Then Begin
          ParseOK:=False;
          Break;
         End;
         If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
                 Else Inc(IterLen,BlockLen);
        End;

        If Not ParseOK Then Begin
         IterLen:=0;
         TmpPos:=GroupPos;
         While TmpPos<GroupLimit do Begin
          BlockLen:=0;
          If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,False,BlockLen) Then Break;
          If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
                  Else Inc(IterLen,BlockLen);
         End;
        End;
             End Else Begin
        TmpPos:=GroupPos;
        While TmpPos<GroupLimit do Begin
         BlockLen:=0;
         If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,False,BlockLen) Then Break;
         If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
                 Else Inc(IterLen,BlockLen);
        End;
             End;

             If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
        SegPtr:=GetSegmentPtr(SegIndex);
        If SegPtr<>Nil Then Begin
         EndPos:=DataOfs32+IterLen;
         If (DataOfs32<0)Or(EndPos<0)Or(EndPos>$FFFF) Then EndPos:=$FFFF;
         If EndPos>SegPtr^.Size Then SegPtr^.Size:=EndPos;
         LastDataSeg:=SegIndex;
         If DataOfs32<0 Then LastDataOfs:=0
         Else If DataOfs32>$FFFF Then LastDataOfs:=$FFFF
         Else LastDataOfs:=DataOfs32;
         HasDataContext:=True;
        End;
             End;
      End;
      $A4, $A5, $B2, $B3:Begin
        { BAKPAT / BAKPAT32 : enregistre les correctifs a appliquer }
        GroupPos:=0;
        GroupLimit:=RecLen-1; { sans checksum }
        If GroupLimit<=0 Then Continue;

        If Not ReadOmfIndex(GroupPos,GroupLimit,SegIndex) Then Continue;
        If GroupPos>=GroupLimit Then Continue;
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);

        While GroupPos<GroupLimit do Begin
         If (RecType=$A5)Or(RecType=$B3) Then Begin
          If GroupPos+7>=GroupLimit Then Break;
          BakPatchOfs:=LongInt(Buffer[GroupPos])
               + LongInt(Buffer[GroupPos+1]) * 256
               + LongInt(Buffer[GroupPos+2]) * 65536
               + LongInt(Buffer[GroupPos+3]) * 16777216;
          BakPatchVal:=LongInt(Buffer[GroupPos+4])
               + LongInt(Buffer[GroupPos+5]) * 256
               + LongInt(Buffer[GroupPos+6]) * 65536
               + LongInt(Buffer[GroupPos+7]) * 16777216;
          Inc(GroupPos,8);
         End Else Begin
          If GroupPos+3>=GroupLimit Then Break;
          BakPatchOfs:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
          BakPatchVal:=Buffer[GroupPos+2]+LongInt(Buffer[GroupPos+3])*256;
          Inc(GroupPos,4);
         End;

         AddBackPatch(SegIndex,BakLocType,BakPatchOfs,BakPatchVal,(RecType=$A5)Or(RecType=$B3));
        End;
      End;
      $A6, $A7, $C4, $C5:Begin
       { LINSYM / LINSYM32 : infos lignes associees a un symbole }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       If GroupPos>=GroupLimit Then Continue;
       LSymFlags:=Buffer[GroupPos];
       Inc(GroupPos);
       LSymContinue:=(LSymFlags And $01)<>0;

       If GroupPos>=GroupLimit Then Continue;
       ParsedNameLen:=Buffer[GroupPos];
       Inc(GroupPos);
       If ParsedNameLen>64 Then ParsedNameLen:=64;
       If GroupPos+ParsedNameLen>GroupLimit Then ParsedNameLen:=GroupLimit-GroupPos;

       LSymName:='';
       For k:=1 to ParsedNameLen do Begin
        LSymName:=LSymName+Chr(Buffer[GroupPos]);
        Inc(GroupPos);
       End;

       LSymSeg:=0;
       LSymBaseOfs:=0;
       If LSymName<>'' Then Begin
        If FindSymbolByName(LSymName,LSymSeg,LSymBaseOfs) Then Begin
         HasLastLSym:=True;
         LastLSymName:=LSymName;
         LastLSymSeg:=LSymSeg;
         LastLSymBaseOfs:=LSymBaseOfs;
        End Else HasLastLSym:=False;
       End Else If LSymContinue And HasLastLSym Then Begin
        LSymName:=LastLSymName;
        LSymSeg:=LastLSymSeg;
        LSymBaseOfs:=LastLSymBaseOfs;
       End;

       While GroupPos<GroupLimit do Begin
        If GroupPos+1>=GroupLimit Then Break;
        LineNum:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
        Inc(GroupPos,2);

        If (RecType=$A7)Or(RecType=$C5) Then Begin
         If GroupPos+3>=GroupLimit Then Break;
         LineOfs:=LongInt(Buffer[GroupPos])
           + LongInt(Buffer[GroupPos+1]) * 256
           + LongInt(Buffer[GroupPos+2]) * 65536
           + LongInt(Buffer[GroupPos+3]) * 16777216;
         Inc(GroupPos,4);
        End Else Begin
         If GroupPos+1>=GroupLimit Then Break;
         LineOfs:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
         Inc(GroupPos,2);
        End;

        AddLineInfo(0,LSymSeg,LineNum,LSymBaseOfs+LineOfs,(RecType=$A7)Or(RecType=$C5));
       End;
      End;
      $C2, $C3:Begin
       { COMDAT / COMDAT32 : donnees communales initialisees }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;
       If GroupPos+2>=GroupLimit Then Continue;

       ComdatFlags:=Buffer[GroupPos];
       Inc(GroupPos);
       ComdatAttr:=Buffer[GroupPos];
       Inc(GroupPos);
       ComdatAllocType:=ComdatAttr And $0F;

       Inc(GroupPos); { Align }
       If GroupPos>GroupLimit Then Continue;

       If RecType=$C3 Then Begin
        If GroupPos+3>=GroupLimit Then Continue;
        ComdatEnumOfs:=LongInt(Buffer[GroupPos])
             + LongInt(Buffer[GroupPos+1]) * 256
             + LongInt(Buffer[GroupPos+2]) * 65536
             + LongInt(Buffer[GroupPos+3]) * 16777216;
        Inc(GroupPos,4);
       End Else Begin
        If GroupPos+1>=GroupLimit Then Continue;
        ComdatEnumOfs:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
        Inc(GroupPos,2);
       End;

       If Not ReadOmfIndex(GroupPos,GroupLimit,PubTypeIdx) Then Continue;

       LSymSeg:=0;
       LSymBaseOfs:=0;
       If ComdatAllocType=0 Then Begin
        If Not ReadOmfIndex(GroupPos,GroupLimit,BaseGroupIdx) Then Continue;
        If Not ReadOmfIndex(GroupPos,GroupLimit,BaseSegIdx) Then Continue;
        If BaseSegIdx=0 Then Begin
         If RecType=$C3 Then Begin
          If GroupPos+3<GroupLimit Then Inc(GroupPos,4)
              Else Continue;
         End Else Begin
          If GroupPos+1<GroupLimit Then Inc(GroupPos,2)
              Else Continue;
         End;
        End Else Begin
         LSymSeg:=BaseSegIdx;
         LSymBaseOfs:=0;
        End;
       End;

       If GroupPos>=GroupLimit Then Continue;
       ParsedNameLen:=Buffer[GroupPos];
       Inc(GroupPos);
       If ParsedNameLen>64 Then ParsedNameLen:=64;
       If GroupPos+ParsedNameLen>GroupLimit Then ParsedNameLen:=GroupLimit-GroupPos;

       ParsedName:='';
       For k:=1 to ParsedNameLen do Begin
        ParsedName:=ParsedName+Chr(Buffer[GroupPos]);
        Inc(GroupPos);
       End;

       If (LSymSeg=0)And(ParsedName<>'') Then
        FindSymbolByName(ParsedName,LSymSeg,LSymBaseOfs);

       IterLen:=0;
       If (ComdatFlags And $02)<>0 Then Begin
        If RecType=$C3 Then Begin
         TmpPos:=GroupPos;
         ParseOK:=True;
         While TmpPos<GroupLimit do Begin
          BlockLen:=0;
          If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,True,BlockLen) Then Begin
           ParseOK:=False;
           Break;
          End;
          If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
               Else Inc(IterLen,BlockLen);
         End;
         If Not(ParseOK And (TmpPos=GroupLimit)) Then Begin
          IterLen:=0;
          TmpPos:=GroupPos;
          While TmpPos<GroupLimit do Begin
           BlockLen:=0;
           If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,False,BlockLen) Then Break;
           If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
            Else Inc(IterLen,BlockLen);
          End;
         End;
        End Else Begin
         TmpPos:=GroupPos;
         While TmpPos<GroupLimit do Begin
          BlockLen:=0;
          If Not SkipIterBlockEx(Buffer,TmpPos,GroupLimit,False,BlockLen) Then Break;
          If IterLen>High(LongInt)-BlockLen Then IterLen:=High(LongInt)
               Else Inc(IterLen,BlockLen);
         End;
        End;
       End Else Begin
        IterLen:=GroupLimit-GroupPos;
       End;

       If (LSymSeg>0)And(LSymSeg<=SegmentCount) Then Begin
        SegPtr:=GetSegmentPtr(LSymSeg);
        If SegPtr<>Nil Then Begin
         EndPos:=LSymBaseOfs+ComdatEnumOfs+IterLen;
         If (ComdatEnumOfs<0)Or(EndPos<0)Or(EndPos>$FFFF) Then EndPos:=$FFFF;
         If EndPos>SegPtr^.Size Then SegPtr^.Size:=EndPos;
         LastDataSeg:=LSymSeg;
         PubOfs:=LSymBaseOfs+ComdatEnumOfs;
         If PubOfs<0 Then LastDataOfs:=0
         Else If PubOfs>$FFFF Then LastDataOfs:=$FFFF
         Else LastDataOfs:=PubOfs;
         HasDataContext:=True;
        End;
       End;
      End;
      $C8, $C9:Begin
       { NBKPAT / NBKPAT32 : backpatch nomme (COMDAT/public) }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       If GroupPos>=GroupLimit Then Continue;
       BakLocType:=Buffer[GroupPos] And $7F;
       Inc(GroupPos);

       If GroupPos>=GroupLimit Then Continue;
       ParsedNameLen:=Buffer[GroupPos];
       Inc(GroupPos);
       If ParsedNameLen>64 Then ParsedNameLen:=64;
       If GroupPos+ParsedNameLen>GroupLimit Then ParsedNameLen:=GroupLimit-GroupPos;

       ParsedName:='';
       For k:=1 to ParsedNameLen do Begin
        ParsedName:=ParsedName+Chr(Buffer[GroupPos]);
        Inc(GroupPos);
       End;

       LSymSeg:=0;
       LSymBaseOfs:=0;
       If Not FindSymbolByName(ParsedName,LSymSeg,LSymBaseOfs) Then Continue;

       While GroupPos<GroupLimit do Begin
        If RecType=$C9 Then Begin
         If GroupPos+7>=GroupLimit Then Break;
         BakPatchOfs:=LongInt(Buffer[GroupPos])
                   + LongInt(Buffer[GroupPos+1]) * 256
                   + LongInt(Buffer[GroupPos+2]) * 65536
                   + LongInt(Buffer[GroupPos+3]) * 16777216;
         BakPatchVal:=LongInt(Buffer[GroupPos+4])
                   + LongInt(Buffer[GroupPos+5]) * 256
                   + LongInt(Buffer[GroupPos+6]) * 65536
                   + LongInt(Buffer[GroupPos+7]) * 16777216;
         Inc(GroupPos,8);
        End Else Begin
         If GroupPos+3>=GroupLimit Then Break;
         BakPatchOfs:=Buffer[GroupPos]+LongInt(Buffer[GroupPos+1])*256;
         BakPatchVal:=Buffer[GroupPos+2]+LongInt(Buffer[GroupPos+3])*256;
         Inc(GroupPos,4);
        End;

        AddBackPatch(LSymSeg,BakLocType,LSymBaseOfs+BakPatchOfs,BakPatchVal,RecType=$C9);
       End;
      End;
      $C6, $C7:Begin
       { ALIAS / ALIAS32 : paires <alias><substitut> }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       While GroupPos<GroupLimit do Begin
        ParsedNameLen:=Buffer[GroupPos];
        Inc(GroupPos);
        If (ParsedNameLen=0)Or(GroupPos>GroupLimit) Then Break;
        If GroupPos+ParsedNameLen>GroupLimit Then Break;

        ParsedName:='';
        For k:=1 to ParsedNameLen do Begin
         ParsedName:=ParsedName+Chr(Buffer[GroupPos]);
         Inc(GroupPos);
        End;

        If GroupPos>=GroupLimit Then Break;
        ParsedNameLen:=Buffer[GroupPos];
        Inc(GroupPos);
        If (ParsedNameLen=0)Or(GroupPos>GroupLimit) Then Break;
        If GroupPos+ParsedNameLen>GroupLimit Then Break;

        ParsedClass:='';
        For k:=1 to ParsedNameLen do Begin
         ParsedClass:=ParsedClass+Chr(Buffer[GroupPos]);
         Inc(GroupPos);
        End;

        If (ParsedName<>'')And(ParsedClass<>'') Then AddAlias(ParsedName,ParsedClass);
       End;
      End;
      $CE:Begin
       { VENDEXT : extension OMF specifique vendeur (TIS 1.1) }
       { Format: VendorNumber(2 octets) + Extension Bytes (opaques) }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;
       If GroupPos+1>=GroupLimit Then Continue;

       { VendorNumber (little-endian), volontairement non exploite }
       BaseGroupIdx:=Buffer[GroupPos]+Word(Buffer[GroupPos+1])*256;
       Inc(GroupPos,2);

       { Le reste du record est opaque et ignore pour compatibilite }
      End;
      $CF:Begin
       { CFh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D0:Begin
       { D0h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D1:Begin
       { D1h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D2:Begin
       { D2h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D3:Begin
       { D3h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D4:Begin
       { D4h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D5:Begin
       { D5h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D6:Begin
       { D6h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D7:Begin
       { D7h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D8:Begin
       { D8h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $D9:Begin
       { D9h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DA:Begin
       { DAh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DB:Begin
       { DBh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DC:Begin
       { DCh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DD:Begin
       { DDh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DE:Begin
       { DEh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $DF:Begin
       { DFh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E0:Begin
       { E0h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E1:Begin
       { E1h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E2:Begin
       { E2h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E3:Begin
       { E3h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E4:Begin
       { E4h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E5:Begin
       { E5h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E6:Begin
       { E6h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E7:Begin
       { E7h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E8:Begin
       { E8h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $E9:Begin
       { E9h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $EA:Begin
       { EAh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $EB:Begin
       { EBh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $EC:Begin
       { ECh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $ED:Begin
       { EDh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $EE:Begin
       { EEh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $EF:Begin
       { EFh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F0:Begin
       { F0h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F1:Begin
       { F1h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F2:Begin
       { F2h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F3:Begin
       { F3h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F4:Begin
       { F4h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F5:Begin
       { F5h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F6:Begin
       { F6h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F7:Begin
       { F7h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F8:Begin
       { F8h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $F9:Begin
       { F9h : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FA:Begin
       { FAh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FB:Begin
       { FBh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FC:Begin
       { FCh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FD:Begin
       { FDh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FE:Begin
       { FEh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
      $FF:Begin
       { FFh : extension/reserve OMF (format non standardise) }
       { Strategie prudente : charge utile opaque, ignoree en compatibilite }
       GroupPos:=0;
       GroupLimit:=RecLen-1; { sans checksum }
       If GroupLimit<=0 Then Continue;

       { Eventuel sous-type octet en tete (si present), non exploite }
       If GroupPos<GroupLimit Then Begin
        BakLocType:=Buffer[GroupPos];
        Inc(GroupPos);
       End;

       { Le reste est considere opaque }
      End;
        $A8..$AF, $B1, $B9..$BF, $C0, $C1:Begin
       { Codes OMF etendus/reserves non pris en charge : ignorer }
      End;
  End;
 End;
 Close(ObjFile);
  { Applique les ALIAS tardifs aux symboles externes deja collectes }
 SymItem:=SymbolHead;
 While SymItem<>Nil do Begin
  If SymItem^.Value.IsExternal Then
   SymItem^.Value.Name:=Copy(ResolveAliasName(SymItem^.Value.Name),1,32);
  SymItem:=SymItem^.Next;
 End;
  { Adresse relative de chaque segment dans l'image li�e }
 For i:=1 to SegmentCount do Begin
  SegPtr:=GetSegmentPtr(i);
  If SegPtr=Nil Then Continue;
  If i=1 Then SegPtr^.Address:=0
   Else Begin
    PrevSegPtr:=GetSegmentPtr(i-1);
    If PrevSegPtr<>Nil Then SegPtr^.Address:=PrevSegPtr^.Address+PrevSegPtr^.Size
          Else SegPtr^.Address:=0;
   End;
 End;
 ReadObjFile:=True;
End;

Procedure GenerateExe(Const FileName:String);
Var
 i:Integer;
 CodeSize,HeaderBytes,DataStart:LongInt;
 Remaining,ChunkSize:Word;
 PatchPos:LongInt;
 OldByte,NewByte:Byte;
 OldWord,NewWord:Word;
 OldLong,NewLong,IncLong:LongInt;
 IncWord:Word;
 PatchItem:POffsetPatchItem;
 BackItem:PBackPatchItem;
 RelocItem:PRelocationItem;
 RecType:Byte;
 RecLen:Word;
 ObjBuf:TObjRecBuffer;
 SegIndex:Word;
 SegOffset:Word;
 DataLen:Word;
 IdxSize:Integer;
 WritePos:LongInt;
 EntryLinear:LongInt;
 GroupPos,GroupLimit:Integer;
 MaxWrite,Produced:LongInt;
 DataOfs32:LongInt;
 BlockLen:LongInt;
 ParseOK:Boolean;
 LidataUse32:Boolean;
 A1IsIter:Boolean;
 ComdatFlags:Byte;
 ComdatAttr:Byte;
 ComdatAllocType:Byte;
 ComdatTypeIdx:Word;
 ComdatBaseGroupIdx,ComdatBaseSegIdx:Word;
 ComdatEnumOfs:LongInt;
 ComdatTargetSeg:Word;
 ComdatBaseOfs:LongInt;
 ComdatName:String[64];
 ComdatNameLen:Byte;
 TmpPos:Integer;
 IterPos:Integer;
 SegPtr:PSegment;

 Function ReadOmfIndexObj(Var Pos:Integer; Limit:Integer; Var Idx:Word):Boolean;
 Var b:Byte;
 Begin
  ReadOmfIndexObj:=False;
  If Pos>=Limit Then Exit;
  b:=ObjBuf[Pos];
  Inc(Pos);
  If (b And $80)<>0 Then Begin
   If Pos>=Limit Then Exit;
   Idx:=((Word(b And $7F) Shl 8) Or ObjBuf[Pos]);
   Inc(Pos);
  End Else Idx:=b;
  ReadOmfIndexObj:=True;
 End;

 Function FindSymbolByNameObj(Const Nm:String; Var SegIdx:Word; Var OfsVal:LongInt):Boolean;
 Var
  symItem:PSymbolItem;
  lookupName:String[64];
 Begin
  FindSymbolByNameObj:=False;
  SegIdx:=0;
  OfsVal:=0;
  lookupName:=ResolveAliasName(Nm);
  symItem:=SymbolHead;
  While symItem<>Nil do Begin
  If (Not symItem^.Value.IsExternal)
    And((symItem^.Value.Name=Nm)Or(symItem^.Value.Name=lookupName)) Then Begin
    SegIdx:=symItem^.Value.Segment;
    OfsVal:=symItem^.Value.Offset;
    FindSymbolByNameObj:=True;
    Exit;
   End;
   symItem:=symItem^.Next;
  End;
 End;

Begin
  { Initialise l'ent�te EXE }
 FillChar(ExeHeader, SizeOf(ExeHeader), 0);
 With ExeHeader do Begin
  Signature:=$5A4D;  { 'MZ' }
  MinAlloc:=0;
  MaxAlloc:=$FFFF;
  InitSS:=0;
  InitSP:=StackSize;
  InitCS:=0;
  InitIP:=0;
  RelocOffset:=SizeOf(TExeHeader);
 End;

 { Point d'entree issu de MODEND/MODEND32, si disponible }
 If HasEntryPoint And (EntrySegIndex>0)And(EntrySegIndex<=SegmentCount) Then Begin
  SegPtr:=GetSegmentPtr(EntrySegIndex);
  If SegPtr<>Nil Then Begin
   EntryLinear:=SegPtr^.Address+EntryOffset;
   If EntryLinear<0 Then EntryLinear:=0;
   If EntryLinear>(LongInt($FFFF)*16+15) Then EntryLinear:=LongInt($FFFF)*16+15;
   ExeHeader.InitCS:=EntryLinear Div 16;
   ExeHeader.InitIP:=EntryLinear Mod 16;
  End;
 End;

  { Calcul du taille du code }
 CodeSize:=0;
 For i:=1 to SegmentCount do Begin
  SegPtr:=GetSegmentPtr(i);
  If SegPtr<>Nil Then Inc(CodeSize,SegPtr^.Size);
 End;
 ExeHeader.RelocCount:=RelocationCount;

 HeaderBytes:=SizeOf(TExeHeader)+LongInt(RelocationCount)*4;
 ExeHeader.HeaderSize:=(HeaderBytes+15) div 16;   { en paragraphes }
 If ExeHeader.HeaderSize<2 Then ExeHeader.HeaderSize:=2;
 DataStart:=LongInt(ExeHeader.HeaderSize)*16;
 ExeHeader.LastPageBytes:=(DataStart+CodeSize) mod 512;
 ExeHeader.PageCount:=(DataStart+CodeSize+511) div 512;

  { Ecrit un fichier EXE }
 Assign(ExeFile,FileName);
 Rewrite(ExeFile,1);
 BlockWrite(ExeFile,ExeHeader,SizeOf(ExeHeader));

  { �crire la relocations }
 RelocItem:=RelocationHead;
 While RelocItem<>Nil do Begin
  BlockWrite(ExeFile,RelocItem^.Value,4);
  RelocItem:=RelocItem^.Next;
 End;

    { Remplit le padding d'ent�te jusqu'� DataStart }
   FillChar(Buffer,SizeOf(Buffer),0);
   While FilePos(ExeFile)<DataStart do Begin
    ChunkSize:=SizeOf(Buffer);
    If FilePos(ExeFile)+ChunkSize>DataStart Then ChunkSize:=DataStart-FilePos(ExeFile);
    BlockWrite(ExeFile,Buffer,ChunkSize);
   End;

    { R�serve les segments de code (z�ro) }
 For i:=1 to SegmentCount do Begin
   SegPtr:=GetSegmentPtr(i);
   If SegPtr=Nil Then Continue;
   Remaining:=SegPtr^.Size;
    While Remaining>0 do Begin
     If Remaining>SizeOf(Buffer) Then ChunkSize:=SizeOf(Buffer)
                               Else ChunkSize:=Remaining;
     BlockWrite(ExeFile,Buffer,ChunkSize);
     Dec(Remaining,ChunkSize);
    End;
 End;

    { Copie les octets r�els depuis LEDATA du fichier OBJ }
   Assign(ObjFile,ObjFileName);
   Reset(ObjFile,1);
   While Not Eof(ObjFile) do Begin
    BlockRead(ObjFile,RecType,1);
    If Eof(ObjFile) Then Break;
      If RecType<$80 Then RecType:=RecType Or $80;
    BlockRead(ObjFile,RecLen,2);
    If RecLen>SizeOf(ObjBuf) Then Begin
     WriteLn('Erreur : RecLen sup�rieur � la taille du tampon LEDATA');
     Close(ObjFile);
     Close(ExeFile);
     Exit;
    End;
    BlockRead(ObjFile,ObjBuf,RecLen);
    If (RecType=$A0)Or(RecType=$84) Then Begin
     If RecLen<5 Then Continue;
     IdxSize:=1;
     SegIndex:=ObjBuf[0];
     If (SegIndex And $80)<>0 Then Begin
      If RecLen<6 Then Continue;
      SegIndex:=((SegIndex And $7F) Shl 8) Or ObjBuf[1];
      IdxSize:=2;
     End;
     Move(ObjBuf[IdxSize],SegOffset,2);
     DataLen:=RecLen-IdxSize-2-1; { -index -offset -checksum }
     If (DataLen>0)And(SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
      SegPtr:=GetSegmentPtr(SegIndex);
      If SegPtr<>Nil Then Begin
       WritePos:=DataStart+SegPtr^.Address+SegOffset;
       Seek(ExeFile,WritePos);
       BlockWrite(ExeFile,ObjBuf[IdxSize+2],DataLen);
      End;
     End;
    End Else If RecType=$86 Then Begin
     GroupPos:=0;
     GroupLimit:=RecLen-1; { sans checksum }
     If GroupLimit<=0 Then Continue;

     SegIndex:=ObjBuf[GroupPos];
     Inc(GroupPos);
     If (SegIndex And $80)<>0 Then Begin
      If GroupPos>=GroupLimit Then Continue;
      SegIndex:=((SegIndex And $7F) Shl 8) Or ObjBuf[GroupPos];
      Inc(GroupPos);
     End;

     If GroupPos+1>=GroupLimit Then Continue;
     SegOffset:=ObjBuf[GroupPos]+Word(ObjBuf[GroupPos+1])*256;
     Inc(GroupPos,2);

     If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
      SegPtr:=GetSegmentPtr(SegIndex);
      If SegPtr<>Nil Then Begin
       WritePos:=DataStart+SegPtr^.Address+SegOffset;
       MaxWrite:=LongInt(SegPtr^.Size)-LongInt(SegOffset);
       If MaxWrite<0 Then MaxWrite:=0;
       Produced:=0;
       IterPos:=GroupPos;
       While IterPos<GroupLimit do
        If Not EmitIterBlock16(ExeFile,ObjBuf,IterPos,GroupLimit,WritePos,Produced,MaxWrite) Then Break;
      End;
     End;
        End Else If RecType=$A1 Then Begin
         GroupPos:=0;
         GroupLimit:=RecLen-1; { sans checksum }
         If GroupLimit<=0 Then Continue;

         SegIndex:=ObjBuf[GroupPos];
         Inc(GroupPos);
         If (SegIndex And $80)<>0 Then Begin
          If GroupPos>=GroupLimit Then Continue;
          SegIndex:=((SegIndex And $7F) Shl 8) Or ObjBuf[GroupPos];
          Inc(GroupPos);
         End;

         If GroupPos+3>=GroupLimit Then Continue;
         DataOfs32:=LongInt(ObjBuf[GroupPos])
           + LongInt(ObjBuf[GroupPos+1]) * 256
           + LongInt(ObjBuf[GroupPos+2]) * 65536
           + LongInt(ObjBuf[GroupPos+3]) * 16777216;
         Inc(GroupPos,4);

         If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
          SegPtr:=GetSegmentPtr(SegIndex);
          If (SegPtr<>Nil)And(DataOfs32>=0) Then Begin
           WritePos:=DataStart+SegPtr^.Address+DataOfs32;
           MaxWrite:=LongInt(SegPtr^.Size)-DataOfs32;
           If MaxWrite<0 Then MaxWrite:=0;

           A1IsIter:=False;
           LidataUse32:=True;
           TmpPos:=GroupPos;
           ParseOK:=True;
           While TmpPos<GroupLimit do
      If Not SkipIterBlockEx(ObjBuf,TmpPos,GroupLimit,True,BlockLen) Then Begin
       ParseOK:=False;
       Break;
      End;

           If ParseOK And (TmpPos=GroupLimit) Then Begin
      A1IsIter:=True;
      LidataUse32:=True;
           End Else Begin
      TmpPos:=GroupPos;
      ParseOK:=True;
      While TmpPos<GroupLimit do
       If Not SkipIterBlockEx(ObjBuf,TmpPos,GroupLimit,False,BlockLen) Then Begin
        ParseOK:=False;
        Break;
       End;
      If ParseOK And (TmpPos=GroupLimit) Then Begin
       A1IsIter:=True;
       LidataUse32:=False;
      End;
           End;

           If A1IsIter Then Begin
      Produced:=0;
      IterPos:=GroupPos;
      While IterPos<GroupLimit do
       If Not EmitIterBlockEx(ExeFile,ObjBuf,IterPos,GroupLimit,WritePos,Produced,MaxWrite,LidataUse32) Then Break;
           End Else Begin
      If GroupPos<GroupLimit Then DataLen:=GroupLimit-GroupPos
               Else DataLen:=0;
      If MaxWrite<=0 Then DataLen:=0
      Else If LongInt(DataLen)>MaxWrite Then DataLen:=MaxWrite;
      If DataLen>0 Then Begin
       Seek(ExeFile,WritePos);
       BlockWrite(ExeFile,ObjBuf[GroupPos],DataLen);
      End;
           End;
          End;
         End;
        End Else If (RecType=$A2)Or(RecType=$A3) Then Begin
     GroupPos:=0;
     GroupLimit:=RecLen-1; { sans checksum }
     If GroupLimit<=0 Then Continue;

     SegIndex:=ObjBuf[GroupPos];
     Inc(GroupPos);
     If (SegIndex And $80)<>0 Then Begin
      If GroupPos>=GroupLimit Then Continue;
      SegIndex:=((SegIndex And $7F) Shl 8) Or ObjBuf[GroupPos];
      Inc(GroupPos);
     End;

     If RecType=$A3 Then Begin
      If GroupPos+3>=GroupLimit Then Continue;
      DataOfs32:=LongInt(ObjBuf[GroupPos])
              + LongInt(ObjBuf[GroupPos+1]) * 256
              + LongInt(ObjBuf[GroupPos+2]) * 65536
              + LongInt(ObjBuf[GroupPos+3]) * 16777216;
      Inc(GroupPos,4);
     End Else Begin
      If GroupPos+1>=GroupLimit Then Continue;
      DataOfs32:=ObjBuf[GroupPos]+LongInt(ObjBuf[GroupPos+1])*256;
      Inc(GroupPos,2);
     End;

     If (SegIndex>0)And(SegIndex<=SegmentCount) Then Begin
      SegPtr:=GetSegmentPtr(SegIndex);
      If (SegPtr<>Nil)And(DataOfs32>=0) Then Begin
       WritePos:=DataStart+SegPtr^.Address+DataOfs32;
       MaxWrite:=LongInt(SegPtr^.Size)-DataOfs32;
       If MaxWrite<0 Then MaxWrite:=0;

       LidataUse32:=(RecType=$A3);
       If LidataUse32 Then Begin
        TmpPos:=GroupPos;
        ParseOK:=True;
        While TmpPos<GroupLimit do
         If Not SkipIterBlockEx(ObjBuf,TmpPos,GroupLimit,True,BlockLen) Then Begin
          ParseOK:=False;
          Break;
         End;
        If Not ParseOK Then LidataUse32:=False;
       End;

       Produced:=0;
       IterPos:=GroupPos;
       While IterPos<GroupLimit do
        If Not EmitIterBlockEx(ExeFile,ObjBuf,IterPos,GroupLimit,WritePos,Produced,MaxWrite,LidataUse32) Then Break;
      End;
     End;
    End Else If (RecType=$C2)Or(RecType=$C3) Then Begin
     GroupPos:=0;
     GroupLimit:=RecLen-1; { sans checksum }
     If GroupLimit<=0 Then Continue;
     If GroupPos+2>=GroupLimit Then Continue;

     ComdatFlags:=ObjBuf[GroupPos];
     Inc(GroupPos);
     ComdatAttr:=ObjBuf[GroupPos];
     Inc(GroupPos);
     ComdatAllocType:=ComdatAttr And $0F;

     Inc(GroupPos); { Align }
     If GroupPos>GroupLimit Then Continue;

     If RecType=$C3 Then Begin
      If GroupPos+3>=GroupLimit Then Continue;
      ComdatEnumOfs:=LongInt(ObjBuf[GroupPos])
               + LongInt(ObjBuf[GroupPos+1]) * 256
               + LongInt(ObjBuf[GroupPos+2]) * 65536
               + LongInt(ObjBuf[GroupPos+3]) * 16777216;
      Inc(GroupPos,4);
     End Else Begin
      If GroupPos+1>=GroupLimit Then Continue;
      ComdatEnumOfs:=ObjBuf[GroupPos]+LongInt(ObjBuf[GroupPos+1])*256;
      Inc(GroupPos,2);
     End;

     If Not ReadOmfIndexObj(GroupPos,GroupLimit,ComdatTypeIdx) Then Continue;

     ComdatTargetSeg:=0;
     ComdatBaseOfs:=0;
     If ComdatAllocType=0 Then Begin
      If Not ReadOmfIndexObj(GroupPos,GroupLimit,ComdatBaseGroupIdx) Then Continue;
      If Not ReadOmfIndexObj(GroupPos,GroupLimit,ComdatBaseSegIdx) Then Continue;
      If ComdatBaseSegIdx=0 Then Begin
       If RecType=$C3 Then Begin
        If GroupPos+3<GroupLimit Then Inc(GroupPos,4)
                            Else Continue;
       End Else Begin
        If GroupPos+1<GroupLimit Then Inc(GroupPos,2)
                            Else Continue;
       End;
      End Else Begin
       ComdatTargetSeg:=ComdatBaseSegIdx;
       ComdatBaseOfs:=0;
      End;
     End;

     If GroupPos>=GroupLimit Then Continue;
     ComdatNameLen:=ObjBuf[GroupPos];
     Inc(GroupPos);
     If ComdatNameLen>64 Then ComdatNameLen:=64;
     If GroupPos+ComdatNameLen>GroupLimit Then ComdatNameLen:=GroupLimit-GroupPos;

     ComdatName:='';
     For i:=1 to ComdatNameLen do Begin
      ComdatName:=ComdatName+Chr(ObjBuf[GroupPos]);
      Inc(GroupPos);
     End;

     If (ComdatTargetSeg=0)And(ComdatName<>'') Then
      FindSymbolByNameObj(ComdatName,ComdatTargetSeg,ComdatBaseOfs);

     DataOfs32:=ComdatBaseOfs+ComdatEnumOfs;
     If (ComdatTargetSeg>0)And(ComdatTargetSeg<=SegmentCount)And(DataOfs32>=0) Then Begin
      SegPtr:=GetSegmentPtr(ComdatTargetSeg);
      If SegPtr<>Nil Then Begin
       WritePos:=DataStart+SegPtr^.Address+DataOfs32;
       MaxWrite:=LongInt(SegPtr^.Size)-DataOfs32;
       If MaxWrite<0 Then MaxWrite:=0;

       If (ComdatFlags And $02)<>0 Then Begin
        LidataUse32:=(RecType=$C3);
        If LidataUse32 Then Begin
         TmpPos:=GroupPos;
         ParseOK:=True;
         While TmpPos<GroupLimit do
          If Not SkipIterBlockEx(ObjBuf,TmpPos,GroupLimit,True,BlockLen) Then Begin
           ParseOK:=False;
           Break;
          End;
         If Not ParseOK Then LidataUse32:=False;
        End;

        Produced:=0;
        IterPos:=GroupPos;
        While IterPos<GroupLimit do
         If Not EmitIterBlockEx(ExeFile,ObjBuf,IterPos,GroupLimit,WritePos,Produced,MaxWrite,LidataUse32) Then Break;
       End Else Begin
        If GroupPos<GroupLimit Then DataLen:=GroupLimit-GroupPos
                             Else DataLen:=0;
        If MaxWrite<=0 Then DataLen:=0
        Else If LongInt(DataLen)>MaxWrite Then DataLen:=MaxWrite;
        If DataLen>0 Then Begin
         Seek(ExeFile,WritePos);
         BlockWrite(ExeFile,ObjBuf[GroupPos],DataLen);
        End;
       End;
      End;
     End;
    End;
   End;

      { Applique les enregistrements BAKPAT/BAKPAT32 }
    BackItem:=BackPatchHead;
    While BackItem<>Nil do Begin
     If (BackItem^.SegIndex>0)And(BackItem^.SegIndex<=SegmentCount) Then Begin
      SegPtr:=GetSegmentPtr(BackItem^.SegIndex);
      If (SegPtr<>Nil)And(BackItem^.PatchOffset>=0) Then Begin
       PatchPos:=DataStart+SegPtr^.Address+BackItem^.PatchOffset;

       Case BackItem^.LocType of
        0:Begin { BYTE }
         If (PatchPos>=0)And(PatchPos<FileSize(ExeFile)) Then Begin
          Seek(ExeFile,PatchPos);
          BlockRead(ExeFile,OldByte,1);
          NewByte:=Byte((LongInt(OldByte)+(BackItem^.PatchValue And $FF)) And $FF);
          Seek(ExeFile,PatchPos);
          BlockWrite(ExeFile,NewByte,1);
         End;
        End;
        1:Begin { WORD }
         If (PatchPos>=0)And(PatchPos+1<FileSize(ExeFile)) Then Begin
          Seek(ExeFile,PatchPos);
          BlockRead(ExeFile,OldWord,2);
          IncWord:=BackItem^.PatchValue And $FFFF;
          NewWord:=OldWord+IncWord;
          Seek(ExeFile,PatchPos);
          BlockWrite(ExeFile,NewWord,2);
         End;
        End;
        2,9:Begin { DWORD }
         If (PatchPos>=0)And(PatchPos+3<FileSize(ExeFile)) Then Begin
          Seek(ExeFile,PatchPos);
          BlockRead(ExeFile,OldLong,4);
          IncLong:=BackItem^.PatchValue;
          NewLong:=OldLong+IncLong;
          Seek(ExeFile,PatchPos);
          BlockWrite(ExeFile,NewLong,4);
         End;
        End;
       End;
      End;
     End;
     BackItem:=BackItem^.Next;
    End;

    { Applique les corrections OFFSET segment-relatives }
  PatchItem:=OffsetPatchHead;
  While PatchItem<>Nil do Begin
   PatchPos:=DataStart+PatchItem^.Pos;
    If (PatchPos>=0)And(PatchPos+1<FileSize(ExeFile)) Then Begin
     Seek(ExeFile,PatchPos);
     BlockRead(ExeFile,OldWord,2);
    NewWord:=OldWord+PatchItem^.Delta;
     Seek(ExeFile,PatchPos);
     BlockWrite(ExeFile,NewWord,2);
    End;
   PatchItem:=PatchItem^.Next;
   End;

   Close(ObjFile);
 Close(ExeFile);
End;

Function ChangeFileExt(Const FileName:String;Const NewExt:String):String;
Var
 i:Integer;
 BaseName:String;
Begin
 BaseName:=FileName;
 i:=Length(BaseName);
 While(i>0)and(BaseName[i]<>'.')and(BaseName[i]<>'\')and(BaseName[i]<>':')do Dec(i);
 If(i>0)and(BaseName[i]='.')Then BaseName:=Copy(BaseName, 1, i-1);
 ChangeFileExt:=BaseName+NewExt;
End;

Function StrToInt(Const S:String):Integer;
Var
 i:Integer;
 Negative:Boolean;
 Value:Integer;
Begin
 Value:=0;
 i:=1;
 Negative:=False;
  { Saute les espaces blancs }
 While(i<=Length(S))and(S[i] = ' ')do Inc(i);
  { V�rifie pour les signes }
 If(i<=Length(S))Then Begin
  If S[i]='-'Then Begin
   Negative:=True;
   Inc(i);
  End
  Else If S[i]='+'Then Inc(i);
 End;

  { Convertie en chiffres }
 While(i<=Length(S))and(S[i]>='0')and(S[i]<='9')do Begin
  Value:=Value*10+(Ord(S[i])-Ord('0'));
  Inc(i);
 End;
 If(Negative)Then StrToInt:=-Value
             Else StrToInt:=Value;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('LINK : Cette commande permet de lancer le fabricant de liaison.');
  WriteLn;
  WriteLn('Syntaxe : LINK objfile[+objfile...][,[exefile][,[mapfile][,[libraries]]]] [options]');
  WriteLn;
  WriteLn('  /CP:n    - Fixe le maximum de paragraphes');
  WriteLn('  /STACK:n - Fixe la taille de la pile');
  WriteLn('  /MAP     - G�n�rer un fichier de cartographie (MAP)');
  Halt;
 End;
  { Initialise }
   InitMainLists;
   InitOffsetPatchList;
 StackSize:=2048;  { Taille de la pile par d�faut }
  { Analyse de la ligne de commande }
 ObjFileName:=ParamStr(1);
 If ParamCount>1 Then ExeFileName:=ParamStr(2)
                 Else ExeFileName:=ChangeFileExt(ObjFileName, '.EXE');
  { Traitements des options de la ligne de commande }
 For i:=1 to ParamCount do Begin
  Param:=ParamStr(i);
  If(Length(Param)>1)and(Param[1]='/')Then Begin
   Case UpCase(Param[2]) of
    'S':If Copy(Param,1,7)='/STACK:'Then StackSize:=StrToInt(Copy(Param,8,255));
   End;
  End;
 End;
  { Processus de liaison }
 If ReadObjFile(ObjFileName)Then Begin
  GenerateExe(ExeFileName);
  WriteLn('Liaison compl�t�');
 End
  Else
 WriteLn('Erreur de lecture de fichier objet');
   FreeOffsetPatchList;
   FreeMainLists;
END.
