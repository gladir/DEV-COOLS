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
 MAX_CONDITIONS=64;
 COND_SKIPPED=0;
 COND_UNKNOWN=1;
 COND_FALSE=2;
 COND_TRUE=3;
 {$IFDEF FPC}
 MAX_DATA_TEXT=16384;
 {$ELSE}
 MAX_DATA_TEXT=255;
 {$ENDIF}
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
 AM_ZPI=13;
 AM_AIX=14;
 SEC_UNDEF=0;
 SEC_ABSOLUTE=1;
 SEC_RELOCATABLE=2;
 SEC_DSECT=3;
 SEC_EXTERNAL=4;

Type
 TString=String;
 {$IFDEF FPC}
 TDataText=AnsiString;
 {$ELSE}
 TDataText=String;
 {$ENDIF}
 TObjectPage=Array[0..255] Of Byte;
 PObjectPage=^TObjectPage;
 TUsedPage=Array[0..255] Of Boolean;
 PUsedPage=^TUsedPage;
 TSymbol=Record
  Name:String[31];
 Value:LongInt;
 Defined,External,PublicSym,Relocatable,LocalSymbol,UndefinedReported,DefinedThisPass:Boolean;
 ZeroPage,ForwardReference,AddressRelative:Boolean;
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
  Rel,OriginRel:Integer;
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
 PListingDiagnostic=^TListingDiagnostic;
 TListingDiagnostic=Record
  Next:PListingDiagnostic;
  MessageText:TString;
 End;
 TConditionalFrame=Record
  ParentActive,ElseSeen:Boolean;
  State:Byte;
  OpenLine,ElseLine:Integer;
  OpenSource:TString;
 End;
 PConditionalTrace=^TConditionalTrace;
 TConditionalTrace=Record
  Next:PConditionalTrace;
  SourceLine:Integer;
  InitialState,PreviousState:Byte;
 End;
 PMacroFrame=^TMacroFrame;
 TMacroFrame=Record
  Args:Array[0..9] Of TString;
  Serial:Integer;
 End;
 PObjectSegment=^TObjectSegment;
 TObjectSegment=Record
  Next:PObjectSegment;
  Pages:Array[0..255] Of PObjectPage;
  Used:Array[0..255] Of PUsedPage;
  MinAddress,MaxAddress:LongInt;
  FileType:Byte;
 End;
 PInputName=^TInputName;
 TInputName=Record
  Next:PInputName;
  Name:TString;
 End;

Var
 ListText:Text;
 SrcName,ObjName,ListName:TString;
 DiskName,DiskTemplate,DosName:TString;
 DosSlot,DosDrive,DosVolume:Integer;
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
 Pass,LineNo,FileLine,Errors,NextEsdNumber:Integer;
 SourcePaths:Array[0..32] Of TString;
 PC,ObjPC,FirstPC,LastPC:LongInt;
 ObjectMin,ObjectMax,ListObjAddress:LongInt;
 ObjectPages:Array[0..255] Of PObjectPage;
 UsedPages:Array[0..255] Of PUsedPage;
 ObjExplicit:Boolean;
 ListingEnabled,UseListing,MSBMode,EndSeen,Quiet,AppleBinaryHeader:Boolean;
 CondStack:Array[0..MAX_CONDITIONS-1] Of TConditionalFrame;
 CondDepth:Integer;
 CondOverflow:LongInt;
 OverflowParentActive,ConditionEvaluation,ConditionsChanged:Boolean;
 Conditions,ConditionCursor,LastCondition:PConditionalTrace;
 Active:Boolean;
 RelMode,InDsect:Boolean;
 SavedPC:LongInt;
 CurrentSource,ChainName,Subtitle,CurrentScope:TString;
 ChainRequested:Boolean;
 ListPage,ListRow,PageLength:Integer;
 RepeatChar:Char;
 ListingTitle,ListingStamp:TString;
 ListingSection:Byte;
 ListingForce,ListingHeaderDirty,InSourceLine,SourceListed:Boolean;
 StrictSource:Boolean;
 DiagnosticHead,DiagnosticTail:PListingDiagnostic;
 ListingSource:TDataText;
 ListingAddress:LongInt;
 CmosEnabled,MacroEnabled,IncludeRequested,MacroRequested:Boolean;
 MacroLibrary,IncludeName,BuildDate,BuildTime:TString;
 PendingMacro:PMacroFrame;
 MacroSerial,IncludeLevel,SourceBufferSize,IncludeBufferSize:Integer;
 ListGen,ListUnasm,ListAsym,ListVsym,ListExp,ListSix,ListCycles,ListWarn:Boolean;
 CurrentCycles,WarningCount:Integer;
 ProdosType:Byte;
 InteractivePause:Boolean;
 InMacroSource:Boolean;
 FirstPassFailure:TString;
 ValueTable:Boolean;
 MultiObjects,EvalForward,OrgEvaluation,OutputSafe:Boolean;
 OrgCount,SegmentCount:Integer;
 SegmentOrigin:LongInt;
 SegmentType:Byte;
 Segments,LastSegment:PObjectSegment;
 Inputs:PInputName;
 InitialSlot,InitialDrive,InitialVolume,SourceSlot,SourceDrive,SourceVolume:Integer;
 DeviceRoots:Array[1..7,1..2] Of TString;
 DeviceVolumes:Array[1..7,1..2] Of Integer;

Function HostFileExists(Name:TString):Boolean; Forward;

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

Procedure WriteListingDiagnostic(S:TString); Forward;

Procedure Error(S:TString);
Var P:PListingDiagnostic;
Begin
 Inc(Errors); If Pass=2 Then Begin
  WriteLn('EDASM: ',CurrentSource,', ligne ',FileLine,': ',S);
  If UseListing Then Begin
   If InSourceLine Then Begin
    New(P); P^.Next:=Nil; P^.MessageText:=S;
    If DiagnosticHead=Nil Then DiagnosticHead:=P Else DiagnosticTail^.Next:=P;
    DiagnosticTail:=P;
   End Else WriteListingDiagnostic(S);
  End;
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
                  (Pos(','+N+',',',OR,XOR,NOT,MOD,DIV,SHL,SHR,DUP,TITL,TITLE,IFEQ,IFNE,IFLT,IFLE,IFGT,IFGE,')>0) Or
                  (Pos(','+N+',',',MACLIB,INCLUDE,X6502,DEF,REF,ZDEF,ZREF,ZXTRN,STR,DATE,TIME,IDNUM,FAIL,PAUSE,INTERP,SYS,SBUFSIZ,IBUFSIZ,BRA,INA,DEA,PHX,PHY,PLX,PLY,STZ,TRB,TSB,BLT,BGE,LSL,')>0);
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
 Symbols[I].External:=False; Symbols[I].PublicSym:=False; Symbols[I].UndefinedReported:=False;
  Symbols[I].Relocatable:=False; Symbols[I].EsdNumber:=0;
  Symbols[I].LocalSymbol:=WasLocal;
  Symbols[I].Section:=SEC_UNDEF; Symbols[I].DefinedLine:=0;
 End Else If Symbols[I].External Then Begin
  Error('Definition d''un symbole externe: '+N); Exit;
 End Else If (Symbols[I].DefinedLine<>0) And ((Pass=1) Or
  ((Pass=2) And (Symbols[I].DefinedLine<>LineNo))) Then Begin
  Error('Symbole defini deux fois: '+N); Exit;
 End;
 Symbols[I].Value:=V; Symbols[I].Defined:=Resolved; Symbols[I].DefinedThisPass:=True;
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

Procedure SaveObjectSegment;
Var P:PObjectSegment; I:Integer;
Begin
 If Pass<>2 Then Exit;
 If SegmentCount>=36 Then Begin Error('Plus de 36 objets ORG'); Exit; End;
 New(P); P^.Next:=Nil;
 For I:=0 To 255 Do Begin P^.Pages[I]:=ObjectPages[I]; P^.Used[I]:=UsedPages[I]; End;
 P^.MinAddress:=ObjectMin; If ObjectMax<0 Then P^.MinAddress:=SegmentOrigin;
 P^.MaxAddress:=ObjectMax; P^.FileType:=SegmentType;
 If LastSegment=Nil Then Segments:=P Else LastSegment^.Next:=P;
 LastSegment:=P; Inc(SegmentCount); InitObjectImage;
End;

Procedure StoreObjectByte(Address:LongInt; B:Byte); Forward;

Procedure MoveHistoricalOrigin(Address:LongInt);
Var I:LongInt;
Begin
 If Address<SegmentOrigin Then Begin Error('ORG relatif avant le debut de l''objet'); Exit; End;
 If Pass<>2 Then Exit;
 If Address<=ObjectMax Then Begin
  For I:=Address To ObjectMax Do
   If UsedPages[I Shr 8]<>Nil Then UsedPages[I Shr 8]^[I And $FF]:=False;
  ObjectMax:=Address-1;
 End Else For I:=ObjectMax+1 To Address-1 Do
  If I>=SegmentOrigin Then Begin
   { Les trous historiques etaient indetermines; le clone les initialise a zero. }
   StoreObjectByte(I,0);
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
 If (RelMode Or AppleBinaryHeader) And (ObjectMax-ObjectMin+1>65535) Then Begin
  Error('Longueur objet non representable sur 16 bits (REL ou /B)'); Exit;
 End;
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
     Flags:=$31; If Symbols[S].ZeroPage Then Flags:=$30;
     WriteFileByte(F,Flags,Failed); WriteFileByte(F,Symbols[S].EsdNumber,Failed);
     WriteFileByte(F,0,Failed);
    End Else Begin
     Flags:=$08; If Symbols[S].Relocatable Then Flags:=Flags Or $20;
     If Not Symbols[S].ZeroPage Then Flags:=Flags Or $01;
     WriteFileByte(F,Flags,Failed); WriteFileByte(F,Symbols[S].Value And $FF,Failed);
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
  Symbols[I].Defined:=False; Symbols[I].External:=False; Symbols[I].UndefinedReported:=False;
  Symbols[I].DefinedThisPass:=False; Symbols[I].ZeroPage:=False;
  Symbols[I].ForwardReference:=False; Symbols[I].AddressRelative:=False;
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
Var Position,Depth,SpaceAt:Integer; Token:TString; Number:LongInt; InChar:Boolean;
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
 If StrictSource And ((Number<0) Or (Number>65535) Or (Token='#MINMAG')) Then Fail('Constante hors limite 16 bits en mode /STRICT');
  Exit;
 End;
 If C In ['A'..'Z','a'..'z','_','.','@'] Then Begin
  While (Position<=Length(S)) And
   (S[Position] In ['A'..'Z','a'..'z','0'..'9','_','.','@']) Do Inc(Position);
  Token:=Up(Copy(S,Start,Position-Start)); Exit;
 End;
 Token:=C;
 If Position<=Length(S) Then Begin
  TextValue:=C+S[Position];
  If (TextValue='<<') Or (TextValue='>>') Or (TextValue='<=') Or
     (TextValue='>=') Or (TextValue='<>') Or (TextValue='!=') Or
     (TextValue='==') Or (TextValue='&&') Or (TextValue='||') Then Begin
   Token:=TextValue; Inc(Position);
  End;
 End;
End;

Function Checked(V:Extended):LongInt;
Begin
 If StrictSource Then Begin
  V:=V-Trunc(V/65536)*65536; Checked:=Trunc(V) And $FFFF; Exit;
 End;
 If (V<-2147483648.0) Or (V>2147483647.0) Then Begin
  Fail('Debordement arithmetique 32 bits'); Checked:=0;
 End Else Checked:=Trunc(V);
End;

Function Priority(Op:TString):Integer;
Begin
 If StrictSource Then Begin
  Priority:=0;
  If (Op='+') Or (Op='-') Or (Op='*') Or (Op='/') Or
     (Op='^') Or (Op='"') Or (Op='|') Or (Op='!') Then Priority:=1;
  Exit;
 End;
 Priority:=0;
 If Op='||' Then Priority:=1 Else If Op='&&' Then Priority:=2
 Else If (Op='=') Or (Op='==') Or (Op='<>') Or (Op='!=') Or
  (Op='<') Or (Op='<=') Or (Op='>') Or (Op='>=') Then Priority:=3
 Else If (Op='|') Or (Op='OR') Then Priority:=4
 Else If (Op='^') Or (Op='XOR') Then Priority:=5
 Else If (Op='&') Or (Op='AND') Then Priority:=6
 Else If (Op='<<') Or (Op='>>') Or (Op='SHL') Or (Op='SHR') Then Priority:=7
 Else If (Op='+') Or (Op='-') Then Priority:=8
 Else If (Op='*') Or (Op='/') Or (Op='DIV') Or (Op='MOD') Then Priority:=9;
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
 If (Op='+') Or (Op='-') Or (Op='~') Or (Op='NOT') Or (Op='!') Or
    (Op='<') Or (Op='>') Then Begin
  NextToken;
  If (Op='-') And (Token='#MINMAG') Then Begin
   R.Value:=-2147483647-1; NextToken;
  End Else Begin
  R:=ParseUnary;
  If Op='-' Then Begin
   R.Value:=Checked(-1.0*R.Value); R.Rel:=-R.Rel; R.OriginRel:=-R.OriginRel;
   If (R.ExternalIndex>=0) Or (R.Part<>0) Then Fail('Negation relogeable invalide');
  End Else If (Op='~') Or (Op='NOT') Or (Op='!') Then Begin
   If StrictSource Then Fail('Operateur unaire moderne interdit en mode /STRICT');
   If (R.Rel<>0) Or (R.ExternalIndex>=0) Or (R.Part<>0) Then Fail('Operation logique relogeable invalide');
   If Op='!' Then R.Value:=Ord(R.Value=0) Else R.Value:=Not R.Value;
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
  R.Value:=PC; R.OriginRel:=1; If RelMode And Not InDsect Then R.Rel:=1; NextToken;
 End Else If (Op<>'') And (Op[1] In ['A'..'Z','_','.','@']) And
  (Priority(Op)=0) Then Begin
  I:=FindSymbol(Op);
  If I<0 Then I:=GetOrCreateSymbol(Op);
  If I>=0 Then Begin
   AddCrossReference(I);
   If (Pass=1) And Not Symbols[I].Defined Then Symbols[I].ForwardReference:=True;
   If Symbols[I].ForwardReference Then EvalForward:=True;
   If Symbols[I].AddressRelative Then R.OriginRel:=1;
   If OrgEvaluation And Not Symbols[I].DefinedThisPass Then
    Fail('ORG exige des symboles definis avant usage: '+Op);
   If ConditionEvaluation And (Not Symbols[I].DefinedThisPass Or Not Symbols[I].Defined) Then
    Fail('Condition: symbole non defini avant cette ligne: '+Op)
   Else If ConditionEvaluation And Symbols[I].External Then
    Fail('Condition: symbole externe interdit: '+Op)
   Else If Symbols[I].Defined Then Begin
    R.Value:=Symbols[I].Value;
    If Symbols[I].External Then R.ExternalIndex:=I
    Else If Symbols[I].Relocatable Then R.Rel:=1;
   End Else Begin
    Fail('Symbole non defini: '+Op);
    If Pass=2 Then Symbols[I].UndefinedReported:=True;
   End;
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
   L.OriginRel:=L.OriginRel+Sign*R.OriginRel;
   L.Value:=Checked(1.0*L.Value+1.0*Sign*R.Value);
  End Else If (P=3) And Not StrictSource Then Begin
   If (L.Rel<>R.Rel) Or (L.ExternalIndex<>R.ExternalIndex) Or
      (L.Part<>0) Or (R.Part<>0) Then Fail('Comparaison de valeurs relogeables incompatibles');
   If (Op='=') Or (Op='==') Then L.Value:=Ord(L.Value=R.Value)
   Else If (Op='<>') Or (Op='!=') Then L.Value:=Ord(L.Value<>R.Value)
   Else If Op='<' Then L.Value:=Ord(L.Value<R.Value)
   Else If Op='<=' Then L.Value:=Ord(L.Value<=R.Value)
   Else If Op='>' Then L.Value:=Ord(L.Value>R.Value)
   Else L.Value:=Ord(L.Value>=R.Value);
   L.Rel:=0; L.OriginRel:=0; L.ExternalIndex:=-1; L.Part:=0;
  End Else Begin
   If (L.Rel<>0) Or (R.Rel<>0) Or (L.ExternalIndex>=0) Or
      (R.ExternalIndex>=0) Or (L.Part<>0) Or (R.Part<>0) Then
    Fail('Operateur exigeant des valeurs absolues: '+Op);
   L.OriginRel:=0;
   If StrictSource And ((Op='^') Or (Op='"')) Then L.Value:=L.Value And R.Value
   Else If StrictSource And (Op='!') Then L.Value:=L.Value Xor R.Value
   Else If Op='&&' Then L.Value:=Ord((L.Value<>0) And (R.Value<>0))
   Else If Op='||' Then L.Value:=Ord((L.Value<>0) Or (R.Value<>0))
   Else If Op='*' Then L.Value:=Checked(1.0*L.Value*R.Value)
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
 S:=Trim(S);
 If StrictSource Then Begin
  InChar:=False;
  For SpaceAt:=1 To Length(S) Do Begin
   If S[SpaceAt]='''' Then InChar:=Not InChar;
   If Not InChar And (S[SpaceAt] In [' ',#9]) Then Begin Delete(S,SpaceAt,255); Break; End;
  End;
 End;
 Known:=True; EvalForward:=False; Position:=1; Depth:=0; NextToken;
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
 If (ExpressionValue.ExternalIndex>=0) And (ExpressionValue.FullValue<>0) Then
  Error('Ajout a un externe non representable par le lieur Apple (utiliser un symbole exporte distinct)');
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

Function CmosOpcode(M:TString; Mode:Byte):Integer;
Const Names:Array[0..7] Of String[3]=('ORA','AND','EOR','ADC','STA','LDA','CMP','SBC');
Var I:Integer;
Begin
 CmosOpcode:=-1;
 If Mode=AM_ZPI Then For I:=0 To 7 Do If M=Names[I] Then CmosOpcode:=$12+I*$20;
 If (M='BRA') And (Mode=AM_REL) Then CmosOpcode:=$80;
 If ((M='INA') And (Mode=AM_IMP)) Or ((M='INC') And (Mode=AM_ACC)) Then CmosOpcode:=$1A;
 If ((M='DEA') And (Mode=AM_IMP)) Or ((M='DEC') And (Mode=AM_ACC)) Then CmosOpcode:=$3A;
 If Mode=AM_IMP Then Begin
  If M='PHX' Then CmosOpcode:=$DA Else If M='PHY' Then CmosOpcode:=$5A
  Else If M='PLX' Then CmosOpcode:=$FA Else If M='PLY' Then CmosOpcode:=$7A;
 End;
 If M='STZ' Then Case Mode Of AM_ZP:CmosOpcode:=$64; AM_ZPX:CmosOpcode:=$74;
  AM_ABS:CmosOpcode:=$9C; AM_ABX:CmosOpcode:=$9E; End;
 If M='TRB' Then Case Mode Of AM_ZP:CmosOpcode:=$14; AM_ABS:CmosOpcode:=$1C; End;
 If M='TSB' Then Case Mode Of AM_ZP:CmosOpcode:=$04; AM_ABS:CmosOpcode:=$0C; End;
 If M='BIT' Then Case Mode Of AM_IMM:CmosOpcode:=$89; AM_ZPX:CmosOpcode:=$34;
  AM_ABX:CmosOpcode:=$3C; End;
 If (M='JMP') And (Mode=AM_AIX) Then CmosOpcode:=$7C;
End;

Function Opcode(M:TString; Mode:Byte):Integer;
Const
 G1:Array[0..7] Of String[3]=('ORA','AND','EOR','ADC','STA','LDA','CMP','SBC');
 Base:Array[0..7] Of Byte=($00,$20,$40,$60,$80,$A0,$C0,$E0);
Var
 I,B:Integer;
Begin
 If M='BLT' Then M:='BCC' Else If M='BGE' Then M:='BCS' Else If M='LSL' Then M:='ASL';
 I:=CmosOpcode(M,Mode); If I>=0 Then Begin
  Opcode:=I; If Not CmosEnabled Then Opcode:=-1;
  Exit;
 End;
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

Function TrimData(S:TDataText):TDataText;
Var A,B:LongInt;
Begin
 A:=1; B:=Length(S);
 While (A<=B) And (S[A] In [' ',#9]) Do Inc(A);
 While (B>=A) And (S[B] In [' ',#9]) Do Dec(B);
 TrimData:=Copy(S,A,B-A+1);
End;

Function IsDataDirective(M:TString):Boolean;
Begin
 IsDataDirective:=(M='DFB') Or (M='DB') Or (M='DW') Or (M='DA') Or
  (M='DDB') Or (M='DCL') Or (M='ASC') Or (M='DCI') Or (M='STR');
End;

Function IsSourceOperation(M:TString):Boolean;
Const Directives=',ORG,OBJ,EQU,=,DS,DFS,HEX,MSB,DO,ELSE,FIN,IFEQ,IFNE,IFLT,IFLE,IFGT,IFGE,LST,PAGE,SKP,TITL,TITLE,SBTL,CHR,REP,DSECT,DEND,REL,EXTRN,ENTRY,CHN,END,';
 Extra=',MACLIB,INCLUDE,X6502,DEF,REF,ZDEF,ZREF,ZXTRN,DATE,TIME,IDNUM,FAIL,PAUSE,INTERP,SYS,SBUFSIZ,IBUFSIZ,';
Var Mode:Byte;
Begin
 M:=Up(M); IsSourceOperation:=False;
 If M='' Then Exit;
 If IsDataDirective(M) Or (Pos(','+M+',',Directives)>0) Or (Pos(','+M+',',Extra)>0) Then Begin
  IsSourceOperation:=True; Exit;
 End;
 For Mode:=AM_IMP To AM_AIX Do If (Opcode(M,Mode)>=0) Or (CmosOpcode(M,Mode)>=0) Then Begin
  IsSourceOperation:=True; Exit;
 End;
 If MacroEnabled Then IsSourceOperation:=HostFileExists(MacroLibrary+M);
End;

Function DataDelimiter(C:Char; M:TString):Boolean;
Begin
 DataDelimiter:=(C In ['''','"']) Or
  (((M='ASC') Or (M='DCI') Or (M='STR')) And (C In ['/','!','|',':']));
End;

Procedure ParseFields(Line:TDataText; Var LabelName,Op:TString;
                      Var Arg:TDataText; Var Comment:TString);
Var
 I,P:Integer;
 Escaped,ItemStart:Boolean;
 Quote:Char;

Function Token:TString;
Var
 A:Integer;
Begin
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); A:=I;
 While (I<=Length(Line)) And Not(Line[I] In [' ',#9,';']) Do Begin
  If Not StrictSource And (Line[I]=':') Then Begin Inc(I); Break; End;
  Inc(I);
 End;
 Token:=Copy(Line,A,I-A);
End;

Procedure ReadHead;
Var First:TString;
Begin
 I:=1; LabelName:=''; Op:=''; First:=Token;
 If Not StrictSource And (First<>'') And (First[Length(First)]=':') Then Begin
  LabelName:=Copy(First,1,Length(First)-1); Op:=Up(Token);
 End Else If Not StrictSource And IsSourceOperation(First) Then Op:=Up(First)
 Else If Not(Line[1] In [' ',#9]) Then Begin LabelName:=First; Op:=Up(Token); End
 Else Op:=Up(First);
End;

Begin
 LabelName:=''; Op:=''; Arg:=''; Comment:='';
 If TrimData(Line)='' Then Exit;
 If TrimData(Line)[1]=';' Then Exit;
 ReadHead;
 P:=0; Quote:=#0; Escaped:=False; ItemStart:=True;
 While I<=Length(Line) Do Begin
  If Escaped Then Escaped:=False
  Else If (Quote<>#0) And (Line[I]='\') Then Escaped:=True
  Else If Quote<>#0 Then Begin
   If Line[I]=Quote Then Begin
    If (I<Length(Line)) And (Line[I+1]=Quote) Then Inc(I) Else Quote:=#0;
   End;
  End Else If DataDelimiter(Line[I],Op) And
   ((Line[I] In ['''','"']) Or ItemStart) Then Begin Quote:=Line[I]; ItemStart:=False; End
  Else If Line[I]=';' Then Begin P:=I; Break; End
  Else If Line[I] In [',','('] Then ItemStart:=True
  Else If Not (Line[I] In [' ',#9]) Then ItemStart:=False;
  Inc(I);
 End;
 If P>0 Then Begin
  Comment:=Copy(Line,P,255); Delete(Line,P,Length(Line));
 End; If TrimData(Line)='' Then Begin LabelName:=''; Op:=''; Exit; End;
 ReadHead;
 While (I<=Length(Line)) And (Line[I] In [' ',#9]) Do Inc(I); Arg:=TrimData(Copy(Line,I,Length(Line)));
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
      Mode:=AM_INX; Size:=2;
      If M='JMP' Then Begin Mode:=AM_AIX; Size:=3; End;
      Expr:=Trim(Copy(U,1,I-1)); Exit;
     End;
    End;
    If M='JMP' Then Begin
     Mode:=AM_IND; Expr:=Copy(Expr,2,P-2); Size:=3; Exit;
    End;
    If CmosEnabled Then Begin Mode:=AM_ZPI; Expr:=Copy(Expr,2,P-2); Size:=2; Exit; End;
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

Function DecimalText(V:LongInt; Width:Integer; Pad:Char):TString;
Var S:TString;
Begin
 Str(V,S); While Length(S)<Width Do S:=Pad+S; DecimalText:=S;
End;

Procedure InitializeListing;
Var Y,M,D,W,H,N,S,C:Word;
Const Months='JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC';
Begin
 GetDate(Y,M,D,W); GetTime(H,N,S,C);
 If BuildDate='' Then Begin
 ListingStamp:=DecimalText(Y,4,'0')+'-'+DecimalText(M,2,'0')+'-'+
  DecimalText(D,2,'0')+' '+DecimalText(H,2,'0')+':'+
  DecimalText(N,2,'0')+':'+DecimalText(S,2,'0');
  BuildDate:=DecimalText(D,2,'0')+'-'+Copy(Months,(M-1)*3+1,3)+'-'+DecimalText(Y Mod 100,2,'0');
  BuildTime:=DecimalText(H,2,'0')+':'+DecimalText(N,2,'0')+' ';
 End;
 ListPage:=0; ListRow:=0; PageLength:=60; ListingSection:=0;
 ListingForce:=False; DiagnosticHead:=Nil; DiagnosticTail:=Nil;
 InSourceLine:=False;
End;

Function ListingActive:Boolean;
Begin
 ListingActive:=(Pass=2) And UseListing And (ListingEnabled Or ListingForce);
End;

Procedure NewListingPage;
Begin
 If Not ListingActive Then Exit;
 If ListPage>0 Then Write(ListText,#12);
 Inc(ListPage); ListingHeaderDirty:=False;
 WriteLn(ListText,'EDASM ',VERSION,'   PAGE ',ListPage,'   ',ListingStamp);
 WriteLn(ListText,'TITRE: ',ListingTitle);
 WriteLn(ListText,'SOUS-TITRE: ',Subtitle);
 If CurrentSource<>'' Then WriteLn(ListText,'SOURCE: ',CurrentSource)
 Else WriteLn(ListText,'SOURCE: ',SrcName);
 ListRow:=4;
 Case ListingSection Of
  0:WriteLn(ListText,' LINE EXEC OBJ  OBJECT       SOURCE');
  1:Begin
   If ValueTable Then WriteLn(ListText,'TABLE DES SYMBOLES (ordre des valeurs)')
   Else WriteLn(ListText,'TABLE DES SYMBOLES (ordre alphabetique)');
   WriteLn(ListText,'NOM                              VALEUR TYPE    SECTION ATTRIBUTS  DEF  REFERENCES');
   Inc(ListRow);
  End;
  2:Begin
   WriteLn(ListText,'TABLE DES REFERENCES CROISEES (ordre alphabetique)');
   WriteLn(ListText,'NOM                              DEF  REFERENCES (numeros de lignes source)');
   Inc(ListRow);
  End;
 End;
 WriteLn(ListText); Inc(ListRow,2);
End;

Procedure EnsureListingRows(Count:Integer);
Begin
 If Not ListingActive Then Exit;
 If (ListPage=0) Or ListingHeaderDirty Or (ListRow+Count>PageLength) Then NewListingPage;
End;

Procedure ListingRow(S:TString);
Begin
 If Not ListingActive Then Exit;
 EnsureListingRows(1); WriteLn(ListText,S); Inc(ListRow);
End;

Procedure SkipListing(Count:LongInt);
Begin
 If Not ListingActive Then Exit;
 While Count>0 Do Begin ListingRow(''); Dec(Count); End;
End;

Procedure RepeatListing(Count:Integer);
Var S:TString;
Begin
 If Not ListingActive Or (Count=0) Then Exit;
 { Une ShortString ne peut contenir 256 caracteres. }
 While Count>0 Do Begin
  S:=''; While (Count>0) And (Length(S)<120) Do Begin S:=S+RepeatChar; Dec(Count); End;
  ListingRow(S);
 End;
End;

Procedure WriteListingDiagnostic(S:TString);
Var WasForced:Boolean; Prefix:TString; I:Integer;
Begin
 If (Pass<>2) Or Not UseListing Then Exit;
 WasForced:=ListingForce; ListingForce:=True;
 If InSourceLine Then Prefix:='**** Ligne '+DecimalText(FileLine,0,' ') +': '
 Else Begin
  ListingRow('**** Fichier: '+CurrentSource);
  Prefix:='**** Bilan ligne '+DecimalText(FileLine,0,' ')+': ';
 End;
 I:=1;
 Repeat
  ListingRow(Prefix+Copy(S,I,120-Length(Prefix))); Inc(I,120-Length(Prefix));
 Until I>Length(S);
 ListingForce:=WasForced;
End;

Procedure FlushListingDiagnostics;
Var P:PListingDiagnostic;
Begin
 While DiagnosticHead<>Nil Do Begin
  P:=DiagnosticHead; DiagnosticHead:=P^.Next;
  WriteListingDiagnostic(P^.MessageText); Dispose(P);
 End;
 DiagnosticTail:=Nil;
End;

Procedure ListLine(Address:LongInt; Bytes:TString; Source:TDataText);
Var J,SourcePos:Integer; H,Prefix,TextPart:TString;
    Offset,ByteCount,AtObject:LongInt; WasForced,First:Boolean;
Begin
 If (Pass<>2) Or Not UseListing Then Exit;
 WasForced:=ListingForce;
 If DiagnosticHead<>Nil Then ListingForce:=True;
 If Not ListingActive Then Exit;
 SourceListed:=True;
 If (DiagnosticHead=Nil) And
    ((InMacroSource And Not ListExp) Or (Not Active And Not ListUnasm)) Then Exit;
 ByteCount:=0;
 If Length(Bytes)>0 Then ByteCount:=ObjPC-ListObjAddress;
 If ByteCount<0 Then ByteCount:=Length(Bytes);
 If Not ListGen And (ByteCount>4) Then ByteCount:=4;
 Offset:=0; SourcePos:=1; First:=True;
 Repeat
  H:='';
  For J:=0 To 3 Do Begin
   If Offset+J<ByteCount Then Begin
    AtObject:=ListObjAddress+Offset+J;
    If (AtObject>=0) And (AtObject<=65535) And
       (ObjectPages[AtObject Shr 8]<>Nil) And
       UsedPages[AtObject Shr 8]^[AtObject And $FF] Then
     H:=H+Hex(ObjectPages[AtObject Shr 8]^[AtObject And $FF],2)+' '
    Else H:=H+'-- ';
   End Else H:=H+'   ';
  End;
  If First Then Prefix:=DecimalText(LineNo,5,' ') Else Prefix:='     ';
  If First And ListCycles And (CurrentCycles>0) Then Prefix:='('+DecimalText(CurrentCycles,0,' ')+') '+Prefix;
  If First Or (Offset<ByteCount) Then
   Prefix:=Prefix+' '+Hex(Address+Offset,4)+' '+Hex(ListObjAddress+Offset,4)+' '+H
  Else Prefix:=Prefix+'                       ';
  TextPart:=Copy(Source,SourcePos,92); Inc(SourcePos,92);
  If First And (DiagnosticHead<>Nil) Then EnsureListingRows(2);
  ListingRow(Prefix+TextPart);
  Inc(Offset,4); First:=False;
 Until (Offset>=ByteCount) And (SourcePos>Length(Source));
 FlushListingDiagnostics;
 ListingForce:=WasForced;
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

Function TakeExpression(Var S:TDataText):TString;
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

Procedure EmitDataList(M:TString; TextValue:TDataText; Var Bytes:TString);
Var Visits,Emitted,LastAddress:LongInt; Width,LastByte:Byte; Failed:Boolean;
    StringData:TDataText; StringIndex,StringByte:Integer;

Procedure Bad(MessageText:TString);
Begin
 Error(M+': '+MessageText); Failed:=True;
End;

Function Evaluate(S:TDataText; Var Known:Boolean):LongInt;
Begin
 If Length(S)>255 Then Begin
  Bad('expression de plus de 255 caracteres'); Known:=False; Evaluate:=0;
 End Else Evaluate:=Eval(S,Known);
End;

Function HexDigit(C:Char):Integer;
Begin
 C:=UpCase(C);
 If C In ['0'..'9'] Then HexDigit:=Ord(C)-48
 Else If C In ['A'..'F'] Then HexDigit:=Ord(C)-Ord('A')+10
 Else HexDigit:=-1;
End;

Function DecodeStrings(S:TDataText; Var Decoded:TDataText):Boolean;
Var I,J,D,V:Integer; Delimiter,C:Char; Closed:Boolean;
Begin
 I:=1; Decoded:=''; DecodeStrings:=False;
 While I<=Length(S) Do Begin
  While (I<=Length(S)) And (S[I] In [' ',#9]) Do Inc(I);
  If I>Length(S) Then Break;
  If Not DataDelimiter(S[I],M) Then Exit;
  Delimiter:=S[I]; Inc(I); Closed:=False;
  While I<=Length(S) Do Begin
   C:=S[I]; Inc(I);
   If C=Delimiter Then Begin
    If (I<=Length(S)) And (S[I]=Delimiter) Then Inc(I)
    Else Begin Closed:=True; Break; End;
   End Else If C='\' Then Begin
    If I>Length(S) Then Begin Bad('echappement incomplet'); Break; End;
    C:=S[I]; Inc(I);
    If C=Delimiter Then Begin End
    Else Case C Of
     'n':C:=#10; 'r':C:=#13; 't':C:=#9; '0':C:=#0;
     '\','''','"':Begin End;
     'x':Begin
      V:=0;
      For J:=1 To 2 Do Begin
       D:=-1; If I<=Length(S) Then D:=HexDigit(S[I]);
       If D<0 Then Begin Bad('echappement hexadecimal invalide'); D:=0; End;
       V:=V*16+D; Inc(I);
      End;
      C:=Chr(V);
     End;
     Else Bad('echappement inconnu: \'+C);
    End;
   End;
   Decoded:=Decoded+C;
  End;
  If Not Closed Then Begin Bad('chaine non terminee'); DecodeStrings:=True; Exit; End;
 End;
 DecodeStrings:=True;
End;

Procedure EmitValue(V:LongInt; IsString,Enabled:Boolean);
Begin
 If Not Enabled Or Failed Then Exit;
 If (Emitted>65536-Width) Or (PC<0) Or (PC>65536-Width) Or
  ((Not InDsect) And ((ObjPC<0) Or (ObjPC>65536-Width))) Then Begin
  Bad('liste depassant l''espace d''adressage 16 bits'); Exit;
 End;
 If (M='ASC') Or (M='DCI') Then Begin
  If Not CheckRange(V,8,False) Then Begin AdvanceInvalidValue(1); Exit; End;
  If MSBMode Then V:=(V And $FF) Or $80;
 End;
 LastAddress:=ObjPC; LastByte:=V And $FF;
 If Not IsString Then Begin
  If M='DCI' Then Begin
   If (ExpressionValue.Rel<>0) Or (ExpressionValue.ExternalIndex>=0) Then Begin
    Bad('DCI exige des valeurs absolues'); Exit;
   End;
  End Else If M='DDB' Then AddReloc(ObjPC,5)
  Else If Width=2 Then AddReloc(ObjPC,3) Else AddReloc(ObjPC,Width);
 End;
 Case Width Of
  1:EmitByte(V,Bytes);
  2:If M='DDB' Then EmitBigWord(V,Bytes) Else EmitWord(V,Bytes);
  4:EmitLong(V,Bytes);
 End;
 Inc(Emitted,Width);
End;

Procedure ParseList(S:TDataText; Depth:Integer; Enabled:Boolean); Forward;

Procedure ParseItem(S:TDataText; Depth:Integer; Enabled:Boolean);
Var I,Level,DupAt:Integer; Quote,C:Char; Escaped,Known:Boolean;
    Decoded,Body,CountText:TDataText; Count,V:LongInt;
Begin
 S:=TrimData(S); Inc(Visits);
 If Visits>131072 Then Begin Bad('trop de repetitions imbriquees'); Exit; End;
 If S='' Then Begin Bad('element vide dans la liste'); Exit; End;
 ValueContext:=M+' '+S;
 Level:=0; DupAt:=0; Quote:=#0; Escaped:=False;
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If Escaped Then Escaped:=False
  Else If (Quote<>#0) And (C='\') Then Escaped:=True
  Else If Quote<>#0 Then Begin If C=Quote Then Quote:=#0; End
  Else If DataDelimiter(C,M) And ((C In ['''','"']) Or (I=1)) Then Quote:=C
  Else If C='(' Then Inc(Level) Else If C=')' Then Dec(Level)
  Else If (Level=0) And (I>1) And (S[I-1] In [' ',#9,')']) And
   (Up(Copy(S,I,3))='DUP') And
   ((I+3>Length(S)) Or (S[I+3] In [' ',#9,'('])) Then Begin DupAt:=I; Break; End;
 End;
 If DupAt>0 Then Begin
  CountText:=TrimData(Copy(S,1,DupAt-1)); Body:=TrimData(Copy(S,DupAt+3,Length(S)));
  If (Length(Body)<2) Or (Body[1]<>'(') Or (Body[Length(Body)]<>')') Then Begin
   Bad('DUP exige une liste entre parentheses'); Exit;
  End;
  Count:=Evaluate(CountText,Known);
  If Known And ((ExpressionValue.Rel<>0) Or (ExpressionValue.ExternalIndex>=0)) Then Begin
   Bad('compteur DUP non absolu'); Exit;
  End;
  If Known And ((Count<0) Or (Count>65536)) Then Begin Bad('compteur DUP hors limite 0..65536'); Exit; End;
  Body:=Copy(Body,2,Length(Body)-2);
  If Not Enabled Or Not Known Or (Count=0) Then ParseList(Body,Depth+1,False)
  Else While (Count>0) And Not Failed Do Begin
   ParseList(Body,Depth+1,Enabled); Dec(Count);
  End;
 End Else If DecodeStrings(S,Decoded) Then Begin
  If Failed Then Exit;
  For I:=1 To Length(Decoded) Do EmitValue(Ord(Decoded[I]),True,Enabled);
 End Else Begin
  V:=Evaluate(S,Known); EmitValue(V,False,Enabled);
 End;
End;

Procedure ParseList(S:TDataText; Depth:Integer; Enabled:Boolean);
Var I,Start,Level:Integer; Quote,C:Char; Escaped,ItemStart:Boolean;
Begin
 If Depth>32 Then Begin Bad('DUP trop imbrique'); Exit; End;
 Start:=1; I:=1; Level:=0; Quote:=#0; Escaped:=False; ItemStart:=True;
 While (I<=Length(S)) And Not Failed Do Begin
  C:=S[I];
  If Escaped Then Escaped:=False
  Else If (Quote<>#0) And (C='\') Then Escaped:=True
  Else If Quote<>#0 Then Begin
   If C=Quote Then Begin
    If (I<Length(S)) And (S[I+1]=Quote) Then Inc(I) Else Quote:=#0;
   End;
  End Else If DataDelimiter(C,M) And ((C In ['''','"']) Or ItemStart) Then Begin
   Quote:=C; ItemStart:=False;
  End Else If C='(' Then Begin Inc(Level); ItemStart:=True; End
  Else If C=')' Then Begin
   Dec(Level); If Level<0 Then Bad('parenthese fermante inattendue'); ItemStart:=False;
  End Else If C=',' Then Begin
   If Level=0 Then Begin ParseItem(Copy(S,Start,I-Start),Depth,Enabled); Start:=I+1; End;
   ItemStart:=True;
  End Else If Not (C In [' ',#9]) Then ItemStart:=False;
  Inc(I);
 End;
 If Failed Then Exit;
 If Quote<>#0 Then Bad('chaine non terminee')
 Else If Level<>0 Then Bad('parentheses non equilibrees')
 Else ParseItem(Copy(S,Start,Length(S)),Depth,Enabled);
End;

Begin
 Width:=1; If (M='DW') Or (M='DA') Or (M='DDB') Then Width:=2
 Else If M='DCL' Then Width:=4;
 Visits:=0; Emitted:=0; Failed:=False; LastAddress:=0; LastByte:=0;
 If M='STR' Then Begin
  If Not DecodeStrings(TextValue,StringData) Then Bad('chaine delimitee requise');
  If Length(StringData)>255 Then Bad('plus de 255 caracteres');
  If Not Failed Then Begin
   EmitByte(Length(StringData),Bytes);
   For StringIndex:=1 To Length(StringData) Do Begin
    StringByte:=Ord(StringData[StringIndex]) And $7F;
    If MSBMode Then StringByte:=StringByte Or $80;
    EmitByte(StringByte,Bytes);
   End;
  End;
  Exit;
 End;
 ParseList(TextValue,0,True);
 If (M='DCI') And (Emitted>0) And Not Failed Then Begin
  If (Pass=2) And Not InDsect And (ObjectPages[LastAddress Shr 8]<>Nil) Then
   ObjectPages[LastAddress Shr 8]^[LastAddress And $FF]:=LastByte Xor $80;
  If Emitted<=Length(Bytes) Then Bytes[Length(Bytes)]:=Chr(LastByte Xor $80);
 End;
End;

Function IsConditional(M:TString):Boolean;
Begin
 IsConditional:=(M='DO') Or (M='IFNE') Or (M='IFEQ') Or (M='IFLT') Or
  (M='IFLE') Or (M='IFGT') Or (M='IFGE');
End;

Function TrackCondition(State:Byte):Byte;
Var P:PConditionalTrace;
Begin
 P:=ConditionCursor;
 If P=Nil Then Begin
  New(P); P^.Next:=Nil; P^.SourceLine:=LineNo;
  P^.InitialState:=State; P^.PreviousState:=State;
  If LastCondition=Nil Then Conditions:=P Else LastCondition^.Next:=P;
  ConditionsChanged:=True;
  If Pass=2 Then Error('Erreur de phase: nouvelle condition');
 End Else Begin
  If (P^.PreviousState<>State) Or (P^.SourceLine<>LineNo) Then ConditionsChanged:=True;
  P^.PreviousState:=State;
 End;
 If Pass=2 Then Begin
  If P^.InitialState=COND_UNKNOWN Then
   Error('Condition inconnue lors de la premiere passe: definir ses symboles avant DO/IFxx')
  Else If (P^.InitialState<>State) Or (P^.SourceLine<>LineNo) Then
   Error('Erreur de phase: condition differente de la premiere passe');
 End;
 TrackCondition:=P^.InitialState;
 LastCondition:=P; ConditionCursor:=P^.Next;
End;

Procedure FinishConditionalPass;
Var P:PConditionalTrace;
Begin
 If ConditionCursor<>Nil Then Begin
  ConditionsChanged:=True;
  If Pass=2 Then Error('Erreur de phase: nombre de conditions modifie');
 End;
 While ConditionCursor<>Nil Do Begin
  P:=ConditionCursor; ConditionCursor:=P^.Next; Dispose(P);
 End;
 If LastCondition=Nil Then Conditions:=Nil Else LastCondition^.Next:=Nil;
End;

Function SourcePath(Name:TString):TString;
Begin
 Name:=Trim(Name);
 If (Length(Name)>=2) And (Name[1] In ['''','"']) And
    (Name[Length(Name)]=Name[1]) Then Name:=Copy(Name,2,Length(Name)-2);
 If Name<>'' Then
  If (Name[1]<>'\') And (Name[1]<>'/') And (Pos(':',Name)=0) Then
   Name:=SourceDirectory(CurrentSource)+Name;
 SourcePath:=Name;
End;

Function SourceSpecification(S:TDataText; Var Name:TString):Boolean;
Var I,Start,Count,N,Code,Slot,Drive,Volume:Integer; Q:Char;
    Fields:Array[0..3] Of TString; F:TString; WithDevice:Boolean;
Begin
 SourceSpecification:=False; Name:=''; Count:=0; Start:=1; Q:=#0;
 For I:=0 To 3 Do Fields[I]:='';
 S:=S+',';
 For I:=1 To Length(S) Do Begin
  If S[I] In ['''','"'] Then Begin
   If Q=#0 Then Q:=S[I] Else If Q=S[I] Then Q:=#0;
  End Else If (S[I]=',') And (Q=#0) Then Begin
   If Count>3 Then Begin Error('CHN/INCLUDE: trop de parametres'); Exit; End;
   Fields[Count]:=Trim(Copy(S,Start,I-Start)); Inc(Count); Start:=I+1;
  End;
 End;
 If (Q<>#0) Or (Count=0) Or (Fields[0]='') Then Begin Error('Nom de fichier CHN/INCLUDE absent ou mal delimite'); Exit; End;
 Slot:=SourceSlot; Drive:=SourceDrive; Volume:=SourceVolume; WithDevice:=False;
 For I:=1 To Count-1 Do If Fields[I]<>'' Then Begin
  F:=Up(Fields[I]); WithDevice:=True;
  If F[1] In ['S','D','V'] Then Begin
   If ((I=1) And (F[1]<>'S')) Or ((I=2) And (F[1]<>'D')) Or
      ((I=3) And (F[1]<>'V')) Then Begin Error('Ordre attendu: fichier,slot,drive,volume'); Exit; End;
   Delete(F,1,1);
  End;
  Val(F,N,Code); If Code<>0 Then Begin Error('Parametre de peripherique invalide: '+Fields[I]); Exit; End;
  Case I Of 1:Slot:=N; 2:Drive:=N; 3:Volume:=N; End;
 End;
 If (Slot<1) Or (Slot>7) Or (Drive<1) Or (Drive>2) Or (Volume<0) Or (Volume>254) Then Begin
  Error('CHN/INCLUDE: slot 1..7, drive 1..2, volume 0..254 requis'); Exit;
 End;
 Name:=Fields[0];
 If (Length(Name)>=2) And (Name[1] In ['''','"']) And (Name[Length(Name)]=Name[1]) Then Name:=Copy(Name,2,Length(Name)-2);
 If WithDevice Then Begin
  If (DeviceRoots[Slot,Drive]='') Or
     ((Volume<>0) And (DeviceVolumes[Slot,Drive]<>Volume)) Then Begin
   Error('Lecteur/volume non monte: utiliser /DRIVE:slot,drive,volume=repertoire'); Exit;
  End;
  If (Name[1]='\') Or (Name[1]='/') Or (Pos(':',Name)>0) Then Begin
   Error('Un nom relatif est requis avec les parametres de peripherique'); Exit;
  End;
  Name:=FExpand(DeviceRoots[Slot,Drive]+Name);
  SourceSlot:=Slot; SourceDrive:=Drive; SourceVolume:=DeviceVolumes[Slot,Drive];
 End Else Name:=SourcePath(Name);
 SourceSpecification:=True;
End;

Procedure PrepareMacro(M:TString; A:TDataText);
Var I,Start,Count,Level,J:Integer; Q,C:Char; Escaped:Boolean;
Begin
 If Not HostFileExists(MacroLibrary+M) Then Begin Error('Macro introuvable: '+M); Exit; End;
 If MacroSerial>=9999 Then Begin Error('Limite de 9999 appels de macros'); Exit; End;
 New(PendingMacro); For J:=0 To 9 Do PendingMacro^.Args[J]:='';
 Inc(MacroSerial); PendingMacro^.Serial:=MacroSerial;
 Count:=0; Start:=1; Level:=0; Q:=#0; Escaped:=False;
 If TrimData(A)<>'' Then For I:=1 To Length(A)+1 Do Begin
  If I>Length(A) Then C:=',' Else C:=A[I];
  If Escaped Then Escaped:=False
  Else If (Q<>#0) And (C='\') Then Escaped:=True
  Else If Q<>#0 Then Begin If C=Q Then Q:=#0; End
  Else If C In ['''','"'] Then Q:=C
  Else If C='(' Then Inc(Level)
  Else If C=')' Then Dec(Level)
  Else If (C=',') And (Level=0) Then Begin
   Inc(Count);
   If Count>9 Then Error('Macro: plus de neuf parametres')
   Else If I-Start>255 Then Error('Parametre de macro trop long')
   Else PendingMacro^.Args[Count]:=TrimData(Copy(A,Start,I-Start));
   Start:=I+1;
  End;
 End;
 If (Q<>#0) Or (Level<>0) Then Error('Macro: delimitateur non ferme');
 PendingMacro^.Args[0]:=DecimalText(Count,0,' ');
 IncludeName:=MacroLibrary+M; IncludeRequested:=True; MacroRequested:=True;
End;

Function ExpandMacro(S:TDataText; Frame:PMacroFrame):TDataText;
Var I,N:Integer; R:TDataText;
Begin
 R:=''; I:=1;
 While I<=Length(S) Do Begin
  If (S[I]='&') And (I<Length(S)) And (S[I+1] In ['0'..'9','X']) Then Begin
   Inc(I);
   If S[I]='X' Then R:=R+DecimalText(Frame^.Serial,0,' ')
   Else Begin N:=Ord(S[I])-Ord('0'); R:=R+Frame^.Args[N]; End;
  End Else R:=R+S[I];
  Inc(I);
  If Length(R)>MAX_DATA_TEXT Then Begin Error('Expansion de macro trop longue'); Break; End;
 End;
 ExpandMacro:=R;
End;

Procedure SetListingOptions(A:TDataText);
Var P:Integer; S:TString; Enabled:Boolean;
Begin
 If TrimData(A)='' Then Begin Error('LST: option absente'); Exit; End;
 A:=A+',';
 While A<>'' Do Begin
  P:=Pos(',',A); S:=Up(Trim(Copy(A,1,P-1))); Delete(A,1,P);
  If S='ON' Then ListingEnabled:=True Else If S='OFF' Then ListingEnabled:=False
  Else Begin
   Enabled:=Copy(S,1,2)<>'NO'; If Not Enabled Then Delete(S,1,2);
   If S='' Then Error('LST: option vide') Else Case S[1] Of
    'G':ListGen:=Enabled; 'U':ListUnasm:=Enabled; 'A':ListAsym:=Enabled;
    'V':ListVsym:=Enabled; 'E':ListExp:=Enabled; 'S':ListSix:=Enabled;
    'C':ListCycles:=Enabled; 'W':ListWarn:=Enabled;
    Else Error('LST: option inconnue '+S);
   End;
  End;
 End;
End;

Procedure Warning(S:TString);
Begin
 If Pass<>2 Then Exit;
 Inc(WarningCount);
 If ListWarn Then Begin
  WriteLn('EDASM: ',CurrentSource,', ligne ',FileLine,': avertissement: ',S);
  If UseListing Then WriteListingDiagnostic('Avertissement: '+S);
 End;
End;

Function InstructionCycles(M:TString; Mode:Byte):Integer;
Var N:Integer;
Begin
 N:=2;
 Case Mode Of
  AM_ZP:N:=3; AM_ZPX,AM_ZPY:N:=4; AM_ABS,AM_ABX,AM_ABY:N:=4;
  AM_IND:N:=5; AM_INX:N:=6; AM_INY,AM_ZPI:N:=5; AM_AIX:N:=6;
 End;
 If M='BRA' Then N:=3;
 If M='JMP' Then Begin
  If Mode=AM_ABS Then N:=3 Else If (Mode=AM_IND) And CmosEnabled Then N:=6;
 End;
 If M='STA' Then Begin
  If Mode In [AM_ABX,AM_ABY] Then N:=5 Else If Mode=AM_INY Then N:=6;
 End;
 If (M='STZ') And (Mode=AM_ABX) Then N:=5;
 If (M='ASL') Or (M='LSL') Or (M='LSR') Or (M='ROL') Or (M='ROR') Or
    (M='INC') Or (M='DEC') Or (M='TSB') Or (M='TRB') Then Begin
  If Mode In [AM_ZP,AM_ZPX,AM_ABS,AM_ABX] Then Inc(N,2);
  If (Mode=AM_ABX) And (Not CmosEnabled Or (M='INC') Or (M='DEC')) Then Inc(N);
 End;
 If (M='PHA') Or (M='PHP') Or (M='PHX') Or (M='PHY') Then N:=3;
 If (M='PLA') Or (M='PLP') Or (M='PLX') Or (M='PLY') Then N:=4;
 If (M='JSR') Or (M='RTS') Or (M='RTI') Then N:=6;
 If M='BRK' Then N:=7;
 InstructionCycles:=N;
End;

Procedure ProcessLine(Source:TDataText);
Var
 Lab,M,C,E,Item,Bytes:TString;
 A:TDataText;
 V,OldPC,FillValue:LongInt;
 Known,ValidValue,ZDeclaration:Boolean;
 Mode,Size:Byte;
 O,P,I,Code:Integer;
Begin
 Inc(LineNo); Inc(FileLine); OldPC:=PC; ListObjAddress:=ObjPC; Bytes:=''; CurrentCycles:=0;
 If (Trim(Source)<>'') And (Trim(Source)[1]='*') Then Begin
  ListLine(PC,'',Source); Exit;
 End; ParseFields(Source,Lab,M,A,C); ValueContext:=M+' '+A;
 ZDeclaration:=(M='ZDEF') Or (M='ZREF') Or (M='ZXTRN');
 If (M='DEF') Or (M='ZDEF') Then M:='ENTRY';
 If (M='REF') Or (M='ZREF') Or (M='ZXTRN') Then M:='EXTRN';
 If Not IsDataDirective(M) And (Length(A)>255) Then Begin
  Error('Operande de plus de 255 caracteres'); Exit;
 End;
 If CondOverflow>0 Then Begin
  If IsConditional(M) Then Inc(CondOverflow)
  Else If M='FIN' Then Begin
   Dec(CondOverflow); If CondOverflow=0 Then Active:=OverflowParentActive;
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If IsConditional(M) Then Begin
  If CondDepth>=MAX_CONDITIONS Then Begin
   Error('Imbrication conditionnelle excessive: limite '+DecimalText(MAX_CONDITIONS,0,' '));
   CondOverflow:=1; OverflowParentActive:=Active; Active:=False;
   ListLine(PC,'',Source); Exit;
  End;
  Size:=COND_SKIPPED;
  If Active Then Begin
   ConditionEvaluation:=True; V:=Eval(A,Known); ConditionEvaluation:=False;
   Size:=COND_UNKNOWN;
   If Known Then Begin
    ValidValue:=V<>0;
    If M='IFEQ' Then ValidValue:=V=0 Else If M='IFLT' Then ValidValue:=V<0
    Else If M='IFLE' Then ValidValue:=V<=0 Else If M='IFGT' Then ValidValue:=V>0
    Else If M='IFGE' Then ValidValue:=V>=0;
    If ValidValue Then Size:=COND_TRUE Else Size:=COND_FALSE;
   End;
  End;
  Size:=TrackCondition(Size);
  With CondStack[CondDepth] Do Begin
   ParentActive:=Active; ElseSeen:=False; State:=Size;
   OpenLine:=FileLine; ElseLine:=0; OpenSource:=CurrentSource;
  End;
  Inc(CondDepth); Active:=Active And (Size=COND_TRUE);
  ListLine(PC,'',Source); Exit;
 End;
 If M='ELSE' Then Begin
  If A<>'' Then Error('ELSE n''accepte aucun operande');
  If CondDepth=0 Then Error('ELSE sans DO/IFxx')
  Else With CondStack[CondDepth-1] Do Begin
   If ElseSeen Then Error('ELSE multiple: premier ELSE ligne '+DecimalText(ElseLine,0,' ')+
    ', bloc ouvert dans '+OpenSource+':'+DecimalText(OpenLine,0,' '))
   Else Begin
    ElseSeen:=True; ElseLine:=FileLine; Active:=ParentActive And (State=COND_FALSE);
   End;
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='FIN' Then Begin
  If A<>'' Then Error('FIN n''accepte aucun operande');
  If CondDepth=0 Then Error('FIN sans DO/IFxx') Else
  Begin
   Dec(CondDepth); Active:=CondStack[CondDepth].ParentActive;
  End; ListLine(PC,'',Source); Exit;
 End;
 If Not Active Then Begin
  ListLine(PC,'',Source); Exit;
 End;
 If StrictSource And (Lab<>'') And (IsSourceOperation(Lab) Or (Pos(':',Lab)>0)) Then Begin
  Error('Mode /STRICT: etiquette sans deux-points en colonne 1, operation indentee');
  ListLine(PC,'',Source); Exit;
 End;
 If M='X6502' Then Begin
  If A<>'' Then Error('X6502 sans operande'); CmosEnabled:=True;
  ListLine(PC,'',Source); Exit;
 End;
 If M='MACLIB' Then Begin
  If A='' Then Error('MACLIB: repertoire absent') Else Begin
   MacroLibrary:=SourcePath(A);
   If Not (MacroLibrary[Length(MacroLibrary)] In ['\','/']) Then MacroLibrary:=MacroLibrary+'\';
   MacroEnabled:=True;
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='INCLUDE' Then Begin
  If StrictSource And (IncludeLevel>0) Then Error('/STRICT: INCLUDE imbrique interdit')
  Else If SourceSpecification(A,IncludeName) Then Begin
   IncludeRequested:=True; MacroRequested:=False;
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If (Lab<>'') And (M<>'ENTRY') And (M<>'EXTRN') And
  Not IsLocalName(Lab) And Not IsReservedSymbol(Lab) Then
  CurrentScope:=Up(Lab);
 If (M='EQU') Or (M='=') Then Begin
  If Lab='' Then Begin Error(M+' exige une etiquette'); ListLine(PC,'',Source); Exit; End;
  V:=Eval(A,Known);
  DefineSymbol(Lab,V,Known); I:=FindSymbol(Lab); If I>=0 Then Begin
   If Known Then Symbols[I].Section:=EquSection(A)
   Else Symbols[I].Section:=SEC_UNDEF;
   Symbols[I].Relocatable:=Symbols[I].Section=SEC_RELOCATABLE;
   Symbols[I].AddressRelative:=ExpressionValue.OriginRel<>0;
  End; ListLine(V,'',Source); Exit;
 End;
 If (Lab<>'') And (M<>'ENTRY') And (M<>'EXTRN') Then Begin
  DefineSymbol(Lab,PC,True); I:=FindSymbol(Lab);
  If I>=0 Then Begin
   If InDsect Then Symbols[I].Section:=SEC_DSECT
   Else If RelMode Then Symbols[I].Section:=SEC_RELOCATABLE
   Else Symbols[I].Section:=SEC_ABSOLUTE;
   Symbols[I].Relocatable:=RelMode And Not InDsect;
   Symbols[I].AddressRelative:=Not InDsect;
  End;
 End; If M='' Then Begin
  ListLine(PC,'',Source); Exit;
 End;
 If M='ORG' Then Begin
  OrgEvaluation:=StrictSource Or MultiObjects; V:=Eval(A,Known); OrgEvaluation:=False;
  If Known Then Known:=CheckRange(V,16,True);
  If Known Then Begin
   If (MultiObjects Or StrictSource) And Not InDsect And Not RelMode And Not ObjExplicit Then Begin
    If ExpressionValue.OriginRel=0 Then Begin
     If (Pass=2) And (OrgCount=0) And (ObjectMax>=0) Then Error('Octets emis avant le premier ORG absolu');
     If (Pass=2) And (OrgCount>0) Then SaveObjectSegment;
     Inc(OrgCount); If OrgCount>36 Then Error('Plus de 36 ORG absolus');
     SegmentOrigin:=V; SegmentType:=ProdosType; ProdosType:=$06;
    End Else If OrgCount=0 Then Error('ORG relatif sans ORG absolu initial')
    Else MoveHistoricalOrigin(V);
   End Else If Not InDsect Then Inc(OrgCount);
   PC:=V;
  End Else Error('ORG invalide');
  If Known And Not ObjExplicit And Not InDsect Then ObjPC:=V;
  ListObjAddress:=ObjPC;
  If FirstPC<0 Then FirstPC:=PC; ListLine(PC,'',Source); Exit;
 End;
 If M='OBJ' Then Begin
  If SegmentCount>0 Then Begin Error('OBJ interdit apres une separation multi-ORG'); ListLine(PC,'',Source); Exit; End;
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
 If (M='DATE') Or (M='TIME') Or (M='IDNUM') Then Begin
  If A<>'' Then Error(M+' sans operande');
  E:=BuildTime; If M='DATE' Then E:=BuildDate;
  For I:=1 To Length(E) Do EmitByte(Ord(E[I]),Bytes);
  ListLine(OldPC,Bytes,Source); Exit;
 End;
 If (M='INTERP') Or (M='SYS') Then Begin
  If A<>'' Then Error(M+' sans operande');
  If RelMode Or (DiskName<>'') Or AppleBinaryHeader Then Error(M+' exige une sortie ProDOS absolue sans /DSK ni /B')
  Else ProdosType:=$FF;
  ListLine(PC,'',Source); Exit;
 End;
 If (M='SBUFSIZ') Or (M='IBUFSIZ') Then Begin
  V:=Eval(A,Known);
  If IncludeLevel>0 Then Error(M+' interdit dans INCLUDE ou macro')
  Else If Known Then Begin
   If V>256 Then V:=V Div 256;
   If (V<1) Or (V>127) Then Error(M+': taille de 1 a 127 pages requise')
   Else If M='SBUFSIZ' Then SourceBufferSize:=V*256 Else IncludeBufferSize:=V*256;
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If (M='FAIL') Or (M='PAUSE') Then Begin
  E:=A; P:=Pos(',',A);
  If M='FAIL' Then Begin
   If P=0 Then Begin Error('FAIL attend passe,chaine'); ListLine(PC,'',Source); Exit; End;
   E:=Trim(Copy(A,1,P-1));
  End;
  V:=Eval(E,Known);
  If Known And (V<>1) And (V<>2) And Not ((M='FAIL') And (V=3)) Then Error(M+': passe invalide');
  If Known And ((V=Pass) Or ((M='FAIL') And (V=3))) And (Pass<>0) Then Begin
   If M='FAIL' Then Begin
    E:=Trim(Copy(A,P+1,255));
    If (Length(E)<2) Or (E[1]<>E[Length(E)]) Then Error('FAIL: message delimite requis')
    Else E:=Copy(E,2,Length(E)-2);
    If Pass=1 Then FirstPassFailure:=CurrentSource+':'+DecimalText(FileLine,0,' ')+': '+E
    Else Error('FAIL: '+E);
   End Else If InteractivePause Then Begin
    WriteLn(CurrentSource,':',FileLine,': PRESS RETURN TO CONTINUE');
    If EOF(Input) Then Begin
     If Pass=1 Then FirstPassFailure:='PAUSE: entree standard fermee' Else Error('PAUSE: entree standard fermee');
    End Else ReadLn;
   End Else Warning('PAUSE ignoree en mode /BATCH');
  End;
  ListLine(PC,'',Source); Exit;
 End;
 If M='MSB' Then Begin
  MSBMode:=Up(A)<>'OFF'; ListLine(PC,'',Source); Exit;
 End;
 If M='LST' Then Begin
  If Up(Trim(A))='OFF' Then ListLine(PC,'',Source);
  SetListingOptions(A);
  If Up(Trim(A))<>'OFF' Then ListLine(PC,'',Source);
  Exit;
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
  If SegmentCount>0 Then Begin Error('REL interdit apres une separation multi-ORG'); ListLine(PC,'',Source); Exit; End;
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
     If ZDeclaration And (M='ENTRY') Then Begin
      If Not Symbols[I].DefinedThisPass Or Not Symbols[I].Defined Or
         (Symbols[I].Value<0) Or (Symbols[I].Value>255) Then
       Error('ZDEF exige une definition precedente en page zero: '+Item);
     End;
     If Symbols[I].External And (Symbols[I].ZeroPage<>ZDeclaration) Then
      Error('Declaration externe de largeur incompatible: '+Item);
     If ZDeclaration Then Symbols[I].ZeroPage:=True;
     If Symbols[I].EsdNumber=0 Then Begin
      If NextEsdNumber>255 Then Error('Plus de 255 symboles ENTRY/EXTRN') Else Begin
       Symbols[I].EsdNumber:=NextEsdNumber; Inc(NextEsdNumber);
      End;
     End;
     If M='EXTRN' Then Begin
      Symbols[I].External:=True; Symbols[I].Defined:=True; Symbols[I].Value:=0;
      Symbols[I].DefinedThisPass:=True;
      Symbols[I].Section:=SEC_EXTERNAL; Symbols[I].Relocatable:=True;
     End
     Else Begin
      Symbols[I].PublicSym:=True;
      If (Pass=2) And Not Symbols[I].Defined Then Begin
       Error('Symbole ENTRY non defini: '+Symbols[I].Name);
       Symbols[I].UndefinedReported:=True;
      End;
     End;
     AddCrossReference(I);
     End;
    End;
   End;
  End; ListLine(PC,'',Source); Exit;
 End;
 If M='CHN' Then Begin
  If SourceSpecification(A,ChainName) Then ChainRequested:=True;
  ListLine(PC,'',Source); Exit;
 End;
 If M='PAGE' Then Begin
  If Trim(A)<>'' Then Error('PAGE n''accepte pas d''operande');
  ListLine(PC,'',Source); NewListingPage; Exit;
 End;
 If M='SKP' Then Begin
  V:=1; Known:=True; If Trim(A)<>'' Then V:=Eval(A,Known);
  If Known And ((V<0) Or (V>65535)) Then Begin
   Error('SKP attend un nombre de lignes de 0 a 65535'); Known:=False;
  End;
  ListLine(PC,'',Source); If Known Then SkipListing(V); Exit;
 End;
 If (M='SBTL') Or (M='TITL') Or (M='TITLE') Then Begin
  E:=Trim(A);
  If (E<>'') And (E[1] In ['''','"']) Then Begin
   If (Length(E)<2) Or (E[Length(E)]<>E[1]) Then Error(M+': titre non termine')
   Else E:=Copy(E,2,Length(E)-2);
  End;
  ListLine(PC,'',Source);
  If M='SBTL' Then Subtitle:=E Else ListingTitle:=E;
  ListingHeaderDirty:=True; Exit;
 End;
 If M='CHR' Then Begin
  A:=Trim(A); Known:=True; V:=-1;
  If A='' Then Begin Error('Caractere CHR absent'); Known:=False; End
  Else If (Length(A)=3) And (A[1]='"') And (A[3]='"') Then V:=Ord(A[2])
  Else If (Length(A)=1) And Not(A[1] In ['0'..'9','''']) Then V:=Ord(A[1])
  Else V:=Eval(A,Known);
  If Known Then If (V<32) Or (V>255) Or (V=127) Then
   Error('CHR attend un caractere imprimable (32..255, sauf 127)')
  Else RepeatChar:=Chr(V);
  ListLine(PC,'',Source); Exit;
 End;
 If M='REP' Then Begin
  V:=Eval(A,Known);
  V:=V And $FF; If V=0 Then V:=256;
  ListLine(PC,'',Source); If Known Then RepeatListing(V); Exit;
 End;
 If IsDataDirective(M) Then EmitDataList(M,A,Bytes)
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
 Else
 Begin
  If MacroEnabled And Not IsReservedSymbol(M) Then Begin
   PrepareMacro(M,A); ListLine(PC,'',Source); Exit;
  End;
  { Extraire l'expression avant de l'evaluer: #, ,X et parentheses
    appartiennent au mode d'adressage, pas au nom du symbole. }
  DetermineMode(M,A,0,False,Mode,Size,E);
  V:=0; Known:=True;
  If Size>1 Then V:=Eval(E,Known);
  If StrictSource And (EvalForward Or (ExpressionValue.OriginRel<>0)) And (Size>1) Then Known:=False;
 If (Size>1) And (ExpressionValue.ExternalIndex>=0) Then
  Known:=Symbols[ExpressionValue.ExternalIndex].ZeroPage;
  DetermineMode(M,A,V,Known,Mode,Size,E);
  O:=Opcode(M,Mode); If (O<0) And (Mode In [AM_ZP,AM_ZPX,AM_ZPY]) Then Begin
   Inc(Mode,3); Inc(Size); O:=Opcode(M,Mode);
  End; If O<0 Then Error('Mode d''adressage illegal pour '+M) Else
  Begin
   TrackInstruction(Mode,Size);
   CurrentCycles:=InstructionCycles(M,Mode);
   If (M='JMP') And (Mode=AM_IND) And ((V And $FF)=$FF) And Not CmosEnabled Then
    Warning('JMP indirect sur une fin de page: comportement particulier du 6502');
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

Function DataContinues(S:TDataText; M:TString):Boolean;
Var I:Integer; Quote,C:Char; Escaped,ItemStart:Boolean;
Begin
 S:=TrimData(S); DataContinues:=False;
 Quote:=#0; Escaped:=False; ItemStart:=True; I:=1;
 While I<=Length(S) Do Begin
  C:=S[I];
  If Escaped Then Escaped:=False
  Else If (Quote<>#0) And (C='\') Then Escaped:=True
  Else If Quote<>#0 Then Begin
   If C=Quote Then Begin
    If (I<Length(S)) And (S[I+1]=Quote) Then Inc(I) Else Quote:=#0;
   End;
  End Else If DataDelimiter(C,M) And ((C In ['''','"']) Or ItemStart) Then Begin
   Quote:=C; ItemStart:=False;
  End Else If C In [',','('] Then ItemStart:=True
  Else If Not (C In [' ',#9]) Then Begin
   If (C='\') And (I=Length(S)) Then DataContinues:=True;
   ItemStart:=False;
  End;
  Inc(I);
 End;
End;

Procedure ProcessSourceFile(Name:TString; Depth:Integer);
Var
 F:Text;
 S,Args,More,Part:TDataText;
 E,Joined,I,CallerLine,LineSlot,LineDrive,LineVolume:Integer;
 NextName,Lab,M,Comment,DummyLab,DummyOp,CallerScope:TString;
 Missing,TooLong,IsMacroCall:Boolean;
 Frame:PMacroFrame;
 InputName:PInputName;
 ReadBuffer:Pointer;
 BufferSize:Word;
Begin
 Frame:=PendingMacro; PendingMacro:=Nil;
 Name:=FExpand(Name);
 InputName:=Inputs;
 While (InputName<>Nil) And (Up(InputName^.Name)<>Up(Name)) Do InputName:=InputName^.Next;
 If InputName=Nil Then Begin New(InputName); InputName^.Name:=Name; InputName^.Next:=Inputs; Inputs:=InputName; End;
 For I:=0 To Depth-1 Do If Up(SourcePaths[I])=Up(Name) Then Begin
  Error('Cycle CHN: fichier deja visite (CHN/INCLUDE/macro): '+Name);
  If Frame<>Nil Then Dispose(Frame); Exit;
 End;
 If Depth>32 Then Begin Error('Limite CHN de 33 fichiers depassee (INCLUDE/macros inclus)');
  If Frame<>Nil Then Dispose(Frame); Exit; End;
 Assign(F,Name); Reset(F); E:=IOResult; If E<>0 Then Begin
  Error('Impossible d''ouvrir le fichier source '+Name); If Frame<>Nil Then Dispose(Frame); Exit;
 End;
 If IncludeLevel>0 Then BufferSize:=IncludeBufferSize Else BufferSize:=SourceBufferSize;
 GetMem(ReadBuffer,BufferSize); SetTextBuf(F,ReadBuffer^,BufferSize);
 SourcePaths[Depth]:=Name; CurrentSource:=Name; FileLine:=0;
 If (Pass=2) And (ListPage>0) Then ListingHeaderDirty:=True;
 If (Pass=2) And UseListing Then Begin
  ListingRow('FICHIER: '+Name);
  ListingRow('Premiere ligne globale: '+DecimalText(LineNo+1,0,' ')+
   ' (LINE et references: numeros globaux; diagnostics: lignes du fichier)');
 End;
 ChainRequested:=False;
 While Not EOF(F) And Not EndSeen And Not ChainRequested Do Begin
  InMacroSource:=Frame<>Nil;
  ReadLn(F,S); Joined:=0; Missing:=False; TooLong:=Length(S)>MAX_DATA_TEXT;
  If Frame<>Nil Then S:=ExpandMacro(S,Frame);
  If TooLong Then S:=Copy(S,1,MAX_DATA_TEXT);
  ParseFields(S,Lab,M,Args,Comment);
  If IsDataDirective(M) Then Begin
   While DataContinues(Args,M) And Not TooLong Do Begin
    Args:=TrimData(Args); Delete(Args,Length(Args),1); Part:='';
    While (TrimData(Part)='') And Not EOF(F) Do Begin
     ReadLn(F,More); Inc(Joined); More:=TrimData(More);
     If Frame<>Nil Then More:=ExpandMacro(More,Frame);
     If (More<>'') And (More[1]<>'*') And (More[1]<>';') Then
      ParseFields(' '+M+' '+More,DummyLab,DummyOp,Part,Comment);
    End;
    If TrimData(Part)='' Then Begin Missing:=True; Break; End;
    If Length(Args)+Length(Part)+Length(Lab)+Length(M)+4>MAX_DATA_TEXT Then
     TooLong:=True
    Else Args:=Args+' '+Part;
   End;
   If Joined>0 Then S:=Lab+' '+M+' '+Args;
  End;
  ListingSource:=S; ListingAddress:=PC; SourceListed:=False; InSourceLine:=True;
  LineSlot:=SourceSlot; LineDrive:=SourceDrive; LineVolume:=SourceVolume;
  ProcessLine(S);
  If Missing Then Error('Continuation de donnees sans ligne suivante');
  If TooLong Then Error('Liste de donnees ou ligne source trop longue');
  If (DiagnosticHead<>Nil) And Not SourceListed Then ListLine(ListingAddress,'',ListingSource);
  FlushListingDiagnostics; InSourceLine:=False;
  Inc(LineNo,Joined); Inc(FileLine,Joined);
  If IncludeRequested And Not EndSeen Then Begin
   NextName:=IncludeName; IncludeRequested:=False; IsMacroCall:=MacroRequested;
   CallerLine:=FileLine; CallerScope:=CurrentScope;
   Inc(IncludeLevel); ProcessSourceFile(NextName,Depth+1); Dec(IncludeLevel);
   CurrentSource:=Name; FileLine:=CallerLine; InMacroSource:=Frame<>Nil;
   SourceSlot:=LineSlot; SourceDrive:=LineDrive; SourceVolume:=LineVolume;
   If IsMacroCall Then CurrentScope:=CallerScope;
   ListingHeaderDirty:=True;
   If (Pass=2) And UseListing Then ListingRow('REPRISE: '+Name+' ligne '+DecimalText(FileLine+1,0,' '));
  End;
 End;
 Close(F); FreeMem(ReadBuffer,BufferSize);
 If Frame<>Nil Then Dispose(Frame);
 If ChainRequested And Not EndSeen Then Begin
  NextName:=ChainName;
  If (NextName[1]<>'\') And (NextName[1]<>'/') And (Pos(':',NextName)=0) Then
   NextName:=SourceDirectory(Name)+NextName;
  ChainRequested:=False; ProcessSourceFile(NextName,Depth+1);
 End;
End;

Procedure AssembleOnePass;
Var I:Integer;
Begin
 OrgCount:=0; SegmentOrigin:=0; SegmentType:=$06; OrgEvaluation:=False;
 SourceSlot:=InitialSlot; SourceDrive:=InitialDrive; SourceVolume:=InitialVolume;
 CmosEnabled:=False; MacroEnabled:=False; MacroLibrary:=''; MacroSerial:=0;
 IncludeRequested:=False; MacroRequested:=False; PendingMacro:=Nil;
 IncludeLevel:=0; InMacroSource:=False;
 SourceBufferSize:=1024; IncludeBufferSize:=4096; ProdosType:=$06;
 ListGen:=Not StrictSource; ListUnasm:=True; ListAsym:=True; ListVsym:=False;
 ListExp:=True; ListSix:=False; ListCycles:=False; ListWarn:=True; WarningCount:=0;
 For I:=0 To SymbolCount-1 Do Symbols[I].DefinedThisPass:=False;
 ConditionCursor:=Conditions; LastCondition:=Nil; ConditionsChanged:=False;
 CondOverflow:=0; ConditionEvaluation:=False;
 InstructionCursor:=Instructions; LastInstruction:=Nil; InstructionsChanged:=False;
 LineNo:=0; FileLine:=0; PC:=0; ObjPC:=0; FirstPC:=-1; LastPC:=0; EndSeen:=False;
 ObjExplicit:=False; ListObjAddress:=0;
 CondDepth:=0; Active:=True; MSBMode:=False; RelMode:=False; InDsect:=False;
 ListingEnabled:=True; ListingTitle:=SrcName; Subtitle:=''; ListingHeaderDirty:=False;
 RepeatChar:='*'; CurrentScope:='';
 ChainRequested:=False; CurrentSource:=SrcName; ProcessSourceFile(SrcName,0);
 FinishInstructionPass;
 FinishConditionalPass;
 If StrictSource And (OrgCount=0) And Not RelMode And Not ObjExplicit Then Error('/STRICT: ORG requis pour une sortie objet');
 If InDsect Then Error('DSECT sans DEND');
 For I:=CondDepth-1 DownTo 0 Do
  Error('DO/IFxx sans FIN: bloc ouvert dans '+CondStack[I].OpenSource+':'+DecimalText(CondStack[I].OpenLine,0,' '));
 If CondOverflow>0 Then Error('Bloc conditionnel excedentaire sans FIN');
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
   (PreviousObjPC=ObjPC) And Not InstructionsChanged And Not ConditionsChanged;
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

Function PadRight(S:TString; Width:Integer):TString;
Begin
 While Length(S)<Width Do S:=S+' '; PadRight:=S;
End;

Procedure ListingReferences(SymbolIndex:Integer; Prefix:TString);
Var R:Integer; Row,Number:TString; HasRef:Boolean;
Begin
 Row:=Prefix; HasRef:=False;
 For R:=0 To ReferenceCount-1 Do If References[R].SymbolIndex=SymbolIndex Then Begin
  Number:=DecimalText(References[R].SourceLine,0,' ');
  If Length(Row)+Length(Number)+1>120 Then Begin
   ListingRow(Row); Row:=PadRight('',Length(Prefix)); HasRef:=False;
  End;
  If HasRef Then Row:=Row+',';
  Row:=Row+Number; HasRef:=True;
 End;
 If Not HasRef Then Row:=Row+'-'; ListingRow(Row);
End;

Procedure WriteSymbolTable;
Var Order:Array[0..MAX_SYMBOLS-1] Of Integer;
    I,J,K,Column:Integer; T:Integer; Attr,Row,Definition,Compact:TString;
Begin
 If Not UseListing Then Exit;
 ListingForce:=True;
 For K:=0 To 1 Do If ((K=0) And ListAsym) Or ((K=1) And ListVsym) Then Begin
 ValueTable:=K=1;
 For I:=0 To SymbolCount-1 Do Order[I]:=I;
 For I:=1 To SymbolCount-1 Do Begin
  T:=Order[I]; J:=I-1;
  While (J>=0) And
   (((Not ValueTable Or (Symbols[Order[J]].Value=Symbols[T].Value)) And
     (Symbols[Order[J]].Name>Symbols[T].Name)) Or
    (ValueTable And (Symbols[Order[J]].Value>Symbols[T].Value))) Do Begin
   Order[J+1]:=Order[J]; Dec(J);
  End; Order[J+1]:=T;
 End;
 ListingForce:=True; ListingSection:=1; NewListingPage;
 Compact:=''; Column:=0;
 For J:=0 To SymbolCount-1 Do Begin
  I:=Order[J]; Attr:='';
  If Symbols[I].PublicSym Then Attr:=Attr+'EXPORT ';
  If Symbols[I].LocalSymbol Then Attr:=Attr+'LOCAL ';
  If Symbols[I].ZeroPage Then Attr:=Attr+'ZP ';
  Row:=PadRight(Symbols[I].Name,32);
  If Symbols[I].Defined And Not Symbols[I].External Then
   If (Symbols[I].Value>=0) And (Symbols[I].Value<=65535) Then
    Row:=Row+' $'+Hex(Symbols[I].Value,4)+' '
   Else Row:=Row+' $'+Hex(Symbols[I].Value,8)+' '
  Else Row:=Row+' ----  ';
  Row:=Row+PadRight(SymbolTypeName(I),8)+PadRight(SectionName(I),8)+PadRight(Attr,11);
  Definition:='   -';
  If Symbols[I].DefinedLine>0 Then Definition:=DecimalText(Symbols[I].DefinedLine,4,' ');
  If ListSix Then Begin
   Compact:=Compact+PadRight(Copy(Symbols[I].Name,1,14),14)+' '+Hex(Symbols[I].Value,4)+' ';
   Inc(Column);
   If Column=6 Then Begin ListingRow(Compact); Compact:=''; Column:=0; End;
  End Else ListingReferences(I,Row+Definition+'  ');
 End;
 If Compact<>'' Then ListingRow(Compact);
 End;
 ValueTable:=False;
 { References toujours alphabetiques, independamment de VSYM. }
 For I:=0 To SymbolCount-1 Do Order[I]:=I;
 For I:=1 To SymbolCount-1 Do Begin
  T:=Order[I]; J:=I-1;
  While (J>=0) And (Symbols[Order[J]].Name>Symbols[T].Name) Do Begin
   Order[J+1]:=Order[J]; Dec(J);
  End; Order[J+1]:=T;
 End;
 ListingSection:=2; NewListingPage;
 For J:=0 To SymbolCount-1 Do Begin
  I:=Order[J]; Definition:='   -';
  If Symbols[I].DefinedLine>0 Then Definition:=DecimalText(Symbols[I].DefinedLine,4,' ');
  ListingReferences(I,PadRight(Symbols[I].Name,32)+Definition+'  ');
 End;
 ListingRow(''); ListingRow('Symboles: '+DecimalText(SymbolCount,0,' ')+
  '   References: '+DecimalText(ReferenceCount,0,' ')+'   Erreurs: '+DecimalText(Errors,0,' '));
 If WarningCount>0 Then ListingRow('Avertissements: '+DecimalText(WarningCount,0,' '));
 ListingForce:=False;
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
  If Symbols[I].PublicSym And Not Symbols[I].Defined And Not Symbols[I].UndefinedReported Then
   Error('Symbole ENTRY non defini: '+Symbols[I].Name)
  Else If Not Symbols[I].Defined And Not Symbols[I].UndefinedReported Then
   Error('Symbole non defini: '+Symbols[I].Name);
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
 WriteLn('Syntaxe: EDASM source [objet] [/L:listing] [/B] [/Q] [/STRICT|/MODERN]');
 WriteLn('         EDASM ASM SOURCE,OBJECT[,S6,D1,V254] [options]');
 WriteLn('/DSK:image.dsk       Cree une nouvelle image DOS 3.3 (140 Ko, ordre DOS).');
 WriteLn('/NAME:NOM APPLE      Nom du fichier B dans le catalogue (30 caracteres max).');
 WriteLn('/TEMPLATE:base.dsk   Copie une image DOS 3.3 et y ajoute l''objet.');
 WriteLn(' Sans modele: disque de donnees non amorcable; aucun DOS de demarrage inclus.');
 WriteLn(' Le modele et les fichiers existants ne sont jamais remplaces dans l''image.');
 WriteLn(' S1..7,D1..2 designent le lecteur virtuel /DSK; V0..254 fixe son volume.');
 WriteLn(' Source et CHN restent des fichiers de l''hote; pas d''editeur interactif.');
 WriteLn(' Objet disque: binaire absolu 1..65535 octets avec en-tete adresse/longueur.');
 WriteLn;
 WriteLn('Conditions: DO/IFNE IFEQ IFLT IFLE IFGT IFGE, ELSE unique, FIN; 64 niveaux.');
 WriteLn('Symboles conditionnels definis avant usage; choix figes a la premiere passe.');
 WriteLn('Condition inconnue: aucune branche active et erreur finale.');
 WriteLn('Comparaisons = == <> != < <= > >=; ! && || sans court-circuit.');
 WriteLn('Par defaut: instructions et directives reconnues meme en colonne 1.');
 WriteLn('Etiquettes: nom OP ... en colonne 1, ou nom: [OP ...] avec retrait libre.');
 WriteLn('/STRICT: format a colonnes, etiquette en colonne 1, operation indentee.');
 WriteLn('         Expressions 16 bits de gauche a droite; ^ AND, ! XOR, | OR.');
 WriteLn('         References avant en absolu; NOGEN par defaut; ORG requis.');
 WriteLn('         INCLUDE imbrique interdit; ORG absolus en fichiers distincts.');
 WriteLn('/MULTIOBJ: sorties ORG historiques avec analyse source moderne (aussi ASM).');
 WriteLn(' Dernier caractere du nom objet: cycle 0..9,A..Z; limite de 36 fichiers.');
 WriteLn(' ORG relatif: troncature arriere ou remplissage avant par zeros.');
 WriteLn('/DRIVE:s,d,v=repertoire Monte un repertoire hote comme lecteur source.');
 WriteLn(' CHN fichier[,slot[,drive[,volume]]] accepte aussi S6,D1,V254.');
 WriteLn('         Les deux-points ne sont pas admis; une etiquette peut etre seule.');
 WriteLn('/MODERN: reactive la reconnaissance automatique (mode par defaut).');
 WriteLn;
 WriteLn('Directives: ORG OBJ EQU = DFB DB DW DA DDB DCL DS DFS HEX ASC DCI MSB');
 WriteLn('            MACLIB INCLUDE X6502 DEF REF ZDEF ZREF ZXTRN STR');
 WriteLn('            DATE TIME IDNUM FAIL PAUSE SYS INTERP SBUFSIZ IBUFSIZ');
 WriteLn('MACLIB repertoire    Macros en fichiers, parametres &1..&9, &0 et &X.');
 WriteLn('INCLUDE fichier      Assemble le fichier puis reprend le source appelant.');
 WriteLn('X6502                Active les instructions NCR 65C02 du manuel EDASM.');
 WriteLn('DEF/REF              Synonymes de ENTRY/EXTRN; ZDEF/ZREF: page zero.');
 WriteLn('STR chaine           Chaine precedee de sa longueur (255 caracteres max).');
 WriteLn('DATE/TIME/IDNUM       DD-MMM-YY (9 octets), HH:MM espace (6 octets).');
 WriteLn('FAIL passe,/message/ Erreur programmee: 1, 2, ou 3 pour les deux passes.');
 WriteLn('PAUSE 1|2            Attend RETURN; /BATCH desactive cette attente.');
 WriteLn('SYS/INTERP           Objet brut SYS, attributs dans objet.prodos.');
 WriteLn('SBUFSIZ/IBUFSIZ      Taille de lecture des prochains fichiers: pages ou octets.');
 WriteLn('LST options          [NO]GEN, UNASM, ASYM, VSYM, EXP, SIXUP, CYC, WARN.');
 WriteLn(' CYC affiche les cycles de base, hors branche prise, page franchie et mode decimal.');
 WriteLn(' GEN reste actif par defaut pour conserver le listing moderne complet.');
 WriteLn('            DO ELSE FIN LST PAGE SKP TITL TITLE SBTL CHR REP');
 WriteLn('            DSECT DEND REL EXTRN ENTRY CHN END');
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
 WriteLn('                     Pages de 60 lignes avec date/heure et adresses EXEC/OBJ.');
 WriteLn('LST ON/OFF           Active/masque les lignes source et la mise en page.');
 WriteLn('                     Diagnostics et tables finales restent visibles.');
 WriteLn('CHN fichier          Continue l''assemblage dans un autre source.');
 WriteLn(' Chemins relatifs au source courant; CHN remplace la suite du fichier.');
 WriteLn(' Cycles interdits; 33 fichiers maximum. LINE/references: lignes globales,');
 WriteLn(' diagnostics: lignes physiques du fichier indique.');
 WriteLn('PAGE                 Commence une nouvelle page du listing.');
 WriteLn('SKP [n]              Insere n lignes blanches dans le listing.');
 WriteLn('SBTL texte           Change le sous-titre et commence une page.');
 WriteLn('TITL texte / TITLE   Change le titre de page (source par defaut).');
 WriteLn('CHR caractere        Choisit le caractere imprime par REP.');
 WriteLn('REP nombre           Imprime ce nombre de caracteres dans le listing.');
 WriteLn('                     Seul l''octet faible compte; zero signifie 256.');
 WriteLn('DDB valeur,...       Ecrit des mots en ordre octet fort, octet faible.');
 WriteLn('DCL valeur,...       Ecrit des valeurs 32 bits, octet faible d''abord.');
 WriteLn('DS taille[,octet]    Reserve et remplit une zone (zero par defaut).');
 WriteLn('ASC delimiteur...    Ecrit une ou plusieurs chaines ASCII delimitees.');
 WriteLn('DCI delimiteur...    Comme ASC; inverse le bit 7 du dernier caractere.');
 WriteLn('Listes de donnees: chaines entre apostrophes ou guillemets,');
 WriteLn(' expressions et n DUP(liste), y compris repetitions imbriquees.');
 WriteLn(' DW/DA/DDB: chaque caractere de chaine occupe un mot de 16 bits.');
 WriteLn(' ASC/DCI: delimiteurs supplementaires / ! | : et MSB ON/OFF.');
 WriteLn(' Echappements et delimiteurs doubles admis; virgules internes conservees.');
 WriteLn(' Terminer une ligne par \ pour continuer la liste sur la suivante.');
 WriteLn(' DCI inverse le bit 7 du dernier octet de la liste complete.');
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

{ Apple DOS 3.3, images 35 pistes x 16 secteurs, ordre DOS (.DSK/.DO).
  Le modele reste intact; aucune image existante n'est remplacee.
  Structures verifiees contre DiskArc/FS/DOS.cs et DOS_VTOC.cs (CiderPress2).
  Implementation independante; pas de code DOS de demarrage distribue. }

Function HostFileExists(Name:TString):Boolean;
Var R:SearchRec;
Begin FindFirst(Name,AnyFile,R); HostFileExists:=DosError=0; End;

Function ValidDosName(Name:TString):Boolean;
Var I:Integer;
Begin
 ValidDosName:=False;
 If (Length(Name)<1) Or (Length(Name)>30) Then Exit;
 If Not (Name[1] In ['A'..'Z']) Then Exit;
 For I:=1 To Length(Name) Do
  If (Ord(Name[I])<32) Or (Ord(Name[I])>126) Or (Name[I]=',') Then Exit;
 ValidDosName:=True;
End;

Procedure WriteDosDisk;
Const Vtoc=272; SectorCount=560;
Var
 Disk:Array[0..SectorCount-1] Of PObjectPage;
 Claimed:Array[0..SectorCount-1] Of Boolean;
 Allocated:Array[0..260] Of Integer;
 F:File;
 I,J,K,C,Entry,FreeCat,FreeEntry,T,L,P,N,NextC,NextL,DataCount,ListCount,E:Integer;
 Got:Word;
 ImageLength,Offset:LongInt;
 Failed,Opened,Created:Boolean;
 Name:TString;

Procedure Bad(S:TString);
Begin If Not Failed Then Error('DOS 3.3: '+S); Failed:=True; End;

Function Sector(T,S:Integer):Integer;
Begin
 Sector:=0;
 If (T<1) Or (T>34) Or (S<0) Or (S>15) Then Bad('pointeur piste/secteur invalide')
 Else Sector:=T*16+S;
End;

Function IsFree(N:Integer):Boolean;
Var B:Integer;
Begin
 B:=$38+(N Div 16)*4+1-(N Mod 16) Div 8;
 IsFree:=(Disk[Vtoc]^[B] And (1 Shl (N Mod 8)))<>0;
End;

Procedure Claim(N:Integer);
Begin
 If Failed Then Exit;
 If Claimed[N] Then Bad('cycle ou secteurs partages dans le modele')
 Else If IsFree(N) Then Bad('secteur utilise marque libre dans le VTOC')
 Else Claimed[N]:=True;
End;

Procedure MarkUsed(N:Integer);
Var B:Integer;
Begin
 B:=$38+(N Div 16)*4+1-(N Mod 16) Div 8;
 Disk[Vtoc]^[B]:=Disk[Vtoc]^[B] And Not (1 Shl (N Mod 8));
End;

Begin
 Failed:=False; Opened:=False; Created:=False;
 FillChar(Disk,SizeOf(Disk),0); FillChar(Claimed,SizeOf(Claimed),0);
 If RelMode Then Begin Error('/DSK exige un objet absolu (REL non pris en charge)'); Exit; End;
 ImageLength:=0; If ObjectMax>=ObjectMin Then ImageLength:=ObjectMax-ObjectMin+1;
 If (ImageLength=0) Or (ImageLength>65535) Then Begin
  Error('/DSK exige entre 1 et 65535 octets objet'); Exit;
 End;
 For I:=0 To SectorCount-1 Do Begin New(Disk[I]); FillChar(Disk[I]^,256,0); End;
 If DiskTemplate<>'' Then Begin
  Assign(F,DiskTemplate); Reset(F,1); E:=IOResult;
  If E<>0 Then Bad('impossible d''ouvrir le modele') Else Begin
   Opened:=True;
   If FileSize(F)<>143360 Then Bad('modele attendu: image DOS 3.3 de 143360 octets');
   E:=IOResult; If E<>0 Then Bad('lecture de la taille du modele impossible');
   If Not Failed Then For I:=0 To SectorCount-1 Do Begin
    BlockRead(F,Disk[I]^,256,Got); E:=IOResult;
    If (E<>0) Or (Got<>256) Then Bad('lecture du modele incomplete');
   End;
   Close(F); E:=IOResult; Opened:=False;
   If E<>0 Then Bad('fermeture du modele impossible');
  End;
 End Else Begin
  Disk[Vtoc]^[1]:=17; Disk[Vtoc]^[2]:=15; Disk[Vtoc]^[3]:=3;
  Disk[Vtoc]^[$27]:=122; Disk[Vtoc]^[$30]:=18; Disk[Vtoc]^[$31]:=1;
  Disk[Vtoc]^[$34]:=35; Disk[Vtoc]^[$35]:=16; Disk[Vtoc]^[$37]:=1;
  For I:=3 To 34 Do If I<>17 Then Begin
   Disk[Vtoc]^[$38+I*4]:=255; Disk[Vtoc]^[$39+I*4]:=255;
  End;
  For I:=15 DownTo 2 Do Begin
   Disk[17*16+I]^[1]:=17; Disk[17*16+I]^[2]:=I-1;
  End;
 End;
 If Not Failed Then Begin
  If (Disk[Vtoc]^[$27]<>122) Or (Disk[Vtoc]^[$34]<>35) Or
     (Disk[Vtoc]^[$35]<>16) Or (Disk[Vtoc]^[$36]<>0) Or
     (Disk[Vtoc]^[$37]<>1) Then Bad('VTOC DOS 3.3 invalide');
 End;
 FreeCat:=-1; FreeEntry:=-1;
 If Not Failed Then Begin
  Claim(Vtoc); C:=Sector(Disk[Vtoc]^[1],Disk[Vtoc]^[2]);
  While (C<>0) And Not Failed Do Begin
   Claim(C);
   For Entry:=0 To 6 Do If Not Failed Then Begin
    P:=$0B+Entry*35; T:=Disk[C]^[P];
    If (T=0) Or (T=255) Then Begin
     If FreeCat<0 Then Begin FreeCat:=C; FreeEntry:=P; End;
    End Else Begin
     Name:=''; For J:=0 To 29 Do Name:=Name+Chr(Disk[C]^[P+3+J] And $7F);
     If Up(Trim(Name))=DosName Then Bad('nom deja present dans le modele: '+DosName);
     L:=Sector(T,Disk[C]^[P+1]);
     While (L<>0) And Not Failed Do Begin
      Claim(L);
      For J:=0 To 121 Do If Not Failed Then Begin
       T:=Disk[L]^[$0C+J*2]; K:=Disk[L]^[$0D+J*2];
       If T<>0 Then Claim(Sector(T,K)) Else If K<>0 Then Bad('reference de donnees invalide');
      End;
      NextL:=0;
      If Disk[L]^[1]<>0 Then NextL:=Sector(Disk[L]^[1],Disk[L]^[2]);
      L:=NextL;
     End;
    End;
   End;
   NextC:=0; If Disk[C]^[1]<>0 Then NextC:=Sector(Disk[C]^[1],Disk[C]^[2]);
   C:=NextC;
  End;
  If FreeCat<0 Then Bad('catalogue plein');
 End;
 DataCount:=(ImageLength+4+255) Div 256; ListCount:=(DataCount+121) Div 122;
 If Not Failed Then Begin
  N:=0;
  For I:=48 To SectorCount-1 Do
   If (I Div 16<>17) And IsFree(I) And (N<DataCount+ListCount) Then Begin
    Allocated[N]:=I; Inc(N); MarkUsed(I); FillChar(Disk[I]^,256,0);
   End;
  If N<DataCount+ListCount Then Bad('espace disque insuffisant');
 End;
 If Not Failed Then Begin
  For I:=0 To ListCount-1 Do Begin
   L:=Allocated[I];
   If I+1<ListCount Then Begin
    Disk[L]^[1]:=Allocated[I+1] Div 16; Disk[L]^[2]:=Allocated[I+1] Mod 16;
   End;
   Disk[L]^[5]:=(I*122) And 255; Disk[L]^[6]:=(I*122) Shr 8;
  End;
  For I:=0 To DataCount-1 Do Begin
   L:=Allocated[I Div 122]; P:=$0C+(I Mod 122)*2; N:=Allocated[ListCount+I];
   Disk[L]^[P]:=N Div 16; Disk[L]^[P+1]:=N Mod 16;
   For J:=0 To 255 Do Begin
    Offset:=LongInt(I)*256+J;
    Case Offset Of
     0:Disk[N]^[J]:=ObjectMin And 255;
     1:Disk[N]^[J]:=ObjectMin Shr 8;
     2:Disk[N]^[J]:=ImageLength And 255;
     3:Disk[N]^[J]:=ImageLength Shr 8;
     Else If Offset<ImageLength+4 Then Disk[N]^[J]:=ObjectByte(ObjectMin+Offset-4);
    End;
   End;
  End;
  P:=FreeEntry; C:=FreeCat;
  FillChar(Disk[C]^[P],35,0);
  Disk[C]^[P]:=Allocated[0] Div 16; Disk[C]^[P+1]:=Allocated[0] Mod 16;
  Disk[C]^[P+2]:=4;
  For I:=1 To 30 Do
   If I<=Length(DosName) Then Disk[C]^[P+2+I]:=Ord(DosName[I]) Or $80
   Else Disk[C]^[P+2+I]:=$A0;
  Disk[C]^[P+33]:=(DataCount+ListCount) And 255;
  Disk[C]^[P+34]:=(DataCount+ListCount) Shr 8;
  Disk[Vtoc]^[6]:=DosVolume;
  Disk[Vtoc]^[$30]:=Allocated[DataCount+ListCount-1] Div 16;
  Disk[Vtoc]^[$31]:=1;
  If HostFileExists(DiskName) Then Bad('image de sortie deja existante') Else Begin
   Assign(F,DiskName); Rewrite(F,1); E:=IOResult;
   If E<>0 Then Bad('creation image impossible') Else Begin
    Created:=True; Opened:=True;
    For I:=0 To SectorCount-1 Do If Not Failed Then Begin
     BlockWrite(F,Disk[I]^,256,Got); E:=IOResult;
     If (E<>0) Or (Got<>256) Then Bad('ecriture image incomplete');
    End;
   End;
  End;
 End;
 If Opened Then Begin Close(F); E:=IOResult; If E<>0 Then Bad('fermeture image impossible'); End;
 If Failed And Created Then Begin Assign(F,DiskName); Erase(F); E:=IOResult; End;
 For I:=0 To SectorCount-1 Do Dispose(Disk[I]);
 If Not Failed And Not Quiet Then
  WriteLn('Image DOS 3.3: ',DiskName,' ; B ',DosName,' ; lecteur virtuel S',DosSlot,',D',DosDrive);
End;

Procedure ParseArgs;
Var
 I,J,K,Code,N,Slt,Drv,Vol:Integer;
 A,U,Command,Field:TString;
 Historical,DeviceSet:Boolean;
Begin
 If ParamCount=0 Then Help; SrcName:=''; ObjName:=''; ListName:=''; ListingEnabled:=True;
 Quiet:=False; AppleBinaryHeader:=False; StrictSource:=False; InteractivePause:=True;
 MultiObjects:=False;
 For I:=1 To 7 Do For J:=1 To 2 Do Begin DeviceRoots[I,J]:=''; DeviceVolumes[I,J]:=254; End;
 DiskName:=''; DiskTemplate:=''; DosName:=''; DosSlot:=6; DosDrive:=1; DosVolume:=254;
 Historical:=False; DeviceSet:=False; Command:='';
 For I:=1 To ParamCount Do Begin
  A:=ParamStr(I); U:=Up(A);
  If (I=1) And ((U='ASM') Or (Copy(U,1,4)='ASM ')) Then Begin
   Historical:=True; Command:=Trim(Copy(A,4,255));
  End Else If Copy(U,1,5)='/DSK:' Then DiskName:=Copy(A,6,255)
  Else If U='/MULTIOBJ' Then MultiObjects:=True
  Else If Copy(U,1,7)='/DRIVE:' Then Begin
   Field:=Copy(A,8,255); J:=Pos('=',Field);
   If J=0 Then Begin WriteLn('/DRIVE:slot,drive,volume=repertoire attendu'); Halt(1); End;
   U:=Copy(Field,1,J-1); Field:=Copy(Field,J+1,255);
   K:=Pos(',',U); If K=0 Then Begin WriteLn('Slot,drive,volume requis'); Halt(1); End;
   Val(Copy(U,1,K-1),Slt,Code); If Code<>0 Then Halt(1); Delete(U,1,K);
   K:=Pos(',',U); If K=0 Then Begin WriteLn('Slot,drive,volume requis'); Halt(1); End;
   Val(Copy(U,1,K-1),Drv,Code); If Code<>0 Then Halt(1); Delete(U,1,K);
   Val(U,Vol,Code);
   If (Code<>0) Or (Slt<1) Or (Slt>7) Or (Drv<1) Or (Drv>2) Or (Vol<0) Or (Vol>254) Or (Field='') Then Begin
    WriteLn('Parametres /DRIVE invalides'); Halt(1);
   End;
   DeviceRoots[Slt,Drv]:=FExpand(Field);
   If Not (DeviceRoots[Slt,Drv][Length(DeviceRoots[Slt,Drv])] In ['\','/']) Then
    DeviceRoots[Slt,Drv]:=DeviceRoots[Slt,Drv]+'\';
   DeviceVolumes[Slt,Drv]:=Vol;
  End
  Else If Copy(U,1,10)='/TEMPLATE:' Then DiskTemplate:=Copy(A,11,255)
  Else If Copy(U,1,6)='/NAME:' Then DosName:=Copy(A,7,255)
  Else If (U='/?') Or (U='-?') Then Help Else If Copy(U,1,3)='/L:' Then Begin
   ListName:=Copy(A,4,255); UseListing:=True;
  End Else If U='/Q' Then Quiet:=True Else If U='/B' Then AppleBinaryHeader:=True
  Else If U='/STRICT' Then StrictSource:=True Else If U='/MODERN' Then StrictSource:=False
  Else If U='/BATCH' Then InteractivePause:=False
  Else If (A<>'') And (A[1]='/') Then Begin
   WriteLn('Option inconnue: ',A); Halt(1);
  End Else If Historical Then Begin
   If Command<>'' Then Command:=Command+' '; Command:=Command+A;
  End Else If SrcName='' Then SrcName:=A Else If ObjName='' Then ObjName:=A Else
  Begin
   WriteLn('Argument surnumeraire: ',A); Halt(1);
  End;
 End;
 If Historical Then Begin
  K:=0;
  Repeat
   J:=Pos(',',Command);
   If J=0 Then Begin Field:=Trim(Command); Command:=''; End
   Else Begin Field:=Trim(Copy(Command,1,J-1)); Delete(Command,1,J); End;
   Inc(K);
   If K=1 Then SrcName:=Field Else If K=2 Then ObjName:=Field
   Else Begin
    U:=Up(Field); Code:=1; N:=0;
    If Length(U)>1 Then Val(Copy(U,2,255),N,Code);
    If (Code<>0) Or (U='') Then Begin WriteLn('Parametre ASM invalide: ',Field); Halt(1); End;
    Case U[1] Of
     'S':Begin DosSlot:=N; DeviceSet:=True; End;
     'D':Begin DosDrive:=N; DeviceSet:=True; End;
     'V':Begin DosVolume:=N; DeviceSet:=True; End;
     Else Begin WriteLn('Parametre ASM inconnu: ',Field); Halt(1); End;
    End;
   End;
  Until J=0;
  If K<2 Then Begin WriteLn('Syntaxe: ASM SOURCE,OBJECT[,S6,D1,V254]'); Halt(1); End;
 End;
 If SrcName='' Then Begin WriteLn('Source absent'); Halt(1); End;
 If Historical Then MultiObjects:=True;
 If (DosSlot<1) Or (DosSlot>7) Or (DosDrive<1) Or (DosDrive>2) Or
    (DosVolume<0) Or (DosVolume>254) Then Begin WriteLn('Slot 1..7, drive 1..2, volume 0..254 requis'); Halt(1); End;
 If (DiskName='') And (DeviceSet Or (DiskTemplate<>'') Or (DosName<>'')) Then Begin
  WriteLn('Les parametres disque exigent /DSK:image.dsk'); Halt(1);
 End;
 If ObjName='' Then ObjName:=BaseName(SrcName)+'.OBJ';
 If UseListing And (ListName='') Then ListName:=BaseName(SrcName)+'.LST';
 InitialSlot:=DosSlot; InitialDrive:=DosDrive; InitialVolume:=DosVolume;
 If DeviceRoots[DosSlot,DosDrive]='' Then Begin
  DeviceRoots[DosSlot,DosDrive]:=SourceDirectory(FExpand(SrcName));
  DeviceVolumes[DosSlot,DosDrive]:=DosVolume;
 End;
 If (Up(FExpand(ObjName+'.prodos'))=Up(FExpand(SrcName))) Or
    (UseListing And (Up(FExpand(ObjName+'.prodos'))=Up(FExpand(ListName)))) Or
    ((DiskTemplate<>'') And (Up(FExpand(ObjName+'.prodos'))=Up(FExpand(DiskTemplate)))) Or
    ((DiskName<>'') And (Up(FExpand(ObjName+'.prodos'))=Up(FExpand(DiskName)))) Then Begin
  WriteLn('Conflit de chemin avec les attributs ProDOS de l''objet'); Halt(1);
 End;
 If DiskTemplate<>'' Then Begin
  If (Up(FExpand(DiskTemplate))=Up(FExpand(ObjName))) Or
     (UseListing And (Up(FExpand(DiskTemplate))=Up(FExpand(ListName)))) Then Begin
   WriteLn('Le modele disque ne peut pas servir de fichier objet ou listing'); Halt(1);
  End;
 End;
 If DiskName<>'' Then Begin
  If DosName='' Then Begin
   DosName:=ObjName;
   For J:=Length(DosName) DownTo 1 Do If DosName[J] In ['\','/',':'] Then Begin
    Delete(DosName,1,J); Break;
   End;
  End;
  DosName:=Up(Trim(DosName));
  If Not ValidDosName(DosName) Then Begin WriteLn('Nom Apple DOS invalide (1..30 caracteres, initiale A-Z, sans virgule): ',DosName); Halt(1); End;
  If HostFileExists(DiskName) Then Begin WriteLn('Image de sortie deja existante: ',DiskName); Halt(1); End;
  If (Up(FExpand(DiskName))=Up(FExpand(SrcName))) Or
     (Up(FExpand(DiskName))=Up(FExpand(ObjName))) Or
     ((ListName<>'') And (Up(FExpand(DiskName))=Up(FExpand(ListName)))) Then Begin
   WriteLn('Chemins source, objet, listing et image doivent etre distincts'); Halt(1);
  End;
 End;
 If UseListing And (ListName='') Then ListName:=BaseName(SrcName)+'.LST';
End;

Procedure WriteProdosAttributes;
Var F:Text; E:Integer;
Begin
 If RelMode Then ProdosType:=$FE;
 If (ProdosType<>$FF) And (ProdosType<>$FE) And (Segments=Nil) Then Exit;
 Assign(F,ObjName+'.prodos'); Rewrite(F); E:=IOResult;
 If E<>0 Then Begin Error('Impossible de creer les attributs ProDOS'); Exit; End;
 WriteLn(F,'TYPE=$',Hex(ProdosType,2)); WriteLn(F,'AUXTYPE=$',Hex(ObjectMin,4)); E:=IOResult;
 Close(F); If (IOResult<>0) Or (E<>0) Then Error('Erreur ecriture attributs ProDOS');
End;

Procedure RemoveProdosAttributes;
Var F:File; E:Integer;
Begin
 If Not HostFileExists(ObjName+'.prodos') Then Exit;
 Assign(F,ObjName+'.prodos'); Erase(F); E:=IOResult;
 If E<>0 Then Error('Impossible de supprimer les attributs ProDOS perimes');
End;

Function NextObjectName(Name:TString):TString;
Const Alphabet='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
Var P:Integer;
Begin
 P:=Pos(UpCase(Name[Length(Name)]),Alphabet);
 If P=0 Then Begin Error('Nom objet multi-ORG: dernier caractere attendu dans 0..9,A..Z'); NextObjectName:=Name; Exit; End;
 Name[Length(Name)]:=Alphabet[(P Mod 36)+1]; NextObjectName:=Name;
End;

Function SafeOutputName(Name:TString):Boolean;
Var P:PInputName; Canon:TString;
Begin
 Canon:=Up(FExpand(Name)); SafeOutputName:=False;
 P:=Inputs;
 While P<>Nil Do Begin
  If Up(P^.Name)=Canon Then Exit;
  P:=P^.Next;
 End;
 If UseListing And (Canon=Up(FExpand(ListName))) Then Exit;
 If (DiskTemplate<>'') And (Canon=Up(FExpand(DiskTemplate))) Then Exit;
 If (DiskName<>'') And (Canon=Up(FExpand(DiskName))) Then Exit;
 SafeOutputName:=True;
End;

Procedure WriteAllOutputs;
Var Names:Array[0..35] Of TString;
    Stages:Array[0..35] Of TString;
    StageCreated:Array[0..35] Of Boolean;
    BaseObject,BaseDisk,BaseTemplate,BaseDos,NextDos:TString;
    P:PObjectSegment; I,J,Count,E:Integer; F:File;
Begin
 BaseObject:=ObjName; BaseDisk:=DiskName; BaseTemplate:=DiskTemplate; BaseDos:=DosName;
 FillChar(StageCreated,SizeOf(StageCreated),0);
 Count:=SegmentCount; If Count=0 Then Count:=1;
 Names[0]:=BaseObject;
 For I:=1 To Count-1 Do Names[I]:=NextObjectName(Names[I-1]);
 OutputSafe:=True;
 For I:=0 To Count-1 Do Begin
  If Not SafeOutputName(Names[I]) Or Not SafeOutputName(Names[I]+'.prodos') Then Begin
   Error('Sortie objet en conflit avec un fichier source, modele ou listing: '+Names[I]); OutputSafe:=False;
  End;
  Stages[I]:=BaseDisk+'.edasm-stage-'+Hex(I,2);
  If (BaseDisk<>'') And (Count>1) Then
   If HostFileExists(Stages[I]) Or Not SafeOutputName(Stages[I]) Then Begin
    Error('Fichier temporaire disque deja utilise: '+Stages[I]); OutputSafe:=False;
   End;
 End;
 If Not OutputSafe Then Exit;
 P:=Segments; NextDos:=BaseDos;
 For I:=0 To Count-1 Do Begin
  ObjName:=Names[I];
  If P<>Nil Then Begin
   For J:=0 To 255 Do Begin ObjectPages[J]:=P^.Pages[J]; UsedPages[J]:=P^.Used[J]; End;
   ObjectMin:=P^.MinAddress; ObjectMax:=P^.MaxAddress; ProdosType:=P^.FileType;
   P:=P^.Next;
  End;
  RemoveProdosAttributes;
  If Errors=0 Then WriteObjectFile;
  If Errors=0 Then WriteProdosAttributes;
  If (Errors=0) And (BaseDisk<>'') Then Begin
   If Count>1 Then Begin
    DiskName:=Stages[I]; DosName:=NextDos;
    If I>0 Then DiskTemplate:=Stages[I-1];
   End;
   WriteDosDisk;
   If (Count>1) And (Errors=0) Then StageCreated[I]:=True;
   If (I+1<Count) And (Errors=0) Then NextDos:=NextObjectName(NextDos);
  End;
 End;
 If (Errors=0) And (BaseDisk<>'') And (Count>1) Then Begin
  If HostFileExists(BaseDisk) Then Error('Image de sortie apparue pendant l''assemblage') Else Begin
   Assign(F,Stages[Count-1]); Rename(F,BaseDisk); E:=IOResult;
   If E<>0 Then Error('Impossible de publier l''image disque') Else StageCreated[Count-1]:=False;
  End;
 End;
 For I:=0 To Count-1 Do Begin
  If Errors<>0 Then Begin ObjName:=Names[I]; RemoveInvalidObject; RemoveProdosAttributes; End;
  If StageCreated[I] Then Begin Assign(F,Stages[I]); Erase(F); E:=IOResult;
   If E<>0 Then Error('Impossible de supprimer une image intermediaire'); End;
 End;
 ObjName:=BaseObject; DiskName:=BaseDisk; DiskTemplate:=BaseTemplate; DosName:=BaseDos;
End;

Procedure FreeSegments;
Var P:PObjectSegment; N:PInputName; I:Integer;
Begin
 If Segments<>Nil Then Begin
  While Segments<>Nil Do Begin
   P:=Segments; Segments:=P^.Next;
   For I:=0 To 255 Do Begin
    If P^.Pages[I]<>Nil Then Dispose(P^.Pages[I]);
    If P^.Used[I]<>Nil Then Dispose(P^.Used[I]);
   End;
   Dispose(P);
  End;
  InitObjectImage;
 End;
 While Inputs<>Nil Do Begin N:=Inputs; Inputs:=N^.Next; Dispose(N); End;
End;

BEGIN
 Instructions:=Nil; Conditions:=Nil; Segments:=Nil; LastSegment:=Nil; SegmentCount:=0; Inputs:=Nil;
 ParseArgs; BuildDate:=''; FirstPassFailure:=''; InitializeListing;
 SymbolCount:=0; NextEsdNumber:=1; Errors:=0; Pass:=1; AssembleOnePass;
 If UseListing Then Begin
  Assign(ListText,ListName); Rewrite(ListText); If IOResult<>0 Then Begin
   WriteLn('EDASM: impossible de creer ',ListName); Halt(3);
  End;
 End;
 { Stabilise les etiquettes et les choix page-zero/absolu apres la passe
   initiale. Les references avant peuvent modifier la taille du code. }
 StabilizeSymbols;
 Errors:=0; RelocCount:=0; ReferenceCount:=0;
 InitializeListing;
 InitObjectImage; Pass:=2; AssembleOnePass;
 If (MultiObjects Or StrictSource) And Not RelMode And Not ObjExplicit And (OrgCount>0) Then SaveObjectSegment;
 If FirstPassFailure<>'' Then Error('FAIL/PAUSE en premiere passe: '+FirstPassFailure);
 If Not PhaseStable Then Error('Erreur de phase: limite de stabilisation atteinte (symboles ou instructions)');
 If RelMode And AppleBinaryHeader Then Error('/B incompatible avec un module REL');
 If (ProdosType=$FF) And (RelMode Or AppleBinaryHeader Or (DiskName<>'')) Then
  Error('SYS/INTERP incompatible avec REL, /B ou /DSK');
 ValidateExternalSymbols;
 WriteAllOutputs;
 If UseListing Then Begin
  WriteSymbolTable;
  Close(ListText);
 End;
 { Libere l'historique sans lancer une autre passe. }
 InstructionCursor:=Instructions; LastInstruction:=Nil; Pass:=0;
 FinishInstructionPass;
 ConditionCursor:=Conditions; LastCondition:=Nil; FinishConditionalPass;
 If Errors=0 Then Begin
  If Not Quiet And (SegmentCount>1) Then WriteLn('Objets ORG produits: ',SegmentCount);
  If Not Quiet Then If ObjectMax>=ObjectMin Then
   WriteLn('Assemblage termine: ',ObjName,' (',ObjectMax-ObjectMin+1,
   ' octets, objet $',Hex(ObjectMin,4),'-$',Hex(ObjectMax,4),').') Else
   WriteLn('Assemblage termine: ',ObjName,' (objet vide).');
  If Not Quiet And RelMode Then
   WriteLn('Attributs ProDOS requis: TYPE=$FE, AUXTYPE=$',Hex(ObjectMin,4),'.');
 End Else
 Begin
  WriteLn(Errors,' erreur(s); objet invalide.'); FreeSegments; FreeObjectImage; Halt(4);
 End; FreeSegments; FreeObjectImage;
END.
