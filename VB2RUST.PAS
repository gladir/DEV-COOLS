{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Visual Basic 6 vers le langage Rust
}

(* ============================================================
   VB2RUST.PAS - Transpilateur Visual Basic 6 vers Rust
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Rust 2021 (rustc 1.56+)

   Couvre les constructions courantes de VB6 :
     Sub / Function ... End Sub / End Function -> fn ... [-> T]
     Dim / Static / Public / Private -> let mut
     Const x As T = v -> const X: T = v;
     If..Then..ElseIf..Else..End If -> if ... else if ... else
     Select Case..End Select -> match
     For x = a To b [Step s] ... Next -> for x in a..=b
     Do / Loop While|Until / While..Wend -> while / loop+break
     Exit Sub|Function -> return
     Type..End Type -> struct
     Debug.Print -> println!
     MsgBox -> println! (commente)
     Operateurs : = contextuel (= ou ==), <> -> !=, \ -> /,
                  Mod -> %, & -> + (concat), And/Or/Not/Xor.

   Limitations :
     - VB6 est insensible a la casse ; le sens d emploi de '='
       (affectation vs egalite) est determine par contexte simple.
     - Les constructions COM/UserForms/With ne sont pas converties.
     - Variant/Object/Currency sont approximes.
     - On Error / GoSub / Property sont signales en commentaire.
     - Le typage strict de Rust peut requerir des ajustements
       manuels (casts, durees de vie).
   ============================================================ *)

Program VB2RUST;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Const
  VB2RUST_VERSION = '1.0';
  VB2RUST_DATE    = '2026-04-28';

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
    RetType   : TString;     { type Rust de retour ('' si Sub) }
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

Function StrLower(S:TString):TString;
Var I:Integer;
Begin
  For I:=1 to Length(S) do
    If S[I] in ['A'..'Z'] Then S[I]:=Chr(Ord(S[I])+32);
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
  TOKENISEUR (identique a VB2PAS.PAS)
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
    WriteLn('VB2RUST : trop de tokens (>',MAX_TOKEN,')');
    Halt(EXIT_ERROR);
  End;
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
    (U='IN')or(U='STOP');
End;

Procedure ScanString;
Var S:TString; Ch:Char;
Begin
  S:='"';
  Repeat
    Ch:=NextCh;
    If (Ch=#0)or(Ch=#10) Then Begin
      WriteLn('VB2RUST : chaine non terminee ligne ',SrcLineNo);
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
  Ch:=PeekCh;
  If Ch in ['%','&','!','#','@','$'] Then NextCh;
  If StrEqualCI(S,'REM') Then Begin
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
      ' ',#9,#13: ;
      #10: AddTok(TK_EOS,'');
      '_':Begin
        Ch2:=PeekCh;
        If (Ch2=' ')or(Ch2=#9)or(Ch2=#10)or(Ch2=#13) Then Begin
          While (Ch2=' ')or(Ch2=#9)or(Ch2=#13) do Begin NextCh; Ch2:=PeekCh; End;
          If Ch2=#10 Then NextCh;
        End Else Begin
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
        If Ch2='=' Then Begin NextCh; AddTok(TK_OP,':='); End
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
    End;
  Until SrcEOF and (Not HasPending);
  AddTok(TK_EOS,'');
  AddTok(TK_EOF,'');
End;

{ ============================================================
  MAPPAGES VB6 -> RUST
  ============================================================ }
Function MapVBType(T:TString):TString;
Var U:TString;
Begin
  U:=StrUpper(T);
  If U='INTEGER' Then MapVBType:='i16' Else
  If U='LONG' Then MapVBType:='i32' Else
  If U='SINGLE' Then MapVBType:='f32' Else
  If U='DOUBLE' Then MapVBType:='f64' Else
  If U='STRING' Then MapVBType:='String' Else
  If U='BOOLEAN' Then MapVBType:='bool' Else
  If U='BYTE' Then MapVBType:='u8' Else
  If U='CURRENCY' Then MapVBType:='f64' Else
  If U='DATE' Then MapVBType:='f64' Else
  If U='VARIANT' Then MapVBType:='String' Else
  If U='OBJECT' Then MapVBType:='Box<dyn std::any::Any>' Else
  If U='ANY' Then MapVBType:='Box<dyn std::any::Any>' Else
  MapVBType:=T;
End;

{ Valeur initiale par defaut Rust pour un type donne. }
Function DefaultValueFor(T:TString):TString;
Begin
  If T='String' Then DefaultValueFor:='String::new()' Else
  If T='bool' Then DefaultValueFor:='false' Else
  If T='f32' Then DefaultValueFor:='0.0_f32' Else
  If T='f64' Then DefaultValueFor:='0.0_f64' Else
  If (T='i16')or(T='i32')or(T='u8') Then DefaultValueFor:='0'
  Else DefaultValueFor:='Default::default()';
End;

Function MapVBKeyword(K:TString):TString;
Begin
  If K='AND' Then MapVBKeyword:='&&' Else
  If K='OR'  Then MapVBKeyword:='||' Else
  If K='NOT' Then MapVBKeyword:='!' Else
  If K='XOR' Then MapVBKeyword:='^' Else
  If K='MOD' Then MapVBKeyword:='%' Else
  If K='TRUE' Then MapVBKeyword:='true' Else
  If K='FALSE' Then MapVBKeyword:='false' Else
  If K='NOTHING' Then MapVBKeyword:='None' Else
  If K='NULL' Then MapVBKeyword:='None' Else
  If K='EMPTY' Then MapVBKeyword:='None' Else
  If K='ME' Then MapVBKeyword:='self' Else
  If K='IS' Then MapVBKeyword:='==' Else
  If K='EQV' Then MapVBKeyword:='==' Else
  If K='IMP' Then MapVBKeyword:='<=' Else
  If K='LIKE' Then MapVBKeyword:='=='
  Else MapVBKeyword:=K;
End;

Function MapVBOperator(Op:TString):TString;
Begin
  If Op='\' Then MapVBOperator:='/' Else
  If Op='&' Then MapVBOperator:='+' Else
  If Op='<>' Then MapVBOperator:='!=' Else
  If Op='^' Then MapVBOperator:='/* ^ */' Else
  MapVBOperator:=Op;
End;

{ Conversion d une chaine VB6 "abc""def" en chaine Rust "abc\"def". }
Function VBStringToRust(S:TString):TString;
Var I:Integer; R:TString;
Begin
  R:='';
  I:=2;
  While I<Length(S) do Begin
    If (S[I]='"')and(I<Length(S))and(S[I+1]='"') Then Begin
      R:=R+'\"'; Inc(I,2);
    End Else
    If S[I]='\' Then Begin
      R:=R+'\\'; Inc(I);
    End Else Begin
      R:=R+S[I]; Inc(I);
    End;
  End;
  VBStringToRust:='"'+R+'"';
End;

{ Conversion d un nombre VB &H1A ou &O17 en litteral Rust 0x1a / 0o17 / 0b... }
Function VBIntToRust(S:TString):TString;
Var Body:TString;
Begin
  If (Length(S)>=2)and(S[1]='&') Then Begin
    Body:=Copy(S,3,Length(S)-2);
    If (Length(S)>=2)and(Upcase(S[2])='H') Then VBIntToRust:='0x'+Body Else
    If (Length(S)>=2)and(Upcase(S[2])='O') Then VBIntToRust:='0o'+Body Else
    If (Length(S)>=2)and(Upcase(S[2])='B') Then VBIntToRust:='0b'+Body Else
    VBIntToRust:=S;
  End Else
    VBIntToRust:=S;
End;

{ ============================================================
  ANALYSEUR
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
  ProgName:='vb_program';
  FuncCount:=0;
  HasMain:=False;
  I:=1;
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='ATTRIBUTE') and (I+2<=TokCount) Then Begin
        If (Tokens[I+1].Kind=TK_IDENT)and StrEqualCI(Tokens[I+1].Val,'VB_Name') Then Begin
          J:=I+2;
          While (J<=TokCount) and (Tokens[J].Kind<>TK_STRING) and (Tokens[J].Kind<>TK_EOS) do Inc(J);
          If (J<=TokCount) and (Tokens[J].Kind=TK_STRING) Then Begin
            ProgName:=StrLower(Copy(Tokens[J].Val,2,Length(Tokens[J].Val)-2));
          End;
        End;
      End Else
      If ((K='SUB')or(K='FUNCTION')) and (I<TokCount) Then Begin
        J:=I+1;
        If (J<=TokCount) and (Tokens[J].Kind=TK_IDENT) Then Begin
          Ret:='';
          If K='FUNCTION' Then Begin
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
            If Ret='' Then Ret:='String';
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
        For OutCol:=1 to Indent*4 do OutLine:=OutLine+' ';
        OutCol:=Indent*4;
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

Procedure SkipEOS(Var I:Integer);
Begin
  While (I<=TokCount) and (Tokens[I].Kind=TK_EOS) do Inc(I);
End;

{ Forward declarations }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure SkipDimLike(Var I:Integer); Forward;
Procedure EmitBlock(Var I:Integer; Const StopSet:TString); Forward;
Procedure EmitExpr(Var I:Integer; StopAtEOS,StopAtComma:Boolean); Forward;

Function IsBlockEnd(Const T:TToken; Const StopSet:TString):Boolean;
Var U:TString;
Begin
  IsBlockEnd:=False;
  If T.Kind<>TK_KEYWORD Then Exit;
  U:=','+T.Val+',';
  IsBlockEnd:=Pos(U,StopSet)>0;
End;

{ Emet une expression VB6 jusqu a EOS / mot-cle structurant. }
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
      If (Tokens[I].Kind=TK_OP) Then EmitSpace
      Else If (Tokens[I].Kind=TK_KEYWORD) Then EmitSpace
      Else If (Tokens[I].Kind=TK_IDENT) Then Begin
        If (I>1)and((Tokens[I-1].Kind=TK_IDENT)or(Tokens[I-1].Kind=TK_KEYWORD)or
                    (Tokens[I-1].Kind=TK_INTEGER)or(Tokens[I-1].Kind=TK_REAL)or
                    (Tokens[I-1].Kind=TK_STRING)) Then EmitSpace;
      End;
    End;
    First:=False;
    Case Tokens[I].Kind of
      TK_INTEGER:EmitRaw(VBIntToRust(Tokens[I].Val));
      TK_REAL   :EmitRaw(Tokens[I].Val);
      TK_STRING :EmitRaw(VBStringToRust(Tokens[I].Val)+'.to_string()');
      TK_IDENT  :EmitRaw(Tokens[I].Val);
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        EmitRaw(MapVBKeyword(K));
      End;
      TK_OP:Begin
        If Tokens[I].Val='=' Then EmitRaw('==')
        Else If Tokens[I].Val=':=' Then EmitRaw('=')
        Else If (Tokens[I].Val='\')or(Tokens[I].Val='&')or(Tokens[I].Val='<>') Then Begin
          EmitSpace; EmitRaw(MapVBOperator(Tokens[I].Val)); EmitSpace;
        End
        Else If Tokens[I].Val='^' Then EmitRaw(' /* ^ */ ')
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

{ Emet une affectation : <lhs> = <rhs> -> <lhs> = <rhs>; (Rust) }
Procedure EmitAssign(Var I:Integer);
Var First:Boolean;
Begin
  First:=True;
  While (I<=TokCount) and Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) and
        (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If Not First Then EmitSpace;
    First:=False;
    Case Tokens[I].Kind of
      TK_IDENT  :EmitRaw(Tokens[I].Val);
      TK_KEYWORD:EmitRaw(MapVBKeyword(Tokens[I].Val));
      TK_INTEGER:EmitRaw(VBIntToRust(Tokens[I].Val));
      TK_STRING :EmitRaw(VBStringToRust(Tokens[I].Val)+'.to_string()');
    Else
      EmitRaw(Tokens[I].Val);
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
    EmitRaw(' = ');
    Inc(I);
  End;
  EmitExpr(I,True,False);
  EmitRaw(';');
End;

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

{ Emet une declaration Dim/Static au niveau procedure : let mut x: T = ...; }
Procedure EmitDimLike(Var I:Integer);
Var Name,Typ:TString;
Begin
  Inc(I); { sauter le mot-cle Dim/Static/etc. }
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If Tokens[I].Kind=TK_IDENT Then Begin
      Name:=Tokens[I].Val;
      Inc(I);
      Typ:='String';
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
        Inc(I);
        If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
          Typ:=MapVBType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      EmitRaw('let mut '+Name+': '+Typ+' = '+DefaultValueFor(Typ)+';');
      EmitLn;
    End Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
    Else Inc(I);
  End;
End;

{ Saute Dim/Static (consomme jusqu a EOS sans rien emettre). }
Procedure SkipDimLike(Var I:Integer);
Begin
  Inc(I);
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
End;

{ Emet une declaration Const : Const X As T = expr -> const X: T = expr; }
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
    If Typ<>'' Then EmitRaw(': '+Typ) Else EmitRaw(': i32');
    EmitRaw(' = ');
    EmitExpr(I,True,False);
    EmitRaw(';');
  End;
End;

Procedure EmitIf(Var I:Integer);
Begin
  Inc(I); { IF }
  EmitRaw('if ');
  EmitExpr(I,False,False);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitRaw(' {');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind<>TK_EOS) Then Begin
    { forme inline }
    EmitStmt(I);
    Dec(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
      Inc(I);
      EmitRaw('} else {');
      EmitLn;
      Inc(Indent);
      EmitStmt(I);
      Dec(Indent);
    End;
    EmitRaw('}');
    EmitLn;
    Exit;
  End;
  SkipEOS(I);
  EmitBlock(I,',ELSE,ELSEIF,END,');
  Dec(Indent);
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSEIF') do Begin
    Inc(I);
    EmitRaw('} else if ');
    EmitExpr(I,False,False);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
    EmitRaw(' {');
    EmitLn;
    Inc(Indent);
    SkipEOS(I);
    EmitBlock(I,',ELSE,ELSEIF,END,');
    Dec(Indent);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
    Inc(I);
    EmitRaw('} else {');
    EmitLn;
    Inc(Indent);
    SkipEOS(I);
    EmitBlock(I,',END,');
    Dec(Indent);
  End;
  EmitRaw('}');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='IF') Then Inc(I);
  End;
End;

{ Emet For X = A To B [Step S] ... Next [X] -> for X in A..=B (corps) }
Procedure EmitFor(Var I:Integer);
Var VarName:TString; HasStep:Boolean;
Begin
  Inc(I); { FOR }
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    VarName:=Tokens[I].Val;
    Inc(I);
  End Else VarName:='i';
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I);
  EmitRaw('for '+VarName+' in ');
  EmitExpr(I,True,False);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Begin
    Inc(I);
    EmitRaw('..=');
    EmitExpr(I,True,False);
  End;
  HasStep:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STEP') Then Begin
    Inc(I);
    HasStep:=True;
    EmitRaw(' /* step ');
    While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
      EmitRaw(Tokens[I].Val); Inc(I);
    End;
    EmitRaw(' : ajuster a la main */');
  End;
  EmitRaw(' {');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',NEXT,');
  Dec(Indent);
  EmitRaw('}');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='NEXT') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Inc(I);
  End;
End;

Procedure EmitWhile(Var I:Integer);
Begin
  Inc(I); { WHILE }
  EmitRaw('while ');
  EmitExpr(I,True,False);
  EmitRaw(' {');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',WEND,');
  Dec(Indent);
  EmitRaw('}');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WEND') Then Inc(I);
End;

{ Do [While|Until cond] ... Loop [While|Until cond] -> while/loop+break }
Procedure EmitDo(Var I:Integer);
Var TopWhile,TopUntil:Boolean;
Begin
  Inc(I); { DO }
  TopWhile:=False;
  TopUntil:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WHILE') Then Begin
    Inc(I);
    TopWhile:=True;
    EmitRaw('while ');
    EmitExpr(I,True,False);
    EmitRaw(' {');
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Begin
    Inc(I);
    TopUntil:=True;
    EmitRaw('while !(');
    EmitExpr(I,True,False);
    EmitRaw(') {');
  End Else Begin
    EmitRaw('loop {');
  End;
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  EmitBlock(I,',LOOP,');
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='LOOP') Then Inc(I);
  If TopWhile or TopUntil Then Begin
    Dec(Indent);
    EmitRaw('}'); EmitLn;
    { eventuel "While|Until cond" au pied : ignorer }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='WHILE')or(Tokens[I].Val='UNTIL')) Then Begin
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
    End;
  End Else Begin
    (* loop ... if !(cond) break pour Until ou !(cond) pour While *)
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Begin
      Inc(I);
      EmitRaw('if ');
      EmitExpr(I,True,False);
      EmitRaw(' { break; }'); EmitLn;
    End Else
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='WHILE') Then Begin
      Inc(I);
      EmitRaw('if !(');
      EmitExpr(I,True,False);
      EmitRaw(') { break; }'); EmitLn;
    End;
    Dec(Indent);
    EmitRaw('}'); EmitLn;
  End;
End;

{ Select Case <e> ... Case <list> ... Case Else ... End Select -> match <e> (bras) }
Procedure EmitSelect(Var I:Integer);
Begin
  Inc(I); { SELECT }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CASE') Then Inc(I);
  EmitRaw('match ');
  EmitExpr(I,True,False);
  EmitRaw(' {');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Break;
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CASE') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
        Inc(I);
        EmitRaw('_ => {');
        EmitLn;
        Inc(Indent);
        SkipEOS(I);
        EmitBlock(I,',END,CASE,');
        Dec(Indent);
        EmitRaw('}'); EmitLn;
      End Else Begin
        EmitExpr(I,True,False);
        EmitRaw(' => {');
        EmitLn;
        Inc(Indent);
        SkipEOS(I);
        EmitBlock(I,',END,CASE,');
        Dec(Indent);
        EmitRaw('}'); EmitLn;
      End;
    End Else Inc(I);
  End;
  Dec(Indent);
  EmitRaw('}');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='SELECT') Then Inc(I);
  End;
End;

{ Type ... End Type -> struct Name (champs) }
Procedure EmitType(Var I:Integer);
Var Name,FName,FType:TString;
Begin
  Inc(I); { TYPE }
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    Inc(I);
  End Else Name:='Unknown';
  EmitRaw('#[derive(Default, Clone)]'); EmitLn;
  EmitRaw('struct '+Name+' {');
  EmitLn;
  Inc(Indent);
  SkipEOS(I);
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Break;
    If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
      FName:=Tokens[I].Val;
      Inc(I);
      FType:='String';
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
        Inc(I);
        If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
          FType:=MapVBType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      EmitRaw(FName+': '+FType+',');
      EmitLn;
    End Else Inc(I);
  End;
  Dec(Indent);
  EmitRaw('}'); EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TYPE') Then Inc(I);
  End;
End;

(* Debug.Print arg [, arg ...] -> println avec format "(placeholder) (placeholder) ...", a, b, ... *)
Procedure EmitDebugPrint(Var I:Integer);
Var Args:Array[1..32] of Integer; Ends:Array[1..32] of Integer;
    NbArgs,K:Integer; J,Depth:Integer;
Begin
  NbArgs:=0;
  { capturer chaque argument (debut/fin) }
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
    If NbArgs>=32 Then Break;
    Inc(NbArgs);
    Args[NbArgs]:=I;
    Depth:=0;
    J:=I;
    While J<=TokCount do Begin
      If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and
         ((Tokens[J].Val=',')or(Tokens[J].Val=';')) Then Break;
      If (Depth=0)and(Tokens[J].Kind=TK_EOS) Then Break;
      If (Depth=0)and(Tokens[J].Kind=TK_EOF) Then Break;
      If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
      If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
      Inc(J);
    End;
    Ends[NbArgs]:=J;
    I:=J;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and
       ((Tokens[I].Val=',')or(Tokens[I].Val=';')) Then Inc(I);
  End;
  If NbArgs=0 Then Begin
    EmitRaw('println!();');
    Exit;
  End;
  EmitRaw('println!("');
  For K:=1 to NbArgs do Begin
    If K>1 Then EmitRaw(' ');
    EmitRaw('{}');
  End;
  EmitRaw('"');
  For K:=1 to NbArgs do Begin
    EmitRaw(', ');
    J:=Args[K];
    While J<Ends[K] do Begin
      Case Tokens[J].Kind of
        TK_INTEGER:EmitRaw(VBIntToRust(Tokens[J].Val));
        TK_REAL   :EmitRaw(Tokens[J].Val);
        TK_STRING :EmitRaw(VBStringToRust(Tokens[J].Val));
        TK_IDENT  :EmitRaw(Tokens[J].Val);
        TK_KEYWORD:EmitRaw(MapVBKeyword(Tokens[J].Val));
        TK_OP     :Begin
          If Tokens[J].Val='=' Then EmitRaw('==')
          Else If (Tokens[J].Val='\') Then EmitRaw(' / ')
          Else If (Tokens[J].Val='&') Then EmitRaw(' + ')
          Else If (Tokens[J].Val='<>') Then EmitRaw(' != ')
          Else EmitRaw(Tokens[J].Val);
        End;
        TK_PUNCT:EmitRaw(Tokens[J].Val);
      End;
      Inc(J);
    End;
  End;
  EmitRaw(');');
End;

{ Emet une instruction unique. Avance I. }
Procedure EmitStmt(Var I:Integer);
Var K:TString;
Begin
  SkipEOS(I);
  If (I>TokCount)or(Tokens[I].Kind=TK_EOF) Then Exit;
  If Tokens[I].Kind=TK_KEYWORD Then Begin
    K:=Tokens[I].Val;
    If (K='DIM')or(K='STATIC')or
       ((K='PUBLIC')or(K='PRIVATE')) and (I+1<=TokCount) and
       Not((Tokens[I+1].Kind=TK_KEYWORD)and((Tokens[I+1].Val='SUB')or(Tokens[I+1].Val='FUNCTION')or(Tokens[I+1].Val='TYPE')or(Tokens[I+1].Val='CONST')))
    Then Begin
      EmitDimLike(I);
      Exit;
    End;
    If (K='PUBLIC')or(K='PRIVATE') Then Begin
      Inc(I); { mot-cle de portee }
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
      Inc(I);
      If IsAssignment(I) Then EmitAssign(I)
      Else Begin EmitExpr(I,True,False); EmitRaw(';'); End;
      EmitLn; Exit;
    End;
    If K='CALL' Then Begin
      Inc(I);
      EmitExpr(I,True,False);
      EmitRaw(';'); EmitLn; Exit;
    End;
    If K='EXIT' Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD) Then Inc(I);
      EmitRaw('return;'); EmitLn; Exit;
    End;
    If K='RETURN' Then Begin
      Inc(I);
      EmitRaw('return;'); EmitLn; Exit;
    End;
    If K='GOTO' Then Begin
      EmitRaw('/* GOTO non traduit en Rust : ');
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin EmitRaw(Tokens[I].Val); Inc(I); End;
      EmitRaw(' */'); EmitLn; Exit;
    End;
    If K='ON' Then Begin
      EmitRaw('/* On Error/Goto non traduit : ');
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw('*/'); EmitLn; Exit;
    End;
    If K='OPTION' Then Begin
      EmitRaw('// Option ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitLn; Exit;
    End;
    If K='ATTRIBUTE' Then Begin
      EmitRaw('// Attribute ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitLn; Exit;
    End;
    If (K='REDIM')or(K='ERASE') Then Begin
      EmitRaw('/* '+K+' : ');
      Inc(I);
      While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
        EmitRaw(Tokens[I].Val+' '); Inc(I);
      End;
      EmitRaw('*/'); EmitLn; Exit;
    End;
    If K='STOP' Then Begin
      Inc(I);
      EmitRaw('std::process::exit(0);'); EmitLn; Exit;
    End;
    If K='WITH' Then Begin
      EmitRaw('/* With ... End With non traduit */'); EmitLn;
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
  { Debug.Print ... }
  If (Tokens[I].Kind=TK_IDENT) and StrEqualCI(Tokens[I].Val,'Debug') and
     (I+2<=TokCount) and (Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='.') and
     (Tokens[I+2].Kind=TK_IDENT) and StrEqualCI(Tokens[I+2].Val,'Print') Then Begin
    Inc(I,3);
    EmitDebugPrint(I);
    EmitLn;
    Exit;
  End;
  { MsgBox ... }
  If (Tokens[I].Kind=TK_IDENT) and StrEqualCI(Tokens[I].Val,'MsgBox') Then Begin
    EmitRaw('/* MsgBox -> println! */ println!("{}", ');
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
  If (Tokens[I].Kind=TK_IDENT) Then Begin
    EmitExpr(I,True,False);
    EmitRaw(';'); EmitLn;
    Exit;
  End;
  Inc(I);
End;

Procedure EmitBlock(Var I:Integer; Const StopSet:TString);
Begin
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I>TokCount) or (Tokens[I].Kind=TK_EOF) Then Break;
    If IsBlockEnd(Tokens[I],StopSet) Then Break;
    EmitStmt(I);
  End;
End;

{ Emet une procedure ou fonction VB6 -> fn ... (corps) }
Procedure EmitProc(Var I:Integer);
Var IsFunc:Boolean; Name,Ret,PName,PType,Mode,FnName:TString;
    First:Boolean; FidxOld:Integer;
Begin
  IsFunc:=Tokens[I].Val='FUNCTION';
  Inc(I);
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val; Inc(I);
  End Else Name:='anonymous';
  FidxOld:=CurFunc;
  CurFunc:=FindFunc(Name);
  FnName:=Name;
  { Sub Main devient fn main, autres sub/function gardent leur nom }
  If StrEqualCI(Name,'Main') Then FnName:='main';
  EmitRaw('fn '+FnName+'(');
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    First:=True;
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        Inc(I); Continue;
      End;
      Mode:='';
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BYVAL') Then Begin Inc(I); Mode:='mut '; End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BYREF') Then Begin Inc(I); Mode:='&mut '; End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OPTIONAL') Then Begin Inc(I); Mode:='mut '; End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        PName:=Tokens[I].Val; Inc(I);
        PType:='String';
        If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
          Inc(I);
          If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
            PType:=MapVBType(Tokens[I].Val); Inc(I);
          End;
        End;
        If Not First Then EmitRaw(', ');
        EmitRaw(Mode+PName+': '+PType);
        First:=False;
      End Else Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End;
  EmitRaw(')');
  Ret:='';
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='AS') Then Begin
      Inc(I);
      If (I<=TokCount)and((Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_KEYWORD)) Then Begin
        Ret:=MapVBType(Tokens[I].Val); Inc(I);
      End;
    End;
    If Ret='' Then Ret:='String';
    EmitRaw(' -> '+Ret);
  End;
  EmitRaw(' {'); EmitLn;
  Inc(Indent);
  { Pour les fonctions VB6, declarer une variable du nom de la fonction
    et la retourner en fin de bloc, car en VB6 on ecrit Name = expr. }
  If IsFunc Then Begin
    EmitRaw('let mut '+Name+': '+Ret+' = '+DefaultValueFor(Ret)+';');
    EmitLn;
  End;
  SkipEOS(I);
  InProcBody:=True;
  EmitBlock(I,',END,');
  InProcBody:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='SUB')or(Tokens[I].Val='FUNCTION')) Then Inc(I);
  End;
  If IsFunc Then Begin
    EmitRaw('return '+Name+';'); EmitLn;
  End;
  Dec(Indent);
  EmitRaw('}'); EmitLn; EmitLn;
  CurFunc:=FidxOld;
End;

{ Emet le programme entier }
Procedure EmitProgram;
Var I:Integer; K:TString; HasModuleDecl:Boolean;
Begin
  EmitRaw('// Genere par VB2RUST '+VB2RUST_VERSION+' a partir de '+SrcName);
  EmitLn;
  EmitRaw('// Module : '+ProgName); EmitLn;
  EmitRaw('#![allow(non_snake_case)]'); EmitLn;
  EmitRaw('#![allow(non_camel_case_types)]'); EmitLn;
  EmitRaw('#![allow(unused_mut)]'); EmitLn;
  EmitRaw('#![allow(unused_variables)]'); EmitLn;
  EmitRaw('#![allow(dead_code)]'); EmitLn;
  EmitRaw('#![allow(unused_assignments)]'); EmitLn;
  EmitLn;

  HasModuleDecl:=False;
  { 1ere passe : declarations module-level (Type, Const), en sautant Sub/Function. }
  I:=1;
  While (I<=TokCount) and (Tokens[I].Kind<>TK_EOF) do Begin
    SkipEOS(I);
    If (I>TokCount) or (Tokens[I].Kind=TK_EOF) Then Break;
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='SUB')or(K='FUNCTION')or(K='PROPERTY') Then Begin
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
      If K='CONST' Then Begin EmitConstDecl(I); EmitLn; HasModuleDecl:=True; Continue; End;
      If K='TYPE' Then Begin EmitType(I); EmitLn; HasModuleDecl:=True; Continue; End;
      If K='OPTION' Then Begin
        EmitRaw('// Option ');
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
          EmitRaw(Tokens[I].Val+' '); Inc(I);
        End;
        EmitLn; Continue;
      End;
      If K='ATTRIBUTE' Then Begin
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Inc(I);
        Continue;
      End;
      If (K='DIM')or(K='STATIC')or(K='PUBLIC')or(K='PRIVATE') Then Begin
        { variables globales : signalees en commentaire ; usage Rust : static mut }
        EmitRaw('/* variable module-level (gerer manuellement en Rust) : ');
        Inc(I);
        While (I<=TokCount) and (Tokens[I].Kind<>TK_EOS) and (Tokens[I].Kind<>TK_EOF) do Begin
          EmitRaw(Tokens[I].Val+' '); Inc(I);
        End;
        EmitRaw('*/'); EmitLn; HasModuleDecl:=True; Continue;
      End;
    End;
    Inc(I);
  End;
  If HasModuleDecl Then EmitLn;

  { 2eme passe : Subs et Functions }
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

  { Si pas de Sub Main, generer un main() qui ne fait rien (ou appelle la
    seule procedure du module si elle existe). }
  If Not HasMain Then Begin
    EmitRaw('fn main() {'); EmitLn;
    Inc(Indent);
    EmitRaw('// Pas de Sub Main detecte dans le module VB6 d origine.'); EmitLn;
    Dec(Indent);
    EmitRaw('}'); EmitLn;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('VB2RUST ',VB2RUST_VERSION,' - Transpilateur Visual Basic 6 vers Rust');
  WriteLn;
  WriteLn('Syntaxe : VB2RUST [-v] source.bas [destination.rs]');
  WriteLn;
  WriteLn('  source.bas      Fichier source Visual Basic 6 (.bas).');
  WriteLn('  destination.rs  Fichier Rust a generer (defaut : source.rs).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : VB2RUST hello.bas hello.rs');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.rs'
                          Else DstName:=A+'.rs';
  End;
End;

BEGIN
  ErrorCount:=0;
  ParseArgs;
  If Verbose Then WriteLn('VB2RUST : tokenisation de ',SrcName,'...');
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('VB2RUST : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('VB2RUST : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('VB2RUST : module = ',ProgName);
    WriteLn('VB2RUST : ',FuncCount,' Sub/Function.');
    If HasMain Then WriteLn('VB2RUST : Sub Main detecte.');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('VB2RUST : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;
  OutLine:=''; OutCol:=0; Indent:=0; CurFunc:=0;
  EmitProgram;
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('VB2RUST : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
