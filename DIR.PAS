{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2021
  @website(https://www.gladir.com/dev-cools)
  @abstract(Cible : Turbo Pascal 7, Free Pascal)
}

Program DIR;

{$IFDEF MSDOS}{$DEFINE DOSCOMPRESSION}{$ENDIF}
{$IFDEF GO32V2}{$DEFINE DOSCOMPRESSION}{$ENDIF}

Uses {$IFDEF FPC}{$IFDEF WINDOWS}Windows,{$ENDIF}{$ENDIF}
     {$IFDEF GO32V2}Go32,{$ENDIF} Crt,DOS;

Type
 PDirPath=^TDirPath;
 TDirPath=Record
  Path:String;
  Next:PDirPath;
 End;
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
 Option:Set of (Pause,Subdirectory,Lower,Brief,Description,CompressionDetails,
                NoColor,FullPath,JustifyNames,NoHeader);
 Column:Set Of (Double,Width,Four);
 TotalNumFiles,TotalSize:LongInt;
 CurrParam,ShowDir,CurrLabel:String;
 CurrDrive:Char;
 OutputFormat:(_Text,_CSV,_HTML,_Json,_Pascal,_SQL,_XML);
 RequiredAttr,ExcludedAttr:Word;
 SortOrder:String;
 Entries,CurrentEntry:PDirEntry;
 EntriesLoaded:Boolean;
 PendingDirs:PDirPath;
 RecursiveRoot,RecursiveMask,CurrentFolder:String;

Function StrToUpper(S:String):String; Forward;
Function PadRight(S:String;Space:Byte):String; Forward;

Function ShowCompression:Boolean;
Begin
 ShowCompression:=(CompressionDetails in Option)and
                  Not(Brief in Option)and Not(Width in Column);
End;

Function DisplayName:String;
Var
 S:String;
 I:Integer;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 S:=Info.Name;
 If Subdirectory in Option Then S:=CurrentFolder+S Else
 If FullPath in Option Then Begin
  FSplit(FExpand(ShowDir),D,N,E);
  S:=D+S;
 End;
 If Lower in Option Then
  For I:=1 to Length(S)do
   If S[I] in ['A'..'Z']Then S[I]:=Chr(Ord(S[I])+32);
 DisplayName:=S;
End;

Function TextDisplayName:String;
Var
 S,Name,Prefix,Extension:String;
 I,Dot:Integer;
Begin
 S:=DisplayName;
 TextDisplayName:=S;
 If Not(JustifyNames in Option)Then Exit;
 If (Info.Attr and Directory)<>0Then Exit;
 { Separer le nom de son extension, sans modifier les chemins ni les exports. }
 Prefix:=Copy(S,1,Length(S)-Length(Info.Name));
 Name:=Copy(S,Length(Prefix)+1,255);
 Dot:=0;
 For I:=2 to Length(Name)do If Name[I]='.'Then Dot:=I;
 Extension:='';
 If Dot>0Then Begin
  Extension:=Copy(Name,Dot+1,255);
  Name:=Copy(Name,1,Dot-1);
 End;
 TextDisplayName:=Prefix+PadRight(Name,8)+' '+PadRight(Extension,3);
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
     { Comparer les dates/heures DOS compactes comme des valeurs non signees,
       y compris pour les annees >= 2044. }
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

{ Tri fusion stable : les cles egales conservent l'ordre d'enumeration. }
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

{$IFDEF DOSCOMPRESSION}
Function DosStoredSize(Path:String;Var StoredSize:Real):Boolean;
Var
 {$IFDEF GO32V2}R:Go32.TRealRegs;{$ELSE}R:Registers;{$ENDIF}
 FileNameZ:Array[0..255]of Char;
 MajorVersion:Byte;

 Function CallDos:Boolean;
 Begin
  {$IFDEF GO32V2}
  CallDos:=Go32.RealIntr($21,R);
  {$ELSE}
  MsDos(R);
  CallDos:=True;
  {$ENDIF}
 End;

Begin
 DosStoredSize:=False;
 StoredSize:=0;
 { AX=4302h a une autre signification sous DR DOS (droits d'acces).
   Utiliser uniquement l'interface MS-DOS 7+. AH=30h fournit l'identifiant OEM;
   AX=3306h fournit la version reelle meme lorsque SETVER est actif. }
 FillChar(R,SizeOf(R),0);
 R.AX:=$3000;
 If Not CallDos Then Exit;
 If R.BH=$EE Then Exit;
 MajorVersion:=R.AL;
 FillChar(R,SizeOf(R),0);
 R.AX:=$3306;
 If Not CallDos Then Exit;
 If (R.Flags and FCarry)=0Then
  If R.AL<>$FF Then MajorVersion:=R.BL;
 If MajorVersion<7Then Exit;
 FillChar(FileNameZ,SizeOf(FileNameZ),0);
 Move(Path[1],FileNameZ[0],Length(Path));
 FillChar(R,SizeOf(R),0);
 R.AX:=$4302;
 R.Flags:=FCarry;
 {$IFDEF GO32V2}
 { Les adresses du mode protege ne peuvent pas etre transmises
   comme des pointeurs DOS segment:deplacement. }
 If Length(Path)+1>Go32.TB_Size Then Exit;
 Go32.DosMemPut(Go32.TB_Segment,Go32.TB_Offset,FileNameZ,Length(Path)+1);
 R.DS:=Go32.TB_Segment;
 R.DX:=Go32.TB_Offset;
 {$ELSE}
 R.DS:=Seg(FileNameZ);
 R.DX:=Ofs(FileNameZ);
 {$ENDIF}
 { INT 21h/AX=4302h : DS:DX -> chemin ASCIIZ, CF=erreur, DX:AX=taille.
   Sur un volume non compresse, le resultat est arrondi au multiple
   superieur de la taille d'une unite d'allocation. }
 If Not CallDos Then Exit;
 If (R.Flags and FCarry)<>0Then Exit;
 StoredSize:=R.DX*65536.0+R.AX;
 DosStoredSize:=True;
End;
{$ENDIF}

{$IFDEF DOSCOMPRESSION}
Function DosCompressedDrive(Drive:Char):Boolean;
Var
 {$IFDEF GO32V2}R:Go32.TRealRegs;{$ELSE}R:Registers;{$ENDIF}
Begin
 DosCompressedDrive:=False;
 If Not(UpCase(Drive) in ['A'..'Z'])Then Exit;
 FillChar(R,SizeOf(R),0);
 R.AX:=$4A11;
 {$IFDEF GO32V2}
 If Not Go32.RealIntr($2F,R)Then Exit;
 {$ELSE}
 Intr($2F,R);
 {$ENDIF}
 If (R.AX<>0)or(R.BX<>$444D)Then Exit;
 { DoubleSpace/DriveSpace : le bit 7 de BL identifie un lecteur compresse. }
 FillChar(R,SizeOf(R),0);
 R.AX:=$4A11;
 R.BX:=1;
 R.DL:=Ord(UpCase(Drive))-Ord('A');
 {$IFDEF GO32V2}
 If Not Go32.RealIntr($2F,R)Then Exit;
 {$ELSE}
 Intr($2F,R);
 {$ENDIF}
 DosCompressedDrive:=(R.AX=0)and((R.BL and $80)<>0);
End;
{$ENDIF}

Function FileStorageInfo(Var StoredSize:Real;Var Compressed:Boolean):Boolean;
Var
 Available:Boolean;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
{$IFDEF FPC}{$IFDEF WINDOWS}
 Path:AnsiString;
 LowSize,HighSize,Attributes:DWORD;
{$ENDIF}{$ENDIF}
Begin
 FileStorageInfo:=False;
 Available:=False;
 Compressed:=False;
 StoredSize:=0;
 If (Info.Size<=0)or((Info.Attr and Directory)<>0)Then Exit;
 FSplit(FExpand(ShowDir),D,N,E);
{$IFDEF DOSCOMPRESSION}
 If Not DosStoredSize(D+Info.Name,StoredSize)Then Exit;
 Compressed:=DosCompressedDrive(D[1]);
 Available:=True;
{$ENDIF}
{$IFDEF FPC}{$IFDEF WINDOWS}
 Path:=D+Info.Name;
 Windows.SetLastError(0);
 LowSize:=Windows.GetCompressedFileSizeA(PChar(Path),@HighSize);
 If (LowSize=DWORD($FFFFFFFF))and(Windows.GetLastError<>0)Then Exit;
 StoredSize:=HighSize*4294967296.0+LowSize;
 Attributes:=Windows.GetFileAttributesA(PChar(Path));
 If Attributes<>DWORD($FFFFFFFF)Then
  Compressed:=(Attributes and FILE_ATTRIBUTE_COMPRESSED)<>0;
 Available:=True;
{$ENDIF}{$ENDIF}
 { La reduction effective couvre aussi les volumes compresses Windows 9x. }
 If Available and(StoredSize<Info.Size)Then Compressed:=True;
 FileStorageInfo:=Available;
End;

Function CompressionRate:Real;
Var
 StoredSize:Real;
 Compressed:Boolean;
Begin
 { Pourcentage d'octets economises pour le tri /O:C. }
 CompressionRate:=0;
 If Not FileStorageInfo(StoredSize,Compressed)Then Exit;
 If StoredSize<Info.Size Then
  CompressionRate:=100.0*(1.0-StoredSize/Info.Size);
End;

Function CompressionRatioText:String;
Var
 StoredSize,AllocatedSize:Real;
 Compressed:Boolean;
 S:String;
Begin
 CompressionRatioText:='-';
 If Not FileStorageInfo(StoredSize,Compressed)Then Exit;
 If Not Compressed Then Exit;
 If StoredSize<=0Then Exit;
 { Arrondir la taille logique a l'unite de 8 Ko, sans debordement LongInt.
   La taille physique reste celle fournie par le systeme, sans arrondi a 8 Ko. }
 AllocatedSize:=(Info.Size div 8192)*8192.0;
 If (Info.Size mod 8192)<>0Then AllocatedSize:=AllocatedSize+8192.0;
 Str(AllocatedSize/StoredSize:0:1,S);
 CompressionRatioText:=S+':1';
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

{ Chaque signe s'applique a l'attribut suivant;
  les attributs sans signe doivent etre presents. }
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
     ((Info.Attr and ExcludedAttr)=0)Then
   If Not(Subdirectory in Option)or
      ((Info.Name<>'.')and(Info.Name<>'..'))Then Exit;
  FindNext(Info);
 End;
End;

Procedure FindFirstLocalMatch;
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

Procedure FindNextLocalMatch;
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

Function AppendPath(A,B:String):String;
Begin
 If Length(A)+Length(B)>255Then Begin
  Case Language of
   _Germany:WriteLn('Pfad zu lang: ',A,B);
   _English:WriteLn('Path too long: ',A,B);
   Else WriteLn('Chemin trop long : ',A,B);
  End;
  Halt(1);
 End;
 AppendPath:=A+B;
End;

Function FolderPath(Path:String):String;
Begin
 If Path<>''Then
  If Not(Path[Length(Path)] in ['\','/'])Then
   {$IFDEF UNIX}Path:=AppendPath(Path,'/');{$ELSE}Path:=AppendPath(Path,'\');{$ENDIF}
 FolderPath:=Path;
End;

Procedure FreePendingDirs;
Var
 NextDir:PDirPath;
Begin
 While PendingDirs<>Nil do Begin
  NextDir:=PendingDirs^.Next;
  Dispose(PendingDirs);
  PendingDirs:=NextDir;
 End;
End;

Procedure QueueSubdirectories;
Var
 DirInfo:SearchRec;
 Node,Head,Tail:PDirPath;
 Path:String;
 Descend:Boolean;
 {$IFDEF FPC}{$IFDEF WINDOWS}
 NativePath:AnsiString;
 Attributes:DWORD;
 {$ENDIF}{$ENDIF}
Begin
 Head:=Nil;
 Tail:=Nil;
 { Le masque de fichiers et /A ne doivent pas filtrer les dossiers a parcourir. }
 FindFirst(AppendPath(CurrentFolder,'*.*'),AnyFile,DirInfo);
 While DosError=0do Begin
  Descend:=((DirInfo.Attr and Directory)<>0)and
           (DirInfo.Name<>'.')and(DirInfo.Name<>'..');
  If Descend Then Begin
   Path:=AppendPath(CurrentFolder,DirInfo.Name);
   {$IFDEF FPC}{$IFDEF WINDOWS}
   { Ne pas suivre les jonctions ou liens pouvant revenir vers un dossier parent. }
   NativePath:=Path;
   Attributes:=Windows.GetFileAttributesA(PChar(NativePath));
   Descend:=(Attributes<>DWORD($FFFFFFFF))and
            ((Attributes and FILE_ATTRIBUTE_REPARSE_POINT)=0);
   {$ENDIF}{$ENDIF}
   {$IFDEF UNIX}
   Descend:=(DirInfo.Attr and $40)=0;
   {$ENDIF}
   If Descend Then Begin
    {$IFNDEF FPC}
    If MaxAvail<SizeOf(TDirPath)Then Begin
     Case Language of
      _Germany:WriteLn('Nicht genug Speicher.');
      _English:WriteLn('Not enough memory.');
      Else WriteLn('M'+#130+'moire insuffisante.');
     End;
     Halt(1);
    End;
    {$ENDIF}
    New(Node);
    Node^.Path:=FolderPath(Path);
    Node^.Next:=Nil;
    If Head=Nil Then Head:=Node Else Tail^.Next:=Node;
    Tail:=Node;
   End;
  End;
  FindNext(DirInfo);
 End;
 {$IFDEF FPC}FindClose(DirInfo);{$ENDIF}
 { Parcours en profondeur, sans conserver de recherche ouverte pour les parents. }
 If Tail<>Nil Then Begin
  Tail^.Next:=PendingDirs;
  PendingDirs:=Head;
 End;
End;

Procedure StartFolder;
Begin
 FreeEntries;
 CurrentEntry:=Nil;
 EntriesLoaded:=False;
 ShowDir:=AppendPath(CurrentFolder,RecursiveMask);
 QueueSubdirectories;
 FindFirstLocalMatch;
End;

Procedure AdvanceFolder;
Var
 Node:PDirPath;
Begin
 While DosError<>0do Begin
  If SortOrder=''Then Begin
   {$IFDEF FPC}FindClose(Info);{$ENDIF}
  End;
  If PendingDirs=Nil Then Begin
   DosError:=18;
   Exit;
  End;
  Node:=PendingDirs;
  PendingDirs:=Node^.Next;
  CurrentFolder:=Node^.Path;
  Dispose(Node);
  StartFolder;
 End;
End;

Procedure FindFirstMatch;
Begin
 If Not(Subdirectory in Option)Then Begin
  FindFirstLocalMatch;
  Exit;
 End;
 { Reinitialiser aussi le parcours pour la seconde passe du format Pascal. }
 FreePendingDirs;
 CurrentFolder:=RecursiveRoot;
 StartFolder;
 AdvanceFolder;
End;

Procedure FindNextMatch;
Begin
 FindNextLocalMatch;
 If Subdirectory in Option Then AdvanceFolder;
End;

Procedure PrepareRecursivePath;
Var
 DirInfo:SearchRec;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
 Expanded:String;
 IsFolder:Boolean;
Begin
 Expanded:=FExpand(ShowDir);
 IsFolder:=False;
 If (Pos('*',Expanded)=0)and(Pos('?',Expanded)=0)Then Begin
  FindFirst(Expanded,AnyFile,DirInfo);
  If DosError=0Then IsFolder:=(DirInfo.Attr and Directory)<>0;
  {$IFDEF FPC}FindClose(DirInfo);{$ENDIF}
 End;
 If IsFolder Then Begin
  RecursiveRoot:=FolderPath(Expanded);
  RecursiveMask:='*.*';
 End Else Begin
  FSplit(Expanded,D,N,E);
  RecursiveRoot:=FolderPath(D);
  RecursiveMask:=N+E;
  If RecursiveMask=''Then RecursiveMask:='*.*';
 End;
End;

Procedure WriteJsonDisplayName;
Var
 S:String;
 I:Integer;
Begin
 S:=DisplayName;
 For I:=1 to Length(S)do Begin
  If S[I] in ['\','"']Then Write('\');
  Write(S[I]);
 End;
End;

Procedure WriteFileDescription;
Var
 F:Text;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
 Name,DescriptionPath:String;
 Ch:Char;
 Quoted,Valid,Found,Started,Metadata:Boolean;
 Status:Integer;
Begin
 { Lire le fichier du dossier courant du parcours, avec les noms originaux.
   La lecture caractere par caractere accepte les descriptions de plus de 255 caracteres. }
 FSplit(FExpand(ShowDir),D,N,E);
 DescriptionPath:=AppendPath(D,'DESCRIPT.ION');
 Assign(F,DescriptionPath);
 {$I-}Reset(F);{$I+}
 If IOResult<>0Then Exit;
 Found:=False;
 Status:=0;
 {$I-}
 While Not Eof(F)and Not Found and(Status=0)do Begin
  Name:='';
  Ch:=' ';
  While Not Eoln(F)and(Ch in [' ',#9])do Begin
   Read(F,Ch);
   Status:=IOResult;
   If Status<>0Then Break;
  End;
  If Status<>0Then Break;
  Quoted:=Ch='"';
  Valid:=True;
  If Quoted Then Begin
   Valid:=False;
   While Not Eoln(F)do Begin
    Read(F,Ch);
    Status:=IOResult;
    If Status<>0Then Break;
    If Ch='"'Then Begin Valid:=True; Break; End;
    If Length(Name)<255Then Name:=Name+Ch Else Break;
   End;
  End Else Begin
   While Not(Ch in [' ',#9])do Begin
    If Length(Name)<255Then Name:=Name+Ch Else Begin Valid:=False; Break; End;
    If Eoln(F)Then Break;
    Read(F,Ch);
    Status:=IOResult;
    If Status<>0Then Break;
   End;
  End;
  If Status<>0Then Break;
  Found:=Valid and(Name<>'')and(StrToUpper(Name)=StrToUpper(Info.Name));
  Started:=False;
  Metadata:=False;
  While Not Eoln(F)do Begin
   Read(F,Ch);
   Status:=IOResult;
   If Status<>0Then Break;
   { Le caractere 4 introduit les donnees privees des autres logiciels. }
   If Ch=#4Then Metadata:=True;
   If Found and Not Metadata Then Begin
    If Not Started and Not(Ch in [' ',#9])Then Begin
     Write(' ');
     Started:=True;
    End;
    If Started Then Begin
     If Ch=#9Then Write(' ')Else If Ch>=' 'Then Write(Ch);
    End;
   End;
  End;
  If Status<>0Then Break;
  ReadLn(F);
  Status:=IOResult;
 End;
 Close(F);
 Status:=IOResult;
 {$I+}
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

Procedure ShowFourColumns;
Var
 Names,Sizes:Array[1..4]of String;
 Count,I:Byte;
 NameWidth,SizeWidth:Byte;
Begin
 While DosError=0do Begin
  Count:=0;
  NameWidth:=12;
  SizeWidth:=5;
  { Memoriser une ligne avant l'affichage pour aligner les quatre colonnes.
    Les noms longs et les grandes tailles sont conserves integralement. }
  While (Count<4)and(DosError=0)do Begin
   Inc(Count);
   Names[Count]:=TextDisplayName;
   If (Info.Attr and Directory)<>0Then Sizes[Count]:='<DIR>'
   Else Str(Info.Size,Sizes[Count]);
   If Length(Names[Count])>NameWidth Then NameWidth:=Length(Names[Count]);
   If Length(Sizes[Count])>SizeWidth Then SizeWidth:=Length(Sizes[Count]);
   FindNextMatch;
  End;
  For I:=1 to Count do Begin
   If I>1Then Write('  ');
   Write(PadRight(Names[I],NameWidth),' ',Sizes[I]:SizeWidth);
  End;
  WriteLn;
  { La pagination compte les lignes completes, et non les fichiers. }
  If Pause in Option Then Begin
   Inc(P);
   If (P>=Hi(WindMax))and(DosError=0)Then Begin
    Write('Presse une touche pour continuer...');
    If ReadKey=#27Then Exit;
    WriteLn;
    P:=0;
   End;
  End;
 End;
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
 PendingDirs:=Nil;
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
     WriteLn('Format:   DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/P] [/S] ',
             '[/A[[:]Attribute]] [/O[[:]Folge]] [Pfad] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /A[[:]Attribute]  A=Archiv D=Verzeichnis H=Versteckt R=Schreibgesch'+#129+'tzt S=System');
     WriteLn('                  + : einschlie'+#225+'en; - : ausschlie'+#225+'en');
     WriteLn('                  /A : alle; /A:H-D : versteckte Dateien ohne Verzeichnisse');
     WriteLn(' /C               DoubleSpace-Kompressionsverh'+#132+'ltnis, 8-KB-Einheiten');
     WriteLn('                  MS-DOS 7+ / Windows; - = nicht verf'+#129+'gbar; /B und /W haben Vorrang');
     WriteLn(' /L               Datei- und Verzeichnisnamen in Kleinbuchstaben anzeigen');
     WriteLn(' /1               Eine Datei pro Zeile: Name, Gr'+#148+'sse, Datum, Beschreibung');
     WriteLn('                  Beschreibungen aus DESCRIPT.ION im jeweiligen Verzeichnis');
     WriteLn(' /4               Dateien mit ihren Gr'+#148+'ssen in vier Spalten anzeigen');
     WriteLn(' /D               Farbdarstellung deaktivieren');
     WriteLn(' /F               Vollst'+#132+'ndige Dateinamen mit Pfad anzeigen');
     WriteLn(' /J               Dateinamen und Erweiterungen getrennt ausrichten');
     WriteLn(' /K               Kopfzeilen ausblenden, Summen beibehalten');
     WriteLn(' /S               Dateien auch in allen Unterverzeichnissen auflisten');
     WriteLn(' /O[[:]Folge]     C=Kompressionsrate D=Datum/Zeit E=Erweiterung');
     WriteLn('                  G=Verzeichnisse zuerst N=Name S=Gr'+#148+'sse');
     WriteLn('                  Aufsteigend; - kehrt den folgenden Schl'+#129+'ssel um');
     WriteLn('                  /O = GN; mehrere Schl'+#129+'ssel, z.B. /O:G-S');
     WriteLn('                  C: eingesparte Bytes (%), Windows / MS-DOS 7+');
     WriteLn('                  Ohne Unterst'+#129+'tzung: 0');
    End;
    _English:Begin
     WriteLn('Purpose:  Display information about files and subdirectories.');
     WriteLn;
     WriteLn('Format:   DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/P] [/S] ',
             '[/A[[:]attributes]] [/O[[:]order]] [path] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /A[[:]attributes] A=Archive D=Directory H=Hidden R=ReadOnly S=System');
     WriteLn('                  + : include; - : exclude');
     WriteLn('                  /A : all; /A:H-D : hidden files without directories');
     WriteLn(' /C               DoubleSpace compression ratio, based on 8 KB allocation units');
     WriteLn('                  MS-DOS 7+ / Windows; - = unavailable; ignored with /B or /W');
     WriteLn(' /L               Display file and directory names in lowercase');
     WriteLn(' /1               One file per line: name, size, date and description');
     WriteLn('                  Descriptions from DESCRIPT.ION in each directory');
     WriteLn(' /4               Display files and their sizes in four columns');
     WriteLn(' /D               Disable color coding');
     WriteLn(' /F               Display full filenames including their paths');
     WriteLn(' /J               Align filenames and extensions separately');
     WriteLn(' /K               Suppress headers, retaining totals');
     WriteLn(' /S               List files recursively in all subdirectories');
     WriteLn(' /O[[:]order]     C=Compression rate D=Date/time E=Extension');
     WriteLn('                  G=Directories first N=Name S=Size');
     WriteLn('                  Ascending; - reverses the following key');
     WriteLn('                  /O = GN; combine keys, e.g. /O:G-S');
     WriteLn('                  C: bytes saved (%), Windows / MS-DOS 7+');
     WriteLn('                  Unsupported systems: 0');
    End;
    Else Begin
     WriteLn('DIR   Cette commande permet d''afficher le contenu d''un r'+#130+'pertoire dans l''unite de disque.');
     WriteLn;
     WriteLn('Syntaxe:');
     WriteLn;
     WriteLn('DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/P] [/S] ',
             '[/A[[:]attributs]] [/O[[:]ordretri]] [chemin] [/FORMAT:format]');
     WriteLn;
     WriteLn(' /?               Ce param'+#138+'tre permet d''afficher l''aide sur cette commande');
     WriteLn(' /1               Un fichier par ligne : nom, taille, date et description');
     WriteLn('                  Descriptions lues dans DESCRIPT.ION de chaque dossier');
     WriteLn(' /2               Ce param'+#138+'tre permet d''afficher sur 2 colonnes');
     WriteLn(' /4               Affiche les fichiers et leurs tailles sur quatre colonnes');
     WriteLn(' /A[[:]attributs]  A=Archive D=R'+#130+'pertoire H=Cach'+#130+' R=Lecture seule S=Syst'+#138+'me');
     WriteLn('                  + : inclure; - : exclure');
     WriteLn('                  /A : tous; /A:H-D : fichiers cach'+#130+'s sans les r'+#130+'pertoires');     
     WriteLn(' /B               Ce param'+#138+'tre enl'+#138+'ve l''entete et les d'+#130+'tails de la fin');     
     WriteLn(' /C               Taux de compression DoubleSpace, unit'+#130+'s d''allocation de 8 Ko');
     WriteLn('                  MS-DOS 7+ / Windows; - = indisponible; ignor'+#130+' avec /B ou /W');     
     WriteLn(' /D               D'+#130+'sactive la colorisation');
     WriteLn(' /F               Affiche les noms complets avec leur chemin');
     WriteLn(' /FORMAT:format   Ce param'+#138+'tre permet d''indiquer CSV, HTML, Json, PASCAL, SQL ou XML');     
     WriteLn(' /J               Aligne s'+#130+'par'+#130+'ment les noms et les extensions');
     WriteLn(' /K               Masque les ent'+#136+'tes et conserve les totaux');
     WriteLn(' /L               Affiche les noms des fichiers et r'+#130+'pertoires en minuscules');
     WriteLn(' /O[[:]ordretri]  C=Taux de compression D=Date/heure E=Extension');
     WriteLn('                  G=R'+#130+'pertoires en premier N=Nom S=Taille');
     WriteLn('                  Ordre croissant; - inverse le crit'+#138+'re suivant');
     WriteLn('                  /O = GN; crit'+#138+'res combinables, ex. /O:G-S');
     WriteLn('                  C : octets '+#130+'conomis'+#130+'s (%), Windows / MS-DOS 7+');
     WriteLn('                  Syst'+#138+'mes non pris en charge : 0');
     WriteLn(' /P               Ce param'+#138+'tre affiche une pause apres l''affichage d''une page pleine');
     WriteLn(' /S               Ce param'+#138+'tre affiche les fichiers du dossier et de tous ses sous-dossiers');
     WriteLn(' /W               Ce param'+#138+'tre affiche seulement les fichiers sur plein de colonnes');
    End;
   End;
   Exit;
  End
   Else
  If CurrParam='/2'Then Begin
   Exclude(Column,Four);
   Include(Column,Double);
  End Else
  If CurrParam='/4'Then Column:=[Four] Else
  If CurrParam='/1'Then Include(Option,Description) Else
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
  If(CurrParam='/C')or(CurrParam='/c')Then Include(Option,CompressionDetails) Else
  If(CurrParam='/D')or(CurrParam='/d')Then Include(Option,NoColor) Else
  If(CurrParam='/F')or(CurrParam='/f')Then Include(Option,FullPath) Else
  If(CurrParam='/J')or(CurrParam='/j')Then Include(Option,JustifyNames) Else
  If(CurrParam='/K')or(CurrParam='/k')Then Include(Option,NoHeader) Else
  If(CurrParam='/L')or(CurrParam='/l')Then Include(Option,Lower) Else
  If(CurrParam='/P')or(CurrParam='/p')Then Include(Option,Pause) Else
  If(CurrParam='/S')or(CurrParam='/s')Then Include(Option,Subdirectory) Else
  If(CurrParam='/W')or(CurrParam='/w')Then Begin
   Exclude(Column,Four);
   Include(Column,Width);
  End Else
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
 If (Description in Option)or(Four in Column)Then Begin
  If Description in Option Then Column:=[];
  OutputFormat:=_Text;
  If Not(Subdirectory in Option)Then Begin
   PrepareRecursivePath;
   ShowDir:=AppendPath(RecursiveRoot,RecursiveMask);
  End;
 End;
 If Subdirectory in Option Then PrepareRecursivePath;
 If (FullPath in Option)and Not(Subdirectory in Option)Then Begin
  PrepareRecursivePath;
  ShowDir:=AppendPath(RecursiveRoot,RecursiveMask);
 End;
 { Aucun schema de couleurs n'est applique; /D retablit les attributs normaux. }
 If (NoColor in Option)and(OutputFormat=_Text)Then NormVideo;
 CurrDrive:=Path2Drive(ShowDir);
 CurrLabel:=GetDiskLabel(Byte(CurrDrive)-64);
 P:=0;
 Case OutputFormat of
  _CSV:Begin
   FindFirstMatch;
   While DOSError=0 do Begin
    Write(DisplayName);
    If ShowCompression Then Write(',',CompressionRatioText);
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
   If ShowCompression Then WriteLn(' ':8,'<th>Compression (8K)</th>');
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
    If ShowCompression Then WriteLn(' ':8,'<td>',CompressionRatioText,'</td>');
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
    Write(' ':8,'"filename":"');
    WriteJsonDisplayName;
    WriteLn('",');
    If ShowCompression Then
     WriteLn(' ':8,'"compression8k":"',CompressionRatioText,'",');
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
    If ShowCompression Then
     WriteLn(' ':8,'(* Compression (8K): ',CompressionRatioText,' *)');
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
   If ShowCompression Then WriteLn(' ':8,'compression8k TEXT,');
   WriteLn(' ':8,'attribut TEXT,');
   WriteLn(' ':8,'size INT,');
   WriteLn(' ':8,'time TEXT');
   WriteLn(');');
   FindFirstMatch;
   While DOSError=0 do Begin
    Write('INSERT INTO files (filename,');
    If ShowCompression Then Write('compression8k,');
    WriteLn('attribut,size,time) VALUES (');
    WriteLn(' ':8,'''',DisplayName,''',');
    If ShowCompression Then WriteLn(' ':8,'''',CompressionRatioText,''',');
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
    If ShowCompression Then
     WriteLn(' ':8,'<compression8k>',CompressionRatioText,'</compression8k>');
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
   If((Subdirectory in Option)or(FullPath in Option))and(Brief in Option)and
     Not(Description in Option)Then While DosError=0do Begin
    WriteLn(DisplayName);
    FindNextMatch;
    If Pause in Option Then Begin
     Inc(P);
     If P=Hi(WindMax)Then Begin
      Write('Presse une touche pour continuer...');
      If ReadKey=#27Then Exit;
      WriteLn;
      P:=0;
     End;
    End;
   End Else
   If Four in Column Then ShowFourColumns Else
   If(Width)in(Column)Then While DOSError=0 do Begin
    Write(PadRight(TextDisplayName,16));
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
    Write(PadRight(TextDisplayName,13));
    If Info.Attr and Directory=Directory Then Begin
     Write(PadRight('<DIR>',9));
    End
     Else
    Write(Info.Size:9);
    If ShowCompression Then Write(' ',CompressionRatioText:8);
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
    If Not(Brief in Option)and Not(NoHeader in Option)Then Begin
     Inc(P,2);
     WriteLn('Le volume de l''unite '+CurrDrive+' est '+CurrLabel);
     WriteLn;
    End;
    While DOSError=0 do Begin
     Write(PadRight(TextDisplayName,13));
     If Info.Attr and Directory=Directory Then Begin
      Write(PadRight('<DIR>',15));
     End
      Else
     Write(Info.Size:15);
     If ShowCompression Then Write(' ',CompressionRatioText:8);
     UnpackTime(Info.Time,T);
     Write(' ',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2));
     If Description in Option Then WriteFileDescription;
     WriteLn;
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
 FreePendingDirs;
END.
