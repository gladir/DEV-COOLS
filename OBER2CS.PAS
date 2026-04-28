{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Oberon
                (Oberon-2 / Oberon-07) vers C# (.cs).

  Sources : Oberon (.Mod / .ob / .ob2 / .ob07).
  Cible   : code source C# (.cs) compilable avec un compilateur C#
            standard (csc, mcs, dotnet).

  Le module Oberon est emis sous la forme d'une classe C# statique
  contenant champs, methodes statiques et un `Main()` quand un bloc
  d'initialisation Oberon est present.

  Sous-ensemble pris en charge :
    MODULE/END Module., IMPORT (mappage en `using` quand possible),
    CONST, TYPE, VAR, PROCEDURE (avec ou sans type de retour),
    parametres VAR (mappes en `ref`), BEGIN..END,
    IF/THEN/ELSIF/ELSE/END, WHILE..DO..END, REPEAT..UNTIL,
    FOR..TO/BY..DO..END, LOOP/EXIT, CASE..OF (avec separateur `|`),
    RETURN expr.

  Mappages d'entrees/sorties :
    Out.String/Int/Real/Char         -> Console.Write
    Out.Ln                           -> Console.WriteLine()
    In.Int/Real/Char/String          -> Console.ReadLine + parse
    In.Ln                            -> Console.ReadLine

  Compilation : fpc -Mtp OBER2CS.PAS
  Usage       : OBER2CS source.Mod [destination.cs]
}
Program OBER2CS;

Const
 VERSION = '1.0';
 MAX_TOK = 65535;
 MAX_FNS = 1024;
 MAX_IMP = 64;
 MAX_TYPES = 256;

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
   RetType : TString;       { type C# de retour ('' si void) }
   IsFunc  : Boolean;
 End;
 TTypeRec = Record
   Name : TString;          { nom Oberon }
   Kind : (TYK_RECORD, TYK_ARRAY, TYK_OTHER);
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Funcs      : Array[1..MAX_FNS] of TFuncRec;
 FuncCount  : Integer;
 CurFunc    : Integer;
 Types      : Array[1..MAX_TYPES] of TTypeRec;
 TypeCount  : Integer;
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
 HasMain    : Boolean;

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
 C,Suffix:Char;
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
   AddToken(TK_INT,'0x'+V);
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
Function MapOberonType(T:TString):TString;
Var U:TString;
Begin
 U:=StrUpper(T);
 If U='INTEGER'   Then MapOberonType:='int' Else
 If U='LONGINT'   Then MapOberonType:='long' Else
 If U='HUGEINT'   Then MapOberonType:='long' Else
 If U='SHORTINT'  Then MapOberonType:='sbyte' Else
 If U='BYTE'      Then MapOberonType:='byte' Else
 If U='REAL'      Then MapOberonType:='float' Else
 If U='LONGREAL'  Then MapOberonType:='double' Else
 If U='CHAR'      Then MapOberonType:='char' Else
 If U='BOOLEAN'   Then MapOberonType:='bool' Else
 If U='SET'       Then MapOberonType:='uint' Else
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
 { Modules Oberon standard : pas de `using` (mappage natif). }
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
 CurFunc:=0;
 ICount:=0;
 TypeCount:=0;
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

{ Conversion d'une chaine Oberon `"abc"` en chaine C# `"abc"` avec
  echappement des `"` et `\`. Si la chaine contient un seul caractere,
  on emet un `'c'` quand le caractere est un litteral simple. }
Function OberonStringToCS(S:TString):TString;
Var
 I:Integer;
 R:TString;
 C:Char;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   C:=S[I];
   If C='\' Then R:=R+'\\'
   Else If C='"' Then R:=R+'\"'
   Else If C=#10 Then R:=R+'\n'
   Else If C=#13 Then R:=R+'\r'
   Else If C=#9  Then R:=R+'\t'
   Else R:=R+C;
   Inc(I);
 End;
 OberonStringToCS:='"'+R+'"';
End;

{ Conversion d'un litteral caractere Oberon `41X` (stocke `#41`) en
  notation C# `'A'` ou `'\u0041'`. }
Function OberonCharToCS(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body,H:TString;
 I:Integer;
Begin
 Body:=Copy(S,2,Length(S)-1);
 Val('$'+Body,V,Code);
 If Code<>0 Then V:=0;
 If(V>=32)and(V<=126)and(V<>Ord(''''))and(V<>Ord('\'))Then Begin
   OberonCharToCS:=''''+Chr(V)+''''; Exit;
 End;
 If V=Ord('''')Then Begin OberonCharToCS:='''\'''''; Exit; End;
 If V=Ord('\') Then Begin OberonCharToCS:='''\\'''; Exit; End;
 { Sinon : '\uXXXX' }
 H:='';
 For I:=1 to 4 do Begin
   Case(V Shr ((4-I)*4))and 15 of
     0..9 : H:=H+Chr(Ord('0')+((V Shr ((4-I)*4))and 15));
     10..15:H:=H+Chr(Ord('A')+((V Shr ((4-I)*4))and 15)-10);
   End;
 End;
 OberonCharToCS:='''\u'+H+'''';
End;

{ Mappage d'un operateur Oberon vers C#. }
Function MapOp(Op:TString):TString;
Begin
 If Op='#'  Then MapOp:='!=' Else
 If Op='&'  Then MapOp:='&&' Else
 If Op='~'  Then MapOp:='!' Else
 If Op='='  Then MapOp:='==' Else
 If Op=':=' Then MapOp:='=' Else
 MapOp:=Op;
End;

{ Mappage d'un mot-cle Oberon (utilise en expression) vers C#. }
Function MapKw(K:TString):TString;
Begin
 If K='OR'   Then MapKw:='||'  Else
 If K='DIV'  Then MapKw:='/'   Else
 If K='MOD'  Then MapKw:='%'   Else
 If K='IN'   Then MapKw:='/* IN */'   Else
 If K='IS'   Then MapKw:='is'  Else
 If K='TRUE' Then MapKw:='true'  Else
 If K='FALSE'Then MapKw:='false' Else
 If K='NIL'  Then MapKw:='null'  Else
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
Procedure EmitVarSection(Var I:Integer; AsField:Boolean); Forward;
Procedure EmitConstSection(Var I:Integer; AsField:Boolean); Forward;
Procedure EmitTypeSection(Var I:Integer); Forward;
Procedure ReadOberonTypeS(Var I:Integer; Var TypeS:TString;
                          Var IsArray:Boolean; Var ArrSize:TString); Forward;

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
       EmitRaw(OberonStringToCS(V));
   End;
   TK_CHAR   : EmitRaw(OberonCharToCS(Tokens[I].Val));
   TK_INT    : EmitRaw(Tokens[I].Val);
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : EmitRaw(Tokens[I].Val);
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('') { dereferencement implicite en C# }
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
{ Out.X(args) -> Console.Write/WriteLine. }
Procedure EmitOutCall(Var I:Integer; Method:TString);
Var M:TString;
Begin
 M:=StrUpper(Method);
 If M='LN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('Console.WriteLine();');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('/* Out.'+Method+' sans args */');
   Exit;
 End;
 Inc(I);                     { sauter `(` }
 EmitRaw('Console.Write(');
 If(M='STRING')or(M='CHAR')or(M='INT')or(M='HEX')or(M='REAL')or(M='LONGREAL')Then Begin
   EmitExprUntil(I,',)');
   { Largeur de champ optionnelle : on l'emet en chaine de format
     C# style "{0,width}" via ToString -- on la met en commentaire. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(' /* width=');
     EmitExprUntil(I,',)');
     EmitRaw(' */');
   End;
 End Else Begin
   EmitRaw('/* Out.'+Method+' */ ');
   EmitExprUntil(I,',)');
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 EmitRaw(');');
End;

{ In.X(args) -> Console.ReadLine + parse. Implementation tres simple :
  In.Int(x) -> x = int.Parse(Console.ReadLine());
  In.Real(x) -> x = double.Parse(Console.ReadLine());
  In.Char(c) -> c = (char)Console.Read();
  In.String(s) -> s = Console.ReadLine();
  In.Ln -> Console.ReadLine(); }
Procedure EmitInCall(Var I:Integer; Method:TString);
Var
 M:TString;
 Target:TString;
 Save,J:Integer;
Begin
 M:=StrUpper(Method);
 If M='LN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('Console.ReadLine();');
   Exit;
 End;
 If M='OPEN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('/* In.Open : implicite en C# */');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('/* In.'+Method+' sans args */');
   Exit;
 End;
 Inc(I);
 { Capturer la cible (jusqu'a `)`). }
 Target:='';
 Save:=Indent; Indent:=0;
 J:=Length(OutLine);
 EmitExprUntil(I,')');
 Target:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 Indent:=Save;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 If M='INT' Then EmitRaw(Target+' = int.Parse(Console.ReadLine());')
 Else If M='LONGINT' Then EmitRaw(Target+' = long.Parse(Console.ReadLine());')
 Else If M='REAL' Then EmitRaw(Target+' = float.Parse(Console.ReadLine());')
 Else If M='LONGREAL' Then EmitRaw(Target+' = double.Parse(Console.ReadLine());')
 Else If M='CHAR' Then EmitRaw(Target+' = (char)Console.Read();')
 Else If M='STRING' Then EmitRaw(Target+' = Console.ReadLine();')
 Else If M='NAME' Then EmitRaw(Target+' = Console.ReadLine();')
 Else EmitRaw('/* In.'+Method+' */ '+Target+' = Console.ReadLine();');
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

Procedure EmitBlock(Var I:Integer);
Begin
 EmitRaw(' {'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('}');
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF }
 EmitRaw('if (');
 EmitExpr(I);
 EmitRaw(')');
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
 EmitBlock(I);
 While(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSIF')do Begin
   Inc(I);
   EmitRaw(' else if (');
   EmitExpr(I);
   EmitRaw(')');
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
   EmitBlock(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE')Then Begin
   Inc(I);
   EmitRaw(' else');
   EmitBlock(I);
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
 EmitBlock(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT }
 EmitRaw('do {'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL')Then Inc(I);
 WriteIndent; EmitRaw('} while (!(');
 EmitExpr(I);
 EmitRaw('));');
End;

Procedure EmitLoopStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter LOOP }
 EmitRaw('while (true)');
 EmitBlock(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

Procedure EmitForStatement(Var I:Integer);
Var
 IdxName,StartE,EndE,StepE:TString;
 Save:Integer;
 J:Integer;
Begin
 Inc(I);                     { sauter FOR }
 IdxName:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then Inc(I);
 { Capturer expressions. }
 Save:=Indent; Indent:=0;
 J:=Length(OutLine);
 EmitExprUntil(I,'');         { jusqu'a TO }
 StartE:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
 J:=Length(OutLine);
 EmitExprUntil(I,'');         { jusqu'a BY ou DO }
 EndE:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 StepE:='1';
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BY')Then Begin
   Inc(I);
   J:=Length(OutLine);
   EmitExprUntil(I,'');
   StepE:=Copy(OutLine,J+1,Length(OutLine)-J);
   OutLine:=Copy(OutLine,1,J);
 End;
 Indent:=Save;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 { Si pas negatif, utiliser <= ; sinon >=. On ne peut savoir
   sans evaluer ; on emet la version positive par defaut. }
 If(Length(StepE)>0)and(StepE[1]='-')Then
   EmitRaw('for ('+IdxName+' ='+StartE+'; '+IdxName+' >='+EndE+'; '+IdxName+' +='+StepE+')')
 Else
   EmitRaw('for ('+IdxName+' ='+StartE+'; '+IdxName+' <='+EndE+'; '+IdxName+' +='+StepE+')');
 EmitBlock(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
End;

{ Emet une etiquette de CASE Oberon `n[, m, lo..hi] :` en branches
  C# `case X: case Y: ...`. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 LowS:TString;
 J,K:Integer;
 First:Boolean;
Begin
 First:=True;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':'))do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin Inc(I); Continue; End;
   J:=I; LowS:='';
   While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':')))do Begin
     If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+OberonCharToCS(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Begin
     { Plage : C# n'a pas de plage en switch classique ; on emet un
       commentaire et on considere la borne basse. }
     If Not First Then EmitLn;
     WriteIndent; EmitRaw('case '+LowS+': /* .. */');
     Inc(J);
     K:=J;
     While(K<=TokCount)and Not((Tokens[K].Kind=TK_PUNCT)and((Tokens[K].Val=',')or(Tokens[K].Val=':')))do Inc(K);
     I:=K;
   End Else Begin
     If Not First Then EmitLn;
     WriteIndent; EmitRaw('case '+LowS+':');
     I:=J;
   End;
   First:=False;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
End;

Procedure EmitCaseStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter CASE }
 EmitRaw('switch (');
 EmitExpr(I);
 EmitRaw(') {'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE'))Then Begin
     If Tokens[I].Val='ELSE' Then Begin
       Inc(I);
       WriteIndent; EmitRaw('default:'); EmitLn;
       Inc(Indent,2);
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Begin
         If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
         WriteIndent; EmitStmt(I); EmitLn;
       End;
       WriteIndent; EmitRaw('break;'); EmitLn;
       Dec(Indent,2);
     End;
     Break;
   End;
   EmitCaseLabels(I);
   EmitLn;
   Inc(Indent,2);
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|'))and
     Not((Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
     WriteIndent; EmitStmt(I); EmitLn;
   End;
   WriteIndent; EmitRaw('break;'); EmitLn;
   Dec(Indent,2);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 WriteIndent; EmitRaw('}');
End;

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
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
       Dec(Indent,2);
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
       EmitRaw('/* WITH Oberon non supporte */');
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
     If(I+2<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.')and
       (Tokens[I+2].Kind=TK_IDENT)Then Begin
       If U='OUT' Then Begin
         Inc(I,2);
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
{ Lit un specificateur de type Oberon. Renvoie le type C# de base dans
  TypeS, et les eventuelles dimensions de tableau dans IsArray/ArrSize.
  ArrSize est une expression C# pour la taille (cas mono-dim). Pour les
  tableaux multi-dim ou imbriques, on renvoie un type complexe. }
Procedure ReadOberonTypeS(Var I:Integer; Var TypeS:TString;
                          Var IsArray:Boolean; Var ArrSize:TString);
Var
 InnerT,InnerSize:TString;
 InnerArr:Boolean;
 J:Integer;
 SizeBuf:TString;
Begin
 IsArray:=False;
 ArrSize:='';
 TypeS:='int';
 If I>TokCount Then Exit;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY')Then Begin
   Inc(I);
   IsArray:=True;
   { ARRAY OF T (open array) -> T[] sans taille. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Begin
     Inc(I);
     ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
     If(StrUpper(InnerT)='CHAR')and Not InnerArr Then Begin
       TypeS:='string'; IsArray:=False;
     End Else If InnerArr Then Begin
       TypeS:=InnerT+'[]';
     End Else Begin
       TypeS:=InnerT+'[]';
     End;
     Exit;
   End;
   { ARRAY N [, M] OF T -> T[N] (avec allocation new T[N]). }
   SizeBuf:='';
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF'))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin Inc(I); Continue; End;
     If SizeBuf<>'' Then SizeBuf:=SizeBuf+'*';
     SizeBuf:=SizeBuf+Tokens[I].Val;
     Inc(I);
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
   ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
   { Cas idiomatique : ARRAY n OF CHAR -> string (taille comme commentaire). }
   If(StrUpper(InnerT)='CHAR')and Not InnerArr Then Begin
     TypeS:='string'; IsArray:=False; ArrSize:=SizeBuf;
   End Else Begin
     TypeS:=InnerT+'[]';
     ArrSize:=SizeBuf;
   End;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
   { POINTER TO T en Oberon -> reference C# vers T (struct/class). }
   If InnerArr Then TypeS:=InnerT
   Else TypeS:=InnerT;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
   { Type RECORD inline non gere ici (les RECORD nommes sont traites
     dans EmitTypeSection). }
   TypeS:='/* RECORD inline non supporte */ object';
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
   ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
   TypeS:=InnerT;
   Exit;
 End;
 If Tokens[I].Kind=TK_IDENT Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End Else If Tokens[I].Kind=TK_KEYWORD Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End;
End;

{ Emet un RECORD nomme : `struct Name { ... }`. Suppose I sur RECORD. }
Procedure EmitRecordDecl(Var I:Integer; Const TypeName:TString);
Var
 FieldType,Names,Sz:TString;
 Arr:Boolean;
Begin
 EmitRaw('public struct '); EmitRaw(TypeName); EmitRaw(' {'); EmitLn;
 Inc(Indent,2);
 Inc(I);                     { sauter RECORD }
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
   ReadOberonTypeS(I,FieldType,Arr,Sz);
   WriteIndent;
   EmitRaw('public '); EmitRaw(FieldType); EmitRaw(' '); EmitRaw(Names); EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('}'); EmitLn;
End;

{ Emet une declaration VAR. AsField=True quand on est au niveau du
  module (champs statiques de la classe), sinon variables locales. }
Procedure EmitVarSection(Var I:Integer; AsField:Boolean);
Var
 Names,TypeS,Sz:TString;
 K:TString;
 Arr:Boolean;
 NameList:Array[1..32] of TString;
 NameCount,N:Integer;
 SubName:TString;
 P,Start:Integer;
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
   ReadOberonTypeS(I,TypeS,Arr,Sz);
   { Decouper Names. }
   NameCount:=0;
   Start:=1;
   For P:=1 to Length(Names) do Begin
     If Names[P]=',' Then Begin
       Inc(NameCount);
       NameList[NameCount]:=Copy(Names,Start,P-Start);
       Start:=P+1;
       While(Start<=Length(Names))and(Names[Start]=' ')do Inc(Start);
     End;
   End;
   Inc(NameCount);
   NameList[NameCount]:=Copy(Names,Start,Length(Names)-Start+1);
   For N:=1 to NameCount do Begin
     SubName:=NameList[N];
     WriteIndent;
     If AsField Then EmitRaw('static ');
     EmitRaw(TypeS); EmitRaw(' '); EmitRaw(SubName);
     If Arr and(Sz<>'')Then Begin
       EmitRaw(' = new '); EmitRaw(Copy(TypeS,1,Length(TypeS)-2));
       EmitRaw('['); EmitRaw(Sz); EmitRaw(']');
     End;
     EmitRaw(';'); EmitLn;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

Procedure EmitConstSection(Var I:Integer; AsField:Boolean);
Var K:TString; J:Integer; Name:TString;
Begin
 Inc(I);                     { sauter CONST }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   WriteIndent;
   { On emet en `const var X = expr;`. Type infere par valeur :
     entier, reel, chaine, etc. On utilise `static readonly` pour
     permettre des expressions complexes ; au niveau local on
     utilise `const`. }
   If AsField Then EmitRaw('static readonly var ')
   Else EmitRaw('const var ');
   { C# n'accepte pas `var` pour const/static readonly. On utilise
     une approche plus simple : en C#, `const` exige un type
     explicite ; on utilise `static readonly object` au niveau
     module et on laisse le compilateur typer si possible. }
   { Inversion : on retravaille en ne pretendant pas connaitre le
     type. On tente int et on revertit. }
   { Pour rester correct, on emet `static readonly int` -- mais
     c'est faux pour les chaines. Solution : examiner le premier
     token de la valeur pour deviner. }
   { On annule la ligne precedente et on regenere. }
   OutLine:=Copy(OutLine,1,Length(OutLine));
   { Reset partiel. }
 End;
 { Remarque : la version simplifiee suivante remplace la logique
   ci-dessus. }
End;

{ Version finale de EmitConstSection : on infere le type depuis la
  premiere valeur et on emet `const T NAME = expr;`. }
Procedure EmitConstSection2(Var I:Integer; AsField:Boolean);
Var K,Name,TypeS:TString; J:Integer;
Begin
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If(K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or(K='PROCEDURE')or
       (K='END')or(K='IMPORT')Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')Then Inc(I);
   { Inferer le type depuis le token suivant. }
   TypeS:='int';
   If I<=TokCount Then Begin
     Case Tokens[I].Kind of
       TK_INT  : TypeS:='int';
       TK_REAL : TypeS:='double';
       TK_STRING: TypeS:='string';
       TK_CHAR : TypeS:='char';
       TK_KEYWORD: If(Tokens[I].Val='TRUE')or(Tokens[I].Val='FALSE')Then TypeS:='bool';
     End;
   End;
   WriteIndent;
   If AsField Then EmitRaw('const ') Else EmitRaw('const ');
   EmitRaw(TypeS); EmitRaw(' '); EmitRaw(Name); EmitRaw(' = ');
   J:=I; EmitExprUntil(J,''); I:=J;
   EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

Procedure EmitTypeSection(Var I:Integer);
Var Name,K,TypeS,Sz:TString; Arr:Boolean;
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
   { POINTER TO RECORD -> on saute le POINTER et on emet une class. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
     WriteIndent;
     EmitRecordDecl(I,Name);
   End Else Begin
     ReadOberonTypeS(I,TypeS,Arr,Sz);
     WriteIndent; EmitRaw('// type alias : '); EmitRaw(Name); EmitRaw(' = '); EmitRaw(TypeS); EmitLn;
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
 Names,TypeS,Sz:TString;
 First:Boolean;
 Arr:Boolean;
 NameList:Array[1..32] of TString;
 NameCount,N:Integer;
 SubName:TString;
 P,Start:Integer;
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
   ReadOberonTypeS(I,TypeS,Arr,Sz);
   { Decouper Names. }
   NameCount:=0;
   Start:=1;
   For P:=1 to Length(Names) do Begin
     If Names[P]=',' Then Begin
       Inc(NameCount);
       NameList[NameCount]:=Copy(Names,Start,P-Start);
       Start:=P+1;
       While(Start<=Length(Names))and(Names[Start]=' ')do Inc(Start);
     End;
   End;
   Inc(NameCount);
   NameList[NameCount]:=Copy(Names,Start,Length(Names)-Start+1);
   For N:=1 to NameCount do Begin
     SubName:=NameList[N];
     If Not First Then EmitRaw(', ');
     If IsVar Then EmitRaw('ref ');
     EmitRaw(TypeS); EmitRaw(' '); EmitRaw(SubName);
     First:=False;
   End;
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
 EmitRaw('public static ');
 If IsFunc Then EmitRaw(RetT) Else EmitRaw('void');
 EmitRaw(' '); EmitRaw(Name);
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then EmitProcParams(I)
 Else EmitRaw('()');
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Begin
   Inc(I);
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
 End;
 EmitRaw(' {'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 Inc(Indent,2);
 { declarations locales : VAR/CONST/TYPE imbriquees. Les PROCEDURE
   imbriquees Oberon n'ont pas d'equivalent en C# : on les emet
   comme methodes statiques separees apres celle-ci (mais pour
   simplifier, on les emet apres la fin du corps). }
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_KEYWORD)Then Begin
     If Tokens[I].Val='VAR'   Then EmitVarSection(I,False) Else
     If Tokens[I].Val='CONST' Then Begin Inc(I); EmitConstSection2(I,False); End Else
     If Tokens[I].Val='TYPE'  Then EmitTypeSection(I) Else
     If Tokens[I].Val='PROCEDURE' Then Begin
       { Methode imbriquee : non supportee en C#. On emet un
         commentaire et on consomme la procedure (en sautant le
         corps). }
       WriteIndent; EmitRaw('// procedure imbriquee non supportee en C# : '); EmitLn;
       { On consomme jusqu'au END Name; final. }
       Inc(I);
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Inc(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
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
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('}'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Var I:Integer;
Begin
 EmitRaw('// Genere par OBER2CS '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw('using System;'); EmitLn;
 For I:=1 to ICount do Begin
   EmitRaw('using '); EmitRaw(Imports[I]); EmitRaw(';'); EmitLn;
 End;
 EmitLn;
 EmitRaw('public static class '); EmitRaw(ModuleName); EmitRaw(' {'); EmitLn;
 EmitLn;
 Inc(Indent,2);
End;

Procedure EmitFileFooter;
Begin
 Dec(Indent,2);
 EmitRaw('}'); EmitLn;
End;

{ ============================================================
  BLOC PRINCIPAL
  ============================================================ }
Procedure EmitTopLevel;
Var
 I:Integer;
 K:TString;
Begin
 I:=1;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='MODULE')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IMPORT')Then Begin
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 HasMain:=False;
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='CONST' Then Begin Inc(I); EmitConstSection2(I,True); Continue; End;
     If K='TYPE'  Then Begin EmitTypeSection(I); Continue; End;
     If K='VAR'   Then Begin EmitVarSection(I,True); Continue; End;
     If K='PROCEDURE' Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       HasMain:=True;
       WriteIndent; EmitRaw('public static void Main() {'); EmitLn;
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
         Inc(I);
         If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
       End;
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then Inc(I);
       Dec(Indent,2);
       WriteIndent; EmitRaw('}'); EmitLn;
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
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('OBER2CS ',VERSION,' - Transpilateur Oberon vers C# (C Sharp)');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : OBER2CS source.Mod [destination.cs]');
 WriteLn('Exemple : OBER2CS hello.Mod hello.cs');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.cs'
          Else DstName:=A+'.cs';
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
 EmitFileFooter;
 FlushLine;
 Close(OutFile);
 WriteLn('OBER2CS : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procedures).');
End.
