{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal, Turbo Pascal)
}

Program AWK;

Uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF DARWIN}
  MacOSAll, { n�cessaire pour appeler ObjC sous macOS/iOS }
  CocoaAll,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  DOS;

Const
 TokenList:Array[0..69]of String[20]=(
  'BEGIN','BEGINFILE','END','ENDFILE','and','asort','asorti','atan2',
  'bindtextdomain','break','case','close','compl','continue','cos',
  'dcgettext','dcngettext','default','delete','do','else','eval',
  'exit','exp','fflush','for','func','function','gensub','getline',
  'gsub','if','in','include','index','int','isarray','length',
  'load','log','lshift','match','mktime','namespace','next',
  'nextfile','or','patsplit','print','printf','rand','return',
  'rshift','sin','split','sprintf','sqrt','srand','strftime',
  'strtonum','sub','substr','switch','system','systime','tolower',
  'toupper','typeof','while','xor'
 );

 FunctionList:Array[0..15]of String[12]=(
  'ATAN2','COS','EXP','GSUB','INDEX','INT','LENGTH','LOG','MATCH',
  'RAND','SIN','SPLIT','SPRINTF','SQRT','SRAND','SUBSTR'
 );

 MaxLine=1024;
 MaxVariable=100;
 MaxFields=10;
 MaxUserFunctions=50;
 MaxFunctionParams=10;
 MaxArrays=50;
 MaxArrayElements=100;
 MaxRules=50;           { Maximum de regles pattern-action }

Type
 StrPointer=^String;
 FieldArray=Array[0..MaxFields]of String;
 VarTypeEnum=(_None,_Integer,_LongInt,_Real,_String);
 VarRec=Record
  Variant:Record Case Integer of
   0:(I:Integer);
   1:(L:LongInt);
   2:(R:Real);
   3:(S:StrPointer);
  End;
  VarType:VarTypeEnum;
  VarName:String[20];
 End;
 VarPointer=^VarRec;
 { Type pour les fonctions utilisateur }
 TUserFunc=Record
  FuncName:String[32];
  ParamNames:Array[1..MaxFunctionParams]of String[20];
  ParamCount:Integer;
  BodyStartLine:Integer;  { Ligne de debut du corps de la fonction }
  BodyEndLine:Integer;    { Ligne de fin du corps de la fonction }
  BodyStartPos:Integer;   { Position dans la ligne de debut }
 End;
 { Type pour les elements de tableaux associatifs }
 TArrayElement=Record
  Key:String[64];
  Value:String[255];
 End;
 { Type pour les tableaux associatifs }
 TAssocArray=Record
  Name:String[32];
  Elements:Array[1..MaxArrayElements]of TArrayElement;
  Count:Integer;
 End;
 { Type pour les regles pattern-action }
 TRuleKind=(RK_BEGIN,RK_END,RK_REGEX,RK_EXPR,RK_ALL);
 TRule=Record
  Kind:TRuleKind;           { Type de regle }
  Pattern:String[128];      { Pattern regex ou expression }
  ActionLine:Integer;       { Ligne de debut de l'action }
  ActionPos:Integer;        { Position dans la ligne }
  ActionEndLine:Integer;    { Ligne de fin de l'action }
 End;

Var
 Fields:FieldArray;
 NumFields:Integer;
 FileAWK:Text;
 Mode:(_None_,_F,_InStringSimpleQuote);
 Terminated:Boolean;
 CurrCommand,CurrParam:String;
 FileName,CurrLine:String;
 CurrPos:Byte;
 PA:Array[1..MaxLine] of StrPointer;
 VarList:Array[1..MaxVariable]of VarPointer;
 CurrLinePtr,NumberLine:Integer;
 CurrNumberLine:Integer;
 AccoladeBlock:Integer;
 I,NumberVariable:Integer;
 EndBlockStart:Integer;  { Ligne de debut du bloc END }
 EndBlockEnd:Integer;    { Ligne de fin du bloc END }
 InEndBlock:Boolean;     { Indique si on est dans un bloc END }
 { Variables pour les fonctions utilisateur }
 UserFuncs:Array[1..MaxUserFunctions]of TUserFunc;
 UserFuncCount:Integer;
 InFunctionCall:Boolean;
 FunctionReturnValue:Real;
 FunctionReturnStr:String;
 HasFunctionReturn:Boolean;
 { Variables pour les boucles (break/continue) }
 BreakFlag:Boolean;
 ContinueFlag:Boolean;
 LoopDepth:Integer;
 { Variables pour les tableaux associatifs }
 AssocArrays:Array[1..MaxArrays]of TAssocArray;
 AssocArrayCount:Integer;
 { Variables pour les regles pattern-action }
 Rules:Array[1..MaxRules]of TRule;
 RuleCount:Integer;
 InputFile:Text;         { Fichier de donnees en entree }
 InputFileName:String;   { Nom du fichier de donnees }
 HasInputFile:Boolean;   { Indique si un fichier d'entree est specifie }
 NRValue:LongInt;        { Variable NR (numero d'enregistrement) }

{ Declaration anticipee de RunLine }
Function RunLine:Boolean; forward;

{ Declarations anticipees pour les fonctions utilisateur }
Function FindUserFunction(const FName:String):Integer; forward;
Function CallUserFunction(FuncIdx:Integer):Real; forward;

{ Declaration anticipee pour SplitIntoFields }
Procedure SplitIntoFields(Line:String); forward;

{ ========================================================= }
{ SECTION: Expressions Regex                                }
{ ========================================================= }

{ Verifie si un caractere correspond a une classe de caracteres }
Function MatchCharClass(C:Char;const CharClass:String):Boolean;
Var
 I:Integer;
 Negated:Boolean;
 InRange:Boolean;
 PrevChar:Char;
Begin
 MatchCharClass:=False;
 If Length(CharClass)=0 Then Exit;
 
 I:=1;
 Negated:=False;
 
 { Verifie si la classe est negativee }
 If CharClass[1]='^'Then Begin
  Negated:=True;
  Inc(I);
 End;
 
 InRange:=False;
 PrevChar:=#0;
 
 While I<=Length(CharClass)do Begin
  If(CharClass[I]='-')and(I>1)and(I<Length(CharClass))and(PrevChar<>#0)Then Begin
   { Range de caracteres, ex: a-z }
   Inc(I);
   If(C>=PrevChar)and(C<=CharClass[I])Then Begin
    MatchCharClass:=Not Negated;
    Exit;
   End;
   PrevChar:=#0;
  End
   Else
  Begin
   If C=CharClass[I]Then Begin
    MatchCharClass:=Not Negated;
    Exit;
   End;
   PrevChar:=CharClass[I];
  End;
  Inc(I);
 End;
 
 MatchCharClass:=Negated;
End;

{ Fonction de matching regex simplifiee }
{ Supporte: . (tout caractere), * (0 ou plus), + (1 ou plus), ? (0 ou 1),
           ^ (debut), $ (fin), [...] (classes), \d \w \s }
Function RegexMatch(const Text,Pattern:String):Boolean;
Var
 TPos,PPos:Integer;
 AnchorStart,AnchorEnd:Boolean;
 PatternWork:String;
 
 { Fonction interne recursive pour le matching }
 Function DoMatch(TI,PI:Integer):Boolean;
 Var
  CharClass:String;
  BracketEnd:Integer;
  Matched:Boolean;
  NextChar:Char;
  Quantifier:Char;
  MinMatch,I:Integer;
 Begin
  DoMatch:=False;
  
  { Si on a atteint la fin du pattern }
  If PI>Length(PatternWork)Then Begin
   If AnchorEnd Then DoMatch:=(TI>Length(Text))
                Else DoMatch:=True;
   Exit;
  End;
  
  { Si on a atteint la fin du texte mais pas du pattern }
  If TI>Length(Text)Then Begin
   { On peut encore matcher si le reste du pattern est optionnel }
   While PI<=Length(PatternWork)do Begin
    If PI<Length(PatternWork)Then Begin
     If PatternWork[PI+1]in['*','?']Then Begin
      Inc(PI,2);
      Continue;
     End;
    End;
    Exit; { Pattern non termine = pas de match }
   End;
   DoMatch:=True;
   Exit;
  End;
  
  { Traite les classes de caracteres [...] }
  If PatternWork[PI]='['Then Begin
   BracketEnd:=PI+1;
   While(BracketEnd<=Length(PatternWork))and(PatternWork[BracketEnd]<>']')do
    Inc(BracketEnd);
   CharClass:=Copy(PatternWork,PI+1,BracketEnd-PI-1);
   
   { Verifie le quantificateur apres la classe }
   Quantifier:=#0;
   If BracketEnd<Length(PatternWork)Then Begin
    If PatternWork[BracketEnd+1]in['*','+','?']Then
     Quantifier:=PatternWork[BracketEnd+1];
   End;
   
   If Quantifier='*'Then Begin
    { 0 ou plus }
    If DoMatch(TI,BracketEnd+2)Then Begin DoMatch:=True; Exit; End;
    I:=TI;
    While(I<=Length(Text))and MatchCharClass(Text[I],CharClass)do Begin
     Inc(I);
     If DoMatch(I,BracketEnd+2)Then Begin DoMatch:=True; Exit; End;
    End;
   End
    Else If Quantifier='+'Then Begin
    { 1 ou plus }
    If Not MatchCharClass(Text[TI],CharClass)Then Exit;
    I:=TI+1;
    If DoMatch(I,BracketEnd+2)Then Begin DoMatch:=True; Exit; End;
    While(I<=Length(Text))and MatchCharClass(Text[I],CharClass)do Begin
     Inc(I);
     If DoMatch(I,BracketEnd+2)Then Begin DoMatch:=True; Exit; End;
    End;
   End
    Else If Quantifier='?'Then Begin
    { 0 ou 1 }
    If DoMatch(TI,BracketEnd+2)Then Begin DoMatch:=True; Exit; End;
    If MatchCharClass(Text[TI],CharClass)Then
     DoMatch:=DoMatch(TI+1,BracketEnd+2);
   End
    Else
   Begin
    { Exactement 1 }
    If MatchCharClass(Text[TI],CharClass)Then
     DoMatch:=DoMatch(TI+1,BracketEnd+1);
   End;
   Exit;
  End;
  
  { Traite les sequences d'echappement \d \w \s \. etc }
  If PatternWork[PI]='\'Then Begin
   If PI>=Length(PatternWork)Then Exit;
   Inc(PI);
   Case PatternWork[PI]of
    'd':Matched:=Text[TI]in['0'..'9'];
    'D':Matched:=Not(Text[TI]in['0'..'9']);
    'w':Matched:=Text[TI]in['A'..'Z','a'..'z','0'..'9','_'];
    'W':Matched:=Not(Text[TI]in['A'..'Z','a'..'z','0'..'9','_']);
    's':Matched:=Text[TI]in[' ',#9,#10,#13];
    'S':Matched:=Not(Text[TI]in[' ',#9,#10,#13]);
    Else Matched:=(Text[TI]=PatternWork[PI]); { Caractere echappe }
   End;
   
   { Verifie le quantificateur }
   Quantifier:=#0;
   If PI<Length(PatternWork)Then Begin
    If PatternWork[PI+1]in['*','+','?']Then
     Quantifier:=PatternWork[PI+1];
   End;
   
   If Quantifier=#0 Then Begin
    If Matched Then DoMatch:=DoMatch(TI+1,PI+1);
   End
    Else
   Begin
    { Gere les quantificateurs pour \d, \w, etc }
    Case Quantifier of
     '*':Begin
      If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
      I:=TI;
      While I<=Length(Text)do Begin
       Case PatternWork[PI]of
        'd':Matched:=Text[I]in['0'..'9'];
        'D':Matched:=Not(Text[I]in['0'..'9']);
        'w':Matched:=Text[I]in['A'..'Z','a'..'z','0'..'9','_'];
        'W':Matched:=Not(Text[I]in['A'..'Z','a'..'z','0'..'9','_']);
        's':Matched:=Text[I]in[' ',#9,#10,#13];
        'S':Matched:=Not(Text[I]in[' ',#9,#10,#13]);
        Else Matched:=(Text[I]=PatternWork[PI]);
       End;
       If Not Matched Then Break;
       Inc(I);
       If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
      End;
     End;
     '+':Begin
      If Not Matched Then Exit;
      I:=TI+1;
      If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
      While I<=Length(Text)do Begin
       Case PatternWork[PI]of
        'd':Matched:=Text[I]in['0'..'9'];
        'D':Matched:=Not(Text[I]in['0'..'9']);
        'w':Matched:=Text[I]in['A'..'Z','a'..'z','0'..'9','_'];
        'W':Matched:=Not(Text[I]in['A'..'Z','a'..'z','0'..'9','_']);
        's':Matched:=Text[I]in[' ',#9,#10,#13];
        'S':Matched:=Not(Text[I]in[' ',#9,#10,#13]);
        Else Matched:=(Text[I]=PatternWork[PI]);
       End;
       If Not Matched Then Break;
       Inc(I);
       If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
      End;
     End;
     '?':Begin
      If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
      If Matched Then DoMatch:=DoMatch(TI+1,PI+2);
     End;
    End;
   End;
   Exit;
  End;
  
  { Le point matche tout caractere }
  If PatternWork[PI]='.'Then Begin
   { Verifie le quantificateur }
   Quantifier:=#0;
   If PI<Length(PatternWork)Then Begin
    If PatternWork[PI+1]in['*','+','?']Then
     Quantifier:=PatternWork[PI+1];
   End;
   
   Case Quantifier of
    '*':Begin
     If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
     I:=TI;
     While I<=Length(Text)do Begin
      Inc(I);
      If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
     End;
    End;
    '+':Begin
     I:=TI+1;
     If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
     While I<=Length(Text)do Begin
      Inc(I);
      If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
     End;
    End;
    '?':Begin
     If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
     DoMatch:=DoMatch(TI+1,PI+2);
    End;
    Else DoMatch:=DoMatch(TI+1,PI+1);
   End;
   Exit;
  End;
  
  { Caractere litteral }
  Quantifier:=#0;
  If PI<Length(PatternWork)Then Begin
   If PatternWork[PI+1]in['*','+','?']Then
    Quantifier:=PatternWork[PI+1];
  End;
  
  Case Quantifier of
   '*':Begin
    If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
    I:=TI;
    While(I<=Length(Text))and(Text[I]=PatternWork[PI])do Begin
     Inc(I);
     If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
    End;
   End;
   '+':Begin
    If Text[TI]<>PatternWork[PI]Then Exit;
    I:=TI+1;
    If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
    While(I<=Length(Text))and(Text[I]=PatternWork[PI])do Begin
     Inc(I);
     If DoMatch(I,PI+2)Then Begin DoMatch:=True; Exit; End;
    End;
   End;
   '?':Begin
    If DoMatch(TI,PI+2)Then Begin DoMatch:=True; Exit; End;
    If Text[TI]=PatternWork[PI]Then DoMatch:=DoMatch(TI+1,PI+2);
   End;
   Else Begin
    If Text[TI]=PatternWork[PI]Then DoMatch:=DoMatch(TI+1,PI+1);
   End;
  End;
 End;

Begin
 RegexMatch:=False;
 If Length(Pattern)=0 Then Begin
  RegexMatch:=True;
  Exit;
 End;
 
 PatternWork:=Pattern;
 AnchorStart:=False;
 AnchorEnd:=False;
 
 { Traite les ancres }
 If PatternWork[1]='^'Then Begin
  AnchorStart:=True;
  Delete(PatternWork,1,1);
 End;
 If(Length(PatternWork)>0)and(PatternWork[Length(PatternWork)]='$')Then Begin
  AnchorEnd:=True;
  Delete(PatternWork,Length(PatternWork),1);
 End;
 
 If AnchorStart Then Begin
  RegexMatch:=DoMatch(1,1);
 End
  Else
 Begin
  { Essaie de matcher a partir de chaque position }
  For TPos:=1 to Length(Text)do Begin
   If DoMatch(TPos,1)Then Begin
    RegexMatch:=True;
    Exit;
   End;
  End;
 End;
End;

{ ========================================================= }
{ SECTION: Parsing Multi-lignes                             }
{ ========================================================= }

{ Compte les accolades dans une ligne en ignorant les strings et commentaires }
Function CountBracesInLine(const Line:String):Integer;
Var
 I:Integer;
 InQuote,InApos:Boolean;
 BraceBalance:Integer;
Begin
 BraceBalance:=0;
 InQuote:=False;
 InApos:=False;
 
 For I:=1 to Length(Line)do Begin
  If Line[I]='"'Then Begin
   If Not InApos Then InQuote:=Not InQuote;
  End
   Else If Line[I]=''''Then Begin
   If Not InQuote Then InApos:=Not InApos;
  End
   Else If Not InQuote and Not InApos Then Begin
   If Line[I]='#'Then Begin
    CountBracesInLine:=BraceBalance;
    Exit;
   End;
   If Line[I]='{'Then Inc(BraceBalance)
   Else If Line[I]='}'Then Dec(BraceBalance);
  End;
 End;
 CountBracesInLine:=BraceBalance;
End;

{ Execute une ligne specifique du programme }
Function ExecuteLine(LineNum:Integer):Boolean;
Var
 SaveLine:String;
 SavePos:Integer;
 SaveLineNum:Integer;
Begin
 ExecuteLine:=True;
 If(LineNum<1)or(LineNum>NumberLine)Then Exit;
 
 SaveLine:=CurrLine;
 SavePos:=CurrPos;
 SaveLineNum:=CurrLinePtr;
 
 CurrLine:=PA[LineNum]^;
 CurrPos:=1;
 CurrLinePtr:=LineNum;
 
 { Saute les espaces }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in[' ',#9])do Inc(CurrPos);
 
 If CurrPos<=Length(CurrLine)Then
  ExecuteLine:=RunLine;
 
 CurrLine:=SaveLine;
 CurrPos:=SavePos;
 CurrLinePtr:=SaveLineNum;
End;

{ Remplace tous les caracteres OldChar par NewChar dans une chaine }
Function ReplaceChar(S:String;OldChar,NewChar:Char):String;
Var
 J:Integer;
Begin
 For J:=1 to Length(S)do Begin
  If S[J]=OldChar Then S[J]:=NewChar;
 End;
 ReplaceChar:=S;
End;

Function GetRawCommandLine:String;
{$IFDEF FPC}
 {$IFDEF WINDOWS}
  Var
   pw:PWideChar;
  Begin
   pw:=GetCommandLineW();
   GetRawCommandLine:=UTF8Encode(WideString(pw)); { convertir UTF-16 vers UTF-8 }
  End;
 {$ELSE}
  {$IFDEF LINUX}
   Var
     CmdFile:Text;
     Buffer,CmdResult:String;
   Begin
    CmdResult:='';
    Assign(CmdFile, '/proc/self/cmdline');
    {$I-}Reset(CmdFile);{$I+}
    If IOResult=0 Then Begin
     While Not EOF(CmdFile)do Begin
      Read(CmdFile, Buffer);
      CmdResult:=CmdResult+Buffer;
     End;
     Close(CmdFile);
    End;
    { /proc/self/cmdline s�pare les param�tres avec #0 }
    GetRawCommandLine:= ReplaceChar(CmdResult, #0, ' ');
   End;
  {$ELSE}
   {$IFDEF DARWIN}
    Var
     ProcInfo:NSObject;
     nsArgs:NSArray;
     i:Integer;
     argStr:NSString;
    Begin
     procInfo:=NSProcessInfo.processInfo;
     nsArgs:=NSProcessInfo(procInfo).arguments;
     GetRawCommandLine:='';
     For i:=0 to nsArgs.count-1 do Begin
      argStr:= NSString(nsArgs.objectAtIndex(i));
      GetRawCommandLine:=GetRawCommandLine+UTF8Encode(argStr.UTF8String)+' ';
     End;
    End;
   {$ELSE}
    Var
     S:String;
    Begin
     S:='';
     For I:=1 to ParamCount do Begin
      S:=S+ParamStr(I);
     End;
     GetRawCommandLine:=S;
    End;
   {$ENDIF}
  {$ENDIF}
 {$ENDIF}
{$ELSE}
 Var
  PtrStr:^String;
 Begin
  PtrStr:=Ptr(PrefixSeg,$80);
  GetRawCommandLine:=PtrStr^;
 End;
{$ENDIF}

Function IsDelimiter(C:Char):Boolean;Begin
 IsDelimiter:=(C=' ')or(C=#9)or(C=#13)or(C=#10);
End;

Function RawParamCount:Integer;
Var
 PC:Integer;
 I:Integer;
 InQuote,InApos,InBrace:Boolean;
 CmdLine:String;
Begin
 PC:=0;
 InQuote:=False;
 InApos:=False;
 InBrace:=False;
 CmdLine:=GetRawCommandLine;
 I:=1;
 While I<=Length(CmdLine)do Begin
  While(I<=Length(CmdLine))and(IsDelimiter(CmdLine[I]))do Inc(I);
  If I<=Length(CmdLine)Then Begin
   Inc(PC);
   While(I<=Length(CmdLine))do Begin
    Case CmdLine[I]of
     '"':If Not(InApos)and Not(InBrace)Then InQuote:=Not(InQuote);
     '''':If Not(InQuote)and Not(InBrace)Then InApos:=Not(InApos);
     '{':If Not(InQuote)and Not(InApos)Then InBrace:=True;
     '}':If Not(InQuote)and Not(InApos)Then InBrace:=False;
     ' ',#9,#13,#10:If Not(InQuote)and Not(InApos)and Not(InBrace)Then Break;
    End;
    Inc(I);
   End;
  End;
 End;
 RawParamCount:=PC-1; { -1 car on ne compte pas le nom du programme }
End;

Function RawParamStr(Index:Integer):String;
Var
 PC,StartPos:Integer;
 I:Integer;
 InQuote,InApos,InBrace:Boolean;
 CmdLine,Param:String;
Begin
 PC:=0;
 InQuote:=False;
 InApos:=False;
 InBrace:=False;
 CmdLine:=GetRawCommandLine;
 I:=1;
 While I<=Length(CmdLine)do Begin
  While(I<=Length(CmdLine))and(IsDelimiter(CmdLine[I]))do Inc(I);
  If I<=Length(CmdLine)Then Begin
   Inc(PC);
   If PC=Index+1 Then Begin
    StartPos:=I;
    While(I<=Length(CmdLine))do Begin
     Case CmdLine[I]of
      '"':If Not(InApos)and Not(InBrace)Then InQuote:=Not(InQuote);
      '''':If Not(InQuote)and Not(InBrace)Then InApos:=Not(InApos);
      '{':If Not(InQuote)and Not(InApos)Then InBrace:=True;
      '}':If Not(InQuote)and Not(InApos)Then InBrace:=False;
      ' ',#9,#13,#10:If Not(InQuote)and Not(InApos)and Not(InBrace)Then Break;
     End;
     Inc(I);
    End;
    RawParamStr:=Copy(CmdLine,StartPos,I-StartPos);
    Exit;
   End;
   While(I<=Length(CmdLine))do Begin
    Case CmdLine[I]of
     '"':If Not(InApos)and Not(InBrace)Then InQuote:=Not(InQuote);
     '''':If Not(InQuote)and Not(InBrace)Then InApos:=Not(InApos);
     '{':If Not(InQuote)and Not(InApos) Then InBrace:=True;
     '}':If Not(InQuote)and Not(InApos) Then InBrace:=False;
     ' ',#9,#13,#10:If Not(InQuote)and Not(InApos)and Not(InBrace)Then Break;
    End;
    Inc(I);
   End;
  End;
 End;
 RawParamStr:='';
End;


Function LTrim(S:String):String;
Var
 I:Integer;
Begin
 I:=1;
 While(I<=Length(s)) and (S[I] in [#9,' ']) do Inc(I);
 Delete(S,1,I-1);
 LTrim:=S;
End;

Function PadRight(S:String;Space:Byte):String;
Var
 I:Byte;
Begin
 If Length(S)<Space Then For I:=Length(S)+1 to Space do S:=S+' ';
 PadRight:=S;
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

 { Traitement des variables }
Function VariableExist(S:String):Boolean;
Var
 I:Integer;
Begin
 VariableExist:=False;
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  VariableExist:=True;
  Exit;
 End;
End;

Function VariableType(S:String):VarTypeEnum;
Var
 I:Integer;
Begin
 VariableType:=_None;
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  VariableType:=VarList[I]^.VarType;
  Exit;
 End;
End;

Function AddVariableInt(S:String;Value:Integer):Boolean;
Var
 P:VarPointer;
Begin
 If NumberVariable>=MaxVariable Then Begin
  AddVariableInt:=False;
  Exit;
 End;
 Inc(NumberVariable);
 GetMem(P,SizeOf(VarRec));
 P^.VarName:=Copy(StrToUpper(S),1,20);
 P^.VarType:=_Integer;
 P^.Variant.I:=Value;
 VarList[NumberVariable]:=P;
 AddVariableInt:=True;
End;

Function GetVariableInt(S:String):Integer;
Var
 I:Integer;
Begin
 GetVariableInt:=0;
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  GetVariableInt:=VarList[I]^.Variant.I;
  Exit;
 End;
End;

Procedure SetVariableInt(S:String;Value:Integer);
Var
 I:Integer;
Begin
 For I:=1 to NumberVariable do If(S=VarList[I]^.VarName)Then Begin
  VarList[I]^.Variant.I:=Value;
  Exit;
 End;
End;

Function AddVariableLongInt(S:String;Value:LongInt):Boolean;
Var
 P:VarPointer;
Begin
 If NumberVariable>=MaxVariable Then Begin
  AddVariableLongInt:=False;
  Exit;
 End;
 Inc(NumberVariable);
 GetMem(P,SizeOf(VarRec));
 P^.VarName:=Copy(StrToUpper(S),1,20);
 P^.VarType:=_LongInt;
 P^.Variant.L:=Value;
 VarList[NumberVariable]:=P;
 AddVariableLongInt:=True;
End;

Function GetVariableLongInt(S:String):LongInt;
Var
 I:Integer;
Begin
 GetVariableLongInt:=0;
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  GetVariableLongInt:=VarList[I]^.Variant.L;
  Exit;
 End;
End;

Procedure SetVariableLongInt(S:String;Value:LongInt);
Var
 I:Integer;
Begin
 For I:=1 to NumberVariable do If(S=VarList[I]^.VarName)Then Begin
  VarList[I]^.Variant.L:=Value;
  Exit;
 End;
End;

Function AddVariableReal(S:String;Value:Real):Boolean;
Var
 P:VarPointer;
Begin
 If NumberVariable>=MaxVariable Then Begin
  AddVariableReal:=False;
  Exit;
 End;
 Inc(NumberVariable);
 GetMem(P,SizeOf(VarRec));
 P^.VarName:=Copy(StrToUpper(S),1,20);
 P^.VarType:=_Real;
 P^.Variant.R:=Value;
 VarList[NumberVariable]:=P;
 AddVariableReal:=True;
End;

Function GetVariableReal(S:String):Real;
Var
 I:Integer;
Begin
 GetVariableReal:=0;
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  GetVariableReal:=VarList[I]^.Variant.R;
  Exit;
 End;
End;

Procedure SetVariableReal(S:String;Value:Real);
Var
 I:Integer;
Begin
 For I:=1 to NumberVariable do If(S=VarList[I]^.VarName)Then Begin
  VarList[I]^.Variant.R:=Value;
  Exit;
 End;
End;

Function AddVariableString(S:String;Value:String):Boolean;
Var
 P:VarPointer;
 PS:StrPointer;
Begin
 If NumberVariable>=MaxVariable Then Begin
  AddVariableString:=False;
  Exit;
 End;
 Inc(NumberVariable);
 GetMem(P,SizeOf(VarRec));
 P^.VarName:=Copy(StrToUpper(S),1,20);
 P^.VarType:=_String;
 GetMem(PS,SizeOf(String));
 PS^:=Value;
 P^.Variant.S:=PS;
 VarList[NumberVariable]:=P;
 AddVariableString:=True;
End;

Function GetVariableString(S:String):String;
Var
 I:Integer;
Begin
 GetVariableString:='';
 For I:=1 to NumberVariable do If(StrToUpper(S)=VarList[I]^.VarName)Then Begin
  GetVariableString:=VarList[I]^.Variant.S^;
  Exit;
 End;
End;

Procedure SetVariableString(S:String;Value:String);
Var
 I:Integer;
Begin
 For I:=1 to NumberVariable do If(S=VarList[I]^.VarName)Then Begin
  VarList[I]^.Variant.S^:=Value;
  Exit;
 End;
End;

 { Traitement de la liste }
Function AddLine(S:String):Boolean;
Var
 P:StrPointer;
Begin
 If NumberLine>=MaxLine Then Begin
  AddLine:=False;
  Exit;
 End;
 Inc(NumberLine);
 GetMem(P,Length(S)+1);
 P^:=S;
 PA[NumberLine]:=P;
 AddLine:=True;
End;

{ === Fonctions pour les tableaux associatifs === }

Function FindArray(ArrayName:String):Integer;
Var
 J:Integer;
 UpperName:String;
Begin
 FindArray:=0;
 UpperName:=StrToUpper(ArrayName);
 For J:=1 to AssocArrayCount do Begin
  If StrToUpper(AssocArrays[J].Name)=UpperName Then Begin
   FindArray:=J;
   Exit;
  End;
 End;
End;

Function CreateArray(ArrayName:String):Integer;
Begin
 If AssocArrayCount>=MaxArrays Then Begin
  WriteLn('Trop de tableaux');
  CreateArray:=0;
  Exit;
 End;
 Inc(AssocArrayCount);
 AssocArrays[AssocArrayCount].Name:=ArrayName;
 AssocArrays[AssocArrayCount].Count:=0;
 CreateArray:=AssocArrayCount;
End;

Function FindArrayElement(ArrayIdx:Integer;Key:String):Integer;
Var
 J:Integer;
Begin
 FindArrayElement:=0;
 If(ArrayIdx<1)or(ArrayIdx>AssocArrayCount)Then Exit;
 For J:=1 to AssocArrays[ArrayIdx].Count do Begin
  If AssocArrays[ArrayIdx].Elements[J].Key=Key Then Begin
   FindArrayElement:=J;
   Exit;
  End;
 End;
End;

Procedure SetArrayElement(ArrayName,Key,Value:String);
Var
 ArrayIdx,ElemIdx:Integer;
Begin
 ArrayIdx:=FindArray(ArrayName);
 If ArrayIdx=0 Then ArrayIdx:=CreateArray(ArrayName);
 If ArrayIdx=0 Then Exit;
 
 ElemIdx:=FindArrayElement(ArrayIdx,Key);
 If ElemIdx>0 Then Begin
  AssocArrays[ArrayIdx].Elements[ElemIdx].Value:=Value;
 End
  Else
 Begin
  If AssocArrays[ArrayIdx].Count>=MaxArrayElements Then Begin
   WriteLn('Trop d''elements dans le tableau');
   Exit;
  End;
  Inc(AssocArrays[ArrayIdx].Count);
  ElemIdx:=AssocArrays[ArrayIdx].Count;
  AssocArrays[ArrayIdx].Elements[ElemIdx].Key:=Key;
  AssocArrays[ArrayIdx].Elements[ElemIdx].Value:=Value;
 End;
End;

Function GetArrayElement(ArrayName,Key:String):String;
Var
 ArrayIdx,ElemIdx:Integer;
Begin
 GetArrayElement:='';
 ArrayIdx:=FindArray(ArrayName);
 If ArrayIdx=0 Then Exit;
 
 ElemIdx:=FindArrayElement(ArrayIdx,Key);
 If ElemIdx>0 Then
  GetArrayElement:=AssocArrays[ArrayIdx].Elements[ElemIdx].Value;
End;

Function KeyInArray(ArrayName,Key:String):Boolean;
Var
 ArrayIdx,ElemIdx:Integer;
Begin
 KeyInArray:=False;
 ArrayIdx:=FindArray(ArrayName);
 If ArrayIdx=0 Then Exit;
 
 ElemIdx:=FindArrayElement(ArrayIdx,Key);
 KeyInArray:=(ElemIdx>0);
End;

Procedure DeleteArrayElement(ArrayName,Key:String);
Var
 ArrayIdx,ElemIdx,J:Integer;
Begin
 ArrayIdx:=FindArray(ArrayName);
 If ArrayIdx=0 Then Exit;
 
 ElemIdx:=FindArrayElement(ArrayIdx,Key);
 If ElemIdx>0 Then Begin
  { Decaler les elements }
  For J:=ElemIdx to AssocArrays[ArrayIdx].Count-1 do Begin
   AssocArrays[ArrayIdx].Elements[J]:=AssocArrays[ArrayIdx].Elements[J+1];
  End;
  Dec(AssocArrays[ArrayIdx].Count);
 End;
End;

Function ExtractCommand:Byte;
Var
 I:Byte;
Begin
 ExtractCommand:=255;
 CurrCommand:='';
 For I:=CurrPos to Length(CurrLine)do Begin
  If Not(CurrLine[I]in['A'..'Z','a'..'z','$'])Then Begin
   CurrCommand:=Copy(CurrLine,CurrPos,I-CurrPos);
   CurrPos:=I;
   Break;
  End;
 End;
 If CurrCommand=''Then Begin
  CurrCommand:=Copy(CurrLine,CurrPos,255);
  CurrPos:=Length(CurrLine)+1;
 End;
 For I:=Low(TokenList)to High(TokenList)do Begin
  If CurrCommand=TokenList[I]Then Begin
   ExtractCommand:=I;
   Exit;
  End;
 End;
End;

 { Evaluation d'expression (Infix to PostFix ) }
Var
 Stack:Array[0..100]of Char;
 TopOfStack:Byte;
 resultStack:Array[0..100]of Real;
 TopOfStackInt:Byte;

Procedure StackPushChar(C:Char);Begin
 If TopOfStack>=High(Stack)Then Begin
  WriteLn('Pile pleine!');
  Halt;
 End
  Else
 Begin
  Stack[TopOfStack]:=C;
  Inc(TopOfStack);
 End;
End;

Function StackPop:String;
Var
 S:String;
 Err:Word;
Begin
 Dec(TopOfStack);
 If TopOfStack<1Then Begin
  TopOfStack:=1;
  StackPop:='';
 End
  Else
 StackPop:=Stack[TopOfStack];
End;

Function StackPeek:Char;Begin
 StackPeek:=Stack[TopOfStack-1];
End;

Procedure ResultStackPush(C:Real);Begin
 If TopOfStackInt>=High(ResultStack)Then Begin
  WriteLn('Pile pleine!');
  Halt;
 End
  Else
 Begin
  ResultStack[TopOfStackInt]:=C;
  Inc(TopOfStackInt);
 End;
End;

Function ResultStackPop:Real;Begin
 Dec(TopOfStackInt);
 If TopOfStackInt<1Then Begin
  TopOfStackInt:=1;
  ResultStackPop:=0;
 End
  Else
 ResultStackPop:=ResultStack[TopOfStackInt];
End;

Function GetStringValue:String;
Var
 S:String;
Begin
 GetStringValue:='';
 S:='';
 If CurrLine[CurrPos]='"'Then Begin
  Inc(CurrPos);
  While(CurrLine[CurrPos]<>'"')and(CurrPos<=Length(CurrLine))do Begin
   S:=S+CurrLine[CurrPos];
   Inc(CurrPos);
  End;
  If CurrLine[CurrPos]='"'Then Inc(CurrPos);
  GetStringValue:=S;
 End;
End;

Function GetNumberValue(MinTopOfStack:Integer):Real;
Var
 I,J:Byte;
 Top,P_2:Char;
 AppendOk,FunctionFound:Boolean;
 _Result,P,P2:Real;
 Err:Word;
 PostFix:String;
 VarName,Value:String;
 Exposant:Boolean;
 StopChar:Set Of Char;
 Infix:String;
 FuncIdx,ParamIdx:Integer;
 ParamVarName:String;
 ArgValue:Real;
 SavedParams:Array[1..MaxFunctionParams]of Real;
 SavedParamCount:Integer;
Begin
 StopChar:=[',',':',';','"','<','=','>','!'];
 TopOfStack:=1;
 TopOfStackInt:=1;
 PostFix:='';
 Infix:=CurrLine;
 I:=CurrPos;
 If Infix[CurrPos]='-'Then Begin
  Insert('(0)',Infix,CurrPos);
  Dec(CurrPos,3);
 End;
 Repeat
  If(I<=Length(Infix))and(Infix[I]in['A'..'Z','a'..'z','_'])Then Begin
   VarName:=Infix[I];
   Inc(I);
   While(I<=Length(Infix))and(Infix[I]in['A'..'Z','a'..'z','_','0'..'9','%','!','#'])do Begin
    VarName:=VarName+Infix[I];
    Inc(I);
   End;
   VarName:=StrToUpper(VarName);
   If VariableExist(VarName)Then Begin
    Case VariableType(VarName)of
     _Integer:Str(GetVariableInt(VarName),Value);
     _LongInt:Str(GetVariableLongInt(VarName),Value);
     _Real:Str(GetVariableReal(VarName):0:6,Value);
     Else Begin
      WriteLn('Type incompatiable');
      Exit;
     End;
    End;
   End
    Else
   Begin { Fonction ?}
    FunctionFound:=False;
    For J:=Low(FunctionList)to High(FunctionList)do Begin
     If FunctionList[J]=VarName Then Begin
      FunctionFound:=True;
      Case J of
       1:Begin{COS}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        Str(Cos(_Result),Value);
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       2:Begin{EXP}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        Str(Exp(_Result),Value);
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       7:Begin{LOG}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        Str(Ln(_Result),Value);
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       5:Begin{INT}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        Str(Trunc(_Result):0,Value);
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       10:Begin{SIN}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        Str(Sin(_Result),Value);
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       13:Begin{SQRT}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        CurrPos:=I;
        _Result:=GetNumberValue(TopOfStack);
        If _Result>=0 Then Str(Sqrt(_Result),Value)
                      Else Value:='0';
        I:=CurrPos;
        If Infix[I]<>')'Then Begin
         WriteLn('")" attendu');
         Exit;
        End;
        Inc(I);
       End;
       6:Begin{LENGTH}
        If Infix[I]<>'('Then Begin
         WriteLn('"(" attendu');
         Exit;
        End;
        Inc(I);
        { Lire argument - chaine ou variable }
        If Infix[I]='"'Then Begin
         Inc(I);
         Value:='';
         While(I<=Length(Infix))and(Infix[I]<>'"')do Begin
          Value:=Value+Infix[I];
          Inc(I);
         End;
         If I<=Length(Infix)Then Inc(I); { passer le " }
         Str(System.Length(Value),Value);
        End
         Else
        Begin
         { Variable ou $0 }
         VarName:='';
         While(I<=Length(Infix))and(Infix[I]in['A'..'Z','a'..'z','0'..'9','_','$'])do Begin
          VarName:=VarName+Infix[I];
          Inc(I);
         End;
         VarName:=StrToUpper(VarName);
         If VariableExist(VarName)Then Begin
          If VariableType(VarName)=_String Then
           Str(System.Length(GetVariableString(VarName)),Value)
          Else
           Value:='0';
         End
          Else
         Str(System.Length(Fields[0]),Value); { $0 par defaut }
        End;
        If(I<=Length(Infix))and(Infix[I]=')')Then Inc(I);
       End;
      End;
      Break;
     End
      Else
     Begin { Variable vide }
      Value:='0';
     End;
    End;
    { Si pas une fonction builtin, verifier les fonctions utilisateur }
    If Not FunctionFound Then Begin
     FuncIdx:=FindUserFunction(VarName);
     If(FuncIdx>0)and(I<=Length(Infix))and(Infix[I]='(')Then Begin
      FunctionFound:=True;
      Inc(I);
      { Sauvegarder les anciennes valeurs des parametres }
      For ParamIdx:=1 to UserFuncs[FuncIdx].ParamCount do Begin
       ParamVarName:=UserFuncs[FuncIdx].ParamNames[ParamIdx];
       If VariableExist(ParamVarName)Then
        SavedParams[ParamIdx]:=GetVariableReal(ParamVarName)
       Else
        SavedParams[ParamIdx]:=0;
      End;
      SavedParamCount:=UserFuncs[FuncIdx].ParamCount;
      { Lire les arguments et les assigner aux parametres }
      ParamIdx:=0;
      While(I<=Length(Infix))and(Infix[I]<>')')do Begin
       { Sauter les espaces }
       While(I<=Length(Infix))and(Infix[I]=' ')do Inc(I);
       If Infix[I]=')'Then Break;
       Inc(ParamIdx);
       { Lire l'argument (nombre ou variable) }
       CurrPos:=I;
       ArgValue:=GetNumberValue(TopOfStack);
       I:=CurrPos;
       { Assigner a la variable de parametre }
       If ParamIdx<=UserFuncs[FuncIdx].ParamCount Then Begin
        ParamVarName:=UserFuncs[FuncIdx].ParamNames[ParamIdx];
        If Frac(ArgValue)=0.0 Then Begin
         If VariableExist(ParamVarName)Then SetVariableLongInt(ParamVarName,Round(ArgValue))
                                       Else AddVariableLongInt(ParamVarName,Round(ArgValue));
        End
         Else
        Begin
         If VariableExist(ParamVarName)Then SetVariableReal(ParamVarName,ArgValue)
                                       Else AddVariableReal(ParamVarName,ArgValue);
        End;
       End;
       { Sauter la virgule }
       While(I<=Length(Infix))and(Infix[I]in[' ',','])do Inc(I);
      End;
      If(I<=Length(Infix))and(Infix[I]=')')Then Inc(I);
      { Appeler la fonction }
      _Result:=CallUserFunction(FuncIdx);
      Str(_Result,Value);
      { Restaurer les anciennes valeurs des parametres }
      For ParamIdx:=1 to SavedParamCount do Begin
       ParamVarName:=UserFuncs[FuncIdx].ParamNames[ParamIdx];
       If VariableExist(ParamVarName)Then Begin
        If Frac(SavedParams[ParamIdx])=0.0 Then SetVariableLongInt(ParamVarName,Round(SavedParams[ParamIdx]))
                                           Else SetVariableReal(ParamVarName,SavedParams[ParamIdx]);
       End;
      End;
     End;
    End;
   End;
   PostFix:=PostFix+'('+LTrim(Value)+')';
   If I>Length(Infix)Then Break;
  End
   Else
  If Infix[I]in['0'..'9']Then Begin
   Value:='';
   Exposant:=False;
   Repeat
    If Infix[I]in['E','e']Then Begin
     Exposant:=True;
     Value:=Value+Infix[I];
     Inc(I);
    End
     Else
    If(Exposant)and(Infix[I]in['-','+'])Then Begin
     Value:=Value+Infix[I];
     Inc(I);
    End
     Else
    If Infix[I]in['0'..'9','.']Then Begin
     Value:=Value+Infix[I];
     Inc(I);
    End
     Else
    Break;
   Until I>Length(Infix);
   PostFix:=PostFix+'('+Value+')';
  End
  Else If Infix[I]='('Then Begin
   StackPushChar(Infix[I]);
   Inc(I);
  End
  Else If Infix[I]in['*','+','-','/','%','^']Then Begin
   While(TopOfStack>1)and(StackPeek <> '(')do Begin
    Top:=StackPeek;
    P_2:=Infix[I];
    AppendOk:=True;
    If(Top='+')and(P_2='*')Then AppendOk:=False
    Else If(Top='*')and(P_2='-')Then AppendOk:=True
    Else If(Top='+')and(P_2='-')Then AppendOk:=True
    Else If(Top in['+','-'])and(P_2='^')Then AppendOk:=False
    Else If(Top in['*','/','%'])and(P_2='^')Then AppendOk:=False;
    If(AppendOk)Then PostFix:=PostFix+StackPop
                Else Break;
   End;
   StackPushChar(Infix[I]);
   Inc(I);
  End
   Else
  If Infix[I]=')'Then Begin
   If TopOfStack<=MinTopOfStack Then Begin
    Break;
   End;
   While(TopOfStack>MinTopOfStack)and(StackPeek<>'(')do PostFix:=PostFix+StackPop;
   If TopOfStack>1Then StackPop;
   Inc(I);
  End
   Else
  Inc(I);
  If(Infix[I]in StopChar)Then Break;
  If StrToUpper(Copy(Infix,I,4))='THEN'Then Break;
 Until I>Length(Infix);
 CurrPos:=I;
 While(TopOfStack>1)do PostFix:=PostFix+StackPop;
  { Transformation en POSTFIX }
 I:=1;
 Repeat
  If PostFix[I]in['*','+','-','/','%','^']Then Begin
   P:=ResultStackPop;
   P2:=ResultStackPop;
   Case PostFix[I]of
    '+':_Result:=P2+P;
    '-':_Result:=P2-P;
    '*':_Result:=P2*P;
    '/':If P<>0 Then _Result:=P2/P Else _Result:=0;
    '%':If P<>0 Then _Result:=Trunc(P2) mod Trunc(P) Else _Result:=0;
    '^':If P2>0 Then _Result:=Exp(P*Ln(P2)) Else If P2=0 Then _Result:=0 Else _Result:=-Exp(P*Ln(-P2));
    Else _Result:=-1;
   End;
   ResultStackPush(_Result);
  End
   Else
  Begin
   Value:='';
   Exposant:=False;
   Repeat
    If Postfix[I]in['0'..'9','.']Then Begin
     Value:=Value+Postfix[I];
     Inc(I);
    End
     Else
    If(Value<>'')and(Postfix[I]in['E','e'])Then Begin
     Exposant:=True;
     Value:=Value+Postfix[I];
     Inc(I);
    End
     Else
    If(Value<>'')and(Exposant)and(Postfix[I]in['+','-'])Then Begin
     Value:=Value+Postfix[I];
     Inc(I);
    End
     Else
    Break;
   Until I>Length(Postfix);
   If Value<>''Then Begin
    Val(Value,_Result,Err);
    ResultStackPush(_Result);
   End;
  End;
  Inc(I);
 Until I>Length(Postfix);
 GetNumberValue:=ResultStackPop;
End;

Procedure SkipSpace;Begin
 While(CurrLine[CurrPos]in[' '])and(CurrPos<Length(CurrLine))do Inc(CurrPos);
End;

Function GetSeparator:Char;Begin
 If CurrPos>Length(CurrLine)Then Begin
  GetSeparator:=#0;
  Exit;
 End;
 SkipSpace;
 GetSeparator:=CurrLine[CurrPos];
End;


Procedure BeginCommand;Begin
End;

{ Implementation de la commande END }
Procedure EndCommand;
Var
 BlockLevel:Integer;
 SaveLinePtr:Integer;
Begin
 { END est execute a la fin du programme, on sauvegarde la position }
 EndBlockStart:=CurrLinePtr;
 
 { Sauter le bloc END pour l'instant - il sera execute a la fin }
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
  BlockLevel:=1;
  Inc(CurrPos);
  While BlockLevel>0 do Begin
   While CurrPos<=Length(CurrLine)do Begin
    If CurrLine[CurrPos]='{' Then Inc(BlockLevel)
    Else If CurrLine[CurrPos]='}' Then Dec(BlockLevel);
    If BlockLevel=0 Then Break;
    Inc(CurrPos);
   End;
   If BlockLevel>0 Then Begin
    { Passer a la ligne suivante }
    Inc(CurrLinePtr);
    If CurrLinePtr>NumberLine Then Break;
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
   End;
  End;
 End;
 EndBlockEnd:=CurrLinePtr;
End;

{ Implementation de getline - lit une ligne depuis l'entree standard }
{ Formes supportees:                                                  }
{   getline             -> lit dans $0, retourne 1 si ok, 0 si EOF   }
{   getline var         -> lit dans var, retourne 1 si ok, 0 si EOF  }
{   getline < "fichier" -> lit depuis un fichier                     }
Procedure GetlineCommand;
Var
 InputLine:String;
 VarName:String;
 SavePos:Integer;
 NRVal:LongInt;
Begin
 SkipSpace;
 SavePos:=CurrPos;
 
 { Verifier si c'est "getline var" ou juste "getline" }
 VarName:='';
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
  VarName:=VarName+CurrLine[CurrPos];
  Inc(CurrPos);
 End;
 SkipSpace;
 
 { Lire depuis l'entree standard }
 If Not EOF Then Begin
  ReadLn(InputLine);
  
  If VarName<>''Then Begin
   { getline var - stocker dans la variable }
   SetVariableString(StrToUpper(VarName),InputLine);
  End
   Else
  Begin
   { getline - stocker dans $0 et mettre a jour les champs }
   Fields[0]:=InputLine;
   SplitIntoFields(InputLine);
  End;
  
  { Mettre a jour NR }
  NRVal:=GetVariableLongInt('NR');
  Inc(NRVal);
  SetVariableLongInt('NR',NRVal);
  
  { Retourner 1 (succes) via variable speciale GETLINE_STATUS }
  SetVariableInt('_GETLINE_STATUS',1);
 End
  Else
 Begin
  { EOF atteint - retourner 0 }
  SetVariableInt('_GETLINE_STATUS',0);
 End;
End;

{ Recherche une fonction utilisateur par son nom }
Function FindUserFunction(const FName:String):Integer;
Var
 J:Integer;
 UpperName:String;
Begin
 FindUserFunction:=0;
 UpperName:=FName;
 For J:=1 to Length(UpperName)do
  If UpperName[J] in ['a'..'z'] Then
   UpperName[J]:=Chr(Ord(UpperName[J])-32);
 For J:=1 to UserFuncCount do Begin
  If UserFuncs[J].FuncName=UpperName Then Begin
   FindUserFunction:=J;
   Exit;
  End;
 End;
End;

{ Parse une definition de fonction: function name(params) ... }
Procedure ParseFunctionDef;
Var
 FuncName,ParamName:String;
 BlockLevel:Integer;
 FuncIdx:Integer;
Begin
 SkipSpace;
 { Lire le nom de la fonction }
 FuncName:='';
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
  FuncName:=FuncName+CurrLine[CurrPos];
  Inc(CurrPos);
 End;
 
 If FuncName='' Then Exit;
 
 { Convertir en majuscules }
 FuncName:=StrToUpper(FuncName);
 
 { Incrementer le compteur de fonctions }
 Inc(UserFuncCount);
 FuncIdx:=UserFuncCount;
 UserFuncs[FuncIdx].FuncName:=FuncName;
 UserFuncs[FuncIdx].ParamCount:=0;
 
 { Sauter les espaces }
 SkipSpace;
 
 { Parser les parametres }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='(')Then Begin
  Inc(CurrPos); { Passer '(' }
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>')')do Begin
   SkipSpace;
   ParamName:='';
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
    ParamName:=ParamName+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   If ParamName<>'' Then Begin
    Inc(UserFuncs[FuncIdx].ParamCount);
    UserFuncs[FuncIdx].ParamNames[UserFuncs[FuncIdx].ParamCount]:=StrToUpper(ParamName);
   End;
   SkipSpace;
   If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=',')Then Inc(CurrPos);
  End;
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
 End;
 
 { Sauter les espaces et chercher '{' }
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
  { Enregistrer le debut du corps de la fonction }
  UserFuncs[FuncIdx].BodyStartLine:=CurrLinePtr;
  UserFuncs[FuncIdx].BodyStartPos:=CurrPos+1;
  
  { Sauter le bloc de la fonction }
  BlockLevel:=1;
  Inc(CurrPos);
  While BlockLevel>0 do Begin
   While CurrPos<=Length(CurrLine)do Begin
    If CurrLine[CurrPos]='{' Then Inc(BlockLevel)
    Else If CurrLine[CurrPos]='}' Then Dec(BlockLevel);
    If BlockLevel=0 Then Break;
    Inc(CurrPos);
   End;
   If BlockLevel>0 Then Begin
    Inc(CurrLinePtr);
    If CurrLinePtr>NumberLine Then Break;
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
   End;
  End;
  UserFuncs[FuncIdx].BodyEndLine:=CurrLinePtr;
  { Avancer apres l'accolade fermante }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='}')Then Inc(CurrPos);
 End;
End;

{ Commande function - parse et enregistre une fonction utilisateur }
Procedure FunctionCommand;
Begin
 ParseFunctionDef;
End;

{ Commande return - retourne une valeur depuis une fonction }
Procedure ReturnCommand;
Var
 R:Real;
Begin
 SkipSpace;
 HasFunctionReturn:=True;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
  { Retour de chaine }
  FunctionReturnStr:=GetStringValue;
  FunctionReturnValue:=0;
 End
  Else
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['0'..'9','-','+','(','A'..'Z','a'..'z','_','$'])Then Begin
  { Retour numerique }
  R:=GetNumberValue(1);
  FunctionReturnValue:=R;
  FunctionReturnStr:='';
 End
  Else
 Begin
  { Retour vide }
  FunctionReturnValue:=0;
  FunctionReturnStr:='';
 End;
End;

{ Appel d'une fonction utilisateur }
Function CallUserFunction(FuncIdx:Integer):Real;
Var
 SaveLinePtr:Integer;
 SaveCurrLine:String;
 SavePos:Integer;
 OldReturnValue:Real;
 OldReturnStr:String;
 OldHasReturn:Boolean;
Begin
 CallUserFunction:=0;
 If(FuncIdx<1)or(FuncIdx>UserFuncCount)Then Exit;
 
 { Sauvegarder l'etat courant }
 SaveLinePtr:=CurrLinePtr;
 SaveCurrLine:=CurrLine;
 SavePos:=CurrPos;
 OldReturnValue:=FunctionReturnValue;
 OldReturnStr:=FunctionReturnStr;
 OldHasReturn:=HasFunctionReturn;
 
 { Initialiser pour l'appel }
 HasFunctionReturn:=False;
 FunctionReturnValue:=0;
 FunctionReturnStr:='';
 InFunctionCall:=True;
 
 { Executer le corps de la fonction }
 CurrLinePtr:=UserFuncs[FuncIdx].BodyStartLine;
 CurrLine:=PA[CurrLinePtr]^;
 CurrPos:=UserFuncs[FuncIdx].BodyStartPos;
 
 While(CurrLinePtr<=UserFuncs[FuncIdx].BodyEndLine)and(Not HasFunctionReturn)do Begin
  If Not RunLine Then Break;
  Inc(CurrLinePtr);
  If CurrLinePtr<=UserFuncs[FuncIdx].BodyEndLine Then Begin
   CurrLine:=PA[CurrLinePtr]^;
   CurrPos:=1;
  End;
 End;
 
 { Recuperer la valeur de retour }
 CallUserFunction:=FunctionReturnValue;
 
 { Restaurer l'etat }
 CurrLinePtr:=SaveLinePtr;
 CurrLine:=SaveCurrLine;
 CurrPos:=SavePos;
 FunctionReturnValue:=OldReturnValue;
 FunctionReturnStr:=OldReturnStr;
 HasFunctionReturn:=OldHasReturn;
 InFunctionCall:=False;
End;

Procedure PrintCommand;
Var
 R:Real;
 VarName,StrVal,OutputStr,TempStr:String;
 SavePos:Integer;
 HasOutput:Boolean;
Begin
 SkipSpace;
 OutputStr:='';
 HasOutput:=False;
 
 If CurrPos>Length(CurrLine)Then Begin
  { print sans argument - affiche $0 }
  WriteLn(Fields[0]);
  Exit;
 End;
 
 { Boucle pour gerer la concatenation de chaines et variables }
 While(CurrPos<=Length(CurrLine))and(Not(CurrLine[CurrPos]in[';','}','#']))do Begin
  SkipSpace;
  If CurrPos>Length(CurrLine)Then Break;
  If CurrLine[CurrPos]in[';','}','#']Then Break;
  
  { Chaine literale }
  If CurrLine[CurrPos]='"'Then Begin
   TempStr:=GetStringValue;
   OutputStr:=OutputStr+TempStr;
   HasOutput:=True;
  End
   Else
  { Variable ou expression }
  If CurrLine[CurrPos]in['A'..'Z','a'..'z','_']Then Begin
   SavePos:=CurrPos;
   VarName:='';
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
    VarName:=VarName+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   { Verifier si c'est un acces tableau }
   If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='[')Then Begin
    { Acces tableau }
    Inc(CurrPos);
    TempStr:='';
    If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
     TempStr:=GetStringValue;
    End
     Else
    Begin
     While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
      TempStr:=TempStr+CurrLine[CurrPos];
      Inc(CurrPos);
     End;
     { Si c'est une variable, recuperer sa valeur }
     If VariableExist(StrToUpper(TempStr))Then Begin
      Case VariableType(StrToUpper(TempStr))of
       _String:TempStr:=GetVariableString(StrToUpper(TempStr));
       _Integer:Str(GetVariableInt(StrToUpper(TempStr)),TempStr);
       _LongInt:Str(GetVariableLongInt(StrToUpper(TempStr)),TempStr);
       _Real:Str(GetVariableReal(StrToUpper(TempStr)):0:0,TempStr);
      End;
     End;
    End;
    If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=']')Then Inc(CurrPos);
    OutputStr:=OutputStr+GetArrayElement(VarName,TempStr);
    HasOutput:=True;
   End
    Else
   Begin
    VarName:=StrToUpper(VarName);
    If VariableExist(VarName)Then Begin
     Case VariableType(VarName)of
      _String:OutputStr:=OutputStr+GetVariableString(VarName);
      _Integer:Begin
       Str(GetVariableInt(VarName),TempStr);
       OutputStr:=OutputStr+TempStr;
      End;
      _LongInt:Begin
       Str(GetVariableLongInt(VarName),TempStr);
       OutputStr:=OutputStr+TempStr;
      End;
      _Real:Begin
       R:=GetVariableReal(VarName);
       If Frac(R)=0.0Then Str(R:0:0,TempStr)
                     Else Str(R,TempStr);
       OutputStr:=OutputStr+TempStr;
      End;
     End;
     HasOutput:=True;
    End
     Else
    Begin
     { Pas une variable connue, restaurer et traiter comme expression }
     CurrPos:=SavePos;
     R:=GetNumberValue(1);
     If Frac(R)=0.0Then Str(R:0:0,TempStr)
                   Else Str(R,TempStr);
     OutputStr:=OutputStr+TempStr;
     HasOutput:=True;
    End;
   End;
  End
   Else
  If CurrLine[CurrPos]in['0'..'9','-','+','(']Then Begin
   { Expression numerique }
   R:=GetNumberValue(1);
   If Frac(R)=0.0Then Str(R:0:0,TempStr)
                 Else Str(R,TempStr);
   OutputStr:=OutputStr+TempStr;
   HasOutput:=True;
  End
   Else
  If CurrLine[CurrPos]=','Then Begin
   { Separateur d'arguments - ajouter un espace (OFS) }
   OutputStr:=OutputStr+' ';
   Inc(CurrPos);
  End
   Else
  Begin
   { Caractere inconnu - arreter }
   Break;
  End;
  
  SkipSpace;
 End;
 
 If HasOutput Then WriteLn(OutputStr)
              Else WriteLn;
End;

Procedure CosCommand;
Begin
 If GetSeparator<>'"'Then Begin
  WriteLn(Cos(GetNumberValue(1)));
 End
  Else
 Begin
  WriteLn('Erreur de syntaxe : cos attend une valeur numerique');
  Halt;
 End;
End;

{ Fonction sqrt - racine carree }
Procedure SqrtCommand;
Var
 R:Real;
Begin
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='(')Then Inc(CurrPos);
 R:=GetNumberValue(1);
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
 If R>=0 Then Begin
  R:=Sqrt(R);
  If Frac(R)=0.0 Then WriteLn(R:0:0)
                 Else WriteLn(R);
 End
  Else
 WriteLn('Erreur: sqrt d''un nombre negatif');
End;

{ Commande printf - affichage formate }
Procedure PrintfCommand;
Var
 FormatStr,OutputStr,TempStr:String;
 I:Integer;
 R:Real;
 InFormat:Boolean;
 Width,Precision:Integer;
 WidthStr,PrecStr:String;
Begin
 SkipSpace;
 OutputStr:='';
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
  FormatStr:=GetStringValue;
  I:=1;
  While I<=Length(FormatStr) do Begin
   If(FormatStr[I]='%')and(I<Length(FormatStr))Then Begin
    Inc(I);
    { Gerer %% comme un seul % }
    If FormatStr[I]='%'Then Begin
     OutputStr:=OutputStr+'%';
     Inc(I);
    End
     Else
    Begin
     { Lire la largeur optionnelle }
     WidthStr:='';
     While(I<=Length(FormatStr))and(FormatStr[I]in['0'..'9','-'])do Begin
      WidthStr:=WidthStr+FormatStr[I];
      Inc(I);
     End;
     { Lire la precision optionnelle }
     PrecStr:='';
     If(I<=Length(FormatStr))and(FormatStr[I]='.')Then Begin
      Inc(I);
      While(I<=Length(FormatStr))and(FormatStr[I]in['0'..'9'])do Begin
       PrecStr:=PrecStr+FormatStr[I];
       Inc(I);
      End;
     End;
     { Traiter le specifier de format }
     If I<=Length(FormatStr)Then Begin
      SkipSpace;
      If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=',')Then Inc(CurrPos);
      SkipSpace;
      Case FormatStr[I] of
       'd','i':Begin { Entier }
        R:=GetNumberValue(1);
        Str(Round(R),TempStr);
        OutputStr:=OutputStr+TempStr;
       End;
       's':Begin { Chaine }
        If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then
         TempStr:=GetStringValue
        Else Begin
         TempStr:='';
         While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
          TempStr:=TempStr+CurrLine[CurrPos];
          Inc(CurrPos);
         End;
         If VariableExist(StrToUpper(TempStr))Then
          TempStr:=GetVariableString(StrToUpper(TempStr));
        End;
        OutputStr:=OutputStr+TempStr;
       End;
       'f','g','e':Begin { Reel }
        R:=GetNumberValue(1);
        If PrecStr<>''Then Begin
         Str(R:0:2,TempStr);
        End
         Else
        Str(R,TempStr);
        OutputStr:=OutputStr+TempStr;
       End;
       'c':Begin { Caractere }
        R:=GetNumberValue(1);
        OutputStr:=OutputStr+Chr(Round(R));
       End;
      End;
      Inc(I);
     End;
    End;
   End
    Else
   If(FormatStr[I]='\')and(I<Length(FormatStr))Then Begin
    Inc(I);
    Case FormatStr[I] of
     'n':OutputStr:=OutputStr+#13#10;
     't':OutputStr:=OutputStr+#9;
     '\':OutputStr:=OutputStr+'\';
     '"':OutputStr:=OutputStr+'"';
    End;
    Inc(I);
   End
    Else
   Begin
    OutputStr:=OutputStr+FormatStr[I];
    Inc(I);
   End;
  End;
  Write(OutputStr);
 End;
End;

{ Evaluation des conditions pour if et switch }
Function EvaluateCondition:Boolean;
Var
 LeftStr,RightStr:String;
 LeftNum,RightNum:Real;
 Op:String;
 I,SavePos:Integer;
 IsStringCompare:Boolean;
 Err:Integer;
 KeyStr,ArrayName:String;
 ScanPos:Integer;
Begin
 EvaluateCondition:=False;
 SkipSpace;

 { Verifie si c'est une parenthese ouvrante }
 If CurrLine[CurrPos]='('Then Inc(CurrPos);
 SkipSpace;

 { Detecter l'operateur "in" pour les tableaux }
 { Format: "key" in array ou (key in array) }
 SavePos:=CurrPos;
 KeyStr:='';
 ArrayName:='';
 
 { Lire la cle (string ou variable) }
 If CurrLine[CurrPos]='"'Then Begin
  KeyStr:=GetStringValue;
 End
  Else
 Begin
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
   KeyStr:=KeyStr+CurrLine[CurrPos];
   Inc(CurrPos);
  End;
  { Si c'est une variable, recuperer sa valeur }
  If VariableExist(KeyStr)Then Begin
   Case VariableType(KeyStr)of
    _String:KeyStr:=GetVariableString(KeyStr);
    _Integer:Str(GetVariableInt(KeyStr),KeyStr);
    _LongInt:Str(GetVariableLongInt(KeyStr),KeyStr);
    _Real:Str(GetVariableReal(KeyStr):0:0,KeyStr);
   End;
  End;
 End;
 
 SkipSpace;
 
 { Verifier si "in" suit }
 If(CurrPos+1<=Length(CurrLine))and(Copy(CurrLine,CurrPos,3)='in ')Then Begin
  Inc(CurrPos,2);
  SkipSpace;
  { Lire le nom du tableau }
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
   ArrayName:=ArrayName+CurrLine[CurrPos];
   Inc(CurrPos);
  End;
  SkipSpace;
  { Ferme la parenthese si presente }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
  { Evaluer l'appartenance }
  EvaluateCondition:=KeyInArray(ArrayName,KeyStr);
  Exit;
 End;
 
 { Sinon, revenir en arriere et traiter normalement }
 CurrPos:=SavePos;

 { Recupere la partie gauche de la condition }
 IsStringCompare:=False;
 If CurrLine[CurrPos]='"'Then Begin
  IsStringCompare:=True;
  LeftStr:=GetStringValue;
 End
  Else
 Begin
  SavePos:=CurrPos;
  LeftNum:=GetNumberValue(1);
 End;

 SkipSpace;

 { Recupere l'operateur de comparaison }
 Op:='';
 If(CurrPos<=Length(CurrLine))Then Begin
  If(CurrLine[CurrPos]='=')and(CurrPos+1<=Length(CurrLine))and(CurrLine[CurrPos+1]='=')Then Begin
   Op:='==';
   Inc(CurrPos,2);
  End
   Else
  If(CurrLine[CurrPos]='!')and(CurrPos+1<=Length(CurrLine))and(CurrLine[CurrPos+1]='=')Then Begin
   Op:='!=';
   Inc(CurrPos,2);
  End
   Else
  If(CurrLine[CurrPos]='<')and(CurrPos+1<=Length(CurrLine))and(CurrLine[CurrPos+1]='=')Then Begin
   Op:='<=';
   Inc(CurrPos,2);
  End
   Else
  If(CurrLine[CurrPos]='>')and(CurrPos+1<=Length(CurrLine))and(CurrLine[CurrPos+1]='=')Then Begin
   Op:='>=';
   Inc(CurrPos,2);
  End
   Else
  If CurrLine[CurrPos]='<'Then Begin
   Op:='<';
   Inc(CurrPos);
  End
   Else
  If CurrLine[CurrPos]='>'Then Begin
   Op:='>';
   Inc(CurrPos);
  End
   Else
  If CurrLine[CurrPos]='~'Then Begin
   Op:='~'; { regex match }
   Inc(CurrPos);
  End;
 End;

 { Si pas d'operateur, on evalue la valeur comme booleen }
 If Op=''Then Begin
  If IsStringCompare Then EvaluateCondition:=(LeftStr<>'')
                     Else EvaluateCondition:=(LeftNum<>0);
  { Ferme la parenthese si presente }
  SkipSpace;
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
  Exit;
 End;

 SkipSpace;

 { Recupere la partie droite de la condition }
 { Pour l'operateur regex, on peut avoir /pattern/ ou "pattern" }
 If Op='~'Then Begin
  IsStringCompare:=True;
  If CurrLine[CurrPos]='/'Then Begin
   { Pattern regex entre slashes }
   Inc(CurrPos);
   RightStr:='';
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>'/')do Begin
    If(CurrLine[CurrPos]='\')and(CurrPos<Length(CurrLine))Then Begin
     { Caractere echappe }
     Inc(CurrPos);
     RightStr:=RightStr+CurrLine[CurrPos];
    End
     Else
    RightStr:=RightStr+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   If CurrPos<=Length(CurrLine)Then Inc(CurrPos); { Saute le / final }
  End
   Else If CurrLine[CurrPos]='"'Then Begin
   RightStr:=GetStringValue;
  End
   Else
  Begin
   { Pattern sans delimiteurs }
   RightStr:='';
   While(CurrPos<=Length(CurrLine))and Not(CurrLine[CurrPos]in[' ',#9,')',';','}'])do Begin
    RightStr:=RightStr+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
  End;
 End
  Else
 If CurrLine[CurrPos]='"'Then Begin
  IsStringCompare:=True;
  RightStr:=GetStringValue;
 End
  Else
 Begin
  RightNum:=GetNumberValue(1);
  If IsStringCompare Then Begin
   Str(RightNum:0:0,RightStr);
  End;
 End;

 { Ferme la parenthese si presente }
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);

 { Effectue la comparaison }
 If Op='~'Then Begin
  { Regex match - convertit LeftNum en string si necessaire }
  If LeftStr=''Then Str(LeftNum:0:0,LeftStr);
  EvaluateCondition:=RegexMatch(LeftStr,RightStr);
 End
  Else
 If IsStringCompare Then Begin
  { Convertit LeftNum en string si necessaire }
  If LeftStr=''Then Str(LeftNum:0:0,LeftStr);

  If Op='=='Then EvaluateCondition:=(LeftStr=RightStr)
  Else If Op='!='Then EvaluateCondition:=(LeftStr<>RightStr)
  Else If Op='<'Then EvaluateCondition:=(LeftStr<RightStr)
  Else If Op='>'Then EvaluateCondition:=(LeftStr>RightStr)
  Else If Op='<='Then EvaluateCondition:=(LeftStr<=RightStr)
  Else If Op='>='Then EvaluateCondition:=(LeftStr>=RightStr);
 End
  Else
 Begin
  If Op='=='Then EvaluateCondition:=(LeftNum=RightNum)
  Else If Op='!='Then EvaluateCondition:=(LeftNum<>RightNum)
  Else If Op='<'Then EvaluateCondition:=(LeftNum<RightNum)
  Else If Op='>'Then EvaluateCondition:=(LeftNum>RightNum)
  Else If Op='<='Then EvaluateCondition:=(LeftNum<=RightNum)
  Else If Op='>='Then EvaluateCondition:=(LeftNum>=RightNum);
 End;
End;

{ Saute les espaces et le mot-cle 'then' }
Procedure SkipThen;
Begin
 SkipSpace;
 If StrToUpper(Copy(CurrLine,CurrPos,4))='THEN'Then Inc(CurrPos,4);
 SkipSpace;
End;

{ Trouve la position de fin du bloc (accolade fermante correspondante) }
Function FindBlockEnd(StartLine:Integer):Integer;
Var
 BraceCount:Integer;
 I,J:Integer;
 Line:String;
Begin
 FindBlockEnd:=StartLine;
 BraceCount:=0;

 For I:=StartLine to NumberLine do Begin
  Line:=PA[I]^;
  For J:=1 to Length(Line)do Begin
   If Line[J]='{'Then Inc(BraceCount)
   Else If Line[J]='}'Then Begin
    Dec(BraceCount);
    If BraceCount<=0 Then Begin
     FindBlockEnd:=I;
     Exit;
    End;
   End;
  End;
 End;
End;

{ Execute le bloc de code entre accolades ou une seule instruction }
Function RunBlock:Boolean;
Var
 SaveLinePtr:Integer;
 SaveAccoladeBlock:Integer;
Begin
 RunBlock:=True;
 SkipSpace;

 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
  Inc(CurrPos);
  SaveAccoladeBlock:=AccoladeBlock;
  Inc(AccoladeBlock);
  
  { Executer le contenu du bloc jusqu'a l'accolade fermante }
  While AccoladeBlock>SaveAccoladeBlock do Begin
   If Not RunLine Then Break;
   { Verifier si on a atteint la fin du bloc }
   If AccoladeBlock<=SaveAccoladeBlock Then Break;
   { Passer a la ligne suivante si necessaire }
   If CurrPos>Length(CurrLine)Then Begin
    Inc(CurrLinePtr);
    If CurrLinePtr<=NumberLine Then Begin
     CurrLine:=PA[CurrLinePtr]^;
     CurrPos:=1;
    End
     Else
    Break;
   End;
  End;
 End
  Else
 Begin
  { Pas d'accolade - executer une seule instruction }
  { Si fin de ligne, passer a la ligne suivante }
  If CurrPos>Length(CurrLine)Then Begin
   SaveLinePtr:=CurrLinePtr;
   Inc(CurrLinePtr);
   If CurrLinePtr<=NumberLine Then Begin
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
    { Executer cette ligne comme le corps du if }
    RunLine;
   End;
  End
   Else
  Begin
   { Il reste du contenu sur la ligne - l'executer }
   RunLine;
  End;
 End;
End;

{ Saute le bloc de code (ne l'execute pas) - supporte multi-lignes }
Procedure SkipBlock;
Var
 BraceCount:Integer;
 InQuote,InApos:Boolean;
Begin
 SkipSpace;
 BraceCount:=0;
 InQuote:=False;
 InApos:=False;

 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
  BraceCount:=1;
  Inc(CurrPos);

  { Parcourt la ligne courante }
  While(CurrPos<=Length(CurrLine))and(BraceCount>0)do Begin
   Case CurrLine[CurrPos]of
    '"':If Not InApos Then InQuote:=Not InQuote;
    '''':If Not InQuote Then InApos:=Not InApos;
    '{':If Not InQuote and Not InApos Then Inc(BraceCount);
    '}':If Not InQuote and Not InApos Then Dec(BraceCount);
   End;
   If BraceCount>0 Then Inc(CurrPos);
  End;
  If BraceCount=0 Then Begin
   Inc(CurrPos); { Saute l'accolade fermante }
   Exit;
  End;
  
  { Continue sur les lignes suivantes si necessaire }
  While(BraceCount>0)and(CurrLinePtr<NumberLine)do Begin
   Inc(CurrLinePtr);
   CurrLine:=PA[CurrLinePtr]^;
   CurrPos:=1;
   InQuote:=False;
   InApos:=False;
   
   While(CurrPos<=Length(CurrLine))and(BraceCount>0)do Begin
    Case CurrLine[CurrPos]of
     '"':If Not InApos Then InQuote:=Not InQuote;
     '''':If Not InQuote Then InApos:=Not InApos;
     '#':If Not InQuote and Not InApos Then Begin
       CurrPos:=Length(CurrLine)+1; { Commentaire, saute le reste }
       Continue;
      End;
     '{':If Not InQuote and Not InApos Then Inc(BraceCount);
     '}':If Not InQuote and Not InApos Then Dec(BraceCount);
    End;
    If BraceCount>0 Then Inc(CurrPos);
   End;
  End;
  
  If BraceCount=0 Then Inc(CurrPos); { Saute l'accolade fermante }
 End
  Else
 Begin
  { Saute jusqu'au point-virgule ou fin de ligne pour instructions simples }
  { Si on est en fin de ligne, passer a la ligne suivante }
  If CurrPos>Length(CurrLine)Then Begin
   If CurrLinePtr<NumberLine Then Begin
    Inc(CurrLinePtr);
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
   End;
  End;
  { Sauter l'instruction }
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>';')and(CurrLine[CurrPos]<>'}')do Begin
   Inc(CurrPos);
  End;
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
 End;
End;

{ Implementation de la commande if }
Procedure IfCommand;
Var
 Condition:Boolean;
Begin
 SkipSpace;
 Condition:=EvaluateCondition;
 SkipThen;

 If Condition Then Begin
  { Execute le bloc then }
  RunBlock;
  { Apres le bloc then, il peut y avoir un else a sauter }
  SkipSpace;
  If CurrPos>Length(CurrLine)Then Begin
   { Passer a la ligne suivante pour chercher else }
   If CurrLinePtr<NumberLine Then Begin
    Inc(CurrLinePtr);
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
   End;
  End;
  If StrToUpper(Copy(CurrLine,CurrPos,4))='ELSE'Then Begin
   Inc(CurrPos,4);
   SkipSpace;
   SkipBlock;
  End;
 End
  Else
 Begin
  { Saute le bloc then }
  SkipBlock;

  { Verifie s'il y a un else - possiblement sur la ligne suivante }
  SkipSpace;
  If CurrPos>Length(CurrLine)Then Begin
   { Passer a la ligne suivante pour chercher else }
   If CurrLinePtr<NumberLine Then Begin
    Inc(CurrLinePtr);
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
   End;
  End;
  If StrToUpper(Copy(CurrLine,CurrPos,4))='ELSE'Then Begin
   Inc(CurrPos,4);
   SkipSpace;
   { Verifie s'il y a un "if" apres le else (else if) }
   If StrToUpper(Copy(CurrLine,CurrPos,2))='IF'Then Begin
    Inc(CurrPos,2);
    SkipSpace;
    IfCommand;
   End
    Else
   RunBlock;
  End;
 End;
End;

{ Recupere la valeur d'expression pour switch }
Function GetSwitchValue:String;
Var
 V:Real;
 S:String;
Begin
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='(')Then Inc(CurrPos);
 SkipSpace;

 If CurrLine[CurrPos]='"'Then Begin
  GetSwitchValue:=GetStringValue;
 End
  Else
 Begin
  V:=GetNumberValue(1);
  If Frac(V)=0.0 Then Str(V:0:0,S)
                 Else Str(V,S);
  GetSwitchValue:=S;
 End;

 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
End;

{ Recupere la valeur d'un case }
Function GetCaseValue:String;
Var
 V:Real;
 S:String;
Begin
 SkipSpace;
 If CurrLine[CurrPos]='"'Then Begin
  GetCaseValue:=GetStringValue;
 End
  Else
 Begin
  V:=GetNumberValue(1);
  If Frac(V)=0.0 Then Str(V:0:0,S)
                 Else Str(V,S);
  GetCaseValue:=S;
 End;

 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=':')Then Inc(CurrPos);
End;

{ Implementation de la commande switch }
Procedure SwitchCommand;
Var
 SwitchVal,CaseVal:String;
 Found,BreakFound,Executing:Boolean;
 SaveCmd:String;
 CmdIndex:Byte;
 SavePos:Integer;
 InString:Boolean;
Begin
 SkipSpace;
 SwitchVal:=GetSwitchValue;
 SkipSpace;

 { Attend l'accolade ouvrante }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
  Inc(CurrPos);
  Inc(AccoladeBlock);
 End
  Else
 Begin
  WriteLn('Erreur de syntaxe : "{" attendu apres switch');
  Halt(1);
 End;

 Found:=False;
 BreakFound:=False;
 Executing:=False;

 { Parcourt les cases }
 While(CurrPos<=Length(CurrLine))do Begin
  SkipSpace;
  If CurrPos>Length(CurrLine)Then Break;

  If CurrLine[CurrPos]='}'Then Begin
   Dec(AccoladeBlock);
   Inc(CurrPos);
   Break;
  End;

  { Extrait le mot-cle }
  SavePos:=CurrPos;
  SaveCmd:='';
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z'])do Begin
   SaveCmd:=SaveCmd+CurrLine[CurrPos];
   Inc(CurrPos);
  End;

  If StrToUpper(SaveCmd)='CASE'Then Begin
   CaseVal:=GetCaseValue;
   If(Not Found)and(SwitchVal=CaseVal)Then Begin
    Found:=True;
    Executing:=True;
   End;
  End
   Else
  If StrToUpper(SaveCmd)='DEFAULT'Then Begin
   SkipSpace;
   If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=':')Then Inc(CurrPos);
   If Not Found Then Begin
    Found:=True;
    Executing:=True;
   End;
  End
   Else
  If StrToUpper(SaveCmd)='BREAK'Then Begin
   SkipSpace;
   If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
   If Executing Then Begin
    BreakFound:=True;
    Break; { Sort de la boucle switch }
   End;
  End
   Else
  If SaveCmd<>''Then Begin
   { C'est une commande a executer }
   If Executing Then Begin
    CurrPos:=SavePos;
    CmdIndex:=ExtractCommand;
    Case CmdIndex of
     48: PrintCommand; { print }
     31: IfCommand; { if }
     Else Begin
      { Saute les commandes non supportees dans switch }
      InString:=False;
      While(CurrPos<=Length(CurrLine))do Begin
       If CurrLine[CurrPos]='"'Then InString:=Not InString;
       If(Not InString)and((CurrLine[CurrPos]=';')or(CurrLine[CurrPos]='}'))Then Break;
       If(Not InString)and(CurrLine[CurrPos]in['A'..'Z','a'..'z'])Then Begin
        { Peut-etre un nouveau mot-cle }
        SavePos:=CurrPos;
        SaveCmd:='';
        While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z'])do Begin
         SaveCmd:=SaveCmd+CurrLine[CurrPos];
         Inc(CurrPos);
        End;
        If(StrToUpper(SaveCmd)='CASE')or(StrToUpper(SaveCmd)='DEFAULT')or
          (StrToUpper(SaveCmd)='BREAK')or(StrToUpper(SaveCmd)='PRINT')Then Begin
         CurrPos:=SavePos;
         Break;
        End;
       End
        Else
       Inc(CurrPos);
      End;
      If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
     End;
    End;
   End
    Else
   Begin
    { Pas en execution, saute cette commande en tenant compte des strings }
    InString:=False;
    While(CurrPos<=Length(CurrLine))do Begin
     If CurrLine[CurrPos]='"'Then InString:=Not InString;
     If(Not InString)and((CurrLine[CurrPos]=';')or(CurrLine[CurrPos]='}'))Then Break;
     { Verifie si on arrive a un mot-cle }
     If(Not InString)and(CurrLine[CurrPos]in['A'..'Z','a'..'z'])Then Begin
      SavePos:=CurrPos;
      SaveCmd:='';
      While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z'])do Begin
       SaveCmd:=SaveCmd+CurrLine[CurrPos];
       Inc(CurrPos);
      End;
      If(StrToUpper(SaveCmd)='CASE')or(StrToUpper(SaveCmd)='DEFAULT')or
        (StrToUpper(SaveCmd)='BREAK')Then Begin
       CurrPos:=SavePos;
       Break;
      End;
     End
      Else
     Inc(CurrPos);
    End;
    If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
   End;
  End;

  SkipSpace;
 End;

 { Assure que l'accolade est fermee si on n'a pas atteint la fin }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>'}')do Inc(CurrPos);
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='}')Then Begin
  Dec(AccoladeBlock);
  Inc(CurrPos);
 End;
End;

Procedure SplitIntoFields(Line:String);
Var
 I,Start:Integer;
 InSpace:Boolean;
Begin
 NumFields:=0;
 I:=1;
 InSpace:=True;
 Start:=1;
 While I<=Length(Line)do Begin
  If(Line[I]in[' ',#9])Then Begin
   If Not InSpace Then Begin
    Fields[NumFields]:=Copy(Line,Start,I-Start);
    Inc(NumFields);
    InSpace:=True;
   End;
  End
   Else
  Begin
   If InSpace Then Begin
    Start:=I;
    InSpace:=False;
   End;
  End;
  Inc(I);
 End;
 If Not InSpace Then Begin
  Fields[NumFields]:=Copy(Line,Start,I-Start);
  Inc(NumFields);
 End;
End;

{ Tente de traiter une assignation de variable }
{ Retourne True si c'est une assignation, False sinon }
Function TryAssignment:Boolean;
Var
 VarName:String;
 SavePos:Integer;
 R:Real;
 StrValue:String;
 IsIncrement,IsDecrement:Boolean;
 ArrayKey:String;
 IsArrayAssign:Boolean;
Begin
 TryAssignment:=False;
 SavePos:=CurrPos;
 VarName:='';
 IsIncrement:=False;
 IsDecrement:=False;
 IsArrayAssign:=False;
 ArrayKey:='';

 { Verifier operateur prefixe ++ ou -- }
 If(CurrPos+1<=Length(CurrLine))Then Begin
  If(CurrLine[CurrPos]='+')and(CurrLine[CurrPos+1]='+')Then Begin
   IsIncrement:=True;
   Inc(CurrPos,2);
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=' ')do Inc(CurrPos);
  End
  Else If(CurrLine[CurrPos]='-')and(CurrLine[CurrPos+1]='-')Then Begin
   IsDecrement:=True;
   Inc(CurrPos,2);
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=' ')do Inc(CurrPos);
  End;
 End;

 { Extraire le nom de la variable }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
  VarName:=VarName+CurrLine[CurrPos];
  Inc(CurrPos);
 End;

 If VarName=''Then Begin
  CurrPos:=SavePos;
  Exit;
 End;

 { Verifier si c'est un acces tableau array[key] }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='[')Then Begin
  Inc(CurrPos);
  { Lire la cle }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
   ArrayKey:=GetStringValue;
  End
   Else
  Begin
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
    ArrayKey:=ArrayKey+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   { Si c'est une variable, recuperer sa valeur }
   If VariableExist(StrToUpper(ArrayKey))Then Begin
    Case VariableType(StrToUpper(ArrayKey))of
     _String:ArrayKey:=GetVariableString(StrToUpper(ArrayKey));
     _Integer:Str(GetVariableInt(StrToUpper(ArrayKey)),ArrayKey);
     _LongInt:Str(GetVariableLongInt(StrToUpper(ArrayKey)),ArrayKey);
     _Real:Str(GetVariableReal(StrToUpper(ArrayKey)):0:0,ArrayKey);
    End;
   End;
  End;
  { Sauter ] }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=']')Then Inc(CurrPos);
  IsArrayAssign:=True;
 End;

 { Sauter les espaces }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=' ')do Inc(CurrPos);

 { Si c'etait un prefix ++/-- }
 If IsIncrement or IsDecrement Then Begin
  VarName:=StrToUpper(VarName);
  TryAssignment:=True;
  If VariableExist(VarName)Then Begin
   R:=GetVariableLongInt(VarName);
   If IsIncrement Then SetVariableLongInt(VarName,Round(R)+1)
                  Else SetVariableLongInt(VarName,Round(R)-1);
  End
   Else
  Begin
   If IsIncrement Then AddVariableLongInt(VarName,1)
                  Else AddVariableLongInt(VarName,-1);
  End;
  Exit;
 End;

 { Verifier operateur postfixe ++ ou -- }
 If(CurrPos+1<=Length(CurrLine))Then Begin
  If(CurrLine[CurrPos]='+')and(CurrLine[CurrPos+1]='+')Then Begin
   VarName:=StrToUpper(VarName);
   TryAssignment:=True;
   If VariableExist(VarName)Then Begin
    R:=GetVariableLongInt(VarName);
    SetVariableLongInt(VarName,Round(R)+1);
   End
    Else
   Begin
    AddVariableLongInt(VarName,1);
   End;
   Inc(CurrPos,2);
   Exit;
  End
  Else If(CurrLine[CurrPos]='-')and(CurrLine[CurrPos+1]='-')Then Begin
   VarName:=StrToUpper(VarName);
   TryAssignment:=True;
   If VariableExist(VarName)Then Begin
    R:=GetVariableLongInt(VarName);
    SetVariableLongInt(VarName,Round(R)-1);
   End
    Else
   Begin
    AddVariableLongInt(VarName,-1);
   End;
   Inc(CurrPos,2);
   Exit;
  End;
 End;

 { Verifier si c'est une assignation }
 If(CurrPos>Length(CurrLine))or(CurrLine[CurrPos]<>'=')Then Begin
  CurrPos:=SavePos;
  Exit;
 End;

 { Verifier que ce n'est pas == }
 If(CurrPos+1<=Length(CurrLine))and(CurrLine[CurrPos+1]='=')Then Begin
  CurrPos:=SavePos;
  Exit;
 End;

 { C'est une assignation! }
 Inc(CurrPos); { passer le = }
 TryAssignment:=True;

 { Sauter les espaces }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=' ')do Inc(CurrPos);

 { Si c'est une assignation de tableau }
 If IsArrayAssign Then Begin
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
   StrValue:=GetStringValue;
  End
   Else
  Begin
   R:=GetNumberValue(1);
   Str(R:0:0,StrValue);
  End;
  SetArrayElement(VarName,ArrayKey,StrValue);
  Exit;
 End;

 { Determiner si c'est une chaine ou un nombre }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
  { Assignation de chaine }
  StrValue:=GetStringValue;
  VarName:=StrToUpper(VarName);
  If VariableExist(VarName)Then Begin
   SetVariableString(VarName,StrValue);
  End
   Else
  Begin
   AddVariableString(VarName,StrValue);
  End;
 End
  Else
 Begin
  { Assignation numerique }
  R:=GetNumberValue(1);
  VarName:=StrToUpper(VarName);
  If VariableExist(VarName)Then Begin
   If Frac(R)=0.0 Then SetVariableLongInt(VarName,Round(R))
                  Else SetVariableReal(VarName,R);
  End
   Else
  Begin
   If Frac(R)=0.0 Then AddVariableLongInt(VarName,Round(R))
                  Else AddVariableReal(VarName,R);
  End;
 End;
End;

{ Implementation de la commande while }
Procedure WhileCommand;
Var
 Condition:Boolean;
 SaveLinePtr:Integer;
 SaveCurrLine:String;
 LoopStart:Integer;
 BlockStartLinePtr:Integer;
 BlockStartLine:String;
 BlockStartPos:Integer;
 HasBrace:Boolean;
Begin
 SkipSpace;
 Inc(LoopDepth);
 
 { Sauvegarder position pour la condition }
 SaveLinePtr:=CurrLinePtr;
 SaveCurrLine:=CurrLine;
 LoopStart:=CurrPos;
 
 { Evaluer la condition initiale }
 Condition:=EvaluateCondition;
 SkipSpace;
 
 { Determiner si le bloc a une accolade }
 HasBrace:=(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{');
 
 { Memoriser le debut du bloc }
 If HasBrace Then Begin
  BlockStartLinePtr:=CurrLinePtr;
  BlockStartLine:=CurrLine;
  BlockStartPos:=CurrPos;
 End
  Else
 Begin
  { Pas d'accolade - le bloc est sur la ligne suivante si fin de ligne }
  If CurrPos>Length(CurrLine)Then Begin
   If CurrLinePtr<NumberLine Then Begin
    Inc(CurrLinePtr);
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
   End;
  End;
  BlockStartLinePtr:=CurrLinePtr;
  BlockStartLine:=CurrLine;
  BlockStartPos:=CurrPos;
 End;
 
 If Not Condition Then Begin
  { Condition fausse des le depart - sauter le bloc }
  CurrLinePtr:=BlockStartLinePtr;
  CurrLine:=BlockStartLine;
  CurrPos:=BlockStartPos;
  SkipBlock;
  Dec(LoopDepth);
  Exit;
 End;
 
 { Boucle while }
 While Condition do Begin
  { Reinitialiser les flags }
  ContinueFlag:=False;
  
  { Revenir au debut du bloc }
  CurrLinePtr:=BlockStartLinePtr;
  CurrLine:=BlockStartLine;
  CurrPos:=BlockStartPos;
  
  { Executer le bloc }
  RunBlock;
  
  { Verifier break }
  If BreakFlag Then Begin
   BreakFlag:=False;
   Break;
  End;
  
  { Revenir a la condition }
  CurrLinePtr:=SaveLinePtr;
  CurrLine:=SaveCurrLine;
  CurrPos:=LoopStart;
  
  { Reevaluer la condition }
  Condition:=EvaluateCondition;
  SkipSpace;
 End;
 
 { Sauter le bloc apres la derniere iteration }
 CurrLinePtr:=BlockStartLinePtr;
 CurrLine:=BlockStartLine;
 CurrPos:=BlockStartPos;
 SkipBlock;
 Dec(LoopDepth);
End;

{ Implementation de la boucle do-while }
Procedure DoWhileCommand;
Var
 Condition:Boolean;
 BlockStartLinePtr:Integer;
 BlockStartLine:String;
 BlockStartPos:Integer;
 HasBrace:Boolean;
 DidBreak:Boolean;
Begin
 SkipSpace;
 Inc(LoopDepth);
 DidBreak:=False;
 
 { Memoriser le debut du bloc }
 HasBrace:=(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{');
 
 If Not HasBrace Then Begin
  { Pas d'accolade - le bloc est sur la ligne suivante si fin de ligne }
  If CurrPos>Length(CurrLine)Then Begin
   If CurrLinePtr<NumberLine Then Begin
    Inc(CurrLinePtr);
    CurrLine:=PA[CurrLinePtr]^;
    CurrPos:=1;
    SkipSpace;
   End;
  End;
 End;
 
 BlockStartLinePtr:=CurrLinePtr;
 BlockStartLine:=CurrLine;
 BlockStartPos:=CurrPos;
 
 { Boucle do-while - executer au moins une fois }
 Repeat
  { Reinitialiser les flags }
  ContinueFlag:=False;
  
  { Revenir au debut du bloc }
  CurrLinePtr:=BlockStartLinePtr;
  CurrLine:=BlockStartLine;
  CurrPos:=BlockStartPos;
  
  { Executer le bloc }
  RunBlock;
  
  { Verifier break }
  If BreakFlag Then Begin
   BreakFlag:=False;
   DidBreak:=True;
   Break;
  End;
  
  { Pour trouver 'while', revenir au debut et utiliser SkipBlock }
  { car RunBlock ne positionne pas correctement le curseur apres le bloc }
  CurrLinePtr:=BlockStartLinePtr;
  CurrLine:=BlockStartLine;
  CurrPos:=BlockStartPos;
  SkipBlock;
  
  { Chercher le mot-cle while }
  SkipSpace;
  { Peut etre sur la ligne suivante }
  While(CurrPos>Length(CurrLine))and(CurrLinePtr<NumberLine)do Begin
   Inc(CurrLinePtr);
   CurrLine:=PA[CurrLinePtr]^;
   CurrPos:=1;
   SkipSpace;
  End;
  
  { Verifier qu'on a 'while' }
  If(CurrPos+4<=Length(CurrLine))and
    (StrToUpper(Copy(CurrLine,CurrPos,5))='WHILE')Then Begin
   Inc(CurrPos,5);
   SkipSpace;
  End
   Else
  Begin
   { Pas de while trouve - erreur de syntaxe }
   WriteLn('Erreur: while attendu apres do');
   Dec(LoopDepth);
   Exit;
  End;
  
  { Evaluer la condition }
  Condition:=EvaluateCondition;
  
 Until Not Condition;
 
 { Si on a fait break, on doit sauter le bloc et chercher le while final }
 If DidBreak Then Begin
  { Revenir au debut du bloc et le sauter }
  CurrLinePtr:=BlockStartLinePtr;
  CurrLine:=BlockStartLine;
  CurrPos:=BlockStartPos;
  SkipBlock;
  
  { Chercher le mot-cle while }
  SkipSpace;
  While(CurrPos>Length(CurrLine))and(CurrLinePtr<NumberLine)do Begin
   Inc(CurrLinePtr);
   CurrLine:=PA[CurrLinePtr]^;
   CurrPos:=1;
   SkipSpace;
  End;
  
  { Sauter 'while' et la condition }
  If(CurrPos+4<=Length(CurrLine))and
    (StrToUpper(Copy(CurrLine,CurrPos,5))='WHILE')Then Begin
   Inc(CurrPos,5);
   SkipSpace;
   { Sauter la condition entre parentheses }
   If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='(')Then Begin
    Inc(CurrPos);
    { Trouver la parenthese fermante }
    While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>')')do Inc(CurrPos);
    If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
   End;
  End;
 End;
 
 { Sauter le point-virgule final si present }
 SkipSpace;
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
 
 Dec(LoopDepth);
End;

{ Implementation de la boucle for-in }
Procedure ForInCommand(IterVar,ArrayName:String);
Var
 ArrayIdx,ElemIdx:Integer;
 BlockStartPos:Integer;
 SaveLinePtr:Integer;
 SaveCurrLine:String;
Begin
 Inc(LoopDepth);
 
 { Position du bloc }
 BlockStartPos:=CurrPos;
 
 { Sauvegarder la ligne courante }
 SaveLinePtr:=CurrLinePtr;
 SaveCurrLine:=CurrLine;
 
 { Trouver le tableau }
 ArrayIdx:=FindArray(ArrayName);
 If ArrayIdx=0 Then Begin
  { Tableau vide ou inexistant - sauter le bloc }
  SkipBlock;
  Dec(LoopDepth);
  Exit;
 End;
 
 { Iterer sur chaque element }
 For ElemIdx:=1 to AssocArrays[ArrayIdx].Count do Begin
  { Reinitialiser les flags }
  ContinueFlag:=False;
  
  { Assigner la cle a la variable d'iteration }
  If VariableExist(IterVar)Then Begin
   SetVariableString(IterVar,AssocArrays[ArrayIdx].Elements[ElemIdx].Key);
  End
   Else
  AddVariableString(IterVar,AssocArrays[ArrayIdx].Elements[ElemIdx].Key);
  
  { Executer le bloc }
  CurrLinePtr:=SaveLinePtr;
  CurrLine:=SaveCurrLine;
  CurrPos:=BlockStartPos;
  RunBlock;
  
  { Verifier break }
  If BreakFlag Then Begin
   BreakFlag:=False;
   Break;
  End;
 End;
 
 { Sauter le bloc apres la derniere iteration }
 CurrLinePtr:=SaveLinePtr;
 CurrLine:=SaveCurrLine;
 CurrPos:=BlockStartPos;
 SkipBlock;
 Dec(LoopDepth);
End;

{ Implementation de la commande for }
Procedure ForCommand;
Var
 Condition:Boolean;
 SavePos:Integer;
 InitStartPos,CondStartPos,IncrStartPos,BlockStartPos:Integer;
 SaveLinePtr:Integer;
 SaveCurrLine:String;
 InParen:Integer;
 IterVar,ArrayName:String;
 IsForIn:Boolean;
 ScanPos:Integer;
Begin
 SkipSpace;
 
 { Attendre ( }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='(')Then Inc(CurrPos);
 SkipSpace;
 
 { Detecter si c'est un for-in en cherchant "var in array" }
 IsForIn:=False;
 IterVar:='';
 ArrayName:='';
 ScanPos:=CurrPos;
 
 { Lire la variable potentielle }
 While(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
  IterVar:=IterVar+CurrLine[ScanPos];
  Inc(ScanPos);
 End;
 
 { Sauter les espaces }
 While(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]in[' ',#9])do Inc(ScanPos);
 
 { Verifier si "in" suit }
 If(ScanPos+1<=Length(CurrLine))and(Copy(CurrLine,ScanPos,3)='in ')Then Begin
  Inc(ScanPos,2);
  While(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]in[' ',#9])do Inc(ScanPos);
  { Lire le nom du tableau }
  While(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
   ArrayName:=ArrayName+CurrLine[ScanPos];
   Inc(ScanPos);
  End;
  { Sauter les espaces et la parenthese fermante }
  While(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]in[' ',#9])do Inc(ScanPos);
  If(ScanPos<=Length(CurrLine))and(CurrLine[ScanPos]=')')Then Begin
   IsForIn:=True;
   CurrPos:=ScanPos+1;
   SkipSpace;
  End;
 End;
 
 { Si c'est un for-in, deleguer a ForInCommand }
 If IsForIn Then Begin
  ForInCommand(IterVar,ArrayName);
  Exit;
 End;
 
 Inc(LoopDepth);
 
 { Partie initialisation (avant le premier ;) }
 InitStartPos:=CurrPos;
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>';')do Inc(CurrPos);
 
 { Executer l'initialisation }
 SavePos:=CurrPos;
 CurrPos:=InitStartPos;
 TryAssignment;
 CurrPos:=SavePos;
 
 { Sauter le premier ; }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
 SkipSpace;
 
 { Partie condition (entre le premier et deuxieme ;) }
 CondStartPos:=CurrPos;
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>';')do Inc(CurrPos);
 
 { Sauter le deuxieme ; }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=';')Then Inc(CurrPos);
 SkipSpace;
 
 { Partie increment (entre le deuxieme ; et ) ) }
 IncrStartPos:=CurrPos;
 InParen:=1;
 While(CurrPos<=Length(CurrLine))and(InParen>0)do Begin
  If CurrLine[CurrPos]='('Then Inc(InParen)
  Else If CurrLine[CurrPos]=')'Then Dec(InParen);
  If InParen>0 Then Inc(CurrPos);
 End;
 
 { Sauter ) }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=')')Then Inc(CurrPos);
 SkipSpace;
 
 { Position du bloc }
 BlockStartPos:=CurrPos;
 
 { Sauvegarder la ligne courante }
 SaveLinePtr:=CurrLinePtr;
 SaveCurrLine:=CurrLine;
 
 { Evaluer la condition initiale }
 CurrPos:=CondStartPos;
 If CurrPos<Length(CurrLine)Then Condition:=EvaluateCondition
                            Else Condition:=True;
 
 If Not Condition Then Begin
  { Condition fausse des le depart }
  CurrPos:=BlockStartPos;
  SkipBlock;
  Dec(LoopDepth);
  Exit;
 End;
 
 { Boucle for }
 While Condition do Begin
  { Reinitialiser les flags }
  ContinueFlag:=False;
  
  { Executer le bloc }
  CurrPos:=BlockStartPos;
  RunBlock;
  
  { Verifier break }
  If BreakFlag Then Begin
   BreakFlag:=False;
   Break;
  End;
  
  { Executer l'increment }
  CurrLinePtr:=SaveLinePtr;
  CurrLine:=SaveCurrLine;
  CurrPos:=IncrStartPos;
  TryAssignment;
  
  { Reevaluer la condition }
  CurrPos:=CondStartPos;
  If CurrPos<Length(CurrLine)Then Condition:=EvaluateCondition
                             Else Condition:=True;
 End;
 
 { Sauter le bloc apres la derniere iteration }
 CurrPos:=BlockStartPos;
 SkipBlock;
 Dec(LoopDepth);
End;

{ Implementation de la commande delete }
Procedure DeleteCommand;
Var
 ArrayName,Key:String;
Begin
 SkipSpace;
 
 { Lire le nom du tableau }
 ArrayName:='';
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
  ArrayName:=ArrayName+CurrLine[CurrPos];
  Inc(CurrPos);
 End;
 
 { Sauter les espaces }
 While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=' ')do Inc(CurrPos);
 
 { Lire la cle entre crochets }
 If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='[')Then Begin
  Inc(CurrPos);
  Key:='';
  
  { Lire la cle - peut etre une chaine entre guillemets ou une variable }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='"')Then Begin
   Key:=GetStringValue;
  End
   Else
  Begin
   { Variable ou expression }
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','0'..'9'])do Begin
    Key:=Key+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   { Si c'est une variable, recuperer sa valeur }
   If VariableExist(StrToUpper(Key))Then Begin
    Case VariableType(StrToUpper(Key))of
     _String:Key:=GetVariableString(StrToUpper(Key));
     _Integer:Str(GetVariableInt(StrToUpper(Key)),Key);
     _LongInt:Str(GetVariableLongInt(StrToUpper(Key)),Key);
     _Real:Str(GetVariableReal(StrToUpper(Key)):0:0,Key);
    End;
   End;
  End;
  
  { Sauter le crochet fermant }
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]=']')Then Inc(CurrPos);
  
  { Supprimer l'element }
  DeleteArrayElement(ArrayName,Key);
 End;
End;

Function RunLine:Boolean;
Var
 UnknownCommand:Boolean;
 NoImplementation:Boolean;
 J,Err:Integer;
 CmdResult:Byte;
Begin
 RunLine:=False;
 Repeat
  { Sauter les espaces en debut de ligne }
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in[' ',#9])do Inc(CurrPos);

  { Verifier fin de ligne }
  If CurrPos>Length(CurrLine)Then Begin
   RunLine:=True;
   Exit;
  End;

  If CurrLine[CurrPos]='{'Then  Begin
   Inc(AccoladeBlock);
   Inc(CurrPos);
   Continue;
  End;
  If CurrLine[CurrPos]='}'Then  Begin
   If(AccoladeBlock>0)Then Begin
    Dec(AccoladeBlock);
    Inc(CurrPos);
    Continue;
   End
    Else
   Begin
    WriteLn('Une fermeture d''accolade est rencontr� ',
            'sans ouverture d''accolade');
    Halt(1);
   End;
  End;
  If CurrLine[CurrPos]='#'Then Begin
   CurrPos:=Length(CurrLine)+1;
   RunLine:=True;
   Exit;
  End;

  { Essayer d'abord une assignation de variable }
  If TryAssignment Then Begin
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in[' ',';'])do Inc(CurrPos);
   If CurrPos>Length(CurrLine)Then Begin
    RunLine:=True;
    Exit;
   End;
   Continue;
  End;

  NoImplementation:=False;
  UnknownCommand:=False;
  CmdResult:=ExtractCommand;
  Case CmdResult of
   0: BeginCommand;{BEGIN}
   1: NoImplementation:=True; {BEGINFILE}
   2: EndCommand; { END }
   3: NoImplementation:=True; {ENDFILE}
   4: NoImplementation:=True; { and }
   5: NoImplementation:=True; { asort }
   6: NoImplementation:=True; { asorti }
   7: NoImplementation:=True; { atan2 }
   8: NoImplementation:=True; { bindtextdomain }
   9: Begin { break }
    BreakFlag:=True;
   End;
   10: NoImplementation:=True; { case }
   11: NoImplementation:=True; { close }
   12: NoImplementation:=True; { compl }
   13: Begin { continue }
    ContinueFlag:=True;
   End;
   14: CosCommand; { cos }
   15: NoImplementation:=True; { dcgettext }
   16: NoImplementation:=True; { dcngettext }
   17: NoImplementation:=True; { default }
   18: DeleteCommand; { delete }
   19: DoWhileCommand; { do }
   20: Begin { else - gere par IfCommand, sauter ici }
    SkipBlock;
   End;
   21: NoImplementation:=True; { eval }
   22:Begin
    Terminated:=True;
    Exit;
   End;{ exit }
   23: NoImplementation:=True; { exp }
   24: NoImplementation:=True; { fflush }
   25: ForCommand; { for }
   26: FunctionCommand; { func }
   27: FunctionCommand; { function }
   28: NoImplementation:=True; { gensub }
   29: GetlineCommand; { getline }
   30: NoImplementation:=True; { gsub }
   31: IfCommand; { if }
   32: NoImplementation:=True; { in }
   33: NoImplementation:=True; { include }
   34: NoImplementation:=True; { index }
   35: NoImplementation:=True; { int }
   36: NoImplementation:=True; { isarray }
   37: Begin { length - gere comme fonction dans GetNumberValue }
    SkipSpace;
    If(CurrPos<=System.Length(CurrLine))and(CurrLine[CurrPos]='(')Then Begin
     WriteLn(GetNumberValue(1):0:0);
    End;
   End;
   38: NoImplementation:=True; { load }
   39: NoImplementation:=True; { log }
   40: NoImplementation:=True; { lshift }
   41: NoImplementation:=True; { match }
   42: NoImplementation:=True; { mktime }
   43: NoImplementation:=True; { namespace }
   44: NoImplementation:=True; { next }
   45: NoImplementation:=True; { nextfile }
   46: NoImplementation:=True; { or }
   47: NoImplementation:=True; { patsplit }
   48: PrintCommand; { print }
   49: PrintfCommand; { printf }
   50: NoImplementation:=True; { rand }
   51: ReturnCommand; { return }
   52: NoImplementation:=True; { rshift }
   53: NoImplementation:=True; { sin }
   54: NoImplementation:=True; { split }
   55: NoImplementation:=True; { sprintf }
   56: SqrtCommand; { sqrt }
   57: NoImplementation:=True; { srand }
   58: NoImplementation:=True; { strftime }
   59: NoImplementation:=True; { strtonum }
   60: NoImplementation:=True; { sub }
   61: NoImplementation:=True; { substr }
   62: SwitchCommand; { switch }
   63: NoImplementation:=True; { system }
   64: NoImplementation:=True; { systime }
   65: NoImplementation:=True; { tolower }
   66: NoImplementation:=True; { toupper }
   67: NoImplementation:=True; { typeof }
   68: WhileCommand; { while }
   69: NoImplementation:=True; { xor }
   Else UnknownCommand:=True;
  End;
  If(UnknownCommand)Then Begin
   WriteLn('Commande non reconnu a la position ',CurrPos,' de la ligne ',CurrNumberLine+1);
   Exit;
  End;
  If(NoImplementation)Then Begin
   WriteLn('La commande ',CurrCommand,' n''a pas ete implemente');
   Exit;
  End;
  { Verifier si un return a ete execute }
  If HasFunctionReturn Then Begin
   RunLine:=True;
   Exit;
  End;
  While(CurrLine[CurrPos]in[' ',';'])and(CurrPos<=Length(CurrLine)) do Inc(CurrPos);
  If CurrPos>Length(CurrLine)Then Break;
  If Not(CurrLine[CurrPos]in['A'..'Z','a'..'z','_','{','}','#'])Then Begin
   WriteLn('Erreur de syntaxe a la position ',CurrPos,' de la ligne ',CurrNumberLine+1);
   Exit;
  End;
 Until (CurrPos>Length(CurrLine))or HasFunctionReturn;
 RunLine:=True;
End;

{ ========================================================= }
{ SECTION: Regles Pattern-Action                            }
{ ========================================================= }

{ Initialise le tableau des regles }
Procedure InitRules;
Begin
 RuleCount:=0;
 HasInputFile:=False;
 InputFileName:='';
 NRValue:=0;
End;

{ Ajoute une regle pattern-action }
Procedure AddRule(Kind:TRuleKind;const Pattern:String;ActionLine,ActionPos,ActionEndLine:Integer);
Begin
 If RuleCount<MaxRules Then Begin
  Inc(RuleCount);
  Rules[RuleCount].Kind:=Kind;
  Rules[RuleCount].Pattern:=Pattern;
  Rules[RuleCount].ActionLine:=ActionLine;
  Rules[RuleCount].ActionPos:=ActionPos;
  Rules[RuleCount].ActionEndLine:=ActionEndLine;
 End;
End;

{ Execute une action (bloc de code) pour une regle }
Procedure ExecuteRuleAction(RuleIdx:Integer);
Var
 SaveLinePtr:Integer;
 SavePos:Integer;
 SaveLine:String;
Begin
 SaveLinePtr:=CurrLinePtr;
 SavePos:=CurrPos;
 SaveLine:=CurrLine;
 
 CurrLinePtr:=Rules[RuleIdx].ActionLine;
 CurrLine:=PA[CurrLinePtr]^;
 CurrPos:=Rules[RuleIdx].ActionPos;
 
 { Executer jusqu'a la fin de l'action }
 While CurrLinePtr<=Rules[RuleIdx].ActionEndLine do Begin
  If Not RunLine Then Break;
  Inc(CurrLinePtr);
  If CurrLinePtr<=Rules[RuleIdx].ActionEndLine Then Begin
   CurrLine:=PA[CurrLinePtr]^;
   CurrPos:=1;
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in[' ',#9])do Inc(CurrPos);
  End;
 End;
 
 CurrLinePtr:=SaveLinePtr;
 CurrPos:=SavePos;
 CurrLine:=SaveLine;
End;

{ Verifie si un pattern correspond a la ligne courante }
Function MatchesPattern(RuleIdx:Integer):Boolean;
Begin
 MatchesPattern:=False;
 Case Rules[RuleIdx].Kind of
  RK_BEGIN: MatchesPattern:=False; { BEGIN deja execute }
  RK_END: MatchesPattern:=False;   { END execute a la fin }
  RK_ALL: MatchesPattern:=True;    { Toujours vrai }
  RK_REGEX: Begin
   { Matcher le pattern regex contre $0 }
   MatchesPattern:=RegexMatch(Fields[0],Rules[RuleIdx].Pattern);
  End;
  RK_EXPR: Begin
   { TODO: Evaluer l'expression - pour l'instant, toujours vrai }
   MatchesPattern:=True;
  End;
 End;
End;

{ Execute les regles BEGIN }
Procedure ExecuteBeginRules;
Var
 I:Integer;
Begin
 For I:=1 to RuleCount do Begin
  If Rules[I].Kind=RK_BEGIN Then
   ExecuteRuleAction(I);
 End;
End;

{ Execute les regles END }
Procedure ExecuteEndRules;
Var
 I:Integer;
Begin
 For I:=1 to RuleCount do Begin
  If Rules[I].Kind=RK_END Then
   ExecuteRuleAction(I);
 End;
End;

{ Execute les regles pattern sur la ligne courante }
Procedure ExecutePatternRules;
Var
 I:Integer;
Begin
 For I:=1 to RuleCount do Begin
  If Rules[I].Kind in[RK_ALL,RK_REGEX,RK_EXPR]Then Begin
   If MatchesPattern(I)Then
    ExecuteRuleAction(I);
  End;
 End;
End;

{ Parse le programme AWK pour extraire les regles }
Procedure ParseRulesFromProgram;
Var
 J,Err:Integer;
 LineStart:Integer;
 RuleKind:TRuleKind;
 Pattern:String;
 BlockLevel:Integer;
 ActionStart,ActionStartPos,ActionEnd:Integer;
 SaveLinePtr:Integer;
 InPattern:Boolean;
Begin
 InitRules;
 If NumberLine=0 Then Exit;
 
 CurrLinePtr:=1;
 While CurrLinePtr<=NumberLine do Begin
  CurrLine:=PA[CurrLinePtr]^;
  
  { Extraire le numero de ligne s'il y en a un }
  J:=1;
  While(J<Length(CurrLine))and(CurrLine[J]in['0'..'9'])do Inc(J);
  While(J<=Length(CurrLine))and(CurrLine[J]in[' ',#9])do Inc(J);
  CurrPos:=J;
  
  { Sauter les lignes vides et commentaires }
  If CurrPos>Length(CurrLine)Then Begin
   Inc(CurrLinePtr);
   Continue;
  End;
  If CurrLine[CurrPos]='#'Then Begin
   Inc(CurrLinePtr);
   Continue;
  End;
  
  { Detecter le type de regle }
  RuleKind:=RK_ALL;
  Pattern:='';
  InPattern:=False;
  
  { Verifier BEGIN }
  If(CurrPos+4<=Length(CurrLine))and
    (UpCase(CurrLine[CurrPos])='B')and
    (UpCase(CurrLine[CurrPos+1])='E')and
    (UpCase(CurrLine[CurrPos+2])='G')and
    (UpCase(CurrLine[CurrPos+3])='I')and
    (UpCase(CurrLine[CurrPos+4])='N')Then Begin
   RuleKind:=RK_BEGIN;
   Inc(CurrPos,5);
  End
  { Verifier END }
  Else If(CurrPos+2<=Length(CurrLine))and
         (UpCase(CurrLine[CurrPos])='E')and
         (UpCase(CurrLine[CurrPos+1])='N')and
         (UpCase(CurrLine[CurrPos+2])='D')Then Begin
   RuleKind:=RK_END;
   Inc(CurrPos,3);
  End
  { Verifier pattern regex /.../ }
  Else If CurrLine[CurrPos]='/'Then Begin
   RuleKind:=RK_REGEX;
   Inc(CurrPos); { Passer le premier / }
   While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]<>'/')do Begin
    Pattern:=Pattern+CurrLine[CurrPos];
    Inc(CurrPos);
   End;
   If CurrPos<=Length(CurrLine)Then Inc(CurrPos); { Passer le / final }
  End
  (* Verifier si c'est juste un bloc sans pattern *)
  Else If CurrLine[CurrPos]<>'{'Then Begin
   (* Pas de pattern reconnu et pas d'accolade - sauter *)
   Inc(CurrLinePtr);
   Continue;
  End;
  
  { Sauter les espaces avant l'accolade }
  While(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]in[' ',#9])do Inc(CurrPos);
  
  (* Trouver le bloc d'action *)
  If(CurrPos<=Length(CurrLine))and(CurrLine[CurrPos]='{')Then Begin
   ActionStart:=CurrLinePtr;
   ActionStartPos:=CurrPos+1;
   BlockLevel:=1;
   Inc(CurrPos);
   
   { Chercher la fin du bloc }
   While BlockLevel>0 do Begin
    While CurrPos<=Length(CurrLine)do Begin
     If CurrLine[CurrPos]='{'Then Inc(BlockLevel)
     Else If CurrLine[CurrPos]='}'Then Dec(BlockLevel);
     If BlockLevel=0 Then Break;
     Inc(CurrPos);
    End;
    If BlockLevel>0 Then Begin
     Inc(CurrLinePtr);
     If CurrLinePtr>NumberLine Then Break;
     CurrLine:=PA[CurrLinePtr]^;
     CurrPos:=1;
    End;
   End;
   ActionEnd:=CurrLinePtr;
   
   { Ajouter la regle }
   AddRule(RuleKind,Pattern,ActionStart,ActionStartPos,ActionEnd);
  End;
  
  Inc(CurrLinePtr);
 End;
End;

{ Traite un fichier de donnees avec les regles pattern }
Procedure ProcessInputWithRules;
Var
 InputLine:String;
Begin
 { Executer les regles BEGIN d'abord }
 ExecuteBeginRules;
 
 { Si pas de fichier d'entree, lire depuis stdin }
 If HasInputFile Then Begin
  {$I-}Assign(InputFile,InputFileName);
  Reset(InputFile);{$I+}
  If IoResult<>0Then Begin
   WriteLn('Fichier d''entree introuvable: ',InputFileName);
   Exit;
  End;
  
  While Not EOF(InputFile)do Begin
   ReadLn(InputFile,InputLine);
   Inc(NRValue);
   SetVariableLongInt('NR',NRValue);
   Fields[0]:=InputLine;
   SplitIntoFields(InputLine);
   SetVariableInt('NF',NumFields);
   ExecutePatternRules;
  End;
  Close(InputFile);
 End
  Else
 Begin
  { Lire depuis l'entree standard }
  While Not EOF do Begin
   ReadLn(InputLine);
   Inc(NRValue);
   SetVariableLongInt('NR',NRValue);
   Fields[0]:=InputLine;
   SplitIntoFields(InputLine);
   SetVariableInt('NF',NumFields);
   ExecutePatternRules;
  End;
 End;
 
 { Executer les regles END a la fin }
 ExecuteEndRules;
End;

Procedure RunProgram;
Var
 J:Integer;
 Err:Integer;
Begin
 If NumberLine>0Then Begin
  CurrLinePtr:=1;
  While(CurrLinePtr<=NumberLine) do Begin
   CurrLine:=PA[CurrLinePtr]^;
   CurrNumberLine:=0;
   J:=1;
   While(J<Length(CurrLine))do Begin
    If Not(CurrLine[J]in['0'..'9'])Then Begin
     Val(Copy(CurrLine,1,J-1),CurrNumberLine,Err);
     Break;
    End;
    Inc(J);
   End;
   While J<=Length(CurrLine)do Begin
    If CurrLine[J]in[' ',#9]Then Inc(J)
                            Else Break;
   End;
   CurrPos:=J;
   If Not RunLine Then Break;
   Inc(CurrLinePtr);
  End;
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('AWK : Cette commande permet de lancer le langage de programmation AWK.');
  WriteLn;
  WriteLn('Syntaxe : AWK [-f nomfichier] [fichier_donnees]');
  WriteLn;
  WriteLn(' -f   Ce parametre permet d''indiquer un fichier de code source AWK');
  WriteLn(' fichier_donnees   Fichier de donnees a traiter avec les regles AWK');
 End
  Else
 If ParamCount>=1Then Begin
  NumberLine:=0;CurrNumberLine:=0;
  Mode:=_None_;FileName:='';
  CurrCommand:='';
  AccoladeBlock:=0;
  InitRules;
  For I:=1 to RawParamCount do Begin
   CurrParam:=RawParamStr(I);
   If Mode=_InStringSimpleQuote Then Begin
    If CurrParam[Length(CurrParam)]=''''Then Begin
     CurrCommand:=CurrCommand+' '+Copy(CurrParam,1,Length(CurrParam)-1);
     Mode:=_None_;
    End
     Else
    CurrCommand:=CurrCommand+' '+CurrParam;
   End
    Else
   If Mode=_F Then Begin
    FileName:=CurrParam;
    Mode:=_None_;
   End
    Else
   If(Copy(CurrParam,1,1)='''')and(CurrParam[Length(CurrParam)]='''')Then Begin
    CurrCommand:=Copy(CurrParam,2,Length(CurrParam)-2);
   End
    Else
   If CurrParam='-f'Then Mode:=_F Else
   If(Copy(CurrParam,1,1)='''')Then Begin
    Mode:=_InStringSimpleQuote;
    CurrCommand:=Copy(CurrParam,2,Length(CurrParam)-1);
   End
    Else
   Begin
    { C'est peut-etre un fichier de donnees }
    If(FileName<>'')and(Not HasInputFile)Then Begin
     InputFileName:=CurrParam;
     HasInputFile:=True;
    End
     Else
    If FileName=''Then Begin
     { Premier parametre non reconnu - peut-etre un fichier AWK sans -f }
     FileName:=CurrParam;
    End
     Else
    Begin
     WriteLn('Parametre non reconnu: ',CurrParam);
     Halt(1);
    End;
   End;
  End;
  If CurrCommand<>''Then Begin
   CurrLine:=CurrCommand;
   CurrPos:=1;
   RunLine;
  End;
  If FileName<>''Then Begin
   {$I-}Assign(FileAWK,FileName);
   Reset(FileAWK);{$I+}
   If IoResult<>0Then Begin
    WriteLn('Fichier introuvable');
    Exit;
   End;
   While Not EOF(FileAWK) do Begin
    ReadLn(FileAWK,CurrLine);
    If Not AddLine(CurrLine)Then Begin
     WriteLn('Manque de memoire');
     Break;
    End;
   End;
   Close(FileAWK);
   
   { Parser les regles du programme AWK }
   ParseRulesFromProgram;
   
   { Si des regles ont ete trouvees, les executer avec les donnees }
   If RuleCount>0 Then Begin
    ProcessInputWithRules;
   End
    Else
   Begin
    { Pas de regles detectees, executer normalement }
    RunProgram;
   End;
  End;
 End;
END.
