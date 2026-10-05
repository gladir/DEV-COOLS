{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
 @description: Assembleur Zilog Z8000/Z8002 non segmente, Turbo Pascal / Free Pascal. }

Program ASMZ8000;

{$A-}
{$R-}
{$Q-}

Uses Dos;

Const
 MaxSymbols=1500;
 MaxLineBytes=32;
 OK_REG=1;
 OK_BREG=2;
 OK_LREG=3;
 OK_IND=4;
 OK_IMM=5;
 OK_ADDR=6;
 OK_INDEX=7;

Type
 TSymbol=Record
  Name:String[31];
  Value:LongInt;
  Defined:Boolean
 End;
 TOperand=Record
  Kind,Reg,Index:Byte;
  Value:LongInt
 End;

Var
 Symbols:Array[1..MaxSymbols]Of TSymbol;
 SymbolCount:Integer;
 Source,Listing:Text;
 Binary:File Of Byte;
 SourceName,ListName,BinName:String;
 Pass,LineNumber,ErrorCount:Integer;
 PC,BinAddress:LongInt;
 LineBytes:Array[0..MaxLineBytes-1]Of Byte;
 LineByteCount:Integer;
 BinStarted,StopAssembly,ShowErrors:Boolean;

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
 End Else If S[Length(S)]='H'Then Begin
  Base:=16;Delete(S,Length(S),1)
 End Else If S[Length(S)]='B'Then Begin
  Base:=2;Delete(S,Length(S),1)
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
 End;
 If Neg Then N:=-N;V:=N;ParseNumber:=True
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
  End Else
  While(I<=Length(S))And Not(S[I]In['+','-',' ',#9])Do Inc(I);T:=Copy(S,St,I-St);
  If T='$'Then N:=PC Else If ParseNumber(T,N)Then Begin
  End Else
  Begin
   Idx:=FindSymbol(T);If(Idx=0)Or Not Symbols[Idx].Defined Then Begin
    Known:=False;N:=0;If Pass=2Then Error('symbole inconnu: '+T)
   End Else N:=Symbols[Idx].Value
  End;V:=V+Sign*N;Sign:=1
 End;EvalExpr:=V
End;

Procedure EmitByte(B:Byte);
Var
 Z:Byte;
Begin
 If LineByteCount<MaxLineBytes Then Begin
  LineBytes[LineByteCount]:=B;Inc(LineByteCount)
 End;If Pass=2Then Begin
  If Not BinStarted Then Begin
   BinStarted:=True;BinAddress:=PC
  End;
  If PC<BinAddress Then Error('ORG arriere impossible')Else
  Begin
   Z:=0;
   While BinAddress<PC Do Begin
    Write(Binary,Z);Inc(BinAddress)
   End;Write(Binary,B);Inc(BinAddress)
  End
 End;Inc(PC)
End;

Procedure EmitWord(W:Word);Begin
 EmitByte(Hi(W));EmitByte(Lo(W))
End;

Procedure EmitLong(V:LongInt);Begin
 EmitWord(Word(V Shr 16));EmitWord(Word(V))
End;

Function ParseRegister(Const Text:String;Var Kind,Num:Byte):Boolean;
Var
 S,T:String;
 N,C:Integer;
Begin
 S:=Upper(Trim(Text));ParseRegister:=False;Kind:=0;Num:=0;
 If(Length(S)>=2)And(S[1]='R')And(S[2]In['0'..'9'])Then Begin
  T:=Copy(S,2,3);Val(T,N,C);If(C=0)And(N>=0)And(N<=15)Then Begin
   Kind:=OK_REG;Num:=N;ParseRegister:=True
  End;Exit
 End;
 If(Length(S)>=3)And(Copy(S,1,2)='RH')Then Begin
  Val(Copy(S,3,2),N,C);If(C=0)And(N>=0)And(N<=7)Then Begin
   Kind:=OK_BREG;Num:=N;ParseRegister:=True
  End;Exit
 End;
 If(Length(S)>=3)And(Copy(S,1,2)='RL')Then Begin
  Val(Copy(S,3,2),N,C);If(C=0)And(N>=0)And(N<=7)Then Begin
   Kind:=OK_BREG;Num:=N+8;ParseRegister:=True
  End;Exit
 End;
 If(Length(S)>=3)And(Copy(S,1,2)='RR')Then Begin
  Val(Copy(S,3,2),N,C);If(C=0)And(N>=0)And(N<=14)And Not Odd(N)Then Begin
   Kind:=OK_LREG;Num:=N;ParseRegister:=True
  End
 End
End;

Function ParseOperand(Const Text:String;Var O:TOperand):Boolean;
Var
 S,Inside,Before:String;
 K,R:Byte;
 P:Integer;
 Known:Boolean;
Begin
 FillChar(O,SizeOf(O),0);S:=Trim(Text);ParseOperand:=False;If S=''Then Exit;
 If S[1]='#'Then Begin
  O.Kind:=OK_IMM;O.Value:=EvalExpr(Copy(S,2,255),Known);ParseOperand:=True;Exit
 End;
 If S[1]='@'Then Begin
  If Not ParseRegister(Copy(S,2,255),K,R)Or(K<>OK_REG)Or(R=0)Then Begin
   Error('registre indirect invalide');Exit
  End;O.Kind:=OK_IND;O.Reg:=R;ParseOperand:=True;Exit
 End;
 If ParseRegister(S,K,R)Then Begin
  O.Kind:=K;O.Reg:=R;ParseOperand:=True;Exit
 End;
 P:=Pos('(',S);If(P>1)And(S[Length(S)]=')')Then Begin
  Before:=Trim(Copy(S,1,P-1));Inside:=Trim(Copy(S,P+1,Length(S)-P-1));
  If Not ParseRegister(Inside,K,R)Or(K<>OK_REG)Or(R=0)Then Begin
   Error('registre d''index invalide');Exit
  End;O.Kind:=OK_INDEX;O.Reg:=R;O.Value:=EvalExpr(Before,Known);ParseOperand:=True;Exit
 End;
 O.Kind:=OK_ADDR;O.Value:=EvalExpr(S,Known);ParseOperand:=True
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
    If S[I]='('Then Inc(Depth)Else If S[I]=')'Then Dec(Depth)
   End
  End;
  If(I>Length(S))Or((S[I]=',')And(Depth=0)And Not Q)Then Begin
   T:=Trim(Copy(S,St,I-St));If T<>''Then Begin
    Inc(Count);If Count=1Then A:=T Else If Count=2Then B:=T Else C:=T
   End;St:=I+1
  End
 End
End;

Function ConditionCode(Const S:String;Var C:Byte):Boolean;
Var
 U:String;
Begin
 U:=Upper(Trim(S));ConditionCode:=True;
 If(U='F')Then C:=0 Else If(U='LT')Then C:=1 Else If(U='LE')Then C:=2 Else If(U='ULE')
 Then C:=3 Else If(U='OV')Or(U='PE')Then C:=4 Else If(U='MI')Then C:=5 Else If(U='Z')Or(U=
 'EQ')Then C:=6 Else If(U='C')Or(U='ULT')Then C:=7 Else If(U='T')Then C:=8 Else If(U='GE')
 Then C:=9 Else If(U='GT')Then C:=10 Else If(U='UGT')Then C:=11 Else If(U='NOV')Or(U='PO')
 Then C:=12 Else If(U='PL')Then C:=13 Else If(U='NZ')Or(U='NE')Then C:=14 Else If(U='NC')
 Or(U='UGE')Then C:=15 Else ConditionCode:=False
End;

Function BinarySubOp(Const Op:String;Var Sub:Byte;Var Size:Byte):Boolean;Begin
 BinarySubOp:=True;Size:=2;
 If Op='ADD'Then Sub:=1 Else If Op='SUB'Then Sub:=3 Else If Op='OR'Then Sub:=5 Else If Op=
 'AND'Then Sub:=7 Else If Op='XOR'Then Sub:=9 Else If Op='CP'Then Sub:=$B
 Else If Op='ADDB'Then Begin
  Sub:=0;Size:=1
 End Else If Op='SUBB'Then Begin
  Sub:=2;Size:=1
 End Else If Op='ORB'Then Begin
  Sub:=4;Size:=1
 End Else If Op='ANDB'Then Begin
  Sub:=6;Size:=1
 End Else If Op='XORB'Then Begin
  Sub:=8;Size:=1
 End Else If Op='CPB'Then Begin
  Sub:=$A;Size:=1
 End
 Else If Op='ADDL'Then Begin
  Sub:=6;Size:=4
 End Else If Op='SUBL'Then Begin
  Sub:=2;Size:=4
 End Else If Op='CPL'Then Begin
  Sub:=0;Size:=4
 End Else BinarySubOp:=False
End;

Procedure AssembleBinary(Const Op:String;Const D,S:TOperand);
Var
 Sub,Size,DK:Byte;
 W:Word;
Begin
 If Not BinarySubOp(Op,Sub,Size)Then Exit;
 If Size=1Then DK:=OK_BREG Else If Size=2Then DK:=OK_REG Else DK:=OK_LREG;
 If D.Kind<>DK Then Begin
  Error('registre destination de taille incorrecte');Exit
 End;
 If S.Kind=DK Then Begin
  If Size=4Then W:=$9000Or(Sub Shl 8)Else W:=$8000Or(Sub Shl 8);
  EmitWord(W Or(S.Reg Shl 4)Or D.Reg)
 End
 Else If S.Kind=OK_IND Then Begin
  If Size=4Then W:=$1000Or(Sub Shl 8)Else W:=Sub Shl 8;EmitWord(W Or(S.Reg Shl 4)Or D.Reg)
 End
 Else If S.Kind=OK_ADDR Then Begin
  If Size=4Then W:=$5000Or(Sub Shl 8)Else W:=$4000Or(Sub Shl 8);EmitWord(W Or D.Reg);
  EmitWord(Word(S.Value))
 End
 Else If S.Kind=OK_INDEX Then Begin
  If Size=4Then W:=$5000Or(Sub Shl 8)Else W:=$4000Or(Sub Shl 8);
  EmitWord(W Or(S.Reg Shl 4)Or D.Reg);EmitWord(Word(S.Value))
 End
 Else If S.Kind=OK_IMM Then Begin
  If Size=4Then W:=$1000Or(Sub Shl 8)Else W:=Sub Shl 8;EmitWord(W Or D.Reg);
  If Size=4Then EmitLong(S.Value)Else EmitWord(Word(S.Value))
 End Else Error('operande source invalide')
End;

Procedure AssembleLoad(Const Op:String;Const D,S:TOperand);
Var
 Size,DK:Byte;
 W:Word;
Begin
 If Op='LDB'Then Begin
  Size:=1;DK:=OK_BREG
 End Else If Op='LDL'Then Begin
  Size:=4;DK:=OK_LREG
 End Else
 Begin
  Size:=2;DK:=OK_REG
 End;
 If(D.Kind=DK)And(S.Kind=DK)Then Begin
  If Size=4Then W:=$9400 Else If Size=1Then W:=$A000 Else W:=$A100;
  EmitWord(W Or(S.Reg Shl 4)Or D.Reg);Exit
 End;
 If(D.Kind=DK)And(S.Kind=OK_IND)Then Begin
  If Size=4Then W:=$1400 Else If Size=1Then W:=$2000 Else W:=$2100;
  EmitWord(W Or(S.Reg Shl 4)Or D.Reg);Exit
 End;
 If(D.Kind=DK)And((S.Kind=OK_ADDR)Or(S.Kind=OK_INDEX))Then Begin
  If Size=4Then W:=$5400 Else If Size=1Then W:=$6000 Else W:=$6100;
  If S.Kind=OK_INDEX Then W:=W Or(S.Reg Shl 4);EmitWord(W Or D.Reg);
  EmitWord(Word(S.Value));Exit
 End;
 If(D.Kind=DK)And(S.Kind=OK_IMM)Then Begin
  If Size=1Then Begin
   If S.Value>=0Then Begin
    EmitWord($C000Or(D.Reg Shl 8)Or(Byte(S.Value)));Exit
   End;W:=$2000
  End Else If Size=4Then W:=$1400 Else W:=$2100;EmitWord(W Or D.Reg);
  If Size=4Then EmitLong(S.Value)Else EmitWord(Word(S.Value));Exit
 End;
 If(D.Kind=OK_IND)And(S.Kind=DK)Then Begin
  If Size=4Then W:=$1D00 Else If Size=1Then W:=$2E00 Else W:=$2F00;
  EmitWord(W Or(D.Reg Shl 4)Or S.Reg);Exit
 End;
 If((D.Kind=OK_ADDR)Or(D.Kind=OK_INDEX))And(S.Kind=DK)Then Begin
  If Size=4Then W:=$5D00 Else If Size=1Then W:=$6E00 Else W:=$6F00;
  If D.Kind=OK_INDEX Then W:=W Or(D.Reg Shl 4);EmitWord(W Or S.Reg);
  EmitWord(Word(D.Value));Exit
 End;
 If((D.Kind=OK_IND)Or(D.Kind=OK_ADDR)Or(D.Kind=OK_INDEX))And(S.Kind=OK_IMM)And(Size<>4)
 Then Begin
  If Size=1Then W:=$0C05 Else W:=$0D05;If D.Kind=OK_IND Then W:=W Or(D.Reg Shl 4)Else
  Begin
   W:=W Or $4000;If D.Kind=OK_INDEX Then W:=W Or(D.Reg Shl 4)
  End;EmitWord(W);If D.Kind<>OK_IND Then EmitWord(Word(D.Value));EmitWord(Word(S.Value));
  Exit
 End;
 Error('forme LD invalide')
End;

Procedure AssembleUnary(Const Op:String;Const D:TOperand);
Var
 ByteOp:Boolean;
 Action:Byte;
 W:Word;
Begin
 ByteOp:=(Op[Length(Op)]='B');
 If(Pos('CLR',Op)=1)Then Action:=8 Else If(Pos('COM',Op)=1)Then Action:=0 Else If(Pos(
 'NEG',Op)=1)Then Action:=2 Else Action:=4;
 If(ByteOp And(D.Kind=OK_BREG))Or((Not ByteOp)And(D.Kind=OK_REG))Then Begin
  If ByteOp Then W:=$8C00 Else W:=$8D00;EmitWord(W Or(D.Reg Shl 4)Or Action)
 End
 Else If D.Kind=OK_IND Then Begin
  If ByteOp Then W:=$0C00 Else W:=$0D00;EmitWord(W Or(D.Reg Shl 4)Or Action)
 End
 Else If(D.Kind=OK_ADDR)Or(D.Kind=OK_INDEX)Then Begin
  If ByteOp Then W:=$4C00 Else W:=$4D00;If D.Kind=OK_INDEX Then W:=W Or(D.Reg Shl 4);
  EmitWord(W Or Action);EmitWord(Word(D.Value))
 End Else Error('operande unaire invalide')
End;

Function IsMnemonic(Const S:String):Boolean;
Const
 N:String=
 ' ADC ADCB ADD ADDB ADDL AND ANDB BIT BITB CALL CALR CLR CLRB COM COMB CP CPB CPL DEC DECB DI DIV DJNZ DBJNZ EI HALT INC INCB IRET JP JR LD LDB LDL LDK MULT NEG NEGB NOP OR ORB POP PUSH RES RESB RET SC SET SETB SUB SUBB SUBL TEST TESTB XOR XORB ';
Begin
 IsMnemonic:=Pos(' '+Upper(S)+' ',N)>0
End;

Function IsDirective(Const S:String):Boolean;
Const
 N:String=' ORG EQU DB BYTE DW WORD DL LONG DS BSS EVEN END ';
Begin
 IsDirective:=Pos(' '+Upper(S)+' ',N)>0
End;

Procedure AssembleInstruction(Op,Args:String);
Var
 A,B,C:String;
 N:Integer;
 D,S:TOperand;
 V,Disp:LongInt;
 K:Boolean;
 CC,Sub,Size:Byte;
 W:Word;
Begin
 Op:=Upper(Op);SplitOperands(Args,A,B,C,N);
 If(Op='NOP')Or(Op='HALT')Or(Op='IRET')Then Begin
  If N<>0Then Error('instruction sans operande');
  If Op='NOP'Then EmitWord($8D07)Else If Op='HALT'Then EmitWord($7A00)Else EmitWord($7B00)
  ;Exit
 End;
 If(Op='DI')Or(Op='EI')Then Begin
  If N=0Then V:=3 Else V:=EvalExpr(A,K);
  If(V<0)Or(V>3)Then Error('masque DI/EI hors plage');
  If Op='DI'Then W:=$7C00 Else W:=$7C04;EmitWord(W Or Word(V));Exit
 End;
 If Op='SC'Then Begin
  If N<>1Then Error('SC exige une valeur');V:=EvalExpr(A,K);EmitWord($7F00Or Byte(V));Exit
 End;
 If BinarySubOp(Op,Sub,Size)Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,D)Or Not ParseOperand(B,S)Then Begin
   Error('operande invalide');Exit
  End;AssembleBinary(Op,D,S);Exit
 End;
 If(Op='ADC')Or(Op='ADCB')Then Begin
  If N<>2Then Begin
   Error('deux registres requis');Exit
  End;If Not ParseOperand(A,D)Or Not ParseOperand(B,S)Then Exit;
  If Op='ADC'Then W:=$B500 Else W:=$B400;EmitWord(W Or(S.Reg Shl 4)Or D.Reg);Exit
 End;
 If(Op='LD')Or(Op='LDB')Or(Op='LDL')Then Begin
  If N<>2Then Begin
   Error('deux operandes requises');Exit
  End;If Not ParseOperand(A,D)Or Not ParseOperand(B,S)Then Begin
   Error('operande invalide');Exit
  End;AssembleLoad(Op,D,S);Exit
 End;
 If(Op='CLR')Or(Op='CLRB')Or(Op='COM')Or(Op='COMB')Or(Op='NEG')Or(Op='NEGB')Or(Op='TEST')
 Or(Op='TESTB')Then Begin
  If(N<>1)Or Not ParseOperand(A,D)Then Begin
   Error('une operande requise');Exit
  End;AssembleUnary(Op,D);Exit
 End;
 If(Op='INC')Or(Op='INCB')Or(Op='DEC')Or(Op='DECB')Then Begin
  If(N<1)Or(N>2)Or Not ParseOperand(A,D)Then Begin
   Error('operande invalide');Exit
  End;If N=2Then V:=EvalExpr(B,K)Else V:=1;
  If(V<1)Or(V>16)Then Error('increment hors plage');Sub:=Byte((V-1)And 15);
  If Pos('INC',Op)=1Then W:=$A900 Else W:=$AB00;If Op[Length(Op)]='B'Then W:=W-$0100;
  If(D.Kind=OK_REG)Or(D.Kind=OK_BREG)Then EmitWord(W Or(D.Reg Shl 4)Or Sub)Else If D.Kind=
  OK_IND Then EmitWord((W-$8000)Or(D.Reg Shl 4)Or Sub)Else
  Begin
   W:=W-$4000;If D.Kind=OK_INDEX Then W:=W Or(D.Reg Shl 4);EmitWord(W Or Sub);
   EmitWord(Word(D.Value))
  End;Exit
 End;
 If(Op='BIT')Or(Op='BITB')Or(Op='RES')Or(Op='RESB')Or(Op='SET')Or(Op='SETB')Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Then Begin
   Error('operande et numero de bit requis');Exit
  End;V:=EvalExpr(B,K);If(V<0)Or(V>15)Then Error('numero de bit hors plage');
  If Pos('BIT',Op)=1Then Sub:=7 Else If Pos('RES',Op)=1Then Sub:=3 Else Sub:=5;
  If Op[Length(Op)]='B'Then Dec(Sub);
  If(D.Kind=OK_REG)Or(D.Kind=OK_BREG)Then EmitWord($A000Or(Sub Shl 8)Or(D.Reg Shl 4)
  Or Byte(V))Else If D.Kind=OK_IND Then EmitWord($2000Or(Sub Shl 8)Or(D.Reg Shl 4)Or Byte(
  V))Else
  Begin
   W:=$6000Or(Sub Shl 8);If D.Kind=OK_INDEX Then W:=W Or(D.Reg Shl 4);
   EmitWord(W Or Byte(V));EmitWord(Word(D.Value))
  End;Exit
 End;
 If(Op='MULT')Or(Op='DIV')Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Or Not ParseOperand(B,S)Or(D.Kind<>OK_LREG)Then Begin
   Error(Op+' RR,source attendu');Exit
  End;If Op='MULT'Then Sub:=9 Else Sub:=$B;
  If S.Kind=OK_REG Then EmitWord($9000Or(Sub Shl 8)Or(S.Reg Shl 4)Or D.Reg)Else If S.Kind=
  OK_IND Then EmitWord($1000Or(Sub Shl 8)Or(S.Reg Shl 4)Or D.Reg)Else If(S.Kind=OK_ADDR)
  Or(S.Kind=OK_INDEX)Then Begin
   W:=$5000Or(Sub Shl 8)Or D.Reg;If S.Kind=OK_INDEX Then W:=W Or(S.Reg Shl 4);EmitWord(W);
   EmitWord(Word(S.Value))
  End Else If S.Kind=OK_IMM Then Begin
   EmitWord($1000Or(Sub Shl 8)Or D.Reg);EmitWord(Word(S.Value))
  End Else Error('source invalide');Exit
 End;
 If Op='PUSH'Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Or(D.Kind<>OK_IND)Or Not ParseOperand(B,S)Then Begin
   Error('PUSH @pile,source attendu');Exit
  End;
  If S.Kind=OK_REG Then EmitWord($9300Or(D.Reg Shl 4)Or S.Reg)Else If S.Kind=
  OK_IND Then EmitWord($1300Or(D.Reg Shl 4)Or S.Reg)Else If S.Kind=OK_IMM Then Begin
   EmitWord($0D09Or(D.Reg Shl 4));EmitWord(Word(S.Value))
  End Else
  Begin
   Error('source PUSH invalide');Exit
  End;Exit
 End;
 If Op='POP'Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Or Not ParseOperand(B,S)Or(S.Kind<>OK_IND)Then Begin
   Error('POP destination,@pile attendu');Exit
  End;
  If D.Kind=OK_REG Then EmitWord($9700Or(S.Reg Shl 4)Or D.Reg)Else If D.Kind=
  OK_IND Then EmitWord($1700Or(S.Reg Shl 4)Or D.Reg)Else Error('destination POP invalide')
  ;Exit
 End;
 If(Op='JP')Or(Op='JR')Then Begin
  If N=1Then Begin
   CC:=8;B:=A
  End Else If(N=2)And ConditionCode(A,CC)Then Begin
  End Else
  Begin
   Error('condition ou cible invalide');Exit
  End;V:=EvalExpr(B,K);
  If Op='JR'Then Begin
   Disp:=(V-(PC+2))Div 2;
   If(Pass=2)And((Disp< -128)Or(Disp>127))Then Error('JR hors limite');
   EmitWord($E000Or(CC Shl 8)Or(Byte(Disp)))
  End Else
  Begin
   EmitWord($5E00Or CC);EmitWord(Word(V))
  End;Exit
 End;
 If Op='CALL'Then Begin
  If N<>1Then Begin
   Error('cible requise');Exit
  End;If Not ParseOperand(A,D)Then Exit;
  If D.Kind=OK_IND Then EmitWord($1F00Or(D.Reg Shl 4))Else
  Begin
   EmitWord($5F00);EmitWord(Word(D.Value))
  End;Exit
 End;
 If Op='CALR'Then Begin
  V:=EvalExpr(A,K);Disp:=(PC+2-V)Div 2;
  If(Pass=2)And((Disp<0)Or(Disp>$FFF))Then Error('CALR hors limite');
  EmitWord($D000Or Word(Disp And $FFF));Exit
 End;
 If Op='RET'Then Begin
  If N=0Then CC:=8 Else If Not ConditionCode(A,CC)Then Begin
   Error('condition invalide');Exit
  End;EmitWord($9E00Or CC);Exit
 End;
 If(Op='DJNZ')Or(Op='DBJNZ')Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Then Begin
   Error('registre et cible requis');Exit
  End;V:=EvalExpr(B,K);Disp:=(PC+2-V)Div 2;
  If(Pass=2)And((Disp<0)Or(Disp>127))Then Error('DJNZ hors limite');
  If Op='DJNZ'Then W:=$F080 Else W:=$F000;EmitWord(W Or(D.Reg Shl 8)Or(Disp And $7F));Exit
 End;
 If Op='LDK'Then Begin
  If(N<>2)Or Not ParseOperand(A,D)Then Begin
   Error('LDK registre,valeur attendu');Exit
  End;V:=EvalExpr(B,K);If(V<0)Or(V>15)Then Error('LDK hors plage');
  EmitWord($BD00Or(D.Reg Shl 4)Or Byte(V));Exit
 End;
 Error('instruction non encore prise en charge: '+Op)
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
 P,I:Integer;
 V:LongInt;
 K:Boolean;
Begin
 S:=Args;Repeat P:=Pos(',',S);If P=0Then Begin
  T:=Trim(S);S:=''
 End Else
 Begin
  T:=Trim(Copy(S,1,P-1));Delete(S,1,P)
 End;If(Size=1)And(Length(T)>=2)And(T[1]='''')And(T[Length(T)]='''')Then
 For I:=2To Length(T)-1Do EmitByte(Ord(T[I]))Else
 Begin
  V:=EvalExpr(T,K);
  If Size=1Then EmitByte(Byte(V))Else If Size=2Then EmitWord(Word(V))Else EmitLong(V)
 End Until S=''
End;

Procedure ProcessLine(Const Original:String);
Var
 Work,First,LabelName,Op,Args:String;
 P,I:Integer;
 V,StartPC:LongInt;
 K:Boolean;
Begin
 LineByteCount:=0;StartPC:=PC;Work:=Original;P:=Pos(';',Work);If P=0Then P:=Pos('!',Work);
 If P>0Then Work:=Copy(Work,1,P-1);Work:=Trim(Work);If Work<>''Then Begin
  First:=FirstToken(Work);LabelName:='';If(Length(Work)>0)And(Work[1]=':')Then Begin
   Delete(Work,1,1);Work:=LTrim(Work);LabelName:=First;First:=FirstToken(Work)
  End Else If Not IsMnemonic(First)And Not IsDirective(First)Then Begin
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
  End Else If(Op='DB')Or(Op='BYTE')Then EmitData(Args,1)Else If(Op='DW')Or(Op='WORD')
  Then EmitData(Args,2)Else If(Op='DL')Or(Op='LONG')Then EmitData(Args,4)
  Else If(Op='DS')Or(Op='BSS')Then Begin
   V:=EvalExpr(Args,K);If V<0Then Error('taille negative')Else
   For I:=1To V Do EmitByte(0)
  End Else If Op='EVEN'Then Begin
   If Odd(PC)Then EmitByte(0)
  End Else If Op='END'Then StopAssembly:=True Else If Op<>''Then AssembleInstruction(Op,
  Args)
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
 WriteLn('ASMZ8000 - Cette commande permet de lancer l''assembleur Zilog Z8000/Z8002.');
 WriteLn;
 WriteLn('Syntaxe: ASMZ8000 source[.ASM] [-B=sortie.BIN] [-L=listing.LIS] [-E]');
 WriteLn;
 WriteLn('  -B=sortie.BIN       Fichier binaire de sortie.');
 WriteLn('  -L=listing.LIS      Fichier de listing.');
 WriteLn('  -E                  Affiche les erreurs.');
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
  Else If Copy(U,1,3)='-L='Then ListName:=Copy(A,4,255)Else If(A='/?')Or(U='-H')Or(U=
  '--HELP')Then Begin
   Usage;Halt
  End Else If SourceName=''Then SourceName:=A Else
  Begin
   Usage;Halt(1)
  End
 End;If SourceName=''Then Begin
  Usage;Halt(1)
 End;If Pos('.',SourceName)=0Then SourceName:=SourceName+'.ASM';
 Base:=BaseName(SourceName);If BinName=''Then BinName:=Base+'.BIN';
 If ListName=''Then ListName:=Base+'.LIS'
End;

BEGIN
 ParseCommandLine;SymbolCount:=0;ErrorCount:=0;Pass:=1;DoPass;Assign(Listing,ListName);
 Rewrite(Listing);If IOResult<>0Then Begin
  WriteLn('Impossible de creer ',ListName);Halt(1)
 End;Assign(Binary,BinName);Rewrite(Binary);If IOResult<>0Then Begin
  WriteLn('Impossible de creer ',BinName);Close(Listing);Halt(1)
 End;Pass:=2;DoPass;WriteLn(Listing);WriteLn(Listing,ErrorCount,' erreur(s)');
 Close(Binary);Close(Listing);If ErrorCount<>0Then Halt(1)
END.
