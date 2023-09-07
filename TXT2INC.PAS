{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program TXT2INC;

Var
 SourceASC,TargetPas:Text;
 CurrLine:String;

Function StringToPascalString(Source:String):String;
Var
 I:Integer;
 ConvStr:String;
Begin
 ConvStr:='';
 For I:=1 to Length(Source)do Begin
  If Source[I]=''''Then ConvStr:=ConvStr+'''';
  ConvStr:=ConvStr+Source[I];
 End;
 StringToPascalString:=ConvStr;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('TXT2INC : Cette commande permet de convertir un ',
                    'texte en chaine de caractŠres entre guillemet ',
                    'pour Pascal.');
  WriteLn;
  WriteLn('Syntaxe : TXT2INC source target constname');
  WriteLn;
 End
  Else
 If ParamCount>0 Then Begin
  Assign(SourceASC,ParamStr(1));
  {$I-}Reset(SourceASC);{$I+}
  If IoResult<>0Then Begin
   WriteLn('Fichier ASCII introuvable !');
   Halt;
  End;
  Assign(TargetPas,ParamStr(2));
  {$I+}Rewrite(TargetPas); {$I+}
  If IoResult<>0Then Begin
   WriteLn('Impossible de cr‚er le fichier Pascal !');
   Close(SourceASC);
   Halt;
  End;
  WriteLn(TargetPas,'Const ',ParamStr(3),':String=');
  While Not EOF(SourceASC)do Begin
   ReadLn(SourceASC,CurrLine);
   If CurrLine=''Then WriteLn(TargetPas,' LineEnding +')
    Else
   Begin
    WriteLn(TargetPas,' ''',StringToPascalString(CurrLine),''' + LineEnding +');
   End;
  End;
  WriteLn(TargetPas,''''';');
  Close(TargetPas);
  Close(SourceASC);
 End
  Else
 WriteLn('ParamŠtre requis !');
END.