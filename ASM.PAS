{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Clone de l'assembleur Microware OS-9/6809.
 @license: MIT }

Program OS9ASM;

{$A-,B-,I-,R-,S-}

Const
 Version='1.0';
 MaxLine=120;
 ImageSize=65535;

Type
 TName=String[31];
 PSymbol=^TSymbol;
 TSymbol=Record Name:TName;
 Value:LongInt;
 Kind:Char;
 Defined,Mutable:Boolean;
 Next:PSymbol
End;
PDecision=^TDecision;
TDecision=Record
 Size:Byte;
 Next:PDecision
End;
TOptionState=Record
 MakeObject,ObjectExplicit,ListOn,SymbolsOn,CondList,ErrorsInList,FormFeed,Generated,
 Narrow,Motorola:Boolean;
 PageLength,PageWidth:Integer;
 ObjectName:String
End;
TBytes=Array[0..ImageSize]of Byte;

Var
 Symbols:PSymbol;
 Decisions,DecisionTail,DecisionCursor:PDecision;
 Image:^TBytes;
 SourceName,ObjectName,ListName:String;
 MakeObject,ObjectExplicit,ListOn,SymbolsOn,CondList,ErrorsInList,FormFeed,Generated,
 Narrow,Motorola:Boolean;
 PageLength,PageWidth,MemoryK,PassNo,Errors,Warnings,LineNo,PageNo,PageLine,
 LineByteCount:Integer;
 PC,DataPC,LowAddr,HighAddr,DirectPage:LongInt;
 ListFile:Text;
 ListingToFile,StopAssembly,ConstantDirective:Boolean;
 ProgramName,Title:String;
 InitialOptions:TOptionState;

Function Upper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do if S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);Upper:=S
End;

Function Trim(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[#9,' '])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[#9,' '])do Delete(S,Length(S),1);Trim:=S
End;

Function Hex(V:LongInt;N:Integer):String;
Const
 D:Array[0..15]of Char='0123456789ABCDEF';
Var
 S:String;
Begin
 S:='';
 While N>0 do Begin
  S:=D[V and 15]+S;
  V:=V shr 4;Dec(N)
 End;
 Hex:=S
End;

Procedure OutText(S:String);Begin
 If ListingToFile Then WriteLn(ListFile,S)
                  Else WriteLn(S)
End;

Procedure Help;Begin
 WriteLn('ASM ',Version,' - Cette commande permet de lancer ',
         'l''Assembleur Microware OS-9/6809.');
 WriteLn;
 WriteLn('Syntaxe : ASM fichier [options] [#memoire] [>listing]');
 WriteLn;
 WriteLn(' C/-C     afficher/masquer l''assemblage conditionnel (defaut C)');
 WriteLn(' Dnn      nombre de lignes par page (defaut D66)');
 WriteLn(' E/-E     inclure/exclure les erreurs du listing (defaut E)');
 WriteLn(' F/-F     changements de page par Form Feed');
 WriteLn(' G/-G     afficher toutes les lignes generees');
 WriteLn(' L/-L     produire un listing formate');
 WriteLn(' M/-M     mode Motorola absolu');
 WriteLn(' N/-N     listing etroit');
 WriteLn(' O[=nom]  produire le fichier objet');
 WriteLn(' S/-S     ajouter la table des symboles');
 WriteLn(' Wnn      largeur du listing (defaut W80)');
 WriteLn(' #nn[K]   memoire de travail annoncee (defaut 4K)');
 WriteLn(' >nom     rediriger le listing');Halt(0)
End;

Procedure Error(S:String);Begin
 Inc(Errors);WriteLn(StdErr,SourceName,'(',LineNo,'): erreur: ',S);
 if(PassNo=2)and ListOn and ErrorsInList Then OutText('**** ERREUR: '+S)
End;

Function FindSymbol(N:String):PSymbol;
Var
 P:PSymbol;
Begin
 N:=Upper(N);P:=Symbols;
 While(P<>Nil)and(P^.Name<>N)do P:=P^.Next;FindSymbol:=P
End;

Procedure ApplyOption(OptionText:String;FromSource:Boolean);
Var
 Raw,NumberText:String;
 Enable:Boolean;
 Key:Char;
 N,Code,EqPos:Integer;
Begin
 Raw:=Trim(OptionText);Enable:=True;
 if(Raw<>'')and(Raw[1]='-')Then Begin Enable:=False;Delete(Raw,1,1)End;
 if Raw=''Then Begin
  if FromSource Then Error('option OPT manquante')
  else Begin WriteLn('ASM: option manquante');Halt(2)End;
  Exit
 End;
 Key:=UpCase(Raw[1]);
 if Key='C'Then CondList:=Enable
 else if Key='E'Then ErrorsInList:=Enable
 else if Key='F'Then FormFeed:=Enable
 else if Key='G'Then Generated:=Enable
 else if Key='L'Then ListOn:=Enable
 else if Key='M'Then Motorola:=Enable
 else if Key='N'Then Narrow:=Enable
 else if Key='S'Then SymbolsOn:=Enable
 else if(Key='D')or(Key='W')Then Begin
  NumberText:=Copy(Raw,2,255);Val(NumberText,N,Code);
  if(Code<>0)or(N<1)or(N>255)Then Begin
   if FromSource Then Error('valeur incorrecte pour OPT '+Upper(Raw))
   else Begin WriteLn('ASM: valeur d''option incorrecte: ',Raw);Halt(2)End
  End else if Key='D'Then PageLength:=N else PageWidth:=N
 End else if Key='O'Then Begin
  MakeObject:=Enable;EqPos:=Pos('=',Raw);
  if EqPos>0 Then Begin
   if not Enable Then Begin
    if FromSource Then Error('nom de fichier interdit avec OPT -O')
    else Begin WriteLn('ASM: nom de fichier interdit avec -O');Halt(2)End
   End else if EqPos=Length(Raw)Then Begin
    if FromSource Then Error('nom de fichier objet manquant')
    else Begin WriteLn('ASM: nom de fichier objet manquant');Halt(2)End
   End else Begin
    ObjectName:=Copy(Raw,EqPos+1,255);ObjectExplicit:=True
   End
  End
 End else Begin
  if FromSource Then Error('option OPT inconnue: '+Upper(Raw))
  else Begin WriteLn('ASM: option inconnue: ',Raw);Halt(2)End
 End
End;

Procedure SaveOptions(Var State:TOptionState);
Begin
 State.MakeObject:=MakeObject;State.ObjectExplicit:=ObjectExplicit;State.ListOn:=ListOn;
 State.SymbolsOn:=SymbolsOn;State.CondList:=CondList;State.ErrorsInList:=ErrorsInList;
 State.FormFeed:=FormFeed;State.Generated:=Generated;State.Narrow:=Narrow;
 State.Motorola:=Motorola;State.PageLength:=PageLength;State.PageWidth:=PageWidth;
 State.ObjectName:=ObjectName
End;

Procedure RestoreOptions(Var State:TOptionState);
Begin
 MakeObject:=State.MakeObject;ObjectExplicit:=State.ObjectExplicit;ListOn:=State.ListOn;
 SymbolsOn:=State.SymbolsOn;CondList:=State.CondList;ErrorsInList:=State.ErrorsInList;
 FormFeed:=State.FormFeed;Generated:=State.Generated;Narrow:=State.Narrow;
 Motorola:=State.Motorola;PageLength:=State.PageLength;PageWidth:=State.PageWidth;
 ObjectName:=State.ObjectName
End;

Function ValidSymbolName(N:String):Boolean;
Var
 I:Integer;
Begin
 ValidSymbolName:=False;
 if(Length(N)<1)or(Length(N)>8)or not(UpCase(N[1])in['A'..'Z'])Then Exit;
 For I:=2 to Length(N)do if not(UpCase(N[I])in['A'..'Z','0'..'9','_','.','$'])Then Exit;
 ValidSymbolName:=True
End;

Procedure DefineSymbol(N:String;V:LongInt;K:Char;CanSet:Boolean);
Var
 P:PSymbol;
Begin
 N:=Upper(N);
 if not ValidSymbolName(N)Then Begin
  if PassNo=2 Then Error('etiquette incorrecte: '+N);Exit
 End;
 P:=FindSymbol(N);if P=Nil Then Begin
  New(P);P^.Name:=N;P^.Next:=Symbols;Symbols:=P;P^.Defined:=False;P^.Mutable:=CanSet
 End;
 if(PassNo=1)and P^.Defined and not P^.Mutable Then Begin
  Error('symbole defini deux fois: '+N);Exit
 End;
 if(PassNo=2)and P^.Defined and(P^.Value<>V)and not P^.Mutable Then Begin
  Error('erreur de phase: '+N);Exit
 End;
 P^.Value:=V;P^.Kind:=K;P^.Defined:=True;P^.Mutable:=CanSet
End;

Var
 ExprText:String;
 ExprPos,ExprForwardCount:Integer;
 ExprKnown:Boolean;

Procedure SkipSpace;Begin
 While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in[' ',#9])do Inc(ExprPos)
End;
Function ParseExpr:LongInt;Forward;
Function UnaryValue:LongInt;Forward;

Function Atom:LongInt;
Var
 S:String;
 P:PSymbol;
 V:LongInt;
 C:Char;
Begin
 SkipSpace;if ExprPos>Length(ExprText)Then Begin
  if PassNo=2 Then Error('operande manquant');ExprKnown:=False;Atom:=0;Exit
 End;C:=ExprText[ExprPos];
 if C='('Then Begin
  Inc(ExprPos);V:=ParseExpr;SkipSpace;
  if(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos)else Begin
   if PassNo=2 Then Error('parenthese droite manquante');ExprKnown:=False
  End;Atom:=V;Exit
 End;
 { Dans le dialecte Microware, une constante caractere est une apostrophe suivie
   d'un seul caractere; elle n'a pas d'apostrophe fermante. }
 if C=''''Then Begin
  Inc(ExprPos);if ExprPos<=Length(ExprText)Then Begin
   V:=Ord(ExprText[ExprPos]);Inc(ExprPos)
  End else Begin
   if PassNo=2 Then Error('caractere manquant apres apostrophe');ExprKnown:=False;V:=0
  End;
  Atom:=V;Exit
 End;
 if C='$'Then Begin
  Inc(ExprPos);V:=0;S:='';
  While(ExprPos<=Length(ExprText))and(UpCase(ExprText[ExprPos])in['0'..'9','A'..'F'])
  do Begin
   C:=UpCase(ExprText[ExprPos]);S:=S+C;
   if C<='9'Then V:=V*16+Ord(C)-48 else V:=V*16+Ord(C)-55;
   Inc(ExprPos)
  End;if(S='')or(Length(S)>4)Then Begin
   if PassNo=2 Then Error('constante hexadecimale incorrecte');ExprKnown:=False
  End;Atom:=V;Exit
 End;
 if C='%'Then Begin
  Inc(ExprPos);V:=0;S:='';
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0','1'])do Begin
   S:=S+ExprText[ExprPos];V:=V*2+Ord(ExprText[ExprPos])-48;Inc(ExprPos)
  End;if(S='')or(Length(S)>16)Then Begin
   if PassNo=2 Then Error('constante binaire incorrecte');ExprKnown:=False
  End;Atom:=V;Exit
 End;
 if C='@'Then Begin
  Inc(ExprPos);V:=0;S:='';
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'7'])do Begin
   S:=S+ExprText[ExprPos];V:=V*8+Ord(ExprText[ExprPos])-48;Inc(ExprPos)
  End;if(S='')or(V>65535)Then Begin
   if PassNo=2 Then Error('constante octale incorrecte');ExprKnown:=False
  End;Atom:=V;Exit
 End;
 if C='*'Then Begin
  Inc(ExprPos);Atom:=PC;Exit
 End;if C='.'Then Begin
  Inc(ExprPos);Atom:=DataPC;Exit
 End;
 if C in['0'..'9']Then Begin
  V:=0;
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9'])do Begin
   V:=V*10+Ord(ExprText[ExprPos])-48;Inc(ExprPos)
  End;if V>65535 Then Begin
   if PassNo=2 Then Error('constante superieure a 65535');ExprKnown:=False
  End;Atom:=V;Exit
 End;
 S:='';
 While(ExprPos<=Length(ExprText))and(UpCase(ExprText[ExprPos])in['A'..'Z','0'..'9','_',
 '$','.'])do Begin
  S:=S+UpCase(ExprText[ExprPos]);Inc(ExprPos)
 End;
 if S=''Then Begin
  if PassNo=2 Then Error('operande incorrect');ExprKnown:=False;Atom:=0;Exit
 End;
 if not ValidSymbolName(S)Then Begin
  if PassNo=2 Then Error('nom symbolique incorrect: '+S);ExprKnown:=False;Atom:=0;Exit
 End;
 P:=FindSymbol(S);if(P=Nil)or not P^.Defined Then Begin
  Inc(ExprForwardCount);
  if PassNo=2 Then Error('symbole non defini: '+S);ExprKnown:=False;Atom:=0
 End else Atom:=P^.Value
End;

Function UnaryValue:LongInt;
Var
 C:Char;
Begin
 SkipSpace;
 if ExprPos>Length(ExprText)Then Begin UnaryValue:=Atom;Exit End;
 C:=ExprText[ExprPos];
 if C='-'Then Begin Inc(ExprPos);UnaryValue:=-UnaryValue End
 else if C='+'Then Begin Inc(ExprPos);UnaryValue:=UnaryValue End
 else if C='^'Then Begin Inc(ExprPos);UnaryValue:=(not UnaryValue)and$FFFF End
 else UnaryValue:=Atom
End;

Function LogicalValue:LongInt;
Var
 V,W:LongInt;
 C:Char;
Begin
 V:=UnaryValue;
 Repeat
  SkipSpace;if ExprPos>Length(ExprText)Then Break;C:=ExprText[ExprPos];
  if not(C in['&','!'])Then Break;Inc(ExprPos);W:=UnaryValue;
  if C='&'Then V:=(V and W)and$FFFF else V:=(V or W)and$FFFF
 Until False;
 LogicalValue:=V
End;

Function Product:LongInt;
Var
 V,W:LongInt;
 C:Char;
Begin
 V:=LogicalValue;Repeat SkipSpace;if ExprPos>Length(ExprText)Then Break;C:=ExprText[ExprPos];
 if not(C in['*','/'])Then Break;Inc(ExprPos);W:=LogicalValue;
 if C='*'Then Begin
  V:=(V and$FFFF)*(W and$FFFF);
  if V>65535 Then Begin if PassNo=2 Then Error('debordement de multiplication');
   ExprKnown:=False;V:=V and$FFFF
  End
 End else if(W and$FFFF)=0 Then Begin
  if PassNo=2 Then Error('division par zero');ExprKnown:=False;V:=0
 End else V:=(V and$FFFF)div(W and$FFFF)
 Until False;Product:=V
End;

Function ParseExpr:LongInt;
Var
 V:LongInt;
 C:Char;
Begin
 V:=Product;Repeat SkipSpace;if ExprPos>Length(ExprText)Then Break;C:=ExprText[ExprPos];
 if not(C in['+','-'])Then Break;Inc(ExprPos);
 if C='+'Then V:=V+Product else V:=V-Product Until False;ParseExpr:=V
End;

Function Eval(S:String;Var Known:Boolean):LongInt;
Var
 V:LongInt;
Begin
 ExprText:=S;ExprPos:=1;ExprKnown:=True;ExprForwardCount:=0;V:=ParseExpr;SkipSpace;
 if ExprPos<=Length(ExprText)Then Begin
  if PassNo=2 Then Error('expression incorrecte: '+S);ExprKnown:=False
 End;
 if(PassNo=1)and(ExprForwardCount>1)Then Begin
  Error('references avant multiples dans une expression');ExprKnown:=False
 End;
 if ExprKnown and((V<-$8000)or(V>$FFFF))Then Begin
  if PassNo=2 Then Error('resultat d''expression hors plage 16 bits');ExprKnown:=False
 End;Known:=ExprKnown;Eval:=V
End;

Procedure Emit(B:Byte);Begin
 if(PC<0)or(PC>ImageSize)Then Begin
  Error('compteur programme hors limites');Exit
 End;if PassNo=2 Then Image^[PC]:=B;if PC<LowAddr Then LowAddr:=PC;
 if PC>HighAddr Then HighAddr:=PC;Inc(PC);Inc(LineByteCount)
End;

Procedure EmitW(V:LongInt);Begin
 Emit(Byte(V shr 8));Emit(Byte(V))
End;

Procedure EmitOp(Op:Word);Begin
 if Op>$FF Then Emit(Byte(Op shr 8));Emit(Byte(Op))
End;

Function SelectSize(Proposed:Byte):Byte;
Var
 P:PDecision;
Begin
 if PassNo=1 Then Begin
  New(P);P^.Size:=Proposed;P^.Next:=Nil;
  if Decisions=Nil Then Decisions:=P else DecisionTail^.Next:=P;
  DecisionTail:=P;SelectSize:=Proposed
 End else if DecisionCursor<>Nil Then Begin
  SelectSize:=DecisionCursor^.Size;DecisionCursor:=DecisionCursor^.Next
 End else Begin
  Error('erreur de phase dans la selection d''adressage');SelectSize:=Proposed
 End
End;

Procedure CheckByte(V:LongInt;Known:Boolean;What:String);
Begin
 if(PassNo=2)and Known and((V<-$80)or(V>$FF))Then Error(What+' hors plage 8 bits')
End;

Procedure CheckWord(V:LongInt;Known:Boolean;What:String);
Begin
 if(PassNo=2)and Known and((V<-$8000)or(V>$FFFF))Then Error(What+' hors plage 16 bits')
End;

Function NextPart(Var S:String):String;
Var
 I:Integer;
 Q:Char;
Begin
 S:=Trim(S);Q:=#0;I:=1;
 While I<=Length(S)do Begin
  if(S[I]='''')and(Q=#0)Then Begin
   Inc(I);if I<=Length(S)Then Inc(I);Continue
  End;
  if S[I]='"'Then Begin
   if Q=#0 Then Q:='"'else Q:=#0
  End else if(S[I]=',')and(Q=#0)Then Break;Inc(I)
 End;if I<=Length(S)Then Begin
  NextPart:=Trim(Copy(S,1,I-1));Delete(S,1,I)
 End else
 Begin
  NextPart:=Trim(S);S:=''
 End
End;

Function InherentOp(M:String):Word;Begin
 InherentOp:=$FFFF;
 if M='NOP'Then InherentOp:=$12 else if M='SYNC'Then InherentOp:=$13 else if M=
 'DAA'Then InherentOp:=$19 else if M='SEX'Then InherentOp:=$1D else if M=
 'RTS'Then InherentOp:=$39 else if M='ABX'Then InherentOp:=$3A else if M=
 'RTI'Then InherentOp:=$3B else if M='MUL'Then InherentOp:=$3D else if M=
 'SWI'Then InherentOp:=$3F else if M='SWI2'Then InherentOp:=$103F else if M=
 'SWI3'Then InherentOp:=$113F else
 if M='NEGA'Then InherentOp:=$40 else if M='COMA'Then InherentOp:=$43 else if M=
 'LSRA'Then InherentOp:=$44 else if M='RORA'Then InherentOp:=$46 else if M=
 'ASRA'Then InherentOp:=$47 else if(M='ASLA')or(M='LSLA')Then InherentOp:=$48 else if M=
 'ROLA'Then InherentOp:=$49 else if M='DECA'Then InherentOp:=$4A else if M=
 'INCA'Then InherentOp:=$4C else if M='TSTA'Then InherentOp:=$4D else if M=
 'CLRA'Then InherentOp:=$4F else
 if M='NEGB'Then InherentOp:=$50 else if M='COMB'Then InherentOp:=$53 else if M=
 'LSRB'Then InherentOp:=$54 else if M='RORB'Then InherentOp:=$56 else if M=
 'ASRB'Then InherentOp:=$57 else if(M='ASLB')or(M='LSLB')Then InherentOp:=$58 else if M=
 'ROLB'Then InherentOp:=$59 else if M='DECB'Then InherentOp:=$5A else if M=
 'INCB'Then InherentOp:=$5C else if M='TSTB'Then InherentOp:=$5D else if M=
 'CLRB'Then InherentOp:=$5F
End;

Function BranchOp(M:String;Var LongBranch:Boolean):Word;
Const
 BNames:String='BRNBHIBLSBCCBCSBNEBEQBVCBVSBPLBMIBGEBLTBGTBLE';
Var
 I:Integer;
Begin
 BranchOp:=$FFFF;LongBranch:=False;
 if M='BHS'Then M:='BCC' else if M='BLO'Then M:='BCS' else if M='LBHS'Then M:='LBCC'
 else if M='LBLO'Then M:='LBCS';
 if M='BRA'Then BranchOp:=$20 else if M='BSR'Then BranchOp:=$8D else if M='LBRA'Then Begin
  BranchOp:=$16;LongBranch:=True
 End else if M='LBSR'Then Begin
  BranchOp:=$17;LongBranch:=True
 End else
 Begin
  if Copy(M,1,2)='LB'Then Begin
   M:=Copy(M,2,Length(M));LongBranch:=True
  End;
  For I:=0 to 15 do if M=Copy(BNames,I*3+1,3)Then Begin
   if LongBranch Then BranchOp:=$1021+I else BranchOp:=$21+I;Exit
  End
 End
End;

Function MemBase(M:String;Var Base:Byte;Var WordImm:Boolean):Boolean;Begin
 MemBase:=True;WordImm:=False;
 if M='SUBA'Then Base:=$80 else if M='CMPA'Then Base:=$81 else if M='SBCA'Then Base:=
 $82 else if M='SUBD'Then Begin
  Base:=$83;WordImm:=True
 End else if M='ANDA'Then Base:=$84 else if M='BITA'Then Base:=$85 else if M=
 'LDA'Then Base:=$86 else if M='STA'Then Base:=$87 else if M='EORA'Then Base:=
 $88 else if M='ADCA'Then Base:=$89 else if M='ORA'Then Base:=$8A else if M=
 'ADDA'Then Base:=$8B else if M='CMPX'Then Begin
  Base:=$8C;WordImm:=True
 End else if M='LDX'Then Begin
  Base:=$8E;WordImm:=True
 End else if M='STX'Then Begin
  Base:=$8F;WordImm:=True
 End else
 if M='SUBB'Then Base:=$C0 else if M='CMPB'Then Base:=$C1 else if M='SBCB'Then Base:=
 $C2 else if M='ADDD'Then Begin
  Base:=$C3;WordImm:=True
 End else if M='ANDB'Then Base:=$C4 else if M='BITB'Then Base:=$C5 else if M=
 'LDB'Then Base:=$C6 else if M='STB'Then Base:=$C7 else if M='EORB'Then Base:=
 $C8 else if M='ADCB'Then Base:=$C9 else if M='ORB'Then Base:=$CA else if M=
 'ADDB'Then Base:=$CB else if M='LDD'Then Begin
  Base:=$CC;WordImm:=True
 End else if M='STD'Then Begin
  Base:=$CD;WordImm:=True
 End else if M='LDU'Then Begin
  Base:=$CE;WordImm:=True
 End else if M='STU'Then Begin
  Base:=$CF;WordImm:=True
 End else MemBase:=False
End;

Function UnaryBase(M:String;Var Base:Byte):Boolean;Begin
 UnaryBase:=True;
 if M='NEG'Then Base:=$00 else if M='COM'Then Base:=$03 else if M='LSR'Then Base:=
 $04 else if M='ROR'Then Base:=$06 else if M='ASR'Then Base:=$07 else if(M='ASL')or(M=
 'LSL')Then Base:=$08 else if M='ROL'Then Base:=$09 else if M='DEC'Then Base:=
 $0A else if M='INC'Then Base:=$0C else if M='TST'Then Base:=$0D else if M=
 'JMP'Then Base:=$0E else if M='CLR'Then Base:=$0F else UnaryBase:=False
End;

Function RegCode(R:String):Integer;Begin
 R:=Upper(Trim(R));RegCode:=-1;
 if R='D'Then RegCode:=0 else if R='X'Then RegCode:=1 else if R='Y'Then RegCode:=
 2 else if R='U'Then RegCode:=3 else if R='S'Then RegCode:=4 else if R='PC'Then RegCode:=
 5 else if R='A'Then RegCode:=8 else if R='B'Then RegCode:=9 else if R='CC'Then RegCode:=
 10 else if R='DP'Then RegCode:=11
End;

Function IndexReg(R:String):Integer;Begin
 R:=Upper(Trim(R));IndexReg:=-1;
 if R='X'Then IndexReg:=0 else if R='Y'Then IndexReg:=1 else if R='U'Then IndexReg:=
 2 else if(R='S')or(R='SP')Then IndexReg:=3
End;

Procedure EncodeIndexed(S:String);
Var
 Ind:Boolean;
 Comma,I,R,Post,Chosen:Integer;
 A,B:String;
 V,Disp:LongInt;
 K:Boolean;
 ForceShort,ForceLong:Boolean;
Begin
 S:=Trim(S);Ind:=(Length(S)>1)and(S[1]='[')and(S[Length(S)]=']');
 if Ind Then S:=Trim(Copy(S,2,Length(S)-2));Comma:=0;
 For I:=Length(S)downto 1 do if S[I]=','Then Begin
  Comma:=I;Break
 End;
 { Forme indirecte etendue [adresse] : post-octet $9F suivi de l'adresse. }
 if Comma=0 Then Begin
  if not Ind Then Begin
   Error('registre index absent');Emit($84);Exit
  End;
  V:=Eval(S,K);CheckWord(V,K,'adresse indirecte');Emit($9F);EmitW(V);Exit
 End;
 A:=Trim(Copy(S,1,Comma-1));B:=Upper(Trim(Copy(S,Comma+1,255)));
 ForceShort:=(Length(A)>0)and(A[1]='<');ForceLong:=(Length(A)>0)and(A[1]='>');
 if ForceShort or ForceLong Then Delete(A,1,1);
 if(B='PC')or(B='PCR')Then Begin
  if A='' Then Begin Error('adresse PCR absente');V:=0;K:=False End else V:=Eval(A,K);
  if ForceShort Then Begin
   { PC pointe ici sur le post-octet; l'instruction finit deux octets plus loin. }
   Disp:=V-(PC+2);if(PassNo=2)and K and((Disp<-$80)or(Disp>$7F))Then
    Error('deplacement PCR hors plage 8 bits');
   Post:=$8C;if Ind Then Post:=Post or $10;Emit(Post);Emit(Byte(Disp))
  End else
  Begin
   Disp:=V-(PC+3);if(PassNo=2)and K and((Disp<-$8000)or(Disp>$7FFF))Then
    Error('deplacement PCR hors plage 16 bits');
   Post:=$8D;if Ind Then Post:=Post or $10;Emit(Post);EmitW(Disp)
  End;Exit
 End;
 if Copy(B,1,2)='--'Then Begin
  Delete(B,1,2);Post:=$83
 End else if Copy(B,1,1)='-'Then Begin
  Delete(B,1,1);Post:=$82
 End else if Copy(B,Length(B)-1,2)='++'Then Begin
  Delete(B,Length(B)-1,2);Post:=$81
 End else if Copy(B,Length(B),1)='+'Then Begin
  Delete(B,Length(B),1);Post:=$80
 End else Post:=-1;
 R:=IndexReg(B);if R<0 Then Begin
  Error('registre index incorrect: '+B);R:=0
 End;if Post>=0 Then Begin
  if A<>'' Then Error('offset interdit avec auto-indexation');
  if Ind and(Post in[$80,$82])Then Error('mode indexe indirect illegal');
  if Ind Then Post:=Post or $10;Emit(Post or(R shl 5));Exit
 End;
 if(A='A')Then Post:=$86 else if(A='B')Then Post:=$85 else if(A='D')Then Post:=$8B else
 Begin
  if A='' Then Begin
   Post:=$84;if Ind Then Post:=Post or $10;Emit(Post or(R shl 5));Exit
  End;
  V:=Eval(A,K);
  if ForceLong Then Chosen:=2
  else if ForceShort Then Chosen:=1
  else if not Ind and K and(V>=-16)and(V<=15)Then Chosen:=0
  else if K and(V>=-128)and(V<=127)Then Chosen:=1
  else Chosen:=2;
  Chosen:=SelectSize(Chosen);
  if Chosen=0 Then Begin
   if Ind Then Error('offset indexe 5 bits indirect illegal');
   if(PassNo=2)and K and((V<-16)or(V>15))Then Error('offset indexe hors plage 5 bits');
   Emit((R shl 5)or(Byte(V)and$1F));Exit
  End;
  if Chosen=1 Then Begin
   if(PassNo=2)and K and((V<-$80)or(V>$7F))Then Error('offset indexe hors plage 8 bits');
   Post:=$88;if Ind Then Post:=Post or $10;Emit(Post or(R shl 5));Emit(Byte(V));Exit
  End;
  if(PassNo=2)and K and((V<-$8000)or(V>$7FFF))Then Error('offset indexe hors plage 16 bits');
  Post:=$89;if Ind Then Post:=Post or $10;Emit(Post or(R shl 5));EmitW(V);Exit
 End;if Ind Then Post:=Post or $10;Emit(Post or(R shl 5))
End;

Procedure EncodeInstruction(M,Operand:String);
Var
 Op:Word;
 Base,B:Byte;
 LongB,WI,K,ForceDirect:Boolean;
 V,Off:LongInt;
 A,C:String;
 R1,R2,I:Integer;
 Indexed:Boolean;
Begin
 Op:=InherentOp(M);if Op<>$FFFF Then Begin
  if Trim(Operand)<>''Then Error('operande superflu');EmitOp(Op);Exit
 End;
 Op:=BranchOp(M,LongB);if Op<>$FFFF Then Begin
  V:=Eval(Operand,K);EmitOp(Op);if LongB Then Begin
   Off:=V-(PC+2);
   if(PassNo=2)and K and((Off<-$8000)or(Off>$7FFF))Then Error('branche longue hors portee');EmitW(Off)
  End else
  Begin
   Off:=V-(PC+1);
   if(PassNo=2)and K and((Off<-$80)or(Off>$7F))Then Error('branche hors portee');
   Emit(Byte(Off))
  End;Exit
 End;
 if(M='TFR')or(M='EXG')Then Begin
  if M='TFR'Then Emit($1F)else Emit($1E);A:=Operand;C:=NextPart(A);R1:=RegCode(C);
  R2:=RegCode(A);
  if(R1<0)or(R2<0)or(((R1<8)xor(R2<8)))Then Error('registres incompatibles');
  Emit(Byte((R1 shl 4)or R2));Exit
 End;
 if(M='PSHS')or(M='PULS')or(M='PSHU')or(M='PULU')Then Begin
  if M='PSHS'Then Emit($34)else if M='PULS'Then Emit($35)else if M='PSHU'Then Emit($36)
  else Emit($37);B:=0;A:=Operand;Repeat C:=Upper(NextPart(A));
  if C='CC'Then B:=B or 1 else if C='A'Then B:=B or 2 else if C='B'Then B:=
  B or 4 else if C='D'Then B:=B or 6 else if C='DP'Then B:=B or 8 else if C='X'Then B:=
  B or 16 else if C='Y'Then B:=B or 32 else if C='U'Then B:=B or 64 else if C='S'Then B:=
  B or 64 else if C='PC'Then B:=B or 128 else Error('registre de pile incorrect')Until A=
  '';Emit(B);Exit
 End;
 if(M='ORCC')or(M='ANDCC')or(M='CWAI')Then Begin
  if M='ORCC'Then Emit($1A)else if M='ANDCC'Then Emit($1C)else Emit($3C);A:=Trim(Operand);
  if(A<>'')and(A[1]='#')Then Delete(A,1,1);V:=Eval(A,K);
  CheckByte(V,K,'operande immediate');Emit(Byte(V));Exit
 End;
 if(M='LEAX')or(M='LEAY')or(M='LEAS')or(M='LEAU')Then Begin
  if M='LEAX'Then Emit($30)else if M='LEAY'Then Emit($31)else if M='LEAS'Then Emit($32)
  else Emit($33);EncodeIndexed(Operand);Exit
 End;
 if M='JSR'Then Begin
  Base:=$8D;WI:=True
 End else if not MemBase(M,Base,WI)Then Begin
  if UnaryBase(M,Base)Then WI:=False else
  Begin
   { Page 2/3 loads and compares }
   Op:=0;
   if M='CMPD'Then Op:=$1083 else if M='CMPY'Then Op:=$108C else if M='LDY'Then Op:=
   $108E else if M='STY'Then Op:=$108F else if M='LDS'Then Op:=$10CE else if M=
   'STS'Then Op:=$10CF else if M='CMPU'Then Op:=$1183 else if M='CMPS'Then Op:=$118C;
   if Op=0 Then Begin
    Error('instruction inconnue: '+M);Exit
   End;Base:=Byte(Op);WI:=True;Emit(Byte(Op shr 8))
  End
 End;
 A:=Trim(Operand);Indexed:=(Length(A)>1)and(A[1]='[')and(A[Length(A)]=']');
 For I:=1 to Length(A)do if A[I]=','Then Indexed:=True;
 if Indexed Then Begin
  if UnaryBase(M,B)Then Emit(B+$60)else Emit(Base+$20);EncodeIndexed(A);Exit
 End;
 if(A<>'')and(A[1]='#')Then Begin
  if(M='STA')or(M='STB')or(M='STD')or(M='STX')or(M='STU')or(M='STY')or(M='STS')or(M='JMP')
  or(M='JSR')Then Error('mode immediat illegal');Delete(A,1,1);Emit(Base);V:=Eval(A,K);
  if WI Then Begin CheckWord(V,K,'operande immediate');EmitW(V)End
  else Begin CheckByte(V,K,'operande immediate');Emit(Byte(V))End;Exit
 End;
 if UnaryBase(M,B)Then Base:=B;K:=True;if(A<>'')and(A[1]='>')Then Begin
  Delete(A,1,1);V:=Eval(A,K);CheckWord(V,K,'adresse etendue');
  if UnaryBase(M,B)Then Emit(B+$70)else Emit(Base+$30);EmitW(V)
 End else
 Begin
  ForceDirect:=(A<>'')and(A[1]='<');if ForceDirect Then Delete(A,1,1);V:=Eval(A,K);
  if ForceDirect Then I:=1 else if K and(V>=0)and(V<=$FFFF)and(((V shr 8)and$FF)=DirectPage)
   Then I:=1 else I:=2;I:=SelectSize(I);
  if I=1 Then Begin
   CheckWord(V,K,'adresse directe');
   if K and not ForceDirect and(((V shr 8)and$FF)<>DirectPage)Then
    Error('adresse hors de la page directe');
   if UnaryBase(M,B)Then Emit(B)else Emit(Base+$10);Emit(Byte(V))
  End else
  Begin
   CheckWord(V,K,'adresse etendue');
   if UnaryBase(M,B)Then Emit(B+$70)else Emit(Base+$30);EmitW(V)
  End
 End
End;

Procedure ParseFields(Line:String;Var LabelName,Op,Operand:String);
Var
 I,J:Integer;
 FirstBlank:Boolean;
 Q:Char;
Begin
 LabelName:='';Op:='';Operand:='';if Trim(Line)=''Then Exit;if Line[1]='*'Then Exit;
 FirstBlank:=Line[1]in[' ',#9];I:=1;
 While(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);J:=I;
 While(J<=Length(Line))and not(Line[J]in[' ',#9])do Inc(J);if not FirstBlank Then Begin
  LabelName:=Copy(Line,I,J-I);I:=J;
  While(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);J:=I;
  While(J<=Length(Line))and not(Line[J]in[' ',#9])do Inc(J)
 End;Op:=Upper(Copy(Line,I,J-I));I:=J;
 While(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);Operand:=Trim(Copy(Line,I,255));
 I:=1;Q:=#0;
 While I<=Length(Operand)do Begin
  if(Operand[I]='''')and(Q=#0)Then Begin
   Inc(I);if I<=Length(Operand)Then Inc(I);Continue
  End;
  if Operand[I]='"'Then Begin
   if Q=#0 Then Q:='"'else Q:=#0
  End else if(Operand[I]=';')and(Q=#0)Then Begin
   Operand:=Trim(Copy(Operand,1,I-1));Break
  End;Inc(I)
 End
End;

Procedure RemoveFieldComment(Op:String;Var Operand:String);
Var
 I:Integer;
 Q:Char;
Begin
 if(Op='NAM')or(Op='TTL')or(Op='FCC')or(Op='FCS')Then Exit;Q:=#0;I:=1;
 While I<=Length(Operand)do Begin
  if(Operand[I]='''')and(Q=#0)Then Begin
   Inc(I);if I<=Length(Operand)Then Inc(I);Continue
  End;
  if Operand[I]='"'Then Begin
   if Q=#0 Then Q:='"'else Q:=#0
  End
  else if(Operand[I]in[' ',#9])and(Q=#0)Then Begin
   Operand:=Trim(Copy(Operand,1,I-1));Exit
  End;
  Inc(I)
 End
End;

Procedure ListLine(Addr:LongInt;OldPC:LongInt;Src:String);
Var
 S,Bs:String;
 I,FirstByte,LastByte:LongInt;

 Procedure StartPage;
 Begin
  if PageLine=0 Then Begin
   Inc(PageNo);OutText(ProgramName+'  '+Title+'  Page '+Hex(PageNo,2));OutText('');
   Inc(PageLine,2)
  End
 End;

 Procedure PutPhysicalLine(Address:LongInt;BytesText,SourceText:String;First:Boolean);
 Begin
  StartPage;
  if Narrow Then Begin
   S:=Hex(Address,4)+' '+BytesText;
   if SourceText<>''Then S:=S+' '+SourceText
  End else if First Then
   S:=Hex(LineNo,4)+' '+Hex(Address,4)+' '+Copy(BytesText+'               ',1,15)+SourceText
  else S:='     '+Hex(Address,4)+' '+Copy(BytesText+'               ',1,15);
  if Length(S)>PageWidth Then S:=Copy(S,1,PageWidth);OutText(S);Inc(PageLine);
  if PageLine>=PageLength Then Begin
   if FormFeed Then OutText(#12);PageLine:=0
  End
 End;

Begin
 if(PassNo<>2)or not ListOn Then Exit;
 FirstByte:=0;LastByte:=LineByteCount-1;if LastByte>4 Then LastByte:=4;Bs:='';
 For I:=FirstByte to LastByte do if(OldPC+I>=0)and(OldPC+I<=ImageSize)Then
  Bs:=Bs+Hex(Image^[OldPC+I],2)+' ';
 PutPhysicalLine(Addr,Bs,Src,True);
 if Generated and ConstantDirective Then Begin
  FirstByte:=5;
  While FirstByte<LineByteCount do Begin
   LastByte:=FirstByte+4;if LastByte>=LineByteCount Then LastByte:=LineByteCount-1;
   Bs:='';
   For I:=FirstByte to LastByte do if(OldPC+I>=0)and(OldPC+I<=ImageSize)Then
    Bs:=Bs+Hex(Image^[OldPC+I],2)+' ';
   PutPhysicalLine(OldPC+FirstByte,Bs,'',False);Inc(FirstByte,5)
  End
 End
End;

Procedure ProcessFile(FileName:String);
Var
 F:Text;
 Line,L,O,A:String;
 OldPC,V:LongInt;
 K:Boolean;
 Cond:Array[1..16]of Boolean;
 Depth,I:Integer;
 Active:Boolean;
Begin
 Assign(F,FileName);Reset(F);if IOResult<>0 Then Begin
  Error('impossible d''ouvrir '+FileName);Exit
 End;Depth:=0;Active:=True;
 While not Eof(F)and not StopAssembly do Begin
  ReadLn(F,Line);Inc(LineNo);
  if Length(Line)>MaxLine Then Error('ligne de plus de 120 caracteres');
  ParseFields(Line,L,O,A);RemoveFieldComment(O,A);OldPC:=PC;LineByteCount:=0;
  ConstantDirective:=False;
  if(O='IF')or(O='IFEQ')or(O='IFNE')or(O='IFLT')or(O='IFLE')or(O='IFGT')or(O='IFGE')or(O=
  'IFP1')Then Begin
   Inc(Depth);if Depth>16 Then Begin
    Error('imbrication conditionnelle trop profonde');Depth:=16
   End;Cond[Depth]:=Active;if O='IFP1'Then K:=PassNo=1 else
   Begin
    V:=Eval(A,K);
    if O='IFEQ'Then K:=V=0 else if O='IFNE'Then K:=V<>0 else if O='IFLT'Then K:=V<
    0 else if O='IFLE'Then K:=V<=0 else if O='IFGT'Then K:=V>0 else if O='IFGE'Then K:=V>=
    0 else K:=V<>0
   End;Active:=Active and K;Continue
  End;
  if O='ELSE'Then Begin
   if Depth=0 Then Error('ELSE sans IF')else Active:=Cond[Depth]and not Active;Continue
  End;if O='ENDC'Then Begin
   if Depth=0 Then Error('ENDC sans IF')else
   Begin
    Active:=Cond[Depth];Dec(Depth)
   End;Continue
  End;if not Active Then Begin
   if CondList Then ListLine(OldPC,OldPC,Line);Continue
  End;
  if(L<>'')and(O<>'EQU')and(O<>'SET')and(O<>'RMB')Then DefineSymbol(L,PC,'L',False);
  if O=''Then Begin
   ListLine(OldPC,OldPC,Line);Continue
  End else if O='EQU'Then Begin
   V:=Eval(A,K);
   if L=''Then Error('EQU exige une etiquette')else DefineSymbol(L,V,'E',False)
  End else if O='SET'Then Begin
   V:=Eval(A,K);
   if L=''Then Error('SET exige une etiquette')else DefineSymbol(L,V,'E',True)
  End else if(O='FCB')or(O='FDB')Then Begin
   ConstantDirective:=True;
   Repeat L:=NextPart(A);if(L<>'')and(L[1]='"')Then Begin
    For I:=2 to Length(L)-1 do if O='FCB'Then Emit(Ord(L[I]))else EmitW(Ord(L[I]))
   End else
   Begin
    V:=Eval(L,K);
    if O='FCB'Then Begin CheckByte(V,K,'constante FCB');Emit(Byte(V))End
    else Begin CheckWord(V,K,'constante FDB');EmitW(V)End
   End Until A=''
  End else if(O='FCC')or(O='FCS')Then Begin
   ConstantDirective:=True;
   A:=Trim(A);if Length(A)>=2 Then Begin
    L:=A[1];I:=2;
    While(I<=Length(A))and(A[I]<>L[1])do Inc(I);
    if I>Length(A)Then Error('delimiteur de chaine manquant')else
    Begin
     A:=Copy(A,2,I-2);
     For I:=1 to Length(A)do Begin
      V:=Ord(A[I]);if(O='FCS')and(I=Length(A))Then V:=V or $80;Emit(Byte(V))
     End
    End
   End else Error('chaine attendue')
  End else if O='RMB'Then Begin
   V:=Eval(A,K);if Motorola Then Begin
    if L<>''Then DefineSymbol(L,PC,'D',False);Inc(PC,V)
   End else
   Begin
    if L<>''Then DefineSymbol(L,DataPC,'D',False);Inc(DataPC,V)
   End
  End else if O='ORG'Then Begin
   V:=Eval(A,K);if Motorola Then PC:=V else DataPC:=V
  End else if O='SETDP'Then Begin
   V:=Eval(A,K);CheckWord(V,K,'valeur SETDP');DirectPage:=(V shr 8)and$FF
  End else if O='OS9'Then Begin
   Emit($10);Emit($3F);V:=Eval(A,K);CheckByte(V,K,'numero d''appel OS9');Emit(Byte(V))
  End else if O='MOD'Then Begin
   PC:=0;DataPC:=0;LowAddr:=0;Emit($87);Emit($CD);L:=NextPart(A);EmitW(Eval(L,K));
   L:=NextPart(A);EmitW(Eval(L,K));L:=NextPart(A);V:=Eval(L,K);
   CheckByte(V,K,'type/langage MOD');Emit(Byte(V));L:=NextPart(A);V:=Eval(L,K);
   CheckByte(V,K,'attribut/revision MOD');Emit(Byte(V));Emit(0);if A<>''Then Begin
    L:=NextPart(A);EmitW(Eval(L,K));EmitW(Eval(A,K))
   End
  End else if O='EMOD'Then Begin
   Emit(0);Emit(0);Emit(0)
  End else if O='NAM'Then ProgramName:=A else if O='TTL'Then Title:=A else if O=
  'USE'Then Begin ProcessFile(A);LineByteCount:=0 End
  else if O='PAG'Then PageLine:=0 else if O='SPC'Then Begin
   if PassNo=2 Then
   For I:=1 to Eval(A,K)do OutText('')
  End else if O='OPT'Then ApplyOption(A,True)
  else if O='END'Then StopAssembly:=True else EncodeInstruction(O,A);
  ListLine(OldPC,OldPC,Line)
 End;Close(F);if Depth<>0 Then Error('ENDC manquant')
End;

Procedure FixModule;
Var
 I:LongInt;
 P:Byte;
 CRC:LongInt;
Begin
 if(HighAddr<8)or(Image^[0]<>$87)or(Image^[1]<>$CD)Then Exit;P:=0;
 For I:=0 to 7 do P:=P xor Image^[I];Image^[8]:=P xor $FF;
 { CRC-24 OS-9, polynome $800063; les trois octets CRC sont le complement. }
 CRC:=$FFFFFF;
 For I:=0 to HighAddr-3 do Begin
  CRC:=CRC xor(LongInt(Image^[I])shl 16);P:=0;
  While P<8 do Begin
   if(CRC and $800000)<>0 Then CRC:=(CRC shl 1)xor$800063 else CRC:=CRC shl 1;
   CRC:=CRC and $FFFFFF;Inc(P)
  End
 End;CRC:=CRC xor $FFFFFF;Image^[HighAddr-2]:=Byte(CRC shr 16);
 Image^[HighAddr-1]:=Byte(CRC shr 8);Image^[HighAddr]:=Byte(CRC)
End;

Procedure WriteObject;
Var
 F:File;
 I:LongInt;
 B:Byte;
Begin
 FixModule;Assign(F,ObjectName);Rewrite(F,1);if IOResult<>0 Then Begin
  Error('impossible de creer '+ObjectName);Exit
 End;
 For I:=LowAddr to HighAddr do Begin
  B:=Image^[I];BlockWrite(F,B,1)
 End;Close(F);if IOResult<>0 Then Error('erreur d''ecriture de '+ObjectName)
End;

Procedure PrintSymbols;
Var
 P:PSymbol;
Begin
 if not SymbolsOn Then Exit;OutText('');OutText('Table des symboles');P:=Symbols;
 While P<>Nil do Begin
  OutText(Copy(P^.Name+'                                ',1,32)+' '+Hex(P^.Value,4)+' '+
  P^.Kind);P:=P^.Next
 End
End;

Procedure ParseArgs;
Var
 I,J:Integer;
 S,T:String;
Begin
 CondList:=True;ErrorsInList:=True;PageLength:=66;PageWidth:=80;MemoryK:=4;I:=1;
 if ParamCount=0 Then Help;
 While I<=ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')or(Upper(S)='HELP')Then Help else if S[1]='#'Then Begin
   T:=Upper(Copy(S,2,255));if(T<>'')and(T[Length(T)]='K')Then Delete(T,Length(T),1);
   Val(T,MemoryK,J);if(J<>0)or(MemoryK<1)Then Begin
    WriteLn('ASM: taille memoire incorrecte');Halt(2)
   End
  End else if S[1]='>'Then Begin
   ListName:=Copy(S,2,255);ListingToFile:=True;ListOn:=True
  End else if SourceName=''Then SourceName:=S else
  Begin
   While S<>''do Begin
    J:=Pos(',',S);if J=0 Then Begin
     T:=S;S:=''
    End else
    Begin
     T:=Copy(S,1,J-1);Delete(S,1,J)
    End;T:=Trim(T);if T<>''Then ApplyOption(T,False)
   End
  End;Inc(I)
 End;
 if not ObjectExplicit Then Begin
  ObjectName:=SourceName;
  if Pos('.',ObjectName)>0 Then ObjectName:=Copy(ObjectName,1,Pos('.',ObjectName)-1);
  ObjectName:=ObjectName+'.obj'
 End;if ListingToFile and(ListName='')Then Begin
  WriteLn('ASM: nom du listing absent');Halt(2)
 End
End;

Procedure DisposeSymbols;
Var
 P,Q:PSymbol;
Begin
 P:=Symbols;
 While P<>Nil do Begin
  Q:=P^.Next;Dispose(P);P:=Q
 End
End;

Procedure DisposeDecisions;
Var
 P,Q:PDecision;
Begin
 P:=Decisions;
 While P<>Nil do Begin
  Q:=P^.Next;Dispose(P);P:=Q
 End
End;

Var
 F:File;
 Code:Integer;

BEGIN
 Symbols:=Nil;Decisions:=Nil;DecisionTail:=Nil;DecisionCursor:=Nil;
 SourceName:='';ObjectName:='';ListName:='';MakeObject:=False;
 ObjectExplicit:=False;ListOn:=False;SymbolsOn:=False;ListingToFile:=False;
 Motorola:=False;Narrow:=False;FormFeed:=False;Generated:=False;
 ParseArgs;SaveOptions(InitialOptions);Assign(F,SourceName);Reset(F,1);Code:=IOResult;if Code<>0 Then Begin
  WriteLn('ASM: impossible d''ouvrir ',SourceName);Halt(2)
 End;Close(F);GetMem(Image,SizeOf(TBytes));FillChar(Image^,SizeOf(TBytes),0);
 if ListingToFile Then Begin
  Assign(ListFile,ListName);Rewrite(ListFile);if IOResult<>0 Then Begin
   WriteLn('ASM: impossible de creer ',ListName);Halt(2)
  End
 End;
 Errors:=0;Warnings:=0;ProgramName:=Upper(SourceName);Title:='';
 For PassNo:=1 to 2 do Begin
  RestoreOptions(InitialOptions);
  PC:=0;DataPC:=0;DirectPage:=0;LowAddr:=ImageSize;HighAddr:=-1;LineNo:=0;PageNo:=0;
  PageLine:=0;StopAssembly:=False;if PassNo=2 Then DecisionCursor:=Decisions;
  ProcessFile(SourceName)
 End;
 PrintSymbols;if MakeObject and(Errors=0)Then WriteObject;
 if ListingToFile Then Close(ListFile);
 if Errors=0 Then WriteLn('Assemblage termine: aucune erreur.')else WriteLn(Errors,
 ' erreur(s).');DisposeSymbols;DisposeDecisions;FreeMem(Image,SizeOf(TBytes));
 if Errors<>0 Then Halt(1)
END.
