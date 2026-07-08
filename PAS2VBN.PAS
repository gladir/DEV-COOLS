{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Turbo Pascal vers Visual Basic .NET (.vb)
}

(* ============================================================
   PAS2VBN.PAS - Transpilateur Turbo Pascal vers Visual Basic .NET
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Visual Basic .NET (.vb - Module standard)

   Couvre les constructions courantes :
     PROGRAM/UNIT, USES (commente), CONST, TYPE, VAR,
     PROCEDURE -> Sub, FUNCTION -> Function ... As Type
       (l'assignation au nom de fonction est conservee telle
       quelle car VB.NET utilise la meme syntaxe : Name = expr,
       ou Return expr -- on choisit la forme Pascal-compatible).
     BEGIN..END, IF..THEN..ELSE (ELSE IF -> ElseIf),
     WHILE..DO -> Do While..Loop,
     REPEAT..UNTIL -> Do..Loop Until,
     FOR..TO/DOWNTO..DO -> For..Next (Step -1 pour DOWNTO),
     CASE..OF -> Select Case..End Select,
     Write/WriteLn -> Console.Write/Console.WriteLine,
     Read/ReadLn  -> Console.ReadLine(),
     operateurs Pascal -> VB.NET (= et <> identiques, := -> =,
     DIV -> \, MOD/AND/OR/NOT/XOR -> mots-cles VB).

   Specificites VB.NET (par rapport a VB6) :
     - le source est encadre par "Module Name ... End Module".
     - "Imports System" est emis pour Console.
     - les RECORD Pascal deviennent des "Structure ... End Structure".
     - les Sub peuvent etre appelees avec parentheses sans "Call".
     - Char Pascal -> Char .NET (et non String * 1).

   Limitations connues (signalees en commentaires VB.NET dans la
   sortie quand applicable) :
     - les unites utilisateurs sont signalees en commentaire.
     - la concatenation de chaine '+' est conservee telle quelle ;
       VB.NET prefere '&' mais accepte aussi '+' pour les chaines.
     - les pointeurs Pascal n'ont pas d'equivalent direct ;
       approximes par "Object" ou commentaire.
   ============================================================ *)

Program PAS2VBN;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PAS2VBN_VERSION = '1.0';
  PAS2VBN_DATE    = '2026-04-27';

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
    WriteLn('PAS2VBN : trop de tokens (>',MAX_TOKEN,')');
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
      WriteLn('PAS2VBN : chaine non terminee ligne ',SrcLineNo);
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
  If U='INTEGER' Then MapPascalType:='Integer' Else
  If U='LONGINT' Then MapPascalType:='Integer' Else
  If U='LONGWORD' Then MapPascalType:='UInteger' Else
  If U='CARDINAL' Then MapPascalType:='UInteger' Else
  If U='SHORTINT' Then MapPascalType:='SByte' Else
  If U='SMALLINT' Then MapPascalType:='Short' Else
  If U='BYTE' Then MapPascalType:='Byte' Else
  If U='WORD' Then MapPascalType:='UShort' Else
  If U='INT64' Then MapPascalType:='Long' Else
  If U='QWORD' Then MapPascalType:='ULong' Else
  If U='REAL' Then MapPascalType:='Single' Else
  If U='SINGLE' Then MapPascalType:='Single' Else
  If U='DOUBLE' Then MapPascalType:='Double' Else
  If U='EXTENDED' Then MapPascalType:='Double' Else
  If U='BOOLEAN' Then MapPascalType:='Boolean' Else
  If U='CHAR' Then MapPascalType:='Char' Else
  If U='STRING' Then MapPascalType:='String' Else
  If U='ANSISTRING' Then MapPascalType:='String' Else
  If U='POINTER' Then MapPascalType:='IntPtr' Else
  If U='TEXT' Then MapPascalType:='IO.StreamReader ''(file handle)' Else
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

{ Conversion d'une chaine Pascal 'abc''def' en chaine VB.NET "abc""def".
  En VB.NET, les chaines sont entourees de " et le " interne est double. }
Function PasStringToVB(S:TString):TString;
Var
  I:Integer;
  R:TString;
Begin
  R:='';
  I:=2;                       { sauter le guillemet d'ouverture     }
  While I<Length(S) do Begin
    If (S[I]='''')and(I<Length(S))and(S[I+1]='''') Then Begin
      { '' Pascal -> ' simple en VB.NET (apostrophe litteral) }
      R:=R+'''';
      Inc(I,2);
    End Else
    If S[I]='"' Then Begin
      { " litteral -> "" en VB.NET }
      R:=R+'""'; Inc(I);
    End Else Begin
      R:=R+S[I];
      Inc(I);
    End;
  End;
  PasStringToVB:='"'+R+'"';
End;

{ Conversion d'un litteral caractere Pascal #N en VB.NET ChrW(N).
  ChrW est preferable a Chr en VB.NET pour produire un Char Unicode. }
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
  PasCharToVB:='ChrW('+Dec+')';
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op=':=' Then MapOperator:='=' Else
  If Op='<>' Then MapOperator:='<>' Else
  If Op='='  Then MapOperator:='=' Else
                  MapOperator:=Op;
End;

Function MapKeyword(K:TString):TString;
Begin
  If K='AND' Then MapKeyword:='And' Else
  If K='OR'  Then MapKeyword:='Or' Else
  If K='NOT' Then MapKeyword:='Not' Else
  If K='DIV' Then MapKeyword:='\' Else
  If K='MOD' Then MapKeyword:='Mod' Else
  If K='SHL' Then MapKeyword:=''' SHL : utiliser fonction VB *' Else
  If K='SHR' Then MapKeyword:=''' SHR : utiliser fonction VB \' Else
  If K='XOR' Then MapKeyword:='Xor' Else
  If K='TRUE' Then MapKeyword:='True' Else
  If K='FALSE' Then MapKeyword:='False' Else
  If K='NIL' Then MapKeyword:='Nothing' Else
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
  If IsLn Then EmitRaw('Console.WriteLine')
          Else EmitRaw('Console.Write');
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    HasArgs:=True;
    EmitRaw('(');
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If Not FirstArg Then EmitRaw(' & ');
      FirstArg:=False;
      EmitWriteArg(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then
      Inc(I);
    EmitRaw(')');
  End Else Begin
    If IsLn Then EmitRaw('()');
  End;
  If False Then HasArgs:=HasArgs;            { eviter "non utilise" }
End;

{ Emission d'un appel ReadLn(...) ou Read(...) en VB.NET :
    ReadLn(x)     -> x = Console.ReadLine()
    ReadLn(x,y)   -> x = Console.ReadLine()
                     y = Console.ReadLine()
    ReadLn        -> Console.ReadLine()
  Avance I jusqu'apres la parenthese fermante (si presente). }
Procedure EmitReadCall(Var I:Integer; IsLn:Boolean);
Var
  Depth:Integer;
  First:Boolean;
  J:Integer;
Begin
  First:=True;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    Depth:=0;
    While (I<=TokCount) and Not((Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
        Inc(I);
        EmitLn;
        First:=False;
        Continue;
      End;
      First:=False;
      { lire la cible jusqu'a , ou ) au niveau 0 }
      J:=I;
      Depth:=0;
      While (J<=TokCount) and Not((Depth=0)and(Tokens[J].Kind=TK_PUNCT)and
            ((Tokens[J].Val=',')or(Tokens[J].Val=')'))) do Begin
        If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
        If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
        Inc(J);
      End;
      { emettre LHS = Console.ReadLine() }
      While I<J do Begin
        Case Tokens[I].Kind of
          TK_OP    : EmitRaw(MapOperator(Tokens[I].Val));
          TK_KEYWORD:EmitRaw(MapKeyword(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
      EmitRaw(' = Console.ReadLine()');
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End Else Begin
    If IsLn Then EmitRaw('Console.ReadLine()');
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
{ En VB.NET, la valeur de retour d'une fonction se fait par "Name = expr",
  ce qui est identique a Pascal apres la transformation := -> =. Il
  n'y a donc aucune conversion specifique a effectuer. }
Function MaybeEmitFuncReturn(Var I:Integer):Boolean;
Begin
  MaybeEmitFuncReturn:=False;
End;

{ Verifie si la sequence courante est ELSE IF -> emettre ElseIf et
  consommer les deux tokens (utilise dans EmitStmt en chaine). }
Function MaybeEmitElsif(Var I:Integer):Boolean;
Begin
  MaybeEmitElsif:=False;
  If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') and
     (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
    EmitRaw('ElseIf');
    Inc(I,2);
    MaybeEmitElsif:=True;
  End;
End;

{ Emet l'en-tete d'une PROCEDURE/FUNCTION en VB.NET.
  PROCEDURE Foo(p:Type; Var q:Type);   ->  Sub Foo(ByVal p As Type, ByRef q As Type)
  FUNCTION  Bar(p:Type):RType;         ->  Function Bar(ByVal p As Type) As RType
  Avance I jusqu'apres le ';' final de l'en-tete. }
Procedure EmitProcHeader(Var I:Integer);
Var
  Name,RetType:TString;
  IsFunc,FirstParam,InGroup:Boolean;
  ByMode:TString;          { 'ByVal' ou 'ByRef' }
  GroupNames:Array[1..16] of TString;
  GroupCount,K:Integer;
  GroupBy:TString;
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
  If IsFunc Then EmitRaw('Function ') Else EmitRaw('Sub ');
  EmitRaw(Name);
  EmitRaw('(');
  FirstParam:=True;
  GroupCount:=0;
  GroupBy:='ByVal';
  InGroup:=False;
  { parametres }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    { format Pascal : [VAR|CONST|OUT] name1,name2 : Type ; ...        }
    While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Begin
      ByMode:='ByVal';
      { mot-cle de mode }
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='VAR') Then Begin
        ByMode:='ByRef'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='CONST') Then Begin
        ByMode:='ByVal'; Inc(I);
      End Else
      If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OUT') Then Begin
        ByMode:='ByRef'; Inc(I);
      End;
      GroupCount:=0; GroupBy:=ByMode; InGroup:=True;
      { collecter les noms separes par ',' }
      While (I<=TokCount) and (Tokens[I].Kind=TK_IDENT) do Begin
        Inc(GroupCount);
        If GroupCount<=16 Then GroupNames[GroupCount]:=Tokens[I].Val;
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I)
        Else Break;
      End;
      { ':' Type }
      RetType:='Variant';
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
        Inc(I);
        If (I<=TokCount) Then Begin
          RetType:=MapPascalType(Tokens[I].Val);
          Inc(I);
        End;
      End;
      { Emettre chaque nom du groupe }
      For K:=1 to GroupCount do Begin
        If Not FirstParam Then EmitRaw(', ');
        FirstParam:=False;
        EmitRaw(GroupBy); EmitRaw(' ');
        EmitRaw(GroupNames[K]); EmitRaw(' As '); EmitRaw(RetType);
      End;
      InGroup:=False;
      { ';' separateur de groupes }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
  End;
  EmitRaw(')');
  { type de retour pour une fonction }
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
      Inc(I);
      If (I<=TokCount) Then Begin
        RetType:=MapPascalType(Tokens[I].Val);
        Inc(I);
        EmitRaw(' As '); EmitRaw(RetType);
      End;
    End;
  End;
  { saut du ';' final }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  EmitLn;
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
        ReadType:='String * '+Lo;
        Exit;
      End;
      ReadType:='String';
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
    EmitRaw('Structure '); EmitRaw(TypeIdent); EmitLn;
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
        If Copy(FType,1,9)='__ARRAY__' Then Begin
          Val2:=Copy(FType,11,Length(FType)-10);
          Pk1:=Pos(':',Val2);
          FK:=Copy(Val2,1,Pk1-1);
          Val2:=Copy(Val2,Pk1+1,Length(Val2));
          Pk2:=Pos(':',Val2);
          EmitRaw('Public '); EmitRaw(FNames[L]); EmitRaw('(');
          EmitRaw(Copy(Val2,1,Pk2-1)); EmitRaw(') As ');
          EmitRaw(Copy(Val2,Pk2+1,Length(Val2)));
          EmitRaw(' '' Pascal: '); EmitRaw(FK); EmitRaw('..');
          EmitRaw(Copy(Val2,1,Pk2-1));
        End Else Begin
          EmitRaw('Public '); EmitRaw(FNames[L]); EmitRaw(' As '); EmitRaw(FType);
        End;
        EmitLn;
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
    Dec(Indent);
    EmitRaw('End Structure'); EmitLn;
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
        { __ARRAY__:lo:hi:elt -> Dim Name(hi) As Elt ' Pascal: lo..hi }
        Val:=Copy(TypeName,11,Length(TypeName)-10);
        J:=Pos(':',Val);
        Depth:=Pos(':',Copy(Val,J+1,Length(Val)));
        EmitRaw('Dim ');
        For M:=1 to GCount do Begin
          If M>1 Then EmitRaw(', ');
          EmitRaw(Names[M]);
          EmitRaw('('); EmitRaw(Copy(Val,J+1,Depth-1)); EmitRaw(') As ');
          EmitRaw(Copy(Val,J+Depth+1,Length(Val)));
        End;
        EmitRaw(' '' Pascal: '); EmitRaw(Copy(Val,1,J-1));
        EmitRaw('..'); EmitRaw(Copy(Val,J+1,Depth-1));
        EmitLn;
      End Else
      If TypeName='__RECORD__' Then Begin
        EmitRaw(''' Type RECORD anonyme dans VAR : non transpilable directement en VB.NET');
        EmitLn;
        { sauter le bloc RECORD..END }
        Depth:=1; Inc(I);
        While (I<=TokCount) and (Depth>0) do Begin
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='RECORD') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Dec(Depth);
          Inc(I);
        End;
      End Else Begin
        EmitRaw('Dim ');
        For M:=1 to GCount do Begin
          If M>1 Then EmitRaw(', ');
          EmitRaw(Names[M]); EmitRaw(' As '); EmitRaw(TypeName);
        End;
        EmitLn;
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

      EmitRaw('Const '); EmitRaw(Name);
      If TypeName<>'' Then Begin
        EmitRaw(' As '); EmitRaw(TypeName);
      End;
      EmitRaw(' = ');
      { lire la valeur jusqu'au ';' }
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
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

        EmitRaw(''' Type '); EmitRaw(Name); EmitRaw(' = '); EmitRaw(TypeName);
        EmitRaw(' (alias non supporte directement en VB.NET)');
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
        If K='AND' Then EmitRaw(' And ') Else
        If K='OR' Then EmitRaw(' Or ') Else
        If K='NOT' Then EmitRaw(' Not ') Else
        If K='DIV' Then EmitRaw(' \ ') Else
        If K='MOD' Then EmitRaw(' Mod ') Else
        If K='IN' Then EmitRaw(' '' (IN ensemble : non supporte) ') Else
        If K='SHL' Then EmitRaw(' '' (SHL : utiliser * 2^n) ') Else
        If K='SHR' Then EmitRaw(' '' (SHR : utiliser \ 2^n) ') Else
        If K='XOR' Then EmitRaw(' Xor ') Else
        If K='NIL' Then EmitRaw('Nothing') Else
        If K='TRUE' Then EmitRaw('True') Else
        If K='FALSE' Then EmitRaw('False') Else
          EmitRaw(MapKeyword(K));
      End;
      TK_IDENT:Begin
          EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        If (Length(Tokens[I].Val)>0)and(Tokens[I].Val[1]='$') Then
          EmitRaw('&H'+Copy(Tokens[I].Val,2,Length(Tokens[I].Val)-1))
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
        If Tokens[I].Val='^' Then EmitRaw('') Else
        If Tokens[I].Val='@' Then EmitRaw('VarPtr(') Else
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
  EmitRaw('If ');
  Inc(I);                              { sauter IF                        }
  EmitExpr(I);
  EmitRaw(' Then');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  { ELSE / ELSE IF -> ElseIf (en boucle) }
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='ELSE') do Begin
    If (I<TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='IF') Then Begin
      Inc(I,2);
      EmitRaw('ElseIf ');
      EmitExpr(I);
      EmitRaw(' Then');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='THEN') Then Inc(I);
      EmitControlBody(I);
      Dec(Indent);
    End Else Begin
      Inc(I);
      EmitRaw('Else');
      EmitLn;
      Inc(Indent);
      EmitControlBody(I);
      Dec(Indent);
      Break;
    End;
  End;
  EmitRaw('End If');
End;

Procedure EmitWhileStatement(Var I:Integer);
Begin
  EmitRaw('Do While ');
  Inc(I);
  EmitExpr(I);
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('Loop');
End;

Procedure EmitForStatement(Var I:Integer);
Var
  Down:Boolean;
  VarName:TString;
  J:Integer;
Begin
  EmitRaw('For ');
  Inc(I);                                { sauter FOR                    }
  { capturer le nom de variable du For pour Next i }
  VarName:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then VarName:=Tokens[I].Val;
  EmitExpr(I);                           { i := 1 (s'arrete sur TO/DOWNTO)}
  Down:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DOWNTO') Then Begin
    Down:=True;
    EmitRaw(' To ');
    Inc(I);
  End Else
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='TO') Then Begin
    EmitRaw(' To ');
    Inc(I);
  End;
  EmitExpr(I);                           { borne                          }
  If Down Then EmitRaw(' Step -1');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO') Then Inc(I);
  EmitControlBody(I);
  Dec(Indent);
  EmitRaw('Next ');
  EmitRaw(VarName);
End;

Procedure EmitRepeatStatement(Var I:Integer);
Begin
  EmitRaw('Do');
  EmitLn;
  Inc(Indent);
  Inc(I);                                  { sauter REPEAT                }
  EmitStatementList(I,'UNTIL');
  Dec(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='UNTIL') Then Inc(I);
  EmitRaw('Loop Until ');
  EmitExpr(I);
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
        EmitRaw(' To '); Inc(I); Continue;
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
  EmitRaw('Select Case ');
  Inc(I);                                  { sauter CASE                  }
  EmitExpr(I);
  EmitLn;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='OF') Then Inc(I);
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_KEYWORD) and
       ((Tokens[I].Val='END')or(Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE')) Then Begin
      If (Tokens[I].Val='ELSE')or(Tokens[I].Val='OTHERWISE') Then Begin
        EmitRaw('Case Else');
        EmitLn;
        Inc(Indent);
        Inc(I);
        EmitStatementList(I,'END');
        Dec(Indent);
      End;
      Break;
    End;
    EmitRaw('Case ');
    EmitCaseLabels(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
    EmitLn;
    Inc(Indent);
    { instruction unique du label (ou bloc BEGIN..END) }
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='BEGIN') Then Begin
      Inc(I);
      EmitStatementList(I,'END');
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
    End Else Begin
      EmitStmt(I);
      EmitLn;
    End;
    Dec(Indent);
    { un eventuel ';' separe les alternatives }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Inc(I);
  EmitRaw('End Select');
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
        If (CurFunc>0)and(Funcs[CurFunc].IsFunc) Then EmitRaw('Exit Function')
        Else If CurFunc>0 Then EmitRaw('Exit Sub')
        Else EmitRaw('Exit Sub');
        Inc(I);
      End Else
      If K='BREAK' Then Begin
        EmitRaw(''' Break : remplacer par Exit For / Exit Do selon contexte');
        Inc(I);
      End Else
      If K='CONTINUE' Then Begin
        EmitRaw(''' Continue non supporte directement en VB.NET');
        Inc(I);
      End Else
      If K='WITH' Then Begin
        EmitRaw(''' WITH non supporte en VB.NET ; expansion manuelle requise');
        EmitLn;
        { sauter jusqu'au DO }
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='DO')) do
          Inc(I);
        If I<=TokCount Then Inc(I);
        EmitStmt(I);
      End Else
      If K='GOTO' Then Begin
        EmitRaw('GoTo ');
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
        { En VB.NET, l'appel d'une Sub peut utiliser des parentheses
          sans "Call" -- on emet directement l'expression. }
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
      If (K='LABEL') Then Begin
        EmitRaw(''' LABEL section ignoree en VB.NET');
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
    If IsTopLevel Then Begin
      EmitRaw('Sub Main()'); EmitLn;
      Inc(Indent);
    End;
    EmitStatementList(I,'END');
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='END') Then Begin
      Inc(I);
      If IsTopLevel Then Begin
        Dec(Indent);
        EmitRaw('End Sub');
        EmitLn;
      End Else Begin
        Dec(Indent);
        If IsFunc Then EmitRaw('End Function')
                  Else EmitRaw('End Sub');
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
      EmitRaw('Sub Main()'); EmitLn;
      EmitRaw('End Sub'); EmitLn;
    End;
  End;
  CurFunc:=PrevFunc;
End;

{ Emet la clause USES Pascal en commentaire VB.NET.
  VB.NET utilise des references de projet ; aucun import au niveau du
  source .vb n'est requis. }
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
    EmitRaw(''' Pascal USES : ');
    First:=True;
    For K:=1 to ICount do Begin
      If Not First Then EmitRaw(', ');
      First:=False;
      EmitRaw(Names[K]);
    End;
    EmitRaw(' (a remplacer par References projet VB.NET)');
    EmitLn;
    EmitLn;
  End;
End;

{ Emet l'en-tete d'un module VB.NET (.vb) :
    Option Strict On
    Imports System
    Module Name
      ...
    End Module
  Le "Module Name" est emis ici ; le "End Module" sera emis a la
  fin par le programme principal. }
Procedure EmitModuleHeader(Var I:Integer);
Var
  J:Integer;
Begin
  EmitRaw('Option Strict On');     EmitLn;
  EmitRaw('Option Explicit On');   EmitLn;
  EmitLn;
  EmitRaw('Imports System');       EmitLn;
  EmitLn;
  EmitRaw('Module '+ProgName);     EmitLn;
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
  WriteLn('PAS2VBN ',PAS2VBN_VERSION,' - Transpilateur Pascal vers Visual Basic .NET');
  WriteLn;
  WriteLn('Syntaxe : PAS2VBN [-v] source.pas [destination.vb]');
  WriteLn;
  WriteLn('  source.pas      Fichier source Pascal (Turbo Pascal/FPC).');
  WriteLn('  destination.vb Fichier Visual Basic .NET a generer (defaut : source.vb).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : PAS2VBN hello.pas hello.vb');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.vb'
                          Else DstName:=A+'.vb';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('PAS2VBN : impossible d''ouvrir ',SrcName);
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
  If Verbose Then WriteLn('PAS2VBN : tokenisation de ',SrcName,'...');
  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('PAS2VBN : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('PAS2VBN : programme = ',ProgName);
    WriteLn('PAS2VBN : ',FuncCount,' procedure(s)/fonction(s).');
    If UsesOut Then WriteLn('PAS2VBN : Out detecte.');
    If UsesIn  Then WriteLn('PAS2VBN : In detecte.');
  End;

  { DstFile est ouvert dans le corps principal apres l'analyse }

  OutLine:='';
  OutCol:=0;
  Indent:=0;
  CurFunc:=0;
  FuncSP:=0;
  IPos:=1;
  EmitRaw(''' Genere par PAS2VBN ');
  EmitRaw(PAS2VBN_VERSION);
  EmitRaw(' a partir de ');
  EmitRaw(SrcName);
  EmitLn;
  EmitModuleHeader(IPos);
  EmitBlock(IPos,True);
  Dec(Indent);
  EmitRaw('End Module'); EmitLn;
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('PAS2VBN : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
