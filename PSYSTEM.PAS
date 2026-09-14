{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Environnement de commandes inspire du UCSD p-System.
 @license: MIT }

Program PSYSTEM;

{$A-,B-,I-,R-,S-}

Uses Dos;

Const
 Version='1.0';

Var
 WorkFile,ProgramFile:String;
 Finished:Boolean;

Function TrimString(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 TrimString:=S
End;

Function UpperString(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do S[I]:=UpCase(S[I]);UpperString:=S
End;

Function QuoteName(S:String):String;Begin
 if Pos(' ',S)<>0 Then QuoteName:='"'+S+'"'else QuoteName:=S
End;

Function ReplaceExtension(S,Ext:String):String;
Var
 I,P:Integer;
Begin
 P:=0;
 For I:=Length(S)downto 1 do Begin
  if S[I]='.'Then Begin
   P:=I;Break
  End;
  if S[I]in['\','/',':']Then Break
 End;
 if P<>0 Then S:=Copy(S,1,P-1);ReplaceExtension:=S+Ext
End;

Function ToolName(VariableName,DefaultName:String):String;
Var
 R:String;
Begin
 R:=GetEnv(VariableName);if R=''Then R:=DefaultName;ToolName:=R
End;

Function RunShell(CommandLine:String):Integer;
Var
 ShellName,Parameters:String;
 ResultCode:Word;
Begin
 ShellName:=GetEnv('COMSPEC');
 if ShellName=''Then ShellName:='COMMAND.COM';
 Parameters:='/C '+CommandLine;SwapVectors;Exec(ShellName,Parameters);SwapVectors;
 if DosError<>0 Then Begin
  WriteLn('Unable to start command processor (error ',DosError,').');RunShell:=DosError
 End else
 Begin
  ResultCode:=DosExitCode;RunShell:=Lo(ResultCode)
 End
End;

Procedure AskFile(Prompt:String;Var Name:String);
Var
 S:String;
Begin
 if Name<>''Then Write(Prompt,' [',Name,']: ')else Write(Prompt,': ');
 ReadLn(S);S:=TrimString(S);if S<>''Then Name:=S
End;

Function FileExists(Name:String):Boolean;
Var
 F:File;
 Exists:Boolean;
Begin
 Assign(F,Name);Reset(F,1);Exists:=IOResult=0;
 if Exists Then Begin
  Close(F);if IOResult<>0 Then Exists:=False
 End;
 FileExists:=Exists
End;

Procedure EditCommand;
Var
 Editor:String;
Begin
 AskFile('Edit file',WorkFile);if WorkFile=''Then Exit;
 Editor:=ToolName('PSYSTEM_EDITOR',GetEnv('EDITOR'));
 if Editor=''Then Editor:='EDIT';
 RunShell(Editor+' '+QuoteName(WorkFile))
End;

Function CompileWork(AskName:Boolean):Boolean;
Var
 Compiler:String;
 Code:Integer;
Begin
 CompileWork:=False;if AskName or(WorkFile='')Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if not FileExists(WorkFile)Then Begin
  WriteLn('File not found: ',WorkFile);Exit
 End;
 Compiler:=ToolName('PSYSTEM_COMPILER','FPC');
 WriteLn('Compiling ',WorkFile,' ...');Code:=RunShell(Compiler+' '+QuoteName(WorkFile));
 if Code<>0 Then Begin
  WriteLn('Compile failed (status ',Code,').');Exit
 End;
 ProgramFile:=ReplaceExtension(WorkFile,'.exe');CompileWork:=True;
 WriteLn('Compilation complete.')
End;

Procedure RunCommand;Begin
 if WorkFile=''Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if(ProgramFile='')or not FileExists(ProgramFile)Then  if not CompileWork(False)Then Exit;
 WriteLn('Running ',ProgramFile,' ...');RunShell(QuoteName(ProgramFile))
End;

Procedure ExecuteCommand;
Var
 Name:String;
Begin
 Name:=ProgramFile;AskFile('Program file',Name);if Name=''Then Exit;
 if not FileExists(Name)Then Begin
  WriteLn('File not found: ',Name);Exit
 End;
 ProgramFile:=Name;RunShell(QuoteName(Name))
End;

Procedure LinkCommand;
Var
 Modules,OutputName,Linker,CommandLine:String;
 Code:Integer;
Begin
 Write('Object files: ');ReadLn(Modules);Modules:=TrimString(Modules);
 if Modules=''Then Exit;OutputName:=ProgramFile;AskFile('Output program',OutputName);
 if OutputName=''Then Exit;Linker:=ToolName('PSYSTEM_LINKER','FPC');
 CommandLine:=Linker+' '+Modules+' -o'+QuoteName(OutputName);
 WriteLn('Linking ',OutputName,' ...');Code:=RunShell(CommandLine);
 if Code=0 Then Begin
  ProgramFile:=OutputName;WriteLn('Link complete.')
 End
 else WriteLn('Link failed (status ',Code,').')
End;

Const
 OPK_NONE  = 0;
 OPK_UB    = 1;
 OPK_SB    = 2;
 OPK_W     = 3;
 OPK_BIG   = 4;
 OPK_UBUB  = 5;
 OPK_UBBIG = 6;
 OPK_DBBIG = 7;
 OPK_LSA   = 8;
 OPK_LDC   = 9;
 OPK_XJP   = 10;
 OPK_SLDC  = 200;
 OPK_DB    = 201;

Type
 TMnem=String[6];

Const
 Mnem128:Array[128..255]Of TMnem = (
  'ABI','ABR','ADI','ADR','LAND','DIF','DVI','DVR',         { 128..135 }
  'CHK','FLO','FLT','INN','INT','IOR','MODI','MPI',         { 136..143 }
  'MPR','NGI','NGR','LNOT','SRS','SBI','SBR','SGS',         { 144..151 }
  'SQI','SQR','STO','IXS','UNI','LDE','CSP','LDCN',         { 152..159 }
  'ADJ','FJP','INC','IND','IXA','LAO','LSA','LAE',          { 160..167 }
  'MOV','LDO','SAS','SRO','XJP','RNP','CIP','EQU',          { 168..175 }
  'GEQ','GRT','LDA','LDC','LEQ','LES','LOD','NEQ',          { 176..183 }
  'STR','UJP','LDP','STP','LDM','STM','LDB','STB',          { 184..191 }
  'IXP','RBP','CBP','EQUI','GEQI','GRTI','LLA','LDCI',      { 192..199 }
  'LEQI','LESI','LDL','NEQI','STL','CXP','CLP','CGP',       { 200..207 }
  'LPA','STE','???','EFJ','NFJ','BPT','XIT','NOP',          { 208..215 }
  'SLDL1','SLDL2','SLDL3','SLDL4','SLDL5','SLDL6','SLDL7','SLDL8',
  'SLDL9','SLDL10','SLDL11','SLDL12','SLDL13','SLDL14','SLDL15','SLDL16',
  'SLDO1','SLDO2','SLDO3','SLDO4','SLDO5','SLDO6','SLDO7','SLDO8',
  'SLDO9','SLDO10','SLDO11','SLDO12','SLDO13','SLDO14','SLDO15','SLDO16',
  'SIND0','SIND1','SIND2','SIND3','SIND4','SIND5','SIND6','SIND7'
 );

 Kind128:Array[128..255]Of Byte = (
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_UBBIG,OPK_UB,OPK_NONE,
  OPK_UB,OPK_SB,OPK_BIG,OPK_BIG,OPK_BIG,OPK_BIG,OPK_LSA,OPK_UBBIG,
  OPK_BIG,OPK_BIG,OPK_UB,OPK_BIG,OPK_XJP,OPK_UB,OPK_UB,OPK_UB,
  OPK_UB,OPK_UB,OPK_DBBIG,OPK_LDC,OPK_UB,OPK_UB,OPK_DBBIG,OPK_UB,
  OPK_DBBIG,OPK_SB,OPK_NONE,OPK_NONE,OPK_UB,OPK_UB,OPK_NONE,OPK_NONE,
  OPK_UBUB,OPK_UB,OPK_UB,OPK_NONE,OPK_NONE,OPK_NONE,OPK_BIG,OPK_W,
  OPK_NONE,OPK_NONE,OPK_BIG,OPK_NONE,OPK_BIG,OPK_UBUB,OPK_UB,OPK_UB,
  OPK_UBUB,OPK_UBBIG,OPK_NONE,OPK_SB,OPK_SB,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
  OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE
 );

Var
 InFile:Text;
 OutFile:File;
 BBuf:Array[0..4095]Of Byte;
 BLen:Integer;
 OutPos:LongInt;
 LineNum:LongInt;
 ErrCount:Integer;
 InName,OutName:String;

Procedure FlushBuf;
Var Wr:Word;
Begin
 If BLen>0 Then Begin BlockWrite(OutFile,BBuf,BLen,Wr); BLen:=0; End;
End;

Procedure Emit(B:Byte);
Begin
 BBuf[BLen]:=B; Inc(BLen); Inc(OutPos);
 If BLen>=SizeOf(BBuf) Then FlushBuf;
End;

Procedure Err(Msg:String);
Begin
 WriteLn('Ligne ',LineNum,': ',Msg); Inc(ErrCount);
End;

Procedure EmitUB(V:LongInt);
Begin
 If (V<0) Or (V>255) Then Begin Err('UB hors limite'); V:=0; End;
 Emit(Byte(V));
End;

Procedure EmitSB(V:LongInt);
Begin
 If (V<-128) Or (V>127) Then Begin Err('SB hors limite'); V:=0; End;
 If V<0 Then V:=V+256;
 Emit(Byte(V));
End;

Procedure EmitW(V:LongInt);
Begin
 If V<0 Then V:=V+65536;
 Emit(Byte(V And $FF));
 Emit(Byte((V Shr 8) And $FF));
End;

Procedure EmitBig(V:LongInt);
Begin
 If (V<0) Or (V>32767) Then Begin Err('BIG hors limite'); V:=0; End;
 If V<128 Then Emit(Byte(V))
 Else Begin
  Emit(Byte($80 Or ((V Shr 8) And $7F)));
  Emit(Byte(V And $FF));
 End;
End;

Function IsDigit(C:Char):Boolean;
Begin IsDigit:=(C>='0')And(C<='9'); End;

Function IsHexDigit(C:Char):Boolean;
Begin
 IsHexDigit:=IsDigit(C) Or ((C>='A')And(C<='F')) Or ((C>='a')And(C<='f'));
End;

Function IsAlpha(C:Char):Boolean;
Begin
 IsAlpha:=((C>='A')And(C<='Z')) Or ((C>='a')And(C<='z'));
End;

Procedure SkipSp(Var P:Integer; S:String);
Begin
 While (P<=Length(S)) And ((S[P]=' ') Or (S[P]=#9)) Do Inc(P);
End;

Function ParseNum(Var P:Integer; S:String; Var V:LongInt):Boolean;
Var Sign:Integer; HasH,Got:Boolean; D:Integer; C:Char;
Begin
 SkipSp(P,S);
 ParseNum:=False; V:=0; Sign:=1; Got:=False; HasH:=False;
 If P>Length(S) Then Exit;
 If S[P]='+' Then Inc(P)
 Else If S[P]='-' Then Begin Sign:=-1; Inc(P); End;
 If (P<=Length(S)) And (S[P]='$') Then Begin HasH:=True; Inc(P); End;
 While P<=Length(S) Do Begin
  C:=S[P];
  If HasH Then Begin
   If Not IsHexDigit(C) Then Break;
   If IsDigit(C) Then D:=Ord(C)-Ord('0')
   Else D:=Ord(UpCase(C))-Ord('A')+10;
   V:=V*16+D; Got:=True;
  End
  Else Begin
   If Not IsDigit(C) Then Break;
   V:=V*10+(Ord(C)-Ord('0')); Got:=True;
  End;
  Inc(P);
 End;
 V:=V*Sign;
 ParseNum:=Got;
End;

Function ParseId(Var P:Integer; S:String; Var Id:String):Boolean;
Begin
 SkipSp(P,S); Id:='';
 If (P>Length(S)) Or (Not IsAlpha(S[P])) Then Begin ParseId:=False; Exit; End;
 While (P<=Length(S)) And (IsAlpha(S[P]) Or IsDigit(S[P])) Do Begin
  Id:=Id+UpCase(S[P]); Inc(P);
 End;
 ParseId:=True;
End;

Function ParseQStr(Var P:Integer; S:String; Var Q:String):Boolean;
Begin
 SkipSp(P,S); Q:='';
 If (P>Length(S)) Or (S[P]<>'"') Then Begin ParseQStr:=False; Exit; End;
 Inc(P);
 While (P<=Length(S)) And (S[P]<>'"') Do Begin
  Q:=Q+S[P]; Inc(P);
 End;
 If P>Length(S) Then Err('cha'+#238+'ne non termin'+#130+'e')
 Else Inc(P);
 ParseQStr:=True;
End;

Function ExpectComma(Var P:Integer; S:String):Boolean;
Begin
 SkipSp(P,S);
 If (P>Length(S)) Or (S[P]<>',') Then Begin ExpectComma:=False; Exit; End;
 Inc(P); ExpectComma:=True;
End;

Function LookupMn(Mn:String; Var Code:Byte; Var Kind:Byte):Boolean;
Var I,P:Integer; N:LongInt;
Begin
 LookupMn:=False;
 If Mn='SLDC' Then Begin Code:=0; Kind:=OPK_SLDC; LookupMn:=True; Exit; End;
 If Mn='DB' Then Begin Code:=0; Kind:=OPK_DB; LookupMn:=True; Exit; End;
 If (Copy(Mn,1,4)='SLDL') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=1) And (N<=16) Then Begin
   Code:=Byte(215+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 If (Copy(Mn,1,4)='SLDO') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=1) And (N<=16) Then Begin
   Code:=Byte(231+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 If (Copy(Mn,1,4)='SIND') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=0) And (N<=7) Then Begin
   Code:=Byte(248+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 For I:=128 To 255 Do
  If Mnem128[I]=Mn Then Begin
   Code:=Byte(I); Kind:=Kind128[I]; LookupMn:=True; Exit;
  End;
End;

Function IsPrefixTok(S:String):Boolean;
Var I:Integer;
Begin
 IsPrefixTok:=False;
 If S='..' Then Begin IsPrefixTok:=True; Exit; End;
 If (Length(S)<>2) And (Length(S)<>6) Then Exit;
 For I:=1 To Length(S) Do
  If Not IsHexDigit(S[I]) Then Exit;
 IsPrefixTok:=True;
End;

Function FindMn(S:String):Integer;
Var P,Q:Integer; Tok:String;
Begin
 FindMn:=0; P:=1;
 While P<=Length(S) Do Begin
  While (P<=Length(S)) And (S[P]=' ') Do Inc(P);
  If P>Length(S) Then Exit;
  Q:=P;
  While (Q<=Length(S)) And (S[Q]<>' ') Do Inc(Q);
  Tok:=Copy(S,P,Q-P);
  If Not IsPrefixTok(Tok) Then Begin FindMn:=P; Exit; End;
  P:=Q;
 End;
End;

Procedure ProcessLine(S:String);
Var I,P:Integer; Mn,Q:String; Code,Kind:Byte; V,V2:LongInt;
Begin
 I:=Pos(';',S); If I>0 Then S:=Copy(S,1,I-1);
 While (Length(S)>0) And ((S[Length(S)]=' ')Or(S[Length(S)]=#9)Or(S[Length(S)]=#13)) Do
  S:=Copy(S,1,Length(S)-1);
 If S='' Then Exit;
 If (Pos('Addr',S)=1) Or (Pos('------',S)>=1) Or (Pos('Fichier',S)=1)
    Or (Pos('D'+#130+'but',S)=1) Or (Pos('Debut',S)=1)
    Or (Pos('Total',S)=1) Then Exit;
 P:=FindMn(S); If P=0 Then Exit;
 If Not ParseId(P,S,Mn) Then Exit;
 If Not LookupMn(Mn,Code,Kind) Then Begin
  Err('mn'+#130+'monique inconnu: '+Mn); Exit;
 End;
 Case Kind Of
  OPK_SLDC: Begin
   If Not ParseNum(P,S,V) Then Begin Err('SLDC: nombre attendu'); Exit; End;
   If (V<0) Or (V>127) Then Begin Err('SLDC hors limite (0..127)'); Exit; End;
   Emit(Byte(V));
  End;
  OPK_DB: Begin
   While ParseNum(P,S,V) Do Begin
    EmitUB(V);
    If Not ExpectComma(P,S) Then Break;
   End;
  End;
  OPK_NONE: Emit(Code);
  OPK_UB: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Err('UB attendu') Else EmitUB(V);
  End;
  OPK_SB: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Err('SB attendu') Else EmitSB(V);
  End;
  OPK_W: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Err('W attendu') Else EmitW(V);
  End;
  OPK_BIG: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Err('BIG attendu') Else EmitBig(V);
  End;
  OPK_UBUB: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Begin Err('UB,UB attendu'); Exit; End;
   If Not ExpectComma(P,S) Then Begin Err('virgule attendue'); Exit; End;
   If Not ParseNum(P,S,V2) Then Begin Err('2e UB attendu'); Exit; End;
   EmitUB(V); EmitUB(V2);
  End;
  OPK_UBBIG: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Begin Err('UB,BIG attendu'); Exit; End;
   If Not ExpectComma(P,S) Then Begin Err('virgule attendue'); Exit; End;
   If Not ParseNum(P,S,V2) Then Begin Err('BIG attendu'); Exit; End;
   EmitUB(V); EmitBig(V2);
  End;
  OPK_DBBIG: Begin
   Emit(Code);
   SkipSp(P,S);
   If (P<=Length(S)) And (UpCase(S[P])='L') Then Inc(P);
   If Not ParseNum(P,S,V) Then Begin Err('DB level attendu'); Exit; End;
   If Not ExpectComma(P,S) Then Begin Err('virgule attendue'); Exit; End;
   If Not ParseNum(P,S,V2) Then Begin Err('BIG attendu'); Exit; End;
   EmitUB(V); EmitBig(V2);
  End;
  OPK_LSA: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Begin Err('LSA: len attendu'); Exit; End;
   If Not ExpectComma(P,S) Then Begin Err('virgule attendue'); Exit; End;
   If Not ParseQStr(P,S,Q) Then Begin Err('"..." attendu'); Exit; End;
   If Length(Q)<>V Then Err('LSA: longueur ne correspond pas');
   EmitUB(V);
   For I:=1 To Length(Q) Do Emit(Byte(Q[I]));
  End;
  OPK_LDC: Begin
   Emit(Code);
   If Not ParseNum(P,S,V) Then Begin Err('LDC: count attendu'); Exit; End;
   EmitUB(V);
   For I:=1 To V Do Begin
    If Not ExpectComma(P,S) Then Begin Err('virgule attendue'); Exit; End;
    If Not ParseNum(P,S,V2) Then Begin Err('mot attendu'); Exit; End;
    EmitW(V2);
   End;
  End;
  OPK_XJP: Begin
   Emit(Code);
   Err('XJP: tableau de cas non support'+#130+', utiliser DB pour la suite');
  End;
 End;
End;


Function AssemblePCode(InputName,OutputName:String):Integer;
Var
 Line:String;
 ReadCode,CloseCode:Integer;
Begin
 AssemblePCode:=2;InName:=InputName;OutName:=OutputName;
 If UpperString(OutName)=UpperString(InName) Then Begin
  WriteLn('Erreur: source et destination identiques');Exit
 End;
 Assign(InFile,InName);Reset(InFile);
 If IOResult<>0 Then Begin WriteLn('Erreur: ouverture ',InName);Exit End;
 Assign(OutFile,OutName);Rewrite(OutFile,1);
 If IOResult<>0 Then Begin Close(InFile);ReadCode:=IOResult;
  WriteLn('Erreur: creation ',OutName);Exit
 End;
 OutPos:=0;BLen:=0;LineNum:=0;ErrCount:=0;ReadCode:=0;
 While not Eof(InFile)do Begin
  ReadLn(InFile,Line);ReadCode:=IOResult;
  If ReadCode<>0 Then Begin Err('erreur de lecture');Break End;
  Inc(LineNum);ProcessLine(Line)
 End;
 FlushBuf;Close(InFile);CloseCode:=IOResult;
 Close(OutFile);if CloseCode=0 Then CloseCode:=IOResult else ReadCode:=IOResult;
 If(ReadCode<>0)or(CloseCode<>0)Then Inc(ErrCount);
 WriteLn('Assemble : ',OutPos,' octet(s), ',ErrCount,' erreur(s)');
 If ErrCount=0 Then AssemblePCode:=0 else AssemblePCode:=1
End;


Procedure AssembleCommand;
Var
 Name,OutputName:String;
 Code:Integer;
Begin
 Name:='';AskFile('Source assembleur p-Code',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.ASM')Then Name:=Name+'.ASM';
 OutputName:=ReplaceExtension(Name,'.CODE');AskFile('Fichier p-Code produit',OutputName);
 if OutputName=''Then Exit;Code:=AssemblePCode(Name,OutputName);
 if Code=0 Then Begin ProgramFile:=OutputName;WriteLn('Assemblage termine.')End
 else WriteLn('Echec de l''assemblage (code ',Code,').')
End;

Procedure DebugCommand;
Var
 Name,Debugger:String;
Begin
 Name:=ProgramFile;AskFile('Program to debug',Name);if Name=''Then Exit;
 Debugger:=ToolName('PSYSTEM_DEBUGGER','DEBUG');RunShell(Debugger+' '+QuoteName(Name))
End;

Procedure ListFiles;
Var
 Mask:String;
 Info:SearchRec;
Begin
 Mask:='*.*';AskFile('File mask',Mask);FindFirst(Mask,AnyFile,Info);
 if DosError<>0 Then Begin
  WriteLn('No files.');Exit
 End;
 While DosError=0 do Begin
  if(Info.Name<>'.')and(Info.Name<>'..')Then Begin
   Write(Info.Name:20);
   if(Info.Attr and Directory)<>0 Then WriteLn('   <DIR>')else WriteLn(Info.Size:10)
  End;FindNext(Info)
 End
End;

Procedure CopyFileCommand;
Var
 Source,Target:String;
 A,B:File;
 Buffer:Array[1..8192]of Byte;
 N,W:Word;
 OK:Boolean;
Begin
 Source:='';Target:='';AskFile('Copy from',Source);if Source=''Then Exit;
 AskFile('Copy to',Target);if Target=''Then Exit;
 if UpperString(FExpand(Source))=UpperString(FExpand(Target))Then Begin
  WriteLn('Source and destination are the same file.');Exit
 End;
 Assign(A,Source);Reset(A,1);if IOResult<>0 Then Begin
  WriteLn('Cannot open ',Source);Exit
 End;
 Assign(B,Target);Rewrite(B,1);if IOResult<>0 Then Begin
  Close(A);WriteLn('Cannot create ',Target);Exit
 End;
 OK:=True;
 Repeat
 BlockRead(A,Buffer,SizeOf(Buffer),N);if IOResult<>0 Then Begin
  OK:=False;Break
 End;
 if N<>0 Then Begin
  BlockWrite(B,Buffer,N,W);if(IOResult<>0)or(W<>N)Then OK:=False
 End
 Until(N=0)or not OK;
 Close(A);if IOResult<>0 Then OK:=False;Close(B);if IOResult<>0 Then OK:=False;
 if OK Then WriteLn('Copy complete.')else WriteLn('Copy failed.')
End;

Procedure RenameFileCommand;
Var
 OldName,NewName:String;
 F:File;
Begin
 OldName:='';NewName:='';AskFile('Rename file',OldName);if OldName=''Then Exit;
 AskFile('New name',NewName);if NewName=''Then Exit;
 Assign(F,OldName);Rename(F,NewName);
 if IOResult<>0 Then WriteLn('Rename failed.')else WriteLn('Rename complete.')
End;

Procedure DeleteFileCommand;
Var
 Name,Answer:String;
 F:File;
Begin
 Name:='';AskFile('Delete file',Name);if Name=''Then Exit;
 Write('Delete ',Name,' (Y/N)? ');ReadLn(Answer);
 if(Answer='')or not(UpCase(Answer[1])='Y')Then Exit;
 Assign(F,Name);Erase(F);
 if IOResult<>0 Then WriteLn('Delete failed.')else WriteLn('Deleted.')
End;

Procedure VolumeCommand;
Var
 DirectoryName:String;
Begin
 GetDir(0,DirectoryName);WriteLn('Current volume and directory: ',DirectoryName);
 WriteLn('Free bytes: ',DiskFree(0));WriteLn('Total bytes: ',DiskSize(0))
End;

Procedure FileCommand;
Var
 S:String;
 Done:Boolean;
Begin
 Done:=False;Repeat
 Write('File: L(ist, C(opy, R(ename, D(elete, V(olume, Q(uit ? ');ReadLn(S);
 S:=UpperString(TrimString(S));if S=''Then Continue;
 Case S[1]of
 'L':ListFiles;
 'C':CopyFileCommand;
 'R':RenameFileCommand;
 'D':DeleteFileCommand;
 'V':VolumeCommand;
 'Q':Done:=True;
 '?':WriteLn('Liste, Copie, Renommage, Suppression, Volume, Quitter');
 else WriteLn('Unknown file command.')
End
Until Done
End;

Procedure Help;Begin
 WriteLn('E  Editer le fichier source de travail');
 WriteLn('R  Compiler si necessaire, puis executer le programme de travail');
 WriteLn('F  Ouvrir le gestionnaire de fichiers');
 WriteLn('C  Compiler le fichier source Pascal courant');
 WriteLn('L  Lier des fichiers objets');
 WriteLn('X  Executer un programme deja compile');
 WriteLn('A  Assembler un fichier source');
 WriteLn('D  Lancer le debogueur');
 WriteLn('Q  Quitter PSYSTEM');
 WriteLn;
 WriteLn('Les outils externes peuvent etre choisis avec PSYSTEM_EDITOR,');
 WriteLn('PSYSTEM_COMPILER, PSYSTEM_LINKER et PSYSTEM_DEBUGGER.');
 WriteLn('L''assembleur p-Code est directement integre a PSYSTEM.')
End;

Procedure Prompt;
Var
 S:String;
Begin
 WriteLn;
 Write('Command: E(dit, R(un, F(ile, C(omp, L(ink, ');
 Write('X(ecute, A(ssem, D(ebug, Q)uit ? ');ReadLn(S);S:=UpperString(TrimString(S));
 if S=''Then Exit;
 Case S[1]of
 'E':EditCommand;
 'R':RunCommand;
 'F':FileCommand;
 'C':if CompileWork(True)Then Begin
 End;
 'L':LinkCommand;
 'X':ExecuteCommand;
 'A':AssembleCommand;
 'D':DebugCommand;
 'Q':Finished:=True;
 '?':Help;
 else WriteLn('Unknown command. Type ? for help.')
End
End;

Procedure CommandLine;
Var
 I:Integer;
 S:String;
Begin
 WorkFile:='';ProgramFile:='';
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')or(UpperString(S)='HELP')Then Begin
   WriteLn('PSYSTEM ',Version,' - Cette commande permet lancer ',
   'l''environnement de commande UCSD p-System.');
   Help;
   Halt(0)
  End else if WorkFile=''Then WorkFile:=S
  else
  Begin
   WriteLn('Syntaxe : PSYSTEM [fichier-de-travail]');
   Halt(1)
  End
 End;
 if WorkFile<>''Then ProgramFile:=ReplaceExtension(WorkFile,'.exe')
End;

BEGIN
 CommandLine;Finished:=False;
 WriteLn('UCSD p-System compatible command environment ',Version);
 if WorkFile<>''Then WriteLn('Work file: ',WorkFile);
 Repeat Prompt Until Finished;
 WriteLn('System halted.')
END.
