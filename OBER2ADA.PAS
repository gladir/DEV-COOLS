{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal du langage Oberon
                (Oberon-2 / Oberon-07) vers Ada (.adb).

  Sources : Oberon (.Mod / .ob / .ob2 / .ob07).
  Cible   : code source Ada (.adb) compilable avec un compilateur Ada
            standard (gnat).

  Le module Oberon est emis sous la forme d une procedure Ada
  contenant la declaration des constantes, types, variables et
  sous-programmes, suivie d un bloc d instructions (begin .. end).

  Sous-ensemble pris en charge :
    MODULE/END Module., IMPORT (mappage en `with ...; use ...;`),
    CONST, TYPE, VAR, PROCEDURE (avec ou sans type de retour),
    parametres VAR (mappes en `in out`), BEGIN..END,
    IF/THEN/ELSIF/ELSE/END, WHILE..DO..END, REPEAT..UNTIL,
    FOR..TO/BY..DO..END, LOOP/EXIT, CASE..OF (avec separateur `|`),
    RETURN expr.

  Mappages d entrees/sorties :
    Out.String/Int/Real/Char         -> Ada.Text_IO.Put / Ada.Integer_Text_IO.Put
    Out.Ln                           -> Ada.Text_IO.New_Line
    In.Int/Real/Char/String          -> Ada.Integer_Text_IO.Get / Get_Line

  Compilation : fpc -Mtp OBER2ADA.PAS
  Usage       : OBER2ADA source.Mod [destination.adb]
}
Program OBER2ADA;

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
   RetType : TString;       { type Ada de retour ('' si procedure) }
   IsFunc  : Boolean;
   VarMask : TString;       { '1' = param VAR (in out), '0' = par valeur }
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
 SourceLine : LongInt;
 Indent     : Integer;
 OutLine    : TString;
 Imports    : Array[1..MAX_IMP] of TString;
 ICount     : Integer;
 SrcEOF     : Boolean;
 SrcPushed  : Boolean;
 SrcPushCh  : Char;
 NeedTextIO : Boolean;
 NeedIntIO  : Boolean;
 NeedFloatIO: Boolean;

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
   AddToken(TK_INT,'16#'+V+'#');
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
 If U='INTEGER'   Then MapOberonType:='Integer' Else
 If U='LONGINT'   Then MapOberonType:='Long_Integer' Else
 If U='HUGEINT'   Then MapOberonType:='Long_Long_Integer' Else
 If U='SHORTINT'  Then MapOberonType:='Short_Integer' Else
 If U='BYTE'      Then MapOberonType:='Short_Short_Integer' Else
 If U='REAL'      Then MapOberonType:='Float' Else
 If U='LONGREAL'  Then MapOberonType:='Long_Float' Else
 If U='CHAR'      Then MapOberonType:='Character' Else
 If U='BOOLEAN'   Then MapOberonType:='Boolean' Else
 If U='SET'       Then MapOberonType:='Integer' Else
                       MapOberonType:=T;
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean; VarMask:TString);
Begin
 If FuncCount>=MAX_FNS Then Exit;
 Inc(FuncCount);
 Funcs[FuncCount].Name:=Name;
 Funcs[FuncCount].RetType:=RetType;
 Funcs[FuncCount].IsFunc:=IsFunc;
 Funcs[FuncCount].VarMask:=VarMask;
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
 { Modules Oberon standard : pas de `with` (mappage natif). }
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
 Name,Ret,Mask:TString;
 Depth,GrpCount,PI:Integer;
 IsVarGrp,InGroup:Boolean;
Begin
 FuncCount:=0;
 CurFunc:=0;
 ICount:=0;
 ModuleName:='Module';
 NeedTextIO:=False;
 NeedIntIO:=False;
 NeedFloatIO:=False;

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
       Name:=''; Ret:=''; Mask:='';
       If(J<=TokCount)and(Tokens[J].Kind=TK_IDENT)Then Begin Name:=Tokens[J].Val; Inc(J); End;
       If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(')Then Begin
         Depth:=1; Inc(J);
         IsVarGrp:=False;
         GrpCount:=0;
         InGroup:=False;
         While(J<=TokCount)and(Depth>0)do Begin
           If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(')Then Begin
             Inc(Depth); Inc(J); Continue;
           End;
           If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')')Then Begin
             Dec(Depth);
             If Depth=0 Then Begin
               For PI:=1 to GrpCount do Begin
                 If IsVarGrp Then Mask:=Mask+'1' Else Mask:=Mask+'0';
               End;
               Inc(J); Break;
             End;
             Inc(J); Continue;
           End;
           If Depth>1 Then Begin Inc(J); Continue; End;
           If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';')Then Begin
             For PI:=1 to GrpCount do Begin
               If IsVarGrp Then Mask:=Mask+'1' Else Mask:=Mask+'0';
             End;
             IsVarGrp:=False; GrpCount:=0; InGroup:=False;
             Inc(J); Continue;
           End;
           If Not InGroup Then Begin
             InGroup:=True; IsVarGrp:=False; GrpCount:=0;
             If(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='VAR')Then Begin
               IsVarGrp:=True; Inc(J); Continue;
             End;
           End;
           If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':')Then Begin
             Inc(J);
             While(J<=TokCount)and(Depth>0)and
               Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=';')or(Tokens[J].Val=')')))do Begin
               If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(')Then Inc(Depth)
               Else If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')')Then Begin
                 If Depth>1 Then Dec(Depth)
                 Else Break;
               End;
               Inc(J);
             End;
             Continue;
           End;
           If Tokens[J].Kind=TK_IDENT Then Inc(GrpCount);
           Inc(J);
         End;
       End;
       If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':')Then Begin
         Inc(J);
         If J<=TokCount Then Begin Ret:=MapOberonType(Tokens[J].Val); Inc(J); End;
       End;
       If Name<>'' Then RegisterFunc(Name,Ret,Ret<>'',Mask);
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

{ Conversion d une chaine Oberon `"abc"` en chaine Ada `"abc"` avec
  doublement des `"`. Une chaine de longueur 1 est emise en `'c'`. }
Function OberonStringToAda(S:TString):TString;
Var
 I:Integer;
 R:TString;
 C:Char;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   C:=S[I];
   If C='"' Then R:=R+'""'
   Else R:=R+C;
   Inc(I);
 End;
 OberonStringToAda:='"'+R+'"';
End;

{ Conversion d un litteral caractere Oberon `41X` (stocke `#41`) en
  notation Ada `'A'` ou `Character'Val(N)`. }
Function OberonCharToAda(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body:TString;
 NS:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 Val('$'+Body,V,Code);
 If Code<>0 Then V:=0;
 If(V>=32)and(V<=126)and(V<>Ord(''''))Then Begin
   OberonCharToAda:=''''+Chr(V)+''''; Exit;
 End;
 If V=Ord('''')Then Begin OberonCharToAda:=''''''''; Exit; End;
 Str(V,NS);
 OberonCharToAda:='Character''Val('+NS+')';
End;

{ Mappage d un operateur Oberon vers Ada. }
Function MapOp(Op:TString):TString;
Begin
 If Op='#'  Then MapOp:='/=' Else
 If Op='&'  Then MapOp:=' and ' Else
 If Op='~'  Then MapOp:=' not ' Else
 MapOp:=Op;
End;

{ Mappage d un mot-cle Oberon (utilise en expression) vers Ada. }
Function MapKw(K:TString):TString;
Begin
 If K='OR'   Then MapKw:=' or '   Else
 If K='DIV'  Then MapKw:=' / '    Else
 If K='MOD'  Then MapKw:=' mod '  Else
 If K='IN'   Then MapKw:=' in '   Else
 If K='IS'   Then MapKw:=' in '   Else
 If K='TRUE' Then MapKw:='True'   Else
 If K='FALSE'Then MapKw:='False'  Else
 If K='NIL'  Then MapKw:='null'   Else
 MapKw:=StrLower(K);
End;

{ ============================================================
  FORWARDS
  ============================================================ }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString); Forward;
Procedure EmitProcedure(Var I:Integer); Forward;
Procedure EmitVarSection(Var I:Integer); Forward;
Procedure EmitConstSection(Var I:Integer); Forward;
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
       EmitRaw(OberonStringToAda(V));
   End;
   TK_CHAR   : EmitRaw(OberonCharToAda(Tokens[I].Val));
   TK_INT    : EmitRaw(Tokens[I].Val);
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : EmitRaw(Tokens[I].Val);
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('.all')
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
   { En Ada, l indexation utilise () et non []. }
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[')Then EmitRaw('(')
   Else If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')Then EmitRaw(')')
   Else EmitOneExprTok(I);
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
  Out / In : pseudo modules d E/S Oberon
  ============================================================ }
Procedure EmitOutCall(Var I:Integer; Method:TString);
Var M:TString;
Begin
 M:=StrUpper(Method);
 NeedTextIO:=True;
 If M='LN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('Ada.Text_IO.New_Line;');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('-- Out.'+Method+' sans args');
   Exit;
 End;
 Inc(I);                     { sauter `(` }
 If(M='STRING')or(M='CHAR')Then Begin
   EmitRaw('Ada.Text_IO.Put (');
   EmitExprUntil(I,',)');
   { Largeur de champ optionnelle : ignoree pour les chaines. }
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(' -- width=');
     EmitExprUntil(I,',)');
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
 End Else
 If(M='INT')or(M='HEX')Then Begin
   NeedIntIO:=True;
   EmitRaw('Ada.Integer_Text_IO.Put (');
   EmitExprUntil(I,',)');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(', ');
     EmitExprUntil(I,',)');
   End Else EmitRaw(', 0');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
 End Else
 If(M='REAL')or(M='LONGREAL')Then Begin
   NeedFloatIO:=True;
   EmitRaw('Ada.Float_Text_IO.Put (');
   EmitExprUntil(I,',)');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     EmitRaw(', ');
     EmitExprUntil(I,',)');
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
 End Else Begin
   EmitRaw('-- Out.'+Method+' : ');
   EmitRaw('Ada.Text_IO.Put (');
   EmitExprUntil(I,',)');
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   EmitRaw(');');
 End;
End;

Procedure EmitInCall(Var I:Integer; Method:TString);
Var
 M:TString;
 Target:TString;
 Save,J:Integer;
Begin
 M:=StrUpper(Method);
 NeedTextIO:=True;
 If M='LN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('Ada.Text_IO.Skip_Line;');
   Exit;
 End;
 If M='OPEN' Then Begin
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
   End;
   EmitRaw('null; -- In.Open : implicite en Ada');
   Exit;
 End;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='('))Then Begin
   EmitRaw('-- In.'+Method+' sans args');
   Exit;
 End;
 Inc(I);
 Target:='';
 Save:=Indent; Indent:=0;
 J:=Length(OutLine);
 EmitExprUntil(I,')');
 Target:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 Indent:=Save;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')Then Inc(I);
 If M='INT' Then Begin
   NeedIntIO:=True;
   EmitRaw('Ada.Integer_Text_IO.Get ('+Target+');');
 End Else If M='LONGINT' Then Begin
   NeedIntIO:=True;
   EmitRaw('Ada.Integer_Text_IO.Get ('+Target+');');
 End Else If(M='REAL')or(M='LONGREAL')Then Begin
   NeedFloatIO:=True;
   EmitRaw('Ada.Float_Text_IO.Get ('+Target+');');
 End Else If M='CHAR' Then Begin
   EmitRaw('Ada.Text_IO.Get ('+Target+');');
 End Else If(M='STRING')or(M='NAME')or(M='LINE')Then Begin
   { Lit une ligne dans un buffer fixe. On initialise d abord aux
     espaces puis on remplit via Get_Line. }
   EmitRaw('declare Last : Natural; begin '+Target+' := (others => '' ''); Ada.Text_IO.Get_Line ('+Target+', Last); end;');
 End Else
   EmitRaw('-- In.'+Method+' : '+Target);
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

Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF }
 EmitRaw('if ');
 EmitExpr(I);
 EmitRaw(' then'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 While(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSIF')do Begin
   Inc(I);
   WriteIndent; EmitRaw('elsif ');
   EmitExpr(I);
   EmitRaw(' then'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN')Then Inc(I);
   Inc(Indent,2);
   EmitStatementList(I);
   Dec(Indent,2);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE')Then Begin
   Inc(I);
   WriteIndent; EmitRaw('else'); EmitLn;
   Inc(Indent,2);
   EmitStatementList(I);
   Dec(Indent,2);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 WriteIndent; EmitRaw('end if;');
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE }
 EmitRaw('while ');
 EmitExpr(I);
 EmitRaw(' loop'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 WriteIndent; EmitRaw('end loop;');
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT }
 EmitRaw('loop'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL')Then Inc(I);
 WriteIndent; EmitRaw('exit when ');
 EmitExpr(I);
 EmitRaw(';'); EmitLn;
 Dec(Indent,2);
 WriteIndent; EmitRaw('end loop;');
End;

Procedure EmitLoopStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter LOOP }
 EmitRaw('loop'); EmitLn;
 Inc(Indent,2);
 EmitStatementList(I);
 Dec(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 WriteIndent; EmitRaw('end loop;');
End;

Procedure EmitForStatement(Var I:Integer);
Var
 IdxName,StartE,EndE,StepE:TString;
 Save:Integer;
 J:Integer;
 IsReverse,UseRange:Boolean;
Begin
 Inc(I);                     { sauter FOR }
 IdxName:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=')Then Inc(I);
 Save:=Indent; Indent:=0;
 J:=Length(OutLine);
 EmitExprUntil(I,'');
 StartE:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
 J:=Length(OutLine);
 EmitExprUntil(I,'');
 EndE:=Copy(OutLine,J+1,Length(OutLine)-J);
 OutLine:=Copy(OutLine,1,J);
 StepE:='';
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BY')Then Begin
   Inc(I);
   J:=Length(OutLine);
   EmitExprUntil(I,'');
   StepE:=Copy(OutLine,J+1,Length(OutLine)-J);
   OutLine:=Copy(OutLine,1,J);
 End;
 Indent:=Save;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')Then Inc(I);
 IsReverse:=False;
 UseRange:=False;
 { Cas simples : pas de step (=1), ou step = 1 -> for in lo .. hi.
   Step = -1 -> for in reverse hi .. lo. Sinon -> while loop. }
 While(Length(StartE)>0)and(StartE[1]=' ')do Delete(StartE,1,1);
 While(Length(EndE)>0)and(EndE[1]=' ')do Delete(EndE,1,1);
 While(Length(StepE)>0)and(StepE[1]=' ')do Delete(StepE,1,1);
 If(StepE='')or(StepE='1')Then UseRange:=True
 Else If StepE='-1' Then Begin UseRange:=True; IsReverse:=True; End;
 If UseRange Then Begin
   If IsReverse Then
     EmitRaw('for '+IdxName+' in reverse '+EndE+' .. '+StartE+' loop')
   Else
     EmitRaw('for '+IdxName+' in '+StartE+' .. '+EndE+' loop');
   EmitLn;
   Inc(Indent,2);
   EmitStatementList(I);
   Dec(Indent,2);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
   WriteIndent; EmitRaw('end loop;');
 End Else Begin
   { Boucle while equivalente. }
   EmitRaw(IdxName+' := '+StartE+';'); EmitLn;
   WriteIndent;
   If(Length(StepE)>0)and(StepE[1]='-')Then
     EmitRaw('while '+IdxName+' >= '+EndE+' loop')
   Else
     EmitRaw('while '+IdxName+' <= '+EndE+' loop');
   EmitLn;
   Inc(Indent,2);
   EmitStatementList(I);
   WriteIndent; EmitRaw(IdxName+' := '+IdxName+' + '+StepE+';'); EmitLn;
   Dec(Indent,2);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
   WriteIndent; EmitRaw('end loop;');
 End;
End;

{ Emet une etiquette de CASE Oberon `n[, m, lo..hi]` en branche Ada
  `when X | Y | lo .. hi =>`. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 LowS,HighS:TString;
 J:Integer;
 First:Boolean;
Begin
 EmitRaw('when ');
 First:=True;
 While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':'))do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin
     Inc(I);
     If Not First Then EmitRaw(' | ');
     Continue;
   End;
   J:=I; LowS:='';
   While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':')))do Begin
     If(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+OberonCharToAda(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If Not First Then EmitRaw(' | ');
   If(J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..')Then Begin
     Inc(J);
     HighS:='';
     While(J<=TokCount)and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':')))do Begin
       Case Tokens[J].Kind of
         TK_INT  : HighS:=HighS+Tokens[J].Val;
         TK_CHAR : HighS:=HighS+OberonCharToAda(Tokens[J].Val);
         TK_IDENT: HighS:=HighS+Tokens[J].Val;
         TK_KEYWORD:HighS:=HighS+MapKw(Tokens[J].Val);
       Else
         HighS:=HighS+Tokens[J].Val;
       End;
       Inc(J);
     End;
     EmitRaw(LowS+' .. '+HighS);
   End Else
     EmitRaw(LowS);
   I:=J;
   First:=False;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Inc(I);
 EmitRaw(' =>');
End;

Procedure EmitCaseStatement(Var I:Integer);
Var First:Boolean;
Begin
 Inc(I);                     { sauter CASE }
 EmitRaw('case ');
 EmitExpr(I);
 EmitRaw(' is'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
 First:=True;
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
   If(Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE'))Then Begin
     If Tokens[I].Val='ELSE' Then Begin
       Inc(I);
       WriteIndent; EmitRaw('when others =>'); EmitLn;
       Inc(Indent,2);
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Begin
         If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
         WriteIndent; EmitStmt(I); EmitLn;
       End;
       Dec(Indent,2);
     End;
     Break;
   End;
   WriteIndent; EmitCaseLabels(I); EmitLn;
   Inc(Indent,2);
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='|'))and
     Not((Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Begin Inc(I); Continue; End;
     WriteIndent; EmitStmt(I); EmitLn;
   End;
   Dec(Indent,2);
   First:=False;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 WriteIndent; EmitRaw('end case;');
 If First Then ;
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
 { Cas special : `In.X(...)` ou `Out.X(...)`. Le tokenizer marque
   IN comme keyword, donc on l intercepte ici. }
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IN')and
   (I+2<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.')and
   (Tokens[I+2].Kind=TK_IDENT)Then Begin
   Inc(I,2);
   Name:=Tokens[I].Val; Inc(I);
   EmitInCall(I,Name);
   Exit;
 End;
 Case Tokens[I].Kind of
   TK_KEYWORD:Begin
     K:=Tokens[I].Val;
     If K='BEGIN' Then Begin
       EmitRaw('begin'); EmitLn;
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
       Dec(Indent,2);
       WriteIndent; EmitRaw('end;');
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
     If K='EXIT' Then Begin Inc(I); EmitRaw('exit;'); End Else
     If K='WITH' Then Begin
       EmitRaw('-- WITH Oberon non supporte');
       While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END'))do Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Begin
       EmitRaw('-- mot-cle non gere : '+K);
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
         EmitRaw(' := ');
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
 TypeS:='Integer';
 If I>TokCount Then Exit;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY')Then Begin
   Inc(I);
   IsArray:=True;
   { ARRAY OF T (open array). }
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Begin
     Inc(I);
     ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
     If(InnerT='Character')and Not InnerArr Then Begin
       TypeS:='String'; IsArray:=False;
     End Else Begin
       TypeS:='array (Integer range <>) of '+InnerT;
     End;
     Exit;
   End;
   { ARRAY N OF T -> array (0 .. N-1) of T (cas mono-dim). }
   SizeBuf:='';
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF'))do Begin
     If(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',')Then Begin Inc(I); Continue; End;
     If SizeBuf<>'' Then SizeBuf:=SizeBuf+'*';
     SizeBuf:=SizeBuf+Tokens[I].Val;
     Inc(I);
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF')Then Inc(I);
   ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
   { Cas idiomatique : ARRAY n OF CHAR -> String (1..n). }
   If(InnerT='Character')and Not InnerArr Then Begin
     TypeS:='String (1 .. '+SizeBuf+')'; IsArray:=False; ArrSize:=SizeBuf;
   End Else Begin
     TypeS:='array (0 .. '+SizeBuf+' - 1) of '+InnerT;
     ArrSize:=SizeBuf;
   End;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   ReadOberonTypeS(I,InnerT,InnerArr,InnerSize);
   TypeS:='access '+InnerT;
   Exit;
 End;
 If(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
   TypeS:='-- RECORD inline non supporte';
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
   TypeS:='access '+InnerT;
   Exit;
 End;
 If Tokens[I].Kind=TK_IDENT Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End Else If Tokens[I].Kind=TK_KEYWORD Then Begin
   TypeS:=MapOberonType(Tokens[I].Val); Inc(I);
 End;
End;

{ Emet un RECORD nomme : `type Name is record ... end record;`. }
Procedure EmitRecordDecl(Var I:Integer; Const TypeName:TString);
Var
 FieldType,Names,Sz:TString;
 Arr:Boolean;
Begin
 EmitRaw('type '); EmitRaw(TypeName); EmitRaw(' is record'); EmitLn;
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
   EmitRaw(Names); EmitRaw(' : '); EmitRaw(FieldType); EmitRaw(';'); EmitLn;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('end record;'); EmitLn;
End;

Procedure EmitVarSection(Var I:Integer);
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
     EmitRaw(SubName); EmitRaw(' : '); EmitRaw(TypeS); EmitRaw(';'); EmitLn;
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 End;
End;

Procedure EmitConstSection(Var I:Integer);
Var K,Name,TypeS:TString; J:Integer;
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
   { Inferer le type. }
   TypeS:='Integer';
   If I<=TokCount Then Begin
     Case Tokens[I].Kind of
       TK_INT  : TypeS:='Integer';
       TK_REAL : TypeS:='Long_Float';
       TK_STRING:Begin
         If Length(Tokens[I].Val)=3 Then TypeS:='Character'
         Else TypeS:='String';
       End;
       TK_CHAR : TypeS:='Character';
       TK_KEYWORD: If(Tokens[I].Val='TRUE')or(Tokens[I].Val='FALSE')Then TypeS:='Boolean';
     End;
   End;
   WriteIndent;
   EmitRaw(Name); EmitRaw(' : constant '); EmitRaw(TypeS); EmitRaw(' := ');
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
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='POINTER')Then Begin
     Inc(I);
     If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO')Then Inc(I);
   End;
   If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD')Then Begin
     WriteIndent;
     EmitRecordDecl(I,Name);
   End Else Begin
     ReadOberonTypeS(I,TypeS,Arr,Sz);
     WriteIndent; EmitRaw('subtype '); EmitRaw(Name); EmitRaw(' is '); EmitRaw(TypeS); EmitRaw(';'); EmitLn;
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
     If Not First Then EmitRaw('; ');
     EmitRaw(SubName); EmitRaw(' : ');
     If IsVar Then EmitRaw('in out ');
     EmitRaw(TypeS);
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
 If IsFunc Then EmitRaw('function ') Else EmitRaw('procedure ');
 EmitRaw(Name);
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')Then EmitProcParams(I);
 If IsFunc Then Begin
   EmitRaw(' return '); EmitRaw(RetT);
 End;
 { Sauter `: type;` du retour Oberon (deja capture par Analyze). }
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')Then Begin
   Inc(I);
   While(I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';'))do Inc(I);
 End;
 EmitRaw(' is'); EmitLn;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 Inc(Indent,2);
 { Declarations locales. }
 While I<=TokCount do Begin
   If(Tokens[I].Kind=TK_KEYWORD)Then Begin
     If Tokens[I].Val='VAR'   Then EmitVarSection(I) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I) Else
     If Tokens[I].Val='TYPE'  Then EmitTypeSection(I) Else
     If Tokens[I].Val='PROCEDURE' Then Begin
       EmitProcedure(I);
     End Else Break;
   End Else Break;
 End;
 Dec(Indent,2);
 WriteIndent; EmitRaw('begin'); EmitLn;
 Inc(Indent,2);
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN')Then Begin
   Inc(I);
   EmitStatementList(I);
 End Else Begin
   WriteIndent; EmitRaw('null;'); EmitLn;
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
   Inc(I);
   If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
 End;
 If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')Then Inc(I);
 Dec(Indent,2);
 WriteIndent; EmitRaw('end '); EmitRaw(Name); EmitRaw(';'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
End;

{ ============================================================
  EN-TETE / PIED DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Var I:Integer;
Begin
 EmitRaw('-- Genere par OBER2ADA '+VERSION+' a partir de '+SrcName); EmitLn;
 If NeedTextIO Then Begin
   EmitRaw('with Ada.Text_IO; use Ada.Text_IO;'); EmitLn;
 End;
 If NeedIntIO Then Begin
   EmitRaw('with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;'); EmitLn;
 End;
 If NeedFloatIO Then Begin
   EmitRaw('with Ada.Float_Text_IO; use Ada.Float_Text_IO;'); EmitLn;
 End;
 For I:=1 to ICount do Begin
   EmitRaw('with '); EmitRaw(Imports[I]);
   EmitRaw('; use '); EmitRaw(Imports[I]); EmitRaw(';'); EmitLn;
 End;
 EmitLn;
 EmitRaw('procedure '); EmitRaw(ModuleName); EmitRaw(' is'); EmitLn;
 Inc(Indent,2);
End;

Procedure EmitFileFooter;
Begin
 Dec(Indent,2);
 EmitRaw('end '); EmitRaw(ModuleName); EmitRaw(';'); EmitLn;
End;

{ ============================================================
  BLOC PRINCIPAL
  ============================================================ }
{ Emet la section declarative + corps. Pre : I sur premier token apres
  le `;` qui suit `MODULE Name`. }
Procedure EmitDeclsAndBody(Var I:Integer);
Var K:TString; HasBegin:Boolean;
Begin
 HasBegin:=False;
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='CONST' Then Begin EmitConstSection(I); Continue; End;
     If K='TYPE'  Then Begin EmitTypeSection(I); Continue; End;
     If K='VAR'   Then Begin EmitVarSection(I); Continue; End;
     If K='PROCEDURE' Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       HasBegin:=True;
       Dec(Indent,2);
       WriteIndent; EmitRaw('begin'); EmitLn;
       Inc(Indent,2);
       Inc(I);
       EmitStatementList(I);
       If(I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')Then Begin
         Inc(I);
         If(I<=TokCount)and(Tokens[I].Kind=TK_IDENT)Then Inc(I);
       End;
       If(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')Then Inc(I);
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
 If Not HasBegin Then Begin
   Dec(Indent,2);
   WriteIndent; EmitRaw('begin'); EmitLn;
   Inc(Indent,2);
   WriteIndent; EmitRaw('null;'); EmitLn;
 End;
End;

Procedure EmitTopLevel;
Var I:Integer;
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
 EmitDeclsAndBody(I);
End;

{ ============================================================
  PRE-PASSE : detection des modules d E/S utilises
  ============================================================ }
{ Avant l emission, on parcourt les tokens pour decider si Out / In
  sont utilises (donc s il faut faire `with Ada.Text_IO`, etc.). }
Procedure DetectIOUsage;
Var
 I:Integer;
 U,M:TString;
Begin
 NeedTextIO:=False;
 NeedIntIO:=False;
 NeedFloatIO:=False;
 I:=1;
 While I<TokCount do Begin
   If((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD))and
     (I+2<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.')and
     (Tokens[I+2].Kind=TK_IDENT)Then Begin
     U:=StrUpper(Tokens[I].Val);
     M:=StrUpper(Tokens[I+2].Val);
     If(U='OUT')or(U='IN')Then Begin
       NeedTextIO:=True;
       If(M='INT')or(M='LONGINT')or(M='HEX')Then NeedIntIO:=True;
       If(M='REAL')or(M='LONGREAL')Then NeedFloatIO:=True;
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
 WriteLn('OBER2ADA ',VERSION,' - Transpilateur Oberon vers Ada');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : OBER2ADA source.Mod [destination.adb]');
 WriteLn('Exemple : OBER2ADA hello.Mod hello.adb');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.adb'
          Else DstName:=A+'.adb';
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
 DetectIOUsage;
 OutLine:='';
 Indent:=0;
 EmitFileHeader;
 EmitTopLevel;
 EmitFileFooter;
 FlushLine;
 Close(OutFile);
 WriteLn('OBER2ADA : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procedures).');
End.
