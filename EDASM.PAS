{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
 @description: Clone en ligne de commande de l'Apple 6502 EDASM. }

Program EDASM;

{$IFDEF FPC}
 {$MODE TP}{$H-}
{$ENDIF}
{$I-}{$R-}

Uses DOS;

Const
 VERSION='1.1';
 MAX_SYMBOLS=4096;
 MAX_LINE=255;
 MAX_RELOCS=8192;
 AM_IMP=0;
 AM_ACC=1;
 AM_IMM=2;
 AM_ZP=3;
 AM_ZPX=4;
 AM_ZPY=5;
 AM_ABS=6;
 AM_ABX=7;
 AM_ABY=8;
 AM_IND=9;
 AM_INX=10;
 AM_INY=11;
 AM_REL=12;

Type
 TString=String;
 TSymbol=Record
  Name:String[31];
  Value:LongInt;
  Defined,External,PublicSym,Relocatable:Boolean;
 End;
 TReloc=Record
  Offset:LongInt;
  Kind:Byte;
  SymbolName:String[31];
 End;

Var
 Obj:File;
 ListText:Text;
 SrcName,ObjName,ListName:TString;
 Symbols:Array[0..MAX_SYMBOLS-1] Of TSymbol;
 SymbolCount:Integer;
 Relocs:Array[0..MAX_RELOCS-1] Of TReloc;
 RelocCount:Integer;
 Pass,LineNo,Errors:Integer;
 PC,ObjPC,FirstPC,LastPC:LongInt;
 ListingEnabled,UseListing,MSBMode,EndSeen,Quiet:Boolean;
 CondStack:Array[0..15] Of Boolean;
 CondDepth:Integer;
 Active:Boolean;
 RelMode,InDsect:Boolean;
 SavedPC:LongInt;
 CurrentSource,ChainName,Subtitle:TString;
 ChainRequested:Boolean;
 ListPage,ListRow,PageLength:Integer;

Function Up(S:TString):TString;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]); Up:=S;
End;

Function Trim(S:TString):TString;
Var
 A,B:Integer;
Begin
 A:=1;
 While (A<=Length(S)) And (S[A] In [' ',#9]) Do Inc(A); B:=Length(S);
 While (B>=A) And (S[B] In [' ',#9]) Do Dec(B); Trim:=Copy(S,A,B-A+1);
End;

Function Hex(V:LongInt; N:Byte):TString;
Const
 D:Array[1..16] Of Char='0123456789ABCDEF';
Var
 S:TString;
 I:Byte;
Begin
 S:='';
 For I:=1 To N Do Begin
  S:=D[(V And 15)+1]+S; V:=V Shr 4;
 End; Hex:=S;
End;

Function BaseName(S:TString):TString;
Var
 I,P:Integer;
Begin
 P:=0;
 For I:=1 To Length(S) Do If S[I]='.' Then P:=I; If P>0 Then Delete(S,P,255); BaseName:=S;
End;

Procedure Error(S:TString);Begin
 Inc(Errors); If Pass=2 Then Begin
  WriteLn('EDASM: ',CurrentSource,', ligne ',LineNo,': ',S);
  If UseListing Then WriteLn(ListText,'**** ',S);
 End;
End;

Function FindSymbol(N:TString):Integer;
Var
 I:Integer;
Begin
 N:=Up(N);
 For I:=0 To SymbolCount-1 Do If Symbols[I].Name=N Then Begin
  FindSymbol:=I; Exit;
 End; FindSymbol:=-1;
End;

Procedure DefineSymbol(N:TString; V:LongInt);
Var
 I:Integer;
Begin
 If N='' Then Exit; N:=Up(N); I:=FindSymbol(N); If I<0 Then Begin
  If SymbolCount>=MAX_SYMBOLS Then Begin
   Error('Table des symboles pleine'); Exit;
 End; I:=SymbolCount; Inc(SymbolCount); Symbols[I].Name:=N;
  Symbols[I].External:=False; Symbols[I].PublicSym:=False;
  Symbols[I].Relocatable:=False;
 End Else If Symbols[I].Defined And (Pass=1) Then Begin
  Error('Symbole defini deux fois: '+N); Exit;
 End; Symbols[I].Value:=V; Symbols[I].Defined:=True;
End;

Function SourceDirectory(S:TString):TString;
Var I,P:Integer;
Begin P:=0; For I:=1 To Length(S) Do If S[I] In ['\','/'] Then P:=I; SourceDirectory:=Copy(S,1,P); End;

Function GetOrCreateSymbol(N:TString):Integer;
Var I:Integer;
Begin
 N:=Up(Trim(N)); I:=FindSymbol(N);
 If (I<0) And (N<>'') Then Begin
  If SymbolCount>=MAX_SYMBOLS Then Begin Error('Table des symboles pleine'); GetOrCreateSymbol:=-1; Exit; End;
  I:=SymbolCount; Inc(SymbolCount); Symbols[I].Name:=N; Symbols[I].Value:=0;
  Symbols[I].Defined:=False; Symbols[I].External:=False;
  Symbols[I].PublicSym:=False; Symbols[I].Relocatable:=False;
 End; GetOrCreateSymbol:=I;
End;

Function ExpressionSymbol(S:TString):TString;
Var I,A:Integer; C:Char;
Begin
 S:=Trim(S); If (S<>'') And (S[1] In ['<','>','#']) Then Delete(S,1,1);
 While (S<>'') And (S[1]='(') Do Delete(S,1,1);
 A:=1; While A<=Length(S) Do Begin C:=S[A];
  If (C In ['A'..'Z','a'..'z','@','_','.']) Then Break; Inc(A); End;
 I:=A; While (I<=Length(S)) And (S[I] In ['A'..'Z','a'..'z','0'..'9','@','_','.']) Do Inc(I);
 ExpressionSymbol:=Up(Copy(S,A,I-A));
End;

Procedure AddReloc(Offset:LongInt; Kind:Byte; Expr:TString);
Var N:TString; I:Integer;
Begin
 If (Pass<>2) Or Not RelMode Or InDsect Then Exit; N:=ExpressionSymbol(Expr);
 If N='' Then Exit; I:=FindSymbol(N);
 If (I<0) Or ((Not Symbols[I].External) And (Not Symbols[I].Relocatable)) Then Exit;
 If RelocCount>=MAX_RELOCS Then Begin Error('Table de relocation pleine'); Exit; End;
 Relocs[RelocCount].Offset:=Offset; Relocs[RelocCount].Kind:=Kind;
 Relocs[RelocCount].SymbolName:=N; Inc(RelocCount);
End;

Function EvalAtom(S:TString; Var Known:Boolean):LongInt;
Var
 V:LongInt;
 C:Integer;
 Code:Integer;
 Low,High:Boolean;
Begin
 S:=Trim(S); Low:=False; High:=False; If S='' Then Begin
  Known:=False; EvalAtom:=0; Exit;
 End;
 { EDASM historique: > donne l'octet faible et < l'octet fort. }
 If S[1]='>' Then Begin
  Low:=True; Delete(S,1,1);
 End Else If S[1]='<' Then Begin
  High:=True; Delete(S,1,1);
 End;
 If S='*' Then V:=PC Else If S[1]='$' Then Begin
  Val('$'+Copy(S,2,255),V,Code); If Code<>0 Then Known:=False;
 End
 Else If S[1]='%' Then Begin
  V:=0;
  For C:=2 To Length(S) Do If S[C] In ['0','1'] Then V:=V*2+Ord(S[C])-48 Else Known:=
  False;
 End
 Else If (S[1]='''') And (Length(S)>=2) Then V:=Ord(S[2]) Else
 Begin
  C:=FindSymbol(S); If (C>=0) And Symbols[C].Defined Then V:=Symbols[C].Value Else
  Begin
   V:=0; Val(S,V,Code); If Code<>0 Then Known:=False;
  End;
 End;
 If Low Then V:=V And $FF Else If High Then V:=(V Shr 8) And $FF; EvalAtom:=V;
End;

Function Eval(S:TString; Var Known:Boolean):LongInt;
Var
 I,Start:Integer;
 Sign:LongInt;
 T:TString;
 V:LongInt;
 InQuote:Boolean;
Begin
 Known:=True; V:=0; Sign:=1; Start:=1; InQuote:=False; I:=1;
 While I<=Length(S)+1 Do Begin
  If (I<=Length(S)) And (S[I]='''') Then InQuote:=Not InQuote;
  If (I>Length(S)) Or (((S[I]='+') Or (S[I]='-')) And Not InQuote) Then Begin
   T:=Copy(S,Start,I-Start); If Trim(T)<>'' Then V:=V+Sign*EvalAtom(T,Known);
   If I<=Length(S) Then If S[I]='-' Then Sign:=-1 Else Sign:=1; Start:=I+1;
  End; Inc(I);
 End; Eval:=V;
End;

Procedure EmitByte(B:Byte; Var Bytes:TString);
Var
 W:Word;
Begin
 If InDsect Then Begin Inc(PC); Exit; End;
 Bytes:=Bytes+Chr(B); If Pass=2 Then Begin
  BlockWrite(Obj,B,1,W); If W<>1 Then Error('Erreur d''ecriture objet');
 End; Inc(PC); Inc(ObjPC);
End;

Procedure EmitWord(V:LongInt; Var Bytes:TString);Begin
 EmitByte(V And $FF,Bytes); EmitByte((V Shr 8) And $FF,Bytes);
End;

Function ImpliedOpcode(M:TString):Integer;Begin
 If M='BRK' Then ImpliedOpcode:=$00 Else If M='PHP' Then ImpliedOpcode:=$08 Else If M=
 'CLC' Then ImpliedOpcode:=$18 Else If M='PLP' Then ImpliedOpcode:=$28 Else If M=
 'SEC' Then ImpliedOpcode:=$38 Else If M='RTI' Then ImpliedOpcode:=$40 Else If M=
 'PHA' Then ImpliedOpcode:=$48 Else If M='CLI' Then ImpliedOpcode:=$58 Else If M=
 'RTS' Then ImpliedOpcode:=$60 Else If M='PLA' Then ImpliedOpcode:=$68 Else If M=
 'SEI' Then ImpliedOpcode:=$78 Else If M='DEY' Then ImpliedOpcode:=$88 Else If M=
 'TXA' Then ImpliedOpcode:=$8A Else If M='TYA' Then ImpliedOpcode:=$98 Else If M=
 'TXS' Then ImpliedOpcode:=$9A Else If M='TAY' Then ImpliedOpcode:=$A8 Else If M=
 'TAX' Then ImpliedOpcode:=$AA Else If M='CLV' Then ImpliedOpcode:=$B8 Else If M=
 'TSX' Then ImpliedOpcode:=$BA Else If M='INY' Then ImpliedOpcode:=$C8 Else If M=
 'DEX' Then ImpliedOpcode:=$CA Else If M='CLD' Then ImpliedOpcode:=$D8 Else If M=
 'INX' Then ImpliedOpcode:=$E8 Else If M='NOP' Then ImpliedOpcode:=$EA Else If M=
 'SED' Then ImpliedOpcode:=$F8 Else ImpliedOpcode:=-1;
End;

Function Opcode(M:TString; Mode:Byte):Integer;
Const
 G1:Array[0..7] Of String[3]=('ORA','AND','EOR','ADC','STA','LDA','CMP','SBC');
 Base:Array[0..7] Of Byte=($00,$20,$40,$60,$80,$A0,$C0,$E0);
Var
 I,B:Integer;
Begin
 Opcode:=-1; If Mode=AM_IMP Then Begin
  Opcode:=ImpliedOpcode(M); Exit;
 End;
 If (Mode=AM_ACC) And (M='ASL') Then Opcode:=$0A Else If (Mode=AM_ACC) And (M='ROL')
 Then Opcode:=$2A Else If (Mode=AM_ACC) And (M='LSR') Then Opcode:=$4A Else If (Mode=
 AM_ACC) And (M='ROR') Then Opcode:=$6A Else
 Begin
  I:=-1;
  For B:=0 To 7 Do If M=G1[B] Then I:=B; If I>=0 Then Begin
   B:=Base[I]; Case Mode Of AM_INX:Opcode:=B+$01; AM_ZP:Opcode:=B+$05;
   AM_IMM:If M<>'STA' Then Opcode:=B+$09; AM_ABS:Opcode:=B+$0D; AM_INY:Opcode:=B+$11;
   AM_ZPX:Opcode:=B+$15; AM_ABY:Opcode:=B+$19; AM_ABX:Opcode:=B+$1D;
  End; Exit;
 End;
 If (M='ASL') Or (M='ROL') Or (M='LSR') Or (M='ROR') Then Begin
  If M='ASL' Then B:=$00 Else If M='ROL' Then B:=$20 Else If M='LSR' Then B:=$40 Else B:=
  $60; Case Mode Of AM_ZP:Opcode:=B+$06; AM_ABS:Opcode:=B+$0E; AM_ZPX:Opcode:=B+$16;
  AM_ABX:Opcode:=B+$1E;
 End; Exit;
End;
If M='JMP' Then Begin
 If Mode=AM_ABS Then Opcode:=$4C Else If Mode=AM_IND Then Opcode:=$6C;
End Else If (M='JSR') And (Mode=AM_ABS) Then Opcode:=$20 Else
If M='BIT' Then Begin
 If Mode=AM_ZP Then Opcode:=$24 Else If Mode=AM_ABS Then Opcode:=$2C;
End
Else If M='STX' Then Case Mode Of AM_ZP:Opcode:=$86; AM_ZPY:Opcode:=$96;
AM_ABS:Opcode:=$8E;
End
Else If M='LDX' Then Case Mode Of AM_IMM:Opcode:=$A2; AM_ZP:Opcode:=$A6;
AM_ZPY:Opcode:=$B6; AM_ABS:Opcode:=$AE; AM_ABY:Opcode:=$BE;
End
Else If M='STY' Then Case Mode Of AM_ZP:Opcode:=$84; AM_ZPX:Opcode:=$94;
AM_ABS:Opcode:=$8C;
End
Else If M='LDY' Then Case Mode Of AM_IMM:Opcode:=$A0; AM_ZP:Opcode:=$A4;
AM_ZPX:Opcode:=$B4; AM_ABS:Opcode:=$AC; AM_ABX:Opcode:=$BC;
End
Else If (M='CPX') Or (M='CPY') Then Begin
 If M='CPX' Then B:=$E0 Else B:=$C0; Case Mode Of AM_IMM:Opcode:=B; AM_ZP:Opcode:=B+$04;
 AM_ABS:Opcode:=B+$0C;
End;
End
Else If (M='INC') Or (M='DEC') Then Begin
 If M='INC' Then B:=$E0 Else B:=$C0; Case Mode Of AM_ZP:Opcode:=B+$06;
 AM_ZPX:Opcode:=B+$16; AM_ABS:Opcode:=B+$0E; AM_ABX:Opcode:=B+$1E;
End;
End
Else If Mode=AM_REL Then Begin
 If M='BPL' Then Opcode:=$10 Else If M='BMI' Then Opcode:=$30 Else If M=
 'BVC' Then Opcode:=$50 Else If M='BVS' Then Opcode:=$70 Else If M='BCC' Then Opcode:=
 $90 Else If M='BCS' Then Opcode:=$B0 Else If M='BNE' Then Opcode:=$D0 Else If M=
 'BEQ' Then Opcode:=$F0;
End;
End;
End;

Procedure ParseFields(Line:TString; Var LabelName,Op,Arg,Comment:TString);
Var
 I,P:Integer;
 HasLabel:Boolean;

Function Token:TString;
Var
 A:Integer;
Begin
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); A:=I;
 While (I<=Length(Line)) And Not(Line[I] In [' ',#9]) Do Inc(I); Token:=Copy(Line,A,I-A);
End;
Begin
 LabelName:=''; Op:=''; Arg:=''; Comment:=''; P:=Pos(';',Line); If P>0 Then Begin
  Comment:=Copy(Line,P,255); Delete(Line,P,255);
 End; If Trim(Line)='' Then Exit; HasLabel:=Not(Line[1] In [' ',#9]); I:=1;
 If HasLabel Then Begin
  LabelName:=Token; Op:=Up(Token);
 End Else Op:=Up(Token);
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); Arg:=Trim(Copy(Line,I,255));
 If (LabelName<>'') And (Op='') Then Begin
  Op:=Up(LabelName); LabelName:='';
 End;
End;

Procedure DetermineMode(M,Arg:TString; V:LongInt; Known:Boolean; Var Mode,Size:Byte;
                        Var Expr:TString);
Var
 U:TString;
 P:Integer;
Begin
 U:=Up(Trim(Arg)); Expr:=U; If U='' Then Begin
  Mode:=AM_IMP; Size:=1; Exit;
 End; If U='A' Then Begin
  Mode:=AM_ACC; Size:=1; Exit;
 End;
 If (M[1]='B') And (Length(M)=3) And (M<>'BIT') And (M<>'BRK') Then Begin
  Mode:=AM_REL; Size:=2; Exit;
 End;
 If U[1]='#' Then Begin
  Delete(Expr,1,1); Mode:=AM_IMM; Size:=2; Exit;
 End;
 If (U[1]='(') Then Begin
  P:=Pos(')',U); If Pos(',X)',U)>0 Then Begin
   Mode:=AM_INX; Expr:=Copy(U,2,Pos(',X)',U)-2); Size:=2;
  End Else If Pos('),Y',U)>0 Then Begin
   Mode:=AM_INY; Expr:=Copy(U,2,Pos('),Y',U)-2); Size:=2;
  End Else
  Begin
   Mode:=AM_IND; Expr:=Copy(U,2,P-2); Size:=3;
  End; Exit;
 End;
 If Pos(',X',U)>0 Then Begin
  Delete(Expr,Pos(',X',Expr),2); If Known And (V<256) Then Begin
   Mode:=AM_ZPX; Size:=2;
  End Else
  Begin
   Mode:=AM_ABX; Size:=3;
  End; Exit;
 End;
 If Pos(',Y',U)>0 Then Begin
  Delete(Expr,Pos(',Y',Expr),2); If Known And (V<256) Then Begin
   Mode:=AM_ZPY; Size:=2;
  End Else
  Begin
   Mode:=AM_ABY; Size:=3;
  End; Exit;
 End;
 If Known And (V>=0) And (V<256) And (M<>'JMP') And (M<>'JSR') Then Begin
  Mode:=AM_ZP; Size:=2;
 End Else
 Begin
  Mode:=AM_ABS; Size:=3;
 End;
End;

Procedure NewListingPage;
Begin
 If (Pass<>2) Or Not UseListing Or Not ListingEnabled Then Exit;
 If ListPage>0 Then WriteLn(ListText,#12); Inc(ListPage); ListRow:=0;
 WriteLn(ListText,'EDASM ',VERSION,'   ',CurrentSource,'   PAGE ',ListPage);
 If Subtitle<>'' Then WriteLn(ListText,Subtitle) Else WriteLn(ListText);
 WriteLn(ListText,' LINE ADDR  OBJECT       SOURCE'); WriteLn(ListText); ListRow:=4;
End;

Procedure EnsureListingRows(Count:Integer);
Begin
 If (Pass<>2) Or Not UseListing Or Not ListingEnabled Then Exit;
 If (ListPage=0) Or (ListRow+Count>PageLength) Then NewListingPage;
End;

Procedure SkipListing(Count:Integer);
Begin
 If Count<1 Then Count:=1; EnsureListingRows(Count);
 While Count>0 Do Begin WriteLn(ListText); Inc(ListRow); Dec(Count); End;
End;

Procedure ListLine(Address:LongInt; Bytes,Source:TString);
Var
 I:Integer;
 H:TString;
Begin
 If (Pass<>2) Or Not UseListing Or Not ListingEnabled Then Exit;
 EnsureListingRows(1); H:='';
 For I:=1 To Length(Bytes) Do H:=H+Hex(Ord(Bytes[I]),2)+' ';
 While Length(H)<12 Do H:=H+' ';
 WriteLn(ListText,LineNo:5,' ',Hex(Address,4),'  ',H,Source); Inc(ListRow);
End;

Procedure ProcessSourceFile(Name:TString; Depth:Integer); Forward;

Procedure ProcessLine(Source:TString);
Var
 Lab,M,A,C,E,Item,Bytes:TString;
 V,OldPC:LongInt;
 Known:Boolean;
 Mode,Size:Byte;
 O,P,I,Code:Integer;
Begin
 Inc(LineNo); OldPC:=PC; Bytes:='';
 If (Trim(Source)<>'') And (Trim(Source)[1]='*') Then Begin
  ListLine(PC,'',Source); Exit;
 End; ParseFields(Source,Lab,M,A,C);
 If M='DO' Then Begin
  V:=Eval(A,Known); CondStack[CondDepth]:=Active; Inc(CondDepth);
  Active:=Active And Known And (V<>0); ListLine(PC,'',Source); Exit;
 End;
 If M='ELSE' Then Begin
  If CondDepth=0 Then Error('ELSE sans DO') Else Active:=CondStack[CondDepth-
  1] And Not Active; ListLine(PC,'',Source); Exit;
 End;
 If M='FIN' Then Begin
  If CondDepth=0 Then Error('FIN sans DO') Else
  Begin
   Dec(CondDepth); Active:=CondStack[CondDepth];
  End; ListLine(PC,'',Source); Exit;
 End;
 If Not Active Then Begin
  ListLine(PC,'',Source); Exit;
 End;
 If (M='EQU') Or (M='=') Then Begin
  V:=Eval(A,Known); If Not Known And (Pass=1) Then Error('Expression EQU inconnue');
  DefineSymbol(Lab,V); ListLine(V,'',Source); Exit;
 End;
 If Lab<>'' Then Begin
  DefineSymbol(Lab,PC); I:=FindSymbol(Lab);
  If (I>=0) And RelMode And Not InDsect Then Symbols[I].Relocatable:=True;
 End; If M='' Then Begin
  ListLine(PC,'',Source); Exit;
 End;
 If M='ORG' Then Begin
  V:=Eval(A,Known); If Known Then PC:=V Else Error('ORG invalide');
  If FirstPC<0 Then FirstPC:=PC; ListLine(PC,'',Source); Exit;
 End;
 If M='OBJ' Then Begin
  V:=Eval(A,Known); If Known Then ObjPC:=V Else Error('OBJ invalide');
  ListLine(PC,'',Source); Exit;
 End;
 If M='END' Then Begin
  EndSeen:=True; ListLine(PC,'',Source); Exit;
 End;
 If M='MSB' Then Begin
  MSBMode:=Up(A)<>'OFF'; ListLine(PC,'',Source); Exit;
 End;
 If M='LST' Then Begin
  ListingEnabled:=Up(A)<>'OFF'; ListLine(PC,'',Source); Exit;
 End;
 If M='DSECT' Then Begin
  If InDsect Then Error('DSECT imbrique interdit') Else Begin
   SavedPC:=PC; V:=0; If Trim(A)<>'' Then Begin V:=Eval(A,Known); If Not Known Then Error('Adresse DSECT inconnue'); End;
   PC:=V; InDsect:=True; If Lab<>'' Then Begin I:=FindSymbol(Lab); If I>=0 Then Symbols[I].Value:=PC; End;
  End; ListLine(PC,'',Source); Exit;
 End;
 If M='DEND' Then Begin
  If Not InDsect Then Error('DEND sans DSECT') Else Begin PC:=SavedPC; InDsect:=False; End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='REL' Then Begin
  RelMode:=True; If Trim(A)<>'' Then Begin V:=Eval(A,Known); If Known Then PC:=V Else Error('Adresse REL inconnue'); End;
  ListLine(PC,'',Source); Exit;
 End;
 If (M='EXTRN') Or (M='ENTRY') Then Begin
  If Lab<>'' Then A:=Lab+','+A; A:=A+',';
  While A<>'' Do Begin P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P);
   If Item<>'' Then Begin I:=GetOrCreateSymbol(Item); If I>=0 Then
    If M='EXTRN' Then Begin Symbols[I].External:=True; Symbols[I].Defined:=True; Symbols[I].Value:=0; End
    Else Symbols[I].PublicSym:=True;
   End;
  End; ListLine(PC,'',Source); Exit;
 End;
 If M='CHN' Then Begin
  A:=Trim(A); If (Length(A)>=2) And (A[1] In ['''','"']) And (A[Length(A)]=A[1]) Then A:=Copy(A,2,Length(A)-2);
  If A='' Then Error('Nom de fichier CHN absent') Else Begin ChainName:=A; ChainRequested:=True; End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='PAGE' Then Begin ListLine(PC,'',Source); NewListingPage; Exit; End;
 If M='SKP' Then Begin V:=1; If Trim(A)<>'' Then Begin V:=Eval(A,Known); If Not Known Then V:=1; End; ListLine(PC,'',Source); SkipListing(V); Exit; End;
 If M='SBTL' Then Begin Subtitle:=Trim(A); If (Length(Subtitle)>=2) And (Subtitle[1] In ['''','"']) And (Subtitle[Length(Subtitle)]=Subtitle[1]) Then Subtitle:=Copy(Subtitle,2,Length(Subtitle)-2); ListLine(PC,'',Source); NewListingPage; Exit; End;
 If (M='DFB') Or (M='DB') Then Begin
  A:=A+',';
  While A<>'' Do Begin
   P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P); V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DFB inconnue: '+Item);
   If (Item<>'') And (Item[1]='<') Then AddReloc(ObjPC,2,Item) Else AddReloc(ObjPC,1,Item);
   EmitByte(V,Bytes);
  End;
 End
 Else If (M='DW') Or (M='DA') Then Begin
  A:=A+',';
  While A<>'' Do Begin
   P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P); V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DW inconnue: '+Item); AddReloc(ObjPC,3,Item); EmitWord(V,Bytes);
  End;
 End
 Else If (M='DS') Or (M='DFS') Then Begin
  V:=Eval(A,Known); If Not Known Then Error('Taille DS inconnue') Else
  For I:=1 To V Do EmitByte(0,Bytes);
 End
 Else If M='HEX' Then Begin
  A:=Trim(A); I:=1;
  While I<=Length(A) Do Begin
   While (I<=Length(A)) And (A[I] In [' ',#9,',']) Do Inc(I); If I+1<=Length(A) Then Begin
    Val('$'+Copy(A,I,2),V,Code);
    If Code<>0 Then Error('Chiffre HEX invalide') Else EmitByte(V,Bytes); Inc(I,2);
   End Else If I<=Length(A) Then Begin
    Error('Nombre impair de chiffres HEX'); Inc(I);
   End;
  End;
 End
 Else If (M='ASC') Or (M='DCI') Then Begin
  A:=Trim(A); If Length(A)>=2 Then Begin
   C:=A[1]; Delete(A,1,1); P:=Pos(C,A); If P=0 Then P:=Length(A)+1; A:=Copy(A,1,P-1);
   For I:=1 To Length(A) Do Begin
    V:=Ord(A[I]); If MSBMode Then V:=V Or $80;
    If (M='DCI') And (I=Length(A)) Then V:=V Xor $80; EmitByte(V,Bytes);
   End;
  End Else Error('Chaine ASC invalide');
 End
  Else
 Begin
  V:=Eval(A,Known); I:=FindSymbol(ExpressionSymbol(A));
  If (I>=0) And Symbols[I].External Then Known:=False;
  DetermineMode(M,A,V,Known,Mode,Size,E); V:=Eval(E,Known);
  O:=Opcode(M,Mode); If (O<0) And (Mode In [AM_ZP,AM_ZPX,AM_ZPY]) Then Begin
   Inc(Mode,3); Inc(Size); O:=Opcode(M,Mode);
  End; If O<0 Then Error('Mode d''adressage illegal pour '+M) Else
  Begin
   EmitByte(O,Bytes); If Mode=AM_REL Then Begin
    V:=V-(PC+1); If Known And ((V<-128) Or (V>127)) Then Error('Branchement hors limite');
    EmitByte(V And $FF,Bytes);
   End Else If Size=2 Then Begin AddReloc(ObjPC,1,E); EmitByte(V,Bytes); End
   Else If Size=3 Then Begin AddReloc(ObjPC,3,E); EmitWord(V,Bytes); End;
  End;
 End;
 If PC>LastPC Then LastPC:=PC; ListLine(OldPC,Bytes,Source);
End;

Procedure ProcessSourceFile(Name:TString; Depth:Integer);
Var
 F:Text;
 S:TString;
 E:Integer;
 NextName,PreviousSource:TString;
Begin
 If Depth>32 Then Begin Error('Trop de fichiers CHN (boucle probable)'); Exit; End;
 PreviousSource:=CurrentSource; CurrentSource:=Name;
 Assign(F,Name); Reset(F); E:=IOResult; If E<>0 Then Begin
  Error('Impossible d''ouvrir le fichier CHN '+Name); CurrentSource:=PreviousSource; Exit;
 End;
 ChainRequested:=False;
 While Not EOF(F) And Not EndSeen And Not ChainRequested Do Begin ReadLn(F,S); ProcessLine(S); End;
 Close(F); If ChainRequested And Not EndSeen Then Begin
  NextName:=ChainName; If SourceDirectory(NextName)='' Then NextName:=SourceDirectory(Name)+NextName;
  ChainRequested:=False; ProcessSourceFile(NextName,Depth+1);
 End; CurrentSource:=PreviousSource;
End;

Procedure AssembleOnePass;
Begin
 LineNo:=0; PC:=0; ObjPC:=0; FirstPC:=-1; LastPC:=0; EndSeen:=False;
 CondDepth:=0; Active:=True; MSBMode:=False; RelMode:=False; InDsect:=False;
 ChainRequested:=False; CurrentSource:=SrcName; ProcessSourceFile(SrcName,0);
 If InDsect Then Error('DSECT sans DEND');
 If CondDepth<>0 Then Error('DO sans FIN');
End;

Procedure WriteRelocationFile;
Var F:Text; I,E:Integer; N:TString;
Begin
 For I:=0 To SymbolCount-1 Do
  If Symbols[I].PublicSym And Not Symbols[I].Defined Then Error('Symbole ENTRY non defini: '+Symbols[I].Name);
 If Not RelMode And (RelocCount=0) Then Exit;
 N:=BaseName(ObjName)+'.REL'; Assign(F,N); Rewrite(F); E:=IOResult;
 If E<>0 Then Begin Error('Impossible de creer '+N); Exit; End;
 WriteLn(F,'EDASM-REL 1'); WriteLn(F,'OBJECT ',ObjName); WriteLn(F,'ORIGIN ',Hex(FirstPC,4));
 For I:=0 To SymbolCount-1 Do Begin
  If Symbols[I].External Then WriteLn(F,'EXTRN ',Symbols[I].Name);
  If Symbols[I].PublicSym And Symbols[I].Defined Then WriteLn(F,'ENTRY ',Symbols[I].Name,' ',Hex(Symbols[I].Value,4));
 End;
 For I:=0 To RelocCount-1 Do Begin
  Write(F,'RELOC ',Hex(Relocs[I].Offset,4),' ');
  Case Relocs[I].Kind Of 1:Write(F,'LOW8 '); 2:Write(F,'HIGH8 '); Else Write(F,'WORD16 '); End;
  WriteLn(F,Relocs[I].SymbolName);
 End; WriteLn(F,'END'); Close(F);
 If Not Quiet Then WriteLn('Relocations ecrites dans ',N);
End;

Procedure Help;Begin
 WriteLn('EDASM ',VERSION,' - Cette commande permet de lancer un assembleur Apple EDASM compatible 6502.');
 WriteLn;
 WriteLn('Syntaxe: EDASM source [objet] [/L:listing] [/Q]');
 WriteLn;
 WriteLn('Directives: ORG OBJ EQU = DFB DB DW DA DS DFS HEX ASC DCI MSB');
 WriteLn('            DO ELSE FIN LST PAGE SKP SBTL DSECT DEND REL EXTRN ENTRY CHN END');
 WriteLn;
 WriteLn('DSECT [adr] / DEND  Definit une zone symbolique sans octets objet.');
 WriteLn('REL [adr]            Active les informations de relocation <objet>.REL.');
 WriteLn('EXTRN nom,...        Declare des symboles fournis par un autre module.');
 WriteLn('ENTRY nom,...        Exporte des symboles definis dans ce module.');
 WriteLn('CHN fichier          Continue l''assemblage dans un autre source.');
 WriteLn('PAGE                 Commence une nouvelle page du listing.');
 WriteLn('SKP [n]              Insere n lignes blanches dans le listing.');
 WriteLn('SBTL texte           Change le sous-titre et commence une page.');
 WriteLn; 
 WriteLn('Nombres: decimal, $hexadecimal, %binaire, caracteres entre apostrophes.');
 WriteLn('Expressions: symbole+valeur, symbole-valeur, >octet-faible, <octet-fort.');
 Halt(0);
End;

Procedure ParseArgs;
Var
 I:Integer;
 A,U:TString;
Begin
 If ParamCount=0 Then Help; SrcName:=''; ObjName:=''; ListName:=''; ListingEnabled:=True;
 Quiet:=False;
 For I:=1 To ParamCount Do Begin
  A:=ParamStr(I); U:=Up(A);
  If (U='/?') Or (U='-?') Then Help Else If Copy(U,1,3)='/L:' Then Begin
   ListName:=Copy(A,4,255); UseListing:=True;
  End Else If U='/Q' Then Quiet:=True Else If (A<>'') And (A[1]='/') Then Begin
   WriteLn('Option inconnue: ',A); Halt(1);
  End Else If SrcName='' Then SrcName:=A Else If ObjName='' Then ObjName:=A Else
  Begin
   WriteLn('Argument surnumeraire: ',A); Halt(1);
  End;
 End; If ObjName='' Then ObjName:=BaseName(SrcName)+'.OBJ';
 If UseListing And (ListName='') Then ListName:=BaseName(SrcName)+'.LST';
End;

Var
 E:Integer;

BEGIN
 ParseArgs; SymbolCount:=0; Errors:=0; Pass:=1; AssembleOnePass;
 E:=IOResult; { efface un etat d'E/S non fatal laisse par un fichier source }
 Assign(Obj,ObjName); Rewrite(Obj,1); E:=IOResult; If E<>0 Then Begin
  WriteLn('EDASM: impossible de creer ',ObjName,' (erreur ',E,')'); Halt(3);
 End;
 If UseListing Then Begin
  Assign(ListText,ListName); Rewrite(ListText); If IOResult<>0 Then Begin
   WriteLn('EDASM: impossible de creer ',ListName); Close(Obj); Halt(3);
  End;
 End;
 { Stabilise les etiquettes et les choix page-zero/absolu apres la passe
   initiale. Les references avant peuvent modifier la taille du code. }
 Pass:=0; AssembleOnePass; AssembleOnePass; AssembleOnePass;
 Errors:=0; RelocCount:=0; ListPage:=0; ListRow:=0; PageLength:=60; Subtitle:='';
 Pass:=2; AssembleOnePass; WriteRelocationFile; Close(Obj); If UseListing Then Begin
  WriteLn(ListText); WriteLn(ListText,'Symboles: ',SymbolCount,'   Erreurs: ',Errors);
  Close(ListText);
 End;
 If Errors=0 Then Begin
  If Not Quiet Then WriteLn('Assemblage termine: ',ObjName,' (',LastPC-FirstPC,
  ' octets).');
 End Else
 Begin
  WriteLn(Errors,' erreur(s); objet invalide.'); Halt(4);
 End;
END.
