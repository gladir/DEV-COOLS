{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program QPUINFO;

Uses DOS;

Const
 QPUSignMicrosoft='MSQP';    { Signature normal, celle de Microsoft}

Type
 QPUHeader=Record
  Sign:Array[0..3]of Char;   { Signature de l'unit� Microsoft QuickPascal: �MSQP�}
  Data1:Array[4..9]of Byte;  { R�serv�s pour un usage inconnue }
  NmUses:Word;               { Nombre d'unit� r�f�renc� par cette unit�: �Uses ...,...�}
  OffsetCodeSource:Word;     { D�placement vers la liste des fichiers sources }
  Data2:Array[14..23]of Byte;{ R�serv�s pour un usage inconnue }
  SizeIncludeFiles:Word;     { Taille des fichiers inclue lors de la compilation}
  Data3:Array[26..34]of Byte;{ R�serv�s pour un usage inconnue }
  UnitName:String[8];        { Nom de l'unit�: �Unit ...�}
 End;

 QPUUses=Record
  Data:Array[0..2]of Byte;   { Donn�e inconnue }
  Name:String[8];            { Nom de l'unit� de l'ensemble �Uses ...�}
 End;

Var
 FileSrc:File;
 Header:QPUHeader;
 XUses:QPUUses;
 I,ByteReaded:Word;

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
  WriteLn('QPUINFO : Cette commande permet d''afficher les ',
                   'informations sommaires d''un unit� QPU de Quick Pascal.');
  WriteLn;
  WriteLn('Syntaxe : QPUINFO [/?]');
  WriteLn('          QPUINFO filename');
  WriteLn;
  WriteLn('/?        Ce param�tre permet d''afficher l''aide sur cette commande.');
  WriteLn('filename  Ce param�tre permet d''indiquer le fichier � analyser.');
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
   WriteLn('Erreur d''ent�te de fichier!');
   Halt(1);
  End;
  WriteLn('Nom de l''unit� : ',Header.UnitName);
  WriteLn('Type de fichier : QPU');
  WriteLn('Version : 1.0');
  WriteLn('Nombre de d�pendances ',Header.NmUses);
  WriteLn('Taille des fichiers inclue : ',Header.SizeIncludeFiles);
  WriteLn('D�placement de la liste des sources : ',Header.OffsetCodeSource);
  Close(FileSrc)
 End;
END.
