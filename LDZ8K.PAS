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
 X_SU_MAGIC=$EE00;
 X_SX_MAGIC=$EE01;
 X_NU_MAGIC=$EE02;
 X_NXN_MAGIC=$EE03;
 X_NUS_MAGIC=$EE06;
 X_NXS_MAGIC=$EE07;
 X_NUI_MAGIC=$EE0A;
 X_NXI_MAGIC=$EE0B;
 X_SG_BSS=1;
 X_SG_STK=2;
 X_SG_COD=3;
 X_SG_CON=4;
 X_SG_DAT=5;
 X_SG_MXU=6;
 X_SG_MXP=7;
 X_RL_OFF=1;
 X_RL_SSG=2;
 X_RL_LSG=3;
 X_RL_XOF=5;
 X_RL_XSSG=6;
 X_RL_XLSG=7;
 X_SY_LOC=1;
 X_SY_UNX=2;
 X_SY_GLB=3;
 X_SY_SEG=4;
 AR8K_MAGIC=$FF65;
 AR8K_HEADER_SIZE=26;
 MaxSegmentSize=65535;
 SharedBoundary=8192;
 DefaultStackSize=256;
 MaxErrors=100;

Type
 TBuffer=Array[0..254]of Byte;
 PInput=^TInput;
TInput=Record Name:String;
Next:PInput
End;
PDescriptor=^TDescriptor;
TDescriptor=Record
 Text:String;
 FromFile:Boolean;
 Next:PDescriptor
End;
PImage=^TImage;
TImage=Record Index:LongInt;
Data:Array[0..4095]of Byte;
Next:PImage
End;
POutSection=^TOutSection;
TOutSection=Record
Number,Attributes,SegmentType,AssignedNumber,Ordinal:Byte;
Name:String;
Size,LoadBase:LongInt;
IsBss,Fixed,Common,Reserved:Boolean;
FirstImage,LastImage:PImage;
Next:POutSection
End;
PSegmentAlias=^TSegmentAlias;
TSegmentAlias=Record
 Name:String;
 Segment:POutSection;
 Next:PSegmentAlias
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
CommonSize:LongInt;
ObjectBase,SymbolIndex:Word;
Next:PGlobal
End;
PLocalSymbol=^TLocalSymbol;
TLocalSymbol=Record
 Name:String;
 Section:POutSection;
 Value:LongInt;
 Next:PLocalSymbol
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
HasTransfer,IsExecutable,TargetKnown,TargetSegmented:Boolean;
TransferValue:LongInt;
TransferBase:Word
End;
PModuleNode=^TModuleNode;
TModuleNode=Record Item:TModule;
Next:PModuleNode
End;
TOptions=Record
 OutputName:String;
 Relocatable,Strip,SplitID,ReadOnly,Preassign,StackSpecified:Boolean;
 StackSize:LongInt
End;

Var
 Opt:TOptions;
 Inputs,LastInput:PInput;
 Descriptors,LastDescriptor:PDescriptor;
 SegmentAliases:PSegmentAlias;
 OutSections,LastOutSection:POutSection;
 Globals:PGlobal;
 LocalSymbols,LastLocalSymbol:PLocalSymbol;
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
 Modules,LastModule:PModuleNode;
 ModuleCount:LongInt;

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
 WriteLn('  -r          produit un objet x.out relogeable et conserve les externes');
 WriteLn('  -s          supprime les symboles locaux et la table publique finale');
 WriteLn('  -u symbole  ajoute une reference externe forcee');
 WriteLn('  -i          espace instructions/donnees separe');
 WriteLn('  -n          texte partage, donnees alignees sur 8 Kio');
 WriteLn('  -t taille   pile en octets (decimal, arrondie au mot, maximum 65534)');
 WriteLn('              defaut chargeur Z8002: 256; Z8001: segment explicite de 256');
 WriteLn('  -w          reserve 0=TEXT, 1=CONST, 2=DATA et 3=BSS');
 WriteLn('  -d fichier  lit les descriptions de segments dans un fichier');
 WriteLn('  -d"ligne"   applique directement une ligne de description');
 WriteLn('  -lxx        recherche la bibliotheque AR8K libxx.a');
 WriteLn('              chemins: repertoire courant, LIB, LIBRARY et repertoire lib');
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

Procedure AddDescriptor(Const Text:String;FromFile:Boolean);
Var P:PDescriptor;
Begin
 New(P);if P=Nil Then Fatal('memoire pleine');P^.Text:=Text;P^.FromFile:=FromFile;P^.Next:=Nil;
 if LastDescriptor=Nil Then Descriptors:=P else LastDescriptor^.Next:=P;LastDescriptor:=P
End;

Function ResolveLibrary(Const Abbreviation:String):String;Forward;

Procedure ParseCommandLine;
Var
 I,J,Code:Integer;
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
  else if U='-W'Then Opt.Preassign:=True
  else if U='-D'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-d exige un fichier de descriptions');
   AddDescriptor(ParamStr(I),True)
  End
  else if(Length(S)>2)and(S[1]='-')and(UpCase(S[2])='D')Then
   AddDescriptor(Copy(S,3,Length(S)),False)
  else if U='-T'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-t exige une taille');
   S:=ParamStr(I);
   if S=''Then Fatal('taille de pile incorrecte');
   For J:=1 to Length(S)do if not(S[J]in['0'..'9'])Then
    Fatal('taille de pile incorrecte: '+S);
   Val(S,Opt.StackSize,Code);
   if(Code<>0)or(Opt.StackSize<0)or(Opt.StackSize>65534)Then
    Fatal('taille de pile hors limite (0..65534)');
   if(Opt.StackSize and 1)<>0 Then Inc(Opt.StackSize);
   Opt.StackSpecified:=True
  End
  else if U='-U'Then Begin
   Inc(I);if I>ParamCount Then Fatal('-u exige un symbole');
   AddInput(ParamStr(I),ForcedUndefined,LastForced)
  End
  else if(Length(S)>2)and(S[1]='-')and(UpCase(S[2])='L')Then
   AddInput(ResolveLibrary(Copy(S,3,Length(S))),Inputs,LastInput)
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
M.TargetKnown:=True;M.TargetSegmented:=SegmentedSeen
End;

Function CreateOutSection(Const Name:String;Attributes,SegmentType:Byte):POutSection;
Var P:POutSection;
Begin
 New(P);if P=Nil Then Fatal('memoire pleine');FillChar(P^,SizeOf(P^),0);
 if NextSectionNumber>=RBUND Then Fatal('trop de segments de sortie');
 P^.Number:=NextSectionNumber;Inc(NextSectionNumber);P^.Name:=Name;
 P^.Attributes:=Attributes;P^.SegmentType:=SegmentType;P^.AssignedNumber:=255;
 if LastOutSection=Nil Then OutSections:=P else LastOutSection^.Next:=P;
 LastOutSection:=P;CreateOutSection:=P
End;

Function IsCommonName(Const Name:String):Boolean;
Var U:String;
Begin U:=UpperString(Name);IsCommonName:=(U='COMMON')or(Pos('COMMON$',U)=1)or(Pos('__COMMON',U)=1)End;

Procedure NormalizeObjSection(S:PObjSection);
Var U:String;
Begin
 U:=UpperString(S^.Name);
 if S^.SegmentType=0 Then Begin
  if S^.IsBss or(Pos('BSS',U)<>0)or IsCommonName(U)Then S^.SegmentType:=X_SG_BSS
  else if Pos('STACK',U)<>0 Then S^.SegmentType:=X_SG_STK
  else if Pos('CONST',U)<>0 Then S^.SegmentType:=X_SG_CON
  else if Pos('DATA',U)<>0 Then S^.SegmentType:=X_SG_DAT
  else if(Pos('TEXT',U)<>0)or(Pos('CODE',U)<>0)Then S^.SegmentType:=X_SG_COD
  else S^.SegmentType:=X_SG_MXU
 End
End;

Function CompatibleSegmentType(A,B:Byte):Boolean;
Begin CompatibleSegmentType:=(A=0)or(B=0)or(A=B)End;

Function IsInstructionType(Typ:Byte):Boolean;
Begin IsInstructionType:=Typ=X_SG_COD End;

Function SameAddressSpace(A,B:POutSection):Boolean;
Begin
 if not Opt.SplitID Then SameAddressSpace:=True
 else SameAddressSpace:=IsInstructionType(A^.SegmentType)=IsInstructionType(B^.SegmentType)
End;

Function FindSegmentAlias(Const Name:String):PSegmentAlias;
Var A:PSegmentAlias;U:String;
Begin U:=UpperString(Name);A:=SegmentAliases;
 While(A<>Nil)and(UpperString(A^.Name)<>U)do A:=A^.Next;FindSegmentAlias:=A
End;

Procedure AddSegmentAlias(Const Name:String;S:POutSection);
Var A:PSegmentAlias;
Begin
 if Name=''Then Exit;A:=FindSegmentAlias(Name);
 if A<>Nil Then Begin
  if A^.Segment<>S Then Error(Name,'alias de segment defini plusieurs fois');Exit
 End;
 New(A);if A=Nil Then Fatal('memoire pleine');A^.Name:=Name;A^.Segment:=S;
 A^.Next:=SegmentAliases;SegmentAliases:=A
End;

Function AllocateOutSection(S:PObjSection):POutSection;
Var P,Best:POutSection;A:PSegmentAlias;FixedInput,CommonInput:Boolean;Physical:Byte;Suffix:String;N:Integer;
Begin
 NormalizeObjSection(S);FixedInput:=S^.AssignedNumber<>255;
 if FixedInput Then Begin Physical:=S^.AssignedNumber and $7F;FixedInput:=Physical<>127 End;
 CommonInput:=IsCommonName(S^.Name);Best:=Nil;P:=OutSections;
 A:=FindSegmentAlias(S^.Name);
 if A<>Nil Then Begin
  P:=A^.Segment;
  if not CompatibleSegmentType(P^.SegmentType,S^.SegmentType)Then
   Error(S^.Name,'type incompatible avec sa description de segment')
  else if P^.Size+(P^.Size and 1)+S^.Size>MaxSegmentSize Then
   Error(S^.Name,'debordement du segment impose par -d')
  else Begin if P^.SegmentType=0 Then P^.SegmentType:=S^.SegmentType;AllocateOutSection:=P;Exit End;
  AllocateOutSection:=P;Exit
 End;
 While P<>Nil do Begin
  if FixedInput and P^.Fixed and(P^.AssignedNumber=Physical)and
  ((not Opt.SplitID)or(IsInstructionType(P^.SegmentType)=IsInstructionType(S^.SegmentType)))Then Begin
   if not CompatibleSegmentType(P^.SegmentType,S^.SegmentType)Then
    Error(S^.Name,'collision de numero de segment fixe')
   else if P^.Size+(P^.Size and 1)+S^.Size>MaxSegmentSize Then
    Error(S^.Name,'debordement d''un segment fixe')
   else Begin AllocateOutSection:=P;Exit End;
   AllocateOutSection:=P;Exit
  End;
  if CommonInput and P^.Common and(UpperString(P^.Name)=UpperString(S^.Name))Then Begin
   AllocateOutSection:=P;Exit
  End;
  if(not FixedInput)and P^.Fixed and CompatibleSegmentType(P^.SegmentType,S^.SegmentType)and
   (P^.Size+(P^.Size and 1)+S^.Size<=MaxSegmentSize)Then Begin AllocateOutSection:=P;Exit End;
  if(not P^.Fixed)and not P^.Common and CompatibleSegmentType(P^.SegmentType,S^.SegmentType)and
   (UpperString(P^.Name)=UpperString(S^.Name))and
   (P^.Size+(P^.Size and 1)+S^.Size<=MaxSegmentSize)Then Best:=P;
  P:=P^.Next
 End;
 if Best<>Nil Then Begin AllocateOutSection:=Best;Exit End;
 Suffix:='';N:=1;P:=OutSections;
 While P<>Nil do Begin if UpperString(P^.Name)=UpperString(S^.Name+Suffix)Then Begin
  Str(N,Suffix);Suffix:='$'+Suffix;Inc(N);P:=OutSections
 End else P:=P^.Next End;
 Best:=CreateOutSection(S^.Name+Suffix,S^.Attributes,S^.SegmentType);
 Best^.IsBss:=S^.IsBss or(S^.SegmentType in[X_SG_BSS,X_SG_STK]);
 Best^.Common:=CommonInput;Best^.Reserved:=S^.SegmentType=X_SG_STK;
 if FixedInput Then Begin Best^.Fixed:=True;Best^.AssignedNumber:=Physical End;
 AllocateOutSection:=Best
End;

Function JoinPath(Const PathPart,FilePart:String):String;
Begin
 if PathPart=''Then JoinPath:=FilePart
 else if PathPart[Length(PathPart)]in['\','/',':']Then JoinPath:=PathPart+FilePart
 else JoinPath:=PathPart+'\'+FilePart
End;

Function SearchLibraryPath(Const FileName,PathList:String):String;
Var P,Q:Integer;Part,Candidate:String;
Begin
 P:=1;While P<=Length(PathList)+1 do Begin
  Q:=P;While(Q<=Length(PathList))and(PathList[Q]<>';')do Inc(Q);
  Part:=TrimString(Copy(PathList,P,Q-P));Candidate:=JoinPath(Part,FileName);
  if(Part<>'')and FileExists(Candidate)Then Begin SearchLibraryPath:=Candidate;Exit End;
  P:=Q+1
 End;SearchLibraryPath:=''
End;

Function ResolveLibrary(Const Abbreviation:String):String;
Var Name,Candidate:String;Dir,Base,Ext:String[255];
Begin
 Name:='lib'+Abbreviation+'.a';if FileExists(Name)Then Begin ResolveLibrary:=Name;Exit End;
 Candidate:=SearchLibraryPath(Name,GetEnv('LIB'));
 if Candidate=''Then Candidate:=SearchLibraryPath(Name,GetEnv('LIBRARY'));
 if Candidate=''Then Begin
  FSplit(ParamStr(0),Dir,Base,Ext);Candidate:=JoinPath(JoinPath(Dir,'lib'),Name);
  if not FileExists(Candidate)Then Candidate:=''
 End;
 if Candidate=''Then Begin Candidate:=JoinPath('\lib',Name);if not FileExists(Candidate)Then Candidate:=''End;
 if Candidate=''Then Fatal('bibliotheque introuvable: '+Name);ResolveLibrary:=Candidate
End;

Function ReadBEWordFile(Var F:File;Var Ok:Boolean):Word;
Var
 B:Array[0..1]of Byte;
 N:Word;
Begin
 BlockRead(F,B,2,N);if N<>2 Then Ok:=False;ReadBEWordFile:=Word(B[0])shl 8 or B[1]
End;

Function ReadBELongFile(Var F:File;Var Ok:Boolean):LongInt;
Var
 A,B:Word;
Begin
 A:=ReadBEWordFile(F,Ok);B:=ReadBEWordFile(F,Ok);ReadBELongFile:=LongInt(A)shl 16 or B
End;

Function DefaultSegmentName(SegmentType:Byte;Index:Integer):String;
Var
 N:String;
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

Procedure ReadXOutAt(Const FileName:String;Start,MemberSize:LongInt;Var M:TModule);
Var
 F:File;
 Ok,Segmented:Boolean;
 Magic,NSeg:Word;
 InitSize,RelocSize,SymbolSize,ExpectedSize:LongInt;
 I,J,SegmentIndex,SymbolIndex:Integer;
 Assigned,SegmentType:Byte;
 SegmentLength:Word;
 S,LastS:PObjSection;
 Y,LastY:PObjSymbol;
 T,LastT:PText;
 R,LastR:PReloc;
 InitRead,Left,Chunk,Location:LongInt;
 Flag:Byte;
 Base:Word;
 Name:String;
 Buf:Array[0..248]of Byte;
 N:Word;
Begin
 FillChar(M,SizeOf(M),0);M.FileName:=FileName;Assign(F,FileName);Reset(F,1);
 if IOResult<>0 Then Begin
  Error(FileName,'ouverture impossible');Exit
 End;
 if MemberSize<0 Then MemberSize:=FileSize(F);
 if(Start<0)or(MemberSize<16)or(Start>FileSize(F)-MemberSize)Then Begin
  Close(F);Error(FileName,'limites du membre x.out incorrectes');Exit
 End;
 Seek(F,Start);if IOResult<>0 Then Begin
  Close(F);Error(FileName,'positionnement x.out impossible');Exit
 End;Ok:=True;
 Magic:=ReadBEWordFile(F,Ok);NSeg:=ReadBEWordFile(F,Ok);InitSize:=ReadBELongFile(F,Ok);
 RelocSize:=ReadBELongFile(F,Ok);SymbolSize:=ReadBELongFile(F,Ok);
 if not Ok Then Begin
  Close(F);Error(FileName,'en-tete x.out tronque');Exit
 End;
 Segmented:=(Magic=X_SU_MAGIC)or(Magic=X_SX_MAGIC);
 if not Segmented and not((Magic=X_NU_MAGIC)or(Magic=X_NXN_MAGIC)or
 (Magic=X_NUS_MAGIC)or(Magic=X_NXS_MAGIC)or(Magic=X_NUI_MAGIC)or(Magic=X_NXI_MAGIC))
 Then Begin
  Close(F);Error(FileName,'mot magique x.out inconnu');Exit
 End;
 M.IsExecutable:=(Magic=X_SX_MAGIC)or(Magic=X_NXN_MAGIC)or(Magic=X_NXS_MAGIC)or(Magic=
 X_NXI_MAGIC);
 if M.IsExecutable Then Begin
  Close(F);Error(FileName,'un executable x.out ne peut pas etre relie comme objet');Exit
 End;
 if(RelocSize<0)or(SymbolSize<0)or((RelocSize mod 6)<>0)or((SymbolSize mod 12)<>0)
 Then Begin
  Close(F);Error(FileName,'tailles de tables x.out incorrectes');Exit
 End;
 ExpectedSize:=16+LongInt(NSeg)*4+InitSize+RelocSize+SymbolSize;
 if ExpectedSize<>MemberSize Then Begin
  Close(F);Error(FileName,'taille globale x.out incoherente');Exit
 End;
 M.TargetKnown:=True;M.TargetSegmented:=Segmented;
 if(NSeg=0)or(NSeg>254)Then Begin
  Close(F);Error(FileName,'nombre de segments x.out incorrect');Exit
 End;
 LastS:=Nil;
 For I:=0 to NSeg-1 do Begin
  BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,SegmentType,1,N);
  if N<>1 Then Ok:=False;
  SegmentLength:=ReadBEWordFile(F,Ok);New(S);if S=Nil Then Fatal('memoire pleine');
  FillChar(S^,SizeOf(S^),0);
  if not(SegmentType in[X_SG_BSS,X_SG_STK,X_SG_COD,X_SG_CON,X_SG_DAT,X_SG_MXU,X_SG_MXP])
  Then   Error(FileName,'type de segment x.out inconnu');
  S^.Number:=I+1;S^.AssignedNumber:=Assigned;S^.SegmentType:=SegmentType;
  S^.Size:=SegmentLength;
  S^.IsBss:=SegmentType in[X_SG_BSS,X_SG_STK];S^.Name:=DefaultSegmentName(SegmentType,I);
  if LastS=Nil Then M.Sections:=S else LastS^.Next:=S;LastS:=S
 End;
 if not Ok Then Begin
  Close(F);Error(FileName,'descripteurs x.out tronques');Exit
 End;
 InitRead:=0;LastT:=Nil;S:=M.Sections;
 While S<>Nil do Begin
  if not S^.IsBss Then Begin
   Left:=S^.Size;Location:=0;
   While Left>0 do Begin
    Chunk:=Left;if Chunk>249 Then Chunk:=249;BlockRead(F,Buf,Chunk,N);
    if N<>Chunk Then Begin
     Ok:=False;Break
    End;New(T);if T=Nil Then Fatal('memoire pleine');FillChar(T^,SizeOf(T^),0);
    T^.Section:=S^.Number;T^.Offset:=Location;T^.Count:=Chunk;
    For J:=0 to Chunk-1 do T^.Data[J]:=Buf[J];
    if LastT=Nil Then M.Texts:=T else LastT^.Next:=T;LastT:=T;Inc(Location,Chunk);
    Inc(InitRead,Chunk);Dec(Left,Chunk)
   End
  End;S:=S^.Next
 End;
 if(not Ok)or(InitRead<>InitSize)Then Begin
  Close(F);Error(FileName,'zone initialisee x.out incoherente');Exit
 End;
 { Les relogements x.out sont convertis dans des blocs texte artificiels. }
 For I:=1 to RelocSize div 6 do Begin
  BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,Flag,1,N);
  if N<>1 Then Ok:=False;
  Location:=ReadBEWordFile(F,Ok);Base:=ReadBEWordFile(F,Ok);SegmentIndex:=Assigned+1;
  S:=FindObjSection(M,SegmentIndex);if S=Nil Then Begin
   Error(FileName,'segment de relogement x.out inconnu');Continue
  End;
  T:=M.Texts;
  While(T<>Nil)and not((T^.Section=SegmentIndex)and(Location>=T^.Offset)and(Location<
  T^.Offset+T^.Count))do T:=T^.Next;
  if T=Nil Then Begin
   Error(FileName,'relogement x.out hors des donnees');Continue
  End;
  New(R);if R=Nil Then Fatal('memoire pleine');FillChar(R^,SizeOf(R^),0);
  R^.Offset:=Location-T^.Offset;
  Case Flag of
  X_RL_OFF,X_RL_XOF:
  Begin
   if Segmented Then R^.Action:=RAZOF else R^.Action:=RAA16M;R^.Width:=2
  End;
  X_RL_SSG,X_RL_XSSG:
  Begin
   R^.Action:=RAZSS;R^.Width:=2
  End;
  X_RL_LSG,X_RL_XLSG:
  Begin
   R^.Action:=RAZLS;R^.Width:=4
  End;
  else
  Begin
   Error(FileName,'type de relogement x.out inconnu');R^.Action:=0
  End
 End;
 if Flag in[X_RL_XOF,X_RL_XSSG,X_RL_XLSG]Then R^.Base:=RBEXT+Base else R^.Base:=Base+1;
 LastR:=T^.Relocs;if LastR=Nil Then T^.Relocs:=R else
 Begin
  While LastR^.Next<>Nil do LastR:=LastR^.Next;LastR^.Next:=R
 End
End;
if(RelocSize mod 6)<>0 Then Error(FileName,'taille de relogement x.out incorrecte');
LastY:=Nil;
For SymbolIndex:=0 to SymbolSize div 12-1 do Begin
 BlockRead(F,Assigned,1,N);if N<>1 Then Ok:=False;BlockRead(F,Flag,1,N);
 if N<>1 Then Ok:=False;
 SegmentLength:=ReadBEWordFile(F,Ok);Name:='';
 For J:=1 to 8 do Begin
  BlockRead(F,SegmentType,1,N);if N<>1 Then Ok:=False;
  if SegmentType<>0 Then Name:=Name+Chr(SegmentType)
 End;
 if Flag=X_SY_SEG Then Begin
  S:=FindObjSection(M,Assigned+1);if S<>Nil Then S^.Name:=Name
 End
 else
 Begin
  New(Y);if Y=Nil Then Fatal('memoire pleine');FillChar(Y^,SizeOf(Y^),0);Y^.Name:=Name;
  Y^.Value:=SegmentLength;
  Y^.Global:=Flag in[X_SY_UNX,X_SY_GLB];Y^.Defined:=Flag<>X_SY_UNX;
  if Assigned=255 Then Y^.Section:=0 else Y^.Section:=Assigned+1;
  { X_RL_X* contient l'indice de toute entree de symbole, y compris une
    definition globale deja satisfaite dans un objet produit avec -r. }
  Y^.ExternalBase:=RBEXT+SymbolIndex;
  if LastY=Nil Then M.Symbols:=Y else LastY^.Next:=Y;LastY:=Y
 End
End;
if(SymbolSize mod 12)<>0 Then Error(FileName,'taille de symboles x.out incorrecte');
if not Ok Then Error(FileName,'fichier x.out tronque');Close(F);
if IOResult<>0 Then Error(FileName,'erreur de fermeture')
End;

Procedure ReadXOut(Const FileName:String;Var M:TModule);
Begin
 ReadXOutAt(FileName,0,-1,M)
End;

Procedure ReadObject(Const FileName:String;Var M:TModule);
Var
 F:File;
 B:Array[0..1]of Byte;
 N:Word;
 Magic:Word;
Begin
 Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Begin
  FillChar(M,SizeOf(M),0);M.FileName:=FileName;Error(FileName,'ouverture impossible');Exit
 End;
 BlockRead(F,B,2,N);Close(F);if IOResult<>0 Then Begin
 End;
 if N<>2 Then Begin
  FillChar(M,SizeOf(M),0);M.FileName:=FileName;Error(FileName,'fichier trop court');Exit
 End;
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
 L:PLocalSymbol;
Begin
 S:=M.Sections;
 While S<>Nil do Begin
  if S^.Size>MaxSegmentSize Then Begin
   Error(M.FileName,'segment d''entree superieur a 64 Kio: '+S^.Name);S:=S^.Next;Continue
  End;
  S^.OutputSection:=AllocateOutSection(S);
  if S^.OutputSection^.Common Then Begin
   S^.OutputBase:=0;if S^.Size>S^.OutputSection^.Size Then S^.OutputSection^.Size:=S^.Size
  End else Begin
   if(S^.OutputSection^.Size and 1)<>0 Then Inc(S^.OutputSection^.Size);
   S^.OutputBase:=S^.OutputSection^.Size;
   if S^.Size>MaxSegmentSize-S^.OutputSection^.Size Then
    Error(M.FileName,'debordement du segment de sortie: '+S^.OutputSection^.Name)
   else Inc(S^.OutputSection^.Size,S^.Size)
  End;
  if(S^.IsBss or(Pos('BSS',UpperString(S^.Name))<>0))
  and not S^.HasBytes Then S^.OutputSection^.IsBss:=True;
  S:=S^.Next
 End;
 Y:=M.Symbols;
 While Y<>Nil do Begin
  if Y^.Global and Y^.Defined Then Begin
   if Y^.Section=0 Then Begin
    G:=GetGlobal(Y^.Name);
    if G^.Defined Then Error(M.FileName,'symbole defini plusieurs fois: '+Y^.Name)
    else
    Begin
     G^.Defined:=True;G^.Absolute:=True;G^.Value:=Y^.Value
    End
   End else
   Begin
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
    End
   End
  End else if Y^.Global Then Begin
   G:=GetGlobal(Y^.Name);if Y^.Value>G^.CommonSize Then G^.CommonSize:=Y^.Value
  End else if Y^.Defined Then Begin
   if Y^.Section=0 Then S:=Nil else S:=FindObjSection(M,Y^.Section);
   if(Y^.Section<>0)and(S=Nil)Then
    Error(M.FileName,'symbole local dans un segment inconnu: '+Y^.Name)
   else Begin
    New(L);if L=Nil Then Fatal('memoire pleine');L^.Name:=Y^.Name;
    if S=Nil Then Begin L^.Section:=Nil;L^.Value:=Y^.Value End
    else Begin L^.Section:=S^.OutputSection;L^.Value:=S^.OutputBase+Y^.Value End;
    L^.Next:=Nil;
    if LastLocalSymbol=Nil Then LocalSymbols:=L else LastLocalSymbol^.Next:=L;
    LastLocalSymbol:=L
   End
  End;Y:=Y^.Next
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
      if G=Nil Then Error(M.FileName,'symbole externe absent de la table globale')
      else if Opt.Relocatable Then Begin
       { LD8K -r conserve une reference externe, meme si sa definition est
         deja presente dans ce lien partiel. Le prochain lien la resoudra. }
       NewBase:=G^.ObjectBase
      End
      else if not G^.Defined Then Begin
       if not Opt.Relocatable Then Error(M.FileName,'symbole non defini: '+Y^.Name);
       NewBase:=G^.ObjectBase
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
  if Opt.Relocatable or not G^.Defined Then Begin
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

Function DescriptorType(Const S:String):Byte;
Var U:String;
Begin
 U:=UpperString(S);
 if(U='T')or(U='TEXT')Then DescriptorType:=X_SG_COD
 else if(U='D')or(U='DATA')Then DescriptorType:=X_SG_DAT
 else if(U='B')or(U='BSS')Then DescriptorType:=X_SG_BSS
 else if(U='C')or(U='CONS')or(U='CONST')Then DescriptorType:=X_SG_CON
 else DescriptorType:=0
End;

Function DescriptorNumber(Const S,Context:String):Integer;
Var N,Code:Integer;
Begin
 Val(S,N,Code);if(Code<>0)or(N<0)or(N>126)Then Fatal('description de segment incorrecte ('+
 Context+'): numero 0..126 attendu');DescriptorNumber:=N
End;

Function DefineFixedSegment(Physical,Typ:Byte;Const SuggestedName:String):POutSection;
Var P:POutSection;CodeSpace,OtherCode:Boolean;N:String;
Begin
 CodeSpace:=Opt.SplitID and IsInstructionType(Typ);P:=OutSections;
 While P<>Nil do Begin
  OtherCode:=Opt.SplitID and IsInstructionType(P^.SegmentType);
  if P^.Fixed and(P^.AssignedNumber=Physical)and(CodeSpace=OtherCode)Then Begin
   if not CompatibleSegmentType(P^.SegmentType,Typ)Then
    Fatal('collision de type sur le segment fixe '+SuggestedName);
   if(P^.SegmentType=0)and(Typ<>0)Then P^.SegmentType:=Typ;
   DefineFixedSegment:=P;Exit
  End;P:=P^.Next
 End;
 N:=SuggestedName;if N=''Then Begin Str(Physical,N);N:='__seg'+N End;
 P:=CreateOutSection(N,0,Typ);P^.Fixed:=True;P^.AssignedNumber:=Physical;
 P^.IsBss:=Typ in[X_SG_BSS,X_SG_STK];DefineFixedSegment:=P
End;

Procedure ParseDescriptorLine(Line:String;LineNumber:Integer;Const Origin:String);
Var I,P,Comma,Dash,FirstValue,LastValue,StepValue,N:Integer;Left,Right,Token,TypeToken,
 Name,Context:String;Typ:Byte;S:POutSection;
Begin
 P:=Pos(';',Line);if P<>0 Then Delete(Line,P,Length(Line));P:=Pos('#',Line);
 if P<>0 Then Delete(Line,P,Length(Line));I:=1;
 While I<=Length(Line)do if Line[I]in[' ',#9]Then Delete(Line,I,1)else Inc(I);
 if Line=''Then Exit;Str(LineNumber,Context);Context:=Origin+':'+Context;
 P:=Pos('=',Line);if P=0 Then Fatal('description de segment incorrecte ('+Context+'): = attendu');
 Left:=Copy(Line,1,P-1);Right:=Copy(Line,P+1,Length(Line));
 if(Left='')or(Right='')Then Fatal('description de segment incomplete ('+Context+')');
 if UpCase(Left[1])in['A'..'Z','_']Then Begin
  Typ:=DescriptorType(Left);if Typ=0 Then Fatal('type de segment inconnu ('+Context+'): '+Left);
  While Right<>''do Begin
   Comma:=Pos(',',Right);if Comma=0 Then Begin Token:=Right;Right:=''End
   else Begin Token:=Copy(Right,1,Comma-1);Delete(Right,1,Comma)End;
   Dash:=Pos('-',Token);
   if Dash=0 Then Begin FirstValue:=DescriptorNumber(Token,Context);LastValue:=FirstValue End
   else Begin FirstValue:=DescriptorNumber(Copy(Token,1,Dash-1),Context);
    LastValue:=DescriptorNumber(Copy(Token,Dash+1,Length(Token)),Context)End;
   if FirstValue<=LastValue Then StepValue:=1 else StepValue:=-1;N:=FirstValue;
   Repeat DefineFixedSegment(N,Typ,'');if N=LastValue Then Break;Inc(N,StepValue)Until False
  End
 End else Begin
  Comma:=Pos(',',Left);if Comma=0 Then Begin Token:=Left;TypeToken:=''End
  else Begin Token:=Copy(Left,1,Comma-1);TypeToken:=Copy(Left,Comma+1,Length(Left))End;
  N:=DescriptorNumber(Token,Context);Typ:=0;
  if TypeToken<>''Then Begin Typ:=DescriptorType(TypeToken);
   if Typ=0 Then Fatal('type de segment inconnu ('+Context+'): '+TypeToken)
  End;
  Comma:=Pos(',',Right);if Comma=0 Then Name:=Right else Name:=Copy(Right,1,Comma-1);
  S:=DefineFixedSegment(N,Typ,Name);
  While Right<>''do Begin
   Comma:=Pos(',',Right);if Comma=0 Then Begin Name:=Right;Right:=''End
   else Begin Name:=Copy(Right,1,Comma-1);Delete(Right,1,Comma)End;
   if Name=''Then Fatal('alias de segment vide ('+Context+')');AddSegmentAlias(Name,S)
  End
 End
End;

Procedure ProcessSegmentDescriptions;
Var D:PDescriptor;F:Text;Line:String;LineNumber:Integer;
Begin
 D:=Descriptors;While D<>Nil do Begin
  if D^.FromFile Then Begin
   Assign(F,D^.Text);Reset(F);if IOResult<>0 Then Fatal('lecture impossible du fichier -d: '+D^.Text);
   LineNumber:=1;While not Eof(F)do Begin ReadLn(F,Line);
    if IOResult<>0 Then Fatal('erreur de lecture du fichier -d: '+D^.Text);
    ParseDescriptorLine(Line,LineNumber,D^.Text);Inc(LineNumber)
   End;Close(F);if IOResult<>0 Then Fatal('erreur de fermeture du fichier -d: '+D^.Text)
  End else ParseDescriptorLine(D^.Text,1,'-d');D:=D^.Next
 End
End;

Procedure InitializePreassignedSegments;
Var S:POutSection;
 Procedure AddFixed(Const Name:String;Typ,Physical:Byte);
 Begin S:=CreateOutSection(Name,0,Typ);S^.Fixed:=True;S^.AssignedNumber:=Physical;
  S^.IsBss:=Typ in[X_SG_BSS,X_SG_STK]
 End;
Begin
 if not Opt.Preassign Then Exit;
 AddFixed('_text',X_SG_COD,0);AddFixed('_cons',X_SG_CON,1);
 AddFixed('_data',X_SG_DAT,2);AddFixed('_bss',X_SG_BSS,3)
End;

Procedure AllocateCommonSymbols;
Var G:PGlobal;S:POutSection;Base:LongInt;
Begin
 if Opt.Relocatable Then Exit;G:=Globals;
 While G<>Nil do Begin
  if(not G^.Defined)and(G^.CommonSize>0)Then Begin
   S:=FindOutSection('__common',0);S^.SegmentType:=X_SG_BSS;S^.IsBss:=True;S^.Common:=True;
   if G^.CommonSize>1 Then if(S^.Size and 1)<>0 Then Inc(S^.Size);
   Base:=S^.Size;if G^.CommonSize>MaxSegmentSize-Base Then
    Error(G^.Name,'espace COMMON superieur a 64 Kio')
   else Begin G^.Defined:=True;G^.Section:=S;G^.Value:=Base;Inc(S^.Size,G^.CommonSize)End
  End;G:=G^.Next
 End
End;

Procedure RemoveEmptyAndOrderSections;
Var P,N,FixedFirst,FixedLast,AutoFirst,AutoLast:POutSection;
Begin
 FixedFirst:=Nil;FixedLast:=Nil;AutoFirst:=Nil;AutoLast:=Nil;P:=OutSections;
 While P<>Nil do Begin
  N:=P^.Next;P^.Next:=Nil;
  if(P^.Size=0)and not P^.Reserved Then Dispose(P)
  else if P^.Fixed Then Begin
   if FixedLast=Nil Then FixedFirst:=P else FixedLast^.Next:=P;FixedLast:=P
  End else Begin if AutoLast=Nil Then AutoFirst:=P else AutoLast^.Next:=P;AutoLast:=P End;
  P:=N
 End;
 if FixedLast<>Nil Then FixedLast^.Next:=AutoFirst;
 if FixedFirst<>Nil Then OutSections:=FixedFirst else OutSections:=AutoFirst;
 if AutoLast<>Nil Then LastOutSection:=AutoLast else LastOutSection:=FixedLast
End;

Procedure AssignSegmentNumbers;
Var UsedCode,UsedData:Array[0..126]of Boolean;S:POutSection;N,I:Integer;CodeSpace:Boolean;
Begin
 FillChar(UsedCode,SizeOf(UsedCode),0);FillChar(UsedData,SizeOf(UsedData),0);
 S:=OutSections;While S<>Nil do Begin
  if S^.Fixed Then Begin
   if S^.AssignedNumber>126 Then Fatal('numero fixe Z8001 reserve ou invalide');
   CodeSpace:=Opt.SplitID and IsInstructionType(S^.SegmentType);
   if CodeSpace Then Begin if UsedCode[S^.AssignedNumber]Then Fatal('collision de segments fixes');UsedCode[S^.AssignedNumber]:=True End
   else Begin if UsedData[S^.AssignedNumber]Then Fatal('collision de segments fixes');UsedData[S^.AssignedNumber]:=True End
  End;S:=S^.Next
 End;
 N:=0;S:=OutSections;While S<>Nil do Begin
  if N>127 Then Fatal('x.out ne peut contenir plus de 128 segments');S^.Ordinal:=N;Inc(N);
  if not S^.Fixed Then Begin
   CodeSpace:=Opt.SplitID and IsInstructionType(S^.SegmentType);I:=0;
   if CodeSpace Then Begin While(I<=126)and UsedCode[I]do Inc(I)End
   else Begin While(I<=126)and UsedData[I]do Inc(I)End;
   if I>126 Then Fatal('plus aucun numero de segment Z8001 disponible');S^.AssignedNumber:=I;
   if CodeSpace Then UsedCode[I]:=True else UsedData[I]:=True
  End;
  S:=S^.Next
 End
End;

Procedure ValidateSplitAddressSpaces;
Var
 A,B,T:POutSection;
 R:PReloc;
Begin
 if not Opt.SplitID Then Exit;
 { Un meme numero physique peut designer un segment CODE et un segment DATA,
   mais jamais deux segments appartenant au meme espace d'adressage. }
 A:=OutSections;
 While A<>Nil do Begin
  B:=A^.Next;
  While B<>Nil do Begin
   if SameAddressSpace(A,B)and(A^.AssignedNumber=B^.AssignedNumber)Then
    Fatal('numero de segment duplique dans le meme espace instructions/donnees');
   B:=B^.Next
  End;
  A:=A^.Next
 End;
 { Une reference entre CODE et DATA est licite sur le Z8000. On controle
   cependant sa cible ici: le numero reutilise ne doit jamais servir a
   choisir la cible, qui reste le descripteur logique du fichier objet. }
 R:=Relocations;
 While R<>Nil do Begin
  if R^.Base<RBEXT Then Begin
   T:=OutSections;
   While(T<>Nil)and(T^.Number<>R^.Base)do T:=T^.Next;
   if T=Nil Then Fatal('reference entre espaces vers un segment inconnu');
   if T^.AssignedNumber>126 Then
    Fatal('reference vers un numero de segment Z8001 reserve')
  End;
  R:=R^.Next
 End
End;

Procedure ApplyLayoutOptions;
Var
 S,Stack:POutSection;
 U:String;
 RequestedStack:LongInt;
Begin
 if Opt.ReadOnly and TargetSegmented Then
  Fatal('-n est incompatible avec un chargement segmente Z8001');
 if Opt.ReadOnly and Opt.SplitID Then
  Fatal('-n et -i designent deux organisations memoire incompatibles');
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
 { x.out ne possede pas de champ de pile dans x_hdr. La convention
   historique est un descripteur x_sg de type X_SG_STK. Le chargeur
   Z8002 reserve 256 octets si ce descripteur est absent; un programme
   segmente Z8001 doit au contraire posseder explicitement son segment. }
 Stack:=Nil;S:=OutSections;
 While(S<>Nil)and(Stack=Nil)do Begin
  if S^.SegmentType=X_SG_STK Then Stack:=S else S:=S^.Next
 End;
 RequestedStack:=0;
 if Opt.StackSpecified Then RequestedStack:=Opt.StackSize
 else if TargetSegmented and(Stack=Nil)Then RequestedStack:=DefaultStackSize;
 if RequestedStack>0 Then Begin
  if Stack=Nil Then Stack:=FindOutSection('__stack',0);
  Stack^.IsBss:=True;Stack^.SegmentType:=X_SG_STK;Stack^.Reserved:=True;
  if Stack^.Size>MaxSegmentSize-RequestedStack Then
   Fatal('segment de pile superieur a la limite historique de 64 Kio');
  Inc(Stack^.Size,RequestedStack);
  if(Stack^.Size and 1)<>0 Then Inc(Stack^.Size)
 End;
 RemoveEmptyAndOrderSections;S:=OutSections;
 While S<>Nil do Begin
  if S^.SegmentType=0 Then if S^.IsBss Then S^.SegmentType:=X_SG_STK else S^.SegmentType:=
  X_SG_MXU;
  if S^.Size>$FFFF Then Fatal('segment x.out superieur a 64 Kio: '+S^.Name);
  S:=S^.Next
 End;AssignSegmentNumbers;ValidateSplitAddressSpaces
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
Var
 N:Word;
Begin
 BlockWrite(OutputFile,V,1,N);if N<>1 Then Fatal('erreur d''ecriture x.out')
End;

Procedure RawWord(V:Word);Begin
 RawByte(V shr 8);RawByte(V)
End;

Procedure RawLong(V:LongInt);Begin
 RawWord(Word(LongInt(V)shr 16));RawWord(Word(V))
End;

Function FindOutByNumber(N:Word):POutSection;
Var
 S:POutSection;
Begin
 S:=OutSections;
 While(S<>Nil)and(S^.Number<>N)do S:=S^.Next;FindOutByNumber:=S
End;

Function FindGlobalByBase(N:Word):PGlobal;
Var
 G:PGlobal;
Begin
 G:=Globals;
 While(G<>Nil)and(G^.ObjectBase<>N)do G:=G^.Next;FindGlobalByBase:=G
End;

Function UndefinedGlobals:Boolean;
Var
 G:PGlobal;
Begin
 G:=Globals;
 While G<>Nil do Begin
  if not G^.Defined Then Begin
   UndefinedGlobals:=True;Exit
  End;G:=G^.Next
 End;
 UndefinedGlobals:=False
End;

Procedure PrepareExecutable;
Var
 S,T:POutSection;
 R:PReloc;
 Base,CodeBase,DataBase,V:LongInt;
 DataStarted:Boolean;
Begin
 Base:=0;CodeBase:=0;DataBase:=0;DataStarted:=False;S:=OutSections;
 While S<>Nil do Begin
  if TargetSegmented Then S^.LoadBase:=0
  else if Opt.SplitID Then Begin
   if IsInstructionType(S^.SegmentType)Then Begin
    S^.LoadBase:=CodeBase;Inc(CodeBase,S^.Size)
   End
   else
   Begin
    S^.LoadBase:=DataBase;Inc(DataBase,S^.Size)
   End
  End else
  Begin
   if Opt.ReadOnly Then Begin
    if IsInstructionType(S^.SegmentType)Then Begin
     if DataStarted Then
      Fatal('segment de texte rencontre apres les donnees partageables')
    End else if not DataStarted Then Begin
     if Base>MaxSegmentSize-(SharedBoundary-1)Then
      Fatal('alignement partageable au-dela de 64 Kio');
     Base:=(Base+SharedBoundary-1)and not LongInt(SharedBoundary-1);
     DataStarted:=True
    End
   End;
   S^.LoadBase:=Base;Inc(Base,S^.Size)
  End;
  S:=S^.Next
 End;
 if not TargetSegmented Then Begin
  if Opt.SplitID Then Begin
   if CodeBase>MaxSegmentSize Then Fatal('espace instructions superieur a 64 Kio');
   if DataBase>MaxSegmentSize Then Fatal('espace donnees superieur a 64 Kio')
  End else if Base>MaxSegmentSize Then Fatal('image non segmentee superieure a 64 Kio')
 End;
 R:=Relocations;
 While R<>Nil do Begin
  T:=FindOutByNumber(R^.Base);
  if T=Nil Then Fatal('base de relogement de sortie inconnue');
  if Opt.SplitID and not TargetSegmented Then Begin
   Case R^.Action of
   RAA8:Begin V:=GetImageByte(R^.Section,R^.Offset)+T^.LoadBase;
    if(V<0)or(V>$FF)Then Fatal('reference 8 bits hors de son espace instructions/donnees')
   End;
   RAA16,RAA16M,RAZOF:Begin V:=ReadBE16(R^.Section,R^.Offset)+T^.LoadBase;
    if(V<0)or(V>$FFFF)Then Fatal('reference 16 bits hors de son espace instructions/donnees')
   End
   End
  End;
  if TargetSegmented and(R^.Action=RAZSS)Then   WriteBE16Image(R^.Section,R^.Offset,(
  ReadBE16(R^.Section,R^.Offset)and $80FF)or
  (Word(T^.AssignedNumber and $7F)shl 8))
  else if TargetSegmented and(R^.Action=RAZLS)Then   WriteBE32Image(R^.Section,R^.Offset,(
  ReadBE32(R^.Section,R^.Offset)and LongInt($80FFFFFF))or
  (LongInt(T^.AssignedNumber and $7F)shl 24))
  else ApplyAddend(R^.Section,R^.Offset,R^.Action,T^.LoadBase);
  R:=R^.Next
 End
End;

Procedure AssignXOutSymbolIndices(SegmentCount:Word);
Var
 G:PGlobal;
 N:Word;
Begin
 N:=SegmentCount;G:=Globals;
 While G<>Nil do Begin
  G^.SymbolIndex:=N;Inc(N);G:=G^.Next
 End
End;

Procedure WriteXName(S:String);
Var
 I:Integer;
Begin
 For I:=1 to 8 do if I<=Length(S)Then RawByte(Ord(S[I]))else RawByte(0)
End;

Procedure WriteXOut;
Var
 S:POutSection;
 G:PGlobal;
 L:PLocalSymbol;
 R:PReloc;
 Old:File;
 Backup:String;
 HadOld,Executable:Boolean;
 Magic,SegmentCount,SymbolCount:Word;
 InitSize,RelocSize,SymbolSize:LongInt;
 Flag:Byte;
 Location,FinalSymbolValue:LongInt;
Begin
 { x.out ne contient aucun champ de point d'entree. OBTRA n'est donc pas
   serialise: le demarrage est choisi par le module initial et ses symboles
   publics (_start, startup, etc.), comme dans la chaine CP/M-8000. }
 Executable:=not Opt.Relocatable and not UndefinedGlobals;
 SegmentCount:=0;InitSize:=0;S:=OutSections;
 While S<>Nil do Begin
  Inc(SegmentCount);if not S^.IsBss Then Inc(InitSize,S^.Size);S:=S^.Next
 End;
 AssignXOutSymbolIndices(SegmentCount);
 if Executable Then Begin
  PrepareExecutable;RelocSize:=0
 End
 else
 Begin
  RelocSize:=0;R:=Relocations;
  While R<>Nil do Begin
   Inc(RelocSize,6);R:=R^.Next
  End
 End;
 SymbolCount:=0;if not(Opt.Strip and Executable)Then Begin
  SymbolCount:=SegmentCount;G:=Globals;
  While G<>Nil do Begin
   Inc(SymbolCount);G:=G^.Next
  End;
  L:=LocalSymbols;While L<>Nil do Begin Inc(SymbolCount);L:=L^.Next End
 End;SymbolSize:=LongInt(SymbolCount)*12;
 if TargetSegmented Then if Executable Then Magic:=X_SX_MAGIC else Magic:=X_SU_MAGIC
 else if Opt.SplitID Then if Executable Then Magic:=X_NXI_MAGIC else Magic:=X_NUI_MAGIC
 else if Opt.ReadOnly Then if Executable Then Magic:=X_NXS_MAGIC else Magic:=X_NUS_MAGIC
 else if Executable Then Magic:=X_NXN_MAGIC else Magic:=X_NU_MAGIC;
 TemporaryName:=Opt.OutputName+'.$$$';DeleteQuiet(TemporaryName);
 Assign(OutputFile,TemporaryName);Rewrite(OutputFile,1);
 if IOResult<>0 Then Fatal('creation impossible: '+TemporaryName);OutputOpen:=True;
 RawWord(Magic);RawWord(SegmentCount);RawLong(InitSize);RawLong(RelocSize);
 RawLong(SymbolSize);
 S:=OutSections;
 While S<>Nil do Begin
  if Executable Then RawByte(S^.AssignedNumber)else RawByte(255);
  RawByte(S^.SegmentType);RawWord(Word(S^.Size));S:=S^.Next
 End;
 S:=OutSections;
 While S<>Nil do Begin
  if not S^.IsBss Then Begin
   Location:=0;
   While Location<S^.Size do Begin
    RawByte(GetImageByte(S,Location));Inc(Location)
   End
  End;
  S:=S^.Next
 End;
 if not Executable Then Begin
  R:=Relocations;
  While R<>Nil do Begin
   RawByte(R^.Section^.Ordinal);Location:=R^.Offset;
   Case R^.Action of
   RAA16,RAA16M,RAZOF:Flag:=X_RL_OFF;
   RAA32,RAA32M:
   Begin
    Flag:=X_RL_OFF;Inc(Location,2)
   End;
   RAZSS:Flag:=X_RL_SSG;RAZLS:Flag:=X_RL_LSG;
   else Fatal('relogement non representable dans x.out')
  End;
  if R^.Base>=RBEXT Then Begin
   G:=FindGlobalByBase(R^.Base);
   if G=Nil Then Fatal('symbole externe de relogement inconnu');Inc(Flag,4);
   RawByte(Flag);if Location>$FFFF Then Fatal('position de relogement x.out hors limite');
   RawWord(Location);RawWord(G^.SymbolIndex)
  End else
  Begin
   S:=FindOutByNumber(R^.Base);if S=Nil Then Fatal('segment cible de relogement inconnu');
   RawByte(Flag);
   if Location>$FFFF Then Fatal('position de relogement x.out hors limite');
   RawWord(Location);RawWord(S^.Ordinal)
  End;R:=R^.Next
 End
End;
if SymbolCount<>0 Then Begin
 S:=OutSections;
 While S<>Nil do Begin
  RawByte(S^.Ordinal);RawByte(X_SY_SEG);RawWord(0);WriteXName(S^.Name);S:=S^.Next
 End;
 G:=Globals;
 While G<>Nil do Begin
  if not G^.Defined Then Begin
   RawByte(255);RawByte(X_SY_UNX);
   if Opt.Relocatable Then Begin
    if G^.CommonSize>$FFFF Then Fatal('COMMON x.out hors limite: '+G^.Name);
    RawWord(Word(G^.CommonSize))
   End else RawWord(0)
  End
  else
  Begin
   FinalSymbolValue:=G^.Value;
   if Executable and not TargetSegmented and not G^.Absolute Then
    Inc(FinalSymbolValue,G^.Section^.LoadBase);
   if(FinalSymbolValue<0)or(FinalSymbolValue>$FFFF)Then
    Fatal('valeur de symbole x.out hors limite: '+G^.Name);
   if G^.Absolute Then Begin
    RawByte(255);RawByte(X_SY_GLB);RawWord(Word(FinalSymbolValue))
   End
   else
   Begin
    RawByte(G^.Section^.Ordinal);RawByte(X_SY_GLB);RawWord(Word(FinalSymbolValue))
   End
  End;
  WriteXName(G^.Name);G:=G^.Next
 End;
 L:=LocalSymbols;
 While L<>Nil do Begin
  if(L^.Value<0)or(L^.Value>$FFFF)Then
   Fatal('valeur de symbole local x.out hors limite: '+L^.Name);
  if L^.Section=Nil Then RawByte(255)else RawByte(L^.Section^.Ordinal);
  RawByte(X_SY_LOC);RawWord(Word(L^.Value));
  WriteXName(L^.Name);L:=L^.Next
 End
End;
Close(OutputFile);OutputOpen:=False;if IOResult<>0 Then Fatal('fermeture impossible');
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
End;
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

Function ModuleResolvesNeeded(Var M:TModule):Boolean;
Var Y:PObjSymbol;G:PGlobal;
Begin
 Y:=M.Symbols;While Y<>Nil do Begin
  if Y^.Global and Y^.Defined Then Begin
   G:=FindGlobal(Y^.Name);if(G<>Nil)and not G^.Defined Then Begin
    ModuleResolvesNeeded:=True;Exit
   End
  End;Y:=Y^.Next
 End;ModuleResolvesNeeded:=False
End;

Function AcceptModule(Var M:TModule):Boolean;
Var MN:PModuleNode;
Begin
 AcceptModule:=False;
 if M.TargetKnown Then Begin
  if TargetKnown and(TargetSegmented<>M.TargetSegmented)Then Begin
   Error(M.FileName,'melange de modules Z8001 et Z8002');Exit
  End;
  TargetKnown:=True;TargetSegmented:=M.TargetSegmented
 End;
 LayoutModule(M);if ErrorCount<>0 Then Exit;
 New(MN);if MN=Nil Then Fatal('memoire pleine');MN^.Item:=M;MN^.Next:=Nil;
 if LastModule=Nil Then Modules:=MN else LastModule^.Next:=MN;LastModule:=MN;
 Inc(ModuleCount);FillChar(M,SizeOf(M),0);AcceptModule:=True
End;

Function IsArchiveFile(Const FileName:String):Boolean;
Var F:File;B:Array[0..1]of Byte;N:Word;
Begin
 Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Begin IsArchiveFile:=False;Exit End;
 BlockRead(F,B,2,N);Close(F);if IOResult<>0 Then Begin End;
 IsArchiveFile:=(N=2)and(((B[0]=$FF)and(B[1]=$65))or((B[0]=$65)and(B[1]=$FF)))
End;

Function ArchiveLong(Const H:TBuffer;P:Integer;LittleEndian:Boolean):LongInt;
Begin
 if LittleEndian Then ArchiveLong:=LongInt(H[P])or(LongInt(H[P+1])shl 8)or
  (LongInt(H[P+2])shl 16)or(LongInt(H[P+3])shl 24)
 else ArchiveLong:=(LongInt(H[P])shl 24)or(LongInt(H[P+1])shl 16)or
  (LongInt(H[P+2])shl 8)or H[P+3]
End;

Function ArchiveMemberName(Const H:TBuffer):String;
Var I:Integer;S:String;
Begin S:='';I:=0;While(I<14)and(H[I]<>0)do Begin S:=S+Chr(H[I]);Inc(I)End;
 ArchiveMemberName:=S
End;

Function IsArchiveIndex(Const Name:String):Boolean;
Var U:String;
Begin
 U:=UpperString(Name);IsArchiveIndex:=(U='__.SYMDEF')or(U='__.SYMDEF SORT')or
  (U='/')or(U='/SYM64/')or(U='SYMDEF')
End;

Procedure ProcessArchive(Const FileName:String);
Var F:File;H:TBuffer;B:Array[0..1]of Byte;N:Word;Total,Position,DataPosition,MemberSize:LongInt;
 LittleEndian:Boolean;MemberName,DisplayName:String;M:TModule;BeforeErrors:Integer;
Begin
 Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Begin Error(FileName,'ouverture impossible');Exit End;
 Total:=FileSize(F);BlockRead(F,B,2,N);if(N<>2)or not(((B[0]=$FF)and(B[1]=$65))or
 ((B[0]=$65)and(B[1]=$FF)))Then Begin Close(F);Error(FileName,'magic AR8K incorrect');Exit End;
 LittleEndian:=(B[0]=$65);Position:=2;
 While Position<Total do Begin
  if not UndefinedGlobals Then Break;
  if Position>Total-AR8K_HEADER_SIZE Then Begin Error(FileName,'en-tete de membre AR8K tronque');Break End;
  Seek(F,Position);BlockRead(F,H,AR8K_HEADER_SIZE,N);if N<>AR8K_HEADER_SIZE Then Begin
   Error(FileName,'lecture d''en-tete AR8K impossible');Break
  End;
  MemberName:=ArchiveMemberName(H);if MemberName=''Then Break;
  MemberSize:=ArchiveLong(H,22,LittleEndian);DataPosition:=Position+AR8K_HEADER_SIZE;
  if(MemberSize<0)or(DataPosition>Total-MemberSize)Then Begin
   Error(FileName,'taille de membre AR8K incorrecte: '+MemberName);Break
  End;
  if not IsArchiveIndex(MemberName)Then Begin
   DisplayName:=FileName+'('+MemberName+')';BeforeErrors:=ErrorCount;
   Close(F);if IOResult<>0 Then Begin Error(FileName,'erreur de fermeture temporaire');Break End;
   ReadXOutAt(FileName,DataPosition,MemberSize,M);M.FileName:=DisplayName;
   Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Begin
    Error(FileName,'reouverture de l''archive impossible');FreeModule(M);Exit
   End;
   if ErrorCount=BeforeErrors Then Begin
    { Une archive peut melanger Z8001 et Z8002. Les membres de l'autre cible
      sont ignores, comme dans trysim() du LD8K original. }
    if((not TargetKnown)or(not M.TargetKnown)or(TargetSegmented=M.TargetSegmented))and
    ModuleResolvesNeeded(M)Then Begin
     if not AcceptModule(M)Then FreeModule(M)
    End else FreeModule(M)
   End else Begin FreeModule(M);Break End
  End;
  Position:=DataPosition+MemberSize;if(Position and 1)<>0 Then Inc(Position)
 End;
 Close(F);if IOResult<>0 Then Error(FileName,'erreur de fermeture de l''archive')
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
 MN,MNext:PModuleNode;
 M:TModule;

BEGIN
 Inputs:=Nil;LastInput:=Nil;ForcedUndefined:=Nil;LastForced:=Nil;OutSections:=Nil;
 Descriptors:=Nil;LastDescriptor:=Nil;SegmentAliases:=Nil;
 LastOutSection:=Nil;
 Globals:=Nil;LocalSymbols:=Nil;LastLocalSymbol:=Nil;
 Relocations:=Nil;LastRelocation:=Nil;ErrorCount:=0;
 NextSectionNumber:=1;OutputOpen:=False;TemporaryName:='';ModuleCount:=0;Modules:=Nil;
 LastModule:=Nil;
 HasTransfer:=False;TransferValue:=0;TransferBase:=0;
 TargetKnown:=False;TargetSegmented:=False;
 ParseCommandLine;InitializePreassignedSegments;ProcessSegmentDescriptions;
 AddForcedUndefined;P:=Inputs;
 While P<>Nil do Begin
  if IsArchiveFile(P^.Name)Then ProcessArchive(P^.Name)
  else Begin
   ReadObject(P^.Name,M);
   if ErrorCount=0 Then Begin if not AcceptModule(M)Then FreeModule(M)End
   else FreeModule(M)
  End;
  if ErrorCount<>0 Then Break;P:=P^.Next
 End;
 AllocateCommonSymbols;ApplyLayoutOptions;
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
