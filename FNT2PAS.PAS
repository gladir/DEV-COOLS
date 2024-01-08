{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program FNT2PAS;

Uses DOS;

Var
 Source:File;
 Target:Text;
 FontName:String;
 Tampon:Array[0..0]of Byte;
 ByteReaded:Integer;
 Position:Byte;
 CurrChar,HeightChar:LongInt;

Function Path2Name(S:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(S,D,N,E);
 Path2Name:=N;
End;

Function ByteHex2Str(value:Byte):String;
Const
 matrix:Array[0..15]of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Begin
 ByteHex2Str:=matrix[(value shr 4) and $0F]+matrix[value and $F];
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('FNT2PAS : Cette commande permet de convertir un fichier de police de caractäres en tableau de Pascal.');
  WriteLn;
  WriteLn('Syntaxe : FNT2PAS source.fnt destination.pas');
  WriteLn;
  WriteLn(' source.fnt       Nom du fichier de la police de caractäres');
  WriteLn(' destination.pas  Nom du fichier Pascal');
 End
  Else
 If ParamCount=2Then Begin
  FontName:='';
  {$I-}Assign(Source,ParamStr(1));
  Reset(Source,1);{$I+}
  If IOResult<>0 Then Begin
   WriteLn('Impossible de lire le fichier : ',ParamStr(1));
   Halt(1);
  End;
  FontName:=Path2Name(ParamStr(1));
  {$I-}Assign(Target,ParamStr(2));
  Rewrite(Target);{$I+}
  If IOResult<>0 Then Begin
   WriteLn('Impossible de crÇer le fichier : ',ParamStr(2));
   Halt(2);
  End;
  Position:=0;
  CurrChar:=0;
  HeightChar:=FileSize(Source) shr 8;
  WriteLn(Target,'Const Font',FontName,':Array[0..',FileSize(Source)-1,'] of Byte=(');
  Write(Target,'  ');
  While Not EOF(Source)do Begin
   BlockRead(Source,Tampon,1,ByteReaded);
   Write(Target,'$',ByteHex2Str(Tampon[0]));
   If Not EOF(Source)Then Begin
    Write(Target,', ');
    Inc(Position);
    If Position=HeightChar Then BEgin
     Write(Target);
     If Char(CurrChar)in[#33..#126]Then Write(Target,' { ''',Char(CurrChar),''' }')
                                   Else Write(Target,' { #',CurrChar,' }');
     Inc(CurrChar);
     WriteLn(Target);
     Write(Target,'  ');
    End;
    Position:=Position mod HeightChar;
   End;
  End;
  WriteLn(Target,'   { #255 }');
  WriteLn(Target,');');
  Close(Target);
  Close(Source);
 End
  Else
 WriteLn('Parametre invalide !');
END.
