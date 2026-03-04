{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program LINK;

{$A-}

Uses DOS;

Const
 MAX_SEGMENTS=128;
 MAX_SYMBOLS=1024;
 MAX_RELOCATIONS=2048;

Type
 TExeHeader=Record
  Signature:Word;          { 'MZ' }
  LastPageBytes:Word;
  PageCount:Word;
  RelocCount:Word;
  HeaderSize:Word;
  MinAlloc:Word;
  MaxAlloc:Word;
  InitSS:Word;
  InitSP:Word;
  Checksum:Word;
  InitIP:Word;
  InitCS:Word;
  RelocOffset:Word;
  OverlayNumber:Word;
 End;

 TSegment=Record
  Name:String[16];
  Address:LongInt;
  Size:Word;
  Class:String[8];
 End;

 TSymbol=Record
  Name:String[32];
  Segment:Word;
  Offset:Word;
  IsExternal:Boolean;
 End;

 TRelocation=Record
  Segment:Word;
  Offset:Word;
  Target:Word;
 End;

Var
 ObjFile,ExeFile,MapFile:File;
 ExeHeader:TExeHeader;
 Segments:Array[1..MAX_SEGMENTS] of TSegment;
 Symbols:Array[1..MAX_SYMBOLS] of TSymbol;
 Relocations:Array[1..MAX_RELOCATIONS] of TRelocation;
 SegmentCount,SymbolCount,RelocationCount:Integer;
 StackSize:Word;
 ObjFileName,ExeFileName,MapFileName:String;  { Ajout des variables }
 i:Integer;
 Param:string;
 Buffer:Array[0..1023] of Byte;  { Ajout du tampon manquant }

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
Begin
 ReadObjFile:=False;
 {$I-}Assign(ObjFile,FileName);
 Reset(ObjFile, 1);{$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(ObjFile) do Begin
  BlockRead(ObjFile,RecType,1);
  If Eof(ObjFile) Then Break;
  BlockRead(ObjFile,RecLen,2);
  If RecLen>SizeOf(Buffer)Then Begin
   WriteLn('Erreur : RecLen sup�rieur � la taille du tampon');
   Halt(10);
  End;
  BlockRead(ObjFile,Buffer,RecLen);
  Case RecType of
   $98:Begin { SEGDEF : D�finition de segment OMF }
    Inc(SegmentCount);
    If SegmentCount>MAX_SEGMENTS Then Begin
     WriteLn('Erreur : Trop de segments dans le fichier objet');
     Halt(11);
    End;
    With Segments[SegmentCount] do Begin
     Name:='';
     If RecLen>=4 Then Move(Buffer[1], Size, 2)
                 Else Size:=0;
     Address:=0;
     Class:='CODE';
    End;
   End;
   $90:Begin { D�finition publique }
    Inc(SymbolCount);
    If SymbolCount>MAX_SYMBOLS Then Begin
     WriteLn('Erreur : Trop de symboles publics');
     Halt(12);
    End;
    With Symbols[SymbolCount] do Begin
     Name:='';
     Segment:=0;
     Offset:=0;
     IsExternal:=False;
    End;
   End;
   $8C:Begin { EXTDEF : R�f�rence externe }
    Inc(SymbolCount);
    If SymbolCount>MAX_SYMBOLS Then Begin
     WriteLn('Erreur : Trop de symboles externes');
     Halt(13);
    End;
    With Symbols[SymbolCount] do Begin
     Name:='';
     Segment:=0;
     Offset := 0;
     IsExternal:=True;
    End;
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
      EndPos:=LongInt(SegOffset)+LongInt(DataLen);
      If EndPos>$FFFF Then EndPos:=$FFFF;
      If EndPos>Segments[SegIndex].Size Then Segments[SegIndex].Size:=EndPos;
     End;
    End;
   End;
  End;
 End;
 Close(ObjFile);
  { Adresse relative de chaque segment dans l'image li�e }
 For i:=1 to SegmentCount do Begin
  If i=1 Then Segments[i].Address:=0
         Else Segments[i].Address:=Segments[i-1].Address+Segments[i-1].Size;
 End;
 ReadObjFile:=True;
End;

Procedure GenerateExe(Const FileName:String);
Var
 i:Integer;
 CodeSize,HeaderBytes,DataStart:LongInt;
 Remaining,ChunkSize:Word;
 RecType:Byte;
 RecLen:Word;
 ObjBuf:Array[0..8191] of Byte;
 SegIndex:Word;
 SegOffset:Word;
 DataLen:Word;
 IdxSize:Integer;
 WritePos:LongInt;
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
 For i:=1 to SegmentCount do Inc(CodeSize,Segments[i].Size);
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
 For i:=1 to RelocationCount do BlockWrite(ExeFile,Relocations[i],4);

    { Remplit le padding d'ent�te jusqu'� DataStart }
   FillChar(Buffer,SizeOf(Buffer),0);
   While FilePos(ExeFile)<DataStart do Begin
    ChunkSize:=SizeOf(Buffer);
    If FilePos(ExeFile)+ChunkSize>DataStart Then ChunkSize:=DataStart-FilePos(ExeFile);
    BlockWrite(ExeFile,Buffer,ChunkSize);
   End;

    { R�serve les segments de code (z�ro) }
 For i:=1 to SegmentCount do Begin
    Remaining:=Segments[i].Size;
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
      WritePos:=DataStart+Segments[SegIndex].Address+SegOffset;
      Seek(ExeFile,WritePos);
      BlockWrite(ExeFile,ObjBuf[IdxSize+2],DataLen);
     End;
    End;
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
 SegmentCount:=0;
 SymbolCount:=0;
 RelocationCount:=0;
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
END.
