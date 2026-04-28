{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Rust vers Ada (.adb)
}

(* ============================================================
   RUST2ADA.PAS - Transpilateur Rust vers Ada
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Ada 95+ (.adb)

   Couvre les constructions courantes de Rust :
     fn, let / let mut, const, static, struct, enum simple,
     if / else if / else, while, loop, for x in a..b / a..=b
     (avec .rev() -> reverse), match (avec _ -> when others, |
     pour les alternatives), return, break, continue (-> goto
     interne), use ::path,
     macros println!/print!/eprintln! -> Put_Line/Put/New_Line,
     types primitifs (i8..i64, u8..u64, isize, usize, f32, f64,
     bool, char, &str, String) mappes vers Integer/Long_Integer/
     Natural/Float/Long_Float/Boolean/Character/String,
     operateurs Rust vers Ada (== =, != /=, && and then, ||
     or else, ! not, % mod).

   Limitations connues (signalees en commentaires Ada dans la
   sortie quand applicable) :
     - les variants enum avec donnees ne sont pas traduits, ils
       sont approximes en commentaire ;
     - les traits, impl, generiques, closures, lifetimes, lifetimes
       explicites, async, unsafe ne sont pas supportes ;
     - le type est infere pour `let x = expr;` a partir du litteral
       initial uniquement (sinon commentaire indicatif) ;
     - les macros autres que println!/print!/eprintln!/eprint! sont
       conservees comme appel d'une fonction homonyme.
   ============================================================ *)

Program RUST2ADA;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  RUST2ADA_VERSION = '1.0';
  RUST2ADA_DATE    = '2026-04-28';

  MAX_STR     = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_TOKEN   = {$IFDEF FPC}48000{$ELSE}4000{$ENDIF};
  MAX_PROC    = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_USES    = 32;
  MAX_PARAMS  = 16;

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
    TK_INTEGER,    { 42  0xFF  0b10  0o77  + suffixe i32     }
    TK_REAL,       { 3.14  1.0e2  + suffixe f64              }
    TK_STRING,     { "hello"  r"raw"  r#"raw#"#              }
    TK_CHAR,       { 'a' '\n' '\u{1F600}'                    }
    TK_IDENT,      { identificateur ordinaire                }
    TK_KEYWORD,    { mot-cle Rust                            }
    TK_OP,         { = == != + - * / % < > <= >= && || ! &   }
                   { | ^ << >> += -= ..   ..=  =>  -> ::     }
    TK_PUNCT       { ; , ( ) [ ] { } : .                     }
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;
    Line   : Integer;
    Col    : Integer;
  End;

  TFuncRec = Record
    Name      : TString;     { nom de la fonction Rust              }
    RetType   : TString;     { type de retour Ada (vide -> proc)    }
    IsFunc    : Boolean;     { true si fonction (-> R)              }
    NParam    : Integer;
    POut      : Array[1..MAX_PARAMS] of Boolean; { &mut             }
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

  ProgName         : TString;       { nom du fichier source            }

  Funcs            : Array[1..MAX_PROC] of TFuncRec;
  FuncCount        : Integer;

  UsesTextIO       : Boolean;       { faut-il with Ada.Text_IO         }

  CurFunc          : Integer;
  FuncStack        : Array[1..32] of Integer;
  FuncSP           : Integer;

  ErrorCount       : Integer;

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

Function StrEqual(A,B:TString):Boolean;
Begin
  StrEqual:=A=B;
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

{ Capitalise la premiere lettre, garde le reste tel quel.
  Utile pour produire des identificateurs Ada en CamelCase doux
  a partir de noms Rust en snake_case (Compteur -> Compteur). }
Function PascalCase(S:TString):TString;
Var
  R:TString;
  I:Integer;
  UpNext:Boolean;
Begin
  R:='';
  UpNext:=True;
  For I:=1 to Length(S) do Begin
    If S[I]='_' Then Begin
      UpNext:=True;
    End Else Begin
      If UpNext and (S[I] in ['a'..'z']) Then
        R:=R+Chr(Ord(S[I])-32)
      Else
        R:=R+S[I];
      UpNext:=False;
    End;
  End;
  If R='' Then R:=S;
  PascalCase:=R;
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

Procedure AddToken(K:TTokenKind; V:TString);
Begin
  If TokCount>=MAX_TOKEN Then Begin
    WriteLn('RUST2ADA : trop de tokens (>',MAX_TOKEN,')');
    Halt(EXIT_ERROR);
  End;
  Inc(TokCount);
  Tokens[TokCount].Kind:=K;
  Tokens[TokCount].Val :=V;
  Tokens[TokCount].Line:=SrcLineNo;
  Tokens[TokCount].Col :=SrcCol;
End;

Function IsRustKeyword(S:TString):Boolean;
Begin
  IsRustKeyword:=
    (S='as')or(S='async')or(S='await')or(S='break')or(S='const')or
    (S='continue')or(S='crate')or(S='dyn')or(S='else')or(S='enum')or
    (S='extern')or(S='false')or(S='fn')or(S='for')or(S='if')or
    (S='impl')or(S='in')or(S='let')or(S='loop')or(S='match')or
    (S='mod')or(S='move')or(S='mut')or(S='pub')or(S='ref')or
    (S='return')or(S='self')or(S='Self')or(S='static')or(S='struct')or
    (S='super')or(S='trait')or(S='true')or(S='type')or(S='unsafe')or
    (S='use')or(S='where')or(S='while')or(S='yield');
End;

{ Saute un commentaire ligne // jusqu'a fin de ligne. }
Procedure SkipLineComment;
Var Ch:Char;
Begin
  Repeat
    Ch:=NextCh;
  Until (Ch=#10)or(Ch=#0);
End;

{ Saute un commentaire bloc /* ... */ avec imbrication Rust. }
Procedure SkipBlockComment;
Var
  Ch,Prev:Char;
  Depth:Integer;
Begin
  Depth:=1;
  Prev:=#0;
  While Depth>0 do Begin
    Ch:=NextCh;
    If Ch=#0 Then Exit;
    If (Prev='/')and(Ch='*') Then Begin
      Inc(Depth);
      Ch:=#0;
    End Else
    If (Prev='*')and(Ch='/') Then Begin
      Dec(Depth);
      Ch:=#0;
    End;
    Prev:=Ch;
  End;
End;

{ Lit une chaine "..." avec sequences d'echappement. La forme
  litterale source est conservee (incluant les guillemets). }
Procedure ScanString;
Var
  S:TString;
  Ch:Char;
Begin
  S:='"';
  Repeat
    Ch:=NextCh;
    If (Ch=#0) Then Begin
      WriteLn('RUST2ADA : chaine non terminee ligne ',SrcLineNo);
      Inc(ErrorCount);
      Break;
    End;
    If Ch='"' Then Begin
      S:=S+Ch;
      Break;
    End;
    If Ch='\' Then Begin
      S:=S+Ch;
      Ch:=NextCh;
      If Ch=#0 Then Break;
      S:=S+Ch;
    End Else
      S:=S+Ch;
  Until False;
  AddToken(TK_STRING,S);
End;

{ Lit une raw string r"..." ou r#"..."# (jusqu'a 3 #). }
Procedure ScanRawString;
Var
  S:TString;
  Ch:Char;
  N,K:Integer;
Begin
  S:='r';
  N:=0;
  Ch:=PeekCh;
  While Ch='#' do Begin
    S:=S+NextCh;
    Inc(N);
    Ch:=PeekCh;
  End;
  If PeekCh<>'"' Then Begin
    AddToken(TK_IDENT,'r');
    Exit;
  End;
  S:=S+NextCh; { '"' }
  Repeat
    Ch:=NextCh;
    If Ch=#0 Then Break;
    If Ch='"' Then Begin
      K:=0;
      While (K<N)and(PeekCh='#') do Begin
        S:=S+'"';
        S:=S+NextCh;
        Inc(K);
        If K=N Then Break;
      End;
      If K=N Then Begin
        S:=S+'"'; { ferme }
        { ajouter les # supplementaires deja consommes ? deja ajoutes }
        Break;
      End;
      S:=S+Ch;
    End Else
      S:=S+Ch;
  Until False;
  AddToken(TK_STRING,S);
End;

{ Lit un litteral char 'x' ou '\n' ou '\u{...}' }
Procedure ScanCharLit;
Var
  S:TString;
  Ch:Char;
Begin
  S:='''';
  Ch:=NextCh;
  If Ch=#0 Then Exit;
  S:=S+Ch;
  If Ch='\' Then Begin
    Ch:=NextCh;
    If Ch=#0 Then Exit;
    S:=S+Ch;
    If Ch='u' Then Begin
      If PeekCh='{' Then Begin
        S:=S+NextCh;
        Repeat
          Ch:=NextCh;
          If Ch=#0 Then Exit;
          S:=S+Ch;
        Until Ch='}';
      End;
    End Else
    If Ch='x' Then Begin
      S:=S+NextCh;
      S:=S+NextCh;
    End;
  End;
  Ch:=NextCh; { quote fermant }
  If Ch='''' Then S:=S+Ch
  Else Begin
    UngetCh(Ch);
    Inc(ErrorCount);
  End;
  AddToken(TK_CHAR,S);
End;

Function IsHexDigit(C:Char):Boolean;
Begin
  IsHexDigit:=C in ['0'..'9','A'..'F','a'..'f'];
End;

Procedure ScanNumber(First:Char);
Var
  S:TString;
  Ch:Char;
  IsReal:Boolean;
Begin
  S:=First;
  IsReal:=False;
  Ch:=PeekCh;
  { 0x / 0b / 0o }
  If (First='0')and((Ch='x')or(Ch='X')) Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    While IsHexDigit(Ch) or (Ch='_') do Begin
      S:=S+NextCh; Ch:=PeekCh;
    End;
    AddToken(TK_INTEGER,S);
    { suffixe optionnel u/i/f }
    If Ch in ['u','i'] Then Begin
      While PeekCh in ['a'..'z','A'..'Z','0'..'9'] do
        Tokens[TokCount].Val:=Tokens[TokCount].Val+NextCh;
    End;
    Exit;
  End;
  If (First='0')and((Ch='b')or(Ch='o')) Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    While (Ch in ['0'..'9','_']) do Begin
      S:=S+NextCh; Ch:=PeekCh;
    End;
    AddToken(TK_INTEGER,S);
    Exit;
  End;
  { decimaux + separateurs _ }
  While (Ch in ['0'..'9','_']) do Begin
    S:=S+NextCh;
    Ch:=PeekCh;
  End;
  If Ch='.' Then Begin
    { attention a Rust : a..b et a..=b ne sont pas des reels }
    Ch:=NextCh; { consume '.' }
    If (PeekCh='.')or(PeekCh='=') Then Begin
      { remettre le '.' au flot }
      UngetCh('.');
      AddToken(TK_INTEGER,S);
      Exit;
    End;
    { sinon c'est bien un reel }
    S:=S+'.';
    Ch:=PeekCh;
    While Ch in ['0'..'9','_'] do Begin
      S:=S+NextCh; Ch:=PeekCh;
    End;
    IsReal:=True;
  End;
  If (Ch='e')or(Ch='E') Then Begin
    IsReal:=True;
    S:=S+NextCh;
    Ch:=PeekCh;
    If (Ch='+')or(Ch='-') Then Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
    While Ch in ['0'..'9','_'] do Begin
      S:=S+NextCh; Ch:=PeekCh;
    End;
  End;
  { suffixe i32/u8/f64/usize/isize/etc - ignore (consomme) }
  Ch:=PeekCh;
  If Ch in ['i','u','f'] Then Begin
    S:=S+NextCh;
    Ch:=PeekCh;
    While Ch in ['a'..'z','A'..'Z','0'..'9'] do Begin
      S:=S+NextCh;
      Ch:=PeekCh;
    End;
    If S[Length(S)-2]='f' Then IsReal:=True;
    If (Length(S)>=3) and ((Copy(S,Length(S)-2,3)='f32')or(Copy(S,Length(S)-2,3)='f64')) Then IsReal:=True;
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
  { 'r' suivi de '#' ou '"' indique une raw string lue - traite avant }
  If IsRustKeyword(S) Then AddToken(TK_KEYWORD,S)
                      Else AddToken(TK_IDENT,S);
End;

Procedure Tokenize;
Var
  Ch,Ch2,Ch3:Char;
  S:TString;
Begin
  TokCount:=0;
  TokInit;
  Repeat
    Ch:=NextCh;
    If Ch=#0 Then Break;
    Case Ch of
      ' ',#9,#10,#13: ;
      '/':Begin
        Ch2:=PeekCh;
        If Ch2='/' Then Begin
          NextCh;
          SkipLineComment;
        End Else
        If Ch2='*' Then Begin
          NextCh;
          SkipBlockComment;
        End Else
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'/='); End { /= Rust assignment, will be remapped }
                   Else AddToken(TK_OP,'/');
      End;
      '"':ScanString;
      'r':Begin
        Ch2:=PeekCh;
        If (Ch2='"')or(Ch2='#') Then ScanRawString
        Else ScanIdent('r');
      End;
      'b':Begin
        Ch2:=PeekCh;
        If Ch2='"' Then Begin
          NextCh;
          ScanString; { reuse, byte string approxime en string }
        End Else
        If Ch2='''' Then Begin
          NextCh;
          ScanCharLit;
        End Else
          ScanIdent('b');
      End;
      '''':ScanCharLit;
      '0'..'9':ScanNumber(Ch);
      'A'..'Z','a'..'z','_':ScanIdent(Ch);
      ':':Begin
        Ch2:=PeekCh;
        If Ch2=':' Then Begin NextCh; AddToken(TK_OP,'::'); End
                   Else AddToken(TK_PUNCT,':');
      End;
      '<':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'<='); End Else
        If Ch2='<' Then Begin
          NextCh;
          If PeekCh='=' Then Begin NextCh; AddToken(TK_OP,'<<='); End
                        Else AddToken(TK_OP,'<<');
        End Else AddToken(TK_OP,'<');
      End;
      '>':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'>='); End Else
        If Ch2='>' Then Begin
          NextCh;
          If PeekCh='=' Then Begin NextCh; AddToken(TK_OP,'>>='); End
                        Else AddToken(TK_OP,'>>');
        End Else AddToken(TK_OP,'>');
      End;
      '=':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'=='); End Else
        If Ch2='>' Then Begin NextCh; AddToken(TK_OP,'=>'); End
                   Else AddToken(TK_OP,'=');
      End;
      '!':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'!='); End
                   Else AddToken(TK_OP,'!');
      End;
      '&':Begin
        Ch2:=PeekCh;
        If Ch2='&' Then Begin NextCh; AddToken(TK_OP,'&&'); End Else
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'&='); End
                   Else AddToken(TK_OP,'&');
      End;
      '|':Begin
        Ch2:=PeekCh;
        If Ch2='|' Then Begin NextCh; AddToken(TK_OP,'||'); End Else
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'|='); End
                   Else AddToken(TK_OP,'|');
      End;
      '+':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'+='); End
                   Else AddToken(TK_OP,'+');
      End;
      '-':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'-='); End Else
        If Ch2='>' Then Begin NextCh; AddToken(TK_OP,'->'); End
                   Else AddToken(TK_OP,'-');
      End;
      '*':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'*='); End
                   Else AddToken(TK_OP,'*');
      End;
      '%':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'%='); End
                   Else AddToken(TK_OP,'%');
      End;
      '^':Begin
        Ch2:=PeekCh;
        If Ch2='=' Then Begin NextCh; AddToken(TK_OP,'^='); End
                   Else AddToken(TK_OP,'^');
      End;
      '.':Begin
        Ch2:=PeekCh;
        If Ch2='.' Then Begin
          NextCh;
          Ch3:=PeekCh;
          If Ch3='=' Then Begin NextCh; AddToken(TK_OP,'..='); End
                     Else AddToken(TK_OP,'..');
        End Else
          AddToken(TK_PUNCT,'.');
      End;
      '(':AddToken(TK_PUNCT,'(');
      ')':AddToken(TK_PUNCT,')');
      '[':AddToken(TK_PUNCT,'[');
      ']':AddToken(TK_PUNCT,']');
      '{':AddToken(TK_PUNCT,'{');
      '}':AddToken(TK_PUNCT,'}');
      ';':AddToken(TK_PUNCT,';');
      ',':AddToken(TK_PUNCT,',');
      '#':AddToken(TK_PUNCT,'#'); { attribut #[...] - on consomme entier ensuite }
      '?':AddToken(TK_OP,'?');
      '@':AddToken(TK_OP,'@');
    End;
  Until SrcEOF and (Not HasPending);
  AddToken(TK_EOF,'');
End;

{ ============================================================
  ANALYSEUR
  ============================================================ }
Function MapRustType(T:TString):TString;
Begin
  If (T='i8')or(T='i16')or(T='i32')or(T='isize') Then MapRustType:='Integer' Else
  If (T='i64') Then MapRustType:='Long_Integer' Else
  If (T='u8')or(T='u16')or(T='u32')or(T='usize') Then MapRustType:='Natural' Else
  If (T='u64') Then MapRustType:='Long_Integer' Else
  If T='f32' Then MapRustType:='Float' Else
  If T='f64' Then MapRustType:='Long_Float' Else
  If T='bool' Then MapRustType:='Boolean' Else
  If T='char' Then MapRustType:='Character' Else
  If (T='str')or(T='String') Then MapRustType:='String' Else
    MapRustType:=PascalCase(T);
End;

Procedure RegisterFunc(Name,RetType:TString; IsFunc:Boolean);
Begin
  If FuncCount>=MAX_PROC Then Exit;
  Inc(FuncCount);
  Funcs[FuncCount].Name   :=Name;
  Funcs[FuncCount].RetType:=RetType;
  Funcs[FuncCount].IsFunc :=IsFunc;
  Funcs[FuncCount].NParam :=0;
End;

Function FindFunc(Name:TString):Integer;
Var I:Integer;
Begin
  For I:=1 to FuncCount do
    If Funcs[I].Name=Name Then Begin
      FindFunc:=I;
      Exit;
    End;
  FindFunc:=0;
End;

{ Saute les attributs #[...] et la visibilite pub. Avance I. }
Procedure SkipAttribute(Var I:Integer);
Var Depth:Integer;
Begin
  While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='#') do Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Begin
      Depth:=1; Inc(I);
      While (I<=TokCount)and(Depth>0) do Begin
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='[') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=']') Then Dec(Depth);
        Inc(I);
      End;
    End;
  End;
End;

{ Pre-analyse pour collecter les fonctions et leurs parametres }
Procedure Analyze;
Var
  I,J,Depth,PIdx:Integer;
  Name,Ret:TString;
  IsFunc,SeenMut:Boolean;
Begin
  ProgName:='Main';
  FuncCount:=0;
  UsesTextIO:=False;
  I:=1;
  While I<=TokCount do Begin
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        Name:=Tokens[I].Val;
        Inc(I);
        { sauter generiques <...> }
        If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='<') Then Begin
          Depth:=1; Inc(I);
          While (I<=TokCount)and(Depth>0) do Begin
            If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='<') Then Inc(Depth) Else
            If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='>') Then Dec(Depth);
            Inc(I);
          End;
        End;
        IsFunc:=False; Ret:='';
        PIdx:=0;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
          Inc(I); Depth:=1;
          { lire chaque parametre : nom : [&mut] type }
          SeenMut:=False;
          While (I<=TokCount)and(Depth>0) do Begin
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
              Dec(Depth);
              If Depth=0 Then Begin Inc(I); Break; End;
            End Else
            If (Depth=1)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Begin
              { nouveau parametre : enregistrer le precedent }
              Inc(PIdx);
              If PIdx<=MAX_PARAMS Then
                Funcs[FuncCount+1].POut[PIdx]:=SeenMut;
              SeenMut:=False;
            End Else
            If (Depth=1)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='&') Then Begin
              { peut etre suivi de mut }
              If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_KEYWORD)and(Tokens[I+1].Val='mut') Then
                SeenMut:=True;
            End;
            Inc(I);
          End;
          { dernier parametre }
          If PIdx>=0 Then Begin
            { Compter combien de virgules au niveau 1 -> nb param-1 }
            { Plus simple : fixer NParam = PIdx+1 si on a vu du contenu, sinon 0 }
            { Heuristique : si SeenMut ou la liste est non vide on incremente }
            Inc(PIdx);
            If PIdx<=MAX_PARAMS Then
              Funcs[FuncCount+1].POut[PIdx]:=SeenMut;
          End;
        End;
        { type de retour }
        If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='->') Then Begin
          Inc(I);
          IsFunc:=True;
          Ret:='';
          { lire jusqu'a '{' ou where }
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) and
                Not((Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='where')) do Begin
            If Tokens[I].Kind=TK_IDENT Then Ret:=Ret+MapRustType(Tokens[I].Val) Else
            If Tokens[I].Kind=TK_KEYWORD Then Ret:=Ret+Tokens[I].Val Else
              Ret:=Ret+Tokens[I].Val;
            Inc(I);
          End;
          If Ret='' Then Ret:='Integer';
        End;
        RegisterFunc(Name,Ret,IsFunc);
        Funcs[FuncCount].NParam:=PIdx;
      End;
    End Else
    If (Tokens[I].Kind=TK_IDENT) Then Begin
      If (Tokens[I].Val='println')or(Tokens[I].Val='print')or
         (Tokens[I].Val='eprintln')or(Tokens[I].Val='eprint') Then
        UsesTextIO:=True;
      Inc(I);
    End Else
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
        For OutCol:=1 to Indent*3 do OutLine:=OutLine+' ';
        OutCol:=Indent*3;
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

{ Conversion d'une chaine Rust "abc\n" en chaine Ada "abc" & ASCII.LF.
  Approximation : on remplace \n par "" & ASCII.LF & "" en concatenation. }
Function RustStringToAda(S:TString):TString;
Var
  I:Integer;
  R,Acc:TString;
  InAcc:Boolean;
Begin
  R:='';
  Acc:='';
  InAcc:=True;
  I:=2; { sauter " }
  While I<Length(S) do Begin
    If (S[I]='\') and (I<Length(S)-1) Then Begin
      Case S[I+1] of
        'n':Begin
          If Acc='' Then R:=R+'""'
          Else R:=R+'"'+Acc+'"';
          R:=R+' & ASCII.LF & ';
          Acc:='';
        End;
        't':Begin
          If Acc='' Then R:=R+'""'
          Else R:=R+'"'+Acc+'"';
          R:=R+' & ASCII.HT & ';
          Acc:='';
        End;
        'r':Begin
          If Acc='' Then R:=R+'""'
          Else R:=R+'"'+Acc+'"';
          R:=R+' & ASCII.CR & ';
          Acc:='';
        End;
        '\':Acc:=Acc+'\';
        '"':Acc:=Acc+'""';
        '0':Begin
          If Acc='' Then R:=R+'""'
          Else R:=R+'"'+Acc+'"';
          R:=R+' & ASCII.NUL & ';
          Acc:='';
        End;
      Else
        Acc:=Acc+S[I+1];
      End;
      Inc(I,2);
    End Else
    If S[I]='"' Then Begin
      Acc:=Acc+'""';
      Inc(I);
    End Else Begin
      Acc:=Acc+S[I];
      Inc(I);
    End;
  End;
  If Acc<>'' Then R:=R+'"'+Acc+'"'
  Else If R='' Then R:='""'
  Else Begin
    { retirer le trailing & si present }
    While (Length(R)>0) and (R[Length(R)]=' ') do R:=Copy(R,1,Length(R)-1);
    If (Length(R)>0) and (R[Length(R)]='&') Then
      R:=Copy(R,1,Length(R)-1);
  End;
  RustStringToAda:=R;
End;

Function RustCharToAda(S:TString):TString;
Var
  Body:TString;
  V:LongInt;
  Code:Integer;
Begin
  { S = 'x' or '\n' ... }
  Body:=Copy(S,2,Length(S)-2);
  If (Length(Body)=2) and (Body[1]='\') Then Begin
    Case Body[2] of
      'n':RustCharToAda:='ASCII.LF';
      't':RustCharToAda:='ASCII.HT';
      'r':RustCharToAda:='ASCII.CR';
      '0':RustCharToAda:='ASCII.NUL';
      '\':RustCharToAda:='''\''';
      '''':RustCharToAda:='Character''Val(39)';
      '"':RustCharToAda:='''"''';
    Else
      RustCharToAda:=''''+Body[2]+'''';
    End;
    Exit;
  End;
  If Length(Body)=1 Then Begin
    RustCharToAda:=''''+Body+'''';
    Exit;
  End;
  RustCharToAda:='''?'' (* '+S+' *)';
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op='==' Then MapOperator:='=' Else
  If Op='!=' Then MapOperator:='/=' Else
  If Op='&&' Then MapOperator:=' and then ' Else
  If Op='||' Then MapOperator:=' or else ' Else
  If Op='%'  Then MapOperator:=' mod ' Else
  If Op='<<' Then MapOperator:=' * 2** ' Else
  If Op='>>' Then MapOperator:=' / 2** ' Else
  If Op='!'  Then MapOperator:='not ' Else
  If Op='::' Then MapOperator:='.' Else
  If Op='->' Then MapOperator:='->' Else
  If Op='=>' Then MapOperator:='=>' Else
                  MapOperator:=Op;
End;

{ Forward declarations }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitBlock(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitFnHeaderAndBody(Var I:Integer; AsNested:Boolean); Forward;

{ Emet une expression jusqu'a un separateur de niveau 0 (; , ) ] } => ).
  Convertit operateurs, identificateurs (PascalCase pour appels de
  fonction reconnus), litteraux. Ne descend pas dans les blocs. }
Procedure EmitExpr(Var I:Integer);
Var
  Depth,BrDepth,BrcDepth:Integer;
  K:TString;
  Stop:Boolean;
Begin
  Depth:=0; BrDepth:=0; BrcDepth:=0;
  While I<=TokCount do Begin
    Stop:=False;
    If (Depth=0)and(BrDepth=0)and(BrcDepth=0) Then Begin
      If Tokens[I].Kind=TK_PUNCT Then Begin
        If (Tokens[I].Val=';')or(Tokens[I].Val=',')or
           (Tokens[I].Val=')')or(Tokens[I].Val=']')or
           (Tokens[I].Val='}')or(Tokens[I].Val='{') Then Stop:=True;
      End Else
      If Tokens[I].Kind=TK_OP Then Begin
        If Tokens[I].Val='=>' Then Stop:=True;
      End Else
      If Tokens[I].Kind=TK_KEYWORD Then Begin
        K:=Tokens[I].Val;
        If (K='else') Then Stop:=True;
      End;
    End;
    If Stop Then Break;
    Case Tokens[I].Kind of
      TK_OP:Begin
        K:=Tokens[I].Val;
        If K='&' Then Begin
          { reference : ignorer en Ada (simplification) }
        End Else
        If (K='..') or (K='..=') Then EmitRaw('..') Else
          EmitRaw(MapOperator(K));
      End;
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='true' Then EmitRaw('True') Else
        If K='false' Then EmitRaw('False') Else
        If K='self' Then EmitRaw('Self') Else
        If K='Self' Then EmitRaw('Self') Else
        If K='mut' Then { ignorer dans expression } Else
        If K='ref' Then { ignorer } Else
        If K='as' Then EmitRaw('-- as ') Else
          EmitRaw(K);
      End;
      TK_IDENT:Begin
        EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        K:=Tokens[I].Val;
        { 0xFF -> 16#FF# en Ada }
        If (Length(K)>=3) and (K[1]='0') and ((K[2]='x')or(K[2]='X')) Then
          EmitRaw('16#'+Copy(K,3,Length(K)-2)+'#')
        Else
        If (Length(K)>=3) and (K[1]='0') and (K[2]='b') Then
          EmitRaw('2#'+Copy(K,3,Length(K)-2)+'#')
        Else
        If (Length(K)>=3) and (K[1]='0') and (K[2]='o') Then
          EmitRaw('8#'+Copy(K,3,Length(K)-2)+'#')
        Else
          EmitRaw(K);
      End;
      TK_REAL:EmitRaw(Tokens[I].Val);
      TK_STRING:EmitRaw(RustStringToAda(Tokens[I].Val));
      TK_CHAR:EmitRaw(RustCharToAda(Tokens[I].Val));
      TK_PUNCT:Begin
        K:=Tokens[I].Val;
        If K='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If K=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If K='[' Then Begin Inc(BrDepth); EmitRaw('('); End Else
        If K=']' Then Begin Dec(BrDepth); EmitRaw(')'); End Else
        If K='{' Then Begin Inc(BrcDepth); EmitRaw('('); End Else
        If K='}' Then Begin Dec(BrcDepth); EmitRaw(')'); End Else
        If K='.' Then EmitRaw('.') Else
        If K=',' Then EmitRaw(', ') Else
        If K=':' Then EmitRaw(':') Else
        If K=';' Then EmitRaw(';') Else
        If K='#' Then { skip attribut } Else
          EmitRaw(K);
      End;
    End;
    Inc(I);
  End;
End;

{ Emet l'argument format de println!/print!/eprintln!.
  Convertit "fmt", arg1, arg2, ... en "fmt"-with-replacements ou
  concatenation Ada. Pour simplifier : si pas d'arg, emet la
  chaine telle quelle ; si des args, on emet
   <fmt-converti> & Type'Image(arg1) & ...
  ou plus simplement on remplace chaque {} par & X'Image(...) &.
  Implementation simple : on emet les parties brutes en concat. }
Procedure EmitFormatArgs(Var I:Integer);
Var
  Fmt,Cur:TString;
  J,K:Integer;
  ArgIdx:Integer;
  Args:Array[1..16] of String[80];
  ArgCount:Integer;
  Depth,Q:Integer;
  S:TString;
  P:Integer;
Begin
  { I pointe sur '(' apres le ! }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(I);
  { format string }
  Fmt:='';
  If (I<=TokCount)and(Tokens[I].Kind=TK_STRING) Then Begin
    Fmt:=Tokens[I].Val;
    Inc(I);
  End;
  { lire arguments }
  ArgCount:=0;
  While (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') do Begin
    Inc(I);
    Cur:='';
    Depth:=0;
    While I<=TokCount do Begin
      If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=',')or(Tokens[I].Val=')')) Then Break;
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Inc(Depth) Else
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Dec(Depth);
      If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='&') Then
        { skip & }
      Else Begin
        If Length(Cur)>0 Then Cur:=Cur+' ';
        Cur:=Cur+Tokens[I].Val;
      End;
      Inc(I);
    End;
    Inc(ArgCount);
    If ArgCount<=16 Then Args[ArgCount]:=Cur;
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);

  { Si pas d'argument format, emettre la chaine telle quelle }
  If ArgCount=0 Then Begin
    If Fmt='' Then EmitRaw('""')
    Else EmitRaw(RustStringToAda(Fmt));
    Exit;
  End;

  { Decoupage de Fmt sur "{}" : on emet "<segment>" puis chaque arg
    converti via Image, en concatenation Ada. }
  S:=Copy(Fmt,2,Length(Fmt)-2); { sans guillemets }
  ArgIdx:=0;
  Cur:='';
  P:=1;
  EmitRaw('"');
  While P<=Length(S) do Begin
    If (P<Length(S))and(S[P]='{')and(S[P+1]='}') Then Begin
      EmitRaw('" & ');
      Inc(ArgIdx);
      If ArgIdx<=ArgCount Then
        EmitRaw(Args[ArgIdx]+'''Img')
      Else
        EmitRaw('""');
      EmitRaw(' & "');
      Inc(P,2);
    End Else
    If S[P]='\' Then Begin
      If (P<Length(S))and(S[P+1]='n') Then Begin
        EmitRaw('" & ASCII.LF & "');
        Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='t') Then Begin
        EmitRaw('" & ASCII.HT & "');
        Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='"') Then Begin
        EmitRaw('""'); Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='\') Then Begin
        EmitRaw('\'); Inc(P,2);
      End Else Begin
        EmitRaw(S[P]); Inc(P);
      End;
    End Else
    If S[P]='"' Then Begin
      EmitRaw('""'); Inc(P);
    End Else Begin
      EmitRaw(S[P]); Inc(P);
    End;
  End;
  EmitRaw('"');
End;

{ Emet un appel d'identificateur (potentiellement un appel
  de fonction). I pointe sur l'ident. }
Procedure EmitCallOrAssign(Var I:Integer);
Var
  Name:TString;
  IsLn:Boolean;
Begin
  Name:=Tokens[I].Val;
  { Macros : ident! ( ... ) }
  If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_OP)and(Tokens[I+1].Val='!') Then Begin
    Inc(I,2);
    If (Name='println')or(Name='eprintln') Then Begin
      IsLn:=True;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
        { verifier si vide : "()" -> juste New_Line }
        If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val=')') Then Begin
          EmitRaw('New_Line');
          Inc(I,2);
          Exit;
        End;
      End;
      EmitRaw('Put_Line (');
      EmitFormatArgs(I);
      EmitRaw(')');
      Exit;
    End Else
    If (Name='print')or(Name='eprint') Then Begin
      EmitRaw('Put (');
      EmitFormatArgs(I);
      EmitRaw(')');
      Exit;
    End Else Begin
      { autre macro : conserver comme appel }
      EmitRaw(Name+' (* macro *) (');
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
        Inc(I);
        EmitExpr(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
      End;
      EmitRaw(')');
      Exit;
    End;
  End;
  { sinon : expression normale (appel ou assignement) }
  EmitExpr(I);
End;

{ Saute un type Rust dans une declaration : type de base, generiques,
  references. Avance I jusqu'au prochain ',' / ';' / '=' / ')' / '{'
  au niveau 0. Emet le type Ada equivalent. }
Procedure EmitType(Var I:Integer);
Var
  Depth:Integer;
  K:TString;
  First:Boolean;
Begin
  Depth:=0;
  First:=True;
  While I<=TokCount do Begin
    If Depth=0 Then Begin
      If (Tokens[I].Kind=TK_PUNCT)and
         ((Tokens[I].Val=',')or(Tokens[I].Val=';')or(Tokens[I].Val=')')or
          (Tokens[I].Val='{')) Then Break;
      If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Break;
    End;
    Case Tokens[I].Kind of
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='mut' Then { ignorer } Else
        If K='dyn' Then { ignorer } Else
          EmitRaw(K);
      End;
      TK_IDENT:Begin
        If First Then Begin EmitRaw(MapRustType(Tokens[I].Val)); First:=False; End
        Else EmitRaw(MapRustType(Tokens[I].Val));
      End;
      TK_OP:Begin
        K:=Tokens[I].Val;
        If K='&' Then { reference : ignorer } Else
        If K='<' Then Begin Inc(Depth); EmitRaw(' (* < *) '); End Else
        If K='>' Then Begin Dec(Depth); EmitRaw(' (* > *) '); End
        Else EmitRaw(K);
      End;
      TK_PUNCT:Begin
        K:=Tokens[I].Val;
        If K='(' Then Begin Inc(Depth); EmitRaw('('); End Else
        If K=')' Then Begin Dec(Depth); EmitRaw(')'); End Else
        If K='[' Then Begin Inc(Depth); EmitRaw(' (* [ *) '); End Else
        If K=']' Then Begin Dec(Depth); EmitRaw(' (* ] *) '); End Else
          EmitRaw(K);
      End;
    Else
      EmitRaw(Tokens[I].Val);
    End;
    Inc(I);
  End;
End;

{ Devine un type Ada a partir du litteral initial d'un let sans
  annotation. }
Function GuessType(I:Integer):TString;
Begin
  If I>TokCount Then Begin GuessType:='Integer'; Exit; End;
  Case Tokens[I].Kind of
    TK_INTEGER:GuessType:='Integer';
    TK_REAL   :GuessType:='Long_Float';
    TK_STRING :GuessType:='String';
    TK_CHAR   :GuessType:='Character';
    TK_KEYWORD:Begin
      If (Tokens[I].Val='true')or(Tokens[I].Val='false') Then GuessType:='Boolean'
      Else GuessType:='Integer';
    End;
  Else
    GuessType:='Integer';
  End;
End;

{ Emet une declaration `let` ou `let mut`.
  let [mut] name [: T] [= expr];
  -> Name : [constant] T := Expr;
  Hypothese : on est dans la partie declarative d'un declare/begin block
  ou on emet le declare a la volee (gere par EmitBlock). Ici on assume
  que la sortie est correcte au sein d'un declare. }
Procedure EmitLet(Var I:Integer);
Var
  IsMut:Boolean;
  Name,T:TString;
  HasType,HasInit:Boolean;
  J:Integer;
Begin
  Inc(I); { sauter let }
  IsMut:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Begin
    IsMut:=True;
    Inc(I);
  End;
  Name:='X';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=PascalCase(Tokens[I].Val);
    Inc(I);
  End;
  T:=''; HasType:=False; HasInit:=False;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
    HasType:=True;
    Inc(I);
    EmitRaw(Name+' : ');
    If Not IsMut Then EmitRaw('constant ');
    EmitType(I);
  End Else Begin
    { type infere }
    J:=I;
    If (J<=TokCount)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val='=') Then Inc(J);
    T:=GuessType(J);
    EmitRaw(Name+' : ');
    If Not IsMut Then EmitRaw('constant ');
    EmitRaw(T);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
    Inc(I);
    HasInit:=True;
    EmitRaw(' := ');
    EmitExpr(I);
  End;
  EmitRaw(';');
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
End;

{ Emet une instruction if .. else if .. else .. en Ada
   if cond then ... elsif cond then ... else ... end if;  }
Procedure EmitIf(Var I:Integer);
Begin
  Inc(I); { if }
  EmitRaw('if ');
  EmitExpr(I);
  EmitRaw(' then');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then
    EmitBlock(I);
  Dec(Indent);
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='else') do Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='if') Then Begin
      Inc(I);
      EmitRaw('elsif ');
      EmitExpr(I);
      EmitRaw(' then');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
      Dec(Indent);
    End Else Begin
      EmitRaw('else');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
      Dec(Indent);
      Break;
    End;
  End;
  EmitRaw('end if;');
  EmitLn;
End;

Procedure EmitWhile(Var I:Integer);
Begin
  Inc(I);
  EmitRaw('while ');
  EmitExpr(I);
  EmitRaw(' loop');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end loop;');
  EmitLn;
End;

Procedure EmitLoop(Var I:Integer);
Begin
  Inc(I);
  EmitRaw('loop');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end loop;');
  EmitLn;
End;

{ for x in a..b { ... } -> for X in A..B-1 loop ... end loop;
  for x in a..=b { ... } -> for X in A..B loop ... end loop;
  for x in (a..b).rev() -> for X in reverse A..B-1 loop }
Procedure EmitFor(Var I:Integer);
Var
  VName:TString;
  Inclusive,Reverse:Boolean;
  Depth:Integer;
  StartTok,DotsTok,EndTok:Integer;
  J:Integer;
Begin
  Inc(I); { for }
  VName:='I';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    VName:=PascalCase(Tokens[I].Val);
    Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='in') Then Inc(I);
  Reverse:=False;
  Inclusive:=False;
  { detecter pattern (a..b).rev() }
  StartTok:=I;
  DotsTok:=0;
  EndTok:=0;
  Depth:=0;
  J:=I;
  While J<=TokCount do Begin
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='{') Then Break;
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
    If (Tokens[J].Kind=TK_OP)and((Tokens[J].Val='..')or(Tokens[J].Val='..=')) Then Begin
      DotsTok:=J;
      If Tokens[J].Val='..=' Then Inclusive:=True;
    End;
    If (Tokens[J].Kind=TK_IDENT)and(Tokens[J].Val='rev') Then Reverse:=True;
    Inc(J);
  End;
  EndTok:=J;
  EmitRaw('for '+VName+' in ');
  If Reverse Then EmitRaw('reverse ');
  If DotsTok>0 Then Begin
    { emettre tokens [StartTok..DotsTok-1] en sautant les '(' initiaux
      jusqu'au token utile }
    J:=StartTok;
    While (J<DotsTok) do Begin
      If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val='(')or(Tokens[J].Val=')')) Then
        { skip }
      Else Begin
        Case Tokens[J].Kind of
          TK_INTEGER,TK_REAL,TK_IDENT,TK_KEYWORD:EmitRaw(Tokens[J].Val);
          TK_OP:EmitRaw(MapOperator(Tokens[J].Val));
        Else
          EmitRaw(Tokens[J].Val);
        End;
      End;
      Inc(J);
    End;
    EmitRaw('..');
    { borne haute : tokens (DotsTok+1) jusqu'au prochain ')' / '.' / '{' }
    J:=DotsTok+1;
    While (J<EndTok) do Begin
      If (Tokens[J].Kind=TK_PUNCT)and((Tokens[J].Val=')')or(Tokens[J].Val='.')) Then Break;
      Case Tokens[J].Kind of
        TK_INTEGER,TK_REAL,TK_IDENT,TK_KEYWORD:EmitRaw(Tokens[J].Val);
        TK_OP:EmitRaw(MapOperator(Tokens[J].Val));
      Else
        EmitRaw(Tokens[J].Val);
      End;
      Inc(J);
    End;
    If Not Inclusive Then EmitRaw(' - 1');
    I:=EndTok;
  End Else Begin
    EmitExpr(I);
  End;
  EmitRaw(' loop');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end loop;');
  EmitLn;
End;

{ match x { p1 => expr1, p2 | p3 => expr2, _ => exprN }
  -> case X is when P1 => Expr1; when P2 | P3 => Expr2; when others => ExprN; end case; }
Procedure EmitMatch(Var I:Integer);
Var
  Depth:Integer;
Begin
  Inc(I); { match }
  EmitRaw('case ');
  EmitExpr(I);
  EmitRaw(' is');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(I);
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Begin
      Inc(I);
      Break;
    End;
    EmitRaw('when ');
    { lire pattern jusqu'a => }
    While (I<=TokCount) do Begin
      If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=>') Then Begin Inc(I); Break; End;
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='_') Then EmitRaw('others') Else
      If (Tokens[I].Kind=TK_IDENT)and(Tokens[I].Val='_') Then EmitRaw('others') Else
      Case Tokens[I].Kind of
        TK_OP:Begin
          If (Tokens[I].Val='|') Then EmitRaw(' | ') Else
          If (Tokens[I].Val='..=') Then EmitRaw('..') Else
          If (Tokens[I].Val='..') Then EmitRaw('..') Else
            EmitRaw(MapOperator(Tokens[I].Val));
        End;
        TK_INTEGER,TK_REAL,TK_IDENT,TK_KEYWORD:EmitRaw(Tokens[I].Val);
        TK_STRING:EmitRaw(RustStringToAda(Tokens[I].Val));
        TK_CHAR  :EmitRaw(RustCharToAda(Tokens[I].Val));
      Else
        EmitRaw(Tokens[I].Val);
      End;
      Inc(I);
    End;
    EmitRaw(' => ');
    { corps de la branche : expression simple ou bloc }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
      EmitLn;
      Inc(Indent);
      EmitBlock(I);
      Dec(Indent);
      EmitRaw('null;');
      EmitLn;
    End Else Begin
      EmitExpr(I);
      EmitRaw(';');
      EmitLn;
    End;
    { virgule separatrice }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
  End;
  Dec(Indent);
  EmitRaw('end case;');
  EmitLn;
End;

{ Determine si un bloc { ... } contient des `let` au niveau 1
  (pour decider declare vs simple begin). }
Function BlockHasLet(Start:Integer):Boolean;
Var
  Depth,J:Integer;
Begin
  BlockHasLet:=False;
  J:=Start; { pointe sur '{' }
  If (J>TokCount)or(Tokens[J].Kind<>TK_PUNCT)or(Tokens[J].Val<>'{') Then Exit;
  Depth:=0;
  Inc(J);
  Depth:=1;
  While (J<=TokCount)and(Depth>0) do Begin
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='{') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='}') Then Dec(Depth) Else
    If (Depth=1)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='let') Then Begin
      BlockHasLet:=True;
      Exit;
    End;
    Inc(J);
  End;
End;

{ Emet une instruction unique (sans le ; final). I avance. }
Procedure EmitStmt(Var I:Integer);
Var K:TString;
Begin
  If I>TokCount Then Exit;
  SkipAttribute(I);
  Case Tokens[I].Kind of
    TK_KEYWORD:Begin
      K:=Tokens[I].Val;
      If K='let' Then Begin
        EmitRaw('-- let in body : voir declare block ci-dessus');
        EmitLn;
        { sauter jusqu'au ; }
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
      End Else
      If K='if' Then EmitIf(I) Else
      If K='while' Then EmitWhile(I) Else
      If K='loop' Then EmitLoop(I) Else
      If K='for' Then EmitFor(I) Else
      If K='match' Then EmitMatch(I) Else
      If K='return' Then Begin
        Inc(I);
        EmitRaw('return');
        If (I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) Then Begin
          EmitRaw(' ');
          EmitExpr(I);
        End;
        EmitRaw(';');
        EmitLn;
      End Else
      If K='break' Then Begin
        Inc(I);
        EmitRaw('exit;');
        EmitLn;
      End Else
      If K='continue' Then Begin
        Inc(I);
        EmitRaw('-- continue : non disponible en Ada (utiliser un goto/etiquette)');
        EmitLn;
      End Else
      If K='pub' Then Begin
        Inc(I);
        EmitStmt(I);
      End Else
      If K='unsafe' Then Begin
        Inc(I);
        EmitRaw('-- unsafe block aplati');
        EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
      End Else Begin
        EmitRaw(K);
        Inc(I);
      End;
    End;
    TK_IDENT:Begin
      EmitCallOrAssign(I);
      EmitRaw(';');
      EmitLn;
    End;
    TK_PUNCT:Begin
      If Tokens[I].Val=';' Then Inc(I)
      Else Inc(I);
    End;
  Else
    EmitExpr(I);
    EmitRaw(';');
    EmitLn;
  End;
End;

{ Emet le contenu d'un bloc { ... }. I pointe sur '{'.
  Si le bloc contient des `let`, on emet un declare avec les declarations
  hoissees, puis begin ... end;. Sinon, juste les statements. }
Procedure EmitBlock(Var I:Integer);
Var
  StartI,Depth,J:Integer;
  HasLet:Boolean;
Begin
  If (I>TokCount)or(Tokens[I].Kind<>TK_PUNCT)or(Tokens[I].Val<>'{') Then Exit;
  StartI:=I;
  HasLet:=BlockHasLet(I);
  Inc(I); { sauter '{' }
  Depth:=1;
  If HasLet Then Begin
    EmitRaw('declare');
    EmitLn;
    Inc(Indent);
    { 1ere passe : emettre tous les let directement au niveau 1 du bloc }
    J:=I;
    While (J<=TokCount)and(Depth>0) do Begin
      If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='{') Then Inc(Depth) Else
      If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='}') Then Dec(Depth);
      If (Depth=1)and(Tokens[J].Kind=TK_KEYWORD)and(Tokens[J].Val='let') Then Begin
        EmitLet(J);
        EmitLn;
      End Else
        Inc(J);
    End;
    Dec(Indent);
    EmitRaw('begin');
    EmitLn;
    Inc(Indent);
  End;
  { 2eme passe : emettre les instructions, en sautant les `let` }
  Depth:=1;
  While (I<=TokCount)and(Depth>0) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
      { sous-bloc }
      EmitBlock(I);
    End Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Begin
      Dec(Depth);
      If Depth=0 Then Begin Inc(I); Break; End;
    End Else
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='let') Then Begin
      { sauter jusqu'au ; }
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End Else
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') Then Begin
      { fn imbriquee : ignorer (deja emise au niveau superieur) }
      Inc(I);
      Depth:=1;
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
        Inc(I); Depth:=1;
        While (I<=TokCount)and(Depth>0) do Begin
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Dec(Depth);
          Inc(I);
        End;
      End;
      Depth:=1; { restaurer pour la boucle parent }
    End Else Begin
      EmitStmt(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
  End;
  If HasLet Then Begin
    Dec(Indent);
    EmitRaw('end;');
    EmitLn;
  End;
End;

{ Emet une fonction Rust complete : header + corps. I pointe sur 'fn'. }
Procedure EmitFnHeaderAndBody(Var I:Integer; AsNested:Boolean);
Var
  Name,RetType,PName,PType:TString;
  IsFunc,IsMut:Boolean;
  Depth,FIdx,PIdx:Integer;
Begin
  Inc(I); { fn }
  If (I>TokCount)or(Tokens[I].Kind<>TK_IDENT) Then Exit;
  Name:=PascalCase(Tokens[I].Val);
  FIdx:=FindFunc(Tokens[I].Val);
  Inc(I);
  { sauter generiques <...> }
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='<') Then Begin
    Depth:=1; Inc(I);
    While (I<=TokCount)and(Depth>0) do Begin
      If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='<') Then Inc(Depth) Else
      If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='>') Then Dec(Depth);
      Inc(I);
    End;
  End;
  IsFunc:=False;
  RetType:='';
  { Determiner si fonction par regard avant }
  Depth:=0;
  PIdx:=I;
  While PIdx<=TokCount do Begin
    If (Tokens[PIdx].Kind=TK_PUNCT)and(Tokens[PIdx].Val='{')and(Depth=0) Then Break;
    If (Tokens[PIdx].Kind=TK_PUNCT)and(Tokens[PIdx].Val='(') Then Inc(Depth) Else
    If (Tokens[PIdx].Kind=TK_PUNCT)and(Tokens[PIdx].Val=')') Then Dec(Depth);
    If (Depth=0)and(Tokens[PIdx].Kind=TK_OP)and(Tokens[PIdx].Val='->') Then IsFunc:=True;
    Inc(PIdx);
  End;
  If IsFunc Then EmitRaw('function ') Else EmitRaw('procedure ');
  EmitRaw(Name);
  { parametres }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
    Inc(I);
    EmitRaw(' (');
    PIdx:=0;
    Depth:=1;
    While (I<=TokCount)and(Depth>0) do Begin
      { lire un parametre : nom : [&] [mut] type }
      If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Begin
        Dec(Depth);
        If Depth=0 Then Begin Inc(I); Break; End;
      End;
      If PIdx>0 Then EmitRaw('; ');
      Inc(PIdx);
      { nom }
      PName:='P'+IntToStr(PIdx);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        PName:=PascalCase(Tokens[I].Val);
        Inc(I);
      End Else
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='self')or(Tokens[I].Val='mut')) Then Begin
        PName:='Self';
        Inc(I);
      End;
      EmitRaw(PName+' : ');
      { ':' }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
      { mode : & = in , &mut = in out , sinon in }
      IsMut:=False;
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='&') Then Begin
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Begin
          IsMut:=True;
          Inc(I);
        End;
      End;
      If IsMut Then EmitRaw('in out ')
      Else EmitRaw('in ');
      { type }
      EmitType(I);
      { virgule }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    EmitRaw(')');
  End;
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='->') Then Begin
      Inc(I);
      EmitRaw(' return ');
      EmitType(I);
    End;
  End;
  EmitRaw(' is');
  EmitLn;
  EmitRaw('begin');
  EmitLn;
  Inc(Indent);
  { corps }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end '+Name+';');
  EmitLn;
  EmitLn;
End;

{ Trouve le token de debut de la fonction main. Retourne 0 si absent. }
Function FindMain:Integer;
Var I:Integer;
Begin
  FindMain:=0;
  I:=1;
  While I<TokCount do Begin
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') and
       (I+1<=TokCount)and(Tokens[I+1].Kind=TK_IDENT)and(Tokens[I+1].Val='main') Then Begin
      FindMain:=I;
      Exit;
    End;
    Inc(I);
  End;
End;

{ Emet la sortie complete : with/use, procedure Main is, sous-programmes,
  begin (corps de main), end Main; }
Procedure EmitProgram;
Var
  I,MainTok:Integer;
  K:TString;
Begin
  EmitRaw('-- Genere par RUST2ADA '+RUST2ADA_VERSION+' a partir de '+SrcName);
  EmitLn;
  If UsesTextIO Then Begin
    EmitRaw('with Ada.Text_IO; use Ada.Text_IO;');
    EmitLn;
  End;
  EmitRaw('with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;');
  EmitLn;
  EmitLn;
  EmitRaw('procedure '+ProgName+' is');
  EmitLn;
  Inc(Indent);
  { Emettre toutes les fonctions sauf main comme sous-programmes Ada
    dans la partie declarative }
  I:=1;
  MainTok:=FindMain;
  While I<=TokCount do Begin
    SkipAttribute(I);
    If I>TokCount Then Break;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='pub') Then Begin
      Inc(I);
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='use') Then Begin
      { skip use ::path; }
      EmitRaw('-- ');
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
        EmitRaw(Tokens[I].Val+' ');
        Inc(I);
      End;
      EmitRaw(';');
      EmitLn;
      If I<=TokCount Then Inc(I);
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='const')or(Tokens[I].Val='static')) Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        EmitRaw(PascalCase(Tokens[I].Val)+' : constant ');
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
        EmitType(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
          Inc(I);
          EmitRaw(' := ');
          EmitExpr(I);
        End;
        EmitRaw(';');
        EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
      End;
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='struct') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        EmitRaw('type '+PascalCase(Tokens[I].Val)+' is record');
        EmitLn;
        Inc(I); Inc(Indent);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
          Inc(I);
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}')) do Begin
            If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='pub') Then Inc(I);
            If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
              EmitRaw(PascalCase(Tokens[I].Val)+' : ');
              Inc(I);
              If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
              EmitType(I);
              EmitRaw(';');
              EmitLn;
              If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
            End Else
              Inc(I);
          End;
          If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Inc(I);
        End;
        Dec(Indent);
        EmitRaw('end record;');
        EmitLn;
      End;
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='enum') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        EmitRaw('type '+PascalCase(Tokens[I].Val)+' is (');
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
          Inc(I);
          K:='';
          While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}')) do Begin
            If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
              If K<>'' Then EmitRaw(', ');
              EmitRaw(PascalCase(Tokens[I].Val));
              K:=Tokens[I].Val;
              Inc(I);
              { sauter eventuelles donnees du variant }
              If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='{')) Then Begin
                Inc(I);
                Var Depth:Integer;
                Depth:=1;
                While (I<=TokCount)and(Depth>0) do Begin
                  If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='{')) Then Inc(Depth) Else
                  If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val='}')) Then Dec(Depth);
                  Inc(I);
                End;
              End;
            End Else
              Inc(I);
          End;
          If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Inc(I);
        End;
        EmitRaw(');');
        EmitLn;
      End;
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') Then Begin
      If I=MainTok Then Begin
        { ignorer ici, le corps est emis dans le begin..end }
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
          Var D:Integer;
          D:=1; Inc(I);
          While (I<=TokCount)and(D>0) do Begin
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(D) Else
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Dec(D);
            Inc(I);
          End;
        End;
      End Else Begin
        EmitFnHeaderAndBody(I,True);
      End;
      Continue;
    End;
    { autres : ignorer }
    Inc(I);
  End;
  Dec(Indent);
  EmitRaw('begin');
  EmitLn;
  Inc(Indent);
  { Corps de main }
  If MainTok>0 Then Begin
    I:=MainTok;
    Inc(I); { fn }
    Inc(I); { main }
    { sauter ()  }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
      If I<=TokCount Then Inc(I);
    End;
    { sauter type retour eventuel }
    If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='->') Then Begin
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  End Else Begin
    EmitRaw('null;');
    EmitLn;
  End;
  Dec(Indent);
  EmitRaw('end '+ProgName+';');
  EmitLn;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('RUST2ADA ',RUST2ADA_VERSION,' - Transpilateur Rust vers Ada');
  WriteLn;
  WriteLn('Syntaxe : RUST2ADA [-v] source.rs [destination.adb]');
  WriteLn;
  WriteLn('  source.rs       Fichier source Rust.');
  WriteLn('  destination.adb Fichier Ada a generer (defaut : source.adb).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : RUST2ADA hello.rs hello.adb');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.adb'
                          Else DstName:=A+'.adb';
  End;
End;

Procedure ExtractProgName;
Var
  I,Start:Integer;
Begin
  I:=Length(SrcName);
  While (I>0)and(SrcName[I]<>'.') do Dec(I);
  If I=0 Then Start:=Length(SrcName)+1
  Else Start:=I;
  I:=Start-1;
  While (I>0)and(SrcName[I]<>'\')and(SrcName[I]<>'/') do Dec(I);
  ProgName:=PascalCase(Copy(SrcName,I+1,Start-I-1));
  If ProgName='' Then ProgName:='Main';
End;

Var
  IPos:Integer;

BEGIN
  ErrorCount:=0;
  ParseArgs;
  ExtractProgName;
  If Verbose Then WriteLn('RUST2ADA : tokenisation de ',SrcName,'...');
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('RUST2ADA : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('RUST2ADA : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('RUST2ADA : module = ',ProgName);
    WriteLn('RUST2ADA : ',FuncCount,' fonction(s).');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('RUST2ADA : impossible de creer ',DstName);
    Halt(EXIT_ERROR);
  End;

  OutLine:='';
  OutCol:=0;
  Indent:=0;
  CurFunc:=0;
  FuncSP:=0;
  IPos:=1;
  EmitProgram;
  If OutLine<>'' Then FlushLine;
  Close(DstFile);
  If Verbose Then WriteLn('RUST2ADA : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
