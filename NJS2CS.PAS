{ @author: Sylvain Maltais (support@gladir.com)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Node.js
                (JavaScript) vers le langage C# (.cs).

  Source : Node.js / JavaScript (ES6+).
  Cible  : code source C# (.NET / Mono).

  Sous-ensemble pris en charge :
    require('module')   -> using mappes (fs/path -> System.IO, http -> ...),
    var, let, const     -> var (avec dynamic au besoin),
    function NAME(...)  -> dynamic NAME(dynamic ...) (fonction locale),
    fonctions flechees  -> (=> conserve),
    class/extends/super, constructor, this, new, instanceof,
    if/else, while, do/while, for, for...of, for...in,
    switch/case/default, break/continue/return,
    try/catch/finally, throw,
    template literals `...$(x)...` (avec $ accolade) -> $"...(x)...",
    chaines simples 'x' et doubles "x" -> "x",
    nombres (decimaux, hex 0x, octal 0o, binaire 0b, BigInt 123n -> 123),
    operateurs JS (===, !==, &&, ||, ??, ?., **, etc.).

  Mappages principaux :
    console.log     -> Console.WriteLine
    console.error   -> Console.Error.WriteLine
    console.warn    -> Console.Error.WriteLine
    console.info    -> Console.WriteLine
    process.argv    -> Environment.GetCommandLineArgs()
    process.exit    -> Environment.Exit
    parseInt(x)     -> int.Parse(Convert.ToString(x))
    parseFloat(x)   -> double.Parse(Convert.ToString(x))
    Number(x)       -> Convert.ToDouble(x)
    String(x)       -> Convert.ToString(x)
    Math.X          -> Math.X (compatible)
    Array.isArray(x)-> (x is System.Collections.IList)
    JSON.stringify  -> Convert.ToString
    var/let/const   -> var (dynamic pour parametres et champs)
    function        -> dynamic (declaration de fonction locale)
    extends         -> :          implements -> ,
    super           -> base       instanceof -> is
    ===             -> ==         !==        -> !=
    typeof X        -> /* typeof */ X
    for(.. of ..)   -> foreach(.. in ..)
    for(.. in ..)   -> foreach(.. in ..)
    .length         -> .Length    .push(     -> .Add(
    .pop()          -> .Pop_()    .shift()   -> .Shift_()
    .toString()     -> .ToString().toUpperCase()-> .ToUpper()
    .toLowerCase()  -> .ToLower() .startsWith(-> .StartsWith(
    .endsWith(      -> .EndsWith(  .includes( -> .Contains(
    .indexOf(       -> .IndexOf(  .lastIndexOf( -> .LastIndexOf(
    .replace(       -> .Replace(  .split(    -> .Split(
    .trim()         -> .Trim()    .substring(-> .Substring(
    .charAt(        -> .Substring(   (taille fixe 1)
    .slice(         -> .Substring((commente)

  Modules require('xxx') :
    fs / fs/promises -> using System.IO;
    path             -> using System.IO;
    os               -> using System;
    http / https     -> using System.Net.Http;
    url              -> using System;
    crypto           -> using System.Security.Cryptography;
    util             -> using System;
    events           -> using System;
    stream           -> using System.IO;
    child_process    -> using System.Diagnostics;
    querystring      -> using System.Web;

  Limitations :
    - Le transpileur est token-a-token : les semantiques JS dynamiques
      (typeof, prototype, eval, Proxy, ...) ne sont pas reproduites.
    - Les expressions regulieres /.../[flags] ne sont pas detectees ;
      le caractere '/' est toujours interprete comme une division.
    - async/await/yield sont mis en commentaire ; le resultat doit etre
      adapte manuellement vers `Task` / `IEnumerable` C#.
    - Les "destructuring" (accolades = obj) et les spread (...x) sont laisses
      tels quels et necessiteront une revision manuelle.
    - Les modules CommonJS (module.exports / exports.X) sont mis en
      commentaire ; aucune classe ou methode statique n'est generee.

  Compilation : fpc -Mtp NJS2CS.PAS
  Usage       : NJS2CS source.js [destination.cs]
}

Program NJS2CS;

Const
 VERSION    = '1.0';
 MAX_TOK    = 65535;
 MAX_USE    = 64;
 MAX_BRACE  = 256;
 MAX_LINES  = 32767;
 MAX_CLASS  = 64;

Type
 TString = String;
 TTokenKind = (TK_NONE, TK_IDENT, TK_KEYWORD, TK_INT, TK_REAL,
               TK_STRING, TK_TEMPLATE, TK_CHAR, TK_OP, TK_PUNCT, TK_EOF);
 TToken = Record
   Kind : TTokenKind;
   Val  : TString;
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Usings     : Array[1..MAX_USE] of TString;
 UseCount   : Integer;
 InFile     : Text;
 OutFile    : Text;
 SrcName    : TString;
 DstName    : TString;
 Indent     : Integer;
 OutLine    : TString;
 SrcEOF     : Boolean;
 SrcPushed  : Boolean;
 SrcPushCh  : Char;

 { Pile d'accolades : 'C' = corps de classe, 'M' = bloc de methode/code,
   'O' = litteral d'objet (a eviter de reformater).                       }
 BraceStack : Array[1..MAX_BRACE] of Char;
 BraceTop   : Integer;
 ParenStack : Array[1..MAX_BRACE] of Char;   { 'F' for-each, 'N' normal     }
 ParenTop   : Integer;

 InClassHdr : Boolean;
 SeenColonHdr:Boolean;
 AtMemberStart:Boolean;

 { Pile des noms de classes courantes (pour 'constructor' -> nom de classe). }
 ClassStack : Array[1..MAX_CLASS] of TString;
 ClassTop   : Integer;

 { Deux tampons de sortie : MAIN = code dans Main(), CLAS = classes apres
   le code de niveau superieur. La sortie est routee vers l'un des deux.  }
 MainLines  : Array[1..MAX_LINES] of TString;
 MainCount  : Integer;
 ClassLines : Array[1..MAX_LINES] of TString;
 ClassCount : Integer;
 OutTarget  : Char;                         { 'M' ou 'C' }

{ ============================================================
  UTILITAIRES
  ============================================================ }
Function StrLower(S:TString):TString;
Var I:Integer;
Begin
 For I:=1 to Length(S) do If(S[I]>='A')and(S[I]<='Z')Then S[I]:=Chr(Ord(S[I])+32);
 StrLower:=S;
End;

Function IntToStr(N:LongInt):TString;
Var S:TString;
Begin Str(N,S); IntToStr:=S; End;

{ ============================================================
  LEXER
  ============================================================ }
Procedure TokInit;
Begin
 TokCount:=0;
 SrcEOF:=False;
 SrcPushed:=False;
End;

Function NextCh:Char;
Var C:Char;
Begin
 If SrcPushed Then Begin
   SrcPushed:=False; NextCh:=SrcPushCh; Exit;
 End;
 If Eof(InFile) Then Begin SrcEOF:=True; NextCh:=#0; Exit; End;
 If Eoln(InFile) Then Begin ReadLn(InFile); NextCh:=#10; Exit; End;
 Read(InFile,C);
 NextCh:=C;
End;

Procedure UngetCh(Ch:Char);
Begin SrcPushCh:=Ch; SrcPushed:=True; End;

Function PeekCh:Char;
Var C:Char;
Begin C:=NextCh; UngetCh(C); PeekCh:=C; End;

Procedure AddToken(K:TTokenKind; V:TString);
Begin
 If TokCount>=MAX_TOK Then Begin
   WriteLn('Erreur : trop de tokens (>',MAX_TOK,').');
   Halt(1);
 End;
 Inc(TokCount);
 Tokens[TokCount].Kind:=K;
 Tokens[TokCount].Val :=V;
End;

Function IsJsKeyword(S:TString):Boolean;
Begin
 IsJsKeyword:=
  (S='break')or(S='case')or(S='catch')or(S='class')or(S='const')or
  (S='continue')or(S='debugger')or(S='default')or(S='delete')or
  (S='do')or(S='else')or(S='enum')or(S='export')or(S='extends')or
  (S='false')or(S='finally')or(S='for')or(S='function')or(S='if')or
  (S='import')or(S='in')or(S='instanceof')or(S='new')or(S='null')or
  (S='of')or(S='return')or(S='super')or(S='switch')or(S='this')or
  (S='throw')or(S='true')or(S='try')or(S='typeof')or(S='undefined')or
  (S='var')or(S='void')or(S='while')or(S='with')or(S='yield')or
  (S='let')or(S='static')or(S='async')or(S='await')or
  (S='get')or(S='set')or(S='from')or(S='as');
End;

Procedure SkipLineComment;
Var C:Char;
Begin Repeat C:=NextCh; Until SrcEOF or (C=#10); End;

Procedure SkipBlockComment;
Var C:Char;
Begin
 While Not SrcEOF do Begin
   C:=NextCh;
   If SrcEOF Then Exit;
   If C='*' Then If PeekCh='/' Then Begin C:=NextCh; Exit; End;
 End;
End;

{ Lit une chaine simple ou double quote et la stocke comme une chaine
  C# (toujours entre guillemets doubles).                                }
Procedure ScanString(Quote:Char);
Var C:Char; V:TString;
Begin
 V:='"';
 Repeat
   If SrcEOF Then Break;
   C:=NextCh;
   If C=#10 Then Break;
   If C='\' Then Begin
     V:=V+'\';
     If Not SrcEOF Then V:=V+NextCh;
     Continue;
   End;
   If C=Quote Then Break;
   { Quote interne d'un autre type : echapper si c'est un guillemet double
     dans une chaine C#. }
   If (Quote='''') and (C='"') Then Begin V:=V+'\"'; Continue; End;
   V:=V+C;
 Until False;
 V:=V+'"';
 AddToken(TK_STRING,V);
End;

(* Lit un template literal `...$ accollade...accollade...` et le convertit en chaine
   interpolee C# $"..." . Les expressions sont copiees telles quelles ; les
   caracteres accolade sont doubles dans les parties litterales pour les
   echapper en C#.                                                         *)
Procedure ScanTemplate;
Var C:Char; V:TString; Depth:Integer;
Begin
 V:='$"';
 While Not SrcEOF do Begin
   C:=NextCh;
   If SrcEOF Then Break;
   If C='`' Then Break;
   If C='\' Then Begin
     V:=V+'\';
     If Not SrcEOF Then V:=V+NextCh;
     Continue;
   End;
   If C='"' Then Begin V:=V+'\"'; Continue; End;
   If C='{' Then Begin V:=V+'{{'; Continue; End;
   If C='}' Then Begin V:=V+'}}'; Continue; End;
   If C='$' Then Begin
     If PeekCh='{' Then Begin
       C:=NextCh;             { consomme ouvre accolade }
       V:=V+'{';
       Depth:=1;
       While Not SrcEOF and (Depth>0) do Begin
         C:=NextCh;
         If SrcEOF Then Break;
         If C='{' Then Begin Inc(Depth); V:=V+C; Continue; End;
         If C='}' Then Begin
           Dec(Depth);
           If Depth=0 Then Begin V:=V+'}'; Break; End;
           V:=V+C; Continue;
         End;
         V:=V+C;
       End;
       Continue;
     End;
     V:=V+C;
     Continue;
   End;
   V:=V+C;
 End;
 V:=V+'"';
 AddToken(TK_TEMPLATE,V);
End;

Procedure ScanNumber(First:Char);
Var V:TString; IsReal:Boolean;
Begin
 V:=First;
 IsReal:=False;
 If First='0' Then Begin
   If (PeekCh='x')or(PeekCh='X') Then Begin
     V:=V+NextCh;
     While PeekCh in ['0'..'9','A'..'F','a'..'f','_'] do V:=V+NextCh;
     If PeekCh='n' Then NextCh;     { BigInt suffix supprime }
     AddToken(TK_INT,V); Exit;
   End;
   If (PeekCh='b')or(PeekCh='B') Then Begin
     V:=V+NextCh;
     While PeekCh in ['0','1','_'] do V:=V+NextCh;
     If PeekCh='n' Then NextCh;
     AddToken(TK_INT,V); Exit;
   End;
   If (PeekCh='o')or(PeekCh='O') Then Begin
     { 0o755 -> on retire le prefixe et on emet en decimal litteral hex }
     NextCh;
     V:='0';
     While PeekCh in ['0'..'7','_'] do V:=V+NextCh;
     If PeekCh='n' Then NextCh;
     AddToken(TK_INT,V); Exit;
   End;
 End;
 While PeekCh in ['0'..'9','_'] do V:=V+NextCh;
 If PeekCh='.' Then Begin
   V:=V+NextCh; IsReal:=True;
   While PeekCh in ['0'..'9','_'] do V:=V+NextCh;
 End;
 If (PeekCh='e')or(PeekCh='E') Then Begin
   V:=V+NextCh; IsReal:=True;
   If (PeekCh='+')or(PeekCh='-') Then V:=V+NextCh;
   While PeekCh in ['0'..'9','_'] do V:=V+NextCh;
 End;
 If PeekCh='n' Then NextCh;        { BigInt suffix }
 If IsReal Then AddToken(TK_REAL,V) Else AddToken(TK_INT,V);
End;

Procedure ScanIdent(First:Char);
Var V:TString;
Begin
 V:=First;
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_','$'] do V:=V+NextCh;
 If IsJsKeyword(V) Then AddToken(TK_KEYWORD,V) Else AddToken(TK_IDENT,V);
End;

Procedure Tokenize;
Var C,N:Char;
Begin
 While Not SrcEOF do Begin
   C:=NextCh;
   If SrcEOF Then Break;
   Case C of
    ' ',#9,#10,#13: ;
    '/':Begin
       N:=PeekCh;
       If N='/' Then Begin C:=NextCh; SkipLineComment; End
       Else If N='*' Then Begin C:=NextCh; SkipBlockComment; End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'/='); End
       Else AddToken(TK_OP,'/');
    End;
    '"':ScanString('"');
    '''':ScanString('''');
    '`':ScanTemplate;
    '0'..'9':ScanNumber(C);
    'A'..'Z','a'..'z','_','$':ScanIdent(C);
    '+':Begin
       N:=PeekCh;
       If N='+' Then Begin C:=NextCh; AddToken(TK_OP,'++'); End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'+='); End
       Else AddToken(TK_OP,'+');
    End;
    '-':Begin
       N:=PeekCh;
       If N='-' Then Begin C:=NextCh; AddToken(TK_OP,'--'); End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'-='); End
       Else AddToken(TK_OP,'-');
    End;
    '*':Begin
       N:=PeekCh;
       If N='*' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'**='); End
         Else AddToken(TK_OP,'**');
       End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'*='); End
       Else AddToken(TK_OP,'*');
    End;
    '%':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'%='); End
       Else AddToken(TK_OP,'%');
    End;
    '=':Begin
       If PeekCh='=' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'==='); End
         Else AddToken(TK_OP,'==');
       End
       Else If PeekCh='>' Then Begin C:=NextCh; AddToken(TK_OP,'=>'); End
       Else AddToken(TK_OP,'=');
    End;
    '!':Begin
       If PeekCh='=' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'!=='); End
         Else AddToken(TK_OP,'!=');
       End
       Else AddToken(TK_OP,'!');
    End;
    '<':Begin
       N:=PeekCh;
       If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'<='); End
       Else If N='<' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'<<='); End
         Else AddToken(TK_OP,'<<');
       End
       Else AddToken(TK_OP,'<');
    End;
    '>':Begin
       N:=PeekCh;
       If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'>='); End
       Else If N='>' Then Begin
         C:=NextCh;
         If PeekCh='>' Then Begin
           C:=NextCh;
           If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'>>>='); End
           Else AddToken(TK_OP,'>>>');
         End
         Else If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'>>='); End
         Else AddToken(TK_OP,'>>');
       End
       Else AddToken(TK_OP,'>');
    End;
    '&':Begin
       N:=PeekCh;
       If N='&' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'&&='); End
         Else AddToken(TK_OP,'&&');
       End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'&='); End
       Else AddToken(TK_OP,'&');
    End;
    '|':Begin
       N:=PeekCh;
       If N='|' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'||='); End
         Else AddToken(TK_OP,'||');
       End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'|='); End
       Else AddToken(TK_OP,'|');
    End;
    '^':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'^='); End
       Else AddToken(TK_OP,'^');
    End;
    '~':AddToken(TK_OP,'~');
    '?':Begin
       N:=PeekCh;
       If N='?' Then Begin
         C:=NextCh;
         If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'??='); End
         Else AddToken(TK_OP,'??');
       End
       Else If N='.' Then Begin C:=NextCh; AddToken(TK_OP,'?.'); End
       Else AddToken(TK_OP,'?');
    End;
    ':':AddToken(TK_PUNCT,':');
    '(':AddToken(TK_PUNCT,'(');
    ')':AddToken(TK_PUNCT,')');
    ',':AddToken(TK_PUNCT,',');
    ';':AddToken(TK_PUNCT,';');
    '[':AddToken(TK_PUNCT,'[');
    ']':AddToken(TK_PUNCT,']');
    '{':AddToken(TK_PUNCT,'{');
    '}':AddToken(TK_PUNCT,'}');
    '.':Begin
       If PeekCh='.' Then Begin
         C:=NextCh;
         If PeekCh='.' Then Begin C:=NextCh; AddToken(TK_OP,'...'); End
         Else AddToken(TK_PUNCT,'.');
       End
       Else AddToken(TK_PUNCT,'.');
    End;
   End;
 End;
 AddToken(TK_EOF,'');
End;

{ ============================================================
  MAPPAGES
  ============================================================ }
Function MapJsMethod(S:TString):TString;
Begin
 If S='toString'    Then MapJsMethod:='ToString' Else
 If S='toUpperCase' Then MapJsMethod:='ToUpper' Else
 If S='toLowerCase' Then MapJsMethod:='ToLower' Else
 If S='startsWith'  Then MapJsMethod:='StartsWith' Else
 If S='endsWith'    Then MapJsMethod:='EndsWith' Else
 If S='includes'    Then MapJsMethod:='Contains' Else
 If S='indexOf'     Then MapJsMethod:='IndexOf' Else
 If S='lastIndexOf' Then MapJsMethod:='LastIndexOf' Else
 If S='replace'     Then MapJsMethod:='Replace' Else
 If S='replaceAll'  Then MapJsMethod:='Replace' Else
 If S='split'       Then MapJsMethod:='Split' Else
 If S='trim'        Then MapJsMethod:='Trim' Else
 If S='trimStart'   Then MapJsMethod:='TrimStart' Else
 If S='trimEnd'     Then MapJsMethod:='TrimEnd' Else
 If S='substring'   Then MapJsMethod:='Substring' Else
 If S='substr'      Then MapJsMethod:='Substring' Else
 If S='concat'      Then MapJsMethod:='Concat' Else
 If S='push'        Then MapJsMethod:='Add' Else
 If S='sort'        Then MapJsMethod:='Sort' Else
 If S='reverse'     Then MapJsMethod:='Reverse' Else
 If S='forEach'     Then MapJsMethod:='ForEach' Else
 If S='join'        Then MapJsMethod:='Join_' Else
                          MapJsMethod:='';
End;

{ Mappage des methodes JS Math.* vers C# Math.*. Ces mappages ne sont
  appliques que lorsque l'objet recepteur est l'identifiant 'Math'.       }
Function MapJsMathMethod(S:TString):TString;
Begin
 If S='abs'    Then MapJsMathMethod:='Abs' Else
 If S='pow'    Then MapJsMathMethod:='Pow' Else
 If S='sqrt'   Then MapJsMathMethod:='Sqrt' Else
 If S='cbrt'   Then MapJsMathMethod:='Cbrt' Else
 If S='max'    Then MapJsMathMethod:='Max' Else
 If S='min'    Then MapJsMathMethod:='Min' Else
 If S='floor'  Then MapJsMathMethod:='Floor' Else
 If S='ceil'   Then MapJsMathMethod:='Ceiling' Else
 If S='round'  Then MapJsMathMethod:='Round' Else
 If S='sign'   Then MapJsMathMethod:='Sign' Else
 If S='log'    Then MapJsMathMethod:='Log' Else
 If S='log2'   Then MapJsMathMethod:='Log2' Else
 If S='log10'  Then MapJsMathMethod:='Log10' Else
 If S='exp'    Then MapJsMathMethod:='Exp' Else
 If S='sin'    Then MapJsMathMethod:='Sin' Else
 If S='cos'    Then MapJsMathMethod:='Cos' Else
 If S='tan'    Then MapJsMathMethod:='Tan' Else
 If S='asin'   Then MapJsMathMethod:='Asin' Else
 If S='acos'   Then MapJsMathMethod:='Acos' Else
 If S='atan'   Then MapJsMathMethod:='Atan' Else
 If S='atan2'  Then MapJsMathMethod:='Atan2' Else
 If S='trunc'  Then MapJsMathMethod:='Truncate' Else
 If S='random' Then MapJsMathMethod:='Random_' Else { gestion speciale : new Random().NextDouble() }
                     MapJsMathMethod:='';
End;

Procedure AddUsing(S:TString);
Var I:Integer;
Begin
 If S='' Then Exit;
 For I:=1 to UseCount do If Usings[I]=S Then Exit;
 If UseCount>=MAX_USE Then Exit;
 Inc(UseCount);
 Usings[UseCount]:=S;
End;

Function MapRequireModule(M:TString):TString;
Begin
 { Retire d'eventuels guillemets autour de M. }
 If (Length(M)>=2)and((M[1]='"')or(M[1]=''''))Then
   M:=Copy(M,2,Length(M)-2);
 If (M='fs')or(M='fs/promises')or(M='path')or(M='stream') Then
   MapRequireModule:='System.IO' Else
 If (M='http')or(M='https') Then
   MapRequireModule:='System.Net.Http' Else
 If (M='crypto') Then
   MapRequireModule:='System.Security.Cryptography' Else
 If (M='child_process') Then
   MapRequireModule:='System.Diagnostics' Else
 If (M='querystring') Then
   MapRequireModule:='System.Web' Else
 If (M='os')or(M='url')or(M='util')or(M='events')or(M='buffer') Then
   MapRequireModule:='System' Else
   MapRequireModule:='';
End;

{ ============================================================
  EMISSION : tampons MAIN / CLAS
  ============================================================ }
Procedure FlushLine;
Var L:TString;
Begin
 If Length(OutLine)=0 Then Exit;
 L:=OutLine;
 OutLine:='';
 If OutTarget='C' Then Begin
   If ClassCount<MAX_LINES Then Begin
     Inc(ClassCount); ClassLines[ClassCount]:=L;
   End;
 End Else Begin
   If MainCount<MAX_LINES Then Begin
     Inc(MainCount); MainLines[MainCount]:=L;
   End;
 End;
End;

Procedure WriteIndent;
Var I:Integer;
Begin For I:=1 to Indent*4 do OutLine:=OutLine+' '; End;

Procedure EmitRaw(S:TString);
Var I:Integer;
Begin
 For I:=1 to Length(S) do Begin
   If S[I]=#10 Then Begin
     If OutTarget='C' Then Begin
       If ClassCount<MAX_LINES Then Begin
         Inc(ClassCount); ClassLines[ClassCount]:=OutLine;
       End;
     End Else Begin
       If MainCount<MAX_LINES Then Begin
         Inc(MainCount); MainLines[MainCount]:=OutLine;
       End;
     End;
     OutLine:='';
   End Else Begin
     If (Length(OutLine)=0) and (S[I]<>' ') Then WriteIndent;
     OutLine:=OutLine+S[I];
   End;
 End;
End;

Procedure EmitLn; Begin EmitRaw(#10); End;

Function LastChar(S:TString):Char;
Begin
 If Length(S)=0 Then LastChar:=#0 Else LastChar:=S[Length(S)];
End;

Procedure EmitSepSpace;
Var C:Char;
Begin
 C:=LastChar(OutLine);
 If (C=#0)or(C=' ')or(C='(')or(C='[')or(C='{')or(C='.') Then Exit;
 EmitRaw(' ');
End;

{ ============================================================
  PILES
  ============================================================ }
Procedure PushBrace(Kind:Char);
Begin
 If BraceTop<MAX_BRACE Then Begin Inc(BraceTop); BraceStack[BraceTop]:=Kind; End;
End;

Procedure PopBrace;
Begin If BraceTop>0 Then Dec(BraceTop); End;

Function TopBrace:Char;
Begin
 If BraceTop=0 Then TopBrace:='G'
 Else TopBrace:=BraceStack[BraceTop];
End;

Procedure PushParen(Kind:Char);
Begin
 If ParenTop<MAX_BRACE Then Begin Inc(ParenTop); ParenStack[ParenTop]:=Kind; End;
End;

Procedure PopParen;
Begin If ParenTop>0 Then Dec(ParenTop); End;

Function TopParen:Char;
Begin If ParenTop=0 Then TopParen:=' ' Else TopParen:=ParenStack[ParenTop]; End;

Procedure PushClass(N:TString);
Begin
 If ClassTop<MAX_CLASS Then Begin Inc(ClassTop); ClassStack[ClassTop]:=N; End;
End;

Procedure PopClass;
Begin If ClassTop>0 Then Dec(ClassTop); End;

Function TopClass:TString;
Begin
 If ClassTop=0 Then TopClass:='' Else TopClass:=ClassStack[ClassTop];
End;

{ ============================================================
  ANALYSE : require -> using
  ============================================================ }
Procedure AnalyzeRequires;
Var I:Integer; U:TString;
Begin
 UseCount:=0;
 I:=1;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_IDENT)and(Tokens[I].Val='require') and
      (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') and
      (I+2<=TokCount)and(Tokens[I+2].Kind=TK_STRING) Then Begin
     U:=MapRequireModule(Tokens[I+2].Val);
     If U<>'' Then AddUsing(U);
     Inc(I,3); Continue;
   End;
   Inc(I);
 End;
End;

{ ============================================================
  DETECTIONS CONTEXTUELLES
  ============================================================ }

{ Determine si la parenthese qui s'ouvre apres 'for' est un for-of/for-in. }
Function ForIsForEach(I:Integer):Boolean;
Var J,Depth:Integer;
Begin
 ForIsForEach:=False;
 J:=I+1;                       { I pointe sur '(' }
 Depth:=1;
 While (J<=TokCount) and (Depth>0) do Begin
   If Tokens[J].Kind=TK_PUNCT Then Begin
     If (Tokens[J].Val='(')or(Tokens[J].Val='[')or(Tokens[J].Val='{') Then Inc(Depth)
     Else If (Tokens[J].Val=')')or(Tokens[J].Val=']')or(Tokens[J].Val='}') Then Begin
       Dec(Depth);
       If Depth=0 Then Exit;
     End
     Else If (Depth=1) Then Begin
       If Tokens[J].Val=';' Then Exit;
     End;
   End;
   If (Depth=1)and(Tokens[J].Kind=TK_KEYWORD) and
      ((Tokens[J].Val='of')or(Tokens[J].Val='in')) Then Begin
     ForIsForEach:=True; Exit;
   End;
   Inc(J);
 End;
End;

{ ============================================================
  HANDLERS : console.X / process.X / require / typeof
  ============================================================ }

Function TryEmitConsole(Var I:Integer):Boolean;
Var J:Integer; Method:TString;
Begin
 TryEmitConsole:=False;
 If (Tokens[I].Kind<>TK_IDENT)or(Tokens[I].Val<>'console') Then Exit;
 If (I>1)and(Tokens[I-1].Kind=TK_PUNCT)and(Tokens[I-1].Val='.') Then Exit;
 J:=I+1;
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')) Then Exit;
 Inc(J);
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_IDENT)) Then Exit;
 Method:=Tokens[J].Val;
 If (Method='log')or(Method='info')or(Method='debug') Then EmitRaw('Console.WriteLine')
 Else If (Method='error')or(Method='warn') Then EmitRaw('Console.Error.WriteLine')
 Else Exit;
 I:=J+1;
 TryEmitConsole:=True;
End;

Function TryEmitProcess(Var I:Integer):Boolean;
Var J:Integer; Method:TString;
Begin
 TryEmitProcess:=False;
 If (Tokens[I].Kind<>TK_IDENT)or(Tokens[I].Val<>'process') Then Exit;
 If (I>1)and(Tokens[I-1].Kind=TK_PUNCT)and(Tokens[I-1].Val='.') Then Exit;
 J:=I+1;
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')) Then Exit;
 Inc(J);
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_IDENT)) Then Exit;
 Method:=Tokens[J].Val;
 If Method='argv' Then EmitRaw('Environment.GetCommandLineArgs()')
 Else If Method='exit' Then EmitRaw('Environment.Exit')
 Else If Method='cwd' Then EmitRaw('System.IO.Directory.GetCurrentDirectory')
 Else If Method='platform' Then EmitRaw('Environment.OSVersion.Platform.ToString()')
 Else Exit;
 I:=J+1;
 TryEmitProcess:=True;
End;

{ require('xxx') -> /* require(...) */ null }
Function TryEmitRequire(Var I:Integer):Boolean;
Begin
 TryEmitRequire:=False;
 If (Tokens[I].Kind<>TK_IDENT)or(Tokens[I].Val<>'require') Then Exit;
 If (I+3<=TokCount) and (Tokens[I+1].Kind=TK_PUNCT) and (Tokens[I+1].Val='(') and
    (Tokens[I+2].Kind=TK_STRING) and (Tokens[I+3].Kind=TK_PUNCT) and
    (Tokens[I+3].Val=')') Then Begin
   EmitRaw('/* require('); EmitRaw(Tokens[I+2].Val); EmitRaw(') */ null');
   I:=I+4;
   TryEmitRequire:=True;
 End;
End;

{ Si I pointe sur '.' length, emet '.Length' et avance.                   }
Function TryEmitDotLength(Var I:Integer):Boolean;
Begin
 TryEmitDotLength:=False;
 If Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')) Then Exit;
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)and(Tokens[I+1].Val='length')) Then Exit;
 EmitRaw('.Length');
 I:=I+2;
 TryEmitDotLength:=True;
End;

{ Si I pointe sur '.' nomMethode connu, emet '.Equiv' et laisse I sur '('. }
Function TryEmitDotMethod(Var I:Integer):Boolean;
Var Eq:TString;
Begin
 TryEmitDotMethod:=False;
 If Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')) Then Exit;
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)) Then Exit;
 Eq:='';
 { Cas Math.X : appliquer un mappage specialise. }
 If (I-1>=1)and(Tokens[I-1].Kind=TK_IDENT)and(Tokens[I-1].Val='Math') Then
   Eq:=MapJsMathMethod(Tokens[I+1].Val);
 If Eq='' Then Eq:=MapJsMethod(Tokens[I+1].Val);
 If Eq='' Then Exit;
 If (Eq='Join_')or(Eq='Random_') Then Exit; { conserve : signature differente }
 EmitRaw('.');
 EmitRaw(Eq);
 I:=I+2;
 TryEmitDotMethod:=True;
End;

{ ============================================================
  MEMBRE DE CLASSE : detection
  ============================================================ }

{ Quand AtMemberStart=True a l'entree d'un membre de classe, on doit
  determiner s'il s'agit d'une methode/constructeur/getter ou d'un champ.
  La fonction emet les modificateurs et avance I si elle reconnait un
  membre. Renvoie True si elle a emis quelque chose.                       }
Procedure EmitTypedParamList(Var I:Integer); Forward;

Function HandleClassMember(Var I:Integer):Boolean;
Var
 J:Integer;
 IsStatic, IsGet, IsSet, IsAsync:Boolean;
 Name:TString;
 ClsName:TString;
Begin
 HandleClassMember:=False;
 If TopBrace<>'C' Then Exit;
 If Not AtMemberStart Then Exit;

 J:=I;
 IsStatic:=False; IsGet:=False; IsSet:=False; IsAsync:=False;

 { Sauter modificateurs : static, async, get, set }
 While J<=TokCount do Begin
   If Tokens[J].Kind=TK_KEYWORD Then Begin
     If Tokens[J].Val='static' Then Begin IsStatic:=True; Inc(J); Continue; End;
     If Tokens[J].Val='async'  Then Begin IsAsync:=True;  Inc(J); Continue; End;
     If Tokens[J].Val='get'    Then Begin IsGet:=True;    Inc(J); Continue; End;
     If Tokens[J].Val='set'    Then Begin IsSet:=True;    Inc(J); Continue; End;
   End;
   Break;
 End;

 If J>TokCount Then Exit;

 { Le nom du membre : un IDENT (ou 'constructor' qui est aussi un IDENT). }
 If Tokens[J].Kind<>TK_IDENT Then Exit;
 Name:=Tokens[J].Val;

 { Apres le nom : '(' = methode, autre = champ. }
 If (J+1<=TokCount) and (Tokens[J+1].Kind=TK_PUNCT) and (Tokens[J+1].Val='(') Then Begin
   { methode (ou constructor) }
   If Name='constructor' Then Begin
     ClsName:=TopClass;
     If ClsName='' Then ClsName:='Ctor';
     EmitRaw('public ');
     EmitRaw(ClsName);
   End Else Begin
     EmitRaw('public ');
     If IsStatic Then EmitRaw('static ');
     If IsAsync Then EmitRaw('/* async */ ');
     EmitRaw('dynamic ');
     EmitRaw(Name);
   End;
   I:=J+1;
   AtMemberStart:=False;
   { Emettre la liste de parametres avec types dynamiques. }
   EmitTypedParamList(I);
   HandleClassMember:=True;
   Exit;
 End;

 { champ : on emet 'public dynamic NAME' et le reste sera traite normalement. }
 EmitRaw('public ');
 If IsStatic Then EmitRaw('static ');
 EmitRaw('dynamic ');
 EmitRaw(Name);
 I:=J+1;
 AtMemberStart:=False;
 HandleClassMember:=True;
End;

{ Emet une liste de parametres typee a partir de I qui pointe sur '('.
  Avance I jusqu'apres le ')' correspondant. Insere 'dynamic ' devant
  chaque nom de parametre. Gere les '...' (params), les valeurs par
  defaut (=) et les paires nom=valeur.                                   }
Procedure EmitTypedParamList(Var I:Integer);
Var NeedParam:Boolean;
Begin
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')) Then Exit;
 EmitRaw('(');
 PushParen('P');
 Inc(I);
 NeedParam:=True;
 While (I<=TokCount) and (TopParen='P') do Begin
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
     PopParen; EmitRaw(')'); Inc(I); Break;
   End;
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
     EmitRaw(', '); NeedParam:=True; Inc(I); Continue;
   End;
   If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
     EmitRaw(' = '); NeedParam:=False; Inc(I); Continue;
   End;
   If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='...') Then Begin
     EmitRaw('params dynamic[] '); NeedParam:=False; Inc(I); Continue;
   End;
   If (Tokens[I].Kind=TK_IDENT) and NeedParam Then Begin
     EmitRaw('dynamic '); EmitRaw(Tokens[I].Val); NeedParam:=False;
     Inc(I); Continue;
   End;
   EmitRaw(Tokens[I].Val);
   Inc(I);
 End;
End;

{ ============================================================
  EMISSION : boucle principale
  ============================================================ }
Procedure EmitTokens(StartIdx:Integer);
Var
 I:Integer;
 V,K,Mapped:TString;
 ForEachOpen:Boolean;
 ParenK:Char;
 NextTok:Integer;
 Saved:Integer;
 ClsName:TString;
Begin
 I:=StartIdx;
 BraceTop:=0;
 ParenTop:=0;
 InClassHdr:=False;
 SeenColonHdr:=False;
 AtMemberStart:=False;

 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_EOF Then Break;

   { Membre de classe : detection prioritaire. }
   If HandleClassMember(I) Then Continue;

   { console.X(...) / process.X / require('mod')                          }
   If TryEmitConsole(I) Then Continue;
   If TryEmitProcess(I) Then Continue;
   If TryEmitRequire(I) Then Continue;

   { Acces .length / methode .X .                                         }
   If TryEmitDotLength(I) Then Continue;
   If TryEmitDotMethod(I) Then Continue;

   Case Tokens[I].Kind of
     TK_KEYWORD:Begin
       K:=Tokens[I].Val;
       If (K='var')or(K='let') Then Begin EmitSepSpace; EmitRaw('var'); Inc(I); End Else
       If K='const' Then Begin
         { Au niveau d'un membre de classe, const n'a pas de sens : sauter. }
         If TopBrace='C' Then Inc(I)
         Else Begin EmitSepSpace; EmitRaw('var'); Inc(I); End;
       End Else
       If K='function' Then Begin
         (* function NAME(args) (block) -> dynamic NAME(dynamic args ...) (block)
            function (args) (block)     -> delegate ... ; on emet "delegate"  *)
         Inc(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
           EmitSepSpace; EmitRaw('dynamic '); EmitRaw(Tokens[I].Val); Inc(I);
         End Else Begin
           EmitSepSpace; EmitRaw('delegate');
         End;
         EmitTypedParamList(I);
       End Else
       If K='extends' Then Begin
         If InClassHdr Then Begin
           If Not SeenColonHdr Then Begin EmitRaw(' :'); SeenColonHdr:=True; End
           Else EmitRaw(',');
           Inc(I);
         End Else Begin EmitRaw(' /* extends */ '); Inc(I); End;
       End Else
       If K='instanceof' Then Begin EmitSepSpace; EmitRaw('is'); Inc(I); End Else
       If K='super' Then Begin EmitSepSpace; EmitRaw('base'); Inc(I); End Else
       If K='class' Then Begin
         { Forcer la sortie de toute classe vers le tampon CLAS si on est
           au niveau global. Sauvegarder le precedent OutTarget. }
         FlushLine;
         If TopBrace='G' Then OutTarget:='C';
         EmitSepSpace;
         EmitRaw('public class');
         InClassHdr:=True;
         SeenColonHdr:=False;
         Inc(I);
         { Capturer le nom de la classe pour le constructor. }
         If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
           ClsName:=Tokens[I].Val;
           PushClass(ClsName);
           EmitRaw(' '); EmitRaw(ClsName);
           Inc(I);
         End Else PushClass('Anon');
       End Else
       If K='for' Then Begin
         EmitSepSpace;
         ForEachOpen:=False;
         If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') Then
           ForEachOpen:=ForIsForEach(I+1);
         If ForEachOpen Then EmitRaw('foreach') Else EmitRaw('for');
         Inc(I);
       End Else
       If K='of' Then Begin
         { Apparait dans for-of, devient 'in' en C#. }
         If TopParen='F' Then EmitRaw(' in ')
         Else Begin EmitSepSpace; EmitRaw('/* of */'); End;
         Inc(I);
       End Else
       If K='in' Then Begin
         If TopParen='F' Then EmitRaw(' in ')
         Else Begin EmitSepSpace; EmitRaw('in'); EmitRaw(' '); End;
         Inc(I);
       End Else
       If K='typeof' Then Begin
         EmitSepSpace; EmitRaw('/* typeof */ '); Inc(I);
       End Else
       If K='delete' Then Begin
         EmitSepSpace; EmitRaw('/* delete */ '); Inc(I);
       End Else
       If K='void' Then Begin
         EmitSepSpace; EmitRaw('/* void */ '); Inc(I);
       End Else
       If K='async' Then Begin
         EmitSepSpace; EmitRaw('/* async */ '); Inc(I);
       End Else
       If K='await' Then Begin
         EmitSepSpace; EmitRaw('/* await */ '); Inc(I);
       End Else
       If K='yield' Then Begin
         EmitSepSpace; EmitRaw('/* yield */ '); Inc(I);
       End Else
       If K='undefined' Then Begin EmitSepSpace; EmitRaw('null'); Inc(I); End Else
       If (K='true')or(K='false')or(K='null') Then Begin
         EmitSepSpace; EmitRaw(K); Inc(I);
       End Else
       If (K='import')or(K='export') Then Begin
         { Mettre toute l'instruction en commentaire jusqu'au ';' ou EOL. }
         EmitSepSpace; EmitRaw('/* '); EmitRaw(K);
         Inc(I);
         While (I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) and
               (Tokens[I].Kind<>TK_EOF) do Begin
           EmitRaw(' '); EmitRaw(Tokens[I].Val); Inc(I);
         End;
         EmitRaw(' */');
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
         EmitLn;
         If I<=TokCount Then If Tokens[I].Kind<>TK_EOF Then WriteIndent;
       End Else
       Begin
         { mots-cles communs : if, else, while, do, switch, case, default,
           return, break, continue, throw, try, catch, finally, new, this,
           static, debugger, ... }
         If K='debugger' Then Begin
           EmitSepSpace; EmitRaw('/* debugger */'); Inc(I);
         End Else Begin
           EmitSepSpace; EmitRaw(K); Inc(I);
         End;
       End;
     End;
     TK_IDENT:Begin
       EmitSepSpace;
       EmitRaw(Tokens[I].Val);
       Inc(I);
     End;
     TK_INT:Begin
       EmitSepSpace; EmitRaw(Tokens[I].Val); Inc(I);
     End;
     TK_REAL:Begin
       EmitSepSpace; EmitRaw(Tokens[I].Val); Inc(I);
     End;
     TK_STRING:Begin
       EmitSepSpace; EmitRaw(Tokens[I].Val); Inc(I);
     End;
     TK_TEMPLATE:Begin
       EmitSepSpace; EmitRaw(Tokens[I].Val); Inc(I);
     End;
     TK_CHAR:Begin
       EmitSepSpace; EmitRaw(Tokens[I].Val); Inc(I);
     End;
     TK_OP:Begin
       V:=Tokens[I].Val;
       Mapped:=V;
       If V='===' Then Mapped:='==';
       If V='!==' Then Mapped:='!=';
       If V='??'  Then Mapped:='??';
       If V='?.'  Then Mapped:='?.';
       If V='...' Then Mapped:='/* ... */';
       If (V='**')or(V='**=') Then Mapped:='/* ** */';
       If (V='=')or(V='==')or(V='===')or(V='!=')or(V='!==')or
          (V='<')or(V='>')or(V='<=')or(V='>=')or
          (V='+=')or(V='-=')or(V='*=')or(V='/=')or(V='%=')or
          (V='&=')or(V='|=')or(V='^=')or(V='<<=')or(V='>>=')or(V='>>>=')or
          (V='&&')or(V='||')or(V='??')or(V='&&=')or(V='||=')or(V='??=')or
          (V='=>') Then Begin
         EmitSepSpace;
         If V='===' Then EmitRaw('==')
         Else If V='!==' Then EmitRaw('!=')
         Else EmitRaw(Mapped);
         EmitRaw(' ');
       End Else
       If (V='+')or(V='-')or(V='*')or(V='/')or(V='%')or
          (V='&')or(V='|')or(V='^')or(V='<<')or(V='>>')or(V='>>>') Then Begin
         EmitRaw(Mapped);
       End Else
       Begin
         EmitRaw(Mapped);
       End;
       Inc(I);
     End;
     TK_PUNCT:Begin
       V:=Tokens[I].Val;
       If V='{' Then Begin
         If InClassHdr Then Begin
           PushBrace('C');
           InClassHdr:=False;
           SeenColonHdr:=False;
           AtMemberStart:=True;
         End Else Begin
           PushBrace('M');
         End;
         EmitRaw(' {');
         EmitLn;
         Inc(Indent);
         Inc(I);
         If I<=TokCount Then WriteIndent;
         Continue;
       End;
       If V='}' Then Begin
         If TopBrace='C' Then Begin
           PopBrace;
           PopClass;
           If Indent>0 Then Dec(Indent);
           If Length(OutLine)>0 Then EmitLn;
           WriteIndent;
           EmitRaw('}');
           EmitLn;
           Inc(I);
           { On sort potentiellement d'une classe : revenir au tampon MAIN
             si on n'est plus dans aucune classe. }
           If ClassTop=0 Then Begin
             If OutTarget='C' Then EmitLn;
             OutTarget:='M';
           End;
           If I<=TokCount Then If Tokens[I].Kind<>TK_EOF Then WriteIndent;
           Continue;
         End;
         PopBrace;
         If Indent>0 Then Dec(Indent);
         If Length(OutLine)>0 Then EmitLn;
         WriteIndent;
         EmitRaw('}');
         EmitLn;
         Inc(I);
         { Si on revient au niveau corps de classe, le prochain token
           commence un nouveau membre. }
         If TopBrace='C' Then AtMemberStart:=True;
         If I<=TokCount Then If Tokens[I].Kind<>TK_EOF Then WriteIndent;
         Continue;
       End;
       If V=';' Then Begin
         If ParenTop>0 Then Begin
           EmitRaw('; ');
         End Else Begin
           EmitRaw(';');
           EmitLn;
           If (I+1<=TokCount)and(Tokens[I+1].Kind<>TK_EOF) Then
             If Not((Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='}')) Then
               WriteIndent;
         End;
         Inc(I);
         { Au niveau d'un corps de classe, un ';' termine un champ ; le
           prochain token est un nouveau membre. }
         If TopBrace='C' Then AtMemberStart:=True;
         Continue;
       End;
       If V='(' Then Begin
         { Detection d'une fonction flechee avec parentheses : '(' ... ')'
           '=>'. Si oui, traiter comme une liste de parametres typee.    }
         Saved:=I+1; Mapped:='';
         { Trouver le ')' correspondant. }
         ParenK:=' ';   { reutilise comme drapeau temporaire }
         NextTok:=1;    { profondeur }
         While (Saved<=TokCount) and (NextTok>0) do Begin
           If (Tokens[Saved].Kind=TK_PUNCT)and(Tokens[Saved].Val='(') Then Inc(NextTok);
           If (Tokens[Saved].Kind=TK_PUNCT)and(Tokens[Saved].Val=')') Then Begin
             Dec(NextTok);
             If NextTok=0 Then Break;
           End;
           Inc(Saved);
         End;
         If (NextTok=0) and (Saved<TokCount) and
            (Tokens[Saved+1].Kind=TK_OP) and (Tokens[Saved+1].Val='=>') Then Begin
           { Fonction flechee : emettre les parametres avec dynamic. }
           EmitTypedParamList(I);
           Continue;
         End;
         EmitRaw('(');
         { Detecter for-each : '(' precede par 'for' (mot-cle). }
         If (I-1>=1)and(Tokens[I-1].Kind=TK_KEYWORD)and(Tokens[I-1].Val='for') Then Begin
           If ForIsForEach(I) Then PushParen('F') Else PushParen('N');
         End Else PushParen('N');
         Inc(I);
         Continue;
       End;
       If V=')' Then Begin
         PopParen;
         EmitRaw(')');
         Inc(I);
         Continue;
       End;
       If V=',' Then Begin EmitRaw(', '); Inc(I); Continue; End;
       If V='.' Then Begin EmitRaw('.'); Inc(I); Continue; End;
       If V=':' Then Begin EmitRaw(':'); Inc(I); Continue; End;
       If V='[' Then Begin
         { Detection litteral de tableau : '[' apparait apres un '=', ',',
           '(', '?', ':', ';', '[', ouvre accolade, '=>', 'return' ; sinon c'est un
           operateur d'indexation.                                          }
         If (I=1) or
            ((Tokens[I-1].Kind=TK_OP)and
              ((Tokens[I-1].Val='=')or(Tokens[I-1].Val='=>')or
               (Tokens[I-1].Val='?')or(Tokens[I-1].Val='+')or
               (Tokens[I-1].Val='-')or(Tokens[I-1].Val='*')or
               (Tokens[I-1].Val='/')or(Tokens[I-1].Val='%')or
               (Tokens[I-1].Val='&&')or(Tokens[I-1].Val='||')or
               (Tokens[I-1].Val='??')or(Tokens[I-1].Val='!'))) or
            ((Tokens[I-1].Kind=TK_PUNCT)and
              ((Tokens[I-1].Val=',')or(Tokens[I-1].Val='(')or
               (Tokens[I-1].Val=':')or(Tokens[I-1].Val=';')or
               (Tokens[I-1].Val='[')or(Tokens[I-1].Val='{'))) or
            ((Tokens[I-1].Kind=TK_KEYWORD)and
              ((Tokens[I-1].Val='return')or(Tokens[I-1].Val='in')or
               (Tokens[I-1].Val='of')or(Tokens[I-1].Val='new')or
               (Tokens[I-1].Val='throw')or(Tokens[I-1].Val='case')or
               (Tokens[I-1].Val='typeof')))
         Then Begin
           EmitRaw('new dynamic[] {');
           PushParen('L');
         End Else Begin
           EmitRaw('[');
           PushParen('I');
         End;
         Inc(I); Continue;
       End;
       If V=']' Then Begin
         If TopParen='L' Then EmitRaw('}') Else EmitRaw(']');
         PopParen;
         Inc(I); Continue;
       End;
       EmitRaw(V);
       Inc(I);
     End;
   Else
     Inc(I);
   End;
 End;
 FlushLine;
End;

{ ============================================================
  ECRITURE FINALE DU FICHIER C#
  ============================================================ }
Procedure WriteFinalFile;
Var I:Integer; HasGen, HasIO:Boolean;
Begin
 WriteLn(OutFile,'// Genere par NJS2CS ',VERSION,' a partir de ',SrcName);
 WriteLn(OutFile,'using System;');
 HasGen:=False; HasIO:=False;
 For I:=1 to UseCount do Begin
   WriteLn(OutFile,'using ',Usings[I],';');
   If Usings[I]='System.Collections.Generic' Then HasGen:=True;
   If Usings[I]='System.IO' Then HasIO:=True;
 End;
 If Not HasGen Then WriteLn(OutFile,'using System.Collections.Generic;');
 If Not HasIO  Then WriteLn(OutFile,'using System.IO;');
 WriteLn(OutFile,'using System.Linq;');
 WriteLn(OutFile,'using System.Text;');
 WriteLn(OutFile);
 WriteLn(OutFile,'namespace ConvertedJs {');
 WriteLn(OutFile,'    public class Program {');
 WriteLn(OutFile,'        public static void Main(string[] args) {');
 For I:=1 to MainCount do
   WriteLn(OutFile,'            ',MainLines[I]);
 WriteLn(OutFile,'        }');
 WriteLn(OutFile,'    }');
 If ClassCount>0 Then Begin
   WriteLn(OutFile);
   For I:=1 to ClassCount do
     WriteLn(OutFile,'    ',ClassLines[I]);
 End;
 WriteLn(OutFile,'}');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('NJS2CS ',VERSION,' - Cette commande permet de lancer le transpilateur Node.js (JavaScript) vers C#.');
 WriteLn;
 WriteLn('Syntaxe : NJS2CS source.js [destination.cs]');
 WriteLn;
 WriteLn(' source.js       Indique le fichier Node.js a convertir');
 WriteLn(' destination.cs  Indique le fichier destinataire en C# (C Sharp)');
 WriteLn;
 WriteLn('Exemple : ');
 WriteLn;
 WriteLn('NJS2CS Hello.js Hello.cs');
End;

Procedure ParseArgs;
Var A:TString; I:Integer;
Begin
 If ParamCount<1 Then Begin ShowUsage; Halt(1); End;
 SrcName:=ParamStr(1);
 If ParamCount>=2 Then DstName:=ParamStr(2)
 Else Begin
   A:=SrcName;
   I:=Length(A);
   While (I>0)and(A[I]<>'.') do Dec(I);
   If I>0 Then DstName:=Copy(A,1,I-1)+'.cs'
          Else DstName:=A+'.cs';
 End;
End;

Procedure OpenFiles;
Begin
 Assign(InFile,SrcName);
 {$I-} Reset(InFile); {$I+}
 If IOResult<>0 Then Begin
   WriteLn('Erreur : impossible d''ouvrir ',SrcName);
   Halt(1);
 End;
 Assign(OutFile,DstName);
 Rewrite(OutFile);
End;

Procedure CloseFiles;
Begin
 Close(OutFile);
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowUsage;
  Halt(0);
 End;
 ParseArgs;
 OpenFiles;
 TokInit;
 Tokenize;
 Close(InFile);
 AnalyzeRequires;
 OutLine:='';
 Indent:=0;
 MainCount:=0;
 ClassCount:=0;
 ClassTop:=0;
 OutTarget:='M';
 EmitTokens(1);
 WriteFinalFile;
 CloseFiles;
 WriteLn('NJS2CS : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         UseCount,' usings, ',MainCount,' lignes Main, ',ClassCount,' lignes classes).');
END.