{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program BINLINE;

Uses DOS;

Var
 Source:File;
 Target:Text;
 Tampon:Array[0..0]of Byte;
 ByteReaded:Integer;
 Position:Byte;
 DriverName:String;

Function ByteHex2Str(value:Byte):String;
Const
 matrix:Array[0..15]of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Begin
 ByteHex2Str:=matrix[(value shr 4) and $0F]+matrix[value and $F];
End;

Function Path2Name(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2Name:=N;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BINLINE : Cette commande permet de convertir un fichier BIN ',
                      'en code source Pascal Inline.');
  WriteLn;
  WriteLn('Syntaxe : BINLINE fichier.bin fichier.pas');
 End
  Else
 If ParamCount=2Then Begin
  Assign(Source,ParamStr(1));
  Reset(Source,1);
  Assign(Target,ParamStr(2));
  Rewrite(Target);
  Position:=0;
  DriverName:=Path2Name(ParamStr(1));
  WriteLn(Target,'Procedure ',DriverName,';Inline(');
  Write(Target,'  ');
  While Not EOF(Source)do Begin
   BlockRead(Source,Tampon,1,ByteReaded);
   Write(Target,'$',ByteHex2Str(Tampon[0]));
   If Not EOF(Source)Then Begin
    Write(Target,'/');
    Inc(Position);
    If Position=18Then BEgin
     WriteLn(Target);
     Write(Target,'  ');
    End;
    Position:=(Position+1)mod 19;
   End;
  End;
  WriteLn(Target);
  WriteLn(Target,');');
  Close(Target);
  Close(Source);
 End
  Else
 WriteLn('Parametre invalide !');
END.
