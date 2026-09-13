{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
  @abstract: Clone de l'assembleur Microware OS-9/6809.
  @license: MIT
}

Program OS9ASM;

{$A-,B-,I-,R-,S-}

Const
 Version='1.0'; MaxLine=120; ImageSize=65535;

Type
 TName=String[31];
 PSymbol=^TSymbol;
 TSymbol=Record Name:TName;Value:LongInt;Kind:Char;Defined,Mutable:Boolean;Next:PSymbol End;
 TBytes=Array[0..ImageSize]of Byte;

Var
 Symbols:PSymbol; Image:^TBytes;
 SourceName,ObjectName,ListName:String;
 MakeObject,ObjectExplicit,ListOn,SymbolsOn,CondList,ErrorsInList,FormFeed,Generated,Narrow,Motorola:Boolean;
 PageLength,PageWidth,MemoryK,PassNo,Errors,Warnings,LineNo,PageNo,PageLine:Integer;
 PC,DataPC,LowAddr,HighAddr,DirectPage:LongInt;
 ListFile:Text; ListingToFile,StopAssembly:Boolean;
 ProgramName,Title:String;

Function Upper(S:String):String;Var I:Integer;Begin For I:=1 to Length(S)do if S[I]in['a'..'z']then S[I]:=Chr(Ord(S[I])-32);Upper:=S End;
Function Trim(S:String):String;Begin While(Length(S)>0)and(S[1]in[#9,' '])do Delete(S,1,1);While(Length(S)>0)and(S[Length(S)]in[#9,' '])do Delete(S,Length(S),1);Trim:=S End;
Function Hex(V:LongInt;N:Integer):String;Const D='0123456789ABCDEF';Var S:String;Begin S:='';While N>0 do Begin S:=D[(V and 15)+1]+S;V:=V shr 4;Dec(N)End;Hex:=S End;
Procedure OutText(S:String);Begin if ListingToFile then WriteLn(ListFile,S)else WriteLn(S)End;
Procedure Help;Begin
 WriteLn('ASM ',Version,' - Assembleur Microware OS-9/6809');
 WriteLn('Syntaxe : ASM fichier [options] [#memoire] [>listing]');
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
Procedure Error(S:String);Begin Inc(Errors);WriteLn(StdErr,SourceName,'(',LineNo,'): erreur: ',S);if(PassNo=2)and ListOn and ErrorsInList then OutText('**** ERREUR: '+S)End;

Function FindSymbol(N:String):PSymbol;Var P:PSymbol;Begin N:=Upper(N);P:=Symbols;While(P<>Nil)and(P^.Name<>N)do P:=P^.Next;FindSymbol:=P End;
Procedure DefineSymbol(N:String;V:LongInt;K:Char;CanSet:Boolean);Var P:PSymbol;Begin
 N:=Upper(N);P:=FindSymbol(N);if P=Nil then Begin New(P);P^.Name:=N;P^.Next:=Symbols;Symbols:=P;P^.Defined:=False;P^.Mutable:=CanSet End;
 if(PassNo=1)and P^.Defined and not P^.Mutable then Begin Error('symbole defini deux fois: '+N);Exit End;
 if(PassNo=2)and P^.Defined and(P^.Value<>V)and not P^.Mutable then Begin Error('erreur de phase: '+N);Exit End;
 P^.Value:=V;P^.Kind:=K;P^.Defined:=True;P^.Mutable:=CanSet
End;

Var ExprText:String;ExprPos:Integer;ExprKnown:Boolean;
Procedure SkipSpace;Begin While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in[' ',#9])do Inc(ExprPos)End;
Function ParseExpr:LongInt;Forward;
Function Atom:LongInt;Var S:String;P:PSymbol;V:LongInt;C:Char;Begin
 SkipSpace;if ExprPos>Length(ExprText)then Begin ExprKnown:=False;Atom:=0;Exit End;C:=ExprText[ExprPos];
 if C='('then Begin Inc(ExprPos);V:=ParseExpr;SkipSpace;if(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')then Inc(ExprPos)else Error('parenthese fermante attendue');Atom:=V;Exit End;
 if C='-'then Begin Inc(ExprPos);Atom:=-Atom;Exit End;if C='+'then Begin Inc(ExprPos);Atom:=Atom;Exit End;
 if C=''''then Begin Inc(ExprPos);if ExprPos<=Length(ExprText)then V:=Ord(ExprText[ExprPos])else V:=0;Inc(ExprPos);if(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='''')then Inc(ExprPos);Atom:=V;Exit End;
 if C='$'then Begin Inc(ExprPos);V:=0;While(ExprPos<=Length(ExprText))and(UpCase(ExprText[ExprPos])in['0'..'9','A'..'F'])do Begin C:=UpCase(ExprText[ExprPos]);if C<='9'then V:=V*16+Ord(C)-48 else V:=V*16+Ord(C)-55;Inc(ExprPos)End;Atom:=V;Exit End;
 if C='%'then Begin Inc(ExprPos);V:=0;While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0','1'])do Begin V:=V*2+Ord(ExprText[ExprPos])-48;Inc(ExprPos)End;Atom:=V;Exit End;
 if C='@'then Begin Inc(ExprPos);V:=0;While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'7'])do Begin V:=V*8+Ord(ExprText[ExprPos])-48;Inc(ExprPos)End;Atom:=V;Exit End;
 if C='*'then Begin Inc(ExprPos);Atom:=PC;Exit End;if C='.'then Begin Inc(ExprPos);Atom:=DataPC;Exit End;
 if C in['0'..'9']then Begin V:=0;While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9'])do Begin V:=V*10+Ord(ExprText[ExprPos])-48;Inc(ExprPos)End;Atom:=V;Exit End;
 S:='';While(ExprPos<=Length(ExprText))and(UpCase(ExprText[ExprPos])in['A'..'Z','0'..'9','_','$','@','.'])do Begin S:=S+UpCase(ExprText[ExprPos]);Inc(ExprPos)End;
 P:=FindSymbol(S);if(P=Nil)or not P^.Defined then Begin if PassNo=2 then Error('symbole non defini: '+S);ExprKnown:=False;Atom:=0 End else Atom:=P^.Value
End;
Function Product:LongInt;Var V,W:LongInt;C:Char;Begin V:=Atom;Repeat SkipSpace;if ExprPos>Length(ExprText)then Break;C:=ExprText[ExprPos];if not(C in['*','/'])then Break;Inc(ExprPos);W:=Atom;if C='*'then V:=V*W else if W=0 then Error('division par zero')else V:=V div W Until False;Product:=V End;
Function ParseExpr:LongInt;Var V:LongInt;C:Char;Begin V:=Product;Repeat SkipSpace;if ExprPos>Length(ExprText)then Break;C:=ExprText[ExprPos];if not(C in['+','-'])then Break;Inc(ExprPos);if C='+'then V:=V+Product else V:=V-Product Until False;ParseExpr:=V End;
Function Eval(S:String;Var Known:Boolean):LongInt;Begin ExprText:=S;ExprPos:=1;ExprKnown:=True;Eval:=ParseExpr;SkipSpace;if ExprPos<=Length(ExprText)then Begin if PassNo=2 then Error('expression incorrecte: '+S);ExprKnown:=False End;Known:=ExprKnown End;

Procedure Emit(B:Byte);Begin if(PC<0)or(PC>ImageSize)then Begin Error('compteur programme hors limites');Exit End;if PassNo=2 then Image^[PC]:=B;if PC<LowAddr then LowAddr:=PC;if PC>HighAddr then HighAddr:=PC;Inc(PC)End;
Procedure EmitW(V:LongInt);Begin Emit(Byte(V shr 8));Emit(Byte(V))End;
Procedure EmitOp(Op:Word);Begin if Op>$FF then Emit(Byte(Op shr 8));Emit(Byte(Op))End;
Function NextPart(Var S:String):String;Var I:Integer;Q:Char;Begin S:=Trim(S);Q:=#0;I:=1;While I<=Length(S)do Begin if(S[I]in['''','"'])then Begin if Q=#0 then Q:=S[I]else if Q=S[I]then Q:=#0 End else if(S[I]=',')and(Q=#0)then Break;Inc(I)End;if I<=Length(S)then Begin NextPart:=Trim(Copy(S,1,I-1));Delete(S,1,I)End else Begin NextPart:=Trim(S);S:=''End End;

Function InherentOp(M:String):Word;Begin InherentOp:=$FFFF;
 if M='NOP'then InherentOp:=$12 else if M='SYNC'then InherentOp:=$13 else if M='DAA'then InherentOp:=$19 else if M='SEX'then InherentOp:=$1D else if M='RTS'then InherentOp:=$39 else if M='ABX'then InherentOp:=$3A else if M='RTI'then InherentOp:=$3B else if M='MUL'then InherentOp:=$3D else if M='SWI'then InherentOp:=$3F else if M='SWI2'then InherentOp:=$103F else if M='SWI3'then InherentOp:=$113F else
 if M='NEGA'then InherentOp:=$40 else if M='COMA'then InherentOp:=$43 else if M='LSRA'then InherentOp:=$44 else if M='RORA'then InherentOp:=$46 else if M='ASRA'then InherentOp:=$47 else if(M='ASLA')or(M='LSLA')then InherentOp:=$48 else if M='ROLA'then InherentOp:=$49 else if M='DECA'then InherentOp:=$4A else if M='INCA'then InherentOp:=$4C else if M='TSTA'then InherentOp:=$4D else if M='CLRA'then InherentOp:=$4F else
 if M='NEGB'then InherentOp:=$50 else if M='COMB'then InherentOp:=$53 else if M='LSRB'then InherentOp:=$54 else if M='RORB'then InherentOp:=$56 else if M='ASRB'then InherentOp:=$57 else if(M='ASLB')or(M='LSLB')then InherentOp:=$58 else if M='ROLB'then InherentOp:=$59 else if M='DECB'then InherentOp:=$5A else if M='INCB'then InherentOp:=$5C else if M='TSTB'then InherentOp:=$5D else if M='CLRB'then InherentOp:=$5F End;

Function BranchOp(M:String;Var LongBranch:Boolean):Word;Const BNames:String='BRNBHIBLSBCCBCSBNEBEQBVCBVSBPLBMIBGEBLTBGTBLE';Var I:Integer;Begin BranchOp:=$FFFF;LongBranch:=False;if M='BRA'then BranchOp:=$20 else if M='BSR'then BranchOp:=$8D else if M='LBRA'then Begin BranchOp:=$16;LongBranch:=True End else if M='LBSR'then Begin BranchOp:=$17;LongBranch:=True End else Begin if Copy(M,1,2)='LB'then Begin M:=Copy(M,2,Length(M));LongBranch:=True End;For I:=0 to 15 do if M=Copy(BNames,I*3+1,3)then Begin if LongBranch then BranchOp:=$1021+I else BranchOp:=$21+I;Exit End End End;

Function MemBase(M:String;Var Base:Byte;Var WordImm:Boolean):Boolean;Begin MemBase:=True;WordImm:=False;
 if M='SUBA'then Base:=$80 else if M='CMPA'then Base:=$81 else if M='SBCA'then Base:=$82 else if M='SUBD'then Begin Base:=$83;WordImm:=True End else if M='ANDA'then Base:=$84 else if M='BITA'then Base:=$85 else if M='LDA'then Base:=$86 else if M='STA'then Base:=$87 else if M='EORA'then Base:=$88 else if M='ADCA'then Base:=$89 else if M='ORA'then Base:=$8A else if M='ADDA'then Base:=$8B else if M='CMPX'then Begin Base:=$8C;WordImm:=True End else if M='LDX'then Begin Base:=$8E;WordImm:=True End else if M='STX'then Begin Base:=$8F;WordImm:=True End else
 if M='SUBB'then Base:=$C0 else if M='CMPB'then Base:=$C1 else if M='SBCB'then Base:=$C2 else if M='ADDD'then Begin Base:=$C3;WordImm:=True End else if M='ANDB'then Base:=$C4 else if M='BITB'then Base:=$C5 else if M='LDB'then Base:=$C6 else if M='STB'then Base:=$C7 else if M='EORB'then Base:=$C8 else if M='ADCB'then Base:=$C9 else if M='ORB'then Base:=$CA else if M='ADDB'then Base:=$CB else if M='LDD'then Begin Base:=$CC;WordImm:=True End else if M='STD'then Begin Base:=$CD;WordImm:=True End else if M='LDU'then Begin Base:=$CE;WordImm:=True End else if M='STU'then Begin Base:=$CF;WordImm:=True End else MemBase:=False End;

Function UnaryBase(M:String;Var Base:Byte):Boolean;Begin UnaryBase:=True;if M='NEG'then Base:=$00 else if M='COM'then Base:=$03 else if M='LSR'then Base:=$04 else if M='ROR'then Base:=$06 else if M='ASR'then Base:=$07 else if(M='ASL')or(M='LSL')then Base:=$08 else if M='ROL'then Base:=$09 else if M='DEC'then Base:=$0A else if M='INC'then Base:=$0C else if M='TST'then Base:=$0D else if M='JMP'then Base:=$0E else if M='CLR'then Base:=$0F else UnaryBase:=False End;

Function RegCode(R:String):Integer;Begin R:=Upper(Trim(R));RegCode:=-1;if R='D'then RegCode:=0 else if R='X'then RegCode:=1 else if R='Y'then RegCode:=2 else if R='U'then RegCode:=3 else if R='S'then RegCode:=4 else if R='PC'then RegCode:=5 else if R='A'then RegCode:=8 else if R='B'then RegCode:=9 else if R='CC'then RegCode:=10 else if R='DP'then RegCode:=11 End;
Function IndexReg(R:String):Integer;Begin R:=Upper(Trim(R));IndexReg:=-1;if R='X'then IndexReg:=0 else if R='Y'then IndexReg:=1 else if R='U'then IndexReg:=2 else if(R='S')or(R='SP')then IndexReg:=3 End;

Procedure EncodeIndexed(S:String);Var Ind:Boolean;Comma,I,R,Post:Integer;A,B:String;V:LongInt;K:Boolean;ForceShort:Boolean;Begin
 S:=Trim(S);Ind:=(Length(S)>1)and(S[1]='[')and(S[Length(S)]=']');if Ind then S:=Trim(Copy(S,2,Length(S)-2));Comma:=0;For I:=Length(S)downto 1 do if S[I]=','then Begin Comma:=I;Break End;if Comma=0 then Begin Error('registre index absent');Emit($84);Exit End;
 A:=Trim(Copy(S,1,Comma-1));B:=Upper(Trim(Copy(S,Comma+1,255)));ForceShort:=(Length(A)>0)and(A[1]='<');if ForceShort then Delete(A,1,1);
 if(B='PC')or(B='PCR')then Begin V:=Eval(A,K);if ForceShort then Begin Post:=$8C;if Ind then Post:=Post or $10;Emit(Post);Emit(Byte(V-(PC+1)))End else Begin Post:=$8D;if Ind then Post:=Post or $10;Emit(Post);EmitW(V-(PC+2))End;Exit End;
 if Copy(B,1,2)='--'then Begin Delete(B,1,2);Post:=$83 End else if Copy(B,1,1)='-'then Begin Delete(B,1,1);Post:=$82 End else if Copy(B,Length(B)-1,2)='++'then Begin Delete(B,Length(B)-1,2);Post:=$81 End else if Copy(B,Length(B),1)='+'then Begin Delete(B,Length(B),1);Post:=$80 End else Post:=-1;
 R:=IndexReg(B);if R<0 then Begin Error('registre index incorrect: '+B);R:=0 End;if Post>=0 then Begin if Ind and(Post in[$80,$82])then Error('mode indexe indirect illegal');if Ind then Post:=Post or $10;Emit(Post or(R shl 5));Exit End;
 if(A='A')then Post:=$86 else if(A='B')then Post:=$85 else if(A='D')then Post:=$8B else Begin V:=Eval(A,K);if not Ind and(V>=-16)and(V<=15)then Begin Emit((R shl 5)or(Byte(V)and$1F));Exit End else if(V>=-128)and(V<=127)then Begin Post:=$88;if Ind then Post:=Post or $10;Emit(Post or(R shl 5));Emit(Byte(V));Exit End else Begin Post:=$89;if Ind then Post:=Post or $10;Emit(Post or(R shl 5));EmitW(V);Exit End End;if Ind then Post:=Post or $10;Emit(Post or(R shl 5))
End;

Procedure EncodeInstruction(M,Operand:String);Var Op:Word;Base,B:Byte;LongB,WI,K,ForceDirect:Boolean;V,Off:LongInt;A,C:String;R1,R2,I:Integer;Indexed:Boolean;Begin
 Op:=InherentOp(M);if Op<>$FFFF then Begin if Trim(Operand)<>''then Error('operande superflu');EmitOp(Op);Exit End;
 Op:=BranchOp(M,LongB);if Op<>$FFFF then Begin V:=Eval(Operand,K);EmitOp(Op);if LongB then Begin Off:=V-(PC+2);if K and((Off<-$8000)or(Off>$7FFF))then Error('branche longue hors portee');EmitW(Off)End else Begin Off:=V-(PC+1);if(PassNo=2)and K and((Off<-$80)or(Off>$7F))then Error('branche hors portee');Emit(Byte(Off))End;Exit End;
 if(M='TFR')or(M='EXG')then Begin if M='TFR'then Emit($1F)else Emit($1E);A:=Operand;C:=NextPart(A);R1:=RegCode(C);R2:=RegCode(A);if(R1<0)or(R2<0)or(((R1<8)xor(R2<8)))then Error('registres incompatibles');Emit(Byte((R1 shl 4)or R2));Exit End;
 if(M='PSHS')or(M='PULS')or(M='PSHU')or(M='PULU')then Begin if M='PSHS'then Emit($34)else if M='PULS'then Emit($35)else if M='PSHU'then Emit($36)else Emit($37);B:=0;A:=Operand;Repeat C:=Upper(NextPart(A));if C='CC'then B:=B or 1 else if C='A'then B:=B or 2 else if C='B'then B:=B or 4 else if C='D'then B:=B or 6 else if C='DP'then B:=B or 8 else if C='X'then B:=B or 16 else if C='Y'then B:=B or 32 else if C='U'then B:=B or 64 else if C='S'then B:=B or 64 else if C='PC'then B:=B or 128 else Error('registre de pile incorrect')Until A='';Emit(B);Exit End;
 if(M='ORCC')or(M='ANDCC')or(M='CWAI')then Begin if M='ORCC'then Emit($1A)else if M='ANDCC'then Emit($1C)else Emit($3C);A:=Trim(Operand);if(A<>'')and(A[1]='#')then Delete(A,1,1);Emit(Byte(Eval(A,K)));Exit End;
 if(M='LEAX')or(M='LEAY')or(M='LEAS')or(M='LEAU')then Begin if M='LEAX'then Emit($30)else if M='LEAY'then Emit($31)else if M='LEAS'then Emit($32)else Emit($33);EncodeIndexed(Operand);Exit End;
 if M='JSR'then Begin Base:=$8D;WI:=True End else if not MemBase(M,Base,WI)then Begin if UnaryBase(M,Base)then WI:=False else Begin
   { Page 2/3 loads and compares }
   Op:=0;if M='CMPD'then Op:=$1083 else if M='CMPY'then Op:=$108C else if M='LDY'then Op:=$108E else if M='STY'then Op:=$108F else if M='LDS'then Op:=$10CE else if M='STS'then Op:=$10CF else if M='CMPU'then Op:=$1183 else if M='CMPS'then Op:=$118C;
   if Op=0 then Begin Error('instruction inconnue: '+M);Exit End;Base:=Byte(Op);WI:=True;Emit(Byte(Op shr 8))
  End
 End;
 A:=Trim(Operand);Indexed:=False;For I:=1 to Length(A)do if A[I]=','then Indexed:=True;
 if Indexed then Begin if UnaryBase(M,B)then Emit(B+$60)else Emit(Base+$20);EncodeIndexed(A);Exit End;
 if(A<>'')and(A[1]='#')then Begin if(M='STA')or(M='STB')or(M='STD')or(M='STX')or(M='STU')or(M='STY')or(M='STS')or(M='JMP')or(M='JSR')then Error('mode immediat illegal');Delete(A,1,1);Emit(Base);V:=Eval(A,K);if WI then EmitW(V)else Emit(Byte(V));Exit End;
 if UnaryBase(M,B)then Base:=B;K:=True;if(A<>'')and(A[1]='>')then Begin Delete(A,1,1);V:=Eval(A,K);if UnaryBase(M,B)then Emit(B+$70)else Emit(Base+$30);EmitW(V)End else Begin ForceDirect:=(A<>'')and(A[1]='<');if ForceDirect then Delete(A,1,1);V:=Eval(A,K);if ForceDirect or(K and((V shr 8)=DirectPage))then Begin if UnaryBase(M,B)then Emit(B)else Emit(Base+$10);Emit(Byte(V))End else Begin if UnaryBase(M,B)then Emit(B+$70)else Emit(Base+$30);EmitW(V)End End
End;

Procedure ParseFields(Line:String;Var LabelName,Op,Operand:String);Var I,J:Integer;FirstBlank:Boolean;Begin LabelName:='';Op:='';Operand:='';if Trim(Line)=''then Exit;if Line[1]='*'then Exit;FirstBlank:=Line[1]in[' ',#9];I:=1;while(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);J:=I;while(J<=Length(Line))and not(Line[J]in[' ',#9])do Inc(J);if not FirstBlank then Begin LabelName:=Copy(Line,I,J-I);I:=J;while(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);J:=I;while(J<=Length(Line))and not(Line[J]in[' ',#9])do Inc(J)End;Op:=Upper(Copy(Line,I,J-I));I:=J;while(I<=Length(Line))and(Line[I]in[' ',#9])do Inc(I);Operand:=Trim(Copy(Line,I,255));I:=1;while I<=Length(Operand)do Begin if Operand[I]=';'then Begin Operand:=Trim(Copy(Operand,1,I-1));Break End;Inc(I)End End;

Procedure RemoveFieldComment(Op:String;Var Operand:String);Var I:Integer;Q:Char;Begin
 if(Op='NAM')or(Op='TTL')or(Op='FCC')or(Op='FCS')then Exit;Q:=#0;I:=1;
 while I<=Length(Operand)do Begin
  if Operand[I]in['''','"']then Begin if Q=#0 then Q:=Operand[I]else if Q=Operand[I]then Q:=#0 End
  else if(Operand[I]in[' ',#9])and(Q=#0)then Begin Operand:=Trim(Copy(Operand,1,I-1));Exit End;
  Inc(I)
 End
End;

Procedure ListLine(Addr:LongInt;OldPC:LongInt;Src:String);Var S,Bs:String;I:LongInt;Begin if(PassNo<>2)or not ListOn then Exit;if PageLine=0 then Begin Inc(PageNo);OutText(ProgramName+'  '+Title+'  Page '+Hex(PageNo,2));OutText('');Inc(PageLine,2)End;Bs:='';For I:=OldPC to PC-1 do if(I>=0)and(I<=ImageSize)then Bs:=Bs+Hex(Image^[I],2)+' ';if Narrow then S:=Hex(Addr,4)+' '+Bs+' '+Src else S:=Hex(LineNo,4)+' '+Hex(Addr,4)+' '+Copy(Bs+'               ',1,15)+Src;if Length(S)>PageWidth then S:=Copy(S,1,PageWidth);OutText(S);Inc(PageLine);if PageLine>=PageLength then Begin if FormFeed then OutText(#12);PageLine:=0 End End;

Procedure ProcessFile(FileName:String);Var F:Text;Line,L,O,A:String;OldPC,V:LongInt;K:Boolean;Cond:Array[1..16]of Boolean;Depth,I:Integer;Active:Boolean;Begin
 Assign(F,FileName);Reset(F);if IOResult<>0 then Begin Error('impossible d''ouvrir '+FileName);Exit End;Depth:=0;Active:=True;
 While not Eof(F)and not StopAssembly do Begin ReadLn(F,Line);Inc(LineNo);if Length(Line)>MaxLine then Error('ligne de plus de 120 caracteres');ParseFields(Line,L,O,A);RemoveFieldComment(O,A);OldPC:=PC;
  if(O='IF')or(O='IFEQ')or(O='IFNE')or(O='IFLT')or(O='IFLE')or(O='IFGT')or(O='IFGE')or(O='IFP1')then Begin Inc(Depth);if Depth>16 then Begin Error('imbrication conditionnelle trop profonde');Depth:=16 End;Cond[Depth]:=Active;if O='IFP1'then K:=PassNo=1 else Begin V:=Eval(A,K);if O='IFEQ'then K:=V=0 else if O='IFNE'then K:=V<>0 else if O='IFLT'then K:=V<0 else if O='IFLE'then K:=V<=0 else if O='IFGT'then K:=V>0 else if O='IFGE'then K:=V>=0 else K:=V<>0 End;Active:=Active and K;Continue End;
  if O='ELSE'then Begin if Depth=0 then Error('ELSE sans IF')else Active:=Cond[Depth]and not Active;Continue End;if O='ENDC'then Begin if Depth=0 then Error('ENDC sans IF')else Begin Active:=Cond[Depth];Dec(Depth)End;Continue End;if not Active then Begin if CondList then ListLine(OldPC,OldPC,Line);Continue End;
  if(L<>'')and(O<>'EQU')and(O<>'SET')and(O<>'RMB')then DefineSymbol(L,PC,'L',False);
  if O=''then Begin ListLine(OldPC,OldPC,Line);Continue End else if O='EQU'then Begin V:=Eval(A,K);if L=''then Error('EQU exige une etiquette')else DefineSymbol(L,V,'E',False)End else if O='SET'then Begin V:=Eval(A,K);if L=''then Error('SET exige une etiquette')else DefineSymbol(L,V,'E',True)End else if(O='FCB')or(O='FDB')then Begin Repeat L:=NextPart(A);if(L<>'')and(L[1]in['''','"'])then Begin for I:=2 to Length(L)-1 do if O='FCB'then Emit(Ord(L[I]))else EmitW(Ord(L[I]))End else Begin V:=Eval(L,K);if O='FCB'then Emit(Byte(V))else EmitW(V)End Until A=''End else if(O='FCC')or(O='FCS')then Begin A:=Trim(A);if Length(A)>=2 then Begin L:=A[1];I:=2;while(I<=Length(A))and(A[I]<>L[1])do Inc(I);if I>Length(A)then Error('delimiteur de chaine manquant')else Begin A:=Copy(A,2,I-2);for I:=1 to Length(A)do Begin V:=Ord(A[I]);if(O='FCS')and(I=Length(A))then V:=V or $80;Emit(Byte(V))End End End else Error('chaine attendue')End else if O='RMB'then Begin V:=Eval(A,K);if Motorola then Begin if L<>''then DefineSymbol(L,PC,'D',False);Inc(PC,V)End else Begin if L<>''then DefineSymbol(L,DataPC,'D',False);Inc(DataPC,V)End End else if O='ORG'then Begin V:=Eval(A,K);if Motorola then PC:=V else DataPC:=V End else if O='SETDP'then Begin V:=Eval(A,K);DirectPage:=(V shr 8)and$FF End else if O='OS9'then Begin Emit($10);Emit($3F);Emit(Byte(Eval(A,K)))End else if O='MOD'then Begin PC:=0;DataPC:=0;LowAddr:=0;Emit($87);Emit($CD);L:=NextPart(A);EmitW(Eval(L,K));L:=NextPart(A);EmitW(Eval(L,K));L:=NextPart(A);Emit(Byte(Eval(L,K)));L:=NextPart(A);Emit(Byte(Eval(L,K)));Emit(0);if A<>''then Begin L:=NextPart(A);EmitW(Eval(L,K));EmitW(Eval(A,K))End End else if O='EMOD'then Begin Emit(0);Emit(0);Emit(0)End else if O='NAM'then ProgramName:=A else if O='TTL'then Title:=A else if O='USE'then ProcessFile(A)else if O='PAG'then PageLine:=0 else if O='SPC'then Begin if PassNo=2 then for I:=1 to Eval(A,K)do OutText('')End else if O='OPT'then Begin End else if O='END'then StopAssembly:=True else EncodeInstruction(O,A);
  ListLine(OldPC,OldPC,Line)
 End;Close(F);if Depth<>0 then Error('ENDC manquant')
End;

Procedure FixModule;Var I:LongInt;P:Byte;CRC:LongInt;Begin if(HighAddr<8)or(Image^[0]<>$87)or(Image^[1]<>$CD)then Exit;P:=0;For I:=0 to 7 do P:=P xor Image^[I];Image^[8]:=P xor $FF;
 { CRC-24 OS-9, polynome $800063; les trois octets CRC sont le complement. }
 CRC:=$FFFFFF;For I:=0 to HighAddr-3 do Begin CRC:=CRC xor(LongInt(Image^[I])shl 16);P:=0;while P<8 do Begin if(CRC and $800000)<>0 then CRC:=(CRC shl 1)xor$800063 else CRC:=CRC shl 1;CRC:=CRC and $FFFFFF;Inc(P)End End;CRC:=CRC xor $FFFFFF;Image^[HighAddr-2]:=Byte(CRC shr 16);Image^[HighAddr-1]:=Byte(CRC shr 8);Image^[HighAddr]:=Byte(CRC)End;
Procedure WriteObject;Var F:File;I:LongInt;B:Byte;Begin FixModule;Assign(F,ObjectName);Rewrite(F,1);if IOResult<>0 then Begin Error('impossible de creer '+ObjectName);Exit End;For I:=LowAddr to HighAddr do Begin B:=Image^[I];BlockWrite(F,B,1)End;Close(F);if IOResult<>0 then Error('erreur d''ecriture de '+ObjectName)End;
Procedure PrintSymbols;Var P:PSymbol;Begin if not SymbolsOn then Exit;OutText('');OutText('Table des symboles');P:=Symbols;While P<>Nil do Begin OutText(Copy(P^.Name+'                                ',1,32)+' '+Hex(P^.Value,4)+' '+P^.Kind);P:=P^.Next End End;
Procedure ParseArgs;Var I,J,V:Integer;S,T:String;Enable:Boolean;Begin
 CondList:=True;ErrorsInList:=True;PageLength:=66;PageWidth:=80;MemoryK:=4;I:=1;if ParamCount=0 then Help;
 while I<=ParamCount do Begin S:=ParamStr(I);if(S='/?')or(S='-?')or(Upper(S)='HELP')then Help else if S[1]='#'then Begin T:=Upper(Copy(S,2,255));if(T<>'')and(T[Length(T)]='K')then Delete(T,Length(T),1);Val(T,MemoryK,J);if(J<>0)or(MemoryK<1)then Begin WriteLn('ASM: taille memoire incorrecte');Halt(2)End End else if S[1]='>'then Begin ListName:=Copy(S,2,255);ListingToFile:=True;ListOn:=True End else if SourceName=''then SourceName:=S else Begin
   while S<>''do Begin J:=Pos(',',S);if J=0 then Begin T:=S;S:=''End else Begin T:=Copy(S,1,J-1);Delete(S,1,J)End;T:=Upper(Trim(T));Enable:=True;if(T<>'')and(T[1]='-')then Begin Enable:=False;Delete(T,1,1)End;if T=''then Continue;
    if T[1]='C'then CondList:=Enable else if T[1]='E'then ErrorsInList:=Enable else if T[1]='F'then FormFeed:=Enable else if T[1]='G'then Generated:=Enable else if T[1]='L'then ListOn:=Enable else if T[1]='M'then Motorola:=Enable else if T[1]='N'then Narrow:=Enable else if T[1]='S'then SymbolsOn:=Enable else if T[1]='D'then Begin Val(Copy(T,2,255),V,J);if J=0 then PageLength:=V End else if T[1]='W'then Begin Val(Copy(T,2,255),V,J);if J=0 then PageWidth:=V End else if T[1]='O'then Begin MakeObject:=Enable;if Pos('=',T)>0 then Begin ObjectName:=Copy(T,Pos('=',T)+1,255);ObjectExplicit:=True End End else Begin WriteLn('ASM: option inconnue: ',T);Halt(2)End
   End
  End;Inc(I)
 End;
 if not ObjectExplicit then Begin ObjectName:=SourceName;if Pos('.',ObjectName)>0 then ObjectName:=Copy(ObjectName,1,Pos('.',ObjectName)-1);ObjectName:=ObjectName+'.obj'End;if ListingToFile and(ListName='')then Begin WriteLn('ASM: nom du listing absent');Halt(2)End
End;
Procedure DisposeSymbols;Var P,Q:PSymbol;Begin P:=Symbols;While P<>Nil do Begin Q:=P^.Next;Dispose(P);P:=Q End End;

Var F:File;Code:Integer;
Begin
 Symbols:=Nil;SourceName:='';ObjectName:='';ListName:='';MakeObject:=False;ObjectExplicit:=False;ListOn:=False;SymbolsOn:=False;ListingToFile:=False;Motorola:=False;Narrow:=False;FormFeed:=False;Generated:=False;
 ParseArgs;Assign(F,SourceName);Reset(F,1);Code:=IOResult;if Code<>0 then Begin WriteLn('ASM: impossible d''ouvrir ',SourceName);Halt(2)End;Close(F);GetMem(Image,SizeOf(TBytes));FillChar(Image^,SizeOf(TBytes),0);
 if ListingToFile then Begin Assign(ListFile,ListName);Rewrite(ListFile);if IOResult<>0 then Begin WriteLn('ASM: impossible de creer ',ListName);Halt(2)End End;
 Errors:=0;Warnings:=0;ProgramName:=Upper(SourceName);Title:='';For PassNo:=1 to 2 do Begin PC:=0;DataPC:=0;DirectPage:=0;LowAddr:=ImageSize;HighAddr:=-1;LineNo:=0;PageNo:=0;PageLine:=0;StopAssembly:=False;ProcessFile(SourceName)End;
 PrintSymbols;if MakeObject and(Errors=0)then WriteObject;if ListingToFile then Close(ListFile);if Errors=0 then WriteLn('Assemblage termine: aucune erreur.')else WriteLn(Errors,' erreur(s).');DisposeSymbols;FreeMem(Image,SizeOf(TBytes));if Errors<>0 then Halt(1)
End.
