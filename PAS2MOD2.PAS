{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Turbo Pascal vers Modula-2 (.mod)
}

(* ============================================================
   PAS2MOD2.PAS - Transpilateur Turbo Pascal vers Modula-2
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Modula-2 (.mod)

   Couvre les constructions courantes :
     PROGRAM/UNIT, USES, CONST, TYPE, VAR,
     PROCEDURE, FUNCTION (assignation du nom -> RETURN),
     BEGIN..END, IF..THEN..ELSE (ELSE IF -> ELSIF),
     WHILE..DO, REPEAT..UNTIL, FOR..TO/DOWNTO..DO,
     CASE..OF (avec separateur |),
     Write/WriteLn -> InOut.WriteString/WriteInt/WriteReal/WriteLn,
     Read/ReadLn  -> InOut.ReadInt/Read,
     operateurs Pascal vers Modula-2 (<> #, AND/OR/NOT mots-cles).

   Limitations connues (signalees en commentaires Modula-2 dans la
   sortie quand applicable) :
     - assignations multiples au nom de fonction sont toutes
       traduites en RETURN (semantique de Pascal non preservee
       pour les fonctions complexes).
     - les types String[N] et certains types Pascal sans
       equivalent direct sont approximes (ARRAY [0..255] OF CHAR).
     - les unites utilisateurs sont importees telles quelles.
   ============================================================ *)

Program PAS2MOD2;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PAS2MOD2_VERSION = '1.0';
  PAS2MOD2_DATE    = '2026-04-27';

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
    RetType   : TString;     { type de retour Modula-2                   }
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
    WriteLn('PAS2MOD2 : trop de tokens (>',MAX_TOKEN,')');
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
      WriteLn('PAS2MOD2 : chaine non terminee ligne ',SrcLineNo);
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
  If U='INTEGER' Then MapPascalType:='INTEGER' Else
  If U='LONGINT' Then MapPascalType:='LONGINT' Else
  If U='SHORTINT' Then MapPascalType:='SHORTINT' Else
  If U='BYTE' Then MapPascalType:='BYTE' Else
  If U='WORD' Then MapPascalType:='INTEGER' Else
  If U='REAL' Then MapPascalType:='REAL' Else
  If U='SINGLE' Then MapPascalType:='REAL' Else
  If U='DOUBLE' Then MapPascalType:='LONGREAL' Else
  If U='EXTENDED' Then MapPascalType:='LONGREAL' Else
  If U='BOOLEAN' Then MapPascalType:='BOOLEAN' Else
  If U='CHAR' Then MapPascalType:='CHAR' Else
  If U='STRING' Then MapPascalType:='ARRAY [0..255] OF CHAR' Else
  If U='POINTER' Then MapPascalType:='POINTER TO BYTE' Else
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine Modula-2 "abc'def".
  Si la chaine contient un guillemet double, on tente de la decouper
  en concatenation, mais Modula-2 ne supporte pas la concatenation
  litterale -> on remplace " par ' avec un commentaire d'avertissement. }
Function PasStringToModula2(S:TString):TString;
Var
  I:Integer;
  R:TString;
Begin
  R:='';
  I:=2;                       { sauter le guillemet d'ouverture     }
  While I<Length(S) do Begin
    If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin
      R:=R+'''';
      Inc(I,2);
    End Else
    If S[I]='"' Then Begin
      R:=R+''''; Inc(I);     { remplacer " par ' (alternative)     }
    End Else Begin
      R:=R+S[I];
      Inc(I);
    End;
  End;
  PasStringToModula2:='"'+R+'"';
End;

{ Conversion d'un litteral caractere Pascal #N en Modula-2 NX. }
Function PasCharToModula2(S:TString):TString;
Var
  V:LongInt;
  Code:Integer;
  Body,Hex:TString;
  N:LongInt;
Begin
  Body:=Copy(S,2,Length(S)-1);     { retirer le # }
  If (Length(Body)>0)and(Body[1]='$') Then Begin
    Val('$'+Copy(Body,2,Length(Body)-1),V,Code);
  End Else
    Val(Body,V,Code);
  If Code<>0 Then V:=0;
  { Convertir V en hexa (au moins 2 chiffres) }
  Hex:='';
  If V=0 Then Hex:='0' Else Begin
    N:=V;
    While N>0 do Begin
      Case (N and 15) of
        0..9 : Hex:=Chr(Ord('0')+(N and 15))+Hex;
        10..15: Hex:=Chr(Ord('A')+(N and 15)-10)+Hex;
      End;
      N:=N shr 4;
    End;
  End;
  If (Length(Hex)>0)and(Hex[1] in ['A'..'F']) Then Hex:='0'+Hex;
  PasCharToModula2:=Hex+'X';
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op='<>' Then MapOperator:='#' Else
  If Op='='  Then MapOperator:='=' Else
                  MapOperator:=Op;
End;

Function MapKeyword(K:TString):TString;
Begin
  If K='AND' Then MapKeyword:='AND' Else
  If K='OR'  Then MapKeyword:='OR' Else
  If K='NOT' Then MapKeyword:='NOT' Else
  If K='DIV' Then MapKeyword:='DIV' Else
  If K='MOD' Then MapKeyword:='MOD' Else
  If K='SHL' Then MapKeyword:='(* SHL : utiliser SYSTEM.SHIFT *) *' Else
  If K='SHR' Then MapKeyword:='(* SHR : utiliser SYSTEM.SHIFT *) DIV' Else
  If K='XOR' Then MapKeyword:='(* XOR : utiliser BITWORD.XOR *)' Else
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

{ Emet un argument Write/WriteLn en choisissant Out.String/Out.Int/Out.Real
  selon le type lexical du token. Avance I jusqu'apres l'argument
  (jusqu'a la virgule ou la parenthese fermante du Write).
  Format Pascal Write(x:width) ou Write(x:width:precision) sont supportes
  partiellement -- la largeur est mappee sur le 2eme parametre Out.Int. }
Procedure EmitWriteArg(Var I:Integer);
Var
  Kind:TTokenKind;
  Val:TString;
  StartI,Depth:Integer;
  IsString,IsReal,IsChar:Boolean;
  J:Integer;
Begin
  StartI:=I;
  Depth:=0;
  IsString:=False; IsReal:=False; IsChar:=False;

  { Capture jusqu'a ',' ou ')' au niveau 0 }
  J:=I;
  While J<=TokCount do Begin
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and
       ((Tokens[J].Val=',')or(Tokens[J].Val=')')) Then Break;
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=':') Then Break;
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
    Inc(J);
  End;

  { Determination du type d'argument par le 1er token significatif }
  Kind:=Tokens[I].Kind;
  Val :=Tokens[I].Val;
  Case Kind of
    TK_STRING:Begin
      IsString:=True;
      { si la chaine ne contient qu'un caractere, on peut emettre Out.Char }
      If Length(Val)=3 Then IsChar:=True;
    End;
    TK_CHAR:IsChar:=True;
    TK_REAL:IsReal:=True;
  End;

  { Emission du contenu de l'argument en mode "expression" }
  Kind:=Tokens[I].Kind;
  Val :=Tokens[I].Val;

  { Choisir la procedure InOut.* (Modula-2) }
  If IsString Then Begin
    EmitRaw('InOut.WriteString('+PasStringToModula2(Val)+')');
    I:=J;
  End Else
  If IsChar then Begin
    EmitRaw('InOut.Write('+PasCharToModula2(Val)+')');
    I:=J;
  End Else
  If IsReal Then Begin
    EmitRaw('InOut.WriteReal('+Val+', 15)');
    I:=J;
  End Else Begin
    { expression entiere par defaut }
    EmitRaw('InOut.WriteInt(');
    { reemettre l'expression source }
    StartI:=I;
    While StartI<J do Begin
      Case Tokens[StartI].Kind of
        TK_OP    : EmitRaw(MapOperator(Tokens[StartI].Val));
        TK_KEYWORD:EmitRaw(MapKeyword(Tokens[StartI].Val));
        TK_STRING:EmitRaw(PasStringToModula2(Tokens[StartI].Val));
        TK_CHAR  : EmitRaw(PasCharToModula2(Tokens[StartI].Val));
      Else
        EmitRaw(Tokens[StartI].Val);
      End;
      Inc(StartI);
    End;
    EmitRaw(', 0)');
    I:=J;
  End;

  { Sauter formatage :width[:prec] s'il existe }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
    Inc(I);
    { largeur }
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

{ Emission d'un appel WriteLn(...) ou Write(...).
  IsLn=true => terminer par ; Out.Ln
  Avance I jusqu'apres la parenthese fermante (si presente). }
Procedure EmitWriteCall(Var I:Integer; IsLn:Boolean);
Var
  HasArgs:Boolean;
Begin
  HasArgs:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      EmitWriteArg(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        EmitRaw('; ');
        Inc(I);
      End;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then
      Inc(I);
  End;
  If IsLn Then Begin
    If HasArgs Then EmitRaw('; ');
    EmitRaw('InOut.WriteLn');
  End Else Begin
    If Not HasArgs Then EmitRaw('(* Write sans arguments *)');
  End;
End;

Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var
  Depth:Integer;
  First:Boolean;
Begin
  First:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    Depth:=0;
    While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
      If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        EmitRaw('; ');
        Inc(I);
        First:=False;
      End Else Begin
        If First or (Length(OutLine)=0) Then Begin
          EmitRaw('InOut.ReadInt(');
          { lire jusqu'a , ou ) au niveau 0 }
          While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
                ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do Begin
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
            If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=',')or(Tokens[I].Val=')')) Then Break;
            EmitRaw(Tokens[I].Val);
            Inc(I);
          End;
          EmitRaw(')');
          First:=False;
        End Else
        If (OutLine[Length(OutLine)]=';') or (OutLine[Length(OutLine)]=' ') Then Begin
          EmitRaw('InOut.ReadInt(');
          While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and
                ((Tokens[I].Val=',')or(Tokens[I].Val=')'))) do Begin
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
            If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=',')or(Tokens[I].Val=')')) Then Break;
            EmitRaw(Tokens[I].Val);
            Inc(I);
          End;
          EmitRaw(')');
          First:=False;
        End Else
          Inc(I);
      End;
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End;
  { ReadLn sans arguments en Pascal = attendre une ligne ; en Modula-2
    InOut, equivalent approximatif : InOut.Read d'un caractere ignore. }
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
Function MaybeEmitFuncReturn(Var I:Integer):Boolean;
Var
  Name:TString;
  J:Integer;
Begin
  MaybeEmitFuncReturn:=False;
  If CurFunc=0 Then Exit;
  If Tokens[I].Kind<>TK_IDENT Then Exit;
  Name:=Tokens[I].Val;
  If Not StrEqualCI(Name,Funcs[CurFunc].Name) Then Exit;
  J:=I+1;
  If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val=':=') Then Begin
    EmitRaw('RETURN ');
    I:=J+1;        { se positionner sur l'expression apres :=     }
    MaybeEmitFuncReturn:=True;
  End;
End;

{ Verifie si la sequence courante est ELSE IF -> emettre ELSIF et
  consommer les deux tokens. }
Function MaybeEmitElsif(Var I:Integer):Boolean;
Begin
  MaybeEmitElsif:=False;
  If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') and
     (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
    EmitRaw('ELSIF');
    Inc(I,2);
    MaybeEmitElsif:=True;
  End;
End;

{ Emet l'en-tete d'une PROCEDURE/FUNCTION.
  Avance I jusqu'apres le ';' final de l'en-tete. }
Procedure EmitProcHeader(Var I:Integer);
Var
  Name:TString;
  Depth:Integer;
Begin
  EmitRaw('PROCEDURE ');
  Inc(I);
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=Tokens[I].Val;
    EmitRaw(Name);
    { mettre a jour la pile de fonctions courantes }
    Inc(FuncSP);
    FuncStack[FuncSP]:=FindFunc(Name);
    CurFunc:=FuncStack[FuncSP];
    Inc(I);
  End;
  { parametres }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    EmitRaw('(');
    Inc(I);
    Depth:=1;
    While (I<=TokCount) and (Depth>0) do Begin
      Case Tokens[I].Kind of
        TK_KEYWORD:Begin
          If Tokens[I].Val='VAR' Then EmitRaw('VAR ') Else
          If Tokens[I].Val='CONST' Then EmitRaw('') Else  { CONST param non standard en Modula-2, ignorer }
          If Tokens[I].Val='OUT' Then EmitRaw('VAR ') Else
            EmitRaw(MapKeyword(Tokens[I].Val));
        End;
        TK_IDENT:EmitRaw(MapPascalType(Tokens[I].Val));
        TK_PUNCT:Begin
          If Tokens[I].Val='(' Then Inc(Depth) Else
          If Tokens[I].Val=')' Then Dec(Depth);
          If Depth>0 Then Begin
            If Tokens[I].Val=';' Then EmitRaw('; ') Else
            If Tokens[I].Val=',' Then EmitRaw(', ') Else
            If Tokens[I].Val=':' Then EmitRaw(': ') Else
              EmitRaw(Tokens[I].Val);
          End;
        End;
        TK_OP:EmitRaw(MapOperator(Tokens[I].Val));
      Else
        EmitRaw(Tokens[I].Val);
      End;
      Inc(I);
    End;
    EmitRaw(')');
  End;
  { type de retour }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
    Inc(I);
    EmitRaw(': ');
    If (I<=TokCount) Then Begin
      EmitRaw(MapPascalType(Tokens[I].Val));
      Inc(I);
    End;
  End;
  { saut du ';' final }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  EmitRaw(';');
  EmitLn;
End;

{ Emet une declaration VAR / CONST / TYPE jusqu'au prochain mot-cle
  de section. }
Procedure EmitDeclSection(Var I:Integer; SectKw:TString);
Var
  K:TString;
Begin
  EmitRaw(SectKw);
  EmitLn;
  Inc(Indent);
  Inc(I);
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If IsSectionKw(K) Then Break;
    End;
    Case Tokens[I].Kind of
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='ARRAY' Then EmitRaw('ARRAY ') Else
        If K='OF' Then EmitRaw(' OF ') Else
        If K='RECORD' Then Begin EmitLn; EmitRaw('RECORD'); EmitLn; Inc(Indent); End Else
        If K='END' Then Begin Dec(Indent); EmitRaw('END'); End Else
        If K='STRING' Then EmitRaw('ARRAY [0..255] OF CHAR') Else
        If K='PACKED' Then { ignorer } Else
        If K='SET' Then EmitRaw('SET') Else
        If K='FILE' Then EmitRaw('(* FILE *)') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:EmitRaw(MapPascalType(Tokens[I].Val));
      TK_OP:EmitRaw(MapOperator(Tokens[I].Val));
      TK_INTEGER,TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:EmitRaw(PasStringToModula2(Tokens[I].Val));
      TK_CHAR  :EmitRaw(PasCharToModula2(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val=';' Then Begin
          EmitRaw(';');
          EmitLn;
        End Else
        If Tokens[I].Val=',' Then EmitRaw(', ') Else
        If Tokens[I].Val=':' Then EmitRaw(': ') Else
        If Tokens[I].Val='=' Then EmitRaw(' = ') Else
        If Tokens[I].Val='..' Then EmitRaw('..') Else
          EmitRaw(Tokens[I].Val);
      End;
    End;
    Inc(I);
  End;
  Dec(Indent);
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
Procedure EmitExpr(Var I:Integer); Forward;
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
        If K='AND' Then EmitRaw(' AND ') Else
        If K='OR' Then EmitRaw(' OR ') Else
        If K='NOT' Then EmitRaw(' NOT ') Else
        If K='DIV' Then EmitRaw(' DIV ') Else
        If K='MOD' Then EmitRaw(' MOD ') Else
        If K='IN' Then EmitRaw(' IN ') Else
        If K='SHL' Then EmitRaw(' (* SHL *) * 2 *') Else { approximation cassee }
        If K='SHR' Then EmitRaw(' (* SHR *) DIV 2 DIV ') Else
        If K='XOR' Then EmitRaw(' (* XOR : non standard Modula-2 *) ') Else
        If K='NIL' Then EmitRaw('NIL') Else
        If K='TRUE' Then EmitRaw('TRUE') Else
        If K='FALSE' Then EmitRaw('FALSE') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:Begin
        If IdentIsWrite(Tokens[I].Val) or IdentIsRead(Tokens[I].Val) Then Begin
          { dans une expression, peu probable; emettre tel quel }
          EmitRaw(Tokens[I].Val);
        End Else
          EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        If (Length(Tokens[I].Val)>0)and(Tokens[I].Val[1]='$') Then
          EmitRaw(Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-1)+'H')
        Else
          EmitRaw(Tokens[I].Val);
      End;
      TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:EmitRaw(PasStringToModula2(Tokens[I].Val));
      TK_CHAR  :EmitRaw(PasCharToModula2(Tokens[I].Val));
      TK_PUNCT :Begin
        If Tokens[I].Val='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If Tokens[I].Val=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If Tokens[I].Val='[' Then Begin Inc(Depth); EmitRaw('['); End Else
        If Tokens[I].Val=']' Then Begin Dec(Depth); EmitRaw(']'); End Else
        If Tokens[I].Val='^' Then EmitRaw('^') Else
        If Tokens[I].Val='@' Then EmitRaw('SYSTEM.ADR(') Else
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
    EmitLn;
    { ne pas consommer le ';' separateur ici : laisser au caller }
  End;
End;

Procedure EmitIfStatement(Var I:Integer);
Begin
  EmitRaw('IF ');
  Inc(I);                              { sauter IF                        }
  EmitExpr(I);
  EmitRaw(' THEN');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  { ELSE / ELSE IF -> ELSIF (en boucle) }
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') do Begin
    If (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
      Inc(I,2);
      EmitRaw('ELSIF ');
      EmitExpr(I);
      EmitRaw(' THEN');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
      EmitControlBody(I);
      Dec(Indent);
    End Else Begin
      Inc(I);
      EmitRaw('ELSE');
      EmitLn;
      Inc(Indent);
      EmitControlBody(I);
      Dec(Indent);
      Break;
    End;
  End;
  EmitRaw('END');
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
  EmitRaw('WHILE ');
  Inc(I);
  EmitExpr(I);
  EmitRaw(' DO');
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
Begin
  EmitRaw('FOR ');
  Inc(I);                                { sauter FOR                    }
  EmitExpr(I);                           { i := 1 (s'arrete sur TO/DOWNTO)}
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
  EmitRaw(' DO');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('END');
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
  EmitRaw('REPEAT');
  EmitLn;
  Inc(Indent);
  Inc(I);                                  { sauter REPEAT                }
  EmitStatementList(I,'UNTIL');
  Dec(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
  EmitRaw('UNTIL ');
  EmitExpr(I);
End;

Procedure EmitCaseStatement(Var I:Integer);
Var
  First:Boolean;
Begin
  EmitRaw('CASE ');
  Inc(I);                                  { sauter CASE                  }
  EmitExpr(I);
  EmitRaw(' OF');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
  First:=True;
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
      If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
        Dec(Indent);
        EmitLn;
        EmitRaw('ELSE');
        EmitLn;
        Inc(Indent);
        Inc(I);
        EmitStatementList(I,'END');
      End;
      Break;
    End;
    If Not First Then Begin
      EmitRaw(' |');
      EmitLn;
    End;
    First:=False;
    { liste de selecteurs jusqu'a ':' au niveau 0 }
    EmitExpr(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
      EmitRaw(': ');
      Inc(I);
    End;
    { instruction unique du label (ou bloc BEGIN..END) }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
      Inc(I);
      EmitStatementList(I,'END');
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
    End Else
      EmitStmt(I);
    { un eventuel ';' separe les alternatives }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  Dec(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  EmitLn;
  EmitRaw('END');
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
        EmitRaw('RETURN');
        Inc(I);
      End Else
      If K='BREAK' Then Begin
        EmitRaw('EXIT');                      { rapprochement Modula-2 LOOP   }
        Inc(I);
      End Else
      If K='CONTINUE' Then Begin
        EmitRaw('(* CONTINUE non supporte en Modula-2 *)');
        Inc(I);
      End Else
      If K='WITH' Then Begin
        EmitRaw('(* WITH non supporte en Modula-2 ; expansion manuelle requise *)');
        EmitLn;
        { sauter jusqu'au DO }
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do
          Inc(I);
        If I<=TokCount Then Inc(I);
        EmitStmt(I);
      End Else
      If K='GOTO' Then Begin
        EmitRaw('(* GOTO non supporte *)');
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
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
      End Else
      If MaybeEmitFuncReturn(I) Then Begin
        EmitExpr(I);
      End Else Begin
        { affectation ou appel ordinaire }
        EmitExpr(I);
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
  ou EOF. Ne consomme PAS le mot-cle final. }
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
    { gerer separateur ';' }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
      EmitRaw(';');
      EmitLn;
      Inc(I);
    End Else Begin
      { pas de ';' : possible avant END/ELSE/UNTIL ; juste passer       }
      EmitLn;
    End;
  End;
End;

{ Emet le corps complet d'une procedure ou du module : declarations
  locales puis BEGIN..END. }
Procedure EmitBlock(Var I:Integer; IsTopLevel:Boolean);
Var
  K:TString;
  PrevFunc:Integer;
Begin
  PrevFunc:=CurFunc;
  { boucler sur les declarations }
  While I<=TokCount do Begin
    If Tokens[I].Kind=TK_KEYWORD Then Begin
      K:=Tokens[I].Val;
      If (K='VAR') Then EmitDeclSection(I,'VAR') Else
      If (K='CONST') Then EmitDeclSection(I,'CONST') Else
      If (K='TYPE') Then EmitDeclSection(I,'TYPE') Else
      If (K='LABEL') Then Begin
        EmitRaw('(* LABEL section ignored *)');
        EmitLn;
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
        If I<=TokCount Then Inc(I);
      End Else
      If (K='PROCEDURE')or(K='FUNCTION') Then Begin
        EmitProcHeader(I);
        EmitBlock(I,False);
        { restaurer la fonction courante }
        Dec(FuncSP);
        If FuncSP>0 Then CurFunc:=FuncStack[FuncSP] Else CurFunc:=0;
      End Else
      If K='BEGIN' Then Break Else
      If K='IMPLEMENTATION' Then Begin
        Inc(I);                              { passer a la partie impl     }
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
    EmitRaw('BEGIN');
    EmitLn;
    Inc(Indent);
    Inc(I);
    EmitStatementList(I,'END');
    Dec(Indent);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
      Inc(I);
      If IsTopLevel Then Begin
        EmitRaw('END '+ProgName+'.');
        EmitLn;
      End Else Begin
        { fin de procedure : "END nomProc;" }
        EmitRaw('END ');
        If CurFunc>0 Then EmitRaw(Funcs[CurFunc].Name);
        EmitRaw(';');
        EmitLn;
        EmitLn;
      End;
      { sauter le '.' ou ';' final Pascal }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val='.')or(Tokens[I].Val=';')) Then Inc(I);
    End;
  End Else Begin
    { corps absent (procedure forward, ou module ne se terminant que
      par "end.") }
    If IsTopLevel Then Begin
      EmitRaw('BEGIN');
      EmitLn;
      EmitRaw('END '+ProgName+'.');
      EmitLn;
    End;
  End;
  CurFunc:=PrevFunc;
End;

{ Emet la clause USES Pascal en Modula-2 IMPORT.
  Mappe les unites courantes a des modules Modula-2 proches. }
Procedure EmitUses(Var I:Integer);
Var
  Name,U:TString;
  First:Boolean;
  Imports:Array[1..MAX_USES] of TString;
  ICount,K:Integer;
  Found:Boolean;

  Procedure AddImport(N:TString);
  Var L:Integer; Dup:Boolean;
  Begin
    Dup:=False;
    For L:=1 to ICount do If StrEqualCI(Imports[L],N) Then Dup:=True;
    If (Not Dup) and (ICount<MAX_USES) Then Begin
      Inc(ICount);
      Imports[ICount]:=N;
    End;
  End;

Begin
  ICount:=0;
  Inc(I);                                   { sauter USES                  }
  While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
    If Tokens[I].Kind=TK_IDENT Then Begin
      Name:=Tokens[I].Val;
      U:=StrUpper(Name);
      Found:=False;
      If U='CRT' Then Begin AddImport('InOut'); Found:=True; End Else
      If U='DOS' Then Begin AddImport('(* DOS non disponible *)'); Found:=True; End Else
      If U='SYSUTILS' Then Begin AddImport('Strings'); Found:=True; End Else
      If U='STRINGS' Then Begin AddImport('Strings'); Found:=True; End Else
      If U='MATH' Then Begin AddImport('MathLib0'); Found:=True; End Else
      If U='SYSTEM' Then Begin AddImport('SYSTEM'); Found:=True; End;
      If Not Found Then AddImport(Name);
    End;
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  { ajouter InOut si Write/Read sont utilises }
  If UsesOut or UsesIn Then AddImport('InOut');
  If ICount>0 Then Begin
    EmitRaw('IMPORT ');
    First:=True;
    For K:=1 to ICount do Begin
      If Not First Then EmitRaw(', ');
      First:=False;
      EmitRaw(Imports[K]);
    End;
    EmitRaw(';');
    EmitLn;
    EmitLn;
  End;
End;

{ Emet l'en-tete MODULE et IMPORT. }
Procedure EmitModuleHeader(Var I:Integer);
Var
  HasUses:Boolean;
  J:Integer;
Begin
  EmitRaw('MODULE '+ProgName+';');
  EmitLn;
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
  { USES }
  HasUses:=False;
  J:=I;
  If (J<=TokCount)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='USES') Then Begin
    HasUses:=True;
    EmitUses(I);
  End;
  If (Not HasUses) and (UsesOut or UsesIn) Then Begin
    EmitRaw('IMPORT InOut;');
    EmitLn;
    EmitLn;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('PAS2MOD2 ',PAS2MOD2_VERSION,' - Transpilateur Pascal vers Modula-2');
  WriteLn;
  WriteLn('Syntaxe : PAS2MOD2 [-v] source.pas [destination.mod]');
  WriteLn;
  WriteLn('  source.pas      Fichier source Pascal (Turbo Pascal/FPC).');
  WriteLn('  destination.mod Fichier Modula-2 a generer (defaut : source.mod).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : PAS2MOD2 hello.pas hello.mod');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.mod'
                          Else DstName:=A+'.mod';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2MOD2 : impossible d''ouvrir ',SrcName);
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
  If Verbose Then WriteLn('PAS2MOD2 : tokenisation de ',SrcName,'...');
  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('PAS2MOD2 : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('PAS2MOD2 : programme = ',ProgName);
    WriteLn('PAS2MOD2 : ',FuncCount,' procedure(s)/fonction(s).');
    If UsesOut Then WriteLn('PAS2MOD2 : Out detecte.');
    If UsesIn  Then WriteLn('PAS2MOD2 : In detecte.');
  End;

  { DstFile est ouvert dans le corps principal apres l'analyse }

  OutLine:='';
  OutCol:=0;
  Indent:=0;
  CurFunc:=0;
  FuncSP:=0;
  IPos:=1;
  EmitRaw('(* Genere par PAS2MOD2 ');
  EmitRaw(PAS2MOD2_VERSION);
  EmitRaw(' a partir de ');
  EmitRaw(SrcName);
  EmitRaw(' *)');
  EmitLn;
  EmitModuleHeader(IPos);
  EmitBlock(IPos,True);
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('PAS2MOD2 : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
