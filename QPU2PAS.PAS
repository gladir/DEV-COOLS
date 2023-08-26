{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program QPU2PAS;

Uses DOS;

Const
 QPUSignMicrosoft='MSQP';    { Signature normal, celle de Microsoft}

Type
 QPUHeader=Record
  Sign:Array[0..3]of Char;   { Signature de l'unit‚ Microsoft QuickPascal: ®MSQP¯}
  Data1:Array[4..9]of Byte;  { R‚serv‚s pour un usage inconnue }
  NmUses:Word;               { Nombre d'unit‚ r‚f‚renc‚ par cette unit‚: ®Uses ...,...¯}
  OffsetCodeSource:Word;     { D‚placement vers la liste des fichiers sources }
  Data2:Array[14..23]of Byte;{ R‚serv‚s pour un usage inconnue }
  SizeIncludeFiles:Word;     { Taille des fichiers inclue lors de la compilation}
  Data3:Array[26..34]of Byte;{ R‚serv‚s pour un usage inconnue }
  UnitName:String[8];        { Nom de l'unit‚: ®Unit ...¯}
 End;

 QPUUses=Record
  Data:Array[0..2]of Byte;   { Donn‚e inconnue }
  Name:String[8];            { Nom de l'unit‚ de l'ensemble ®Uses ...¯}
 End;

Var
 FileSrc:File;
 FileTarget:Text;
 Header:QPUHeader;
 XUses:QPUUses;
 I,ByteReaded:Word;
 CharData:Char;
 SearchName:String;
 First:Boolean;

Function Path2NoExt(Const Path:String):String;
 Var
  D:DirStr;
  N:NameStr;
  E:ExtStr;
 Begin
 FSplit(Path,D,N,E);
 Path2NoExt:=D+N;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('QPU2PAS : Cette commande permet de convertir un fichier .QPU de  ',
                   'Quick Pascal en code source Pascal.');
  WriteLn;
  WriteLn('Syntaxe : QPU2PAS [/?]');
  WriteLn('          QPU2PAS filename');
  WriteLn;
  WriteLn('/?        Ce paramŠtre permet d''afficher l''aide sur cette comamnde.');
  WriteLn('filename  Ce paramŠtre permet d''indiquer le fichier … analyser.');
 End
  Else
 If ParamCount>0 Then Begin
  {$I-}Assign(FileSrc,ParamStr(1));
  Reset(FileSrc,1);{$I-}
  If(IoResult<>0)Then Begin
   WriteLn('Fichier introuvable!');
   Halt(1);
  End;
  Seek(FileSrc,0);
  BlockRead(FileSrc,Header,SizeOf(Header),ByteReaded);
  If(Header.Sign<>QPUSignMicrosoft)Then Begin
   WriteLn('Erreur d''entˆte de fichier!');
   Halt(1);
  End;
  {$I-}Assign(FileTarget,Path2NoExt(ParamStr(1))+'.PAS');
  Rewrite(FileTarget);{$I+}
  If(IoResult<>0)Then Begin
   WriteLn('Erreur de cr‚ation de fichier!');
   Halt(1);
  End;
  WriteLn(FileTarget,'Unit '+Header.UnitName+';');
  WriteLn(FileTarget);
  WriteLn(FileTarget,'INTERFACE');
  WriteLn(FileTarget);
  Write(FileTarget,'Uses ');
  For I:=1to(Header.NmUses)do Begin
   BlockRead(FileSrc,XUses,SizeOf(XUses),ByteReaded);
   Write(FileTarget,XUses.Name);
   If(I<Header.NmUses)Then Write(FileTarget,',')
  End;
  WriteLn(FileTarget,';');
  WriteLn(FileTarget);
  WriteLn(FileTarget,'IMPLEMENTATION');
  WriteLn(FileTarget);
  Seek(FileSrc,Header.OffsetCodeSource);
  SearchName:='';
  First:=True;
  Repeat
   BlockRead(FileSrc,CharData,1,ByteReaded);
   If CharData=#0 Then Begin
    If SearchName=''Then Break;
    If(First)Then First:=False
             Else WriteLn(FileTarget,'{$L ',SearchName,'}');
    SearchName:='';
   End
    Else
   SearchName:=SearchName+CharData;
   If CharData>=#$80 Then Break;
  Until ByteReaded>1;
  WriteLn(FileTarget);
  WriteLn(FileTarget,'END.');
  Close(FileTarget);
  Close(FileSrc)
 End;
END.