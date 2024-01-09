{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program ROT13PAS;

Const
 ReservedWord:Array[1..26]of String[12]=(
  'AND','ARRAY','ASM','BEGIN','CASE','CONST','DO','ELSE',
  'END','FILE','FOR','FUNCTION','IF','NOT','OF','OR','PROCEDURE',
  'PROGRAM','RECORD','REPEAT','STRING','THEN','TO','UNTIL',
  'VAR','WHILE'
 );

 BuiltinFunction:Array[1..36]of String[12]=(
  'ABS','APPEND','ASSIGN','BLOCKREAD','BLOCKWRITE','BOOLEAN','BREAK',
  'BYTE','CHAR','CHR','CLOSE','CONTINUE','DOUBLE','EXIT','FILESIZE',
  'HALT','INSERT','INTEGER','IORESULT','LENGTH','LONGINT','ORD',
  'PARAMCOUNT','POS','PARAMSTR','PRED','READ','READLN','REAL',
  'RESET','REWRITE','SINGLE','SUCC','UPCASE','WRITE','WRITELN'
 );

Var
 FileSource:Text;
 Ch:Char;
 InString,InComment:Boolean;
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

Function Rot13ToString(someText:String):String;
Var
 I:Integer;
 Ch:Char;
 R:String;
Begin
 R:='';
 For I:=1 to Length(someText) do Begin
  Ch:=SomeText[i];
  Case ch of
   'A'..'M','a'..'m':Ch:=Chr(Ord(Ch)+13);
   'N'..'Z','n'..'z':Ch:=Chr(Ord(Ch)-13);
  End;
  R:=R+Ch;
 End;
 Rot13ToString:=R;
End;

Procedure DumpWord;
Var
 I:Integer;
 IsReservedWord,IsBuildinFunction:Boolean;
Begin
 IsReservedWord:=False;
 IsBuildinFunction:=False;
 If CurrWord<>''Then Begin
  For I:=1 to High(ReservedWord) do Begin
   If StrToUpper(ReservedWord[I])=StrToUpper(CurrWord)Then Begin
    IsReservedWord:=True;
    Break;
   End;
  End;
   For I:=1 to High(BuiltinFunction) do Begin
   If StrToUpper(BuiltinFunction[I])=StrToUpper(CurrWord)Then Begin
    IsBuildinFunction:=True;
    Break;
   End;
  End;
  If IsBuildinFunction Then Write(CurrWord) Else
  If IsReservedWord Then Write(CurrWord)
                    Else Write(Rot13ToString(CurrWord));
  CurrWord:='';
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('ROT13PAS : Cette commande permet d''obscurcir le code ',
                      'Pascal en le transformant avec l''algorithme ',
                      'rot13 sur les identificateurs du programme.');
  WriteLn;
  WriteLn('Syntaxe : ROT13PAS nomdufichier.pas');
  WriteLn;
  WriteLn(' nomdufichier.pas  Nom du fichier de code source Pascal.');
 End
  Else
 If ParamCount>0 Then Begin
  For I:=1 to ParamCount do Begin
   {$I-}Assign(FileSource,ParamStr(I));
   Reset(FileSource);{$I+}
   If IoResult=0Then Begin
    InString:=False;
    InComment:=False;
    CurrWord:='';
    While Not EOF(FileSource)do Begin
     While Not Eoln(FileSource) do Begin
      Read(FileSource,Ch);
      If(Ch = '''')and(Not InComment)Then Begin
       InString:=Not InString;
      End;
      If(Ch = '{')and(Not InString)Then Begin
       InComment:=True;
      End;
      If(Ch = '}')and(Not InString)Then Begin
       InComment:=False;
      End;
      If Not(InString)and Not(InComment)Then Begin
       If Ch in['A'..'Z','a'..'z']Then Begin
        CurrWord:=CurrWord+Ch;
       End
        Else
       Begin
        DumpWord;
        Write(Ch);
       End;
      End
       else
      Begin
       DumpWord;
       Write(Ch);
      End;
     End;
     DumpWord;
     WriteLn;
     Readln(FileSource);
    End;
    Close(FileSource);
   End
    Else
   WriteLn('Erreur de lecture du fichier : ',ParamStr(I));
  End;
 End;
END.
