{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2021
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
}

Program DIR;

Uses {$IFDEF FPC}{$IFDEF WINDOWS}Windows,{$ENDIF}{$ENDIF} Crt,DOS;

Type
 PDirEntry=^TDirEntry;
 TDirEntry=Record
  Data:SearchRec;
  Compression:Real;
  Next:PDirEntry;
 End;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain);
 TmpLanguage:String;
 First:Boolean;
 Error:Integer;
 P:Byte;
 Info:SearchRec;
 T:DateTime;
 Option:Set of (Pause,Subdirectory,Lower,Brief,Description);
 Column:Set Of (Double,Width);
 TotalNumFiles,TotalSize:LongInt;
 CurrParam,ShowDir,CurrLabel:String;
 CurrDrive:Char;
 OutputFormat:(_Text,_CSV,_HTML,_Json,_Pascal,_SQL,_XML);
 RequiredAttr,ExcludedAttr:Word;
 SortOrder:String;
 Entries,CurrentEntry:PDirEntry;
 EntriesLoaded:Boolean;

Function StrToUpper(S:String):String; Forward;

Function DisplayName:String;
Var
 S:String;
 I:Integer;
Begin
 S:=Info.Name;
 If Lower in Option Then
  For I:=1 to Length(S)do
   If S[I] in ['A'..'Z']Then S[I]:=Chr(Ord(S[I])+32);
 DisplayName:=S;
End;

Function ParseSortOrder(S:String):Boolean;
Var
 I:Integer;
Begin
 ParseSortOrder:=False;
 SortOrder:='';
 I:=3;
 If I<=Length(S)Then If S[I]=':'Then Inc(I);
 While I<=Length(S)do Begin
  If S[I] in ['+','-']Then Begin
   If S[I]='-'Then SortOrder:=SortOrder+'-';
   Inc(I);
   If I>Length(S)Then Exit;
  End;
  If Not(UpCase(S[I]) in ['C','D','E','G','N','S'])Then Exit;
  SortOrder:=SortOrder+UpCase(S[I]);
  Inc(I);
 End;
 If SortOrder=''Then SortOrder:='GN';
 ParseSortOrder:=True;
End;

Function FileExtension(S:String):String;
Var
 I:Integer;
Begin
 I:=Length(S);
 While I>0do Begin
  If S[I]='.'Then Begin
   FileExtension:=Copy(S,I+1,255);
   Exit;
  End;
  Dec(I);
 End;
 FileExtension:='';
End;

Function CompareEntries(A,B:PDirEntry):Integer;
Var
 I,Direction,Cmp:Integer;
 SA,SB:String;
 VA,VB:Real;
Begin
 I:=1;
 CompareEntries:=0;
 While I<=Length(SortOrder)do Begin
  Direction:=1;
  If SortOrder[I]='-'Then Begin
   Direction:=-1;
   Inc(I);
  End;
  Cmp:=0;
  If SortOrder[I] in ['N','E']Then Begin
   SA:=StrToUpper(A^.Data.Name);
   SB:=StrToUpper(B^.Data.Name);
   If SortOrder[I]='E'Then Begin
    SA:=FileExtension(SA);
    SB:=FileExtension(SB);
   End;
   If SA<SB Then Cmp:=-1 Else If SA>SB Then Cmp:=1;
  End Else Begin
   VA:=0;
   VB:=0;
   Case SortOrder[I] of
    'C':Begin VA:=A^.Compression; VB:=B^.Compression; End;
    'D':Begin
     { Compare packed DOS timestamps as unsigned values, including years >= 2044. }
     VA:=A^.Data.Time;
     VB:=B^.Data.Time;
     If VA<0Then VA:=VA+4294967296.0;
     If VB<0Then VB:=VB+4294967296.0;
    End;
    'G':Begin
     VA:=-Ord((A^.Data.Attr and Directory)<>0);
     VB:=-Ord((B^.Data.Attr and Directory)<>0);
    End;
    'S':Begin VA:=A^.Data.Size; VB:=B^.Data.Size; End;
   End;
   If VA<VB Then Cmp:=-1 Else If VA>VB Then Cmp:=1;
  End;
  If Cmp<>0Then Begin
   CompareEntries:=Cmp*Direction;
   Exit;
  End;
  Inc(I);
 End;
End;

{ Stable merge sort: equal keys retain enumeration order. }
Function SortEntries(Head:PDirEntry):PDirEntry;
Var
 Slow,Fast,Left,Right,Tail,Sorted,Chosen:PDirEntry;
Begin
 SortEntries:=Head;
 If Head=Nil Then Exit;
 If Head^.Next=Nil Then Exit;
 Slow:=Head;
 Fast:=Head^.Next;
 While Fast<>Nil do Begin
  Fast:=Fast^.Next;
  If Fast<>Nil Then Begin
   Slow:=Slow^.Next;
   Fast:=Fast^.Next;
  End;
 End;
 Right:=Slow^.Next;
 Slow^.Next:=Nil;
 Left:=SortEntries(Head);
 Right:=SortEntries(Right);
 Sorted:=Nil;
 Tail:=Nil;
 While (Left<>Nil)and(Right<>Nil)do Begin
  If CompareEntries(Left,Right)<=0Then Begin
   Chosen:=Left;
   Left:=Left^.Next;
  End Else Begin
   Chosen:=Right;
   Right:=Right^.Next;
  End;
  If Tail=Nil Then Sorted:=Chosen Else Tail^.Next:=Chosen;
  Tail:=Chosen;
 End;
 If Left=Nil Then Left:=Right;
 If Tail=Nil Then Sorted:=Left Else Tail^.Next:=Left;
 SortEntries:=Sorted;
End;

Function CompressionRate:Real;
{$IFDEF FPC}{$IFDEF WINDOWS}
Var
 Path:AnsiString;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
 LowSize,HighSize:DWORD;
 StoredSize:Real;
{$ENDIF}{$ENDIF}
Begin
 { Percentage of bytes saved; unavailable values and empty files use zero. }
 CompressionRate:=0;
{$IFDEF FPC}{$IFDEF WINDOWS}
 If (Info.Size<=0)or((Info.Attr and Directory)<>0)Then Exit;
 FSplit(FExpand(ShowDir),D,N,E);
 Path:=D+Info.Name;
 Windows.SetLastError(0);
 LowSize:=Windows.GetCompressedFileSizeA(PChar(Path),@HighSize);
 If (LowSize=DWORD($FFFFFFFF))and(Windows.GetLastError<>0)Then Exit;
 StoredSize:=HighSize*4294967296.0+LowSize;
 If StoredSize<Info.Size Then
  CompressionRate:=100.0*(1.0-StoredSize/Info.Size);
{$ENDIF}{$ENDIF}
End;

Procedure FreeEntries;
Var
 NextEntry:PDirEntry;
Begin
 While Entries<>Nil do Begin
  NextEntry:=Entries^.Next;
  Dispose(Entries);
  Entries:=NextEntry;
 End;
End;

{ Each sign applies to the following attribute; unsigned attributes are required. }
Function ParseAttributes(S:String):Boolean;
Var
 I:Integer;
 Mask:Word;
 ExcludeAttr:Boolean;
Begin
 ParseAttributes:=False;
 RequiredAttr:=0;
 ExcludedAttr:=0;
 I:=3;
 If I<=Length(S)Then If S[I]=':'Then Inc(I);
 While I<=Length(S)do Begin
  ExcludeAttr:=False;
  If S[I] in ['+','-']Then Begin
   ExcludeAttr:=S[I]='-';
   Inc(I);
   If I>Length(S)Then Exit;
  End;
  Case UpCase(S[I]) of
   'A':Mask:=Archive;
   'D':Mask:=Directory;
   'H':Mask:=Hidden;
   'R':Mask:=ReadOnly;
   'S':Mask:=SysFile;
   Else Exit;
  End;
  If ExcludeAttr Then ExcludedAttr:=ExcludedAttr or Mask
                 Else RequiredAttr:=RequiredAttr or Mask;
  Inc(I);
 End;
 ParseAttributes:=True;
End;

Procedure SkipExcluded;
Begin
 While DosError=0do Begin
  If ((Info.Attr and RequiredAttr)=RequiredAttr)and
     ((Info.Attr and ExcludedAttr)=0)Then Exit;
  FindNext(Info);
 End;
End;

Procedure FindFirstMatch;
Var
 Entry,Tail:PDirEntry;
Begin
 If SortOrder<>''Then Begin
  If Not EntriesLoaded Then Begin
   Tail:=Nil;
   FindFirst(ShowDir,AnyFile,Info);
   SkipExcluded;
   While DosError=0do Begin
    {$IFNDEF FPC}
    If MaxAvail<SizeOf(TDirEntry)Then Begin
     FreeEntries;
     Case Language of
      _Germany:WriteLn('Nicht genug Speicher zum Sortieren.');
      _English:WriteLn('Not enough memory to sort.');
      Else WriteLn('M'+#130+'moire insuffisante pour le tri.');
     End;
     Halt(1);
    End;
    {$ENDIF}
    New(Entry);
    Entry^.Data:=Info;
    Entry^.Compression:=0;
    If Pos('C',SortOrder)>0Then Entry^.Compression:=CompressionRate;
    Entry^.Next:=Nil;
    If Tail=Nil Then Entries:=Entry Else Tail^.Next:=Entry;
    Tail:=Entry;
    FindNext(Info);
    SkipExcluded;
   End;
   {$IFDEF FPC}FindClose(Info);{$ENDIF}
   Entries:=SortEntries(Entries);
   EntriesLoaded:=True;
  End;
  CurrentEntry:=Entries;
  If CurrentEntry=Nil Then DosError:=18 Else Begin
   Info:=CurrentEntry^.Data;
   DosError:=0;
  End;
  Exit;
 End;
 FindFirst(ShowDir,AnyFile,Info);
 SkipExcluded;
End;

Procedure FindNextMatch;
Begin
 If SortOrder<>''Then Begin
  If CurrentEntry<>Nil Then CurrentEntry:=CurrentEntry^.Next;
  If CurrentEntry=Nil Then DosError:=18 Else Begin
   Info:=CurrentEntry^.Data;
   DosError:=0;
  End;
  Exit;
 End;
 FindNext(Info);
 SkipExcluded;
End;

Function PadRight(S:String;Space:Byte):String;
Var
 I:Byte;
Begin
 If Length(S)<Space Then For I:=Length(S)+1 to Space do S:=S+' ';
 PadRight:=S;
End;

Function PadZeroLeft(Value:Integer;Space:Byte):String;
Var
 S:String;
Begin
 Str(Value,S);
 While Length(S)<Space do S:='0'+S;
 PadZeroLeft:=S;
End;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function Path2Drive(Path:String):Char;Begin
 Path:=FExpand(Path);
 Path2Drive:=Path[1];
End;

Function GetDiskLabel(Dsk:Byte):String;
Var
 Info:SearchRec;
 CurrentDir:String;
Begin
 If Dsk=0Then GetDir(0,CurrentDir)
         Else CurrentDir:=Char(Dsk+64);
 FindFirst(CurrentDir[1]+':\*.*',VolumeID,Info);
 While DosError=0do Begin
  If(Info.Attr = VolumeID)Then Begin
   GetDiskLabel:=Info.Name;
   Exit;
  End;
  FindNext(Info);
 End;
 GetDiskLabel:=''
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain;
 End;
 Option:=[];
 Column:=[];
 RequiredAttr:=0;
 ExcludedAttr:=0;
 P:=0;
 SortOrder:='';
 Entries:=Nil;
 CurrentEntry:=Nil;
 EntriesLoaded:=False;
 ShowDir:='*.*';
 OutputFormat:=_Text;
 Repeat
  Inc(P);
  CurrParam:=ParamStr(P);
 If Length(CurrParam)=0Then Break;
  If CurrParam='/?'Then Begin
  Case Language of
    _Germany:Begin
     WriteLn('Listet die Dateien und Unterverzeichnisse eines Verzeichnisses auf.');
     WriteLn;
     WriteLn('Format:   DIR [/?] [/2|/W] [/B] [/L] [/P] [/A[[:]Attribute]] [/O[[:]Folge]] [Pfad] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /A[[:]Attribute]  A=Archiv D=Verzeichnis H=Versteckt R=Schreibgesch'+#129+'tzt S=System');
     WriteLn('                  + : einschlie'+#225+'en; - : ausschlie'+#225+'en');
     WriteLn('                  /A : alle; /A:H-D : versteckte Dateien ohne Verzeichnisse');
     WriteLn(' /L               Datei- und Verzeichnisnamen in Kleinbuchstaben anzeigen');
     WriteLn(' /O[[:]Folge]     C=Kompressionsrate D=Datum/Zeit E=Erweiterung');
     WriteLn('                  G=Verzeichnisse zuerst N=Name S=Gr'+#148+'sse');
     WriteLn('                  Aufsteigend; - kehrt den folgenden Schl'+#129+'ssel um');
     WriteLn('                  /O = GN; mehrere Schl'+#129+'ssel, z.B. /O:G-S');
     WriteLn('                  C: eingesparte Bytes (%), Windows; sonst 0');
    End;
    _English:Begin
     WriteLn('Purpose:  Display information about files and subdirectories.');
     WriteLn;
     WriteLn('Format:   DIR [/?] [/2|/W] [/B] [/L] [/P] [/A[[:]attributes]] [/O[[:]order]] [path] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /A[[:]attributes] A=Archive D=Directory H=Hidden R=ReadOnly S=System');
     WriteLn('                  + : include; - : exclude');
     WriteLn('                  /A : all; /A:H-D : hidden files without directories');
     WriteLn(' /L               Display file and directory names in lowercase');
     WriteLn(' /O[[:]order]     C=Compression rate D=Date/time E=Extension');
     WriteLn('                  G=Directories first N=Name S=Size');
     WriteLn('                  Ascending; - reverses the following key');
     WriteLn('                  /O = GN; combine keys, e.g. /O:G-S');
     WriteLn('                  C: bytes saved (%), Windows; otherwise 0');
    End;
    Else Begin
     WriteLn('DIR   Cette commande permet d''afficher le contenu d''un r'+#130+'pertoire dans l''unite de disque.');
     WriteLn;
     WriteLn('Syntaxe:');
     WriteLn;
     WriteLn('DIR [/?] [/2|/W] [/B] [/L] [/P] [/A[[:]attributs]] [/O[[:]ordretri]] [chemin] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /?             Ce param'+#138+'tre permet d''afficher l''aide sur cette commande');
     WriteLn(' /2             Ce param'+#138+'tre permet d''afficher sur 2 colonnes');
     WriteLn(' /A[[:]attributs]  A=Archive D=R'+#130+'pertoire H=Cach'+#130+' R=Lecture seule S=Syst'+#138+'me');
     WriteLn('                  + : inclure; - : exclure');
     WriteLn('                  /A : tous; /A:H-D : fichiers cach'+#130+'s sans les r'+#130+'pertoires');
     WriteLn(' /B             Ce param'+#138+'tre enl'+#138+'ve l''entete et les d'+#130+'tails de la fin');
     WriteLn(' /L               Affiche les noms des fichiers et r'+#130+'pertoires en minuscules');
     WriteLn(' /O[[:]ordretri]  C=Taux de compression D=Date/heure E=Extension');
     WriteLn('                  G=R'+#130+'pertoires en premier N=Nom S=Taille');
     WriteLn('                  Ordre croissant; - inverse le crit'+#138+'re suivant');
     WriteLn('                  /O = GN; crit'+#138+'res combinables, ex. /O:G-S');
     WriteLn('                  C : octets '+#130+'conomis'+#130+'s (%), Windows; sinon 0');
     WriteLn(' /P             Ce param'+#138+'tre affiche une pause apres l''affichage d''une page pleine');
     WriteLn(' /W             Ce param'+#138+'tre affiche seulement les fichiers sur plein de colonnes');
     WriteLn(' /FORMAT:format Ce param'+#138+'tre permet d''indiquer CSV, HTML, Json, PASCAL, SQL ou XML');
    End;
   End;
   Exit;
  End
   Else
  If CurrParam='/2'Then Include(Column,Double) Else
  If StrToUpper(Copy(CurrParam,1,2))='/O'Then Begin
   If Not ParseSortOrder(CurrParam)Then Begin
    Case Language of
     _Germany:WriteLn('Ung'+#129+'ltige Sortierreihenfolge: ',CurrParam);
     _English:WriteLn('Invalid sort order: ',CurrParam);
     Else WriteLn('Ordre de tri non valide : ',CurrParam);
    End;
    Halt(1);
   End;
  End Else
  If StrToUpper(Copy(CurrParam,1,2))='/A'Then Begin
   If Not ParseAttributes(CurrParam)Then Begin
    WriteLn('Invalid attribute parameter: ',CurrParam);
    Halt(1);
   End;
  End Else
  If(CurrParam='/B')or(CurrParam='/b')Then Include(Option,Brief) Else
  If(CurrParam='/L')or(CurrParam='/l')Then Include(Option,Lower) Else
  If(CurrParam='/P')or(CurrParam='/p')Then Include(Option,Pause) Else
  If(CurrParam='/W')or(CurrParam='/w')Then Include(Column,Width) Else
  If(StrToUpper(Copy(CurrParam,1,8))='/FORMAT:')Then Begin
   If StrToUpper(Copy(CurrParam,9,255))='CSV'Then OutputFormat:=_CSV Else
   If StrToUpper(Copy(CurrParam,9,255))='HTML'Then OutputFormat:=_HTML Else
   If StrToUpper(Copy(CurrParam,9,255))='JSON'Then OutputFormat:=_Json Else
   If StrToUpper(Copy(CurrParam,9,255))='PASCAL'Then OutputFormat:=_Pascal Else
   If StrToUpper(Copy(CurrParam,9,255))='SQL'Then OutputFormat:=_SQL Else
   If StrToUpper(Copy(CurrParam,9,255))='XML'Then OutputFormat:=_XML;
  End
   Else
  ShowDir:=CurrParam;
  If P>99Then Break;
 Until CurrParam='';
 CurrDrive:=Path2Drive(ShowDir);
 CurrLabel:=GetDiskLabel(Byte(CurrDrive)-64);
 P:=0;
 Case OutputFormat of
  _CSV:Begin
   FindFirstMatch;
   While DOSError=0 do Begin
    Write(DisplayName);
    If Not((Width)in(Column))Then Begin
     Write(',');
     If Info.Attr and Directory=Directory Then Begin
      Write('[directory]');
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      Write('[readonly]');
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      Write('[system]');
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      Write('[hidden]');
     End;
     If Info.Attr and Archive=Archive Then Begin
      Write('[archive]');
     End;
     Write(',');
     Write(Info.Size,',');
     UnpackTime(Info.Time,T);
     Write(T.Year:4,'-',PadZeroLeft(T.Month,2),'-',PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2));
    End;
    WriteLn;
    FindNextMatch;
   End;
  End;
  _HTML:Begin
   WriteLn('<!DOCTYPE html>');
   WriteLn('<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr" lang="fr">');
   WriteLn('<body>');
   WriteLn('<table>');
   WriteLn(' ':4,'<tr>');
   WriteLn(' ':8,'<th>FileName</th>');
   If Not((Width)in(Column))Then Begin
    WriteLn(' ':8,'<th>Attribut</th>');
    WriteLn(' ':8,'<th>Size</th>');
    WriteLn(' ':8,'<th>Time</th>');
   End;
   WriteLn(' ':4,'</tr>');
   FindFirstMatch;
   While DOSError=0 do Begin
    WriteLn(' ':4,'<tr>');
    WriteLn(' ':8,'<td>',DisplayName,'</td>');
    If Not((Width)in(Column))Then Begin
     Write(' ':8,'<td>');
     If Info.Attr and Directory=Directory Then Begin
      Write('[directory]');
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      Write('[readonly]');
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      Write('[system]');
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      Write('[hidden]');
     End;
     If Info.Attr and Archive=Archive Then Begin
      Write('[archive]');
     End;
     WriteLn('</td>');
     WriteLn(' ':8,'<td>',Info.Size,'</td>');
     UnpackTime(Info.Time,T);
     WriteLn(' ':8,'<td>',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',
             PadZeroLeft(T.Day,2),' ',T.Hour:2,':',
             PadZeroLeft(T.Min,2),'</td>');
    End;
    WriteLn(' ':4,'</tr>');
    FindNextMatch;
   End;
   WriteLn('</table>');
   WriteLn('</body>');
   WriteLn('</html>');
  End;
  _Json:Begin
   WriteLn('{');
   FindFirstMatch;
   Error:=DOSError;
   While Error=0 do Begin
    WriteLn(' ':4,'"file":{');
    WriteLn(' ':8,'"filename":"',DisplayName,'",');
    If Not((Width)in(Column))Then Begin
     Write(' ':8,'"attribut":"');
     If Info.Attr and Directory=Directory Then Begin
      Write('[directory]');
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      Write('[readonly]');
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      Write('[system]');
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      Write('[hidden]');
     End;
     If Info.Attr and Archive=Archive Then Begin
      Write('[archive]');
     End;
     WriteLn('",');
     WriteLn(' ':8,'"size":',Info.Size,',');
     UnpackTime(Info.Time,T);
     WriteLn(' ':8,'"time":"',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',
             PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2),'"');
    End;
    Write(' ':4,'}');
    FindNextMatch;
    Error:=DOSError;
    If Error=0 Then Write(',');
    WriteLn;
   End;
   WriteLn('}');
  End;
  _Pascal:Begin
   TotalNumFiles:=0;
   FindFirstMatch;
   While DOSError=0 do Begin
    FindNextMatch;
    Inc(TotalNumFiles);
   End;
   WriteLn('Var files:Array[1..',TotalNumFiles,'] of SearchRec=(');
   FindFirstMatch;
   Error:=DOSError;
   While Error=0 do Begin
    WriteLn(' ':7,'(Name:''',DisplayName,''';');
    If Not((Width)in(Column))Then Begin
     Write(' ':8,'Attr:');
     First:=True;
     If Info.Attr and Directory=Directory Then Begin
      Write('Directory');
      First:=False;
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      If Not(First)Then Write('+');
      Write('ReadOnly');
      First:=False;
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      If Not(First)Then Write('+');
      Write('SysFile');
      First:=False;
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      If Not(First)Then Write('+');
      Write('Hidden');
      First:=False;
     End;
     If Info.Attr and Archive=Archive Then Begin
      If Not(First)Then Write('+');
      Write('Archive');
     End;
     WriteLn(';');
     WriteLn(' ':8,'Size:',Info.Size,';');
     UnpackTime(Info.Time,T);
     Write(' ':8,'Time:',Info.Time,'  ');
     WriteLn('(* ',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',
             PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2),' *)');
    End;
    Write(' ':4,')');
    FindNextMatch;
    Error:=DOSError;
    If Error=0 Then Write(',');
    WriteLn;
   End;
   WriteLn(');');
  End;
  _SQL:Begin
   WriteLn('CREATE TABLE files (');
   WriteLn(' ':8,'filename TEXT,');
   WriteLn(' ':8,'attribut TEXT,');
   WriteLn(' ':8,'size INT,');
   WriteLn(' ':8,'time TEXT');
   WriteLn(');');
   FindFirstMatch;
   While DOSError=0 do Begin
    WriteLn('INSERT INTO files (filename,attribut,size,time) VALUES (');
    WriteLn(' ':8,'''',DisplayName,''',');
    If Not((Width)in(Column))Then Begin
     Write(' ':8,'''');
     If Info.Attr and Directory=Directory Then Begin
      Write('[directory]');
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      Write('[readonly]');
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      Write('[system]');
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      Write('[hidden]');
     End;
     If Info.Attr and Archive=Archive Then Begin
      Write('[archive]');
     End;
     WriteLn(''',');
     WriteLn(' ':8,'',Info.Size,',');
     UnpackTime(Info.Time,T);
     WriteLn(' ':8,'''',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',
             PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2),
             '''');
    End;
    WriteLn(' ':4,');');
    FindNextMatch;
   End;
  End;
  _XML:Begin
   WriteLn('<?xml version="1.0" encoding="UTF-8"?>');
   WriteLn('<files>');
   FindFirstMatch;
   While DOSError=0 do Begin
    WriteLn(' ':4,'<file>');
    WriteLn(' ':8,'<filename>',DisplayName,'</filename>');
    If Not((Width)in(Column))Then Begin
     Write(' ':8,'<attribut>');
     If Info.Attr and Directory=Directory Then Begin
      Write('[directory]');
     End;
     If Info.Attr and ReadOnly=ReadOnly Then Begin
      Write('[readonly]');
     End;
     If Info.Attr and SysFile=SysFile Then Begin
      Write('[system]');
     End;
     If Info.Attr and Hidden=Hidden Then Begin
      Write('[hidden]');
     End;
     If Info.Attr and Archive=Archive Then Begin
      Write('[archive]');
     End;
     WriteLn('</attribut>');
     WriteLn(' ':8,'<size>',Info.Size,'</size>');
     UnpackTime(Info.Time,T);
     WriteLn(' ':8,'<time>',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',
             PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2),
             '</time>');
    End;
    WriteLn(' ':4,'</file>');
    FindNextMatch;
   End;
   WriteLn('</files>');
  End;
  Else Begin
   FindFirstMatch;
   If(Width)in(Column)Then While DOSError=0 do Begin
    Write(PadRight(DisplayName,16));
    FindNextMatch;
    If(Pause)in(Option)Then Begin
    Inc(P);
     If P=Hi(WindMax)Then Begin
      Write('Presse une touche pour continuer...');
      If ReadKey=#27Then Exit;
      WriteLn;
      P:=0;
     End;
    End;
   End
    Else
   If(Double)in(Column)Then While DOSError=0 do Begin
    Write(PadRight(DisplayName,13));
    If Info.Attr and Directory=Directory Then Begin
     Write(PadRight('<DIR>',9));
    End
     Else
    Write(Info.Size:9);
    UnpackTime(Info.Time,T);
    Write(' ',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2),' ');
    FindNextMatch;
    If(Pause)in(Option)Then Begin
     Inc(P);
     If P=Hi(WindMax)Then Begin
      Write('Presse une touche pour continuer...');
      If ReadKey=#27Then Exit;
      WriteLn;
      P:=0;
     End;
    End;
   End
    Else
   Begin
    TotalNumFiles:=0;
    TotalSize:=0;
    If Not((Brief)in(Option))Then Begin
     Inc(P,2);
     WriteLn('Le volume de l''unite '+CurrDrive+' est '+CurrLabel);
     WriteLn;
    End;
    While DOSError=0 do Begin
     Write(PadRight(DisplayName,13));
     If Info.Attr and Directory=Directory Then Begin
      Write(PadRight('<DIR>',15));
     End
      Else
     Write(Info.Size:15);
     UnpackTime(Info.Time,T);
     WriteLn(' ',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2));
     Inc(TotalNumFiles);
     Inc(TotalSize,Info.Size);
     FindNextMatch;
     If(Pause)in(Option)Then Begin
      Inc(P);
      If P=Hi(WindMax)Then Begin
       Write('Presse une touche pour continuer...');
       If ReadKey=#27Then Exit;
       WriteLn;
       P:=0;
      End;
     End;
    End;
    If Not((Brief)in(Option))Then Begin
     WriteLn(' Les ',TotalNumFiles,' fichier(s) utilisent ',TotalSize,' octet(s)');
     WriteLn(DiskFree(Byte(CurrDrive)-64):10,' octet(s) de libre');
    End;
   End;
  End;
 End;
 FreeEntries;
END.
