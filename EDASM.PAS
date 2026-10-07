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
 MAX_STABILIZATION_PASSES=MAX_SYMBOLS+2;
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
 TExprValue=Record
  Value,FullValue:LongInt;
  Rel:Integer;
  ExternalIndex:Integer;
  Part:Byte;
 End;
 TReloc=Record
  Offset:LongInt;
  Kind:Byte;
  SymbolName:String[31];
  Aux:Byte;
 End;
 PInstructionState=^TInstructionState;
 TInstructionState=Record
  Next:PInstructionState;
  SourceLine:Integer;
  Address,ObjectAddress:LongInt;
  Mode,Size:Byte;
 End;

Var
 ListText:Text;
 SrcName,ObjName,ListName:TString;
 Symbols:Array[0..MAX_SYMBOLS-1] Of TSymbol;
 SymbolCount:Integer;
 PreviousSymbols:Array[0..MAX_SYMBOLS-1] Of TSymbolState;
 PhaseStable:Boolean;
 Instructions,InstructionCursor,LastInstruction:PInstructionState;
 InstructionsChanged:Boolean;
 ExpressionValue:TExprValue;
 ExpressionKnown:Boolean;
 ValueContext:TString;
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
                  (Pos(','+N+',',R3)>0) Or
                  (Pos(','+N+',',',OR,XOR,NOT,MOD,DIV,SHL,SHR,')>0);
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

Function Eval(S:TString; Var Known:Boolean):LongInt;
Var Position,Depth:Integer; Token:TString; Number:LongInt;
    ResultValue:TExprValue;

Procedure Fail(MessageText:TString);
Begin
 Known:=False;
 If Pass=2 Then Error(MessageText);
End;

Function EmptyValue:TExprValue;
Var R:TExprValue;
Begin
 FillChar(R,SizeOf(R),0); R.ExternalIndex:=-1; EmptyValue:=R;
End;

Function Digit(C:Char):Integer;
Begin
 C:=UpCase(C);
 If C In ['0'..'9'] Then Digit:=Ord(C)-Ord('0')
 Else If C In ['A'..'F'] Then Digit:=Ord(C)-Ord('A')+10
 Else Digit:=-1;
End;

Procedure NextToken;
Var Start,Code,D,J:Integer; C:Char; TextValue:TString;
Begin
 While (Position<=Length(S)) And (S[Position] In [' ',#9]) Do Inc(Position);
 Token:=''; Number:=0;
 If Position>Length(S) Then Exit;
 C:=S[Position]; Start:=Position; Inc(Position);
 If C='''' Then Begin
  Token:='#NUMBER';
  If Position>Length(S) Then Begin Fail('Caractere non termine'); Exit; End;
  C:=S[Position]; Inc(Position);
  If C='\' Then Begin
   If Position>Length(S) Then Begin Fail('Echappement incomplet'); Exit; End;
   C:=S[Position]; Inc(Position);
   Case C Of
    'n':Number:=10; 'r':Number:=13; 't':Number:=9; '0':Number:=0;
    '\','''','"':Number:=Ord(C);
    'x':Begin
     For J:=1 To 2 Do Begin
      D:=-1; If Position<=Length(S) Then D:=Digit(S[Position]);
      If D<0 Then Begin Fail('Echappement hexadecimal invalide'); D:=0; End;
      Number:=Number*16+D; Inc(Position);
     End;
    End;
    Else Fail('Echappement de caractere inconnu');
   End;
  End Else Number:=Ord(C);
  If (Position>Length(S)) Or (S[Position]<>'''') Then
   Fail('Un caractere entre apostrophes est attendu') Else Inc(Position);
  Exit;
 End;
 If C In ['0'..'9','$','%'] Then Begin
  While (Position<=Length(S)) And (S[Position] In ['0'..'9','A'..'Z','a'..'z']) Do Inc(Position);
  TextValue:=Copy(S,Start,Position-Start); Token:='#NUMBER';
  If C='%' Then Begin
   If Length(TextValue)=1 Then Fail('Nombre binaire vide');
   For J:=2 To Length(TextValue) Do Begin
    If Not (TextValue[J] In ['0','1']) Then Fail('Nombre binaire invalide');
    If J>33 Then Fail('Debordement de constante 32 bits');
    Number:=(Number Shl 1) Or Ord(TextValue[J]='1');
   End;
  End Else If TextValue='2147483648' Then Token:='#MINMAG'
  Else Begin
   Val(TextValue,Number,Code);
   If Code<>0 Then Begin Number:=0; Fail('Constante numerique invalide: '+TextValue); End;
  End;
  Exit;
 End;
 If C In ['A'..'Z','a'..'z','_','.','@'] Then Begin
  While (Position<=Length(S)) And
   (S[Position] In ['A'..'Z','a'..'z','0'..'9','_','.','@']) Do Inc(Position);
  Token:=Up(Copy(S,Start,Position-Start)); Exit;
 End;
 Token:=C;
 If (Position<=Length(S)) And (S[Position]=C) And (C In ['<','>']) Then Begin
  Token:=Token+C; Inc(Position);
 End;
End;

Function Checked(V:Extended):LongInt;
Begin
 If (V<-2147483648.0) Or (V>2147483647.0) Then Begin
  Fail('Debordement arithmetique 32 bits'); Checked:=0;
 End Else Checked:=Trunc(V);
End;

Function Priority(Op:TString):Integer;
Begin
 Priority:=0;
 If (Op='|') Or (Op='OR') Then Priority:=1
 Else If (Op='^') Or (Op='XOR') Then Priority:=2
 Else If (Op='&') Or (Op='AND') Then Priority:=3
 Else If (Op='<<') Or (Op='>>') Or (Op='SHL') Or (Op='SHR') Then Priority:=4
 Else If (Op='+') Or (Op='-') Then Priority:=5
 Else If (Op='*') Or (Op='/') Or (Op='DIV') Or (Op='MOD') Then Priority:=6;
End;

Function ParseExpression(MinPriority:Integer):TExprValue; Forward;

Function ParseUnary:TExprValue;
Var R:TExprValue; Op:TString; I:Integer;
Begin
 R:=EmptyValue; Inc(Depth);
 If Depth>64 Then Begin
  Fail('Expression trop imbriquee'); Token:=''; Dec(Depth); ParseUnary:=R; Exit;
 End;
 Op:=Token;
 If (Op='+') Or (Op='-') Or (Op='~') Or (Op='NOT') Or
    (Op='<') Or (Op='>') Then Begin
  NextToken;
  If (Op='-') And (Token='#MINMAG') Then Begin
   R.Value:=-2147483647-1; NextToken;
  End Else Begin
  R:=ParseUnary;
  If Op='-' Then Begin
   R.Value:=Checked(-1.0*R.Value); R.Rel:=-R.Rel;
   If (R.ExternalIndex>=0) Or (R.Part<>0) Then Fail('Negation relogeable invalide');
  End Else If (Op='~') Or (Op='NOT') Then Begin
   If (R.Rel<>0) Or (R.ExternalIndex>=0) Or (R.Part<>0) Then Fail('Operation logique relogeable invalide');
   R.Value:=Not R.Value;
  End Else If (Op='<') Or (Op='>') Then Begin
   If R.Part<>0 Then Fail('Extraction relogeable imbriquee invalide');
   R.FullValue:=R.Value;
   If (R.Rel<>0) Or (R.ExternalIndex>=0) Then
    If Op='>' Then R.Part:=1 Else R.Part:=2;
   If Op='>' Then R.Value:=R.Value And $FF Else R.Value:=(R.Value Shr 8) And $FF;
  End;
  End;
 End Else If Op='(' Then Begin
  NextToken; R:=ParseExpression(1);
  If Token<>')' Then Fail('Parenthese fermante attendue') Else NextToken;
 End Else If Op='#NUMBER' Then Begin R.Value:=Number; NextToken; End
 Else If Op='*' Then Begin
  R.Value:=PC; If RelMode And Not InDsect Then R.Rel:=1; NextToken;
 End Else If (Op<>'') And (Op[1] In ['A'..'Z','_','.','@']) And
  (Priority(Op)=0) Then Begin
  I:=FindSymbol(Op);
  If I<0 Then I:=GetOrCreateSymbol(Op);
  If I>=0 Then Begin
   AddCrossReference(I);
   If Symbols[I].Defined Then Begin
    R.Value:=Symbols[I].Value;
    If Symbols[I].External Then R.ExternalIndex:=I
    Else If Symbols[I].Relocatable Then R.Rel:=1;
   End Else Fail('Symbole non defini: '+Op);
  End Else Known:=False;
  NextToken;
 End Else Begin
  Fail('Operande attendu: '+Op); If Token<>'' Then NextToken;
 End;
 Dec(Depth); ParseUnary:=R;
End;

Function ParseExpression(MinPriority:Integer):TExprValue;
Var L,R:TExprValue; Op:TString; P,Sign:Integer;
Begin
 L:=ParseUnary;
 While (Priority(Token)>=MinPriority) And (Token<>'') Do Begin
  Op:=Token; P:=Priority(Op); NextToken; R:=ParseExpression(P+1);
  If (Op='+') Or (Op='-') Then Begin
   Sign:=1; If Op='-' Then Sign:=-1;
   If (L.Part<>0) Or (R.Part<>0) Then Fail('Calcul apres extraction relogeable interdit');
   If R.ExternalIndex>=0 Then Begin
    If (Op='-') And (L.ExternalIndex=R.ExternalIndex) Then L.ExternalIndex:=-1
    Else If (Op='+') And (L.ExternalIndex<0) Then L.ExternalIndex:=R.ExternalIndex
    Else Fail('Expression externe non relogeable');
   End;
   L.Rel:=L.Rel+Sign*R.Rel;
   L.Value:=Checked(1.0*L.Value+1.0*Sign*R.Value);
  End Else Begin
   If (L.Rel<>0) Or (R.Rel<>0) Or (L.ExternalIndex>=0) Or
      (R.ExternalIndex>=0) Or (L.Part<>0) Or (R.Part<>0) Then
    Fail('Operateur exigeant des valeurs absolues: '+Op);
   If Op='*' Then L.Value:=Checked(1.0*L.Value*R.Value)
   Else If (Op='/') Or (Op='DIV') Or (Op='MOD') Then Begin
    If R.Value=0 Then Begin Fail('Division par zero'); L.Value:=0; End
    Else If (L.Value=(-2147483647-1)) And (R.Value=-1) Then
     Begin Fail('Debordement arithmetique 32 bits'); L.Value:=0; End
    Else If Op='MOD' Then L.Value:=L.Value Mod R.Value Else L.Value:=L.Value Div R.Value;
   End Else If (Op='&') Or (Op='AND') Then L.Value:=L.Value And R.Value
   Else If (Op='|') Or (Op='OR') Then L.Value:=L.Value Or R.Value
   Else If (Op='^') Or (Op='XOR') Then L.Value:=L.Value Xor R.Value
   Else Begin
    If (R.Value<0) Or (R.Value>31) Then Fail('Decalage hors limite (0..31)')
    Else If (Op='<<') Or (Op='SHL') Then L.Value:=L.Value Shl R.Value
    Else L.Value:=L.Value Shr R.Value;
   End;
  End;
 End;
 ParseExpression:=L;
End;

Begin
 Known:=True; Position:=1; Depth:=0; NextToken;
 ResultValue:=ParseExpression(1);
 If Token<>'' Then Fail('Operateur inattendu: '+Token);
 If (ResultValue.Rel<0) Or (ResultValue.Rel>1) Or
  ((ResultValue.ExternalIndex>=0) And (ResultValue.Rel<>0)) Then
  Fail('Expression non relogeable');
 If (Pass=2) And (ResultValue.ExternalIndex>=0) And Not RelMode Then
  Fail('Symbole externe exigeant le mode REL');
 If ResultValue.Part=0 Then ResultValue.FullValue:=ResultValue.Value;
 ExpressionValue:=ResultValue;
 ExpressionKnown:=Known;
 If (Pass=2) And Not Known Then Error('Expression inconnue: '+S);
 Eval:=ResultValue.Value;
End;

Procedure AddReloc(Offset:LongInt; Kind:Byte);
Begin
 If (Pass<>2) Or Not RelMode Or InDsect Then Exit;
 { Reutiliser l'evaluation faite avant l'emission de l'opcode: * doit
   conserver l'adresse de l'instruction, pas celle de son operande. }
 If Not ExpressionKnown Or ((ExpressionValue.Rel=0) And (ExpressionValue.ExternalIndex<0)) Then Exit;
 If RelocCount>=MAX_RELOCS Then Begin Error('Table de relocation pleine'); Exit; End;
 If ExpressionValue.Part<>0 Then Begin
  If Kind<>1 Then Begin Error('Extraction relogeable exige un octet'); Exit; End;
  Kind:=ExpressionValue.Part;
 End;
 Relocs[RelocCount].Offset:=Offset; Relocs[RelocCount].Kind:=Kind;
 Relocs[RelocCount].SymbolName:='';
 If ExpressionValue.ExternalIndex>=0 Then
  Relocs[RelocCount].SymbolName:=Symbols[ExpressionValue.ExternalIndex].Name;
 Relocs[RelocCount].Aux:=0;
 If Kind=2 Then Relocs[RelocCount].Aux:=ExpressionValue.FullValue And $FF;
 Inc(RelocCount);
End;

Function EquSection(S:TString):Byte;
Var Known:Boolean;
Begin
 Eval(S,Known); EquSection:=SEC_ABSOLUTE;
 If (ExpressionValue.ExternalIndex>=0) Or (ExpressionValue.Part<>0) Then
  Error('EQU externe ou extraction relogeable interdit')
 Else If ExpressionValue.Rel=1 Then EquSection:=SEC_RELOCATABLE;
End;

Function CheckRange(V:LongInt; Bits:Byte; AddressOnly:Boolean):Boolean;
Var Minimum,Maximum:LongInt; Actual,Lo,Hi,Width:TString;
Begin
 CheckRange:=True; If Pass<>2 Then Exit;
 If Bits=8 Then Begin Minimum:=-128; Maximum:=255; End
 Else Begin Minimum:=-32768; Maximum:=65535; End;
 If AddressOnly Then Minimum:=0;
 If (V<Minimum) Or (V>Maximum) Then Begin
  Str(V,Actual); Str(Minimum,Lo); Str(Maximum,Hi); Str(Bits,Width);
  Error(ValueContext+': valeur '+Actual+' hors limite '+Width+
   ' bits (attendu '+Lo+'..'+Hi+')');
  CheckRange:=False;
 End;
End;

Procedure AdvanceInvalidValue(Count:LongInt);
Begin
 Inc(PC,Count); If Not InDsect Then Inc(ObjPC,Count);
End;

Procedure EmitByte(B:LongInt; Var Bytes:TString);
Begin
 If Not CheckRange(B,8,False) Then Begin AdvanceInvalidValue(1); Exit; End;
 If InDsect Then Begin Inc(PC); Exit; End;
 B:=B And $FF;
 Bytes:=Bytes+Chr(B); If Pass=2 Then StoreObjectByte(ObjPC,B);
 Inc(PC); Inc(ObjPC);
End;

Procedure EmitWord(V:LongInt; Var Bytes:TString);Begin
 If Not CheckRange(V,16,False) Then Begin AdvanceInvalidValue(2); Exit; End;
 EmitByte(V And $FF,Bytes); EmitByte((V Shr 8) And $FF,Bytes);
End;

Procedure EmitBigWord(V:LongInt; Var Bytes:TString);Begin
 If Not CheckRange(V,16,False) Then Begin AdvanceInvalidValue(2); Exit; End;
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
 HasLabel,Escaped:Boolean;
 Quote:Char;

Function Token:TString;
Var
 A:Integer;
Begin
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); A:=I;
 While (I<=Length(Line)) And Not(Line[I] In [' ',#9]) Do Inc(I); Token:=Copy(Line,A,I-A);
End;
Begin
 LabelName:=''; Op:=''; Arg:=''; Comment:=''; P:=0; Quote:=#0; Escaped:=False;
 For I:=1 To Length(Line) Do Begin
  If Escaped Then Escaped:=False
  Else If (Quote<>#0) And (Line[I]='\') Then Escaped:=True
  Else If (Line[I] In ['''','"']) Then Begin If Quote=#0 Then Quote:=Line[I] Else If Quote=Line[I] Then Quote:=#0; End
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
 P,I,Level:Integer;
 Quote,Ch:Char;
 Escaped:Boolean;
Begin
 { Conserver la casse des caracteres; supprimer uniquement les espaces
   autour des separateurs d'adressage, jamais ceux des operateurs mots. }
 Expr:=Trim(Arg); U:=Up(Expr); If U='' Then Begin
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
 P:=0; Level:=0; Quote:=#0; Escaped:=False;
 If U[1]='(' Then Begin
  For I:=1 To Length(U) Do Begin
   Ch:=U[I];
   If Escaped Then Escaped:=False
   Else If (Quote<>#0) And (Ch='\') Then Escaped:=True
   Else If Ch='''' Then Begin If Quote=#0 Then Quote:=Ch Else Quote:=#0; End
   Else If Quote=#0 Then Begin
    If Ch='(' Then Inc(Level) Else If Ch=')' Then Begin
     Dec(Level); If Level=0 Then Begin P:=I; Break; End;
    End;
   End;
  End;
  If P>0 Then Begin
   U:=Up(Trim(Copy(Expr,P+1,255)));
   If (U<>'') And (U[1]=',') And (Trim(Copy(U,2,255))='Y') Then Begin
    Mode:=AM_INY; Expr:=Copy(Expr,2,P-2); Size:=2; Exit;
   End;
   If P=Length(Expr) Then Begin
    U:=Trim(Copy(Expr,2,P-2)); I:=Length(U);
    If (I>0) And (UpCase(U[I])='X') Then Begin
     U:=Trim(Copy(U,1,I-1)); I:=Length(U);
     If (I>0) And (U[I]=',') Then Begin
      Mode:=AM_INX; Expr:=Trim(Copy(U,1,I-1)); Size:=2; Exit;
     End;
    End;
    If M='JMP' Then Begin
     Mode:=AM_IND; Expr:=Copy(Expr,2,P-2); Size:=3; Exit;
    End;
   End;
  End;
 End;
 U:=Up(Expr); P:=Length(U);
 If (P>0) And (U[P] In ['X','Y']) Then Begin
  Ch:=U[P]; U:=Trim(Copy(U,1,P-1)); P:=Length(U);
  If (P>0) And (U[P]=',') Then Begin
   Expr:=Trim(Copy(Expr,1,P-1));
   If Ch='X' Then Begin
    If Known And (V>=0) And (V<256) Then Begin
   Mode:=AM_ZPX; Size:=2;
    End Else Begin
   Mode:=AM_ABX; Size:=3;
    End;
   End Else If Known And (V>=0) And (V<256) Then Begin
   Mode:=AM_ZPY; Size:=2;
   End Else Begin
   Mode:=AM_ABY; Size:=3;
   End; Exit;
  End;
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

{ Compare chaque instruction, meme si deux changements de taille se
  compensent et laissent les symboles et l'adresse finale inchanges. }
Procedure TrackInstruction(Mode,Size:Byte);
Var P:PInstructionState; Changed:Boolean;
Begin
 P:=InstructionCursor; Changed:=P=Nil;
 If P=Nil Then Begin
  New(P); P^.Next:=Nil;
  If LastInstruction=Nil Then Instructions:=P Else LastInstruction^.Next:=P;
 End Else
  Changed:=(P^.SourceLine<>LineNo) Or (P^.Address<>PC) Or
   (P^.ObjectAddress<>ObjPC) Or (P^.Mode<>Mode) Or (P^.Size<>Size);
 If Changed Then Begin
  InstructionsChanged:=True;
  If Pass=2 Then Error('Erreur de phase: mode, taille ou adresse d''instruction modifie');
 End;
 P^.SourceLine:=LineNo; P^.Address:=PC; P^.ObjectAddress:=ObjPC;
 P^.Mode:=Mode; P^.Size:=Size;
 LastInstruction:=P; InstructionCursor:=P^.Next;
End;

Procedure FinishInstructionPass;
Var P:PInstructionState;
Begin
 If InstructionCursor<>Nil Then Begin
  InstructionsChanged:=True;
  If Pass=2 Then Error('Erreur de phase: nombre d''instructions modifie');
 End;
 While InstructionCursor<>Nil Do Begin
  P:=InstructionCursor; InstructionCursor:=P^.Next; Dispose(P);
 End;
 If LastInstruction=Nil Then Instructions:=Nil Else LastInstruction^.Next:=Nil;
End;

Function TakeExpression(Var S:TString):TString;
Var I,Level:Integer; Quoted,Escaped:Boolean; C:Char;
Begin
 Level:=0; Quoted:=False; Escaped:=False; I:=1;
 While I<=Length(S) Do Begin
  C:=S[I];
  If Escaped Then Escaped:=False
  Else If Quoted And (C='\') Then Escaped:=True
  Else If C='''' Then Quoted:=Not Quoted
  Else If Not Quoted Then Begin
   If C='(' Then Inc(Level) Else If C=')' Then Dec(Level)
   Else If (C=',') And (Level=0) Then Break;
  End;
  Inc(I);
 End;
 TakeExpression:=Trim(Copy(S,1,I-1)); Delete(S,1,I);
End;

Procedure ProcessLine(Source:TString);
Var
 Lab,M,A,C,E,Item,Bytes:TString;
 V,OldPC,FillValue:LongInt;
 Known,ValidValue:Boolean;
 Mode,Size:Byte;
 O,P,I,Code:Integer;
Begin
 Inc(LineNo); OldPC:=PC; ListObjAddress:=ObjPC; Bytes:='';
 If (Trim(Source)<>'') And (Trim(Source)[1]='*') Then Begin
  ListLine(PC,'',Source); Exit;
 End; ParseFields(Source,Lab,M,A,C); ValueContext:=M+' '+A;
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
  V:=Eval(A,Known); If Known Then Begin CheckRange(V,16,True); PC:=V; End Else Error('ORG invalide');
  If Known And Not ObjExplicit Then ObjPC:=V;
  ListObjAddress:=ObjPC;
  If FirstPC<0 Then FirstPC:=PC; ListLine(PC,'',Source); Exit;
 End;
 If M='OBJ' Then Begin
  If RelMode Then Begin Error('OBJ interdit dans un module REL'); ListLine(PC,'',Source); Exit; End;
  V:=Eval(A,Known); If Known Then Begin
   CheckRange(V,16,True);
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
   CheckRange(V,16,True);
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
   V:=Eval(A,Known); If Known Then Begin CheckRange(V,16,True); PC:=V; ObjPC:=V; End
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
   Item:=TakeExpression(A); ValueContext:=M+' '+Item; V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DFB inconnue: '+Item);
   AddReloc(ObjPC,1);
   EmitByte(V,Bytes);
  End;
 End
 Else If (M='DW') Or (M='DA') Then Begin
  A:=A+',';
  While A<>'' Do Begin
   Item:=TakeExpression(A); ValueContext:=M+' '+Item; V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DW inconnue: '+Item); AddReloc(ObjPC,3); EmitWord(V,Bytes);
  End;
 End
 Else If M='DDB' Then Begin
  A:=A+',';
  While A<>'' Do Begin
   Item:=TakeExpression(A); ValueContext:=M+' '+Item; V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DDB inconnue: '+Item); AddReloc(ObjPC,5); EmitBigWord(V,Bytes);
  End;
 End
 Else If M='DCL' Then Begin
  A:=A+',';
  While A<>'' Do Begin
   Item:=TakeExpression(A); V:=Eval(Item,Known);
   If Not Known Then Error('Valeur DCL inconnue: '+Item); AddReloc(ObjPC,4); EmitLong(V,Bytes);
  End;
 End
 Else If (M='DS') Or (M='DFS') Then Begin
  Item:=TakeExpression(A); C:=Trim(A); If C='' Then C:='0';
  V:=Eval(Item,Known);
  If Not Known Then Error(M+': taille inconnue: '+Item)
  Else If V<0 Then Begin
   Str(V,E); Error(M+': taille negative '+E+' (attendu 0..65536)');
  End Else If V>65536 Then Begin
   Str(V,E); Error(M+': taille '+E+' hors limite (attendu 0..65536)');
  End Else If (PC<0) Or (PC>65536-V) Or
   ((Not InDsect) And ((ObjPC<0) Or (ObjPC>65536-V))) Then
   Error(M+': reservation depassant l''espace d''adressage 16 bits')
  Else Begin
   ValueContext:=M+' remplissage '+C;
   FillValue:=Eval(C,Known);
   If Not Known Then Error(M+': octet de remplissage inconnu: '+C)
   Else If CheckRange(FillValue,8,True) Then Begin
    { V est LongInt: une reservation de 65536 octets doit aussi
      fonctionner avec les Integer 16 bits du mode Turbo Pascal. }
    While V>0 Do Begin EmitByte(FillValue,Bytes); Dec(V); End;
   End;
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
  If (Size>1) And (ExpressionValue.ExternalIndex>=0) Then Known:=False;
  DetermineMode(M,A,V,Known,Mode,Size,E);
  O:=Opcode(M,Mode); If (O<0) And (Mode In [AM_ZP,AM_ZPX,AM_ZPY]) Then Begin
   Inc(Mode,3); Inc(Size); O:=Opcode(M,Mode);
  End; If O<0 Then Error('Mode d''adressage illegal pour '+M) Else
  Begin
   TrackInstruction(Mode,Size);
   ValidValue:=True;
   If Size>1 Then Begin
    If Mode=AM_REL Then Begin
     ValidValue:=CheckRange(V,16,True);
     If (ExpressionValue.ExternalIndex>=0) Or (ExpressionValue.Part<>0) Then
      Error('Cible de branchement externe ou extraite interdite');
    End Else If Size=2 Then ValidValue:=CheckRange(V,8,Mode<>AM_IMM)
    Else ValidValue:=CheckRange(V,16,True);
   End;
   If Not ValidValue Then Begin
    AdvanceInvalidValue(Size); ListLine(OldPC,'',Source); Exit;
   End;
   EmitByte(O,Bytes); If Mode=AM_REL Then Begin
    V:=V-(PC+1); If Known And ((V<-128) Or (V>127)) Then Error('Branchement hors limite');
    EmitByte(V And $FF,Bytes);
   End Else If Size=2 Then Begin AddReloc(ObjPC,1); EmitByte(V,Bytes); End
   Else If Size=3 Then Begin AddReloc(ObjPC,3); EmitWord(V,Bytes); End;
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
 InstructionCursor:=Instructions; LastInstruction:=Nil; InstructionsChanged:=False;
 LineNo:=0; PC:=0; ObjPC:=0; FirstPC:=-1; LastPC:=0; EndSeen:=False;
 ObjExplicit:=False; ListObjAddress:=0;
 CondDepth:=0; Active:=True; MSBMode:=False; RelMode:=False; InDsect:=False;
 RepeatChar:='*'; CurrentScope:='';
 ChainRequested:=False; CurrentSource:=SrcName; ProcessSourceFile(SrcName,0);
 FinishInstructionPass;
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
   (PreviousObjPC=ObjPC) And Not InstructionsChanged;
  For I:=0 To PreviousCount-1 Do
   If (PreviousSymbols[I].Value<>Symbols[I].Value) Or
      (PreviousSymbols[I].Defined<>Symbols[I].Defined) Or
      (PreviousSymbols[I].Relocatable<>Symbols[I].Relocatable) Or
      (PreviousSymbols[I].Section<>Symbols[I].Section) Then PhaseStable:=False;
 Until PhaseStable Or (Iteration>=MAX_STABILIZATION_PASSES);
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
 WriteLn('Expressions: parentheses, + - * / DIV MOD, AND & XOR ^ OR |,');
 WriteLn('             SHL << SHR >>, signes unaires + - et NOT ~.');
 WriteLn('Priorites: unaires, produit, somme, decalages, AND, XOR, OR.');
 WriteLn('EDASM: >expr = octet faible; <expr = octet fort.');
 WriteLn('Caracteres: ''a'', ''\n'', ''\r'', ''\t'', ''\0'', ''\\'', ''\x41''.');
 WriteLn('Plages: donnees 8 bits -128..255, 16 bits -32768..65535;');
 WriteLn('        adresses non negatives; decalages logiques de 0 a 31.');
 WriteLn('JMP (expr) reste indirect; LDA (expr) utilise un calcul arithmetique.');
 WriteLn('Relocation: adresse +/- constante ou difference d''adresses;');
 WriteLn('            produit, division et operations logiques exigent des absolus.');
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
 Instructions:=Nil;
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
 If Not PhaseStable Then Error('Erreur de phase: limite de stabilisation atteinte (symboles ou instructions)');
 If RelMode And AppleBinaryHeader Then Error('/B incompatible avec un module REL');
 ValidateExternalSymbols;
 If Errors=0 Then WriteObjectFile;
 If Errors<>0 Then RemoveInvalidObject;
 If UseListing Then Begin
  WriteSymbolTable;
  Close(ListText);
 End;
 { Libere l'historique sans lancer une autre passe. }
 InstructionCursor:=Instructions; LastInstruction:=Nil; Pass:=0;
 FinishInstructionPass;
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
