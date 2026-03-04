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

 { Liste chainee des corrections OFFSET }
 POffsetPatchItem=^TOffsetPatchItem;
 TOffsetPatchItem=Record
  Pos:LongInt;
  Delta:Integer;
  Next:POffsetPatchItem;
 End;

Var
 ObjFile,ExeFile,MapFile:File;
 ExeHeader:TExeHeader;
 SegmentHead,SegmentTail:PSegmentItem;
 SymbolHead,SymbolTail:PSymbolItem;
 RelocationHead,RelocationTail:PRelocationItem;
 OffsetPatchHead,OffsetPatchTail:POffsetPatchItem;
 SegmentCount,SymbolCount,RelocationCount:Integer;
 OffsetPatchCount:Integer;
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
 SegmentCount:=0;
 SymbolCount:=0;
 RelocationCount:=0;
End;

Procedure FreeMainLists;
Var
 segItem,nextSeg:PSegmentItem;
 symItem,nextSym:PSymbolItem;
 relItem,nextRel:PRelocationItem;
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

Function ReadObjFile(Const FileName:String):Boolean;
Var
 RecType:Byte;
 RecLen:Word;
 Buffer:Array[0..8191] of Byte;
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
 SymRec:TSymbol;
 SegRec:TSegment;
 SegPtr,PrevSegPtr:PSegment;
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
 {$I-}Assign(ObjFile,FileName);
 Reset(ObjFile, 1);{$I+}
 If IOResult<>0 Then Exit;
 While(Not Eof(ObjFile))and(Not ModuleEnded)do Begin
  BlockRead(ObjFile,RecType,1);
  If Eof(ObjFile) Then Break;
  BlockRead(ObjFile,RecLen,2);
  If RecLen>SizeOf(Buffer)Then Begin
   WriteLn('Erreur : RecLen sup�rieur � la taille du tampon');
   Halt(10);
  End;
  BlockRead(ObjFile,Buffer,RecLen);
  Case RecType of
    $00..$7F:Begin
     { Codes invalides/reserves dans OMF Intel 16-bit : ignorer proprement }
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
     { PEDATA/PIDATA (anciens) : non pris en charge, ignore }
    End;
    $88:Begin
     { COMENT : commentaires/directives du compilateur/assembleur }
    End;
    $8A, $8B:Begin
     { MODEND/MODEND32 : fin de module }
     ModuleEnded:=True;
    End;
    $8C, $8D:Begin { EXTDEF/LEXTDEF : reference externe }
      If SymbolCount>=MAX_SYMBOLS Then Begin
      WriteLn('Erreur : Trop de symboles externes');
      Halt(13);
     End;
      SymRec.Name:='';
      SymRec.Segment:=0;
      SymRec.Offset:=0;
      SymRec.IsExternal:=True;
      AddSymbol(SymRec);
    End;
    $8E, $8F:Begin
     { TYPDEF / PUBDEF 32-bit ancien format : non utilise ici }
    End;
    $90, $91:Begin { PUBDEF/PUBDEF32 : definition publique }
      If SymbolCount>=MAX_SYMBOLS Then Begin
      WriteLn('Erreur : Trop de symboles publics');
      Halt(12);
     End;
      SymRec.Name:='';
      SymRec.Segment:=0;
      SymRec.Offset:=0;
      SymRec.IsExternal:=False;
      AddSymbol(SymRec);
    End;
    $92, $93:Begin
     { LPUBDEF/LPUBDEF32 : def publique locale, ignore pour instant }
    End;
    $94, $95:Begin
     { LINNUM/LINNUM32 : info de debug lignes source }
    End;
    $96, $97:Begin
     { LNAMES/LLNAMES : index de noms (segments/classes), non exploite ici }
    End;
    $99:Begin
     { SEGDEF32 / variante etendue : non exploite par ce linker 16-bit }
    End;
    $9A, $9B:Begin
     { GRPDEF / GRPDEF32 : definition de groupes de segments, ignore }
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
   $98:Begin { SEGDEF : D�finition de segment OMF }
      SegRec.Name:='';
      If RecLen>=4 Then Move(Buffer[1], SegRec.Size, 2)
            Else SegRec.Size:=0;
      SegRec.Address:=0;
      SegRec.Class:='CODE';
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
       { LEDATA/LIDATA 32-bit : offset long, non supporte en sortie MZ 16-bit }
      End;
      $A2, $A3:Begin
       { COMDAT / COMDAT32 ou variantes : ignorer pour instant }
      End;
      $A4, $A5:Begin
       { BAKPAT / BAKPAT32 : backpatch, non implemente }
      End;
      $A6, $A7:Begin
       { LINSYM / LINSYM32 : infos symboles de debug }
      End;
      $A8..$FF:Begin
       { Codes OMF etendus/reserves/non documentes pour ce linker : ignorer }
      End;
  End;
 End;
 Close(ObjFile);
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
 OldWord,NewWord:Word;
 PatchItem:POffsetPatchItem;
 RelocItem:PRelocationItem;
 RecType:Byte;
 RecLen:Word;
 ObjBuf:Array[0..8191] of Byte;
 SegIndex:Word;
 SegOffset:Word;
 DataLen:Word;
 IdxSize:Integer;
 WritePos:LongInt;
 SegPtr:PSegment;
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
    BlockRead(ObjFile,RecLen,2);
    If RecLen>SizeOf(ObjBuf) Then Begin
     WriteLn('Erreur : RecLen sup�rieur � la taille du tampon LEDATA');
     Close(ObjFile);
     Close(ExeFile);
     Exit;
    End;
    BlockRead(ObjFile,ObjBuf,RecLen);
    If RecType=$A0 Then Begin
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
    End;
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
