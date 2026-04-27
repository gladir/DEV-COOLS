{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal vers Algol 68 (.a68).

  Sources : Turbo Pascal / Free Pascal (mode TP).
  Cible   : code source Algol 68 (variante de la suite SAMPLES/ALGOL68
            du projet DEV-COOLS, utilisant les modes INT, REAL, BOOL,
            CHAR, STRING, les commentaires CO ... CO, les chaines "...",
            les structures IF/THEN/ELIF/ELSE/FI, WHILE/DO/OD,
            FOR/FROM/TO/BY/DO/OD, et la procedure d'E/S print((...)).

  Sous-ensemble pris en charge :
    PROGRAM/UNIT, USES (ignore), CONST, TYPE (alias simples),
    VAR, PROCEDURE, FUNCTION, parametres VAR (=> REF MODE),
    BEGIN..END, IF/THEN/ELSE, WHILE..DO (=> WHILE..DO..OD),
    REPEAT..UNTIL (=> emule via WHILE/drapeau),
    FOR..TO/DOWNTO..DO (=> FOR i FROM a TO b BY +-1 DO..OD),
    CASE..OF (=> cascade IF/ELIF/ELSE/FI),
    Halt (=> goto halt + label de fin),
    Exit (=> goto sur etiquette de sortie de routine),
    Write/WriteLn (=> print((...))), Read/ReadLn (=> read((...))).

  Limitations :
    - WITH, ensembles (sets), pointeurs : commentes en sortie.
    - Les chaines sont passees en STRING (denotation "..."
      avec doublement des guillemets internes).

  Compilation : fpc -Mtp PAS2AL68.PAS
  Usage       : PAS2AL68 source.pas [destination.a68]
}
Program PAS2AL68;

Const
 VERSION = '1.0';
 MAX_TOK = 65535;
 MAX_FNS = 1024;

Type
 TString = String;
 TTokenKind = (TK_NONE, TK_IDENT, TK_KEYWORD, TK_INT, TK_REAL,
               TK_STRING, TK_CHAR, TK_OP, TK_PUNCT, TK_EOF);
 TToken = Record
   Kind : TTokenKind;
   Val  : TString;
 End;
 TFuncRec = Record
   Name    : TString;       { nom Pascal d'origine                         }
   RetType : TString;       { type Algol 68 (' ' si procedure)             }
   IsFunc  : Boolean;
   ExitLab : TString;       { etiquette pour Exit                          }
   NeedExit: Boolean;       { fonction utilise-t-elle Exit ?               }
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
 ProgName   : TString;
 IsUnit     : Boolean;
 SourceLine : LongInt;
 Indent     : Integer;
 OutLine    : TString;       { ligne en cours d'emission                   }
 SrcCh      : Char;
 SrcEOF     : Boolean;
 SrcPushed  : Integer;       { 0, 1 ou 2 caracteres en attente               }
 SrcPushCh  : Array[1..2] of Char;
 NeedSemi   : Boolean;       { '; ' a inserer avant la prochaine instruction}
 LabelSeq   : Integer;       { compteur d'etiquettes generees              }
 HaltUsed   : Boolean;       { Halt rencontre quelque part ?               }

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

Function NewLabel(Prefix:TString):TString;
Begin
 Inc(LabelSeq);
 NewLabel:=Prefix+IntToStr(LabelSeq);
End;

{ ============================================================
  LEXER (identique a PAS2C)
  ============================================================ }
Procedure TokInit;
Begin
 TokCount:=0;
 SrcEOF:=False;
 SrcPushed:=0;
 SourceLine:=1;
End;

Function NextCh:Char;
Var C:Char;
Begin
 If SrcPushed>0 Then Begin
   NextCh:=SrcPushCh[SrcPushed];
   Dec(SrcPushed);
   Exit;
 End;
 If Eof(InFile) Then Begin SrcEOF:=True; NextCh:=#0; Exit; End;
 If Eoln(InFile) Then Begin ReadLn(InFile); Inc(SourceLine); NextCh:=#10; Exit; End;
 Read(InFile,C);
 NextCh:=C;
End;

Procedure UngetCh(Ch:Char);
Begin
 Inc(SrcPushed);
 SrcPushCh[SrcPushed]:=Ch;
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
 If U='INTEGER'   Then MapPascalType:='INT' Else
 If U='LONGINT'   Then MapPascalType:='INT' Else
 If U='SHORTINT'  Then MapPascalType:='INT' Else
 If U='SMALLINT'  Then MapPascalType:='INT' Else
 If U='WORD'      Then MapPascalType:='INT' Else
 If U='BYTE'      Then MapPascalType:='INT' Else
 If U='CARDINAL'  Then MapPascalType:='INT' Else
 If U='REAL'      Then MapPascalType:='REAL' Else
 If U='SINGLE'    Then MapPascalType:='REAL' Else
 If U='DOUBLE'    Then MapPascalType:='REAL' Else
 If U='EXTENDED'  Then MapPascalType:='REAL' Else
 If U='CHAR'      Then MapPascalType:='CHAR' Else
 If U='BOOLEAN'   Then MapPascalType:='BOOL' Else
 If U='STRING'    Then MapPascalType:='STRING' Else
                       MapPascalType:=StrUpper(T);
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean);
Begin
 If FuncCount>=MAX_FNS Then Exit;
 Inc(FuncCount);
 Funcs[FuncCount].Name:=Name;
 Funcs[FuncCount].RetType:=RetType;
 Funcs[FuncCount].IsFunc:=IsFunc;
 Funcs[FuncCount].ExitLab:='';
 Funcs[FuncCount].NeedExit:=False;
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
 ScopeFunc:Integer;
 NestedDepth:Integer;
Begin
 FuncCount:=0;
 CurFunc:=0;
 IsUnit:=False;
 ProgName:='Program';
 LabelSeq:=0;
 HaltUsed:=False;

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
     End;
   End;
   Inc(I);
 End;

 { Deuxieme passe : reperer les Halt et les Exit, en attribuant chaque
   Exit a la fonction englobante (la plus recemment ouverte). }
 ScopeFunc:=0; NestedDepth:=0;
 I:=1;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='PROCEDURE')or(Tokens[I].Val='FUNCTION')) Then Begin
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT) Then
       ScopeFunc:=FindFunc(Tokens[I+1].Val);
     NestedDepth:=0;
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Inc(NestedDepth)
   Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
     Dec(NestedDepth);
     If NestedDepth<=0 Then Begin
       ScopeFunc:=0; NestedDepth:=0;
     End;
   End Else
   If (Tokens[I].Kind=TK_IDENT)and StrEqualCI(Tokens[I].Val,'HALT') Then HaltUsed:=True
   Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='EXIT') Then Begin
     If ScopeFunc>0 Then Funcs[ScopeFunc].NeedExit:=True
     Else HaltUsed:=True;
   End;
   Inc(I);
 End;
End;

{ ============================================================
  EMISSION : helpers de bas niveau
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
 For I:=1 to Indent*2 do OutLine:=OutLine+' ';
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine Algol 68
  "abc""def" (les guillemets internes sont doubles). }
Function PasStringToA68(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin R:=R+''''; Inc(I,2); End
   Else If S[I]='"' Then Begin R:=R+'""'; Inc(I); End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 PasStringToA68:='"'+R+'"';
End;

{ Conversion d'un litteral Pascal #N en denotation caractere Algol 68. }
Function PasCharToA68(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 If (Length(Body)>0)and(Body[1]='$') Then Val('$'+Copy(Body,2,Length(Body)-1),V,Code)
 Else Val(Body,V,Code);
 If Code<>0 Then V:=0;
 If (V>=32) and (V<127) and (V<>34) Then Begin
   PasCharToA68:='"'+Chr(V)+'"';
 End Else Begin
   { fallback : Algol 68 ne propose pas de denotation \nnn portable
     pour les caracteres de controle, on emet 'REPR n' (pas garanti
     mais documente). }
   Str(V,Body);
   PasCharToA68:='REPR '+Body;
 End;
End;

{ Mappage d'un operateur Pascal vers Algol 68. ContextEq=True =>
  '=' represente une egalite (en expression), sinon initialisation. }
Function MapOp(Op:TString; ContextEq:Boolean):TString;
Begin
 If Op='<>' Then MapOp:='/=' Else
 If Op=':=' Then MapOp:=':=' Else
 If Op='^'  Then MapOp:='**' Else
 If (Op='=')and ContextEq Then MapOp:='=' Else
 MapOp:=Op;
End;

Function MapKw(K:TString):TString;
Begin
 If K='AND' Then MapKw:='AND' Else
 If K='OR'  Then MapKw:='OR' Else
 If K='NOT' Then MapKw:='NOT' Else
 If K='DIV' Then MapKw:='OVER' Else
 If K='MOD' Then MapKw:='MOD' Else
 If K='SHL' Then MapKw:='SHL' Else
 If K='SHR' Then MapKw:='SHR' Else
 If K='XOR' Then MapKw:='/=' Else  { approximation : XOR booleen <=> != }
 If K='TRUE' Then MapKw:='TRUE' Else
 If K='FALSE' Then MapKw:='FALSE' Else
 If K='NIL' Then MapKw:='NIL' Else
 If K='IN' Then MapKw:='CO IN non supporte CO' Else
                 MapKw:=StrUpper(K);
End;

{ ============================================================
  FORWARDS et ETAT
  ============================================================ }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitExprUntil(Var I:Integer; const StopPunct:TString); Forward;
Procedure EmitBlockBody(Var I:Integer); Forward;

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

{ Mappe certains identificateurs builtin Pascal vers Algol 68
  lorsqu'ils sont suivis d'une parenthese (appel de fonction).
  Retourne la chaine a emettre (si nil, emettre l'identificateur tel quel). }
Function MapBuiltinIdent(Name:TString):TString;
Var U:TString;
Begin
 U:=StrUpper(Name);
 If U='CHR' Then MapBuiltinIdent:='REPR' Else
 If U='ORD' Then MapBuiltinIdent:='ABS' Else
 If U='ABS' Then MapBuiltinIdent:='ABS' Else
 If U='ODD' Then MapBuiltinIdent:='ODD' Else
 If U='UPCASE' Then MapBuiltinIdent:='UPCASE' Else
                    MapBuiltinIdent:=Name;
End;

{ Emet un seul token au sein d'une expression. }
Procedure EmitOneExprTok(I:Integer);
Var V:TString; Code:Integer; Hex:LongInt;
Begin
 Case Tokens[I].Kind of
   TK_KEYWORD: EmitRaw(MapKw(Tokens[I].Val));
   TK_OP     : EmitRaw(MapOp(Tokens[I].Val,True));
   TK_STRING : EmitRaw(PasStringToA68(Tokens[I].Val));
   TK_CHAR   : EmitRaw(PasCharToA68(Tokens[I].Val));
   TK_INT    : Begin
     V:=Tokens[I].Val;
     If (Length(V)>0)and(V[1]='$') Then Begin
       Val('$'+Copy(V,2,Length(V)-1),Hex,Code);
       If Code=0 Then EmitRaw(IntToStr(Hex)) Else EmitRaw(V);
     End Else EmitRaw(V);
   End;
   TK_REAL   : EmitRaw(Tokens[I].Val);
   TK_IDENT  : Begin
     { Si suivi d'une parenthese, on regarde si c'est un builtin. }
     If (I<TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') Then
       EmitRaw(MapBuiltinIdent(Tokens[I].Val))
     Else
       EmitRaw(Tokens[I].Val);
   End;
   TK_PUNCT  : Begin
     If Tokens[I].Val='^' Then EmitRaw('^') { puissance Algol 68           }
     Else If Tokens[I].Val='@' Then EmitRaw('/* @ non supporte */')
     Else EmitRaw(Tokens[I].Val);
   End;
 End;
End;

{ Emet des tokens jusqu'a un point d'arret (sans franchir parens/[]). }
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
   IsOpish:=False;
   If Tokens[I].Kind=TK_OP Then IsOpish:=True;
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='AND')or(Tokens[I].Val='OR')or(Tokens[I].Val='DIV')or
       (Tokens[I].Val='MOD')or(Tokens[I].Val='SHL')or(Tokens[I].Val='SHR')or
       (Tokens[I].Val='XOR')or(Tokens[I].Val='NOT')) Then IsOpish:=True;
   If IsOpish or NeedSpaceBefore Then Begin
     If (Length(OutLine)>0) and (OutLine[Length(OutLine)]<>' ') and
        (OutLine[Length(OutLine)]<>'(') and (OutLine[Length(OutLine)]<>'[') Then
       EmitRaw(' ');
   End;
   EmitOneExprTok(I);
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
{ Determine la procedure de sortie Algol 68 a utiliser pour
  l'argument compris entre les tokens [I0..I1-1] (I1 exclus).
  Heuristique :
    - TK_STRING => outstring
    - TK_REAL ou expression contenant un TK_REAL => outreal
    - TRUE/FALSE/NOT/AND/OR/comparaison => outboolean
    - sinon => outinteger }
{ En Algol 68 toutes les valeurs (INT, REAL, BOOL, CHAR, STRING) sont
  imprimables uniformement par print((...)). Aucun choix de procedure
  selon le type n'est necessaire. PickOutProc est conserve pour
  compatibilite mais n'est pas utilise. }
Function PickOutProc(I0,I1:Integer):TString;
Begin
 PickOutProc:='print';
 If I0=I1 Then ;             { evite avertissement parametre non utilise }
End;

{ Emet WriteLn(...)/Write(...) sous forme print((arg1, arg2, ..., newline)).
  I positionne sur l'identifiant Write/WriteLn. }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var First,HadAny:Boolean;
    Save,J:Integer;
Begin
 Inc(I);                     { sauter Write/WriteLn                        }
 EmitRaw('print((');
 First:=True; HadAny:=False;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then EmitRaw(', ');
     Save:=I;
     EmitExprUntil(Save,',)'); J:=Save;
     I:=J;
     First:=False; HadAny:=True;
     { sauter une eventuelle specification de format :width[:prec] }
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
 If IsLn Then Begin
   If HadAny Then EmitRaw(', ');
   EmitRaw('newline');
 End;
 EmitRaw('))');
End;

{ Emet ReadLn(x) / Read(x) sous forme read((x1, x2, ...)). }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var First:Boolean; J:Integer;
Begin
 Inc(I);
 EmitRaw('read((');
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then EmitRaw(', ');
     J:=I; EmitExprUntil(J,',)'); I:=J;
     First:=False;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 EmitRaw('))');
 If IsLn Then ;              { saut de ligne implicite en lecture           }
End;

{ ============================================================
  INSTRUCTIONS DE CONTROLE
  ============================================================ }
{ Si I pointe sur une affectation au nom de la fonction courante,
  emettre 'FuncName := ...' (Algol 68 utilise le meme idiome que Pascal). }
Function MaybeEmitFuncReturn(Var I:Integer):Boolean;
Var J:Integer; Name:TString;
Begin
 MaybeEmitFuncReturn:=False;
 If CurFunc=0 Then Exit;
 If I>TokCount Then Exit;
 If Tokens[I].Kind<>TK_IDENT Then Exit;
 Name:=Tokens[I].Val;
 J:=I+1;
 If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
   If StrEqualCI(Name,Funcs[CurFunc].Name) or StrEqualCI(Name,'RESULT') Then Begin
     EmitRaw(Funcs[CurFunc].Name); EmitRaw(' := ');
     Inc(I,2);
     EmitExpr(I);
     MaybeEmitFuncReturn:=True;
   End;
 End;
End;

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

{ Emet un bloc enfant sur la meme ligne (ou multiligne).
  Si BEGIN..END, ouvre/ferme begin..end ; sinon emet l'instruction. }
Procedure EmitBlockBody(Var I:Integer);
Begin
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   EmitLn;
   WriteIndent; EmitRaw('BEGIN'); EmitLn;
   Inc(Indent);
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   Dec(Indent);
   WriteIndent; EmitRaw('END');
 End Else Begin
   EmitLn;
   Inc(Indent);
   WriteIndent;
   EmitStmt(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   Dec(Indent);
 End;
End;

{ IF Pascal -> IF c THEN s ELSE s FI (Algol 68 : FI obligatoire). }
Procedure EmitIfStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter IF                                   }
 EmitRaw('IF ');
 EmitExpr(I);
 EmitRaw(' THEN');
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 EmitBlockBody(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
   If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='ELSE') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
   Inc(I);
   EmitLn;
   { Cas IF-ELSE-IF imbrique : on emet un ELIF Algol 68. }
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IF') Then Begin
     Inc(I);
     WriteIndent; EmitRaw('ELIF '); EmitExpr(I); EmitRaw(' THEN');
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
     EmitBlockBody(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
       If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='ELSE') Then Inc(I);
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
       Inc(I);
       EmitLn; WriteIndent; EmitRaw('ELSE');
       EmitBlockBody(I);
     End;
     EmitLn; WriteIndent; EmitRaw('FI');
     Exit;
   End;
   WriteIndent; EmitRaw('ELSE');
   EmitBlockBody(I);
 End;
 EmitLn; WriteIndent; EmitRaw('FI');
End;

{ WHILE Pascal -> WHILE c DO s OD (Algol 68). }
Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                     { sauter WHILE                                }
 EmitRaw('WHILE ');
 EmitExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitRaw(' DO'); EmitLn;
 Inc(Indent); WriteIndent;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End Else
   EmitStmt(I);
 Dec(Indent); EmitLn;
 WriteIndent; EmitRaw('OD');
End;

{ FOR Pascal -> FOR i FROM a TO b DO s OD
  Variante DOWNTO -> ... TO b BY -1 DO s OD (Algol 68 accepte aussi DOWNTO). }
Procedure EmitForStatement(Var I:Integer);
Var IdxName:TString; Down:Boolean;
Begin
 Inc(I);                     { sauter FOR                                  }
 IdxName:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 EmitRaw('FOR '); EmitRaw(IdxName); EmitRaw(' FROM ');
 If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
 EmitExprUntil(I,'');
 Down:=False;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
   Down:=True; Inc(I);
 End Else
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Inc(I);
 EmitRaw(' TO ');
 EmitExprUntil(I,'');
 If Down Then EmitRaw(' BY -1');
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitRaw(' DO'); EmitLn;
 Inc(Indent); WriteIndent;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End Else
   EmitStmt(I);
 Dec(Indent); EmitLn;
 WriteIndent; EmitRaw('OD');
End;

{ repeat S until C  ->
  BEGIN BOOL _done := FALSE;
        WHILE NOT _done DO
          S;
          _done := C
        OD
  END (semantiquement equivalent : execution avant test) }
Procedure EmitRepeatStatement(Var I:Integer);
Var DoneVar:TString;
Begin
 Inc(I);                     { sauter REPEAT                               }
 DoneVar:=NewLabel('done_');
 EmitRaw('BEGIN'); EmitLn;
 Inc(Indent);
 WriteIndent; EmitRaw('BOOL '); EmitRaw(DoneVar); EmitRaw(' := FALSE;'); EmitLn;
 WriteIndent; EmitRaw('WHILE NOT '); EmitRaw(DoneVar); EmitRaw(' DO'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
 WriteIndent; EmitRaw('; '); EmitRaw(DoneVar); EmitRaw(' := (');
 EmitExpr(I);
 EmitRaw(')'); EmitLn;
 Dec(Indent);
 WriteIndent; EmitRaw('OD'); EmitLn;
 Dec(Indent);
 WriteIndent; EmitRaw('END');
End;

{ Recolte les valeurs d'une etiquette de CASE jusqu'a ':'.
  Renvoie une liste sous forme de chaines C concatenees pour comparaison. }
Procedure EmitCaseLabelExpr(Var I:Integer; SelExpr:TString);
Var First:Boolean; LowS,HighS:TString; J:Integer;
Begin
 First:=True;
 EmitRaw('(');
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')) do Begin
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin Inc(I); Continue; End;
   If Not First Then EmitRaw(' OR ');
   First:=False;
   J:=I; LowS:='';
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':'))) do Begin
     If (J+1<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')and
        (Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val='.') Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+PasCharToA68(Tokens[J].Val);
       TK_IDENT: LowS:=LowS+Tokens[J].Val;
       TK_KEYWORD:LowS:=LowS+MapKw(Tokens[J].Val);
     Else
       LowS:=LowS+Tokens[J].Val;
     End;
     Inc(J);
   End;
   If (J+1<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')and
      (Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val='.') Then Begin
     Inc(J,2); HighS:='';
     While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':'))) do Begin
       Case Tokens[J].Kind of
         TK_INT  : HighS:=HighS+Tokens[J].Val;
         TK_CHAR : HighS:=HighS+PasCharToA68(Tokens[J].Val);
         TK_IDENT: HighS:=HighS+Tokens[J].Val;
         TK_KEYWORD:HighS:=HighS+MapKw(Tokens[J].Val);
       Else
         HighS:=HighS+Tokens[J].Val;
       End;
       Inc(J);
     End;
     EmitRaw('('); EmitRaw(SelExpr); EmitRaw(' >= '); EmitRaw(LowS);
     EmitRaw(' AND '); EmitRaw(SelExpr); EmitRaw(' <= '); EmitRaw(HighS); EmitRaw(')');
   End Else Begin
     EmitRaw('('); EmitRaw(SelExpr); EmitRaw(' = '); EmitRaw(LowS); EmitRaw(')');
   End;
   I:=J;
 End;
 EmitRaw(')');
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
End;

{ CASE traduit en cascade if ... else if ... else.
  Selecteur evalue UNE FOIS dans une variable temporaire
  declaree dans un bloc englobant (ce qui suppose que l'on
  emette case dans un bloc compose). }
Procedure EmitCaseStatement(Var I:Integer);
Var SelTmp:TString; First:Boolean;
Begin
 Inc(I);                     { sauter CASE                                 }
 SelTmp:=NewLabel('case_');
 EmitRaw('BEGIN'); EmitLn;
 Inc(Indent);
 WriteIndent; EmitRaw('INT '); EmitRaw(SelTmp); EmitRaw(' := ');
 EmitExpr(I);
 EmitRaw(';'); EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
 First:=True;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
     If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
       Inc(I);
       WriteIndent; EmitRaw('ELSE'); EmitLn;
       Inc(Indent);
       WriteIndent;
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
         EmitRaw('BEGIN'); EmitLn; Inc(Indent); Inc(I);
         EmitStatementList(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
         Dec(Indent);
         WriteIndent; EmitRaw('END');
       End Else
         EmitStmt(I);
       Dec(Indent);
       EmitLn;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
     End;
     Break;
   End;
   WriteIndent;
   If First Then EmitRaw('IF ') Else EmitRaw('ELIF ');
   First:=False;
   EmitCaseLabelExpr(I, SelTmp);
   EmitRaw(' THEN');
   EmitLn;
   Inc(Indent);
   WriteIndent;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
     EmitRaw('BEGIN'); EmitLn; Inc(Indent); Inc(I);
     EmitStatementList(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
     Dec(Indent);
     WriteIndent; EmitRaw('END');
   End Else
     EmitStmt(I);
   EmitLn;
   Dec(Indent);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 If Not First Then Begin WriteIndent; EmitRaw('FI'); EmitLn; End;
 Dec(Indent);
 WriteIndent; EmitRaw('END');
End;

{ Emet une instruction unique. }
Procedure EmitStmt(Var I:Integer);
Var
 K:TString; J:Integer; Name:TString;
Begin
 If I>TokCount Then Exit;
 Case Tokens[I].Kind of
   TK_KEYWORD:Begin
     K:=Tokens[I].Val;
     If K='BEGIN' Then Begin
       EmitRaw('BEGIN'); EmitLn;
       Inc(Indent); Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       Dec(Indent);
       WriteIndent; EmitRaw('END');
     End Else
     If K='IF' Then EmitIfStatement(I) Else
     If K='WHILE' Then EmitWhileStatement(I) Else
     If K='FOR' Then EmitForStatement(I) Else
     If K='REPEAT' Then EmitRepeatStatement(I) Else
     If K='CASE' Then EmitCaseStatement(I) Else
     If K='EXIT' Then Begin
       Inc(I);
       If (CurFunc>0) and (Funcs[CurFunc].ExitLab<>'') Then Begin
         EmitRaw('GOTO '); EmitRaw(Funcs[CurFunc].ExitLab);
       End Else
         EmitRaw('CO EXIT non gere CO');
     End Else
     If K='BREAK' Then Begin Inc(I); EmitRaw('CO BREAK non supporte CO'); End Else
     If K='CONTINUE' Then Begin Inc(I); EmitRaw('CO CONTINUE non supporte CO'); End Else
     If K='WITH' Then Begin
       EmitRaw('CO WITH non supporte CO ');
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       EmitLn; WriteIndent; EmitStmt(I);
     End Else
     If K='GOTO' Then Begin
       EmitRaw('GOTO '); Inc(I);
       If (I<=TokCount) Then Begin EmitRaw(Tokens[I].Val); Inc(I); End;
     End Else Begin
       EmitRaw('CO mot-cle non gere : '); EmitRaw(K); EmitRaw(' CO ');
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
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
         If (I<=TokCount) Then Inc(I);
       End;
       EmitRaw('GOTO halt');
     End Else If MaybeEmitFuncReturn(I) Then Begin
       { rien : MaybeEmitFuncReturn a deja produit l'instruction }
     End Else Begin
       J:=I;
       EmitExprUntil(J,'');
       If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
         EmitRaw(' := ');
         Inc(J);
         EmitExpr(J);
       End;
       I:=J;
     End;
   End;
 Else
   Inc(I);
 End;
End;

{ Liste d'instructions Algol 68 : separees par ' ;' (le dernier
  n'a pas de point-virgule, conformement au style Algol). }
Procedure EmitStatementList(Var I:Integer);
Var First:Boolean;
Begin
 First:=True;
 While I<=TokCount do Begin
   If StatListEnds(I) Then Break;
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin Inc(I); Continue; End;
   If Not First Then Begin EmitRaw(' ;'); EmitLn; End
                Else EmitLn;
   WriteIndent;
   EmitStmt(I);
   First:=False;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If Not First Then EmitLn;
End;

{ ============================================================
  DECLARATIONS (CONST / VAR / TYPE)
  ============================================================ }
Procedure EmitVarSection(Var I:Integer);
Var
 Names:TString;
 TypeS:TString;
 J,K2:Integer;
 K:TString;
 IsArr:Boolean;
 ArrLow,ArrHigh:TString;
 DefaultV,OneName:TString;
Begin
 Inc(I);                     { sauter VAR                                  }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If (K='VAR')or(K='CONST')or(K='TYPE')or(K='BEGIN')or
        (K='PROCEDURE')or(K='FUNCTION')or(K='IMPLEMENTATION')or
        (K='INITIALIZATION')or(K='LABEL')or(K='USES')or(K='END') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Names:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       Names:=Names+', '+Tokens[I].Val; Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   IsArr:=False; ArrLow:='1'; ArrHigh:='1';
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY') Then Begin
     IsArr:=True; Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
       Inc(I);
       ArrLow:='';
       { Lecture borne basse jusqu'a `..` ou `]` }
       While I<=TokCount do Begin
         If (Tokens[I].Kind=TK_PUNCT) and (Tokens[I].Val=']') Then Break;
         If (Tokens[I].Kind=TK_PUNCT) and (Tokens[I].Val='.') and
            (I+1<=TokCount) and
            (Tokens[I+1].Kind=TK_PUNCT) and (Tokens[I+1].Val='.') Then Break;
         ArrLow:=ArrLow+Tokens[I].Val;
         Inc(I);
       End;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Begin
         Inc(I);
         If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
         ArrHigh:='';
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
           ArrHigh:=ArrHigh+Tokens[I].Val;
           Inc(I);
         End;
       End;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
   End;
   TypeS:='INT';
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       TypeS:='STRING'; Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else
     If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') Then Begin
       Inc(I);
       If I<=TokCount Then Begin TypeS:='REF '+MapPascalType(Tokens[I].Val); Inc(I); End;
     End Else Begin
       TypeS:=MapPascalType(Tokens[I].Val); Inc(I);
     End;
   End;
   { Determiner la valeur par defaut selon le mode }
   DefaultV:='0';
   If TypeS='REAL' Then DefaultV:='0.0' Else
   If TypeS='BOOL' Then DefaultV:='FALSE' Else
   If TypeS='STRING' Then DefaultV:='""' Else
   If TypeS='CHAR' Then DefaultV:='" "';
   { Splitter Names sur ',' et emettre une declaration par nom }
   K2:=1; OneName:='';
   While K2<=Length(Names)+1 do Begin
     If (K2>Length(Names)) or (Names[K2]=',') Then Begin
       If OneName<>'' Then Begin
         WriteIndent;
         If IsArr Then Begin
           EmitRaw('['); EmitRaw(ArrLow); EmitRaw(':'); EmitRaw(ArrHigh); EmitRaw('] ');
           EmitRaw(TypeS); EmitRaw(' '); EmitRaw(OneName); EmitRaw(';');
         End Else Begin
           EmitRaw(TypeS); EmitRaw(' '); EmitRaw(OneName); EmitRaw(' := '); EmitRaw(DefaultV); EmitRaw(';');
         End;
         EmitLn;
       End;
       OneName:=''; Inc(K2);
       While (K2<=Length(Names))and(Names[K2]=' ') do Inc(K2);
     End Else Begin
       OneName:=OneName+Names[K2]; Inc(K2);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ const X = V ;  -> MODE X = V; (en Algol 68, '=' declare une constante,
  avec le type infere depuis la valeur). }
Procedure EmitConstSection(Var I:Integer);
Var K,Name:TString; J:Integer;
    IsReal,IsString,IsBool:Boolean;
    Mode:TString;
Begin
 Inc(I);                     { sauter CONST                                }
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
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
     Inc(I);
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) do Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   { detecter type a partir de la valeur }
   IsReal:=False; IsString:=False; IsBool:=False;
   J:=I;
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';')) do Begin
     If Tokens[J].Kind=TK_REAL Then IsReal:=True;
     If Tokens[J].Kind=TK_STRING Then IsString:=True;
     If (Tokens[J].Kind=TK_KEYWORD)and((Tokens[J].Val='TRUE')or(Tokens[J].Val='FALSE')) Then IsBool:=True;
     Inc(J);
   End;
   Mode:='INT';
   If IsString Then Mode:='STRING' Else
   If IsReal Then Mode:='REAL' Else
   If IsBool Then Mode:='BOOL';
   WriteIndent;
   EmitRaw(Mode); EmitRaw(' '); EmitRaw(Name); EmitRaw(' = ');
   J:=I; EmitExprUntil(J,''); I:=J;
   EmitRaw(';'); EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

Procedure EmitTypeSection(Var I:Integer);
Var Name,K:TString; J:Integer;
Begin
 Inc(I);
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
   EmitRaw('CO type '); EmitRaw(Name); EmitRaw(' = ');
   If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
     EmitRaw(MapPascalType(Tokens[I].Val)); Inc(I);
   End;
   EmitRaw(' CO'); EmitLn;
   J:=I;
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';')) do Inc(J);
   I:=J;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  PROCEDURES / FONCTIONS
  ============================================================ }
{ Construit la signature Algol 68 d'une liste de parametres Pascal :
   (a, b: T1; var c: T2)  ->  "T1 a, T1 b, REF T2 c"
  Sig recoit le texte complet entre parentheses (sans les parentheses).
  HasVarParam est mis a True si au moins un parametre est VAR (REF). }
Procedure EmitProcSignature(Var I:Integer; Var Sig:TString; Var HasVarParam:Boolean);
Var
 IsVar:Boolean;
 Names:TString;
 TypeS:TString;
 K:TString;
 J:Integer;
 N:TString;
Begin
 Sig:=''; HasVarParam:=False;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')) Then Exit;
 Inc(I);
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
   IsVar:=False;
   If (Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='VAR')or(Tokens[I].Val='OUT')) Then Begin
     IsVar:=True; Inc(I);
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Inc(I);
   If (I>TokCount) or (Tokens[I].Kind<>TK_IDENT) Then Begin
     If I<=TokCount Then Inc(I);
     Continue;
   End;
   Names:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       Names:=Names+','+Tokens[I].Val; Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   TypeS:='INT';
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       TypeS:='STRING'; Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else Begin
       K:=Tokens[I].Val;
       TypeS:=MapPascalType(K); Inc(I);
     End;
   End;
   If IsVar Then Begin TypeS:='REF '+TypeS; HasVarParam:=True; End;
   { Pour chaque nom : ajouter "TypeS Name" a Sig, separes par ", " }
   J:=1; N:='';
   While J<=Length(Names)+1 do Begin
     If (J>Length(Names)) or (Names[J]=',') Then Begin
       If N<>'' Then Begin
         If Sig<>'' Then Sig:=Sig+', ';
         Sig:=Sig+TypeS+' '+N;
       End;
       N:=''; Inc(J);
     End Else Begin
       N:=N+Names[J]; Inc(J);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
End;

Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,RetT,Sig,DefaultVal:TString;
 PrevFunc:Integer;
 HasVar,BodyHasStmts:Boolean;
 ExitLab:TString;
 StartI:Integer;
Begin
 IsFunc:=Tokens[I].Val='FUNCTION';
 Inc(I);
 Name:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin Name:=Tokens[I].Val; Inc(I); End;
 RetT:='VOID';
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 If IsFunc and (CurFunc>0) and (Funcs[CurFunc].RetType<>'') Then RetT:=Funcs[CurFunc].RetType;

 { Recolter parametres }
 Sig:=''; HasVar:=False;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then
   EmitProcSignature(I, Sig, HasVar);

 { sauter ': type' de fonction }
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
   Inc(I);
   If I<=TokCount Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 { directive forward / external ? }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
    ((Tokens[I].Val='FORWARD')or(Tokens[I].Val='EXTERNAL')) Then Begin
   WriteIndent;
   EmitRaw('CO forward declaration de '); EmitRaw(Name); EmitRaw(' CO'); EmitLn;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   CurFunc:=PrevFunc;
   Exit;
 End;

 { En-tete Algol 68 : PROC name = (sig) rettype : BEGIN ... END; }
 WriteIndent;
 EmitRaw('PROC '); EmitRaw(Name); EmitRaw(' = (');
 EmitRaw(Sig); EmitRaw(') '); EmitRaw(RetT); EmitRaw(' :'); EmitLn;
 WriteIndent; EmitRaw('BEGIN'); EmitLn;
 Inc(Indent);
 { Pour une fonction, declarer une variable locale resultat ayant
   le meme nom que la fonction (idiome Pascal). Algol 68 utilisera
   la valeur de cette variable comme valeur retournee. }
 DefaultVal:='0';
 If RetT='REAL' Then DefaultVal:='0.0' Else
 If RetT='BOOL' Then DefaultVal:='FALSE' Else
 If RetT='STRING' Then DefaultVal:='""' Else
 If RetT='CHAR' Then DefaultVal:='" "';
 If IsFunc and (RetT<>'VOID') Then Begin
   WriteIndent; EmitRaw(RetT); EmitRaw(' '); EmitRaw(Name); EmitRaw(' := '); EmitRaw(DefaultVal); EmitRaw(';'); EmitLn;
 End;

 { Etiquette de sortie pour Exit (uniquement si utilisee) }
 ExitLab:='';
 If (CurFunc>0) and Funcs[CurFunc].NeedExit Then Begin
   ExitLab:=NewLabel('proc_exit_');
   Funcs[CurFunc].ExitLab:=ExitLab;
 End;

 { declarations locales }
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If Tokens[I].Val='VAR' Then EmitVarSection(I) Else
     If Tokens[I].Val='CONST' Then EmitConstSection(I) Else
     If Tokens[I].Val='TYPE' Then EmitTypeSection(I) Else
     If Tokens[I].Val='LABEL' Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
     End Else Break;
   End Else Break;
 End;

 { corps }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   StartI:=I;
   EmitStatementList(I);
   BodyHasStmts:=(I>StartI);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End Else BodyHasStmts:=False;
 { etiquette de sortie }
 If ExitLab<>'' Then Begin
   If BodyHasStmts Then Begin EmitRaw(';'); EmitLn; End;
   WriteIndent; EmitRaw(ExitLab); EmitRaw(': SKIP'); EmitLn;
   BodyHasStmts:=True;
 End;
 { Pour une fonction, retourner la valeur (derniere expression).
   La declaration de Name s'est terminee par un ; donc inutile d'en ajouter
   si le corps est vide. }
 If IsFunc and (RetT<>'VOID') Then Begin
   If BodyHasStmts Then Begin EmitRaw(';'); EmitLn; End;
   WriteIndent; EmitRaw(Name); EmitLn;
 End Else
 If Not BodyHasStmts Then Begin
   { PROC vide : SKIP requis }
   WriteIndent; EmitRaw('SKIP'); EmitLn;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw('END;'); EmitLn; EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 CurFunc:=PrevFunc;
 If HasVar Then ;            { evite avertissement }
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Begin
 EmitRaw('CO Genere par PAS2AL68 '+VERSION+' a partir de '+SrcName+' CO'); EmitLn;
 EmitRaw('CO Programme original : '+ProgName+' CO'); EmitLn;
 EmitLn;
End;

Procedure EmitUsesA58(Var I:Integer);
Begin
 Inc(I);
 EmitRaw('CO uses : ');
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
   If Tokens[I].Kind=TK_IDENT Then Begin EmitRaw(Tokens[I].Val); EmitRaw(' '); End;
   Inc(I);
 End;
 EmitRaw('CO'); EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
End;

{ ============================================================
  BLOC PRINCIPAL
  ============================================================ }
Procedure EmitTopLevel;
Var
 I:Integer;
 K:TString;
 InMainBlock:Boolean;
 MainStarted:Boolean;
Begin
 I:=1;
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
 If IsUnit and (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='INTERFACE') Then Inc(I);

 { Niveau global : un grand BEGIN..END englobant tout le programme. }
 EmitRaw('BEGIN'); EmitLn;
 Inc(Indent);
 InMainBlock:=False; MainStarted:=False;

 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='USES') Then EmitUsesA58(I);

 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='IMPLEMENTATION' Then Begin Inc(I); Continue; End;
     If (K='INITIALIZATION')or(K='FINALIZATION') Then Begin
       WriteIndent; EmitRaw('CO Section '); EmitRaw(K); EmitRaw(' non supportee CO'); EmitLn;
       Inc(I);
       Continue;
     End;
     If (K='USES') Then Begin EmitUsesA58(I); Continue; End;
     If (K='CONST') Then Begin EmitConstSection(I); Continue; End;
     If (K='TYPE') Then Begin EmitTypeSection(I); Continue; End;
     If (K='VAR') Then Begin EmitVarSection(I); Continue; End;
     If (K='LABEL') Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       Continue;
     End;
     If (K='PROCEDURE')or(K='FUNCTION') Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       MainStarted:=True;
       InMainBlock:=True;
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
 If Not MainStarted Then Begin WriteIndent; EmitRaw('CO unite sans corps principal CO'); EmitLn; End;
 { Etiquette pour Halt (uniquement si Halt est utilise) }
 If HaltUsed Then Begin
   WriteIndent; EmitRaw(';'); EmitLn;
   WriteIndent; EmitRaw('halt: SKIP'); EmitLn;
 End;
 Dec(Indent);
 EmitRaw('END'); EmitLn;
 If InMainBlock Then ;        { simple no-op pour eviter avertissement     }
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('PAS2AL68 ',VERSION,' - Transpilateur Pascal vers Algol 68');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : PAS2AL68 source.pas [destination.a68]');
 WriteLn('Exemple : PAS2AL68 hello.pas hello.a68');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.a68'
          Else DstName:=A+'.a68';
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

Begin
 ParseArgs;
 OpenFiles;
 TokInit;
 Tokenize;
 Close(InFile);
 Analyze;
 OutLine:='';
 Indent:=0;
 NeedSemi:=False;
 EmitFileHeader;
 EmitTopLevel;
 CloseFiles;
 WriteLn('PAS2AL68 : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procs/funcs).');
End.
