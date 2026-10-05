{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)

  Desassembleur de Cray-1. Les noms d'operations sont normalises afin de
  produire un listing lisible; les operandes suivent les registres Cray
  A, B, S, T et V. Un fichier binaire brut est interprete comme une suite
  de parcelles de 16 bits, dans l'ordre gros-boutiste par defaut.
}

Program DISCRAY1;

Const
 Version = '1.0';

Var
 InputFile:File;
 Listing:Text;
 InputName,OutputName:String;
 LittleEndian,ListingOpen,ShowCode:Boolean;
 ParcelAddress,InstructionCount,ErrorCount:LongInt;

Function Upper(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='a') And (S[I]<='z') Then S[I]:=Chr(Ord(S[I])-32);
 Upper:=S;
End;

Function Octal(Value:LongInt; Width:Byte):String;
Var
 S:String;
 D:Byte;
Begin
 S:='';
 Repeat
  D:=Value Mod 8;
  S:=Chr(Ord('0')+D)+S;
  Value:=Value Div 8;
 Until Value=0;
 While Length(S)<Width Do S:='0'+S;
 Octal:=S;
End;

Function Decimal(Value:LongInt):String;
Var
 S:String;
Begin
 Str(Value,S);
 Decimal:=S;
End;

Function ParseNumber(S:String; Var Value:LongInt):Boolean;
Var
 I,Base,Digit:Integer;
 C:Char;
Begin
 ParseNumber:=False;
 Value:=0;
 If S='' Then Exit;
 Base:=8;
 If (Length(S)>1) And (S[1]='$') Then Begin
  Base:=16;
  Delete(S,1,1);
 End Else If (Length(S)>2) And (S[1]='0') And
             ((S[2]='x') Or (S[2]='X')) Then Begin
  Base:=16;
  Delete(S,1,2);
 End Else If (S[Length(S)]='D') Or (S[Length(S)]='d') Then Begin
  Base:=10;
  Delete(S,Length(S),1);
 End Else If (S[Length(S)]='O') Or (S[Length(S)]='o') Or
             (S[Length(S)]='Q') Or (S[Length(S)]='q') Then
  Delete(S,Length(S),1);
 If S='' Then Exit;
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If (C>='0') And (C<='9') Then Digit:=Ord(C)-Ord('0') Else
  If (C>='A') And (C<='F') Then Digit:=Ord(C)-Ord('A')+10 Else
  If (C>='a') And (C<='f') Then Digit:=Ord(C)-Ord('a')+10 Else Exit;
  If Digit>=Base Then Exit;
  Value:=Value*Base+Digit;
 End;
 ParseNumber:=True;
End;

Procedure Emit(S:String);
Begin
 If ListingOpen Then WriteLn(Listing,S) Else WriteLn(S);
End;

Function ReadParcel(Var W:Word):Boolean;
Var
 B:Array[0..1] Of Byte;
 Count:Word;
Begin
 BlockRead(InputFile,B,2,Count);
 ReadParcel:=Count=2;
 If Count=2 Then
  If LittleEndian Then W:=Word(B[0])+(Word(B[1]) Shl 8)
                  Else W:=(Word(B[0]) Shl 8)+Word(B[1]);
End;

Function RegisterName(C:Char; N:Byte):String;
Begin
 RegisterName:=C+Chr(Ord('0')+N);
End;

Function AReg(N:Byte):String; Begin AReg:=RegisterName('A',N); End;
Function SReg(N:Byte):String; Begin SReg:=RegisterName('S',N); End;
Function VReg(N:Byte):String; Begin VReg:=RegisterName('V',N); End;

Function BReg(J,K:Byte):String;
Begin
 BReg:='B'+Chr(Ord('0')+J)+Chr(Ord('0')+K);
End;

Function TReg(J,K:Byte):String;
Begin
 TReg:='T'+Chr(Ord('0')+J)+Chr(Ord('0')+K);
End;

Function ParcelLocation(P:LongInt):String;
Begin
 ParcelLocation:=Octal(P Div 4,8)+Chr(Ord('a')+(P Mod 4));
End;

Function IsTwoParcel(Op:Byte):Boolean;
Begin
 IsTwoParcel:=((Op>=$06) And (Op<=$0F)) Or
              (Op=$10) Or (Op=$11) Or (Op=$20) Or (Op=$21) Or
              ((Op>=$40) And (Op<=$5F));
 { Les constantes ci-dessus sont hexadecimales. Les groupes $40..$5F
   correspondent aux codes octaux 100..137. }
End;

Function JKM(J,K:Byte; M:Word):LongInt;
Begin
 JKM:=((LongInt(J)*8+K) Shl 16)+M;
End;

Function BranchAddress(I,J,K:Byte; M:Word):LongInt;
Begin
 BranchAddress:=((LongInt(I And 3)*64+LongInt(J)*8+K) Shl 16)+M;
End;

Function Decode(W1,W2:Word; HasSecond:Boolean):String;
Var
 Op,I,J,K,H:Byte;
 Imm,Target:LongInt;
 Mnem,Args:String;
Begin
 Op:=W1 Shr 9;
 H:=(W1 Shr 9) And 7;
 I:=(W1 Shr 6) And 7;
 J:=(W1 Shr 3) And 7;
 K:=W1 And 7;
 Imm:=JKM(J,K,W2);
 Target:=BranchAddress(I,J,K,W2);
 Mnem:=''; Args:='';

 Case Op Of
  $00:Begin Mnem:='ERR'; End;
  $01:Begin Mnem:='MONITOR'; Args:=Octal(I*64+J*8+K,3); End;
  $02:Case I Of
    0:Begin Mnem:='SETVL'; Args:=AReg(K); End;
    1:Begin Mnem:='SETFP'; End;
    2:Begin Mnem:='CLRFP'; End;
    Else Begin Mnem:='OP002'; Args:=Octal(W1 And $1FF,3); End;
   End;
  $03:Begin Mnem:='SETVM'; Args:=SReg(J); End;
  $04:Begin Mnem:='EXIT'; End;
  $05:Begin Mnem:='JUMP'; Args:=BReg(J,K); End;
  $06:Begin Mnem:='JUMP'; Args:=Octal(Target,9); End;
  $07:Begin Mnem:='RJUMP'; Args:=Octal(Target,9); End;
  $08:Begin Mnem:='JAZ'; Args:=Octal(Target,9); End;
  $09:Begin Mnem:='JAN'; Args:=Octal(Target,9); End;
  $0A:Begin Mnem:='JAP'; Args:=Octal(Target,9); End;
  $0B:Begin Mnem:='JAM'; Args:=Octal(Target,9); End;
  $0C:Begin Mnem:='JSZ'; Args:=Octal(Target,9); End;
  $0D:Begin Mnem:='JSN'; Args:=Octal(Target,9); End;
  $0E:Begin Mnem:='JSP'; Args:=Octal(Target,9); End;
  $0F:Begin Mnem:='JSM'; Args:=Octal(Target,9); End;

  $10:Begin Mnem:='LA'; Args:=AReg(I)+','+Octal(Imm,8); End;
  $11:Begin Mnem:='LAC'; Args:=AReg(I)+','+Octal(Imm,8); End;
  $12:Begin Mnem:='LA'; Args:=AReg(I)+','+Octal(J*8+K,2); End;
  $13:Begin Mnem:='SA'; Args:=AReg(I)+','+SReg(J); End;
  $14:Begin Mnem:='LAB'; Args:=AReg(I)+','+BReg(J,K); End;
  $15:Begin Mnem:='SBA'; Args:=BReg(J,K)+','+AReg(I); End;
  $16:Begin Mnem:='POPCNT'; Args:=AReg(I)+','+SReg(J); End;
  $17:Begin Mnem:='LEADZ'; Args:=AReg(I)+','+SReg(J); End;
  $18:Begin Mnem:='AADD'; Args:=AReg(I)+','+AReg(J)+','+AReg(K); End;
  $19:Begin Mnem:='ASUB'; Args:=AReg(I)+','+AReg(J)+','+AReg(K); End;
  $1A:Begin Mnem:='AMUL'; Args:=AReg(I)+','+AReg(J)+','+AReg(K); End;
  $1B:Begin Mnem:='IOSTAT'; Args:=AReg(I)+','+Octal(J*8+K,2); End;
  $1C:Begin Mnem:='LDB'; Args:='B00-B77,(A0)'; End;
  $1D:Begin Mnem:='STB'; Args:='B00-B77,(A0)'; End;
  $1E:Begin Mnem:='LDT'; Args:='T00-T77,(A0)'; End;
  $1F:Begin Mnem:='STT'; Args:='T00-T77,(A0)'; End;

  $20:Begin Mnem:='LS'; Args:=SReg(I)+','+Octal(Imm,8); End;
  $21:Begin Mnem:='LSC'; Args:=SReg(I)+','+Octal(Imm,8); End;
  $22:Begin Mnem:='RMASK'; Args:=SReg(I)+','+Decimal(64-(J*8+K)); End;
  $23:Begin Mnem:='LMASK'; Args:=SReg(I)+','+Decimal(J*8+K); End;
  $24:Begin Mnem:='SAND'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $25:Begin Mnem:='SANDN'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $26:Begin Mnem:='SXOR'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $27:Begin Mnem:='SEQV'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $28:Begin Mnem:='SMERGE'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $29:Begin Mnem:='SOR'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $2A:Begin Mnem:='SHL0'; Args:='S0,'+SReg(I)+','+Decimal(J*8+K); End;
  $2B:Begin Mnem:='SHR0'; Args:='S0,'+SReg(I)+','+Decimal(J*8+K); End;
  $2C:Begin Mnem:='SHL'; Args:=SReg(I)+','+SReg(J)+','+Decimal(J*8+K); End;
  $2D:Begin Mnem:='SHR'; Args:=SReg(I)+','+SReg(J)+','+Decimal(J*8+K); End;
  $2E:Begin Mnem:='DSHL'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $2F:Begin Mnem:='DSHR'; Args:=SReg(I)+','+SReg(J)+','+AReg(K); End;
  $30:Begin Mnem:='SADD'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $31:Begin Mnem:='SSUB'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $32:Begin Mnem:='FADD'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $33:Begin Mnem:='FSUB'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $34:Begin Mnem:='FMUL'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $35:Begin Mnem:='FHMUL'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $36:Begin Mnem:='FRMUL'; Args:=SReg(I)+','+SReg(J)+','+SReg(K); End;
  $37:Begin Mnem:='FRCPIT'; Args:=SReg(I)+','+SReg(J); End;
  $38:Begin Mnem:='FRCPA'; Args:=SReg(I)+','+SReg(J); End;
  $39:Begin Mnem:='FNORM'; Args:=SReg(I)+','+SReg(J)+','+AReg(K); End;
  $3A:Begin Mnem:='RCLK'; Args:=SReg(I); End;
  $3B:Begin Mnem:='GETVM'; Args:=SReg(I); End;
  $3C:Begin Mnem:='LST'; Args:=SReg(I)+','+TReg(J,K); End;
  $3D:Begin Mnem:='STS'; Args:=TReg(J,K)+','+SReg(I); End;
  $3E:Begin Mnem:='VGET'; Args:=SReg(I)+','+VReg(J)+'['+AReg(K)+']'; End;
  $3F:Begin Mnem:='VSET'; Args:=VReg(I)+'['+AReg(K)+'],'+SReg(J); End;

  $40..$47:Begin Mnem:='LDA'; Args:=AReg(I)+',(A'+Chr(Ord('0')+H)+'+'+Octal(Imm,8)+')'; End;
  $48..$4F:Begin Mnem:='STA'; Args:='(A'+Chr(Ord('0')+H)+'+'+Octal(Imm,8)+'),'+AReg(I); End;
  $50..$57:Begin Mnem:='LDS'; Args:=SReg(I)+',(A'+Chr(Ord('0')+H)+'+'+Octal(Imm,8)+')'; End;
  $58..$5F:Begin Mnem:='STS'; Args:='(A'+Chr(Ord('0')+H)+'+'+Octal(Imm,8)+'),'+SReg(I); End;

  $60:Begin Mnem:='VANDS'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $61:Begin Mnem:='VAND'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  $62:Begin Mnem:='VORS'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $63:Begin Mnem:='VOR'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  $64:Begin Mnem:='VXORS'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $65:Begin Mnem:='VXOR'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  $66:Begin Mnem:='VMERGES'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $67:Begin Mnem:='VMERGE'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  $68:Begin Mnem:='VSHL'; Args:=VReg(I)+','+VReg(J)+','+AReg(K); End;
  $69:Begin Mnem:='VSHR'; Args:=VReg(I)+','+VReg(J)+','+AReg(K); End;
  $6A:Begin Mnem:='VDSHL'; Args:=VReg(I)+','+VReg(J)+','+AReg(K); End;
  $6B:Begin Mnem:='VDSHR'; Args:=VReg(I)+','+VReg(J)+','+AReg(K); End;
  $6C:Begin Mnem:='VADDS'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $6D:Begin Mnem:='VADD'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  $6E:Begin Mnem:='VSUBS'; Args:=VReg(I)+','+SReg(J)+','+VReg(K); End;
  $6F:Begin Mnem:='VSUB'; Args:=VReg(I)+','+VReg(J)+','+VReg(K); End;
  Else Begin
   Mnem:='PARCEL';
   Args:=Octal(W1,6);
  End;
 End;
 If HasSecond=False Then
  If IsTwoParcel(Op) Then Begin
   Mnem:='TRUNCATED';
   Args:=Octal(W1,6);
  End;
 If Args<>'' Then Decode:=Mnem+' '+Args Else Decode:=Mnem;
End;

Procedure Usage;
Begin
 WriteLn('DISCRAY1 ',Version,' - Desassembleur Cray-1');
 WriteLn('Syntaxe: DISCRAY1 fichier [-O=listing] [-A=adresse] [-LE] [-NC]');
 WriteLn('  -O=nom      Ecrit le listing dans un fichier (sinon: ecran)');
 WriteLn('  -A=adresse  Adresse initiale de parcelle, en octal');
 WriteLn('  -LE         Parcelles en ordre petit-boutiste');
 WriteLn('  -NC         Ne pas afficher les parcelles machine');
 Halt(1);
End;

Procedure ReadOptions;
Var
 N:Integer;
 S,U:String;
 Value:LongInt;
Begin
 If ParamCount=0 Then Usage;
 InputName:=ParamStr(1);
 OutputName:='';
 LittleEndian:=False;
 ShowCode:=True;
 ParcelAddress:=0;
 For N:=2 To ParamCount Do Begin
  S:=ParamStr(N);
  U:=Upper(S);
  If Copy(U,1,3)='-O=' Then OutputName:=Copy(S,4,255) Else
  If Copy(U,1,3)='/O=' Then OutputName:=Copy(S,4,255) Else
  If Copy(U,1,3)='-A=' Then Begin
   If Not ParseNumber(Copy(S,4,255),Value) Then Begin
    WriteLn('Adresse incorrecte: ',S);
    Halt(1);
   End;
   ParcelAddress:=Value;
  End Else If Copy(U,1,3)='/A=' Then Begin
   If Not ParseNumber(Copy(S,4,255),Value) Then Begin
    WriteLn('Adresse incorrecte: ',S);
    Halt(1);
   End;
   ParcelAddress:=Value;
  End Else If (U='-LE') Or (U='/LE') Then LittleEndian:=True Else
  If (U='-NC') Or (U='/NC') Then ShowCode:=False Else Begin
   WriteLn('Option inconnue: ',S);
   Halt(1);
  End;
 End;
End;

Procedure Disassemble;
Var
 W1,W2:Word;
 Op:Byte;
 Start:LongInt;
 HasSecond:Boolean;
 Raw,Line:String;
Begin
 InstructionCount:=0;
 ErrorCount:=0;
 While ReadParcel(W1) Do Begin
  Start:=ParcelAddress;
  Inc(ParcelAddress);
  Op:=W1 Shr 9;
  HasSecond:=True;
  W2:=0;
  If IsTwoParcel(Op) Then Begin
   HasSecond:=ReadParcel(W2);
   If HasSecond Then Inc(ParcelAddress) Else Inc(ErrorCount);
  End;
  Raw:='';
  If ShowCode Then Begin
   Raw:=Octal(W1,6);
   If IsTwoParcel(Op) Then
    If HasSecond Then Raw:=Raw+' '+Octal(W2,6) Else Raw:=Raw+' ------';
   While Length(Raw)<14 Do Raw:=Raw+' ';
  End;
  Line:=ParcelLocation(Start)+'  '+Raw+'  '+Decode(W1,W2,HasSecond);
  Emit(Line);
  Inc(InstructionCount);
 End;
End;

Var
 IOResultCode:Integer;
Begin
 ReadOptions;
 Assign(InputFile,InputName);
 {$I-} Reset(InputFile,1); {$I+}
 IOResultCode:=IOResult;
 If IOResultCode<>0 Then Begin
  WriteLn('Impossible d''ouvrir "',InputName,'" (erreur ',IOResultCode,').');
  Halt(2);
 End;
 ListingOpen:=False;
 If OutputName<>'' Then Begin
  Assign(Listing,OutputName);
  {$I-} Rewrite(Listing); {$I+}
  IOResultCode:=IOResult;
  If IOResultCode<>0 Then Begin
   Close(InputFile);
   WriteLn('Impossible de creer "',OutputName,'" (erreur ',IOResultCode,').');
   Halt(3);
  End;
  ListingOpen:=True;
 End;
 Emit('; DISCRAY1 '+Version+' - '+InputName);
 Emit('; Adresse    Parcelle(s)      Instruction');
 Disassemble;
 Emit('; '+Decimal(InstructionCount)+' instruction(s), '+
      Decimal(ErrorCount)+' erreur(s).');
 Close(InputFile);
 If ListingOpen Then Close(Listing);
 If ErrorCount<>0 Then Halt(4);
End.
