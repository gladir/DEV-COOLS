{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Clone de RELMOD pour les fichiers DRI CP/M-68K et GEMDOS.
 @license: MIT }

Program RELMOD;

{$A-,B-,I-,R-,S-}

Uses Dos;

Const
 Version='1.0';
 DRI_NORMAL=$601A;
 DRI_BASES =$601B;
 DRI_2K    =$601C;
 DRI_ID    =$601D;
 DRI_4K    =$601E;
 REL_ABS   =0;
 REL_DATA  =1;
 REL_TEXT  =2;
 REL_BSS   =3;
 REL_EXTERN=4;
 REL_UPPER =5;
 REL_PCREL =6;
 REL_INSTR =7;
 BufferSize=8192;

Type
 TBuffer=Array[0..BufferSize-1]of Byte;

Var
 Errors,Conversions:Integer;

Function Upper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do if S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 Upper:=S
End;

Function HasExtension(Path:String):Boolean;
Var
 I:Integer;
Begin
 HasExtension:=False;
 For I:=Length(Path)downto 1 do Begin
  if Path[I]='.'Then Begin
   HasExtension:=True;Exit
  End;
  if Path[I]in['/','\',':']Then Exit
 End
End;

Function ReplaceExtension(Path,Ext:String):String;
Var
 I,P:Integer;
Begin
 P:=0;
 For I:=Length(Path)downto 1 do Begin
  if Path[I]='.'Then Begin
   P:=I;Break
  End;
  if Path[I]in['/','\',':']Then Break
 End;
 if P<>0 Then Path:=Copy(Path,1,P-1);
 ReplaceExtension:=Path+Ext
End;

Function AddExtension(Path,Ext:String):String;Begin
 if HasExtension(Path)Then AddExtension:=Path else AddExtension:=Path+Ext
End;

Function HostPath(Path:String):String;
Var
 Root:String;
 I:Integer;
Begin
 if(Path<>'')and(Path[1]='/')Then Begin
  Root:=GetEnv('OS9ROOT');
  if Root<>''Then Begin
   if not(Root[Length(Root)]in['/','\',':'])Then Root:=Root+'\';
   Path:=Root+Copy(Path,2,255)
  End
 End;
 For I:=1 to Length(Path)do if Path[I]='/'Then Path[I]:='\';
 HostPath:=Path
End;

Function SamePath(A,B:String):Boolean;Begin
 SamePath:=Upper(FExpand(A))=Upper(FExpand(B))
End;

Procedure Message(S:String);Begin
 WriteLn(StdErr,'RELMOD: ',S)
End;

Procedure Fail(S:String);Begin
 Inc(Errors);Message(S)
End;

Procedure Help;Begin
 WriteLn('RELMOD ',Version,' - Cette commande permet de lancer le ',
         'convertisseur DRI CP/M-68K vers GEMDOS.');
 WriteLn;
 WriteLn('Syntaxe : RELMOD [-]entree[.68K] [sortie[.PRG]] ...');
 WriteLn;
 WriteLn('Un nom pr'+#130+'c'+#130+'d'+#130+
         ' de - commence une nouvelle conversion.');
 WriteLn('Exemple : RELMOD BAR -BAZ.ZIP');
 Halt(0)
End;

Function GetByte(Var F:File;Var OK:Boolean):Byte;
Var
 B:Byte;
 N:Word;
Begin
 B:=0;BlockRead(F,B,1,N);if(IOResult<>0)or(N<>1)Then OK:=False;GetByte:=B
End;

Function GetWord(Var F:File;Var OK:Boolean):Word;
Var
 A,B:Byte;
Begin
 A:=GetByte(F,OK);B:=GetByte(F,OK);GetWord:=(Word(A)shl 8)or B
End;

Function GetLong(Var F:File;Var OK:Boolean):LongInt;
Var
 A,B:Word;
Begin
 A:=GetWord(F,OK);B:=GetWord(F,OK);GetLong:=(LongInt(A)shl 16)or B
End;

Procedure PutByte(Var F:File;B:Byte;Var OK:Boolean);
Var
 N:Word;
Begin
 BlockWrite(F,B,1,N);if(IOResult<>0)or(N<>1)Then OK:=False
End;

Procedure PutWord(Var F:File;W:Word;Var OK:Boolean);Begin
 PutByte(F,Byte(W shr 8),OK);PutByte(F,Byte(W),OK)
End;

Procedure PutLong(Var F:File;L:LongInt;Var OK:Boolean);Begin
 PutWord(F,Word(L shr 16),OK);PutWord(F,Word(L),OK)
End;

Function SafeAdd(A,B:LongInt;Var OK:Boolean):LongInt;Begin
 if(B<0)or(A<0)or(A>MaxLongInt-B)Then Begin
  OK:=False;SafeAdd:=0
 End
 else SafeAdd:=A+B
End;

Procedure CopyBytes(Var Src,Dst:File;Count:LongInt;Var OK:Boolean);
Var
 Buf:TBuffer;
 N,Got,Wrote:Word;
Begin
 While(Count>0)and OK do Begin
  if Count>BufferSize Then N:=BufferSize else N:=Count;
  BlockRead(Src,Buf,N,Got);if(IOResult<>0)or(Got<>N)Then Begin
   OK:=False;Exit
  End;
  BlockWrite(Dst,Buf,N,Wrote);if(IOResult<>0)or(Wrote<>N)Then Begin
   OK:=False;Exit
  End;
  Dec(Count,N)
 End
End;

Procedure RemoveFile(Path:String);
Var
 F:File;
Begin
 Assign(F,Path);Erase(F);if IOResult<>0 Then Begin
 End
End;

Procedure ConvertOne(InputArg,OutputArg:String);
Var
 Src,Dst,TmpFile:File;
 InputName,OutputName,InputPath,OutputPath,TempPath:String;
 Magic,AbsFlag,R,NextR:Word;
 TextSize,DataSize,BssSize,SymSize,StackSize,TextBase,DataBase,BssBase:LongInt;
 HeaderSize,PayloadSize,RelocWords,I,Location,Previous,Delta:LongInt;
 OK,HaveReloc,Opened:Boolean;
 CloseCode,BeforeErrors:Integer;
Begin
 BeforeErrors:=Errors;
 InputName:=AddExtension(InputArg,'.68K');InputPath:=HostPath(InputName);
 if OutputArg=''Then OutputName:=ReplaceExtension(InputArg,'.PRG')
 else OutputName:=AddExtension(OutputArg,'.PRG');
 OutputPath:=HostPath(OutputName);
 if SamePath(InputPath,OutputPath)Then Begin
  Fail('le fichier de sortie ne peut pas etre le fichier d''entree: '+OutputName);Exit
 End;
 Assign(Src,InputPath);Reset(Src,1);if IOResult<>0 Then Begin
  Fail('impossible d''ouvrir '+InputName);Exit
 End;
 OK:=True;Opened:=False;Magic:=GetWord(Src,OK);TextSize:=GetLong(Src,OK);
 DataSize:=GetLong(Src,OK);BssSize:=GetLong(Src,OK);SymSize:=GetLong(Src,OK);
 StackSize:=GetLong(Src,OK);TextBase:=GetLong(Src,OK);AbsFlag:=GetWord(Src,OK);
 HeaderSize:=28;DataBase:=TextBase+TextSize;BssBase:=DataBase+DataSize;
 if Magic=DRI_BASES Then Begin
  DataBase:=GetLong(Src,OK);BssBase:=GetLong(Src,OK);HeaderSize:=36
 End;
 if(Magic<>DRI_NORMAL)and(Magic<>DRI_BASES)and(Magic<>DRI_2K)and
 (Magic<>DRI_4K)Then Begin
  if Magic=DRI_ID Then Fail(InputName+
  ': format I/D separe non convertible en programme GEMDOS')
  else Fail(InputName+': mauvais nombre magique DRI');Close(Src);Exit
 End;
 if not OK Then Begin
  Fail(InputName+': en-tete tronque');Close(Src);Exit
 End;
 if StackSize<>0 Then Begin
 End;
 if(TextSize<0)or(DataSize<0)or(BssSize<0)or(SymSize<0)Then Begin
  Fail(InputName+': taille de segment incorrecte');Close(Src);Exit
 End;
 if(TextSize and 1<>0)or(DataSize and 1<>0)Then Begin
  Fail(InputName+': les segments TEXT et DATA doivent etre pairs');Close(Src);Exit
 End;
 if(TextBase<>0)or(DataBase<>TextBase+TextSize)or(BssBase<>DataBase+DataSize)Then Begin
  Fail(InputName+': segments non contigus ou bases absolues incompatibles avec GEMDOS');
  Close(Src);Exit
 End;
 PayloadSize:=SafeAdd(TextSize,DataSize,OK);PayloadSize:=SafeAdd(PayloadSize,SymSize,OK);
 if not OK Then Begin
  Fail(InputName+': tailles trop grandes');Close(Src);Exit
 End;
 RelocWords:=(TextSize+DataSize)div 2;
 if AbsFlag=0 Then I:=SafeAdd(HeaderSize,SafeAdd(PayloadSize,RelocWords*2,OK),OK)
 else I:=SafeAdd(HeaderSize,PayloadSize,OK);
 if(not OK)or(I>FileSize(Src))Then Begin
  Fail(InputName+': fichier tronque');Close(Src);Exit
 End;
 TempPath:=OutputPath+'.$RM';RemoveFile(TempPath);
 Assign(Dst,TempPath);Rewrite(Dst,1);if IOResult<>0 Then Begin
  Fail('impossible de creer '+OutputName);Close(Src);Exit
 End;Opened:=True;
 PutWord(Dst,DRI_NORMAL,OK);PutLong(Dst,TextSize,OK);PutLong(Dst,DataSize,OK);
 PutLong(Dst,BssSize,OK);PutLong(Dst,SymSize,OK);PutLong(Dst,0,OK);PutLong(Dst,0,OK);
 if AbsFlag=0 Then PutWord(Dst,0,OK)else PutWord(Dst,1,OK);
 Seek(Src,HeaderSize);if IOResult<>0 Then OK:=False;CopyBytes(Src,Dst,PayloadSize,OK);
 if OK and(AbsFlag=0)Then Begin
  HaveReloc:=False;Previous:=0;I:=0;
  While(I<RelocWords)and OK do Begin
   R:=GetWord(Src,OK)and 7;
   if R=REL_UPPER Then Begin
    if I+1>=RelocWords Then Begin
     Fail(InputName+': relogement long tronque');OK:=False
    End
    else
    Begin
     NextR:=GetWord(Src,OK)and 7;
     if not(NextR in[REL_DATA,REL_TEXT,REL_BSS])Then Begin
      Fail(InputName+': relogement long non resolu ou invalide');OK:=False
     End else
     Begin
      Location:=I*2;
      if Location=0 Then Begin
       Fail(InputName+': relogement GEMDOS impossible a l''offset zero');OK:=False
      End else
      if not HaveReloc Then Begin
       PutLong(Dst,Location,OK);HaveReloc:=True
      End
      else
      Begin
       Delta:=Location-Previous;
       While Delta>254 do Begin
        PutByte(Dst,1,OK);Dec(Delta,254)
       End;
       if(Delta<2)or(Delta>254)Then Begin
        Fail(InputName+': distance de relogement invalide');OK:=False
       End
       else PutByte(Dst,Byte(Delta),OK)
      End;Previous:=Location
     End;Inc(I,2);Continue
    End
   End else if R in[REL_DATA,REL_TEXT,REL_BSS,REL_EXTERN,REL_PCREL]Then Begin
    Fail(InputName+': relogement 16 bits non representable par GEMDOS');OK:=False
   End;
   Inc(I)
  End;
  if OK Then if HaveReloc Then PutByte(Dst,0,OK)else PutLong(Dst,0,OK)
 End;
 Close(Src);CloseCode:=IOResult;if CloseCode<>0 Then OK:=False;
 if Opened Then Begin
  Close(Dst);CloseCode:=IOResult;if CloseCode<>0 Then OK:=False
 End;
 if not OK Then Begin
  RemoveFile(TempPath);
  if Errors=BeforeErrors Then Fail(InputName+': erreur de lecture ou d''ecriture');Exit
 End;
 RemoveFile(OutputPath);Assign(TmpFile,TempPath);Rename(TmpFile,OutputPath);
 if IOResult<>0 Then Begin
  RemoveFile(TempPath);Fail('impossible de renommer la sortie en '+OutputName);Exit
 End;
 Inc(Conversions);WriteLn(InputName,' -> ',OutputName)
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 S,InputName,OutputName:String;

Procedure Flush;Begin
 if InputName<>''Then ConvertOne(InputName,OutputName);
 InputName:='';OutputName:=''
End;
Begin
 if ParamCount=0 Then Help;InputName:='';OutputName:='';
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')Then Help;
  if(S<>'')and(S[1]='-')Then Begin
   Flush;Delete(S,1,1);
   if S=''Then Begin
    Fail('nom d''entree absent apres -');Exit
   End;
   InputName:=S
  End else if InputName=''Then InputName:=S
  else if OutputName=''Then OutputName:=S
  else
  Begin
   Fail('utilisez - devant une nouvelle entree: '+S);Exit
  End
 End;Flush
End;

BEGIN
 Errors:=0;Conversions:=0;ParseCommandLine;
 if Errors=0 Then WriteLn(Conversions,' fichier(s) converti(s).')
 else WriteLn(Errors,' erreur(s).');
 if Errors<>0 Then Halt(1)
END.
