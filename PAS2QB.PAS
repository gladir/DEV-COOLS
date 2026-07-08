{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Turbo Pascal vers QBasic/QuickBasic (.bas)
}

(* ============================================================
   PAS2QB.PAS - Transpilateur Turbo Pascal vers QBasic/QuickBasic
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source QBasic/QuickBasic (.bas) compatible
           QuickBasic 4.5 / QBasic 1.1 / QB64.

   QBasic est un dialecte BASIC structure avec types declares.
   Caracteristiques :
     - typage statique (DIM x AS INTEGER, sigils $ % ! # &)
     - blocs : SUB...END SUB, FUNCTION...END FUNCTION,
               IF...END IF, WHILE...WEND, FOR...NEXT,
               DO...LOOP, SELECT CASE...END SELECT
     - PRINT pour sortie, INPUT pour entree
     - commentaires : ligne commencant par '
     - separateur d instructions : retour de ligne ou :

   Couvre les constructions courantes :
     PROGRAM/UNIT     -> commentaire (QBasic n a pas de program-id).
     USES             -> commentaire ($INCLUDE possible).
     CONST            -> CONST nom = valeur.
     TYPE record      -> TYPE Nom : champ AS type : END TYPE.
     VAR              -> DIM nom AS type.
     PROCEDURE        -> SUB name (args) ... END SUB
     FUNCTION         -> FUNCTION name (args) AS type ... END FUNCTION
     BEGIN..END       -> sequence d instructions.
     IF..THEN..ELSE   -> IF cond THEN .. ELSE .. END IF.
     WHILE..DO        -> WHILE cond .. WEND
     REPEAT..UNTIL    -> DO .. LOOP UNTIL cond
     FOR..TO/DOWNTO   -> FOR i = a TO b [STEP -1] .. NEXT i.
     CASE..OF         -> SELECT CASE x : CASE v : .. : CASE ELSE : .. : END SELECT.
     Write/WriteLn    -> PRINT a; b; (avec ; final pour Write).
     Read/ReadLn      -> INPUT var.
     := simple        -> =
     operateurs Pascal -> QBasic :
       =,<>,<,>,<=,>= -> =, <>, <, >, <=, >=
       AND/OR/NOT     -> AND/OR/NOT
       DIV            -> \  (division entiere QBasic)
       MOD            -> MOD
       TRUE/FALSE     -> -1/0
       NIL            -> 0
     concatenation Pascal sur chaine -> + en QBasic

   Limitations connues :
     - les pointeurs Pascal n ont pas d equivalent direct.
     - les types Pascal complexes (SET, FILE) sont commentes.
     - WITH non supporte (commentaire).
     - les CASE avec plages utilisent CASE a TO b natif QBasic.
   ============================================================ *)

Program PAS2QB;



{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PAS2QB_VERSION = '1.0';
  PAS2QB_DATE    = '2026-04-27';

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
    WriteLn('PAS2QB : trop de tokens (>',MAX_TOKEN,')');
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
      WriteLn('PAS2QB : chaine non terminee ligne ',SrcLineNo);
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

{ AWK est typÃ© dynamiquement : les "types" servent juste d'indication
  pour l'initialisation des valeurs. On retourne une valeur initiale
  par defaut comme commentaire d'aide. }
Function MapPascalType(T:TString):TString;
Var
  U:TString;
Begin
  U:=StrUpper(T);
  If U='INTEGER' Then MapPascalType:='INTEGER' Else
  If U='LONGINT' Then MapPascalType:='LONG' Else
  If U='LONGWORD' Then MapPascalType:='LONG' Else
  If U='CARDINAL' Then MapPascalType:='LONG' Else
  If U='SHORTINT' Then MapPascalType:='INTEGER' Else
  If U='SMALLINT' Then MapPascalType:='INTEGER' Else
  If U='BYTE' Then MapPascalType:='INTEGER' Else
  If U='WORD' Then MapPascalType:='LONG' Else
  If U='INT64' Then MapPascalType:='LONG' Else
  If U='QWORD' Then MapPascalType:='LONG' Else
  If U='REAL' Then MapPascalType:='SINGLE' Else
  If U='SINGLE' Then MapPascalType:='SINGLE' Else
  If U='DOUBLE' Then MapPascalType:='DOUBLE' Else
  If U='EXTENDED' Then MapPascalType:='DOUBLE' Else
  If U='BOOLEAN' Then MapPascalType:='INTEGER' Else
  If U='CHAR' Then MapPascalType:='STRING' Else
  If U='STRING' Then MapPascalType:='STRING' Else
  If U='ANSISTRING' Then MapPascalType:='STRING' Else
  If U='POINTER' Then MapPascalType:='LONG' Else
  If U='TEXT' Then MapPascalType:='INTEGER' Else
  MapPascalType:=T;     { type utilisateur : nom du type Pascal d'origine }
End;

{ Retourne la valeur initiale par defaut pour un type QBasic donne. }
Function QBDefaultValue(QbType:TString):TString;
Var
  U:TString;
Begin
  U:=StrUpper(QbType);
  If U='STRING' Then QBDefaultValue:='""' Else
  If (U='SINGLE')or(U='DOUBLE') Then QBDefaultValue:='0.0' Else
  QBDefaultValue:='0';
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
  MAX_DECL     = 4000;
  MAX_MAIN     = 8000;
Var
  OutCol  : Integer;
  OutLine : TString;       { ligne courante en attente              }
  Indent  : Integer;
  RepeatLabelCounter : Integer;
  DeferredMode : Boolean;            { mode paragraphe (FORM proc)  }
  DeferredCount: Integer;
  DeferredLines: Array[1..MAX_DEFERRED] of TString;
  DeclMode     : Boolean;            { mode WORKING-STORAGE         }
  DeclCount    : Integer;
  DeclLines    : Array[1..MAX_DECL] of TString;
  MainCount    : Integer;
  MainLines    : Array[1..MAX_MAIN] of TString;
  CapturingMain: Boolean;            { true tant que le corps principal est capture }

Procedure FlushLine;
Begin
  If DeclMode Then Begin
    If DeclCount<MAX_DECL Then Begin
      Inc(DeclCount);
      DeclLines[DeclCount]:=OutLine;
    End;
  End Else
  If DeferredMode Then Begin
    If DeferredCount<MAX_DEFERRED Then Begin
      Inc(DeferredCount);
      DeferredLines[DeferredCount]:=OutLine;
    End;
  End Else
  If CapturingMain Then Begin
    If MainCount<MAX_MAIN Then Begin
      Inc(MainCount);
      MainLines[MainCount]:=OutLine;
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

Procedure FlushDecls;
Var
  K:Integer;
Begin
  For K:=1 to DeclCount do WriteLn(DstFile,DeclLines[K]);
End;

Procedure FlushMain;
Var
  K:Integer;
Begin
  For K:=1 to MainCount do WriteLn(DstFile,MainLines[K]);
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

{ Emet une ligne de commentaire AWK ('# ...') et termine la ligne en
  cours s'il y en a une. }
Procedure EmitCommentLine(S:TString);
Var
  I:Integer;
Begin
  If OutCol>0 Then FlushLine;
  OutLine:=''' ';
  OutCol:=2;
  For I:=1 to Length(S) do Begin
    If S[I]=#10 Then Begin
      FlushLine;
      OutLine:=''' ';
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

{ Conversion d'un litteral caractere Pascal #N en AWK.
  AWK utilise sprintf("%c", N) pour les caracteres non imprimables.
  Pour les caracteres imprimables, on emet le litteral entre guillemets. }
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
  If V=10 Then PasCharToVB:='CHR$(10)' Else
  If V=13 Then PasCharToVB:='CHR$(13)' Else
  If V=9  Then PasCharToVB:='CHR$(9)' Else
  If V=34 Then PasCharToVB:='CHR$(34)' Else
  If (V>=32)and(V<=126) Then Begin
    PasCharToVB:='"'+Chr(V)+'"';
  End Else Begin
    Str(V,Dec);
    PasCharToVB:='CHR$('+Dec+')';
  End;
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op=':=' Then MapOperator:='=' Else
  If Op='<>' Then MapOperator:='<>' Else
  If Op='='  Then MapOperator:='=' Else
  If Op='<'  Then MapOperator:='<' Else
  If Op='>'  Then MapOperator:='>' Else
  If Op='<=' Then MapOperator:='<=' Else
  If Op='>=' Then MapOperator:='>=' Else
                  MapOperator:=Op;
End;

Function MapKeyword(K:TString):TString;
Begin
  If K='AND' Then MapKeyword:='AND' Else
  If K='OR'  Then MapKeyword:='OR' Else
  If K='NOT' Then MapKeyword:='NOT' Else
  If K='DIV' Then MapKeyword:='\' Else
  If K='MOD' Then MapKeyword:='MOD' Else
  If K='SHL' Then MapKeyword:='__SHL__' Else
  If K='SHR' Then MapKeyword:='__SHR__' Else
  If K='XOR' Then MapKeyword:='XOR' Else
  If K='TRUE' Then MapKeyword:='-1' Else
  If K='FALSE' Then MapKeyword:='0' Else
  If K='NIL' Then MapKeyword:='0' Else
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
  J:=I;
  While J<=TokCount do Begin
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and
       ((Tokens[J].Val=',')or(Tokens[J].Val=')')) Then Break;
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Break;
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
    Inc(J);
  End;
  While I<J do Begin
    Case Tokens[I].Kind of
      TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
      TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
      TK_STRING:EmitRaw('"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"');
      TK_CHAR  : EmitRaw(PasCharToVB(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='[' Then EmitRaw('[') Else
        If Tokens[I].Val=']' Then EmitRaw(']') Else
        If Tokens[I].Val='.' Then EmitRaw('.') Else
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

{ Emission d'un appel WriteLn(...) ou Write(...) en AWK :
    WriteLn(a,b,c) -> print a, b, c
    Write(a,b,c)   -> printf "%s%s%s", a, b, c
    WriteLn        -> print ""
    Write          -> # (commentaire) }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
  FirstArg:Boolean;
Begin
  FirstArg:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    EmitRaw('PRINT ');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw('; ');
      FirstArg:=False;
      EmitWriteArg(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
    { Sans IsLn : Write -> ajouter ';' final pour empecher le saut de ligne }
    If Not IsLn Then EmitRaw(';');
  End Else Begin
    If IsLn Then EmitRaw('PRINT')
            Else EmitRaw(''' Write sans argument');
  End;
End;

{ Emission d'un appel ReadLn(...) ou Read(...) en QBasic : INPUT. }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var
  FirstArg:Boolean;
  VName:TString;
Begin
  FirstArg:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then Begin
        EmitRaw(' : ');
      End;
      FirstArg:=False;
      VName:='';
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and
            ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do Begin
        Case Tokens[I].Kind of
          TK_OP    : VName:=VName+MapOperator(Tokens[I].Val);
          TK_KEYWORD:VName:=VName+MapKeyword(Tokens[I].Val);
          TK_PUNCT :Begin
            If Tokens[I].Val='.' Then VName:=VName+'.' Else
              VName:=VName+Tokens[I].Val;
          End;
        Else
          VName:=VName+Tokens[I].Val;
        End;
        Inc(I);
      End;
      EmitRaw('INPUT "", '); EmitRaw(VName);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End Else Begin
    If IsLn Then EmitRaw('INPUT "", __dummy__$')
            Else EmitRaw(''' Read sans argument');
  End;
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
  { En AWK, un FORM utilise un parametre CHANGING pour retourner
    une valeur. On laisse l'assignation ident := expr passer telle
    quelle, en supposant que le nom de la fonction est aussi le nom
    du parametre CHANGING. }
  MaybeEmitFuncReturn:=False;
End;

{ Emet une assignation Pascal "ident[...]/.field := expr" en AWK :
    - si expr est un seul atome (litteral, identifiant), MOVE expr TO var.
    - sinon, COMPUTE var = expr.
  Si le nom est celui de la fonction englobante, on emet l'affectation
  vers <Name>-RESULT (variable globale conventionnelle).
  Avance I jusqu'apres l'expression. }
Procedure EmitAssignment(Var I:Integer);
Var
  LhsStart:Integer;
  Lhs:TString;
  Depth:Integer;
Begin
  LhsStart:=I;
  Lhs:='';
  Depth:=0;
  { lire le LHS jusqu'a ':=' au niveau 0 }
  While I<=TokCount do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and
       ((Tokens[I].Val='(')or(Tokens[I].Val='[')) Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and
       ((Tokens[I].Val=')')or(Tokens[I].Val=']')) Then Dec(Depth);
    Case Tokens[I].Kind of
      TK_PUNCT:Begin
        If Tokens[I].Val='.' Then Lhs:=Lhs+'.' Else
          Lhs:=Lhs+Tokens[I].Val;
      End;
      TK_KEYWORD:Lhs:=Lhs+MapKeyword(Tokens[I].Val);
    Else
      Lhs:=Lhs+Tokens[I].Val;
    End;
    Inc(I);
  End;
  { En QBasic, `name := value` dans la fonction `name` est deja correct
    (assignation au nom de la fonction). Conserver Lhs tel quel. }
  { sauter ':=' }
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
  EmitRaw(Lhs); EmitRaw(' = ');
  EmitExpr(I);
End;

{ Emet l'en-tete d'une PROCEDURE/FUNCTION en AWK.
  En AWK, un sous-programme est typiquement implemente comme un
  paragraphe ou une SECTION qu'on appelle via PERFORM. Les parametres
  ne sont pas natifs au modele paragraphe : ils doivent etre passes
  par des variables globales. On genere :
     <Name>-PARA SECTION.
       *> parametres : p1 p2 ...
       *> retour : <Name>-RESULT (pour FUNCTION)
       <corps>.
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
  CurType,CurMode,Buf:TString;
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
      CurMode:='in';
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='VAR') Then Begin
        CurMode:='inout'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Begin
        CurMode:='in'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OUT') Then Begin
        CurMode:='out'; Inc(I);
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
      CurType:='PIC S9(9)';
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
  { Emission de l'en-tete AWK : paragraphe avec commentaires
    decrivant les parametres et le type de retour. }
  EmitLn;
  If IsFunc Then EmitRaw('FUNCTION ') Else EmitRaw('SUB ');
  EmitRaw(Name); EmitRaw(' (');
  For K:=1 to PCount do Begin
    If K>1 Then EmitRaw(', ');
    EmitRaw(PNames[K]);
    If PTypes[K]<>'' Then Begin
      EmitRaw(' AS '); EmitRaw(PTypes[K]);
    End;
  End;
  EmitRaw(')');
  If IsFunc and (RetType<>'') Then Begin
    EmitRaw(' AS '); EmitRaw(RetType);
  End;
  EmitLn;
  Inc(Indent);
  If PCount>0 Then Begin
    Buf:=''' Parametres :';
    For K:=1 to PCount do Begin
      Buf:=Buf+' '+PNames[K]+' ('+PModes[K]+')';
      If K<PCount Then Buf:=Buf+',';
    End;
    EmitCommentLine(Copy(Buf,3,Length(Buf)-2));
  End;
End;

{ Emet une declaration VAR / CONST / TYPE en syntaxe AWK DATA DIVISION.

  Pascal VAR :   x, y : Integer;        ->  01 X PIC S9(9). 01 Y PIC S9(9).
  Pascal CONST:  Pi = 3.14;             ->  01 PI USAGE COMP-2 VALUE 3.14.
  Pascal TYPE :  TPoint = Record ...End;->  01 TPoint. 05 ... PIC ...

  Toutes les declarations sont bufferisees dans DeclLines via DeclMode
  pour etre emises dans la WORKING-STORAGE SECTION avant la PROCEDURE
  DIVISION.

  Pour les types non triviaux (ARRAY, RECORD imbrique, SET, FILE),
  une approximation est emise avec un commentaire d'avertissement. }
{ Emet une declaration VAR / CONST / TYPE en AWK. AWK est typÃ©
  dynamiquement : on Ã©met seulement des initialisations dans BEGIN.

  Pascal VAR :   x, y : Integer;        ->  x = 0; y = 0
  Pascal CONST:  Pi = 3.14;             ->  PI = 3.14
  Pascal TYPE :  TPoint = Record ...End;->  # type TPoint : champs ...
}
Procedure EmitDeclSection(Var I:Integer; SectKw:TString);
Var
  K,Name,TypeName,Val,InitVal,FieldName:TString;
  Depth,GCount,M:Integer;
  Names:Array[1..32] of TString;
  SavedMode:Boolean;

  { Lire un type Pascal et retourner soit un tag interne soit
    une valeur initiale par defaut AWK. }
  Function ReadType:TString;
  Var
    R,Lo,Hi:TString;
  Begin
    R:='INTEGER';
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
      If (I<=TokCount) Then Inc(I);
      ReadType:='__ARRAY__';
      Exit;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='STRING') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']')) do Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Inc(I);
      End;
      ReadType:='STRING';
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

Begin
  SavedMode:=DeclMode;
  DeclMode:=True;
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
      If TypeName='__ARRAY__' Then Begin
        For M:=1 to GCount do Begin
          EmitCommentLine('tableau '+Names[M]+' : utiliser DIM '+Names[M]+'(taille)');
          EmitRaw('DIM '); EmitRaw(Names[M]); EmitRaw('(100)'); EmitLn;
        End;
      End Else
      If TypeName='__RECORD__' Then Begin
        For M:=1 to GCount do Begin
          EmitCommentLine('record '+Names[M]+' : champs traites individuellement');
        End;
        Inc(I);
        Depth:=1;
        FieldName:='';
        While (I<=TokCount) and (Depth>0) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
            Dec(Depth); Inc(I); If Depth=0 Then Break Else Continue;
          End;
          If (Depth=1)and(Tokens[I].Kind=TK_IDENT) Then Begin
            FieldName:=Tokens[I].Val;
            For M:=1 to GCount do Begin
              EmitRaw('DIM '+Names[M]+'_'+FieldName+' AS INTEGER'); EmitLn;
            End;
          End;
          Inc(I);
        End;
      End Else Begin
        For M:=1 to GCount do Begin
          EmitRaw('DIM '); EmitRaw(Names[M]);
          EmitRaw(' AS '); EmitRaw(TypeName); EmitLn;
        End;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End Else
    If StrEqualCI(SectKw,'CONST') Then Begin
      Name:=Tokens[I].Val; Inc(I);
      TypeName:='';
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
        Inc(I);
        TypeName:=ReadType;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I)
      Else
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='=') Then Inc(I);
      Val:='';
      Depth:=0;
      While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
        Case Tokens[I].Kind of
          TK_STRING:Val:=Val+'"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
          TK_CHAR  :Val:=Val+PasCharToVB(Tokens[I].Val);
          TK_OP    :Val:=Val+MapOperator(Tokens[I].Val);
          TK_KEYWORD:Val:=Val+MapKeyword(Tokens[I].Val);
        Else
          Val:=Val+Tokens[I].Val;
        End;
        Inc(I);
      End;
      EmitRaw('CONST '); EmitRaw(Name); EmitRaw(' = '); EmitRaw(Val); EmitLn;
      If False Then InitVal:=TypeName;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End Else
    If StrEqualCI(SectKw,'TYPE') Then Begin
      Name:=Tokens[I].Val; Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Inc(I)
      Else
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='=') Then Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Begin
        EmitRaw('TYPE '); EmitRaw(Name); EmitLn;
        Inc(I);
        Depth:=1;
        FieldName:='';
        While (I<=TokCount) and (Depth>0) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
            Dec(Depth); Inc(I); If Depth=0 Then Break Else Continue;
          End;
          { Detecter "field : type ;" }
          If (Depth=1)and(Tokens[I].Kind=TK_IDENT) Then Begin
            FieldName:=Tokens[I].Val;
            Inc(I);
            { sauter les ", autre_champ" eventuels }
            While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
              Inc(I);
              If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
                EmitRaw('  '); EmitRaw(FieldName); EmitRaw(' AS INTEGER'); EmitLn;
                FieldName:=Tokens[I].Val; Inc(I);
              End;
            End;
            If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
              Inc(I);
              If (I<=TokCount) Then Begin
                EmitRaw('  '); EmitRaw(FieldName); EmitRaw(' AS '); EmitRaw(MapPascalType(Tokens[I].Val));
                EmitLn;
                Inc(I);
              End;
            End;
            Continue;
          End;
          Inc(I);
        End;
        EmitRaw('END TYPE'); EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
      End Else Begin
        TypeName:=ReadType;
        EmitCommentLine('TYPE '+Name+' = '+TypeName);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
      End;
    End Else
      Inc(I);
  End;
  DeclMode:=SavedMode;
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
        If K='DIV' Then EmitRaw(' \ ') Else
        If K='MOD' Then EmitRaw(' MOD ') Else
        If K='IN' Then EmitRaw(' '' IN '' ') Else
        If K='SHL' Then EmitRaw(' '' SHL '' ') Else
        If K='SHR' Then EmitRaw(' '' SHR '' ') Else
        If K='XOR' Then EmitRaw(' XOR ') Else
        If K='NIL' Then EmitRaw('0') Else
        If K='TRUE' Then EmitRaw('-1') Else
        If K='FALSE' Then EmitRaw('0') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:Begin
          EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        If (Length(Tokens[I].Val)>0)and(Tokens[I].Val[1]='$') Then
          EmitRaw('0x'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-1))
        Else
          EmitRaw(Tokens[I].Val);
      End;
      TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:Begin
        K:='"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
        EmitRaw(K);
      End;
      TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If Tokens[I].Val=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If Tokens[I].Val='[' Then Begin Inc(Depth); EmitRaw('['); End Else
        If Tokens[I].Val=']' Then Begin Dec(Depth); EmitRaw(']'); End Else
        If Tokens[I].Val='^' Then EmitRaw('') Else
        If Tokens[I].Val='@' Then EmitRaw('') Else
        If Tokens[I].Val='..' Then EmitRaw(',') Else
        If Tokens[I].Val=':' Then EmitRaw(':') Else
        If Tokens[I].Val=',' Then EmitRaw(', ') Else
        If Tokens[I].Val='.' Then EmitRaw('.') Else       { struct.field -> struct_field }
          EmitRaw(Tokens[I].Val);
      End;
    End;
    Inc(I);
  End;
End;

{ Emet le corps d'une instruction de controle (apres THEN, ELSE, DO).
  En QBasic : juste les instructions, le bloc est delimite par
  THEN/DO/ELSE et END IF/WEND/NEXT/LOOP qui sont emis par l'appelant. }
Procedure EmitControlBody(Var I:Integer);
Begin
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
    Inc(I);
    EmitStatementList(I,'END');
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  End Else Begin
    EmitStmt(I);
    EmitLn;
  End;
  Dec(Indent);
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
  EmitRaw('IF ');
  Inc(I);                              { sauter IF                        }
  EmitExpr(I);
  EmitRaw(' THEN');
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitControlBody(I);
  { ELSE / ELSE IF }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') Then Begin
    Inc(I);
    EmitRaw('ELSE');
    EmitControlBody(I);
  End;
  EmitRaw('END IF');
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
  EmitRaw('WHILE ');
  Inc(I);
  EmitExpr(I);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  EmitRaw('WEND');
End;

{ FOR i := a TO/DOWNTO b DO ... -> en QBasic :
    FOR i = a TO b ... NEXT i
    FOR i = a TO b STEP -1 ... NEXT i  (DOWNTO) }
Procedure EmitForStatement(Var I:Integer);
Var
  Down:Boolean;
  VarName,StartE,EndE:TString;
  Depth:Integer;
Begin
  Inc(I);                                { sauter FOR                    }
  VarName:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    VarName:=Tokens[I].Val; Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val=':=') Then Inc(I);
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
      TK_STRING:StartE:=StartE+'"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
      TK_CHAR  :StartE:=StartE+PasCharToVB(Tokens[I].Val);
    Else
      StartE:=StartE+Tokens[I].Val;
    End;
    Inc(I);
  End;
  Down:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
    Down:=True; Inc(I);
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Inc(I);
  EndE:='';
  Depth:=0;
  While (I<=TokCount) do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Case Tokens[I].Kind of
      TK_OP    : EndE:=EndE+MapOperator(Tokens[I].Val);
      TK_KEYWORD:EndE:=EndE+MapKeyword(Tokens[I].Val);
      TK_STRING:EndE:=EndE+'"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
      TK_CHAR  :EndE:=EndE+PasCharToVB(Tokens[I].Val);
    Else
      EndE:=EndE+Tokens[I].Val;
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitRaw('FOR '); EmitRaw(VarName); EmitRaw(' = '); EmitRaw(StartE);
  EmitRaw(' TO '); EmitRaw(EndE);
  If Down Then EmitRaw(' STEP -1');
  EmitControlBody(I);
  EmitRaw('NEXT '); EmitRaw(VarName);
End;

{ REPEAT ... UNTIL c -> en QBasic : DO ... LOOP UNTIL c }
Procedure EmitRepeatStatement(Var I:Integer);
Begin
  Inc(I);                                  { sauter REPEAT                }
  EmitRaw('DO'); EmitLn;
  Inc(Indent);
  EmitStatementList(I,'UNTIL');
  Dec(Indent);
  EmitRaw('LOOP UNTIL ');
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
  EmitExpr(I);
End;

Procedure EmitRepeatStatementOld(Var I:Integer);
Begin
  EmitRepeatStatement(I);
End;

{ Emet le selecteur d'une CASE comme variable AWK. SelStart..SelEnd-1
  contient le selecteur source. }
Procedure EmitCaseSelector(SelStart,SelEnd:Integer);
Var
  J:Integer;
Begin
  J:=SelStart;
  While J<SelEnd do Begin
    Case Tokens[J].Kind of
      TK_OP    : EmitRaw(MapOperator(Tokens[J].Val));
      TK_KEYWORD:EmitRaw(MapKeyword(Tokens[J].Val));
      TK_STRING:EmitRaw('"'+Copy(Tokens[J].Val,2,Length(Tokens[J].Val)-2)+'"');
      TK_CHAR  :EmitRaw(PasCharToVB(Tokens[J].Val));
      TK_PUNCT :Begin
        If Tokens[J].Val='.' Then EmitRaw('.') Else
                                  EmitRaw(Tokens[J].Val);
      End;
    Else
      EmitRaw(Tokens[J].Val);
    End;
    Inc(J);
  End;
End;

{ Emet une liste de selecteurs Pascal sous forme de liste de cas QBasic :
    1, 2, 3 :   -> "1, 2, 3"
    1..10 :     -> "1 TO 10"
  Le selecteur source n'est pas utilise (QBasic gere nativement). }
Procedure EmitCaseLabelsAsCondition(Var I:Integer; Const SelText:TString);
Var
  First:Boolean;
  Depth:Integer;
  Lo,Hi:TString;
Begin
  First:=True;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
      Inc(I); Continue;
    End;
    If Not First Then EmitRaw(', ');
    First:=False;
    Lo:=''; Hi:='';
    Depth:=0;
    While (I<=TokCount) do Begin
      If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val=',')or(Tokens[I].Val=':')) Then Break;
      If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='..') Then Begin
        Inc(I);
        While (I<=TokCount) do Begin
          If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
             ((Tokens[I].Val=',')or(Tokens[I].Val=':')) Then Break;
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
          Case Tokens[I].Kind of
            TK_KEYWORD:Hi:=Hi+MapKeyword(Tokens[I].Val);
            TK_STRING:Hi:=Hi+'"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
            TK_CHAR  :Hi:=Hi+PasCharToVB(Tokens[I].Val);
          Else
            Hi:=Hi+Tokens[I].Val;
          End;
          Inc(I);
        End;
        Break;
      End;
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
      Case Tokens[I].Kind of
        TK_KEYWORD:Lo:=Lo+MapKeyword(Tokens[I].Val);
        TK_STRING:Lo:=Lo+'"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"';
        TK_CHAR  :Lo:=Lo+PasCharToVB(Tokens[I].Val);
      Else
        Lo:=Lo+Tokens[I].Val;
      End;
      Inc(I);
    End;
    If Hi<>'' Then Begin
      EmitRaw(Lo); EmitRaw(' TO '); EmitRaw(Hi);
    End Else Begin
      EmitRaw(Lo);
    End;
  End;
  If False Then If SelText='' Then ;
End;

{ CASE x OF v1: s1; v2..v3: s2; ELSE s3; END
  -> en Lua :
       if (x == v1) then s1
       elseif (x >= v2 and x <= v3) then s2
       else s3
       end
}
Procedure EmitCaseStatement(Var I:Integer);
Var
  SelStart,SelEnd,Depth,SaveI,K:Integer;
  SelText:TString;
  HasElse,FirstClause:Boolean;
Begin
  Inc(I);                                  { sauter CASE                  }
  SelStart:=I;
  Depth:=0;
  While (I<=TokCount) do Begin
    If (Depth=0)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Break;
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
    Inc(I);
  End;
  SelEnd:=I;
  SelText:='';
  K:=SelStart;
  While K<SelEnd do Begin
    Case Tokens[K].Kind of
      TK_OP    : SelText:=SelText+MapOperator(Tokens[K].Val);
      TK_KEYWORD:SelText:=SelText+MapKeyword(Tokens[K].Val);
      TK_STRING:SelText:=SelText+'"'+Copy(Tokens[K].Val,2,Length(Tokens[K].Val)-2)+'"';
      TK_CHAR  :SelText:=SelText+PasCharToVB(Tokens[K].Val);
      TK_PUNCT :Begin
        If Tokens[K].Val='.' Then SelText:=SelText+'.'
                             Else SelText:=SelText+Tokens[K].Val;
      End;
    Else
      SelText:=SelText+Tokens[K].Val;
    End;
    Inc(K);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
  EmitRaw('SELECT CASE '); EmitRaw(SelText); EmitLn;
  FirstClause:=True;
  HasElse:=False;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
      If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
        HasElse:=True;
        Inc(I);
        EmitRaw('CASE ELSE'); EmitLn;
        Inc(Indent);
        EmitStatementList(I,'END');
        Dec(Indent);
      End;
      Break;
    End;
    EmitRaw('CASE ');
    If FirstClause Then FirstClause:=False;
    EmitCaseLabelsAsCondition(I,SelText);
    EmitLn;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
    Inc(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
      Inc(I);
      EmitStatementList(I,'END');
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
    End Else Begin
      EmitStmt(I);
      EmitLn;
    End;
    Dec(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  EmitRaw('END SELECT');
  If False Then Begin SaveI:=SelStart; SelEnd:=SelEnd; HasElse:=HasElse; End;
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
  First:Boolean;
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
        If CurFunc>0 Then Begin
          If Funcs[CurFunc].IsFunc Then EmitRaw('EXIT FUNCTION')
                                   Else EmitRaw('EXIT SUB');
        End Else EmitRaw('SYSTEM');
        Inc(I);
      End Else
      If K='HALT' Then Begin
        EmitRaw('SYSTEM');
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
          Inc(I);
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do
            Inc(I);
          If I<=TokCount Then Inc(I);
        End;
      End Else
      If K='BREAK' Then Begin
        EmitRaw('EXIT FOR    '' ou EXIT DO selon contexte');
        Inc(I);
      End Else
      If K='CONTINUE' Then Begin
        EmitCommentLine('CONTINUE non supporte directement en QBasic ; utiliser GOTO');
        Inc(I);
      End Else
      If K='WITH' Then Begin
        EmitCommentLine('WITH non supporte en QBasic ; expansion manuelle requise');
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do
          Inc(I);
        If I<=TokCount Then Inc(I);
        EmitStmt(I);
      End Else
      If K='GOTO' Then Begin
        EmitRaw('GOTO ');
        Inc(I);
        If (I<=TokCount) Then Begin
          EmitRaw(Tokens[I].Val); Inc(I);
        End;
      End Else Begin
        EmitRaw(MapKeyword(K));
        Inc(I);
      End;
    End;
    TK_IDENT:Begin
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
        If LooksLikeAssignment(I) Then Begin
          EmitAssignment(I);
        End Else Begin
          { Appel de procedure : CALL nom(args) en QBasic
            (forme avec parentheses requiert CALL ; sans CALL il faut
            ne pas mettre de parentheses). }
          EmitRaw('CALL ');
          EmitRaw(Tokens[I].Val);
          Inc(I);
          If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
            EmitRaw('(');
            FIdx:=1;
            Inc(I);
            First:=True;
            While (I<=TokCount) do Begin
              If (FIdx=1)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
                Inc(I); Break;
              End;
              If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(FIdx) Else
              If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(FIdx);
              If First Then First:=False;
              Case Tokens[I].Kind of
                TK_STRING:EmitRaw('"'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-2)+'"');
                TK_CHAR  :EmitRaw(PasCharToVB(Tokens[I].Val));
                TK_OP    :EmitRaw(MapOperator(Tokens[I].Val));
                TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
                TK_PUNCT :Begin
                  If Tokens[I].Val='.' Then EmitRaw('.') Else
                                            EmitRaw(Tokens[I].Val);
                End;
              Else
                EmitRaw(Tokens[I].Val);
              End;
              Inc(I);
            End;
            EmitRaw(')');
          End;
        End;
      End;
    End;
    TK_PUNCT:Begin
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
    { Lua ne necessite pas de ';' separateur. }
    EmitLn;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
End;

{ Emet le corps complet d'une procedure ou du module en AWK :
   - les declarations VAR/CONST/TYPE sont bufferisees dans DeclLines
     (DeclMode active dans EmitDeclSection) pour etre emises dans
     la WORKING-STORAGE SECTION.
   - le BEGIN..END de la procedure top-level est capture dans
     MainLines (le code de MAIN-PARA SECTION).
   - une procedure imbriquee est emise en mode differe (DeferredLines)
     avec un en-tete "<Name>-PARA SECTION." et un EXIT (paragraphe).
   L'emission dans le bon ordre se fait par le programme principal. }
Procedure EmitBlock(Var I:Integer; IsTopLevel:Boolean);
Var
  K:TString;
  PrevFunc:Integer;
  IsFunc:Boolean;
  SaveIndent:Integer;
  SavedCapturing:Boolean;
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
        EmitCommentLine('LABEL section ignoree en Lua');
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
        If I<=TokCount Then Inc(I);
      End Else
      If (K='PROCEDURE')or(K='FUNCTION') Then Begin
        { Les paragraphes de procedures/fonctions sont bufferises pour
          etre emis apres le programme principal. }
        SaveIndent:=Indent;
        SavedCapturing:=CapturingMain;
        If IsTopLevel Then Begin
          DeferredMode:=True;
          CapturingMain:=False;
          Indent:=0;
        End;
        EmitProcHeader(I);
        Inc(Indent);
        EmitBlock(I,False);
        Dec(Indent);
        If IsTopLevel Then Begin
          DeferredMode:=False;
          CapturingMain:=SavedCapturing;
        End;
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
      If IsTopLevel Then Begin
        { rien : le main emet SYSTEM/END }
      End Else Begin
        Dec(Indent);
        If IsFunc Then EmitRaw('END FUNCTION') Else EmitRaw('END SUB');
        EmitLn;
        EmitLn;
        Inc(Indent);
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val='.')or(Tokens[I].Val=';')) Then Inc(I);
    End;
  End;
  CurFunc:=PrevFunc;
  If False Then IsFunc:=IsFunc;
End;

{ Emet la clause USES Pascal en commentaire AWK. }
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
    Buf:=Buf+' (modules AWK : @include en gawk)';
    EmitCommentLine(Buf);
  End;
End;

{ Emet l'en-tete d'un programme AWK : juste un commentaire avec le nom
  du programme. Le code AWK proprement dit est dans le bloc BEGIN. }
Procedure EmitModuleHeader(Var I:Integer);
Var
  J:Integer;
Begin
  EmitCommentLine('Genere par PAS2QB '+PAS2QB_VERSION+' a partir de Pascal');
  If ProgName<>'' Then
    EmitCommentLine('Programme : '+ProgName);
  EmitCommentLine('');
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
  If IsUnit Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='INTERFACE') Then Inc(I);
  End;
  J:=I;
  If (J<=TokCount)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='USES') Then
    EmitUses(I);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('PAS2QB ',PAS2QB_VERSION,' - Transpilateur Pascal vers AWK');
  WriteLn;
  WriteLn('Syntaxe : PAS2AWK [-v] source.pas [destination.awk]');
  WriteLn;
  WriteLn('  source.pas        Fichier source Pascal (Turbo Pascal/FPC).');
  WriteLn('  destination.awk   Fichier AWK a generer (defaut : source.awk).');
  WriteLn('  -v / --verbose    Afficher des messages de progression.');
  WriteLn('  -h / --help       Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : PAS2AWK hello.pas hello.awk');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.bas'
                          Else DstName:=A+'.bas';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2QB : impossible d''ouvrir ',SrcName);
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
  If Verbose Then WriteLn('PAS2QB : tokenisation de ',SrcName,'...');
  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('PAS2QB : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('PAS2QB : programme = ',ProgName);
    WriteLn('PAS2QB : ',FuncCount,' procedure(s)/fonction(s).');
    If UsesOut Then WriteLn('PAS2QB : Out detecte.');
    If UsesIn  Then WriteLn('PAS2QB : In detecte.');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2QB : impossible de creer ',DstName);
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
  DeclMode:=False;
  DeclCount:=0;
  MainCount:=0;
  CapturingMain:=False;
  IPos:=1;
  EmitModuleHeader(IPos);
  { capturer le code principal dans MainLines (sera emis dans BEGIN bloc) }
  CapturingMain:=True;
  EmitBlock(IPos,True);
  CapturingMain:=False;
  If OutLine<>'' Then FlushLine;
  { emettre les declarations VAR/CONST puis le code principal,
    puis END, puis les SUB/FUNCTION (regle de structuration QBasic) }
  FlushDecls;
  FlushMain;
  WriteLn(DstFile,'END');
  WriteLn(DstFile,'');
  FlushDeferred;
  Close(DstFile);
  If Verbose Then WriteLn('PAS2QB : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
