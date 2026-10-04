{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Assembleur Intel 8089 a deux passes. Compatible Turbo Pascal / Free Pascal.
 @license: MIT }

Program ASM89;

{$A-}
{$R-}
{$Q-}

Uses Dos;

Const
 MaxSymbols=1000;
 MaxLineBytes=32;

Type
 TSymbol=Record
  Name:String[31];
  Value:LongInt;
  Defined:Boolean
 End;
 TOperand=Record
  Kind,Reg,Base,Mode:Byte;
  Offset:LongInt
 End;

Var
 Symbols:Array[1..MaxSymbols]Of TSymbol;
 SymbolCount:Integer;
 Source,Listing:Text;
 Binary:File Of Byte;
 SourceName,ListName,BinName:String;
 Pass,LineNumber,ErrorCount:Integer;
 PC:LongInt;
 LineBytes:Array[0..MaxLineBytes-1]Of Byte;
 LineByteCount:Integer;
 BinStarted,StopAssembly,ShowErrors:Boolean;
 BinAddress:LongInt;

Function Upper(Const S:String):String;
Var
 R:String;
 I:Integer;
Begin
 R:=S;
 For I:=1To Length(R)Do R[I]:=UpCase(R[I]);Upper:=R
End;

Function LTrim(Const S:String):String;
Var
 I:Integer;
Begin
 I:=1;
 While(I<=Length(S))And(S[I]In[' ',#9])Do Inc(I);LTrim:=Copy(S,I,255)
End;

Function RTrim(Const S:String):String;
Var
 I:Integer;
Begin
 I:=Length(S);
 While(I>0)And(S[I]In[' ',#9,#13,#10])Do Dec(I);RTrim:=Copy(S,1,I)
End;

Function Trim(Const S:String):String;Begin
 Trim:=LTrim(RTrim(S))
End;

Function Hex2(V:Byte):String;
Const
 H:String[16]='0123456789ABCDEF';
Begin
 Hex2:=H[(V Shr 4)+1]+H[(V And 15)+1]
End;

Function Hex4(V:Word):String;Begin
 Hex4:=Hex2(Hi(V))+Hex2(Lo(V))
End;

Function BaseName(Const S:String):String;
Var
 I,D:Integer;
Begin
 D:=0;
 For I:=1To Length(S)Do If S[I]='.'Then D:=I;If D=0Then D:=Length(S)+1;
 BaseName:=Copy(S,1,D-1)
End;

Procedure Error(Const S:String);Begin
 Inc(ErrorCount);If Pass=2Then Begin
  WriteLn(Listing,'***** Ligne ',LineNumber,': ',S);
  If ShowErrors Then WriteLn('Erreur ligne ',LineNumber,': ',S)
 End
End;

Function FindSymbol(Const Name:String):Integer;
Var
 I:Integer;
 U:String;
Begin
 U:=Upper(Name);
 For I:=1To SymbolCount Do If Symbols[I].Name=U Then Begin
  FindSymbol:=I;Exit
 End;FindSymbol:=0
End;

Procedure DefineSymbol(Const Name:String;V:LongInt);
Var
 I:Integer;
 U:String;
Begin
 U:=Upper(Name);I:=FindSymbol(U);If I=0Then Begin
  If SymbolCount=MaxSymbols Then Begin
   Error('table des symboles pleine');Exit
  End;Inc(SymbolCount);I:=SymbolCount;Symbols[I].Name:=U;Symbols[I].Defined:=False
 End;
 If(Pass=1)And Symbols[I].Defined Then Error('symbole defini deux fois: '+U)Else
 Begin
  Symbols[I].Value:=V;Symbols[I].Defined:=True
 End
End;

Function ParseNumber(Const Text:String;Var V:LongInt):Boolean;
Var
 S:String;
 I,D,Code,Base:Integer;
 N:LongInt;
 Neg:Boolean;
Begin
 S:=Upper(Trim(Text));V:=0;ParseNumber:=False;If S=''Then Exit;Neg:=False;
 If S[1]='-'Then Begin
  Neg:=True;Delete(S,1,1)
 End Else If S[1]='+'Then Delete(S,1,1);
 If(Length(S)>=3)And(S[1]='''')And(S[Length(S)]='''')Then Begin
  N:=0;
  For I:=2To Length(S)-1Do N:=N*256+Ord(S[I]);If Neg Then N:=-N;V:=N;ParseNumber:=True;
  Exit
 End;
 Base:=10;If Copy(S,1,2)='0X'Then Begin
  Base:=16;Delete(S,1,2)
 End Else If S[1]='$'Then Begin
  Base:=16;Delete(S,1,1)
 End
 Else If S[Length(S)]='H'Then Begin
  Base:=16;Delete(S,Length(S),1)
 End Else If S[Length(S)]='Q'Then Begin
  Base:=8;Delete(S,Length(S),1)
 End;
 If Base=10Then Begin
  Val(S,N,Code);If Code<>0Then Exit
 End Else
 Begin
  N:=0;If S=''Then Exit;
  For I:=1To Length(S)Do Begin
   If S[I]In['0'..'9']Then D:=Ord(S[I])-48 Else If S[I]In['A'..'F']Then D:=Ord(S[I])-
   55 Else Exit;If D>=Base Then Exit;N:=N*Base+D
  End
 End;If Neg Then N:=-N;V:=N;ParseNumber:=True
End;

Function EvalExpr(Const Expr:String;Var Known:Boolean):LongInt;
Var
 S,T:String;
 I,St,Sign,Idx:Integer;
 V,N:LongInt;
Begin
 S:=Trim(Expr);I:=1;V:=0;Sign:=1;Known:=True;
 While I<=Length(S)Do Begin
  While(I<=Length(S))And(S[I]In[' ',#9])Do Inc(I);If I>Length(S)Then Break;
  If S[I]='+'Then Begin
   Sign:=1;Inc(I);Continue
  End;If S[I]='-'Then Begin
   Sign:=-1;Inc(I);Continue
  End;St:=I;
  If S[I]=''''Then Begin
   Inc(I);
   While(I<=Length(S))And(S[I]<>'''')Do Inc(I);If I<=Length(S)Then Inc(I)
  End
   Else
  While(I<=Length(S))And Not(S[I]In['+','-',' ',#9])Do Inc(I);T:=Copy(S,St,I-St);
  If T='$'Then N:=PC Else If ParseNumber(T,N)Then Begin
  End Else
  Begin
   Idx:=FindSymbol(T);If(Idx=0)Or Not Symbols[Idx].Defined Then Begin
    Known:=False;N:=0;If Pass=2Then Error('symbole inconnu: '+T)
   End Else N:=Symbols[Idx].Value
  End;
  V:=V+Sign*N;Sign:=1
 End;EvalExpr:=V
End;

Procedure EmitByte(B:Byte);
Var
 Z:Byte;
Begin
 If LineByteCount<MaxLineBytes Then Begin
  LineBytes[LineByteCount]:=B;Inc(LineByteCount)
 End;
 If Pass=2Then Begin
  If Not BinStarted Then Begin
   BinStarted:=True;BinAddress:=PC
  End;If PC<BinAddress Then Error('ORG arriere impossible')Else
  Begin
   Z:=0;
   While BinAddress<PC Do Begin
    Write(Binary,Z);Inc(BinAddress)
   End;Write(Binary,B);Inc(BinAddress)
  End
 End;Inc(PC)
End;

Procedure EmitWord(W:Word);Begin
 EmitByte(Lo(W));EmitByte(Hi(W))
End;

Procedure EmitLong(V:LongInt);Begin
 EmitWord(Word(V));EmitWord(Word(V Shr 16))
End;

Function RegisterNumber(Const S:String;Var R:Byte):Boolean;
Var
 U:String;
Begin
 U:=Upper(Trim(S));RegisterNumber:=True;
 If U='GA'Then R:=0 Else If U='GB'Then R:=1 Else If U='GC'Then R:=2 Else If U='BC'Then R:=
 3 Else If U='TP'Then R:=4 Else If U='IX'Then R:=5 Else If U='CC'Then R:=6 Else If U=
 'MC'Then R:=7 Else RegisterNumber:=False
End;

Function PointerNumber(Const S:String;Var R:Byte):Boolean;
Var
 U:String;
Begin
 U:=Upper(Trim(S));PointerNumber:=True;
 If U='GA'Then R:=0 Else If U='GB'Then R:=1 Else If U='GC'Then R:=2 Else If U='TP'Then R:=
 4 Else PointerNumber:=False
End;

Function ParseMemory(Const Text:String;Var O:TOperand):Boolean;
Var
 S,Inside,Tail,BaseName:String;
 P:Integer;
 K:Boolean;
Begin
 ParseMemory:=False;S:=Trim(Text);If(Length(S)<3)Or(S[1]<>'[')Then Exit;P:=Pos(']',S);
 If P=0Then Begin
  Error('crochet ] manquant');Exit
 End;
 Inside:=Upper(Trim(Copy(S,2,P-2)));Tail:=Trim(Copy(S,P+1,255));O.Kind:=2;O.Offset:=0;
 If Pos('+IX+',Inside)>0Then Begin
  O.Mode:=3;BaseName:=Trim(Copy(Inside,1,Pos('+',Inside)-1))
 End
 Else If Pos('+IX',Inside)>0Then Begin
  O.Mode:=2;BaseName:=Trim(Copy(Inside,1,Pos('+',Inside)-1))
 End
  Else
 Begin
  O.Mode:=0;BaseName:=Inside
 End;
 If BaseName='GA'Then O.Base:=0 Else If BaseName='GB'Then O.Base:=1 Else If BaseName=
 'GC'Then O.Base:=2 Else If BaseName='PP'Then O.Base:=3 Else
 Begin
  Error('registre de base invalide: '+BaseName);Exit
 End;
 If Tail<>''Then Begin
  If Tail[1]<>'.'Then Begin
   Error('offset memoire invalide');Exit
  End;If O.Mode<>0Then Begin
   Error('offset incompatible avec IX');Exit
  End;O.Mode:=1;O.Offset:=EvalExpr(Copy(Tail,2,255),K)
 End;ParseMemory:=True
End;

Function ParseOperand(Const S:String;Var O:TOperand):Boolean;
Var
 R:Byte;
Begin
 FillChar(O,SizeOf(O),0);If ParseMemory(S,O)Then Begin
  ParseOperand:=True;Exit
 End;If RegisterNumber(S,R)Then Begin
  O.Kind:=1;O.Reg:=R;ParseOperand:=True;Exit
 End;ParseOperand:=False
End;

Procedure SplitOperands(Const S:String;Var A,B,C:String;Var Count:Integer);
Var
 I,St,Depth:Integer;
 Q:Boolean;
 T:String;
Begin
 A:='';B:='';C:='';Count:=0;St:=1;Depth:=0;Q:=False;
 For I:=1To Length(S)+1Do Begin
  If I<=Length(S)Then Begin
   If S[I]=''''Then Q:=Not Q;If Not Q Then Begin
    If S[I]='['Then Inc(Depth)Else If S[I]=']'Then Dec(Depth)
   End
  End;
  If(I>Length(S))Or((S[I]=',')And(Depth=0)And Not Q)Then Begin
   T:=Trim(Copy(S,St,I-St));If T<>''Then Begin
    Inc(Count);If Count=1Then A:=T Else If Count=2Then B:=T Else If Count=3Then C:=T
   End;St:=I+1
  End
 End
End;

Procedure EmitMemory(Const M:TOperand;Selector,Opcode:Byte;WordData:Boolean);
Var
 B:Byte;
Begin
 B:=Selector Shl 5;If WordData Then B:=B Or 1;B:=B Or(M.Mode Shl 1);EmitByte(B);
 EmitByte(Opcode Or M.Base);If M.Mode=1Then EmitByte(Byte(M.Offset))
End;

Procedure EmitImmediate(V:LongInt;WordData:Boolean);Begin
 If WordData Then EmitWord(Word(V))Else EmitByte(Byte(V))
End;

Function IsMnemonic(Const S:String):Boolean;
Const
 Names:String=
 ' MOV MOVB MOVI MOVBI MOVP LPD LPDI ADD ADDB ADDI ADDBI INC INCB DEC DECB AND ANDB ANDI ANDBI OR ORB ORI '+
 'ORBI NOT NOTB SETB CLR CALL LCALL JMP LJMP JZ LJZ JZB LJZB JNZ LJNZ JNZB LJNZB JMCE LJMCE JMCNE LJMCNE JBT '+
 'LJBT JNBT LJNBT TSL WID XFER SINTR HLT NOP ';
Begin
 IsMnemonic:=Pos(' '+Upper(S)+' ',Names)>0
End;

Function IsDirective(Const S:String):Boolean;
Const
 Names:String=
 ' ORG EQU DB BYTE DW WORD DD DS BSS EVEN NAME SEGMENT ENDS PUBLIC EXTRN END ';
Begin
 IsDirective:=Pos(' '+Upper(S)+' ',Names)>0
End;

Procedure AssembleRM(Const Op:String;Const A,B:TOperand);
Var
 FromMem,ToMem:Byte;
 WordData:Boolean;
Begin
 WordData:=(Op<>'MOVB')And(Op<>'ADDB')And(Op<>'ANDB')And(Op<>'ORB');
 If(Op='MOV')Or(Op='MOVB')Then Begin
  FromMem:=$80;ToMem:=$84
 End
 Else If(Op='ADD')Or(Op='ADDB')Then Begin
  FromMem:=$A0;ToMem:=$D0
 End
 Else If(Op='AND')Or(Op='ANDB')Then Begin
  FromMem:=$A8;ToMem:=$D8
 End Else
 Begin
  FromMem:=$A4;ToMem:=$D4
 End;
 If(A.Kind=1)And(B.Kind=2)Then EmitMemory(B,A.Reg,FromMem,WordData)
 Else If(A.Kind=2)And(B.Kind=1)Then EmitMemory(A,B.Reg,ToMem,WordData)
 Else Error('forme registre/memoire attendue')
End;

Procedure AssembleImmediate(Const Op:String;Const Dest:TOperand;V:LongInt);
Var
 RegOp,MemOp,Lead:Byte;
 WordData:Boolean;
Begin
 WordData:=(Op='MOVI')Or(Op='ADDI')Or(Op='ANDI')Or(Op='ORI');
 If(Op='MOVI')Or(Op='MOVBI')Then Begin
  RegOp:=$30;MemOp:=$4C
 End
 Else If(Op='ADDI')Or(Op='ADDBI')Then Begin
  RegOp:=$20;MemOp:=$C0
 End Else If(Op='ANDI')Or(Op='ANDBI')Then Begin
  RegOp:=$28;MemOp:=$C8
 End Else
 Begin
  RegOp:=$24;MemOp:=$C4
 End;
 If Dest.Kind=1Then Begin
  If WordData Then Lead:=$11 Else Lead:=$08;EmitByte((Dest.Reg Shl 5)Or Lead);
  EmitByte(RegOp);EmitImmediate(V,WordData)
 End
 Else If Dest.Kind=2Then Begin
  If WordData Then Lead:=$10 Else Lead:=$08;
  EmitByte(Lead Or(Dest.Mode Shl 1)Or Ord(WordData));EmitByte(MemOp Or Dest.Base);
  If Dest.Mode=1Then EmitByte(Byte(Dest.Offset));EmitImmediate(V,WordData)
 End
 Else Error('destination invalide')
End;

Procedure EmitJump(Const Op:String;Const Test:TOperand;Target:LongInt);
Var
 LongForm,ByteForm:Boolean;
 Opcode,Lead,Len:Byte;
 Disp:LongInt;
Begin
 LongForm:=(Op[1]='L');
 ByteForm:=(Pos('ZB',Op)>0)Or(Pos('NZB',Op)>0)Or(Pos('MCE',Op)>0)Or(Pos('MCNE',Op)>0);
 If(Op='JMP')Or(Op='LJMP')Then Begin
  Len:=3+Ord(LongForm);Disp:=Target-(PC+Len);
  If(Pass=2)And Not LongForm And((Disp< -128)Or(Disp>127))Then Error(
  'saut court hors limite');If LongForm Then Begin
   EmitByte($91);EmitByte($20);EmitWord(Word(Disp))
  End Else
  Begin
   EmitByte($88);EmitByte($20);EmitByte(Byte(Disp))
  End;Exit
 End;
 If Pos('JNZ',Op)>0Then Opcode:=$E0 Else If Pos('JZ',Op)>0Then Opcode:=$E4 Else If Pos(
 'JMCNE',Op)>0Then Opcode:=$B4 Else Opcode:=$B0;
 Len:=2+Ord(Test.Mode=1)+1+Ord(LongForm);Disp:=Target-(PC+Len);
 If Test.Kind=1Then Begin
  If LongForm Then Lead:=$10 Else Lead:=$08;EmitByte((Test.Reg Shl 5)Or Lead);
  EmitByte(Opcode)
 End
  Else
 Begin
  If LongForm Then Lead:=$10 Else Lead:=$08;If Not ByteForm Then Lead:=Lead Or 1;
  EmitByte(Lead Or(Test.Mode Shl 1));EmitByte(Opcode Or Test.Base);
  If Test.Mode=1Then EmitByte(Byte(Test.Offset))
 End;
 If LongForm Then EmitWord(Word(Disp))Else EmitByte(Byte(Disp));
 If(Pass=2)And Not LongForm And((Disp< -128)Or(Disp>127))Then Error(
 'saut court hors limite')
End;

Procedure AssembleInstruction(Op,Args:String);
Var
 A,B,C:String;
 N:Integer;
 O1,O2:TOperand;
 V,T:LongInt;
 K:Boolean;
 Code,Lead:Byte;
 LongForm:Boolean;
Begin
 Op:=Upper(Op);SplitOperands(Args,A,B,C,N);
 If(Op='NOP')Or(Op='SINTR')Or(Op='XFER')Or(Op='HLT')Then Begin
  If N<>0Then Error('instruction sans operande');If Op='NOP'Then Begin
   EmitByte(0);EmitByte(0)
  End Else If Op='SINTR'Then Begin
   EmitByte($40);EmitByte(0)
  End Else If Op='XFER'Then Begin
   EmitByte($60);EmitByte(0)
  End Else
  Begin
   EmitByte($20);EmitByte($48)
  End;Exit
 End;
 If Op='WID'Then Begin
  If N<>2Then Begin
   Error('WID exige deux operandes');Exit
  End;V:=EvalExpr(A,K);T:=EvalExpr(B,K);Lead:=$80;
  If V=16Then Lead:=Lead Or $40 Else If V<>8Then Error('largeur source 8 ou 16 attendue');
  If T=16Then Lead:=Lead Or $20 Else If T<>8Then Error(
  'largeur destination 8 ou 16 attendue');EmitByte(Lead);EmitByte(0);Exit
 End;
 If(Op='MOV')Or(Op='MOVB')Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,O1)Then Begin
   Error('premiere operande invalide');Exit
  End;If Not ParseOperand(B,O2)Then Begin
   Error('seconde operande invalide');Exit
  End;
  If(O1.Kind=2)And(O2.Kind=2)Then Begin
   EmitMemory(O2,0,$90,Op='MOV');EmitMemory(O1,0,$CC,Op='MOV')
  End Else AssembleRM(Op,O1,O2);Exit
 End;
 If(Op='ADD')Or(Op='ADDB')Or(Op='AND')Or(Op='ANDB')Or(Op='OR')Or(Op='ORB')Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,O1)Or Not ParseOperand(B,O2)Then Begin
   Error('operande invalide');Exit
  End;AssembleRM(Op,O1,O2);Exit
 End;
 If(Op='MOVI')Or(Op='MOVBI')Or(Op='ADDI')Or(Op='ADDBI')Or(Op='ANDI')Or(Op='ANDBI')Or(Op=
 'ORI')Or(Op='ORBI')Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,O1)Then Begin
   Error('destination invalide');Exit
  End;V:=EvalExpr(B,K);AssembleImmediate(Op,O1,V);Exit
 End;
 If(Op='INC')Or(Op='INCB')Or(Op='DEC')Or(Op='DECB')Then Begin
  If N<>1Then Begin
   Error('une operande requise');Exit
  End;If Not ParseOperand(A,O1)Then Begin
   Error('operande invalide');Exit
  End;
  If O1.Kind=1Then Begin
   EmitByte(O1.Reg Shl 5);If Op='INC'Then Code:=$38 Else If Op='DEC'Then Code:=$3C Else
   Begin
    Error('forme octet exige la memoire');Code:=0
   End;EmitByte(Code)
  End
   Else
  Begin
   If(Op='INC')Or(Op='INCB')Then Code:=$E8 Else Code:=$EC;
   EmitMemory(O1,0,Code,(Op='INC')Or(Op='DEC'))
  End;Exit
 End;
 If(Op='NOT')Or(Op='NOTB')Then Begin
  If(N<1)Or(N>2)Then Begin
   Error('une ou deux operandes requises');Exit
  End;If Not ParseOperand(A,O1)Then Begin
   Error('operande invalide');Exit
  End;
  If N=2Then Begin
   If Not ParseOperand(B,O2)Then Begin
    Error('operande invalide');Exit
   End;
   If(O1.Kind<>1)Or(O2.Kind<>2)Then Error('forme NOT R,M attendue')Else EmitMemory(O2,
   O1.Reg,$AC,Op='NOT')
  End
  Else If O1.Kind=1Then Begin
   EmitByte(O1.Reg Shl 5);EmitByte($2C)
  End Else EmitMemory(O1,0,$DC,Op='NOT');Exit
 End;
 If(Op='SETB')Or(Op='CLR')Then Begin
  If N<>2Then Begin
   Error('memoire et bit requis');Exit
  End;If Not ParseMemory(A,O1)Then Exit;V:=EvalExpr(B,K);
  If(V<0)Or(V>7)Then Error('numero de bit hors plage');
  If Op='SETB'Then Code:=$F4 Else Code:=$F8;EmitMemory(O1,Byte(V),Code,False);Exit
 End;
 If Op='MOVP'Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,O1)Or Not ParseOperand(B,O2)Then Begin
   Error('operande invalide');Exit
  End;
  If(O1.Kind=1)And(O2.Kind=2)And PointerNumber(A,Lead)Then EmitMemory(O2,Lead,$8C,True)
  Else If(O1.Kind=2)And(O2.Kind=1)And PointerNumber(B,Lead)Then EmitMemory(O1,Lead,$98,
  True)Else Error('MOVP exige un pointeur et une memoire');Exit
 End;
 If Op='LPD'Then Begin
  If(N<>2)Or Not PointerNumber(A,Lead)Or Not ParseMemory(B,O2)Then Begin
   Error('LPD P,M attendu');Exit
  End;EmitMemory(O2,Lead,$88,True);Exit
 End;
 If Op='LPDI'Then Begin
  If(N<>2)Or Not PointerNumber(A,Lead)Then Begin
   Error('LPDI P,I attendu');Exit
  End;V:=EvalExpr(B,K);EmitByte((Lead Shl 5)Or $11);EmitByte($08);EmitLong(V);Exit
 End;
 If(Op='JMP')Or(Op='LJMP')Then Begin
  If N<>1Then Begin
   Error('cible requise');Exit
  End;V:=EvalExpr(A,K);FillChar(O1,SizeOf(O1),0);EmitJump(Op,O1,V);Exit
 End;
 If(Pos('JZ',Op)>0)Or(Pos('JNZ',Op)>0)Or(Pos('JMCE',Op)>0)Or(Pos('JMCNE',Op)>0)Then Begin
  If N<>2Then Begin
   Error('test et cible requis');Exit
  End;If Not ParseOperand(A,O1)Then Begin
   Error('test invalide');Exit
  End;
  If((Pos('MCE',Op)>0)Or(Pos('MCNE',Op)>0)Or(Pos('ZB',Op)>0)Or(Pos('NZB',Op)>0))And(
  O1.Kind<>2)Then Begin
   Error('cette forme exige une operande memoire');Exit
  End;V:=EvalExpr(B,K);EmitJump(Op,O1,V);Exit
 End;
 If(Op='CALL')Or(Op='LCALL')Then Begin
  If(N<>2)Or Not ParseMemory(A,O1)Then Begin
   Error('CALL M,cible attendu');Exit
  End;LongForm:=Op='LCALL';V:=EvalExpr(B,K);T:=2+Ord(O1.Mode=1)+1+Ord(LongForm);
  T:=V-(PC+T);
  If(Pass=2)And Not LongForm And((T< -128)Or(T>127))Then Error('CALL court hors limite');
  If LongForm Then Lead:=$10 Else Lead:=$08;EmitByte(Lead Or(O1.Mode Shl 1)Or 1);
  EmitByte($9C Or O1.Base);If O1.Mode=1Then EmitByte(Byte(O1.Offset));
  If LongForm Then EmitWord(Word(T))Else EmitByte(Byte(T));Exit
 End;
 If(Op='JBT')Or(Op='LJBT')Or(Op='JNBT')Or(Op='LJNBT')Then Begin
  If(N<>3)Or Not ParseMemory(A,O1)Then Begin
   Error('memoire, bit et cible requis');Exit
  End;V:=EvalExpr(B,K);If(V<0)Or(V>7)Then Error('numero de bit hors plage');
  T:=EvalExpr(C,K);LongForm:=Op[1]='L';If Pos('JNBT',Op)>0Then Code:=$B8 Else Code:=$BC;
  Lead:=$08;If LongForm Then Lead:=$10;N:=2+Ord(O1.Mode=1)+1+Ord(LongForm);T:=T-(PC+N);
  If(Pass=2)And Not LongForm And((T< -128)Or(T>127))Then Error('saut court hors limite');
  EmitByte((Byte(V)Shl 5)Or Lead Or(O1.Mode Shl 1));EmitByte(Code Or O1.Base);
  If O1.Mode=1Then EmitByte(Byte(O1.Offset));
  If LongForm Then EmitWord(Word(T))Else EmitByte(Byte(T));Exit
 End;
 If Op='TSL'Then Begin
  If(N<>3)Or Not ParseMemory(A,O1)Then Begin
   Error('TSL M,I,cible attendu');Exit
  End;V:=EvalExpr(B,K);T:=EvalExpr(C,K);N:=2+Ord(O1.Mode=1)+2;T:=T-(PC+N);
  If(Pass=2)And((T< -128)Or(T>127))Then Error('saut TSL hors limite');
  EmitByte($18 Or(O1.Mode Shl 1));EmitByte($94 Or O1.Base);
  If O1.Mode=1Then EmitByte(Byte(O1.Offset));EmitByte(Byte(V));EmitByte(Byte(T));Exit
 End;
 Error('instruction inconnue: '+Op)
End;

Function FirstToken(Var S:String):String;
Var
 I:Integer;
Begin
 S:=LTrim(S);I:=1;
 While(I<=Length(S))And Not(S[I]In[' ',#9,':'])Do Inc(I);FirstToken:=Copy(S,1,I-1);
 Delete(S,1,I-1);S:=LTrim(S)
End;

Procedure EmitData(Const Args:String;Size:Byte);
Var
 S,T:String;
 I,P:Integer;
 V:LongInt;
 K:Boolean;
Begin
 S:=Args;Repeat P:=Pos(',',S);If P=0Then Begin
  T:=Trim(S);S:=''
 End Else
 Begin
  T:=Trim(Copy(S,1,P-1));Delete(S,1,P)
 End;
 If(Size=1)And(Length(T)>=2)And(T[1]='''')And(T[Length(T)]='''')Then
 For I:=2To Length(T)-1Do EmitByte(Ord(T[I]))Else
 Begin
  V:=EvalExpr(T,K);
  If Size=1Then EmitByte(Byte(V))Else If Size=2Then EmitWord(Word(V))Else EmitLong(V)
 End
 Until S=''
End;

Procedure ProcessLine(Const Original:String);
Var
 Work,First,LabelName,Op,Args:String;
 P,I:Integer;
 V,StartPC:LongInt;
 K:Boolean;
Begin
 LineByteCount:=0;StartPC:=PC;Work:=Original;P:=Pos(';',Work);
 If P>0Then Work:=Copy(Work,1,P-1);Work:=Trim(Work);
 If Work<>''Then Begin
  First:=FirstToken(Work);LabelName:='';If(Length(Work)>0)And(Work[1]=':')Then Begin
   Delete(Work,1,1);Work:=LTrim(Work);LabelName:=First;First:=FirstToken(Work)
  End
  Else If Not IsMnemonic(First)And Not IsDirective(First)Then Begin
   LabelName:=First;First:=FirstToken(Work)
  End;Op:=Upper(First);Args:=Trim(Work);
  If LabelName<>''Then Begin
   If Op='EQU'Then Begin
    V:=EvalExpr(Args,K);DefineSymbol(LabelName,V)
   End Else DefineSymbol(LabelName,PC)
  End;
  If Op='ORG'Then Begin
   V:=EvalExpr(Args,K);If(V<0)Or(V>$FFFF)Then Error('ORG hors plage')Else PC:=V
  End Else If Op='EQU'Then Begin
   If LabelName=''Then Error('EQU exige un symbole')
  End
  Else If(Op='DB')Or(Op='BYTE')Then EmitData(Args,1)Else If(Op='DW')Or(Op='WORD')
  Then EmitData(Args,2)Else If Op='DD'Then EmitData(Args,4)
  Else If(Op='DS')Or(Op='BSS')Then Begin
   V:=EvalExpr(Args,K);If V<0Then Error('taille negative')Else
   For I:=1To V Do EmitByte(0)
  End
  Else If Op='EVEN'Then Begin
   If Odd(PC)Then EmitByte(0)
  End
  Else If(Op='NAME')Or(Op='SEGMENT')Or(Op='ENDS')Or(Op='PUBLIC')Then Begin
  End
  Else If Op='EXTRN'Then Error(
  'EXTRN exige un editeur de liens et n''est pas disponible en sortie binaire')
  Else If Op='END'Then StopAssembly:=True Else If Op<>''Then AssembleInstruction(Op,Args)
 End;
 If Pass=2Then Begin
  Write(Listing,LineNumber:5,' ',Hex4(Word(StartPC)),' ');
  For I:=0To 7Do If I<LineByteCount Then Write(Listing,Hex2(LineBytes[I]),' ')Else Write(
  Listing,'   ');WriteLn(Listing,Original)
 End
End;

Procedure DoPass;
Var
 L:String;
Begin
 Assign(Source,SourceName);Reset(Source);If IOResult<>0Then Begin
  WriteLn('Impossible d''ouvrir ',SourceName);Halt(1)
 End;PC:=0;LineNumber:=0;StopAssembly:=False;If Pass=2Then Begin
  BinStarted:=False;BinAddress:=0
 End;
 While Not Eof(Source)And Not StopAssembly Do Begin
  ReadLn(Source,L);Inc(LineNumber);ProcessLine(L)
 End;Close(Source)
End;

Procedure Usage;Begin
 WriteLn('ASM89 - Cette commande permet de lancer le compilateur assembleur Intel 8089.');
 WriteLn;
 WriteLn('Syntaxe: ASM89 source[.ASM] [-B=sortie.BIN] [-L=listing.LIS] [-E]');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  -B=sortie.BIN   Fichier binaire de sortie');
 WriteLn('  -L=listing.LIS  Fichier de listing');
 WriteLn('  -E              Afficher les erreurs');
 
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 A,U,Base:String;
Begin
 SourceName:='';BinName:='';ListName:='';ShowErrors:=False;
 For I:=1To ParamCount Do Begin
  A:=ParamStr(I);U:=Upper(A);
  If U='-E'Then ShowErrors:=True Else If Copy(U,1,3)='-B='Then BinName:=Copy(A,4,255)
  Else If Copy(U,1,3)='-L='Then ListName:=Copy(A,4,255)
  Else If(A='/?')Or(U='-H')Or(U='--HELP')Then Begin
   Usage;Halt
  End Else If SourceName=''Then SourceName:=A Else
  Begin
   Usage;Halt(1)
  End
 End;
 If SourceName=''Then Begin
  Usage;Halt(1)
 End;If Pos('.',SourceName)=0Then SourceName:=SourceName+'.ASM';
 Base:=BaseName(SourceName);If BinName=''Then BinName:=Base+'.BIN';
 If ListName=''Then ListName:=Base+'.LIS'
End;

BEGIN
 ParseCommandLine;SymbolCount:=0;ErrorCount:=0;Pass:=1;DoPass;
 Assign(Listing,ListName);Rewrite(Listing);If IOResult<>0Then Begin
  WriteLn('Impossible de creer ',ListName);Halt(1)
 End;Assign(Binary,BinName);Rewrite(Binary);If IOResult<>0Then Begin
  WriteLn('Impossible de creer ',BinName);Close(Listing);Halt(1)
 End;
 Pass:=2;DoPass;WriteLn(Listing);WriteLn(Listing,ErrorCount,' erreur(s)');Close(Binary);
 Close(Listing);If ErrorCount<>0Then Halt(1)
END.
