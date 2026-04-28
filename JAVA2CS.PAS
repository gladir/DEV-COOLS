{ @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Java vers
                le langage C# (.cs).

  Sources : Java (compatible JDK 8+).
  Cible   : code source C# (.NET / Mono).

  Sous-ensemble pris en charge :
    package, import, class/interface/enum (extends, implements),
    modificateurs (public, private, protected, static, abstract, final),
    methodes, champs, constructeurs, parametres, generiques,
    if/else, while, do/while, for (classique et for-each),
    switch/case, try/catch/finally, throw, return, break, continue,
    new, this, super, instanceof, lambdas (->), annotations (@...),
    System.out.print(ln), System.err.print(ln),
    chaines, caracteres, nombres (hex, binaire, long, float, double),
    operateurs Java (incluant >>>) et expressions usuelles.

  Mappages principaux :
    String      -> string         boolean     -> bool
    Integer     -> int            Long        -> long
    Short       -> short          Byte        -> sbyte
    Float       -> float          Double      -> double
    Character   -> char           Boolean     -> bool
    Object      -> object
    ArrayList   -> List           HashMap     -> Dictionary
    LinkedList  -> LinkedList     TreeMap     -> SortedDictionary
    HashSet     -> HashSet        TreeSet     -> SortedSet
    Map         -> Dictionary     ArrayDeque  -> Queue
    extends     -> :              implements  -> : (ou ,)
    instanceof  -> is             super       -> base
    synchronized-> lock           throws X    -> (supprime)
    final classe-> sealed         final champ -> readonly
    @Annotation -> commentee      <> (diamant)-> supprime
    ->          -> =>             for(:)      -> foreach(in)
    System.out.println -> Console.WriteLine
    System.out.print   -> Console.Write
    System.out.printf  -> Console.Write
    System.err.println -> Console.Error.WriteLine
    System.err.print   -> Console.Error.Write
    .length()  -> .Length        .equals(    -> .Equals(
    .toString()-> .ToString()    .substring( -> .Substring(
    .indexOf(  -> .IndexOf(      .replace(   -> .Replace(
    .toUpperCase()-> .ToUpper()  .toLowerCase()-> .ToLower()
    .startsWith(-> .StartsWith(  .endsWith(  -> .EndsWith(
    .contains( -> .Contains(     .trim()     -> .Trim()
    .compareTo(-> .CompareTo(    .hashCode() -> .GetHashCode()
    .charAt(   -> [              .split(     -> .Split(

  Imports :
    java.util.*      -> using System.Collections.Generic;
    java.io.*        -> using System.IO;
    java.net.*       -> using System.Net;
    java.math.*      -> using System.Numerics;
    java.text.*      -> using System.Globalization;
    java.util.regex.*-> using System.Text.RegularExpressions;
    java.util.concurrent.* -> using System.Threading.Tasks;

  Limitations :
    - L'analyse semantique est limitee : la plupart des types et
      des references inconnus sont transmis tels quels.
    - try-with-resources : un commentaire est emis ; le bloc `try`
      est conserve mais les ressources ne sont pas fermees automatiquement.
    - Les expressions complexes utilisant des references de methode
      `Type::method` sont reecrites en `Type.method`.
    - Les annotations sont mises en commentaire ; aucune ne devient
      un attribut C#.

  Compilation : fpc -Mtp JAVA2CS.PAS
  Usage       : JAVA2CS source.java [destination.cs]
}

Program JAVA2CS;

Const
 VERSION   = '1.0';
 MAX_TOK   = 65535;
 MAX_USE   = 64;
 MAX_BRACE = 256;

Type
 TString = String;
 TTokenKind = (TK_NONE, TK_IDENT, TK_KEYWORD, TK_INT, TK_REAL,
               TK_STRING, TK_CHAR, TK_OP, TK_PUNCT, TK_ANNOT, TK_EOF);
 TToken = Record
   Kind : TTokenKind;
   Val  : TString;
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Usings     : Array[1..MAX_USE] of TString;
 UseCount   : Integer;
 PackageName: TString;
 ClassMain  : TString;          { nom de la 1re classe trouvee, pour le namespace }
 InFile     : Text;
 OutFile    : Text;
 SrcName    : TString;
 DstName    : TString;
 Indent     : Integer;
 OutLine    : TString;
 SrcEOF     : Boolean;
 SrcPushed  : Boolean;
 SrcPushCh  : Char;
 BraceStack : Array[1..MAX_BRACE] of Char;   { 'C' classe, 'M' methode/bloc }
 BraceTop   : Integer;
 ParenStack : Array[1..MAX_BRACE] of Char;   { 'F' for-each, 'N' normal     }
 ParenTop   : Integer;
 InClassHdr : Boolean;
 SeenColonHdr:Boolean;

{ ============================================================
  UTILITAIRES
  ============================================================ }
Function StrUpper(S:TString):TString;
Var I:Integer;
Begin
 For I:=1 to Length(S) do If(S[I]>='a')and(S[I]<='z')Then S[I]:=Chr(Ord(S[I])-32);
 StrUpper:=S;
End;

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

Function IsJavaKeyword(S:TString):Boolean;
Begin
 IsJavaKeyword:=
  (S='abstract')or(S='assert')or(S='boolean')or(S='break')or
  (S='byte')or(S='case')or(S='catch')or(S='char')or(S='class')or
  (S='const')or(S='continue')or(S='default')or(S='do')or
  (S='double')or(S='else')or(S='enum')or(S='extends')or
  (S='final')or(S='finally')or(S='float')or(S='for')or(S='goto')or
  (S='if')or(S='implements')or(S='import')or(S='instanceof')or
  (S='int')or(S='interface')or(S='long')or(S='native')or(S='new')or
  (S='package')or(S='private')or(S='protected')or(S='public')or
  (S='return')or(S='short')or(S='static')or(S='strictfp')or
  (S='super')or(S='switch')or(S='synchronized')or(S='this')or
  (S='throw')or(S='throws')or(S='transient')or(S='try')or
  (S='void')or(S='volatile')or(S='while')or
  (S='true')or(S='false')or(S='null')or
  (S='var')or(S='record')or(S='yield')or(S='sealed')or(S='permits');
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

{ Lit une chaine. La chaine est stockee avec ses guillemets pour pouvoir
  detecter les blocs de texte ("""...""") et la reemettre integralement.   }
Procedure ScanString;
Var C:Char; V:TString; IsBlock:Boolean;
Begin
 V:='"';
 IsBlock:=False;
 If PeekCh='"' Then Begin
   C:=NextCh; V:=V+C;
   If PeekCh='"' Then Begin
     C:=NextCh; V:=V+C;
     IsBlock:=True;
   End Else Begin
     { chaine vide "" }
     AddToken(TK_STRING,V);
     Exit;
   End;
 End;
 If IsBlock Then Begin
   { Bloc de texte : lire jusqu'a """ }
   While Not SrcEOF do Begin
     C:=NextCh;
     V:=V+C;
     If C='"' Then Begin
       If PeekCh='"' Then Begin
         V:=V+NextCh;
         If PeekCh='"' Then Begin V:=V+NextCh; Break; End;
       End;
     End;
   End;
   AddToken(TK_STRING,V);
   Exit;
 End;
 Repeat
   If SrcEOF Then Break;
   C:=NextCh;
   If C=#10 Then Break;
   V:=V+C;
   If C='\' Then Begin
     If Not SrcEOF Then Begin C:=NextCh; V:=V+C; End;
     Continue;
   End;
   If C='"' Then Break;
 Until False;
 AddToken(TK_STRING,V);
End;

Procedure ScanChar;
Var C:Char; V:TString;
Begin
 V:='''';
 Repeat
   If SrcEOF Then Break;
   C:=NextCh;
   V:=V+C;
   If C='\' Then Begin
     If Not SrcEOF Then Begin C:=NextCh; V:=V+C; End;
     Continue;
   End;
   If C='''' Then Break;
   If C=#10 Then Break;
 Until False;
 AddToken(TK_CHAR,V);
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
     If (PeekCh='L')or(PeekCh='l') Then V:=V+NextCh;
     AddToken(TK_INT,V); Exit;
   End;
   If (PeekCh='b')or(PeekCh='B') Then Begin
     V:=V+NextCh;
     While PeekCh in ['0','1','_'] do V:=V+NextCh;
     If (PeekCh='L')or(PeekCh='l') Then V:=V+NextCh;
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
 If (PeekCh='f')or(PeekCh='F')or(PeekCh='d')or(PeekCh='D') Then Begin
   IsReal:=True; V:=V+NextCh;
 End Else If (PeekCh='L')or(PeekCh='l') Then V:=V+NextCh;
 If IsReal Then AddToken(TK_REAL,V) Else AddToken(TK_INT,V);
End;

Procedure ScanIdent(First:Char);
Var V:TString;
Begin
 V:=First;
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_','$'] do V:=V+NextCh;
 If IsJavaKeyword(V) Then AddToken(TK_KEYWORD,V) Else AddToken(TK_IDENT,V);
End;

Procedure ScanAnnotation;
Var V:TString;
Begin
 V:='@';
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_','.'] do V:=V+NextCh;
 AddToken(TK_ANNOT,V);
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
    '"':ScanString;
    '''':ScanChar;
    '0'..'9':ScanNumber(C);
    'A'..'Z','a'..'z','_','$':ScanIdent(C);
    '@':ScanAnnotation;
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
       Else If N='>' Then Begin C:=NextCh; AddToken(TK_OP,'->'); End
       Else AddToken(TK_OP,'-');
    End;
    '*':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'*='); End
       Else AddToken(TK_OP,'*');
    End;
    '%':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'%='); End
       Else AddToken(TK_OP,'%');
    End;
    '=':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'=='); End
       Else AddToken(TK_OP,'=');
    End;
    '!':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'!='); End
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
       If N='&' Then Begin C:=NextCh; AddToken(TK_OP,'&&'); End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'&='); End
       Else AddToken(TK_OP,'&');
    End;
    '|':Begin
       N:=PeekCh;
       If N='|' Then Begin C:=NextCh; AddToken(TK_OP,'||'); End
       Else If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'|='); End
       Else AddToken(TK_OP,'|');
    End;
    '^':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'^='); End
       Else AddToken(TK_OP,'^');
    End;
    '~':AddToken(TK_OP,'~');
    '?':AddToken(TK_OP,'?');
    ':':Begin
       If PeekCh=':' Then Begin C:=NextCh; AddToken(TK_OP,'::'); End
       Else AddToken(TK_PUNCT,':');
    End;
    '(':AddToken(TK_PUNCT,'(');
    ')':AddToken(TK_PUNCT,')');
    ',':AddToken(TK_PUNCT,',');
    ';':AddToken(TK_PUNCT,';');
    '[':AddToken(TK_PUNCT,'[');
    ']':AddToken(TK_PUNCT,']');
    '{':AddToken(TK_PUNCT,'{');
    '}':AddToken(TK_PUNCT,'}');
    '.':AddToken(TK_PUNCT,'.');
   End;
 End;
 AddToken(TK_EOF,'');
End;

{ ============================================================
  MAPPAGES
  ============================================================ }
Function MapJavaIdent(S:TString):TString;
Begin
 If S='String'        Then MapJavaIdent:='string' Else
 If S='Object'        Then MapJavaIdent:='object' Else
 If S='Integer'       Then MapJavaIdent:='int' Else
 If S='Long'          Then MapJavaIdent:='long' Else
 If S='Short'         Then MapJavaIdent:='short' Else
 If S='Byte'          Then MapJavaIdent:='sbyte' Else
 If S='Double'        Then MapJavaIdent:='double' Else
 If S='Float'         Then MapJavaIdent:='float' Else
 If S='Character'     Then MapJavaIdent:='char' Else
 If S='Boolean'       Then MapJavaIdent:='bool' Else
 If S='ArrayList'     Then MapJavaIdent:='List' Else
 If S='HashMap'       Then MapJavaIdent:='Dictionary' Else
 If S='LinkedHashMap' Then MapJavaIdent:='Dictionary' Else
 If S='TreeMap'       Then MapJavaIdent:='SortedDictionary' Else
 If S='HashSet'       Then MapJavaIdent:='HashSet' Else
 If S='TreeSet'       Then MapJavaIdent:='SortedSet' Else
 If S='LinkedHashSet' Then MapJavaIdent:='HashSet' Else
 If S='Map'           Then MapJavaIdent:='Dictionary' Else
 If S='Set'           Then MapJavaIdent:='HashSet' Else
 If S='ArrayDeque'    Then MapJavaIdent:='Queue' Else
 If S='StringBuilder' Then MapJavaIdent:='StringBuilder' Else
 If S='StringBuffer'  Then MapJavaIdent:='StringBuilder' Else
                           MapJavaIdent:=S;
End;

{ Renomme une methode Java en son equivalent C# (chaine vide si aucun
  changement). Le mappage est applique uniquement apres un '.'.            }
Function MapJavaMethod(S:TString):TString;
Begin
 If S='equals'      Then MapJavaMethod:='Equals' Else
 If S='toString'    Then MapJavaMethod:='ToString' Else
 If S='hashCode'    Then MapJavaMethod:='GetHashCode' Else
 If S='compareTo'   Then MapJavaMethod:='CompareTo' Else
 If S='substring'   Then MapJavaMethod:='Substring' Else
 If S='indexOf'     Then MapJavaMethod:='IndexOf' Else
 If S='lastIndexOf' Then MapJavaMethod:='LastIndexOf' Else
 If S='replace'     Then MapJavaMethod:='Replace' Else
 If S='replaceAll'  Then MapJavaMethod:='Replace' Else
 If S='toUpperCase' Then MapJavaMethod:='ToUpper' Else
 If S='toLowerCase' Then MapJavaMethod:='ToLower' Else
 If S='startsWith'  Then MapJavaMethod:='StartsWith' Else
 If S='endsWith'    Then MapJavaMethod:='EndsWith' Else
 If S='contains'    Then MapJavaMethod:='Contains' Else
 If S='trim'        Then MapJavaMethod:='Trim' Else
 If S='split'       Then MapJavaMethod:='Split' Else
 If S='isEmpty'     Then MapJavaMethod:='IsEmpty' Else { conserve, voir warning }
 If S='size'        Then MapJavaMethod:='Count_' Else { Count est une propriete }
 If S='add'         Then MapJavaMethod:='Add' Else
 If S='remove'      Then MapJavaMethod:='Remove' Else
 If S='clear'       Then MapJavaMethod:='Clear' Else
 If S='get'         Then MapJavaMethod:='Get_' Else { potentiellement un acces indexeur }
 If S='put'         Then MapJavaMethod:='Add' Else
 If S='containsKey' Then MapJavaMethod:='ContainsKey' Else
 If S='keySet'      Then MapJavaMethod:='Keys_' Else
 If S='values'      Then MapJavaMethod:='Values_' Else
                         MapJavaMethod:='';
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

{ Convertit un chemin d'import Java en using C#. Retourne '' s'il n'y a rien
  a emettre (java.lang implicite, ou inconnu).                              }
Function MapImport(Path:TString):TString;
Begin
 If Pos('java.util.regex',Path)=1 Then MapImport:='System.Text.RegularExpressions' Else
 If Pos('java.util.concurrent',Path)=1 Then MapImport:='System.Threading.Tasks' Else
 If Pos('java.util.stream',Path)=1 Then MapImport:='System.Linq' Else
 If Pos('java.util',Path)=1 Then MapImport:='System.Collections.Generic' Else
 If Pos('java.io',Path)=1 Then MapImport:='System.IO' Else
 If Pos('java.nio',Path)=1 Then MapImport:='System.IO' Else
 If Pos('java.net',Path)=1 Then MapImport:='System.Net' Else
 If Pos('java.text',Path)=1 Then MapImport:='System.Globalization' Else
 If Pos('java.math',Path)=1 Then MapImport:='System.Numerics' Else
                                  MapImport:='';
End;

{ ============================================================
  EMISSION : aides
  ============================================================ }
Procedure FlushLine;
Begin
 If Length(OutLine)>0 Then Begin
   WriteLn(OutFile,OutLine);
   OutLine:='';
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
     WriteLn(OutFile,OutLine);
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

{ Emet une espace de separation seulement si necessaire.                    }
Procedure EmitSepSpace;
Var C:Char;
Begin
 C:=LastChar(OutLine);
 If (C=#0)or(C=' ')or(C='(')or(C='[')or(C='{')or(C='.') Then Exit;
 EmitRaw(' ');
End;

{ ============================================================
  ANALYSE : imports, package, nom de classe principal
  ============================================================ }
Procedure Analyze;
Var
 I,J:Integer;
 Path:TString;
 U:TString;
Begin
 PackageName:='';
 ClassMain:='';
 UseCount:=0;
 I:=1;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='package') Then Begin
     Inc(I);
     Path:='';
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
       Path:=Path+Tokens[I].Val;
       Inc(I);
     End;
     PackageName:=Path;
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='import') Then Begin
     Inc(I);
     { sauter un eventuel 'static' }
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='static') Then Inc(I);
     Path:='';
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
       Path:=Path+Tokens[I].Val;
       Inc(I);
     End;
     U:=MapImport(Path);
     If U<>'' Then AddUsing(U);
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and
      ((Tokens[I].Val='class')or(Tokens[I].Val='interface')or(Tokens[I].Val='enum')) Then Begin
     If ClassMain='' Then Begin
       J:=I+1;
       If (J<=TokCount)and(Tokens[J].Kind=TK_IDENT) Then ClassMain:=Tokens[J].Val;
     End;
   End;
   Inc(I);
 End;
End;

{ ============================================================
  EMISSION : pile d'accolades et entete de classe
  ============================================================ }
Procedure PushBrace(Kind:Char);
Begin
 If BraceTop<MAX_BRACE Then Begin
   Inc(BraceTop);
   BraceStack[BraceTop]:=Kind;
 End;
End;

Procedure PopBrace;
Begin
 If BraceTop>0 Then Dec(BraceTop);
End;

Function TopBrace:Char;
Begin
 If BraceTop=0 Then TopBrace:='G' { global/file scope }
 Else TopBrace:=BraceStack[BraceTop];
End;

Procedure PushParen(Kind:Char);
Begin
 If ParenTop<MAX_BRACE Then Begin
   Inc(ParenTop);
   ParenStack[ParenTop]:=Kind;
 End;
End;

Procedure PopParen;
Begin
 If ParenTop>0 Then Dec(ParenTop);
End;

Function TopParen:Char;
Begin
 If ParenTop=0 Then TopParen:=' ' Else TopParen:=ParenStack[ParenTop];
End;

{ ============================================================
  EMISSION : detection contextuelle
  ============================================================ }

{ Cherche apres l'index I (qui pointe sur 'final' ou un autre modificateur)
  si la prochaine "categorie" introduite est class/interface/enum.          }
Function ModifierIntroducesClass(I:Integer):Boolean;
Var J:Integer;
Begin
 ModifierIntroducesClass:=False;
 J:=I+1;
 While J<=TokCount do Begin
   If Tokens[J].Kind=TK_ANNOT Then Begin Inc(J); Continue; End;
   If (Tokens[J].Kind=TK_KEYWORD)and
      ((Tokens[J].Val='public')or(Tokens[J].Val='private')or
       (Tokens[J].Val='protected')or(Tokens[J].Val='static')or
       (Tokens[J].Val='final')or(Tokens[J].Val='abstract')or
       (Tokens[J].Val='strictfp')or(Tokens[J].Val='sealed')) Then Begin
     Inc(J); Continue;
   End;
   Break;
 End;
 If J<=TokCount Then
   If (Tokens[J].Kind=TK_KEYWORD)and
      ((Tokens[J].Val='class')or(Tokens[J].Val='interface')or
       (Tokens[J].Val='enum')or(Tokens[J].Val='record')) Then
     ModifierIntroducesClass:=True;
End;

{ Determine si le 'final' situe a l'indice I (avec TopBrace='C') decrit un
  champ (true) ou une methode/constructeur (false). Heuristique : on cherche
  '(' (=> methode) ou ';'/'='/etc. (=> champ) avant une accolade ouvrante.  }
Function FinalIsField(I:Integer):Boolean;
Var J,Depth:Integer;
Begin
 FinalIsField:=True;
 J:=I+1;
 Depth:=0;
 While J<=TokCount do Begin
   If Tokens[J].Kind=TK_PUNCT Then Begin
     If (Tokens[J].Val='(')or(Tokens[J].Val='[')or(Tokens[J].Val='{') Then Begin
       If (Depth=0)and(Tokens[J].Val='(') Then Begin FinalIsField:=False; Exit; End;
       If (Depth=0)and(Tokens[J].Val='{') Then Exit;
       Inc(Depth);
     End Else
     If (Tokens[J].Val=')')or(Tokens[J].Val=']')or(Tokens[J].Val='}') Then Dec(Depth)
     Else
     If (Depth=0)and((Tokens[J].Val=';')or(Tokens[J].Val=',')) Then Exit;
   End Else
   If (Tokens[J].Kind=TK_OP)and(Tokens[J].Val='=')and(Depth=0) Then Exit;
   Inc(J);
 End;
End;

{ Determine si la parenthese qui s'ouvre apres 'for' decrit un for-each
  Java (i.e. un ':' au niveau 1 avant le ';' au niveau 1).                  }
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
       If Tokens[J].Val=':' Then Begin ForIsForEach:=True; Exit; End;
     End;
   End;
   Inc(J);
 End;
End;

{ ============================================================
  EMISSION : reecriture des sequences speciales
  ============================================================ }

{ Si I pointe sur 'System' suivi de '.out'/'.err' '.println'/'print'/'printf'
  '(' alors emet la version C# et avance I jusqu'a la position du '('
  (lequel sera emis par la boucle principale). Renvoie True si match.       }
Function TryEmitSystemOut(Var I:Integer):Boolean;
Var
 J:Integer;
 IsErr:Boolean;
 Method:TString;
Begin
 TryEmitSystemOut:=False;
 If (Tokens[I].Kind<>TK_IDENT)or(Tokens[I].Val<>'System') Then Exit;
 J:=I+1;
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')) Then Exit;
 Inc(J);
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_IDENT)and
        ((Tokens[J].Val='out')or(Tokens[J].Val='err'))) Then Exit;
 IsErr:=Tokens[J].Val='err';
 Inc(J);
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')) Then Exit;
 Inc(J);
 If Not((J<=TokCount)and(Tokens[J].Kind=TK_IDENT)) Then Exit;
 Method:=Tokens[J].Val;
 If (Method<>'println')and(Method<>'print')and(Method<>'printf') Then Exit;
 { emission }
 If IsErr Then EmitRaw('Console.Error.') Else EmitRaw('Console.');
 If Method='println' Then EmitRaw('WriteLine')
 Else                     EmitRaw('Write');
 I:=J+1;                       { positionner sur ce qui suit le nom de methode }
 TryEmitSystemOut:=True;
End;

{ Si I pointe sur '.' length '(' ')' alors emet '.Length' et avance I de 4.
  Si I pointe sur '.' length (autre) alors emet '.Length' et avance I de 2. }
Function TryEmitDotLength(Var I:Integer):Boolean;
Begin
 TryEmitDotLength:=False;
 If Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')) Then Exit;
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)and(Tokens[I+1].Val='length')) Then Exit;
 EmitRaw('.Length');
 If (I+2<=TokCount)and(Tokens[I+2].Kind=TK_PUNCT)and(Tokens[I+2].Val='(') and
    (I+3<=TokCount)and(Tokens[I+3].Kind=TK_PUNCT)and(Tokens[I+3].Val=')') Then
   I:=I+4
 Else
   I:=I+2;
 TryEmitDotLength:=True;
End;

{ Si I pointe sur '.' nomMethode et nomMethode est connu, emet '.Equiv' et
  laisse I sur '(' (qui sera emis normalement).                              }
Function TryEmitDotMethod(Var I:Integer):Boolean;
Var Eq:TString;
Begin
 TryEmitDotMethod:=False;
 If Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')) Then Exit;
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)) Then Exit;
 Eq:=MapJavaMethod(Tokens[I+1].Val);
 If Eq='' Then Exit;
 { Cas particuliers : on garde le nom Java pour eviter une mauvaise
   interpretation de proprietes vs methodes. }
 If (Eq='IsEmpty')or(Eq='Count_')or(Eq='Get_')or(Eq='Keys_')or(Eq='Values_') Then Exit;
 EmitRaw('.');
 EmitRaw(Eq);
 I:=I+2;
 TryEmitDotMethod:=True;
End;

{ Si I pointe sur '<' '>' alors c'est un diamant : on l'omet. }
Function TryEmitDiamond(Var I:Integer):Boolean;
Begin
 TryEmitDiamond:=False;
 If Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='<')) Then Exit;
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_OP)and(Tokens[I+1].Val='>')) Then Exit;
 I:=I+2;
 TryEmitDiamond:=True;
End;

{ ============================================================
  EMISSION : token par token
  ============================================================ }

{ Emet un token IDENT en appliquant les renommages de types (sauf si
  precede de '.' et que ce n'est pas pertinent).                            }
Procedure EmitIdent(I:Integer);
Var V,M:TString;
Begin
 V:=Tokens[I].Val;
 { Si juste apres un '.' on ne renomme pas (c'est un acces a un membre). }
 If (I>1) and (Tokens[I-1].Kind=TK_PUNCT) and (Tokens[I-1].Val='.') Then Begin
   EmitRaw(V);
   Exit;
 End;
 M:=MapJavaIdent(V);
 EmitRaw(M);
End;

{ Convertit la chaine Java litterale en chaine C#. La plupart du temps
  c'est l'identite. On gere notamment les blocs de texte """...""".        }
Function ConvertString(S:TString):TString;
Begin
 ConvertString:=S;
End;

{ Emet 'throws X, Y, Z' en sautant tout jusqu'au prochain bloc ou ';'. }
Procedure SkipThrowsClause(Var I:Integer);
Begin
 Inc(I);                       { sauter 'throws' }
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='{')or(Tokens[I].Val=';')) Then Exit;
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
 IsField:Boolean;
 ForEachOpen:Boolean;
 Saved:Integer;
Begin
 I:=StartIdx;
 BraceTop:=0;
 ParenTop:=0;
 InClassHdr:=False;
 SeenColonHdr:=False;

 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_EOF Then Break;

   { Sauter package : il a deja ete utilise pour le namespace. }
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='package') Then Begin
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
     If I<=TokCount Then Inc(I);
     Continue;
   End;

   { Sauter import. }
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='import') Then Begin
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
     If I<=TokCount Then Inc(I);
     Continue;
   End;

   { Annotations : commentees. }
   If Tokens[I].Kind=TK_ANNOT Then Begin
     If LastChar(OutLine)<>' ' Then If Length(OutLine)>0 Then EmitRaw(' ');
     EmitRaw('/* ');
     EmitRaw(Tokens[I].Val);
     { une eventuelle liste d'arguments d'annotation : @Foo(a=1, b=2) }
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') Then Begin
       Inc(I);
       EmitRaw('('); Inc(I);
       Saved:=1;
       While (I<=TokCount)and(Saved>0) do Begin
         If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Saved)
         Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
           Dec(Saved);
           If Saved=0 Then Begin EmitRaw(')'); Inc(I); Break; End;
         End;
         EmitRaw(Tokens[I].Val);
         Inc(I);
       End;
     End Else Inc(I);
     EmitRaw(' */');
     EmitLn;
     WriteIndent;
     Continue;
   End;

   { 'throws' apres une signature de methode -> ignore. }
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='throws') Then Begin
     SkipThrowsClause(I);
     Continue;
   End;

   { Diamant '<>' -> rien. }
   If TryEmitDiamond(I) Then Continue;

   { System.out / System.err. }
   If TryEmitSystemOut(I) Then Continue;

   { Acces .length / .length() . }
   If TryEmitDotLength(I) Then Continue;

   { Methodes Java courantes apres '.' . }
   If TryEmitDotMethod(I) Then Continue;

   Case Tokens[I].Kind of
     TK_KEYWORD:Begin
       K:=Tokens[I].Val;
       If K='boolean' Then Begin EmitSepSpace; EmitRaw('bool'); Inc(I); End Else
       If K='extends' Then Begin
         If InClassHdr Then Begin
           If Not SeenColonHdr Then Begin EmitRaw(' :'); SeenColonHdr:=True; End
           Else EmitRaw(',');
           Inc(I);
         End Else Begin
           { dans un parametre generique : <T extends X> -> on perd l'info,
             on garde extends comme un commentaire pour preserver le sens. }
           EmitRaw(' /* extends */ ');
           Inc(I);
         End;
       End Else
       If K='implements' Then Begin
         If InClassHdr Then Begin
           If Not SeenColonHdr Then Begin EmitRaw(' :'); SeenColonHdr:=True; End
           Else EmitRaw(',');
         End Else EmitRaw(',');
         Inc(I);
       End Else
       If K='instanceof' Then Begin EmitSepSpace; EmitRaw('is'); Inc(I); End Else
       If K='super' Then Begin EmitSepSpace; EmitRaw('base'); Inc(I); End Else
       If K='synchronized' Then Begin EmitSepSpace; EmitRaw('lock'); Inc(I); End Else
       If K='final' Then Begin
         If ModifierIntroducesClass(I) Then Begin
           EmitSepSpace; EmitRaw('sealed'); Inc(I);
         End Else
         If TopBrace='C' Then Begin
           IsField:=FinalIsField(I);
           If IsField Then Begin EmitSepSpace; EmitRaw('readonly'); End;
           { si methode/constructeur, on supprime simplement final }
           Inc(I);
         End Else Begin
           { dans un corps de methode : final supprime }
           Inc(I);
         End;
       End Else
       If (K='class')or(K='interface')or(K='enum')or(K='record') Then Begin
         EmitSepSpace;
         EmitRaw(K);
         InClassHdr:=True;
         SeenColonHdr:=False;
         Inc(I);
       End Else
       If (K='try') Then Begin
         EmitSepSpace; EmitRaw('try');
         Inc(I);
         { try-with-resources : try (decl) suivi du bloc }
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
           EmitRaw(' /* try-with-resources : la fermeture automatique des ressources doit etre traduite manuellement avec using */ ');
           { sauter ( ... ) }
           Saved:=0;
           Inc(I);
           Saved:=1;
           While (I<=TokCount)and(Saved>0) do Begin
             If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Saved);
             If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
               Dec(Saved);
               If Saved=0 Then Begin Inc(I); Break; End;
             End;
             Inc(I);
           End;
         End;
       End Else
       If K='for' Then Begin
         EmitSepSpace;
         { Verifier si c'est un for-each. }
         ForEachOpen:=False;
         If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') Then
           ForEachOpen:=ForIsForEach(I+1);
         If ForEachOpen Then EmitRaw('foreach') Else EmitRaw('for');
         Inc(I);
       End Else
       If K='var' Then Begin EmitSepSpace; EmitRaw('var'); Inc(I); End Else
       If (K='true')or(K='false')or(K='null') Then Begin
         EmitSepSpace; EmitRaw(K); Inc(I);
       End Else
       Begin
         { mot-cle commun : if, else, while, do, switch, case, default,
           return, break, continue, throw, catch, finally, new, this,
           static, public, private, protected, abstract, void, int, long,
           short, byte, double, float, char, native, transient, volatile,
           strictfp, default, enum, package(deja sauter), import(deja sauter),
           const, goto, ... }
         EmitSepSpace;
         EmitRaw(K);
         Inc(I);
       End;
     End;
     TK_IDENT:Begin
       EmitSepSpace;
       EmitIdent(I);
       Inc(I);
     End;
     TK_INT:Begin
       EmitSepSpace;
       V:=Tokens[I].Val;
       { Java accepte 1_000 ; C# 7+ aussi. Hex/binaire : compatibles. }
       EmitRaw(V);
       Inc(I);
     End;
     TK_REAL:Begin
       EmitSepSpace;
       V:=Tokens[I].Val;
       EmitRaw(V);
       Inc(I);
     End;
     TK_STRING:Begin
       EmitSepSpace;
       EmitRaw(ConvertString(Tokens[I].Val));
       Inc(I);
     End;
     TK_CHAR:Begin
       EmitSepSpace;
       EmitRaw(Tokens[I].Val);
       Inc(I);
     End;
     TK_OP:Begin
       V:=Tokens[I].Val;
       Mapped:=V;
       If V='->' Then Mapped:='=>';
       If V='::' Then Mapped:='.';
       { espace autour des operateurs binaires/de comparaison }
       If (V='=')or(V='==')or(V='!=')or(V='<')or(V='>')or(V='<=')or(V='>=')or
          (V='+=')or(V='-=')or(V='*=')or(V='/=')or(V='%=')or(V='&=')or(V='|=')or
          (V='^=')or(V='<<=')or(V='>>=')or(V='>>>=')or(V='&&')or(V='||')or
          (V='->') Then Begin
         EmitSepSpace; EmitRaw(Mapped); EmitRaw(' ');
       End Else
       If (V='+')or(V='-')or(V='*')or(V='/')or(V='%')or
          (V='&')or(V='|')or(V='^')or(V='<<')or(V='>>')or(V='>>>') Then Begin
         { ces operateurs peuvent etre unaires ; on emet sans espace force }
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
         End Else
           PushBrace('M');
         EmitRaw(' {');
         EmitLn;
         Inc(Indent);
         Inc(I);
         If I<=TokCount Then WriteIndent;
         Continue;
       End;
       If V='}' Then Begin
         PopBrace;
         If Indent>0 Then Dec(Indent);
         { remonter sur une nouvelle ligne propre si necessaire }
         If Length(OutLine)>0 Then If LastChar(OutLine)<>' ' Then EmitLn Else FlushLine;
         If Length(OutLine)>0 Then EmitLn;
         WriteIndent;
         EmitRaw('}');
         EmitLn;
         Inc(I);
         If I<=TokCount Then If Tokens[I].Kind<>TK_EOF Then WriteIndent;
         Continue;
       End;
       If V=';' Then Begin
         If ParenTop>0 Then Begin
           EmitRaw('; ');
         End Else Begin
           EmitRaw(';');
           EmitLn;
           If (I+1<=TokCount)and(Tokens[I+1].Kind<>TK_EOF) Then Begin
             { Ne pas reindenter si le prochain token est une accolade fermante. }
             If Not((Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='}')) Then WriteIndent;
           End;
         End;
         Inc(I);
         Continue;
       End;
       If V='(' Then Begin
         EmitRaw('(');
         { detecter for-each pour traduire ':' -> 'in' }
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
       If V=':' Then Begin
         If TopParen='F' Then Begin
           EmitRaw(' in ');
         End Else Begin
           EmitRaw(':');
         End;
         Inc(I);
         Continue;
       End;
       If V=',' Then Begin
         EmitRaw(', ');
         Inc(I);
         Continue;
       End;
       If V='.' Then Begin
         EmitRaw('.');
         Inc(I);
         Continue;
       End;
       { autres : [ ] }
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
  EN-TETE / FIN DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Var I:Integer; HasGen,HasIO:Boolean;
Begin
 EmitRaw('// Genere par JAVA2CS '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw('using System;'); EmitLn;
 HasGen:=False; HasIO:=False;
 For I:=1 to UseCount do Begin
   EmitRaw('using '); EmitRaw(Usings[I]); EmitRaw(';'); EmitLn;
   If Usings[I]='System.Collections.Generic' Then HasGen:=True;
   If Usings[I]='System.IO' Then HasIO:=True;
 End;
 If Not HasGen Then Begin
   EmitRaw('using System.Collections.Generic;'); EmitLn;
 End;
 If Not HasIO Then Begin
   { utile pour un grand nombre de programmes Java }
   EmitRaw('using System.Text;'); EmitLn;
 End;
 EmitLn;
 If PackageName<>'' Then Begin
   EmitRaw('namespace '); EmitRaw(PackageName); EmitRaw(' {'); EmitLn;
   Inc(Indent);
   WriteIndent;
 End Else Begin
   { un namespace minimal base sur le nom de classe principal, ou un nom
     generique si aucune classe trouvee. }
   If ClassMain<>'' Then EmitRaw('namespace '+ClassMain+'NS {')
   Else EmitRaw('namespace ConvertedJava {');
   EmitLn;
   Inc(Indent);
   WriteIndent;
 End;
End;

Procedure EmitFileFooter;
Begin
 If Indent>0 Then Dec(Indent);
 EmitLn;
 EmitRaw('}'); EmitLn;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('JAVA2CS ',VERSION,' - Cette commande permet de lancer le transpilateur Java vers C#.');
 WriteLn;
 WriteLn('Syntaxe : JAVA2CS source.java [destination.cs]');
 WriteLn;
 WriteLn(' source.java     Indique le fichier … convertir');
 WriteLn(' destination.cs  Indique le fichier destinataire en C# (C Sharp)');
 WriteLn;
 WriteLn('Exemple : ');
 WriteLn;
 WriteLn('JAVA2CS Hello.java Hello.cs');
End;

Procedure ParseArgs;
Var
 A:TString;
 I:Integer;
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
 FlushLine;
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
 Analyze;
 OutLine:='';
 Indent:=0;
 EmitFileHeader;
 EmitTokens(1);
 EmitFileFooter;
 CloseFiles;
 WriteLn('JAVA2CS : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         UseCount,' usings).');
END.
