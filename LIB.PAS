{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program LIB;

{$A-}

Uses DOS;

Const
 VERSION='1.0';
 MAX_MODULES=1024;
 MAX_SYMBOLS=4096;
 MAX_LNAME_ENTRIES=256;
 RECBUF_SIZE=32768;
 PAGE_SIZE=16;

 { Types d'enregistrements OMF }
 OMF_THEADR:Byte=$80;
 OMF_LHEADR:Byte=$82;
 OMF_COMENT:Byte=$88;
 OMF_MODEND:Byte=$8A;
 OMF_MODEND32:Byte=$8B;
 OMF_EXTDEF:Byte=$8C;
 OMF_TYPDEF:Byte=$8E;
 OMF_PUBDEF:Byte=$90;
 OMF_PUBDEF32:Byte=$91;
 OMF_LINNUM:Byte=$94;
 OMF_LINNUM32:Byte=$95;
 OMF_LNAMES:Byte=$96;
 OMF_SEGDEF:Byte=$98;
 OMF_SEGDEF32:Byte=$99;
 OMF_GRPDEF:Byte=$9A;
 OMF_FIXUPP:Byte=$9C;
 OMF_FIXUPP32:Byte=$9D;
 OMF_LEDATA:Byte=$A0;
 OMF_LEDATA32:Byte=$A1;
 OMF_LIDATA:Byte=$A2;
 OMF_LIDATA32:Byte=$A3;
 OMF_COMDEF:Byte=$B0;
 OMF_BAKPAT:Byte=$B2;
 OMF_BAKPAT32:Byte=$B3;
 OMF_LEXTDEF:Byte=$B4;
 OMF_LEXTDEF32:Byte=$B5;
 OMF_LPUBDEF:Byte=$B6;
 OMF_LPUBDEF32:Byte=$B7;
 OMF_LCOMDEF:Byte=$B8;
 OMF_CEXTDEF:Byte=$BC;
 OMF_COMDAT:Byte=$C2;
 OMF_COMDAT32:Byte=$C3;
 OMF_LINSYM:Byte=$C4;
 OMF_LINSYM32:Byte=$C5;
 OMF_ALIAS:Byte=$C6;
 OMF_NBKPAT:Byte=$C8;
 OMF_NBKPAT32:Byte=$C9;
 OMF_LLNAMES:Byte=$CA;
 OMF_VERNUM:Byte=$CC;
 OMF_VENDEXT:Byte=$CE;
 OMF_LIBHDR:Byte=$F0;
 OMF_LIBEND:Byte=$F1;

Type
 { Enregistrement de module dans une bibliothèque }
 TModule=Record
  Name:String[64];
  FileOffset:LongInt;
  Size:LongInt;
  PageNum:Word;
 End;

 { Enregistrement de symbole public }
 TSymbolRec=Record
  Name:String[64];
  ModuleIndex:Word;
  Segment:Word;
  Offset:Word;
  TypeIndex:Word;
 End;

 { En-tête de bibliothèque OMF }
 TLibHeader=Record
  RecType:Byte;
  RecLen:Word;
  PageSize:Word;
  DictOffset:LongInt;
  DictSize:Word;
  Flags:Byte;
 End;

 { Noeud de liste chainee pour les modules }
 PModuleNode=^TModuleNode;
 TModuleNode=Record
  Data:TModule;
  Next:PModuleNode;
 End;

 { Noeud de liste chainee pour les symboles }
 PSymbolNode=^TSymbolNode;
 TSymbolNode=Record
  Data:TSymbolRec;
  Next:PSymbolNode;
 End;

 { Noeud de liste chainee pour les fichiers d'entree }
 PInputFileNode=^TInputFileNode;
 TInputFileNode=Record
  Name:String;
  Next:PInputFileNode;
 End;

Var
 { Options de la ligne de commande }
 OptOut:String;
 OptRemove:Array[1..32] of String[64];
 OptRemoveCount:Integer;
 OptExtract:Array[1..32] of String[64];
 OptExtractCount:Integer;
 OptList:Boolean;
 OptSymbols:Boolean;
 OptInclude:Array[1..32] of String[64];
 OptIncludeCount:Integer;
 OptMachine:String[16];
 OptVerbose:Boolean;
 OptNoLogo:Boolean;

 { Fichiers d'entrée }
 InputFilesHead:PInputFileNode;
 InputFilesTail:PInputFileNode;
 InputFileCount:Integer;

 { Liste des modules }
 ModulesHead:PModuleNode;
 ModulesTail:PModuleNode;
 ModuleCount:Integer;

 { Liste des symboles }
 SymbolsHead:PSymbolNode;
 SymbolsTail:PSymbolNode;
 SymbolCount:Integer;

 { Tampon de lecture }
 RecBuf:Array[1..RECBUF_SIZE] of Byte;
 BufPos:Integer;
 RecLen:Word;
 RecLeft:Integer;
 ChkSum:Byte;

 { Variables globales }
 LibFile:File;
 OutputLib:File;
 TempFile:File;
 LNamesList:Array[0..MAX_LNAME_ENTRIES] of String[64];
 LNameCount:Integer;
 CurrentModuleName:String[64];
 CurrentModuleStart:LongInt;
 MainIdx:Integer;

Procedure ShowBanner;
Begin
 If Not OptNoLogo Then Begin
  WriteLn('LIB - Cette commande permet de lancer le gestionnaire de ',
               'biblioth�ques compatible Microsoft.');
  WriteLn('Version ', VERSION, ' - Clone Turbo Pascal/Free Pascal');
  WriteLn;
 End;
End;

Procedure ShowHelp;
Begin
 ShowBanner;
 WriteLn('Syntaxe:');
 WriteLn('  LIB [options] biblioth�que [objets]');
 WriteLn('  LIB @fichier_réponse');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /OUT:nom       Nom du fichier .lib de sortie');
 WriteLn('  /REMOVE:nom    Supprimer un module');
 WriteLn('  /EXTRACT:nom   Extraire un module');
 WriteLn('  /LIST          Lister le contenu de la biblioth�que');
 WriteLn('  /SYMBOLS       Afficher les symboles publics');
 WriteLn('  /INCLUDE:sym   Forcer l''inclusion d''un symbole');
 WriteLn('  /MACHINE:arch  Architecture cible (IX86, X64, ARM, etc.)');
 WriteLn('  /VERBOSE       Mode d�taill�');
 WriteLn('  /NOLOGO        Supprimer la banni�re');
 WriteLn('  /? ou /HELP    Afficher cette aide');
 WriteLn;
 WriteLn('Op�rations:');
 WriteLn('  +module.obj    Ajouter un module');
 WriteLn('  -module        Supprimer un module');
 WriteLn('  *module        Extraire un module');
 WriteLn;
 WriteLn('Exemples:');
 WriteLn('  LIB /LIST malib.lib');
 WriteLn('  LIB /OUT:nouvelle.lib ancienne.lib +module.obj');
 WriteLn('  LIB /EXTRACT:module malib.lib');
End;

Procedure Error(S:String);Begin
 WriteLn('ERREUR: ', S);
 Halt(1);
End;

Procedure Warning(S:String);Begin
 WriteLn('AVERTISSEMENT: ', S);
End;

Procedure AddInputFile(S:String);
Var
 Node:PInputFileNode;
Begin
 New(Node);
 Node^.Name := S;
 Node^.Next := Nil;
 If InputFilesHead = Nil Then Begin
  InputFilesHead := Node;
  InputFilesTail := Node;
 End
 Else Begin
  InputFilesTail^.Next := Node;
  InputFilesTail := Node;
 End;
 Inc(InputFileCount);
End;

Function GetInputFileAt(Index:Integer):String;
Var
 Node:PInputFileNode;
 I:Integer;
Begin
 GetInputFileAt := '';
 If (Index < 1) Or (Index > InputFileCount) Then Exit;
 Node := InputFilesHead;
 I := 1;
 While (Node <> Nil) And (I < Index) Do Begin
  Node := Node^.Next;
  Inc(I);
 End;
 If Node <> Nil Then
  GetInputFileAt := Node^.Name;
End;

Procedure ClearInputFiles;
Var
 Node, NextNode:PInputFileNode;
Begin
 Node := InputFilesHead;
 While Node <> Nil Do Begin
  NextNode := Node^.Next;
  Dispose(Node);
  Node := NextNode;
 End;
 InputFilesHead := Nil;
 InputFilesTail := Nil;
 InputFileCount := 0;
End;

Procedure AddModule(ModuleName:String; FileOffset, Size:LongInt; PageNum:Word);
Var
 Node:PModuleNode;
Begin
 New(Node);
 Node^.Data.Name := ModuleName;
 Node^.Data.FileOffset := FileOffset;
 Node^.Data.Size := Size;
 Node^.Data.PageNum := PageNum;
 Node^.Next := Nil;
 If ModulesHead = Nil Then Begin
  ModulesHead := Node;
  ModulesTail := Node;
 End
 Else Begin
  ModulesTail^.Next := Node;
  ModulesTail := Node;
 End;
 Inc(ModuleCount);
End;

Function GetModuleAt(Index:Integer):PModuleNode;
Var
 Node:PModuleNode;
 I:Integer;
Begin
 GetModuleAt := Nil;
 If (Index < 1) Or (Index > ModuleCount) Then Exit;
 Node := ModulesHead;
 I := 1;
 While (Node <> Nil) And (I < Index) Do Begin
  Node := Node^.Next;
  Inc(I);
 End;
 GetModuleAt := Node;
End;

Procedure ClearModules;
Var
 Node, NextNode:PModuleNode;
Begin
 Node := ModulesHead;
 While Node <> Nil Do Begin
  NextNode := Node^.Next;
  Dispose(Node);
  Node := NextNode;
 End;
 ModulesHead := Nil;
 ModulesTail := Nil;
 ModuleCount := 0;
End;

Procedure AddSymbol(SymName:String; ModuleIndex, Segment, Offset, TypeIndex:Word);
Var
 Node:PSymbolNode;
Begin
 New(Node);
 Node^.Data.Name := SymName;
 Node^.Data.ModuleIndex := ModuleIndex;
 Node^.Data.Segment := Segment;
 Node^.Data.Offset := Offset;
 Node^.Data.TypeIndex := TypeIndex;
 Node^.Next := Nil;
 If SymbolsHead = Nil Then Begin
  SymbolsHead := Node;
  SymbolsTail := Node;
 End
 Else Begin
  SymbolsTail^.Next := Node;
  SymbolsTail := Node;
 End;
 Inc(SymbolCount);
End;

Function GetSymbolAt(Index:Integer):PSymbolNode;
Var
 Node:PSymbolNode;
 I:Integer;
Begin
 GetSymbolAt := Nil;
 If (Index < 1) Or (Index > SymbolCount) Then Exit;
 Node := SymbolsHead;
 I := 1;
 While (Node <> Nil) And (I < Index) Do Begin
  Node := Node^.Next;
  Inc(I);
 End;
 GetSymbolAt := Node;
End;

Procedure ClearSymbols;
Var
 Node, NextNode:PSymbolNode;
Begin
 Node := SymbolsHead;
 While Node <> Nil Do Begin
  NextNode := Node^.Next;
  Dispose(Node);
  Node := NextNode;
 End;
 SymbolsHead := Nil;
 SymbolsTail := Nil;
 SymbolCount := 0;
End;

Function UpperCase(S:String):String;
Var I:Integer;
Begin
 For I := 1 to Length(S) do
  If (S[I] >= 'a') and (S[I] <= 'z') Then
   S[I] := Chr(Ord(S[I]) - 32);
 UpperCase := S;
End;

Function ByteHex2Str(Value:Byte):String;
Const
 HexChars:Array[0..15] of Char = '0123456789ABCDEF';
Begin
 ByteHex2Str := HexChars[(Value shr 4) and $0F] + HexChars[Value and $0F];
End;

Function WordHex2Str(Value:Word):String;
Begin
 WordHex2Str := ByteHex2Str(Hi(Value)) + ByteHex2Str(Lo(Value));
End;

Function LongHex2Str(Value:LongInt):String;
Begin
 LongHex2Str := WordHex2Str(Word(Value shr 16)) + WordHex2Str(Word(Value and $FFFF));
End;

Function ExtractFileName(Path:String):String;
Var
 I:Integer;
 Name:String;
Begin
 Name := Path;
 For I := Length(Path) downto 1 do
  If (Path[I] = '\') or (Path[I] = '/') or (Path[I] = ':') Then Begin
   Name := Copy(Path, I + 1, Length(Path) - I);
   Break;
  End;
 ExtractFileName := Name;
End;

Function StripExtension(FileName:String):String;
Var I:Integer;
Begin
 For I := Length(FileName) downto 1 do
  If FileName[I] = '.' Then Begin
   StripExtension := Copy(FileName, 1, I - 1);
   Exit;
  End
  Else If (FileName[I] = '\') or (FileName[I] = '/') Then Break;
 StripExtension := FileName;
End;

Function FileExists(FileName:String):Boolean;
Var F:File;
Begin
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 Close(F);
 {$I+}
 FileExists := (IOResult = 0);
End;

Function GetFileSize(FileName:String):LongInt;
Var
 F:File;
 Size:LongInt;
Begin
 Size := 0;
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 If IOResult = 0 Then Begin
  Size := System.FileSize(F);
  Close(F);
 End;
 {$I+}
 GetFileSize := Size;
End;

{ Lecture d'un octet du tampon }
Function GetByte:Byte;
Begin
 GetByte := RecBuf[BufPos];
 ChkSum := (ChkSum + RecBuf[BufPos]) and $FF;
 Inc(BufPos);
 Dec(RecLeft);
End;

{ Lecture d'un mot du tampon }
Function GetWord:Word;
Var W:Word;
Begin
 W := GetByte;
 W := W or (Word(GetByte) shl 8);
 GetWord := W;
End;

{ Lecture d'un double mot du tampon }
Function GetDWord:LongInt;
Var D:LongInt;
Begin
 D := GetWord;
 D := D or (LongInt(GetWord) shl 16);
 GetDWord := D;
End;

{ Lecture d'un nom OMF (préfixé par la longueur) }
Function GetName:String;
Var
 Len:Byte;
 S:String;
 I:Integer;
Begin
 Len := GetByte;
 S := '';
 For I := 1 to Len do
  S := S + Chr(GetByte);
 GetName := S;
End;

{ Lecture d'un index OMF (1 ou 2 octets) }
Function GetIndex:Word;
Var B:Byte;
Begin
 B := GetByte;
 If B <= 127 Then
  GetIndex := B
 Else
  GetIndex := ((B and $7F) shl 8) or GetByte;
End;

{ Lecture d'un enregistrement OMF complet }
Function ReadRecord(Var F:File):Boolean;
Var
 RecType:Byte;
 NumRead:Word;
Begin
 ReadRecord := False;
 BufPos := 1;
 ChkSum := 0;

 { Lire le type et la longueur }
 BlockRead(F, RecBuf[1], 3, NumRead);
 If NumRead < 3 Then Exit;

 RecType := RecBuf[1];
 RecLen := RecBuf[2] or (Word(RecBuf[3]) shl 8);

 If RecLen > RECBUF_SIZE - 3 Then Begin
  Warning('Enregistrement trop long');
  Exit;
 End;

 { Lire le reste de l'enregistrement }
 BlockRead(F, RecBuf[4], RecLen, NumRead);
 If NumRead < RecLen Then Begin
  Warning('Fin de fichier inattendue');
  Exit;
 End;

 RecLeft := RecLen + 3;
 ReadRecord := True;
End;

{ Écriture d'un enregistrement OMF }
Procedure WriteRecord(Var F:File; RecType:Byte; Data:Array of Byte; DataLen:Word);
Var
 Header:Array[1..3] of Byte;
 ChkByte:Byte;
 I:Integer;
 NumWritten:Word;
Begin
 Header[1] := RecType;
 Header[2] := Lo(DataLen + 1);
 Header[3] := Hi(DataLen + 1);

 { Calculer la somme de contrôle }
 ChkByte := RecType + Lo(DataLen + 1) + Hi(DataLen + 1);
 For I := 0 to DataLen - 1 do
  ChkByte := (ChkByte + Data[I]) and $FF;
 ChkByte := (256 - ChkByte) and $FF;

 BlockWrite(F, Header, 3, NumWritten);
 If DataLen > 0 Then
  BlockWrite(F, Data, DataLen, NumWritten);
 BlockWrite(F, ChkByte, 1, NumWritten);
End;

{ Parse un fichier réponse (@fichier) }
Procedure ParseResponseFile(FileName:String);
Var
 F:Text;
 Line, Token:String;
 I, P:Integer;
Begin
 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then
  Error('Impossible d''ouvrir le fichier réponse: ' + FileName);

 While Not Eof(F) do Begin
  ReadLn(F, Line);
  { Supprimer les commentaires }
  P := Pos('#', Line);
  If P > 0 Then Line := Copy(Line, 1, P - 1);
  P := Pos(';', Line);
  If P > 0 Then Line := Copy(Line, 1, P - 1);

  { Parser les tokens }
  While Length(Line) > 0 do Begin
   { Supprimer les espaces au début }
   While (Length(Line) > 0) and (Line[1] in [' ', #9]) do
    Delete(Line, 1, 1);
   If Length(Line) = 0 Then Break;

   { Extraire le token }
   Token := '';
   If Line[1] = '"' Then Begin
    Delete(Line, 1, 1);
    P := Pos('"', Line);
    If P > 0 Then Begin
     Token := Copy(Line, 1, P - 1);
     Delete(Line, 1, P);
    End;
   End
   Else Begin
    P := 1;
    While (P <= Length(Line)) and Not (Line[P] in [' ', #9]) do
     Inc(P);
    Token := Copy(Line, 1, P - 1);
    Delete(Line, 1, P);
   End;

   If Length(Token) > 0 Then Begin
    AddInputFile(Token);
   End;
  End;
 End;

 Close(F);
End;

{ Extraction du paramètre après les deux-points }
Function GetOptionValue(Opt:String):String;
Var P:Integer;
Begin
 P := Pos(':', Opt);
 If P > 0 Then
  GetOptionValue := Copy(Opt, P + 1, Length(Opt) - P)
 Else
  GetOptionValue := '';
End;

{ Vérifie si une chaîne semble être une option (commence par / suivi d'une lettre et pas un chemin) }
Function IsOption(S:String):Boolean;
Var
 P, ColonPos:Integer;
Begin
 IsOption := False;
 If Length(S) < 2 Then Exit;

 { Sur Unix/Linux, un chemin absolu commence par / }
 { Une option comme /OUT:xxx contient : après le mot-clé }
 { Une option sans paramètre comme /LIST ne contient pas de / après le premier caractère }

 If S[1] = '/' Then Begin
  { Vérifier si c'est une option avec une valeur (contient : avant tout /) }
  ColonPos := Pos(':', S);
  P := Pos('/', Copy(S, 2, Length(S) - 1));

  { Si on a un : avant le /, c'est une option avec valeur comme /OUT:/tmp/test.lib }
  If (ColonPos > 0) and ((P = 0) or (ColonPos < P + 1)) Then Begin
   IsOption := (S[2] in ['A'..'Z', 'a'..'z', '?']);
   Exit;
  End;

  { Si pas de :, vérifier si c'est un chemin }
  If P > 0 Then Begin
   { C'est probablement un chemin Unix comme /tmp/test.lib }
   IsOption := False;
   Exit;
  End;

  { Vérifier si ça ressemble à une option }
  IsOption := (S[2] in ['A'..'Z', 'a'..'z', '?']);
 End
 Else If S[1] = '-' Then Begin
  { Options style Unix }
  IsOption := (S[2] in ['A'..'Z', 'a'..'z', '-']);
 End;
End;

{ Analyse des arguments de la ligne de commande }
Procedure ParseCommandLine;
Var
 I:Integer;
 Arg, ArgUpper, Value:String;
Begin
 OptOut := '';
 OptRemoveCount := 0;
 OptExtractCount := 0;
 OptList := False;
 OptSymbols := False;
 OptIncludeCount := 0;
 OptMachine := 'IX86';
 OptVerbose := False;
 OptNoLogo := False;
 ClearInputFiles;

 For I := 1 to ParamCount do Begin
  Arg := ParamStr(I);
  ArgUpper := UpperCase(Arg);

  { Fichier réponse }
  If Arg[1] = '@' Then Begin
   ParseResponseFile(Copy(Arg, 2, Length(Arg) - 1));
  End
  { Options avec / ou - (mais pas un chemin de fichier) }
  Else If IsOption(Arg) Then Begin
   { Supprimer le préfixe / ou - ou -- }
   Delete(ArgUpper, 1, 1);
   Delete(Arg, 1, 1);
   { Si c'était un double tiret, supprimer le second }
   If (Length(ArgUpper) > 0) and (ArgUpper[1] = '-') Then Begin
    Delete(ArgUpper, 1, 1);
    Delete(Arg, 1, 1);
   End;

   If (ArgUpper = '?') or (ArgUpper = 'HELP') or (ArgUpper = 'H') Then Begin
    ShowHelp;
    Halt(0);
   End
   Else If Copy(ArgUpper, 1, 4) = 'OUT:' Then
    OptOut := GetOptionValue(Arg)
   Else If Copy(ArgUpper, 1, 7) = 'REMOVE:' Then Begin
    Inc(OptRemoveCount);
    OptRemove[OptRemoveCount] := GetOptionValue(Arg);
   End
   Else If Copy(ArgUpper, 1, 8) = 'EXTRACT:' Then Begin
    Inc(OptExtractCount);
    OptExtract[OptExtractCount] := GetOptionValue(Arg);
   End
   Else If ArgUpper = 'LIST' Then
    OptList := True
   Else If ArgUpper = 'SYMBOLS' Then
    OptSymbols := True
   Else If Copy(ArgUpper, 1, 8) = 'INCLUDE:' Then Begin
    Inc(OptIncludeCount);
    OptInclude[OptIncludeCount] := GetOptionValue(Arg);
   End
   Else If Copy(ArgUpper, 1, 8) = 'MACHINE:' Then
    OptMachine := UpperCase(GetOptionValue(Arg))
   Else If ArgUpper = 'VERBOSE' Then
    OptVerbose := True
   Else If ArgUpper = 'NOLOGO' Then
    OptNoLogo := True
   Else
    Warning('Option inconnue: /' + Arg);
  End
  { Opérations + - * }
  Else If Arg[1] = '+' Then Begin
   AddInputFile(Copy(Arg, 2, Length(Arg) - 1));
  End
  Else If Arg[1] = '-' Then Begin
   Inc(OptRemoveCount);
   OptRemove[OptRemoveCount] := Copy(Arg, 2, Length(Arg) - 1);
  End
  Else If Arg[1] = '*' Then Begin
   Inc(OptExtractCount);
   OptExtract[OptExtractCount] := Copy(Arg, 2, Length(Arg) - 1);
  End
  { Fichiers d'entrée }
  Else Begin
    AddInputFile(Arg);
  End;
 End;
End;

{ Traitement d'un enregistrement THEADR (nom du module T) }
Procedure ProcessTHEADR;
Begin
 GetByte; { Type }
 RecLen := GetWord;
 RecLeft := RecLen;
 CurrentModuleName := GetName;
 If OptVerbose Then
  WriteLn('  Module: ', CurrentModuleName);
End;

{ Traitement d'un enregistrement LHEADR (nom du module L) }
Procedure ProcessLHEADR;
Begin
 GetByte; { Type }
 RecLen := GetWord;
 RecLeft := RecLen;
 CurrentModuleName := GetName;
 If OptVerbose Then
  WriteLn('  Module L: ', CurrentModuleName);
End;

{ Traitement d'un enregistrement LNAMES }
Procedure ProcessLNAMES;
Begin
 GetByte; { Type }
 RecLen := GetWord;
 RecLeft := RecLen;

 While RecLeft > 1 do Begin
  Inc(LNameCount);
  If LNameCount <= MAX_LNAME_ENTRIES Then
   LNamesList[LNameCount] := GetName
  Else
   GetName;
 End;
End;

{ Traitement d'un enregistrement PUBDEF (symboles publics) }
Procedure ProcessPUBDEF(Is32Bit:Boolean);
Var
 GroupIndex, SegIndex:Word;
 BaseFrame:Word;
 SymName:String;
 SymOffset:LongInt;
 SymType:Word;
Begin
 GetByte; { Type }
 RecLen := GetWord;
 RecLeft := RecLen;

 GroupIndex := GetIndex;
 SegIndex := GetIndex;
 If (GroupIndex = 0) and (SegIndex = 0) Then
  BaseFrame := GetWord
 Else
  BaseFrame := 0;

 While RecLeft > 1 do Begin
  SymName := GetName;
  If Is32Bit Then
   SymOffset := GetDWord
  Else
   SymOffset := GetWord;
  SymType := GetIndex;

  AddSymbol(SymName, ModuleCount, SegIndex, SymOffset, SymType);

  If OptVerbose Then
   WriteLn('    Public: ', SymName, ' @ ', WordHex2Str(SymOffset));
 End;
End;

{ Traitement d'un enregistrement EXTDEF (symboles externes) }
Procedure ProcessEXTDEF;
Var
 SymName:String;
 SymType:Word;
Begin
 GetByte; { Type }
 RecLen := GetWord;
 RecLeft := RecLen;

 While RecLeft > 1 do Begin
  SymName := GetName;
  SymType := GetIndex;

  If OptVerbose Then
   WriteLn('    Externe: ', SymName);
 End;
End;

{ Lecture d'un fichier OBJ pour en extraire les informations }
Procedure ReadObjFile(FileName:String);
Var
 F:File;
 RecType:Byte;
 Done:Boolean;
Begin
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  Warning('Impossible d''ouvrir: ' + FileName);
  Exit;
 End;

 LNameCount := 0;
 CurrentModuleName := StripExtension(ExtractFileName(FileName));
 Done := False;

 While Not Done and Not Eof(F) do Begin
  If Not ReadRecord(F) Then Break;

  RecType := RecBuf[1];
  BufPos := 1;

  If RecType = OMF_THEADR Then ProcessTHEADR
  Else If RecType = OMF_LHEADR Then ProcessLHEADR
  Else If (RecType = OMF_LNAMES) or (RecType = OMF_LLNAMES) Then ProcessLNAMES
  Else If RecType = OMF_PUBDEF Then ProcessPUBDEF(False)
  Else If RecType = OMF_PUBDEF32 Then ProcessPUBDEF(True)
  Else If (RecType = OMF_EXTDEF) or (RecType = OMF_LEXTDEF) Then ProcessEXTDEF
  Else If (RecType = OMF_MODEND) or (RecType = OMF_MODEND32) Then Done := True;
 End;

 Close(F);

 { Ajouter le module à la liste }
 AddModule(CurrentModuleName, 0, GetFileSize(FileName), 0);
End;

{ Lecture de l'en-tête d'une bibliothèque OMF }
Function ReadLibHeader(Var F:File; Var Header:TLibHeader):Boolean;
Var NumRead:Word;
Begin
 ReadLibHeader := False;
 BlockRead(F, Header.RecType, 1, NumRead);
 If (NumRead < 1) or (Header.RecType <> OMF_LIBHDR) Then Exit;

 BlockRead(F, Header.RecLen, 2, NumRead);
 BlockRead(F, Header.PageSize, 2, NumRead);
 BlockRead(F, Header.DictOffset, 4, NumRead);
 BlockRead(F, Header.DictSize, 2, NumRead);
 BlockRead(F, Header.Flags, 1, NumRead);

 ReadLibHeader := True;
End;

{ Lecture des modules d'une bibliothèque OMF }
Procedure ReadLibrary(FileName:String);
Var
 F:File;
 Header:TLibHeader;
 RecType:Byte;
 PageSize:Word;
 CurrentPos, NextPos:LongInt;
 ModuleStart:LongInt;
 InModule:Boolean;
 NumRead:Word;
Begin
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  Warning('Impossible d''ouvrir la bibliothèque: ' + FileName);
  Exit;
 End;

 If Not ReadLibHeader(F, Header) Then Begin
  Warning('Format de bibliothèque invalide: ' + FileName);
  Close(F);
  Exit;
 End;

 PageSize := Header.PageSize + 3;
 If OptVerbose Then
  WriteLn('Bibliothèque: ', FileName, ' (Page size: ', PageSize, ')');

 { Se positionner après l'en-tête }
 CurrentPos := PageSize;
 Seek(F, CurrentPos);

 InModule := False;
 ModuleStart := CurrentPos;
 LNameCount := 0;

 While Not Eof(F) do Begin
  If Not ReadRecord(F) Then Break;

  RecType := RecBuf[1];
  BufPos := 1;

  If RecType = OMF_THEADR Then Begin
   InModule := True;
   ModuleStart := CurrentPos;
   ProcessTHEADR;
    AddModule(CurrentModuleName, ModuleStart, 0, ModuleStart div PageSize);
  End
  Else If RecType = OMF_LHEADR Then Begin
   InModule := True;
   ModuleStart := CurrentPos;
   ProcessLHEADR;
    AddModule(CurrentModuleName, ModuleStart, 0, ModuleStart div PageSize);
  End
  Else If (RecType = OMF_LNAMES) or (RecType = OMF_LLNAMES) Then ProcessLNAMES
  Else If RecType = OMF_PUBDEF Then ProcessPUBDEF(False)
  Else If RecType = OMF_PUBDEF32 Then ProcessPUBDEF(True)
  Else If (RecType = OMF_EXTDEF) or (RecType = OMF_LEXTDEF) Then ProcessEXTDEF
  Else If (RecType = OMF_MODEND) or (RecType = OMF_MODEND32) Then Begin
   CurrentPos := FilePos(F);
   If ModulesTail <> Nil Then
    ModulesTail^.Data.Size := CurrentPos - ModuleStart;
   InModule := False;
   LNameCount := 0;
   { Aligner sur la prochaine page }
   NextPos := ((CurrentPos + PageSize - 1) div PageSize) * PageSize;
   If NextPos > CurrentPos Then
    Seek(F, NextPos);
  End
  Else If RecType = OMF_LIBEND Then Break;

  CurrentPos := FilePos(F);
 End;

 Close(F);
End;

{ Affichage de la liste des modules }
Procedure ListModules;
Var
 I:Integer;
 ModuleNode:PModuleNode;
Begin
 WriteLn('Modules dans la bibliothèque:');
 WriteLn('-----------------------------');
 For I := 1 to ModuleCount do Begin
  ModuleNode := GetModuleAt(I);
  If ModuleNode <> Nil Then
   WriteLn('  ', ModuleNode^.Data.Name, ' (', ModuleNode^.Data.Size, ' octets)');
 End;
 WriteLn;
 WriteLn('Total: ', ModuleCount, ' module(s)');
End;

{ Affichage des symboles publics }
Procedure ListSymbols;
Var
 I:Integer;
 ModuleNode:PModuleNode;
 SymbolNode:PSymbolNode;
Begin
 WriteLn('Symboles publics:');
 WriteLn('-----------------');
 For I := 1 to SymbolCount do Begin
  SymbolNode := GetSymbolAt(I);
  If SymbolNode = Nil Then Continue;
  Write('  ', SymbolNode^.Data.Name);
  If SymbolNode^.Data.ModuleIndex <= ModuleCount Then Begin
   ModuleNode := GetModuleAt(SymbolNode^.Data.ModuleIndex);
   If ModuleNode <> Nil Then
    Write(' (', ModuleNode^.Data.Name, ')');
  End;
  WriteLn(' @ ', WordHex2Str(SymbolNode^.Data.Offset));
 End;
 WriteLn;
 WriteLn('Total: ', SymbolCount, ' symbole(s)');
End;

{ Extraction d'un module vers un fichier .OBJ }
Procedure ExtractModule(ModuleName:String; LibFileName:String);
Var
 F, OutF:File;
 Header:TLibHeader;
 I:Integer;
 Found:Boolean;
 ModuleNode:PModuleNode;
 Buffer:Array[1..4096] of Byte;
 ToRead, NumRead, NumWritten:Word;
 Remaining:LongInt;
 OutFileName:String;
Begin
 Found := False;
 For I := 1 to ModuleCount do Begin
  ModuleNode := GetModuleAt(I);
  If (ModuleNode <> Nil) And (UpperCase(ModuleNode^.Data.Name) = UpperCase(ModuleName)) Then Begin
   Found := True;

   OutFileName := ModuleName;
   If Pos('.', OutFileName) = 0 Then
    OutFileName := OutFileName + '.OBJ';

   {$I-}
   Assign(F, LibFileName);
   Reset(F, 1);
   {$I+}
   If IOResult <> 0 Then Begin
    Error('Impossible d''ouvrir la bibliothèque');
    Exit;
   End;

   {$I-}
   Assign(OutF, OutFileName);
   Rewrite(OutF, 1);
   {$I+}
   If IOResult <> 0 Then Begin
    Close(F);
    Error('Impossible de créer: ' + OutFileName);
    Exit;
   End;

  Seek(F, ModuleNode^.Data.FileOffset);
  Remaining := ModuleNode^.Data.Size;

   While Remaining > 0 do Begin
    If Remaining > SizeOf(Buffer) Then
     ToRead := SizeOf(Buffer)
    Else
     ToRead := Remaining;
    BlockRead(F, Buffer, ToRead, NumRead);
    BlockWrite(OutF, Buffer, NumRead, NumWritten);
    Dec(Remaining, NumRead);
   End;

   Close(OutF);
   Close(F);
   WriteLn('Module extrait: ', OutFileName);
   Break;
  End;
 End;

 If Not Found Then
  Warning('Module non trouvé: ' + ModuleName);
End;

{ Vérification si un module doit être supprimé }
Function ShouldRemoveModule(ModuleName:String):Boolean;
Var I:Integer;
Begin
 ShouldRemoveModule := False;
 For I := 1 to OptRemoveCount do
  If UpperCase(OptRemove[I]) = UpperCase(ModuleName) Then Begin
   ShouldRemoveModule := True;
   Exit;
  End;
End;

{ Calcul du prochain multiple de PageSize }
Function AlignToPage(Pos:LongInt; PageSize:Word):LongInt;
Begin
 AlignToPage := ((Pos + PageSize - 1) div PageSize) * PageSize;
End;

{ �criture des octets de bourrage pour l'alignement }
Procedure WritePadding(Var F:File; CurrentPos:LongInt; TargetPos:LongInt);
Var
 PadByte:Byte;
 I:LongInt;
 NumWritten:Word;
Begin
 PadByte := 0;
 For I := CurrentPos to TargetPos - 1 do BlockWrite(F, PadByte, 1, NumWritten);
End;

{ �criture de l'ent�te de biblioth�que }
Procedure WriteLibHeader(Var F:File; PageSize:Word; DictOffset:LongInt; DictSize:Word);
Var
 Header:Array[1..16] of Byte;
 RecLen:Word;
 NumWritten:Word;
Begin
 { Format standard Microsoft LIB:
   Octet 1: F0 (LIBHDR)
   Octets 2-3: RecLen = PageSize - 3 (longueur sans type et sans ces 2 octets)
   Octets 4-5: PageSize - 3 (taille de page stockée)
   Octets 6-9: DictOffset (offset du dictionnaire)
   Octets 10-11: DictSize (nombre de blocs de 512 octets)
   Octet 12: Flags
   Reste: Padding jusqu'à PageSize }
 RecLen := PageSize - 3;
 Header[1] := OMF_LIBHDR;
 Header[2] := Lo(RecLen);
 Header[3] := Hi(RecLen);
 Header[4] := Lo(PageSize - 3);
 Header[5] := Hi(PageSize - 3);
 Header[6] := DictOffset and $FF;
 Header[7] := (DictOffset shr 8) and $FF;
 Header[8] := (DictOffset shr 16) and $FF;
 Header[9] := (DictOffset shr 24) and $FF;
 Header[10] := Lo(DictSize);
 Header[11] := Hi(DictSize);
 Header[12] := 0; { Flags }
 BlockWrite(F, Header, 12, NumWritten);
End;

{ �criture du dictionnaire de la biblioth�que }
Procedure WriteLibDictionary(Var F:File);
Var
 I, J, Bucket:Integer;
 ModuleNode:PModuleNode;
 SymbolNode:PSymbolNode;
 BucketData:Array[0..36] of Byte;
 NumBuckets:Word;
 NameLen:Byte;
 NumWritten:Word;
 DictPage:Array[1..512] of Byte;
 PageOffset:Integer;
Begin
 { Cr�er un dictionnaire simple avec un seul bloc de 512 octets }
 FillChar(DictPage, SizeOf(DictPage), 0);
 DictPage[1] := 37; { Nombre de buckets }
 DictPage[38] := $FF; { Index libre }
 PageOffset := 39;
 For I := 1 to SymbolCount do Begin
  SymbolNode := GetSymbolAt(I);
  If SymbolNode = Nil Then Continue;
  If PageOffset + Length(SymbolNode^.Data.Name) + 4 > 512 Then Break;
  NameLen := Length(SymbolNode^.Data.Name);
  DictPage[PageOffset] := NameLen;
  Inc(PageOffset);
  For J := 1 to NameLen do Begin
   DictPage[PageOffset] := Ord(SymbolNode^.Data.Name[J]);
   Inc(PageOffset);
  End;
   { Page number du module }
  ModuleNode := GetModuleAt(SymbolNode^.Data.ModuleIndex);
  If ModuleNode <> Nil Then Begin
   DictPage[PageOffset] := Lo(ModuleNode^.Data.PageNum);
   Inc(PageOffset);
   DictPage[PageOffset] := Hi(ModuleNode^.Data.PageNum);
   Inc(PageOffset);
  End;
 End;
 BlockWrite(F, DictPage, 512, NumWritten);
End;

{ �criture de l'enregistrement LIBEND }
Procedure WriteLibEnd(Var F:File);
Var
 EndRec:Array[1..3] of Byte;
 NumWritten:Word;
Begin
 EndRec[1] := OMF_LIBEND;
 EndRec[2] := 0;
 EndRec[3] := 0;
 BlockWrite(F, EndRec, 3, NumWritten);
End;

{ Cr�ation ou mise � jour d'une biblioth�que }
Procedure CreateLibrary(OutputName:String);
Var
 OutF, InF:File;
 I:Integer;
 InputNode:PInputFileNode;
 InputName:String;
 Buffer:Array[1..4096] of Byte;
 ToRead, NumRead, NumWritten:Word;
 FileSize:LongInt;
 CurrentPos, AlignedPos, DictOffset:LongInt;
 PageSize:Word;
 Header:TLibHeader;
 ModuleOffset:LongInt;
 TempName:String;
Begin
 PageSize := 16; { Taille de page standard }
 TempName := OutputName + '.tmp';
 {$I-}
 Assign(OutF, TempName);
 Rewrite(OutF, 1);
 {$I+}
 If IOResult <> 0 Then Error('Impossible de cr�er: ' + TempName);
 { �crire un en-tête temporaire }
 WriteLibHeader(OutF, PageSize, 0, 0);
 WritePadding(OutF, FilePos(OutF), PageSize);
 CurrentPos := PageSize;
 ClearModules;
 ClearSymbols;
  { Traiter chaque fichier d'entr�e }
 InputNode := InputFilesHead;
 While InputNode <> Nil Do Begin
  InputName := InputNode^.Name;
  If UpperCase(Copy(InputName, Length(InputName) - 3, 4)) = '.LIB' Then Begin
   { C'est une bibliothèque, lire ses modules }
   ReadLibrary(InputName);
  End
   Else
  Begin
   { C'est un fichier .OBJ }
   If ShouldRemoveModule(StripExtension(ExtractFileName(InputName))) Then Begin
    If OptVerbose Then
     WriteLn('Module ignor� (supprim�): ', InputName);
    InputNode := InputNode^.Next;
    Continue;
   End;
   { Lire les informations du module }
   ReadObjFile(InputName);
   { Copier le fichier dans la biblioth�que }
   {$I-}
   Assign(InF, InputName);
   Reset(InF, 1);
   {$I+}
   If IOResult <> 0 Then Begin
    Warning('Impossible d''ouvrir: ' + InputName);
    InputNode := InputNode^.Next;
    Continue;
   End;
   { Enregistrer l'offset du module }
  If ModulesTail <> Nil Then Begin
   ModulesTail^.Data.FileOffset := CurrentPos;
   ModulesTail^.Data.PageNum := CurrentPos div PageSize;
  End;
   FileSize := System.FileSize(InF);
   While Not Eof(InF) do Begin
    BlockRead(InF, Buffer, SizeOf(Buffer), NumRead);
    BlockWrite(OutF, Buffer, NumRead, NumWritten);
   End;
   Close(InF);
  If ModulesTail <> Nil Then
   ModulesTail^.Data.Size := FileSize;
   { Aligner sur la prochaine page }
   CurrentPos := FilePos(OutF);
   AlignedPos := AlignToPage(CurrentPos, PageSize);
   WritePadding(OutF, CurrentPos, AlignedPos);
   CurrentPos := AlignedPos;
   If OptVerbose Then
    If ModulesTail <> Nil Then
     WriteLn('Module ajout�: ', ModulesTail^.Data.Name);
  End;
  InputNode := InputNode^.Next;
 End;
 { �crire le dictionnaire }
 DictOffset := FilePos(OutF);
 WriteLibDictionary(OutF);
 { �crire LIBEND }
 WriteLibEnd(OutF);
 Close(OutF);
  { R��crire l'ent�te avec les bonnes informations }
 {$I-}
 Assign(OutF, TempName);
 Reset(OutF, 1);
 {$I+}
 WriteLibHeader(OutF, PageSize, DictOffset, 1);
 Close(OutF);
 { Renommer le fichier temporaire }
 {$I-}
 Assign(InF, OutputName);
 Erase(InF);
 {$I+}
 { Ignorer le IOResult car le fichier peut ne pas exister }
 I := IOResult;
 {$I-}
 Assign(InF, TempName);
 Rename(InF, OutputName);
 {$I+}
 If IOResult <> 0 Then Error('Impossible de renommer le fichier temporaire');
 WriteLn('Biblioth�que cr��e: ', OutputName);
 WriteLn('  ', ModuleCount, ' module(s)');
 WriteLn('  ', SymbolCount, ' symbole(s)');
End;

{ Programme principal }
BEGIN
 InputFilesHead := Nil;
 InputFilesTail := Nil;
 InputFileCount := 0;
 ModulesHead := Nil;
 ModulesTail := Nil;
 ModuleCount := 0;
 SymbolsHead := Nil;
 SymbolsTail := Nil;
 SymbolCount := 0;
 ParseCommandLine;
 If ParamCount = 0 Then Begin
  ClearInputFiles;
  ClearModules;
  ClearSymbols;
  ShowHelp;
  Halt(0);
 End;
 ShowBanner;
 ClearModules;
 ClearSymbols;
  { Si /LIST ou /SYMBOLS sans fichier de sortie, afficher les informations }
 If (OptList or OptSymbols) and (InputFileCount > 0) Then Begin
    ReadLibrary(GetInputFileAt(1));
  If OptList Then ListModules;
  If OptSymbols Then ListSymbols;
 End
 { Si /EXTRACT, extraire les modules }
 Else If OptExtractCount > 0 Then Begin
  If InputFileCount > 0 Then Begin
     ReadLibrary(GetInputFileAt(1));
   For MainIdx := 1 to OptExtractCount do
      ExtractModule(OptExtract[MainIdx], GetInputFileAt(1));
  End
   Else
  Error('Aucune biblioth�que sp�cifi�e pour l''extraction');
 End
 { Sinon, cr�er ou mettre à jour une bibliothèque }
 Else If InputFileCount > 0 Then Begin
  If OptOut = '' Then Begin
   { Utiliser le premier fichier .LIB comme sortie, sinon le premier .OBJ avec extension .LIB }
   If UpperCase(Copy(GetInputFileAt(1), Length(GetInputFileAt(1)) - 3, 4)) = '.LIB' Then
    OptOut := GetInputFileAt(1)
   Else
    OptOut := StripExtension(GetInputFileAt(1)) + '.LIB';
  End;
  CreateLibrary(OptOut);
 End
  Else
 Begin
  ClearInputFiles;
    ClearModules;
    ClearSymbols;
  Error('Aucun fichier sp�cifi�');
 End;
 ClearInputFiles;
   ClearModules;
   ClearSymbols;
END.
