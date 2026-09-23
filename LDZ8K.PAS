{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Editeur de liens UNIDOT Z8000 compatible avec la chaine CP/M-8000.
 @license: MIT }

Program LDZ8K;

{$A-,B-,I-,R-,S-}
{$IFDEF FPC}{$H+}{$ENDIF}

Uses Dos;

Const
 Version='1.0';
 OBOST=1;OBLST=2;OBSEC=3;OBGLO=4;OBLOC=5;OBTXT=6;OBBSZ=7;
 OBTRA=8;OBLIX=9;OBLND=10;OBOND=11;OBMOD=12;
 RAA16=$8000;RAA8=$4000;RAA32=$C000;RAA16M=$2000;RAA32M=$A000;
 RAZSS=$6000;RAZLS=$E000;RASEG=$1000;RAOFF=$9000;RAZOF=$3000;
 RAMSK=$F000;RBUND=255;RBEXT=256;RBMSK=$0FFF;
 MaxErrors=100;

Type
 TBuffer=Array[0..254]of Byte;
 PInput=^TInput;
 TInput=Record Name:String;Next:PInput End;
 PImage=^TImage;
 TImage=Record Index:LongInt;Data:Array[0..4095]of Byte;Next:PImage End;
 POutSection=^TOutSection;
 TOutSection=Record
  Number,Attributes:Byte;Name:String;Size:LongInt;IsBss:Boolean;
  FirstImage,LastImage:PImage;Next:POutSection
 End;
 PObjSection=^TObjSection;
 TObjSection=Record
  Number,Attributes:Byte;Name:String;Size,OutputBase:LongInt;IsBss,HasBytes:Boolean;
  OutputSection:POutSection;Next:PObjSection
 End;
 PGlobal=^TGlobal;
 TGlobal=Record
  Name:String;Defined:Boolean;Section:POutSection;Value:LongInt;
  ObjectBase:Word;Next:PGlobal
 End;
 PObjSymbol=^TObjSymbol;
 TObjSymbol=Record
  Name:String;Defined,Global:Boolean;Section:Byte;Value:LongInt;ExternalBase:Word;
  Next:PObjSymbol
 End;
 PReloc=^TReloc;
 TReloc=Record
  Section:POutSection;Offset:LongInt;Action,Base:Word;Width:Byte;Next:PReloc
 End;
 PText=^TText;
 TText=Record
  Section:Byte;Offset:LongInt;Count:Byte;Data:Array[0..248]of Byte;
  Relocs:PReloc;Next:PText
 End;
 TModule=Record
  Name,FileName:String;Sections:PObjSection;Symbols:PObjSymbol;Texts:PText;
  HasTransfer:Boolean;TransferValue:LongInt;TransferBase:Word
 End;
 PModuleNode=^TModuleNode;
 TModuleNode=Record Item:TModule;Next:PModuleNode End;
 TOptions=Record
  OutputName:String;Relocatable,Strip,SplitID,ReadOnly:Boolean;StackSize:LongInt
 End;

Var
 Opt:TOptions;Inputs,LastInput:PInput;OutSections,LastOutSection:POutSection;
 Globals:PGlobal;Relocations,LastRelocation:PReloc;
 ErrorCount:Integer;NextSectionNumber:Integer;
 OutputFile:File;OutputOpen:Boolean;TemporaryName:String;
 ForcedUndefined,LastForced:PInput;
 HasTransfer:Boolean;TransferValue:LongInt;TransferBase:Word;

Function UpperString(S:String):String;
Var I:Integer;
Begin For I:=1 to Length(S)do S[I]:=UpCase(S[I]);UpperString:=S End;

Function TrimString(S:String):String;
Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 TrimString:=S
End;

Function Extension(S:String):String;
Var I:Integer;
Begin
 Extension:='';For I:=Length(S)downto 1 do if S[I]='.'Then Begin
  Extension:=UpperString(Copy(S,I,Length(S)));Exit
 End else if S[I]in['\','/',':']Then Exit
End;

Function BaseName(S:String):String;
Var I:Integer;
Begin
 For I:=Length(S)downto 1 do if S[I]='.'Then Begin Delete(S,I,Length(S));Break End
 else if S[I]in['\','/',':']Then Break;BaseName:=S
End;

Function FileExists(Const Name:String):Boolean;
Var F:File;Ok:Boolean;
Begin Assign(F,Name);Reset(F,1);Ok:=IOResult=0;if Ok Then Begin Close(F);if IOResult<>0 Then Begin End End;FileExists:=Ok End;

Procedure DeleteQuiet(Const Name:String);
Var F:File;
Begin if Name=''Then Exit;Assign(F,Name);Erase(F);if IOResult<>0 Then Begin End End;

Procedure Fatal(Const S:String);
Begin
 if OutputOpen Then Begin Close(OutputFile);if IOResult<>0 Then Begin End;OutputOpen:=False End;
 DeleteQuiet(TemporaryName);WriteLn('LDZ8K: erreur fatale: ',S);Halt(1)
End;

Procedure Error(Const FileName,S:String);
Begin
 Inc(ErrorCount);WriteLn('LDZ8K: ',FileName,': erreur: ',S);
 if ErrorCount>=MaxErrors Then Fatal('trop d''erreurs')
End;

Procedure Usage;
Begin
 WriteLn('LDZ8K ',Version,' - Cette commande permet de lancer l''',#130,
         'diteur de liens Z8000 UNIDOT pour CP/M-8000');
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
 WriteLn('  Les fichiers sans extension recoivent .OBJ.')
End;

Procedure AddInput(Const Name:String;Var First,Last:PInput);
Var P:PInput;
Begin New(P);if P=Nil Then Fatal('memoire pleine');P^.Name:=Name;P^.Next:=Nil;
 if Last=Nil Then First:=P else Last^.Next:=P;Last:=P End;

Procedure ParseCommandLine;
Var I,Code:Integer;S,U:String;
Begin
 FillChar(Opt,SizeOf(Opt),0);Opt.OutputName:='x.out';I:=1;
 While I<=ParamCount do Begin
  S:=ParamStr(I);U:=UpperString(S);
  if(U='/?')or(U='-?')or(U='--HELP')Then Begin Usage;Halt(0) End
  else if U='-O'Then Begin Inc(I);if I>ParamCount Then Fatal('-o exige un fichier');Opt.OutputName:=ParamStr(I) End
  else if U='-R'Then Opt.Relocatable:=True
  else if U='-S'Then Opt.Strip:=True
  else if U='-I'Then Opt.SplitID:=True
  else if U='-N'Then Opt.ReadOnly:=True
  else if U='-T'Then Begin Inc(I);if I>ParamCount Then Fatal('-t exige une taille');Val(ParamStr(I),Opt.StackSize,Code);if Code<>0 Then Fatal('taille de pile incorrecte') End
  else if U='-U'Then Begin Inc(I);if I>ParamCount Then Fatal('-u exige un symbole');AddInput(ParamStr(I),ForcedUndefined,LastForced) End
  else if(S<>'')and(S[1]='-')Then Fatal('option inconnue: '+S)
  else Begin if Extension(S)=''Then S:=S+'.OBJ';AddInput(S,Inputs,LastInput) End;
  Inc(I)
 End;
 if Inputs=Nil Then Begin Usage;Halt(1) End
End;

Function ReadByte(Var F:File;Var Position:LongInt;Limit:LongInt;Var Ok:Boolean):Byte;
Var B:Byte;N:Word;
Begin
 if Position>=Limit Then Begin Ok:=False;ReadByte:=0;Exit End;
 BlockRead(F,B,1,N);if N<>1 Then Ok:=False else Inc(Position);ReadByte:=B
End;

Function LE16(Const B:TBuffer;P:Integer):Word;
Begin LE16:=Word(B[P])or(Word(B[P+1])shl 8) End;

Function LE32(Const B:TBuffer;P:Integer):LongInt;
Begin LE32:=LongInt(B[P])or(LongInt(B[P+1])shl 8)or(LongInt(B[P+2])shl 16)or(LongInt(B[P+3])shl 24) End;

Function GetName(Const B:TBuffer;Var P:Integer;Limit:Integer):String;
Var S:String;
Begin
 S:='';While(P<Limit)and(B[P]<>0)do Begin S:=S+Chr(B[P]);Inc(P) End;
 if P<Limit Then Inc(P);GetName:=S
End;

Function FindObjSection(Var M:TModule;Number:Byte):PObjSection;
Var P:PObjSection;
Begin P:=M.Sections;While(P<>Nil)and(P^.Number<>Number)do P:=P^.Next;FindObjSection:=P End;

Function FindOutSection(Const Name:String;Attributes:Byte):POutSection;
Var P:POutSection;U:String;
Begin
 U:=UpperString(Name);P:=OutSections;While P<>Nil do Begin
  if UpperString(P^.Name)=U Then Begin FindOutSection:=P;Exit End;P:=P^.Next
 End;
 New(P);if P=Nil Then Fatal('memoire pleine');FillChar(P^,SizeOf(P^),0);
 if NextSectionNumber>=RBUND Then Fatal('trop de segments');P^.Number:=NextSectionNumber;Inc(NextSectionNumber);
 P^.Name:=Name;P^.Attributes:=Attributes;
 if LastOutSection=Nil Then OutSections:=P else LastOutSection^.Next:=P;LastOutSection:=P;
 FindOutSection:=P
End;

Function FindGlobal(Const Name:String):PGlobal;
Var P:PGlobal;U:String;
Begin U:=UpperString(Name);P:=Globals;While(P<>Nil)and(UpperString(P^.Name)<>U)do P:=P^.Next;FindGlobal:=P End;

Function GetGlobal(Const Name:String):PGlobal;
Var P:PGlobal;
Begin
 P:=FindGlobal(Name);if P=Nil Then Begin New(P);if P=Nil Then Fatal('memoire pleine');
  FillChar(P^,SizeOf(P^),0);P^.Name:=Name;P^.Next:=Globals;Globals:=P
 End;GetGlobal:=P
End;

Procedure PutImageByte(S:POutSection;Offset:LongInt;Value:Byte);
Var P,N:PImage;Index:LongInt;
Begin
 Index:=Offset div 4096;P:=S^.FirstImage;While(P<>Nil)and(P^.Index<>Index)do P:=P^.Next;
 if P=Nil Then Begin New(N);if N=Nil Then Fatal('memoire pleine');FillChar(N^,SizeOf(N^),0);N^.Index:=Index;
  if S^.LastImage=Nil Then S^.FirstImage:=N else S^.LastImage^.Next:=N;S^.LastImage:=N;P:=N
 End;P^.Data[Offset mod 4096]:=Value;if Offset>=S^.Size Then S^.Size:=Offset+1
End;

Function GetImageByte(S:POutSection;Offset:LongInt):Byte;
Var P:PImage;
Begin
 P:=S^.FirstImage;While(P<>Nil)and(P^.Index<>Offset div 4096)do P:=P^.Next;
 if P=Nil Then GetImageByte:=0 else GetImageByte:=P^.Data[Offset mod 4096]
End;

Procedure AddOutputRelocation(S:POutSection;Offset:LongInt;Action,Base:Word;Width:Byte);
Var R:PReloc;
Begin
 New(R);if R=Nil Then Fatal('memoire pleine');R^.Section:=S;R^.Offset:=Offset;R^.Action:=Action;
 R^.Base:=Base;R^.Width:=Width;R^.Next:=Nil;
 if LastRelocation=Nil Then Relocations:=R else LastRelocation^.Next:=R;LastRelocation:=R
End;

Procedure ReadObject(Const FileName:String;Var M:TModule);
Var F:File;Total,Position:LongInt;Kind,Len:Byte;B:TBuffer;N:Word;P,I:Integer;
 Ok:Boolean;S:PObjSection;Y:PObjSymbol;T:PText;LastS:PObjSection;LastY:PObjSymbol;LastT:PText;
 R,LastR:PReloc;ExternalNumber:Word;
Begin
 FillChar(M,SizeOf(M),0);M.FileName:=FileName;Assign(F,FileName);Reset(F,1);
 if IOResult<>0 Then Begin Error(FileName,'ouverture impossible');Exit End;
 Total:=FileSize(F);Position:=0;Ok:=True;LastS:=Nil;LastY:=Nil;LastT:=Nil;ExternalNumber:=RBEXT;
 While(Position<Total)and Ok do Begin
  Kind:=ReadByte(F,Position,Total,Ok);Len:=ReadByte(F,Position,Total,Ok);
  if not Ok or(Position+Len>Total)Then Begin Error(FileName,'bloc UNIDOT tronque');Break End;
  if Len<>0 Then Begin BlockRead(F,B,Len,N);if N<>Len Then Ok:=False;Inc(Position,Len) End;
  if not Ok Then Begin Error(FileName,'erreur de lecture');Break End;
  Case Kind of
   OBMOD:Begin P:=0;M.Name:=GetName(B,P,Len) End;
   OBSEC:Begin
    P:=0;While P<Len do Begin
     if P+3>Len Then Begin Error(FileName,'descripteur de segment tronque');Break End;
     New(S);if S=Nil Then Fatal('memoire pleine');FillChar(S^,SizeOf(S^),0);
     S^.Number:=B[P];S^.Attributes:=B[P+1];Inc(P,3);S^.Name:=GetName(B,P,Len);
     if S^.Name=''Then Begin Error(FileName,'nom de segment vide');Dispose(S);Break End;
     if LastS=Nil Then M.Sections:=S else LastS^.Next:=S;LastS:=S
    End
   End;
   OBGLO,OBLOC:Begin
    P:=0;While P<Len do Begin
     if P+6>Len Then Begin Error(FileName,'symbole tronque');Break End;
     New(Y);if Y=Nil Then Fatal('memoire pleine');FillChar(Y^,SizeOf(Y^),0);
     Y^.Value:=LE32(B,P);Y^.Section:=B[P+4];Inc(P,5);Y^.Name:=GetName(B,P,Len);Y^.Global:=Kind=OBGLO;
     Y^.Defined:=Y^.Section<>RBUND;if(not Y^.Defined)and(Kind=OBGLO)Then Begin
      Y^.ExternalBase:=ExternalNumber;Inc(ExternalNumber)
     End;
     if LastY=Nil Then M.Symbols:=Y else LastY^.Next:=Y;LastY:=Y
    End
   End;
   OBTXT:Begin
    if Len<6 Then Error(FileName,'bloc texte trop court')else Begin
     New(T);if T=Nil Then Fatal('memoire pleine');FillChar(T^,SizeOf(T^),0);
     T^.Offset:=LE32(B,0);T^.Section:=B[4];T^.Count:=B[5];
     if 6+T^.Count>Len Then Begin Error(FileName,'taille de texte incorrecte');Dispose(T) End else Begin
      For I:=0 to T^.Count-1 do T^.Data[I]:=B[6+I];P:=6+T^.Count;LastR:=Nil;
      While P<Len do Begin
       if P+3>Len Then Begin Error(FileName,'relogement tronque');Break End;
       New(R);if R=Nil Then Fatal('memoire pleine');FillChar(R^,SizeOf(R^),0);
       R^.Offset:=B[P]-6;R^.Action:=LE16(B,P+1)and RAMSK;R^.Base:=LE16(B,P+1)and RBMSK;
       Case R^.Action of RAA8:R^.Width:=1;RAA32,RAA32M,RAZLS:R^.Width:=4;else R^.Width:=2 End;
       if(R^.Offset<0)or(R^.Offset+R^.Width>T^.Count)Then Error(FileName,'relogement hors du bloc');
       if LastR=Nil Then T^.Relocs:=R else LastR^.Next:=R;LastR:=R;Inc(P,3)
      End;
      if LastT=Nil Then M.Texts:=T else LastT^.Next:=T;LastT:=T;
      S:=FindObjSection(M,T^.Section);if S=Nil Then Error(FileName,'segment de texte inconnu')
      else Begin
       if T^.Count<>0 Then S^.HasBytes:=True else if T^.Offset<>0 Then S^.IsBss:=True;
       if T^.Offset+T^.Count>S^.Size Then S^.Size:=T^.Offset+T^.Count
      End
     End
    End
   End;
   OBTRA:if Len>=6 Then Begin M.HasTransfer:=True;M.TransferValue:=LE32(B,0);M.TransferBase:=LE16(B,4) End;
   OBOST,OBOND:;
   else Error(FileName,'type de bloc UNIDOT inconnu')
  End
 End;Close(F);if IOResult<>0 Then Error(FileName,'erreur de fermeture')
End;

Procedure LayoutModule(Var M:TModule);
Var S:PObjSection;Y:PObjSymbol;G:PGlobal;
Begin
 S:=M.Sections;While S<>Nil do Begin
  S^.OutputSection:=FindOutSection(S^.Name,S^.Attributes);S^.OutputBase:=S^.OutputSection^.Size;
  if(S^.IsBss or(Pos('BSS',UpperString(S^.Name))<>0))and not S^.HasBytes Then S^.OutputSection^.IsBss:=True;
  if S^.Size>2147483647-S^.OutputSection^.Size Then Fatal('segment de sortie trop grand');
  Inc(S^.OutputSection^.Size,S^.Size);S:=S^.Next
 End;
 Y:=M.Symbols;While Y<>Nil do Begin
  if Y^.Global and Y^.Defined Then Begin
   S:=FindObjSection(M,Y^.Section);if S=Nil Then Error(M.FileName,'symbole dans un segment inconnu: '+Y^.Name)
   else Begin G:=GetGlobal(Y^.Name);
    if G^.Defined Then Error(M.FileName,'symbole defini plusieurs fois: '+Y^.Name)
    else Begin G^.Defined:=True;G^.Section:=S^.OutputSection;G^.Value:=S^.OutputBase+Y^.Value End
   End
  End else if Y^.Global Then GetGlobal(Y^.Name);Y:=Y^.Next
 End;
 if M.HasTransfer and not HasTransfer Then Begin
  S:=FindObjSection(M,Byte(M.TransferBase));
  if S=Nil Then Error(M.FileName,'base du point d''entree inconnue')else Begin
   HasTransfer:=True;TransferValue:=S^.OutputBase+M.TransferValue;TransferBase:=S^.OutputSection^.Number
  End
 End
End;

Function FindExternalSymbol(Var M:TModule;Base:Word):PObjSymbol;
Var P:PObjSymbol;
Begin P:=M.Symbols;While(P<>Nil)and(P^.ExternalBase<>Base)do P:=P^.Next;FindExternalSymbol:=P End;

Function ReadBE16(S:POutSection;O:LongInt):Word;
Begin ReadBE16:=Word(GetImageByte(S,O))shl 8 or GetImageByte(S,O+1) End;

Function ReadBE32(S:POutSection;O:LongInt):LongInt;
Begin ReadBE32:=LongInt(ReadBE16(S,O))shl 16 or ReadBE16(S,O+2) End;

Procedure WriteBE16Image(S:POutSection;O:LongInt;V:Word);
Begin PutImageByte(S,O,V shr 8);PutImageByte(S,O+1,V) End;

Procedure WriteBE32Image(S:POutSection;O:LongInt;V:LongInt);
Begin WriteBE16Image(S,O,Word(LongInt(V)shr 16));WriteBE16Image(S,O+2,Word(V)) End;

Procedure ApplyAddend(S:POutSection;O:LongInt;Action:Word;Addend:LongInt);
Var V:LongInt;W:Word;
Begin
 Case Action of
  RAA8:PutImageByte(S,O,Byte(GetImageByte(S,O)+Addend));
  RAA16,RAA16M,RAZOF:Begin W:=ReadBE16(S,O);WriteBE16Image(S,O,Word(W+Addend)) End;
  RAA32,RAA32M:Begin V:=ReadBE32(S,O);WriteBE32Image(S,O,V+Addend) End;
  RAZSS:Begin W:=ReadBE16(S,O);W:=(W and $FF00)or Word((W+Addend)and $FF);WriteBE16Image(S,O,W) End;
  RAZLS:Begin V:=ReadBE32(S,O);V:=(V and LongInt($FFFF0000))or((V+Addend)and $FFFF);WriteBE32Image(S,O,V) End
 End
End;

Procedure CopyAndRelocateModule(Var M:TModule);
Var T:PText;S,Target:PObjSection;R:PReloc;Y:PObjSymbol;G:PGlobal;I:Integer;
 OutOffset,Addend:LongInt;NewBase:Word;
Begin
 T:=M.Texts;While T<>Nil do Begin
  S:=FindObjSection(M,T^.Section);if S<>Nil Then Begin
   OutOffset:=S^.OutputBase+T^.Offset;
   For I:=0 to T^.Count-1 do PutImageByte(S^.OutputSection,OutOffset+I,T^.Data[I]);
   R:=T^.Relocs;While R<>Nil do Begin
    Addend:=0;NewBase:=0;
    if R^.Base>=RBEXT Then Begin
     Y:=FindExternalSymbol(M,R^.Base);
     if Y=Nil Then Error(M.FileName,'indice externe inconnu')else Begin
      G:=FindGlobal(Y^.Name);
      if(G=Nil)or not G^.Defined Then Begin
       if not Opt.Relocatable Then Error(M.FileName,'symbole non defini: '+Y^.Name);
       if G<>Nil Then NewBase:=G^.ObjectBase
      End else Begin Addend:=G^.Value;NewBase:=G^.Section^.Number End
     End
    End else if R^.Base<>0 Then Begin
     Target:=FindObjSection(M,Byte(R^.Base));if Target=Nil Then Error(M.FileName,'base de relogement inconnue')
     else Begin Addend:=Target^.OutputBase;NewBase:=Target^.OutputSection^.Number End
    End;
    ApplyAddend(S^.OutputSection,OutOffset+R^.Offset,R^.Action,Addend);
    if NewBase<>0 Then AddOutputRelocation(S^.OutputSection,OutOffset+R^.Offset,R^.Action,NewBase,R^.Width);
    R:=R^.Next
   End
  End;T:=T^.Next
 End
End;

Procedure AssignExternalBases;
Var G:PGlobal;N:Word;
Begin
 N:=RBEXT;G:=Globals;While G<>Nil do Begin
  if not G^.Defined Then Begin G^.ObjectBase:=N;Inc(N);if N>=RBMSK Then Fatal('trop de symboles externes') End;
  G:=G^.Next
 End;
 if Opt.Strip Then Begin
  G:=Globals;While G<>Nil do Begin
   if not G^.Defined Then Fatal('-s ne peut pas supprimer une table externe encore necessaire');G:=G^.Next
  End
 End
End;

Procedure ApplyLayoutOptions;
Var S,Stack:POutSection;U:String;
Begin
 S:=OutSections;While S<>Nil do Begin
  U:=UpperString(S^.Name);
  if Opt.ReadOnly and((U='__TEXT')or(Pos('TEXT',U)<>0))Then S^.Attributes:=S^.Attributes or 2;
  S:=S^.Next
 End;
 if Opt.StackSize>0 Then Begin
  Stack:=FindOutSection('__stack',0);Stack^.IsBss:=True;
  if Stack^.Size<Opt.StackSize Then Stack^.Size:=Opt.StackSize
 End
End;

Procedure PutLE16(Var B:TBuffer;Var N:Integer;V:Word);
Begin B[N]:=V;B[N+1]:=V shr 8;Inc(N,2) End;

Procedure PutLE32(Var B:TBuffer;Var N:Integer;V:LongInt);
Begin PutLE16(B,N,Word(V));PutLE16(B,N,Word(LongInt(V)shr 16)) End;

Procedure PutName(Var B:TBuffer;Var N:Integer;S:String);
Var I,L:Integer;
Begin L:=Length(S);if L>8 Then L:=8;For I:=1 to L do Begin B[N]:=Ord(S[I]);Inc(N) End;B[N]:=0;Inc(N) End;

Procedure WriteBlock(Kind:Byte;Var B:TBuffer;N:Integer);
Var W:Word;L:Byte;
Begin
 L:=N;BlockWrite(OutputFile,Kind,1,W);if W<>1 Then Fatal('erreur d''ecriture');
 BlockWrite(OutputFile,L,1,W);if W<>1 Then Fatal('erreur d''ecriture');
 if N<>0 Then Begin BlockWrite(OutputFile,B,N,W);if W<>N Then Fatal('erreur d''ecriture') End
End;

Procedure WriteSections;
Var B:TBuffer;N,Need:Integer;S:POutSection;
Begin
 N:=0;S:=OutSections;While S<>Nil do Begin Need:=4+Length(S^.Name);if Need>12 Then Need:=12;
  if N+Need>255 Then Begin WriteBlock(OBSEC,B,N);N:=0 End;
  B[N]:=S^.Number;B[N+1]:=S^.Attributes;B[N+2]:=0;Inc(N,3);PutName(B,N,S^.Name);S:=S^.Next
 End;if N<>0 Then WriteBlock(OBSEC,B,N)
End;

Procedure WriteGlobals;
Var B:TBuffer;N,Need:Integer;G:PGlobal;
Begin
 if Opt.Strip Then Exit;N:=0;G:=Globals;While G<>Nil do Begin Need:=6+Length(G^.Name);if Need>14 Then Need:=14;
  if N+Need>255 Then Begin WriteBlock(OBGLO,B,N);N:=0 End;
  if G^.Defined Then Begin PutLE32(B,N,G^.Value);B[N]:=G^.Section^.Number End
  else Begin PutLE32(B,N,0);B[N]:=RBUND End;Inc(N);PutName(B,N,G^.Name);G:=G^.Next
 End;if N<>0 Then WriteBlock(OBGLO,B,N)
End;

Procedure WriteText(S:POutSection);
Var B:TBuffer;Position:LongInt;Chunk,N,Count,I:Integer;R:PReloc;
Begin
 Position:=0;While Position<S^.Size do Begin Chunk:=S^.Size-Position;if Chunk>249 Then Chunk:=249;
  Repeat
   Count:=0;R:=Relocations;While R<>Nil do Begin
    if(R^.Section=S)and(R^.Offset>=Position)and(R^.Offset<Position+Chunk)Then Begin
     Inc(Count);if R^.Offset+R^.Width>Position+Chunk Then Chunk:=R^.Offset-Position
    End;R:=R^.Next
   End;
   if 6+Chunk+3*Count>255 Then Dec(Chunk)else Break
  Until Chunk=0;
  if Chunk<=0 Then Fatal('relogement trop grand');N:=0;PutLE32(B,N,Position);B[N]:=S^.Number;Inc(N);B[N]:=Chunk;Inc(N);
  For I:=0 to Chunk-1 do Begin B[N]:=GetImageByte(S,Position+I);Inc(N) End;
  R:=Relocations;While R<>Nil do Begin
   if(R^.Section=S)and(R^.Offset>=Position)and(R^.Offset<Position+Chunk)Then Begin
    B[N]:=6+R^.Offset-Position;Inc(N);PutLE16(B,N,R^.Action or(R^.Base and RBMSK))
   End;R:=R^.Next
  End;WriteBlock(OBTXT,B,N);Inc(Position,Chunk)
 End
End;

Procedure WriteOutput;
Var B:TBuffer;N:Integer;S:POutSection;Old:File;Backup:String;HadOld:Boolean;
Begin
 TemporaryName:=Opt.OutputName+'.$$$';DeleteQuiet(TemporaryName);Assign(OutputFile,TemporaryName);Rewrite(OutputFile,1);
 if IOResult<>0 Then Fatal('creation impossible: '+TemporaryName);OutputOpen:=True;
 N:=0;WriteBlock(OBOST,B,N);N:=0;PutName(B,N,'LDZ8K');WriteBlock(OBMOD,B,N);
 WriteSections;WriteGlobals;S:=OutSections;While S<>Nil do Begin
  if S^.IsBss Then Begin N:=0;PutLE32(B,N,S^.Size);B[N]:=S^.Number;Inc(N);B[N]:=0;Inc(N);WriteBlock(OBTXT,B,N) End
  else WriteText(S);S:=S^.Next
 End;
 if HasTransfer Then Begin N:=0;PutLE32(B,N,TransferValue);PutLE16(B,N,TransferBase);WriteBlock(OBTRA,B,N) End;
 N:=0;WriteBlock(OBOND,B,N);Close(OutputFile);OutputOpen:=False;if IOResult<>0 Then Fatal('fermeture impossible');
 Backup:=Opt.OutputName+'.$OLD';DeleteQuiet(Backup);HadOld:=FileExists(Opt.OutputName);
 if HadOld Then Begin Assign(Old,Opt.OutputName);Rename(Old,Backup);if IOResult<>0 Then Fatal('sauvegarde de l''ancienne sortie impossible') End;
 Assign(OutputFile,TemporaryName);Rename(OutputFile,Opt.OutputName);if IOResult<>0 Then Begin
  if HadOld Then Begin Assign(Old,Backup);Rename(Old,Opt.OutputName);if IOResult<>0 Then Begin End End;
  Fatal('installation de la sortie impossible')
 End;if HadOld Then DeleteQuiet(Backup);TemporaryName:=''
End;

Procedure FreeModule(Var M:TModule);
Var S,SN:PObjSection;Y,YN:PObjSymbol;T,TN:PText;R,RN:PReloc;
Begin
 S:=M.Sections;While S<>Nil do Begin SN:=S^.Next;Dispose(S);S:=SN End;
 Y:=M.Symbols;While Y<>Nil do Begin YN:=Y^.Next;Dispose(Y);Y:=YN End;
 T:=M.Texts;While T<>Nil do Begin TN:=T^.Next;R:=T^.Relocs;While R<>Nil do Begin RN:=R^.Next;Dispose(R);R:=RN End;Dispose(T);T:=TN End
End;

Procedure AddForcedUndefined;
Var P:PInput;
Begin P:=ForcedUndefined;While P<>Nil do Begin GetGlobal(P^.Name);P:=P^.Next End End;

Var P:PInput;Modules,LastModule,MN,MNext:PModuleNode;ModuleCount:LongInt;

BEGIN
 Inputs:=Nil;LastInput:=Nil;ForcedUndefined:=Nil;LastForced:=Nil;OutSections:=Nil;LastOutSection:=Nil;
 Globals:=Nil;Relocations:=Nil;LastRelocation:=Nil;ErrorCount:=0;
 NextSectionNumber:=1;OutputOpen:=False;TemporaryName:='';ModuleCount:=0;Modules:=Nil;LastModule:=Nil;
 HasTransfer:=False;TransferValue:=0;TransferBase:=0;
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
 MN:=Modules;While(MN<>Nil)and(ErrorCount=0)do Begin CopyAndRelocateModule(MN^.Item);MN:=MN^.Next End;
 if(ErrorCount=0)Then WriteOutput;
 MN:=Modules;While MN<>Nil do Begin MNext:=MN^.Next;FreeModule(MN^.Item);Dispose(MN);MN:=MNext End;
 if ErrorCount<>0 Then Begin WriteLn(ErrorCount,' erreur(s)');Halt(1) End;
 WriteLn('LDZ8K: ',ModuleCount,' module(s) lies dans ',Opt.OutputName);Halt(0)
END.
