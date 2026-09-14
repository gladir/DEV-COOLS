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

Function TrimString(S:String):String;
Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 TrimString:=S
End;

Function UpperString(S:String):String;
Var I:Integer;
Begin
 For I:=1 to Length(S)do S[I]:=UpCase(S[I]);UpperString:=S
End;

Function QuoteName(S:String):String;
Begin
 if Pos(' ',S)<>0 Then QuoteName:='"'+S+'"'else QuoteName:=S
End;

Function ReplaceExtension(S,Ext:String):String;
Var I,P:Integer;
Begin
 P:=0;For I:=Length(S)downto 1 do Begin
  if S[I]='.'Then Begin P:=I;Break End;
  if S[I]in['\','/',':']Then Break
 End;
 if P<>0 Then S:=Copy(S,1,P-1);ReplaceExtension:=S+Ext
End;

Function ToolName(VariableName,DefaultName:String):String;
Var R:String;
Begin
 R:=GetEnv(VariableName);if R=''Then R:=DefaultName;ToolName:=R
End;

Function RunShell(CommandLine:String):Integer;
Var ShellName,Parameters:String;ResultCode:Word;
Begin
 ShellName:=GetEnv('COMSPEC');
 if ShellName=''Then ShellName:='COMMAND.COM';
 Parameters:='/C '+CommandLine;SwapVectors;Exec(ShellName,Parameters);SwapVectors;
 if DosError<>0 Then Begin
  WriteLn('Unable to start command processor (error ',DosError,').');RunShell:=DosError
 End else Begin
  ResultCode:=DosExitCode;RunShell:=Lo(ResultCode)
 End
End;

Procedure AskFile(Prompt:String;Var Name:String);
Var S:String;
Begin
 if Name<>''Then Write(Prompt,' [',Name,']: ')else Write(Prompt,': ');
 ReadLn(S);S:=TrimString(S);if S<>''Then Name:=S
End;

Function FileExists(Name:String):Boolean;
Var F:File;Exists:Boolean;
Begin
 Assign(F,Name);Reset(F,1);Exists:=IOResult=0;
 if Exists Then Begin Close(F);if IOResult<>0 Then Exists:=False End;
 FileExists:=Exists
End;

Procedure EditCommand;
Var Editor:String;
Begin
 AskFile('Edit file',WorkFile);if WorkFile=''Then Exit;
 Editor:=ToolName('PSYSTEM_EDITOR',GetEnv('EDITOR'));
 if Editor=''Then Editor:='EDIT';
 RunShell(Editor+' '+QuoteName(WorkFile))
End;

Function CompileWork(AskName:Boolean):Boolean;
Var Compiler:String;Code:Integer;
Begin
 CompileWork:=False;if AskName or(WorkFile='')Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if not FileExists(WorkFile)Then Begin WriteLn('File not found: ',WorkFile);Exit End;
 Compiler:=ToolName('PSYSTEM_COMPILER','FPC');
 WriteLn('Compiling ',WorkFile,' ...');Code:=RunShell(Compiler+' '+QuoteName(WorkFile));
 if Code<>0 Then Begin WriteLn('Compile failed (status ',Code,').');Exit End;
 ProgramFile:=ReplaceExtension(WorkFile,'.exe');CompileWork:=True;
 WriteLn('Compilation complete.')
End;

Procedure RunCommand;
Begin
 if WorkFile=''Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if(ProgramFile='')or not FileExists(ProgramFile)Then
  if not CompileWork(False)Then Exit;
 WriteLn('Running ',ProgramFile,' ...');RunShell(QuoteName(ProgramFile))
End;

Procedure ExecuteCommand;
Var Name:String;
Begin
 Name:=ProgramFile;AskFile('Program file',Name);if Name=''Then Exit;
 if not FileExists(Name)Then Begin WriteLn('File not found: ',Name);Exit End;
 ProgramFile:=Name;RunShell(QuoteName(Name))
End;

Procedure LinkCommand;
Var Modules,OutputName,Linker,CommandLine:String;Code:Integer;
Begin
 Write('Object files: ');ReadLn(Modules);Modules:=TrimString(Modules);
 if Modules=''Then Exit;OutputName:=ProgramFile;AskFile('Output program',OutputName);
 if OutputName=''Then Exit;Linker:=ToolName('PSYSTEM_LINKER','FPC');
 CommandLine:=Linker+' '+Modules+' -o'+QuoteName(OutputName);
 WriteLn('Linking ',OutputName,' ...');Code:=RunShell(CommandLine);
 if Code=0 Then Begin ProgramFile:=OutputName;WriteLn('Link complete.')End
 else WriteLn('Link failed (status ',Code,').')
End;

Procedure AssembleCommand;
Var Name,Assembler:String;Code:Integer;
Begin
 Name:='';AskFile('Assembly source',Name);if Name=''Then Exit;
 Assembler:=ToolName('PSYSTEM_ASSEMBLER','ASM');Code:=RunShell(Assembler+' '+QuoteName(Name));
 if Code<>0 Then WriteLn('Assembly failed (status ',Code,').')
End;

Procedure DebugCommand;
Var Name,Debugger:String;
Begin
 Name:=ProgramFile;AskFile('Program to debug',Name);if Name=''Then Exit;
 Debugger:=ToolName('PSYSTEM_DEBUGGER','DEBUG');RunShell(Debugger+' '+QuoteName(Name))
End;

Procedure ListFiles;
Var Mask:String;Info:SearchRec;
Begin
 Mask:='*.*';AskFile('File mask',Mask);FindFirst(Mask,AnyFile,Info);
 if DosError<>0 Then Begin WriteLn('No files.');Exit End;
 While DosError=0 do Begin
  if(Info.Name<>'.')and(Info.Name<>'..')Then Begin
   Write(Info.Name:20);
   if(Info.Attr and Directory)<>0 Then WriteLn('   <DIR>')else WriteLn(Info.Size:10)
  End;FindNext(Info)
 End
End;

Procedure CopyFileCommand;
Var Source,Target:String;A,B:File;Buffer:Array[1..8192]of Byte;N,W:Word;OK:Boolean;
Begin
 Source:='';Target:='';AskFile('Copy from',Source);if Source=''Then Exit;
 AskFile('Copy to',Target);if Target=''Then Exit;
 if UpperString(FExpand(Source))=UpperString(FExpand(Target))Then Begin
  WriteLn('Source and destination are the same file.');Exit
 End;
 Assign(A,Source);Reset(A,1);if IOResult<>0 Then Begin WriteLn('Cannot open ',Source);Exit End;
 Assign(B,Target);Rewrite(B,1);if IOResult<>0 Then Begin Close(A);WriteLn('Cannot create ',Target);Exit End;
 OK:=True;
 Repeat
  BlockRead(A,Buffer,SizeOf(Buffer),N);if IOResult<>0 Then Begin OK:=False;Break End;
  if N<>0 Then Begin BlockWrite(B,Buffer,N,W);if(IOResult<>0)or(W<>N)Then OK:=False End
 Until(N=0)or not OK;
 Close(A);if IOResult<>0 Then OK:=False;Close(B);if IOResult<>0 Then OK:=False;
 if OK Then WriteLn('Copy complete.')else WriteLn('Copy failed.')
End;

Procedure RenameFileCommand;
Var OldName,NewName:String;F:File;
Begin
 OldName:='';NewName:='';AskFile('Rename file',OldName);if OldName=''Then Exit;
 AskFile('New name',NewName);if NewName=''Then Exit;
 Assign(F,OldName);Rename(F,NewName);
 if IOResult<>0 Then WriteLn('Rename failed.')else WriteLn('Rename complete.')
End;

Procedure DeleteFileCommand;
Var Name,Answer:String;F:File;
Begin
 Name:='';AskFile('Delete file',Name);if Name=''Then Exit;
 Write('Delete ',Name,' (Y/N)? ');ReadLn(Answer);
 if(Answer='')or not(UpCase(Answer[1])='Y')Then Exit;
 Assign(F,Name);Erase(F);if IOResult<>0 Then WriteLn('Delete failed.')else WriteLn('Deleted.')
End;

Procedure VolumeCommand;
Var DirectoryName:String;
Begin
 GetDir(0,DirectoryName);WriteLn('Current volume and directory: ',DirectoryName);
 WriteLn('Free bytes: ',DiskFree(0));WriteLn('Total bytes: ',DiskSize(0))
End;

Procedure FileCommand;
Var S:String;Done:Boolean;
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
   '?':WriteLn('List, Copy, Rename, Delete, Volume, Quit');
  else WriteLn('Unknown file command.')End
 Until Done
End;

Procedure Help;
Begin
 WriteLn('E  Edit the current source file');
 WriteLn('R  Compile when necessary and run the work program');
 WriteLn('F  File manager');
 WriteLn('C  Compile the current Pascal source');
 WriteLn('L  Link object files');
 WriteLn('X  Execute an existing program');
 WriteLn('A  Assemble a source file');
 WriteLn('D  Start the debugger');
 WriteLn('Q  Quit PSYSTEM');
 WriteLn;
 WriteLn('External tools may be selected with PSYSTEM_EDITOR, PSYSTEM_COMPILER,');
 WriteLn('PSYSTEM_LINKER, PSYSTEM_ASSEMBLER and PSYSTEM_DEBUGGER.')
End;

Procedure Prompt;
Var S:String;
Begin
 WriteLn;
 Write('Command: E(dit, R(un, F(ile, C(omp, L(ink, ');
 Write('X(ecute, A(ssem, D(ebug, Q)uit ? ');ReadLn(S);S:=UpperString(TrimString(S));
 if S=''Then Exit;
 Case S[1]of
  'E':EditCommand;
  'R':RunCommand;
  'F':FileCommand;
  'C':if CompileWork(True)Then Begin End;
  'L':LinkCommand;
  'X':ExecuteCommand;
  'A':AssembleCommand;
  'D':DebugCommand;
  'Q':Finished:=True;
  '?':Help;
 else WriteLn('Unknown command. Type ? for help.')End
End;

Procedure CommandLine;
Var I:Integer;S:String;
Begin
 WorkFile:='';ProgramFile:='';
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')or(UpperString(S)='HELP')Then Begin
   WriteLn('PSYSTEM ',Version,' - UCSD p-System command environment.');Help;Halt(0)
  End else if WorkFile=''Then WorkFile:=S
  else
  Begin
   WriteLn('Syntaxe: PSYSTEM [workfile]');
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
