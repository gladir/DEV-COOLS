{
  @author: Gladir.com (Sylvain Maltais)
  @description: Transpilateur Turbo Pascal/Free Pascal vers le langage
                Common Lisp (.lisp / .lsp).

  Sources : Turbo Pascal / Free Pascal (mode TP).
  Cible   : code source Common Lisp (compatible CLISP, SBCL).

  Sous-ensemble pris en charge :
    PROGRAM/UNIT, USES (ignore),
    CONST (-> defparameter / defconstant),
    TYPE (en commentaire),
    VAR (-> defparameter au niveau global ; let* dans les routines),
    PROCEDURE/FUNCTION (-> defun),
    BEGIN..END (-> progn),
    IF/THEN/ELSE (-> if / cond),
    WHILE..DO (-> loop while ... do ...),
    REPEAT..UNTIL (-> loop do ... until cond),
    FOR..TO/DOWNTO..DO (-> loop for ... from ... to/downto ... do),
    CASE..OF (-> case ... otherwise),
    Exit (-> return-from <fonction>),
    Break (-> loop-finish), Continue (-> commentaire).

  Mappages d'entrees/sorties :
    Write(x,y)    -> (progn (princ x) (princ y))
    WriteLn(x,y)  -> (progn (princ x) (princ y) (terpri))
    Read(x)       -> (setf x (read))
    ReadLn(x)     -> (setf x (read-line))

  Particularites Lisp :
    - Notation prefixe : un parseur d'expressions infixe convertit
      les expressions Pascal vers des S-expressions Lisp.
    - Operateurs : := -> setf, = (egalite) -> equal pour generalite,
      <> -> /= pour les nombres (geree comme (not (equal a b))),
      AND/OR/NOT -> and/or/not, DIV -> floor, MOD -> mod, XOR -> logxor,
      SHL -> ash (positif), SHR -> ash (negatif).
    - true/false/nil -> t/nil/nil.
    - Les parametres VAR ne sont pas reellement supportes (Lisp passe
      par valeur sauf pour les structures mutables) ; un commentaire
      est ajoute pour signaler le probleme.

  Limitations :
    - WITH, ensembles (sets), pointeurs : commentes en sortie.
    - Le typage statique est perdu (Lisp est dynamique).
    - Les chaines Pascal et caracteres sont fusionnes en strings Lisp.

  Compilation : fpc -Mtp PAS2LISP.PAS
  Usage       : PAS2LISP source.pas [destination.lisp]
}
Program PAS2LISP;

Const
 VERSION = '1.0';
 MAX_TOK = 65535;
 MAX_FNS = 1024;
 MAX_VAR = 4096;

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
   RetType : TString;
   IsFunc  : Boolean;
   RefMask : TString;
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
 Indent     : Integer;
 OutLine    : TString;
 VarNames   : Array[1..MAX_VAR] of TString;
 VarCount   : Integer;
 ConstNames : Array[1..MAX_VAR] of TString;
 ConstCount : Integer;

{ ============================================================
  UTILITAIRES DE CHAINE
  ============================================================ }
Function StrUpper(S:TString):TString;
Var I:Integer; R:TString;
Begin
 R:='';
 For I:=1 to Length(S) do
   If (S[I]>='a')and(S[I]<='z') Then R:=R+Chr(Ord(S[I])-32)
   Else R:=R+S[I];
 StrUpper:=R;
End;

Function StrLower(S:TString):TString;
Var I:Integer; R:TString;
Begin
 R:='';
 For I:=1 to Length(S) do
   If (S[I]>='A')and(S[I]<='Z') Then R:=R+Chr(Ord(S[I])+32)
   Else R:=R+S[I];
 StrLower:=R;
End;

Function StrEqualCI(A,B:TString):Boolean;
Begin StrEqualCI:=StrUpper(A)=StrUpper(B); End;

Function IntToStr(N:LongInt):TString;
Var S:TString;
Begin Str(N,S); IntToStr:=S; End;

{ ============================================================
  REGISTRES DE NOMS
  ============================================================ }
Procedure RegisterVar(Const Name:TString);
Var I:Integer;
Begin
 For I:=1 to VarCount do If StrEqualCI(VarNames[I],Name) Then Exit;
 If VarCount<MAX_VAR Then Begin
   Inc(VarCount);
   VarNames[VarCount]:=Name;
 End;
End;

Procedure RegisterConst(Const Name:TString);
Var I:Integer;
Begin
 For I:=1 to ConstCount do If StrEqualCI(ConstNames[I],Name) Then Exit;
 If ConstCount<MAX_VAR Then Begin
   Inc(ConstCount);
   ConstNames[ConstCount]:=Name;
 End;
End;

Function FindFunc(Const Name:TString):Integer;
Var I:Integer;
Begin
 FindFunc:=0;
 For I:=1 to FuncCount do
   If StrEqualCI(Funcs[I].Name,Name) Then Begin FindFunc:=I; Exit; End;
End;

{ ============================================================
  LEXEUR
  ============================================================ }
Var
 LexBuf  : TString;
 LexPos  : Integer;
 LexLine : Integer;

Procedure TokInit;
Begin
 LexBuf:='';
 LexPos:=1;
 LexLine:=1;
 TokCount:=0;
 FuncCount:=0;
 VarCount:=0;
 ConstCount:=0;
 ProgName:='';
 IsUnit:=False;
End;

Procedure AddTok(K:TTokenKind; Const V:TString);
Begin
 If TokCount<MAX_TOK Then Begin
   Inc(TokCount);
   Tokens[TokCount].Kind:=K;
   Tokens[TokCount].Val:=V;
 End;
End;

Function IsKeyword(Const W:TString):Boolean;
Var U:TString;
Begin
 U:=StrUpper(W);
 IsKeyword:=
   (U='PROGRAM')or(U='UNIT')or(U='USES')or(U='INTERFACE')or
   (U='IMPLEMENTATION')or(U='INITIALIZATION')or(U='FINALIZATION')or
   (U='BEGIN')or(U='END')or(U='CONST')or(U='TYPE')or(U='VAR')or
   (U='LABEL')or(U='PROCEDURE')or(U='FUNCTION')or(U='IF')or(U='THEN')or
   (U='ELSE')or(U='WHILE')or(U='DO')or(U='REPEAT')or(U='UNTIL')or
   (U='FOR')or(U='TO')or(U='DOWNTO')or(U='CASE')or(U='OF')or
   (U='OTHERWISE')or(U='RECORD')or(U='ARRAY')or(U='STRING')or
   (U='SET')or(U='FILE')or(U='WITH')or(U='GOTO')or(U='EXIT')or
   (U='BREAK')or(U='CONTINUE')or(U='AND')or(U='OR')or(U='NOT')or
   (U='DIV')or(U='MOD')or(U='SHL')or(U='SHR')or(U='XOR')or
   (U='IN')or(U='TRUE')or(U='FALSE')or(U='NIL')or(U='FORWARD')or
   (U='EXTERNAL')or(U='OBJECT')or(U='CLASS')or(U='PRIVATE')or
   (U='PUBLIC')or(U='PROTECTED')or(U='PUBLISHED');
End;

Function ReadLineFromFile:Boolean;
Var S:TString;
Begin
 If EOF(InFile) Then Begin ReadLineFromFile:=False; Exit; End;
 ReadLn(InFile,S);
 LexBuf:=S+#10;
 LexPos:=1;
 Inc(LexLine);
 ReadLineFromFile:=True;
End;

Function PeekCh:Char;
Begin
 While LexPos>Length(LexBuf) do
   If Not ReadLineFromFile Then Begin PeekCh:=#0; Exit; End;
 PeekCh:=LexBuf[LexPos];
End;

Function NextCh:Char;
Var Tmp:Char;
Begin
 Tmp:=PeekCh;
 NextCh:=Tmp;
 If Tmp<>#0 Then Inc(LexPos);
End;

Procedure SkipBraceComment;
Begin
 While True do Begin
   If PeekCh=#0 Then Exit;
   If PeekCh='}' Then Begin NextCh; Exit; End;
   NextCh;
 End;
End;

Procedure SkipParenStarComment;
Var Prev:Char;
Begin
 Prev:=#0;
 While True do Begin
   If PeekCh=#0 Then Exit;
   If (Prev='*')and(PeekCh=')') Then Begin NextCh; Exit; End;
   Prev:=NextCh;
 End;
End;

Procedure SkipLineComment;
Begin
 While True do Begin
   If (PeekCh=#0)or(PeekCh=#10) Then Exit;
   NextCh;
 End;
End;

Procedure Tokenize;
Var
 C,C2:Char;
 W:TString;
 NumStr:TString;
 IsReal:Boolean;
 StrVal:TString;
Begin
 While True do Begin
   { sauter blancs et commentaires }
   While True do Begin
     C:=PeekCh;
     If C=#0 Then Begin AddTok(TK_EOF,''); Exit; End;
     If (C=' ')or(C=#9)or(C=#10)or(C=#13) Then Begin NextCh; Continue; End;
     If C='{' Then Begin NextCh; SkipBraceComment; Continue; End;
     If C='/' Then Begin
       If LexPos<Length(LexBuf) Then Begin
         If LexBuf[LexPos+1]='/' Then Begin
           NextCh; NextCh; SkipLineComment; Continue;
         End;
       End;
     End;
     If C='(' Then Begin
       If LexPos<Length(LexBuf) Then Begin
         If LexBuf[LexPos+1]='*' Then Begin
           NextCh; NextCh; SkipParenStarComment; Continue;
         End;
       End;
     End;
     Break;
   End;
   C:=PeekCh;
   If C=#0 Then Begin AddTok(TK_EOF,''); Exit; End;
   { identificateur ou mot-cle }
   If ((C>='A')and(C<='Z'))or((C>='a')and(C<='z'))or(C='_') Then Begin
     W:='';
     While True do Begin
       C:=PeekCh;
       If ((C>='A')and(C<='Z'))or((C>='a')and(C<='z'))or
          ((C>='0')and(C<='9'))or(C='_') Then Begin
         W:=W+C;
         NextCh;
       End Else Break;
     End;
     If IsKeyword(W) Then AddTok(TK_KEYWORD,StrUpper(W))
     Else AddTok(TK_IDENT,W);
     Continue;
   End;
   { nombre }
   If ((C>='0')and(C<='9'))or(C='$') Then Begin
     NumStr:=''; IsReal:=False;
     If C='$' Then Begin
       NumStr:='$'; NextCh;
       While True do Begin
         C:=PeekCh;
         If ((C>='0')and(C<='9'))or((C>='A')and(C<='F'))or
            ((C>='a')and(C<='f')) Then Begin
           NumStr:=NumStr+C; NextCh;
         End Else Break;
       End;
       AddTok(TK_INT,NumStr);
       Continue;
     End;
     While True do Begin
       C:=PeekCh;
       If (C>='0')and(C<='9') Then Begin NumStr:=NumStr+C; NextCh; End
       Else Break;
     End;
     If (PeekCh='.')and(LexPos<Length(LexBuf))and
        (LexBuf[LexPos+1]<>'.') Then Begin
       IsReal:=True;
       NumStr:=NumStr+'.'; NextCh;
       While True do Begin
         C:=PeekCh;
         If (C>='0')and(C<='9') Then Begin NumStr:=NumStr+C; NextCh; End
         Else Break;
       End;
     End;
     If (PeekCh='e')or(PeekCh='E') Then Begin
       IsReal:=True;
       NumStr:=NumStr+'e'; NextCh;
       If (PeekCh='+')or(PeekCh='-') Then Begin
         NumStr:=NumStr+PeekCh; NextCh;
       End;
       While True do Begin
         C:=PeekCh;
         If (C>='0')and(C<='9') Then Begin NumStr:=NumStr+C; NextCh; End
         Else Break;
       End;
     End;
     If IsReal Then AddTok(TK_REAL,NumStr) Else AddTok(TK_INT,NumStr);
     Continue;
   End;
   { chaine '...' }
   If C='''' Then Begin
     StrVal:=''''; NextCh;
     While True do Begin
       C:=PeekCh;
       If C=#0 Then Break;
       If C='''' Then Begin
         StrVal:=StrVal+''''; NextCh;
         If PeekCh='''' Then Begin
           StrVal:=StrVal+''''; NextCh;
         End Else Break;
       End Else Begin
         StrVal:=StrVal+C; NextCh;
       End;
     End;
     AddTok(TK_STRING,StrVal);
     Continue;
   End;
   { caractere #N ou #$NN }
   If C='#' Then Begin
     StrVal:='#'; NextCh;
     If PeekCh='$' Then Begin
       StrVal:=StrVal+'$'; NextCh;
       While True do Begin
         C:=PeekCh;
         If ((C>='0')and(C<='9'))or((C>='A')and(C<='F'))or
            ((C>='a')and(C<='f')) Then Begin
           StrVal:=StrVal+C; NextCh;
         End Else Break;
       End;
     End Else Begin
       While True do Begin
         C:=PeekCh;
         If (C>='0')and(C<='9') Then Begin
           StrVal:=StrVal+C; NextCh;
         End Else Break;
       End;
     End;
     AddTok(TK_CHAR,StrVal);
     Continue;
   End;
   { ponctuation et operateurs }
   C2:=#0;
   If LexPos<Length(LexBuf) Then C2:=LexBuf[LexPos+1];
   If (C=':')and(C2='=') Then Begin NextCh; NextCh; AddTok(TK_OP,':='); Continue; End;
   If (C='<')and(C2='=') Then Begin NextCh; NextCh; AddTok(TK_OP,'<='); Continue; End;
   If (C='>')and(C2='=') Then Begin NextCh; NextCh; AddTok(TK_OP,'>='); Continue; End;
   If (C='<')and(C2='>') Then Begin NextCh; NextCh; AddTok(TK_OP,'<>'); Continue; End;
   If (C='.')and(C2='.') Then Begin NextCh; NextCh; AddTok(TK_PUNCT,'..'); Continue; End;
   If (C='+')or(C='-')or(C='*')or(C='/')or(C='=')or(C='<')or(C='>') Then Begin
     AddTok(TK_OP,C); NextCh; Continue;
   End;
   If (C=';')or(C=',')or(C=':')or(C='.')or(C='(')or(C=')')or
      (C='[')or(C=']')or(C='^')or(C='@') Then Begin
     AddTok(TK_PUNCT,C); NextCh; Continue;
   End;
   { caractere inconnu : ignorer }
   NextCh;
 End;
End;

{ ============================================================
  PRE-ANALYSE : trouver les fonctions et leurs masques de parametres
  ============================================================ }
Procedure Analyze;
Var
 I,J,Depth:Integer;
 Name,Mask,RetT:TString;
 IsF:Boolean;
 Saw:Boolean;
Begin
 I:=1;
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If (Tokens[I].Val='PROGRAM')or(Tokens[I].Val='UNIT') Then Begin
       IsUnit:=Tokens[I].Val='UNIT';
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
         ProgName:=Tokens[I].Val; Inc(I);
       End;
       Continue;
     End;
     If (Tokens[I].Val='PROCEDURE')or(Tokens[I].Val='FUNCTION') Then Begin
       IsF:=Tokens[I].Val='FUNCTION';
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
         Name:=Tokens[I].Val; Inc(I);
       End Else Name:='';
       Mask:=''; RetT:='';
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
         Inc(I); Depth:=1;
         While (I<=TokCount)and(Depth>0) do Begin
           Saw:=False;
           If (Tokens[I].Kind=TK_KEYWORD)and
              ((Tokens[I].Val='VAR')or(Tokens[I].Val='OUT')) Then Begin
             Saw:=True; Inc(I);
           End Else
           If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Inc(I);
           { collecter les noms separes par , puis ':' type }
           J:=0;
           While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':')) and
                 Not((Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=';')or(Tokens[I].Val=')'))) do Begin
             If (Tokens[I].Kind=TK_IDENT) Then Inc(J);
             Inc(I);
           End;
           While J>0 do Begin
             If Saw Then Mask:=Mask+'V' Else Mask:=Mask+'N';
             Dec(J);
           End;
           { sauter le type jusqu'a ; ou ) }
           While (I<=TokCount) do Begin
             If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth)
             Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
               Dec(Depth); If Depth=0 Then Begin Inc(I); Break; End;
             End
             Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')and(Depth=1) Then Begin
               Inc(I); Break;
             End;
             Inc(I);
           End;
         End;
       End;
       If IsF and (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
         Inc(I);
         If I<=TokCount Then Begin RetT:=Tokens[I].Val; Inc(I); End;
       End;
       If FuncCount<MAX_FNS Then Begin
         Inc(FuncCount);
         Funcs[FuncCount].Name:=Name;
         Funcs[FuncCount].RetType:=StrLower(RetT);
         Funcs[FuncCount].IsFunc:=IsF;
         Funcs[FuncCount].RefMask:=Mask;
       End;
       Continue;
     End;
   End;
   Inc(I);
 End;
End;

{ ============================================================
  EMISSION
  ============================================================ }
Procedure WriteIndent;
Var I:Integer;
Begin
 For I:=1 to Indent*2 do OutLine:=OutLine+' ';
End;

Procedure FlushLine;
Begin
 If OutLine<>'' Then Begin
   WriteLn(OutFile,OutLine);
   OutLine:='';
 End;
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine Lisp "abc'def".
  Les guillemets et backslash sont echappes. }
Function PasStringToLisp(S:TString):TString;
Var
 I:Integer;
 R:TString;
Begin
 R:='';
 I:=2;
 While I<Length(S) do Begin
   If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin
     R:=R+''''; Inc(I,2);
   End
   Else If S[I]='"' Then Begin R:=R+'\"'; Inc(I); End
   Else If S[I]='\' Then Begin R:=R+'\\'; Inc(I); End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 PasStringToLisp:='"'+R+'"';
End;

{ Un litteral caractere Pascal #N -> notation Lisp #\NomDuCaractere
  pour les valeurs imprimables, sinon (code-char N). }
Function PasCharToLisp(S:TString):TString;
Var
 V:LongInt;
 Code:Integer;
 Body,Num:TString;
Begin
 Body:=Copy(S,2,Length(S)-1);
 If (Length(Body)>0)and(Body[1]='$') Then
   Val('$'+Copy(Body,2,Length(Body)-1),V,Code)
 Else Val(Body,V,Code);
 If Code<>0 Then V:=0;
 Str(V,Num);
 Case V of
   10: PasCharToLisp:='#\Newline';
   13: PasCharToLisp:='#\Return';
   9 : PasCharToLisp:='#\Tab';
   32: PasCharToLisp:='#\Space';
   Else
     If (V>=33)and(V<=126) Then
       PasCharToLisp:='#\'+Chr(V)
     Else
       PasCharToLisp:='(code-char '+Num+')';
 End;
End;

{ Convertit un nombre Pascal eventuellement hexadecimal en notation Lisp. }
Function PasNumToLisp(S:TString):TString;
Begin
 If (Length(S)>0)and(S[1]='$') Then
   PasNumToLisp:='#x'+Copy(S,2,Length(S)-1)
 Else
   PasNumToLisp:=S;
End;

{ Renvoie le nom Lisp pour un identificateur Pascal.
  Common Lisp est insensible a la casse, on emet en minuscules
  et on remplace les caracteres problematiques. }
Function LispName(Const N:TString):TString;
Var R:TString; I:Integer;
Begin
 R:=StrLower(N);
 { ne pas reserver les noms problematiques 't' et 'nil' :
   on les renomme pour eviter le conflit avec les valeurs Lisp. }
 If (R='t')or(R='nil') Then R:=R+'_';
 LispName:=R;
 If False Then If I=0 Then ;
End;

{ ============================================================
  PARSEUR D'EXPRESSIONS PASCAL -> S-EXPRESSION LISP
  ============================================================
  Chaque fonction Parse* lit a partir de Tokens[I], avance I,
  et retourne une chaine TString contenant la S-expression Lisp.
  Niveaux de precedence (du plus bas vers le plus haut) :
    Or  : OR XOR
    And : AND
    Rel : =  <>  <  <=  >  >=  IN
    Add : + -
    Mul : * / DIV MOD SHL SHR
    Unaire : NOT, +, -
    Primaire : litteral, ident, ident(args), ident[idx], (expr), @x, x^
}

Function ParseExpr(Var I:Integer):TString; Forward;
Function ParseOrExpr(Var I:Integer):TString; Forward;
Function ParseAndExpr(Var I:Integer):TString; Forward;
Function ParseRelExpr(Var I:Integer):TString; Forward;
Function ParseAddExpr(Var I:Integer):TString; Forward;
Function ParseMulExpr(Var I:Integer):TString; Forward;
Function ParseUnaryExpr(Var I:Integer):TString; Forward;
Function ParsePrimary(Var I:Integer):TString; Forward;

{ Determine si l'on doit s'arreter dans une expression (separateur
  Pascal). }
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

{ Litteral Pascal -> chaine Lisp. }
Function LitToLisp(I:Integer):TString;
Var V:TString;
Begin
 V:=Tokens[I].Val;
 Case Tokens[I].Kind of
   TK_INT    : LitToLisp:=PasNumToLisp(V);
   TK_REAL   : LitToLisp:=V;
   TK_STRING : Begin
     { une chaine d'un seul caractere reste une chaine ; le contexte
       decidera si on a besoin de char ou string. }
     If Length(V)=3 Then Begin
       { 'X' -> #\X }
       If V[2]<>'''' Then LitToLisp:='#\'+V[2]
       Else LitToLisp:=PasStringToLisp(V);
     End Else
       LitToLisp:=PasStringToLisp(V);
   End;
   TK_CHAR   : LitToLisp:=PasCharToLisp(V);
   TK_KEYWORD: Begin
     If V='TRUE' Then LitToLisp:='t'
     Else If V='FALSE' Then LitToLisp:='nil'
     Else If V='NIL' Then LitToLisp:='nil'
     Else LitToLisp:=StrLower(V);
   End;
   Else
     LitToLisp:=V;
 End;
End;

{ Lit un argument d'appel jusqu'au prochain ',' ou ')' au niveau 0. }
Function ParseCallArg(Var I:Integer):TString;
Begin
 ParseCallArg:=ParseExpr(I);
End;

{ Mappe certains builtins Pascal vers des fonctions Lisp.
  Renvoie '' si pas de mappage special. }
Function MapBuiltin(Const Name:TString; Const Args:TString;
                    NumArgs:Integer):TString;
Var U:TString;
Begin
 U:=StrUpper(Name);
 MapBuiltin:='';
 If (U='LENGTH')and(NumArgs=1) Then MapBuiltin:='(length '+Args+')'
 Else If (U='ORD')and(NumArgs=1) Then MapBuiltin:='(char-code '+Args+')'
 Else If (U='CHR')and(NumArgs=1) Then MapBuiltin:='(code-char '+Args+')'
 Else If (U='ABS')and(NumArgs=1) Then MapBuiltin:='(abs '+Args+')'
 Else If (U='SQR')and(NumArgs=1) Then MapBuiltin:='(* '+Args+' '+Args+')'
 Else If (U='SQRT')and(NumArgs=1) Then MapBuiltin:='(sqrt '+Args+')'
 Else If (U='SIN')and(NumArgs=1) Then MapBuiltin:='(sin '+Args+')'
 Else If (U='COS')and(NumArgs=1) Then MapBuiltin:='(cos '+Args+')'
 Else If (U='LN')and(NumArgs=1) Then MapBuiltin:='(log '+Args+')'
 Else If (U='EXP')and(NumArgs=1) Then MapBuiltin:='(exp '+Args+')'
 Else If (U='TRUNC')and(NumArgs=1) Then MapBuiltin:='(truncate '+Args+')'
 Else If (U='ROUND')and(NumArgs=1) Then MapBuiltin:='(round '+Args+')'
 Else If (U='ODD')and(NumArgs=1) Then MapBuiltin:='(oddp '+Args+')'
 Else If (U='UPCASE')and(NumArgs=1) Then MapBuiltin:='(char-upcase '+Args+')'
 Else If (U='SUCC')and(NumArgs=1) Then MapBuiltin:='(1+ '+Args+')'
 Else If (U='PRED')and(NumArgs=1) Then MapBuiltin:='(1- '+Args+')';
End;

{ Primaire : litteral, '(' expr ')', ident eventuellement suivi
  d'un appel (...) ou d'un index []. }
Function ParsePrimary(Var I:Integer):TString;
Var
 R,Name,Arg,Args:TString;
 NArgs:Integer;
 Mapped:TString;
 IsCall:Boolean;
Begin
 R:='';
 If I>TokCount Then Begin ParsePrimary:='nil'; Exit; End;
 { unaire ? deja gere par ParseUnary, donc ici on n'attend pas '+/-' isole }
 { '(' expr ')' }
 If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   R:=ParseExpr(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
   ParsePrimary:=R; Exit;
 End;
 { '@' x : adresse - en Lisp on ignore et on retourne x }
 If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='@') Then Begin
   Inc(I);
   ParsePrimary:=ParsePrimary(I); Exit;
 End;
 { litteral simple }
 If (Tokens[I].Kind=TK_INT)or(Tokens[I].Kind=TK_REAL)or
    (Tokens[I].Kind=TK_STRING)or(Tokens[I].Kind=TK_CHAR) Then Begin
   R:=LitToLisp(I); Inc(I);
   ParsePrimary:=R; Exit;
 End;
 { mots-cles litteraux }
 If (Tokens[I].Kind=TK_KEYWORD) Then Begin
   If (Tokens[I].Val='TRUE')or(Tokens[I].Val='FALSE')or(Tokens[I].Val='NIL') Then Begin
     R:=LitToLisp(I); Inc(I);
     ParsePrimary:=R; Exit;
   End;
 End;
 { identificateur }
 If Tokens[I].Kind=TK_IDENT Then Begin
   Name:=Tokens[I].Val; Inc(I);
   { suite eventuelle : (...) [...] ^ . }
   IsCall:=(I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(');
   If IsCall Then Begin
     Inc(I);
     Args:=''; NArgs:=0;
     If Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) Then Begin
       Arg:=ParseCallArg(I);
       Args:=Arg; Inc(NArgs);
       While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
         Inc(I);
         Arg:=ParseCallArg(I);
         Args:=Args+' '+Arg; Inc(NArgs);
       End;
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
     Mapped:=MapBuiltin(Name,Args,NArgs);
     If Mapped<>'' Then R:=Mapped
     Else If Args='' Then R:='('+LispName(Name)+')'
     Else R:='('+LispName(Name)+' '+Args+')';
   End Else
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
     { acces tableau : x[i] -> (aref x i) ; x[i,j] -> (aref x i j) }
     Inc(I);
     Args:=ParseExpr(I);
     While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
       Inc(I);
       Args:=Args+' '+ParseExpr(I);
     End;
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
     R:='(aref '+LispName(Name)+' '+Args+')';
   End Else Begin
     R:=LispName(Name);
   End;
   { dereferencement ^ : ignore en Lisp }
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') do Inc(I);
   { acces a un champ x.y -> (slot-value x 'y) ; pour simplifier on
     emet 'x.y' comme reference globale (rare dans nos tests). On
     transforme en (slot-value ...) pour conserver la semantique. }
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') do Begin
     { distinguer le '.' final du programme : si suivi de EOF ou END,
       arreter sans consommer. }
     If (I+1>TokCount) Then Break;
     If Tokens[I+1].Kind<>TK_IDENT Then Break;
     Inc(I);
     R:='(slot-value '+R+' '+''''+LispName(Tokens[I].Val)+')';
     Inc(I);
   End;
   ParsePrimary:=R; Exit;
 End;
 { defaut : avancer pour eviter une boucle }
 Inc(I);
 ParsePrimary:='nil';
End;

Function ParseUnaryExpr(Var I:Integer):TString;
Var R:TString;
Begin
 If I>TokCount Then Begin ParseUnaryExpr:='nil'; Exit; End;
 If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='NOT') Then Begin
   Inc(I);
   R:=ParseUnaryExpr(I);
   ParseUnaryExpr:='(not '+R+')'; Exit;
 End;
 If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='-') Then Begin
   Inc(I);
   R:=ParseUnaryExpr(I);
   ParseUnaryExpr:='(- '+R+')'; Exit;
 End;
 If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='+') Then Begin
   Inc(I);
   ParseUnaryExpr:=ParseUnaryExpr(I); Exit;
 End;
 ParseUnaryExpr:=ParsePrimary(I);
End;

Function ParseMulExpr(Var I:Integer):TString;
Var L,R:TString; Op:TString; Done:Boolean;
Begin
 L:=ParseUnaryExpr(I);
 Done:=False;
 While (I<=TokCount) and Not Done do Begin
   Op:='';
   If (Tokens[I].Kind=TK_OP) Then Begin
     If (Tokens[I].Val='*')or(Tokens[I].Val='/') Then Op:=Tokens[I].Val;
   End Else
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If (Tokens[I].Val='DIV') Then Op:='DIV'
     Else If (Tokens[I].Val='MOD') Then Op:='MOD'
     Else If (Tokens[I].Val='SHL') Then Op:='SHL'
     Else If (Tokens[I].Val='SHR') Then Op:='SHR';
   End;
   If Op='' Then Begin Done:=True; Continue; End;
   Inc(I);
   R:=ParseUnaryExpr(I);
   If Op='*' Then L:='(* '+L+' '+R+')'
   Else If Op='/' Then L:='(/ '+L+' '+R+')'
   Else If Op='DIV' Then L:='(floor '+L+' '+R+')'
   Else If Op='MOD' Then L:='(mod '+L+' '+R+')'
   Else If Op='SHL' Then L:='(ash '+L+' '+R+')'
   Else If Op='SHR' Then L:='(ash '+L+' (- '+R+'))';
 End;
 ParseMulExpr:=L;
End;

Function ParseAddExpr(Var I:Integer):TString;
Var L,R:TString; Op:TString; Done:Boolean;
Begin
 L:=ParseMulExpr(I);
 Done:=False;
 While (I<=TokCount) and Not Done do Begin
   Op:='';
   If (Tokens[I].Kind=TK_OP) Then Begin
     If (Tokens[I].Val='+')or(Tokens[I].Val='-') Then Op:=Tokens[I].Val;
   End;
   If Op='' Then Begin Done:=True; Continue; End;
   Inc(I);
   R:=ParseMulExpr(I);
   L:='('+Op+' '+L+' '+R+')';
 End;
 ParseAddExpr:=L;
End;

Function ParseRelExpr(Var I:Integer):TString;
Var L,R:TString; Op:TString;
Begin
 L:=ParseAddExpr(I);
 If I<=TokCount Then Begin
   Op:='';
   If Tokens[I].Kind=TK_OP Then Begin
     If (Tokens[I].Val='=')or(Tokens[I].Val='<>')or(Tokens[I].Val='<')or
        (Tokens[I].Val='<=')or(Tokens[I].Val='>')or(Tokens[I].Val='>=') Then
       Op:=Tokens[I].Val;
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IN') Then Op:='IN';
   If Op<>'' Then Begin
     Inc(I);
     R:=ParseAddExpr(I);
     If Op='=' Then L:='(equal '+L+' '+R+')'
     Else If Op='<>' Then L:='(not (equal '+L+' '+R+'))'
     Else If Op='<' Then L:='(< '+L+' '+R+')'
     Else If Op='<=' Then L:='(<= '+L+' '+R+')'
     Else If Op='>' Then L:='(> '+L+' '+R+')'
     Else If Op='>=' Then L:='(>= '+L+' '+R+')'
     Else If Op='IN' Then L:='(member '+L+' '+R+')';
   End;
 End;
 ParseRelExpr:=L;
End;

Function ParseAndExpr(Var I:Integer):TString;
Var L,R:TString;
Begin
 L:=ParseRelExpr(I);
 While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AND') do Begin
   Inc(I);
   R:=ParseRelExpr(I);
   L:='(and '+L+' '+R+')';
 End;
 ParseAndExpr:=L;
End;

Function ParseOrExpr(Var I:Integer):TString;
Var L,R,Op:TString;
Begin
 L:=ParseAndExpr(I);
 While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='OR')or(Tokens[I].Val='XOR')) do Begin
   Op:=Tokens[I].Val;
   Inc(I);
   R:=ParseAndExpr(I);
   If Op='OR' Then L:='(or '+L+' '+R+')'
   Else L:='(logxor '+L+' '+R+')';
 End;
 ParseOrExpr:=L;
End;

Function ParseExpr(Var I:Integer):TString;
Begin
 If (I>TokCount) or IsExprStop(I) Then Begin
   ParseExpr:='nil'; Exit;
 End;
 ParseExpr:=ParseOrExpr(I);
End;

{ ============================================================
  EMISSION DES INSTRUCTIONS
  ============================================================ }
Procedure EmitStatement(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer); Forward;

{ Lit la cible d'un :=  : un identificateur eventuellement suivi
  de [..] / ^ / .x. Renvoie deux choses : la representation Lisp
  de l'acces (LhsLisp), et la forme 'setter' a appliquer. Pour
  simplifier, on retourne la sous-S-expression identique a un
  primaire et on utilisera (setf <expr> <valeur>). }
Function ParseLhs(Var I:Integer):TString;
Begin
 ParseLhs:=ParsePrimary(I);
End;

{ WriteLn / Write : emet (princ a) (princ b) ... eventuellement (terpri). }
Procedure EmitWrite(Var I:Integer; AddNewLine:Boolean);
Var
 Args:Array[1..64] of TString;
 NArgs,K:Integer;
Begin
 Inc(I);                     { sauter Write/WriteLn }
 NArgs:=0;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) Then Begin
     Inc(NArgs); Args[NArgs]:=ParseExpr(I);
     { ignorer la specification de largeur :n:m }
     While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') do Begin
       Inc(I); If I<=TokCount Then ParseExpr(I);
     End;
     While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
       Inc(I);
       Inc(NArgs); If NArgs>64 Then NArgs:=64;
       Args[NArgs]:=ParseExpr(I);
       While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') do Begin
         Inc(I); If I<=TokCount Then ParseExpr(I);
       End;
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 WriteIndent;
 If (NArgs=0) and AddNewLine Then EmitRaw('(terpri)')
 Else If NArgs=0 Then EmitRaw('(values)')
 Else Begin
   EmitRaw('(progn');
   For K:=1 to NArgs do Begin EmitRaw(' (princ '); EmitRaw(Args[K]); EmitRaw(')'); End;
   If AddNewLine Then EmitRaw(' (terpri)');
   EmitRaw(')');
 End;
 EmitLn;
End;

{ Read / ReadLn : (setf x (read)) ou (setf x (read-line)).
  ReadLn sans argument -> (read-line). }
Procedure EmitRead(Var I:Integer; ALine:Boolean);
Var
 Targets:Array[1..16] of TString;
 NT,K:Integer;
 Reader:TString;
Begin
 Inc(I);                     { sauter Read/ReadLn }
 NT:=0;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   Inc(I);
   If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) Then Begin
     Inc(NT); Targets[NT]:=ParseLhs(I);
     While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
       Inc(I); Inc(NT); If NT>16 Then NT:=16;
       Targets[NT]:=ParseLhs(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 End;
 If ALine Then Reader:='(read-line)' Else Reader:='(read)';
 If NT=0 Then Begin
   WriteIndent; EmitRaw(Reader); EmitLn;
 End Else Begin
   WriteIndent; EmitRaw('(progn');
   For K:=1 to NT do Begin
     EmitRaw(' (setf '); EmitRaw(Targets[K]); EmitRaw(' '); EmitRaw(Reader); EmitRaw(')');
   End;
   EmitRaw(')'); EmitLn;
 End;
End;

{ IF cond THEN stmt [ELSE stmt]
  Si on a un seul stmt dans chaque branche -> (if cond then else).
  Sinon, on emet sous forme indentee multi-lignes. }
Procedure EmitIf(Var I:Integer);
Var Cond:TString;
Begin
 Inc(I);                     { sauter IF }
 Cond:=ParseExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
 WriteIndent; EmitRaw('(if '); EmitRaw(Cond); EmitLn;
 Inc(Indent);
 EmitStatement(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
   Inc(I);
   EmitStatement(I);
 End Else Begin
   WriteIndent; EmitRaw('nil'); EmitLn;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw(')'); EmitLn;
End;

{ WHILE cond DO stmt
  -> (loop while cond do stmt) }
Procedure EmitWhile(Var I:Integer);
Var Cond:TString;
Begin
 Inc(I);
 Cond:=ParseExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 WriteIndent; EmitRaw('(loop while '); EmitRaw(Cond); EmitRaw(' do'); EmitLn;
 Inc(Indent);
 EmitStatement(I);
 Dec(Indent);
 WriteIndent; EmitRaw(')'); EmitLn;
End;

{ REPEAT stmts UNTIL cond
  -> (loop do (progn stmts) until cond) }
Procedure EmitRepeat(Var I:Integer);
Var Cond:TString;
Begin
 Inc(I);
 WriteIndent; EmitRaw('(loop do (progn'); EmitLn;
 Inc(Indent);
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL')) do Begin
   EmitStatement(I);
   { permettre les ; multiples }
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') do Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Break;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw(') until '); 
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
 Cond:=ParseExpr(I);
 EmitRaw(Cond); EmitRaw(')'); EmitLn;
End;

{ FOR x := a TO/DOWNTO b DO stmt
  -> (loop for x from a to b do stmt) ou ... downfrom a to b ... }
Procedure EmitFor(Var I:Integer);
Var
 VarN,A,B:TString;
 IsDown:Boolean;
Begin
 Inc(I);                     { sauter FOR }
 VarN:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
   VarN:=LispName(Tokens[I].Val); RegisterVar(Tokens[I].Val); Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
 A:=ParseExpr(I);
 IsDown:=False;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD) Then Begin
   If Tokens[I].Val='DOWNTO' Then IsDown:=True;
   Inc(I);
 End;
 B:=ParseExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
 WriteIndent;
 If IsDown Then Begin
   EmitRaw('(loop for '); EmitRaw(VarN); EmitRaw(' from '); EmitRaw(A);
   EmitRaw(' downto '); EmitRaw(B); EmitRaw(' do'); EmitLn;
 End Else Begin
   EmitRaw('(loop for '); EmitRaw(VarN); EmitRaw(' from '); EmitRaw(A);
   EmitRaw(' to '); EmitRaw(B); EmitRaw(' do'); EmitLn;
 End;
 Inc(Indent);
 EmitStatement(I);
 Dec(Indent);
 WriteIndent; EmitRaw(')'); EmitLn;
End;

{ CASE expr OF lab1[,lab2]: stmt; ... [OTHERWISE/ELSE stmt;] END
  -> (case expr ((lab1 lab2) stmt) ... (otherwise stmt))
  Note : nous emettons (cond ...) pour tolerer les plages a..b
  qui ne sont pas directement supportees par CASE. }
Procedure EmitCase(Var I:Integer);
Var Expr,Labs,LabExpr,A,B:TString;
Begin
 Inc(I);                     { sauter CASE }
 Expr:=ParseExpr(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
 WriteIndent; EmitRaw('(let ((__case '); EmitRaw(Expr); EmitRaw('))'); EmitLn;
 Inc(Indent);
 WriteIndent; EmitRaw('(cond'); EmitLn;
 Inc(Indent);
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='END')or(Tokens[I].Val='OTHERWISE')or
        ((Tokens[I].Val='ELSE')and(Indent>0)))) do Begin
   { lire les labels separes par , }
   Labs:='';
   While True do Begin
     A:=ParseExpr(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Begin
       Inc(I);
       B:=ParseExpr(I);
       LabExpr:='(and (>= __case '+A+') (<= __case '+B+'))';
     End Else
       LabExpr:='(equal __case '+A+')';
     If Labs='' Then Labs:=LabExpr Else Labs:='(or '+Labs+' '+LabExpr+')';
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
     Else Break;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   WriteIndent; EmitRaw('('); EmitRaw(Labs); EmitLn;
   Inc(Indent);
   EmitStatement(I);
   Dec(Indent);
   WriteIndent; EmitRaw(')'); EmitLn;
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') do Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD) and
    ((Tokens[I].Val='OTHERWISE')or(Tokens[I].Val='ELSE')) Then Begin
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   WriteIndent; EmitRaw('(t'); EmitLn;
   Inc(Indent);
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')) do Begin
     EmitStatement(I);
     While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') do Inc(I);
   End;
   Dec(Indent);
   WriteIndent; EmitRaw(')'); EmitLn;
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 Dec(Indent);
 WriteIndent; EmitRaw('))'); EmitLn;
 Dec(Indent);
End;

{ BEGIN ... END -> (progn ...) }
Procedure EmitBeginEnd(Var I:Integer);
Begin
 Inc(I);                     { sauter BEGIN }
 WriteIndent; EmitRaw('(progn'); EmitLn;
 Inc(Indent);
 EmitStatementList(I);
 Dec(Indent);
 WriteIndent; EmitRaw(')'); EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
End;

{ Determine si Name est le nom de la fonction courante (pour le retour). }
Function IsCurrentFunction(Const Name:TString):Boolean;
Begin
 IsCurrentFunction:=False;
 If CurFunc>0 Then
   If StrEqualCI(Name,Funcs[CurFunc].Name) Then IsCurrentFunction:=True;
 If StrEqualCI(Name,'Result') Then IsCurrentFunction:=True;
End;

{ Affectation : x := expr ;
  cas particuliers : x est le nom de la fonction courante -> _result_ }
Procedure EmitAssign(Var I:Integer);
Var
 Lhs,Rhs:TString;
 NameTok:Integer;
Begin
 NameTok:=I;
 Lhs:=ParseLhs(I);
 If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Begin
   Inc(I);
   Rhs:=ParseExpr(I);
   { si LHS est juste un identificateur correspondant a la fonction courante,
     remplacer par _result_ }
   If (Tokens[NameTok].Kind=TK_IDENT) and IsCurrentFunction(Tokens[NameTok].Val)
      and (Lhs=LispName(Tokens[NameTok].Val)) Then Begin
     WriteIndent; EmitRaw('(setf _result_ '); EmitRaw(Rhs); EmitRaw(')'); EmitLn;
   End Else Begin
     WriteIndent; EmitRaw('(setf '); EmitRaw(Lhs); EmitRaw(' '); EmitRaw(Rhs);
     EmitRaw(')'); EmitLn;
   End;
 End Else Begin
   { instruction expression seule (appel de procedure) }
   WriteIndent; EmitRaw(Lhs); EmitLn;
 End;
End;

{ Emet une instruction (sans le ; final). }
Procedure EmitStatement(Var I:Integer);
Var K:TString;
Begin
 If I>TokCount Then Exit;
 { sauter les ; vides }
 While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') do Inc(I);
 If I>TokCount Then Exit;
 If Tokens[I].Kind=TK_KEYWORD Then Begin
   K:=Tokens[I].Val;
   If K='BEGIN' Then Begin EmitBeginEnd(I); Exit; End;
   If K='IF' Then Begin EmitIf(I); Exit; End;
   If K='WHILE' Then Begin EmitWhile(I); Exit; End;
   If K='REPEAT' Then Begin EmitRepeat(I); Exit; End;
   If K='FOR' Then Begin EmitFor(I); Exit; End;
   If K='CASE' Then Begin EmitCase(I); Exit; End;
   If K='EXIT' Then Begin
     Inc(I);
     { Exit() optionnel }
     If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
       Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
     End;
     WriteIndent;
     If CurFunc>0 Then Begin
       If Funcs[CurFunc].IsFunc Then Begin
         EmitRaw('(return-from '); EmitRaw(LispName(Funcs[CurFunc].Name));
         EmitRaw(' _result_)'); EmitLn;
       End Else Begin
         EmitRaw('(return-from '); EmitRaw(LispName(Funcs[CurFunc].Name));
         EmitRaw(')'); EmitLn;
       End;
     End Else Begin
       EmitRaw('(return-from main)'); EmitLn;
     End;
     Exit;
   End;
   If K='BREAK' Then Begin
     Inc(I);
     WriteIndent; EmitRaw('(loop-finish)'); EmitLn;
     Exit;
   End;
   If K='CONTINUE' Then Begin
     Inc(I);
     WriteIndent; EmitRaw('; continue (non supporte directement en Lisp)'); EmitLn;
     Exit;
   End;
   If K='GOTO' Then Begin
     Inc(I);
     If I<=TokCount Then Inc(I);
     WriteIndent; EmitRaw('; goto non supporte'); EmitLn;
     Exit;
   End;
   If K='WITH' Then Begin
     { sauter jusqu'a DO }
     Inc(I);
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do Inc(I);
     If I<=TokCount Then Inc(I);
     WriteIndent; EmitRaw('; WITH non supporte directement'); EmitLn;
     EmitStatement(I);
     Exit;
   End;
   If K='END' Then Exit;
 End;
 { Write / WriteLn / Read / ReadLn ? }
 If Tokens[I].Kind=TK_IDENT Then Begin
   K:=StrUpper(Tokens[I].Val);
   If K='WRITELN' Then Begin EmitWrite(I,True); Exit; End;
   If K='WRITE' Then Begin EmitWrite(I,False); Exit; End;
   If K='READLN' Then Begin EmitRead(I,True); Exit; End;
   If K='READ' Then Begin EmitRead(I,False); Exit; End;
 End;
 { autre : affectation ou appel }
 EmitAssign(I);
End;

Procedure EmitStatementList(Var I:Integer);
Begin
 While I<=TokCount do Begin
   { fin du bloc ? }
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If (Tokens[I].Val='END')or(Tokens[I].Val='UNTIL')or
        (Tokens[I].Val='ELSE') Then Exit;
   End;
   EmitStatement(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') do Inc(I);
 End;
End;

{ ============================================================
  DECLARATIONS DE VARIABLES / CONSTANTES / TYPES
  ============================================================ }
{ Renvoie une valeur initiale Lisp d'apres un nom de type Pascal. }
Function DefaultForType(Const TypeS:TString; IsArr:Boolean):TString;
Var U:TString;
Begin
 U:=StrUpper(TypeS);
 If IsArr Then Begin DefaultForType:='nil'; Exit; End;
 If (U='STRING')or(U='ANSISTRING')or(U='SHORTSTRING')or(U='PCHAR') Then
   DefaultForType:='""'
 Else If (U='BOOLEAN') Then DefaultForType:='nil'
 Else If (U='REAL')or(U='SINGLE')or(U='DOUBLE')or(U='EXTENDED')or
         (U='COMP')or(U='CURRENCY') Then DefaultForType:='0.0'
 Else If (U='CHAR')or(U='ANSICHAR')or(U='WIDECHAR') Then DefaultForType:='#\Space'
 Else If (U='POINTER') Then DefaultForType:='nil'
 Else DefaultForType:='0';
End;

{ Lit un type Pascal et le consume jusqu'au prochain ';' (ou fin de
  declaration). Renvoie le nom de type et indique s'il s'agit d'un
  tableau. Pas tres precis, mais suffisant pour deduire la valeur
  initiale. }
Procedure ConsumeType(Var I:Integer; Var TypeS:TString; Var IsArr:Boolean);
Var Depth:Integer;
Begin
 TypeS:=''; IsArr:=False;
 If I>TokCount Then Exit;
 If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY') Then Begin
   IsArr:=True; Inc(I);
   { sauter [..] }
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
     Depth:=1; Inc(I);
     While (I<=TokCount)and(Depth>0) do Begin
       If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Inc(Depth)
       Else If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Dec(Depth);
       Inc(I);
     End;
   End;
   { OF type }
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
   If I<=TokCount Then Begin TypeS:=Tokens[I].Val; Inc(I); End;
 End Else
 If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
   TypeS:='STRING'; Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
     If I<=TokCount Then Inc(I);
   End;
 End Else
 If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Begin
   TypeS:='RECORD'; Inc(I);
   { sauter jusqu'a END }
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')) do Inc(I);
   If I<=TokCount Then Inc(I);
 End Else
 If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='^') Then Begin
   Inc(I);
   If I<=TokCount Then Begin TypeS:='POINTER'; Inc(I); End;
 End Else
 If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
   { type enumere : on consomme jusqu'au ')' }
   TypeS:='INTEGER';
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
   If I<=TokCount Then Inc(I);
 End Else Begin
   TypeS:=Tokens[I].Val; Inc(I);
 End;
 { sauter d'eventuels suffixes (ex: range a..b) }
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=';')or(Tokens[I].Val=')'))) do
   Inc(I);
End;

{ VAR section.
  AsGlobal=True : produit (defparameter NAME init).
  AsGlobal=False : remplit la liste LocalDecls passee en parametre,
  pour qu'elle soit utilisee dans un (let* ...). }
Procedure EmitVarSectionGlobal(Var I:Integer);
Var
 Names:Array[1..32] of TString;
 NN,J:Integer;
 TypeS,Init:TString;
 IsArr:Boolean;
Begin
 Inc(I);                     { sauter VAR }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     If (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
        (Tokens[I].Val='BEGIN')or(Tokens[I].Val='PROCEDURE')or
        (Tokens[I].Val='FUNCTION')or(Tokens[I].Val='IMPLEMENTATION')or
        (Tokens[I].Val='LABEL')or(Tokens[I].Val='USES')or(Tokens[I].Val='END')or
        (Tokens[I].Val='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   NN:=0;
   Inc(NN); Names[NN]:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       If NN<32 Then Begin Inc(NN); Names[NN]:=Tokens[I].Val; End;
       Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   ConsumeType(I,TypeS,IsArr);
   Init:=DefaultForType(TypeS,IsArr);
   { affectation initiale = ?  ex : x: integer = 5 ; non gere ici, laisse defaut }
   For J:=1 to NN do Begin
     RegisterVar(Names[J]);
     EmitRaw('(defparameter '); EmitRaw(LispName(Names[J])); EmitRaw(' ');
     EmitRaw(Init); EmitRaw(')'); EmitRaw(' ; '); EmitRaw(StrLower(TypeS));
     If IsArr Then EmitRaw(' (array)');
     EmitLn;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ Variante : produit la liste de bindings pour un let* local.
  Renvoie la chaine '((x 0) (y "")...)' (ou '' si aucune var). }
Function CollectLocalVarBindings(Var I:Integer):TString;
Var
 Names:Array[1..32] of TString;
 NN,J:Integer;
 TypeS,Init,R:TString;
 IsArr:Boolean;
Begin
 R:='';
 Inc(I);                     { sauter VAR }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     If (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
        (Tokens[I].Val='BEGIN')or(Tokens[I].Val='PROCEDURE')or
        (Tokens[I].Val='FUNCTION')or(Tokens[I].Val='IMPLEMENTATION')or
        (Tokens[I].Val='LABEL')or(Tokens[I].Val='USES')or(Tokens[I].Val='END')or
        (Tokens[I].Val='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   NN:=0;
   Inc(NN); Names[NN]:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       If NN<32 Then Begin Inc(NN); Names[NN]:=Tokens[I].Val; End;
       Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   ConsumeType(I,TypeS,IsArr);
   Init:=DefaultForType(TypeS,IsArr);
   For J:=1 to NN do Begin
     RegisterVar(Names[J]);
     R:=R+'('+LispName(Names[J])+' '+Init+') ';
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 CollectLocalVarBindings:=R;
End;

{ CONST section globale -> defconstant ou defparameter.
  Emet en (defparameter +NAME+ valeur) pour permettre la modification
  de la constante depuis le code (Lisp est strict avec defconstant). }
Procedure EmitConstSectionGlobal(Var I:Integer);
Var
 Name:TString; J:Integer; Save:Integer; Expr:TString;
Begin
 Inc(I);                     { sauter CONST }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     If (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
        (Tokens[I].Val='BEGIN')or(Tokens[I].Val='PROCEDURE')or
        (Tokens[I].Val='FUNCTION')or(Tokens[I].Val='IMPLEMENTATION')or
        (Tokens[I].Val='LABEL')or(Tokens[I].Val='USES')or(Tokens[I].Val='END')or
        (Tokens[I].Val='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   { type explicite optionnel : ': type =' }
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
     Inc(I);
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) do Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   Save:=I;
   Expr:=ParseExpr(I);
   If I=Save Then Expr:='0';
   RegisterConst(Name);
   EmitRaw('(defparameter '); EmitRaw(LispName(Name)); EmitRaw(' ');
   EmitRaw(Expr); EmitRaw(')'); EmitLn;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   If False Then If J=0 Then ;
 End;
End;

{ Variante : retourne un binding 'let*' pour les CONST locaux. }
Function CollectLocalConstBindings(Var I:Integer):TString;
Var Name,Expr,R:TString; Save:Integer;
Begin
 R:='';
 Inc(I);                     { sauter CONST }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     If (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
        (Tokens[I].Val='BEGIN')or(Tokens[I].Val='PROCEDURE')or
        (Tokens[I].Val='FUNCTION')or(Tokens[I].Val='IMPLEMENTATION')or
        (Tokens[I].Val='LABEL')or(Tokens[I].Val='USES')or(Tokens[I].Val='END')or
        (Tokens[I].Val='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
     Inc(I);
     While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) do Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   Save:=I;
   Expr:=ParseExpr(I);
   If I=Save Then Expr:='0';
   RegisterConst(Name);
   R:=R+'('+LispName(Name)+' '+Expr+') ';
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
 CollectLocalConstBindings:=R;
End;

{ TYPE section : emet juste un commentaire. }
Procedure EmitTypeSection(Var I:Integer);
Var Name:TString;
Begin
 Inc(I);                     { sauter TYPE }
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     If (Tokens[I].Val='VAR')or(Tokens[I].Val='CONST')or(Tokens[I].Val='TYPE')or
        (Tokens[I].Val='BEGIN')or(Tokens[I].Val='PROCEDURE')or
        (Tokens[I].Val='FUNCTION')or(Tokens[I].Val='IMPLEMENTATION')or
        (Tokens[I].Val='LABEL')or(Tokens[I].Val='USES')or(Tokens[I].Val='END')or
        (Tokens[I].Val='INITIALIZATION') Then Break;
   End;
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   Name:=Tokens[I].Val; Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
   EmitRaw('; type '); EmitRaw(LispName(Name));
   EmitRaw(' (alias non emis : Lisp est dynamique)'); EmitLn;
   { sauter jusqu'au ; au niveau 0 }
   While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
     If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END')) do Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Inc(I);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 End;
End;

{ ============================================================
  PROCEDURES / FONCTIONS
  ============================================================ }
{ Lit la liste des parametres et renvoie une chaine 'a b c'.
  Enregistre les noms comme variables connues.
  Si HasVar passe a True, signale un commentaire d'avertissement. }
Function ParseProcParams(Var I:Integer; Var HasVar:Boolean):TString;
Var
 Names:Array[1..32] of TString;
 NN,K:Integer;
 IsVar:Boolean;
 R,TypeS:TString;
 IsArr:Boolean;
Begin
 R:='';
 HasVar:=False;
 If Not((I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(')) Then Begin
   ParseProcParams:=R; Exit;
 End;
 Inc(I);
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
   IsVar:=False;
   If (Tokens[I].Kind=TK_KEYWORD)and
      ((Tokens[I].Val='VAR')or(Tokens[I].Val='OUT')) Then Begin
     IsVar:=True; HasVar:=True; Inc(I);
   End Else
   If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Inc(I);
   If Tokens[I].Kind<>TK_IDENT Then Begin Inc(I); Continue; End;
   NN:=0; Inc(NN); Names[NN]:=Tokens[I].Val; Inc(I);
   While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
     Inc(I);
     If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
       If NN<32 Then Begin Inc(NN); Names[NN]:=Tokens[I].Val; End;
       Inc(I);
     End;
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
   ConsumeType(I,TypeS,IsArr);
   For K:=1 to NN do Begin
     RegisterVar(Names[K]);
     If R<>'' Then R:=R+' ';
     R:=R+LispName(Names[K]);
   End;
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   If False Then If IsVar Then ;
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
 ParseProcParams:=R;
End;

Procedure EmitProcedure(Var I:Integer);
Var
 IsFunc:Boolean;
 Name,Params,LetBindings,B:TString;
 PrevFunc,SavedVarCount:Integer;
 HasVar:Boolean;
Begin
 IsFunc:=Tokens[I].Val='FUNCTION';
 Inc(I);
 Name:='';
 If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin Name:=Tokens[I].Val; Inc(I); End;
 PrevFunc:=CurFunc;
 CurFunc:=FindFunc(Name);
 SavedVarCount:=VarCount;
 Params:=ParseProcParams(I,HasVar);
 { sauter ': type' (deja vu en Analyze) }
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
   Inc(I);
   If I<=TokCount Then Inc(I);
 End;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 { directive forward / external -> ignorer la definition }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
    ((Tokens[I].Val='FORWARD')or(Tokens[I].Val='EXTERNAL')) Then Begin
   EmitRaw('; '); EmitRaw(LispName(Name));
   EmitRaw(' : declaration forward/external (ignoree)'); EmitLn;
   Inc(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
   CurFunc:=PrevFunc;
   VarCount:=SavedVarCount;
   Exit;
 End;
 EmitRaw('(defun '); EmitRaw(LispName(Name)); EmitRaw(' (');
 EmitRaw(Params); EmitRaw(')'); EmitLn;
 Inc(Indent);
 If HasVar Then Begin
   WriteIndent;
   EmitRaw('; NOTE : parametres VAR/OUT non geres en Lisp (passage par valeur)');
   EmitLn;
 End;
 { collecter les declarations locales VAR/CONST en un let* }
 LetBindings:='';
 If IsFunc Then LetBindings:='(_result_ '+DefaultForType(Funcs[CurFunc].RetType,False)+') ';
 While I<=TokCount do Begin
   If (Tokens[I].Kind=TK_KEYWORD) Then Begin
     If Tokens[I].Val='VAR' Then LetBindings:=LetBindings+CollectLocalVarBindings(I)
     Else If Tokens[I].Val='CONST' Then LetBindings:=LetBindings+CollectLocalConstBindings(I)
     Else If Tokens[I].Val='TYPE' Then EmitTypeSection(I)
     Else If Tokens[I].Val='LABEL' Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If I<=TokCount Then Inc(I);
     End Else Break;
   End Else Break;
 End;
 { ouverture du block-name pour permettre return-from }
 WriteIndent; EmitRaw('(block '); EmitRaw(LispName(Name)); EmitLn;
 Inc(Indent);
 If LetBindings<>'' Then Begin
   WriteIndent; EmitRaw('(let* ('); EmitRaw(LetBindings); EmitRaw(')'); EmitLn;
   Inc(Indent);
 End;
 { corps }
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
   Inc(I);
   EmitStatementList(I);
   If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
 End;
 If IsFunc Then Begin
   WriteIndent; EmitRaw('_result_'); EmitLn;
 End Else Begin
   WriteIndent; EmitRaw('nil'); EmitLn;
 End;
 If LetBindings<>'' Then Begin
   Dec(Indent);
   WriteIndent; EmitRaw(')'); EmitLn;
 End;
 Dec(Indent);
 WriteIndent; EmitRaw(')'); EmitLn;             { fin (block ) }
 Dec(Indent);
 EmitRaw(')'); EmitLn;                          { fin (defun ) }
 EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
 CurFunc:=PrevFunc;
 VarCount:=SavedVarCount;
 If False Then If B='' Then ;
End;

{ ============================================================
  USES / EN-TETE / BLOC PRINCIPAL
  ============================================================ }
Procedure EmitFileHeader;
Begin
 EmitRaw(';;;; Genere par PAS2LISP '+VERSION+' a partir de '+SrcName); EmitLn;
 EmitRaw(';;;; Programme : '+ProgName); EmitLn;
 EmitLn;
End;

Procedure EmitFileFooter;
Begin
 EmitLn;
End;

Procedure EmitUses(Var I:Integer);
Begin
 Inc(I);                     { sauter USES }
 EmitRaw('; uses : ');
 While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
   If Tokens[I].Kind=TK_IDENT Then EmitRaw(Tokens[I].Val+' ');
   Inc(I);
 End;
 EmitLn;
 If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
End;

Procedure EmitTopLevel;
Var
 I:Integer;
 K:TString;
 HasMain:Boolean;
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
 If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='USES') Then EmitUses(I);
 HasMain:=False;
 While I<=TokCount do Begin
   If Tokens[I].Kind=TK_EOF Then Break;
   If Tokens[I].Kind=TK_KEYWORD Then Begin
     K:=Tokens[I].Val;
     If K='IMPLEMENTATION' Then Begin Inc(I); Continue; End;
     If (K='INITIALIZATION')or(K='FINALIZATION') Then Begin
       EmitRaw('; section '); EmitRaw(StrLower(K)); EmitRaw(' non emise'); EmitLn;
       Inc(I); Continue;
     End;
     If K='USES' Then Begin EmitUses(I); Continue; End;
     If K='CONST' Then Begin EmitConstSectionGlobal(I); Continue; End;
     If K='TYPE' Then Begin EmitTypeSection(I); Continue; End;
     If K='VAR' Then Begin EmitVarSectionGlobal(I); Continue; End;
     If K='LABEL' Then Begin
       Inc(I);
       While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
       If I<=TokCount Then Inc(I);
       Continue;
     End;
     If (K='PROCEDURE')or(K='FUNCTION') Then Begin EmitProcedure(I); Continue; End;
     If K='BEGIN' Then Begin
       HasMain:=True;
       EmitRaw('; --- corps principal ---'); EmitLn;
       EmitRaw('(defun main ()'); EmitLn;
       Inc(Indent);
       WriteIndent; EmitRaw('(block main'); EmitLn;
       Inc(Indent);
       Inc(I);
       EmitStatementList(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
       If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='.') Then Inc(I);
       Dec(Indent);
       WriteIndent; EmitRaw(')'); EmitLn;
       Dec(Indent);
       EmitRaw(')'); EmitLn;
       EmitLn;
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
 If HasMain and Not IsUnit Then Begin
   EmitRaw('(main)'); EmitLn;
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
 WriteLn('PAS2LISP ',VERSION,' - Transpilateur Pascal vers Common Lisp');
 WriteLn('(C) Gladir.com');
 WriteLn;
 WriteLn('Usage : PAS2LISP source.pas [destination.lisp]');
 WriteLn('Exemple : PAS2LISP hello.pas hello.lisp');
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
   If I>0 Then DstName:=Copy(A,1,I-1)+'.lisp'
          Else DstName:=A+'.lisp';
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
 EmitFileHeader;
 EmitTopLevel;
 EmitFileFooter;
 CloseFiles;
 WriteLn('PAS2LISP : ',SrcName,' -> ',DstName,' (',TokCount,' tokens, ',
         FuncCount,' procs/funcs).');
End.
