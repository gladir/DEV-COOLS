{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program COM2EXE;

Type
 ExeHead=Array[1..32]of Byte;

Const
 ExeHeader:ExeHead=(
  $4D,$5A,$00,$00,$12,$00,$00,$00,$02,$00,$D7,$0D,$FF,$FF,
  $F0,$FF,$FE,$FF,$00,$00,$00,$01,$F0,$FF,$1C,$00,$00,$44,
  $6f,$74,$61,$6e);

Var
 Buf:Array[1..4096]of Byte;
 FileCOM,FileEXE:File;
 Size,I,J:Word;
 FileNameCOM,FileNameEXE:String;
 W:Byte;

Function FileExists(FileName:String):Boolean;
Var
 F:File;
Begin
 {$I-}Assign(F,FileName);
 Reset(F);
 Close(F);
 {$I+}
 FileExists:=(IOResult=0)and(FileName<>'');
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('COM2EXE : Cette commande permet de convertir un fichier COM ',
                     'en fichier EXE.');
  WriteLn;
  Writeln('Syntaxe: COM2EXE [/?] source [dest]');
  WriteLn;
  WriteLn('/?      Ce paramätre permet de fournir de l''aide sur cette commande');
  WriteLn('source  Ce paramätre permet d''indiquer le fichier .COM');
  WriteLn('dest    Ce paramätre peremt d''indiquer le fichier .EXE');
 End
  Else
 If ParamCount>0 Then Begin
  FileNameEXE:=ParamStr(1);
  If Not FileExists(FileNameEXE)Then Begin
   WriteLn('Fichier introuvable !');
   Halt(1)
  End;
  For w:=1 to Length(FileNameEXE) do FileNameEXE[w]:=UpCase(FileNameEXE[w]);
  FileNameCOM:=FileNameEXE;
  Assign(FileCOM,FileNameEXE);
  Reset(FileCOM,1);
  Size:=FileSize(FileCOM)+32;
  If ParamCount=2 Then Begin
   FileNameEXE:=ParamStr(2);
   For w:=1 to Length(FileNameEXE)do FileNameEXE[w]:=upcase(FileNameEXE[w]);
  End
   Else
  Begin
   W:=(Pos('.',FileNameEXE));
   Inc(W);
   Delete(FileNameEXE,W,Length(FileNameEXE)-w+1);
   Insert('EXE',FileNameEXE,w);
  End;
  Assign(FileEXE,FileNameEXE);
  Rewrite(FileEXE,1);
  ExeHeader[3]:=(Size mod 512);
  ExeHeader[5]:=(Size div 512)+1;
  BlockWrite(FileEXE,ExeHeader,32);
  Repeat
   BlockRead(FileCOM,Buf,4096,I);
   BlockWrite(FileEXE,Buf,I,J);
  Until(I<>4096)or(J<>I);
  Close(FileCOM);
  Close(FileEXE);
  Writeln('Conversion de ',FileNameCOM,' Ö ',FileNameEXE,' !');
 End
  Else
 WriteLn('Paramätre requis !');
END.