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
 MagicSegmented=$EE00;
 MagicNonSegmented=$EE02;
 MaxSectionSize=65535;
 SecAbsolute=0;
 SecText=1;
 SecData=2;
 SecBss=3;

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
 Next:PSymbol
End;
TOptions=Record
SourceName,ObjectName,ListName:String;
Listing,CrossReference,UndefinedGlobal,Segmented:Boolean
End;

Var
 Opt:TOptions;
 TextImage,DataImage:Array[0..3]of PByteBlock;
 TextSize,DataSize,BssSize:LongInt;
 CurrentSection:Byte;
 Location:Array[0..3]of LongInt;
 Symbols:PSymbol;
 Pass,LineNumber,ErrorCount,WarningCount:Integer;
 Source:Text;
 ListFile:Text;
 ListOpen:Boolean;
 CurrentLine,LabelField,OpcodeField,OperandField:String;
 LineBytes:Array[0..31]of Byte;
 LineByteCount:Integer;
 StopAssembly:Boolean;

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
 WriteLn('Syntaxe : ASZ8K [-o fichier] [-lux] fichier.8k{n|s}');
 WriteLn('  -o nom  produit nom.RL');
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
  Inc(ErrorCount);WriteLn(Opt.SourceName,'(',LineNumber,'): ',S);
  if ListOpen Then WriteLn(ListFile,'**** ',S)
 End
End;

Procedure Warning(Const S:String);Begin
 if Pass=2 Then Begin
  Inc(WarningCount);WriteLn(Opt.SourceName,'(',LineNumber,'): avertissement: ',S)
 End
End;

Function FindSymbol(Const Name:String):PSymbol;
Var
 P:PSymbol;
Begin
 P:=Symbols;
 While(P<>Nil)and(P^.Name<>Name)do P:=P^.Next;FindSymbol:=P
End;

Function GetSymbol(Const Name:String):PSymbol;
Var
 P:PSymbol;
Begin
 P:=FindSymbol(Name);if P=Nil Then Begin
  New(P);if P=Nil Then Fatal('memoire pleine');
  FillChar(P^,SizeOf(P^),0);P^.Name:=Name;P^.Next:=Symbols;Symbols:=P
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
Begin
 P:=Symbols;
 While P<>Nil do Begin
  N:=P^.Next;Dispose(P);P:=N
 End;Symbols:=Nil
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
  if(UpperString(Copy(OperandField,1,P-1))='EQU')or(Copy(OperandField,1,P-1)='=')
  Then Begin
   LabelField:=FirstWord;OpcodeField:='EQU';Delete(OperandField,1,P-1);
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

Function ParseNumber(Var E:TExprParser):LongInt;
Var
 Start,Code:Integer;
 T,U:String;
 V:LongInt;
 P:PSymbol;
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
 if C=''''Then Begin
  Inc(E.P);if E.P<=Length(E.S)Then Begin
   V:=Ord(E.S[E.P]);Inc(E.P)
  End else V:=0;
  if(E.P<=Length(E.S))and(E.S[E.P]='''')Then Inc(E.P);ParseNumber:=V;Exit
 End;
 if C='$'Then Begin
  Inc(E.P);Start:=E.P;
  While(E.P<=Length(E.S))and(UpCase(E.S[E.P])in['0'..'9','A'..'F'])do Inc(E.P);
  T:=Copy(E.S,Start,E.P-Start);Val('$'+T,V,Code);if Code<>0 Then V:=0;ParseNumber:=V;Exit
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
  T:=Copy(E.S,Start,E.P-Start);P:=GetSymbol(T);AddReference(P);
  if P^.Defined Then V:=P^.Value else
  Begin
   V:=0;E.ForwardRef:=True;
   if Pass=2 Then Begin
    if Opt.UndefinedGlobal Then Begin
     P^.Global:=True;P^.External:=True
    End
    else Diagnostic('symbole indefini: '+T)
   End
  End;ParseNumber:=V;Exit
 End;
 Diagnostic('terme incorrect dans expression');Inc(E.P);ParseNumber:=0
End;

Function ParseUnary(Var E:TExprParser):LongInt;Begin
 ExprSkip(E);if(E.P<=Length(E.S))and(E.S[E.P]='+')Then Begin
  Inc(E.P);ParseUnary:=ParseUnary(E)
 End
 else if(E.P<=Length(E.S))and(E.S[E.P]='-')Then Begin
  Inc(E.P);ParseUnary:=-ParseUnary(E)
 End
 else if(E.P<=Length(E.S))and(E.S[E.P]='~')Then Begin
  Inc(E.P);ParseUnary:=not ParseUnary(E)
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
Begin
 U:=UpperString(TrimString(S));RegisterNumber:=-1;
 if Kind='B'Then Begin
  if(Length(U)<3)or not((Copy(U,1,2)='RH')or(Copy(U,1,2)='RL'))Then Exit;
  Val(Copy(U,3,255),N,E);if(E=0)and(N>=0)and(N<=7)Then Begin
   if U[2]='L'Then Inc(N,8);RegisterNumber:=N
  End;Exit
 End;
 if Kind='L'Then P:=3 else P:=2;
 if Kind='L'Then Begin
  if Copy(U,1,2)<>'RR'Then Exit
 End else if U[1]<>'R'Then Exit;
 Val(Copy(U,P,255),N,E);if E<>0 Then Exit;
 if Kind='L'Then Begin
  if(N>=0)and(N<=14)and((N and 1)=0)Then RegisterNumber:=N
 End
 else if(N>=0)and(N<=15)Then RegisterNumber:=N
End;

Function ConditionNumber(S:String):Integer;
Var
 U:String;
Begin
 U:=UpperString(TrimString(S));ConditionNumber:=-1;
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
 Base:Word;
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
  Delete(B,1,1);V:=Eval(B,F);
  if K='B'Then Begin
   EmitWord($2100 or Rd);EmitByte(Byte(V));EmitByte(0)
  End
  else if K='L'Then Begin
   EmitWord($1400 or Rd);EmitLong(V)
  End
  else
  Begin
   EmitWord($2100 or Rd);EmitWord(Word(V))
  End;Exit
 End;
 Diagnostic('forme LD non prise en charge ou operande incorrect')
End;

Procedure EncodeJump;
Var
 S,A,B:String;
 C:Integer;
 V,D:LongInt;
 F:Boolean;
Begin
 S:=OperandField;A:=NextOperand(S);B:=NextOperand(S);
 if B=''Then Begin
  B:=A;if OpcodeField='RET'Then C:=8 else C:=8
 End
 else C:=ConditionNumber(A);
 if C<0 Then Begin
  Diagnostic('condition incorrecte');Exit
 End;
 if OpcodeField='RET'Then Begin
  EmitWord($9E00 or Word(C shl 4)or 8);Exit
 End;
 V:=Eval(B,F);
 if OpcodeField='JR'Then Begin
  D:=(V-(Location[CurrentSection]+2))div 2;
  if(Pass=2)and not F and((D< -128)or(D>127))Then Diagnostic('saut relatif hors plage');
  EmitWord($E000 or Word(C shl 8)or(Byte(D)))
 End else
 Begin
  EmitWord($5E00 or Word(C shl 4));EmitWord(Word(V))
 End
End;

Procedure DataDirective(Size:Integer);
Var
 S,A:String;
 V:LongInt;
 F:Boolean;
 I:Integer;
Begin
 S:=OperandField;
 While S<>''do Begin
  A:=NextOperand(S);
  if(Size=1)and(Length(A)>=2)and(A[1]='"')and(A[Length(A)]='"')Then
  For I:=2 to Length(A)-1 do EmitByte(Ord(A[I]))
  else
  Begin
   V:=Eval(A,F);if Size=1 Then Begin
    if(Pass=2)and not F and((V< -128)or(V>255))Then Diagnostic('octet hors plage');
    EmitByte(Byte(V))
   End else if Size=2 Then Begin
    if(Pass=2)and not F and((V< -32768)or(V>65535))Then Diagnostic('mot hors plage');
    EmitWord(Word(V))
   End else EmitLong(V)
  End
 End
End;

Procedure ProcessDirective;
Var
 V:LongInt;
 F:Boolean;
 S,A:String;
 P:PSymbol;
Begin
 if(OpcodeField='TEXT')or(OpcodeField='.TEXT')or(OpcodeField='CSEG')Then CurrentSection:=
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
 else if(OpcodeField='END')or(OpcodeField='.END')or(OpcodeField='ENDMODULE')
 Then StopAssembly:=True
 else if(OpcodeField='MODULE')or(OpcodeField='CODE')or(OpcodeField='SECTION')Then Begin
 End
 else Diagnostic('directive inconnue: '+OpcodeField)
End;

Procedure ProcessInstruction;
Var
 V:LongInt;
 F:Boolean;
 R:Integer;
 S,A:String;
Begin
 if(OpcodeField='LD')or(OpcodeField='LDB')or(OpcodeField='LDL')Then EncodeLoad
 else if OpcodeField='ADD'Then EncodeRegReg(OpcodeField,$8100,'W')
 else if OpcodeField='ADDB'Then EncodeRegReg(OpcodeField,$8000,'B')
 else if OpcodeField='ADDL'Then EncodeRegReg(OpcodeField,$9600,'L')
 else if OpcodeField='ADC'Then EncodeRegReg(OpcodeField,$B500,'W')
 else if OpcodeField='ADCB'Then EncodeRegReg(OpcodeField,$B400,'B')
 else if OpcodeField='SUB'Then EncodeRegReg(OpcodeField,$A100,'W')
 else if OpcodeField='SUBB'Then EncodeRegReg(OpcodeField,$A000,'B')
 else if OpcodeField='CP'Then EncodeRegReg(OpcodeField,$A300,'W')
 else if OpcodeField='CPB'Then EncodeRegReg(OpcodeField,$A200,'B')
 else if OpcodeField='AND'Then EncodeRegReg(OpcodeField,$8300,'W')
 else if OpcodeField='ANDB'Then EncodeRegReg(OpcodeField,$8200,'B')
 else if OpcodeField='OR'Then EncodeRegReg(OpcodeField,$8500,'W')
 else if OpcodeField='ORB'Then EncodeRegReg(OpcodeField,$8400,'B')
 else if OpcodeField='XOR'Then EncodeRegReg(OpcodeField,$8700,'W')
 else if OpcodeField='XORB'Then EncodeRegReg(OpcodeField,$8600,'B')
 else if OpcodeField='NOP'Then EmitWord($8D07)
 else if OpcodeField='HALT'Then EmitWord($7A00)
 else if OpcodeField='IRET'Then EmitWord($7B00)
 else if(OpcodeField='JR')or(OpcodeField='JP')or(OpcodeField='RET')Then EncodeJump
 else if OpcodeField='SC'Then Begin
  S:=OperandField;if(S<>'')and(S[1]='#')Then Delete(S,1,1);
  V:=Eval(S,F);if(V<0)or(V>255)Then Diagnostic('numero SC hors plage');
  EmitWord($7F00 or Byte(V))
 End
 else if(OpcodeField='INC')or(OpcodeField='DEC')Then Begin
  S:=OperandField;A:=NextOperand(S);R:=RegisterNumber(A,'W');A:=NextOperand(S);
  if(R<0)or(A='')Then Diagnostic('registre et increment attendus')else
  Begin
   if A[1]='#'Then Delete(A,1,1);V:=Eval(A,F);
   if(V<1)or(V>16)Then Diagnostic('increment hors plage 1..16');
   if OpcodeField='INC'Then EmitWord($0B00 or Word((V-1)shl 4)or R)
   else EmitWord($0A00 or Word((V-1)shl 4)or R)
  End
 End
 else Diagnostic('instruction inconnue ou forme non implementee: '+OpcodeField)
End;

Function IsDirective(Const S:String):Boolean;
Var
 U:String;
Begin
 U:=UpperString(S);
 IsDirective:=(U='TEXT')or(U='.TEXT')or(U='CSEG')or(U='DATA')or(U='.DATA')or
 (U='DSEG')or(U='BSS')or(U='.BSS')or(U='EQU')or(U='=')or(U='DB')or(U='DEFB')or(U='.BYTE')
 or
 (U='DW')or(U='DEFW')or(U='.WORD')or(U='DL')or(U='DEFL')or(U='.LONG')or(U='DS')or(U=
 'DEFS')or
 (U='.SPACE')or(U='BLOCK')or(U='EVEN')or(U='.EVEN')or(U='ALIGN')or(U='.ALIGN')or(U='ORG')
 or
 (U='.ORG')or(U='GLOBAL')or(U='.GLOBAL')or(U='PUBLIC')or(U='EXTERN')or(U='.EXTERN')or
 (U='EXTERNAL')or(U='END')or(U='.END')or(U='ENDMODULE')or(U='MODULE')or(U='CODE')or(U=
 'SECTION')
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
 StartAddress:LongInt;
Begin
 Pass:=PassNo;Location[SecText]:=0;Location[SecData]:=0;Location[SecBss]:=0;
 CurrentSection:=SecText;LineNumber:=0;StopAssembly:=False;Reset(Source);
 if IOResult<>0 Then Fatal('lecture impossible: '+Opt.SourceName);
 While not Eof(Source)and not StopAssembly do Begin
  ReadLn(Source,CurrentLine);if IOResult<>0 Then Begin
   Diagnostic('erreur de lecture');Break
  End;
  Inc(LineNumber);LineByteCount:=0;StartAddress:=Location[CurrentSection];
  SplitLine(CurrentLine);
  if(LabelField<>'')and not((OpcodeField='EQU')or(OpcodeField='='))Then   DefineSymbol(
  LabelField,Location[CurrentSection],CurrentSection);
  if OpcodeField<>''Then if IsDirective(OpcodeField)
  Then ProcessDirective else ProcessInstruction;
  if Pass=2 Then WriteListingLine(StartAddress)
 End;Close(Source);if IOResult<>0 Then Diagnostic('erreur de fermeture du source');
 if Pass=1 Then Begin
  TextSize:=Location[SecText];DataSize:=Location[SecData];BssSize:=Location[SecBss]
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

Function SymbolTableSize:LongInt;
Var
 P:PSymbol;
Begin
 SymbolTableSize:=0;P:=Symbols;
 While P<>Nil do Begin
  if P^.Global or P^.External Then Inc(SymbolTableSize,7+Length(P^.Name));P:=P^.Next
 End
End;

Procedure WriteObject;
Var
 F:File;
 P:PSymbol;
 N:Byte;
 Flags:Word;
 SymSize,Remain:LongInt;
 Written,Count:Word;
 I:Integer;
Begin
 Assign(F,Opt.ObjectName);Rewrite(F,1);
 if IOResult<>0 Then Fatal('creation impossible: '+Opt.ObjectName);
 if Opt.Segmented Then WriteBE16(F,MagicSegmented)else WriteBE16(F,MagicNonSegmented);
 WriteBE16(F,2);SymSize:=SymbolTableSize;
 WriteBE32(F,TextSize+DataSize);WriteBE32(F,0);WriteBE32(F,SymSize);
 Remain:=TextSize;I:=0;
 While Remain>0 do Begin
  Count:=16384;if Remain<Count Then Count:=Remain;
  BlockWrite(F,TextImage[I]^,Count,Written);Dec(Remain,Count);Inc(I)
 End;
 Remain:=DataSize;I:=0;
 While Remain>0 do Begin
  Count:=16384;if Remain<Count Then Count:=Remain;
  BlockWrite(F,DataImage[I]^,Count,Written);Dec(Remain,Count);Inc(I)
 End;
 P:=Symbols;
 While P<>Nil do Begin
  if P^.Global or P^.External Then Begin
   N:=Length(P^.Name);BlockWrite(F,N,1);BlockWrite(F,P^.Name[1],N);Flags:=P^.Section;
   if P^.Defined Then Flags:=Flags or $0100;if P^.Global Then Flags:=Flags or $0200;
   if P^.External Then Flags:=Flags or $0400;WriteBE16(F,Flags);WriteBE32(F,P^.Value)
  End;P:=P^.Next
 End;
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
if Opt.ObjectName=''Then Opt.ObjectName:=OutBase+'.RL'else if Extension(Opt.ObjectName)=
''Then Opt.ObjectName:=Opt.ObjectName+'.RL';
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
Begin
 if ListOpen Then Begin
  Close(ListFile);if IOResult<>0 Then Begin
  End
 End;
 For I:=0 to 3 do Begin
  if TextImage[I]<>Nil Then FreeMem(TextImage[I],SizeOf(TByteBlock));
  if DataImage[I]<>Nil Then FreeMem(DataImage[I],SizeOf(TByteBlock))
 End;FreeSymbols
End;

BEGIN
 Symbols:=Nil;FillChar(TextImage,SizeOf(TextImage),0);
 FillChar(DataImage,SizeOf(DataImage),0);
 ListOpen:=False;ErrorCount:=0;WarningCount:=0;
 ParseCommandLine;AllocateImages;Assign(Source,Opt.SourceName);Reset(Source);
 if IOResult<>0 Then Fatal('fichier source introuvable: '+Opt.SourceName);Close(Source);
 if IOResult<>0 Then Begin
 End;
 if Opt.Listing Then Begin
  Assign(ListFile,Opt.ListName);Rewrite(ListFile);
  if IOResult<>0 Then Fatal('creation listing impossible');
  ListOpen:=True;WriteLn(ListFile,'ASZ8K ',Version,'  ',Opt.SourceName,'  ',
  'Z800',Ord(not Opt.Segmented)+1);WriteLn(ListFile)
 End;
 AssemblePass(1);if ErrorCount=0 Then AssemblePass(2);
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
