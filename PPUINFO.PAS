{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program PPUINFO;

Var
 FilePPU:File;
 S:String;
 A:Array[1..3]of Char;
 Sign,FileFormatVersion:String[3];
 VersionMajor,VersionMinor:Byte;
 TargetProcessor,OperatingSystem:Word;
 I:Integer;
 ByteReaded:Word;

Function FileExists(FileName:String):Boolean;
Var
 F:File;
Begin
 {$I-}Assign(F,FileName);
 Reset(f);
 Close(f);{$I+}
 FileExists:=(IOResult=0)and(FileName<>'');
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PPUINFO : Cette commande permet de retourner les informations  ',
                   'de version d''une unit‚ Free Pascal.');
  WriteLn;
  WriteLn('Syntaxe : PPUINFO [/?]');
  WriteLn('          PPUINFO filename');
  WriteLn;
  WriteLn('/?        Ce paramŠtre permet d''afficher l''aide sur cette comamnde.');
  WriteLn('filename  Ce paramŠtre permet d''indiquer le fichier … analyser.');
 End
  Else
 If ParamCount>0 Then Begin
  S:=ParamStr(1);
  For I:=1 to Length(s)do S[I]:=UpCase(S[I]);
  If(Pos('.TPU',s)=0)and(Pos('.',S)=0)Then Insert('.TPU',s,length(s)+1);
  For I:=1 to Length(S)do S[I]:=UpCase(S[i]);
  If Not FileExists(s)Then Begin
   Writeln('Le fichier ',s,' est introuvable.');
   Halt(1);
  End;
  {$I-}Assign(FilePPU,S);
  Reset(FilePPU,1);{$I+}
  If IoResult=0 Then Begin
   Blockread(FilePPU,A,3,ByteReaded);
   Sign[0]:=#03;
   Move(A[1],Sign[1],3);
   If Sign<>'PPU' Then Begin { P }
    Writeln('Le fichier sp‚cifi‚ n''est pas un unit‚ Free Pascal.');
    Halt(2);
   End;
   Blockread(FilePPU,A,3);
   FileFormatVersion[0]:=#03;
   Move(A[1],FileFormatVersion[1],3);
   WriteLn('Signature : ',Sign);
   WriteLn('Version du format de fichier : ',FileFormatVersion);
   Blockread(FilePPU,VersionMajor,1,ByteReaded);
   Blockread(FilePPU,VersionMinor,1,ByteReaded);
   WriteLn('Version : ',VersionMajor,'.',VersionMinor);
   Blockread(FilePPU,TargetProcessor,2,ByteReaded);
   Write('Processeur cible : ');
   Case TargetProcessor of
    1:WriteLn('Compatible Intel 80x86');
    2:WriteLn('Motorola 680x0 ou compatible');
    3:WriteLn('Alpha AXP ou compatible');
    4:WriteLn('PowerPC ou compatible');
    Else WriteLn('Inconnu : ',TargetProcessor);
   End;
   Write('SystŠme cible : ');
   BlockRead(FilePPU,OperatingSystem,2,ByteReaded);
   Case OperatingSystem of
    5:WriteLn('Windows');
    Else WriteLn('Inconnu : ',OperatingSystem);
   End;
   Close(FilePPU);
  End
   Else
  Begin
   WriteLn('Impossible de lire le fichier ',S,'!');
   Halt;
  End;
 End
  Else
 WriteLn('ParamŠtre attendu !');
END.