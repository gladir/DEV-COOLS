{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Turbo Pascal vers PL/I (.pli)
}

(* ============================================================
   PAS2PLI.PAS - Transpilateur Turbo Pascal vers PL/I (PL/1)
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source PL/I ANSI (.pli)

   Couvre les constructions courantes :
     PROGRAM/UNIT -> name: PROCEDURE OPTIONS(MAIN); ... END name;
     USES (commente),
     CONST   -> DCL ... INIT(...);
     TYPE record -> DCL 1 Name, 2 field type, ...;
     VAR     -> DECLARE name type;
     PROCEDURE -> name: PROCEDURE(args); ... END name;
     FUNCTION  -> name: PROCEDURE(args) RETURNS(type);
                  l'assignation au nom de fonction est traduite
                  en RETURN(expr); par EmitStmt.
     BEGIN..END   -> DO; ... END;
     IF..THEN..ELSE (avec blocs DO; ... END;),
     WHILE..DO    -> DO WHILE(cond); ... END;
     REPEAT..UNTIL-> DO UNTIL(cond); ... END;
     FOR..TO/DOWNTO..DO -> DO i = a TO b [BY -1]; ... END;
     CASE..OF     -> SELECT(expr); WHEN(v) ...; OTHERWISE ...; END;
     Write/WriteLn -> PUT LIST(...) / PUT SKIP LIST(...);
     Read/ReadLn   -> GET LIST(...) / GET SKIP LIST(...);
     operateurs Pascal -> PL/I (:= -> =, <> -> ^=,
       DIV/MOD -> /,MOD; AND/OR/NOT/XOR -> mots-cles PL/I).
     concatenation '+' sur chaine -> '||'.

   Limitations connues (signalees en commentaires /* ... */ dans
   la sortie quand applicable) :
     - les unites utilisateurs sont signalees en commentaire.
     - les pointeurs Pascal sont approximes par POINTER PL/I.
     - le typage exact des constantes Pascal n'est pas inferre ;
       on emet un type generique (FIXED ou FLOAT) selon le litteral.
   ============================================================ *)

Program PAS2PLI;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PAS2PLI_VERSION = '1.0';
  PAS2PLI_DATE    = '2026-04-27';

  MAX_STR     = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_TOKEN   = {$IFDEF FPC}32000{$ELSE}4000{$ENDIF};
  MAX_PROC    = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_USES    = 32;

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  TTokenKind = (
    TK_EOF,
    TK_INTEGER,    { 42  $FF                                  }
    TK_REAL,       { 3.14  1.0E2                              }
    TK_STRING,     { 'hello'                                  }
    TK_CHAR,       { #65  #$41                                }
    TK_IDENT,      { identificateur ordinaire                 }
    TK_KEYWORD,    { mot-cle Pascal                           }
    TK_OP,         { :=  =  <>  +  -  *  /  <  >  <=  >= ...  }
    TK_PUNCT,      { ;  ,  (  )  [  ]  ^  @  ..               }
    TK_COMMENT     { commentaire Pascal (preserve)            }
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;
    Line   : Integer;
    Col    : Integer;
  End;

  TFuncRec = Record
    Name      : TString;     { nom de la fonction Pascal               }
    RetType   : TString;     { type de retour Visual Basic .NET                   }
    IsFunc    : Boolean;     { true si FUNCTION, false si PROCEDURE    }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  SrcFile, DstFile : Text;
  SrcName, DstName : TString;
  Verbose          : Boolean;

  Tokens           : Array[1..MAX_TOKEN] of TToken;
  TokCount         : Integer;

  ProgName         : TString;       { nom du PROGRAM ou UNIT          }
  IsUnit           : Boolean;       { true si UNIT au lieu de PROGRAM }

  Funcs            : Array[1..MAX_PROC] of TFuncRec;
  FuncCount        : Integer;

  UsesOut          : Boolean;       { faut-il IMPORT Out;             }
  UsesIn           : Boolean;       { faut-il IMPORT In;              }

  CurFunc          : Integer;       { index dans Funcs ou 0           }
  FuncStack        : Array[1..32] of Integer;
  FuncSP           : Integer;

  ErrorCount       : Integer;

{ ============================================================
  UTILITAIRES STRING
  ============================================================ }
Function StrUpper(S:TString):TString;
Var
  I:Integer;
Begin
  For I:=1 to Length(S) do
    If S[I] in ['a'..'z'] Then S[I]:=Chr(Ord(S[I])-32);
  StrUpper:=S;
End;

Function StrLower(S:TString):TString;
Var
  I:Integer;
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
Var
  S:TString;
Begin
  Str(N,S);
  IntToStr:=S;
End;

{ ============================================================
  TOKENISEUR
  ============================================================ }
Var
  SrcText      : TString;        { ligne courante                 }
  SrcLineNo    : Integer;
  SrcCol       : Integer;
  SrcEOF       : Boolean;
  PendingChar  : Char;           { 1 caractere d'avance ou #0     }
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

{ Lit un caractere du fichier source en simulant un flot continu
  ou retourne #10 en fin de ligne et #0 en fin de fichier. }
Function NextCh:Char;
Var
  Ch:Char;
Begin
  If HasPending Then Begin
    HasPending:=False;
    NextCh:=PendingChar;
    Exit;
  End;
  If SrcEOF Then Begin
    NextCh:=#0;
    Exit;
  End;
  If SrcCol>Length(SrcText) Then Begin
    If EOF(SrcFile) Then Begin
      SrcEOF:=True;
      NextCh:=#0;
      Exit;
    End;
    ReadLn(SrcFile,SrcText);
    Inc(SrcLineNo);
    SrcCol:=1;
    NextCh:=#10;             { renvoyer la fin de ligne          }
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
Var
  Ch:Char;
Begin
  Ch:=NextCh;
  UngetCh(Ch);
  PeekCh:=Ch;
End;

Procedure AddToken(K:TTokenKind; V:TString);
Begin
  If TokCount>=MAX_TOKEN Then Begin
    WriteLn('PAS2PLI : trop de tokens (>',MAX_TOKEN,')');
    Halt(EXIT_ERROR);
  End;
  Inc(TokCount);
  Tokens[TokCount].Kind:=K;
  Tokens[TokCount].Val :=V;
  Tokens[TokCount].Line:=SrcLineNo;
  Tokens[TokCount].Col :=SrcCol;
End;

Function IsKeyword(S:TString):Boolean;
Var
  U:TString;
Begin
  U:=StrUpper(S);
  IsKeyword:=
    (U='AND')or(U='ARRAY')or(U='ASM')or(U='BEGIN')or(U='BREAK')or
    (U='CASE')or(U='CONST')or(U='CONSTRUCTOR')or(U='CONTINUE')or
    (U='DESTRUCTOR')or(U='DIV')or(U='DO')or(U='DOWNTO')or
    (U='ELSE')or(U='END')or(U='EXIT')or(U='FILE')or(U='FOR')or
    (U='FUNCTION')or(U='GOTO')or(U='IF')or(U='IMPLEMENTATION')or
    (U='IN')or(U='INHERITED')or(U='INTERFACE')or(U='LABEL')or
    (U='MOD')or(U='NIL')or(U='NOT')or(U='OBJECT')or(U='OF')or
    (U='OR')or(U='OTHERWISE')or(U='PACKED')or(U='PROCEDURE')or
    (U='PROGRAM')or(U='RECORD')or(U='REPEAT')or(U='SET')or
    (U='SHL')or(U='SHR')or(U='STRING')or(U='THEN')or(U='TO')or
    (U='TYPE')or(U='UNIT')or(U='UNTIL')or(U='USES')or(U='VAR')or
    (U='WHILE')or(U='WITH')or(U='XOR');
End;

Procedure SkipBlockComment(EndCh1,EndCh2:Char);
Var
  Ch,Prev:Char;
Begin
  Prev:=#0;
  Repeat
    Ch:=NextCh;
    If Ch=#0 Then Exit;
    If (EndCh2=#0) Then Begin
      If Ch=EndCh1 Then Exit;
    End Else Begin
      If (Prev=EndCh1)and(Ch=EndCh2) Then Exit;
    End;
    Prev:=Ch;
  Until False;
End;

Procedure ReadLineComment;
Var
  Ch:Char;
Begin
  Repeat
    Ch:=NextCh;
  Until (Ch=#10)or(Ch=#0);
End;

Procedure ScanString;
Var
  S:TString;
  Ch:Char;
Begin
  S:='''';
  Repeat
    Ch:=NextCh;
    If (Ch=#0)or(Ch=#10) Then Begin
      WriteLn('PAS2PLI : chaine non terminee ligne ',SrcLineNo);
      Inc(ErrorCount);
      Break;
    End;
    S:=S+Ch;
    If Ch='''' Then Begin
      Ch:=PeekCh;
      If Ch='''' Then Begin            { '' = quote echappee   }
        S:=S+NextCh;
      End Else
        Break;
    End;
  Until False;
  AddToken(TK_STRING,S);
End;

Procedure ScanCharLit;
Var
  S:TString;
  Ch:Char;
Begin
  S:='#';
  Ch:=PeekCh;
  If Ch='$' Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    While Ch in ['0'..'9','A'..'F','a'..'f'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
  End Else Begin
    While Ch in ['0'..'9'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
  End;
  AddToken(TK_CHAR,S);
End;

Procedure ScanNumber(First:Char);
Var
  S:TString;
  Ch:Char;
  IsReal:Boolean;
Begin
  S:=First;
  IsReal:=False;
  If First='$' Then Begin
    Ch:=PeekCh;
    While Ch in ['0'..'9','A'..'F','a'..'f'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
    AddToken(TK_INTEGER,S);
    Exit;
  End;
  Ch:=PeekCh;
  While Ch in ['0'..'9'] do Begin
    S:=S+NextCh;
    Ch:=PeekCh;
  End;
  If Ch='.' Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    If Ch='.' Then Begin
      { .. -> rendre le 2eme '.' au flot et arreter }
      UngetCh('.');
      S:=Copy(S,1,Length(S)-1);
      AddToken(TK_INTEGER,S);
      AddToken(TK_PUNCT,'..');
      { consommer le '.' suivant }
      NextCh;
      Exit;
    End;
    IsReal:=True;
    Ch:=PeekCh;
    While Ch in ['0'..'9'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
  End;
  If (Ch='e')or(Ch='E') Then Begin
    IsReal:=True;
    S:=S+NextCh;
    Ch:=PeekCh;
    If (Ch='+')or(Ch='-') Then Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
    While Ch in ['0'..'9'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
  End;
  If IsReal Then AddToken(TK_REAL,S)
            Else AddToken(TK_INTEGER,S);
End;

Procedure ScanIdent(First:Char);
Var
  S:TString;
  Ch:Char;
Begin
  S:=First;
  Ch:=PeekCh;
  While Ch in ['A'..'Z','a'..'z','0'..'9','_'] do Begin
    S:=S+NextCh;
    Ch:=PeekCh;
  End;
  If IsKeyword(S) Then AddToken(TK_KEYWORD,StrUpper(S))
                  Else AddToken(TK_IDENT,S);
End;

Procedure Tokenize;
Var
  Ch,Ch2:Char;
  S:TString;
Begin
  TokCount:=0;
  TokInit;
  Repeat
    Ch:=NextCh;
    If Ch=#0 Then Break;
    Case Ch of
      ' ',#9,#10,#13: ;                { ignorer espaces            }
      '{':Begin
        SkipBlockComment('}',#0);
      End;
      '(':Begin
        Ch2:=PeekCh;
        If Ch2='*' Then Begin
          NextCh;
          SkipBlockComment('*',')');
        End Else
          AddToken(TK_PUNCT,'(');
      End;
      '/':Begin
        Ch2:=PeekCh;
        If Ch2='/' Then Begin
          NextCh;
          ReadLineComment;
        End Else
          AddToken(TK_OP,'/');
      End;
      '''':ScanString;
      '#':ScanCharLit;
      '$':ScanNumber('$');
      '0'..'9':ScanNumber(Ch);
      'A'..'Z','a'..'z','_':ScanIdent(Ch);
      ':':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,':='); End
                   Else AddToken(TK_PUNCT,':');
      End;
      '<':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'<='); End Else
        If Ch2='>' Then Begin NextCh; AddToken(TK_OP,'<>'); End
                   Else AddToken(TK_OP,'<');
      End;
      '>':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'>='); End
                   Else AddToken(TK_OP,'>');
      End;
      '+','-','*','=':Begin
        S:=Ch;
        AddToken(TK_OP,S);
      End;
      '.':Begin
        Ch2:=PeekCh;
        If Ch2='.' Then Begin NextCh; AddToken(TK_PUNCT,'..'); End
                   Else AddToken(TK_PUNCT,'.');
      End;
      ')':AddToken(TK_PUNCT,')');
      '[',']',';',',','^','@':Begin
        S:=Ch;
        AddToken(TK_PUNCT,S);
      End;
    Else
      { caractere inconnu : ignorer silencieusement }
    End;
  Until SrcEOF and (Not HasPending);
  AddToken(TK_EOF,'');
End;

{ ============================================================
  ANALYSEUR
  Decouvre :
    - le nom du programme/unit
    - la liste des fonctions/procedures et leur type de retour
    - si Out / In doivent etre importes
  ============================================================ }

Function MapPascalType(T:TString):TString;
Var
  U:TString;
Begin
  U:=StrUpper(T);
  If U='INTEGER' Then MapPascalType:='FIXED BIN(31)' Else
  If U='LONGINT' Then MapPascalType:='FIXED BIN(31)' Else
  If U='LONGWORD' Then MapPascalType:='FIXED BIN(31) UNSIGNED' Else
  If U='CARDINAL' Then MapPascalType:='FIXED BIN(31) UNSIGNED' Else
  If U='SHORTINT' Then MapPascalType:='FIXED BIN(7)' Else
  If U='SMALLINT' Then MapPascalType:='FIXED BIN(15)' Else
  If U='BYTE' Then MapPascalType:='FIXED BIN(7) UNSIGNED' Else
  If U='WORD' Then MapPascalType:='FIXED BIN(15) UNSIGNED' Else
  If U='INT64' Then MapPascalType:='FIXED BIN(63)' Else
  If U='QWORD' Then MapPascalType:='FIXED BIN(63) UNSIGNED' Else
  If U='REAL' Then MapPascalType:='FLOAT BIN(21)' Else
  If U='SINGLE' Then MapPascalType:='FLOAT BIN(21)' Else
  If U='DOUBLE' Then MapPascalType:='FLOAT BIN(53)' Else
  If U='EXTENDED' Then MapPascalType:='FLOAT BIN(53)' Else
  If U='BOOLEAN' Then MapPascalType:='BIT(1)' Else
  If U='CHAR' Then MapPascalType:='CHAR(1)' Else
  If U='STRING' Then MapPascalType:='CHAR(255) VARYING' Else
  If U='ANSISTRING' Then MapPascalType:='CHAR(255) VARYING' Else
  If U='POINTER' Then MapPascalType:='POINTER' Else
  If U='TEXT' Then MapPascalType:='FILE /* (file handle) */' Else
  MapPascalType:=T;       { type utilisateur : conserver tel quel  }
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean);
Begin
  If FuncCount>=MAX_PROC Then Exit;
  Inc(FuncCount);
  Funcs[FuncCount].Name   :=Name;
  Funcs[FuncCount].RetType:=RetType;
  Funcs[FuncCount].IsFunc :=IsFunc;
End;

Function FindFunc(Name:TString):Integer;
Var
  I:Integer;
Begin
  For I:=1 to FuncCount do
    If StrEqualCI(Funcs[I].Name,Name) Then Begin
      FindFunc:=I;
      Exit;
    End;
  FindFunc:=0;
End;

{ Analyse principale : balaie les tokens pour collecter les
  meta-informations utiles avant l'emission. }
Procedure Analyze;
Var
  I,J,Depth:Integer;
  K:TString;
Begin
  ProgName:='Program';
  IsUnit:=False;
  FuncCount:=0;
  UsesOut:=False;
  UsesIn:=False;
  I:=1;
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='PROGRAM') and (I<TokCount) Then Begin
        If Tokens[I+1].Kind=TK_IDENT Then Begin
          ProgName:=Tokens[I+1].Val;
          IsUnit:=False;
        End;
      End Else
      If (K='UNIT') and (I<TokCount) Then Begin
        If Tokens[I+1].Kind=TK_IDENT Then Begin
          ProgName:=Tokens[I+1].Val;
          IsUnit:=True;
        End;
      End Else
      If (K='FUNCTION') and (I<TokCount) Then Begin
        If Tokens[I+1].Kind=TK_IDENT Then Begin
          { rechercher : <nom>(...): <type>; }
          J:=I+2;
          If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Begin
            Depth:=1; Inc(J);
            While (J<=TokCount) and (Depth>0) do Begin
              If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
              If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
              Inc(J);
            End;
          End;
          If (J<=TokCount)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Begin
            Inc(J);
            If (J<=TokCount)and((Tokens[J].Kind=TK_IDENT)or(Tokens[J].Kind=TK_KEYWORD)) Then
              RegisterFunc(Tokens[I+1].Val,MapPascalType(Tokens[J].Val),True);
          End Else
            RegisterFunc(Tokens[I+1].Val,'INTEGER',True);
        End;
      End Else
      If (K='PROCEDURE') and (I<TokCount) Then Begin
        If Tokens[I+1].Kind=TK_IDENT Then
          RegisterFunc(Tokens[I+1].Val,'',False);
      End;
    End Else
    If Tokens[I].Kind=TK_IDENT Then Begin
      K:=StrUpper(Tokens[I].Val);
      If (K='WRITE')or(K='WRITELN') Then UsesOut:=True Else
      If (K='READ')or(K='READLN') Then Begin UsesIn:=True; UsesOut:=True; End;
    End;
    Inc(I);
  End;
End;

{ ============================================================
  EMISSION
  ============================================================ }
Var
  OutCol  : Integer;
  OutLine : TString;       { ligne courante en attente              }
  Indent  : Integer;

Procedure FlushLine;
Begin
  WriteLn(DstFile,OutLine);
  OutLine:='';
  OutCol:=0;
End;

Procedure EmitRaw(S:TString);
Var
  I:Integer;
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

Procedure Emit(S:TString);
Begin
  EmitRaw(S);
End;

Procedure EmitSpace;
Begin
  If (OutCol>0)and(OutLine[Length(OutLine)]<>' ') Then EmitRaw(' ');
End;

Procedure EmitLn;
Begin
  EmitRaw(#10);
End;

{ Conversion d'une chaine Pascal 'abc''def' en chaine PL/I 'abc''def'.
  En PL/I, les chaines sont entourees de ' et le ' interne est double,
  donc la representation Pascal et PL/I sont identiques. }
Function PasStringToVB(S:TString):TString;
Begin
  PasStringToVB:=S;
End;

{ Conversion d'un litteral caractere Pascal #N en PL/I :
    SUBSTR('...',n,1) ou plus simplement BYTE(n) si la cible
    est CHAR(1). On utilise UNSPEC inverse via SUBSTR pour
    rester portable : on emet une chaine litterale d'un seul
    caractere quand n est imprimable, sinon SUBSTR(...). }
Function PasCharToVB(S:TString):TString;
Var
  V:LongInt;
  Code:Integer;
  Body,Dec:TString;
Begin
  Body:=Copy(S,2,Length(S)-1);     { retirer le # }
  If (Length(Body)>0)and(Body[1]='$') Then Begin
    Val('$'+Copy(Body,2,Length(Body)-1),V,Code);
  End Else
    Val(Body,V,Code);
  If Code<>0 Then V:=0;
  Str(V,Dec);
  { en PL/I, BYTE(n) ou SUBSTR(COLLATE(),n+1,1) ; on utilise
    la forme portable BYTE(n) du standard PL/I moderne. }
  PasCharToVB:='BYTE('+Dec+')';
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op=':=' Then MapOperator:='=' Else
  If Op='<>' Then MapOperator:='^=' Else
  If Op='='  Then MapOperator:='=' Else
  If Op='+'  Then MapOperator:='+' Else  { reste + : pour chaines, voir MapKeyword }
                  MapOperator:=Op;
End;

Function MapKeyword(K:TString):TString;
Begin
  If K='AND' Then MapKeyword:='&' Else
  If K='OR'  Then MapKeyword:='|' Else
  If K='NOT' Then MapKeyword:='^' Else
  If K='DIV' Then MapKeyword:='/' Else
  If K='MOD' Then MapKeyword:='MOD' Else        { fonction MOD(a,b) -- approximation operatoire }
  If K='SHL' Then MapKeyword:='/* SHL */' Else
  If K='SHR' Then MapKeyword:='/* SHR */' Else
  If K='XOR' Then MapKeyword:='/* XOR */' Else  { PL/I n'a pas d'operateur XOR direct }
  If K='TRUE' Then MapKeyword:='''1''B' Else
  If K='FALSE' Then MapKeyword:='''0''B' Else
  If K='NIL' Then MapKeyword:='NULL()' Else
                  MapKeyword:=K;
End;

{ Determine si l'identificateur est un appel "Write" ou "WriteLn". }
Function IdentIsWrite(S:TString):Boolean;
Var U:TString;
Begin
  U:=StrUpper(S);
  IdentIsWrite:=(U='WRITE')or(U='WRITELN');
End;

Function IdentIsWriteLn(S:TString):Boolean;
Begin
  IdentIsWriteLn:=StrEqualCI(S,'WRITELN');
End;

Function IdentIsRead(S:TString):Boolean;
Var U:TString;
Begin
  U:=StrUpper(S);
  IdentIsRead:=(U='READ')or(U='READLN');
End;

Function IdentIsReadLn(S:TString):Boolean;
Begin
  IdentIsReadLn:=StrEqualCI(S,'READLN');
End;

{ ============================================================
  EMISSION D'EXPRESSIONS / D'ARGUMENTS WRITE/READ
  ============================================================ }
{ Forward declarations pour la recursion }
Procedure EmitExpr(Var I:Integer); Forward;

{ Emet l'expression d'un argument Write/WriteLn comme expression VB.NET.
  J pointera apres l'argument. }
Procedure EmitWriteArg(Var I:Integer);
Var
  Depth:Integer;
  J:Integer;
Begin
  Depth:=0;
  { Capture jusqu'a ',' ou ')' au niveau 0 ; egalement ':' niveau 0
    pour le formatage Pascal :width[:prec] que l'on ignore. }
  J:=I;
  While J<=TokCount do Begin
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and
       ((Tokens[J].Val=',')or(Tokens[J].Val=')')) Then Break;
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Break;
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
    Inc(J);
  End;
  { Emettre l'expression source comme expression VB.NET }
  While I<J do Begin
    Case Tokens[I].Kind of
      TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
      TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
      TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
      TK_CHAR  : EmitRaw(PasCharToVB(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='[' Then EmitRaw('(') Else
        If Tokens[I].Val=']' Then EmitRaw(')') Else
        If Tokens[I].Val=',' Then EmitRaw(', ') Else
          EmitRaw(Tokens[I].Val);
      End;
    Else
      EmitRaw(Tokens[I].Val);
    End;
    Inc(I);
  End;
  { Sauter formatage :width[:prec] s'il existe }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
    Inc(I);
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and
          ((Tokens[I].Val=',')or(Tokens[I].Val=')')or(Tokens[I].Val=':'))) do
      Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
      Inc(I);
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and
            ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do
        Inc(I);
    End;
  End;
End;

{ Emission d'un appel WriteLn(...) ou Write(...) en VB.NET :
    WriteLn(a,b,c) -> Console.WriteLine(a & b & c)
    Write(a,b,c)   -> Console.Write(a & b & c)
    WriteLn        -> Console.WriteLine()
    Write          -> ' Write sans arguments est sans effet }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
  HasArgs,FirstArg:Boolean;
Begin
  HasArgs:=False;
  FirstArg:=True;
  If IsLn Then EmitRaw('PUT SKIP LIST')
          Else EmitRaw('PUT LIST');
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    EmitRaw('(');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw(', ');
      FirstArg:=False;
      EmitWriteArg(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then
      Inc(I);
    EmitRaw(')');
  End Else Begin
    If Not IsLn Then Begin
      { PUT LIST sans argument est inutile : emis comme commentaire }
      OutLine:=Copy(OutLine,1,Length(OutLine)-Length('PUT LIST'));
      OutCol:=Length(OutLine);
      EmitRaw('/* Write sans argument */');
    End;
    { PUT SKIP LIST sans argument => simple SKIP : on remplace }
    If IsLn Then Begin
      OutLine:=Copy(OutLine,1,Length(OutLine)-Length('PUT SKIP LIST'));
      OutCol:=Length(OutLine);
      EmitRaw('PUT SKIP');
    End;
  End;
  If False Then HasArgs:=HasArgs;            { eviter "non utilise" }
End;

{ Emission d'un appel ReadLn(...) ou Read(...) en PL/I :
    ReadLn(x)     -> GET LIST(x); GET SKIP;
    ReadLn(x,y)   -> GET LIST(x, y); GET SKIP;
    Read(x)       -> GET LIST(x);
    ReadLn        -> GET SKIP;
  Avance I jusqu'apres la parenthese fermante (si presente). }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var
  HasArgs,FirstArg:Boolean;
Begin
  HasArgs:=False;
  FirstArg:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    EmitRaw('GET LIST(');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw(', ');
      FirstArg:=False;
      { emettre l'expression cible jusqu'a , ou ) au niveau courant }
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and
            ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do Begin
        Case Tokens[I].Kind of
          TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
          TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
    EmitRaw(')');
    If IsLn Then Begin
      EmitRaw(';'); EmitLn;
      EmitRaw('GET SKIP');
    End;
  End Else Begin
    If IsLn Then EmitRaw('GET SKIP')
            Else EmitRaw('/* Read sans argument */');
  End;
  If False Then HasArgs:=HasArgs;
End;

{ Emet la sequence VAR/CONST/TYPE qui suit jusqu'au prochain
  mot-cle de section ou BEGIN/PROCEDURE/FUNCTION/IMPLEMENTATION. }
{ ============================================================
  EMISSION GENERIQUE DE TOKENS
  ============================================================ }
Function IsSectionKw(K:TString):Boolean;
Begin
  IsSectionKw:=
    (K='VAR')or(K='CONST')or(K='TYPE')or(K='LABEL')or(K='USES')or
    (K='BEGIN')or(K='PROCEDURE')or(K='FUNCTION')or
    (K='IMPLEMENTATION')or(K='INTERFACE');
End;

{ Emet un identificateur en gerant les cas speciaux :
   - si on est dans une fonction et l'ident == nom de fonction
     suivi de := alors emettre RETURN.
  Renvoie True si l'identificateur a ete consomme entierement. }
{ En PL/I, le retour de fonction se fait via RETURN(expr); ;
  l'assignation Pascal "FuncName := expr" doit donc etre traduite
  en RETURN(expr). On detecte ici l'identificateur courant : s'il
  correspond au nom de la fonction englobante et est suivi de :=,
  on emet "RETURN(expr)" puis on consomme le := et on laisse
  l'expression suivante s'emettre. Le ')' final est ferme par le
  ';' classique de fin d'instruction. Renvoie True si traite. }
Function MaybeEmitFuncReturn(Var I:Integer):Boolean;
Var
  Name:TString;
Begin
  MaybeEmitFuncReturn:=False;
  If (CurFunc>0) and Funcs[CurFunc].IsFunc and
     (Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    If StrEqualCI(Name,Funcs[CurFunc].Name) and
       (I<TokCount)and(Tokens[I+1].Kind=TK_OP)and(Tokens[I+1].Val=':=') Then Begin
      EmitRaw('RETURN(');
      Inc(I,2);                          { consommer Name et := }
      EmitExpr(I);
      EmitRaw(')');
      MaybeEmitFuncReturn:=True;
    End;
  End;
End;

{ Verifie si la sequence courante est ELSE IF -> emettre ELSE IF
  (PL/I ne possede pas de mot-cle ELSIF mais ELSE IF chaine fonctionne).
  Consomme les deux tokens. }
Function MaybeEmitElsif(Var I:Integer):Boolean;
Begin
  MaybeEmitElsif:=False;
  If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') and
     (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
    EmitRaw('ELSE IF');
    Inc(I,2);
    MaybeEmitElsif:=True;
  End;
End;

{ Emet l'en-tete d'une PROCEDURE/FUNCTION en PL/I.
  PROCEDURE Foo(p:Type; Var q:Type);
    -> Foo: PROCEDURE(p, q);
       DCL p type;
       DCL q type;
  FUNCTION  Bar(p:Type):RType;
    -> Bar: PROCEDURE(p) RETURNS(rtype);
       DCL p type;
  Avance I jusqu'apres le ';' final de l'en-tete. }
Procedure EmitProcHeader(Var I:Integer);
Const
  MAX_PARAMS = 32;
Var
  Name,RetType,Mode:TString;
  IsFunc:Boolean;
  PNames    : Array[1..MAX_PARAMS] of TString;
  PTypes    : Array[1..MAX_PARAMS] of TString;
  PModes    : Array[1..MAX_PARAMS] of TString;   { '' ou 'BYVALUE' }
  PCount,K  : Integer;
  GroupStart,GroupEnd,M:Integer;
  CurType,CurMode:TString;
Begin
  IsFunc:=(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='FUNCTION');
  Inc(I);
  Name:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    Inc(FuncSP);
    FuncStack[FuncSP]:=FindFunc(Name);
    CurFunc:=FuncStack[FuncSP];
    Inc(I);
  End;
  PCount:=0;
  { collecter les parametres }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      CurMode:='BYVALUE';
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='VAR') Then Begin
        CurMode:=''; Inc(I);          { VAR : reference (defaut PL/I) }
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Begin
        CurMode:='BYVALUE'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OUT') Then Begin
        CurMode:=''; Inc(I);
      End;
      GroupStart:=PCount+1;
      While (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) do Begin
        Inc(PCount);
        If PCount<=MAX_PARAMS Then Begin
          PNames[PCount]:=Tokens[I].Val;
          PModes[PCount]:=CurMode;
        End;
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
        Else Break;
      End;
      GroupEnd:=PCount;
      CurType:='FIXED BIN(31)';
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
        Inc(I);
        If (I<=TokCount) Then Begin
          CurType:=MapPascalType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      For M:=GroupStart to GroupEnd do
        If M<=MAX_PARAMS Then PTypes[M]:=CurType;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End;
  { type de retour }
  RetType:='';
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
      Inc(I);
      If (I<=TokCount) Then Begin
        RetType:=MapPascalType(Tokens[I].Val);
        Inc(I);
      End;
    End;
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  { emission de l'en-tete }
  EmitRaw(Name); EmitRaw(': PROCEDURE(');
  For K:=1 to PCount do Begin
    If K>1 Then EmitRaw(', ');
    EmitRaw(PNames[K]);
  End;
  EmitRaw(')');
  If IsFunc and (RetType<>'') Then Begin
    EmitRaw(' RETURNS('); EmitRaw(RetType); EmitRaw(')');
  End;
  EmitRaw(';');
  EmitLn;
  { emission des declarations de parametres }
  Inc(Indent);
  For K:=1 to PCount do Begin
    EmitRaw('DCL '); EmitRaw(PNames[K]); EmitRaw(' '); EmitRaw(PTypes[K]);
    Mode:=PModes[K];
    If Mode<>'' Then Begin EmitRaw(' '); EmitRaw(Mode); End;
    EmitRaw(';');
    EmitLn;
  End;
  Dec(Indent);
End;

{ Emet une declaration VAR / CONST / TYPE en syntaxe Visual Basic .NET.

  Pascal VAR :   x, y : Integer;        ->  Dim x As Long, y As Long
  Pascal CONST:  Pi = 3.14;             ->  Const Pi = 3.14
  Pascal TYPE :  TPoint = Record ...End;->  Type TPoint ... End Type

  Pour les types non triviaux (ARRAY, RECORD imbrique, SET, FILE),
  une approximation est emise avec un commentaire d'avertissement. }
Procedure EmitDeclSection(Var I:Integer; SectKw:TString);
Var
  K,Name,TypeName,Val:TString;
  J,Depth,GCount,M:Integer;
  Names:Array[1..32] of TString;

  { Lire un type Pascal a partir de la position courante I jusqu'au
    prochain ';' au niveau 0 ou un mot-cle de section. Retourne une
    representation en chaine et avance I.   Les cas reconnus :
      Type simple                          -> mappe via MapPascalType
      ARRAY[low..high] OF T                -> '(low To high) As <T>'
                                              (note : sera utilise dans Dim)
      STRING[N]                             -> 'String * N'
      RECORD ... END                        -> '__RECORD__' (signal)
    Les cas non triviaux retournent leur source litterale. }
  Function ReadType:TString;
  Var
    R:TString;
    Lo,Hi:TString;
  Begin
    R:='';
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ARRAY') Then Begin
      Inc(I);
      Lo:=''; Hi:='';
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..')) do Begin
          Lo:=Lo+Tokens[I].Val; Inc(I);
        End;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
          Hi:=Hi+Tokens[I].Val; Inc(I);
        End;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
      { type element }
      If (I<=TokCount) Then Begin
        R:='__ARRAY__:'+Lo+':'+Hi+':'+MapPascalType(Tokens[I].Val);
        Inc(I);
      End;
      ReadType:=R;
      Exit;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
        Inc(I);
        Lo:='';
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Begin
          Lo:=Lo+Tokens[I].Val; Inc(I);
        End;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
        ReadType:='CHAR('+Lo+') VARYING';
        Exit;
      End;
      ReadType:='CHAR(255) VARYING';
      Exit;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Begin
      ReadType:='__RECORD__';
      Exit;
    End;
    If (I<=TokCount) Then Begin
      R:=MapPascalType(Tokens[I].Val);
      Inc(I);
    End;
    ReadType:=R;
  End;

  { Emet une definition de Type RECORD apres avoir consomme RECORD :
    parcourt les champs jusqu'a END et les emet. }
  Procedure EmitRecordBody(Const TypeIdent:TString);
  Var
    FK,FType,Val2:TString;
    FCount,L,Pk1,Pk2:Integer;
    FNames:Array[1..32] of TString;
  Begin
    EmitRaw('DCL 1 '); EmitRaw(TypeIdent); EmitLn;
    Inc(Indent);
    Inc(I);                                 { sauter RECORD }
    While I<=TokCount do Begin
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
        Inc(I); Break;
      End;
      { liste de champs }
      FCount:=0;
      While (I<=TokCount) and (Tokens[I].Kind=TK_IDENT) do Begin
        Inc(FCount);
        If FCount<=32 Then FNames[FCount]:=Tokens[I].Val;
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
        Else Break;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
      FType:=ReadType;
      For L:=1 to FCount do Begin
        EmitRaw(', 2 '); EmitRaw(FNames[L]); EmitRaw(' ');
        If Copy(FType,1,9)='__ARRAY__' Then Begin
          Val2:=Copy(FType,11,Length(FType)-10);
          Pk1:=Pos(':',Val2);
          FK:=Copy(Val2,1,Pk1-1);
          Val2:=Copy(Val2,Pk1+1,Length(Val2));
          Pk2:=Pos(':',Val2);
          EmitRaw('('); EmitRaw(FK); EmitRaw(':'); EmitRaw(Copy(Val2,1,Pk2-1));
          EmitRaw(') '); EmitRaw(Copy(Val2,Pk2+1,Length(Val2)));
        End Else Begin
          EmitRaw(FType);
        End;
        EmitLn;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
    Dec(Indent);
    EmitRaw(';'); EmitLn;
    EmitRaw('/* fin RECORD '); EmitRaw(TypeIdent); EmitRaw(' */'); EmitLn;
    { sauter ';' eventuel }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;

Begin
  Inc(I);  { sauter VAR / CONST / TYPE }
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If IsSectionKw(K) Then Break;
    End;
    If Tokens[I].Kind<>TK_IDENT Then Begin
      Inc(I); Continue;
    End;
    If StrEqualCI(SectKw,'VAR') Then Begin
      (* Lire la liste de noms : ident, ident ... : Type ; *)
      GCount:=0;
      While (I<=TokCount) and (Tokens[I].Kind=TK_IDENT) do Begin
        Inc(GCount);
        If GCount<=32 Then Names[GCount]:=Tokens[I].Val;
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
        Else Break;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
      TypeName:=ReadType;

      If Copy(TypeName,1,9)='__ARRAY__' Then Begin
        { __ARRAY__:lo:hi:elt -> DCL name(lo:hi) elt; }
        Val:=Copy(TypeName,11,Length(TypeName)-10);
        J:=Pos(':',Val);
        Depth:=Pos(':',Copy(Val,J+1,Length(Val)));
        For M:=1 to GCount do Begin
          EmitRaw('DCL '); EmitRaw(Names[M]);
          EmitRaw('('); EmitRaw(Copy(Val,1,J-1)); EmitRaw(':');
          EmitRaw(Copy(Val,J+1,Depth-1)); EmitRaw(') ');
          EmitRaw(Copy(Val,J+Depth+1,Length(Val)));
          EmitRaw(';'); EmitLn;
        End;
      End Else
      If TypeName='__RECORD__' Then Begin
        { record anonyme dans VAR : emettre comme structure DCL 1 name }
        For M:=1 to GCount do Begin
          EmitRaw('/* RECORD anonyme : '); EmitRaw(Names[M]); EmitRaw(' */'); EmitLn;
        End;
        Depth:=1; Inc(I);
        While (I<=TokCount) and (Depth>0) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Dec(Depth);
          Inc(I);
        End;
      End Else Begin
        If GCount=1 Then Begin
          EmitRaw('DCL '); EmitRaw(Names[1]); EmitRaw(' '); EmitRaw(TypeName);
          EmitRaw(';'); EmitLn;
        End Else Begin
          EmitRaw('DCL (');
          For M:=1 to GCount do Begin
            If M>1 Then EmitRaw(', ');
            EmitRaw(Names[M]);
          End;
          EmitRaw(') '); EmitRaw(TypeName); EmitRaw(';'); EmitLn;
        End;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End Else
    If StrEqualCI(SectKw,'CONST') Then Begin
      Name:=Tokens[I].Val; Inc(I);
      { eventuel ':' Type (Pascal etendu) }
      TypeName:='';
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
        Inc(I);
        TypeName:=ReadType;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I)
      Else
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='=') Then Inc(I);

      { lire la valeur dans Val pour pouvoir inferer le type }
      Val:='';
      Depth:=0;
      While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
        Case Tokens[I].Kind of
          TK_STRING:Val:=Val+PasStringToVB(Tokens[I].Val);
          TK_CHAR  :Val:=Val+PasCharToVB(Tokens[I].Val);
          TK_OP    :Val:=Val+MapOperator(Tokens[I].Val);
          TK_KEYWORD:Val:=Val+MapKeyword(Tokens[I].Val);
        Else
          Val:=Val+Tokens[I].Val;
        End;
        Inc(I);
      End;
      { inferer un type si non specifie }
      If TypeName='' Then Begin
        If (Length(Val)>0)and(Val[1]='''') Then TypeName:='CHAR(255) VARYING' Else
        If Pos('.',Val)>0 Then TypeName:='FLOAT BIN(53)' Else
          TypeName:='FIXED BIN(31)';
      End;
      EmitRaw('DCL '); EmitRaw(Name); EmitRaw(' '); EmitRaw(TypeName);
      EmitRaw(' INIT('); EmitRaw(Val); EmitRaw(');');
      EmitLn;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End Else
    If StrEqualCI(SectKw,'TYPE') Then Begin
      Name:=Tokens[I].Val; Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I)
      Else
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='=') Then Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Begin
        EmitRecordBody(Name);
      End Else Begin
        TypeName:=ReadType;
        EmitRaw('/* TYPE '); EmitRaw(Name); EmitRaw(' = '); EmitRaw(TypeName);
        EmitRaw(' (alias de type non supporte en PL/I ; utilisez DEFINE ALIAS) */');
        EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
      End;
    End Else
      Inc(I);
  End;
End;

{ Emet une instruction unique (jusqu'au ';' qui la termine, au
  niveau de nesting 0, ou jusqu'a un mot-cle de fin). }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitStatementList(Var I:Integer; UntilKwSet:TString); Forward;
Procedure EmitIfStatement(Var I:Integer); Forward;
Procedure EmitWhileStatement(Var I:Integer); Forward;
Procedure EmitForStatement(Var I:Integer); Forward;
Procedure EmitRepeatStatement(Var I:Integer); Forward;
Procedure EmitCaseStatement(Var I:Integer); Forward;
Procedure EmitBeginEnd(Var I:Integer); Forward;
Procedure EmitControlBody(Var I:Integer); Forward;

{ Emet une expression jusqu'au prochain ';' / ',' / ')' / ']' / 'END' /
  'THEN' / 'DO' / 'UNTIL' / 'OF' / 'TO' / 'DOWNTO' / 'ELSE' au niveau 0. }
Procedure EmitExpr(Var I:Integer);
Var
  Depth:Integer;
  Stop:Boolean;
  K:TString;
Begin
  Depth:=0;
  While I<=TokCount do Begin
    Stop:=False;
    If Depth=0 Then Begin
      If Tokens[I].Kind=TK_PUNCT Then Begin
        If (Tokens[I].Val=';')or(Tokens[I].Val=',')or
           (Tokens[I].Val=')')or(Tokens[I].Val=']')or
           (Tokens[I].Val=':') Then Stop:=True;
      End Else
      If Tokens[I].Kind=TK_KEYWORD Then Begin
        K:=Tokens[I].Val;
        If (K='END')or(K='THEN')or(K='DO')or(K='UNTIL')or(K='OF')or
           (K='TO')or(K='DOWNTO')or(K='ELSE')or(K='BEGIN') Then Stop:=True;
      End;
    End;
    If Stop Then Break;
    Case Tokens[I].Kind of
      TK_OP:Begin
        EmitRaw(MapOperator(Tokens[I].Val));
      End;
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='AND' Then EmitRaw(' & ') Else
        If K='OR' Then EmitRaw(' | ') Else
        If K='NOT' Then EmitRaw(' ^') Else
        If K='DIV' Then EmitRaw(' / ') Else
        If K='MOD' Then EmitRaw(' MOD ') Else
        If K='IN' Then EmitRaw(' /* IN ensemble : non supporte */ ') Else
        If K='SHL' Then EmitRaw(' /* SHL */ ') Else
        If K='SHR' Then EmitRaw(' /* SHR */ ') Else
        If K='XOR' Then EmitRaw(' /* XOR */ ') Else
        If K='NIL' Then EmitRaw('NULL()') Else
        If K='TRUE' Then EmitRaw('''1''B') Else
        If K='FALSE' Then EmitRaw('''0''B') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:Begin
          EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        If (Length(Tokens[I].Val)>0)and(Tokens[I].Val[1]='$') Then
          EmitRaw(''''+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-1)+'''X')
        Else
          EmitRaw(Tokens[I].Val);
      End;
      TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
      TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If Tokens[I].Val=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If Tokens[I].Val='[' Then Begin Inc(Depth); EmitRaw('('); End Else
        If Tokens[I].Val=']' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If Tokens[I].Val='^' Then EmitRaw('->') Else
        If Tokens[I].Val='@' Then EmitRaw('ADDR(') Else
        If Tokens[I].Val='..' Then EmitRaw('..') Else
        If Tokens[I].Val=':' Then EmitRaw(':') Else
        If Tokens[I].Val=',' Then EmitRaw(', ') Else
          EmitRaw(Tokens[I].Val);
      End;
    End;
    Inc(I);
  End;
End;

{ Emet le corps d'une instruction de controle (apres THEN, ELSE, DO).
  Si BEGIN suit, consomme BEGIN..END comme bloc.
  Sinon, emet une seule instruction (terminee par ';' eventuel). }
Procedure EmitControlBody(Var I:Integer);
Begin
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
    Inc(I);                                     { sauter BEGIN              }
    EmitStatementList(I,'END');
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  End Else Begin
    { instruction unique }
    EmitStmt(I);
    If (Length(OutLine)>0)and(OutLine[Length(OutLine)]<>';') Then EmitRaw(';');
    EmitLn;
    { ne pas consommer le ';' separateur ici : laisser au caller }
  End;
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
  EmitRaw('IF ');
  Inc(I);                              { sauter IF                        }
  EmitExpr(I);
  EmitRaw(' THEN DO;');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('END;'); EmitLn;
  { ELSE / ELSE IF -> ELSE IF chaine en boucle }
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') do Begin
    If (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
      Inc(I,2);
      EmitRaw('ELSE IF ');
      EmitExpr(I);
      EmitRaw(' THEN DO;');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
      EmitControlBody(I);
      Dec(Indent);
      EmitRaw('END;'); EmitLn;
    End Else Begin
      Inc(I);
      EmitRaw('ELSE DO;');
      EmitLn;
      Inc(Indent);
      EmitControlBody(I);
      Dec(Indent);
      EmitRaw('END');                      { ; ajoute par EmitStmt }
      Break;
    End;
  End;
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
  EmitRaw('DO WHILE(');
  Inc(I);
  EmitExpr(I);
  EmitRaw(');');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('END');
End;

Procedure EmitForStatement(Var I:Integer);
Var
  Down:Boolean;
  VarName:TString;
Begin
  EmitRaw('DO ');
  Inc(I);                                { sauter FOR                    }
  VarName:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then VarName:=Tokens[I].Val;
  EmitExpr(I);                           { i := 1 (s'arrete sur TO/DOWNTO) }
  Down:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
    Down:=True;
    EmitRaw(' TO ');
    Inc(I);
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Begin
    EmitRaw(' TO ');
    Inc(I);
  End;
  EmitExpr(I);                           { borne                          }
  If Down Then EmitRaw(' BY -1');
  EmitRaw(';');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('END /* '); EmitRaw(VarName); EmitRaw(' */');
End;

Procedure EmitRepeatStatement(Var I:Integer);
Var
  BodyStart,UntilIdx,Depth,J,Save:Integer;
Begin
  Inc(I);                                  { sauter REPEAT                }
  BodyStart:=I;
  { Trouver le UNTIL au meme niveau que REPEAT }
  Depth:=0;
  J:=I;
  UntilIdx:=0;
  While J<=TokCount do Begin
    If Tokens[J].Kind=TK_KEYWORD Then Begin
      If (Tokens[J].Val='REPEAT')or(Tokens[J].Val='CASE') Then Inc(Depth) Else
      If (Tokens[J].Val='BEGIN') Then Inc(Depth) Else
      If (Tokens[J].Val='END') Then Dec(Depth) Else
      If (Tokens[J].Val='UNTIL') and (Depth=0) Then Begin
        UntilIdx:=J;
        Break;
      End;
    End;
    Inc(J);
  End;
  If UntilIdx=0 Then Begin
    { malforme : emettre une boucle sans condition + corps }
    EmitRaw('DO;'); EmitLn;
    Inc(Indent);
    EmitStatementList(I,'UNTIL');
    Dec(Indent);
    EmitRaw('END');
    Exit;
  End;
  { 1. emettre l'en-tete avec la condition trouvee a UntilIdx+1 }
  EmitRaw('DO UNTIL(');
  Save:=UntilIdx+1;
  EmitExpr(Save);
  EmitRaw(');'); EmitLn;
  { 2. emettre le corps : depuis BodyStart jusqu'a UntilIdx }
  Inc(Indent);
  I:=BodyStart;
  EmitStatementList(I,'UNTIL');
  Dec(Indent);
  { 3. consommer UNTIL et la condition (deja emise en en-tete) }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
  { sauter la condition jusqu'a la prochaine fin d'instruction }
  Depth:=0;
  While I<=TokCount do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
       ((Tokens[I].Val=';')or(Tokens[I].Val=')')) Then Break;
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or
        (Tokens[I].Val='UNTIL')) Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Inc(I);
  End;
  EmitRaw('END');
End;

{ Marqueur pour laisser EmitRepeatStatementReal exister sans usage. }
Procedure EmitRepeatStatementOld(Var I:Integer);
Begin
  EmitRepeatStatement(I);
End;

{ Emet une liste de selecteurs Pascal en selecteurs VB.NET :
   Pascal :  1, 2, 3 :              -> Case 1, 2, 3
   Pascal :  1..10 :                -> Case 1 To 10
   Pascal :  1, 5..10 :             -> Case 1, 5 To 10
  Avance I jusqu'au ':' qui termine la liste. }
Procedure EmitCaseLabels(Var I:Integer);
Var
  First:Boolean;
  Depth:Integer;
Begin
  First:=True;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Break;
    If Not First Then Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        EmitRaw(', '); Inc(I); Continue;
      End;
    End;
    First:=False;
    { lire un selecteur jusqu'a ',' ou ':' au niveau 0 }
    Depth:=0;
    While (I<=TokCount) do Begin
      If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val=',')or(Tokens[I].Val=':')) Then Break;
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Begin
        EmitRaw(' /*..*/ '); Inc(I); Continue;     { PL/I n'a pas de range WHEN : a expanser manuellement }
      End;
      Case Tokens[I].Kind of
        TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
        TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
        TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
        TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
      Else
        EmitRaw(Tokens[I].Val);
      End;
      Inc(I);
    End;
  End;
End;

Procedure EmitCaseStatement(Var I:Integer);
Begin
  EmitRaw('SELECT(');
  Inc(I);                                  { sauter CASE                  }
  EmitExpr(I);
  EmitRaw(');');
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
      If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
        EmitRaw('OTHERWISE DO;');
        EmitLn;
        Inc(Indent);
        Inc(I);
        EmitStatementList(I,'END');
        Dec(Indent);
        EmitRaw('END;'); EmitLn;
      End;
      Break;
    End;
    EmitRaw('WHEN(');
    EmitCaseLabels(I);
    EmitRaw(')');
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
    EmitRaw(' DO;');
    EmitLn;
    Inc(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
      Inc(I);
      EmitStatementList(I,'END');
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
    End Else Begin
      EmitStmt(I);
      If (Length(OutLine)>0)and(OutLine[Length(OutLine)]<>';') Then EmitRaw(';');
      EmitLn;
    End;
    Dec(Indent);
    EmitRaw('END;'); EmitLn;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  EmitRaw('END /* SELECT */');
End;

Procedure EmitBeginEnd(Var I:Integer);
Begin
  Inc(I);                                       { sauter BEGIN              }
  EmitStatementList(I,'END');
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
End;

{ Emet une seule instruction (sans le ';' terminal). Avance I.
  L'appelant gere le ';' separateur. }
Procedure EmitStmt(Var I:Integer);
Var
  K:TString;
  FIdx:Integer;
Begin
  If I>TokCount Then Exit;
  Case Tokens[I].Kind of
    TK_KEYWORD:Begin
      K:=Tokens[I].Val;
      If K='BEGIN' Then EmitBeginEnd(I) Else
      If K='IF' Then EmitIfStatement(I) Else
      If K='WHILE' Then EmitWhileStatement(I) Else
      If K='FOR' Then EmitForStatement(I) Else
      If K='REPEAT' Then EmitRepeatStatement(I) Else
      If K='CASE' Then EmitCaseStatement(I) Else
      If K='EXIT' Then Begin
        If (CurFunc>0) Then EmitRaw('RETURN')
        Else EmitRaw('STOP');
        Inc(I);
      End Else
      If K='HALT' Then Begin
        EmitRaw('STOP');
        Inc(I);
        { sauter eventuellement un argument (...) }
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
          If I<=TokCount Then Inc(I);
        End;
      End Else
      If K='BREAK' Then Begin
        EmitRaw('LEAVE');
        Inc(I);
      End Else
      If K='CONTINUE' Then Begin
        EmitRaw('ITERATE');
        Inc(I);
      End Else
      If K='WITH' Then Begin
        EmitRaw('/* WITH non supporte en PL/I ; expansion manuelle requise */');
        EmitLn;
        { sauter jusqu'au DO }
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do
          Inc(I);
        If I<=TokCount Then Inc(I);
        EmitStmt(I);
      End Else
      If K='GOTO' Then Begin
        EmitRaw('GO TO ');
        Inc(I);
        If (I<=TokCount) Then Begin
          EmitRaw(Tokens[I].Val);
          Inc(I);
        End;
      End Else Begin
        { mot-cle inattendu : copier tel quel }
        EmitRaw(MapKeyword(K));
        Inc(I);
      End;
    End;
    TK_IDENT:Begin
      { Cas Write/WriteLn/Read/ReadLn }
      If IdentIsWriteLn(Tokens[I].Val) Then Begin
        Inc(I);
        EmitWriteCall(I,True);
      End Else
      If IdentIsWrite(Tokens[I].Val) Then Begin
        Inc(I);
        EmitWriteCall(I,False);
      End Else
      If IdentIsReadLn(Tokens[I].Val) Then Begin
        Inc(I);
        EmitReadCall(I,True);
      End Else
      If IdentIsRead(Tokens[I].Val) Then Begin
        Inc(I);
        EmitReadCall(I,False);
      End Else Begin
        { Pascal "FuncName := expr" -> PL/I "RETURN(expr)" }
        If MaybeEmitFuncReturn(I) Then Begin
          { ok -- RETURN(expr) emis }
        End Else Begin
          EmitExpr(I);
        End;
      End;
    End;
    TK_PUNCT:Begin
      { Ignorer ';' isole (instruction vide) }
      Inc(I);
    End;
  Else
    EmitExpr(I);
  End;
End;

{ Emet une suite d'instructions separees par ';' jusqu'a rencontrer
  l'un des mots-cles dans UntilKwSet (liste CSV en majuscules), ou ')'
  ou EOF. Ne consomme PAS le mot-cle final.
  En VB.NET les instructions sont separees par un retour de ligne, pas
  par ';'. }
Procedure EmitStatementList(Var I:Integer; UntilKwSet:TString);
Var
  Stop:Boolean;
  K,Set2:TString;

  Function InSet(K:TString):Boolean;
  Var
    P,Q:Integer;
    Item:TString;
  Begin
    InSet:=False;
    P:=1;
    While P<=Length(Set2) do Begin
      Q:=P;
      While (Q<=Length(Set2))and(Set2[Q]<>',') do Inc(Q);
      Item:=Copy(Set2,P,Q-P);
      If Item=K Then Begin InSet:=True; Exit; End;
      P:=Q+1;
    End;
  End;

Begin
  Set2:=StrUpper(UntilKwSet);
  While I<=TokCount do Begin
    Stop:=False;
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If InSet(K) Then Stop:=True;
    End Else
    If Tokens[I].Kind=TK_EOF Then Stop:=True;
    If Stop Then Break;
    EmitStmt(I);
    { ajouter le ';' final si la ligne ne finit pas deja par ';' }
    If (Length(OutLine)>0)and(OutLine[Length(OutLine)]<>';') Then EmitRaw(';');
    EmitLn;
    { ';' separateur Pascal : juste l'avaler }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
End;

{ Emet le corps complet d'une procedure ou du module en VB.NET :
   - les declarations VAR/CONST/TYPE deviennent Dim/Const/Type
   - le BEGIN..END devient simplement le corps de la Sub/Function
     (sans marqueur)
   - la procedure top-level devient "Sub Main()" ... "End Sub"
   - une procedure imbriquee devient "Sub Name(...)" ... "End Sub" ou
     "Function Name(...) As Type" ... "End Function" }
Procedure EmitBlock(Var I:Integer; IsTopLevel:Boolean);
Var
  K:TString;
  PrevFunc:Integer;
  IsFunc:Boolean;
Begin
  PrevFunc:=CurFunc;
  IsFunc:=False;
  If (Not IsTopLevel) and (CurFunc>0) Then IsFunc:=Funcs[CurFunc].IsFunc;
  { boucler sur les declarations }
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='VAR') Then EmitDeclSection(I,'VAR') Else
      If (K='CONST') Then EmitDeclSection(I,'CONST') Else
      If (K='TYPE') Then EmitDeclSection(I,'TYPE') Else
      If K='LABEL' Then Begin
        EmitRaw('/* LABEL section ignoree en PL/I */');
        EmitLn;
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
        If I<=TokCount Then Inc(I);
      End Else
      If (K='PROCEDURE')or(K='FUNCTION') Then Begin
        EmitProcHeader(I);
        Inc(Indent);
        EmitBlock(I,False);
        Dec(Indent);
        { restaurer la fonction courante }
        Dec(FuncSP);
        If FuncSP>0 Then CurFunc:=FuncStack[FuncSP] Else CurFunc:=0;
      End Else
      If K='BEGIN' Then Break Else
      If K='IMPLEMENTATION' Then Begin
        Inc(I);
      End Else
      If K='INTERFACE' Then Begin
        Inc(I);
      End Else
      If K='END' Then Break Else
        Break;
    End Else
      Inc(I);
  End;
  { corps : BEGIN..END }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
    Inc(I);
    EmitStatementList(I,'END');
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
      Inc(I);
      Dec(Indent);
      If IsTopLevel Then Begin
        EmitRaw('END '); EmitRaw(ProgName); EmitRaw(';');
        EmitLn;
      End Else Begin
        EmitRaw('END '); EmitRaw(Funcs[CurFunc].Name); EmitRaw(';');
        EmitLn;
        EmitLn;
        Inc(Indent);
      End;
      { sauter le '.' ou ';' final Pascal }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val='.')or(Tokens[I].Val=';')) Then Inc(I);
    End;
  End Else Begin
    { corps absent (procedure forward, ou module sans BEGIN..END) }
    If IsTopLevel Then Begin
      Dec(Indent);
      EmitRaw('END '); EmitRaw(ProgName); EmitRaw(';'); EmitLn;
    End;
  End;
  CurFunc:=PrevFunc;
End;

{ Emet la clause USES Pascal en commentaire PL/I.
  PL/I ne possede pas d'instruction d'import au niveau du source ;
  les modules externes sont resolus a l'edition de liens. }
Procedure EmitUses(Var I:Integer);
Var
  Names:Array[1..MAX_USES] of TString;
  ICount,K:Integer;
  First:Boolean;
Begin
  ICount:=0;
  Inc(I);                                   { sauter USES                  }
  While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
    If Tokens[I].Kind=TK_IDENT Then Begin
      If ICount<MAX_USES Then Begin
        Inc(ICount);
        Names[ICount]:=Tokens[I].Val;
      End;
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  If ICount>0 Then Begin
    EmitRaw('/* Pascal USES : ');
    First:=True;
    For K:=1 to ICount do Begin
      If Not First Then EmitRaw(', ');
      First:=False;
      EmitRaw(Names[K]);
    End;
    EmitRaw(' (a remplacer par modules PL/I correspondants) */');
    EmitLn;
    EmitLn;
  End;
End;

{ Emet l'en-tete d'un programme PL/I (.pli) :
    /* commentaire de generation */
    NAME: PROCEDURE OPTIONS(MAIN);
    ...
    END NAME;
  Le "END NAME;" sera emis par EmitBlock a la fin du corps. }
Procedure EmitModuleHeader(Var I:Integer);
Var
  J:Integer;
Begin
  EmitRaw('/* Genere par PAS2PLI ');
  EmitRaw(PAS2PLI_VERSION);
  EmitRaw(' a partir de Pascal */'); EmitLn;
  EmitLn;
  EmitRaw(ProgName); EmitRaw(': PROCEDURE OPTIONS(MAIN);'); EmitLn;
  Inc(Indent);
  { sauter PROGRAM/UNIT name; }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
     ((Tokens[I].Val='PROGRAM')or(Tokens[I].Val='UNIT')) Then Begin
    Inc(I);                            { sauter PROGRAM/UNIT             }
    If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Inc(I);
    { eventuels parametres (input,output) }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
      If I<=TokCount Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  { Sauter une eventuelle section INTERFACE d'unite }
  If IsUnit Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='INTERFACE') Then Inc(I);
  End;
  { USES en commentaire }
  J:=I;
  If (J<=TokCount)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='USES') Then
    EmitUses(I);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('PAS2PLI ',PAS2PLI_VERSION,' - Transpilateur Pascal vers PL/I');
  WriteLn;
  WriteLn('Syntaxe : PAS2PLI [-v] source.pas [destination.pli]');
  WriteLn;
  WriteLn('  source.pas       Fichier source Pascal (Turbo Pascal/FPC).');
  WriteLn('  destination.pli  Fichier PL/I a generer (defaut : source.pli).');
  WriteLn('  -v / --verbose   Afficher des messages de progression.');
  WriteLn('  -h / --help      Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : PAS2PLI hello.pas hello.pli');
End;

Procedure ParseArgs;
Var
  I:Integer;
  A:TString;
Begin
  Verbose:=False;
  SrcName:='';
  DstName:='';
  For I:=1 to ParamCount do Begin
    A:=ParamStr(I);
    If (A='-h')or(A='--help')or(A='/?')or(A='/h')or(A='/H') Then Begin
      ShowUsage;
      Halt(EXIT_OK);
    End Else
    If (A='-v')or(A='--verbose') Then Verbose:=True
    Else
    If SrcName='' Then SrcName:=A
    Else
    If DstName='' Then DstName:=A;
  End;
  If SrcName='' Then Begin
    ShowUsage;
    Halt(EXIT_USAGE);
  End;
  If DstName='' Then Begin
    { remplacer extension }
    A:=SrcName;
    I:=Length(A);
    While (I>0)and(A[I]<>'.')and(A[I]<>'\')and(A[I]<>'/') do Dec(I);
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.pli'
                          Else DstName:=A+'.pli';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2PLI : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  { DstFile est ouvert dans le corps principal apres l'analyse }
End;

Procedure CloseFiles;
Begin
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  Close(SrcFile);
End;

Var
  IPos:Integer;

BEGIN
  ErrorCount:=0;
  ParseArgs;
  If Verbose Then WriteLn('PAS2PLI : tokenisation de ',SrcName,'...');
  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('PAS2PLI : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('PAS2PLI : programme = ',ProgName);
    WriteLn('PAS2PLI : ',FuncCount,' procedure(s)/fonction(s).');
    If UsesOut Then WriteLn('PAS2PLI : Out detecte.');
    If UsesIn  Then WriteLn('PAS2PLI : In detecte.');
  End;

  { DstFile est ouvert dans le corps principal apres l'analyse }

  OutLine:='';
  OutCol:=0;
  Indent:=0;
  CurFunc:=0;
  FuncSP:=0;
  IPos:=1;
  EmitModuleHeader(IPos);
  EmitBlock(IPos,True);
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('PAS2PLI : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
