{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Oberon
                (Oberon-2 / Oberon-07) vers le langage C (.c).

  Sources : Oberon (.Mod / .ob / .ob2 / .ob07).
  Cible   : code source C ANSI/C99 portable.

  Sous-ensemble pris en charge :
    MODULE/END Module., IMPORT (mappage des modules courants vers en-tetes
    C standards), CONST, TYPE, VAR, PROCEDURE, FUNCTION (PROCEDURE avec
    type de retour), parametres VAR (=> pointeurs), BEGIN..END, IF/THEN/
    ELSIF/ELSE/END, WHILE..DO..END, REPEAT..UNTIL, FOR..TO/BY..DO..END,
    LOOP/EXIT, CASE..OF (=> switch/case), RETURN expr.

  Mappages d'entrees/sorties :
    Out.String/Out.Int/Out.Real/Out.Char/Out.Ln  -> printf
    In.Int/In.Real/In.Char                       -> scanf

  Limitations :
    - WITH, ensembles (SET) : commentes en sortie.
    - L'analyse semantique est limitee : les types complexes (RECORD,
      POINTER TO, ARRAY OF) sont rendus de maniere syntaxique.

  Compilation : fpc -Mtp OBERON2C.PAS
  Usage       : OBERON2C source.Mod [destination.c]
}
Program OBERON2C;

Const
 VERSION = '1.0';
 MAX_TOK = 65535;
 MAX_FNS = 1024;
 MAX_IMP = 64;

Type
 TString = String;
 TTokenKind = (TK_NONE, TK_IDENT, TK_KEYWORD, TK_INT, TK_REAL,
               TK_STRING, TK_CHAR, TK_OP, TK_PUNCT, TK_EOF);
 TToken = Record
   Kind : TTokenKind;
   Val  : TString;
 End;
 TFuncRec = Record
   Name    : TString;     { nom Oberon d'origine                          }
   RetType : TString;     { type C de retour ('' si procedure pure)       }
   IsFunc  : Boolean;
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Funcs      : Array[1..MAX_FNS] of TFuncRec;
 FuncCount  : Integer;
 CurFunc    : Integer;
 InFile     : Text;
 OutFile    : Text;
 SrcName    : TString;
 DstName    : TString;
 ModuleName : TString;
 UsesOut    : Boolean;       { faut-il #include <stdio.h>                 }
 UsesString : Boolean;       { faut-il #include <string.h>                }
 UsesMath   : Boolean;       { faut-il #include <math.h>                  }
 UsesStdLib : Boolean;       { faut-il #include <stdlib.h>                }
 SourceLine : LongInt;
 Indent     : Integer;
 OutLine    : TString;       { ligne en cours d'emission                  }
 Imports    : Array[1..MAX_IMP] of TString;
 ICount     : Integer;
 SrcCh      : Char;
 SrcEOF     : Boolean;
 SrcPushed  : Boolean;
 SrcPushCh  : Char;

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

Function StrEqualCI(A,B:TString):Boolean;
Begin
 StrEqualCI:=StrUpper(A)=StrUpper(B);
End;

Function IntToStr(N:LongInt):TString;
Var S:TString;
Begin
 Str(N,S); IntToStr:=S;
End;

{ ============================================================
  ANALYSE LEXICALE
  ============================================================ }
Procedure TokInit;
Begin
 TokCount:=0;
 SrcEOF:=False;
 SrcPushed:=False;
 SourceLine:=1;
End;

Function NextCh:Char;
Var C:Char;
Begin
 If SrcPushed Then Begin
   SrcPushed:=False;
   NextCh:=SrcPushCh;
   Exit;
 End;
 If Eof(InFile) Then Begin SrcEOF:=True; NextCh:=#0; Exit; End;
 If Eoln(InFile) Then Begin ReadLn(InFile); Inc(SourceLine); NextCh:=#10; Exit; End;
 Read(InFile,C);
 NextCh:=C;
End;

Procedure UngetCh(Ch:Char);
Begin
 SrcPushCh:=Ch; SrcPushed:=True;
End;

Function PeekCh:Char;
Var C:Char;
Begin
 C:=NextCh;
 UngetCh(C);
 PeekCh:=C;
End;

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

Function IsKeyword(S:TString):Boolean;
Var U:TString;
Begin
 U:=StrUpper(S);
 IsKeyword:=
   (U='ARRAY')or(U='BEGIN')or(U='BY')or(U='CASE')or(U='CONST')or
   (U='DEFINITION')or(U='DIV')or(U='DO')or(U='ELSE')or(U='ELSIF')or
   (U='END')or(U='EXIT')or(U='FALSE')or(U='FOR')or(U='IF')or
   (U='IMPORT')or(U='IN')or(U='IS')or(U='LOOP')or(U='MOD')or
   (U='MODULE')or(U='NIL')or(U='OF')or(U='OR')or(U='POINTER')or
   (U='PROCEDURE')or(U='RECORD')or(U='REPEAT')or(U='RETURN')or
   (U='THEN')or(U='TO')or(U='TRUE')or(U='TYPE')or(U='UNTIL')or
   (U='VAR')or(U='WHILE')or(U='WITH');
End;

{ Saute un commentaire Oberon (* ... *) en gerant l'imbrication. Le `(`
  d'ouverture a deja ete consomme, le `*` de tete egalement. }
Procedure SkipOberonComment;
Var C:Char; Depth:Integer;
Begin
 Depth:=1;
 While(Not SrcEOF)and(Depth>0)do Begin
   C:=NextCh;
   If SrcEOF Then Exit;
   If(C='*')and(PeekCh=')')Then Begin
     C:=NextCh; Dec(Depth);
   End Else
   If(C='(')and(PeekCh='*')Then Begin
     C:=NextCh; Inc(Depth);
   End;
 End;
End;

{ Lit un litteral chaine entre delimiteurs Q (`"` ou `'`). Stockage : on
  prefixe par `"` pour normaliser ; les guillemets internes ne sont pas
  doubles en Oberon (contrairement a Pascal). }
Procedure ScanString(Q:Char);
Var C:Char; V:TString;
Begin
 V:='"';
 Repeat
   C:=NextCh;
   If SrcEOF Then Break;
   If C=#10 Then Break;
   If C=Q Then Break;
   V:=V+C;
 Until False;
 V:=V+'"';
 { Une chaine d'un seul caractere entre apostrophes peut representer un
   caractere ; on conserve le format chaine et on adaptera au moment de
   l'emission selon le contexte. }
 AddToken(TK_STRING,V);
End;

Procedure ScanNumber(First:Char);
Var
 V:TString;
 IsReal:Boolean;
 C:Char;
 Suffix:Char;
Begin
 V:=First;
 IsReal:=False;
 While PeekCh in ['0'..'9','A'..'F','a'..'f'] do V:=V+NextCh;
 { Suffixe Oberon : H = hexadecimal entier, X = caractere code en hexa. }
 If(PeekCh='H')or(PeekCh='X')Then Begin
   Suffix:=NextCh;
   If Suffix='X' Then Begin
     AddToken(TK_CHAR,'#'+V);
     Exit;
   End;
   AddToken(TK_INT,'$'+V);
   Exit;
 End;
 If PeekCh='.' Then Begin
   C:=NextCh;
   If PeekCh='.' Then Begin UngetCh(C); End
   Else Begin V:=V+'.'; IsReal:=True;
     While PeekCh in ['0'..'9'] do V:=V+NextCh;
   End;
 End;
 If(PeekCh='E')or(PeekCh='e')or(PeekCh='D')or(PeekCh='d')Then Begin
   C:=NextCh;
   If(C='D')or(C='d')Then V:=V+'E' Else V:=V+C;
   IsReal:=True;
   If(PeekCh='+')or(PeekCh='-')Then V:=V+NextCh;
   While PeekCh in ['0'..'9'] do V:=V+NextCh;
 End;
 If IsReal Then AddToken(TK_REAL,V) Else AddToken(TK_INT,V);
End;

Procedure ScanIdent(First:Char);
Var V:TString;
Begin
 V:=First;
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_'] do V:=V+NextCh;
 { Marqueurs d'export Oberon-2 : `*` (export) ou `-` (export en lecture
   seule). On les consomme silencieusement, ils n'ont pas d'equivalent
   syntaxique en C. }
 If PeekCh='*' Then Begin SrcCh:=NextCh; End
 Else If PeekCh='-' Then Begin
   { On ne consomme `-` que s'il suit immediatement un identificateur en
     declaration. Comme on ne distingue pas le contexte ici, on regarde
     le caractere suivant : s'il est alphanumerique on laisse, sinon on
     considere que c'est un marqueur. }
 End;
 If IsKeyword(V) Then AddToken(TK_KEYWORD,StrUpper(V))
                 Else AddToken(TK_IDENT,V);
End;

Procedure Tokenize;
Var
 C,N:Char;
Begin
 While Not SrcEOF do Begin
   C:=NextCh;
   If SrcEOF Then Break;
   Case C of
     ' ',#9,#10,#13: ;
     '(':Begin
       If PeekCh='*' Then Begin C:=NextCh; SkipOberonComment; End
       Else AddToken(TK_PUNCT,'(');
     End;
     '/':AddToken(TK_OP,'/');
     '"':ScanString('"');
     '''':ScanString('''');
     '0'..'9':ScanNumber(C);
     'A'..'Z','a'..'z','_':ScanIdent(C);
     ':':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,':='); End
       Else AddToken(TK_PUNCT,':');
     End;
     '<':Begin
       N:=PeekCh;
       If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'<='); End
       Else AddToken(TK_OP,'<');
     End;
     '>':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'>='); End
       Else AddToken(TK_OP,'>');
     End;
     '#':AddToken(TK_OP,'#');
     '&':AddToken(TK_OP,'&');
     '~':AddToken(TK_OP,'~');
     '+','-','*','=':AddToken(TK_OP,C);
     '.':Begin
       If PeekCh='.' Then Begin C:=NextCh; AddToken(TK_PUNCT,'..'); End
       Else AddToken(TK_PUNCT,'.');
     End;
     '|':AddToken(TK_PUNCT,'|');
     ')',',',';','[',']','^','{','}':AddToken(TK_PUNCT,C);
   End;
 End;
 AddToken(TK_EOF,'');
End;

{ ============================================================
  ANALYSE PRELIMINAIRE
  ============================================================ }
Function MapOberonType(T:TString):TString;
Var U:TString;
Begin
 U:=StrUpper(T);
 If U='INTEGER'   Then MapOberonType:='int' Else
 If U='LONGINT'   Then MapOberonType:='long' Else
 If U='HUGEINT'   Then MapOberonType:='long long' Else
 If U='SHORTINT'  Then MapOberonType:='signed char' Else
 If U='BYTE'      Then MapOberonType:='unsigned char' Else
 If U='REAL'      Then MapOberonType:='float' Else
 If U='LONGREAL'  Then MapOberonType:='double' Else
 If U='CHAR'      Then MapOberonType:='char' Else
 If U='BOOLEAN'   Then MapOberonType:='int' Else
 If U='SET'       Then MapOberonType:='unsigned int' Else
                       MapOberonType:=T;
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean);
Begin
 If FuncCount>=MAX_FNS Then Exit;
 Inc(FuncCount);
 Funcs[FuncCount].Name:=Name;
 Funcs[FuncCount].RetType:=RetType;
 Funcs[FuncCount].IsFunc:=IsFunc;
End;

Function FindFunc(Name:TString):Integer;
Var I:Integer;
Begin
 FindFunc:=0;
 For I:=1 to FuncCount do
   If StrEqualCI(Funcs[I].Name,Name) Then Begin FindFunc:=I; Exit; End;
End;

Procedure RegisterImport(Name:TString);
Var I:Integer; U:TString;
Begin
 If ICount>=MAX_IMP Then Exit;
 U:=StrUpper(Name);
 For I:=1 to ICount do If StrUpper(Imports[I])=U Then Exit;
 Inc(ICount);
 Imports[ICount]:=Name;
 If(U='IN')or(U='OUT')or(U='TEXTS')or(U='IO')Then UsesOut:=True;
 If(U='STRINGS')or(U='STRING')Then UsesString:=True;
 If(U='MATH')or(U='MATHL')or(U='MATHLIB')or(U='REALMATH')Then UsesMath:=True;
 If(U='SYSTEM')or(U='STORAGE')or(U='OBERON')Then UsesStdLib:=True;
End;

Procedure Analyze;
Var
 I,J:Integer;
 K:TString;
 Name,Ret:TString;
 Depth:Integer;
Begin
 FuncCount:=0;
 CurFunc:=0;
 ICount:=0;
 UsesOut:=False;
 UsesString:=False;
 UsesMath:=False;
 UsesStdLib:=False;
 ModuleName:='Module';

 I:=1;
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='MODULE')Then Begin
     If(I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)Then ModuleName:=Tokens[I+1].Val;
   End Else
   If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IMPORT')Then Begin
     J:=I+1;
     While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';'))do Begin
       If Tokens[J].Kind=TK_IDENT Then Begin
         { Forme `alias := Module` -> on enregistre le module reel. }
         If(J+2<=TokCount)and(Tokens[J+1].Kind=TK_OP)and(Tokens[J+1].Val=':=')and
           (Tokens[J+2].Kind=TK_IDENT)Then Begin
           RegisterImport(Tokens[J+2].Val);
           Inc(J,3);
         End Else Begin
           RegisterImport(Tokens[J].Val);
           Inc(J);
         End;
       End Else Inc(J);
     End;
     I:=J;
   End Else
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='PROCEDURE' Then Begin
       J:=I+1;
       Name:=''; Ret:='';
       If(J<=TokCount)and(Tokens[J].Kind=TK_IDENT)Then Begin Name:=Tokens[J].Val; Inc(J); End;
       If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(')Then Begin
         Depth:=1; Inc(J);
         While(J<=TokCount)and(Depth>0)do Begin
           If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(')Then Inc(Depth)
           Else If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')')Then Dec(Depth);
           Inc(J);
         End;
       End;
       If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':')Then Begin
         Inc(J);
         If J<=TokCount Then Begin Ret:=MapOberonType(Tokens[J].Val); Inc(J); End;
       End;
       If Name<>'' Then RegisterFunc(Name,Ret,Ret<>'');
     End;
   End;
   Inc(I);
 End;
End;

{ ============================================================
  EMISSION
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
Begin
 For I:=1 to Indent*4 do OutLine:=OutLine+' ';
End;

Procedure EmitRaw(S:TString);
Var I:Integer;
Begin
 For I:=1 to Length(S) do Begin
   If S[I]=#10 Then Begin
     WriteLn(OutFile,OutLine);
     OutLine:='';
   End Else Begin
     If(Length(OutLine)=0)and(S[I]<>' ')Then WriteIndent;
     OutLine:=OutLine+S[I];
   End;
 End;
End;

Procedure EmitLn;
Begin EmitRaw(#10); End;

{ Conversion d'une chaine Oberon stockee comme "..." vers une chaine C
  echappee. }
Function OberonStringToC(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If S[I]='"'  Then Begin R:=R+'\"'; Inc(I); End
   Else If S[I]='\' Then Begin R:=R+'\\'; Inc(I); End
   Else If S[I]=#10 Then Begin R:=R+'\n'; Inc(I); End
   Else If S[I]=#13 Then Begin R:=R+'\r'; Inc(I); End
   Else If S[I]=#9  Then Begin R:=R+'\t'; Inc(I); End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 OberonStringToC:='"'+R+'"';
End;

{ Conversion d'un litteral Oberon `code X` (#code) en C. }
Function OberonCharToC(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body,Num:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 Val('$'+Body,V,Code);
 If Code<>0 Then V:=0;
 Str(V,Num);
 If(V>=32)and(V<=126)and(V<>Ord(''''))and(V<>Ord('\'))Then
   OberonCharToC:=''''+Chr(V)+''''
 Else
   OberonCharToC:='(char)'+Num;
End;

{ Mappage d'un operateur Oberon vers C. ContextEq=True => `=` egalite. }
Function MapOp(Op:TString; ContextEq:Boolean):TString;
Begin
 If Op='#' Then MapOp:='!=' Else
 If Op=':=' Then MapOp:='=' Else
 If Op='&'  Then MapOp:='&&' Else
 If Op='~'  Then MapOp:='!' Else
 If(Op='=')and ContextEq Then MapOp:='==' Else
 MapOp:=Op;
End;

Function MapKw(K:TString):TString;
Begin
 If K='OR'   Then MapKw:='||' Else
 If K='DIV'  Then MapKw:='/'  Else
 If K='MOD'  Then MapKw:='%'  Else
 If K='TRUE' Then MapKw:='1'  Else
 If K='FALSE'Then MapKw:='0'  Else
 If K='NIL'  Then MapKw:='NULL' Else
 If K='IN'   Then MapKw:='/* IN ensemble non supporte */' Else
                  MapKw:=StrLower(K);
End;

{ ============================================================
  FORWARDS et ETAT
  ============================================================ }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString); Forward;

{ Determine si un token termine une expression Oberon. }
Function IsExprStop(I:Integer):Boolean;
Begin
 IsExprStop:=False;
 If I>TokCount Then Begin IsExprStop:=True; Exit; End;
 If Tokens[I].Kind=TK_EOF Then Begin IsExprStop:=True; Exit; End;
 If Tokens[I].Kind=TK_PUNCT Then Begin
   If(Tokens[I].Val=';')or(Tokens[I].Val=',')or(Tokens[I].Val=')')or
     (Tokens[I].Val=']')or(Tokens[I].Val='|')Then IsExprStop:=True;
 End Else
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   If(Tokens[I].Val='THEN')or(Tokens[I].Val='DO')or(Tokens[I].Val='ELSE')or
     (Tokens[I].Val='ELSIF')or(Tokens[I].Val='OF')or(Tokens[I].Val='TO')or
     (Tokens[I].Val='BY')or(Tokens[I].Val='UNTIL')or(Tokens[I].Val='BEGIN')or
     (Tokens[I].Val='END')or(Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or
     (Tokens[I].Val='TYPE')or(Tokens[I].Val='PROCEDURE')Then IsExprStop:=True;
 End Else
 If(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then IsExprStop:=True;
End;

{ Emet un seul token au sein d'une expression. }
Procedure EmitOneExprTok(I:Integer);
Var V:TString;
Begin
 Case Tokens[I].Kind of
   TK_KEYWORD: EmitRaw(MapKw(Tokens[I].Val));
   TK_OP     : EmitRaw(MapOp(Tokens[I].Val,True));
   TK_STRING : Begin
     V:=Tokens[I].Val;
     If Length(V)=3 Then
       { chaine de un caractere "X" -> caractere C 'X' }
       EmitRaw(''''+V[2]+'''')
     Else
       EmitRaw(OberonStringToC(V));
   End;
   TK_CHAR   : EmitRaw(OberonCharToC(Tokens[I].Val));
   TK_INT    : Begin
     V:=Tokens[I].Val;
     If(Length(V)>0)and(V[1]='$')Then EmitRaw('0x'+Copy(V,2,Length(V)-1))
     Else EmitRaw(V);
   End;
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : EmitRaw(Tokens[I].Val);
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('[0]')
     Else EmitRaw(Tokens[I].Val);
   End;
 End;
End;

{ Emet des tokens jusqu'a un point d'arret, en gerant la profondeur de
  parentheses/crochets. }
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString);
Var
 Depth:Integer;
 NeedSpaceBefore:Boolean;
 IsOpish:Boolean;
Begin
 Depth:=0;
 NeedSpaceBefore:=False;
 While I<=TokCount do Begin
   If(Depth=0)and IsExprStop(I)Then Break;
   If(Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Pos(Tokens[I].Val,StopPunct)>0)Then Break;
   { Acces module : `Mod.Ident` -> on garde le `.` colle, mais on doit
     traiter le `.` autrement -- vu que la tokenisation inclut `.` comme
     ponctuation ; on l'emet sans espaces. }
   If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='['))Then Inc(Depth)
   Else If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val=']'))Then Dec(Depth);
   IsOpish:=False;
   If Tokens[I].Kind=TK_OP Then IsOpish:=True;
   If(Tokens[I].Kind=TK_KEYWORD)and
     ((Tokens[I].Val='OR')or(Tokens[I].Val='DIV')or(Tokens[I].Val='MOD')or
      (Tokens[I].Val='IS')or(Tokens[I].Val='IN'))Then IsOpish:=True;
   If IsOpish or NeedSpaceBefore Then Begin
     If(Length(OutLine)>0)and(OutLine[Length(OutLine)]<>' ')and
       (OutLine[Length(OutLine)]<>'(')and(OutLine[Length(OutLine)]<>'[')and
       (OutLine[Length(OutLine)]<>'.')Then
       EmitRaw(' ');
   End;
   { Pas d'espace avant `.` (acces de membre). }
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then NeedSpaceBefore:=False;
   EmitOneExprTok(I);
   NeedSpaceBefore:=False;
   If IsOpish Then NeedSpaceBefore:=True;
   If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=',')or(Tokens[I].Val=';'))Then
     NeedSpaceBefore:=True;
   { Pas d'espace apres `.` }
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then NeedSpaceBefore:=False;
   Inc(I);
 End;
End;

Procedure EmitExpr(Var I:Integer);
Begin EmitExprUntil(I,''); End;

{ ============================================================
  Out / In : pseudo modules d'E/S
  ============================================================ }
{ Emet un appel Out.X(args) -> printf(...) approprie. I doit pointer sur
  le `(`. Apres le retour, I pointe juste apres le `)`. }
Procedure EmitOutCall(Var I:Integer; Method:TString);
Var J:Integer; M:TString;
Begin
 M:=StrUpper(Method);
 If M='LN' Then Begin
   { Out.Ln : pas d'arguments. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('printf("\n");');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('/* Out.'+Method+' sans args */');
   Exit;
 End;
 Inc(I);                     { sauter `(` }
 If M='STRING' Then Begin
   EmitRaw('printf("%s", ');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(')');
 End Else
 If M='CHAR' Then Begin
   EmitRaw('putchar((int)(');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw('))');
 End Else
 If M='INT' Then Begin
   EmitRaw('printf("%d", (int)(');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw('))');
   { Sauter une eventuelle largeur de champ (non supportee). }
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     J:=I;
     While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')'))do Inc(J);
     I:=J;
   End;
 End Else
 If(M='REAL')or(M='LONGREAL')Then Begin
   EmitRaw('printf("%g", (double)(');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw('))');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     J:=I;
     While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')'))do Inc(J);
     I:=J;
   End;
 End Else
 If M='HEX' Then Begin
   EmitRaw('printf("%X", (unsigned int)(');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw('))');
 End Else Begin
   EmitRaw('/* Out.'+Method+' non standard */ printf("%d", (int)(');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw('))');
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(';');
End;

{ Emet un appel In.X(args) -> scanf(...). }
Procedure EmitInCall(Var I:Integer; Method:TString);
Var J:Integer; M:TString;
Begin
 M:=StrUpper(Method);
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   { In.Ln, In.Open, etc. : pas d'argument. }
   If M='LN' Then EmitRaw('{ int _c; while ((_c=getchar())!=EOF && _c!=''\n''); }')
   Else EmitRaw('/* In.'+Method+' sans args */');
   Exit;
 End;
 Inc(I);
 If M='INT' Then Begin
   EmitRaw('scanf("%d", &');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(');');
 End Else
 If(M='REAL')or(M='LONGREAL')Then Begin
   EmitRaw('scanf("%lf", &');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(');');
 End Else
 If M='CHAR' Then Begin
   EmitRaw('scanf("%c", &');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(');');
 End Else
 If M='STRING' Then Begin
   EmitRaw('scanf("%s", ');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(');');
 End Else Begin
   EmitRaw('/* In.'+Method+' non standard */ scanf("%d", &');
   J:=I; EmitExprUntil(J,',)'); I:=J;
   EmitRaw(');');
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
End;

{ ============================================================
  INSTRUCTIONS DE CONTROLE
  ============================================================ }
{ Determine si le token courant est un keyword qui termine une liste
  d'instructions. }
Function StatListEnds(I:Integer):Boolean;
Begin
 StatListEnds:=False;
 If I>TokCount Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_EOF Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   If(Tokens[I].Val='END')or(Tokens[I].Val='UNTIL')or(Tokens[I].Val='ELSE')or
     (Tokens[I].Val='ELSIF')or(Tokens[I].Val='RETURN')Then StatListEnds:=True;
 End Else
 If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then StatListEnds:=True;
End;

{ Emet une suite d'instructions placee dans une accolade C entre
  delimiteurs Oberon (par ex. THEN..END, DO..END, ELSE..END). Avance I
  jusqu'au mot de fin sans le consommer. }
Procedure EmitBraceList(Var I:Integer);
Begin
 EmitRaw(' {'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF }
 EmitRaw('if (');
 EmitExpr(I);
 EmitRaw(')');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
 EmitBraceList(I);
 While(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSIF')do Begin
   Inc(I);
   EmitRaw(' else if (');
   EmitExpr(I);
   EmitRaw(')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
   EmitBraceList(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE')Then Begin
   Inc(I);
   EmitRaw(' else');
   EmitBraceList(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE }
 EmitRaw('while (');
 EmitExpr(I);
 EmitRaw(')');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 EmitBraceList(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT }
 EmitRaw('do {'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 Dec(Indent);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL')Then Inc(I);
 WriteIndent; EmitRaw('} while (!(');
 EmitExpr(I);
 EmitRaw('));');
End;

Procedure EmitLoopStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter LOOP }
 EmitRaw('for (;;)');
 EmitBraceList(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitForStatement(Var I:Integer);
Var
 IdxName,Step:TString;
Begin
 Inc(I);                     { sauter FOR }
 IdxName:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 EmitRaw('for (');
 EmitRaw(IdxName);
 If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then Inc(I);
 EmitRaw(' = ');
 EmitExprUntil(I,'');         { jusqu'a TO }
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
 EmitRaw('; ');
 EmitRaw(IdxName);
 EmitRaw(' <= ');
 EmitExprUntil(I,'');         { jusqu'a BY ou DO }
 Step:=' = '+IdxName+' + 1';
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BY')Then Begin
   Inc(I);
   Step:=' = '+IdxName+' + (';
   EmitRaw(''); { rien }
   { lire l'expression du pas dans une chaine temporaire via une astuce :
     on continue d'emettre dans Step en utilisant un buffer separe. Pour
     simplifier on emet directement dans le for. }
   EmitRaw('; '); EmitRaw(IdxName); EmitRaw(' = '); EmitRaw(IdxName); EmitRaw(' + (');
   EmitExprUntil(I,'');
   EmitRaw(')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
   EmitRaw(')');
   EmitBraceList(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
   Exit;
 End;
 EmitRaw('; '); EmitRaw(IdxName); EmitRaw(Step);
 EmitRaw(')');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 EmitBraceList(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

{ Emet une etiquette de CASE Oberon `n[, m, lo..hi] :`. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 First:Boolean;
 LowS:TString;
 J,K:Integer;
Begin
 First:=True;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':'))do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin Inc(I); Continue; End;
   If Not First Then EmitRaw(' ');
   First:=False;
   J:=I; LowS:='';
   While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':')))do Begin
     If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+OberonCharToC(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Begin
     EmitRaw('/* '+LowS+'..'); Inc(J);
     K:=J;
     While(K<=TokCount)and Not((Tokens[K].Kind=TK_PUNCT)and((Tokens[K].Val=',')or(Tokens[K].Val=':')))do Inc(K);
     While J<K do Begin EmitRaw(Tokens[J].Val); Inc(J); End;
     EmitRaw(' : utiliser if/else */ default:');
   End Else Begin
     EmitRaw('case '); EmitRaw(LowS); EmitRaw(':');
   End;
   I:=J;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
End;

Procedure EmitCaseStatement(Var I:Integer);
Var First:Boolean;
Begin
 Inc(I);                     { sauter CASE }
 EmitRaw('switch (');
 EmitExpr(I);
 EmitRaw(') {'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
 Inc(Indent);
 First:=True;
 While I<=TokCount do Begin
   { Separateur `|` entre alternatives. }
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE'))Then Begin
     If Tokens[I].Val='ELSE' Then Begin
       Inc(I);
       WriteIndent; EmitRaw('default:'); EmitLn;
       Inc(Indent);
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Begin
         If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
         WriteIndent;
         EmitStmt(I);
         EmitLn;
       End;
       WriteIndent; EmitRaw('break;'); EmitLn;
       Dec(Indent);
     End;
     Break;
   End;
   { Une etiquette de cas commence ici. }
   WriteIndent;
   EmitCaseLabels(I);
   EmitLn;
   Inc(Indent);
   While(I<=TokCount)and
         Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|'))and
         Not((Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
     WriteIndent;
     EmitStmt(I);
     EmitLn;
   End;
   WriteIndent; EmitRaw('break;'); EmitLn;
   Dec(Indent);
   First:=False;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

{ Avance J jusqu'au `,` ou `)` au niveau 0 SANS rien emettre. }
Procedure ScanArgEnd(Var J:Integer);
Var Depth:Integer;
Begin
 Depth:=0;
 While J<=TokCount do Begin
   If(Depth=0)and(Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=')'))Then Exit;
   If(Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val='(')or(Tokens[J].Val='['))Then Inc(Depth)
   Else If(Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=')')or(Tokens[J].Val=']'))Then Dec(Depth);
   Inc(J);
 End;
End;

{ Detecte les pseudo-procedures standard d'Oberon : INC, DEC, NEW, HALT,
  ABS, ASSERT, COPY, ORD, CHR, LEN. Si le token I correspond, emet le
  code C equivalent et avance I. Retourne True en cas de prise en charge. }
Function MaybeEmitStandardCall(Var I:Integer):Boolean;
Var
 Name,U:TString;
 J:Integer;
Begin
 MaybeEmitStandardCall:=False;
 If I>TokCount Then Exit;
 If Tokens[I].Kind<>TK_IDENT Then Exit;
 Name:=Tokens[I].Val;
 U:=StrUpper(Name);
 { Verifier si suivi par `(` }
 If Not((I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='('))Then Exit;
 If U='INC' Then Begin
   Inc(I,2);                  { Name(  }
   EmitRaw('(');
   EmitExprUntil(I,',)');
   EmitRaw(')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(' += (');
     EmitExprUntil(I,')');
     EmitRaw(')');
   End Else Begin
     EmitRaw('++');
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(';');
   MaybeEmitStandardCall:=True;
   Exit;
 End;
 If U='DEC' Then Begin
   Inc(I,2);
   EmitRaw('(');
   EmitExprUntil(I,',)');
   EmitRaw(')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(' -= (');
     EmitExprUntil(I,')');
     EmitRaw(')');
   End Else Begin
     EmitRaw('--');
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(';');
   MaybeEmitStandardCall:=True;
   Exit;
 End;
 If U='NEW' Then Begin
   Inc(I,2);
   EmitRaw('/* NEW : allocation a adapter manuellement */ ');
   EmitExprUntil(I,')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(' = malloc(sizeof(void*))');
   EmitRaw(';');
   UsesStdLib:=True;
   MaybeEmitStandardCall:=True;
   Exit;
 End;
 If U='HALT' Then Begin
   Inc(I,2);
   EmitRaw('exit(');
   If(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')'))Then
     EmitExprUntil(I,')')
   Else EmitRaw('0');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
   UsesStdLib:=True;
   MaybeEmitStandardCall:=True;
   Exit;
 End;
 If U='ASSERT' Then Begin
   Inc(I,2);
   EmitRaw('assert(');
   EmitExprUntil(I,',)');
   { Le second argument optionnel est un code, ignore. }
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')'))do Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
   MaybeEmitStandardCall:=True;
   Exit;
 End;
End;

{ Determine si I introduit une expression d'affectation (Ident := ...). }
Function IsAssignment(I:Integer):Boolean;
Var Depth:Integer;
Begin
 IsAssignment:=False;
 Depth:=0;
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='['))Then Inc(Depth)
   Else If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val=']'))Then Dec(Depth);
   If(Depth=0)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then Begin
     IsAssignment:=True; Exit;
   End;
   If(Depth=0)and((Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=';')or(Tokens[I].Val=')')))Then Exit;
   If(Depth=0)and(Tokens[I].Kind=TK_KEYWORD)Then Exit;
   Inc(I);
 End;
End;

{ Emet une instruction unique. }
Procedure EmitStmt(Var I:Integer);
Var
 K:TString;
 J:Integer;
 Name,U:TString;
Begin
 If I>TokCount Then Exit;
 Case Tokens[I].Kind of
   TK_KEYWORD:Begin
     K:=Tokens[I].Val;
     If K='BEGIN' Then Begin
       EmitRaw('{'); EmitLn;
       Inc(Indent);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
       Dec(Indent);
       WriteIndent; EmitRaw('}');
     End Else
     If K='IF' Then EmitIfStatement(I) Else
     If K='WHILE' Then EmitWhileStatement(I) Else
     If K='FOR' Then EmitForStatement(I) Else
     If K='REPEAT' Then EmitRepeatStatement(I) Else
     If K='LOOP' Then EmitLoopStatement(I) Else
     If K='CASE' Then EmitCaseStatement(I) Else
     If K='RETURN' Then Begin
       Inc(I);
       If(I<=TokCount)and Not StatListEnds(I)and
         Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))Then Begin
         EmitRaw('return ');
         EmitExpr(I);
         EmitRaw(';');
       End Else
         EmitRaw('return;');
     End Else
     If K='EXIT' Then Begin Inc(I); EmitRaw('break;'); End Else
     If K='WITH' Then Begin
       EmitRaw('/* WITH non supporte ; expansion manuelle requise */');
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Begin
       EmitRaw('/* mot-cle non gere : '+K+' */');
       Inc(I);
     End;
   End;
   TK_IDENT:Begin
     Name:=Tokens[I].Val;
     U:=StrUpper(Name);
     { Detection d'un appel module : Ident `.` Methode }
     If(I+2<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.')and
       (Tokens[I+2].Kind=TK_IDENT)Then Begin
       If U='OUT' Then Begin
         Inc(I,2);                 { passer Out . }
         Name:=Tokens[I].Val; Inc(I);
         EmitOutCall(I,Name);
         Exit;
       End;
       If U='IN' Then Begin
         Inc(I,2);
         Name:=Tokens[I].Val; Inc(I);
         EmitInCall(I,Name);
         Exit;
       End;
     End;
     If MaybeEmitStandardCall(I) Then Exit;
     If U='HALT' Then Begin
       Inc(I);
       EmitRaw('exit(');
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
         Inc(I); EmitExpr(I);
         If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
       End Else EmitRaw('0');
       EmitRaw(');');
       UsesStdLib:=True;
       Exit;
     End;
     { Affectation ou appel. Comme `.` est un punct distinct, on parcourt
       l'expression de gauche jusqu'au `:=` ou la fin. }
     If IsAssignment(I) Then Begin
       J:=I;
       EmitExprUntil(J,'');
       If(J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=')Then Begin
         EmitRaw(' = ');
         Inc(J);
         EmitExpr(J);
       End;
       I:=J;
       EmitRaw(';');
     End Else Begin
       J:=I;
       EmitExprUntil(J,'');
       I:=J;
       EmitRaw(';');
     End;
   End;
 Else
   { un token isole inattendu : avancer pour eviter une boucle infinie }
   Inc(I);
 End;
End;

Procedure EmitStatementList(Var I:Integer);
Begin
 While I<=TokCount do Begin
   If StatListEnds(I) Then Begin
     { RETURN apparait dans la fin d'une procedure ; on l'emet ici. }
     If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RETURN')Then Begin
       WriteIndent;
       EmitStmt(I);
       EmitLn;
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
       Continue;
     End;
     Break;
   End;
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
   WriteIndent;
   EmitStmt(I);
   EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

{ ============================================================
  DECLARATIONS (CONST / VAR / TYPE)
  ============================================================ }
{ Lit le specificateur de type Oberon a partir de I et retourne :
  - TypeS : le type C (sans le suffixe de tableau)
  - ArrSpec : suffixe de tableau eventuel (ex. `[10]`).
  Avance I a la fin du type. }
Procedure ReadOberonType(Var I:Integer; Var TypeS,ArrSpec:TString);
Var Bound:TString; J:Integer;
Begin
 TypeS:='int'; ArrSpec:='';
 If I>TokCount Then Exit;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY')Then Begin
   Inc(I);
   Bound:='';
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF'))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
       ArrSpec:=ArrSpec+'['+Bound+']';
       Bound:=''; Inc(I); Continue;
     End;
     Bound:=Bound+Tokens[I].Val;
     Inc(I);
   End;
   ArrSpec:=ArrSpec+'['+Bound+']';
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
   { Type element (recursif simple) }
   ReadOberonType(I,TypeS,Bound);
   ArrSpec:=ArrSpec+Bound;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   ReadOberonType(I,TypeS,Bound);
   TypeS:=TypeS+'*';
   ArrSpec:=Bound;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
   { Type RECORD inline non supporte dans une declaration de variable :
     on commente et on consomme jusqu'au END equilibre. }
   TypeS:='/* RECORD inline non supporte */ struct';
   J:=1; Inc(I);
   While(I<=TokCount)and(J>0)do Begin
     If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Inc(J);
     If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
       Dec(J);
       If J=0 Then Begin Inc(I); Break; End;
     End;
     Inc(I);
   End;
   Exit;
 End;
 If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^')Then Begin
   Inc(I);
   ReadOberonType(I,TypeS,Bound);
   TypeS:=TypeS+'*'; ArrSpec:=Bound;
   Exit;
 End;
 If Tokens[I].Kind=TK_IDENT Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End Else If Tokens[I].Kind=TK_KEYWORD Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End;
End;

{ Emet une declaration RECORD en typedef struct nomme. Suppose que le
  token courant est `RECORD`. Emet la struct comme type anonyme local. }
Procedure EmitRecordDecl(Var I:Integer; Const TypeName:TString);
Var
 FieldType,FieldArr,Names:TString;
 J:Integer;
 K:TString;
 T,N:TString;
Begin
 EmitRaw('typedef struct '); EmitRaw(TypeName); EmitRaw(' {'); EmitLn;
 Inc(Indent);
 Inc(I);                    { sauter RECORD }
 { Saut d'eventuelle clause d'extension : `RECORD (Base)`. }
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')'))do Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 End;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Names:=Tokens[I].Val; Inc(I);
   While(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')do Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin
       Names:=Names+', '+Tokens[I].Val; Inc(I);
     End;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
   ReadOberonType(I,FieldType,FieldArr);
   WriteIndent; EmitRaw(FieldType); EmitRaw(' ');
   { dupliquer ArrSpec apres chaque nom }
   If FieldArr<>'' Then Begin
     T:=''; J:=1; N:='';
     While J<=Length(Names) do Begin
       If Names[J]=',' Then Begin T:=T+N+FieldArr+', '; N:=''; Inc(J);
         While(J<=Length(Names))and(Names[J]=' ')do Inc(J);
       End Else Begin N:=N+Names[J]; Inc(J); End;
     End;
     If N<>'' Then T:=T+N+FieldArr;
     EmitRaw(T);
   End Else
     EmitRaw(Names);
   EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent);
 WriteIndent; EmitRaw('} '); EmitRaw(TypeName); EmitRaw(';'); EmitLn;
End;

Procedure EmitVarSection(Var I:Integer);
Var
 Names:TString;
 TypeS,ArrSpec:TString;
 J:Integer;
 K:TString;
 T,N:TString;
Begin
 Inc(I);                     { sauter VAR }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')or(K='RETURN')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Names:=Tokens[I].Val; Inc(I);
   While(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')do Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin
       Names:=Names+', '+Tokens[I].Val; Inc(I);
     End;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
   ReadOberonType(I,TypeS,ArrSpec);
   WriteIndent;
   EmitRaw(TypeS); EmitRaw(' ');
   If ArrSpec<>'' Then Begin
     T:=''; J:=1; N:='';
     While J<=Length(Names) do Begin
       While(J<=Length(Names))and(Names[J]<>',')do Begin T:=T+Names[J]; Inc(J); End;
       T:=T+ArrSpec;
       If J<=Length(Names) Then Begin T:=T+', '; Inc(J);
         While(J<=Length(Names))and(Names[J]=' ')do Inc(J);
       End;
     End;
     Names:=T;
   End;
   EmitRaw(Names); EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

Procedure EmitConstSection(Var I:Integer);
Var K:TString; J:Integer;
Begin
 Inc(I);                     { sauter CONST }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   EmitRaw('#define '); EmitRaw(Tokens[I].Val); EmitRaw(' ');
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   J:=I; EmitExprUntil(J,''); I:=J;
   EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

Procedure EmitTypeSection(Var I:Integer);
Var Name,K,TypeS,ArrSpec:TString;
Begin
 Inc(I);                     { sauter TYPE }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   { Cas RECORD nomme }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
     EmitRecordDecl(I,Name);
   End Else Begin
     ReadOberonType(I,TypeS,ArrSpec);
     EmitRaw('typedef '); EmitRaw(TypeS); EmitRaw(' '); EmitRaw(Name);
     EmitRaw(ArrSpec); EmitRaw(';'); EmitLn;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

{ ============================================================
  PROCEDURES
  ============================================================ }
Procedure EmitProcParams(Var I:Integer);
Var
 IsVar:Boolean;
 Names:TString;
 TypeS,ArrSpec:TString;
 First:Boolean;
 J:Integer;
 T,N:TString;
Begin
 EmitRaw('(');
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw(')'); Exit;
 End;
 Inc(I);
 First:=True;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')'))do Begin
   IsVar:=False;
   If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='VAR')Then Begin
     IsVar:=True; Inc(I);
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Names:=Tokens[I].Val; Inc(I);
   While(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')do Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin
       Names:=Names+', '+Tokens[I].Val; Inc(I);
     End;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
   ReadOberonType(I,TypeS,ArrSpec);
   If IsVar Then TypeS:=TypeS+'*';
   { dupliquer le type avant chaque nom (avec ArrSpec apres) }
   T:=''; J:=1; N:='';
   While J<=Length(Names) do Begin
     If Names[J]=',' Then Begin
       If Not First Then T:=T+', ';
       T:=T+TypeS+' '+N+ArrSpec;
       First:=False; N:=''; Inc(J);
       While(J<=Length(Names))and(Names[J]=' ')do Inc(J);
     End Else Begin N:=N+Names[J]; Inc(J); End;
   End;
   If N<>'' Then Begin
     If Not First Then T:=T+', ';
     T:=T+TypeS+' '+N+ArrSpec;
     First:=False;
   End;
   EmitRaw(T);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(')');
End;

{ Emet une PROCEDURE complete. }
Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,RetT:TString;
 PrevFunc:Integer;
 SavedIndent:Integer;
Begin
 Inc(I);                     { sauter PROCEDURE }
 Name:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin Name:=Tokens[I].Val; Inc(I); End;
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 RetT:='void'; IsFunc:=False;
 If(CurFunc>0)and(Funcs[CurFunc].IsFunc)Then Begin
   RetT:=Funcs[CurFunc].RetType; IsFunc:=True;
 End;
 SavedIndent:=Indent;
 EmitRaw(RetT); EmitRaw(' '); EmitRaw(Name);
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then EmitProcParams(I)
 Else EmitRaw('()');
 { sauter `: type` (deja enregistre) }
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Begin
   Inc(I);
   { lire jusqu'a `;` }
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 EmitRaw(' {'); EmitLn;
 Inc(Indent);
 { declarations locales : VAR/CONST/TYPE imbriquees }
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_KEYWORD)Then Begin
     If Tokens[I].Val='VAR'   Then EmitVarSection(I) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I) Else
     If Tokens[I].Val='TYPE'  Then EmitTypeSection(I) Else
     If Tokens[I].Val='PROCEDURE' Then Begin
       { Procedure imbriquee : C ne supporte pas, on l'emet quand meme. }
       EmitRaw('/* PROCEDURE imbriquee : portee C globale */'); EmitLn;
       EmitProcedure(I);
     End Else Break;
   End Else Break;
 End;
 { corps }
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN')Then Begin
   Inc(I);
   EmitStatementList(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
   Inc(I);
   { sauter le nom de procedure terminal `END Name;` }
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
 End;
 Dec(Indent);
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 WriteIndent; EmitRaw('}'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
 Indent:=SavedIndent;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Var I:Integer;
Begin
 EmitRaw('/* Genere par OBERON2C '+VERSION+' a partir de '+SrcName+' */'); EmitLn;
 If UsesOut Then Begin EmitRaw('#include <stdio.h>'); EmitLn; End;
 If UsesString Then Begin EmitRaw('#include <string.h>'); EmitLn; End;
 If UsesMath Then Begin EmitRaw('#include <math.h>'); EmitLn; End;
 If UsesStdLib or UsesOut Then Begin EmitRaw('#include <stdlib.h>'); EmitLn; End;
 EmitRaw('#include <assert.h>'); EmitLn;
 If ICount>0 Then Begin
   EmitRaw('/* IMPORT Oberon :');
   For I:=1 to ICount do Begin EmitRaw(' '); EmitRaw(Imports[I]); End;
   EmitRaw(' */'); EmitLn;
 End;
 EmitLn;
End;

{ ============================================================
  BLOC PRINCIPAL
  ============================================================ }
Procedure EmitTopLevel;
Var
 I:Integer;
 K:TString;
 HasMain:Boolean;
Begin
 I:=1;
 { sauter MODULE Name; }
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='MODULE')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 { IMPORT clause : deja analysee, on saute }
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IMPORT')Then Begin
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 HasMain:=False;
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='CONST' Then Begin EmitConstSection(I); Continue; End;
     If K='TYPE'  Then Begin EmitTypeSection(I); Continue; End;
     If K='VAR'   Then Begin EmitVarSection(I); Continue; End;
     If K='PROCEDURE' Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       HasMain:=True;
       EmitRaw('int main(void) {'); EmitLn;
       Inc(Indent);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
         Inc(I);
         If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I); { END Name }
       End;
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then Inc(I);
       WriteIndent; EmitRaw('return 0;'); EmitLn;
       Dec(Indent);
       EmitRaw('}'); EmitLn;
       Continue;
     End;
     If K='END' Then Begin
       Inc(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then Inc(I);
       Continue;
     End;
   End;
   Inc(I);
 End;
 If Not HasMain Then Begin
   EmitRaw('int main(void) { return 0; }'); EmitLn;
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('OBERON2C ',VERSION,' - Transpilateur Oberon vers C');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : OBERON2C source.Mod [destination.c]');
 WriteLn('Exemple : OBERON2C hello.Mod hello.c');
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
   While(I>0)and(A[I]<>'.')do Dec(I);
   If I>0 Then DstName:=Copy(A,1,I-1)+'.c'
          Else DstName:=A+'.c';
 End;
End;

Procedure OpenFiles;
Begin
 Assign(InFile,SrcName);
 {$I-}Reset(InFile);{$I+}
 If IOResult<>0 Then Begin
   WriteLn('Erreur : impossible d''ouvrir ',SrcName);
   Halt(1);
 End;
 Assign(OutFile,DstName);
 Rewrite(OutFile);
End;

Procedure CloseFiles;
Begin
 Close(InFile);
 FlushLine;
 Close(OutFile);
End;

Begin
 ParseArgs;
 OpenFiles;
 TokInit;
 Tokenize;
 Close(InFile);
 Analyze;
 OutLine:='';
 Indent:=0;
 EmitFileHeader;
 EmitTopLevel;
 FlushLine;
 Close(OutFile);
 WriteLn('OBERON2C : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procedures).');
End.
