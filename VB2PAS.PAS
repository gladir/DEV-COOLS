{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Visual Basic 6 vers Turbo Pascal
}

(* ============================================================
   VB2PAS.PAS - Transpilateur Visual Basic 6 vers Turbo Pascal
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Turbo Pascal (.pas)

   Couvre les constructions courantes de VB6 :
     Sub / Function ... End Sub / End Function -> procedure/function
     Dim / Const / Static -> var / const
     If..Then..ElseIf..Else..End If -> if..then..else if..else..end
     Select Case..End Select -> case..of..end
     For x = a To b [Step s] ... Next -> for x := a to b do
     Do / Loop While|Until / While..Wend -> while..do
     Exit Sub/Function/For/Do -> exit/break
     Type..End Type -> record
     Debug.Print -> WriteLn
     MsgBox / InputBox -> WriteLn / ReadLn (commente)
     Operateurs : = (contextuel ->:= ou =), <> -> <>,
       \ -> div, Mod -> mod, & -> + (concatenation),
       And/Or/Not/Xor -> and/or/not/xor,
       Eqv/Imp/Is/Like signales en commentaire.

   Limitations :
     - VB6 est insensible a la casse ; le sens d emploi de '='
       (affectation vs egalite) est determine par contexte simple.
     - Les constructions COM/UserForms/With ne sont pas converties.
     - Les types Variant, Currency, Object sont approximes.
     - On Error / GoSub / Property sont signales en commentaire.
   ============================================================ *)

Program VB2PAS;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Const
  VB2PAS_VERSION = '1.0';
  VB2PAS_DATE    = '2026-04-28';

  MAX_STR     = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_TOKEN   = {$IFDEF FPC}32000{$ELSE}4000{$ENDIF};
  MAX_PROC    = {$IFDEF FPC}256{$ELSE}64{$ENDIF};

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

Type
  TString = String[MAX_STR];

  TTokenKind = (
    TK_EOF,
    TK_EOS,        { fin de ligne ou ':' separateur d instructions }
    TK_INTEGER,
    TK_REAL,
    TK_STRING,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT
  );

  TToken = Record
    Kind : TTokenKind;
    Val  : TString;
    Line : Integer;
  End;

  TFuncRec = Record
    Name      : TString;
    RetType   : TString;     { type Pascal de retour ('' si Sub) }
    IsFunc    : Boolean;
  End;

Var
  SrcFile, DstFile : Text;
  SrcName, DstName : TString;
  Verbose          : Boolean;

  Tokens           : Array[1..MAX_TOKEN] of TToken;
  TokCount         : Integer;

  ProgName         : TString;
  Funcs            : Array[1..MAX_PROC] of TFuncRec;
  FuncCount        : Integer;
  HasMain          : Boolean;

  CurFunc          : Integer;
  ErrorCount       : Integer;
  InProcBody       : Boolean;

{ ============================================================
  UTILITAIRES STRING
  ============================================================ }
Function StrUpper(S:TString):TString;
Var I:Integer;
Begin
  For I:=1 to Length(S) do
    If S[I] in ['a'..'z'] Then S[I]:=Chr(Ord(S[I])-32);
  StrUpper:=S;
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
  TOKENISEUR
  ============================================================ }
Var
  SrcText      : TString;
  SrcLineNo    : Integer;
  SrcCol       : Integer;
  SrcEOF       : Boolean;
  PendingChar  : Char;
  HasPending   : Boolean;

Procedure TokInit;
Begin
  SrcText:='';
  SrcLineNo:=0;
  SrcCol:=1;
  SrcEOF:=False;
  HasPending:=False;
  PendingChar:=#0;
End;

Function NextCh:Char;
Var Ch:Char;
Begin
  If HasPending Then Begin
    HasPending:=False;
    NextCh:=PendingChar;
    Exit;
  End;
  If SrcEOF Then Begin NextCh:=#0; Exit; End;
  If SrcCol>Length(SrcText) Then Begin
    If EOF(SrcFile) Then Begin SrcEOF:=True; NextCh:=#0; Exit; End;
    ReadLn(SrcFile,SrcText);
    Inc(SrcLineNo);
    SrcCol:=1;
    NextCh:=#10;
    Exit;
  End;
  Ch:=SrcText[SrcCol];
  Inc(SrcCol);
  NextCh:=Ch;
End;

Procedure UngetCh(Ch:Char);
Begin
  PendingChar:=Ch;
  HasPending:=True;
End;

Function PeekCh:Char;
Var Ch:Char;
Begin
  Ch:=NextCh;
  UngetCh(Ch);
  PeekCh:=Ch;
End;

Procedure AddTok(K:TTokenKind; V:TString);
Begin
  If TokCount>=MAX_TOKEN Then Begin
    WriteLn('VB2PAS : trop de tokens (>',MAX_TOKEN,')');
    Halt(EXIT_ERROR);
  End;
  { eviter de dupliquer un TK_EOS en debut de tableau }
  If (K=TK_EOS) and ((TokCount=0) or (Tokens[TokCount].Kind=TK_EOS)) Then Exit;
  Inc(TokCount);
  Tokens[TokCount].Kind:=K;
  Tokens[TokCount].Val :=V;
  Tokens[TokCount].Line:=SrcLineNo;
End;

Function IsVBKeyword(S:TString):Boolean;
Var U:TString;
Begin
  U:=StrUpper(S);
  IsVBKeyword:=
    (U='SUB')or(U='FUNCTION')or(U='END')or(U='AS')or(U='DIM')or
    (U='PUBLIC')or(U='PRIVATE')or(U='STATIC')or(U='CONST')or
    (U='IF')or(U='THEN')or(U='ELSE')or(U='ELSEIF')or
    (U='SELECT')or(U='CASE')or
    (U='FOR')or(U='TO')or(U='STEP')or(U='NEXT')or
    (U='DO')or(U='LOOP')or(U='WHILE')or(U='UNTIL')or(U='WEND')or
    (U='EXIT')or(U='RETURN')or(U='GOTO')or
    (U='AND')or(U='OR')or(U='NOT')or(U='XOR')or(U='MOD')or
    (U='EQV')or(U='IMP')or(U='IS')or(U='LIKE')or
    (U='TRUE')or(U='FALSE')or(U='NOTHING')or(U='NULL')or
    (U='EMPTY')or(U='NEW')or(U='ME')or
    (U='TYPE')or(U='SET')or(U='WITH')or(U='REDIM')or(U='ERASE')or
    (U='CALL')or(U='OPTION')or(U='EXPLICIT')or(U='ATTRIBUTE')or
    (U='BYVAL')or(U='BYREF')or(U='OPTIONAL')or
    (U='ON')or(U='ERROR')or(U='RESUME')or(U='GOSUB')or
    (U='PROPERTY')or(U='GET')or(U='LET')or(U='FRIEND')or
    (U='MOD')or(U='IN')or(U='STOP');
End;

Procedure ScanString;
Var S:TString; Ch:Char;
Begin
  S:='"';
  Repeat
    Ch:=NextCh;
    If (Ch=#0)or(Ch=#10) Then Begin
      WriteLn('VB2PAS : chaine non terminee ligne ',SrcLineNo);
      Inc(ErrorCount);
      Break;
    End;
    S:=S+Ch;
    If Ch='"' Then Begin
      Ch:=PeekCh;
      If Ch='"' Then Begin S:=S+NextCh; End
      Else Break;
    End;
  Until False;
  AddTok(TK_STRING,S);
End;

Procedure ScanNumberAmp;
{ Lit un nombre &H... (hex) ou &O... (octal) ou &B... (binaire). }
Var S:TString; Ch,Type_:Char;
Begin
  S:='&';
  Ch:=PeekCh;
  Type_:=Upcase(Ch);
  If (Type_='H')or(Type_='O')or(Type_='B') Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    While Ch in ['0'..'9','A'..'F','a'..'f'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
    AddTok(TK_INTEGER,S);
  End Else
    AddTok(TK_OP,'&');
End;

Procedure ScanNumber(First:Char);
Var S:TString; Ch:Char; IsReal:Boolean;
Begin
  S:=First;
  IsReal:=False;
  Ch:=PeekCh;
  While Ch in ['0'..'9'] do Begin S:=S+NextCh; Ch:=PeekCh; End;
  If Ch='.' Then Begin
    IsReal:=True;
    S:=S+NextCh;
    Ch:=PeekCh;
    While Ch in ['0'..'9'] do Begin S:=S+NextCh; Ch:=PeekCh; End;
  End;
  If (Ch='e')or(Ch='E') Then Begin
    IsReal:=True;
    S:=S+NextCh;
    Ch:=PeekCh;
    If (Ch='+')or(Ch='-') Then Begin S:=S+NextCh; Ch:=PeekCh; End;
    While Ch in ['0'..'9'] do Begin S:=S+NextCh; Ch:=PeekCh; End;
  End;
  { suffixes de type VB : %, &, !, #, @, $ - on les ignore }
  Ch:=PeekCh;
  If Ch in ['%','&','!','#','@','$'] Then NextCh;
  If IsReal Then AddTok(TK_REAL,S) Else AddTok(TK_INTEGER,S);
End;

Procedure ScanIdent(First:Char);
Var S:TString; Ch:Char;
Begin
  S:=First;
  Ch:=PeekCh;
  While Ch in ['A'..'Z','a'..'z','0'..'9','_'] do Begin
    S:=S+NextCh;
    Ch:=PeekCh;
  End;
  { suffixe de type VB : ignore (sauf $ qui est concat) }
  Ch:=PeekCh;
  If Ch in ['%','&','!','#','@','$'] Then NextCh;
  If StrEqualCI(S,'REM') Then Begin
    { commentaire jusqu a fin de ligne }
    While (Ch<>#10)and(Ch<>#0) do Ch:=NextCh;
    Exit;
  End;
  If IsVBKeyword(S) Then AddTok(TK_KEYWORD,StrUpper(S))
                    Else AddTok(TK_IDENT,S);
End;

Procedure SkipLineComment;
Var Ch:Char;
Begin
  Repeat Ch:=NextCh; Until (Ch=#10)or(Ch=#0);
  AddTok(TK_EOS,'');
End;

Procedure Tokenize;
Var Ch,Ch2:Char; S:TString;
Begin
  TokCount:=0;
  TokInit;
  Repeat
    Ch:=NextCh;
    If Ch=#0 Then Break;
    Case Ch of
      ' ',#9,#13: ; { ignorer }
      #10: AddTok(TK_EOS,'');
      '_':Begin
        { underscore en fin de ligne = continuation }
        Ch2:=PeekCh;
        If (Ch2=' ')or(Ch2=#9)or(Ch2=#10)or(Ch2=#13) Then Begin
          { sauter espaces et fin de ligne }
          While (Ch2=' ')or(Ch2=#9)or(Ch2=#13) do Begin NextCh; Ch2:=PeekCh; End;
          If Ch2=#10 Then NextCh;
        End Else Begin
          { _ en debut d ident est legal en VB ? rare ; on le traite comme ident }
          ScanIdent('_');
        End;
      End;
      '''':SkipLineComment;
      '"':ScanString;
      '&':ScanNumberAmp;
      '0'..'9':ScanNumber(Ch);
      'A'..'Z','a'..'z':ScanIdent(Ch);
      ':':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddTok(TK_OP,':='); End { attribut Foo:=Bar }
        Else AddTok(TK_EOS,'');
      End;
      '<':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddTok(TK_OP,'<='); End Else
        If Ch2='>' Then Begin NextCh; AddTok(TK_OP,'<>'); End
        Else AddTok(TK_OP,'<');
      End;
      '>':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddTok(TK_OP,'>='); End
        Else AddTok(TK_OP,'>');
      End;
      '+','-','*','/','=','^','\':Begin S:=Ch; AddTok(TK_OP,S); End;
      '.':AddTok(TK_PUNCT,'.');
      '(',')',',',';','[',']','#','?','!':Begin S:=Ch; AddTok(TK_PUNCT,S); End;
    Else
      { caractere inconnu : ignorer silencieusement }
    End;
  Until SrcEOF and (Not HasPending);
  AddTok(TK_EOS,'');
  AddTok(TK_EOF,'');
End;

{ ============================================================
  MAPPAGES
  ============================================================ }
Function MapVBType(T:TString):TString;
Var U:TString;
Begin
  U:=StrUpper(T);
  If U='INTEGER' Then MapVBType:='SmallInt' Else
  If U='LONG' Then MapVBType:='LongInt' Else
  If U='SINGLE' Then MapVBType:='Single' Else
  If U='DOUBLE' Then MapVBType:='Double' Else
  If U='STRING' Then MapVBType:='String' Else
  If U='BOOLEAN' Then MapVBType:='Boolean' Else
  If U='BYTE' Then MapVBType:='Byte' Else
  If U='CURRENCY' Then MapVBType:='Real' Else
  If U='DATE' Then MapVBType:='TDateTime' Else
  If U='VARIANT' Then MapVBType:='Variant' Else
  If U='OBJECT' Then MapVBType:='Pointer' Else
  If U='ANY' Then MapVBType:='Pointer' Else
  MapVBType:=T;
End;

Function MapVBKeyword(K:TString):TString;
Begin
  If K='AND' Then MapVBKeyword:='and' Else
  If K='OR'  Then MapVBKeyword:='or' Else
  If K='NOT' Then MapVBKeyword:='not' Else
  If K='XOR' Then MapVBKeyword:='xor' Else
  If K='MOD' Then MapVBKeyword:='mod' Else
  If K='TRUE' Then MapVBKeyword:='True' Else
  If K='FALSE' Then MapVBKeyword:='False' Else
  If K='NOTHING' Then MapVBKeyword:='nil' Else
  If K='NULL' Then MapVBKeyword:='nil' Else
  If K='EMPTY' Then MapVBKeyword:='nil' Else
  If K='ME' Then MapVBKeyword:='Self' Else
  If K='IS' Then MapVBKeyword:='=' Else
  If K='EQV' Then MapVBKeyword:='=' Else
  If K='IMP' Then MapVBKeyword:='<=' Else
  If K='LIKE' Then MapVBKeyword:='='
  Else MapVBKeyword:=K;
End;

Function MapVBOperator(Op:TString):TString;
Begin
  If Op='\' Then MapVBOperator:='div' Else
  If Op='&' Then MapVBOperator:='+' Else
  If Op='^' Then MapVBOperator:='**' Else { signale, pas d operateur Pascal }
  MapVBOperator:=Op;
End;

{ Conversion d une chaine VB6 "abc""def" en chaine Pascal 'abc"def'.
  En VB6 le " est double pour s echapper ; en Pascal c est ' qui doit
  etre double, et " est juste un caractere. }
Function VBStringToPas(S:TString):TString;
Var I:Integer; R:TString;
Begin
  R:='';
  I:=2;
  While I<Length(S) do Begin
    If (S[I]='"')and(I<Length(S))and(S[I+1]='"') Then Begin
      R:=R+'"'; Inc(I,2);
    End Else
    If S[I]='''' Then Begin
      R:=R+''''''; Inc(I);
    End Else Begin
      R:=R+S[I]; Inc(I);
    End;
  End;
  VBStringToPas:=''''+R+'''';
End;

{ Conversion d un nombre VB &H1A ou &O17 en litteral Pascal. }
Function VBIntToPas(S:TString):TString;
Var Body:TString;
Begin
  If (Length(S)>=2)and(S[1]='&') Then Begin
    Body:=Copy(S,3,Length(S)-2);
    If (Length(S)>=2)and(Upcase(S[2])='H') Then VBIntToPas:='$'+Body Else
    If (Length(S)>=2)and(Upcase(S[2])='O') Then VBIntToPas:='&'+Body Else
    If (Length(S)>=2)and(Upcase(S[2])='B') Then VBIntToPas:='%'+Body Else
    VBIntToPas:=S;
  End Else
    VBIntToPas:=S;
End;

{ ============================================================
  ANALYSEUR : recense Subs/Functions, detecte Sub Main
  ============================================================ }
Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean);
Begin
  If FuncCount>=MAX_PROC Then Exit;
  Inc(FuncCount);
  Funcs[FuncCount].Name   :=Name;
  Funcs[FuncCount].RetType:=RetType;
  Funcs[FuncCount].IsFunc :=IsFunc;
End;

Function FindFunc(Name:TString):Integer;
Var I:Integer;
Begin
  For I:=1 to FuncCount do
    If StrEqualCI(Funcs[I].Name,Name) Then Begin
      FindFunc:=I;
      Exit;
    End;
  FindFunc:=0;
End;

Procedure Analyze;
Var I,J,Depth:Integer; K,Ret:TString;
Begin
  ProgName:='VbProgram';
  FuncCount:=0;
  HasMain:=False;
  I:=1;
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='ATTRIBUTE') and (I+2<=TokCount) Then Begin
        { Attribute VB_Name = "Module1" }
        If (Tokens[I+1].Kind=TK_IDENT)and StrEqualCI(Tokens[I+1].Val,'VB_Name') Then Begin
          J:=I+2;
          While (J<=TokCount) and (Tokens[J].Kind<>TK_STRING) and (Tokens[J].Kind<>TK_EOS) do Inc(J);
          If (J<=TokCount) and (Tokens[J].Kind=TK_STRING) Then Begin
            { extraire le nom sans guillemets }
            ProgName:=Copy(Tokens[J].Val,2,Length(Tokens[J].Val)-2);
          End;
        End;
      End Else
      If ((K='SUB')or(K='FUNCTION')) and (I<TokCount) Then Begin
        J:=I+1;
        { sauter Public/Private/Static qui aurait deja ete mis comme keyword }
        If (J<=TokCount) and (Tokens[J].Kind=TK_IDENT) Then Begin
          Ret:='';
          If K='FUNCTION' Then Begin
            { rechercher : <nom>(...) As <type> }
            Depth:=0;
            J:=J+1;
            If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Begin
              Depth:=1; Inc(J);
              While (J<=TokCount) and (Depth>0) do Begin
                If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
                If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
                Inc(J);
              End;
            End;
            If (J<=TokCount)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='AS') Then Begin
              Inc(J);
              If (J<=TokCount)and((Tokens[J].Kind=TK_IDENT)or(Tokens[J].Kind=TK_KEYWORD)) Then
                Ret:=MapVBType(Tokens[J].Val);
            End;
            If Ret='' Then Ret:='Variant';
            RegisterFunc(Tokens[I+1].Val,Ret,True);
          End Else Begin
            RegisterFunc(Tokens[I+1].Val,'',False);
            If StrEqualCI(Tokens[I+1].Val,'Main') Then HasMain:=True;
          End;
        End;
      End;
    End;
    Inc(I);
  End;
End;

{ ============================================================
  EMISSION
  ============================================================ }
Var
  OutCol  : Integer;
  OutLine : TString;
  Indent  : Integer;

Procedure FlushLine;
Begin
  WriteLn(DstFile,OutLine);
  OutLine:='';
  OutCol:=0;
End;

Procedure EmitRaw(S:TString);
Var I:Integer;
Begin
  For I:=1 to Length(S) do Begin
    If S[I]=#10 Then FlushLine
    Else Begin
      If OutCol=0 Then Begin
        For OutCol:=1 to Indent*2 do OutLine:=OutLine+' ';
        OutCol:=Indent*2;
      End;
      OutLine:=OutLine+S[I];
      Inc(OutCol);
    End;
  End;
End;

Procedure EmitLn;
Begin
  EmitRaw(#10);
End;

Procedure EmitSpace;
Begin
  If (OutCol>0)and(Length(OutLine)>0)and(OutLine[Length(OutLine)]<>' ') Then EmitRaw(' ');
End;

{ Saute les TK_EOS consecutifs }
Procedure SkipEOS(Var I:Integer);
Begin
  While (I<=TokCount) and (Tokens[I].Kind=TK_EOS) do Inc(I);
End;

{ Forward declarations }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure SkipDimLike(Var I:Integer); Forward;
Procedure EmitBlock(Var I:Integer; Const StopSet:TString); Forward;
Procedure EmitExpr(Var I:Integer; StopAtEOS,StopAtComma:Boolean); Forward;

{ Determine si Tokens[I] est un mot-cle terminant un bloc }
Function IsBlockEnd(Const T:TToken; Const StopSet:TString):Boolean;
Var U:TString;
Begin
  IsBlockEnd:=False;
  If T.Kind<>TK_KEYWORD Then Exit;
  U:=','+T.Val+',';
  IsBlockEnd:=Pos(U,StopSet)>0;
End;

{ Emet une expression VB6 jusqu a un EOS ou a un mot-cle structurant.
  StopAtComma : aussi s arrete sur ',' au niveau 0.
  Convertit operateurs, identificateurs (cas special : True/False/Nothing,
  Debug.Print, etc.) }
Procedure EmitExpr(Var I:Integer; StopAtEOS,StopAtComma:Boolean);
Var Depth:Integer; K:TString; First:Boolean;
Begin
  Depth:=0;
  First:=True;
  While I<=TokCount do Begin
    If (Depth=0) Then Begin
      If StopAtEOS and (Tokens[I].Kind=TK_EOS) Then Break;
      If Tokens[I].Kind=TK_EOF Then Break;
      If StopAtComma and (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Break;
      If (Tokens[I].Kind=TK_KEYWORD) and
         ((Tokens[I].Val='THEN')or(Tokens[I].Val='TO')or(Tokens[I].Val='STEP')or
          (Tokens[I].Val='AS')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='ELSEIF')) Then Break;
    End;
    If Not First Then Begin
      { espace selectif }
      If (Tokens[I].Kind=TK_OP) Then EmitSpace
      Else If (Tokens[I].Kind=TK_KEYWORD) Then EmitSpace
      Else If (Tokens[I].Kind=TK_IDENT) Then Begin
        { espace seulement apres un autre ident ou un mot-cle }
        If (I>1)and((Tokens[I-1].Kind=TK_IDENT)or(Tokens[I-1].Kind=TK_KEYWORD)or
                    (Tokens[I-1].Kind=TK_INTEGER)or(Tokens[I-1].Kind=TK_REAL)or
                    (Tokens[I-1].Kind=TK_STRING)) Then EmitSpace;
      End;
    End;
    First:=False;
    Case Tokens[I].Kind of
      TK_INTEGER:EmitRaw(VBIntToPas(Tokens[I].Val));
      TK_REAL   :EmitRaw(Tokens[I].Val);
      TK_STRING :EmitRaw(VBStringToPas(Tokens[I].Val));
      TK_IDENT  :EmitRaw(Tokens[I].Val);
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='NEW' Then Begin EmitRaw('{ NEW '); End Else
        EmitRaw(MapVBKeyword(K));
        If K='NEW' Then EmitRaw(' }');
      End;
      TK_OP:Begin
        If Tokens[I].Val='=' Then EmitRaw('=')
        Else If (Tokens[I].Val='\')or(Tokens[I].Val='&') Then Begin
          EmitSpace; EmitRaw(MapVBOperator(Tokens[I].Val)); EmitSpace;
        End
        Else If Tokens[I].Val='^' Then EmitRaw(' { ^ } ')
        Else EmitRaw(Tokens[I].Val);
      End;
      TK_PUNCT:Begin
        If Tokens[I].Val='(' Then Inc(Depth) Else
        If Tokens[I].Val=')' Then Dec(Depth);
        EmitRaw(Tokens[I].Val);
      End;
    End;
    Inc(I);
  End;
End;

{ Emet une affectation : <lhs> = <rhs>.
  En VB6 le '=' est ambigu ; au niveau d une instruction simple, il
  s agit d une affectation. On emet donc <lhs> := <rhs>. }
Procedure EmitAssign(Var I:Integer);
Var First:Boolean;
Begin
  First:=True;
  { LHS jusqu au premier '=' au niveau 0 }
  While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) and
        (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If Not First Then EmitSpace;
    First:=False;
    Case Tokens[I].Kind of
      TK_IDENT  :EmitRaw(Tokens[I].Val);
      TK_KEYWORD:EmitRaw(MapVBKeyword(Tokens[I].Val));
      TK_INTEGER:EmitRaw(VBIntToPas(Tokens[I].Val));
      TK_STRING :EmitRaw(VBStringToPas(Tokens[I].Val));
    Else
      EmitRaw(Tokens[I].Val);
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
    EmitRaw(' := ');
    Inc(I);
  End;
  EmitExpr(I,True,False);
  EmitRaw(';');
End;

{ Determine si un token courant correspond au debut d une affectation
  (ident ou ident.qualified ou ident(...) suivi de '=' au niveau 0). }
Function IsAssignment(StartI:Integer):Boolean;
Var J,Depth:Integer;
Begin
  IsAssignment:=False;
  J:=StartI;
  Depth:=0;
  If (J>TokCount) or
     ((Tokens[J].Kind<>TK_IDENT) and Not((Tokens[J].Kind=TK_KEYWORD) and (Tokens[J].Val='ME'))) Then Exit;
  While J<=TokCount do Begin
    If Tokens[J].Kind=TK_EOS Then Exit;
    If Tokens[J].Kind=TK_EOF Then Exit;
    If (Depth=0) and (Tokens[J].Kind=TK_OP) and (Tokens[J].Val='=') Then Begin
      IsAssignment:=True;
      Exit;
    End;
    If (Depth=0) and (Tokens[J].Kind=TK_KEYWORD) Then Begin
      { si on rencontre un mot-cle de structure avant '=', ce n est pas une affectation }
      If (Tokens[J].Val='THEN')or(Tokens[J].Val='ELSE')or(Tokens[J].Val='TO')or
         (Tokens[J].Val='STEP')or(Tokens[J].Val='AS') Then Exit;
    End;
    If (Tokens[J].Kind=TK_PUNCT) Then Begin
      If (Tokens[J].Val='(')or(Tokens[J].Val='[') Then Inc(Depth) Else
      If (Tokens[J].Val=')')or(Tokens[J].Val=']') Then Dec(Depth);
    End;
    Inc(J);
  End;
End;

{ Emet une declaration Dim/Static/Public/Private au niveau procedure
  ou module. Forme : <KW> name [As Type] [, name [As Type]]... }
Procedure EmitDimLike(Var I:Integer);
Var Name,Typ:TString; First:Boolean;
Begin
  Inc(I); { sauter le mot-cle Dim/Static/etc. }
  EmitRaw('var ');
  First:=True;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If Tokens[I].Kind=TK_IDENT Then Begin
      Name:=Tokens[I].Val;
      Inc(I);
      Typ:='Variant';
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
        Inc(I);
        If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
          Typ:=MapVBType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      If Not First Then EmitRaw('; ');
      EmitRaw(Name+': '+Typ);
      First:=False;
    End Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
    Else Inc(I);
  End;
  EmitRaw(';');
End;

{ Emet une declaration Const : Const X As T = expr }
Procedure EmitConstDecl(Var I:Integer);
Var Name,Typ:TString;
Begin
  Inc(I); { sauter Const }
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    Inc(I);
    Typ:='';
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
      Inc(I);
      If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
        Typ:=MapVBType(Tokens[I].Val);
        Inc(I);
      End;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
    EmitRaw('const '+Name);
    If Typ<>'' Then EmitRaw(': '+Typ);
    EmitRaw(' = ');
    EmitExpr(I,True,False);
    EmitRaw(';');
  End;
End;

{ Emet une instruction If ... Then ... [ElseIf...] [Else ...] End If
  ou la forme inline If cond Then stmt [Else stmt]. }
Procedure EmitIf(Var I:Integer);
Var Inline_:Boolean;
Begin
  Inc(I); { IF }
  EmitRaw('if ');
  EmitExpr(I,False,False);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitRaw(' then begin');
  EmitLn;
  Inc(Indent);
  Inline_:=False;
  { si la prochaine chose n est pas EOS, c est une forme inline }
  If (I<=TokCount)and(Tokens[I].Kind<>TK_EOS) Then Begin
    Inline_:=True;
    EmitStmt(I);
    Dec(Indent);
    EmitRaw('end;');
    EmitLn;
    { eventuellement Else <stmt> sur la meme ligne }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
      Inc(I);
      EmitRaw('{ else }'); EmitLn;
    End;
    Exit;
  End;
  SkipEOS(I);
  EmitBlock(I,',ELSE,ELSEIF,END,');
  Dec(Indent);
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSEIF') do Begin
    Inc(I);
    EmitRaw('end else if ');
    EmitExpr(I,False,False);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
    EmitRaw(' then begin');
    EmitLn;
    Inc(Indent);
    SkipEOS(I);
    EmitBlock(I,',ELSE,ELSEIF,END,');
    Dec(Indent);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
    Inc(I);
    EmitRaw('end else begin');
    EmitLn;
    Inc(Indent);
    SkipEOS(I);
    EmitBlock(I,',END,');
    Dec(Indent);
  End;
  EmitRaw('end;');
  EmitLn;
  { consommer END IF }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IF') Then Inc(I);
  End;
End;

{ Emet For X = A To B [Step S] ... Next [X] }
Procedure EmitFor(Var I:Integer);
Var VarName,StepStr:TString; UseStep:Boolean;
Begin
  Inc(I); { FOR }
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    VarName:=Tokens[I].Val;
    Inc(I);
  End Else VarName:='I';
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
  EmitRaw('for '+VarName+' := ');
  EmitExpr(I,True,False);
  UseStep:=False;
  StepStr:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Begin
    Inc(I);
    EmitRaw(' to ');
    EmitExpr(I,True,False);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STEP') Then Begin
    Inc(I);
    UseStep:=True;
    EmitRaw(' { step ');
    While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
      EmitRaw(Tokens[I].Val); Inc(I);
    End;
    EmitRaw(' }');
  End;
  EmitRaw(' do begin');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',NEXT,');
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='NEXT') Then Begin
    Inc(I);
    { sauter eventuelle variable apres Next }
    If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Inc(I);
  End;
End;

{ Emet While ... Wend }
Procedure EmitWhile(Var I:Integer);
Begin
  Inc(I); { WHILE }
  EmitRaw('while ');
  EmitExpr(I,True,False);
  EmitRaw(' do begin');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',WEND,');
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WEND') Then Inc(I);
End;

{ Emet Do [While|Until cond] ... Loop [While|Until cond] }
Procedure EmitDo(Var I:Integer);
Var TopCond,TopUntil:Boolean; Cond:TString; J:Integer;
Begin
  Inc(I); { DO }
  TopCond:=False;
  TopUntil:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WHILE') Then Begin
    Inc(I);
    TopCond:=True;
    EmitRaw('while ');
    EmitExpr(I,True,False);
    EmitRaw(' do begin');
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Begin
    Inc(I);
    TopUntil:=True;
    EmitRaw('while not (');
    EmitExpr(I,True,False);
    EmitRaw(') do begin');
  End Else Begin
    EmitRaw('repeat');
  End;
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',LOOP,');
  Dec(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='LOOP') Then Inc(I);
  If TopCond or TopUntil Then Begin
    EmitRaw('end;');
    EmitLn;
    { eventuel "While|Until cond" au pied de Loop : on l ignore (forme top deja emise) }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='WHILE')or(Tokens[I].Val='UNTIL')) Then Begin
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
    End;
  End Else Begin
    { repeat ... until cond ; }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Begin
      Inc(I);
      EmitRaw('until ');
      EmitExpr(I,True,False);
      EmitRaw(';');
      EmitLn;
    End Else
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WHILE') Then Begin
      Inc(I);
      EmitRaw('until not (');
      EmitExpr(I,True,False);
      EmitRaw(');');
      EmitLn;
    End Else Begin
      EmitRaw('until False;');
      EmitLn;
    End;
  End;
End;

{ Emet Select Case <expr> ... Case <list> ... Case Else ... End Select }
Procedure EmitSelect(Var I:Integer);
Var First:Boolean;
Begin
  Inc(I); { SELECT }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CASE') Then Inc(I);
  EmitRaw('case ');
  EmitExpr(I,True,False);
  EmitRaw(' of');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  First:=True;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Break;
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CASE') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
        Inc(I);
        EmitRaw('else');
        EmitLn;
        Inc(Indent);
        EmitRaw('begin');
        EmitLn;
        Inc(Indent);
        SkipEOS(I);
        EmitBlock(I,',END,CASE,');
        Dec(Indent);
        EmitRaw('end;');
        EmitLn;
        Dec(Indent);
      End Else Begin
        { liste d items separes par , ; emis tels quels }
        EmitExpr(I,True,False);
        EmitRaw(':');
        EmitLn;
        Inc(Indent);
        EmitRaw('begin');
        EmitLn;
        Inc(Indent);
        SkipEOS(I);
        EmitBlock(I,',END,CASE,');
        Dec(Indent);
        EmitRaw('end;');
        EmitLn;
        Dec(Indent);
      End;
    End Else Inc(I);
  End;
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='SELECT') Then Inc(I);
  End;
End;

{ Emet Type ... End Type comme record Pascal }
Procedure EmitType(Var I:Integer);
Var Name,FName,FType:TString;
Begin
  Inc(I); { TYPE }
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    Inc(I);
  End Else Name:='TUnknown';
  EmitRaw('type'); EmitLn;
  Inc(Indent);
  EmitRaw(Name+' = record'); EmitLn;
  Inc(Indent);
  SkipEOS(I);
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Break;
    If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
      FName:=Tokens[I].Val;
      Inc(I);
      FType:='Variant';
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
        Inc(I);
        If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
          FType:=MapVBType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      EmitRaw(FName+': '+FType+';');
      EmitLn;
    End Else Inc(I);
  End;
  Dec(Indent);
  EmitRaw('end;'); EmitLn;
  Dec(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TYPE') Then Inc(I);
  End;
End;

{ Emet Debug.Print arg [, arg ...] -> WriteLn(arg, arg ...) }
Procedure EmitDebugPrint(Var I:Integer);
Var First:Boolean;
Begin
  EmitRaw('WriteLn(');
  First:=True;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If Not First Then EmitRaw(', ');
    First:=False;
    EmitExpr(I,True,True);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
    Else If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I)
    Else Break;
  End;
  EmitRaw(');');
End;

{ Emet une instruction unique. Avance I. }
Procedure EmitStmt(Var I:Integer);
Var K:TString; J:Integer;
Begin
  SkipEOS(I);
  If (I>TokCount)or(Tokens[I].Kind=TK_EOF) Then Exit;
  If Tokens[I].Kind=TK_KEYWORD Then Begin
    K:=Tokens[I].Val;
    If (K='DIM')or(K='STATIC')or
       ((K='PUBLIC')or(K='PRIVATE')) and (I+1<=TokCount) and
       Not((Tokens[I+1].Kind=TK_KEYWORD)and((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')or(Tokens[I+1].Val='TYPE')or(Tokens[I+1].Val='CONST')))
    Then Begin
      If InProcBody Then SkipDimLike(I)
      Else Begin EmitDimLike(I); EmitLn; End;
      Exit;
    End;
    If (K='PUBLIC')or(K='PRIVATE') Then Begin
      Inc(I); { mot-cle de portee, on continue }
      EmitStmt(I); Exit;
    End;
    If K='CONST' Then Begin EmitConstDecl(I); EmitLn; Exit; End;
    If K='IF' Then Begin EmitIf(I); Exit; End;
    If K='FOR' Then Begin EmitFor(I); Exit; End;
    If K='WHILE' Then Begin EmitWhile(I); Exit; End;
    If K='DO' Then Begin EmitDo(I); Exit; End;
    If K='SELECT' Then Begin EmitSelect(I); Exit; End;
    If K='TYPE' Then Begin EmitType(I); Exit; End;
    If K='SET' Then Begin
      Inc(I); { en Pascal, l affectation d objet est identique a une affectation }
      If IsAssignment(I) Then EmitAssign(I)
      Else EmitExpr(I,True,False);
      EmitLn; Exit;
    End;
    If K='CALL' Then Begin
      Inc(I);
      EmitExpr(I,True,False);
      EmitRaw(';'); EmitLn; Exit;
    End;
    If K='EXIT' Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD) Then Inc(I); { Sub/Function/For/Do }
      EmitRaw('Exit;'); EmitLn; Exit;
    End;
    If K='RETURN' Then Begin
      Inc(I);
      EmitRaw('{ Return : equivaut a Exit en Pascal } Exit;'); EmitLn; Exit;
    End;
    If K='GOTO' Then Begin
      Inc(I);
      EmitRaw('goto ');
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin EmitRaw(Tokens[I].Val); Inc(I); End;
      EmitRaw(';'); EmitLn; Exit;
    End;
    If K='ON' Then Begin
      EmitRaw('{ On Error/Goto non traduit : ');
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw('}'); EmitLn; Exit;
    End;
    If K='OPTION' Then Begin
      EmitRaw('{ Option ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw('}'); EmitLn; Exit;
    End;
    If K='ATTRIBUTE' Then Begin
      EmitRaw('{ Attribute ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw(' }'); EmitLn; Exit;
    End;
    If (K='REDIM')or(K='ERASE') Then Begin
      EmitRaw('{ '+K+' : ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw('}'); EmitLn; Exit;
    End;
    If K='STOP' Then Begin
      Inc(I);
      EmitRaw('Halt;'); EmitLn; Exit;
    End;
    If K='WITH' Then Begin
      EmitRaw('{ With ... End With non traduit }');
      EmitLn;
      { sauter jusqu a End With }
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
        If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') and (I+1<=TokCount) and
           (Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='WITH') Then Begin
          Inc(I,2); Break;
        End;
        Inc(I);
      End;
      Exit;
    End;
  End;
  { detection d appel : Debug.Print ... }
  If (Tokens[I].Kind=TK_IDENT) and StrEqualCI(Tokens[I].Val,'Debug') and
     (I+2<=TokCount) and (Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.') and
     (Tokens[I+2].Kind=TK_IDENT) and StrEqualCI(Tokens[I+2].Val,'Print') Then Begin
    Inc(I,3);
    EmitDebugPrint(I);
    EmitLn;
    Exit;
  End;
  { detection d appel MsgBox / InputBox }
  If (Tokens[I].Kind=TK_IDENT) and StrEqualCI(Tokens[I].Val,'MsgBox') Then Begin
    EmitRaw('{ MsgBox -> WriteLn } WriteLn(');
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(I);
    EmitExpr(I,True,True);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
    EmitRaw(');'); EmitLn; Exit;
  End;
  { affectation ou appel }
  If IsAssignment(I) Then Begin
    EmitAssign(I); EmitLn; Exit;
  End;
  { sinon : appel ou expression seule }
  If (Tokens[I].Kind=TK_IDENT) Then Begin
    J:=I;
    EmitExpr(I,True,False);
    EmitRaw(';'); EmitLn;
    Exit;
  End;
  { token inattendu : avancer }
  Inc(I);
End;

{ Emet une suite d instructions jusqu a un mot-cle dans StopSet
  ou jusqu a la fin. StopSet est de la forme ',KW1,KW2,'. }
Procedure EmitBlock(Var I:Integer; Const StopSet:TString);
Begin
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I>TokCount) or (Tokens[I].Kind=TK_EOF) Then Break;
    If IsBlockEnd(Tokens[I],StopSet) Then Break;
    EmitStmt(I);
  End;
End;

{ Saute une declaration Dim/Static (consomme jusqu a EOS sans rien emettre).
  Utilise quand on a deja hisse les Dim au debut de la procedure. }
Procedure SkipDimLike(Var I:Integer);
Begin
  Inc(I);
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
End;

{ Scanne le corps d une procedure VB depuis StartI jusqu au END SUB/FUNCTION
  matchant (sans le consommer) et emet une section var Pascal pour les Dim
  et Static rencontres. Les Dim a l interieur seront ensuite ignores
  pendant l emission du corps. }
Procedure HoistDims(StartI:Integer);
Var J:Integer; FirstVar:Boolean; Name,Typ:TString;
Begin
  J:=StartI;
  FirstVar:=True;
  While J<=TokCount do Begin
    If (Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='END') and
       (J+1<=TokCount) and (Tokens[J+1].Kind=TK_KEYWORD) and
       ((Tokens[J+1].Val='SUB')or(Tokens[J+1].Val='FUNCTION')) Then Break;
    If (Tokens[J].Kind=TK_EOF) Then Break;
    If (Tokens[J].Kind=TK_KEYWORD) and
       ((Tokens[J].Val='DIM')or(Tokens[J].Val='STATIC')) Then Begin
      Inc(J);
      While (J<=TokCount) and (Tokens[J].Kind<>TK_EOS) and (Tokens[J].Kind<>TK_EOF) do Begin
        If Tokens[J].Kind=TK_IDENT Then Begin
          Name:=Tokens[J].Val;
          Inc(J);
          Typ:='Variant';
          If (J<=TokCount)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='AS') Then Begin
            Inc(J);
            If (J<=TokCount)and((Tokens[J].Kind=TK_IDENT)or(Tokens[J].Kind=TK_KEYWORD)) Then Begin
              Typ:=MapVBType(Tokens[J].Val);
              Inc(J);
            End;
          End;
          If FirstVar Then Begin
            EmitRaw('var'); EmitLn;
            Inc(Indent);
            FirstVar:=False;
          End;
          EmitRaw(Name+': '+Typ+';'); EmitLn;
        End Else
        If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=',') Then Inc(J)
        Else Inc(J);
      End;
    End Else
      Inc(J);
  End;
  If Not FirstVar Then Dec(Indent);
End;

{ Emet une procedure ou fonction VB6.
  AsNested : true si emis a l interieur du programme principal. }
Procedure EmitProc(Var I:Integer);
Var IsFunc:Boolean; Name,Ret,PName,PType,Mode:TString;
    First:Boolean; FidxOld:Integer; ParCount:Integer;
Begin
  IsFunc:=Tokens[I].Val='FUNCTION';
  Inc(I);
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val; Inc(I);
  End Else Name:='Anonymous';
  FidxOld:=CurFunc;
  CurFunc:=FindFunc(Name);
  If IsFunc Then EmitRaw('function ') Else EmitRaw('procedure ');
  EmitRaw(Name);
  ParCount:=0;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    { si parens vides, ne pas les emettre (TP n accepte pas proc(); ) }
    If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val=')') Then Begin
      Inc(I,2);
    End Else Begin
    Inc(I);
    EmitRaw('(');
    First:=True;
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        Inc(I); Continue;
      End;
      Mode:='';
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BYVAL') Then Begin Inc(I); Mode:=''; End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BYREF') Then Begin Inc(I); Mode:='var '; End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OPTIONAL') Then Begin Inc(I); Mode:=''; End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        PName:=Tokens[I].Val; Inc(I);
        PType:='Variant';
        If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
          Inc(I);
          If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
            PType:=MapVBType(Tokens[I].Val); Inc(I);
          End;
        End;
        If Not First Then EmitRaw('; ');
        EmitRaw(Mode+PName+': '+PType);
        Inc(ParCount);
        First:=False;
      End Else Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
    EmitRaw(')');
    End; { sinon parens vides, on n a rien emis }
  End Else Begin
    EmitRaw('');
  End;
  Ret:='';
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
      Inc(I);
      If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
        Ret:=MapVBType(Tokens[I].Val); Inc(I);
      End;
    End;
    If Ret='' Then Ret:='Variant';
    EmitRaw(': '+Ret);
  End;
  EmitRaw(';');
  EmitLn;
  SkipEOS(I);
  HoistDims(I);
  EmitRaw('begin'); EmitLn;
  Inc(Indent);
  InProcBody:=True;
  EmitBlock(I,',END,');
  InProcBody:=False;
  { fin : End Sub / End Function }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='SUB')or(Tokens[I].Val='FUNCTION')) Then Inc(I);
  End;
  { en VB la valeur de retour est <Name> = expr ; en Pascal la traduction
    standard <Name> := expr a deja ete faite par EmitAssign comme une
    affectation ordinaire. Le compilateur Pascal acceptera cela car
    <Name> est le nom de la fonction. }
  Dec(Indent);
  EmitRaw('end;'); EmitLn; EmitLn;
  CurFunc:=FidxOld;
End;

{ Emet le programme entier }
Procedure EmitProgram;
Var I:Integer; K:TString; HasModuleDecl:Boolean;
Begin
  EmitRaw('{ Genere par VB2PAS '+VB2PAS_VERSION+' a partir de '+SrcName+' }');
  EmitLn;
  EmitRaw('program '+ProgName+';'); EmitLn;
  EmitLn;

  { 1ere passe : declarations module-level (Type, Const, Dim, Public/Private),
    en sautant Sub/Function/Property. On ignore l ordre relatif des sections
    pour rester simple. On accumule en sortie. }
  HasModuleDecl:=False;
  I:=1;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I>TokCount) or (Tokens[I].Kind=TK_EOF) Then Break;
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='SUB')or(K='FUNCTION')or(K='PROPERTY') Then Begin
        { sauter le bloc proc }
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') and (I+1<=TokCount) and
             (Tokens[I+1].Kind=TK_KEYWORD) and
             ((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')or(Tokens[I+1].Val='PROPERTY')) Then Begin
            Inc(I,2); Break;
          End;
          Inc(I);
        End;
        Continue;
      End;
      If ((K='PUBLIC')or(K='PRIVATE'))and(I+1<=TokCount)and
         (Tokens[I+1].Kind=TK_KEYWORD)and
         ((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')or(Tokens[I+1].Val='PROPERTY')) Then Begin
        { sauter de meme }
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') and (I+1<=TokCount) and
             (Tokens[I+1].Kind=TK_KEYWORD) and
             ((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')or(Tokens[I+1].Val='PROPERTY')) Then Begin
            Inc(I,2); Break;
          End;
          Inc(I);
        End;
        Continue;
      End;
      If (K='DIM')or(K='STATIC')or(K='PUBLIC')or(K='PRIVATE') Then Begin
        EmitDimLike(I); EmitLn; HasModuleDecl:=True; Continue;
      End;
      If K='CONST' Then Begin EmitConstDecl(I); EmitLn; HasModuleDecl:=True; Continue; End;
      If K='TYPE' Then Begin EmitType(I); HasModuleDecl:=True; Continue; End;
      If K='OPTION' Then Begin
        EmitRaw('{ Option ');
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
          EmitRaw(Tokens[I].Val+' '); Inc(I);
        End;
        EmitRaw('}'); EmitLn; Continue;
      End;
      If K='ATTRIBUTE' Then Begin
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
        Continue;
      End;
    End;
    Inc(I);
  End;
  If HasModuleDecl Then EmitLn;

  { 2eme passe : Subs et Functions (Public/Private optionnel) }
  I:=1;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I>TokCount) or (Tokens[I].Kind=TK_EOF) Then Break;
    If (Tokens[I].Kind=TK_KEYWORD) and ((Tokens[I].Val='PUBLIC')or(Tokens[I].Val='PRIVATE')) Then Begin
      If (I+1<=TokCount) and (Tokens[I+1].Kind=TK_KEYWORD) and
         ((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')) Then Inc(I);
    End;
    If (Tokens[I].Kind=TK_KEYWORD) and ((Tokens[I].Val='SUB')or(Tokens[I].Val='FUNCTION')) Then Begin
      EmitProc(I);
    End Else
      Inc(I);
  End;

  { Programme principal }
  EmitRaw('begin'); EmitLn;
  Inc(Indent);
  If HasMain Then EmitRaw('Main;')
  Else If FuncCount>0 Then EmitRaw('{ pas de Sub Main : ajouter ici l appel approprie }')
  Else EmitRaw('{ module sans procedure }');
  EmitLn;
  Dec(Indent);
  EmitRaw('end.'); EmitLn;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('VB2PAS ',VB2PAS_VERSION,' - Transpilateur Visual Basic 6 vers Turbo Pascal');
  WriteLn;
  WriteLn('Syntaxe : VB2PAS [-v] source.bas [destination.pas]');
  WriteLn;
  WriteLn('  source.bas      Fichier source Visual Basic 6 (.bas).');
  WriteLn('  destination.pas Fichier Pascal a generer (defaut : source.pas).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : VB2PAS hello.bas hello.pas');
End;

Procedure ParseArgs;
Var I:Integer; A:TString;
Begin
  Verbose:=False;
  SrcName:='';
  DstName:='';
  For I:=1 to ParamCount do Begin
    A:=ParamStr(I);
    If (A='-h')or(A='--help')or(A='/?')or(A='/h')or(A='/H') Then Begin
      ShowUsage; Halt(EXIT_OK);
    End Else
    If (A='-v')or(A='--verbose') Then Verbose:=True
    Else If SrcName='' Then SrcName:=A
    Else If DstName='' Then DstName:=A;
  End;
  If SrcName='' Then Begin ShowUsage; Halt(EXIT_USAGE); End;
  If DstName='' Then Begin
    A:=SrcName;
    I:=Length(A);
    While (I>0)and(A[I]<>'.')and(A[I]<>'\')and(A[I]<>'/') do Dec(I);
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.pas'
                          Else DstName:=A+'.pas';
  End;
End;

BEGIN
  ErrorCount:=0;
  ParseArgs;
  If Verbose Then WriteLn('VB2PAS : tokenisation de ',SrcName,'...');
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('VB2PAS : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('VB2PAS : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('VB2PAS : module = ',ProgName);
    WriteLn('VB2PAS : ',FuncCount,' Sub/Function.');
    If HasMain Then WriteLn('VB2PAS : Sub Main detecte.');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('VB2PAS : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;
  OutLine:=''; OutCol:=0; Indent:=0; CurFunc:=0;
  EmitProgram;
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('VB2PAS : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
