{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program HEXCOM;
Type
 Blocks=Array[1..128] of Char;
 S2=string[2] ;

Var
 I:Byte;
 ComName,HexName:String;
 FN:String;
 REC:String;
 AByte:Byte;
 AFile:File of Byte;
 BFile:Text;
 Count,RCount:Integer;

Function HexNum(Char1,Char2:Char):Byte;
Var
 Hi,Low:Byte;
 TempByte:Byte;
Begin
 Hi:=Ord(Char1);
 Low:=Ord(Char2);
 If Hi>$40 Then Hi:=Byte(Hi+9);
 Hi:=Byte(Hi shl 4);
 If Low>$40 Then Low:=Byte(Low+9);
 Low:=Low and $0F;
 HexNum:=Byte(Hi+Low);
End;

BEGIN
If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('HEXCOM : Cette commande permet de charger un HEX (fichier ',
                    'de vidage hexad‚cimal) et en fait un fichier de format .COM.');
  WriteLn;
  WriteLn('Syntaxe : HEXCOM [/?] nomdufichier.HEX');
  WriteLn;
  WriteLn('nomdufichier  Nom du fichier sans extension');
  Halt;
 End
  Else
 If ParamCount>=1 Then Begin
  FN:=ParamStr(1);
 End
  Else
 Begin
  WriteLn('Entrez le nom du fichier HEX … charger dans le fichier COM');
  Readln(FN);
 End;
 ComName:=FN+'.COM' ;
 HexName:=FN+'.HEX' ;
 {$I-}Assign(Bfile,HexName);
 Reset(Bfile);{$I+}
 If IoResult<>0 Then Begin
  WriteLn('Fichier hexad‚cimal ',HexName,' introuvable !');
  Halt;
 End;
 {$I-}Assign(Afile,ComName);
 Rewrite(Afile);{$I+}
 IF IoResult<>0 Then Begin
  WriteLn('Impossible de cr‚er le fichier COM ',ComName,' !');
 End;
 Count:=0;
 Rcount:=0;
 Writeln('Conversion du fichier : ',HexName,' taille du fichier =',FileSize(Afile));
 Write(' Enregistrement de 64 octets produit 32 octets.  Compteur d''enregistrement = ');
 While Not Eof(Bfile) Do Begin
  ReadLn(Bfile,Rec);
  WriteLn('Enregistrement=',Rec);
  I:=1;
  While i<Length(Rec)do Begin
   While(Rec[I]in[' ',#9,',','$'])and(I<Length(Rec))do Inc(I); { Saute les espaces et les tabulations s'il existe }
   If I>=Length(Rec)Then Break;
   AByte:=HexNum(Rec[I],Rec[I+1]);
   Inc(I,2);
   Write(AFile,AByte);
   Count:=Count+1;
  End;
  Rcount:=Rcount+1;
  Write(RCount,'  ');
 End;
 Close(Afile) ;
 Writeln('Nombre d''enregistrement de 64 octets lue =',Rcount +1);
 Writeln('Nouveau fichier ',ComName,' cr‚‚.  La taille du fichier est ',count);
END.