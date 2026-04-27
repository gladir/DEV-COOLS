(*
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal vers le langage Raku (.raku).

  Sources : Turbo Pascal / Free Pascal (mode TP).
  Cible   : code source Raku (anciennement Perl 6).

  Sous-ensemble pris en charge :
    PROGRAM/UNIT, USES (ignore),
    CONST (-> constant $NAME = valeur), TYPE (en commentaire),
    VAR (-> my $name;), PROCEDURE/FUNCTION (-> sub),
    BEGIN..END (-> accolades),
    IF/THEN/ELSE (-> if/elsif/else), WHILE..DO (-> while),
    REPEAT..UNTIL (-> loop avec last if cond),
    FOR..TO/DOWNTO..DO (-> for low..high -> $i),
    CASE..OF (-> given/when), Exit (-> return).

  Mappages d'entrees/sorties :
    Write/WriteLn  -> print(...) / say(...)
    Read/ReadLn    -> $x = get; (chaine), $x = +get; (numerique)

  Particularites Raku :
    - Sigils : variables scalaires prefixees par dollar.
    - Chaines : concatenation avec tilde (et non plus).
    - Operateurs : := -> =, = -> ==, <> -> !=, AND -> &&, OR -> ||,
      NOT -> !, DIV -> div, MOD -> mod, XOR -> +^, SHL -> +<, SHR -> +>.
    - True/False/Nil -> True/False/Nil.
    - Parametres VAR : marques 'is rw' dans la signature.

  Limitations :
    - WITH, ensembles (sets) : commentes en sortie.
    - Pointeurs Pascal non mappes (chapeau ignore).
    - Le typage statique est perdu (Raku est dynamique mais a des contraintes
      optionnelles non emises ici).
    - L'operateur plus Pascal sur des chaines ne devient pas tilde
      automatiquement (ambiguite numerique/chaine) ; les Write/WriteLn
      utilisent deja tilde.

  Compilation : fpc -Mtp PAS2RAKU.PAS
  Usage       : PAS2RAKU source.pas [destination.raku]
*)
Program PAS2RAKU;

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
   RetType : TString;     { type C# de retour ('' si procedure)           }
   IsFunc  : Boolean;
   RefMask : TString;     { 'V' pour chaque param VAR/OUT, 'N' sinon       }
 End;

Var
 Tokens     : Array[1..MAX_TOK] of TToken;
 TokCount   : Integer;
 Funcs      : Array[1..MAX_FNS] of TFuncRec;
 FuncCount  : Integer;
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
 { Registre des noms d'identifiants connus comme VARIABLES (a prefixer
   par '$' a l'emission). Inclut : var globales, parametres, var locales. }
 VarNames   : Array[1..4096] of TString;
 VarCount   : Integer;
 { Registre des noms d'identifiants connus comme CONSTANTES (pas de prefixe). }
 ConstNames : Array[1..1024] of TString;
 ConstCount : Integer;

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

{ Enregistre Name comme variable Raku (a prefixer par '$'). }
Procedure RegisterVar(Name:TString);
Var I:Integer;
Begin
 For I:=1 to VarCount do
   If StrEqualCI(VarNames[I],Name) Then Exit;
 If VarCount>=4096 Then Exit;
 Inc(VarCount); VarNames[VarCount]:=Name;
End;

Function IsVarName(Name:TString):Boolean;
Var I:Integer;
Begin
 IsVarName:=False;
 For I:=1 to VarCount do
   If StrEqualCI(VarNames[I],Name) Then Begin IsVarName:=True; Exit; End;
End;

Procedure RegisterConst(Name:TString);
Var I:Integer;
Begin
 For I:=1 to ConstCount do
   If StrEqualCI(ConstNames[I],Name) Then Exit;
 If ConstCount>=1024 Then Exit;
 Inc(ConstCount); ConstNames[ConstCount]:=Name;
End;

Function IsConstName(Name:TString):Boolean;
Var I:Integer;
Begin
 IsConstName:=False;
 For I:=1 to ConstCount do
   If StrEqualCI(ConstNames[I],Name) Then Begin IsConstName:=True; Exit; End;
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
   C:=NextCh;                       { consomme le premier '.' }
   If PeekCh='.' Then Begin
     { operateur de plage '..' : on consomme le second '.' et on
       emet le nombre puis le token '..'. }
     C:=NextCh;
     If IsReal Then AddToken(TK_REAL,V) Else AddToken(TK_INT,V);
     AddToken(TK_PUNCT,'..');
     Exit;
   End
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
     ')',',',';','[',']','^','@':AddToken(TK_PUNCT,C);
     '.':Begin
       If PeekCh='.' Then Begin C:=NextCh; AddToken(TK_PUNCT,'..'); End
       Else AddToken(TK_PUNCT,'.');
     End;
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
 If U='INTEGER'   Then MapPascalType:='int' Else
 If U='LONGINT'   Then MapPascalType:='int' Else
 If U='INT64'     Then MapPascalType:='int' Else
 If U='SHORTINT'  Then MapPascalType:='int' Else
 If U='SMALLINT'  Then MapPascalType:='int' Else
 If U='WORD'      Then MapPascalType:='int' Else
 If U='BYTE'      Then MapPascalType:='int' Else
 If U='CARDINAL'  Then MapPascalType:='int' Else
 If U='LONGWORD'  Then MapPascalType:='int' Else
 If U='REAL'      Then MapPascalType:='float' Else
 If U='SINGLE'    Then MapPascalType:='float' Else
 If U='DOUBLE'    Then MapPascalType:='float' Else
 If U='EXTENDED'  Then MapPascalType:='float' Else
 If U='CHAR'      Then MapPascalType:='string' Else
 If U='BOOLEAN'   Then MapPascalType:='bool' Else
 If U='STRING'    Then MapPascalType:='string' Else
 If U='ANSISTRING'Then MapPascalType:='string' Else
 If U='POINTER'   Then MapPascalType:='mixed' Else
 If U='TEXT'      Then MapPascalType:='resource' Else
                       MapPascalType:=T;
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean; RefMask:TString);
Begin
 If FuncCount>=MAX_FNS Then Exit;
 Inc(FuncCount);
 Funcs[FuncCount].Name:=Name;
 Funcs[FuncCount].RetType:=RetType;
 Funcs[FuncCount].IsFunc:=IsFunc;
 Funcs[FuncCount].RefMask:=RefMask;
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
 Name,Ret,Mask:TString;
 Depth,CurNames:Integer;
 IsVar:Boolean;
Begin
 FuncCount:=0;
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
       Name:=''; Ret:=''; Mask:='';
       If (J<=TokCount)and(Tokens[J].Kind=TK_IDENT) Then Begin Name:=Tokens[J].Val; Inc(J); End;
       If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Begin
         Inc(J);
         { Pour chaque groupe de parametres separe par ; ou termine par ) :
           detecter VAR/OUT, compter les identifiants jusqu'au ':',
           ajouter autant de marqueurs au masque. }
         IsVar:=False; CurNames:=0;
         While (J<=TokCount) do Begin
           If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Begin
             { fin : flush le groupe courant }
             While CurNames>0 do Begin
               If IsVar Then Mask:=Mask+'V' Else Mask:=Mask+'N';
               Dec(CurNames);
             End;
             Inc(J);
             Break;
           End;
           If (Tokens[J].Kind=TK_KEYWORD)and((Tokens[J].Val='VAR')or(Tokens[J].Val='OUT')) Then Begin
             IsVar:=True; Inc(J); Continue;
           End;
           If (Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='CONST') Then Begin
             IsVar:=False; Inc(J); Continue;
           End;
           If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Begin
             { flush du groupe courant : Mask gagne CurNames marqueurs }
             While CurNames>0 do Begin
               If IsVar Then Mask:=Mask+'V' Else Mask:=Mask+'N';
               Dec(CurNames);
             End;
             { sauter jusqu'au ; ou ) au depth=0 }
             Depth:=0;
             While J<=TokCount do Begin
               If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val='(')or(Tokens[J].Val='[')) Then Inc(Depth)
               Else If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=')')or(Tokens[J].Val=']')) Then Begin
                 If Depth=0 Then Break;
                 Dec(Depth);
               End
               Else If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';') Then Break;
               Inc(J);
             End;
             IsVar:=False;
             If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';') Then Inc(J);
             Continue;
           End;
           If Tokens[J].Kind=TK_IDENT Then Inc(CurNames);
           Inc(J);
         End;
       End;
       If K='FUNCTION' Then Begin
         If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Begin
           Inc(J);
           If (J<=TokCount) Then Begin Ret:=MapPascalType(Tokens[J].Val); Inc(J); End;
         End;
       End;
       If Name<>'' Then RegisterFunc(Name,Ret,K='FUNCTION',Mask);
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine Raku 'abc\'def'.
  On utilise les guillemets simples Raku qui n'interpretent pas les
  variables ($foo) ni les sequences d'echappement (sauf \' et \\). }
Function PasStringToC(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin R:=R+'\'''; Inc(I,2); End
   Else If S[I]='\' Then Begin R:=R+'\\'; Inc(I); End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 PasStringToC:=''''+R+'''';
End;

{ Conversion d'un litteral Pascal #N en Raku : 'A' (string mono-char) ou chr(N). }
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
   PasCharToC:='chr('+Num+')';
End;

{ Mappage d'un operateur Pascal vers Raku. ContextEq=True => '=' represente
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
 If K='DIV' Then MapKw:='div' Else
 If K='MOD' Then MapKw:='mod' Else
 If K='SHL' Then MapKw:='+<' Else
 If K='SHR' Then MapKw:='+>' Else
 If K='XOR' Then MapKw:='+^' Else
 If K='TRUE' Then MapKw:='True' Else
 If K='FALSE' Then MapKw:='False' Else
 If K='NIL' Then MapKw:='Nil' Else
 If K='IN' Then MapKw:='(elem)' Else
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
Procedure EmitOneExprTok(I:Integer);
Var V,Name,Op:TString; IsCall:Boolean; PrevK,NextK:TTokenKind;
Begin
 Case Tokens[I].Kind of
   TK_KEYWORD: EmitRaw(MapKw(Tokens[I].Val));
   TK_OP     : Begin
     Op:=Tokens[I].Val;
     { '+' adjacent a une chaine litterale : utiliser '~' (concatenation Raku). }
     If Op='+' Then Begin
       PrevK:=TK_NONE; NextK:=TK_NONE;
       If I>1 Then PrevK:=Tokens[I-1].Kind;
       If I<TokCount Then NextK:=Tokens[I+1].Kind;
       If (PrevK=TK_STRING)or(PrevK=TK_CHAR)or(NextK=TK_STRING)or(NextK=TK_CHAR) Then
         EmitRaw('~')
       Else
         EmitRaw(MapOp(Op,True));
     End
     Else EmitRaw(MapOp(Op,True));
   End;
   TK_STRING : EmitRaw(PasStringToC(Tokens[I].Val));
   TK_CHAR   : EmitRaw(PasCharToC(Tokens[I].Val));
   TK_INT    : Begin
     V:=Tokens[I].Val;
     If (Length(V)>0)and(V[1]='$') Then EmitRaw('0x'+Copy(V,2,Length(V)-1))
     Else EmitRaw(V);
   End;
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : Begin
     Name:=Tokens[I].Val;
     IsCall:=False;
     If (I<TokCount) and (Tokens[I+1].Kind=TK_PUNCT) and (Tokens[I+1].Val='(') Then
       IsCall:=True;
     { En Raku, prefixer les variables scalaires par '$'. Les noms de
       fonctions/procedures restent sans sigil. On utilise IsCall (suivi
       de '(') et la table IsVarName/IsConstName pour decider. }
     If IsCall Then EmitRaw(Name)
     Else If IsVarName(Name) or IsConstName(Name) Then EmitRaw('$'+Name)
     Else EmitRaw('$'+Name);
   End;
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('')
     Else If Tokens[I].Val='@' Then EmitRaw('')
     Else EmitRaw(Tokens[I].Val);
   End;
 End;
End;

{ Emet des tokens jusqu'a un point d'arret, en gerant la profondeur de
  parentheses/crochets. }
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString);
Const MAX_CALL_DEPTH = 32;
Var
 Depth:Integer;
 NeedSpaceBefore:Boolean;
 IsOpish:Boolean;
 { Pile de calls en cours : pour chaque '(' qui suit un IDENT,
   on memorise le masque ref/val et l'index de l'argument courant. }
 CallMask : Array[1..MAX_CALL_DEPTH] of TString;
 CallArg  : Array[1..MAX_CALL_DEPTH] of Integer;
 CallDepth: Array[1..MAX_CALL_DEPTH] of Integer;
 CallTop  : Integer;
 ArgStart : Boolean;
 FIdx     : Integer;
 PrevWasIdent:Boolean;
 PrevIdent:TString;
Begin
 Depth:=0;
 NeedSpaceBefore:=False;
 CallTop:=0;
 ArgStart:=False;
 PrevWasIdent:=False;
 PrevIdent:='';
 While I<=TokCount do Begin
   If (Depth=0) and IsExprStop(I) Then Break;
   If (Depth=0) and (Tokens[I].Kind=TK_PUNCT) and (Pos(Tokens[I].Val,StopPunct)>0) Then Break;
   { Detection d'ouverture d'appel : IDENT precedent suivi de '(' }
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
     If PrevWasIdent and (CallTop<MAX_CALL_DEPTH) Then Begin
       FIdx:=FindFunc(PrevIdent);
       Inc(CallTop);
       If FIdx>0 Then CallMask[CallTop]:=Funcs[FIdx].RefMask
       Else CallMask[CallTop]:='';
       CallArg[CallTop]:=1;
       CallDepth[CallTop]:=Depth+1;
       ArgStart:=CallMask[CallTop]<>'';
     End;
     Inc(Depth);
   End
   Else If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val=']')) Then Begin
     Dec(Depth);
     If (CallTop>0) and (CallDepth[CallTop]=Depth+1) and (Tokens[I].Val=')') Then Dec(CallTop);
   End
   Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Inc(Depth);
   { Si on est juste apres ',' au niveau de l'appel courant, debut d'arg }
   If (CallTop>0) and (CallDepth[CallTop]=Depth) and
      (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
     Inc(CallArg[CallTop]);
     ArgStart:=True;
   End;
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
   { Si '(' juste emis, l'argument 1 commence apres }
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') and
      (CallTop>0)and(CallDepth[CallTop]=Depth) Then ArgStart:=CallMask[CallTop]<>'';
   { Raku : les parametres VAR sont declares 'is rw' dans la signature de
     la fonction, donc rien a emettre cote appelant. }
   If ArgStart and (CallTop>0) Then ArgStart:=False;
   { Espace apres operateur ou apres , ; }
   NeedSpaceBefore:=False;
   If IsOpish Then NeedSpaceBefore:=True;
   If (Tokens[I].Kind=TK_PUNCT) and ((Tokens[I].Val=',')or(Tokens[I].Val=';')) Then
     NeedSpaceBefore:=True;
   { Memoriser si on vient de voir un IDENT (pour reperer un appel ensuite) }
   If Tokens[I].Kind=TK_IDENT Then Begin
     PrevWasIdent:=True; PrevIdent:=Tokens[I].Val;
   End Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Begin
     { acces tableau : on garde PrevWasIdent True pour l'expression entiere  }
   End Else PrevWasIdent:=False;
   Inc(I);
 End;
End;

Procedure EmitExpr(Var I:Integer);
Begin EmitExprUntil(I,''); End;

{ ============================================================
  WRITE / READ
  ============================================================ }
{ Emet WriteLn(...)/Write(...) sous forme d'un appel say(...) ou print(...) Raku.
  Les arguments sont concatenes via '~' (concat Raku). Les eventuelles
  specifications de format Pascal (:width[:prec]) sont ignorees. }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var First:Boolean; K:Integer;
Begin
 Inc(I);                     { sauter Write/WriteLn                         }
 If IsLn Then EmitRaw('say(') Else EmitRaw('print(');
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then EmitRaw(' ~ ');
     EmitRaw('('); K:=I; EmitExprUntil(K,',)'); I:=K; EmitRaw(')');
     First:=False;
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
 If First Then EmitRaw('''''');   { say sans argument -> ligne vide }
 EmitRaw(')');
End;

{ EmitWriteArg n'est plus utilise par EmitWriteCall mais reste defini
  pour la compatibilite des forwards. }
Procedure EmitWriteArg(Var I:Integer);
Var K:Integer;
Begin
 K:=I; EmitExprUntil(K,',)'); I:=K;
End;

{ Emet ReadLn(x) / Read(x) sous forme d'appels Raku 'get'. }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var First:Boolean; J:Integer; LhsBuf:TString; SaveOut:TString;
Begin
 Inc(I);                     { sauter Read/ReadLn                           }
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then Begin EmitRaw(';'); EmitLn; WriteIndent; End;
     SaveOut:=OutLine;
     OutLine:='';
     J:=I; EmitExprUntil(J,',)'); I:=J;
     LhsBuf:=OutLine;
     OutLine:=SaveOut;
     EmitRaw(LhsBuf);
     EmitRaw(' = get');
     First:=False;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 If IsLn and First Then Begin
   { ReadLn sans argument : consommer une ligne }
   EmitRaw('get');
 End;
End;

{ ============================================================
  INSTRUCTIONS DE CONTROLE
  ============================================================ }
{ Si I pointe sur un appel de la fonction courante en partie gauche
  (FuncName := ...), emettre '$_result_ = ...' et avancer. }
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
     EmitRaw('$_result_ = ');
     EmitExpr(I);
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

{ Emet un bloc enfant Raku : accolade ouvrante newline + indent + corps + dedent + accolade fermante. }
Procedure EmitBlockBody(Var I:Integer);
Begin
 EmitRaw(' {'); EmitLn;
 Inc(Indent);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End Else Begin
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
     Inc(I);
   End Else Begin
     WriteIndent; EmitStmt(I); EmitRaw(';'); EmitLn;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   End;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

Procedure EmitIfStatement(Var I:Integer);
Var Done:Boolean;
Begin
 Inc(I);                     { sauter IF                                    }
 EmitRaw('if (');
 EmitExpr(I);
 EmitRaw(')');
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 EmitBlockBody(I);
 Done:=False;
 While Not Done do Begin
   { Sauter un eventuel ';' avant ELSE }
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='ELSE') Then Inc(I);
   End;
   If Not((I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE')) Then Begin
     Done:=True; Break;
   End;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IF') Then Begin
     Inc(I);
     EmitRaw(' elsif (');
     EmitExpr(I);
     EmitRaw(')');
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
     EmitBlockBody(I);
     { boucler pour traiter d'eventuels else/else if suivants }
   End Else Begin
     EmitRaw(' else');
     EmitBlockBody(I);
     Done:=True;
   End;
 End;
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE                                 }
 EmitRaw('while (');
 EmitExpr(I);
 EmitRaw(')');
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitBlockBody(I);
End;

Procedure EmitForStatement(Var I:Integer);
Var
 IdxName:TString;
 LowExpr,HighExpr:TString;
 Down:Boolean;
 SaveOut:TString;
Begin
 Inc(I);                     { sauter FOR                                   }
 IdxName:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 RegisterVar(IdxName);
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
 If Down Then Begin
   EmitRaw('for ('); EmitRaw(LowExpr); EmitRaw(' ... '); EmitRaw(HighExpr);
   EmitRaw(') -> $'); EmitRaw(IdxName);
 End Else Begin
   EmitRaw('for ('); EmitRaw(LowExpr); EmitRaw(' .. '); EmitRaw(HighExpr);
   EmitRaw(') -> $'); EmitRaw(IdxName);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitBlockBody(I);
End;

{ Pascal REPEAT body UNTIL cond  ->  loop avec last if (cond) }
Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter REPEAT                                }
 EmitRaw('loop {'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
 WriteIndent; EmitRaw('last if (');
 EmitExpr(I);
 EmitRaw(');'); EmitLn;
 Dec(Indent);
 WriteIndent; EmitRaw('}');
End;

{ Lit une etiquette de CASE et la transforme en condition Raku.
  En Raku 'when', on peut utiliser :
    when val               -> egalite avec smartmatch
    when val1|val2         -> alternative
    when low..high         -> intervalle
  Construit l'expression de match dans OutLine via EmitRaw. }
Procedure EmitCaseLabels(Var I:Integer);
Var
 First:Boolean;
 LowS,HighS:TString;
 J,K:Integer;

 Procedure EmitOne;
 Begin
   J:=I; LowS:='';
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':'))) do Begin
     If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..') Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+PasCharToC(Tokens[J].Val);
       TK_STRING:LowS:=LowS+PasStringToC(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+'$'+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='..') Then Begin
     Inc(J);
     HighS:='';
     K:=J;
     While (K<=TokCount) and Not((Tokens[K].Kind=TK_PUNCT)and((Tokens[K].Val=',')or(Tokens[K].Val=':'))) do Begin
       Case Tokens[K].Kind of
         TK_INT  : HighS:=HighS+Tokens[K].Val;
         TK_CHAR : HighS:=HighS+PasCharToC(Tokens[K].Val);
         TK_STRING:HighS:=HighS+PasStringToC(Tokens[K].Val);
         TK_IDENT: HighS:=HighS+'$'+Tokens[K].Val;
         TK_KEYWORD:HighS:=HighS+MapKw(Tokens[K].Val);
       Else
         HighS:=HighS+Tokens[K].Val;
       End;
       Inc(K);
     End;
     EmitRaw(LowS+'..'+HighS);
     I:=K;
   End Else Begin
     EmitRaw(LowS);
     I:=J;
   End;
 End;

Begin
 First:=True;
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')) do Begin
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin Inc(I); Continue; End;
   If Not First Then EmitRaw(' | ');
   First:=False;
   EmitOne;
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
End;

{ Pascal CASE Sel OF ... END  ->  given $sel avec when ... et default ... }
Procedure EmitCaseStatement(Var I:Integer);
Var
 SelExpr,SaveOut:TString;
Begin
 Inc(I);                     { sauter CASE                                  }
 SaveOut:=OutLine; OutLine:='';
 EmitExpr(I);
 SelExpr:=OutLine;
 OutLine:=SaveOut;
 EmitRaw('given ('); EmitRaw(SelExpr); EmitRaw(') {'); EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
 Inc(Indent);
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
     If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
       Inc(I);
       WriteIndent; EmitRaw('default {'); EmitLn;
       Inc(Indent);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')) do Begin
         WriteIndent;
         EmitStmt(I); EmitRaw(';'); EmitLn;
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
       End;
       Dec(Indent);
       WriteIndent; EmitRaw('}'); EmitLn;
     End;
     Break;
   End;
   WriteIndent;
   EmitRaw('when ');
   EmitCaseLabels(I);
   EmitRaw(' {'); EmitLn;
   Inc(Indent);
   WriteIndent;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
     Inc(I);
     EmitStatementList(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   End Else Begin
     EmitStmt(I); EmitRaw(';'); EmitLn;
   End;
   Dec(Indent);
   WriteIndent; EmitRaw('}'); EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
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
       If (CurFunc>0) and (Funcs[CurFunc].IsFunc) Then EmitRaw('return $_result_')
       Else EmitRaw('return');
     End Else
     If K='BREAK' Then Begin Inc(I); EmitRaw('last'); End Else
     If K='CONTINUE' Then Begin Inc(I); EmitRaw('next'); End Else
     If K='WITH' Then Begin
       EmitRaw('# WITH non supporte ; expansion manuelle requise');
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       EmitLn; WriteIndent; EmitStmt(I);
     End Else
     If K='GOTO' Then Begin
       EmitRaw('# goto '); Inc(I);
       If (I<=TokCount) Then Begin EmitRaw(Tokens[I].Val); Inc(I); End;
       EmitRaw(' (non supporte)');
     End Else Begin
       EmitRaw('# mot-cle non gere : '+K);
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
       EmitRaw('exit(');
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
         Inc(I); EmitExpr(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
       End Else EmitRaw('0');
       EmitRaw(')');
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
     End;
   End;
 Else
   { un token isole inattendu : avancer pour eviter une boucle infinie }
   Inc(I);
 End;
End;

{ Emet une suite d'instructions jusqu'a END/UNTIL/ELSE/OTHERWISE/EOF.
  Chaque instruction est terminee par ';'. }
Procedure EmitStatementList(Var I:Integer);
Begin
 While I<=TokCount do Begin
   If StatListEnds(I) Then Break;
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin Inc(I); Continue; End;
   WriteIndent;
   EmitStmt(I);
   EmitRaw(';');
   EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  DECLARATIONS (CONST / VAR / TYPE)
  ============================================================ }
{ Emet des declarations VAR : 'var x, y: integer;' -> 'my $x = 0; my $y = 0;'.
  Pour les tableaux : 'my @x;'.
  S'arrete sur un mot-cle de section ou BEGIN/PROCEDURE/FUNCTION. }
Procedure EmitVarSection(Var I:Integer; AsStatic:Boolean);
Var
 Names:TString;
 TypeS:TString;
 J:Integer;
 K:TString;
 IsArr:Boolean;
 SeenDots:Boolean;
 Lo,Hi:TString;
 Pos1,LenN:Integer;
 NameOne:TString;
Begin
 Inc(I);                     { sauter VAR                                   }
 If False Then If AsStatic Then ;
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
   { type : ARRAY[lo..hi] OF T  ou  STRING  ou  T simple }
   IsArr:=False;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY') Then Begin
     IsArr:=True; Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
       Inc(I);
       Lo:=''; Hi:=''; SeenDots:=False;
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
         If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Begin
           SeenDots:=True; Inc(I); Continue;
         End;
         If SeenDots Then Hi:=Hi+Tokens[I].Val Else Lo:=Lo+Tokens[I].Val;
         Inc(I);
       End;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
   End;
   { type element }
   TypeS:='int';
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       TypeS:='string'; Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
       End;
     End Else
     If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') Then Begin
       Inc(I);
       If I<=TokCount Then Begin TypeS:=MapPascalType(Tokens[I].Val); Inc(I); End;
     End Else Begin
       TypeS:=MapPascalType(Tokens[I].Val); Inc(I);
     End;
   End;
   If False Then If (Lo<>'')or(Hi<>'') Then ; { silence }
   { Emission : pour chaque nom, emettre 'my $name = valeur_initiale;'. }
   J:=1; LenN:=Length(Names);
   While J<=LenN do Begin
     Pos1:=J;
     While (J<=LenN) and (Names[J]<>',') do Inc(J);
     NameOne:=Copy(Names,Pos1,J-Pos1);
     While (Length(NameOne)>0) and (NameOne[1]=' ') do NameOne:=Copy(NameOne,2,Length(NameOne)-1);
     RegisterVar(NameOne);
     WriteIndent;
     If IsArr Then Begin
       EmitRaw('my @'); EmitRaw(NameOne); EmitRaw(';');
     End Else Begin
       EmitRaw('my $'); EmitRaw(NameOne); EmitRaw(' = ');
       If TypeS='string' Then EmitRaw('''''')
       Else If TypeS='bool' Then EmitRaw('False')
       Else If TypeS='int' Then EmitRaw('0')
       Else If TypeS='float' Then EmitRaw('0.0')
       Else EmitRaw('Nil');
       EmitRaw(';');
     End;
     EmitRaw('  # '); EmitRaw(TypeS);
     If IsArr Then EmitRaw('[]');
     EmitLn;
     If J<=LenN Then Inc(J);
     While (J<=LenN) and (Names[J]=' ') do Inc(J);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ Emet une declaration CONST : 'const Pi = 3.14;' -> 'constant $Pi = 3.14;'. }
Procedure EmitConstSection(Var I:Integer; AsStatic:Boolean);
Var K,Name,TypeS:TString; J,Save:Integer; FirstTok:Integer;
Begin
 Inc(I);                     { sauter CONST                                 }
 If False Then If AsStatic Then ;
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
   { type explicite : ': type =' }
   TypeS:='';
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       TypeS:='Str'; Inc(I);
     End Else If I<=TokCount Then Begin
       TypeS:=MapPascalType(Tokens[I].Val); Inc(I);
     End;
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) do Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   { si pas de type explicite, deduire d'apres le 1er token de l'expression }
   If TypeS='' Then Begin
     FirstTok:=I;
     If (FirstTok<=TokCount)and(Tokens[FirstTok].Kind=TK_OP)and
        ((Tokens[FirstTok].Val='-')or(Tokens[FirstTok].Val='+')) Then Inc(FirstTok);
     If FirstTok<=TokCount Then Begin
       Case Tokens[FirstTok].Kind of
         TK_INT   : TypeS:='int';
         TK_REAL  : TypeS:='double';
         TK_STRING: TypeS:='Str';
         TK_CHAR  : TypeS:='char';
         TK_KEYWORD:
           If (Tokens[FirstTok].Val='TRUE')or(Tokens[FirstTok].Val='FALSE') Then TypeS:='boolean'
           Else TypeS:='int';
       Else
         TypeS:='int';
       End;
     End Else TypeS:='int';
   End;
   WriteIndent;
   RegisterConst(Name);
   EmitRaw('constant $'); EmitRaw(Name); EmitRaw(' = ');
   J:=I; Save:=I; EmitExprUntil(J,''); I:=J;
   If I=Save Then EmitRaw('0');
   EmitRaw(';');
   EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ Emet une declaration TYPE : 'type T = integer;' -> commentaire (Raku est dynamique). }
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
   If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
     EmitRaw('# type alias '); EmitRaw(Name); EmitRaw(' = ');
     EmitRaw(MapPascalType(Tokens[I].Val)); EmitLn;
     Inc(I);
   End Else Begin
     EmitRaw('# type '); EmitRaw(Name); EmitRaw(' non supporte'); EmitLn;
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
{ Emet la liste de parametres Raku : '(a, b: integer; var c: real)'
  -> '($a, $b, $c is rw)'. Les VAR/OUT sont marques 'is rw'.
  Enregistre aussi les noms comme variables connues. }
Procedure EmitProcParams(Var I:Integer);
Var
 IsVar:Boolean;
 Names:TString;
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
   { sauter le type Pascal (Raku est dynamique) }
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else Begin
       K:=Tokens[I].Val;
       If False Then If K='' Then ; { silence }
       Inc(I);
     End;
   End;
   { Pour chaque nom dans Names, l'emettre avec sigil '$'. }
   T:=''; J:=1; N:='';
   While J<=Length(Names)+1 do Begin
     If (J>Length(Names)) or (Names[J]=',') Then Begin
       If N<>'' Then Begin
         RegisterVar(N);
         If Not First Then T:=T+', ';
         T:=T+'$'+N;
         If IsVar Then T:=T+' is rw';
         First:=False;
       End;
       N:=''; Inc(J);
       While (J<=Length(Names))and(Names[J]=' ') do Inc(J);
     End Else Begin
       N:=N+Names[J]; Inc(J);
     End;
   End;
   EmitRaw(T);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 EmitRaw(')');
End;

{ Emet l'en-tete et le corps d'une PROCEDURE/FUNCTION Raku.
  Forme : sub nom(parametres) suivi du corps entre accolades. }
Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,RetT:TString;
 PrevFunc:Integer;
 SavedIndent:Integer;
 SavedVarCount:Integer;
Begin
 IsFunc:=Tokens[I].Val='FUNCTION';
 Inc(I);
 Name:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin Name:=Tokens[I].Val; Inc(I); End;
 RetT:='';
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 If IsFunc and (CurFunc>0) and (Funcs[CurFunc].RetType<>'') Then RetT:=Funcs[CurFunc].RetType;
 SavedIndent:=Indent;
 SavedVarCount:=VarCount;
 WriteIndent;
 EmitRaw('sub '); EmitRaw(Name);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then EmitProcParams(I)
 Else EmitRaw('()');
 { sauter ': type' de fonction }
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
   Inc(I);
   If I<=TokCount Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 { directive forward / external ? }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
    ((Tokens[I].Val='FORWARD')or(Tokens[I].Val='EXTERNAL')) Then Begin
   EmitRaw(' { ... } # forward / external'); EmitLn; EmitLn;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   CurFunc:=PrevFunc;
   VarCount:=SavedVarCount;
   Exit;
 End;
 EmitRaw(' {'); EmitLn;
 Inc(Indent);
 { declarations locales }
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If Tokens[I].Val='VAR' Then EmitVarSection(I, False) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I, False) Else
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
   RegisterVar('_result_');
   WriteIndent; EmitRaw('my $_result_ = ');
   If (RetT='string') Then EmitRaw('''''')
   Else If (RetT='bool') Then EmitRaw('False')
   Else If (RetT='float') Then EmitRaw('0.0')
   Else If (RetT='int') Then EmitRaw('0')
   Else EmitRaw('Nil');
   EmitRaw(';'); EmitLn;
 End;
 { corps }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End;
 If IsFunc Then Begin
   WriteIndent; EmitRaw('return $_result_;'); EmitLn;
 End;
 Dec(Indent);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 WriteIndent; EmitRaw('}'); EmitLn; EmitLn;
 CurFunc:=PrevFunc;
 Indent:=SavedIndent;
 VarCount:=SavedVarCount;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Begin
 EmitRaw('#!/usr/bin/env raku'); EmitLn;
 EmitRaw('# Genere par PAS2RAKU '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw('# Programme : '+ProgName); EmitLn;
 EmitRaw('use v6;'); EmitLn;
 EmitLn;
End;

Procedure EmitFileFooter;
Begin
 EmitLn;
End;

Procedure EmitUsesC(Var I:Integer);
Begin
 { On consomme la clause USES sans rien produire de specifique. }
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
       EmitRaw('# Section '); EmitRaw(K); EmitRaw(' non supportee'); EmitLn;
       Inc(I);
       Continue;
     End;
     If (K='USES') Then Begin EmitUsesC(I); Continue; End;
     If (K='CONST') Then Begin EmitConstSection(I, True); Continue; End;
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
       WriteIndent; EmitRaw('# --- corps principal ---'); EmitLn;
       Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
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
   WriteIndent; EmitRaw('# (corps principal vide)'); EmitLn;
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('PAS2RAKU ',VERSION,' - Transpilateur Pascal vers Raku');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : PAS2RAKU source.pas [destination.raku]');
 WriteLn('Exemple : PAS2RAKU hello.pas hello.raku');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.raku'
          Else DstName:=A+'.raku';
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
 EmitFileFooter;
 FlushLine;
 Close(OutFile);
 WriteLn('PAS2RAKU : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procs/funcs).');
End.
