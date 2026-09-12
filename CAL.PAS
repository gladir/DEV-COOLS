{ CAL - Assembleur Cray-1, sous-ensemble autonome de CAL.
  Compatible syntaxe Turbo Pascal 7 / Free Pascal (-Mtp).
  Sortie: parcels 16 bits big-endian, image absolue, pas un objet COS.
  Reference: Cray Research 2240004 revision C, chapitre 4.
  Voir DOC/CAL.txt pour la syntaxe et les limites. }
Program CAL;
{$I-}
Const MaxSymbols=1024; MaxBytes=60000;
Type TSymbol=Record Name:String[32]; Value:LongInt End;
     TCode=Array[0..MaxBytes-1] of Byte;
Var Symbols:Array[1..MaxSymbols] of TSymbol;
    Code:^TCode;
    Count,Pass,LineNo,Errors,Radix:Integer;
    PC,Size:LongInt;
    Src,Dest,ListName,Raw:String;
    InputFile,Listing:Text;
    OutputFile:File;
    Finished,Known,ListOpen:Boolean;

Function Upper(S:String):String;
Var I:Integer;
Begin For I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S End;

Function Trim(S:String):String;
Begin
  While (Length(S)>0) and (S[1]<=' ') do Delete(S,1,1);
  While (Length(S)>0) and (S[Length(S)]<=' ') do Delete(S,Length(S),1);
  Trim:=S
End;

Function Token(Var S:String):String;
Var I:Integer;
Begin
  S:=Trim(S); I:=1;
  While (I<=Length(S)) and (S[I]>' ') do Inc(I);
  Token:=Copy(S,1,I-1); Delete(S,1,I); S:=Trim(S)
End;

Procedure Error(S:String);
Begin
  WriteLn(Src,'(',LineNo,'): erreur: ',S); Inc(Errors)
End;

Function Find(S:String):Integer;
Var I:Integer;
Begin
  Find:=0;
  For I:=1 to Count do If Symbols[I].Name=S then Begin Find:=I; Exit End
End;

Function ValidName(S:String):Boolean;
Var I:Integer;
Begin
  ValidName:=False;
  If (Length(S)=0) or (Length(S)>32) then Exit;
  If not (S[1] in ['A'..'Z','_','$']) then Exit;
  For I:=2 to Length(S) do
    If not (S[I] in ['A'..'Z','0'..'9','_','$']) then Exit;
  ValidName:=True
End;

Procedure Define(S:String; V:LongInt);
Var I:Integer;
Begin
  If not ValidName(S) then Begin Error('etiquette invalide: '+S); Exit End;
  I:=Find(S);
  If Pass=1 then Begin
    If I<>0 then Error('symbole duplique: '+S)
    Else If Count=MaxSymbols then Error('table des symboles pleine')
    Else Begin Inc(Count); Symbols[Count].Name:=S; Symbols[Count].Value:=V End
  End Else If I<>0 then
    If Symbols[I].Value<>V then Error('valeur instable: '+S)
End;

{ Expressions signees, termes nombres/symboles/*, operateurs + et -.
  Calcul en real pour detecter les debordements avant conversion LongInt. }
Function Expr(S:String):LongInt;
Var P,Q,B,D,I,Sign:Integer; T:String; N,Total:Real;
Begin
  Expr:=0; S:=Trim(S); P:=1; Total:=0; Known:=True;
  If S='' then Begin Error('expression manquante'); Exit End;
  While P<=Length(S) do Begin
    Sign:=1;
    If S[P]='-' then Begin Sign:=-1; Inc(P) End
    Else If S[P]='+' then Inc(P);
    Q:=P;
    While (P<=Length(S)) and not (S[P] in ['+','-']) do Inc(P);
    T:=Trim(Copy(S,Q,P-Q)); N:=0;
    If T='' then Begin Error('expression invalide'); Exit End;
    If T='*' then N:=PC
    Else If T[1] in ['0'..'9'] then Begin
      B:=Radix; I:=1;
      If Copy(T,1,2)='0X' then Begin B:=16; I:=3 End
      Else If Copy(T,1,2)='0O' then Begin B:=8; I:=3 End
      Else If Copy(T,1,2)='0D' then Begin B:=10; I:=3 End;
      If I>Length(T) then Begin Error('nombre vide'); Exit End;
      While I<=Length(T) do Begin
        D:=Ord(T[I])-Ord('0');
        If T[I] in ['A'..'F'] then D:=Ord(T[I])-Ord('A')+10;
        If (D<0) or (D>=B) then Begin Error('chiffre invalide: '+T); Exit End;
        N:=N*B+D;
        If N>2147483648.0 then Begin Error('nombre hors limites'); Exit End;
        Inc(I)
      End
    End Else Begin
      I:=Find(T);
      If I=0 then Begin
        Known:=False;
        If Pass=2 then Error('symbole inconnu: '+T)
      End Else N:=Symbols[I].Value
    End;
    Total:=Total+Sign*N;
    If (Total>2147483647.0) or (Total< -2147483648.0) then Begin
      Error('expression hors limites'); Exit
    End
  End;
  Expr:=Trunc(Total)
End;

Procedure Emit(V:LongInt);
Begin
  If (PC<0) or (PC>=MaxBytes div 2) then Begin
    Error('image trop grande (60000 octets)'); Exit
  End;
  If Pass=2 then Begin
    Code^[PC*2]:=(V shr 8) and 255; Code^[PC*2+1]:=V and 255
  End;
  Inc(PC); If PC*2>Size then Size:=PC*2
End;

Procedure Ins(Op,I,J,K:Integer);
Begin Emit(LongInt(Op)*512+I*64+J*8+K) End;

Function Reg(S:String; C:Char):Integer;
Begin
  Reg:=-1;
  If Length(S)=2 then
    If (S[1]=C) and (S[2] in ['0'..'7']) then Reg:=Ord(S[2])-48
End;

Procedure LongIns(Op,I:Integer; S:String; Limit:LongInt);
Var V:LongInt;
Begin
  V:=Expr(S);
  If (V<0) and ((Op=16) or (Op=32)) then Begin
    Inc(Op); V:=-(V+1)
  End;
  If (V<0) or (V>Limit) then Error('operande hors limites');
  Emit(LongInt(Op)*512+I*64+(V shr 16)); Emit(V)
End;

Procedure Machine(R,O:String);
Var I,J,K,Op,P:Integer; C:Char; L,T,Oper:String;
Begin
  If (R='ERR') or (R='EX') or (R='PASS') then Begin
    If O<>'' then Error('operande superflu');
    If R='ERR' then Emit(0) Else If R='EX' then Ins(4,0,0,0)
    Else Ins(1,0,0,0);
    Exit
  End;
  Op:=-1;
  If R='J' then Op:=6 Else If R='R' then Op:=7
  Else If R='JAZ' then Op:=8 Else If R='JAN' then Op:=9
  Else If R='JAP' then Op:=10 Else If R='JAM' then Op:=11
  Else If R='JSZ' then Op:=12 Else If R='JSN' then Op:=13
  Else If R='JSP' then Op:=14 Else If R='JSM' then Op:=15;
  If Op>=0 then Begin
    If (R='J') and (Length(O)=3) and (O[1]='B') and
       (O[2] in ['0'..'7']) and (O[3] in ['0'..'7']) then
      Ins(5,0,Ord(O[2])-48,Ord(O[3])-48)
    Else LongIns(Op,0,O,16777215);
    Exit
  End;
  If R='VL' then Begin
    K:=Reg(O,'A'); If K<0 then Error('registre A attendu') Else Ins(2,0,0,K);
    Exit
  End;
  If R='VM' then Begin
    J:=Reg(O,'S'); If J<0 then Error('registre S attendu') Else Ins(3,0,J,0);
    Exit
  End;
  If R='' then Begin Error('instruction manquante'); Exit End;
  C:=R[1]; I:=Reg(R,C);
  If (I<0) or not (C in ['A','S','V']) then Begin
    Error('instruction non prise en charge: '+R); Exit
  End;
  If (C='S') and ((O='RTC') or (O='VM')) then Begin
    If O='RTC' then Ins(58,I,0,0) Else Ins(59,I,0,0); Exit
  End;
  J:=Reg(O,'S');
  If (C='A') and (J>=0) then Begin Ins(19,I,J,0); Exit End;
  K:=Reg(O,'A');
  If (C='S') and (K>=0) then Begin Ins(57,I,0,K); Exit End;
  K:=Reg(O,C);
  If (K>=0) and (C in ['A','S']) then Begin
    If C='A' then Ins(24,I,0,K) Else Ins(48,I,0,K); Exit
  End;
  { Binary register expressions: Aj+Ak, Sj+FSk, Vj&Vk, etc. }
  If Length(O)>=5 then Begin
    L:=Copy(O,1,2); Oper:=Copy(O,3,1); P:=4;
    If (Length(O)>=6) and (O[4]='F') then Begin Oper:=Oper+'F'; P:=5 End;
    T:=Copy(O,P,255); J:=Reg(L,C); K:=Reg(T,C); Op:=-1;
    If (J>=0) and (K>=0) then Begin
      If C='A' then Begin
        If Oper='+' then Op:=24 Else If Oper='-' then Op:=25
        Else If Oper='*' then Op:=26
      End Else If C='S' then Begin
        If Oper='+' then Op:=48 Else If Oper='-' then Op:=49
        Else If Oper='+F' then Op:=50 Else If Oper='-F' then Op:=51
        Else If Oper='*F' then Op:=52 Else If Oper='&' then Op:=36
        Else If Oper='!' then Op:=41 Else If Oper='\' then Op:=38
      End Else Begin
        If Oper='+' then Op:=109 Else If Oper='-' then Op:=111
        Else If Oper='&' then Op:=97 Else If Oper='!' then Op:=99
        Else If Oper='\' then Op:=101
        Else If Oper='+F' then Op:=121 Else If Oper='-F' then Op:=123
      End;
      If Op>=0 then Begin Ins(Op,I,J,K); Exit End
    End
  End;
  { Constants always use two parcels: stable forward-reference sizes. }
  If (C in ['A','S']) and (Length(O)>0) then Begin
    If (O[1] in ['0'..'9','+','-','*']) or
       (ValidName(O) and (Reg(O,'A')<0) and (Reg(O,'S')<0) and (Reg(O,'V')<0)) then Begin
      If C='A' then Op:=16 Else Op:=32;
      LongIns(Op,I,O,4194303); Exit
    End
  End;
  Error('forme non prise en charge: '+R+' '+O)
End;

Procedure ParseLine;
Var S,LabelName,R,O,T:String; P,I:Integer; V,Start:LongInt;
Begin
  S:=Upper(Raw); Start:=PC;
  If S='' then Exit;
  If S[1]='*' then Exit;
  P:=Pos(';',S); If P>0 then Delete(S,P,255);
  If Trim(S)='' then Exit;
  LabelName:='';
  If S[1]>' ' then Begin
    LabelName:=Token(S);
    If LabelName[Length(LabelName)]=':' then Delete(LabelName,Length(LabelName),1)
  End;
  R:=Token(S); O:=Trim(S);
  { Ignore trailing CAL comment field, separated by whitespace. }
  O:=Token(O);
  If R='EQU' then Begin
    V:=Expr(O);
    If (Pass=1) and not Known then Error('EQU exige des symboles deja definis');
    Define(LabelName,V); Exit
  End;
  If LabelName<>'' then Define(LabelName,PC);
  If R='' then Exit;
  If R='END' then Finished:=True
  Else If (R='IDENT') or (R='TITLE') then Begin End
  Else If R='BASE' then Begin
    If O='D' then Radix:=10 Else If O='O' then Radix:=8
    Else If O='H' then Radix:=16 Else Error('BASE attend D, O ou H')
  End Else If R='ORG' then Begin
    V:=Expr(O);
    If not Known then Error('ORG exige une valeur connue');
    If (V<PC) or (V>=MaxBytes div 2) then Error('ORG hors limites ou en arriere')
    Else Begin PC:=V; If PC*2>Size then Size:=PC*2 End
  End Else If R='BSS' then Begin
    V:=Expr(O);
    If not Known then Error('BSS exige une valeur connue');
    If (V<0) or (V>(MaxBytes div 2-PC) div 4) then Error('BSS hors limites')
    Else While V>0 do Begin For I:=1 to 4 do Emit(0); Dec(V) End
  End Else If (R='CON') or (R='PARCEL') then Begin
    Repeat
      P:=Pos(',',O); If P=0 then P:=Length(O)+1;
      T:=Copy(O,1,P-1); Delete(O,1,P); V:=Expr(T);
      If R='CON' then Begin
        If V<0 then Begin Emit(65535); Emit(65535) End
        Else Begin Emit(0); Emit(0) End;
        Emit(V shr 16); Emit(V)
      End Else Begin
        If (V<0) or (V>65535) then Error('PARCEL hors limites'); Emit(V)
      End
    Until O=''
  End Else Machine(R,O);
  If (Pass=2) and ListOpen then Begin
    Write(Listing,LineNo:5,' ',Start:7,' ');
    For I:=0 to Integer(PC-Start)-1 do
      If I<4 then Write(Listing,LongInt(Code^[(Start+I)*2])*256+Code^[(Start+I)*2+1]:6,' ');
    WriteLn(Listing,'  ',Raw)
  End
End;

Procedure Help;
Begin
  WriteLn('CAL - Assembleur Cray-1 (sous-ensemble)');
  WriteLn('Usage: CAL source [-o sortie.bin] [-l listing.lst]');
  WriteLn('Source: [etiquette] resultat operande ; commentaire');
  WriteLn('Sans etiquette, commencer la ligne par une espace.');
  WriteLn('Directives: IDENT TITLE BASE EQU ORG CON PARCEL BSS END');
  WriteLn('Image absolue big-endian; adresses en parcels; defaut decimal.');
  WriteLn('Limites et exemples: DOC/CAL.txt')
End;

Var Arg:String; N,Io:Integer; Written:Word;
Begin
  Count:=0; Errors:=0; LineNo:=0; Src:=''; Dest:=''; ListName:=''; ListOpen:=False;
  N:=1;
  While N<=ParamCount do Begin
    Arg:=ParamStr(N);
    If (Arg='--help') or (Arg='-h') or (Arg='/?') then Begin Help; Halt(0) End
    Else If (Arg='-o') or (Arg='-l') then Begin
      Inc(N); If N>ParamCount then Begin WriteLn('Option incomplete: ',Arg); Halt(1) End;
      If Arg='-o' then Dest:=ParamStr(N) Else ListName:=ParamStr(N)
    End Else If (Copy(Arg,1,1)='-') or (Src<>'') then Begin
      WriteLn('Argument invalide: ',Arg); Halt(1)
    End Else Src:=Arg;
    Inc(N)
  End;
  If Src='' then Begin Help; Halt(1) End;
  {$IFNDEF FPC}
  If MaxAvail<SizeOf(TCode) then Begin WriteLn('Memoire insuffisante'); Halt(1) End;
  {$ENDIF}
  New(Code);
  If Dest='' then Dest:=Src+'.bin';
  { Refuse all existing output paths: also protects aliases of the source. }
  Assign(OutputFile,Dest); Reset(OutputFile,1); Io:=IOResult;
  If Io=0 then Begin Close(OutputFile); WriteLn('Sortie deja existante: ',Dest); Halt(1) End;
  If ListName<>'' then Begin
    If Upper(ListName)=Upper(Dest) then Begin WriteLn('Sorties identiques'); Halt(1) End;
    Assign(OutputFile,ListName); Reset(OutputFile,1); Io:=IOResult;
    If Io=0 then Begin Close(OutputFile); WriteLn('Listing deja existant'); Halt(1) End
  End;
  For Pass:=1 to 2 do Begin
    PC:=0; Size:=0; Radix:=10; LineNo:=0; Finished:=False;
    FillChar(Code^,SizeOf(TCode),0);
    Assign(InputFile,Src); Reset(InputFile);
    If IOResult<>0 then Begin WriteLn('Lecture impossible: ',Src); Halt(1) End;
    If (Pass=2) and (ListName<>'') then Begin
      Assign(Listing,ListName); Rewrite(Listing);
      If IOResult<>0 then Begin WriteLn('Creation listing impossible'); Halt(1) End;
      ListOpen:=True
    End;
    While not Eof(InputFile) and not Finished do Begin
      ReadLn(InputFile,Raw);
      If IOResult<>0 then Begin Error('lecture impossible'); Break End;
      Inc(LineNo); ParseLine
    End;
    Close(InputFile); Io:=IOResult;
    If ListOpen then Begin
      Close(Listing); If IOResult<>0 then Error('ecriture listing impossible'); ListOpen:=False
    End;
    If Errors<>0 then Begin WriteLn(Errors,' erreur(s), binaire non genere.'); Halt(1) End
  End;
  Assign(OutputFile,Dest); Rewrite(OutputFile,1);
  If IOResult<>0 then Begin WriteLn('Creation impossible: ',Dest); Halt(1) End;
  BlockWrite(OutputFile,Code^,Word(Size),Written); Io:=IOResult;
  Close(OutputFile);
  If (IOResult<>0) or (Io<>0) or (Written<>Size) then Begin WriteLn('Ecriture impossible'); Halt(1) End;
  WriteLn('CAL: ',Size,' octets, ',Count,' symboles -> ',Dest)
End.
