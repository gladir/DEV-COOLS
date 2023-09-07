{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PAS2HTML;

Const
 ReservedWord:Array[1..26]of String[12]=(
  'AND','ARRAY','ASM','BEGIN','CASE','CONST','DO','ELSE',
  'END','FILE','FOR','FUNCTION','IF','NOT','OF','OR','PROCEDURE',
  'PROGRAM','RECORD','REPEAT','STRING','THEN','TO','UNTIL',
  'VAR','WHILE'
 );

Var
 FileSource:Text;
 Ch:Char;
 InString,InComment,NoColor:Boolean;
 CurrWord:String;
 I:Integer;

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

Procedure DumpWord;
Var
 I:Integer;
 IsReservedWord:Boolean;
Begin
 IsReservedWord:=False;
 If CurrWord<>''Then Begin
  For I:=1 to High(ReservedWord) do Begin
   If StrToUpper(ReservedWord[I])=StrToUpper(CurrWord)Then Begin
    If(NoColor)Then Write('<b>')
               Else Write('<b style="color:white;">');
    IsReservedWord:=True;
    Break;
   End;
  End;
  If Not(IsReservedWord)Then Begin
   If Not(NoColor)Then Write('<span style="color:magenta;">');
  End;
  Write(CurrWord);
  If(IsReservedWord)Then Write('</b>')
   Else
  Begin
   If Not(NoColor)Then Write('</span>');
  End;
  CurrWord:='';
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('PAS2HTML : Cette commande permet de convertir un ',
                    'un fichier de code source Pascal en ',
                    'syntaxe color‚ HTML.');
  WriteLn;
  WriteLn('Syntaxe : PAS2HTML [/NOCOLOR] nomdufichier.pas');
  WriteLn;
  WriteLn(' nomdufichier.pas  Nom du fichier de code source Pascal.');
  WriteLn(' /NOCOLOR          Pas de couleur dans la syntaxe');
  WriteLn;
 End
  Else
 If ParamCount>0 Then Begin
  NoColor:=False;
  For I:=1 to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/NOCOLOR'Then NoColor:=True;
  End;
  For I:=1 to ParamCount do If StrToUpper(ParamStr(I))<>'/NOCOLOR'Then Begin
   {$I-}Assign(FileSource,ParamStr(I));
   Reset(FileSource);{$I+}
   If IoResult=0Then Begin
    If Not(NoColor)Then WriteLn('<code><div style="background-color:darkblue;">');
    InString:=False;
    InComment:=False;
    CurrWord:='';
    While Not EOF(FileSource)do Begin
     While Not Eoln(FileSource) do Begin
      Read(FileSource,Ch);
      If(Ch = '''')and(Not InComment)Then Begin
       If Not(NoColor)Then Case(InString)of
        True:Write('</span>');
        False:Write('<span style="color:red;">');
       End;
       InString:=Not InString;
      End;
      If(Ch = '{')and(Not InString)Then Begin
       InComment:=True;
       If(NoColor)Then Write('<i>')
                  Else Write('<i style="color:yellow;">');
      End;
      If(Ch = '}')and(Not InString)Then Begin
       InComment:=False;
       Write('</i>');
      End;
      If Not(InString)and Not(InComment)Then Begin
       If Ch in['A'..'Z','a'..'z']Then Begin
        CurrWord:=CurrWord+Ch;
       End
        Else
       Begin
        DumpWord;
        If Ch = ''''Then Begin
         If(NoColor)Then Write('<span>')
                    Else Write('<span style="color:red;">');
         Write(Ch);
         Write('</span>');
        End
         Else
        If Ch = '}'Then Begin
         If(NoColor)Then Write('<i>')
                    Else Write('<i style="color:yellow;">');
         Write(Ch);
         Write('</i>');
        End
         Else
        If Ch in['0'..'9']Then Begin
         If(NoColor)Then Write('<span>')
                    Else Write('<span style="color:lightblue;">');
         Write(Ch);
         Write('</span>');
        End
         Else
        If Ch in['+','-','*','/',':','=','(',')','[',']','.',',','<','>','$','#',';']Then Begin
         If Not(NoColor)Then Write('<span style="color:cyan">');
         Write(Ch);
         If Not(NoColor)Then Write('</span>');
        End
         Else
        If Ch=' 'Then Write('&nbsp;')
                 Else Write(Ch);
       End;
      End
       else
      Begin
       DumpWord;
       If Ch=' 'Then Write('&nbsp;')
                Else Write(Ch);
      End;
     End;
     DumpWord;
     WriteLn('<br />');
     Readln(FileSource);
    End;
    Close(FileSource);
    If Not(NoColor)Then WriteLn('</div></code>');
   End
    Else
   WriteLn('Erreur de lecture du fichier : ',ParamStr(I));
  End;
 End;
END.