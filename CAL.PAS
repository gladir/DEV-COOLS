Program CAL;
{ CAL - Assembleur Cray-1, sous-ensemble autonome de CAL.
  Compatible syntaxe Turbo Pascal 7 / Free Pascal (-Mtp).
  Sortie: parcels 16 bits big-endian, image absolue, pas un objet COS.
  Reference: Cray Research 2240004 revision C, chapitre 4.
  Voir DOC/CAL.txt pour la syntaxe et les limites. }
{$I-}
Const
 MaxSymbols=1024;
 MaxBytes=60000;
Type
 TSymbol=Record Name:String[32];
 Value:LongInt
End;
TCode=Array[0..MaxBytes-1] of Byte;
Var
 Symbols:Array[1..MaxSymbols] of TSymbol;
 Code:^TCode;
 Count,Pass,LineNo,Errors,Radix:Integer;
 PC,Size:LongInt;
 Src,Dest,ListName,Raw:String;
 InputFile,Listing:Text;
 OutputFile:File;
 Finished,Known,ListOpen:Boolean;

Function Upper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S
End;

Function Trim(S:String):String;Begin
 While (Length(S)>0) and (S[1]<=' ') do Delete(S,1,1);
 While (Length(S)>0) and (S[Length(S)]<=' ') do Delete(S,Length(S),1);
 Trim:=S
End;

Function Token(Var S:String):String;
Var
 I:Integer;
Begin
 S:=Trim(S); I:=1;
 While (I<=Length(S)) and (S[I]>' ') do Inc(I);
 Token:=Copy(S,1,I-1); Delete(S,1,I); S:=Trim(S)
End;

Procedure Error(S:String);Begin
 WriteLn(Src,'(',LineNo,'): erreur: ',S); Inc(Errors)
End;

Function Find(S:String):Integer;
Var
 I:Integer;
Begin
 Find:=0;
 For I:=1 to Count do If Symbols[I].Name=S Then Begin
  Find:=I; Exit
 End
End;

Function ValidName(S:String):Boolean;
Var
 I:Integer;
Begin
 ValidName:=False;
 If (Length(S)=0) or (Length(S)>32) Then Exit;
 If not (S[1] in ['A'..'Z','_','$']) Then Exit;
 For I:=2 to Length(S) do    If not (S[I] in ['A'..'Z','0'..'9','_','$']) Then Exit;
 ValidName:=True
End;

Procedure Define(S:String; V:LongInt);
Var
 I:Integer;
Begin
 If not ValidName(S) Then Begin
  Error('etiquette invalide: '+S); Exit
 End;
 I:=Find(S);
 If Pass=1 Then Begin
  If I<>0 Then Error('symbole duplique: '+S)
  Else If Count=MaxSymbols Then Error('table des symboles pleine')
  Else
  Begin
   Inc(Count); Symbols[Count].Name:=S; Symbols[Count].Value:=V
  End
 End Else If I<>0 Then    If Symbols[I].Value<>V Then Error('valeur instable: '+S)
End;
{ Expressions signees, termes nombres/symboles/*, operateurs + et -.
  Calcul en real pour detecter les debordements avant conversion LongInt. }

Function Expr(S:String):LongInt;
Var
 P,Q,B,D,I,Sign:Integer;
 T:String;
 N,Total:Real;
Begin
 Expr:=0; S:=Trim(S); P:=1; Total:=0; Known:=True;
 If S='' Then Begin
  Error('expression manquante'); Exit
 End;
 While P<=Length(S) do Begin
  Sign:=1;
  If S[P]='-' Then Begin
   Sign:=-1; Inc(P)
  End
  Else If S[P]='+' Then Inc(P);
  Q:=P;
  While (P<=Length(S)) and not (S[P] in ['+','-']) do Inc(P);
  T:=Trim(Copy(S,Q,P-Q)); N:=0;
  If T='' Then Begin
   Error('expression invalide'); Exit
  End;
  If T='*' Then N:=PC
  Else If T[1] in ['0'..'9'] Then Begin
   B:=Radix; I:=1;
   If Copy(T,1,2)='0X' Then Begin
    B:=16; I:=3
   End
   Else If Copy(T,1,2)='0O' Then Begin
    B:=8; I:=3
   End
   Else If Copy(T,1,2)='0D' Then Begin
    B:=10; I:=3
   End;
   If I>Length(T) Then Begin
    Error('nombre vide'); Exit
   End;
   While I<=Length(T) do Begin
    D:=Ord(T[I])-Ord('0');
    If T[I] in ['A'..'F'] Then D:=Ord(T[I])-Ord('A')+10;
    If (D<0) or (D>=B) Then Begin
     Error('chiffre invalide: '+T); Exit
    End;
    N:=N*B+D;
    If N>2147483648.0 Then Begin
     Error('nombre hors limites'); Exit
    End;
    Inc(I)
   End
  End Else
  Begin
   I:=Find(T);
   If I=0 Then Begin
    Known:=False;
    If Pass=2 Then Error('symbole inconnu: '+T)
   End Else N:=Symbols[I].Value
  End;
  Total:=Total+Sign*N;
  If (Total>2147483647.0) or (Total< -2147483648.0) Then Begin
   Error('expression hors limites'); Exit
  End
 End;
 Expr:=Trunc(Total)
End;

Procedure Emit(V:LongInt);Begin
 If (PC<0) or (PC>=MaxBytes div 2) Then Begin
  Error('image trop grande (60000 octets)'); Exit
 End;
 If Pass=2 Then Begin
  Code^[PC*2]:=(V shr 8) and 255; Code^[PC*2+1]:=V and 255
 End;
 Inc(PC); If PC*2>Size Then Size:=PC*2
End;

Procedure Ins(Op,I,J,K:Integer);Begin
 Emit(LongInt(Op)*512+I*64+J*8+K)
End;

Function Reg(S:String; C:Char):Integer;Begin
 Reg:=-1;
 If Length(S)=2 Then    If (S[1]=C) and (S[2] in ['0'..'7']) Then Reg:=Ord(S[2])-48
End;

Procedure LongIns(Op,I:Integer; S:String; Limit:LongInt);
Var
 V:LongInt;
Begin
 V:=Expr(S);
 If (V<0) and ((Op=16) or (Op=32)) Then Begin
  Inc(Op); V:=-(V+1)
 End;
 If (V<0) or (V>Limit) Then Error('operande hors limites');
 Emit(LongInt(Op)*512+I*64+(V shr 16)); Emit(V)
End;

Procedure Machine(R,O:String);
Var
 I,J,K,Op,P:Integer;
 C:Char;
 L,T,Oper:String;
Begin
 If (R='ERR') or (R='EX') or (R='PASS') Then Begin
  If O<>'' Then Error('operande superflu');
  If R='ERR' Then Emit(0) Else If R='EX' Then Ins(4,0,0,0)
  Else Ins(1,0,0,0);
  Exit
 End;
 Op:=-1;
 If R='J' Then Op:=6 Else If R='R' Then Op:=7
 Else If R='JAZ' Then Op:=8 Else If R='JAN' Then Op:=9
 Else If R='JAP' Then Op:=10 Else If R='JAM' Then Op:=11
 Else If R='JSZ' Then Op:=12 Else If R='JSN' Then Op:=13
 Else If R='JSP' Then Op:=14 Else If R='JSM' Then Op:=15;
 If Op>=0 Then Begin
  If (R='J') and (Length(O)=3) and (O[1]='B') and
  (O[2] in ['0'..'7']) and (O[3] in ['0'..'7']) Then      Ins(5,0,Ord(O[2])-48,Ord(O[3])-
  48)
  Else LongIns(Op,0,O,16777215);
  Exit
 End;
 If R='VL' Then Begin
  K:=Reg(O,'A'); If K<0 Then Error('registre A attendu') Else Ins(2,0,0,K);
  Exit
 End;
 If R='VM' Then Begin
  J:=Reg(O,'S'); If J<0 Then Error('registre S attendu') Else Ins(3,0,J,0);
  Exit
 End;
 If R='' Then Begin
  Error('instruction manquante'); Exit
 End;
 C:=R[1]; I:=Reg(R,C);
 If (I<0) or not (C in ['A','S','V']) Then Begin
  Error('instruction non prise en charge: '+R); Exit
 End;
 If (C='S') and ((O='RTC') or (O='VM')) Then Begin
  If O='RTC' Then Ins(58,I,0,0) Else Ins(59,I,0,0); Exit
 End;
 J:=Reg(O,'S');
 If (C='A') and (J>=0) Then Begin
  Ins(19,I,J,0); Exit
 End;
 K:=Reg(O,'A');
 If (C='S') and (K>=0) Then Begin
  Ins(57,I,0,K); Exit
 End;
 K:=Reg(O,C);
 If (K>=0) and (C in ['A','S']) Then Begin
  If C='A' Then Ins(24,I,0,K) Else Ins(48,I,0,K); Exit
 End;
  { Binary register expressions: Aj+Ak, Sj+FSk, Vj&Vk, etc. }
 If Length(O)>=5 Then Begin
  L:=Copy(O,1,2); Oper:=Copy(O,3,1); P:=4;
  If (Length(O)>=6) and (O[4]='F') Then Begin
   Oper:=Oper+'F'; P:=5
  End;
  T:=Copy(O,P,255); J:=Reg(L,C); K:=Reg(T,C); Op:=-1;
  If (J>=0) and (K>=0) Then Begin
   If C='A' Then Begin
    If Oper='+' Then Op:=24 Else If Oper='-' Then Op:=25
    Else If Oper='*' Then Op:=26
   End Else If C='S' Then Begin
    If Oper='+' Then Op:=48 Else If Oper='-' Then Op:=49
    Else If Oper='+F' Then Op:=50 Else If Oper='-F' Then Op:=51
    Else If Oper='*F' Then Op:=52 Else If Oper='&' Then Op:=36
    Else If Oper='!' Then Op:=41 Else If Oper='\' Then Op:=38
   End Else
   Begin
    If Oper='+' Then Op:=109 Else If Oper='-' Then Op:=111
    Else If Oper='&' Then Op:=97 Else If Oper='!' Then Op:=99
    Else If Oper='\' Then Op:=101
    Else If Oper='+F' Then Op:=121 Else If Oper='-F' Then Op:=123
   End;
   If Op>=0 Then Begin
    Ins(Op,I,J,K); Exit
   End
  End
 End;
  { Constants always use two parcels: stable forward-reference sizes. }
 If (C in ['A','S']) and (Length(O)>0) Then Begin
  If (O[1] in ['0'..'9','+','-','*']) or
  (ValidName(O) and (Reg(O,'A')<0) and (Reg(O,'S')<0) and (Reg(O,'V')<0)) Then Begin
   If C='A' Then Op:=16 Else Op:=32;
   LongIns(Op,I,O,4194303); Exit
  End
 End;
 Error('forme non prise en charge: '+R+' '+O)
End;

Procedure ParseLine;
Var
 S,LabelName,R,O,T:String;
 P,I:Integer;
 V,Start:LongInt;
Begin
 S:=Upper(Raw); Start:=PC;
 If S='' Then Exit;
 If S[1]='*' Then Exit;
 P:=Pos(';',S); If P>0 Then Delete(S,P,255);
 If Trim(S)='' Then Exit;
 LabelName:='';
 If S[1]>' ' Then Begin
  LabelName:=Token(S);
  If LabelName[Length(LabelName)]=':' Then Delete(LabelName,Length(LabelName),1)
 End;
 R:=Token(S); O:=Trim(S);
  { Ignore trailing CAL comment field, separated by whitespace. }
 O:=Token(O);
 If R='EQU' Then Begin
  V:=Expr(O);
  If (Pass=1) and not Known Then Error('EQU exige des symboles deja definis');
  Define(LabelName,V); Exit
 End;
 If LabelName<>'' Then Define(LabelName,PC);
 If R='' Then Exit;
 If R='END' Then Finished:=True
 Else If (R='IDENT') or (R='TITLE') Then Begin
 End
 Else If R='BASE' Then Begin
  If O='D' Then Radix:=10 Else If O='O' Then Radix:=8
  Else If O='H' Then Radix:=16 Else Error('BASE attend D, O ou H')
 End Else If R='ORG' Then Begin
  V:=Expr(O);
  If not Known Then Error('ORG exige une valeur connue');
  If (V<PC) or (V>=MaxBytes div 2) Then Error('ORG hors limites ou en arriere')
  Else
  Begin
   PC:=V; If PC*2>Size Then Size:=PC*2
  End
 End Else If R='BSS' Then Begin
  V:=Expr(O);
  If not Known Then Error('BSS exige une valeur connue');
  If (V<0) or (V>(MaxBytes div 2-PC) div 4) Then Error('BSS hors limites')
  Else
  While V>0 do Begin
   For I:=1 to 4 do Emit(0); Dec(V)
  End
 End Else If (R='CON') or (R='PARCEL') Then Begin
  Repeat
  P:=Pos(',',O); If P=0 Then P:=Length(O)+1;
  T:=Copy(O,1,P-1); Delete(O,1,P); V:=Expr(T);
  If R='CON' Then Begin
   If V<0 Then Begin
    Emit(65535); Emit(65535)
   End
   Else
   Begin
    Emit(0); Emit(0)
   End;
   Emit(V shr 16); Emit(V)
  End Else
  Begin
   If (V<0) or (V>65535) Then Error('PARCEL hors limites'); Emit(V)
  End
  Until O=''
 End Else Machine(R,O);
 If (Pass=2) and ListOpen Then Begin
  Write(Listing,LineNo:5,' ',Start:7,' ');
  For I:=0 to Integer(PC-Start)-1 do      If I<4 Then Write(Listing,LongInt(Code^[(Start+
  I)*2])*256+Code^[(Start+I)*2+1]:6,' ');
  WriteLn(Listing,'  ',Raw)
 End
End;

Procedure Help;Begin
 WriteLn('CAL - Cette commande permet de lancer l''assembleur ',
         'Cray-1 (sous-ensemble).');
 WriteLn;
 WriteLn('Syntaxe: CAL source [-o sortie.bin] [-l listing.lst]');
 WriteLn;
 WriteLn('Source: [etiquette] resultat operande ; commentaire');
 WriteLn;
 WriteLn('Sans etiquette, commencer la ligne par une espace.');
 WriteLn('Directives: IDENT TITLE BASE EQU ORG CON PARCEL BSS END');
 WriteLn('Image absolue big-endian; adresses en parcels; defaut decimal.');
 WriteLn('Limites et exemples: DOC/CAL.txt')
End;
Var
 Arg:String;
 N,Io:Integer;
 Written:Word;

BEGIN
 Count:=0; Errors:=0; LineNo:=0; Src:=''; Dest:=''; ListName:=''; ListOpen:=False;
 N:=1;
 While N<=ParamCount do Begin
  Arg:=ParamStr(N);
  If (Arg='--help') or (Arg='-h') or (Arg='/?') Then Begin
   Help; Halt(0)
  End
  Else If (Arg='-o') or (Arg='-l') Then Begin
   Inc(N); If N>ParamCount Then Begin
    WriteLn('Option incomplete: ',Arg); Halt(1)
   End;
   If Arg='-o' Then Dest:=ParamStr(N) Else ListName:=ParamStr(N)
  End Else If (Copy(Arg,1,1)='-') or (Src<>'') Then Begin
   WriteLn('Argument invalide: ',Arg); Halt(1)
  End Else Src:=Arg;
  Inc(N)
 End;
 If Src='' Then Begin
  Help; Halt(1)
 End;
 {$IFNDEF FPC}
  If MaxAvail<SizeOf(TCode) Then Begin
   WriteLn('Memoire insuffisante'); Halt(1)
  End;
 {$ENDIF}
 New(Code);
 If Dest='' Then Dest:=Src+'.bin';
  { Refuse all existing output paths: also protects aliases of the source. }
 Assign(OutputFile,Dest); Reset(OutputFile,1); Io:=IOResult;
 If Io=0 Then Begin
  Close(OutputFile); WriteLn('Sortie deja existante: ',Dest); Halt(1)
 End;
 If ListName<>'' Then Begin
  If Upper(ListName)=Upper(Dest) Then Begin
   WriteLn('Sorties identiques'); Halt(1)
  End;
  Assign(OutputFile,ListName); Reset(OutputFile,1); Io:=IOResult;
  If Io=0 Then Begin
   Close(OutputFile); WriteLn('Listing deja existant'); Halt(1)
  End
 End;
 For Pass:=1 to 2 do Begin
  PC:=0; Size:=0; Radix:=10; LineNo:=0; Finished:=False;
  FillChar(Code^,SizeOf(TCode),0);
  Assign(InputFile,Src); Reset(InputFile);
  If IOResult<>0 Then Begin
   WriteLn('Lecture impossible: ',Src); Halt(1)
  End;
  If (Pass=2) and (ListName<>'') Then Begin
   Assign(Listing,ListName); Rewrite(Listing);
   If IOResult<>0 Then Begin
    WriteLn('Creation listing impossible'); Halt(1)
   End;
   ListOpen:=True
  End;
  While not Eof(InputFile) and not Finished do Begin
   ReadLn(InputFile,Raw);
   If IOResult<>0 Then Begin
    Error('lecture impossible'); Break
   End;
   Inc(LineNo); ParseLine
  End;
  Close(InputFile); Io:=IOResult;
  If ListOpen Then Begin
   Close(Listing); If IOResult<>0 Then Error('ecriture listing impossible');
   ListOpen:=False
  End;
  If Errors<>0 Then Begin
   WriteLn(Errors,' erreur(s), binaire non genere.'); Halt(1)
  End
 End;
 Assign(OutputFile,Dest); Rewrite(OutputFile,1);
 If IOResult<>0 Then Begin
  WriteLn('Creation impossible: ',Dest); Halt(1)
 End;
 BlockWrite(OutputFile,Code^,Word(Size),Written); Io:=IOResult;
 Close(OutputFile);
 If (IOResult<>0) or (Io<>0) or (Written<>Size) Then Begin
  WriteLn('Ecriture impossible'); Halt(1)
 End;
 WriteLn('CAL: ',Size,' octets, ',Count,' symboles -> ',Dest)
END.
