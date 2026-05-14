{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de la commande HC.EXE de Microsoft Help Compiler.
                Compile un projet .HPJ et ses sources .RTF en un fichier
                d'aide Windows .HLP au format WinHelp 3.x.
  @license: MIT
}

Program HC;

{$A-}
{$Q-}
{$R-}

Uses DOS;

Const
 HC_VERSION = '1.00';
 HC_MAGIC   : LongInt = $00035F3F;   { Magic WinHelp .HLP }
 SYS_MAGIC  = $036C;                 { Magic du fichier interne |SYSTEM }

 MAX_FILES    = 256;                 { Fichiers RTF references }
 MAX_TOPICS   = 4096;                { Topics globaux }
 MAX_MAP      = 4096;                { Entrees [MAP] }
 MAX_ALIAS    = 1024;                { Entrees [ALIAS] }
 MAX_BITMAPS  = 256;                 { Entrees [BITMAPS] }
 MAX_WINDOWS  = 64;                  { Fenetres secondaires }
 MAX_CONFIG   = 256;                 { Macros [CONFIG] }
 MAX_KEYS     = 8192;                { Mots-cles globaux }

 { Codes d'erreur HC (compatibles esprit Microsoft) }
 ERR_HPJ_NOTFOUND   = 1001;
 ERR_RTF_NOTFOUND   = 1002;
 ERR_BAD_SECTION    = 1003;
 ERR_BAD_OPTION     = 1004;
 ERR_DUP_CONTEXT    = 1005;
 ERR_BAD_MAP        = 1006;
 ERR_NO_FILES       = 1007;
 ERR_BAD_RTF        = 1008;
 ERR_WRITE          = 1009;

Type
 TStr80   = String[80];
 TStr255  = String[255];

 { Description d'un fichier RTF reference dans [FILES] }
 TRtfFile = Record
  Name      : TStr80;        { Nom du fichier RTF }
  FullPath  : TStr255;       { Chemin complet resolu }
  Exists    : Boolean;       { True si le fichier a ete trouve }
  TopicCnt  : Integer;       { Nombre de topics decouverts }
  ByteSize  : LongInt;       { Taille en octets }
 End;

 { Description d'un topic decouvert dans un RTF }
 TTopic = Record
  Context   : TStr80;        { Contexte # (peut etre vide) }
  Title     : TStr80;        { Titre $ (peut etre vide) }
  Browse    : TStr80;        { Sequence + }
  BuildTag  : TStr80;        { Tag * }
  FileIdx   : Integer;       { Index dans la table des fichiers }
  Offset    : LongInt;       { Position dans le |TOPIC genere }
  Size      : LongInt;       { Taille du contenu RTF }
  KeyStart  : Integer;       { Premier mot-cle (index dans Keywords) }
  KeyCount  : Integer;       { Nombre de mots-cles K }
 End;

 { Entree [MAP] : symbole numerique vers contexte }
 TMapEntry = Record
  Name      : TStr80;        { Nom symbolique (ex: IDH_INDEX) }
  Value     : LongInt;       { Valeur numerique }
  Resolved  : Boolean;       { True si reference un topic existant }
 End;

 { Entree [ALIAS] }
 TAliasEntry = Record
  Source    : TStr80;
  Target    : TStr80;
 End;

 { Mot-cle K }
 TKeyword = Record
  Text      : TStr80;        { Mot-cle }
  TopicIdx  : Integer;       { Topic associe }
 End;

 { En-tete .HLP }
 THelpHeader = Record
  Magic     : LongInt;       { 0x00035F3F }
  DirStart  : LongInt;       { Offset de l'en-tete du fichier interne 'directory' }
  FreeChain : LongInt;       { -1 si aucun bloc libre }
  EOFOfs    : LongInt;       { Taille totale du fichier }
 End;

 { En-tete d'un fichier interne dans le container WinHelp }
 TFileHeader = Record
  ReservedSpace : LongInt;   { Espace reserve (taille des donnees + 9) }
  UsedSpace     : LongInt;   { Espace utilise par les donnees }
  FileFlags     : Byte;      { 4 = en lecture seule normal }
 End;

 { En-tete d'une page B-tree }
 TBTreeHeader = Record
  Magic         : Word;      { 0x293B }
  Flags         : Word;      { 0x0402 = directory file }
  PageSize      : Word;      { 0x0400 = 1024 }
  Structure     : Array[1..16] Of Char; { Description structure (ex: 'Fz4') }
  MustBeZero    : Word;
  PageSplits    : Word;
  RootPage      : Word;
  MustBeNegOne  : Word;      { 0xFFFF }
  TotalPages    : Word;
  NLevels       : Word;
  TotalEntries  : LongInt;
 End;

Var
 { ----- Options en ligne de commande ----- }
 OptCompileAll  : Boolean;   { /A : compiler tous les topics }
 OptCleanTmp    : Boolean;   { /C : supprimer fichiers temporaires }
 OptStopOnError : Boolean;   { /E : arret a la premiere erreur }
 OptMakeLog     : Boolean;   { /L : generer un fichier .LOG }
 OptMoreInfo    : Boolean;   { /M : informations supplementaires }
 OptNoCompress  : Boolean;   { /N : pas de compression }
 OptKeepTmp     : Boolean;   { /P : conserver les fichiers intermediaires }
 OptQuiet       : Boolean;   { /Q : mode silencieux }
 OptStats       : Boolean;   { /T : statistiques de compilation }
 OptVerbose     : Boolean;   { /V : mode verbeux }

 { ----- Fichiers et chemins ----- }
 HpjPath        : TStr255;
 HpjDir         : TStr255;
 HlpPath        : TStr255;
 LogPath        : TStr255;
 ErrPath        : TStr255;

 { ----- Sortie ----- }
 LogF           : Text;
 LogOpen        : Boolean;
 ErrF           : Text;
 ErrOpen        : Boolean;
 HlpF           : File;
 HlpOpen        : Boolean;

 { ----- Donnees du projet ----- }
 ProjTitle      : TStr255;
 ProjCopyright  : TStr255;
 ProjCompress   : Boolean;
 ProjContents   : TStr80;
 ProjReport     : Boolean;
 ProjWarn       : Integer;   { Niveau warning (1..3) }
 ProjLang       : LongInt;
 ProjOldKey     : Boolean;
 ProjBmRoot     : TStr255;
 ProjRoot       : TStr255;
 ProjIcon       : TStr80;

 RtfFiles       : Array[1..MAX_FILES]   Of TRtfFile;
 NumRtfFiles    : Integer;

 Topics         : Array[1..MAX_TOPICS]  Of TTopic;
 NumTopics      : Integer;

 MapEntries     : Array[1..MAX_MAP]     Of TMapEntry;
 NumMapEntries  : Integer;

 Aliases        : Array[1..MAX_ALIAS]   Of TAliasEntry;
 NumAliases     : Integer;

 BitmapPaths    : Array[1..MAX_BITMAPS] Of TStr255;
 NumBitmaps     : Integer;

 ConfigMacros   : Array[1..MAX_CONFIG]  Of TStr255;
 NumConfig      : Integer;

 Keywords       : Array[1..MAX_KEYS]    Of TKeyword;
 NumKeywords    : Integer;

 { ----- Compteurs et statistiques ----- }
 ErrorCount     : Integer;
 WarnCount      : Integer;
 CtxResolved    : Integer;
 CtxUnresolved  : Integer;
 TotalRtfBytes  : LongInt;
 OutputBytes    : LongInt;
 TopicRawBytes  : LongInt;   { Taille |TOPIC avant compression }
 TopicCompBytes : LongInt;   { Taille |TOPIC apres compression }
 CompressUsed   : Boolean;   { True si LZ77 reellement applique }
 StartTimeHi    : Word;
 StartTimeLo    : Word;
 StartDateLo    : Word;
 StartDateHi    : Word;
 StartTicks     : LongInt;

{ ============================================================
  UTILITAIRES GENERIQUES
  ============================================================ }

Function UpStr(Const S:TStr255):TStr255;
Var I:Integer; R:TStr255;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  If(R[I]>='a')And(R[I]<='z')Then R[I]:=Chr(Ord(R[I])-32);
 UpStr:=R;
End;

Function Trim(Const S:TStr255):TStr255;
Var I,J:Integer;
Begin
 I:=1;
 While(I<=Length(S))And(S[I] In [' ',#9,#13,#10])Do Inc(I);
 J:=Length(S);
 While(J>=I)And(S[J] In [' ',#9,#13,#10])Do Dec(J);
 If J<I Then Trim:='' Else Trim:=Copy(S,I,J-I+1);
End;

Function StrToInt(Const S:TStr255;Var OK:Boolean):LongInt;
Var V,Sign:LongInt; I:Integer; T:TStr255;
Begin
 T:=Trim(S); V:=0; Sign:=1; OK:=False;
 If T='' Then Begin StrToInt:=0; Exit; End;
 I:=1;
 If T[I]='-' Then Begin Sign:=-1; Inc(I); End
 Else If T[I]='+' Then Inc(I);
 If(I<=Length(T))And(T[I]='$')Then Begin
  Inc(I);
  While I<=Length(T) Do Begin
   Case T[I] Of
    '0'..'9': V:=V*16+Ord(T[I])-Ord('0');
    'A'..'F': V:=V*16+Ord(T[I])-Ord('A')+10;
    'a'..'f': V:=V*16+Ord(T[I])-Ord('a')+10;
   Else
    Begin StrToInt:=0; Exit; End;
   End;
   Inc(I);
  End;
  OK:=True; StrToInt:=V*Sign; Exit;
 End;
 While I<=Length(T) Do Begin
  If(T[I]<'0')Or(T[I]>'9')Then Begin StrToInt:=0; Exit; End;
  V:=V*10+Ord(T[I])-Ord('0');
  Inc(I);
 End;
 OK:=True;
 StrToInt:=V*Sign;
End;

Function IntToStr(N:LongInt):TStr80;
Var S:TStr80;
Begin
 Str(N,S);
 IntToStr:=S;
End;

Function ExtractFileDir(Const Path:TStr255):TStr255;
Var I:Integer;
Begin
 For I:=Length(Path) DownTo 1 Do
  If(Path[I]='\')Or(Path[I]='/')Or(Path[I]=':')Then Begin
   ExtractFileDir:=Copy(Path,1,I);
   Exit;
  End;
 ExtractFileDir:='';
End;

Function ExtractFileName(Const Path:TStr255):TStr255;
Var I:Integer;
Begin
 For I:=Length(Path) DownTo 1 Do
  If(Path[I]='\')Or(Path[I]='/')Or(Path[I]=':')Then Begin
   ExtractFileName:=Copy(Path,I+1,Length(Path)-I);
   Exit;
  End;
 ExtractFileName:=Path;
End;

Function ChangeExt(Const Path:TStr255;Const NewExt:TStr80):TStr255;
Var I,DotPos,SlashPos:Integer;
Begin
 DotPos:=0; SlashPos:=0;
 For I:=Length(Path) DownTo 1 Do Begin
  If(Path[I]='\')Or(Path[I]='/')Or(Path[I]=':')Then Begin
   SlashPos:=I; Break;
  End;
  If(Path[I]='.')And(DotPos=0)Then DotPos:=I;
 End;
 If(DotPos=0)Or(DotPos<SlashPos)Then
  ChangeExt:=Path+NewExt
 Else
  ChangeExt:=Copy(Path,1,DotPos-1)+NewExt;
End;

Function FileExists(Const Path:TStr255):Boolean;
Var F:File; OldFM:Byte;
Begin
 OldFM:=FileMode; FileMode:=0;
 Assign(F,Path);
 {$I-} Reset(F,1); {$I+}
 If IOResult=0 Then Begin
  Close(F);
  FileMode:=OldFM;
  FileExists:=True;
 End Else Begin
  FileMode:=OldFM;
  FileExists:=False;
 End;
End;

Function ResolvePath(Const Name:TStr255;Const BaseDir:TStr255):TStr255;
Var Try1:TStr255;
Begin
 If FileExists(Name) Then Begin ResolvePath:=Name; Exit; End;
 Try1:=BaseDir+Name;
 If FileExists(Try1) Then Begin ResolvePath:=Try1; Exit; End;
 If(ProjRoot<>'')Then Begin
  Try1:=ProjRoot+Name;
  If FileExists(Try1) Then Begin ResolvePath:=Try1; Exit; End;
 End;
 ResolvePath:=Name;
End;

{ ============================================================
  GESTION DES MESSAGES / LOG / ERREURS
  ============================================================ }

Procedure Emit(Const S:TStr255);
Begin
 If Not OptQuiet Then WriteLn(S);
 If LogOpen Then WriteLn(LogF,S);
End;

Procedure EmitVerbose(Const S:TStr255);
Begin
 If OptVerbose Or OptMoreInfo Then Emit(S);
End;

Procedure EmitWarning(Code:Integer;Const Msg:TStr255);
Var S:TStr255;
Begin
 Inc(WarnCount);
 S:='HC W'+IntToStr(Code)+': '+Msg;
 WriteLn(S);
 If LogOpen Then WriteLn(LogF,S);
 If ErrOpen Then WriteLn(ErrF,S);
End;

Procedure EmitError(Code:Integer;Const Msg:TStr255);
Var S:TStr255;
Begin
 Inc(ErrorCount);
 S:='HC E'+IntToStr(Code)+': '+Msg;
 WriteLn(S);
 If LogOpen Then WriteLn(LogF,S);
 If ErrOpen Then WriteLn(ErrF,S);
 If OptStopOnError Then Begin
  WriteLn('HC : compilation interrompue (/E).');
  If LogOpen Then Close(LogF);
  If ErrOpen Then Close(ErrF);
  If HlpOpen Then Close(HlpF);
  Halt(2);
 End;
End;

Procedure OpenLogs;
Begin
 If OptMakeLog Then Begin
  Assign(LogF,LogPath);
  {$I-} Rewrite(LogF); {$I+}
  If IOResult=0 Then Begin
   LogOpen:=True;
   WriteLn(LogF,'Microsoft Help Compiler clone (HC) v',HC_VERSION);
   WriteLn(LogF,'Projet: ',HpjPath);
   WriteLn(LogF,'-----------------------------------------');
  End;
 End;
 Assign(ErrF,ErrPath);
 {$I-} Rewrite(ErrF); {$I+}
 If IOResult=0 Then ErrOpen:=True;
End;

Procedure CloseLogs;
Begin
 If LogOpen Then Begin
  WriteLn(LogF,'-----------------------------------------');
  WriteLn(LogF,'Erreurs: ',ErrorCount,'  Avertissements: ',WarnCount);
  Close(LogF);
  LogOpen:=False;
 End;
 If ErrOpen Then Begin
  Close(ErrF);
  ErrOpen:=False;
  { Effacer .ERR si vide et qu'il n'y a pas eu d'erreur }
  If(ErrorCount=0)And(WarnCount=0)Then Begin
   Assign(ErrF,ErrPath);
   {$I-} Erase(ErrF); {$I+}
   If IOResult<>0 Then; { ignore }
  End;
 End;
End;

{ ============================================================
  TIMING ET STATISTIQUES
  ============================================================ }

Procedure GetNowTicks(Var Ticks:LongInt);
Var H,M,S,Sec100:Word;
Begin
 GetTime(H,M,S,Sec100);
 Ticks:=LongInt(H)*360000+LongInt(M)*6000+LongInt(S)*100+Sec100;
End;

Function ElapsedSeconds:Real;
Var Now:LongInt;
Begin
 GetNowTicks(Now);
 If Now<StartTicks Then Now:=Now+LongInt(24)*360000;
 ElapsedSeconds:=(Now-StartTicks)/100.0;
End;

Function DosNow:LongInt;
Var Y,Mo,D,DOW,H,Mi,S,SS:Word;
    R:LongInt;
Begin
 GetDate(Y,Mo,D,DOW);
 GetTime(H,Mi,S,SS);
 { Encodage time_t simplifie : secondes depuis 1980-01-01 }
 R:=(LongInt(Y)-1980)*31536000;
 R:=R+(LongInt(Mo)-1)*2592000;
 R:=R+(LongInt(D)-1)*86400;
 R:=R+LongInt(H)*3600+LongInt(Mi)*60+S;
 DosNow:=R;
End;

{ ============================================================
  PARSEUR DE FICHIER .HPJ (format INI)
  ============================================================ }

Function StripComment(Const Line:TStr255):TStr255;
Var I:Integer;
Begin
 For I:=1 To Length(Line) Do
  If Line[I]=';' Then Begin
   StripComment:=Copy(Line,1,I-1);
   Exit;
  End;
 StripComment:=Line;
End;

Procedure SplitKV(Const Line:TStr255;Var Key,Val:TStr255);
Var I,P:Integer;
Begin
 P:=0;
 For I:=1 To Length(Line) Do
  If Line[I]='=' Then Begin P:=I; Break; End;
 If P=0 Then Begin
  Key:=Trim(Line);
  Val:='';
 End Else Begin
  Key:=Trim(Copy(Line,1,P-1));
  Val:=Trim(Copy(Line,P+1,Length(Line)-P));
 End;
End;

Procedure HandleOptions(Const Key,Val:TStr255);
Var U:TStr255; OK:Boolean; V:LongInt;
Begin
 U:=UpStr(Key);
 If U='TITLE' Then ProjTitle:=Val
 Else If U='COPYRIGHT' Then ProjCopyright:=Val
 Else If U='COMPRESS' Then ProjCompress:=(UpStr(Val)='TRUE')Or(UpStr(Val)='YES')Or(Val='1')Or(UpStr(Val)='HIGH')Or(UpStr(Val)='MEDIUM')
 Else If U='CONTENTS' Then ProjContents:=Val
 Else If U='REPORT' Then ProjReport:=(UpStr(Val)='ON')Or(UpStr(Val)='YES')Or(Val='1')
 Else If U='WARNING' Then Begin
  V:=StrToInt(Val,OK);
  If OK Then ProjWarn:=V Else EmitWarning(1100,'WARNING= valeur invalide: '+Val);
 End
 Else If U='LANGUAGE' Then ProjLang:=StrToInt(Val,OK)
 Else If U='OLDKEYPHRASE' Then ProjOldKey:=(UpStr(Val)='YES')Or(Val='1')
 Else If U='BMROOT' Then ProjBmRoot:=Val
 Else If U='ROOT' Then ProjRoot:=Val
 Else If U='ICON' Then ProjIcon:=Val
 Else If(U='ERRORLOG')Or(U='HLP')Or(U='OPTCDROM')Or(U='MAPFONTSIZE')Or
        (U='REPLACE')Or(U='FORCEFONT')Or(U='MULTIKEY')Or(U='CITATION')Or
        (U='CNT')Then { reconnu, valeur conservee globalement non requise }
 Else
  EmitWarning(1101,'Option [OPTIONS] inconnue: '+Key);
End;

Procedure HandleFiles(Const Line:TStr255);
Var Name:TStr255;
Begin
 Name:=Trim(Line);
 If Name='' Then Exit;
 If NumRtfFiles>=MAX_FILES Then Begin
  EmitError(ERR_BAD_SECTION,'Trop de fichiers dans [FILES]');
  Exit;
 End;
 Inc(NumRtfFiles);
 RtfFiles[NumRtfFiles].Name:=Name;
 RtfFiles[NumRtfFiles].FullPath:=ResolvePath(Name,HpjDir);
 RtfFiles[NumRtfFiles].Exists:=FileExists(RtfFiles[NumRtfFiles].FullPath);
 RtfFiles[NumRtfFiles].TopicCnt:=0;
 RtfFiles[NumRtfFiles].ByteSize:=0;
 If Not RtfFiles[NumRtfFiles].Exists Then
  EmitError(ERR_RTF_NOTFOUND,'Fichier RTF introuvable: '+Name);
End;

Procedure HandleMap(Const Line:TStr255);
Var Key,Val:TStr255; OK:Boolean; V:LongInt; I:Integer;
Begin
 SplitKV(Line,Key,Val);
 If(Key='')Or(Val='')Then Exit;
 V:=StrToInt(Val,OK);
 If Not OK Then Begin
  EmitError(ERR_BAD_MAP,'Valeur [MAP] invalide pour '+Key+': '+Val);
  Exit;
 End;
 For I:=1 To NumMapEntries Do
  If UpStr(MapEntries[I].Name)=UpStr(Key) Then Begin
   EmitWarning(ERR_DUP_CONTEXT,'Contexte duplique dans [MAP]: '+Key);
   MapEntries[I].Value:=V;
   Exit;
  End;
 If NumMapEntries>=MAX_MAP Then Begin
  EmitError(ERR_BAD_MAP,'Trop d''entrees dans [MAP]');
  Exit;
 End;
 Inc(NumMapEntries);
 MapEntries[NumMapEntries].Name:=Key;
 MapEntries[NumMapEntries].Value:=V;
 MapEntries[NumMapEntries].Resolved:=False;
End;

Procedure HandleAlias(Const Line:TStr255);
Var Key,Val:TStr255;
Begin
 SplitKV(Line,Key,Val);
 If(Key='')Or(Val='')Then Exit;
 If NumAliases>=MAX_ALIAS Then Exit;
 Inc(NumAliases);
 Aliases[NumAliases].Source:=Key;
 Aliases[NumAliases].Target:=Val;
End;

Procedure HandleBitmaps(Const Line:TStr255);
Begin
 If NumBitmaps>=MAX_BITMAPS Then Exit;
 Inc(NumBitmaps);
 BitmapPaths[NumBitmaps]:=ResolvePath(Trim(Line),HpjDir);
 If Not FileExists(BitmapPaths[NumBitmaps]) Then
  EmitWarning(1200,'Bitmap introuvable: '+Line);
End;

Procedure HandleConfig(Const Line:TStr255);
Begin
 If NumConfig>=MAX_CONFIG Then Exit;
 Inc(NumConfig);
 ConfigMacros[NumConfig]:=Trim(Line);
End;

Procedure ReadHPJ(Const Path:TStr255);
Var F:Text; Line,Raw:TStr255; Section:TStr80; SecU:TStr80;
    P:Integer;
Begin
 EmitVerbose('Lecture du projet '+Path+'...');
 Assign(F,Path);
 {$I-} Reset(F); {$I+}
 If IOResult<>0 Then Begin
  EmitError(ERR_HPJ_NOTFOUND,'Impossible d''ouvrir le projet: '+Path);
  Halt(2);
 End;
 Section:=''; SecU:='';
 While Not Eof(F) Do Begin
  ReadLn(F,Raw);
  Line:=Trim(StripComment(Raw));
  If Line='' Then Continue;
  If(Line[1]='[')And(Line[Length(Line)]=']')Then Begin
   Section:=Copy(Line,2,Length(Line)-2);
   SecU:=UpStr(Section);
   EmitVerbose('  Section ['+Section+']');
   Continue;
  End;
  If SecU='OPTIONS' Then Begin
   SplitKV(Line,Raw,Line);  { reuse: Raw=key, Line=val }
   HandleOptions(Raw,Line);
  End
  Else If SecU='FILES' Then HandleFiles(Line)
  Else If SecU='MAP' Then HandleMap(Line)
  Else If SecU='ALIAS' Then HandleAlias(Line)
  Else If SecU='BITMAPS' Then HandleBitmaps(Line)
  Else If SecU='CONFIG' Then HandleConfig(Line)
  Else If SecU='WINDOWS' Then  { reconnu, ignore pour ce clone }
  Else If SecU='BAGGAGE' Then  { reconnu, ignore }
  Else If SecU='' Then
   EmitWarning(ERR_BAD_SECTION,'Donnees hors-section ignorees: '+Line)
  Else
   EmitWarning(ERR_BAD_SECTION,'Section inconnue ['+Section+']');
 End;
 Close(F);
 EmitVerbose('Projet lu: '+IntToStr(NumRtfFiles)+' fichier(s), '+
             IntToStr(NumMapEntries)+' map(s).');
End;

{ ============================================================
  SCANNEUR RTF : extraction des topics et footnotes
  ============================================================ }

{ Format Word/WinHelp :
    Chaque topic commence par un footnote special :
      \footnote # ContextString    -> contexte
      \footnote $ TitleString      -> titre
      \footnote K Keyword1;Keyword2 -> mots-cles
      \footnote + BrowseSeq        -> sequence parcours
      \footnote * BuildTag         -> tag de build
    Les topics sont separes par \page                            }

Procedure AddTopic(Var T:TTopic);
Begin
 If NumTopics>=MAX_TOPICS Then Begin
  EmitError(ERR_BAD_RTF,'Trop de topics (>'+IntToStr(MAX_TOPICS)+')');
  Exit;
 End;
 Inc(NumTopics);
 Topics[NumTopics]:=T;
End;

Procedure ResetTopic(Var T:TTopic;FileIdx:Integer);
Begin
 T.Context:=''; T.Title:=''; T.Browse:=''; T.BuildTag:='';
 T.FileIdx:=FileIdx; T.Offset:=0; T.Size:=0;
 T.KeyStart:=NumKeywords+1; T.KeyCount:=0;
End;

Procedure AddKeywordList(Var T:TTopic;Const List:TStr255);
Var I,J:Integer; S:TStr255;
Begin
 I:=1; J:=1;
 S:='';
 While I<=Length(List)+1 Do Begin
  If(I>Length(List))Or(List[I]=';')Then Begin
   S:=Trim(S);
   If(S<>'')And(NumKeywords<MAX_KEYS)Then Begin
    Inc(NumKeywords);
    Keywords[NumKeywords].Text:=S;
    Keywords[NumKeywords].TopicIdx:=NumTopics+1; { topic en cours, sera ajoute apres }
    Inc(T.KeyCount);
   End;
   S:='';
  End Else
   S:=S+List[I];
  Inc(I);
 End;
End;

(* Recupere le texte d'un footnote RTF jusqu'au '}' fermant equilibre.
   ConsumedBytes recoit le nombre exact d'octets lus depuis F. *)
Function ReadGroup(Var F:Text;Var ConsumedBytes:LongInt):TStr255;
Var Ch:Char; Depth:Integer; R:TStr255;
Begin
 R:=''; Depth:=1; ConsumedBytes:=0;
 While(Not Eof(F))And(Depth>0)Do Begin
  Read(F,Ch); Inc(ConsumedBytes);
  If Ch='\' Then Begin
   { ignorer la sequence de controle }
   If Not Eof(F) Then Begin
    Read(F,Ch); Inc(ConsumedBytes);
    If(Ch>='a')And(Ch<='z')Then
     While(Not Eof(F))And(((Ch>='a')And(Ch<='z'))Or((Ch>='0')And(Ch<='9'))Or(Ch='-'))Do Begin
      Read(F,Ch); Inc(ConsumedBytes);
     End;
    If Ch=' ' Then { delim consumed }
    Else Begin
     If Ch='{' Then Inc(Depth)
     Else If Ch='}' Then Dec(Depth)
     Else If(Ch<>#13)And(Ch<>#10)Then R:=R+Ch;
    End;
   End;
  End
  Else If Ch='{' Then Inc(Depth)
  Else If Ch='}' Then Dec(Depth)
  Else If(Ch<>#13)And(Ch<>#10)Then
   If Length(R)<250 Then R:=R+Ch;
 End;
 ReadGroup:=Trim(R);
End;

Procedure ScanRTF(FileIdx:Integer);
Var F:Text; Ch,Nx:Char; Buf:TStr80; HasTopic:Boolean;
    T:TTopic; FN:Char; Body:TStr255;
    Sz,GroupBytes:LongInt;
Begin
 If Not RtfFiles[FileIdx].Exists Then Exit;
 EmitVerbose('Scan: '+RtfFiles[FileIdx].Name);
 Assign(F,RtfFiles[FileIdx].FullPath);
 {$I-} Reset(F); {$I+}
 If IOResult<>0 Then Begin
  EmitError(ERR_RTF_NOTFOUND,'Echec ouverture RTF: '+RtfFiles[FileIdx].Name);
  Exit;
 End;
 HasTopic:=False;
 ResetTopic(T,FileIdx);
 T.Offset:=OutputBytes;
 Sz:=0;
 While Not Eof(F) Do Begin
  Read(F,Ch);
  Inc(Sz);
  If Ch='\' Then Begin
   { lire un mot de controle }
   Buf:='';
   While(Not Eof(F))Do Begin
    Read(F,Nx); Inc(Sz);
    If((Nx>='a')And(Nx<='z'))Or((Nx>='A')And(Nx<='Z'))Then Buf:=Buf+Nx
    Else Break;
   End;
   { Nx contient le caractere de fin }
   If UpStr(Buf)='PAGE' Then Begin
    If HasTopic Then Begin
     T.Size:=Sz-T.Offset;
     AddTopic(T);
     HasTopic:=False;
    End;
    ResetTopic(T,FileIdx);
    T.Offset:=Sz;
   End
   Else If UpStr(Buf)='FOOTNOTE' Then Begin
    { Le caractere de reference du footnote est le caractere
      qui PRECEDE \footnote dans la source, mais en pratique
      Word place \chftn juste avant. On scanne le contenu du groupe
      a la recherche du marqueur # $ K + * en debut. }
    Body:=ReadGroup(F,GroupBytes);
    Inc(Sz,GroupBytes);
    { Le contenu est typiquement: '# IDH_INDEX' ou simplement
      le texte de la note avec le caractere de reference recupere
      via le caractere qui precedait. Pour la robustesse on
      cherche un des marqueurs au debut. }
    If Length(Body)>=1 Then Begin
     FN:=Body[1];
     If FN In ['#','$','K','+','*'] Then
      Body:=Trim(Copy(Body,2,Length(Body)-1))
     Else
      FN:=' ';
     HasTopic:=True;
     Case FN Of
      '#': T.Context:=Body;
      '$': T.Title:=Body;
      'K': AddKeywordList(T,Body);
      '+': T.Browse:=Body;
      '*': T.BuildTag:=Body;
     End;
    End;
   End;
  End;
 End;
 If HasTopic Then Begin
  T.Size:=Sz-T.Offset;
  AddTopic(T);
 End;
 Close(F);
 RtfFiles[FileIdx].ByteSize:=Sz;
 Inc(TotalRtfBytes,Sz);
 RtfFiles[FileIdx].TopicCnt:=NumTopics;
 EmitVerbose('  '+IntToStr(Sz)+' octets, topics cumules: '+IntToStr(NumTopics));
End;

{ ============================================================
  VERIFICATION : resoudre les contextes du [MAP]
  ============================================================ }

Procedure VerifyMap;
Var I,J:Integer; Found:Boolean;
Begin
 CtxResolved:=0; CtxUnresolved:=0;
 For I:=1 To NumMapEntries Do Begin
  Found:=False;
  For J:=1 To NumTopics Do
   If UpStr(Topics[J].Context)=UpStr(MapEntries[I].Name) Then Begin
    Found:=True; Break;
   End;
  MapEntries[I].Resolved:=Found;
  If Found Then Inc(CtxResolved)
  Else Begin
   Inc(CtxUnresolved);
   If OptCompileAll Then
    EmitWarning(1300,'Contexte [MAP] non reference: '+MapEntries[I].Name)
   Else
    EmitWarning(1301,'Contexte [MAP] introuvable: '+MapEntries[I].Name);
  End;
 End;
End;

{ ============================================================
  ECRITURE DU CONTAINER WINHELP 3.x
  ============================================================ }

Procedure WriteByte(B:Byte);
Begin
 BlockWrite(HlpF,B,1);
 Inc(OutputBytes);
End;

Procedure WriteWord(W:Word);
Begin
 BlockWrite(HlpF,W,2);
 Inc(OutputBytes,2);
End;

Procedure WriteLong(L:LongInt);
Begin
 BlockWrite(HlpF,L,4);
 Inc(OutputBytes,4);
End;

Procedure WriteAsciiZ(Const S:TStr255);
Var Z:Byte;
Begin
 If Length(S)>0 Then BlockWrite(HlpF,S[1],Length(S));
 Z:=0;
 BlockWrite(HlpF,Z,1);
 Inc(OutputBytes,Length(S)+1);
End;

Procedure WriteBytes(Var Buf;Count:LongInt);
Begin
 BlockWrite(HlpF,Buf,Count);
 Inc(OutputBytes,Count);
End;

{ En-tete d'un fichier interne : reserved + used + flags }
Procedure WriteFileHeader(DataSize:LongInt);
Var FH:TFileHeader;
Begin
 FH.ReservedSpace:=DataSize+9;
 FH.UsedSpace:=DataSize;
 FH.FileFlags:=4;
 BlockWrite(HlpF,FH,9);
 Inc(OutputBytes,9);
End;

{ ---- Fichier interne |SYSTEM ---- }
Var SystemFileOfs:LongInt;
Function ComputeSystemSize:LongInt;
Var S:LongInt;
Begin
 S:=10; { en-tete TSystemHeader 10 octets }
 If ProjTitle<>'' Then S:=S+4+Length(ProjTitle)+1;
 If ProjCopyright<>'' Then S:=S+4+Length(ProjCopyright)+1;
 If ProjContents<>'' Then S:=S+4+Length(ProjContents)+1;
 ComputeSystemSize:=S;
End;

Procedure WriteSystemFile;
Var Size:LongInt;
Begin
 SystemFileOfs:=OutputBytes;
 Size:=ComputeSystemSize;
 WriteFileHeader(Size);
 WriteWord(SYS_MAGIC);   { Magic 0x036C }
 WriteWord(21);          { MinorVer = HCW 3.1 }
 WriteWord(1);           { MajorVer }
 WriteLong(DosNow);      { GenDate }
 If ProjCompress And Not OptNoCompress Then
  WriteWord(8)           { Flags : compresse }
 Else
  WriteWord(0);
 If ProjTitle<>'' Then Begin
  WriteWord(1);                       { type Title }
  WriteWord(Length(ProjTitle)+1);
  WriteAsciiZ(ProjTitle);
 End;
 If ProjCopyright<>'' Then Begin
  WriteWord(2);
  WriteWord(Length(ProjCopyright)+1);
  WriteAsciiZ(ProjCopyright);
 End;
 If ProjContents<>'' Then Begin
  WriteWord(3);
  WriteWord(Length(ProjContents)+1);
  WriteAsciiZ(ProjContents);
 End;
End;

{ ---- Fichier interne |TOPIC ---- }
Var TopicFileOfs:LongInt;
    TopicDataSize:LongInt;
    TopicOffsets:Array[1..MAX_TOPICS] Of LongInt;

Type
 PByteArr = ^TByteArr;
 TByteArr = Array[0..0] Of Byte;

{ ------------------------------------------------------------
  LZ77 - Compression simple style WinHelp
  ------------------------------------------------------------
  Format de sortie :
   - 4 octets : taille decompressee (LongInt LE)
   - Suite de groupes de 9 octets max :
       * 1 octet de flags (8 bits, LSB-first)
       * Pour chaque bit a 1 : 1 octet litteral
       * Pour chaque bit a 0 : 2 octets match
                   octet 1 = (length-3) shl 4 | (offset shr 8)
                   octet 2 = offset and $FF
                   offset 1..4096, length 3..18
  ------------------------------------------------------------ }

Const
 LZ_WIN_BITS   = 12;
 LZ_WIN_SIZE   = 4096;     { 1 shl LZ_WIN_BITS }
 LZ_WIN_MASK   = 4095;
 LZ_MIN_MATCH  = 3;
 LZ_MAX_MATCH  = 18;
 LZ_HASH_SIZE  = 4096;

Procedure LZ77Compress(Src:PByteArr;SrcLen:LongInt;
                       Dst:PByteArr;Var DstLen:LongInt);
Var
 SrcPos,DstPos:LongInt;
 Head:Array[0..LZ_HASH_SIZE-1] Of LongInt;
 Prev:Array[0..LZ_WIN_SIZE-1] Of LongInt;
 I,K,L,BestLen,BestOfs,Cand,Limit,MaxLen:LongInt;
 H:LongInt;
 FlagPos:LongInt;
 FlagBit:Byte;
 FlagVal:Byte;

 Procedure EmitLiteral(B:Byte);
 Begin
  If FlagBit=0 Then Begin
   FlagPos:=DstPos;
   Dst^[DstPos]:=0;
   Inc(DstPos);
   FlagBit:=1;
   FlagVal:=0;
  End;
  FlagVal:=FlagVal Or FlagBit;
  Dst^[FlagPos]:=FlagVal;
  Dst^[DstPos]:=B;
  Inc(DstPos);
  If FlagBit=128 Then FlagBit:=0 Else FlagBit:=FlagBit Shl 1;
 End;

 Procedure EmitMatch(Ofs,Len:LongInt);
 Var L2:LongInt;
 Begin
  If FlagBit=0 Then Begin
   FlagPos:=DstPos;
   Dst^[DstPos]:=0;
   Inc(DstPos);
   FlagBit:=1;
   FlagVal:=0;
  End;
  { bit reste a 0 = match }
  Dst^[FlagPos]:=FlagVal;
  L2:=Len-LZ_MIN_MATCH;            { 0..15 }
  Dst^[DstPos]:=((L2 And $0F) Shl 4) Or ((Ofs Shr 8) And $0F);
  Dst^[DstPos+1]:=Ofs And $FF;
  Inc(DstPos,2);
  If FlagBit=128 Then FlagBit:=0 Else FlagBit:=FlagBit Shl 1;
 End;

Begin
 FillChar(Head,SizeOf(Head),$FF);  { -1 partout }
 FillChar(Prev,SizeOf(Prev),$FF);
 SrcPos:=0; DstPos:=0;
 FlagPos:=0; FlagBit:=0; FlagVal:=0;

 { Ecrire la taille originale en tete }
 Dst^[0]:=SrcLen And $FF;
 Dst^[1]:=(SrcLen Shr 8) And $FF;
 Dst^[2]:=(SrcLen Shr 16) And $FF;
 Dst^[3]:=(SrcLen Shr 24) And $FF;
 DstPos:=4;

 While SrcPos<SrcLen Do Begin
  BestLen:=0; BestOfs:=0;
  If SrcPos+LZ_MIN_MATCH<=SrcLen Then Begin
   H:=((LongInt(Src^[SrcPos]) Shl 8) Xor
       (LongInt(Src^[SrcPos+1]) Shl 4) Xor
        LongInt(Src^[SrcPos+2])) And (LZ_HASH_SIZE-1);
   Cand:=Head[H];
   { Offset encode sur 12 bits : 1..4095. Cand doit etre > SrcPos-4096
     pour que BestOfs := SrcPos-Cand reste <= 4095. Sinon l offset 4096
     est code comme 0, ce qui equivaut a "fin de flux" pour le decodeur. }
   Limit:=SrcPos-LZ_WIN_SIZE+1;
   If Limit<0 Then Limit:=0;
   While(Cand>=Limit)And(Cand>=0)Do Begin
    { Verifier le match }
    MaxLen:=SrcLen-SrcPos;
    If MaxLen>LZ_MAX_MATCH Then MaxLen:=LZ_MAX_MATCH;
    L:=0;
    While(L<MaxLen)And(Src^[Cand+L]=Src^[SrcPos+L])Do Inc(L);
    If L>BestLen Then Begin
     BestLen:=L;
     BestOfs:=SrcPos-Cand;
     If L>=LZ_MAX_MATCH Then Break;
    End;
    Cand:=Prev[Cand And LZ_WIN_MASK];
   End;
   { Inserer la position courante dans le hash }
   Prev[SrcPos And LZ_WIN_MASK]:=Head[H];
   Head[H]:=SrcPos;
  End;
  If BestLen>=LZ_MIN_MATCH Then Begin
   EmitMatch(BestOfs,BestLen);
   { Avancer et alimenter le hash sur les positions intermediaires }
   For K:=1 To BestLen-1 Do Begin
    I:=SrcPos+K;
    If I+LZ_MIN_MATCH<=SrcLen Then Begin
     H:=((LongInt(Src^[I]) Shl 8) Xor
         (LongInt(Src^[I+1]) Shl 4) Xor
          LongInt(Src^[I+2])) And (LZ_HASH_SIZE-1);
     Prev[I And LZ_WIN_MASK]:=Head[H];
     Head[H]:=I;
    End;
   End;
   Inc(SrcPos,BestLen);
  End Else Begin
   EmitLiteral(Src^[SrcPos]);
   Inc(SrcPos);
  End;
 End;
 DstLen:=DstPos;
End;

Procedure CopyRtfBytes(Const Src:TStr255;StartOfs,Count:LongInt);
Var F:File; Buf:Array[1..1024] Of Byte; NR,Need,Got:Word;
    Remain:LongInt; OldFM:Byte;
Begin
 OldFM:=FileMode; FileMode:=0;
 Assign(F,Src);
 {$I-} Reset(F,1); {$I+}
 If IOResult<>0 Then Begin FileMode:=OldFM; Exit; End;
 Seek(F,StartOfs);
 Remain:=Count;
 While Remain>0 Do Begin
  If Remain>1024 Then Need:=1024 Else Need:=Remain;
  BlockRead(F,Buf,Need,Got);
  If Got=0 Then Break;
  BlockWrite(HlpF,Buf,Got);
  Inc(OutputBytes,Got);
  Dec(Remain,Got);
 End;
 Close(F);
 FileMode:=OldFM;
End;

Procedure LoadRtfRange(Const Src:TStr255;StartOfs,Count:LongInt;
                       Buf:PByteArr;DstOfs:LongInt);
Var F:File; Tmp:Array[1..1024] Of Byte; Need,Got:Word;
    Remain:LongInt; OldFM:Byte; K:Integer;
Begin
 OldFM:=FileMode; FileMode:=0;
 Assign(F,Src);
 {$I-} Reset(F,1); {$I+}
 If IOResult<>0 Then Begin FileMode:=OldFM; Exit; End;
 Seek(F,StartOfs);
 Remain:=Count;
 While Remain>0 Do Begin
  If Remain>1024 Then Need:=1024 Else Need:=Remain;
  BlockRead(F,Tmp,Need,Got);
  If Got=0 Then Break;
  For K:=1 To Got Do Buf^[DstOfs+K-1]:=Tmp[K];
  Inc(DstOfs,Got);
  Dec(Remain,Got);
 End;
 Close(F);
 FileMode:=OldFM;
End;

Procedure WriteTopicFile;
Var I:Integer; LocalOfs,RawTotal,CompSize:LongInt;
    RawBuf,CompBuf:PByteArr;
    UseCompression:Boolean;
    FlagsByte:Byte;
Begin
 TopicFileOfs:=OutputBytes;
 UseCompression:=ProjCompress And Not OptNoCompress;

 { Calculer la taille brute totale du fichier |TOPIC }
 RawTotal:=0;
 For I:=1 To NumTopics Do
  RawTotal:=RawTotal+21+Topics[I].Size;
 If RawTotal=0 Then RawTotal:=1;
 TopicRawBytes:=RawTotal;

 { Allouer le buffer brut et le remplir }
 GetMem(RawBuf,RawTotal);
 FillChar(RawBuf^,RawTotal,0);
 LocalOfs:=0;
 For I:=1 To NumTopics Do Begin
  TopicOffsets[I]:=LocalOfs;
  RawBuf^[LocalOfs]:=2;
  RawBuf^[LocalOfs+1]:=Topics[I].Size And $FF;
  RawBuf^[LocalOfs+2]:=(Topics[I].Size Shr 8) And $FF;
  RawBuf^[LocalOfs+3]:=(Topics[I].Size Shr 16) And $FF;
  RawBuf^[LocalOfs+4]:=(Topics[I].Size Shr 24) And $FF;
  LoadRtfRange(RtfFiles[Topics[I].FileIdx].FullPath,
               Topics[I].Offset,Topics[I].Size,
               RawBuf,LocalOfs+21);
  LocalOfs:=LocalOfs+21+Topics[I].Size;
 End;

 If UseCompression Then Begin
  { Buffer de sortie : au pire (SrcLen + SrcLen/8 + 16) }
  GetMem(CompBuf,RawTotal+(RawTotal Shr 3)+64);
  LZ77Compress(RawBuf,RawTotal,CompBuf,CompSize);
  EmitVerbose('Compression |TOPIC : '+IntToStr(RawTotal)+' -> '+
              IntToStr(CompSize)+' octets ('+
              IntToStr((CompSize*100) Div RawTotal)+'%)');
  { Si la compression gonfle, on retombe sur l'image brute }
  If CompSize>=RawTotal Then Begin
   EmitVerbose('  Compression non rentable, fichier stocke tel quel.');
   FreeMem(CompBuf,RawTotal+(RawTotal Shr 3)+64);
   UseCompression:=False;
  End;
 End;

 If UseCompression Then Begin
  TopicCompBytes:=CompSize;
  CompressUsed:=True;
  { En-tete fichier interne : on encode le flag de compression dans
    FileFlags (bit 0 mis a 1 en plus du bit 2). }
  FlagsByte:=4 Or 1;
  WriteLong(CompSize+9);
  WriteLong(CompSize);
  WriteByte(FlagsByte);
  BlockWrite(HlpF,CompBuf^,CompSize);
  Inc(OutputBytes,CompSize);
  FreeMem(CompBuf,RawTotal+(RawTotal Shr 3)+64);
 End Else Begin
  TopicCompBytes:=RawTotal;
  WriteFileHeader(RawTotal);
  BlockWrite(HlpF,RawBuf^,RawTotal);
  Inc(OutputBytes,RawTotal);
 End;

 FreeMem(RawBuf,RawTotal);
 TopicDataSize:=TopicCompBytes;
End;

{ ---- Fichier interne |CTXOMAP : mapping contexte numerique -> topic ---- }
Var CtxOmapOfs:LongInt;

Procedure WriteCtxomap;
Var I,J,N:Integer; Size:LongInt; W:Word;
Begin
 CtxOmapOfs:=OutputBytes;
 N:=0;
 For I:=1 To NumMapEntries Do If MapEntries[I].Resolved Then Inc(N);
 Size:=2+LongInt(N)*8;
 WriteFileHeader(Size);
 W:=N; WriteWord(W);
 For I:=1 To NumMapEntries Do
  If MapEntries[I].Resolved Then Begin
   WriteLong(MapEntries[I].Value);
   { Trouver l'offset du topic correspondant }
   For J:=1 To NumTopics Do
    If UpStr(Topics[J].Context)=UpStr(MapEntries[I].Name) Then Begin
     WriteLong(TopicOffsets[J]);
     Break;
    End;
  End;
End;

{ ---- Fichier interne |TTLBTREE : titres des topics ----- }
Var TtlBtreeOfs:LongInt;

Procedure WriteTtlBtree;
Var I:Integer; Size:LongInt;
Begin
 TtlBtreeOfs:=OutputBytes;
 { Format simplifie : suite de (LongInt offset + ASCIIZ title).
   Le format reel utilise un B-tree, mais ce conteneur reste valide
   comme fichier brut interne. }
 Size:=0;
 For I:=1 To NumTopics Do
  Size:=Size+4+Length(Topics[I].Title)+1;
 If Size=0 Then Size:=1;
 WriteFileHeader(Size);
 If NumTopics=0 Then WriteByte(0)
 Else
  For I:=1 To NumTopics Do Begin
   WriteLong(TopicOffsets[I]);
   WriteAsciiZ(Topics[I].Title);
  End;
End;

{ ---- Fichier interne |CONTEXT : table des contextes haches ---- }
Var ContextOfs:LongInt;

Function HashContext(Const S:TStr255):LongInt;
Var I:Integer; H:LongInt; C:Char;
Begin
 { Hash WinHelp standard : sur chaine en majuscules sans certains chars }
 H:=0;
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If(C>='a')And(C<='z')Then C:=Chr(Ord(C)-32);
  H:=H*43+Ord(C);
 End;
 HashContext:=H;
End;

Procedure WriteContextFile;
Var I:Integer; Size:LongInt;
Begin
 ContextOfs:=OutputBytes;
 Size:=0;
 For I:=1 To NumTopics Do
  If Topics[I].Context<>'' Then Inc(Size,8);
 If Size=0 Then Size:=1;
 WriteFileHeader(Size);
 If Size=1 Then WriteByte(0)
 Else
  For I:=1 To NumTopics Do
   If Topics[I].Context<>'' Then Begin
    WriteLong(HashContext(Topics[I].Context));
    WriteLong(TopicOffsets[I]);
   End;
End;

{ ---- Repertoire (B-tree) du systeme de fichiers interne ---- }
Var DirOfs:LongInt;

Type
 TDirEntry = Record
  Name : TStr80;
  Ofs  : LongInt;
 End;

Var DirEntries:Array[1..16] Of TDirEntry;
    NumDirEntries:Integer;

Procedure AddDir(Const Name:TStr80;Ofs:LongInt);
Begin
 Inc(NumDirEntries);
 DirEntries[NumDirEntries].Name:=Name;
 DirEntries[NumDirEntries].Ofs:=Ofs;
End;

Procedure SortDir;
Var I,J:Integer; Tmp:TDirEntry;
Begin
 For I:=1 To NumDirEntries-1 Do
  For J:=I+1 To NumDirEntries Do
   If UpStr(DirEntries[I].Name)>UpStr(DirEntries[J].Name) Then Begin
    Tmp:=DirEntries[I]; DirEntries[I]:=DirEntries[J]; DirEntries[J]:=Tmp;
   End;
End;

Procedure WriteDirectory;
Var I:Integer; DataSize:LongInt;
    BT:TBTreeHeader;
    PageBuf:Array[0..1023] Of Byte;
    PagePos:Integer;
    Name:TStr80;
    L:Byte;
    Hdr:LongInt;
Begin
 SortDir;
 DirOfs:=OutputBytes;
 { Le 'directory' est lui-meme un fichier interne contenant une
   B-tree d'une seule page de 1024 octets. }
 DataSize:=38+1024;  { en-tete B-tree + 1 page }
 WriteFileHeader(DataSize);

 FillChar(BT,SizeOf(BT),0);
 BT.Magic:=$293B;
 BT.Flags:=$0402;
 BT.PageSize:=$0400;
 FillChar(BT.Structure,16,0);
 BT.Structure[1]:='F'; BT.Structure[2]:='z'; BT.Structure[3]:='4';
 BT.MustBeZero:=0;
 BT.PageSplits:=0;
 BT.RootPage:=0;
 BT.MustBeNegOne:=$FFFF;
 BT.TotalPages:=1;
 BT.NLevels:=1;
 BT.TotalEntries:=NumDirEntries;
 BlockWrite(HlpF,BT,38);
 Inc(OutputBytes,38);

 { Construire la page : en-tete (2 octets unused, 2 octets nentries,
   2 octets previous=-1, 2 octets next=-1) puis pour chaque entree :
   ASCIIZ name + LongInt offset. }
 FillChar(PageBuf,SizeOf(PageBuf),0);
 PageBuf[0]:=0; PageBuf[1]:=0;
 PageBuf[2]:=NumDirEntries And $FF;
 PageBuf[3]:=(NumDirEntries Shr 8) And $FF;
 PageBuf[4]:=$FF; PageBuf[5]:=$FF;
 PageBuf[6]:=$FF; PageBuf[7]:=$FF;
 PagePos:=8;
 For I:=1 To NumDirEntries Do Begin
  Name:=DirEntries[I].Name;
  L:=Length(Name);
  If PagePos+L+1+4>1024 Then Break;
  If L>0 Then Move(Name[1],PageBuf[PagePos],L);
  Inc(PagePos,L);
  PageBuf[PagePos]:=0; Inc(PagePos);
  Hdr:=DirEntries[I].Ofs;
  PageBuf[PagePos]  := Hdr And $FF;
  PageBuf[PagePos+1]:= (Hdr Shr 8) And $FF;
  PageBuf[PagePos+2]:= (Hdr Shr 16) And $FF;
  PageBuf[PagePos+3]:= (Hdr Shr 24) And $FF;
  Inc(PagePos,4);
 End;
 BlockWrite(HlpF,PageBuf,1024);
 Inc(OutputBytes,1024);
End;

Procedure WriteHelpFile;
Var Hdr:THelpHeader;
Begin
 EmitVerbose('Generation du fichier .HLP: '+HlpPath);
 Assign(HlpF,HlpPath);
 {$I-} Rewrite(HlpF,1); {$I+}
 If IOResult<>0 Then Begin
  EmitError(ERR_WRITE,'Impossible de creer '+HlpPath);
  Exit;
 End;
 HlpOpen:=True;
 OutputBytes:=0;

 { Reserver 16 octets pour l'en-tete, a reecrire a la fin }
 FillChar(Hdr,SizeOf(Hdr),0);
 BlockWrite(HlpF,Hdr,16);
 Inc(OutputBytes,16);

 NumDirEntries:=0;
 WriteSystemFile;   AddDir('|SYSTEM',  SystemFileOfs);
 WriteTopicFile;    AddDir('|TOPIC',   TopicFileOfs);
 WriteContextFile;  AddDir('|CONTEXT', ContextOfs);
 WriteCtxomap;      AddDir('|CTXOMAP', CtxOmapOfs);
 WriteTtlBtree;     AddDir('|TTLBTREE',TtlBtreeOfs);
 WriteDirectory;

 { Reecrire l'en-tete avec les bons offsets }
 Hdr.Magic    :=HC_MAGIC;
 Hdr.DirStart :=DirOfs;
 Hdr.FreeChain:=-1;
 Hdr.EOFOfs   :=OutputBytes;
 Seek(HlpF,0);
 BlockWrite(HlpF,Hdr,16);

 Close(HlpF);
 HlpOpen:=False;
 EmitVerbose('Fichier .HLP ecrit: '+IntToStr(OutputBytes)+' octets.');
End;

{ ============================================================
  AIDE EN LIGNE DE COMMANDE
  ============================================================ }

Procedure ShowHelp;Begin
 WriteLn('HC - Cette comman de permet de lancer le Help Compiler (HC).');
 WriteLn;
 WriteLn('Syntaxe : HC [options] fichier.hpj');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /A   Compiler tous les topics, meme ceux non references.');
 WriteLn('  /C   Supprimer les fichiers temporaires apres compilation.');
 WriteLn('  /E   Arreter a la premiere erreur rencontree.');
 WriteLn('  /L   Generer un fichier journal (.LOG) detaille.');
 WriteLn('  /M   Afficher davantage d''informations.');
 WriteLn('  /N   Desactiver les optimisations de compression .HLP.');
 WriteLn('  /P   Conserver les fichiers intermediaires.');
 WriteLn('  /Q   Mode silencieux.');
 WriteLn('  /T   Afficher les statistiques et le temps de compilation.');
 WriteLn('  /V   Mode verbeux avec diagnostics supplementaires.');
 WriteLn;
 WriteLn('Exemple : HC /L /V MONAIDE.HPJ');
End;

Procedure ParseCommandLine;
Var I,J:Integer; A:TStr255; C:Char;
Begin
 If ParamCount=0 Then Begin ShowHelp; Halt(0); End;
 For I:=1 To ParamCount Do Begin
  A:=ParamStr(I);
  If(A='/?')Or(A='-?')Or(UpStr(A)='--HELP')Or(UpStr(A)='-H')Then Begin
   ShowHelp; Halt(0);
  End;
  If(Length(A)>=1)And((A[1]='/')Or(A[1]='-'))Then Begin
   For J:=2 To Length(A) Do Begin
    C:=A[J];
    If(C>='a')And(C<='z')Then C:=Chr(Ord(C)-32);
    Case C Of
     'A': OptCompileAll  :=True;
     'C': OptCleanTmp    :=True;
     'E': OptStopOnError :=True;
     'L': OptMakeLog     :=True;
     'M': OptMoreInfo    :=True;
     'N': OptNoCompress  :=True;
     'P': OptKeepTmp     :=True;
     'Q': OptQuiet       :=True;
     'T': OptStats       :=True;
     'V': OptVerbose     :=True;
    Else
     Begin
      WriteLn('HC E',ERR_BAD_OPTION,': Option inconnue: ',A);
      Halt(2);
     End;
    End;
   End;
  End Else Begin
   If HpjPath<>'' Then Begin
    WriteLn('HC E',ERR_BAD_OPTION,': Un seul projet attendu.');
    Halt(2);
   End;
   HpjPath:=A;
  End;
 End;
 If HpjPath='' Then Begin
  WriteLn('HC : aucun fichier projet specifie.');
  Halt(2);
 End;
 If Pos('.',ExtractFileName(HpjPath))=0 Then HpjPath:=HpjPath+'.HPJ';
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Procedure InitGlobals;
Begin
 OptCompileAll:=False; OptCleanTmp:=False; OptStopOnError:=False;
 OptMakeLog:=False; OptMoreInfo:=False; OptNoCompress:=False;
 OptKeepTmp:=False; OptQuiet:=False; OptStats:=False; OptVerbose:=False;

 HpjPath:=''; HpjDir:=''; HlpPath:=''; LogPath:=''; ErrPath:='';
 LogOpen:=False; ErrOpen:=False; HlpOpen:=False;

 ProjTitle:=''; ProjCopyright:=''; ProjCompress:=True;
 ProjContents:=''; ProjReport:=False; ProjWarn:=3;
 ProjLang:=0; ProjOldKey:=False;
 ProjBmRoot:=''; ProjRoot:=''; ProjIcon:='';

 NumRtfFiles:=0; NumTopics:=0; NumMapEntries:=0;
 NumAliases:=0; NumBitmaps:=0; NumConfig:=0; NumKeywords:=0;

 ErrorCount:=0; WarnCount:=0;
 CtxResolved:=0; CtxUnresolved:=0;
 TotalRtfBytes:=0; OutputBytes:=0;
 TopicRawBytes:=0; TopicCompBytes:=0; CompressUsed:=False;

 GetNowTicks(StartTicks);
End;

Procedure PrintBanner;
Begin
 If OptQuiet Then Exit;
 WriteLn('Microsoft Help Compiler clone (HC) v',HC_VERSION);
End;

Procedure PrintStats;
Var Elapsed:Real;
Begin
 If OptQuiet And Not OptStats Then Exit;
 Elapsed:=ElapsedSeconds;
 WriteLn;
 WriteLn('--- Statistiques de compilation ---');
 WriteLn('Fichiers RTF traites  : ',NumRtfFiles);
 WriteLn('Topics decouverts     : ',NumTopics);
 WriteLn('Mots-cles indexes     : ',NumKeywords);
 WriteLn('Entrees [MAP]         : ',NumMapEntries,
         '  (resolues: ',CtxResolved,', non resolues: ',CtxUnresolved,')');
 WriteLn('Bitmaps               : ',NumBitmaps);
 WriteLn('Alias                 : ',NumAliases);
 WriteLn('Macros [CONFIG]       : ',NumConfig);
 WriteLn('Octets RTF lus        : ',TotalRtfBytes);
 WriteLn('Octets HLP ecrits     : ',OutputBytes);
 If CompressUsed And (TopicRawBytes>0) Then
  WriteLn('Compression |TOPIC    : ',TopicRawBytes,' -> ',TopicCompBytes,
          ' octets (',(TopicCompBytes*100) Div TopicRawBytes,'%)')
 Else
  WriteLn('Compression |TOPIC    : desactivee');
 WriteLn('Avertissements        : ',WarnCount);
 WriteLn('Erreurs               : ',ErrorCount);
 WriteLn('Temps total           : ',Elapsed:7:2,' s');
 If LogOpen Then Begin
  WriteLn(LogF);
  WriteLn(LogF,'Topics: ',NumTopics,'  Map: ',NumMapEntries,
          '  Bytes RTF: ',TotalRtfBytes,'  Bytes HLP: ',OutputBytes);
  WriteLn(LogF,'Temps: ',Elapsed:7:2,' s');
 End;
End;

Procedure CleanupTemporaries;
Var I:Integer; F:File;
Begin
 If OptKeepTmp Then Exit;
 If Not OptCleanTmp Then Exit;
 EmitVerbose('Nettoyage des fichiers temporaires...');
 { Aucune temporaire generee par ce clone, mais on respecte
   l'intention en supprimant un eventuel .GID associe. }
 Assign(F,ChangeExt(HpjPath,'.GID'));
 {$I-} Erase(F); {$I+}
 If IOResult<>0 Then; { ignore }
 If Not OptMakeLog Then Begin
  Assign(F,ChangeExt(HpjPath,'.LOG'));
  {$I-} Erase(F); {$I+}
  If IOResult<>0 Then;
 End;
 I:=0; If I=0 Then ; { silence }
End;

Var I:Integer;

BEGIN
 InitGlobals;
 ParseCommandLine;
 HpjDir:=ExtractFileDir(HpjPath);
 HlpPath:=ChangeExt(HpjPath,'.HLP');
 LogPath:=ChangeExt(HpjPath,'.LOG');
 ErrPath:=ChangeExt(HpjPath,'.ERR');

 PrintBanner;
 OpenLogs;
 Emit('Compilation du projet : '+HpjPath);

 If Not FileExists(HpjPath) Then Begin
  EmitError(ERR_HPJ_NOTFOUND,'Projet introuvable: '+HpjPath);
  CloseLogs;
  Halt(2);
 End;

 ReadHPJ(HpjPath);

 If NumRtfFiles=0 Then
  EmitError(ERR_NO_FILES,'Aucun fichier RTF declare dans [FILES].');

 EmitVerbose('Scan des fichiers source...');
 For I:=1 To NumRtfFiles Do
  If RtfFiles[I].Exists Then ScanRTF(I);

 EmitVerbose('Verification de la table de mappage...');
 VerifyMap;

 If ErrorCount=0 Then
  WriteHelpFile
 Else
  Emit('Compilation echouee : '+IntToStr(ErrorCount)+' erreur(s).');

 PrintStats;
 CleanupTemporaries;
 CloseLogs;

 If ErrorCount>0 Then Halt(1)
 Else If WarnCount>0 Then Halt(0)
 Else Halt(0);
END.
