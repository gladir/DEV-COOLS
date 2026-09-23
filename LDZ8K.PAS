{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Editeur de liens Z8000 x.out/UNIDOT compatible avec la chaine CP/M-8000.
 @license: MIT }

Program LDZ8K;

{$A-,B-,I-,R-,S-}
{$IFDEF FPC}
 {$H+}
{$ENDIF}

Uses Dos;

Const
 Version='1.0';
 OBOST=1;
 OBLST=2;
 OBSEC=3;
 OBGLO=4;
 OBLOC=5;
 OBTXT=6;
 OBBSZ=7;
 OBTRA=8;
 OBLIX=9;
 OBLND=10;
 OBOND=11;
 OBMOD=12;
 RAA16=$8000;
 RAA8=$4000;
 RAA32=$C000;
 RAA16M=$2000;
 RAA32M=$A000;
 RAZSS=$6000;
 RAZLS=$E000;
 RASEG=$1000;
 RAOFF=$9000;
 RAZOF=$3000;
 RAMSK=$F000;
 RBUND=255;
 RBEXT=256;
 RBMSK=$0FFF;
 X_SU_MAGIC=$EE00;X_SX_MAGIC=$EE01;X_NU_MAGIC=$EE02;X_NXN_MAGIC=$EE03;
 X_NUS_MAGIC=$EE06;X_NXS_MAGIC=$EE07;X_NUI_MAGIC=$EE0A;X_NXI_MAGIC=$EE0B;
 X_SG_BSS=1;X_SG_STK=2;X_SG_COD=3;X_SG_CON=4;X_SG_DAT=5;X_SG_MXU=6;X_SG_MXP=7;
 X_RL_OFF=1;X_RL_SSG=2;X_RL_LSG=3;X_RL_XOF=5;X_RL_XSSG=6;X_RL_XLSG=7;
 X_SY_LOC=1;X_SY_UNX=2;X_SY_GLB=3;X_SY_SEG=4;
 MaxErrors=100;

Type
 TBuffer=Array[0..254]of Byte;
 PInput=^TInput;
 TInput=Record Name:String;
 Next:PInput
End;
PImage=^TImage;
TImage=Record Index:LongInt;
Data:Array[0..4095]of Byte;
Next:PImage
End;
POutSection=^TOutSection;
TOutSection=Record
Number,Attributes,SegmentType,AssignedNumber:Byte;
Name:String;
Size,LoadBase:LongInt;
IsBss:Boolean;
FirstImage,LastImage:PImage;
Next:POutSection
End;
PObjSection=^TObjSection;
TObjSection=Record
Number,Attributes,SegmentType,AssignedNumber:Byte;
Name:String;
Size,OutputBase:LongInt;
IsBss,HasBytes:Boolean;
OutputSection:POutSection;
Next:PObjSection
End;
PGlobal=^TGlobal;
TGlobal=Record
Name:String;
Defined,Absolute:Boolean;
Section:POutSection;
Value:LongInt;
ObjectBase,SymbolIndex:Word;
Next:PGlobal
End;
PObjSymbol=^TObjSymbol;
TObjSymbol=Record
Name:String;
Defined,Global:Boolean;
Section:Byte;
Value:LongInt;
ExternalBase:Word;
Next:PObjSymbol
End;
PReloc=^TReloc;
TReloc=Record
Section:POutSection;
Offset:LongInt;
Action,Base:Word;
Width:Byte;
Next:PReloc
End;
PText=^TText;
TText=Record
Section:Byte;
Offset:LongInt;
Count:Byte;
Data:Array[0..248]of Byte;
Relocs:PReloc;
Next:PText
End;
TModule=Record
Name,FileName:String;
Sections:PObjSection;
Symbols:PObjSymbol;
Texts:PText;
HasTransfer,IsExecutable:Boolean;
TransferValue:LongInt;
TransferBase:Word
End;
PModuleNode=^TModuleNode;
TModuleNode=Record Item:TModule;
Next:PModuleNode
End;
TOptions=Record
OutputName:String;
Relocatable,Strip,SplitID,ReadOnly:Boolean;
StackSize:LongInt
End;

Var
 Opt:TOptions;
 Inputs,LastInput:PInput;
 OutSections,LastOutSection:POutSection;
 Globals:PGlobal;
 Relocations,LastRelocation:PReloc;
 ErrorCount:Integer;
 NextSectionNumber:Integer;
 OutputFile:File;
 OutputOpen:Boolean;
 TemporaryName:String;
 ForcedUndefined,LastForced:PInput;
 HasTransfer:Boolean;
 TransferValue:LongInt;
 TransferBase:Word;
 TargetKnown,TargetSegmented:Boolean;

Function UpperString(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do S[I]:=UpCase(S[I]);UpperString:=S
End;

Function TrimString(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 TrimString:=S
End;

Function Extension(S:String):String;
Var
 I:Integer;
Begin
 Extension:='';
 For I:=Length(S)downto 1 do if S[I]='.'Then Begin
  Extension:=UpperString(Copy(S,I,Length(S)));Exit
 End else if S[I]in['\','/',':']Then Exit
End;

Function BaseName(S:String):String;
Var
 I:Integer;
Begin
 For I:=Length(S)downto 1 do if S[I]='.'Then Begin
  Delete(S,I,Length(S));Break
 End
 else if S[I]in['\','/',':']Then Break;BaseName:=S
End;

Function FileExists(Const Name:String):Boolean;
Var
 F:File;
 Ok:Boolean;
Begin
 Assign(F,Name);Reset(F,1);Ok:=IOResult=0;if Ok Then Begin
  Close(F);if IOResult<>0 Then Begin
  End
 End;FileExists:=Ok
End;

Procedure DeleteQuiet(Const Name:String);
Var
 F:File;
Begin
 if Name=''Then Exit;Assign(F,Name);Erase(F);if IOResult<>0 Then Begin
 End
End;

Procedure Fatal(Const S:String);Begin
 if OutputOpen Then Begin
  Close(OutputFile);if IOResult<>0 Then Begin
  End;OutputOpen:=False
 End;
 DeleteQuiet(TemporaryName);WriteLn('LDZ8K: erreur fatale: ',S);Halt(1)
End;

Procedure Error(Const FileName,S:String);Begin
 Inc(ErrorCount);WriteLn('LDZ8K: ',FileName,': erreur: ',S);
 if ErrorCount>=MaxErrors Then Fatal('trop d''erreurs')
End;

Procedure Usage;Begin
 WriteLn('LDZ8K ',Version,' - Cette commande permet de lancer l''',#130,
 'diteur de liens Z8000 x.out pour CP/M-8000');
 WriteLn;
 WriteLn('Syntaxe : LDZ8K [options] fichier1 [fichier2 ...]');
 WriteLn;
 WriteLn('  -o fichier  nom du fichier produit (x.out par defaut)');
 WriteLn('  -r          conserve les references non resolues');
 WriteLn('  -s          supprime les symboles locaux et la table publique finale');
 WriteLn('  -u symbole  ajoute une reference externe forcee');
 WriteLn('  -i          espace instructions/donnees separe');
 WriteLn('  -n          texte partage, donnees alignees sur 8 Kio');
 WriteLn('  -t taille   taille de pile demandee');
 WriteLn('  Entrees x.out de XCON et objets UNIDOT acceptes; sortie x.out big-endian.');
 WriteLn('  Les fichiers sans extension recoivent .OBJ.')
End;

Procedure AddInput(Const Name:String;Var First,Last:PInput);
Var
 P:PInput;
Begin
 New(P);if P=Nil Then Fatal('memoire pleine');P^.Name:=Name;P^.Next:=Nil;
 if Last=Nil Then First:=P else Last^.Next:=P;Last:=P
End;

Procedure ParseCommandLine;
Var
 I,Code:Integer;
 S,U:String;
Begin
 FillChar(Opt,SizeOf(Opt),0);Opt.OutputName:='x.out';I:=1;
 While I<=ParamCount do Begin
  S:=ParamStr(I);U:=UpperString(S);
  if(U='/?')or(U='-?')or(U='--HELP')Then Begin
   Usage;Halt(0)
  End
  else if U='-O'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-o exige un fichier');Opt.OutputName:=ParamStr(I)
  End
  else if U='-R'Then Opt.Relocatable:=True
  else if U='-S'Then Opt.Strip:=True
  else if U='-I'Then Opt.SplitID:=True
  else if U='-N'Then Opt.ReadOnly:=True
  else if U='-T'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-t exige une taille');
   Val(ParamStr(I),Opt.StackSize,Code);if Code<>0 Then Fatal('taille de pile incorrecte')
  End
  else if U='-U'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-u exige un symbole');
   AddInput(ParamStr(I),ForcedUndefined,LastForced)
  End
  else if(S<>'')and(S[1]='-')Then Fatal('option inconnue: '+S)
  else
  Begin
   if Extension(S)=''Then S:=S+'.OBJ';AddInput(S,Inputs,LastInput)
  End;
  Inc(I)
 End;
 if Inputs=Nil Then Begin
  Usage;Halt(1)
 End
End;

Function ReadByte(Var F:File;Var Position:LongInt;Limit:LongInt;Var Ok:Boolean):Byte;
Var
 B:Byte;
 N:Word;
Begin
 if Position>=Limit Then Begin
  Ok:=False;ReadByte:=0;Exit
 End;
 BlockRead(F,B,1,N);if N<>1 Then Ok:=False else Inc(Position);ReadByte:=B
End;

Function LE16(Const B:TBuffer;P:Integer):Word;Begin
 LE16:=Word(B[P])or(Word(B[P+1])shl 8)
End;

Function LE32(Const B:TBuffer;P:Integer):LongInt;Begin
 LE32:=LongInt(B[P])or(LongInt(B[P+1])shl 8)or(LongInt(B[P+2])shl 16)or(LongInt(B[P+3])
 shl 24)
End;

Function GetName(Const B:TBuffer;Var P:Integer;Limit:Integer):String;
Var
 S:String;
Begin
 S:='';
 While(P<Limit)and(B[P]<>0)do Begin
  S:=S+Chr(B[P]);Inc(P)
 End;
 if P<Limit Then Inc(P);GetName:=S
End;

Function FindObjSection(Var M:TModule;Number:Byte):PObjSection;
Var
 P:PObjSection;
Begin
 P:=M.Sections;
 While(P<>Nil)and(P^.Number<>Number)do P:=P^.Next;FindObjSection:=P
End;

Function FindOutSection(Const Name:String;Attributes:Byte):POutSection;
Var
 P:POutSection;
 U:String;
Begin
 U:=UpperString(Name);P:=OutSections;
 While P<>Nil do Begin
  if UpperString(P^.Name)=U Then Begin
   FindOutSection:=P;Exit
  End;P:=P^.Next
 End;
 New(P);if P=Nil Then Fatal('memoire pleine');FillChar(P^,SizeOf(P^),0);
 if NextSectionNumber>=RBUND Then Fatal('trop de segments');P^.Number:=NextSectionNumber;
 Inc(NextSectionNumber);
 P^.Name:=Name;P^.Attributes:=Attributes;
 if LastOutSection=Nil Then OutSections:=P else LastOutSection^.Next:=P;LastOutSection:=P;
 FindOutSection:=P
End;

Function FindGlobal(Const Name:String):PGlobal;
Var
 P:PGlobal;
 U:String;
Begin
 U:=UpperString(Name);P:=Globals;
 While(P<>Nil)and(UpperString(P^.Name)<>U)do P:=P^.Next;FindGlobal:=P
End;

Function GetGlobal(Const Name:String):PGlobal;
Var
 P:PGlobal;
Begin
 P:=FindGlobal(Name);if P=Nil Then Begin
  New(P);if P=Nil Then Fatal('memoire pleine');
  FillChar(P^,SizeOf(P^),0);P^.Name:=Name;P^.Next:=Globals;Globals:=P
 End;GetGlobal:=P
End;

Procedure PutImageByte(S:POutSection;Offset:LongInt;Value:Byte);
Var
 P,N:PImage;
 Index:LongInt;
Begin
 Index:=Offset div 4096;P:=S^.FirstImage;
 While(P<>Nil)and(P^.Index<>Index)do P:=P^.Next;
 if P=Nil Then Begin
  New(N);if N=Nil Then Fatal('memoire pleine');FillChar(N^,SizeOf(N^),0);N^.Index:=Index;
  if S^.LastImage=Nil Then S^.FirstImage:=N else S^.LastImage^.Next:=N;S^.LastImage:=N;
  P:=N
 End;P^.Data[Offset mod 4096]:=Value;if Offset>=S^.Size Then S^.Size:=Offset+1
End;

Function GetImageByte(S:POutSection;Offset:LongInt):Byte;
Var
 P:PImage;
Begin
 P:=S^.FirstImage;
 While(P<>Nil)and(P^.Index<>Offset div 4096)do P:=P^.Next;
 if P=Nil Then GetImageByte:=0 else GetImageByte:=P^.Data[Offset mod 4096]
End;

Procedure AddOutputRelocation(S:POutSection;Offset:LongInt;Action,Base:Word;Width:Byte);
Var
 R:PReloc;
Begin
 New(R);if R=Nil Then Fatal('memoire pleine');R^.Section:=S;R^.Offset:=Offset;
 R^.Action:=Action;
 R^.Base:=Base;R^.Width:=Width;R^.Next:=Nil;
 if LastRelocation=Nil Then Relocations:=R else LastRelocation^.Next:=R;LastRelocation:=R
End;

Procedure ReadUnidot(Const FileName:String;Var M:TModule);
Var
 F:File;
 Total,Position:LongInt;
 Kind,Len:Byte;
 B:TBuffer;
 N:Word;
 P,I:Integer;
 Ok,SegmentedSeen:Boolean;
 S:PObjSection;
 Y:PObjSymbol;
 T:PText;
 LastS:PObjSection;
 LastY:PObjSymbol;
 LastT:PText;
 R,LastR:PReloc;
 ExternalNumber:Word;
Begin
 FillChar(M,SizeOf(M),0);M.FileName:=FileName;Assign(F,FileName);Reset(F,1);
 if IOResult<>0 Then Begin
  Error(FileName,'ouverture impossible');Exit
 End;
 Total:=FileSize(F);Position:=0;Ok:=True;LastS:=Nil;LastY:=Nil;LastT:=Nil;
 ExternalNumber:=RBEXT;SegmentedSeen:=False;
 While(Position<Total)and Ok do Begin
  Kind:=ReadByte(F,Position,Total,Ok);Len:=ReadByte(F,Position,Total,Ok);
  if not Ok or(Position+Len>Total)Then Begin
   Error(FileName,'bloc UNIDOT tronque');Break
  End;
  if Len<>0 Then Begin
   BlockRead(F,B,Len,N);if N<>Len Then Ok:=False;Inc(Position,Len)
  End;
  if not Ok Then Begin
   Error(FileName,'erreur de lecture');Break
  End;
  Case Kind of
  OBMOD:
  Begin
   P:=0;M.Name:=GetName(B,P,Len)
  End;
  OBSEC:
  Begin
   P:=0;
   While P<Len do Begin
    if P+3>Len Then Begin
     Error(FileName,'descripteur de segment tronque');Break
    End;
    New(S);if S=Nil Then Fatal('memoire pleine');FillChar(S^,SizeOf(S^),0);
    S^.Number:=B[P];S^.Attributes:=B[P+1];Inc(P,3);S^.Name:=GetName(B,P,Len);
    if S^.Name=''Then Begin
     Error(FileName,'nom de segment vide');Dispose(S);Break
    End;
    if LastS=Nil Then M.Sections:=S else LastS^.Next:=S;LastS:=S
   End
  End;
  OBGLO,OBLOC:
  Begin
   P:=0;
   While P<Len do Begin
    if P+6>Len Then Begin
     Error(FileName,'symbole tronque');Break
    End;
    New(Y);if Y=Nil Then Fatal('memoire pleine');FillChar(Y^,SizeOf(Y^),0);
    Y^.Value:=LE32(B,P);Y^.Section:=B[P+4];Inc(P,5);Y^.Name:=GetName(B,P,Len);
    Y^.Global:=Kind=OBGLO;
    Y^.Defined:=Y^.Section<>RBUND;if(not Y^.Defined)and(Kind=OBGLO)Then Begin
     Y^.ExternalBase:=ExternalNumber;Inc(ExternalNumber)
    End;
    if LastY=Nil Then M.Symbols:=Y else LastY^.Next:=Y;LastY:=Y
   End
  End;
  OBTXT:
  Begin
   if Len<6 Then Error(FileName,'bloc texte trop court')else
   Begin
    New(T);if T=Nil Then Fatal('memoire pleine');FillChar(T^,SizeOf(T^),0);
    T^.Offset:=LE32(B,0);T^.Section:=B[4];T^.Count:=B[5];
    if 6+T^.Count>Len Then Begin
     Error(FileName,'taille de texte incorrecte');Dispose(T)
    End else
    Begin
     For I:=0 to T^.Count-1 do T^.Data[I]:=B[6+I];P:=6+T^.Count;LastR:=Nil;
     While P<Len do Begin
      if P+3>Len Then Begin
       Error(FileName,'relogement tronque');Break
      End;
      New(R);if R=Nil Then Fatal('memoire pleine');FillChar(R^,SizeOf(R^),0);
      R^.Offset:=B[P]-6;R^.Action:=LE16(B,P+1)and RAMSK;R^.Base:=LE16(B,P+1)and RBMSK;
      if(R^.Action=RAZOF)or(R^.Action=RAZSS)or(R^.Action=RAZLS)Then SegmentedSeen:=True;
      Case R^.Action of RAA8:R^.Width:=1;RAA32,RAA32M,RAZLS:R^.Width:=4;else R^.Width:=2
     End;
     if(R^.Offset<0)or(R^.Offset+R^.Width>T^.Count)Then Error(FileName,
     'relogement hors du bloc');
     if LastR=Nil Then T^.Relocs:=R else LastR^.Next:=R;LastR:=R;Inc(P,3)
    End;
    if LastT=Nil Then M.Texts:=T else LastT^.Next:=T;LastT:=T;
    S:=FindObjSection(M,T^.Section);
    if S=Nil Then Error(FileName,'segment de texte inconnu')
    else
    Begin
     if T^.Count<>0 Then S^.HasBytes:=True else if T^.Offset<>0 Then S^.IsBss:=True;
     if T^.Offset+T^.Count>S^.Size Then S^.Size:=T^.Offset+T^.Count
    End
   End
  End
 End;
 OBTRA:if Len>=6 Then Begin
  M.HasTransfer:=True;M.TransferValue:=LE32(B,0);M.TransferBase:=LE16(B,4)
 End;
 OBOST,OBOND:;
 else Error(FileName,'type de bloc UNIDOT inconnu')
End
End;Close(F);if IOResult<>0 Then Error(FileName,'erreur de fermeture');
if TargetKnown and(TargetSegmented<>SegmentedSeen)Then
 Error(FileName,'melange de modules Z8001 et Z8002')
else Begin TargetKnown:=True;TargetSegmented:=SegmentedSeen End
End;

Function ReadBEWordFile(Var F:File;Var Ok:Boolean):Word;
Var B:Array[0..1]of Byte;N:Word;
Begin BlockRead(F,B,2,N);if N<>2 Then Ok:=False;ReadBEWordFile:=Word(B[0])shl 8 or B[1] End;

Function ReadBELongFile(Var F:File;Var Ok:Boolean):LongInt;
Var A,B:Word;
Begin A:=ReadBEWordFile(F,Ok);B:=ReadBEWordFile(F,Ok);ReadBELongFile:=LongInt(A)shl 16 or B End;

Function DefaultSegmentName(SegmentType:Byte;Index:Integer):String;
Var N:String;
Begin
 Str(Index,N);Case SegmentType of
  X_SG_COD:DefaultSegmentName:='__text'+N;
  X_SG_CON:DefaultSegmentName:='__con'+N;
  X_SG_DAT:DefaultSegmentName:='__data'+N;
  X_SG_BSS:DefaultSegmentName:='__bss'+N;
  X_SG_STK:DefaultSegmentName:='__stack'+N;
  else DefaultSegmentName:='__mixed'+N
 End
End;

Procedure ReadXOut(Const FileName:String;Var M:TModule);
Var F:File;Ok,Segmented:Boolean;Magic,NSeg:Word;InitSize,RelocSize,SymbolSize,ExpectedSize:LongInt;
 I,J,SegmentIndex,SymbolIndex:Integer;Assigned,SegmentType:Byte;SegmentLength:Word;
 S,LastS:PObjSection;Y,LastY:PObjSymbol;T,LastT:PText;R,LastR:PReloc;
 InitRead,Left,Chunk,Location:LongInt;Flag:Byte;Base:Word;Name:String;Buf:Array[0..248]of Byte;N:Word;
Begin
 FillChar(M,SizeOf(M),0);M.FileName:=FileName;Assign(F,FileName);Reset(F,1);
 if IOResult<>0 Then Begin Error(FileName,'ouverture impossible');Exit End;Ok:=True;
 Magic:=ReadBEWordFile(F,Ok);NSeg:=ReadBEWordFile(F,Ok);InitSize:=ReadBELongFile(F,Ok);
 RelocSize:=ReadBELongFile(F,Ok);SymbolSize:=ReadBELongFile(F,Ok);
 if not Ok Then Begin Close(F);Error(FileName,'en-tete x.out tronque');Exit End;
 Segmented:=(Magic=X_SU_MAGIC)or(Magic=X_SX_MAGIC);
 if not Segmented and not((Magic=X_NU_MAGIC)or(Magic=X_NXN_MAGIC)or
 (Magic=X_NUS_MAGIC)or(Magic=X_NXS_MAGIC)or(Magic=X_NUI_MAGIC)or(Magic=X_NXI_MAGIC))Then Begin
  Close(F);Error(FileName,'mot magique x.out inconnu');Exit
 End;
 M.IsExecutable:=(Magic=X_SX_MAGIC)or(Magic=X_NXN_MAGIC)or(Magic=X_NXS_MAGIC)or(Magic=X_NXI_MAGIC);
 if M.IsExecutable Then Begin Close(F);Error(FileName,'un executable x.out ne peut pas etre relie comme objet');Exit End;
 if(RelocSize<0)or(SymbolSize<0)or((RelocSize mod 6)<>0)or((SymbolSize mod 12)<>0)Then Begin
  Close(F);Error(FileName,'tailles de tables x.out incorrectes');Exit
 End;
 ExpectedSize:=16+LongInt(NSeg)*4+InitSize+RelocSize+SymbolSize;
 if ExpectedSize<>FileSize(F)Then Begin Close(F);Error(FileName,'taille globale x.out incoherente');Exit End;
 if TargetKnown and(TargetSegmented<>Segmented)Then Error(FileName,'melange de modules Z8001 et Z8002')
 else Begin TargetKnown:=True;TargetSegmented:=Segmented End;
 if(NSeg=0)or(NSeg>254)Then Begin Close(F);Error(FileName,'nombre de segments x.out incorrect');Exit End;
 LastS:=Nil;For I:=0 to NSeg-1 do Begin
  BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,SegmentType,1,N);if N<>1 Then Ok:=False;
  SegmentLength:=ReadBEWordFile(F,Ok);New(S);if S=Nil Then Fatal('memoire pleine');FillChar(S^,SizeOf(S^),0);
  if not(SegmentType in[X_SG_BSS,X_SG_STK,X_SG_COD,X_SG_CON,X_SG_DAT,X_SG_MXU,X_SG_MXP])Then
   Error(FileName,'type de segment x.out inconnu');
  S^.Number:=I+1;S^.AssignedNumber:=Assigned;S^.SegmentType:=SegmentType;S^.Size:=SegmentLength;
  S^.IsBss:=SegmentType in[X_SG_BSS,X_SG_STK];S^.Name:=DefaultSegmentName(SegmentType,I);
  if LastS=Nil Then M.Sections:=S else LastS^.Next:=S;LastS:=S
 End;
 if not Ok Then Begin Close(F);Error(FileName,'descripteurs x.out tronques');Exit End;
 InitRead:=0;LastT:=Nil;S:=M.Sections;
 While S<>Nil do Begin
  if not S^.IsBss Then Begin
   Left:=S^.Size;Location:=0;While Left>0 do Begin
    Chunk:=Left;if Chunk>249 Then Chunk:=249;BlockRead(F,Buf,Chunk,N);
    if N<>Chunk Then Begin Ok:=False;Break End;New(T);if T=Nil Then Fatal('memoire pleine');FillChar(T^,SizeOf(T^),0);
    T^.Section:=S^.Number;T^.Offset:=Location;T^.Count:=Chunk;For J:=0 to Chunk-1 do T^.Data[J]:=Buf[J];
    if LastT=Nil Then M.Texts:=T else LastT^.Next:=T;LastT:=T;Inc(Location,Chunk);Inc(InitRead,Chunk);Dec(Left,Chunk)
   End
  End;S:=S^.Next
 End;
 if(not Ok)or(InitRead<>InitSize)Then Begin Close(F);Error(FileName,'zone initialisee x.out incoherente');Exit End;
 { Les relogements x.out sont convertis dans des blocs texte artificiels. }
 For I:=1 to RelocSize div 6 do Begin
  BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,Flag,1,N);if N<>1 Then Ok:=False;
  Location:=ReadBEWordFile(F,Ok);Base:=ReadBEWordFile(F,Ok);SegmentIndex:=Assigned+1;
  S:=FindObjSection(M,SegmentIndex);if S=Nil Then Begin Error(FileName,'segment de relogement x.out inconnu');Continue End;
  T:=M.Texts;While(T<>Nil)and not((T^.Section=SegmentIndex)and(Location>=T^.Offset)and(Location<T^.Offset+T^.Count))do T:=T^.Next;
  if T=Nil Then Begin Error(FileName,'relogement x.out hors des donnees');Continue End;
  New(R);if R=Nil Then Fatal('memoire pleine');FillChar(R^,SizeOf(R^),0);R^.Offset:=Location-T^.Offset;
  Case Flag of
   X_RL_OFF,X_RL_XOF:Begin if Segmented Then R^.Action:=RAZOF else R^.Action:=RAA16M;R^.Width:=2 End;
   X_RL_SSG,X_RL_XSSG:Begin R^.Action:=RAZSS;R^.Width:=2 End;
   X_RL_LSG,X_RL_XLSG:Begin R^.Action:=RAZLS;R^.Width:=4 End;
   else Begin Error(FileName,'type de relogement x.out inconnu');R^.Action:=0 End
  End;
  if Flag in[X_RL_XOF,X_RL_XSSG,X_RL_XLSG]Then R^.Base:=RBEXT+Base else R^.Base:=Base+1;
  LastR:=T^.Relocs;if LastR=Nil Then T^.Relocs:=R else Begin While LastR^.Next<>Nil do LastR:=LastR^.Next;LastR^.Next:=R End
 End;
 if(RelocSize mod 6)<>0 Then Error(FileName,'taille de relogement x.out incorrecte');
 LastY:=Nil;For SymbolIndex:=0 to SymbolSize div 12-1 do Begin
  BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,Flag,1,N);if N<>1 Then Ok:=False;
  SegmentLength:=ReadBEWordFile(F,Ok);Name:='';For J:=1 to 8 do Begin BlockRead(F,SegmentType,1,N);if N<>1 Then Ok:=False;
   if SegmentType<>0 Then Name:=Name+Chr(SegmentType)
  End;
  if Flag=X_SY_SEG Then Begin S:=FindObjSection(M,Assigned+1);if S<>Nil Then S^.Name:=Name End
  else Begin New(Y);if Y=Nil Then Fatal('memoire pleine');FillChar(Y^,SizeOf(Y^),0);Y^.Name:=Name;Y^.Value:=SegmentLength;
   Y^.Global:=Flag in[X_SY_UNX,X_SY_GLB];Y^.Defined:=Flag<>X_SY_UNX;
   if Assigned=255 Then Y^.Section:=0 else Y^.Section:=Assigned+1;
   if not Y^.Defined Then Y^.ExternalBase:=RBEXT+SymbolIndex;
   if LastY=Nil Then M.Symbols:=Y else LastY^.Next:=Y;LastY:=Y
  End
 End;
 if(SymbolSize mod 12)<>0 Then Error(FileName,'taille de symboles x.out incorrecte');
 if not Ok Then Error(FileName,'fichier x.out tronque');Close(F);if IOResult<>0 Then Error(FileName,'erreur de fermeture')
End;

Procedure ReadObject(Const FileName:String;Var M:TModule);
Var F:File;B:Array[0..1]of Byte;N:Word;Magic:Word;
Begin
 Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Begin FillChar(M,SizeOf(M),0);M.FileName:=FileName;Error(FileName,'ouverture impossible');Exit End;
 BlockRead(F,B,2,N);Close(F);if IOResult<>0 Then Begin End;
 if N<>2 Then Begin FillChar(M,SizeOf(M),0);M.FileName:=FileName;Error(FileName,'fichier trop court');Exit End;
 Magic:=Word(B[0])shl 8 or B[1];
 if(Magic=X_SU_MAGIC)or(Magic=X_SX_MAGIC)or(Magic=X_NU_MAGIC)or(Magic=X_NXN_MAGIC)or
 (Magic=X_NUS_MAGIC)or(Magic=X_NXS_MAGIC)or(Magic=X_NUI_MAGIC)or(Magic=X_NXI_MAGIC)
 Then ReadXOut(FileName,M)else ReadUnidot(FileName,M)
End;

Procedure LayoutModule(Var M:TModule);
Var
 S:PObjSection;
 Y:PObjSymbol;
 G:PGlobal;
Begin
 S:=M.Sections;
 While S<>Nil do Begin
  S^.OutputSection:=FindOutSection(S^.Name,S^.Attributes);
  if S^.OutputSection^.SegmentType=0 Then S^.OutputSection^.SegmentType:=S^.SegmentType;
  S^.OutputBase:=S^.OutputSection^.Size;
  if(S^.IsBss or(Pos('BSS',UpperString(S^.Name))<>0))
  and not S^.HasBytes Then S^.OutputSection^.IsBss:=True;
  if S^.Size>2147483647-S^.OutputSection^.Size Then Fatal('segment de sortie trop grand');
  Inc(S^.OutputSection^.Size,S^.Size);S:=S^.Next
 End;
 Y:=M.Symbols;
 While Y<>Nil do Begin
  if Y^.Global and Y^.Defined Then Begin
   if Y^.Section=0 Then Begin
    G:=GetGlobal(Y^.Name);
    if G^.Defined Then Error(M.FileName,'symbole defini plusieurs fois: '+Y^.Name)
    else Begin G^.Defined:=True;G^.Absolute:=True;G^.Value:=Y^.Value End
   End else Begin
   S:=FindObjSection(M,Y^.Section);
   if S=Nil Then Error(M.FileName,'symbole dans un segment inconnu: '+Y^.Name)
   else
   Begin
    G:=GetGlobal(Y^.Name);
    if G^.Defined Then Error(M.FileName,'symbole defini plusieurs fois: '+Y^.Name)
    else
    Begin
     G^.Defined:=True;G^.Section:=S^.OutputSection;G^.Value:=S^.OutputBase+Y^.Value
    End
   End End
  End else if Y^.Global Then GetGlobal(Y^.Name);Y:=Y^.Next
 End;
 if M.HasTransfer and not HasTransfer Then Begin
  S:=FindObjSection(M,Byte(M.TransferBase));
  if S=Nil Then Error(M.FileName,'base du point d''entree inconnue')else
  Begin
   HasTransfer:=True;TransferValue:=S^.OutputBase+M.TransferValue;
   TransferBase:=S^.OutputSection^.Number
  End
 End
End;

Function FindExternalSymbol(Var M:TModule;Base:Word):PObjSymbol;
Var
 P:PObjSymbol;
Begin
 P:=M.Symbols;
 While(P<>Nil)and(P^.ExternalBase<>Base)do P:=P^.Next;FindExternalSymbol:=P
End;

Function ReadBE16(S:POutSection;O:LongInt):Word;Begin
 ReadBE16:=Word(GetImageByte(S,O))shl 8 or GetImageByte(S,O+1)
End;

Function ReadBE32(S:POutSection;O:LongInt):LongInt;Begin
 ReadBE32:=LongInt(ReadBE16(S,O))shl 16 or ReadBE16(S,O+2)
End;

Procedure WriteBE16Image(S:POutSection;O:LongInt;V:Word);Begin
 PutImageByte(S,O,V shr 8);PutImageByte(S,O+1,V)
End;

Procedure WriteBE32Image(S:POutSection;O:LongInt;V:LongInt);Begin
 WriteBE16Image(S,O,Word(LongInt(V)shr 16));WriteBE16Image(S,O+2,Word(V))
End;

Procedure ApplyAddend(S:POutSection;O:LongInt;Action:Word;Addend:LongInt);
Var
 V:LongInt;
 W:Word;
Begin
 Case Action of
 RAA8:PutImageByte(S,O,Byte(GetImageByte(S,O)+Addend));
 RAA16,RAA16M,RAZOF:
 Begin
  W:=ReadBE16(S,O);WriteBE16Image(S,O,Word(W+Addend))
 End;
 RAA32,RAA32M:
 Begin
  V:=ReadBE32(S,O);WriteBE32Image(S,O,V+Addend)
 End;
 RAZSS:
 Begin
  W:=ReadBE16(S,O);W:=(W and $FF00)or Word((W+Addend)and $FF);WriteBE16Image(S,O,W)
 End;
 RAZLS:
 Begin
  V:=ReadBE32(S,O);V:=(V and LongInt($FFFF0000))or((V+Addend)and $FFFF);
  WriteBE32Image(S,O,V)
 End
End
End;

Procedure CopyAndRelocateModule(Var M:TModule);
Var
 T:PText;
 S,Target:PObjSection;
 R:PReloc;
 Y:PObjSymbol;
 G:PGlobal;
 I:Integer;
 OutOffset,Addend:LongInt;
 NewBase:Word;
Begin
 T:=M.Texts;
 While T<>Nil do Begin
  S:=FindObjSection(M,T^.Section);if S<>Nil Then Begin
   OutOffset:=S^.OutputBase+T^.Offset;
   For I:=0 to T^.Count-1 do PutImageByte(S^.OutputSection,OutOffset+I,T^.Data[I]);
   R:=T^.Relocs;
   While R<>Nil do Begin
    Addend:=0;NewBase:=0;
    if R^.Base>=RBEXT Then Begin
     Y:=FindExternalSymbol(M,R^.Base);
     if Y=Nil Then Error(M.FileName,'indice externe inconnu')else
     Begin
      G:=FindGlobal(Y^.Name);
      if(G=Nil)or not G^.Defined Then Begin
       if not Opt.Relocatable Then Error(M.FileName,'symbole non defini: '+Y^.Name);
       if G<>Nil Then NewBase:=G^.ObjectBase
      End else
      Begin
       Addend:=G^.Value;if not G^.Absolute Then NewBase:=G^.Section^.Number
      End
     End
    End else if R^.Base<>0 Then Begin
     Target:=FindObjSection(M,Byte(R^.Base));
     if Target=Nil Then Error(M.FileName,'base de relogement inconnue')
     else
     Begin
      Addend:=Target^.OutputBase;NewBase:=Target^.OutputSection^.Number
     End
    End;
    ApplyAddend(S^.OutputSection,OutOffset+R^.Offset,R^.Action,Addend);
    if NewBase<>0 Then AddOutputRelocation(S^.OutputSection,OutOffset+R^.Offset,R^.Action,
    NewBase,R^.Width);
    R:=R^.Next
   End
  End;T:=T^.Next
 End
End;

Procedure AssignExternalBases;
Var
 G:PGlobal;
 N:Word;
Begin
 N:=RBEXT;G:=Globals;
 While G<>Nil do Begin
  if not G^.Defined Then Begin
   G^.ObjectBase:=N;Inc(N);if N>=RBMSK Then Fatal('trop de symboles externes')
  End;
  G:=G^.Next
 End;
 if Opt.Strip Then Begin
  G:=Globals;
  While G<>Nil do Begin
   if not G^.Defined Then Fatal(
   '-s ne peut pas supprimer une table externe encore necessaire');G:=G^.Next
  End
 End
End;

Procedure ApplyLayoutOptions;
Var
 S,Stack:POutSection;
 U:String;
 N:Integer;
Begin
 S:=OutSections;
 While S<>Nil do Begin
 U:=UpperString(S^.Name);
  if S^.SegmentType=0 Then Begin
   if S^.IsBss or(Pos('BSS',U)<>0)Then S^.SegmentType:=X_SG_BSS
   else if Pos('STACK',U)<>0 Then S^.SegmentType:=X_SG_STK
   else if Pos('DATA',U)<>0 Then S^.SegmentType:=X_SG_DAT
   else if Pos('CONST',U)<>0 Then S^.SegmentType:=X_SG_CON
   else if Pos('TEXT',U)<>0 Then S^.SegmentType:=X_SG_COD
   else S^.SegmentType:=X_SG_MXU
  End;
  if Opt.ReadOnly and((U='__TEXT')or(Pos('TEXT',U)<>0))Then S^.Attributes:=
  S^.Attributes or 2;
  S:=S^.Next
 End;
 if Opt.StackSize>0 Then Begin
  Stack:=FindOutSection('__stack',0);Stack^.IsBss:=True;
 if Stack^.Size<Opt.StackSize Then Stack^.Size:=Opt.StackSize
 End;
 N:=0;S:=OutSections;While S<>Nil do Begin
  if S^.SegmentType=0 Then if S^.IsBss Then S^.SegmentType:=X_SG_STK else S^.SegmentType:=X_SG_MXU;
  if N>127 Then Fatal('x.out ne peut contenir plus de 128 segments');
  if S^.Size>$FFFF Then Fatal('segment x.out superieur a 64 Kio: '+S^.Name);
  S^.AssignedNumber:=N;Inc(N);S:=S^.Next
 End
End;

Procedure PutLE16(Var B:TBuffer;Var N:Integer;V:Word);Begin
 B[N]:=V;B[N+1]:=V shr 8;Inc(N,2)
End;

Procedure PutLE32(Var B:TBuffer;Var N:Integer;V:LongInt);Begin
 PutLE16(B,N,Word(V));PutLE16(B,N,Word(LongInt(V)shr 16))
End;

Procedure PutName(Var B:TBuffer;Var N:Integer;S:String);
Var
 I,L:Integer;
Begin
 L:=Length(S);if L>8 Then L:=8;
 For I:=1 to L do Begin
  B[N]:=Ord(S[I]);Inc(N)
 End;B[N]:=0;Inc(N)
End;

Procedure WriteBlock(Kind:Byte;Var B:TBuffer;N:Integer);
Var
 W:Word;
 L:Byte;
Begin
 L:=N;BlockWrite(OutputFile,Kind,1,W);if W<>1 Then Fatal('erreur d''ecriture');
 BlockWrite(OutputFile,L,1,W);if W<>1 Then Fatal('erreur d''ecriture');
 if N<>0 Then Begin
  BlockWrite(OutputFile,B,N,W);if W<>N Then Fatal('erreur d''ecriture')
 End
End;

Procedure WriteSections;
Var
 B:TBuffer;
 N,Need:Integer;
 S:POutSection;
Begin
 N:=0;S:=OutSections;
 While S<>Nil do Begin
  Need:=4+Length(S^.Name);if Need>12 Then Need:=12;
  if N+Need>255 Then Begin
   WriteBlock(OBSEC,B,N);N:=0
  End;
  B[N]:=S^.Number;B[N+1]:=S^.Attributes;B[N+2]:=0;Inc(N,3);PutName(B,N,S^.Name);S:=S^.Next
 End;if N<>0 Then WriteBlock(OBSEC,B,N)
End;

Procedure WriteGlobals;
Var
 B:TBuffer;
 N,Need:Integer;
 G:PGlobal;
Begin
 if Opt.Strip Then Exit;N:=0;G:=Globals;
 While G<>Nil do Begin
  Need:=6+Length(G^.Name);if Need>14 Then Need:=14;
  if N+Need>255 Then Begin
   WriteBlock(OBGLO,B,N);N:=0
  End;
  if G^.Defined Then Begin
   PutLE32(B,N,G^.Value);B[N]:=G^.Section^.Number
  End
  else
  Begin
   PutLE32(B,N,0);B[N]:=RBUND
  End;Inc(N);PutName(B,N,G^.Name);G:=G^.Next
 End;if N<>0 Then WriteBlock(OBGLO,B,N)
End;

Procedure WriteText(S:POutSection);
Var
 B:TBuffer;
 Position:LongInt;
 Chunk,N,Count,I:Integer;
 R:PReloc;
Begin
 Position:=0;
 While Position<S^.Size do Begin
  Chunk:=S^.Size-Position;if Chunk>249 Then Chunk:=249;
  Repeat
  Count:=0;R:=Relocations;
  While R<>Nil do Begin
   if(R^.Section=S)and(R^.Offset>=Position)and(R^.Offset<Position+Chunk)Then Begin
    Inc(Count);if R^.Offset+R^.Width>Position+Chunk Then Chunk:=R^.Offset-Position
   End;R:=R^.Next
  End;
  if 6+Chunk+3*Count>255 Then Dec(Chunk)else Break
  Until Chunk=0;
  if Chunk<=0 Then Fatal('relogement trop grand');N:=0;PutLE32(B,N,Position);
  B[N]:=S^.Number;Inc(N);B[N]:=Chunk;Inc(N);
  For I:=0 to Chunk-1 do Begin
   B[N]:=GetImageByte(S,Position+I);Inc(N)
  End;
  R:=Relocations;
  While R<>Nil do Begin
   if(R^.Section=S)and(R^.Offset>=Position)and(R^.Offset<Position+Chunk)Then Begin
    B[N]:=6+R^.Offset-Position;Inc(N);PutLE16(B,N,R^.Action or(R^.Base and RBMSK))
   End;R:=R^.Next
  End;WriteBlock(OBTXT,B,N);Inc(Position,Chunk)
 End
End;

Procedure WriteUnidotOutput;
Var
 B:TBuffer;
 N:Integer;
 S:POutSection;
 Old:File;
 Backup:String;
 HadOld:Boolean;
Begin
 TemporaryName:=Opt.OutputName+'.$$$';DeleteQuiet(TemporaryName);
 Assign(OutputFile,TemporaryName);Rewrite(OutputFile,1);
 if IOResult<>0 Then Fatal('creation impossible: '+TemporaryName);OutputOpen:=True;
 N:=0;WriteBlock(OBOST,B,N);N:=0;PutName(B,N,'LDZ8K');WriteBlock(OBMOD,B,N);
 WriteSections;WriteGlobals;S:=OutSections;
 While S<>Nil do Begin
  if S^.IsBss Then Begin
   N:=0;PutLE32(B,N,S^.Size);B[N]:=S^.Number;Inc(N);B[N]:=0;Inc(N);WriteBlock(OBTXT,B,N)
  End
  else WriteText(S);S:=S^.Next
 End;
 if HasTransfer Then Begin
  N:=0;PutLE32(B,N,TransferValue);PutLE16(B,N,TransferBase);WriteBlock(OBTRA,B,N)
 End;
 N:=0;WriteBlock(OBOND,B,N);Close(OutputFile);OutputOpen:=False;
 if IOResult<>0 Then Fatal('fermeture impossible');
 Backup:=Opt.OutputName+'.$OLD';DeleteQuiet(Backup);HadOld:=FileExists(Opt.OutputName);
 if HadOld Then Begin
  Assign(Old,Opt.OutputName);Rename(Old,Backup);
  if IOResult<>0 Then Fatal('sauvegarde de l''ancienne sortie impossible')
 End;
 Assign(OutputFile,TemporaryName);Rename(OutputFile,Opt.OutputName);
 if IOResult<>0 Then Begin
  if HadOld Then Begin
   Assign(Old,Backup);Rename(Old,Opt.OutputName);if IOResult<>0 Then Begin
   End
  End;
  Fatal('installation de la sortie impossible')
 End;if HadOld Then DeleteQuiet(Backup);TemporaryName:=''
End;

Procedure RawByte(V:Byte);
Var N:Word;
Begin BlockWrite(OutputFile,V,1,N);if N<>1 Then Fatal('erreur d''ecriture x.out') End;

Procedure RawWord(V:Word);
Begin RawByte(V shr 8);RawByte(V) End;

Procedure RawLong(V:LongInt);
Begin RawWord(Word(LongInt(V)shr 16));RawWord(Word(V)) End;

Function FindOutByNumber(N:Word):POutSection;
Var S:POutSection;
Begin S:=OutSections;While(S<>Nil)and(S^.Number<>N)do S:=S^.Next;FindOutByNumber:=S End;

Function FindGlobalByBase(N:Word):PGlobal;
Var G:PGlobal;
Begin G:=Globals;While(G<>Nil)and(G^.ObjectBase<>N)do G:=G^.Next;FindGlobalByBase:=G End;

Function UndefinedGlobals:Boolean;
Var G:PGlobal;
Begin G:=Globals;While G<>Nil do Begin if not G^.Defined Then Begin UndefinedGlobals:=True;Exit End;G:=G^.Next End;
 UndefinedGlobals:=False
End;

Procedure PrepareExecutable;
Var S,T:POutSection;R:PReloc;Base,CodeBase,DataBase:LongInt;
Begin
 Base:=0;CodeBase:=0;DataBase:=0;S:=OutSections;
 While S<>Nil do Begin
  if TargetSegmented Then S^.LoadBase:=0
  else if Opt.SplitID Then Begin
   if S^.SegmentType in[X_SG_COD,X_SG_CON]Then Begin S^.LoadBase:=CodeBase;Inc(CodeBase,S^.Size)End
   else Begin S^.LoadBase:=DataBase;Inc(DataBase,S^.Size)End
  End else Begin S^.LoadBase:=Base;Inc(Base,S^.Size) End;
  S:=S^.Next
 End;
 R:=Relocations;While R<>Nil do Begin
  T:=FindOutByNumber(R^.Base);if T=Nil Then Fatal('base de relogement de sortie inconnue');
  if TargetSegmented and(R^.Action=RAZSS)Then
   WriteBE16Image(R^.Section,R^.Offset,(ReadBE16(R^.Section,R^.Offset)and $80FF)or
   (Word(T^.AssignedNumber and $7F)shl 8))
  else if TargetSegmented and(R^.Action=RAZLS)Then
   WriteBE32Image(R^.Section,R^.Offset,(ReadBE32(R^.Section,R^.Offset)and LongInt($80FFFFFF))or
   (LongInt(T^.AssignedNumber and $7F)shl 24))
  else ApplyAddend(R^.Section,R^.Offset,R^.Action,T^.LoadBase);
  R:=R^.Next
 End
End;

Procedure AssignXOutSymbolIndices(SegmentCount:Word);
Var G:PGlobal;N:Word;
Begin N:=SegmentCount;G:=Globals;While G<>Nil do Begin G^.SymbolIndex:=N;Inc(N);G:=G^.Next End End;

Procedure WriteXName(S:String);
Var I:Integer;
Begin For I:=1 to 8 do if I<=Length(S)Then RawByte(Ord(S[I]))else RawByte(0) End;

Procedure WriteXOut;
Var S:POutSection;G:PGlobal;R:PReloc;Old:File;Backup:String;HadOld,Executable:Boolean;
 Magic,SegmentCount,SymbolCount:Word;InitSize,RelocSize,SymbolSize:LongInt;Flag:Byte;Location:LongInt;
Begin
 Executable:=not Opt.Relocatable and not UndefinedGlobals;
 SegmentCount:=0;InitSize:=0;S:=OutSections;While S<>Nil do Begin
  Inc(SegmentCount);if not S^.IsBss Then Inc(InitSize,S^.Size);S:=S^.Next
 End;
 AssignXOutSymbolIndices(SegmentCount);
 if Executable Then Begin PrepareExecutable;RelocSize:=0 End
 else Begin RelocSize:=0;R:=Relocations;While R<>Nil do Begin Inc(RelocSize,6);R:=R^.Next End End;
 SymbolCount:=0;if not(Opt.Strip and Executable)Then Begin
  SymbolCount:=SegmentCount;G:=Globals;While G<>Nil do Begin Inc(SymbolCount);G:=G^.Next End
 End;SymbolSize:=LongInt(SymbolCount)*12;
 if TargetSegmented Then if Executable Then Magic:=X_SX_MAGIC else Magic:=X_SU_MAGIC
 else if Opt.SplitID Then if Executable Then Magic:=X_NXI_MAGIC else Magic:=X_NUI_MAGIC
 else if Opt.ReadOnly Then if Executable Then Magic:=X_NXS_MAGIC else Magic:=X_NUS_MAGIC
 else if Executable Then Magic:=X_NXN_MAGIC else Magic:=X_NU_MAGIC;
 TemporaryName:=Opt.OutputName+'.$$$';DeleteQuiet(TemporaryName);Assign(OutputFile,TemporaryName);Rewrite(OutputFile,1);
 if IOResult<>0 Then Fatal('creation impossible: '+TemporaryName);OutputOpen:=True;
 RawWord(Magic);RawWord(SegmentCount);RawLong(InitSize);RawLong(RelocSize);RawLong(SymbolSize);
 S:=OutSections;While S<>Nil do Begin
  if TargetSegmented Then RawByte(S^.AssignedNumber)else RawByte(255);
  RawByte(S^.SegmentType);RawWord(Word(S^.Size));S:=S^.Next
 End;
 S:=OutSections;While S<>Nil do Begin
  if not S^.IsBss Then Begin Location:=0;While Location<S^.Size do Begin RawByte(GetImageByte(S,Location));Inc(Location)End End;
  S:=S^.Next
 End;
 if not Executable Then Begin R:=Relocations;While R<>Nil do Begin
  RawByte(R^.Section^.AssignedNumber);Location:=R^.Offset;
  Case R^.Action of
   RAA16,RAA16M,RAZOF:Flag:=X_RL_OFF;
   RAA32,RAA32M:Begin Flag:=X_RL_OFF;Inc(Location,2)End;
   RAZSS:Flag:=X_RL_SSG;RAZLS:Flag:=X_RL_LSG;
   else Fatal('relogement non representable dans x.out')
  End;
  if R^.Base>=RBEXT Then Begin
   G:=FindGlobalByBase(R^.Base);if G=Nil Then Fatal('symbole externe de relogement inconnu');Inc(Flag,4);
   RawByte(Flag);if Location>$FFFF Then Fatal('position de relogement x.out hors limite');RawWord(Location);RawWord(G^.SymbolIndex)
  End else Begin
   S:=FindOutByNumber(R^.Base);if S=Nil Then Fatal('segment cible de relogement inconnu');RawByte(Flag);
   if Location>$FFFF Then Fatal('position de relogement x.out hors limite');RawWord(Location);RawWord(S^.AssignedNumber)
  End;R:=R^.Next
 End End;
 if SymbolCount<>0 Then Begin
  S:=OutSections;While S<>Nil do Begin RawByte(S^.AssignedNumber);RawByte(X_SY_SEG);RawWord(0);WriteXName(S^.Name);S:=S^.Next End;
  G:=Globals;While G<>Nil do Begin
   if not G^.Defined Then Begin RawByte(255);RawByte(X_SY_UNX);RawWord(0)End
   else Begin
    if(G^.Value<0)or(G^.Value>$FFFF)Then Fatal('valeur de symbole x.out hors limite: '+G^.Name);
    if G^.Absolute Then Begin RawByte(255);RawByte(X_SY_GLB);RawWord(Word(G^.Value))End
    else Begin RawByte(G^.Section^.AssignedNumber);RawByte(X_SY_GLB);RawWord(Word(G^.Value))End
   End;
   WriteXName(G^.Name);G:=G^.Next
  End
 End;
 Close(OutputFile);OutputOpen:=False;if IOResult<>0 Then Fatal('fermeture impossible');
 Backup:=Opt.OutputName+'.$OLD';DeleteQuiet(Backup);HadOld:=FileExists(Opt.OutputName);
 if HadOld Then Begin Assign(Old,Opt.OutputName);Rename(Old,Backup);if IOResult<>0 Then Fatal('sauvegarde de l''ancienne sortie impossible')End;
 Assign(OutputFile,TemporaryName);Rename(OutputFile,Opt.OutputName);
 if IOResult<>0 Then Begin if HadOld Then Begin Assign(Old,Backup);Rename(Old,Opt.OutputName);if IOResult<>0 Then Begin End End;
  Fatal('installation de la sortie impossible')End;
 if HadOld Then DeleteQuiet(Backup);TemporaryName:=''
End;

Procedure FreeModule(Var M:TModule);
Var
 S,SN:PObjSection;
 Y,YN:PObjSymbol;
 T,TN:PText;
 R,RN:PReloc;
Begin
 S:=M.Sections;
 While S<>Nil do Begin
  SN:=S^.Next;Dispose(S);S:=SN
 End;
 Y:=M.Symbols;
 While Y<>Nil do Begin
  YN:=Y^.Next;Dispose(Y);Y:=YN
 End;
 T:=M.Texts;
 While T<>Nil do Begin
  TN:=T^.Next;R:=T^.Relocs;
  While R<>Nil do Begin
   RN:=R^.Next;Dispose(R);R:=RN
  End;Dispose(T);T:=TN
 End
End;

Procedure AddForcedUndefined;
Var
 P:PInput;
Begin
 P:=ForcedUndefined;
 While P<>Nil do Begin
  GetGlobal(P^.Name);P:=P^.Next
 End
End;

Var
 P:PInput;
 Modules,LastModule,MN,MNext:PModuleNode;
 ModuleCount:LongInt;

BEGIN
 Inputs:=Nil;LastInput:=Nil;ForcedUndefined:=Nil;LastForced:=Nil;OutSections:=Nil;
 LastOutSection:=Nil;
 Globals:=Nil;Relocations:=Nil;LastRelocation:=Nil;ErrorCount:=0;
 NextSectionNumber:=1;OutputOpen:=False;TemporaryName:='';ModuleCount:=0;Modules:=Nil;
 LastModule:=Nil;
 HasTransfer:=False;TransferValue:=0;TransferBase:=0;
 TargetKnown:=False;TargetSegmented:=False;
 ParseCommandLine;AddForcedUndefined;P:=Inputs;
 While P<>Nil do Begin
  New(MN);if MN=Nil Then Fatal('memoire pleine');FillChar(MN^,SizeOf(MN^),0);
  ReadObject(P^.Name,MN^.Item);if ErrorCount=0 Then Begin
   LayoutModule(MN^.Item);if LastModule=Nil Then Modules:=MN else LastModule^.Next:=MN;
   LastModule:=MN;Inc(ModuleCount)
  End else Dispose(MN);P:=P^.Next
 End;
 ApplyLayoutOptions;
 AssignExternalBases;
 MN:=Modules;
 While(MN<>Nil)and(ErrorCount=0)do Begin
  CopyAndRelocateModule(MN^.Item);MN:=MN^.Next
 End;
 if(ErrorCount=0)Then WriteXOut;
 MN:=Modules;
 While MN<>Nil do Begin
  MNext:=MN^.Next;FreeModule(MN^.Item);Dispose(MN);MN:=MNext
 End;
 if ErrorCount<>0 Then Begin
  WriteLn(ErrorCount,' erreur(s)');Halt(1)
 End;
 WriteLn('LDZ8K: ',ModuleCount,' module(s) lies dans ',Opt.OutputName);Halt(0)
END.
