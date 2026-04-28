{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Turbo Pascal vers ABAP/4 (.abap)
}

(* ============================================================
   PAS2ABP.PAS - Transpilateur Turbo Pascal vers ABAP/4
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source ABAP/4 (.abap)

   ABAP/4 (Advanced Business Application Programming) est le langage
   propriétaire SAP. Il presente plusieurs caracteristiques :
     - chaque instruction se termine par un point '.'
     - commentaire pleine ligne : '*' en colonne 1
     - commentaire en fin de ligne : '"' jusqu'au saut de ligne
     - les structures de controle ont leur propre mot-cle de fermeture
       (IF/ENDIF, WHILE/ENDWHILE, DO/ENDDO, CASE/ENDCASE, FORM/ENDFORM)
     - les sous-programmes (FORM) peuvent etre imbriques au niveau
       textuel mais sont en pratique declares au niveau du report.

   Couvre les constructions courantes :
     PROGRAM/UNIT -> REPORT name.
     USES         -> commentaire (les modules sont charges via INCLUDE)
     CONST   -> CONSTANTS: name TYPE t VALUE val.
     TYPE record -> TYPES: BEGIN OF t, ... END OF t.
     VAR     -> DATA: var TYPE i / TYPE c LENGTH n / TYPE p / etc.
     PROCEDURE -> FORM name USING p1 p2... ENDFORM.
     FUNCTION  -> FORM name USING p1 p2... CHANGING result. ENDFORM.
                  (ABAP/4 distingue procedures et fonctions par CHANGING)
     BEGIN..END       -> blocs implicites,
     IF..THEN..ELSE   -> IF cond. ... ELSEIF cond2. ... ENDIF.
     WHILE..DO        -> WHILE cond. ... ENDWHILE.
     REPEAT..UNTIL    -> DO. ... IF cond. EXIT. ENDIF. ENDDO.
     FOR..TO/DOWNTO   -> DO. i = a. WHILE i <= b. ... i = i+1. ENDWHILE.
                         (approximation ; ABAP a aussi DO n TIMES)
     CASE..OF         -> CASE sel. WHEN val. ... WHEN OTHERS. ENDCASE.
     Write/WriteLn    -> WRITE: / expr1, expr2.
     Read/ReadLn      -> commentaire (lecture interactive : PARAMETERS)
     operateurs Pascal -> ABAP/4 (:= -> =, = -> EQ, <> -> NE,
       <,>,<=,>= -> LT,GT,LE,GE, AND/OR/NOT -> AND/OR/NOT,
       TRUE/FALSE -> 'X'/' ', DIV/MOD -> DIV/MOD).
     concatenation '+' sur chaine -> CONCATENATE (commentaire).

   Limitations connues :
     - les pointeurs Pascal n'ont pas d'equivalent direct en ABAP.
     - WITH non supporte (commentaire).
     - les CASE avec plages (1..10) generent un OR sur les valeurs.
   ============================================================ *)

Program PAS2ABP;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PAS2ABP_VERSION = '1.0';
  PAS2ABP_DATE    = '2026-04-27';

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
    WriteLn('PAS2ABP : trop de tokens (>',MAX_TOKEN,')');
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
      WriteLn('PAS2ABP : chaine non terminee ligne ',SrcLineNo);
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
  If U='INTEGER' Then MapPascalType:='i' Else
  If U='LONGINT' Then MapPascalType:='i' Else
  If U='LONGWORD' Then MapPascalType:='i' Else
  If U='CARDINAL' Then MapPascalType:='i' Else
  If U='SHORTINT' Then MapPascalType:='b' Else
  If U='SMALLINT' Then MapPascalType:='s' Else
  If U='BYTE' Then MapPascalType:='b' Else
  If U='WORD' Then MapPascalType:='s' Else
  If U='INT64' Then MapPascalType:='int8' Else
  If U='QWORD' Then MapPascalType:='int8' Else
  If U='REAL' Then MapPascalType:='f' Else
  If U='SINGLE' Then MapPascalType:='f' Else
  If U='DOUBLE' Then MapPascalType:='f' Else
  If U='EXTENDED' Then MapPascalType:='f' Else
  If U='BOOLEAN' Then MapPascalType:='c LENGTH 1' Else  { ABAP : 'X' (true) ou ' ' (false) }
  If U='CHAR' Then MapPascalType:='c LENGTH 1' Else
  If U='STRING' Then MapPascalType:='string' Else
  If U='ANSISTRING' Then MapPascalType:='string' Else
  If U='POINTER' Then MapPascalType:='REF TO data' Else
  If U='TEXT' Then MapPascalType:='string' Else
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
Const
  MAX_DEFERRED = 4000;
Var
  OutCol  : Integer;
  OutLine : TString;       { ligne courante en attente              }
  Indent  : Integer;
  RepeatLabelCounter : Integer;
  DeferredMode : Boolean;
  DeferredCount: Integer;
  DeferredLines: Array[1..MAX_DEFERRED] of TString;

Procedure FlushLine;
Begin
  If DeferredMode Then Begin
    If DeferredCount<MAX_DEFERRED Then Begin
      Inc(DeferredCount);
      DeferredLines[DeferredCount]:=OutLine;
    End;
  End Else
    WriteLn(DstFile,OutLine);
  OutLine:='';
  OutCol:=0;
End;

Procedure FlushDeferred;
Var
  K:Integer;
Begin
  For K:=1 to DeferredCount do WriteLn(DstFile,DeferredLines[K]);
  DeferredCount:=0;
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

{ Emet une ligne de commentaire complete ABAP/4 ('*' en colonne 1).
  Si une ligne est en cours, la termine d'abord. }
Procedure EmitCommentLine(S:TString);
Var
  I:Integer;
Begin
  If OutCol>0 Then FlushLine;
  OutLine:='* ';
  OutCol:=2;
  For I:=1 to Length(S) do Begin
    If S[I]=#10 Then Begin
      FlushLine;
      OutLine:='* ';
      OutCol:=2;
    End Else Begin
      OutLine:=OutLine+S[I];
      Inc(OutCol);
    End;
  End;
  FlushLine;
End;

{ Conversion d'une chaine Pascal 'abc''def' en chaine F77 'abc''def'.
  Pascal et Fortran 77 utilisent tous deux ' avec ' interne double :
  la representation est identique. }
Function PasStringToVB(S:TString):TString;
Begin
  PasStringToVB:=S;
End;

{ Conversion d'un litteral caractere Pascal #N en ABAP/4 :
  ABAP n'a pas de fonction CHR standard portable ; on utilise
  l'expression entre quote retourne directement le caractere.
  Pour le caractere de code N, on emet cl_abap_conv_in_ce ou
  un commentaire avec la valeur. }
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
  { caracteres ASCII imprimables courants }
  If V=13 Then PasCharToVB:='cl_abap_char_utilities=>cr_lf+0(1)' Else
  If V=10 Then PasCharToVB:='cl_abap_char_utilities=>newline' Else
  If V=9  Then PasCharToVB:='cl_abap_char_utilities=>horizontal_tab' Else
  If (V>=32)and(V<=126) Then Begin
    Str(V,Dec);
    PasCharToVB:=''''+Chr(V)+''''+' "#'+Dec;
  End Else Begin
    Str(V,Dec);
    PasCharToVB:='''?'' "#'+Dec+' (caractere non imprimable)';
  End;
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op=':=' Then MapOperator:='=' Else
  If Op='<>' Then MapOperator:='NE' Else
  If Op='='  Then MapOperator:='EQ' Else
  If Op='<'  Then MapOperator:='LT' Else
  If Op='>'  Then MapOperator:='GT' Else
  If Op='<=' Then MapOperator:='LE' Else
  If Op='>=' Then MapOperator:='GE' Else
  If Op='+'  Then MapOperator:='+' Else
                  MapOperator:=Op;
End;

Function MapKeyword(K:TString):TString;
Begin
  If K='AND' Then MapKeyword:='AND' Else
  If K='OR'  Then MapKeyword:='OR' Else
  If K='NOT' Then MapKeyword:='NOT' Else
  If K='DIV' Then MapKeyword:='DIV' Else
  If K='MOD' Then MapKeyword:='MOD' Else
  If K='SHL' Then MapKeyword:='" SHL non supporte' Else
  If K='SHR' Then MapKeyword:='" SHR non supporte' Else
  If K='XOR' Then MapKeyword:='" XOR non supporte' Else
  If K='TRUE' Then MapKeyword:='''X''' Else      { booleen vrai en ABAP }
  If K='FALSE' Then MapKeyword:=''' ''' Else     { booleen faux en ABAP }
  If K='NIL' Then MapKeyword:='" NIL"' Else
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

{ Emission d'un appel WriteLn(...) ou Write(...) en ABAP/4 :
    WriteLn(a,b,c) -> WRITE: / a, b, c.
    Write(a,b,c)   -> WRITE: a, b, c.
    WriteLn        -> WRITE: /.   (saute une ligne)
    Write          -> "Write sans argument" (commentaire) }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
  HasArgs,FirstArg:Boolean;
Begin
  HasArgs:=False;
  FirstArg:=True;
  If IsLn Then EmitRaw('WRITE: /')
          Else EmitRaw('WRITE:');
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    EmitRaw(' ');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw(', ');
      FirstArg:=False;
      EmitWriteArg(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then
      Inc(I);
  End Else Begin
    If Not IsLn Then Begin
      OutLine:=Copy(OutLine,1,Length(OutLine)-Length('WRITE:'));
      OutCol:=Length(OutLine);
      EmitRaw('" Write sans argument');
    End;
  End;
  If False Then HasArgs:=HasArgs;
End;

{ Emission d'un appel ReadLn(...) ou Read(...) en ABAP/4 :
  ABAP/4 n'a pas de lecture clavier interactive standard ;
  les valeurs d'entree se font via PARAMETERS (declaration au debut
  du report) ou SELECT-OPTIONS. On emet un commentaire mentionnant
  les variables a lire. }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var
  HasArgs,FirstArg:Boolean;
Begin
  HasArgs:=False;
  FirstArg:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    EmitRaw('" '); If IsLn Then EmitRaw('ReadLn(') Else EmitRaw('Read(');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw(', ');
      FirstArg:=False;
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
    EmitRaw(') -- a remplacer par PARAMETERS ou SELECT-OPTIONS');
  End Else Begin
    If IsLn Then EmitRaw('" ReadLn -- en ABAP, utiliser PARAMETERS')
            Else EmitRaw('" Read sans argument');
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
Begin
  { En ABAP/4, un FORM utilise un parametre CHANGING pour retourner
    une valeur. On laisse l'assignation ident := expr passer telle
    quelle, en supposant que le nom de la fonction est aussi le nom
    du parametre CHANGING. }
  MaybeEmitFuncReturn:=False;
End;

Function MaybeEmitElsif(Var I:Integer):Boolean;
Begin
  MaybeEmitElsif:=False;
  If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') and
     (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
    EmitRaw('ELSEIF');
    Inc(I,2);
    MaybeEmitElsif:=True;
  End;
End;

{ Emet l'en-tete d'une PROCEDURE/FUNCTION en ABAP/4.
  PROCEDURE Foo(p:Type; Var q:Type);
    -> FORM foo USING p TYPE t1
                CHANGING q TYPE t2.
  FUNCTION  Bar(p:Type):RType;
    -> FORM bar USING p TYPE t1
                CHANGING bar TYPE rtype.
       (le resultat est retourne via le parametre CHANGING de meme nom).
  Avance I jusqu'apres le ';' final de l'en-tete. }
Procedure EmitProcHeader(Var I:Integer);
Const
  MAX_PARAMS = 32;
Var
  Name,RetType:TString;
  IsFunc:Boolean;
  PNames    : Array[1..MAX_PARAMS] of TString;
  PTypes    : Array[1..MAX_PARAMS] of TString;
  PModes    : Array[1..MAX_PARAMS] of TString;
  PCount,K  : Integer;
  GroupStart,GroupEnd,M:Integer;
  CurType,CurMode:TString;
  HasUsing,HasChanging,First:Boolean;
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
      CurMode:='using';
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='VAR') Then Begin
        CurMode:='changing'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Begin
        CurMode:='using'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OUT') Then Begin
        CurMode:='changing'; Inc(I);
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
      CurType:='i';
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
  { emission de l'en-tete ABAP/4 }
  EmitRaw('FORM '); EmitRaw(Name);
  HasUsing:=False;
  HasChanging:=False;
  For K:=1 to PCount do Begin
    If PModes[K]='using' Then HasUsing:=True;
    If PModes[K]='changing' Then HasChanging:=True;
  End;
  If IsFunc Then HasChanging:=True;
  If HasUsing Then Begin
    EmitRaw(' USING');
    First:=True;
    For K:=1 to PCount do Begin
      If PModes[K]='using' Then Begin
        If First Then EmitRaw(' ') Else EmitRaw(' ');
        First:=False;
        EmitRaw(PNames[K]); EmitRaw(' TYPE '); EmitRaw(PTypes[K]);
      End;
    End;
  End;
  If HasChanging Then Begin
    EmitRaw(' CHANGING');
    First:=True;
    For K:=1 to PCount do Begin
      If PModes[K]='changing' Then Begin
        If First Then EmitRaw(' ') Else EmitRaw(' ');
        First:=False;
        EmitRaw(PNames[K]); EmitRaw(' TYPE '); EmitRaw(PTypes[K]);
      End;
    End;
    If IsFunc Then Begin
      If First Then EmitRaw(' ');
      EmitRaw(Name); EmitRaw(' TYPE '); EmitRaw(RetType);
    End;
  End;
  EmitRaw('.'); EmitLn;
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
        ReadType:='c LENGTH '+Lo;
        Exit;
      End;
      ReadType:='string';
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
    -> TYPES: BEGIN OF <typeident>,
                <field1> TYPE <type1>,
                ...
              END OF <typeident>. }
  Procedure EmitRecordBody(Const TypeIdent:TString);
  Var
    FType,Val2:TString;
    FCount,L,Pk1,Pk2:Integer;
    FNames:Array[1..32] of TString;
  Begin
    EmitRaw('TYPES: BEGIN OF '); EmitRaw(TypeIdent); EmitRaw(','); EmitLn;
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
        EmitRaw(FNames[L]);
        If Copy(FType,1,9)='__ARRAY__' Then Begin
          Val2:=Copy(FType,11,Length(FType)-10);
          Pk1:=Pos(':',Val2);
          Val2:=Copy(Val2,Pk1+1,Length(Val2));
          Pk2:=Pos(':',Val2);
          EmitRaw(' TYPE '); EmitRaw(Copy(Val2,Pk2+1,Length(Val2)));
          EmitRaw(' OCCURS '); EmitRaw(Copy(Val2,1,Pk2-1));
        End Else
        If FType='__RECORD__' Then Begin
          EmitRaw(' " RECORD imbrique non supporte');
        End Else Begin
          EmitRaw(' TYPE '); EmitRaw(FType);
        End;
        EmitRaw(','); EmitLn;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
    Dec(Indent);
    EmitRaw('       END OF '); EmitRaw(TypeIdent); EmitRaw('.'); EmitLn;
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
        { __ARRAY__:lo:hi:elt -> DATA: name TYPE elt OCCURS (hi-lo+1). }
        Val:=Copy(TypeName,11,Length(TypeName)-10);
        J:=Pos(':',Val);
        Depth:=Pos(':',Copy(Val,J+1,Length(Val)));
        For M:=1 to GCount do Begin
          EmitRaw('DATA: '); EmitRaw(Names[M]);
          EmitRaw(' TYPE '); EmitRaw(Copy(Val,J+Depth+1,Length(Val)));
          EmitRaw(' OCCURS '); EmitRaw(Copy(Val,J+1,Depth-1));
          EmitRaw('.'); EmitLn;
        End;
      End Else
      If TypeName='__RECORD__' Then Begin
        For M:=1 to GCount do
          EmitCommentLine(Names[M]+' : RECORD anonyme - utilisez TYPES: BEGIN OF ... END OF');
        Depth:=1; Inc(I);
        While (I<=TokCount) and (Depth>0) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Dec(Depth);
          Inc(I);
        End;
      End Else Begin
        EmitRaw('DATA: ');
        For M:=1 to GCount do Begin
          If M>1 Then EmitRaw(', ');
          EmitRaw(Names[M]); EmitRaw(' TYPE '); EmitRaw(TypeName);
        End;
        EmitRaw('.'); EmitLn;
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

      { lire la valeur dans Val }
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
        If (Length(Val)>0)and(Val[1]='''') Then Begin
          { Calculer la longueur du litteral chaine ABAP : Inner = Length-2,
            chaque '' interne represente 1 caractere mais consomme 2. }
          Depth:=Length(Val)-2;
          If Depth<0 Then Depth:=0;
          GCount:=0;
          For M:=2 to Length(Val)-1 do
            If Val[M]='''' Then Inc(GCount);
          Depth:=Depth-(GCount Div 2);
          If Depth<1 Then Depth:=1;
          Str(Depth,TypeName);
          TypeName:='c LENGTH '+TypeName;
        End Else
        If Pos('.',Val)>0 Then TypeName:='f' Else
                              TypeName:='i';
      End;
      EmitRaw('CONSTANTS: '); EmitRaw(Name); EmitRaw(' TYPE '); EmitRaw(TypeName);
      EmitRaw(' VALUE '); EmitRaw(Val); EmitRaw('.'); EmitLn;
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
        EmitRaw('TYPES: '); EmitRaw(Name); EmitRaw(' TYPE '); EmitRaw(TypeName);
        EmitRaw('.'); EmitLn;
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
        EmitRaw(' '); EmitRaw(MapOperator(Tokens[I].Val)); EmitRaw(' ');
      End;
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='AND' Then EmitRaw(' AND ') Else
        If K='OR' Then EmitRaw(' OR ') Else
        If K='NOT' Then EmitRaw('NOT ') Else
        If K='DIV' Then EmitRaw(' DIV ') Else
        If K='MOD' Then EmitRaw(' MOD ') Else
        If K='IN' Then EmitRaw(' " IN ensemble : non supporte ') Else
        If K='SHL' Then EmitRaw(' " SHL ') Else
        If K='SHR' Then EmitRaw(' " SHR ') Else
        If K='XOR' Then EmitRaw(' " XOR ') Else
        If K='NIL' Then EmitRaw(''' ''') Else
        If K='TRUE' Then EmitRaw('''X''') Else
        If K='FALSE' Then EmitRaw(''' ''') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:Begin
          EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        If (Length(Tokens[I].Val)>0)and(Tokens[I].Val[1]='$') Then
          EmitRaw('X'''+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-1)+'''')
        Else
          EmitRaw(Tokens[I].Val);
      End;
      TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
      TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If Tokens[I].Val=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If Tokens[I].Val='[' Then Begin Inc(Depth); EmitRaw('-'); End Else  { acces : indice ABAP varname-field ou tab[i] = tab[ i ] ; on emet [ tel quel? }
        If Tokens[I].Val=']' Then Begin Dec(Depth); End Else
        If Tokens[I].Val='^' Then EmitRaw('->') Else
        If Tokens[I].Val='@' Then EmitRaw('" @') Else
        If Tokens[I].Val='..' Then EmitRaw(' .. ') Else
        If Tokens[I].Val=':' Then EmitRaw(':') Else
        If Tokens[I].Val=',' Then EmitRaw(', ') Else
        If Tokens[I].Val='.' Then EmitRaw('-') Else  { acces a champ ABAP : structure-field }
          EmitRaw(Tokens[I].Val);
      End;
    End;
    Inc(I);
  End;
End;

{ Emet le corps d'une instruction de controle (apres THEN, ELSE, DO).
  Si BEGIN suit, consomme BEGIN..END comme bloc.
  Sinon, emet une seule instruction. }
Procedure EmitControlBody(Var I:Integer);
Begin
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
    Inc(I);                                     { sauter BEGIN              }
    EmitStatementList(I,'END');
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  End Else Begin
    { instruction unique }
    EmitStmt(I);
    If (Length(OutLine)>0)and(OutLine[Length(OutLine)]<>'.') Then EmitRaw('.');
    EmitLn;
  End;
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
  EmitRaw('IF ');
  Inc(I);                              { sauter IF                        }
  EmitExpr(I);
  EmitRaw('.');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  { ELSE / ELSE IF -> ELSEIF chaine en boucle }
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') do Begin
    If (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
      Inc(I,2);
      EmitRaw('ELSEIF ');
      EmitExpr(I);
      EmitRaw('.');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
      EmitControlBody(I);
      Dec(Indent);
    End Else Begin
      Inc(I);
      EmitRaw('ELSE.');
      EmitLn;
      Inc(Indent);
      EmitControlBody(I);
      Dec(Indent);
      Break;
    End;
  End;
  EmitRaw('ENDIF');
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
  EmitRaw('WHILE ');
  Inc(I);
  EmitExpr(I);
  EmitRaw('.');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('ENDWHILE');
End;

{ FOR i := a TO/DOWNTO b DO ... -> en ABAP/4 :
    i = a.
    WHILE i <= b. (ou >= b en DOWNTO)
      ...
      i = i + 1. (ou - 1)
    ENDWHILE.
  ABAP a aussi DO n TIMES. mais sans variable de comptage indexable. }
Procedure EmitForStatement(Var I:Integer);
Var
  Down:Boolean;
  VarName,StartE,EndE,Op,Step:TString;
  J,Depth:Integer;
Begin
  Inc(I);                                { sauter FOR                    }
  VarName:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    VarName:=Tokens[I].Val; Inc(I);
  End;
  { sauter ':=' }
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
  { lire l'expression de depart jusqu'a TO/DOWNTO }
  StartE:='';
  Depth:=0;
  While (I<=TokCount) do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='TO')or(Tokens[I].Val='DOWNTO')) Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Case Tokens[I].Kind of
      TK_OP    : StartE:=StartE+MapOperator(Tokens[I].Val);
      TK_KEYWORD:StartE:=StartE+MapKeyword(Tokens[I].Val);
      TK_STRING:StartE:=StartE+PasStringToVB(Tokens[I].Val);
      TK_CHAR  :StartE:=StartE+PasCharToVB(Tokens[I].Val);
    Else
      StartE:=StartE+Tokens[I].Val;
    End;
    Inc(I);
  End;
  Down:=False;
  Op:='<='; Step:='+ 1';
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
    Down:=True; Op:='>='; Step:='- 1'; Inc(I);
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Inc(I);
  { lire la borne }
  EndE:='';
  Depth:=0;
  While (I<=TokCount) do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Case Tokens[I].Kind of
      TK_OP    : EndE:=EndE+MapOperator(Tokens[I].Val);
      TK_KEYWORD:EndE:=EndE+MapKeyword(Tokens[I].Val);
      TK_STRING:EndE:=EndE+PasStringToVB(Tokens[I].Val);
      TK_CHAR  :EndE:=EndE+PasCharToVB(Tokens[I].Val);
    Else
      EndE:=EndE+Tokens[I].Val;
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitRaw(VarName); EmitRaw(' = '); EmitRaw(StartE); EmitRaw('.'); EmitLn;
  EmitRaw('WHILE '); EmitRaw(VarName); EmitRaw(' '); EmitRaw(Op); EmitRaw(' ');
  EmitRaw(EndE); EmitRaw('.'); EmitLn;
  Inc(Indent);
  EmitControlBody(I);
  EmitRaw(VarName); EmitRaw(' = '); EmitRaw(VarName); EmitRaw(' '); EmitRaw(Step);
  EmitRaw('.'); EmitLn;
  Dec(Indent);
  EmitRaw('ENDWHILE');
  If False Then J:=Depth;
  If False Then Down:=Down;
End;

{ REPEAT ... UNTIL c -> en ABAP/4 :
    DO.
      ...
      IF c. EXIT. ENDIF.
    ENDDO. }
Procedure EmitRepeatStatement(Var I:Integer);
Var
  BodyStart,UntilIdx,Depth,Save:Integer;
  J:Integer;
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
  EmitRaw('DO.'); EmitLn;
  Inc(Indent);
  I:=BodyStart;
  EmitStatementList(I,'UNTIL');
  If UntilIdx<>0 Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
    EmitRaw('IF ');
    Save:=UntilIdx+1;
    EmitExpr(Save);
    EmitRaw('. EXIT. ENDIF.'); EmitLn;
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
  End;
  Dec(Indent);
  EmitRaw('ENDDO');
End;

{ Marqueur pour laisser EmitRepeatStatementReal exister sans usage. }
Procedure EmitRepeatStatementOld(Var I:Integer);
Begin
  EmitRepeatStatement(I);
End;

{ Emet le selecteur d'une CASE comme expression Fortran 77 entre les
  positions SelStart..SelEnd-1, en utilisant EmitExpr. }
Procedure EmitCaseSelector(SelStart,SelEnd:Integer);
Var
  J:Integer;
Begin
  J:=SelStart;
  While J<SelEnd do Begin
    Case Tokens[J].Kind of
      TK_OP    : EmitRaw(MapOperator(Tokens[J].Val));
      TK_KEYWORD:EmitRaw(MapKeyword(Tokens[J].Val));
      TK_STRING:EmitRaw(PasStringToVB(Tokens[J].Val));
      TK_CHAR  :EmitRaw(PasCharToVB(Tokens[J].Val));
      TK_PUNCT :Begin
        If Tokens[J].Val='[' Then EmitRaw('(') Else
        If Tokens[J].Val=']' Then EmitRaw(')') Else
                                  EmitRaw(Tokens[J].Val);
      End;
    Else
      EmitRaw(Tokens[J].Val);
    End;
    Inc(J);
  End;
End;

{ Emet une condition correspondant a une liste de selecteurs Pascal :
    1, 2, 3 :       -> sel.EQ.1 .OR. sel.EQ.2 .OR. sel.EQ.3
    1..10 :         -> sel.GE.1 .AND. sel.LE.10
    1, 5..10 :      -> sel.EQ.1 .OR. (sel.GE.5 .AND. sel.LE.10)
  Avance I jusqu'au ':' qui termine la liste. }
Procedure EmitCaseLabelsAsCondition(Var I:Integer; SelStart,SelEnd:Integer);
Var
  First,IsRange:Boolean;
  Depth,Save,LabelStart:Integer;
Begin
  First:=True;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Break;
    If Not First Then Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        EmitRaw(' OR '); Inc(I); Continue;
      End;
    End;
    First:=False;
    { detecter si plage : scanner jusqu'a ',' ou ':' a la recherche de '..' }
    LabelStart:=I;
    IsRange:=False;
    Depth:=0;
    Save:=I;
    While (Save<=TokCount) do Begin
      If (Depth=0)and(Tokens[Save].Kind=TK_PUNCT)and
         ((Tokens[Save].Val=',')or(Tokens[Save].Val=':')) Then Break;
      If (Tokens[Save].Kind=TK_PUNCT)and(Tokens[Save].Val='(') Then Inc(Depth) Else
      If (Tokens[Save].Kind=TK_PUNCT)and(Tokens[Save].Val=')') Then Dec(Depth);
      If (Depth=0)and(Tokens[Save].Kind=TK_PUNCT)and(Tokens[Save].Val='..') Then Begin
        IsRange:=True;
      End;
      Inc(Save);
    End;
    If IsRange Then Begin
      EmitRaw('(');
      EmitCaseSelector(SelStart,SelEnd);
      EmitRaw(' GE ');
      Depth:=0;
      While (I<=TokCount) do Begin
        If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Break;
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
        Case Tokens[I].Kind of
          TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
          TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
          TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
      Inc(I);                                     { sauter '..'              }
      EmitRaw(' AND ');
      EmitCaseSelector(SelStart,SelEnd);
      EmitRaw(' LE ');
      Depth:=0;
      While (I<=TokCount) do Begin
        If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
           ((Tokens[I].Val=',')or(Tokens[I].Val=':')) Then Break;
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
        Case Tokens[I].Kind of
          TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
          TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
          TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
      EmitRaw(')');
    End Else Begin
      EmitCaseSelector(SelStart,SelEnd);
      EmitRaw(' EQ ');
      Depth:=0;
      While (I<=TokCount) do Begin
        If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
           ((Tokens[I].Val=',')or(Tokens[I].Val=':')) Then Break;
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
        Case Tokens[I].Kind of
          TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
          TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
          TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
    End;
    If False Then LabelStart:=LabelStart;
  End;
End;

Procedure EmitCaseStatement(Var I:Integer);
Var
  SelStart,SelEnd,Depth:Integer;
  FirstWhen:Boolean;
Begin
  Inc(I);                                  { sauter CASE                  }
  { capturer les tokens du selecteur, jusqu'a OF }
  SelStart:=I;
  Depth:=0;
  While (I<=TokCount) do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Inc(I);
  End;
  SelEnd:=I;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
  FirstWhen:=True;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
      If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
        If FirstWhen Then EmitRaw('IF 1 = 1.')
                     Else EmitRaw('ELSE.');
        EmitLn;
        Inc(Indent);
        Inc(I);
        EmitStatementList(I,'END');
        Dec(Indent);
      End;
      Break;
    End;
    If FirstWhen Then EmitRaw('IF ')
                 Else EmitRaw('ELSEIF ');
    EmitCaseLabelsAsCondition(I,SelStart,SelEnd);
    EmitRaw('.');
    EmitLn;
    FirstWhen:=False;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
    Inc(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
      Inc(I);
      EmitStatementList(I,'END');
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
    End Else Begin
      EmitStmt(I);
      If (Length(OutLine)>0)and(OutLine[Length(OutLine)]<>'.') Then EmitRaw('.');
      EmitLn;
    End;
    Dec(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  If FirstWhen Then EmitRaw('" CASE vide')
               Else EmitRaw('ENDIF');
End;

Procedure EmitBeginEnd(Var I:Integer);
Begin
  Inc(I);                                       { sauter BEGIN              }
  EmitStatementList(I,'END');
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
End;

{ Determine si la sequence de tokens commencant en I ressemble a une
  assignation Pascal "ident[...] := expr" ou "ident.field := expr".
  Utilise pour decider s'il faut prefixer un appel par CALL. }
Function LooksLikeAssignment(StartI:Integer):Boolean;
Var
  J,Depth:Integer;
Begin
  LooksLikeAssignment:=False;
  J:=StartI;
  If (J>TokCount)or(Tokens[J].Kind<>TK_IDENT) Then Exit;
  Inc(J);
  Depth:=0;
  While J<=TokCount do Begin
    If Depth=0 Then Begin
      If (Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
        LooksLikeAssignment:=True; Exit;
      End;
      If (Tokens[J].Kind=TK_PUNCT)and
         ((Tokens[J].Val=';')or(Tokens[J].Val=',')) Then Exit;
      If (Tokens[J].Kind=TK_KEYWORD) Then Exit;
    End;
    If (Tokens[J].Kind=TK_PUNCT)and
       ((Tokens[J].Val='(')or(Tokens[J].Val='[')) Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and
       ((Tokens[J].Val=')')or(Tokens[J].Val=']')) Then Dec(Depth);
    Inc(J);
  End;
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
        EmitRaw('EXIT');
        Inc(I);
      End Else
      If K='HALT' Then Begin
        EmitRaw('LEAVE PROGRAM');
        Inc(I);
        { sauter eventuellement un argument (...) }
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
          If I<=TokCount Then Inc(I);
        End;
      End Else
      If K='BREAK' Then Begin
        EmitRaw('EXIT');
        Inc(I);
      End Else
      If K='CONTINUE' Then Begin
        EmitRaw('CONTINUE');     { ABAP/4 a CONTINUE pour passer a iter. suivante }
        Inc(I);
      End Else
      If K='WITH' Then Begin
        EmitCommentLine('WITH non supporte en ABAP ; expansion manuelle requise');
        { sauter jusqu'au DO }
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do
          Inc(I);
        If I<=TokCount Then Inc(I);
        EmitStmt(I);
      End Else
      If K='GOTO' Then Begin
        EmitRaw('GOTO ');
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
        { Pascal "FuncName := expr" -> assignation directe en F77 }
        If MaybeEmitFuncReturn(I) Then Begin
        End Else Begin
          { Si l'identifiant est une procedure connue (subroutine F77),
            preceder l'appel par CALL. Une assignation est detectee si
            le token apres l'identifiant et ses ([..]) eventuels est ':='. }
          FIdx:=FindFunc(Tokens[I].Val);
          If (FIdx>0) and (not Funcs[FIdx].IsFunc) and
             (not LooksLikeAssignment(I)) Then Begin
            EmitRaw('PERFORM ');
            EmitRaw(Tokens[I].Val);
            Inc(I);
            { transformer (a,b,c) en USING a b c }
            If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
              EmitRaw(' USING');
              Inc(I);
              FIdx:=1;          { reutilise FIdx comme depth                  }
              While (I<=TokCount) do Begin
                If (FIdx=1)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
                  Inc(I); Break;
                End;
                If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(FIdx) Else
                If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(FIdx);
                If (FIdx=1)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
                  EmitRaw(' '); Inc(I); Continue;
                End;
                EmitRaw(' ');
                Case Tokens[I].Kind of
                  TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
                  TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
                  TK_STRING:EmitRaw(PasStringToVB(Tokens[I].Val));
                  TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
                Else
                  EmitRaw(Tokens[I].Val);
                End;
                Inc(I);
                { si pas une virgule consommee, on emet un espace         }
                If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and
                   ((Tokens[I].Val=',')or(Tokens[I].Val=')')) Then Continue;
              End;
            End;
          End Else
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
  SaveIndent:Integer;
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
        EmitCommentLine('LABEL section ignoree en ABAP');
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
        If I<=TokCount Then Inc(I);
      End Else
      If (K='PROCEDURE')or(K='FUNCTION') Then Begin
        { En ABAP les FORM doivent etre declarees au niveau du report :
          on bufferise leur emission pour les ressortir apres le corps
          du programme principal, en remettant l'indentation a 0. }
        SaveIndent:=Indent;
        If IsTopLevel Then Begin
          DeferredMode:=True;
          Indent:=0;
        End;
        EmitProcHeader(I);
        Inc(Indent);
        EmitBlock(I,False);
        Dec(Indent);
        If IsTopLevel Then DeferredMode:=False;
        Indent:=SaveIndent;
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
        FlushDeferred;
      End Else Begin
        EmitRaw('ENDFORM.');
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
    End;
  End;
  CurFunc:=PrevFunc;
End;

{ Emet la clause USES Pascal en commentaire F77.
  Fortran 77 n'a pas d'instruction d'import au niveau du source ;
  les modules externes sont resolus a l'edition de liens. }
Procedure EmitUses(Var I:Integer);
Var
  Names:Array[1..MAX_USES] of TString;
  ICount,K:Integer;
  Buf:TString;
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
    Buf:='Pascal USES : ';
    First:=True;
    For K:=1 to ICount do Begin
      If Not First Then Buf:=Buf+', ';
      First:=False;
      Buf:=Buf+Names[K];
    End;
    Buf:=Buf+' (a remplacer par modules F77 correspondants)';
    EmitCommentLine(Buf);
  End;
End;

{ Emet l'en-tete d'un programme Fortran 77 (.f) :
    C commentaire de generation
          PROGRAM NAME
          IMPLICIT NONE
          ...
          STOP
          END
  Le 'STOP' / 'END' final sera emis par EmitBlock. }
Procedure EmitModuleHeader(Var I:Integer);
Var
  J:Integer;
Begin
  EmitCommentLine('Genere par PAS2ABP '+PAS2ABP_VERSION+' a partir de Pascal');
  EmitCommentLine('');
  EmitRaw('REPORT '); EmitRaw(ProgName); EmitRaw('.'); EmitLn;
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
  WriteLn('PAS2ABP ',PAS2ABP_VERSION,' - Transpilateur Pascal vers ABAP/4');
  WriteLn;
  WriteLn('Syntaxe : PAS2ABP [-v] source.pas [destination.abap]');
  WriteLn;
  WriteLn('  source.pas        Fichier source Pascal (Turbo Pascal/FPC).');
  WriteLn('  destination.abap  Fichier ABAP/4 a generer (defaut : source.abap).');
  WriteLn('  -v / --verbose    Afficher des messages de progression.');
  WriteLn('  -h / --help       Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : PAS2ABP hello.pas hello.abap');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.abap'
                          Else DstName:=A+'.abap';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2ABP : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    Close(SrcFile);
    WriteLn('PAS2ABP : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;
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
  If Verbose Then WriteLn('PAS2ABP : tokenisation de ',SrcName,'...');
  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('PAS2ABP : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('PAS2ABP : programme = ',ProgName);
    WriteLn('PAS2ABP : ',FuncCount,' procedure(s)/fonction(s).');
    If UsesOut Then WriteLn('PAS2ABP : Out detecte.');
    If UsesIn  Then WriteLn('PAS2ABP : In detecte.');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2ABP : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;

  OutLine:='';
  OutCol:=0;
  Indent:=0;
  CurFunc:=0;
  FuncSP:=0;
  RepeatLabelCounter:=0;
  DeferredMode:=False;
  DeferredCount:=0;
  IPos:=1;
  EmitModuleHeader(IPos);
  EmitBlock(IPos,True);
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('PAS2ABP : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
