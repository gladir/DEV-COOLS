{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal vers BCPL (.b).

  Sources : Turbo Pascal / Free Pascal (mode TP).
  Cible   : code source BCPL accepte par BINLINUX/BCPL86, utilisant les
            blocs $( ... $), les declarations LET, les commentaires // ... ,
            les chaines "..." avec echappements (*N *T *" **), les
            structures IF..DO, TEST..THEN..ELSE, WHILE..DO, UNTIL..DO,
            FOR i = a TO b [BY n] DO, REPEAT..REPEATWHILE/UNTIL,
            SWITCHON..INTO $( CASE n: ENDCASE  DEFAULT: $), VALOF/RESULTIS
            pour les fonctions, et les routines I/O WRITES, WRITEN,
            WRITECH, NEWLINE, FINISH.

  Sous-ensemble pris en charge :
    PROGRAM/UNIT, USES (ignore), CONST (=> MANIFEST), TYPE (commente),
    VAR (=> LET), PROCEDURE (=> LET P() BE),
    FUNCTION (=> LET F() = VALOF $(... RESULTIS F $)),
    parametres VAR (passes par valeur en BCPL, signale en commentaire),
    BEGIN..END (=> $( ... $)),
    IF/THEN/ELSE (=> IF..DO ou TEST..THEN..ELSE),
    WHILE..DO, REPEAT..UNTIL (=> REPEAT $(...$) REPEATUNTIL),
    FOR..TO/DOWNTO..DO (=> FOR i = a TO b [BY -1] DO),
    CASE..OF (=> SWITCHON..INTO $( CASE n: ENDCASE  DEFAULT: $)),
    Halt (=> FINISH), Exit (=> goto sur etiquette de sortie),
    Write/WriteLn (=> WRITES/WRITEN ; NEWLINE).

  Limitations :
    - BCPL n'a pas de types : tous les Integer/Real/Char/Boolean/String
      sont mappes vers le mot machine BCPL (tout est entier).
    - Les chaines sont emises avec echappements BCPL (*N=newline,
      *T=tab, *"=quote, **=etoile).
    - WITH, ensembles, records, fichiers, objets : commentes en sortie.
    - Tableaux Pascal => allocation par VEC (taille indicative).

  Compilation : fpc -Mtp PAS2BCPL.PAS
  Usage       : PAS2BCPL source.pas [destination.b]
}
Program PAS2BCPL;

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
 Mute       : Boolean;       { si vrai, EmitRaw ne produit aucune sortie    }

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
 If Mute Then Exit;
 For I:=1 to Indent*2 do OutLine:=OutLine+' ';
End;

Procedure EmitRaw(S:TString);
Var I:Integer;
Begin
 If Mute Then Exit;
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine BCPL "abc*"def".
  Echappements BCPL : *N (newline), *T (tab), *" (quote), ** (etoile),
  *S (space), *B (backspace). }
Function PasStringToBCPL(S:TString):TString;
Var
 I:Integer;
 R:TString;
 C:Char;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   { Pascal : '' est un guillemet simple a l'interieur d'une chaine }
   If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin R:=R+''''; Inc(I,2); End
   Else Begin
     C:=S[I];
     Case C of
       '"' : R:=R+'*"';
       '*' : R:=R+'**';
       #9  : R:=R+'*T';
       #10 : R:=R+'*N';
       #13 : ;                  { CR : on absorbe }
     Else
       R:=R+C;
     End;
     Inc(I);
   End;
 End;
 PasStringToBCPL:='"'+R+'"';
End;

{ Conversion d'un litteral Pascal #N en denotation caractere BCPL. }
Function PasCharToBCPL(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 If (Length(Body)>0)and(Body[1]='$') Then Val('$'+Copy(Body,2,Length(Body)-1),V,Code)
 Else Val(Body,V,Code);
 If Code<>0 Then V:=0;
 If (V>=32) and (V<127) and (V<>Ord('"')) and (V<>Ord('*')) and (V<>Ord('''')) Then Begin
   PasCharToBCPL:=''''+Chr(V)+'''';
 End Else Begin
   { On utilise une denotation chaine d'un caractere via echappement BCPL. }
   Case V of
      9: PasCharToBCPL:='''*T''';
     10: PasCharToBCPL:='''*N''';
     34: PasCharToBCPL:='''*"''';
     42: PasCharToBCPL:='''**''';
   Else
     Begin Str(V,Body); PasCharToBCPL:=Body; End;
   End;
 End;
End;

{ Mappage d'un operateur Pascal vers BCPL. ContextEq=True =>
  '=' represente une egalite (en expression), sinon initialisation. }
Function MapOp(Op:TString; ContextEq:Boolean):TString;
Begin
 If Op='<>' Then MapOp:='~=' Else
 If Op=':=' Then MapOp:=':=' Else
 If Op='^'  Then MapOp:='/* ^ non supporte */' Else
 If (Op='=')and ContextEq Then MapOp:='=' Else
 MapOp:=Op;
End;

Function MapKw(K:TString):TString;
Begin
 If K='AND' Then MapKw:='&' Else
 If K='OR'  Then MapKw:='|' Else
 If K='NOT' Then MapKw:='~' Else
 If K='DIV' Then MapKw:='/' Else
 If K='MOD' Then MapKw:='MOD' Else
 If K='SHL' Then MapKw:='<<' Else
 If K='SHR' Then MapKw:='>>' Else
 If K='XOR' Then MapKw:='NEQV' Else
 If K='TRUE' Then MapKw:='TRUE' Else
 If K='FALSE' Then MapKw:='FALSE' Else
 If K='NIL' Then MapKw:='0' Else
 If K='IN' Then MapKw:='/* IN non supporte */' Else
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
   TK_STRING : EmitRaw(PasStringToBCPL(Tokens[I].Val));
   TK_CHAR   : EmitRaw(PasCharToBCPL(Tokens[I].Val));
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
{ En BCPL, on emet une suite d'appels :
    - WRITES("texte")  pour les chaines
    - WRITEN(expr)     pour les entiers/expressions
    - WRITECH(c)       pour les caracteres
    - NEWLINE()        en fin de WriteLn
  Heuristique sur le premier token de l'argument pour choisir :
    - TK_STRING => WRITES
    - TK_CHAR   => WRITECH
    - autre     => WRITEN }
Procedure EmitWriteArg(I0,I1:Integer);
Var Kind:Integer; J:Integer; Proc:TString;
Begin
 If I0>=I1 Then Exit;
 Kind:=0;                      { 0=integer, 1=string, 2=char }
 { Examen du premier token significatif }
 J:=I0;
 If (Tokens[J].Kind=TK_STRING) and (J+1>=I1) Then Kind:=1
 Else If (Tokens[J].Kind=TK_CHAR) and (J+1>=I1) Then Kind:=2;
 Case Kind of
   1: Proc:='WRITES';
   2: Proc:='WRITECH';
 Else
   Proc:='WRITEN';
 End;
 EmitRaw(Proc); EmitRaw('(');
 J:=I0;
 EmitExprUntil(J,':,)');
 If J<I1 Then ;                { suffisant : EmitExprUntil consomme le tout  }
 EmitRaw(')');
End;

{ Emet WriteLn(...)/Write(...) en suite d'appels BCPL.
  I positionne sur l'identifiant Write/WriteLn. }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
 ArgStart,J,Depth:Integer;
 First:Boolean;
Begin
 Inc(I);                       { sauter Write/WriteLn                       }
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then Begin EmitRaw(';'); EmitLn; WriteIndent; End;
     ArgStart:=I;
     { Trouver la fin de l'argument courant : virgule au niveau 0 ou ')' }
     J:=I; Depth:=0;
     While J<=TokCount do Begin
       If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val='(')or(Tokens[J].Val='[')) Then Inc(Depth)
       Else If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=')')or(Tokens[J].Val=']')) Then Begin
         If (Depth=0) and (Tokens[J].Val=')') Then Break;
         Dec(Depth);
       End
       Else If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=',') Then Break
       Else If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Break;
       Inc(J);
     End;
     EmitWriteArg(ArgStart,J);
     I:=J;
     First:=False;
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
   If Not First Then Begin EmitRaw(';'); EmitLn; WriteIndent; End;
   EmitRaw('NEWLINE()');
 End Else
 If First Then EmitRaw('// Write() vide');
End;

{ Emet ReadLn(x) / Read(x). BCPL n'a pas d'equivalent standard direct,
  on emet un commentaire et un appel speculatif a READN. }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var First:Boolean; J:Integer;
Begin
 Inc(I);
 EmitRaw('// Read'); If IsLn Then EmitRaw('Ln'); EmitRaw(' :');
 First:=True;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
     If Not First Then EmitRaw(',');
     EmitRaw(' '); J:=I; EmitExprUntil(J,',)'); I:=J;
     First:=False;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
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

{ Emet un bloc enfant : toujours entoure par $( ... $) en BCPL.
  Ainsi, meme une instruction unique Pascal qui se traduit par
  plusieurs instructions BCPL (ex: WriteLn) reste a l'interieur. }
Procedure EmitBlockBody(Var I:Integer);
Begin
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   EmitRaw(' $('); EmitLn;
   Inc(Indent);
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   Dec(Indent);
   WriteIndent; EmitRaw('$)');
 End Else Begin
   EmitRaw(' $('); EmitLn;
   Inc(Indent);
   WriteIndent;
   EmitStmt(I);
   EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   Dec(Indent);
   WriteIndent; EmitRaw('$)');
 End;
End;

{ IF Pascal sans ELSE -> IF cond DO body
  IF Pascal avec ELSE  -> TEST cond THEN body ELSE body }
Procedure EmitIfStatement(Var I:Integer);
Var
 CondStart:Integer;
 ThenStart:Integer;
 K:Integer;
 HasElse:Boolean;
 Depth:Integer;
 SaveMute:Boolean;
Begin
 Inc(I);                       { sauter IF                                  }
 CondStart:=I;
 { Premiere passe (muette) : sauter la condition jusqu'a THEN au niveau 0. }
 SaveMute:=Mute; Mute:=True;
 EmitExprUntil(I,'');
 Mute:=SaveMute;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 ThenStart:=I;
 { Determine s'il y a un ELSE en avancant un parser jete. }
 K:=ThenStart;
 If (K<=TokCount)and(Tokens[K].Kind=TK_KEYWORD)and(Tokens[K].Val='BEGIN') Then Begin
   Depth:=1; Inc(K);
   While (K<=TokCount) and (Depth>0) do Begin
     If Tokens[K].Kind=TK_KEYWORD Then Begin
       If Tokens[K].Val='BEGIN' Then Inc(Depth)
       Else If Tokens[K].Val='END' Then Dec(Depth);
     End;
     Inc(K);
   End;
 End Else If (K<=TokCount)and(Tokens[K].Kind=TK_KEYWORD)and(Tokens[K].Val='IF') Then Begin
   { Pour un IF imbrique, on doit consommer l'IF complet (avec son ELSE
     eventuel) avant de chercher notre ELSE. }
   K:=ThenStart;
   { On va emuler en muet : sauter la sous-instruction IF. }
   SaveMute:=Mute; Mute:=True;
   EmitStmt(K);
   Mute:=SaveMute;
 End Else Begin
   { saute jusqu'au prochain ; au niveau 0, en passant les ()/[] }
   Depth:=0;
   While K<=TokCount do Begin
     If (Tokens[K].Kind=TK_PUNCT) and ((Tokens[K].Val='(')or(Tokens[K].Val='[')) Then Inc(Depth)
     Else If (Tokens[K].Kind=TK_PUNCT) and ((Tokens[K].Val=')')or(Tokens[K].Val=']')) Then Dec(Depth)
     Else If (Depth=0)and(Tokens[K].Kind=TK_PUNCT)and(Tokens[K].Val=';') Then Break
     Else If (Depth=0)and(Tokens[K].Kind=TK_KEYWORD) and
             ((Tokens[K].Val='ELSE')or(Tokens[K].Val='END')) Then Break;
     Inc(K);
   End;
 End;
 If (K<=TokCount)and(Tokens[K].Kind=TK_PUNCT)and(Tokens[K].Val=';') Then Inc(K);
 HasElse:=(K<=TokCount)and(Tokens[K].Kind=TK_KEYWORD)and(Tokens[K].Val='ELSE');

 { Reemission reelle : condition + corps. }
 I:=CondStart;
 If HasElse Then EmitRaw('TEST ') Else EmitRaw('IF ');
 EmitExprUntil(I,'');
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 If HasElse Then Begin
   EmitRaw(' THEN');
   EmitBlockBody(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='ELSE') Then Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
     Inc(I);
     EmitLn; WriteIndent; EmitRaw('ELSE');
     EmitBlockBody(I);
   End;
 End Else Begin
   EmitRaw(' DO');
   EmitBlockBody(I);
 End;
End;

{ WHILE Pascal -> WHILE c DO body BCPL. }
Procedure EmitWhileStatement(Var I:Integer);
Begin
 Inc(I);                       { sauter WHILE                                }
 EmitRaw('WHILE ');
 EmitExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 EmitRaw(' DO');
 EmitBlockBody(I);
End;

{ FOR Pascal -> FOR i = a TO b DO body BCPL.
  Variante DOWNTO -> FOR i = a TO b BY -1 DO body. }
Procedure EmitForStatement(Var I:Integer);
Var IdxName:TString; Down:Boolean;
Begin
 Inc(I);                       { sauter FOR                                  }
 IdxName:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin IdxName:=Tokens[I].Val; Inc(I); End;
 EmitRaw('FOR '); EmitRaw(IdxName); EmitRaw(' = ');
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
 EmitRaw(' DO');
 EmitBlockBody(I);
End;

{ repeat S until C  ->  REPEAT $( S $) REPEATUNTIL C }
Procedure EmitRepeatStatement(Var I:Integer);
Begin
 Inc(I);                       { sauter REPEAT                               }
 EmitRaw('REPEAT $('); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
 Dec(Indent);
 WriteIndent; EmitRaw('$) REPEATUNTIL ');
 EmitExpr(I);
End;

{ Recolte les valeurs d'une etiquette de CASE jusqu'a ':'.
  Emet une expression booleenne BCPL : (sel = v1) | (sel = v2) | ((sel >= a) & (sel <= b)) }
Procedure EmitCaseLabelExpr(Var I:Integer; SelExpr:TString);
Var First:Boolean; LowS,HighS:TString; J:Integer;
Begin
 First:=True;
 EmitRaw('(');
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')) do Begin
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin Inc(I); Continue; End;
   If Not First Then EmitRaw(' | ');
   First:=False;
   J:=I; LowS:='';
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=',')or(Tokens[J].Val=':'))) do Begin
     If (J+1<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='.')and
        (Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val='.') Then Break;
     Case Tokens[J].Kind of
       TK_INT  : LowS:=LowS+Tokens[J].Val;
       TK_CHAR : LowS:=LowS+PasCharToBCPL(Tokens[J].Val);
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
         TK_CHAR : HighS:=HighS+PasCharToBCPL(Tokens[J].Val);
         TK_IDENT: HighS:=HighS+Tokens[J].Val;
         TK_KEYWORD:HighS:=HighS+MapKw(Tokens[J].Val);
       Else
         HighS:=HighS+Tokens[J].Val;
       End;
       Inc(J);
     End;
     EmitRaw('('); EmitRaw(SelExpr); EmitRaw(' >= '); EmitRaw(LowS);
     EmitRaw(' & '); EmitRaw(SelExpr); EmitRaw(' <= '); EmitRaw(HighS); EmitRaw(')');
   End Else Begin
     EmitRaw('('); EmitRaw(SelExpr); EmitRaw(' = '); EmitRaw(LowS); EmitRaw(')');
   End;
   I:=J;
 End;
 EmitRaw(')');
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
End;

{ Emet le corps d'une branche CASE : un bloc BCPL ou une instruction simple. }
Procedure EmitCaseBranchBody(Var I:Integer);
Begin
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   EmitRaw('$('); EmitLn; Inc(Indent); Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
   Dec(Indent);
   WriteIndent; EmitRaw('$)');
 End Else Begin
   EmitRaw('$('); EmitLn; Inc(Indent);
   WriteIndent;
   EmitStmt(I);
   EmitLn; Dec(Indent);
   WriteIndent; EmitRaw('$)');
 End;
End;

{ CASE Pascal -> cascade TEST cond THEN body ELSE TEST ... ELSE default
  Le selecteur est evalue une fois dans une variable locale au sein
  d'un bloc $( ... $). }
Procedure EmitCaseStatement(Var I:Integer);
Var SelTmp:TString; First:Boolean;
Begin
 Inc(I);                       { sauter CASE                                 }
 SelTmp:=NewLabel('case_');
 EmitRaw('$('); EmitLn;
 Inc(Indent);
 WriteIndent; EmitRaw('LET '); EmitRaw(SelTmp); EmitRaw(' = ');
 EmitExpr(I);
 EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
 First:=True;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) and
      ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
     If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
       Inc(I);
       If First Then Begin
         { Aucun cas avant le ELSE : on emet directement le corps }
         WriteIndent;
       End Else Begin
         EmitLn; WriteIndent; EmitRaw('ELSE ');
       End;
       EmitCaseBranchBody(I);
       EmitLn;
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
     End;
     Break;
   End;
   If First Then Begin WriteIndent; EmitRaw('TEST '); End
   Else Begin EmitLn; WriteIndent; EmitRaw('ELSE TEST '); End;
   First:=False;
   EmitCaseLabelExpr(I, SelTmp);
   EmitRaw(' THEN ');
   EmitCaseBranchBody(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 EmitLn; Dec(Indent);
 WriteIndent; EmitRaw('$)');
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
       EmitRaw('$('); EmitLn;
       Inc(Indent); Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       Dec(Indent);
       WriteIndent; EmitRaw('$)');
     End Else
     If K='IF' Then EmitIfStatement(I) Else
     If K='WHILE' Then EmitWhileStatement(I) Else
     If K='FOR' Then EmitForStatement(I) Else
     If K='REPEAT' Then EmitRepeatStatement(I) Else
     If K='CASE' Then EmitCaseStatement(I) Else
     If K='EXIT' Then Begin
       Inc(I);
       If (CurFunc>0) and (Funcs[CurFunc].ExitLab<>'') Then Begin
         If Funcs[CurFunc].IsFunc Then Begin
           EmitRaw('RESULTIS '); EmitRaw(Funcs[CurFunc].Name);
         End Else
           EmitRaw('RETURN');
       End Else
         EmitRaw('FINISH // EXIT (top-level)');
     End Else
     If K='BREAK' Then Begin Inc(I); EmitRaw('BREAK'); End Else
     If K='CONTINUE' Then Begin Inc(I); EmitRaw('LOOP'); End Else
     If K='WITH' Then Begin
       EmitRaw('// WITH non supporte ');
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do Inc(I);
       If (I<=TokCount) Then Inc(I);
       EmitLn; WriteIndent; EmitStmt(I);
     End Else
     If K='GOTO' Then Begin
       EmitRaw('// GOTO '); Inc(I);
       If (I<=TokCount) Then Begin EmitRaw(Tokens[I].Val); EmitRaw(' (non supporte en BCPL86)'); Inc(I); End;
     End Else Begin
       EmitRaw('// mot-cle non gere : '); EmitRaw(K);
       Inc(I);
     End;
   End;
   TK_IDENT:Begin
     { Detection d'une etiquette Pascal : IDENT ':' (mais pas ':=') }
     If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val=':') Then Begin
       EmitRaw('// etiquette '); EmitRaw(Tokens[I].Val); EmitRaw(': (non supportee en BCPL)');
       Inc(I,2);
       Exit;
     End;
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
       EmitRaw('FINISH');
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

{ Liste d'instructions BCPL : separees par des sauts de ligne (les ';'
  Pascal sont consommes). En BCPL le ; est facultatif. }
Procedure EmitStatementList(Var I:Integer);
Var First:Boolean;
Begin
 First:=True;
 While I<=TokCount do Begin
   If StatListEnds(I) Then Break;
   If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin Inc(I); Continue; End;
   If Not First Then EmitLn;
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
{ VAR section : emettre une declaration LET par variable.
  Pour un tableau Pascal[a..b], emettre LET name = VEC (b-a) ;
  les types sont ignores (BCPL n'a pas de types). }
Procedure EmitVarSection(Var I:Integer);
Var
 Names:TString;
 J,K2:Integer;
 K:TString;
 IsArr:Boolean;
 ArrLow,ArrHigh:TString;
 OneName:TString;
 ArrSize:TString;
Begin
 Inc(I);                       { sauter VAR                                  }
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
   { sauter le type Pascal }
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else
     If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') Then Begin
       Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Begin
       Inc(I);
     End;
   End;
   { Construire la taille du tableau : (high - low + 1) }
   ArrSize:='';
   If IsArr Then Begin
     If ArrLow='0' Then ArrSize:=ArrHigh
     Else If ArrLow='1' Then ArrSize:=ArrHigh
     Else ArrSize:='('+ArrHigh+') - ('+ArrLow+')';
   End;
   { Splitter Names sur ',' et emettre une declaration par nom }
   K2:=1; OneName:='';
   While K2<=Length(Names)+1 do Begin
     If (K2>Length(Names)) or (Names[K2]=',') Then Begin
       If OneName<>'' Then Begin
         WriteIndent;
         If IsArr Then Begin
           EmitRaw('LET '); EmitRaw(OneName); EmitRaw(' = VEC '); EmitRaw(ArrSize);
         End Else Begin
           EmitRaw('LET '); EmitRaw(OneName); EmitRaw(' = 0');
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
   If J=0 Then ;                { evite warning sur J non utilise }
 End;
End;

{ const X = V ;  -> MANIFEST $( X = V $) si V est entier, sinon LET X = V.
  BCPL exige MANIFEST pour les constantes utilisables dans VEC. }
Procedure EmitConstSection(Var I:Integer);
Var K,Name:TString; J,Save:Integer;
    IsInt:Boolean;
Begin
 Inc(I);                       { sauter CONST                                }
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
   { Determiner si la valeur est purement entiere : TK_INT eventuellement
     precede d'un signe '+'/'-'. }
   IsInt:=False;
   J:=I;
   If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and((Tokens[J].Val='+')or(Tokens[J].Val='-')) Then Inc(J);
   If (J<=TokCount)and(Tokens[J].Kind=TK_INT) Then Begin
     If (J+1>TokCount) or
        ((Tokens[J+1].Kind=TK_PUNCT)and(Tokens[J+1].Val=';')) Then IsInt:=True;
   End;
   WriteIndent;
   If IsInt Then Begin
     EmitRaw('MANIFEST $( '); EmitRaw(Name); EmitRaw(' = ');
     Save:=I; EmitExprUntil(Save,''); I:=Save;
     EmitRaw(' $)'); EmitLn;
   End Else Begin
     EmitRaw('LET '); EmitRaw(Name); EmitRaw(' = ');
     Save:=I; EmitExprUntil(Save,''); I:=Save;
     EmitLn;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ TYPE en BCPL : ignore (pas de types), commente. }
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
   EmitRaw('// type '); EmitRaw(Name); EmitRaw(' (ignore en BCPL)'); EmitLn;
   J:=I;
   While (J<=TokCount) and Not((Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=';')) do Inc(J);
   I:=J;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  PROCEDURES / FONCTIONS
  ============================================================ }
{ Construit la signature BCPL d'une liste de parametres Pascal :
   (a, b: T1; var c: T2)  ->  "a, b, c"
  BCPL n'a pas de types et passe tout par valeur, donc on ne fait
  qu'extraire les noms. HasVarParam reste a True si au moins un
  parametre etait VAR (utilise pour avertir en commentaire). }
Procedure EmitProcSignature(Var I:Integer; Var Sig:TString; Var HasVarParam:Boolean);
Var
 IsVar:Boolean;
 Names:TString;
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
   { sauter le type Pascal du parametre }
   If I<=TokCount Then Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
         While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
         If I<=TokCount Then Inc(I);
       End;
     End Else Begin
       Inc(I);
     End;
   End;
   If IsVar Then HasVarParam:=True;
   J:=1; N:='';
   While J<=Length(Names)+1 do Begin
     If (J>Length(Names)) or (Names[J]=',') Then Begin
       If N<>'' Then Begin
         If Sig<>'' Then Sig:=Sig+', ';
         Sig:=Sig+N;
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
 Name,Sig:TString;
 PrevFunc:Integer;
 HasVar:Boolean;
 ExitLab:TString;
Begin
 IsFunc:=Tokens[I].Val='FUNCTION';
 Inc(I);
 Name:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin Name:=Tokens[I].Val; Inc(I); End;
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);

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
   EmitRaw('// forward declaration de '); EmitRaw(Name); EmitLn;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   CurFunc:=PrevFunc;
   Exit;
 End;

 If HasVar Then Begin
   WriteIndent;
   EmitRaw('// note : parametres VAR passes par valeur en BCPL'); EmitLn;
 End;

 { En-tete BCPL :
     pour une procedure :  LET name(args) BE $( ... $)
     pour une fonction  :  LET name(args) = VALOF $( LET name = 0; ... RESULTIS name $) }
 WriteIndent;
 If IsFunc Then Begin
   EmitRaw('LET '); EmitRaw(Name); EmitRaw('('); EmitRaw(Sig); EmitRaw(') = VALOF $('); EmitLn;
 End Else Begin
   EmitRaw('LET '); EmitRaw(Name); EmitRaw('('); EmitRaw(Sig); EmitRaw(') BE $('); EmitLn;
 End;
 Inc(Indent);
 { Pour une fonction, declarer la variable de resultat homonyme. }
 If IsFunc Then Begin
   WriteIndent; EmitRaw('LET '); EmitRaw(Name); EmitRaw(' = 0'); EmitLn;
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
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End;
 { etiquette de sortie : en BCPL on n'a pas d'etiquette directe pour
   sauter dans un bloc, mais on peut utiliser RESULTIS pour sortir
   (uniquement dans VALOF). Le code actuel n'emet pas de GOTO ExitLab,
   donc l'etiquette n'est pas necessaire. }
 If ExitLab='' Then ;          { evite warning sur ExitLab }
 { Pour une fonction : RESULTIS name }
 If IsFunc Then Begin
   WriteIndent; EmitRaw('RESULTIS '); EmitRaw(Name); EmitLn;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw('$)'); EmitLn; EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 CurFunc:=PrevFunc;
End;

{ ============================================================
  EN-TETE DE FICHIER
  ============================================================ }
Procedure EmitFileHeader;
Begin
 EmitRaw('// Genere par PAS2BCPL '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw('// Programme original : '+ProgName); EmitLn;
 EmitLn;
End;

Procedure EmitUsesA58(Var I:Integer);
Begin
 Inc(I);
 EmitRaw('// uses : ');
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
   If Tokens[I].Kind=TK_IDENT Then Begin EmitRaw(Tokens[I].Val); EmitRaw(' '); End;
   Inc(I);
 End;
 EmitLn;
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

 InMainBlock:=False; MainStarted:=False;

 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='USES') Then EmitUsesA58(I);

 { Emettre les sections globales (CONST, TYPE, VAR, PROC/FUNC) au niveau
   superieur du fichier BCPL, puis le bloc principal en LET start() BE. }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='IMPLEMENTATION' Then Begin Inc(I); Continue; End;
     If (K='INITIALIZATION')or(K='FINALIZATION') Then Begin
       EmitRaw('// Section '); EmitRaw(K); EmitRaw(' non supportee'); EmitLn;
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
       EmitRaw('LET start() BE $('); EmitLn;
       Inc(Indent);
       Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
       { Etiquette pour Halt (si Halt utilise) - en BCPL FINISH suffit
         pour terminer le programme, donc rien a faire. }
       If HaltUsed Then ;
       Dec(Indent);
       EmitRaw('$)'); EmitLn;
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
 If Not MainStarted Then Begin EmitRaw('// unite sans corps principal'); EmitLn; End;
 If InMainBlock Then ;          { simple no-op pour eviter avertissement     }
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('PAS2BCPL ',VERSION,' - Transpilateur Pascal vers BCPL');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : PAS2BCPL source.pas [destination.b]');
 WriteLn('Exemple : PAS2BCPL hello.pas hello.b');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.b'
          Else DstName:=A+'.b';
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
 Mute:=False;
 EmitFileHeader;
 EmitTopLevel;
 CloseFiles;
 WriteLn('PAS2BCPL : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procs/funcs).');
End.
