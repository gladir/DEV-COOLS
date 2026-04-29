{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpilateur Rust vers Turbo Pascal / Free Pascal (.pas)
}

(* ============================================================
   RUST2PAS.PAS - Transpilateur Rust vers Turbo Pascal / Free Pascal
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code source Pascal (.pas) compilable en mode TP.

   Couvre les constructions courantes de Rust :
     fn, let / let mut, const, static, struct, enum simple,
     if / else if / else, while, loop, for x in a..b / a..=b
     (avec .rev() -> for downto), match (avec _ -> else),
     return, break, continue,
     macros println!/print!/eprintln! -> WriteLn/Write,
     types primitifs (i8..i64, u8..u64, isize, usize, f32, f64,
     bool, char, &str, String) mappes vers ShortInt/SmallInt/
     LongInt/Int64/Byte/Word/LongWord/QWord/Single/Double/
     Boolean/Char/String,
     operateurs Rust vers Pascal (== =, != <>, && and, ||
     or, ! not, % mod, :: ., references & ignorees).

   Limitations connues (signalees en commentaires Pascal dans
   la sortie quand applicable) :
     - les variants enum avec donnees ne sont pas traduits, ils
       sont approximes en commentaire ;
     - les traits, impl, generiques, closures, lifetimes, async,
       unsafe ne sont pas supportes ;
     - le type est infere pour `let x = expr;` a partir du litteral
       initial uniquement (sinon LongInt par defaut) ;
     - les macros autres que println!/print!/eprintln!/eprint! sont
       conservees comme appel d'une procedure homonyme.

   Compilation : fpc -Mtp RUST2PAS.PAS -o./BINLINUX/RUST2PAS
   Usage       : RUST2PAS source.rs [destination.pas]
   ============================================================ *)

Program RUST2PAS;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  RUST2PAS_VERSION = '1.0';
  RUST2PAS_DATE    = '2026-04-28';

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
    TK_STRING,     { chaine litterale Rust                   }
    TK_CHAR,       { caractere litteral Rust                 }
    TK_IDENT,      { identificateur ordinaire                }
    TK_KEYWORD,    { mot-cle Rust                            }
    TK_OP,         { operateurs Rust                         }
                   { suite operateurs Rust                   }
    TK_PUNCT       { ponctuation Rust                        }
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

{ En Pascal, on conserve les noms Rust tels quels (snake_case
  est valide, et Pascal est insensible a la casse). On ajoute
  juste un suffixe '_' aux mots reserves Pascal pour eviter les
  collisions. }
Function PascalCase(S:TString):TString;
Var U:TString;
Begin
  U:=StrUpper(S);
  If (U='BEGIN')or(U='END')or(U='PROGRAM')or(U='UNIT')or(U='USES')or
     (U='TYPE')or(U='RECORD')or(U='VAR')or(U='CONST')or(U='LABEL')or
     (U='FUNCTION')or(U='PROCEDURE')or(U='IF')or(U='THEN')or(U='ELSE')or
     (U='CASE')or(U='OF')or(U='FOR')or(U='TO')or(U='DOWNTO')or(U='DO')or
     (U='WHILE')or(U='REPEAT')or(U='UNTIL')or(U='WITH')or
     (U='AND')or(U='OR')or(U='NOT')or(U='XOR')or(U='DIV')or(U='MOD')or
     (U='IN')or(U='IS')or(U='AS')or(U='SHL')or(U='SHR')or
     (U='ARRAY')or(U='SET')or(U='FILE')or(U='STRING')or(U='OBJECT')or
     (U='CLASS')or(U='INTERFACE')or(U='IMPLEMENTATION')or(U='SECTION')or
     (U='NIL')or(U='GOTO')or(U='EXIT')or(U='HALT')or(U='BREAK')or(U='CONTINUE')or
     (U='WRITE')or(U='WRITELN')or(U='READ')or(U='READLN')
  Then PascalCase:=S+'_'
  Else PascalCase:=S;
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
    WriteLn('RUST2PAS : trop de tokens (>',MAX_TOKEN,')');
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
      WriteLn('RUST2PAS : chaine non terminee ligne ',SrcLineNo);
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

{ Lit un litteral char Rust avec sequences d echappement }
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
  Ch,Ch2:Char;
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
    { attention a Rust : a..b et a..=b ne sont pas des reels.
      On ne consume PAS le '.' tant qu'on n'est pas sur que c'est
      vraiment un point decimal. }
    { peek le caractere apres le '.' sans le consommer durablement }
    Ch:=NextCh; { consume 1er '.' }
    Ch2:=PeekCh;
    If (Ch2='.')or(Ch2='=') Then Begin
      { c'est '..=' ou '..' : remettre le '.' deja consume.
        Pending = Ch2 a ce stade (depuis PeekCh) mais Ch2 est le 2e
        caractere, donc on perdrait le 1er. Pour eviter cela, on
        consomme Ch2 du pending et on injecte '.'+Ch2 sous forme
        d un re-injection en deux etapes. }
      { Vider le pending en consommant Ch2 (le 2e car) }
      Ch2:=NextCh;
      { Remettre le 2e car en pending pour qu il soit lu apres le '.' }
      { Comme pending n a qu un slot, on remet plutot via SrcText :
        on decremente SrcCol pour replacer Ch2 et on met '.' en pending. }
      Dec(SrcCol);
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
      'A'..'Z','a','c'..'q','s'..'z','_':ScanIdent(Ch);
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
  If T='i8' Then MapRustType:='ShortInt' Else
  If T='i16' Then MapRustType:='SmallInt' Else
  If (T='i32')or(T='isize') Then MapRustType:='LongInt' Else
  If T='i64' Then MapRustType:='Int64' Else
  If T='u8' Then MapRustType:='Byte' Else
  If T='u16' Then MapRustType:='Word' Else
  If (T='u32')or(T='usize') Then MapRustType:='LongWord' Else
  If T='u64' Then MapRustType:='QWord' Else
  If T='f32' Then MapRustType:='Single' Else
  If T='f64' Then MapRustType:='Double' Else
  If T='bool' Then MapRustType:='Boolean' Else
  If T='char' Then MapRustType:='Char' Else
  If (T='str')or(T='String') Then MapRustType:='String' Else
    MapRustType:=T;
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

{ Conversion d'une chaine Rust "abc\n" en chaine Pascal 'abc'#10.
  Approximation : on remplace les sequences \n, \t, \r, \0 par
  des concatenations Pascal #N. Les guillemets simples sont
  doubles. }
Function RustStringToPas(S:TString):TString;
Var
  I:Integer;
  R,Acc:TString;

  Procedure FlushAcc;
  Begin
    If Acc<>'' Then Begin
      R:=R+''''+Acc+'''';
      Acc:='';
    End;
  End;

  Procedure EmitChar(Code:Integer);
  Begin
    FlushAcc;
    Str(Code,Acc);
    R:=R+'#'+Acc;
    Acc:='';
  End;

Begin
  R:='';
  Acc:='';
  I:=2; { sauter " }
  While I<Length(S) do Begin
    If (S[I]='\') and (I<Length(S)-1) Then Begin
      Case S[I+1] of
        'n':EmitChar(10);
        't':EmitChar(9);
        'r':EmitChar(13);
        '0':EmitChar(0);
        '\':Acc:=Acc+'\';
        '"':Acc:=Acc+'"';
        '''':Acc:=Acc+'''''';
      Else
        Acc:=Acc+S[I+1];
      End;
      Inc(I,2);
    End Else
    If S[I]='''' Then Begin
      Acc:=Acc+'''''';
      Inc(I);
    End Else Begin
      Acc:=Acc+S[I];
      Inc(I);
    End;
  End;
  FlushAcc;
  If R='' Then R:='''''';
  RustStringToPas:=R;
End;

Function RustCharToPas(S:TString):TString;
Var
  Body,N:TString;
Begin
  { S = 'x' or '\n' ... }
  Body:=Copy(S,2,Length(S)-2);
  If (Length(Body)=2) and (Body[1]='\') Then Begin
    Case Body[2] of
      'n':RustCharToPas:='#10';
      't':RustCharToPas:='#9';
      'r':RustCharToPas:='#13';
      '0':RustCharToPas:='#0';
      '\':RustCharToPas:='''\''';
      '''':RustCharToPas:='''''''''';
      '"':RustCharToPas:='''"''';
    Else
      RustCharToPas:=''''+Body[2]+'''';
    End;
    Exit;
  End;
  If Length(Body)=1 Then Begin
    If Body='''' Then RustCharToPas:=''''''''''''
    Else RustCharToPas:=''''+Body+'''';
    Exit;
  End;
  RustCharToPas:='''?'' { '+S+' }';
End;

{ Nettoie un litteral numerique Rust : retire les '_' et les
  suffixes type i32/u8/f64/usize/isize/etc. Renvoie aussi
  l indication isReal pour les suffixes f32/f64. }
Function CleanNumber(S:TString):TString;
Var
  R:TString;
  I,L:Integer;
Begin
  R:='';
  L:=Length(S);
  { trouver debut suffixe : derniere occurrence d'un i/u/f
    suivi de chiffres, mais pas pour 0xAF / 0b... }
  I:=L;
  While (I>1) and (S[I] in ['0'..'9']) do Dec(I);
  If (I>=1) and (I<L) and ((S[I]='i')or(S[I]='u')or(S[I]='f')) then Begin
    { suffixe entier de type i32/u32/f64 ; mais attention a 0x... }
    If Not ((Length(S)>=3)and(S[1]='0')and((S[2]='x')or(S[2]='X'))) Then
      L:=I-1;
  End;
  { cas usize/isize : gerer textuellement }
  If (L>=5)and(Copy(S,L-4,5)='usize') Then L:=L-5;
  If (L>=5)and(Copy(S,L-4,5)='isize') Then L:=L-5;
  For I:=1 to L do
    If S[I]<>'_' Then R:=R+S[I];
  If R='' Then R:='0';
  CleanNumber:=R;
End;

Function MapOperator(Op:TString):TString;
Begin
  If Op='==' Then MapOperator:='=' Else
  If Op='!=' Then MapOperator:='<>' Else
  If Op='&&' Then MapOperator:=' and ' Else
  If Op='||' Then MapOperator:=' or ' Else
  If Op='%'  Then MapOperator:=' mod ' Else
  If Op='<<' Then MapOperator:=' shl ' Else
  If Op='>>' Then MapOperator:=' shr ' Else
  If Op='!'  Then MapOperator:='not ' Else
  If Op='::' Then MapOperator:='.' Else
  If Op='->' Then MapOperator:='->' Else
  If Op='=>' Then MapOperator:='=>' Else
  If Op='='  Then MapOperator:=':=' Else
                  MapOperator:=Op;
End;

{ Forward declarations }
Procedure EmitStmt(Var I:Integer); Forward;
Procedure EmitBlock(Var I:Integer); Forward;
Procedure EmitExpr(Var I:Integer); Forward;
Procedure EmitFnHeaderAndBody(Var I:Integer; AsNested:Boolean); Forward;

{ Emet une expression jusqu au prochain separateur de niveau 0.
  Convertit operateurs, identificateurs, litteraux. Ne descend
  pas dans les blocs. }
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
          { reference : ignorer (Pascal n a pas d emprunt) }
        End Else
        If (K='..') or (K='..=') Then EmitRaw('..') Else
          EmitRaw(MapOperator(K));
      End;
      TK_KEYWORD:Begin
        K:=Tokens[I].Val;
        If K='true' Then EmitRaw('True') Else
        If K='false' Then EmitRaw('False') Else
        If K='self' Then EmitRaw('Self_') Else
        If K='Self' Then EmitRaw('Self_') Else
        If K='mut' Then { ignorer dans expression } Else
        If K='ref' Then { ignorer } Else
        If K='as' Then EmitRaw(' { as } ') Else
          EmitRaw(K);
      End;
      TK_IDENT:Begin
        EmitRaw(Tokens[I].Val);
      End;
      TK_INTEGER:Begin
        K:=CleanNumber(Tokens[I].Val);
        { 0xFF -> $FF en Pascal }
        If (Length(K)>=3) and (K[1]='0') and ((K[2]='x')or(K[2]='X')) Then
          EmitRaw('$'+Copy(K,3,Length(K)-2))
        Else
        If (Length(K)>=3) and (K[1]='0') and (K[2]='b') Then
          EmitRaw('%'+Copy(K,3,Length(K)-2))
        Else
        If (Length(K)>=3) and (K[1]='0') and (K[2]='o') Then
          EmitRaw('&'+Copy(K,3,Length(K)-2))
        Else
          EmitRaw(K);
      End;
      TK_REAL:EmitRaw(CleanNumber(Tokens[I].Val));
      TK_STRING:EmitRaw(RustStringToPas(Tokens[I].Val));
      TK_CHAR:EmitRaw(RustCharToPas(Tokens[I].Val));
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

(* Emet l argument format de println!/print!/eprintln!.
   En Pascal, on emet une suite d arguments separes par virgules
   pour Write/WriteLn. Chaque accolade vide du format devient
   une separation entre arguments. *)
Procedure EmitFormatArgs(Var I:Integer);
Var
  Fmt,Cur,Seg:TString;
  ArgIdx:Integer;
  Args:Array[1..16] of String[80];
  ArgCount:Integer;
  Depth:Integer;
  S:TString;
  P:Integer;
  FirstOut:Boolean;

  Procedure FlushSeg;
  Var R:TString; J:Integer;
  Begin
    If Seg='' Then Exit;
    If Not FirstOut Then EmitRaw(', ');
    FirstOut:=False;
    R:='';
    For J:=1 to Length(Seg) do
      If Seg[J]='''' Then R:=R+''''''
      Else R:=R+Seg[J];
    EmitRaw(''''+R+'''');
    Seg:='';
  End;

  Procedure EmitCh(Code:Integer);
  Var T:TString;
  Begin
    FlushSeg;
    If Not FirstOut Then EmitRaw(', ');
    FirstOut:=False;
    Str(Code,T);
    EmitRaw('#'+T);
  End;

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
        If (Tokens[I].Kind=TK_OP) Then
          Cur:=Cur+MapOperator(Tokens[I].Val)
        Else
        If (Tokens[I].Kind=TK_INTEGER)or(Tokens[I].Kind=TK_REAL) Then
          Cur:=Cur+CleanNumber(Tokens[I].Val)
        Else
          Cur:=Cur+Tokens[I].Val;
      End;
      Inc(I);
    End;
    Inc(ArgCount);
    If ArgCount<=16 Then Args[ArgCount]:=Cur;
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);

  { Pas de format -> emettre chaine vide explicite ; mais notre
    appelant gere deja le cas des parentheses vides. }
  S:=Copy(Fmt,2,Length(Fmt)-2); { sans guillemets }
  ArgIdx:=0;
  Seg:='';
  P:=1;
  FirstOut:=True;
  While P<=Length(S) do Begin
    If (P<Length(S))and(S[P]='{')and(S[P+1]='}') Then Begin
      FlushSeg;
      Inc(ArgIdx);
      If ArgIdx<=ArgCount Then Begin
        If Not FirstOut Then EmitRaw(', ');
        FirstOut:=False;
        EmitRaw(Args[ArgIdx]);
      End;
      Inc(P,2);
    End Else
    If S[P]='\' Then Begin
      If (P<Length(S))and(S[P+1]='n') Then Begin
        EmitCh(10); Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='t') Then Begin
        EmitCh(9); Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='r') Then Begin
        EmitCh(13); Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='"') Then Begin
        Seg:=Seg+'"'; Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='\') Then Begin
        Seg:=Seg+'\'; Inc(P,2);
      End Else
      If (P<Length(S))and(S[P+1]='''') Then Begin
        Seg:=Seg+''''; Inc(P,2);
      End Else Begin
        Seg:=Seg+S[P]; Inc(P);
      End;
    End Else Begin
      Seg:=Seg+S[P]; Inc(P);
    End;
  End;
  FlushSeg;
  If FirstOut Then EmitRaw('''''');
End;

{ Emet un appel d'identificateur (potentiellement un appel
  de fonction). I pointe sur l'ident. }
Procedure EmitCallOrAssign(Var I:Integer);
Var
  Name:TString;
Begin
  Name:=Tokens[I].Val;
  { Macros : ident! ( ... ) }
  If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_OP)and(Tokens[I+1].Val='!') Then Begin
    Inc(I,2);
    If (Name='println')or(Name='eprintln') Then Begin
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
        { verifier si vide : "()" -> WriteLn sans args }
        If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val=')') Then Begin
          EmitRaw('WriteLn');
          Inc(I,2);
          Exit;
        End;
      End;
      EmitRaw('WriteLn(');
      EmitFormatArgs(I);
      EmitRaw(')');
      Exit;
    End Else
    If (Name='print')or(Name='eprint') Then Begin
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
        If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val=')') Then Begin
          EmitRaw('Write');
          Inc(I,2);
          Exit;
        End;
      End;
      EmitRaw('Write(');
      EmitFormatArgs(I);
      EmitRaw(')');
      Exit;
    End Else
    If (Name='format') Then Begin
      { format!(...) -> approxime par concat ; emis comme commentaire }
      EmitRaw('{format!} ');
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
        Inc(I);
        EmitExpr(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')') Then Inc(I);
      End;
      Exit;
    End Else
    If (Name='vec') Then Begin
      EmitRaw('{vec!} ');
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='[')or(Tokens[I].Val='(')) Then Begin
        Inc(I);
        EmitRaw('(');
        EmitExpr(I);
        EmitRaw(')');
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=']')or(Tokens[I].Val=')')) Then Inc(I);
      End;
      Exit;
    End Else Begin
      { autre macro : conserver comme appel }
      EmitRaw(Name+' { macro } (');
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

{ Devine un type Pascal a partir du litteral initial d'un let
  sans annotation. }
Function GuessType(I:Integer):TString;
Begin
  If I>TokCount Then Begin GuessType:='LongInt'; Exit; End;
  Case Tokens[I].Kind of
    TK_INTEGER:GuessType:='LongInt';
    TK_REAL   :GuessType:='Double';
    TK_STRING :GuessType:='String';
    TK_CHAR   :GuessType:='Char';
    TK_IDENT  :Begin
      (* litteral de struct : Ident suivi de '{' *)
      If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='{') Then
        GuessType:=PascalCase(Tokens[I].Val)
      Else
      If (I+1<=TokCount)and(Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='(') Then
        GuessType:='LongInt' (* appel de fonction : approxime *)
      Else
        GuessType:='LongInt';
    End;
    TK_KEYWORD:Begin
      If (Tokens[I].Val='true')or(Tokens[I].Val='false') Then GuessType:='Boolean'
      Else GuessType:='LongInt';
    End;
  Else
    GuessType:='LongInt';
  End;
End;

{ Construit le texte d'un type Pascal a partir d'un type Rust
  starting at I (sans avancer I). Retourne aussi NewI : index
  apres le type. Ne consume pas l'expression d initialisation. }
Function ReadType(Var I:Integer):TString;
Var
  Depth:Integer;
  K,R:TString;
  First:Boolean;
Begin
  R:='';
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
        If (K='mut')or(K='dyn') Then { ignorer } Else
          R:=R+K;
      End;
      TK_IDENT:Begin
        If First Then Begin R:=R+MapRustType(Tokens[I].Val); First:=False; End
        Else R:=R+MapRustType(Tokens[I].Val);
      End;
      TK_OP:Begin
        K:=Tokens[I].Val;
        If K='&' Then { reference : ignorer } Else
        If K='<' Then Begin Inc(Depth); R:=R+' { < } '; End Else
        If K='>' Then Begin Dec(Depth); R:=R+' { > } '; End
        Else R:=R+K;
      End;
      TK_PUNCT:Begin
        K:=Tokens[I].Val;
        If K='(' Then Begin Inc(Depth); R:=R+'('; End Else
        If K=')' Then Begin Dec(Depth); R:=R+')'; End Else
          R:=R+K;
      End;
    Else
      R:=R+Tokens[I].Val;
    End;
    Inc(I);
  End;
  If R='' Then R:='LongInt';
  ReadType:=R;
End;

(* Emet une affectation de let dans le corps Pascal :
   let [mut] name [: T] = expr;  -->  name := expr;
   let [mut] name [: T];          -->  rien (juste declaree).
   La declaration de variable est emise ailleurs (section var).
   Cas particulier : let p = Point ouvre-acc x:1, y:2 ferme-acc ;
   --> p.x := 1; p.y := 2; (champs separes) *)
Procedure EmitLet(Var I:Integer);
Var
  Name,FName:TString;
  J,SaveI:Integer;
  IsStructLit:Boolean;
Begin
  Inc(I); { sauter let }
  If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Inc(I);
  Name:='X';
  If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
    Name:=PascalCase(Tokens[I].Val);
    Inc(I);
  End;
  { sauter type s il y en a un }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
    Inc(I);
    While (I<=TokCount) and
          Not((Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=')) and
          Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Inc(I);
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
    Inc(I);
    (* detecter litteral struct : Type ouvre-acc field: val, ... ferme-acc *)
    IsStructLit:=False;
    If (I+1<=TokCount)and(Tokens[I].Kind=TK_IDENT)and
       (Tokens[I+1].Kind=TK_PUNCT)and(Tokens[I+1].Val='{') Then
      IsStructLit:=True;
    If IsStructLit Then Begin
      Inc(I); (* sauter ident type *)
      Inc(I); { sauter '{' }
      While (I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}')) do Begin
        FName:='';
        If (Tokens[I].Kind=TK_IDENT) Then Begin
          FName:=PascalCase(Tokens[I].Val);
          Inc(I);
        End;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
        EmitRaw(Name+'.'+FName+' := ');
        EmitExpr(I);
        EmitRaw(';');
        EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Inc(I);
    End Else Begin
      EmitRaw(Name+' := ');
      EmitExpr(I);
      EmitRaw(';');
      EmitLn;
    End;
  End;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
End;

{ Emet une instruction if .. else if .. else .. en Pascal :
   if cond then begin ... end else if cond then begin ... end
                                  else begin ... end;  }
Procedure EmitIf(Var I:Integer);
Begin
  Inc(I); { if }
  EmitRaw('if ');
  EmitExpr(I);
  EmitRaw(' then begin');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then
    EmitBlock(I);
  Dec(Indent);
  While (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='else') do Begin
    Inc(I);
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='if') Then Begin
      Inc(I);
      EmitRaw('end else if ');
      EmitExpr(I);
      EmitRaw(' then begin');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
      Dec(Indent);
    End Else Begin
      EmitRaw('end else begin');
      EmitLn;
      Inc(Indent);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
      Dec(Indent);
      Break;
    End;
  End;
  EmitRaw('end;');
  EmitLn;
End;

Procedure EmitWhile(Var I:Integer);
Begin
  Inc(I);
  EmitRaw('while ');
  EmitExpr(I);
  EmitRaw(' do begin');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
End;

Procedure EmitLoop(Var I:Integer);
Begin
  Inc(I);
  EmitRaw('while True do begin');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
End;

{ for x in a..b devient for X := A to B-1 do begin ... end;
  for x in a..=b devient for X := A to B do begin ... end;
  for x in (a..b).rev() devient for X := B-1 downto A do ... }
Procedure EmitFor(Var I:Integer);
Var
  VName:TString;
  Inclusive,Reverse:Boolean;
  Depth:Integer;
  StartTok,DotsTok,EndTok:Integer;
  J:Integer;

  Procedure EmitRange(From,UpTo:Integer);
  Var KK,LocDepth:Integer;
  Begin
    KK:=From;
    LocDepth:=0;
    While (KK<UpTo) do Begin
      { stopper sur '.' (appel de methode comme .rev()) au niveau 0 }
      If (LocDepth=0)and(Tokens[KK].Kind=TK_PUNCT)and(Tokens[KK].Val='.') Then Break;
      If (Tokens[KK].Kind=TK_PUNCT)and(Tokens[KK].Val='(') Then Begin
        Inc(LocDepth);
        Inc(KK);
        Continue;
      End;
      If (Tokens[KK].Kind=TK_PUNCT)and(Tokens[KK].Val=')') Then Begin
        If LocDepth=0 Then Break; { ')' non apparie : fin de borne }
        Dec(LocDepth);
        Inc(KK);
        Continue;
      End;
      Case Tokens[KK].Kind of
        TK_INTEGER:EmitRaw(CleanNumber(Tokens[KK].Val));
        TK_REAL   :EmitRaw(CleanNumber(Tokens[KK].Val));
        TK_IDENT,TK_KEYWORD:EmitRaw(Tokens[KK].Val);
        TK_OP:EmitRaw(MapOperator(Tokens[KK].Val));
      Else
        EmitRaw(Tokens[KK].Val);
      End;
      Inc(KK);
    End;
  End;

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
  StartTok:=I;
  DotsTok:=0;
  EndTok:=0;
  Depth:=0;
  J:=I;
  While J<=TokCount do Begin
    If (Depth=0)and(Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='{') Then Break;
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='(') Then Inc(Depth) Else
    If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val=')') Then Dec(Depth);
    If (DotsTok=0)and(Tokens[J].Kind=TK_OP)and((Tokens[J].Val='..')or(Tokens[J].Val='..=')) Then Begin
      DotsTok:=J;
      If Tokens[J].Val='..=' Then Inclusive:=True;
    End;
    If (Tokens[J].Kind=TK_IDENT)and(Tokens[J].Val='rev') Then Reverse:=True;
    Inc(J);
  End;
  EndTok:=J;
  EmitRaw('for '+VName+' := ');
  If DotsTok>0 Then Begin
    If Reverse Then Begin
      { for X := (high) downto (low) }
      EmitRange(DotsTok+1,EndTok);
      If Not Inclusive Then EmitRaw(' - 1');
      EmitRaw(' downto ');
      EmitRange(StartTok,DotsTok);
    End Else Begin
      EmitRange(StartTok,DotsTok);
      EmitRaw(' to ');
      EmitRange(DotsTok+1,EndTok);
      If Not Inclusive Then EmitRaw(' - 1');
    End;
    I:=EndTok;
  End Else Begin
    EmitExpr(I);
  End;
  EmitRaw(' do begin');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
End;

{ match Rust devient case Pascal :
   case X of
     V1: instr;
     V2,V3: instr;
   else
     instr;
   end; }
Procedure EmitMatch(Var I:Integer);
Var
  IsOthers:Boolean;
Begin
  Inc(I); { match }
  EmitRaw('case ');
  EmitExpr(I);
  EmitRaw(' of');
  EmitLn;
  Inc(Indent);
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(I);
  While (I<=TokCount) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Begin
      Inc(I);
      Break;
    End;
    { detection du _ ou autre underscore comme pattern }
    IsOthers:=False;
    If ((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='_')) or
       ((Tokens[I].Kind=TK_IDENT)and(Tokens[I].Val='_')) Then Begin
      { pattern others : on emet else }
      Dec(Indent);
      EmitRaw('else');
      EmitLn;
      Inc(Indent);
      IsOthers:=True;
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=>') Then Inc(I);
    End Else Begin
      { lire pattern jusqu'a => , patterns multiples avec | -> ',' }
      While (I<=TokCount) do Begin
        If (Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=>') Then Begin Inc(I); Break; End;
        Case Tokens[I].Kind of
          TK_OP:Begin
            If Tokens[I].Val='|' Then EmitRaw(', ') Else
            If (Tokens[I].Val='..=') Then EmitRaw('..') Else
            If (Tokens[I].Val='..') Then EmitRaw('..') Else
              EmitRaw(MapOperator(Tokens[I].Val));
          End;
          TK_INTEGER:EmitRaw(CleanNumber(Tokens[I].Val));
          TK_REAL   :EmitRaw(CleanNumber(Tokens[I].Val));
          TK_IDENT,TK_KEYWORD:EmitRaw(Tokens[I].Val);
          TK_STRING:EmitRaw(RustStringToPas(Tokens[I].Val));
          TK_CHAR  :EmitRaw(RustCharToPas(Tokens[I].Val));
        Else
          EmitRaw(Tokens[I].Val);
        End;
        Inc(I);
      End;
      EmitRaw(': ');
    End;
    { corps de la branche : expression simple, instruction ou bloc }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
      EmitRaw('begin');
      EmitLn;
      Inc(Indent);
      EmitBlock(I);
      Dec(Indent);
      EmitRaw('end;');
      EmitLn;
    End Else
    If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='return')or(Tokens[I].Val='break')or
        (Tokens[I].Val='continue')) Then Begin
      EmitRaw('Begin ');
      EmitStmt(I);
      EmitRaw(' End;');
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
  EmitRaw('end;');
  EmitLn;
End;

{ Determine si un bloc Rust contient des let au niveau 1. }
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
        EmitLet(I);
      End Else
      If K='if' Then EmitIf(I) Else
      If K='while' Then EmitWhile(I) Else
      If K='loop' Then EmitLoop(I) Else
      If K='for' Then EmitFor(I) Else
      If K='match' Then EmitMatch(I) Else
      If K='return' Then Begin
        Inc(I);
        If (I<=TokCount)and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) Then Begin
          { return expr -> result := expr; Exit; en mode TP, le nom
            de fonction est utilise comme variable de resultat. }
          If (CurFunc>0)and(CurFunc<=FuncCount)and(Funcs[CurFunc].IsFunc) Then Begin
            EmitRaw(PascalCase(Funcs[CurFunc].Name)+' := ');
            EmitExpr(I);
            EmitRaw('; Exit;');
          End Else Begin
            EmitRaw('{ return } ');
            EmitExpr(I);
            EmitRaw('; Exit;');
          End;
        End Else Begin
          EmitRaw('Exit;');
        End;
        EmitLn;
      End Else
      If K='break' Then Begin
        Inc(I);
        EmitRaw('Break;');
        EmitLn;
      End Else
      If K='continue' Then Begin
        Inc(I);
        EmitRaw('Continue;');
        EmitLn;
      End Else
      If K='pub' Then Begin
        Inc(I);
        EmitStmt(I);
      End Else
      If K='unsafe' Then Begin
        Inc(I);
        EmitRaw('{ unsafe block aplati }');
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

(* Emet le contenu d un bloc Rust. I pointe sur l accolade
   ouvrante. Les declarations let sont transformees en simples
   affectations ; les types sont declares au niveau du var
   Pascal de la fonction englobante (voir CollectAndEmitVars).
   Si IsFnBody est vrai et que le bloc se termine par une
   expression sans ';' final, c est un implicit return Rust :
   on emet funcName := expr; Exit;  *)
Procedure EmitBlock(Var I:Integer);
Var
  Depth,K,LDepth:Integer;
  IsTrailExpr,IsFnBody:Boolean;
Begin
  If (I>TokCount)or(Tokens[I].Kind<>TK_PUNCT)or(Tokens[I].Val<>'{') Then Exit;
  IsFnBody:=(CurFunc>0)and(CurFunc<=FuncCount)and Funcs[CurFunc].IsFunc;
  Inc(I); (* sauter '{' *)
  Depth:=1;
  While (I<=TokCount)and(Depth>0) do Begin
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
      EmitRaw('begin');
      EmitLn;
      Inc(Indent);
      EmitBlock(I);
      Dec(Indent);
      EmitRaw('end;');
      EmitLn;
    End Else
    If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Begin
      Dec(Depth);
      If Depth=0 Then Begin Inc(I); Break; End;
    End Else
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') Then Begin
      Inc(I);
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
        Inc(I);
        Depth:=Depth+1;
        While (I<=TokCount)and(Depth>1) do Begin
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(Depth) Else
          If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Dec(Depth);
          Inc(I);
        End;
      End;
    End Else Begin
      (* implicit return : si IsFnBody et l expression courante n est
         pas terminee par ';' avant le '}' final, c est un retour. *)
      IsTrailExpr:=False;
      If IsFnBody and (Depth=1) and Not
         ((Tokens[I].Kind=TK_KEYWORD)and
          ((Tokens[I].Val='let')or(Tokens[I].Val='if')or
           (Tokens[I].Val='while')or(Tokens[I].Val='for')or
           (Tokens[I].Val='loop')or(Tokens[I].Val='match')or
           (Tokens[I].Val='return')or(Tokens[I].Val='break')or
           (Tokens[I].Val='continue')or(Tokens[I].Val='unsafe'))) Then Begin
        (* scan : trouver le prochain ; ou } au niveau 0 *)
        K:=I; LDepth:=0;
        While K<=TokCount do Begin
          If (LDepth=0)and(Tokens[K].Kind=TK_PUNCT)and(Tokens[K].Val=';') Then Break;
          If (LDepth=0)and(Tokens[K].Kind=TK_PUNCT)and(Tokens[K].Val='}') Then Begin
            IsTrailExpr:=True;
            Break;
          End;
          If (Tokens[K].Kind=TK_PUNCT)and
             ((Tokens[K].Val='(')or(Tokens[K].Val='[')or(Tokens[K].Val='{')) Then Inc(LDepth) Else
          If (Tokens[K].Kind=TK_PUNCT)and
             ((Tokens[K].Val=')')or(Tokens[K].Val=']')or(Tokens[K].Val='}')) Then Dec(LDepth);
          Inc(K);
        End;
      End;
      If IsTrailExpr Then Begin
        EmitRaw(PascalCase(Funcs[CurFunc].Name)+' := ');
        EmitExpr(I);
        EmitRaw('; Exit;');
        EmitLn;
      End Else Begin
        EmitStmt(I);
      End;
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
    End;
  End;
End;

{ Pre-scan recursif d un corps de fonction pour collecter tous les
  let (declaration de var Pascal). Les let dans les sous-blocs sont
  hisses dans la section var de la fonction. Pas de gestion des
  shadowings (premiere occurrence l emporte). I doit pointer sur '{'
  ouvrant ; cette procedure ne consume pas. }
Type
  TVarDecl = Record
    Name : TString;
    Typ  : TString;
  End;

Var
  CollectedVars : Array[1..128] of TVarDecl;
  CollectedCount: Integer;

Procedure AddVar(Name,Typ:TString);
Var I:Integer;
Begin
  For I:=1 to CollectedCount do
    If StrEqualCI(CollectedVars[I].Name,Name) Then Exit;
  If CollectedCount>=128 Then Exit;
  Inc(CollectedCount);
  CollectedVars[CollectedCount].Name:=Name;
  CollectedVars[CollectedCount].Typ :=Typ;
End;

Procedure CollectLetsRec(StartTok,EndTok:Integer);
Var
  I,J,SaveI:Integer;
  Name,Typ:TString;
Begin
  I:=StartTok;
  While I<=EndTok do Begin
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='let') Then Begin
      Inc(I);
      If (I<=EndTok)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Inc(I);
      If (I<=EndTok)and(Tokens[I].Kind=TK_IDENT) Then Begin
        Name:=PascalCase(Tokens[I].Val);
        Inc(I);
        Typ:='';
        If (I<=EndTok)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
          Inc(I);
          SaveI:=I;
          Typ:=ReadType(I);
          If Typ='' Then Typ:='LongInt';
          { I avance dans ReadType jusqu a '=' ou ';' }
        End Else Begin
          { type infere du litteral apres = }
          J:=I;
          If (J<=EndTok)and(Tokens[J].Kind=TK_OP)and(Tokens[J].Val='=') Then Inc(J);
          Typ:=GuessType(J);
        End;
        AddVar(Name,Typ);
      End;
    End Else
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='for') Then Begin
      { for var in ... -> var devient une boucle Pascal. var doit etre declaree. }
      Inc(I);
      If (I<=EndTok)and(Tokens[I].Kind=TK_IDENT) Then Begin
        Name:=PascalCase(Tokens[I].Val);
        AddVar(Name,'LongInt');
        Inc(I);
      End;
    End Else
      Inc(I);
  End;
End;

Procedure EmitVarSection;
Var I:Integer;
Begin
  If CollectedCount=0 Then Exit;
  EmitRaw('var');
  EmitLn;
  Inc(Indent);
  For I:=1 to CollectedCount do Begin
    EmitRaw(CollectedVars[I].Name+' : '+CollectedVars[I].Typ+';');
    EmitLn;
  End;
  Dec(Indent);
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
    EmitRaw('(');
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
        PName:='Self_';
        Inc(I);
      End;
      { ':' }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Inc(I);
      { mode : & = par valeur (in), &mut = par var, sinon par valeur }
      IsMut:=False;
      If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='&') Then Begin
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Begin
          IsMut:=True;
          Inc(I);
        End;
      End;
      If IsMut Then EmitRaw('var ');
      EmitRaw(PName+' : ');
      { type }
      PType:=ReadType(I);
      EmitRaw(PType);
      { virgule }
      If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
    End;
    EmitRaw(')');
  End;
  If IsFunc Then Begin
    If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='->') Then Begin
      Inc(I);
      EmitRaw(' : ');
      RetType:=ReadType(I);
      EmitRaw(RetType);
    End;
  End;
  EmitRaw(';');
  EmitLn;
  { etablir CurFunc }
  If FIdx>0 Then CurFunc:=FIdx;
  { collecter les let pour la section var }
  CollectedCount:=0;
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
    { trouver l index de fin du bloc }
    Depth:=1;
    PIdx:=I+1;
    While (PIdx<=TokCount)and(Depth>0) do Begin
      If (Tokens[PIdx].Kind=TK_PUNCT)and(Tokens[PIdx].Val='{') Then Inc(Depth) Else
      If (Tokens[PIdx].Kind=TK_PUNCT)and(Tokens[PIdx].Val='}') Then Dec(Depth);
      Inc(PIdx);
    End;
    CollectLetsRec(I+1,PIdx-1);
  End;
  EmitVarSection;
  EmitRaw('begin');
  EmitLn;
  Inc(Indent);
  { corps }
  If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then EmitBlock(I);
  Dec(Indent);
  EmitRaw('end;');
  EmitLn;
  EmitLn;
  CurFunc:=0;
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

{ Emet la sortie complete : program X; type/const sections,
  sous-programmes, begin (corps de main) end. }
Procedure EmitProgram;
Var
  I,J,MainTok:Integer;
  K:TString;
  EnumDepth:Integer;
  MainBodyDepth:Integer;
  MainBodyStart,MainBodyEnd:Integer;
  Depth:Integer;
  HasTypeSection:Boolean;
Begin
  EmitRaw('{ Genere par RUST2PAS '+RUST2PAS_VERSION+' a partir de '+SrcName+' }');
  EmitLn;
  EmitRaw('Program '+ProgName+';');
  EmitLn;
  EmitLn;
  EmitRaw('{$IFDEF FPC}');
  EmitLn;
  EmitRaw('  {$MODE TP}');
  EmitLn;
  EmitRaw('  {$H-}');
  EmitLn;
  EmitRaw('{$ENDIF}');
  EmitLn;
  EmitLn;

  MainTok:=FindMain;

  { Premiere passe : emettre type (struct/enum) et const/static }
  HasTypeSection:=False;
  I:=1;
  While I<=TokCount do Begin
    SkipAttribute(I);
    If I>TokCount Then Break;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='pub') Then Begin Inc(I); Continue; End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='struct') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        If Not HasTypeSection Then Begin
          EmitRaw('Type'); EmitLn; Inc(Indent); HasTypeSection:=True;
        End;
        EmitRaw(PascalCase(Tokens[I].Val)+' = Record');
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
              EmitRaw(ReadType(I));
              EmitRaw(';');
              EmitLn;
              If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then Inc(I);
            End Else
              Inc(I);
          End;
          If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Inc(I);
        End;
        Dec(Indent);
        EmitRaw('End;');
        EmitLn;
      End;
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='enum') Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        If Not HasTypeSection Then Begin
          EmitRaw('Type'); EmitLn; Inc(Indent); HasTypeSection:=True;
        End;
        EmitRaw(PascalCase(Tokens[I].Val)+' = (');
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
                EnumDepth:=1;
                While (I<=TokCount)and(EnumDepth>0) do Begin
                  If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val='(')or(Tokens[I].Val='{')) Then Inc(EnumDepth) Else
                  If (Tokens[I].Kind=TK_PUNCT)and((Tokens[I].Val=')')or(Tokens[I].Val='}')) Then Dec(EnumDepth);
                  Inc(I);
                End;
              End;
            End Else
            If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=',') Then
              Inc(I)
            Else
              Inc(I);
          End;
          If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Inc(I);
        End;
        EmitRaw(');');
        EmitLn;
      End;
      Continue;
    End;
    Inc(I);
  End;
  If HasTypeSection Then Begin
    Dec(Indent);
    EmitLn;
  End;

  { Deuxieme passe : emettre const/static }
  I:=1;
  J:=0; { compteur de const }
  While I<=TokCount do Begin
    SkipAttribute(I);
    If I>TokCount Then Break;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='pub') Then Begin Inc(I); Continue; End;
    If (Tokens[I].Kind=TK_KEYWORD)and((Tokens[I].Val='const')or(Tokens[I].Val='static')) Then Begin
      Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='mut') Then Inc(I);
      If (I<=TokCount)and(Tokens[I].Kind=TK_IDENT) Then Begin
        If J=0 Then Begin EmitRaw('Const'); EmitLn; Inc(Indent); End;
        Inc(J);
        EmitRaw(PascalCase(Tokens[I].Val));
        Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=':') Then Begin
          Inc(I);
          EmitRaw(' : ');
          EmitRaw(ReadType(I));
        End;
        If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='=') Then Begin
          Inc(I);
          EmitRaw(' = ');
          EmitExpr(I);
        End;
        EmitRaw(';');
        EmitLn;
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Inc(I);
      End;
      Continue;
    End;
    Inc(I);
  End;
  If J>0 Then Begin Dec(Indent); EmitLn; End;

  { Troisieme passe : sous-programmes (sauf main) }
  I:=1;
  While I<=TokCount do Begin
    SkipAttribute(I);
    If I>TokCount Then Break;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='pub') Then Begin Inc(I); Continue; End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='use') Then Begin
      EmitRaw('{ ');
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';')) do Begin
        EmitRaw(Tokens[I].Val+' ');
        Inc(I);
      End;
      EmitRaw('; }');
      EmitLn;
      If I<=TokCount Then Inc(I);
      Continue;
    End;
    If (Tokens[I].Kind=TK_KEYWORD)and(Tokens[I].Val='fn') Then Begin
      If I=MainTok Then Begin
        { ignorer ici, le corps est emis dans le begin..end }
        Inc(I);
        While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
        If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
          MainBodyDepth:=1; Inc(I);
          While (I<=TokCount)and(MainBodyDepth>0) do Begin
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(MainBodyDepth) Else
            If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Dec(MainBodyDepth);
            Inc(I);
          End;
        End;
      End Else Begin
        EmitFnHeaderAndBody(I,True);
      End;
      Continue;
    End;
    { skip struct/enum/const/static deja traites }
    If (Tokens[I].Kind=TK_KEYWORD)and
       ((Tokens[I].Val='struct')or(Tokens[I].Val='enum')or
        (Tokens[I].Val='const')or(Tokens[I].Val='static')) Then Begin
      Inc(I);
      Depth:=0;
      While (I<=TokCount) do Begin
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Inc(Depth) Else
        If (Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='}') Then Begin
          Dec(Depth);
          If Depth<=0 Then Begin Inc(I); Break; End;
        End Else
        If (Depth=0)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=';') Then Begin
          Inc(I); Break;
        End;
        Inc(I);
      End;
      Continue;
    End;
    Inc(I);
  End;

  { Section var + corps de main }
  CollectedCount:=0;
  MainBodyStart:=0; MainBodyEnd:=0;
  If MainTok>0 Then Begin
    I:=MainTok;
    Inc(I); { fn }
    Inc(I); { main }
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='(') Then Begin
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val=')')) do Inc(I);
      If I<=TokCount Then Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_OP)and(Tokens[I].Val='->') Then Begin
      While (I<=TokCount) and Not((Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{')) do Inc(I);
    End;
    If (I<=TokCount)and(Tokens[I].Kind=TK_PUNCT)and(Tokens[I].Val='{') Then Begin
      MainBodyStart:=I;
      Depth:=1;
      J:=I+1;
      While (J<=TokCount)and(Depth>0) do Begin
        If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='{') Then Inc(Depth) Else
        If (Tokens[J].Kind=TK_PUNCT)and(Tokens[J].Val='}') Then Dec(Depth);
        Inc(J);
      End;
      MainBodyEnd:=J-1;
      CollectLetsRec(MainBodyStart+1,MainBodyEnd-1);
    End;
  End;
  EmitVarSection;
  EmitRaw('begin');
  EmitLn;
  Inc(Indent);
  If MainBodyStart>0 Then Begin
    I:=MainBodyStart;
    EmitBlock(I);
  End;
  Dec(Indent);
  EmitRaw('end.');
  EmitLn;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Procedure ShowUsage;
Begin
  WriteLn('RUST2PAS ',RUST2PAS_VERSION,' - Transpilateur Rust vers Turbo/Free Pascal');
  WriteLn;
  WriteLn('Syntaxe : RUST2PAS [-v] source.rs [destination.pas]');
  WriteLn;
  WriteLn('  source.rs       Fichier source Rust.');
  WriteLn('  destination.pas Fichier Pascal a generer (defaut : source.pas).');
  WriteLn('  -v / --verbose  Afficher des messages de progression.');
  WriteLn('  -h / --help     Afficher cette aide.');
  WriteLn;
  WriteLn('Exemple : RUST2PAS hello.rs hello.pas');
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
    If (I>0)and(A[I]='.') Then DstName:=Copy(A,1,I-1)+'.pas'
                          Else DstName:=A+'.pas';
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
  If Verbose Then WriteLn('RUST2PAS : tokenisation de ',SrcName,'...');
  Assign(SrcFile,SrcName);
  {$I-} Reset(SrcFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('RUST2PAS : impossible d''ouvrir ',SrcName);
    Halt(EXIT_ERROR);
  End;
  Tokenize;
  Close(SrcFile);
  If Verbose Then WriteLn('RUST2PAS : ',TokCount,' tokens lus.');
  Analyze;
  If Verbose Then Begin
    WriteLn('RUST2PAS : module = ',ProgName);
    WriteLn('RUST2PAS : ',FuncCount,' fonction(s).');
  End;

  Assign(DstFile,DstName);
  {$I-} Rewrite(DstFile); {$I+}
  If IOResult<>0 Then Begin
    WriteLn('RUST2PAS : impossible de creer ',DstName);
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
  If Verbose Then WriteLn('RUST2PAS : sortie ecrite dans ',DstName);
  If ErrorCount>0 Then Halt(EXIT_ERROR);
  Halt(EXIT_OK);
END.
