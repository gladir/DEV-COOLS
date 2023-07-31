{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program TPUINFO;

Var
 FileTPU:File;
 S:String;
 A:Array[1..4]of byte;
 I:Integer;

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
  WriteLn('TPUINFO : Cette commande permet de retourner les informations  ',
                   'de version d''une unit‚ Turbo Pascal.');
  WriteLn;
  WriteLn('Syntaxe : TPUINFO [/?]');
  WriteLn('          TPUINFO filename');
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
  Assign(FileTPU,S);
  Reset(FileTPU,1);
  Blockread(FileTPU,A,4);

  If A[1]<>$54 Then Begin { T }
   Writeln('Le fichier sp‚cifi‚ n''est pas un unit‚ Turbo Pascal.');
   Halt(2);
  End;
  Write('Version de l''unit‚ Turbo Pascal : ');
  Case a[4] of
{ 0 } $30:WriteLn('4.0');
{ 5 } $35:WriteLn('5.0');
{ 6 } $36:WriteLn('5.5');
{ 9 } $39:WriteLn('6.0');
{ Q } $51:WriteLn('7.0, mode r‚el');
      Else Writeln('Inconnu');
  End;
  Close(FileTPU);
 End
  Else
 WriteLn('ParamŠtre attendu !');
END.

