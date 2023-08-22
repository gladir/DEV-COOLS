{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
}

Program BUGFIND;

Uses DOS;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain);
 NumberFiles,NumberFilesScanned,NumberError:LongInt;
 I:Byte;
 SubDirectory:Boolean;
 TmpLanguage:String;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function Path2Ext(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2Ext:=E;
End;

Function Path2Dir(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 Path2Dir:='';
 If Path=''Then Exit;
 FSplit(Path,D,N,E);
 If E=''Then Begin
  If D[Length(D)]<>'\'Then D:=D+'\';
  D:=D+E;
 End;
 If D=''Then Path2Dir:='' Else
 If D[Length(D)]<>'\'Then D:=D+'\';
 Path2Dir:=D;
End;

Function SetPath4AddFile(Path:String):String;Begin
 If Path=''Then GetDir(0,Path);
 If Path[Length(Path)]<>'\'Then Path:=Path+'\';
 SetPath4AddFile:=Path;
End;

Procedure ScanHTMLFile(FileName:String);
Var
 FileHTML:Text;
 LineNumber:LongInt;
 CurrLine:String;
Begin
  LineNumber:=0;
  {$I-}Assign(FileHTML,FileName);
  Reset(FileHTML);{$I+}
  If IoResult=0Then Begin
   NumberFilesScanned:=NumberFilesScanned+1;
   While Not EOF(FileHTML)do Begin
    ReadLn(FileHTML,CurrLine);
    Inc(LineNumber);
    If Pos('&NBPS;',StrToUpper(CurrLine))>0 Then Begin
     WriteLn(FileName,'[',LineNumber,']');
     WriteLn('Erreur : &nbps; plut“t que &nbsp;');
     WriteLn('Ligne suspect :',CurrLine);
     WriteLn;
     NumberError:=NumberError+1;
    End;
   End;
   Close(FileHTML);
  End;
End;

Procedure ScanSubdirectoryFiles(FileSpec:String);
Var
 Info:SearchRec;
 CurrFile:File;
 Found:Boolean;
Begin
 FileSpec:=FExpand(FileSpec);
 FindFirst(FileSpec,AnyFile,Info);
 Found:=False;
 While DOSError=0 do Begin
  Found:=True;
  If Info.Attr and Directory=Directory Then Begin
   If(SubDirectory)Then Begin
    If Not((Info.Name='.')or(Info.Name='..')or(Info.Name=''))Then Begin
     ScanSubdirectoryFiles(SetPath4AddFile(Path2Dir(FileSpec)+Info.Name)+'*.*');
    End;
   End;
  End
   Else
  Begin
   If StrToUpper(Path2Ext(Info.Name))='.HTM'Then ScanHTMLFile(Path2Dir(FileSpec)+Info.Name);
   NumberFiles:=NumberFiles+1;
  End;
  FindNext(Info);
 End;
End;

Procedure ScanCurrentDirectory;
Var
 Info:SearchRec;
Begin
 FindFirst('*.*',AnyFile and Not Directory,Info);
 While DOSError=0 do Begin
  If StrToUpper(Path2Ext(Info.Name))='.HTM'Then ScanHTMLFile(Info.Name);
  NumberFiles:=NumberFiles+1;
  FindNext(Info);
 End;
End;

BEGIN
 NumberFiles:=0;
 NumberFilesScanned:=0;
 NumberError:=0;
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain;
 End;
 If ParamStr(1)='/?'Then Begin
  WriteLn('BUGFINDER - Cette commande permet de rechercher des anomalies dans des fichiers');
  WriteLn;
  WriteLn('Syntaxe : BUGFIND nomdufichier [/S]');
  WriteLn;
  WriteLn(' /S   Applique le changement dans les sous-repertoires recursivement');
 End
  Else
 If ParamCount=0Then ScanCurrentDirectory
  Else
 If ParamCount>0Then Begin
  SubDirectory:=False;
  For I:=1to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/S'Then Begin
    SubDirectory:=True;
   End;
  End;
  For I:=1to ParamCount do Begin
   ScanSubdirectoryFiles(ParamStr(I));
   If I=255Then Exit;
  End;
 End;
 If NumberError>0 Then Begin
  WriteLn('------------------------------------');
  WriteLn('Nombre de fichiers : ',NumberFiles);
  WriteLn('Nombre de fichiers analys‚s : ',NumberFilesScanned);
  WriteLn('Nombre d''erreur(s) trouv‚(s) : ',NumberError);
  WriteLn;
 End;
END.
