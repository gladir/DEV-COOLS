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

Type
 TPSYSTEMTarget=(ptAppleHeath,ptUCSDPascalII,ptUCSDPSystemIII,ptUCSDPSystemIV);

Var
 WorkFile,ProgramFile:String;
 Finished:Boolean;
 CurrentTarget:TPSYSTEMTarget;

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
Function CompilePascalPCode(SourceName,CodeName:String):Integer;Forward;

Function CompileWork(AskName:Boolean):Boolean;
Var
 Code:Integer;
Begin
 CompileWork:=False;if AskName or(WorkFile='')Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if not FileExists(WorkFile)Then Begin
  WriteLn('File not found: ',WorkFile);Exit
 End;
 ProgramFile:=ReplaceExtension(WorkFile,'.CODE');
 WriteLn('Compilation UCSD de ',WorkFile,' ...');
 Code:=CompilePascalPCode(WorkFile,ProgramFile);
 if Code<>0 Then Begin
  WriteLn('Compile failed (status ',Code,').');Exit
 End;
 CompileWork:=True;
 WriteLn('Compilation complete.')
End;

Procedure RunCommand;Begin
 if WorkFile=''Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if(ProgramFile='')or not FileExists(ProgramFile)Then  if not CompileWork(False)Then Exit;
 WriteLn('Running ',ProgramFile,' ...');RunShell(QuoteName(ProgramFile))
End;

Type
 TPCodeMemory=Array[0..65534]of Byte;
 PPCodeMemory=^TPCodeMemory;
 TPCodeData=Array[0..8191]of Integer;
 PPCodeData=^TPCodeData;

Var
 PCode_Mem:PPCodeMemory;
 PCode_Data:PPCodeData;
 PCode_CodeSize,PCode_PC,PCode_SP,PCode_MP,PCode_Cycles:LongInt;
 PCode_Halted:Boolean;
 PCode_ExitCode:Integer;

Function PCode_IntToStr(V:LongInt):String;
Var
 S:String;
Begin
 Str(V,S);PCode_IntToStr:=S
End;

Procedure PCode_Write(S:String);Begin
 Write(S)
End;

Procedure PCode_PutChar(C:Char);Begin
 Write(C)
End;

Function PCode_LoadRaw(Const FileName:String):Boolean;
Var
 F:File;
 Sz,SegmentSize,SegmentPos,AttrPos,LoadedSize:LongInt;
 ReadCount:Word;
 Header:Array[0..511]of Byte;
 ProcCount:Byte;
Begin
 PCode_LoadRaw:=False;Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Exit;
 Sz:=FileSize(F);
 if Sz<0 Then Begin
  Close(F);if IOResult<>0 Then Begin
  End;WriteLn('Fichier p-Code trop grand.');Exit
 End;
 FillChar(PCode_Mem^,SizeOf(TPCodeMemory),0);ReadCount:=0;
 LoadedSize:=Sz;
 if Sz>=512 Then Begin
  BlockRead(F,Header,512,ReadCount);SegmentPos:=(Header[0]or(Header[1]shl 8))*512;
  SegmentSize:=Header[2]or(Header[3]shl 8);
  if(ReadCount=512)and(SegmentPos>=512)and(SegmentSize>=14)and
   (SegmentPos+SegmentSize<=Sz)and(SegmentSize<=SizeOf(TPCodeMemory))Then Begin
   Seek(F,SegmentPos);ReadCount:=0;BlockRead(F,PCode_Mem^,SegmentSize,ReadCount);
   LoadedSize:=SegmentSize;ProcCount:=PCode_Mem^[SegmentSize-2];
   AttrPos:=PCode_Mem^[SegmentSize-4]or(PCode_Mem^[SegmentSize-3]shl 8);
   if(ProcCount<1)or(AttrPos<0)or(AttrPos>SegmentSize-14)Then Begin
    Close(F);if IOResult<>0 Then Begin End;
    WriteLn('Dictionnaire de procedures invalide.');Exit
   End;PCode_CodeSize:=AttrPos
  End else Begin
   if Sz>SizeOf(TPCodeMemory)Then Begin Close(F);if IOResult<>0 Then Begin End;Exit End;
   Seek(F,0);ReadCount:=0;if Sz>0 Then BlockRead(F,PCode_Mem^,Sz,ReadCount);
   LoadedSize:=Sz;PCode_CodeSize:=Sz
  End
 End else Begin
  if Sz>SizeOf(TPCodeMemory)Then Begin Close(F);if IOResult<>0 Then Begin End;Exit End;
  if Sz>0 Then BlockRead(F,PCode_Mem^,Sz,ReadCount);PCode_CodeSize:=Sz
 End;
 if(IOResult<>0)or(ReadCount<>LoadedSize)Then Begin
  Close(F);if IOResult<>0 Then Begin
  End;Exit
 End;
 Close(F);if IOResult<>0 Then Exit;PCode_LoadRaw:=True
End;

Function TargetName:String;
Begin
 Case CurrentTarget of
  ptAppleHeath:TargetName:='APPLEHEATH';
  ptUCSDPascalII:TargetName:='UCSDPASCALII';
  ptUCSDPSystemIII:TargetName:='UCSDPSYSTEMIII';
 else TargetName:='UCSDPSYSTEMIV'End
End;

Function SelectTarget(S:String):Boolean;
Begin
 S:=UpperString(S);SelectTarget:=True;
 if(S='APPLEHEALT')or(S='APPLEHEATH')or(S='APPLE')or(S='HEATH')Then
  CurrentTarget:=ptAppleHeath
 else if(S='UCSDPASCALII')or(S='PASCALII')or(S='II')Then CurrentTarget:=ptUCSDPascalII
 else if(S='UCSDPSYSTEMIII')or(S='PSYSTEMIII')or(S='III')Then CurrentTarget:=ptUCSDPSystemIII
 else if(S='UCSDPSYSTEMIV')or(S='PSYSTEMIV')or(S='IV')Then CurrentTarget:=ptUCSDPSystemIV
 else SelectTarget:=False
End;

Function PCode_Fetch(Ofs: LongInt): Byte;Begin
 If (Ofs >= 0) And (Ofs < PCode_CodeSize) Then PCode_Fetch := PCode_Mem^[Ofs]
 Else PCode_Fetch := 0;
End;
{ BIG : MSB=0 => 1 octet (0..127) ; MSB=1 => 14 bits sur 2 octets (grand-boutiste). }

Function PCode_ReadBig(Ofs: LongInt; Var Used: Integer): Integer;
Var
 B1, B2: Byte;
Begin
 B1 := PCode_Fetch(Ofs);
 If B1 < 128 Then Begin
  Used := 1; PCode_ReadBig := B1;
 End
 Else
 Begin
  B2 := PCode_Fetch(Ofs + 1);
  Used := 2;
  PCode_ReadBig := (Integer(B1 And $7F) * 256) + B2;
 End;
End;

Procedure PCode_Push(V: Integer);Begin
 If PCode_Halted Then Exit;
 If PCode_SP < High(PCode_Data^) Then Begin
  PCode_Data^[PCode_SP] := V;
  Inc(PCode_SP);
 End Else
 Begin
  PCode_Write('[depassement de pile p-code]');
  PCode_Halted := True;
  PCode_ExitCode := 1;
 End;
End;

Function PCode_Pop: Integer;Begin
 If PCode_SP > 0 Then Begin
  Dec(PCode_SP);
  PCode_Pop := PCode_Data^[PCode_SP];
 End Else
 Begin
  If Not PCode_Halted Then   PCode_Write('[pile p-code vide]');
  PCode_Halted := True;
  PCode_ExitCode := 1;
  PCode_Pop := 0;
 End;
End;

Function PCode_DataAt(A: LongInt): Integer;Begin
 If (A >= 0) And (A <= High(PCode_Data^)) Then PCode_DataAt := PCode_Data^[A]
 Else
 Begin
  PCode_DataAt := 0;
 End;
End;

Procedure PCode_DataSet(A: LongInt; V: Integer);Begin
 If (A >= 0) And (A <= High(PCode_Data^)) Then PCode_Data^[A] := V;
End;
{ Resout la base de cadre a Lvl chainons statiques (mot 0 du cadre = lien   }
{ statique) en amont du cadre courant (PCode_MP). Lvl=0 => cadre courant.   }

Function PCode_StaticBase(Lvl: Integer): LongInt;
Var
 FB: LongInt;
 I: Integer;
Begin
 FB := PCode_MP;
 For I := 1 To Lvl Do FB := PCode_DataAt(FB);
 PCode_StaticBase := FB;
End;

Procedure PCode_Unsupported(Const Msg: String);Begin
 If Not PCode_Halted Then Begin
  PCode_Write('[' + Msg + ' non supporte]');
  PCode_Halted := True;
  PCode_ExitCode := 1;
 End;
End;
{ Appel d unite externe (CXP) 0 = runtime hote (E/S console, adapte de la  }
{ numerotation SYSTEM.PASCAL documentee par DISPCODE/PDECODE, mais avec une }
{ convention de parametrage SIMPLIFIEE de mon fait : valeurs directement    }
{ sur la pile, sans descripteur de fichier - voir memoire projet).          }

Procedure PCode_CallUnit0(ProcNum: Byte);
Var
 V, Addr, N, I: Integer;
 S: String;
Begin
 Case ProcNum Of
 2:
 Begin
 { execerror : arret avec code d erreur } N := PCode_Pop;
  PCode_Write('[EXECERROR ' + PCode_IntToStr(N) + ']');
  PCode_Halted := True; PCode_ExitCode := N;
 End;
 12:
 Begin
 { read integer : pas d entree disponible, pousse 0 } PCode_Push(0); 
 End;
 13:
 Begin
 { write integer } V := PCode_Pop; Str(V, S); PCode_Write(S); 
 End;
 16:
 Begin
 { read char : pas d entree disponible, pousse 0 } PCode_Push(0); 
 End;
 17:
 Begin
 { write char } PCode_PutChar(Chr(Byte(PCode_Pop And $FF))); 
 End;
 19:
 Begin
 { write string : pile = [..., adresse, longueur] (longueur au sommet) }
  N := PCode_Pop; Addr := PCode_Pop;
  For I := 0 To N - 1 Do Begin
   If Addr >= 30000 Then         PCode_PutChar(Chr(PCode_Fetch(Addr - 30000 + I)))
   Else
   PCode_PutChar(Chr(Byte(PCode_DataAt(Addr + I) And $FF)));
  End;
 End;
 21:
 Begin
 { readln : ignore, pas d entree disponible } 
 End;
 22:
 Begin
 { writeln } PCode_PutChar(#13); PCode_PutChar(#10); 
 End;
 Else
 PCode_Unsupported('CXP 0,' + PCode_IntToStr(ProcNum) + ' (E/S)');
End;
End;
{ Appel de procedure standard (CSP). Table de numeros reprise de           }
{ DISPCODE.PAS (CSPName) - seules EXIT (4) et les no-op mathematiques sur   }
{ entiers (18=TRC, 19=RND, pas de reel donc identite) sont implementees.    }

Procedure PCode_CallCSP(CspNum: Byte);
Var
 N: Integer;
Begin
 Case CspNum Of
 4:
 Begin
 { exit } N := PCode_Pop; PCode_Halted := True; PCode_ExitCode := N; 
 End;
 18, 19:
 Begin
 { trunc/round : deja entier dans ce sous-ensemble, no-op } 
 End;
 Else
 PCode_Unsupported('CSP ' + PCode_IntToStr(CspNum));
End;
End;
{ Execute UNE instruction p-code a partir de PCode_PC. }

Procedure PCode_Step;
Var
 Op: Byte;
 B: Byte;
 SB: ShortInt;
 W, Used, N, I, Lvl: Integer;
 A, V1, V2, Addr, FB: LongInt;
 Temp: Array[0..255] Of Integer;
Begin
 If PCode_Halted Then Exit;
 If (PCode_PC < 0) Or (PCode_PC >= PCode_CodeSize) Then Begin
  PCode_Halted := True; PCode_ExitCode := 1; Exit;
 End;
 Op := PCode_Fetch(PCode_PC);
 If Op < 128 Then Begin
 { SLDC n : charge court la constante n (0..127) }
  PCode_Push(Op);
  Inc(PCode_PC);
  Exit;
 End;
 Case Op Of
 128, 129:
 Begin
  V1 := PCode_Pop; If V1 < 0 Then V1 := -V1; PCode_Push(V1); Inc(PCode_PC);
 End; { ABI/ABR }
 130, 131:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 + V2); Inc(PCode_PC);
 End; { ADI/ADR }
 132:
 Begin
 { LAND } V2 := PCode_Pop; V1 := PCode_Pop;
  PCode_Push(Ord((V1 <> 0) And (V2 <> 0))); Inc(PCode_PC);
 End;
 133: PCode_Unsupported('DIF (ensembles)'); { DIF }
 134, 135:
 Begin
 { DVI/DVR } V2 := PCode_Pop; V1 := PCode_Pop;
  If V2 = 0 Then Begin
   PCode_Write('[erreur 300 : division par zero]');
   PCode_Halted := True; PCode_ExitCode := 300;
  End Else PCode_Push(V1 Div V2);
  Inc(PCode_PC);
 End;
 136:
 Begin
 { CHK : verifie bornes [min,max] sur la valeur au sommet (non depilee) }
  V2 := PCode_Pop; { max }
  V1 := PCode_Pop; { min }
  W := PCode_DataAt(PCode_SP - 1); { valeur, laissee sur la pile }
  If (W < V1) Or (W > V2) Then Begin
   PCode_Write('[erreur 302 : hors bornes]');
   PCode_Halted := True; PCode_ExitCode := 302;
  End;
  Inc(PCode_PC);
 End;
 137, 138: Inc(PCode_PC); { FLO/FLT : pas de reels, no-op }
 139: PCode_Unsupported('INN (ensembles)');
 140: PCode_Unsupported('INT (ensembles)');
 141:
 Begin
 { IOR : OU booleen } V2 := PCode_Pop; V1 := PCode_Pop;
  PCode_Push(Ord((V1 <> 0) Or (V2 <> 0))); Inc(PCode_PC);
 End;
 142:
 Begin
 { MODI } V2 := PCode_Pop; V1 := PCode_Pop;
  If V2 = 0 Then Begin
   PCode_Write('[erreur 300 : division par zero]');
   PCode_Halted := True; PCode_ExitCode := 300;
  End Else PCode_Push(V1 Mod V2);
  Inc(PCode_PC);
 End;
 143, 144:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 * V2); Inc(PCode_PC);
 End; { MPI/MPR }
 145, 146:
 Begin
  V1 := PCode_Pop; PCode_Push(-V1); Inc(PCode_PC);
 End; { NGI/NGR }
 147:
 Begin
  V1 := PCode_Pop; PCode_Push(Ord(V1 = 0)); Inc(PCode_PC);
 End; { LNOT }
 148: PCode_Unsupported('SRS (ensembles)');
 149, 150:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 - V2); Inc(PCode_PC);
 End; { SBI/SBR }
 151: PCode_Unsupported('SGS (ensembles)');
 152, 153:
 Begin
  V1 := PCode_Pop; PCode_Push(V1 * V1); Inc(PCode_PC);
 End; { SQI/SQR }
 154:
 Begin
 { STO : pile = [..., adresse, valeur] } V1 := PCode_Pop; Addr := PCode_Pop;
  PCode_DataSet(Addr, V1); Inc(PCode_PC);
 End;
 155: PCode_Unsupported('IXS (chaines)');
 156: PCode_Unsupported('UNI (ensembles)');
 157: PCode_Unsupported('LDE (unite externe)');
 158:
 Begin
 { CSP n } B := PCode_Fetch(PCode_PC + 1); PCode_PC := PCode_PC + 2;
  PCode_CallCSP(B);
 End;
 159:
 Begin
  PCode_Push(0); Inc(PCode_PC);
 End; { LDCN : NIL }
 160: PCode_Unsupported('ADJ (ensembles)');
 161:
 Begin
 { FJP dep : saut si faux }
  SB := ShortInt(PCode_Fetch(PCode_PC + 1));
  V1 := PCode_Pop;
  If V1 = 0 Then PCode_PC := PCode_PC + 2 + SB
  Else PCode_PC := PCode_PC + 2;
 End;
 162:
 Begin
 { INC n } A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
  PCode_Push(V1 + A); PCode_PC := PCode_PC + 1 + Used;
 End;
 163:
 Begin
 { IND n : *(pop()+n) }
  A := PCode_ReadBig(PCode_PC + 1, Used); Addr := PCode_Pop;
  PCode_Push(PCode_DataAt(Addr + A)); PCode_PC := PCode_PC + 1 + Used;
 End;
 164:
 Begin
 { IXA n : indexation tableau, taille element n mots }
  A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop; Addr := PCode_Pop;
  PCode_Push(Addr + V1 * A); PCode_PC := PCode_PC + 1 + Used;
 End;
 165:
 Begin
 { LAO n : adresse globale }
  A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(A);
  PCode_PC := PCode_PC + 1 + Used;
 End;
 166:
 Begin
 { LSA n,"texte" : adresse (taguee espace code) de la chaine litterale }
  N := PCode_Fetch(PCode_PC + 1);
  PCode_Push(30000 + (PCode_PC + 2));
  PCode_PC := PCode_PC + 2 + N;
 End;
 167: PCode_Unsupported('LAE (unite externe)');
 168:
 Begin
 { MOV n : pile = [..., dest, src], copie n mots src->dest }
  A := PCode_ReadBig(PCode_PC + 1, Used);
  V2 := PCode_Pop; { src }
  V1 := PCode_Pop; { dest }
  For I := 0 To A - 1 Do PCode_DataSet(V1 + I, PCode_DataAt(V2 + I));
  PCode_PC := PCode_PC + 1 + Used;
 End;
 169:
 Begin
 { LDO n }
  A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(PCode_DataAt(A));
  PCode_PC := PCode_PC + 1 + Used;
 End;
 170: PCode_Unsupported('SAS');
 171:
 Begin
 { SRO n }
  A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
  PCode_DataSet(A, V1); PCode_PC := PCode_PC + 1 + Used;
 End;
 172: PCode_Unsupported('XJP (table de cas)');
 173:
 Begin
 { RNP n : retour procedure (non testee dans ce sous-ensemble, } { programme = un seul bloc plat sans appel) }
  N := PCode_Fetch(PCode_PC + 1);
  Addr := PCode_DataAt(PCode_MP + 2); { retIC }
  FB := PCode_DataAt(PCode_MP + 1);   { lien dynamique }
  PCode_SP := PCode_MP - N;
  PCode_MP := FB;
  PCode_PC := Addr;
 End;
 174: PCode_Unsupported('CIP (appel indirect)');
 175, 176, 177, 180, 181, 183:
 Begin
 { EQU/GEQ/GRT/LEQ/LES/NEQ : octet type ignore, compare entier }
  Inc(PCode_PC); { consomme l octet discriminant de type }
  B := PCode_Fetch(PCode_PC); Inc(PCode_PC);
  V2 := PCode_Pop; V1 := PCode_Pop;
  Case Op Of
  175: PCode_Push(Ord(V1 = V2));
  176: PCode_Push(Ord(V1 >= V2));
  177: PCode_Push(Ord(V1 > V2));
  180: PCode_Push(Ord(V1 <= V2));
  181: PCode_Push(Ord(V1 < V2));
  183: PCode_Push(Ord(V1 <> V2));
 End;
End;
178:
Begin
 { LDA Lvl,Off : adresse via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);
 PCode_Push(FB + A);
 PCode_PC := PCode_PC + 2 + Used;
End;
179:
Begin
 { LDC n,$w1,... : charge n constantes 16 bits }
 N := PCode_Fetch(PCode_PC + 1);
 For I := 0 To N - 1 Do Begin
  W := PCode_Fetch(PCode_PC + 2 + I*2) Or (PCode_Fetch(PCode_PC + 3 + I*2) Shl 8);
  PCode_Push(W);
 End;
 PCode_PC := PCode_PC + 2 + N*2;
End;
182:
Begin
 { LOD Lvl,Off : charge via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);
 PCode_Push(PCode_DataAt(FB + A));
 PCode_PC := PCode_PC + 2 + Used;
End;
184:
Begin
 { STR Lvl,Off : stocke via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);
 V1 := PCode_Pop;
 PCode_DataSet(FB + A, V1);
 PCode_PC := PCode_PC + 2 + Used;
End;
185:
Begin
 { UJP dep }
 SB := ShortInt(PCode_Fetch(PCode_PC + 1));
 PCode_PC := PCode_PC + 2 + SB;
End;
186, 187: PCode_Unsupported('LDP/STP (fichiers)'); { LDP/STP }
188:
Begin
 { LDM n : empile n mots depuis l adresse au sommet }
 N := PCode_Fetch(PCode_PC + 1); Addr := PCode_Pop;
 For I := 0 To N - 1 Do PCode_Push(PCode_DataAt(Addr + I));
 PCode_PC := PCode_PC + 2;
End;
189:
Begin
 { STM n : pile = [..., dest, mot1..motN], depile n mots puis dest }
 N := PCode_Fetch(PCode_PC + 1);
 For I := N - 1 Downto 0 Do Temp[I] := PCode_Pop;
 Addr := PCode_Pop;
 For I := 0 To N - 1 Do PCode_DataSet(Addr + I, Temp[I]);
 PCode_PC := PCode_PC + 2;
End;
190, 191: PCode_Unsupported('LDB/STB (octets)'); { LDB/STB }
192: PCode_Unsupported('IXP (tableau tasse)');
193:
Begin
 { RBP n : retour de bloc = fin de programme }
 PCode_Halted := True; PCode_ExitCode := 0;
End;
194: PCode_Unsupported('CBP');
195, 196, 197, 200, 201, 203:
Begin
 { EQUI/GEQI/GRTI/LEQI/LESI/NEQI }
 V2 := PCode_Pop; V1 := PCode_Pop;
 Case Op Of
 195: PCode_Push(Ord(V1 = V2));
 196: PCode_Push(Ord(V1 >= V2));
 197: PCode_Push(Ord(V1 > V2));
 200: PCode_Push(Ord(V1 <= V2));
 201: PCode_Push(Ord(V1 < V2));
 203: PCode_Push(Ord(V1 <> V2));
End;
Inc(PCode_PC);
End;
198:
Begin
 { LLA n : adresse locale MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(PCode_MP + A);
 PCode_PC := PCode_PC + 1 + Used;
End;
199:
Begin
 { LDCI w : constante entiere 16 bits (Integer 16 bits signe -}
        { la troncature d affectation fait deja l extension de signe).   }
 W := PCode_Fetch(PCode_PC + 1) Or (PCode_Fetch(PCode_PC + 2) Shl 8);
 PCode_Push(W); PCode_PC := PCode_PC + 3;
End;
202:
Begin
 { LDL n : charge local MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(PCode_DataAt(PCode_MP + A));
 PCode_PC := PCode_PC + 1 + Used;
End;
204:
Begin
 { STL n : stocke local MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
 PCode_DataSet(PCode_MP + A, V1); PCode_PC := PCode_PC + 1 + Used;
End;
205:
Begin
 { CXP unite,proc }
 B := PCode_Fetch(PCode_PC + 1); N := PCode_Fetch(PCode_PC + 2);
 PCode_PC := PCode_PC + 3;
 If B = 0 Then PCode_CallUnit0(N)
 Else PCode_Unsupported('CXP ' + PCode_IntToStr(B) + ',' + PCode_IntToStr(N) +
 ' (unite externe)');
End;
206: PCode_Unsupported('CLP (appel par numero)');
207: PCode_Unsupported('CGP (appel par numero)');
208: PCode_Unsupported('LPA (tableau tasse)');
209: PCode_Unsupported('STE (unite externe)');
210: PCode_Unsupported('opcode reserve ???');
211: PCode_Unsupported('EFJ');
212: PCode_Unsupported('NFJ');
213: Inc(PCode_PC, 2); { BPT : point d arret, ignore }
214:
Begin
 PCode_Halted := True; PCode_ExitCode := 0;
End; { XIT }
215: Inc(PCode_PC); { NOP }
216..231:
Begin
 { SLDL1..16 }
 PCode_Push(PCode_DataAt(PCode_MP + (Op - 215))); Inc(PCode_PC);
End;
232..247:
Begin
 { SLDO1..16 }
 PCode_Push(PCode_DataAt(Op - 231)); Inc(PCode_PC);
End;
248..255:
Begin
 { SIND0..7 }
 Addr := PCode_Pop; PCode_Push(PCode_DataAt(Addr + (Op - 248))); Inc(PCode_PC);
End;
End;
End;

Function ExecutePCodeFile(Const FileName:String):Integer;
Const
 MaxCycles=10000000;
Begin
 ExecutePCodeFile:=1;GetMem(PCode_Mem,SizeOf(TPCodeMemory));
 GetMem(PCode_Data,SizeOf(TPCodeData));
 if not PCode_LoadRaw(FileName)Then Begin
  WriteLn('Impossible de charger le fichier p-Code: ',FileName);
  FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory));Exit
 End;
 FillChar(PCode_Data^,SizeOf(TPCodeData),0);PCode_PC:=0;PCode_SP:=0;PCode_MP:=0;
 PCode_Cycles:=0;PCode_Halted:=False;PCode_ExitCode:=0;
 While not PCode_Halted and(PCode_Cycles<MaxCycles)do Begin
  PCode_Step;Inc(PCode_Cycles)
 End;
 if not PCode_Halted Then Begin
  WriteLn('[limite d''instructions p-Code atteinte]');PCode_ExitCode:=1
 End;
 FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory));
 ExecutePCodeFile:=PCode_ExitCode
End;

Procedure ExecuteCommand;
Var
 Name:String;
 Code:Integer;
Begin
 Name:=ProgramFile;AskFile('Programme p-Code',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.CODE')Then Name:=Name+'.CODE';
 if not FileExists(Name)Then Begin
  WriteLn('Fichier introuvable: ',Name);Exit
 End;
 ProgramFile:=Name;WriteLn('Execution de ',Name,' ...');Code:=ExecutePCodeFile(Name);
 WriteLn;WriteLn('Fin du programme p-Code (code ',Code,').')
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
Var
 Wr:Word;
Begin
 If BLen>0 Then Begin
  BlockWrite(OutFile,BBuf,BLen,Wr); BLen:=0;
 End;
End;

Procedure Emit(B:Byte);Begin
 BBuf[BLen]:=B; Inc(BLen); Inc(OutPos);
 If BLen>=SizeOf(BBuf) Then FlushBuf;
End;

Procedure Err(Msg:String);Begin
 WriteLn('Ligne ',LineNum,': ',Msg); Inc(ErrCount);
End;

Procedure EmitUB(V:LongInt);Begin
 If (V<0) Or (V>255) Then Begin
  Err('UB hors limite'); V:=0;
 End;
 Emit(Byte(V));
End;

Procedure EmitSB(V:LongInt);Begin
 If (V<-128) Or (V>127) Then Begin
  Err('SB hors limite'); V:=0;
 End;
 If V<0 Then V:=V+256;
 Emit(Byte(V));
End;

Procedure EmitW(V:LongInt);Begin
 If V<0 Then V:=V+65536;
 Emit(Byte(V And $FF));
 Emit(Byte((V Shr 8) And $FF));
End;

Procedure EmitBig(V:LongInt);Begin
 If (V<0) Or (V>32767) Then Begin
  Err('BIG hors limite'); V:=0;
 End;
 If V<128 Then Emit(Byte(V))
 Else
 Begin
  Emit(Byte($80 Or ((V Shr 8) And $7F)));
  Emit(Byte(V And $FF));
 End;
End;

Function IsDigit(C:Char):Boolean;Begin
 IsDigit:=(C>='0')And(C<='9');
End;

Function IsHexDigit(C:Char):Boolean;Begin
 IsHexDigit:=IsDigit(C) Or ((C>='A')And(C<='F')) Or ((C>='a')And(C<='f'));
End;

Function IsAlpha(C:Char):Boolean;Begin
 IsAlpha:=((C>='A')And(C<='Z')) Or ((C>='a')And(C<='z'));
End;

Procedure SkipSp(Var P:Integer; S:String);Begin
 While (P<=Length(S)) And ((S[P]=' ') Or (S[P]=#9)) Do Inc(P);
End;

Function ParseNum(Var P:Integer; S:String; Var V:LongInt):Boolean;
Var
 Sign:Integer;
 HasH,Got:Boolean;
 D:Integer;
 C:Char;
Begin
 SkipSp(P,S);
 ParseNum:=False; V:=0; Sign:=1; Got:=False; HasH:=False;
 If P>Length(S) Then Exit;
 If S[P]='+' Then Inc(P)
 Else If S[P]='-' Then Begin
  Sign:=-1; Inc(P);
 End;
 If (P<=Length(S)) And (S[P]='$') Then Begin
  HasH:=True; Inc(P);
 End;
 While P<=Length(S) Do Begin
  C:=S[P];
  If HasH Then Begin
   If Not IsHexDigit(C) Then Break;
   If IsDigit(C) Then D:=Ord(C)-Ord('0')
   Else D:=Ord(UpCase(C))-Ord('A')+10;
   V:=V*16+D; Got:=True;
  End
  Else
  Begin
   If Not IsDigit(C) Then Break;
   V:=V*10+(Ord(C)-Ord('0')); Got:=True;
  End;
  Inc(P);
 End;
 V:=V*Sign;
 ParseNum:=Got;
End;

Function ParseId(Var P:Integer; S:String; Var Id:String):Boolean;Begin
 SkipSp(P,S); Id:='';
 If (P>Length(S)) Or (Not IsAlpha(S[P])) Then Begin
  ParseId:=False; Exit;
 End;
 While (P<=Length(S)) And (IsAlpha(S[P]) Or IsDigit(S[P])) Do Begin
  Id:=Id+UpCase(S[P]); Inc(P);
 End;
 ParseId:=True;
End;

Function ParseQStr(Var P:Integer; S:String; Var Q:String):Boolean;Begin
 SkipSp(P,S); Q:='';
 If (P>Length(S)) Or (S[P]<>'"') Then Begin
  ParseQStr:=False; Exit;
 End;
 Inc(P);
 While (P<=Length(S)) And (S[P]<>'"') Do Begin
  Q:=Q+S[P]; Inc(P);
 End;
 If P>Length(S) Then Err('cha'+#238+'ne non termin'+#130+'e')
 Else Inc(P);
 ParseQStr:=True;
End;

Function ExpectComma(Var P:Integer; S:String):Boolean;Begin
 SkipSp(P,S);
 If (P>Length(S)) Or (S[P]<>',') Then Begin
  ExpectComma:=False; Exit;
 End;
 Inc(P); ExpectComma:=True;
End;

Function LookupMn(Mn:String; Var Code:Byte; Var Kind:Byte):Boolean;
Var
 I,P:Integer;
 N:LongInt;
Begin
 LookupMn:=False;
 If Mn='SLDC' Then Begin
  Code:=0; Kind:=OPK_SLDC; LookupMn:=True; Exit;
 End;
 If Mn='DB' Then Begin
  Code:=0; Kind:=OPK_DB; LookupMn:=True; Exit;
 End;
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
 For I:=128 To 255 Do  If Mnem128[I]=Mn Then Begin
  Code:=Byte(I); Kind:=Kind128[I]; LookupMn:=True; Exit;
 End;
End;

Function IsPrefixTok(S:String):Boolean;
Var
 I:Integer;
Begin
 IsPrefixTok:=False;
 If S='..' Then Begin
  IsPrefixTok:=True; Exit;
 End;
 If (Length(S)<>2) And (Length(S)<>6) Then Exit;
 For I:=1 To Length(S) Do  If Not IsHexDigit(S[I]) Then Exit;
 IsPrefixTok:=True;
End;

Function FindMn(S:String):Integer;
Var
 P,Q:Integer;
 Tok:String;
Begin
 FindMn:=0; P:=1;
 While P<=Length(S) Do Begin
  While (P<=Length(S)) And (S[P]=' ') Do Inc(P);
  If P>Length(S) Then Exit;
  Q:=P;
  While (Q<=Length(S)) And (S[Q]<>' ') Do Inc(Q);
  Tok:=Copy(S,P,Q-P);
  If Not IsPrefixTok(Tok) Then Begin
   FindMn:=P; Exit;
  End;
  P:=Q;
 End;
End;

Procedure ProcessLine(S:String);
Var
 I,P:Integer;
 Mn,Q:String;
 Code,Kind:Byte;
 V,V2:LongInt;
Begin
 I:=Pos(';',S); If I>0 Then S:=Copy(S,1,I-1);
 While (Length(S)>0) And ((S[Length(S)]=' ')Or(S[Length(S)]=#9)Or(S[Length(S)]=#13))
 Do  S:=Copy(S,1,Length(S)-1);
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
 OPK_SLDC:
 Begin
  If Not ParseNum(P,S,V) Then Begin
   Err('SLDC: nombre attendu'); Exit;
  End;
  If (V<0) Or (V>127) Then Begin
   Err('SLDC hors limite (0..127)'); Exit;
  End;
  Emit(Byte(V));
 End;
 OPK_DB:
 Begin
  While ParseNum(P,S,V) Do Begin
   EmitUB(V);
   If Not ExpectComma(P,S) Then Break;
  End;
 End;
 OPK_NONE: Emit(Code);
 OPK_UB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('UB attendu') Else EmitUB(V);
 End;
 OPK_SB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('SB attendu') Else EmitSB(V);
 End;
 OPK_W:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('W attendu') Else EmitW(V);
 End;
 OPK_BIG:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('BIG attendu') Else EmitBig(V);
 End;
 OPK_UBUB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('UB,UB attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('2e UB attendu'); Exit;
  End;
  EmitUB(V); EmitUB(V2);
 End;
 OPK_UBBIG:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('UB,BIG attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('BIG attendu'); Exit;
  End;
  EmitUB(V); EmitBig(V2);
 End;
 OPK_DBBIG:
 Begin
  Emit(Code);
  SkipSp(P,S);
  If (P<=Length(S)) And (UpCase(S[P])='L') Then Inc(P);
  If Not ParseNum(P,S,V) Then Begin
   Err('DB level attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('BIG attendu'); Exit;
  End;
  EmitUB(V); EmitBig(V2);
 End;
 OPK_LSA:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('LSA: len attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseQStr(P,S,Q) Then Begin
   Err('"..." attendu'); Exit;
  End;
  If Length(Q)<>V Then Err('LSA: longueur ne correspond pas');
  EmitUB(V);
  For I:=1 To Length(Q) Do Emit(Byte(Q[I]));
 End;
 OPK_LDC:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('LDC: count attendu'); Exit;
  End;
  EmitUB(V);
  For I:=1 To V Do Begin
   If Not ExpectComma(P,S) Then Begin
    Err('virgule attendue'); Exit;
   End;
   If Not ParseNum(P,S,V2) Then Begin
    Err('mot attendu'); Exit;
   End;
   EmitW(V2);
  End;
 End;
 OPK_XJP:
 Begin
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
 If IOResult<>0 Then Begin
  WriteLn('Erreur: ouverture ',InName);Exit
 End;
 Assign(OutFile,OutName);Rewrite(OutFile,1);
 If IOResult<>0 Then Begin
  Close(InFile);ReadCode:=IOResult;
  WriteLn('Erreur: creation ',OutName);Exit
 End;
 OutPos:=0;BLen:=0;LineNum:=0;ErrCount:=0;ReadCode:=0;
 While not Eof(InFile)do Begin
  ReadLn(InFile,Line);ReadCode:=IOResult;
  If ReadCode<>0 Then Begin
   Err('erreur de lecture');Break
  End;
  Inc(LineNum);ProcessLine(Line)
 End;
 FlushBuf;Close(InFile);CloseCode:=IOResult;
 Close(OutFile);if CloseCode=0 Then CloseCode:=IOResult else ReadCode:=IOResult;
 If(ReadCode<>0)or(CloseCode<>0)Then Inc(ErrCount);
 WriteLn('Assemble : ',OutPos,' octet(s), ',ErrCount,' erreur(s)');
 If ErrCount=0 Then AssemblePCode:=0 else AssemblePCode:=1
End;

Type
 PPasSymbol=^TPasSymbol;
 TPasSymbol=Record Name:String[31];
 Address,Value:Integer;
 IsConst:Boolean;
 Next:PPasSymbol
End;
PPasSource=^TPCodeMemory;

Var
 CPSource:PPasSource;
 CPSize,CPPos,CPLine,CPCodePos,CPVarCount:LongInt;
 CPToken,CPText:String;
 CPNumber:LongInt;
 CPError:Boolean;
 CPSymbols:PPasSymbol;

Procedure CPFail(S:String);Begin
 if not CPError Then WriteLn('Erreur UCSD ligne ',CPLine,': ',S);CPError:=True
End;

Procedure CPNext;
Var
 C:Char;
Begin
 CPToken:='';CPText:='';CPNumber:=0;
 Repeat
 While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in[' ',#9,#10,#13])do Begin
  if CPSource^[CPPos]=10 Then Inc(CPLine);Inc(CPPos)
 End;
 if CPPos>=CPSize Then Begin
  CPToken:='EOF';Exit
 End;
 C:=Chr(CPSource^[CPPos]);
 if C='{'Then Begin
  Inc(CPPos);
  While(CPPos<CPSize)and(CPSource^[CPPos]<>Ord('}'))do Begin
   if CPSource^[CPPos]=10 Then Inc(CPLine);Inc(CPPos)
  End;if CPPos<CPSize Then Inc(CPPos)
 End else Break
 Until False;
 C:=Chr(CPSource^[CPPos]);
 if C in['A'..'Z','a'..'z','_']Then Begin
  CPText:='';
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['A'..'Z','a'..'z','_','0'..'9'])do Begin
   CPText:=CPText+UpCase(Chr(CPSource^[CPPos]));Inc(CPPos)
  End;CPToken:='ID';Exit
 End;
 if C in['0'..'9']Then Begin
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
   CPNumber:=CPNumber*10+CPSource^[CPPos]-Ord('0');Inc(CPPos)
  End;CPToken:='NUM';Exit
 End;
 if C=''''Then Begin
  Inc(CPPos);
  While(CPPos<CPSize)do Begin
   C:=Chr(CPSource^[CPPos]);Inc(CPPos);
   if C=''''Then Begin
    if(CPPos<CPSize)and(CPSource^[CPPos]=Ord(''''))Then Begin
     CPText:=CPText+'''';Inc(CPPos)
    End else Break
   End else CPText:=CPText+C
  End;CPToken:='STR';Exit
 End;
 CPToken:=C;Inc(CPPos);
 if(C in[':', '<','>'])and(CPPos<CPSize)Then Begin
  C:=Chr(CPSource^[CPPos]);
  if((CPToken=':')and(C='='))or((CPToken='<')and(C in['=','>']))or
  ((CPToken='>')and(C='='))Then Begin
   CPToken:=CPToken+C;Inc(CPPos)
  End
 End
End;

Function CPIs(S:String):Boolean;Begin
 CPIs:=(CPToken='ID')and(CPText=S)
End;

Procedure CPNeed(S:String);Begin
 if CPToken<>S Then CPFail('"'+S+'" attendu')else CPNext
End;

Function CPFind(S:String):PPasSymbol;
Var
 P:PPasSymbol;
Begin
 P:=CPSymbols;
 While(P<>Nil)and(P^.Name<>S)do P:=P^.Next;CPFind:=P
End;

Procedure CPAdd(S:String;V:Integer;K:Boolean);
Var
 P:PPasSymbol;
Begin
 if CPFind(S)<>Nil Then Begin
  CPFail('identificateur deja defini: '+S);Exit
 End;
 New(P);P^.Name:=S;P^.Value:=V;P^.Address:=V;P^.IsConst:=K;P^.Next:=CPSymbols;CPSymbols:=P
End;

Procedure CPE(B:Byte);Begin
 if CPCodePos>=65535 Then CPFail('programme trop grand')else
 Begin
  PCode_Mem^[CPCodePos]:=B;Inc(CPCodePos)
 End
End;

Procedure CPBig(V:LongInt);Begin
 if V<128 Then CPE(V)else
 Begin
  CPE($80 or(V shr 8));CPE(V)
 End
End;

Procedure CPConst(V:LongInt);Begin
 if(V>=0)and(V<128)Then CPE(V)else
 Begin
  CPE(199);CPE(V);CPE(V shr 8)
 End
End;
Procedure CPExpression;Forward;

Procedure CPFactor;
Var
 P:PPasSymbol;
 Neg:Boolean;
Begin
 Neg:=False;if CPToken='-'Then Begin
  Neg:=True;CPNext
 End;
 if CPToken='NUM'Then Begin
  CPConst(CPNumber);CPNext
 End
 else if CPToken='STR'Then Begin
  CPFail('chaine interdite dans cette expression');CPNext
 End
 else if CPToken='('Then Begin
  CPNext;CPExpression;CPNeed(')')
 End
 else if CPIs('TRUE')Then Begin
  CPConst(1);CPNext
 End else if CPIs('FALSE')Then Begin
  CPConst(0);CPNext
 End
 else if CPToken='ID'Then Begin
  P:=CPFind(CPText);if P=Nil Then CPFail('identificateur inconnu: '+CPText)
  else if P^.IsConst Then CPConst(P^.Value)else
  Begin
   CPE(169);CPBig(P^.Address)
  End;CPNext
 End else
 Begin
  CPFail('facteur attendu');CPNext
 End;if Neg Then CPE(145)
End;

Procedure CPTerm;
Var
 O:String;
Begin
 CPFactor;
 While(CPToken='*')or(CPToken='/')or CPIs('DIV')or CPIs('MOD')or CPIs('AND')do Begin
  O:=CPToken;if CPToken='ID'Then O:=CPText;CPNext;CPFactor;
  if O='*'Then CPE(143)else if(O='/')or(O='DIV')Then CPE(134)else if O='MOD'Then CPE(142)
  else CPE(132)
 End
End;

Procedure CPSimple;
Var
 O:String;
Begin
 CPTerm;
 While(CPToken='+')or(CPToken='-')or CPIs('OR')do Begin
  O:=CPToken;
  if CPToken='ID'Then O:=CPText;CPNext;CPTerm;
  if O='+'Then CPE(130)else if O='-'Then CPE(149)else CPE(141)
 End
End;

Procedure CPExpression;
Var
 O:String;
Begin
 CPSimple;if(CPToken='=')or(CPToken='<>')or(CPToken='<')or(CPToken='<=')or
 (CPToken='>')or(CPToken='>=')Then Begin
  O:=CPToken;CPNext;CPSimple;
  if O='='Then CPE(195)else if O='<>'Then CPE(203)else if O='<'Then CPE(201)
  else if O='<='Then CPE(200)else if O='>'Then CPE(197)else CPE(196)
 End
End;
Procedure CPStatement;Forward;

Procedure CPCompound;Begin
 if not CPIs('BEGIN')Then Begin
  CPFail('BEGIN attendu');Exit
 End;CPNext;
 While not CPIs('END')and(CPToken<>'EOF')and not CPError do Begin
  CPStatement;
  if CPToken=';'Then CPNext else if not CPIs('END')Then CPFail('point-virgule attendu')
 End;
 if CPIs('END')Then CPNext
End;

Procedure CPStatement;
Var
 P:PPasSymbol;
 Name:String;
 J,Patch:LongInt;
Begin
 if CPIs('BEGIN')Then CPCompound
 else if CPIs('IF')Then Begin
  CPNext;CPExpression;if not CPIs('THEN')Then CPFail('THEN attendu')else CPNext;
  CPE(161);Patch:=CPCodePos;CPE(0);CPStatement;
  if CPIs('ELSE')Then Begin
   CPE(185);J:=CPCodePos;CPE(0);PCode_Mem^[Patch]:=CPCodePos-Patch-1;
   CPNext;CPStatement;PCode_Mem^[J]:=CPCodePos-J-1
  End else PCode_Mem^[Patch]:=CPCodePos-Patch-1
 End
 else if CPIs('WHILE')Then Begin
  J:=CPCodePos;CPNext;CPExpression;if not CPIs('DO')Then CPFail('DO attendu')else CPNext;
  CPE(161);Patch:=CPCodePos;CPE(0);CPStatement;CPE(185);CPE(J-(CPCodePos+1));
  PCode_Mem^[Patch]:=CPCodePos-Patch-1
 End
 else if CPIs('WRITE')or CPIs('WRITELN')Then Begin
  Name:=CPText;CPNext;
  if CPToken='('Then Begin
   CPNext;
   While CPToken<>')'do Begin
    if CPToken='STR'Then Begin
     CPE(166);CPE(Length(CPText));
     For J:=1 to Length(CPText)do CPE(Ord(CPText[J]));
     CPConst(Length(CPText));CPE(205);CPE(0);CPE(19);CPNext
    End else
    Begin
     CPExpression;CPE(205);CPE(0);CPE(13)
    End;
    if CPToken=','Then CPNext else Break
   End;CPNeed(')')
  End;
  if Name='WRITELN'Then Begin
   CPE(205);CPE(0);CPE(22)
  End
 End
 else if CPToken='ID'Then Begin
  P:=CPFind(CPText);Name:=CPText;CPNext;
  if(P=nil)or P^.IsConst Then CPFail('variable attendue: '+Name)else
  Begin
   CPNeed(':=');CPExpression;
   CPE(171);CPBig(P^.Address)
  End
 End
End;

Function WriteUCSDCodeFile(CodeName,SegmentName:String;CodeLength:LongInt;
 DataWords:Integer):Boolean;
Var F:File;Header:Array[0..511]of Byte;SegmentLength:Word;N,W:Word;I:Integer;
 Procedure HW(Offset:Integer;Value:Word);
 Begin Header[Offset]:=Byte(Value);Header[Offset+1]:=Byte(Value shr 8)End;
 Procedure EW(Value:Word);
 Begin CPE(Byte(Value));CPE(Byte(Value shr 8))End;
Begin
 WriteUCSDCodeFile:=False;if CodeLength>65520 Then Begin CPFail('segment trop grand');Exit End;
 EW(DataWords*2);EW(0);EW(CodeLength-1);EW(0);CPE(1);CPE(0);
 EW(CodeLength);CPE(1);CPE(1);SegmentLength:=CPCodePos;
 FillChar(Header,SizeOf(Header),0);HW(0,1);HW(2,SegmentLength);
 SegmentName:=UpperString(SegmentName);if Length(SegmentName)>8 Then SegmentName:=Copy(SegmentName,1,8);
 For I:=1 to Length(SegmentName)do Header[63+I]:=Ord(SegmentName[I]);
 HW(192,1);HW(224,0);
 Case CurrentTarget of
  ptAppleHeath:HW(256,$0101);
  ptUCSDPascalII:HW(256,$0201);
  ptUCSDPSystemIII:HW(256,$0301);
  ptUCSDPSystemIV:HW(256,$0401)
 End;
 Assign(F,CodeName);Rewrite(F,1);if IOResult<>0 Then Begin CPFail('creation impossible');Exit End;
 BlockWrite(F,Header,512,W);if(IOResult<>0)or(W<>512)Then CPFail('erreur d''ecriture');
 if not CPError Then Begin BlockWrite(F,PCode_Mem^,SegmentLength,N);
  if(IOResult<>0)or(N<>SegmentLength)Then CPFail('erreur d''ecriture')End;
 Close(F);if IOResult<>0 Then CPFail('erreur de fermeture');WriteUCSDCodeFile:=not CPError
End;

Function CompilePascalPCode(SourceName,CodeName:String):Integer;
Label 99;

Var
 F:File;
 Sz:LongInt;
 N:Word;
 P,Q:PPasSymbol;
 Names:Array[1..64]of String;
 NC,I:Integer;
 V:LongInt;
Begin
 CompilePascalPCode:=1;CPSymbols:=Nil;CPError:=False;CPLine:=1;CPVarCount:=0;
 GetMem(CPSource,SizeOf(TPCodeMemory));GetMem(PCode_Mem,SizeOf(TPCodeMemory));
 Assign(F,SourceName);Reset(F,1);if IOResult<>0 Then Begin
  CPFail('ouverture impossible');Goto 99
 End;
 Sz:=FileSize(F);if Sz>65534 Then Begin
  Close(F);CPFail('source trop grand');Goto 99
 End;
 BlockRead(F,CPSource^,Sz,N);if(IOResult<>0)or(N<>Sz)Then CPFail('erreur de lecture');
 Close(F);
 CPSize:=Sz;CPPos:=0;CPCodePos:=0;CPNext;
 if CPIs('PROGRAM')Then Begin
  CPNext;if CPToken='ID'Then CPNext;
  While(CPToken<>';')and(CPToken<>'EOF')do CPNext;CPNeed(';')
 End;
 if CPIs('CONST')Then Begin
  CPNext;
  While(CPToken='ID')and not CPError do Begin
   Names[1]:=CPText;CPNext;CPNeed('=');if CPToken='NUM'Then Begin
    V:=CPNumber;CPNext
   End
   else
   Begin
    CPFail('constante entiere attendue');V:=0
   End;CPAdd(Names[1],V,True);CPNeed(';')
  End
 End;
 if CPIs('VAR')Then Begin
  CPNext;
  While(CPToken='ID')and not CPIs('BEGIN')and
  not CPIs('PROCEDURE')and not CPIs('FUNCTION')and not CPError do Begin
   NC:=0;
   Repeat Inc(NC);Names[NC]:=CPText;CPNext;
   if CPToken=','Then CPNext else Break Until NC=64;
   CPNeed(':');if CPToken='ID'Then CPNext else CPFail('type attendu');CPNeed(';');
   For I:=1 to NC do Begin
    Inc(CPVarCount);CPAdd(Names[I],CPVarCount,False)
   End
  End
 End;
 CPCompound;if CPToken='.'Then CPNext else CPFail('point final attendu');CPE(214);
 if not CPError Then WriteUCSDCodeFile(CodeName,'PROGRAM',CPCodePos,CPVarCount);
 99:P:=CPSymbols;
 While P<>Nil do Begin
  Q:=P^.Next;Dispose(P);P:=Q
 End;
 FreeMem(PCode_Mem,SizeOf(TPCodeMemory));FreeMem(CPSource,SizeOf(TPCodeMemory));
 if not CPError Then Begin
  WriteLn(CPCodePos,' octet(s) de p-Code.');CompilePascalPCode:=0
 End
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
 if Code=0 Then Begin
  ProgramFile:=OutputName;WriteLn('Assemblage termine.')
 End
 else WriteLn('Echec de l''assemblage (code ',Code,').')
End;

Function DebugHex(V:LongInt;N:Integer):String;
Const
 Digits:Array[0..15]of Char='0123456789ABCDEF';
Var
 S:String;
Begin
 S:='';
 While N>0 do Begin
  S:=Digits[V and 15]+S;V:=V shr 4;Dec(N)
 End;DebugHex:=S
End;

Function DebugNumber(S:String;Var V:LongInt):Boolean;
Var
 P:Integer;
 OK:Boolean;
Begin
 P:=1;OK:=ParseNum(P,S,V);SkipSp(P,S);
 DebugNumber:=OK and(P>Length(S))
End;

Function PCodeInstruction(Address:LongInt;Var NextAddress:LongInt):String;
Var
 Op,Kind,B,N:Byte;
 Used,I:Integer;
 V:LongInt;
 S,T:String;
Begin
 NextAddress:=Address+1;
 if(Address<0)or(Address>=PCode_CodeSize)Then Begin
  PCodeInstruction:='<hors code>';Exit
 End;
 Op:=PCode_Fetch(Address);
 if Op<128 Then Begin
  Str(Op,T);PCodeInstruction:='SLDC '+T;Exit
 End;
 S:=Mnem128[Op];Kind:=Kind128[Op];
 Case Kind of
 OPK_NONE:;
 OPK_UB:
 Begin
  B:=PCode_Fetch(Address+1);Str(B,T);S:=S+' '+T;NextAddress:=Address+2
 End;
 OPK_SB:
 Begin
  Str(ShortInt(PCode_Fetch(Address+1)),T);S:=S+' '+T;NextAddress:=Address+2
 End;
 OPK_W:
 Begin
  V:=PCode_Fetch(Address+1)or(PCode_Fetch(Address+2)shl 8);
  Str(V,T);S:=S+' '+T;NextAddress:=Address+3
 End;
 OPK_BIG:
 Begin
  V:=PCode_ReadBig(Address+1,Used);Str(V,T);S:=S+' '+T;NextAddress:=Address+1+Used
 End;
 OPK_UBUB:
 Begin
  Str(PCode_Fetch(Address+1),T);S:=S+' '+T+',';
  Str(PCode_Fetch(Address+2),T);S:=S+T;NextAddress:=Address+3
 End;
 OPK_UBBIG,OPK_DBBIG:
 Begin
  B:=PCode_Fetch(Address+1);V:=PCode_ReadBig(Address+2,Used);
  Str(B,T);S:=S+' ';if Kind=OPK_DBBIG Then S:=S+'L';S:=S+T+',';Str(V,T);S:=S+T;
  NextAddress:=Address+2+Used
 End;
 OPK_LSA:
 Begin
  N:=PCode_Fetch(Address+1);S:=S+' '+PCode_IntToStr(N)+',"';
  For I:=0 to N-1 do Begin
   B:=PCode_Fetch(Address+2+I);
   if B in[32..126]Then S:=S+Chr(B)else S:=S+'.'
  End;
  S:=S+'"';NextAddress:=Address+2+N
 End;
 OPK_LDC:
 Begin
  N:=PCode_Fetch(Address+1);S:=S+' '+PCode_IntToStr(N);
  For I:=0 to N-1 do Begin
   V:=PCode_Fetch(Address+2+I*2)or
   (PCode_Fetch(Address+3+I*2)shl 8);S:=S+',$'+DebugHex(V,4)
  End;
  NextAddress:=Address+2+N*2
 End;
 OPK_XJP:
 Begin
 End;
End;PCodeInstruction:=S
End;

Procedure DebugCommand;
Const
 MaxBreakpoints=16;
 MaxRunCycles=10000000;
Var
 Name,Line,Command,Args,S:String;
 Breakpoint:Array[1..MaxBreakpoints]of LongInt;
 BreakCount,I,N:Integer;
 Address,V,NextAddress,RunCount:LongInt;
 Done,Hit:Boolean;

Function IsBreakpoint(A:LongInt):Boolean;
Var
 J:Integer;
Begin
 IsBreakpoint:=False;
 For J:=1 to BreakCount do if Breakpoint[J]=A Then Begin
  IsBreakpoint:=True;Exit
 End
End;

Procedure Registers;Begin
 WriteLn('PC=$',DebugHex(PCode_PC,4),'  SP=',PCode_SP,'  MP=',PCode_MP,
 '  cycles=',PCode_Cycles,'  sortie=',PCode_ExitCode);
 if not PCode_Halted Then WriteLn(DebugHex(PCode_PC,4),': ',
 PCodeInstruction(PCode_PC,NextAddress))else WriteLn('Machine arretee.')
End;

Procedure ResetMachine;Begin
 FillChar(PCode_Data^,SizeOf(TPCodeData),0);PCode_PC:=0;PCode_SP:=0;PCode_MP:=0;
 PCode_Cycles:=0;PCode_Halted:=False;PCode_ExitCode:=0
End;

Procedure DebugHelp;Begin
 WriteLn('S [n]       Executer une ou plusieurs instructions');
 WriteLn('G [adresse] Continuer jusqu''a un point d''arret');
 WriteLn('B [adresse] Poser ou afficher les points d''arret');
 WriteLn('BC adresse  Supprimer un point d''arret (BC ALL: tous)');
 WriteLn('U [a] [n]   Desassembler (10 instructions par defaut)');
 WriteLn('R            Afficher les registres de la VM');
 WriteLn('K [n]        Afficher la pile');
 WriteLn('M a [n]      Afficher la memoire de donnees');
 WriteLn('E a valeur   Modifier un mot de donnees');
 WriteLn('P adresse    Modifier le compteur programme');
 WriteLn('I            Reinitialiser le programme');
 WriteLn('Q            Quitter le debogueur')
End;
Begin
 Name:=ProgramFile;AskFile('Programme p-Code a deboguer',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.CODE')Then Name:=Name+'.CODE';
 if not FileExists(Name)Then Begin
  WriteLn('Fichier introuvable: ',Name);Exit
 End;
 GetMem(PCode_Mem,SizeOf(TPCodeMemory));GetMem(PCode_Data,SizeOf(TPCodeData));
 if not PCode_LoadRaw(Name)Then Begin
  WriteLn('Chargement impossible.');
  FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory));Exit
 End;
 ProgramFile:=Name;BreakCount:=0;FillChar(Breakpoint,SizeOf(Breakpoint),0);
 Done:=False;ResetMachine;
 WriteLn('Debogueur p-System interne - ',PCode_CodeSize,
 ' octet(s). Tapez ? pour l''aide.');
 Registers;
 Repeat
 Write('Debug> ');ReadLn(Line);Line:=TrimString(Line);if Line=''Then Command:='S'else
 Begin
  I:=Pos(' ',Line);if I=0 Then Begin
   Command:=UpperString(Line);Args:=''
  End
  else
  Begin
   Command:=UpperString(Copy(Line,1,I-1));Args:=TrimString(Copy(Line,I+1,255))
  End
 End;
 if(Command='?')or(Command='H')or(Command='HELP')Then DebugHelp
 else if Command='R'Then Registers
 else if Command='I'Then Begin
  ResetMachine;Registers
 End
 else if Command='Q'Then Done:=True
 else if Command='P'Then Begin
  if DebugNumber(Args,Address)and(Address>=0)and(Address<PCode_CodeSize)Then Begin
   PCode_PC:=Address;PCode_Halted:=False;Registers
  End else WriteLn('Adresse incorrecte.')
 End
 else if Command='S'Then Begin
  if Args=''Then N:=1 else if DebugNumber(Args,V)Then N:=V else N:=0;
  if N<1 Then WriteLn('Nombre de pas incorrect.')else
  Begin
   For I:=1 to N do if not PCode_Halted Then Begin
    PCode_Step;Inc(PCode_Cycles)
   End;
   Registers
  End
 End
 else if Command='G'Then Begin
  if Args<>''Then if DebugNumber(Args,Address)and(Address>=0)and(Address<PCode_CodeSize)
  Then Begin
   PCode_PC:=Address;PCode_Halted:=False
  End else
  Begin
   WriteLn('Adresse incorrecte.');Continue
  End;
  RunCount:=0;Hit:=False;
  Repeat
  if IsBreakpoint(PCode_PC)Then Begin
   Hit:=True;Break
  End;
  if PCode_Fetch(PCode_PC)=213 Then Begin
   Hit:=True;WriteLn('Point BPT atteint.');Break
  End;
  PCode_Step;Inc(PCode_Cycles);Inc(RunCount)
  Until PCode_Halted or(RunCount>=MaxRunCycles);
  if Hit Then WriteLn('Point d''arret a $',DebugHex(PCode_PC,4));
  if RunCount>=MaxRunCycles Then WriteLn('Limite d''execution atteinte.');Registers
 End
 else if Command='B'Then Begin
  if Args=''Then Begin
   if BreakCount=0 Then WriteLn('Aucun point d''arret.');
   For I:=1 to BreakCount do WriteLn(I:2,': $',DebugHex(Breakpoint[I],4))
  End else if not DebugNumber(Args,Address)or(Address<0)or(Address>=PCode_CodeSize)
  Then    WriteLn('Adresse incorrecte.')
  else if IsBreakpoint(Address)Then WriteLn('Point d''arret deja present.')
  else if BreakCount=MaxBreakpoints Then WriteLn('Table des points d''arret pleine.')
  else
  Begin
   Inc(BreakCount);Breakpoint[BreakCount]:=Address;
   WriteLn('Point d''arret pose a $',DebugHex(Address,4))
  End
 End
 else if Command='BC'Then Begin
  if UpperString(Args)='ALL'Then BreakCount:=0
  else if DebugNumber(Args,Address)Then Begin
   I:=1;
   While(I<=BreakCount)and(Breakpoint[I]<>Address)do Inc(I);
   if I>BreakCount Then WriteLn('Point d''arret introuvable.')else
   Begin
    For N:=I to BreakCount-1 do Breakpoint[N]:=Breakpoint[N+1];Dec(BreakCount)
   End
  End else WriteLn('Adresse incorrecte.')
 End
 else if Command='U'Then Begin
  Address:=PCode_PC;N:=10;if Args<>''Then Begin
   I:=Pos(' ',Args);if I=0 Then Begin
    if not DebugNumber(Args,Address)Then N:=0
   End
   else
   Begin
    S:=Copy(Args,1,I-1);Delete(Args,1,I);Args:=TrimString(Args);
    if not DebugNumber(S,Address)or not DebugNumber(Args,V)Then N:=0 else N:=V
   End
  End;
  if(N<1)or(Address<0)or(Address>=PCode_CodeSize)Then WriteLn('Parametres incorrects.')
  else
  For I:=1 to N do if Address<PCode_CodeSize Then Begin
   S:=PCodeInstruction(Address,NextAddress);WriteLn(DebugHex(Address,4),': ',S);
   if NextAddress<=Address Then Address:=Address+1 else Address:=NextAddress
  End
 End
 else if Command='K'Then Begin
  if Args=''Then N:=16 else if DebugNumber(Args,V)Then N:=V else N:=0;
  if N<0 Then N:=0;if N>PCode_SP Then N:=PCode_SP;
  For I:=PCode_SP-N to PCode_SP-1 do WriteLn(I:5,': ',PCode_Data^[I])
 End
 else if Command='M'Then Begin
  I:=Pos(' ',Args);if I=0 Then Begin
   S:=Args;N:=16
  End else
  Begin
   S:=Copy(Args,1,I-1);Delete(Args,1,I);if not DebugNumber(TrimString(Args),V)Then V:=0;
   N:=V
  End;
  if not DebugNumber(S,Address)or(Address<0)or(Address>High(PCode_Data^))or(N<1)
  Then    WriteLn('Parametres incorrects.')else
  Begin
   if Address+N-1>High(PCode_Data^)Then N:=High(PCode_Data^)-Address+1;
   For I:=0 to N-1 do WriteLn(Address+I:5,': ',PCode_Data^[Address+I])
  End
 End
 else if Command='E'Then Begin
  I:=Pos(' ',Args);if I=0 Then WriteLn('Syntaxe: E adresse valeur')else
  Begin
   S:=Copy(Args,1,I-1);Delete(Args,1,I);
   if DebugNumber(S,Address)and DebugNumber(TrimString(Args),V)and
   (Address>=0)and(Address<=High(PCode_Data^))Then PCode_Data^[Address]:=V
   else WriteLn('Parametres incorrects.')
  End
 End else WriteLn('Commande inconnue. Tapez ? pour l''aide.')
 Until Done;
 FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory))
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
 WriteLn('X  Executer un fichier p-Code .CODE avec la machine virtuelle integree');
 WriteLn('A  Assembler un fichier source');
 WriteLn('D  Lancer le debogueur p-Code integre');
 WriteLn('Q  Quitter PSYSTEM');
 WriteLn('/TARGET:nom  Choisir la version du p-System cible');
 WriteLn('  APPLEHEALT, UCSDPASCALII, UCSDPSYSTEMIII ou UCSDPSYSTEMIV');
 WriteLn('Cible courante: ',TargetName);
 WriteLn;
 WriteLn(
 'Les outils externes peuvent etre choisis avec PSYSTEM_EDITOR et PSYSTEM_LINKER.');
 WriteLn(
 'Le compilateur, l''assembleur, l''executeur et le debogueur p-Code sont integres.')
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
 WorkFile:='';ProgramFile:='';CurrentTarget:=ptUCSDPSystemIV;
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')or(UpperString(S)='HELP')Then Begin
   WriteLn('PSYSTEM ',Version,' - Cette commande permet lancer ',
   'l''environnement de commande UCSD p-System.');
   Help;
   Halt(0)
  End else if(Copy(UpperString(S),1,8)='/TARGET:')or
   (Copy(UpperString(S),1,8)='-TARGET:')Then Begin
   if not SelectTarget(Copy(S,9,255))Then Begin
    WriteLn('Cible p-System inconnue: ',Copy(S,9,255));Halt(1)
   End
  End else if WorkFile=''Then WorkFile:=S
  else
  Begin
   WriteLn('Syntaxe : PSYSTEM [fichier-de-travail] [/TARGET:cible]');
   Halt(1)
  End
 End;
 if WorkFile<>''Then ProgramFile:=ReplaceExtension(WorkFile,'.CODE')
End;

BEGIN
 CommandLine;Finished:=False;
 WriteLn('UCSD p-System compatible command environment ',Version);
 WriteLn('Cible: ',TargetName);
 if WorkFile<>''Then WriteLn('Work file: ',WorkFile);
 Repeat Prompt Until Finished;
 WriteLn('System halted.')
END.
