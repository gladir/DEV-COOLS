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
 VERSION='1.4';
 MAX_SYMBOLS=4096;
 MAX_REFERENCES=8192;
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
 SEC_UNDEF=0;
 SEC_ABSOLUTE=1;
 SEC_RELOCATABLE=2;
 SEC_DSECT=3;
 SEC_EXTERNAL=4;

Type
 TString=String;
 TObjectPage=Array[0..255] Of Byte;
 PObjectPage=^TObjectPage;
 TUsedPage=Array[0..255] Of Boolean;
 PUsedPage=^TUsedPage;
 TSymbol=Record
  Name:String[31];
 Value:LongInt;
 Defined,External,PublicSym,Relocatable,LocalSymbol:Boolean;
  EsdNumber:Byte;
  Section:Byte;
  DefinedLine:Word;
 End;
 TReference=Record
  SymbolIndex:Word;
  SourceLine:Word;
 End;
 TSymbolState=Record
  Value:LongInt;
  Defined,Relocatable:Boolean;
  Section:Byte;
 End;
 TReloc=Record
  Offset:LongInt;
  Kind:Byte;
  SymbolName:String[31];
  Aux:Byte;
 End;

Var
 ListText:Text;
 SrcName,ObjName,ListName:TString;
 Symbols:Array[0..MAX_SYMBOLS-1] Of TSymbol;
 SymbolCount:Integer;
 PreviousSymbols:Array[0..MAX_SYMBOLS-1] Of TSymbolState;
 PhaseStable:Boolean;
 References:Array[0..MAX_REFERENCES-1] Of TReference;
 ReferenceCount:Integer;
 Relocs:Array[0..MAX_RELOCS-1] Of TReloc;
 RelocCount:Integer;
 Pass,LineNo,Errors,NextEsdNumber:Integer;
 PC,ObjPC,FirstPC,LastPC:LongInt;
 ObjectMin,ObjectMax,ListObjAddress:LongInt;
 ObjectPages:Array[0..255] Of PObjectPage;
 UsedPages:Array[0..255] Of PUsedPage;
 ObjExplicit:Boolean;
 ListingEnabled,UseListing,MSBMode,EndSeen,Quiet,AppleBinaryHeader:Boolean;
 CondStack:Array[0..15] Of Boolean;
 CondDepth:Integer;
 Active:Boolean;
 RelMode,InDsect:Boolean;
 SavedPC:LongInt;
 CurrentSource,ChainName,Subtitle,CurrentScope:TString;
 ChainRequested:Boolean;
 ListPage,ListRow,PageLength:Integer;
 RepeatChar:Char;

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

Function IsLocalName(N:TString):Boolean;
Begin
 N:=Trim(N); IsLocalName:=(N<>'') And (N[1] In ['.','@']);
End;

Function CanonicalSymbolName(N:TString):TString;
Begin
 N:=Up(Trim(N));
 If IsLocalName(N) And (CurrentScope<>'') Then N:=CurrentScope+N;
 CanonicalSymbolName:=N;
End;

Function IsReservedSymbol(N:TString):Boolean;
Const
 R1=',ADC,AND,ASL,BCC,BCS,BEQ,BIT,BMI,BNE,BPL,BRK,BVC,BVS,CLC,CLD,CLI,CLV,CMP,CPX,CPY,DEC,DEX,DEY,EOR,INC,INX,INY,JMP,JSR,';
 R2=',LDA,LDX,LDY,LSR,NOP,ORA,PHA,PHP,PLA,PLP,ROL,ROR,RTI,RTS,SBC,SEC,SED,SEI,STA,STX,STY,TAX,TAY,TSX,TXA,TXS,TYA,';
 R3=',ORG,OBJ,EQU,DFB,DB,DW,DA,DDB,DCL,DS,DFS,HEX,ASC,DCI,MSB,DO,ELSE,FIN,LST,PAGE,SKP,SBTL,DSECT,DEND,REL,EXTRN,ENTRY,CHN,END,CHR,REP,A,X,Y,';
Begin
 N:=Up(Trim(N));
 IsReservedSymbol:=(Pos(','+N+',',R1)>0) Or (Pos(','+N+',',R2)>0) Or
                  (Pos(','+N+',',R3)>0);
End;

Function FindSymbol(N:TString):Integer;
Var
 I:Integer;
Begin
 N:=CanonicalSymbolName(N);
 For I:=0 To SymbolCount-1 Do If Symbols[I].Name=N Then Begin
  FindSymbol:=I; Exit;
 End; FindSymbol:=-1;
End;

Procedure DefineSymbol(N:TString; V:LongInt; Resolved:Boolean);
Var
 I:Integer;
 WasLocal:Boolean;
Begin
 If N='' Then Exit;
 WasLocal:=IsLocalName(N);
 If Not IsLocalName(N) And IsReservedSymbol(N) Then Begin
  Error('Nom de symbole reserve: '+Up(N)); Exit;
 End;
 N:=CanonicalSymbolName(N);
 If Length(N)>31 Then Begin Error('Nom de symbole trop long: '+N); Exit; End;
 I:=FindSymbol(N); If I<0 Then Begin
  If SymbolCount>=MAX_SYMBOLS Then Begin
   Error('Table des symboles pleine'); Exit;
 End; I:=SymbolCount; Inc(SymbolCount); Symbols[I].Name:=N;
 Symbols[I].External:=False; Symbols[I].PublicSym:=False;
  Symbols[I].Relocatable:=False; Symbols[I].EsdNumber:=0;
  Symbols[I].LocalSymbol:=WasLocal;
  Symbols[I].Section:=SEC_UNDEF; Symbols[I].DefinedLine:=0;
 End Else If Symbols[I].External Then Begin
  Error('Definition d''un symbole externe: '+N); Exit;
 End Else If (Symbols[I].DefinedLine<>0) And ((Pass=1) Or
  ((Pass=2) And (Symbols[I].DefinedLine<>LineNo))) Then Begin
  Error('Symbole defini deux fois: '+N); Exit;
 End;
 Symbols[I].Value:=V; Symbols[I].Defined:=Resolved;
 If Symbols[I].DefinedLine=0 Then Symbols[I].DefinedLine:=LineNo;
End;

Procedure InitObjectImage;
Var I:Integer;
Begin
 For I:=0 To 255 Do Begin ObjectPages[I]:=Nil; UsedPages[I]:=Nil; End;
 ObjectMin:=65536; ObjectMax:=-1;
End;

Procedure FreeObjectImage;
Var I:Integer;
Begin
 For I:=0 To 255 Do Begin
  If ObjectPages[I]<>Nil Then Dispose(ObjectPages[I]);
  If UsedPages[I]<>Nil Then Dispose(UsedPages[I]);
  ObjectPages[I]:=Nil; UsedPages[I]:=Nil;
 End;
End;

Procedure StoreObjectByte(Address:LongInt; B:Byte);
Var Page,Offset:Integer;
Begin
 If (Address<0) Or (Address>65535) Then Begin
  Error('Adresse objet hors limite: $'+Hex(Address,4)); Exit;
 End;
 Page:=Address Shr 8; Offset:=Address And $FF;
 If ObjectPages[Page]=Nil Then Begin
  New(ObjectPages[Page]); New(UsedPages[Page]);
  FillChar(ObjectPages[Page]^,SizeOf(TObjectPage),0);
  FillChar(UsedPages[Page]^,SizeOf(TUsedPage),0);
 End;
 If UsedPages[Page]^[Offset] Then Begin
  Error('Conflit de zone objet a $'+Hex(Address,4)); Exit;
 End;
 ObjectPages[Page]^[Offset]:=B; UsedPages[Page]^[Offset]:=True;
 If Address<ObjectMin Then ObjectMin:=Address;
 If Address>ObjectMax Then ObjectMax:=Address;
End;

Procedure WriteFileByte(Var F:File; B:Byte; Var Failed:Boolean);
Var W:Word;
Begin
 If Failed Then Exit; BlockWrite(F,B,1,W);
 If W<>1 Then Begin Error('Erreur d''ecriture objet'); Failed:=True; End;
End;

Function ObjectByte(Address:LongInt):Byte;
Begin
 If (Address>=0) And (Address<=65535) And
    (UsedPages[Address Shr 8]<>Nil) And
    UsedPages[Address Shr 8]^[Address And $FF] Then
  ObjectByte:=ObjectPages[Address Shr 8]^[Address And $FF] Else ObjectByte:=0;
End;

Function WriteObjectFile:Boolean;
Var
 F:File;
 Address,ImageLength,Offset:LongInt;
 B,Flags:Byte;
 E,I,J,S:Integer;
 Failed:Boolean;
 N:TString;
Begin
 WriteObjectFile:=False; Failed:=False;
 Assign(F,ObjName); Rewrite(F,1); E:=IOResult;
 If E<>0 Then Begin Error('Impossible de creer '+ObjName); Exit; End;
 If ObjectMax>=ObjectMin Then ImageLength:=ObjectMax-ObjectMin+1 Else ImageLength:=0;

 { Le format REL EDASM commence par la longueur de l'image. Sous ProDOS,
   le type de fichier doit etre $FE et l'AUXTYPE contient l'ORG. }
 If RelMode Then Begin
  WriteFileByte(F,ImageLength And $FF,Failed);
  WriteFileByte(F,(ImageLength Shr 8) And $FF,Failed);
 End Else If AppleBinaryHeader Then Begin
  WriteFileByte(F,ObjectMin And $FF,Failed);
  WriteFileByte(F,(ObjectMin Shr 8) And $FF,Failed);
  WriteFileByte(F,ImageLength And $FF,Failed);
  WriteFileByte(F,(ImageLength Shr 8) And $FF,Failed);
 End;

 If ImageLength>0 Then For Address:=ObjectMin To ObjectMax Do
  WriteFileByte(F,ObjectByte(Address),Failed);

 If RelMode Then Begin
  { RLD: indicateurs, position du champ (lo/hi), numero ESD ou octet
    auxiliaire. Le bit 0 indique qu'un autre enregistrement suit. }
  For I:=0 To RelocCount-1 Do Begin
   Offset:=Relocs[I].Offset-ObjectMin;
   If (Offset<0) Or (Offset>=ImageLength) Then Begin
    Error('Relocation hors image a $'+Hex(Relocs[I].Offset,4)); Failed:=True;
   End Else Begin
    Case Relocs[I].Kind Of
     1:Flags:=$01;             { octet faible }
     2:Flags:=$41;             { octet fort }
     3:Flags:=$81;             { mot faible/fort }
     5:Flags:=$A1;             { mot fort/faible }
     Else Begin Flags:=$81; Error('Relocation 32 bits reduite a 16 bits'); Failed:=True; End;
    End;
    S:=FindSymbol(Relocs[I].SymbolName);
    B:=Relocs[I].Aux;
    If (S>=0) And Symbols[S].External Then Begin
     Flags:=Flags Or $10; B:=Symbols[S].EsdNumber;
    End;
    WriteFileByte(F,Flags,Failed); WriteFileByte(F,Offset And $FF,Failed);
    WriteFileByte(F,(Offset Shr 8) And $FF,Failed); WriteFileByte(F,B,Failed);
   End;
  End;
  WriteFileByte(F,0,Failed); { fin du RLD }

  { ESD: nom avec bit 7 sur tous les caracteres sauf le dernier,
    indicateurs du symbole, puis valeur ou numero de symbole externe. }
  For I:=1 To 255 Do For S:=0 To SymbolCount-1 Do
   If Symbols[S].EsdNumber=I Then Begin
    N:=Symbols[S].Name;
    For J:=1 To Length(N) Do Begin
     B:=Ord(N[J]); If J<Length(N) Then B:=B Or $80;
     WriteFileByte(F,B,Failed);
    End;
    If Symbols[S].External Then Begin
     WriteFileByte(F,$31,Failed); WriteFileByte(F,Symbols[S].EsdNumber,Failed);
     WriteFileByte(F,0,Failed);
    End Else Begin
     WriteFileByte(F,$28,Failed); WriteFileByte(F,Symbols[S].Value And $FF,Failed);
     WriteFileByte(F,(Symbols[S].Value Shr 8) And $FF,Failed);
    End;
   End;
  WriteFileByte(F,0,Failed); { fin de l'ESD }
 End;
 Close(F); E:=IOResult;
 If E<>0 Then Begin Error('Erreur de fermeture objet'); Failed:=True; End;
 WriteObjectFile:=Not Failed;
End;

Function SourceDirectory(S:TString):TString;
Var I,P:Integer;
Begin P:=0; For I:=1 To Length(S) Do If S[I] In ['\','/'] Then P:=I; SourceDirectory:=Copy(S,1,P); End;

Function GetOrCreateSymbol(N:TString):Integer;
Var I:Integer; WasLocal:Boolean;
Begin
 WasLocal:=IsLocalName(N);
 If Not WasLocal And IsReservedSymbol(N) Then Begin
  Error('Nom de symbole reserve: '+Up(N)); GetOrCreateSymbol:=-1; Exit;
 End;
 N:=CanonicalSymbolName(N);
 If Length(N)>31 Then Begin Error('Nom de symbole trop long: '+N); GetOrCreateSymbol:=-1; Exit; End;
 I:=FindSymbol(N);
 If (I<0) And (N<>'') Then Begin
  If SymbolCount>=MAX_SYMBOLS Then Begin Error('Table des symboles pleine'); GetOrCreateSymbol:=-1; Exit; End;
  I:=SymbolCount; Inc(SymbolCount); Symbols[I].Name:=N; Symbols[I].Value:=0;
  Symbols[I].Defined:=False; Symbols[I].External:=False;
  Symbols[I].PublicSym:=False; Symbols[I].Relocatable:=False; Symbols[I].EsdNumber:=0;
  Symbols[I].LocalSymbol:=WasLocal; Symbols[I].Section:=SEC_UNDEF;
  Symbols[I].DefinedLine:=0;
 End; GetOrCreateSymbol:=I;
End;

Procedure AddCrossReference(SymbolIndex:Integer);
Var I:Integer;
Begin
 If (Pass<>2) Or (SymbolIndex<0) Then Exit;
 I:=ReferenceCount-1;
 While (I>=0) And (References[I].SourceLine=LineNo) Do Begin
  If References[I].SymbolIndex=SymbolIndex Then Exit; Dec(I);
 End;
 If ReferenceCount>=MAX_REFERENCES Then Begin
  Error('Table des references croisees pleine'); Exit;
 End;
 References[ReferenceCount].SymbolIndex:=SymbolIndex;
 References[ReferenceCount].SourceLine:=LineNo;
 Inc(ReferenceCount);
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

Function Eval(S:TString; Var Known:Boolean):LongInt; Forward;

Procedure AddReloc(Offset:LongInt; Kind:Byte; Expr:TString);
Var N,T:TString; I:Integer; V:LongInt; Known:Boolean;
Begin
 If (Pass<>2) Or Not RelMode Or InDsect Then Exit; N:=ExpressionSymbol(Expr);
 If N='' Then Exit; I:=FindSymbol(N);
 If (I<0) Or ((Not Symbols[I].External) And (Not Symbols[I].Relocatable)) Then Exit;
 If RelocCount>=MAX_RELOCS Then Begin Error('Table de relocation pleine'); Exit; End;
 Relocs[RelocCount].Offset:=Offset; Relocs[RelocCount].Kind:=Kind;
 Relocs[RelocCount].SymbolName:=Symbols[I].Name; Relocs[RelocCount].Aux:=0;
 T:=Trim(Expr); If (T<>'') And (T[1] In ['<','>','#']) Then Delete(T,1,1);
 V:=Eval(T,Known);
 If Known And (Kind=2) Then Relocs[RelocCount].Aux:=V And $FF;
 Inc(RelocCount);
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
  C:=FindSymbol(S); If C>=0 Then AddCrossReference(C);
  If (C>=0) And Symbols[C].Defined Then V:=Symbols[C].Value Else
  Begin
   V:=0; Val(S,V,Code); If Code<>0 Then Begin
    Known:=False;
    If Pass=2 Then Error('Symbole non defini ou valeur invalide: '+S);
    If (C<0) And (Pass=1) Then C:=GetOrCreateSymbol(S);
   End;
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
 End;
 If Trim(S)='' Then Known:=False;
 If (Pass=2) And Not Known Then Error('Expression inconnue: '+S);
 Eval:=V;
End;

{ Les differences de deux adresses REL sont absolues; une adresse REL
  plus une constante reste relogeable. Les extractions d'octet sont ABS. }
Function EquSection(S:TString):Byte;
Var I,Start,J,Balance,Sign:Integer; T:TString; InQuote:Boolean;
Begin
 Balance:=0; Sign:=1; Start:=1; InQuote:=False;
 For I:=1 To Length(S)+1 Do Begin
  If (I<=Length(S)) And (S[I]='''') Then InQuote:=Not InQuote;
  If (I>Length(S)) Or ((S[I] In ['+','-']) And Not InQuote) Then Begin
   T:=Trim(Copy(S,Start,I-Start));
   If T='*' Then Begin
    If RelMode And Not InDsect Then Inc(Balance,Sign);
   End Else If T<>'' Then Begin
    J:=FindSymbol(T);
    If J>=0 Then Begin
     If Symbols[J].External Then Error('EQU sur symbole externe interdit: '+T)
     Else If Symbols[J].Relocatable Then Inc(Balance,Sign);
    End;
   End;
   If I<=Length(S) Then If S[I]='-' Then Sign:=-1 Else Sign:=1;
   Start:=I+1;
  End;
 End;
 EquSection:=SEC_ABSOLUTE;
 If Balance=1 Then EquSection:=SEC_RELOCATABLE
 Else If Balance<>0 Then Error('Expression EQU non relogeable');
End;

Procedure EmitByte(B:Byte; Var Bytes:TString);
Begin
 If InDsect Then Begin Inc(PC); Exit; End;
 Bytes:=Bytes+Chr(B); If Pass=2 Then StoreObjectByte(ObjPC,B);
 Inc(PC); Inc(ObjPC);
End;

Procedure EmitWord(V:LongInt; Var Bytes:TString);Begin
 EmitByte(V And $FF,Bytes); EmitByte((V Shr 8) And $FF,Bytes);
End;

Procedure EmitBigWord(V:LongInt; Var Bytes:TString);Begin
 EmitByte((V Shr 8) And $FF,Bytes); EmitByte(V And $FF,Bytes);
End;

Procedure EmitLong(V:LongInt; Var Bytes:TString);Begin
 EmitByte(V And $FF,Bytes); EmitByte((V Shr 8) And $FF,Bytes);
 EmitByte((V Shr 16) And $FF,Bytes); EmitByte((V Shr 24) And $FF,Bytes);
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
 Quote:Char;

Function Token:TString;
Var
 A:Integer;
Begin
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); A:=I;
 While (I<=Length(Line)) And Not(Line[I] In [' ',#9]) Do Inc(I); Token:=Copy(Line,A,I-A);
End;
Begin
 LabelName:=''; Op:=''; Arg:=''; Comment:=''; P:=0; Quote:=#0;
 For I:=1 To Length(Line) Do Begin
  If (Line[I] In ['''','"']) Then Begin If Quote=#0 Then Quote:=Line[I] Else If Quote=Line[I] Then Quote:=#0; End
  Else If (Line[I]=';') And (Quote=#0) Then Begin P:=I; Break; End;
 End;
 If P>0 Then Begin
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
 WriteLn(ListText,' LINE EXEC OBJ  OBJECT       SOURCE'); WriteLn(ListText); ListRow:=4;
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

Procedure RepeatListing(Count:Integer);
Var S:TString;
Begin
 If Count<0 Then Count:=0; If Count>255 Then Count:=255;
 EnsureListingRows(1); S:=''; While Count>0 Do Begin S:=S+RepeatChar; Dec(Count); End;
 If (Pass=2) And UseListing And ListingEnabled Then Begin WriteLn(ListText,S); Inc(ListRow); End;
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
 WriteLn(ListText,LineNo:5,' ',Hex(Address,4),' ',Hex(ListObjAddress,4),' ',H,Source);
 Inc(ListRow);
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
 Inc(LineNo); OldPC:=PC; ListObjAddress:=ObjPC; Bytes:='';
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
 If (Lab<>'') And (M<>'ENTRY') And (M<>'EXTRN') And
  Not IsLocalName(Lab) And Not IsReservedSymbol(Lab) Then
  CurrentScope:=Up(Lab);
 If (M='EQU') Or (M='=') Then Begin
  V:=Eval(A,Known);
  DefineSymbol(Lab,V,Known); I:=FindSymbol(Lab); If I>=0 Then Begin
   If Known Then Symbols[I].Section:=EquSection(A)
   Else Symbols[I].Section:=SEC_UNDEF;
   Symbols[I].Relocatable:=Symbols[I].Section=SEC_RELOCATABLE;
  End; ListLine(V,'',Source); Exit;
 End;
 If (Lab<>'') And (M<>'ENTRY') And (M<>'EXTRN') Then Begin
  DefineSymbol(Lab,PC,True); I:=FindSymbol(Lab);
  If I>=0 Then Begin
   If InDsect Then Symbols[I].Section:=SEC_DSECT
   Else If RelMode Then Symbols[I].Section:=SEC_RELOCATABLE
   Else Symbols[I].Section:=SEC_ABSOLUTE;
   Symbols[I].Relocatable:=RelMode And Not InDsect;
  End;
 End; If M='' Then Begin
  ListLine(PC,'',Source); Exit;
 End;
 If M='ORG' Then Begin
  V:=Eval(A,Known); If Known Then PC:=V Else Error('ORG invalide');
  If Known And Not ObjExplicit Then ObjPC:=V;
  ListObjAddress:=ObjPC;
  If FirstPC<0 Then FirstPC:=PC; ListLine(PC,'',Source); Exit;
 End;
 If M='OBJ' Then Begin
  If RelMode Then Begin Error('OBJ interdit dans un module REL'); ListLine(PC,'',Source); Exit; End;
  V:=Eval(A,Known); If Known Then Begin
   ObjPC:=V; ObjExplicit:=True; ListObjAddress:=ObjPC;
  End Else Error('OBJ invalide');
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
   If Lab<>'' Then Begin I:=FindSymbol(Lab); If I>=0 Then Begin
    Symbols[I].Section:=SEC_DSECT; Symbols[I].Relocatable:=False;
   End; End;
  End; ListLine(PC,'',Source); Exit;
 End;
 If M='DEND' Then Begin
  If Not InDsect Then Error('DEND sans DSECT') Else Begin PC:=SavedPC; InDsect:=False; End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='REL' Then Begin
  If ObjExplicit Then Error('REL incompatible avec OBJ') Else RelMode:=True;
  If Trim(A)<>'' Then Begin
   V:=Eval(A,Known); If Known Then Begin PC:=V; ObjPC:=V; End
   Else Error('Adresse REL inconnue');
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If (M='EXTRN') Or (M='ENTRY') Then Begin
  If Lab<>'' Then A:=Lab+','+A; A:=A+',';
  While A<>'' Do Begin P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P);
   If IsLocalName(Item) Then Error('ENTRY/EXTRN exige un symbole global: '+Item)
   Else If Item<>'' Then Begin I:=GetOrCreateSymbol(Item); If I>=0 Then
    Begin
     If ((M='EXTRN') And (Symbols[I].PublicSym Or
         (Symbols[I].Defined And Not Symbols[I].External))) Or
        ((M='ENTRY') And Symbols[I].External) Then Begin
      Error('Conflit ENTRY/EXTRN ou definition: '+Item);
     End Else Begin
     If Symbols[I].EsdNumber=0 Then Begin
      If NextEsdNumber>255 Then Error('Plus de 255 symboles ENTRY/EXTRN') Else Begin
       Symbols[I].EsdNumber:=NextEsdNumber; Inc(NextEsdNumber);
      End;
     End;
     If M='EXTRN' Then Begin
      Symbols[I].External:=True; Symbols[I].Defined:=True; Symbols[I].Value:=0;
      Symbols[I].Section:=SEC_EXTERNAL; Symbols[I].Relocatable:=True;
     End
     Else Symbols[I].PublicSym:=True;
     AddCrossReference(I);
     End;
    End;
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
 If M='CHR' Then Begin
  A:=Trim(A); If A='' Then Error('Caractere CHR absent') Else If (Length(A)>=2) And (A[1] In ['''','"']) Then RepeatChar:=A[2]
  Else If (Length(A)=1) And Not(A[1] In ['0'..'9']) Then RepeatChar:=A[1]
  Else Begin V:=Eval(A,Known); If Known And (V>=0) And (V<=255) Then RepeatChar:=Chr(V) Else Error('Valeur CHR invalide'); End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='REP' Then Begin
  V:=Eval(A,Known); If Not Known Or (V<0) Then Error('Nombre REP invalide') Else Begin ListLine(PC,'',Source); RepeatListing(V); End; Exit;
 End;
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
 Else If M='DDB' Then Begin
  A:=A+',';
  While A<>'' Do Begin
   P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P); V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DDB inconnue: '+Item); AddReloc(ObjPC,5,Item); EmitBigWord(V,Bytes);
  End;
 End
 Else If M='DCL' Then Begin
  A:=A+',';
  While A<>'' Do Begin
   P:=Pos(',',A); Item:=Trim(Copy(A,1,P-1)); Delete(A,1,P); V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DCL inconnue: '+Item); AddReloc(ObjPC,4,Item); EmitLong(V,Bytes);
  End;
 End
 Else If (M='DS') Or (M='DFS') Then Begin
  P:=Pos(',',A); Item:=A; C:='0'; If P>0 Then Begin Item:=Copy(A,1,P-1); C:=Copy(A,P+1,255); End;
  V:=Eval(Item,Known); If Not Known Or (V<0) Then Error('Taille DS inconnue ou negative') Else Begin
   O:=Eval(C,Known); If Not Known Or (O<0) Or (O>255) Then Error('Octet de remplissage DS invalide')
   Else For I:=1 To V Do EmitByte(O,Bytes);
  End;
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
  A:=Trim(A); Item:='';
  While A<>'' Do Begin
   While (A<>'') And (A[1] In [' ',#9,',']) Do Delete(A,1,1); If A='' Then Break;
   C:=A[1]; Delete(A,1,1); P:=Pos(C,A);
   If P=0 Then Begin Item:=Item+A; A:=''; End Else Begin Item:=Item+Copy(A,1,P-1); Delete(A,1,P); End;
  End;
  If Item='' Then Error('Chaine '+M+' vide') Else Begin
   For I:=1 To Length(Item) Do Begin V:=Ord(Item[I]); If MSBMode Then V:=V Or $80; If (M='DCI') And (I=Length(Item)) Then V:=V Xor $80; EmitByte(V,Bytes); End;
  End;
 End
  Else
 Begin
  { Extraire l'expression avant de l'evaluer: #, ,X et parentheses
    appartiennent au mode d'adressage, pas au nom du symbole. }
  DetermineMode(M,A,0,False,Mode,Size,E);
  V:=0; Known:=True;
  If Size>1 Then V:=Eval(E,Known);
  I:=FindSymbol(ExpressionSymbol(E));
  If (I>=0) And Symbols[I].External Then Known:=False;
  DetermineMode(M,A,V,Known,Mode,Size,E);
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
 ObjExplicit:=False; ListObjAddress:=0;
 CondDepth:=0; Active:=True; MSBMode:=False; RelMode:=False; InDsect:=False;
 RepeatChar:='*'; CurrentScope:='';
 ChainRequested:=False; CurrentSource:=SrcName; ProcessSourceFile(SrcName,0);
 If InDsect Then Error('DSECT sans DEND');
 If CondDepth<>0 Then Error('DO sans FIN');
End;

{ Une chaine de N EQU peut demander N passes. Ne pas considerer une
  valeur provisoire comme definie, sinon les cycles deviennent des zeros. }
Procedure StabilizeSymbols;
Var I,Iteration,PreviousCount:Integer; PreviousPC,PreviousObjPC:LongInt;
Begin
 Pass:=0; Iteration:=0;
 Repeat
  PreviousCount:=SymbolCount; PreviousPC:=PC; PreviousObjPC:=ObjPC;
  For I:=0 To SymbolCount-1 Do Begin
   PreviousSymbols[I].Value:=Symbols[I].Value;
   PreviousSymbols[I].Defined:=Symbols[I].Defined;
   PreviousSymbols[I].Relocatable:=Symbols[I].Relocatable;
   PreviousSymbols[I].Section:=Symbols[I].Section;
  End;
  AssembleOnePass; Inc(Iteration);
  PhaseStable:=(PreviousCount=SymbolCount) And (PreviousPC=PC) And
   (PreviousObjPC=ObjPC);
  For I:=0 To PreviousCount-1 Do
   If (PreviousSymbols[I].Value<>Symbols[I].Value) Or
      (PreviousSymbols[I].Defined<>Symbols[I].Defined) Or
      (PreviousSymbols[I].Relocatable<>Symbols[I].Relocatable) Or
      (PreviousSymbols[I].Section<>Symbols[I].Section) Then PhaseStable:=False;
 Until PhaseStable Or (Iteration>=MAX_SYMBOLS+2);
End;

Function SymbolTypeName(I:Integer):TString;
Begin
 If Symbols[I].External Then SymbolTypeName:='EXTERN'
 Else If Not Symbols[I].Defined Then SymbolTypeName:='UNDEF'
 Else If Symbols[I].Relocatable Then SymbolTypeName:='RELOC'
 Else SymbolTypeName:='ABS';
End;

Function SectionName(I:Integer):TString;
Begin
 Case Symbols[I].Section Of
  SEC_ABSOLUTE:SectionName:='ABS';
  SEC_RELOCATABLE:SectionName:='REL';
  SEC_DSECT:SectionName:='DSECT';
  SEC_EXTERNAL:SectionName:='EXTERN';
  Else SectionName:='UNDEF';
 End;
End;

Procedure WriteSymbolTable;
Var Order:Array[0..MAX_SYMBOLS-1] Of Integer;
    I,J,K,R:Integer; T:Integer; Attr:TString; HasRef:Boolean;
Begin
 If Not UseListing Then Exit;
 For I:=0 To SymbolCount-1 Do Order[I]:=I;
 For I:=1 To SymbolCount-1 Do Begin
  T:=Order[I]; J:=I-1;
  While (J>=0) And (Symbols[Order[J]].Name>Symbols[T].Name) Do Begin
   Order[J+1]:=Order[J]; Dec(J);
  End; Order[J+1]:=T;
 End;
 WriteLn(ListText,#12); WriteLn(ListText,'TABLE DES SYMBOLES (ordre alphabetique)');
 WriteLn(ListText,'NOM                              VALEUR TYPE    SECTION ATTRIBUTS  DEF  REFERENCES');
 WriteLn(ListText,'-------------------------------  ------ ------- ------- ---------- ---- ----------------');
 For J:=0 To SymbolCount-1 Do Begin
  I:=Order[J]; Attr:='';
  If Symbols[I].PublicSym Then Attr:=Attr+'EXPORT ';
  If Symbols[I].LocalSymbol Then Attr:=Attr+'LOCAL ';
  Write(ListText,Symbols[I].Name);
  For K:=Length(Symbols[I].Name) To 31 Do Write(ListText,' ');
  If Symbols[I].Defined And Not Symbols[I].External Then
   If (Symbols[I].Value>=0) And (Symbols[I].Value<=65535) Then
    Write(ListText,' $',Hex(Symbols[I].Value,4),' ')
   Else Write(ListText,' $',Hex(Symbols[I].Value,8),' ')
  Else Write(ListText,' ----  ');
  Write(ListText,SymbolTypeName(I));
  For K:=Length(SymbolTypeName(I)) To 7 Do Write(ListText,' ');
  Write(ListText,SectionName(I));
  For K:=Length(SectionName(I)) To 7 Do Write(ListText,' ');
  Write(ListText,Attr);
  For K:=Length(Attr) To 10 Do Write(ListText,' ');
  If Symbols[I].DefinedLine>0 Then Write(ListText,Symbols[I].DefinedLine:4)
  Else Write(ListText,'   -');
  Write(ListText,'  '); HasRef:=False;
  For R:=0 To ReferenceCount-1 Do If References[R].SymbolIndex=I Then Begin
   If HasRef Then Write(ListText,','); Write(ListText,References[R].SourceLine);
   HasRef:=True;
  End;
  If Not HasRef Then Write(ListText,'-'); WriteLn(ListText);
 End;
 WriteLn(ListText); WriteLn(ListText,'Symboles: ',SymbolCount,
  '   References: ',ReferenceCount,'   Erreurs: ',Errors);
End;

Procedure ValidateExternalSymbols;
Var I:Integer;
Begin
 For I:=0 To SymbolCount-1 Do Begin
  If PhaseStable And Symbols[I].Defined And
   ((PreviousSymbols[I].Value<>Symbols[I].Value) Or
    (PreviousSymbols[I].Defined<>Symbols[I].Defined) Or
    (PreviousSymbols[I].Section<>Symbols[I].Section)) Then
   Error('Erreur de phase pour le symbole: '+Symbols[I].Name);
  If Symbols[I].PublicSym And Not Symbols[I].Defined Then
   Error('Symbole ENTRY non defini: '+Symbols[I].Name)
  Else If Not Symbols[I].Defined Then Error('Symbole non defini: '+Symbols[I].Name);
 End;
End;

Procedure RemoveInvalidObject;
Var F:File; E:Integer;
Begin
 Assign(F,ObjName); Erase(F); E:=IOResult;
 If (E<>0) And (E<>2) And (E<>3) Then
  Error('Impossible de supprimer le fichier objet invalide: '+ObjName);
End;

Procedure Help;Begin
 WriteLn('EDASM ',VERSION,' - Cette commande permet de lancer un assembleur Apple EDASM compatible 6502.');
 WriteLn;
 WriteLn('Syntaxe: EDASM source [objet] [/L:listing] [/B] [/Q]');
 WriteLn;
 WriteLn('Directives: ORG OBJ EQU = DFB DB DW DA DDB DCL DS DFS HEX ASC DCI MSB');
 WriteLn('            DO ELSE FIN LST PAGE SKP SBTL DSECT DEND REL EXTRN ENTRY CHN END');
 WriteLn;
 WriteLn('DSECT [adr] / DEND  Definit une zone symbolique sans octets objet.');
 WriteLn('ORG adresse          Fixe l''adresse d''execution des instructions.');
 WriteLn('OBJ adresse          Fixe independamment leur adresse de stockage objet.');
 WriteLn('                     Les trous sont remplis de zero; tout chevauchement est une erreur.');
 WriteLn('REL [adr]            Produit directement un module objet EDASM relogeable.');
 WriteLn('                     Le fichier contient image, RLD et ESD au format EDASM.');
 WriteLn('                     Sur ProDOS: type $FE (REL), AUXTYPE=adresse ORG.');
 WriteLn('EXTRN nom,...        Declare des symboles fournis par un autre module.');
 WriteLn('ENTRY nom,...        Exporte des symboles definis dans ce module.');
 WriteLn('Labels .nom/@nom     Labels locaux rattaches au dernier label global.');
 WriteLn('Listing /L           Ajoute une table alphabetique: type, section,');
 WriteLn('                     attributs, definition et references croisees.');
 WriteLn('CHN fichier          Continue l''assemblage dans un autre source.');
 WriteLn('PAGE                 Commence une nouvelle page du listing.');
 WriteLn('SKP [n]              Insere n lignes blanches dans le listing.');
 WriteLn('SBTL texte           Change le sous-titre et commence une page.');
 WriteLn('CHR caractere        Choisit le caractere imprime par REP.');
 WriteLn('REP nombre           Imprime ce nombre de caracteres dans le listing.');
 WriteLn('DDB valeur,...       Ecrit des mots en ordre octet fort, octet faible.');
 WriteLn('DCL valeur,...       Ecrit des valeurs 32 bits, octet faible d''abord.');
 WriteLn('DS taille[,octet]    Reserve et remplit une zone (zero par defaut).');
 WriteLn('ASC delimiteur...    Ecrit une ou plusieurs chaines ASCII delimitees.');
 WriteLn('DCI delimiteur...    Comme ASC; inverse le bit 7 du dernier caractere.');
 WriteLn('/B                   Ajoute l''en-tete Apple DOS B: adresse et longueur.');
 WriteLn('                     Sans /B, une sortie absolue demeure un binaire brut.');
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
 Quiet:=False; AppleBinaryHeader:=False;
 For I:=1 To ParamCount Do Begin
  A:=ParamStr(I); U:=Up(A);
  If (U='/?') Or (U='-?') Then Help Else If Copy(U,1,3)='/L:' Then Begin
   ListName:=Copy(A,4,255); UseListing:=True;
  End Else If U='/Q' Then Quiet:=True Else If U='/B' Then AppleBinaryHeader:=True
  Else If (A<>'') And (A[1]='/') Then Begin
   WriteLn('Option inconnue: ',A); Halt(1);
  End Else If SrcName='' Then SrcName:=A Else If ObjName='' Then ObjName:=A Else
  Begin
   WriteLn('Argument surnumeraire: ',A); Halt(1);
  End;
 End; If ObjName='' Then ObjName:=BaseName(SrcName)+'.OBJ';
 If UseListing And (ListName='') Then ListName:=BaseName(SrcName)+'.LST';
End;

BEGIN
 ParseArgs; SymbolCount:=0; NextEsdNumber:=1; Errors:=0; Pass:=1; AssembleOnePass;
 If UseListing Then Begin
  Assign(ListText,ListName); Rewrite(ListText); If IOResult<>0 Then Begin
   WriteLn('EDASM: impossible de creer ',ListName); Halt(3);
  End;
 End;
 { Stabilise les etiquettes et les choix page-zero/absolu apres la passe
   initiale. Les references avant peuvent modifier la taille du code. }
 StabilizeSymbols;
 Errors:=0; RelocCount:=0; ReferenceCount:=0;
 ListPage:=0; ListRow:=0; PageLength:=60; Subtitle:='';
 InitObjectImage; Pass:=2; AssembleOnePass;
 If Not PhaseStable Then Error('Erreur de phase: les symboles ne se stabilisent pas');
 If RelMode And AppleBinaryHeader Then Error('/B incompatible avec un module REL');
 ValidateExternalSymbols;
 If Errors=0 Then WriteObjectFile;
 If Errors<>0 Then RemoveInvalidObject;
 If UseListing Then Begin
  WriteSymbolTable;
  Close(ListText);
 End;
 If Errors=0 Then Begin
  If Not Quiet Then If ObjectMax>=ObjectMin Then
   WriteLn('Assemblage termine: ',ObjName,' (',ObjectMax-ObjectMin+1,
   ' octets, objet $',Hex(ObjectMin,4),'-$',Hex(ObjectMax,4),').') Else
   WriteLn('Assemblage termine: ',ObjName,' (objet vide).');
  If Not Quiet And RelMode Then
   WriteLn('Attributs ProDOS requis: TYPE=$FE, AUXTYPE=$',Hex(ObjectMin,4),'.');
 End Else
 Begin
  WriteLn(Errors,' erreur(s); objet invalide.'); FreeObjectImage; Halt(4);
 End; FreeObjectImage;
END.
