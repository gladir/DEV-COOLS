{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Ada (.adb) vers Rust (.rs)
}

(* ============================================================
   ADA2RUST.PAS - Transpilateur Ada vers Rust
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Rust portable, compilable avec rustc.

   Couvre les constructions courantes :
     WITH / USE  (les paquets Ada.* sont ignores ;
                  les autres deviennent des commentaires
                  /* with: pkg */ ),
     PROCEDURE Nom IS ... END Nom; au sommet
       -> fn main() { ... }
     PROCEDURE / FUNCTION imbriquees -> fn libres,
     declarations CONSTANT / TYPE / SUBTYPE / VAR,
     TYPE ... IS RECORD / ARRAY / (enum) / RANGE A..B,
     IF / ELSIF / ELSE / END IF        -> if / else if / else,
     WHILE / FOR (REVERSE) / LOOP      -> while / for in / loop,
     EXIT [WHEN] / RETURN              -> break / return,
     CASE ... IS / WHEN x | y / OTHERS -> match ... { x | y => ..., _ => ... },
     blocs DECLARE et BEGIN anonymes (aplatis),
     Put / Put_Line / New_Line / Get / Get_Line / Skip_Line
       -> print! / println! / read_line_int / read_line_string.

   Limitations connues :
     - les genericites, taches et exceptions Ada ne sont pas
       traduites (signalees en commentaire dans la sortie).
     - les blocs DECLARE sont aplatis : leurs declarations
       locales sont remontees au scope englobant.
     - les types FLOAT digits / fixed point sont approximes
       par f64.
     - operateur ** est traduit via une fonction helper
       power_(...) emise au debut du fichier.
     - les attributs Ada 'First / 'Last / 'Range ne sont pas
       generalement supportes.
     - GOTO/<<labels>> Ada ne sont pas supportes en Rust ;
       deviennent un commentaire.
     - les enumerations Ada deviennent des `enum` Rust.
     - String Ada -> String Rust (par defaut).
     - Rust n'a pas de RANGE comme contrainte de type :
       ces clauses sont commentees.
   ============================================================ *)

Program ADA2RUST;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  ADA2RUST_VERSION = '1.0';
  ADA2RUST_DATE    = '2026-04-28';

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

  TFuncSig = Record
    Name      : TString;
    ParamCount: Integer;
    OutFlags  : Array[1..16] of Boolean;
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

  { Tables collectees pendant l'analyse pour la sortie Oberon }
  UsesList     : TNameList;        { paquets non-Ada.* a inclure }
  ArrayTypes   : TNameList;        { noms de types qui sont des Array }
  ArrayVars    : TNameList;        { variables typees Array         }
  Labels       : TNameList;        { etiquettes vues (<<lab>>)      }
  ForVars      : TNameList;        { variables de boucle FOR        }
  DeclaredVars : TNameList;        { vars deja declarees (objets)   }
  OutParams    : TNameList;        { params in out / out de fn courante }

  { Signatures detectees au pre-scan, pour traduire les sites d'appel. }
  FuncSigs     : Array[1..128] of TFuncSig;
  FuncSigCount : Integer;
  HasPower     : Boolean;          { true si ** rencontre           }
  UsesOut    : Boolean;          { true si Put/Get/etc. rencontre }
  UsesIO     : Boolean;          { true si stdin/stdout requis    }

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
  TRADUCTION DE CHAINES ADA -> RUST
  ============================================================ }
Function AdaStrToRust(const S:TString):TString;
Var I:Integer; R:TString; Ch:Char;
Begin
  R:='"';
  For I:=1 to Length(S) do Begin
    Ch:=S[I];
    Case Ch of
      '\':  R:=R+'\\';
      '"':  R:=R+'\"';
      #10:  R:=R+'\n';
      #13:  R:=R+'\r';
      #9:   R:=R+'\t';
    Else
      R:=R+Ch;
    End;
  End;
  R:=R+'"';
  AdaStrToRust:=R;
End;

Function MapType(const T:TString):TString;
Var U:TString;
Begin
  U:=UpperStr(T);
  If U='INTEGER'      Then MapType:='i32'
  Else If U='NATURAL' Then MapType:='u32'
  Else If U='POSITIVE'Then MapType:='u32'
  Else If U='LONG_INTEGER' Then MapType:='i64'
  Else If U='SHORT_INTEGER' Then MapType:='i16'
  Else If U='LONG_LONG_INTEGER' Then MapType:='i64'
  Else If U='FLOAT'   Then MapType:='f64'
  Else If U='LONG_FLOAT' Then MapType:='f64'
  Else If U='SHORT_FLOAT' Then MapType:='f32'
  Else If U='BOOLEAN' Then MapType:='bool'
  Else If U='CHARACTER' Then MapType:='char'
  Else If U='WIDE_CHARACTER' Then MapType:='char'
  Else If U='STRING'  Then MapType:='String'
  Else If U='WIDE_STRING' Then MapType:='String'
  Else MapType:=T;
End;

Function MapIdentInExpr(const N:TString):TString;
Var U:TString;
Begin
  U:=UpperStr(N);
  If U='TRUE'  Then MapIdentInExpr:='true'
  Else If U='FALSE' Then MapIdentInExpr:='false'
  Else MapIdentInExpr:=N;
End;

{ ============================================================
  EMISSION (sortie Oberon)
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
Function FindFuncSig(const N:TString):Integer; Forward;

{ Emet une expression scalaire/composite avec traduction de :
   - "..." -> "..." (Oberon)
   - 'X'  -> 'X' (Oberon)
   - /=   -> #
   - &    -> +    (concatenation approximee)
   - **   -> Power_(...) (en wrap binaire, simpliste)
   - mots-cles AND/OR/NOT/MOD/REM/ABS -> equivalents Oberon
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
  CallSig    : Array[0..63] of Integer; { idx FuncSigs ou 0 }
  CallArg    : Array[0..63] of Integer; { 1..ParamCount }

  Procedure EmitMutIfNeeded;
  Var SI:Integer;
  Begin
    If (ParenDepth<=63) and (ParenDepth>0) Then Begin
      SI:=CallSig[ParenDepth];
      If (SI>0) and (CallArg[ParenDepth]<=FuncSigs[SI].ParamCount)
                and (CallArg[ParenDepth]<=16)
                and FuncSigs[SI].OutFlags[CallArg[ParenDepth]] Then
        Write(DstFile,'&mut ');
    End;
  End;

  Function StopHere:Boolean;
  Begin
    StopHere:=False;
    If TKind(I)=TK_EOF Then Begin StopHere:=True; Exit; End;
    If ParenDepth>0 Then Exit;
    StopHere:=ExprStop(I,Stop);
  End;

Begin
  ParenDepth:=0;
  Prev:='';
  PrevK:=TK_EOF;
  CallSig[0]:=0;
  CallArg[0]:=0;
  While not StopHere do Begin
    K:=TKind(I);
    V:=TVal(I);
    Case K of
      TK_KEYWORD: Begin
        U:=V;
        If (U='AND') Then Begin
          { AND THEN -> && (court-circuit C) }
          If IsKw(I+1,'THEN') Then Begin
            Write(DstFile,' && '); Inc(I,2);
          End Else Begin
            Write(DstFile,' && '); Inc(I);
          End;
        End Else If (U='OR') Then Begin
          If IsKw(I+1,'ELSE') Then Begin
            Write(DstFile,' || '); Inc(I,2);
          End Else Begin
            Write(DstFile,' || '); Inc(I);
          End;
        End Else If U='NOT' Then Begin
          Write(DstFile,'!'); Inc(I);
        End Else If U='XOR' Then Begin
          { C : XOR booleen -> != ; pour bits, ^ }
          Write(DstFile,' ^ '); Inc(I);
        End Else If U='MOD' Then Begin
          Write(DstFile,' % '); Inc(I);
        End Else If U='REM' Then Begin
          Write(DstFile,' % '); Inc(I);
        End Else If U='ABS' Then Begin
          { Rust : x.abs() est postfix ; ici on emet `abs` en prefix
            qui produira `abs (x)` -- on convertit en helper Rust. }
          Write(DstFile,'/* abs */ '); Inc(I);
        End Else If U='IN' Then Begin
          { IN n'a pas d'equivalent Rust direct hors range. }
          Write(DstFile,' /* in */ '); Inc(I);
        End Else If U='NULL' Then Begin
          Write(DstFile,'None'); Inc(I);
        End Else If U='NEW' Then Begin
          Write(DstFile,'/* NEW */'); Inc(I);
        End Else If U='OTHERS' Then Begin
          Write(DstFile,'_'); Inc(I);
        End Else If U='RANGE' Then Begin
          Write(DstFile,' /* range */ '); Inc(I);
        End Else Begin
          { Mot-cle Ada non gere dans une expression : emettre tel quel. }
          Write(DstFile,LowerStr(U)); Inc(I);
        End;
      End;
      TK_OP: Begin
        If V='/=' Then Write(DstFile,'!=')
        Else If V='=' Then Write(DstFile,'==')
        Else If V='&' Then Write(DstFile,'+') { concatenation : approximation }
        Else If V='**' Then Begin
          HasPower:=True;
          Write(DstFile,' /* ** */ *');
        End
        Else If V='..' Then Write(DstFile,'..=')
        Else If V=':=' Then Write(DstFile,'=')
        Else If V='''' Then Write(DstFile,V)  { attribut, emet brut }
        Else Write(DstFile,V);
        Inc(I);
      End;
      TK_PUNCT: Begin
        If V='(' Then Begin
          Inc(ParenDepth);
          If ParenDepth<=63 Then Begin
            IsArrayCall[ParenDepth]:=False;
            CallSig[ParenDepth]:=0;
            CallArg[ParenDepth]:=0;
          End;
          If (PrevK=TK_IDENT)and NameInList(ArrayVars,Prev) Then Begin
            { Acces tableau Ada T(i) -> T[i] en Rust }
            Bracket:='[';
            If ParenDepth<=63 Then IsArrayCall[ParenDepth]:=True;
            Write(DstFile,Bracket);
          End Else Begin
            { Detecter appel a une fonction connue avec params out. }
            If (PrevK=TK_IDENT) and (ParenDepth<=63) Then Begin
              CallSig[ParenDepth]:=FindFuncSig(Prev);
              CallArg[ParenDepth]:=1;
            End;
            Write(DstFile,'(');
            EmitMutIfNeeded;
          End;
          Inc(I);
        End Else If V=')' Then Begin
          If (ParenDepth<=63)and(ParenDepth>0)and IsArrayCall[ParenDepth] Then
            Write(DstFile,']')
          Else
            Write(DstFile,')');
          If ParenDepth>0 Then Dec(ParenDepth);
          Inc(I);
        End Else If V=',' Then Begin
          Write(DstFile,',');
          { Avancer le compteur d'argument courant }
          If (ParenDepth<=63) and (ParenDepth>0)
             and (CallSig[ParenDepth]>0) Then Begin
            Inc(CallArg[ParenDepth]);
            Inc(I);
            EmitMutIfNeeded;
            { On a deja consomme la virgule ; aller au prochain tour
              de boucle. }
            Prev:=V; PrevK:=K;
            If K=TK_KEYWORD Then PrevK:=TK_KEYWORD;
            Continue;
          End;
          Inc(I);
        End Else If V='|' Then Begin
          { Separateur dans `match` : Rust utilise `|` aussi. }
          Write(DstFile,' | ');
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
        Write(DstFile,AdaStrToRust(V));
        Inc(I);
      End;
      TK_CHAR: Begin
        { Caractere Rust : 'X', avec escapes Rust si necessaire }
        Write(DstFile,'''');
        Case V[1] of
          '\':  Write(DstFile,'\\');
          '''': Write(DstFile,'\''');
          #10:  Write(DstFile,'\n');
          #13:  Write(DstFile,'\r');
          #9:   Write(DstFile,'\t');
        Else
          Write(DstFile,V);
        End;
        Write(DstFile,'''');
        Inc(I);
      End;
      TK_IDENT: Begin
        If NameInList(OutParams,V) Then
          Write(DstFile,'(*',V,')')
        Else
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
  les sections Oberon correspondantes (CONST / TYPE / VAR) et
  ajoute les nested PROCEDURE / FUNCTION.
  Renvoie via Var I la position de 'BEGIN'.
  InitStmts est rempli avec les initialisations 'X := expr;' issues
  des declarations 'X : T := expr;'.
}

Var
  CurSection : Char;  { 'C' Const, 'T' Type, 'V' Var, ' ' rien }

Procedure SwitchSection(NewSec:Char);
Begin
  { C n'a pas de sections CONST/TYPE/VAR distinctes :
    chaque declaration utilise sa propre forme. }
  If NewSec=CurSection Then Exit;
  CurSection:=NewSec;
End;

{ Forward }
Procedure EmitProcOrFunc(Var I:Integer); Forward;

{ Emet une declaration de type complete.
  I pointe sur 'TYPE' ou 'SUBTYPE'. En C, on tente d'emettre
  un typedef pour les RECORD, ARRAY et enums ; les autres
  declarations Ada deviennent des commentaires. }
Procedure EmitTypeDecl(Var I:Integer);
Var
  Name : TString;
  Base : TString;
  V    : TString;
  IsSub: Boolean;
  Lo,Hi: TString;
  ArrSz: TString;
  Save : Integer;
Begin
  IsSub := IsKw(I,'SUBTYPE');
  Inc(I); { TYPE / SUBTYPE }
  Name:='';
  If TKind(I)=TK_IDENT Then Begin
    Name:=TVal(I);
    Inc(I);
  End;
  If IsKw(I,'IS') Then Inc(I);

  If IsSub Then Begin
    { SUBTYPE Name IS Base [RANGE A..B]; -> type Name = Base; }
    Base:=ReadAdaType(I);
    If IsKw(I,'RANGE') Then Begin
      Inc(I);
      Write(DstFile,'type ',Name,' = ',Base,'; // range ');
      EmitExpr(I, ST_DDOT or ST_SEMI);
      If IsOp(I,'..') Then Begin
        Write(DstFile,'..='); Inc(I);
        EmitExpr(I, ST_SEMI);
      End;
      WriteLn(DstFile);
    End Else Begin
      WriteLn(DstFile,'type ',Name,' = ',Base,';');
    End;
  End Else
  If IsKw(I,'RECORD') Then Begin
    (* TYPE Name IS RECORD ... END RECORD; -> #[derive(Default)] struct Name { ... } *)
    Inc(I);
    WriteLn(DstFile,'#[derive(Default, Clone)]');
    WriteLn(DstFile,'struct ',Name,' {');
    While (TKind(I)<>TK_EOF) and not (IsKw(I,'END') and IsKw(I+1,'RECORD')) do Begin
      If IsPunct(I,';') Then Begin Inc(I); Continue; End;
      Save:=I;
      { Premiere passe : avancer pour saisir le type. }
      While TKind(I)=TK_IDENT do Begin
        Inc(I);
        If IsPunct(I,',') Then Inc(I) Else Break;
      End;
      If IsPunct(I,':') Then Inc(I);
      V:=ReadAdaType(I);
      { ignorer eventuel := default }
      If IsOp(I,':=') Then Begin
        Inc(I);
        While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
      End;
      { Reemettre les noms avec leur type Rust : `name: Type,`. }
      I:=Save;
      While TKind(I)=TK_IDENT do Begin
        Write(DstFile,'    ',TVal(I),': ',V,',');
        WriteLn(DstFile);
        Inc(I);
        If IsPunct(I,',') Then Inc(I) Else Break;
      End;
      If IsPunct(I,':') Then Inc(I);
      V:=ReadAdaType(I);
      If IsOp(I,':=') Then Begin
        Inc(I);
        While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
      End;
      If IsPunct(I,';') Then Inc(I);
    End;
    WriteLn(DstFile,'}');
    If IsKw(I,'END') Then Inc(I);
    If IsKw(I,'RECORD') Then Inc(I);
  End Else
  If IsKw(I,'ARRAY') Then Begin
    Inc(I);
    { ARRAY (lo..hi) OF Base -> type Name = [Base; size]; ou
      taille MAX_ARR si non determinable. }
    ArrSz:='256';
    If IsPunct(I,'(') Then Begin
      Inc(I);
      Lo:=''; Hi:='';
      While (TKind(I)<>TK_EOF) and not IsOp(I,'..') and not IsPunct(I,')') do Begin
        Lo:=Lo+TVal(I);
        Inc(I);
      End;
      If IsOp(I,'..') Then Begin
        Inc(I);
        While (TKind(I)<>TK_EOF) and not IsPunct(I,')') do Begin
          Hi:=Hi+TVal(I);
          Inc(I);
        End;
      End;
      If IsPunct(I,')') Then Inc(I);
      If (Hi<>'') and (Lo<>'') Then
        ArrSz:='(('+Hi+')-('+Lo+')+1) as usize';
    End;
    If IsKw(I,'OF') Then Begin
      Inc(I);
      Base:=ReadAdaType(I);
    End Else
      Base:='i32';
    WriteLn(DstFile,'type ',Name,' = [',Base,'; ',ArrSz,'];');
    If Length(Name)>0 Then AddName(ArrayTypes,Name);
  End Else
  If IsPunct(I,'(') Then Begin
    (* Type enum Ada (a,b,c) -> #[derive(...)] enum Name { a, b, c } *)
    WriteLn(DstFile,'#[derive(Copy, Clone, PartialEq, Eq, Debug)]');
    Write(DstFile,'enum ',Name,' { ');
    Inc(I);
    While (TKind(I)<>TK_EOF) and not IsPunct(I,')') do Begin
      If TKind(I)=TK_IDENT Then Write(DstFile,TVal(I));
      Inc(I);
      If IsPunct(I,',') Then Begin Write(DstFile,', '); Inc(I); End;
    End;
    If IsPunct(I,')') Then Inc(I);
    WriteLn(DstFile,' }');
  End Else
  If IsKw(I,'NEW') Then Begin
    Inc(I);
    Base:=ReadAdaType(I);
    WriteLn(DstFile,'type ',Name,' = ',Base,';');
    If IsKw(I,'RANGE') Then Begin
      Inc(I);
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
    End;
  End Else
  If IsKw(I,'RANGE') Then Begin
    Inc(I);
    Write(DstFile,'type ',Name,' = i32; // range ');
    EmitExpr(I, ST_DDOT or ST_SEMI);
    If IsOp(I,'..') Then Begin
      Write(DstFile,'..='); Inc(I);
      EmitExpr(I, ST_SEMI);
    End;
    WriteLn(DstFile);
  End Else Begin
    Base:=ReadAdaType(I);
    WriteLn(DstFile,'type ',Name,' = ',Base,';');
  End;
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
  RawType  : TString;
  IsString : Boolean;
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
  RawType:='';
  If TKind(I)=TK_IDENT Then RawType:=TVal(I);
  TypeStr:=ReadAdaType(I);
  IsString:=(UpperStr(RawType)='STRING')or(UpperStr(RawType)='WIDE_STRING');

  { Inscrire les variables de type tableau }
  If NameInList(ArrayTypes,RawType) or NameInList(ArrayTypes,TypeStr) Then
    For K:=1 to NCount do AddName(ArrayVars,Names[K]);
  If IsString Then
    For K:=1 to NCount do AddName(ArrayVars,Names[K]);

  { Inscrire toutes les variables/constantes declarees }
  For K:=1 to NCount do AddName(DeclaredVars,Names[K]);

  { Initialiseur ? }
  If IsOp(I,':=') Then Begin
    Inc(I);
    If IsConst Then Begin
      { CONSTANT Rust : const Name: Type = expr;
        Pour les constantes String, on emet plutot un &'static str. }
      WriteIndent;
      If IsString Then Begin
        Write(DstFile,'let ',Names[1],': &str = ');
        EmitExpr(I, ST_SEMI);
        WriteLn(DstFile,';');
      End Else Begin
        Write(DstFile,'const ',Names[1],': ',TypeStr,' = ');
        EmitExpr(I, ST_SEMI);
        WriteLn(DstFile,';');
      End;
    End Else Begin
      For K:=1 to NCount do Begin
        WriteIndent;
        If IsString Then Begin
          If K=1 Then Begin
            Write(DstFile,'let mut ',Names[K],': String = ');
            EmitExpr(I, ST_SEMI);
            WriteLn(DstFile,'.to_string();');
          End Else
            WriteLn(DstFile,'let mut ',Names[K],': String = String::new();');
        End Else Begin
          Write(DstFile,'let mut ',Names[K],': ',TypeStr,' = ');
          If K=1 Then EmitExpr(I, ST_SEMI)
          Else Write(DstFile,'Default::default()');
          WriteLn(DstFile,';');
        End;
      End;
    End;
  End Else Begin
    If IsConst Then Begin
      For K:=1 to NCount do Begin
        WriteIndent;
        WriteLn(DstFile,'const ',Names[K],': ',TypeStr,' = Default::default();');
      End;
    End Else Begin
      For K:=1 to NCount do Begin
        WriteIndent;
        If IsString Then
          WriteLn(DstFile,'let mut ',Names[K],': String = String::new();')
        Else If NameInList(ArrayVars,Names[K]) Then
          WriteLn(DstFile,'let mut ',Names[K],': ',TypeStr,' = Default::default();')
        Else
          WriteLn(DstFile,'let mut ',Names[K],': ',TypeStr,' = Default::default();');
      End;
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


{ Emet un appel a Put/Put_Line/Get/etc. en traduisant vers
  print!/println!/read_line de Rust.                       }
Procedure EmitIOCall(Var I:Integer; const Name:TString);
Var
  U        : TString;
  Depth    : Integer;
  Found    : Boolean;
  J        : Integer;
  ArgKind  : TTokenKind;
  IsPutLn  : Boolean;
  IsGet    : Boolean;
  HasArg   : Boolean;
Begin
  U:=UpperStr(Name);
  UsesOut:=True;
  UsesIO:=True;
  IsPutLn:=(U='PUT_LINE');
  IsGet:=(U='GET')or(U='GET_LINE');

  { Pas de () suivant -> appel sans argument }
  If not IsPunct(I,'(') Then Begin
    If U='NEW_LINE' Then EmitLn('println!();')
    Else If U='SKIP_LINE' Then EmitLn('let mut _skip = String::new(); std::io::stdin().read_line(&mut _skip).unwrap();')
    Else If U='PUT_LINE' Then EmitLn('println!();')
    Else If U='PUT' Then  { rien a faire }
    Else Begin
      WriteIndent; Write(DstFile,Name,'();'); WriteLn(DstFile);
    End;
    Exit;
  End;
  Inc(I); { ( }

  { Cas particuliers : Skip_Line(N) -> commentaire avec lecture }
  If U='SKIP_LINE' Then Begin
    WriteIndent;
    Write(DstFile,'// skip_line ');
    Depth:=1;
    While (Depth>0)and(TKind(I)<>TK_EOF) do Begin
      If IsPunct(I,'(') Then Inc(Depth)
      Else If IsPunct(I,')') Then Begin Dec(Depth); If Depth=0 Then Break; End;
      Write(DstFile,TVal(I)); Inc(I);
    End;
    If IsPunct(I,')') Then Inc(I);
    WriteLn(DstFile);
    EmitLn('{ let mut _skip = String::new(); std::io::stdin().read_line(&mut _skip).unwrap(); }');
    Exit;
  End;

  HasArg:=False;
  Depth:=1;
  While (Depth>0)and(TKind(I)<>TK_EOF) do Begin
    { Sauter ',' separateurs }
    If IsPunct(I,',') Then Begin Inc(I); Continue; End;
    If IsPunct(I,')') Then Begin
      Dec(Depth);
      If Depth=0 Then Begin Inc(I); Break; End;
      Inc(I); Continue;
    End;

    { Detecter parametre nomme A=>B et le sauter }
    Found:=False;
    J:=I;
    While (J<=TokCount) and not IsPunct(J,',') and not IsPunct(J,')') do Begin
      If IsOp(J,'=>') Then Begin Found:=True; Break; End;
      Inc(J);
    End;
    If Found Then Begin
      I:=J+1;
      While (TKind(I)<>TK_EOF) and not IsPunct(I,',') and not IsPunct(I,')') do
        Inc(I);
      Continue;
    End;

    HasArg:=True;
    ArgKind:=TKind(I);

    If IsGet Then Begin
      (* Get/Get_Line en Rust :
          Get_Line(s)  -> s.clear(); std::io::stdin().read_line(&mut s).unwrap();
                          s = s.trim_end_matches('\n').to_string();
          Get(x)       -> let mut tmp = String::new();
                          std::io::stdin().read_line(&mut tmp).unwrap();
                          x = tmp.trim().parse().unwrap(); *)
      WriteIndent;
      If U='GET_LINE' Then Begin
        { On capture l identifiant simple si possible. }
        If (TKind(I)=TK_IDENT) and (IsPunct(I+1,',') or IsPunct(I+1,')')) Then Begin
          Write(DstFile,'{ ',TVal(I),'.clear(); std::io::stdin().read_line(&mut ',TVal(I),').unwrap(); ');
          WriteLn(DstFile,TVal(I),' = ',TVal(I),'.trim_end_matches(''\n'').to_string(); }');
          Inc(I);
        End Else Begin
          Write(DstFile,'/* get_line(');
          EmitExpr(I, ST_RPAR or ST_COMMA);
          WriteLn(DstFile,') -- forme complexe */');
        End;
      End Else Begin
        Write(DstFile,'{ let mut _line = String::new(); std::io::stdin().read_line(&mut _line).unwrap(); ');
        EmitExpr(I, ST_RPAR or ST_COMMA);
        WriteLn(DstFile,' = _line.trim().parse().unwrap(); }');
      End;
    End Else Begin
      { Determiner le format selon le type d'argument }
      WriteIndent;
      Case ArgKind of
        TK_STRING : Begin
          { Chaine litterale. }
          If IsPutLn Then Write(DstFile,'println!(') Else Write(DstFile,'print!(');
          EmitExpr(I, ST_RPAR or ST_COMMA);
          WriteLn(DstFile,');');
          { Ne pas reemettre le println! final pour PUT_LINE. }
          IsPutLn:=False;
          Continue;
        End;
      Else
        If IsPutLn Then
          Write(DstFile,'println!("{}", ')
        Else
          Write(DstFile,'print!("{}", ');
        EmitExpr(I, ST_RPAR or ST_COMMA);
        WriteLn(DstFile,');');
        IsPutLn:=False;
      End;
    End;
  End;

  { New_Line : retour ligne final }
  If U='NEW_LINE' Then
    EmitLn('println!();');
  If IsPutLn then EmitLn('println!();');
  If (not HasArg) and (U='PUT') Then ; { rien }
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
    EmitExpr(I, ST_ASSIGN or ST_SEMI);
    If IsOp(I,':=') Then Begin
      Write(DstFile,' = ');
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
  WriteIndent; Write(DstFile,'if ');
  EmitExpr(I, ST_THEN);
  WriteLn(DstFile,' {');
  If IsKw(I,'THEN') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; Write(DstFile,'}');
  While IsKw(I,'ELSIF') do Begin
    Write(DstFile,' else if ');
    Inc(I);
    EmitExpr(I, ST_THEN);
    WriteLn(DstFile,' {');
    If IsKw(I,'THEN') Then Inc(I);
    Indent:=Indent+2;
    EmitStmtBlock(I,'END');
    Indent:=Indent-2;
    WriteIndent; Write(DstFile,'}');
  End;
  If IsKw(I,'ELSE') Then Begin
    WriteLn(DstFile,' else {');
    Inc(I);
    Indent:=Indent+2;
    EmitStmtBlock(I,'END');
    Indent:=Indent-2;
    WriteIndent; WriteLn(DstFile,'}');
  End Else
    WriteLn(DstFile);
  { END IF; }
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'IF') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitWhileStmt(Var I:Integer);
Begin
  Inc(I); { WHILE }
  WriteIndent; Write(DstFile,'while ');
  EmitExpr(I, ST_LOOP);
  WriteLn(DstFile,' {');
  If IsKw(I,'LOOP') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
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
    StartA:=I;
    DDotPos:=I;
    While (TKind(DDotPos)<>TK_EOF) and not IsOp(DDotPos,'..')
                                   and not IsKw(DDotPos,'LOOP') do
      Inc(DDotPos);
    EndPos:=DDotPos+1;
    While (TKind(EndPos)<>TK_EOF) and not IsKw(EndPos,'LOOP') do Inc(EndPos);
    Write(DstFile,'for ',VarName,' in (');
    If IsOp(DDotPos,'..') Then Begin
      { Borne basse .. borne haute, puis .rev() }
      Save:=StartA;
      EmitExpr(Save, ST_DDOT or ST_LOOP);
      Write(DstFile,'..=');
      Save:=DDotPos+1;
      EmitExpr(Save, ST_LOOP);
    End Else Begin
      EmitExpr(I, ST_LOOP);
    End;
    I:=EndPos;
    WriteLn(DstFile,').rev() {');
  End Else Begin
    Write(DstFile,'for ',VarName,' in ');
    EmitExpr(I, ST_DDOT or ST_LOOP);
    If IsOp(I,'..') Then Begin
      Write(DstFile,'..=');
      Inc(I);
      EmitExpr(I, ST_LOOP);
    End;
    WriteLn(DstFile,' {');
  End;
  If IsKw(I,'LOOP') Then Inc(I);
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'LOOP') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitLoopStmt(Var I:Integer);
Begin
  Inc(I); { LOOP }
  WriteIndent; WriteLn(DstFile,'loop {');
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'LOOP') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitCaseStmt(Var I:Integer);
Var
  First : Boolean;
Begin
  Inc(I); { CASE }
  WriteIndent; Write(DstFile,'match ');
  EmitExpr(I, ST_IS);
  WriteLn(DstFile,' {');
  If IsKw(I,'IS') Then Inc(I);
  Indent:=Indent+2;
  While IsKw(I,'WHEN') do Begin
    Inc(I);
    If IsKw(I,'OTHERS') Then Begin
      Inc(I);
      If IsOp(I,'=>') Then Inc(I);
      WriteIndent; WriteLn(DstFile,'_ => {');
      Indent:=Indent+2;
      EmitStmtBlock(I,'WHEN');
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'},');
    End Else Begin
      WriteIndent;
      First:=True;
      { Premiere alternative : potentiellement plage A..B ou liste a|b|c. }
      While True do Begin
        If not First Then Write(DstFile,' | ');
        First:=False;
        If (TKind(I)<>TK_EOF) and IsOp(I+1,'..') Then Begin
          { Plage : tok .. tok -> tok..=tok }
          Write(DstFile,TVal(I),'..=',TVal(I+2));
          Inc(I,3);
        End Else Begin
          EmitExpr(I, ST_ARROW or ST_PIPE);
        End;
        If IsPunct(I,'|') Then Begin
          Inc(I);
        End Else
          Break;
      End;
      If IsOp(I,'=>') Then Inc(I);
      WriteLn(DstFile,' => {');
      Indent:=Indent+2;
      EmitStmtBlock(I,'WHEN');
      Indent:=Indent-2;
      WriteIndent; WriteLn(DstFile,'},');
    End;
  End;
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
  If IsKw(I,'END') Then Inc(I);
  If IsKw(I,'CASE') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitReturnStmt(Var I:Integer);
Begin
  Inc(I); { RETURN }
  If IsPunct(I,';') Then Begin
    EmitLn('return;');
    Inc(I);
    Exit;
  End;
  WriteIndent;
  Write(DstFile,'return ');
  EmitExpr(I, ST_SEMI);
  WriteLn(DstFile,';');
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitExitStmt(Var I:Integer);
Begin
  Inc(I); { EXIT }
  If IsKw(I,'WHEN') Then Begin
    Inc(I);
    WriteIndent; Write(DstFile,'if ');
    EmitExpr(I, ST_SEMI);
    WriteLn(DstFile,' { break; }');
  End Else Begin
    EmitLn('break;');
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
    WriteIndent; WriteLn(DstFile,'// goto ',Lab,' (non supporte en Rust)');
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
    WriteIndent; WriteLn(DstFile,'// <<',Lab,'>>');
    Inc(I);
  End;
  If IsOp(I,'>>') Then Inc(I);
End;

Procedure EmitDeclareBlock(Var I:Integer);
Var
  Names    : Array[1..16] of TString;
  Inits    : Array[1..16] of Integer;
  Types    : Array[1..16] of TString;
  NCount,K : Integer;
  Save     : Integer;
  TName    : TString;
Begin
  Inc(I); { DECLARE }
  NCount:=0;
  WriteIndent; WriteLn(DstFile,'{ // declare');
  Indent:=Indent+2;
  While not IsKw(I,'BEGIN') and (TKind(I)<>TK_EOF) do Begin
    If IsPunct(I,';') Then Begin Inc(I); Continue; End;
    If TKind(I)=TK_IDENT Then Begin
      Inc(NCount);
      If NCount<=16 Then Begin
        Names[NCount]:=TVal(I);
        Types[NCount]:='i32';
      End;
      Inc(I);
      While IsPunct(I,',') and (TKind(I+1)=TK_IDENT) do Inc(I,2);
      If IsPunct(I,':') Then Inc(I);
      If IsKw(I,'CONSTANT') Then Inc(I);
      If TKind(I)=TK_IDENT Then Begin
        TName:=ReadAdaType(I);
        If NCount<=16 Then Types[NCount]:=TName;
      End;
      While (TKind(I)<>TK_EOF) and not IsOp(I,':=') and not IsPunct(I,';') do
        Inc(I);
      If NCount<=16 Then Begin
        If IsOp(I,':=') Then Inits[NCount]:=I+1
                         Else Inits[NCount]:=0;
      End;
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') do Inc(I);
      If IsPunct(I,';') Then Inc(I);
    End Else
      Inc(I);
  End;
  { Emettre les declarations Rust locales }
  For K:=1 to NCount do Begin
    AddName(DeclaredVars,Names[K]);
    WriteIndent;
    If Inits[K]>0 Then Begin
      Write(DstFile,'let mut ',Names[K],': ',Types[K],' = ');
      Save:=Inits[K];
      EmitExpr(Save, ST_SEMI);
      WriteLn(DstFile,';');
    End Else
      WriteLn(DstFile,'let mut ',Names[K],': ',Types[K],' = Default::default();');
  End;
  If IsKw(I,'BEGIN') Then Inc(I);
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
  If IsKw(I,'END') Then Inc(I);
  If IsPunct(I,';') Then Inc(I);
End;

Procedure EmitBeginBlock(Var I:Integer);
Begin
  Inc(I); { BEGIN }
  WriteIndent; WriteLn(DstFile,'{');
  Indent:=Indent+2;
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');
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
    EmitLn('// null');
    Exit;
  End;
  If IsKw(I,'PRAGMA') Then Begin
    WriteIndent; Write(DstFile,'// pragma');
    While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Begin
      Write(DstFile,' ',TVal(I)); Inc(I);
    End;
    WriteLn(DstFile);
    If IsPunct(I,';') Then Inc(I);
    Exit;
  End;
  If IsOp(I,'<<') Then Begin EmitLabel(I); Exit; End;
  If IsKw(I,'RAISE') Then Begin
    WriteIndent; Write(DstFile,'// raise');
    Inc(I);
    While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Begin
      Write(DstFile,' ',TVal(I)); Inc(I);
    End;
    WriteLn(DstFile);
    EmitLn('std::process::exit(1);');
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
  IsOut    : Boolean;
  TypeStr  : TString;
  RawType  : TString;
  IsString : Boolean;
  First    : Boolean;
Begin
  If not IsPunct(I,'(') Then Begin
    Write(DstFile,'()');
    Exit;
  End;
  Inc(I);
  Write(DstFile,'(');
  First:=True;
  While not IsPunct(I,')') and (TKind(I)<>TK_EOF) do Begin
    IsOut:=False;
    NCount:=0;
    While TKind(I)=TK_IDENT do Begin
      Inc(NCount);
      If NCount<=16 Then Names[NCount]:=TVal(I);
      Inc(I);
      If IsPunct(I,',') Then Inc(I) Else Break;
    End;
    If IsPunct(I,':') Then Inc(I);
    { mode : IN (default, valeur), OUT/IN OUT/ACCESS -> &mut }
    If IsKw(I,'IN') Then Begin
      Inc(I);
      If IsKw(I,'OUT') Then Begin IsOut:=True; Inc(I); End;
    End Else If IsKw(I,'OUT') Then Begin IsOut:=True; Inc(I); End
    Else If IsKw(I,'ACCESS') Then Begin IsOut:=True; Inc(I); End;
    RawType:='';
    If TKind(I)=TK_IDENT Then RawType:=TVal(I);
    TypeStr:=ReadAdaType(I);
    IsString:=(UpperStr(RawType)='STRING')or(UpperStr(RawType)='WIDE_STRING');
    If IsOp(I,':=') Then Begin
      Inc(I);
      While (TKind(I)<>TK_EOF) and not IsPunct(I,';') and not IsPunct(I,')') do
        Inc(I);
    End;
    For K:=1 to NCount do Begin
      If not First Then Write(DstFile,', ');
      First:=False;
      If IsString Then Begin
        If IsOut Then Begin
          Write(DstFile,Names[K],': &mut String');
          AddName(OutParams,Names[K]);
        End Else
          Write(DstFile,Names[K],': &str');
        AddName(ArrayVars,Names[K]);
      End Else If IsOut Then Begin
        Write(DstFile,Names[K],': &mut ',TypeStr);
        AddName(OutParams,Names[K]);
      End Else
        Write(DstFile,Names[K],': ',TypeStr);
      AddName(DeclaredVars,Names[K]);
    End;
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
  SaveI   : Integer;
  EndSig  : Integer;
  Depth   : Integer;
  J       : Integer;
  SavedOutParams : TNameList;
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

  RetType:='';
  If IsFunc Then Begin
    SaveI:=I;
    Depth:=0;
    EndSig:=I;
    While (TKind(EndSig)<>TK_EOF) and not IsKw(EndSig,'IS') do Begin
      If IsPunct(EndSig,'(') Then Inc(Depth);
      If IsPunct(EndSig,')') Then Dec(Depth);
      If (Depth=0) and IsKw(EndSig,'RETURN') Then Begin
        J:=EndSig+1;
        RetType:=ReadAdaType(J);
        Break;
      End;
      Inc(EndSig);
    End;
    I:=SaveI;
  End;

  Write(DstFile,'fn ',Name);
  { Sauver/initialiser OutParams pour cette fonction }
  SavedOutParams:=OutParams;
  InitNameList(OutParams);
  EmitParamList(I);
  If IsFunc and (RetType<>'') Then Write(DstFile,' -> ',RetType);

  If IsFunc and IsKw(I,'RETURN') Then Begin
    Inc(I);
    RetType:=ReadAdaType(I);
    If RetType='' Then ;
  End;

  If IsKw(I,'IS') Then Inc(I);

  If IsKw(I,'SEPARATE') Then Begin
    WriteLn(DstFile,'; // FORWARD');
    While not IsPunct(I,';') and (TKind(I)<>TK_EOF) do Inc(I);
    If IsPunct(I,';') Then Inc(I);
    OutParams:=SavedOutParams;
    Exit;
  End;

  WriteLn(DstFile,' {');

  If IsFunc then Begin
    Inc(FuncSP);
    If FuncSP<=MAX_FSTACK Then FuncStack[FuncSP]:=Name;
  End;

  Indent:=Indent+2;
  CurSection:=' ';
  EmitDecls(I);
  CurSection:=' ';
  If IsKw(I,'BEGIN') Then Inc(I);
  EmitStmtBlock(I,'END');
  Indent:=Indent-2;
  WriteIndent; WriteLn(DstFile,'}');

  If IsKw(I,'END') Then Inc(I);
  If TKind(I)=TK_IDENT Then Inc(I);
  If IsPunct(I,';') Then Inc(I);

  If IsFunc and (FuncSP>0) Then Dec(FuncSP);
  { Restaurer OutParams }
  OutParams:=SavedOutParams;
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

Procedure ScanIO;
Var I:Integer; U:TString;
Begin
  For I:=1 to TokCount do Begin
    If TKind(I)=TK_IDENT Then Begin
      U:=UpperStr(TVal(I));
      If (U='PUT')or(U='PUT_LINE')or(U='NEW_LINE')
       or(U='GET')or(U='GET_LINE')or(U='SKIP_LINE') Then Begin
        UsesOut:=True;
        UsesIO:=True;
        Exit;
      End;
    End;
  End;
End;

Procedure ScanPower;
Var I:Integer;
Begin
  For I:=1 to TokCount do
    If IsOp(I,'**') Then Begin HasPower:=True; Exit; End;
End;

Function FindFuncSig(const N:TString):Integer;
Var I:Integer;
Begin
  FindFuncSig:=0;
  For I:=1 to FuncSigCount do
    If UpperStr(FuncSigs[I].Name)=UpperStr(N) Then Begin
      FindFuncSig:=I; Exit;
    End;
End;

{ Pre-scan : detecte les signatures de PROCEDURE / FUNCTION et
  enregistre, pour chaque parametre, s'il est `in out` ou `out`
  (cas qui correspondent a `&mut` en Rust). }
Procedure ScanFuncSigs;
Var
  I,J,K  : Integer;
  Sig    : TFuncSig;
  Depth  : Integer;
  IsOut  : Boolean;
  GroupNames : Integer;
Begin
  FuncSigCount:=0;
  I:=1;
  While I<=TokCount do Begin
    If IsKw(I,'PROCEDURE') or IsKw(I,'FUNCTION') Then Begin
      Inc(I);
      If TKind(I)<>TK_IDENT Then Continue;
      Sig.Name:=TVal(I);
      Sig.ParamCount:=0;
      For K:=1 to 16 do Sig.OutFlags[K]:=False;
      Inc(I);
      { Liste de parametres optionnelle }
      If IsPunct(I,'(') Then Begin
        Inc(I);
        Depth:=1;
        While (Depth>0) and (TKind(I)<>TK_EOF) do Begin
          { Compter les identifiants jusqu'a `:` (au niveau 1) }
          GroupNames:=0;
          IsOut:=False;
          While (Depth>0) and (TKind(I)<>TK_EOF) and not IsPunct(I,':') do Begin
            If IsPunct(I,'(') Then Inc(Depth)
            Else If IsPunct(I,')') Then Begin
              Dec(Depth);
              If Depth=0 Then Begin Inc(I); Break; End;
            End
            Else If (Depth=1) and (TKind(I)=TK_IDENT) Then Inc(GroupNames);
            Inc(I);
          End;
          If Depth=0 Then Break;
          If IsPunct(I,':') Then Inc(I);
          { Lire mode }
          If IsKw(I,'IN') Then Begin
            Inc(I);
            If IsKw(I,'OUT') Then Begin IsOut:=True; Inc(I); End;
          End Else If IsKw(I,'OUT') Then Begin IsOut:=True; Inc(I); End
          Else If IsKw(I,'ACCESS') Then Begin IsOut:=True; Inc(I); End;
          { Inscrire les params }
          For K:=1 to GroupNames do Begin
            Inc(Sig.ParamCount);
            If Sig.ParamCount<=16 Then Sig.OutFlags[Sig.ParamCount]:=IsOut;
          End;
          { Avancer jusqu'au prochain `;` au niveau 1, ou au `)` final }
          While (Depth>0) and (TKind(I)<>TK_EOF) do Begin
            If IsPunct(I,'(') Then Inc(Depth)
            Else If IsPunct(I,')') Then Begin
              Dec(Depth);
              If Depth=0 Then Begin Inc(I); Break; End;
            End
            Else If (Depth=1) and IsPunct(I,';') Then Begin Inc(I); Break; End;
            Inc(I);
          End;
        End;
      End;
      { Enregistrer la signature (ecrase si meme nom existe) }
      J:=FindFuncSig(Sig.Name);
      If J=0 Then Begin
        If FuncSigCount<128 Then Begin
          Inc(FuncSigCount);
          FuncSigs[FuncSigCount]:=Sig;
        End;
      End Else
        FuncSigs[J]:=Sig;
    End Else
      Inc(I);
  End;
End;

Procedure EmitLabelsDecl;
Begin
  { En Rust, les labels sont definis a l'usage avec 'label: loop. }
End;

Procedure EmitForVarsDecl;
Begin
  { Rust : les variables de boucle FOR sont declarees implicitement
    dans `for x in ...`, rien a faire ici. }
End;

{ ============================================================
  PROGRAMME PRINCIPAL DU TRANSPILEUR
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('ADA2RUST ',ADA2RUST_VERSION,' - Transpilateur Ada vers Rust');
  WriteLn;
  WriteLn('Syntaxe : ADA2RUST [-v] source.adb [destination.rs]');
  WriteLn;
  WriteLn('  source.adb      Fichier source Ada (corps de procedure).');
  WriteLn('  destination.rs  Fichier Rust a generer (defaut : source.rs).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : ADA2RUST hello.adb hello.rs');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.rs'
                          Else DstName:=A+'.rs';
  End;
End;

Procedure OpenFiles;
Begin
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('ADA2RUST : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    Close(SrcFile);
    WriteLn('ADA2RUST : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;
End;

Procedure EmitHelpers;
Begin
  WriteLn(DstFile,'// Genere par ADA2RUST ',ADA2RUST_VERSION);
  WriteLn(DstFile,'#![allow(non_snake_case)]');
  WriteLn(DstFile,'#![allow(non_camel_case_types)]');
  WriteLn(DstFile,'#![allow(non_upper_case_globals)]');
  WriteLn(DstFile,'#![allow(unused_variables)]');
  WriteLn(DstFile,'#![allow(unused_mut)]');
  WriteLn(DstFile,'#![allow(unused_assignments)]');
  WriteLn(DstFile,'#![allow(dead_code)]');
  WriteLn(DstFile);
  If HasPower Then Begin
    WriteLn(DstFile,'fn power_(b: f64, e: i32) -> f64 {');
    WriteLn(DstFile,'    let mut r = 1.0_f64;');
    WriteLn(DstFile,'    let mut e = e;');
    WriteLn(DstFile,'    while e > 0 { r *= b; e -= 1; }');
    WriteLn(DstFile,'    r');
    WriteLn(DstFile,'}');
    WriteLn(DstFile);
  End;
End;

Var
  IPos : Integer;

BEGIN
  ErrorCount:=0;
  HasPower:=False;
  UsesOut:=False;
  UsesIO:=False;
  CurSection:=' ';
  Indent:=0;
  FuncSP:=0;
  InitNameList(UsesList);
  InitNameList(ArrayTypes);
  InitNameList(ArrayVars);
  InitNameList(Labels);
  InitNameList(ForVars);
  InitNameList(DeclaredVars);
  InitNameList(OutParams);

  ParseArgs;
  If Verbose Then WriteLn('ADA2RUST : tokenisation de ',SrcName,'...');

  OpenFiles;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('ADA2RUST : ',TokCount,' tokens lus.');

  ScanForVars;
  ScanDeclareVars;
  ScanLabels;
  ScanIO;
  ScanPower;
  ScanFuncSigs;

  CollectUsesAndProgName(IPos);
  If Verbose Then WriteLn('ADA2RUST : programme = ',ProgName);

  EmitHelpers;
  EmitLabelsDecl;

  { En Rust, on ne peut pas avoir de `let mut` au scope global,
    et les fonctions imbriquees dans `fn main()` sont valides.
    On emet donc TOUTES les declarations Ada (CONST/TYPE/VAR/PROC)
    dans `fn main()`. }
  WriteLn(DstFile,'fn main() {');
  Indent:=4;
  EmitDecls(IPos);
  CurSection:=' ';

  EmitForVarsDecl;
  CurSection:=' ';
  If IsKw(IPos,'BEGIN') Then Inc(IPos);
  EmitStmtBlock(IPos,'END');
  Indent:=0;
  WriteLn(DstFile,'}');

  Close(DstFile);
  If Verbose Then WriteLn('ADA2RUST : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
