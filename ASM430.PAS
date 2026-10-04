{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Assembleur MSP430 a deux passes, compatible Turbo Pascal / Free Pascal.
 @license: MIT }

Program ASM430;

{$A-}
{$R-}
{$Q-}
Uses Dos;

Const MaxSymbols=1000;MaxLineBytes=64;

Type
 TSymbol=Record Name:String[31];Value:LongInt;Defined:Boolean End;
 TOperand=Record Reg,Mode:Byte;HasExt,Relative:Boolean;ExtValue:LongInt End;

Var
 Symbols:Array[1..MaxSymbols]Of TSymbol;SymbolCount:Integer;
 Source,Listing:Text;Binary:File Of Byte;
 SourceName,ListName,BinName:String;
 Pass,LineNumber,ErrorCount:Integer;PC:LongInt;
 LineBytes:Array[0..MaxLineBytes-1]Of Byte;LineByteCount:Integer;
 BinStarted:Boolean;BinAddress:LongInt;ShowErrors,StopAssembly:Boolean;

Function Upper(Const S:String):String;
Var R:String;I:Integer;
Begin R:=S;For I:=1To Length(R)Do R[I]:=UpCase(R[I]);Upper:=R End;

Function LTrim(Const S:String):String;
Var I:Integer;
Begin I:=1;While(I<=Length(S))And(S[I]In[' ',#9])Do Inc(I);LTrim:=Copy(S,I,255)End;

Function RTrim(Const S:String):String;
Var I:Integer;
Begin I:=Length(S);While(I>0)And(S[I]In[' ',#9,#13,#10])Do Dec(I);RTrim:=Copy(S,1,I)End;

Function Trim(Const S:String):String;Begin Trim:=LTrim(RTrim(S))End;

Function Hex4(V:Word):String;
Const H:String[16]='0123456789ABCDEF';
Begin Hex4:=H[((V Shr 12)And 15)+1]+H[((V Shr 8)And 15)+1]+H[((V Shr 4)And 15)+1]+H[(V And 15)+1]End;

Function Hex2(V:Byte):String;
Const H:String[16]='0123456789ABCDEF';
Begin Hex2:=H[(V Shr 4)+1]+H[(V And 15)+1]End;

Function BaseName(Const S:String):String;
Var I,P,D:Integer;
Begin P:=1;D:=0;For I:=1To Length(S)Do If S[I]In['\','/',':']Then Begin P:=I+1;D:=0 End Else If S[I]='.'Then D:=I;
 If D=0Then D:=Length(S)+1;BaseName:=Copy(S,1,D-1)End;

Function IsIdentChar(C:Char):Boolean;Begin IsIdentChar:=C In['A'..'Z','a'..'z','0'..'9','_','.','$']End;

Procedure Error(Const S:String);
Begin Inc(ErrorCount);If Pass=2Then Begin WriteLn(Listing,'***** Ligne ',LineNumber,': ',S);If ShowErrors Then WriteLn('Erreur ligne ',LineNumber,': ',S)End End;

Function FindSymbol(Const Name:String):Integer;
Var I:Integer;U:String;
Begin U:=Upper(Name);For I:=1To SymbolCount Do If Symbols[I].Name=U Then Begin FindSymbol:=I;Exit End;FindSymbol:=0 End;

Procedure DefineSymbol(Const Name:String;Value:LongInt);
Var I:Integer;U:String;
Begin U:=Upper(Name);I:=FindSymbol(U);
 If I=0Then Begin If SymbolCount=MaxSymbols Then Begin Error('table des symboles pleine');Exit End;Inc(SymbolCount);I:=SymbolCount;Symbols[I].Name:=U;Symbols[I].Defined:=False End;
 If(Pass=1)And Symbols[I].Defined Then Error('symbole defini deux fois: '+U)
 Else Begin Symbols[I].Value:=Value;Symbols[I].Defined:=True End
End;

Function ParseNumber(Const S:String;Var V:LongInt):Boolean;
Var T:String;I,D,Code:Integer;N:LongInt;Neg:Boolean;
Begin T:=Trim(S);V:=0;ParseNumber:=False;If T=''Then Exit;Neg:=False;
 If T[1]='-'Then Begin Neg:=True;Delete(T,1,1)End Else If T[1]='+'Then Delete(T,1,1);
 If(Length(T)>=3)And(T[1]='''')And(T[Length(T)]='''')Then Begin V:=Ord(T[2]);If Neg Then V:=-V;ParseNumber:=True;Exit End;
 If Copy(Upper(T),1,2)='0X'Then Begin Delete(T,1,2);T:='$'+T End;
 If T[1]='$'Then Begin N:=0;For I:=2To Length(T)Do Begin
   If T[I]In['0'..'9']Then D:=Ord(T[I])-48 Else If UpCase(T[I])In['A'..'F']Then D:=Ord(UpCase(T[I]))-55 Else Exit;N:=N*16+D
  End;V:=N
 End Else Begin Val(T,V,Code);If Code<>0Then Exit End;
 If Neg Then V:=-V;ParseNumber:=True
End;

Function EvalExpr(Const Expr:String;Var Known:Boolean):LongInt;
Var S,Tok:String;I,Start,Sign,Idx:Integer;V,Total:LongInt;
Begin S:=Trim(Expr);I:=1;Total:=0;Sign:=1;Known:=True;
 While I<=Length(S)Do Begin
  While(I<=Length(S))And(S[I]In[' ',#9])Do Inc(I);
  If I>Length(S)Then Break;
  If S[I]='+'Then Begin Sign:=1;Inc(I);Continue End;
  If S[I]='-'Then Begin Sign:=-1;Inc(I);Continue End;
  Start:=I;If S[I]=''''Then Begin Inc(I);While(I<=Length(S))And(S[I]<>'''')Do Inc(I);If I<=Length(S)Then Inc(I)End
  Else While(I<=Length(S))And Not(S[I]In['+','-',' ',#9])Do Inc(I);
  Tok:=Copy(S,Start,I-Start);
  If Upper(Tok)='$'Then V:=PC Else If ParseNumber(Tok,V)Then Begin End Else Begin
   Idx:=FindSymbol(Tok);If(Idx=0)Or Not Symbols[Idx].Defined Then Begin Known:=False;V:=0;If Pass=2Then Error('symbole inconnu: '+Tok)End Else V:=Symbols[Idx].Value
  End;Total:=Total+Sign*V;Sign:=1
 End;EvalExpr:=Total
End;

Procedure EmitByte(B:Byte);
Var Z:Byte;
Begin If LineByteCount<MaxLineBytes Then Begin LineBytes[LineByteCount]:=B;Inc(LineByteCount)End;
 If Pass=2Then Begin
  If Not BinStarted Then Begin BinStarted:=True;BinAddress:=PC End;
  If PC<BinAddress Then Error('ORG arriere impossible dans le fichier binaire')
  Else Begin Z:=0;While BinAddress<PC Do Begin Write(Binary,Z);Inc(BinAddress)End;Write(Binary,B);Inc(BinAddress)End
 End;Inc(PC)
End;

Procedure EmitWord(W:Word);Begin EmitByte(Lo(W));EmitByte(Hi(W))End;

Function RegisterNumber(Const S:String;Var R:Byte):Boolean;
Var U,T:String;N,Code:Integer;
Begin U:=Upper(Trim(S));RegisterNumber:=True;
 If U='PC'Then R:=0 Else If U='SP'Then R:=1 Else If U='SR'Then R:=2 Else If(U='CG')Or(U='CG1')Then R:=3 Else Begin
  If(U='R0')Then R:=0 Else If(U='R1')Then R:=1 Else If(U='R2')Then R:=2 Else If(U='R3')Then R:=3
  Else If(Length(U)>1)And(U[1]='R')Then Begin T:=Copy(U,2,10);Val(T,N,Code);If(Code<>0)Or(N<4)Or(N>15)Then RegisterNumber:=False Else R:=N End
  Else RegisterNumber:=False
 End
End;

Function ParseOperand(Const Text:String;IsSource:Boolean;Var O:TOperand):Boolean;
Var S,U,Inside,Before:String;P:Integer;R:Byte;K:Boolean;
Begin FillChar(O,SizeOf(O),0);S:=Trim(Text);U:=Upper(S);ParseOperand:=False;If S=''Then Exit;
 If RegisterNumber(S,R)Then Begin O.Reg:=R;O.Mode:=0;ParseOperand:=True;Exit End;
 If S[1]='#'Then Begin If Not IsSource Then Begin Error('immediat interdit en destination');Exit End;O.Reg:=0;O.Mode:=3;O.HasExt:=True;O.ExtValue:=EvalExpr(Copy(S,2,255),K);ParseOperand:=True;Exit End;
 If S[1]='&'Then Begin O.Reg:=2;O.Mode:=1;O.HasExt:=True;O.ExtValue:=EvalExpr(Copy(S,2,255),K);ParseOperand:=True;Exit End;
 If S[1]='@'Then Begin If Not IsSource Then Begin Error('destination indirecte interdite');Exit End;Delete(S,1,1);O.Mode:=2;
  If(Length(S)>0)And(S[Length(S)]='+')Then Begin O.Mode:=3;Delete(S,Length(S),1)End;
  If Not RegisterNumber(S,R)Then Begin Error('registre indirect invalide');Exit End;O.Reg:=R;ParseOperand:=True;Exit
 End;
 P:=Pos('(',S);If(P>1)And(S[Length(S)]=')')Then Begin Before:=Copy(S,1,P-1);Inside:=Copy(S,P+1,Length(S)-P-1);
  If Not RegisterNumber(Inside,R)Then Begin Error('registre indexe invalide');Exit End;O.Reg:=R;O.Mode:=1;O.HasExt:=True;O.ExtValue:=EvalExpr(Before,K);ParseOperand:=True;Exit
 End;
 { Adresse symbolique relative au PC. }
 O.Reg:=0;O.Mode:=1;O.HasExt:=True;O.Relative:=True;O.ExtValue:=EvalExpr(S,K);ParseOperand:=True
End;

Procedure SplitOperands(Const S:String;Var A,B:String;Var Count:Integer);
Var I,Depth:Integer;InQuote:Boolean;
Begin A:='';B:='';Count:=0;Depth:=0;InQuote:=False;
 For I:=1To Length(S)Do Begin
  If S[I]=''''Then InQuote:=Not InQuote;
  If Not InQuote Then Begin If S[I]='('Then Inc(Depth)Else If S[I]=')'Then Dec(Depth);
   If(S[I]=',')And(Depth=0)Then Begin A:=Trim(Copy(S,1,I-1));B:=Trim(Copy(S,I+1,255));Count:=2;Exit End
  End
 End;If Trim(S)<>''Then Begin A:=Trim(S);Count:=1 End
End;

Function DoubleOpcode(Const Op:String):Integer;
Var U:String;
Begin U:=Upper(Op);If U='MOV'Then DoubleOpcode:=4 Else If U='ADD'Then DoubleOpcode:=5 Else If U='ADDC'Then DoubleOpcode:=6 Else If U='SUBC'Then DoubleOpcode:=7 Else If U='SUB'Then DoubleOpcode:=8 Else If U='CMP'Then DoubleOpcode:=9 Else If U='DADD'Then DoubleOpcode:=10 Else If U='BIT'Then DoubleOpcode:=11 Else If U='BIC'Then DoubleOpcode:=12 Else If U='BIS'Then DoubleOpcode:=13 Else If U='XOR'Then DoubleOpcode:=14 Else If U='AND'Then DoubleOpcode:=15 Else DoubleOpcode:=-1
End;

Function JumpOpcode(Const Op:String):Integer;
Var U:String;
Begin U:=Upper(Op);If(U='JNE')Or(U='JNZ')Then JumpOpcode:=$2000 Else If(U='JEQ')Or(U='JZ')Then JumpOpcode:=$2400 Else If(U='JNC')Or(U='JLO')Then JumpOpcode:=$2800 Else If(U='JC')Or(U='JHS')Then JumpOpcode:=$2C00 Else If U='JN'Then JumpOpcode:=$3000 Else If U='JGE'Then JumpOpcode:=$3400 Else If U='JL'Then JumpOpcode:=$3800 Else If U='JMP'Then JumpOpcode:=$3C00 Else JumpOpcode:=-1 End;

Function SingleOpcode(Const Op:String):Integer;
Var U:String;
Begin U:=Upper(Op);If U='RRC'Then SingleOpcode:=$1000 Else If U='SWPB'Then SingleOpcode:=$1080 Else If U='RRA'Then SingleOpcode:=$1100 Else If U='SXT'Then SingleOpcode:=$1180 Else If U='PUSH'Then SingleOpcode:=$1200 Else If U='CALL'Then SingleOpcode:=$1280 Else SingleOpcode:=-1 End;

Procedure AssembleInstruction(Op,Args:String);
Var A,B:String;N,D,J,S:Integer;Src,Dst:TOperand;W:Word;ByteMode:Boolean;Start,ExtAddr,Target,Off:LongInt;Known:Boolean;
Begin Start:=PC;ByteMode:=False;Op:=Upper(Op);If Copy(Op,Length(Op)-1,2)='.B'Then Begin ByteMode:=True;Delete(Op,Length(Op)-1,2)End Else If Copy(Op,Length(Op)-1,2)='.W'Then Delete(Op,Length(Op)-1,2);
 If Op='RETI'Then Begin If Trim(Args)<>''Then Error('RETI sans operande');EmitWord($1300);Exit End;
 If Op='NOP'Then Begin EmitWord($4303);Exit End;
 If Op='RET'Then Begin EmitWord($4130);Exit End;
 If Op='POP'Then Begin Op:='MOV';Args:='@SP+,'+Args End;
 If Op='BR'Then Begin Op:='MOV';Args:=Args+',PC'End;
 If Op='CLR'Then Begin Op:='MOV';Args:='#0,'+Args End;
 If Op='INC'Then Begin Op:='ADD';Args:='#1,'+Args End;
 If Op='INCD'Then Begin Op:='ADD';Args:='#2,'+Args End;
 If Op='DEC'Then Begin Op:='SUB';Args:='#1,'+Args End;
 If Op='DECD'Then Begin Op:='SUB';Args:='#2,'+Args End;
 If Op='TST'Then Begin Op:='CMP';Args:='#0,'+Args End;
 If Op='ADC'Then Begin Op:='ADDC';Args:='#0,'+Args End;
 If Op='SBC'Then Begin Op:='SUBC';Args:='#0,'+Args End;
 If Op='INV'Then Begin Op:='XOR';Args:='#-1,'+Args End;
 If(Op='RLA')Or(Op='RLC')Then Begin A:=Args;If Op='RLA'Then Op:='ADD'Else Op:='ADDC';Args:=A+','+A End;
 If Op='CLRC'Then Begin Op:='BIC';Args:='#1,SR'End;
 If Op='SETC'Then Begin Op:='BIS';Args:='#1,SR'End;
 If Op='CLRZ'Then Begin Op:='BIC';Args:='#2,SR'End;
 If Op='SETZ'Then Begin Op:='BIS';Args:='#2,SR'End;
 If Op='CLRN'Then Begin Op:='BIC';Args:='#4,SR'End;
 If Op='SETN'Then Begin Op:='BIS';Args:='#4,SR'End;
 If Op='DINT'Then Begin Op:='BIC';Args:='#8,SR'End;
 If Op='EINT'Then Begin Op:='BIS';Args:='#8,SR'End;
 D:=DoubleOpcode(Op);If D>=0Then Begin SplitOperands(Args,A,B,N);If N<>2Then Begin Error('deux operandes requis');Exit End;
  If Not ParseOperand(A,True,Src)Then Exit;If Not ParseOperand(B,False,Dst)Then Exit;
  W:=Word(D Shl 12)Or Word(Src.Reg Shl 8)Or Word(Dst.Mode Shl 7)Or Word(Src.Mode Shl 4)Or Dst.Reg;If ByteMode Then W:=W Or $40;EmitWord(W);
  If Src.HasExt Then Begin ExtAddr:=PC;Target:=Src.ExtValue;If Src.Relative Then Target:=Target-(ExtAddr+2);EmitWord(Word(Target))End;
  If Dst.HasExt Then Begin ExtAddr:=PC;Target:=Dst.ExtValue;If Dst.Relative Then Target:=Target-(ExtAddr+2);EmitWord(Word(Target))End;Exit
 End;
 S:=SingleOpcode(Op);If S>=0Then Begin SplitOperands(Args,A,B,N);If N<>1Then Begin Error('une operande requise');Exit End;If Not ParseOperand(A,True,Src)Then Exit;
  W:=Word(S)Or Word(Src.Mode Shl 4)Or Src.Reg;If ByteMode And(Op<>'SWPB')And(Op<>'SXT')And(Op<>'CALL')Then W:=W Or $40;EmitWord(W);
  If Src.HasExt Then Begin ExtAddr:=PC;Target:=Src.ExtValue;If Src.Relative Then Target:=Target-(ExtAddr+2);EmitWord(Word(Target))End;Exit
 End;
 J:=JumpOpcode(Op);If J>=0Then Begin Target:=EvalExpr(Trim(Args),Known);Off:=(Target-(PC+2))Div 2;
  If Pass=2Then Begin If((Target-(PC+2))And 1)<>0Then Error('cible de saut non alignee');If(Off< -512)Or(Off>511)Then Error('saut hors limite')End;
  EmitWord(Word(J)Or Word(Off And $3FF));Exit
 End;
 Error('instruction inconnue: '+Op)
End;

Function FirstToken(Var S:String):String;
Var I:Integer;
Begin S:=LTrim(S);I:=1;While(I<=Length(S))And Not(S[I]In[' ',#9,':'])Do Inc(I);FirstToken:=Copy(S,1,I-1);Delete(S,1,I-1);S:=LTrim(S)End;

Function IsOperation(Const S:String):Boolean;
Var U,T:String;
Begin U:=Upper(S);T:=U;If(Copy(T,Length(T)-1,2)='.B')Or(Copy(T,Length(T)-1,2)='.W')Then Delete(T,Length(T)-1,2);
 IsOperation:=(DoubleOpcode(T)>=0)Or(SingleOpcode(T)>=0)Or(JumpOpcode(T)>=0)Or(T='RETI')Or(T='RET')Or(T='NOP')Or(T='POP')Or(T='BR')Or(T='CLR')Or(T='INC')Or(T='INCD')Or(T='DEC')Or(T='DECD')Or(T='TST')Or(T='ADC')Or(T='SBC')Or(T='INV')Or(T='RLA')Or(T='RLC')Or(T='CLRC')Or(T='SETC')Or(T='CLRZ')Or(T='SETZ')Or(T='CLRN')Or(T='SETN')Or(T='DINT')Or(T='EINT')Or(U='ORG')Or(U='EQU')Or(U='DB')Or(U='BYTE')Or(U='DW')Or(U='WORD')Or(U='DS')Or(U='BSS')Or(U='END')
End;

Procedure EmitData(Const Args:String;WordData:Boolean);
Var S,T:String;P,I:Integer;V:LongInt;K:Boolean;
Begin S:=Args;Repeat P:=Pos(',',S);If P=0Then Begin T:=Trim(S);S:=''End Else Begin T:=Trim(Copy(S,1,P-1));Delete(S,1,P)End;
  If(Not WordData)And(Length(T)>=2)And(T[1]='''')And(T[Length(T)]='''')Then For I:=2To Length(T)-1Do EmitByte(Ord(T[I]))
  Else Begin V:=EvalExpr(T,K);If WordData Then EmitWord(Word(V))Else EmitByte(Byte(V))End
 Until S=''
End;

Procedure ProcessLine(Const Original:String);
Var Work,LabelName,Op,Args,First,Second:String;P,I:Integer;V,StartPC:LongInt;Known:Boolean;
Begin LineByteCount:=0;StartPC:=PC;Work:=Original;P:=Pos(';',Work);If P>0Then Work:=Copy(Work,1,P-1);Work:=Trim(Work);
 If Work<>''Then Begin First:=FirstToken(Work);LabelName:='';
  If(Length(Work)>0)And(Work[1]=':')Then Begin Delete(Work,1,1);Work:=LTrim(Work);LabelName:=First;First:=FirstToken(Work)End
  Else If Not IsOperation(First)Then Begin LabelName:=First;First:=FirstToken(Work)End;
  Op:=Upper(First);Args:=Trim(Work);If LabelName<>''Then Begin If Op='EQU'Then Begin V:=EvalExpr(Args,Known);DefineSymbol(LabelName,V)End Else DefineSymbol(LabelName,PC)End;
  If Op='ORG'Then Begin V:=EvalExpr(Args,Known);If(V<0)Or(V>$FFFF)Then Error('ORG hors plage')Else PC:=V End
  Else If Op='EQU'Then Begin If LabelName=''Then Error('EQU exige un symbole')End
  Else If(Op='DB')Or(Op='BYTE')Then EmitData(Args,False)
  Else If(Op='DW')Or(Op='WORD')Then EmitData(Args,True)
  Else If(Op='DS')Or(Op='BSS')Then Begin V:=EvalExpr(Args,Known);If V<0Then Error('taille negative')Else For I:=1To V Do EmitByte(0)End
  Else If Op='END'Then StopAssembly:=True
  Else If Op<>''Then AssembleInstruction(Op,Args)
 End;
 If Pass=2Then Begin Write(Listing,LineNumber:5,' ',Hex4(Word(StartPC)),' ');For I:=0To 7Do If I<LineByteCount Then Write(Listing,Hex2(LineBytes[I]),' ')Else Write(Listing,'   ');WriteLn(Listing,Original)End
End;

Procedure DoPass;
Var L:String;
Begin Assign(Source,SourceName);Reset(Source);If IOResult<>0Then Begin WriteLn('Impossible d''ouvrir ',SourceName);Halt(1)End;
 PC:=0;LineNumber:=0;StopAssembly:=False;If Pass=2Then Begin BinStarted:=False;BinAddress:=0 End;
 While Not Eof(Source)And Not StopAssembly Do Begin ReadLn(Source,L);Inc(LineNumber);ProcessLine(L)End;Close(Source)
End;

Procedure Usage;
Begin WriteLn('ASM430 - Assembleur MSP430 Turbo Pascal / Free Pascal');WriteLn('Syntaxe: ASM430 source[.ASM] [-B=sortie.BIN] [-L=listing.LIS] [-E]');WriteLn('Directives: ORG, EQU, DB/BYTE, DW/WORD, DS/BSS, END')End;

Procedure ParseCommandLine;
Var I,P:Integer;A,U,Base:String;
Begin SourceName:='';BinName:='';ListName:='';ShowErrors:=False;
 For I:=1To ParamCount Do Begin A:=ParamStr(I);U:=Upper(A);P:=Pos('=',A);
  If U='-E'Then ShowErrors:=True Else If(Copy(U,1,3)='-B=')Then BinName:=Copy(A,4,255)Else If Copy(U,1,3)='-L='Then ListName:=Copy(A,4,255)
  Else If(A='/?')Or(U='-H')Or(U='--HELP')Then Begin Usage;Halt End Else If SourceName=''Then SourceName:=A Else Begin Usage;Halt(1)End
 End;
 If SourceName=''Then Begin Usage;Halt(1)End;If Pos('.',SourceName)=0Then SourceName:=SourceName+'.ASM';Base:=BaseName(SourceName);If BinName=''Then BinName:=Base+'.BIN';If ListName=''Then ListName:=Base+'.LIS'
End;

BEGIN
 ParseCommandLine;SymbolCount:=0;ErrorCount:=0;Pass:=1;DoPass;
 Assign(Listing,ListName);Rewrite(Listing);If IOResult<>0Then Begin WriteLn('Impossible de creer ',ListName);Halt(1)End;
 Assign(Binary,BinName);Rewrite(Binary);If IOResult<>0Then Begin WriteLn('Impossible de creer ',BinName);Close(Listing);Halt(1)End;
 Pass:=2;DoPass;WriteLn(Listing);WriteLn(Listing,ErrorCount,' erreur(s)');Close(Binary);Close(Listing);
 If ErrorCount<>0Then Halt(1)
END.
