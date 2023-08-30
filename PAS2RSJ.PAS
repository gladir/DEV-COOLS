{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PAS2RSJ(Input,Output);

Uses DOS;

Var
 SourcePAS,TargetRSJ:Text;
 CurrName,CurrLine,CurrWord,CurrValue:String;
 I:Integer;
 RV:String;
 First:Boolean;

Function TrimL(S:String):String;
Var
 I:Byte;
Begin
 For I:=1to Length(S)do Begin
  If S[I]<>' 'Then Begin
   TrimL:=Copy(S,I,255);
   Exit;
  End;
 End;
 TrimL:=S;
End;

Function TrimR(s:String):String;
Var
 i:Integer;
Begin
 i:=Length(s);
 While (i>0)and(s[i]in[#9,' '])do Dec(i);
 s[0]:=Chr(i);
 TrimR:=S;
End;

Function Trim(s:String):String;Begin
 Trim:=TrimL(TrimR(s));
End;

Function Path2Name(S:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(S,D,N,E);
 Path2Name:=N;
End;

Function Hash(S:String):LongInt;
Var
 TheHash,G,I:LongInt;
Begin
 thehash:=0;
 For I:=1 to Length(S)do Begin
  TheHash:=TheHash shl 4;
  Inc(TheHash,Ord(S[i]));
  G:=TheHash and LongInt($f shl 28);
  If g<>0 Then Begin
   TheHash:=TheHash xor (g shr 24);
   TheHash:=TheHash xor g;
  End;
 End;
 If TheHash=0 Then Hash:=LongInt($ffffffff)
              Else Hash:=TheHash;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PAS2RSJ : Cette commande permet de convertir des constantes ',
                     ' Pascal en fichier de ressource RSJ.');
  WriteLn;
  WriteLn('Syntaxe : PAS2RSJ nomdufichier.PAS nomdufichier.RSJ');
 End
  Else
 If ParamCount>0Then Begin
  {$I-}Assign(SourcePAS,ParamStr(1));
  Reset(SourcePAS);{$I+}
  If IoResult<>0Then Begin
   WriteLn('Fichier Pascal introuvable !');
   Halt;
  End;
  {$I+}Assign(TargetRSJ,ParamStr(2));
  Rewrite(TargetRSJ); {$I+}
  If IoResult<>0Then Begin
   WriteLn('Impossible de cr‚er le fichier RSJ !');
   Close(SourcePAS);
   Halt;
  End;
  CurrName:=Path2Name(ParamStr(1));
  First:=True;
  WriteLn(TargetRSJ,'{ "version: 1,');
  WriteLn(TargetRSJ,'  "strings":[');
  While Not EOF(SourcePAS)do Begin
   ReadLn(SourcePAS,CurrLine);
   CurrLine:=Trim(CurrLine);
   If CurrLine<>''Then Begin
    CurrWord:='';CurrValue:='';
    I:=1;
    If CurrLine[I]in['A'..'Z','a'..'z','_']Then Begin
     CurrWord:=CurrWord+CurrLine[I];
     Inc(I);
     While (CurrLine[I]in['A'..'Z','a'..'z','_','0'..'9'])and(I<=Length(CurrLine))do Begin
      CurrWord:=CurrWord+CurrLine[I];
      Inc(I);
     End;
    End;
    While(CurrLine[I]in[' '])and(I<=Length(CurrLine))do Inc(I);
    If(CurrLine[I]='=')and(I<=Length(CurrLine))Then Begin
     Inc(I);
     While(CurrLine[I]in[' '])and(I<=Length(CurrLine))do Inc(I);
     If(CurrLine[I]='''')and(I<=Length(CurrLine))Then Begin
      Inc(I);
      While I<=Length(CurrLine)do Begin
       If(CurrLine[I]='''')and(CurrLine[I+1]='''')and
         (I+1<=Length(CurrLine))Then Begin
        CurrValue:=CurrValue+'''';
        Inc(I,2);
       End
        Else
       If(CurrLine[I]='''')Then Break
        Else
       Begin
        CurrValue:=CurrValue+CurrLine[I];
        Inc(I);
       End;
      End;
     End;
    End;
    If CurrWord<>''Then Begin
     If(First)Then First:=False
              Else WriteLn(TargetRSJ,'   ,');
     WriteLn(TargetRSJ,'   {"hash":',Hash(CurrWord),',');
     WriteLn(TargetRSJ,'    "name":"',CurrName,'.',CurrWord,'",');
     Write(TargetRSJ,'    "sourcebytes":[');
     For I:=1 to Length(CurrValue)do Begin
      Str(Byte(CurrValue[I]),RV);
      Write(TargetRSJ,RV);
      If I<Length(CurrValue)Then Write(TargetRSJ,',');
     End;
     WriteLn(TargetRSJ,'],');
     WriteLn(TargetRSJ,'    "value":"',CurrValue,'",');
     WriteLn(TargetRSJ,'   }');
    End;
   End;
  End;
  WriteLn(TargetRSJ,'  ]');
  WriteLn(TargetRSJ,'}');
  Close(TargetRSJ);
  Close(SourcePAS);
 End
  Else
 WriteLn('ParamŠtre requis !');
END.