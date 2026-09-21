{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Clone libre de l'assembleur Digital Research ASZ8K pour Z8001/Z8002.
 @license: MIT }

Program ASZ8K;

{$A-,B-,I-,R-,S-}

Uses Dos;

Const
 Version='1.0';
 MaxSectionSize=65535;
 SecAbsolute=0;
 SecText=1;
 SecData=2;
 SecBss=3;
 { Types de blocs et codes de relogement du format DRI UNIDOT. }
 OBOST=1; OBSEC=3; OBGLO=4; OBLOC=5; OBTXT=6; OBTRA=8; OBMOD=12; OBOND=11;
 RAA8=$4000; RAA16M=$2000; RAA32M=$A000; RAZSS=$6000; RAZLS=$E000; RAZOF=$3000;
 RBUND=255; RBEXT=256; RBMSK=$0FFF;

Type
 TByteBlock=Array[0..16383]of Byte;
 PByteBlock=^TByteBlock;
 PSymbol=^TSymbol;
 TSymbol=Record
 Name:String;
 Value:LongInt;
 Section:Byte;
 Defined,Global,External:Boolean;
 DefLine:LongInt;
 References:String;
 ObjectBase:Word;
 Next:PSymbol
End;
PRelocation=^TRelocation;
TRelocation=Record
 Section:Byte;
 Offset:LongInt;
 Action,Base:Word;
 Width:Byte;
 Next:PRelocation
End;
TOptions=Record
SourceName,ObjectName,ListName,PredefName:String;
Listing,CrossReference,UndefinedGlobal,Segmented:Boolean
End;
PPredefFormat=^TPredefFormat;
TPredefFormat=Record
 Operand:Array[0..3]of Word;
 Skeleton,Flags:Word;
 Next:PPredefFormat
End;
PPredefName=^TPredefName;
TPredefName=Record
 Name:String;
 Kind:Byte; { 1=instruction, 2=directive, 3=symbole predefini }
 Value:LongInt;
 Formats:PPredefFormat;
 Next:PPredefName
End;
TPredefTokenArray=Array[0..31]of String;

Var
 Opt:TOptions;
 TextImage,DataImage:Array[0..3]of PByteBlock;
 TextSize,DataSize,BssSize:LongInt;
 CurrentSection:Byte;
 Location:Array[0..3]of LongInt;
 Symbols:PSymbol;
 Relocations,LastRelocation:PRelocation;
 Pass,LineNumber,ErrorCount,WarningCount:Integer;
 Source:Text;
 ListFile:Text;
 ListOpen:Boolean;
 CurrentLine,LabelField,OpcodeField,OperandField:String;
 CurrentInputName:String;
 LineBytes:Array[0..31]of Byte;
 LineByteCount:Integer;
 StopAssembly:Boolean;
 HasTransfer:Boolean;
 TransferAddress:LongInt;
 TransferBase:Word;
 Predefinitions:PPredefName;
 PredefInstructionCount,PredefDirectiveCount,PredefSymbolCount:Integer;
 ModuleActive,ModuleClosed:Boolean;
 ObjectModuleName,CurrentGlobal:String;
 SectionObjectName:Array[1..3]of String;
 SectionAttributes:Array[1..3]of Byte;
 ConditionalDepth:Integer;
 ConditionalParent,ConditionalValue,ConditionalElse:Array[1..32]of Boolean;
 ConditionalEnabled:Boolean;
 StructureDepth,StructureSerial:Integer;
 StructureKind:Array[1..32]of Char;
 StructureStart,StructureFalse,StructureEnd:Array[1..32]of String;
 StructureHasElse:Array[1..32]of Boolean;

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

Function HexDigit(N:Byte):Char;Begin
 if N<10 Then HexDigit:=Chr(Ord('0')+N)else HexDigit:=Chr(Ord('A')+N-10)
End;

Function HexWord(W:Word):String;Begin
 HexWord:=HexDigit(W shr 12)+HexDigit((W shr 8)and 15)+
 HexDigit((W shr 4)and 15)+HexDigit(W and 15)
End;

Function HexByte(B:Byte):String;Begin
 HexByte:=HexDigit(B shr 4)+HexDigit(B and 15)
End;

Function BaseName(S:String):String;
Var
 I,P:Integer;
Begin
 P:=0;
 For I:=Length(S)downto 1 do if S[I]='.'Then Begin
  P:=I;Break
 End
 else if S[I]in['\','/',':']Then Break;
 if P<>0 Then Delete(S,P,255);BaseName:=S
End;

Function Extension(S:String):String;
Var
 I:Integer;
Begin
 Extension:='';
 For I:=Length(S)downto 1 do if S[I]='.'Then Begin
  Extension:=UpperString(Copy(S,I,255));Exit
 End else if S[I]in['\','/',':']Then Exit
End;

Procedure Usage;Begin
 WriteLn('ASZ8K ',Version,
 ' - Cette commande permet de lancer l''assembleur Zilog Z8001/Z8002 pour CP/M-8000');
 WriteLn;
 WriteLn('Syntaxe : ASZ8K [-o fichier] [-p ASZ8K.PD] [-lux] fichier.8k{n|s}');
 WriteLn;
 WriteLn('  -o nom  produit un objet relogeable UNIDOT (extension .OBJ par defaut)');
 WriteLn('  -p nom  utilise ce fichier de predefinitions Digital Research');
 WriteLn('            .O vient de XCON, .RL de LDSK et .Z8K est executable');
 WriteLn('  -l      produit un listing fichier.LST');
 WriteLn('  -u      considere les symboles indefinis comme globaux externes');
 WriteLn('  -x      ajoute les references croisees au listing (implique -l)');
 WriteLn('  .8KN    objet Z8002/non segmente; .8KS objet Z8001 segmente')
End;

Procedure Fatal(Const S:String);Begin
 WriteLn('ASZ8K: ',S);Halt(1)
End;

Procedure Diagnostic(Const S:String);Begin
 if Pass=2 Then Begin
  Inc(ErrorCount);WriteLn(CurrentInputName,'(',LineNumber,'): ',S);
  if ListOpen Then WriteLn(ListFile,'**** ',S)
 End
End;

Procedure Warning(Const S:String);Begin
 if Pass=2 Then Begin
  Inc(WarningCount);WriteLn(Opt.SourceName,'(',LineNumber,'): avertissement: ',S)
 End
End;

Function QualifiedSymbolName(Const Name:String):String;
Begin
 if(Length(Name)>0)and(Name[1]='.')and(CurrentGlobal<>'')Then
  QualifiedSymbolName:=CurrentGlobal+Name
 else QualifiedSymbolName:=Name
End;

Function FindSymbol(Const Name:String):PSymbol;
Var
 P:PSymbol;Q:String;
Begin
 Q:=QualifiedSymbolName(Name);P:=Symbols;
 While(P<>Nil)and(P^.Name<>Q)do P:=P^.Next;FindSymbol:=P
End;

Function GetSymbol(Const Name:String):PSymbol;
Var
 P:PSymbol;
Begin
 P:=FindSymbol(Name);if P=Nil Then Begin
  New(P);if P=Nil Then Fatal('memoire pleine');
  FillChar(P^,SizeOf(P^),0);P^.Name:=QualifiedSymbolName(Name);P^.Next:=Symbols;Symbols:=P
 End;GetSymbol:=P
End;

Procedure AddReference(P:PSymbol);
Var
 N:String;
Begin
 if(Pass<>2)or(P=Nil)Then Exit;Str(LineNumber,N);
 if Length(P^.References)+Length(N)+1<255 Then P^.References:=P^.References+' '+N
End;

Procedure DefineSymbol(Const Name:String;Value:LongInt;Section:Byte);
Var
 P:PSymbol;
Begin
 if Name=''Then Exit;P:=GetSymbol(Name);
 if Pass=1 Then Begin
  if P^.Defined Then Begin
   Diagnostic('symbole defini plusieurs fois: '+Name);Exit
  End;
  P^.Defined:=True;P^.Value:=Value;P^.Section:=Section;P^.DefLine:=LineNumber
 End else if(not P^.Defined)or(P^.Value<>Value)or(P^.Section<>Section)Then  Diagnostic(
 'erreur de phase pour '+Name)
End;

Procedure FreeSymbols;
Var
 P,N:PSymbol;
 R,RN:PRelocation;
Begin
 P:=Symbols;
 While P<>Nil do Begin
  N:=P^.Next;Dispose(P);P:=N
 End;Symbols:=Nil;
 R:=Relocations;While R<>Nil do Begin RN:=R^.Next;Dispose(R);R:=RN End;
 Relocations:=Nil;LastRelocation:=Nil
End;

Function DirectoryPart(S:String):String;
Var I:Integer;
Begin
 DirectoryPart:='';
 For I:=Length(S)downto 1 do if S[I]in['\','/',':']Then Begin
  DirectoryPart:=Copy(S,1,I);Exit
 End
End;

Function TextFileExists(Const Name:String):Boolean;
Var F:Text;Ok:Boolean;
Begin
 Assign(F,Name);Reset(F);Ok:=IOResult=0;TextFileExists:=Ok;
 if Ok Then Begin Close(F);if IOResult<>0 Then Begin End End
End;

Function FindPredefName(Const Name:String;Kind:Byte):PPredefName;
Var P:PPredefName;U:String;
Begin
 U:=UpperString(Name);P:=Predefinitions;
 While P<>Nil do Begin
  if(P^.Kind=Kind)and(P^.Name=U)Then Begin FindPredefName:=P;Exit End;
  P:=P^.Next
 End;
 FindPredefName:=Nil
End;

Function ParsePredefNumber(Const Token:String;Var Value:LongInt):Boolean;
Var S:String;Code:Integer;
Begin
 S:=UpperString(Token);
 if(Length(S)>1)and(S[Length(S)]='H')Then Begin
  Delete(S,Length(S),1);S:='$'+S
 End;
 Val(S,Value,Code);ParsePredefNumber:=Code=0
End;

Procedure SplitPredefTokens(S:String;Var Tokens:TPredefTokenArray;Var Count:Integer);
Var I,J:Integer;
Begin
 I:=Pos(';',S);if I<>0 Then Delete(S,I,255);Count:=0;I:=1;
 While I<=Length(S)do Begin
  While(I<=Length(S))and(S[I]in[' ',#9])do Inc(I);if I>Length(S)Then Break;
  J:=I;While(J<=Length(S))and not(S[J]in[' ',#9])do Inc(J);
  if Count<=31 Then Begin Tokens[Count]:=Copy(S,I,J-I);Inc(Count) End;
  I:=J
 End
End;

Function ClonePredefFormats(P:PPredefFormat):PPredefFormat;
Var First,Last,Q:PPredefFormat;
Begin
 First:=Nil;Last:=Nil;
 While P<>Nil do Begin
  New(Q);if Q=Nil Then Fatal('memoire pleine pendant le chargement ASZ8K.PD');
  Q^:=P^;Q^.Next:=Nil;
  if First=Nil Then First:=Q else Last^.Next:=Q;Last:=Q;P:=P^.Next
 End;
 ClonePredefFormats:=First
End;

Procedure FreePredefFormats(P:PPredefFormat);
Var N:PPredefFormat;
Begin
 While P<>Nil do Begin N:=P^.Next;Dispose(P);P:=N End
End;

Procedure AddPredef(Const Name:String;Kind:Byte;Value:LongInt;Formats:PPredefFormat;
 LineNo:Integer);
Var P:PPredefName;
Begin
 { Le fichier DRI publie volontairement chaque nom en minuscules et en
   majuscules. La table du clone est insensible a la casse: garder une seule
   entree pour ces deux graphies. }
 if FindPredefName(Name,Kind)<>Nil Then Exit;
 New(P);if P=Nil Then Fatal('memoire pleine pendant le chargement ASZ8K.PD');
 FillChar(P^,SizeOf(P^),0);P^.Name:=UpperString(Name);P^.Kind:=Kind;P^.Value:=Value;
 if Formats<>Nil Then P^.Formats:=ClonePredefFormats(Formats);
 P^.Next:=Predefinitions;Predefinitions:=P;
 Case Kind of
  1:Inc(PredefInstructionCount);2:Inc(PredefDirectiveCount);3:Inc(PredefSymbolCount)
 End
End;

Procedure PredefError(LineNo:Integer;Const S:String);
Var N:String;
Begin
 Str(LineNo,N);Fatal('ASZ8K.PD ligne '+N+': '+S)
End;

Procedure LoadPredefinitions;
Var
 F:Text;Line:String;Tokens:TPredefTokenArray;
 Count,Section,LineNo,I:Integer;V:LongInt;Fmt,FirstFmt,LastFmt:PPredefFormat;
 Candidate,EnvName:String;
Begin
 Candidate:=Opt.PredefName;
 if Candidate=''Then Begin
  EnvName:=GetEnv('ASZ8KPD');if EnvName<>''Then Candidate:=EnvName
 End;
 if Candidate=''Then Begin
 Candidate:='ASZ8K.PD';
  if not TextFileExists(Candidate)Then Candidate:='asz8k.pd';
  if not TextFileExists(Candidate)Then Candidate:=DirectoryPart(ParamStr(0))+'ASZ8K.PD';
  if not TextFileExists(Candidate)Then Candidate:=DirectoryPart(ParamStr(0))+'asz8k.pd';
  if not TextFileExists(Candidate)Then Candidate:=DirectoryPart(Opt.SourceName)+'ASZ8K.PD';
  if not TextFileExists(Candidate)Then Candidate:=DirectoryPart(Opt.SourceName)+'asz8k.pd'
 End;
 if not TextFileExists(Candidate)Then Fatal('fichier de predefinitions ASZ8K.PD introuvable');
 Opt.PredefName:=Candidate;Assign(F,Candidate);Reset(F);
 if IOResult<>0 Then Fatal('lecture impossible du fichier ASZ8K.PD');
 Section:=1;LineNo:=0;FirstFmt:=Nil;LastFmt:=Nil;
 While not Eof(F)do Begin
 ReadLn(F,Line);if IOResult<>0 Then PredefError(LineNo,'erreur de lecture');Inc(LineNo);
  if Pos(#26,Line)<>0 Then Delete(Line,Pos(#26,Line),255);
  if(TrimString(Line)<>'')and(TrimString(Line)[1]=';')Then Continue;
  SplitPredefTokens(Line,Tokens,Count);
  if Count=0 Then Begin
   if Section=1 Then Begin
    if FirstFmt<>Nil Then PredefError(LineNo,'mnemonique absent apres une description');Section:=2
   End else if Section=2 Then Section:=3;
   Continue
  End;
  if Section=1 Then Begin
   if Count<6 Then PredefError(LineNo,'six champs numeriques attendus');
   New(Fmt);if Fmt=Nil Then Fatal('memoire pleine pendant le chargement ASZ8K.PD');
   FillChar(Fmt^,SizeOf(Fmt^),0);
   For I:=0 to 3 do Begin
    if not ParsePredefNumber(Tokens[I],V)or(V<0)or(V>$FFFF)Then
     PredefError(LineNo,'descripteur d''operande incorrect: '+Tokens[I]);
    Fmt^.Operand[I]:=Word(V)
   End;
   if not ParsePredefNumber(Tokens[4],V)or(V<0)or(V>$FFFF)Then
    PredefError(LineNo,'squelette d''instruction incorrect');Fmt^.Skeleton:=Word(V);
   if not ParsePredefNumber(Tokens[5],V)or(V<0)or(V>$FFFF)Then
    PredefError(LineNo,'indicateurs d''instruction incorrects');Fmt^.Flags:=Word(V);
   if FirstFmt=Nil Then FirstFmt:=Fmt else LastFmt^.Next:=Fmt;LastFmt:=Fmt;
   if Count>6 Then Begin
    For I:=6 to Count-1 do AddPredef(Tokens[I],1,0,FirstFmt,LineNo);
    FreePredefFormats(FirstFmt);FirstFmt:=Nil;LastFmt:=Nil
   End
  End else Begin
   if(Count<2)or not ParsePredefNumber(Tokens[0],V)Then
    PredefError(LineNo,'valeur et nom predefini attendus');
   For I:=1 to Count-1 do AddPredef(Tokens[I],Section,V,Nil,LineNo)
  End
 End;
 Close(F);if IOResult<>0 Then Fatal('erreur de fermeture de ASZ8K.PD');
 if FirstFmt<>Nil Then PredefError(LineNo,'description d''instruction inachevee');
 if(PredefInstructionCount=0)or(PredefDirectiveCount=0)or(PredefSymbolCount=0)Then
  Fatal('ASZ8K.PD incomplet ou corrompu')
End;

Function ModuleName(S:String):String;
Var I,P:Integer;
Begin
 P:=0;For I:=Length(S)downto 1 do if S[I]in['\','/',':']Then Begin P:=I;Break End;
 if P<>0 Then Delete(S,1,P);S:=BaseName(S);if Length(S)>8 Then Delete(S,9,255);
 ModuleName:=S
End;

Procedure AddRelocation(Action,Base:Word);
Var R:PRelocation;
Begin
 if(Pass<>2)or(Base=0)Then Exit;
 New(R);if R=Nil Then Fatal('memoire pleine');
 R^.Section:=CurrentSection;R^.Offset:=Location[CurrentSection];
 R^.Action:=Action;R^.Base:=Base and RBMSK;
 if Action=RAA8 Then R^.Width:=1 else if(Action=RAA32M)or(Action=RAZLS)Then R^.Width:=4
 else R^.Width:=2;
 R^.Next:=Nil;
 if LastRelocation=Nil Then Relocations:=R else LastRelocation^.Next:=R;
 LastRelocation:=R
End;

Procedure EmitByte(B:Byte);Begin
 if Pass=2 Then Begin
  if LineByteCount<SizeOf(LineBytes)Then Begin
   LineBytes[LineByteCount]:=B;Inc(LineByteCount)
  End;
  Case CurrentSection of
  SecText:if Location[SecText]<=
  MaxSectionSize Then    TextImage[Location[SecText]div 16384]^[Location[SecText]mod 16384]:=B;
  SecData:if Location[SecData]<=
  MaxSectionSize Then    DataImage[Location[SecData]div 16384]^[Location[SecData]mod 16384]:=B;
  SecBss:Diagnostic('emission de donnees dans BSS');
 End
End;
Inc(Location[CurrentSection]);
if Location[CurrentSection]>65536 Then Diagnostic('section superieure a 64 Kio')
End;

Procedure EmitWord(W:Word);Begin
 EmitByte(W shr 8);EmitByte(W and $FF)
End;

Procedure EmitLong(L:LongInt);Begin
 EmitWord(Word(LongInt(L)shr 16));EmitWord(Word(L))
End;

Procedure EmitByteReloc(B:Byte;Action,Base:Word);Begin
 AddRelocation(Action,Base);EmitByte(B)
End;

Procedure EmitWordReloc(W:Word;Action,Base:Word);Begin
 AddRelocation(Action,Base);EmitWord(W)
End;

Procedure EmitLongReloc(L:LongInt;Action,Base:Word);Begin
 AddRelocation(Action,Base);EmitLong(L)
End;

Function SegmentedLongValue(V:LongInt;Base:Word):LongInt;
Var S:Word;
Begin
 if Base>$7F Then S:=$7F else S:=Base;
 SegmentedLongValue:=LongInt($80000000)or(LongInt(S)shl 24)or(V and $FFFF)
End;

Function SegmentedShortValue(V:LongInt;Base:Word):Word;
Var S:Word;
Begin
 if Base>$7F Then S:=$7F else S:=Base;
 SegmentedShortValue:=(S shl 8)or Word(V and $FF)
End;

Function IsIdentStart(C:Char):Boolean;Begin
 IsIdentStart:=C in['A'..'Z','a'..'z','_','.','$']
End;

Function IsIdentChar(C:Char):Boolean;Begin
 IsIdentChar:=IsIdentStart(C)or(C in['0'..'9'])
End;

Function StripComment(S:String):String;
Var
 I:Integer;
 Quoted:Boolean;
Begin
 Quoted:=False;I:=1;
 While I<=Length(S)do Begin
  if S[I]='"'Then Quoted:=not Quoted
  else if not Quoted and(S[I]in[';','!'])Then Begin
   Delete(S,I,255);Break
  End;
  Inc(I)
 End;StripComment:=S
End;

Procedure SplitLine(S:String);
Var
 I,P:Integer;
 FirstWord:String;
Begin
 LabelField:='';OpcodeField:='';OperandField:='';S:=StripComment(S);
 if TrimString(S)=''Then Exit;
 I:=1;
 While(I<=Length(S))and(S[I]in[' ',#9])do Inc(I);P:=I;
 While(I<=Length(S))and IsIdentChar(S[I])do Inc(I);
 if(I<=Length(S))and(S[I]=':')Then Begin
  LabelField:=Copy(S,P,I-P);Inc(I)
 End
 else I:=P;
 While(I<=Length(S))and(S[I]in[' ',#9])do Inc(I);P:=I;
 While(I<=Length(S))and not(S[I]in[' ',#9])do Inc(I);
 FirstWord:=Copy(S,P,I-P);OpcodeField:=UpperString(FirstWord);
 While(I<=Length(S))and(S[I]in[' ',#9])do Inc(I);
 OperandField:=TrimString(Copy(S,I,255));
 { DRI accepte aussi: nom equ expression, sans deux-points. }
 if(LabelField='')and(OpcodeField<>'')Then Begin
  P:=1;
  While(P<=Length(OperandField))and not(OperandField[P]in[' ',#9])do Inc(P);
  if(UpperString(Copy(OperandField,1,P-1))='EQU')or(Copy(OperandField,1,P-1)='=')or
   (UpperString(Copy(OperandField,1,P-1))='CONSTANT')or
   (UpperString(Copy(OperandField,1,P-1))='BYTE')or
   (UpperString(Copy(OperandField,1,P-1))='WORD')or
   (UpperString(Copy(OperandField,1,P-1))='LONG')or
   (UpperString(Copy(OperandField,1,P-1))='ARRAY')or
   (UpperString(Copy(OperandField,1,P-1))='RECORD')or
   (UpperString(Copy(OperandField,1,P-1))='PROCEDURE')
  Then Begin
   LabelField:=FirstWord;OpcodeField:=UpperString(Copy(OperandField,1,P-1));
   if OpcodeField='='Then OpcodeField:='EQU';Delete(OperandField,1,P-1);
   OperandField:=TrimString(OperandField)
  End
 End
End;

Function NextOperand(Var S:String):String;
Var
 I,Level:Integer;
 Quoted:Boolean;
Begin
 S:=TrimString(S);I:=1;Level:=0;Quoted:=False;
 While I<=Length(S)do Begin
  if S[I]='"'Then Quoted:=not Quoted
  else if not Quoted Then Begin
   if S[I]in['(','[']Then Inc(Level)else if S[I]in[')',']']Then Dec(Level)
   else if(S[I]=',')and(Level=0)Then Break
  End;Inc(I)
 End;
 NextOperand:=TrimString(Copy(S,1,I-1));if I<=Length(S)Then Delete(S,1,I)else S:=''
End;

Type
 TExprParser=Record S:String;
 P:Integer;
 ForwardRef:Boolean
End;

Procedure ExprSkip(Var E:TExprParser);Begin
 While(E.P<=Length(E.S))and(E.S[E.P]in[' ',#9])do Inc(E.P)
End;
Function ParseExprOr(Var E:TExprParser):LongInt;Forward;
Function ParseUnary(Var E:TExprParser):LongInt;Forward;

Function ParseNumber(Var E:TExprParser):LongInt;
Var
 Start,Code:Integer;
 T,U:String;
 V:LongInt;
 P:PSymbol;
 K:PPredefName;
 Base:Integer;
 C:Char;
Begin
 ExprSkip(E);if E.P>Length(E.S)Then Begin
  Diagnostic('expression attendue');ParseNumber:=0;Exit
 End;
 C:=E.S[E.P];if C='('Then Begin
  Inc(E.P);V:=ParseExprOr(E);ExprSkip(E);
  if(E.P>Length(E.S))or(E.S[E.P]<>')')Then Diagnostic('parenthese fermante attendue')
  else Inc(E.P);
  ParseNumber:=V;Exit
 End;
 if C='['Then Begin
  if not Opt.Segmented Then Diagnostic('adresse [segment]offset reservee aux sources .8KS');
  Inc(E.P);V:=ParseExprOr(E);ExprSkip(E);
  if(E.P>Length(E.S))or(E.S[E.P]<>']')Then Diagnostic('crochet fermant attendu')
  else Inc(E.P);
  if(Pass=2)and((V<0)or(V>$7F))Then Diagnostic('numero de segment hors plage 0..127');
  Base:=V;V:=ParseUnary(E);
  if(Pass=2)and((V<0)or(V>$FFFF))Then Diagnostic('offset segmente hors plage 0..65535');
  ParseNumber:=LongInt($80000000)or(LongInt(Base and $7F)shl 24)or(V and $FFFF);Exit
 End;
 if C=''''Then Begin
  Inc(E.P);if E.P<=Length(E.S)Then Begin
   V:=Ord(E.S[E.P]);Inc(E.P)
  End else V:=0;
  if(E.P<=Length(E.S))and(E.S[E.P]='''')Then Inc(E.P);ParseNumber:=V;Exit
 End;
 if C='$'Then Begin
  Inc(E.P);Start:=E.P;
  While(E.P<=Length(E.S))and(UpCase(E.S[E.P])in['0'..'9','A'..'F'])do Inc(E.P);
  T:=Copy(E.S,Start,E.P-Start);
  if T=''Then V:=Location[CurrentSection]else Begin
   Val('$'+T,V,Code);if Code<>0 Then V:=0
  End;ParseNumber:=V;Exit
 End;
 if C in['0'..'9']Then Begin
  Start:=E.P;
  While(E.P<=Length(E.S))and(IsIdentChar(E.S[E.P]))do Inc(E.P);
  T:=Copy(E.S,Start,E.P-Start);U:=UpperString(T);Base:=10;
  if(Length(U)>1)and(U[Length(U)]='H')Then Begin
   Delete(U,Length(U),1);U:='$'+U
  End
  else if(Length(U)>1)and(U[Length(U)]='B')Then Begin
   Base:=2;Delete(U,Length(U),1)
  End;
  if Base=2 Then Begin
   V:=0;
   For Code:=1 to Length(U)do if U[Code]in['0','1']Then V:=V*2+Ord(U[Code])-48
   else
   Begin
    Diagnostic('constante binaire incorrecte');Break
   End
  End else
  Begin
   Val(U,V,Code);if Code<>0 Then Begin
    Diagnostic('nombre incorrect: '+T);V:=0
   End
  End;
  ParseNumber:=V;Exit
 End;
 if IsIdentStart(C)Then Begin
  Start:=E.P;
  While(E.P<=Length(E.S))and IsIdentChar(E.S[E.P])do Inc(E.P);
  T:=Copy(E.S,Start,E.P-Start);
  if(UpperString(T)='SIZEOF')Then Begin
   ExprSkip(E);
   if(E.P>Length(E.S))or(E.S[E.P]<>'(')Then Begin
    Diagnostic('SIZEOF exige un type entre parentheses');ParseNumber:=0;Exit
   End;
   Inc(E.P);ExprSkip(E);Start:=E.P;
   While(E.P<=Length(E.S))and IsIdentChar(E.S[E.P])do Inc(E.P);
   U:=UpperString(Copy(E.S,Start,E.P-Start));ExprSkip(E);
   if(E.P>Length(E.S))or(E.S[E.P]<>')')Then
    Diagnostic('parenthese fermante attendue apres SIZEOF')else Inc(E.P);
   if(U='BYTE')or(U='CHAR')Then V:=1
   else if(U='LONG')or(U='DWORD')Then V:=4
   else if U='QUAD'Then V:=8
   else if(U='WORD')or(U='INTEGER')or(U='ADDRESS')Then V:=2
   else Begin Diagnostic('type SIZEOF inconnu: '+U);V:=0 End;
   ParseNumber:=V;Exit
  End;
  K:=FindPredefName(T,3);
  if K<>Nil Then Begin ParseNumber:=K^.Value;Exit End;
  P:=GetSymbol(T);AddReference(P);
  if P^.Defined Then V:=P^.Value else
  Begin
   V:=0;E.ForwardRef:=True;
   if Pass=2 Then Begin
    if Opt.UndefinedGlobal or P^.External Then Begin
     P^.Global:=True;P^.External:=True
    End
    else Diagnostic('symbole indefini: '+T)
   End
  End;ParseNumber:=V;Exit
 End;
 Diagnostic('terme incorrect dans expression');Inc(E.P);ParseNumber:=0
End;

Function Eval(Const S:String;Var ForwardRef:Boolean):LongInt;Forward;

{ Evalue l'expression et conserve sa base UNIDOT. Les expressions usuelles
  symbole+constante restent relogeables; la difference de deux symboles de la
  meme section devient absolue. }
Function EvalReloc(Const S:String;Var ForwardRef:Boolean;Var Base:Word):LongInt;
Var
 I,J,Count:Integer;
 T:String;
 P,FirstP:PSymbol;
 MinusBetween:Boolean;
Begin
 EvalReloc:=Eval(S,ForwardRef);Base:=0;FirstP:=Nil;Count:=0;MinusBetween:=False;I:=1;
 if TrimString(S)='$'Then Begin Base:=CurrentSection;Exit End;
 While I<=Length(S)do Begin
  if S[I]=''''Then Begin Inc(I);if I<=Length(S)Then Inc(I);if(I<=Length(S))and(S[I]='''')Then Inc(I) End
  else if S[I]='$'Then Begin
   Inc(I);While(I<=Length(S))and(UpCase(S[I])in['0'..'9','A'..'F'])do Inc(I)
  End
  else if IsIdentStart(S[I])Then Begin
   J:=I;Inc(I);While(I<=Length(S))and IsIdentChar(S[I])do Inc(I);
   T:=Copy(S,J,I-J);P:=FindSymbol(T);
   if P<>Nil Then Begin
    Inc(Count);if FirstP=Nil Then FirstP:=P
   End
  End else Begin if(S[I]='-')and(Count=1)Then MinusBetween:=True;Inc(I) End
 End;
 if Count=1 Then Begin
  if FirstP^.Defined Then Base:=FirstP^.Section else Base:=FirstP^.ObjectBase
 End else if(Count=2)and MinusBetween and(FirstP<>Nil)Then Begin
  { Le parseur a deja calcule la difference; elle ne requiert aucun relogement. }
  Base:=0
 End else if Count>1 Then Diagnostic('expression relogeable trop complexe')
End;

Function ParseUnary(Var E:TExprParser):LongInt;
Var P0:Integer;U:String;V:LongInt;
Begin
 ExprSkip(E);if(E.P<=Length(E.S))and(E.S[E.P]='+')Then Begin
  Inc(E.P);ParseUnary:=ParseUnary(E)
 End
 else if(E.P<=Length(E.S))and(E.S[E.P]='-')Then Begin
  Inc(E.P);ParseUnary:=-ParseUnary(E)
 End
 else if(E.P<=Length(E.S))and(E.S[E.P]='~')Then Begin
  Inc(E.P);ParseUnary:=not ParseUnary(E)
 End
 else if(E.P<=Length(E.S))and IsIdentStart(E.S[E.P])Then Begin
  P0:=E.P;While(E.P<=Length(E.S))and IsIdentChar(E.S[E.P])do Inc(E.P);
  U:=UpperString(Copy(E.S,P0,E.P-P0));
  if(U='SEG')or(U='OFFSET')Then Begin
   V:=ParseUnary(E);
   if U='SEG'Then ParseUnary:=(LongInt(V)shr 24)and $7F else ParseUnary:=V and $FFFF
  End else Begin E.P:=P0;ParseUnary:=ParseNumber(E) End
 End
 else ParseUnary:=ParseNumber(E)
End;

Function ParseMul(Var E:TExprParser):LongInt;
Var
 V,R:LongInt;
 C:Char;
Begin
 V:=ParseUnary(E);
 While True do Begin
  ExprSkip(E);if E.P>Length(E.S)Then Break;C:=E.S[E.P];
  if not(C in['*','/','%'])Then Break;Inc(E.P);R:=ParseUnary(E);
  if C='*'Then V:=V*R else if R=0 Then Begin
   Diagnostic('division par zero');V:=0
  End
  else if C='/'Then V:=V div R else V:=V mod R
 End;ParseMul:=V
End;

Function ParseAdd(Var E:TExprParser):LongInt;
Var
 V,R:LongInt;
 C:Char;
Begin
 V:=ParseMul(E);
 While True do Begin
  ExprSkip(E);if E.P>Length(E.S)Then Break;C:=E.S[E.P];
  if not(C in['+','-'])Then Break;Inc(E.P);R:=ParseMul(E);if C='+'Then V:=V+R else V:=V-R
 End;ParseAdd:=V
End;

Function ParseExprOr(Var E:TExprParser):LongInt;
Var
 V,R:LongInt;
 C:Char;
Begin
 V:=ParseAdd(E);
 While True do Begin
  ExprSkip(E);if E.P>Length(E.S)Then Break;C:=E.S[E.P];
  if not(C in['&','|','^'])Then Break;Inc(E.P);R:=ParseAdd(E);
  if C='&'Then V:=V and R else if C='|'Then V:=V or R else V:=V xor R
 End;ParseExprOr:=V
End;

Function Eval(Const S:String;Var ForwardRef:Boolean):LongInt;
Var
 E:TExprParser;
 V:LongInt;
Begin
 E.S:=TrimString(S);E.P:=1;E.ForwardRef:=False;V:=ParseExprOr(E);ExprSkip(E);
 if E.P<=Length(E.S)Then Diagnostic('caracteres superflus dans expression: '+Copy(E.S,E.P,
 255));
 ForwardRef:=E.ForwardRef;Eval:=V
End;

Function RegisterNumber(S:String;Kind:Char):Integer;
Var
 N,E,P:Integer;
 U:String;
 K:PPredefName;
Begin
 U:=UpperString(TrimString(S));RegisterNumber:=-1;
 K:=FindPredefName(U,3);if K=Nil Then Exit;
 if Kind='B'Then Begin
  if(Length(U)<3)or not((Copy(U,1,2)='RH')or(Copy(U,1,2)='RL'))Then Exit;
  Val(Copy(U,3,255),N,E);if(E=0)and(N>=0)and(N<=7)Then Begin
   if U[2]='L'Then Inc(N,8);RegisterNumber:=N
  End;Exit
 End;
 if Kind in['L','Q']Then P:=3 else P:=2;
 if Kind='L'Then Begin
  if Copy(U,1,2)<>'RR'Then Exit
 End else if Kind='Q'Then Begin
  if Copy(U,1,2)<>'RQ'Then Exit
 End else if U[1]<>'R'Then Exit;
 Val(Copy(U,P,255),N,E);if E<>0 Then Exit;
 if Kind='L'Then Begin
  if(N>=0)and(N<=14)and((N and 1)=0)Then RegisterNumber:=N
 End else if Kind='Q'Then Begin
  if(N>=0)and(N<=12)and((N and 3)=0)Then RegisterNumber:=N
 End
 else if(N>=0)and(N<=15)Then RegisterNumber:=N
End;

Function ConditionNumber(S:String):Integer;
Var
 U:String;
 P:PPredefName;
Begin
 U:=UpperString(TrimString(S));ConditionNumber:=-1;
 P:=FindPredefName(U,3);
 if(P<>Nil)and((P^.Value and $FF00)=$1400)Then Begin
  ConditionNumber:=P^.Value and 15;Exit
 End;
 if(U='F')Then ConditionNumber:=0 else if U='LT'Then ConditionNumber:=1
 else if U='LE'Then ConditionNumber:=2 else if U='ULE'Then ConditionNumber:=3
 else if(U='OV')or(U='PE')Then ConditionNumber:=4 else if U='MI'Then ConditionNumber:=5
 else if(U='Z')or(U='EQ')Then ConditionNumber:=6 else if(U='C')or(U='ULT')
 Then ConditionNumber:=7
 else if U='T'Then ConditionNumber:=8 else if U='GE'Then ConditionNumber:=9
 else if U='GT'Then ConditionNumber:=10 else if U='UGT'Then ConditionNumber:=11
 else if(U='NOV')or(U='PO')Then ConditionNumber:=12 else if U='PL'Then ConditionNumber:=13
 else if(U='NZ')or(U='NE')Then ConditionNumber:=14 else if(U='NC')or(U='UGE')
 Then ConditionNumber:=15
End;

Procedure EncodeRegReg(Const Op:String;Base:Word;Kind:Char);
Var
 S,A,B:String;
 Rd,Rs:Integer;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);if(S<>'')or(A='')or(B='')Then Begin
  Diagnostic('deux registres attendus');Exit
 End;Rd:=RegisterNumber(A,Kind);Rs:=RegisterNumber(B,Kind);
 if(Rd<0)or(Rs<0)Then Begin
  Diagnostic('registre incompatible');Exit
 End;
 EmitWord(Base or Word(Rs shl 4)or Word(Rd))
End;

Procedure EncodeLoad;
Var
 S,A,B:String;
 Rd,Rs:Integer;
 V:LongInt;
 F:Boolean;
 K:Char;
 Base,RelBase:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);if(A='')or(B='')or(S<>'')Then Begin
  Diagnostic('LD exige deux operandes');Exit
 End;
 if OpcodeField='LDB'Then Begin
  K:='B';Base:=$D800
 End else if OpcodeField='LDL'Then Begin
  K:='L';Base:=$D500
 End
 else
 Begin
  K:='W';Base:=$D900
 End;
 Rd:=RegisterNumber(A,K);Rs:=RegisterNumber(B,K);
 if(Rd>=0)and(Rs>=0)Then Begin
  EmitWord(Base or Word(Rs shl 4)or Word(Rd));Exit
 End;
 if(Rd>=0)and(Length(B)>0)and(B[1]='#')Then Begin
  Delete(B,1,1);V:=EvalReloc(B,F,RelBase);
  if K='B'Then Begin
   EmitWord($2100 or Rd);EmitByteReloc(Byte(V),RAA8,RelBase);EmitByte(0)
  End
  else if K='L'Then Begin
   EmitWord($1400 or Rd);
   if Opt.Segmented and(RelBase<>0)Then
    EmitLongReloc(SegmentedLongValue(V,RelBase),RAZLS,RelBase)
   else EmitLongReloc(V,RAA32M,RelBase)
  End
  else
  Begin
   EmitWord($2100 or Rd);
   if Opt.Segmented Then EmitWordReloc(Word(V),RAZOF,RelBase)
   else EmitWordReloc(Word(V),RAA16M,RelBase)
  End;Exit
 End;
 Diagnostic('forme LD non prise en charge ou operande incorrect')
End;

Procedure DataDirective(Size:Integer);
Var
 S,A:String;
 V:LongInt;
 F:Boolean;
 I:Integer;
 Base:Word;
Begin
 S:=OperandField;
 While S<>''do Begin
  A:=NextOperand(S);
  if(Size=1)and(Length(A)>=2)and(A[1]='"')and(A[Length(A)]='"')Then
  For I:=2 to Length(A)-1 do EmitByte(Ord(A[I]))
  else
  Begin
   V:=EvalReloc(A,F,Base);if Size=1 Then Begin
    if(Pass=2)and not F and((V< -128)or(V>255))Then Diagnostic('octet hors plage');
    EmitByteReloc(Byte(V),RAA8,Base)
   End else if Size=2 Then Begin
    if(Pass=2)and not F and((V< -32768)or(V>65535))Then Diagnostic('mot hors plage');
    if Opt.Segmented Then EmitWordReloc(Word(V),RAZOF,Base)
    else EmitWordReloc(Word(V),RAA16M,Base)
   End else if Opt.Segmented and(Base<>0)Then
    EmitLongReloc(SegmentedLongValue(V,Base),RAZLS,Base)
   else EmitLongReloc(V,RAA32M,Base)
  End
 End
End;

Procedure SelectNamedSection;
Var S,Name,A,U:String;Section:Byte;
Begin
 S:=OperandField;Name:=NextOperand(S);A:=NextOperand(S);U:=UpperString(A);
 if Name=''Then Begin Diagnostic('SECTION exige un nom');Exit End;
 if(U='DATA')or(U='WRITE')Then Section:=SecData
 else if(U='BSS')or(U='COMMON')or(U='UNINITIALIZED')Then Section:=SecBss
 else Section:=SecText;
 CurrentSection:=Section;SectionObjectName[Section]:=Name;
 SectionAttributes[Section]:=0;
 While S<>''do Begin
  U:=UpperString(NextOperand(S));
  if U='GLOBAL'Then SectionAttributes[Section]:=SectionAttributes[Section]or 1
  else if U='READONLY'Then SectionAttributes[Section]:=SectionAttributes[Section]or 2
  else if U='PURE'Then SectionAttributes[Section]:=SectionAttributes[Section]or 4
  else if U='COMMON'Then SectionAttributes[Section]:=SectionAttributes[Section]or 8
  else if U='ABSOLUTE'Then SectionAttributes[Section]:=SectionAttributes[Section]or 16
  else Diagnostic('attribut de section inconnu: '+U)
 End;
 if Opt.Segmented and(Length(Name)>8)Then
  Diagnostic('nom de section segmente limite a huit caracteres')
End;

Procedure DeclareCommon;
Var S,N,T:String;V:LongInt;F:Boolean;P:PSymbol;
Begin
 S:=OperandField;N:=NextOperand(S);T:=NextOperand(S);
 if(N='')or(T='')Then Begin Diagnostic('COMMON exige nom,taille');Exit End;
 V:=Eval(T,F);if V<0 Then Begin Diagnostic('taille COMMON negative');Exit End;
 P:=GetSymbol(N);
 if(P^.Defined)and(P^.Section<>SecBss)Then Diagnostic('COMMON incompatible avec '+N)
 else Begin
  P^.Defined:=True;P^.Global:=True;P^.Section:=SecBss;P^.Value:=Location[SecBss];
  Inc(Location[SecBss],V)
 End
End;

Function DeclarationSize(Const Name:String):LongInt;
Var U:String;
Begin
 U:=UpperString(TrimString(Name));
 if(U='BYTE')or(U='CHAR')Then DeclarationSize:=1
 else if(U='LONG')or(U='DWORD')Then DeclarationSize:=4
 else if U='QUAD'Then DeclarationSize:=8
 else DeclarationSize:=2
End;

Procedure TypedDeclaration(Size:Integer);
Var S:String;
Begin
 S:=TrimString(OperandField);
 if(S='')Then Inc(Location[CurrentSection],Size)
 else DataDirective(Size)
End;

Procedure StructuredDeclaration(IsArray:Boolean);
Var S,A,B:String;Count,Size:LongInt;F:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if IsArray Then Begin
  Count:=Eval(A,F);if B=''Then B:='BYTE';Size:=DeclarationSize(B);
  if Count<0 Then Diagnostic('dimension de tableau negative')
  else if Count>65535 div Size Then Diagnostic('tableau trop grand')
  else Inc(Location[CurrentSection],Count*Size)
 End else Begin
  if A=''Then A:=B;Size:=Eval(A,F);
  if Size<0 Then Diagnostic('taille RECORD negative')else Inc(Location[CurrentSection],Size)
 End
End;

Function NewStructureLabel(Const Suffix:String):String;
Var N:String;
Begin
 Inc(StructureSerial);Str(StructureSerial,N);NewStructureLabel:='_Z'+N+Suffix
End;

Procedure EmitStructureJump(Const Condition,Destination:String;Invert:Boolean);
Var C:Integer;V:LongInt;F:Boolean;Base:Word;W:Word;
Begin
 if Condition=''Then C:=8 else Begin
  C:=ConditionNumber(Condition);
  if C<0 Then Begin Diagnostic('condition structuree inconnue: '+Condition);C:=8 End;
  if Invert Then C:=C xor 8
 End;
 V:=EvalReloc(Destination,F,Base);W:=$5E00 or Word(C);
 EmitWord(W);
 if Opt.Segmented Then EmitWordReloc(Word(V),RAZOF,Base)
 else EmitWordReloc(Word(V),RAA16M,Base)
End;

Procedure BeginStructuredBlock(Kind:Char);
Var C:String;
Begin
 if StructureDepth=32 Then Begin Diagnostic('structures trop imbriquees');Exit End;
 Inc(StructureDepth);StructureKind[StructureDepth]:=Kind;StructureHasElse[StructureDepth]:=False;
 StructureStart[StructureDepth]:=NewStructureLabel('S');
 StructureFalse[StructureDepth]:=NewStructureLabel('F');
 StructureEnd[StructureDepth]:=NewStructureLabel('E');C:=TrimString(OperandField);
 if Kind in['D','R']Then Begin
  DefineSymbol(StructureStart[StructureDepth],Location[CurrentSection],CurrentSection);
  if(Kind='D')and(C<>'')Then EmitStructureJump(C,StructureEnd[StructureDepth],True)
 End
 else EmitStructureJump(C,StructureFalse[StructureDepth],True)
End;

Procedure EndStructuredBlock(Kind:Char);
Var C:String;
Begin
 if(StructureDepth=0)or(StructureKind[StructureDepth]<>Kind)Then Begin
  Diagnostic('fin de structure sans debut correspondant');Exit
 End;
 C:=TrimString(OperandField);
 if Kind='D'Then Begin
  EmitStructureJump(C,StructureStart[StructureDepth],False);
  DefineSymbol(StructureEnd[StructureDepth],Location[CurrentSection],CurrentSection)
 End
 else if Kind='R'Then Begin
  EmitStructureJump(C,StructureStart[StructureDepth],True);
  DefineSymbol(StructureEnd[StructureDepth],Location[CurrentSection],CurrentSection)
 End
 else Begin
  if StructureHasElse[StructureDepth]Then
   DefineSymbol(StructureEnd[StructureDepth],Location[CurrentSection],CurrentSection)
  else DefineSymbol(StructureFalse[StructureDepth],Location[CurrentSection],CurrentSection)
 End;
 Dec(StructureDepth)
End;

Procedure StructuredElse;
Begin
 if(StructureDepth=0)or not(StructureKind[StructureDepth]in['I','C'])Then Begin
  Diagnostic('ELSE sans IF ou CASE');Exit
 End;
 if StructureHasElse[StructureDepth]Then Begin Diagnostic('ELSE repete');Exit End;
 EmitStructureJump('',StructureEnd[StructureDepth],False);
 DefineSymbol(StructureFalse[StructureDepth],Location[CurrentSection],CurrentSection);
 StructureHasElse[StructureDepth]:=True
End;

Procedure StructuredExit;
Var I:Integer;
Begin
 I:=StructureDepth;While(I>0)and not(StructureKind[I]in['D','R'])do Dec(I);
 if I=0 Then Diagnostic('EXIT hors d''une boucle')
 else EmitStructureJump('',StructureEnd[I],False)
End;

Procedure ProcessDirective;
Var
 V:LongInt;
 F:Boolean;
 S,A:String;
 P:PSymbol;
 Base:Word;I:Integer;
Begin
 if OpcodeField='IF'Then BeginStructuredBlock('I')
 else if OpcodeField='CASE'Then BeginStructuredBlock('C')
 else if OpcodeField='ELSE'Then StructuredElse
 else if(OpcodeField='FI')or(OpcodeField='ENDIF')Then EndStructuredBlock('I')
 else if OpcodeField='ENDCASE'Then EndStructuredBlock('C')
 else if OpcodeField='DO'Then BeginStructuredBlock('D')
 else if OpcodeField='OD'Then EndStructuredBlock('D')
 else if OpcodeField='REPEAT'Then BeginStructuredBlock('R')
 else if OpcodeField='UNTIL'Then Begin
  if TrimString(OperandField)=''Then Diagnostic('UNTIL exige une condition');
  EndStructuredBlock('R')
 end
 else if OpcodeField='EXIT'Then StructuredExit
 else if(OpcodeField='TEXT')or(OpcodeField='.TEXT')or(OpcodeField='CSEG')Then CurrentSection:=
 SecText
 else if(OpcodeField='DATA')or(OpcodeField='.DATA')or(OpcodeField='DSEG')
 Then CurrentSection:=SecData
 else if(OpcodeField='BSS')or(OpcodeField='.BSS')Then CurrentSection:=SecBss
 else if(OpcodeField='EQU')or(OpcodeField='=')Then Begin
  V:=Eval(OperandField,F);DefineSymbol(LabelField,V,SecAbsolute)
 End
 else if(OpcodeField='DB')or(OpcodeField='DEFB')or(OpcodeField='.BYTE')Then DataDirective(
 1)
 else if(OpcodeField='DW')or(OpcodeField='DEFW')or(OpcodeField='.WORD')Then DataDirective(
 2)
 else if(OpcodeField='DL')or(OpcodeField='DEFL')or(OpcodeField='.LONG')Then DataDirective(
 4)
 else if(OpcodeField='SADDR')or(OpcodeField='.SADDR')Then Begin
  if not Opt.Segmented Then Diagnostic('SADDR exige la cible Z8001 segmentee');
  V:=EvalReloc(OperandField,F,Base);
  if(Pass=2)and not F and((V<0)or(V>255))Then Diagnostic('offset segmente court hors plage');
  EmitWordReloc(SegmentedShortValue(V,Base),RAZSS,Base)
 End
 else if OpcodeField='CONSTANT'Then Begin
  S:=TrimString(OperandField);I:=Pos(':=',S);
  if I<>0 Then S:=Copy(S,I+2,255)else Begin
   I:=Pos('=',S);if I<>0 Then S:=Copy(S,I+1,255)
  End;
  if S=''Then Diagnostic('valeur CONSTANT attendue')
  else Begin V:=Eval(TrimString(S),F);DefineSymbol(LabelField,V,SecAbsolute) End
 End
 else if OpcodeField='BYTE'Then TypedDeclaration(1)
 else if OpcodeField='WORD'Then TypedDeclaration(2)
 else if OpcodeField='LONG'Then TypedDeclaration(4)
 else if OpcodeField='ARRAY'Then StructuredDeclaration(True)
 else if OpcodeField='RECORD'Then StructuredDeclaration(False)
 else if OpcodeField='PROCEDURE'Then Begin
  S:=LabelField;if S=''Then S:=TrimString(OperandField);
  if S=''Then Diagnostic('PROCEDURE exige un nom')else CurrentGlobal:=S
 End
 else if OpcodeField='ENDPROC'Then CurrentGlobal:=''
 else if(OpcodeField='DS')or(OpcodeField='DEFS')or(OpcodeField='.SPACE')or(OpcodeField=
 'BLOCK')Then Begin
  V:=Eval(OperandField,F);
  if V<0 Then Diagnostic('taille negative')else Inc(Location[CurrentSection],V)
 End
 else if(OpcodeField='EVEN')or(OpcodeField='.EVEN')Then Begin
  if(Location[CurrentSection]and 1)<>0 Then EmitByte(0)
 End
 else if(OpcodeField='ALIGN')or(OpcodeField='.ALIGN')Then Begin
  V:=Eval(OperandField,F);
  if V<=0 Then Diagnostic('alignement incorrect')else
  While(Location[CurrentSection]mod V)<>0 do EmitByte(0)
 End
 else if(OpcodeField='ORG')or(OpcodeField='.ORG')Then Begin
  V:=Eval(OperandField,F);
  if V<Location[CurrentSection]Then Diagnostic('ORG en arriere')else
  While Location[CurrentSection]<V do EmitByte(0)
 End
 else if(OpcodeField='GLOBAL')or(OpcodeField='.GLOBAL')or(OpcodeField='PUBLIC')Then Begin
  S:=OperandField;
  While S<>''do Begin
   A:=NextOperand(S);P:=GetSymbol(A);P^.Global:=True
  End
 End
 else if(OpcodeField='EXTERN')or(OpcodeField='.EXTERN')or(OpcodeField='EXTERNAL')
 Then Begin
  S:=OperandField;
  While S<>''do Begin
   A:=NextOperand(S);P:=GetSymbol(A);P^.Global:=True;P^.External:=True
  End
 End
 else if OpcodeField='MODULE'Then Begin
  S:=TrimString(OperandField);if S=''Then S:=LabelField;
  if S=''Then Diagnostic('MODULE exige un nom')
  else if ModuleActive Then Diagnostic('MODULE imbrique interdit')
  else Begin ModuleActive:=True;ModuleClosed:=False;ObjectModuleName:=S End
 End
 else if OpcodeField='ENDMODULE'Then Begin
  if not ModuleActive Then Diagnostic('ENDMODULE sans MODULE');
  ModuleActive:=False;ModuleClosed:=True;StopAssembly:=True
 End
 else if(OpcodeField='SECTION')or(OpcodeField='.SECT')Then SelectNamedSection
 else if(OpcodeField='COMMON')or(OpcodeField='.COMMON')Then DeclareCommon
 else if(OpcodeField='END')or(OpcodeField='.END')Then Begin
  if OperandField<>''Then Begin
   TransferAddress:=EvalReloc(OperandField,F,TransferBase);HasTransfer:=True
  End;
  StopAssembly:=True
 End
 else if OpcodeField='CODE'Then CurrentSection:=SecText
 else Diagnostic('directive inconnue: '+OpcodeField)
End;

Procedure EmitDirectAddress(V:LongInt;Base:Word;ForceShort:Boolean);Forward;

Type
 TOperandKind=(okInvalid,okRegister,okImmediate,okIndirect,okDirect,okIndexed,okBase,
  okBaseIndex);
 TOperand=Record
  Kind:TOperandKind;
  Reg,IndexReg:Integer;
  Value:LongInt;
  RelBase:Word;
  ForwardRef,ForceShort:Boolean
 End;

Procedure ParseOperand(S:String;RegKind:Char;Var O:TOperand);
Var P:Integer;Left,Inside:String;
Begin
 FillChar(O,SizeOf(O),0);O.Kind:=okInvalid;O.Reg:=-1;O.IndexReg:=-1;S:=TrimString(S);
 if S=''Then Exit;
 O.Reg:=RegisterNumber(S,RegKind);if O.Reg>=0 Then Begin O.Kind:=okRegister;Exit End;
 if S[1]='#'Then Begin
  Delete(S,1,1);O.Value:=EvalReloc(S,O.ForwardRef,O.RelBase);O.Kind:=okImmediate;Exit
 End;
 if S[1]='@'Then Begin
  Delete(S,1,1);O.Reg:=RegisterNumber(S,'W');
  if O.Reg<0 Then Begin
   O.Reg:=RegisterNumber(S,'L');
   if(O.Reg>=0)and not Opt.Segmented Then Begin
    Diagnostic('pointeur @RRn reserve au Z8001 segmente');O.Reg:=-1
   End
  End;
  if O.Reg>=0 Then O.Kind:=okIndirect;Exit
 End;
 if S[1]='|'Then Begin
  if not Opt.Segmented Then Diagnostic('adresse segmentee courte interdite dans un source .8KN');
  O.ForceShort:=True;Delete(S,1,1);S:=TrimString(S)
 End;
 P:=Pos('(',S);
 if(P>1)and(S[Length(S)]=')')Then Begin
  Left:=TrimString(Copy(S,1,P-1));Inside:=TrimString(Copy(S,P+1,Length(S)-P-1));
  if Opt.Segmented Then O.Reg:=RegisterNumber(Left,'L')else O.Reg:=RegisterNumber(Left,'W');
  if O.Reg>=0 Then Begin
   if(Inside<>'')and(Inside[1]='#')Then Begin
    Delete(Inside,1,1);O.Value:=EvalReloc(Inside,O.ForwardRef,O.RelBase);O.Kind:=okBase
   End else Begin
    O.IndexReg:=RegisterNumber(Inside,'W');if O.IndexReg>=0 Then O.Kind:=okBaseIndex
   End;Exit
  End;
  O.IndexReg:=RegisterNumber(Inside,'W');if O.IndexReg<0 Then Begin O.Kind:=okInvalid;Exit End;
  O.Value:=EvalReloc(Left,O.ForwardRef,O.RelBase);O.Kind:=okIndexed;Exit
 End;
 O.Value:=EvalReloc(S,O.ForwardRef,O.RelBase);O.Kind:=okDirect
End;

Procedure EmitOperandAddress(Var O:TOperand);
Begin
 Case O.Kind of
 okDirect,okIndexed:EmitDirectAddress(O.Value,O.RelBase,O.ForceShort);
 okBase:EmitWordReloc(Word(O.Value),RAA16M,O.RelBase);
 okBaseIndex:EmitWord(Word(O.IndexReg shl 8))
 End
End;

Procedure EmitImmediateValue(Size:Integer;V:LongInt;RelBase:Word;DuplicateByte:Boolean);
Begin
 if Size=1 Then Begin
  EmitByteReloc(Byte(V),RAA8,RelBase);
  if DuplicateByte Then EmitByteReloc(Byte(V),RAA8,RelBase)
 End else if Size=2 Then Begin
  if Opt.Segmented Then EmitWordReloc(Word(V),RAZOF,RelBase)
  else EmitWordReloc(Word(V),RAA16M,RelBase)
 End else if Opt.Segmented and(RelBase<>0)Then
  EmitLongReloc(SegmentedLongValue(V,RelBase),RAZLS,RelBase)
 else EmitLongReloc(V,RAA32M,RelBase)
End;

Procedure EncodeALU(RegKind:Char;Size:Integer;BaseRR,BaseImm,BaseMem:Word);
Var S,A,B:String;D,Src:TOperand;W:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);ParseOperand(A,RegKind,D);
 ParseOperand(B,RegKind,Src);
 if(D.Kind<>okRegister)or(S<>'')Then Begin Diagnostic('registre destination attendu');Exit End;
 Case Src.Kind of
 okRegister:EmitWord(BaseRR or Word(Src.Reg shl 4)or Word(D.Reg));
 okImmediate:Begin
  EmitWord(BaseImm or Word(D.Reg));EmitImmediateValue(Size,Src.Value,Src.RelBase,Size=1)
 End;
 okIndirect:EmitWord(BaseImm or Word(Src.Reg shl 4)or Word(D.Reg));
 okDirect,okIndexed:Begin
  W:=BaseMem or Word(D.Reg);if Src.Kind=okIndexed Then W:=W or Word(Src.IndexReg shl 4);
  EmitWord(W);EmitOperandAddress(Src)
 End;
 else Diagnostic('mode source non permis pour cette instruction')
 End
End;

Procedure EncodeLoadFull;
Var S,A,B:String;D,Src:TOperand;K:Char;Size:Integer;RR,Imm,Mem,Based,BIndex:Word;W:Word;
Begin
 if OpcodeField='LDB'Then Begin K:='B';Size:=1;RR:=$A000;Imm:=$2000;Mem:=$6000;Based:=$3000;BIndex:=$7000 End
 else if OpcodeField='LDL'Then Begin K:='L';Size:=4;RR:=$9400;Imm:=$1400;Mem:=$5400;Based:=$3500;BIndex:=$7500 End
 else Begin K:='W';Size:=2;RR:=$A100;Imm:=$2100;Mem:=$6100;Based:=$3100;BIndex:=$7100 End;
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);ParseOperand(A,K,D);ParseOperand(B,K,Src);
 if(A='')or(B='')or(S<>'')Then Begin Diagnostic('LD exige deux operandes');Exit End;
 if D.Kind=okRegister Then Case Src.Kind of
  okRegister:EmitWord(RR or Word(Src.Reg shl 4)or Word(D.Reg));
  okImmediate:if Size=1 Then Begin
   EmitByte($C0 or Byte(D.Reg));EmitByteReloc(Byte(Src.Value),RAA8,Src.RelBase)
  End else Begin
   EmitWord(Imm or Word(D.Reg));EmitImmediateValue(Size,Src.Value,Src.RelBase,False)
  End;
  okIndirect:EmitWord(Imm or Word(Src.Reg shl 4)or Word(D.Reg));
  okDirect,okIndexed:Begin W:=Mem or Word(D.Reg);if Src.Kind=okIndexed Then W:=W or Word(Src.IndexReg shl 4);
   EmitWord(W);EmitOperandAddress(Src) End;
  okBase:Begin EmitWord(Based or Word(Src.Reg shl 4)or Word(D.Reg));EmitOperandAddress(Src) End;
  okBaseIndex:Begin EmitWord(BIndex or Word(Src.Reg shl 4)or Word(D.Reg));EmitOperandAddress(Src) End;
  else Diagnostic('mode source LD incorrect')
 End else if Src.Kind=okRegister Then Begin
  if Size=1 Then Begin Imm:=$2E00;Mem:=$6E00;Based:=$3200;BIndex:=$7200 End
  else if Size=4 Then Begin Imm:=$1D00;Mem:=$5D00;Based:=$3700;BIndex:=$7700 End
  else Begin Imm:=$2F00;Mem:=$6F00;Based:=$3300;BIndex:=$7300 End;
  Case D.Kind of
  okIndirect:EmitWord(Imm or Word(D.Reg shl 4)or Word(Src.Reg));
  okDirect,okIndexed:Begin W:=Mem or Word(Src.Reg);if D.Kind=okIndexed Then W:=W or Word(D.IndexReg shl 4);
   EmitWord(W);EmitOperandAddress(D) End;
  okBase:Begin EmitWord(Based or Word(D.Reg shl 4)or Word(Src.Reg));EmitOperandAddress(D) End;
  okBaseIndex:Begin EmitWord(BIndex or Word(D.Reg shl 4)or Word(Src.Reg));EmitOperandAddress(D) End;
  else Diagnostic('mode destination LD incorrect')
  End
 End else if Src.Kind=okImmediate Then Begin
  if Size=4 Then Begin Diagnostic('immediat long vers memoire non defini par le Z8000');Exit End;
  if Size=1 Then Begin Imm:=$0C05;Mem:=$4C05 End else Begin Imm:=$0D05;Mem:=$4D05 End;
  if D.Kind=okIndirect Then EmitWord(Imm or Word(D.Reg shl 4))
  else if D.Kind in[okDirect,okIndexed]Then Begin
   W:=Mem;if D.Kind=okIndexed Then W:=W or Word(D.IndexReg shl 4);EmitWord(W);EmitOperandAddress(D)
  End else Begin Diagnostic('mode destination pour immediat incorrect');Exit End;
  EmitImmediateValue(Size,Src.Value,Src.RelBase,Size=1)
 End else Diagnostic('combinaison d''operandes LD non prise en charge')
End;

Procedure EncodeJumpFull;
Var S,A,B,Target:String;C:Integer;V,D:LongInt;F,Conditional:Boolean;RelBase:Word;O:TOperand;W:Word;
Begin
 if OpcodeField='RET'Then Begin
  S:=TrimString(OperandField);
  if S=''Then EmitWord($9E08)else Begin
   C:=ConditionNumber(S);if C<0 Then Diagnostic('condition RET incorrecte')
   else EmitWord($9E00 or Word(C))
  End;Exit
 End;
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);Conditional:=B<>'';
 if Conditional Then Begin C:=ConditionNumber(A);Target:=B End
 else Begin C:=8;Target:=A End;
 if(C<0)or(Target='')or(S<>'')Then Begin Diagnostic('operandes de saut incorrects');Exit End;
 if OpcodeField='JR'Then Begin
  V:=EvalReloc(Target,F,RelBase);D:=V-(Location[CurrentSection]+2);
  if(Pass=2)and(RelBase<>CurrentSection)Then Diagnostic('saut relatif vers une autre section');
  if(Pass=2)and(((D and 1)<>0)or(D< -256)or(D>254))Then Diagnostic('saut relatif hors plage');
  D:=D div 2;if Conditional Then W:=$E000 or Word(C shl 8)else W:=$E800;
  EmitWord(W or Word(Byte(D)));Exit
 End;
 ParseOperand(Target,'W',O);
 if O.Kind=okIndirect Then Begin
  if Conditional Then W:=$1E00 or Word(C)else W:=$1E08;
  EmitWord(W or Word(O.Reg shl 4))
 End else if O.Kind in[okDirect,okIndexed]Then Begin
  if Conditional Then W:=$5E00 or Word(C)else W:=$5E08;
  if O.Kind=okIndexed Then W:=W or Word(O.IndexReg shl 4);
  EmitWord(W);EmitOperandAddress(O)
 End else Diagnostic('JP exige @registre, adresse ou adresse indexee')
End;

Procedure EncodeUnaryRegister(Base:Word;Kind:Char);Forward;
Function IndirectRegister(S:String;Var R:Integer):Boolean;Forward;
Procedure EncodeMulDiv(BaseRR,BaseImm:Word;DestKind,SourceKind:Char);Forward;
Procedure EncodeBitInstruction(BaseReg,BaseImm:Word;Kind:Char);Forward;
Procedure EncodeShiftRotate(Base:Word;Kind:Char;RightShift:Boolean);Forward;
Procedure EncodeCall;Forward;
Procedure EncodeRelative12;Forward;
Procedure EncodeDJNZ(ByteForm:Boolean);Forward;
Procedure EncodePushPop(IsPop:Boolean);Forward;
Procedure EncodePushPopLong(IsPop:Boolean);Forward;
Procedure EncodeTCC(ByteForm:Boolean);Forward;
Procedure EncodeFlags(Base:Word);Forward;
Procedure EncodeLDCTL(ByteForm:Boolean);Forward;
Procedure EncodeString3(Base:Word;FirstInWord2:Boolean;TailNibble:Byte);Forward;
Procedure EncodeIO(IsOut,ByteForm,Special:Boolean);Forward;
Procedure EncodeLDA;Forward;
Procedure EncodeLDAR;Forward;
Procedure EncodeLDR;Forward;
Procedure EncodeLDM;Forward;
Procedure EncodeCompareString(Base:Word);Forward;
Procedure EncodeIncDec(IsDec,ByteForm:Boolean);Forward;

Procedure ProcessInstruction;
Var
 V:LongInt;
 F:Boolean;
 R:Integer;
 S:String;
Begin
 if FindPredefName(OpcodeField,1)=Nil Then Begin
  Diagnostic('mnemonique absent de ASZ8K.PD: '+OpcodeField);Exit
 End;
 if(OpcodeField='LD')or(OpcodeField='LDB')or(OpcodeField='LDL')Then EncodeLoadFull
 else if OpcodeField='ADD'Then EncodeALU('W',2,$8100,$0100,$4100)
 else if OpcodeField='ADDB'Then EncodeALU('B',1,$8000,$0000,$4000)
 else if OpcodeField='ADDL'Then EncodeALU('L',4,$9600,$1600,$5600)
 else if OpcodeField='ADC'Then EncodeRegReg(OpcodeField,$B500,'W')
 else if OpcodeField='ADCB'Then EncodeRegReg(OpcodeField,$B400,'B')
 else if OpcodeField='SUB'Then EncodeALU('W',2,$8300,$0300,$4300)
 else if OpcodeField='SUBB'Then EncodeALU('B',1,$8200,$0200,$4200)
 else if OpcodeField='SUBL'Then EncodeALU('L',4,$9200,$1200,$5200)
 else if OpcodeField='CP'Then EncodeALU('W',2,$8B00,$0B00,$4B00)
 else if OpcodeField='CPB'Then EncodeALU('B',1,$8A00,$0A00,$4A00)
 else if OpcodeField='CPL'Then EncodeALU('L',4,$9000,$1000,$5000)
 else if OpcodeField='AND'Then EncodeALU('W',2,$8700,$0700,$4700)
 else if OpcodeField='ANDB'Then EncodeALU('B',1,$8600,$0600,$4600)
 else if OpcodeField='OR'Then EncodeALU('W',2,$8500,$0500,$4500)
 else if OpcodeField='ORB'Then EncodeALU('B',1,$8400,$0400,$4400)
 else if OpcodeField='XOR'Then EncodeALU('W',2,$8900,$0900,$4900)
 else if OpcodeField='XORB'Then EncodeALU('B',1,$8800,$0800,$4800)
 else if OpcodeField='SBC'Then EncodeRegReg(OpcodeField,$B700,'W')
 else if OpcodeField='SBCB'Then EncodeRegReg(OpcodeField,$B600,'B')
 else if OpcodeField='EX'Then EncodeRegReg(OpcodeField,$AD00,'W')
 else if OpcodeField='EXB'Then EncodeRegReg(OpcodeField,$AC00,'B')
 else if OpcodeField='RLDB'Then EncodeRegReg(OpcodeField,$BE00,'B')
 else if OpcodeField='RRDB'Then EncodeRegReg(OpcodeField,$BC00,'B')
 else if OpcodeField='NEG'Then EncodeUnaryRegister($8D02,'W')
 else if OpcodeField='NEGB'Then EncodeUnaryRegister($8C02,'B')
 else if OpcodeField='CLR'Then EncodeUnaryRegister($8D08,'W')
 else if OpcodeField='CLRB'Then EncodeUnaryRegister($8C08,'B')
 else if OpcodeField='COM'Then EncodeUnaryRegister($8D00,'W')
 else if OpcodeField='COMB'Then EncodeUnaryRegister($8C00,'B')
 else if OpcodeField='TEST'Then EncodeUnaryRegister($8D04,'W')
 else if OpcodeField='TESTB'Then EncodeUnaryRegister($8C04,'B')
 else if OpcodeField='TESTL'Then EncodeUnaryRegister($9C08,'L')
 else if OpcodeField='TSET'Then EncodeUnaryRegister($8D06,'W')
 else if OpcodeField='TSETB'Then EncodeUnaryRegister($8C06,'B')
 else if OpcodeField='DAB'Then EncodeUnaryRegister($B000,'B')
 else if OpcodeField='EXTS'Then EncodeUnaryRegister($B10A,'L')
 else if OpcodeField='EXTSB'Then EncodeUnaryRegister($B100,'W')
 else if OpcodeField='EXTSL'Then EncodeUnaryRegister($B107,'Q')
 else if OpcodeField='MULT'Then EncodeMulDiv($9900,$1900,'L','W')
 else if OpcodeField='DIV'Then EncodeMulDiv($9B00,$1B00,'L','W')
 else if OpcodeField='MULTL'Then EncodeMulDiv($9800,$1800,'Q','L')
 else if OpcodeField='DIVL'Then EncodeMulDiv($9A00,$1A00,'Q','L')
 else if OpcodeField='BIT'Then EncodeBitInstruction($2700,$A700,'W')
 else if OpcodeField='BITB'Then EncodeBitInstruction($2600,$A600,'B')
 else if OpcodeField='SET'Then EncodeBitInstruction($2500,$A500,'W')
 else if OpcodeField='SETB'Then EncodeBitInstruction($2400,$A400,'B')
 else if OpcodeField='RES'Then EncodeBitInstruction($2300,$A300,'W')
 else if OpcodeField='RESB'Then EncodeBitInstruction($2200,$A200,'B')
 else if OpcodeField='RL'Then EncodeShiftRotate($B300,'W',False)
 else if OpcodeField='RLB'Then EncodeShiftRotate($B200,'B',False)
 else if OpcodeField='RLC'Then EncodeShiftRotate($B308,'W',False)
 else if OpcodeField='RLCB'Then EncodeShiftRotate($B208,'B',False)
 else if OpcodeField='RR'Then EncodeShiftRotate($B304,'W',True)
 else if OpcodeField='RRB'Then EncodeShiftRotate($B204,'B',True)
 else if OpcodeField='RRC'Then EncodeShiftRotate($B30C,'W',True)
 else if OpcodeField='RRCB'Then EncodeShiftRotate($B20C,'B',True)
 else if OpcodeField='SLA'Then EncodeShiftRotate($B309,'W',False)
 else if OpcodeField='SLAB'Then EncodeShiftRotate($B209,'B',False)
 else if OpcodeField='SLL'Then EncodeShiftRotate($B301,'W',False)
 else if OpcodeField='SLLB'Then EncodeShiftRotate($B201,'B',False)
 else if OpcodeField='SRA'Then EncodeShiftRotate($B309,'W',True)
 else if OpcodeField='SRAB'Then EncodeShiftRotate($B209,'B',True)
 else if OpcodeField='SRL'Then EncodeShiftRotate($B301,'W',True)
 else if OpcodeField='SRLB'Then EncodeShiftRotate($B201,'B',True)
 else if OpcodeField='SLAL'Then EncodeShiftRotate($B30D,'L',False)
 else if OpcodeField='SLLL'Then EncodeShiftRotate($B305,'L',False)
 else if OpcodeField='SRAL'Then EncodeShiftRotate($B30D,'L',True)
 else if OpcodeField='SRLL'Then EncodeShiftRotate($B305,'L',True)
 else if OpcodeField='CALL'Then EncodeCall
 else if OpcodeField='CALR'Then EncodeRelative12
 else if OpcodeField='DJNZ'Then EncodeDJNZ(False)
 else if OpcodeField='DBJNZ'Then EncodeDJNZ(True)
 else if OpcodeField='PUSH'Then EncodePushPop(False)
 else if OpcodeField='POP'Then EncodePushPop(True)
 else if OpcodeField='PUSHL'Then EncodePushPopLong(False)
 else if OpcodeField='POPL'Then EncodePushPopLong(True)
 else if OpcodeField='TCC'Then EncodeTCC(False)
 else if OpcodeField='TCCB'Then EncodeTCC(True)
 else if OpcodeField='SETFLG'Then EncodeFlags($8D01)
 else if OpcodeField='RESFLG'Then EncodeFlags($8D03)
 else if OpcodeField='COMFLG'Then EncodeFlags($8D05)
 else if OpcodeField='LDCTL'Then EncodeLDCTL(False)
 else if OpcodeField='LDCTLB'Then EncodeLDCTL(True)
 else if OpcodeField='LDI'Then EncodeString3($BB01,True,8)
 else if OpcodeField='LDIB'Then EncodeString3($BA01,True,8)
 else if OpcodeField='LDIR'Then EncodeString3($BB01,True,0)
 else if OpcodeField='LDIRB'Then EncodeString3($BA01,True,0)
 else if OpcodeField='LDD'Then EncodeString3($BB09,True,8)
 else if OpcodeField='LDDB'Then EncodeString3($BA09,True,8)
 else if OpcodeField='LDDR'Then EncodeString3($BB09,True,0)
 else if OpcodeField='LDDRB'Then EncodeString3($BA09,True,0)
 else if OpcodeField='TRIB'Then EncodeString3($B800,False,0)
 else if OpcodeField='TRIRB'Then EncodeString3($B804,False,0)
 else if OpcodeField='TRDB'Then EncodeString3($B808,False,0)
 else if OpcodeField='TRDRB'Then EncodeString3($B80C,False,0)
 else if OpcodeField='TRTIB'Then EncodeString3($B802,False,0)
 else if OpcodeField='TRTIRB'Then EncodeString3($B806,False,$E)
 else if OpcodeField='TRTDB'Then EncodeString3($B80A,False,0)
 else if OpcodeField='TRTDRB'Then EncodeString3($B80E,False,$E)
 else if OpcodeField='INI'Then EncodeString3($3B00,True,8)
 else if OpcodeField='INIB'Then EncodeString3($3A00,True,8)
 else if OpcodeField='INIR'Then EncodeString3($3B00,True,0)
 else if OpcodeField='INIRB'Then EncodeString3($3A00,True,0)
 else if OpcodeField='IND'Then EncodeString3($3B08,True,8)
 else if OpcodeField='INDB'Then EncodeString3($3A08,True,8)
 else if OpcodeField='INDR'Then EncodeString3($3B08,True,0)
 else if OpcodeField='INDRB'Then EncodeString3($3A08,True,0)
 else if OpcodeField='OUTI'Then EncodeString3($3B02,True,8)
 else if OpcodeField='OUTIB'Then EncodeString3($3A02,True,8)
 else if OpcodeField='OUTD'Then EncodeString3($3B0A,True,8)
 else if OpcodeField='OUTDB'Then EncodeString3($3A0A,True,8)
 else if OpcodeField='SINI'Then EncodeString3($3B01,True,8)
 else if OpcodeField='SINIB'Then EncodeString3($3A01,True,8)
 else if OpcodeField='SIND'Then EncodeString3($3B09,True,8)
 else if OpcodeField='SINDB'Then EncodeString3($3A09,True,8)
 else if OpcodeField='SOUTI'Then EncodeString3($3B03,True,8)
 else if OpcodeField='SOUTIB'Then EncodeString3($3A03,True,8)
 else if OpcodeField='SOUTD'Then EncodeString3($3B0B,True,8)
 else if OpcodeField='SOUTDB'Then EncodeString3($3A0B,True,8)
 else if OpcodeField='IN'Then EncodeIO(False,False,False)
 else if OpcodeField='INB'Then EncodeIO(False,True,False)
 else if OpcodeField='OUT'Then EncodeIO(True,False,False)
 else if OpcodeField='OUTB'Then EncodeIO(True,True,False)
 else if OpcodeField='SIN'Then EncodeIO(False,False,True)
 else if OpcodeField='SINB'Then EncodeIO(False,True,True)
 else if OpcodeField='SOUT'Then EncodeIO(True,False,True)
 else if OpcodeField='SOUTB'Then EncodeIO(True,True,True)
 else if OpcodeField='LDK'Then EncodeBitInstruction(0,$BD00,'W')
 else if OpcodeField='LDPS'Then Begin
  S:=TrimString(OperandField);if not IndirectRegister(S,R)Then Diagnostic('LDPS exige @registre')
  else EmitWord($3900 or Word(R shl 4))
 End
 else if OpcodeField='LDA'Then EncodeLDA
 else if OpcodeField='LDAR'Then EncodeLDAR
 else if OpcodeField='LDR'Then EncodeLDR
 else if OpcodeField='LDM'Then EncodeLDM
 else if OpcodeField='CPI'Then EncodeCompareString($BB00)
 else if OpcodeField='CPIB'Then EncodeCompareString($BA00)
 else if OpcodeField='CPIR'Then EncodeCompareString($BB04)
 else if OpcodeField='CPIRB'Then EncodeCompareString($BA04)
 else if OpcodeField='CPD'Then EncodeCompareString($BB08)
 else if OpcodeField='CPDB'Then EncodeCompareString($BA08)
 else if OpcodeField='CPDR'Then EncodeCompareString($BB0C)
 else if OpcodeField='CPDRB'Then EncodeCompareString($BA0C)
 else if OpcodeField='MREQ'Then EncodeUnaryRegister($7B0D,'W')
 else if OpcodeField='MRES'Then EmitWord($7B09)
 else if OpcodeField='MBIT'Then EmitWord($7B0A)
 else if OpcodeField='MSET'Then EmitWord($7B08)
 else if OpcodeField='DI'Then EmitWord($7C03)
 else if OpcodeField='EI'Then EmitWord($7C07)
 else if OpcodeField='NOP'Then EmitWord($8D07)
 else if OpcodeField='HALT'Then EmitWord($7A00)
 else if OpcodeField='IRET'Then EmitWord($7B00)
 else if(OpcodeField='JR')or(OpcodeField='JP')or(OpcodeField='RET')Then EncodeJumpFull
 else if OpcodeField='SC'Then Begin
  S:=OperandField;if(S<>'')and(S[1]='#')Then Delete(S,1,1);
  V:=Eval(S,F);if(V<0)or(V>255)Then Diagnostic('numero SC hors plage');
  EmitWord($7F00 or Byte(V))
 End
 else if OpcodeField='INC'Then EncodeIncDec(False,False)
 else if OpcodeField='DEC'Then EncodeIncDec(True,False)
 else if OpcodeField='INCB'Then EncodeIncDec(False,True)
 else if OpcodeField='DECB'Then EncodeIncDec(True,True)
 else Diagnostic('instruction inconnue ou forme non implementee: '+OpcodeField)
End;

Function IsDirective(Const S:String):Boolean;
Var
 U:String;
Begin
 U:=UpperString(S);
 IsDirective:=(FindPredefName(U,2)<>Nil)or(U='TEXT')or(U='.TEXT')or(U='CSEG')or(U='DATA')or(U='.DATA')or
 (U='DSEG')or(U='BSS')or(U='.BSS')or(U='EQU')or(U='=')or(U='DB')or(U='DEFB')or(U='.BYTE')
 or
 (U='DW')or(U='DEFW')or(U='.WORD')or(U='DL')or(U='DEFL')or(U='.LONG')or(U='DS')or(U=
 'DEFS')or
 (U='SADDR')or(U='.SADDR')or
 (U='.SPACE')or(U='BLOCK')or(U='EVEN')or(U='.EVEN')or(U='ALIGN')or(U='.ALIGN')or(U='ORG')
 or
 (U='.ORG')or(U='GLOBAL')or(U='.GLOBAL')or(U='PUBLIC')or(U='EXTERN')or(U='.EXTERN')or
 (U='EXTERNAL')or(U='END')or(U='.END')or(U='ENDMODULE')or(U='MODULE')or(U='CODE')or(U=
 'SECTION')or(U='COMMON')or(U='.COMMON')or(U='INCLUDE')or(U='.INPUT')or
 (U='IF')or(U='.IF')or(U='IFDEF')or(U='IFNDEF')or(U='ELSE')or(U='.ELSE')or
 (U='ENDIF')or(U='.ENDIF')or(U='FI')or(U='DO')or(U='OD')or(U='REPEAT')or
 (U='UNTIL')or(U='EXIT')or(U='CASE')or(U='ENDCASE')or
 (U='PROCEDURE')or(U='ENDPROC')or(U='CONSTANT')or
 (U='BYTE')or(U='WORD')or(U='LONG')or(U='ARRAY')or(U='RECORD')
End;

Function IsConditionalDirective(Const U:String):Boolean;
Begin
 IsConditionalDirective:=(U='.IF')or(U='IFDEF')or(U='IFNDEF')or
 (U='.ELSE')or(U='.ENDIF')
End;

Procedure HandleConditionalDirective;
Var F,Value:Boolean;V:LongInt;U:String;
Begin
 U:=OpcodeField;
 if(U='.IF')or(U='IFDEF')or(U='IFNDEF')Then Begin
  if ConditionalDepth=32 Then Begin Diagnostic('conditionnels trop imbriques');Exit End;
  Inc(ConditionalDepth);ConditionalParent[ConditionalDepth]:=ConditionalEnabled;
  if not ConditionalEnabled Then Value:=False
  else if(U='IFDEF')or(U='IFNDEF')Then Begin
   Value:=FindSymbol(TrimString(OperandField))<>Nil;
   if U='IFNDEF'Then Value:=not Value
  End else Begin V:=Eval(OperandField,F);Value:=V<>0 End;
  ConditionalValue[ConditionalDepth]:=Value;ConditionalElse[ConditionalDepth]:=False;
  ConditionalEnabled:=ConditionalParent[ConditionalDepth]and Value
 End else if U='.ELSE'Then Begin
  if ConditionalDepth=0 Then Begin Diagnostic('ELSE sans IF');Exit End;
  if ConditionalElse[ConditionalDepth]Then Begin Diagnostic('ELSE repete');Exit End;
  ConditionalElse[ConditionalDepth]:=True;
  ConditionalEnabled:=ConditionalParent[ConditionalDepth]and not ConditionalValue[ConditionalDepth]
 End else Begin
  if ConditionalDepth=0 Then Begin Diagnostic('ENDIF sans IF');Exit End;
  ConditionalEnabled:=ConditionalParent[ConditionalDepth];Dec(ConditionalDepth)
 End
End;

Procedure WriteListingLine(StartAddress:LongInt);
Var
 I:Integer;
 Bytes:String;
Begin
 if not ListOpen Then Exit;Bytes:='';
 For I:=0 to LineByteCount-1 do Bytes:=Bytes+HexByte(LineBytes[I])+' ';
 While Length(Bytes)<24 do Bytes:=Bytes+' ';
 WriteLn(ListFile,LineNumber:5,' ',HexWord(Word(StartAddress)),' ',Bytes,CurrentLine)
End;

Procedure AssemblePass(PassNo:Integer);
Var
 IncludeNames:Array[1..8]of String;

 Procedure AssembleFile(Const FileName:String;Depth:Integer);
 Var F:Text;StartAddress:LongInt;SavedLine:Integer;SavedText,SavedName,Name:String;
     I:Integer;
 Begin
  if Depth>8 Then Begin Diagnostic('profondeur INCLUDE superieure a huit');Exit End;
  For I:=1 to Depth-1 do if UpperString(IncludeNames[I])=UpperString(FileName)Then Begin
   Diagnostic('inclusion cyclique de '+FileName);Exit
  End;
  IncludeNames[Depth]:=FileName;Assign(F,FileName);Reset(F);
  if IOResult<>0 Then Begin Diagnostic('lecture impossible: '+FileName);Exit End;
  SavedLine:=LineNumber;SavedText:=CurrentLine;SavedName:=CurrentInputName;
  LineNumber:=0;CurrentInputName:=FileName;
  While not Eof(F)and not StopAssembly do Begin
   ReadLn(F,CurrentLine);if IOResult<>0 Then Begin Diagnostic('erreur de lecture');Break End;
   Inc(LineNumber);LineByteCount:=0;StartAddress:=Location[CurrentSection];SplitLine(CurrentLine);
   if IsConditionalDirective(OpcodeField)Then HandleConditionalDirective
   else if ConditionalEnabled Then Begin
    if(OpcodeField='INCLUDE')or(OpcodeField='.INPUT')Then Begin
     Name:=TrimString(OperandField);
     if(Length(Name)>=2)and(Name[1]in['''','"'])and(Name[Length(Name)]=Name[1])Then Begin
      Delete(Name,Length(Name),1);Delete(Name,1,1)
     End;
     if Name=''Then Diagnostic('INCLUDE exige un fichier')else Begin
      if not TextFileExists(Name)Then Name:=DirectoryPart(FileName)+Name;
      AssembleFile(Name,Depth+1)
     End
    End else Begin
     if(LabelField<>'')and(LabelField[1]<>'.')Then CurrentGlobal:=LabelField;
     if(LabelField<>'')and not((OpcodeField='EQU')or(OpcodeField='=')or
      (OpcodeField='CONSTANT'))Then DefineSymbol(LabelField,Location[CurrentSection],CurrentSection);
     if OpcodeField<>''Then if IsDirective(OpcodeField)Then ProcessDirective
     else ProcessInstruction
    End
   End;
   if Pass=2 Then WriteListingLine(StartAddress)
  End;
  Close(F);if IOResult<>0 Then Diagnostic('erreur de fermeture du source');
  LineNumber:=SavedLine;CurrentLine:=SavedText;CurrentInputName:=SavedName
 End;
Begin
 Pass:=PassNo;Location[SecText]:=0;Location[SecData]:=0;Location[SecBss]:=0;
 CurrentSection:=SecText;LineNumber:=0;StopAssembly:=False;ConditionalDepth:=0;
 ConditionalEnabled:=True;ModuleActive:=False;ModuleClosed:=False;CurrentGlobal:='';
 StructureDepth:=0;StructureSerial:=0;
 AssembleFile(Opt.SourceName,1);
 if ConditionalDepth<>0 Then Diagnostic('ENDIF manquant');
 if StructureDepth<>0 Then Diagnostic('fin de structure PLZ manquante');
 if ModuleActive and not ModuleClosed Then Diagnostic('ENDMODULE manquant');
 if Pass=1 Then Begin
  TextSize:=Location[SecText];DataSize:=Location[SecData];BssSize:=Location[SecBss]
 End
End;

Function IndirectRegister(S:String;Var R:Integer):Boolean;
Begin
 S:=TrimString(S);IndirectRegister:=False;R:=-1;
 if(S='')or(S[1]<>'@')Then Exit;Delete(S,1,1);R:=RegisterNumber(S,'W');
 IndirectRegister:=R>=0
End;

Procedure EncodeUnaryRegister(Base:Word;Kind:Char);
Var R:Integer;
Begin
 R:=RegisterNumber(OperandField,Kind);
 if R<0 Then Diagnostic('registre attendu')else EmitWord(Base or Word(R shl 4))
End;

Procedure EncodeMulDiv(BaseRR,BaseImm:Word;DestKind,SourceKind:Char);
Var S,A,B:String;Rd,Rs:Integer;V:LongInt;F:Boolean;RelBase:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if(A='')or(B='')or(S<>'')Then Begin Diagnostic('deux operandes attendus');Exit End;
 Rd:=RegisterNumber(A,DestKind);if Rd<0 Then Begin Diagnostic('registre destination incorrect');Exit End;
 Rs:=RegisterNumber(B,SourceKind);
 if Rs>=0 Then Begin EmitWord(BaseRR or Word(Rs shl 4)or Word(Rd));Exit End;
 if B[1]='#'Then Begin
  Delete(B,1,1);V:=EvalReloc(B,F,RelBase);EmitWord(BaseImm or Word(Rd));
  if SourceKind='L'Then EmitLongReloc(V,RAA32M,RelBase)
  else if Opt.Segmented Then EmitWordReloc(Word(V),RAZOF,RelBase)
  else EmitWordReloc(Word(V),RAA16M,RelBase);Exit
 End;
 Diagnostic('registre ou valeur immediate attendu')
End;

Procedure EncodeBitInstruction(BaseReg,BaseImm:Word;Kind:Char);
Var S,A,B:String;R,N:Integer;V:LongInt;F:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);R:=RegisterNumber(A,Kind);
 if(R<0)or(B='')or(S<>'')Then Begin Diagnostic('registre et numero de bit attendus');Exit End;
 if B[1]='#'Then Begin
  Delete(B,1,1);V:=Eval(B,F);if(V<0)or(V>15)Then Diagnostic('numero de bit hors plage');
  EmitWord(BaseImm or Word(R shl 4)or Word(V and 15))
 End else Begin
  N:=RegisterNumber(B,'W');if N<0 Then Diagnostic('registre de bit attendu')else Begin
   EmitWord(BaseReg or Word(N));EmitWord(Word(R shl 8))
  End
 End
End;

Procedure EncodeShiftRotate(Base:Word;Kind:Char;RightShift:Boolean);
Var S,A,B:String;R:Integer;V:LongInt;F:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);R:=RegisterNumber(A,Kind);
 if R<0 Then Begin Diagnostic('registre attendu');Exit End;
 if B=''Then V:=1 else Begin
  if B[1]='#'Then Delete(B,1,1);V:=Eval(B,F)
 End;
 if S<>''Then Diagnostic('trop d''operandes');
 if(V<1)or(V>2)Then Begin
  { Les formes de decalage acceptent aussi un compte signe sur 16 bits. }
  if RightShift Then V:=-V;
  EmitWord(Base or Word(R shl 4));EmitWord(Word(V))
 End else Begin
  EmitWord(Base or Word(R shl 4)or Word((V-1)shl 1))
 End
End;

Procedure EmitDirectAddress(V:LongInt;Base:Word;ForceShort:Boolean);
Var S:Word;
Begin
 if Opt.Segmented Then Begin
  if(Base=0)and((LongInt(V)and LongInt($80000000))<>0)Then Begin
   if ForceShort Then Begin
    S:=Word((LongInt(V)shr 24)and $7F);EmitWord((S shl 8)or Word(V and $FF))
   End else EmitLong(V)
  End else if ForceShort Then EmitWordReloc(SegmentedShortValue(V,Base),RAZSS,Base)
  else EmitLongReloc(SegmentedLongValue(V,Base),RAZLS,Base)
 End else EmitWordReloc(Word(V),RAA16M,Base)
End;

Procedure EncodeCall;
Var S:String;R:Integer;V:LongInt;F,ShortAddress:Boolean;Base:Word;
Begin
 S:=TrimString(OperandField);
 if IndirectRegister(S,R)Then Begin EmitWord($1F00 or Word(R shl 4));Exit End;
 ShortAddress:=(S<>'')and(S[1]='|');if ShortAddress Then Delete(S,1,1);
 V:=EvalReloc(S,F,Base);EmitWord($5F00);EmitDirectAddress(V,Base,ShortAddress)
End;

Procedure EncodeRelative12;
Var V,D:LongInt;F:Boolean;Base:Word;
Begin
 V:=EvalReloc(OperandField,F,Base);D:=Location[CurrentSection]+2-V;
 if(Pass=2)and(Base<>CurrentSection)Then Diagnostic('appel relatif vers une autre section');
 if(Pass=2)and(((D and 1)<>0)or(D< -4096)or(D>4094))Then
  Diagnostic('appel relatif hors plage');
 EmitWord($D000 or Word((D div 2)and $0FFF))
End;

Procedure EncodeDJNZ(ByteForm:Boolean);
Var S,A,B:String;R:Integer;V,D:LongInt;F:Boolean;Base:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if ByteForm Then R:=RegisterNumber(A,'B')else R:=RegisterNumber(A,'W');
 V:=EvalReloc(B,F,Base);D:=Location[CurrentSection]+2-V;
 if(R<0)or(B='')Then Begin Diagnostic('registre et destination attendus');Exit End;
 if(Pass=2)and((Base<>CurrentSection)or((D and 1)<>0)or(D<0)or(D>254))Then
  Diagnostic('destination DJNZ hors plage');
 if ByteForm Then EmitWord($F000 or Word(R shl 8)or Word((D div 2)and $7F))
 else EmitWord($F080 or Word(R shl 8)or Word((D div 2)and $7F))
End;

Procedure EncodePushPop(IsPop:Boolean);
Var S,A,B:String;RP,RV:Integer;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if IsPop Then Begin
  RV:=RegisterNumber(A,'W');if not IndirectRegister(B,RP)Then RP:=-1;
  if(RV<0)or(RP<0)Then Diagnostic('POP exige registre,@registre')
  else EmitWord($9700 or Word(RP shl 4)or Word(RV))
 End else Begin
  if not IndirectRegister(A,RP)Then RP:=-1;RV:=RegisterNumber(B,'W');
  if(RV<0)or(RP<0)Then Diagnostic('PUSH exige @registre,registre')
  else EmitWord($9300 or Word(RP shl 4)or Word(RV))
 End
End;

Procedure EncodePushPopLong(IsPop:Boolean);
Var S,A,B:String;RP,RV:Integer;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if IsPop Then Begin
  RV:=RegisterNumber(A,'L');if not IndirectRegister(B,RP)Then RP:=-1;
  if(RV<0)or(RP<0)Then Diagnostic('POPL exige registre long,@registre')
  else EmitWord($9500 or Word(RP shl 4)or Word(RV))
 End else Begin
  if not IndirectRegister(A,RP)Then RP:=-1;RV:=RegisterNumber(B,'L');
  if(RV<0)or(RP<0)Then Diagnostic('PUSHL exige @registre,registre long')
  else EmitWord($9100 or Word(RP shl 4)or Word(RV))
 End
End;

Procedure EncodeTCC(ByteForm:Boolean);
Var S,A,B:String;C,R:Integer;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);C:=ConditionNumber(A);
 if ByteForm Then R:=RegisterNumber(B,'B')else R:=RegisterNumber(B,'W');
 if(C<0)or(R<0)or(S<>'')Then Diagnostic('TCC exige condition,registre')
 else if ByteForm Then EmitWord($AE00 or Word(R shl 4)or Word(C))
 else EmitWord($AF00 or Word(R shl 4)or Word(C))
End;

Procedure EncodeFlags(Base:Word);
Var S,A,U:String;Bits:Word;
Begin
 S:=OperandField;Bits:=0;
 While S<>''do Begin
  A:=NextOperand(S);U:=UpperString(A);
  if(U='V')or(U='P')Then Bits:=Bits or $10
  else if U='S'Then Bits:=Bits or $20
  else if U='Z'Then Bits:=Bits or $40
  else if U='C'Then Bits:=Bits or $80
  else Diagnostic('flag incorrect: '+A)
 End;
 if Bits=0 Then Diagnostic('au moins un flag est requis');EmitWord(Base or Bits)
End;

Function ControlRegisterNumber(S:String):Integer;
Var U:String;
Begin
 U:=UpperString(TrimString(S));ControlRegisterNumber:=-1;
 if U='FCW'Then ControlRegisterNumber:=2
 else if U='REFRESH'Then ControlRegisterNumber:=3
 else if U='PSAPSEG'Then ControlRegisterNumber:=4
 else if(U='PSAPOFF')or(U='PSAP')Then ControlRegisterNumber:=5
 else if U='NSPSEG'Then ControlRegisterNumber:=6
 else if(U='NSPOFF')or(U='NSP')Then ControlRegisterNumber:=7
End;

Procedure EncodeLDCTL(ByteForm:Boolean);
Var S,A,B:String;R,C:Integer;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if ByteForm Then Begin
  if UpperString(A)='FLAGS'Then Begin R:=RegisterNumber(B,'B');if R>=0 Then EmitWord($8C09 or Word(R shl 4)) End
  else if UpperString(B)='FLAGS'Then Begin R:=RegisterNumber(A,'B');if R>=0 Then EmitWord($8C01 or Word(R shl 4)) End
  else R:=-1;
  if R<0 Then Diagnostic('LDCTLB exige FLAGS et un registre octet');Exit
 End;
 C:=ControlRegisterNumber(A);R:=RegisterNumber(B,'W');
 if(C>=0)and(R>=0)Then Begin EmitWord($7D00 or Word(R shl 4)or Word(C));Exit End;
 R:=RegisterNumber(A,'W');C:=ControlRegisterNumber(B);
 if(C>=0)and(R>=0)Then EmitWord($7D08 or Word(R shl 4)or Word(C))
 else Diagnostic('operandes LDCTL incorrects')
End;

Procedure EncodeString3(Base:Word;FirstInWord2:Boolean;TailNibble:Byte);
Var S,A,B,C:String;R1,R2,R3:Integer;W1,W2:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);C:=NextOperand(S);
 if not IndirectRegister(A,R1)Then R1:=-1;if not IndirectRegister(B,R2)Then R2:=-1;
 R3:=RegisterNumber(C,'W');if(R1<0)or(R2<0)or(R3<0)or(S<>'')Then Begin
  Diagnostic('trois registres valides attendus');Exit
 End;
 W1:=Base;W2:=0;
 if FirstInWord2 Then Begin
  W1:=W1 or Word(R2 shl 4);W2:=Word(R1 shl 12)or Word(R3 shl 8)or TailNibble
 End else Begin
  W1:=W1 or Word(R1 shl 4);W2:=Word(R2 shl 12)or Word(R3 shl 8)or TailNibble
 End;
 EmitWord(W1);EmitWord(W2)
End;

Procedure EncodeIO(IsOut,ByteForm,Special:Boolean);
Var S,A,B,Addr:String;R,RI:Integer;V:LongInt;F:Boolean;RelBase:Word;Base:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if IsOut Then Begin Addr:=A;if ByteForm Then R:=RegisterNumber(B,'B')else R:=RegisterNumber(B,'W') End
 else Begin if ByteForm Then R:=RegisterNumber(A,'B')else R:=RegisterNumber(A,'W');Addr:=B End;
 if(R<0)or(Addr='')or(S<>'')Then Begin Diagnostic('operandes d''entree-sortie incorrects');Exit End;
 if IndirectRegister(Addr,RI)and not Special Then Begin
  if ByteForm Then Base:=$3C00 else Base:=$3D00;
  if IsOut Then Base:=Base or $0200;
  EmitWord(Base or Word(R)or Word(RI shl 4));Exit
 End;
 V:=EvalReloc(Addr,F,RelBase);
 if ByteForm Then Base:=$3A04 else Base:=$3B04;
 if Special Then Inc(Base)else if IsOut Then Inc(Base,2);
 EmitWord(Base or Word(R shl 4));EmitWordReloc(Word(V),RAA16M,RelBase)
End;

Procedure EncodeLDA;
Var S,A,B:String;R:Integer;V:LongInt;F,ShortAddress:Boolean;RelBase:Word;K:Char;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);if Opt.Segmented Then K:='L'else K:='W';
 R:=RegisterNumber(A,K);ShortAddress:=(B<>'')and(B[1]='|');if ShortAddress Then Delete(B,1,1);
 if(R<0)or(B='')or(S<>'')Then Begin Diagnostic('LDA exige registre-adresse,adresse');Exit End;
 V:=EvalReloc(B,F,RelBase);EmitWord($7600 or Word(R));EmitDirectAddress(V,RelBase,ShortAddress)
End;

Procedure EncodeLDAR;
Var S,A,B:String;R:Integer;V,D:LongInt;F:Boolean;RelBase:Word;K:Char;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);if Opt.Segmented Then K:='L'else K:='W';
 R:=RegisterNumber(A,K);V:=EvalReloc(B,F,RelBase);D:=V-(Location[CurrentSection]+4);
 if(R<0)or(B='')or(S<>'')Then Begin Diagnostic('LDAR exige registre-adresse,destination');Exit End;
 if(Pass=2)and((RelBase<>CurrentSection)or((D and 1)<>0)or(D< -32768)or(D>32767))Then
  Diagnostic('destination LDAR hors plage');
 EmitWord($3400 or Word(R));EmitWord(Word(D))
End;

Procedure EncodeLDR;
Var S,A,B,E:String;R:Integer;V,D:LongInt;F:Boolean;RelBase:Word;Store:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);R:=RegisterNumber(A,'W');Store:=R<0;
 if Store Then Begin E:=A;R:=RegisterNumber(B,'W') End else E:=B;
 if(R<0)or(E='')or(S<>'')Then Begin Diagnostic('LDR exige registre et destination relative');Exit End;
 V:=EvalReloc(E,F,RelBase);D:=V-(Location[CurrentSection]+4);
 if(Pass=2)and((RelBase<>CurrentSection)or((D and 1)<>0)or(D< -32768)or(D>32767))Then
  Diagnostic('destination LDR hors plage');
 if Store Then EmitWord($3300 or Word(R))else EmitWord($3100 or Word(R));EmitWord(Word(D))
End;

Procedure EncodeLDM;
Var S,A,B,C:String;RM,RStart:Integer;V:LongInt;F,Store:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);C:=NextOperand(S);
 if(A='')or(B='')or(C='')Then Begin Diagnostic('LDM exige trois operandes');Exit End;
 Store:=A[1]<>'@';
 if Store Then Begin RStart:=RegisterNumber(A,'W');if not IndirectRegister(B,RM)Then RM:=-1 End
 else Begin if not IndirectRegister(A,RM)Then RM:=-1;RStart:=RegisterNumber(B,'W') End;
 if(C<>'')and(C[1]='#')Then Delete(C,1,1);V:=Eval(C,F);
 if(RM<0)or(RStart<0)or(V<1)or(V>16)or(S<>'')Then Begin
  Diagnostic('LDM exige registre/@registre et compte 1..16');Exit
 End;
 if Store Then EmitWord($1C01 or Word(RM shl 4))else EmitWord($1C09 or Word(RM shl 4));
 EmitWord(Word(RStart shl 8)or Word(V-1))
End;

Procedure EncodeCompareString(Base:Word);
Var S,A,B,C,D:String;R1,R2,R3,CC:Integer;W2:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);C:=NextOperand(S);D:=NextOperand(S);
 if(Base and $FF00)=$BA00 Then R1:=RegisterNumber(A,'B')else R1:=RegisterNumber(A,'W');
 if not IndirectRegister(B,R2)Then R2:=-1;R3:=RegisterNumber(C,'W');
 CC:=ConditionNumber(D);
 if(R1<0)or(R2<0)or(R3<0)or(CC<0)or(S<>'')Then Begin
  Diagnostic('instruction de comparaison de chaine: registre,@registre,registre,condition attendus');Exit
 End;
 W2:=Word(R1 shl 12)or Word(R3 shl 8)or Word(CC);EmitWord(Base or Word(R2 shl 4));EmitWord(W2)
End;

Procedure EncodeIncDec(IsDec,ByteForm:Boolean);
Var S,A,B:String;R:Integer;V:LongInt;F:Boolean;Base:Word;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if ByteForm Then R:=RegisterNumber(A,'B')else R:=RegisterNumber(A,'W');
 if B=''Then V:=1 else Begin if B[1]='#'Then Delete(B,1,1);V:=Eval(B,F) End;
 if(R<0)or(S<>'')Then Begin Diagnostic('registre et increment attendus');Exit End;
 if(V<1)or(V>16)Then Diagnostic('increment hors plage 1..16');
 if ByteForm Then Begin if IsDec Then Base:=$AA00 else Base:=$A800 End
 else Begin if IsDec Then Base:=$AB00 else Base:=$A900 End;
 EmitWord(Base or Word(R shl 4)or Word(V-1))
End;

Procedure AssignObjectBases;
Var P,Q:PSymbol;N:Word;
Begin
 N:=RBEXT;P:=Symbols;
 While P<>Nil do Begin
  if not P^.Defined Then Begin
   if Opt.UndefinedGlobal Then Begin P^.Global:=True;P^.External:=True End;
   if P^.External Then Begin
    if N>=RBMSK Then Fatal('trop de references externes');
    P^.ObjectBase:=N;Inc(N)
   End
  End else P^.ObjectBase:=P^.Section;
  Q:=P^.Next;While Q<>Nil do Begin
   if(Copy(P^.Name,1,8)=Copy(Q^.Name,1,8))and(P^.Name<>Q^.Name)Then
    Fatal('collision de noms UNIDOT sur 8 caracteres: '+P^.Name+' / '+Q^.Name);
   Q:=Q^.Next
  End;
  P:=P^.Next
 End
End;

Procedure WriteBE16(Var F:File;W:Word);
Var
 B:Array[0..1]of Byte;
Begin
 B[0]:=W shr 8;B[1]:=W;BlockWrite(F,B,2)
End;

Procedure WriteBE32(Var F:File;L:LongInt);
Var
 B:Array[0..3]of Byte;
Begin
 B[0]:=LongInt(L)shr 24;B[1]:=LongInt(L)shr 16;B[2]:=LongInt(L)shr 8;B[3]:=L;
 BlockWrite(F,B,4)
End;

Type TObjectBuffer=Array[0..254]of Byte;

Procedure PutLE16(Var B:TObjectBuffer;Var N:Integer;W:Word);Begin
 B[N]:=Byte(W);Inc(N);B[N]:=Byte(W shr 8);Inc(N)
End;

Procedure PutLE32(Var B:TObjectBuffer;Var N:Integer;L:LongInt);Begin
 PutLE16(B,N,Word(L));PutLE16(B,N,Word(LongInt(L)shr 16))
End;

Procedure PutObjectName(Var B:TObjectBuffer;Var N:Integer;S:String);
Var I,L:Integer;
Begin
 L:=Length(S);if L>8 Then L:=8;
 For I:=1 to L do Begin B[N]:=Ord(S[I]);Inc(N) End;B[N]:=0;Inc(N)
End;

Procedure WriteObjectBlock(Var F:File;BlockType:Byte;Var B:TObjectBuffer;N:Integer);
Var T,L:Byte;Written:Word;
Begin
 T:=BlockType;L:=Byte(N);BlockWrite(F,T,1,Written);BlockWrite(F,L,1,Written);
 if N<>0 Then BlockWrite(F,B,N,Written)
End;

Function ObjectImageByte(Section:Byte;Offset:LongInt):Byte;
Begin
 if Section=SecText Then ObjectImageByte:=TextImage[Offset div 16384]^[Offset mod 16384]
 else ObjectImageByte:=DataImage[Offset div 16384]^[Offset mod 16384]
End;

Procedure WriteTextSection(Var F:File;Section:Byte;Size:LongInt);
Var
 B:TObjectBuffer;
 Pos:LongInt;
 Chunk,N,RC,I:Integer;
 R:PRelocation;
Begin
 Pos:=0;
 While Pos<Size do Begin
  Chunk:=Size-Pos;if Chunk>249 Then Chunk:=249;
  Repeat
   R:=Relocations;
   While R<>Nil do Begin
    if(R^.Section=Section)and(R^.Offset>=Pos)and(R^.Offset<Pos+Chunk)and
     (R^.Offset+R^.Width>Pos+Chunk)Then Chunk:=R^.Offset-Pos;
    R:=R^.Next
   End;
   RC:=0;R:=Relocations;
   While R<>Nil do Begin
    if(R^.Section=Section)and(R^.Offset>=Pos)and(R^.Offset<Pos+Chunk)Then Inc(RC);
    R:=R^.Next
   End;
   if 6+Chunk+3*RC>255 Then Dec(Chunk)else Break
  Until Chunk=0;
  if Chunk=0 Then Fatal('bloc UNIDOT de relogement trop grand');
  N:=0;PutLE32(B,N,Pos);B[N]:=Section;Inc(N);B[N]:=Chunk;Inc(N);
  For I:=0 to Chunk-1 do Begin B[N]:=ObjectImageByte(Section,Pos+I);Inc(N) End;
  R:=Relocations;
  While R<>Nil do Begin
   if(R^.Section=Section)and(R^.Offset>=Pos)and(R^.Offset<Pos+Chunk)Then Begin
    B[N]:=Byte(6+R^.Offset-Pos);Inc(N);PutLE16(B,N,R^.Action or(R^.Base and RBMSK))
   End;
   R:=R^.Next
  End;
  WriteObjectBlock(F,OBTXT,B,N);Inc(Pos,Chunk)
 End
End;

Procedure WriteSymbolBlocks(Var F:File;BlockType:Byte;WantGlobal:Boolean);
Var B:TObjectBuffer;N,Need:Integer;P:PSymbol;IsGlobal:Boolean;
Begin
 N:=0;P:=Symbols;
 While P<>Nil do Begin
  IsGlobal:=P^.Global or P^.External;
  if IsGlobal=WantGlobal Then Begin
   Need:=6+Length(P^.Name);if Need>14 Then Need:=14;
   if N+Need>255 Then Begin WriteObjectBlock(F,BlockType,B,N);N:=0 End;
   if P^.Defined Then Begin PutLE32(B,N,P^.Value);B[N]:=P^.Section End
   else Begin PutLE32(B,N,0);B[N]:=RBUND End;
   Inc(N);PutObjectName(B,N,P^.Name)
  End;
  P:=P^.Next
 End;
 if N<>0 Then WriteObjectBlock(F,BlockType,B,N)
End;

Procedure WriteObject;
Var F:File;B:TObjectBuffer;N:Integer;S:String;
Begin
 Assign(F,Opt.ObjectName);Rewrite(F,1);
 if IOResult<>0 Then Fatal('creation impossible: '+Opt.ObjectName);
 N:=0;WriteObjectBlock(F,OBOST,B,N);
 S:=ObjectModuleName;if S=''Then S:=ModuleName(Opt.SourceName);
 N:=0;PutObjectName(B,N,S);WriteObjectBlock(F,OBMOD,B,N);
 N:=0;
 B[N]:=1;Inc(N);B[N]:=32 or SectionAttributes[1];Inc(N);B[N]:=0;Inc(N);
 PutObjectName(B,N,SectionObjectName[1]);
 B[N]:=1;Inc(N);B[N]:=32 or SectionAttributes[2];Inc(N);B[N]:=0;Inc(N);
 PutObjectName(B,N,SectionObjectName[2]);
 B[N]:=1;Inc(N);B[N]:=32 or SectionAttributes[3];Inc(N);B[N]:=0;Inc(N);
 PutObjectName(B,N,SectionObjectName[3]);
 WriteObjectBlock(F,OBSEC,B,N);
 WriteSymbolBlocks(F,OBGLO,True);WriteSymbolBlocks(F,OBLOC,False);
 WriteTextSection(F,SecText,TextSize);WriteTextSection(F,SecData,DataSize);
 { Comme l'assembleur DRI, matérialiser la marque de fin du BSS par un
   OBTXT vide placé à son compteur final. }
 N:=0;PutLE32(B,N,BssSize);B[N]:=SecBss;Inc(N);B[N]:=0;Inc(N);
 WriteObjectBlock(F,OBTXT,B,N);
 if HasTransfer Then Begin
  N:=0;PutLE32(B,N,TransferAddress);PutLE16(B,N,TransferBase);
  WriteObjectBlock(F,OBTRA,B,N)
 End;
 N:=0;WriteObjectBlock(F,OBOND,B,N);
 Close(F);if IOResult<>0 Then Fatal('erreur d''ecriture objet')
End;

Procedure WriteCrossReference;
Var
 P:PSymbol;
Begin
 if not ListOpen or not Opt.CrossReference Then Exit;WriteLn(ListFile);
 WriteLn(ListFile,'TABLE DES REFERENCES CROISEES');
 WriteLn(ListFile,'Symbole                          Valeur Sect Definition References');
 P:=Symbols;
 While P<>Nil do Begin
  Write(ListFile,P^.Name:32,' ',HexWord(Word(P^.Value)),' ',P^.Section:4,' ');
  if P^.Defined Then Write(ListFile,P^.DefLine:10)else Write(ListFile,'     EXTERN');
  WriteLn(ListFile,P^.References);P:=P^.Next
 End
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 S,U,OutBase:String;
Begin
 FillChar(Opt,SizeOf(Opt),0);I:=1;
 While I<=ParamCount do Begin
  S:=ParamStr(I);U:=UpperString(S);
  if(U='/?')or(U='-?')or(U='--HELP')Then Begin
   Usage;Halt(0)
  End
  else if(U='-O')Then Begin
   Inc(I);if I>ParamCount Then Fatal('-o exige un nom');Opt.ObjectName:=ParamStr(I)
  End
  else if(U='-P')Then Begin
   Inc(I);if I>ParamCount Then Fatal('-p exige un nom');Opt.PredefName:=ParamStr(I)
  End
  else if(Copy(U,1,2)='-O')and(Length(S)>2)Then Opt.ObjectName:=Copy(S,3,255)
  else if(S<>'')and(S[1]='-')Then Begin
   Delete(U,1,1);
   While U<>''do Begin
    Case U[1]of 'L':Opt.Listing:=True;'U':Opt.UndefinedGlobal:=True;
    'X':
    Begin
     Opt.CrossReference:=True;Opt.Listing:=True
    End;
    else Fatal('option inconnue: -'+U[1])
   End;Delete(U,1,1)
  End
 End else if Opt.SourceName=''Then Opt.SourceName:=S else Fatal(
 'plusieurs fichiers source');Inc(I)
End;
if Opt.SourceName=''Then Begin
 Usage;Halt(1)
End;
U:=Extension(Opt.SourceName);
if(U<>'.8KN')and(U<>'.8KS')Then Fatal('extension .8KN ou .8KS attendue');
Opt.Segmented:=U='.8KS';OutBase:=BaseName(Opt.SourceName);
if Opt.ObjectName=''Then Opt.ObjectName:=OutBase+'.OBJ'else if Extension(Opt.ObjectName)=
''Then Opt.ObjectName:=Opt.ObjectName+'.OBJ';
U:=Extension(Opt.ObjectName);
if(U='.O')or(U='.RL')or(U='.Z8K')Then Fatal(U+
 ' n''est pas un conteneur UNIDOT brut; utilisez .OBJ puis XCON/LDSK');
Opt.ListName:=OutBase+'.LST'
End;

Procedure AllocateImages;
Var
 I:Integer;
Begin
 For I:=0 to 3 do Begin
  GetMem(TextImage[I],SizeOf(TByteBlock));GetMem(DataImage[I],SizeOf(TByteBlock));
  if(TextImage[I]=Nil)or(DataImage[I]=Nil)Then Fatal('memoire pleine');
  FillChar(TextImage[I]^,SizeOf(TByteBlock),0);
  FillChar(DataImage[I]^,SizeOf(TByteBlock),0)
 End
End;

Procedure Cleanup;
Var
 I:Integer;
 P,N:PPredefName;
Begin
 if ListOpen Then Begin
  Close(ListFile);if IOResult<>0 Then Begin
  End
 End;
 For I:=0 to 3 do Begin
  if TextImage[I]<>Nil Then FreeMem(TextImage[I],SizeOf(TByteBlock));
  if DataImage[I]<>Nil Then FreeMem(DataImage[I],SizeOf(TByteBlock))
 End;FreeSymbols;
 P:=Predefinitions;While P<>Nil do Begin
  N:=P^.Next;FreePredefFormats(P^.Formats);Dispose(P);P:=N
 End;Predefinitions:=Nil
End;

BEGIN
 Symbols:=Nil;Relocations:=Nil;LastRelocation:=Nil;HasTransfer:=False;
 Predefinitions:=Nil;PredefInstructionCount:=0;PredefDirectiveCount:=0;
 PredefSymbolCount:=0;
 ObjectModuleName:='';SectionObjectName[1]:='__text';SectionObjectName[2]:='__data';
 SectionObjectName[3]:='__bss';FillChar(SectionAttributes,SizeOf(SectionAttributes),0);
 TransferAddress:=0;TransferBase:=0;FillChar(TextImage,SizeOf(TextImage),0);
 FillChar(DataImage,SizeOf(DataImage),0);
 ListOpen:=False;ErrorCount:=0;WarningCount:=0;
 ParseCommandLine;LoadPredefinitions;AllocateImages;Assign(Source,Opt.SourceName);Reset(Source);
 if IOResult<>0 Then Fatal('fichier source introuvable: '+Opt.SourceName);Close(Source);
 if IOResult<>0 Then Begin
 End;
 if Opt.Listing Then Begin
  Assign(ListFile,Opt.ListName);Rewrite(ListFile);
  if IOResult<>0 Then Fatal('creation listing impossible');
  ListOpen:=True;WriteLn(ListFile,'ASZ8K ',Version,'  ',Opt.SourceName,'  ',
  'Z800',Ord(not Opt.Segmented)+1);WriteLn(ListFile)
 End;
 AssemblePass(1);AssignObjectBases;if ErrorCount=0 Then AssemblePass(2);
 WriteCrossReference;
 if ErrorCount=0 Then Begin
  WriteObject;WriteLn('ASZ8K: ',Opt.SourceName,' -> ',Opt.ObjectName,
  ' (TEXT=',TextSize,', DATA=',DataSize,', BSS=',BssSize,')')
 End else
 Begin
  Assign(Source,Opt.ObjectName);Erase(Source);if IOResult<>0 Then Begin
  End
 End;
 if WarningCount<>0 Then WriteLn(WarningCount,' avertissement(s)');
 if ErrorCount<>0 Then WriteLn(ErrorCount,' erreur(s)');Cleanup;
 if ErrorCount<>0 Then Halt(1)else Halt(0)
END.
