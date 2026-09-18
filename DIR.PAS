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
 PDisplayCell=^TDisplayCell;
 TDisplayCell=Record
  Name,Details:String;
  Color:Byte;
  Next:PDisplayCell;
 End;
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
                NoColor,FullPath,JustifyNames,NoHeader,NoFooter,
                AttributesOnly,SummaryOnly,Vertical);
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
 ColorRules:String;
 OriginalColor:Byte;
 ListingNameWidth:Byte;

Function StrToUpper(S:String):String; Forward;
Function PadRight(S:String;Space:Byte):String; Forward;

{ Les regles COLORDIR sont examinees de gauche a droite, comme sous 4DOS. }
Function ColorMatch(Pattern,Value:String):Boolean;
Var I,J,Star,Retry:Integer;
Begin
 I:=1; J:=1; Star:=0; Retry:=0;
 While J<=Length(Value)do Begin
  If (I<=Length(Pattern))and((Pattern[I]='?')or(Pattern[I]=Value[J]))Then Begin
   Inc(I); Inc(J);
  End Else If (I<=Length(Pattern))and(Pattern[I]='*')Then Begin
   Star:=I; Inc(I); Retry:=J;
  End Else If Star<>0Then Begin
   Inc(Retry); J:=Retry; I:=Star+1;
  End Else Begin ColorMatch:=False; Exit; End;
 End;
 While (I<=Length(Pattern))and(Pattern[I]='*')do Inc(I);
 ColorMatch:=I>Length(Pattern);
End;

Function ColorSelector(S:String):Boolean;
Var Name,Extension:String; I:Integer;
Begin
 If S='DIRS'Then ColorSelector:=(Info.Attr and Directory)<>0 Else
 If S='HIDDEN'Then ColorSelector:=(Info.Attr and Hidden)<>0 Else
 If S='SYSTEM'Then ColorSelector:=(Info.Attr and SysFile)<>0 Else
 If S='RDONLY'Then ColorSelector:=(Info.Attr and ReadOnly)<>0 Else
 If S='ARCHIVE'Then ColorSelector:=(Info.Attr and Archive)<>0 Else
 If S='NORMAL'Then ColorSelector:=(Info.Attr and (Directory+Hidden+SysFile+ReadOnly))=0
 Else Begin
  Name:=StrToUpper(Info.Name); Extension:='';
  For I:=Length(Name)downto 1do If Name[I]='.'Then Begin
   Extension:=Copy(Name,I+1,255); Break;
  End;
  { Les extensions seules et les masques de noms sont acceptes. }
  If Pos('.',S)>0Then ColorSelector:=ColorMatch(S,Name)
  Else ColorSelector:=ColorMatch(S,Extension);
 End;
End;

Function ParseColor(S:String;Var Value:Byte):Boolean;
Var Token:String; N,Foreground,Background:Integer;
 BrightColor,OnBackground,Valid:Boolean;
Begin
 Foreground:=-1; Background:=(OriginalColor shr 4)and 7;
 BrightColor:=False; OnBackground:=False; Valid:=True;
 While S<>''do Begin
  While (Length(S)>0)and(S[1]=' ')do Delete(S,1,1);
  If S=''Then Break;
  N:=Pos(' ',S); If N=0Then N:=Length(S)+1;
  Token:=Copy(S,1,N-1); Delete(S,1,N);
  If (Token='BRIGHT')or(Token='BRI')Then BrightColor:=True Else
  If Token='ON'Then Begin OnBackground:=True; BrightColor:=False; End Else Begin
   N:=-1;
   If (Token='BLACK')or(Token='BLA')Then N:=0 Else
   If (Token='BLUE')or(Token='BLU')Then N:=1 Else
   If (Token='GREEN')or(Token='GRE')Then N:=2 Else
   If (Token='CYAN')or(Token='CYA')Then N:=3 Else
   If Token='RED'Then N:=4 Else
   If (Token='MAGENTA')or(Token='MAG')Then N:=5 Else
   If (Token='BROWN')or(Token='BRO')Then N:=6 Else
   If (Token='WHITE')or(Token='WHI')Then N:=7 Else
   If (Token='GRAY')or(Token='GREY')Then N:=8 Else
   If (Token='YELLOW')or(Token='YEL')Then N:=14;
   If N<0Then Valid:=False Else Begin
    If BrightColor Then N:=N or 8;
    If OnBackground Then Background:=N and 7 Else Foreground:=N;
   End;
   BrightColor:=False;
  End;
 End;
 ParseColor:=Valid and(Foreground>=0);
 If Valid and(Foreground>=0)Then Value:=Foreground or(Background shl 4);
End;

Function EntryColor:Byte;
Var Rules,Rule,Selectors,Token:String; N:Integer; Matches:Boolean; Value:Byte;
Begin
 EntryColor:=OriginalColor;
 If (NoColor in Option)or(OutputFormat<>_Text)Then Exit;
 Rules:=ColorRules;
 While Rules<>''do Begin
  N:=Pos(';',Rules); If N=0Then N:=Length(Rules)+1;
  Rule:=Copy(Rules,1,N-1); Delete(Rules,1,N);
  N:=Pos(':',Rule);
  If N>0Then Begin
   Selectors:=Copy(Rule,1,N-1); Delete(Rule,1,N); Matches:=False;
   While Selectors<>''do Begin
    While (Length(Selectors)>0)and(Selectors[1]=' ')do Delete(Selectors,1,1);
    N:=Pos(' ',Selectors); If N=0Then N:=Length(Selectors)+1;
    Token:=Copy(Selectors,1,N-1); Delete(Selectors,1,N);
    If Token<>''Then If ColorSelector(Token)Then Matches:=True;
   End;
   If Matches Then If ParseColor(Rule,Value)Then Begin EntryColor:=Value; Exit; End;
  End;
 End;
End;

Procedure ResetOptions;
Begin
 { Retablir les options initiales sans modifier le chemin ni la langue.
   Les parametres places apres /N seront ensuite appliques normalement. }
 Option:=[];
 Column:=[];
 RequiredAttr:=0;
 ExcludedAttr:=0;
 SortOrder:='';
 OutputFormat:=_Text;
End;

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
 Colors:Array[1..4]of Byte;
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
   Colors[Count]:=EntryColor;
   If (Info.Attr and Directory)<>0Then Sizes[Count]:='<DIR>'
   Else Str(Info.Size,Sizes[Count]);
   If Length(Names[Count])>NameWidth Then NameWidth:=Length(Names[Count]);
   If Length(Sizes[Count])>SizeWidth Then SizeWidth:=Length(Sizes[Count]);
   FindNextMatch;
  End;
  For I:=1 to Count do Begin
   If I>1Then Write('  ');
   TextAttr:=Colors[I];
   Write(PadRight(Names[I],NameWidth),' ',Sizes[I]:SizeWidth);
   TextAttr:=OriginalColor;
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

Function PageContinue:Boolean;
Begin
 PageContinue:=True;
 If Not(Pause in Option)Then Exit;
 Inc(P);
 If P<Hi(WindMax)Then Exit;
 Write('Presse une touche pour continuer...');
 PageContinue:=ReadKey<>#27;
 WriteLn;
 P:=0;
End;

Procedure ShowAttributes;
Var
 S:String;
Begin
 While DosError=0do Begin
  S:='-----';
  If (Info.Attr and ReadOnly)<>0Then S[1]:='R';
  If (Info.Attr and Hidden)<>0Then S[2]:='H';
  If (Info.Attr and SysFile)<>0Then S[3]:='S';
  If (Info.Attr and Directory)<>0Then S[4]:='D';
  If (Info.Attr and Archive)<>0Then S[5]:='A';
  TextAttr:=EntryColor;
  WriteLn(PadRight(TextDisplayName,13),' ',S);
  TextAttr:=OriginalColor;
  FindNextMatch;
  If DosError=0Then If Not PageContinue Then Exit;
 End;
End;

Procedure ShowSummary;
Begin
 TotalNumFiles:=0;
 TotalSize:=0;
 While DosError=0do Begin
  { Les dossiers ne sont pas comptes comme des fichiers. }
  If (Info.Attr and Directory)=0Then Begin
   Inc(TotalNumFiles);
   Inc(TotalSize,Info.Size);
  End;
  FindNextMatch;
 End;
 Case Language of
  _Germany:WriteLn(TotalNumFiles,' Datei(en), ',TotalSize,' Byte');
  _English:WriteLn(TotalNumFiles,' file(s), ',TotalSize,' bytes');
  Else WriteLn(TotalNumFiles,' fichier(s), ',TotalSize,' octet(s)');
 End;
End;

Procedure ShowColumns;
Var
 Head,Tail,Node,NextCell:PDisplayCell;
 Starts:Array[1..5]of PDisplayCell;
 Count,Rows,Row,Step:LongInt;
 Col,Columns:Byte;
 CellWidth,Used,J,NameWidth,DetailsWidth:Integer;
 IsVertical,More:Boolean;
 SizeText,YearText:String;
Begin
 Head:=Nil;
 Tail:=Nil;
 Count:=0;
 IsVertical:=Vertical in Option;
 NameWidth:=12;
 DetailsWidth:=0;
 Columns:=2;
 If Width in Column Then Columns:=5;
 If Four in Column Then Columns:=4;
 CellWidth:=16;
 If Width in Column Then CellWidth:=14;
 { Mesurer toute la liste pour conserver les memes alignements sur chaque ligne. }
 While DosError=0do Begin
  {$IFNDEF FPC}
  If MaxAvail<SizeOf(TDisplayCell)Then Begin
   Case Language of
    _Germany:WriteLn('Nicht genug Speicher.');
    _English:WriteLn('Not enough memory.');
    Else WriteLn('M'+#130+'moire insuffisante.');
   End;
   Halt(1);
  End;
  {$ENDIF}
  New(Node);
  Node^.Name:=TextDisplayName;
  Node^.Color:=EntryColor;
  Node^.Details:='';
  Node^.Next:=Nil;
  If Not(Width in Column)Then Begin
   If (Info.Attr and Directory)<>0Then SizeText:='<DIR>'
   Else Str(Info.Size,SizeText);
   If Not(Four in Column)Then
    While Length(SizeText)<9do SizeText:=' '+SizeText;
   Node^.Details:=' '+SizeText;
   If Not(Four in Column)Then Begin
    If ShowCompression Then Node^.Details:=Node^.Details+' '+CompressionRatioText;
    UnpackTime(Info.Time,T);
    Str(T.Year,YearText);
    Node^.Details:=Node^.Details+' '+YearText+'-'+PadZeroLeft(T.Month,2)+'-'+
     PadZeroLeft(T.Day,2)+' '+PadZeroLeft(T.Hour,2)+':'+PadZeroLeft(T.Min,2);
   End;
  End;
  Used:=Length(Node^.Name)+Length(Node^.Details);
  If Length(Node^.Name)>NameWidth Then NameWidth:=Length(Node^.Name);
  If Length(Node^.Details)>DetailsWidth Then DetailsWidth:=Length(Node^.Details);
  If Used>CellWidth Then CellWidth:=Used;
  If Head=Nil Then Head:=Node Else Tail^.Next:=Node;
  Tail:=Node;
  Inc(Count);
  FindNextMatch;
 End;
 If Not(Width in Column)and Not(Four in Column)Then
  CellWidth:=NameWidth+DetailsWidth;
 Rows:=Count div Columns;
 If (Count mod Columns)<>0Then Inc(Rows);
 Node:=Head;
 For Col:=1 to Columns do Begin
  Starts[Col]:=Node;
  For Step:=1 to Rows do If Node<>Nil Then Node:=Node^.Next;
 End;
 Node:=Head;
 For Row:=1 to Rows do Begin
  For Col:=1 to Columns do Begin
   If IsVertical Then Node:=Starts[Col];
   If Node<>Nil Then Begin
    If Col>1Then Write('  ');
    TextAttr:=Node^.Color;
    Used:=Length(Node^.Name)+Length(Node^.Details);
    If Not(Width in Column)and Not(Four in Column)Then Begin
     Write(PadRight(Node^.Name,NameWidth),Node^.Details);
     Used:=NameWidth+Length(Node^.Details);
    End Else Write(Node^.Name,Node^.Details);
    TextAttr:=OriginalColor;
    More:=False;
    If Col<Columns Then Begin
     If IsVertical Then More:=Starts[Col+1]<>Nil Else More:=Node^.Next<>Nil;
    End;
    If More Then For J:=Used+1 to CellWidth do Write(' ');
    If IsVertical Then Starts[Col]:=Node^.Next Else Node:=Node^.Next;
    { La derniere ligne peut etre incomplete dans la derniere colonne. }
    If Row=Rows Then Starts[Col]:=Nil;
   End;
  End;
  WriteLn;
  If Row<Rows Then If Not PageContinue Then Break;
 End;
 While Head<>Nil do Begin
  NextCell:=Head^.Next;
  Dispose(Head);
  Head:=NextCell;
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
 OriginalColor:=TextAttr;
 ColorRules:=StrToUpper(GetEnv('COLORDIR'));
 If ColorRules=''Then
  ColorRules:='DIRS:BRIGHT BLUE;EXE COM BAT BTM:BRIGHT GREEN;INI TXT:BRIGHT MAGENTA';
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain;
 End;
 ResetOptions;
 P:=0;
 Entries:=Nil;
 CurrentEntry:=Nil;
 EntriesLoaded:=False;
 PendingDirs:=Nil;
 ShowDir:='*.*';
 Repeat
  Inc(P);
  CurrParam:=ParamStr(P);
 If Length(CurrParam)=0Then Break;
  If CurrParam='/?'Then Begin
  Case Language of
    _Germany:Begin
     WriteLn('Listet die Dateien und Unterverzeichnisse eines Verzeichnisses auf.');
     WriteLn;
     WriteLn('Format:   DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/M] [/N] [/P] [/S] ',
             '[/T] [/U] [/V] [/A[[:]Attribute]] [/O[[:]Folge]] [Pfad] [/FORMAT:format]');
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
     WriteLn(' COLORDIR         Farben: DIRS, HIDDEN, SYSTEM, RDONLY, ARCHIVE, NORMAL oder Erweiterungen');
     WriteLn(' /F               Vollst'+#132+'ndige Dateinamen mit Pfad anzeigen');
     WriteLn(' /J               Dateinamen und Erweiterungen getrennt ausrichten');
     WriteLn(' /K               Kopfzeilen ausblenden, Summen beibehalten');
     WriteLn(' /M               Fusszeilen mit Dateianzahl und Speicherplatz ausblenden');
     WriteLn(' /N               Bisherige Optionen auf die Standardwerte zur'+#129+'cksetzen');
     WriteLn(' /T               Nur Namen und Attribute anzeigen (R H S D A)');
     WriteLn(' /U               Nur Dateianzahl und belegte Bytes anzeigen');
     WriteLn(' /V               Spalten senkrecht f'+#129+'llen, mit /2, /4 oder /W');
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
     WriteLn('Format:   DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/M] [/N] [/P] [/S] ',
             '[/T] [/U] [/V] [/A[[:]attributes]] [/O[[:]order]] [path] [/FORMAT:format]');
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
     WriteLn(' COLORDIR         Colors: DIRS, HIDDEN, SYSTEM, RDONLY, ARCHIVE, NORMAL or extensions');
     WriteLn(' /F               Display full filenames including their paths');
     WriteLn(' /J               Align filenames and extensions separately');
     WriteLn(' /K               Suppress headers, retaining totals');
     WriteLn(' /M               Suppress footer information and totals');
     WriteLn(' /N               Reset preceding options to their defaults');
     WriteLn(' /T               Display only names and attributes (R H S D A)');
     WriteLn(' /U               Display only file count and bytes used');
     WriteLn(' /V               Fill columns vertically with /2, /4 or /W');
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
     WriteLn('DIR [/?] [/1|/2|/4|/W] [/B] [/C] [/D] [/F] [/J] [/K] [/L] [/M] [/N] [/P] [/S] ',
             '[/T] [/U] [/V] [/A[[:]attributs]] [/O[[:]ordretri]] [chemin] [/FORMAT:format]');
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
     WriteLn(' COLORDIR         Couleurs: DIRS, HIDDEN, SYSTEM, RDONLY, ARCHIVE, NORMAL ou extensions');
     WriteLn(' /F               Affiche les noms complets avec leur chemin');
     WriteLn(' /FORMAT:format   Ce param'+#138+'tre permet d''indiquer CSV, HTML, Json, PASCAL, SQL ou XML');     
     WriteLn(' /J               Aligne s'+#130+'par'+#130+'ment les noms et les extensions');
     WriteLn(' /K               Masque les ent'+#136+'tes et conserve les totaux');
     WriteLn(' /L               Affiche les noms des fichiers et r'+#130+'pertoires en minuscules');
     WriteLn(' /M               Masque le bas de page : totaux et espace libre');
     WriteLn(' /N               R'+#130+'initialise les options pr'+#130+'c'+#130+'dentes aux valeurs par d'+#130+'faut');
     WriteLn(' /O[[:]ordretri]  C=Taux de compression D=Date/heure E=Extension');
     WriteLn('                  G=R'+#130+'pertoires en premier N=Nom S=Taille');
     WriteLn('                  Ordre croissant; - inverse le crit'+#138+'re suivant');
     WriteLn('                  /O = GN; crit'+#138+'res combinables, ex. /O:G-S');
     WriteLn('                  C : octets '+#130+'conomis'+#130+'s (%), Windows / MS-DOS 7+');
     WriteLn('                  Syst'+#138+'mes non pris en charge : 0');
     WriteLn(' /P               Ce param'+#138+'tre affiche une pause apres l''affichage d''une page pleine');
     WriteLn(' /S               Ce param'+#138+'tre affiche les fichiers du dossier et de tous ses sous-dossiers');
     WriteLn(' /T               Affiche uniquement les noms et attributs (R H S D A)');
     WriteLn(' /U               Affiche uniquement le nombre de fichiers et les octets utilis'+#130+'s');
     WriteLn(' /V               Remplit les colonnes verticalement avec /2, /4 ou /W');     
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
  If(CurrParam='/M')or(CurrParam='/m')Then Include(Option,NoFooter) Else
  If(CurrParam='/N')or(CurrParam='/n')Then ResetOptions Else
  If(CurrParam='/P')or(CurrParam='/p')Then Include(Option,Pause) Else
  If(CurrParam='/S')or(CurrParam='/s')Then Include(Option,Subdirectory) Else
  If(CurrParam='/T')or(CurrParam='/t')Then Include(Option,AttributesOnly) Else
  If(CurrParam='/U')or(CurrParam='/u')Then Include(Option,SummaryOnly) Else
  If(CurrParam='/V')or(CurrParam='/v')Then Include(Option,Vertical) Else
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
 If (Description in Option)or(Four in Column)or(AttributesOnly in Option)or
    (SummaryOnly in Option)or((Vertical in Option)and(Column<>[]))Then Begin
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
   If SummaryOnly in Option Then ShowSummary Else
   If AttributesOnly in Option Then ShowAttributes Else
   If(Vertical in Option)and(Column<>[])Then ShowColumns Else
   If((Subdirectory in Option)or(FullPath in Option))and(Brief in Option)and
     Not(Description in Option)Then While DosError=0do Begin
    TextAttr:=EntryColor;
    WriteLn(DisplayName);
    TextAttr:=OriginalColor;
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
    TextAttr:=EntryColor;
    Write(PadRight(TextDisplayName,16));
    TextAttr:=OriginalColor;
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
   If Double in Column Then ShowColumns Else
   Begin
    { Mesurer les noms affiches, chemins compris, avant de tracer les colonnes. }
    ListingNameWidth:=12;
    While DosError=0do Begin
     If Length(TextDisplayName)>ListingNameWidth Then
      ListingNameWidth:=Length(TextDisplayName);
     FindNextMatch;
    End;
    FindFirstMatch;
    TotalNumFiles:=0;
    TotalSize:=0;
    If Not(Brief in Option)and Not(NoHeader in Option)Then Begin
     Inc(P,2);
     WriteLn('Le volume de l''unite '+CurrDrive+' est '+CurrLabel);
     WriteLn;
    End;
    While DOSError=0 do Begin
     TextAttr:=EntryColor;
     Write(PadRight(TextDisplayName,ListingNameWidth),' ');
     If Info.Attr and Directory=Directory Then Begin
      Write(PadRight('<DIR>',15));
     End
      Else
     Write(Info.Size:15);
     If ShowCompression Then Write(' ',CompressionRatioText:8);
     UnpackTime(Info.Time,T);
     Write(' ',T.Year:4,'-',PadZeroLeft(T.Month,2),'-',PadZeroLeft(T.Day,2),' ',T.Hour:2,':',PadZeroLeft(T.Min,2));
     If Description in Option Then WriteFileDescription;
     TextAttr:=OriginalColor;
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
    If Not(Brief in Option)and Not(NoFooter in Option)Then Begin
     WriteLn(' Les ',TotalNumFiles,' fichier(s) utilisent ',TotalSize,' octet(s)');
     WriteLn(DiskFree(Byte(CurrDrive)-64):10,' octet(s) de libre');
    End;
   End;
  End;
 End;
 FreeEntries;
 FreePendingDirs;
END.
