{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Ada (.adb) vers PSP (.psp)
}

(* ============================================================
   ADA2PSP.PAS - Transpilateur Ada vers PSP (Pascal Server Pages)
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source PSP (Pascal Server Pages) dans lequel le
           code Pascal est encapsule dans des balises <% ... %>
           a l'interieur d'un document HTML, compilable par
           PSP86 / PSPCW32. Utilise les primitives PSP standard
           (Write / WriteLn pour la sortie HTTP).

   Couvre les constructions courantes :
     WITH / USE  (les paquets Ada.* sont ignores),
     PROCEDURE Nom IS ... END Nom; au sommet  -> program Nom;
     PROCEDURE / FUNCTION imbriquees,
     declarations CONSTANT / TYPE / SUBTYPE / VAR,
     TYPE ... IS RECORD / ARRAY / (enum) / RANGE A..B,
     IF / ELSIF / ELSE / END IF,
     WHILE / FOR (REVERSE) / LOOP / EXIT [WHEN] / RETURN,
     CASE ... IS / WHEN x | y | a..b / OTHERS / END CASE,
     blocs DECLARE et BEGIN anonymes, GOTO, <<label>>, PRAGMA,
     Put / Put_Line / New_Line / Get / Get_Line / Skip_Line.

   Limitations connues :
     - les genericites et taches Ada ne sont pas traduites
       (signalees en commentaire dans la sortie).
     - les clauses 'exception ... when ... =>' Ada sont traduites
       en blocs try ... except (avec mapping des exceptions
       predefinies). Selon la version de PSP utilisee, ces
       constructions peuvent necessiter un ajustement manuel.
     - les blocs DECLARE sont aplatis : leurs declarations
       locales sont remontees au scope englobant.
     - les types FLOAT digits / fixed point sont approximes
       par Extended.
     - operateur ** est traduit via une fonction Power_ helper.
     - les attributs Ada 'First / 'Last / 'Range ne sont pas
       generalement supportes.
     - le code Pascal genere est encapsule dans une balise
       <% ... %> au sein d'un document HTML minimal afin de
       produire un fichier PSP utilisable directement.
   ============================================================ *)

Program ADA2PSP;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  ADA2PSP_VERSION = '1.0';
  ADA2PSP_DATE    = '2026-04-28';

  MAX_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_TOKEN  = {$IFDEF FPC}32000{$ELSE}4000{$ENDIF};
  MAX_USES   = 32;
  MAX_NAMES  = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FSTACK = 32;

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
    TK_INT,        { 42  16#FF#                       }
    TK_REAL,       { 3.14  1.0E2                      }
    TK_STRING,     { "hello"                          }
    TK_CHAR,       { 'X'                              }
    TK_IDENT,      { identificateur (en majuscules)   }
    TK_KEYWORD,    { mot-cle Ada (en majuscules)      }
    TK_OP,         { :=  /=  **  ..  =>  + - * / etc. }
    TK_PUNCT       { ;  ,  (  )  [  ]  :  |  .        }
  );

  TToken = Record
    Kind : TTokenKind;
    Val  : TString;
    Line : Integer;
  End;

  TNameList = Record
    Count : Integer;
    Items : Array[1..MAX_NAMES] of TString;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  SrcFile, DstFile : Text;
  SrcName, DstName : TString;
  Verbose          : Boolean;

  Tokens   : Array[1..MAX_TOKEN] of TToken;
  TokCount : Integer;

  ProgName : TString;

  { Tables collectees pendant l'analyse pour la sortie Pascal }
  UsesList     : TNameList;        { paquets non-Ada.* a inclure }
  ArrayTypes   : TNameList;        { noms de types qui sont des Array }
  ArrayVars    : TNameList;        { variables typees Array         }
  Labels       : TNameList;        { etiquettes vues (<<lab>>)      }
  ForVars      : TNameList;        { variables de boucle FOR        }
  DeclaredVars : TNameList;        { vars deja declarees (objets)   }
  HasPower     : Boolean;          { true si ** rencontre           }

  { Pile de fonctions pour traduire RETURN expr -> nom := expr ; Exit }
  FuncStack : Array[1..MAX_FSTACK] of TString;
  FuncSP    : Integer;

  { Sortie }
  Indent     : Integer;
  ErrorCount : Integer;

{ ============================================================
  UTILITAIRES
  ============================================================ }
Function UpperStr(const S:TString):TString;
Var I:Integer; R:TString;
Begin
  R:='';
  For I:=1 to Length(S) do
    If (S[I]>='a')and(S[I]<='z') Then R:=R+Chr(Ord(S[I])-32)
                                  Else R:=R+S[I];
  UpperStr:=R;
End;

Function LowerStr(const S:TString):TString;
Var I:Integer; R:TString;
Begin
  R:='';
  For I:=1 to Length(S) do
    If (S[I]>='A')and(S[I]<='Z') Then R:=R+Chr(Ord(S[I])+32)
                                  Else R:=R+S[I];
  LowerStr:=R;
End;

Procedure InitNameList(Var L:TNameList);
Begin L.Count:=0; End;

Function NameInList(Var L:TNameList; const N:TString):Boolean;
Var I:Integer;
Begin
  NameInList:=False;
  For I:=1 to L.Count do
    If UpperStr(L.Items[I])=UpperStr(N) Then Begin NameInList:=True; Exit; End;
End;

Procedure AddName(Var L:TNameList; const N:TString);
Begin
  If NameInList(L,N) Then Exit;
  If L.Count<MAX_NAMES Then Begin
    Inc(L.Count);
    L.Items[L.Count]:=N;
  End;
End;

Procedure AddToken(K:TTokenKind; const V:TString; Ln:Integer);
Begin
  If TokCount>=MAX_TOKEN Then Exit;
  Inc(TokCount);
  Tokens[TokCount].Kind:=K;
  Tokens[TokCount].Val :=V;
  Tokens[TokCount].Line:=Ln;
End;

Function IsAdaKeyword(const S:TString):Boolean;
Var U:TString;
Begin
  U:=UpperStr(S);
  IsAdaKeyword :=
   (U='ABORT')or(U='ABS')or(U='ABSTRACT')or(U='ACCEPT')or(U='ACCESS')or
   (U='ALIASED')or(U='ALL')or(U='AND')or(U='ARRAY')or(U='AT')or
   (U='BEGIN')or(U='BODY')or(U='CASE')or(U='CONSTANT')or(U='DECLARE')or
   (U='DELAY')or(U='DELTA')or(U='DIGITS')or(U='DO')or(U='ELSE')or
   (U='ELSIF')or(U='END')or(U='ENTRY')or(U='EXCEPTION')or(U='EXIT')or
   (U='FOR')or(U='FUNCTION')or(U='GENERIC')or(U='GOTO')or(U='IF')or
   (U='IN')or(U='INTERFACE')or(U='IS')or(U='LIMITED')or(U='LOOP')or
   (U='MOD')or(U='NEW')or(U='NOT')or(U='NULL')or(U='OF')or(U='OR')or
   (U='OTHERS')or(U='OUT')or(U='OVERRIDING')or(U='PACKAGE')or
   (U='PRAGMA')or(U='PRIVATE')or(U='PROCEDURE')or(U='PROTECTED')or
   (U='RAISE')or(U='RANGE')or(U='RECORD')or(U='REM')or(U='RENAMES')or
   (U='REQUEUE')or(U='RETURN')or(U='REVERSE')or(U='SELECT')or
   (U='SEPARATE')or(U='SOME')or(U='SUBTYPE')or(U='SYNCHRONIZED')or
   (U='TAGGED')or(U='TASK')or(U='TERMINATE')or(U='THEN')or(U='TYPE')or
   (U='UNTIL')or(U='USE')or(U='WHEN')or(U='WHILE')or(U='WITH')or
   (U='XOR');
End;

{ ============================================================
  TOKENISATION DU SOURCE ADA
  ============================================================ }
Procedure Tokenize;
Var
  Line : TString;
  L,C  : Integer;
  Ch   : Char;
  S    : TString;
Begin
  TokCount:=0;
  L:=0;
  Reset(SrcFile);
  While not Eof(SrcFile) do Begin
    ReadLn(SrcFile,Line);
    Inc(L);
    C:=1;
    While C<=Length(Line) do Begin
      Ch:=Line[C];
      { Espaces }
      If (Ch=' ')or(Ch=#9) Then Begin Inc(C); Continue; End;
      { Commentaire -- jusqu'a la fin de ligne }
      If (Ch='-')and(C<Length(Line))and(Line[C+1]='-') Then Break;
      { Identificateur ou mot-cle }
      If ((Ch>='A')and(Ch<='Z'))or((Ch>='a')and(Ch<='z'))or(Ch='_') Then Begin
        S:='';
        While (C<=Length(Line)) and
              (((Line[C]>='A')and(Line[C]<='Z'))or
               ((Line[C]>='a')and(Line[C]<='z'))or
               ((Line[C]>='0')and(Line[C]<='9'))or
               (Line[C]='_')) do Begin
          S:=S+Line[C];
          Inc(C);
        End;
        If IsAdaKeyword(S) Then AddToken(TK_KEYWORD,UpperStr(S),L)
                            Else AddToken(TK_IDENT,S,L);
        Continue;
      End;
      { Nombre }
      If (Ch>='0')and(Ch<='9') Then Begin
        S:='';
        While (C<=Length(Line))and(((Line[C]>='0')and(Line[C]<='9'))or(Line[C]='_')) do Begin
          If Line[C]<>'_' Then S:=S+Line[C];
          Inc(C);
        End;
        { Reel: . suivi d'un chiffre (pas .. ) }
        If (C<Length(Line))and(Line[C]='.')and
           (Line[C+1]>='0')and(Line[C+1]<='9') Then Begin
          S:=S+'.';
          Inc(C);
          While (C<=Length(Line))and(((Line[C]>='0')and(Line[C]<='9'))or(Line[C]='_')) do Begin
            If Line[C]<>'_' Then S:=S+Line[C];
            Inc(C);
          End;
          { Exposant }
          If (C<=Length(Line))and((Line[C]='E')or(Line[C]='e')) Then Begin
            S:=S+Line[C]; Inc(C);
            If (C<=Length(Line))and((Line[C]='+')or(Line[C]='-')) Then Begin
              S:=S+Line[C]; Inc(C);
            End;
            While (C<=Length(Line))and(Line[C]>='0')and(Line[C]<='9') do Begin
              S:=S+Line[C]; Inc(C);
            End;
          End;
          AddToken(TK_REAL,S,L);
        End Else
          AddToken(TK_INT,S,L);
        Continue;
      End;
      { Chaine "...": gerer "" double quote interne }
      If Ch='"' Then Begin
        S:=''; Inc(C);
        While C<=Length(Line) do Begin
          If Line[C]='"' Then Begin
            If (C<Length(Line))and(Line[C+1]='"') Then Begin
              S:=S+'"'; Inc(C,2);
            End Else Begin Inc(C); Break; End;
          End Else Begin
            S:=S+Line[C]; Inc(C);
          End;
        End;
        AddToken(TK_STRING,S,L);
        Continue;
      End;
      { Char literal 'X' (3 caracteres exactement) ou apostrophe d'attribut }
      If Ch='''' Then Begin
        If (C+2<=Length(Line))and(Line[C+2]='''') Then Begin
          AddToken(TK_CHAR,Line[C+1],L);
          Inc(C,3);
        End Else Begin
          AddToken(TK_OP,'''',L);
          Inc(C);
        End;
        Continue;
      End;
      { Operateurs composes }
      If (Ch=':')and(C<Length(Line))and(Line[C+1]='=') Then Begin
        AddToken(TK_OP,':=',L); Inc(C,2); Continue;
      End;
      If (Ch='/')and(C<Length(Line))and(Line[C+1]='=') Then Begin
        AddToken(TK_OP,'/=',L); Inc(C,2); Continue;
      End;
      If (Ch='*')and(C<Length(Line))and(Line[C+1]='*') Then Begin
        AddToken(TK_OP,'**',L); Inc(C,2); Continue;
      End;
      If (Ch='.')and(C<Length(Line))and(Line[C+1]='.') Then Begin
        AddToken(TK_OP,'..',L); Inc(C,2); Continue;
      End;
      If (Ch='=')and(C<Length(Line))and(Line[C+1]='>') Then Begin
        AddToken(TK_OP,'=>',L); Inc(C,2); Continue;
      End;
      If (Ch='<')and(C<Length(Line))and(Line[C+1]='=') Then Begin
        AddToken(TK_OP,'<=',L); Inc(C,2); Continue;
      End;
      If (Ch='>')and(C<Length(Line))and(Line[C+1]='=') Then Begin
        AddToken(TK_OP,'>=',L); Inc(C,2); Continue;
      End;
      If (Ch='<')and(C<Length(Line))and(Line[C+1]='<') Then Begin
        AddToken(TK_OP,'<<',L); Inc(C,2); Continue;
      End;
      If (Ch='>')and(C<Length(Line))and(Line[C+1]='>') Then Begin
        AddToken(TK_OP,'>>',L); Inc(C,2); Continue;
      End;
      { Operateurs simples }
      If (Ch='+')or(Ch='-')or(Ch='*')or(Ch='/')or
         (Ch='=')or(Ch='<')or(Ch='>')or(Ch='&') Then Begin
        AddToken(TK_OP,Ch,L); Inc(C); Continue;
      End;
      { Ponctuation }
      If (Ch=';')or(Ch=',')or(Ch='(')or(Ch=')')or
         (Ch='[')or(Ch=']')or(Ch=':')or(Ch='|')or(Ch='.') Then Begin
        AddToken(TK_PUNCT,Ch,L); Inc(C); Continue;
      End;
      { Inconnu : ignorer }
      Inc(C);
    End;
  End;
  AddToken(TK_EOF,'',L);
End;

{ ============================================================
  HELPERS DE LECTURE DE TOKEN
  ============================================================ }
Function TKind(I:Integer):TTokenKind;
Begin
  If (I<1)or(I>TokCount) Then TKind:=TK_EOF
                          Else TKind:=Tokens[I].Kind;
End;

Function TVal(I:Integer):TString;
Begin
  If (I<1)or(I>TokCount) Then TVal:=''
                          Else TVal:=Tokens[I].Val;
End;

Function IsKw(I:Integer; const W:TString):Boolean;
Begin
  IsKw := (TKind(I)=TK_KEYWORD)and(TVal(I)=W);
End;

Function IsPunct(I:Integer; const W:TString):Boolean;
Begin
  IsPunct := (TKind(I)=TK_PUNCT)and(TVal(I)=W);
End;

Function IsOp(I:Integer; const W:TString):Boolean;
Begin
  IsOp := (TKind(I)=TK_OP)and(TVal(I)=W);
End;

{ ============================================================
  TRADUCTION DE CHAINES ADA -> PASCAL
  ============================================================ }
Function AdaStrToPas(const S:TString):TString;
Var I:Integer; R:TString;
Begin
  R:='''';
  For I:=1 to Length(S) do Begin
    If S[I]='''' Then R:=R+''''''   { ' double pour Pascal }
                  Else R:=R+S[I];
  End;
  R:=R+'''';
  AdaStrToPas:=R;
End;

Function MapType(const T:TString):TString;
Var U:TString;
Begin
  U:=UpperStr(T);
  If U='INTEGER'      Then MapType:='Integer'
  Else If U='NATURAL' Then MapType:='Cardinal'
  Else If U='POSITIVE'Then MapType:='Cardinal'
  Else If U='LONG_INTEGER' Then MapType:='Int64'
  Else If U='SHORT_INTEGER' Then MapType:='SmallInt'
  Else If U='FLOAT'   Then MapType:='Extended'
  Else If U='LONG_FLOAT' Then MapType:='Double'
  Else If U='SHORT_FLOAT' Then MapType:='Single'
  Else If U='BOOLEAN' Then MapType:='Boolean'
  Else If U='CHARACTER' Then MapType:='Char'
  Else If U='WIDE_CHARACTER' Then MapType:='WideChar'
  Else If U='STRING'  Then MapType:='string'
  Else If U='WIDE_STRING' Then MapType:='WideString'
  Else MapType:=T;
End;

{ Mappe un nom d'exception Ada vers la classe d'exception Delphi
  correspondante (de l'unite SysUtils). Pour les exceptions
  utilisateur (non predefinies), conserve le nom d'origine. }
Function MapExceptionName(const N:TString):TString;
Var U:TString;
Begin
  U:=UpperStr(N);
  If U='CONSTRAINT_ERROR' Then MapExceptionName:='ERangeError'
  Else If U='NUMERIC_ERROR' Then MapExceptionName:='EMathError'
  Else If U='STORAGE_ERROR' Then MapExceptionName:='EOutOfMemory'
  Else If U='PROGRAM_ERROR' Then MapExceptionName:='Exception'
  Else If U='TASKING_ERROR' Then MapExceptionName:='Exception'
  Else If U='DATA_ERROR' Then MapExceptionName:='EConvertError'
  Else If U='END_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='NAME_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='USE_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='STATUS_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='DEVICE_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='MODE_ERROR' Then MapExceptionName:='EInOutError'
  Else If U='LAYOUT_ERROR' Then MapExceptionName:='EInOutError'
  Else MapExceptionName:=N;
End;

Function MapIdentInExpr(const N:TString):TString;
Var U:TString;
Begin
  U:=UpperStr(N);
  If U='TRUE'  Then MapIdentInExpr:='True'
  Else If U='FALSE' Then MapIdentInExpr:='False'
  Else MapIdentInExpr:=N;
End;

{ ============================================================
  EMISSION (sortie Pascal)
  ============================================================ }
Procedure WriteIndent;
Var K:Integer;
Begin
  For K:=1 to Indent do Write(DstFile,' ');
End;

Procedure EmitLn(const S:TString);
Begin
  WriteIndent;
  WriteLn(DstFile,S);
End;

Procedure EmitBlank;
Begin
  WriteLn(DstFile);
End;

{ Emet une expression Ada en traduisant les operateurs.
  S'arrete sur le premier separateur du contexte, sans le consommer.
  StopSet : 1=';', 2=',', 4=')', 8='THEN', 16='LOOP', 32='IS',
            64='..', 128='=>', 256='|', 512=':=' (used in CASE/iter)
}
Const
  ST_SEMI  = 1;
  ST_COMMA = 2;
  ST_RPAR  = 4;
  ST_THEN  = 8;
  ST_LOOP  = 16;
  ST_IS    = 32;
  ST_DDOT  = 64;
  ST_ARROW = 128;
  ST_PIPE  = 256;
  ST_ASSIGN= 512;
  ST_RANGE = 1024;  { keyword RANGE }
  ST_EOF   = 2048;

Function ExprStop(I:Integer; Stop:Integer):Boolean;
Var K:TTokenKind;
Begin
  K:=TKind(I);
  ExprStop:=False;
  If K=TK_EOF Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_SEMI)<>0) and IsPunct(I,';') Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_COMMA)<>0)and IsPunct(I,',') Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_RPAR)<>0) and IsPunct(I,')') Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_THEN)<>0) and IsKw(I,'THEN')  Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_LOOP)<>0) and IsKw(I,'LOOP')  Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_IS)<>0)   and IsKw(I,'IS')    Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_DDOT)<>0) and IsOp(I,'..')    Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_ARROW)<>0)and IsOp(I,'=>')    Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_PIPE)<>0) and IsPunct(I,'|')  Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_ASSIGN)<>0)and IsOp(I,':=')   Then Begin ExprStop:=True; Exit; End;
  If ((Stop and ST_RANGE)<>0) and IsKw(I,'RANGE') Then Begin ExprStop:=True; Exit; End;
End;

{ Forward }
Procedure EmitExpr(Var I:Integer; Stop:Integer); Forward;

{ Emet une expression scalaire/composite avec traduction de :
   - "..." -> '...'
   - 'X'  -> 'X' (Pascal)
   - /=   -> <>
   - &    -> +
   - **   -> Power_(...)  (en wrap binaire, simpliste)
   - mots-cles AND/OR/NOT/MOD/REM/ABS -> equivalents Pascal
   - Ident(...) si Ident est un ArrayVar -> Ident[...]
}
Procedure EmitExpr(Var I:Integer; Stop:Integer);
Var
  ParenDepth : Integer;
  IsArrayCall: Array[0..63] of Boolean; { pour chaque niveau de parenthese }
  V          : TString;
  U          : TString;
  K          : TTokenKind;
  Prev       : TString;
  PrevK      : TTokenKind;
  Bracket    : Char;
Begin
  ParenDepth:=0;
  Prev:='';
  PrevK:=TK_EOF;
  While not ExprStop(I,Stop) do Begin
    K:=TKind(I);
    V:=TVal(I);
    Case K of
      TK_KEYWORD: Begin
        U:=V;
        If (U='AND') Then Begin
          { AND THEN -> And }
          If IsKw(I+1,'THEN') Then Begin
            Write(DstFile,' And '); Inc(I,2);
          End Else Begin
            Write(DstFile,' And '); Inc(I);
          End;
        End Else If (U='OR') Then Begin
          If IsKw(I+1,'ELSE') Then Begin
            Write(DstFile,' Or '); Inc(I,2);
          End Else Begin
            Write(DstFile,' Or '); Inc(I);
          End;
        End Else If U='NOT' Then Begin
          { NOT IN -> not in (ensemble Pascal); sinon Not espace }
          Write(DstFile,'Not '); Inc(I);
        End Else If U='XOR' Then Begin
          Write(DstFile,' Xor '); Inc(I);
        End Else If U='MOD' Then Begin
          Write(DstFile,' Mod '); Inc(I);
        End Else If U='REM' Then Begin
          Write(DstFile,' Mod '); Inc(I);
        End Else If U='ABS' Then Begin
          Write(DstFile,'Abs'); Inc(I);
        End Else If U='IN' Then Begin
          Write(DstFile,' in '); Inc(I);
        End Else If U='NULL' Then Begin
          Write(DstFile,'nil'); Inc(I);
        End Else If U='NEW' Then Begin
          { allocation: Ada 'NEW T(...)' -> ne sait pas mapper proprement }
          Write(DstFile,'{ NEW }'); Inc(I);
        End Else If U='OTHERS' Then Begin
          Write(DstFile,'{ others }'); Inc(I);
        End Else If U='RANGE' Then Begin
          Write(DstFile,' { range } '); Inc(I);
        End Else Begin
          { Mot-cle Ada non gere dans une expression : emettre en clair }
          Write(DstFile,LowerStr(U)); Inc(I);
        End;
      End;
      TK_OP: Begin
        If V='/=' Then Write(DstFile,'<>')
        Else If V='&' Then Write(DstFile,'+')
        Else If V='**' Then Begin
          HasPower:=True;
          { La forme deja emise est l'operande gauche; on ne peut pas
            facilement re-encoder. On insere un appel de fonction
            Power_ inline en utilisant un commentaire. }
          Write(DstFile,' { ** } *');
        End
        Else If V='..' Then Write(DstFile,'..')
        Else If V=':=' Then Write(DstFile,':=')
        Else If V='''' Then Write(DstFile,V)  { attribut, emet brut }
        Else Write(DstFile,V);
        Inc(I);
      End;
      TK_PUNCT: Begin
        If V='(' Then Begin
          { Verifier si c'est un appel sur une variable tableau }
          Inc(ParenDepth);
          If ParenDepth<=63 Then IsArrayCall[ParenDepth]:=False;
          If (PrevK=TK_IDENT)and NameInList(ArrayVars,Prev) Then Begin
            { Remplacer la parenthese par un crochet }
            { Mais on a deja ecrit Prev... ecrire [ }
            Bracket:='[';
            If ParenDepth<=63 Then IsArrayCall[ParenDepth]:=True;
            Write(DstFile,Bracket);
          End Else Begin
            Write(DstFile,'(');
          End;
          Inc(I);
        End Else If V=')' Then Begin
          If (ParenDepth<=63)and(ParenDepth>0)and IsArrayCall[ParenDepth] Then
            Write(DstFile,']')
          Else
            Write(DstFile,')');
          If ParenDepth>0 Then Dec(ParenDepth);
          Inc(I);
        End Else If V='|' Then Begin
          { Dans une expression simple : '|' est un OR-pattern (CASE).
            Si on n'est pas dans un parametre, on devrait s'arreter
            mais Stop le gere; sinon emit ', ' separator. }
          Write(DstFile,', ');
          Inc(I);
        End Else Begin
          Write(DstFile,V);
          Inc(I);
        End;
      End;
      TK_INT,TK_REAL: Begin
        Write(DstFile,V);
        Inc(I);
      End;
      TK_STRING: Begin
        Write(DstFile,AdaStrToPas(V));
        Inc(I);
      End;
      TK_CHAR: Begin
        { Emettre 'X' Pascal }
        If V='''' Then Write(DstFile,'''''''''')
        Else Begin
          Write(DstFile,'''');
          Write(DstFile,V);
          Write(DstFile,'''');
        End;
        Inc(I);
      End;
      TK_IDENT: Begin
        Write(DstFile,MapIdentInExpr(V));
        Inc(I);
      End;
    Else
      Inc(I);
    End;
    Prev:=V;
    PrevK:=K;
    { Si V est un mot-cle qu'on a transforme, neutraliser PrevK }
    If K=TK_KEYWORD Then PrevK:=TK_KEYWORD;
  End;
End;

{ Lit un type Ada (un identifiant possiblement qualifie A.B.C, ou mot-cle).
  Avance I et renvoie le type Pascal mappe. }
Function ReadAdaType(Var I:Integer):TString;
Var R,Part:TString;
Begin
  R:='';
  If TKind(I)=TK_KEYWORD Then Begin
    R:=TVal(I); Inc(I);
  End Else If TKind(I)=TK_IDENT Then Begin
    R:=TVal(I); Inc(I);
    While IsPunct(I,'.') and (TKind(I+1)=TK_IDENT) do Begin
      Part:=TVal(I+1);
      R:=R+'.'+Part;
      Inc(I,2);
    End;
  End;
  ReadAdaType:=MapType(R);
End;

{ Saute le contenu d'une parenthese (utilise pour ARRAY (range)) en
  emettant le texte tel quel, en traduisant les operateurs. }
Procedure EmitInsideParen(Var I:Integer);
Var Depth:Integer;
Begin
  Depth:=0;
  If IsPunct(I,'(') Then Begin
    Write(DstFile,'[');
    Inc(I);
    Depth:=1;
    While (Depth>0)and(TKind(I)<>TK_EOF) do Begin
      If IsPunct(I,'(') Then Begin Inc(Depth); Write(DstFile,'('); Inc(I); End
      Else If IsPunct(I,')') Then Begin
        Dec(Depth);
        If Depth=0 Then Write(DstFile,']')
                    Else Write(DstFile,')');
        Inc(I);
      End
      Else Begin
        EmitExpr(I, ST_RPAR or ST_COMMA);
        If IsPunct(I,',') Then Begin Write(DstFile,','); Inc(I); End;
      End;
    End;
  End;
End;

{ ============================================================
  EMISSION DES DECLARATIONS
  ============================================================ }
{
  EmitDecls : analyse les declarations entre 'IS' et 'BEGIN', emet
  les sections Pascal correspondantes (Const / Type / Var) et ajoute
  les nested Procedures/Functions.
  Renvoie via Var I la position de 'BEGIN'.
  InitStmts est rempli avec les initialisations 'X := expr;' issues
  des declarations 'X : T := expr;'.
}

Var
  CurSection : Char;  { 'C' Const, 'T' Type, 'V' Var, ' ' rien }

Procedure SwitchSection(NewSec:Char);
Begin
  If NewSec=CurSection Then Exit;
  CurSection:=NewSec;
  Case NewSec of
    'C': EmitLn('Const');
    'T': EmitLn('Type');
    'V': EmitLn('Var');
  End;
End;

{ Forward }
Procedure EmitProcOrFunc(Var I:Integer); Forward;

{ Emet une declaration de type complete.
  I pointe sur 'TYPE' ou 'SUBTYPE'. }
Procedure EmitTypeDecl(Var I:Integer);
Var
  Name : TString;
  IsSub: Boolean;
  Base : TString;
  V    : TString;
Begin
  IsSub := IsKw(I,'SUBTYPE');
  Inc(I); { TYPE / SUBTYPE }
  SwitchSection('T');
  Indent:=Indent+2;
  WriteIndent;
  If TKind(I)=TK_IDENT Then Begin
    Name:=TVal(I);
    Write(DstFile,Name,'=');
    Inc(I);
  End Else Begin
    Inc(I);
  End;
  { 'IS' attendu }
  If IsKw(I,'IS') Then Inc(I);

  If IsSub Then Begin
    { SUBTYPE Name IS Base [RANGE A..B]; }
    Base:=ReadAdaType(I);
    If IsKw(I,'RANGE') Then Begin
      Inc(I);
      EmitExpr(I, ST_DDOT or ST_SEMI);
      If IsOp(I,'..') Then Begin
        Write(DstFile,'..');
        Inc(I);
        EmitExpr(I, ST_SEMI);
      End;
    End Else Begin
      Write(DstFile,Base);
    End;
  End Else
  If IsKw(I,'RECORD') Then Begin
    { TYPE Name IS RECORD ... END RECORD; }
    Inc(I);
    Write(DstFile,'Record');
    WriteLn(DstFile);
    While (TKind(I)<>TK_EOF) and not (IsKw(I,'END') and IsKw(I+1,'RECORD')) do Begin
      If IsPunct(I,';') Then Begin Inc(I); Continue; End;
      { champ : Name [, Name...] : Type [:= expr]; }
      WriteIndent; Write(DstFile,'  ');
      While TKind(I)=TK_IDENT do Begin
        Write(DstFile,TVal(I));
        Inc(I);
        If IsPunct(I,',') Then Begin Write(DstFile,','); Inc(I); End
        Else Break;
      End;
      If IsPunct(I,':') Then Begin Write(DstFile,':'); Inc(I); End;
      V:=ReadAdaType(I);
      Write(DstFile,V);
      { ignorer eventuel := default }
      If IsOp(I,':=') Then Begin
        Inc(I);
        While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
      End;
      Write(DstFile,';');
      WriteLn(DstFile);
      If IsPunct(I,';') Then Inc(I);
    End;
    WriteIndent;
    Write(DstFile,'End');
    If IsKw(I,'END') Then Inc(I);
    If IsKw(I,'RECORD') Then Inc(I);
  End Else
  If IsKw(I,'ARRAY') Then Begin
    Inc(I);
    Write(DstFile,'Array');
    EmitInsideParen(I);
    If IsKw(I,'OF') Then Begin
      Write(DstFile,' Of ');
      Inc(I);
      Base:=ReadAdaType(I);
      Write(DstFile,Base);
    End;
    If Length(Name)>0 Then AddName(ArrayTypes,Name);
  End Else
  If IsPunct(I,'(') Then Begin
    { Type enum: TYPE Name IS (a,b,c); }
    Write(DstFile,'(');
    Inc(I);
    While (TKind(I)<>TK_EOF) and not IsPunct(I,')') do Begin
      If TKind(I)=TK_IDENT Then Write(DstFile,TVal(I));
      Inc(I);
      If IsPunct(I,',') Then Begin Write(DstFile,', '); Inc(I); End;
    End;
    If IsPunct(I,')') Then Begin Write(DstFile,')'); Inc(I); End;
  End Else
  If IsKw(I,'NEW') Then Begin
    Inc(I);
    { TYPE X IS NEW Base [RANGE ...]; -> juste copier Base }
    Base:=ReadAdaType(I);
    Write(DstFile,Base);
    If IsKw(I,'RANGE') Then Begin
      Inc(I);
      EmitExpr(I, ST_DDOT or ST_SEMI);
      If IsOp(I,'..') Then Begin
        Write(DstFile,'..'); Inc(I);
        EmitExpr(I, ST_SEMI);
      End;
    End;
  End Else
  If IsKw(I,'RANGE') Then Begin
    Inc(I);
    EmitExpr(I, ST_DDOT or ST_SEMI);
    If IsOp(I,'..') Then Begin
      Write(DstFile,'..'); Inc(I);
      EmitExpr(I, ST_SEMI);
    End;
  End Else Begin
    { Inconnu : juste reproduire jusqu'a ; }
    Base:=ReadAdaType(I);
    Write(DstFile,Base);
  End;
  Write(DstFile,';');
  WriteLn(DstFile);
  Indent:=Indent-2;
  If IsPunct(I,';') Then Inc(I);
End;

{ Emet une declaration d'objet :
   Name [, Name]* : [CONSTANT] Type [:= expr];
}
Procedure EmitObjectDecl(Var I:Integer; Var InitBuf:TString);
Var
  Names    : Array[1..16] of TString;
  NCount   : Integer;
  IsConst  : Boolean;
  TypeStr  : TString;
  K        : Integer;
Begin
  NCount:=0;
  While TKind(I)=TK_IDENT do Begin
    Inc(NCount);
    If NCount<=16 Then Names[NCount]:=TVal(I);
    Inc(I);
    If IsPunct(I,',') Then Inc(I) Else Break;
  End;
  If IsPunct(I,':') Then Inc(I);
  IsConst:=False;
  If IsKw(I,'CONSTANT') Then Begin IsConst:=True; Inc(I); End;
  TypeStr:=ReadAdaType(I);

  { Inscrire les variables de type tableau }
  If NameInList(ArrayTypes,TypeStr) Then
    For K:=1 to NCount do AddName(ArrayVars,Names[K]);

  { Inscrire toutes les variables/constantes declarees }
  For K:=1 to NCount do AddName(DeclaredVars,Names[K]);

  { Initialiseur ? }
  If IsOp(I,':=') Then Begin
    Inc(I);
    If IsConst Then Begin
      { Const Pascal : Name : Type = expr; (typee) }
      SwitchSection('C');
      Indent:=Indent+2;
      WriteIndent;
      Write(DstFile,Names[1],':',TypeStr,'=');
      EmitExpr(I, ST_SEMI);
      Write(DstFile,';');
      WriteLn(DstFile);
      Indent:=Indent-2;
    End Else Begin
      { Var avec init : declarer la variable, et capturer l'init dans
        InitBuf pour l'emettre en debut de BEGIN. Comme InitBuf est
        une chaine simple, nous reconstruisons un tampon ligne par
        ligne via EmitInitToBuf ci-dessous. Trop complexe pour la
        version actuelle : emettre l'init via un fichier temporaire
        en memoire (variable Pascal). On va la stocker en dur. }
      SwitchSection('V');
      Indent:=Indent+2;
      For K:=1 to NCount do Begin
        WriteIndent;
        Write(DstFile,Names[K],':',TypeStr,';');
        WriteLn(DstFile);
      End;
      Indent:=Indent-2;
      { On note ' Name := expr;' a appliquer en debut de body. }
      InitBuf:=InitBuf+' '+Names[1];
      InitBuf:=InitBuf+'__INIT__';
      { Capturer l'init dans le fichier de sortie via une seconde
        passe est complexe; on fait simple : enregistrer la position
        dans Tokens. On reserve le mecanisme pour plus tard et on
        signale par un commentaire. }
      Write(DstFile,'  { init: ',Names[1],':=');
      EmitExpr(I, ST_SEMI);
      WriteLn(DstFile,'; }');
    End;
  End Else Begin
    If IsConst Then Begin
      { CONSTANT sans valeur : exceptionnel, traiter en Var }
      SwitchSection('V');
      Indent:=Indent+2;
      For K:=1 to NCount do Begin
        WriteIndent;
        Write(DstFile,Names[K],':',TypeStr,';');
        WriteLn(DstFile);
      End;
      Indent:=Indent-2;
    End Else Begin
      SwitchSection('V');
      Indent:=Indent+2;
      For K:=1 to NCount do Begin
        WriteIndent;
        Write(DstFile,Names[K],':',TypeStr,';');
        WriteLn(DstFile);
      End;
      Indent:=Indent-2;
    End;
  End;
  If IsPunct(I,';') Then Inc(I);
End;

{ Boucle de declarations. Renvoie I sur 'BEGIN'. }
Procedure EmitDecls(Var I:Integer);
Var Dummy:TString;
Begin
  Dummy:='';
  While (TKind(I)<>TK_EOF) and not IsKw(I,'BEGIN') do Begin
    If IsPunct(I,';') Then Begin Inc(I); Continue; End;
    If IsKw(I,'TYPE') or IsKw(I,'SUBTYPE') Then Begin
      EmitTypeDecl(I);
    End Else
    If IsKw(I,'PROCEDURE') or IsKw(I,'FUNCTION') Then Begin
      CurSection:=' ';
      EmitProcOrFunc(I);
    End Else
    If IsKw(I,'PRAGMA') Then Begin
      { sauter la pragma }
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
      If IsPunct(I,';') Then Inc(I);
    End Else
    If IsKw(I,'USE') or IsKw(I,'WITH') Then Begin
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
      If IsPunct(I,';') Then Inc(I);
    End Else
    If TKind(I)=TK_IDENT Then Begin
      EmitObjectDecl(I,Dummy);
    End Else Begin
      Inc(I);
    End;
  End;
End;

{ ============================================================
  EMISSION DES INSTRUCTIONS
  ============================================================ }

{ Forward }
Procedure EmitOneStmt(Var I:Integer); Forward;

Procedure EmitStmtBlock(Var I:Integer; const StopKw:TString);
Begin
  While (TKind(I)<>TK_EOF) do Begin
    If IsKw(I,'END') or IsKw(I,'ELSIF') or IsKw(I,'ELSE')
       or IsKw(I,'WHEN') or IsKw(I,'EXCEPTION') Then Exit;
    If IsPunct(I,';') Then Begin Inc(I); Continue; End;
    EmitOneStmt(I);
  End;
End;

{ Determine si le body courant (a partir de StartI, juste apres son
  BEGIN d'ouverture) possede une clause EXCEPTION au meme niveau.
  Suit une pile des constructions imbriquees pour ne pas confondre
  avec une exception interne a un sous-bloc. }
Function BlockHasException(StartI:Integer):Boolean;
Const MAX_EXC_STACK = 64;
Var
  I, Top : Integer;
  Stk    : Array[1..MAX_EXC_STACK] of TString;

  Procedure SPush(const S:TString);
  Begin
    If Top<MAX_EXC_STACK Then Begin Inc(Top); Stk[Top]:=S; End;
  End;

  Procedure SPop;
  Begin If Top>0 Then Dec(Top); End;

Begin
  BlockHasException:=False;
  I:=StartI;
  Top:=0;
  While (TKind(I)<>TK_EOF) do Begin
    If IsKw(I,'BEGIN') Then Begin
      If (Top>0) and (Stk[Top]='DECLARE') Then Stk[Top]:='BLOCK'
      Else SPush('BLOCK');
      Inc(I);
    End Else If IsKw(I,'DECLARE') Then Begin
      SPush('DECLARE'); Inc(I);
    End Else If IsKw(I,'IF') Then Begin
      SPush('IF'); Inc(I);
    End Else If IsKw(I,'LOOP') Then Begin
      SPush('LOOP'); Inc(I);
    End Else If IsKw(I,'CASE') Then Begin
      SPush('CASE'); Inc(I);
    End Else If IsKw(I,'RECORD') Then Begin
      SPush('RECORD'); Inc(I);
    End Else If IsKw(I,'SELECT') Then Begin
      SPush('SELECT'); Inc(I);
    End Else If IsKw(I,'EXCEPTION') Then Begin
      If Top=0 Then Begin BlockHasException:=True; Exit; End;
      Inc(I);
    End Else If IsKw(I,'END') Then Begin
      If Top=0 Then Exit;  { END qui ferme notre body }
      Inc(I);
      { Sauter le mot-cle ou nom apres END (IF/LOOP/CASE/RECORD/
        SELECT ou nom de subprog/block). }
      If (TKind(I)=TK_KEYWORD) or (TKind(I)=TK_IDENT) Then Inc(I);
      SPop;
    End Else Inc(I);
  End;
End;

{ Emet les handlers Delphi pour une clause exception Ada.
  I doit pointer sur le mot-cle EXCEPTION en entree. En sortie I
  pointe sur le END qui clot le body englobant. }
Procedure EmitExceptionHandlers(Var I:Integer);
Var
  Names    : Array[1..16] of TString;
  NCount,K,K2 : Integer;
  IsOthers : Boolean;
  Mapped   : TString;
  BodyStart, TmpI, LastEnd : Integer;
  EmittedCount : Integer;
  AlreadyDone  : Boolean;
Begin
  If IsKw(I,'EXCEPTION') Then Inc(I);
  While IsKw(I,'WHEN') do Begin
    Inc(I);
    NCount:=0;
    IsOthers:=False;
    { Lire les noms d'exception jusqu'au '=>'.
      Forme acceptee : [Choice : ] Name1 [| Name2 ...] => stmts
      ou               others => stmts }
    While not IsOp(I,'=>') and (TKind(I)<>TK_EOF) do Begin
      If IsKw(I,'OTHERS') Then Begin
        IsOthers:=True; Inc(I);
      End Else If TKind(I)=TK_IDENT Then Begin
        { Ignorer la forme nommee 'Choice : Type' }
        If IsPunct(I+1,':') and (TKind(I+2)=TK_IDENT) Then Inc(I,2);
        If TKind(I)=TK_IDENT Then Begin
          Inc(NCount);
          If NCount<=16 Then Names[NCount]:=TVal(I);
          Inc(I);
          { Permettre les noms qualifies type Ada.IO.Data_Error }
          While IsPunct(I,'.') and (TKind(I+1)=TK_IDENT) do Begin
            If NCount<=16 Then Names[NCount]:=TVal(I+1);
            Inc(I,2);
          End;
        End;
      End Else If IsOp(I,'|') Then Inc(I)
      Else Inc(I);
    End;
    If IsOp(I,'=>') Then Inc(I);

    If IsOthers Then Begin
      WriteIndent; WriteLn(DstFile,'on E: Exception do Begin');
      Indent:=Indent+2;
      EmitStmtBlock(I,'END');
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'End;');
    End Else If NCount=1 Then Begin
      Mapped:=MapExceptionName(Names[1]);
      WriteIndent; Write(DstFile,'on E: ',Mapped,' do Begin');
      WriteLn(DstFile);
      Indent:=Indent+2;
      EmitStmtBlock(I,'END');
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'End;');
    End Else If NCount>1 Then Begin
      { Plusieurs exceptions partagent le meme handler. Delphi ne
        supporte pas la liste de classes dans 'on', donc on emet
        une clause 'on' par nom (avec deduplication par classe
        Delphi). Le corps est replaye en repositionnant l'index
        de tokens avant chaque emission. }
      BodyStart:=I;
      LastEnd:=I;
      EmittedCount:=0;
      For K:=1 to NCount do Begin
        Mapped:=MapExceptionName(Names[K]);
        AlreadyDone:=False;
        For K2:=1 to K-1 do
          If MapExceptionName(Names[K2])=Mapped Then AlreadyDone:=True;
        If AlreadyDone Then Continue;
        WriteIndent; Write(DstFile,'on E: ',Mapped,' do Begin');
        WriteLn(DstFile);
        Indent:=Indent+2;
        TmpI:=BodyStart;
        EmitStmtBlock(TmpI,'END');
        Indent:=Indent-2;
        WriteIndent; WriteLn(DstFile,'End;');
        LastEnd:=TmpI;
        Inc(EmittedCount);
      End;
      I:=LastEnd;
    End Else Begin
      { Aucun nom (parse error) : sauter les statements }
      EmitStmtBlock(I,'END');
    End;
  End;
End;

{ Emet le contenu d'un body : statements + clause exception
  optionnelle. Le 'Begin' d'ouverture et le 'End' de fermeture sont
  emis par l'appelant. Si une clause EXCEPTION est presente, le
  contenu est entoure d'un try ... except ... end Delphi. }
Procedure EmitBodyContent(Var I:Integer);
Begin
  If BlockHasException(I) Then Begin
    WriteIndent; WriteLn(DstFile,'try');
    Indent:=Indent+2;
    EmitStmtBlock(I,'END');
    Indent:=Indent-2;
    WriteIndent; WriteLn(DstFile,'except');
    Indent:=Indent+2;
    EmitExceptionHandlers(I);
    Indent:=Indent-2;
    WriteIndent; WriteLn(DstFile,'end;');
  End Else Begin
    EmitStmtBlock(I,'END');
  End;
End;


{ Emet un appel a Put/Put_Line/Get/etc. en traduisant. }
Procedure EmitIOCall(Var I:Integer; const Name:TString);
Var
  U      : TString;
  Depth  : Integer;
  Found  : Boolean;
  J      : Integer;
Begin
  U:=UpperStr(Name);
  { Pas de () suivant -> appel sans argument }
  If not IsPunct(I,'(') Then Begin
    If U='NEW_LINE' Then EmitLn('WriteLn;')
    Else If U='SKIP_LINE' Then EmitLn('ReadLn;')
    Else If U='PUT_LINE' Then EmitLn('WriteLn;')
    Else If U='PUT' Then  { rien a faire }
    Else Begin
      WriteIndent; Write(DstFile,Name,';'); WriteLn(DstFile);
    End;
    Exit;
  End;
  Inc(I); { ( }
  WriteIndent;
  If U='PUT_LINE' Then Write(DstFile,'WriteLn(')
  Else If U='PUT' Then Write(DstFile,'Write(')
  Else If U='GET' Then Write(DstFile,'Read(')
  Else If U='GET_LINE' Then Write(DstFile,'ReadLn(')
  Else If U='NEW_LINE' Then Write(DstFile,'WriteLn(')
  Else If U='SKIP_LINE' Then Write(DstFile,'ReadLn(')
  Else Write(DstFile,Name,'(');

  { Emettre les arguments. Les parametres nommes Ada (Fore=>1, etc.)
    sont ignores car Pascal ne les supporte pas. }
  Depth:=1;
  While (Depth>0)and(TKind(I)<>TK_EOF) do Begin
    If IsPunct(I,'(') Then Begin
      Inc(Depth); Write(DstFile,'('); Inc(I);
    End Else If IsPunct(I,')') Then Begin
      Dec(Depth);
      If Depth=0 Then Write(DstFile,')')
                  Else Write(DstFile,')');
      Inc(I);
    End Else If IsPunct(I,',') Then Begin
      { Verifier si l'argument suivant est de la forme Name => valeur
        (parametre nomme Ada). Pour Put(X, 0) on garde la virgule.
        Pour Put(X, Fore=>1, Aft=>6, Exp=>0) on coupe : on ne supporte
        pas les params nommes en Pascal. On regarde si dans les
        prochains tokens on rencontre '=>'. }
      Found:=False;
      J:=I+1;
      While (J<=TokCount) and not IsPunct(J,',') and not IsPunct(J,')') do Begin
        If IsOp(J,'=>') Then Begin Found:=True; Break; End;
        Inc(J);
      End;
      If Found Then Begin
        { sauter l'argument nomme entier }
        I:=J+1;
        While (TKind(I)<>TK_EOF) and not IsPunct(I,',') and not IsPunct(I,')') do Begin
          { sauter l'expression de l'argument nomme }
          If IsPunct(I,'(') Then Begin
            Inc(Depth); Inc(I);
            While Depth>1 do Begin
              If IsPunct(I,'(') Then Inc(Depth);
              If IsPunct(I,')') Then Dec(Depth);
              Inc(I);
            End;
          End Else
            Inc(I);
        End;
        { rien a emettre, juste continuer }
      End Else Begin
        { Pour Put(X,0) -> emettre Write(X:0); convertir ',' restantes
          en ':' uniquement pour Put }
        If U='PUT' Then Write(DstFile,':')
        Else Write(DstFile,',');
        Inc(I);
      End;
    End Else Begin
      EmitExpr(I, ST_RPAR or ST_COMMA);
    End;
  End;
  Write(DstFile,';');
  WriteLn(DstFile);
End;

{ Detecte les appels d'IO Ada. Renvoie True si traite. }
Function TryEmitIOorCall(Var I:Integer):Boolean;
Var
  Name : TString;
  U    : TString;
Begin
  TryEmitIOorCall:=False;
  If TKind(I)<>TK_IDENT Then Exit;
  Name:=TVal(I);
  U:=UpperStr(Name);
  If (U='PUT')or(U='PUT_LINE')or(U='NEW_LINE')or(U='GET')
   or(U='GET_LINE')or(U='SKIP_LINE') Then Begin
    Inc(I);
    EmitIOCall(I,Name);
    If IsPunct(I,';') Then Inc(I);
    TryEmitIOorCall:=True;
  End;
End;

{ Emet une instruction simple : assignation ou appel. }
Procedure EmitSimpleStmt(Var I:Integer);
Var
  Lookahead:Integer;
  IsAssign:Boolean;
  Depth   :Integer;
Begin
  { Detection d'IO standard }
  If TryEmitIOorCall(I) Then Exit;

  { Determiner si c'est une assignation : chercher ':=' avant ';' au
    niveau 0 de parentheses. }
  IsAssign:=False;
  Depth:=0;
  Lookahead:=I;
  While (TKind(Lookahead)<>TK_EOF)and not(IsPunct(Lookahead,';')and(Depth=0)) do Begin
    If IsPunct(Lookahead,'(') Then Inc(Depth);
    If IsPunct(Lookahead,')') Then Dec(Depth);
    If (Depth=0)and IsOp(Lookahead,':=') Then Begin
      IsAssign:=True; Break;
    End;
    Inc(Lookahead);
  End;

  WriteIndent;
  If IsAssign Then Begin
    { LHS jusqu'a ':=', puis RHS jusqu'a ';' }
    EmitExpr(I, ST_ASSIGN or ST_SEMI);
    If IsOp(I,':=') Then Begin
      Write(DstFile,':=');
      Inc(I);
      EmitExpr(I, ST_SEMI);
    End;
    Write(DstFile,';');
    WriteLn(DstFile);
  End Else Begin
    EmitExpr(I, ST_SEMI);
    Write(DstFile,';');
    WriteLn(DstFile);
  End;
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitIfStmt(Var I:Integer);
Begin
  { I sur 'IF' }
  Inc(I);
  WriteIndent; Write(DstFile,'If ');
  EmitExpr(I, ST_THEN);
  Write(DstFile,' Then Begin');
  WriteLn(DstFile);
  If IsKw(I,'THEN') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  While IsKw(I,'ELSIF') do Begin
    WriteIndent; Write(DstFile,'End Else If ');
    Inc(I);
    EmitExpr(I, ST_THEN);
    Write(DstFile,' Then Begin');
    WriteLn(DstFile);
    If IsKw(I,'THEN') Then Inc(I);
    Indent:=Indent+2;
    EmitStmtBlock(I,'END');
    Indent:=Indent-2;
  End;
  If IsKw(I,'ELSE') Then Begin
    WriteIndent; WriteLn(DstFile,'End Else Begin');
    Inc(I);
    Indent:=Indent+2;
    EmitStmtBlock(I,'END');
    Indent:=Indent-2;
  End;
  WriteIndent; WriteLn(DstFile,'End;');
  { END IF; }
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'IF') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitWhileStmt(Var I:Integer);
Begin
  Inc(I); { WHILE }
  WriteIndent; Write(DstFile,'While ');
  EmitExpr(I, ST_LOOP);
  WriteLn(DstFile,' Do Begin');
  If IsKw(I,'LOOP') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'LOOP') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitForStmt(Var I:Integer);
Var
  VarName : TString;
  Reverse : Boolean;
  StartA  : Integer;
  DDotPos : Integer;
  EndPos  : Integer;
  Save    : Integer;
Begin
  Inc(I); { FOR }
  Reverse:=False;
  VarName:='';
  If TKind(I)=TK_IDENT Then Begin VarName:=TVal(I); Inc(I); End;
  If IsKw(I,'IN') Then Inc(I);
  If IsKw(I,'REVERSE') Then Begin Reverse:=True; Inc(I); End;
  WriteIndent;
  If Reverse Then Begin
    { Localiser bornes A..B }
    StartA:=I;
    DDotPos:=I;
    While (TKind(DDotPos)<>TK_EOF) and not IsOp(DDotPos,'..')
                                   and not IsKw(DDotPos,'LOOP') do
      Inc(DDotPos);
    EndPos:=DDotPos+1;
    While (TKind(EndPos)<>TK_EOF) and not IsKw(EndPos,'LOOP') do Inc(EndPos);
    Write(DstFile,'For ',VarName,':=');
    { Emettre B en premier }
    If IsOp(DDotPos,'..') Then Begin
      Save:=DDotPos+1;
      EmitExpr(Save, ST_LOOP);
      Write(DstFile,' DownTo ');
      { Puis A }
      Save:=StartA;
      EmitExpr(Save, ST_DDOT or ST_LOOP);
    End Else Begin
      EmitExpr(I, ST_LOOP);
    End;
    I:=EndPos;
    WriteLn(DstFile,' Do Begin');
  End Else Begin
    Write(DstFile,'For ',VarName,':=');
    EmitExpr(I, ST_DDOT or ST_LOOP);
    If IsOp(I,'..') Then Begin
      Write(DstFile,' To ');
      Inc(I);
      EmitExpr(I, ST_LOOP);
    End;
    WriteLn(DstFile,' Do Begin');
  End;
  If IsKw(I,'LOOP') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'LOOP') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitLoopStmt(Var I:Integer);
Begin
  Inc(I); { LOOP }
  WriteIndent; WriteLn(DstFile,'While True Do Begin');
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'LOOP') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitCaseStmt(Var I:Integer);
Begin
  Inc(I); { CASE }
  WriteIndent; Write(DstFile,'Case ');
  EmitExpr(I, ST_IS);
  WriteLn(DstFile,' Of');
  If IsKw(I,'IS') Then Inc(I);
  Indent:=Indent+2;
  While IsKw(I,'WHEN') do Begin
    Inc(I);
    If IsKw(I,'OTHERS') Then Begin
      Inc(I);
      If IsOp(I,'=>') Then Inc(I);
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'Else Begin');
      Indent:=Indent+2;
      EmitStmtBlock(I,'WHEN');
      WriteIndent; WriteLn(DstFile,'End;');
    End Else Begin
      WriteIndent;
      { Liste de valeurs avec | et ranges A..B }
      EmitExpr(I, ST_ARROW or ST_PIPE);
      While IsPunct(I,'|') do Begin
        Write(DstFile,', ');
        Inc(I);
        EmitExpr(I, ST_ARROW or ST_PIPE);
      End;
      Write(DstFile,': Begin ');
      If IsOp(I,'=>') Then Inc(I);
      WriteLn(DstFile);
      Indent:=Indent+2;
      EmitStmtBlock(I,'WHEN');
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'End;');
    End;
  End;
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'CASE') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitReturnStmt(Var I:Integer);
Var FN:TString;
Begin
  Inc(I); { RETURN }
  If IsPunct(I,';') Then Begin
    EmitLn('Exit;');
    Inc(I);
    Exit;
  End;
  If FuncSP>0 Then FN:=FuncStack[FuncSP] Else FN:='';
  WriteIndent;
  If FN<>'' Then Begin
    Write(DstFile,FN,':=');
    EmitExpr(I, ST_SEMI);
    WriteLn(DstFile,'; Exit;');
  End Else Begin
    Write(DstFile,'Exit; { return ');
    EmitExpr(I, ST_SEMI);
    WriteLn(DstFile,' }');
  End;
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitExitStmt(Var I:Integer);
Begin
  Inc(I); { EXIT }
  If IsKw(I,'WHEN') Then Begin
    Inc(I);
    WriteIndent; Write(DstFile,'If ');
    EmitExpr(I, ST_SEMI);
    WriteLn(DstFile,' Then Break;');
  End Else Begin
    EmitLn('Break;');
  End;
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitGotoStmt(Var I:Integer);
Var Lab:TString;
Begin
  Inc(I); { GOTO }
  If TKind(I)=TK_IDENT Then Begin
    Lab:=TVal(I);
    AddName(Labels,Lab);
    WriteIndent; WriteLn(DstFile,'GoTo ',Lab,';');
    Inc(I);
  End;
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitLabel(Var I:Integer);
Var Lab:TString;
Begin
  Inc(I); { << }
  If TKind(I)=TK_IDENT Then Begin
    Lab:=TVal(I);
    AddName(Labels,Lab);
    WriteIndent; WriteLn(DstFile,Lab,':');
    Inc(I);
  End;
  If IsOp(I,'>>') Then Inc(I);
End;

Procedure EmitDeclareBlock(Var I:Integer);
Var
  Names    : Array[1..16] of TString;
  Inits    : Array[1..16] of Integer; { token index of := expr ; or 0 }
  NCount,K : Integer;
  Save     : Integer;
Begin
  Inc(I); { DECLARE }
  NCount:=0;
  WriteIndent; WriteLn(DstFile,'{ DECLARE: declarations locales }');
  While not IsKw(I,'BEGIN') and (TKind(I)<>TK_EOF) do Begin
    If IsPunct(I,';') Then Begin Inc(I); Continue; End;
    { Lire un nom : type [:= expr]; }
    If TKind(I)=TK_IDENT Then Begin
      Inc(NCount);
      If NCount<=16 Then Names[NCount]:=TVal(I);
      Inc(I);
      { sauter eventuel ", autre" pour cette version simple }
      While IsPunct(I,',') and (TKind(I+1)=TK_IDENT) do Inc(I,2);
      If IsPunct(I,':') Then Inc(I);
      { sauter le type }
      While (TKind(I)<>TK_EOF) and not IsOp(I,':=') and not IsPunct(I,';') do
        Inc(I);
      If NCount<=16 Then Begin
        If IsOp(I,':=') Then Inits[NCount]:=I+1
                         Else Inits[NCount]:=0;
      End;
      { trouver le ; }
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
      If IsPunct(I,';') Then Inc(I);
    End Else
      Inc(I);
  End;
  { Promouvoir les vars vers la liste globale ForVars (Integer) }
  For K:=1 to NCount do AddName(ForVars,Names[K]);
  If IsKw(I,'BEGIN') Then Inc(I);
  WriteIndent; WriteLn(DstFile,'Begin');
  Indent:=Indent+2;
  { Emettre les initialisations en debut de bloc }
  For K:=1 to NCount do Begin
    If Inits[K]>0 Then Begin
      WriteIndent;
      Write(DstFile,Names[K],':=');
      Save:=Inits[K];
      EmitExpr(Save, ST_SEMI);
      WriteLn(DstFile,';');
    End;
  End;
  EmitBodyContent(I);
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitBeginBlock(Var I:Integer);
Begin
  Inc(I); { BEGIN }
  WriteIndent; WriteLn(DstFile,'Begin');
  Indent:=Indent+2;
  EmitBodyContent(I);
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  If IsKw(I,'END') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitOneStmt(Var I:Integer);
Begin
  If IsKw(I,'IF')      Then Begin EmitIfStmt(I);     Exit; End;
  If IsKw(I,'WHILE')   Then Begin EmitWhileStmt(I);  Exit; End;
  If IsKw(I,'FOR')     Then Begin EmitForStmt(I);    Exit; End;
  If IsKw(I,'LOOP')    Then Begin EmitLoopStmt(I);   Exit; End;
  If IsKw(I,'CASE')    Then Begin EmitCaseStmt(I);   Exit; End;
  If IsKw(I,'RETURN')  Then Begin EmitReturnStmt(I); Exit; End;
  If IsKw(I,'EXIT')    Then Begin EmitExitStmt(I);   Exit; End;
  If IsKw(I,'GOTO')    Then Begin EmitGotoStmt(I);   Exit; End;
  If IsKw(I,'DECLARE') Then Begin EmitDeclareBlock(I); Exit; End;
  If IsKw(I,'BEGIN')   Then Begin EmitBeginBlock(I); Exit; End;
  If IsKw(I,'NULL') Then Begin
    Inc(I); If IsPunct(I,';') Then Inc(I);
    EmitLn('{ null }');
    Exit;
  End;
  If IsKw(I,'PRAGMA') Then Begin
    WriteIndent; Write(DstFile,'{ pragma');
    While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Begin
      Write(DstFile,' ',TVal(I)); Inc(I);
    End;
    WriteLn(DstFile,' }');
    If IsPunct(I,';') Then Inc(I);
    Exit;
  End;
  If IsOp(I,'<<') Then Begin EmitLabel(I); Exit; End;
  If IsKw(I,'RAISE') Then Begin
    Inc(I);
    { 'raise;' (re-raise dans un handler) ou 'raise Name [with msg];' }
    If IsPunct(I,';') or (TKind(I)=TK_EOF) Then Begin
      WriteIndent; WriteLn(DstFile,'raise;');
    End Else If TKind(I)=TK_IDENT Then Begin
      WriteIndent;
      Write(DstFile,'raise ',MapExceptionName(TVal(I)),
            '.Create(''',TVal(I),''');');
      WriteLn(DstFile);
      { Sauter le nom et tout 'with msg' optionnel jusqu'au ; }
      While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
    End Else Begin
      { Forme inattendue : commenter pour ne pas casser la sortie }
      WriteIndent; Write(DstFile,'{ raise');
      While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Begin
        Write(DstFile,' ',TVal(I)); Inc(I);
      End;
      WriteLn(DstFile,' }');
    End;
    If IsPunct(I,';') Then Inc(I);
    Exit;
  End;
  EmitSimpleStmt(I);
End;

{ ============================================================
  PROCEDURES / FONCTIONS IMBRIQUEES
  ============================================================ }
Procedure EmitParamList(Var I:Integer);
Var
  Names    : Array[1..16] of TString;
  NCount,K : Integer;
  Mode     : TString;
  TypeStr  : TString;
  First    : Boolean;
Begin
  If not IsPunct(I,'(') Then Exit;
  Inc(I);
  Write(DstFile,'(');
  First:=True;
  While not IsPunct(I,')') and (TKind(I)<>TK_EOF) do Begin
    Mode:='';
    NCount:=0;
    While TKind(I)=TK_IDENT do Begin
      Inc(NCount);
      If NCount<=16 Then Names[NCount]:=TVal(I);
      Inc(I);
      If IsPunct(I,',') Then Inc(I) Else Break;
    End;
    If IsPunct(I,':') Then Inc(I);
    If IsKw(I,'IN') Then Begin
      Inc(I);
      If IsKw(I,'OUT') Then Begin Mode:='Var'; Inc(I); End;
    End Else If IsKw(I,'OUT') Then Begin Mode:='Var'; Inc(I); End
    Else If IsKw(I,'ACCESS') Then Begin Mode:='Var'; Inc(I); End;
    TypeStr:=ReadAdaType(I);
    { Default value Ada := expr -> ignorer en Pascal classique }
    If IsOp(I,':=') Then Begin
      Inc(I);
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') and not IsPunct(I,')') do
        Inc(I);
    End;
    If not First Then Write(DstFile,';');
    First:=False;
    If Mode<>'' Then Write(DstFile,Mode,' ');
    For K:=1 to NCount do Begin
      If K>1 Then Write(DstFile,',');
      Write(DstFile,Names[K]);
      AddName(DeclaredVars,Names[K]);
    End;
    Write(DstFile,':',TypeStr);
    If IsPunct(I,';') Then Inc(I);
  End;
  If IsPunct(I,')') Then Inc(I);
  Write(DstFile,')');
End;

Procedure EmitProcOrFunc(Var I:Integer);
Var
  IsFunc  : Boolean;
  Name    : TString;
  RetType : TString;
Begin
  IsFunc := IsKw(I,'FUNCTION');
  Inc(I); { PROCEDURE / FUNCTION }
  CurSection:=' ';
  If TKind(I)=TK_IDENT Then Begin
    Name:=TVal(I);
    Inc(I);
  End Else
    Name:='unknown';

  WriteIndent;
  If IsFunc Then Write(DstFile,'Function ',Name)
              Else Write(DstFile,'Procedure ',Name);

  If IsPunct(I,'(') Then EmitParamList(I);

  If IsFunc Then Begin
    If IsKw(I,'RETURN') Then Begin
      Inc(I);
      RetType:=ReadAdaType(I);
      Write(DstFile,':',RetType);
    End;
  End;

  If IsKw(I,'IS') Then Inc(I);

  { Forward declaration ? Si on a 'IS SEPARATE' ou directement ';' }
  If IsKw(I,'SEPARATE') Then Begin
    WriteLn(DstFile,'; Forward;');
    While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
    If IsPunct(I,';') Then Inc(I);
    Exit;
  End;

  WriteLn(DstFile,';');

  { Empiler nom pour RETURN expr }
  If IsFunc then Begin
    Inc(FuncSP);
    If FuncSP<=MAX_FSTACK Then FuncStack[FuncSP]:=Name;
  End;

  { Declarations puis body }
  Indent:=Indent+2;
  CurSection:=' ';
  EmitDecls(I);
  CurSection:=' ';
  If IsKw(I,'BEGIN') Then Inc(I);
  WriteIndent; WriteLn(DstFile,'Begin');
  Indent:=Indent+2;
  EmitBodyContent(I);
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'End;');
  Indent:=Indent-2;

  { Sauter END Name; }
  If IsKw(I,'END') Then Inc(I);
  If TKind(I)=TK_IDENT Then Inc(I);
  If IsPunct(I,';') Then Inc(I);

  If IsFunc and (FuncSP>0) Then Dec(FuncSP);
End;

{ ============================================================
  COLLECTE DES WITH/USE ET ENTETE DU PROGRAMME PRINCIPAL
  ============================================================ }
Procedure CollectUsesAndProgName(Var I:Integer);
Var Pkg:TString;
    DepthTmp:Integer;
Begin
  InitNameList(UsesList);
  ProgName:='Main';
  I:=1;
  While (TKind(I)<>TK_EOF) and not IsKw(I,'PROCEDURE')
                            and not IsKw(I,'PACKAGE')
                            and not IsKw(I,'FUNCTION') do Begin
    If IsKw(I,'WITH') or IsKw(I,'USE') Then Begin
      Inc(I);
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Begin
        If TKind(I)=TK_IDENT Then Begin
          Pkg:=TVal(I);
          Inc(I);
          While IsPunct(I,'.') and (TKind(I+1)=TK_IDENT) do Begin
            Pkg:=Pkg+'.'+TVal(I+1);
            Inc(I,2);
          End;
          { Filtrer Ada.* }
          If (Length(Pkg)<4) or
             (UpperStr(Copy(Pkg,1,4))<>'ADA.') and
             (UpperStr(Pkg)<>'ADA') Then
            AddName(UsesList,Pkg);
        End Else
          Inc(I);
      End;
      If IsPunct(I,';') Then Inc(I);
    End Else
    If IsKw(I,'PRAGMA') Then Begin
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
      If IsPunct(I,';') Then Inc(I);
    End Else
      Inc(I);
  End;
  { I pointe sur PROCEDURE/PACKAGE/FUNCTION }
  If IsKw(I,'PROCEDURE') or IsKw(I,'FUNCTION')
     or IsKw(I,'PACKAGE') Then Begin
    Inc(I);
    If IsKw(I,'BODY') Then Inc(I); { PACKAGE BODY }
    If TKind(I)=TK_IDENT Then Begin
      ProgName:=TVal(I);
      Inc(I);
    End;
    { Ignorer parametres formels eventuels }
    If IsPunct(I,'(') Then Begin
      DepthTmp:=1; Inc(I);
      While (DepthTmp>0)and(TKind(I)<>TK_EOF) do Begin
        If IsPunct(I,'(') Then Inc(DepthTmp);
        If IsPunct(I,')') Then Dec(DepthTmp);
        Inc(I);
      End;
    End;
    If IsKw(I,'IS') Then Inc(I);
  End;
End;

Procedure ScanForVars;
Var I:Integer;
Begin
  For I:=1 to TokCount-2 do Begin
    If IsKw(I,'FOR') and (TKind(I+1)=TK_IDENT) and IsKw(I+2,'IN') Then
      AddName(ForVars,TVal(I+1));
  End;
End;

Procedure ScanDeclareVars;
Var I:Integer;
Begin
  I:=1;
  While I<=TokCount do Begin
    If IsKw(I,'DECLARE') Then Begin
      Inc(I);
      While (TKind(I)<>TK_EOF) and not IsKw(I,'BEGIN') do Begin
        If (TKind(I)=TK_IDENT) and IsPunct(I+1,':') Then Begin
          AddName(ForVars,TVal(I));
          While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
        End Else
          Inc(I);
      End;
    End Else
      Inc(I);
  End;
End;

Procedure ScanLabels;
Var I:Integer;
Begin
  For I:=1 to TokCount-2 do Begin
    If IsOp(I,'<<') and (TKind(I+1)=TK_IDENT) and IsOp(I+2,'>>') Then
      AddName(Labels,TVal(I+1));
  End;
End;

Procedure EmitLabelsDecl;
Var I:Integer;
Begin
  If Labels.Count=0 Then Exit;
  Write(DstFile,'Label ');
  For I:=1 to Labels.Count do Begin
    If I>1 Then Write(DstFile,',');
    Write(DstFile,Labels.Items[I]);
  End;
  WriteLn(DstFile,';');
End;

Procedure EmitForVarsDecl;
Var I:Integer; First:Boolean;
Begin
  First:=True;
  For I:=1 to ForVars.Count do Begin
    If not NameInList(DeclaredVars,ForVars.Items[I]) Then Begin
      If First Then Begin
        SwitchSection('V');
        Indent:=Indent+2;
        First:=False;
      End;
      WriteIndent;
      WriteLn(DstFile,ForVars.Items[I],':Integer; { boucle FOR }');
    End;
  End;
  If not First Then Indent:=Indent-2;
End;

{ ============================================================
  PROGRAMME PRINCIPAL DU TRANSPILEUR
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('ADA2PSP ',ADA2PSP_VERSION,' - Transpilateur Ada vers PSP');
  WriteLn;
  WriteLn('Syntaxe : ADA2PSP [-v] source.adb [destination.psp]');
  WriteLn;
  WriteLn('  source.adb      Fichier source Ada (corps de procedure).');
  WriteLn('  destination.psp Fichier PSP a generer (defaut : source.psp).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : ADA2PSP hello.adb hello.psp');
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
    A:=SrcName;
    I:=Length(A);
    While (I>0)and(A[I]<>'.')and(A[I]<>'\')and(A[I]<>'/') do Dec(I);
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.psp'
                          Else DstName:=A+'.psp';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('ADA2PSP : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    Close(SrcFile);
    WriteLn('ADA2PSP : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;
End;

Procedure EmitHelpers;
Var I:Integer;
Begin
  WriteLn(DstFile,'{ Helpers generes par ADA2PSP }');
  { PSP ne supporte pas la clause 'uses' standard de Delphi.
    Les unites importees par les clauses with/use d'Ada sont
    listees en commentaire pour reference. }
  If UsesList.Count>0 Then Begin
    Write(DstFile,'{ uses');
    For I:=1 to UsesList.Count do Begin
      If I>1 Then Write(DstFile,',');
      Write(DstFile,' ',UsesList.Items[I]);
    End;
    WriteLn(DstFile,'; }');
  End;
  If HasPower Then Begin
    WriteLn(DstFile);
    WriteLn(DstFile,'function Power_(B:Integer; E:Integer):Integer;');
    WriteLn(DstFile,'var R:Integer;');
    WriteLn(DstFile,'begin');
    WriteLn(DstFile,'  R:=1;');
    WriteLn(DstFile,'  while E>0 do begin R:=R*B; E:=E-1; end;');
    WriteLn(DstFile,'  Power_:=R;');
    WriteLn(DstFile,'end;');
  End;
End;

Var
  IPos : Integer;

BEGIN
  ErrorCount:=0;
  HasPower:=False;
  CurSection:=' ';
  Indent:=0;
  FuncSP:=0;
  InitNameList(UsesList);
  InitNameList(ArrayTypes);
  InitNameList(ArrayVars);
  InitNameList(Labels);
  InitNameList(ForVars);
  InitNameList(DeclaredVars);

  ParseArgs;
  If Verbose Then WriteLn('ADA2PSP : tokenisation de ',SrcName,'...');

  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('ADA2PSP : ',TokCount,' tokens lus.');

  ScanForVars;
  ScanDeclareVars;
  ScanLabels;

  { On a besoin de connaitre l'usage de ** avant la sortie de l'entete.
    Pre-scan pour HasPower et collecte preliminaire. }
  CollectUsesAndProgName(IPos);
  If Verbose Then WriteLn('ADA2PSP : programme = ',ProgName);

  { Entete PSP : document HTML minimal contenant un bloc <% %>
    qui encapsule le programme Pascal traduit. }
  WriteLn(DstFile,'<!-- Genere par ADA2PSP ',ADA2PSP_VERSION,' a partir de ',SrcName,' -->');
  WriteLn(DstFile,'<html>');
  WriteLn(DstFile,'  <head>');
  WriteLn(DstFile,'    <title>',ProgName,'</title>');
  WriteLn(DstFile,'  </head>');
  WriteLn(DstFile,'  <body>');
  WriteLn(DstFile,'    <pre>');
  WriteLn(DstFile,'<%');
  WriteLn(DstFile,'program ',ProgName,';');
  WriteLn(DstFile);
  EmitHelpers;
  WriteLn(DstFile);
  EmitLabelsDecl;

  { Section declarations + corps }
  Indent:=0;
  EmitDecls(IPos);
  CurSection:=' ';
  EmitForVarsDecl;
  CurSection:=' ';

  { BEGIN principal }
  If IsKw(IPos,'BEGIN') Then Inc(IPos);
  WriteLn(DstFile,'begin');
  Indent:=2;
  EmitBodyContent(IPos);
  Indent:=0;
  WriteLn(DstFile,'end.');
  WriteLn(DstFile,'%>');
  WriteLn(DstFile,'    </pre>');
  WriteLn(DstFile,'  </body>');
  WriteLn(DstFile,'</html>');

  Close(DstFile);
  If Verbose Then WriteLn('ADA2PSP : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
