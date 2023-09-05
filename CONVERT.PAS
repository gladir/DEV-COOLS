{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/corail)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program CONVERT;

Var
 FileInput:Text;
 Ch:Char;
 FirstChar:Boolean;
 InString,InComment:boolean;
 UpperCase:Set of Char;
 I:Integer;
 Mode:(_LowerCase,_UpperCase,_Capital);

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function LoCase(C:Char):Char;Begin
 If C in['A'..'Z']Then LoCase:=Chr(Ord(C)+32)
                  Else LoCase:=C;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('CONVERT : Cette commande permet de convertir en ',
                    'minuscule, majuscule ou capitale un fichier ',
                    'de code source Pascal.');
  WriteLn;
  WriteLn('Syntaxe : CONVERT [/LOWER|/UPPER|/CAPITAL] nomdufichier.pas');
  WriteLn;
  WriteLn(' nomdufichier.pas  Nom du fichier de code source Pascal.');
  WriteLn(' /CAPITAL          Convertie les mots en capitale.');
  WriteLn(' /LOWER            Force Ö convertir en minuscule. ',
                              'Valeur par dÇfaut');
  WriteLn(' /UPPER            Force Ö convertir en majuscule.');
  WriteLn;
 End
  Else
 If ParamCount>0 Then Begin
  Mode:=_LowerCase;
  For I:=1 to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/LOWER'Then Mode:=_LowerCase Else
   If StrToUpper(ParamStr(I))='/UPPER'Then Mode:=_UpperCase Else
   If StrToUpper(ParamStr(I))='/CAPITAL'Then Mode:=_Capital;
  End;
  For I:=1 to ParamCount do If(StrToUpper(ParamStr(I))<>'/LOWER')and
                              (StrToUpper(ParamStr(I))<>'/UPPER')and
                              (StrToUpper(ParamStr(I))<>'/CAPITAL')Then Begin
   {$I-}Assign(FileInput,ParamStr(I));
   Reset(FileInput);{$I+}
   If IoResult=0 Then Begin
    InString:=False;
    InComment:=False;
    If(Mode=_Capital)Then Begin
     FirstChar:=True;
     While Not Eof(FileInput)do Begin
      While not Eoln(FileInput) do Begin
       Read(FileInput,Ch);
       If(Ch = '''')and(Not InComment)Then InString:=Not InString;
       If(Ch = '{')and(Not InString)Then InComment:=True;
       If(Ch = '}')and(Not InString)Then InComment:=False;
       If Not(InString)and Not(InComment)Then Begin
        If Ch in['A'..'Z','a'..'z']Then Begin
         If(FirstChar)Then Begin
          Write(UpCase(Ch));
          FirstChar:=False;
         End
          Else
         Write(LoCase(Ch));
        End
         Else
        Begin
         FirstChar:=True;
         Write(Ch);
        End;
       End
        else
       Write(Ch);
      End;
      Readln(FileInput);
      WriteLn;
     End;
    End
     Else
    If(Mode=_UpperCase)Then Begin
     UpperCase:=['a'..'z'];
     While Not Eof(FileInput)do Begin
      While not Eoln(FileInput) do Begin
       Read(FileInput,ch);
       If(Ch = '''')and(Not InComment)Then InString:=Not InString;
       If(Ch = '{')and(Not InString)Then InComment:=True;
       If(Ch = '}')and(Not InString)Then InComment:=False;
       If Not(InString)and Not(InComment)Then Begin
        If Ch in UpperCase Then Write(Chr(Ord(ch)-Ord('a')+Ord('A')))
                           Else Write(Ch);
       End
        else
       Write(Ch);
      End;
      Readln(FileInput);
      WriteLn;
     End;
    End
     Else
    Begin
     UpperCase:=['A'..'Z'];
     While Not Eof(FileInput)do Begin
      While not Eoln(FileInput) do Begin
       Read(FileInput,ch);
       If(Ch = '''')and(Not InComment)Then InString:=Not InString;
       If(Ch = '{')and(Not InString)Then InComment:=True;
       If(Ch = '}')and(Not InString)Then InComment:=False;
       If Not(InString)and Not(InComment)Then Begin
        If Ch in UpperCase Then Write(Chr(Ord(ch)-Ord('A')+Ord('a')))
                           Else Write(Ch);
       End
        else
       Write(Ch);
      End;
      Readln(FileInput);
      WriteLn;
     End;
    End;
    Close(FileInput);
   End
    Else
   WriteLn('Impossible de lire le fichier : ',ParamStr(I));
  End;
 End
  Else
 WriteLn('Paramätre attendu !');
END.