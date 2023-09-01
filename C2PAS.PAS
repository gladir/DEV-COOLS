{ @author: Sylvain Maltais (support@gladir.com)
  @created: 1993, 1996 et 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program C2PAS;

Uses DOS,Strings;

{$DEFINE CONSOLE}

Const
 NoUpper:Boolean=False;

Const
 IncludeFile=100;
  {Compilateur: Constante de message d'erreur}
 PointCommaExpected=10001;      { ';' attendu }
 SemicolonExpected=PointCommaExpected;
 OpenEnsExpected=10002;         (* #123 attendu *)
 CloseEnsExpected=10003;        (* #125 attendu *)
 OpenArrayExpected=10004;       { '[' attendu }
 CloseArrayExpected=10005;      { ']' attendu }
 OpenParExpected=10006;         { '(' attendu }
 CloseParExpected=10007;        { ')' attendu }
 AsterixExpected=10008;         { '*' attendu }
 NumExpected=10009;             { Nombre attendu }
 GrExpected=10010;              { '>' attendu }
 GuillExpected=10011;           { '"' attendu }
 CommaExpected=10012;           { '.' attendu }
 EnumExpected=10013;            { ênumÇration attendu }
 NumberOfArrayExpected=10014;   { Nombre de l'instruction ÆARRAYØ attendu }
 EndOfFunctionExpected=10015;   { Fin de fonction attendu }
 EndOfSourceExpected=10016;     { Fin de source attendu }
 EndOfStringExpected=10017;     { Fin de chaåne de caractäres attendu }
 EndOfCommentExpected=10018;    { Fin de commentaire attendu }
 EndOfCommandExpected=10019;    { Fin de commande attendu }
 EndOfArgumentExpected=10020;   { Fin d'argument attendu }
 TypeVarExpected=10021;         { Type de variable attendu }
 VarNameExpected=10022;         { Nom de variable attendu }
 DirectiveCommandExpected=10023;{ Directive attendu }
 TypedefNameExpected=10024;     { Nom de l'instruction ÆtypedefØ attendu }
 IncludeFileNameExpected=10025; { Nom de l'inclusion de fichier attendu }
 IfDirectNameExpected=10026;    { Nom de la directive conditionnel ÆIFØ attendu }
 IfDefDirectNameExpected=10027; { Nom de la directive conditionnel ÆIFDEFØ atetndu }
 IfNDefDirectNameExpected=10028;{ Nom de la directive conditionnel ÆIFNDEFØ atetndu }
 WhileExpected=10029;           { Instruction ÆWHILEØ attendu }
 BeginExpected=10030;           { Instruction ÆBEGINØ attendu }
 NameExpected=10031;            { Nom attendu }
 ValueExpected=10032;           { Valeur attendu }
 TypeExpected=10033;            { Type attendu }
 OfExpected=10034;              { Instruction ÆOFØ attendu }
 LabelExpected=10035;           { êtiquette attendu }
 NamePrgExpected=10036;         { Nom de programme attendu }
 UnitNameExpected=10037;        { Nom d'unitÇ attendu }
 ConstNameExpected=10038;       { Nom de constante attendu }
 EndExpected=10039;             { Instruction ÆENDØ attendu }
 ColonExpected=10040;           { Æ:Ø attendu }
 EqualExpected=10041;           { Æ=Ø attendu }
 CFExpected=10042;              { Æ_CFØ attendu...}
 IdentifierExpected=10043;      { Identificateur attendu }
 LowerExpected=10044;           { Æ<Ø attendu }
 PlusExpected=10045;            { Æ+Ø attendu }
 MinusExpected=10046;           { Æ-Ø attendu }
 VirguleExpected=10047;         { Æ,Ø attendu }
 ThenExpected=10048;            { ÆTHENØ attendu}
 DuplExpression=10049;          { Duplication d'expression }
 EnumDupl=10050;                { Duplication d'ÇnumÇration }
 VarStructDupl=10051;           { Variable de la structure dupliquÇ }
 DuplDefUnit=10052;             { Duplication de dÇfinition d'unitÇ }
 VarDupl=10053;                 { Variable dupliquÇ }
 AsExpected=10054;              { Instruction ÆASØ attendu }
 ToExpected=10055;              { ÆTOØ attendu}
 BreakPressed=10056;            { Ctrl+Break enfoncÇ }
 VarNotFound=10057;             { Variable introuvable! }
 NextWithoutFor=10058;          { ÆNEXTØ sans ÆFORØ }
 DieseExpected=10059;           { Æ#Ø_ attendu }
 InvalidFunctionCall=10060;     { Appel de fonction invalide }
 DollarExpected=10061;          { Æ$Ø attendu}
 TooManyGosub=10062;            { Trop de 'GOSUB' }
 ReturnWithoutGosub=10063;      { Instruction 'RETURN' sans instruction 'GOSUB'}
 WhileWithoutWend=10064;        { Instruction 'WHILE' sans instruction 'WEND'}
 MisplacedWend=10065;           { ÆWENDØ mal placÇ}
 ImageTooBig=10066;             { Image trop grosse }
 LabelDupl=10067;               { Duplication d'Çtiquette!!! }
 ConstDupl=10068;               { Constante dupliquÇ }
 InvalidNumber=10069;           { Nombre invalide }
 UsePascalReservedWordForVar=10070;{Utilise un mot rÇservÇ PASCAL comme variable }
 ITEMExpected=10071;            { Identificateur 'ITEM' attendu! }
 TrueExpected=10072;            { 'TRUE' attendu! }
 ExternCallExpected=10073;      { Appel externe attendu! }
 ValidIdentificatorExpected=10074;{ Identificateur valide attendu! }
 NumberExpected=10075;          { Nombre attendu }
 NumberArabicExpected=10076;    { Nombre entre 1 et 9 attendu }
 EnumEmpty=10080;               { ênumÇration vide }
 StructEmpty=10081;             { Structure vide }
 TooManyPathInHeader=10096;     { Trop de rÇpertoire dans l'entàte }
 TooManyWarning=10097;          { Trop de message d'attention }
 UnknownIdentifier=10098;       { Identificateur inconnue }
 UnknownType=10099;             { Type inconnu }
 SyntaxError=10100;             { Erreur de syntaxe }
 SyntaxNumber=10101;            { Erreur de nombre }
 SyntaxErrorRec=10102;          { Erreur de syntaxe d'un enregistrement }
 MisplacedProgram=10124;        { ÆPROGRAMØ mal placÇ }
 MisplacedNext=10125;           { ÆNEXTØ mal placÇ }
 MisplacedElse=10126;           { ÆELSEØ mal placÇ }
 MisplacedBeginSymbol=10127;    { ÆBEGINØ mal placÇ }
 MisplacedCondDirective=10128;  { Directive conditionnel mal placÇ }
 MisplacedEndSymbol=10129;      { Fin de symbole mal placÇ }
 MisplacedPointComma=10130;     { ';' mal placÇ }
 MisplacedUnit=10131;           { ÆUNITØ mal placÇ }
 MisplacedUses=10132;           { ÆUSESØ mal placÇ }
 MisplacedInterface=10133;      { ÆINTERFACEØ mal placÇ }
 MisplacedImplementation=10134; { ÆIMPLEMENTATIONØ mal placÇ }
 MisplacedInitialization=10135; { ÆINITIALIZATIONØ mal placÇ }
 MisplacedFinalization=10136;   { ÆFINALIZATIONØ mal plac, }
 TooManyBoucle=10139;           { Trop de boucle }
 TooBigNumber=10140;            { Nombre trop grand }
 TypeMistmatch=10141;           { Type incompatible }
 OpCode186=10150 ;              { Instruction pour 80186 }
 OpCode286=10151;               { Instruction pour 80286 }
 OpCode287=10152;               { Instruction coprocesseur mathÇmatique 80287 }
 OpCode386=10153;               { Instruction pour 80386 }
 OpCode387=10154;               { Instruction coprocesseur mathÇmatique 80387 }
 OverloadIndex=10180;           { DÇpassement d'index! }
 UnitNotFound=10198;            { UnitÇ introuvable! }
 FileNotOpen=10199;             { Fichier non ouvert }
 FileNotFound=10200;            { Fichier introuvable }
 CannotCreateFile=10201;        { Impossible de crÇer le fichier }
 FileReadError=10202;           { Erreur de lecture du fichier }
 OutOfMemory=10254;             { Manque de mÇmoire }
 InternalError=10255;           { Erreur interne }
 ErrorParamInternal=10256;      { Erreur de paramätre interne }
 ResFileNoSpecified=10401;      { Fichier ressource non spÇcifiÇ }
  { Compilateur: Constante de message d'attention }
 SkipDefineFar=-1;              { DÇfinition ÆFARØ sans effet }
 SkipDefineSizeOf=-2;           { DÇfinition ÆSizeOfØ sans effet }
 DuplicateDefineSymbol=-3;      { Duplication de symbole de dÇfinition }
 WrongValueInDefineDirective=-4;{ Mauvaise valeur dans la ÆDEFINEØ conditionnelle }

 SpcCode=[' ',#9];
 MinRomanLetter=['a'..'z'];
 MajRomanLetter=['A'..'Z'];
 BinArabicDigit=['0'..'1'];
 OctArabicDigit=['0'..'7'];
 ArabicDigit=['0'..'9'];
 ArabicXDigit=['0'..'9','A'..'F','a'..'f'];
 Coder1DefLetter=['A'..'Z','a'..'z','_'];
 CoderDefLetter=['A'..'Z','a'..'z','0'..'9','_'];

 PathHeader='C:\TP\INCLUDE';
  ProcBuffer:Array[0..46,0..1]of PChar=(
   ('AcosAsin','[x{bits16}>d]d'),
   ('abs','[i]i'),
   ('acos','[d]d'),
   ('bdos','[BwB]i'),
   ('bdosptr','[B<B]i'),
   ('country_','[B>{COUNTRY}]{PCOUNTRY}'),
   ('bioscom','[BBi]i'),
   ('biosdisk','[BcBwB<]'),
   ('biosequip','[]i'),
   ('biosmemory','[]i'),
   ('biosprint','[BBi]b'),
   ('chdir','[x]i'),
   ('dosexterr','[>{DOSERROR}]i'),
   ('farcoreleft','[]l'),
   ('free','[>p]'),
   ('getcurdir','[cx]i]'),
   ('isalnum','[c]b'),
   ('isalpha','[c]b'),
   ('iscntrl','[c]b'),
   ('isdigit','[c]b'),
   ('islower','[c]b'),
   ('isprint','[c]b'),
   ('ispunct','[c]b'),
   ('isspace','[c]b'),
   ('isupper','[c]b'),
   ('isxdigit','[c]b'),
   ('lock','[ill]i'),
   ('malloc','[w]p'),
   ('memchr','[<xw]b'),
   ('memcpy','[<<w]'),
   ('setftime','[i>{ftime}]i'),
   ('strupr','[x]x'),
   ('swab','[>B>Bi]'),
   ('toascii','[c]c'),
   ('tolower','[c]c'),
   ('toupper','[c]c'),
   ('Funlink','[x]i'),
   ('Funlock','[ill]i'),
   ('_chmod','[xBi]i'),
   ('_clear87','[]w'),
   ('_control87','[ww]w'),
   ('_dos_getftime','[i>w>w]w'),
   ('_dos_read','[i<w>w]w'),
   ('_dos_setftime','[iww]w'),
   ('_status87','[]w'),
   ('F_tolower','[c]c'),
   ('_toupper','[c]c'));

Type
 BooleanDirectivePtr=^BooleanDirectiveRecord;
 BooleanDirectiveRecord=Record
  Name:PChar;
  Value:Boolean;
 End;

Type
 PCharByteRec=Record
  PChr:PChar;
  Nm:Byte;
 End;

 StrByteRec=Record
  PChr:PChar;
  Nm:Byte;
  Len:Word;
 End;

 StrWordRec = Record
  PChr:PChar;
  Nm,Len:Word;
 End;

 PCharWordRec = Record
  PChr:PChar;
  Nm:Word;
 End;

 RBufPtr = ^RBufRec;

 RBufRec = Record
  Buf:Pointer;
  Size:Word;
  Previous,Next:RBufPtr;
 End;

 ArrayList = Record
  PCurrPtr,Count:LongInt;
  CurrPtr,List,EndListPtr:RBufPtr;
 End;

Const
 MinRec=SizeOf(PCharWordRec)+1;

{$IFDEF FPC}
Function MaxAvail:LongInt;Begin
 MaxAvail:=High(LongInt);
End;

Function MemAvail:LongInt;Begin
 MemAvail:=High(LongInt);
End;
{$ENDIF}

Function GetErrMsg(Err:Integer):String;Begin
 Case Err of
  PointCommaExpected:GetErrMsg:=''';'' attendu';
  OpenEnsExpected:GetErrMsg:='{ attendu';
  CloseEnsExpected:GetErrMsg:='} attendu';
  OpenArrayExpected:GetErrMsg:='''['' attendu';
  CloseArrayExpected:GetErrMsg:=''']'' attendu';
  OpenParExpected:GetErrMsg:='''('' attendu';
  CloseParExpected:GetErrMsg:=''')'' attendu';
  AsterixExpected:GetErrMsg:='''*'' attendu';
  NumExpected:GetErrMsg:='Nombre attendu';
  GrExpected:GetErrMsg:='''>'' attendu';
  GuillExpected:GetErrMsg:='''"'' attendu';
  CommaExpected:GetErrMsg:='''.'' attendu';
  EnumExpected:GetErrMsg:='ênumÇration attendu';
  NumberOfArrayExpected:GetErrMsg:='Nombre de l''instruction ÆARRAYØ attendu';
  EndOfFunctionExpected:GetErrMsg:='Fin de fonction attendu';
  EndOfSourceExpected:GetErrMsg:='Fin de source attendu';
  EndOfStringExpected:GetErrMsg:='Fin de chaåne de caractäres attendu';
  EndOfCommentExpected:GetErrMsg:='Fin de commentaire attendu';
  EndOfCommandExpected:GetErrMsg:='Fin de commande attendu';
  EndOfArgumentExpected:GetErrMsg:='Fin d''argument attendu';
  TypeVarExpected:GetErrMsg:='Type de variable attendu';
  VarNameExpected:GetErrMsg:='Nom de variable attendu';
  DirectiveCommandExpected:GetErrMsg:='Directive attendu';
  TypedefNameExpected:GetErrMsg:='Nom de l''instruction ÆtypedefØ attendu';
  IncludeFileNameExpected:GetErrMsg:='Nom de l''inclusion de fichier attendu';
  IfDirectNameExpected:GetErrMsg:='Nom de la directive conditionnel ÆIFØ attendu';
  IfDefDirectNameExpected:GetErrMsg:='Nom de la directive conditionnel ÆIFDEFØ attendu';
  IfNDefDirectNameExpected:GetErrMsg:='Nom de la directive conditionnel ÆIFNDEFØ attendu';
  WhileExpected:GetErrMsg:='Instruction ÆWHILEØ attendu';
  BeginExpected:GetErrMsg:='Instruction ÆBEGINØ attendu';
  NameExpected:GetErrMsg:='Nom attendu';
  ValueExpected:GetErrMsg:='Valeur attendu';
  TypeExpected:GetErrMsg:='Type attendu';
  OfExpected:GetErrMsg:='Instruction ÆOFØ attendu';
  LabelExpected:GetErrMsg:='êtiquette attendu';
  NamePrgExpected:GetErrMsg:='Nom de programme attendu';
  UnitNameExpected:GetErrMsg:='Nom d''unitÇ attendu';
  ConstNameExpected:GetErrMsg:='Nom de constante attendu';
  EndExpected:GetErrMsg:='Instruction ÆENDØ attendu';
  ColonExpected:GetErrMsg:='Æ:Ø attendu';
  EqualExpected:GetErrMsg:='Æ=Ø attendu';
  CFExpected:GetErrMsg:='Æ_CFØ attendu...';
  IdentifierExpected:GetErrMsg:='Identificateur attendu';
  LowerExpected:GetErrMsg:='Æ<Ø attendu';
  PlusExpected:GetErrMsg:='Æ+Ø attendu';
  MinusExpected:GetErrMsg:='Æ-Ø attendu';
  VirguleExpected:GetErrMsg:='Æ,Ø attendu';
  ThenExpected:GetErrMsg:='ÆTHENØ attendu';
  DuplExpression:GetErrMsg:='Duplication d''expression';
  EnumDupl:GetErrMsg:='Duplication d''ÇnumÇration';
  VarStructDupl:GetErrMsg:='Variable de la structure dupliquÇ';
  DuplDefUnit:GetErrMsg:='Duplication de dÇfinition d''unitÇ';
  VarDupl:GetErrMsg:='Variable dupliquÇ';
  AsExpected:GetErrMsg:='Instruction ÆASØ attendu';
  ToExpected:GetErrMsg:='ÆTOØ attendu';
  BreakPressed:GetErrMsg:='Ctrl+Break enfoncÇ';
  VarNotFound:GetErrMsg:='Variable introuvable!';
  NextWithoutFor:GetErrMsg:='ÆNEXTØ sans ÆFORØ';
  DieseExpected:GetErrMsg:='Æ#Ø_ attendu';
  InvalidFunctionCall:GetErrMsg:='Appel de fonction invalide';
  DollarExpected:GetErrMsg:='Æ$Ø attendu';
  TooManyGosub:GetErrMsg:='Trop de ''GOSUB''';
  ReturnWithoutGosub:GetErrMsg:='Instruction ''RETURN'' sans instruction ''GOSUB''';
  WhileWithoutWend:GetErrMsg:='Instruction ''WHILE'' sans instruction ''WEND''';
  MisplacedWend:GetErrMsg:='ÆWENDØ mal placÇ';
  ImageTooBig:GetErrMsg:='Image trop grosse';
  LabelDupl:GetErrMsg:='Duplication d''Çtiquette!!!';
  ConstDupl:GetErrMsg:='Constante dupliquÇ';
  InvalidNumber:GetErrMsg:='Nombre invalide';
  UsePascalReservedWordForVar:GetErrMsg:='Utilise un mot rÇservÇ PASCAL comme variable';
  ITEMExpected:GetErrMsg:='Identificateur ''ITEM'' attendu!';
  TrueExpected:GetErrMsg:='''TRUE'' attendu!';
  ExternCallExpected:GetErrMsg:='Appel externe attendu!';
  ValidIdentificatorExpected:GetErrMsg:='Identificateur valide attendu!';
  NumberExpected:GetErrMsg:='Nombre attendu';
  NumberArabicExpected:GetErrMsg:='Nombre entre 1 et 9 attendu';
  EnumEmpty:GetErrMsg:='ênumÇration vide';
  StructEmpty:GetErrMsg:='Structure vide';
  TooManyPathInHeader:GetErrMsg:='Trop de rÇpertoire dans l''entàte';
  TooManyWarning:GetErrMsg:='Trop de message d''attention';
  UnknownIdentifier:GetErrMsg:='Identificateur inconnue';
  UnknownType:GetErrMsg:='Type inconnu';
  SyntaxError:GetErrMsg:='Erreur de syntaxe';
  SyntaxNumber:GetErrMsg:='Erreur de nombre';
  SyntaxErrorRec:GetErrMsg:='Erreur de syntaxe d''un enregistrement';
  MisplacedProgram:GetErrMsg:='ÆPROGRAMØ mal placÇ';
  MisplacedNext:GetErrMsg:='ÆNEXTØ mal placÇ';
  MisplacedElse:GetErrMsg:='ÆELSEØ mal placÇ';
  MisplacedBeginSymbol:GetErrMsg:='ÆBEGINØ mal placÇ';
  MisplacedCondDirective:GetErrMsg:='Directive conditionnel mal placÇ';
  MisplacedEndSymbol:GetErrMsg:='Fin de symbole mal placÇ';
  MisplacedPointComma:GetErrMsg:=''';'' mal placÇ';
  MisplacedUnit:GetErrMsg:='ÆUNITØ mal placÇ';
  MisplacedUses:GetErrMsg:='ÆUSESØ mal placÇ';
  MisplacedInterface:GetErrMsg:='ÆINTERFACEØ mal placÇ';
  MisplacedImplementation:GetErrMsg:='ÆIMPLEMENTATIONØ mal placÇ';
  MisplacedInitialization:GetErrMsg:='ÆINITIALIZATIONØ mal placÇ';
  MisplacedFinalization:GetErrMsg:='ÆFINALIZATIONØ mal placÇ';
  TooManyBoucle:GetErrMsg:='Trop de boucle';
  TooBigNumber:GetErrMsg:='Nombre trop grand';
  TypeMistmatch:GetErrMsg:='Type incompatible';
  OpCode186:GetErrMsg:='Instruction pour 80186';
  OpCode286:GetErrMsg:='Instruction pour 80286';
  OpCode287:GetErrMsg:='Instruction coprocesseur mathÇmatique 80287';
  OpCode386:GetErrMsg:='Instruction pour 80386';
  OpCode387:GetErrMsg:='Instruction coprocesseur mathÇmatique 80387';
  OverloadIndex:GetErrMsg:='DÇpassement d''index!';
  UnitNotFound:GetErrMsg:='UnitÇ introuvable!';
  FileNotOpen:GetErrMsg:='Fichier non ouvert';
  FileNotFound:GetErrMsg:='Fichier introuvable';
  CannotCreateFile:GetErrMsg:='Impossible de crÇer le fichier';
  FileReadError:GetErrMsg:='Erreur de lecture du fichier';
  OutOfMemory:GetErrMsg:='Manque de mÇmoire';
  InternalError:GetErrMsg:='Erreur interne';
  ErrorParamInternal:GetErrMsg:='Erreur de paramätre interne';
  ResFileNoSpecified:GetErrMsg:='Fichier ressource non spÇcifiÇ';
  Else GetErrMsg:='Erreur inconnu';
 End;
End;

Function FileExist(Name:String):Boolean;
Var
 Info:SearchRec;
Begin
 FindFirst(Name,$FFFF,Info);
 FileExist:=DOSError=0;
End;

Function DuplicateString(C:Char;Num:Integer):String;
Var
 I:Byte;
 S:String;
Begin
 S:='';
 For I:=1 to Num do S:=S+C;
 DuplicateString:=S;
End;

Function PadRight(S:String;Space:Byte):String;
Var
 I:Byte;
Begin
 If Length(S)<Space Then For I:=Length(S)+1 to Space do S:=S+' ';
 PadRight:=S;
End;

Function MemAlloc(Size:Word):Pointer;
Var Ptr:Pointer;
Begin
 MemAlloc := NIL;
 If(Size = 0)Then Exit;
 If(MaxAvail < Size)Then Exit;
 GetMem(Ptr,Size);
 MemAlloc := Ptr;
End;

Function MemNew(Size:Word):Pointer;
Var
 Ptr:Pointer;
Begin
 Ptr:=MemAlloc(Size);
 If(Ptr<>NIL)Then FillChar(Ptr^,Size,0);
 MemNew:=Ptr;
End;

Function NewBlock(Var Buf;Size:Word):Pointer;
Var
 Ptr:Pointer;
Begin
 Ptr:=MemAlloc(Size);
 If(Ptr<>NIL)Then Move(Buf,Ptr^,Size);
 NewBlock:=Ptr;
End;

Procedure ArrayListInit(Var Q:ArrayList);Begin
 Q.PCurrPtr:=-1;
 Q.CurrPtr:=NIL;
 Q.List:=NIL;
 Q.EndListPtr:=NIL;
 Q.Count:=0;
End;

Function ArrayListIsEmpty(Var Q:ArrayList):Boolean;
Begin
 ArrayListIsEmpty := (Q.List = NIL);
End;

Function ArrayListAdd(Var Q:ArrayList;Size:Word):Pointer;
Var
 W:RBufRec;
 WPtr:RBufPtr;
 Addr:Pointer;
Begin
 ArrayListAdd:=NIL;
 FillChar(W,SizeOf(W),0);
 If Size>0Then Begin
  Addr:=MemAlloc(Size);
  If(Addr=NIL)Then Exit;
  W.Buf:=Addr;
  W.Size:=Size
 End;
 If(Q.List=NIL)Then Begin
  Q.List:=NewBlock(W,SizeOf(RBufRec));
  If(Q.List=NIL)Then Exit;
  Q.EndListPtr:=Q.List
 End
  Else
 Begin
  WPtr:=Q.EndListPtr;
  If(WPtr=NIL)Then Exit;
  W.Previous:=WPtr;
  WPtr^.Next:=NewBlock(W,SizeOf(RBufRec));
  Q.EndListPtr:=WPtr^.Next;
 End;
 Inc(Q.Count);
 ArrayListAdd:=Addr
End;

Function ArrayListAddBuf(Var Q:ArrayList;Size:Word;Const Block):Boolean;
Var
 Ptr:Pointer;
Begin
 ArrayListAddBuf:=False;
 Ptr:=ArrayListAdd(Q,Size);
 If(Ptr<>NIL)Then Begin
  Move(Block,Ptr^,Size);
  ArrayListAddBuf:=True;
 End;
End;

Function ArrayList_AddBuf(Var Q:ArrayList;Size:Word):Pointer;
Var Ptr:Pointer;
Begin
 ArrayList_AddBuf := NIL;
 If Not(ArrayListAddBuf(Q,Size,Ptr))Then Exit;
 ArrayList_AddBuf := Ptr;
End;

Function ArrayList_SetPtr(Var Q:ArrayList;P:LongInt):Pointer;
Var
 WP:RBufPtr;
 I:LongInt;
Begin
 WP:=Q.List;
 For I:=1to(P)do Begin
  WP:=WP^.Next;
  If(WP=NIL)Then Begin
   ArrayList_SetPtr:=NIL;
   Exit;
  End;
 End;
 ArrayList_SetPtr:=WP
End;


Function ArrayListIns(Var Q:ArrayList;P:LongInt;Size:Word):Pointer;
Var
 WP,NewP:RBufPtr;
 Addr:Pointer;
Begin
 ArrayListIns:=NIL;
 If(P>Q.Count)Then Exit;
 If(P=Q.Count)Then ArrayListIns:=ArrayListAdd(Q,Size)
  else
 Begin
  Addr:=NIL;
  If P=0Then Begin
   WP:=MemNew(SizeOf(Q.List^));
   If(WP=NIL)Then Exit;
   Q.List^.Previous:=WP;WP^.Next:=Q.List;
   If Size>0Then Begin
    Addr:=MemAlloc(Size);
    If(Addr=NIL)Then Exit;
    WP^.Buf:=Addr;WP^.Size:=Size
   End;
   Q.List:=WP
  End
   else
  Begin
   NewP:=MemNew(SizeOf(Q.List^));
   If(NewP=NIL)Then Exit;
   WP:=ArrayList_SetPtr(Q,P);
   If(WP=NIL)Then Exit;
   NewP^.Next:=WP;
   NewP^.Previous:=WP^.Previous;
   If Size>0Then Begin
    Addr:=MemAlloc(Size);
    If(Addr=NIL)Then Exit;
    NewP^.Buf:=Addr;
    NewP^.Size:=Size
   End;
   WP^.Previous^.Next:=NewP;
   WP^.Previous:=NewP
  End;
  Inc(Q.Count);
  ArrayListIns:=Addr
 End
End;

Function ArrayListInsBlock(Var Q:ArrayList;P:LongInt;Size:Word;Const Block):Boolean;
Var
 Ptr:Pointer;
Begin
 ArrayListInsBlock:=False;
 Ptr:=ArrayListIns(Q,P,Size);
 If(Ptr<>NIL)Then Begin
  Move(Block,Ptr^,Size);
  ArrayListInsBlock:=True;
 End;
End;


Function ArrayListInsBuf(Var Q:ArrayList;P:LongInt;Size:Word;Var Addr:Pointer):Boolean;
Var WP,NewP:RBufPtr; I:LongInt;
Begin
 ArrayListInsBuf := False;
 If(P > Q.Count)Then Exit;
 If(P = Q.Count)Then ArrayListInsBuf := ArrayListAddBuf(Q,Size,Addr)
  else
 Begin
  ArrayListInsBuf := False;
  If(P = 0)Then
  Begin
   WP := MemAlloc(SizeOf(Q.List^));
   If(WP = NIL)Then Exit;
   Q.List^.Previous := WP; WP^.Previous := NIL; WP^.Next := Q.List;
   If(Size = 0)Then
   Begin
    WP^.Buf := NIL; WP^.Size := 0; Addr := NIL;
   End
    Else
   Begin
    Addr := MemAlloc(Size);
    If(Addr = NIL)Then Exit;
    WP^.Buf := Addr; WP^.Size := Size;
   End;
   Q.List := WP;
  End
   else
  Begin
   NewP := MemAlloc(SizeOf(Q.List^));
   If(NewP = NIL)Then Exit;
   WP := Q.List;
   For I := 1 to P do
   Begin
    If(WP = NIL)Then Exit;
    WP := WP^.Next;
   End;
   NewP^.Next := WP; NewP^.Previous := WP^.Previous;
   If(Size = 0)Then
   Begin
    NewP^.Buf := NIL; NewP^.Size := 0; Addr := NIL;
   End
    Else
   Begin
    Addr := MemAlloc(Size);
    If(Addr = NIL)Then Exit;
    NewP^.Buf := Addr; NewP^.Size := Size;
   End;
   WP^.Previous^.Next := NewP; WP^.Previous := NewP;
  End;
  Inc(Q.Count); ArrayListInsBuf := True;
 End;
End;

Function ArrayListAddPChr(Var Q:ArrayList;PChr:PChar):Boolean;
Type
 TChar=Array[0..32767]of Char;
Var
 PBuf:^TChar;
 L:Word;
Begin
 ArrayListAddPChr:=False;
 L:=StrLen(PChr)+1;
 PBuf:=ArrayListAdd(Q,L);
 If(PBuf=NIL)Then Exit;
 If L=1Then PBuf^[0]:=#0
       Else Move(PChr^,PBuf^,L);
 ArrayListAddPChr:=True
End;

Function ArrayListAddPChrByte(Var Q:ArrayList;PChr:PChar;Num:Byte):Boolean;
Var PCharByte:^PCharByteRec; Ptr:Pointer;
Begin
 ArrayListAddPChrByte := False;
 If Not(ArrayListAddBuf(Q,SizeOf(PCharByteRec),Ptr))Then Exit;
 PCharByte := Ptr; PCharByte^.PChr := PChr; PCHarByte^.Nm := Num;
 ArrayListAddPChrByte := True;
End;

Function ArrayListAddStrByte(Var Q:ArrayList;Str:String;Num:Byte):Boolean;
Var StrByte:^StrByteRec; Ptr:Pointer; PChr:Array[0..255] of Char;
Begin
 ArrayListAddStrByte := False;
 If Not(ArrayListAddBuf(Q,SizeOf(StrByteRec),Ptr))Then Exit;
 StrByte := Ptr; StrPCopy(PChr,Str); StrByte^.PChr := StrNew(PChr);
 StrByte^.Len := Length(Str); StrByte^.Nm := Num; ArrayListAddStrByte := True;
End;

Function ArrayListAddStrWord(Var Q:ArrayList;Str:String;Num:Word):Boolean;
Var StrWord:^StrWordRec; Ptr:Pointer; PChr:Array[0..255] of Char;
Begin
 ArrayListAddStrWord := False;
 If Not(ArrayListAddBuf(Q,SizeOf(StrWordRec),Ptr))Then Exit;
 StrWord := Ptr; StrPCopy(PChr,Str); StrWord^.PChr := StrNew(PChr);
 StrWord^.Len := Length(Str); StrWord^.Nm := Num; ArrayListAddStrWord := True;
End;

Function ArrayListAddLn(Var Q:ArrayList):Boolean;
Begin
 ArrayListAddLn := ArrayListAddPChr(Q,NIL);
End;

Function ArrayListAddStr(Var Q:ArrayList;Const Str:String):Boolean;
Var
 Ptr:Pointer;
 PC:PChar Absolute Ptr;
 Size:Word;
Begin
 If Length(Str)=0Then ArrayListAddStr:=ArrayListAddLn(Q)
  Else
 Begin
  ArrayListAddStr:=False;
  Size:=Length(Str)+1;
  If(Size<MinRec)Then Size:=MinRec;
  Ptr:=ArrayListAdd(Q,Size);
  If(Ptr=NIL)Then Exit;
  StrPCopy(PC,Str);
  ArrayListAddStr:=True
 End;
End;

Function ArrayListInsStr(Var Q:ArrayList;P:LongInt;Str:String):Boolean;
Var Ptr:Pointer; PChr:PChar; Size:Word;
Begin
 ArrayListInsStr := False; Size := Length(Str)+1;
 If(Size < 32)Then Size := 32;
 If Not(ArrayListInsBuf(Q,P,Size,Ptr))Then Exit;
 If(Ptr = NIL)Then Exit;
 PChr := Ptr; StrPCopy(PChr,Str); ArrayListInsStr := True;
End;

Function ArrayListInsStrWord(Var Q:ArrayList;P:LongInt;Str:String;Num:Word):Boolean;
Var StrWord:^StrWordRec; Ptr:Pointer; PChr:Array[0..255] of Char;
Begin
 ArrayListInsStrWord := False;
 If Not(ArrayListInsBuf(Q,P,SizeOf(StrWordRec),Ptr))Then Exit;
 StrWord := Ptr; StrPCopy(PChr,Str);
 StrWord^.PChr := StrNew(PChr); StrWord^.Len := Length(Str);
 StrWord^.Nm := Num; ArrayListInsStrWord := True;
End;

Function ArrayListAddPChrWord(Var Q:ArrayList;PChr:PChar;Num:Word):Boolean;
Var PCharWord:^PCharWordRec; Ptr:Pointer;
Begin
 ArrayListAddPChrWord := False;
 If Not(ArrayListAddBuf(Q,SizeOf(PCharWordRec),Ptr))Then Exit;
 PCharWord := Ptr; PCharWord^.PChr := PChr;
 PCHarWord^.Nm := Num; ArrayListAddPChrWord := True;
End;

Function ArrayListGetBuf(Var Q:ArrayList;P:LongInt;Var Size:Word):Pointer;
Var WP:RBufPtr; I:LongInt;
Begin
 Size := 0; ArrayListGetBuf := Nil;
 If(P < 0)or(P >= Q.Count)Then Exit;
 If(P = 0)Then
 Begin
  ArrayListGetBuf := Q.List^.Buf; Size := Q.List^.Size;
 End
  Else
 Begin
  WP := Q.List;
  For I := 1 to P do
  Begin
   If(WP = NIL)Then Exit;
   WP := WP^.Next;
  End;
  If(WP = NIL)Then Exit;
  ArrayListGetBuf := WP^.Buf; Size := WP^.Size;
 End;
End;

Procedure ArrayListPrevious(Var Q:ArrayList);Begin
 If Not(Q.CurrPtr = NIL)Then
 Begin
  Q.CurrPtr := Q.CurrPtr^.Previous;
  Dec(Q.PCurrPtr);
 End;
End;

Procedure ArrayListNext(Var Q:ArrayList);Begin
 If Not(Q.CurrPtr = NIL)Then
 Begin
  Q.CurrPtr := Q.CurrPtr^.Next;
  Inc(Q.PCurrPtr);
 End;
End;

Procedure ArrayListSetPtr(Var Q:ArrayList;P:LongInt);
Var WP:RBufPtr; I:LongInt;
Begin
 If(P = 0)Then
 Begin
  Q.PCurrPtr := 0; Q.CurrPtr := Q.List;
 End
  else
 If Not(Q.PCurrPtr = P)Then
 Begin
  If(Q.PCurrPtr - 1 = P)Then ArrayListPrevious(Q) else
  If(Q.PCurrPtr + 1 = P)Then ArrayListNext(Q)
   else
  Begin
   WP := Q.List;
   If(P > 0)Then For I := 1 to P do
   Begin
    If(WP = NIL)Then Exit;
    WP := WP^.Next;
   End;
   If(WP = NIL)Then Exit;
   Q.PCurrPtr := P;
   Q.CurrPtr  := WP;
  End;
 End;
End;

Function ArrayList_GetCurrBuf(Var Q:ArrayList):Pointer;Begin
 If(Q.CurrPtr = NIL)Then ArrayList_GetCurrBuf := NIL Else ArrayList_GetCurrBuf := Q.CurrPtr^.Buf;
End;

Function ArrayListGetCurrBuf(Var Q:ArrayList;Var Size:Word):Pointer;Begin
 If(Q.CurrPtr = NIL)Then
 Begin
  ArrayListGetCurrBuf := NIL; Size := 0;
 End
  Else
 Begin
  ArrayListGetCurrBuf := Q.CurrPtr^.Buf; Size := Q.CurrPtr^.Size;
 End;
End;

Function ArrayList_GetBuf(Var Q:ArrayList;P:LongInt):Pointer;
Var Size:Word;
Begin
 ArrayList_GetBuf := ArrayListGetBuf(Q,P,Size);
End;

Function ArrayListGetCurrStr(Var Q:ArrayList):String;Begin
 ArrayListGetCurrStr := StrPas(ArrayList_GetCurrBuf(Q));
End;

Function ArrayList_GetStr(Var Q:ArrayList;P:LongInt):String;Begin
 ArrayList_GetStr := StrPas(ArrayList_GetBuf(Q,P));
End;

Function ArrayListRemoveAt(Var Q:ArrayList;P:LongInt):Boolean;
Var WP:RBufPtr; I:LongInt;
Begin
 ArrayListRemoveAt := False;
 If(Q.Count = 0)or(P < 0)or(P >= Q.Count)Then Exit;
 If(P = 0)Then
 Begin
  If(Q.List = NIL)Then Exit;
  WP := Q.List;
  FreeMem(WP^.Buf,WP^.Size);
  FreeMem(WP,SizeOf(WP^));
  If(Q.Count > 1)Then
  Begin
   If(Q.List^.Next = NIL)Then Exit;
   WP^.Next^.Previous := NIL; Q.List := Q.List^.Next; Q.CurrPtr := NIL;
   Q.PCurrPtr := -1; Dec(Q.Count); ArrayListRemoveAt := True;
   Exit;
  End
   else
  Begin
   Q.PCurrPtr := -1; Q.CurrPtr := NIL; Q.List := NIL; Q.EndListPtr := NIL;
   Q.Count := 0; ArrayListRemoveAt := True;
   Exit;
  End;
 End
  else
 Begin
  WP := Q.List;
  For I := 1 to P do
  Begin
   If(WP = NIL)Then Exit;
   WP := WP^.Next;
  End;
  If(WP = NIL)Then Exit;
  If(Q.Count - 1 = P)Then
  Begin
   Q.EndListPtr := WP^.Previous; WP^.Previous^.Next := NIL;
  End
   Else
  Begin
   WP^.Next^.Previous := WP^.Previous; WP^.Previous^.Next := WP^.Next;
  End;
  FreeMem(WP^.Buf,WP^.Size);
  FreeMem(WP,SizeOf(Q.List^));
  Dec(Q.Count);
  ArrayListRemoveAt := True;
 End;
End;

Function ArrayListSetBuf(Var Q:ArrayList;P:LongInt;Size:Word;Var Addr:Pointer):Boolean;
Var WP:RBufPtr; I:LongInt;
Begin
 ArrayListSetBuf := False;
 If(P < 0)or(P > Q.Count)Then Exit;
 If(P = Q.Count)Then
 Begin
  ArrayListSetBuf := ArrayListAddBuf(Q,Size,Addr);
  Exit;
 End;
 If(P = 0)Then
 Begin
  FreeMem(Q.List^.Buf,Q.List^.Size);
  If(Size = 0)Then
  Begin
   Q.List^.Buf := NIL; Q.List^.Size := 0;
  End
   Else
  Begin
   Addr := MemAlloc(Size);
   If(Addr = NIL)Then Exit;
   Q.List^.Buf := Addr; Q.List^.Size := Size;
  End;
  ArrayListSetBuf := True;
  Exit;
 End;
 WP := Q.List;
 For I := 1 to P do
 Begin
  If(WP = NIL)Then Exit;
  WP := WP^.Next;
 End;
 FreeMem(WP^.Buf,WP^.Size);
 If(Size = 0)Then
 Begin
  WP^.Buf := NIL; WP^.Size := 0;
 End
  Else
 Begin
  Addr := MemAlloc(Size);
  If(Addr = NIL)Then Exit;
  WP^.Buf := Addr; WP^.Size := Size;
 End;
 ArrayListSetBuf := True;
End;

Function ArrayList_SetBuf(Var Q:ArrayList;P:LongInt;Size:Word):Pointer;
Var Ptr:Pointer;
Begin
 ArrayList_SetBuf := NIL;
 If Not(ArrayListSetBuf(Q,P,Size,Ptr))Then Exit;
 ArrayList_SetBuf := Ptr;
End;

Function ArrayListCount(Var Q:ArrayList):LongInt;Begin
 ArrayListCount := Q.Count;
End;

Function ArrayListMaxList(Var Q:ArrayList):LongInt;Begin
 ArrayListMaxList := Q.Count - 1;
End;

Procedure ArrayListPopCurrPtr(Var Q:ArrayList;Addr:Pointer);Begin
 Q.CurrPtr:=Addr;
End;

Procedure ArrayListDone(Var Q:ArrayList);
Var WP:RBufPtr; Ptr:^StrByteRec;
Begin
 WP := Q.List;
 While Not(WP = NIL) do
 Begin
  If(WP^.Size = SizeOf(StrByteRec))Then
  Begin
   Ptr := WP^.Buf;
   StrDispose(Ptr^.PChr);
  End;
  FreeMem(WP^.Buf,WP^.Size);
  FreeMem(WP,SizeOf(RBufRec));
  WP := WP^.Next;
 End;
End;

Function BDAdd(Var Inf:ArrayList;Const Name:String;Value:Boolean):Boolean;Forward;
Function BDSearchValue(Var Inf:ArrayList;Const Name:String):Boolean;Forward;
Function BWWordExist(Var Inf:ArrayList;Const Name:String):Boolean;Forward;

Type
 ModeType=(_Label_,_Const_,_Type_,_Var_,_None_);

 BankVarPtr=^BankVarRec;
 BankVarRec=Record
  Name,TypeVar:PChar;
  Previous,Next:BankVarPtr;
 End;

 BankVar=Record
  List,EndList:BankVarPtr;
 End;

 SwitchC2Pascal=Record
  HandleC:Text;
  HandlePas:Text;
  NameC,PathHeader,Output:String;
  L:LongInt;
  I:Byte;
  WarPos:Byte;
  Mode:ModeType;
  Warning:Array[Byte]of Record
   Line:Word;
   War:Integer;
  End;
  SourceName:String;
  Line:String;
  BoolDir:ArrayList;
  SYS_Types,StdDef:Boolean;
  WarningMsg,Rem:Boolean;
  CondIf,OvrEndIf:Byte;
  Beg:Word;
 End;

 PackProcPtr=^PackProcRecord;
 PackProcRecord=Record
  Name:PChar;
  Func:Boolean;
  FuncType:PChar;
  Previous,Next:PackProcPtr;
 End;

 PackProc=Record
  List:PackProcPtr;
  EndList:PackProcPtr;
 End;

Var
 LineNum:LongInt;
 WarnNum:LongInt;

Procedure BVInit(Var Q:BankVar);Forward;
Function  BVAdd(Var Q:BankVar;Const Name,TypeVar:String):Boolean;Forward;
Function  BVWordExist(Var Q:BankVar;Const Name:String):Boolean;Forward;
Function  BVGetMaxWord(Var Q:BankVar):Integer;Forward;
Procedure BVGetWord(Var Q:BankVar;N:Word;Var Name,TypeVar:String);Forward;
Procedure BVDone(Var Q:BankVar);Forward;
Procedure PPInit(Var K:PackProc);Forward;
Procedure PPPushProc(Var K:PackProc;Q:SwitchC2Pascal;Const Name:String);Forward;
Procedure PPPushFunc(Var K:PackProc;Q:SwitchC2Pascal;Const Name:String;FuncType:String);Forward;
Function  PPGetLastProcName(Var K:PackProc):String;Forward;
Procedure PPDone(Var K:PackProc);Forward;

Function BDAdd(Var Inf:ArrayList;Const Name:String;Value:Boolean):Boolean;
Var
 Ptr:Pointer;
 BMC:BooleanDirectiveRecord;
 PName:PChar;
Begin
 BDAdd:=False; PName:=MemAlloc(Length(Name)+1);
 If(PName=NIL)Then Exit;
 StrPCopy(PName,Name);BMC.Name:=PName;BMC.Value:=Value;
 Ptr:=ArrayListAdd(Inf,SizeOf(BMC));
 If(Ptr=NIL)Then Exit;
 Move(BMC,Ptr^,SizeOf(BMC));
 BDAdd:=True;
End;

Function BDSearchValue(Var Inf:ArrayList;Const Name:String):Boolean;
Var
 TMC:BooleanDirectivePtr;
 I:LongInt;
Begin
 BDSearchValue:=False;
 For I:=0to ArrayListMaxList(Inf)do Begin
  TMC:=ArrayList_GetBuf(Inf,I);
  If(StrPas(TMC^.Name)=Name)Then Begin
   BDSearchValue:=TMC^.Value;
   Exit;
  End;
 End;
End;

Function BWWordExist(Var Inf:ArrayList;Const Name:String):Boolean;
Var
 I:LongInt;
 S:PChar;
Begin
 BWWordExist:=False;
 For I:=0to ArrayListMaxList(Inf)do Begin
  S:=ArrayList_GetBuf(Inf,I);
  If Name=StrPas(S)Then Begin
   BWWordExist:=True;
   Exit;
  End;
 End;
End;

Procedure BVInit(Var Q:BankVar);Begin
 FillChar(Q,SizeOf(Q),0);
End;

Function BVAdd(Var Q:BankVar;Const Name,TypeVar:String):Boolean;
Var
 PBV:BankVarPtr;
 BV:BankVarRec;
 PName,PTypeVar:PChar;
Begin
 BVAdd:=False;
 PName:=MemAlloc(Length(Name)+1);
 If(PName=NIL)Then Exit;
 StrPCopy(PName,Name);
 BV.Name:=PName; PTypeVar:=MemAlloc(Length(TypeVar)+1);
 If(PTypeVar=NIL)Then Exit;
 StrPCopy(PTypeVar,TypeVar);
 BV.TypeVar:=PTypeVar;
 BV.Previous:=NIL;
 BV.Next:=NIL;
 PBV:=Q.List;
 If(PBV<>NIL)Then Begin
  While(PBV^.Next<>NIL)do PBV:=PBV^.Next;
  BV.Previous:=PBV;
  PBV^.Next:=MemAlloc(SizeOf(Q.List^));
  Q.EndList:=PBV^.Next;
  If(PBV^.Next=NIL)Then Exit;
  Move(BV,PBV^.Next^,SizeOf(Q.List^));
 End
  Else
 Begin
  PBV:=MemAlloc(SizeOf(Q.List^));
  If(PBV=NIL)Then Exit;
  Q.List:=PBV;
  Q.EndList:=Q.List;
  Move(BV,PBV^,SizeOf(Q.List^));
 End;
 BVAdd:=True;
End;

Function BVWordExist(Var Q:BankVar;Const Name:String):Boolean;
Var
 BV:BankVarPtr;
Begin
 BVWordExist:=False;
 BV:=Q.EndList;
 If(StrPas(Q.EndList^.Name)=Name)Then BVWordExist:=True
  Else
 Begin
  While(BV^.Previous<>NIL)do Begin
   BV:=BV^.Previous;
   If Name=StrPas(BV^.Name)Then Begin
    BVWordExist:=True;
    Exit;
   End;
  End;
 End;
End;

Function BVGetMaxWord(Var Q:BankVar):Integer;
Var
 I:Integer;
 BV:BankVarPtr;
Begin
 I:=0;BV:=Q.List;
 While(BV<>NIL)do Begin
  Inc(I);
  BV:=BV^.Next;
 End;
 Dec(I);
 BVGetMaxWord:=I
End;

Procedure BVGetWord(Var Q:BankVar;N:Word;Var Name,TypeVar:String);
Var
 I:Word;
 BV:BankVarPtr;
Begin
 Name:='';
 TypeVar:='';
 If(Q.List=NIL)Then Exit;
 I:=0; BV:=Q.List;
 If N>0Then For I:=1to(N)do BV:=BV^.Next;
 Name:=StrPas(BV^.Name);
 TypeVar:=StrPas(BV^.TypeVar)
End;

Procedure BVDone(Var Q:BankVar);Begin
End;

Function CommentC2Pascal(Var Info:SwitchC2Pascal;Put:Boolean):Boolean;Forward;
Function ExtractLine(Var I:Byte;Var Line:String;Var Handle:Text;Var L:LongInt):Boolean;Forward;
Function SkipSpcRem(Var Info:SwitchC2Pascal;Put:Boolean):Boolean;Forward;
Function VarC2Pas(Str:String;Signed:Boolean):String;Forward;

Function IntToStr(X:LongInt):String;
Var
 S:String;
Begin
 Str(X,S);
 IntToStr:=S;
End;

Function BinStr2Nm(Const Str:String):LongInt;
Var
 I:Byte;
 X:LongInt;
 SL:Byte Absolute Str;
Begin
 X:=0;
 For I:=SL downto 1do X:=X or((Byte(Str[I])-Byte('0'))shl(SL-I));
 BinStr2Nm:=X
End;

Function OctStr2Nm(Const Str:String):LongInt;
Var
 I:Byte;
 X:LongInt;
 SL:Byte Absolute Str;
Begin
 X:=0;
 For I:=SL downto 1do X:=X or((Byte(Str[I])-Byte('0'))shl((SL-I)*3));
 OctStr2Nm:=X;
End;

Function XtrkXNm(X:Byte;Var I:Byte;Const L:String):String;
Var
 J:Byte;
Begin
 XtrkXNm:='';
 If I>Length(L)Then Exit;
 J:=I;
 Case(X)of
  2:While I<=Length(L)do If(L[I]in BinArabicDigit)Then Inc(I)Else Break;
  8:While I<=Length(L)do If(L[I]in OctArabicDigit)Then Inc(I)Else Break;
 10:While I<=Length(L)do If(L[I]in ArabicDigit)Then Inc(I)Else Break;
 16:While I<=Length(L)do If(L[I]in ArabicXDigit)Then Inc(I)Else Break;
 End;
 If(I=J)Then Exit;
 XtrkXNm:=Copy(L,J,I-J)
End;

Function XtrkBinNm(Var I:Byte;Const L:String):String;Begin
 XtrkBinNm:=XtrkXNm(2,I,L)
End;

Function XtrkDecNm(Var I:Byte;Const L:String):String;Begin
 XtrkDecNm:=XtrkXNm(10,I,L);
End;

Function XtrkHexNm(Var I:Byte;Const L:String):String;Begin
 XtrkHexNm:=XtrkXNm(16,I,L);
End;

Function XtrkOctNm(Var I:Byte;Const L:String):String;Begin
 XtrkOctNm:=XtrkXNm(8,I,L);
End;

Function XtrkCNm2Pas(Var I:Byte;Const L:String):String;Begin
 XtrkCNm2Pas:='';
 If I>Length(L)Then Exit;
 Case L[I]of
  '0':If I+1>Length(L)Then Begin Inc(I);XtrkCNm2Pas:='0';End Else
  Case L[I+1]of
   '0'..'7':Begin
    Inc(I);
    XtrkCNm2Pas:=IntToStr(OctStr2Nm(XtrkOctNm(I,L)))
   End;
   'B','b':Begin
    Inc(I,2);
    XtrkCNm2Pas:=IntToStr(BinStr2Nm(XtrkBinNm(I,L)))
   End;
   'X','x':Begin
    Inc(I,2);
    XtrkCNm2Pas:='$'+XtrkHexNm(I,L)
   End;
   'L','l':Begin
    Inc(I,2);
    XtrkCNm2Pas:='LongInt(0)'
   End;
   Else Begin
    XtrkCNm2Pas:='0';
    Inc(I)
   End;
  End;
  '1'..'9':
  If(I<=Length(L))and(L[I]='L')Then XtrkCNm2Pas:='LongInt('+XtrkDecNm(I,L)+')'
			       Else XtrkCNm2Pas:=XtrkDecNm(I,L);
  Else
  XtrkCNm2Pas:='';
 End;
End;

Function XtrkWord(Var I:Byte;L:String):String;
Var
 Start:Byte;
Begin
 Start:=I;
 If(L[I]in Coder1DefLetter)Then Begin
  Inc(I);
  While I<=Length(L)do Begin
   If Not(L[I]in CoderDefLetter)Then Break;
   Inc(I);
  End;
 End;
 XtrkWord:=Copy(L,Start,I-Start);
End;

Function FormuleC2Pascal(Var Info:SwitchC2Pascal;Put:Boolean):Integer;
Var
 Open:Word;
 Ok:Boolean;
 Str,WordC:String;
 BufDec:ArrayList;
 I:Word;
 Ptr:Boolean;
Begin
 FormuleC2Pascal:=0;
 If Info.Line[Info.I]<>'('Then Begin
  FormuleC2Pascal:=OpenParExpected;
  Exit; (* '(' expected. *)
 End;
 ArrayListInit(BufDec);
 Open:=0;
 Repeat
  Case Info.Line[Info.I]of
   '(':Inc(Open);
   ')':Dec(Open);
  End;
  If(Put)Then Write(Info.HandlePas,Info.Line[Info.I]);
  Inc(Info.I);
  If Open>0Then Begin
   While Info.I>Length(Info.Line)do Begin
    If EOF(Info.HandleC)Then Exit;
    If(Put)Then WriteLn(Info.HandlePAS);
    If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Begin
     FormuleC2Pascal:=EndOfSourceExpected;
     Exit;
    End;
   End;
  End;
  Case Info.Line[Info.I]of
   '0':Begin
    Str:=XtrkCNm2Pas(Info.I,Info.Line);
    Write(Info.HandlePas,Str);
   End;
   '-':Begin
    Case Info.Line[Info.I+1]of
     '>':Begin
      Inc(Info.I,Length('->'));
      Write(Info.HandlePas,'.');
     End;
     '-':Begin
      Inc(Info.I,Length('--'));Ptr:=False;WordC:='';
      If Info.Line[Info.I]='('Then Begin
       Inc(Info.I,Length('('));
       If Info.Line[Info.I]='*'Then Begin
        Inc(Info.I,Length('*'));
        Ptr:=True;
       End;
       While Info.Line[Info.I]<>')'do Begin
        WordC:=WordC+Info.Line[Info.I];
        Inc(Info.I);
       End;
       Inc(Info.I,Length(')'));
      End;
      WordC:=WordC+XtrkWord(Info.I,Info.Line);
      While(Info.Line[Info.I]='-')and(Info.Line[Info.I+1]='>')do Begin
       Inc(Info.I,Length('->'));
       WordC:=WordC+'.'+XtrkWord(Info.I,Info.Line);
      End;
      If(Ptr)Then ArrayListAddStr(BufDec,WordC+'^')
             Else ArrayListAddStr(BufDec,WordC);
      Write(Info.HandlePas,WordC);
     End;
    End;
   End;
   '&','|':If Open>0Then Begin
    Ok:=False;
    Case Info.Line[Info.I]of
     '&':Write(Info.HandlePas,' and ');
     '|':Write(Info.HandlePas,' or ');
    End;
    Inc(Info.I);
    While Info.I>Length(Info.Line)do Begin
     If EOF(Info.HandleC)Then Exit;
     If(Put)Then WriteLn(Info.HandlePas);
     If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Begin
      FormuleC2Pascal:=EndOfSourceExpected;
      Exit; (* Fin du source attendu. *)
     End;
    End;
   End;
   Else Ok:=Open=0;
  End;
 Until Ok;
 If Not(ArrayListIsEmpty(BufDec))Then Begin
  WriteLn(Info.HandlePas,';');
  Write(Info.HandlePas,' ');
  For I:=0to ArrayListMaxList(BufDec)do
   WriteLn(Info.HandlePas,' Dec('+ArrayList_GetStr(BufDec,I)+');');
 End;
End;

Function SkipSpc(Var Info:SwitchC2Pascal;Put:Boolean):Boolean;Begin
 SkipSpc:=False;
 While Info.I>Length(Info.Line)do Begin
  If EOF(Info.HandleC)Then Exit;
  If(Put)Then WriteLn(Info.HandlePas);
  If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
 End;
 While Info.Line[Info.I]in[' ',#9]do Begin
  If(Put)Then Write(Info.HandlePas,Info.Line[Info.I]);
  Inc(Info.I);
  While Info.I>Length(Info.Line)do Begin
   If(EOF(Info.HandleC))Then Exit;
   If(Put)Then WriteLn(Info.HandlePas);
   If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
  End;
 End;
 SkipSpc:=True;
End;

Function IinStr(I:Byte;Const S:String):Boolean;Begin
 IinStr:=(I>0)and(I<=Length(S))
End;

Function ChrUp(Chr:Char):Char;Begin
 Case(Chr)of
  'a'..'z': ChrUp:=Char(Byte(Chr)-32);
  'Ä','á': ChrUp:='C';
  'ö','ñ','ó','Å','£': ChrUp:='U';
  'Ç','à','â','ä','ê': ChrUp:='E';
  'É','Ñ','Ö','Ü','«','µ','∑','¶': ChrUp:='A';
  'ã','å','ç','°': ChrUp:='I';
  'ì','î','ï','‚','„','‰': ChrUp:='O';
  '§','•': ChrUp:='N';
  'ò': ChrUp:='Y';
  'ë': ChrUp:='í';
  Else ChrUp:=Chr;
 End
End;

Function StrUp(S:String):String;
Var
 I:Byte;
Begin
 For I:=1to Length(S)do S[I]:=ChrUp(S[I]);
 StrUp:=S;
End;

Procedure SkipSpcInLn(Var I:Byte;Const Line:String);
Var
 LL:Byte Absolute Line;
Begin
 If(I>LL)Then Exit;
 While(Line[I]in SpcCode)do Begin
  Inc(I);
  If(I>LL)Then Exit;
 End;
End;

Function IsLangChrWord(Chr:Char):Boolean;Begin
 IsLangChrWord:=Chr in['A'..'Z','a'..'z','_']
End;

Function AutoUp(Const Str:String):String;Begin
 If(NoUpper)Then AutoUp:=Str
            Else AutoUp:=StrUp(Str);
End;

Function HexStrToInt(Str:String):LongInt;
Const
 HexChr:Array['A'..'F']of Byte=(10,11,12,13,14,15);
 HexNum:Array['0'..'9']of Byte=(0,1,2,3,4,5,6,7,8,9);
Var
 I:Byte;
 X:LongInt;
 SL:Byte Absolute Str;
Begin
 X:=0;Str:=StrUp(Str);
 For I:=SL downto 1do Begin
  If Str[I]in['A'..'F']Then X:=X or LongInt(LongInt(HexChr[Str[I]])shl((SL-I)shl 2))Else
  If(Str[I]in ArabicDigit)Then X:=X or LongInt(LongInt(HexNum[Str[I]])shl((SL-I)shl 2))
 End;
 HexStrToInt:=X
End;

Function XtrkCStr(Var I:Byte;Const L:String;Var EM:Boolean):String;
Var
 M,NS:String;
 J:Byte;
 W:Word;

 Function EndStr:Boolean;Begin
  EndStr:=I>Length(L);
 End;

Begin
 XtrkCStr:='';EM:=True;M:='';Inc(I);
 While L[I]<>'"'do Begin
  If I>Length(L)Then Exit;
  If L[I]='\'Then Begin
   Inc(I);
   If Not(EndStr)Then Begin
    Case L[I]of
     '?':M:=M+'?';
     '\':M:=M+'\';
     '"':M:=M+'"';
     '''':M:=M+'''';
     '0':Begin
      J:=0;NS:='';
      While L[I]in['0'..'7']do Begin
       NS:=NS+L[I];
       Inc(I);
       If(EndStr)Then Exit;
       Inc(J);
       If J>3Then Break;
      End;
      M:=M+Char(OctStr2Nm(NS));
      Dec(I);
     End;
     'a':M:=M+#7;
     'b':M:=M+#8;
     'f':M:=M+#$C;
     'n':M:=M+#$A;
     'r':M:=M+#$D;
     't':M:=M+#$B;
     'x':Begin
      J:=0;NS:='';
      While L[I]in['0'..'9','A'..'F','a'..'f']do Begin
       NS:=NS+L[I];
       Inc(I);
       If(EndStr)Then Exit;
       Inc(J);
       If J>3Then Break;
      End;
      W:=HexStrToInt(NS);
      If Hi(W)=0Then M:=M+Char(W)
                Else M:=M+Char(W)+Char(Hi(W));
     End;
     Else
     M:=M+L[I];
    End;
    Inc(I);
   End
    Else
   Exit;
  End
   Else
  Begin
   M:=M+L[I];
   Inc(I);
  End;
 End;
 XtrkCStr:=M;
 EM:=False;
End;


Function CondC2Pascal(Var Info:SwitchC2Pascal):Integer;
Var
 WordC,UWordC,Msg,Arg,Str:String;
 Value,Par:Integer;
 Defined,EndMissing:Boolean;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
 J:Byte;

 Procedure _And;Begin
  If Info.Line[Info.I]='&'Then Begin
   Inc(Info.I);
   If Info.Line[Info.I]='&'Then Inc(Info.I);
   Write(Info.HandlePAS,' and ');
  End;
 End;

 Procedure _Or;Begin
  If Info.Line[Info.I]='|'Then Begin
   Inc(Info.I);
   If Info.Line[Info.I]='|'Then Inc(Info.I);
   Write(Info.HandlePAS,' or ');
  End;
 End;

 Procedure _Shl;Begin
  If(Info.Line[Info.I]='<')and(Info.Line[Info.I+1]='<')Then Begin
   Inc(Info.I,Length('<<'));
   Write(Info.HandlePAS,' shl ');
  End
   Else
  Begin
   Write(Info.HandlePAS,'<');
   Inc(Info.I);
  End;
 End;

 Procedure _Shr;Begin
  If(Info.Line[Info.I]='>')and(Info.Line[Info.I+1]='>')Then Begin
   Inc(Info.I,Length('>>'));
   Write(Info.HandlePAS,' shr ');
  End
   Else
  Begin
   Write(Info.HandlePAS,'>');
   Inc(Info.I);
  End;
 End;

 Function DumpEnd:Integer;Var TStr:String;Begin
  DumpEnd:=0;
  While Info.I<=Length(Info.Line)do Begin
   Case Info.Line[Info.I]of
    '/': If Not(CommentC2Pascal(Info,True))Then Begin
     DumpEnd:=EndOfCommentExpected;
     Exit;
    End;
    '<':_Shl;
    '>':_Shr;
    '|':_Or;
    '&':_And;
    '-':Begin
     Inc(Info.I);
     Case Info.Line[Info.I]of
      '>':Begin
       Write(Info.HandlePAS,'.');
       Inc(Info.I);
      End;
       Else
      Write(Info.HandlePAS,'-');
     End;
    End;
    '0':Begin
     TStr:=XtrkCNm2Pas(Info.I,Info.Line);
     If TStr<>''Then Write(Info.HandlePAS,TStr)
      Else
     Begin
      Write(Info.HandlePAS,Info.Line[Info.I]);
      Inc(Info.I);
     End;
    End;
    Else Begin
     Write(Info.HandlePAS,Info.Line[Info.I]);
     Inc(Info.I);
    End;
   End;
  End;
 End;

Begin
 CondC2Pascal:=NumExpected;
 If Info.Line[Info.I]<>'#'Then Exit;
 Inc(Info.I);
 If Not(IinStr(Info.I,Info.Line))Then Begin
  CondC2Pascal:=DirectiveCommandExpected;
  Exit;
 End;
 SkipSpc(Info,True);
 WordC:=XtrkWord(Info.I,Info.Line);
 UWordC:=StrUp(WordC);
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                     DEFINE                    *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='DEFINE'Then Begin
  SkipSpcInLn(Info.I,Info.Line);
  WordC:=XtrkWord(Info.I,Info.Line);
  If StrUp(WordC)='SIZEOF'Then Begin{ Execption ? }
   Info.Warning[Info.WarPos].War:=SkipDefineSizeOf;
   Info.Warning[Info.WarPos].Line:=Info.L;
   If Info.WarPos=255Then Begin
    CondC2Pascal:=TooManyWarning;
    Exit;
   End
    Else
   Inc(Info.WarPos);
   SkipSpcInLn(Info.I,Info.Line);
   WordC:=XtrkWord(Info.I,Info.Line);
   If(IinStr(Info.I,Info.Line))and(Info.Line[Info.I]='(')Then Begin{ Function ? }
    Inc(Info.I);
    While Info.Line[Info.I]<>')'do Begin
     Inc(Info.I);
     If Not(IinStr(Info.I,Info.Line))Then Begin
      CondC2Pascal:=EndOfFunctionExpected;
      Exit;
     End;
    End;
    Inc(Info.I);
    SkipSpcRem(Info,False);
    If(IsLangChrWord(Info.Line[Info.I]))Then XtrkWord(Info.I,Info.Line);
    Value:=FormuleC2Pascal(Info,False);
    If Value<0Then Begin
     CondC2Pascal:=Value;
     Exit;
    End;
   End
    Else
   Begin
    CondC2Pascal:=SyntaxError;
    Exit;
   End;
  End
   Else
  If(IinStr(Info.I,Info.Line))and(Info.Line[Info.I]='(')Then Begin{ Function ? }
   Info.Mode:=_None_;
   Write(Info.HandlePAS,'Function '+WordC+'(');
   Inc(Info.I,Length('('));
   Arg:='';
   While Info.Line[Info.I]<>')'do Begin
    Arg:=Arg+Info.Line[Info.I];
    Write(Info.HandlePAS,Info.Line[Info.I]);
    Inc(Info.I);
    If Not(IinStr(Info.I,Info.Line))Then Begin
     CondC2Pascal:=EndOfFunctionExpected;
     Exit;
    End;
   End;
   Inc(Info.I,Length(')'));
   SkipSpcRem(Info,False);
   If IsLangChrWord(Info.Line[Info.I])Then Begin
    WriteLn(Info.HandlePAS,':?):?;');
    WriteLn(Info.HandlePAS,'Begin');
    Str:=XtrkWord(Info.I,Info.Line);
    If AutoUp(Str)=AutoUp(Arg)Then Begin
     WriteLn(Info.HandlePas,' '+WordC+' := '+Arg+';');
     WriteLn(Info.HandlePas,'End;');
     CondC2Pascal:=0;
     Exit;
    End;
    If AutoUp(Str)=AutoUp('do')Then Begin
     WriteLn(Info.HandlePAS,' Repeat');
     Write(Info.HandlePAS,' ');
     SkipSpcRem(Info,True);
     If Info.Line[Info.I]=#123Then Begin
      Inc(Info.I,Length(#123));
      Repeat
       SkipSpcRem(Info,True);
       Str:=XtrkWord(Info.I,Info.Line);
       If Str=''Then Begin
        CondC2Pascal:=SyntaxError;
        Exit;
       End;
       Write(Info.HandlePAS,Str);
       SkipSpcRem(Info,True);
       If Info.Line[Info.I]=';'Then Begin
	Inc(Info.I,Length(';'));
	SkipSpcRem(Info,True);
       End;
      Until Info.Line[Info.I]=#125;
      Inc(Info.I,Length(#125));
      SkipSpcRem(Info,True);
      Str:=XtrkWord(Info.I,Info.Line);
      If AutoUp(Str)=AutoUp('while')Then Begin
       SkipSpcRem(Info,True);
       Par:=1;
       WriteLn(Info.HandlePas);
       Write(Info.HandlePas,' Until (');
       Inc(Info.I,Length('('));
       If(Info.Line[Info.I]='0')and(Info.Line[Info.I+1]=')')Then Begin
	Inc(Info.I,Length('0)'));
	Write(Info.HandlePas,'False)');
       End
	Else
       While Par>0do Begin
	SkipSpcRem(Info,False);
	Case Info.Line[Info.I]of
	 '(': Inc(Par);
	 ')': Dec(Par);
	End;
	Write(Info.HandlePAS,Info.Line[Info.I]);
	Inc(Info.I);
       End;
       Write(Info.HandlePas,';');
       Write(Info.HandlePas,'End;');
       CondC2Pascal:=0;
       Exit;
      End
       Else
      Begin
       CondC2Pascal:=whileExpected; {"while" expected.}
       Exit;
      End;
     End
      Else
     Begin
      CondC2Pascal:=OpenEnsExpected; {#123 expected.}
      Exit;
     End;
    End
     else
    Write(Info.HandlePAS,' '+Str);
    SkipSpcRem(Info,False);
   End
    Else
   Begin
    WriteLn(Info.HandlePAS,':LongInt):LongInt;');
    WriteLn(Info.HandlePAS,'Begin');
    Write(Info.HandlePAS,' '+WordC+' := ');
   End;
   Value:=FormuleC2Pascal(Info,True);
   If Value<0Then Begin
    CondC2Pascal:=Value;
    Exit;
   End;
   SkipSpcRem(Info,False);
   If(IsLangChrWord(Info.Line[Info.I]))Then Begin
    J:=Info.I; Str:=XtrkWord(Info.I,Info.Line);
    If Pos(Str,Arg)>0Then Write(Info.HandlePAS,Str)
                     Else Info.I:=J;
   End;
   If(Info.Line[Info.I]='(')and(Info.Line[Info.I+1]=')')Then Begin
    Inc(Info.I,Length('()'));
    Write(Info.HandlePAS,'()');
   End;
   If Info.I>1Then WriteLn(Info.HandlePas,';');
   WriteLn(Info.HandlePAS,'End;');
   WriteLn(Info.HandlePas);
  End
   Else
  Begin
   SkipSpcInLn(Info.I,Info.Line);
   If Not(IinStr(Info.I,Info.Line))Then Begin
    If BDSearchValue(Info.BoolDir,WordC)Then Begin
     Info.Warning[Info.WarPos].War:=DuplicateDefineSymbol; { Duplicate define symbol. }
     Info.Warning[Info.WarPos].Line:=Info.L;
     If Info.WarPos=255Then Begin
      CondC2Pascal:=TooManyWarning;
      Exit;
     End
      Else
     Inc(Info.WarPos);
    End;
    WriteLn(Info.HandlePAS,' ':Info.CondIf,#123,'$DEFINE ',WordC,#125);
    BDAdd(Info.BoolDir,WordC,True);
   End
    Else
   Case Info.Line[Info.I]of
    '(':Begin
     WriteLn(Info.HandlePAS,'Function ',WordC,':LongInt;');
     WriteLn(Info.HandlePAS,'Begin');
     Write(Info.HandlePAS,' ',WordC,':=');
     SkipSpcInLn(Info.I,Info.Line);
     Value:=FormuleC2Pascal(Info,True);
     If Value<0Then Begin
      CondC2Pascal:=Value;
      Exit;
     End;
     WriteLn(Info.HandlePAS,';');
     Info.I:=Length(Info.Line)+1;
     WriteLn(Info.HandlePAS,'End;');
     Info.Mode:=_None_;
    End;
    'A'..'Z','a'..'z','_':Begin
     Msg:=XtrkWord(Info.I,Info.Line);
     If(StrUp(WordC)='FAR')and(StrUp(Msg)='FAR')Then Begin
      Info.Warning[Info.WarPos].War:=SkipDefineFar; { Skip define "far". }
      Info.Warning[Info.WarPos].Line:=Info.L;
      If Info.WarPos=255Then Begin
       CondC2Pascal:=TooManyWarning;
       Exit;
      End
       Else
      Inc(Info.WarPos)
     End
      Else
     Begin
      If(Info.Mode<>_Const_)Then Begin
       WriteLn(Info.HandlePAS,'Const');
       WriteLn(Info.HandlePAS);
      End;
      Write(Info.HandlePAS,' ':6,WordC,' = ',Msg,';');
      Info.Mode:=_Const_;
     End;
    End;
    '0'..'9':Begin
     Msg:=XtrkCNm2Pas(Info.I,Info.Line);
     If(Info.Mode<>_Const_)Then Begin
      WriteLn(Info.HandlePAS,'Const');
      WriteLn(Info.HandlePAS);
     End;
     Write(Info.HandlePAS,' ':6,WordC,' = ',Msg,';');
     Info.Mode:=_Const_;
    End;
    Else Begin
     If BDSearchValue(Info.BoolDir,WordC)Then Begin
      Info.Warning[Info.WarPos].War:=DuplicateDefineSymbol; { Duplicate define symbol. }
      Info.Warning[Info.WarPos].Line:=Info.L;
      If Info.WarPos=255Then Begin
       CondC2Pascal:=TooManyWarning;
       Exit;
      End
       Else
      Inc(Info.WarPos)
     End;
     WriteLn(Info.HandlePAS,' ':Info.CondIf,#123,'$DEFINE ',WordC,#125);
     BDAdd(Info.BoolDir,WordC,True);
    End;
   End;
  End;
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                      ELIF                     *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='ELIF'Then Begin
  Inc(Info.OvrEndIf);
  WriteLn(Info.HandlePAS,' ':Info.CondIf-1,#123,'$ELSE',#125);
  Inc(Info.CondIf);
  Info.Mode:=_None_;
  SkipSpc(Info,True);
  WordC:=StrUp(XtrkWord(Info.I,Info.Line));
  Defined:=False;
  If WordC=''Then Begin
   If Info.Line[Info.I]='!'Then Begin
    Inc(Info.I); WordC:=StrUp(XtrkWord(Info.I,Info.Line));
    If WordC='DEFINED'Then Begin
     If Info.Line[Info.I]='('Then Begin
      Inc(Info.I,Length('('));
      SkipSpc(Info,True);
      WordC:=XtrkWord(Info.I,Info.Line);
     End
      Else
     Begin
      CondC2Pascal:=OpenParExpected; { '(' expected. }
      Exit;
     End;
     Defined:=True;
    End;
    If WordC=''Then Begin
     CondC2Pascal:=IfDirectNameExpected;
     Exit; { "if" directive name expected. }
    End;
    Write(Info.HandlePAS,' ':Info.CondIf,#123,'$IFNDEF ',WordC);
   End;
  End
   Else
  Begin
   If WordC='DEFINED'Then
   Case Info.Line[Info.I]of
    '(':Begin
     Inc(Info.I,Length('('));
     SkipSpc(Info,True);
     WordC:=XtrkWord(Info.I,Info.Line); Defined:=True;
    End;
    ';':Begin
     CondC2Pascal:=MisplacedPointComma; { Misplaced ';'. }
     Exit;
    End;
    Else Begin
     CondC2Pascal:=OpenParExpected; { '(' expected.  }
     Exit;
    End;
   End;
   Write(Info.HandlePAS,' ',Info.CondIf,#123,'$IFDEF'+WordC);
  End;
  If(Defined)Then Begin
   SkipSpc(Info,True);
   If Info.Line[Info.I]<>')'Then Begin
    CondC2Pascal:=CloseParExpected; { ')' expected. }
    Exit;
   End;
   Inc(Info.I,Length(')'));
  End;
  Inc(Info.CondIf);
  DumpEnd;
  Write(Info.HandlePAS,#125);
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                      ELSE                     *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='ELSE'Then Begin
  Info.Mode:=_None_;
  If Info.CondIf=0Then Begin
   CondC2Pascal:=MisplacedCondDirective;
   Exit; { Misplaced conditional directive. }
  End;
  Write(Info.HandlePAS,' ',Info.CondIf-1+Info.OvrEndIf,#123,'$ELSE',#125);
 End
  else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                      ENDIF                    *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='ENDIF'Then Begin
  Info.Mode:=_None_;
  If Info.CondIf>0Then Begin
   Dec(Info.CondIf);
   Write(Info.HandlePAS,' ':Info.CondIf,#123,'$ENDIF',#125);
   While Info.OvrEndIf>0do Begin
    WriteLn(Info.HandlePAS);
    Write(Info.HandlePAS,' ':Info.CondIf+Info.OvrEndIf,#123,'$ENDIF',#125);
    Dec(Info.OvrEndIf);
   End;
  End
   Else
  Begin
   CondC2Pascal:=MisplacedCondDirective;
   Exit; { Misplaced conditional directive. }
  End;
 End
  else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                    ERROR                      *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='ERROR'Then Begin
  Write(Info.HandlePAS,' ':Info.CondIf,'''Erreur: ',Copy(Info.Line,Info.I,255),'''');
  Info.I:=Length(Info.Line)+1;
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                        IF                     *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='IF'Then Begin
  Info.Mode:=_None_;
  SkipSpc(Info,True);
  WordC:=StrUp(XtrkWord(Info.I,Info.Line)); Defined:=False;
  If WordC=''Then Begin
   If Info.Line[Info.I]='!'Then Begin
    Inc(Info.I); WordC:=StrUp(XtrkWord(Info.I,Info.Line));
    If WordC='DEFINED'Then Begin
     Case Info.Line[Info.I]of
      '(':Begin
       Inc(Info.I,Length('('));
       SkipSpc(Info,True);
       WordC:=XtrkWord(Info.I,Info.Line);
      End;
      ';':Begin
       CondC2Pascal:=MisplacedPointComma;
       Exit; { Misplaced ';'. }
      End;
      Else Begin
       CondC2Pascal:=OpenParExpected;
       Exit; { '(' expected.  }
      End;
     End;
     Defined:=True;
    End;
    If WordC=''Then Begin
     CondC2Pascal:=IfDirectNameExpected;
     Exit;
    End;
    If WordC='_Windows'Then WordC:='WINDOWS'; { C/C++ -> _Windows: Pascal -> WINDOWS }
    Write(Info.HandlePAS,' ':Info.CondIf,'{$IFNDEF',' ',WordC);
   End
    else
   Begin
    CondC2Pascal:=SyntaxError;
    Exit;
   End;
  End
   Else
  Begin
   If WordC='DEFINED'Then Begin
    If Info.Line[Info.I]='('Then Begin
     Inc(Info.I,Length('('));
     SkipSpc(Info,True);
     WordC:=XtrkWord(Info.I,Info.Line);
     Defined:=True;
    End;
   End;
   If WordC='_Windows'Then WordC:='WINDOWS'; { C/C++ -> _Windows: Pascal -> WINDOWS }
   Write(Info.HandlePAS,' ',Info.CondIf,'{$IFDEF',' ',WordC);
  End;
  If(Defined)Then Begin
   SkipSpc(Info,True);
   If Info.Line[Info.I]<>')'Then Begin
    CondC2Pascal:=CloseParExpected; { ')' expected. }
    Exit;
   End;
   Inc(Info.I,Length(')'));
  End;
  Inc(Info.CondIf); Value:=DumpEnd;
  If Value<0Then Begin
   CondC2Pascal:=Value;
   Exit;
  End;
  Write(Info.HandlePAS,#125);
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                      IFDEF                    *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='IFDEF'Then Begin
  Info.Mode:=_None_;
  Write(Info.HandlePAS,' ',Info.CondIf,'{$IFDEF');
  Inc(Info.CondIf);
  SkipSpc(Info,True);
  WordC:=XtrkWord(Info.I,Info.Line);
  If WordC=''Then Begin
   CondC2Pascal:=IfDefDirectNameExpected;
   Exit; { "ifdef" directive name expected. }
  End;
  If WordC='_Windows'Then WordC:='WINDOWS'; { C/C++ -> _Windows: Pascal -> WINDOWS }
  Write(Info.HandlePAS,WordC,#125);
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                     IFNDEF                    *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='IFNDEF'Then Begin
  Info.Mode:=_None_;
  Write(Info.HandlePAS,' ':Info.CondIf+Info.OvrEndIf,#123,'$IFNDEF');
  Inc(Info.CondIf);
  SkipSpc(Info,True);
  WordC:=XtrkWord(Info.I,Info.Line);
  If WordC=''Then Begin
   CondC2Pascal:=IfNDefDirectNameExpected;
   Exit; { "ifndef" directive name expected. }
  End;
  Write(Info.HandlePAS,WordC,#125);
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                     INCLUDE                   *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='INCLUDE'Then Begin
  SkipSpc(Info,False);
  Case Info.Line[Info.I]of
   '<':Begin
    EndMissing:=False;Inc(Info.I);WordC:='';
    While Info.Line[Info.I]<>'>'do Begin
     WordC:=WordC+Info.Line[Info.I];
     Inc(Info.I);
     If Not(IinStr(Info.I,Info.Line))Then Begin
      CondC2Pascal:=GrExpected;
      Exit; { '>' expected. }
     End;
    End;
   End;
   '"':WordC:=XtrkCStr(Info.I,Info.Line,EndMissing);
   Else Begin
    CondC2Pascal:=IncludeFileNameExpected;
    Exit;
   End;
  End;
  If(EndMissing)Then Begin
   CondC2Pascal:=EndOfStringExpected;
   Exit;
  End;
  UWordC:=StrUp(WordC);
  If(UWordC='SYS\TYPES.H')or(UWordC='SYS/TYPES.H')Then Begin
   If Not(Info.SYS_Types)Then Begin
    WriteLn(Info.HandlePAS,'Type Time_T=LongInt;',#123,
           'Type C/C++ pour l''heure.',#125);
    Info.SYS_Types:=True;
   End;
  End
   Else
  If UWordC='STDDEF.H'Then Begin
   If Not(Info.StdDef)Then Begin
    WriteLn(Info.HandlePas,'Const');
    WriteLn(Info.HandlePas);
    WriteLn(Info.HandlePas,' ':6,'Null=NIL;');
    WriteLn(Info.HandlePas);
    WriteLn(Info.HandlePas,'Type');
    WriteLn(Info.HandlePas);
    WriteLn(Info.HandlePas,' ':5,'WChar_T=Char;');
    WriteLn(Info.HandlePas,' ':5,'Size_T=Word;');
    WriteLn(Info.HandlePas,' ':5,'PtrDiff_T=Pointer;');
    Info.StdDef:=True;
   End;
  End
   Else
  If UWordC='DOS.H'Then Write(Info.HandlePAS,'Uses Crt,DOS;')else
  If UWordC='DIR.H'Then Write(Info.HandlePAS,'Uses DOS;')else
  If UWordC='STRING.H'Then Write(Info.HandlePAS,'Uses Strings;')else
  If UWordC='STRINGS.H'Then Write(Info.HandlePAS,'Uses Strings;')else
  If UWordC='ALLOC.H'Then Write(Info.HandlePAS,'Uses Memory;')else
  If UWordC='PROCESS.H'Then Write(Info.HandlePAS,'Uses DOS;')else
  If UWordC='STDIO.H'Then Write(Info.HandlePAS,'Uses Crt,DOS;')else
  If UWordC='CONIO.H'Then Write(Info.HandlePAS,'Uses Crt;')else
  If UWordC='IO.H'Then Write(Info.HandlePAS,'Uses DOS;')else
  If UWordC='STDLIB.H'Then Write(Info.HandlePAS,'Uses Memory;')else
  If UWordC='GRAPH.H'Then Write(Info.HandlePAS,'Uses Graph;')
   else
  Begin
   FSplit(Info.NameC,D,N,E);
   Info.Output:=D+';'+Info.PathHeader+';'+GetEnv('PATH');
   Info.Output:=StrUp(FSearch(WordC,Info.Output));
   If Info.Output=''Then Info.Output:=WordC;
   CondC2Pascal:=IncludeFile;
   Exit;
  End;
  Inc(Info.I);
 End
  Else
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 {*                      UNDEF                    *}
 {* * * * * * * * * * * * * * * * * * * * * * * * *}
 If UWordC='UNDEF'Then Begin
  SkipSpc(Info,False);
  WordC:=XtrkWord(Info.I,Info.Line);
  UWordC:=StrUp(WordC);
  If UWordC='SIZEOF'Then Begin
   Info.Warning[Info.WarPos].War:=SkipDefineSizeOf; { Skip define "sizeof". }
   Info.Warning[Info.WarPos].Line:=Info.L;
   If Info.WarPos=255Then Begin
    CondC2Pascal:=TooManyWarning;
    Exit; { Too many warning. }
   End
    Else
   Inc(Info.WarPos);
  End
   Else
  Begin
   If BDSearchValue(Info.BoolDir,WordC)Then Begin
    Info.Warning[Info.WarPos].War:=WrongValueInDefineDirective; { Wrong value in define directive. }
    Info.Warning[Info.WarPos].Line:=Info.L;
    If Info.WarPos=255Then Begin
     CondC2Pascal:=TooManyWarning;
     Exit;
    End
     Else
    Inc(Info.WarPos)
   End;
   WriteLn(Info.HandlePAS,' ',Info.CondIf,#123,'$UNDEF ',WordC,#125);
   BDAdd(Info.BoolDir,WordC,False);
  End;
 End
  Else
 Write(Info.HandlePAS,'#',WordC);
 CondC2Pascal:=0;
End;

Function IsReservedWordPascal(Const Word:String):Boolean;Begin
 IsReservedWordPascal:=
  (Word='AND')or
  (Word='ASSEMBLER')or
  (Word='ASM')or
  (Word='ARRAY')or
  (Word='BEGIN')or
  (Word='CASE')or
  (Word='CONST')or
  (Word='CONSTRUCTOR')or
  (Word='DESTRUCTOR')or
  (Word='DIV')or
  (Word='DO')or
  (Word='DOWNTO')or
  (Word='ELSE')or
  (Word='END')or
  (Word='EXPORTS')or
  (Word='FILE')or
  (Word='FOR')or
  (Word='FUNCTION')or
  (Word='GOTO')or
  (Word='IF')or
  (Word='IMPLEMENTATION')or
  (Word='IN')or
  (Word='INHERITED')or
  (Word='INLINE')or
  (Word='INTERFACE')or
  (Word='LABEL')or
  (Word='LIBRARY')or
  (Word='MOD')or
  (Word='NIL')or
  (Word='NOT')or
  (Word='OBJECT')or
  (Word='OF')or
  (Word='OR')or
  (Word='PACKED')or
  (Word='PROCEDURE')or
  (Word='PROGRAM')or
  (Word='RECORD')or
  (Word='REPEAT')or
  (Word='SET')or
  (Word='SHL')or
  (Word='SHR')or
  (Word='STRING')or
  (Word='THEN')or
  (Word='TO')or
  (Word='TYPE')or
  (Word='UNIT')or
  (Word='UNTIL')or
  (Word='USES')or
  (Word='VAR')or
  (Word='VIRTUEL')or
  (Word='WHILE')or
  (Word='WITH')or
  (Word='XOR');
End;

Function StructC2Pascal(Var Info:SwitchC2Pascal):Integer;
Var
 TypeStruct,VarName,WordC,Name,TypeVar:String;
 NameLen:Byte Absolute Name;
 Ok,_Ptr:Boolean;BV:BankVar;
 J,Par:Integer;
 ML:Byte;
Begin
 StructC2Pascal:=0; ML:=0;
 If Not(SkipSpcRem(Info,False))Then Begin
  StructC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 TypeStruct:=XtrkWord(Info.I,Info.Line);
 If TypeStruct=''Then Begin
  StructC2Pascal:=TypeVarExpected;
  Exit;
 End;
 If Not(SkipSpcRem(Info,False))Then Begin
  StructC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 Case Info.Line[Info.I]of
  #123:Begin
   Inc(Info.I,Length(#123));
   BVInit(BV);
   Ok:=False;
   Repeat
    If Not(SkipSpcRem(Info,False))Then Begin
     StructC2Pascal:=EndOfSourceExpected;
     Exit;
    End;
    TypeVar:=XtrkWord(Info.I,Info.Line);
    If TypeVar=''Then Begin
     StructC2Pascal:=TypeVarExpected;
     Exit;
    End;
    If Not(SkipSpcRem(Info,False))Then Begin
     StructC2Pascal:=EndOfSourceExpected;
     Exit;
    End;
    _Ptr:=False;
    Case Info.Line[Info.I]of
     '*':Begin
      _Ptr:=True;
      Inc(Info.I,Length('*'));
      If Not(SkipSpcRem(Info,False))Then Begin
       StructC2Pascal:=EndOfSourceExpected;
       Exit;
      End;
      Name:=XtrkWord(Info.I,Info.Line);
     End;
     '(':Begin
      Name:='';Par:=1;Inc(Info.I,Length('('));
      While Par>0do Begin
       SkipSpcRem(Info,False);
       Case Info.Line[Info.I]of
        '(':Inc(Par);
	')':Dec(Par);
       End;
       Name:=Name+Info.Line[Info.I];
       Inc(Info.I);
      End;
     End;
     Else Name:=XtrkWord(Info.I,Info.Line);
    End;
    If Name=''Then Begin
     StructC2Pascal:=VarNameExpected;
     Exit;
    End;
    Case Info.Line[Info.I]of
     '[':Begin
      Inc(Info.I,Length('['));
      Case Info.Line[Info.I]of
       '0'..'9':WordC:=XtrkCNm2Pas(Info.I,Info.Line);
       'A'..'Z','a'..'z','_':WordC:=XtrkWord(Info.I,Info.Line);
       Else WordC:='';
      End;
      If WordC=''Then Begin
       StructC2Pascal:=NumberOfArrayExpected;
       Exit;
      End;
      If Info.Line[Info.I]<>']'Then Begin
       StructC2Pascal:=CloseArrayExpected;
       Exit; (* ']' expected. *)
      End;
      Inc(Info.I,Length(']'));
      If Info.Line[Info.I]<>';'Then Begin
       StructC2Pascal:=PointCommaExpected;
       Exit; (* ';' expected. *)
      End;
      TypeVar:='Array[0..'+WordC+'] of '+VarC2Pas(TypeVar,True);
     End;
     ';':;
     #125:Begin
      StructC2Pascal:=PointCommaExpected;
      Exit; (* ';' expected. *)
     End;
     Else Begin
      StructC2Pascal:=SyntaxError;
      Exit; (* Syntax error *)
     End;
    End;
    If(_Ptr)Then TypeVar:='^'+TypeVar;
    Inc(Info.I);
    {If(BV.WordExist(Name))Then Begin
     TypeStructC2Pascal := VarStructDupl;
     Exit; (* Variable structure duplicated. *)
    End;}
    If IsReservedWordPascal(Name)Then Begin
     StructC2Pascal:=UsePascalReservedWordForVar;
     Exit; (* Mot r,serv, Pascal utilis, comme variable. *)
    End;
    If(NameLen>ML)Then ML:=NameLen;
    BVAdd(BV,Name,TypeVar);
    If Not(SkipSpcRem(Info,False))Then Begin
     StructC2Pascal:=EndOfSourceExpected;
     Exit; (* Fin du source attendu. *)
    End;
    Ok:=Info.Line[Info.I]=#125;
   Until Ok;
   Inc(Info.I,Length(#125));
   If Not(SkipSpcRem(Info,False))Then Begin
    StructC2Pascal:=EndOfSourceExpected;
    Exit; (* Fin du source attendu. *)
   End;
   VarName:=XtrkWord(Info.I,Info.Line);
   If Not(SkipSpcRem(Info,False))Then Begin
    StructC2Pascal:=EndOfSourceExpected;
    Exit; (* Fin du source attendu. *)
   End;
   If Info.Line[Info.I]<>';'Then Begin
    StructC2Pascal:=PointCommaExpected;
    Exit; (* ';' attendu. *)
   End;
   Inc(Info.I,Length(';'));
   If(Info.Mode<>_Type_)Then Begin
    WriteLn(Info.HandlePas,'Type');
    WriteLn(Info.HandlePas);
    Info.Mode:=_Type_;
   End;
   WriteLn(Info.HandlePAS,' ':5,TypeStruct,'=Record');
   For J:=0to BVGetMaxWord(BV)do Begin
    BVGetWord(BV,J,Name,TypeVar);
    WriteLn(Info.HandlePAS,' ':10+Length(TypeStruct),PadRight(Name,ML)+' : '+VarC2Pas(TypeVar,True)+';');
   End;
   WriteLn(Info.HandlePAS,' ':8+Length(TypeStruct),'End;');
   BVDone(BV);
   If VarName<>''Then Begin
    Info.Mode:=_Var_;
    WriteLn(Info.HandlePas,'Var');
    WriteLn(Info.HandlePas);
    WriteLn(Info.HandlePas,' ':4,VarName,' : ',TypeStruct);
   End;
  End;
  'A'..'Z','a'..'z','_':Begin
   VarName:=XtrkWord(Info.I,Info.Line);
   If VarName=''Then Begin
    StructC2Pascal:=VarNameExpected;
    Exit; (* Nom de variable attendu. *)
   End;
   If Info.Line[Info.I]<>';'Then Begin
    StructC2Pascal:=PointCommaExpected;
    Exit;
   End;
   Inc(Info.I,Length(';'));
   If(Info.Mode<>_Var_)Then Begin
    WriteLn(Info.HandlePas,'Var');
    WriteLn(Info.HandlePas);
    Info.Mode:=_Var_;
   End;
   WriteLn(Info.HandlePAS,' ':4,VarName,' : ',TypeStruct,';');
  End;
  Else Begin
   StructC2Pascal:=SyntaxError;
   Exit;
  End;
 End;
End;

Function VarC2Pas(Str:String;Signed:Boolean):String;Begin
 VarC2Pas:=Str;Str:=StrUp(Str);
 Case Signed of
	  {* * * * * * * * * * * * * * * * * * * * * *}
	  {*               unsigned                  *}
	  {* * * * * * * * * * * * * * * * * * * * * *}
False:Begin
       If Str='SHORT'Then VarC2Pas:='Word';
       If Str='INT'Then VarC2Pas:='Word';
       If Str='LONG'Then VarC2Pas:='LongInt';
       If Str='FLOAT'Then VarC2Pas:='Real';
       If Str='DOUBLE'Then VarC2Pas:='Double';
       If Str='CHAR'Then VarC2Pas:='Char';
      End;
      {* * * * * * * * * * * * * * * * * * * * * *}
      {*                 signed                  *}
      {* * * * * * * * * * * * * * * * * * * * * *}
 Else Begin
       If Str='SHORT'Then VarC2Pas:='Integer';
       If Str='INT'Then VarC2Pas:='Integer';
       If Str='LONG'Then VarC2Pas:='LongInt';
       If Str='FLOAT'Then VarC2Pas:='Real';
       If Str='DOUBLE'Then VarC2Pas:='Double';
       If Str='CHAR'Then VarC2Pas:='Char';
      End;
 End;
End;

Function TypeStructC2Pascal(Var Info:SwitchC2Pascal):Integer;
Var Ok:Boolean;BV:BankVar;J:Integer;WordC,Name,TypeVar:String;
NameLen:Byte Absolute Name;WordCLen:Byte Absolute WordC;ML:Byte;Begin
 TypeStructC2Pascal:=0; ML:=0;
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeStructC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 If IsLangChrWord(Info.Line[Info.I])Then Begin
  TypeVar:=XtrkWord(Info.I,Info.Line);
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  If Info.Line[Info.I]<>'*'Then Begin
   TypeStructC2Pascal:=AsterixExpected;
   Exit; (* '*' attendu. *)
  End;
  Inc(Info.I,Length('*'));
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  Name:=XtrkWord(Info.I,Info.Line);
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  If Info.Line[Info.I]<>';'Then Begin
   TypeStructC2Pascal:=PointCommaExpected;
   Exit; (* ';' attendu.' *)
  End;
  Inc(Info.I,Length(';'));
  WriteLn(Info.HandlePas,' ':6,Name,' = ^',TypeVar,';');
  Exit;
 End;
 If Info.Line[Info.I]<>#123Then Begin
  TypeStructC2Pascal:=OpenEnsExpected;
  Exit; (* #123 attendu. *)
 End;
 Inc(Info.I,Length(#125));
 If Info.Line[Info.I]=#125Then Begin
  TypeStructC2Pascal:=StructEmpty;
  Exit;
 End;
 BVInit(BV);
 Ok:=False;
 Repeat
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  TypeVar:=XtrkWord(Info.I,Info.Line);
  If TypeVar=''Then Begin TypeStructC2Pascal:=TypeVarExpected;Exit;End;
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  Name:=XtrkWord(Info.I,Info.Line);
  If Name=''Then Begin
   TypeStructC2Pascal:=VarNameExpected;
   Exit;
  End;
  Case Info.Line[Info.I]of
   '[': Begin
	 Inc(Info.I,Length('['));
	 WordC:=XtrkCNm2Pas(Info.I,Info.Line);
	 If WordC=''Then Begin
          TypeStructC2Pascal:=NumberOfArrayExpected;
          Exit;
         End;
	 If Info.Line[Info.I]<>']'Then Begin
	  TypeStructC2Pascal:=CloseArrayExpected;
	  Exit; (* ']' attendu. *)
	 End;
	 Inc(Info.I,Length(']'));
	 If Info.Line[Info.I]<>';'Then Begin
	  TypeStructC2Pascal:=PointCommaExpected;
	  Exit; (* ';' attendu. *)
	 End;
	 TypeVar:='Array[0..'+WordC+'] of '+VarC2Pas(TypeVar,True);
	End;
   ';':;
   #125:Begin
	 TypeStructC2Pascal:=PointCommaExpected;
	 Exit; (* ';' attendu. *)
	End;
   Else Begin
	 TypeStructC2Pascal:=SyntaxError;
	 Exit; (* Erreur de syntaxe *)
	End;
  End;
  Inc(Info.I);
{  If(BV.WordExist(Name))Then Begin
   TypeStructC2Pascal:=VarStructDupl;
   Exit; (* Duplication de structure de variable. *)
  End;}
  If IsReservedWordPascal(Name)Then Begin
   TypeStructC2Pascal:=UsePascalReservedWordForVar;
   Exit; (* Mot Pascal r,serv, utilis, comme variable. *)
  End;
  If(NameLen>ML)Then ML:=NameLen;
  BVAdd(BV,Name,TypeVar);
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeStructC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  Ok:=(Info.Line[Info.I]=#125);
 Until Ok;
 Inc(Info.I,Length(#125));
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeStructC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 WordC:=XtrkWord(Info.I,Info.Line);
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeStructC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 If Info.Line[Info.I]<>';'Then Begin
  TypeStructC2Pascal:=PointCommaExpected;
  Exit; (* ';' attendu. *)
 End;
 Inc(Info.I,Length(';'));
 If(Info.Mode<>_Type_)Then Begin
  Info.Mode:=_Type_;
  WriteLn(Info.HandlePas,'Type');
  WriteLn(Info.HandlePas);
 End;
 WriteLn(Info.HandlePAS,' ':5,WordC,'=Record');
 For J:=0to BVGetMaxWord(BV)do Begin
  BVGetWord(BV,J,Name,TypeVar);
  WriteLn(Info.HandlePas,' ':10+WordCLen,PadRight(Name,ML),':',VarC2Pas(TypeVar,True),';');
 End;
 WriteLn(Info.HandlePas,' ':8+WordCLen,'End;');
 BVDone(BV);
End;

Function SkipSpcRem(Var Info:SwitchC2Pascal;Put:Boolean):Boolean;Begin
 SkipSpcRem:=False;
 While Info.I>Length(Info.Line)do Begin
  If EOF(Info.HandleC)Then Exit;
  If(Put)Then WriteLn(Info.HandlePas);
  If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
 End;
 If Info.Line[Info.I]='/'Then Begin
  If Length(Info.Line)>=Info.I+1Then Begin
   If Info.Line[Info.I+1]in['/','*']Then Begin
    If Not(CommentC2Pascal(Info,Put))Then Exit;
    While Info.I>Length(Info.Line)do Begin
     If(EOF(Info.HandleC))Then Exit;
     If(Put)Then WriteLn(Info.HandlePas);
     If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
    End;
   End;
  End;
 End;
 While Info.Line[Info.I]in[' ',#9]do Begin
  If(Put)Then Write(Info.HandlePas,Info.Line[Info.I]);
  Inc(Info.I);
  While Info.I>Length(Info.Line)do Begin
   If EOF(Info.HandleC)Then Exit;
   If(Put)Then WriteLn(Info.HandlePAS);
   If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
  End;
  If Info.Line[Info.I]='/'Then Begin
   If Length(Info.Line)>=Info.I+1Then Begin
    If Info.Line[Info.I+1]in['/','*']Then Begin
     If Not(CommentC2Pascal(Info,Put))Then Exit;
     While Info.I>Length(Info.Line)do Begin
      If EOF(Info.HandleC)Then Exit;
      If(Put)Then WriteLn(Info.HandlePas);
      If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
     End;
    End;
   End;
  End;
 End;
 SkipSpcRem:=True;
End;

Function TypeEnumC2Pascal(Var Info:SwitchC2Pascal):Integer;
Var
 Ok:Boolean;
 BW:ArrayList;
 J:Integer;
 WordC:String;
Begin
 TypeEnumC2Pascal:=0;
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeEnumC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 If Info.Line[Info.I]<>#123Then Begin
  TypeEnumC2Pascal:=OpenEnsExpected;
  Exit;{#123 attendu.}
 End;
 Inc(Info.I,Length(#123));
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeEnumC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 If Info.Line[Info.I]=#125Then Begin
  TypeEnumC2Pascal:=EnumEmpty;
  Exit;
 End;
 ArrayListInit(BW);
 Ok:=False;
 Repeat
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeEnumC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  WordC:=XtrkWord(Info.I,Info.Line);
  If WordC=''Then Begin
   TypeEnumC2Pascal:=EnumExpected;
   Exit;
  End;
{  If(BW.WordExist(WordC))Then Begin
   TypeEnumC2Pascal:=EnumDupl;
   Exit; (* Duplication d',numeration. *)
  End;}
  ArrayListAddStr(BW,WordC);
  If Not(SkipSpcRem(Info,False))Then Begin
   TypeEnumC2Pascal:=EndOfSourceExpected;
   Exit;
  End;
  Case Info.Line[Info.I]of
   ',': ;
   #125: Ok:=True;
   Else Begin
    TypeEnumC2Pascal:=SyntaxError;
    Exit;
   End;
  End;
  Inc(Info.I);
 Until Ok;
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeEnumC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 WordC:=XtrkWord(Info.I,Info.Line);
 If Not(SkipSpcRem(Info,False))Then Begin
  TypeEnumC2Pascal:=EndOfSourceExpected;
  Exit;
 End;
 If Info.Line[Info.I]<>';'Then Begin
  TypeEnumC2Pascal:=PointCommaExpected;
  Exit; (* ';' attendu.*)
 End;
 Inc(Info.I,Length(';'));
 If(Info.Mode<>_Type_)Then Begin
  Info.Mode:=_Type_;
  WriteLn(Info.HandlePas,'Type');
  WriteLn(Info.HandlePas);
 End;
 WriteLn(Info.HandlePas,' ':5,WordC,' = (');
 For J:=0to ArrayListMaxList(BW)do Begin
  Write(Info.HandlePas,' ':6,ArrayList_GetStr(BW,J));
  If(ArrayListMaxList(BW)<>J)Then Write(Info.HandlePas,',');
  WriteLn(Info.HandlePas);
 End;
 WriteLn(Info.HandlePas,' ':5,');');
 ArrayListDone(BW);
End;

Function ExtractLine(Var I:Byte;Var Line:String;Var Handle:Text;Var L:LongInt):Boolean;Begin
 ExtractLine:=False;
 If EOF(Handle)Then Exit;
 FillChar(Line,SizeOf(Line),0);
 ReadLn(Handle,Line);
 Inc(L);I:=1;
 ExtractLine:=True;
End;

Function CommentC2Pascal(Var Info:SwitchC2Pascal;Put:Boolean):Boolean;Begin
 CommentC2Pascal:=False;
 Inc(Info.I);
 If Info.I<=Length(Info.Line)Then Begin
  Case Info.Line[Info.I]of
   '/':Begin
    If(Put)Then Write(Info.HandlePAS,#123,Copy(Info.Line,Info.I+1,255),#125);
    Info.I:=Length(Info.Line)+1;
   End;
   '*':Begin
    If(Put)Then Write(Info.HandlePAS,'(*');
    Inc(Info.I);
    While Info.I>Length(Info.Line)do Begin
     If(EOF(Info.HandleC))Then Exit;
     If(Put)Then WriteLn(Info.HandlePas);
     If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
    End;
    While Not((Info.Line[Info.I]='*')and(Info.Line[Info.I+1]='/'))do Begin
     If(Put)Then Write(Info.HandlePAS,Info.Line[Info.I]);
     Inc(Info.I);
     While Info.I>Length(Info.Line)do Begin
      If EOF(Info.HandleC)Then Exit;
      If(Put)Then WriteLn(Info.HandlePAS);
      If Not(ExtractLine(Info.I,Info.Line,Info.HandleC,Info.L))Then Exit;
     End;
    End;
    If(Put)Then Write(Info.HandlePAS,'*)');
    Inc(Info.I,Length('*)'));
   End;
   Else
   Begin
    If(Put)Then Write(Info.HandlePAS,'/');
    Inc(Info.I);
   End;
  End;
 End
  Else
 Begin
  If(Put)Then Write(Info.HandlePAS,'/');
 End;
 CommentC2Pascal:=True;
End;

Procedure HaltMsg(Var Q:SwitchC2Pascal;Const Msg:String);Begin
 WriteLn('Erreur ',Q.NameC,' ',Q.L,': ',Msg);
 If(Q.WarningMsg)Then WriteLn('*** ',WarnNum,' attention(s) ***');
 WriteLn('*** 1 erreur       ***');
 WriteLn;
 WriteLn('      MÇmoire disponible ',MemAvail);
 WriteLn;
 Close(Q.HandlePas);
 Halt;
End;

Procedure HaltOutOfMemory(Var Q:SwitchC2Pascal);Begin
 HaltMsg(Q,'Manque de mÇmoire.');
End;

Procedure Warning(Var Q:SwitchC2Pascal;Const Msg:String);Begin
 If(Q.WarningMsg)Then Begin
  WriteLn('Attention ',Q.NameC,' ',Q.L,': ',Msg);
  Inc(WarnNum);
 End;
End;

Procedure StartUpC2Pas(Var Q:SwitchC2Pascal);Var I:Byte;Str:String;

 Procedure Help;Begin
  WriteLn('C2PAS - Cette commande permet de convertir un fichier .C en .PAS.');
  WriteLn;
  WriteLn('Syntaxe : C2PAS [fichier[.C]] [ option ]');
  WriteLn(' * = par dÇfaut');
  WriteLn;
  WriteLn(' /?     Retourne ces messages');
  WriteLn(' /NR    Pas de remarque');
  WriteLn(' /NU    Distinction entre les Minuscule/Majuscule');
  WriteLn(' /NW    Pas de message d''attention');
  WriteLn(' /R   * Remarque');
  WriteLn(' /U   * Pas de distinction entre les Majuscules/Minuscule');
  WriteLn(' /W   * Message d''attention');
  WriteLn;
  WriteLn;
  Halt;
 End;

Begin
 If ParamCount=0Then Help;
 For I:=1to ParamCount do Begin
  Str:=StrUp(ParamStr(I));
  If(Str='-H')or(Str='--HELP')Then Help Else
  If Str[1]='/'Then Begin
   If Str='/?'Then Help else
   If Str='/NR'Then Q.Rem:=False else
   If Str='/NU'Then NoUpper:=True else
   If Str='/NW'Then Q.WarningMsg:=False else
   If Str='/R'Then Q.Rem:=True else
   If Str='/U'Then NoUpper:=False else
   If Str='/W'Then Q.WarningMsg:=True
    Else
   Begin
    System.WriteLn('Erreur: Paramätre non-reconnue "',ParamStr(I),'".');
    Halt;
   End;
  End
   Else
  Q.SourceName:=Str;
 End;
 If(Q.Rem)Then System.WriteLn(' ˛ Commentaire dÇtaillÇ');
 If Not(NoUpper)Then System.WriteLn(' ˛ Pas de distinction majuscule/minuscule');
 If(Q.WarningMsg)Then System.WriteLn(' ˛ Retourne les messages d''attention');
 System.WriteLn;
End;

Procedure PPInit(Var K:PackProc);Begin
 FillChar(K,SizeOf(K),0);
End;

Procedure PPPushProc(Var K:PackProc;Q:SwitchC2Pascal;Const Name:String);Begin
 PPPushFunc(K,Q,Name,'');
End;

Procedure PPPushFunc(Var K:PackProc;Q:SwitchC2Pascal;Const Name:String;FuncType:String);
Var
 TMC:PackProcPtr;
 BMC:PackProcRecord;
 PName,PFuncType:PChar;
Begin
 PName:=MemAlloc(Length(Name)+1);
 If(PName=NIL)Then HaltOutOfMemory(Q);
 StrPCopy(PName,Name);
 If FuncType<>''Then Begin
  PFuncType:=MemAlloc(Length(FuncType)+1);
  If(PFuncType=NIL)Then HaltOutOfMemory(Q);
  StrPCopy(PFuncType,FuncType);
 End
  Else
 PFuncType:=NIL;
 BMC.Name:=PName; BMC.Func:=FuncType<>''; BMC.FuncType:=PFuncType;
 BMC.Previous:=NIL;
 BMC.Next:=NIL;
 TMC:=K.List;
 If(TMC<>NIL)Then Begin
  While(TMC^.Next<>NIL)do TMC:=TMC^.Next;
  BMC.Previous:=TMC;
  TMC^.Next:=MemAlloc(SizeOf(K.List^));
  K.EndList:=TMC^.Next;
  If(TMC^.Next=NIL)Then Exit;
  Move(BMC,TMC^.Next^,SizeOf(K.List^));
 End
  Else
 Begin
  TMC:=MemAlloc(SizeOf(K.List^));
  If(TMC=NIL)Then Exit;
  K.List:=TMC;
  K.EndList:=K.List;
  Move(BMC,TMC^,SizeOf(K.List^));
 End;
End;

Function  PPGetLastProcName(Var K:PackProc):String;Begin
 If(K.EndList<>NIL)Then PPGetLastProcName:=StrPas(K.EndList^.Name)
                   Else PPGetLastProcName:='';
End;

Procedure PPDone(Var K:PackProc);Begin
End;

Var
 Proc:PackProc;

Procedure InitC2Pas(Var Q:SwitchC2Pascal);
Var
 I:Byte;
Begin
 FillChar(Q,SizeOf(Q),0);
 Q.WarningMsg:=True;
 NoUpper:=False;
 Q.Rem:=True;Q.Beg:=0;
 PPInit(Proc);
 {$IFDEF TABLEEXTENSION}
  LineNum:=0;
  For I:=0to 45do Proc.PushFunc(Q,StrPas(@ProcBuffer[I,0]),StrPas(@ProcBuffer[I,1]));
 {$ENDIF}
End;

Function Error(Var Q:SwitchC2Pascal;Err:Integer):Boolean;Begin
 Error:=Err>0;
 If Err>0Then HaltMsg(Q,GetErrMsg(Err));
End;

Procedure DumpWarning(Var Q:SwitchC2Pascal);
Var
 I:Byte;
Begin
 For I:=1to(Q.WarPos)do Begin
  Q.L:=Q.Warning[Q.WarPos-1].Line;
  Case Q.Warning[Q.WarPos-1].War of
   SkipDefineFar: Warning(Q,'DÇfinition "far" non spÇcifiÇ.');
   SkipDefineSizeOf: Warning(Q,'DÇfinition "sizeof" non dÇclarÇ.');
   DuplicateDefineSymbol: Warning(Q,'Duplicate de symbole de definition.');
   WrongValueInDefineDirective: Warning(Q,'Valeur incompatible dans la dÇfinition de la directive.');
  End;
 End;
End;

Procedure ConvFile(Var Q:SwitchC2Pascal;Const FileName:String);
Var
 WordC,UWordC,ProcName,Msg:String;
 InProc,EndMissing,SkipBeg,Signed,Defined:Boolean;
 TPath:PathStr;D:DirStr;
 N:NameStr;E:ExtStr;
 Err:Integer;

 Procedure ExtractLine;Begin
  FillChar(Q.Line,SizeOf(Q.Line),0);
  ReadLn(Q.HandleC,Q.Line);
  Inc(Q.L);
  Q.I:=1;
 End;

 Function ConvComment(Put:Boolean):Boolean;Begin
  ConvComment:=True;
  If Not(CommentC2Pascal(Q,Put))Then ConvComment:=Not Error(Q,EndOfCommentExpected);
 End;

 Procedure SkipSpcRem(Put:Boolean);Begin
  If Q.I>Length(Q.Line)Then Begin
   If(Put)Then WriteLn(Q.HandlePas);
   ExtractLine;
  End;
  If Q.Line[Q.I]='/'Then Begin
   If Length(Q.Line)>=Q.I+1Then Begin
    If Q.Line[Q.I]in['/','*']Then ConvComment(False);
    If Q.I>Length(Q.Line)Then Begin
     If(Put)Then WriteLn(Q.HandlePas);
     ExtractLine;
    End;
   End;
  End;
  While Q.Line[Q.I]in[' ',#9]do Begin
   If(Put)Then Write(Q.HandlePas,Q.Line[Q.I]);
   Inc(Q.I);
   If Q.I>Length(Q.Line)Then Begin
    If EOF(Q.HandleC)Then Begin
     If Error(Q,EndOfCommandExpected)Then Exit;{ Fin de commande attendu. }
    End;
    If(Put)Then WriteLn(Q.HandlePas);
    ExtractLine;
   End;
   If Q.Line[Q.I]='/'Then Begin
    If Length(Q.Line)>=Q.I+1Then Begin
     If Q.Line[Q.I]in['/','*']Then Begin
      If Not ConvComment(False)Then Exit;
     End;
     If Q.I>Length(Q.Line)Then Begin
      If EOF(Q.HandleC)Then Begin
       If Error(Q,EndOfCommandExpected)Then Exit;{ Fin de commande attendu. }
      End;
      If(Put)Then WriteLn(Q.HandlePas);
      ExtractLine;
     End;
    End;
   End;
  End;
 End;

 Procedure GotoPointVirgule;Begin
  If Q.I>Length(Q.Line)Then Begin
   WriteLn(Q.HandlePas);
   ExtractLine;
  End;
  While Q.Line[Q.I]<>';'do Begin
   Case Q.Line[Q.I]of
    '-': Begin
	  Inc(Q.I);
	  Case Q.Line[Q.I]of
	   '>': Write(Q.HandlePas,'.');
	   Else Write(Q.HandlePas,'-'+Q.Line[Q.I]);
	  End;
	 End;
    Else Write(Q.HandlePas,Q.Line[Q.I]);
   End;
   Inc(Q.I);
   If Q.I>Length(Q.Line)Then Begin
    If EOF(Q.HandleC)Then Error(Q,EndOfCommentExpected); { Fin de commentaire attendu. }
    WriteLn(Q.HandlePAS);
    ExtractLine;
   End;
  End;
 End;

 Function ExtractCWord:String;Begin
  While(Q.Line[Q.I]='-')and(Q.Line[Q.I+1]='>')do Begin
   Inc(Q.I,Length('->'));
   WordC:=WordC+'.'+XtrkWord(Q.I,Q.Line);
  End;
  UWordC:=AutoUp(WordC);
 End;

 Procedure ExtractFuncArg;
 Var
  UHeader,Header,VarName:String;
 Begin
  SkipSpcRem(False);
  If Q.Line[Q.I]='('Then Begin
   Write(Q.HandlePas,'(');
   Inc(Q.I);
   If Q.I>Length(Q.Line)Then Exit;
   While Q.Line[Q.I]<>')'do Begin
    SkipSpcRem(False);
    If Q.Line[Q.I]=','Then Begin
     Write(Q.HandlePas,';');
     Inc(Q.I);
     SkipSpcRem(False);
    End;
    If IsLangChrWord(Q.Line[Q.I])Then Begin
     Header:=XtrkWord(Q.I,Q.Line);
     SkipSpcRem(False);
    End;
    Case Q.Line[Q.I]of
     '/': ConvComment(True);
     ')': Begin
      Write(Q.HandlePas,Header);
      Break;
     End;
     #123: Error(Q,MisplacedBeginSymbol); { Symbole de dÇbut mal placÇ. }
     ';': Error(Q,MisplacedPointComma);  { ';' mal placÇ. }
     Else Begin
	   If Q.Line[Q.I]='*'Then Begin
	    Write(Q.HandlePas,'^');
	    Inc(Q.I);
	   End;
	   VarName:=XtrkWord(Q.I,Q.Line);
	   Write(Q.HandlePas,VarName+':');
	   UHeader:=StrUp(UHeader);
	   If UHeader='UNSIGNED'Then Begin
	    SkipSpcRem(False);
	    Header:=XtrkWord(Q.I,Q.Line);
            UHeader:=StrUp(Header);
	    If UHeader='UNSIGNED'Then HaltMsg(Q,'Variable illogique 2 fois non-signÇ...') else
	    If UHeader='SHORT'Then Write(Q.HandlePas,'Word') else
	    If UHeader='INT'Then Write(Q.HandlePas,'Word') else
	    If UHeader='LONG'Then Write(Q.HandlePas,'LongInt{Word}') else
	    If UHeader='FLOAT'Then Write(Q.HandlePas,'Real') else
	    If UHeader='DOUBLE'Then Write(Q.HandlePas,'Double') else
	    If UHeader='CHAR'Then Write(Q.HandlePas,'Char')
	     else
	    Write(Q.HandlePas,Header);
	   End
	    Else
	   If UHeader='SHORT'Then Write(Q.HandlePas,'Integer')else
	   If UHeader='INT'Then Write(Q.HandlePas,'Integer')else
	   If UHeader='LONG'Then Write(Q.HandlePas,'LongInt')else
	   If UHeader='FLOAT'Then Write(Q.HandlePas,'Real')else
	   If UHeader='DOUBLE'Then Write(Q.HandlePas,'Double')else
	   If UHeader='CHAR'Then Write(Q.HandlePas,'Char')
	    else
	   Write(Q.HandlePas,Header);
	  End;
    End;
    If Q.I>Length(Q.Line)Then Begin
     If EOF(Q.HandleC)Then Error(Q,EndOfArgumentExpected);
     WriteLn(Q.HandlePas);
     ExtractLine;
    End;
   End;
   Inc(Q.I);
   Write(Q.HandlePas,')');
  End;
 End;

 Function FuncVar(Name,NamePascal:String):Boolean;Begin
  FuncVar:=UWordC=Name;
  If(UWordC=Name)Then Begin
   SkipSpcRem(False);
   WordC:=XtrkWord(Q.I,Q.Line);
   Case Q.Line[Q.I]of
    '/': ConvComment(True);
    '=': Begin
	  If(Q.Mode<>_Const_)Then Begin
	   WriteLn(Q.HandlePas);
	   WriteLn(Q.HandlePas,'Const');
	   WriteLn(Q.HandlePas);
	   Q.Mode:=_Const_;
	  End;
	  Write(Q.HandlePas,' ':6,WordC,'=',XtrkWord(Q.I,Q.Line));
	  If Q.Line[Q.I]=','Then Inc(Q.I,Length(','));
	 End;
    ',': Begin
	  If(Q.Mode<>_Var_)Then Begin
	   WriteLn(Q.HandlePas);
	   WriteLn(Q.HandlePas,'Var');
	   WriteLn(Q.HandlePas);
	   Q.Mode:=_Var_;
	  End;
	  WriteLn(Q.HandlePas,' ':4,WordC,':',NamePascal,';');
	  Inc(Q.I);
	  While Q.Line[Q.I]<>';'do Begin
	   SkipSpcRem(False);
	   WordC:=XtrkWord(Q.I,Q.Line);
	   Write(Q.HandlePas,WordC,':');
	   If Q.Line[Q.I]='['Then Begin
	    Inc(Q.I,Length('['));
	    WordC:=XtrkDecNm(Q.I,Q.Line);
	    WriteLn(Q.HandlePas,' ':4,WordC+'Array[0..'+
		    XtrkDecNm(Q.I,Q.Line)+']of '+NamePascal+';');
	    Inc(Q.I,Length(']'));
	    SkipSpcRem(False);
	    If Q.Line[Q.I]=','Then Inc(Q.I,Length(','));
	   End
	    Else
	   Begin
	    WriteLn(Q.HandlePas,' ':4,NamePascal,';');
	    SkipSpcRem(False);
	    If Q.Line[Q.I]=','Then Inc(Q.I,Length(','));
	   End;
	   If Q.Line[Q.I]='='Then Begin
	    Write(Q.HandlePas,'='+XtrkWord(Q.I,Q.Line));
	    If Q.Line[Q.I]=','Then Inc(Q.I,Length(','));
	   End;
	  End;
	  Inc(Q.I);
	 End;
    ';': Begin
	  If(Q.Mode<>_Var_)Then Begin
	   WriteLn(Q.HandlePas);
	   WriteLn(Q.HandlePas,'Var');
	   WriteLn(Q.HandlePas);
	   Q.Mode:=_Var_;
	  End;
	  Write(Q.HandlePas,' ':4,WordC,':',NamePascal,';');
	  Inc(Q.I);
	 End;
    '[': Begin
	  If(Q.Mode<>_Var_)Then Begin
	   WriteLn(Q.HandlePas);
	   WriteLn(Q.HandlePas,'Var');
	   WriteLn(Q.HandlePas);
	   Q.Mode:=_Var_;
	  End;
	  Inc(Q.I);
	  WriteLn(Q.HandlePas,' ':4,WordC,':Array[0..',
		  XtrkDecNm(Q.I,Q.Line),']of ',NamePascal,';');
	  Inc(Q.I,Length('];'));
         End;
    Else If Q.Beg>0Then Write(Q.HandlePas,#123,NamePascal,#125)
	  Else
	 Begin
	  Q.Mode:={_Func_}_None_;
	  Write(Q.HandlePas,'Function ',WordC);
	  If WordC=''Then HaltMsg(Q,'Nom de la fonction attendue.');
	  PPPushFunc(Proc,Q,WordC,NamePascal);
	  InProc:=True;
	  ExtractFuncArg;
	  Write(Q.HandlePas,':'+NamePascal+';');
	 End;
   End;
  End
 End;

 Function ExtractCNum:String;Begin
  ExtractCNum:=XtrkCNm2Pas(Q.I,Q.Line);
 End;

 Procedure _And;Begin
  If Q.Line[Q.I]='&'Then Begin
   Inc(Q.I);
   If Q.Line[Q.I]='&'Then Inc(Q.I);
   Write(Q.HandlePas,' and ');
  End;
 End;

 Procedure _Or;Begin
  If Q.Line[Q.I]='|'Then Begin
   Inc(Q.I);
   If Q.Line[Q.I]='|'Then Inc(Q.I);
   Write(Q.HandlePas,' or ');
  End;
 End;

 Procedure _Shl;Begin
  If(Q.Line[Q.I]='<')and(Q.Line[Q.I+1]='<')Then Begin
   Inc(Q.I,Length('<<'));
   Write(Q.HandlePas,' shl ');
  End
   Else
  Begin
   Write(Q.HandlePas,'<');
   Inc(Q.I);
  End;
 End;

 Procedure _Shr;Begin
  If(Q.Line[Q.I]='>')and(Q.Line[Q.I+1]='>')Then Begin
   Inc(Q.I,Length('>>'));
   Write(Q.HandlePas,' shr ');
  End
   Else
  Begin
   Write(Q.HandlePas,'>');
   Inc(Q.I);
  End;
 End;

 Procedure DumpEnd;
 Var
  TStr:String;
 Begin
  While Q.I<=Length(Q.Line)do Begin
   Case Q.Line[Q.I]of
     '/': ConvComment(True);
     '<': _Shl;
     '>': _Shr;
     '|': _Or;
     '&': _And;
     '-': Begin
	   Inc(Q.I);
	   Case Q.Line[Q.I]of
	    '>': Begin
		  Write(Q.HandlePas,'.');
		  Inc(Q.I);
		 End;
	     Else Write(Q.HandlePas,'-');
	    End;
	   End;
     '0': Begin
	   TStr:=ExtractCNum;
	   If TStr<>''Then Write(Q.HandlePas,TStr)
	    Else
	   Begin
	    Write(Q.HandlePas,Q.Line[Q.I]);
	    Inc(Q.I);
	   End;
	  End;
     Else Begin
	   Write(Q.HandlePas,Q.Line[Q.I]);
	   Inc(Q.I);
	  End;
   End;
  End;
 End;

 Procedure ConvShl;Begin
  Inc(Q.I);
  If Q.Line[Q.I]='<'Then Begin
   Inc(Q.I);
   Case Q.Line[Q.I]of
    '=':Begin
     Write(Q.HandlePas,WordC+':=',WordC,' shl ');
     Inc(Q.I);
    End;
    Else Write(Q.HandlePAS,WordC,' shl ');
   End;
  End
   Else
  Write(Q.HandlePas,WordC,'<');
 End;

 Procedure ConvShr;Begin
  Inc(Q.I);
  If Q.Line[Q.I]='>'Then Begin
   Inc(Q.I);
   Case Q.Line[Q.I]of
    '=': Begin
	  Write(Q.HandlePas,WordC,':=',WordC,' shr ');
	  Inc(Q.I);
	 End;
    Else Write(Q.HandlePas,WordC,' shr ');
   End;
  End
   Else
  Write(Q.HandlePas,WordC,'<');
 End;

 Procedure TypeEnum;Begin
  Error(Q,TypeEnumC2Pascal(Q));
 End;

 Procedure TypeStruct;Begin
  Error(Q,TypeStructC2Pascal(Q));
 End;

Begin
 Q.NameC:=FileName;
 Q.Mode:=_None_;Q.PathHeader:=PathHeader;
 InProc:=False;
 Assign(Q.HandleC,Q.NameC);
 Reset(Q.HandleC);
 If IOResult<>0Then Begin
  WriteLn('Erreur: Fichier ''',Q.NameC,''' introuvable.');
  Halt;
 End;
 FSplit(Q.NameC,D,N,E);
 WriteLn;
 WriteLn(N+E,':');
 Repeat
  ExtractLine;
  While Q.I<=Length(Q.Line)do Begin
   Case Q.Line[Q.I]of
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*               Comment(s)                *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '/' : ConvComment(True);
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*               And (&,&&)                *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '&': _And;
    '<': Begin
     WordC:='';
     ConvShl;
    End;
    '>': Begin
     WordC:='';
     ConvShr;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*                 String                  *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '"':Begin
     WordC:=XtrkCStr(Q.I,Q.Line,EndMissing);
     Write(Q.HandlePas,'''' + WordC + '''');
     Inc(Q.I);
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*                   Word(s)               *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    'A'..'Z','a'..'z','_':Begin
     WordC:=XtrkWord(Q.I,Q.Line);
     UWordC:=AutoUp(WordC);
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                 TypeDef                 *}
     {* * * * * * * * * * * * * * * * * * * * * *}
     If UWordC='TYPEDEF'Then Begin
      If(Q.Mode<>_Type_)Then Begin
       WriteLn(Q.HandlePAS);
       WriteLn(Q.HandlePAS,'Type');
       WriteLn(Q.HandlePAS);
       Q.Mode:=_Type_
      End;
      SkipSpcRem(False);
      If IsLangChrWord(Q.Line[Q.I])Then Begin
       WordC:=XtrkWord(Q.I,Q.Line);
       If WordC=''Then Error(Q,TypedefNameExpected);
       UWordC:=AutoUp(WordC);
       If UWordC=AutoUp('enum')Then TypeEnum else
       If UWordC=AutoUp('struct')Then TypeStruct
	else
       Begin
	Signed:=True;
	If UWordC='UNSIGNED'Then Begin
	 Signed:=False;
	 SkipSpcRem(False);
	 If IsLangChrWord(Q.Line[Q.I])Then Begin
	  WordC:=XtrkWord(Q.I,Q.Line); UWordC:=StrUp(WordC);
	  If(WordC='SIGNED')or(WordC='UNSIGNED')Then HaltMsg(Q,'Format de variable non-logique.');
	 End;
	End
	 Else
	If UWordC='SIGNED'Then Begin
	 Signed:=True;
	 SkipSpcRem(False);
	 If IsLangChrWord(Q.Line[Q.I])Then Begin
	  WordC:=XtrkWord(Q.I,Q.Line); UWordC:=StrUp(WordC);
	  If(UWordC='SIGNED')or(UWordC='UNSIGNED')Then HaltMsg(Q,'Format de variable non-logique.');
	 End;
	End;
	Msg:=VarC2Pas(WordC,Signed);
	If Msg<>''Then WordC:=Msg;
	Write(Q.HandlePas,' ':5);
	SkipSpcRem(False);
	GotoPointVirgule;
        Write(Q.HandlePAS,' = ',WordC);
	WriteLn(Q.HandlePAS,';');
	Inc(Q.I);
       End;
      End
       Else
      HaltMsg(Q,'Erreur de syntaxe dans la dÇfinition de "typedef".');
     End
      Else
     If UWordC='STRUCT'Then Error(Q,StructC2Pascal(Q))
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                 Extern                  *}
     {* * * * * * * * * * * * * * * * * * * * * *}
      Else
     If UWordC='EXTERN'Then Begin
      WordC:=XtrkWord(Q.I,Q.Line); UWordC:=StrUp(WordC);
      If UWordC='VOID'Then Begin
       Q.Mode:={_Func_}_None_;
       Write(Q.HandlePas,'Procedure ');
       SkipSpcRem(False);
       ProcName:=XtrkWord(Q.I,Q.Line);
       If ProcName=''Then HaltMsg(Q,'Nom de la fonction attendue.');
       PPPushProc(Proc,Q,ProcName);
       Write(Q.HandlePas,ProcName,' External;');
{      SkipSpc;
      ExtractFuncArg;}
      End;
     End
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                  Void                   *}
     {* * * * * * * * * * * * * * * * * * * * * *}
      Else
     If UWordC='VOID'Then Begin
      Q.Mode:={_Func_}_None_;
      Write(Q.HandlePAS,'Procedure ');
      SkipSpcRem(False);
      ProcName:=XtrkWord(Q.I,Q.Line);
      If ProcName=''Then HaltMsg(Q,'Nom de la fonction attendue.');
      PPPushProc(Proc,Q,ProcName);
      Write(Q.HandlePAS,ProcName);
{      SkipSpc;
      ExtractFuncArg;}
      InProc:=True;
     End
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                 Return                  *}
     {* * * * * * * * * * * * * * * * * * * * * *}
      Else
     If UWordC='RETURN'Then Begin
      If(InProc)Then Begin
       Q.Mode:={_Func_}_None_;
       Write(Q.HandlePas,PPGetLastProcName(Proc),' := ');
      End
       Else
      HaltMsg(Q,'Retour de fonction indÇsirable.');
     End
      Else
     If FuncVar('SHORT','Integer')Then Q.Mode:={_Func_}_None_
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                Register                 *}
     {* * * * * * * * * * * * * * * * * * * * * *}
      Else
     If UWordC='REGISTER'Then Begin
      SkipSpcRem(False);
      WordC:=XtrkWord(Q.I,Q.Line); UWordC:=StrUp(WordC); Msg:=WordC;
      If UWordC='FILE'Then Msg:='File';
      SkipSpcRem(False);
      If Q.Line[Q.I]='*'Then Begin Msg:='^'+Msg; Inc(Q.I); End;
      FuncVar(WordC,Msg);
     End
      Else
     If FuncVar('LONG','LongInt')Then Q.Mode:={_Func_}_None_
     {* * * * * * * * * * * * * * * * * * * * * *}
     {*                  Local                  *}
     {* * * * * * * * * * * * * * * * * * * * * *}
      Else
     If UWordC='LOCAL'Then Write(Q.HandlePAS,'{ * * LOCAL * * }')Else
     If FuncVar('INT','Integer')Then Q.Mode:={_Func_}_None_ Else
     If UWordC='GLOBAL'Then Write(Q.HandlePAS,'{ * * GLOBAL * * }')Else
     If FuncVar('CHAR','Char')Then Q.Mode:={_Func_}_None_ Else
     If UWordC='PRINTF'Then Write(Q.HandlePas,'Write')
      Else
     Begin
      Error(Q,UnknownIdentifier); { Unknown identifier. }
      If(SkipBeg)Then Begin
       WriteLn(Q.HandlePas,'Begin');
       SkipBeg:=False;
      End;
      If(Q.Line[Q.I]='-')and(Q.Line[Q.I+1]='>')Then ExtractCWord;
      SkipSpcRem(False);
      Case Q.Line[Q.I]of
       '<': ConvShl;
       '>': ConvShr;
	    {* * * * * * * * * * * * * * * * * * * * * *}
	    {*                   Dec                   *}
	    {* * * * * * * * * * * * * * * * * * * * * *}
       '-': Begin
	     Inc(Q.I);
	     Case Q.Line[Q.I]of
	      '=': Begin
		    Inc(Q.I);
		    Write(Q.HandlePAS,'Dec('+WordC+',');
		    GotoPointVirgule;
		    Write(Q.HandlePAS,');');
		    Inc(Q.I);
		   End;
	      '-': Begin
		    Write(Q.HandlePas,'Dec('+WordC+')');
		    Inc(Q.I);
		   End;
	      '>': Begin
		    Write(Q.HandlePAS,WordC+'.');
		    Inc(Q.I);
		   End;
	      Else Write(Q.HandlePas,WordC+'-'+Q.Line[Q.I]);
	     End;
	    End;
	    {* * * * * * * * * * * * * * * * * * * * * *}
	    {*                   Inc                   *}
	    {* * * * * * * * * * * * * * * * * * * * * *}
       '+': Begin
	     Inc(Q.I);
	     Case Q.Line[Q.I]of
	      '=': Begin
		    Inc(Q.I);
		    Write(Q.HandlePas,'Inc(',WordC,',');
		    GotoPointVirgule;
		    Write(Q.HandlePas,');');
		    Inc(Q.I);
		   End;
	      '+': Begin
		    Write(Q.HandlePAS,'Inc(',WordC,')');
		    Inc(Q.I);
		   End;
	      Else Write(Q.HandlePas,WordC,'+',Q.Line[Q.I]);
	     End;
	    End;
       Else Write(Q.HandlePas,WordC);
      End;
     End;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*             Special Number (Hex)        *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '0':Begin
     Msg:=ExtractCNum;
     If Msg<>''Then Write(Q.HandlePAS,Msg)
               Else Error(Q,SyntaxNumber);
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*         Conditionnel Directive          *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '#':Begin
     Err:=CondC2Pascal(Q);
     DumpWarning(Q);
     Q.WarPos:=0;
     Error(Q,Err);
     If(Err=IncludeFile)Then Begin
      If Q.Output=''Then
       HaltMsg(Q,'Le fichier: '''+Q.Output+''' est introuvable.');
      Warning(Q,'Inclusion du fichier '+Q.Output+' dans le fichier principale.');
      ConvFile(Q,Q.Output);
      WriteLn;
      WriteLn(Q.NameC,':');
     End;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*                   Begin                 *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    #123:Begin
    (* If Not(InProc)Then Begin
      {* * * * * * * * * * * * * * * * * * * * * *}
      {*            Enumeration Variable         *}
      {* * * * * * * * * * * * * * * * * * * * * *}
      Inc(I,Length(#125));
      SkipSpc(No);
      ReadEnum;
     End
      Else*)
     Begin
      SkipBeg:=False;
      If Q.Beg>0Then Write(Q.HandlePas,'Begin ')
                Else SkipBeg:=True;
      Inc(Q.I,Length(#123));
      Inc(Q.Beg);
     End;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*                    End                  *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    #125:Begin
     Write(Q.HandlePas,'End;');
     Inc(Q.I,Length(#125));
     If Q.Beg=0Then Error(Q,MisplacedEndSymbol);
     Dec(Q.Beg);
     If Q.Beg=0Then InProc:=False;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*             Symbole Record/-            *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    '-':Begin
     Inc(Q.I,Length('-'));
     If Q.I<=Length(Q.Line)Then Begin
      Case Q.Line[Q.I]of
       '>':Begin
        Write(Q.HandlePas,'.');
	Inc(Q.I);
       End;
       Else Write(Q.HandlePas,'-');
      End;
     End;
    End;
    {* * * * * * * * * * * * * * * * * * * * * *}
    {*                 Execption               *}
    {* * * * * * * * * * * * * * * * * * * * * *}
    Else
    Begin
     Write(Q.HandlePAS,Q.Line[Q.I]);
     Inc(Q.I);
    End;
   End;
  End;
  WriteLn(Q.HandlePas);
 Until EOF(Q.HandleC);
 Close(Q.HandleC);
End;

Procedure DoneC2Pas(Var Q:SwitchC2Pascal);Begin
 ArrayListDone(Q.BoolDir);
 Close(Q.HandlePas);
End;

Var
 MainName:PathStr;
 D:DirStr;
 N:NameStr;
 E:ExtStr;
 NamePAS:PathStr;
 I:Byte;
 Q:SwitchC2Pascal;

BEGIN
 InitC2Pas(Q);
 StartUpC2Pas(Q);
 WarnNum:=0;
 If Q.SourceName=''Then Begin
  System.WriteLn('Erreur: Pas de nom de fichier dans les paramätres');
  Halt;
 End;
 MainName:=Q.SourceName;
 FSplit(MainName,D,N,E);
 NamePAS:=D+N+'.PAS';
 If FileExist(NamePas)Then Begin
  If(Q.WarningMsg)Then Begin
   WriteLn('Attention: Fichier existant ''',NamePAS,''', puis Çcraser');
   Inc(WarnNum);
  End;
 End;
 {$I-}Assign(Q.HandlePas,NamePas);
 Rewrite(Q.HandlePas);{$I+}
 If(Q.Rem)Then Begin
  WriteLn(Q.HandlePas,#123+DuplicateString('.',60)+#125);
  WriteLn(Q.HandlePas,#123+':                    Fichier Pascal                        :}');
  WriteLn(Q.HandlePas,#123+':'+DuplicateString('.',58)+':}');
 End;
 WriteLn(Q.HandlePas);
 ConvFile(Q,MainName);
 Close(Q.HandlePas);
 If(Q.WarningMsg)Then System.WriteLn('*** ',WarnNum,' attention(s) ***');
 WriteLn;
 WriteLn('      MÇmoire disponible ',MemAvail);
END.