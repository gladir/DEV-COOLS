{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Oberon
                (Oberon-2 / Oberon-07) vers Turbo Pascal / Free Pascal
                (mode TP).

  Sources : Oberon (.Mod / .ob / .ob2 / .ob07).
  Cible   : code source Pascal (.pas) compilable avec fpc -Mtp.

  Sous-ensemble pris en charge :
    MODULE/END Module., IMPORT (mappage en clause USES quand possible),
    CONST, TYPE, VAR, PROCEDURE (avec ou sans type de retour),
    parametres VAR, BEGIN..END, IF/THEN/ELSIF/ELSE/END,
    WHILE..DO..END, REPEAT..UNTIL, FOR..TO/BY..DO..END, LOOP/EXIT,
    CASE..OF (avec separateur `|`), RETURN expr.

  Mappages d'entrees/sorties :
    Out.String/Int/Real/Char/Ln  -> Write/WriteLn
    In.Int/Real/Char/String      -> Read/ReadLn

  Limitations :
    - Les ensembles (SET) Oberon sont rendus tels quels avec
      l'operateur `IN` qui existe aussi en Pascal.
    - Les procedures imbriquees Oberon sont reelles en Pascal :
      la conversion preserve l'imbrication.
    - WITH non supporte.

  Compilation : fpc -Mtp OBER2PAS.PAS
  Usage       : OBER2PAS source.Mod [destination.pas]
}
Program OBER2PAS;

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
   Name    : TString;
   RetType : TString;       { type Pascal de retour ('' si procedure) }
   IsFunc  : Boolean;
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Funcs      : Array[1..MAX_FNS] of TFuncRec;
 FuncCount  : Integer;
 FuncStack  : Array[0..32] of Integer;
 FuncSP     : Integer;
 CurFunc    : Integer;
 InFile     : Text;
 OutFile    : Text;
 SrcName    : TString;
 DstName    : TString;
 ModuleName : TString;
 SourceLine : LongInt;
 Indent     : Integer;
 OutLine    : TString;
 Imports    : Array[1..MAX_IMP] of TString;
 ICount     : Integer;
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
Var V:TString; Tmp:Char;
Begin
 V:=First;
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_'] do V:=V+NextCh;
 { Marqueur d'export Oberon-2 : `*` ou `-`. On les consomme. }
 If PeekCh='*' Then Tmp:=NextCh;
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
{ Mappage de type Oberon vers Pascal. La plupart des types ont le meme
  nom, on normalise toutefois la casse. }
Function MapOberonType(T:TString):TString;
Var U:TString;
Begin
 U:=StrUpper(T);
 If U='INTEGER'   Then MapOberonType:='Integer' Else
 If U='LONGINT'   Then MapOberonType:='LongInt' Else
 If U='HUGEINT'   Then MapOberonType:='Int64' Else
 If U='SHORTINT'  Then MapOberonType:='ShortInt' Else
 If U='BYTE'      Then MapOberonType:='Byte' Else
 If U='REAL'      Then MapOberonType:='Single' Else
 If U='LONGREAL'  Then MapOberonType:='Double' Else
 If U='CHAR'      Then MapOberonType:='Char' Else
 If U='BOOLEAN'   Then MapOberonType:='Boolean' Else
 If U='SET'       Then MapOberonType:='LongWord' Else
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
 { Modules Oberon standard : on ne les ajoute pas a la clause USES car
   ils n'existent pas en Pascal. Out/In sont mappes vers les routines
   intrinseques Write/Read. }
 If(U='OUT')or(U='IN')or(U='TEXTS')or(U='IO')or(U='OBERON')or
   (U='SYSTEM')or(U='STORAGE')or(U='MATH')or(U='MATHL')or
   (U='MATHLIB')or(U='REALMATH')or(U='STRINGS')Then Exit;
 For I:=1 to ICount do If StrUpper(Imports[I])=U Then Exit;
 Inc(ICount);
 Imports[ICount]:=Name;
End;

Procedure Analyze;
Var
 I,J:Integer;
 K:TString;
 Name,Ret:TString;
 Depth:Integer;
Begin
 FuncCount:=0;
 FuncSP:=0;
 CurFunc:=0;
 ICount:=0;
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
 For I:=1 to Indent do OutLine:=OutLine+' ';
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

{ Conversion d'une chaine Oberon `"abc"` en chaine Pascal `'abc'` avec
  doublage des apostrophes internes. }
Function OberonStringToPas(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If S[I]='''' Then R:=R+''''''
   Else R:=R+S[I];
   Inc(I);
 End;
 OberonStringToPas:=''''+R+'''';
End;

{ Conversion d'un litteral caractere Oberon `41X` (stocke `#41`) en
  notation Pascal `#65` (decimal). }
Function OberonCharToPas(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body,Num:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 Val('$'+Body,V,Code);
 If Code<>0 Then V:=0;
 Str(V,Num);
 If(V>=32)and(V<=126)and(V<>Ord(''''))Then
   OberonCharToPas:=''''+Chr(V)+''''
 Else
   OberonCharToPas:='#'+Num;
End;

{ Mappage d'un operateur Oberon vers Pascal. }
Function MapOp(Op:TString):TString;
Begin
 If Op='#' Then MapOp:='<>' Else
 If Op='&' Then MapOp:=' and ' Else
 If Op='~' Then MapOp:=' not ' Else
 MapOp:=Op;
End;

{ Mappage d'un mot-cle Oberon (utilise en expression) vers Pascal. }
Function MapKw(K:TString):TString;
Begin
 If K='OR'   Then MapKw:=' or '  Else
 If K='DIV'  Then MapKw:=' div ' Else
 If K='MOD'  Then MapKw:=' mod ' Else
 If K='IN'   Then MapKw:=' in '  Else
 If K='IS'   Then MapKw:=' is '  Else
 If K='TRUE' Then MapKw:='True'  Else
 If K='FALSE'Then MapKw:='False' Else
 If K='NIL'  Then MapKw:='nil'   Else
 MapKw:=StrLower(K);
End;

{ ============================================================
  FORWARDS et ETAT
  ============================================================ }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString); Forward;
Procedure EmitProcedure(Var I:Integer); Forward;
Procedure EmitVarSection(Var I:Integer); Forward;
Procedure EmitConstSection(Var I:Integer); Forward;
Procedure EmitTypeSection(Var I:Integer); Forward;

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

Procedure EmitOneExprTok(I:Integer);
Var V:TString;
Begin
 Case Tokens[I].Kind of
   TK_KEYWORD: EmitRaw(MapKw(Tokens[I].Val));
   TK_OP     : EmitRaw(MapOp(Tokens[I].Val));
   TK_STRING : Begin
     V:=Tokens[I].Val;
     If Length(V)=3 Then
       EmitRaw(''''+V[2]+'''')
     Else
       EmitRaw(OberonStringToPas(V));
   End;
   TK_CHAR   : EmitRaw(OberonCharToPas(Tokens[I].Val));
   TK_INT    : Begin
     V:=Tokens[I].Val;
     If(Length(V)>0)and(V[1]='$')Then EmitRaw(V) { Pascal accepte $ }
     Else EmitRaw(V);
   End;
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : EmitRaw(Tokens[I].Val);
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('^')
     Else EmitRaw(Tokens[I].Val);
   End;
 End;
End;

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
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then NeedSpaceBefore:=False;
   EmitOneExprTok(I);
   NeedSpaceBefore:=False;
   If IsOpish Then NeedSpaceBefore:=True;
   If(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=',')or(Tokens[I].Val=';'))Then
     NeedSpaceBefore:=True;
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then NeedSpaceBefore:=False;
   Inc(I);
 End;
End;

Procedure EmitExpr(Var I:Integer);
Begin EmitExprUntil(I,''); End;

{ ============================================================
  Out / In : pseudo modules d'E/S Oberon
  ============================================================ }
{ Out.X(args) -> Write/WriteLn argument. I doit pointer sur le `(`
  apres traversee de Out. ; au retour, I pointe juste apres le `)`. }
Procedure EmitOutCall(Var I:Integer; Method:TString);
Var M:TString;
Begin
 M:=StrUpper(Method);
 If M='LN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('WriteLn;');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('{ Out.'+Method+' sans args }');
   Exit;
 End;
 Inc(I);                     { sauter `(` }
 EmitRaw('Write(');
 If(M='STRING')or(M='CHAR')or(M='INT')or(M='HEX')or(M='REAL')or(M='LONGREAL')Then Begin
   EmitExprUntil(I,',)');
   { Largeur de champ optionnelle : on l'emet en specification :width. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(':');
     EmitExprUntil(I,',)');
   End;
 End Else Begin
   EmitRaw('{ Out.'+Method+' non standard } ');
   EmitExprUntil(I,',)');
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(');');
End;

{ In.X(args) -> Read/ReadLn. }
Procedure EmitInCall(Var I:Integer; Method:TString);
Var M:TString;
Begin
 M:=StrUpper(Method);
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   If M='LN' Then EmitRaw('ReadLn;')
   Else If M='OPEN' Then EmitRaw('{ In.Open : implicite en Pascal }')
   Else EmitRaw('{ In.'+Method+' sans args }');
   Exit;
 End;
 Inc(I);
 EmitRaw('Read(');
 EmitExprUntil(I,')');
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(');');
End;

{ ============================================================
  INSTRUCTIONS DE CONTROLE
  ============================================================ }
Function StatListEnds(I:Integer):Boolean;
Begin
 StatListEnds:=False;
 If I>TokCount Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_EOF Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   If(Tokens[I].Val='END')or(Tokens[I].Val='UNTIL')or(Tokens[I].Val='ELSE')or
     (Tokens[I].Val='ELSIF')Then StatListEnds:=True;
 End Else
 If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then StatListEnds:=True;
End;

{ Emet une liste d'instructions delimitee par BEGIN..END Pascal.
  Le `End` est emis SANS `;` ; le `;` final est ajoute par
  l'appelant lorsque la structure de controle est complete (apres
  le dernier Else en particulier). }
Procedure EmitBeginEnd(Var I:Integer);
Begin
 EmitLn;
 WriteIndent; EmitRaw('Begin'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('End');
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF }
 EmitRaw('If ');
 EmitExpr(I);
 EmitRaw(' Then');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
 EmitBeginEnd(I);
 While(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSIF')do Begin
   Inc(I);
   EmitLn;
   WriteIndent; EmitRaw('Else If ');
   EmitExpr(I);
   EmitRaw(' Then');
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
   EmitBeginEnd(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE')Then Begin
   Inc(I);
   EmitLn;
   WriteIndent; EmitRaw('Else');
   EmitBeginEnd(I);
 End;
 EmitRaw(';');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE }
 EmitRaw('While ');
 EmitExpr(I);
 EmitRaw(' Do');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 EmitBeginEnd(I);
 EmitRaw(';');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT }
 EmitRaw('Repeat'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL')Then Inc(I);
 WriteIndent; EmitRaw('Until ');
 EmitExpr(I);
 EmitRaw(';');
End;

Procedure EmitLoopStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter LOOP }
 EmitRaw('While True Do');
 EmitBeginEnd(I);
 EmitRaw(';');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitForStatement(Var I:Integer);
Var
 IdxName:TString;
 HasBy:Boolean;
Begin
 Inc(I);                     { sauter FOR }
 IdxName:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 EmitRaw('For ');
 EmitRaw(IdxName);
 If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then Inc(I);
 EmitRaw(':=');
 EmitExprUntil(I,'');         { jusqu'a TO }
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
 EmitRaw(' To ');
 EmitExprUntil(I,'');         { jusqu'a BY ou DO }
 HasBy:=False;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BY')Then Begin
   HasBy:=True;
   Inc(I);
   { Le pas BY n'a pas d'equivalent direct en TP. On signale en commentaire. }
   EmitRaw(' { BY ');
   EmitExprUntil(I,'');
   EmitRaw(' }');
 End;
 EmitRaw(' Do');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 EmitBeginEnd(I);
 EmitRaw(';');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

{ Emet une etiquette de CASE Oberon `n[, m, lo..hi] :`. Generation Pascal :
  des constantes simples sont separees par `,` et les plages par `..`. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 First:Boolean;
 LowS:TString;
 J,K:Integer;
Begin
 First:=True;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':'))do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     EmitRaw(', '); Inc(I); First:=False; Continue;
   End;
   First:=False;
   J:=I; LowS:='';
   While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':')))do Begin
     If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+OberonCharToPas(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Begin
     EmitRaw(LowS); EmitRaw('..'); Inc(J);
     K:=J;
     While(K<=TokCount)and Not((Tokens[K].Kind=TK_PUNCT)and((Tokens[K].Val=',')or(Tokens[K].Val=':')))do Inc(K);
     While J<K do Begin EmitRaw(Tokens[J].Val); Inc(J); End;
   End Else Begin
     EmitRaw(LowS);
   End;
   I:=J;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
 EmitRaw(':');
End;

Procedure EmitCaseStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter CASE }
 EmitRaw('Case ');
 EmitExpr(I);
 EmitRaw(' Of'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
 Inc(Indent,2);
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE'))Then Begin
     If Tokens[I].Val='ELSE' Then Begin
       Inc(I);
       WriteIndent; EmitRaw('Else'); EmitLn;
       Inc(Indent,2);
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Begin
         If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
         WriteIndent;
         EmitStmt(I);
         EmitLn;
       End;
       Dec(Indent,2);
     End;
     Break;
   End;
   WriteIndent;
   EmitCaseLabels(I);
   EmitRaw(' ');
   { Une seule instruction par branche en sortie : si plusieurs
     instructions Oberon dans la branche, on les regroupe dans un
     Begin..End Pascal. }
   If(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='|')or(Tokens[I].Val=';')))and
     Not((Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')))Then Begin
     EmitStmt(I);
   End;
   EmitLn;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('End;');
End;

{ Detecte une affectation dans le flot : Ident [...sel...] := expr. }
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
   If(Depth=0)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=';')or(Tokens[I].Val=')'))Then Exit;
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
       EmitRaw('Begin'); EmitLn;
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
       Dec(Indent,2);
       WriteIndent; EmitRaw('End;');
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
         { return expr : assigner au nom de fonction puis Exit. }
         If(CurFunc>0)and Funcs[CurFunc].IsFunc Then Begin
           EmitRaw(Funcs[CurFunc].Name);
           EmitRaw(':=');
           EmitExpr(I);
           EmitRaw('; Exit;');
         End Else Begin
           EmitRaw('{ RETURN avec valeur dans une procedure } Exit;');
           { consommer l'expression }
           EmitExpr(I);
         End;
       End Else
         EmitRaw('Exit;');
     End Else
     If K='EXIT' Then Begin Inc(I); EmitRaw('Break;'); End Else
     If K='WITH' Then Begin
       EmitRaw('{ WITH Oberon non supporte ; expansion manuelle requise }');
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Begin
       EmitRaw('{ mot-cle non gere : '+K+' }');
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
     { Affectation ou appel. }
     If IsAssignment(I) Then Begin
       J:=I;
       EmitExprUntil(J,'');
       If(J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=')Then Begin
         EmitRaw(':=');
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
   Inc(I);
 End;
End;

Procedure EmitStatementList(Var I:Integer);
Begin
 While I<=TokCount do Begin
   If StatListEnds(I)Then Break;
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
{ Lit un specificateur de type Oberon a partir de I et le rend en Pascal.
  Avance I a la fin du type. }
Procedure ReadOberonTypeS(Var I:Integer; Var TypeS:TString);
Var Bound,Inner:TString; J:Integer;
Begin
 TypeS:='Integer';
 If I>TokCount Then Exit;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY')Then Begin
   Inc(I);
   { Open array : ARRAY OF T (sans bornes). }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Begin
     Inc(I);
     ReadOberonTypeS(I,Inner);
     { Cas idiomatique Oberon : ARRAY OF CHAR -> String en Pascal. }
     If Inner='Char' Then TypeS:='String'
     Else TypeS:='Array of '+Inner;
     Exit;
   End;
   { Plusieurs dimensions separees par `,` : on les chaine. }
   TypeS:='Array[';
   Bound:='';
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF'))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
       If Bound<>'' Then TypeS:=TypeS+'0..(('+Bound+')-1), '
       Else TypeS:=TypeS+'0..0, ';
       Bound:=''; Inc(I); Continue;
     End;
     Bound:=Bound+Tokens[I].Val;
     Inc(I);
   End;
   If Bound<>'' Then TypeS:=TypeS+'0..(('+Bound+')-1)'
   Else TypeS:=TypeS+'0..0';
   TypeS:=TypeS+'] of ';
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
   ReadOberonTypeS(I,Inner);
   TypeS:=TypeS+Inner;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   ReadOberonTypeS(I,Inner);
   TypeS:='^'+Inner;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
   { Type RECORD inline non gere ici. }
   TypeS:='{ RECORD inline non supporte } LongInt';
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
   ReadOberonTypeS(I,Inner);
   TypeS:='^'+Inner;
   Exit;
 End;
 If Tokens[I].Kind=TK_IDENT Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End Else If Tokens[I].Kind=TK_KEYWORD Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End;
End;

{ Emet un RECORD nomme : `Type Name = Record ... End;`. Suppose I sur RECORD. }
Procedure EmitRecordDecl(Var I:Integer; Const TypeName:TString);
Var FieldType,Names:TString;
Begin
 EmitRaw(TypeName); EmitRaw(' = Record'); EmitLn;
 Inc(Indent,2);
 Inc(I);                    { sauter RECORD }
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
   ReadOberonTypeS(I,FieldType);
   WriteIndent; EmitRaw(Names); EmitRaw(': '); EmitRaw(FieldType); EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('End;'); EmitLn;
End;

Procedure EmitVarSection(Var I:Integer);
Var
 Names,TypeS:TString;
 K:TString;
 First:Boolean;
Begin
 Inc(I);                     { sauter VAR }
 WriteIndent; EmitRaw('Var'); EmitLn;
 Inc(Indent,2);
 First:=True;
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
   ReadOberonTypeS(I,TypeS);
   WriteIndent;
   EmitRaw(Names); EmitRaw(': '); EmitRaw(TypeS); EmitRaw(';'); EmitLn;
   First:=False;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 Dec(Indent,2);
End;

Procedure EmitConstSection(Var I:Integer);
Var K:TString; J:Integer;
Begin
 Inc(I);                     { sauter CONST }
 WriteIndent; EmitRaw('Const'); EmitLn;
 Inc(Indent,2);
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   WriteIndent; EmitRaw(Tokens[I].Val); EmitRaw(' = ');
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   J:=I; EmitExprUntil(J,''); I:=J;
   EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 Dec(Indent,2);
End;

Procedure EmitTypeSection(Var I:Integer);
Var Name,K,TypeS:TString;
Begin
 Inc(I);                     { sauter TYPE }
 WriteIndent; EmitRaw('Type'); EmitLn;
 Inc(Indent,2);
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   { RECORD nomme }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
     WriteIndent;
     EmitRecordDecl(I,Name);
   End Else Begin
     ReadOberonTypeS(I,TypeS);
     WriteIndent; EmitRaw(Name); EmitRaw(' = '); EmitRaw(TypeS); EmitRaw(';'); EmitLn;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 Dec(Indent,2);
End;

{ ============================================================
  PROCEDURES
  ============================================================ }
Procedure EmitProcParams(Var I:Integer);
Var
 IsVar:Boolean;
 Names,TypeS:TString;
 First:Boolean;
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
   ReadOberonTypeS(I,TypeS);
   If Not First Then EmitRaw('; ');
   If IsVar Then EmitRaw('Var ');
   EmitRaw(Names); EmitRaw(': '); EmitRaw(TypeS);
   First:=False;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(')');
End;

Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,RetT:TString;
 PrevFunc:Integer;
Begin
 Inc(I);                     { sauter PROCEDURE }
 Name:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin Name:=Tokens[I].Val; Inc(I); End;
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 RetT:=''; IsFunc:=False;
 If(CurFunc>0)and Funcs[CurFunc].IsFunc Then Begin
   RetT:=Funcs[CurFunc].RetType; IsFunc:=True;
 End;
 WriteIndent;
 If IsFunc Then EmitRaw('Function ') Else EmitRaw('Procedure ');
 EmitRaw(Name);
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then EmitProcParams(I);
 { sauter `: type` (deja enregistre) }
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Begin
   Inc(I);
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
 End;
 If IsFunc Then Begin EmitRaw(': '); EmitRaw(RetT); End;
 EmitRaw(';'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 { declarations locales : VAR/CONST/TYPE/PROCEDURE imbriquees }
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_KEYWORD)Then Begin
     If Tokens[I].Val='VAR'   Then EmitVarSection(I) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I) Else
     If Tokens[I].Val='TYPE'  Then EmitTypeSection(I) Else
     If Tokens[I].Val='PROCEDURE' Then EmitProcedure(I)
     Else Break;
   End Else Break;
 End;
 { corps }
 WriteIndent; EmitRaw('Begin'); EmitLn;
 Inc(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN')Then Begin
   Inc(I);
   EmitStatementList(I);
 End;
 Dec(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
   Inc(I);
   { sauter le nom de procedure terminal `END Name;` }
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 WriteIndent; EmitRaw('End;'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Var I:Integer;
Begin
 EmitRaw('{ Genere par OBER2PAS '+VERSION+' a partir de '+SrcName+' }'); EmitLn;
 EmitRaw('Program '); EmitRaw(ModuleName); EmitRaw(';'); EmitLn;
 If ICount>0 Then Begin
   EmitRaw('Uses');
   For I:=1 to ICount do Begin
     If I>1 Then EmitRaw(',');
     EmitRaw(' '); EmitRaw(Imports[I]);
   End;
   EmitRaw(';'); EmitLn;
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
 { IMPORT }
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
       EmitRaw('Begin'); EmitLn;
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
         Inc(I);
         If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
       End;
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then Inc(I);
       Dec(Indent,2);
       EmitRaw('End.'); EmitLn;
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
   EmitRaw('Begin'); EmitLn;
   EmitRaw('End.'); EmitLn;
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('OBER2PAS ',VERSION,' - Transpilateur Oberon vers Turbo/Free Pascal');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : OBER2PAS source.Mod [destination.pas]');
 WriteLn('Exemple : OBER2PAS hello.Mod hello.pas');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.pas'
          Else DstName:=A+'.pas';
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
 WriteLn('OBER2PAS : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procedures).');
End.
