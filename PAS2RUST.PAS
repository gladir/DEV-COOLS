{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal vers le langage Rust (.rs).

  Sources : Turbo Pascal / Free Pascal (mode TP).
  Cible   : code source Rust 2021 (compatible rustc 1.56+).

  Sous-ensemble pris en charge :
    PROGRAM/UNIT, USES (ignore),
    CONST (-> const), TYPE (en commentaire), VAR (-> let mut / static mut),
    PROCEDURE/FUNCTION (-> fn ... -> T),
    BEGIN..END (-> blocs accolades), parametres VAR (-> &mut T),
    IF/THEN/ELSE, WHILE..DO, REPEAT..UNTIL (-> loop + break),
    FOR..TO/DOWNTO..DO (-> for i in low..=high ou .rev()),
    CASE..OF (-> match avec bras v1 | v2 ou intervalles low..=high),
    Exit (-> return), Halt (-> std::process::exit).

  Mappages d'entrees/sorties :
    Write/WriteLn  -> print!/println! avec format "@@..."
    Read/ReadLn    -> std::io::stdin().read_line(...) + parse().

  Particularites Rust :
    - Variables : let mut name: type = init; (locales) ;
      VAR globales Pascal -> static mut NAME: type = init;
      Les acces aux globales sont encadres en unsafe (corps de
      chaque fonction et de main).
    - Operateurs : := -> =, = -> ==, <> -> !=, AND -> &&, OR -> ||,
      NOT -> !, DIV -> /, MOD -> %, XOR -> ^.
    - Booleens : TRUE/FALSE -> true/false ; NIL -> Default::default().

  Limitations :
    - WITH, GOTO, ensembles (sets) : commentes en sortie.
    - Le typage statique strict de Rust peut requerir des ajustements
      manuels (casts entre types numeriques, durees de vie).

  Compilation : fpc -Mtp PAS2RUST.PAS
  Usage       : PAS2RUST source.pas [destination.rs]
}
Program PAS2RUST;

Const
 VERSION = '1.0';
 MAX_TOK = 65535;
 MAX_FNS = 1024;
 MAX_IMP = 32;

Type
 TString = String;
 TTokenKind = (TK_NONE, TK_IDENT, TK_KEYWORD, TK_INT, TK_REAL,
               TK_STRING, TK_CHAR, TK_OP, TK_PUNCT, TK_EOF);
 TToken = Record
   Kind : TTokenKind;
   Val  : TString;
 End;
 TFuncRec = Record
   Name    : TString;     { nom Pascal d'origine                          }
   RetType : TString;     { type C de retour ('' si procedure)            }
   IsFunc  : Boolean;
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Funcs      : Array[1..MAX_FNS] of TFuncRec;
 FuncCount  : Integer;
 Globals    : Array[1..MAX_FNS] of TString;  { noms des VAR globales }
 GlobalCount: Integer;
 Locals     : Array[1..MAX_FNS] of TString;  { noms locaux (params + var) }
 LocalCount : Integer;
 FuncStack  : Array[0..32] of Integer;  { pile des fonctions imbriquees   }
 FuncSP     : Integer;
 CurFunc    : Integer;
 InFile     : Text;
 OutFile    : Text;
 SrcName    : TString;
 DstName    : TString;
 ProgName   : TString;
 IsUnit     : Boolean;
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
 SrcPushed  : Boolean;       { caractere remis ?                          }
 SrcPushCh  : Char;
 SrcPushed2 : Boolean;       { 2e niveau de remise (pour 'a..b')         }
 SrcPushCh2 : Char;

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
 Str(N,S);
 IntToStr:=S;
End;

{ ============================================================
  LEXER
  ============================================================ }
Procedure TokInit;
Begin
 TokCount:=0;
 SrcEOF:=False;
 SrcPushed:=False;
 SrcPushed2:=False;
 SourceLine:=1;
End;

Function NextCh:Char;
Var C:Char;
Begin
 If SrcPushed Then Begin
   SrcPushed:=False;
   NextCh:=SrcPushCh;
   { remonter le 2e niveau }
   If SrcPushed2 Then Begin
     SrcPushed:=True; SrcPushCh:=SrcPushCh2; SrcPushed2:=False;
   End;
   Exit;
 End;
 If Eof(InFile) Then Begin SrcEOF:=True; NextCh:=#0; Exit; End;
 If Eoln(InFile) Then Begin ReadLn(InFile); Inc(SourceLine); NextCh:=#10; Exit; End;
 Read(InFile,C);
 NextCh:=C;
End;

Procedure UngetCh(Ch:Char);
Begin
 If SrcPushed Then Begin
   { decaler le pushback existant en 2e niveau }
   SrcPushCh2:=SrcPushCh; SrcPushed2:=True;
 End;
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
   (U='AND')or(U='ARRAY')or(U='BEGIN')or(U='CASE')or(U='CONST')or
   (U='DIV')or(U='DO')or(U='DOWNTO')or(U='ELSE')or(U='END')or
   (U='FILE')or(U='FOR')or(U='FUNCTION')or(U='GOTO')or(U='IF')or
   (U='IN')or(U='LABEL')or(U='MOD')or(U='NIL')or(U='NOT')or
   (U='OF')or(U='OR')or(U='PACKED')or(U='PROCEDURE')or
   (U='PROGRAM')or(U='RECORD')or(U='REPEAT')or(U='SET')or
   (U='THEN')or(U='TO')or(U='TYPE')or(U='UNTIL')or(U='VAR')or
   (U='WHILE')or(U='WITH')or(U='UNIT')or(U='USES')or
   (U='INTERFACE')or(U='IMPLEMENTATION')or(U='INITIALIZATION')or
   (U='FINALIZATION')or(U='TRUE')or(U='FALSE')or(U='SHL')or
   (U='SHR')or(U='XOR')or(U='STRING')or(U='OUT')or(U='EXIT')or
   (U='BREAK')or(U='CONTINUE')or(U='OBJECT')or(U='CLASS')or
   (U='INHERITED')or(U='PRIVATE')or(U='PUBLIC')or(U='PROTECTED')or
   (U='ABSOLUTE')or(U='FORWARD')or(U='EXTERNAL')or(U='OTHERWISE');
End;

Procedure SkipBlockComment(EndCh1,EndCh2:Char);
Var C:Char;
Begin
 While Not SrcEOF do Begin
   C:=NextCh;
   If SrcEOF Then Exit;
   If EndCh2=#0 Then Begin
     If C=EndCh1 Then Exit;
   End Else Begin
     If C=EndCh1 Then Begin
       If PeekCh=EndCh2 Then Begin C:=NextCh; Exit; End;
     End;
   End;
 End;
End;

Procedure ReadLineComment;
Var C:Char;
Begin
 Repeat C:=NextCh; Until SrcEOF or (C=#10);
End;

Procedure ScanString;
Var
 C:Char;
 V:TString;
Begin
 V:='''';
 Repeat
   C:=NextCh;
   If SrcEOF Then Break;
   If C=#10 Then Break;
   V:=V+C;
   If C='''' Then Begin
     If PeekCh='''' Then Begin V:=V+NextCh; End Else Break;
   End;
 Until False;
 AddToken(TK_STRING,V);
End;

Procedure ScanCharLit;
Var
 C:Char;
 V:TString;
Begin
 V:='#';
 C:=PeekCh;
 If C='$' Then Begin V:=V+NextCh; While PeekCh in ['0'..'9','A'..'F','a'..'f'] do V:=V+NextCh; End
 Else While PeekCh in ['0'..'9'] do V:=V+NextCh;
 AddToken(TK_CHAR,V);
End;

Procedure ScanNumber(First:Char);
Var
 V:TString;
 IsReal:Boolean;
 C:Char;
Begin
 V:=First;
 IsReal:=False;
 If First='$' Then Begin
   While PeekCh in ['0'..'9','A'..'F','a'..'f'] do V:=V+NextCh;
   AddToken(TK_INT,V);
   Exit;
 End;
 While PeekCh in ['0'..'9'] do V:=V+NextCh;
 If PeekCh='.' Then Begin
   C:=NextCh;
   If PeekCh='.' Then Begin UngetCh(C); End
   Else Begin V:=V+'.'; IsReal:=True;
     While PeekCh in ['0'..'9'] do V:=V+NextCh;
   End;
 End;
 If (PeekCh='E')or(PeekCh='e') Then Begin
   V:=V+NextCh; IsReal:=True;
   If (PeekCh='+')or(PeekCh='-') Then V:=V+NextCh;
   While PeekCh in ['0'..'9'] do V:=V+NextCh;
 End;
 If IsReal Then AddToken(TK_REAL,V) Else AddToken(TK_INT,V);
End;

Procedure ScanIdent(First:Char);
Var V:TString;
Begin
 V:=First;
 While PeekCh in ['A'..'Z','a'..'z','0'..'9','_'] do V:=V+NextCh;
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
     '{':SkipBlockComment('}',#0);
     '(':Begin
       If PeekCh='*' Then Begin C:=NextCh; SkipBlockComment('*',')'); End
       Else AddToken(TK_PUNCT,'(');
     End;
     '/':Begin
       If PeekCh='/' Then Begin C:=NextCh; ReadLineComment; End
       Else AddToken(TK_OP,'/');
     End;
     '''':ScanString;
     '#':ScanCharLit;
     '$':ScanNumber('$');
     '0'..'9':ScanNumber(C);
     'A'..'Z','a'..'z','_':ScanIdent(C);
     ':':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,':='); End
       Else AddToken(TK_PUNCT,':');
     End;
     '<':Begin
       N:=PeekCh;
       If N='=' Then Begin C:=NextCh; AddToken(TK_OP,'<='); End
       Else If N='>' Then Begin C:=NextCh; AddToken(TK_OP,'<>'); End
       Else AddToken(TK_OP,'<');
     End;
     '>':Begin
       If PeekCh='=' Then Begin C:=NextCh; AddToken(TK_OP,'>='); End
       Else AddToken(TK_OP,'>');
     End;
     '+','-','*','=':AddToken(TK_OP,C);
     ')',',',';','.','[',']','^','@':AddToken(TK_PUNCT,C);
   End;
 End;
 AddToken(TK_EOF,'');
End;

{ ============================================================
  ANALYSE PRELIMINAIRE
  ============================================================ }
Function MapPascalType(T:TString):TString;
Var U:TString;
Begin
 U:=StrUpper(T);
 If U='INTEGER'   Then MapPascalType:='i32' Else
 If U='LONGINT'   Then MapPascalType:='i64' Else
 If U='SHORTINT'  Then MapPascalType:='i8' Else
 If U='SMALLINT'  Then MapPascalType:='i16' Else
 If U='WORD'      Then MapPascalType:='u16' Else
 If U='BYTE'      Then MapPascalType:='u8' Else
 If U='CARDINAL'  Then MapPascalType:='u32' Else
 If U='REAL'      Then MapPascalType:='f64' Else
 If U='SINGLE'    Then MapPascalType:='f32' Else
 If U='DOUBLE'    Then MapPascalType:='f64' Else
 If U='EXTENDED'  Then MapPascalType:='f64' Else
 If U='CHAR'      Then MapPascalType:='char' Else
 If U='BOOLEAN'   Then MapPascalType:='bool' Else
 If U='STRING'    Then MapPascalType:='String' Else
 If U='POINTER'   Then MapPascalType:='*mut u8' Else
 If U='TEXT'      Then MapPascalType:='std::fs::File' Else
                       MapPascalType:=T;
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

Procedure Analyze;
Var
 I,J:Integer;
 K:TString;
 Name,Ret:TString;
 Depth:Integer;
Begin
 FuncCount:=0;
 GlobalCount:=0;
 LocalCount:=0;
 FuncSP:=0;
 CurFunc:=0;
 UsesOut:=False;
 UsesString:=False;
 UsesMath:=False;
 UsesStdLib:=False;
 IsUnit:=False;
 ProgName:='Program';

 I:=1;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNIT') Then Begin
     IsUnit:=True;
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT) Then ProgName:=Tokens[I+1].Val;
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='PROGRAM') Then Begin
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT) Then ProgName:=Tokens[I+1].Val;
   End Else
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If (K='PROCEDURE')or(K='FUNCTION') Then Begin
       J:=I+1;
       Name:=''; Ret:='';
       If (J<=TokCount)and(Tokens[J].Kind=TK_IDENT) Then Begin Name:=Tokens[J].Val; Inc(J); End;
       If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Begin
         Depth:=1; Inc(J);
         While (J<=TokCount) and (Depth>0) do Begin
           If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth)
           Else If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
           Inc(J);
         End;
       End;
       If K='FUNCTION' Then Begin
         If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Begin
           Inc(J);
           If (J<=TokCount) Then Begin Ret:=MapPascalType(Tokens[J].Val); Inc(J); End;
         End;
       End;
       If Name<>'' Then RegisterFunc(Name,Ret,K='FUNCTION');
     End Else
     If (K='WRITE')or(K='WRITELN')or(K='READ')or(K='READLN') Then UsesOut:=True;
   End Else
   If Tokens[I].Kind=TK_IDENT Then Begin
     K:=StrUpper(Tokens[I].Val);
     If (K='WRITE')or(K='WRITELN')or(K='READ')or(K='READLN') Then UsesOut:=True Else
     If (K='LENGTH')or(K='COPY')or(K='POS')or(K='STRCOMP')or(K='STRCOPY') Then UsesString:=True Else
     If (K='SQRT')or(K='SIN')or(K='COS')or(K='LN')or(K='EXP')or(K='ARCTAN') Then UsesMath:=True Else
     If (K='ABS')or(K='RANDOM')or(K='RANDOMIZE')or(K='HALT')or(K='EXIT') Then UsesStdLib:=True;
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
     If (Length(OutLine)=0) and (S[I]<>' ') Then WriteIndent;
     OutLine:=OutLine+S[I];
   End;
 End;
End;

Procedure EmitLn;
Begin EmitRaw(#10); End;

{ Conversion d'une chaine Pascal 'abc''def' en chaine C "abc'def" avec
  echappements C standards. }
Function PasStringToC(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin R:=R+''''; Inc(I,2); End
   Else If S[I]='"' Then Begin R:=R+'\"'; Inc(I); End
   Else If S[I]='\' Then Begin R:=R+'\\'; Inc(I); End
   Else If S[I]=#10 Then Begin R:=R+'\n'; Inc(I); End
   Else If S[I]=#13 Then Begin R:=R+'\r'; Inc(I); End
   Else If S[I]=#9  Then Begin R:=R+'\t'; Inc(I); End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 PasStringToC:='"'+R+'"';
End;

{ Conversion d'un litteral Pascal #N en Rust : caractere ASCII ou cast. }
Function PasCharToC(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body,Num:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 If (Length(Body)>0)and(Body[1]='$') Then Val('$'+Copy(Body,2,Length(Body)-1),V,Code)
 Else Val(Body,V,Code);
 If Code<>0 Then V:=0;
 Str(V,Num);
 If (V>=32)and(V<=126)and(V<>Ord(''''))and(V<>Ord('\')) Then
   PasCharToC:=''''+Chr(V)+''''
 Else
   PasCharToC:='('+Num+'u32 as u8 as char)';
End;

{ Mappage d'un operateur Pascal vers C. ContextEq=True => '=' represente
  une egalite (en expression), sinon affectation. }
Function MapOp(Op:TString; ContextEq:Boolean):TString;
Begin
 If Op='<>' Then MapOp:='!=' Else
 If Op=':=' Then MapOp:='=' Else
 If (Op='=')and ContextEq Then MapOp:='==' Else
 MapOp:=Op;
End;

Function MapKw(K:TString):TString;
Begin
 If K='AND' Then MapKw:='&&' Else
 If K='OR'  Then MapKw:='||' Else
 If K='NOT' Then MapKw:='!' Else
 If K='DIV' Then MapKw:='/' Else
 If K='MOD' Then MapKw:='%' Else
 If K='SHL' Then MapKw:='<<' Else
 If K='SHR' Then MapKw:='>>' Else
 If K='XOR' Then MapKw:='^' Else
 If K='TRUE' Then MapKw:='true' Else
 If K='FALSE' Then MapKw:='false' Else
 If K='NIL' Then MapKw:='Default::default()' Else
 If K='IN' Then MapKw:='/* IN non supporte */' Else
                 MapKw:=StrLower(K);
End;

{ ============================================================
  FORWARDS et ETAT
  ============================================================ }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString); Forward;
Procedure EmitBlockBody(Var I:Integer); Forward;

{ Emission d'une expression jusqu'a un separateur "naturel" :
  ; , ) ] OF DO THEN ELSE TO DOWNTO UNTIL := au niveau 0. }
Function IsExprStop(I:Integer):Boolean;
Begin
 IsExprStop:=False;
 If I>TokCount Then Begin IsExprStop:=True; Exit; End;
 If Tokens[I].Kind=TK_EOF Then Begin IsExprStop:=True; Exit; End;
 If Tokens[I].Kind=TK_PUNCT Then Begin
   If (Tokens[I].Val=';')or(Tokens[I].Val=',')or(Tokens[I].Val=')')or
      (Tokens[I].Val=']') Then IsExprStop:=True;
 End Else
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   If (Tokens[I].Val='THEN')or(Tokens[I].Val='DO')or(Tokens[I].Val='ELSE')or
      (Tokens[I].Val='OF')or(Tokens[I].Val='TO')or(Tokens[I].Val='DOWNTO')or
      (Tokens[I].Val='UNTIL')or(Tokens[I].Val='BEGIN')or(Tokens[I].Val='END')or
      (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
      (Tokens[I].Val='PROCEDURE')or(Tokens[I].Val='FUNCTION') Then IsExprStop:=True;
 End Else
 If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then IsExprStop:=True;
End;

{ Emet un seul token au sein d'une expression. }
Function IsLocal(N:TString):Boolean;
Var I:Integer;
Begin
 IsLocal:=False;
 For I:=1 to LocalCount do
   If StrEqualCI(Locals[I],N) Then Begin IsLocal:=True; Exit; End;
End;

Procedure AddLocal(N:TString);
Begin
 If LocalCount<MAX_FNS Then Begin Inc(LocalCount); Locals[LocalCount]:=N; End;
End;

Function IsGlobal(N:TString):Boolean;
Var I:Integer;
Begin
 IsGlobal:=False;
 If IsLocal(N) Then Exit;
 For I:=1 to GlobalCount do
   If StrEqualCI(Globals[I],N) Then Begin IsGlobal:=True; Exit; End;
End;

Procedure EmitOneExprTok(I:Integer);
Var V:TString;
Begin
 Case Tokens[I].Kind of
   TK_KEYWORD: EmitRaw(MapKw(Tokens[I].Val));
   TK_OP     : EmitRaw(MapOp(Tokens[I].Val,True));
   TK_STRING : EmitRaw(PasStringToC(Tokens[I].Val));
   TK_CHAR   : EmitRaw(PasCharToC(Tokens[I].Val));
   TK_INT    : Begin
     V:=Tokens[I].Val;
     If (Length(V)>0)and(V[1]='$') Then EmitRaw('0x'+Copy(V,2,Length(V)-1))
     Else EmitRaw(V);
   End;
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : Begin
     If IsGlobal(Tokens[I].Val) Then EmitRaw(Tokens[I].Val+'_g')
     Else EmitRaw(Tokens[I].Val);
   End;
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('*')
     Else If Tokens[I].Val='@' Then EmitRaw('&')
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
   If (Depth=0) and IsExprStop(I) Then Break;
   If (Depth=0) and (Tokens[I].Kind=TK_PUNCT) and (Pos(Tokens[I].Val,StopPunct)>0) Then Break;
   If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='[')) Then Inc(Depth)
   Else If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val=']')) Then Dec(Depth);
   { Cet item est-il un operateur (binaire) ? }
   IsOpish:=False;
   If Tokens[I].Kind=TK_OP Then IsOpish:=True;
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='AND')or(Tokens[I].Val='OR')or(Tokens[I].Val='DIV')or
       (Tokens[I].Val='MOD')or(Tokens[I].Val='SHL')or(Tokens[I].Val='SHR')or
       (Tokens[I].Val='XOR')) Then IsOpish:=True;
   { Espace avant si necessaire }
   If IsOpish or NeedSpaceBefore Then Begin
     If (Length(OutLine)>0) and (OutLine[Length(OutLine)]<>' ') and
        (OutLine[Length(OutLine)]<>'(') and (OutLine[Length(OutLine)]<>'[') Then
       EmitRaw(' ');
   End;
   EmitOneExprTok(I);
   { Espace apres operateur ou apres , ; }
   NeedSpaceBefore:=False;
   If IsOpish Then NeedSpaceBefore:=True;
   If (Tokens[I].Kind=TK_PUNCT) and ((Tokens[I].Val=',')or(Tokens[I].Val=';')) Then
     NeedSpaceBefore:=True;
   Inc(I);
 End;
End;

Procedure EmitExpr(Var I:Integer);
Begin EmitExprUntil(I,''); End;

{ ============================================================
  WRITE / READ
  ============================================================ }
{ Emet l'argument courant d'un Write/WriteLn (helper inutilise dans la version
  Rust, conserve pour eviter les forwards). }
Procedure EmitWriteArg(Var I:Integer);
Var K:Integer;
Begin
 K:=I; EmitExprUntil(K,',)'); I:=K;
End;

{ Emet WriteLn(...)/Write(...) Rust : un seul appel print!/println! avec une
  chaine de format @@ ... et la liste des arguments separes par ','.
  I positionne sur le mot-cle. }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
 ArgCount,K:Integer;
 SaveOut,ArgsBuf,FmtStr:TString;
Begin
 Inc(I);                     { sauter Write/WriteLn                         }
 ArgCount:=0;
 ArgsBuf:='';
 SaveOut:=OutLine;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If ArgCount>0 Then ArgsBuf:=ArgsBuf+', ';
     OutLine:='';
     K:=I; EmitExprUntil(K,',)'); I:=K;
     ArgsBuf:=ArgsBuf+OutLine;
     Inc(ArgCount);
     { Sauter une eventuelle specification de format :width[:prec] }
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT) and
             ((Tokens[I].Val=',')or(Tokens[I].Val=')')or(Tokens[I].Val=':'))) do Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
         Inc(I);
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT) and
               ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do Inc(I);
       End;
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 OutLine:=SaveOut;
 FmtStr:='';
 For K:=1 to ArgCount do FmtStr:=FmtStr+'{}';
 If IsLn Then EmitRaw('println!("') Else EmitRaw('print!("');
 EmitRaw(FmtStr);
 EmitRaw('"');
 If ArgCount>0 Then Begin EmitRaw(', '); EmitRaw(ArgsBuf); End;
 EmitRaw(');');
End;

{ Emet ReadLn(x) / Read(x) Rust : utilise std::io::stdin().read_line(). }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var First:Boolean; J:Integer; SaveOut,LhsBuf:TString;
Begin
 Inc(I);                     { sauter Read/ReadLn                           }
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then Begin EmitLn; WriteIndent; End;
     SaveOut:=OutLine; OutLine:='';
     J:=I; EmitExprUntil(J,',)'); I:=J;
     LhsBuf:=OutLine;
     OutLine:=SaveOut;
     EmitRaw('{ let mut _s = String::new(); std::io::stdin().read_line(&mut _s).unwrap(); ');
     EmitRaw(LhsBuf);
     EmitRaw(' = _s.trim().parse().unwrap_or_default(); }');
     First:=False;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 If IsLn and First Then Begin
   { ReadLn sans argument : consommer une ligne }
   EmitRaw('{ let mut _s = String::new(); std::io::stdin().read_line(&mut _s).unwrap(); }');
 End;
End;

{ ============================================================
  INSTRUCTIONS DE CONTROLE
  ============================================================ }
{ Si I pointe sur un appel de la fonction courante en partie gauche
  (FuncName := ...), emettre '_result_ = ...;' et avancer. }
Function MaybeEmitFuncReturn(Var I:Integer):Boolean;
Var
 J:Integer;
 Name:TString;
Begin
 MaybeEmitFuncReturn:=False;
 If CurFunc=0 Then Exit;
 If I>TokCount Then Exit;
 If Tokens[I].Kind<>TK_IDENT Then Exit;
 Name:=Tokens[I].Val;
 J:=I+1;
 If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
   If StrEqualCI(Name,Funcs[CurFunc].Name) or StrEqualCI(Name,'RESULT') Then Begin
     Inc(I,2);                { sauter Name :=                              }
     EmitRaw('_result_ = ');
     EmitExpr(I);
     EmitRaw(';');
     MaybeEmitFuncReturn:=True;
   End;
 End;
End;

{ Determine si le token courant est un keyword qui termine une liste
  d'instructions (END, UNTIL, etc.). }
Function StatListEnds(I:Integer):Boolean;
Begin
 StatListEnds:=False;
 If I>TokCount Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_EOF Then Begin StatListEnds:=True; Exit; End;
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   If (Tokens[I].Val='END')or(Tokens[I].Val='UNTIL')or(Tokens[I].Val='ELSE')or
      (Tokens[I].Val='OTHERWISE') Then StatListEnds:=True;
 End;
End;

{ Emet un bloc enfant : si BEGIN..END, ouvre/ferme des accolades ;
  sinon emet une seule instruction sur sa propre ligne. }
Procedure EmitBlockBody(Var I:Integer);
Begin
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   EmitRaw(' {'); EmitLn;
   Inc(Indent);
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   Dec(Indent);
   WriteIndent; EmitRaw('}');
 End Else Begin
   EmitRaw(' {'); EmitLn;
   Inc(Indent);
   WriteIndent; EmitStmt(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   EmitLn;
   Dec(Indent);
   WriteIndent; EmitRaw('}');
 End;
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF                                    }
 EmitRaw('if ');
 EmitExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 EmitBlockBody(I);
 { Sauter un eventuel ';' avant ELSE }
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
   If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='ELSE') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
   Inc(I);
   EmitRaw(' else');
   { else if ... }
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IF') Then Begin
     EmitRaw(' ');
     EmitIfStatement(I);
     Exit;
   End;
   EmitBlockBody(I);
 End;
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE                                 }
 EmitRaw('while ');
 EmitExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitBlockBody(I);
End;

{ FOR Pascal vers Rust : 'for i in low..=high' ou 'for i in (a..=b).rev()'.
  Si la variable de boucle est une globale (static mut), on utilise un nom
  temporaire et on l'affecte a la globale dans le corps. }
Procedure EmitForStatement(Var I:Integer);
Var
 IdxName,LoopVar:TString;
 LowExpr,HighExpr,SaveOut:TString;
 Down,IdxIsGlobal:Boolean;
Begin
 Inc(I);                     { sauter FOR                                   }
 IdxName:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 IdxIsGlobal:=IsGlobal(IdxName);
 If IdxIsGlobal Then LoopVar:='_'+IdxName Else LoopVar:=IdxName;
 If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
 SaveOut:=OutLine; OutLine:='';
 EmitExprUntil(I,'');         { jusqu'a TO/DOWNTO                           }
 LowExpr:=OutLine;
 OutLine:=SaveOut;
 Down:=False;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
   Down:=True; Inc(I);
 End Else
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Inc(I);
 SaveOut:=OutLine; OutLine:='';
 EmitExprUntil(I,'');         { jusqu'a DO                                  }
 HighExpr:=OutLine;
 OutLine:=SaveOut;
 EmitRaw('for '); EmitRaw(LoopVar); EmitRaw(' in ');
 If Down Then Begin
   EmitRaw('('); EmitRaw(HighExpr); EmitRaw('..='); EmitRaw(LowExpr); EmitRaw(').rev()');
 End Else Begin
   EmitRaw(LowExpr); EmitRaw('..='); EmitRaw(HighExpr);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 If IdxIsGlobal Then Begin
   EmitRaw(' {'); EmitLn;
   Inc(Indent);
   WriteIndent; EmitRaw(IdxName); EmitRaw('_g = '); EmitRaw(LoopVar); EmitRaw(';'); EmitLn;
   WriteIndent;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
     Inc(I);
     EmitStatementList(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   End Else Begin
     EmitStmt(I);
     EmitLn;
   End;
   Dec(Indent);
   WriteIndent; EmitRaw('}');
 End Else
   EmitBlockBody(I);
End;

{ REPEAT body UNTIL cond  vers Rust : loop avec if cond break. }
Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT                                }
 EmitRaw('loop {'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
 WriteIndent; EmitRaw('if ');
 EmitExpr(I);
 EmitRaw(' { break; }'); EmitLn;
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

{ Emet une etiquette de CASE Pascal -> bras Rust 'v1 | v2' ou 'low..=high'. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 First:Boolean;
 LowS,HighS:TString;
 J,K:Integer;
Begin
 First:=True;
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')) do Begin
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin Inc(I); Continue; End;
   If Not First Then EmitRaw(' | ');
   First:=False;
   { lire un selecteur jusqu'a , ou : ou .. }
   J:=I; LowS:='';
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':'))) do Begin
     If (J+1<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')and
        (Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val='.') Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+PasCharToC(Tokens[J].Val);
       TK_STRING:LowS:=LowS+PasStringToC(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   { Intervalle a..b -> a..=b en Rust }
   If (J+1<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')and
      (Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val='.') Then Begin
     Inc(J,2);
     HighS:='';
     K:=J;
     While (K<=TokCount) and Not((Tokens[K].Kind=TK_PUNCT)and((Tokens[K].Val=',')or(Tokens[K].Val=':'))) do Begin
       Case Tokens[K].Kind of
         TK_INT  : HighS:=HighS+Tokens[K].Val;
         TK_CHAR : HighS:=HighS+PasCharToC(Tokens[K].Val);
         TK_STRING:HighS:=HighS+PasStringToC(Tokens[K].Val);
         TK_IDENT: HighS:=HighS+Tokens[K].Val;
         TK_KEYWORD:HighS:=HighS+MapKw(Tokens[K].Val);
       Else
         HighS:=HighS+Tokens[K].Val;
       End;
       Inc(K);
     End;
     EmitRaw(LowS); EmitRaw('..='); EmitRaw(HighS);
     J:=K;
   End Else Begin
     EmitRaw(LowS);
   End;
   I:=J;
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
End;

{ CASE Pascal vers Rust match : v1 | v2 => stmt, low..=high => stmt, _ => ... }
Procedure EmitCaseStatement(Var I:Integer);
Var HasElse:Boolean;
Begin
 Inc(I);                     { sauter CASE                                  }
 EmitRaw('match ');
 EmitExpr(I);
 EmitRaw(' {'); EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
 Inc(Indent);
 HasElse:=False;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
     If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
       Inc(I);
       HasElse:=True;
       WriteIndent; EmitRaw('_ => {'); EmitLn;
       Inc(Indent);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')) do Begin
         WriteIndent;
         EmitStmt(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
         EmitLn;
       End;
       Dec(Indent);
       WriteIndent; EmitRaw('},'); EmitLn;
     End;
     Break;
   End;
   WriteIndent;
   EmitCaseLabels(I);
   EmitRaw(' => {'); EmitLn;
   Inc(Indent);
   WriteIndent;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
     Inc(I);
     EmitStatementList(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   End Else
     EmitStmt(I);
   EmitLn;
   Dec(Indent);
   WriteIndent; EmitRaw('},'); EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 { Rust exige l'exhaustivite : ajouter un bras catch-all si pas d'ELSE. }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
   If Not HasElse Then Begin WriteIndent; EmitRaw('_ => {},'); EmitLn; End;
   Inc(I);
 End;
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

{ Emet une instruction unique. Avance I sur le ';' suivant si present. }
Procedure EmitStmt(Var I:Integer);
Var
 K:TString;
 J:Integer;
 Name:TString;
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
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       Dec(Indent);
       WriteIndent; EmitRaw('}');
     End Else
     If K='IF' Then EmitIfStatement(I) Else
     If K='WHILE' Then EmitWhileStatement(I) Else
     If K='FOR' Then EmitForStatement(I) Else
     If K='REPEAT' Then EmitRepeatStatement(I) Else
     If K='CASE' Then EmitCaseStatement(I) Else
     If K='EXIT' Then Begin
       Inc(I);
       If (CurFunc>0) and (Funcs[CurFunc].IsFunc) Then EmitRaw('return _result_;')
       Else EmitRaw('return;');
     End Else
     If K='BREAK' Then Begin Inc(I); EmitRaw('break;'); End Else
     If K='CONTINUE' Then Begin Inc(I); EmitRaw('continue;'); End Else
     If K='WITH' Then Begin
       EmitRaw('/* WITH non supporte ; expansion manuelle requise */');
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       EmitLn; WriteIndent; EmitStmt(I);
     End Else
     If K='GOTO' Then Begin
       EmitRaw('/* goto '); Inc(I);
       If (I<=TokCount) Then Begin EmitRaw(Tokens[I].Val); Inc(I); End;
       EmitRaw(' non supporte en Rust */');
     End Else Begin
       EmitRaw('/* mot-cle non gere : '+K+' */');
       Inc(I);
     End;
   End;
   TK_IDENT:Begin
     Name:=StrUpper(Tokens[I].Val);
     If (Name='WRITE')or(Name='WRITELN') Then
       EmitWriteCall(I, Name='WRITELN')
     Else If (Name='READ')or(Name='READLN') Then
       EmitReadCall(I, Name='READLN')
     Else If (Name='HALT') Then Begin
       Inc(I);
       EmitRaw('std::process::exit(');
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
         Inc(I); EmitExpr(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
       End Else EmitRaw('0');
       EmitRaw(');');
     End Else If MaybeEmitFuncReturn(I) Then Begin
       { rien : MaybeEmitFuncReturn a deja produit l'affectation }
     End Else Begin
       { affectation ou appel }
       J:=I;
       EmitExprUntil(J,'');
       If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
         EmitRaw(' = ');
         Inc(J);
         EmitExpr(J);
       End;
       I:=J;
       EmitRaw(';');
     End;
   End;
 Else
   { un token isole inattendu : avancer pour eviter une boucle infinie }
   Inc(I);
 End;
End;

{ Emet une suite d'instructions jusqu'a END/UNTIL/ELSE/OTHERWISE/EOF. }
Procedure EmitStatementList(Var I:Integer);
Begin
 While I<=TokCount do Begin
   If StatListEnds(I) Then Break;
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin Inc(I); Continue; End;
   WriteIndent;
   EmitStmt(I);
   EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  DECLARATIONS (CONST / VAR / TYPE)
  ============================================================ }
{ Helper : valeur d'initialisation Rust pour un type donne. }
Function RustDefaultFor(TypeS:TString):TString;
Begin
 If (TypeS='i8')or(TypeS='i16')or(TypeS='i32')or(TypeS='i64')or
    (TypeS='u8')or(TypeS='u16')or(TypeS='u32')or(TypeS='u64')or
    (TypeS='isize')or(TypeS='usize') Then RustDefaultFor:='0'
 Else If TypeS='f32' Then RustDefaultFor:='0.0f32'
 Else If TypeS='f64' Then RustDefaultFor:='0.0f64'
 Else If TypeS='bool' Then RustDefaultFor:='false'
 Else If TypeS='char' Then RustDefaultFor:=''#39'\0'#39
 Else If TypeS='String' Then RustDefaultFor:='String::new()'
 Else RustDefaultFor:='Default::default()';
End;

{ Emet des declarations VAR Pascal en Rust :
   - AsStatic=True  : 'static mut NAME: type = init;' (acces via unsafe).
   - AsStatic=False : 'let mut name: type = init;' (variable locale).
  S'arrete sur un mot-cle de section ou BEGIN/PROCEDURE/FUNCTION. }
Procedure EmitVarSection(Var I:Integer; AsStatic:Boolean);
Var
 Names,Item:TString;
 TypeS,DefV:TString;
 J,LenN,Pos1:Integer;
 K:TString;
 IsArr:Boolean;
 ArrSize,SaveOut:TString;
Begin
 Inc(I);                     { sauter VAR                                   }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If (K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or
        (K='PROCEDURE')or(K='FUNCTION')or(K='IMPLEMENTATION')or
        (K='INITIALIZATION')or(K='LABEL')or(K='USES')or(K='END') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   { collecter les noms separes par , jusqu'a : }
   Names:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       Names:=Names+', '+Tokens[I].Val;
       Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   IsArr:=False; ArrSize:='';
   { type : ARRAY[lo..hi] OF T  ou  STRING  ou  T simple }
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY') Then Begin
     IsArr:=True; Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
       Inc(I);
       { Capturer 'haut' apres '..' jusqu'a ']'. }
       SaveOut:=OutLine; OutLine:='';
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
         If (I+1<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.')and
            (Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.') Then Begin
           Inc(I,2);
           OutLine:='';
           While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
             OutLine:=OutLine+Tokens[I].Val;
             Inc(I);
           End;
           Break;
         End Else Inc(I);
       End;
       ArrSize:='('+OutLine+'+1) as usize';
       If OutLine='' Then ArrSize:='1';
       OutLine:=SaveOut;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
   End;
   { type element }
   TypeS:='i32';
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       TypeS:='String';
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         { sauter [N] de string[N] }
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
       End;
     End Else
     If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') Then Begin
       Inc(I);
       If I<=TokCount Then Begin TypeS:='*mut '+MapPascalType(Tokens[I].Val); Inc(I); End;
     End Else Begin
       TypeS:=MapPascalType(Tokens[I].Val); Inc(I);
     End;
   End;
   DefV:=RustDefaultFor(TypeS);
   { Emission : pour chaque nom, une declaration separee. }
   J:=1; LenN:=Length(Names);
   While J<=LenN do Begin
     Pos1:=J;
     While (J<=LenN) and (Names[J]<>',') do Inc(J);
     Item:=Copy(Names,Pos1,J-Pos1);
     While (Length(Item)>0) and (Item[1]=' ') do Item:=Copy(Item,2,Length(Item)-1);
     WriteIndent;
     If AsStatic Then Begin
       If GlobalCount<MAX_FNS Then Begin
         Inc(GlobalCount); Globals[GlobalCount]:=Item;
       End;
       EmitRaw('static mut '); EmitRaw(Item); EmitRaw('_g: ');
     End Else Begin
       AddLocal(Item);
       EmitRaw('let mut '); EmitRaw(Item); EmitRaw(': ');
     End;
     If IsArr Then Begin
       EmitRaw('['); EmitRaw(TypeS); EmitRaw('; '); EmitRaw(ArrSize); EmitRaw(']');
       EmitRaw(' = ['); EmitRaw(DefV); EmitRaw('; '); EmitRaw(ArrSize); EmitRaw(']');
     End Else Begin
       EmitRaw(TypeS); EmitRaw(' = '); EmitRaw(DefV);
     End;
     EmitRaw(';'); EmitLn;
     If J<=LenN Then Inc(J);
     While (J<=LenN) and (Names[J]=' ') do Inc(J);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ Emet une declaration CONST Pascal en Rust :
   'const Pi = 3.14;'  -> 'const PI: f64 = 3.14;' (deduit le type).
   Le typage Rust requiert un type explicite : on infere int/f64/bool/&str
   d'apres le 1er token de l'expression. }
Procedure EmitConstSection(Var I:Integer);
Var
 K,Name,TypeS:TString;
 J,FirstTok:Integer;
Begin
 Inc(I);                     { sauter CONST                                 }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If (K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or
        (K='PROCEDURE')or(K='FUNCTION')or(K='IMPLEMENTATION')or
        (K='LABEL')or(K='USES')or(K='END')or
        (K='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val;
   Inc(I);
   TypeS:='';
   { type explicite ': type =' }
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
     Inc(I);
     If I<=TokCount Then Begin
       If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
         TypeS:='&''static str'; Inc(I);
       End Else Begin
         TypeS:=MapPascalType(Tokens[I].Val); Inc(I);
       End;
     End;
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) do Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   { si pas de type explicite, deduire selon le 1er token }
   If TypeS='' Then Begin
     FirstTok:=I;
     If (FirstTok<=TokCount)and(Tokens[FirstTok].Kind=TK_OP)and
        ((Tokens[FirstTok].Val='-')or(Tokens[FirstTok].Val='+')) Then Inc(FirstTok);
     If FirstTok<=TokCount Then Begin
       Case Tokens[FirstTok].Kind of
         TK_INT   : TypeS:='i32';
         TK_REAL  : TypeS:='f64';
         TK_STRING: TypeS:='&''static str';
         TK_CHAR  : TypeS:='char';
         TK_KEYWORD:
           If (Tokens[FirstTok].Val='TRUE')or(Tokens[FirstTok].Val='FALSE') Then TypeS:='bool'
           Else TypeS:='i32';
       Else
         TypeS:='i32';
       End;
     End Else TypeS:='i32';
   End;
   WriteIndent;
   EmitRaw('const '); EmitRaw(Name);
   EmitRaw(': '); EmitRaw(TypeS); EmitRaw(' = ');
   J:=I; EmitExprUntil(J,''); I:=J;
   EmitRaw(';'); EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ Emet une declaration TYPE : 'type T = integer;' -> 'type T = i32;'. }
Procedure EmitTypeSection(Var I:Integer);
Var Name,K:TString; J:Integer;
Begin
 Inc(I);                     { sauter TYPE                                  }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If (K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or
        (K='PROCEDURE')or(K='FUNCTION')or(K='IMPLEMENTATION')or
        (K='LABEL')or(K='USES')or(K='END')or
        (K='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   WriteIndent;
   { cas simple : alias de type }
   If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
     EmitRaw('type '); EmitRaw(Name); EmitRaw(' = ');
     EmitRaw(MapPascalType(Tokens[I].Val)); EmitRaw(';'); EmitLn;
     Inc(I);
   End Else Begin
     EmitRaw('// type '); EmitRaw(Name); EmitRaw(' non supporte'); EmitLn;
     J:=I;
     While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';')) do Inc(J);
     I:=J;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  PROCEDURES / FONCTIONS
  ============================================================ }
{ Emet la liste de parametres Rust : '(a, b: integer; var c: real)' ->
   '(a: i32, b: i32, c: &mut f64)'. }
Procedure EmitProcParams(Var I:Integer);
Var
 IsVar:Boolean;
 Names:TString;
 TypeS:TString;
 First:Boolean;
 K:TString;
 J:Integer;
 T,N:TString;
Begin
 EmitRaw('(');
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')) Then Begin
   EmitRaw(')'); Exit;
 End;
 Inc(I);
 First:=True;
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
   IsVar:=False;
   If (Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='VAR')or(Tokens[I].Val='OUT')) Then Begin
     IsVar:=True; Inc(I);
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Inc(I);
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Names:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       Names:=Names+', '+Tokens[I].Val; Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   TypeS:='i32';
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       If IsVar Then TypeS:='String' Else TypeS:='&str';
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else Begin
       K:=Tokens[I].Val;
       TypeS:=MapPascalType(K); Inc(I);
     End;
   End;
   If IsVar Then TypeS:='&mut '+TypeS;
   { dupliquer le type apres chaque nom : 'name: type' }
   T:=''; J:=1; N:='';
   While J<=Length(Names) do Begin
     If Names[J]=',' Then Begin
       If Not First Then T:=T+', ';
       T:=T+N+': '+TypeS;
       AddLocal(N);
       First:=False;
       N:=''; Inc(J);
       While (J<=Length(Names))and(Names[J]=' ') do Inc(J);
     End Else Begin
       N:=N+Names[J]; Inc(J);
     End;
   End;
   If N<>'' Then Begin
     If Not First Then T:=T+', ';
     T:=T+N+': '+TypeS;
     AddLocal(N);
     First:=False;
   End;
   EmitRaw(T);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then EmitRaw(', ');
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 EmitRaw(')');
End;

{ Emet l'en-tete et le corps d'une PROCEDURE/FUNCTION Rust :
   'fn name(args) [-> RetT]' suivi du bloc 'unsafe' contenant le corps.
   Le corps est encadre dans 'unsafe' pour permettre l'acces aux globales
   declarees en 'static mut'. }
Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,RetT:TString;
 PrevFunc:Integer;
 SavedIndent,SavedLocalCount:Integer;
Begin
 IsFunc:=Tokens[I].Val='FUNCTION';
 Inc(I);
 Name:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin Name:=Tokens[I].Val; Inc(I); End;
 RetT:='';
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 SavedLocalCount:=LocalCount;
 LocalCount:=0;
 AddLocal('_result_');
 If IsFunc and (CurFunc>0) and (Funcs[CurFunc].RetType<>'') Then RetT:=Funcs[CurFunc].RetType;
 { Convertir le type de retour C heritage de l'analyse en type Rust :
   on remappe via MapPascalType si besoin. Comme l'analyse a deja produit
   une chaine type C, on la retraduit. }
 If RetT='int' Then RetT:='i32' Else
 If RetT='long' Then RetT:='i64' Else
 If RetT='short' Then RetT:='i16' Else
 If RetT='signed char' Then RetT:='i8' Else
 If RetT='unsigned short' Then RetT:='u16' Else
 If RetT='unsigned char' Then RetT:='u8' Else
 If RetT='unsigned int' Then RetT:='u32' Else
 If RetT='float' Then RetT:='f32' Else
 If RetT='double' Then RetT:='f64' Else
 If RetT='long double' Then RetT:='f64' Else
 If RetT='char*' Then RetT:='String';
 SavedIndent:=Indent;
 EmitRaw('fn '); EmitRaw(Name);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then EmitProcParams(I)
 Else EmitRaw('()');
 { sauter ': type' de fonction }
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
   Inc(I);
   If I<=TokCount Then Inc(I);
 End;
 If IsFunc and (RetT<>'') Then Begin EmitRaw(' -> '); EmitRaw(RetT); End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 { directive forward / external ? }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
    ((Tokens[I].Val='FORWARD')or(Tokens[I].Val='EXTERNAL')) Then Begin
   EmitRaw(' { unimplemented!() }'); EmitLn;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   CurFunc:=PrevFunc;
   LocalCount:=SavedLocalCount;
   Exit;
 End;
 EmitRaw(' { unsafe {'); EmitLn;
 Inc(Indent);
 { declarations locales }
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If Tokens[I].Val='VAR' Then EmitVarSection(I, False) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I) Else
     If Tokens[I].Val='TYPE' Then EmitTypeSection(I) Else
     If Tokens[I].Val='LABEL' Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
     End Else Break;
   End Else Break;
 End;
 { reservation pour Result/EXIT }
 If IsFunc Then Begin
   WriteIndent; EmitRaw('let mut _result_: '); EmitRaw(RetT);
   EmitRaw(' = '); EmitRaw(RustDefaultFor(RetT)); EmitRaw(';'); EmitLn;
 End;
 { corps }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End;
 If IsFunc Then Begin
   WriteIndent; EmitRaw('return _result_;'); EmitLn;
 End;
 Dec(Indent);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 WriteIndent; EmitRaw('} }'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
 Indent:=SavedIndent;
 LocalCount:=SavedLocalCount;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Begin
 EmitRaw('// Genere par PAS2RUST '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw('#![allow(non_snake_case, non_upper_case_globals, unused_mut, unused_variables, unused_assignments, dead_code, unused_imports)]'); EmitLn;
 EmitLn;
End;

Procedure EmitUsesC(Var I:Integer);
Begin
 { On consomme la clause USES sans rien produire (Rust gere ses imports
   directement dans le code emis lorsque necessaire). }
 Inc(I);                     { sauter USES                                  }
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
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
 { sauter PROGRAM/UNIT name; }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
    ((Tokens[I].Val='PROGRAM')or(Tokens[I].Val='UNIT')) Then Begin
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
     If I<=TokCount Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 { sauter INTERFACE pour les unites }
 If IsUnit and (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='INTERFACE') Then Inc(I);

 { USES }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='USES') Then EmitUsesC(I);

 HasMain:=False;
 { Boucle de niveau superieur }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='IMPLEMENTATION' Then Begin Inc(I); Continue; End;
     If (K='INITIALIZATION')or(K='FINALIZATION') Then Begin
       EmitRaw('// Section '); EmitRaw(K); EmitRaw(' non supportee'); EmitLn;
       Inc(I);
       Continue;
     End;
     If (K='USES') Then Begin EmitUsesC(I); Continue; End;
     If (K='CONST') Then Begin EmitConstSection(I); Continue; End;
     If (K='TYPE') Then Begin EmitTypeSection(I); Continue; End;
     If (K='VAR') Then Begin EmitVarSection(I, True); Continue; End;
     If (K='LABEL') Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       Continue;
     End;
     If (K='PROCEDURE')or(K='FUNCTION') Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       HasMain:=True;
       EmitRaw('fn main() { unsafe {'); EmitLn;
       Inc(Indent);
       Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
       Dec(Indent);
       EmitRaw('} }'); EmitLn;
       Continue;
     End;
     If K='END' Then Begin
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
       Continue;
     End;
   End;
   Inc(I);
 End;
 If Not HasMain and Not IsUnit Then Begin
   EmitRaw('fn main() {}'); EmitLn;
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('PAS2RUST ',VERSION,' - Transpilateur Pascal vers Rust');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : PAS2RUST source.pas [destination.rs]');
 WriteLn('Exemple : PAS2RUST hello.pas hello.rs');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.rs'
          Else DstName:=A+'.rs';
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
 WriteLn('PAS2RUST : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procs/funcs).');
End.
